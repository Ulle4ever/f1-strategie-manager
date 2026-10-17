extends Control
## Rennwochenende: Strecke, Wetter, Qualifying (interaktiv oder automatisch), Startaufstellung, Strategieplanung.

const U = preload("res://scripts/ui.gd")
const TrackMap = preload("res://scripts/track_map.gd")
const RaceSim = preload("res://scripts/race_sim.gd")
const StintBar = preload("res://scripts/stint_bar.gd")
const WeatherPanel = preload("res://scripts/weather_panel.gd")
const BiasBar = preload("res://scripts/bias_bar.gd")

var main
var sim
var track
var race: Dictionary
var laps := 0
var editors := []


func _ready() -> void:
	U.fill(self)
	add_child(U.backdrop())
	race = Game.current_race()
	track = DB.track(race["circuitId"])
	var margin := U.screen_margin(self, 22)
	var root := U.vbox(6 if U.is_mobile() else 12)
	margin.add_child(root)
	if track == null:
		root.add_child(U.title_bar("Rennwochenende", str(race["name"])))
		root.add_child(U.label("Für %s liegen keine Streckendaten vor." % race["circuit"], 22, U.BAD))
		root.add_child(U.button("Zurück", func(): main.show_hub(), 160))
		return
	laps = Game.race_laps(race, track)
	if Game.weekend_sim == null or Game.weekend_round != Game.round_index:
		sim = RaceSim.new()
		sim.setup(Game.year, track, Game.sim_teams(), laps, Game.team_id, 0)
		Game.weekend_sim = sim
		Game.weekend_round = Game.round_index
	else:
		sim = Game.weekend_sim

	var head := U.hbox(12)
	root.add_child(head)
	var tb := U.title_bar("Rennwochenende", str(race["name"]))
	tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tb)
	head.add_child(U.button("Zurück", func(): main.show_hub(), 120, 42))

	var entries := _left_entries()
	if not sim.quali_done:
		entries.append({"name": "Qualifying", "node": _quali_intro_panel(), "grow": true})
	else:
		entries.append({"name": "Startaufstellung", "node": _grid_panel(), "grow": true, "self_scroll": true})
		entries.append({"name": "Strategie", "node": _strategy_panel(), "min": 430.0, "self_scroll": true})
	var cols := U.columns(entries, 14)
	root.add_child(cols)
	if sim.quali_done:
		var foot := U.hbox(12)
		root.add_child(foot)
		foot.add_child(U.spacer())
		foot.add_child(U.button("Sofort simulieren", _on_instant, 220 if not U.is_mobile() else 170, 52 if not U.is_mobile() else 42))
		foot.add_child(U.primary_button("RENNEN STARTEN", _on_start, 300 if not U.is_mobile() else 240, 52 if not U.is_mobile() else 42))


## Haltbarkeit: genau nach Reifentest, sonst als ungefähre Angabe.
func _life_txt(k: int) -> String:
	if sim.practice["tyre_known"]:
		return str(int(sim.life_eff(k)))
	return "~%d" % (int(round(sim.known_life(k) / 2.0)) * 2)


func _wrap(content: Control, accent := U.ACCENT, margin := 14) -> Control:
	var p := U.panel(margin, accent)
	p.add_child(content)
	return p


## Linker Bereich: Strecke, Wetterbericht und Auto-Eignung (PC: Reiter in einer Karte, Handy: eigene Reiter).
func _left_entries() -> Array:
	if U.is_mobile():
		return [
			{"name": "Strecke", "node": _wrap(_info_content(), U.ACCENT, 12), "min": 350.0},
			{"name": "Wetter", "node": _wrap(_weather_content(), U.BLUE, 12)},
			{"name": "Auto", "node": _wrap(_fit_content(), U.WARN, 12)},
		]
	var p := U.panel(12, U.ACCENT)
	p.custom_minimum_size = Vector2(390, 0)
	var tc := TabContainer.new()
	tc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for e in [["Strecke", _info_content()], ["Wetter", _weather_content()], ["Auto", _fit_content()]]:
		var sc := ScrollContainer.new()
		sc.name = e[0]
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var inner: Control = e[1]
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(inner)
		tc.add_child(sc)
	p.add_child(tc)
	return [{"name": "Strecke", "node": p, "min": 390.0}]


func _weather_content() -> Control:
	var wp := WeatherPanel.new()
	wp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wp.refresh(sim)
	return wp


func _bias_word(v: float, low: String, high: String) -> String:
	if v > 0.55:
		return "sehr " + high
	if v > 0.18:
		return high
	if v < -0.55:
		return "sehr " + low
	if v < -0.18:
		return low
	return "ausgewogen"


func _sec_col(s: float) -> Color:
	return U.GOOD if s > 0.04 else (U.BAD if s < -0.04 else U.MUTED)


## Auto-Eignung: wie gut passt dein Auto zu dieser Strecke (Abtrieb, Motor, Reifen, Regen) und wer profitiert noch.
func _fit_content() -> Control:
	var v := U.vbox(8)
	v.add_child(U.section("Dein Auto auf dieser Strecke", 13))
	var mine: Dictionary = {}
	for t in Game.sim_teams():
		if t["id"] == Game.team_id:
			mine = t
	var prof: Dictionary = mine.get("profile", {})
	var rep: Dictionary = sim.fit_report(prof)
	var total: float = float(rep["total"])
	var hl := U.hbox(8)
	hl.add_child(U.label("%+.2f s" % total, 30, _sec_col(total), true))
	var sub := U.label("pro Runde gegenüber dem Durchschnitt deines Autos", 12, U.MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl.add_child(sub)
	v.add_child(hl)
	var col := Color(mine.get("color", U.WARN))
	# Abtrieb
	var b1 := BiasBar.new()
	b1.set_values(float(prof.get("df", 0.0)), track.df_need(), col, "wenig Luftwiderstand", "viel Abtrieb")
	v.add_child(U.label("Abtrieb   %+.2f s" % float(rep["df"]), 14, _sec_col(float(rep["df"])), true))
	v.add_child(b1)
	var t1 := U.label("Auto: %s. Strecke: %s." % [_bias_word(float(prof.get("df", 0.0)), "Topspeed-Auto", "Abtriebs-Auto"), "braucht viel Abtrieb" if track.df_need() > 0.4 else ("Topspeed-Strecke" if track.df_need() < -0.3 else "ausgewogen")], 12, U.MUTED)
	t1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t1)
	# Motor
	var b2 := BiasBar.new()
	b2.set_values(float(prof.get("power", 0.0)), track.power_need(), col, "wenig Leistung", "viel Leistung")
	v.add_child(U.label("Motor / Topspeed   %+.2f s" % float(rep["power"]), 14, _sec_col(float(rep["power"])), true))
	v.add_child(b2)
	var t2 := U.label("Auto: %s. Strecke: Leistung %s." % [_bias_word(float(prof.get("power", 0.0)), "schwacher Motor", "starker Motor"), "sehr wichtig" if track.power_need() > 0.55 else ("kaum gefragt" if track.power_need() < 0.0 else "wichtig")], 12, U.MUTED)
	t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t2)
	# Reifen und Regen
	var tyre: float = float(prof.get("tyre", 0.0))
	var sev: float = track.tyre_severity
	var tt := "Reifen: %s. Verschleiß hier %s." % [_bias_word(tyre, "reifenfressend", "reifenschonend"), "hoch" if sev > 1.1 else ("niedrig" if sev < 0.92 else "normal")]
	if tyre > 0.2 and sev > 1.05:
		tt += " Vorteil: längere Stints möglich."
	elif tyre < -0.2 and sev > 1.05:
		tt += " Nachteil: früher stoppen."
	var tl := U.label(tt, 13, U.TEXT)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tl)
	var wet: float = float(prof.get("wet", 0.0))
	var wl := U.label("Regen: %s%s" % [_bias_word(wet, "schwach im Nassen", "stark im Nassen"), " (Regenwahrscheinlichkeit %d %%)" % int(sim.rain_chance * 100.0)], 13, U.TEXT)
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(wl)
	v.add_child(HSeparator.new())
	# Konkurrenz
	var tm := {}
	for c in sim.cars:
		tm[c.team_id] = {"name": c.team_name, "s": c.fit * track.lap_ref, "mine": c.is_player, "color": c.color}
	var arr: Array = tm.values()
	arr.sort_custom(func(a, b): return float(a["s"]) > float(b["s"]))
	v.add_child(U.section("Wer hier profitiert", 12))
	for k in mini(3, arr.size()):
		v.add_child(_fit_row(arr[k]))
	if arr.size() > 6:
		v.add_child(U.section("Wer hier leidet", 12))
		for k in range(arr.size() - 3, arr.size()):
			v.add_child(_fit_row(arr[k]))
	var hint := U.label("Das Autoprofil ändert sich mit dem Reglement und deinen Entwicklungsstufen (Aerodynamik erhöht den Abtrieb, Antrieb die Leistung).", 11, U.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	return v


func _fit_row(d: Dictionary) -> Control:
	var row := U.hbox(8)
	row.add_child(U.color_bar(d["color"], 5, 18))
	var nm := U.label(str(d["name"]), 14, U.WARN if d["mine"] else U.TEXT, bool(d["mine"]))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	row.add_child(nm)
	row.add_child(U.label("%+.2f s" % float(d["s"]), 14, _sec_col(float(d["s"])), true))
	return row


func _info_content() -> Control:
	var v := U.vbox(8)
	v.add_child(U.label(str(track.track_name).to_upper(), 22, U.TEXT, true))
	v.add_child(U.label("%s, %s" % [track.locality, track.country], 14, U.MUTED))
	var map := TrackMap.new()
	map.custom_minimum_size = Vector2(0, 220)
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.set_track(track)
	v.add_child(map)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 8)
	g.add_child(U.stat("Länge", "%.3f km" % (track.length / 1000.0)))
	g.add_child(U.stat("Runden", str(laps)))
	g.add_child(U.stat("Distanz", "%.0f km" % (track.length * laps / 1000.0)))
	g.add_child(U.stat("Referenz", sim.fmt_time(track.lap_ref)))
	g.add_child(U.stat("Boxengasse", "%.0f s" % (track.pit_loss * sim.rules["pit_loss_scale"])))
	g.add_child(U.stat("Überholen", "%d %%" % int(track.overtake_ease * 100.0)))
	v.add_child(g)
	var tyre := U.label("Haltbarkeit  Soft %s  |  Medium %s  |  Hard %s Runden" % [_life_txt(0), _life_txt(1), _life_txt(2)], 13, U.MUTED)
	v.add_child(tyre)
	var wl := "Regenwahrscheinlichkeit: %d %%" % int(sim.rain_chance * 100.0)
	var wcol := U.MUTED
	if sim.rain_chance >= 0.2:
		wcol = U.BLUE
	v.add_child(U.label(wl, 14, wcol, true))
	var rules := []
	if sim.rules["refuel"]:
		rules.append("Nachtanken erlaubt")
	if sim.rules["drs"]:
		rules.append("DRS")
	if sim.rules["min_compounds"] >= 2:
		rules.append("mind. 2 Mischungen")
	if rules.size() > 0:
		v.add_child(U.label("Regeln: " + ", ".join(rules), 13, U.MUTED))
	return v


func _quali_intro_panel() -> Control:
	var p := U.panel(20, U.WARN)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := U.vbox(12)
	p.add_child(v)
	v.add_child(U.heading("Qualifying", 30))
	var fmt := "Q1 (18 min) - Q2 (15 min) - Q3 (12 min)"
	if sim.year < 2003:
		fmt = "Eine Stunde, bis zu 12 Runden pro Fahrer"
	elif sim.year < 2006:
		fmt = "Einzelrunden-Qualifying: eine gezeitete Runde pro Fahrer"
	v.add_child(U.label(fmt, 18, U.TEXT, true))
	var txt := "Du schickst deine Autos selbst auf die Strecke: Reifenmischung und Risiko wählen, Verkehr und Streckenentwicklung beachten. Zum Schluss ist es eng - die Strecke wird schneller, aber alle fahren gleichzeitig."
	if sim.year >= 2010 and sim.year <= 2021:
		txt += "\n\nRegel dieser Jahre: Die Top 10 starten auf den Reifen ihrer schnellsten Q2-Runde."
	var l := U.label(txt, 15, U.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	v.add_child(HSeparator.new())
	v.add_child(_practice_box())
	v.add_child(HSeparator.new())
	v.add_child(U.heading("Startplatzstrafen", 16, U.MUTED))
	if sim.grid_penalties.is_empty():
		v.add_child(U.label("Keine bekannt.", 15, U.MUTED))
	else:
		for c in sim.cars:
			if sim.grid_penalties.has(c.index):
				var row := U.hbox(8)
				row.add_child(U.color_bar(c.color, 5, 20))
				row.add_child(U.label("%s  %s" % [c.code, c.team_name], 16, U.WARN if c.is_player else U.TEXT, true))
				row.add_child(U.chip("-%d Plätze" % int(sim.grid_penalties[c.index]), U.ACCENT_DARK, Color.WHITE))
				v.add_child(row)
	if sim.engine_allowance > 0:
		v.add_child(HSeparator.new())
		v.add_child(_engine_box())
	v.add_child(U.spacer())
	v.add_child(U.primary_button("QUALIFYING FAHREN", func(): main.show_quali(), 0, 60))
	v.add_child(U.button("Qualifying automatisch simulieren", _on_auto_quali, 0, 44))
	return p


## Freitagstraining: Stand und Einstieg.
func _practice_box() -> Control:
	var b := U.hbox(10)
	var done: int = int(sim.practice["done"])
	var t := "Training: %d von 3 Sessions gefahren. Setup %+.2f" % [done, float(sim.practice["setup"])]
	var l := U.label(t, 14, U.TEXT, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(l)
	b.add_child(U.button("FREITAGSTRAINING", func(): main.show_practice(), 190, 40))
	return b


## Motoren: Verschleiß je Fahrer, Wechsel (mit Strafe, wenn das Kontingent überschritten wird).
func _engine_box() -> Control:
	var v := U.vbox(4)
	v.add_child(U.heading("Motoren (%d pro Saison)" % sim.engine_allowance, 16, U.MUTED))
	for c in sim.cars:
		if not c.is_player:
			continue
		var row := U.hbox(8)
		row.add_child(U.color_bar(c.color, 5, 22))
		var wc := U.GOOD if c.engine_wear < 0.7 else (U.WARN if c.engine_wear < 0.95 else U.BAD)
		var info := U.label("%s: Motor %d, Verschleiß %d %%" % [c.code, c.engines_used, int(c.engine_wear * 100.0)], 14, wc, true)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var cb := U.checkbox()
		var over: bool = (c.engines_used + (0 if c.engine_new else 1)) > sim.engine_allowance
		cb.text = "Neuer Motor" + ("  (+10 Plätze)" if over else "  (frei)")
		cb.button_pressed = c.engine_new
		cb.toggled.connect(_on_engine.bind(c))
		row.add_child(cb)
		v.add_child(row)
	var hint := U.label("Ein alter Motor fällt häufiger aus. Wird das Kontingent überschritten, kostet der Wechsel 10 Startplätze.", 12, U.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	return v


func _on_engine(on: bool, c) -> void:
	sim.set_engine_change(c, on)
	main.show_weekend()


func _on_auto_quali() -> void:
	var t0 := Time.get_ticks_msec()
	await U.busy(self, "Qualifying wird berechnet ...", func(): sim.do_qualifying())
	print("[Zeit] Qualifying berechnet in %d ms" % (Time.get_ticks_msec() - t0))
	main.show_weekend()


func _grid_panel() -> Control:
	var p := U.panel(14, U.ACCENT)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := U.vbox(4)
	p.add_child(v)
	v.add_child(U.heading("Startaufstellung", 20))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 3)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(g)
	var order: Array = sim.grid_order()
	var best: float = 0.0
	for c in order:
		if c.quali_time > 0.0 and (best == 0.0 or c.quali_time < best):
			best = c.quali_time
	for c in order:
		var col: Color = U.WARN if c.is_player else U.TEXT
		var pos := U.label(str(c.grid), 17, col, true)
		pos.custom_minimum_size = Vector2(26, 0)
		g.add_child(pos)
		g.add_child(U.color_bar(c.color, 5, 20))
		var nm := U.label("%s  %s" % [c.code, c.driver_name], 15, col, c.is_player)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(nm)
		g.add_child(U.label(sim.fmt_time(c.quali_time) if c.quali_time > 0.0 else "ohne Zeit", 14, col))
		g.add_child(U.label("" if c.quali_time <= 0.0 or is_equal_approx(c.quali_time, best) else "+%.3f" % (c.quali_time - best), 14, U.MUTED))
		var note := HBoxContainer.new()
		if c.grid_penalty > 0:
			note.add_child(U.chip("-%d" % c.grid_penalty, U.ACCENT_DARK))
		if c.forced_start >= 0:
			var cd: Dictionary = RaceSim.COMPOUNDS[c.forced_start]
			var cl := U.label(cd["short"], 14, cd["color"], true)
			note.add_child(cl)
		g.add_child(note)
	return p


func _strategy_panel() -> Control:
	var p := U.panel(14, U.ACCENT)
	p.custom_minimum_size = Vector2(430, 0)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var v := U.vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	v.add_child(U.section("Strategie", 14))
	var intro := "Zeitleiste: Farbe = Reifenmischung, weiße Marke = Boxenstopp, rote Schraffur = Reifen halten nicht so lange."
	if sim.rules["refuel"]:
		intro += " Nachtanken erlaubt: Jeder Stopp bekommt eine eigene Spritmenge."
	var il := U.label(intro, 12, U.MUTED)
	il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(il)
	for c in sim.cars:
		if c.is_player:
			v.add_child(_build_editor(c))
	return p


## Reihe aus Mischungs-Knöpfen (nur ein Knopf aktiv). Rückgabe: {"row": HBox, "btns": Array}
func _comp_row(selected: int, cb: Callable, disabled_except := -1) -> Dictionary:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	var btns: Array = []
	for k in RaceSim.COMPOUNDS.size():
		var cd: Dictionary = RaceSim.COMPOUNDS[k]
		var b := Button.new()
		b.toggle_mode = true
		b.text = cd["name"] if k >= RaceSim.DRY_COUNT else "%s %s" % [cd["name"], _life_txt(k)]
		b.custom_minimum_size = Vector2(0, 32)
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", cd["color"])
		b.add_theme_color_override("font_pressed_color", cd["color"])
		b.add_theme_color_override("font_hover_color", cd["color"])
		b.add_theme_color_override("font_disabled_color", Color(cd["color"], 0.28))
		b.button_pressed = k == selected
		b.pressed.connect(cb.bind(k))
		if disabled_except >= 0 and k != disabled_except:
			b.disabled = true
		row.add_child(b)
		btns.append(b)
	return {"row": row, "btns": btns}


func _build_editor(c) -> Control:
	var e := {"car": c, "start": c.compound, "plan": c.plan.duplicate(true), "extra": c.fuel_extra, "stop_lbls": []}
	var card := U.card(10)
	var box := U.vbox(8)
	card.add_child(box)
	var head := U.hbox(8)
	head.add_child(U.color_bar(c.color, 6, 26))
	head.add_child(U.label("%s" % c.driver_name, 19, U.TEXT, true))
	head.add_child(U.spacer())
	head.add_child(U.chip("Start P%d" % c.grid, U.PANEL3))
	box.add_child(head)
	var tl := StintBar.new()
	box.add_child(tl)
	e["timeline"] = tl
	box.add_child(U.label("Start-Reifen", 12, U.MUTED, true))
	var sr := _comp_row(int(e["start"]), _on_start_comp.bind(e), c.forced_start)
	box.add_child(sr["row"])
	e["start_buttons"] = sr["btns"]
	if c.forced_start >= 0:
		box.add_child(U.label("Pflicht: Start auf dem Q2-Reifen (Top 10).", 12, U.WARN))
	var stops := U.vbox(6)
	box.add_child(stops)
	e["stops_box"] = stops
	var arow := U.hbox(8)
	arow.add_child(U.button("+ Boxenstopp", _on_add_stop.bind(e), 0, 34))
	arow.add_child(U.button("KI-Empfehlung", _on_reset.bind(e), 0, 34))
	box.add_child(arow)
	# Sprit
	box.add_child(HSeparator.new())
	box.add_child(U.section("Tank", 12))
	var frow := U.hbox(8)
	var fl := U.label("Reserve beim Start (Runden)", 13)
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frow.add_child(fl)
	var fsp := SpinBox.new()
	fsp.min_value = -4.0
	fsp.max_value = 12.0 if sim.rules["refuel"] else 6.0
	fsp.step = 0.5
	fsp.value = float(e["extra"])
	fsp.value_changed.connect(_on_fuel_extra.bind(e))
	frow.add_child(fsp)
	box.add_child(frow)
	e["fuel_spin"] = fsp
	var fi := U.label("", 13, U.TEXT)
	fi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(fi)
	e["fuel_info"] = fi
	var est := U.label("", 14, U.GOOD, true)
	est.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(est)
	e["est"] = est
	var warn := U.label("", 12, U.BAD)
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(warn)
	e["warn"] = warn
	editors.append(e)
	_rebuild_stops(e)
	return card


func _rebuild_stops(e: Dictionary) -> void:
	var stops: VBoxContainer = e["stops_box"]
	U.clear(stops)
	e["stop_lbls"] = []
	var plan: Array = e["plan"]
	plan.sort_custom(func(a, b): return int(a["lap"]) < int(b["lap"]))
	for i in plan.size():
		var s: Dictionary = plan[i]
		var sc := U.card(8, Color(1, 1, 1, 0.035))
		var col := U.vbox(5)
		sc.add_child(col)
		var r1 := U.hbox(8)
		r1.add_child(U.label("STOPP %d" % (i + 1), 13, U.MUTED, true))
		r1.add_child(U.spacer())
		r1.add_child(U.label("Ende Runde", 13))
		var sp := SpinBox.new()
		sp.min_value = 1
		sp.max_value = maxi(1, laps - 1)
		sp.value = int(s["lap"])
		sp.value_changed.connect(_on_stop_lap.bind(e, s))
		r1.add_child(sp)
		r1.add_child(U.button("x", _on_remove.bind(e, s), 34, 32))
		col.add_child(r1)
		var cr := _comp_row(int(s["comp"]), _on_stop_comp.bind(e, s))
		col.add_child(cr["row"])
		s["_btns"] = cr["btns"]
		if sim.rules["refuel"]:
			var r3 := U.hbox(8)
			var tl := U.label("Tanken: +Reserve (Runden)", 13)
			tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r3.add_child(tl)
			var fs := SpinBox.new()
			fs.min_value = -3.0
			fs.max_value = 12.0
			fs.step = 0.5
			fs.value = float(s.get("fuel", 0.0))
			fs.value_changed.connect(_on_stop_fuel.bind(e, s))
			r3.add_child(fs)
			col.add_child(r3)
			var il := U.label("", 12, U.MUTED)
			il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(il)
			e["stop_lbls"].append({"s": s, "lbl": il})
		stops.add_child(sc)
	for k in RaceSim.COMPOUNDS.size():
		e["start_buttons"][k].set_pressed_no_signal(k == int(e["start"]))
	_apply(e)


## Plan an die Simulation übergeben und Anzeige (Zeitleiste, Tank, Schätzung, Warnungen) aktualisieren.
func _apply(e: Dictionary) -> void:
	var c = e["car"]
	var plan: Array = e["plan"]
	var clean: Array = []
	for s in plan:
		clean.append({"lap": int(s["lap"]), "comp": int(s["comp"]), "fuel": float(s.get("fuel", 0.0))})
	sim.set_fuel_extra(c, float(e["extra"]))
	sim.set_plan(c, int(e["start"]), clean)
	e["timeline"].set_plan(laps, int(e["start"]), clean, func(k): return sim.life_eff(k))
	var t: float = sim.estimate_time(c, int(e["start"]), clean)
	e["est"].text = "Geschätzte Renndauer: %s   (%d Stopp%s)" % [sim.fmt_race_time(t), plan.size(), "" if plan.size() == 1 else "s"]
	var warns: Array = []
	var used := {int(e["start"]): true}
	for s in plan:
		used[int(s["comp"])] = true
	if int(sim.rules["min_compounds"]) >= 2 and used.size() < 2 and not sim.rain_seen:
		warns.append("Regel: mindestens zwei verschiedene Mischungen nötig, sonst erzwingt das Team einen Zusatzstopp.")
	# Reifen je Stint
	var sorted: Array = clean.duplicate()
	sorted.sort_custom(func(a, b): return int(a["lap"]) < int(b["lap"]))
	var a := 0
	var comp := int(e["start"])
	var idx := 0
	for s in sorted:
		var len_l: int = int(s["lap"]) - a
		var life: float = sim.life_eff(comp)
		if float(len_l) > life * 1.1:
			warns.append("Stint %d: %s hält nur ca. %d Runden, geplant sind %d." % [idx + 1, RaceSim.COMPOUNDS[comp]["name"], int(life), len_l])
		a = int(s["lap"])
		comp = int(s["comp"])
		idx += 1
	var last_len: int = laps - a
	if float(last_len) > sim.life_eff(comp) * 1.1:
		warns.append("Letzter Stint: %s hält nur ca. %d Runden, geplant sind %d." % [RaceSim.COMPOUNDS[comp]["name"], int(sim.life_eff(comp)), last_len])
	# Sprit
	var burn: float = sim.burn_per_lap
	var first_stop := laps
	if sim.rules["refuel"] and not sorted.is_empty():
		first_stop = int(sorted[0]["lap"])
	var f0: float = c.fuel
	var range0: float = (f0 - 0.3) / burn
	var pen: float = f0 * RaceSim.FUEL_TIME * sim.scale_time
	var ftxt := "Start: %.1f kg = %.1f Runden Reichweite (Bedarf bis %s: %d). Gewicht kostet %.1f s pro Runde." % [f0, range0, "Stopp 1" if sim.rules["refuel"] and not sorted.is_empty() else "Ziel", first_stop, pen]
	if range0 < float(first_stop):
		ftxt += "\nZU WENIG SPRIT: Der Tank wird vor %s leer! Mit Fahrstil 'Sparen' (-6 %%) reicht es nur knapp." % ("Stopp 1" if first_stop < laps else "dem Ziel")
		warns.append("Tank reicht nicht bis zum ersten Stopp/Ziel.")
		e["fuel_info"].add_theme_color_override("font_color", U.BAD)
	elif range0 < float(first_stop) + 0.8:
		e["fuel_info"].add_theme_color_override("font_color", U.WARN)
	else:
		e["fuel_info"].add_theme_color_override("font_color", U.TEXT)
	e["fuel_info"].text = ftxt
	if sim.rules["refuel"]:
		for entry in e["stop_lbls"]:
			var st: Dictionary = entry["s"]
			var nxt := laps
			for s2 in sorted:
				if int(s2["lap"]) > int(st["lap"]):
					nxt = mini(nxt, int(s2["lap"]))
			var need := nxt - int(st["lap"])
			var kg: float = sim.fuel_for_laps(float(need) + float(st.get("fuel", 0.0)))
			var rng_l: float = (kg - 0.3) / burn
			var add_s: float = maxf(0.0, kg - 2.0) / 9.0 + 1.2
			entry["lbl"].text = "Tank danach %.1f kg = %.1f Rd. (Bedarf %d)  |  Standzeit ca. %.1f s" % [kg, rng_l, need, add_s]
			entry["lbl"].add_theme_color_override("font_color", U.BAD if rng_l < float(need) else U.MUTED)
			if rng_l < float(need):
				warns.append("Stopp bei Runde %d: Tank reicht nicht bis zum nächsten Stopp/Ziel." % int(st["lap"]))
	e["warn"].text = "\n".join(warns)


func _on_start_comp(e: Dictionary, k: int) -> void:
	e["start"] = k
	_rebuild_stops(e)


func _on_stop_lap(v: float, e: Dictionary, s: Dictionary) -> void:
	s["lap"] = int(v)
	_apply(e)


func _on_stop_comp(e: Dictionary, s: Dictionary, k: int) -> void:
	s["comp"] = k
	var btns: Array = s.get("_btns", [])
	for i in btns.size():
		btns[i].set_pressed_no_signal(i == k)
	_apply(e)


func _on_stop_fuel(v: float, e: Dictionary, s: Dictionary) -> void:
	s["fuel"] = v
	_apply(e)


func _on_fuel_extra(v: float, e: Dictionary) -> void:
	e["extra"] = v
	_apply(e)


func _on_remove(e: Dictionary, s: Dictionary) -> void:
	e["plan"].erase(s)
	_rebuild_stops(e)


func _on_add_stop(e: Dictionary) -> void:
	var plan: Array = e["plan"]
	var last := 0
	for s in plan:
		last = maxi(last, int(s["lap"]))
	var lap := clampi(last + int(laps / (plan.size() + 2)), 2, maxi(2, laps - 1))
	plan.append({"lap": lap, "comp": 1, "fuel": 0.0})
	_rebuild_stops(e)


func _on_reset(e: Dictionary) -> void:
	var p: Dictionary = sim.default_plan(e["car"])
	e["start"] = p["start"]
	e["plan"] = p["plan"].duplicate(true)
	e["extra"] = 0.0
	e["fuel_spin"].set_value_no_signal(0.0)
	_rebuild_stops(e)


func _on_start() -> void:
	main.show_race(sim)


func _on_instant() -> void:
	main.show_race(sim, true)

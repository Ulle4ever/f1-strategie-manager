extends Control
## Rennwochenende: Strecke, Wetter, Qualifying (interaktiv oder automatisch), Startaufstellung, Strategieplanung.

const U = preload("res://scripts/ui.gd")
const Career = preload("res://scripts/career.gd")
const TrackMap = preload("res://scripts/track_map.gd")
const RaceSim = preload("res://scripts/race_sim.gd")
const StintBar = preload("res://scripts/stint_bar.gd")
const WeatherPanel = preload("res://scripts/weather_panel.gd")
const BiasBar = preload("res://scripts/bias_bar.gd")
const TeamCrest = preload("res://scripts/team_crest.gd")
const StrategyPanel = preload("res://scripts/strategy_panel.gd")
const DriverPhoto = preload("res://scripts/driver_photo.gd")
const Flag = preload("res://scripts/flag.gd")

var main
var sim
var track
var race: Dictionary
var laps := 0
var editors := []


func _ready() -> void:
	U.fill(self)
	add_child(U.team_backdrop())
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
	_maybe_intro.call_deferred()

	var head := U.hbox(12)
	root.add_child(head)
	var tb := U.title_bar("Rennwochenende", str(race["name"]))
	tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tb)
	head.add_child(TeamCrest.make(Game.team_id, 40.0 if U.is_mobile() else 50.0))
	if U.is_mobile() and sim.quali_done:
		# Handy: Start-Knöpfe oben in der Kopfzeile statt in einer eigenen Fußzeile (mehr Platz für Aufstellung und Strategie)
		head.add_child(U.dark_button("Sofort", _on_instant, 76, 40))
		head.add_child(U.primary_button("START", _on_start, 96, 40))
	head.add_child(U.dark_button("Zurück", func(): main.show_hub(), 84 if U.is_mobile() else 120, 42))

	var entries := _left_entries()
	if not sim.quali_done:
		entries.append({"name": "Qualifying", "node": _quali_intro_panel(), "grow": true})
	else:
		entries.append({"name": "Startaufstellung", "node": _grid_panel(), "grow": true, "self_scroll": true})
		entries.append({"name": "Strategie", "node": _strategy_panel(), "min": 400.0, "self_scroll": true})
	var cols := U.columns(entries, 14)
	root.add_child(cols)
	if sim.quali_done and not U.is_mobile():
		var foot := U.hbox(12)
		root.add_child(foot)
		var ea := _engine_alert()
		if ea != "":
			foot.add_child(U.label(ea + " – neuer Motor im Reiter Auto?", 14, U.WARN, true))
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
			{"name": "Auto" + (" (!)" if _engine_alert() != "" else ""), "node": _wrap(_fit_content(), U.WARN, 12)},
		]
	var p := U.panel(12, U.ACCENT)
	p.custom_minimum_size = Vector2(360, 0)
	var tc := TabContainer.new()
	tc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for e in [["Strecke", _info_content()], ["Wetter", _weather_content()], ["Auto" + (" (!)" if _engine_alert() != "" else ""), _fit_content()]]:
		var sc := ScrollContainer.new()
		sc.name = e[0]
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var inner: Control = e[1]
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(inner)
		tc.add_child(sc)
	p.add_child(tc)
	return [{"name": "Strecke", "node": p, "min": 360.0}]


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


## Sektoren der Strecke: Farbe wie auf der Karte, Länge und ungefährer Anteil an der Rundenzeit.
func _sector_legend() -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 4)
	var third: float = track.length / 3.0
	for k in 3:
		var t0: float = track.time_at(third * float(k))
		var t1: float = track.time_at(third * float(k + 1)) if k < 2 else track.lap_ref
		var c := PanelContainer.new()
		var sb := U.button_style(Color(TrackMap.SECTOR_COLS[k], 0.12), TrackMap.SECTOR_COLS[k], 2, 4)
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		c.add_theme_stylebox_override("panel", sb)
		var h := U.hbox(6)
		c.add_child(h)
		h.add_child(U.label("S%d" % (k + 1), 13, TrackMap.SECTOR_COLS[k].darkened(0.15), true))
		h.add_child(U.label("%.2f km  ·  ca. %.1f s" % [third / 1000.0, t1 - t0], 12, U.TEXT))
		row.add_child(c)
	return row


func _info_content() -> Control:
	var v := U.vbox(8)
	var trow := U.hbox(10)
	trow.add_child(Flag.make(str(track.country), 26.0))
	var tn := U.label(str(track.track_name).to_upper(), 22, U.TEXT, true)
	tn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(tn)
	v.add_child(trow)
	v.add_child(U.label("%s, %s" % [track.locality, track.country], 14, U.MUTED))
	var map := TrackMap.new()
	map.sector_style = 1
	map.custom_minimum_size = Vector2(0, 220)
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.set_track(track)
	v.add_child(map)
	v.add_child(_sector_legend())
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
	v.add_child(_goal_card())
	return v


## Rennziel für dieses Wochenende mit Prämie.
func _goal_card() -> Control:
	var g: Dictionary = Career.race_goal()
	var p := U.panel(10, U.BLUE)
	var v := U.vbox(2)
	p.add_child(v)
	v.add_child(U.label("RENNZIEL", 11, U.MUTED, true))
	var t := U.label(str(g["text"]), 16, U.TEXT, true)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var h := U.label("Prämie %.1f Mio. $, übertroffen %.1f Mio. $. Das Vertrauen des Vorstands steigt oder sinkt mit dem Ergebnis." % [float(g["bonus"]), float(g["bonus_hi"])], 12, U.MUTED)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(h)
	return p


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


## Warnung, wenn ein eigener Motor fast verbraucht ist (ab 90 %, ohne Wechsel an diesem Wochenende), sonst "".
func _engine_alert() -> String:
	if sim == null or sim.engine_allowance <= 0:
		return ""
	var parts: Array = []
	for c in sim.cars:
		if c.is_player and not c.engine_new and c.engine_wear >= 0.9:
			parts.append("%s %d %%" % [c.code, int(c.engine_wear * 100.0)])
	return "" if parts.is_empty() else "Motor verschlissen: " + ", ".join(parts)


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
	var M := U.is_mobile()
	var p := U.dark_panel(10 if M else 14, U.ACCENT)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := U.vbox(6)
	p.add_child(v)
	v.add_child(U.heading("Startaufstellung", 18 if M else 20, U.ON_DARK))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	# zwei versetzte Spalten wie auf der echten Startaufstellung
	var cols := U.hbox(10)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(cols)
	var lc := U.vbox(5)
	var rc := U.vbox(5)
	for c2 in [lc, rc]:
		c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(c2)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 22 if M else 26)
	rc.add_child(sp)
	var order: Array = sim.grid_order()
	var best: float = 0.0
	for c in order:
		if c.quali_time > 0.0 and (best == 0.0 or c.quali_time < best):
			best = c.quali_time
	var slots: Array = []
	for i in order.size():
		var slot := _grid_slot(order[i], best, M)
		slot.modulate.a = 0.0
		slots.append(slot)
		(lc if i % 2 == 0 else rc).add_child(slot)
	# Präsentation: sobald die Aufstellung sichtbar wird, erscheinen die Plätze nacheinander
	var shown := [false]
	var start := func():
		if shown[0] or not p.is_visible_in_tree():
			return
		shown[0] = true
		_animate_grid(slots)
	p.visibility_changed.connect(start)
	p.ready.connect(func(): start.call_deferred())
	return p


## Plätze von der Pole an nacheinander einblenden (leicht vergrößert hereinfedern), die Pole leuchtet danach kurz auf.
func _animate_grid(slots: Array) -> void:
	await get_tree().process_frame
	for i in slots.size():
		var s: Control = slots[i]
		if not is_instance_valid(s):
			return
		s.pivot_offset = s.size * 0.5
		s.scale = Vector2(1.12, 1.12)
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "modulate:a", 1.0, 0.22).set_delay(0.05 * float(i))
		tw.tween_property(s, "scale", Vector2.ONE, 0.32).set_delay(0.05 * float(i)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if slots.is_empty():
		return
	var pole: Control = slots[0]
	var glow := pole.create_tween()
	glow.tween_interval(0.05 * float(slots.size()) + 0.25)
	glow.tween_property(pole, "self_modulate", Color(1.5, 1.4, 1.1), 0.18)
	glow.tween_property(pole, "self_modulate", Color.WHITE, 0.45)


## Ein Startplatz: Position, Teamfarbe, Foto, Kürzel und Name, Zeit bzw. Abstand, Strafe und Startreifen.
func _grid_slot(c, best: float, M: bool) -> Control:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(U.ACCENT, 0.22) if c.is_player else U.DARK2
	sb.border_color = c.color
	sb.border_width_left = 4
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	card.add_theme_stylebox_override("panel", sb)
	var h := U.hbox(6)
	card.add_child(h)
	var pos := U.display(str(c.grid), 18 if M else 20, U.ON_DARK)
	pos.custom_minimum_size = Vector2(24, 0)
	pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(pos)
	h.add_child(DriverPhoto.make(c.driver_id, 30.0 if M else 36.0))
	var nv := U.vbox(-3)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nv)
	nv.add_child(U.display(c.code, 14 if M else 16, U.ACCENT.lightened(0.2) if c.is_player else U.ON_DARK))
	var sub: String = c.team_name if M else "%s  ·  %s" % [c.driver_name, c.team_name]
	var nl := U.label(sub, 10 if M else 12, U.MUTED_DARK)
	nl.clip_text = true
	nv.add_child(nl)
	var tv := U.vbox(-3)
	h.add_child(tv)
	var tl := U.label(sim.fmt_time(c.quali_time) if c.quali_time > 0.0 else "ohne Zeit", 11 if M else 13, U.ON_DARK, true)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(tl)
	var gl := U.label("" if c.quali_time <= 0.0 or is_equal_approx(c.quali_time, best) else "+%.3f" % (c.quali_time - best), 10 if M else 12, U.MUTED_DARK)
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tv.add_child(gl)
	if c.grid_penalty > 0:
		h.add_child(U.chip("-%d" % c.grid_penalty, U.BAD))
	if c.forced_start >= 0:
		var cd: Dictionary = RaceSim.COMPOUNDS[c.forced_start]
		h.add_child(U.label(cd["short"], 13, cd["color"], true))
	return card


func _strategy_panel() -> Control:
	var sp = StrategyPanel.new()
	sp.setup(sim, laps)
	return sp


## Intro-Karte einmal pro Rennwochenende (beim ersten Öffnen), danach nicht mehr.
func _maybe_intro() -> void:
	var key := "%d-%d" % [Game.year, Game.round_index]
	if not Game.active or Game.intro_seen == key or sim.quali_done:
		return
	Game.intro_seen = key
	var ri = load("res://scripts/race_intro.gd").new()
	ri.setup(track, sim, laps)
	add_child(ri)


func _on_start() -> void:
	main.show_race(sim)


func _on_instant() -> void:
	main.show_race(sim, true)

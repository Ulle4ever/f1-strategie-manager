extends Control
## Rennwochenende: Strecke, Wetter, Qualifying (interaktiv oder automatisch), Startaufstellung, Strategieplanung.

const U = preload("res://scripts/ui.gd")
const TrackMap = preload("res://scripts/track_map.gd")
const RaceSim = preload("res://scripts/race_sim.gd")

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

	var entries := [{"name": "Strecke", "node": _info_panel(), "min": 350.0}]
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


func _info_panel() -> Control:
	var p := U.panel(16, U.ACCENT)
	p.custom_minimum_size = Vector2(350, 0)
	var v := U.vbox(8)
	p.add_child(v)
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
	var v := U.vbox(12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	v.add_child(U.heading("Strategie", 20))
	if sim.rules["refuel"]:
		var rl := U.label("Nachtanken erlaubt: Die Spritmenge wird automatisch auf den nächsten Stopp abgestimmt.", 13, U.MUTED)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(rl)
	for c in sim.cars:
		if c.is_player:
			v.add_child(_build_editor(c))
	return p


func _build_editor(c) -> Control:
	var e := {"car": c, "start": c.compound, "plan": c.plan.duplicate(true)}
	var box := U.vbox(8)
	var head := U.hbox(8)
	head.add_child(U.color_bar(c.color, 8, 28))
	head.add_child(U.label("%s" % c.driver_name, 20, U.TEXT, true))
	head.add_child(U.chip("Start P%d" % c.grid, U.PANEL3))
	box.add_child(head)
	var srow := HFlowContainer.new()
	srow.add_theme_constant_override("h_separation", 6)
	srow.add_child(U.label("Start-Reifen:", 15, U.MUTED))
	var sbtns := []
	for k in RaceSim.COMPOUNDS.size():
		var b := Button.new()
		b.toggle_mode = true
		b.text = ("%s" % RaceSim.COMPOUNDS[k]["name"]) if k >= RaceSim.DRY_COUNT else ("%s %s R." % [RaceSim.COMPOUNDS[k]["name"], _life_txt(k)])
		b.add_theme_color_override("font_color", RaceSim.COMPOUNDS[k]["color"])
		b.add_theme_color_override("font_pressed_color", RaceSim.COMPOUNDS[k]["color"])
		b.add_theme_color_override("font_hover_color", RaceSim.COMPOUNDS[k]["color"])
		b.add_theme_color_override("font_disabled_color", Color(RaceSim.COMPOUNDS[k]["color"], 0.28))
		b.pressed.connect(_on_start_comp.bind(e, k))
		if c.forced_start >= 0 and k != c.forced_start:
			b.disabled = true
		srow.add_child(b)
		sbtns.append(b)
	box.add_child(srow)
	if c.forced_start >= 0:
		box.add_child(U.label("Pflicht: Start auf dem Q2-Reifen (Top 10).", 13, U.WARN))
	e["start_buttons"] = sbtns
	var stops := U.vbox(4)
	box.add_child(stops)
	e["stops_box"] = stops
	var arow := U.hbox(8)
	arow.add_child(U.button("+ Boxenstopp", _on_add_stop.bind(e), 140, 34))
	arow.add_child(U.button("KI-Empfehlung", _on_reset.bind(e), 140, 34))
	box.add_child(arow)
	var est := U.label("", 14, U.GOOD, true)
	box.add_child(est)
	e["est"] = est
	var warn := U.label("", 13, U.BAD)
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(warn)
	e["warn"] = warn
	editors.append(e)
	_rebuild_stops(e)
	box.add_child(HSeparator.new())
	return box


func _rebuild_stops(e: Dictionary) -> void:
	var stops: VBoxContainer = e["stops_box"]
	U.clear(stops)
	var plan: Array = e["plan"]
	plan.sort_custom(func(a, b): return int(a["lap"]) < int(b["lap"]))
	for i in plan.size():
		var s: Dictionary = plan[i]
		var row := U.hbox(8)
		row.add_child(U.label("Stopp %d: Ende Runde" % (i + 1), 15))
		var sp := SpinBox.new()
		sp.min_value = 1
		sp.max_value = maxi(1, laps - 1)
		sp.value = int(s["lap"])
		sp.value_changed.connect(_on_stop_lap.bind(e, s))
		row.add_child(sp)
		var ob := OptionButton.new()
		for k in RaceSim.COMPOUNDS.size():
			ob.add_item(RaceSim.COMPOUNDS[k]["name"], k)
		ob.select(int(s["comp"]))
		ob.item_selected.connect(_on_stop_comp.bind(e, s, ob))
		row.add_child(ob)
		row.add_child(U.button("x", _on_remove.bind(e, s), 34, 32))
		stops.add_child(row)
	for k in RaceSim.COMPOUNDS.size():
		e["start_buttons"][k].set_pressed_no_signal(k == int(e["start"]))
	_apply(e)


func _apply(e: Dictionary) -> void:
	var c = e["car"]
	var plan: Array = e["plan"]
	sim.set_plan(c, int(e["start"]), plan)
	var t: float = sim.estimate_time(c, int(e["start"]), plan)
	e["est"].text = "Geschätzte Renndauer: %s   (%d Stopp%s)" % [sim.fmt_race_time(t), plan.size(), "" if plan.size() == 1 else "s"]
	var used := {int(e["start"]): true}
	for s in plan:
		used[int(s["comp"])] = true
	var txt := ""
	if int(sim.rules["min_compounds"]) >= 2 and used.size() < 2:
		txt = "Regel: mindestens zwei verschiedene Mischungen nötig. Das Team erzwingt sonst einen Zusatzstopp."
	var life: float = sim.life_eff(int(e["start"]))
	var first := laps
	for s in plan:
		first = mini(first, int(s["lap"]))
	if float(first) > life * 1.15:
		txt += "  Start-Reifen halten nur ca. %d Runden." % int(life)
	e["warn"].text = txt


func _on_start_comp(e: Dictionary, k: int) -> void:
	e["start"] = k
	_rebuild_stops(e)


func _on_stop_lap(v: float, e: Dictionary, s: Dictionary) -> void:
	s["lap"] = int(v)
	_apply(e)


func _on_stop_comp(i: int, e: Dictionary, s: Dictionary, ob: OptionButton) -> void:
	s["comp"] = ob.get_item_id(i)
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
	plan.append({"lap": lap, "comp": 1})
	_rebuild_stops(e)


func _on_reset(e: Dictionary) -> void:
	var p: Dictionary = sim.default_plan(e["car"])
	e["start"] = p["start"]
	e["plan"] = p["plan"].duplicate(true)
	_rebuild_stops(e)


func _on_start() -> void:
	main.show_race(sim)


func _on_instant() -> void:
	main.show_race(sim, true)

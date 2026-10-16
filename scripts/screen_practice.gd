extends Control
## Freitagstraining: drei Sessions mit Programmwahl, danach Setup (Abtrieb gegen Topspeed) festlegen.

const U = preload("res://scripts/ui.gd")
const RaceSim = preload("res://scripts/race_sim.gd")

var main
var sim
var program_opts: Array = []
var run_buttons: Array = []
var result_boxes: Array = []
var slider: HSlider
var slider_label: Label
var est_label: Label
var tyre_label: Label
var setup_note: Label
var _building := false


func _ready() -> void:
	U.fill(self)
	add_child(U.backdrop())
	sim = Game.weekend_sim
	var margin := U.screen_margin(self, 22)
	var root := U.vbox(6 if U.is_mobile() else 12)
	margin.add_child(root)
	var race: Dictionary = Game.current_race()
	var head := U.hbox(12)
	root.add_child(head)
	var tb := U.title_bar("Freitagstraining", str(race["name"]))
	tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tb)
	head.add_child(U.button("Zurück", func(): main.show_weekend(), 120, 42))

	# Sessions
	var lsc := ScrollContainer.new()
	lsc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var left := U.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lsc.add_child(left)
	var intro := U.label("Drei Trainingssessions: Wähle je ein Programm. Mehr Setup-Messungen machen die Schätzung genauer. Jede Session kostet etwas Motorverschleiß, und aggressive Fahrer bauen eher einen Unfall.", 14, U.MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(intro)
	for i in 3:
		left.add_child(_session_card(i))

	# Setup
	var cols := U.columns([{"name": "Training", "node": lsc, "grow": true, "self_scroll": true}, {"name": "Setup", "node": _setup_panel(), "min": 390.0}], 14)
	root.add_child(cols)
	_refresh()


func _session_card(i: int) -> Control:
	var p := U.panel(12, U.ACCENT)
	var v := U.vbox(6)
	p.add_child(v)
	var h := U.hbox(10)
	v.add_child(h)
	h.add_child(U.label("FP%d" % (i + 1), 24, U.WARN, true))
	var opt := OptionButton.new()
	opt.fit_to_longest_item = false
	opt.custom_minimum_size = Vector2(240, 38)
	var kinds := RaceSim.PRACTICE_PROGRAMS.keys()
	for k in kinds:
		opt.add_item(RaceSim.PRACTICE_PROGRAMS[k]["name"])
		opt.set_item_metadata(opt.item_count - 1, k)
	opt.item_selected.connect(func(_x): _refresh())
	h.add_child(opt)
	program_opts.append(opt)
	h.add_child(U.spacer())
	var b := U.primary_button("SESSION FAHREN", _on_run.bind(i), 190, 40)
	h.add_child(b)
	run_buttons.append(b)
	var res := U.vbox(3)
	res.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(res)
	result_boxes.append(res)
	return p


func _setup_panel() -> Control:
	var p := U.panel(14, U.WARN)
	p.custom_minimum_size = Vector2(390, 0)
	var v := U.vbox(8)
	p.add_child(v)
	v.add_child(U.heading("Setup", 22))
	var tr = sim.track
	var df: float = tr.df_need()
	var ch := "Ausgewogene Strecke"
	if df > 0.6:
		ch = "Abtriebsstrecke: viele langsame Kurven"
	elif df > 0.25:
		ch = "Eher abtriebsorientiert"
	elif df < -0.6:
		ch = "Powerstrecke: Topspeed zählt"
	elif df < -0.25:
		ch = "Eher geringer Abtrieb"
	v.add_child(U.label("%s  |  grobe Erwartung %+.1f" % [ch, df], 14, U.MUTED))
	var sh := U.hbox(8)
	sh.add_child(U.label("Topspeed", 12, U.MUTED))
	sh.add_child(U.spacer())
	slider_label = U.label("", 22, U.WARN, true)
	sh.add_child(slider_label)
	sh.add_child(U.spacer())
	sh.add_child(U.label("Abtrieb", 12, U.MUTED))
	v.add_child(sh)
	slider = HSlider.new()
	slider.min_value = -1.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(0, 28)
	slider.add_theme_stylebox_override("slider", U.button_style(U.PANEL3, U.PANEL3, 0, 3))
	slider.add_theme_stylebox_override("grabber_area", U.button_style(U.ACCENT, U.ACCENT, 0, 3))
	slider.add_theme_stylebox_override("grabber_area_highlight", U.button_style(U.ACCENT_HI, U.ACCENT_HI, 0, 3))
	_building = true
	slider.value = float(sim.practice["setup"])
	_building = false
	slider.value_changed.connect(_on_slider)
	v.add_child(slider)
	est_label = U.label("", 14, U.TEXT)
	est_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(est_label)
	v.add_child(U.button("Schätzung übernehmen", _on_take_estimate, 0, 36))
	var note := U.label("Passt das Setup nicht zur Strecke, verlierst du Rundenzeit im Qualifying und im Rennen. Das echte Optimum schwankt jedes Wochenende leicht.", 12, U.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	v.add_child(HSeparator.new())
	tyre_label = U.label("", 14, U.TEXT)
	tyre_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tyre_label)
	setup_note = U.label("", 13, U.MUTED)
	setup_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(setup_note)
	v.add_child(U.spacer())
	v.add_child(U.primary_button("ZURÜCK ZUM WOCHENENDE", func(): main.show_weekend(), 0, 54))
	return p


func _refresh() -> void:
	var done: int = int(sim.practice["done"])
	var sessions: Array = sim.practice["sessions"]
	for i in 3:
		run_buttons[i].disabled = i != done or sim.quali_done
		run_buttons[i].text = "SESSION FAHREN" if i >= done else "ABSOLVIERT"
		program_opts[i].disabled = i < done or sim.quali_done
		var box: VBoxContainer = result_boxes[i]
		U.clear(box)
		if i < sessions.size():
			var r: Dictionary = sessions[i]
			program_opts[i].select(RaceSim.PRACTICE_PROGRAMS.keys().find(r["kind"]))
			var tl := U.label(str(r["text"]), 14, U.TEXT)
			tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(tl)
			if str(r["incident"]) != "":
				box.add_child(U.label(str(r["incident"]), 13, U.BAD, true))
			box.add_child(_times_table(r))
		else:
			var k: String = program_opts[i].get_item_metadata(program_opts[i].selected)
			var dl := U.label(str(RaceSim.PRACTICE_PROGRAMS[k]["desc"]), 14, U.MUTED)
			dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(dl)
	_update_setup_labels()


func _times_table(r: Dictionary) -> Control:
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 1)
	var list: Array = r["times"]
	var best: float = float(list[0]["t"])
	var shown := 0
	for i in list.size():
		var c = list[i]["car"]
		if i >= 5 and not c.is_player:
			continue
		var col: Color = U.WARN if c.is_player else U.TEXT
		g.add_child(U.label(str(i + 1), 13, U.MUTED, true))
		g.add_child(U.color_bar(c.color, 4, 14))
		g.add_child(U.label(c.code, 13, col, true))
		g.add_child(U.label(sim.fmt_time(float(list[i]["t"])), 13, col))
		g.add_child(U.label("" if i == 0 else "+%.3f" % (float(list[i]["t"]) - best), 13, U.MUTED))
		g.add_child(U.label("", 13))
		shown += 1
	return g


func _update_setup_labels() -> void:
	var e: Dictionary = sim.practice_estimate()
	var v := slider.value
	var d := "ausgewogen"
	if v > 0.25:
		d = "mehr Abtrieb"
	elif v < -0.25:
		d = "mehr Topspeed"
	slider_label.text = "%+.2f  %s" % [v, d]
	if e["has"]:
		est_label.text = "Datenlage: Schätzung %+.2f (± %.2f) nach %d Messung(en)." % [float(e["est"]), float(e["sigma"]), sim.practice["setup_obs"].size()]
	else:
		est_label.text = "Noch keine Messung. Erwartung nur grob: %+.2f (± 0.55). Fahre eine Setup-Abstimmung." % float(e["est"])
	tyre_label.text = "Reifendaten: genau bekannt." if sim.practice["tyre_known"] else "Reifendaten: nur ungefähr bekannt (± 15 %). Ein Reifentest zeigt die genaue Haltbarkeit."
	var wear := ""
	if sim.engine_allowance > 0:
		wear = "Jede Session kostet ca. 3.5 % Motorverschleiß."
	var q := ""
	if sim.quali_done:
		q = " Das Qualifying läuft bereits, das Training ist beendet."
	setup_note.text = wear + q


func _on_slider(v: float) -> void:
	if _building:
		return
	sim.practice["setup"] = v
	for c in sim.cars:
		if c.is_player:
			sim.apply_setup(c, v)
	_update_setup_labels()


func _on_take_estimate() -> void:
	var e: Dictionary = sim.practice_estimate()
	slider.value = clampf(snappedf(float(e["est"]), 0.05), -1.0, 1.0)


func _on_run(i: int) -> void:
	var k: String = program_opts[i].get_item_metadata(program_opts[i].selected)
	var r: Dictionary = sim.run_practice(k)
	if float(r["cost"]) > 0.0:
		Game.budget -= float(r["cost"])
	Game.save()
	_refresh()

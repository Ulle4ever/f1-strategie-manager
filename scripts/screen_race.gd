extends Control
## Live-Rennen: Startampel, Karte mit Punkten, Zeitenturm, Boxenfunk für die eigenen Autos, Vorspulen.

const U = preload("res://scripts/ui.gd")
const TrackMap = preload("res://scripts/track_map.gd")
const Tower = preload("res://scripts/timing_tower.gd")
const RaceSim = preload("res://scripts/race_sim.gd")
const StartLights = preload("res://scripts/start_lights.gd")
const Market = preload("res://scripts/market.gd")
const TvOverlay = preload("res://scripts/tv_overlay.gd")
const TyreIcon = preload("res://scripts/tyre_icon.gd")
const StintBar = preload("res://scripts/stint_bar.gd")
const FuelPlanBar = preload("res://scripts/fuel_plan_bar.gd")
const DriverPanel = preload("res://scripts/driver_panel.gd")
const Career = preload("res://scripts/career.gd")
const WeatherPanel = preload("res://scripts/weather_panel.gd")

const SPEEDS := [0, 1, 4, 16, 64, 256]
const SPEED_NAMES := ["Pause", "1x", "4x", "16x", "64x", "256x"]
const SPEED_NAMES_SHORT := ["II", "1x", "4x", "16x", "64x", "256x"]

var main
var sim
var map
var tower
var selected = null
var speed_idx := 2
var acc := 0.0
var ev_index := 0
var log_lines: Array = []
var auto_slow := true
var finished_shown := false
var alerted := {}
var lights_t := 0.0
var lights_hold := 1.5
var lights_phase := 0      # 0 = Ampel läuft, 1 = erloschen (kurz anzeigen), 2 = Rennen
var banner_t := 0.0

var lap_label: Label
var status_chip: PanelContainer
var status_label: Label
var weather_label: Label
var time_label: Label
var speed_buttons: Array = []
var log_label: RichTextLabel
var car_title: Label
var car_sub: Label
var tyre_label: Label
var tyre_bar: ProgressBar
var info_label: Label
var style_buttons: Array = []
var pit_buttons: Array = []
var pit_status: Label
var player_buttons: Array = []
var end_panel: PanelContainer
var end_text: Label
var lights: Control
var banner: PanelContainer
var banner_label: Label
var race_tabs: TabContainer
var race_main_tabs: TabContainer
var skipping := false
var skip_t0 := 0
var auto_finish := false
var skip_panel: PanelContainer
var skip_label: Label
const TICK_BUDGET_US := 14000
var tv
var ers_title: Label
var ers_bar: ProgressBar
var mode_buttons: Array = []
var mode_hint: Label
var engine_label: Label
var uc_label: Label
var threat_label: Label
var rejoin_label: Label
var uc_btn: Button
var to_label: Label
var order_buttons: Array = []
var order_status: Label
var order_msg := ""
var sc_label: Label
var radar_label: Label
var double_btn: Button
var stint_bar
var driver_panels: Array = []        # Fahrer-Panels unter der Karte (je Spielerauto eins)
var quick_info: Label
var goal_label: Label
var goal_line: Label
var decision_layer: Control
var decision_card: PanelContainer
var decision_chip: Button     # Handy: Hinweis oben, wenn eine Funkanfrage wartet und die Karte nicht sichtbar ist
var decision_box: VBoxContainer
var decision_data: Dictionary = {}
var decision_car = null
var decision_seen := {}
var _dec_check_t := 0.0
var ov_info: Label
var ov_bars: Dictionary = {}
var ov_radar_box: VBoxContainer
var ov_radar_key := ""
var _ov_last := 0
var radio_buttons: Array = []
var radio_label: Label
var rule_checks: Dictionary = {}
var fuel_label: Label
var fuel_bar: ProgressBar
var style_hint: Label
var follow_buttons: Array = []
var follow_hint: Label
var pit_head: Label
var pit_win_label: Label
var pit_outlook: Label
var pit_when_box: HFlowContainer
var pit_when_lap := -1
var pit_edit_lap := -1
var pit_when_key := ""
var pit_touched := false      # Spieler hat im Assistenten etwas geändert (sonst folgt er dem nächsten geplanten Stopp)
var pit_plan_sig := ""
var pit_confirm_btn: Button
var pit_add_btn: Button
var pit_cancel_btn: Button
var pit_edit_label: Label
var pit_edit_reset: Button
var pit_auto_key := ""
var pit_plan_box: VBoxContainer
var pit_fuel_card: VBoxContainer
var pit_fuel_label: Label
var pit_fuel_hint: Label
var pit_pred: Label
var advice_box: VBoxContainer
var ers_head_label: Label
var weather_panel
var race_pages: Array = []
var gap_labels: Array = []
var pit_note: Label
var fuel_plan
var pit_fuel_quick: Array = []
var pit_sel := -1
var _advice_key := "init"
var _seg_key := ""
var _plan_key := ""
var map_big := false
var _hide_when_big: Array = []        # Knoten, die bei großer Karte ausgeblendet werden


func _ready() -> void:
	sim.requests_on = Game.requests_on
	U.fill(self)
	var bd = U.team_backdrop()
	bd.band = 0.0          # die Kopfleiste des Rennens ist selbst dunkel
	add_child(bd)
	var margin := U.screen_margin(self, 10)
	var M := U.is_mobile()
	if M:
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 4)
	var root := U.vbox(4 if M else 8)
	margin.add_child(root)
	root.add_child(_build_top())

	var tp := U.dark_panel(4)
	tp.custom_minimum_size = Vector2(372, 0)
	tower = Tower.new()
	tower.sim = sim
	tower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tower.car_clicked.connect(_select)
	if M:
		tower.custom_minimum_size = Vector2(380, 34.0 + float(sim.cars.size()) * 29.0 + 8.0)
	tp.add_child(tower)

	# Handy quer: Karte links, Fahrer-Panel als schmale Spalte rechts (die Karte behält die volle Höhe); PC: Panel unter der Karte
	var center: BoxContainer = U.hbox(5) if M else U.vbox(8)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mp := U.panel(4)
	mp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map = TrackMap.new()
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.sim = sim
	map.interactive = true
	map.car_clicked.connect(_select)
	map.set_track(sim.track)
	map.expand_pressed.connect(_toggle_map_big)
	mp.add_child(map)
	tv = TvOverlay.new()
	tv.sim = sim
	mp.add_child(tv)
	center.add_child(mp)
	if not M:
		goal_line = U.label("", 13, U.MUTED, true)
		goal_line.clip_text = true
		goal_line.custom_minimum_size = Vector2(60, 0)
		center.add_child(goal_line)
	var pbox: BoxContainer = U.vbox(5) if M else U.hbox(6)
	for c in sim.cars:
		if c.is_player:
			var dp = DriverPanel.new()
			dp.sim = sim
			dp.car = c
			dp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if M:
				dp.vertical = true
				dp.custom_minimum_size = Vector2(250, 0)
				dp.size_flags_vertical = Control.SIZE_EXPAND_FILL
			dp.box_pressed.connect(_on_panel_box)
			dp.plan_pressed.connect(_on_panel_plan)
			dp.switch_pressed.connect(_on_panel_switch)
			pbox.add_child(dp)
			driver_panels.append(dp)
	center.add_child(pbox)
	_build_decision_layer(mp)   # über der Karte; am Handy auf anderen Reitern nur ein Hinweis oben (die Karte verdeckte sonst die Knöpfe)
	var lp := U.panel(8)
	lp.custom_minimum_size = Vector2(0, 62 if M else 150)
	log_label = RichTextLabel.new()
	log_label.add_theme_color_override("default_color", U.TEXT)
	log_label.bbcode_enabled = true
	log_label.scroll_active = false
	log_label.add_theme_font_size_override("normal_font_size", 14)
	log_label.add_theme_font_override("normal_font", U.font(false))
	lp.add_child(log_label)
	if not M:
		center.add_child(lp)

	var funk = _build_control_panel()      # PC: Panel mit den Reitern Lage, Boxen, Fahren; Handy: null (die Seiten werden eigene Reiter)
	var entries := [
		{"name": "Tabelle", "node": tp, "min": 372.0},
		{"name": "Karte", "node": center, "grow": true, "self_scroll": true},
	]
	if M:
		for pg in race_pages:
			entries.append({"name": str(pg.name), "node": pg, "self_scroll": true})
		lp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		entries.append({"name": "Log", "node": lp, "self_scroll": true})
	else:
		entries.append({"name": "Funk", "node": funk, "min": 364.0, "self_scroll": true})
	if M:
		_hide_when_big = [pbox]
	else:
		_hide_when_big = [tp, funk, lp]
	var cols := U.columns(entries, 10)
	root.add_child(cols)
	race_main_tabs = cols as TabContainer
	if M:
		race_tabs = race_main_tabs
		U.compact_tabs(race_main_tabs, 9, 14)
		race_main_tabs.current_tab = 1
		race_main_tabs.tab_changed.connect(func(_i): _update_decision_chip())

	# Startampel
	lights = StartLights.new()
	lights.custom_minimum_size = Vector2(420, 200)
	lights.set_anchors_preset(Control.PRESET_CENTER_TOP)
	var lk := 0.72 if M else 1.0
	lights.offset_left = -210.0
	lights.offset_right = 210.0
	lights.offset_top = 90.0 * (0.5 if M else 1.0)
	lights.offset_bottom = lights.offset_top + 200.0
	lights.pivot_offset = Vector2(210.0, 0)
	lights.scale = Vector2(lk, lk)
	lights.mouse_filter = Control.MOUSE_FILTER_STOP
	lights.gui_input.connect(_on_lights_input)
	add_child(lights)

	# Banner
	banner = U.panel(5 if U.is_mobile() else 10, U.WARN)
	banner.visible = false
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_label = U.label("", 15 if U.is_mobile() else 22, U.WARN, true)
	banner.add_child(banner_label)
	add_child(banner)

	# Ende-Overlay
	end_panel = U.panel(22, U.ACCENT)
	end_panel.visible = false
	end_panel.custom_minimum_size = Vector2(340 if M else 480, 0)
	var ev := U.vbox(12)
	end_panel.add_child(ev)
	ev.add_child(U.heading("Zielflagge - Rennen beendet", 26))
	end_text = U.label("", 18, U.TEXT, true)
	ev.add_child(end_text)
	ev.add_child(U.primary_button("ERGEBNIS ANSEHEN", _on_results, 0, 54))
	add_child(end_panel)

	for c in sim.cars:
		if c.is_player and selected == null:
			_select(c)
	if sim.started:
		lights_phase = 2
		lights.visible = false
	_set_speed(2)
	_banner_msg("Startplatz P%d" % _player_grid(), 2.5, U.TEXT)
	skip_panel = U.panel(22, U.ACCENT)
	skip_panel.visible = false
	skip_label = U.label("", 24, U.TEXT, true)
	skip_panel.add_child(skip_label)
	add_child(skip_panel)
	if auto_finish:
		_skip_to_end()


## Handy: Tippen auf die Ampel startet das Rennen (statt Leertaste).
func _on_lights_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and lights_phase == 0:
		_lights_out()


func _player_grid() -> int:
	for c in sim.cars:
		if c.is_player:
			return c.grid
	return 1


func _build_top() -> Control:
	var p := U.panel(5 if U.is_mobile() else 8, U.ACCENT)
	var h := U.hbox(4 if U.is_mobile() else 14)
	p.add_child(h)
	var M := U.is_mobile()
	var lv := U.vbox(-6)
	lv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lv.add_child(U.label("RUNDE", 10 if M else 12, U.MUTED, true))
	lap_label = U.display("", 19 if M else 30, U.TEXT)
	lv.add_child(lap_label)
	h.add_child(lv)
	time_label = U.label("", 16, U.MUTED)
	time_label.visible = not M
	h.add_child(time_label)
	status_chip = U.chip("GRÜN", Color("14562f"), U.GOOD)
	status_label = status_chip.get_child(0)
	h.add_child(status_chip)
	if M:
		decision_chip = U.dark_button("Funk ▸", _on_decision_chip, 0, 30)
		decision_chip.add_theme_font_size_override("font_size", 12)
		decision_chip.add_theme_color_override("font_color", U.WARN)
		decision_chip.visible = false
		h.add_child(decision_chip)
	weather_label = U.label("", 14, U.MUTED)
	weather_label.clip_text = true
	weather_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weather_label.visible = not M
	if M:
		h.add_child(U.spacer())
	h.add_child(weather_label)
	var sg := U.hbox(2)          # Geschwindigkeit als zusammenhängende Leiste
	h.add_child(sg)
	for i in SPEEDS.size():
		var b := U.dark_button(SPEED_NAMES_SHORT[i] if U.is_mobile() else SPEED_NAMES[i], null, 34 if M else 54, 32 if M else 36)
		b.toggle_mode = true
		if M:
			b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_set_speed.bind(i))
		sg.add_child(b)
		speed_buttons.append(b)
	var end_b := U.dark_button("Ende", _skip_to_end, 48 if M else 64, 32 if M else 36)
	if M:
		end_b.add_theme_font_size_override("font_size", 14)
	h.add_child(end_b)
	var cb := U.checkbox("")
	cb.text = "Auto" if U.is_mobile() else "Auto-Slow"
	if U.is_mobile():
		cb.add_theme_font_size_override("font_size", 12)
	cb.button_pressed = true
	cb.toggled.connect(func(v): auto_slow = v)
	h.add_child(cb)
	var tvcb := U.checkbox("TV" if M else "TV-Grafik")
	if M:
		tvcb.add_theme_font_size_override("font_size", 12)
	tvcb.button_pressed = true
	tvcb.tooltip_text = "Fahrerkarte, Rundenzeiten, Zweikampf-Banner und Laufband ein- oder ausblenden"
	tvcb.toggled.connect(func(v): tv.visible = v)
	h.add_child(tvcb)
	return p


# ------------------------------------------------------------------ Schnellleiste

func _action_car():
	if selected != null and selected.is_player:
		return selected
	for c in sim.cars:
		if c.is_player:
			return c
	return null


func _on_quick_box() -> void:
	var c = _action_car()
	if c == null or c.state != 1:
		return
	if c.pit_requested:
		sim.cancel_pit(c)
		_radio("Funk an %s: Stopp zurückgenommen." % c.code)
		return
	var comp: int = sim.suggest_comp(c)
	sim.request_pit(c, comp)
	_radio("Funk an %s: Box, Box! Reifen: %s" % [c.code, RaceSim.COMPOUNDS[comp]["name"]])
	_banner_msg("Box diese Runde: %s" % RaceSim.COMPOUNDS[comp]["name"], 2.0, U.GOOD)


func _open_pit_tab() -> void:
	_show_page("Boxen")


func _on_quick_plan() -> void:
	_open_pit_tab()


func _on_panel_box(c) -> void:
	_select(c)
	_on_quick_box()


func _on_panel_plan(c) -> void:
	_select(c)
	_open_pit_tab()


## Wechsel zum anderen Spielerauto (Panel zeigt dann dessen Werte).
func _on_panel_switch(c) -> void:
	for o in sim.cars:
		if o.is_player and o != c:
			_select(o)
			return


## Fahrer-Panels: normal nur das gewählte Auto; bei großer Karte am PC beide nebeneinander.
func _update_quick() -> void:
	var c = _action_car()
	if c == null:
		return
	var both := map_big and not U.is_mobile()
	for dp in driver_panels:
		dp.visible = both or dp.car == c
		dp.can_switch = driver_panels.size() > 1 and not both


# ------------------------------------------------------------------ Entscheidungskarten

func _build_decision_layer(parent: Control) -> void:
	decision_layer = Control.new()
	U.fill(decision_layer)
	decision_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(decision_layer)
	else:
		add_child(decision_layer)
	decision_card = U.panel(10, U.WARN)
	decision_card.visible = false
	decision_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	decision_card.custom_minimum_size = Vector2(300.0 if U.is_mobile() else 380.0, 0)
	decision_box = U.vbox(5)
	decision_card.add_child(decision_box)
	decision_layer.add_child(decision_card)


## Karte unten mittig über der Kartenfläche platzieren (Höhe richtet sich nach dem Inhalt).
func _place_decision() -> void:
	if not decision_card.visible:
		return
	var cw: float = decision_card.custom_minimum_size.x
	decision_card.size = Vector2(cw, 0)
	var par := decision_layer.size
	if U.is_mobile():
		decision_card.position = Vector2((par.x - cw) * 0.5, maxf(4.0, (par.y - decision_card.size.y) * 0.5 + 18.0))
	else:
		decision_card.position = Vector2((par.x - cw) * 0.5, maxf(4.0, par.y - decision_card.size.y - 56.0))


func _hide_decision() -> void:
	decision_card.visible = false
	decision_data = {}
	decision_car = null
	_update_decision_chip()


## Handy: wartet eine Funkanfrage, während ein anderer Reiter als die Karte offen ist, erscheint oben ein Hinweis.
func _update_decision_chip() -> void:
	if decision_chip == null or race_main_tabs == null:
		return
	var on_map: bool = race_main_tabs.current_tab == 1
	decision_chip.visible = decision_card.visible and not on_map
	# die Karte ist am Handy niedrig: solange eine Anfrage offen ist, macht das Fahrer-Panel ihr Platz
	for n in _hide_when_big:
		(n as Control).visible = not map_big and not decision_card.visible
	_place_decision.call_deferred()


func _on_decision_chip() -> void:
	if map_big:
		_toggle_map_big()
	race_main_tabs.current_tab = 1


func _show_decision(c, d: Dictionary) -> void:
	decision_data = d
	decision_car = c
	decision_seen[d["key"]] = true
	U.clear(decision_box)
	var col := {"bad": U.BAD, "warn": U.WARN, "good": U.GOOD, "info": U.BLUE}[d["level"]] as Color
	var kinds := {"sc": "Safety Car", "rain": "Wetter", "tyre": "Reifen", "threat": "Undercut", "damage": "Schaden", "duel": "Zweikampf", "tyres": "Reifen", "mate": "Teamorder", "problem": "Technik", "fuel": "Sprit"}
	var psb: StyleBoxFlat = decision_card.get_theme_stylebox("panel")
	psb.border_color = col
	var head := U.hbox(6)
	head.add_child(U.chip(str(kinds.get(str(d["kind"]), "Hinweis")), col, U.INK))
	head.add_child(U.label(c.code, 13, U.MUTED, true))
	decision_box.add_child(head)
	decision_box.add_child(_wrap_label(str(d["title"]), 16, U.TEXT, true))
	decision_box.add_child(_wrap_label(str(d["text"]), 12, U.MUTED))
	# Handy: breitere Karte, die Optionen in zwei Spalten (wenig Höhe)
	var holder: Container = decision_box
	if U.is_mobile():
		decision_card.custom_minimum_size = Vector2(minf(maxf(decision_layer.size.x - 16.0, 300.0), 620.0), 0)
		var grid := GridContainer.new()
		grid.columns = 2 if d["options"].size() > 1 else 1
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 5)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		decision_box.add_child(grid)
		holder = grid
	for o in d["options"]:
		var act := str(o["action"])
		var strong: bool = act.begins_with("pit") or act.begins_with("later") or act.ends_with(":box")
		var oc := U.option_card(str(o["label"]), str(o["hint"]), col, _on_decision.bind(act), strong)
		oc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_child(oc)
	decision_card.visible = true
	_update_decision_chip()
	_place_decision.call_deferred()
	# Einblenden: kurz aufploppen
	decision_card.modulate.a = 0.0
	decision_card.scale = Vector2(0.94, 0.94)
	decision_card.pivot_offset = Vector2(decision_card.custom_minimum_size.x * 0.5, 40.0)
	var tw := decision_card.create_tween().set_parallel(true)
	tw.tween_property(decision_card, "modulate:a", 1.0, 0.18)
	tw.tween_property(decision_card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(0.06).timeout.connect(_place_decision)
	get_tree().create_timer(0.3).timeout.connect(_place_decision)
	if auto_slow and speed_idx > 2:
		_set_speed(2)


func _on_decision(action: String) -> void:
	var c = decision_car
	if c != null and c.is_player and c.state == 1:
		var parts := action.split(":")
		match parts[0]:
			"pit":
				var comp := int(parts[1])
				sim.request_pit(c, comp)
				_radio("Funk an %s: Box, Box! Reifen: %s" % [c.code, RaceSim.COMPOUNDS[comp]["name"]])
				_banner_msg("Box diese Runde: %s" % RaceSim.COMPOUNDS[comp]["name"], 2.0, U.GOOD)
			"rq":
				sim.apply_request(c, parts[1], parts[2])
				_plan_key = "x"
			"later":
				var n := int(parts[1])
				var comp2 := int(parts[2])
				var lap: int = c.floor_laps + 1 + n
				if lap < sim.laps:
					sim.schedule_pit(c, lap, comp2)
					_radio("Funk an %s: Stopp für Ende Runde %d eingeplant (%s)." % [c.code, lap, RaceSim.COMPOUNDS[comp2]["name"]])
					_plan_key = "x"
	_hide_decision()


## Prüft (ein paar Mal pro Sekunde), ob eine Entscheidungskarte angezeigt werden soll oder nicht mehr gilt.
func _check_decisions(delta: float) -> void:
	_dec_check_t += delta
	if _dec_check_t < 0.4:
		return
	_dec_check_t = 0.0
	if sim == null or not sim.started or sim.over:
		if decision_card.visible:
			_hide_decision()
		return
	if decision_card.visible:
		var cur: Dictionary = sim.decision_for(decision_car) if decision_car != null else {}
		if cur.is_empty() or str(cur["key"]) != str(decision_data["key"]):
			_hide_decision()
		return
	if lights_phase != 2:
		return
	for c in sim.cars:
		if not c.is_player:
			continue
		var d: Dictionary = sim.decision_for(c)
		if not d.is_empty() and not decision_seen.has(d["key"]):
			_show_decision(c, d)
			return


# ------------------------------------------------------------------ Seiten des Boxenfunks: Lage, Boxen, Fahren

func _scroll_tab(tab_name: String) -> Array:
	var sc := ScrollContainer.new()
	sc.name = tab_name
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := U.vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return [sc, v]


func _wrap_label(text := "", size := 13, col := U.TEXT, bold := false) -> Label:
	var l := U.label(text, size, col, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Fahrerwahl (Handy: oben auf jeder Seite) mit Positionszeile.
func _driver_bar() -> Control:
	var h := U.hbox(6)
	for c in sim.cars:
		if c.is_player:
			var b := Button.new()
			b.toggle_mode = true
			b.text = c.code
			b.custom_minimum_size = Vector2(62, 30)
			b.add_theme_font_size_override("font_size", 14)
			b.pressed.connect(_select.bind(c))
			h.add_child(b)
			player_buttons.append({"btn": b, "car": c})
	var gl := _wrap_label("", 12, U.MUTED)
	gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gl.custom_minimum_size = Vector2(140, 0)
	gl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(gl)
	gap_labels.append(gl)
	return h


## Schrittüberschrift mit Nummernmarke.
func _step_head(num: String, text: String) -> Control:
	var h := U.hbox(7)
	if num != "":
		h.add_child(U.chip(num, U.PANEL3, U.TEXT))
	h.add_child(U.label(text, 14, U.TEXT, true))
	return h


## Boxenfunk: am PC ein Panel mit drei Reitern, am Handy werden die Seiten eigene Reiter neben Tabelle und Karte.
func _build_control_panel() -> Control:
	var M := U.is_mobile()
	car_title = U.label("", 17, U.TEXT, true)
	car_sub = _wrap_label("", 11, U.MUTED)
	car_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	car_sub.custom_minimum_size = Vector2(60, 0)
	var pages: Array = [_build_page_lage(M), _build_page_pit(M), _build_page_drive(M)]
	if M:
		race_pages = pages
		return null
	var p := U.panel(10, U.WARN)
	p.custom_minimum_size = Vector2(364, 0)
	var v := U.vbox(6)
	p.add_child(v)
	var prow := U.hbox(8)
	v.add_child(prow)
	for c in sim.cars:
		if c.is_player:
			var b := Button.new()
			b.toggle_mode = true
			b.text = c.code
			b.custom_minimum_size = Vector2(66, 36)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.pressed.connect(_select.bind(c))
			prow.add_child(b)
			player_buttons.append({"btn": b, "car": c})
	var th := U.vbox(0)
	th.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prow.add_child(th)
	th.add_child(car_title)
	th.add_child(car_sub)
	var gl := _wrap_label("", 12, U.MUTED)
	th.add_child(gl)
	gap_labels.append(gl)
	race_tabs = TabContainer.new()
	race_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	U.compact_tabs(race_tabs, 14, 15)
	v.add_child(race_tabs)
	for pg in pages:
		race_tabs.add_child(pg)
	return p


func _show_page(title: String) -> void:
	if race_tabs == null:
		return
	if map_big:
		_toggle_map_big()       # Seite muss sichtbar sein
	for i in race_tabs.get_tab_count():
		if race_tabs.get_tab_title(i) == title:
			race_tabs.current_tab = i


## Seite mit zwei Spalten (Handy quer: viel Breite, wenig Höhe) oder einer Spalte (PC). Mit footer: fester Bereich unter der rechten Spalte.
## Rückgabe: [Seitenwurzel, linke Spalte, rechte Spalte]
func _page_cols(page_name: String, M: bool, footer: VBoxContainer = null) -> Array:
	if not M:
		var t := _scroll_tab("Inhalt")
		t[0].size_flags_vertical = Control.SIZE_EXPAND_FILL
		if footer == null:
			t[0].name = page_name
			return [t[0], t[1], t[1]]
		var root := VBoxContainer.new()
		root.name = page_name
		root.add_theme_constant_override("separation", 6)
		root.add_child(t[0])
		root.add_child(footer)
		return [root, t[1], t[1]]
	var h := HBoxContainer.new()
	h.name = page_name
	h.add_theme_constant_override("separation", 8)
	var l := _scroll_tab("Links")
	var r := _scroll_tab("Rechts")
	for t2 in [l, r]:
		t2[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t2[0].size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(l[0])
	if footer == null:
		h.add_child(r[0])
	else:
		var rc := VBoxContainer.new()
		rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rc.add_theme_constant_override("separation", 6)
		rc.add_child(r[0])
		rc.add_child(footer)
		h.add_child(rc)
	return [h, l[1], r[1]]


## Seite "Lage": was ist jetzt wichtig, Rennplan beider Autos, Gegner in der Nähe, Wetter.
func _build_page_lage(M: bool) -> Control:
	var pc := _page_cols("Lage", M)
	var v: VBoxContainer = pc[1]
	var v2: VBoxContainer = pc[2]
	if M:
		v.add_child(_driver_bar())
	var gcard := U.card(9, Color(U.BLUE, 0.07), Color(U.BLUE, 0.3))
	goal_label = _wrap_label("", 13, U.TEXT, true)
	gcard.add_child(goal_label)
	v.add_child(gcard)
	v.add_child(U.section("Jetzt wichtig", 12))
	advice_box = U.vbox(5)
	v.add_child(advice_box)
	v.add_child(U.section("Rennplan", 12))
	ov_info = _wrap_label("", 13, U.TEXT, true)
	v.add_child(ov_info)
	for c in sim.cars:
		if c.is_player:
			var row := U.vbox(2)
			var lb := U.hbox(6)
			lb.add_child(U.color_bar(c.color, 5, 16))
			lb.add_child(U.label("%s" % c.driver_name, 13, U.TEXT, true))
			row.add_child(lb)
			var bar = StintBar.new()
			bar.make_interactive()
			bar.stop_clicked.connect(_on_bar_stop.bind(c))
			row.add_child(bar)
			v.add_child(row)
			ov_bars[c.index] = bar
	v.add_child(_wrap_label("Tipp auf eine Stopp-Marke öffnet die Änderung. Blau: erwarteter Regen, gelb: Safety Car.", 11, U.MUTED))
	v2.add_child(U.section("Gegner-Radar", 12))
	ov_radar_box = U.vbox(3)
	v2.add_child(ov_radar_box)
	var wb := _collapsible(v2, "Wetter und Prognose", false)
	weather_panel = WeatherPanel.new()
	weather_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wb.add_child(weather_panel)
	return pc[0]


## Seite "Boxen": alles für den Stopp an einem Ort. Links Zustand und Plan, rechts der Stopp in Schritten, unten fest der Bestätigen-Knopf.
func _build_page_pit(M: bool) -> Control:
	var footer := U.vbox(5)
	var pc := _page_cols("Boxen", M, footer)
	var v: VBoxContainer = pc[1]
	var v2: VBoxContainer = pc[2]
	if M:
		v.add_child(_driver_bar())

	# 1) Zustand: Stopp-Status, Reifen, Tank
	var hc := U.card(9, Color(U.WARN, 0.07), Color(U.WARN, 0.35))
	var hv := U.vbox(4)
	hc.add_child(hv)
	pit_head = _wrap_label("", 16, U.WARN, true)
	hv.add_child(pit_head)
	pit_win_label = _wrap_label("", 12, U.TEXT)
	hv.add_child(pit_win_label)
	pit_cancel_btn = U.button("Angeforderten Stopp zurücknehmen", _on_cancel_request, 0, 34)
	hv.add_child(pit_cancel_btn)
	v.add_child(hc)

	var sc := U.card(9)
	var sv := U.vbox(4)
	sc.add_child(sv)
	tyre_label = _wrap_label("", 14, U.TEXT, true)
	sv.add_child(tyre_label)
	tyre_bar = ProgressBar.new()
	tyre_bar.max_value = 100.0
	tyre_bar.show_percentage = false
	tyre_bar.custom_minimum_size = Vector2(0, 10)
	sv.add_child(tyre_bar)
	info_label = _wrap_label("", 11, U.MUTED)
	sv.add_child(info_label)
	fuel_label = _wrap_label("", 13, U.TEXT, true)
	sv.add_child(fuel_label)
	fuel_bar = ProgressBar.new()
	fuel_bar.max_value = 100.0
	fuel_bar.show_percentage = false
	fuel_bar.custom_minimum_size = Vector2(0, 8)
	sv.add_child(fuel_bar)

	# 2) Rennplan: Zeitleiste und Stints mit Prüfung
	var rc := U.card(9)
	var rv := U.vbox(5)
	rc.add_child(rv)
	rv.add_child(U.section("Rennplan", 12))
	stint_bar = StintBar.new()
	stint_bar.make_interactive()
	stint_bar.stop_clicked.connect(_on_pit_bar_stop)
	rv.add_child(stint_bar)
	pit_plan_box = U.vbox(4)
	rv.add_child(pit_plan_box)
	pit_note = _wrap_label("", 12, U.BLUE, true)
	rv.add_child(pit_note)
	var clr := U.button("Alle geplanten Stopps löschen", _on_cancel_pit, 0, 30)
	clr.add_theme_font_size_override("font_size", 12)
	rv.add_child(clr)
	v.add_child(rc)
	v.add_child(sc)

	# 3) Stopp planen
	var comp_card := U.card(10)
	var cv := U.vbox(8)
	comp_card.add_child(cv)
	cv.add_child(U.section("Stopp planen", 13))
	pit_edit_label = _wrap_label("", 12, U.BLUE, true)
	cv.add_child(pit_edit_label)
	var erow := U.hbox(5)
	cv.add_child(erow)
	pit_add_btn = U.button("+ Zusätzlicher Stopp", _on_add_stop, 0, 34)
	pit_add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	erow.add_child(pit_add_btn)
	pit_edit_reset = U.button("Verwerfen", _on_edit_reset, 0, 34)
	pit_edit_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	erow.add_child(pit_edit_reset)
	cv.add_child(_step_head("1", "Reifen"))
	var brow := HFlowContainer.new()
	brow.add_theme_constant_override("h_separation", 4)
	brow.add_theme_constant_override("v_separation", 4)
	cv.add_child(brow)
	for k in RaceSim.COMPOUNDS.size():
		var b := Button.new()
		var cd: Dictionary = RaceSim.COMPOUNDS[k]
		b.toggle_mode = true
		b.text = cd["name"]
		b.custom_minimum_size = Vector2(58 if M else 62, 84)
		b.icon = TyreIcon.texture(k, 24)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("h_separation", 2)
		b.add_theme_color_override("font_color", cd["ink"])
		b.add_theme_color_override("font_hover_color", cd["ink"])
		b.add_theme_color_override("font_disabled_color", Color(cd["ink"], 0.35))
		U.tyre_button(b, cd["color"])
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(_on_pit_sel.bind(k))
		brow.add_child(b)
		pit_buttons.append(b)
	pit_outlook = _wrap_label("", 12, U.MUTED)
	cv.add_child(pit_outlook)
	cv.add_child(_step_head("2", "Zeitpunkt"))
	pit_when_box = HFlowContainer.new()
	pit_when_box.add_theme_constant_override("h_separation", 4)
	pit_when_box.add_theme_constant_override("v_separation", 4)
	cv.add_child(pit_when_box)
	pit_fuel_card = U.vbox(5)
	pit_fuel_card.add_child(_step_head("3", "Tanken"))
	fuel_plan = FuelPlanBar.new()
	pit_fuel_card.add_child(fuel_plan)
	var pfr := U.hbox(5)
	pit_fuel_card.add_child(pfr)
	pfr.add_child(U.button("-", _on_pit_fuel.bind(-1), 42, 36))
	pit_fuel_label = _wrap_label("", 14, U.TEXT, true)
	pit_fuel_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pit_fuel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pfr.add_child(pit_fuel_label)
	pfr.add_child(U.button("+", _on_pit_fuel.bind(1), 42, 36))
	var fq := HFlowContainer.new()
	fq.add_theme_constant_override("h_separation", 4)
	fq.add_theme_constant_override("v_separation", 4)
	pit_fuel_card.add_child(fq)
	for i in 2:
		var qb := Button.new()
		qb.toggle_mode = true
		qb.custom_minimum_size = Vector2(110, 36)
		qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qb.add_theme_font_size_override("font_size", 12)
		qb.pressed.connect(_on_pit_fuel_quick.bind(i))
		fq.add_child(qb)
		pit_fuel_quick.append(qb)
	pit_fuel_hint = _wrap_label("", 11, U.MUTED)
	pit_fuel_card.add_child(pit_fuel_hint)
	cv.add_child(pit_fuel_card)
	pit_fuel_card.visible = sim.rules["refuel"]
	var sum_parent: VBoxContainer = cv      # die Vorschau scrollt mit, nur der Bestätigen-Knopf bleibt unten stehen
	sum_parent.add_child(_step_head("", "Vorschau"))
	pit_pred = _wrap_label("", 13, U.TEXT)
	var pc2 := U.card(9, Color(U.BLUE, 0.06), Color(U.BLUE, 0.3))
	pc2.add_child(pit_pred)
	sum_parent.add_child(pc2)
	pit_confirm_btn = U.primary_button("STOPP BESTÄTIGEN", _on_pit_confirm, 0, 40 if M else 48)
	pit_confirm_btn.clip_text = true
	if M:
		pit_confirm_btn.add_theme_font_size_override("font_size", 16)
	footer.add_child(pit_confirm_btn)
	v2.add_child(comp_card)
	pit_status = _wrap_label("", 13, U.GOOD, true)
	v2.add_child(pit_status)

	# 4) Hilfen: Lage an der Box, Undercut, Doppelstopp
	var gb := _collapsible(v, "Hilfen: Rückkehr, Undercut, Doppelstopp", false)
	sc_label = _wrap_label("", 12, U.TEXT)
	gb.add_child(sc_label)
	rejoin_label = _wrap_label("", 12, U.MUTED)
	gb.add_child(rejoin_label)
	uc_label = _wrap_label("", 12, U.TEXT)
	gb.add_child(uc_label)
	threat_label = _wrap_label("", 12, U.TEXT)
	gb.add_child(threat_label)
	uc_btn = U.button("Jetzt stoppen (empfohlene Mischung)", _on_uc_pit, 0, 36)
	gb.add_child(uc_btn)
	radar_label = _wrap_label("", 12, U.TEXT)
	gb.add_child(radar_label)
	gb.add_child(HSeparator.new())
	double_btn = U.button("Doppelstopp (beide Autos)", _on_double, 0, 36)
	gb.add_child(double_btn)
	gb.add_child(_wrap_label("Beide Autos stoppen am Rundenende. Das zweite Auto wartet etwa 2-3 Sekunden.", 11, U.MUTED))
	return pc[0]


## Seite "Fahren": Fahrstil, Abstand, Funkanweisung (links), Energie/Motor, Teamorder, Automatik (rechts).
func _build_page_drive(M: bool) -> Control:
	var pc := _page_cols("Fahren", M)
	var v: VBoxContainer = pc[1]
	var v2: VBoxContainer = pc[2]
	if M:
		v.add_child(_driver_bar())

	v.add_child(U.section("Fahrstil", 12))
	var srow := U.hbox(5)
	v.add_child(srow)
	for i in RaceSim.STYLE_NAMES.size():
		var b := Button.new()
		b.toggle_mode = true
		b.text = ["Schonen", "Ruhig", "Standard", "Zügig", "Angriff"][i]
		b.tooltip_text = RaceSim.STYLE_NAMES[i]
		b.custom_minimum_size = Vector2(0, 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_style.bind(i))
		b.clip_text = M
		srow.add_child(b)
		style_buttons.append(b)
	style_hint = _wrap_label("", 11, U.MUTED)
	v.add_child(style_hint)

	v.add_child(U.section("Abstand zum Vordermann", 12))
	var frow := U.hbox(5)
	v.add_child(frow)
	for i in 2:
		var b := Button.new()
		b.toggle_mode = true
		b.text = ["Abstand halten", "Dranbleiben"][i]
		b.custom_minimum_size = Vector2(0, 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_follow.bind(i == 1))
		b.clip_text = M
		frow.add_child(b)
		follow_buttons.append(b)
	follow_hint = _wrap_label("", 11, U.MUTED)
	v.add_child(follow_hint)

	v.add_child(U.section("Funkanweisung an den Fahrer", 12))
	var rrow := HFlowContainer.new()
	rrow.add_theme_constant_override("h_separation", 4)
	rrow.add_theme_constant_override("v_separation", 4)
	v.add_child(rrow)
	var rdefs := [["push", "Push\n3 Runden"], ["manage", "Reifen managen\n5 Runden"], ["lico", "Lift & Coast\n5 Runden"], ["normal", "Normal"]]
	for d in rdefs:
		var b := Button.new()
		b.text = d[1]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(84, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(_on_radio.bind(str(d[0])))
		rrow.add_child(b)
		radio_buttons.append({"btn": b, "kind": str(d[0])})
	radio_label = _wrap_label("", 11, U.MUTED)
	v.add_child(radio_label)

	# Energie / Motor
	var ec := U.card(9)
	var ev := U.vbox(5)
	ec.add_child(ev)
	ers_head_label = U.label("Energie", 12, U.MUTED, true)
	ev.add_child(ers_head_label)
	ers_bar = ProgressBar.new()
	ers_bar.max_value = 100.0
	ers_bar.show_percentage = false
	ers_bar.custom_minimum_size = Vector2(0, 8)
	ev.add_child(ers_bar)
	var mrow := U.hbox(5)
	ev.add_child(mrow)
	for i in 3:
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_energy_mode.bind(i))
		b.clip_text = M          # Handy: lieber kürzen als die Seite verbreitern
		mrow.add_child(b)
		mode_buttons.append(b)
	mode_hint = _wrap_label("", 11, U.MUTED)
	ev.add_child(mode_hint)
	engine_label = _wrap_label("", 11, U.MUTED)
	ev.add_child(engine_label)
	v2.add_child(ec)

	# Teamorder
	var oc := U.card(9)
	var ov := U.vbox(5)
	oc.add_child(ov)
	ov.add_child(U.label("TEAMORDER", 12, U.MUTED, true))
	to_label = _wrap_label("", 12, U.TEXT)
	ov.add_child(to_label)
	var trow := U.hbox(5)
	ov.add_child(trow)
	var names := ["Platz tauschen", "Position halten", "Aufhalten"]
	var tips := ["Der gewählte Fahrer lässt den Teamkollegen hinter sich vorbei.", "Kein Zweikampf unter Teamkollegen.", "Der gewählte Fahrer bremst einen Verfolger bewusst ein (Schützenhilfe)."]
	for i in 3:
		var b := U.button(names[i], _on_order.bind(i), 0, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 12)
		b.tooltip_text = tips[i]
		b.clip_text = M
		trow.add_child(b)
		order_buttons.append(b)
	order_buttons.append(U.button("Befehle aufheben", _on_order.bind(3), 0, 30))
	ov.add_child(order_buttons[3])
	order_status = _wrap_label("", 11, U.MUTED)
	ov.add_child(order_status)
	v2.add_child(oc)

	# Automatik (eingeklappt)
	var auto_box := _collapsible(v2, "Automatik und Funkanfragen")
	var req_cb := U.checkbox("Fahrer melden sich mit Anfragen (Entscheidungskarten)")
	req_cb.button_pressed = sim.requests_on
	req_cb.toggled.connect(func(on: bool):
		sim.requests_on = on
		Game.requests_on = on)
	auto_box.add_child(req_cb)
	auto_box.add_child(_wrap_label("Das Team handelt automatisch, auch wenn du gerade nicht eingreifst.", 11, U.MUTED))
	var rdefs2 := [["sc_pit", "Safety Car: Stopp holen"], ["rain_switch", "Regen: auf Regenreifen"], ["dry_switch", "Abtrocknen: zurück auf Slicks"], ["defend", "Konter-Stopp bei Undercut-Gefahr"], ["fuel_save", "Sprit automatisch sparen"]]
	for d2 in rdefs2:
		var cb := U.checkbox(str(d2[1]))
		cb.toggled.connect(_on_rule.bind(str(d2[0])))
		auto_box.add_child(cb)
		rule_checks[str(d2[0])] = cb
	return pc[0]


## Einklappbarer Bereich: Kopfzeile zum Antippen, Inhalt darunter. Rückgabe: Inhalts-Box.
func _collapsible(parent: VBoxContainer, title: String, open := false) -> VBoxContainer:
	var holder := U.vbox(4)
	var content := U.vbox(5)
	content.visible = open
	var head := Button.new()
	head.toggle_mode = true
	head.button_pressed = open
	head.text = ("%s   [-]" if open else "%s   [+]") % title
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.custom_minimum_size = Vector2(0, 38)
	head.add_theme_font_size_override("font_size", 14)
	head.toggled.connect(func(on: bool):
		content.visible = on
		head.text = ("%s   [-]" if on else "%s   [+]") % title)
	holder.add_child(head)
	holder.add_child(content)
	parent.add_child(holder)
	return content


func _on_bar_stop(lap: int, c) -> void:
	_select(c)
	for s in c.plan:
		if int(s["lap"]) == lap:
			_on_edit_plan(lap, int(s["comp"]))
			_open_pit_tab()
			return


func _update_overview() -> void:
	var c = selected if selected != null else _action_car()
	if c == null:
		return
	var rain: Array = []
	var fr: Dictionary = sim.forecast_report(16)
	for b in fr.get("bins", []):
		rain.append({"lap0": int(b["lap0"]), "lap1": int(b["lap1"]), "i": float(b["i"])})
	stint_bar.set_extras(rain, sim.sc_marks)
	for pc in sim.cars:
		if pc.is_player and ov_bars.has(pc.index):
			var bar = ov_bars[pc.index]
			bar.laps = sim.laps
			bar.segments = sim.stint_segments(pc, pc.floor_laps)
			bar.set_cur_lap(pc.floor_laps)
			bar.set_extras(rain, sim.sc_marks)
			bar.queue_redraw()
	var rk: Array = sim.ranking()
	var pos := rk.find(c)
	var txt := "%s: P%d" % [c.code, pos + 1]
	if c.state == 1:
		var nxt := -1
		for s in c.plan:
			if int(s["lap"]) > c.floor_laps and (nxt < 0 or int(s["lap"]) < nxt):
				nxt = int(s["lap"])
		txt += "  |  Reifen %s, %d Rd. alt" % [RaceSim.COMPOUNDS[c.compound]["name"], c.tyre_age_laps]
		txt += ("  |  nächster Stopp: Ende R%d" % nxt) if nxt > 0 else "  |  kein Stopp geplant"
	ov_info.text = txt
	# Gegner-Radar: Autos rund um die eigene Position
	var rows: Array = []
	for i in range(maxi(0, pos - 4), mini(rk.size(), pos + 5)):
		var r = rk[i]
		if r == c or r.state == 3 or r.state == 4:
			continue
		var o: Dictionary = sim.rival_outlook(r, c)
		rows.append({"r": r, "o": o, "rank": i + 1})
	var key := ""
	for e in rows:
		var rr = e["r"]
		key += "%s|%d|%d|%s|%d;" % [rr.code, rr.compound, rr.tyre_age_laps, str(e["o"]["stop_lap"]), int(absf(rr.gap_leader - c.gap_leader) * 2.0)]
	if key == ov_radar_key:
		return
	ov_radar_key = key
	U.clear(ov_radar_box)
	if rows.is_empty():
		ov_radar_box.add_child(_wrap_label("Keine Gegner in der Nähe.", 12, U.MUTED))
		return
	for e in rows:
		var r = e["r"]
		var o: Dictionary = e["o"]
		var card := U.card(6, Color(U.BAD, 0.08) if bool(o["threat"]) else U.tint(0.035), Color(U.BAD, 0.5) if bool(o["threat"]) else U.tint(0.08))
		var h := U.hbox(6)
		card.add_child(h)
		var rl := U.label("P%d" % int(e["rank"]), 13, U.MUTED, true)
		rl.custom_minimum_size = Vector2(30, 0)
		h.add_child(rl)
		h.add_child(U.color_bar(r.color, 5, 28))
		var mid := U.vbox(0)
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var gap: float = r.gap_leader - c.gap_leader
		var gtxt := ("%.1f s vor dir" % -gap) if gap < 0.0 else ("%.1f s hinter dir" % gap)
		mid.add_child(U.label("%s   %s" % [r.code, gtxt], 14, U.TEXT, true))
		var cd: Dictionary = RaceSim.COMPOUNDS[r.compound]
		var sub := _wrap_label("%s %d Rd.  |  %d %% Rest  |  %s" % [cd["name"], r.tyre_age_laps, int(float(o["rest"]) * 100.0), o["text"]], 11, U.MUTED)
		mid.add_child(sub)
		h.add_child(mid)
		if bool(o["threat"]):
			h.add_child(U.chip("UNDERCUT", U.BAD, U.INK))
		ov_radar_box.add_child(card)



func _on_energy_mode(i: int) -> void:
	if selected == null or not selected.is_player:
		return
	if sim.has_ers():
		sim.set_ers_mode(selected, i)
	else:
		sim.set_engine_mode(selected, i)


func _on_radio(kind: String) -> void:
	if selected != null and selected.is_player and selected.state == 1:
		sim.radio_order(selected, kind)


func _on_rule(on: bool, key: String) -> void:
	for c in sim.cars:
		if c.is_player:
			sim.set_rule(c, key, on)


func _on_follow(on: bool) -> void:
	if selected != null and selected.is_player:
		selected.follow = on


func _on_order(i: int) -> void:
	if selected == null or not selected.is_player:
		return
	var msg := ""
	match i:
		0:
			msg = sim.order_swap(selected)
		1:
			msg = sim.order_hold(selected)
		2:
			msg = sim.order_block(selected)
		3:
			sim.clear_orders(selected)
	order_msg = msg


func _radio(text: String) -> void:
	log_lines.append("[color=#8a93a8]R%02d[/color]  [color=#b86f00]%s[/color]" % [sim.leader_lap(), text])


func _on_uc_pit() -> void:
	if selected == null or not selected.is_player or selected.state != 1:
		return
	var info: Dictionary = sim.undercut_info(selected)
	var comp: int = info["comp"] if info["has"] else sim.suggest_comp(selected)
	sim.request_pit(selected, comp)
	_radio("Funk an %s: Undercut! Box, Box! Reifen: %s" % [selected.code, RaceSim.COMPOUNDS[comp]["name"]])


func _on_double() -> void:
	if selected == null or not selected.is_player or selected.state != 1:
		return
	var comp: int = selected.pit_comp if selected.pit_requested else sim.suggest_comp(selected)
	sim.double_stop(selected, comp)
	_radio("Funk: Doppelstopp! Beide Autos kommen rein (%s)." % RaceSim.COMPOUNDS[comp]["name"])


## Ausführung einer Empfehlung aus der Taktik-Liste.
func _on_advice(action: String) -> void:
	var c = selected
	if c == null or not c.is_player or c.state != 1:
		return
	match action:
		"style_save":
			sim.set_style(c, 0)
			_radio("Funk an %s: Sprit sparen!" % c.code)
		"pit_now", "pit_wet", "pit_slick":
			var comp: int = sim.suggest_comp(c)
			if action == "pit_slick":
				comp = sim._choose_comp(c, sim.laps - sim.leader_lap())
			sim.request_pit(c, comp)
			_radio("Funk an %s: Box, Box! Reifen: %s" % [c.code, RaceSim.COMPOUNDS[comp]["name"]])
		"pit_inter":
			sim.request_pit(c, 3)
			_radio("Funk an %s: Box, Box! Wir wetten auf Intermediates." % c.code)
		"undercut":
			_on_uc_pit()
		"ers_normal":
			sim.set_ers_mode(c, 1)
		"ers_attack":
			sim.set_ers_mode(c, 2)
		"swap":
			sim.order_swap(c)


func _on_pit_sel(k: int) -> void:
	pit_sel = k
	pit_touched = true
	# gewählter Reifen federt kurz auf, die Vorschau blendet neu ein
	if U.fx_on() and k < pit_buttons.size():
		var b: Button = pit_buttons[k]
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(1.12, 1.12), 0.08)
		tw.tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if pit_outlook != null:
			pit_outlook.modulate.a = 0.0
			pit_outlook.create_tween().tween_property(pit_outlook, "modulate:a", 1.0, 0.3)


## Zeitpunkt wählen (nur Auswahl, ausgeführt wird erst mit "Stopp bestätigen").
func _on_when(lap: int) -> void:
	pit_when_lap = lap
	pit_when_key = ""
	pit_touched = true


## Beschreibung einer Mischung für den Stopp-Assistenten: Tempo, Abbau, Aufwärmen, Haltbarkeit, Sätze.
func _compound_text(c, k: int, oc: Dictionary) -> String:
	var cd: Dictionary = RaceSim.COMPOUNDS[k]
	var t: String = "%s hält ca. %d Runden%s." % [cd["name"], int(oc["life"]), " und reicht bis ins Ziel" if oc["to_end"] else ""]
	if k < RaceSim.DRY_COUNT:
		var off: float = float(cd["offset"]) * sim.scale_time
		var deg: float = float(cd["deg"]) * sim.track.tyre_severity * sim.scale_time
		var warm := "wärmt schnell auf" if k == 0 else ("wärmt normal auf" if k == 1 else "wärmt langsam auf (Ausfahrt ca. %.1f s langsamer)" % (float(cd["warm"]) * sim.scale_time))
		t += " %s ggü. Soft, jede Runde %.2f s langsamer, %s." % ["Gleiche Pace" if k == 0 else "%+.1f s pro Runde" % off, deg, warm]
	if not sim.tyre_unlimited():
		t += " Frei: %d Sätze." % int(sim.tyre_count(c, k)["free"])
	return t + "  * = Empfehlung, OK = reicht bis ins Ziel."


## Mischung des geplanten Stopps am Ende von Runde lap (-1 = keiner).
func _plan_comp(c, lap: int) -> int:
	for s in c.plan:
		if int(s["lap"]) == lap:
			return int(s["comp"])
	return -1


## Gewählte Stopp-Runde (Ende der Runde): mindestens die laufende Runde.
func _pit_sel_lap(c) -> int:
	var now_lap: int = c.floor_laps + 1
	return pit_when_lap if pit_when_lap >= now_lap else now_lap


## Geplante Stopps, die ein Stopp in Runde lap (mit Mischung comp) überflüssig macht.
func _dropped_stops(c, lap: int, comp: int) -> Array:
	var info: Dictionary = sim.adapt_info(c, lap, comp)
	var keep_laps := {}
	for s in info["keep"]:
		keep_laps[int(s["lap"])] = true
	var out: Array = []
	for s in c.plan:
		var l := int(s["lap"])
		if l > lap and not keep_laps.has(l) and l != pit_edit_lap:
			out.append(l)
	out.sort()
	return out


## Stopp bestätigen: am Rundenende anfordern oder für eine spätere Runde einplanen.
func _on_pit_confirm() -> void:
	var c = selected
	if c == null or not c.is_player or c.state != 1:
		return
	var now_lap: int = c.floor_laps + 1
	var lap: int = _pit_sel_lap(c)
	var comp: int = pit_sel if pit_sel >= 0 else sim.suggest_comp(c)
	var carry := {}                    # Tank-Extra des bearbeiteten Stopps mitnehmen
	if pit_edit_lap > 0:
		for s in c.plan:
			if int(s["lap"]) == pit_edit_lap:
				carry = s
		sim.unschedule_pit(c, pit_edit_lap)
	if lap <= now_lap:
		sim.request_pit(c, comp)      # der Plan wird beim Stopp angepasst (ein ersetzter Stopp entfällt)
		_radio("Funk an %s: Box, Box! Reifen: %s" % [c.code, RaceSim.COMPOUNDS[comp]["name"]])
		_banner_msg("Box diese Runde: %s" % RaceSim.COMPOUNDS[comp]["name"], 2.0, U.GOOD)
	else:
		if lap >= sim.laps:
			return
		for dl in _dropped_stops(c, lap, comp):
			sim.unschedule_pit(c, int(dl))
		sim.schedule_pit(c, lap, comp)
		if carry.has("fuel"):
			for s2 in c.plan:
				if int(s2["lap"]) == lap:
					s2["fuel"] = carry["fuel"]
		_radio("Funk an %s: Stopp für Ende Runde %d eingeplant (%s)." % [c.code, lap, RaceSim.COMPOUNDS[comp]["name"]])
		_banner_msg("Stopp Runde %d: %s" % [lap, RaceSim.COMPOUNDS[comp]["name"]], 2.0, U.GOOD)
	pit_edit_lap = -1
	pit_when_lap = -1
	pit_when_key = ""
	pit_auto_key = ""
	pit_touched = false
	pit_plan_sig = ""
	_plan_key = "x"


## Geplanten Stopp bearbeiten: Reifen und Zeitpunkt in die Auswahl laden, die alte Planung bleibt bis zum Bestätigen.
func _on_edit_plan(lap: int, comp: int) -> void:
	pit_edit_lap = lap
	pit_sel = comp
	pit_when_lap = lap
	pit_when_key = ""
	pit_touched = true
	_plan_key = "x"


## Neuen Stopp zusätzlich zu den geplanten anlegen (statt den nächsten geplanten zu ändern).
func _on_add_stop() -> void:
	pit_edit_lap = -1
	pit_when_lap = -1          # wird auf die laufende Runde gesetzt
	pit_touched = true
	pit_when_key = ""
	_plan_key = "x"


func _on_edit_reset() -> void:
	pit_edit_lap = -1
	pit_when_lap = -1
	pit_when_key = ""
	pit_auto_key = ""
	pit_touched = false
	pit_plan_sig = ""
	_plan_key = "x"


## Antippen einer Stopp-Marke in der Zeitleiste der Boxen-Seite.
func _on_pit_bar_stop(lap: int) -> void:
	var c = selected if selected != null and selected.is_player else _action_car()
	if c == null:
		return
	for s in c.plan:
		if int(s["lap"]) == lap:
			_on_edit_plan(lap, int(s["comp"]))
			return


func _on_cancel_request() -> void:
	if selected != null and selected.is_player:
		sim.cancel_pit(selected)


func _on_pit_fuel(d: int) -> void:
	var c = selected
	if c == null or not c.is_player:
		return
	var base: float = c.pit_fuel_laps
	if base < 0.0:
		base = float(_auto_fuel_laps(c, _pit_sel_lap(c), pit_sel if pit_sel >= 0 else sim.suggest_comp(c)))
	c.pit_fuel_laps = clampf(base + float(d), 1.0, 90.0)


## Schnellwahl der Spritmenge: 0 = bis zum nächsten Stopp (automatisch), 1 = bis ins Ziel.
func _on_pit_fuel_quick(i: int) -> void:
	var c = selected
	if c == null or not c.is_player:
		return
	if i == 0:
		c.pit_fuel_laps = -1.0
	else:
		c.pit_fuel_laps = float(maxi(1, sim.laps - _pit_sel_lap(c)))


## Runden Sprit, die der Stopp in Runde sel_lap automatisch tankt (bis zum nächsten verbleibenden Stopp bzw. Ziel).
func _auto_fuel_laps(c, sel_lap: int, comp: int) -> int:
	var info: Dictionary = sim.adapt_info(c, sel_lap, comp)
	return maxi(1, int(info["next"]) - sel_lap)


func _update_advice(c) -> void:
	var items: Array = sim.advice(c) if c.state == 1 else []
	var key := ""
	for a in items:
		key += "%s|%s|%s;" % [a["title"], a["level"], a["text"]]
	if key == _advice_key:
		return
	_advice_key = key
	U.clear(advice_box)
	if items.is_empty():
		advice_box.add_child(_wrap_label("Alles im grünen Bereich. Hier erscheinen Hinweise zu Boxenstopps, Wetter, Sprit und Gegnern.", 12, U.MUTED))
		return
	for a in items:
		var col := {"bad": U.BAD, "warn": U.WARN, "good": U.GOOD, "info": U.BLUE}[a["level"]] as Color
		var card := U.card(8, Color(col, 0.10), Color(col, 0.55))
		var h := U.hbox(8)
		card.add_child(h)
		var v := U.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(_wrap_label(str(a["title"]), 14, col, true))
		v.add_child(_wrap_label(str(a["text"]), 12, U.TEXT))
		if str(a.get("action", "")) != "":
			var b := U.button(str(a["label"]), _on_advice.bind(str(a["action"])), 96, 40)
			b.add_theme_font_size_override("font_size", 13)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(b)
		advice_box.add_child(card)


func _update_tactics() -> void:
	var c = selected
	if c == null or not c.is_player:
		return
	var racing: bool = c.state == 1
	_update_advice(c)
	# Energie / Motor
	if sim.has_ers():
		ers_head_label.text = "BATTERIE (ERS) %d %%" % int(c.ers)
		ers_bar.visible = true
		ers_bar.value = c.ers
		var ec: Color = U.GOOD if c.ers > 30.0 else (U.WARN if c.ers > 10.0 else U.BAD)
		ers_bar.add_theme_stylebox_override("fill", U.button_style(ec, ec, 0, 5))
		for i in 3:
			mode_buttons[i].text = RaceSim.ERS_NAMES[i]
			mode_buttons[i].set_pressed_no_signal(i == c.ers_mode)
			mode_buttons[i].disabled = not racing
		mode_hint.text = "Laden: Batterie füllen, etwas langsamer.  Angriff: schneller, hilft beim Überholen und Verteidigen, leert die Batterie."
	else:
		ers_head_label.text = "MOTORMODUS"
		ers_bar.visible = false
		for i in 3:
			mode_buttons[i].text = RaceSim.ENG_NAMES[i]
			mode_buttons[i].set_pressed_no_signal(i == c.eng_mode)
			mode_buttons[i].disabled = not racing
		mode_hint.text = "Eco: langsamer, schont Motor und Sprit.  Power: schneller, aber mehr Verschleiß und Defektrisiko."
	if sim.engine_allowance > 0:
		var wcol := "ok"
		if c.engine_wear > 1.0:
			wcol = "KRITISCH"
		elif c.engine_wear > 0.8:
			wcol = "hoch"
		engine_label.text = "Motor %d von %d, Verschleiß %d %% (%s)" % [c.engines_used, sim.engine_allowance, int(c.engine_wear * 100.0), wcol]
	else:
		engine_label.text = ""
	engine_label.text += ("\n" if engine_label.text != "" else "") + "Setup: Abweichung %.2f vom Optimum (%.2f %% Pace)" % [c.setup_err, c.setup_pen_race * 100.0]
	# Undercut
	var info: Dictionary = sim.undercut_info(c) if racing else {"has": false}
	uc_btn.disabled = not racing
	if info["has"]:
		var a = info["car"]
		var mcol := U.GOOD if info["margin"] > 0.8 else (U.WARN if info["margin"] > -0.5 else U.BAD)
		var verdict := "Undercut sollte klappen" if info["margin"] > 0.8 else ("knapp" if info["margin"] > -0.5 else "lohnt sich nicht")
		uc_label.text = "Vor dir: %s, %.1f s, Reifen %d Rd. alt.\nUndercut auf %s: %+.1f s  (%s)" % [a.code, info["gap"], a.tyre_age_laps, RaceSim.COMPOUNDS[info["comp"]]["name"], info["margin"], verdict]
		uc_label.add_theme_color_override("font_color", mcol)
	else:
		uc_label.text = "Kein Gegner in Reichweite für einen Undercut."
		uc_label.add_theme_color_override("font_color", U.MUTED)
	var th: Dictionary = sim.threat_info(c) if racing else {"has": false}
	if th["has"] and th["margin"] > -0.3:
		threat_label.text = "ACHTUNG: %s (%.1f s hinter dir) kann dich per Undercut überholen (%+.1f s)." % [th["car"].code, th["gap"], th["margin"]]
		threat_label.add_theme_color_override("font_color", U.BAD)
	elif th["has"]:
		threat_label.text = "Hinter dir: %s, %.1f s. Kein Undercut-Risiko." % [th["car"].code, th["gap"]]
		threat_label.add_theme_color_override("font_color", U.MUTED)
	else:
		threat_label.text = ""
	if racing:
		var rj: Dictionary = sim.rejoin_info(c)
		var t := "Boxenstopp jetzt: %.0f s Verlust, Rückkehr auf P%d" % [rj["loss"], rj["pos"]]
		if rj["ahead"] != null:
			t += " hinter %s (+%.1f s)" % [rj["ahead"].code, rj["gap_ahead"]]
		if rj["behind"] != null and rj["gap_behind"] < 2.0:
			t += ", Verkehr: %s dicht dahinter" % rj["behind"].code
		rejoin_label.text = t
	else:
		rejoin_label.text = ""
	# Teamorder
	var mate = sim.mate_of(c)
	if mate != null and mate.state != 3 and racing:
		var rk: Array = sim.ranking()
		to_label.text = "Teamkollege %s: P%d (du P%d), Abstand %.1f s" % [mate.code, rk.find(mate) + 1, rk.find(c) + 1, absf(c.gap_leader - mate.gap_leader)]
		for i in 4:
			order_buttons[i].disabled = false
		order_buttons[0].disabled = c.dist < mate.dist
	else:
		to_label.text = "Kein Teamkollege im Rennen."
		for i in 4:
			order_buttons[i].disabled = true
	var os := order_msg
	if not c.order.is_empty():
		os = "Aktiv: %s" % sim._order_name(str(c.order["type"]))
		var mt = sim.mate_of(c)
		if mt != null and not mt.order.is_empty() and mt.order["type"] != c.order["type"]:
			os += " (Teamkollege: %s)" % sim._order_name(str(mt.order["type"]))
	order_status.text = os
	# Gambles
	if sim.status != 0:
		var normal: float = sim.track.pit_loss * float(sim.rules["pit_loss_scale"])
		sc_label.text = "%s: Boxenstopp kostet jetzt nur %.0f s statt %.0f s." % ["Safety Car" if sim.status == 2 else "VSC", sim.pit_cost_now(), normal]
		sc_label.add_theme_color_override("font_color", U.WARN)
	else:
		sc_label.text = "Unter Safety Car oder VSC sind Stopps billiger."
		sc_label.add_theme_color_override("font_color", U.MUTED)
	var rd: Dictionary = sim.rain_radar()
	if float(rd["eta"]) > 0.0:
		radar_label.text = "Wetterradar: Regen in ca. %d min, Wahrscheinlichkeit %d %%. Wette: früh auf Inter stoppen? Fehlalarme kommen vor." % [int(rd["eta"]), int(float(rd["prob"]) * 100.0)]
		radar_label.add_theme_color_override("font_color", U.BLUE)
	else:
		radar_label.text = "Wetterradar: keine Zelle in Sicht."
		radar_label.add_theme_color_override("font_color", U.MUTED)
	double_btn.disabled = not racing or mate == null or mate.state != 1


func _state_color(st: String) -> Color:
	return U.GOOD if st == "ok" else (U.WARN if st == "tight" else U.BAD)


func _state_word(st: String) -> String:
	return {"ok": "OK", "tight": "KNAPP", "long": "ZU LANG", "fuel": "SPRIT"}.get(st, "OK")


## Zeile im Rennplan: Stopp (oder Ziel) mit Prüfung, ob der Reifen den Stint durchhält.
func _plan_row(e: Dictionary) -> Control:
	var stop_lap := int(e["lap"])
	var is_end: bool = int(e["comp"]) < 0
	var sc: Dictionary = RaceSim.COMPOUNDS[int(e["stint_comp"])]
	var st := str(e["state"])
	var scol := _state_color(st)
	var editing: bool = not is_end and stop_lap == pit_edit_lap
	var card := U.card(7, Color(U.BLUE, 0.08) if editing else U.tint(0.035), Color(U.BLUE, 0.55) if editing else U.tint(0.09))
	var v := U.vbox(2)
	card.add_child(v)
	var top := U.hbox(6)
	v.add_child(top)
	if is_end:
		top.add_child(U.label("Ziel (Runde %d)" % sim.laps, 14, U.TEXT, true))
	else:
		top.add_child(U.label("Ende R%d" % stop_lap, 14, U.TEXT, true))
		var nc: Dictionary = RaceSim.COMPOUNDS[int(e["comp"])]
		top.add_child(U.label("-> %s" % nc["name"], 14, nc["ink"], true))
	top.add_child(U.spacer())
	if st != "ok" or not is_end:
		top.add_child(U.chip(_state_word(st), scol, U.INK))
	if not is_end:
		top.add_child(U.button("Ändern", _on_edit_plan.bind(stop_lap, int(e["comp"])), 66, 30))
		top.add_child(U.button("x", _on_unplan.bind(stop_lap), 34, 30))
	var sub := "%s: %d Rd. bis dahin, hält ca. %d Rd." % [sc["name"], int(e["run"]), maxi(0, int(e["cap"]))]
	if st == "fuel":
		sub = "Der Tank reicht nur noch %.1f Rd., bis dahin sind es %d. Früher stoppen oder Sprit sparen!" % [float(e["fuel_cap"]), int(e["run"])]
	v.add_child(_wrap_label(sub, 11, U.BAD if st == "fuel" else U.MUTED))
	return card


## Auto, Fahren und Boxen aktualisieren.
func _update_car_pit(c) -> void:
	var cd: Dictionary = RaceSim.COMPOUNDS[c.compound]
	var life: float = sim.life_eff(c.compound)
	var left := clampf(1.0 - c.tyre_wear / life, 0.0, 1.0)
	var rate_now: float = maxf(sim.wear_rate_now(c), 0.2)
	var holds: int = int(maxf(0.0, (life - c.tyre_wear) / rate_now))
	tyre_label.text = "%s, %d Rd. alt, Rest %d %% (hält noch ca. %d Rd.)" % [cd["name"], c.tyre_age_laps, int(left * 100.0), holds]
	tyre_label.add_theme_color_override("font_color", cd["ink"])
	tyre_bar.value = left * 100.0
	var fc: Color = Color(1, 0.3, 0.25).lerp(Color(0.2, 0.9, 0.45), clampf(left * 1.5, 0.0, 1.0))
	tyre_bar.add_theme_stylebox_override("fill", U.button_style(fc, fc, 0, 5))
	stint_bar.set_cur_lap(c.floor_laps)
	var segs: Array = sim.stint_segments(c, c.floor_laps)
	var skey := str(segs)
	if skey != _seg_key:
		_seg_key = skey
		stint_bar.laps = sim.laps
		stint_bar.segments = segs
		stint_bar.queue_redraw()
	var loss: float = sim.tyre_loss(c)
	info_label.text = "Letzte %s   Beste %s   Reifenverlust %.2f s/Rd.   Verschleiß %.2fx" % [sim.fmt_time(c.last_lap), sim.fmt_time(c.best_lap), loss, sim.wear_rate_now(c)]
	# Tank
	var rng_l: float = sim.fuel_range(c)
	var need: float = sim.fuel_need(c)
	var fcol := U.GOOD if rng_l >= need + 0.3 else (U.WARN if rng_l >= need else U.BAD)
	fuel_label.text = "Tank: %.1f kg, reicht noch %.1f Rd. (Bedarf bis %s: %.1f)" % [c.fuel, rng_l, "Stopp" if sim.rules["refuel"] and need < sim.laps - c.floor_laps else "Ziel", need]
	fuel_label.add_theme_color_override("font_color", fcol)
	fuel_bar.value = clampf(c.fuel / sim.fuel_cap() * 100.0, 0.0, 100.0)
	fuel_bar.add_theme_stylebox_override("fill", U.button_style(fcol, fcol, 0, 5))
	# Fahrstil und Abstand
	for i in style_buttons.size():
		style_buttons[i].set_pressed_no_signal(i == c.style)
		style_buttons[i].disabled = c.state == 3 or c.state == 4
	if c.style == RaceSim.STYLE_STD:
		style_hint.text = "Standard: ausgewogen."
	else:
		style_hint.text = "%s: %+.2f s pro Runde, Reifenverschleiß %+d %%, Sprit %+d %%, Reifen %s." % [RaceSim.STYLE_NAMES[c.style], -RaceSim.STYLE_PACE[c.style] * sim.track.lap_ref, int(round((RaceSim.STYLE_WEAR[c.style] - 1.0) * 100.0)), int(round((RaceSim.STYLE_FUEL[c.style] - 1.0) * 100.0)), "kühler" if c.style < RaceSim.STYLE_STD else "heißer"]
	for rb in radio_buttons:
		rb["btn"].set_pressed_no_signal(c.radio_kind == rb["kind"] or (rb["kind"] == "normal" and c.radio_kind == ""))
		rb["btn"].disabled = c.state != 1
	if c.radio_kind != "":
		radio_label.text = "Aktiv bis Ende Runde %d." % c.radio_until
	else:
		radio_label.text = "Push: schneller, mehr Verschleiß. Reifen managen: langsamer, schont. Lift & Coast: spart Sprit. Der Fahrer meldet sich bei nachlassenden Reifen."
	for key in rule_checks.keys():
		rule_checks[key].set_pressed_no_signal(bool(c.rules.get(key, false)))
	follow_buttons[0].set_pressed_no_signal(not c.follow)
	follow_buttons[1].set_pressed_no_signal(c.follow)
	var fh := "Dranbleiben: Windschatten auf Geraden, mehr Überholchancen, aber verwirbelte Luft kostet in Kurven Reifen."
	if not c.follow:
		fh = "Abstand halten: ca. 1,6 s hinter dem Vordermann, keine Zweikämpfe, Reifen werden geschont."
	elif c.tow > 0.05 and c.state == 1:
		fh = "Im Windschatten: +%d %% Windschatten-Wirkung. %s" % [int(c.tow * 100.0), "Mit DRS/Batterie angreifen!" if c.gap_ahead < 1.0 else ""]
	follow_hint.text = fh

	# Boxen-Seite: Status, Rennplan mit Prüfung, Auswahl in Schritten
	var now_lap: int = c.floor_laps + 1
	var racing: bool = c.state == 1
	var win: Dictionary = sim.pit_window_info(c, now_lap) if racing else {"need": false, "text": "", "frac": 0.0, "ideal": now_lap, "open": now_lap, "close": now_lap}
	var checks: Array = sim.plan_check(c) if racing else []
	var nxt := -1
	for s in c.plan:
		if int(s["lap"]) > c.floor_laps and (nxt < 0 or int(s["lap"]) < nxt):
			nxt = int(s["lap"])
	if c.pit_requested:
		pit_head.text = "BOX DIESE RUNDE: %s" % RaceSim.COMPOUNDS[c.pit_comp]["name"].to_upper()
		pit_head.add_theme_color_override("font_color", U.GOOD)
	elif c.state == 2:
		pit_head.text = "In der Box ..."
		pit_head.add_theme_color_override("font_color", U.WARN)
	else:
		pit_head.add_theme_color_override("font_color", U.WARN)
		pit_head.text = ("Nächster Stopp: Ende Runde %d" % nxt) if nxt > 0 else ("Kein Stopp geplant" if not bool(win["need"]) else "Stopp nötig, noch nichts geplant")
	pit_cancel_btn.visible = c.pit_requested
	# Fenster nur, wenn nichts geplant ist (sonst zeigt der Rennplan die Prüfung je Stint)
	if nxt > 0 and not checks.is_empty():
		var e0: Dictionary = checks[0]
		if str(e0["state"]) == "fuel":
			pit_win_label.text = "ACHTUNG: Der Tank reicht nur noch %.1f Rd., bis zum Stopp sind es %d." % [float(e0["fuel_cap"]), int(e0["run"])]
		else:
			pit_win_label.text = "Bis dahin %d Rd. auf %s, die Reifen halten ca. %d Rd.: %s." % [int(e0["run"]), RaceSim.COMPOUNDS[int(e0["stint_comp"])]["name"], maxi(0, int(e0["cap"])), _state_word(str(e0["state"])).to_lower()]
		pit_win_label.add_theme_color_override("font_color", _state_color(str(e0["state"])))
	else:
		pit_win_label.text = str(win["text"])
		pit_win_label.add_theme_color_override("font_color", U.TEXT)
	if sim.wet > 0.1 or sim.rain > 0.05:
		pit_win_label.text += "\nRegen: Reifenwahl nach Streckennässe (%d %%)." % int(sim.wet * 100.0)
	if bool(win["need"]) and nxt < 0 and racing:
		stint_bar.set_window(int(win["open"]), int(win["ideal"]), int(win["close"]))
	else:
		stint_bar.set_window(0, 0, 0)
	# Standardvorschlag einmal pro Runde setzen, solange der Spieler nichts gewählt hat
	var sug: int = sim.suggest_comp(c) if racing else 1
	var def_lap: int = now_lap
	if bool(win["need"]) and int(win["ideal"]) > now_lap and float(win["frac"]) < 0.85:
		def_lap = mini(int(win["ideal"]), sim.laps - 1)
	# Assistent: vorbelegt mit dem nächsten geplanten Stopp, sonst mit dem Vorschlag aus dem Stopp-Fenster
	var nxt_comp := _plan_comp(c, nxt)
	var psig := "%d|%d|%d" % [c.pit_stops, nxt, nxt_comp]
	if pit_edit_lap > 0 and _plan_comp(c, pit_edit_lap) < 0:
		pit_touched = false           # der bearbeitete Stopp existiert nicht mehr (ersetzt oder gefahren)
		pit_plan_sig = ""
	if (not pit_touched and psig != pit_plan_sig) or pit_sel < 0:
		pit_plan_sig = psig
		pit_when_key = ""
		if nxt > 0:
			pit_edit_lap = nxt
			pit_sel = nxt_comp
			pit_when_lap = nxt
		else:
			pit_edit_lap = -1
			pit_sel = sug
			pit_when_lap = def_lap
	if pit_when_lap < now_lap:
		pit_when_lap = now_lap
	for k in pit_buttons.size():
		var o: Dictionary = sim.compound_outlook(c, k)
		var tt: String = RaceSim.COMPOUNDS[k]["name"]
		if k < RaceSim.DRY_COUNT:
			var off: float = float(RaceSim.COMPOUNDS[k]["offset"]) * sim.scale_time
			tt += "\n" + ("±0 s" if k == 0 else "+%.1f s" % off)
		tt += "\n%d Rd%s" % [int(o["life"]), (" OK" if o["to_end"] else "")]
		if k == sug:
			tt += " *"
		pit_buttons[k].text = tt
		pit_buttons[k].set_pressed_no_signal(k == pit_sel)
		pit_buttons[k].disabled = not racing
	var oc: Dictionary = sim.compound_outlook(c, pit_sel)
	pit_outlook.text = _compound_text(c, pit_sel, oc)
	# Zeitpunkt-Auswahl (nur neu aufbauen, wenn sich die Optionen ändern)
	var opts: Array = []
	for off in [0, 2, 4, 6]:
		var l: int = now_lap + off
		if l < sim.laps:
			opts.append({"lap": l, "t": ("Jetzt\nEnde R%d" % l) if off == 0 else ("R%d\nin %d Rd." % [l, off])})
	if bool(win["need"]) and nxt < 0 and int(win["ideal"]) > now_lap and int(win["ideal"]) < sim.laps:
		var il: int = int(win["ideal"])
		var dup := false
		for o2 in opts:
			if int(o2["lap"]) == il:
				o2["t"] = "%s\nempfohlen" % str(o2["t"]).split("\n")[0]
				dup = true
		if not dup:
			opts.append({"lap": il, "t": "R%d\nempfohlen" % il})
	if pit_edit_lap > 0:
		var has := false
		for o3 in opts:
			if int(o3["lap"]) == pit_edit_lap:
				has = true
		if not has:
			opts.append({"lap": pit_edit_lap, "t": "R%d\ngeplant" % pit_edit_lap})
	opts.sort_custom(func(a, b): return int(a["lap"]) < int(b["lap"]))
	var wkey := "%d|%d|%s|%d" % [now_lap, pit_when_lap, str(opts.size()), int(racing)]
	if wkey != pit_when_key:
		pit_when_key = wkey
		# Knöpfe nur bei geänderter Anzahl neu anlegen, sonst beschriften: ein neu erzeugter Knopf verliert einen laufenden Fingertipp
		if pit_when_box.get_child_count() != opts.size():
			U.clear(pit_when_box)
			for i in opts.size():
				var nb := Button.new()
				nb.toggle_mode = true
				nb.custom_minimum_size = Vector2(70, 44)
				nb.add_theme_font_size_override("font_size", 12)
				nb.pressed.connect(func(): _on_when(int(nb.get_meta("lap"))))
				pit_when_box.add_child(nb)
		for i in opts.size():
			var wb: Button = pit_when_box.get_child(i)
			wb.set_meta("lap", int(opts[i]["lap"]))
			wb.text = str(opts[i]["t"])
			wb.set_pressed_no_signal(int(opts[i]["lap"]) == pit_when_lap)
			wb.disabled = not racing
	# Worauf sich der Assistent bezieht
	if pit_edit_lap > 0 and pit_edit_lap == nxt:
		pit_edit_label.text = "Nächster geplanter Stopp: Ende R%d. Hier änderst du Reifen und Zeitpunkt." % pit_edit_lap
	elif pit_edit_lap > 0:
		pit_edit_label.text = "Du änderst den geplanten Stopp am Ende von Runde %d." % pit_edit_lap
	elif not c.plan.is_empty():
		pit_edit_label.text = "Neuer Stopp zusätzlich zum Plan."
	else:
		pit_edit_label.text = "Kein Stopp geplant: hier planst du einen neuen."
	pit_edit_label.visible = racing
	pit_edit_reset.visible = pit_touched and racing
	pit_add_btn.visible = racing and pit_edit_lap > 0
	# Rennplan: Stints mit Prüfung, Ändern / Löschen
	var pkey := "%s|%d|%d" % [c.plan_note, pit_edit_lap, int(racing)]
	for e in checks:
		pkey += "|%d:%d:%s:%d:%d:%d" % [int(e["lap"]), int(e["comp"]), str(e["state"]), int(e["cap"]), int(e["run"]), int(float(e["fuel_cap"]) * 2.0)]
	if pkey != _plan_key:
		_plan_key = pkey
		U.clear(pit_plan_box)
		for e in checks:
			pit_plan_box.add_child(_plan_row(e))
		pit_note.text = c.plan_note
		pit_note.visible = c.plan_note != ""
	# Auswahl in Zahlen
	var sel_lap: int = _pit_sel_lap(c)
	var cn: String = RaceSim.COMPOUNDS[pit_sel]["name"]
	var fuel_line := ""
	if sim.rules["refuel"]:
		var al: int = _auto_fuel_laps(c, sel_lap, pit_sel)
		var auto_fuel: bool = c.pit_fuel_laps < 0.0
		var laps_f: float = float(al) if auto_fuel else c.pit_fuel_laps
		var kg: float = sim.fuel_for_laps(laps_f)
		var fuel_at: float = maxf(0.0, c.fuel - sim.burn_now(c) * float(sel_lap - c.floor_laps))
		var add_kg: float = maxf(0.0, kg - fuel_at)
		var stand: float = 1.2 + add_kg / 9.0
		var next_stop: int = int(sim.adapt_info(c, sel_lap, pit_sel)["next"])
		pit_fuel_label.text = "%d Rd. Sprit = %d kg%s" % [int(laps_f), int(round(kg)), " (auto)" if auto_fuel else ""]
		fuel_plan.cap = sim.fuel_cap()
		fuel_plan.target = kg
		fuel_plan.now = c.fuel
		var mk: Array = []
		if next_stop < sim.laps:
			mk.append({"kg": sim.fuel_for_laps(float(next_stop - sel_lap)), "text": "Stopp R%d" % next_stop})
		mk.append({"kg": sim.fuel_for_laps(float(sim.laps - sel_lap)), "text": "Ziel"})
		fuel_plan.set_marks(mk)
		var to_end_laps: int = maxi(1, sim.laps - sel_lap)
		pit_fuel_quick[0].text = ("Bis Stopp R%d (%d Rd.)" % [next_stop, al]) if next_stop < sim.laps else ("Bis Ziel (%d Rd.)" % al)
		pit_fuel_quick[0].set_pressed_no_signal(auto_fuel)
		pit_fuel_quick[1].visible = next_stop < sim.laps
		pit_fuel_quick[1].text = "Bis Ziel (%d Rd.)" % to_end_laps
		pit_fuel_quick[1].set_pressed_no_signal(not auto_fuel and int(laps_f) == to_end_laps)
		for qb in pit_fuel_quick:
			qb.disabled = not racing
		pit_fuel_hint.text = "Du tankst ca. %d kg nach, Standzeit ca. %.1f s. Mehr Sprit = schwerer = langsamer: %d kg kosten ca. %.1f s pro Runde, werden aber Runde für Runde leichter." % [int(round(add_kg)), stand, int(round(kg)), kg * RaceSim.FUEL_TIME * sim.scale_time]
		fuel_line = "Tanken: %d Rd. = %d kg, Standzeit ca. %.1f s." % [int(laps_f), int(round(kg)), stand]
	# Vorschau
	if racing:
		var lines: Array = []
		lines.append("Stopp %s auf %s." % [("am Ende dieser Runde (R%d)" % now_lap) if sel_lap <= now_lap else ("am Ende von Runde %d" % sel_lap), cn])
		if pit_edit_lap > 0 and sel_lap != pit_edit_lap:
			lines.append("Der geplante Stopp in Runde %d wird auf Runde %d verlegt." % [pit_edit_lap, sel_lap])
		var rem: int = sim.laps - sel_lap
		var life_n: float = float(oc["life"])
		if life_n >= float(rem) + 0.5:
			lines.append("Die Reifen reichen danach bis ins Ziel (%d Rd. Rest, Haltbarkeit %d)." % [rem, int(life_n)])
		else:
			lines.append("Haltbarkeit %d Rd., danach fehlen noch %d Runden: ein weiterer Stopp wäre nötig." % [int(life_n), rem - int(life_n)])
		if sim.rules["refuel"] and sel_lap > now_lap:
			var have_laps: float = sim.fuel_range(c)
			var need_laps: float = float(sel_lap - c.floor_laps)
			if have_laps < need_laps - 0.3:
				lines.append("ACHTUNG: Der Tank reicht nur noch %.1f Rd., bis zu diesem Stopp sind es %d. Das Auto würde stehenbleiben!" % [have_laps, int(need_laps)])
		var dropped: Array = _dropped_stops(c, sel_lap, pit_sel)
		if not dropped.is_empty():
			var dtxt: Array = []
			for dl in dropped:
				dtxt.append("R%d" % int(dl))
			lines.append("Ersetzt den geplanten Stopp in %s." % ", ".join(dtxt))
		var info2: Dictionary = sim.adapt_info(c, sel_lap, pit_sel)
		if int(info2["next"]) < sim.laps:
			lines.append("Danach geplant: Stopp in Runde %d." % int(info2["next"]))
		if fuel_line != "":
			lines.append(fuel_line)
		if sel_lap <= now_lap:
			var rj: Dictionary = sim.rejoin_info(c)
			var gain: float = sim.tyre_loss(c) - sim.fresh_loss(pit_sel)
			var rt := "Rückkehr auf P%d" % rj["pos"]
			if rj["ahead"] != null:
				rt += " hinter %s (+%.1f s)" % [rj["ahead"].code, rj["gap_ahead"]]
			rt += ", %.0f s Verlust. Frische Reifen: %+.1f s pro Runde." % [rj["loss"], gain]
			lines.append(rt)
		pit_pred.text = "\n".join(lines)
		var when_s: String = "jetzt" if sel_lap <= now_lap else "R%d" % sel_lap
		var unchanged: bool = pit_edit_lap > 0 and sel_lap == pit_edit_lap and pit_sel == _plan_comp(c, pit_edit_lap)
		if c.pit_requested:
			pit_confirm_btn.text = "BOX ANGEFORDERT"
			pit_confirm_btn.disabled = true
		elif unchanged:
			pit_confirm_btn.text = "GEPLANT: %s, %s" % [cn, when_s]
			pit_confirm_btn.disabled = true
		else:
			pit_confirm_btn.text = ("ÄNDERN: %s, %s" if pit_edit_lap > 0 else "STOPP: %s, %s") % [cn, when_s]
			pit_confirm_btn.disabled = false
	else:
		pit_pred.text = ""
		pit_confirm_btn.disabled = true
	if c.pit_requested:
		pit_status.text = "Bestätigt: Box am Ende dieser Runde, %s." % RaceSim.COMPOUNDS[c.pit_comp]["name"]
	else:
		pit_status.text = ""


func _on_unplan(lap: int) -> void:
	if selected != null and selected.is_player:
		sim.unschedule_pit(selected, lap)
		_plan_key = "x"


func _select(c) -> void:
	selected = c
	map.selected = c
	if tv != null:
		tv.selected = c
	if map.follow_mode == "car" and c.is_player:
		map.follow_car = c
	tower.selected = c
	for e in player_buttons:
		e["btn"].set_pressed_no_signal(e["car"] == c)
	if not driver_panels.is_empty():
		_update_quick()


func _set_speed(i: int) -> void:
	speed_idx = i
	for k in speed_buttons.size():
		speed_buttons[k].set_pressed_no_signal(k == i)


func _banner_msg(text: String, seconds: float, col: Color) -> void:
	banner_label.text = text.to_upper()
	banner_label.add_theme_color_override("font_color", col)
	banner.visible = true
	banner.modulate.a = 1.0
	banner_t = seconds
	# oben rechts statt mittig, damit die Meldung nicht mitten im Bild aufspringt
	banner.reset_size()
	banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	banner.offset_top = 54 if U.is_mobile() else 72   # am Handy in der freien Reiterzeile rechts


## Große Karte: PC blendet Tabelle, Funk-Panel und Log aus, das Handy die Cockpit-Leiste.
func _toggle_map_big() -> void:
	map_big = not map_big
	for n in _hide_when_big:
		(n as Control).visible = not map_big
	map.set_expanded(map_big)
	_update_decision_chip()
	_update_quick()
	if U.is_mobile() and race_main_tabs != null:
		race_main_tabs.tabs_visible = not map_big


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_M:
		_toggle_map_big()
	if k != null and k.pressed and not k.echo and k.keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
		map.set_view(["all", "car1", "car2", "leader"][k.keycode - KEY_1])
	if k != null and k.pressed and not k.echo and k.keycode == KEY_SPACE:
		if lights_phase == 0:
			_lights_out()
		else:
			_set_speed(0 if speed_idx != 0 else 2)


func _lights_out() -> void:
	lights.out = true
	lights.queue_redraw()
	lights_phase = 1
	lights_t = 0.0
	if not sim.started:
		sim.start_race()
	_banner_msg("Los!", 1.6, U.GOOD)


func _process(delta: float) -> void:
	if sim == null:
		return
	if decision_card != null:
		_check_decisions(delta)
	if banner_t > 0.0:
		banner_t -= delta
		if banner_t < 0.6:
			banner.modulate.a = maxf(0.0, banner_t / 0.6)
		if banner_t <= 0.0:
			banner.visible = false
	if lights_phase == 0:
		lights_t += delta
		var n := mini(5, int(lights_t))
		if n != lights.lights_on:
			lights.lights_on = n
			lights.queue_redraw()
		if lights_t >= 5.0 + lights_hold:
			_lights_out()
		_update_ui()
		return
	if lights_phase == 1:
		lights_t += delta
		if lights_t > 1.4:
			lights.visible = false
			lights_phase = 2
	if skipping:
		var t0 := Time.get_ticks_usec()
		while not sim.over and Time.get_ticks_usec() - t0 < TICK_BUDGET_US:
			sim.tick(1.0)
			_after_tick(false)
		skip_label.text = "Rennen wird berechnet ...  %d %%" % int(100.0 * float(sim.leader_lap()) / float(maxi(sim.laps, 1)))
		skip_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		if sim.over:
			skipping = false
			skip_panel.visible = false
			print("[Zeit] Rennen berechnet in %d ms (%d Runden)" % [Time.get_ticks_msec() - skip_t0, sim.laps])
			if auto_finish:
				_on_results()
				return
		_update_ui()
		return
	if not sim.over:
		var spd: int = SPEEDS[speed_idx]
		if spd > 0:
			acc = minf(acc + delta * float(spd), 2400.0)
			var t1 := Time.get_ticks_usec()
			while acc >= 1.0 and not sim.over:
				sim.tick(1.0)
				_after_tick()
				acc -= 1.0
				if Time.get_ticks_usec() - t1 > TICK_BUDGET_US:
					break
			sim.vis_frac = clampf(acc, 0.0, 1.0) if spd <= 16 else 1.0
	_update_ui()
	if sim.over and not finished_shown:
		finished_shown = true
		var rk: Array = sim.ranking()
		var t := ""
		for i in mini(3, rk.size()):
			t += "P%d  %s  %s\n" % [i + 1, rk[i].code, rk[i].team_name]
		end_text.text = t.strip_edges()
		end_panel.visible = true
		end_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_set_speed(0)


## Bis zum Ziel vorspulen. Normal schrittweise (Bildschirm bleibt bedienbar), blocking = in einem Zug (Tests).
func _skip_to_end(blocking := false) -> void:
	if lights_phase == 0:
		_lights_out()
	if blocking:
		var n := 0
		while not sim.over and n < 30000:
			sim.tick(1.0)
			_after_tick(false)
			n += 1
		return
	skipping = true
	skip_t0 = Time.get_ticks_msec()
	skip_panel.visible = true
	_set_speed(0)


func _event_color(kind: String) -> String:
	match kind:
		"sc":
			return "#b86f00"
		"dnf":
			return "#d93025"
		"weather":
			return "#1f5fd6"
		"fastest":
			return "#8a3fd1"
		"pass":
			return "#0f9d58"
		"pit":
			return "#2b3347"
		"radio":
			return "#1d6fb8"
	return "#5b657b"


func _after_tick(allow_slow := true) -> void:
	while ev_index < sim.events.size():
		var e: Dictionary = sim.events[ev_index]
		ev_index += 1
		var k: String = e["kind"]
		log_lines.append("[color=#8a93a8]R%02d[/color]  [color=%s]%s[/color]" % [e["lap"], _event_color(k), e["text"]])
		if allow_slow:
			if k == "sc":
				_banner_msg(str(e["text"]), 3.5, U.WARN)
			elif k == "weather":
				_banner_msg(str(e["text"]), 3.5, U.BLUE)
			elif k == "dnf" and e["car"] >= 0 and sim.cars[e["car"]].is_player:
				_banner_msg(str(e["text"]), 3.5, U.BAD)
			elif k == "radio" and e["car"] >= 0 and (sim.cars[e["car"]].is_player or (sim.mate_of(sim.cars[e["car"]]) != null and sim.mate_of(sim.cars[e["car"]]).is_player)):
				_banner_msg(str(e["text"]), 3.0, Color("1d6fb8"))
			if auto_slow and speed_idx > 2:
				var relevant: bool = k == "sc" or k == "weather" or (k == "radio" and e["car"] >= 0 and sim.cars[e["car"]].is_player)
				if k == "dnf" and e["car"] >= 0 and sim.cars[e["car"]].is_player:
					relevant = true
				if relevant:
					_set_speed(2)
	if log_lines.size() > 60:
		log_lines = log_lines.slice(log_lines.size() - 60)
	for c in sim.cars:
		if c.is_player and c.state == 1:
			var life: float = sim.life_eff(c.compound)
			var key := "%d_%d" % [c.index, c.pit_stops]
			if c.tyre_wear > life * 0.9 and not alerted.has(key):
				alerted[key] = true
				log_lines.append("[color=#8a93a8]R%02d[/color]  [color=#b86f00]Funk %s: Reifen am Ende (%s, %d Runden alt)[/color]" % [sim.leader_lap(), c.code, RaceSim.COMPOUNDS[c.compound]["name"], c.tyre_age_laps])
				if allow_slow and auto_slow and speed_idx > 2:
					_set_speed(2)


func _on_style(i: int) -> void:
	if selected != null and selected.is_player:
		sim.set_style(selected, i)


func _on_pit(k: int) -> void:
	if selected != null and selected.is_player and selected.state == 1:
		sim.request_pit(selected, k)
		log_lines.append("[color=#8a93a8]R%02d[/color]  [color=#b86f00]Funk an %s: Box, Box! Reifen: %s[/color]" % [sim.leader_lap(), selected.code, RaceSim.COMPOUNDS[k]["name"]])


func _on_cancel_pit() -> void:
	if selected != null and selected.is_player:
		sim.cancel_pit(selected)
		for s in selected.plan.duplicate():
			if int(s["lap"]) > selected.floor_laps:
				selected.plan.erase(s)
		_plan_key = "x"


func _on_results() -> void:
	Game.finish_race(sim)
	main.show_results()


func _update_ui() -> void:
	var lap: int = sim.leader_lap() if sim.started else 1
	lap_label.text = "%d/%d" % [lap, sim.laps]
	time_label.text = sim.fmt_race_time(sim.time)
	# Flaggen-Marke wie in der TV-Grafik: volle Flaggenfarbe
	var chip_bg := Color("16a34a")
	var chip_fg := Color.WHITE
	var chip_text := "GRÜN"
	match sim.status:
		1:
			chip_text = "VSC"
			chip_bg = Color("facc15")
			chip_fg = U.INK
		2:
			chip_text = "SAFETY CAR"
			chip_bg = Color("facc15")
			chip_fg = U.INK
	if sim.leader_finished and not sim.over:
		chip_text = "ZIELFLAGGE"
		chip_bg = Color.WHITE
		chip_fg = U.INK
	if not sim.started:
		chip_text = "STARTAUFSTELLUNG"
		chip_bg = U.DARK3
		chip_fg = U.ON_DARK
	if U.is_mobile():
		chip_text = {"STARTAUFSTELLUNG": "START", "SAFETY CAR": "SC", "ZIELFLAGGE": "ZIEL"}.get(chip_text, chip_text)
	status_label.text = chip_text
	status_label.add_theme_color_override("font_color", chip_fg)
	var sb: StyleBoxFlat = status_chip.get_theme_stylebox("panel")
	sb.bg_color = chip_bg
	# Safety Car / VSC: Marke pulsiert
	status_chip.modulate.a = (0.6 + 0.4 * absf(sin(float(Time.get_ticks_msec()) / 220.0))) if sim.status != 0 else 1.0
	weather_label.text = "%s  |  %d °C  |  %s" % [sim.weather_text(), int(round(sim.temp_race)), sim.forecast_text()]
	var gcol: Color = U.TEXT
	if sim.started:
		var gs: Dictionary = Career.live_status(sim)
		gcol = {"ok": U.GOOD, "risk": U.WARN, "miss": U.BAD}[str(gs["state"])]
		goal_label.text = str(gs["text"])
		if goal_line != null:
			goal_line.text = "RENNZIEL  " + str(gs["short"])
			goal_line.add_theme_color_override("font_color", gcol)
	else:
		goal_label.text = "Rennziel: %s." % str(Career.race_goal()["text"])
	goal_label.add_theme_color_override("font_color", gcol)
	var from := maxi(0, log_lines.size() - (16 if U.is_mobile() else 8))
	var recent: Array = log_lines.slice(from)
	recent.reverse()
	log_label.text = "\n".join(recent)
	if selected == null:
		return
	var c = selected
	car_title.text = "%s  %s" % [c.code, c.driver_name]
	var tr_txt := ""
	if Game.drivers.has(c.driver_id):
		tr_txt = "  |  " + ", ".join(Market.trait_labels(Game.drivers[c.driver_id]))
	car_sub.text = "#%s%s" % [c.number, tr_txt]
	var rk: Array = sim.ranking()
	var pos := rk.find(c)
	var txt := "P%d" % (pos + 1)
	if c.state == 1 or c.state == 2:
		if pos > 0:
			txt += "   vorn %s +%.1f s" % [rk[pos - 1].code, c.gap_ahead]
		if pos < rk.size() - 1 and rk[pos + 1].state != 3:
			var b = rk[pos + 1]
			txt += "   hinten %s %.1f s" % [b.code, b.gap_ahead]
		if c.drs:
			txt += "   DRS"
	elif c.state == 3:
		txt = "Ausgeschieden: %s" % c.out_reason
	for gl in gap_labels:
		gl.text = txt
	_update_car_pit(c)
	_update_tactics()
	weather_panel.refresh(sim)
	_update_quick()
	var now_ms := Time.get_ticks_msec()
	if now_ms - _ov_last > 500:
		_ov_last = now_ms
		_update_overview()

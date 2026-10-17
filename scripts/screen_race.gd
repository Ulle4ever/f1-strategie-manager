extends Control
## Live-Rennen: Startampel, Karte mit Punkten, Zeitenturm, Boxenfunk für die eigenen Autos, Vorspulen.

const U = preload("res://scripts/ui.gd")
const TrackMap = preload("res://scripts/track_map.gd")
const Tower = preload("res://scripts/timing_tower.gd")
const RaceSim = preload("res://scripts/race_sim.gd")
const StartLights = preload("res://scripts/start_lights.gd")
const Market = preload("res://scripts/market.gd")
const TvOverlay = preload("res://scripts/tv_overlay.gd")
const StintBar = preload("res://scripts/stint_bar.gd")
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
var gap_label: Label
var style_buttons: Array = []
var pit_buttons: Array = []
var pit_status: Label
var plan_label: Label
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
var pit_confirm_btn: Button
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
var pit_sel := -1
var _advice_key := "init"
var _seg_key := ""
var _plan_key := ""


func _ready() -> void:
	U.fill(self)
	add_child(U.team_backdrop())
	var margin := U.screen_margin(self, 10)
	var M := U.is_mobile()
	var root := U.vbox(4 if M else 8)
	margin.add_child(root)
	root.add_child(_build_top())

	var tp := U.panel(6, U.ACCENT)
	tp.custom_minimum_size = Vector2(372, 0)
	tower = Tower.new()
	tower.sim = sim
	tower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tower.car_clicked.connect(_select)
	if M:
		tower.custom_minimum_size = Vector2(380, 34.0 + float(sim.cars.size()) * 29.0 + 8.0)
	tp.add_child(tower)

	var center := U.vbox(6 if M else 8)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mp := U.panel(4)
	mp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map = TrackMap.new()
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.sim = sim
	map.interactive = true
	map.car_clicked.connect(_select)
	map.set_track(sim.track)
	mp.add_child(map)
	tv = TvOverlay.new()
	tv.sim = sim
	mp.add_child(tv)
	center.add_child(mp)
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

	var entries := [
		{"name": "Tabelle", "node": tp, "min": 372.0},
		{"name": "Karte", "node": center, "grow": true, "self_scroll": true},
		{"name": "Funk", "node": _build_control_panel(), "min": 364.0, "self_scroll": true},
	]
	if M:
		lp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		entries.append({"name": "Log", "node": lp, "self_scroll": true})
	var cols := U.columns(entries, 10)
	root.add_child(cols)
	race_main_tabs = cols as TabContainer
	if M:
		race_main_tabs.current_tab = 1

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
	banner = U.panel(10, U.WARN)
	banner.visible = false
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_label = U.label("", 26, U.WARN, true)
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
	var p := U.panel(8, U.ACCENT)
	var h := U.hbox(4 if U.is_mobile() else 14)
	p.add_child(h)
	var M := U.is_mobile()
	lap_label = U.label("", 16 if M else 28, U.TEXT, true)
	h.add_child(lap_label)
	time_label = U.label("", 16, U.MUTED)
	time_label.visible = not M
	h.add_child(time_label)
	status_chip = U.chip("GRÜN", Color("14562f"), U.GOOD)
	status_label = status_chip.get_child(0)
	h.add_child(status_chip)
	weather_label = U.label("", 14, U.MUTED)
	weather_label.clip_text = true
	weather_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weather_label.visible = not M
	if M:
		h.add_child(U.spacer())
	h.add_child(weather_label)
	for i in SPEEDS.size():
		var b := Button.new()
		b.text = SPEED_NAMES_SHORT[i] if U.is_mobile() else SPEED_NAMES[i]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(34 if M else 54, 36)
		if M:
			b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_set_speed.bind(i))
		h.add_child(b)
		speed_buttons.append(b)
	var end_b := U.button("Ende", _skip_to_end, 52 if M else 64, 36)
	if M:
		end_b.add_theme_font_size_override("font_size", 14)
	h.add_child(end_b)
	var cb := U.checkbox()
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


func _build_control_panel() -> Control:
	var p := U.panel(10, U.WARN)
	p.custom_minimum_size = Vector2(364, 0)
	var v := U.vbox(6)
	p.add_child(v)
	if not U.is_mobile():
		v.add_child(U.section("Boxenfunk", 13))
	var prow := U.hbox(6)
	v.add_child(prow)
	for c in sim.cars:
		if c.is_player:
			var b := Button.new()
			b.toggle_mode = true
			b.text = c.code
			b.custom_minimum_size = Vector2(84, 30 if U.is_mobile() else 36)
			b.pressed.connect(_select.bind(c))
			prow.add_child(b)
			player_buttons.append({"btn": b, "car": c})
	var th := U.hbox(8)
	(prow if U.is_mobile() else v).add_child(th)
	car_title = U.label("", 22, U.TEXT, true)
	th.add_child(car_title)
	car_sub = U.label("", 13, U.MUTED)
	th.add_child(car_sub)
	race_tabs = TabContainer.new()
	race_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if U.is_mobile():
		race_tabs.add_theme_font_size_override("font_size", 14)
	v.add_child(race_tabs)
	race_tabs.add_child(_build_car_tab())
	race_tabs.add_child(_build_pit_tab())
	race_tabs.add_child(_build_tactics_tab())
	race_tabs.add_child(_build_weather_tab())
	return p


## Reiter "Auto": Reifen, Stints, Tank, Fahrstil, Abstand.
func _build_car_tab() -> Control:
	var t := _scroll_tab("Auto")
	var v: VBoxContainer = t[1]
	var card := U.card(9)
	var cv := U.vbox(5)
	card.add_child(cv)
	tyre_label = U.label("", 16, U.TEXT, true)
	cv.add_child(tyre_label)
	tyre_bar = ProgressBar.new()
	tyre_bar.max_value = 100.0
	tyre_bar.show_percentage = false
	tyre_bar.custom_minimum_size = Vector2(0, 12)
	cv.add_child(tyre_bar)
	stint_bar = StintBar.new()
	cv.add_child(stint_bar)
	info_label = _wrap_label("", 13, U.MUTED)
	cv.add_child(info_label)
	v.add_child(card)
	gap_label = _wrap_label("", 14, U.TEXT)
	v.add_child(gap_label)

	var fc := U.card(9)
	var fv := U.vbox(4)
	fc.add_child(fv)
	fv.add_child(U.section("Tank", 12))
	fuel_label = _wrap_label("", 13, U.TEXT)
	fv.add_child(fuel_label)
	fuel_bar = ProgressBar.new()
	fuel_bar.max_value = 100.0
	fuel_bar.show_percentage = false
	fuel_bar.custom_minimum_size = Vector2(0, 10)
	fv.add_child(fuel_bar)
	v.add_child(fc)

	v.add_child(U.section("Fahrstil", 12))
	var srow := U.hbox(5)
	v.add_child(srow)
	for i in 3:
		var b := Button.new()
		b.toggle_mode = true
		b.text = RaceSim.STYLE_NAMES[i]
		b.custom_minimum_size = Vector2(0, 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_style.bind(i))
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
	return t[0]


## Reiter "Boxen": Stopp-Fenster, Reifenwahl, Zeitpunkt, Tanken, Prognose.
func _build_pit_tab() -> Control:
	var t := _scroll_tab("Boxen")
	var v: VBoxContainer = t[1]
	var pit_root := VBoxContainer.new()
	pit_root.name = "Boxen"
	pit_root.add_theme_constant_override("separation", 6)
	t[0].name = "Scroll"
	t[0].size_flags_vertical = Control.SIZE_EXPAND_FILL
	pit_root.add_child(t[0])
	var footer := U.vbox(5)
	pit_root.add_child(footer)
	# Status: was ist gerade geplant?
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
	pit_plan_box = U.vbox(4)
	v.add_child(pit_plan_box)

	# Neuer Stopp in drei Schritten
	var comp_card := U.card(10)
	var cv := U.vbox(7)
	comp_card.add_child(cv)
	cv.add_child(U.section("Stopp planen", 13))
	pit_edit_label = _wrap_label("", 12, U.BLUE, true)
	cv.add_child(pit_edit_label)
	pit_edit_reset = U.button("Änderung verwerfen", _on_edit_reset, 0, 30)
	cv.add_child(pit_edit_reset)
	cv.add_child(_wrap_label("1  Welche Reifen?", 12, U.MUTED, true))
	var brow := HFlowContainer.new()
	brow.add_theme_constant_override("h_separation", 4)
	brow.add_theme_constant_override("v_separation", 4)
	cv.add_child(brow)
	for k in RaceSim.COMPOUNDS.size():
		var b := Button.new()
		var cd: Dictionary = RaceSim.COMPOUNDS[k]
		b.toggle_mode = true
		b.text = cd["name"]
		b.custom_minimum_size = Vector2(62, 62)
		b.add_theme_color_override("font_color", cd["ink"])
		b.add_theme_color_override("font_pressed_color", cd["ink"])
		b.add_theme_color_override("font_hover_color", cd["ink"])
		b.add_theme_color_override("font_disabled_color", Color(cd["ink"], 0.35))
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(_on_pit_sel.bind(k))
		brow.add_child(b)
		pit_buttons.append(b)
	pit_outlook = _wrap_label("", 12, U.MUTED)
	cv.add_child(pit_outlook)
	cv.add_child(_wrap_label("2  Wann?", 12, U.MUTED, true))
	pit_when_box = HFlowContainer.new()
	pit_when_box.add_theme_constant_override("h_separation", 4)
	pit_when_box.add_theme_constant_override("v_separation", 4)
	cv.add_child(pit_when_box)
	pit_fuel_card = U.vbox(4)
	pit_fuel_card.add_child(_wrap_label("Tanken beim Stopp", 12, U.MUTED, true))
	var pfr := U.hbox(5)
	pit_fuel_card.add_child(pfr)
	pfr.add_child(U.button("-", _on_pit_fuel.bind(-1), 38, 34))
	pit_fuel_label = _wrap_label("", 13, U.TEXT, true)
	pit_fuel_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pit_fuel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pfr.add_child(pit_fuel_label)
	pfr.add_child(U.button("+", _on_pit_fuel.bind(1), 38, 34))
	pfr.add_child(U.button("Auto", _on_pit_fuel.bind(0), 54, 34))
	pit_fuel_hint = _wrap_label("", 11, U.MUTED)
	pit_fuel_card.add_child(pit_fuel_hint)
	cv.add_child(pit_fuel_card)
	pit_fuel_card.visible = sim.rules["refuel"]
	var sum_parent: VBoxContainer = cv if U.is_mobile() else footer   # Handy: Zusammenfassung im Scrollbereich, nur der Knopf bleibt unten
	sum_parent.add_child(_wrap_label("3  Prüfen und bestätigen", 12, U.MUTED, true))
	pit_pred = _wrap_label("", 13, U.TEXT)
	var pc := U.card(9, Color(U.BLUE, 0.06), Color(U.BLUE, 0.3))
	pc.add_child(pit_pred)
	sum_parent.add_child(pc)
	pit_confirm_btn = U.primary_button("STOPP BESTÄTIGEN", _on_pit_confirm, 0, 42 if U.is_mobile() else 48)
	footer.add_child(pit_confirm_btn)
	v.add_child(comp_card)
	pit_status = _wrap_label("", 13, U.GOOD, true)
	v.add_child(pit_status)
	var clr := U.button("Alle geplanten Stopps löschen", _on_cancel_pit, 0, 30)
	v.add_child(clr)
	plan_label = _wrap_label("", 12, U.MUTED)
	plan_label.visible = false
	v.add_child(plan_label)
	return pit_root


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


## Reiter "Taktik": oben Empfehlungen, dann Energie und Teamorder; Automatik, Gambles und Rechner eingeklappt.
func _build_tactics_tab() -> Control:
	var t := _scroll_tab("Taktik")
	var tv: VBoxContainer = t[1]
	tv.add_child(U.section("Empfehlungen", 12))
	advice_box = U.vbox(5)
	tv.add_child(advice_box)

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
		mrow.add_child(b)
		mode_buttons.append(b)
	mode_hint = _wrap_label("", 11, U.MUTED)
	ev.add_child(mode_hint)
	engine_label = _wrap_label("", 11, U.MUTED)
	ev.add_child(engine_label)
	tv.add_child(ec)

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
		trow.add_child(b)
		order_buttons.append(b)
	order_buttons.append(U.button("Befehle aufheben", _on_order.bind(3), 0, 30))
	ov.add_child(order_buttons[3])
	order_status = _wrap_label("", 11, U.MUTED)
	ov.add_child(order_status)
	tv.add_child(oc)

	# Automatik (eingeklappt)
	var auto_box := _collapsible(tv, "Automatik: Wenn-Dann-Regeln")
	auto_box.add_child(_wrap_label("Das Team handelt automatisch, auch wenn du gerade nicht eingreifst.", 11, U.MUTED))
	var rdefs2 := [["sc_pit", "Safety Car: Stopp holen"], ["rain_switch", "Regen: auf Regenreifen"], ["dry_switch", "Abtrocknen: zurück auf Slicks"], ["defend", "Konter-Stopp bei Undercut-Gefahr"], ["fuel_save", "Sprit automatisch sparen"]]
	for d2 in rdefs2:
		var cb := U.checkbox(str(d2[1]))
		cb.toggled.connect(_on_rule.bind(str(d2[0])))
		auto_box.add_child(cb)
		rule_checks[str(d2[0])] = cb

	# Gambles und Rechner (eingeklappt)
	var gb := _collapsible(tv, "Gambles und Rechner")
	sc_label = _wrap_label("", 12, U.TEXT)
	gb.add_child(sc_label)
	radar_label = _wrap_label("", 12, U.TEXT)
	gb.add_child(radar_label)
	double_btn = U.button("Doppelstopp (beide Autos)", _on_double, 0, 36)
	gb.add_child(double_btn)
	gb.add_child(_wrap_label("Beide Autos stoppen am Rundenende. Das zweite Auto wartet etwa 2-3 Sekunden.", 11, U.MUTED))
	gb.add_child(HSeparator.new())
	uc_label = _wrap_label("", 12, U.TEXT)
	threat_label = _wrap_label("", 12, U.TEXT)
	rejoin_label = _wrap_label("", 12, U.MUTED)
	uc_btn = U.button("Jetzt stoppen (empfohlene Mischung)", _on_uc_pit, 0, 36)
	gb.add_child(uc_label)
	gb.add_child(threat_label)
	gb.add_child(rejoin_label)
	gb.add_child(uc_btn)
	return t[0]


func _build_weather_tab() -> Control:
	var t := _scroll_tab("Wetter")
	var v: VBoxContainer = t[1]
	weather_panel = WeatherPanel.new()
	weather_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(weather_panel)
	return t[0]


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


## Zeitpunkt wählen (nur Auswahl, ausgeführt wird erst mit "Stopp bestätigen").
func _on_when(lap: int) -> void:
	pit_when_lap = lap
	pit_when_key = ""


## Stopp bestätigen: am Rundenende anfordern oder für eine spätere Runde einplanen.
func _on_pit_confirm() -> void:
	var c = selected
	if c == null or not c.is_player or c.state != 1:
		return
	var now_lap: int = c.floor_laps + 1
	var lap: int = pit_when_lap if pit_when_lap >= now_lap else now_lap
	var comp: int = pit_sel if pit_sel >= 0 else sim.suggest_comp(c)
	if pit_edit_lap > 0:
		sim.unschedule_pit(c, pit_edit_lap)
	if lap <= now_lap:
		sim.request_pit(c, comp)
		_radio("Funk an %s: Box, Box! Reifen: %s" % [c.code, RaceSim.COMPOUNDS[comp]["name"]])
		_banner_msg("Box diese Runde: %s" % RaceSim.COMPOUNDS[comp]["name"], 2.0, U.GOOD)
	else:
		if lap >= sim.laps:
			return
		sim.schedule_pit(c, lap, comp)
		_radio("Funk an %s: Stopp für Ende Runde %d eingeplant (%s)." % [c.code, lap, RaceSim.COMPOUNDS[comp]["name"]])
		_banner_msg("Stopp Runde %d: %s" % [lap, RaceSim.COMPOUNDS[comp]["name"]], 2.0, U.GOOD)
	pit_edit_lap = -1
	pit_when_lap = -1
	pit_when_key = ""
	pit_auto_key = ""
	_plan_key = "x"


## Geplanten Stopp bearbeiten: Reifen und Zeitpunkt in die Auswahl laden, die alte Planung bleibt bis zum Bestätigen.
func _on_edit_plan(lap: int, comp: int) -> void:
	pit_edit_lap = lap
	pit_sel = comp
	pit_when_lap = lap
	pit_when_key = ""


func _on_edit_reset() -> void:
	pit_edit_lap = -1
	pit_when_lap = -1
	pit_when_key = ""
	pit_auto_key = ""


func _on_cancel_request() -> void:
	if selected != null and selected.is_player:
		sim.cancel_pit(selected)


func _on_pit_fuel(d: int) -> void:
	var c = selected
	if c == null or not c.is_player:
		return
	if d == 0:
		c.pit_fuel_laps = -1.0
		return
	var base: float = c.pit_fuel_laps
	if base < 0.0:
		base = float(_auto_fuel_laps(c))
	c.pit_fuel_laps = clampf(base + float(d), 1.0, 90.0)


## Runden Sprit, die der nächste Stopp automatisch tankt (bis zum übernächsten Stopp bzw. Ziel).
func _auto_fuel_laps(c) -> int:
	var fl: int = c.floor_laps + 1
	var nxt: int = sim.laps
	for s in c.plan:
		if int(s["lap"]) > fl:
			nxt = mini(nxt, int(s["lap"]))
	return maxi(1, nxt - fl)


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


## Auto-Reiter und Boxen-Reiter aktualisieren.
func _update_car_pit(c) -> void:
	var lap: int = c.floor_laps + 1 if c.state == 1 else sim.leader_lap()
	var cd: Dictionary = RaceSim.COMPOUNDS[c.compound]
	var life: float = sim.life_eff(c.compound)
	var left := clampf(1.0 - c.tyre_wear / life, 0.0, 1.0)
	tyre_label.text = "%s  |  %d Runden alt  |  Rest %d %%" % [cd["name"], c.tyre_age_laps, int(left * 100.0)]
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
	info_label.text = "Letzte %s   Beste %s\nReifenverlust %.2f s/Rd.   Verschleiß %.2fx" % [sim.fmt_time(c.last_lap), sim.fmt_time(c.best_lap), loss, sim.wear_rate_now(c)]
	# Tank
	var rng_l: float = sim.fuel_range(c)
	var need: float = float(sim.laps_to_refuel_point(c, maxi(c.floor_laps, 0)))
	var fcol := U.GOOD if rng_l > need + 1.0 else (U.WARN if rng_l >= need else U.BAD)
	fuel_label.text = "%.1f kg   |   reicht noch %.1f Runden (Bedarf bis %s: %d)" % [c.fuel, rng_l, "Stopp" if sim.rules["refuel"] and need < sim.laps - c.floor_laps else "Ziel", int(need)]
	fuel_label.add_theme_color_override("font_color", fcol)
	fuel_bar.value = clampf(c.fuel / sim.fuel_cap() * 100.0, 0.0, 100.0)
	fuel_bar.add_theme_stylebox_override("fill", U.button_style(fcol, fcol, 0, 5))
	# Fahrstil und Abstand
	for i in 3:
		style_buttons[i].set_pressed_no_signal(i == c.style)
		style_buttons[i].disabled = c.state == 3 or c.state == 4
	var sn: Array = ["Sparen: %+.1f %% Pace, %d %% weniger Reifenverschleiß, 6 %% weniger Sprit.", "Standard: ausgewogen.", "Angriff: %+.1f %% Pace, %d %% mehr Reifenverschleiß, 4 %% mehr Sprit."]
	match c.style:
		0:
			style_hint.text = sn[0] % [RaceSim.STYLE_PACE[0] * 100.0, 28]
		1:
			style_hint.text = sn[1]
		2:
			style_hint.text = sn[2] % [RaceSim.STYLE_PACE[2] * 100.0, 32]
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
	# Boxen-Reiter: Status, geplante Stopps, Auswahl in drei Schritten
	var now_lap: int = c.floor_laps + 1
	var racing: bool = c.state == 1
	var win: Dictionary = sim.pit_window_info(c, now_lap) if racing else {"need": false, "text": "", "frac": 0.0, "ideal": now_lap}
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
	pit_win_label.text = str(win["text"])
	if sim.wet > 0.1 or sim.rain > 0.05:
		pit_win_label.text += "\nRegen: Reifenwahl nach Streckennässe (%d %%)." % int(sim.wet * 100.0)
	# Standardvorschlag einmal pro Runde setzen, solange der Spieler nichts gewählt hat
	var sug: int = sim.suggest_comp(c) if racing else 1
	var def_lap: int = now_lap
	if bool(win["need"]) and int(win["ideal"]) > now_lap and float(win["frac"]) < 0.85:
		def_lap = mini(int(win["ideal"]), sim.laps - 1)
	var akey := "%d|%d" % [c.pit_stops, now_lap]
	if pit_sel < 0:
		pit_sel = sug
	if pit_when_lap < now_lap and pit_edit_lap < 0:
		pit_when_lap = def_lap
	if akey != pit_auto_key:
		pit_auto_key = akey
		if pit_when_lap < now_lap:
			pit_when_lap = def_lap
	for k in pit_buttons.size():
		var o: Dictionary = sim.compound_outlook(c, k)
		var tt: String = RaceSim.COMPOUNDS[k]["name"]
		tt += "\n%d Rd%s" % [int(o["life"]), (" OK" if o["to_end"] else "")]
		if not sim.tyre_unlimited():
			var cnt: Dictionary = sim.tyre_count(c, k)
			tt += "\n%d Sätze" % int(cnt["free"])
		if k == sug:
			tt += " *"
		pit_buttons[k].text = tt
		pit_buttons[k].set_pressed_no_signal(k == pit_sel)
		pit_buttons[k].disabled = not racing
	var oc: Dictionary = sim.compound_outlook(c, pit_sel)
	pit_outlook.text = "%s hält ca. %d Runden%s.   * = Empfehlung, OK = reicht bis ins Ziel." % [RaceSim.COMPOUNDS[pit_sel]["name"], int(oc["life"]), " und reicht bis ins Ziel" if oc["to_end"] else ""]
	# Zeitpunkt-Auswahl (nur neu aufbauen, wenn sich die Optionen ändern)
	var opts: Array = []
	for off in [0, 2, 4, 6]:
		var l: int = now_lap + off
		if l < sim.laps:
			opts.append({"lap": l, "t": ("Jetzt\nEnde R%d" % l) if off == 0 else ("R%d\nin %d Rd." % [l, off])})
	if bool(win["need"]) and int(win["ideal"]) > now_lap and int(win["ideal"]) < sim.laps:
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
	var wkey := "%d|%d|%s" % [now_lap, pit_when_lap, str(opts.size())]
	if wkey != pit_when_key:
		pit_when_key = wkey
		U.clear(pit_when_box)
		for o4 in opts:
			var wb := Button.new()
			wb.toggle_mode = true
			wb.text = str(o4["t"])
			wb.custom_minimum_size = Vector2(70, 44)
			wb.add_theme_font_size_override("font_size", 12)
			wb.button_pressed = int(o4["lap"]) == pit_when_lap
			wb.disabled = not racing
			wb.pressed.connect(_on_when.bind(int(o4["lap"])))
			pit_when_box.add_child(wb)
	# Änderungs-Hinweis
	pit_edit_label.visible = pit_edit_lap > 0
	pit_edit_reset.visible = pit_edit_lap > 0
	pit_edit_label.text = "Du änderst den geplanten Stopp nach Runde %d." % pit_edit_lap
	# geplante Stopps als Liste mit Ändern / Löschen
	var pkey := ""
	for s in c.plan:
		if int(s["lap"]) > c.floor_laps:
			pkey += "%d:%d;" % [int(s["lap"]), int(s["comp"])]
	if pkey != _plan_key:
		_plan_key = pkey
		U.clear(pit_plan_box)
		for s in c.plan:
			if int(s["lap"]) > c.floor_laps:
				var row := U.card(6, U.tint(0.04))
				var rh := U.hbox(6)
				row.add_child(rh)
				rh.add_child(U.label("Ende Runde %d" % int(s["lap"]), 14, U.TEXT, true))
				rh.add_child(U.label(RaceSim.COMPOUNDS[int(s["comp"])]["name"], 14, RaceSim.COMPOUNDS[int(s["comp"])]["ink"], true))
				rh.add_child(U.spacer())
				rh.add_child(U.button("Ändern", _on_edit_plan.bind(int(s["lap"]), int(s["comp"])), 70, 30))
				rh.add_child(U.button("x", _on_unplan.bind(int(s["lap"])), 34, 30))
				pit_plan_box.add_child(row)
	# Tanken
	if sim.rules["refuel"]:
		var al: int = _auto_fuel_laps(c)
		var laps_f: float = c.pit_fuel_laps if c.pit_fuel_laps >= 0.0 else float(al)
		var kg: float = sim.fuel_for_laps(laps_f)
		var stand: float = 1.2 + maxf(0.0, kg - c.fuel) / 9.0
		pit_fuel_label.text = "%d Runden = %.1f kg%s" % [int(laps_f), kg, " (auto)" if c.pit_fuel_laps < 0.0 else ""]
		pit_fuel_hint.text = "Standzeit ca. %.1f s. Mehr Sprit = längere Distanz, aber schwerer und langsamer (%.1f s pro Runde Gewicht)." % [stand, kg * RaceSim.FUEL_TIME * sim.scale_time]
	# Zusammenfassung der Auswahl
	var sel_lap: int = pit_when_lap if pit_when_lap >= now_lap else now_lap
	var cn: String = RaceSim.COMPOUNDS[pit_sel]["name"]
	if racing:
		var summary := "Stopp %s auf %s.\n" % ["am Ende dieser Runde (R%d)" % now_lap if sel_lap <= now_lap else "am Ende von Runde %d" % sel_lap, cn]
		var rem: int = sim.laps - sel_lap
		var life_n: float = float(oc["life"])
		if life_n >= float(rem) + 0.5:
			summary += "Die Reifen reichen danach bis ins Ziel (%d Rd. Rest, Haltbarkeit %d)." % [rem, int(life_n)]
		else:
			summary += "Haltbarkeit %d Rd., danach fehlen noch %d Runden: ein weiterer Stopp wäre nötig." % [int(life_n), rem - int(life_n)]
		if sel_lap <= now_lap:
			var rj: Dictionary = sim.rejoin_info(c)
			var gain: float = sim.tyre_loss(c) - sim.fresh_loss(pit_sel)
			summary += "\nRückkehr auf P%d" % rj["pos"]
			if rj["ahead"] != null:
				summary += " hinter %s (+%.1f s)" % [rj["ahead"].code, rj["gap_ahead"]]
			summary += ", %.0f s Verlust. Frische Reifen: %+.1f s pro Runde." % [rj["loss"], gain]
		pit_pred.text = summary
		var btn_t := "STOPP BESTÄTIGEN: %s, %s" % [cn, "jetzt" if sel_lap <= now_lap else "Runde %d" % sel_lap]
		if pit_edit_lap > 0:
			btn_t = "ÄNDERUNG BESTÄTIGEN: %s, Runde %d" % [cn, sel_lap]
		pit_confirm_btn.text = btn_t
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
	banner.reset_size()
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner.offset_top = 72


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
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
	lap_label.text = ("RUNDE %d/%d" if U.is_mobile() else "RUNDE %d / %d") % [lap, sim.laps]
	time_label.text = sim.fmt_race_time(sim.time)
	var chip_bg := Color("d6f3e3")
	var chip_fg := U.GOOD
	var chip_text := "GRÜN"
	match sim.status:
		1:
			chip_text = "VSC"
			chip_bg = Color("ffe9b0")
			chip_fg = U.WARN
		2:
			chip_text = "SAFETY CAR"
			chip_bg = Color("ffe9b0")
			chip_fg = U.WARN
	if sim.leader_finished and not sim.over:
		chip_text = "ZIELFLAGGE"
		chip_bg = Color("e3e7ef")
		chip_fg = U.TEXT
	if not sim.started:
		chip_text = "STARTAUFSTELLUNG"
		chip_bg = Color("e3e7ef")
		chip_fg = U.TEXT
	if U.is_mobile():
		chip_text = {"STARTAUFSTELLUNG": "START", "SAFETY CAR": "SC", "ZIELFLAGGE": "ZIEL"}.get(chip_text, chip_text)
	status_label.text = chip_text
	status_label.add_theme_color_override("font_color", chip_fg)
	var sb: StyleBoxFlat = status_chip.get_theme_stylebox("panel")
	sb.bg_color = chip_bg
	weather_label.text = "%s  |  %s" % [sim.weather_text(), sim.forecast_text()]
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
	gap_label.text = txt
	_update_car_pit(c)
	_update_tactics()
	weather_panel.refresh(sim)

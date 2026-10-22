extends Control
## Qualifying: Q1/Q2/Q3 live. Eigene Autos mit Reifen und Risiko auf die Strecke schicken, vorspulen.

const U = preload("res://scripts/ui.gd")
const TrackMap = preload("res://scripts/track_map.gd")
const Tower = preload("res://scripts/quali_tower.gd")
const RaceSim = preload("res://scripts/race_sim.gd")
const QualiSim = preload("res://scripts/quali_sim.gd")

const SPEEDS := [0, 1, 4, 16, 64]
const SPEED_NAMES := ["Pause", "1x", "4x", "16x", "64x"]
const SPEED_NAMES_SHORT := ["II", "1x", "4x", "16x", "64x"]
const RISK_NAMES := ["Sicher", "Normal", "Attacke"]
const RISK_HINTS := ["ca. 0,15 % langsamer, halb so viele Fehler, kaum Unfälle",
	"Unfall etwa 1 von 300 Runden (Nässe und falsche Reifen mehr)",
	"ca. 0,25 % schneller, doppelt so viele Fehler und Unfälle"]

var main
var sim
var qsim
var map
var tower
var speed_idx := 2
var acc := 0.0
var ev_index := 0
var log_lines: Array = []
var auto_slow := true
var cards := []
var phase_label: Label
var clock_label: Label
var weather_label: Label
var status_label: Label
var speed_buttons: Array = []
var log_label: RichTextLabel
var overlay: PanelContainer
var overlay_title: Label
var overlay_text: Label
var overlay_button: Button
var warned := {}
var skipping_phase := false
const TICK_BUDGET_US := 14000


func _ready() -> void:
	U.fill(self)
	var bd = U.team_backdrop()
	bd.band = 0.0
	add_child(bd)
	sim = Game.weekend_sim
	qsim = QualiSim.new()
	qsim.setup(sim)
	sim.quali = qsim
	var margin := U.screen_margin(self, 12)
	var M := U.is_mobile()
	var root := U.vbox(4 if M else 8)
	margin.add_child(root)
	root.add_child(_build_top())

	var tp := U.dark_panel(4)
	tp.custom_minimum_size = Vector2(390, 0)
	tower = Tower.new()
	tower.qsim = qsim
	tower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if M:
		tower.custom_minimum_size = Vector2(380, 34.0 + float(qsim.qcars.size()) * 29.0 + 8.0)
	tp.add_child(tower)

	var center := U.vbox(8)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mp := U.panel(4)
	mp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map = TrackMap.new()
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.set_track(sim.track)
	map.show_sectors = true
	map.interactive = true
	mp.add_child(map)
	center.add_child(mp)
	var lp := U.panel(8)
	lp.custom_minimum_size = Vector2(0, 56 if M else 140)
	log_label = RichTextLabel.new()
	log_label.add_theme_color_override("default_color", U.TEXT)
	log_label.bbcode_enabled = true
	log_label.scroll_active = false
	log_label.add_theme_font_size_override("normal_font_size", 14)
	log_label.add_theme_font_override("normal_font", U.font(false))
	lp.add_child(log_label)
	center.add_child(lp)

	var cols := U.columns([
		{"name": "Tabelle", "node": tp, "min": 390.0},
		{"name": "Karte", "node": center, "grow": true, "self_scroll": true},
		{"name": "Funk", "node": _build_controls(), "min": 360.0},
	], 10)
	root.add_child(cols)
	if M:
		(cols as TabContainer).current_tab = 2

	overlay = U.panel(22, U.WARN)
	overlay.visible = false
	overlay.custom_minimum_size = Vector2(520, 0)
	var ov := U.vbox(12)
	overlay.add_child(ov)
	overlay_title = U.heading("", 30)
	ov.add_child(overlay_title)
	overlay_text = U.label("", 16, U.TEXT)
	overlay_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ov.add_child(overlay_text)
	overlay_button = U.primary_button("WEITER", _on_continue, 0, 52)
	ov.add_child(overlay_button)
	add_child(overlay)

	qsim.start_next_phase()
	_set_speed(2)
	_select_default()


func _build_top() -> Control:
	var p := U.dark_panel(6 if U.is_mobile() else 8, U.ACCENT)
	var h := U.hbox(6 if U.is_mobile() else 16)
	p.add_child(h)
	var M := U.is_mobile()
	phase_label = U.display("Q1", 24 if M else 34, U.ACCENT.lightened(0.1))
	h.add_child(phase_label)
	var cl := U.vbox(0)
	if not M:
		cl.add_child(U.label("VERBLEIBENDE ZEIT", 10, U.MUTED_DARK, true))
	clock_label = U.display("18:00", 20 if M else 28, U.ON_DARK)
	cl.add_child(clock_label)
	h.add_child(cl)
	status_label = U.label("", 15, U.WARN, true)
	h.add_child(status_label)
	weather_label = U.label("", 14, U.MUTED_DARK)
	weather_label.clip_text = true
	weather_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(weather_label)
	var sg := U.hbox(2)
	h.add_child(sg)
	for i in SPEEDS.size():
		var b := U.dark_button(SPEED_NAMES_SHORT[i] if M else SPEED_NAMES[i], null, 36 if M else 56, 34 if M else 38)
		b.toggle_mode = true
		b.pressed.connect(_set_speed.bind(i))
		sg.add_child(b)
		speed_buttons.append(b)
	h.add_child(U.dark_button("Weiter >>" if M else "Abschnitt überspringen", _skip_phase, 84 if M else 190, 34 if M else 38))
	var cb := U.checkbox("", true)
	cb.text = "Auto" if U.is_mobile() else "Auto-Slow"
	cb.button_pressed = true
	cb.toggled.connect(func(v): auto_slow = v)
	h.add_child(cb)
	return p


func _build_controls() -> Control:
	var p := U.panel(12, U.WARN)
	p.custom_minimum_size = Vector2(360, 0)
	var v := U.vbox(10)
	p.add_child(v)
	v.add_child(U.heading("Boxenfunk", 16, U.MUTED))
	var card_row: Container = U.hbox(8) if U.is_mobile() else v
	if U.is_mobile():
		v.add_child(card_row)
	for q in qsim.qcars:
		if q.is_player:
			var cd := _build_card(q)
			cd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card_row.add_child(cd)
	v.add_child(U.spacer())
	var hint := U.label("Tipp: Die Strecke wird mit jeder Runde schneller. Gegen Ende fahren alle gleichzeitig - Verkehr kostet Zeit. Eine Outlap dauert ca. %.1f min." % (qsim.out_lap_time / 60.0), 12, U.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	return p


func _build_card(q) -> Control:
	var card := {"q": q, "comp": 0, "risk": 1}
	var box := U.panel(10)
	var v := U.vbox(6)
	box.add_child(v)
	var head := U.hbox(8)
	head.add_child(U.color_bar(q.car.color, 7, 26))
	head.add_child(U.label(q.car.driver_name, 18, U.TEXT, true))
	v.add_child(head)
	var st := U.label("", 14, U.MUTED)
	v.add_child(st)
	card["status"] = st
	var QM := U.is_mobile()
	var tr: Container = HBoxContainer.new() if QM else HFlowContainer.new()
	tr.add_theme_constant_override("h_separation", 4 if QM else 5)
	var tbtn := []
	for k in RaceSim.COMPOUNDS.size():
		var b := Button.new()
		b.toggle_mode = true
		b.text = (["Soft", "Med.", "Hard", "Inter", "Wet"][k]) if QM else RaceSim.COMPOUNDS[k]["name"]
		if QM:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size = Vector2(0, 36)
			b.add_theme_font_size_override("font_size", 13)
			b.clip_text = true
		b.add_theme_color_override("font_color", RaceSim.COMPOUNDS[k]["ink"])
		b.add_theme_color_override("font_hover_color", RaceSim.COMPOUNDS[k]["ink"])
		U.tyre_button(b, RaceSim.COMPOUNDS[k]["color"])
		b.pressed.connect(_on_comp.bind(card, k))
		tr.add_child(b)
		tbtn.append(b)
	v.add_child(tr)
	card["comp_buttons"] = tbtn
	var rr := U.hbox(5)
	var rbtn := []
	for i in 3:
		var b := Button.new()
		b.toggle_mode = true
		b.text = RISK_NAMES[i]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_risk.bind(card, i))
		rr.add_child(b)
		rbtn.append(b)
	v.add_child(U.label("Risiko", 12, U.MUTED))
	v.add_child(rr)
	card["risk_buttons"] = rbtn
	var rh := U.label("", 11, U.MUTED)
	rh.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(rh)
	card["risk_hint"] = rh
	var go := U.primary_button("AUF DIE STRECKE", _on_go.bind(card), 0, 46)
	v.add_child(go)
	card["go"] = go
	var auto := U.checkbox()
	auto.text = "Automatisch (KI entscheidet)"
	auto.toggled.connect(func(on): q.auto = on)
	v.add_child(auto)
	var rec := U.label("", 12, U.BLUE)
	v.add_child(rec)
	card["rec"] = rec
	cards.append(card)
	_refresh_card_buttons(card)
	return box


func _refresh_card_buttons(card: Dictionary) -> void:
	for k in card["comp_buttons"].size():
		card["comp_buttons"][k].set_pressed_no_signal(k == int(card["comp"]))
	for i in 3:
		card["risk_buttons"][i].set_pressed_no_signal(i == int(card["risk"]))
	if card.has("risk_hint"):
		card["risk_hint"].text = RISK_HINTS[int(card["risk"])]


func _on_comp(card: Dictionary, k: int) -> void:
	card["comp"] = k
	_refresh_card_buttons(card)


func _on_risk(card: Dictionary, i: int) -> void:
	card["risk"] = i
	_refresh_card_buttons(card)


func _on_go(card: Dictionary) -> void:
	var q = card["q"]
	if qsim.send_out(q, int(card["comp"]), int(card["risk"])):
		log_lines.append("[color=#b86f00]Funk an %s: Raus auf die Strecke, %s, Risiko %s.[/color]" % [q.car.code, RaceSim.COMPOUNDS[int(card["comp"])]["name"], RISK_NAMES[int(card["risk"])]])


func _select_default() -> void:
	for q in qsim.qcars:
		if q.is_player:
			tower.selected = q
			return


func _set_speed(i: int) -> void:
	speed_idx = i
	for k in speed_buttons.size():
		speed_buttons[k].set_pressed_no_signal(k == i)


func _skip_phase(blocking := false) -> void:
	if blocking:
		var n := 0
		while qsim.active and n < 6000:
			qsim.tick(1.0)
			n += 1
			_collect_events(false)
		return
	skipping_phase = true


func _process(delta: float) -> void:
	if qsim == null:
		return
	if skipping_phase:
		var t0 := Time.get_ticks_usec()
		while qsim.active and Time.get_ticks_usec() - t0 < TICK_BUDGET_US:
			qsim.tick(1.0)
			_collect_events(false)
		if not qsim.active:
			skipping_phase = false
	elif qsim.active and not overlay.visible:
		var spd: int = SPEEDS[speed_idx]
		if spd > 0:
			acc = minf(acc + delta * float(spd), 800.0)
			var t1 := Time.get_ticks_usec()
			while acc >= 1.0 and qsim.active:
				qsim.tick(1.0)
				_collect_events(true)
				_check_alerts()
				acc -= 1.0
				if Time.get_ticks_usec() - t1 > TICK_BUDGET_US:
					break
	elif not qsim.active and not overlay.visible and qsim.phase_idx >= 0:
		_show_overlay()
	_update_ui()


func _collect_events(allow_slow: bool) -> void:
	while ev_index < qsim.events.size():
		var e: Dictionary = qsim.events[ev_index]
		ev_index += 1
		var col := "#c8cfdc"
		match e["kind"]:
			"crash":
				col = "#d93025"
			"mistake":
				col = "#ff9a3d"
			"lap":
				col = "#0f9d58"
			"weather":
				col = "#1f5fd6"
		var m := "%s  %s" % [_fmt_clock(qsim.time), e["text"]]
		log_lines.append("[color=%s]%s[/color]" % [col, m])
		if allow_slow and auto_slow and speed_idx > 2 and (e["kind"] == "crash" or e["kind"] == "weather" or (e["kind"] == "lap" and e["player"])):
			_set_speed(2)
	if log_lines.size() > 40:
		log_lines = log_lines.slice(log_lines.size() - 40)


func _check_alerts() -> void:
	if not auto_slow or speed_idx <= 2:
		return
	var left: float = qsim.time_left()
	for q in qsim.qcars:
		if q.is_player and not q.auto and q.state == 0 and not q.crashed and not q.eliminated:
			var latest: float = qsim.time_left() - qsim.out_lap_time
			if latest < 120.0 and latest > 0.0 and qsim.can_send(q):
				var key := "%s_%d_%d" % [q.car.code, qsim.phase_idx, q.runs]
				if not warned.has(key):
					warned[key] = true
					log_lines.append("[color=#b86f00]Funk: %s - letzte Chance für eine Runde (noch %s)![/color]" % [q.car.code, _fmt_clock(latest)])
					_set_speed(2)


func _fmt_clock(t: float) -> String:
	var s := maxi(0, int(t))
	return "%02d:%02d" % [int(s / 60), s % 60]


func _update_ui() -> void:
	phase_label.text = qsim.phase_name() if qsim.phase_idx >= 0 else "Q"
	clock_label.text = _fmt_clock(qsim.time_left())
	var lc := U.ON_DARK
	if qsim.time_left() < 120.0 and qsim.active:
		lc = U.WARN
	clock_label.add_theme_color_override("font_color", lc)
	status_label.text = "ZIELFLAGGE" if qsim.closed and qsim.active else ""
	weather_label.text = "%s  |  %s" % [qsim.weather_text(), qsim.forecast_text()]
	var from := maxi(0, log_lines.size() - 7)
	var recent: Array = log_lines.slice(from)
	recent.reverse()
	log_label.text = "\n".join(recent)
	# Karte
	var dots: Array = []
	for q in qsim.qcars:
		if q.eliminated:
			continue
		var wp = qsim.car_world_pos(q, qsim.time - 1.0 + clampf(acc, 0.0, 1.0) if (qsim.active and not skipping_phase and SPEEDS[speed_idx] <= 16 and SPEEDS[speed_idx] > 0) else -1.0)
		if wp != null:
			dots.append({"pos": wp, "color": q.car.color, "code": q.car.code, "player": q.is_player, "selected": q == tower.selected, "label": qsim.rank_of(q) <= 3})
	map.dots = dots
	# Karten
	for card in cards:
		var q = card["q"]
		var txt := ""
		if q.eliminated:
			txt = "Ausgeschieden"
		elif q.crashed:
			txt = "Unfall - Auto beschädigt"
		elif q.state == 1:
			if qsim.time < q.out_end:
				txt = "Outlap ... noch %d s" % int(q.out_end - qsim.time)
			elif q.fly_end > 0.0 and qsim.time <= q.fly_end:
				txt = "Fliegende Runde ... noch %d s" % int(q.fly_end - qsim.time)
			else:
				txt = "Inlap"
		else:
			txt = "In der Box"
		if not q.eliminated:
			if q.best > 0.0:
				txt += "   |   Bestzeit %s  (P%d)" % [sim.fmt_time(q.best), qsim.rank_of(q)]
			else:
				txt += "   |   noch ohne Zeit"
		card["status"].text = txt
		var can: bool = qsim.can_send(q)
		card["go"].disabled = not can
		var rc := -1
		if qsim.wet > 0.62:
			rc = 4
		elif qsim.wet > 0.2:
			rc = 3
		card["rec"].text = ("Empfehlung: %s (Nässe %d %%)" % [RaceSim.COMPOUNDS[rc]["name"], int(qsim.wet * 100.0)]) if rc >= 0 else ""
	if tower.selected != null:
		pass


func _show_overlay() -> void:
	overlay.visible = true
	overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var nm: String = qsim.phase_name()
	if qsim.finished:
		var order: Array = qsim.final_order()
		overlay_title.text = "Qualifying beendet"
		var pole = order[0]
		var t := "POLE-POSITION: %s  %s  (%s)\n\n" % [pole.code, sim.fmt_time(qsim.best_time_of(pole)), pole.team_name]
		var grid_order: Array = qsim.final_grid()
		var line := ""
		for i in mini(10, grid_order.size()):
			line += "%d. %s   " % [i + 1, grid_order[i].code]
		t += "Startaufstellung (nach Strafen): " + line
		for q in qsim.qcars:
			if q.is_player:
				t += "\n\n%s startet von P%d" % [q.car.code, grid_order.find(q.car) + 1]
		overlay_text.text = t
		overlay_button.text = "ZUR STARTAUFSTELLUNG"
	else:
		overlay_title.text = "%s beendet" % nm
		var names := ""
		var n := 0
		for q in qsim.tail:
			if n < 12:
				names += q.car.code + "  "
			n += 1
		var mine := ""
		for q in qsim.qcars:
			if q.is_player:
				mine += "\n%s: %s" % [q.car.code, "AUSGESCHIEDEN" if q.eliminated else "weiter in den nächsten Abschnitt"]
		overlay_text.text = "Ausgeschieden: %s%s" % [names, mine]
		overlay_button.text = "WEITER ZU %s" % qsim.phases[qsim.phase_idx + 1]["name"].to_upper() if qsim.phase_idx + 1 < qsim.phases.size() else "WEITER"
	_set_speed(0)


func _on_continue() -> void:
	if qsim.finished:
		sim.finish_qualifying(qsim)
		main.show_weekend()
		return
	overlay.visible = false
	qsim.start_next_phase()
	_set_speed(2)

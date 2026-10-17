extends Node
## Wurzel: wechselt zwischen den Bildschirmen (Start, Saison-Zentrale, Wochenende, Qualifying, Rennen, Ergebnis ...).
## Handy-Modus: kleinere virtuelle Bildschirmgröße (große Bedienelemente), Touch-Mindestgrößen, Hinweis zum Drehen.

const U = preload("res://scripts/ui.gd")
const StartScreen = preload("res://scripts/screen_start.gd")
const HubScreen = preload("res://scripts/screen_hub.gd")
const WeekendScreen = preload("res://scripts/screen_weekend.gd")
const QualiScreen = preload("res://scripts/screen_quali.gd")
const RaceScreen = preload("res://scripts/screen_race.gd")
const ResultsScreen = preload("res://scripts/screen_results.gd")
const MarketScreen = preload("res://scripts/screen_market.gd")
const LineupScreen = preload("res://scripts/screen_lineup.gd")
const PracticeScreen = preload("res://scripts/screen_practice.gd")

var current: Node = null
var _theme: Theme = null

# Wisch-Scrollen am Handy: Wisch auf Knöpfen und Karten scrollt die darunterliegende Liste (mit Schwung).
# Es wird die innerste Liste gewählt, die in Wischrichtung noch scrollen kann (sonst die äußere); Bruchteile von Pixeln gehen nicht verloren.
var _ts_list: Array = []          # ScrollContainer unter dem Finger, innerster zuletzt
var _ts_sc: ScrollContainer = null
var _ts_horiz := false
var _ts_blocked := false
var _ts_dist := 0.0
var _ts_acc := Vector2.ZERO       # Weg seit Berührungsbeginn
var _ts_scrolling := false
var _ts_vel := Vector2.ZERO       # Geschwindigkeit in Pixel pro Sekunde (geglättet)
var _ts_idx := -1                 # Kennung des ersten Fingers (Browser vergeben sie beliebig)
var _ts_last_t := 0.0
var rotate_hint: CanvasLayer


func _ready() -> void:
	_theme = U.make_theme()
	get_window().theme = _theme
	RenderingServer.set_default_clear_color(U.BG0)
	if U.is_mobile():
		apply_scale()
		Engine.max_fps = 30   # schont Akku und Grafikspeicher (verhindert "WebGL context lost" auf iPad/Handy)
		get_tree().node_added.connect(_touchify)
		_make_rotate_hint()
	show_start()
	if OS.has_feature("web") and str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('bench')", true)) == "1":
		_bench()


## Leistungstest für den Browser (Adresse mit ?bench=1): Karriere starten, Qualifying und Rennen sofort berechnen. Zeiten stehen in der Konsole.
func _bench() -> void:
	await get_tree().create_timer(1.0).timeout
	Game.new_season(2024, "mclaren")
	Game.round_index = 1
	show_weekend()
	await get_tree().create_timer(1.0).timeout
	var t0 := Time.get_ticks_msec()
	current._on_auto_quali()
	while current == null or current.get("quali_done_flag") == null and not Game.weekend_sim.quali_done:
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	print("[Zeit] Qualifying-Ablauf gesamt %d ms" % (Time.get_ticks_msec() - t0))
	current._on_instant()


## Alle sichtbaren ScrollContainer unter pos (äußerster zuerst); blocked = Finger liegt auf Karte oder Schieberegler (die ziehen selbst).
func _find_scroll(node: Node, pos: Vector2, res: Dictionary) -> void:
	if node is Control:
		var c := node as Control
		if not c.visible or not c.get_global_rect().has_point(pos):
			return
		if node is ScrollContainer:
			res["list"].append(node)
		elif node is HSlider or node.is_in_group("no_touch_scroll"):
			res["blocked"] = true
	for ch in node.get_children():
		_find_scroll(ch, pos, res)


## Kann der Container in der gewünschten Richtung scrollen? dir > 0: Inhalt nach unten/rechts ziehen (Wert sinkt).
func _can_scroll(sc: ScrollContainer, horiz: bool, content_move: float) -> bool:
	var bar: ScrollBar = sc.get_h_scroll_bar() if horiz else sc.get_v_scroll_bar()
	if horiz and sc.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		return false
	if not horiz and sc.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
		return false
	var rng := bar.max_value - bar.page
	if rng < 2.0:
		return false
	if content_move > 0.0:      # Finger zieht nach unten: Wert sinkt
		return bar.value > 0.5
	return bar.value < rng - 0.5


func _pick_scroll(horiz: bool, move: float) -> ScrollContainer:
	for i in range(_ts_list.size() - 1, -1, -1):
		var sc: ScrollContainer = _ts_list[i]
		if is_instance_valid(sc) and _can_scroll(sc, horiz, move):
			return sc
	return null


func _scroll_by(sc: ScrollContainer, horiz: bool, delta_px: float) -> void:
	var bar: ScrollBar = sc.get_h_scroll_bar() if horiz else sc.get_v_scroll_bar()
	bar.value = clampf(bar.value - delta_px, 0.0, maxf(bar.max_value - bar.page, 0.0))


func _input(event: InputEvent) -> void:
	if not U.is_mobile():
		return
	var st := event as InputEventScreenTouch
	if st != null and (st.index == _ts_idx or (st.pressed and _ts_idx == -1)):
		if st.pressed:
			_ts_idx = st.index
			U.touch_scrolled = false
			_ts_dist = 0.0
			_ts_acc = Vector2.ZERO
			_ts_vel = Vector2.ZERO
			_ts_scrolling = false
			_ts_sc = null
			_ts_last_t = Time.get_ticks_msec() / 1000.0
			var res := {"list": [], "blocked": false}
			if current != null:
				_find_scroll(current, st.position, res)
			_ts_list = res["list"]
			_ts_blocked = res["blocked"] or _ts_list.is_empty()
		else:
			# kurzer Stillstand vor dem Loslassen: kein Nachlaufen
			if Time.get_ticks_msec() / 1000.0 - _ts_last_t > 0.09:
				_ts_vel = Vector2.ZERO
			_ts_scrolling = false
			_ts_idx = -1
		return
	var sd := event as InputEventScreenDrag
	if sd != null and sd.index == _ts_idx and not _ts_blocked:
		_ts_acc += sd.relative
		if not _ts_scrolling:
			if _ts_acc.length() < 8.0:
				return
			# Achse und Container beim Überschreiten der Schwelle festlegen
			_ts_horiz = absf(_ts_acc.x) > absf(_ts_acc.y) * 1.2
			var move: float = _ts_acc.x if _ts_horiz else _ts_acc.y
			_ts_sc = _pick_scroll(_ts_horiz, move)
			if _ts_sc == null:
				_ts_horiz = not _ts_horiz
				move = _ts_acc.x if _ts_horiz else _ts_acc.y
				_ts_sc = _pick_scroll(_ts_horiz, move)
			if _ts_sc == null:
				_ts_blocked = true
				return
			_ts_scrolling = true
			U.touch_scrolled = true
			get_viewport().gui_release_focus()   # bricht ein begonnenes Drücken auf einem Knopf ab
			_scroll_by(_ts_sc, _ts_horiz, move)   # bereits zurückgelegten Weg nachholen
		else:
			var d: float = sd.relative.x if _ts_horiz else sd.relative.y
			_scroll_by(_ts_sc, _ts_horiz, d)
			var now := Time.get_ticks_msec() / 1000.0
			var dt := maxf(now - _ts_last_t, 0.004)
			_ts_last_t = now
			var v := d / dt
			_ts_vel = _ts_vel.lerp(Vector2(v, 0.0) if _ts_horiz else Vector2(0.0, v), 0.45)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Schwung nach dem Loslassen
	if _ts_sc != null and is_instance_valid(_ts_sc) and not _ts_scrolling and _ts_vel.length() > 25.0:
		var v: float = _ts_vel.x if _ts_horiz else _ts_vel.y
		_scroll_by(_ts_sc, _ts_horiz, v * delta)
		_ts_vel *= pow(0.04, delta)
	elif not _ts_scrolling:
		_ts_vel = Vector2.ZERO


## Anzeigegröße (Handy): kleinere virtuelle Höhe = alles größer.
func apply_scale() -> void:
	if U.is_mobile():
		get_window().content_scale_size = U.mobile_base_size()


## Alle Bedienelemente auf Fingergröße bringen.
func _touchify(n: Node) -> void:
	if n is Button:
		var b := n as Button
		b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, 40.0)
	elif n is HSlider:
		var s := n as HSlider
		s.custom_minimum_size.y = maxf(s.custom_minimum_size.y, 32.0)
	elif n is SpinBox:
		var sp := n as SpinBox
		sp.custom_minimum_size.y = maxf(sp.custom_minimum_size.y, 40.0)


func _make_rotate_hint() -> void:
	rotate_hint = CanvasLayer.new()
	rotate_hint.layer = 100
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.07, 0.97)
	U.fill(bg)
	var l := U.label("Bitte das Gerät quer halten", 26, U.TEXT, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	U.fill(l)
	bg.add_child(l)
	rotate_hint.add_child(bg)
	add_child(rotate_hint)
	get_window().size_changed.connect(_check_orientation)
	_check_orientation()


func _check_orientation() -> void:
	var s := get_window().size
	rotate_hint.visible = float(s.x) < float(s.y) * 1.1


func _switch(node: Control) -> void:
	if current != null:
		current.queue_free()
	current = node
	node.theme = _theme    # main ist ein Node: das Fenster-Theme würde sonst nicht an die Bildschirme vererbt
	node.set("main", self)
	node.modulate.a = 0.0
	add_child(node)
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", 1.0, 0.22)


func show_start() -> void:
	_switch(StartScreen.new())


func show_hub() -> void:
	_switch(HubScreen.new())


func show_weekend() -> void:
	_switch(WeekendScreen.new())


func show_quali() -> void:
	_switch(QualiScreen.new())


func show_race(sim, auto := false) -> void:
	var s := RaceScreen.new()
	s.sim = sim
	s.auto_finish = auto
	_switch(s)


func show_results() -> void:
	_switch(ResultsScreen.new())


func show_market() -> void:
	_switch(MarketScreen.new())


func show_practice() -> void:
	_switch(PracticeScreen.new())


func show_lineup() -> void:
	_switch(LineupScreen.new())

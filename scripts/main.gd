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
var rotate_hint: CanvasLayer


func _ready() -> void:
	get_window().theme = U.make_theme()
	RenderingServer.set_default_clear_color(U.BG0)
	if U.is_mobile():
		apply_scale()
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

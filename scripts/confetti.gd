extends Control
## Konfetti-Regen über einem Bereich (Sieg, Titel): bunte Streifen fallen, drehen und schaukeln, nach einigen Sekunden
## blendet alles aus und der Knoten entfernt sich selbst. Fängt keine Eingaben. Nur mit Effekten (sonst sofort weg).

const U = preload("res://scripts/ui.gd")

var colors: Array = []
var count := 80
var duration := 4.5
var _p: Array = []
var _t := 0.0


static func burst(parent: Control, cols: Array = []) -> void:
	if not U.fx_on() or parent == null:
		return
	var c = load("res://scripts/confetti.gd").new()
	c.colors = cols
	parent.add_child(c)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 20
	if colors.is_empty():
		colors = [U.ACCENT, Color("facc15"), Color.WHITE, Color("34d399"), Color("60a5fa"), Color("f472b6")]
	await get_tree().process_frame
	for i in count:
		_p.append({
			"pos": Vector2(randf() * size.x, -randf() * size.y * 0.6 - 10.0),
			"vel": Vector2(randf_range(-30.0, 30.0), randf_range(60.0, 140.0)),
			"rot": randf() * TAU, "spin": randf_range(-6.0, 6.0), "sway": randf() * TAU,
			"size": Vector2(randf_range(5.0, 9.0), randf_range(8.0, 14.0)),
			"col": colors[i % colors.size()]})


func _process(delta: float) -> void:
	_t += delta
	for p in _p:
		p["vel"].y = minf(p["vel"].y + 40.0 * delta, 220.0)
		p["sway"] += delta * 3.0
		p["pos"] += (p["vel"] + Vector2(sin(p["sway"]) * 40.0, 0.0)) * delta
		p["rot"] += p["spin"] * delta
	queue_redraw()
	if _t > duration:
		queue_free()


func _draw() -> void:
	var a := clampf((duration - _t) / 0.8, 0.0, 1.0)
	for p in _p:
		var s: Vector2 = p["size"]
		# Drehung um die Längsachse: die Breite schwankt, wirkt wie ein flatternder Papierstreifen
		var w: float = s.x * absf(cos(p["rot"]))
		draw_set_transform(p["pos"], p["rot"] * 0.5, Vector2.ONE)
		draw_rect(Rect2(-w * 0.5, -s.y * 0.5, maxf(w, 1.0), s.y), Color(p["col"], a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

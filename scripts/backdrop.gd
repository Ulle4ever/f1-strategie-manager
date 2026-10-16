extends Control
## Hintergrund im F1-Stil: Verlauf, Carbon-Streifen, roter Schrägakzent.

const U = preload("res://scripts/ui.gd")
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if int(_t * 4.0) != int((_t - delta) * 4.0):
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	# vertikaler Verlauf
	var steps := 24
	for i in steps:
		var f := float(i) / steps
		draw_rect(Rect2(0, h * f, w, h / steps + 1.0), U.BG0.lerp(U.BG1, f))
	# Carbon-Diagonalen
	var x := -h
	while x < w:
		draw_line(Vector2(x, h), Vector2(x + h, 0), Color(1, 1, 1, 0.022), 2.0)
		x += 26.0
	# roter Schrägakzent links oben
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.34, 0), Vector2(w * 0.28, 7), Vector2(0, 7)]), U.ACCENT)
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.35, 0), Vector2(w * 0.37, 0), Vector2(w * 0.31, 7), Vector2(w * 0.29, 7)]), Color(U.ACCENT, 0.5))
	# sanfter roter Schein unten rechts
	for i in 7:
		var r := 420.0 - i * 50.0
		draw_circle(Vector2(w, h), r, Color(0.88, 0.02, 0.0, 0.012 + i * 0.002))

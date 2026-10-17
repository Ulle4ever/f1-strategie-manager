extends Control
## Hintergrund: heller Verlauf mit feinem Raster und einem Farbschleier in der Akzent- bzw. Teamfarbe.

const U = preload("res://scripts/ui.gd")

var accent := Color("e10600")


func _draw() -> void:
	var w := size.x
	var h := size.y
	var steps := 20
	for i in steps:
		var f := float(i) / steps
		draw_rect(Rect2(0, h * f, w, h / steps + 1.0), U.BG0.lerp(U.BG1, f))
	var x := 0.0
	while x < w:
		draw_line(Vector2(x, 0), Vector2(x, h), U.tint(0.035), 1.0)
		x += 48.0
	var y := 0.0
	while y < h:
		draw_line(Vector2(0, y), Vector2(w, y), U.tint(0.035), 1.0)
		y += 48.0
	# Farbband oben (Akzent- bzw. Teamfarbe) und weicher Schein rechts oben
	draw_rect(Rect2(0, 0, w, 4), accent)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.26, 0), Vector2(w * 0.23, 8), Vector2(0, 8)]), accent.darkened(0.25))
	for i in 7:
		var r := 420.0 - i * 55.0
		draw_circle(Vector2(w, 0), r, Color(accent, 0.012 + i * 0.0016))

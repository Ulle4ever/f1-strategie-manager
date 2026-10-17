extends Control
## Hintergrund: ruhiger dunkler Verlauf mit feinem Raster und rotem Akzent oben.

const U = preload("res://scripts/ui.gd")


func _draw() -> void:
	var w := size.x
	var h := size.y
	var steps := 20
	for i in steps:
		var f := float(i) / steps
		draw_rect(Rect2(0, h * f, w, h / steps + 1.0), U.BG0.lerp(Color("131a2a"), f))
	var x := 0.0
	while x < w:
		draw_line(Vector2(x, 0), Vector2(x, h), Color(1, 1, 1, 0.018), 1.0)
		x += 48.0
	var y := 0.0
	while y < h:
		draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, 0.018), 1.0)
		y += 48.0
	draw_rect(Rect2(0, 0, w, 3), Color(U.ACCENT, 0.85))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.22, 0), Vector2(w * 0.20, 5), Vector2(0, 5)]), U.ACCENT_HI)
	for i in 6:
		var r := 380.0 - i * 55.0
		draw_circle(Vector2(w, h), r, Color(0.88, 0.02, 0.0, 0.010 + i * 0.0016))

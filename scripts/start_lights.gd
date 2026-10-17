extends Control
## Startampel: fünf rote Lichtpaare, die nacheinander angehen und zum Start erlöschen.

const U = preload("res://scripts/ui.gd")

var lights_on := 0
var out := false


func _draw() -> void:
	var w := 60.0
	var total := w * 5.0
	var x0 := (size.x - total) * 0.5
	var y0 := 10.0
	draw_rect(Rect2(x0 - 14, y0 - 6, total + 28, 150), Color(0.02, 0.03, 0.05, 0.92))
	draw_rect(Rect2(x0 - 14, y0 - 6, total + 28, 150), Color(1, 1, 1, 0.12), false, 2.0)
	for i in 5:
		var cx := x0 + w * i + w * 0.5
		for row in 2:
			var cy := y0 + 34.0 + row * 62.0
			var lit := (not out) and i < lights_on
			draw_circle(Vector2(cx, cy), 24.0, Color(0.10, 0.02, 0.02))
			if lit:
				draw_circle(Vector2(cx, cy), 36.0, Color(1, 0.05, 0.02, 0.10))
				draw_circle(Vector2(cx, cy), 28.0, Color(1, 0.05, 0.02, 0.18))
				draw_circle(Vector2(cx, cy), 21.0, Color(1.0, 0.12, 0.08))
				draw_circle(Vector2(cx - 6, cy - 7), 6.0, Color(1, 0.75, 0.7, 0.8))
			else:
				draw_circle(Vector2(cx, cy), 21.0, Color(0.16, 0.05, 0.05))
	var font := U.font(true)
	var txt := "LIGHTS OUT!" if out else "BEREIT ZUM START"
	draw_string(font, Vector2(0, y0 + 166), txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, U.WARN if out else U.MUTED_DARK)

extends Control
## Skala -1 .. +1 mit zwei Markern: Auto-Eigenschaft (farbiger Punkt) und Anforderung der Strecke (weißer Rhombus).
## Je näher beide beieinander liegen, desto besser passt das Auto zur Strecke.

const U = preload("res://scripts/ui.gd")

var car_value := 0.0
var track_value := 0.0
var car_color := U.WARN
var left_text := ""
var right_text := ""


func _init() -> void:
	custom_minimum_size = Vector2(0, 34)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(car: float, track: float, col: Color, l: String, r: String) -> void:
	car_value = car
	track_value = track
	car_color = col
	left_text = l
	right_text = r
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var y := 12.0
	var font := U.font(false)
	draw_rect(Rect2(0, y - 3, w, 6), U.tint(0.12))
	draw_rect(Rect2(w * 0.5 - 1, y - 6, 2, 12), U.tint(0.35))
	var tx: float = w * (track_value * 0.5 + 0.5)
	var cx: float = w * (car_value * 0.5 + 0.5)
	# Passung: Verbindungslinie zwischen den Markern
	var ok := absf(car_value - track_value) < 0.5
	draw_line(Vector2(tx, y), Vector2(cx, y), U.GOOD if ok else U.BAD, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(tx, y - 7), Vector2(tx + 6, y), Vector2(tx, y + 7), Vector2(tx - 6, y)]), U.TEXT)
	draw_circle(Vector2(cx, y), 6.0, car_color)
	draw_arc(Vector2(cx, y), 6.0, 0.0, TAU, 20, Color.WHITE, 1.5)
	draw_string(font, Vector2(0, 31), left_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, U.MUTED)
	var rw := font.get_string_size(right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(font, Vector2(w - rw, 31), right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, U.MUTED)

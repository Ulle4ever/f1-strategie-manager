extends Control
## Zeile im Autoprofil: Beschriftung, Skala -1 .. +1 mit gefülltem Balken ab der Mitte und Randtexten.

const U = preload("res://scripts/ui.gd")

var title := ""
var value := 0.0
var left_text := ""
var right_text := ""
var col := Color("e10600")
var _shown := 0.0      # angezeigter Wert (gleitet beim ersten Anzeigen auf value)
var base := NAN       # Ausgangswert (Saisonstart) als heller Kreis, NAN = keiner


func setup(p_title: String, p_value: float, l: String, r: String, p_col: Color, p_base := NAN) -> void:
	title = p_title
	value = p_value
	base = p_base
	_shown = value
	if U.fx_on():
		_shown = 0.0 if is_nan(base) else base
		load("res://scripts/anim.gd").on_first_visible(self, func():
			var tw := create_tween()
			tw.tween_property(self, "_shown", value, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT))
	left_text = l
	right_text = r
	col = p_col
	custom_minimum_size = Vector2(0, 40)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(_d: float) -> void:
	if absf(_shown - value) > 0.0005:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var fb := U.font(true)
	var f := U.font(false)
	draw_string(fb, Vector2(0, 11), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, U.MUTED)
	var y := 17.0
	draw_rect(Rect2(0, y, w, 6), U.tint(0.10))
	var mid := w * 0.5
	var x := w * (clampf(_shown, -1.0, 1.0) * 0.5 + 0.5)
	draw_rect(Rect2(minf(mid, x), y, absf(x - mid), 6), col)
	draw_rect(Rect2(mid - 1, y - 3, 2, 12), U.tint(0.35))
	if not is_nan(base) and absf(base - value) > 0.015:
		var bx := w * (clampf(base, -1.0, 1.0) * 0.5 + 0.5)
		draw_circle(Vector2(bx, y + 3), 5.0, Color(col, 0.28))
		draw_arc(Vector2(bx, y + 3), 5.0, 0.0, TAU, 16, Color(col, 0.7), 1.2)
	draw_circle(Vector2(x, y + 3), 6.0, col)
	draw_arc(Vector2(x, y + 3), 6.0, 0.0, TAU, 16, Color.WHITE, 1.5)
	draw_string(f, Vector2(0, 36), left_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, U.MUTED)
	var rw := f.get_string_size(right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(f, Vector2(w - rw, 36), right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, U.MUTED)

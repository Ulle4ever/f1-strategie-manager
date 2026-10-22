extends Control
## Einfache Linien-Symbole, im Code gezeichnet (keine Schriftdatei nötig): race, team, calendar, trophy, podium, gear,
## people, driver, career, tyre, fuel, weather, info. Gezeichnet auf einem 24er-Raster, skaliert auf die Größe.

var kind := "info"
var color := Color.WHITE


static func make(p_kind: String, px := 20.0, p_col := Color.WHITE) -> Control:
	var ic = load("res://scripts/icon.gd").new()
	ic.kind = p_kind
	ic.color = p_col
	ic.custom_minimum_size = Vector2(px, px)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


func set_color(c: Color) -> void:
	color = c
	queue_redraw()


func _p(x: float, y: float) -> Vector2:
	var s := minf(size.x, size.y) / 24.0
	var o := (size - Vector2(24, 24) * s) * 0.5
	return o + Vector2(x, y) * s


func _w(w: float) -> float:
	return maxf(1.2, w * minf(size.x, size.y) / 24.0)


func _poly(pts: Array, closed := true, w := 2.0) -> void:
	var arr := PackedVector2Array()
	for q in pts:
		arr.append(_p(q[0], q[1]))
	if closed:
		arr.append(arr[0])
	draw_polyline(arr, color, _w(w), true)


func _rect(x: float, y: float, w: float, h: float, filled := false) -> void:
	if filled:
		draw_rect(Rect2(_p(x, y), _p(x + w, y + h) - _p(x, y)), color)
	else:
		_poly([[x, y], [x + w, y], [x + w, y + h], [x, y + h]])


func _circle(x: float, y: float, r: float, filled := false, w := 2.0) -> void:
	var s := minf(size.x, size.y) / 24.0
	if filled:
		draw_circle(_p(x, y), r * s, color)
	else:
		draw_arc(_p(x, y), r * s, 0.0, TAU, 28, color, _w(w), true)


func _arc(x: float, y: float, r: float, a0: float, a1: float, w := 2.0) -> void:
	var s := minf(size.x, size.y) / 24.0
	draw_arc(_p(x, y), r * s, a0, a1, 20, color, _w(w), true)


func _line(x0: float, y0: float, x1: float, y1: float, w := 2.0) -> void:
	draw_line(_p(x0, y0), _p(x1, y1), color, _w(w), true)


func _draw() -> void:
	match kind:
		"race":
			_line(5, 3, 5, 21)
			for r in 3:
				for k in 4:
					if (r + k) % 2 == 0:
						_rect(6 + k * 3.5, 4 + r * 3.0, 3.5, 3.0, true)
			_poly([[6, 4], [20, 4], [20, 13], [6, 13]], true, 1.4)
		"team":
			_poly([[12, 3], [20, 6], [19, 14], [12, 21], [5, 14], [4, 6]])
			_line(12, 7, 12, 17, 1.6)
		"calendar":
			_poly([[4, 6], [20, 6], [20, 20], [4, 20]])
			_rect(4, 6, 16, 4, true)
			_line(8, 3, 8, 7)
			_line(16, 3, 16, 7)
			for k in 3:
				_rect(6.5 + k * 4.0, 13, 2.5, 2.5, true)
		"trophy":
			_poly([[7, 4], [17, 4], [16, 10], [12, 13], [8, 10]])
			_arc(6.5, 7, 2.5, PI * 0.5, PI * 1.5)
			_arc(17.5, 7, 2.5, -PI * 0.5, PI * 0.5)
			_line(12, 13, 12, 17)
			_rect(8, 17, 8, 3, true)
		"podium":
			_rect(3, 13, 6, 8)
			_rect(9, 7, 6, 14)
			_rect(15, 16, 6, 5)
			_circle(12, 3.5, 1.5, true)
		"gear":
			for k in 8:
				var a := TAU * float(k) / 8.0
				_line(12 + cos(a) * 6.5, 12 + sin(a) * 6.5, 12 + cos(a) * 9.5, 12 + sin(a) * 9.5, 3.2)
			_circle(12, 12, 6.5)
			_circle(12, 12, 2.4)
		"people":
			_circle(9, 8, 3)
			_arc(9, 20, 6, PI, TAU)
			_circle(17, 9, 2.4)
			_arc(17.5, 20, 4.5, PI * 1.15, TAU)
		"driver":
			_circle(12, 8, 4)
			_arc(12, 21, 8, PI, TAU)
		"career":
			_poly([[4, 8], [20, 8], [20, 20], [4, 20]])
			_poly([[9, 8], [9, 5], [15, 5], [15, 8]], false)
			_line(4, 13, 20, 13, 1.6)
		"tyre":
			_circle(12, 12, 9)
			_circle(12, 12, 4.5)
		"fuel":
			_poly([[5, 4], [14, 4], [14, 20], [5, 20]])
			_rect(7, 7, 5, 4, true)
			_poly([[14, 9], [18, 11], [18, 18], [20, 18]], false, 1.6)
		"weather":
			_arc(9, 13, 4, PI * 0.75, PI * 1.9)
			_arc(15, 12, 5, PI * 1.1, TAU + PI * 0.25)
			_line(6, 17, 19, 17)
			_line(8, 20, 7, 22, 1.6)
			_line(13, 20, 12, 22, 1.6)
			_line(18, 20, 17, 22, 1.6)
		_:
			_circle(12, 12, 9)
			_line(12, 11, 12, 17)
			_circle(12, 7.5, 1.3, true)

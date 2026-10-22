extends Control
## Streifen "Rausfahrt": Autos rund um den Punkt, an dem das eigene Auto nach dem Stopp auf die Strecke kommt
## (Mitte = du, rechts = vor dir in Fahrtrichtung, ±4,5 s). Überrundete Autos blass.

const U = preload("res://scripts/ui.gd")
const TeamStyle = preload("res://scripts/team_style.gd")

const RANGE := 4.5

var near: Array = []
var me_code := ""


func setup(p_near: Array, p_me: String) -> void:
	near = p_near
	me_code = p_me
	custom_minimum_size = Vector2(0, 52)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _x(gap: float) -> float:
	return size.x * 0.5 + clampf(gap / RANGE, -1.0, 1.0) * (size.x * 0.5 - 22.0)


func _draw() -> void:
	var f := U.font(true)
	var fs := U.font(false)
	var y := 26.0
	draw_rect(Rect2(0, y - 1, size.x, 2), U.tint(0.14))
	for s in [-4, -2, 2, 4]:
		var x := _x(float(s))
		draw_rect(Rect2(x - 0.5, y - 4, 1, 8), U.tint(0.25))
		var t := "%+d s" % s
		var tw := fs.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		draw_string(fs, Vector2(x - tw * 0.5, size.y - 2), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, U.MUTED)
	draw_string(fs, Vector2(0, size.y - 2), "dahinter", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, U.MUTED)
	var vw := fs.get_string_size("davor", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(fs, Vector2(size.x - vw, size.y - 2), "davor", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, U.MUTED)
	# Autos: abwechselnd oben/unten, damit sich Kürzel nicht überdecken
	var row := 0
	var last_x := -999.0
	for n in near:
		var x := _x(float(n["gap"]))
		if absf(x - last_x) < 34.0:
			row = 1 - row
		else:
			row = 0
		last_x = x
		var col: Color = TeamStyle.ui_color(str(n["team_id"]))
		var a := 0.45 if bool(n["lapped"]) else 1.0
		var ry := y - 19.0 if row == 0 else y + 4.0
		var r := Rect2(x - 16.0, ry, 32.0, 15.0)
		draw_rect(r, Color(U.PANEL3, a))
		draw_rect(Rect2(r.position.x, r.position.y, 3, r.size.y), Color(col, a))
		var code := str(n["code"])
		var cw := f.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(f, Vector2(x - cw * 0.5 + 1.5, ry + 11.5), code, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(U.TEXT, a))
		draw_line(Vector2(x, y - 3), Vector2(x, y + 3), Color(col, a), 2.0)
	# du
	var mx := _x(0.0)
	draw_circle(Vector2(mx, y), 6.5, U.ACCENT)
	draw_arc(Vector2(mx, y), 6.5, 0.0, TAU, 20, Color.WHITE, 1.5)
	var mw := f.get_string_size("DU", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(f, Vector2(mx - mw * 0.5, y + 3.5), "DU", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)

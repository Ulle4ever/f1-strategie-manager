extends Control
## Wetterbericht als Balkendiagramm: Regenstärke über die restliche Renndauer (Balkenhöhe = Intensität,
## Deckkraft = Sicherheit der Vorhersage), mit Schwellen für leichten/mäßigen/starken Regen.

const U = preload("res://scripts/ui.gd")

var report := {}
var laps := 50


func _init() -> void:
	custom_minimum_size = Vector2(0, 92)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_report(r: Dictionary, p_laps: int) -> void:
	report = r
	laps = p_laps
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var top := 6.0
	var axis_h := 16.0
	var ch := h - top - axis_h
	var base := top + ch
	draw_rect(Rect2(0, top, w, ch), Color(1, 1, 1, 0.04))
	var font := U.font(false)
	# Schwellen: 2,5 mm/h (mäßig) und 7,6 mm/h (stark)
	for th in [[0.456, "mäßig"], [0.796, "stark"]]:
		var y: float = base - ch * sqrt(float(th[0]))
		var x := 0.0
		while x < w:
			draw_line(Vector2(x, y), Vector2(minf(x + 4.0, w), y), Color(1, 1, 1, 0.14), 1.0)
			x += 9.0
		draw_string(font, Vector2(w - 34.0, y - 2.0), str(th[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.38))
	var bins: Array = report.get("bins", [])
	if bins.is_empty():
		return
	var n := bins.size()
	var bw := w / float(n)
	for k in n:
		var b: Dictionary = bins[k]
		var i: float = float(b["i"])
		var conf: float = float(b["conf"])
		var x0 := bw * float(k)
		if i > 0.03:
			var bh := ch * sqrt(clampf(i, 0.0, 1.0))
			var col := Color(0.24, 0.55, 1.0, 0.35 + 0.6 * conf)
			draw_rect(Rect2(x0 + 1.5, base - bh, bw - 3.0, bh), col)
			draw_rect(Rect2(x0 + 1.5, base - bh, bw - 3.0, 2.5), Color(0.7, 0.88, 1.0, 0.35 + 0.6 * conf))
		else:
			draw_rect(Rect2(x0 + bw * 0.5 - 1.5, base - 3.0, 3.0, 3.0), Color(1, 1, 1, 0.20))
		if k % maxi(1, n / 5) == 0:
			var lt := "R%d" % int(b["lap0"])
			draw_string(font, Vector2(x0 + 2.0, h - 3.0), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.55))
			draw_line(Vector2(x0, base), Vector2(x0, base + 4.0), Color(1, 1, 1, 0.3), 1.0)
	draw_line(Vector2(0, base), Vector2(w, base), Color(1, 1, 1, 0.3), 1.0)

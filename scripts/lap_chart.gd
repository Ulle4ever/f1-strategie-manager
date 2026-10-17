extends Control
## Diagramme für die Strategie.
## Modus "laps": vorhergesagte Rundenzeit über die Renndistanz als gestapelte Flächen (Basiszeit, Tankgewicht, Reifenabbau),
## Boxenstopps als Linien, Reifenmischung als Farbband unten.
## Modus "delta": Rennzeit-Differenz mehrerer Pläne zum ersten Plan (Sekunden, unten = schneller).

const U = preload("res://scripts/ui.gd")
const RaceSim = preload("res://scripts/race_sim.gd")

var mode := "laps"
var pred := {}
var laps := 50
var series: Array = []      # delta: [{"name", "color", "cum": Array, "pit": Array}]


func _init() -> void:
	custom_minimum_size = Vector2(0, 130)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_pred(p: Dictionary, n: int) -> void:
	mode = "laps"
	pred = p
	laps = n
	queue_redraw()


func set_series(s: Array, n: int) -> void:
	mode = "delta"
	series = s
	laps = n
	queue_redraw()


static func fmt(t: float) -> String:
	var m := int(t / 60.0)
	return "%d:%04.1f" % [m, t - m * 60.0]


func _draw() -> void:
	var left := 46.0
	var right := 6.0
	var top := 8.0
	var bottom := 22.0
	var w := size.x - left - right
	var h := size.y - top - bottom
	if w < 20.0 or h < 20.0 or laps < 2:
		return
	var f := U.font(false)
	draw_rect(Rect2(left, top, w, h), U.tint(0.035))
	if mode == "laps":
		_draw_laps(left, top, w, h, f)
	else:
		_draw_delta(left, top, w, h, f)
	# x-Achse
	var step := 10 if laps >= 40 else 5
	var l := 0
	while l <= laps:
		var x := left + w * float(l) / float(laps)
		draw_line(Vector2(x, top + h), Vector2(x, top + h + 3.0), U.tint(0.4), 1.0)
		if l > 0 and l % step == 0 and l < laps - 2:
			draw_string(f, Vector2(x - 6.0, top + h + 15.0), str(l), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, U.MUTED)
		l += step


func _draw_laps(left: float, top: float, w: float, h: float, f: Font) -> void:
	var times: Array = pred.get("times", [])
	if times.is_empty():
		return
	var fuel_s: Array = pred["fuel_s"]
	var tyre_s: Array = pred["tyre_s"]
	var base: float = float(pred["base"])
	var ymax := 0.0
	for i in times.size():
		ymax = maxf(ymax, float(times[i]))
	var ymin := base - 0.15
	ymax += 0.25
	var n := times.size()
	var fx := func(i: int) -> float: return left + w * (float(i) + 0.5) / float(n)
	var fy := func(v: float) -> float: return top + h * (1.0 - (v - ymin) / (ymax - ymin))
	# Gitter und Beschriftung
	for k in 4:
		var v: float = ymin + (ymax - ymin) * float(k) / 3.0
		var y: float = fy.call(v)
		draw_line(Vector2(left, y), Vector2(left + w, y), U.tint(0.08), 1.0)
		draw_string(f, Vector2(0, y + 4.0), fmt(v), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, U.MUTED)
	# gestapelte Flächen: Tankgewicht, darüber Reifenabbau
	var p_fuel := PackedVector2Array()
	var p_tyre := PackedVector2Array()
	for i in n:
		p_fuel.append(Vector2(fx.call(i), fy.call(base + float(fuel_s[i]))))
		p_tyre.append(Vector2(fx.call(i), fy.call(base + float(fuel_s[i]) + float(tyre_s[i]))))
	var base_y: float = fy.call(base)
	var fuel_poly := PackedVector2Array([Vector2(fx.call(0), base_y)])
	fuel_poly.append_array(p_fuel)
	fuel_poly.append(Vector2(fx.call(n - 1), base_y))
	if Geometry2D.triangulate_polygon(fuel_poly).size() > 0:
		draw_colored_polygon(fuel_poly, Color(0.35, 0.55, 0.9, 0.28))
	for i in range(n - 1):
		var q := PackedVector2Array([p_fuel[i], p_tyre[i], p_tyre[i + 1], p_fuel[i + 1]])
		if Geometry2D.triangulate_polygon(q).size() > 0:
			var cd: Dictionary = RaceSim.COMPOUNDS[int(pred["comp"][i])]
			draw_colored_polygon(q, Color(cd["ink"], 0.30))
	draw_line(Vector2(left, base_y), Vector2(left + w, base_y), U.tint(0.25), 1.0)
	# Rundenzeit-Linie je Stint in Mischungsfarbe
	for i in range(n - 1):
		var cd2: Dictionary = RaceSim.COMPOUNDS[int(pred["comp"][i])]
		if int(pred["comp"][i]) == int(pred["comp"][i + 1]) or true:
			draw_line(p_tyre[i], p_tyre[i + 1], cd2["ink"], 2.2, true)
	# Stopps und Mischungsband
	for pl in pred.get("pit", []):
		var x: float = left + w * float(int(pl)) / float(laps)
		draw_line(Vector2(x, top), Vector2(x, top + h), U.TEXT, 1.4)
		draw_string(f, Vector2(x + 3.0, top + 10.0), "R%d" % int(pl), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, U.TEXT)
	for i in n:
		var cd3: Dictionary = RaceSim.COMPOUNDS[int(pred["comp"][i])]
		draw_rect(Rect2(left + w * float(i) / float(laps), top + h + 5.0, w / float(laps) + 0.5, 4.0), cd3["ink"] if int(pred["comp"][i]) != 2 else Color(0.62, 0.66, 0.74))
	draw_string(f, Vector2(left + 6.0, top + h - 6.0), "Basis", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, U.MUTED)


func _draw_delta(left: float, top: float, w: float, h: float, f: Font) -> void:
	if series.is_empty():
		return
	var ref: Array = series[0]["cum"]
	var lo := 0.0
	var hi := 0.0
	for s in series:
		var cum: Array = s["cum"]
		for i in mini(cum.size(), ref.size()):
			var d: float = float(cum[i]) - float(ref[i])
			lo = minf(lo, d)
			hi = maxf(hi, d)
	var span := maxf(maxf(absf(lo), absf(hi)), 3.0) * 1.15
	var fx := func(i: int) -> float: return left + w * float(i + 1) / float(laps)
	var fy := func(v: float) -> float: return top + h * (0.5 - v / (2.0 * span))
	for k in 5:
		var v: float = -span + span * 2.0 * float(k) / 4.0
		var y: float = fy.call(v)
		draw_line(Vector2(left, y), Vector2(left + w, y), U.tint(0.14) if k == 2 else U.tint(0.06), 1.0)
		draw_string(f, Vector2(0, y + 4.0), "%+.0f s" % v, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, U.MUTED)
	for s in series:
		var cum2: Array = s["cum"]
		var pts := PackedVector2Array()
		for i in mini(cum2.size(), ref.size()):
			pts.append(Vector2(fx.call(i), fy.call(float(cum2[i]) - float(ref[i]))))
		if pts.size() > 1:
			draw_polyline(pts, s["color"], 2.4, true)
		for pl in s.get("pit", []):
			var i2 := clampi(int(pl) - 1, 0, pts.size() - 1)
			if pts.size() > 0:
				draw_circle(pts[i2], 3.2, s["color"])
				draw_arc(pts[i2], 3.2, 0.0, TAU, 12, Color.WHITE, 1.2)

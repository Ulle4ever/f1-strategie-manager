extends Control
## Stint-Zeitleiste: das Rennen als Balken, je Reifensatz ein farbiger Abschnitt, Boxenstopps als Marken.
## Rote Schraffur = der Stint ist länger als der Reifen hält. Optional Marker für die aktuelle Runde.

const U = preload("res://scripts/ui.gd")
const RaceSim = preload("res://scripts/race_sim.gd")

signal stop_clicked(lap: int)

var laps := 50
var interactive := false
var rain_bins: Array = []       # [{"lap0", "lap1", "i"}]  erwarteter Regen
var sc_marks: Array = []        # [{"lap", "end", "kind"}]
var _stop_xs: Array = []        # [{"x", "lap"}] für Antippen
var segments: Array = []      # [{"a": Start (Runde, 0-basiert), "b": Ende, "comp": Mischung, "life": Haltbarkeit in Runden}]
var cur_lap := 0              # 0 = kein Marker
var win_open := 0               # empfohlenes Stopp-Fenster (Stopp am Ende dieser Runden), 0 = keins
var win_ideal := 0
var win_close := 0
var show_axis := true


func _init() -> void:
	custom_minimum_size = Vector2(0, 54)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Aus Startmischung und Stoppplan Abschnitte bauen. life_fn(comp) -> Haltbarkeit in Runden.
func set_plan(p_laps: int, start_comp: int, plan: Array, life_fn: Callable) -> void:
	laps = maxi(p_laps, 1)
	segments = []
	var sorted: Array = plan.duplicate()
	sorted.sort_custom(func(a, b): return int(a["lap"]) < int(b["lap"]))
	var a := 0
	var comp := start_comp
	for s in sorted:
		var b := clampi(int(s["lap"]), a, laps)
		segments.append({"a": a, "b": b, "comp": comp, "life": float(life_fn.call(comp))})
		a = b
		comp = int(s["comp"])
	segments.append({"a": a, "b": laps, "comp": comp, "life": float(life_fn.call(comp))})
	queue_redraw()


## Zusatzstreifen unter der Zeitleiste (Regenprognose, Safety Car).
func set_extras(rain: Array, sc: Array) -> void:
	var has := not rain.is_empty() or not sc.is_empty()
	var key := str(rain) + str(sc)
	if key == str(rain_bins) + str(sc_marks):
		return
	rain_bins = rain
	sc_marks = sc
	custom_minimum_size.y = 68.0 if has else 54.0
	queue_redraw()


func set_window(a: int, ideal: int, b: int) -> void:
	if a == win_open and b == win_close and ideal == win_ideal:
		return
	win_open = a
	win_ideal = ideal
	win_close = b
	queue_redraw()


func make_interactive() -> void:
	interactive = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and not U.touch_scrolled:
		for s in _stop_xs:
			if absf(mb.position.x - float(s["x"])) <= 16.0:
				stop_clicked.emit(int(s["lap"]))
				accept_event()
				return


func set_cur_lap(l: int) -> void:
	if l != cur_lap:
		cur_lap = l
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var top := 16.0
	var bh := maxf(size.y - top - (16.0 if show_axis else 4.0), 16.0)
	var font := U.font(true)
	var fs := 13 if U.is_mobile() else 14
	draw_rect(Rect2(0, top, w, bh), U.tint(0.07))
	_stop_xs = []
	for s in segments:
		var x0: float = w * float(s["a"]) / float(laps)
		var x1: float = w * float(s["b"]) / float(laps)
		if x1 - x0 < 1.0:
			continue
		var cd: Dictionary = RaceSim.COMPOUNDS[int(s["comp"])]
		var col: Color = cd["color"]
		var ink: Color = cd["ink"]
		var r := Rect2(x0 + 1.0, top, x1 - x0 - 2.0, bh)
		var fillc := U.PANEL2.lerp(col, 0.32)
		draw_rect(r, fillc)
		draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 3.0), col)
		var len_laps: float = float(s["b"] - s["a"])
		var life: float = float(s["life"])
		if len_laps > life * 1.02 and life > 0.0:
			var ox: float = x0 + w * life / float(laps)
			var hx: float = x1 - 1.0
			draw_rect(Rect2(ox, top + 3.0, hx - ox, bh - 3.0), Color(U.BAD, 0.42))
			var xx := ox
			while xx < hx:
				draw_line(Vector2(xx, top + bh), Vector2(minf(xx + bh * 0.6, hx), top + 3.0), Color(U.BAD, 0.85), 1.4)
				xx += 7.0
		var txt := "%s  %d" % [cd["short"], int(len_laps)]
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if tw < r.size.x - 4.0:
			draw_string(font, Vector2(r.position.x + (r.size.x - tw) * 0.5, top + bh * 0.5 + fs * 0.4 + 2.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
		# Stopp-Marke am Ende
		if int(s["b"]) < laps:
			var mx: float = x1
			_stop_xs.append({"x": mx, "lap": int(s["b"])})
			draw_line(Vector2(mx, top - 2.0), Vector2(mx, top + bh), U.TEXT, 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(mx - 4.0, 2.0), Vector2(mx + 4.0, 2.0), Vector2(mx, 10.0)]), U.TEXT)
			var lt := "R%d" % int(s["b"])
			var lw := font.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(font, Vector2(clampf(mx - lw * 0.5, 0.0, w - lw), 12.0), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, U.TEXT)
	if win_close > 0 and win_close > win_open:
		var wx0: float = w * float(win_open) / float(laps)
		var wx1: float = w * minf(float(win_close), float(laps)) / float(laps)
		draw_rect(Rect2(wx0, top, wx1 - wx0, bh), Color(U.GOOD, 0.20))
		draw_line(Vector2(wx0, top), Vector2(wx0, top + bh), U.GOOD, 2.0)
		draw_line(Vector2(wx1, top), Vector2(wx1, top + bh), U.GOOD, 2.0)
		var ix: float = w * float(win_ideal) / float(laps)
		draw_colored_polygon(PackedVector2Array([Vector2(ix - 5.0, top + bh * 0.5), Vector2(ix, top + bh * 0.5 - 5.0), Vector2(ix + 5.0, top + bh * 0.5), Vector2(ix, top + bh * 0.5 + 5.0)]), U.GOOD)
	if show_axis:
		var step := 10 if laps >= 40 else 5
		var l := 0
		while l <= laps:
			var tx: float = w * float(l) / float(laps)
			draw_line(Vector2(tx, top + bh), Vector2(tx, top + bh + 4.0), U.tint(0.4), 1.0)
			if l % step == 0 and l > 0 and l < laps - 2:
				draw_string(U.font(false), Vector2(tx - 6.0, top + bh + 15.0), str(l), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, U.MUTED)
			l += step
	# Zusatzstreifen: erwarteter Regen (blau) und Safety-Car-Phasen (gelb)
	if not rain_bins.is_empty() or not sc_marks.is_empty():
		var ey := top + bh + 20.0
		draw_rect(Rect2(0, ey, w, 8.0), U.tint(0.05))
		for rb in rain_bins:
			var ri: float = float(rb["i"])
			if ri > 0.05:
				var rx0: float = w * float(int(rb["lap0"]) - 1) / float(laps)
				var rx1: float = w * float(int(rb["lap1"])) / float(laps)
				draw_rect(Rect2(rx0, ey, maxf(rx1 - rx0, 2.0), 8.0), Color(0.20, 0.45, 0.92, 0.25 + 0.6 * sqrt(clampf(ri, 0.0, 1.0))))
		for sm in sc_marks:
			var sx0: float = w * float(int(sm["lap"]) - 1) / float(laps)
			var sx1: float = w * float(int(sm["end"])) / float(laps)
			draw_rect(Rect2(sx0, ey - 2.0, maxf(sx1 - sx0, 3.0), 12.0), Color(U.WARN, 0.9))
			draw_string(U.font(true), Vector2(sx0 + 1.0, ey + 20.0), "SC" if int(sm["kind"]) == 2 else "VSC", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, U.WARN)
	if cur_lap > 0:
		var cx: float = w * clampf(float(cur_lap) / float(laps), 0.0, 1.0)
		draw_line(Vector2(cx, top - 3.0), Vector2(cx, top + bh + 3.0), U.WARN, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 4.0, top + bh + 7.0), Vector2(cx + 4.0, top + bh + 7.0), Vector2(cx, top + bh + 2.0)]), U.ACCENT)

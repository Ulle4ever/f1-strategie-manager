extends Control
## Stint-Zeitleiste: das Rennen als Balken, je Reifensatz ein farbiger Abschnitt, Boxenstopps als Marken.
## Rote Schraffur = der Stint ist länger als der Reifen hält. Optional Marker für die aktuelle Runde.

const U = preload("res://scripts/ui.gd")
const RaceSim = preload("res://scripts/race_sim.gd")

var laps := 50
var segments: Array = []      # [{"a": Start (Runde, 0-basiert), "b": Ende, "comp": Mischung, "life": Haltbarkeit in Runden}]
var cur_lap := 0              # 0 = kein Marker
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
	for s in segments:
		var x0: float = w * float(s["a"]) / float(laps)
		var x1: float = w * float(s["b"]) / float(laps)
		if x1 - x0 < 1.0:
			continue
		var cd: Dictionary = RaceSim.COMPOUNDS[int(s["comp"])]
		var col: Color = cd["color"]
		var ink: Color = cd["ink"]
		var r := Rect2(x0 + 1.0, top, x1 - x0 - 2.0, bh)
		var fillc := ink.lerp(Color.WHITE, 0.15) if int(s["comp"]) != 2 else Color(0.62, 0.66, 0.74)
		draw_rect(r, fillc)
		draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 3.0), col if int(s["comp"]) != 2 else Color(0.85, 0.88, 0.93))
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
			draw_string(font, Vector2(r.position.x + (r.size.x - tw) * 0.5, top + bh * 0.5 + fs * 0.4 + 2.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		# Stopp-Marke am Ende
		if int(s["b"]) < laps:
			var mx: float = x1
			draw_line(Vector2(mx, top - 2.0), Vector2(mx, top + bh), U.TEXT, 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(mx - 4.0, 2.0), Vector2(mx + 4.0, 2.0), Vector2(mx, 10.0)]), U.TEXT)
			var lt := "R%d" % int(s["b"])
			var lw := font.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(font, Vector2(clampf(mx - lw * 0.5, 0.0, w - lw), 12.0), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, U.TEXT)
	if show_axis:
		var step := 10 if laps >= 40 else 5
		var l := 0
		while l <= laps:
			var tx: float = w * float(l) / float(laps)
			draw_line(Vector2(tx, top + bh), Vector2(tx, top + bh + 4.0), U.tint(0.4), 1.0)
			if l % step == 0 and l > 0 and l < laps - 2:
				draw_string(U.font(false), Vector2(tx - 6.0, top + bh + 15.0), str(l), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, U.MUTED)
			l += step
	if cur_lap > 0:
		var cx: float = w * clampf(float(cur_lap) / float(laps), 0.0, 1.0)
		draw_line(Vector2(cx, top - 3.0), Vector2(cx, top + bh + 3.0), U.WARN, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 4.0, top + bh + 7.0), Vector2(cx + 4.0, top + bh + 7.0), Vector2(cx, top + bh + 2.0)]), U.ACCENT)

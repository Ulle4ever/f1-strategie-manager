extends Control
## Nationalflagge eines Rennlandes, im Code gezeichnet (vereinfacht, Seitenverhältnis 3:2, keine Bilddateien).
## country = Ländername wie in den Strecken- und Saisondaten ("Italy", "UK", "USA", "Saudi Arabia" ...).
## Mit Effekten weht die Flagge: alle Flaggen werden einmal in eine Atlas-Textur gezeichnet, jede Flagge dann in
## schmalen Streifen mit Wellenversatz und Schattierung (günstig auch bei vielen Flaggen).

const U = preload("res://scripts/ui.gd")
const COUNTRIES := ["Australia", "USA", "Bahrain", "Azerbaijan", "India", "Spain", "Japan", "Germany", "Hungary", "Italy",
	"Brazil", "Turkey", "Saudi Arabia", "Qatar", "France", "Singapore", "Monaco", "Portugal", "Austria", "Mexico", "Malaysia",
	"China", "UK", "Russia", "Belgium", "Canada", "UAE", "Korea", "Netherlands"]
const CELL := Vector2(120, 80)
const COLS := 8

var country := ""
var _t := 0.0
var _acc := 0.0

static var _atlas: SubViewport = null
static var _atlas_frame := 0


static func make(p_country: String, h := 16.0) -> Control:
	var f = load("res://scripts/flag.gd").new()
	f.country = p_country
	f.custom_minimum_size = Vector2(round(h * 1.5), h)
	f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.clip_contents = true
	return f


static func known(p_country: String) -> bool:
	return p_country in COUNTRIES


## Atlas aller Flaggen (einmal gerendert, bleibt im Baum).
static func _ensure_atlas() -> void:
	if _atlas != null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_atlas = SubViewport.new()
	_atlas.size = Vector2i(int(CELL.x) * COLS, int(CELL.y) * int(ceil(float(COUNTRIES.size()) / float(COLS))))
	_atlas.transparent_bg = true
	_atlas.disable_3d = true
	_atlas.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := Control.new()
	painter.size = Vector2(_atlas.size)
	painter.draw.connect(func():
		for i in COUNTRIES.size():
			draw_flag(painter, _slot(i), COUNTRIES[i]))
	_atlas.add_child(painter)
	tree.root.add_child.call_deferred(_atlas)
	_atlas_frame = Engine.get_process_frames() + 4


static func _slot(i: int) -> Rect2:
	return Rect2(Vector2(float(i % COLS) * CELL.x + 1.0, float(i / COLS) * CELL.y + 1.0), CELL - Vector2(2, 2))


static func _atlas_ready() -> bool:
	return _atlas != null and _atlas.is_inside_tree() and Engine.get_process_frames() > _atlas_frame


func _ready() -> void:
	if U.fx_on():
		_ensure_atlas()
		_t = randf() * 3.0


func _process(delta: float) -> void:
	if not U.fx_on() or not is_visible_in_tree():
		return
	_t += delta
	_acc += delta
	if _acc >= 1.0 / 24.0:
		_acc = 0.0
		queue_redraw()


func _draw() -> void:
	var idx := COUNTRIES.find(country)
	if not U.fx_on() or idx < 0 or not _atlas_ready():
		draw_flag(self, Rect2(Vector2.ZERO, size), country)
		return
	# Wehen: links am Mast ruhig, nach rechts zunehmende Welle; Wellenkämme etwas heller, Täler dunkler
	var tex := _atlas.get_texture()
	var src := _slot(idx)
	var n := clampi(int(size.x / 3.0), 6, 22)
	var amp := size.y * 0.07
	for i in n:
		var f0 := float(i) / float(n)
		var f1 := float(i + 1) / float(n)
		var ph := _t * 4.2 - f0 * 6.0
		var k := 0.25 + 0.75 * f0
		var dy := sin(ph) * amp * k
		var shade := 1.0 + 0.13 * cos(ph) * k
		var sr := Rect2(src.position.x + src.size.x * f0, src.position.y, src.size.x * (f1 - f0), src.size.y)
		var dr := Rect2(size.x * f0, amp + dy, size.x * (f1 - f0) + 0.7, size.y - amp * 2.0)
		draw_texture_rect_region(tex, dr, sr, Color(shade, shade, shade))


static func _hbands(ci: CanvasItem, r: Rect2, cols: Array, weights := []) -> void:
	var tot := 0.0
	for i in cols.size():
		tot += float(weights[i]) if not weights.is_empty() else 1.0
	var y := r.position.y
	for i in cols.size():
		var hh: float = r.size.y * (float(weights[i]) if not weights.is_empty() else 1.0) / tot
		ci.draw_rect(Rect2(r.position.x, y, r.size.x, hh + 0.5), Color(cols[i]))
		y += hh


static func _vbands(ci: CanvasItem, r: Rect2, cols: Array, weights := []) -> void:
	var tot := 0.0
	for i in cols.size():
		tot += float(weights[i]) if not weights.is_empty() else 1.0
	var x := r.position.x
	for i in cols.size():
		var ww: float = r.size.x * (float(weights[i]) if not weights.is_empty() else 1.0) / tot
		ci.draw_rect(Rect2(x, r.position.y, ww + 0.5, r.size.y), Color(cols[i]))
		x += ww


static func _star(ci: CanvasItem, c: Vector2, rad: float, col: Color, points := 5, rot := -PI / 2.0) -> void:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := rot + PI * float(i) / float(points)
		var rr := rad if i % 2 == 0 else rad * 0.42
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, col)


## Halbmond: weißer Kreis, vom Hintergrund versetzt überdeckt.
static func _crescent(ci: CanvasItem, c: Vector2, rad: float, col: Color, bg: Color, dx := 0.28) -> void:
	ci.draw_circle(c, rad, col)
	ci.draw_circle(c + Vector2(rad * dx, 0), rad * 0.82, bg)


## Gezackte Trennlinie (Bahrain, Katar): links weiß, rechts Farbe.
static func _serrated(ci: CanvasItem, r: Rect2, frac: float, teeth: int, col: Color) -> void:
	var x0 := r.position.x + r.size.x * frac
	var d := r.size.x * 0.08
	var pts := PackedVector2Array([Vector2(r.end.x, r.position.y), Vector2(x0, r.position.y)])
	for i in teeth:
		var yy := r.position.y + r.size.y * (float(i) + 0.5) / float(teeth)
		pts.append(Vector2(x0 + d, yy))
		pts.append(Vector2(x0, r.position.y + r.size.y * float(i + 1) / float(teeth)))
	pts.append(Vector2(r.end.x, r.end.y))
	ci.draw_rect(r, Color.WHITE)
	ci.draw_colored_polygon(pts, col)


static func _union_jack(ci: CanvasItem, r: Rect2) -> void:
	var blue := Color("012169")
	var red := Color("c8102e")
	ci.draw_rect(r, blue)
	var w := r.size.y
	ci.draw_line(r.position, r.end, Color.WHITE, w * 0.2)
	ci.draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), Color.WHITE, w * 0.2)
	ci.draw_line(r.position, r.end, red, w * 0.07)
	ci.draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), red, w * 0.07)
	var c := r.get_center()
	ci.draw_rect(Rect2(r.position.x, c.y - w * 0.17, r.size.x, w * 0.34), Color.WHITE)
	ci.draw_rect(Rect2(c.x - w * 0.17, r.position.y, w * 0.34, r.size.y), Color.WHITE)
	ci.draw_rect(Rect2(r.position.x, c.y - w * 0.1, r.size.x, w * 0.2), red)
	ci.draw_rect(Rect2(c.x - w * 0.1, r.position.y, w * 0.2, r.size.y), red)


static func draw_flag(ci: CanvasItem, r: Rect2, country: String) -> void:
	var w := r.size.x
	var h := r.size.y
	var p := r.position
	var c := r.get_center()
	match country:
		"Italy":
			_vbands(ci, r, ["009246", "ffffff", "ce2b37"])
		"France":
			_vbands(ci, r, ["0055a4", "ffffff", "ef4135"])
		"Belgium":
			_vbands(ci, r, ["111111", "fdda24", "ef3340"])
		"Mexico":
			_vbands(ci, r, ["006847", "ffffff", "ce1126"])
			ci.draw_circle(c, h * 0.16, Color("8c5a2b"))
			ci.draw_circle(c, h * 0.09, Color("c7a15a"))
		"Germany":
			_hbands(ci, r, ["111111", "dd0000", "ffce00"])
		"Hungary":
			_hbands(ci, r, ["cd2a3e", "ffffff", "436f4d"])
		"Austria":
			_hbands(ci, r, ["ed2939", "ffffff", "ed2939"])
		"Netherlands":
			_hbands(ci, r, ["ae1c28", "ffffff", "21468b"])
		"Russia":
			_hbands(ci, r, ["ffffff", "0039a6", "d52b1e"])
		"Monaco":
			_hbands(ci, r, ["ce1126", "ffffff"])
		"Spain":
			_hbands(ci, r, ["aa151b", "f1bf00", "aa151b"], [1, 2, 1])
			ci.draw_rect(Rect2(p.x + w * 0.22, p.y + h * 0.36, w * 0.1, h * 0.28), Color("aa151b"))
		"Azerbaijan":
			_hbands(ci, r, ["00b5e2", "ef3340", "509e2f"])
			_crescent(ci, c - Vector2(w * 0.03, 0), h * 0.13, Color.WHITE, Color("ef3340"))
			_star(ci, c + Vector2(w * 0.08, 0), h * 0.06, Color.WHITE, 8)
		"India":
			_hbands(ci, r, ["ff9933", "ffffff", "138808"])
			ci.draw_arc(c, h * 0.12, 0.0, TAU, 20, Color("000080"), maxf(1.0, h * 0.03), true)
			ci.draw_circle(c, h * 0.03, Color("000080"))
		"Japan":
			ci.draw_rect(r, Color.WHITE)
			ci.draw_circle(c, h * 0.3, Color("bc002d"))
		"Korea":
			ci.draw_rect(r, Color.WHITE)
			ci.draw_circle(c, h * 0.25, Color("0047a0"))
			var top := PackedVector2Array()
			for k in 17:
				var a := PI + PI * float(k) / 16.0
				top.append(c + Vector2(cos(a), sin(a)) * h * 0.25)
			ci.draw_colored_polygon(top, Color("cd2e3a"))
			ci.draw_circle(c - Vector2(h * 0.125, 0), h * 0.125, Color("cd2e3a"))
			ci.draw_circle(c + Vector2(h * 0.125, 0), h * 0.125, Color("0047a0"))
			for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				var bc: Vector2 = c + Vector2(q.x * w * 0.33, q.y * h * 0.3)
				for k in 3:
					ci.draw_line(bc + Vector2(-w * 0.06, (float(k) - 1.0) * h * 0.05), bc + Vector2(w * 0.06, (float(k) - 1.0) * h * 0.05), Color("111111"), maxf(1.0, h * 0.03))
		"China":
			ci.draw_rect(r, Color("de2910"))
			_star(ci, p + Vector2(w * 0.17, h * 0.27), h * 0.15, Color("ffde00"))
			for s in [Vector2(0.33, 0.1), Vector2(0.4, 0.2), Vector2(0.4, 0.35), Vector2(0.33, 0.45)]:
				_star(ci, p + Vector2(w * s.x, h * s.y), h * 0.05, Color("ffde00"))
		"Turkey":
			ci.draw_rect(r, Color("e30a17"))
			_crescent(ci, p + Vector2(w * 0.38, h * 0.5), h * 0.25, Color.WHITE, Color("e30a17"), 0.25)
			_star(ci, p + Vector2(w * 0.58, h * 0.5), h * 0.1, Color.WHITE, 5, PI)
		"Singapore":
			_hbands(ci, r, ["ef3340", "ffffff"])
			_crescent(ci, p + Vector2(w * 0.17, h * 0.25), h * 0.15, Color.WHITE, Color("ef3340"), 0.35)
			for k in 5:
				var a := -PI / 2.0 + TAU * float(k) / 5.0
				ci.draw_circle(p + Vector2(w * 0.3, h * 0.25) + Vector2(cos(a), sin(a)) * h * 0.08, maxf(0.8, h * 0.025), Color.WHITE)
		"Saudi Arabia":
			ci.draw_rect(r, Color("006c35"))
			ci.draw_line(p + Vector2(w * 0.22, h * 0.36), p + Vector2(w * 0.78, h * 0.36), Color.WHITE, maxf(1.0, h * 0.06))
			ci.draw_line(p + Vector2(w * 0.3, h * 0.47), p + Vector2(w * 0.7, h * 0.47), Color.WHITE, maxf(1.0, h * 0.04))
			ci.draw_line(p + Vector2(w * 0.25, h * 0.68), p + Vector2(w * 0.75, h * 0.68), Color.WHITE, maxf(1.0, h * 0.04))
		"Bahrain":
			_serrated(ci, r, 0.25, 5, Color("ce1126"))
		"Qatar":
			_serrated(ci, r, 0.3, 9, Color("8a1538"))
		"UAE":
			_hbands(ci, r, ["00732f", "ffffff", "111111"])
			ci.draw_rect(Rect2(p, Vector2(w * 0.26, h)), Color("ff0000"))
		"Portugal":
			_vbands(ci, r, ["006600", "ff0000"], [2, 3])
			ci.draw_circle(p + Vector2(w * 0.4, h * 0.5), h * 0.2, Color("ffcc00"))
			ci.draw_rect(Rect2(p + Vector2(w * 0.4 - h * 0.09, h * 0.38), Vector2(h * 0.18, h * 0.22)), Color("ff0000"))
			ci.draw_rect(Rect2(p + Vector2(w * 0.4 - h * 0.05, h * 0.43), Vector2(h * 0.1, h * 0.12)), Color.WHITE)
		"Brazil":
			ci.draw_rect(r, Color("009c3b"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h * 0.4), c + Vector2(w * 0.42, 0), c + Vector2(0, h * 0.4), c + Vector2(-w * 0.42, 0)]), Color("ffdf00"))
			ci.draw_circle(c, h * 0.22, Color("002776"))
			ci.draw_arc(c + Vector2(0, h * 0.3), h * 0.38, -PI * 0.78, -PI * 0.22, 12, Color.WHITE, maxf(1.0, h * 0.05))
		"Canada":
			_vbands(ci, r, ["d52b1e", "ffffff", "d52b1e"], [1, 2, 1])
			var m := PackedVector2Array()
			var leaf := [[0, -0.36], [0.06, -0.22], [0.15, -0.26], [0.12, -0.08], [0.26, -0.16], [0.22, -0.05], [0.28, 0.0], [0.14, 0.1], [0.16, 0.18], [0.02, 0.15], [0.02, 0.32], [-0.02, 0.32], [-0.02, 0.15], [-0.16, 0.18], [-0.14, 0.1], [-0.28, 0.0], [-0.22, -0.05], [-0.26, -0.16], [-0.12, -0.08], [-0.15, -0.26], [-0.06, -0.22]]
			for q in leaf:
				m.append(c + Vector2(float(q[0]) * h, float(q[1]) * h))
			ci.draw_colored_polygon(m, Color("d52b1e"))
		"UK":
			_union_jack(ci, r)
		"USA":
			var st: Array = []
			for k in 13:
				st.append("b22234" if k % 2 == 0 else "ffffff")
			_hbands(ci, r, st)
			var cr := Rect2(p, Vector2(w * 0.42, h * 7.0 / 13.0))
			ci.draw_rect(cr, Color("3c3b6e"))
			for yy in 4:
				for xx in 5:
					ci.draw_circle(cr.position + Vector2((float(xx) + 0.5 + (0.5 if yy % 2 == 1 else 0.0) * 0.5) * cr.size.x / 5.4, (float(yy) + 0.5) * cr.size.y / 4.0), maxf(0.6, h * 0.022), Color.WHITE)
		"Malaysia":
			var ms: Array = []
			for k in 14:
				ms.append("cc0001" if k % 2 == 0 else "ffffff")
			_hbands(ci, r, ms)
			var cm := Rect2(p, Vector2(w * 0.5, h * 8.0 / 14.0))
			ci.draw_rect(cm, Color("010066"))
			_crescent(ci, cm.get_center() - Vector2(cm.size.x * 0.12, 0), cm.size.y * 0.3, Color("ffcc00"), Color("010066"), 0.3)
			_star(ci, cm.get_center() + Vector2(cm.size.x * 0.17, 0), cm.size.y * 0.2, Color("ffcc00"), 14)
		"Australia":
			ci.draw_rect(r, Color("012169"))
			_union_jack(ci, Rect2(p, Vector2(w * 0.5, h * 0.5)))
			_star(ci, p + Vector2(w * 0.25, h * 0.75), h * 0.11, Color.WHITE, 7)
			for s in [Vector2(0.75, 0.17), Vector2(0.62, 0.45), Vector2(0.88, 0.4), Vector2(0.75, 0.82), Vector2(0.81, 0.56)]:
				_star(ci, p + Vector2(w * s.x, h * s.y), h * 0.055, Color.WHITE, 7)
		_:
			ci.draw_rect(r, Color(0.8, 0.83, 0.88))
	ci.draw_rect(r, Color(0, 0, 0, 0.18), false, 1.0)

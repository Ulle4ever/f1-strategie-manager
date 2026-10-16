extends Control
## Streckenkarte von oben im F1-Look: Kamera (Zoom, Verschieben, Folgen, Voreinstellungen), Streckendetails
## (Randsteine, Auslaufzonen, Gummispur, Tribünen, Start/Ziel-Brücke), Boxengasse mit Garagen,
## Autos als Punkte (ausgezoomt) oder Silhouetten (herangezoomt) und Minikarte.
## Rennen: sim gesetzt. Qualifying: dots gesetzt.

const U = preload("res://scripts/ui.gd")

signal car_clicked(car)

const ZOOM_MAX := 16.0
const LOD_ZOOM := 2.2
const KERB_K := 0.0068
const PIT_EXIT := 300.0

var track
var sim = null
var dots: Array = []          # Qualifying: [{"pos": Vector2 (Welt), "color", "code", "player", "selected"}]
var selected = null
var show_drs := true
var show_sectors := true
var interactive := false

# Kamera
var zoom := 1.0
var target_zoom := 1.0
var cam := Vector2.ZERO               # Weltpunkt in der Bildmitte
var follow_mode := "none"             # none | car | leader
var follow_car = null
var _base_scale := 1.0
var _scale := 1.0
var _fit_center := Vector2.ZERO
var _fit_ready := false
var _last_size := Vector2.ZERO
var _press_pos := Vector2.ZERO
var _touches := {}
var _aa := true            # Kantenglättung der Linien (am Handy aus: spart GPU)
var _pinch_dist := 0.0
var _pinching := false
var _dragging := false
var _t := 0.0
var _chip: StyleBoxFlat
var _kerbs: Array = []                # [{"i0", "i1", "side"}] Indexbereiche enger Kurven
var _team_slots := {}                 # team_id -> Boxen-Position (m)
var _team_order: Array = []
var _preset_box: HBoxContainer

const BODY := [Vector2(0.50, 0.0), Vector2(0.38, 0.045), Vector2(0.22, 0.07), Vector2(0.12, 0.12), Vector2(0.02, 0.14), Vector2(-0.12, 0.17),
	Vector2(-0.28, 0.14), Vector2(-0.40, 0.07), Vector2(-0.46, 0.05), Vector2(-0.46, -0.05), Vector2(-0.40, -0.07), Vector2(-0.28, -0.14),
	Vector2(-0.12, -0.17), Vector2(0.02, -0.14), Vector2(0.12, -0.12), Vector2(0.22, -0.07), Vector2(0.38, -0.045)]
const FRONT_WING := [Vector2(0.40, -0.27), Vector2(0.50, -0.27), Vector2(0.50, 0.27), Vector2(0.40, 0.27)]
const REAR_WING := [Vector2(-0.50, -0.2), Vector2(-0.42, -0.2), Vector2(-0.42, 0.2), Vector2(-0.50, 0.2)]


func _init() -> void:
	_aa = not U.is_mobile()
	_chip = StyleBoxFlat.new()
	_chip.bg_color = Color(0.03, 0.04, 0.07, 0.85)
	_chip.set_corner_radius_all(3)
	_chip.content_margin_left = 4
	_chip.content_margin_right = 4
	_chip.content_margin_top = 1
	_chip.content_margin_bottom = 1
	clip_contents = true


func _ready() -> void:
	if not interactive:
		return
	_preset_box = U.hbox(4)
	_preset_box.position = Vector2(8, 8)
	add_child(_preset_box)
	if sim != null:
		for e in [["Gesamt", "all"], ["Auto 1", "car1"], ["Auto 2", "car2"], ["Führender", "leader"]]:
			var b := _tiny_button(e[0])
			b.pressed.connect(set_view.bind(e[1]))
			_preset_box.add_child(b)
	var zin := _tiny_button("+")
	zin.pressed.connect(_zoom_by.bind(1.35))
	_preset_box.add_child(zin)
	var zout := _tiny_button("-")
	zout.pressed.connect(_zoom_by.bind(1.0 / 1.35))
	_preset_box.add_child(zout)


func _tiny_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 28)
	b.add_theme_font_size_override("font_size", 13)
	b.focus_mode = Control.FOCUS_NONE
	return b


func set_track(t) -> void:
	track = t
	_fit_ready = false
	_last_size = Vector2.ZERO
	_build_kerbs()
	queue_redraw()


# ------------------------------------------------------------------ Kamera

func _ensure_layout() -> void:
	if track == null:
		return
	var m := 44.0
	var b: Rect2 = track.bounds
	var avail := size - Vector2(m * 2.0, m * 2.0)
	if avail.x < 10.0 or avail.y < 10.0:
		return
	_base_scale = minf(avail.x / maxf(b.size.x, 1.0), avail.y / maxf(b.size.y, 1.0))
	_fit_center = b.position + b.size * 0.5
	if not _fit_ready:
		_fit_ready = true
		cam = _fit_center
		zoom = 1.0
		target_zoom = 1.0
	_last_size = size
	_scale = _base_scale * zoom


## Bildmitte der Kamera: beim Heranzoomen etwas nach oben, damit TV-Grafiken unten nichts verdecken.
func _view_center() -> Vector2:
	var f := clampf((zoom - 1.0) / 1.5, 0.0, 1.0) if interactive else 0.0
	return Vector2(size.x * 0.5, size.y * (0.5 - 0.09 * f))


func to_screen(world: Vector2) -> Vector2:
	return (world - cam) * _scale + _view_center()


func to_world(scr: Vector2) -> Vector2:
	return (scr - _view_center()) / _scale + cam


## Kamera-Voreinstellung: all, car1, car2, leader
func set_view(mode: String) -> void:
	if sim == null:
		return
	match mode:
		"all":
			follow_mode = "none"
			follow_car = null
			target_zoom = 1.0
			_pan_to_fit = true
		"car1", "car2":
			var players: Array = []
			for c in sim.cars:
				if c.is_player:
					players.append(c)
			var idx := 0 if mode == "car1" else 1
			if idx < players.size():
				follow_mode = "car"
				follow_car = players[idx]
				target_zoom = maxf(target_zoom, 5.0)
				_pan_to_fit = false
		"leader":
			follow_mode = "leader"
			follow_car = null
			target_zoom = maxf(target_zoom, 5.0)
			_pan_to_fit = false


var _pan_to_fit := false


func follow(c) -> void:
	follow_mode = "car"
	follow_car = c
	target_zoom = maxf(target_zoom, 5.0)
	_pan_to_fit = false


func _zoom_by(f: float) -> void:
	target_zoom = clampf(target_zoom * f, 1.0, ZOOM_MAX)
	if target_zoom <= 1.001 and follow_mode == "none":
		_pan_to_fit = true


func _car_world(c) -> Vector2:
	return track.point_at(c.dist)


func _gui_input(event: InputEvent) -> void:
	if not interactive or track == null:
		return
	# Touch: Zwei Finger = Pinch-Zoom (ein Finger wird als Maus behandelt: schieben und antippen)
	var st := event as InputEventScreenTouch
	if st != null:
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		_pinch_dist = 0.0
		if _touches.size() >= 2:
			_pinching = true
		elif _touches.is_empty():
			_pinching = false
		return
	var sd := event as InputEventScreenDrag
	if sd != null:
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			var ks := _touches.keys()
			var p0: Vector2 = _touches[ks[0]]
			var p1: Vector2 = _touches[ks[1]]
			var dd := p0.distance_to(p1)
			if _pinch_dist > 10.0 and dd > 10.0:
				_wheel_zoom(dd / _pinch_dist, (p0 + p1) * 0.5)
			_pinch_dist = dd
		return
	if _pinching:
		return
	var mb := event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_wheel_zoom(1.2, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_wheel_zoom(1.0 / 1.2, mb.position)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press_pos = mb.position
				_dragging = false
			else:
				if not _dragging:
					_click(mb.position)
				_dragging = false
		return
	var mm := event as InputEventMouseMotion
	if mm != null and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if not _dragging and mm.position.distance_to(_press_pos) > 5.0:
			_dragging = true
			follow_mode = "none"
			follow_car = null
			_pan_to_fit = false
		if _dragging:
			cam -= mm.relative / _scale


func _wheel_zoom(f: float, at: Vector2) -> void:
	var before := to_world(at)
	target_zoom = clampf(target_zoom * f, 1.0, ZOOM_MAX)
	zoom = target_zoom
	_scale = _base_scale * zoom
	if follow_mode == "none":
		cam = before - (at - _view_center()) / _scale
		if target_zoom <= 1.001:
			_pan_to_fit = true


func _click(pos: Vector2) -> void:
	if sim == null:
		return
	var best = null
	var bd := 16.0
	for c in sim.cars:
		if c.state == 3:
			continue
		var p: Vector2 = _screen_pos_of(c)
		var d := p.distance_to(pos)
		if d < bd:
			bd = d
			best = c
	if best != null:
		car_clicked.emit(best)


func _process(delta: float) -> void:
	_t += delta
	if track == null:
		return
	if size != _last_size or not _fit_ready:
		_ensure_layout()
	if interactive:
		# Folgen
		var tgt = null
		if follow_mode == "car" and follow_car != null:
			tgt = follow_car
		elif follow_mode == "leader" and sim != null:
			var rk: Array = sim.ranking()
			if rk.size() > 0:
				tgt = rk[0]
		if tgt != null and tgt.state != 3:
			var wp: Vector2 = _screen_world_of(tgt)
			cam = cam.lerp(wp, 1.0 - exp(-7.0 * delta))
		elif _pan_to_fit:
			cam = cam.lerp(_fit_center, 1.0 - exp(-7.0 * delta))
		zoom = lerpf(zoom, target_zoom, 1.0 - exp(-8.0 * delta))
		if absf(zoom - target_zoom) < 0.002:
			zoom = target_zoom
		_scale = _base_scale * zoom
		# Karte nicht aus dem Bild schieben
		var b: Rect2 = track.bounds.grow(120.0)
		cam = Vector2(clampf(cam.x, b.position.x, b.end.x), clampf(cam.y, b.position.y, b.end.y))
	if sim != null or not dots.is_empty() or interactive:
		queue_redraw()


## Weltposition eines Autos (Boxengasse berücksichtigt) als Kamera-Ziel.
func _screen_world_of(c) -> Vector2:
	if c.state == 2:
		var pv := _pit_visual(c)
		return to_world(pv["pos"])
	return track.point_at(c.dist)


func _screen_pos_of(c) -> Vector2:
	if c.state == 2:
		return _pit_visual(c)["pos"]
	return to_screen(track.point_at(c.dist))


# ------------------------------------------------------------------ Streckendetails vorbereiten

func _build_kerbs() -> void:
	_kerbs = []
	if track == null:
		return
	var n: int = track.n
	var k := 3
	var i := 0
	var in_run := false
	var start := 0
	for step in n:
		var idx := step
		var hot: bool = track.kappa[idx] > KERB_K
		if hot and not in_run:
			in_run = true
			start = idx
		elif (not hot or idx == n - 1) and in_run:
			in_run = false
			if idx - start >= 3:
				var mid := (start + idx) / 2
				var t1: Vector2 = track.pts[mid] - track.pts[(mid - k + n) % n]
				var t2: Vector2 = track.pts[(mid + k) % n] - track.pts[mid]
				var side := 1.0 if t1.cross(t2) > 0.0 else -1.0
				_kerbs.append({"i0": start, "i1": idx, "side": side})


func _road_width() -> float:
	return clampf(12.0 * _scale * 1.8, 13.0, 70.0)


func _tangent_screen(s: float) -> Vector2:
	var a: Vector2 = to_screen(track.point_at(s - 6.0))
	var b: Vector2 = to_screen(track.point_at(s + 6.0))
	var d := b - a
	if d.length() < 0.001:
		return Vector2.RIGHT
	return d.normalized()


## Boxengassen-Position: s (m) entlang der Strecke, lat 0..1 Seitenversatz.
func _pit_point(s: float, lat: float) -> Vector2:
	var rw := _road_width()
	var base := to_screen(track.point_at(s))
	var t := _tangent_screen(s)
	var nrm := Vector2(-t.y, t.x)
	return base + nrm * (_lane_off(rw) * lat)


func _lane_off(rw: float) -> float:
	return rw * 1.15 + 8.0


func _ease(u: float) -> float:
	var x := clampf(u, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Sichtbare Position und Ausrichtung eines Autos in der Boxengasse.
func _pit_visual(c) -> Dictionary:
	var box_s: float = float(_team_slots.get(c.team_id, 120.0))
	var t_el: float = c.pit_total - c.pit_timer
	var drive := maxf(0.5, (c.pit_total - c.pit_stat) * 0.5)
	var s := 0.0
	var lat := 1.0
	var stopped := false
	if t_el < drive:
		var u: float = t_el / drive
		s = lerpf(0.0, box_s, _ease(u))
		lat = _ease(t_el / 1.4)
	elif t_el < drive + c.pit_stat:
		s = box_s
		stopped = true
	else:
		var u2: float = (t_el - drive - c.pit_stat) / drive
		s = lerpf(box_s, PIT_EXIT, _ease(u2))
		lat = 1.0 - _ease((u2 - 0.55) / 0.45)
	var p := _pit_point(s, lat)
	var ahead := _pit_point(s + 8.0, lat)
	var d := ahead - p
	var ang := d.angle() if d.length() > 0.01 else _tangent_screen(s).angle()
	return {"pos": p, "angle": ang, "stopped": stopped}


func _update_team_slots() -> void:
	if sim == null:
		return
	if not _team_order.is_empty() and _team_order.size() == _count_teams():
		return
	_team_order = []
	for c in sim.cars:
		if not _team_order.has(c.team_id):
			_team_order.append(c.team_id)
	_team_slots = {}
	for i in _team_order.size():
		_team_slots[_team_order[i]] = 50.0 + float(i) * (180.0 / maxf(1.0, float(_team_order.size() - 1)))


func _count_teams() -> int:
	var seen := {}
	for c in sim.cars:
		seen[c.team_id] = true
	return seen.size()


# ------------------------------------------------------------------ Zeichnen

func _label_chip(pos: Vector2, text: String, col: Color) -> void:
	var font := U.font(true)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var r := Rect2(pos + Vector2(10, -20), Vector2(tw + 10, 20))
	draw_style_box(_chip, r)
	draw_rect(Rect2(r.position, Vector2(3, r.size.y)), col)
	draw_string(font, r.position + Vector2(7, 15), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _line_points(from_s: float, to_s: float, step: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var s := from_s
	while s <= to_s:
		pts.append(to_screen(track.point_at(s)))
		s += step
	return pts


func _offset_line(from_s: float, to_s: float, step: float, off: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var s := from_s
	while s <= to_s:
		var t := _tangent_screen(s)
		pts.append(to_screen(track.point_at(s)) + Vector2(-t.y, t.x) * off)
		s += step
	return pts


func _draw() -> void:
	if track == null:
		return
	if size != _last_size or not _fit_ready:
		_ensure_layout()
	_update_team_slots()
	var rw := _road_width()
	var n: int = track.n
	var step := 1 if (zoom > 1.6 or n < 600) else maxi(1, n / 500)
	var line := PackedVector2Array()
	for i in range(0, n, step):
		line.append(to_screen(track.pts[i]))
	line.append(line[0])
	var racing := sim != null
	# Auslaufzonen / Rasen
	draw_polyline(line, Color(0.06, 0.15, 0.10, 0.50), rw + 70.0, _aa)
	draw_polyline(line, Color(0.05, 0.11, 0.09, 0.55), rw + 34.0, _aa)
	# Kiesbetten außen an engen Kurven
	for kb in _kerbs:
		var pl := PackedVector2Array()
		for i in range(kb["i0"], kb["i1"] + 1):
			var tt: Vector2 = to_screen(track.pts[(i + 3) % n]) - to_screen(track.pts[(i - 3 + n) % n])
			if tt.length() < 0.001:
				continue
			tt = tt.normalized()
			pl.append(to_screen(track.pts[i]) - Vector2(-tt.y, tt.x) * float(kb["side"]) * (rw * 0.5 + rw * 0.65))
		if pl.size() > 1:
			draw_polyline(pl, Color(0.55, 0.47, 0.32, 0.42), rw * 0.8, _aa)
	# Tribünen an Start/Ziel und in den engsten Kurven
	_draw_stand(-330.0, 250.0, -1.0, rw)
	for kb in _kerbs.slice(0, 3):
		var mid_s: float = (float(kb["i0"]) + float(kb["i1"])) * 0.5 * track.spacing
		_draw_stand(mid_s - 60.0, mid_s + 60.0, -float(kb["side"]), rw)
	# Boxengasse unter der Strecke
	if racing:
		_draw_pit_lane(rw)
	# Strecke: Schatten, Rand, Asphalt
	draw_polyline(line, Color(0, 0, 0, 0.35), rw + 11.0, _aa)
	draw_polyline(line, Color(0.09, 0.11, 0.16), rw + 4.0, _aa)
	draw_polyline(line, Color(0.48, 0.53, 0.64), rw, _aa)
	draw_polyline(line, Color(0.17, 0.19, 0.25), rw - 3.5, _aa)
	if racing:
		# Gummispur wird mit den Runden dunkler, Nässe glänzt
		var prog := clampf(float(sim.leader_lap()) / maxf(float(sim.laps), 1.0), 0.0, 1.0)
		if sim.started:
			draw_polyline(line, Color(0.05, 0.06, 0.08, 0.10 + 0.40 * prog), rw * 0.34, _aa)
		if sim.wet > 0.08:
			draw_polyline(line, Color(0.35, 0.55, 0.95, 0.18 * sim.wet), rw - 3.5, _aa)
			draw_polyline(line, Color(0.75, 0.88, 1.0, 0.16 * sim.wet), rw * 0.18, _aa)
	# Randsteine innen an engen Kurven
	for kb in _kerbs:
		var seg := PackedVector2Array()
		var idx := 0
		for i in range(kb["i0"], kb["i1"] + 1):
			var tt2: Vector2 = to_screen(track.pts[(i + 3) % n]) - to_screen(track.pts[(i - 3 + n) % n])
			if tt2.length() < 0.001:
				continue
			tt2 = tt2.normalized()
			var p: Vector2 = to_screen(track.pts[i]) + Vector2(-tt2.y, tt2.x) * float(kb["side"]) * (rw * 0.5 - 1.2)
			if idx > 0 and seg.size() > 0:
				var col := Color(0.9, 0.12, 0.10) if (idx / 1) % 2 == 0 else Color(0.95, 0.95, 0.95)
				draw_line(seg[seg.size() - 1], p, col, 3.0)
			seg.append(p)
			idx += 1
	# DRS-Zonen
	if show_drs and racing and sim.rules.get("drs", false):
		for z in track.straights:
			var a: float = z[0]
			var l: float = z[2]
			var sg := _line_points(a, a + l, 24.0)
			if sg.size() > 1:
				draw_polyline(sg, Color(U.GOOD, 0.35), 8.0, _aa)
				draw_polyline(sg, Color(U.GOOD, 0.95), 2.5, _aa)
	# Sektoren
	var font := U.font(true)
	if show_sectors:
		for k in 2:
			var sp := to_screen(track.point_at(track.length * float(k + 1) / 3.0))
			draw_circle(sp, 4.0, Color(1, 1, 1, 0.55))
			draw_string(font, sp + Vector2(8, 5), "S%d" % (k + 2), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.5))
	# Start/Ziel-Brücke
	var p0 := to_screen(track.point_at(0.0))
	var dir := _tangent_screen(0.0)
	var nrm := Vector2(-dir.y, dir.x)
	var half := (rw + 14.0) * 0.5
	for i in 6:
		var cc := Color.WHITE if i % 2 == 0 else Color(0.05, 0.05, 0.05)
		var f0 := -half + (half * 2.0) * float(i) / 6.0
		var f1 := -half + (half * 2.0) * float(i + 1) / 6.0
		draw_line(p0 + nrm * f0, p0 + nrm * f1, cc, 5.0)
	draw_line(p0 - dir * 10.0 - nrm * (half + 2.0), p0 - dir * 10.0 + nrm * (half + 2.0), Color(0.22, 0.25, 0.32), 6.0)
	draw_circle(p0 - dir * 10.0 - nrm * (half + 2.0), 4.0, Color(0.5, 0.55, 0.65))
	draw_circle(p0 - dir * 10.0 + nrm * (half + 2.0), 4.0, Color(0.5, 0.55, 0.65))
	draw_string(font, p0 - nrm * (half + 14.0) - Vector2(14, 0), "START/ZIEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.55))
	# Autos
	if racing:
		_draw_sim_cars(rw, font)
	elif not dots.is_empty():
		_draw_dots(font)
	# Regen
	if racing and sim.rain > 0.04:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.4, 0.9, 0.09 * sim.rain))
		var rn := int(60.0 * sim.rain)
		for i in rn:
			var h := float(i * 7919 % 1000) / 1000.0
			var x := fmod(h * size.x + _t * 160.0 * (0.6 + h), size.x + 80.0) - 40.0
			var y := fmod(float(i * 104729 % 997) / 997.0 * size.y + _t * 520.0, size.y)
			draw_line(Vector2(x, y), Vector2(x - 6, y + 16), Color(0.7, 0.85, 1.0, 0.35), 1.2)
	if interactive and zoom > 1.35:
		_draw_minimap()


func _draw_stand(s0: float, s1: float, side: float, rw: float) -> void:
	var off1 := side * (rw * 0.5 + rw * 0.9 + 22.0)
	var seg := _offset_line(s0, s1, 14.0, off1)
	if seg.size() < 2:
		return
	draw_polyline(seg, Color(0.14, 0.16, 0.22, 0.9), rw * 0.95, _aa)
	var seg2 := _offset_line(s0, s1, 14.0, off1 + side * rw * 0.18)
	draw_polyline(seg2, Color(0.28, 0.31, 0.40, 0.8), rw * 0.18, _aa)
	var seg3 := _offset_line(s0, s1, 14.0, off1 - side * rw * 0.18)
	draw_polyline(seg3, Color(0.22, 0.25, 0.33, 0.8), rw * 0.18, _aa)
	# Zuschauer als bunte Punkte
	if zoom > 1.3:
		var i := 0
		for pt in _offset_line(s0, s1, 14.0, off1):
			var h := float((i * 7919 + int(s0)) % 360) / 360.0
			draw_circle(pt + Vector2(float((i * 37) % 7) - 3.0, float((i * 53) % 7) - 3.0) * 0.6, maxf(1.3, rw * 0.07), Color.from_hsv(h, 0.55, 0.85, 0.75))
			i += 1


func _draw_pit_lane(rw: float) -> void:
	var off := _lane_off(rw)
	var lane := PackedVector2Array()
	var s := -60.0
	while s <= PIT_EXIT + 10.0:
		var lat := _ease((s + 60.0) / 50.0) * _ease((PIT_EXIT + 10.0 - s) / 45.0)
		lane.append(_pit_point(s, lat))
		s += 8.0
	if lane.size() < 2:
		return
	draw_polyline(lane, Color(0, 0, 0, 0.35), rw * 0.7 + 8.0, _aa)
	draw_polyline(lane, Color(0.40, 0.44, 0.54), rw * 0.62, _aa)
	draw_polyline(lane, Color(0.13, 0.15, 0.2), rw * 0.62 - 3.0, _aa)
	# Garagen
	var gl := clampf(10.0 * _scale * 1.8, 3.0, 26.0)
	var gd := clampf(rw * 0.75, 6.0, 40.0)
	for tid in _team_slots.keys():
		var gs: float = float(_team_slots[tid])
		var p := _pit_point(gs, 1.0)
		var t := _tangent_screen(gs)
		var nrm := Vector2(-t.y, t.x)
		var center := p + nrm * (rw * 0.31 + gd * 0.5 + 4.0)
		var col: Color = Color.GRAY
		for c in sim.cars:
			if c.team_id == tid:
				col = c.color
				break
		var poly := PackedVector2Array([center - t * gl * 0.5 - nrm * gd * 0.5, center + t * gl * 0.5 - nrm * gd * 0.5,
			center + t * gl * 0.5 + nrm * gd * 0.5, center - t * gl * 0.5 + nrm * gd * 0.5])
		draw_colored_polygon(poly, Color(0.10, 0.12, 0.17, 0.95))
		var strip := PackedVector2Array([poly[0], poly[1], poly[1] + nrm * gd * 0.22, poly[0] + nrm * gd * 0.22])
		draw_colored_polygon(strip, col)
	if zoom > 1.2:
		draw_string(U.font(true), _pit_point(PIT_EXIT * 0.45, 1.0) - Vector2(8, 12) + Vector2(-_tangent_screen(120.0).y, _tangent_screen(120.0).x) * (rw * 1.8), "BOX", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.5))


func _car_heading(c) -> float:
	var a := to_screen(track.point_at(c.dist - 10.0))
	var b := to_screen(track.point_at(c.dist + 10.0))
	var d := b - a
	return d.angle() if d.length() > 0.01 else 0.0


func _draw_car_shape(pos: Vector2, ang: float, len_px: float, col: Color, tyre: Color, player: bool) -> void:
	if player:
		draw_circle(pos, len_px * 0.62, Color(1, 1, 1, 0.18))
	draw_set_transform(pos, ang, Vector2(len_px, len_px))
	draw_colored_polygon(PackedVector2Array(FRONT_WING), col.darkened(0.45))
	draw_colored_polygon(PackedVector2Array(REAR_WING), col.darkened(0.45))
	var wheel := Color(0.03, 0.03, 0.04)
	for sx in [1.0, -1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(0.24, 0.17 * sx), Vector2(0.38, 0.17 * sx), Vector2(0.38, 0.29 * sx), Vector2(0.24, 0.29 * sx)]), wheel)
		draw_colored_polygon(PackedVector2Array([Vector2(-0.38, 0.17 * sx), Vector2(-0.22, 0.17 * sx), Vector2(-0.22, 0.30 * sx), Vector2(-0.38, 0.30 * sx)]), wheel)
	draw_colored_polygon(PackedVector2Array(BODY), col)
	draw_circle(Vector2(0.02, 0.0), 0.055, Color(0.06, 0.07, 0.10))
	draw_circle(Vector2(-0.2, 0.0), 0.05, tyre)
	if player:
		draw_polyline(PackedVector2Array(BODY + [BODY[0]]), Color.WHITE, 0.03)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_sim_cars(rw: float, font: Font) -> void:
	var ranking: Array = sim.ranking()
	var order: Array = ranking.duplicate()
	order.reverse()
	var shapes := zoom >= LOD_ZOOM
	var len_px := clampf(rw * 1.3, 14.0, 80.0)
	for c in order:
		if c.state == 3:
			if shapes:
				var wp := to_screen(track.point_at(c.dist))
				draw_circle(wp, len_px * 0.22, Color(0.25, 0.25, 0.28))
				draw_line(wp + Vector2(-5, -5), wp + Vector2(5, 5), Color(U.BAD, 0.8), 2.0)
				draw_line(wp + Vector2(-5, 5), wp + Vector2(5, -5), Color(U.BAD, 0.8), 2.0)
			continue
		var pos: Vector2
		var ang := 0.0
		var in_pit: bool = c.state == 2
		var stopped := false
		if in_pit:
			var pv := _pit_visual(c)
			pos = pv["pos"]
			ang = pv["angle"]
			stopped = pv["stopped"]
		else:
			pos = to_screen(track.point_at(c.dist))
			ang = _car_heading(c)
		if pos.x < -40.0 or pos.y < -40.0 or pos.x > size.x + 40.0 or pos.y > size.y + 40.0:
			continue
		var rank: int = ranking.find(c)
		if shapes:
			var cd: Dictionary = sim.COMPOUNDS[c.compound]
			_draw_car_shape(pos, ang, len_px, c.color, cd["color"], c.is_player)
			if stopped:
				var t := Vector2(cos(ang), sin(ang))
				var nn := Vector2(-t.y, t.x)
				var bob := absf(sin(_t * 9.0)) * 2.0
				for k in 4:
					var sx := 1.0 if k % 2 == 0 else -1.0
					var sy := 1.0 if k < 2 else -1.0
					draw_circle(pos + t * len_px * 0.34 * sy + nn * len_px * 0.45 * sx, 2.2 + bob * 0.3, Color(1, 1, 1, 0.9))
			if c.drs and show_drs:
				draw_circle(pos - Vector2(cos(ang), sin(ang)) * len_px * 0.55, 2.4, U.GOOD)
		else:
			var r := 5.5
			if c.is_player:
				r = 8.0
			if c.state == 1 and c.speed > 10.0:
				for k in range(1, 5):
					var tp := to_screen(track.point_at(c.dist - 30.0 * k))
					draw_circle(tp, r * (1.0 - 0.16 * k), Color(c.color, 0.32 - 0.07 * k))
			if c.is_player:
				draw_circle(pos, r + 4.0, Color(1, 1, 1, 0.20))
			draw_circle(pos, r + 1.6, Color.WHITE if c.is_player else Color(0, 0, 0, 0.75))
			draw_circle(pos, r, c.color)
		if c == selected:
			draw_arc(pos, (len_px * 0.7 if shapes else 14.0), 0.0, TAU, 28, U.WARN, 2.2)
		if c.is_player or rank < 3 or (shapes and zoom >= 5.0) or c == selected:
			_label_chip(pos, "P%d %s" % [rank + 1, c.code], c.color)


func _draw_dots(font: Font) -> void:
	for d in dots:
		var pos := to_screen(d["pos"])
		var r := 8.0 if d.get("player", false) else 5.5
		if d.get("player", false):
			draw_circle(pos, r + 4.0, Color(1, 1, 1, 0.2))
		draw_circle(pos, r + 1.6, Color.WHITE if d.get("player", false) else Color(0, 0, 0, 0.75))
		draw_circle(pos, r, d["color"])
		if d.get("selected", false):
			draw_arc(pos, r + 8.0, 0.0, TAU, 28, U.WARN, 2.2)
		if d.get("player", false) or d.get("label", false):
			_label_chip(pos, str(d["code"]), d["color"])


func _draw_minimap() -> void:
	var w := 150.0
	var h := 108.0
	var box := Rect2(size.x - w - 10.0, 10.0, w, h)
	if U.is_mobile():
		w = 112.0
		h = 82.0
		box = Rect2(size.x - w - 8.0, size.y - h - 30.0, w, h)
	draw_rect(box, Color(0.03, 0.04, 0.07, 0.82))
	draw_rect(box, Color(1, 1, 1, 0.18), false, 1.0)
	var b: Rect2 = track.bounds
	var ms := minf((w - 16.0) / maxf(b.size.x, 1.0), (h - 16.0) / maxf(b.size.y, 1.0))
	var org := box.position + Vector2(8, 8) + ((Vector2(w - 16.0, h - 16.0) - b.size * ms) * 0.5) - b.position * ms
	var pl := PackedVector2Array()
	var st := maxi(1, track.n / 160)
	for i in range(0, track.n, st):
		pl.append(track.pts[i] * ms + org)
	pl.append(pl[0])
	draw_polyline(pl, Color(0.6, 0.65, 0.78, 0.9), 2.0, _aa)
	if sim != null:
		for c in sim.cars:
			if c.state == 3:
				continue
			var wp: Vector2 = track.point_at(c.dist)
			draw_circle(wp * ms + org, 3.0 if c.is_player else 1.8, c.color)
	# sichtbarer Ausschnitt
	var tl := to_world(Vector2.ZERO) * ms + org
	var br := to_world(size) * ms + org
	draw_rect(Rect2(tl, br - tl), Color(U.WARN, 0.9), false, 1.5)

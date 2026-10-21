extends Control
## Fahrerfoto (res://photos/<fahrer-id>.jpg, freie Fotos von Wikimedia Commons, siehe photos/CREDITS.txt) als Element
## für Listen und Karten; ohne Foto (z. B. Nachwuchsfahrer der Karriere) eine gezeichnete Silhouette.
## draw_into() zeichnet dasselbe direkt in ein CanvasItem (TV-Grafik, Fahrer-Panel).

static var _cache := {}

var driver_id := ""
var frame := Color(1, 1, 1, 0.0)


static func tex(id: String) -> Texture2D:
	if id == "":
		return null
	if _cache.has(id):
		return _cache[id]
	var t: Texture2D = null
	var p := "res://photos/%s.jpg" % id
	if ResourceLoader.exists(p):
		t = load(p)
	_cache[id] = t
	return t


static func make(id: String, px: float, frame_col := Color(1, 1, 1, 0.0)) -> Control:
	var c = load("res://scripts/driver_photo.gd").new()
	c.driver_id = id
	c.frame = frame_col
	c.custom_minimum_size = Vector2(px, px)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func draw_into(ci: CanvasItem, r: Rect2, id: String, frame_col := Color(1, 1, 1, 0.0)) -> void:
	var t := tex(id)
	if t != null:
		ci.draw_texture_rect(t, r, false)
	else:
		ci.draw_rect(r, Color(0.55, 0.59, 0.66))
		var cx := r.position.x + r.size.x * 0.5
		var head := r.size.x * 0.19
		ci.draw_circle(Vector2(cx, r.position.y + r.size.y * 0.40), head, Color(0.86, 0.88, 0.92))
		var sh := PackedVector2Array()
		for i in 13:
			var a := PI + PI * float(i) / 12.0
			sh.append(Vector2(cx + cos(a) * r.size.x * 0.36, r.end.y + sin(a) * r.size.y * 0.30))
		ci.draw_colored_polygon(sh, Color(0.86, 0.88, 0.92))
	if frame_col.a > 0.0:
		ci.draw_rect(r, frame_col, false, 2.0)


func _draw() -> void:
	draw_into(self, Rect2(Vector2.ZERO, size), driver_id, frame)

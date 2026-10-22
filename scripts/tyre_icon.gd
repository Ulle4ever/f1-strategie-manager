extends Control
## Reifen von der Seite: dunkler Gummi, farbiger Streifen der Mischung, Buchstabe in der Mitte. Dreht sich leicht, wenn spin an ist.

const RaceSim = preload("res://scripts/race_sim.gd")
const U = preload("res://scripts/ui.gd")

var comp := 0
var spin := false
var _a := 0.0


static func make(p_comp: int, px := 30.0) -> Control:
	var t = load("res://scripts/tyre_icon.gd").new()
	t.comp = p_comp
	t.custom_minimum_size = Vector2(px, px)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return t


static var _tex_cache := {}


## Reifen als kleine Textur (für Knopf-Symbole): Gummi, Farbstreifen der Mischung, Felge; kantengeglättet.
static func texture(p_comp: int, px := 26) -> ImageTexture:
	var key := "%d_%d" % [p_comp, px]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var col: Color = RaceSim.COMPOUNDS[p_comp]["color"]
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var c := Vector2(px, px) * 0.5
	var r := float(px) * 0.5 - 0.5
	for y in px:
		for x in px:
			var d := (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(c)
			var a := clampf(r - d + 0.5, 0.0, 1.0)
			if a <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var p := Color(0.09, 0.1, 0.12)
			if absf(d - r * 0.76) < r * 0.1:
				p = col
			elif d < r * 0.48:
				p = Color(0.62, 0.65, 0.7) if d > r * 0.36 else Color(0.25, 0.27, 0.31)
			img.set_pixel(x, y, Color(p, a))
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


func _process(delta: float) -> void:
	if spin and U.fx_on() and is_visible_in_tree():
		_a += delta * 2.5
		queue_redraw()


func _draw() -> void:
	var cd: Dictionary = RaceSim.COMPOUNDS[comp]
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 1.0
	draw_circle(c, r, Color(0.09, 0.1, 0.12))
	draw_arc(c, r * 0.78, 0.0, TAU, 32, cd["color"], maxf(2.0, r * 0.14), true)
	draw_circle(c, r * 0.5, Color(0.18, 0.19, 0.22))
	# Speichen der Felge, drehen beim Auswählen
	for k in 5:
		var a := _a + TAU * float(k) / 5.0
		draw_line(c + Vector2(cos(a), sin(a)) * r * 0.18, c + Vector2(cos(a), sin(a)) * r * 0.46, Color(0.55, 0.58, 0.64), maxf(1.0, r * 0.08))
	var f := U.font(true)
	var fs := int(r * 0.62)
	var s: String = cd["short"]
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, c + Vector2(-w * 0.5, fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

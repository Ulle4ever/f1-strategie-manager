extends Control
## Überschriftsleiste: roter Schrägbalken, fetter Titel in Großbuchstaben, Untertitel.

const U = preload("res://scripts/ui.gd")

var title := ""
var subtitle := ""


func _draw() -> void:
	var h := size.y
	var fb := U.font(true)
	var f := U.font(false)
	var k := 0.68 if U.is_mobile() else 1.0
	var fs_t := int(34.0 * k)
	var fs_s := int(19.0 * k)
	# Schrägbalken
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, 1.0))
	draw_colored_polygon(PackedVector2Array([Vector2(16, 4), Vector2(30, 4), Vector2(18, h - 6), Vector2(4, h - 6)]), U.ACCENT)
	draw_colored_polygon(PackedVector2Array([Vector2(36, 4), Vector2(42, 4), Vector2(30, h - 6), Vector2(24, h - 6)]), Color(U.ACCENT, 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(fb, Vector2(60.0 * k, h * 0.5 + 11.0 * k), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs_t, U.TEXT)
	if subtitle != "":
		var tw := fb.get_string_size(title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs_t).x
		draw_string(f, Vector2(60.0 * k + tw + 16.0, h * 0.5 + 10.0 * k), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_s, U.MUTED)
	draw_line(Vector2(0, h - 1), Vector2(size.x, h - 1), Color(1, 1, 1, 0.07), 1.0)

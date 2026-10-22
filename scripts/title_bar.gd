extends Control
## Überschrift im dunklen Kopfband: Schrägstreifen in der Akzentfarbe, Titel in Renn-Schrift (kursiv), Untertitel.

const U = preload("res://scripts/ui.gd")

var title := ""
var subtitle := ""


func _draw() -> void:
	var h := size.y
	var fd := U.display_font()
	var f := U.font(false)
	var k := 0.7 if U.is_mobile() else 1.0
	var fs_t := int(32.0 * k)
	var fs_s := int(18.0 * k)
	var sk := h * 0.32
	# Schrägstreifen
	var x0 := 2.0
	draw_colored_polygon(PackedVector2Array([Vector2(x0 + sk, 6), Vector2(x0 + sk + 10.0 * k, 6), Vector2(x0 + 10.0 * k, h - 6), Vector2(x0, h - 6)]), U.ACCENT)
	draw_colored_polygon(PackedVector2Array([Vector2(x0 + sk + 15.0 * k, 6), Vector2(x0 + sk + 19.0 * k, 6), Vector2(x0 + 19.0 * k, h - 6), Vector2(x0 + 15.0 * k, h - 6)]), Color(U.ACCENT, 0.55))
	var tx := x0 + sk + 32.0 * k
	var t := title.to_upper()
	var base := h * 0.5 + fs_t * 0.36
	draw_string(fd, Vector2(tx, base), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_t, U.ON_DARK)
	if subtitle != "":
		var tw := fd.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_t).x
		var sx := tx + tw + 14.0 * k
		if sx < size.x - 40.0:
			draw_string(f, Vector2(sx, base - 1.0), subtitle, HORIZONTAL_ALIGNMENT_LEFT, size.x - sx, fs_s, U.MUTED_DARK)

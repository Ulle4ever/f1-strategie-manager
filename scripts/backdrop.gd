extends Control
## Hintergrund "Race Control": helle Fläche, oben ein dunkles Kopfband (feine Carbon-Schraffur, Akzentkante in der Team- bzw. Akzentfarbe).

const U = preload("res://scripts/ui.gd")

var accent := Color("e10600")
var band := -1.0          # Höhe des Kopfbands (-1 = an die Kopfzeile mit der Titelleiste angepasst, 0 = ohne)
var _head: Control = null
var _t := 0.0


## Das Band reicht bis unter die Zeile mit der Titelleiste (wird nachgemessen, falls die Kopfzeile höher ist).
func _process(delta: float) -> void:
	_t -= delta
	if band >= 0.0 or _t > 0.0:
		return
	_t = 0.3
	if _head == null or not is_instance_valid(_head):
		var tb := _find_title(get_parent())
		if tb == null:
			return
		_head = tb.get_parent() as Control if tb.get_parent() is HBoxContainer else tb
	var hb := _head.get_global_rect().end.y - get_global_rect().position.y + (6.0 if U.is_mobile() else 12.0)
	if absf(hb - _band_h) > 0.5:
		_band_h = hb
		queue_redraw()


var _band_h := -1.0


func _find_title(n: Node) -> Control:
	if n == null:
		return null
	for ch in n.get_children():
		if ch.get_script() == preload("res://scripts/title_bar.gd"):
			return ch
		var r := _find_title(ch)
		if r != null:
			return r
	return null


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), U.BG0)
	# leichter Verlauf nach unten
	for i in 8:
		var f := float(i) / 8.0
		draw_rect(Rect2(0, h * (0.5 + f * 0.5), w, h / 16.0 + 1.0), Color(U.BG1, f * 0.6))
	var bh := (_band_h if _band_h > 0.0 else U.header_height()) if band < 0.0 else band
	if bh <= 0.0:
		return
	draw_rect(Rect2(0, 0, w, bh), U.DARK)
	# Carbon-Schraffur rechts
	var x := w * 0.45
	while x < w + bh:
		draw_line(Vector2(x, 0), Vector2(x - bh, bh), Color(1, 1, 1, 0.025), 1.0)
		x += 7.0
	# Akzentkante mit Schrägauslauf
	draw_rect(Rect2(0, bh - 3, w, 3), accent)
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.62, bh - 3), Vector2(w, bh - 3), Vector2(w, bh + 3), Vector2(w * 0.62 + 6, bh + 3)]), accent.darkened(0.2))

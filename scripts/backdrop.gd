extends Control
## Hintergrund: heller Himmelsverlauf mit Lichtfleck, oben ein Kopfband aus hellem Glas mit gerader Akzentkante (Team- bzw. Akzentfarbe).

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
	# Himmelsverlauf: oben kühles Blau, unten heller Dunst, dazu ein weicher Lichtfleck
	var steps := 24
	for i in steps:
		var f := float(i) / float(steps - 1)
		var c := U.BG1.lerp(U.BG0, smoothstep(0.0, 0.75, f))
		draw_rect(Rect2(0, h * float(i) / float(steps), w, h / float(steps) + 1.0), c)
	for r in 6:
		var rr := w * (0.42 - float(r) * 0.06)
		draw_circle(Vector2(w * 0.72, h * 0.18), rr, Color(1, 1, 1, 0.07))
	var bh := (_band_h if _band_h > 0.0 else U.header_height()) if band < 0.0 else band
	if bh <= 0.0:
		return
	# Kopfband als helles Glas mit gerader Akzentkante
	draw_rect(Rect2(0, 0, w, bh), Color(1, 1, 1, 0.5))
	draw_rect(Rect2(0, bh - 1, w, 1), Color(1, 1, 1, 0.95))
	draw_rect(Rect2(0, bh - 3, w * 0.35, 2), accent)

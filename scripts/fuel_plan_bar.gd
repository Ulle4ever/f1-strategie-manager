extends Control
## Tankanzeige fürs Nachtanken: Füllstand nach dem Stopp (grün), aktueller Inhalt (blaue Marke) und Markierungen
## für den Bedarf bis zum nächsten Stopp und bis ins Ziel.

const U = preload("res://scripts/ui.gd")

var cap := 150.0
var target := 0.0       # Tankinhalt nach dem Stopp (kg)
var now := 0.0          # aktueller Tankinhalt (kg)
var marks: Array = []   # [{"kg", "text"}]


func _init() -> void:
	custom_minimum_size = Vector2(0, 50)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_marks(m: Array) -> void:
	if str(m) == str(marks):
		return
	marks = m
	queue_redraw()


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var top := 18.0
	var bh := 14.0
	var font := U.font(true)
	draw_rect(Rect2(0, top, w, bh), U.tint(0.08))
	var tx := w * clampf(target / maxf(cap, 1.0), 0.0, 1.0)
	draw_rect(Rect2(0, top, tx, bh), Color(U.GOOD, 0.85))
	var nx := w * clampf(now / maxf(cap, 1.0), 0.0, 1.0)
	draw_rect(Rect2(0, top + bh - 4.0, nx, 4.0), U.BLUE)
	draw_colored_polygon(PackedVector2Array([Vector2(nx - 4.0, top + bh + 6.0), Vector2(nx + 4.0, top + bh + 6.0), Vector2(nx, top + bh + 1.0)]), U.BLUE)
	var lastx := -100.0
	for m in marks:
		var mx: float = w * clampf(float(m["kg"]) / maxf(cap, 1.0), 0.0, 1.0)
		draw_line(Vector2(mx, top - 4.0), Vector2(mx, top + bh + 2.0), U.TEXT, 2.0)
		var txt := str(m["text"])
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var px := clampf(mx - tw * 0.5, 0.0, maxf(w - tw, 0.0))
		if px < lastx + 4.0:
			px = lastx + 4.0
		draw_string(font, Vector2(px, 11.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, U.TEXT)
		lastx = px + tw
	var lo := "jetzt %d kg" % int(round(now))
	draw_string(U.font(false), Vector2(0, top + bh + 18.0), lo, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, U.BLUE)
	var hi := "danach %d kg" % int(round(target))
	var hw := U.font(false).get_string_size(hi, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(U.font(false), Vector2(w - hw, top + bh + 18.0), hi, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, U.GOOD)

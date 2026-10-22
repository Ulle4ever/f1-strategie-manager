extends Control
## Kleiner schräger Marker (Parallelogramm) vor Abschnittsüberschriften.

var color := Color("e10600")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var h := size.y
	var s := minf(w * 0.5, h * 0.3)
	draw_colored_polygon(PackedVector2Array([Vector2(s, 0), Vector2(w, 0), Vector2(w - s, h), Vector2(0, h)]), color)

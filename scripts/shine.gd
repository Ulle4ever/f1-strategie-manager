extends Control
## Glanzstreifen, der alle paar Sekunden schräg über einen Hauptknopf läuft (nur mit Effekten). Füllt den Knopf, fängt keine Eingaben.

var _t := 0.0
var _period := 4.5


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_t = randf() * _period      # nicht alle Knöpfe gleichzeitig


func _process(delta: float) -> void:
	_t += delta
	var u := fmod(_t, _period)
	if u < 1.1:
		queue_redraw()
	elif u < 1.1 + delta * 2.0:
		queue_redraw()        # einmal leer zeichnen, wenn der Streifen durch ist


func _draw() -> void:
	var u := fmod(_t, _period) / 0.9
	if u > 1.0:
		return
	var w := size.x
	var h := size.y
	var x := lerpf(-h - 60.0, w + 20.0, u)
	var band := 46.0
	for k in 3:
		var bw := band * (1.0 - float(k) * 0.3)
		var xx := x + float(k) * 8.0
		var a := 0.14 + float(k) * 0.06
		draw_colored_polygon(PackedVector2Array([Vector2(xx + h * 0.6, 0), Vector2(xx + h * 0.6 + bw, 0), Vector2(xx + bw, h), Vector2(xx, h)]), Color(1, 1, 1, a))

extends Control
## Zeitenturm im TV-Stil: Positionsfeld, Teamfarbe, Abstände, Reifen, Platzwechsel-Pfeile, Schnellste Runde.

const U = preload("res://scripts/ui.gd")
const RaceSim = preload("res://scripts/race_sim.gd")
const ROW_H := 29.0
const TOP := 34.0

signal car_clicked(car)

var sim
var selected = null
var _rank: Array = []
var _last_rank := {}
var _flash := {}


func _process(_d: float) -> void:
	if sim != null:
		queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var f := U.font(false)
	var fb := U.font(true)
	var now := Time.get_ticks_msec() / 1000.0
	_rank = sim.ranking()
	var leader = _rank[0]
	# Kopf
	draw_rect(Rect2(0, 0, size.x, 26), U.tint(0.07))
	draw_string(fb, Vector2(10, 18), "POS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, U.MUTED)
	draw_string(fb, Vector2(66, 18), "FAHRER", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, U.MUTED)
	draw_string(fb, Vector2(138, 18), "ABSTAND", HORIZONTAL_ALIGNMENT_RIGHT, 78, 12, U.MUTED)
	draw_string(fb, Vector2(220, 18), "VORN", HORIZONTAL_ALIGNMENT_RIGHT, 52, 12, U.MUTED)
	draw_string(fb, Vector2(284, 18), "REIFEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, U.MUTED)
	for i in _rank.size():
		var c = _rank[i]
		var y := TOP + i * ROW_H
		var out: bool = c.state == 3
		# Platzwechsel erkennen
		if _last_rank.has(c.index) and _last_rank[c.index] != i and not out:
			_flash[c.index] = [signi(_last_rank[c.index] - i), now + 4.0]
		_last_rank[c.index] = i
		var bg := U.tint(0.045) if i % 2 == 0 else U.tint(0.02)
		draw_rect(Rect2(0, y, size.x, ROW_H - 2), bg)
		if c.is_player:
			draw_rect(Rect2(0, y, size.x, ROW_H - 2), Color(U.WARN, 0.14))
			draw_rect(Rect2(0, y, 3, ROW_H - 2), U.WARN)
		if c == selected:
			draw_rect(Rect2(0, y, size.x, ROW_H - 2), U.tint(0.10))
			draw_rect(Rect2(size.x - 3, y, 3, ROW_H - 2), U.ACCENT)
		var dim := 0.45 if out else 1.0
		# Positionsfeld
		var pc := Color("dfe4ee") if i > 0 else Color("ffd24a")
		draw_rect(Rect2(8, y + 3, 28, ROW_H - 8), Color(pc, dim))
		draw_string(fb, Vector2(8, y + 20), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 28, 16, U.TEXT)
		# Teamfarbe + Kürzel
		draw_rect(Rect2(41, y + 3, 5, ROW_H - 8), Color(c.color, dim))
		draw_string(fb, Vector2(52, y + 20), c.code, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(U.TEXT, dim) if not c.is_player else U.WARN)
		# Pfeil
		if _flash.has(c.index) and _flash[c.index][1] > now:
			var up: bool = _flash[c.index][0] > 0
			var ax := 114.0
			var ay := y + ROW_H * 0.5 - 1
			if up:
				draw_colored_polygon(PackedVector2Array([Vector2(ax, ay - 5), Vector2(ax + 6, ay + 4), Vector2(ax - 6, ay + 4)]), U.GOOD)
			else:
				draw_colored_polygon(PackedVector2Array([Vector2(ax, ay + 5), Vector2(ax + 6, ay - 4), Vector2(ax - 6, ay - 4)]), U.BAD)
		# Abstände
		var gap_t := ""
		var int_t := ""
		var gcol := U.TEXT
		if c.state == 2:
			gap_t = "BOX"
			gcol = U.WARN
		elif out:
			gap_t = "AUS"
			gcol = U.BAD
		else:
			gap_t = sim.gap_text(c, leader) if sim.started else ""
			if i > 0 and c.state != 3 and c.state != 4 and sim.started:
				int_t = "%.1f" % c.gap_ahead
		draw_string(f, Vector2(138, y + 20), gap_t, HORIZONTAL_ALIGNMENT_RIGHT, 78, 15, Color(gcol, dim))
		var icol := U.MUTED
		if c.gap_ahead < 1.0 and i > 0 and c.state == 1:
			icol = U.GOOD
		draw_string(f, Vector2(220, y + 20), int_t, HORIZONTAL_ALIGNMENT_RIGHT, 52, 14, icol)
		# Reifen
		if not out:
			var cd: Dictionary = RaceSim.COMPOUNDS[c.compound]
			draw_circle(Vector2(296, y + 14), 8.5, cd["color"])
			draw_arc(Vector2(296, y + 14), 8.5, 0.0, TAU, 20, U.tint(0.45), 1.2)
			draw_circle(Vector2(296, y + 14), 5.0, Color(0.06, 0.07, 0.1))
			draw_string(fb, Vector2(290, y + 19), cd["short"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, cd["color"])
			draw_string(f, Vector2(310, y + 19), "%d" % c.tyre_age_laps, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(U.TEXT, dim))
			if c.pit_stops > 0:
				draw_string(f, Vector2(328, y + 19), "%dx" % c.pit_stops, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, U.MUTED)
			if sim.fastest_car == c:
				draw_rect(Rect2(size.x - 30, y + 6, 24, 14), U.PURPLE)
				draw_string(fb, Vector2(size.x - 30, y + 17), "FL", HORIZONTAL_ALIGNMENT_CENTER, 24, 11, Color.WHITE)
		else:
			draw_string(f, Vector2(284, y + 19), c.out_reason, HORIZONTAL_ALIGNMENT_LEFT, 90, 12, U.BAD)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var i := int((mb.position.y - TOP) / ROW_H)
		if i >= 0 and i < _rank.size():
			car_clicked.emit(_rank[i])

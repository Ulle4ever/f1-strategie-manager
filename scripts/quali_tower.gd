extends Control
## Qualifying-Ergebnisturm: Position, Bestzeit, Abstand, Reifen, Status (Box / Outlap / Fliegende Runde), Ausscheidungslinie.

const U = preload("res://scripts/ui.gd")
const ROW_H := 29.0
const TOP := 34.0

signal car_clicked(qcar)

var qsim
var selected = null
var _rows: Array = []


func _process(_d: float) -> void:
	if qsim != null:
		queue_redraw()


func _draw() -> void:
	if qsim == null:
		return
	var f := U.font(false)
	var fb := U.font(true)
	var sim = qsim.sim
	_rows = qsim.standings()
	draw_rect(Rect2(0, 0, size.x, 26), U.tint(0.07))
	draw_string(fb, Vector2(10, 18), "POS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, U.MUTED)
	draw_string(fb, Vector2(66, 18), "FAHRER", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, U.MUTED)
	draw_string(fb, Vector2(130, 18), "BESTZEIT", HORIZONTAL_ALIGNMENT_RIGHT, 90, 12, U.MUTED)
	draw_string(fb, Vector2(222, 18), "ABSTAND", HORIZONTAL_ALIGNMENT_RIGHT, 62, 12, U.MUTED)
	draw_string(fb, Vector2(296, 18), "STATUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, U.MUTED)
	var adv := 0
	if qsim.phase_idx >= 0 and qsim.phase_idx < qsim.phases.size():
		adv = int(qsim.phases[qsim.phase_idx]["advance"])
	var best_t := 0.0
	for q in _rows:
		if not q.eliminated and q.best > 0.0:
			best_t = q.best
			break
	for i in _rows.size():
		var q = _rows[i]
		var c = q.car
		var y := TOP + i * ROW_H
		var elim: bool = q.eliminated
		var dim := 0.42 if elim else 1.0
		draw_rect(Rect2(0, y, size.x, ROW_H - 2), U.tint(0.045) if i % 2 == 0 else U.tint(0.02))
		if q.is_player:
			draw_rect(Rect2(0, y, size.x, ROW_H - 2), Color(U.WARN, 0.14))
			draw_rect(Rect2(0, y, 3, ROW_H - 2), U.WARN)
		if q == selected:
			draw_rect(Rect2(0, y, size.x, ROW_H - 2), U.tint(0.10))
		var pc := Color("dfe4ee") if i > 0 else Color("ffd24a")
		draw_rect(Rect2(8, y + 3, 28, ROW_H - 8), Color(pc, dim))
		draw_string(fb, Vector2(8, y + 20), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 28, 16, U.TEXT)
		draw_rect(Rect2(41, y + 3, 5, ROW_H - 8), Color(c.color, dim))
		draw_string(fb, Vector2(52, y + 20), c.code, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(U.TEXT, dim) if not q.is_player else U.WARN)
		var tcol := U.PURPLE if (i == 0 and not elim and q.best > 0.0) else U.TEXT
		var tshow := ""
		if elim:
			var pb := 0.0
			for k in range(2, -1, -1):
				if float(q.phase_best[k]) > 0.0:
					pb = q.phase_best[k]
					break
			tshow = sim.fmt_time(pb) if pb > 0.0 else "--"
		else:
			tshow = sim.fmt_time(q.best) if q.best > 0.0 else "--:--.---"
		draw_string(f, Vector2(130, y + 20), tshow, HORIZONTAL_ALIGNMENT_RIGHT, 90, 15, Color(tcol, dim))
		if not elim and q.best > 0.0 and i > 0 and best_t > 0.0:
			draw_string(f, Vector2(222, y + 20), "+%.3f" % (q.best - best_t), HORIZONTAL_ALIGNMENT_RIGHT, 62, 14, U.MUTED)
		# Status
		var st := ""
		var scol := U.MUTED
		if elim:
			st = "AUS"
			scol = U.BAD
		elif q.crashed:
			st = "UNFALL"
			scol = U.BAD
		elif q.state == 1:
			if qsim.time < q.out_end:
				st = "OUTLAP"
				scol = U.WARN
			elif q.fly_end > 0.0 and qsim.time <= q.fly_end:
				st = "SCHNELL"
				scol = U.GOOD
			else:
				st = "INLAP"
				scol = U.MUTED
		else:
			st = "BOX"
		draw_string(fb, Vector2(296, y + 19), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(scol, dim))
		if not elim and q.best_comp >= 0:
			var cd: Dictionary = sim.COMPOUNDS[q.best_comp]
			draw_circle(Vector2(size.x - 18, y + 14), 8.0, cd["color"])
			draw_arc(Vector2(size.x - 18, y + 14), 8.0, 0.0, TAU, 20, U.tint(0.45), 1.2)
			draw_circle(Vector2(size.x - 18, y + 14), 4.6, Color(0.06, 0.07, 0.1))
			draw_string(fb, Vector2(size.x - 23, y + 19), cd["short"], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, cd["color"])
		# Ausscheidungslinie
		if adv > 0 and i == adv - 1 and not elim:
			var ly := y + ROW_H - 1
			var x := 0.0
			while x < size.x:
				draw_line(Vector2(x, ly), Vector2(x + 8, ly), U.ACCENT, 2.0)
				x += 14.0


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var i := int((mb.position.y - TOP) / ROW_H)
		if i >= 0 and i < _rows.size():
			car_clicked.emit(_rows[i])

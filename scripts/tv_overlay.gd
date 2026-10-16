extends Control
## TV-Grafiken über der Streckenkarte: Fahrerkarte mit Telemetrie und Sektorfarben, Rundenzeit-Einblendung,
## Zweikampf-Banner, Laufband mit Positionswechseln, Startaufstellung vor dem Start.

const U = preload("res://scripts/ui.gd")
const RaceSim = preload("res://scripts/race_sim.gd")

var sim
var selected = null
var _toast := {}
var _toast_t := 0.0
var _battle := {}
var _battle_t := 0.0
var _ticker: Array = []
var _ev_index := 0
var _last_lap := {}
var _last_rank := {}
var _rank_timer := 0.0
var _scroll := 0.0
var _t := 0.0
var compact := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	compact = U.is_mobile()


func _process(delta: float) -> void:
	if sim == null:
		return
	_t += delta
	_toast_t = maxf(0.0, _toast_t - delta)
	_battle_t = maxf(0.0, _battle_t - delta)
	_scroll += delta * 55.0
	_poll_events()
	_poll_laps()
	_rank_timer -= delta
	if _rank_timer <= 0.0:
		_rank_timer = 0.8
		_poll_positions()
		_poll_battle()
	queue_redraw()


func _poll_events() -> void:
	while _ev_index < sim.events.size():
		var e: Dictionary = sim.events[_ev_index]
		_ev_index += 1
		var k: String = e["kind"]
		if k in ["pit", "dnf", "sc", "fastest", "weather", "radio"]:
			var tag := "BOX" if k == "pit" else ("AUSFALL" if k == "dnf" else ("SC" if k == "sc" else ("FL" if k == "fastest" else ("WETTER" if k == "weather" else "FUNK"))))
			_ticker.push_front("%s  %s" % [tag, e["text"]])
	if _ticker.size() > 14:
		_ticker.resize(14)


func _poll_laps() -> void:
	for c in sim.cars:
		if not c.is_player or c.last_lap <= 0.0:
			continue
		var prev: float = float(_last_lap.get(c.index, 0.0))
		if absf(c.last_lap - prev) > 0.0005:
			_last_lap[c.index] = c.last_lap
			if prev <= 0.0 and c.lap_history.size() < 2:
				continue
			var text := "%s  %s" % [c.code, sim.fmt_time(c.last_lap)]
			var tag := ""
			var col := U.WARN
			if sim.fastest_car == c and absf(sim.fastest_lap - c.last_lap) < 0.0005:
				tag = "SCHNELLSTE RUNDE"
				col = U.PURPLE
			elif c.last_lap <= c.best_lap + 0.0005:
				tag = "PERSÖNLICHE BESTZEIT"
				col = U.GOOD
			else:
				tag = "+%.3f zur Bestzeit" % (c.last_lap - c.best_lap)
			_toast = {"text": text, "tag": tag, "col": col, "color": c.color}
			_toast_t = 5.0


func _poll_positions() -> void:
	var rk: Array = sim.ranking()
	for i in mini(10, rk.size()):
		var c = rk[i]
		if c.state == 3:
			continue
		var prev: int = int(_last_rank.get(c.index, i))
		if prev != i and sim.started and sim.time > 25.0:
			if i < prev:
				_ticker.push_front("+ %s  P%d  ->  P%d" % [c.code, prev + 1, i + 1])
			else:
				_ticker.push_front("- %s  P%d  ->  P%d" % [c.code, prev + 1, i + 1])
		_last_rank[c.index] = i
	for i in range(10, rk.size()):
		_last_rank[rk[i].index] = i
	if _ticker.size() > 14:
		_ticker.resize(14)


func _poll_battle() -> void:
	if not sim.started or sim.status != 0:
		return
	var rk: Array = sim.ranking()
	var best = null
	var best_score := -1.0
	for i in range(1, rk.size()):
		var c = rk[i]
		var a = rk[i - 1]
		if c.state != 1 or a.state != 1:
			continue
		if c.gap_ahead > 0.9:
			continue
		var score: float = 2.0 - c.gap_ahead + (3.0 if (c.is_player or a.is_player) else 0.0) + (1.0 if i <= 6 else 0.0)
		if score > best_score:
			best_score = score
			best = {"a": a, "b": c, "pos": i}
	if best != null:
		_battle = best
		_battle_t = 4.0


# ------------------------------------------------------------------ Zeichnen

func _draw() -> void:
	if sim == null:
		return
	if not sim.started:
		_draw_grid()
	else:
		if selected != null:
			_draw_card(selected)
		if _toast_t > 0.0:
			_draw_toast()
		if _battle_t > 0.0 and not _battle.is_empty():
			_draw_battle()
	_draw_ticker()


func _panel(r: Rect2, col: Color) -> void:
	draw_rect(r, Color(0.03, 0.04, 0.07, 0.88))
	draw_rect(Rect2(r.position, Vector2(4, r.size.y)), col)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(U.ACCENT, 0.9))


func _sector_col(v: int) -> Color:
	match v:
		3:
			return U.PURPLE
		2:
			return U.GOOD
		1:
			return U.WARN
	return Color(1, 1, 1, 0.12)


func _draw_card(c) -> void:
	if compact:
		_draw_card_compact(c)
		return
	var f := U.font(false)
	var fb := U.font(true)
	var r := Rect2(10, size.y - 28 - 116, 318, 112)
	_panel(r, c.color)
	var rk: Array = sim.ranking()
	var pos: int = rk.find(c) + 1
	var x := r.position.x + 14.0
	var y := r.position.y + 8.0
	draw_rect(Rect2(x, y, 36, 28), Color.WHITE if pos > 1 else U.WARN)
	draw_string(fb, Vector2(x, y + 21), "P%d" % pos, HORIZONTAL_ALIGNMENT_CENTER, 36, 17, Color(0.05, 0.05, 0.08))
	draw_string(fb, Vector2(x + 46, y + 22), c.code, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, U.WARN if c.is_player else Color.WHITE)
	draw_string(f, Vector2(x + 100, y + 21), "#%s  %s" % [c.number, c.driver_name], HORIZONTAL_ALIGNMENT_LEFT, 210, 13, U.MUTED)
	# Tempo
	var kmh := int(c.speed * 3.6) if c.state == 1 else 0
	draw_string(fb, Vector2(x, y + 58), "%d" % kmh, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	draw_string(f, Vector2(x + 62, y + 58), "km/h", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, U.MUTED)
	# Reifen
	var cd: Dictionary = RaceSim.COMPOUNDS[c.compound]
	draw_circle(Vector2(x + 128, y + 48), 11.0, cd["color"])
	draw_circle(Vector2(x + 128, y + 48), 6.5, Color(0.06, 0.07, 0.1))
	draw_string(fb, Vector2(x + 122, y + 53), cd["short"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cd["color"])
	draw_string(f, Vector2(x + 146, y + 53), "%d Rd." % c.tyre_age_laps, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, U.TEXT)
	# Batterie oder Motormodus
	if sim.has_ers():
		var bx := x + 210.0
		draw_rect(Rect2(bx, y + 38, 90, 8), Color(1, 1, 1, 0.1))
		var ec: Color = U.GOOD if c.ers > 30.0 else (U.WARN if c.ers > 10.0 else U.BAD)
		draw_rect(Rect2(bx, y + 38, 90.0 * clampf(c.ers / 100.0, 0.0, 1.0), 8), ec)
		draw_string(f, Vector2(bx, y + 58), "ERS %d %%  %s" % [int(c.ers), RaceSim.ERS_NAMES[c.ers_mode]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, U.MUTED)
	else:
		draw_string(f, Vector2(x + 210, y + 57), "Motor: %s" % RaceSim.ENG_NAMES[c.eng_mode], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, U.MUTED)
	# Sektoren
	var sy := y + 66.0
	for k in 3:
		var sx := x + float(k) * 100.0
		var col := _sector_col(int(c.sec_cols[k]))
		draw_rect(Rect2(sx, sy, 94, 20), Color(col, 0.28 if int(c.sec_cols[k]) > 0 else 0.10))
		draw_rect(Rect2(sx, sy + 17, 94, 3), col)
		var tt: float = float(c.sec_times[k])
		draw_string(f, Vector2(sx + 4, sy + 14), "S%d  %s" % [k + 1, ("%.1f" % tt) if (tt > 0.0 and int(c.sec_cols[k]) > 0) else "--"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	# Runden
	draw_string(f, Vector2(x, sy + 36), "Letzte %s   Beste %s" % [sim.fmt_time(c.last_lap), sim.fmt_time(c.best_lap)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, U.TEXT)


func _draw_toast() -> void:
	if compact:
		_draw_toast_compact()
		return
	var fb := U.font(true)
	var f := U.font(false)
	var w := minf(380.0, size.x - 20.0)
	var a := clampf(_toast_t / 0.6, 0.0, 1.0)
	var r := Rect2((size.x - w) * 0.5, 44, w, 54)
	draw_rect(r, Color(0.03, 0.04, 0.07, 0.9 * a))
	draw_rect(Rect2(r.position, Vector2(6, r.size.y)), Color(_toast["color"], a))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3), Vector2(r.size.x, 3)), Color(_toast["col"], a))
	draw_string(fb, r.position + Vector2(18, 28), _toast["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, a))
	draw_string(fb, r.position + Vector2(18, 46), str(_toast["tag"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(_toast["col"], a))


func _draw_battle() -> void:
	if compact:
		_draw_battle_compact()
		return
	var fb := U.font(true)
	var f := U.font(false)
	var a: RaceSim.RaceCar = _battle["a"]
	var b: RaceSim.RaceCar = _battle["b"]
	var w := minf(460.0, size.x - 20.0)
	var top := 104.0 if _toast_t > 0.0 else 44.0
	var fade := clampf(_battle_t / 0.6, 0.0, 1.0)
	var r := Rect2((size.x - w) * 0.5, top, w, 44)
	draw_rect(r, Color(0.03, 0.04, 0.07, 0.88 * fade))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(U.ACCENT, fade))
	draw_string(fb, r.position + Vector2(12, 18), "ZWEIKAMPF", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(U.ACCENT_HI, fade))
	draw_string(fb, r.position + Vector2(12, 38), "P%d %s" % [int(_battle["pos"]), a.code], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(a.color.lightened(0.3), fade))
	draw_string(fb, r.position + Vector2(112, 38), "P%d %s" % [int(_battle["pos"]) + 1, b.code], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(b.color.lightened(0.3), fade))
	draw_string(fb, r.position + Vector2(212, 38), "%.1f s" % b.gap_ahead, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(U.GOOD if b.gap_ahead < 1.0 else U.TEXT, fade))
	var ca: Dictionary = RaceSim.COMPOUNDS[a.compound]
	var cb: Dictionary = RaceSim.COMPOUNDS[b.compound]
	draw_string(fb, r.position + Vector2(290, 38), "%s%d" % [ca["short"], a.tyre_age_laps], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(ca["color"], fade))
	draw_string(f, r.position + Vector2(335, 38), "vs", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(U.MUTED, fade))
	draw_string(fb, r.position + Vector2(355, 38), "%s%d" % [cb["short"], b.tyre_age_laps], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(cb["color"], fade))
	if b.drs:
		draw_rect(Rect2(r.position + Vector2(r.size.x - 52, 8), Vector2(40, 18)), Color(U.GOOD, fade))
		draw_string(fb, r.position + Vector2(r.size.x - 52, 21), "DRS", HORIZONTAL_ALIGNMENT_CENTER, 40, 12, Color(0.03, 0.1, 0.05, fade))


func _draw_ticker() -> void:
	if _ticker.is_empty():
		return
	var f := U.font(true)
	var th := 22.0 if compact else 26.0
	var r := Rect2(0, size.y - th, size.x, th)
	draw_rect(r, Color(0.03, 0.04, 0.07, 0.86))
	var fs_t := 12 if compact else 13
	var text := "   |   ".join(_ticker.slice(0, 8))
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 90.0
	var off := fmod(_scroll, tw)
	for rep in 3:
		var x := 84.0 - off + float(rep) * tw
		if x < size.x:
			draw_string(f, Vector2(x, r.position.y + th - 8.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_t, U.TEXT)
	draw_rect(Rect2(0, r.position.y, 74, th), U.ACCENT)
	draw_string(f, Vector2(0, r.position.y + th - 8.0), "LIVE", HORIZONTAL_ALIGNMENT_CENTER, 74, fs_t, Color.WHITE)


## Schneidet am linken Rand abgeschnittenen Text ab (grobe Annäherung über Zeichenbreite).
func _clip_left(text: String, f: Font, x: float, min_x: float) -> String:
	if x >= min_x:
		return text
	var skip := min_x - x
	var acc := 0.0
	for i in text.length():
		acc += f.get_string_size(text.substr(i, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		if acc >= skip:
			return text.substr(i + 1)
	return ""


func _draw_grid() -> void:
	var fb := U.font(true)
	var f := U.font(false)
	var rk: Array = sim.grid_order()
	var rows := int(ceil(float(rk.size()) / 2.0))
	var w := minf(344.0, size.x - 20.0)
	var row_h := 14.0 if compact else 17.0
	var h := 34.0 + float(rows) * row_h
	var r := Rect2(10.0, size.y - 28.0 - h - 6.0, w, h)
	_panel(r, U.ACCENT)
	draw_string(fb, r.position + Vector2(14, 22), "STARTAUFSTELLUNG", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	for i in rk.size():
		var c = rk[i]
		var col := i % 2
		var row := i / 2
		var x := r.position.x + 12.0 + float(col) * (w * 0.5)
		var y := r.position.y + 30.0 + float(row) * row_h + (8.0 if col == 1 else 0.0)
		draw_string(fb, Vector2(x, y + 14), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, 22, 13, U.MUTED)
		draw_rect(Rect2(x + 24, y + 1, 4, 15), c.color)
		draw_string(fb, Vector2(x + 34, y + 14), c.code, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, U.WARN if c.is_player else Color.WHITE)
		if c.grid_penalty > 0:
			draw_string(f, Vector2(x + 76, y + 14), "-%d" % c.grid_penalty, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, U.BAD)
		if c.forced_start >= 0:
			var cd: Dictionary = RaceSim.COMPOUNDS[c.forced_start]
			draw_string(fb, Vector2(x + 110, y + 14), cd["short"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cd["color"])


# ------------------------------------------------------------------ kompakte Varianten (Handy)

func _draw_card_compact(c) -> void:
	var f := U.font(false)
	var fb := U.font(true)
	var r := Rect2(8, size.y - 22 - 66, 330, 62)
	_panel(r, c.color)
	var rk: Array = sim.ranking()
	var pos: int = rk.find(c) + 1
	var x := r.position.x + 12.0
	var y := r.position.y + 6.0
	draw_rect(Rect2(x, y, 32, 22), Color.WHITE if pos > 1 else U.WARN)
	draw_string(fb, Vector2(x, y + 17), "P%d" % pos, HORIZONTAL_ALIGNMENT_CENTER, 32, 14, Color(0.05, 0.05, 0.08))
	draw_string(fb, Vector2(x + 40, y + 18), c.code, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, U.WARN if c.is_player else Color.WHITE)
	var kmh := int(c.speed * 3.6) if c.state == 1 else 0
	draw_string(fb, Vector2(x + 92, y + 18), "%d" % kmh, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(f, Vector2(x + 128, y + 18), "km/h", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, U.MUTED)
	var cd: Dictionary = RaceSim.COMPOUNDS[c.compound]
	draw_circle(Vector2(x + 178, y + 11), 9.0, cd["color"])
	draw_circle(Vector2(x + 178, y + 11), 5.0, Color(0.06, 0.07, 0.1))
	draw_string(f, Vector2(x + 192, y + 16), "%d" % c.tyre_age_laps, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, U.TEXT)
	if sim.has_ers():
		var bx := x + 222.0
		draw_rect(Rect2(bx, y + 8, 84, 7), Color(1, 1, 1, 0.1))
		var ec: Color = U.GOOD if c.ers > 30.0 else (U.WARN if c.ers > 10.0 else U.BAD)
		draw_rect(Rect2(bx, y + 8, 84.0 * clampf(c.ers / 100.0, 0.0, 1.0), 7), ec)
	var sy := y + 30.0
	for k in 3:
		var sx := x + float(k) * 102.0
		var col := _sector_col(int(c.sec_cols[k]))
		draw_rect(Rect2(sx, sy, 98, 18), Color(col, 0.28 if int(c.sec_cols[k]) > 0 else 0.10))
		draw_rect(Rect2(sx, sy + 15, 98, 3), col)
		var tt: float = float(c.sec_times[k])
		draw_string(f, Vector2(sx + 4, sy + 12), "S%d  %s" % [k + 1, ("%.1f" % tt) if (tt > 0.0 and int(c.sec_cols[k]) > 0) else "--"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


func _draw_toast_compact() -> void:
	var fb := U.font(true)
	var a := clampf(_toast_t / 0.6, 0.0, 1.0)
	var w := minf(330.0, size.x - 16.0)
	var r := Rect2(size.x - w - 8.0, 44, w, 34)
	draw_rect(r, Color(0.03, 0.04, 0.07, 0.9 * a))
	draw_rect(Rect2(r.position, Vector2(5, r.size.y)), Color(_toast["color"], a))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 3), Vector2(r.size.x, 3)), Color(_toast["col"], a))
	draw_string(fb, r.position + Vector2(12, 21), _toast["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 1, 1, a))
	draw_string(fb, r.position + Vector2(150, 21), str(_toast["tag"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w - 156.0, 10, Color(_toast["col"], a))


func _draw_battle_compact() -> void:
	var fb := U.font(true)
	var a: RaceSim.RaceCar = _battle["a"]
	var b: RaceSim.RaceCar = _battle["b"]
	var fade := clampf(_battle_t / 0.6, 0.0, 1.0)
	var w := minf(330.0, size.x - 16.0)
	var top := 84.0 if _toast_t > 0.0 else 44.0
	var r := Rect2(size.x - w - 8.0, top, w, 26)
	draw_rect(r, Color(0.03, 0.04, 0.07, 0.88 * fade))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), Color(U.ACCENT, fade))
	draw_string(fb, r.position + Vector2(8, 19), "DUELL  %s - %s  %.1f s" % [a.code, b.code, b.gap_ahead], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, fade))
	var ca: Dictionary = RaceSim.COMPOUNDS[a.compound]
	var cb: Dictionary = RaceSim.COMPOUNDS[b.compound]
	draw_string(fb, r.position + Vector2(230, 19), "%s%d" % [ca["short"], a.tyre_age_laps], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(ca["color"], fade))
	draw_string(fb, r.position + Vector2(262, 19), "%s%d" % [cb["short"], b.tyre_age_laps], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(cb["color"], fade))
	if b.drs:
		draw_string(fb, r.position + Vector2(296, 19), "DRS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(U.GOOD, fade))

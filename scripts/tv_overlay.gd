extends Control
## TV-Grafiken über der Streckenkarte im Stil einer modernen F1-Übertragung: schräge dunkle Glas-Kacheln mit Teamfarben-Kante,
## Renn-Schrift für Positionen und Zeiten. Fahrerkarte mit Telemetrie und Sektoren, Rundenzeit-Einblendung, Zweikampf-Banner,
## Mini-Zeitentafel auf der großen Karte, Laufband mit Positionswechseln, Startaufstellung vor dem Start.
## Einblendungen gleiten herein statt aufzuspringen.

const U = preload("res://scripts/ui.gd")
const DriverPhoto = preload("res://scripts/driver_photo.gd")
const RaceSim = preload("res://scripts/race_sim.gd")

const GLASS := Color(0.05, 0.06, 0.09, 0.9)
const GLASS2 := Color(0.12, 0.13, 0.17, 0.95)
const WHITE := Color(0.97, 0.98, 1.0)
const DIM := Color(0.66, 0.70, 0.78)
const PURPLE_HI := Color("b26bff")
const GREEN_HI := Color("34d399")
const YELLOW_HI := Color("fbbf24")
const RED_HI := Color("f87171")

var sim
var selected = null
var _toast := {}
var _toast_t := 0.0
var _toast_age := 99.0
var _battle := {}
var _battle_t := 0.0
var _battle_age := 99.0
var _ticker: Array = []
var _ev_index := 0
var _last_lap := {}
var _last_rank := {}
var _rank_timer := 0.0
var _scroll := 0.0
var _t := 0.0
var compact := false
var _status_prev := 0
var _flag_kind := ""         # Banner: "sc", "vsc", "green"
var _flag_t := 0.0
var _flag_age := 99.0
var _pits := {}              # Auto-Index -> {"car", "old", "new", "stat", "total", "end"} Boxenstopp-Grafik der eigenen Autos


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
	_toast_age += delta
	_battle_age += delta
	_scroll += delta * 55.0
	_flag_t = maxf(0.0, _flag_t - delta)
	_flag_age += delta
	_poll_status()
	_poll_pits(delta)
	_poll_events()
	_poll_laps()
	_rank_timer -= delta
	if _rank_timer <= 0.0:
		_rank_timer = 0.8
		_poll_positions()
		_poll_battle()
	queue_redraw()


# ------------------------------------------------------------------ Ereignisse sammeln

## Safety Car / VSC / Grün: Wechsel des Rennstatus löst ein Banner aus.
func _poll_status() -> void:
	var st: int = sim.status
	if st == _status_prev:
		return
	if st == 2 or st == 1:
		_flag_kind = "sc" if st == 2 else "vsc"
		_flag_t = 4.2
		_flag_age = 0.0
	elif _status_prev != 0 and st == 0 and sim.started:
		_flag_kind = "green"
		_flag_t = 3.0
		_flag_age = 0.0
	_status_prev = st


## Boxenstopps der eigenen Autos verfolgen (für die Boxenstopp-Grafik, nach dem Stopp noch kurz sichtbar).
func _poll_pits(delta: float) -> void:
	for c in sim.cars:
		if not c.is_player:
			continue
		if c.state == RaceSim.State.PIT:
			if not _pits.has(c.index) or float(_pits[c.index]["end"]) >= 0.0:
				_pits[c.index] = {"car": c, "old": c.compound, "new": c.pit_comp, "stat": c.pit_stat, "total": c.pit_total, "end": -1.0}
			_pits[c.index]["new"] = c.pit_comp
		elif _pits.has(c.index):
			var e: Dictionary = _pits[c.index]
			if float(e["end"]) < 0.0:
				e["end"] = 2.6
			else:
				e["end"] = float(e["end"]) - delta
				if float(e["end"]) <= 0.0:
					_pits.erase(c.index)

func _poll_events() -> void:
	while _ev_index < sim.events.size():
		var e: Dictionary = sim.events[_ev_index]
		_ev_index += 1
		var k: String = e["kind"]
		if k in ["pit", "dnf", "sc", "fastest", "weather", "radio"]:
			var tag := "BOX" if k == "pit" else ("AUSFALL" if k == "dnf" else ("SC" if k == "sc" else ("FL" if k == "fastest" else ("WETTER" if k == "weather" else "FUNK"))))
			_ticker.push_front({"tag": tag, "text": str(e["text"]), "dir": 0})
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
			var tag := ""
			var col := DIM
			if sim.fastest_car == c and absf(sim.fastest_lap - c.last_lap) < 0.0005:
				tag = "SCHNELLSTE RUNDE"
				col = PURPLE_HI
			elif c.last_lap <= c.best_lap + 0.0005:
				tag = "PERSÖNLICHE BESTZEIT"
				col = GREEN_HI
			else:
				tag = "+%.3f" % (c.last_lap - c.best_lap)
				col = YELLOW_HI
			_toast = {"car": c, "time": sim.fmt_time(c.last_lap), "tag": tag, "col": col}
			_toast_t = 5.0
			_toast_age = 0.0


func _poll_positions() -> void:
	var rk: Array = sim.ranking()
	for i in mini(10, rk.size()):
		var c = rk[i]
		if c.state == 3:
			continue
		var prev: int = int(_last_rank.get(c.index, i))
		if prev != i and sim.started and sim.time > 25.0:
			_ticker.push_front({"tag": "", "text": "%s  P%d" % [c.code, i + 1], "dir": 1 if i < prev else -1})
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
		var same: bool = not _battle.is_empty() and _battle["a"] == best["a"] and _battle["b"] == best["b"] and _battle_t > 0.0
		_battle = best
		_battle_t = 4.0
		if not same:
			_battle_age = 0.0


# ------------------------------------------------------------------ Bausteine

func _k() -> float:
	return 0.82 if compact else 1.0


## Kleine Karte am Handy (Fahrer-Panel daneben): schmale Einblendungen, damit die Strecke sichtbar bleibt.
func _mini() -> bool:
	return compact and size.x < 520.0


func _fd() -> Font:
	return U.display_font()


## Dunkle Glas-Kachel mit geraden Kanten (damit nichts abgeschnitten wird); dünne Kante oben in der Farbe col.
func _slab(r: Rect2, col: Color, a := 1.0) -> void:
	draw_rect(r, Color(GLASS, GLASS.a * a))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), Color(col, a))


## Schräges Feld mit Text in der Mitte (Positionsfeld, Marken).
func _tag(r: Rect2, bg: Color, text: String, fg: Color, fs: int, font: Font = null) -> void:
	var s := r.size.y * 0.25
	draw_colored_polygon(PackedVector2Array([r.position + Vector2(s, 0), Vector2(r.end.x, r.position.y), r.end - Vector2(s, 0), Vector2(r.position.x, r.end.y)]), bg)
	var f := font if font != null else _fd()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(r.position.x + (r.size.x - w) * 0.5, r.position.y + r.size.y * 0.5 + float(fs) * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)


func _txt(pos: Vector2, s: String, fs: int, col: Color, font: Font = null, width := -1.0) -> void:
	draw_string(font if font != null else U.font(true), pos, s, HORIZONTAL_ALIGNMENT_LEFT, width, fs, col)


func _txt_r(right: Vector2, s: String, fs: int, col: Color, font: Font = null) -> void:
	var f := font if font != null else U.font(true)
	draw_string(f, right - Vector2(f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _tyre(c: Vector2, comp: int, rad: float) -> void:
	var cd: Dictionary = RaceSim.COMPOUNDS[comp]
	draw_circle(c, rad, cd["color"])
	draw_circle(c, rad * 0.6, Color(0.06, 0.07, 0.1))
	var f := U.font(true)
	var fs := int(rad * 1.05)
	var s: String = cd["short"]
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, c + Vector2(-w * 0.5, fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cd["color"])


func _sector_col(v: int) -> Color:
	match v:
		3:
			return PURPLE_HI
		2:
			return GREEN_HI
		1:
			return YELLOW_HI
	return Color(1, 1, 1, 0.14)


## Einblende-Verlauf: 0..1 beim Hereingleiten (0,35 s), am Ende 0,5 s Ausblenden.
func _ease_in(age: float) -> float:
	var x := clampf(age / 0.35, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


func _team_col(c) -> Color:
	var col: Color = c.color
	return col.lightened(0.25) if col.get_luminance() < 0.25 else col


# ------------------------------------------------------------------ Zeichnen

func _draw() -> void:
	if sim == null:
		return
	var tight := compact and size.y < 150.0   # sehr wenig Platz: nur Fahrerkarte und Laufband
	if not sim.started:
		_draw_grid()
	else:
		var big := size.x > (600.0 if compact else 760.0) and size.y > (240.0 if compact else 420.0)
		if big:
			_draw_tower()
		# Handy mit Fahrer-Panel neben der Karte: Fahrerkarte weglassen (das Panel zeigt dieselben Werte), nur auf der großen Karte zeigen
		if selected != null and not (compact and (size.y < 170.0 or size.x < 600.0)):
			_draw_card(selected)
		# Einblendungen oben rechts (große Karte: ganz oben, sonst unter den Kartenknöpfen)
		var top := 8.0 if big else 44.0 * _k()
		if _toast_t > 0.0 and not tight:
			top = _draw_toast(top) + 6.0
		if _battle_t > 0.0 and not _battle.is_empty() and not tight:
			_draw_battle(top)
		if sim.status != 0:
			_draw_sc_frame()
		if not _pits.is_empty() and not tight:
			_draw_pits(44.0 * _k() if not big else 8.0)
		if _flag_t > 0.0:
			_draw_flag_banner()
	_draw_ticker()


## Gelber Rahmen um die Karte, solange Safety Car oder VSC draußen sind (pulsiert).
func _draw_sc_frame() -> void:
	var a := 0.35 + 0.3 * absf(sin(_t * 3.0))
	draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(YELLOW_HI, a), false, 4.0)


## Banner in der Bildmitte oben: SAFETY CAR / VIRTUAL SAFETY CAR mit blinkenden Leuchten und laufenden Warnstreifen,
## oder GRÜN, wenn das Rennen wieder freigegeben ist. Gleitet herein und blendet am Ende aus.
func _draw_flag_banner() -> void:
	var k := _k()
	var mini := _mini()
	var fd := _fd()
	var e := _ease_in(_flag_age)
	var a := clampf(_flag_t / 0.5, 0.0, 1.0)
	var green := _flag_kind == "green"
	var text := "GRÜN  ·  RENNEN FREI" if green else ("SAFETY CAR" if _flag_kind == "sc" else ("VSC" if mini else "VIRTUAL SAFETY CAR"))
	var fs := int((16 if mini else 24) * k)
	var tw := fd.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w := minf(tw + (90.0 if mini else 150.0) * k, size.x - 16.0)
	var h := (30.0 if mini else 44.0) * k
	var x := (size.x - w) * 0.5 - (1.0 - e) * (size.x * 0.5 + w)
	var y := size.y * (0.2 if not mini else 0.32)
	var r := Rect2(x, y, w, h)
	var bg := Color("16a34a") if green else Color("facc15")
	var ink := Color.WHITE if green else Color(0.05, 0.05, 0.08)
	draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.25 * a))
	draw_rect(r, Color(bg, a))
	# laufende Warnstreifen an beiden Enden
	var sw := (26.0 if mini else 42.0) * k
	for side in 2:
		var zx := r.position.x if side == 0 else r.end.x - sw
		draw_rect(Rect2(zx, r.position.y, sw, h), Color(0.05, 0.05, 0.08, a) if not green else Color(1, 1, 1, 0.18 * a))
		var off := fmod(_t * 40.0, 14.0)
		var xx := zx - 14.0 + off
		while xx < zx + sw:
			var p0 := maxf(xx, zx)
			var p1 := minf(xx + 7.0, zx + sw)
			if p1 > p0:
				draw_colored_polygon(PackedVector2Array([Vector2(p0, r.position.y), Vector2(p1, r.position.y), Vector2(maxf(p1 - 6.0, zx), r.end.y), Vector2(maxf(p0 - 6.0, zx), r.end.y)]), Color(bg, a) if not green else Color(1, 1, 1, 0.35 * a))
			xx += 14.0
	# blinkende Leuchten
	if not green:
		var on := fmod(_t, 0.5) < 0.25
		var lr := 5.0 * k
		draw_circle(Vector2(r.position.x + sw + 12.0 * k, r.position.y + h * 0.5), lr, Color(1.0, 0.55, 0.05, a if on else 0.25 * a))
		draw_circle(Vector2(r.end.x - sw - 12.0 * k, r.position.y + h * 0.5), lr, Color(1.0, 0.55, 0.05, 0.25 * a if on else a))
	draw_string(fd, Vector2(r.position.x + (w - tw) * 0.5, r.position.y + h * 0.5 + float(fs) * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ink, a))


## Boxenstopp-Grafik der eigenen Autos: Auto von oben, die vier Reifen wechseln nacheinander auf die neue Mischung,
## Standzeit zählt mit; nach dem Stopp kurz die Endzeit.
func _draw_pits(top: float) -> void:
	var k := _k()
	var mini := _mini()
	var fd := _fd()
	var y := top
	for idx in _pits.keys():
		var e: Dictionary = _pits[idx]
		var c = e["car"]
		var total: float = maxf(float(e["total"]), 0.1)
		var stat: float = float(e["stat"])
		var done := float(e["end"]) >= 0.0
		var elapsed := total if done else total - float(c.pit_timer)
		var t_in := maxf(0.0, (total - stat) * 0.45)
		var u := clampf((elapsed - t_in) / maxf(stat, 0.1), 0.0, 1.0)     # Fortschritt der Standzeit
		var phase := "STOPP" if u > 0.0 and u < 1.0 else ("EINFAHRT" if u <= 0.0 else "AUSFAHRT")
		if done:
			phase = "FERTIG"
		var w := (170.0 if mini else 230.0) * k
		var h := (52.0 if mini else 66.0) * k
		var a := clampf(float(e["end"]) / 0.5, 0.0, 1.0) if done else 1.0
		var r := Rect2(8.0, y, w, h)
		_slab(r, YELLOW_HI if not done else GREEN_HI, a)
		draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(5.0 * k, h - 2.0)), Color(c.color, a))
		var fs := int((13 if mini else 16) * k)
		draw_string(fd, Vector2(r.position.x + 12.0 * k, r.position.y + 18.0 * k), c.code, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(WHITE, a))
		_txt(Vector2(r.position.x + 12.0 * k, r.position.y + 32.0 * k), phase, int(10 * k), Color(YELLOW_HI if not done else GREEN_HI, a))
		# Standzeit
		var shown := stat * u if not done else stat
		var ts := "%.1f s" % shown
		draw_string(fd, Vector2(r.position.x + 12.0 * k, r.end.y - 7.0 * k), ts, HORIZONTAL_ALIGNMENT_LEFT, -1, int((15 if mini else 19) * k), Color(WHITE, a))
		# Auto von oben mit vier Reifen
		var cw := (60.0 if mini else 84.0) * k
		var ch := h - 14.0 * k
		var cr := Rect2(r.end.x - cw - 12.0 * k, r.position.y + 7.0 * k, cw, ch)
		var body := Rect2(cr.position + Vector2(cw * 0.18, ch * 0.32), Vector2(cw * 0.64, ch * 0.36))
		draw_rect(body, Color(c.color, a))
		draw_rect(Rect2(body.end.x, body.position.y + body.size.y * 0.3, cw * 0.1, body.size.y * 0.4), Color(c.color, a))
		var tr := minf(ch * 0.2, 9.0 * k)
		var spots := [Vector2(0.24, 0.16), Vector2(0.76, 0.16), Vector2(0.24, 0.84), Vector2(0.76, 0.84)]
		for i in 4:
			var swap_at := 0.15 + 0.2 * float(i)
			var changed := done or u > swap_at
			var comp: int = int(e["new"]) if changed else int(e["old"])
			var pop := 1.0
			if changed and not done and u < swap_at + 0.12:
				pop = 1.0 + 0.5 * sin((u - swap_at) / 0.12 * PI)
			var cdv: Dictionary = RaceSim.COMPOUNDS[comp]
			var pc := cr.position + Vector2(cw * spots[i].x, ch * spots[i].y)
			draw_circle(pc, tr * pop, Color(cdv["color"], a))
			draw_circle(pc, tr * pop * 0.55, Color(0.06, 0.07, 0.1, a))
		y = r.end.y + 6.0


## Fahrerkarte unten links: Foto, Position, Kürzel, Tempo, Reifen, Batterie, Abstand, Sektoren.
func _draw_card(c) -> void:
	var k := _k()
	var f := U.font(false)
	var fb := U.font(true)
	var fd := _fd()
	var th := (22.0 if compact else 26.0)
	var w := 340.0 * k
	var h := 96.0 * k
	var r := Rect2(8.0, size.y - th - h - 6.0, w, h)
	_slab(r, _team_col(c))
	var rk: Array = sim.ranking()
	var pos: int = rk.find(c) + 1
	# Teamfarben-Keil links
	draw_colored_polygon(PackedVector2Array([r.position + Vector2(0, 2), r.position + Vector2(6.0 * k, 2), Vector2(r.position.x + 6.0 * k, r.end.y), Vector2(r.position.x, r.end.y)]), c.color)
	var x := r.position.x + 12.0 * k
	var y := r.position.y + 8.0 * k
	var ph := 34.0 * k
	DriverPhoto.draw_into(self, Rect2(x, y, ph, ph), c.driver_id)
	x += ph + 6.0 * k
	_tag(Rect2(x, y + 3.0 * k, 38.0 * k, ph - 6.0 * k), WHITE if pos > 1 else YELLOW_HI, "P%d" % pos, Color(0.05, 0.05, 0.08), int(16 * k))
	x += 44.0 * k
	draw_string(fd, Vector2(x, y + ph * 0.5 + 8.0 * k), c.code, HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * k), U.ACCENT.lightened(0.2) if c.is_player else WHITE)
	if not compact:
		draw_string(f, Vector2(x + 62.0, y + ph * 0.5 + 6.0), c.driver_name.get_slice(" ", c.driver_name.get_slice_count(" ") - 1), HORIZONTAL_ALIGNMENT_LEFT, 90.0, 12, DIM)
	# Tempo rechts oben
	var kmh := int(c.speed * 3.6) if c.state == 1 else 0
	var rx := r.end.x - 14.0 * k
	_txt_r(Vector2(rx, y + ph * 0.5 + 9.0 * k), "%d" % kmh, int(24 * k), WHITE, fd)
	_txt_r(Vector2(rx, y + ph * 0.5 + 21.0 * k), "KM/H", int(9 * k + 1), DIM)
	# Zeile 2: Reifen, Batterie, Abstand nach vorn
	var y2 := y + ph + 13.0 * k
	_tyre(Vector2(r.position.x + 22.0 * k, y2), c.compound, 9.0 * k)
	_txt(Vector2(r.position.x + 36.0 * k, y2 + 5.0 * k), "%d RD." % c.tyre_age_laps, int(12 * k), WHITE)
	var bx := r.position.x + 92.0 * k
	if sim.has_ers():
		var bw := 74.0 * k
		draw_rect(Rect2(bx, y2 - 3.0 * k, bw, 6.0 * k), Color(1, 1, 1, 0.12))
		var ec: Color = GREEN_HI if c.ers > 30.0 else (YELLOW_HI if c.ers > 10.0 else RED_HI)
		draw_rect(Rect2(bx, y2 - 3.0 * k, bw * clampf(c.ers / 100.0, 0.0, 1.0), 6.0 * k), ec)
		_txt(Vector2(bx + bw + 6.0 * k, y2 + 5.0 * k), "ERS %d%%" % int(c.ers), int(11 * k), DIM)
	else:
		_txt(Vector2(bx, y2 + 5.0 * k), "MOTOR %s" % str(RaceSim.ENG_NAMES[c.eng_mode]).to_upper(), int(11 * k), DIM)
	var ahead = sim.car_ahead(c)
	if ahead != null and c.state == 1:
		_txt_r(Vector2(rx, y2 + 5.0 * k), "%s +%.1f" % [ahead.code, c.gap_ahead], int(12 * k), GREEN_HI if c.gap_ahead < 1.0 else WHITE)
	# Zeile 3: Sektoren als schmale Balken mit Zeit darüber
	var sy := r.end.y - 9.0 * k
	var sw := (w - 30.0 * k) / 3.0
	for s in 3:
		var sx := r.position.x + 12.0 * k + float(s) * (sw + 3.0 * k)
		var col := _sector_col(int(c.sec_cols[s]))
		draw_rect(Rect2(sx, sy, sw - 6.0 * k, 4.0 * k), col)
		var tt: float = float(c.sec_times[s])
		_txt(Vector2(sx, sy - 4.0 * k), "S%d %s" % [s + 1, ("%.1f" % tt) if (tt > 0.0 and int(c.sec_cols[s]) > 0) else "--"], int(11 * k), WHITE if int(c.sec_cols[s]) > 0 else DIM, f)


## Rundenzeit oben rechts, gleitet von rechts herein. Rückgabe: Unterkante.
func _draw_toast(top: float) -> float:
	var k := _k()
	var fd := _fd()
	var c = _toast["car"]
	var a := clampf(_toast_t / 0.5, 0.0, 1.0)
	var e := _ease_in(_toast_age)
	var col: Color = _toast["col"]
	var mini := _mini()
	var h := (24.0 if mini else 32.0) * k
	var w := minf((150.0 if mini else 300.0) * k, size.x - 20.0)
	var r := Rect2(size.x - w - 8.0 + (1.0 - e) * (w + 16.0), top, w, h)
	_slab(r, col if mini else _team_col(c), a)
	draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(5.0 * k, h - 2.0)), Color(c.color, a))
	var fs0 := int((15 if mini else 19) * k)
	draw_string(fd, Vector2(r.position.x + 12.0 * k, r.position.y + h * 0.5 + fs0 * 0.37), c.code, HORIZONTAL_ALIGNMENT_LEFT, -1, fs0, Color(WHITE, a))
	# kleine Karte: nur Kürzel und Zeit, die Art der Runde zeigt die Farbe der Zeit
	draw_string(fd, Vector2(r.position.x + (56.0 if mini else 70.0) * k, r.position.y + h * 0.5 + fs0 * 0.37), str(_toast["time"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs0, Color(col if mini else WHITE, a))
	if mini:
		return r.end.y
	var tag: String = _toast["tag"]
	var fs := int(11 * k)
	var tw := U.font(true).get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 18.0 * k
	var tr := Rect2(r.end.x - tw - 16.0 * k, r.position.y + 7.0 * k, tw, h - 14.0 * k)
	_tag(tr, Color(col, a), tag, Color(0.05, 0.05, 0.08, a), fs, U.font(true))
	return r.end.y


## Zweikampf: [P vorne][Kürzel] Abstand [Kürzel][P hinten], Reifen beider, DRS.
func _draw_battle(top: float) -> void:
	var k := _k()
	var fd := _fd()
	var a: RaceSim.RaceCar = _battle["a"]
	var b: RaceSim.RaceCar = _battle["b"]
	var fade := clampf(_battle_t / 0.5, 0.0, 1.0)
	var e := _ease_in(_battle_age)
	if _mini():
		# schmal: [P] AAA  0.4 s  BBB
		var mh := 24.0 * k
		var mw := minf(178.0 * k, size.x - 20.0)
		var mr := Rect2(size.x - mw - 8.0 + (1.0 - e) * 40.0, top, mw, mh)
		var ma := fade * e
		_slab(mr, U.ACCENT, ma)
		var mfs := int(14 * k)
		var my := mr.position.y + mh * 0.5 + mfs * 0.37
		_tag(Rect2(mr.position.x + 4.0 * k, mr.position.y + 5.0 * k, 26.0 * k, mh - 8.0 * k), Color(WHITE, ma), "P%d" % int(_battle["pos"]), Color(0.05, 0.05, 0.08, ma), int(11 * k))
		draw_rect(Rect2(mr.position.x + 33.0 * k, mr.position.y + 6.0 * k, 3.0 * k, mh - 10.0 * k), Color(a.color, ma))
		draw_string(fd, Vector2(mr.position.x + 39.0 * k, my), a.code, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs, Color(WHITE, ma))
		var mg := "%.1f s" % b.gap_ahead
		var mgw := fd.get_string_size(mg, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs).x
		draw_string(fd, Vector2(mr.position.x + mw * 0.58 - mgw * 0.5, my), mg, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs, Color(GREEN_HI if b.gap_ahead < 1.0 else WHITE, ma))
		_txt_r(Vector2(mr.end.x - 8.0 * k, my), b.code, mfs, Color(WHITE, ma), fd)
		var bw := fd.get_string_size(b.code, HORIZONTAL_ALIGNMENT_LEFT, -1, mfs).x
		draw_rect(Rect2(mr.end.x - 14.0 * k - bw, mr.position.y + 6.0 * k, 3.0 * k, mh - 10.0 * k), Color(b.color, ma))
		return
	var h := 34.0 * k
	var w := minf(340.0 * k, size.x - 20.0)
	var r := Rect2(size.x - w - 8.0 + (1.0 - e) * 60.0, top, w, h)
	var al := fade * e
	_slab(r, U.ACCENT, al)
	var cy := r.position.y + h * 0.5
	var fs := int(16 * k)
	var bh := h - 12.0 * k
	_txt(Vector2(r.position.x + 8.0 * k, r.position.y + 12.0 * k), "ZWEIKAMPF", int(9 * k + 1), Color(U.ACCENT.lightened(0.2), al))
	var x := r.position.x + 8.0 * k
	var by := r.position.y + 14.0 * k
	_tag(Rect2(x, by, 30.0 * k, bh - 4.0 * k), Color(WHITE, al), "P%d" % int(_battle["pos"]), Color(0.05, 0.05, 0.08, al), int(12 * k))
	draw_rect(Rect2(x + 34.0 * k, by, 3.0 * k, bh - 4.0 * k), Color(a.color, al))
	draw_string(fd, Vector2(x + 41.0 * k, by + bh * 0.5 + 3.0 * k), a.code, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(WHITE, al))
	_tyre(Vector2(x + 94.0 * k, by + (bh - 4.0 * k) * 0.5), a.compound, 7.0 * k)
	var x2 := r.end.x - 150.0 * k
	# Abstand zwischen den beiden Fahrern
	var gcol := GREEN_HI if b.gap_ahead < 1.0 else WHITE
	var gt := "%.1f s" % b.gap_ahead
	var gw := fd.get_string_size(gt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var gx := (x + 101.0 * k + x2 - 7.0 * k) * 0.5
	draw_string(fd, Vector2(gx - gw * 0.5, cy + 6.0 * k), gt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(gcol, al))
	# hinten
	_tyre(Vector2(x2, by + (bh - 4.0 * k) * 0.5), b.compound, 7.0 * k)
	draw_rect(Rect2(x2 + 12.0 * k, by, 3.0 * k, bh - 4.0 * k), Color(b.color, al))
	draw_string(fd, Vector2(x2 + 19.0 * k, by + bh * 0.5 + 3.0 * k), b.code, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(WHITE, al))
	_tag(Rect2(x2 + 68.0 * k, by, 30.0 * k, bh - 4.0 * k), Color(WHITE, al), "P%d" % (int(_battle["pos"]) + 1), Color(0.05, 0.05, 0.08, al), int(12 * k))
	if b.drs:
		_tag(Rect2(r.end.x - 48.0 * k, by, 34.0 * k, bh - 4.0 * k), Color(GREEN_HI, al), "DRS", Color(0.03, 0.1, 0.05, al), int(11 * k), U.font(true))


## Mini-Zeitentafel links (nur auf der großen Karte): Top 10 mit Abstand zum Vordermann.
func _draw_tower() -> void:
	var k := _k()
	var fd := _fd()
	var f := U.font(true)
	var rk: Array = sim.ranking()
	var n := mini(10, rk.size())
	var rh := 17.0 * k
	var w := 128.0 * k
	var th := (22.0 if compact else 26.0)
	var card_top := size.y - th - 96.0 * k - 12.0
	var x := 8.0
	var y := 40.0 * k
	var avail := card_top - y - 18.0 * k if selected != null else size.y - th - y - 24.0
	n = mini(n, int(avail / rh))
	if n < 3:
		return
	draw_rect(Rect2(x, y, w, 16.0 * k), Color(U.DARK, 0.92))
	draw_rect(Rect2(x, y + 16.0 * k - 2.0, w, 2.0), U.ACCENT)
	var lap: int = sim.leader_lap()
	_txt(Vector2(x + 6.0 * k, y + 12.0 * k), "RUNDE %d/%d" % [lap, sim.laps], int(10 * k + 1), WHITE)
	y += 16.0 * k
	for i in n:
		var c = rk[i]
		var ry := y + float(i) * rh
		draw_rect(Rect2(x, ry, w, rh), Color(GLASS, 0.86 if i % 2 == 0 else 0.78))
		if c.is_player:
			draw_rect(Rect2(x, ry, w, rh), Color(U.ACCENT, 0.28))
		draw_string(fd, Vector2(x + 3.0 * k, ry + rh * 0.5 + 5.0 * k), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 20.0 * k, int(12 * k), WHITE)
		draw_rect(Rect2(x + 25.0 * k, ry + 3.0 * k, 3.0 * k, rh - 6.0 * k), c.color)
		draw_string(fd, Vector2(x + 32.0 * k, ry + rh * 0.5 + 5.0 * k), c.code, HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * k), U.ACCENT.lightened(0.2) if c.is_player else WHITE)
		var gt := ""
		var gc := DIM
		if c.state == 2:
			gt = "BOX"
			gc = YELLOW_HI
		elif c.state == 3:
			gt = "AUS"
			gc = RED_HI
		elif i == 0:
			gt = "Führt"
		else:
			gt = "+%.1f" % c.gap_ahead
			if c.gap_ahead < 1.0:
				gc = GREEN_HI
		_txt_r(Vector2(x + w - 6.0 * k, ry + rh * 0.5 + 4.0 * k), gt, int(11 * k), gc, f)


## Laufband unten: LIVE-Marke, Meldungen mit Punkt-Trennern, Positionswechsel mit Pfeilen.
func _draw_ticker() -> void:
	if _ticker.is_empty():
		return
	var f := U.font(true)
	var th := 22.0 if compact else 26.0
	var r := Rect2(0, size.y - th, size.x, th)
	draw_rect(r, Color(GLASS, 0.92))
	var fs := 12 if compact else 13
	var base := r.position.y + th * 0.5 + float(fs) * 0.36
	# Breite des ganzen Bands
	var items: Array = _ticker.slice(0, 8)
	var widths: Array = []
	var total := 0.0
	for it in items:
		var iw := _item_w(it, f, fs)
		widths.append(iw)
		total += iw + 26.0
	total += 60.0
	var off := fmod(_scroll, total)
	for rep in 3:
		var x := 84.0 - off + float(rep) * total
		for i in items.size():
			if x > size.x:
				break
			if x + float(widths[i]) > 76.0:
				_draw_item(items[i], x, base, f, fs, r.position.y, th)
			x += float(widths[i]) + 26.0
			draw_circle(Vector2(x - 13.0, r.position.y + th * 0.5), 2.0, Color(1, 1, 1, 0.25))
	# LIVE-Marke mit pulsierendem Punkt
	var lw := 70.0
	draw_rect(Rect2(0, r.position.y, lw, th), U.ACCENT)
	var pulse := 0.55 + 0.45 * sin(_t * 5.0)
	draw_circle(Vector2(14.0, r.position.y + th * 0.5), 3.5, Color(1, 1, 1, pulse))
	draw_string(_fd(), Vector2(24.0, base), "LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, U.ACCENT_INK)


func _item_w(it: Dictionary, f: Font, fs: int) -> float:
	var w := f.get_string_size(str(it["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if str(it["tag"]) != "":
		w += f.get_string_size(str(it["tag"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2).x + 14.0
	if int(it["dir"]) != 0:
		w += 14.0
	return w


func _draw_item(it: Dictionary, x: float, base: float, f: Font, fs: int, top: float, th: float) -> void:
	var d := int(it["dir"])
	if d != 0:
		var cy := top + th * 0.5
		var col := GREEN_HI if d > 0 else RED_HI
		if d > 0:
			draw_colored_polygon(PackedVector2Array([Vector2(x + 5, cy - 5), Vector2(x + 10, cy + 3), Vector2(x, cy + 3)]), col)
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(x + 5, cy + 5), Vector2(x + 10, cy - 3), Vector2(x, cy - 3)]), col)
		x += 14.0
	var tag := str(it["tag"])
	if tag != "":
		var tcol := YELLOW_HI if tag in ["SC", "BOX"] else (RED_HI if tag == "AUSFALL" else (PURPLE_HI if tag == "FL" else (Color("60a5fa") if tag == "WETTER" else DIM)))
		draw_string(f, Vector2(x, base), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2, tcol)
		x += f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2).x + 14.0
	draw_string(f, Vector2(x, base), str(it["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, WHITE)


## Startaufstellung vor dem Start: zwei versetzte Spalten wie in der TV-Grafik.
func _draw_grid() -> void:
	var k := _k()
	var fd := _fd()
	var f := U.font(false)
	var rk: Array = sim.grid_order()
	var rows := int(ceil(float(rk.size()) / 2.0))
	var w := minf(360.0 * k, size.x - 20.0)
	var th := (22.0 if compact else 26.0)
	var row_h := minf(17.0 * k, (size.y - th - 60.0 * k) / float(maxi(rows, 1)) - 1.0)
	var h := 30.0 * k + float(rows) * row_h + 10.0 * k
	var r := Rect2(8.0, size.y - th - h - 6.0, w, h)
	_slab(r, U.ACCENT)
	draw_string(fd, r.position + Vector2(12.0 * k, 21.0 * k), "STARTAUFSTELLUNG", HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * k), WHITE)
	for i in rk.size():
		var c = rk[i]
		var col := i % 2
		var row := i / 2
		var x := r.position.x + 12.0 * k + float(col) * (w * 0.5)
		var y := r.position.y + 28.0 * k + float(row) * row_h + (row_h * 0.45 if col == 1 else 0.0)
		draw_string(fd, Vector2(x, y + row_h * 0.75), str(i + 1), HORIZONTAL_ALIGNMENT_RIGHT, 20.0 * k, int(12 * k), DIM)
		draw_rect(Rect2(x + 25.0 * k, y + 2.0, 3.0 * k, row_h - 4.0), c.color)
		draw_string(fd, Vector2(x + 33.0 * k, y + row_h * 0.75), c.code, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * k), U.ACCENT.lightened(0.2) if c.is_player else WHITE)
		if c.grid_penalty > 0:
			draw_string(f, Vector2(x + 76.0 * k, y + row_h * 0.75), "-%d" % c.grid_penalty, HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * k), RED_HI)
		if c.forced_start >= 0:
			_tyre(Vector2(x + 116.0 * k, y + row_h * 0.5), c.forced_start, 6.0 * k)

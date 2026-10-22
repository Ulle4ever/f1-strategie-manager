extends Control
## Fahrer-Panel unter der Rennkarte (Stil Kommandostand): Kopfzeile mit Position, Fahrer, Abständen und DRS,
## daneben BOX; drei Spalten TEMPO (Reifen + Fahrstil), KRAFTSTOFF (Sprit + Lift & Coast) und ERS bzw. MOTOR
## (Batterie oder Motorverschleiß + Modus). Jede Spalte zeigt Wert, wie lange es noch hält, und antippbare Modi.
## vertical = schmale Spalte neben der Karte (Handy): Kopf mit BOX in einer Zeile, darunter die drei Bereiche gestapelt.

const U = preload("res://scripts/ui.gd")
const RaceSim = preload("res://scripts/race_sim.gd")
const DriverPhoto = preload("res://scripts/driver_photo.gd")

signal box_pressed(car)
signal plan_pressed(car)
signal switch_pressed(car)

const BG := Color("15171d")
const CELL := Color("22252d")
const CELL_HI := Color(0.18, 0.21, 0.28, 1.0)
const LINE := Color(1, 1, 1, 0.10)
const TXT := Color(0.94, 0.95, 0.97)
const DIM := Color(0.62, 0.66, 0.74)
const INFO_HI := Color(0.98, 0.80, 0.30)     # Hinweis bei laufendem Funkbefehl
const STYLE_SHORT := ["Schonen", "Ruhig", "Normal", "Zügig", "Angriff"]
const SHORT := {"Lift & Coast": "L&C", "Schonen": "Sch", "Normal": "Nor", "Angriff": "Ang", "Laden": "Lad", "Power": "Pow", "Ruhig": "Ruh", "Zügig": "Züg", "Sparen": "Spa"}

var sim = null
var car = null
var can_switch := false               # Kopfzeile zeigt einen Wechsel-Knopf zum anderen Auto
var vertical := false                 # schmale Spalte (Handy, neben der Karte)
var _t := 0.0
var _hits: Array = []                 # [{"r": Rect2, "act": String, "arg": int}]
var _box_style: StyleBoxFlat
var _cell_style: StyleBoxFlat


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var M := U.is_mobile()
	custom_minimum_size = Vector2(0, 96 if M else 128)
	_box_style = StyleBoxFlat.new()
	_box_style.bg_color = BG
	_box_style.set_corner_radius_all(8)
	_cell_style = StyleBoxFlat.new()
	_cell_style.bg_color = CELL
	_cell_style.set_corner_radius_all(5)


## Farbe des gewählten Segments: Teamfarbe, auf dunklem Grund notfalls aufgehellt.
func _seg_on() -> Color:
	var a := U.ACCENT
	while a.get_luminance() < 0.32:
		a = a.lightened(0.15)
	return a


func _process(delta: float) -> void:
	_t += delta
	if _t >= 0.25 and is_visible_in_tree():
		_t = 0.0
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	for h in _hits:
		if (h["r"] as Rect2).has_point(mb.position):
			_act(str(h["act"]), int(h["arg"]))
			accept_event()
			queue_redraw()
			return


func _act(act: String, arg: int) -> void:
	if sim == null or car == null:
		return
	var c = car
	var racing: bool = c.state == RaceSim.State.RACING
	match act:
		"box":
			box_pressed.emit(c)
		"plan":
			plan_pressed.emit(c)
		"switch":
			switch_pressed.emit(c)
		"style":
			if not racing:
				return
			# ein laufender Funkbefehl (Push / Reifen managen) endet, der gewählte Fahrstil gilt dauerhaft
			if c.radio_kind in ["push", "manage"]:
				c.radio_kind = ""
			sim.set_style(c, arg)
		"fuel":
			if not racing:
				return
			sim.set_fuel_mode(c, arg)
		"energy":
			if sim.has_ers():
				sim.set_ers_mode(c, arg)
			else:
				sim.set_engine_mode(c, arg)


# ------------------------------------------------------------------ Zeichnen

func _txt(pos: Vector2, s: String, fs: int, col: Color, bold := true, width := -1.0) -> void:
	draw_string(U.font(bold), pos, s, HORIZONTAL_ALIGNMENT_LEFT, width, fs, col)


func _txt_r(right: Vector2, s: String, fs: int, col: Color, bold := true) -> void:
	var w := U.font(bold).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(U.font(bold), right - Vector2(w, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _col3(frac: float, warn: float, bad: float) -> Color:
	if frac <= bad:
		return Color(1.0, 0.36, 0.30)
	if frac <= warn:
		return Color(1.0, 0.70, 0.25)
	return Color(0.35, 0.86, 0.52)


func _bar(r: Rect2, frac: float, col: Color, mark := -1.0) -> void:
	draw_rect(r, Color(1, 1, 1, 0.10))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), col)
	if mark >= 0.0:
		draw_rect(Rect2(r.position.x + r.size.x * clampf(mark, 0.0, 1.0) - 1.0, r.position.y - 3.0, 2.0, r.size.y + 6.0), TXT)


## Segmentwahl (Modi): gewähltes Segment gelb, Rest dunkel; jedes Segment ist antippbar.
func _segments(r: Rect2, labels: Array, cur: int, act: String, enabled: bool, fs: int) -> void:
	var n := labels.size()
	var gap := 3.0
	var sw := (r.size.x - gap * float(n - 1)) / float(n)
	# passt eine Beschriftung nicht, werden alle Segmente der Gruppe einheitlich abgekürzt
	var short := false
	for l in labels:
		if U.font(true).get_string_size(str(l), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > sw - 4.0:
			short = true
	for i in n:
		var sr := Rect2(r.position.x + float(i) * (sw + gap), r.position.y, sw, r.size.y)
		var on := i == cur
		var so := _seg_on()
		draw_rect(sr, so if on else Color(1, 1, 1, 0.07))
		var col := (Color(0.08, 0.08, 0.10) if so.get_luminance() > 0.5 else Color.WHITE) if on else (DIM if enabled else Color(DIM, 0.4))
		var lab := str(labels[i])
		var lw := U.font(true).get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if short:
			lab = SHORT.get(lab, lab.substr(0, 3))       # schmale Spalte: Kurzform
			lw = U.font(true).get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_txt(Vector2(sr.position.x + (sw - lw) * 0.5, sr.position.y + sr.size.y * 0.5 + float(fs) * 0.36), lab, fs, col, true, sw)
		if enabled:
			_hits.append({"r": sr.grow(2.0), "act": act, "arg": i})


func _draw() -> void:
	_hits = []
	if sim == null or car == null:
		return
	var c = car
	var M := U.is_mobile()
	var w := size.x
	var h := size.y
	draw_style_box(_box_style, Rect2(Vector2.ZERO, size))
	var pad := 5.0 if M else 7.0
	if vertical:
		_draw_vertical(c, w, h, pad)
		return
	var head_h := 22.0 if M else 28.0
	_draw_head(c, Rect2(pad, pad, w - 2.0 * pad, head_h), true)
	# ---- Rumpf: BOX links, drei Spalten
	var by := pad + head_h + 2.0
	var bh := h - by - pad
	if c.state == RaceSim.State.OUT:
		_txt(Vector2(pad + 4.0, by + bh * 0.5 + 5.0), "Ausgefallen: %s" % c.out_reason, 13 if M else 15, Color(1.0, 0.45, 0.4), true, w - 2.0 * pad)
		return
	var box_w := 76.0 if M else (84.0 if w < 640.0 else 104.0)
	_draw_box(c, Rect2(pad, by, box_w, bh), false)
	var gap := 5.0
	var cx := pad + box_w + gap
	var cw := (w - pad - cx - gap * 2.0) / 3.0
	for k in 3:
		_draw_cell(c, k, Rect2(cx + float(k) * (cw + gap), by, cw, bh), not M)


## Schmale Spalte: Kopf (Position, Foto, Kürzel, BOX) oben, darunter TEMPO, KRAFTSTOFF, ERS/MOTOR gestapelt.
func _draw_vertical(c, w: float, h: float, pad: float) -> void:
	var head_h := 30.0
	var box_w := 74.0
	_draw_head(c, Rect2(pad, pad, w - 2.0 * pad - box_w - 4.0, head_h), false)
	if c.state == RaceSim.State.OUT:
		_txt(Vector2(pad + 4.0, pad + head_h + 20.0), "Ausgefallen: %s" % c.out_reason, 13, Color(1.0, 0.45, 0.4), true, w - 2.0 * pad)
		return
	_draw_box(c, Rect2(w - pad - box_w, pad, box_w, head_h), true)
	var gap := 4.0
	var top := pad + head_h + gap
	var ch := (h - top - pad - gap * 2.0) / 3.0
	for k in 3:
		_draw_cell(c, k, Rect2(pad, top + float(k) * (ch + gap), w - 2.0 * pad, ch), false)


## Kopf: Teamfarbe, Positionsfeld, Foto, Kürzel; mit full auch Name, DRS, Abstände und Wechsel-Knopf.
func _draw_head(c, r: Rect2, full: bool) -> void:
	var M := U.is_mobile()
	var fs_s := 10 if M else 11
	var fs_v := 13 if M else 15
	var fs_i := 10 if M else 12
	var racing: bool = c.state == RaceSim.State.RACING
	var rk: Array = sim.ranking()
	var pos: int = rk.find(c) + 1
	var hh := r.size.y - 4.0
	var x := r.position.x
	var y := r.position.y
	draw_rect(Rect2(x, y, 4, hh), c.color)
	x += 9.0
	# Positionsfeld schräg, weiß
	var pw0 := 32.0 if M else 38.0
	var sk := hh * 0.25
	draw_colored_polygon(PackedVector2Array([Vector2(x + sk, y), Vector2(x + pw0, y), Vector2(x + pw0 - sk, y + hh), Vector2(x, y + hh)]), TXT)
	var ps := "P%d" % pos if c.state != RaceSim.State.OUT else "AUS"
	var fd := U.display_font()
	var pw := fd.get_string_size(ps, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_v).x
	draw_string(fd, Vector2(x + (pw0 - pw) * 0.5, y + hh * 0.5 + float(fs_v) * 0.36), ps, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_v, Color(0.08, 0.08, 0.1))
	x += pw0 + 6.0
	DriverPhoto.draw_into(self, Rect2(x, y, hh, hh), c.driver_id)
	x += hh + 5.0
	var base_y := y + hh * 0.5 + float(fs_v + 2) * 0.36
	draw_string(fd, Vector2(x, base_y), c.code, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_v + 2, c.color.lightened(0.35))
	x += fd.get_string_size(c.code, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_v + 2).x + 7.0
	var right := r.end.x
	if not full:
		# schmale Spalte: Abstand zum Vordermann unter dem Kürzel ist zu eng, daher rechts klein
		var ahead = sim.car_ahead(c)
		if ahead != null and (racing or c.state == RaceSim.State.PIT) and right - x > 40.0:
			_txt_r(Vector2(right, base_y), "+%.1f" % c.gap_ahead, fs_i, DIM)
		if can_switch:
			# Wechsel per Antippen auf Kopf (Foto/Kürzel) oder das Pfeilsymbol
			var sx := x
			var sy := y + hh * 0.5
			draw_rect(Rect2(sx - 2.0, y, 20.0, hh), Color(1, 1, 1, 0.1))
			draw_line(Vector2(sx + 2.0, sy - 3.0), Vector2(sx + 14.0, sy - 3.0), TXT, 1.5)
			draw_colored_polygon(PackedVector2Array([Vector2(sx + 16.0, sy - 3.0), Vector2(sx + 12.0, sy - 6.5), Vector2(sx + 12.0, sy + 0.5)]), TXT)
			draw_line(Vector2(sx + 2.0, sy + 3.0), Vector2(sx + 14.0, sy + 3.0), TXT, 1.5)
			draw_colored_polygon(PackedVector2Array([Vector2(sx, sy + 3.0), Vector2(sx + 4.0, sy - 0.5), Vector2(sx + 4.0, sy + 6.5)]), TXT)
			_hits.append({"r": Rect2(r.position, Vector2(x + 20.0 - r.position.x, r.size.y)), "act": "switch", "arg": 0})
		return
	if not M:
		_txt(Vector2(x, base_y), c.driver_name, fs_i, DIM, false, 170.0)
		x += minf(U.font(false).get_string_size(c.driver_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_i).x, 170.0) + 10.0
	if can_switch:
		var sr := Rect2(right - (58.0 if M else 70.0), y, 58.0 if M else 70.0, hh)
		draw_rect(sr, Color(1, 1, 1, 0.12))
		var st := "Wechsel"
		var stw := U.font(true).get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_s).x
		_txt(Vector2(sr.position.x + (sr.size.x - stw) * 0.5, sr.end.y - (5.0 if M else 6.0)), st, fs_s, TXT)
		_hits.append({"r": sr.grow(3.0), "act": "switch", "arg": 0})
		right = sr.position.x - 8.0
	# DRS
	if sim.rules.get("drs", false):
		var dr := Rect2(right - 34.0, y + 1.0, 34.0, hh - 2.0)
		var on: bool = c.drs and racing
		draw_rect(dr, Color(0.35, 0.86, 0.52) if on else Color(1, 1, 1, 0.0))
		draw_rect(dr, Color(1, 1, 1, 0.35), false, 1.0)
		_txt(Vector2(dr.position.x + 6.0, dr.end.y - (4.0 if M else 5.0)), "DRS", fs_s, Color(0.06, 0.08, 0.1) if on else DIM)
		right = dr.position.x - 10.0
	# Abstände
	if racing or c.state == RaceSim.State.PIT:
		var ahead2 = sim.car_ahead(c)
		var behind = sim.car_behind(c)
		var gs := ""
		if ahead2 != null:
			gs += "%s +%.1f" % [ahead2.code, c.gap_ahead]
		if behind != null:
			gs += ("   " if gs != "" else "") + "%s -%.1f" % [behind.code, behind.gap_ahead]
		if gs != "" and right - x > 90.0:
			_txt_r(Vector2(right, base_y), gs, fs_i, DIM)


## BOX-Kachel in der Teamfarbe; compact = einzeilig (BOX + Plan nebeneinander).
func _draw_box(c, brect: Rect2, compact: bool) -> void:
	var M := U.is_mobile()
	var fs_s := 10 if M else 11
	var fs_v := 13 if M else 15
	var fs_i := 10 if M else 12
	var racing: bool = c.state == RaceSim.State.RACING
	var bcol := U.ACCENT
	var ink := U.ACCENT_INK
	var btxt := "BOX"
	var bsub := ""
	if c.state == RaceSim.State.PIT:
		bcol = Color(0.35, 0.38, 0.46)
		ink = Color.WHITE
		bsub = "in der Box"
	elif c.pit_requested:
		bcol = Color(0.86, 0.55, 0.08)
		ink = Color(0.08, 0.08, 0.1)
		btxt = "BOX!"
		bsub = "zurück"
	elif racing:
		bsub = RaceSim.COMPOUNDS[sim.suggest_comp(c)]["name"]
	var sk := minf(8.0, brect.size.y * 0.18)
	var poly := PackedVector2Array([brect.position + Vector2(sk, 0), Vector2(brect.end.x, brect.position.y), brect.end - Vector2(sk, 0), Vector2(brect.position.x, brect.end.y)])
	draw_colored_polygon(poly, bcol)
	var fd := U.display_font()
	var nxt := -1
	for s in c.plan:
		if int(s["lap"]) > c.floor_laps and (nxt < 0 or int(s["lap"]) < nxt):
			nxt = int(s["lap"])
	var pl := "Plan R%d" % nxt if nxt > 0 else "Plan"
	var box_w := brect.size.x
	var bh := brect.size.y
	if compact:
		# oben BOX, unten klein "Plan R.." als eigene Trefferfläche
		var tw0 := fd.get_string_size(btxt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_v + 1).x
		draw_string(fd, Vector2(brect.position.x + (box_w - tw0) * 0.5, brect.position.y + bh * 0.5), btxt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_v + 1, ink)
		var plw0 := U.font(true).get_string_size(pl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_s - 1).x
		_txt(Vector2(brect.position.x + (box_w - plw0) * 0.5, brect.end.y - 3.0), pl, fs_s - 1, Color(ink, 0.85))
		_hits.append({"r": Rect2(brect.position.x, brect.position.y + bh * 0.58, box_w, bh * 0.42).grow(2.0), "act": "plan", "arg": 0})
		_hits.append({"r": Rect2(brect.position, Vector2(box_w, bh * 0.58)).grow(2.0), "act": "box", "arg": 0})
		return
	var tw := fd.get_string_size(btxt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_v + 5).x
	draw_string(fd, Vector2(brect.position.x + (box_w - tw) * 0.5, brect.position.y + bh * 0.48), btxt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_v + 5, ink)
	if bsub != "":
		var sw2 := U.font(false).get_string_size(bsub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_i).x
		_txt(Vector2(brect.position.x + (box_w - sw2) * 0.5, brect.position.y + bh * 0.48 + float(fs_i) + 5.0), bsub, fs_i, Color(ink, 0.9), false)
	# Plan-Zeile unten in der Box-Kachel
	var pr := Rect2(brect.position.x + 6.0, brect.end.y - (17.0 if M else 21.0), box_w - 12.0, 14.0 if M else 18.0)
	draw_rect(pr, Color(0, 0, 0, 0.25))
	var plw := U.font(true).get_string_size(pl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_s).x
	_txt(Vector2(pr.position.x + (pr.size.x - plw) * 0.5, pr.end.y - (3.0 if M else 4.0)), pl, fs_s, Color.WHITE)
	_hits.append({"r": pr.grow(2.0), "act": "plan", "arg": 0})
	_hits.append({"r": Rect2(brect.position, Vector2(box_w, bh - pr.size.y - 4.0)), "act": "box", "arg": 0})


## Ein Bereich: 0 = TEMPO (Reifen + Fahrstil), 1 = KRAFTSTOFF, 2 = ERS bzw. MOTOR. bar = Füllbalken zeigen.
func _draw_cell(c, k: int, r: Rect2, bar: bool) -> void:
	var M := U.is_mobile()
	var fs_s := 10 if M else 11
	var fs_v := 13 if M else 15
	var fs_i := 10 if M else 12
	var racing: bool = c.state == RaceSim.State.RACING
	draw_style_box(_cell_style, r)
	var ip := 6.0 if M else 8.0
	var seg_h := clampf(r.size.y * 0.36, 16.0, 20.0 if M else 24.0)
	var row1 := r.position.y + (13.0 if M else 17.0)
	var row2 := r.position.y + (26.0 if M else 37.0)
	if r.size.y >= 70.0:
		row2 = r.position.y + 30.0
	var barr := r.position.y + (36.0 if M else 44.0)
	var seg_y := r.end.y - seg_h - (3.0 if M else 6.0)
	var iw := r.size.x - 2.0 * ip
	var fd := U.display_font()
	match k:
		0:
			var cd: Dictionary = RaceSim.COMPOUNDS[c.compound]
			var life: float = sim.life_eff(c.compound)
			var rest := clampf(1.0 - c.tyre_wear / life, 0.0, 1.0)
			var holds := int(maxf(0.0, (life - c.tyre_wear) / maxf(sim.wear_rate_now(c), 0.2)))
			var tcol := _col3(rest, 0.35, 0.15)
			_txt(Vector2(r.position.x + ip, row1), "TEMPO", fs_s, DIM)
			var dx := r.position.x + ip + (46.0 if M else 52.0)
			draw_circle(Vector2(dx, row1 - 4.0), 5.0, cd["color"])
			draw_arc(Vector2(dx, row1 - 4.0), 5.0, 0, TAU, 16, Color(0, 0, 0, 0.5), 1.0)
			# Reifentemperatur: blau zu kalt, grün im Fenster, rot zu heiß
			var ts: int = sim.tyre_temp_state(c)
			var tempc := Color(0.45, 0.70, 1.0) if ts < 0 else (Color(1.0, 0.42, 0.30) if ts > 0 else Color(0.35, 0.86, 0.52))
			var rs := "%d %%" % int(rest * 100.0)
			var rx := r.end.x - ip - fd.get_string_size(rs, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_v).x
			var tt := ("%d°" if r.size.x < 170.0 else "%d°C") % int(round(c.tyre_temp))
			if dx + 9.0 + U.font(true).get_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_i).x < rx - 4.0:
				_txt(Vector2(dx + 9.0, row1), tt, fs_i, tempc)
			draw_string(fd, Vector2(rx, row1 + 1.0), rs, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_v, tcol)
			var tinfo := "hält ~%d Rd. · Alter %d" % [holds, c.tyre_age_laps]
			if ts > 0:
				tinfo = "zu heiß! hält ~%d Rd." % holds
			elif ts < 0 and c.tyre_age_laps >= 2:
				tinfo = "zu kalt · hält ~%d Rd." % holds
			if U.font(false).get_string_size(tinfo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_i).x > iw:
				tinfo = ("zu heiß! ~%d Rd." if ts > 0 else ("zu kalt · ~%d Rd." if ts < 0 and c.tyre_age_laps >= 2 else "hält ~%d Rd.")) % holds
			if c.radio_kind == "push":
				tinfo = "Push: noch %d Rd." % maxi(0, c.radio_until - c.floor_laps)
			elif c.radio_kind == "manage":
				tinfo = "Reifen managen: noch %d Rd." % maxi(0, c.radio_until - c.floor_laps)
			_txt(Vector2(r.position.x + ip, row2), tinfo, fs_i, INFO_HI if c.radio_kind != "" else (tempc if ts != 0 and (ts > 0 or c.tyre_age_laps >= 2) else TXT), false, iw)
			if bar:
				_bar(Rect2(r.position.x + ip, barr, iw, 4.0), rest, tcol)
			_segments(Rect2(r.position.x + ip, seg_y, iw, seg_h), STYLE_SHORT, c.style, "style", racing, fs_s)
		1:
			var rng_l: float = sim.fuel_range(c)
			var need: float = sim.fuel_need(c)
			var delta := rng_l - need
			var fcol := Color(0.35, 0.86, 0.52) if delta >= 0.3 else (Color(1.0, 0.70, 0.25) if delta >= 0.0 else Color(1.0, 0.36, 0.30))
			_txt(Vector2(r.position.x + ip, row1), "KRAFTSTOFF", fs_s, DIM)
			var kg := "%d kg" % int(round(c.fuel))
			draw_string(fd, Vector2(r.end.x - ip - fd.get_string_size(kg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_v).x, row1 + 1.0), kg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_v, TXT)
			var finfo := "Reserve %+.1f Rd. · reicht %d" % [delta, int(rng_l)]
			if U.font(false).get_string_size(finfo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_i).x > iw:
				finfo = "Reserve %+.1f Rd." % delta
			if c.lico:
				finfo = "L&C noch %d Rd. · %+.1f" % [maxi(0, c.radio_until - c.floor_laps), delta]
			_txt(Vector2(r.position.x + ip, row2), finfo, fs_i, fcol, false, iw)
			if bar:
				var cap: float = sim.fuel_cap()
				var need_kg: float = need * sim.burn_now(c) + RaceSim.FUEL_RESERVE
				_bar(Rect2(r.position.x + ip, barr, iw, 4.0), c.fuel / cap, fcol, need_kg / cap)
			_segments(Rect2(r.position.x + ip, seg_y, iw, seg_h), RaceSim.FUEL_MODE_NAMES, c.fuel_mode, "fuel", racing, fs_s)
		2:
			if sim.has_ers():
				var e: float = c.ers
				var ecol := _col3(e / 100.0, 0.30, 0.10)
				_txt(Vector2(r.position.x + ip, row1), "ERS", fs_s, DIM)
				var es := "%d %%" % int(e)
				draw_string(fd, Vector2(r.end.x - ip - fd.get_string_size(es, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_v).x, row1 + 1.0), es, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_v, ecol)
				var rate: float = RaceSim.ERS_RATE[c.ers_mode]
				var einfo := "hält den Stand"
				if rate > 0.5:
					einfo = "voll in ~%d Rd." % int(ceil((100.0 - e) / rate)) if e < 99.0 else "Batterie voll"
				elif rate < -0.5:
					einfo = "leer in ~%d Rd." % int(e / -rate) if e > 1.0 else "Batterie leer"
				_txt(Vector2(r.position.x + ip, row2), einfo, fs_i, TXT, false, iw)
				if bar:
					_bar(Rect2(r.position.x + ip, barr, iw, 4.0), e / 100.0, ecol)
				_segments(Rect2(r.position.x + ip, seg_y, iw, seg_h), RaceSim.ERS_NAMES, c.ers_mode, "energy", racing, fs_s)
			else:
				var wf := clampf(1.0 - c.engine_wear, 0.0, 1.0)
				var mcol := _col3(wf, 0.35, 0.15)
				_txt(Vector2(r.position.x + ip, row1), "MOTOR", fs_s, DIM)
				var ms := "%d %%" % int(wf * 100.0)
				draw_string(fd, Vector2(r.end.x - ip - fd.get_string_size(ms, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_v).x, row1 + 1.0), ms, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_v, mcol)
				var minfo: String = ["weniger Risiko, spart Sprit", "Standard", "schneller, Risiko x2"][c.eng_mode]
				_txt(Vector2(r.position.x + ip, row2), minfo, fs_i, TXT, false, iw)
				if bar:
					_bar(Rect2(r.position.x + ip, barr, iw, 4.0), wf, mcol)
				_segments(Rect2(r.position.x + ip, seg_y, iw, seg_h), RaceSim.ENG_NAMES, c.eng_mode, "energy", racing, fs_s)

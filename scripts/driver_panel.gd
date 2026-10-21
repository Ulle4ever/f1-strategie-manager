extends Control
## Fahrer-Panel unter der Rennkarte (Stil Kommandostand): Kopfzeile mit Position, Fahrer, Abständen und DRS,
## daneben BOX; drei Spalten TEMPO (Reifen + Fahrstil), KRAFTSTOFF (Sprit + Lift & Coast) und ERS bzw. MOTOR
## (Batterie oder Motorverschleiß + Modus). Jede Spalte zeigt Wert, wie lange es noch hält, und antippbare Modi.

const U = preload("res://scripts/ui.gd")
const RaceSim = preload("res://scripts/race_sim.gd")
const DriverPhoto = preload("res://scripts/driver_photo.gd")

signal box_pressed(car)
signal plan_pressed(car)
signal switch_pressed(car)

const BG := Color(0.07, 0.08, 0.11, 0.94)
const CELL := Color(0.13, 0.15, 0.20, 1.0)
const CELL_HI := Color(0.18, 0.21, 0.28, 1.0)
const LINE := Color(1, 1, 1, 0.10)
const TXT := Color(0.94, 0.95, 0.97)
const DIM := Color(0.62, 0.66, 0.74)
const SEG_ON := Color(0.96, 0.78, 0.20)
const STYLE_SHORT := ["Schonen", "Ruhig", "Normal", "Zügig", "Angriff"]
const SHORT := {"Lift & Coast": "L&C", "Schonen": "Sch", "Normal": "Nor", "Angriff": "Ang", "Laden": "Lad", "Power": "Pow", "Ruhig": "Ruh", "Zügig": "Züg", "Sparen": "Spa"}

var sim = null
var car = null
var can_switch := false               # Kopfzeile zeigt einen Wechsel-Knopf zum anderen Auto
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
		draw_rect(sr, SEG_ON if on else Color(1, 1, 1, 0.07))
		var col := Color(0.08, 0.08, 0.10) if on else (DIM if enabled else Color(DIM, 0.4))
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
	var fs_s := 10 if M else 11        # Beschriftung
	var fs_v := 13 if M else 15        # Wert
	var fs_i := 10 if M else 12        # Info
	var pad := 5.0 if M else 7.0
	var head_h := 22.0 if M else 28.0
	var racing: bool = c.state == RaceSim.State.RACING

	# ---- Kopfzeile
	var rk: Array = sim.ranking()
	var pos: int = rk.find(c) + 1
	var x := pad
	draw_rect(Rect2(x, pad, 4, head_h - 4.0), c.color)
	x += 9.0
	var pb := Rect2(x, pad, 30.0 if M else 36.0, head_h - 4.0)
	draw_rect(pb, TXT)
	var ps := "P%d" % pos if c.state != RaceSim.State.OUT else "AUS"
	var pw := U.font(true).get_string_size(ps, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_v - 1).x
	_txt(Vector2(pb.position.x + (pb.size.x - pw) * 0.5, pb.end.y - (4.0 if M else 6.0)), ps, fs_v - 1, Color(0.08, 0.08, 0.1))
	x = pb.end.x + 6.0
	DriverPhoto.draw_into(self, Rect2(x, pad, head_h - 4.0, head_h - 4.0), c.driver_id)
	x += head_h + 4.0
	var base_y := pad + head_h * 0.5 + 4.0
	_txt(Vector2(x, base_y), c.code, fs_v + 1, c.color.lightened(0.35))
	x += U.font(true).get_string_size(c.code, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_v + 1).x + 7.0
	if not M:
		_txt(Vector2(x, base_y), c.driver_name, fs_i, DIM, false, 170.0)
		x += minf(U.font(false).get_string_size(c.driver_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_i).x, 170.0) + 10.0
	var right := w - pad
	if can_switch:
		var sr := Rect2(right - (58.0 if M else 70.0), pad, 58.0 if M else 70.0, head_h - 4.0)
		draw_rect(sr, Color(1, 1, 1, 0.12))
		var st := "Wechsel"
		var stw := U.font(true).get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_s).x
		_txt(Vector2(sr.position.x + (sr.size.x - stw) * 0.5, sr.end.y - (5.0 if M else 6.0)), st, fs_s, TXT)
		_hits.append({"r": sr.grow(3.0), "act": "switch", "arg": 0})
		right = sr.position.x - 8.0
	# DRS
	if sim.rules.get("drs", false):
		var dr := Rect2(right - 34.0, pad + 1.0, 34.0, head_h - 6.0)
		var on: bool = c.drs and racing
		draw_rect(dr, Color(0.35, 0.86, 0.52) if on else Color(1, 1, 1, 0.0))
		draw_rect(dr, Color(1, 1, 1, 0.35), false, 1.0)
		_txt(Vector2(dr.position.x + 6.0, dr.end.y - (4.0 if M else 5.0)), "DRS", fs_s, Color(0.06, 0.08, 0.1) if on else DIM)
		right = dr.position.x - 10.0
	# Abstände
	if racing or c.state == RaceSim.State.PIT:
		var ahead = sim.car_ahead(c)
		var behind = sim.car_behind(c)
		var gs := ""
		if ahead != null:
			gs += "%s +%.1f" % [ahead.code, c.gap_ahead]
		if behind != null:
			gs += ("   " if gs != "" else "") + "%s -%.1f" % [behind.code, behind.gap_ahead]
		if gs != "" and right - x > 90.0:
			_txt_r(Vector2(right, base_y), gs, fs_i, DIM)

	# ---- Rumpf: BOX links, drei Spalten
	var by := pad + head_h + 2.0
	var bh := h - by - pad
	if c.state == RaceSim.State.OUT:
		_txt(Vector2(pad + 4.0, by + bh * 0.5 + 5.0), "Ausgefallen: %s" % c.out_reason, fs_v, Color(1.0, 0.45, 0.4), true, w - 2.0 * pad)
		return
	var box_w := 76.0 if M else (84.0 if w < 640.0 else 104.0)
	var brect := Rect2(pad, by, box_w, bh)
	var bcol := U.ACCENT
	var btxt := "BOX"
	var bsub := ""
	if c.state == RaceSim.State.PIT:
		bcol = Color(0.35, 0.38, 0.46)
		bsub = "in der Box"
	elif c.pit_requested:
		bcol = Color(0.86, 0.55, 0.08)
		btxt = "BOX!"
		bsub = "zurücknehmen"
	elif racing:
		bsub = RaceSim.COMPOUNDS[sim.suggest_comp(c)]["name"]
	draw_rect(brect, bcol)
	var tw := U.font(true).get_string_size(btxt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_v + 5).x
	_txt(Vector2(brect.position.x + (box_w - tw) * 0.5, brect.position.y + bh * 0.48), btxt, fs_v + 5, Color.WHITE)
	if bsub != "":
		var sw2 := U.font(false).get_string_size(bsub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_i).x
		_txt(Vector2(brect.position.x + (box_w - sw2) * 0.5, brect.position.y + bh * 0.48 + float(fs_i) + 5.0), bsub, fs_i, Color(1, 1, 1, 0.9), false)
	# Plan-Zeile unten in der Box-Kachel
	var nxt := -1
	for s in c.plan:
		if int(s["lap"]) > c.floor_laps and (nxt < 0 or int(s["lap"]) < nxt):
			nxt = int(s["lap"])
	var pl := "Plan R%d" % nxt if nxt > 0 else "Plan"
	var pr := Rect2(brect.position.x + 3.0, brect.end.y - (17.0 if M else 21.0), box_w - 6.0, 14.0 if M else 18.0)
	draw_rect(pr, Color(0, 0, 0, 0.25))
	var plw := U.font(true).get_string_size(pl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_s).x
	_txt(Vector2(pr.position.x + (pr.size.x - plw) * 0.5, pr.end.y - (3.0 if M else 4.0)), pl, fs_s, Color.WHITE)
	_hits.append({"r": pr.grow(2.0), "act": "plan", "arg": 0})
	_hits.append({"r": Rect2(brect.position, Vector2(box_w, bh - pr.size.y - 4.0)), "act": "box", "arg": 0})

	var gap := 5.0
	var cx := brect.end.x + gap
	var cw := (w - pad - cx - gap * 2.0) / 3.0
	var seg_h := 20.0 if M else 24.0
	var cells := [Rect2(cx, by, cw, bh), Rect2(cx + cw + gap, by, cw, bh), Rect2(cx + 2.0 * (cw + gap), by, cw, bh)]
	for r in cells:
		draw_style_box(_cell_style, r)
	var ip := 6.0 if M else 8.0
	var row1 := by + (14.0 if M else 17.0)
	var row2 := by + (30.0 if M else 37.0)
	var barr := by + (36.0 if M else 44.0)
	var seg_y := by + bh - seg_h - (4.0 if M else 6.0)

	# 1) TEMPO: Reifen und Fahrstil
	var r0: Rect2 = cells[0]
	var cd: Dictionary = RaceSim.COMPOUNDS[c.compound]
	var life: float = sim.life_eff(c.compound)
	var rest := clampf(1.0 - c.tyre_wear / life, 0.0, 1.0)
	var holds := int(maxf(0.0, (life - c.tyre_wear) / maxf(sim.wear_rate_now(c), 0.2)))
	var tcol := _col3(rest, 0.35, 0.15)
	_txt(Vector2(r0.position.x + ip, row1), "TEMPO", fs_s, DIM)
	draw_circle(Vector2(r0.position.x + ip + (46.0 if M else 52.0), row1 - 4.0), 5.0, cd["color"])
	draw_arc(Vector2(r0.position.x + ip + (46.0 if M else 52.0), row1 - 4.0), 5.0, 0, TAU, 16, Color(0, 0, 0, 0.5), 1.0)
	# Reifentemperatur: blau zu kalt, grün im Fenster, rot zu heiß
	var ts: int = sim.tyre_temp_state(c)
	var tempc := Color(0.45, 0.70, 1.0) if ts < 0 else (Color(1.0, 0.42, 0.30) if ts > 0 else Color(0.35, 0.86, 0.52))
	_txt(Vector2(r0.position.x + ip + (55.0 if M else 62.0), row1), ("%d°" if r0.size.x < 170.0 else "%d°C") % int(round(c.tyre_temp)), fs_i, tempc)
	_txt_r(Vector2(r0.end.x - ip, row1 + 1.0), "%d %%" % int(rest * 100.0), fs_v, tcol)
	var tinfo := "hält ~%d Rd. · Alter %d" % [holds, c.tyre_age_laps]
	if ts > 0:
		tinfo = "zu heiß! hält ~%d Rd." % holds
	elif ts < 0 and c.tyre_age_laps >= 2:
		tinfo = "zu kalt · hält ~%d Rd." % holds
	if U.font(false).get_string_size(tinfo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_i).x > r0.size.x - 2.0 * ip:
		tinfo = ("zu heiß! ~%d Rd." if ts > 0 else ("zu kalt · ~%d Rd." if ts < 0 and c.tyre_age_laps >= 2 else "hält ~%d Rd.")) % holds
	if c.radio_kind == "push":
		tinfo = "Push: noch %d Rd." % maxi(0, c.radio_until - c.floor_laps)
	elif c.radio_kind == "manage":
		tinfo = "Reifen managen: noch %d Rd." % maxi(0, c.radio_until - c.floor_laps)
	_txt(Vector2(r0.position.x + ip, row2), tinfo, fs_i, SEG_ON if c.radio_kind != "" else (tempc if ts != 0 and (ts > 0 or c.tyre_age_laps >= 2) else TXT), false, r0.size.x - 2.0 * ip)
	if not M:
		_bar(Rect2(r0.position.x + ip, barr, r0.size.x - 2.0 * ip, 4.0), rest, tcol)
	_segments(Rect2(r0.position.x + ip, seg_y, r0.size.x - 2.0 * ip, seg_h), STYLE_SHORT, c.style, "style", racing, fs_s)

	# 2) KRAFTSTOFF: Sprit, Reserve bis Stopp/Ziel, Lift & Coast
	var r1: Rect2 = cells[1]
	var rng_l: float = sim.fuel_range(c)
	var need: float = sim.fuel_need(c)
	var delta := rng_l - need
	var fcol := Color(0.35, 0.86, 0.52) if delta >= 0.3 else (Color(1.0, 0.70, 0.25) if delta >= 0.0 else Color(1.0, 0.36, 0.30))
	_txt(Vector2(r1.position.x + ip, row1), "KRAFTSTOFF", fs_s, DIM)
	_txt_r(Vector2(r1.end.x - ip, row1 + 1.0), "%d kg" % int(round(c.fuel)), fs_v, TXT)
	var finfo := "Reserve %+.1f Rd. · reicht %d" % [delta, int(rng_l)]
	if U.font(false).get_string_size(finfo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_i).x > r1.size.x - 2.0 * ip:
		finfo = "Reserve %+.1f Rd." % delta
	if c.lico:
		finfo = "L&C noch %d Rd. · %+.1f" % [maxi(0, c.radio_until - c.floor_laps), delta]
	_txt(Vector2(r1.position.x + ip, row2), finfo, fs_i, fcol, false, r1.size.x - 2.0 * ip)
	if not M:
		var cap: float = sim.fuel_cap()
		var need_kg: float = need * sim.burn_now(c) + RaceSim.FUEL_RESERVE
		_bar(Rect2(r1.position.x + ip, barr, r1.size.x - 2.0 * ip, 4.0), c.fuel / cap, fcol, need_kg / cap)
	_segments(Rect2(r1.position.x + ip, seg_y, r1.size.x - 2.0 * ip, seg_h), RaceSim.FUEL_MODE_NAMES, c.fuel_mode, "fuel", racing, fs_s)

	# 3) ERS ab 2014, davor MOTOR
	var r2: Rect2 = cells[2]
	if sim.has_ers():
		var e: float = c.ers
		var ecol := _col3(e / 100.0, 0.30, 0.10)
		_txt(Vector2(r2.position.x + ip, row1), "ERS", fs_s, DIM)
		_txt_r(Vector2(r2.end.x - ip, row1 + 1.0), "%d %%" % int(e), fs_v, ecol)
		var rate: float = RaceSim.ERS_RATE[c.ers_mode]
		var einfo := "hält den Stand"
		if rate > 0.5:
			einfo = "voll in ~%d Rd." % int(ceil((100.0 - e) / rate)) if e < 99.0 else "Batterie voll"
		elif rate < -0.5:
			einfo = "leer in ~%d Rd." % int(e / -rate) if e > 1.0 else "Batterie leer"
		_txt(Vector2(r2.position.x + ip, row2), einfo, fs_i, TXT, false, r2.size.x - 2.0 * ip)
		if not M:
			_bar(Rect2(r2.position.x + ip, barr, r2.size.x - 2.0 * ip, 4.0), e / 100.0, ecol)
		_segments(Rect2(r2.position.x + ip, seg_y, r2.size.x - 2.0 * ip, seg_h), RaceSim.ERS_NAMES, c.ers_mode, "energy", racing, fs_s)
	else:
		var wf := clampf(1.0 - c.engine_wear, 0.0, 1.0)
		var mcol := _col3(wf, 0.35, 0.15)
		_txt(Vector2(r2.position.x + ip, row1), "MOTOR", fs_s, DIM)
		_txt_r(Vector2(r2.end.x - ip, row1 + 1.0), "%d %%" % int(wf * 100.0), fs_v, mcol)
		var minfo: String = ["weniger Risiko, spart Sprit", "Standard", "schneller, Risiko x2"][c.eng_mode]
		_txt(Vector2(r2.position.x + ip, row2), minfo, fs_i, TXT, false, r2.size.x - 2.0 * ip)
		if not M:
			_bar(Rect2(r2.position.x + ip, barr, r2.size.x - 2.0 * ip, 4.0), wf, mcol)
		_segments(Rect2(r2.position.x + ip, seg_y, r2.size.x - 2.0 * ip, seg_h), RaceSim.ENG_NAMES, c.eng_mode, "energy", racing, fs_s)

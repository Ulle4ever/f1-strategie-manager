extends Control
## Cockpit-Leiste unter der Karte: Reifen, Sprit, Energie und die Abstände des gewählten Spielerautos auf einen Blick.

const U = preload("res://scripts/ui.gd")
const RaceSim = preload("res://scripts/race_sim.gd")

var sim = null
var car = null
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 34 if U.is_mobile() else 42)


func _process(delta: float) -> void:
	_t += delta
	if _t >= 0.25 and is_visible_in_tree():
		_t = 0.0
		queue_redraw()


func _gauge_col(frac: float, warn: float, bad: float) -> Color:
	if frac <= bad:
		return U.BAD
	if frac <= warn:
		return U.WARN
	return U.GOOD


func _draw() -> void:
	if sim == null or car == null:
		return
	var c = car
	var M := U.is_mobile()
	var f := U.font(false)
	var fb := U.font(true)
	var fs_cap := 10 if M else 11
	var fs_val := 11 if M else 13
	var w := size.x
	var code_w := 44.0 if M else 56.0
	draw_rect(Rect2(0, 3, 4, size.y - 6), c.color)
	draw_string(fb, Vector2(9, size.y * 0.5 + 6.0), c.code, HORIZONTAL_ALIGNMENT_LEFT, code_w, 15 if M else 18, U.TEXT)
	var gap := 8.0
	var secs := 4 if (w - code_w - 6.0 - gap * 3.0) / 4.0 >= 150.0 else 3
	var sw := (w - code_w - 6.0 - gap * float(secs - 1)) / float(secs)
	var x := code_w + 6.0
	var by := size.y - (13.0 if M else 15.0)
	var bh := 6.0 if M else 8.0
	var ty := (13.0 if M else 15.0)
	if c.state == RaceSim.State.OUT:
		draw_string(fb, Vector2(x, size.y * 0.5 + 5.0), "Ausgefallen: %s" % c.out_reason, HORIZONTAL_ALIGNMENT_LEFT, w - x, fs_val + 1, U.BAD)
		return
	# 1) Reifen
	var cd: Dictionary = RaceSim.COMPOUNDS[c.compound]
	var life: float = sim.life_eff(c.compound)
	var rest := clampf(1.0 - c.tyre_wear / life, 0.0, 1.0)
	var holds := int(maxf(0.0, (life - c.tyre_wear) / maxf(sim.wear_rate_now(c), 0.2)))
	var tc := _gauge_col(rest, 0.35, 0.15)
	draw_circle(Vector2(x + 5.0, ty - 4.0), 4.5, cd["color"])
	draw_string(fb, Vector2(x + 14.0, ty), "REIFEN", HORIZONTAL_ALIGNMENT_LEFT, -1, fs_cap, U.MUTED)
	var tv := "%d %% · %d Rd." % [int(rest * 100.0), holds]
	var tvw := fb.get_string_size(tv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_val).x
	draw_string(fb, Vector2(x + sw - tvw, ty), tv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_val, tc)
	draw_rect(Rect2(x, by, sw, bh), U.tint(0.10))
	draw_rect(Rect2(x, by, sw * rest, bh), tc)
	# nächster geplanter Stopp als Marke (in Runden verbleibender Haltbarkeit)
	var nxt := -1
	for s in c.plan:
		if int(s["lap"]) > c.floor_laps and (nxt < 0 or int(s["lap"]) < nxt):
			nxt = int(s["lap"])
	if nxt > 0:
		# Stoppmarke: so viel Reifen ist beim geplanten Stopp voraussichtlich noch übrig
		var run := float(nxt - c.floor_laps)
		var rest_at := clampf(rest - run * maxf(sim.wear_rate_now(c), 0.2) / life, 0.0, 1.0)
		draw_rect(Rect2(x + sw * rest_at - 1.0, by - 3.0, 2.0, bh + 6.0), U.TEXT)
	x += sw + gap
	# 2) Sprit
	var cap: float = sim.fuel_cap()
	var rng_l: float = sim.fuel_range(c)
	var need: float = sim.fuel_need(c)
	var fcol := U.GOOD if rng_l >= need + 0.3 else (U.WARN if rng_l >= need else U.BAD)
	var ffrac := clampf(c.fuel / cap, 0.0, 1.0)
	draw_string(fb, Vector2(x, ty), "SPRIT", HORIZONTAL_ALIGNMENT_LEFT, -1, fs_cap, U.MUTED)
	var fv := "%d kg · %d Rd." % [int(round(c.fuel)), int(rng_l)]
	var fvw := fb.get_string_size(fv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_val).x
	draw_string(fb, Vector2(x + sw - fvw, ty), fv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_val, fcol)
	draw_rect(Rect2(x, by, sw, bh), U.tint(0.10))
	draw_rect(Rect2(x, by, sw * ffrac, bh), fcol)
	var need_kg: float = need * sim.burn_now(c) + RaceSim.FUEL_RESERVE
	draw_rect(Rect2(x + sw * clampf(need_kg / cap, 0.0, 1.0) - 1.0, by - 3.0, 2.0, bh + 6.0), U.TEXT)
	x += sw + gap
	# 3) Energie: Batterie ab 2014, davor der Motor
	if sim.has_ers():
		var ec: Color = U.GOOD if c.ers > 30.0 else (U.WARN if c.ers > 10.0 else U.BAD)
		draw_string(fb, Vector2(x, ty), "BATTERIE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs_cap, U.MUTED)
		var ev := "%s  %d %%" % [RaceSim.ERS_NAMES[c.ers_mode], int(c.ers)]
		var evw := fb.get_string_size(ev, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_val).x
		draw_string(fb, Vector2(x + sw - evw, ty), ev, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_val, ec)
		draw_rect(Rect2(x, by, sw, bh), U.tint(0.10))
		draw_rect(Rect2(x, by, sw * clampf(c.ers / 100.0, 0.0, 1.0), bh), ec)
	else:
		var wear_f := clampf(1.0 - c.engine_wear, 0.0, 1.0)
		var mc := _gauge_col(wear_f, 0.35, 0.15)
		draw_string(fb, Vector2(x, ty), "MOTOR", HORIZONTAL_ALIGNMENT_LEFT, -1, fs_cap, U.MUTED)
		var mv := "%s  %d %%" % [RaceSim.ENG_NAMES[c.eng_mode], int(wear_f * 100.0)]
		var mvw := fb.get_string_size(mv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_val).x
		draw_string(fb, Vector2(x + sw - mvw, ty), mv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_val, mc)
		draw_rect(Rect2(x, by, sw, bh), U.tint(0.10))
		draw_rect(Rect2(x, by, sw * wear_f, bh), mc)
	x += sw + gap
	if secs < 4:
		return
	# 4) Abstände
	draw_string(fb, Vector2(x, ty), "ABSTAND", HORIZONTAL_ALIGNMENT_LEFT, -1, fs_cap, U.MUTED)
	var ahead = sim.car_ahead(c)
	var behind = sim.car_behind(c)
	var up := "P1" if ahead == null else "%s %.1f s" % [ahead.code, c.gap_ahead]
	var dn := "" if behind == null else "%s %.1f s" % [behind.code, behind.gap_ahead]
	draw_string(f, Vector2(x, by + bh + 1.0), "vor " + up, HORIZONTAL_ALIGNMENT_LEFT, sw * 0.5 + 6.0, fs_val - 1, U.TEXT)
	if dn != "":
		var dw := f.get_string_size("hinter " + dn, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_val - 1).x
		draw_string(f, Vector2(x + sw - dw, by + bh + 1.0), "hinter " + dn, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_val - 1, U.MUTED)

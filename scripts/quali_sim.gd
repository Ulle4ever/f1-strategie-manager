extends RefCounted
## Qualifying-Simulation: Q1/Q2/Q3 (ab 2006), Einzelrunden (2003-2005) bzw. 1-Stunden-Session (2000-2002).
## Läufe (Outlap, schnelle Runde, Inlap), Streckenentwicklung, Verkehr, Fehler, Regen, Ausscheiden, Strafen.

enum QState { GARAGE, OUT, ELIMINATED, CRASHED }
const DRY_COUNT := 3

class QCar:
	var car
	var is_player := false
	var auto := true
	var state := 0
	var eliminated := false
	var crashed := false
	var t_ready := 0.0
	var fly_start := 0.0
	var fly_end := -1.0
	var run_end := 0.0
	var run_start := 0.0
	var out_end := 0.0
	var comp := 0
	var risk := 1
	var best := 0.0
	var best_comp := -1
	var phase_best: Array = [0.0, 0.0, 0.0]
	var phase_comp: Array = [-1, -1, -1]
	var runs := 0
	var plan_runs := 2
	var next_go := 0.0
	var final_go := 0.0
	var last_lap := 0.0
	var note := ""
	var traffic := false

var sim
var track
var rng: RandomNumberGenerator
var year := 2024
var qcars: Array = []
var phases: Array = []
var phase_idx := -1
var time := 0.0
var sess_time := 0.0
var active := false
var closed := false
var finished := false
var events: Array = []
var tail: Array = []            # ausgeschiedene Autos, beste zuerst (hinter dem Feld des laufenden Abschnitts)
var laps_total := 0
var wet := 0.0
var rain := 0.0
var rain_start := -1.0
var rain_end := -1.0
var rain_peak := 0.0
var rain_chance := 0.08
var forecast_noise := 0.0
var rain_announced := false
var total_dur := 2700.0
var scale_time := 1.0
var out_lap_time := 100.0
var in_lap_time := 100.0
var gap_timer := 0.0


func setup(p_sim) -> void:
	sim = p_sim
	track = sim.track
	rng = sim.rng
	year = sim.year
	scale_time = track.lap_ref / 90.0
	out_lap_time = track.lap_ref * 1.3
	in_lap_time = track.lap_ref * 1.25
	qcars = []
	for c in sim.cars:
		var q := QCar.new()
		q.car = c
		q.is_player = c.is_player
		q.auto = not c.is_player
		qcars.append(q)
	_make_phases()
	_setup_weather()


func _make_phases() -> void:
	var n := qcars.size()
	phases = []
	if year >= 2006:
		var adv1 := n - int(ceil(float(n) / 4.0))
		phases.append({"name": "Q1", "dur": 1080.0, "advance": adv1, "max_runs": 99})
		phases.append({"name": "Q2", "dur": 900.0, "advance": mini(10, adv1), "max_runs": 99})
		phases.append({"name": "Q3", "dur": 720.0, "advance": 0, "max_runs": 99})
	elif year >= 2003:
		phases.append({"name": "Qualifying", "dur": 2400.0, "advance": 0, "max_runs": 1})
	else:
		phases.append({"name": "Qualifying", "dur": 3600.0, "advance": 0, "max_runs": 6})
	total_dur = 0.0
	for p in phases:
		total_dur += float(p["dur"]) + 300.0


func phase_name() -> String:
	if phase_idx < 0 or phase_idx >= phases.size():
		return ""
	return phases[phase_idx]["name"]


func time_left() -> float:
	if phase_idx < 0 or phase_idx >= phases.size():
		return 0.0
	return maxf(0.0, float(phases[phase_idx]["dur"]) - time)


func log_event(kind: String, text: String, q = null) -> void:
	events.append({"t": time, "kind": kind, "text": text, "player": q != null and q.is_player})


# ------------------------------------------------------------------ Wetter

func _setup_weather() -> void:
	rain_chance = float(sim.CLIMATE.get(track.id, 0.08))
	forecast_noise = rng.randf_range(-2.0, 2.0)
	if rng.randf() < rain_chance * 0.9:
		rain_peak = rng.randf_range(0.3, 0.95)
		var st := rng.randf_range(-0.05, 0.85) * total_dur
		if st < 0.0:
			wet = rng.randf_range(0.2, 0.7)
			rain = 0.25
			rain_start = -1.0
			rain_end = rng.randf_range(8.0, 25.0) * 60.0
			rain_announced = true
		else:
			rain_start = st
			rain_end = st + rng.randf_range(10.0, 30.0) * 60.0


func _update_weather(dt: float) -> void:
	sess_time += dt
	var target := 0.0
	if rain_end > 0.0 and sess_time >= rain_start and sess_time < rain_end:
		var u := (sess_time - rain_start) / maxf(rain_end - rain_start, 1.0)
		target = rain_peak * pow(sin(PI * clampf(u, 0.0, 1.0)), 0.7)
		if rain_start < 0.0:
			target = rain_peak * clampf(1.0 - sess_time / rain_end, 0.0, 1.0)
	rain = move_toward(rain, target, 0.015 * dt)
	if rain > 0.04:
		var wt := clampf(rain * 1.05, 0.0, 1.0)
		if wet < wt:
			wet += (wt - wet) * 0.006 * dt
		else:
			wet -= 0.0006 * dt
		if not rain_announced and rain > 0.1:
			rain_announced = true
			log_event("weather", "Es beginnt zu regnen!")
	else:
		wet -= 0.0007 * dt
	wet = clampf(wet, 0.0, 1.0)


func weather_text() -> String:
	var t := "Trocken"
	if rain > 0.6:
		t = "Starker Regen"
	elif rain > 0.25:
		t = "Regen"
	elif rain > 0.04:
		t = "Leichter Regen"
	elif wet > 0.05:
		t = "Strecke feucht"
	return "%s %d %%" % [t, int(wet * 100.0)]


func forecast_text() -> String:
	if rain_end < 0.0:
		return "kein Regen erwartet"
	if sess_time < rain_start:
		var m := (rain_start - sess_time) / 60.0 + forecast_noise
		if m < 30.0:
			return "Regen in ca. %d min" % maxi(1, int(m))
		return "Regen später möglich"
	if sess_time < rain_end:
		return "Regenende in ca. %d min" % maxi(1, int((rain_end - sess_time) / 60.0 + forecast_noise))
	return "bleibt trocken"


func track_evolution() -> float:
	var e := 0.15 + 0.85 * (1.0 - exp(-float(laps_total) / 60.0))
	if wet > 0.3:
		e = 0.2
	return e


# ------------------------------------------------------------------ Abschnitte

func start_next_phase() -> void:
	phase_idx += 1
	if phase_idx >= phases.size():
		finished = true
		active = false
		return
	var ph: Dictionary = phases[phase_idx]
	time = 0.0
	sess_time += 300.0 if phase_idx > 0 else 0.0
	closed = false
	active = true
	for q in qcars:
		if q.eliminated:
			continue
		q.state = QState.GARAGE
		q.crashed = false
		q.best = 0.0
		q.best_comp = -1
		q.runs = 0
		q.t_ready = 0.0
		q.fly_end = -1.0
		q.note = ""
		_plan_ai(q)
	log_event("info", "%s beginnt (%d Minuten)" % [ph["name"], int(float(ph["dur"]) / 60.0)])


func _plan_ai(q: QCar) -> void:
	var ph: Dictionary = phases[phase_idx]
	var dur: float = ph["dur"]
	var mr: int = ph["max_runs"]
	if mr == 1:
		q.plan_runs = 1
		q.next_go = rng.randf_range(10.0, dur * 0.75)
	elif mr <= 6:
		q.plan_runs = rng.randi_range(2, 4)
		q.next_go = rng.randf_range(30.0, 600.0)
	else:
		q.plan_runs = 2 if rng.randf() < 0.85 else 3
		q.next_go = rng.randf_range(20.0, 240.0) if ph["name"] != "Q3" else rng.randf_range(40.0, 200.0)
	q.final_go = dur - out_lap_time - rng.randf_range(5.0, 50.0)


func active_cars() -> Array:
	var out: Array = []
	for q in qcars:
		if not q.eliminated:
			out.append(q)
	return out


func rank_of(q: QCar) -> int:
	var arr := standings()
	return arr.find(q) + 1


## Rangliste: aktueller Abschnitt nach Bestzeit, danach die früher Ausgeschiedenen.
func standings() -> Array:
	var act: Array = active_cars()
	act.sort_custom(_best_less)
	var out: Array = act.duplicate()
	for q in tail:
		out.append(q)
	return out


func _best_less(a: QCar, b: QCar) -> bool:
	var ta: float = a.best if a.best > 0.0 else 1.0e9
	var tb: float = b.best if b.best > 0.0 else 1.0e9
	if ta == tb:
		return a.car.index < b.car.index
	return ta < tb


# ------------------------------------------------------------------ Ablauf

func can_send(q: QCar) -> bool:
	if not active or closed or q.eliminated or q.crashed or q.state != QState.GARAGE:
		return false
	var ph: Dictionary = phases[phase_idx]
	if q.runs >= int(ph["max_runs"]):
		return false
	if time < q.t_ready:
		return false
	return time + out_lap_time <= float(ph["dur"])


func send_out(q: QCar, comp: int, risk: int) -> bool:
	if not can_send(q):
		return false
	q.comp = comp
	q.risk = clampi(risk, 0, 2)
	q.state = QState.OUT
	q.run_start = time
	q.out_end = time + out_lap_time
	q.fly_start = q.out_end
	q.fly_end = -1.0
	q.runs += 1
	q.traffic = false
	return true


func tick(dt: float) -> void:
	if not active:
		return
	time += dt
	_update_weather(dt)
	var ph: Dictionary = phases[phase_idx]
	if not closed and time >= float(ph["dur"]):
		closed = true
		log_event("info", "%s: Zielflagge, laufende Runden werden noch gewertet." % ph["name"])
	for q in qcars:
		if q.eliminated:
			continue
		if q.state == QState.OUT:
			if q.fly_end < 0.0 and time >= q.fly_start:
				_start_flying_lap(q)
			elif q.fly_end > 0.0 and time >= q.fly_end and q.note != "gezählt":
				_finish_lap(q)
			if q.state == QState.OUT and time >= q.run_end and q.fly_end > 0.0:
				q.state = QState.GARAGE
				q.t_ready = time + rng.randf_range(60.0, 150.0)
		elif q.state == QState.GARAGE and q.auto and not closed:
			_ai_step(q)
	var any_out := false
	for q in qcars:
		if not q.eliminated and q.state == QState.OUT and q.fly_end != 0.0 and q.note != "gezählt":
			any_out = true
	if closed and not any_out:
		_end_phase()


func _ai_step(q: QCar) -> void:
	if q.crashed:
		return
	var ph: Dictionary = phases[phase_idx]
	if q.runs >= q.plan_runs:
		return
	if not can_send(q):
		return
	var go := false
	if q.runs == 0:
		go = time >= q.next_go
	elif q.runs == q.plan_runs - 1:
		go = time >= q.final_go
		if go and ph["advance"] > 0 and q.best > 0.0 and rank_of(q) <= int(ph["advance"]) - 3 and rng.randf() < 0.6:
			q.plan_runs = q.runs
			return
	else:
		go = time >= q.t_ready + 30.0
	if go:
		send_out(q, _ai_comp(q), 2 if (ph["name"] == "Q3" and rng.randf() < 0.4) else 1)


func _ai_comp(q: QCar) -> int:
	var c = q.car
	var ph: Dictionary = phases[phase_idx]
	if wet > c.ai_wet_t * 0.8 or (rain > 0.05 and wet > 0.1):
		return 4 if wet > 0.58 else 3
	var fast_team: bool = c.qpace > 0.984
	if ph["name"] == "Q1" and fast_team and year >= 2010 and rng.randf() < 0.8:
		return 1
	if ph["name"] == "Q2" and fast_team and year >= 2010 and year <= 2021 and rng.randf() < 0.3:
		return 1
	return 0


func _start_flying_lap(q: QCar) -> void:
	laps_total += 1
	var c = q.car
	var lap: float = track.lap_ref * 1.004 / c.qpace
	var cd: Dictionary = sim.COMPOUNDS[q.comp]
	lap += float(cd["offset"]) * scale_time if q.comp < DRY_COUNT else 0.0
	lap -= 0.7 * scale_time * track_evolution()
	lap += sim.wet_pen(q.comp, wet) * scale_time
	lap *= 1.0 + 0.2 * wet
	var risk_pace := [1.0015, 1.0, 0.9975]
	lap *= risk_pace[q.risk]
	lap *= 1.0 + rng.randfn(0.0, 0.0013)
	# Verkehr
	var near := 0
	for o in qcars:
		if o == q or o.eliminated or o.state != QState.OUT:
			continue
		if absf(o.fly_start - q.fly_start) < 25.0:
			near += 1
	if near > 0 and rng.randf() < minf(0.6, 0.08 * near):
		lap += rng.randf_range(0.1, 0.55) * scale_time
		q.traffic = true
	# Fehler / Unfall
	var risk_mul := [0.55, 1.0, 2.2]
	var crash_mul := [0.3, 1.0, 3.0]
	var wrong := 0.0
	if q.comp < DRY_COUNT and wet > 0.2:
		wrong = 1.0 + 4.0 * (wet - 0.2)
	var p_mist: float = 0.04 * risk_mul[q.risk] * (1.0 + wet) * (1.0 + wrong)
	var p_crash: float = 0.008 * crash_mul[q.risk] * (1.0 + 2.0 * wet) * (1.0 + wrong)
	var r := rng.randf()
	if r < p_crash:
		q.fly_end = time + lap * rng.randf_range(0.2, 0.7)
		q.crashed = true
		q.note = "Unfall"
		log_event("crash", "UNFALL: %s" % c.code, q)
		q.state = QState.CRASHED
		return
	elif r < p_crash + p_mist:
		lap += rng.randf_range(0.3, 1.6) * scale_time
		q.note = "Fehler"
		log_event("mistake", "%s: Fehler in der Runde" % c.code, q)
	else:
		q.note = ""
	q.fly_end = time + lap
	q.run_end = q.fly_end + in_lap_time
	q.last_lap = lap


func _finish_lap(q: QCar) -> void:
	var c = q.car
	var lap: float = q.last_lap
	var prev_best := q.best
	if q.best <= 0.0 or lap < q.best:
		q.best = lap
		q.best_comp = q.comp
	q.note = "gezählt"
	var rk := rank_of(q)
	if q.is_player or rk <= 3:
		var s := "%s %s  (P%d)" % [c.code, sim.fmt_time(lap), rk]
		if q.traffic:
			s += "  Verkehr!"
		log_event("lap", s, q)
	if q.best == lap and prev_best <= 0.0 or q.best == lap:
		pass


func _end_phase() -> void:
	var ph: Dictionary = phases[phase_idx]
	active = false
	# Bestzeiten dieses Abschnitts sichern
	for q in active_cars():
		if phase_idx < 3:
			q.phase_best[phase_idx] = q.best
			q.phase_comp[phase_idx] = q.best_comp
	var adv: int = ph["advance"]
	if adv > 0:
		var act: Array = active_cars()
		act.sort_custom(_best_less)
		var out: Array = []
		for i in range(adv, act.size()):
			act[i].eliminated = true
			act[i].state = QState.ELIMINATED
			out.append(act[i])
		# beste der Ausgeschiedenen zuerst, vor den früher Ausgeschiedenen
		tail = out + tail
		var names := ""
		for q in out:
			names += q.car.code + " "
		log_event("info", "%s beendet. Ausgeschieden: %s" % [ph["name"], names])
	else:
		log_event("info", "%s beendet." % ph["name"])
		finished = true


func phase_over() -> bool:
	return not active and phase_idx >= 0


func run_auto() -> void:
	for q in qcars:
		q.auto = true
	start_next_phase()
	while not finished:
		if active:
			tick(1.0)
		else:
			start_next_phase()


# ------------------------------------------------------------------ Ergebnis

## Qualifying-Reihenfolge (ohne Strafen).
func final_order() -> Array:
	var out: Array = []
	for q in standings():
		out.append(q.car)
	return out


## Startaufstellung mit Strafen.
func final_grid() -> Array:
	var order: Array = final_order()
	var pen: Array = []
	for c in order:
		if sim.grid_penalties.has(c.index):
			pen.append(c)
	for c in pen:
		var idx: int = order.find(c)
		var ni := mini(idx + int(sim.grid_penalties[c.index]), order.size() - 1)
		order.remove_at(idx)
		order.insert(ni, c)
	return order


func qcar_of(c):
	for q in qcars:
		if q.car == c:
			return q
	return null


func best_time_of(c) -> float:
	var q = qcar_of(c)
	if q == null:
		return 0.0
	for i in range(2, -1, -1):
		if float(q.phase_best[i]) > 0.0:
			return q.phase_best[i]
	return q.best


## Pflicht-Startreifen (Q2-Reifen der Top 10) 2010-2021.
func forced_start_of(c) -> int:
	if year < 2010 or year > 2021 or phases.size() < 3:
		return -1
	var q = qcar_of(c)
	if q == null:
		return -1
	if float(q.phase_best[2]) <= 0.0 and q.eliminated:
		return -1
	if q.eliminated:
		return -1
	var cmp: int = q.phase_comp[1]
	if cmp < 0 or cmp >= DRY_COUNT:
		return -1
	return cmp


## Position des Autos auf der Strecke (Weltkoordinaten) für die Karte; null wenn in der Box.
func car_world_pos(q: QCar):
	if q.state != QState.OUT and q.state != QState.CRASHED:
		return null
	if q.state == QState.CRASHED and time > q.fly_end + 20.0:
		return null
	if time < q.out_end:
		var f := (time - q.run_start) / maxf(out_lap_time, 1.0)
		return track.point_at(f * track.length)
	if q.fly_end > 0.0 and time <= q.fly_end:
		var f2 := (time - q.fly_start) / maxf(q.fly_end - q.fly_start, 1.0)
		return track.point_at(track.dist_at_frac(f2))
	if q.fly_end > 0.0 and time > q.fly_end and q.state == QState.OUT:
		var f3 := (time - q.fly_end) / maxf(in_lap_time, 1.0)
		return track.point_at(clampf(f3, 0.0, 1.0) * track.length)
	return null

extends RefCounted
## Rennsimulation (Distanzmodell mit Referenz-Geschwindigkeitsprofil), Zeitschritt = 1 s Rennzeit.
## Enthält: Qualifying, Start, Reifenverschleiß, Sprit, Boxenstopps, Überholen (DRS), Ausfälle,
## Safety Car / VSC, KI-Strategie. Bedienbar von der Oberfläche über set_style(), request_pit(), set_plan().

const COMPOUNDS := [
	{"name": "Soft", "short": "S", "color": Color(0.95, 0.15, 0.15), "offset": 0.0, "deg": 0.10, "life": 19.0},
	{"name": "Medium", "short": "M", "color": Color(1.0, 0.85, 0.1), "offset": 0.55, "deg": 0.06, "life": 32.0},
	{"name": "Hard", "short": "H", "color": Color(0.92, 0.92, 0.92), "offset": 1.0, "deg": 0.035, "life": 47.0},
	{"name": "Inter", "short": "I", "color": Color(0.2, 0.8, 0.3), "offset": 0.0, "deg": 0.05, "life": 34.0},
	{"name": "Wet", "short": "W", "color": Color(0.25, 0.5, 1.0), "offset": 0.0, "deg": 0.04, "life": 44.0},
]
const QualiSim = preload("res://scripts/quali_sim.gd")
const DRY_COUNT := 3
const CLIMATE := {
	"spa": 0.35, "interlagos": 0.30, "silverstone": 0.25, "suzuka": 0.25, "sepang": 0.30, "villeneuve": 0.22,
	"hungaroring": 0.15, "imola": 0.20, "catalunya": 0.08, "nurburgring": 0.25, "red_bull_ring": 0.20, "monza": 0.12,
	"zandvoort": 0.20, "americas": 0.10, "marina_bay": 0.20, "shanghai": 0.18, "fuji": 0.30, "istanbul": 0.10,
	"magny_cours": 0.20, "hockenheimring": 0.20, "albert_park": 0.20, "monaco": 0.12, "baku": 0.05, "bahrain": 0.0,
	"jeddah": 0.0, "losail": 0.0, "yas_marina": 0.0, "vegas": 0.02, "miami": 0.15, "rodriguez": 0.08, "mugello": 0.10,
	"portimao": 0.10, "ricard": 0.08, "sochi": 0.08, "valencia": 0.08, "buddh": 0.05, "yeongam": 0.20,
	"indianapolis": 0.15, "madring": 0.05,
}
const STYLE_NAMES := ["Sparen", "Standard", "Angriff"]
const STYLE_PACE := [-0.0065, 0.0, 0.0045]
const STYLE_WEAR := [0.72, 1.0, 1.32]
const FUEL_PER_KM := 0.34       # kg pro km
const FUEL_TIME := 0.03         # s pro kg und Runde
const PIT_STATIONARY_BASE := 2.4

# Energie: ab 2014 Batterie (ERS) mit Modi Laden / Normal / Angriff, davor Motormodi Eco / Normal / Power
const ERS_NAMES := ["Laden", "Normal", "Angriff"]
const ERS_PACE := [-0.0012, 0.0, 0.0030]
const ERS_RATE := [9.0, 1.5, -9.0]            # Batterie in Prozent pro Runde
const ENG_NAMES := ["Eco", "Normal", "Power"]
const ENG_PACE := [-0.0020, 0.0, 0.0028]
const ENG_HAZ := [0.55, 1.0, 2.0]
const ENG_WEAR := [0.75, 1.0, 1.45]
const ENG_FUEL := [0.95, 1.0, 1.02]
const DOUBLE_STOP_WAIT := 2.4
const CONTACT_RISK := 0.010
const PIT_EXIT_DIST := 300.0     # Strecke, die ein Auto in der Boxengasse zurücklegt (m)

enum State { GRID, RACING, PIT, OUT, FINISHED }
enum Status { GREEN, VSC, SC }


class RaceCar:
	var index := 0
	var team_id := ""
	var team_name := ""
	var color := Color.WHITE
	var code := ""
	var driver_name := ""
	var number := ""
	var is_player := false
	var pace_base := 1.0
	var qpace := 1.0
	var mech_rate := 0.05
	var crash_rate := 0.05
	var pit_skill := 0.0       # Sekunden schneller (negativ) oder langsamer
	var state := State.GRID
	var dist := 0.0
	var floor_laps := -1
	var lap_start := 0.0
	var last_lap := 0.0
	var best_lap := 0.0
	var lap_noise := 0.0
	var compound := 1
	var tyre_wear := 0.0
	var tyre_age_laps := 0
	var used_compounds: Array = []
	var fuel := 100.0
	var style := 1
	var pit_timer := 0.0
	var pit_stops := 0
	var pit_comp := 1
	var pit_requested := false
	var plan: Array = []        # [{"lap": n, "comp": c}] Boxenstopp am Ende von Runde n
	var grid := 0
	var quali_time := 0.0
	var out_reason := ""
	var finish_time := 0.0
	var finish_rank := 0
	var finish_laps := 0
	var gap_leader := 0.0
	var gap_ahead := 0.0
	var speed := 0.0
	var cur_pace := 1.0
	var dirty := false
	var drs := false
	var ai_threshold := 1.0
	var ai_wet_t := 0.18
	var ai_dry_t := 0.12
	var skill := 0.0
	var lap_history: Array = []
	var fuel_after_pit := 0.0
	var forced_start := -1
	var grid_penalty := 0
	# Fahrer, Taktik und Energie
	var driver_id := ""
	var tyre_trait := 0.0
	var wet_trait := 0.0
	var aggr := 0.5
	var obey := 0.7
	var start_trait := 0.0
	var cons := 0.65
	var morale := 0.62
	var morale_delta := 0.0
	var react := 0.7           # KI: wie schnell/zuverlässig das Team auf Gegner reagiert
	var ers := 70.0
	var ers_mode := 1
	var eng_mode := 1
	var engine_wear := 0.0
	var engines_used := 1
	var engine_new := false
	var wear_rate := 1.0
	var ai_engine_t := 0.9
	var engine_wear_old := 0.0
	var engine_broken := false
	var damage := 0.0          # Pace-Verlust durch Beschädigung bis zum nächsten Stopp
	var setup_err := 0.0
	var setup_pen_race := 0.0
	var setup_pen_q := 0.0
	var mate_index := -1
	var order := {}            # Teamorder: {"type": "swap"|"hold"|"block", "partner": Index, "until": Runde}
	var react_lap := -1
	var react_count := 0
	var react_comp := 1
	var duel_laps := 0
	var stack_wait := 0.0
	var stop_wait := 0.0
	var pit_total := 0.0
	var pit_stat := 0.0
	var sec_k := -1
	var sec_start_t := 0.0
	var sec_valid := false
	var sec_times: Array = [0.0, 0.0, 0.0]
	var sec_cols: Array = [0, 0, 0]       # 0 keine, 1 gelb, 2 grün, 3 lila
	var sec_best: Array = [1e9, 1e9, 1e9]


var track
var year := 2024
var rules: Dictionary = {}
var laps := 50
var time := 0.0
var status := Status.GREEN
var status_laps_left := 0
var cars: Array = []
var events: Array = []
var rng := RandomNumberGenerator.new()
var started := false
var over := false
var leader_finished := false
var finish_counter := 0
var fastest_lap := 0.0
var fastest_car: RaceCar = null
var burn_per_lap := 1.9
var scale_time := 1.0
var quali_done := false
var quali = null
var grid_penalties := {}
var wet := 0.0
var rain := 0.0
var rain_start := -1.0
var rain_end := -1.0
var rain_peak := 0.0
var rain_chance := 0.08
var rain_seen := false
var forecast_noise := 0.0
var rain_announced := false
var rain_over_announced := false
var sc_count := 0
var player_team := ""
var setup_ideal := 0.0        # tatsächlich beste Abtriebs-Einstellung dieses Wochenendes (-1 Topspeed .. +1 Abtrieb)
var ghost_start := -1.0       # Fehlalarm im Wetterbericht (Regen, der nie kommt)
var ghost_end := -1.0
var engine_allowance := 0
var engine_life := 99.0
var tactics_log: Array = []
var sec_best_all: Array = [1e9, 1e9, 1e9]
var gear_pen := {}
var engine_pen := {}
# Freitagstraining: Setup-Messungen, Reifendaten, Programme
var practice := {"done": 0, "setup_obs": [], "tyre_known": false, "longrun": 0, "qsim": 0, "setup": 0.0, "sessions": []}
var tyre_noise: Array = [0.0, 0.0, 0.0]


func setup(p_year: int, p_track, teams: Array, p_laps: int, p_player_team: String, seed_value: int = 0) -> void:
	year = p_year
	track = p_track
	laps = p_laps
	player_team = p_player_team
	rules = DB.rules(year)
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	burn_per_lap = FUEL_PER_KM * track.length / 1000.0
	_setup_weather()
	scale_time = track.lap_ref / 90.0
	cars = []
	var idx := 0
	var best_pace := 0.0
	var worst_pace := 9.0
	for t in teams:
		best_pace = maxf(best_pace, float(t["pace"]))
		worst_pace = minf(worst_pace, float(t["pace"]))
	engine_allowance = int(teams[0].get("engine_allowance", 0)) if teams.size() > 0 else 0
	engine_life = float(teams[0].get("engine_life", 99.0)) if teams.size() > 0 else 99.0
	setup_ideal = clampf(track.df_need() + rng.randfn(0.0, 0.12), -1.0, 1.0)
	tyre_noise = [rng.randfn(0.0, 0.14), rng.randfn(0.0, 0.14), rng.randfn(0.0, 0.14)]
	_setup_ghost()
	for t in teams:
		var form := rng.randfn(0.0, 0.0013)
		var affinity := rng.randfn(0.0, 0.0015)
		var team_react := clampf(rng.randfn(0.72, 0.15), 0.4, 1.0)
		var quality := clampf((float(t["pace"]) - worst_pace) / maxf(best_pace - worst_pace, 0.001), 0.0, 1.0)
		var team_err := absf(rng.randfn(0.0, 0.40 - 0.22 * quality))
		var first_idx := idx
		for d in t["drivers"]:
			var c := RaceCar.new()
			c.index = idx
			idx += 1
			c.team_id = t["id"]
			c.team_name = t["name"]
			c.color = t["color"]
			c.code = d["code"]
			c.driver_name = d["name"]
			c.number = str(d["number"])
			c.driver_id = str(d.get("id", ""))
			c.is_player = (t["id"] == player_team)
			c.skill = d["skill"]
			c.pace_base = float(t["pace"]) * (1.0 + float(d["skill"]) + form + affinity)
			c.qpace = float(t["pace"]) * (1.0 + float(d["skill"]) * 0.6 + float(d["qskill"]) + form + affinity)
			c.mech_rate = float(t["mech_rate"]) * float(t.get("mech_mult", 1.0))
			c.crash_rate = float(d["crash_rate"])
			c.pit_skill = float(t.get("pit_skill", 0.0))
			var tr: Dictionary = d.get("traits", {})
			c.tyre_trait = float(tr.get("tyre", 0.0))
			c.wet_trait = float(tr.get("wet", 0.0))
			c.aggr = float(tr.get("aggr", 0.5))
			c.obey = float(tr.get("obey", 0.7))
			c.start_trait = float(tr.get("start", 0.0))
			c.cons = float(tr.get("cons", 0.65))
			c.morale = float(d.get("morale", 0.62))
			c.engine_wear = float(d.get("engine_wear", 0.0))
			c.engines_used = int(d.get("engines_used", 1))
			c.react = team_react
			c.wear_rate = rng.randf_range(0.88, 1.15)
			c.ai_engine_t = rng.randf_range(0.85, 1.02)
			c.ers = rng.randf_range(55.0, 80.0)
			# Setup: KI-Teams liegen je nach Stärke mehr oder weniger daneben, der Spieler stellt es im Training ein
			if c.is_player:
				apply_setup(c, 0.0)
			else:
				c.setup_err = absf(team_err + rng.randfn(0.0, 0.05))
				_set_setup_pen(c)
			cars.append(c)
		for k in range(first_idx, idx):
			if idx - first_idx == 2:
				cars[k].mate_index = first_idx + (1 if k == first_idx else 0)
	_roll_penalties()


# ------------------------------------------------------------------ Freitagstraining

const PRACTICE_PROGRAMS := {
	"setup": {"name": "Setup-Abstimmung", "desc": "Misst, wie viel Abtrieb die Strecke verlangt. Jede Session macht die Schätzung genauer."},
	"tyres": {"name": "Reifentest", "desc": "Zeigt die genaue Haltbarkeit aller Mischungen für die Strategieplanung."},
	"longrun": {"name": "Longruns (Rennpace)", "desc": "Rennsimulation mit viel Sprit. Kleiner Pace-Gewinn im Rennen, zeigt die Rennpace im Vergleich."},
	"quali": {"name": "Quali-Simulation", "desc": "Runden auf weichen Reifen. Kleiner Pace-Gewinn im Qualifying, zeigt die Qualipace."},
}


## Geschätztes Setup-Optimum aus den bisherigen Messungen: {"has", "est", "sigma"}.
func practice_estimate() -> Dictionary:
	var obs: Array = practice["setup_obs"]
	if obs.is_empty():
		return {"has": false, "est": track.df_need(), "sigma": 0.55}
	var m := 0.0
	for o in obs:
		m += float(o)
	m /= float(obs.size())
	return {"has": true, "est": clampf(m, -1.0, 1.0), "sigma": 0.40 / sqrt(float(obs.size()))}


## Haltbarkeit einer Mischung, wie sie dem Team bekannt ist (ohne Reifentest ungenau).
func known_life(comp: int) -> float:
	var l := life_eff(comp)
	if practice["tyre_known"] or comp >= DRY_COUNT:
		return l
	return l * (1.0 + float(tyre_noise[comp]))


## Eine Trainingssession fahren. Rückgabe: {"text", "times": [{car, t}], "incident": "", "cost": 0.0}
func run_practice(kind: String) -> Dictionary:
	var res := {"kind": kind, "text": "", "times": [], "incident": "", "cost": 0.0}
	practice["done"] = int(practice["done"]) + 1
	for c in cars:
		if c.is_player and engine_allowance > 0:
			c.engine_wear += 0.035
	match kind:
		"setup":
			practice["setup_obs"].append(clampf(setup_ideal + rng.randfn(0.0, 0.40), -1.3, 1.3))
			var e := practice_estimate()
			var hint := "etwas mehr Abtrieb" if float(e["est"]) > 0.15 else ("weniger Abtrieb für mehr Topspeed" if float(e["est"]) < -0.15 else "eine ausgewogene Einstellung")
			res["text"] = "Ingenieur: Die Daten sprechen für %s (Schätzung %+.2f, Unsicherheit ±%.2f)." % [hint, float(e["est"]), float(e["sigma"])]
		"tyres":
			practice["tyre_known"] = true
			res["text"] = "Reifendaten gesammelt: Soft %d, Medium %d, Hard %d Runden Haltbarkeit." % [int(life_eff(0)), int(life_eff(1)), int(life_eff(2))]
		"longrun":
			practice["longrun"] = int(practice["longrun"]) + 1
			if int(practice["longrun"]) == 1:
				for c in cars:
					if c.is_player:
						c.pace_base *= 1.0002
			res["text"] = "Longruns abgeschlossen: Fahrer und Auto sind besser auf die Renndistanz abgestimmt."
		"quali":
			practice["qsim"] = int(practice["qsim"]) + 1
			if int(practice["qsim"]) == 1:
				for c in cars:
					if c.is_player:
						c.qpace *= 1.0003
			res["text"] = "Quali-Simulation abgeschlossen: Der Fahrer hat ein gutes Gefühl für die schnelle Runde."
	# Vorfälle: aggressive Fahrer crashen eher
	for c in cars:
		if c.is_player and rng.randf() < 0.02 + 0.04 * c.aggr:
			res["incident"] = "%s verbremst sich und beschädigt das Auto (Reparatur 1.5 Mio. $)." % c.code
			res["cost"] = float(res["cost"]) + 1.5
			c.morale_delta -= 0.01
	var list: Array = []
	for c in cars:
		var base: float = c.qpace if kind != "longrun" else c.pace_base
		var t: float = track.lap_ref * (1.012 if kind != "longrun" else 1.035) / (base * (1.0 + rng.randfn(0.0, 0.0015)))
		list.append({"car": c, "t": t})
	list.sort_custom(func(a, b): return a["t"] < b["t"])
	res["times"] = list
	practice["sessions"].append(res)
	return res


## Einstellung des Spielers (-1 Topspeed .. +1 Abtrieb) auf beide Autos des Spielerteams anwenden.
func apply_setup(c: RaceCar, value: float) -> void:
	c.pace_base /= (1.0 - c.setup_pen_race)
	c.qpace /= (1.0 - c.setup_pen_q)
	c.setup_err = absf(value - setup_ideal)
	_set_setup_pen(c)


func _set_setup_pen(c: RaceCar) -> void:
	var e := minf(c.setup_err, 1.3)
	c.setup_pen_race = 0.0022 * pow(e, 1.5)
	c.setup_pen_q = 0.0035 * pow(e, 1.5)
	c.pace_base *= (1.0 - c.setup_pen_race)
	c.qpace *= (1.0 - c.setup_pen_q)


func make_log(kind: String, text: String, car = null) -> void:
	events.append({"t": time, "lap": leader_lap(), "kind": kind, "text": text, "car": car.index if car != null else -1})


func leader_lap() -> int:
	var best := 0
	for c in cars:
		if c.state != State.OUT:
			best = maxi(best, c.floor_laps + 1)
	return clampi(best, 1, laps)


func life_eff(comp: int) -> float:
	return float(COMPOUNDS[comp]["life"]) / track.tyre_severity


# ------------------------------------------------------------------ Wetter

func _setup_weather() -> void:
	rain_chance = float(CLIMATE.get(track.id, 0.08))
	forecast_noise = rng.randf_range(-3.0, 3.0)
	if rng.randf() < rain_chance:
		var dur: float = float(laps) * track.lap_ref * 1.05
		var st: float = rng.randf_range(-0.1, 0.65) * dur
		rain_peak = rng.randf_range(0.35, 1.0)
		if st < 0.0:
			wet = rng.randf_range(0.25, 0.85)
			rain = 0.3
			rain_start = -1.0 - rng.randf_range(60.0, 900.0)
			rain_end = rng.randf_range(10.0, 35.0) * 60.0
			rain_announced = true
		else:
			rain_start = st
			rain_end = st + rng.randf_range(15.0, 45.0) * 60.0


func _update_weather(dt: float) -> void:
	var target := 0.0
	if rain_end > 0.0 and time >= rain_start and time < rain_end:
		var u: float = (time - rain_start) / maxf(rain_end - rain_start, 1.0)
		target = rain_peak * pow(sin(PI * clampf(u, 0.0, 1.0)), 0.7)
		if rain_start < 0.0:
			target = rain_peak * clampf(1.0 - time / rain_end, 0.0, 1.0)
	rain = move_toward(rain, target, 0.012 * dt)
	if rain > 0.04:
		var wet_target: float = clampf(rain * 1.05, 0.0, 1.0)
		if wet < wet_target:
			wet += (wet_target - wet) * 0.004 * dt
		else:
			wet -= 0.00045 * dt
		if not rain_seen:
			rain_seen = true
		if not rain_announced and rain > 0.1:
			rain_announced = true
			make_log("weather", "Es beginnt zu regnen!")
	else:
		wet -= 0.00045 * dt
	wet = clampf(wet, 0.0, 1.0)
	if rain_announced and not rain_over_announced and rain < 0.03 and time > rain_end and rain_end > 0.0:
		rain_over_announced = true
		make_log("weather", "Der Regen lässt nach, die Strecke trocknet ab.")


## Zeitverlust (s/Runde, bezogen auf 90-s-Runde) durch Reifenmischung bei Streckennässe.
func wet_penalty(comp: int) -> float:
	return wet_pen(comp, wet)


static func wet_pen(comp: int, w: float) -> float:
	if comp < DRY_COUNT:
		return 28.0 * pow(maxf(0.0, w - 0.08), 1.2)
	if comp == 3:
		if w < 0.38:
			return 7.0 * (0.38 - w) / 0.38
		return 14.0 * (w - 0.38) / 0.62
	if w < 0.8:
		return 11.0 * (0.8 - w) / 0.8
	return 3.0 * (w - 0.8) / 0.2


func wet_wear_factor(comp: int) -> float:
	if comp == 3 and wet < 0.38:
		return 1.0 + 3.0 * (1.0 - wet / 0.38)
	if comp == 4 and wet < 0.8:
		return 1.0 + 3.5 * (1.0 - wet / 0.8)
	return 1.0


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


## Gelegentlich meldet der Wetterbericht Regen, der nie kommt (Fehlalarm).
func _setup_ghost() -> void:
	ghost_start = -1.0
	ghost_end = -1.0
	if rain_end < 0.0 and rng.randf() < 0.10:
		var dur: float = float(laps) * track.lap_ref * 1.05
		ghost_start = rng.randf_range(0.2, 0.7) * dur
		ghost_end = ghost_start + rng.randf_range(15.0, 35.0) * 60.0


func forecast_text() -> String:
	var rs := rain_start
	var re := rain_end
	if re < 0.0 and ghost_end > 0.0:
		rs = ghost_start
		re = ghost_end
	if re < 0.0:
		return "kein Regen erwartet"
	if time < rs:
		var mins: float = (rs - time) / 60.0 + forecast_noise
		if mins < 40.0:
			return "Regen in ca. %d min" % maxi(1, int(mins))
		return "Regen später möglich"
	if time < re:
		if rain_end < 0.0:
			return "Regen ausgeblieben"
		var m: float = (re - time) / 60.0 + forecast_noise
		return "Regenende in ca. %d min" % maxi(1, int(m))
	return "bleibt trocken"


## Wetterradar für die Wette: {"eta": Minuten bis Regen (-1 keiner), "prob": Eintrittswahrscheinlichkeit 0..1}.
func rain_radar() -> Dictionary:
	var rs := rain_start
	var real: bool = rain_end > 0.0
	if not real and ghost_end > 0.0:
		rs = ghost_start
	elif not real:
		return {"eta": -1.0, "prob": 0.0}
	if time >= rs:
		return {"eta": 0.0, "prob": 1.0 if real else 0.0}
	var eta: float = (rs - time) / 60.0 + forecast_noise
	var prob := clampf(0.92 - eta / 80.0, 0.45, 0.92) if real else clampf(0.55 - eta / 120.0, 0.25, 0.55)
	return {"eta": maxf(eta, 1.0), "prob": prob}


func recommended_compound() -> int:
	if wet > 0.62:
		return 4
	if wet > 0.2:
		return 3
	return -1


# ------------------------------------------------------------------ Qualifying

func do_qualifying() -> void:
	var q = QualiSim.new()
	q.setup(self)
	q.run_auto()
	quali = q
	finish_qualifying(q)


## Qualifying abschließen: Startaufstellung (inkl. Strafen) übernehmen, Pflicht-Startreifen setzen.
func finish_qualifying(q) -> void:
	var order: Array = q.final_grid()
	for i in order.size():
		var c: RaceCar = order[i]
		c.grid = i + 1
		c.quali_time = q.best_time_of(c)
		c.grid_penalty = int(grid_penalties.get(c.index, 0))
	for c in cars:
		c.forced_start = q.forced_start_of(c)
	quali = q
	quali_done = true
	for c in cars:
		_plan_ai(c)


## Zufällige Startplatzstrafen (Motor-/Getriebewechsel) erzeugen.
func _roll_penalties() -> void:
	gear_pen = {}
	engine_pen = {}
	for c in cars:
		# Getriebe/Anbauteile: zufällig
		var p: float = clampf(0.010 + 0.08 * c.mech_rate, 0.0, 0.07)
		if rng.randf() < p:
			var sizes := [3, 5, 5]
			gear_pen[c.index] = sizes[rng.randi() % sizes.size()]
		# Motor: KI wechselt bei hohem Verschleiß, Strafe wenn das Kontingent überschritten wird
		if not c.is_player and engine_allowance > 0 and c.engine_wear >= c.ai_engine_t:
			set_engine_change(c, true)
	_refresh_penalties()


func _refresh_penalties() -> void:
	grid_penalties = {}
	for c in cars:
		var s := int(gear_pen.get(c.index, 0)) + int(engine_pen.get(c.index, 0))
		if s > 0:
			grid_penalties[c.index] = s


## Neuer Motor für dieses Wochenende (frischer Motor, aber Strafe bei überschrittenem Kontingent).
func set_engine_change(c: RaceCar, on: bool) -> void:
	if engine_allowance <= 0:
		return
	if on and not c.engine_new:
		c.engine_wear_old = c.engine_wear
		c.engine_wear = 0.0
		c.engine_new = true
		c.engines_used += 1
		if c.engines_used > engine_allowance:
			engine_pen[c.index] = 10
	elif not on and c.engine_new:
		c.engine_wear = c.engine_wear_old
		c.engine_new = false
		c.engines_used -= 1
		engine_pen.erase(c.index)
	_refresh_penalties()


func grid_order() -> Array:
	var order: Array = cars.duplicate()
	order.sort_custom(func(a, b): return a.grid < b.grid)
	return order


# ------------------------------------------------------------------ KI-Strategie / Planung

func default_plan(c: RaceCar) -> Dictionary:
	# Rückgabe: {"start": compound, "plan": [...]}
	var min_c: int = rules["min_compounds"]
	var stops := 1
	if rules["refuel"]:
		stops = rng.randi_range(1, 3)
	else:
		var avg_life := (life_eff(1) + life_eff(2)) * 0.5
		stops = clampi(int(ceil(float(laps) / avg_life)) - 1, 1, 3)
		if rng.randf() < 0.18 and stops < 3:
			stops += 1
		if laps < 28:
			stops = clampi(stops, 0, 1)
	var comps: Array = []
	var start: int = c.forced_start if c.forced_start >= 0 else _pick_start_compound(float(laps) / float(stops + 1))
	comps.append(start)
	var stint := float(laps) / float(stops + 1)
	for k in stops:
		var best := 1
		var cands: Array = []
		for cc in 3:
			if life_eff(cc) >= stint * 0.95:
				cands.append(cc)
		if cands.is_empty():
			best = 2
		else:
			best = cands[rng.randi() % cands.size()]
		comps.append(best)
	if min_c >= 2 and stops >= 1:
		var distinct := {}
		for x in comps:
			distinct[x] = true
		if distinct.size() < 2:
			comps[comps.size() - 1] = (comps[comps.size() - 1] + 1) % 3
	var plan: Array = []
	for k in stops:
		var lap := int(round(stint * (k + 1) + rng.randf_range(-2.0, 2.0)))
		lap = clampi(lap, 3 + k, laps - 3)
		plan.append({"lap": lap, "comp": comps[k + 1]})
	return {"start": start, "plan": plan}


func _pick_start_compound(stint: float) -> int:
	var cands: Array = []
	for k in DRY_COUNT:
		if life_eff(k) >= stint * 0.92:
			cands.append(k)
	if cands.is_empty():
		return 2
	var weights := [0.35, 0.4, 0.25]
	var total := 0.0
	for k in cands:
		total += weights[k]
	var r := rng.randf() * total
	for k in cands:
		r -= weights[k]
		if r <= 0.0:
			return k
	return cands[cands.size() - 1]


func _plan_ai(c: RaceCar) -> void:
	var p := default_plan(c)
	c.compound = p["start"]
	c.plan = p["plan"]
	c.used_compounds = [c.compound]
	c.ai_threshold = rng.randf_range(0.92, 1.02)
	c.ai_wet_t = clampf(rng.randfn(0.17, 0.05), 0.07, 0.3)
	c.ai_dry_t = clampf(rng.randfn(0.12, 0.04), 0.04, 0.2)
	c.fuel = _fuel_for_stint(c, 0)


func _next_stop_lap(c: RaceCar, after_lap: int) -> int:
	for s in c.plan:
		if int(s["lap"]) > after_lap:
			return int(s["lap"])
	return laps


func _fuel_for_stint(c: RaceCar, from_lap: int) -> float:
	if rules["refuel"]:
		var to_lap := _next_stop_lap(c, from_lap)
		return burn_per_lap * float(to_lap - from_lap) + 1.5
	return burn_per_lap * float(laps) + 1.5


# ------------------------------------------------------------------ Befehle (Spieler)

func set_style(c: RaceCar, s: int) -> void:
	c.style = clampi(s, 0, 2)


func request_pit(c: RaceCar, comp: int) -> void:
	c.pit_requested = true
	c.pit_comp = comp


func cancel_pit(c: RaceCar) -> void:
	c.pit_requested = false


func set_plan(c: RaceCar, start_comp: int, plan: Array) -> void:
	c.plan = plan
	if not started:
		c.compound = start_comp
		c.used_compounds = [start_comp]
		c.fuel = _fuel_for_stint(c, 0)


# ------------------------------------------------------------------ Start

func start_race() -> void:
	if not quali_done:
		do_qualifying()
	var order := grid_order()
	for i in order.size():
		var c: RaceCar = order[i]
		c.dist = -(8.0 * i + 6.0) + rng.randf_range(-0.6, 0.6)
		c.floor_laps = -1
		c.sec_k = int(floor(c.dist / (track.length / 3.0)))
		c.sec_start_t = 0.0
		c.state = State.RACING
		c.lap_start = 0.0
		c.lap_noise = rng.randfn(0.0, track.lap_ref * 0.002)
		if c.used_compounds.is_empty():
			c.used_compounds = [c.compound]
	for c in cars:
		if not c.is_player and wet > 0.2:
			c.compound = 4 if wet > 0.58 else 3
			c.used_compounds = [c.compound]
			c.plan = []
	started = true
	make_log("info", "Die Ampel erlischt: Start des Rennens über %d Runden!" % laps)


# ------------------------------------------------------------------ Pace

func tyre_loss(c: RaceCar) -> float:
	var comp: Dictionary = COMPOUNDS[c.compound]
	var life := life_eff(c.compound)
	var loss: float = float(comp["offset"]) + float(comp["deg"]) * track.tyre_severity * c.tyre_wear
	if c.tyre_wear > life:
		var over_l := c.tyre_wear - life
		loss += 0.30 * pow(over_l, 1.35)
	loss += wet_penalty(c.compound)
	return loss * scale_time


func has_ers() -> bool:
	return year >= 2014


## Wirksamer Batteriemodus (leere Batterie kann nicht mehr einsetzen).
func ers_eff(c: RaceCar) -> int:
	if not has_ers():
		return 1
	if c.ers_mode == 2 and c.ers <= 1.0:
		return 1
	return c.ers_mode


func lap_pace(c: RaceCar) -> float:
	var loss := tyre_loss(c) + c.fuel * FUEL_TIME * scale_time + c.lap_noise
	var sp: float = STYLE_PACE[c.style]
	if has_ers():
		sp += ERS_PACE[ers_eff(c)]
	else:
		sp += ENG_PACE[c.eng_mode]
	sp += c.wet_trait * 0.004 * wet
	sp -= c.damage
	if not c.order.is_empty() and c.order["type"] == "block":
		sp -= 0.03
	var p: float = c.pace_base * (1.0 + sp) / ((1.0 + loss / track.lap_ref) * (1.0 + 0.20 * wet))
	return p


## Zeitverlust (s pro Runde) eines frischen Reifens der Mischung comp (für Undercut-Rechnung).
func fresh_loss(comp: int) -> float:
	var cd: Dictionary = COMPOUNDS[comp]
	return (float(cd["offset"]) + float(cd["deg"]) * track.tyre_severity * 0.4 + wet_pen(comp, wet)) * scale_time


## Motorausfall-Faktor durch Verschleiß (ab 75 % steigt das Risiko, über 100 % stark).
func engine_hazard(c: RaceCar) -> float:
	if engine_allowance <= 0:
		return 1.0
	var w := c.engine_wear
	var f := 1.0
	if w > 0.75:
		f = 1.0 + 6.0 * (minf(w, 1.0) - 0.75)
	if w > 1.0:
		f = 2.5 + 12.0 * (w - 1.0)
	return f


func predicted_lap_time(c: RaceCar) -> float:
	return track.lap_ref / lap_pace(c)


# ------------------------------------------------------------------ Hauptschleife

func tick(dt: float) -> void:
	if not started or over:
		return
	time += dt
	_update_weather(dt)
	var want := {}
	var active: Array = []
	for c in cars:
		if c.state == State.RACING:
			active.append(c)
	active.sort_custom(func(a, b): return a.dist > b.dist)

	# 1) freie Fahrt: gewünschte Fortschritte
	var pace_of := {}
	for c in active:
		var p := lap_pace(c)
		var v: float = track.speed_at(c.dist + 6.0) * p
		if time < 16.0:
			v *= clampf(0.22 + time / 20.0, 0.0, 1.0)
		if status == Status.SC:
			v = minf(v, track.speed_at(c.dist) * 0.42)
		elif status == Status.VSC:
			v *= 0.62
		c.cur_pace = p
		pace_of[c] = v
		want[c] = c.dist + v * dt

	# 2) Verkehr, Überholen
	var fin := {}
	var i := 0
	var order: Array = active
	while i < order.size():
		var c: RaceCar = order[i]
		var nd: float = want[c]
		c.dirty = false
		c.drs = false
		if i > 0:
			var ahead: RaceCar = order[i - 1]
			var gap_old: float = ahead.dist - c.dist
			if gap_old < 400.0 and gap_old > -50.0:
				var v_ahead: float = maxf(pace_of[ahead], 10.0)
				var min_gap: float = maxf(12.0, v_ahead * 0.42)
				if status == Status.SC:
					min_gap = 14.0
				elif time < 18.0:
					min_gap = 8.0
				var ahead_nd: float = fin[ahead]
				var gap_time: float = (ahead_nd - nd) / v_ahead
				if nd > ahead_nd - min_gap:
					c.dirty = true
					var chance := _pass_chance(c, ahead, ahead_nd - nd, gap_time) * dt
					if status == Status.GREEN and rng.randf() < chance:
						nd = ahead_nd + 4.0
						_on_pass(c, ahead)
						fin[c] = nd
						# Reihenfolge tauschen
						order[i - 1] = c
						order[i] = ahead
						i += 1
						continue
					else:
						nd = maxf(c.dist, ahead_nd - min_gap)
						if status == Status.SC and ahead_nd - nd > 40.0:
							pass
				elif gap_time < 1.5:
					c.dirty = true
				elif status == Status.SC and ahead_nd - nd > 22.0:
					# Aufschließen unter Safety Car
					nd = minf(nd + pace_of[c] * 0.35 * dt, ahead_nd - 18.0)
				if gap_time < 1.0 and rules["drs"] and track.in_drs_zone(c.dist):
					c.drs = true
		fin[c] = nd
		i += 1

	# 3) anwenden, Runden, Reifen, Sprit
	for c in active:
		var old: float = c.dist
		var nd: float = fin[c]
		c.speed = (nd - old) / dt
		c.dist = nd
		var lap_frac: float = (nd - old) / track.length
		var wear_mul: float = STYLE_WEAR[c.style] * (1.18 if c.dirty else 1.0) * wet_wear_factor(c.compound) * (1.0 - 0.07 * c.tyre_trait)
		c.tyre_wear += lap_frac * wear_mul
		_track_sectors(c, nd)
		var fuel_mul := 1.0 if has_ers() else float(ENG_FUEL[c.eng_mode])
		c.fuel = maxf(0.0, c.fuel - burn_per_lap * lap_frac * fuel_mul)
		# Batterie und Motorverschleiß
		if has_ers():
			var rate: float = ERS_RATE[ers_eff(c)] if status == Status.GREEN else 4.0
			c.ers = clampf(c.ers + rate * lap_frac, 0.0, 100.0)
		if engine_allowance > 0:
			var wf: float = 1.0
			if has_ers():
				wf = [0.9, 1.0, 1.2][c.ers_mode]
			else:
				wf = float(ENG_WEAR[c.eng_mode])
			c.engine_wear += lap_frac / float(laps) / engine_life * wf * c.wear_rate
		var fl := int(floor(nd / track.length))
		if fl > c.floor_laps:
			_on_line(c, fl, old, nd)
	_update_gaps()
	_roll_failures(dt, active)
	_pit_timers(dt)
	_update_status()
	_check_over()


## Sektorzeiten: Strecke in drei gleich lange Abschnitte; Farben wie im TV (lila = Bestzeit aller, grün = persönliche Bestzeit).
func _track_sectors(c: RaceCar, nd: float) -> void:
	var sec_len: float = track.length / 3.0
	var k_new := int(floor(nd / sec_len))
	if status != Status.GREEN:
		c.sec_valid = false
	if k_new <= c.sec_k:
		return
	var cross_t: float = time - (nd - float(k_new) * sec_len) / maxf(c.speed, 1.0)
	var idx: int = ((c.sec_k % 3) + 3) % 3
	var dur: float = cross_t - c.sec_start_t
	c.sec_times[idx] = dur
	if c.sec_valid and dur > 4.0:
		if dur < float(sec_best_all[idx]):
			sec_best_all[idx] = dur
			c.sec_best[idx] = minf(float(c.sec_best[idx]), dur)
			c.sec_cols[idx] = 3
		elif dur < float(c.sec_best[idx]):
			c.sec_best[idx] = dur
			c.sec_cols[idx] = 2
		else:
			c.sec_cols[idx] = 1
	else:
		c.sec_cols[idx] = 0
	c.sec_start_t = cross_t
	c.sec_valid = status == Status.GREEN and c.state == State.RACING
	c.sec_k = k_new


func _pass_chance(c: RaceCar, ahead: RaceCar, gap_m: float, gap_time: float) -> float:
	if status != Status.GREEN:
		return 0.0
	# Teamorder: "Position halten" blockt Duelle, "Platztausch" erzwingt den Überholvorgang
	if c.team_id == ahead.team_id:
		if not ahead.order.is_empty() and not c.order.is_empty() and ahead.order["type"] == "hold" and c.order["type"] == "hold":
			return 0.0
		if not ahead.order.is_empty() and ahead.order["type"] == "swap" and int(ahead.order["partner"]) == c.index:
			return 1.0
	var dlt: float = track.lap_ref * (1.0 / maxf(ahead.cur_pace, 0.5) - 1.0 / maxf(c.cur_pace, 0.5))
	var ez: float = track.overtake_ease
	var ch: float = ez * (0.004 + 0.05 * maxf(0.0, dlt)) if dlt > 0.0 else ez * 0.0015
	if rules["drs"] and gap_time < 1.0 and track.in_drs_zone(c.dist):
		ch *= 2.3
	if time < 25.0:
		ch = maxf(ch, 0.06 * ez + 0.02)
		if dlt > -0.3:
			ch *= 1.8
	ch *= 1.0 + (c.skill - ahead.skill) * 40.0
	# Charakter: Angreifer überholen leichter, Aggressive sind schwerer zu überholen
	ch *= 1.0 + 0.4 * (c.aggr - 0.5)
	ch *= 1.0 - 0.25 * (ahead.aggr - 0.5)
	if time < 25.0:
		ch *= 1.0 + 0.35 * c.start_trait
	# Batterie: Angriff hilft beim Überholen, Verteidigung beim Verteidigen
	if has_ers():
		if ers_eff(c) == 2:
			ch *= 1.5
		if ers_eff(ahead) == 2 and gap_time < 1.2:
			ch *= 0.7
	return clampf(ch, 0.0, 0.4)


func _on_pass(c: RaceCar, ahead: RaceCar) -> void:
	if c.is_player or ahead.is_player:
		make_log("pass", "%s überholt %s" % [c.code, ahead.code], c)
	if c.team_id != ahead.team_id:
		return
	# Teamkollegen: Teamorder erfüllt oder freier Zweikampf mit Kontaktrisiko
	if not ahead.order.is_empty() and ahead.order["type"] == "swap" and int(ahead.order["partner"]) == c.index:
		ahead.order = {}
		ahead.morale_delta -= 0.05
		c.morale_delta += 0.03
		make_log("radio", "Teamorder ausgeführt: %s lässt %s vorbei." % [ahead.code, c.code], c)
		return
	if rng.randf() < CONTACT_RISK * (0.6 + c.aggr + ahead.aggr):
		_teammate_contact(c, ahead)


func _teammate_contact(c: RaceCar, ahead: RaceCar) -> void:
	var victim: RaceCar = ahead if rng.randf() < 0.4 else c
	var other: RaceCar = c if victim == ahead else ahead
	make_log("dnf", "KOLLISION der Teamkollegen %s und %s!" % [c.code, ahead.code], c)
	other.damage = 0.012
	other.morale_delta -= 0.04
	victim.morale_delta -= 0.04
	_retire(victim, "Kollision mit Teamkollegen")


func _on_line(c: RaceCar, fl: int, old: float, nd: float) -> void:
	var prev: int = c.floor_laps
	c.floor_laps = fl
	if fl < 1:
		return
	# Rundenzeit mit Interpolation des Linienübergangs
	var cross_t: float = time - (nd - fl * track.length) / maxf(c.speed, 1.0)
	var lt: float = cross_t - c.lap_start
	if prev >= 0:
		c.last_lap = lt
		c.lap_history.append(lt)
		if c.best_lap <= 0.0 or lt < c.best_lap:
			c.best_lap = lt
		if lt > track.lap_ref * 0.8 and (fastest_lap <= 0.0 or lt < fastest_lap) and status == Status.GREEN:
			fastest_lap = lt
			fastest_car = c
			if c.is_player or fl > laps / 2:
				make_log("fastest", "Schnellste Runde: %s  %s" % [c.code, fmt_time(lt)], c)
	c.lap_start = cross_t
	c.lap_noise = rng.randfn(0.0, track.lap_ref * 0.0022 * (1.35 - 0.7 * c.cons))
	c.tyre_age_laps += 1
	# Rennende
	if fl >= laps:
		if not leader_finished:
			leader_finished = true
			make_log("info", "%s sieht die Zielflagge als Erster!" % c.code, c)
		_finish(c, fl, cross_t)
		return
	if leader_finished:
		_finish(c, fl, cross_t)
		return
	# SC-Runden zählen (Führender)
	if status != Status.GREEN and c == _leader():
		status_laps_left -= 1
	# Taktik pro Runde (Modi, Teamorder), dann Boxenstopp-Entscheidung
	_lap_tactics(c, fl)
	_decide_pit(c, fl)


func _finish(c: RaceCar, fl: int, t: float) -> void:
	c.state = State.FINISHED
	finish_counter += 1
	c.finish_rank = finish_counter
	c.finish_time = t
	c.finish_laps = fl


func _leader() -> RaceCar:
	var best: RaceCar = null
	for c in cars:
		if c.state == State.RACING or c.state == State.PIT:
			if best == null or c.dist > best.dist:
				best = c
	return best


func _decide_pit(c: RaceCar, fl: int) -> void:
	var remaining := laps - fl
	var do_pit := false
	var comp := c.compound
	if c.pit_requested:
		do_pit = true
		comp = c.pit_comp
	else:
		for s in c.plan:
			if int(s["lap"]) == fl:
				do_pit = true
				comp = int(s["comp"])
		if not c.is_player:
			if c.react_lap >= 0 and fl >= c.react_lap and remaining > 3:
				do_pit = true
				comp = c.react_comp
				c.react_lap = -1
			var wc := _ai_weather_choice(c, remaining)
			if wc >= 0 and wc != c.compound and not do_pit and remaining > 1:
				do_pit = true
				comp = wc
				c.plan = []
			var life := life_eff(c.compound)
			var due: bool = c.tyre_wear > life * c.ai_threshold
			for s in c.plan:
				if int(s["lap"]) > fl and int(s["lap"]) - fl <= 8:
					if status != Status.GREEN and c.tyre_wear > life * 0.4:
						do_pit = true
						comp = int(s["comp"])
						c.plan.erase(s)
						break
			if due and remaining > 2 and not do_pit:
				do_pit = true
				comp = _choose_comp(c, remaining)
			if status != Status.GREEN and not do_pit and c.tyre_wear > life * 0.55 and remaining > 12 and c.pit_stops < 3:
				do_pit = true
				comp = _choose_comp(c, remaining)
			# KI-Undercut: stoppt früh, wenn der Gegner direkt vor ihm sonst nicht zu schlagen wäre
			if not do_pit and status == Status.GREEN and remaining > 10 and c.pit_stops < 2 and c.react_count < 1 and c.tyre_wear / life > 0.38:
				var ac := car_ahead(c)
				if ac != null and ac.team_id != c.team_id and c.gap_ahead < 2.6:
					var comp2 := _choose_comp(c, remaining)
					var adv := tyre_loss(ac) - fresh_loss(comp2)
					var margin := 2.0 * adv - c.gap_ahead - 0.8
					if margin > 0.6 and rng.randf() < 0.55 * c.react:
						do_pit = true
						comp = comp2
						c.react_count += 1
						if ac.is_player:
							make_log("radio", "Funk: %s versucht den Undercut gegen %s!" % [c.code, ac.code], c)
		# Zwei-Mischungen-Regel
	if not do_pit:
		return
	if remaining <= 0:
		return
	# Regel: mind. zwei verschiedene Mischungen in einem Trockenrennen
	var used: Array = c.used_compounds.duplicate()
	if not used.has(comp):
		used.append(comp)
	if int(rules["min_compounds"]) >= 2 and used.size() < 2 and remaining <= 22 and not rain_seen and comp < DRY_COUNT:
		comp = (c.compound + 1) % 3
	_enter_pit(c, comp, fl)


func _ai_weather_choice(c: RaceCar, remaining: int) -> int:
	var cur := c.compound
	if cur < DRY_COUNT:
		if wet > c.ai_wet_t:
			return 3 if wet < 0.58 else 4
	elif cur == 3:
		if wet > 0.66 + c.ai_wet_t * 0.3:
			return 4
		if wet < c.ai_dry_t and rain < 0.08:
			return _choose_comp(c, remaining)
	else:
		if wet < 0.42:
			return 3
	return -1


func _choose_comp(c: RaceCar, remaining: int) -> int:
	if remaining <= 14 and life_eff(0) >= remaining:
		return 0
	if remaining <= 26 and life_eff(1) >= remaining:
		return 1
	return 2


func _enter_pit(c: RaceCar, comp: int, fl: int) -> void:
	var stationary: float = float(rules["stationary"]) + rng.randfn(0.0, 0.35) + c.pit_skill
	var fuel_add := 0.0
	var new_fuel := c.fuel
	if rules["refuel"]:
		new_fuel = _fuel_for_stint_after_pit(c, fl)
		fuel_add = maxf(0.0, new_fuel - c.fuel)
		stationary = 1.2 + fuel_add / 9.0 + rng.randfn(0.0, 0.4) + c.pit_skill
	stationary = maxf(1.6, stationary)
	if rng.randf() < 0.025:
		stationary += rng.randf_range(2.5, 7.0)
		make_log("pit", "Langsamer Boxenstopp für %s" % c.code, c)
	var loss: float = track.pit_loss * float(rules["pit_loss_scale"]) - PIT_STATIONARY_BASE - 0.5 + stationary
	if status == Status.SC:
		loss *= 0.58
	elif status == Status.VSC:
		loss *= 0.72
	var wait := 0.0
	var mt := mate_of(c)
	if mt != null and mt.state == State.PIT:
		wait = DOUBLE_STOP_WAIT + rng.randf_range(0.0, 1.2)
		make_log("pit", "Doppelstopp: %s muss warten (+%.1f s)" % [c.code, wait], c)
	c.state = State.PIT
	# Zeit in der Boxengasse: der Zeitverlust bleibt gleich, das Auto gewinnt aber die Boxengassen-Strecke gutgeschrieben
	var avg_v: float = track.length / track.lap_ref * (0.45 if status == Status.SC else (0.65 if status == Status.VSC else 1.0))
	c.pit_timer = maxf(loss, 8.0) + wait + PIT_EXIT_DIST / avg_v
	c.pit_total = c.pit_timer
	c.pit_stat = stationary + wait
	c.sec_valid = false
	c.pit_comp = comp
	c.pit_requested = false
	c.fuel_after_pit = new_fuel
	make_log("pit", "Boxenstopp %s: %s -> %s (%.1f s)" % [c.code, COMPOUNDS[c.compound]["name"], COMPOUNDS[comp]["name"], stationary], c)
	_trigger_covers(c, fl)
	if not rules["refuel"]:
		var keep: Array = []
		var horizon: int = fl + int(life_eff(comp) * 0.4)
		for s in c.plan:
			if int(s["lap"]) > horizon:
				keep.append(s)
		c.plan = keep


func _fuel_for_stint_after_pit(c: RaceCar, fl: int) -> float:
	var to_lap := _next_stop_lap(c, fl)
	return burn_per_lap * float(to_lap - fl) + 1.5


func _pit_timers(dt: float) -> void:
	for c in cars:
		if c.state == State.PIT:
			c.pit_timer -= dt
			c.speed = 0.0
			if c.pit_timer <= 0.0:
				c.state = State.RACING
				c.compound = c.pit_comp
				c.tyre_wear = 0.0
				c.tyre_age_laps = 0
				c.pit_stops += 1
				c.dist += PIT_EXIT_DIST
				c.damage = 0.0
				if not c.used_compounds.has(c.compound):
					c.used_compounds.append(c.compound)
				c.fuel = c.fuel_after_pit if rules["refuel"] else c.fuel


# ------------------------------------------------------------------ Ausfälle, SC

func _roll_failures(dt: float, active: Array) -> void:
	var lt: float = track.lap_ref * 1.04
	var first_lap: bool = time < lt * 1.05
	for c in active:
		var hm: float = c.mech_rate / float(laps) / lt * dt
		var hc: float = c.crash_rate / float(laps) / lt * dt
		hm *= engine_hazard(c) * (float([0.9, 1.0, 1.15][c.ers_mode]) if has_ers() else float(ENG_HAZ[c.eng_mode]))
		hc *= 1.0 + 0.4 * (c.aggr - 0.5)
		if first_lap:
			hc *= 5.0
		if status != Status.GREEN:
			hc *= 0.3
		hc *= 1.0 + wet * 1.2
		if c.compound < DRY_COUNT and wet > 0.25:
			hc *= 1.0 + 6.0 * (wet - 0.25)
		elif c.compound == 3 and wet < 0.1:
			hc *= 1.4
		var r := rng.randf()
		if r < hm:
			_retire(c, "Technischer Defekt")
		elif r < hm + hc:
			_retire(c, "Unfall")


func _retire(c: RaceCar, reason: String) -> void:
	c.state = State.OUT
	c.out_reason = reason
	if reason == "Technischer Defekt" and engine_allowance > 0:
		c.engine_broken = true
		c.engine_wear = maxf(c.engine_wear, 1.25)
	c.order = {}
	c.speed = 0.0
	make_log("dnf", "AUSFALL: %s (%s)" % [c.code, reason], c)
	if status == Status.GREEN and not leader_finished:
		var r := rng.randf()
		var p_sc := (0.5 if reason == "Unfall" else 0.2) * (1.0 + wet)
		var left := laps - leader_lap()
		if left < 3:
			return
		if r < p_sc * 0.7:
			status = Status.SC
			status_laps_left = rng.randi_range(3, 5)
			sc_count += 1
			make_log("sc", "SAFETY CAR!")
		elif r < p_sc:
			status = Status.VSC
			status_laps_left = 2
			make_log("sc", "Virtual Safety Car")


func _update_status() -> void:
	if status != Status.GREEN and status_laps_left <= 0:
		if status == Status.SC:
			make_log("sc", "Safety Car kommt in die Box - Restart!")
		else:
			make_log("sc", "VSC beendet")
		status = Status.GREEN
	# gelegentliche Trümmer-Safety-Car (selten)


func _update_gaps() -> void:
	var order: Array = []
	for c in cars:
		if c.state == State.RACING or c.state == State.PIT:
			order.append(c)
	order.sort_custom(func(a, b): return a.dist > b.dist)
	if order.is_empty():
		return
	var lead: RaceCar = order[0]
	for k in order.size():
		var c: RaceCar = order[k]
		var p: float = maxf(c.cur_pace, 0.5)
		c.gap_leader = (track.time_at(lead.dist) - track.time_at(c.dist)) / p
		if k > 0:
			var a: RaceCar = order[k - 1]
			c.gap_ahead = (track.time_at(a.dist) - track.time_at(c.dist)) / p
		else:
			c.gap_ahead = 0.0


func _check_over() -> void:
	var live := 0
	for c in cars:
		if c.state == State.RACING or c.state == State.PIT:
			live += 1
	if live == 0 and started:
		over = true
		make_log("info", "Das Rennen ist beendet.")


# ------------------------------------------------------------------ Taktik: Modi, Teamorder, Undercut

func car_ahead(c: RaceCar) -> RaceCar:
	var best: RaceCar = null
	for o in cars:
		if o == c or o.state != State.RACING:
			continue
		if o.dist > c.dist and (best == null or o.dist < best.dist):
			best = o
	return best


func car_behind(c: RaceCar) -> RaceCar:
	var best: RaceCar = null
	for o in cars:
		if o == c or o.state != State.RACING:
			continue
		if o.dist < c.dist and (best == null or o.dist > best.dist):
			best = o
	return best


func mate_of(c: RaceCar) -> RaceCar:
	if c.mate_index < 0:
		return null
	return cars[c.mate_index]


## Wird für jedes Auto beim Überqueren der Linie aufgerufen: Ablauf von Befehlen, KI-Modi, KI-Teamorder.
func _lap_tactics(c: RaceCar, fl: int) -> void:
	if not c.order.is_empty() and int(c.order["until"]) < fl:
		var t: String = c.order["type"]
		if c.is_player or (mate_of(c) != null and mate_of(c).is_player):
			make_log("radio", "Teamorder (%s) für %s beendet." % [_order_name(t), c.code], c)
		c.order = {}
	if c.is_player:
		return
	var ahead := car_ahead(c)
	var behind := car_behind(c)
	var gap_a: float = c.gap_ahead if ahead != null else 99.0
	var gap_b: float = behind.gap_ahead if behind != null else 99.0
	if has_ers():
		var mode := 1
		if status != Status.GREEN:
			mode = 0
		elif gap_b < 1.2 and c.ers > 18.0:
			mode = 2
		elif gap_a < 1.4 and c.ers > 28.0 and rng.randf() < 0.5 + 0.4 * c.aggr:
			mode = 2
		elif c.ers < 38.0:
			mode = 0
		c.ers_mode = mode
	else:
		var m2 := 1
		if (gap_a < 1.2 or gap_b < 1.0) and c.engine_wear < 0.85 and status == Status.GREEN:
			m2 = 2
		elif c.engine_wear > 0.95 or (gap_a > 12.0 and gap_b > 12.0 and c.engine_wear > 0.5):
			m2 = 0
		c.eng_mode = m2
	_ai_team_orders(c, fl)


func _order_name(t: String) -> String:
	match t:
		"swap":
			return "Platztausch"
		"hold":
			return "Position halten"
		"block":
			return "Aufhalten"
	return t


func _ai_team_orders(c: RaceCar, fl: int) -> void:
	var m := mate_of(c)
	if m == null or m.state != State.RACING or c.state != State.RACING:
		return
	if not c.order.is_empty() or not m.order.is_empty():
		return
	if car_ahead(m) != c:
		c.duel_laps = 0
		return
	if m.gap_ahead < 1.3:
		c.duel_laps += 1
	else:
		c.duel_laps = 0
	if c.duel_laps < 2:
		return
	var faster := predicted_lap_time(c) - predicted_lap_time(m)
	var late := fl > int(float(laps) * 0.55)
	if faster > 0.25 and late and rng.randf() < 0.35:
		_issue_swap(c, m)
	elif c.duel_laps >= 3 and rng.randf() < 0.22:
		_issue_hold(c, m)


## Folgt der Fahrer dem Befehl? a = Befehlsempfänger. Hängt von Gehorsam, Aggressivität, Stimmung und Tempo ab.
func _complies(a: RaceCar, other: RaceCar, type: String) -> bool:
	var p := 0.30 + 0.65 * a.obey - 0.21 * a.aggr + 0.25 * (a.morale - 0.6)
	if type == "swap" and predicted_lap_time(other) < predicted_lap_time(a) - 0.2:
		p += 0.15
	if type == "block":
		p -= 0.05
	return rng.randf() < clampf(p, 0.05, 0.98)


## a (vorne) lässt b (dahinter, Teamkollege) vorbei. Rückgabe: Befehl befolgt?
func _issue_swap(a: RaceCar, b: RaceCar) -> bool:
	if _complies(a, b, "swap"):
		a.order = {"type": "swap", "partner": b.index, "until": leader_lap() + 5}
		make_log("radio", "Teamorder %s: %s soll %s vorbeilassen." % [a.team_name, a.code, b.code], a)
		return true
	make_log("radio", "%s ignoriert die Teamorder und fährt weiter!" % a.code, a)
	a.morale_delta += 0.01
	b.morale_delta -= 0.03
	return false


## Position halten: beide Autos dürfen sich nicht angreifen. Der Verfolger muss zustimmen.
func _issue_hold(a: RaceCar, b: RaceCar) -> bool:
	var lead: RaceCar = a if a.dist > b.dist else b
	var chaser: RaceCar = b if lead == a else a
	if _complies(chaser, lead, "hold"):
		var until := leader_lap() + 6
		lead.order = {"type": "hold", "partner": chaser.index, "until": until}
		chaser.order = {"type": "hold", "partner": lead.index, "until": until}
		if predicted_lap_time(chaser) < predicted_lap_time(lead) - 0.2:
			chaser.morale_delta -= 0.02
		make_log("radio", "Teamorder %s: Position halten, kein Zweikampf." % lead.team_name, lead)
		return true
	make_log("radio", "%s ignoriert 'Position halten' und greift weiter an!" % chaser.code, chaser)
	chaser.morale_delta += 0.01
	return false


func _trigger_covers(r: RaceCar, fl: int) -> void:
	var remaining := laps - fl
	if remaining < 8 or status != Status.GREEN:
		return
	for c in cars:
		if c == r or c.is_player or c.state != State.RACING or c.team_id == r.team_id or c.react_count >= 1:
			continue
		if absf(c.gap_leader - r.gap_leader) > 5.0:
			continue
		var age_frac: float = c.tyre_wear / life_eff(c.compound)
		if age_frac < 0.3 or c.pit_stops >= 3 or c.react_lap >= 0:
			continue
		var p: float = c.react * (0.25 + 0.9 * age_frac)
		if rng.randf() < p:
			var delay := rng.randi_range(1, 2)
			c.react_count += 1
			c.react_lap = fl + delay
			if r.is_player:
				make_log("radio", "Funk: %s reagiert auf deinen Boxenstopp und kontert in %d Runde(n)." % [c.code, delay], c)
			c.react_comp = _choose_comp(c, remaining - delay)


## Wirksamer Boxenzeitverlust jetzt (Safety Car macht Stopps billiger).
func pit_cost_now() -> float:
	var base: float = track.pit_loss * float(rules["pit_loss_scale"])
	if status == Status.SC:
		return base * 0.58
	if status == Status.VSC:
		return base * 0.72
	return base


## Undercut-Rechnung für c gegen das Auto direkt davor. margin > 0: Undercut sollte gelingen.
func undercut_info(c: RaceCar) -> Dictionary:
	var res := {"has": false}
	if c.state != State.RACING or not started:
		return res
	var a := car_ahead(c)
	if a == null or laps - leader_lap() < 6:
		return res
	var comp := _choose_comp(c, laps - leader_lap())
	var rc := recommended_compound()
	if rc >= 0:
		comp = rc
	var adv := tyre_loss(a) - fresh_loss(comp)
	var gap: float = c.gap_ahead
	var margin := 2.0 * adv - gap - 0.8
	return {"has": true, "car": a, "gap": gap, "adv": adv, "margin": margin, "comp": comp}


## Gefahr für c: Ein Verfolger könnte per Undercut vorbeikommen.
func threat_info(c: RaceCar) -> Dictionary:
	var res := {"has": false}
	if c.state != State.RACING or not started:
		return res
	var b := car_behind(c)
	if b == null or b.gap_ahead > 4.0 or laps - leader_lap() < 6:
		return res
	var comp := _choose_comp(b, laps - leader_lap())
	var adv := tyre_loss(c) - fresh_loss(comp)
	var margin := 2.0 * adv - b.gap_ahead - 0.8
	return {"has": true, "car": b, "gap": b.gap_ahead, "adv": adv, "margin": margin}


## Wohin würde c nach einem Stopp zurückkommen? {"pos", "ahead", "gap_ahead", "behind", "gap_behind"}
func rejoin_info(c: RaceCar) -> Dictionary:
	var loss := pit_cost_now()
	var rejoin: float = c.gap_leader + loss
	var pos := 1
	var ahead: RaceCar = null
	var ahead_g := -1.0
	var behind: RaceCar = null
	var behind_g := 1e9
	for o in cars:
		if o == c or (o.state != State.RACING and o.state != State.PIT):
			continue
		if o.gap_leader < rejoin:
			pos += 1
			if o.gap_leader > ahead_g:
				ahead_g = o.gap_leader
				ahead = o
		elif o.gap_leader < behind_g:
			behind_g = o.gap_leader
			behind = o
	return {"pos": pos, "ahead": ahead, "gap_ahead": rejoin - ahead_g if ahead != null else 0.0,
		"behind": behind, "gap_behind": behind_g - rejoin if behind != null else 0.0, "loss": loss}


# ------------------------------------------------------------------ Befehle (Taktik)

func set_ers_mode(c: RaceCar, m: int) -> void:
	c.ers_mode = clampi(m, 0, 2)


func set_engine_mode(c: RaceCar, m: int) -> void:
	c.eng_mode = clampi(m, 0, 2)


## Teamorder des Spielers. c = Auto, das den Befehl bekommt. Rückgabe: Meldung.
func order_swap(c: RaceCar) -> String:
	var m := mate_of(c)
	if m == null or m.state != State.RACING or c.state != State.RACING:
		return "Nicht möglich."
	if c.dist < m.dist:
		return "%s liegt bereits hinter dem Teamkollegen." % c.code
	_issue_swap(c, m)
	return ""


func order_hold(c: RaceCar) -> String:
	var m := mate_of(c)
	if m == null or m.state != State.RACING or c.state != State.RACING:
		return "Nicht möglich."
	_issue_hold(c, m)
	return ""


## Aufhalten (Schützenhilfe): c bremst einen Verfolger bewusst ein.
func order_block(c: RaceCar) -> String:
	if c.state != State.RACING:
		return "Nicht möglich."
	var b := car_behind(c)
	if b == null or b.team_id == c.team_id or b.gap_ahead > 3.0:
		return "Kein Rivale in Reichweite hinter %s." % c.code
	if _complies(c, b, "block"):
		c.order = {"type": "block", "partner": b.index, "until": leader_lap() + 3}
		c.morale_delta -= 0.02
		make_log("radio", "%s bremst %s bewusst ein (Schützenhilfe)." % [c.code, b.code], c)
	else:
		make_log("radio", "%s weigert sich, sein Rennen zu opfern." % c.code, c)
	return ""


func clear_orders(c: RaceCar) -> void:
	c.order = {}
	var m := mate_of(c)
	if m != null:
		m.order = {}


## Doppelstopp: beide Autos kommen am Rundenende mit der gleichen Mischung an die Box.
func double_stop(c: RaceCar, comp: int) -> void:
	request_pit(c, comp)
	var m := mate_of(c)
	if m != null and m.state == State.RACING:
		request_pit(m, comp)


# ------------------------------------------------------------------ Auswertung

func ranking() -> Array:
	if not started:
		return grid_order()
	var r: Array = cars.duplicate()
	r.sort_custom(_rank_less)
	return r


func _rank_less(a: RaceCar, b: RaceCar) -> bool:
	var ao := a.state == State.OUT
	var bo := b.state == State.OUT
	if ao != bo:
		return bo
	if ao and bo:
		return a.dist > b.dist
	var af := a.state == State.FINISHED
	var bf := b.state == State.FINISHED
	if af and bf:
		if a.finish_laps != b.finish_laps:
			return a.finish_laps > b.finish_laps
		return a.finish_rank < b.finish_rank
	if af != bf:
		return af
	return a.dist > b.dist


func laps_completed(c: RaceCar) -> int:
	return maxi(0, int(floor(c.dist / track.length)))


## Zielzeiten-Text für die Rangliste.
func gap_text(c: RaceCar, leader: RaceCar) -> String:
	if c.state == State.OUT:
		return "AUS"
	if c == leader:
		return "Führend"
	var ll := leader.floor_laps if leader.state != State.FINISHED else leader.finish_laps
	var cl := c.floor_laps if c.state != State.FINISHED else c.finish_laps
	if ll - cl >= 1:
		return "+%d Rd" % (ll - cl)
	if c.state == State.FINISHED and leader.state == State.FINISHED:
		return "+%.3f" % (c.finish_time - leader.finish_time)
	return "+%.1f" % c.gap_leader


func fmt_time(t: float) -> String:
	if t <= 0.0:
		return "--:--.---"
	var m := int(t / 60.0)
	return "%d:%06.3f" % [m, t - m * 60.0]


func fmt_race_time(t: float) -> String:
	var h := int(t / 3600.0)
	var m := int((t - h * 3600.0) / 60.0)
	var s := t - h * 3600.0 - m * 60.0
	return "%d:%02d:%04.1f" % [h, m, s]


## Grobe Renndauerschätzung (s) für einen Strategieplan, ohne Verkehr/Ereignisse.
func estimate_time(c: RaceCar, start_comp: int, plan: Array) -> float:
	var comp := start_comp
	var wear := 0.0
	var total := 0.0
	var stops_by_lap := {}
	for s in plan:
		stops_by_lap[int(s["lap"])] = int(s["comp"])
	var fuel := burn_per_lap * float(laps) + 1.5
	if rules["refuel"]:
		var first := laps
		for s in plan:
			first = mini(first, int(s["lap"]))
		fuel = burn_per_lap * float(first) + 1.5
	var sev: float = track.tyre_severity
	for lap in range(1, laps + 1):
		var cd: Dictionary = COMPOUNDS[comp]
		var life := life_eff(comp)
		var w_mid := wear + 0.5
		var loss: float = float(cd["offset"]) + float(cd["deg"]) * sev * w_mid
		if w_mid > life:
			loss += 0.30 * pow(w_mid - life, 1.35)
		loss *= scale_time
		var floss := fuel * FUEL_TIME * scale_time
		var p: float = c.pace_base / (1.0 + (loss + floss) / track.lap_ref)
		total += track.lap_ref / p
		wear += 1.0
		fuel = maxf(0.0, fuel - burn_per_lap)
		if stops_by_lap.has(lap) and lap < laps:
			comp = stops_by_lap[lap]
			wear = 0.0
			total += track.pit_loss * float(rules["pit_loss_scale"])
			if rules["refuel"]:
				var nxt := laps
				for s in plan:
					if int(s["lap"]) > lap:
						nxt = mini(nxt, int(s["lap"]))
				fuel = burn_per_lap * float(nxt - lap) + 1.5
	return total

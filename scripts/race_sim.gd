extends RefCounted
## Rennsimulation (Distanzmodell mit Referenz-Geschwindigkeitsprofil), Zeitschritt = 1 s Rennzeit.
## Enthält: Qualifying, Start, Reifenverschleiß, Sprit, Boxenstopps, Überholen (DRS), Ausfälle,
## Safety Car / VSC, KI-Strategie. Bedienbar von der Oberfläche über set_style(), request_pit(), set_plan().

const COMPOUNDS := [
	{"name": "Soft", "short": "S", "color": Color(0.95, 0.15, 0.15), "ink": Color(0.84, 0.09, 0.09), "offset": 0.0, "deg": 0.125, "life": 17.0, "warm": 0.30},
	{"name": "Medium", "short": "M", "color": Color(1.0, 0.85, 0.1), "ink": Color(0.74, 0.54, 0.0), "offset": 0.80, "deg": 0.066, "life": 32.0, "warm": 0.70},
	{"name": "Hard", "short": "H", "color": Color(0.92, 0.92, 0.92), "ink": Color(0.30, 0.34, 0.42), "offset": 1.50, "deg": 0.034, "life": 44.0, "warm": 1.30},
	{"name": "Inter", "short": "I", "color": Color(0.2, 0.8, 0.3), "ink": Color(0.07, 0.55, 0.22), "offset": 0.0, "deg": 0.05, "life": 34.0, "warm": 0.40},
	{"name": "Wet", "short": "W", "color": Color(0.25, 0.5, 1.0), "ink": Color(0.12, 0.38, 0.88), "offset": 0.0, "deg": 0.04, "life": 44.0, "warm": 0.40},
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
# Tempo (Fahrstil) in fünf Stufen wie am Kommandostand; 0 = Reifen schonen, 2 = Standard, 4 = Angriff
const STYLE_NAMES := ["Reifen schonen", "Ruhig", "Standard", "Zügig", "Angriff"]
const STYLE_PACE := [-0.0065, -0.0030, 0.0, 0.0024, 0.0045]
const STYLE_WEAR := [0.78, 0.89, 1.0, 1.15, 1.32]   # Schonen: etwa +28 % Lebensdauer in freier Fahrt (plus kühlere Reifen)
const SC_WEAR := [1.0, 0.45, 0.3]     # Verschleiß je Runde bei Grün / VSC / Safety Car
const SC_FUEL := [1.0, 0.7, 0.6]      # Verbrauch je Runde bei Grün / VSC / Safety Car
const STYLE_FUEL := [0.95, 0.98, 1.0, 1.01, 1.02]    # Tempo kostet etwas Sprit, aber nur wenig (Hauptregler bleibt der Kraftstoffmodus)
const STYLE_STD := 2
# Reifentemperatur (°C): Arbeitsfenster je Mischung (Mitte ± TYRE_WIN); Tempo heizt auf oder kühlt
const TYRE_OPT := [95.0, 100.0, 105.0, 80.0, 70.0]
const TYRE_WIN := 10.0
const STYLE_TEMP := [-9.0, -4.5, 0.0, 4.5, 9.0]
const TYRE_TAU := 35.0              # s, so schnell folgt die Temperatur dem Zielwert
const STYLE_MAX := 4
const FUEL_PER_KM := 0.34       # kg pro km
const FUEL_TIME := 0.03         # s pro kg und Runde
# Kraftstoffmodus (Mischung) des Spielers: Sparen / Normal / Push, gilt bis zur Umstellung
const FUEL_MODE_NAMES := ["Sparen", "Normal", "Push"]
const FUEL_MODE_BURN := [0.97, 1.0, 1.04]      # Sparen 3 % weniger, Push 4 % mehr Sprit
const FUEL_MODE_PACE := [-0.0007, 0.0, 0.0011] # etwa -0,05 s / +0,09 s pro Runde
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
const SC_CLOSE_GAP := 26.0      # Abstand im Safety-Car-Zug (m), ab dem nicht mehr aufgeschlossen wird
const TOW_RANGE := 1.25        # Windschatten wirkt bis etwa 1,25 s Abstand
const TOW_MAX := 0.024          # max. Geschwindigkeitsgewinn im Windschatten (auf schnellen Geraden)
const DIRTY_MAX := 0.011        # Verlust durch verwirbelte Luft in langsamen Kurven
const FUEL_CAP_REFUEL := 150.0
const FUEL_CAP_MODERN := 110.0
const FUEL_RESERVE := 1.5
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
	var prev_dist := 0.0
	var floor_laps := -1
	var lap_start := 0.0
	var last_lap := 0.0
	var best_lap := 0.0
	var lap_noise := 0.0
	var compound := 1
	var tyre_wear := 0.0
	var tyre_age_laps := 0
	var tyre_temp := 90.0      # Reifentemperatur (°C), siehe TYRE_OPT
	var used_compounds: Array = []
	var fuel := 100.0
	var style := STYLE_STD
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
	# Windschatten, Zweikämpfe, Sprit, Auto-Profil
	var follow := true         # Dranbleiben (Windschatten, Angriff) oder Abstand halten (Reifen schonen)
	var close_time := 0.0      # Sekunden dichtes Folgen (<1 s) - erhöht die Angriffschance
	var revenge_idx := -1
	var revenge_until := 0.0
	var tow := 0.0             # aktueller Windschatten-Effekt 0..1 (Anzeige)
	var fit := 0.0             # Streckeneignung des Autos (Pace-Anteil)
	var team_wet := 0.0
	var tyre_care := 0.0
	var fuel_extra := 0.0      # Zusatz-Spritmenge zum Start (Runden, auch negativ)
	var pit_fuel_laps := -1.0  # Nachtanken beim nächsten Stopp: Runden Sprit (-1 = automatisch)
	var fuel_warn_stint := -1
	var passes_made := 0
	var passes_lost := 0
	var stint_log: Array = []  # abgeschlossene Stints: [{"a": Start-Runde, "b": End-Runde, "comp": Mischung}]
	var stint_start := 0
	# Regeln, Funkanweisungen, Fahrer-Rückmeldung
	var rules := {}            # Wenn-Dann-Regeln des Spielers: sc_pit, rain_switch, dry_switch, defend, fuel_save
	var radio_kind := ""
	var radio_until := -1
	var lico := false          # Lift and Coast: weniger Sprit, etwas langsamer
	var fuel_mode := 1        # Mischung: 0 Sparen, 1 Normal, 2 Push
	var fb_stage := 0
	var set_used := 0.0        # Vorbelastung des montierten Reifensatzes (Runden)
	var last_pit_lap := -99
	var plan_note := ""        # Hinweis nach automatischer Plan-Anpassung (Anzeige im Boxen-Fenster)
	var trouble_t := 0.0       # Sekunden Langsamfahrt nach Dreher, Kontakt oder Reifenschaden
	var stint_form := 0.0      # Form auf dem aktuellen Reifensatz (Reifenfenster, Verkehr, Gefühl), wechselt mit jedem Stopp
	var req_cd := 0              # Funkanfragen: frühestens wieder ab dieser Runde
	var close_laps := 0          # Runden dicht (unter 1 s) hinter dem Vordermann
	var chase_laps := 0          # Runden, in denen ich schneller bin als der Teamkollege direkt vor mir
	var problem_lap := -1        # Runde, in der der Fahrer eine Unregelmäßigkeit meldet (-1 = keine)
	var problem_real := false    # echtes Problem oder Fehlalarm
	var fail_lap := -1           # Runde, in der das Auto wegen eines ignorierten Problems ausfällt
	var req_tyre_stint := -1     # Stint, für den schon eine Reifen-Anfrage kam
	var req_fuel_stint := -1     # Stint, für den schon eine Sprit-Anfrage kam
	var launch := 0.0          # Startreaktion: positiv = guter Start, negativ = Durchdrehen/Verschalten


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
var pass_total := 0           # Überholmanöver auf der Strecke (ohne Boxen)
var pass_first_lap := 0
var vis_frac := 1.0           # Darstellung: Bruchteil des letzten Zeitschritts (für flüssige Bewegung)
var requests_on := true           # Anfragen des Fahrers an die Box (Entscheidungskarten) ein
var requests: Dictionary = {}    # Auto-Index -> offene Anfrage
var request_serial := 0
var decision_log: Array = []     # Entscheidungen des Spielers mit Auswertung: [{"lap", "car", "code", "kind", "choice", "pos0", "done", "result"}]
var incidents_on := true         # Zwischenfälle (Dreher, Schaden, Reifenschaden) ein; Tests schalten sie ab
var status_serial := 0          # zählt Safety-Car-/VSC-Phasen (für Entscheidungskarten)
var sc_marks: Array = []      # [{"lap", "end", "kind"}] Safety-Car-/VSC-Phasen für die Zeitleiste
var tyre_inv := {}            # Auto-Index -> Reifensätze [{"comp", "used" (Runden), "raced"}]
var crew_form := 0.0          # Form der Boxencrew des Spielers 0..1 (Stopp-Training)
var player_slow_k := 1.0      # Crew-Chef des Spielers: Faktor für verpatzte Stopps
var _src := {}                # Eingaben von setup() für Vorschau-Läufe
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
		var form := rng.randfn(0.0, 0.0014)
		var affinity := rng.randfn(0.0, 0.0016)
		var team_react := clampf(rng.randfn(0.72, 0.15), 0.4, 1.0)
		var quality := clampf((float(t["pace"]) - worst_pace) / maxf(best_pace - worst_pace, 0.001), 0.0, 1.0)
		var team_err := absf(rng.randfn(0.0, 0.40 - 0.22 * quality))
		var first_idx := idx
		var solo_pick := ""      # 1-Fahrer-Modus: nur dieser Fahrer des Spielerteams ist ein Spielerauto
		if t["id"] == player_team and Game.solo_code != "" and not t["drivers"].is_empty():
			solo_pick = str(t["drivers"][0]["code"])
			for d0 in t["drivers"]:
				if str(d0["code"]) == Game.solo_code:
					solo_pick = Game.solo_code
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
			c.is_player = (t["id"] == player_team) and (solo_pick == "" or str(d["code"]) == solo_pick)
			c.skill = d["skill"]
			var prof: Dictionary = t.get("profile", {})
			c.fit = track_fit(prof)
			c.team_wet = float(prof.get("wet", 0.0))
			c.tyre_care = float(prof.get("tyre", 0.0))
			# Tagesform des Fahrers: Rennpace weicht von der Qualifying-Pace ab (Mischfeld, mehr Überholungen), mit seltenen schlechten und guten Tagen
			var race_dev := rng.randfn(0.0, 0.0043)
			var day := rng.randf()
			if day < 0.10:
				race_dev -= absf(rng.randfn(0.0, 0.0035))
			elif day > 0.95:
				race_dev += absf(rng.randfn(0.0, 0.0015))
			# Stimmung des Fahrers: sehr gut gelaunt etwa +0,15 %, sehr schlecht etwa -0,15 % Tempo
			var mood := (float(d.get("morale", 0.62)) - 0.62) * 0.004
			c.pace_base = float(t["pace"]) * (1.0 + float(d["skill"]) + form + affinity + c.fit + race_dev + mood)
			c.qpace = float(t["pace"]) * (1.0 + float(d["skill"]) * 0.6 + float(d["qskill"]) + form + affinity + c.fit + race_dev * 0.35 + mood * 0.6 + rng.randfn(0.0, 0.0026))
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
	_src = {"teams": teams}
	for t in teams:
		if t["id"] == p_player_team:
			crew_form = clampf(float(t.get("crew_form", 0.0)), 0.0, 1.0)
			# Personal: Crew-Chef (verpatzte Stopps), Chefstratege (Prognosefehler, Reifenwissen)
			player_slow_k = float(t.get("slow_k", 1.0))
			forecast_noise *= float(t.get("forecast_k", 1.0))
			if bool(t.get("tyre_known", false)):
				practice["tyre_known"] = true
	for c in cars:
		init_tyres(c)


# ------------------------------------------------------------------ Reifensätze

## Sätze pro Wochenende [Soft, Medium, Hard, Inter, Wet]; leer = unbegrenzt (vor 2007).
func tyre_alloc() -> Array:
	if year < 2007:
		return []
	var d: Array = [2, 3, 8] if year >= 2022 else ([3, 4, 6] if year >= 2016 else [4, 4, 5])
	return [d[0], d[1], d[2], 4 if year >= 2016 else 3, 3 if year >= 2016 else 2]


func tyre_unlimited() -> bool:
	return tyre_alloc().is_empty()


func init_tyres(c: RaceCar) -> void:
	var inv: Array = []
	var a := tyre_alloc()
	for comp in a.size():
		for k in int(a[comp]):
			inv.append({"comp": comp, "used": 0.0, "raced": false})
	tyre_inv[c.index] = inv


## {"new": Anzahl neuer, "used": Anzahl gebrauchter, "free": davon noch nicht im Rennen verbaut, "laps": Durchschnitt Vorbelastung}
func tyre_count(c: RaceCar, comp: int) -> Dictionary:
	var res := {"new": 0, "used": 0, "free": 0, "laps": 0.0}
	if tyre_unlimited():
		res["new"] = 99
		res["free"] = 99
		return res
	var tot := 0.0
	for s in tyre_inv.get(c.index, []):
		if int(s["comp"]) != comp:
			continue
		if float(s["used"]) <= 0.0:
			res["new"] = int(res["new"]) + 1
		else:
			res["used"] = int(res["used"]) + 1
			tot += float(s["used"])
		if not bool(s["raced"]):
			res["free"] = int(res["free"]) + 1
	if int(res["used"]) > 0:
		res["laps"] = tot / float(res["used"])
	return res


## Satz einer Mischung belasten (Training/Qualifying). prefer_new: zuerst neue Sätze.
func tyre_use(c: RaceCar, comp: int, laps_add: float, prefer_new: bool) -> void:
	if tyre_unlimited():
		return
	var best: Dictionary = {}
	for s in tyre_inv.get(c.index, []):
		if int(s["comp"]) != comp or bool(s["raced"]):
			continue
		if best.is_empty():
			best = s
		elif prefer_new and float(s["used"]) < float(best["used"]):
			best = s
		elif not prefer_new and float(s["used"]) > float(best["used"]):
			best = s
	if not best.is_empty():
		best["used"] = float(best["used"]) + laps_add


## Satz für das Rennen montieren (neu zuerst, sonst der am wenigsten gebrauchte). Rückgabe: {"ok", "used"}; ok=false: kein Satz mehr.
func tyre_fit_race(c: RaceCar, comp: int) -> Dictionary:
	if tyre_unlimited():
		return {"ok": true, "used": 0.0}
	var best: Dictionary = {}
	for s in tyre_inv.get(c.index, []):
		if int(s["comp"]) != comp or bool(s["raced"]):
			continue
		if best.is_empty() or float(s["used"]) < float(best["used"]):
			best = s
	if best.is_empty():
		return {"ok": false, "used": 0.0}
	best["raced"] = true
	return {"ok": true, "used": float(best["used"])}


## Reifenbedarf eines Plans je Mischung (Anzahl Sätze).
func plan_tyre_need(start_comp: int, plan: Array) -> Dictionary:
	var need := {start_comp: 1}
	for s in plan:
		need[int(s["comp"])] = int(need.get(int(s["comp"]), 0)) + 1
	return need


## Streckeneignung eines Autos: Abtriebs-/Topspeed-Charakter gegen die Anforderungen der Strecke (Anteil an der Pace).
func track_fit(prof: Dictionary) -> float:
	if prof.is_empty():
		return 0.0
	var df: float = float(prof.get("df", 0.0))
	var pw: float = float(prof.get("power", 0.0))
	return df * track.df_need() * 0.0032 + pw * track.power_need() * 0.0026


## Aufschlüsselung für die Anzeige: Sekunden pro Runde Vor-/Nachteil.
func fit_report(prof: Dictionary) -> Dictionary:
	var df: float = float(prof.get("df", 0.0))
	var pw: float = float(prof.get("power", 0.0))
	var s_df: float = df * track.df_need() * 0.0032 * track.lap_ref
	var s_pw: float = pw * track.power_need() * 0.0026 * track.lap_ref
	return {"df": s_df, "power": s_pw, "total": s_df + s_pw, "tyre": float(prof.get("tyre", 0.0)), "wet": float(prof.get("wet", 0.0))}


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
	for pc in cars:
		if pc.is_player:
			match kind:
				"setup":
					tyre_use(pc, 1, 6.0, false)
				"tyres":
					for cmp in 3:
						tyre_use(pc, cmp, 4.0, false)
				"longrun":
					tyre_use(pc, 1, 12.0, false)
				"quali":
					tyre_use(pc, 0, 3.0, false)
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


## Regenintensität (0..1) zum Zeitpunkt t für ein Regenereignis rs..re mit Spitze pk.
func _rain_curve(t: float, rs: float, re: float, pk: float) -> float:
	if re <= 0.0 or t < rs or t >= re:
		return 0.0
	if rs < 0.0:
		return pk * clampf(1.0 - t / re, 0.0, 1.0)
	var u: float = (t - rs) / maxf(re - rs, 1.0)
	return pk * pow(sin(PI * clampf(u, 0.0, 1.0)), 0.7)


func _update_weather(dt: float) -> void:
	var target := _rain_curve(time, rain_start, rain_end, rain_peak)
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


## Niederschlag in mm/h aus der Intensität 0..1.
static func mm_per_h(i: float) -> float:
	return 12.0 * i * i


static func rain_label(i: float) -> String:
	var mm := mm_per_h(i)
	if mm < 0.2:
		return "kein Regen"
	if mm < 2.5:
		return "leichter Regen"
	if mm < 7.6:
		return "mäßiger Regen"
	return "starker Regen"


## Durchschnittliche Rundenzeit für Prognosen (Rennzeit je Runde).
func avg_lap_time() -> float:
	return track.lap_ref * 1.04


func lap_at_time(t: float) -> int:
	return clampi(1 + int(t / avg_lap_time()), 1, laps)


## Wetterbericht: Balken über die restliche Renndauer plus Zusammenfassung.
## Die Vorhersage ist umso unschärfer, je weiter sie in die Zukunft reicht; Fehlalarme sind möglich.
## {"bins": [{"t0","t1","lap0","lap1","i" (Intensität), "conf" (Sicherheit)}], "has", "start_min", "end_min", "start_lap", "end_lap",
##  "peak", "peak_mm", "label", "conf", "chance", "now_label", "temp_air", "temp_track", "dur_min"}
func forecast_report(n_bins := 16) -> Dictionary:
	var rs := rain_start
	var re := rain_end
	var pk := rain_peak
	var real: bool = rain_end > 0.0
	if not real and ghost_end > 0.0:
		rs = ghost_start
		re = ghost_end
		pk = 0.5
	var total: float = float(laps) * avg_lap_time()
	var t_from := maxf(time, 0.0)
	var span := maxf(total - t_from, 60.0)
	var res := {"bins": [], "has": false, "chance": rain_chance, "now_label": rain_label(rain), "peak": 0.0}
	var best_i := 0.0
	var first_t := -1.0
	var last_t := -1.0
	for k in n_bins:
		var t0: float = t_from + span * float(k) / float(n_bins)
		var t1: float = t_from + span * float(k + 1) / float(n_bins)
		var tm := 0.5 * (t0 + t1)
		var lead_min: float = (tm - time) / 60.0
		var conf := clampf(0.97 - lead_min / 120.0, 0.35, 0.97)
		# Prognosefehler: Zeitversatz und Stärke wachsen mit der Vorlaufzeit
		var shift: float = forecast_noise * 60.0 * clampf(lead_min / 25.0, 0.2, 2.0)
		var i_pred := 0.0
		if re > 0.0:
			i_pred = _rain_curve(tm - shift, rs, re, pk) * (1.0 + forecast_noise * 0.04 * clampf(lead_min / 40.0, 0.0, 1.0))
		i_pred = clampf(i_pred, 0.0, 1.0)
		res["bins"].append({"t0": t0, "t1": t1, "lap0": lap_at_time(t0), "lap1": lap_at_time(t1), "i": i_pred, "conf": conf})
		if i_pred > 0.08:
			if first_t < 0.0:
				first_t = t0
			last_t = t1
			best_i = maxf(best_i, i_pred)
	if first_t >= 0.0 or (re > 0.0 and time < re):
		res["has"] = first_t >= 0.0
	if res["has"]:
		var lead_min2: float = (first_t - time) / 60.0
		var conf2 := clampf(0.97 - lead_min2 / 120.0, 0.35, 0.97) * (1.0 if real else 0.55)
		res["start_min"] = maxf(0.0, (first_t - time) / 60.0)
		res["end_min"] = (last_t - time) / 60.0
		res["dur_min"] = maxf(1.0, (last_t - first_t) / 60.0)
		res["start_lap"] = lap_at_time(first_t)
		res["end_lap"] = lap_at_time(last_t)
		res["peak"] = best_i
		res["peak_mm"] = mm_per_h(best_i)
		res["label"] = rain_label(best_i)
		res["conf"] = conf2
		res["now_rain"] = rain > 0.04
	# Temperatur (Anzeige): Klima grob aus der Breite, Regen kühlt
	res["temp_air"] = 14 + int(16.0 * (1.0 - rain_chance * 1.5)) - int(5.0 * rain)
	res["temp_track"] = int(res["temp_air"]) + 12 - int(14.0 * wet)
	return res


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
		if c.is_player:
			var qc = q.qcar_of(c)
			if qc != null:
				for ph in 3:
					var pcmp: int = int(qc.phase_comp[ph])
					if pcmp >= 0:
						tyre_use(c, pcmp, 3.0 if ph < 2 else 2.0, true)
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

func default_plan(c: RaceCar, force_stops := -1) -> Dictionary:
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
	if force_stops >= 0:
		stops = force_stops
	var comps: Array = []
	var stint := float(laps) / float(stops + 1)
	var start: int
	var first_len := 0.0      # > 0: der erste Stint ist durch die vorgegebene Startmischung begrenzt
	if c.forced_start >= 0:
		start = c.forced_start
		var cap0 := maxf(life_eff(start) - 3.0, 4.0) * 0.9      # der Q2-Satz ist schon ein paar Runden alt
		if cap0 < stint:
			first_len = cap0
			stops = maxi(stops, 1)
			while stops < 4 and (float(laps) - first_len) / float(stops) > life_eff(2) * 0.98:
				stops += 1
			stint = (float(laps) - first_len) / float(stops)
	else:
		start = _pick_start_compound(stint)
	comps.append(start)
	for k in stops:
		var best := 1
		var cands: Array = []
		for cc in 3:
			if life_eff(cc) >= stint * 0.95:
				cands.append(cc)
		if cands.is_empty():
			best = 2
		else:
			best = _pick_weighted_comp(cands, stint, [1.0, 1.0, 1.0])
		comps.append(best)
	if min_c >= 2 and stops >= 1:
		var distinct := {}
		for x in comps:
			distinct[x] = true
		if distinct.size() < 2:
			# andere Mischung für den letzten Stint, die ihn auch durchhält (sonst die Startmischung ändern)
			var li: int = comps.size() - 1
			var alts: Array = []
			for cc in 3:
				if cc != int(comps[li]) and life_eff(cc) >= stint * 0.95:
					alts.append(cc)
			if not alts.is_empty():
				comps[li] = _pick_weighted_comp(alts, stint, [1.0, 1.0, 1.0])
			elif c.forced_start < 0:
				var alts0: Array = []
				for cc in 3:
					if cc != int(comps[0]) and life_eff(cc) >= (first_len if first_len > 0.0 else stint) * 0.95:
						alts0.append(cc)
				if not alts0.is_empty():
					comps[0] = _pick_weighted_comp(alts0, stint, [1.0, 1.0, 1.0])
					start = int(comps[0])
			var distinct2 := {}
			for x2 in comps:
				distinct2[x2] = true
			if distinct2.size() < 2 and stops < 4 and force_stops < 4:
				return default_plan(c, stops + 1)      # mit mehr Stopps halten auch weichere Mischungen die kürzeren Stints durch
	# Stintlängen nach Haltbarkeit der Mischung: weiche Reifen kürzer, harte länger
	var lens: Array = []
	var wsum := 0.0
	for cmp in comps:
		var wv := pow(life_eff(int(cmp)), 0.8)
		lens.append(wv)
		wsum += wv
	var lens_ok := true
	for i in lens.size():
		lens[i] = float(laps) * float(lens[i]) / wsum
		if float(lens[i]) > life_eff(int(comps[i])) * 0.98:
			lens_ok = false
	if first_len > 0.0:
		lens_ok = false
	if not lens_ok:
		for i in lens.size():
			lens[i] = stint
		if first_len > 0.0:
			lens[0] = first_len
	var plan: Array = []
	var acc := 0.0
	for k in stops:
		acc += float(lens[k])
		var lap := int(round(acc + rng.randf_range(-3.5, 3.5)))
		lap = clampi(lap, 3 + k, laps - 3)
		plan.append({"lap": lap, "comp": comps[k + 1]})
	# Jeder Stint soll zur Haltbarkeit seiner Mischung passen; geht das nicht auf, kommt ein Stopp dazu
	var prev_lap := 0
	for k in plan.size():
		var cap_l: int = int(floor(maxf(life_eff(int(comps[k])) - (3.0 if k == 0 and c.forced_start >= 0 else 0.0), 4.0) * 0.9))
		var lap2: int = mini(int(plan[k]["lap"]), prev_lap + cap_l)
		lap2 = maxi(lap2, prev_lap + 3)
		plan[k]["lap"] = lap2
		prev_lap = lap2
	if not plan.is_empty():
		var cap_last: int = int(floor(life_eff(int(comps[comps.size() - 1])) * 0.9))
		if laps - prev_lap > cap_last and stops < 4 and force_stops < 4:
			return default_plan(c, stops + 1)
	return {"start": start, "plan": plan}


## Mittlerer Zeitverlust (s pro Runde) einer Mischung über einen Stint von n Runden, ohne Verkehr (für die KI-Wahl).
func stint_cost(comp: int, n: float) -> float:
	var cd: Dictionary = COMPOUNDS[comp]
	var nn := maxf(n, 1.0)
	return float(cd["offset"]) + float(cd["deg"]) * track.tyre_severity * nn * 0.5 + float(cd["warm"]) * 1.5 / nn


## Zufällige Wahl unter den Mischungen, die den Stint durchhalten; schnellere Mischungen sind wahrscheinlicher.
func _pick_weighted_comp(cands: Array, stint: float, base_w: Array) -> int:
	var cmin := 99.0
	for k in cands:
		cmin = minf(cmin, stint_cost(int(k), stint))
	var ws: Array = []
	var total := 0.0
	for k in cands:
		var w: float = float(base_w[int(k)]) * exp(-(stint_cost(int(k), stint) - cmin) / 0.4)
		ws.append(w)
		total += w
	var r := rng.randf() * total
	for i in cands.size():
		r -= float(ws[i])
		if r <= 0.0:
			return int(cands[i])
	return int(cands[cands.size() - 1])


func _pick_start_compound(stint: float) -> int:
	var cands: Array = []
	for k in DRY_COUNT:
		if life_eff(k) >= stint * 0.92:
			cands.append(k)
	if cands.is_empty():
		return 2
	return _pick_weighted_comp(cands, stint, [0.35, 0.4, 0.25])


func _plan_ai(c: RaceCar) -> void:
	var p := default_plan(c)
	var mt := mate_of(c)
	if mt != null and mt.index < c.index and not mt.plan.is_empty() and not c.is_player and not mt.is_player and wet < 0.2:
		p = _split_from_mate(c, mt, p)
	c.compound = p["start"]
	c.plan = p["plan"]
	c.used_compounds = [c.compound]
	c.ai_threshold = rng.randf_range(0.92, 1.02)
	c.ai_wet_t = clampf(rng.randfn(0.17, 0.05), 0.07, 0.3)
	c.ai_dry_t = clampf(rng.randfn(0.12, 0.04), 0.04, 0.2)
	c.fuel = _fuel_for_stint(c, 0)


## Teams verteilen ihre Autos gern auf verschiedene Strategien (früh/spät, andere Startmischung, anderer Stopp-Anzahl).
func _split_from_mate(c: RaceCar, mt: RaceCar, p: Dictionary) -> Dictionary:
	var plan: Array = p["plan"]
	var same_start: bool = int(p["start"]) == mt.compound
	var near := false
	if plan.size() == mt.plan.size() and not plan.is_empty():
		near = absi(int(plan[0]["lap"]) - int(mt.plan[0]["lap"])) <= 4
	if not (same_start or near) or rng.randf() > 0.75:
		return p
	var mode := rng.randi() % 3
	if mode == 0 and not plan.is_empty():
		var shift: int = rng.randi_range(4, 7) * (1 if rng.randf() < 0.5 else -1)
		var prev := 2
		var out: Array = []
		for s in plan:
			var lap := clampi(int(s["lap"]) + shift, prev + 4, laps - 3)
			out.append({"lap": lap, "comp": s["comp"]})
			prev = lap
		if out[out.size() - 1]["lap"] <= prev - 4 or out[0]["lap"] < 3:
			return p
		return {"start": p["start"], "plan": out}
	if mode == 1:
		var q := default_plan(c, plan.size() + (1 if plan.size() < 3 and rng.randf() < 0.5 else (-1 if plan.size() > 1 else 0)))
		return q
	var alt := default_plan(c)
	if int(alt["start"]) == mt.compound:
		alt["start"] = (int(alt["start"]) + 1) % DRY_COUNT
		if life_eff(int(alt["start"])) < float(laps) / float(int(alt["plan"].size()) + 1) * 0.92:
			return p
	return alt


func _next_stop_lap(c: RaceCar, after_lap: int) -> int:
	for s in c.plan:
		if int(s["lap"]) > after_lap:
			return int(s["lap"])
	return laps


func fuel_cap() -> float:
	return FUEL_CAP_REFUEL if rules["refuel"] else FUEL_CAP_MODERN


## Tankinhalt (kg) für Runden Sprit inklusive Reserve.
func fuel_for_laps(n: float) -> float:
	return clampf(burn_per_lap * maxf(n, 0.0) + FUEL_RESERVE, 3.0, fuel_cap())


func _fuel_for_stint(c: RaceCar, from_lap: int) -> float:
	var to_lap := laps
	if rules["refuel"]:
		to_lap = _next_stop_lap(c, from_lap)
	return fuel_for_laps(float(to_lap - from_lap) + (c.fuel_extra if from_lap == 0 else 0.0))


## Spritverbrauch pro Runde mit Fahrstil und Motormodus.
func burn_now(c: RaceCar) -> float:
	var m: float = STYLE_FUEL[c.style] * (0.94 if c.lico else 1.0) * float(FUEL_MODE_BURN[c.fuel_mode])
	if not has_ers():
		m *= float(ENG_FUEL[c.eng_mode])
	return burn_per_lap * m


## Wie viele Runden reicht der Tank noch (bei aktuellem Verbrauch)?
func fuel_range(c: RaceCar) -> float:
	return maxf(0.0, (c.fuel - 0.3) / maxf(burn_now(c), 0.01))


## Runden (mit Bruchteil) bis zum nächsten Tankstopp bzw. Rennende, gemessen an der Position des Autos.
func fuel_need(c: RaceCar) -> float:
	var target_lap := laps
	if rules["refuel"]:
		target_lap = _next_stop_lap(c, maxi(c.floor_laps, 0))
	return maxf(0.0, float(target_lap) - c.dist / track.length)


## Runden bis zum nächsten geplanten Stopp bzw. Rennende (ab der aktuellen Runde).
func laps_to_refuel_point(c: RaceCar, cur_lap: int) -> int:
	if rules["refuel"]:
		return _next_stop_lap(c, cur_lap) - cur_lap
	return laps - cur_lap


func set_fuel_extra(c: RaceCar, extra_laps: float) -> void:
	c.fuel_extra = clampf(extra_laps, -6.0, 40.0)
	if not started:
		c.fuel = _fuel_for_stint(c, 0)


# ------------------------------------------------------------------ Befehle (Spieler)

func set_style(c: RaceCar, s: int) -> void:
	c.style = clampi(s, 0, STYLE_MAX)


## Kraftstoffmodus (Mischung) des Spielers: 0 Sparen, 1 Normal, 2 Push.
func set_fuel_mode(c: RaceCar, m: int) -> void:
	m = clampi(m, 0, 2)
	if c.fuel_mode == m:
		return
	c.fuel_mode = m
	var txt: String = ["Sprit sparen, magere Mischung.", "Normale Mischung.", "Mischung fett, Push!"][m]
	make_log("radio", "Funk an %s: %s" % [c.code, txt], c)


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
		c.prev_dist = c.dist
		c.floor_laps = -1
		c.sec_k = int(floor(c.dist / (track.length / 3.0)))
		c.sec_start_t = 0.0
		c.state = State.RACING
		c.tyre_temp = float(TYRE_OPT[c.compound]) - 8.0     # nach der Einführungsrunde knapp unter dem Fenster
		c.lap_start = 0.0
		c.lap_noise = rng.randfn(0.0, track.lap_ref * 0.002)
		c.stint_form = rng.randfn(0.0, 0.0012)
		c.problem_lap = -1
		c.fail_lap = -1
		if c.is_player and rng.randf() < clampf(0.10 + 1.2 * c.mech_rate, 0.08, 0.35):
			c.problem_lap = rng.randi_range(int(float(laps) * 0.25), int(float(laps) * 0.75))
			c.problem_real = rng.randf() < 0.5
		c.launch = rng.randfn(0.0, 0.040) + 0.03 * c.start_trait
		if rng.randf() < 0.06:
			c.launch -= rng.randf_range(0.08, 0.16)      # schlechter Start: Durchdrehen oder Motor abgewürgt
		if c.used_compounds.is_empty():
			c.used_compounds = [c.compound]
	for c in cars:
		if not c.is_player and wet > 0.2:
			c.compound = 4 if wet > 0.58 else 3
			c.used_compounds = [c.compound]
			c.plan = []
	for pc in cars:
		if pc.is_player:
			var ft := tyre_fit_race(pc, pc.compound)
			pc.set_used = float(ft["used"]) if bool(ft["ok"]) else 0.0
			pc.tyre_wear = pc.set_used * 0.8
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
	loss += warmup_loss(c)
	loss += temp_loss(c)
	return loss * scale_time


## Reifentemperatur folgt einem Zielwert: Fenster der Mischung, Tempo, verwirbelte Luft, Streckenbelastung,
## Safety Car / VSC (langsam = kühler) und Nässe (Slicks kühlen aus).
func _update_tyre_temp(c: RaceCar, dt: float) -> void:
	var target: float = float(TYRE_OPT[c.compound]) + float(STYLE_TEMP[c.style]) + (track.tyre_severity - 1.0) * 8.0
	if c.dirty:
		target += 4.0
	if status != Status.GREEN:
		target -= 22.0
	if c.compound < DRY_COUNT:
		target -= 25.0 * wet
	else:
		target += 22.0 * (1.0 - wet) - 6.0     # Regenreifen überhitzen auf trockener Strecke
	c.tyre_temp += (target - c.tyre_temp) * (1.0 - exp(-dt / TYRE_TAU))


## Zustand der Reifentemperatur: -1 zu kalt, 0 im Fenster, 1 zu heiß.
func tyre_temp_state(c: RaceCar) -> int:
	var opt: float = TYRE_OPT[c.compound]
	if c.tyre_temp > opt + TYRE_WIN:
		return 1
	if c.tyre_temp < opt - TYRE_WIN:
		return -1
	return 0


## Überhitzte Slicks verschleißen schneller (3,5 % je Grad über dem Fenster).
func tyre_temp_wear(c: RaceCar) -> float:
	if c.compound >= DRY_COUNT:
		return 1.0
	var over: float = c.tyre_temp - float(TYRE_OPT[c.compound]) - TYRE_WIN
	return 1.0 + clampf(over, 0.0, 25.0) * 0.035 if over > 0.0 else 1.0


## Zeitverlust (s/Runde) außerhalb des Fensters: zu heiß rutschen, zu kalt fehlt Grip (nicht in Aus- und Folgerunde,
## das deckt warmup_loss ab).
func temp_loss(c: RaceCar) -> float:
	if c.compound >= DRY_COUNT:
		return 0.0
	var opt: float = TYRE_OPT[c.compound]
	var over: float = c.tyre_temp - opt - TYRE_WIN
	if over > 0.0:
		return 0.012 * minf(over, 25.0)
	var under: float = opt - TYRE_WIN - c.tyre_temp
	if under > 0.0 and c.tyre_age_laps >= 2:
		return 0.022 * minf(under, 30.0)
	return 0.0


## Aufwärmen: harte Reifen brauchen länger, bis sie Temperatur haben (Aus- und Folgerunde nach dem Stopp).
func warmup_loss(c: RaceCar) -> float:
	if c.tyre_age_laps >= 2:
		return 0.0
	return float(COMPOUNDS[c.compound]["warm"]) * (1.0 if c.tyre_age_laps == 0 else 0.5)


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
	var sp: float = STYLE_PACE[c.style] + c.stint_form
	if has_ers():
		sp += ERS_PACE[ers_eff(c)]
	else:
		sp += ENG_PACE[c.eng_mode]
	sp += (c.wet_trait + 0.6 * c.team_wet) * 0.004 * wet
	if c.lico:
		sp -= 0.0012
	sp += float(FUEL_MODE_PACE[c.fuel_mode])
	sp -= c.damage
	if not c.order.is_empty() and c.order["type"] == "block":
		sp -= 0.03
	var p: float = c.pace_base * (1.0 + sp) / ((1.0 + loss / track.lap_ref) * (1.0 + 0.20 * wet))
	return p


## Zeitverlust (s pro Runde) eines frischen Reifens der Mischung comp (für Undercut-Rechnung).
func fresh_loss(comp: int) -> float:
	var cd: Dictionary = COMPOUNDS[comp]
	return (float(cd["offset"]) + float(cd["deg"]) * track.tyre_severity * 0.4 + float(cd["warm"]) * 0.5 + wet_pen(comp, wet)) * scale_time


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

	# 1) freie Fahrt: gewünschte Fortschritte (mit Windschatten auf Geraden und verwirbelter Luft in Kurven)
	var pace_of := {}
	for k in active.size():
		var c: RaceCar = active[k]
		c.prev_dist = c.dist
		var p := lap_pace(c)
		if c.trouble_t > 0.0:
			p *= 0.34
			c.trouble_t = maxf(0.0, c.trouble_t - dt)
		var vr: float = track.speed_at(c.dist + 6.0)
		var v: float = vr * p
		c.tow = 0.0
		if k > 0 and status == Status.GREEN and c.follow and time > 20.0:
			var ah: RaceCar = active[k - 1]
			var gm: float = ah.dist - c.dist
			if gm < 170.0 and gm > -10.0:
				var gt: float = maxf(gm, 0.0) / maxf(ah.speed, 12.0)
				if gt < TOW_RANGE:
					var fq := 1.0 - gt / TOW_RANGE
					var sp := clampf((vr - 52.0) / 38.0, 0.0, 1.0)
					c.tow = fq * sp
					v *= 1.0 + TOW_MAX * fq * sp - DIRTY_MAX * fq * (1.0 - sp)
		if time < 16.0:
			v *= clampf(0.22 + time / 20.0, 0.0, 1.0) * (1.0 + c.launch * clampf(1.0 - time / 12.0, 0.0, 1.0))
		if status == Status.SC:
			# Der Führende fährt hinter dem Safety Car; alle anderen schließen zügig auf,
			# bis das Feld als geschlossener Zug zusammensteht (wie im echten Rennen).
			var sc_cap := 0.42
			if k > 0:
				var sc_gap: float = (active[k - 1] as RaceCar).dist - c.dist
				sc_cap = lerpf(0.42, 0.92, clampf((sc_gap - SC_CLOSE_GAP) / 140.0, 0.0, 1.0))
			v = minf(v, track.speed_at(c.dist) * sc_cap)
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
					min_gap = SC_CLOSE_GAP - 6.0
				elif time < 18.0:
					min_gap = 8.0
				var ahead_nd: float = fin[ahead]
				var gap_time: float = (ahead_nd - nd) / v_ahead
				if gap_time < 1.0:
					c.close_time += dt
				else:
					c.close_time = maxf(0.0, c.close_time - 2.0 * dt)
				if not c.follow and status == Status.GREEN and time > 20.0:
					# Abstand halten: nicht näher als ca. 1,6 s heranfahren, kein Zweikampf, keine verwirbelte Luft
					min_gap = maxf(min_gap, v_ahead * 1.6)
				if nd > ahead_nd - min_gap:
					if not c.follow and status == Status.GREEN and time > 20.0:
						nd = maxf(c.dist, ahead_nd - min_gap)
						fin[c] = nd
						i += 1
						continue
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
				elif gap_time < 1.5 and c.follow:
					c.dirty = true
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
		_update_tyre_temp(c, dt)
		var wear_mul: float = tyre_temp_wear(c) * STYLE_WEAR[c.style] * (1.18 if c.dirty else 1.0) * wet_wear_factor(c.compound) * (1.0 - 0.07 * c.tyre_trait)
		wear_mul *= (1.0 - 0.09 * c.tyre_care) * clampf(1.0 + 0.0018 * (c.fuel - 50.0), 0.9, 1.2)
		# hinter dem Safety Car / VSC wird langsam gefahren: kaum Reifenverschleiß, deutlich weniger Sprit
		wear_mul *= SC_WEAR[status]
		c.tyre_wear += lap_frac * wear_mul
		_track_sectors(c, nd)
		var fuel_mul: float = float(STYLE_FUEL[c.style]) * (1.0 if has_ers() else float(ENG_FUEL[c.eng_mode])) * float(SC_FUEL[status]) * (0.94 if c.lico else 1.0) * float(FUEL_MODE_BURN[c.fuel_mode])
		c.fuel = maxf(0.0, c.fuel - burn_per_lap * lap_frac * fuel_mul)
		if c.fuel <= 0.02 and c.state == State.RACING:
			make_log("dnf", "TANK LEER: %s bleibt auf der Strecke stehen!" % c.code, c)
			_retire(c, "Tank leer")
			continue
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
	_roll_incidents(dt, active)
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
	var ch: float = ez * (0.0045 + 0.05 * maxf(0.0, dlt)) if dlt > -0.05 else ez * (0.0022 + 0.01 * maxf(0.0, dlt + 0.5))
	# Windschatten und anhaltender Druck: wer lange dicht dran ist, findet eher eine Lücke
	ch *= 1.0 + 0.6 * minf(1.0, c.close_time / 6.0) + 0.4 * minf(1.0, maxf(0.0, c.close_time - 10.0) / 30.0)
	ch *= 1.0 + 0.5 * c.tow
	if rules["drs"] and gap_time < 1.0 and track.in_drs_zone(c.dist):
		ch *= 2.3
	if c.revenge_idx == ahead.index and time < c.revenge_until:
		ch *= 1.25          # Gegenangriff direkt nach einem Überholmanöver
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
	pass_total += 1
	if time < 120.0:
		pass_first_lap += 1
	c.passes_made += 1
	ahead.passes_lost += 1
	c.close_time = 0.0
	ahead.revenge_idx = c.index
	ahead.revenge_until = time + 30.0
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
			if wc >= 0 and wc != c.compound and not do_pit and remaining > 1 and fl - c.last_pit_lap >= 6:
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
	# KI ohne zweite Mischung und ohne weiteren geplanten Stopp: Pflichtstopp vor Schluss (Zwei-Mischungen-Regel)
	if not do_pit and not c.is_player and int(rules["min_compounds"]) >= 2 and not rain_seen and c.compound < DRY_COUNT \
			and c.used_compounds.size() < 2 and remaining <= 15 and remaining > 2 and c.state == State.RACING:
		var planned := false
		for s in c.plan:
			if int(s["lap"]) > fl:
				planned = true
		if not planned:
			do_pit = true
			comp = 1 if c.compound != 1 else 0
	if not do_pit:
		return
	if remaining <= 0:
		return
	# Regel: mind. zwei verschiedene Mischungen in einem Trockenrennen
	var used: Array = c.used_compounds.duplicate()
	if not used.has(comp):
		used.append(comp)
	# (spätestens beim letzten Stopp: kurz vor Schluss oder wenn danach kein weiterer Stopp geplant ist)
	var later_stop := false
	for s in c.plan:
		if int(s["lap"]) > fl:
			later_stop = true
	var last_stop := not later_stop or life_eff(comp) * 0.95 >= float(remaining)
	if int(rules["min_compounds"]) >= 2 and used.size() < 2 and not rain_seen and comp < DRY_COUNT:
		if remaining <= 22:
			comp = (c.compound + 1) % 3
		elif not c.is_player and last_stop:
			comp = 1 if c.compound != 1 else 2      # KI: haltbarste andere Mischung
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
	var best := 2
	var best_cost := 99.0
	for k in DRY_COUNT:
		if life_eff(k) >= float(remaining):
			var cst := stint_cost(k, float(remaining))
			if cst < best_cost:
				best_cost = cst
				best = k
	return best


func _enter_pit(c: RaceCar, comp: int, fl: int) -> void:
	requests.erase(c.index)
	c.plan_note = ""
	_adapt_plan(c, fl, comp)      # zuerst den Plan anpassen: Tankmenge und Folgestopps hängen davon ab
	var crew_gain: float = 0.25 * crew_form if c.is_player else 0.0
	var stationary: float = float(rules["stationary"]) + rng.randfn(0.0, 0.45) + c.pit_skill - crew_gain
	c.fb_stage = 0
	var fuel_add := 0.0
	var new_fuel := c.fuel
	if rules["refuel"]:
		new_fuel = _fuel_for_stint_after_pit(c, fl)
		new_fuel = maxf(new_fuel, c.fuel)
		fuel_add = maxf(0.0, new_fuel - c.fuel)
		c.pit_fuel_laps = -1.0
		stationary = 1.2 + fuel_add / 9.0 + rng.randfn(0.0, 0.4) + c.pit_skill - crew_gain
	stationary = maxf(1.6, stationary)
	var slow_r := rng.randf()
	var slow_k := (1.0 - 0.6 * crew_form) * player_slow_k if c.is_player else 1.0
	if slow_r < 0.008 * slow_k:
		stationary += rng.randf_range(8.0, 14.0)
		make_log("pit", "Radmutter klemmt: sehr langer Stopp für %s" % c.code, c)
	elif slow_r < 0.04 * slow_k:
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
	c.last_pit_lap = fl
	c.stint_log.append({"a": c.stint_start, "b": fl, "comp": c.compound})
	c.stint_start = fl
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
	c.plan = c.plan.filter(func(s): return int(s["lap"]) > fl)      # abgehakte Stopps entfernen (Tank-Extras sind gelesen)
	make_log("pit", "Boxenstopp %s: %s -> %s (%.1f s)" % [c.code, COMPOUNDS[c.compound]["name"], COMPOUNDS[comp]["name"], stationary], c)
	_trigger_covers(c, fl)


## Wirkung eines Stopps am Ende von Runde fl auf den Plan, ohne etwas zu ändern.
## Ein geplanter Stopp wird abgehakt. Ein vorgezogener oder verspäteter (ungeplanter) Stopp ersetzt den nächsten geplanten,
## sonst stünde der kurz danach noch einmal an. Spätere Stopps bleiben unverändert.
## Rückgabe: {"replaced" (Runde oder -1), "keep" (Plan danach), "next" (nächster Stopp danach, laps = keiner)}
func adapt_info(c: RaceCar, fl: int, comp: int) -> Dictionary:
	var planned_now := false
	var nxt_lap := -1
	for s in c.plan:
		var l := int(s["lap"])
		if l == fl:
			planned_now = true
		elif l > fl and (nxt_lap < 0 or l < nxt_lap):
			nxt_lap = l
	var replaced := -1
	var horizon: float = maxf(5.0, life_eff(comp) * 0.4)
	if not planned_now and nxt_lap > 0:
		var reach: float = horizon
		if rules["refuel"]:
			reach = maxf(6.0, 0.5 * float(nxt_lap - c.stint_start))
		if float(nxt_lap - fl) <= reach:
			replaced = nxt_lap
	var keep: Array = []
	var next_stop := laps
	for s in c.plan:
		var l := int(s["lap"])
		if l < fl or l == replaced:
			continue
		if l > fl and not rules["refuel"] and float(l - fl) <= horizon:
			continue      # frische Reifen halten noch lange: ein Stopp direkt danach wäre sinnlos
		keep.append(s)
		if l > fl:
			next_stop = mini(next_stop, l)
	return {"replaced": replaced, "keep": keep, "next": next_stop}


## Nach einem Stopp den Plan anpassen (siehe adapt_info). Rückgabe: ersetzter Stopp (Runde) oder -1.
func _adapt_plan(c: RaceCar, fl: int, comp: int) -> int:
	var info := adapt_info(c, fl, comp)
	c.plan = info["keep"]
	var replaced := int(info["replaced"])
	if replaced > 0:
		c.plan_note = "Stopp R%d entfällt: der Stopp jetzt ersetzt ihn." % replaced
		if c.is_player:
			make_log("info", "Plan angepasst: geplanter Stopp in Runde %d entfällt." % replaced, c)
	return replaced


## Prüft jeden geplanten Stint gegen die Reifenhaltbarkeit. Einträge: {"lap" (Stopp am Ende dieser Runde, laps = Ziel), "comp" (neue Mischung, -1 = Ziel),
## "stint_comp", "run" (Runden bis dahin), "cap" (so lange hält der Reifen), "state" ("ok", "tight", "long")}
func plan_check(c: RaceCar) -> Array:
	var out: Array = []
	var fl: int = maxi(c.floor_laps, 0)
	var rate := maxf(wear_rate_now(c), 0.2)
	var stops: Array = []
	for s in c.plan:
		if int(s["lap"]) > fl:
			stops.append(s)
	stops.sort_custom(func(x, y): return int(x["lap"]) < int(y["lap"]))
	var comp := c.compound
	var from_lap := fl
	var used := c.tyre_wear
	var fuel_laps: float = (fuel_range(c) + clampf(c.dist / track.length - float(fl), 0.0, 1.0)) if rules["refuel"] else 99.0       # der Tank reicht bis zum ersten Stopp nur so weit (danach wird neu getankt), gemessen ab der letzten Ziellinie
	for s in stops:
		var run := float(int(s["lap"]) - from_lap)
		out.append(_stint_entry(int(s["lap"]), int(s["comp"]), comp, run, (life_eff(comp) - used) / rate, fuel_laps))
		from_lap = int(s["lap"])
		comp = int(s["comp"])
		used = 0.0
		fuel_laps = 99.0
	out.append(_stint_entry(laps, -1, comp, float(laps - from_lap), (life_eff(comp) - used) / rate, fuel_laps))
	return out


func _stint_entry(lap: int, comp: int, stint_comp: int, run: float, cap: float, fuel_cap := 99.0) -> Dictionary:
	var st := "ok"
	if stint_comp >= DRY_COUNT:
		st = "ok"
	elif cap < run - 0.5:
		st = "long"
	elif cap < run + 1.5:
		st = "tight"
	if fuel_cap < run - 0.3:
		st = "fuel"
	return {"lap": lap, "comp": comp, "stint_comp": stint_comp, "run": run, "cap": cap, "fuel_cap": fuel_cap, "state": st}


func _fuel_for_stint_after_pit(c: RaceCar, fl: int) -> float:
	if c.pit_fuel_laps >= 0.0:
		return fuel_for_laps(c.pit_fuel_laps)
	var to_lap := _next_stop_lap(c, fl)
	var extra := 0.0
	for st in c.plan:
		if int(st["lap"]) == fl:
			extra = float(st.get("fuel", 0.0))
	return fuel_for_laps(float(to_lap - fl) + extra)


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
				c.tyre_temp = 80.0 if c.compound < DRY_COUNT else 65.0   # aus den Heizdecken
				if c.is_player:
					var ft2 := tyre_fit_race(c, c.compound)
					if not bool(ft2["ok"]):
						# kein Satz dieser Mischung mehr: die Mischung mit den meisten freien Sätzen nehmen
						var bestc := -1
						var bestn := 0
						for cc in (range(DRY_COUNT) if c.compound < DRY_COUNT else range(DRY_COUNT, 5)):
							var nfree: int = int(tyre_count(c, cc)["free"])
							if nfree > bestn:
								bestn = nfree
								bestc = cc
						if bestc >= 0:
							make_log("radio", "Funk %s: Kein %s-Satz mehr verfügbar, wir montieren %s." % [c.code, COMPOUNDS[c.compound]["name"], COMPOUNDS[bestc]["name"]], c)
							c.compound = bestc
							ft2 = tyre_fit_race(c, bestc)
					c.set_used = float(ft2["used"])
					c.tyre_wear = c.set_used * 0.8
				c.pit_stops += 1
				c.stint_form = rng.randfn(0.0, 0.0012)
				c.dist += PIT_EXIT_DIST
				c.prev_dist = c.dist
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


## Kleine Zwischenfälle ohne Ausfall: Dreher/Verbremser, Kontakt mit Flügelschaden, Reifenschaden. Sie mischen das Feld durch,
## auch Teamkollegen (jeder Fahrer hat seine eigenen Momente). Bei Gelb/Safety Car passiert nichts.
func _roll_incidents(dt: float, active: Array) -> void:
	if status != Status.GREEN or leader_finished or not incidents_on:
		return
	var lt: float = track.lap_ref * 1.04
	var first_lap: bool = time < lt * 1.05
	var remaining := laps - leader_lap()
	if remaining < 2:
		return
	for c in active:
		if c.trouble_t > 0.0 or c.state != State.RACING:
			continue
		var per_race: float = 0.26 * (1.0 + 0.5 * (c.aggr - 0.5)) * (1.0 + 1.6 * wet) * (1.25 - 0.5 * c.cons)
		if c.compound < DRY_COUNT and wet > 0.25:
			per_race *= 1.0 + 3.0 * (wet - 0.25)
		var h: float = per_race / float(laps) / lt * dt
		if first_lap:
			h *= 3.5
		if rng.randf() >= h:
			continue
		var r := rng.randf()
		if r < 0.62:
			c.trouble_t = rng.randf_range(3.5, 8.0)
			c.tyre_wear += rng.randf_range(0.2, 0.6)         # Bremsplatten
			if c.is_player:
				make_log("radio", "Funk %s: Verbremser, neben die Strecke! Wir verlieren einige Sekunden." % c.code, c)
		elif r < 0.90:
			c.trouble_t = rng.randf_range(1.5, 3.5)
			c.damage = maxf(c.damage, rng.randf_range(0.004, 0.011))
			if c.is_player:
				make_log("radio", "Funk %s: Kontakt, der Frontflügel ist beschädigt (ca. %.1f s pro Runde)." % [c.code, c.damage * track.lap_ref], c)
			elif c.react_lap < 0 and remaining > 5:
				c.react_lap = leader_lap() + 1
				c.react_comp = _choose_comp(c, remaining - 1)
		else:
			c.trouble_t = rng.randf_range(8.0, 14.0)
			c.damage = maxf(c.damage, 0.006)
			if remaining > 3:
				c.pit_requested = true
				c.pit_comp = _choose_comp(c, remaining - 1)
			if c.is_player:
				make_log("radio", "Funk %s: Reifenschaden! Wir holen dich sofort rein." % c.code, c)


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
			status_serial += 1
			sc_marks.append({"lap": leader_lap(), "end": leader_lap() + status_laps_left, "kind": 2})
			make_log("sc", "SAFETY CAR!")
		elif r < p_sc:
			status = Status.VSC
			status_laps_left = 2
			status_serial += 1
			sc_marks.append({"lap": leader_lap(), "end": leader_lap() + 2, "kind": 1})
			make_log("sc", "Virtual Safety Car")


func _update_status() -> void:
	if status != Status.GREEN and status_laps_left <= 0:
		if not sc_marks.is_empty():
			sc_marks[sc_marks.size() - 1]["end"] = leader_lap()
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
## Funkanweisung des Spielers: push (3 Runden Angriff), manage (5 Runden Reifen schonen), lico (5 Runden Sprit sparen), normal.
func radio_order(c: RaceCar, kind: String) -> void:
	c.lico = false
	c.radio_kind = kind
	match kind:
		"push":
			c.style = STYLE_MAX
			c.radio_until = c.floor_laps + 3
			make_log("radio", "Funk an %s: Push! Drei Runden Vollgas." % c.code, c)
		"manage":
			c.style = 0
			c.radio_until = c.floor_laps + 5
			make_log("radio", "Funk an %s: Reifen managen, fünf Runden." % c.code, c)
		"lico":
			c.lico = true
			c.radio_until = c.floor_laps + 5
			make_log("radio", "Funk an %s: Lift and Coast, Sprit sparen." % c.code, c)
		_:
			c.radio_kind = ""
			c.style = STYLE_STD
			make_log("radio", "Funk an %s: Normal weiterfahren." % c.code, c)


func set_rule(c: RaceCar, key: String, on) -> void:
	c.rules[key] = on


## Pro Runde für Spielerautos: Funk-Ablauf, Fahrer-Rückmeldung und Wenn-Dann-Regeln.
func _player_auto(c: RaceCar, fl: int) -> void:
	if c.radio_kind != "" and fl >= c.radio_until:
		make_log("radio", "Funk: %s fährt wieder normal." % c.code, c)
		if c.radio_kind in ["push", "manage"]:
			c.style = STYLE_STD
		c.radio_kind = ""
		c.lico = false
	var life := life_eff(c.compound)
	var fr := c.tyre_wear / life
	if fr > 0.92 and c.fb_stage < 3:
		c.fb_stage = 3
		make_log("radio", "Fahrer %s: Die Reifen sind am Ende, ich brauche neue!" % c.code, c)
	elif fr > 0.75 and c.fb_stage < 2:
		c.fb_stage = 2
		make_log("radio", "Fahrer %s: Der Grip lässt deutlich nach, hinten wird es rutschig." % c.code, c)
	elif fr > 0.5 and c.fb_stage < 1:
		c.fb_stage = 1
		make_log("radio", "Fahrer %s: Reifen gut, die Balance passt noch." % c.code, c)
	if c.state != State.RACING or c.pit_requested or c.rules.is_empty():
		return
	var remaining := laps - fl
	if remaining < 4:
		return
	var rl: Dictionary = c.rules
	if rl.get("sc_pit", false) and status != Status.GREEN and fr >= float(rl.get("sc_wear", 0.35)) and remaining > 6 and c.pit_stops < 4:
		var cmp := suggest_comp(c)
		request_pit(c, cmp)
		make_log("radio", "Regel: %s unter %s, Stopp auf %s." % [c.code, "Safety Car" if status == Status.SC else "VSC", COMPOUNDS[cmp]["name"]], c)
		return
	if rl.get("rain_switch", false) and c.compound < DRY_COUNT and wet > 0.28:
		var cmp2 := 3 if wet < 0.6 else 4
		request_pit(c, cmp2)
		make_log("radio", "Regel: Nässe %d %%, %s wechselt auf %s." % [int(wet * 100.0), c.code, COMPOUNDS[cmp2]["name"]], c)
		return
	if rl.get("dry_switch", false) and c.compound >= DRY_COUNT and wet < 0.10 and rain < 0.05:
		var cmp3 := _choose_comp(c, remaining)
		request_pit(c, cmp3)
		make_log("radio", "Regel: Strecke trocken, %s wechselt auf %s." % [c.code, COMPOUNDS[cmp3]["name"]], c)
		return
	if rl.get("defend", false) and status == Status.GREEN and fr > 0.4 and remaining > 8:
		var th := threat_info(c)
		if bool(th["has"]) and float(th["margin"]) > 0.3:
			var cmp4 := suggest_comp(c)
			request_pit(c, cmp4)
			make_log("radio", "Regel: Konter-Stopp gegen %s (%s)." % [th["car"].code, COMPOUNDS[cmp4]["name"]], c)
			return
	if rl.get("fuel_save", false) and c.style != 0:
		var need := float(laps_to_refuel_point(c, maxi(c.floor_laps, 0))) + 0.15
		if fuel_range(c) < need:
			c.style = 0
			make_log("radio", "Regel: Sprit knapp, %s spart." % c.code, c)


func _fuel_check(c: RaceCar, fl: int) -> void:
	if c.pit_requested or c.state != State.RACING:
		return
	for st in c.plan:
		if int(st["lap"]) == fl:
			return      # kommt gleich an die Box und tankt
	var need := float(laps_to_refuel_point(c, fl)) + 0.15
	var have := fuel_range(c)
	if c.is_player:
		if have < need and c.fuel_warn_stint != c.pit_stops * 1000 + fl / 6:
			c.fuel_warn_stint = c.pit_stops * 1000 + fl / 6
			make_log("radio", "Funk %s: Sprit knapp! Tank reicht noch %.1f Runden, bis zum Stopp/Ziel fehlen %.1f. Sparen oder früher an die Box." % [c.code, have, need - have], c)
		return
	# KI: bei knappem Tank Sprit sparen, sonst Normalstil
	if have < need and c.style != 0:
		c.style = 0
	elif have > need + 1.0 and c.style == 0 and c.tyre_wear < life_eff(c.compound) * 0.9:
		c.style = STYLE_STD


func _lap_tactics(c: RaceCar, fl: int) -> void:
	_fuel_check(c, fl)
	if not c.is_player:
		c.follow = not (c.tyre_wear > life_eff(c.compound) * 0.9 and c.gap_ahead < 2.0 and c.cur_pace < 1.0 and rng.randf() < 0.3)
	else:
		_player_auto(c, fl)
		_player_requests(c, fl)
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
	if m == null or m.state != State.RACING or c.state != State.RACING or m.is_player:
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
	elif c.duel_laps >= 3 and rng.randf() < 0.14:
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


## Aktueller Reifenverschleiß pro Runde (1.0 = Standard) mit Fahrstil, Fahrer, Auto und Tankgewicht.
func wear_rate_now(c: RaceCar) -> float:
	var r: float = float(STYLE_WEAR[c.style]) * (1.0 - 0.07 * c.tyre_trait) * (1.0 - 0.09 * c.tyre_care)
	r *= clampf(1.0 + 0.0018 * (c.fuel - 50.0), 0.9, 1.2) * wet_wear_factor(c.compound) * tyre_temp_wear(c)
	return r


## Passende Reifenwahl für einen Stopp jetzt (Nässe hat Vorrang).
func suggest_comp(c: RaceCar) -> int:
	var rc := recommended_compound()
	if rc >= 0:
		return rc
	var cur := leader_lap()
	var comp := _choose_comp(c, laps - cur)
	if comp == c.compound and int(rules["min_compounds"]) >= 2 and not c.used_compounds.is_empty() and c.used_compounds.size() < 2:
		comp = (c.compound + 1) % 3
	return comp


## Stopp-Fenster aus dem Reifenzustand: {"need", "open", "ideal", "close", "left" (Runden Resthaltbarkeit), "frac", "text"}.
func pit_window_info(c: RaceCar, fl: int) -> Dictionary:
	var remaining := laps - fl
	var life := life_eff(c.compound)
	var rate := maxf(wear_rate_now(c), 0.2)
	var left := maxf(0.0, (life - c.tyre_wear) / rate)
	var frac := c.tyre_wear / life
	var res := {"need": false, "left": left, "frac": frac, "open": fl, "ideal": fl, "close": fl, "text": ""}
	if c.compound >= DRY_COUNT:
		res["text"] = "Regenreifen: Stopp richtet sich nach der Streckennässe."
		return res
	if left >= float(remaining) + 0.5:
		res["text"] = "Die Reifen halten voraussichtlich bis ins Ziel (noch ca. %d Runden Haltbarkeit)." % int(left)
		return res
	res["need"] = true
	res["open"] = maxi(fl + 1, fl + int(left * 0.5))
	res["ideal"] = fl + int(left * 0.8)
	res["close"] = fl + int(left)
	var t := "Stopp-Fenster: Runde %d bis %d (ideal um Runde %d)." % [int(res["open"]), int(res["close"]), int(res["ideal"])]
	if int(res["open"]) >= int(res["close"]):
		t = "Stopp jetzt oder in den nächsten Runden: die Reifen halten nur noch ca. %d Runden." % maxi(1, int(left))
	if int(res["close"]) >= laps:
		t = "Die Reifen reichen fast bis ins Ziel, ein später Stopp ist optional."
	res["text"] = t
	return res


## Ausblick einer Mischung für den restlichen Rennverlauf: {"life", "to_end", "stops_left"}.
func compound_outlook(c: RaceCar, comp: int) -> Dictionary:
	var remaining := laps - leader_lap()
	var life := life_eff(comp) / maxf(wear_rate_now(c) / maxf(float(STYLE_WEAR[c.style]), 0.1), 0.6)
	return {"life": life, "to_end": life >= float(remaining) + 0.5, "remaining": remaining}


## Stopp für eine bestimmte Runde einplanen (ersetzt einen vorhandenen Stopp derselben Runde).
func schedule_pit(c: RaceCar, lap: int, comp: int) -> void:
	unschedule_pit(c, lap)
	c.plan.append({"lap": lap, "comp": comp})
	c.plan.sort_custom(func(a, b): return int(a["lap"]) < int(b["lap"]))


func unschedule_pit(c: RaceCar, lap: int) -> void:
	for s in c.plan.duplicate():
		if int(s["lap"]) == lap:
			c.plan.erase(s)


## Stints für die Zeitleiste: abgeschlossene, aktueller (bis zum nächsten Stopp) und geplante.
func stint_segments(c: RaceCar, cur: int) -> Array:
	var segs: Array = []
	for s in c.stint_log:
		segs.append({"a": int(s["a"]), "b": int(s["b"]), "comp": int(s["comp"]), "life": life_eff(int(s["comp"]))})
	var a: int = c.stint_start
	var comp: int = c.compound
	var future: Array = []
	for s in c.plan:
		if int(s["lap"]) > cur:
			future.append(s)
	future.sort_custom(func(x, y): return int(x["lap"]) < int(y["lap"]))
	for s in future:
		segs.append({"a": a, "b": int(s["lap"]), "comp": comp, "life": life_eff(comp) if a == c.stint_start else life_eff(comp)})
		a = int(s["lap"])
		comp = int(s["comp"])
	segs.append({"a": a, "b": laps, "comp": comp, "life": life_eff(comp)})
	return segs


## Geschätzte Lage eines Gegners für das Gegner-Radar: Reifenrest, Stopp-Erwartung, Gefahr.
## {"rest" (0..1), "laps_left", "stop_lap" (-1 = bis Ziel), "text", "threat" (Undercut-Gefahr für c), "threat_margin"}
func rival_outlook(r: RaceCar, c: RaceCar) -> Dictionary:
	var fl := leader_lap()
	var remaining := laps - fl
	var life := life_eff(r.compound)
	var rate := maxf(wear_rate_now(r), 0.2)
	var laps_left := maxf(0.0, (life - r.tyre_wear) / rate)
	var rest := clampf(1.0 - r.tyre_wear / life, 0.0, 1.0)
	var res := {"rest": rest, "laps_left": laps_left, "stop_lap": -1, "text": "", "threat": false, "threat_margin": -9.0}
	if r.state == State.PIT:
		res["text"] = "in der Box"
		return res
	if r.compound >= DRY_COUNT:
		res["text"] = "Regenreifen"
	elif laps_left >= float(remaining) + 0.5:
		res["text"] = "kommt wohl ohne Stopp ins Ziel"
	else:
		var sl: int = fl + maxi(1, int(laps_left * 0.8))
		res["stop_lap"] = sl
		res["text"] = "Stopp um Runde %d erwartet" % sl
	# Gefahr: Gegner direkt hinter c mit Undercut-Potenzial
	if r != c and r.state == State.RACING and c.state == State.RACING and r.dist < c.dist and r.gap_ahead < 4.0 and car_behind(c) == r and remaining > 6:
		var comp := _choose_comp(r, remaining)
		var adv := tyre_loss(c) - fresh_loss(comp)
		var margin := 2.0 * adv - r.gap_ahead - 0.8
		res["threat_margin"] = margin
		res["threat"] = margin > 0.0
	return res


## Entscheidungskarte für ein Spielerauto: {"key", "kind", "level", "title", "text", "options": [{"label", "action", "hint"}]} oder leer.
## Aktionen: "pit:<Mischung>", "later:<Runden>:<Mischung>", "stay".
func decision_for(c: RaceCar) -> Dictionary:
	if c.state != State.RACING or c.pit_requested or not started:
		return {}
	var fl := leader_lap()
	var remaining := laps - fl
	if remaining < 5:
		return {}
	var life := life_eff(c.compound)
	var fr := c.tyre_wear / life
	var base := "%d|%d" % [c.index, c.pit_stops]
	var comp := suggest_comp(c)
	var cname: String = COMPOUNDS[comp]["name"]
	# 0) Schaden am Auto
	if c.damage >= 0.003 and remaining > 8:
		var lap_cost: float = c.damage * track.lap_ref
		return {"key": "%s|dmg" % base, "kind": "damage", "level": "bad",
			"title": "Schaden am Auto",
			"text": "Der Frontflügel ist beschädigt und kostet ca. %.1f s pro Runde, bis ein Stopp ihn tauscht." % lap_cost,
			"options": [
				{"label": "Stopp: %s" % cname, "action": "pit:%d" % comp, "hint": "Neuer Flügel. Stopp kostet %.0f s, Weiterfahren bis ins Ziel ca. %.0f s." % [pit_cost_now(), lap_cost * float(remaining)]},
				{"label": "Weiterfahren", "action": "stay", "hint": "Nur sinnvoll, wenn ohnehin bald ein Stopp ansteht."},
			]}
	# 1) Safety Car / VSC
	if status != Status.GREEN and fr > 0.3 and remaining > 6:
		var rj := rejoin_info(c)
		var normal: float = track.pit_loss * float(rules["pit_loss_scale"])
		var ahead_txt := ""
		if rj["ahead"] != null:
			ahead_txt = " hinter %s" % rj["ahead"].code
		return {"key": "%s|sc|%d" % [base, status_serial], "kind": "sc", "level": "warn",
			"title": "%s: Stopp jetzt günstig?" % ("Safety Car" if status == Status.SC else "Virtuelles Safety Car"),
			"text": "Reifen zu %d %% verbraucht." % int(fr * 100.0),
			"options": [
				{"label": "Stopp: %s" % cname, "action": "pit:%d" % comp, "hint": "Verlust nur %.0f s statt %.0f s, Rückkehr P%d%s" % [pit_cost_now(), normal, int(rj["pos"]), ahead_txt]},
				{"label": "Draußen bleiben", "action": "stay", "hint": "Später kostet der Stopp %.0f s, Reifen halten noch ca. %d Rd." % [normal, int(maxf(0.0, (life - c.tyre_wear) / maxf(wear_rate_now(c), 0.2)))]},
			]}
	# 2) Nässe: falsche Reifen
	var rc := recommended_compound()
	if rc >= 0 and c.compound != rc:
		var rn: String = COMPOUNDS[rc]["name"]
		return {"key": "%s|wet|%d" % [base, int(wet * 4.0)], "kind": "rain", "level": "bad",
			"title": "Falsche Reifen für die Nässe",
			"text": "Streckennässe %d %%: %s wäre jetzt richtig." % [int(wet * 100.0), rn],
			"options": [
				{"label": "Wechsel auf %s" % rn, "action": "pit:%d" % rc, "hint": "Mit den jetzigen Reifen verlierst du ca. %.0f s pro Runde" % maxf(0.0, wet_penalty(c.compound) - wet_penalty(rc))},
				{"label": "Noch warten", "action": "stay", "hint": "Risiko: Zeitverlust und Ausrutscher"},
			]}
	# 3) Regen im Anmarsch (Wette)
	var rd := rain_radar()
	if float(rd["eta"]) > 0.0 and float(rd["eta"]) < 7.0 and c.compound < DRY_COUNT and float(rd["prob"]) > 0.6 and wet < 0.1:
		return {"key": "%s|radar|%d" % [base, int(float(rd["eta"]) / 3.0)], "kind": "rain", "level": "warn",
			"title": "Regen in ca. %d min" % int(rd["eta"]),
			"text": "Wahrscheinlichkeit %d %%. Fehlalarme sind möglich." % int(float(rd["prob"]) * 100.0),
			"options": [
				{"label": "Wette: auf Inter", "action": "pit:3", "hint": "Gewinn, wenn es regnet; Verlust bei Fehlalarm"},
				{"label": "Abwarten", "action": "stay", "hint": "Sicher, aber ein späterer Stopp kostet Zeit"},
			]}
	# 4) Reifen am Ende
	if fr > 0.92 and c.compound < DRY_COUNT:
		return {"key": "%s|tyre" % base, "kind": "tyre", "level": "bad",
			"title": "Reifen am Ende",
			"text": "%d %% verbraucht, Rundenzeit bricht ein (%.1f s pro Runde Verlust)." % [int(fr * 100.0), tyre_loss(c)],
			"options": [
				{"label": "Stopp: %s" % cname, "action": "pit:%d" % comp, "hint": "Frische Reifen bringen ca. %.1f s pro Runde" % (tyre_loss(c) - fresh_loss(comp))},
				{"label": "Noch 3 Runden", "action": "later:3:%d" % comp, "hint": "Kostet ca. %.0f s Rundenzeit, falls kein Safety Car kommt" % (tyre_loss(c) * 3.0)},
			]}
	# 5) Undercut-Gefahr
	var th := threat_info(c)
	if bool(th["has"]) and float(th["margin"]) > 0.3 and fr > 0.4 and status == Status.GREEN and remaining > 8:
		var bc: RaceCar = th["car"]
		return {"key": "%s|thr|%s|%d" % [base, bc.code, fl / 6], "kind": "threat", "level": "warn",
			"title": "%s droht mit Undercut" % bc.code,
			"text": "%.1f s hinter dir, mit frischen Reifen holt er ca. %+.1f s." % [float(th["gap"]), float(th["margin"])],
			"options": [
				{"label": "Konter-Stopp: %s" % cname, "action": "pit:%d" % comp, "hint": "Du bleibst vor ihm, wenn die Box frei ist"},
				{"label": "Position halten", "action": "stay", "hint": "Er kann bei seinem Stopp vorbeiziehen"},
			]}
	# 6) Anfrage des Fahrers an die Box
	if requests.has(c.index):
		var rq: Dictionary = requests[c.index]
		return {"key": "rq|%d" % int(rq["serial"]), "kind": str(rq["kind"]), "level": str(rq["level"]), "title": str(rq["title"]), "text": str(rq["text"]), "options": rq["options"]}
	return {}


# ------------------------------------------------------------------ Funkanfragen des Fahrers

func _pos_of(c: RaceCar) -> int:
	return ranking().find(c) + 1


## Pro Runde für Spielerautos: Zähler, Verfall offener Anfragen, neue Anfragen, Auswertung früherer Entscheidungen.
func _player_requests(c: RaceCar, fl: int) -> void:
	if c.fail_lap >= 0 and fl >= c.fail_lap and c.state == State.RACING:
		c.fail_lap = -1
		make_log("radio", "Funk %s: Das Auto lässt stark nach, wir müssen aufgeben." % c.code, c)
		_retire(c, "Technischer Defekt")
		return
	if c.state != State.RACING:
		requests.erase(c.index)
		return
	_eval_decisions(c, fl)
	var ahead := car_ahead(c)
	if status == Status.GREEN and ahead != null and c.gap_ahead < 1.0:
		c.close_laps += 1
	else:
		c.close_laps = 0
	var m := mate_of(c)
	if m != null and m.is_player and m.state == State.RACING and ahead == m and c.gap_ahead < 1.3 and status == Status.GREEN and predicted_lap_time(c) < predicted_lap_time(m) - 0.2:
		c.chase_laps += 1
	else:
		c.chase_laps = 0
	if requests.has(c.index):
		var ex: Dictionary = requests[c.index]
		if fl > int(ex["expires"]):
			_apply_request(c, str(ex["kind"]), "expired", fl)
		return
	if not requests_on or fl < c.req_cd or status != Status.GREEN or laps - fl < 6 or c.pit_requested:
		return
	for s in c.plan:
		if int(s["lap"]) == fl:
			return      # der Stopp steht jetzt an: Reifen und Sprit werden gleich erneuert
	var rq := _build_request(c, fl)
	if rq.is_empty():
		return
	request_serial += 1
	rq["serial"] = request_serial
	rq["expires"] = fl + 3
	rq["pos0"] = _pos_of(c)
	requests[c.index] = rq
	c.req_cd = fl + rng.randi_range(7, 11)


## Neue Anfrage des Fahrers (oder leer). Wichtigste zuerst: Technik, Sprit, Teamkollege, Zweikampf, Reifen.
func _build_request(c: RaceCar, fl: int) -> Dictionary:
	var remaining := laps - fl
	var life := life_eff(c.compound)
	var fr := c.tyre_wear / life
	var cost := pit_cost_now()
	# Technik
	if c.problem_lap >= 0 and fl >= c.problem_lap and remaining > 6:
		c.problem_lap = -1
		var syms := ["Vibrationen im Heck", "Öltemperatur steigt", "Druckverlust hinten links", "Bremse wird zu heiß", "Getriebe schaltet hakelig"]
		return {"kind": "problem", "level": "warn",
			"title": "%s meldet: %s" % [c.code, syms[rng.randi() % syms.size()]],
			"text": "Das kann ein echtes Problem sein oder ein Fehlalarm. Ein Check kostet einen Boxenstopp (ca. %.0f s)." % cost,
			"options": [
				{"label": "An die Box: Check", "action": "rq:problem:box", "hint": "Sicher: ein echtes Problem wird behoben. Kostet %.0f s." % cost},
				{"label": "Schonend weiterfahren", "action": "rq:problem:eco", "hint": "Ca. 0,6 s pro Runde langsamer für 5 Runden. Senkt das Ausfallrisiko deutlich."},
				{"label": "Normal weiterfahren", "action": "rq:problem:ignore", "hint": "Ist es echt, kann das Auto bald ausfallen. Bei einem Fehlalarm kostet es nichts."},
			]}
	# Sprit
	var need := fuel_need(c)
	var have := fuel_range(c)
	if have < need - 0.2 and c.req_fuel_stint != c.pit_stops and remaining > 4:
		c.req_fuel_stint = c.pit_stops
		var fo: Array = [
			{"label": "Lift and Coast", "action": "rq:fuel:lico", "hint": "5 Runden ca. 6 % weniger Sprit, kostet nur etwa 0,1 s pro Runde."},
			{"label": "Sparmodus", "action": "rq:fuel:manage", "hint": "5 Runden Fahrstil Sparen: ca. 6 % weniger Sprit und weniger Reifenverschleiß, aber ca. 0,6 s pro Runde langsamer."},
		]
		if rules["refuel"]:
			fo.append({"label": "Früher tanken", "action": "rq:fuel:box", "hint": "Sofort an die Box, der Tank wird neu gefüllt."})
		fo.append({"label": "Weiter wie bisher", "action": "rq:fuel:stay", "hint": "Es fehlen %.1f Runden Sprit, das Auto bliebe stehen." % (need - have)})
		return {"kind": "fuel", "level": "bad", "title": "%s: Der Sprit wird knapp" % c.code,
			"text": "Der Tank reicht noch %.1f Runden, bis %s sind es %.1f." % [have, "zum Stopp" if rules["refuel"] and need < float(laps - fl) else "ins Ziel", need],
			"options": fo}
	# Teamkollege ist schneller
	var m := mate_of(c)
	if c.chase_laps >= 3 and m != null and c.order.is_empty() and m.order.is_empty():
		var diff := predicted_lap_time(m) - predicted_lap_time(c)
		return {"kind": "mate", "level": "info",
			"title": "%s: Ich bin schneller als %s" % [c.code, m.code],
			"text": "%s hängt seit %d Runden hinter %s und wäre ca. %.1f s pro Runde schneller." % [c.code, c.chase_laps, m.code, diff],
			"options": [
				{"label": "Platz tauschen", "action": "rq:mate:swap", "hint": "%s lässt %s vorbei. Er kann sich weigern (Gehorsam, Stimmung)." % [m.code, c.code]},
				{"label": "Position halten", "action": "rq:mate:hold", "hint": "Kein Zweikampf mehr. %s ist verärgert, wenn er schneller ist." % c.code},
				{"label": "Freies Duell", "action": "rq:mate:free", "hint": "Beide dürfen kämpfen, es gibt ein Kollisionsrisiko."},
			]}
	# Zweikampf
	var ahead := car_ahead(c)
	if c.close_laps >= 4 and ahead != null and ahead.team_id != c.team_id and remaining > 7:
		var uc := undercut_info(c)
		var gain: float = absf(STYLE_PACE[STYLE_MAX]) * track.lap_ref
		var dopts: Array = [
			{"label": "Angreifen", "action": "rq:duel:attack", "hint": "3 Runden Push: ca. %.1f s pro Runde schneller, 32 %% mehr Reifenverschleiß, etwas mehr Kontaktrisiko." % gain},
			{"label": "Reifen schonen", "action": "rq:duel:hold", "hint": "5 Runden Sparen: 28 % weniger Verschleiß. Du bleibst dran und greifst später an."},
		]
		if bool(uc["has"]) and float(uc["margin"]) > 0.3 and remaining > 8:
			dopts.append({"label": "Undercut: jetzt stoppen", "action": "rq:duel:box", "hint": "Frische Reifen bringen ca. %+.1f s gegenüber %s." % [float(uc["margin"]), ahead.code]})
		dopts.append({"label": "Weiter wie bisher", "action": "rq:duel:stay", "hint": "Nichts ändern."})
		return {"kind": "duel", "level": "info",
			"title": "%s hängt hinter %s fest" % [c.code, ahead.code],
			"text": "Seit %d Runden dicht dran (%.1f s). %s fährt auf %s, %d Runden alt. Deine Reifen: %d %% Rest." % [c.close_laps, c.gap_ahead, ahead.code, COMPOUNDS[ahead.compound]["name"], ahead.tyre_age_laps, int((1.0 - fr) * 100.0)],
			"options": dopts}
	# Reifen: Plan und Realität passen nicht mehr zusammen
	if fr >= 0.7 and fr < 0.93 and c.req_tyre_stint != c.pit_stops and remaining > 8 and c.compound < DRY_COUNT:
		var rate := maxf(wear_rate_now(c), 0.2)
		var holds := int(maxf(0.0, (life - c.tyre_wear) / rate))
		var nxt := _next_stop_lap(c, fl)
		if nxt - fl > holds + 1 and remaining > holds:
			c.req_tyre_stint = c.pit_stops
			var cmp := suggest_comp(c)
			var holds_m := int(float(holds) / float(STYLE_WEAR[0]))
			return {"kind": "tyres", "level": "warn",
				"title": "%s: Die Reifen lassen nach" % c.code,
				"text": "%d %% Rest, sie halten noch ca. %d Runden. %s." % [int((1.0 - fr) * 100.0), holds, ("Der nächste Stopp ist erst in %d Runden geplant" % (nxt - fl)) if nxt < laps else ("Bis ins Ziel sind es noch %d Runden" % remaining)],
				"options": [
					{"label": "Jetzt stoppen: %s" % COMPOUNDS[cmp]["name"], "action": "rq:tyres:box", "hint": _fresh_hint(c, cmp, cost)},
					{"label": "Reifen managen", "action": "rq:tyres:manage", "hint": "5 Runden Sparen: halten dann ca. %d statt %d Runden, ca. 0,6 s pro Runde langsamer." % [holds_m, holds]},
					{"label": "Weiter wie geplant", "action": "rq:tyres:stay", "hint": "Die Rundenzeiten brechen ein, sobald der Reifen am Ende ist."},
				]}
	return {}


## Wirkung frischer Reifen für Hinweise: schneller oder (harte Mischung) zunächst langsamer, dafür haltbarer.
func _fresh_hint(c: RaceCar, cmp: int, cost: float) -> String:
	var diff: float = tyre_loss(c) - fresh_loss(cmp)
	var lasts := int(life_eff(cmp))
	if diff >= 0.0:
		return "Frische Reifen: ca. %.1f s pro Runde schneller, halten ca. %d Runden. Der Stopp kostet %.0f s." % [diff, lasts, cost]
	return "Frische %s sind zunächst ca. %.1f s pro Runde langsamer, halten aber ca. %d Runden. Der Stopp kostet %.0f s." % [COMPOUNDS[cmp]["name"], -diff, lasts, cost]


## Antwort des Spielers auf eine Anfrage des Fahrers.
func apply_request(c: RaceCar, kind: String, choice: String) -> void:
	_apply_request(c, kind, choice, c.floor_laps)


func _apply_request(c: RaceCar, kind: String, choice: String, fl: int) -> void:
	var rq: Dictionary = requests.get(c.index, {})
	requests.erase(c.index)
	if rq.is_empty() or str(rq["kind"]) != kind:
		return
	var label := choice
	for o in rq["options"]:
		if str(o["action"]) == "rq:%s:%s" % [kind, choice]:
			label = str(o["label"])
	var comp := suggest_comp(c)
	match kind:
		"duel":
			if choice == "attack":
				c.follow = true
				radio_order(c, "push")
			elif choice == "hold":
				radio_order(c, "manage")
			elif choice == "box":
				request_pit(c, comp)
		"tyres":
			if choice == "box":
				request_pit(c, comp)
			elif choice == "manage":
				radio_order(c, "manage")
		"fuel":
			if choice == "lico":
				radio_order(c, "lico")
			elif choice == "manage":
				radio_order(c, "manage")
			elif choice == "box":
				request_pit(c, comp)
		"mate":
			var m := mate_of(c)
			if m != null and m.state == State.RACING:
				if choice == "swap":
					_issue_swap(m, c)
				elif choice == "hold":
					_issue_hold(m, c)
		"problem":
			if choice == "box":
				request_pit(c, comp)
				c.fail_lap = -1
				make_log("radio", "Funk an %s: Box, Box! Wir schauen uns das Auto an." % c.code, c)
			elif choice == "eco":
				radio_order(c, "manage")
				if c.problem_real and rng.randf() < 0.25:
					c.fail_lap = fl + rng.randi_range(5, 12)
			else:
				if c.problem_real and rng.randf() < 0.6:
					c.fail_lap = fl + rng.randi_range(3, 9)
	var entry := {"lap": fl, "car": c.index, "code": c.code, "kind": kind, "choice": label, "pos0": int(rq["pos0"]), "done": false, "result": "", "expired": choice == "expired", "box": choice == "box", "wait": 6 if choice == "box" else 4}
	decision_log.append(entry)


## Vier Runden nach einer Entscheidung: Wie ist es ausgegangen?
func _eval_decisions(c: RaceCar, fl: int) -> void:
	for e in decision_log:
		if bool(e["done"]) or int(e["car"]) != c.index or fl < int(e["lap"]) + int(e["wait"]):
			continue
		e["done"] = true
		var kind := str(e["kind"])
		var p1 := _pos_of(c)
		var res := ""
		if kind == "problem":
			res = "Die Warnung war berechtigt." if c.problem_real else "Es war ein Fehlalarm."
		elif kind == "fuel":
			res = "Der Tank reicht jetzt noch %.1f Runden bei Bedarf %.1f." % [fuel_range(c), fuel_need(c)]
		elif bool(e["box"]):
			res = "Frische Reifen, jetzt P%d. Der Stopp gleicht sich aus, sobald die anderen an die Box kommen." % p1
		else:
			var d := int(e["pos0"]) - p1
			res = "P%d, " % p1 + (("%d Platz gewonnen." % d if d == 1 else "%d Plätze gewonnen." % d) if d > 0 else ("Position gehalten." if d == 0 else ("%d Platz verloren." % -d if d == -1 else "%d Plätze verloren." % -d)))
		e["result"] = res
		if not bool(e["expired"]):
			make_log("radio", "Auswertung %s (%s): %s" % [c.code, str(e["choice"]), res], c)


## Taktik-Empfehlungen für ein Spielerauto: [{"level": bad|warn|good|info, "title", "text", "action", "label"}], wichtigste zuerst.
func advice(c: RaceCar) -> Array:
	var out: Array = []
	if c.state != State.RACING or not started:
		return out
	var fl := leader_lap()
	var remaining := laps - fl
	# Sprit
	var need := fuel_need(c)
	var have := fuel_range(c)
	if have < need:
		var act := "style_save" if c.style != 0 else ("pit_now" if rules["refuel"] else "")
		out.append({"level": "bad", "title": "Sprit knapp", "text": "Der Tank reicht noch %.1f Runden, bis Stopp/Ziel fehlen %.1f. %s" % [have, need - have, "Fahrstil Sparen verbraucht ca. 6 % weniger." if c.style != 0 else "Früher an die Box."], "action": act, "label": "Sparen" if act == "style_save" else "Jetzt stoppen"})
	# Schaden
	if c.damage >= 0.003 and remaining > 6 and not c.pit_requested:
		out.append({"level": "bad", "title": "Schaden am Auto", "text": "Der Frontflügel kostet ca. %.1f s pro Runde. Ein Stopp tauscht ihn." % (c.damage * track.lap_ref), "action": "pit_now", "label": "Jetzt stoppen"})
	# Wetter
	var rc := recommended_compound()
	if rc >= 0 and c.compound != rc and not c.pit_requested:
		out.append({"level": "bad", "title": "Falsche Reifen für die Nässe", "text": "Streckennässe %d %%: %s wäre jetzt richtig." % [int(wet * 100.0), COMPOUNDS[rc]["name"]], "action": "pit_wet", "label": "Auf %s wechseln" % COMPOUNDS[rc]["name"]})
	elif c.compound >= DRY_COUNT and wet < 0.08 and rain < 0.06 and not c.pit_requested:
		out.append({"level": "warn", "title": "Strecke trocknet ab", "text": "Auf Regenreifen verlierst du jetzt Zeit und Reifen. Auf Slicks wechseln.", "action": "pit_slick", "label": "Auf Slicks wechseln"})
	else:
		var rd := rain_radar()
		if float(rd["eta"]) > 0.0 and float(rd["eta"]) < 8.0 and c.compound < DRY_COUNT and float(rd["prob"]) > 0.55:
			out.append({"level": "warn", "title": "Regen in ca. %d min" % int(rd["eta"]), "text": "Wahrscheinlichkeit %d %%. Eine Runde vor Regenbeginn auf Inters zu stoppen spart Zeit, Fehlalarme sind aber möglich." % int(float(rd["prob"]) * 100.0), "action": "pit_inter", "label": "Wette: auf Inters"})
	# Safety Car / VSC
	if status != Status.GREEN and c.tyre_wear > life_eff(c.compound) * 0.3 and remaining > 6 and not c.pit_requested:
		out.append({"level": "good", "title": "Günstiger Stopp unter %s" % ("Safety Car" if status == Status.SC else "VSC"), "text": "Der Stopp kostet jetzt nur %.0f s statt %.0f s." % [pit_cost_now(), track.pit_loss * float(rules["pit_loss_scale"])], "action": "pit_now", "label": "Jetzt stoppen"})
	# Reifen
	var win := pit_window_info(c, fl)
	if not c.pit_requested and bool(win["need"]):
		if float(win["frac"]) > 0.95:
			out.append({"level": "bad", "title": "Reifen am Ende", "text": "%d %% verbraucht, jede Runde kostet jetzt viel Zeit." % int(float(win["frac"]) * 100.0), "action": "pit_now", "label": "Jetzt stoppen"})
		elif fl >= int(win["ideal"]):
			out.append({"level": "warn", "title": "Stopp-Fenster offen", "text": str(win["text"]), "action": "pit_now", "label": "Jetzt stoppen"})
	# Undercut / Konter
	var uc := undercut_info(c)
	if bool(uc["has"]) and float(uc["margin"]) > 0.8 and not c.pit_requested and c.tyre_wear > life_eff(c.compound) * 0.3:
		var ac: RaceCar = uc["car"]
		out.append({"level": "good", "title": "Undercut gegen %s" % ac.code, "text": "Abstand %.1f s, mit frischen Reifen ca. %+.1f s Vorteil. Es sollte klappen." % [float(uc["gap"]), float(uc["margin"])], "action": "undercut", "label": "Jetzt stoppen"})
	var th := threat_info(c)
	if bool(th["has"]) and float(th["margin"]) > -0.3 and not c.pit_requested:
		var bc: RaceCar = th["car"]
		out.append({"level": "warn", "title": "%s droht mit Undercut" % bc.code, "text": "%.1f s hinter dir. Ein Konter-Stopp verhindert den Positionsverlust." % float(th["gap"]), "action": "undercut", "label": "Konter-Stopp"})
	# Batterie
	if has_ers():
		if c.ers < 12.0 and c.ers_mode == 2:
			out.append({"level": "warn", "title": "Batterie fast leer", "text": "Angriffsmodus wirkt bald nicht mehr. Auf Normal oder Laden stellen.", "action": "ers_normal", "label": "Normal"})
		elif c.ers > 85.0 and c.ers_mode != 2 and c.gap_ahead < 1.6 and car_ahead(c) != null:
			out.append({"level": "info", "title": "Batterie voll", "text": "Ein Gegner ist in Reichweite: Angriffsmodus nutzen.", "action": "ers_attack", "label": "Angriff"})
	# Windschatten / verwirbelte Luft
	if c.tow > 0.35 and c.follow and car_ahead(c) != null:
		out.append({"level": "info", "title": "Im Windschatten", "text": "Dranbleiben bringt Topspeed auf den Geraden. In Kurven kostet die verwirbelte Luft Reifen."})
	# Teamorder
	var m := mate_of(c)
	if m != null and m.state == State.RACING and car_ahead(m) == c and m.gap_ahead < 1.3 and predicted_lap_time(m) < predicted_lap_time(c) - 0.3 and c.order.is_empty():
		out.append({"level": "info", "title": "%s ist schneller" % m.code, "text": "Dein Teamkollege klebt hinter dir und hat mehr Tempo. Platztausch erwägen.", "action": "swap", "label": "Platz tauschen"})
	var rank := {"bad": 0, "warn": 1, "good": 2, "info": 3}
	out.sort_custom(func(a, b): return int(rank[a["level"]]) < int(rank[b["level"]]))
	return out.slice(0, 4)


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


## Mittlerer Reifenverschleiß pro Runde für die Vorhersage (Fahrer, Auto, Tankgewicht).
func _pred_wear_rate(c: RaceCar, fuel: float, style := STYLE_STD) -> float:
	return float(STYLE_WEAR[style]) * (1.0 - 0.07 * c.tyre_trait) * (1.0 - 0.09 * c.tyre_care) * clampf(1.0 + 0.0018 * (fuel - 50.0), 0.9, 1.2)


## Vorhergesagte Rundenzeiten eines Plans ohne Verkehr und Ereignisse.
## {"times": [s je Runde ohne Boxenzeit], "pit": [Runden mit Stopp], "total": s, "cum": [Rennzeit nach jeder Runde], "comp": [Mischung je Runde]}
func predict_laps(c: RaceCar, start_comp: int, plan: Array, start_wear := 0.0) -> Dictionary:
	var comp := start_comp
	var wear := start_wear
	var total := 0.0
	var stops_by_lap := {}
	var sorted: Array = plan.duplicate()
	sorted.sort_custom(func(a, b): return int(a["lap"]) < int(b["lap"]))
	for s in sorted:
		stops_by_lap[int(s["lap"])] = s
	var fuel := fuel_for_laps(float(laps) + c.fuel_extra)
	if rules["refuel"]:
		var first := laps
		for s in sorted:
			first = mini(first, int(s["lap"]))
		fuel = fuel_for_laps(float(first) + c.fuel_extra)
	var sev: float = track.tyre_severity
	var times: Array = []
	var cum: Array = []
	var comps: Array = []
	var pit: Array = []
	var fuel_s: Array = []
	var tyre_s: Array = []
	var base_t: float = track.lap_ref / c.pace_base
	var age := 0
	for lap in range(1, laps + 1):
		var cd: Dictionary = COMPOUNDS[comp]
		var life := life_eff(comp)
		var rate := _pred_wear_rate(c, fuel)
		var w_mid := wear + 0.5 * rate
		var loss: float = float(cd["offset"]) + float(cd["deg"]) * sev * w_mid
		if w_mid > life:
			loss += 0.30 * pow(w_mid - life, 1.35)
		if age < 2 and comp < DRY_COUNT:
			loss += float(cd["warm"]) * (1.0 if age == 0 else 0.5)
		age += 1
		loss *= scale_time
		var floss := fuel * FUEL_TIME * scale_time
		var p: float = c.pace_base / (1.0 + (loss + floss) / track.lap_ref)
		var lt: float = track.lap_ref / p
		var lt_fuel: float = track.lap_ref / (c.pace_base / (1.0 + floss / track.lap_ref))
		fuel_s.append(maxf(0.0, lt_fuel - base_t))
		tyre_s.append(maxf(0.0, lt - lt_fuel))
		times.append(lt)
		comps.append(comp)
		total += lt
		wear += rate
		fuel = maxf(0.0, fuel - burn_per_lap)
		if stops_by_lap.has(lap) and lap < laps:
			var st: Dictionary = stops_by_lap[lap]
			comp = int(st["comp"])
			wear = 0.0
			age = 0
			total += track.pit_loss * float(rules["pit_loss_scale"])
			pit.append(lap)
			if rules["refuel"]:
				var nxt := laps
				for s2 in sorted:
					if int(s2["lap"]) > lap:
						nxt = mini(nxt, int(s2["lap"]))
				fuel = fuel_for_laps(float(nxt - lap) + float(st.get("fuel", 0.0)))
		cum.append(total)
	return {"times": times, "pit": pit, "total": total, "cum": cum, "comp": comps, "fuel_s": fuel_s, "tyre_s": tyre_s, "base": base_t}


## Grobe Renndauerschätzung (s) für einen Strategieplan, ohne Verkehr/Ereignisse.
func estimate_time(c: RaceCar, start_comp: int, plan: Array) -> float:
	return float(predict_laps(c, start_comp, plan)["total"])


## Strategie-Varianten für ein Auto: [{"key", "name", "desc", "start", "plan", "time", "stops"}].
## A = ausgewogen (schnellste Schätzung), B = wenig Stopps, C = offensiv (ein Stopp mehr, weiche Reifen zuerst).
func plan_variants(c: RaceCar) -> Array:
	var out: Array = []
	var a := _plan_search(c, 1, 3, 1.05, false)
	if not a.is_empty():
		a["key"] = "A"
		a["name"] = "A  Ausgewogen"
		a["desc"] = "Schnellste Schätzung über die Renndistanz."
		out.append(a)
	var b: Dictionary = {}
	for n in range(0, 4):
		b = _plan_search(c, n, n, 1.0, false)
		if not b.is_empty():
			break
	if not b.is_empty():
		b["key"] = "B"
		b["name"] = "B  Wenig Stopps"
		b["desc"] = "Möglichst wenige Boxenstopps: weniger Zeitverlust, mehr Reifenverschleiß und Verkehr-Risiko."
		out.append(b)
	var base_stops: int = int(a["stops"]) if not a.is_empty() else 1
	var cc := _plan_search(c, mini(base_stops + 1, 3), mini(base_stops + 1, 3), 1.05, true)
	if not cc.is_empty():
		cc["key"] = "C"
		cc["name"] = "C  Offensiv"
		cc["desc"] = "Ein Stopp mehr, kürzere Stints auf schnellen Reifen: Angriff und Undercut-Chancen."
		out.append(cc)
	return out


func _stop_candidates(n: int) -> Array:
	var res: Array = []
	var lo := maxi(4, int(float(laps) * 0.15))
	var hi := laps - 4
	if n == 0:
		return [[]]
	var step := maxi(1, laps / 28) if n == 1 else (maxi(2, laps / 18) if n == 2 else maxi(3, laps / 12))
	if n == 1:
		var l := lo
		while l <= hi:
			res.append([l])
			l += step
	elif n == 2:
		var l1 := lo
		while l1 <= hi:
			var l2 := l1 + 7
			while l2 <= hi:
				res.append([l1, l2])
				l2 += step
			l1 += step
	else:
		var m1 := lo
		while m1 <= hi:
			var m2 := m1 + 7
			while m2 <= hi:
				var m3 := m2 + 7
				while m3 <= hi:
					res.append([m1, m2, m3])
					m3 += step
				m2 += step
			m1 += step
	return res


func _plan_search(c: RaceCar, n_min: int, n_max: int, over: float, soft_start: bool) -> Dictionary:
	var best: Dictionary = {}
	var best_t := 1e18
	var min_c: int = int(rules["min_compounds"])
	for n in range(n_min, n_max + 1):
		for stops in _stop_candidates(n):
			var lens: Array = []
			var prev := 0
			for sl in stops:
				lens.append(int(sl) - prev)
				prev = int(sl)
			lens.append(laps - prev)
			# zulässige Mischungen je Stint
			var opts: Array = []
			var ok := true
			for k in lens.size():
				var o: Array = []
				for cm in DRY_COUNT:
					if life_eff(cm) * over >= float(lens[k]) and (not (soft_start and k == 0) or cm == 0):
						o.append(cm)
				if o.is_empty():
					ok = false
					break
				opts.append(o)
			if not ok:
				continue
			var idx: Array = []
			for k in opts.size():
				idx.append(0)
			while true:
				var combo: Array = []
				var distinct := {}
				for k in opts.size():
					combo.append(int(opts[k][int(idx[k])]))
					distinct[combo[k]] = true
				if min_c < 2 or distinct.size() >= 2:
					var plan: Array = []
					for k in stops.size():
						plan.append({"lap": int(stops[k]), "comp": int(combo[k + 1]), "fuel": 0.0})
					var tt := estimate_time(c, int(combo[0]), plan)
					if tt < best_t:
						best_t = tt
						best = {"start": int(combo[0]), "plan": plan, "time": tt, "stops": n}
				# nächste Kombination
				var k2 := opts.size() - 1
				while k2 >= 0:
					idx[k2] = int(idx[k2]) + 1
					if int(idx[k2]) < opts[k2].size():
						break
					idx[k2] = 0
					k2 -= 1
				if k2 < 0:
					break
	return best


## Eine frische Simulation mit gleichem Startfeld, Wetter und Spielerplan für Vorschau-Läufe (Monte Carlo).
## plan_override: {"start", "plan", "extra"} ersetzt den Plan des Spielerautos mit Index car_index.
func preview_clone(seed_value: int, car_index := -1, plan_override: Dictionary = {}):
	var s = get_script().new()
	s.setup(year, track, _src["teams"], laps, player_team, seed_value)
	for k in ["wet", "rain", "rain_start", "rain_end", "rain_peak", "rain_chance", "forecast_noise", "ghost_start", "ghost_end", "setup_ideal", "engine_allowance", "engine_life", "rain_announced", "crew_form"]:
		s.set(k, get(k))
	s.tyre_noise = tyre_noise.duplicate()
	s.practice = practice.duplicate(true)
	s.tyre_inv = tyre_inv.duplicate(true)
	s.grid_penalties = grid_penalties.duplicate()
	for i in cars.size():
		var a: RaceCar = cars[i]
		var b: RaceCar = s.cars[i]
		b.grid = a.grid
		b.quali_time = a.quali_time
		b.forced_start = a.forced_start
		b.grid_penalty = a.grid_penalty
		b.pace_base = a.pace_base
		b.qpace = a.qpace
		b.setup_err = a.setup_err
		b.engine_wear = a.engine_wear
		b.engine_new = a.engine_new
	s.quali_done = true
	for i in cars.size():
		var a2: RaceCar = cars[i]
		var b2: RaceCar = s.cars[i]
		if a2.is_player:
			b2.fuel_extra = a2.fuel_extra
			b2.follow = a2.follow
			b2.style = a2.style
			b2.rules = a2.rules.duplicate(true)
			b2.compound = a2.compound
			b2.plan = a2.plan.duplicate(true)
			if i == car_index and not plan_override.is_empty():
				b2.compound = int(plan_override["start"])
				b2.plan = plan_override["plan"].duplicate(true)
				b2.fuel_extra = float(plan_override.get("extra", a2.fuel_extra))
			b2.used_compounds = [b2.compound]
			b2.fuel = s._fuel_for_stint(b2, 0)
		else:
			s._plan_ai(b2)
	return s

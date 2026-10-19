extends Node
## Spielstand (Autoload "Game"): Karriere über mehrere Saisons, Team, Kalender, Meisterschaft, Budget, Entwicklung,
## Fahrermarkt (Fahrer, Verträge, News) und Kostenobergrenze. Speichern/Laden.

const Market = preload("res://scripts/market.gd")
const Career = preload("res://scripts/career.gd")
const Field = preload("res://scripts/field.gd")

const SAVE_PATH := "user://savegame.json"
const MAX_LEVEL := 6
const S_OUT := 3
## Jahre mit neuem Reglement: das Kräfteverhältnis wird stärker durchgemischt.
const REG_YEARS := [2009, 2014, 2017, 2022, 2026, 2030, 2034]

const UPGRADES := {
	"aero": {"name": "Aerodynamik", "desc": "+0,10 % Pace je Stufe (neues Auto jede Saison)", "cost": 20.0},
	"engine": {"name": "Antrieb", "desc": "+0,10 % Pace je Stufe (neues Auto jede Saison)", "cost": 20.0},
	"chassis": {"name": "Chassis", "desc": "+0,10 % Pace je Stufe (neues Auto jede Saison)", "cost": 20.0},
	"reliab": {"name": "Zuverlässigkeit", "desc": "12 % weniger technische Defekte je Stufe", "cost": 12.0},
	"pit": {"name": "Boxencrew", "desc": "0,12 s schnellere Stopps je Stufe", "cost": 8.0},
	"coach": {"name": "Fahrertraining", "desc": "+0,06 % Fahrerpace je Stufe", "cost": 10.0},
}
const UPGRADE_ORDER := ["aero", "engine", "chassis", "reliab", "pit", "coach"]

var year := 2026
var career_start := 2026
var team_id := ""
var teams: Array = []
var calendar: Array = []
var round_index := 0
var driver_points := {}
var team_points := {}
var wins := {}
var history: Array = []      # je Rennen: {"name":..., "order":[Codes], "points":{id:pts}}
var budget := 60.0
var upgrades := {}
var dev_pace := {}           # Team-ID -> Entwicklung (Pace-Zuwachs)
var rng := RandomNumberGenerator.new()
var rules: Dictionary = {}
var last_result: Dictionary = {}
var requests_on := true          # Anfragen des Fahrers im Rennen (Entscheidungskarten)
var solo_code := ""              # 1-Fahrer-Modus: Kürzel des betreuten Fahrers ("*" = bester Fahrer des Teams), leer = beide Autos
# Karriere (siehe career.gd)
var board := 60.0                # Vertrauen des Vorstands 0..100
var goal_cache: Dictionary = {}  # Rennziel des aktuellen Rennens {"round", "goal"} (nicht gespeichert)
var sponsor_id := ""             # Sponsorenvertrag ("" = keiner gewählt, es gilt "Ausgewogen")
var season_goal_rank := 0        # Saisonziel: Platz in der Konstrukteurs-WM
var season_eval_done := false
var last_season_eval := ""
var pending_event: Dictionary = {}   # offene Meldung aus der Zentrale: {"id"}
var event_seen := false          # die Meldung wurde in der Zentrale schon angezeigt
var event_last: Dictionary = {}  # Meldungs-ID -> Rennnummer des letzten Auftretens
var event_mods: Array = []       # laufende Wirkungen: [{"mech": Faktor, "left": Rennen}]
var career_log: Array = []       # entschiedene Meldungen
var career_race_no := 0          # gefahrene Rennen der Karriere
var goal_log: Array = []         # Rennziele dieser Saison
var finance_log: Array = []      # Einnahmen dieser Saison
var active := false
var weekend_sim = null
var weekend_round := -1

# Fahrermarkt
var drivers := {}            # Fahrer-ID -> Fahrerdaten (siehe market.gd)
var news: Array = []         # {"year", "round", "kind", "text"}
var market_log: Array = []   # Meldungen der laufenden Marktphase
var market_open := false
var season_log: Array = []   # je Saison: Weltmeister und Platzierung des Spielers
var team_meta := {}          # Team-ID -> {prestige, last_rank, score, pace_rank, since, renamed, formerly, bottom, fresh} (siehe field.gd)
# Teamfeld (siehe field.gd)
var field_dynamic := true    # Teamfeld verändert sich über die Karriere (Neueinsteiger, Rückzüge, Fusionen, Umbenennungen)
var field_plan: Dictionary = {}   # angekündigte Änderungen fürs nächste Jahr, werden beim Marktschluss umgesetzt
var field_log: Array = []    # Chronik der Änderungen: {"year", "kind", "text"}
var field_last_entry := -99  # Jahr des letzten Neueinsteigers
var cap := 160.0             # Kostenobergrenze pro Saison (Mio. $): Gehälter + Entwicklung + Provisionen
var dev_spent := 0.0
var cap_spent_fees := 0.0
var crew_form := 0.0          # Form der Boxencrew 0..1 (Stopp-Training), verfällt von Rennen zu Rennen
var engines := {}            # Fahrer-ID -> {"used": Anzahl Motoren dieser Saison, "wear": Verschleiß 0..1+}


func _ready() -> void:
	rng.randomize()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Neue Karriere ab p_year. Startjahre nach dem letzten Datenjahr (2027 und später) beginnen mit dem vorausgerechneten Teamfeld (forecast_field).
func new_season(p_year: int, p_team: String) -> void:
	var future := p_year > DB.MAX_YEAR
	if future and not (forecast_year == p_year and forecast_dynamic == field_dynamic and not teams.is_empty()):
		forecast_field(p_year)       # der Startbildschirm hat die Prognose normalerweise schon gerechnet
	year = p_year
	career_start = p_year
	team_id = p_team
	solo_code = ""
	board = 60.0
	event_last = {}
	event_mods = []
	career_log = []
	career_race_no = 0
	upgrades = {}
	for k in UPGRADES.keys():
		upgrades[k] = 0
	if not future:
		_setup_base(year)
	forecast_year = 0
	_begin_season()
	# Startbudget nach Teamstärke
	var rank := team_rank(team_id)
	budget = 90.0 - 6.0 * float(rank)
	active = true


## Teams, Fahrer und Markt aus den echten Daten der Saison base_year aufbauen (ohne Spielerteam).
func _setup_base(base_year: int) -> void:
	teams = DB.build_teams(base_year)
	team_meta = {}
	DB.custom_teams = {}
	field_plan = {}
	field_log = []
	field_last_entry = -99
	season_log = []
	driver_points = {}
	team_points = {}
	wins = {}
	dev_pace = {}
	for t in teams:
		dev_pace[t["id"]] = 0.0
	Market.init_career(base_year)


var forecast_year := 0           # Startjahr der vorbereiteten Prognose (nach 2026), 0 = keine
var forecast_dynamic := true
var forecast_seed := 119         # eine feste "Zukunft" (abwechslungsreich, aber ruhig, per Suche gewählt): alle Prognose-Startjahre gehören zum selben Verlauf
var _ghost := false              # Prognoselauf: nichts speichern


## Teamfeld und Fahrer für ein Startjahr nach dem letzten Datenjahr vorausrechnen: ab 2026 laufen die Saisonwechsel ohne Spieler
## (KI-Fahrermarkt, Neueinsteiger, Rückzüge, Fusionen, Umbenennungen), das Ergebnis je Jahr ist reproduzierbar. Rückgabe: die Teams.
## Der Zustand bleibt in Game stehen, new_season übernimmt ihn. Ein laufender Spielstand wird vorher gespeichert.
func forecast_field(target: int) -> Array:
	if target <= DB.MAX_YEAR:
		return DB.build_teams(target)
	if forecast_year == target and forecast_dynamic == field_dynamic and not teams.is_empty():
		return teams
	if active and not _ghost:
		save()
	_ghost = true
	active = false
	rng.seed = forecast_seed
	year = DB.MAX_YEAR
	career_start = DB.MAX_YEAR
	team_id = ""
	solo_code = ""
	upgrades = {}
	for k in UPGRADES.keys():
		upgrades[k] = 0
	_setup_base(year)
	_begin_season()
	while year < target:
		_ghost_points()
		Market.open_market()
		finish_market_and_advance()
	news = []
	market_log = []
	season_log = []
	_ghost = false
	rng.randomize()
	forecast_year = target
	forecast_dynamic = field_dynamic
	return teams


## Ersatz für eine gefahrene Saison im Prognoselauf: Punkte nach Stärke mit Streuung.
func _ghost_points() -> void:
	var order: Array = teams.duplicate()
	order.sort_custom(func(a, b): return float(a["pace"]) + float(dev_pace.get(a["id"], 0.0)) > float(b["pace"]) + float(dev_pace.get(b["id"], 0.0)))
	var tbl := [400.0, 300.0, 240.0, 180.0, 130.0, 90.0, 60.0, 35.0, 18.0, 8.0, 3.0, 1.0]
	for i in order.size():
		team_points[order[i]["id"]] = tbl[mini(i, tbl.size() - 1)] * rng.randf_range(0.6, 1.4)


## Setzt Kalender, Tabellen und Zähler für die laufende Saison zurück (Fahrer müssen bereits synchronisiert sein).
func _begin_season(offer := true) -> void:
	var s := DB.season(mini(year, DB.MAX_YEAR))
	calendar = s["calendar"]
	round_index = 0
	driver_points = {}
	team_points = {}
	wins = {}
	history = []
	for t in teams:
		team_points[t["id"]] = 0.0
		if not dev_pace.has(t["id"]):
			dev_pace[t["id"]] = 0.0
	sync_teams()
	rules = DB.rules(year)
	weekend_sim = null
	weekend_round = -1
	last_result = {}
	dev_spent = 0.0
	cap_spent_fees = 0.0
	engines = {}
	goal_log = []
	finance_log = []
	season_eval_done = false
	last_season_eval = ""
	season_goal_rank = Career.pace_rank()
	if offer:
		sponsor_id = ""
		pending_event = {"id": "sponsor"}
		event_seen = false
	market_open = false
	sync_teams()
	Market.refresh_scores()


## Teams mit den aktuellen Fahrern aus dem Fahrermarkt bestücken.
func sync_teams() -> void:
	for t in teams:
		var list: Array = []
		for d in Market.current_drivers(t["id"]):
			list.append({"id": d["id"], "code": d["code"], "name": d["name"], "family": d["family"], "number": d["number"],
				"team": t["id"], "skill": float(d["skill"]), "qskill": float(d["qskill"]), "crash_rate": float(d["crash_rate"]),
				"morale": float(d["morale"]), "rating": Market.rating_of(d), "traits": d.get("traits", Market.make_traits(str(d["id"]))),
				"engine_wear": float(engines.get(d["id"], {}).get("wear", 0.0)), "engines_used": int(engines.get(d["id"], {}).get("used", 1))})
		t["drivers"] = list
		for e in list:
			if not driver_points.has(e["id"]):
				driver_points[e["id"]] = 0.0
			if not wins.has(e["id"]):
				wins[e["id"]] = 0


func team_rank(id: String) -> int:
	for i in teams.size():
		if teams[i]["id"] == id:
			return i
	return 0


func get_team(id: String) -> Dictionary:
	for t in teams:
		if t["id"] == id:
			return t
	return {}


func player_team() -> Dictionary:
	return get_team(team_id)


## Kürzel des betreuten Fahrers im 1-Fahrer-Modus ("" = du führst beide Autos). Fällt der Fahrer weg, gilt der beste Fahrer des Teams.
func solo_driver() -> String:
	if solo_code == "":
		return ""
	var drs: Array = player_team().get("drivers", [])
	if drs.is_empty():
		return ""
	for d in drs:
		if str(d["code"]) == solo_code:
			return solo_code
	return str(drs[0]["code"])


func season_over() -> bool:
	return round_index >= calendar.size()


func current_race() -> Dictionary:
	if round_index < calendar.size():
		return calendar[round_index]
	return {}


## Erlaubte Motoren pro Fahrer und Saison (0 = keine Begrenzung, vor 2009).
func engine_allowance(y: int = -1) -> int:
	var yy := year if y < 0 else y
	if yy < 2009:
		return 0
	if yy <= 2013:
		return 8
	if yy <= 2017:
		return 5
	if yy <= 2025:
		return 3
	return 4


## Boxenstopp-Training: kostet Budget (Kostenobergrenze), hebt die Crew-Form. Rückgabe: Meldung.
func crew_train() -> String:
	var cost := 1.0
	if crew_form >= 0.99:
		return "Die Crew ist bereits in Topform."
	if budget < cost or cap_left() < cost:
		return "Nicht genug Budget oder Kostenobergrenze erreicht."
	budget -= cost
	dev_spent += cost
	crew_form = minf(1.0, crew_form + 0.34)
	return "Stopp-Training abgeschlossen: Crew-Form %d %%." % int(crew_form * 100.0)


## Rennwochenenden, die ein Motor im Schnitt durchhält.
func engine_life_races() -> float:
	var a := engine_allowance()
	if a <= 0:
		return 99.0
	return maxf(1.0, float(calendar.size()) / float(a) * 1.15)


## Teams mit aktuellem Entwicklungsstand für die Simulation.
func sim_teams() -> Array:
	var out: Array = []
	for t in teams:
		var c: Dictionary = t.duplicate(true)
		c["pace"] = float(t["pace"]) + float(dev_pace.get(t["id"], 0.0))
		var prof: Dictionary = DB.car_profile(str(t["id"]), year)
		if t["id"] == team_id:
			prof["df"] = clampf(float(prof["df"]) + 0.08 * float(upgrades.get("aero", 0)), -1.0, 1.0)
			prof["power"] = clampf(float(prof["power"]) + 0.08 * float(upgrades.get("engine", 0)), -1.0, 1.0)
		c["profile"] = prof
		if t["id"] == team_id:
			var lv: Dictionary = upgrades
			c["mech_mult"] = pow(0.88, float(lv["reliab"])) * Career.mech_factor()
			c["pit_skill"] = -0.12 * float(lv["pit"])
			for d in c["drivers"]:
				d["skill"] = float(d["skill"]) + 0.0006 * float(lv["coach"])
				d["qskill"] = float(d["qskill"]) + 0.0004 * float(lv["coach"])
		# Stimmung wirkt leicht auf die Fahrerleistung
		for d in c["drivers"]:
			d["skill"] = float(d["skill"]) + (float(d.get("morale", 0.62)) - 0.62) * 0.0005
		c["engine_allowance"] = engine_allowance()
		c["engine_life"] = engine_life_races()
		if t["id"] == team_id:
			c["crew_form"] = crew_form
		out.append(c)
	return out


## Rundenzahl: echte Distanz, außer die Daten zeigen ein verkürztes/abgebrochenes Rennen oder eine andere Streckenvariante
## (z. B. Sepang 2009 mit 31 Runden). Dann gilt die Standarddistanz von ca. 305 km (Monaco ca. 260 km).
func race_laps(race: Dictionary, track) -> int:
	var l: int = int(race.get("laps", 0))
	var target := 260000.0 if track.id == "monaco" else 305000.0
	var ratio: float = float(l) * track.length / target
	if l <= 0 or ratio < 0.85 or ratio > 1.07:
		l = int(ceil(target / track.length))
	return l


# ------------------------------------------------------------------ Geld und Kostenobergrenze

func payroll_current() -> float:
	var s := 0.0
	for d in Market.current_drivers(team_id):
		s += float(d["contract"].get("salary", 0.0))
	return s


## Bereits gebundene Mittel dieser Saison (Gehälter + Entwicklung + Provisionen).
func cap_used() -> float:
	return payroll_current() + dev_spent + cap_spent_fees


func cap_left() -> float:
	return cap - cap_used()


func upgrade_cost(key: String) -> float:
	return float(UPGRADES[key]["cost"]) * float(int(upgrades[key]) + 1)


func can_upgrade(key: String) -> bool:
	return int(upgrades[key]) < MAX_LEVEL and budget >= upgrade_cost(key) and upgrade_cost(key) <= cap_left()


func buy_upgrade(key: String) -> bool:
	if not can_upgrade(key):
		return false
	budget -= upgrade_cost(key)
	dev_spent += upgrade_cost(key)
	upgrades[key] = int(upgrades[key]) + 1
	if key in ["aero", "engine", "chassis"]:
		dev_pace[team_id] = float(dev_pace[team_id]) + 0.0010
	return true


func final_rank(tid: String) -> int:
	var st := team_standings()
	for i in st.size():
		if st[i]["id"] == tid:
			return i + 1
	return st.size()


## Ergebnis eines Rennens übernehmen (sim = fertige RaceSim).
func finish_race(sim) -> Dictionary:
	if not pending_event.is_empty():
		Career.apply_default()       # ohne Entscheidung gilt die Vorgabe
	var order: Array = sim.ranking()
	var pts_table: Array = rules["points"]
	var gained := {}
	var rows: Array = []
	var fl_car = sim.fastest_car
	for i in order.size():
		var c = order[i]
		var p := 0.0
		if i < pts_table.size() and c.state != S_OUT:
			p = float(pts_table[i])
		if rules["fastest_lap_point"] and fl_car == c and i < 10 and c.state != S_OUT:
			p += 1.0
		var did := _driver_id(c)
		driver_points[did] = float(driver_points.get(did, 0.0)) + p
		team_points[c.team_id] = float(team_points.get(c.team_id, 0.0)) + p
		if i == 0:
			wins[did] = int(wins.get(did, 0)) + 1
		gained[c.code] = p
		rows.append({"pos": i + 1, "code": c.code, "name": c.driver_name, "team": c.team_name, "team_id": c.team_id, "color": c.color,
			"points": p, "laps": c.finish_laps, "best": c.best_lap, "stops": c.pit_stops, "out": c.out_reason,
			"grid": c.grid, "state": c.state, "gap": sim.gap_text(c, order[0]), "player": c.is_player, "time": c.finish_time})
	# Budget
	var rank_now := _team_standing_rank()
	var income := 10.0 + 14.0 * (1.0 - float(rank_now) / maxf(1.0, float(teams.size() - 1)))
	var team_gain := 0.0
	for r in rows:
		if r["team_id"] == team_id:
			team_gain += float(r["points"])
	var sp: Dictionary = Career.sponsor()
	income += team_gain * 0.35 * float(sp["pts"]) + float(sp["base"])
	# Gehälter laufen pro Rennen, Bezahlfahrer bringen Sponsorgelder
	var n_races: float = maxf(1.0, float(calendar.size()))
	var salaries := payroll_current() / n_races
	var sponsors := 0.0
	for d in Market.current_drivers(team_id):
		sponsors += float(d["dowry"]) / n_races
	income += sponsors
	var gr: Dictionary = Career.settle_race(rows)
	income += float(gr["bonus"])
	income *= 1.0 + (board - 50.0) / 500.0       # Vertrauen des Vorstands: bis zu +-10 % auf die Einnahmen
	board = clampf(board + float(gr["board"]), 0.0, 100.0)
	budget += income - salaries
	# KI-Entwicklung
	for t in teams:
		if t["id"] == team_id:
			continue
		var strength := 1.0 - 0.5 * float(team_rank(t["id"])) / maxf(1.0, float(teams.size()))
		dev_pace[t["id"]] = float(dev_pace[t["id"]]) + rng.randfn(0.00035 * strength, 0.00035)
	# Motorverschleiß und Stimmungsfolgen der Taktik übernehmen
	for c in order:
		var did2 := _driver_id(c)
		engines[did2] = {"used": int(c.engines_used), "wear": float(c.engine_wear)}
		if drivers.has(did2):
			drivers[did2]["morale"] = clampf(float(drivers[did2]["morale"]) + float(c.morale_delta), 0.0, 1.0)
	weekend_sim = null
	crew_form *= 0.6
	round_index += 1
	career_race_no += 1
	goal_log.append({"race": str(calendar[round_index - 1]["name"]), "goal": str(gr["goal"]), "word": str(gr["word"]), "bonus": float(gr["bonus"]), "board": float(gr["board"]), "best": int(gr["best"])})
	finance_log.append({"race": str(calendar[round_index - 1]["name"]), "income": income, "salaries": salaries, "bonus": float(gr["bonus"])})
	Career.tick_mods()
	Career.roll_event()
	Market.update_morale(rows)
	sync_teams()
	if round_index % 4 == 0:
		Market.season_rumors()
	last_result = {"rows": rows, "race": calendar[round_index - 1], "income": income, "salaries": salaries,
		"fastest": fl_car.code if fl_car != null else "", "fastest_time": sim.fastest_lap,
		"decisions": sim.decision_log.filter(func(e): return not bool(e["expired"])), "goal": gr}
	history.append({"name": calendar[round_index - 1]["name"], "order": rows.map(func(r): return r["code"])})
	save()
	return last_result


func _driver_id(c) -> String:
	for t in teams:
		for d in t["drivers"]:
			if d["code"] == c.code and t["id"] == c.team_id:
				return d["id"]
	return c.code


func _team_standing_rank() -> int:
	var arr: Array = teams.duplicate()
	arr.sort_custom(func(a, b): return float(team_points[a["id"]]) > float(team_points[b["id"]]))
	for i in arr.size():
		if arr[i]["id"] == team_id:
			return i
	return 0


func driver_standings() -> Array:
	var out: Array = []
	for t in teams:
		for d in t["drivers"]:
			out.append({"id": d["id"], "code": d["code"], "name": d["name"], "team": t["name"], "color": t["color"],
				"points": float(driver_points.get(d["id"], 0.0)), "wins": int(wins.get(d["id"], 0)), "team_id": t["id"]})
	out.sort_custom(func(a, b):
		if a["points"] != b["points"]:
			return a["points"] > b["points"]
		return a["wins"] > b["wins"])
	return out


func team_standings() -> Array:
	var out: Array = []
	for t in teams:
		out.append({"id": t["id"], "name": t["name"], "color": t["color"], "points": float(team_points.get(t["id"], 0.0))})
	out.sort_custom(func(a, b): return a["points"] > b["points"])
	return out


# ------------------------------------------------------------------ Saisonwechsel

## Marktphase beginnen (nach dem letzten Rennen).
func begin_market() -> void:
	Career.apply_season_eval()
	if not market_open:
		Market.open_market()


## Marktphase beenden und die nächste Saison starten.
func finish_market_and_advance() -> void:
	_log_season()                  # Endstand sichern, bevor das Teamfeld umgebaut wird
	Market.close_market()
	_advance_year()


## Teamfeld des nächsten Jahres bestimmen und ankündigen (Aufruf beim Öffnen der Marktphase, siehe field.gd).
func plan_field() -> void:
	Field.plan_changes()


## Angekündigte Teamfeld-Änderungen umsetzen (Aufruf beim Marktschluss, vor der Besetzung der Cockpits).
func apply_field_plan() -> void:
	Field.apply_plan()


## Team verlässt nach dieser Saison das Feld (Fahrer sind schon vertragslos, keine neuen Cockpits für dieses Team).
func is_leaving(tid: String) -> bool:
	return Field.is_leaving(tid)


## Saisonergebnis einmal ins Saisonbuch eintragen.
func _log_season() -> void:
	if not season_log.is_empty() and int(season_log[0]["year"]) == year:
		return
	var ds := driver_standings()
	var ts := team_standings()
	season_log.push_front({"year": year, "champion": ds[0]["name"] if ds.size() > 0 else "", "champion_team": ts[0]["name"] if ts.size() > 0 else "",
		"player_rank": final_rank(team_id), "player_points": float(team_points.get(team_id, 0.0)), "goal": last_season_eval})


func _advance_year() -> void:
	_log_season()
	year += 1
	# Kräfteverhältnis: Entwicklung wird zum Teil mitgenommen, neues Reglement mischt neu
	var reg: bool = year in REG_YEARS
	var total := {}
	var mean := 0.0
	var old_teams: Array = teams.filter(func(t): return not bool(team_meta.get(t["id"], {}).get("fresh", false)))   # Neueinsteiger zählen nicht mit
	for t in old_teams:
		total[t["id"]] = float(t["pace"]) + float(dev_pace.get(t["id"], 0.0))
		mean += total[t["id"]]
	mean /= maxf(1.0, float(old_teams.size()))
	for t in old_teams:
		var keep := 0.35 if reg else 0.78
		var noise := 0.006 if reg else 0.0022
		t["pace"] = mean + (float(total[t["id"]]) - mean) * keep + rng.randfn(0.0, noise)
		dev_pace[t["id"]] = 0.0
	Field.settle_newcomers()
	teams.sort_custom(func(a, b): return float(a["pace"]) > float(b["pace"]))
	Field.season_start_news()
	if reg:
		Market.news("info", "Neues Reglement %d: Das Kräfteverhältnis wird neu gemischt." % year)
	# Neues Auto: Aero/Antrieb/Chassis beginnen wieder bei Stufe 0
	for k in ["aero", "engine", "chassis"]:
		upgrades[k] = 0
	# Fahrer altern, Form schwankt
	for k in drivers.keys():
		var d: Dictionary = drivers[k]
		if d["status"] in ["retired", "future"]:
			continue
		var age_new := Market.age_of(d, year)
		var age_old := age_new - 1
		var s: float = d["skill"]
		s += Market.age_curve(age_new) - Market.age_curve(age_old)
		s += 0.30 * (float(d["peak_s"]) + Market.age_curve(age_new) - s) + rng.randfn(0.0, 0.00025)
		d["skill"] = s
		var q: float = d["qskill"]
		d["qskill"] = q + 0.30 * (float(d["peak_q"]) - q) + rng.randfn(0.0, 0.0001)
		d["morale"] = 0.5 * float(d["morale"]) + 0.5 * 0.62
	for t in teams:
		team_meta[t["id"]]["pace_rank"] = team_rank(t["id"])
	_begin_season()
	save()


# ------------------------------------------------------------------ Speichern

var save_ok := true            # false, wenn Speichern nicht möglich ist (z. B. privater Browser-Modus)
var last_saved_at := 0         # Unix-Zeit des letzten Speicherns


## Kurzbeschreibung des Spielstands für Menüs: {"year", "round", "team", "saved_at"} oder leer.
static func save_info() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY or not d.has("drivers"):
		return {}
	return {"year": int(d.get("year", 0)), "round": int(d.get("round_index", 0)), "team": str(d.get("team_id", "")), "saved_at": int(d.get("saved_at", 0))}


## Spielstand als Text (Base64) für die Zwischenablage - Sicherung gegen gelöschte Browserdaten.
func export_text() -> String:
	if not FileAccess.file_exists(SAVE_PATH):
		save()
	return Marshalls.utf8_to_base64(FileAccess.get_file_as_string(SAVE_PATH))


## Spielstand aus Sicherungstext wiederherstellen. Rückgabe: true bei Erfolg.
func import_text(txt: String) -> bool:
	var raw := Marshalls.base64_to_utf8(txt.strip_edges())
	var d = JSON.parse_string(raw)
	if typeof(d) != TYPE_DICTIONARY or not d.has("drivers") or not d.has("team_id"):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(raw)
	f.close()
	return load_game()


func save() -> void:
	if _ghost:
		return
	var pace := {}
	var team_list: Array = []
	for t in teams:
		pace[t["id"]] = t["pace"]
		team_list.append({"id": t["id"], "name": t["name"], "pace": t["pace"], "mech_rate": t["mech_rate"]})
	var data := {
		"version": 3, "team_list": team_list, "custom_teams": DB.custom_teams_json(), "field_plan": field_plan, "field_log": field_log,
		"field_dynamic": field_dynamic, "field_last_entry": field_last_entry, "year": year, "career_start": career_start, "team_id": team_id, "round_index": round_index, "driver_points": driver_points,
		"team_points": team_points, "wins": wins, "budget": budget, "upgrades": upgrades, "dev_pace": dev_pace,
		"history": history, "team_pace": pace, "drivers": drivers, "news": news, "market_log": market_log, "market_open": market_open,
		"season_log": season_log, "team_meta": team_meta, "solo_code": solo_code, "board": board, "sponsor_id": sponsor_id, "season_goal_rank": season_goal_rank, "season_eval_done": season_eval_done,
		"last_season_eval": last_season_eval, "pending_event": pending_event, "event_seen": event_seen, "event_last": event_last, "event_mods": event_mods,
		"career_log": career_log, "career_race_no": career_race_no, "goal_log": goal_log, "finance_log": finance_log, "dev_spent": dev_spent, "cap_spent_fees": cap_spent_fees, "engines": engines, "crew_form": crew_form,
		"saved_at": int(Time.get_unix_time_from_system()),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()
		save_ok = FileAccess.file_exists(SAVE_PATH)
		last_saved_at = int(data["saved_at"])
	else:
		save_ok = false


func load_game() -> bool:
	if not has_save():
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY or not d.has("drivers"):
		return false
	forecast_year = 0            # eine vorbereitete Prognose gilt nicht mehr (Teams und Fahrer werden gleich überschrieben)
	year = int(d["year"])
	career_start = int(d.get("career_start", year))
	team_id = str(d["team_id"])
	# Teamliste: neuere Spielstände speichern sie samt Neueinsteigern, Fusionen und Umbenennungen; ältere kennen nur das Startfeld
	DB.load_custom_teams(d.get("custom_teams", {}))
	if d.has("team_list"):
		teams = DB.restore_teams(d["team_list"], career_start)
	else:
		teams = DB.build_teams(career_start)
		var pace: Dictionary = d.get("team_pace", {})
		for t in teams:
			if pace.has(t["id"]):
				t["pace"] = float(pace[t["id"]])
	field_plan = d.get("field_plan", {})
	field_log = d.get("field_log", [])
	field_dynamic = bool(d.get("field_dynamic", true))
	field_last_entry = int(d.get("field_last_entry", -99))
	Field.normalize_loaded()
	teams.sort_custom(func(a, b): return float(a["pace"]) > float(b["pace"]))
	drivers = d["drivers"]
	news = d.get("news", [])
	market_log = d.get("market_log", [])
	season_log = d.get("season_log", [])
	team_meta = d.get("team_meta", {})
	dev_pace = d["dev_pace"]
	upgrades = d["upgrades"]
	_begin_season(false)
	round_index = int(d["round_index"])
	driver_points = d["driver_points"]
	team_points = d["team_points"]
	wins = d["wins"]
	budget = float(d["budget"])
	history = d.get("history", [])
	dev_spent = float(d.get("dev_spent", 0.0))
	cap_spent_fees = float(d.get("cap_spent_fees", 0.0))
	engines = d.get("engines", {})
	crew_form = float(d.get("crew_form", 0.0))
	solo_code = str(d.get("solo_code", ""))
	board = float(d.get("board", 60.0))
	sponsor_id = str(d.get("sponsor_id", ""))
	season_goal_rank = int(d.get("season_goal_rank", Career.pace_rank()))
	season_eval_done = bool(d.get("season_eval_done", false))
	last_season_eval = str(d.get("last_season_eval", ""))
	pending_event = d.get("pending_event", {})
	event_seen = bool(d.get("event_seen", false))
	event_last = d.get("event_last", {})
	event_mods = d.get("event_mods", [])
	career_log = d.get("career_log", [])
	career_race_no = int(d.get("career_race_no", 0))
	goal_log = d.get("goal_log", [])
	finance_log = d.get("finance_log", [])
	sync_teams()
	market_open = bool(d.get("market_open", false))
	active = true
	return true

extends Node
## Spielstand (Autoload "Game"): Karriere über mehrere Saisons, Team, Kalender, Meisterschaft, Budget, Entwicklung,
## Fahrermarkt (Fahrer, Verträge, News) und Kostenobergrenze. Speichern/Laden.

const Market = preload("res://scripts/market.gd")

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
var active := false
var weekend_sim = null
var weekend_round := -1

# Fahrermarkt
var drivers := {}            # Fahrer-ID -> Fahrerdaten (siehe market.gd)
var news: Array = []         # {"year", "round", "kind", "text"}
var market_log: Array = []   # Meldungen der laufenden Marktphase
var market_open := false
var season_log: Array = []   # je Saison: Weltmeister und Platzierung des Spielers
var team_meta := {}          # Team-ID -> {prestige, last_rank, score, pace_rank}
var cap := 160.0             # Kostenobergrenze pro Saison (Mio. $): Gehälter + Entwicklung + Provisionen
var dev_spent := 0.0
var cap_spent_fees := 0.0
var engines := {}            # Fahrer-ID -> {"used": Anzahl Motoren dieser Saison, "wear": Verschleiß 0..1+}


func _ready() -> void:
	rng.randomize()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func new_season(p_year: int, p_team: String) -> void:
	year = p_year
	career_start = p_year
	team_id = p_team
	teams = DB.build_teams(year)
	team_meta = {}
	season_log = []
	driver_points = {}
	team_points = {}
	wins = {}
	dev_pace = {}
	upgrades = {}
	for k in UPGRADES.keys():
		upgrades[k] = 0
	for t in teams:
		dev_pace[t["id"]] = 0.0
	Market.init_career(year)
	_begin_season()
	# Startbudget nach Teamstärke
	var rank := team_rank(team_id)
	budget = 90.0 - 6.0 * float(rank)
	active = true


## Setzt Kalender, Tabellen und Zähler für die laufende Saison zurück (Fahrer müssen bereits synchronisiert sein).
func _begin_season() -> void:
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
		if t["id"] == team_id:
			var lv: Dictionary = upgrades
			c["mech_mult"] = pow(0.88, float(lv["reliab"]))
			c["pit_skill"] = -0.12 * float(lv["pit"])
			for d in c["drivers"]:
				d["skill"] = float(d["skill"]) + 0.0006 * float(lv["coach"])
				d["qskill"] = float(d["qskill"]) + 0.0004 * float(lv["coach"])
		# Stimmung wirkt leicht auf die Fahrerleistung
		for d in c["drivers"]:
			d["skill"] = float(d["skill"]) + (float(d.get("morale", 0.62)) - 0.62) * 0.0005
		c["engine_allowance"] = engine_allowance()
		c["engine_life"] = engine_life_races()
		out.append(c)
	return out


func race_laps(race: Dictionary, track) -> int:
	var l: int = int(race.get("laps", 0))
	if l <= 0:
		l = int(ceil(305000.0 / track.length))
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
	income += team_gain * 0.35
	# Gehälter laufen pro Rennen, Bezahlfahrer bringen Sponsorgelder
	var n_races: float = maxf(1.0, float(calendar.size()))
	var salaries := payroll_current() / n_races
	var sponsors := 0.0
	for d in Market.current_drivers(team_id):
		sponsors += float(d["dowry"]) / n_races
	income += sponsors
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
	round_index += 1
	Market.update_morale(rows)
	sync_teams()
	if round_index % 4 == 0:
		Market.season_rumors()
	last_result = {"rows": rows, "race": calendar[round_index - 1], "income": income, "salaries": salaries,
		"fastest": fl_car.code if fl_car != null else "", "fastest_time": sim.fastest_lap}
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
	if not market_open:
		Market.open_market()


## Marktphase beenden und die nächste Saison starten.
func finish_market_and_advance() -> void:
	Market.close_market()
	_advance_year()


func _advance_year() -> void:
	var ds := driver_standings()
	var ts := team_standings()
	season_log.push_front({"year": year, "champion": ds[0]["name"] if ds.size() > 0 else "", "champion_team": ts[0]["name"] if ts.size() > 0 else "",
		"player_rank": final_rank(team_id), "player_points": float(team_points.get(team_id, 0.0))})
	year += 1
	# Kräfteverhältnis: Entwicklung wird zum Teil mitgenommen, neues Reglement mischt neu
	var reg: bool = year in REG_YEARS
	var total := {}
	var mean := 0.0
	for t in teams:
		total[t["id"]] = float(t["pace"]) + float(dev_pace.get(t["id"], 0.0))
		mean += total[t["id"]]
	mean /= maxf(1.0, float(teams.size()))
	for t in teams:
		var keep := 0.35 if reg else 0.78
		var noise := 0.006 if reg else 0.0022
		t["pace"] = mean + (float(total[t["id"]]) - mean) * keep + rng.randfn(0.0, noise)
		dev_pace[t["id"]] = 0.0
	teams.sort_custom(func(a, b): return float(a["pace"]) > float(b["pace"]))
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

func save() -> void:
	var pace := {}
	for t in teams:
		pace[t["id"]] = t["pace"]
	var data := {
		"version": 2, "year": year, "career_start": career_start, "team_id": team_id, "round_index": round_index, "driver_points": driver_points,
		"team_points": team_points, "wins": wins, "budget": budget, "upgrades": upgrades, "dev_pace": dev_pace,
		"history": history, "team_pace": pace, "drivers": drivers, "news": news, "market_log": market_log, "market_open": market_open,
		"season_log": season_log, "team_meta": team_meta, "dev_spent": dev_spent, "cap_spent_fees": cap_spent_fees, "engines": engines,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))


func load_game() -> bool:
	if not has_save():
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY or not d.has("drivers"):
		return false
	year = int(d["year"])
	career_start = int(d.get("career_start", year))
	team_id = str(d["team_id"])
	teams = DB.build_teams(career_start)
	var pace: Dictionary = d.get("team_pace", {})
	for t in teams:
		if pace.has(t["id"]):
			t["pace"] = float(pace[t["id"]])
	teams.sort_custom(func(a, b): return float(a["pace"]) > float(b["pace"]))
	drivers = d["drivers"]
	news = d.get("news", [])
	market_log = d.get("market_log", [])
	season_log = d.get("season_log", [])
	team_meta = d.get("team_meta", {})
	dev_pace = d["dev_pace"]
	upgrades = d["upgrades"]
	_begin_season()
	round_index = int(d["round_index"])
	driver_points = d["driver_points"]
	team_points = d["team_points"]
	wins = d["wins"]
	budget = float(d["budget"])
	history = d.get("history", [])
	dev_spent = float(d.get("dev_spent", 0.0))
	cap_spent_fees = float(d.get("cap_spent_fees", 0.0))
	engines = d.get("engines", {})
	sync_teams()
	market_open = bool(d.get("market_open", false))
	active = true
	return true

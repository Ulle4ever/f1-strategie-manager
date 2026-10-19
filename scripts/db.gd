extends Node
## Datenbank (Autoload "DB"): Saisons 2000-2026 (Jolpica/Ergast) und Strecken (OpenStreetMap).
## Leitet aus den Ergebnissen Teamstärke, Fahrerstärke und Ausfallraten je Saison ab.

const TrackModel = preload("res://scripts/track_model.gd")
const MIN_YEAR := 2000
const MAX_YEAR := 2026

const TEAM_COLORS := {
	"ferrari": Color("e10600"), "mclaren": Color("ff8000"), "williams": Color("1e5bc6"), "bar": Color("d8d8d8"),
	"benetton": Color("38b6e8"), "jordan": Color("f2d000"), "arrows": Color("ff9a1f"), "sauber": Color("2b9f4a"),
	"jaguar": Color("1f7a4a"), "minardi": Color("2b2b2b"), "prost": Color("2a5fd0"), "renault": Color("ffd800"),
	"toyota": Color("d12030"), "red_bull": Color("1b3a8c"), "honda": Color("f5f5f5"), "bmw_sauber": Color("3a7bd5"),
	"toro_rosso": Color("2a4aa8"), "mf1": Color("d02020"), "super_aguri": Color("e8e8e8"), "spyker_mf1": Color("ff6a00"),
	"spyker": Color("ff6a00"), "force_india": Color("ff80c7"), "brawn": Color("c8f000"), "mercedes": Color("27f4d2"),
	"lotus_racing": Color("0a7a3c"), "hrt": Color("a89060"), "virgin": Color("d4202a"), "lotus_f1": Color("1a1a1a"),
	"marussia": Color("a01830"), "caterham": Color("0b7a3a"), "manor": Color("d03030"), "haas": Color("b6babd"),
	"racing_point": Color("f596c8"), "alfa": Color("a50f2d"), "alphatauri": Color("5e8faa"), "alpine": Color("ff87bc"),
	"aston_martin": Color("229971"), "rb": Color("6692ff"), "audi": Color("e03a3e"), "cadillac": Color("c8a84b"),
}

var _seasons := {}
var _tracks := {}
## Teams, die es nur in der laufenden Karriere gibt (Neueinsteiger, Fusionen, Umbenennungen, siehe field.gd):
## Team-ID -> {name, color, second, short, shape, pattern, hq, founded, titles, tag, profile}. Der Spielstand speichert sie mit.
var custom_teams := {}


func years() -> Array:
	var out: Array = []
	for y in range(MAX_YEAR, MIN_YEAR - 1, -1):
		out.append(y)
	return out


func season(year: int) -> Dictionary:
	if _seasons.has(year):
		return _seasons[year]
	var path := "res://data/seasons/%d.json" % year
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(d) != TYPE_DICTIONARY:
		push_error("Saison %d nicht lesbar" % year)
		d = {"year": year, "calendar": [], "drivers": [], "teams": []}
	_seasons[year] = d
	return d


func track(circuit_id: String):
	if _tracks.has(circuit_id):
		return _tracks[circuit_id]
	var t = TrackModel.load_track(circuit_id)
	_tracks[circuit_id] = t
	return t


func team_color(id: String) -> Color:
	if custom_teams.has(id):
		return custom_teams[id]["color"]
	if TEAM_COLORS.has(id):
		return TEAM_COLORS[id]
	var h := id.hash()
	return Color.from_hsv(float(h % 360) / 360.0, 0.6, 0.9)


## Auto-Charakter eines Teams (stabil je Team und Zeitraum): df = Abtrieb (+) / wenig Luftwiderstand (-),
## power = Motorleistung, tyre = Reifenschonung, wet = Regenstärke. Werte -1 .. +1.
const PROFILES := {
	"red_bull": {"df": 0.7, "power": -0.1, "tyre": 0.1, "wet": 0.3}, "ferrari": {"df": -0.1, "power": 0.5, "tyre": -0.1, "wet": 0.0},
	"mercedes": {"df": 0.0, "power": 0.7, "tyre": -0.2, "wet": 0.2}, "mclaren": {"df": 0.3, "power": 0.0, "tyre": 0.4, "wet": 0.1},
	"williams": {"df": -0.5, "power": 0.2, "tyre": 0.0, "wet": -0.1}, "force_india": {"df": -0.3, "power": 0.3, "tyre": 0.2, "wet": 0.1},
	"racing_point": {"df": -0.3, "power": 0.3, "tyre": 0.2, "wet": 0.1}, "aston_martin": {"df": -0.2, "power": 0.2, "tyre": 0.1, "wet": 0.0},
	"haas": {"df": -0.4, "power": 0.3, "tyre": -0.4, "wet": -0.2}, "renault": {"df": 0.3, "power": -0.3, "tyre": 0.0, "wet": 0.0},
	"alpine": {"df": 0.3, "power": -0.3, "tyre": 0.0, "wet": 0.0}, "sauber": {"df": 0.1, "power": 0.0, "tyre": 0.3, "wet": 0.0},
	"toro_rosso": {"df": 0.3, "power": -0.2, "tyre": 0.0, "wet": 0.1}, "alphatauri": {"df": 0.3, "power": -0.1, "tyre": 0.0, "wet": 0.0},
	"rb": {"df": 0.3, "power": -0.1, "tyre": 0.1, "wet": 0.0}, "lotus_f1": {"df": 0.2, "power": 0.0, "tyre": 0.7, "wet": 0.1},
	"toyota": {"df": -0.2, "power": 0.3, "tyre": 0.0, "wet": 0.0}, "bmw_sauber": {"df": 0.0, "power": 0.5, "tyre": 0.0, "wet": 0.0},
}


func car_profile(team_id: String, year: int) -> Dictionary:
	var base: Dictionary = PROFILES.get(team_id, {})
	if base.is_empty() and custom_teams.has(team_id):
		base = custom_teams[team_id].get("profile", {})
	var out := {}
	for k in ["df", "power", "tyre", "wet"]:
		var h := ("%s|%s|%d" % [team_id, k, year / 3]).hash()
		var noise := (float(h % 2001) / 1000.0 - 1.0) * (0.35 if not base.is_empty() else 0.7)
		out[k] = clampf(float(base.get(k, 0.0)) + noise, -1.0, 1.0)
	return out


func rules(year: int) -> Dictionary:
	var pts: Array = [25, 18, 15, 12, 10, 8, 6, 4, 2, 1]
	if year <= 2002:
		pts = [10, 6, 4, 3, 2, 1]
	elif year <= 2009:
		pts = [10, 8, 6, 5, 4, 3, 2, 1]
	return {
		"refuel": year <= 2009,
		"points": pts,
		"fastest_lap_point": year >= 2019 and year <= 2024,
		"min_compounds": 2 if year >= 2007 else 1,
		"drs": year >= 2011,
		"stationary": 2.4 if year >= 2010 else 7.0,
		"pit_loss_scale": 1.0 if year >= 2010 else 1.12,
	}


## Teams einer Saison mit abgeleiteten Stärken. Rückgabe: Array von Dictionaries, nach Stärke sortiert.
func build_teams(year: int) -> Array:
	var s := season(year)
	var teams: Array = s["teams"]
	var drivers: Array = s["drivers"]
	var max_p := 1.0
	for t in teams:
		max_p = maxf(max_p, float(t["points"]))
	var out: Array = []
	var zero_rank := 0
	for t in teams:
		var has_driver := false
		for d in drivers:
			if d["team"] == t["id"]:
				has_driver = true
				break
		if not has_driver:
			continue
		var pf := clampf(float(t["points"]) / max_p, 0.0, 1.0)
		var pace := 1.0 - 0.036 * (1.0 - sqrt(pf))
		if float(t["points"]) <= 0.0:
			pace -= 0.002 * zero_rank
			zero_rank += 1
		var entries := float(t["entries"])
		var mech_rate := (float(t["mech"]) + 0.6) / (entries + 14.0)
		var team := {
			"id": t["id"], "name": t["name"], "color": team_color(t["id"]), "pace": pace,
			"mech_rate": mech_rate, "points": t["points"], "drivers": [],
		}
		# Fahrer: die beiden mit den meisten Rennen für dieses Team
		var mine: Array = []
		for d in drivers:
			if d["team"] == t["id"]:
				mine.append(d)
		mine.sort_custom(func(a, b): return int(a["races"]) > int(b["races"]))
		var chosen: Array = mine.slice(0, 2)
		var team_pts := 0.0
		var grid_sum := 0.0
		for d in chosen:
			team_pts += float(d["points"])
			grid_sum += float(d["avgGrid"])
		var grid_avg := grid_sum / maxf(1.0, chosen.size())
		for d in chosen:
			var races := float(d["races"])
			var share := 0.5
			if team_pts > 0.0 and chosen.size() > 1:
				share = float(d["points"]) / team_pts
			var conf := minf(1.0, races / 10.0)
			var skill := clampf(share - 0.5, -0.5, 0.5) * 0.016 * conf
			var qskill := clampf(grid_avg - float(d["avgGrid"]), -4.0, 4.0) * 0.0006 * conf
			var crash_rate := (maxf(0.0, float(d["dnf"]) - float(d["mech"])) + 0.4) / (races + 8.0)
			team["drivers"].append({
				"id": d["id"], "code": d["code"], "name": "%s %s" % [d["given"], d["family"]],
				"family": d["family"], "number": d["number"], "team": t["id"],
				"skill": skill, "qskill": qskill, "crash_rate": crash_rate,
			})
		out.append(team)
	return out


# ------------------------------------------------------------------ Karriere-Teams (Teamfeld verändert sich)

## Team in die Karriere-Liste eintragen. spec: {id, name, color, second (Hex ohne #), short, shape, pattern, hq, founded, titles, tag, profile}.
func register_team(spec: Dictionary) -> void:
	custom_teams[str(spec["id"])] = {
		"name": str(spec["name"]), "color": Color(str(spec["color"])), "second": Color(str(spec["second"])),
		"short": str(spec["short"]), "shape": str(spec["shape"]), "pattern": str(spec["pattern"]), "hq": str(spec["hq"]),
		"founded": int(spec.get("founded", 0)), "titles": int(spec.get("titles", 0)), "tag": str(spec["tag"]),
		"profile": (spec.get("profile", {}) as Dictionary).duplicate(),
	}


## Karriere-Teams als JSON-taugliche Daten (Farben als Hex-Text) für den Spielstand.
func custom_teams_json() -> Dictionary:
	var out := {}
	for id in custom_teams.keys():
		var i: Dictionary = custom_teams[id]
		out[id] = {"id": id, "name": i["name"], "color": (i["color"] as Color).to_html(false), "second": (i["second"] as Color).to_html(false),
			"short": i["short"], "shape": i["shape"], "pattern": i["pattern"], "hq": i["hq"], "founded": i["founded"], "titles": i["titles"],
			"tag": i["tag"], "profile": i["profile"]}
	return out


func load_custom_teams(d: Dictionary) -> void:
	custom_teams = {}
	for id in d.keys():
		register_team(d[id])


## Neues Team im Format von build_teams (keine Fahrer, die kommen über den Fahrermarkt).
func new_team(id: String, p_name: String, pace: float, mech_rate: float) -> Dictionary:
	return {"id": id, "name": p_name, "color": team_color(id), "pace": pace, "mech_rate": mech_rate, "points": 0.0, "drivers": []}


## Teamliste aus dem Spielstand wiederherstellen: Teams der Startsaison mit gespeicherter Stärke, dazu die Karriere-Teams.
## saved: [{id, name, pace, mech_rate}] in gespeicherter Reihenfolge. base_year = Startsaison (höchstens MAX_YEAR).
func restore_teams(saved: Array, base_year: int) -> Array:
	var base := {}
	for t in build_teams(mini(base_year, MAX_YEAR)):
		base[t["id"]] = t
	var out: Array = []
	for e in saved:
		var id := str(e["id"])
		var t: Dictionary = base[id] if base.has(id) else new_team(id, str(e["name"]), 1.0, 0.0135)
		t["name"] = str(e["name"])
		t["color"] = team_color(id)
		t["pace"] = float(e["pace"])
		t["mech_rate"] = float(e.get("mech_rate", t.get("mech_rate", 0.0135)))
		out.append(t)
	return out

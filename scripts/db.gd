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
	if TEAM_COLORS.has(id):
		return TEAM_COLORS[id]
	var h := id.hash()
	return Color.from_hsv(float(h % 360) / 360.0, 0.6, 0.9)


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
			var skill := clampf(share - 0.5, -0.5, 0.5) * 0.012 * conf
			var qskill := clampf(grid_avg - float(d["avgGrid"]), -4.0, 4.0) * 0.0006 * conf
			var crash_rate := (maxf(0.0, float(d["dnf"]) - float(d["mech"])) + 0.4) / (races + 8.0)
			team["drivers"].append({
				"id": d["id"], "code": d["code"], "name": "%s %s" % [d["given"], d["family"]],
				"family": d["family"], "number": d["number"], "team": t["id"],
				"skill": skill, "qskill": qskill, "crash_rate": crash_rate,
			})
		out.append(team)
	return out

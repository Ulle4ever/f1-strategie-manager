extends RefCounted
## Personal des eigenen Teams: Technischer Direktor (Entwicklung), Chefstratege (Wetterprognose, Reifenwissen),
## zwei Renningenieure (je ein Fahrer: Tempo und Stimmung) und Crew-Chef (Boxenstopps). Jede Person hat eine Bewertung
## (40-95), ein Gehalt pro Saison (zählt nicht zur Kostenobergrenze, wird aber pro Rennen vom Budget bezahlt) und einen
## Vertrag. Neues Personal kommt vom Personalmarkt (Kandidaten je Rolle, wechseln jede Saison).
## Daten: Game.staff = {Rollen-ID: Person}, Game.staff_pool = [Person], Person = {id, name, role, rating, age, salary, end}

const Market = preload("res://scripts/market.gd")
const ROLES := ["td", "strat", "eng1", "eng2", "crew"]
const ROLE_NAMES := {"td": "Technischer Direktor", "strat": "Chefstratege", "eng1": "Renningenieur Auto 1", "eng2": "Renningenieur Auto 2", "crew": "Crew-Chef"}
const ROLE_KIND := {"td": "td", "strat": "strat", "eng1": "eng", "eng2": "eng", "crew": "crew"}
const KIND_TEXT := {
	"td": "Entwicklung: schnellere Projekte, mehr Zuwachs, weniger Fehlschläge; ab 80 ein dritter Projektplatz.",
	"strat": "Wetterprognose genauer; ab 80 ist die Reifenhaltbarkeit auch ohne Reifentest bekannt.",
	"eng": "Tempo seines Fahrers (bis etwa +0,1 %) und stabilere Stimmung.",
	"crew": "Schnellere Boxenstopps (bis etwa 0,3 s) und weniger verpatzte Stopps.",
}
const FIRST := ["Marco", "James", "Laurent", "Hiro", "Elena", "Tobias", "Andrea", "Simon", "Pierre", "Lukas", "Carlos", "Mia", "Oliver", "Sara", "Jonas", "Nico",
	"Felipe", "Anna", "David", "Kenji", "Luca", "Hannah", "Rafael", "Julia", "Mark", "Claire", "Stefan", "Ines", "Ben", "Yuki"]
const LAST := ["Bianchi", "Whitmore", "Durand", "Tanaka", "Koval", "Brenner", "Rossetti", "Hale", "Lambert", "Weiss", "Navarro", "Lindqvist", "Fairbairn",
	"Moreau", "Kessler", "Okada", "Ferreira", "Novak", "Calloway", "Marchetti", "Holt", "Sauvage", "Grieve", "Albers", "Castellano", "Pryce", "Engel", "Ruiz"]


static func kind(role: String) -> String:
	return str(ROLE_KIND.get(role, role))


## Gehalt pro Saison (Mio. $) zur Bewertung: Spitzenleute sind teuer.
static func salary_for(rating: float) -> float:
	var x := clampf((rating - 40.0) / 55.0, 0.0, 1.0)
	return snappedf(0.6 + 11.0 * pow(x, 2.2), 0.1)


static func make_person(role: String, rating: float) -> Dictionary:
	var r := clampi(int(round(rating)), 40, 95)
	var nm := "%s %s" % [FIRST[Game.rng.randi() % FIRST.size()], LAST[Game.rng.randi() % LAST.size()]]
	var sal := salary_for(r) * Game.rng.randf_range(0.9, 1.12)
	return {"id": "%s_%d" % [role, Game.rng.randi()], "name": nm, "role": role, "rating": r, "age": Game.rng.randi_range(31, 61),
		"salary": snappedf(sal, 0.1), "end": Game.year + Game.rng.randi_range(1, 3)}


## Startbesetzung nach Teamstärke (Topteams haben besseres Personal) und erster Personalmarkt.
static func init_team() -> void:
	var rank := Game.team_rank(Game.team_id)
	var n := maxf(1.0, float(Game.teams.size() - 1))
	var base := 82.0 - 26.0 * float(rank) / n
	Game.staff = {}
	for role in ROLES:
		Game.staff[role] = make_person(role, base + Game.rng.randfn(0.0, 5.0))
	refresh_pool()


## Personalmarkt: je Rolle drei bis vier Kandidaten unterschiedlicher Klasse.
static func refresh_pool() -> void:
	Game.staff_pool = []
	for k in ["td", "strat", "eng", "crew"]:
		for i in 4:
			var r := Game.rng.randf_range(48.0, 93.0)
			var role: String = "eng1" if k == "eng" else str(k)
			var p := make_person(role, r)
			p["role"] = k        # Ingenieure passen auf beide Autos
			p["end"] = Game.year + Game.rng.randi_range(2, 3)
			Game.staff_pool.append(p)


static func rating(role: String) -> float:
	return float(Game.staff.get(role, {}).get("rating", 60.0))


## Faktor 0..1 aus der Bewertung (40 -> 0, 95 -> 1).
static func level(role: String) -> float:
	return clampf((rating(role) - 40.0) / 55.0, 0.0, 1.0)


static func payroll() -> float:
	var s := 0.0
	for role in Game.staff.keys():
		s += float(Game.staff[role].get("salary", 0.0))
	return s


## Abfindung bei Entlassung: die Hälfte des Restvertrags.
static func severance(p: Dictionary) -> float:
	var years := maxf(0.0, float(int(p.get("end", Game.year)) - Game.year) + 0.5)
	return snappedf(float(p["salary"]) * years * 0.5, 0.1)


## Kandidat einstellen (ersetzt die bisherige Person; Abfindung wird fällig). Rückgabe: Meldung.
static func hire(cand: Dictionary, role: String) -> String:
	var old: Dictionary = Game.staff.get(role, {})
	var fee := severance(old) if not old.is_empty() else 0.0
	var signing := snappedf(float(cand["salary"]) * 0.25, 0.1)
	if Game.budget < fee + signing:
		return "Nicht genug Budget (Abfindung %.1f + Handgeld %.1f Mio. $)." % [fee, signing]
	Game.budget -= fee + signing
	var p := cand.duplicate()
	p["role"] = role
	Game.staff[role] = p
	Game.staff_pool.erase(cand)
	Market.news("info", "%s ist neuer %s (Bewertung %d)." % [p["name"], ROLE_NAMES[role], int(p["rating"])])
	return "%s eingestellt. Kosten: %.1f Mio. $ (Abfindung %.1f, Handgeld %.1f)." % [p["name"], fee + signing, fee, signing]


## Vertrag um zwei Jahre verlängern (Gehalt +10 %).
static func extend(role: String) -> String:
	var p: Dictionary = Game.staff.get(role, {})
	if p.is_empty():
		return ""
	p["end"] = maxi(int(p["end"]), Game.year) + 2
	p["salary"] = snappedf(float(p["salary"]) * 1.1, 0.1)
	return "Vertrag mit %s bis %d verlängert (%.1f Mio. $ pro Saison)." % [p["name"], int(p["end"]), float(p["salary"])]


## Gehälter pro Rennen vom Budget abziehen.
static func pay_race() -> float:
	var n := maxf(1.0, float(Game.calendar.size()))
	var cost := payroll() / n
	Game.budget -= cost
	return cost


## Saisonwechsel: Personal entwickelt sich (jung besser, alt schwächer), auslaufende Verträge enden, neuer Personalmarkt.
static func new_season() -> void:
	for role in ROLES:
		var p: Dictionary = Game.staff.get(role, {})
		if p.is_empty():
			continue
		p["age"] = int(p["age"]) + 1
		var drift := 1.2 if int(p["age"]) < 45 else (-1.0 if int(p["age"]) > 56 else 0.2)
		p["rating"] = clampi(int(round(float(p["rating"]) + drift + Game.rng.randfn(0.0, 1.5))), 40, 95)
		if int(p["end"]) < Game.year:
			Market.news("info", "Der Vertrag von %s (%s) ist ausgelaufen. Ein Nachfolger aus der zweiten Reihe übernimmt." % [p["name"], ROLE_NAMES[role]])
			Game.staff[role] = make_person(role, float(p["rating"]) - 14.0 + Game.rng.randfn(0.0, 4.0))
	refresh_pool()


## Wirkung im Rennen für das Spielerteam (wird in Game.sim_teams eingetragen).
static func race_effects() -> Dictionary:
	return {
		"pit_skill": -0.30 * level("crew") + 0.12,                   # Sekunden pro Stopp (negativ = schneller)
		"slow_k": 1.25 - 0.6 * level("crew"),                       # Faktor für verpatzte Stopps
		"forecast_k": 1.4 - 1.0 * level("strat"),                   # Faktor für den Prognosefehler
		"tyre_known": rating("strat") >= 80.0,
		"eng": [(rating("eng1") - 60.0) * 0.00003, (rating("eng2") - 60.0) * 0.00003],
	}

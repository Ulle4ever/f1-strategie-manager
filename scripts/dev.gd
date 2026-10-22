extends RefCounted
## Teile-Entwicklung des eigenen Teams. Sechs Bereiche des Autos (Frontflügel, Heckflügel, Unterboden, Seitenkästen und
## Kühlung, Aufhängung, Antrieb) werden über Projekte verbessert: Größe (Feinschliff, Update-Paket, Großes Paket) bestimmt
## Kosten, Dauer in Rennen und den erwarteten Zuwachs; das Ziel ist das aktuelle Auto (kommt nach der Entwicklungszeit ans Auto)
## oder das Auto der nächsten Saison (mehr Zuwachs, wirkt erst ab nächstem Jahr, bei neuem Reglement besonders wertvoll).
## Der Technische Direktor macht Projekte schneller, ertragreicher und sicherer. Je weiter ein Bereich schon entwickelt ist,
## desto weniger bringt das nächste Teil. Jeder Bereich verschiebt auch das Fahrzeugprofil (Abtrieb, Motorleistung, Reifen).
## Daten: Game.dev_parts = {Bereich: {"cur": Punkte, "next": Punkte}} (Punkte = Pace in Prozent), Game.dev_projects = [Projekt],
## Game.dev_log = [Lieferung]

const Staff = preload("res://scripts/staff.gd")
const Market = preload("res://scripts/market.gd")

const AREAS := ["front", "rear", "floor", "sidepods", "susp", "pu"]
const AREA := {
	"front": {"name": "Frontflügel", "w": 0.75, "prof": {"df": 0.9, "tyre": 0.2}, "desc": "Abtrieb vorne, Einlenken"},
	"rear": {"name": "Heckflügel", "w": 0.65, "prof": {"df": 0.9, "power": -0.35}, "desc": "Abtrieb hinten oder Topspeed"},
	"floor": {"name": "Unterboden", "w": 1.0, "prof": {"df": 0.7}, "desc": "der größte Hebel für Abtrieb"},
	"sidepods": {"name": "Seitenkästen und Kühlung", "w": 0.6, "prof": {"power": 0.5}, "desc": "Kühlung, Luftwiderstand, Standfestigkeit"},
	"susp": {"name": "Aufhängung", "w": 0.6, "prof": {"tyre": 0.9, "wet": 0.3}, "desc": "Reifenschonung, Regen"},
	"pu": {"name": "Antrieb und Energie", "w": 0.8, "prof": {"power": 0.9}, "desc": "Motorleistung, Energierückgewinnung"},
}
const REAR_SPEED := {"df": -0.45, "power": 0.9}
const SIZES := {
	"s": {"name": "Feinschliff", "cost": 3.0, "races": 2, "lo": 0.03, "hi": 0.07},
	"m": {"name": "Update-Paket", "cost": 7.0, "races": 4, "lo": 0.06, "hi": 0.14},
	"l": {"name": "Großes Paket", "cost": 14.0, "races": 7, "lo": 0.12, "hi": 0.28},
}
const NEXT_GAIN := 1.5        # Projekte fürs nächste Auto bringen mehr (mehr Freiheit, Zeit bis zur Saison)


static func init() -> void:
	Game.dev_parts = {}
	for a in AREAS:
		Game.dev_parts[a] = {"cur": 0.0, "next": 0.0}
	Game.dev_projects = []
	Game.dev_log = []


static func part(a: String) -> Dictionary:
	if not Game.dev_parts.has(a):
		Game.dev_parts[a] = {"cur": 0.0, "next": 0.0}
	return Game.dev_parts[a]


## Gleichzeitig laufende Projekte (Kapazität des Konstruktionsbüros).
static func slots() -> int:
	return 3 if Staff.rating("td") >= 80.0 else 2


## Abnehmender Ertrag: je weiter der Bereich schon entwickelt ist, desto weniger bringt das nächste Teil.
static func efficiency(a: String, target: String) -> float:
	var lv := float(part(a)[target])
	return 1.0 / (1.0 + lv / 0.6)


static func reg_next() -> bool:
	return (Game.year + 1) in Game.REG_YEARS


## Kennzahlen eines möglichen Projekts (mit Technischem Direktor und abnehmendem Ertrag).
static func quote(a: String, size: String, target: String) -> Dictionary:
	var s: Dictionary = SIZES[size]
	var L := Staff.level("td")
	var f := float(AREA[a]["w"]) * (0.8 + 0.45 * L) * efficiency(a, target) * (NEXT_GAIN if target == "next" else 1.0)
	var races := maxi(1, int(round(float(s["races"]) * (1.25 - 0.45 * L))))
	var left := Game.calendar.size() - Game.round_index
	return {"cost": float(s["cost"]), "races": races, "lo": float(s["lo"]) * f, "hi": float(s["hi"]) * f,
		"fail": 0.16 - 0.12 * L, "late": target == "cur" and races > left}


static func can_start(cost: float) -> String:
	if Game.dev_projects.size() >= slots():
		return "Alle Projektplätze sind belegt."
	if Game.budget < cost:
		return "Nicht genug Budget."
	if Game.cap_left() < cost:
		return "Die Kostenobergrenze ist erreicht."
	return ""


## Projekt starten. spec: beim Heckflügel "df" (Abtrieb) oder "speed" (Topspeed). Rückgabe: Fehlertext oder "".
static func start(a: String, size: String, target: String, spec := "df") -> String:
	var q := quote(a, size, target)
	var err := can_start(float(q["cost"]))
	if err != "":
		return err
	Game.budget -= float(q["cost"])
	Game.dev_spent += float(q["cost"])
	Game.dev_projects.append({"area": a, "size": size, "target": target, "spec": spec, "cost": q["cost"], "races": int(q["races"]),
		"left": int(q["races"]), "lo": q["lo"], "hi": q["hi"], "fail": q["fail"], "year": Game.year})
	return ""


## Nach jedem Rennen: Projekte rücken vor, fertige Teile werden geliefert (Zuwachs zufällig im erwarteten Bereich, selten ein Fehlschlag).
static func tick_race() -> Array:
	var done: Array = []
	for p in Game.dev_projects.duplicate():
		p["left"] = int(p["left"]) - 1
		if int(p["left"]) > 0:
			continue
		Game.dev_projects.erase(p)
		var failed: bool = Game.rng.randf() < float(p["fail"])
		var gain := 0.0 if failed else Game.rng.randf_range(float(p["lo"]), float(p["hi"]))
		deliver(p, gain, failed)
		done.append(p)
	return done


static func deliver(p: Dictionary, gain: float, failed: bool) -> void:
	var a: String = p["area"]
	var target: String = p["target"]
	part(a)[target] = float(part(a)[target]) + gain
	if a == "rear":
		var k := "rear_speed" if str(p.get("spec", "df")) == "speed" else "rear_df"
		part(a)[k + "_" + target] = float(part(a).get(k + "_" + target, 0.0)) + gain
	if target == "cur":
		Game.dev_pace[Game.team_id] = float(Game.dev_pace.get(Game.team_id, 0.0)) + gain / 100.0
	var nm: String = AREA[a]["name"]
	var txt := ""
	if failed:
		txt = "%s (%s): Das Teil bringt auf der Strecke nichts, zurück ans Reißbrett." % [nm, SIZES[p["size"]]["name"]]
	elif target == "cur":
		txt = "%s: neues Teil am Auto, +%.2f %% Tempo (erwartet %.2f bis %.2f)." % [nm, gain, float(p["lo"]), float(p["hi"])]
	else:
		txt = "%s für das Auto %d fertig: +%.2f %% (wirkt ab nächster Saison)." % [nm, Game.year + 1, gain]
	Game.dev_log.push_front({"year": Game.year, "round": Game.round_index, "area": a, "size": p["size"], "target": target, "gain": gain,
		"lo": p["lo"], "hi": p["hi"], "failed": failed, "text": txt})
	if Game.dev_log.size() > 30:
		Game.dev_log.resize(30)
	Market.news("dev" if not failed else "info", txt)


## Sofortiger Zuwachs am aktuellen Auto (z. B. durch eine Meldung).
static func instant(a: String, gain: float) -> void:
	part(a)["cur"] = float(part(a)["cur"]) + gain
	Game.dev_pace[Game.team_id] = float(Game.dev_pace.get(Game.team_id, 0.0)) + gain / 100.0


## Verschiebung des Fahrzeugprofils durch die Entwicklung am aktuellen Auto (0,1 % Tempo im Bereich etwa 0,08 Profil).
static func profile_shift() -> Dictionary:
	var out := {"df": 0.0, "power": 0.0, "tyre": 0.0, "wet": 0.0}
	for a in AREAS:
		var pts := float(part(a)["cur"])
		if a == "rear":
			var sp := float(part(a).get("rear_speed_cur", 0.0))
			var dfp := pts - sp
			for k in AREA[a]["prof"].keys():
				out[k] += float(AREA[a]["prof"][k]) * dfp * 0.8
			for k in REAR_SPEED.keys():
				out[k] += float(REAR_SPEED[k]) * sp * 0.8
			continue
		for k in AREA[a]["prof"].keys():
			out[k] += float(AREA[a]["prof"][k]) * pts * 0.8
	return out


## Zuverlässigkeit: entwickelte Seitenkästen/Kühlung senken technische Defekte leicht.
static func mech_factor() -> float:
	return 1.0 / (1.0 + float(part("sidepods")["cur"]) * 0.6)


## Saisonwechsel (nach dem Mischen des Kräfteverhältnisses): das vorbereitete neue Auto übernimmt die Entwicklung fürs nächste Jahr.
## Laufende Projekte fürs alte Auto verfallen, Projekte fürs neue Auto laufen weiter.
static func season_rollover() -> void:
	var bank := 0.0
	for a in AREAS:
		var p := part(a)
		bank += float(p["next"])
		p["cur"] = float(p["next"])
		p["rear_speed_cur"] = float(p.get("rear_speed_next", 0.0))
		p["rear_df_cur"] = float(p.get("rear_df_next", 0.0))
		p["next"] = 0.0
		p["rear_speed_next"] = 0.0
		p["rear_df_next"] = 0.0
	Game.dev_pace[Game.team_id] = float(Game.dev_pace.get(Game.team_id, 0.0)) + bank / 100.0
	var keep: Array = []
	for pr in Game.dev_projects:
		if str(pr["target"]) == "next":
			pr["target"] = "cur"
			keep.append(pr)
	var lost := Game.dev_projects.size() - keep.size()
	Game.dev_projects = keep
	if bank > 0.001:
		Market.news("dev", "Das neue Auto %d startet mit +%.2f %% aus der Vorjahresentwicklung." % [Game.year, bank])
	if lost > 0:
		Market.news("info", "%d Entwicklungsprojekt(e) für das alte Auto wurden mit dem Saisonwechsel eingestellt." % lost)


static func cur_total() -> float:
	var s := 0.0
	for a in AREAS:
		s += float(part(a)["cur"])
	return s


static func next_total() -> float:
	var s := 0.0
	for a in AREAS:
		s += float(part(a)["next"])
	return s

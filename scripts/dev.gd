extends RefCounted
## Teile-Entwicklung des eigenen Teams. Sechs Bereiche des Autos (Frontflügel, Heckflügel, Unterboden, Seitenkästen und
## Kühlung, Aufhängung, Antrieb) werden über Projekte verbessert: Größe (Feinschliff, Update-Paket, Großes Paket) bestimmt
## Kosten, Dauer in Rennen und den erwarteten Zuwachs; das Ziel ist das aktuelle Auto (kommt nach der Entwicklungszeit ans Auto)
## oder das Auto der nächsten Saison (mehr Zuwachs, wirkt erst ab nächstem Jahr, bei neuem Reglement besonders wertvoll).
## Der Technische Direktor macht Projekte schneller, ertragreicher und sicherer. Je weiter ein Bereich schon entwickelt ist,
## desto weniger bringt das nächste Teil. Jedes Projekt hat einen Schwerpunkt (z. B. Frontflügel: Abtrieb, Balance oder wenig
## Luftwiderstand), der das Fahrzeugprofil verschiebt (Abtrieb, Topspeed, Reifen, Regen, Standfestigkeit) – mit Zielkonflikten wie
## in der echten F1. Mutige Konzepte streuen mehr und schlagen öfter fehl; ein Teil kann auch nur halb funktionieren
## (Windkanal und Strecke passen nicht zusammen) oder einen Durchbruch bringen.
## Daten: Game.dev_parts = {Bereich: {"cur": Punkte, "next": Punkte, "foc_cur": {Schwerpunkt: Punkte}, "foc_next": {...}}}
## (Punkte = Pace in Prozent), Game.dev_projects = [Projekt], Game.dev_log = [Lieferung]. KI-Teams entwickeln ebenfalls in
## zufällige Richtungen (Game.ai_dev_prof), damit sich die Autos über die Saison unterschiedlich entwickeln.

const Staff = preload("res://scripts/staff.gd")
const Market = preload("res://scripts/market.gd")

const AREAS := ["front", "rear", "floor", "sidepods", "susp", "pu"]
const AREA := {
	"front": {"name": "Frontflügel", "w": 0.75, "desc": "Abtrieb vorne, Balance, Anströmung des Unterbodens"},
	"rear": {"name": "Heckflügel", "w": 0.65, "desc": "Abtrieb hinten oder Topspeed"},
	"floor": {"name": "Unterboden", "w": 1.0, "desc": "der größte Hebel für Abtrieb"},
	"sidepods": {"name": "Seitenkästen und Kühlung", "w": 0.6, "desc": "Kühlung, Luftwiderstand, Standfestigkeit"},
	"susp": {"name": "Aufhängung", "w": 0.6, "desc": "Reifenschonung, mechanischer Grip, Regen"},
	"pu": {"name": "Antrieb und Energie", "w": 0.8, "desc": "Motorleistung, Haltbarkeit, Energierückgewinnung"},
}
## Schwerpunkte je Bereich: prof = Verschiebung des Fahrzeugprofils je Punkt (df Abtrieb, power Topspeed/Leistung, tyre Reifenschonung,
## wet Regen, rel Standfestigkeit), risk = zusätzliches Fehlschlagrisiko, spread = Streuung des Ertrags (> 1 mutiger).
## Die erste Option ist der klassische Weg (alte Spielstände ohne Schwerpunkt zählen dorthin).
const FOCUS := {
	"front": [
		{"id": "df", "name": "Mehr Abtrieb", "desc": "mehr Grip in schnellen Kurven, etwas mehr Luftwiderstand", "prof": {"df": 0.9, "power": -0.15}, "risk": 0.0, "spread": 1.0},
		{"id": "bal", "name": "Balance und Reifen", "desc": "stabile Vorderachse gegen Untersteuern, schont die Vorderreifen, hilft im Regen", "prof": {"df": 0.35, "tyre": 0.55, "wet": 0.3}, "risk": -0.03, "spread": 0.85},
		{"id": "drag", "name": "Wenig Luftwiderstand", "desc": "flacher Flügel für mehr Topspeed, weniger Abtrieb vorne", "prof": {"power": 0.6, "df": -0.2}, "risk": 0.0, "spread": 1.0},
	],
	"rear": [
		{"id": "df", "name": "Mehr Abtrieb", "desc": "Heck liegt satt in den Kurven, kostet auf den Geraden", "prof": {"df": 0.9, "power": -0.35}, "risk": 0.0, "spread": 1.0},
		{"id": "speed", "name": "Mehr Topspeed", "desc": "wenig Luftwiderstand und starker DRS-Effekt, weniger Abtrieb", "prof": {"df": -0.45, "power": 0.9}, "risk": 0.0, "spread": 1.0},
	],
	"floor": [
		{"id": "peak", "name": "Spitzenabtrieb", "desc": "maximaler Abtrieb, aber empfindlich bei Bodenwellen und Regen, frisst Reifen – mutig", "prof": {"df": 1.0, "tyre": -0.2, "wet": -0.25}, "risk": 0.06, "spread": 1.3},
		{"id": "window", "name": "Breites Arbeitsfenster", "desc": "konstanter Abtrieb über Fahrhöhe und Tank, gutmütig zu den Reifen und im Regen", "prof": {"df": 0.45, "tyre": 0.45, "wet": 0.35}, "risk": -0.03, "spread": 0.85},
	],
	"sidepods": [
		{"id": "cool", "name": "Kühlung und Standfestigkeit", "desc": "größere Kühler: weniger Defekte, auch bei Hitze", "prof": {"rel": 0.9, "power": 0.1}, "risk": -0.03, "spread": 0.85},
		{"id": "slim", "name": "Schlanke Bauweise", "desc": "weniger Luftwiderstand und bessere Anströmung des Hecks, aber die Kühlung wird knapp – mutig", "prof": {"power": 0.6, "df": 0.25, "rel": -0.35}, "risk": 0.05, "spread": 1.25},
	],
	"susp": [
		{"id": "tyre", "name": "Reifenschonung", "desc": "weiche Abstimmung, Reifen rutschen weniger und halten länger", "prof": {"tyre": 0.9, "wet": 0.15}, "risk": 0.0, "spread": 1.0},
		{"id": "grip", "name": "Mechanischer Grip", "desc": "mehr Haftung in langsamen Kurven und über Randsteine, stark im Regen", "prof": {"df": 0.4, "wet": 0.55, "tyre": 0.1}, "risk": 0.0, "spread": 1.0},
	],
	"pu": [
		{"id": "power", "name": "Leistung", "desc": "mehr PS und Topspeed, der Motor wird etwas anfälliger – mutig", "prof": {"power": 1.0, "rel": -0.3}, "risk": 0.04, "spread": 1.2},
		{"id": "rel", "name": "Haltbarkeit und Energie", "desc": "standfester Motor und bessere Energierückgewinnung, etwas mehr Leistung", "prof": {"power": 0.45, "rel": 0.7}, "risk": -0.03, "spread": 0.85},
	],
}
const PROF_KEYS := ["df", "power", "tyre", "wet", "rel"]
const PROF_SCALE := 1.2       # Profilverschiebung je Punkt Entwicklung (0,1 % Tempo im Bereich etwa 0,12 Profil)
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
	var p: Dictionary = Game.dev_parts[a]
	if not p.has("foc_cur"):
		# ältere Spielstände: Heckflügel kannte schon Abtrieb/Topspeed, der Rest zählt zum klassischen Schwerpunkt
		p["foc_cur"] = {}
		p["foc_next"] = {}
		if a == "rear":
			p["foc_cur"] = {"df": maxf(0.0, float(p["cur"]) - float(p.get("rear_speed_cur", 0.0))), "speed": float(p.get("rear_speed_cur", 0.0))}
			p["foc_next"] = {"df": maxf(0.0, float(p["next"]) - float(p.get("rear_speed_next", 0.0))), "speed": float(p.get("rear_speed_next", 0.0))}
		else:
			p["foc_cur"] = {focus(a, "")["id"]: float(p["cur"])}
			p["foc_next"] = {focus(a, "")["id"]: float(p["next"])}
		for k in ["rear_speed_cur", "rear_df_cur", "rear_speed_next", "rear_df_next"]:
			p.erase(k)
	return p


## Schwerpunkt-Daten (unbekannte ID: der klassische erste Schwerpunkt).
static func focus(a: String, id: String) -> Dictionary:
	for f in FOCUS[a]:
		if str(f["id"]) == id:
			return f
	return FOCUS[a][0]


## Profilverschiebung eines Schwerpunkts als lesbarer Kurztext, z. B. "Abtrieb ++, Topspeed -".
static func focus_effect_text(a: String, id: String) -> String:
	var names := {"df": "Abtrieb", "power": "Topspeed", "tyre": "Reifen", "wet": "Regen", "rel": "Standfestigkeit"}
	var parts: Array = []
	var prof: Dictionary = focus(a, id)["prof"]
	for k in PROF_KEYS:
		if not prof.has(k):
			continue
		var v := float(prof[k])
		var s := "+++" if v >= 0.85 else ("++" if v >= 0.5 else ("+" if v > 0.0 else ("--" if v <= -0.3 else "-")))
		parts.append("%s %s" % [names[k], s])
	return ", ".join(parts)


## Gleichzeitig laufende Projekte (Kapazität des Konstruktionsbüros).
static func slots() -> int:
	return 3 if Staff.rating("td") >= 80.0 else 2


## Abnehmender Ertrag: je weiter der Bereich schon entwickelt ist, desto weniger bringt das nächste Teil.
static func efficiency(a: String, target: String) -> float:
	var lv := float(part(a)[target])
	return 1.0 / (1.0 + lv / 0.6)


static func reg_next() -> bool:
	return (Game.year + 1) in Game.REG_YEARS


## Kennzahlen eines möglichen Projekts (mit Technischem Direktor, abnehmendem Ertrag und Schwerpunkt).
## Mutige Schwerpunkte (spread > 1) streuen weiter: schlechtester Fall tiefer, bester Fall höher, öfter Fehlschlag.
static func quote(a: String, size: String, target: String, spec := "") -> Dictionary:
	var s: Dictionary = SIZES[size]
	var fo := focus(a, spec)
	var L := Staff.level("td")
	var f := float(AREA[a]["w"]) * (0.8 + 0.45 * L) * efficiency(a, target) * (NEXT_GAIN if target == "next" else 1.0)
	var races := maxi(1, int(round(float(s["races"]) * (1.25 - 0.45 * L))))
	var left := Game.calendar.size() - Game.round_index
	var sp := float(fo["spread"])
	var lo := float(s["lo"]) * f / sp
	var hi := float(s["hi"]) * f * (1.0 + (sp - 1.0) * 0.8)
	return {"cost": float(s["cost"]), "races": races, "lo": lo, "hi": hi, "spec": str(fo["id"]),
		"fail": clampf(0.16 - 0.12 * L + float(fo["risk"]), 0.02, 0.4), "late": target == "cur" and races > left}


static func can_start(cost: float) -> String:
	if Game.dev_projects.size() >= slots():
		return "Alle Projektplätze sind belegt."
	if Game.budget < cost:
		return "Nicht genug Budget."
	if Game.cap_left() < cost:
		return "Die Kostenobergrenze ist erreicht."
	return ""


## Projekt starten. spec: Schwerpunkt-ID aus FOCUS (leer = klassischer Weg). Rückgabe: Fehlertext oder "".
static func start(a: String, size: String, target: String, spec := "") -> String:
	var q := quote(a, size, target, spec)
	var err := can_start(float(q["cost"]))
	if err != "":
		return err
	Game.budget -= float(q["cost"])
	Game.dev_spent += float(q["cost"])
	Game.dev_projects.append({"area": a, "size": size, "target": target, "spec": q["spec"], "cost": q["cost"], "races": int(q["races"]),
		"left": int(q["races"]), "lo": q["lo"], "hi": q["hi"], "fail": q["fail"], "year": Game.year})
	return ""


## Ausgang eines fertigen Projekts: "flop" (bringt nichts), "half" (Windkanal und Strecke passen nicht zusammen, nur ein Teil des
## erwarteten Zuwachses), "ok" (im erwarteten Bereich) oder "top" (Durchbruch über dem Erwarteten). Rückgabe {"kind", "gain"}.
static func roll_outcome(p: Dictionary, r: float, r2: float) -> Dictionary:
	var fail := float(p["fail"])
	var lo := float(p["lo"])
	var hi := float(p["hi"])
	if r < fail:
		return {"kind": "flop", "gain": 0.0}
	if r < fail + 0.04 + fail * 0.6:
		return {"kind": "half", "gain": lo * lerpf(0.25, 0.7, r2)}
	if r > 0.94:
		return {"kind": "top", "gain": hi * lerpf(1.05, 1.3, r2)}
	return {"kind": "ok", "gain": lerpf(lo, hi, r2)}


## Nach jedem Rennen: Projekte rücken vor, fertige Teile werden geliefert (Zuwachs zufällig, siehe roll_outcome).
static func tick_race() -> Array:
	var done: Array = []
	for p in Game.dev_projects.duplicate():
		p["left"] = int(p["left"]) - 1
		if int(p["left"]) > 0:
			continue
		Game.dev_projects.erase(p)
		var o := roll_outcome(p, Game.rng.randf(), Game.rng.randf())
		deliver(p, float(o["gain"]), str(o["kind"]) == "flop", str(o["kind"]))
		done.append(p)
	return done


static func deliver(p: Dictionary, gain: float, failed: bool, kind := "") -> void:
	var a: String = p["area"]
	var target: String = p["target"]
	var fo := focus(a, str(p.get("spec", "")))
	var pt := part(a)
	pt[target] = float(pt[target]) + gain
	var fk := "foc_" + target
	pt[fk][fo["id"]] = float(pt[fk].get(fo["id"], 0.0)) + gain
	if target == "cur":
		Game.dev_pace[Game.team_id] = float(Game.dev_pace.get(Game.team_id, 0.0)) + gain / 100.0
	var nm: String = "%s (%s)" % [AREA[a]["name"], fo["name"]]
	var txt := ""
	if kind == "":
		kind = "flop" if failed else "ok"
	var when := "neues Teil am Auto" if target == "cur" else "für das Auto %d fertig" % (Game.year + 1)
	match kind:
		"flop":
			txt = "%s, %s: Das Teil bringt auf der Strecke nichts, zurück ans Reißbrett." % [nm, SIZES[p["size"]]["name"]]
		"half":
			txt = "%s: %s, aber Windkanal und Strecke passen nicht zusammen – nur +%.2f %% (erwartet %.2f bis %.2f)." % [nm, when, gain, float(p["lo"]), float(p["hi"])]
		"top":
			txt = "%s: Durchbruch! %s, +%.2f %% Tempo (erwartet höchstens %.2f)." % [nm, when, gain, float(p["hi"])]
		_:
			txt = "%s: %s, +%.2f %% Tempo (erwartet %.2f bis %.2f)." % [nm, when, gain, float(p["lo"]), float(p["hi"])]
	if target == "next" and kind != "flop":
		txt += " Wirkt ab nächster Saison."
	Game.dev_log.push_front({"year": Game.year, "round": Game.round_index, "area": a, "size": p["size"], "target": target, "gain": gain,
		"lo": p["lo"], "hi": p["hi"], "failed": failed, "kind": kind, "spec": fo["id"], "text": txt})
	if Game.dev_log.size() > 30:
		Game.dev_log.resize(30)
	Market.news("dev" if kind == "ok" or kind == "top" else "info", txt)


## Sofortiger Zuwachs am aktuellen Auto (z. B. durch eine Meldung), zählt zum klassischen Schwerpunkt.
static func instant(a: String, gain: float) -> void:
	var pt := part(a)
	pt["cur"] = float(pt["cur"]) + gain
	var fid: String = focus(a, "")["id"]
	pt["foc_cur"][fid] = float(pt["foc_cur"].get(fid, 0.0)) + gain
	Game.dev_pace[Game.team_id] = float(Game.dev_pace.get(Game.team_id, 0.0)) + gain / 100.0


## Verschiebung des Fahrzeugprofils durch die Entwicklung am aktuellen Auto ("next": am Auto der nächsten Saison).
static func profile_shift(target := "cur") -> Dictionary:
	var out := {}
	for k in PROF_KEYS:
		out[k] = 0.0
	for a in AREAS:
		var foc: Dictionary = part(a)["foc_" + target]
		for id in foc.keys():
			var prof: Dictionary = focus(a, str(id))["prof"]
			for k in prof.keys():
				out[k] += float(prof[k]) * float(foc[id]) * PROF_SCALE
	return out


## Zuverlässigkeit: Kühlung und haltbarer Motor senken technische Defekte, schlanke Seitenkästen und Leistung erhöhen sie leicht.
static func mech_factor() -> float:
	var rel := clampf(float(profile_shift()["rel"]), -0.4, 2.0)
	return clampf(1.0 / (1.0 + rel * 0.75), 0.55, 1.45)


## KI-Entwicklung: ein Pace-Zuwachs (Anteil, z. B. 0.0004) geht in einen zufälligen Bereich und Schwerpunkt und verschiebt das
## Profil des KI-Autos. Die Verschiebung ist um den Mittelwert der Schwerpunkte des Bereichs bereinigt: der Zuwachs steckt schon
## in der Pace, das Profil ändert nur den Charakter. Ohne Standfestigkeit (die KI-Defektrate bleibt wie in den Daten).
static func ai_develop(tid: String, inc: float, rng: RandomNumberGenerator) -> void:
	if inc <= 0.0:
		return
	var tot := 0.0
	for a in AREAS:
		tot += float(AREA[a]["w"])
	var r := rng.randf() * tot
	var area: String = AREAS[0]
	for a in AREAS:
		r -= float(AREA[a]["w"])
		if r <= 0.0:
			area = a
			break
	var opts: Array = FOCUS[area]
	var fo: Dictionary = opts[rng.randi() % opts.size()]
	var cur: Dictionary = Game.ai_dev_prof.get(tid, {})
	for k in ["df", "power", "tyre", "wet"]:
		var mean := 0.0
		for o in opts:
			mean += float(o["prof"].get(k, 0.0))
		mean /= float(opts.size())
		var v := float(fo["prof"].get(k, 0.0)) - mean
		if absf(v) > 0.001:
			cur[k] = float(cur.get(k, 0.0)) + v * inc * 100.0 * PROF_SCALE
	Game.ai_dev_prof[tid] = cur


## Saisonwechsel (nach dem Mischen des Kräfteverhältnisses): das vorbereitete neue Auto übernimmt die Entwicklung fürs nächste Jahr.
## Laufende Projekte fürs alte Auto verfallen, Projekte fürs neue Auto laufen weiter.
static func season_rollover() -> void:
	var bank := 0.0
	for a in AREAS:
		var p := part(a)
		bank += float(p["next"])
		p["cur"] = float(p["next"])
		p["foc_cur"] = p["foc_next"]
		p["next"] = 0.0
		p["foc_next"] = {}
	Game.dev_pace[Game.team_id] = float(Game.dev_pace.get(Game.team_id, 0.0)) + bank / 100.0
	# KI-Autos: das Konzept wird zum Teil mitgenommen, ein neues Reglement setzt es zurück
	var carry := 0.0 if Game.year in Game.REG_YEARS else 0.4
	for tid in Game.ai_dev_prof.keys():
		var pr: Dictionary = Game.ai_dev_prof[tid]
		for k in pr.keys():
			pr[k] = float(pr[k]) * carry
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

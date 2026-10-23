extends RefCounted
## Karriere neben den Rennen: Rennziele, Vorstandsvertrauen, Saisonziel, Sponsorenvertrag und Meldungen aus der Zentrale.
## Der Spielstand liegt im Autoload "Game" (board, sponsor_id, goal_log, finance_log, pending_event, event_mods).

const Market = preload("res://scripts/market.gd")
const Field = preload("res://scripts/field.gd")

const SPONSORS := [
	{"id": "safe", "name": "Nordwind Energie", "tag": "Sicher", "base": 1.8, "pts": 0.75, "goal": 0.8, "desc": "Hohes Fixum, aber wenig Prämie für Punkte und Rennziele."},
	{"id": "mid", "name": "Vertex Telekom", "tag": "Ausgewogen", "base": 0.9, "pts": 1.0, "goal": 1.0, "desc": "Mittleres Fixum, normale Prämien."},
	{"id": "perf", "name": "Atlas Motorwelt", "tag": "Erfolgsabhängig", "base": 0.0, "pts": 1.5, "goal": 1.6, "desc": "Kein Fixum, dafür deutlich mehr Geld für Punkte und erreichte Rennziele."},
]

# Meldungen aus der Zentrale. Ein Effekt (fx) kann sein: budget (Mio. $, Kosten zählen für die Kostengrenze, wenn "dev"), upgrade (Stufe),
# morale_all / morale_first / morale_second, crew (Boxencrew-Form), mech [Faktor, Rennen], pace (Pace-Zuwachs), board (Vertrauen),
# chance {"p", "ok", "bad"} (Zufallsausgang), text (Meldung nach der Wahl). cond (am Meldungskopf) = nur bei dieser Lage im Teamfeld (field.gd).
const EVENTS := {
	"wind_tunnel": {"title": "Windkanal-Zeit frei geworden", "text": "Ein anderes Team hat seinen Windkanal-Slot abgesagt. Du kannst ihn kurzfristig übernehmen.", "need": 12.0, "options": [
		{"label": "Nutzen (6 Mio. $)", "hint": "Eine Stufe Aerodynamik mehr (wenn noch Luft nach oben ist).", "fx": {"budget": -6.0, "dev": true, "upgrade": "aero", "text": "Das Windkanal-Programm bringt eine Aero-Stufe."}},
		{"label": "Verzichten", "hint": "Das Geld bleibt in der Kasse.", "fx": {"text": "Du lässt den Slot verfallen."}},
	]},
	"supplier": {"title": "Zulieferer meldet fehlerhafte Charge", "text": "Ein Zulieferer hat eine Charge Getriebeteile mit Materialfehlern geliefert. Einige Teile sind schon verbaut.", "need": 0.0, "options": [
		{"label": "Alles tauschen (5 Mio. $)", "hint": "Sicher: kein erhöhtes Ausfallrisiko.", "fx": {"budget": -5.0, "text": "Alle Teile werden getauscht, keine Folgen."}},
		{"label": "Stichproben (1 Mio. $)", "hint": "Für 2 Rennen etwas mehr technische Defekte (+15 %).", "fx": {"budget": -1.0, "mech": [1.15, 2], "text": "Nur Stichproben: 2 Rennen lang etwas höheres Risiko."}},
		{"label": "Ignorieren", "hint": "Spart Geld, aber 3 Rennen lang deutlich mehr Defekte (+45 %).", "fx": {"mech": [1.45, 3], "text": "Du ignorierst die Warnung: 3 Rennen lang deutlich höheres Ausfallrisiko."}},
	]},
	"media_day": {"title": "Sponsor lädt zum Medientag", "text": "Der Sponsor möchte beide Fahrer für einen Medientag. Das kostet Zeit an der Strecke, bringt aber Geld.", "need": 0.0, "options": [
		{"label": "Zusagen", "hint": "+4 Mio. $, die Fahrer sind etwas genervt, der Vorstand freut sich.", "fx": {"budget": 4.0, "morale_all": -0.03, "board": 1.0, "text": "Der Medientag bringt 4 Mio. $, die Fahrer sind etwas genervt."}},
		{"label": "Absagen", "hint": "Die Fahrer können sich auf das Rennen konzentrieren.", "fx": {"board": -1.0, "text": "Der Sponsor ist enttäuscht, der Vorstand weniger zufrieden."}},
	]},
	"rivalry": {"title": "Streit der Fahrer", "text": "Nach dem letzten Rennen gibt es Zoff zwischen deinen Fahrern. Beide erwarten ein Machtwort.", "need": 0.0, "pair": true, "options": [
		{"label": "Beide ermahnen", "hint": "Beide sind etwas verärgert, der Streit ist aber vorbei.", "fx": {"morale_all": -0.02, "text": "Du ermahnst beide, der Streit ist beigelegt."}},
		{"label": "Dem Besseren den Rücken stärken", "hint": "Er ist glücklich (+), sein Teamkollege verärgert (--).", "fx": {"morale_first": 0.05, "morale_second": -0.08, "text": "Dein bester Fahrer fühlt sich gestärkt, sein Teamkollege ist verärgert."}},
		{"label": "Laufen lassen", "hint": "Mit etwas Pech eskaliert es: dann sind beide deutlich unzufrieden.", "fx": {"chance": {"p": 0.55, "ok": {"text": "Die Wogen glätten sich von selbst."}, "bad": {"morale_all": -0.06, "text": "Der Streit eskaliert, beide sind deutlich unzufrieden."}}}},
	]},
	"crew_camp": {"title": "Trainingslager für die Boxencrew", "text": "Ein Boxencrew-Coach bietet ein Trainingslager an, damit die Stopps schneller und sicherer werden.", "need": 8.0, "options": [
		{"label": "Buchen (4 Mio. $)", "hint": "Die Form der Boxencrew steigt deutlich.", "fx": {"budget": -4.0, "dev": true, "crew": 0.35, "text": "Das Trainingslager hebt die Form der Boxencrew."}},
		{"label": "Nein danke", "hint": "Nichts ändert sich.", "fx": {"text": "Die Crew trainiert wie gewohnt."}},
	]},
	"fan_event": {"title": "Fan-Aktion in der Fabrik", "text": "Die Marketingabteilung schlägt einen Fantag in der Fabrik vor.", "need": 0.0, "options": [
		{"label": "Groß aufziehen (1 Mio. $)", "hint": "Bringt etwa 5 Mio. $ ein.", "fx": {"budget": 4.0, "board": 1.0, "text": "Der Fantag ist ein Erfolg: netto +4 Mio. $."}},
		{"label": "Klein halten", "hint": "Bringt etwa 2 Mio. $.", "fx": {"budget": 2.0, "text": "Ein kleiner Fantag bringt 2 Mio. $."}},
	]},
	"poach": {"title": "Konkurrent will Ingenieur abwerben", "text": "Ein Rivale versucht, einen wichtigen Aerodynamiker abzuwerben.", "need": 5.0, "options": [
		{"label": "Bonus zahlen (3 Mio. $)", "hint": "Er bleibt sicher.", "fx": {"budget": -3.0, "text": "Der Ingenieur bleibt."}},
		{"label": "Gegenangebot (1,5 Mio. $)", "hint": "60 % Chance, dass er bleibt, sonst geht er und das Auto verliert etwas Entwicklung.", "fx": {"budget": -1.5, "chance": {"p": 0.6, "ok": {"text": "Er bleibt für das Gegenangebot."}, "bad": {"pace": -0.0005, "text": "Er geht trotzdem: das Auto verliert etwas Entwicklung."}}}},
		{"label": "Gehen lassen", "hint": "Das Auto verliert etwas Entwicklung.", "fx": {"pace": -0.0005, "text": "Der Ingenieur wechselt zum Rivalen, das Auto verliert etwas Entwicklung."}},
	]},
	"test_day": {"title": "Testfahrt-Angebot", "text": "Auf einer privaten Strecke ist ein Testtag frei. Die Fahrer könnten sich einfahren.", "need": 6.0, "options": [
		{"label": "Testtag buchen (2 Mio. $)", "hint": "Beide Fahrer sind spürbar besser gelaunt.", "fx": {"budget": -2.0, "morale_all": 0.04, "text": "Der Testtag hebt die Stimmung beider Fahrer."}},
		{"label": "Nicht buchen", "hint": "Nichts passiert.", "fx": {"text": "Kein Testtag."}},
	]},
	"ex_assets": {"title": "Auktion des ausgestiegenen Teams", "text": "Ein Rennstall hat die Formel 1 verlassen. Seine Fabrik wird abgewickelt, Ingenieure, Windkanal-Modelle und Werkzeug werden angeboten.", "need": 6.0, "cond": "exit", "options": [
		{"label": "Ingenieure verpflichten (5 Mio. $)", "hint": "Etwas mehr Entwicklung für das Auto.", "fx": {"budget": -5.0, "dev": true, "pace": 0.0005, "text": "Erfahrene Ingenieure des ausgestiegenen Teams verstärken deine Entwicklung."}},
		{"label": "Werkzeug ersteigern (2 Mio. $)", "hint": "60 % Chance auf schnellere Boxenstopps, sonst ein Fehlkauf.", "fx": {"budget": -2.0, "chance": {"p": 0.6, "ok": {"crew": 0.3, "text": "Das ersteigerte Werkzeug beschleunigt die Boxenstopps."}, "bad": {"text": "Der Kauf bringt nichts: Die Teile passen nicht zu deinem Auto."}}}},
		{"label": "Nicht mitbieten", "hint": "Nichts passiert.", "fx": {"text": "Du bietest nicht mit."}},
	]},
	"newcomer": {"title": "Neueinsteiger sucht Technik-Partner", "text": "Das neue Team in der Startaufstellung hat noch keine Infrastruktur und fragt dich nach einer Kooperation.", "need": 0.0, "cond": "enter", "options": [
		{"label": "Kooperation (+5 Mio. $)", "hint": "Du verkaufst Dienstleistungen, die Fahrer sind kurz abgelenkt, der Vorstand freut sich.", "fx": {"budget": 5.0, "morale_all": -0.02, "board": 1.0, "text": "Die Kooperation bringt 5 Mio. $ ein, die Fahrer sind etwas genervt."}},
		{"label": "Nur Standardvertrag (+2 Mio. $)", "hint": "Wenig Aufwand, wenig Ertrag.", "fx": {"budget": 2.0, "text": "Du lieferst zum Standardpreis, +2 Mio. $."}},
		{"label": "Ablehnen", "hint": "Keine Geheimnisse für die Konkurrenz.", "fx": {"text": "Du lehnst die Anfrage ab."}},
	]},
	"simulator": {"title": "Simulator-Update", "text": "Der Simulator-Hersteller bietet ein Update an, das die Korrelation zur Strecke verbessert.", "need": 10.0, "options": [
		{"label": "Kaufen (5 Mio. $)", "hint": "Etwas mehr Pace über die ganze Saison.", "fx": {"budget": -5.0, "dev": true, "pace": 0.0004, "text": "Das Simulator-Update bringt etwas Pace."}},
		{"label": "Ablehnen", "hint": "Nichts passiert.", "fx": {"text": "Du lehnst das Update ab."}},
	]},
}


# ------------------------------------------------------------------ Hilfen

static func pace_rank() -> int:
	return Game.team_rank(Game.team_id) + 1


## Erwartete Teampunkte pro Rennen (beide Autos) je Stärkerang, skaliert auf die Punktetabelle der Saison.
static func expected_points(rank: int) -> float:
	var tbl := [30.0, 21.0, 16.0, 11.0, 7.0, 5.0, 3.0, 2.0, 1.0, 0.5]
	var pts: Array = Game.rules["points"]
	return float(tbl[mini(maxi(rank, 1) - 1, tbl.size() - 1)]) * float(pts[0]) / 25.0


static func sponsor_by_id(id: String) -> Dictionary:
	for s in SPONSORS:
		if str(s["id"]) == id:
			return s
	return SPONSORS[1]


static func sponsor() -> Dictionary:
	return sponsor_by_id(Game.sponsor_id)


## Erwartete Einnahmen pro Rennen aus Sponsor, Punkten und Rennziel-Prämien (halbe Erfolgsquote) mit diesem Vertrag.
## Fixum und Prämien sind auf eine Saison mit 22 Rennen bemessen; bei mehr oder weniger Rennen pro Rennen entsprechend
## weniger oder mehr, damit die Saisonsumme gleich bleibt.
static func race_scale() -> float:
	return 22.0 / maxf(1.0, float(Game.calendar.size()))


## Geld pro WM-Punkt (Mio. $), auf das heutige Punkteschema umgerechnet (früher gab es für einen Sieg 10 statt 25 Punkte).
static func point_value() -> float:
	return 0.08 * 25.0 / float(Game.rules["points"][0])


static func sponsor_income(sp: Dictionary) -> float:
	return (float(sp["base"]) + 0.5 * 1.0 * float(sp["goal"])) * race_scale() + point_value() * float(sp["pts"]) * expected_points(pace_rank())


static func board_word() -> String:
	var b: float = Game.board
	if b >= 80.0:
		return "begeistert"
	if b >= 60.0:
		return "zufrieden"
	if b >= 40.0:
		return "abwartend"
	if b >= 20.0:
		return "unzufrieden"
	return "kurz vor dem Ultimatum"


static func board_color() -> Color:
	var b: float = Game.board
	if b >= 60.0:
		return Color("1f8f4e")
	if b >= 40.0:
		return Color("b8860b")
	return Color("c0392b")


# ------------------------------------------------------------------ Rennziel

## Erwartete Platzierung des besten Autos eines Teams aus den Stärkeunterschieden (passt zu Simulationsläufen mehrerer Saisons).
static func expected_best(tid: String) -> float:
	var pm := 0.0
	for t in Game.teams:
		if str(t["id"]) == tid:
			pm = float(t["pace"]) + float(Game.dev_pace.get(tid, 0.0))
	var e := 1.0 - 0.8
	for t in Game.teams:
		if str(t["id"]) == tid:
			continue
		var pj: float = float(t["pace"]) + float(Game.dev_pace.get(str(t["id"]), 0.0))
		e += 2.0 * 0.85 / (1.0 + exp(-1.702 * (pj - pm) / 0.0055))
	return maxf(e, 0.3)


## Ziel für das nächste Rennen (je Rennen gemerkt): {"kind": best|both|duel, "target", "stretch", "text", "bonus", "bonus_hi", "rival"}.
## Abwechselnd: Platzierung, beide Autos, Duell gegen den Rivalen in der Konstrukteurs-WM.
static func race_goal() -> Dictionary:
	if int(Game.goal_cache.get("round", -1)) == Game.round_index and Game.goal_cache.has("goal"):
		return Game.goal_cache["goal"]
	var g := _make_goal()
	Game.goal_cache = {"round": Game.round_index, "goal": g}
	return g


static func _make_goal() -> Dictionary:
	var solo: bool = Game.solo_driver() != ""
	var pts_n: int = (Game.rules["points"] as Array).size()
	var cars: int = Game.teams.size() * 2
	var m := expected_best(Game.team_id)
	var who := "Dein Fahrer" if solo else "Mindestens ein Auto"
	var kind := "best"
	var target: int = clampi(int(ceil(m + 0.4)), 1, cars - 2)
	var stretch: int = maxi(0, target - maxi(2, int(round(float(target) * 0.3)))) if target > 1 else 0
	var rival := ""
	var rival_name := ""
	var text := ""
	var phase: int = Game.round_index % 3
	if phase == 1 and not solo and int(ceil(m + 4.0)) <= pts_n + 2:
		kind = "both"
		target = int(ceil(m + 4.0))
		stretch = maxi(1, target - 4)
	elif phase == 2 and Game.round_index >= 2:
		var st: Array = Game.team_standings()
		var mi := -1
		for i in st.size():
			if str(st[i]["id"]) == Game.team_id:
				mi = i
		if mi >= 0:
			var ri: int = mi - 1 if mi > 0 else mi + 1
			if mi > 0 and mi < st.size() - 1:
				# der Rivale mit dem kleineren Punkteabstand
				var up: float = absf(float(st[mi - 1]["points"]) - float(st[mi]["points"]))
				var dn: float = absf(float(st[mi + 1]["points"]) - float(st[mi]["points"]))
				ri = mi - 1 if up <= dn else mi + 1
			if ri >= 0 and ri < st.size():
				kind = "duel"
				rival = str(st[ri]["id"])
				rival_name = str(st[ri]["name"])
	match kind:
		"duel":
			text = "%s vor dem besten %s" % ["Dein Fahrer" if solo else "Dein bestes Auto", rival_name]
		"both":
			text = "Beide Autos in die Top %d" % target
		_:
			var place := "gewinnt" if target == 1 else ("aufs Podium" if target == 3 else ("in die Punkte" if target == pts_n else "in die Top %d" % target))
			if target == 1:
				text = "%s gewinnt" % ("Dein Fahrer" if solo else "Ein Auto")
			else:
				text = "%s %s" % [who, place]
	var sp := sponsor()
	return {"kind": kind, "target": target, "stretch": stretch, "text": text, "rival": rival, "bonus": 1.0 * float(sp["goal"]) * race_scale(), "bonus_hi": 2.0 * float(sp["goal"]) * race_scale()}


## Platzierungsliste aus Ergebniszeilen: [{"team", "pos", "player"}], Ausgefallene als 99.
static func _entries_rows(rows: Array) -> Array:
	var out: Array = []
	for r in rows:
		out.append({"team": str(r["team_id"]), "pos": 99 if int(r["state"]) == 3 else int(r["pos"]), "player": bool(r["player"]), "code": str(r["code"])})
	return out


static func _entries_sim(sim) -> Array:
	var out: Array = []
	var rk: Array = sim.ranking()
	for i in rk.size():
		var c = rk[i]
		out.append({"team": str(c.team_id), "pos": 99 if c.state == 3 else i + 1, "player": c.is_player, "code": str(c.code)})
	return out


## Auswertung anhand der Platzierungen: {"met", "exceeded", "best", "worst", "rival_best"}
static func eval_goal(g: Dictionary, ent: Array) -> Dictionary:
	var mine: Array = []
	var rival_best := 99
	for e in ent:
		if e["player"]:
			mine.append(int(e["pos"]))
		elif str(e["team"]) == str(g.get("rival", "-")):
			rival_best = mini(rival_best, int(e["pos"]))
	mine.sort()
	var best: int = 99 if mine.is_empty() else int(mine[0])
	var worst: int = 99 if mine.is_empty() else int(mine[mine.size() - 1])
	var target: int = int(g["target"])
	var stretch: int = int(g["stretch"])
	var met := false
	var top := false
	match str(g["kind"]):
		"both":
			met = worst <= target
			top = met and best <= stretch
		"duel":
			met = best < 99 and best < rival_best
			top = met and (worst < rival_best or best <= rival_best - 3)
		_:
			met = best <= target
			top = met and (best <= stretch or (target == 1 and mine.size() >= 2 and worst <= 2))
	return {"met": met, "exceeded": top, "best": best, "worst": worst, "rival_best": rival_best}


## Zwischenstand im Rennen: {"state": ok|risk|miss, "text", "short"}.
static func live_status(sim) -> Dictionary:
	var g := race_goal()
	var ent := _entries_sim(sim)
	var parts: Array = []
	for e in ent:
		if e["player"]:
			parts.append("%s %s" % [str(e["code"]), "ausgefallen" if int(e["pos"]) >= 99 else "P%d" % int(e["pos"])])
	var ev := eval_goal(g, ent)
	var kind := str(g["kind"])
	var gap := 0
	match kind:
		"both":
			gap = int(ev["worst"]) - int(g["target"])
		"duel":
			gap = int(ev["best"]) - int(ev["rival_best"]) + 1
		_:
			gap = int(ev["best"]) - int(g["target"])
	var state := "miss"
	if bool(ev["met"]):
		state = "ok"
	elif gap <= 3:
		state = "risk"
	var line := ", ".join(parts)
	if kind == "duel" and int(ev["rival_best"]) < 99:
		line += "  |  %s P%d" % [Game.get_team(str(g["rival"])).get("name", "Rivale"), int(ev["rival_best"])]
	var text := "Rennziel: %s.\nJetzt: %s" % [str(g["text"]), line]
	if bool(ev["met"]):
		text += "  (erfüllt, Prämie %.1f Mio. $)" % float(g["bonus"])
	elif gap > 0 and gap < 90:
		text += "  (noch %d Plätze)" % gap
	return {"state": state, "text": text, "short": "%s: %s" % [str(g["text"]), line]}


## Rennziel nach dem Rennen abrechnen. rows = Ergebniszeilen.
## Rückgabe: {"text", "met", "exceeded", "bonus", "board", "goal", "best", "word"}
static func settle_race(rows: Array) -> Dictionary:
	var g := race_goal()
	var ev := eval_goal(g, _entries_rows(rows))
	var bonus := 0.0
	var board := -2.0
	var word := "verfehlt"
	if bool(ev["exceeded"]):
		bonus = float(g["bonus_hi"])
		board = 4.0
		word = "übertroffen"
	elif bool(ev["met"]):
		bonus = float(g["bonus"])
		board = 2.0
		word = "erreicht"
	elif int(ev["best"]) >= 99:
		board = -3.0
		word = "verfehlt (kein Auto im Ziel)"
	return {"text": "Rennziel \"%s\": %s" % [str(g["text"]), word], "met": bool(ev["met"]), "exceeded": bool(ev["exceeded"]), "bonus": bonus, "board": board, "goal": str(g["text"]), "kind": str(g["kind"]), "best": int(ev["best"]), "word": word}


# ------------------------------------------------------------------ Saisonziel

static func season_eval() -> Dictionary:
	var fr: int = Game.final_rank(Game.team_id)
	var g: int = maxi(Game.season_goal_rank, 1)
	var d := g - fr
	var mult: float = float(sponsor()["goal"])
	if d >= 1:
		return {"text": "Saisonziel (Platz %d) übertroffen: Platz %d" % [g, fr], "bonus": 20.0 * mult, "board": 15.0, "word": "übertroffen"}
	if d == 0:
		return {"text": "Saisonziel (Platz %d) erreicht" % g, "bonus": 10.0 * mult, "board": 8.0, "word": "erreicht"}
	if d == -1:
		return {"text": "Saisonziel (Platz %d) knapp verfehlt: Platz %d" % [g, fr], "bonus": 0.0, "board": -5.0, "word": "knapp verfehlt"}
	return {"text": "Saisonziel (Platz %d) verfehlt: Platz %d" % [g, fr], "bonus": 0.0, "board": -14.0, "word": "verfehlt"}


## Saisonziel einmal verbuchen (beim Wechsel in den Fahrermarkt).
static func apply_season_eval() -> void:
	if Game.season_eval_done:
		return
	Game.season_eval_done = true
	var e := season_eval()
	Game.budget += float(e["bonus"])
	Game.board = clampf(Game.board + float(e["board"]), 0.0, 100.0)
	Game.last_season_eval = str(e["text"])
	Market.news("info", "%s. Prämie %.1f Mio. $, Vertrauen %+d." % [str(e["text"]), float(e["bonus"]), int(e["board"])])


# ------------------------------------------------------------------ Meldungen

static func event_def(id: String) -> Dictionary:
	if id == "sponsor":
		return sponsor_event()
	return EVENTS.get(id, {})


## Sponsorenangebot zu Saisonbeginn.
static func sponsor_event() -> Dictionary:
	var opts: Array = []
	for s in SPONSORS:
		opts.append({"label": "%s: %s" % [str(s["name"]), str(s["tag"])], "hint": "%s Erwartet ca. %.1f Mio. $ pro Rennen." % [str(s["desc"]), sponsor_income(s)], "fx": {"sponsor": str(s["id"]), "text": "Neuer Sponsor: %s (%s)." % [str(s["name"]), str(s["tag"])]}})
	return {"title": "Sponsorenvertrag für %d" % Game.year, "text": "Drei Sponsoren bieten dir einen Vertrag an. Das passende Modell hängt davon ab, wie viel du deinem Team zutraust.", "options": opts, "default": 1}


## Meldung nach einem Rennen auswürfeln (oder leer).
static func roll_event() -> void:
	if not Game.pending_event.is_empty() or Game.round_index < 1 or Game.round_index >= Game.calendar.size():
		return
	if Game.rng.randf() > 0.42:
		return
	var pool: Array = []
	for id in EVENTS.keys():
		var def: Dictionary = EVENTS[id]
		if int(Game.event_last.get(id, -99)) > Game.career_race_no - (20 if def.has("cond") else 6):
			continue
		if Game.budget < float(def.get("need", 0.0)):
			continue
		if def.get("pair", false) and Market.current_drivers(Game.team_id).size() < 2:
			continue
		if def.has("cond") and not Field.cond(str(def["cond"])):
			continue
		pool.append(id)
	if pool.is_empty():
		return
	var pick: String = str(pool[Game.rng.randi() % pool.size()])
	Game.pending_event = {"id": pick}
	Game.event_last[pick] = Game.career_race_no
	Game.event_seen = false


## Ohne Entscheidung: Vorgabe (letzte Option, beim Sponsor "Ausgewogen").
static func apply_default() -> void:
	if Game.pending_event.is_empty():
		return
	var def := event_def(str(Game.pending_event["id"]))
	var idx: int = int(def.get("default", def["options"].size() - 1))
	choose(idx)


## Option wählen und anwenden. Rückgabe: Meldungstext.
static func choose(idx: int) -> String:
	if Game.pending_event.is_empty():
		return ""
	var def := event_def(str(Game.pending_event["id"]))
	var opts: Array = def["options"]
	idx = clampi(idx, 0, opts.size() - 1)
	var text := apply_fx(opts[idx]["fx"])
	Game.pending_event = {}
	Game.career_log.push_front({"year": Game.year, "round": Game.round_index, "title": str(def["title"]), "choice": str(opts[idx]["label"]), "text": text})
	if Game.career_log.size() > 40:
		Game.career_log.resize(40)
	Market.news("info", "%s: %s" % [str(def["title"]), text])
	return text


static func apply_fx(fx: Dictionary) -> String:
	var text := str(fx.get("text", ""))
	if fx.has("chance"):
		var c: Dictionary = fx["chance"]
		var res: Dictionary = c["ok"] if Game.rng.randf() < float(c["p"]) else c["bad"]
		text = apply_fx(res)
	if fx.has("budget"):
		var b := float(fx["budget"])
		Game.budget += b
		if fx.get("dev", false) and b < 0.0:
			Game.dev_spent += -b
	if fx.has("upgrade"):
		var key := str(fx["upgrade"])
		if key in ["aero", "engine", "chassis"]:
			# Fahrzeugteile laufen über die Teile-Entwicklung (dev.gd)
			load("res://scripts/dev.gd").instant({"aero": "floor", "engine": "pu", "chassis": "susp"}[key], 0.10)
		elif int(Game.upgrades.get(key, 0)) < Game.MAX_LEVEL:
			Game.upgrades[key] = int(Game.upgrades[key]) + 1
		else:
			text += " (Die Stufe war schon am Maximum.)"
	if fx.has("pace"):
		Game.dev_pace[Game.team_id] = float(Game.dev_pace[Game.team_id]) + float(fx["pace"])
	if fx.has("crew"):
		Game.crew_form = clampf(Game.crew_form + float(fx["crew"]), 0.0, 1.0)
	if fx.has("board"):
		Game.board = clampf(Game.board + float(fx["board"]), 0.0, 100.0)
	if fx.has("mech"):
		Game.event_mods.append({"mech": float(fx["mech"][0]), "left": int(fx["mech"][1])})
	var drs: Array = Market.current_drivers(Game.team_id)
	if fx.has("morale_all"):
		for d in drs:
			d["morale"] = clampf(float(d["morale"]) + float(fx["morale_all"]), 0.0, 1.0)
	if fx.has("morale_first") and drs.size() > 0:
		drs[0]["morale"] = clampf(float(drs[0]["morale"]) + float(fx["morale_first"]), 0.0, 1.0)
	if fx.has("morale_second") and drs.size() > 1:
		drs[1]["morale"] = clampf(float(drs[1]["morale"]) + float(fx["morale_second"]), 0.0, 1.0)
	if fx.has("sponsor"):
		Game.sponsor_id = str(fx["sponsor"])
		Game.goal_cache = {}
	return text


## Aktueller Faktor für technische Defekte durch laufende Meldungen.
static func mech_factor() -> float:
	var f := 1.0
	for m in Game.event_mods:
		f *= float(m["mech"])
	return f


## Nach einem Rennen: laufende Wirkungen zählen herunter.
static func tick_mods() -> void:
	for m in Game.event_mods.duplicate():
		m["left"] = int(m["left"]) - 1
		if int(m["left"]) <= 0:
			Game.event_mods.erase(m)

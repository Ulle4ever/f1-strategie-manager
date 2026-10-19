extends RefCounted
## Teamfeld im Karriereverlauf: Neueinsteiger (fiktive Teams), Rückzüge, Fusionen und Umbenennungen.
##
## Ablauf je Saisonwechsel: Beim Öffnen des Fahrermarkts würfelt plan_changes() das Teamfeld des nächsten Jahres und kündigt es an
## (News, Chronik, Fahrer ausgestiegener Teams werden vertragslos). Beim Marktschluss setzt apply_plan() es um, noch bevor die KI die
## offenen Cockpits besetzt. Der Spieler-Rennstall bleibt immer im Feld. Der Spielstand liegt im Autoload "Game"
## (teams, team_meta, field_plan, field_log), Wappen und Daten der Karriere-Teams in DB.custom_teams.
##
## team_meta je Team (zusätzlich zu prestige/score/...): since = erste Saison eines Neueinsteigers, renamed = Jahr der letzten
## Umbenennung/Fusion, formerly = früherer Name, bottom = Saisons in Folge unter den letzten drei, fresh = Neueinsteiger vor dem ersten Saisonstart.

const Market = preload("res://scripts/market.gd")
const TeamStyle = preload("res://scripts/team_style.gd")

const FIELD_MIN := 9           # so viele Teams bleiben mindestens im Feld
const FIELD_MAX := 12          # und höchstens (die Rennsimulation ist bis 24 Autos erprobt)
const GRACE := 2               # volle Saisons Schonfrist für Neueinsteiger und Umbenannte
const EXIT_BASE := 0.10        # Rückzugschance je Jahr bei zwei Saisons in Folge unter den letzten drei Plätzen
const EXIT_STEP := 0.08        # plus je weiterer Saison
const EXIT_MAX := 0.40
const MERGE_P := 0.08
const RENAME_P := 0.07
const ENTER_BASE := 0.18
const NEW_MECH := 0.040        # technische Defekte eines Neueinsteigers (sinkt jedes Jahr bis MECH_FLOOR)
const MECH_FLOOR := 0.0135

## Namensvorrat der fiktiven Teams: n = Name, hq = Standort, tag = Charakter.
const NEW_TEAMS := [
	{"n": "Helios GP", "hq": "Lissabon, Portugal", "tag": "Neueinsteiger mit Solar-Sponsor und großen Ankündigungen. Die Fabrik ist neu, die Erfahrung fehlt noch."},
	{"n": "Zenith Racing", "hq": "Dubai, VAE", "tag": "Investorengeld vom Golf und der Anspruch, bald oben mitzufahren. Erst einmal heißt es lernen."},
	{"n": "Kestrel Motorsport", "hq": "Cambridge, England", "tag": "Kleine, wendige Truppe: Ingenieure aus großen Teams wollen es allen beweisen."},
	{"n": "Aurora Racing", "hq": "Oslo, Norwegen", "tag": "Skandinavische Gründlichkeit und viel Geduld. Das Nordlicht-Projekt setzt auf Nachwuchs."},
	{"n": "Falcon Dynamics", "hq": "Phoenix, USA", "tag": "US-Technologiekonzern auf Formel-1-Abenteuer: viel Datenanalyse, wenig Rennerfahrung."},
	{"n": "Orion Grand Prix", "hq": "Mailand, Italien", "tag": "Italienische Unternehmerfamilie mit Leidenschaft für den Rennsport. Klein anfangen, groß träumen."},
	{"n": "Valkyrie Racing", "hq": "Stuttgart, Deutschland", "tag": "Süddeutsche Ingenieurskunst aus der Zulieferer-Szene. Präzise, aber ohne Budgetpolster."},
	{"n": "Borealis Motorsport", "hq": "Helsinki, Finnland", "tag": "Finnische Rallye-Seele im Formelauto: kompromisslos und eigenwillig."},
	{"n": "Eclipse Racing", "hq": "Tokio, Japan", "tag": "Japanischer Elektronikkonzern, der sein Know-how in die Königsklasse trägt."},
	{"n": "Pinnacle GP", "hq": "Sydney, Australien", "tag": "Neueinsteiger mit Surfer-Mentalität: locker, selbstbewusst, aber noch langsam."},
	{"n": "Cobalt Racing", "hq": "Valencia, Spanien", "tag": "Spanisches Projekt mit Mittelmeer-Temperament und kleinem Etat."},
	{"n": "Ember Motorsport", "hq": "Montreal, Kanada", "tag": "Von einem Energiekonzern finanziert: glüht vor Ehrgeiz, aber noch nicht vor Tempo."},
	{"n": "Quantum Racing", "hq": "Zürich, Schweiz", "tag": "Rechenzentrum statt Windkanal: Das Team verspricht Strategie auf höchstem Niveau."},
	{"n": "Stratos GP", "hq": "São Paulo, Brasilien", "tag": "Brasilianische Leidenschaft: Fans, Samba und der Traum vom ersten Podium."},
	{"n": "Lumen Racing", "hq": "Eindhoven, Niederlande", "tag": "Niederländischer Licht-Technologiekonzern: hell, effizient und noch ganz am Anfang."},
	{"n": "Rheinland Racing", "hq": "Düsseldorf, Deutschland", "tag": "Mittelständler vom Rhein mit Autozulieferer-Hintergrund: solide, bodenständig, mutig."},
	{"n": "Tempest Motorsport", "hq": "Cardiff, Wales", "tag": "Walisischer Rennstall mit Sturm-Logo und Underdog-Charme."},
	{"n": "Sirius Grand Prix", "hq": "Singapur", "tag": "Singapurer Investoren, ein glänzender Name und das Ziel, Asiens Fans zu begeistern."},
	{"n": "Corsa Racing", "hq": "Modena, Italien", "tag": "Kleine Manufaktur aus dem Motor Valley mit dem Traum vom eigenen Motor."},
	{"n": "Titan Racing", "hq": "Houston, USA", "tag": "Texas-Stil: groß geplant, laut verkündet, noch leise auf der Strecke."},
	{"n": "Vanguard Racing", "hq": "Birmingham, England", "tag": "Britischer Hinterhof-Rennstall mit großem Herz und bescheidenen Mitteln."},
	{"n": "Mistral Racing", "hq": "Marseille, Frankreich", "tag": "Französisches Projekt: Eleganz, Esprit und Rückenwind aus dem Süden."},
	{"n": "Phoenix GP", "hq": "Johannesburg, Südafrika", "tag": "Der Phönix vom Kap: Kampfgeist, Gemeinschaft und ein langer Weg nach oben."},
	{"n": "Atlantic Racing", "hq": "Porto, Portugal", "tag": "Atlantik-Brise statt Windkanal-Luft: ein entspanntes Team mit ehrgeizigen Sponsoren."},
]

const SHAPES := ["shield", "round", "hex"]
const PATTERNS := ["stripe", "sash", "chevron", "split", "dots", "plain"]
const SECOND_COLORS := ["ffffff", "0b0e14", "ffcc00", "d6001c"]


# ------------------------------------------------------------------ Hilfen

static func is_leaving(tid: String) -> bool:
	return tid in (Game.field_plan.get("leaving", []) as Array)


## Name ohne Rechtsform-Anhängsel (für Fusionsnamen).
static func brand(n: String) -> String:
	var s := n
	for suf in [" F1 Team", " F1", " Grand Prix", " Motorsport", " Racing", " GP", " Team"]:
		if s.ends_with(suf) and s.length() > suf.length() + 1:
			s = s.substr(0, s.length() - suf.length())
	return s


static func _slug(n: String) -> String:
	var out := ""
	for ch in n.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif out != "" and not out.ends_with("_"):
			out += "_"
	return out.trim_suffix("_")


static func _team_name(tid: String) -> String:
	return str(Game.get_team(tid).get("name", tid))


## Saisons, die das Team in seiner jetzigen Form (seit Einstieg bzw. Umbenennung) mitgefahren ist; 99 = schon immer dabei.
static func seasons_in_field(tid: String) -> int:
	var meta: Dictionary = Game.team_meta.get(tid, {})
	var last := maxi(int(meta.get("since", 0)), int(meta.get("renamed", 0)))
	if last <= 0:
		return 99
	return Game.year - last + 1


static func _all_names() -> Dictionary:
	var used := {}
	for t in Game.teams:
		used[str(t["name"])] = true
	for k in DB.custom_teams.keys():
		used[str(DB.custom_teams[k]["name"])] = true
	return used


## Teamfarbe mit möglichst großem Farbtonabstand zu allen Teams im Feld.
static func _pick_color() -> Color:
	var hues: Array = []
	for t in Game.teams:
		var c: Color = DB.team_color(str(t["id"]))
		if c.s > 0.25 and c.v > 0.3:
			hues.append(c.h)
	var best_h := Game.rng.randf()
	var best_d := -1.0
	for k in 18:
		var h := (float(k) + Game.rng.randf()) / 18.0
		var dmin := 1.0
		for x in hues:
			var dd := absf(h - float(x))
			dmin = minf(dmin, minf(dd, 1.0 - dd))
		if dmin > best_d:
			best_d = dmin
			best_h = h
	return Color.from_hsv(best_h, Game.rng.randf_range(0.65, 0.9), Game.rng.randf_range(0.78, 0.95))


static func _unique_id(base: String, yr: int) -> String:
	var id := "x_" + base
	if DB.custom_teams.has(id) or not Game.get_team(id).is_empty():
		id = "%s_%d" % [id, yr]
	return id


static func _rand_profile() -> Dictionary:
	var p := {}
	for k in ["df", "power", "tyre", "wet"]:
		p[k] = snappedf(Game.rng.randf_range(-0.6, 0.6), 0.05)
	return p


static func _short(n: String) -> String:
	var s := ""
	for ch in n.to_upper():
		if ch >= "A" and ch <= "Z":
			s += ch
		if s.length() >= 2:
			break
	return s if s.length() == 2 else "XX"


# ------------------------------------------------------------------ Identitäten (Wappen, Name, Charakter)

## Fiktiver Neueinsteiger.
static func make_new_spec(yr: int) -> Dictionary:
	var used := _all_names()
	var pool: Array = []
	for entry in NEW_TEAMS:
		if not used.has(entry["n"]):
			pool.append(entry)
	var e: Dictionary
	if pool.is_empty():
		e = {"n": "Orbit Racing %d" % yr, "hq": "Silverstone, England", "tag": "Neues Team ohne Vorgeschichte, aber mit Ehrgeiz."}
	else:
		e = pool[Game.rng.randi() % pool.size()]
	var p_name := str(e["n"])
	return {"id": _unique_id(_slug(p_name), yr), "name": p_name, "color": _pick_color().to_html(false),
		"second": SECOND_COLORS[Game.rng.randi() % SECOND_COLORS.size()], "short": _short(p_name),
		"shape": SHAPES[Game.rng.randi() % SHAPES.size()], "pattern": PATTERNS[Game.rng.randi() % PATTERNS.size()],
		"hq": str(e["hq"]), "founded": yr, "titles": 0, "tag": str(e["tag"]), "profile": _rand_profile()}


## Neue Identität für ein bestehendes Team nach Umbenennung (neuer Eigentümer): Standort, Gründungsjahr, Titel und Auto-Charakter bleiben.
static func make_rename_spec(old_id: String, yr: int) -> Dictionary:
	var old: Dictionary = TeamStyle.info(old_id)
	var fresh := make_new_spec(yr)
	var old_name := _team_name(old_id)
	fresh["hq"] = str(old["hq"])
	fresh["founded"] = int(old["founded"])
	fresh["titles"] = int(old["titles"])
	fresh["tag"] = "Früher %s, jetzt unter neuem Eigentümer: neuer Name, neue Farben, derselbe Rennstall in Fabrik und Werkstatt." % old_name
	fresh["profile"] = _base_profile(old_id)
	return fresh


## Fusion: das Team B führt den Rennbetrieb unter kombiniertem Namen weiter (Farbe von B, Zweitfarbe von A).
static func make_merge_spec(a_id: String, b_id: String, yr: int) -> Dictionary:
	var a_name := _team_name(a_id)
	var b_name := _team_name(b_id)
	var ia: Dictionary = TeamStyle.info(a_id)
	var ib: Dictionary = TeamStyle.info(b_id)
	var p_name := "%s-%s" % [brand(b_name), brand(a_name)]
	var founded := int(ib["founded"])
	if int(ia["founded"]) > 0:
		founded = mini(founded, int(ia["founded"])) if founded > 0 else int(ia["founded"])
	var pa := _base_profile(a_id)
	var pb := _base_profile(b_id)
	var prof := {}
	for k in ["df", "power", "tyre", "wet"]:
		prof[k] = snappedf((float(pa.get(k, 0.0)) + float(pb.get(k, 0.0))) * 0.5, 0.05)
	return {"id": _unique_id(_slug(p_name), yr), "name": p_name, "color": DB.team_color(b_id).to_html(false), "second": DB.team_color(a_id).to_html(false),
		"short": (brand(b_name).substr(0, 1) + brand(a_name).substr(0, 1)).to_upper(), "shape": str(ib["shape"]), "pattern": "split",
		"hq": str(ib["hq"]), "founded": founded, "titles": int(ia["titles"]) + int(ib["titles"]),
		"tag": "Fusion aus %s und %s: zwei kleine Teams bündeln Fabrik, Personal und Budget, um aus dem Hinterfeld zu kommen." % [a_name, b_name],
		"profile": prof}


static func _base_profile(id: String) -> Dictionary:
	var base: Dictionary = DB.PROFILES.get(id, {})
	if base.is_empty() and DB.custom_teams.has(id):
		base = DB.custom_teams[id].get("profile", {})
	if base.is_empty():
		return _rand_profile()
	return base.duplicate()


# ------------------------------------------------------------------ Plan: würfeln und ankündigen

## Beim Öffnen der Marktphase: Teamfeld des nächsten Jahres bestimmen. Aktualisiert immer die Schlusslicht-Serien,
## verändert aber nur dann etwas, wenn die Option field_dynamic gesetzt ist.
static func plan_changes() -> void:
	Game.field_plan = {}
	var n: int = Game.teams.size()
	var st: Array = Game.team_standings()
	var rank_of := {}
	for i in st.size():
		rank_of[str(st[i]["id"])] = i
	for t in Game.teams:
		var tid := str(t["id"])
		var meta: Dictionary = Game.team_meta.get(tid, {})
		var weak: bool = int(rank_of.get(tid, 0)) >= n - 3
		meta["bottom"] = (int(meta.get("bottom", 0)) + 1) if weak else 0
		Game.team_meta[tid] = meta
	if not Game.field_dynamic:
		return
	var yr: int = Game.year + 1
	var plan := {"year": yr, "exits": [], "merges": [], "renames": [], "enters": [], "leaving": []}
	var ai: Array = []              # alle KI-Teams, schwächstes zuerst
	for t in Game.teams:
		if str(t["id"]) != Game.team_id:
			ai.append(str(t["id"]))
	ai.sort_custom(func(a, b): return int(rank_of.get(a, 0)) > int(rank_of.get(b, 0)))
	var gone := 0
	var taken := {}
	# 1. Rückzug: Teams mit mehreren schwachen Saisons in Folge
	var tried := 0
	for tid in ai:
		if tried >= 2 or n - gone - 1 < FIELD_MIN:
			break
		var streak := int(Game.team_meta[tid].get("bottom", 0))
		if streak < 2 or seasons_in_field(tid) < GRACE:
			continue
		tried += 1
		if Game.rng.randf() < minf(EXIT_MAX, EXIT_BASE + EXIT_STEP * float(streak - 2)):
			_plan_exit(plan, tid, yr)
			taken[tid] = true
			gone += 1
			break
	# 2. Fusion: ein schwaches Team geht in einem Team aus der unteren Hälfte auf (nicht im Jahr eines Rückzugs)
	if gone == 0 and n - 1 >= FIELD_MIN and Game.rng.randf() < MERGE_P:
		var a := ""
		for tid in ai:
			if int(rank_of.get(tid, 0)) >= n - 4 and seasons_in_field(tid) >= GRACE:
				a = tid
				break
		var partners: Array = ai.filter(func(i): return i != a and int(rank_of.get(i, 0)) >= n / 2 and seasons_in_field(i) >= GRACE)
		if a != "" and not partners.is_empty():
			var b: String = partners[Game.rng.randi() % partners.size()]
			_plan_merge(plan, a, b, yr)
			taken[a] = true
			taken[b] = true
			gone += 1
	# 3. Umbenennung: neuer Eigentümer in der unteren Hälfte
	if Game.rng.randf() < RENAME_P:
		var cands: Array = ai.filter(func(i): return int(rank_of.get(i, 0)) >= n / 2 and seasons_in_field(i) >= 3 and not taken.has(i))
		if not cands.is_empty():
			var c: String = cands[Game.rng.randi() % cands.size()]
			_plan_rename(plan, c, yr)
			taken[c] = true
	# 4. Neueinsteiger: je kleiner das Feld, desto wahrscheinlicher; nach einem Rückzug rückt gern jemand nach
	var size_after := n - gone
	if size_after < FIELD_MAX:
		var p := ENTER_BASE + 0.10 * float(maxi(0, 11 - size_after))
		if gone > 0:
			p += 0.15
		if yr - Game.field_last_entry < 3 and size_after > FIELD_MIN:
			p *= 0.4
		if Game.rng.randf() < minf(p, 0.9):
			_plan_enter(plan, yr)
	if (plan["exits"] as Array).is_empty() and (plan["merges"] as Array).is_empty() and (plan["renames"] as Array).is_empty() and (plan["enters"] as Array).is_empty():
		return
	Game.field_plan = plan


static func _log(yr: int, kind: String, text: String) -> void:
	Game.field_log.push_front({"year": yr, "kind": kind, "text": text})
	if Game.field_log.size() > 40:
		Game.field_log.resize(40)


## Fahrer eines aussteigenden Teams werden vertragslos. Rückgabe: ihre Namen.
static func _release_drivers(tid: String) -> Array:
	var names: Array = []
	for d in Market.current_drivers(tid):
		d["team"] = ""
		d["status"] = "free"
		d["contract"] = {}
		names.append(str(d["name"]))
	return names


static func _names_text(names: Array) -> String:
	if names.is_empty():
		return ""
	if names.size() == 1:
		return " %s ist ab sofort vertragslos." % names[0]
	return " %s sind ab sofort vertragslos." % " und ".join(names)


static func _plan_exit(plan: Dictionary, tid: String, yr: int) -> void:
	var nm := _team_name(tid)
	plan["exits"].append(tid)
	plan["leaving"].append(tid)
	var names := _release_drivers(tid)
	Market.news("team_out", "%s verlässt die Formel 1 nach der Saison.%s" % [nm, _names_text(names)])
	_log(yr, "team_out", "%s zieht sich zurück." % nm)


static func _plan_merge(plan: Dictionary, a: String, b: String, yr: int) -> void:
	var spec := make_merge_spec(a, b, yr)
	DB.register_team(spec)
	plan["merges"].append({"gone": a, "into": b, "spec": spec})
	plan["leaving"].append(a)
	var a_name := _team_name(a)
	var b_name := _team_name(b)
	var names := _release_drivers(a)
	Market.news("team_merge", "%s übernimmt %s und startet %d als %s.%s" % [b_name, a_name, yr, spec["name"], _names_text(names)])
	_log(yr, "team_merge", "%s und %s fusionieren zu %s." % [a_name, b_name, spec["name"]])


static func _plan_rename(plan: Dictionary, tid: String, yr: int) -> void:
	var spec := make_rename_spec(tid, yr)
	DB.register_team(spec)
	plan["renames"].append({"id": tid, "spec": spec})
	var old_name := _team_name(tid)
	Market.news("team_name", "%s hat einen neuen Eigentümer und startet %d als %s." % [old_name, yr, spec["name"]])
	_log(yr, "team_name", "%s heißt jetzt %s." % [old_name, spec["name"]])


static func _plan_enter(plan: Dictionary, yr: int) -> void:
	var spec := make_new_spec(yr)
	DB.register_team(spec)
	plan["enters"].append(spec)
	Market.news("team_in", "%s (%s) steigt %d in die Formel 1 ein und sucht noch Fahrer." % [spec["name"], spec["hq"], yr])
	_log(yr, "team_in", "%s steigt ein." % spec["name"])


# ------------------------------------------------------------------ Plan umsetzen

## Beim Marktschluss, vor der Besetzung der offenen Cockpits durch die KI.
static func apply_plan() -> void:
	var plan: Dictionary = Game.field_plan
	if plan.is_empty():
		return
	var yr := int(plan.get("year", Game.year + 1))
	for tid in plan.get("exits", []):
		_remove_team(str(tid))
	for m in plan.get("merges", []):
		var into := str(m["into"])
		var a_pace := _team_pace(str(m["gone"]))
		var a_name := _team_name(str(m["gone"]))
		_remove_team(str(m["gone"]))
		_rebrand(into, m["spec"], yr, a_pace, a_name)
	for r in plan.get("renames", []):
		_rebrand(str(r["id"]), r["spec"], yr, -1.0, "")
	for spec in plan.get("enters", []):
		_add_team(spec, yr)
	Game.field_plan = {}


static func _team_pace(tid: String) -> float:
	var t: Dictionary = Game.get_team(tid)
	return float(t.get("pace", 1.0)) + float(Game.dev_pace.get(tid, 0.0))


static func _remove_team(tid: String) -> void:
	for k in Game.drivers.keys():
		var d: Dictionary = Game.drivers[k]
		if d["team"] == tid:
			d["team"] = ""
			if d["status"] == "active":
				d["status"] = "free"
			d["contract"] = {}
	for i in range(Game.teams.size() - 1, -1, -1):
		if Game.teams[i]["id"] == tid:
			Game.teams.remove_at(i)
	Game.dev_pace.erase(tid)
	Game.team_points.erase(tid)
	Game.team_meta.erase(tid)
	DB.custom_teams.erase(tid)


## Team unter neuer ID weiterführen (Fahrer, Stärke, Entwicklung und Ansehen wandern mit). other_pace >= 0: Fusion mit dem Team other_name von dieser Stärke.
static func _rebrand(old_id: String, spec: Dictionary, yr: int, other_pace: float, other_name: String) -> void:
	var t: Dictionary = Game.get_team(old_id)
	if t.is_empty():
		return
	var new_id := str(spec["id"])
	var old_name := str(t["name"])
	var meta: Dictionary = Game.team_meta.get(old_id, {})
	var pace := float(t["pace"]) + float(Game.dev_pace.get(old_id, 0.0))
	var pts := float(Game.team_points.get(old_id, 0.0))
	if other_pace >= 0.0:
		pace = (pace * 2.0 + other_pace) / 3.0 + 0.002      # gebündelte Ressourcen
		meta["prestige"] = minf(1.0, float(meta.get("prestige", 0.3)) + 0.05)
	for k in Game.drivers.keys():
		var d: Dictionary = Game.drivers[k]
		if d["team"] == old_id:
			d["team"] = new_id
	t["id"] = new_id
	t["name"] = str(spec["name"])
	t["pace"] = pace
	t["color"] = DB.team_color(new_id)
	Game.dev_pace.erase(old_id)
	Game.dev_pace[new_id] = 0.0
	Game.team_points.erase(old_id)
	Game.team_points[new_id] = pts
	Game.team_meta.erase(old_id)
	meta["renamed"] = yr
	meta["formerly"] = old_name if other_name == "" else "%s und %s" % [old_name, other_name]
	Game.team_meta[new_id] = meta
	if DB.custom_teams.has(old_id):
		DB.custom_teams.erase(old_id)


static func _add_team(spec: Dictionary, yr: int) -> void:
	var worst := 9.0
	for t in Game.teams:
		worst = minf(worst, float(t["pace"]) + float(Game.dev_pace.get(str(t["id"]), 0.0)))
	var id := str(spec["id"])
	if not DB.custom_teams.has(id):
		DB.register_team(spec)
	Game.teams.append(DB.new_team(id, str(spec["name"]), worst - 0.004, NEW_MECH))
	Game.dev_pace[id] = 0.0
	Game.team_points[id] = 0.0
	var n: int = Game.teams.size()
	Game.team_meta[id] = {"prestige": 0.10, "last_rank": n - 1, "score": 0.05, "pace_rank": n - 1, "since": yr, "bottom": 0, "fresh": true, "formerly": ""}
	Game.field_last_entry = yr


# ------------------------------------------------------------------ Saisonstart

## Nach dem Wechsel in die neue Saison: Neueinsteiger bekommen ihre schwache Anfangsstärke (nicht zum Mittelwert gezogen),
## Defektanfälligkeit der Neuen sinkt mit jedem Jahr. Aufruf in _advance_year nach der Stärke-Durchmischung.
static func settle_newcomers() -> void:
	var worst := 9.0
	for t in Game.teams:
		if not bool(Game.team_meta.get(str(t["id"]), {}).get("fresh", false)):
			worst = minf(worst, float(t["pace"]))
	for t in Game.teams:
		var meta: Dictionary = Game.team_meta.get(str(t["id"]), {})
		if bool(meta.get("fresh", false)):
			t["pace"] = worst - 0.003 - Game.rng.randf() * 0.002
			meta["fresh"] = false
		elif int(meta.get("since", 0)) > 0 and Game.year > int(meta["since"]):
			t["mech_rate"] = maxf(MECH_FLOOR, float(t.get("mech_rate", MECH_FLOOR)) * 0.78)


## Meldung zum Saisonstart, wenn sich das Feld verändert hat.
static func season_start_news() -> void:
	var fresh: Array = []
	var renamed: Array = []
	for t in Game.teams:
		var meta: Dictionary = Game.team_meta.get(str(t["id"]), {})
		if int(meta.get("since", 0)) == Game.year:
			fresh.append(str(t["name"]))
		elif int(meta.get("renamed", 0)) == Game.year:
			renamed.append(str(t["name"]))
	if fresh.is_empty() and renamed.is_empty() and not cond("exit"):
		return
	var txt := "Das Feld %d: %d Teams am Start." % [Game.year, Game.teams.size()]
	if not fresh.is_empty():
		txt += " Neu dabei: %s." % ", ".join(fresh)
	if not renamed.is_empty():
		txt += " Neu aufgestellt: %s." % ", ".join(renamed)
	Market.news("field", txt)


# ------------------------------------------------------------------ Anzeige

## Kurzer Hinweis zur Teamgeschichte (leer, wenn das Team schon immer da war).
static func team_note(tid: String) -> String:
	var meta: Dictionary = Game.team_meta.get(tid, {})
	var since := int(meta.get("since", 0))
	var renamed := int(meta.get("renamed", 0))
	if renamed > 0 and Game.year - renamed <= 2:
		return "früher %s (seit %d)" % [str(meta.get("formerly", "?")), renamed]
	if since > 0 and Game.year - since <= 2:
		return "Neueinsteiger seit %d" % since
	return ""


static func is_new_this_year(tid: String) -> bool:
	var meta: Dictionary = Game.team_meta.get(tid, {})
	return int(meta.get("since", 0)) == Game.year or int(meta.get("renamed", 0)) == Game.year


## Bedingungen für Meldungen aus der Zentrale (career.gd): "exit" = ein Team ist dieses Jahr weggefallen, "enter" = ein Neueinsteiger ist dabei.
static func cond(name: String) -> bool:
	for e in Game.field_log:
		if int(e["year"]) != Game.year:
			continue
		if name == "exit" and str(e["kind"]) in ["team_out", "team_merge"]:
			return true
		if name == "enter" and str(e["kind"]) == "team_in":
			return true
	return false


## Angekündigte Änderungen fürs nächste Jahr als Textzeilen (Fahrermarkt).
static func plan_lines() -> Array:
	var out: Array = []
	var plan: Dictionary = Game.field_plan
	for tid in plan.get("exits", []):
		out.append("Rückzug: %s" % _team_name(str(tid)))
	for m in plan.get("merges", []):
		out.append("Fusion: %s und %s werden zu %s" % [_team_name(str(m["into"])), _team_name(str(m["gone"])), str(m["spec"]["name"])])
	for r in plan.get("renames", []):
		out.append("Umbenennung: %s wird zu %s" % [_team_name(str(r["id"])), str(r["spec"]["name"])])
	for spec in plan.get("enters", []):
		out.append("Neues Team: %s" % str(spec["name"]))
	return out


## Nach dem Laden aus JSON: Jahreszahlen im Plan und in der Chronik sind Ganzzahlen.
static func normalize_loaded() -> void:
	for e in Game.field_log:
		e["year"] = int(e["year"])
	var plan: Dictionary = Game.field_plan
	if plan.is_empty():
		return
	plan["year"] = int(plan.get("year", Game.year + 1))
	var specs: Array = []
	for spec in plan.get("enters", []):
		specs.append(spec)
	for m in plan.get("merges", []):
		specs.append(m["spec"])
	for r in plan.get("renames", []):
		specs.append(r["spec"])
	for sp in specs:
		sp["founded"] = int(sp["founded"])
		sp["titles"] = int(sp["titles"])

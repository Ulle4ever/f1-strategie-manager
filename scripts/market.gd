extends RefCounted
## Fahrermarkt: Verträge, Zufriedenheit, Alterung, Verhandlungen und KI-Transfers.
## Alle Funktionen sind statisch und arbeiten auf dem Spielstand im Autoload "Game" (drivers, news, team_meta ...).
##
## Vertrag:  {"salary": Mio.$/Jahr, "end": letztes Vertragsjahr, "role": "n1"|"n2"|"eq", "option": Teamoption (+1 Jahr),
##            "exit_rank": 0 oder Konstrukteurs-Platz, ab dem der Fahrer das Team ohne Ablöse verlassen darf}
## Status:   "active" (hat Cockpit/Vertrag), "free" (vertragslos), "rookie" (Nachwuchs), "future" (noch nicht sichtbar), "retired"

const POOL_PATH := "res://data/driver_pool.json"
const SEATS := 2
const CAP_DEV_RESERVE := 25.0   # so viel Spielraum der Kostenobergrenze bleibt mindestens für Entwicklung
const NAMES := {
	"British": [["Oliver", "Jack", "Harry", "Ethan", "Callum", "Theo"], ["Hartley", "Ellis", "Brooks", "Whitfield", "Marlow", "Pryce"]],
	"German": [["Felix", "Lukas", "Jonas", "Maximilian", "Leon", "Tim"], ["Brandt", "Keller", "Vogt", "Hartmann", "Reuter", "Sommer"]],
	"French": [["Hugo", "Lucas", "Theo", "Nathan", "Mathis", "Enzo"], ["Dubois", "Lambert", "Fournier", "Girard", "Moreau", "Rochet"]],
	"Italian": [["Matteo", "Luca", "Marco", "Tommaso", "Gabriele", "Andrea"], ["Rinaldi", "Ferrante", "Moretti", "Calvi", "Bellini", "Gentile"]],
	"Spanish": [["Pablo", "Alvaro", "Hugo", "Diego", "Mario", "Sergio"], ["Navarro", "Ortega", "Castillo", "Ibarra", "Salazar", "Quintero"]],
	"Brazilian": [["Gabriel", "Rafael", "Caio", "Lucas", "Bruno", "Felipe"], ["Almeida", "Teixeira", "Barbosa", "Cardoso", "Moura", "Siqueira"]],
	"Dutch": [["Daan", "Sem", "Milan", "Thijs", "Luuk", "Bram"], ["de Boer", "Verhoeven", "van Dijk", "Smit", "Mulder", "Bakker"]],
	"Japanese": [["Ren", "Haruto", "Sota", "Kaito", "Yuma", "Riku"], ["Sakamoto", "Fujita", "Hasegawa", "Ishikawa", "Mori", "Takeda"]],
	"Australian": [["Jack", "Cooper", "Mitchell", "Riley", "Lachlan", "Kai"], ["Whitaker", "Gallagher", "Sutton", "Kendall", "Holloway", "Barrett"]],
	"American": [["Tyler", "Mason", "Logan", "Cole", "Wyatt", "Dylan"], ["Hayes", "Sullivan", "Prescott", "Dawson", "Maddox", "Reed"]],
	"Finnish": [["Eetu", "Onni", "Aatu", "Veeti", "Elias", "Leevi"], ["Korhonen", "Lahti", "Salmi", "Rantanen", "Virtanen", "Niemi"]],
	"Mexican": [["Diego", "Santiago", "Mateo", "Emiliano", "Joaquin", "Ruben"], ["Herrera", "Montoya", "Vargas", "Rivas", "Zamora", "Cabrera"]],
}
const ROLE_NAMES := {"n1": "Nummer 1", "n2": "Nummer 2", "eq": "Gleichberechtigt"}

## Bekannte Charakterzüge (Annäherungen): tyre = Reifenschonung, wet = Regenstärke, aggr = Aggressivität,
## obey = Gehorsam bei Teamorder, start = Startstärke, cons = Konstanz. Alle Werte -1..1 bzw. 0..1; Rest wird zufällig aus der ID erzeugt.
const TRAIT_TABLE := {
	"hamilton": {"tyre": 0.5, "wet": 0.85, "aggr": 0.6, "obey": 0.6, "start": 0.2, "cons": 0.85},
	"max_verstappen": {"tyre": 0.1, "wet": 0.9, "aggr": 0.95, "obey": 0.3, "start": 0.5, "cons": 0.8},
	"alonso": {"tyre": 0.45, "wet": 0.75, "aggr": 0.85, "obey": 0.4, "start": 0.7, "cons": 0.9},
	"vettel": {"tyre": 0.2, "wet": 0.5, "aggr": 0.6, "obey": 0.45, "start": 0.85, "cons": 0.8},
	"michael_schumacher": {"tyre": 0.5, "wet": 0.95, "aggr": 0.85, "obey": 0.7, "start": 0.7, "cons": 0.95},
	"button": {"tyre": 1.0, "wet": 0.8, "aggr": 0.3, "obey": 0.8, "start": 0.0, "cons": 0.7},
	"raikkonen": {"tyre": 0.2, "wet": 0.3, "aggr": 0.5, "obey": 0.5, "start": 0.2, "cons": 0.6},
	"rosberg": {"tyre": 0.4, "wet": 0.3, "aggr": 0.5, "obey": 0.6, "start": 0.3, "cons": 0.85},
	"bottas": {"tyre": 0.2, "wet": 0.0, "aggr": 0.35, "obey": 0.95, "start": 0.7, "cons": 0.75},
	"massa": {"tyre": -0.1, "wet": -0.2, "aggr": 0.55, "obey": 0.95, "start": 0.3, "cons": 0.55},
	"ricciardo": {"tyre": -0.1, "wet": 0.3, "aggr": 0.9, "obey": 0.6, "start": 0.4, "cons": 0.7},
	"leclerc": {"tyre": -0.4, "wet": 0.3, "aggr": 0.7, "obey": 0.7, "start": 0.2, "cons": 0.6},
	"sainz": {"tyre": 0.5, "wet": 0.1, "aggr": 0.6, "obey": 0.75, "start": 0.3, "cons": 0.8},
	"norris": {"tyre": 0.3, "wet": 0.4, "aggr": 0.55, "obey": 0.7, "start": 0.2, "cons": 0.75},
	"piastri": {"tyre": 0.3, "wet": 0.3, "aggr": 0.5, "obey": 0.6, "start": 0.4, "cons": 0.85},
	"russell": {"tyre": 0.1, "wet": 0.6, "aggr": 0.6, "obey": 0.7, "start": 0.2, "cons": 0.8},
	"perez": {"tyre": 0.95, "wet": 0.0, "aggr": 0.5, "obey": 0.95, "start": 0.3, "cons": 0.5},
	"ocon": {"tyre": 0.0, "wet": 0.2, "aggr": 0.85, "obey": 0.35, "start": 0.2, "cons": 0.6},
	"gasly": {"tyre": 0.0, "wet": 0.1, "aggr": 0.7, "obey": 0.6, "start": 0.2, "cons": 0.6},
	"hulkenberg": {"tyre": 0.1, "wet": 0.6, "aggr": 0.5, "obey": 0.6, "start": 0.2, "cons": 0.7},
	"kevin_magnussen": {"tyre": -0.2, "wet": 0.0, "aggr": 1.0, "obey": 0.3, "start": 0.3, "cons": 0.5},
	"webber": {"tyre": 0.1, "wet": 0.2, "aggr": 0.7, "obey": 0.3, "start": -0.1, "cons": 0.7},
	"barrichello": {"tyre": 0.2, "wet": 0.6, "aggr": 0.4, "obey": 0.95, "start": 0.2, "cons": 0.75},
	"montoya": {"tyre": -0.3, "wet": 0.4, "aggr": 1.0, "obey": 0.35, "start": 0.4, "cons": 0.4},
	"coulthard": {"tyre": 0.2, "wet": 0.5, "aggr": 0.4, "obey": 0.85, "start": 0.2, "cons": 0.7},
	"trulli": {"tyre": -0.1, "wet": 0.2, "aggr": 0.4, "obey": 0.6, "start": 0.0, "cons": 0.6},
	"fisichella": {"tyre": 0.0, "wet": 0.4, "aggr": 0.55, "obey": 0.6, "start": 0.2, "cons": 0.6},
	"ralf_schumacher": {"tyre": 0.0, "wet": 0.2, "aggr": 0.6, "obey": 0.5, "start": 0.4, "cons": 0.5},
	"sato": {"tyre": -0.2, "wet": 0.0, "aggr": 0.9, "obey": 0.6, "start": 0.5, "cons": 0.4},
	"stroll": {"tyre": 0.0, "wet": 0.6, "aggr": 0.5, "obey": 0.8, "start": 0.4, "cons": 0.5},
	"tsunoda": {"tyre": -0.2, "wet": 0.0, "aggr": 0.85, "obey": 0.6, "start": 0.3, "cons": 0.5},
}

static var _pool_cache: Array = []


static func pool() -> Array:
	if _pool_cache.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(POOL_PATH))
		if typeof(d) == TYPE_ARRAY:
			_pool_cache = d
	return _pool_cache


# ------------------------------------------------------------------ Fahrerwerte

static func age_curve(age: int) -> float:
	if age <= 20:
		return -0.0012
	if age == 21:
		return -0.0009
	if age == 22:
		return -0.0006
	if age == 23:
		return -0.0004
	if age == 24:
		return -0.0002
	if age <= 31:
		return 0.0
	if age == 32:
		return -0.00015
	if age == 33:
		return -0.0003
	if age == 34:
		return -0.0005
	if age == 35:
		return -0.0007
	if age == 36:
		return -0.0009
	return -0.0009 - 0.0003 * float(age - 36)


static func age_of(d: Dictionary, year: int) -> int:
	return year - int(d["birth"])


static func rating_of(d: Dictionary) -> int:
	var s: float = float(d["skill"]) + 0.6 * float(d["qskill"])
	return clampi(int(round(72.0 + s * 10000.0)), 40, 99)


static func rating_color(r: int) -> Color:
	if r >= 90:
		return Color("9a3fe0")
	if r >= 80:
		return Color("12a15a")
	if r >= 70:
		return Color("4fa817")
	if r >= 60:
		return Color("d99a00")
	return Color("d9702a")


static func potential_of(d: Dictionary) -> int:
	var s: float = float(d["peak_s"]) + 0.6 * float(d["peak_q"])
	return maxi(clampi(int(round(72.0 + s * 10000.0)), 40, 99), rating_of(d))


static func demand(d: Dictionary) -> float:
	var r := float(rating_of(d))
	var base := 1.2 + 52.0 * pow(maxf(0.0, (r - 58.0) / 40.0), 2.4)
	var pot := float(potential_of(d))
	base += maxf(0.0, pot - r) * 0.18
	return clampf(base, 0.8, 68.0)


static func ask_salary(d: Dictionary) -> float:
	return demand(d) * (1.0 + float(d["greed"]))


static func ambition(d: Dictionary) -> float:
	return clampf((float(rating_of(d)) - 55.0) / 40.0, 0.0, 1.0)


static func stable_noise(id: String, year: int, salt: String) -> float:
	return float(absi((id + str(year) + salt).hash()) % 1000) / 1000.0


# ------------------------------------------------------------------ Fahrer anlegen

## Charakterzüge aus der ID (deterministisch) plus bekannte Werte der Tabelle; fiktive Fahrer: zufällig.
static func make_traits(id: String, fictional: bool = false) -> Dictionary:
	var r := RandomNumberGenerator.new()
	if fictional:
		r.randomize()
	else:
		r.seed = absi(id.hash()) + 7
	var t := {
		"tyre": clampf(r.randfn(0.0, 0.45), -1.0, 1.0), "wet": clampf(r.randfn(0.0, 0.45), -1.0, 1.0),
		"aggr": clampf(r.randfn(0.55, 0.25), 0.0, 1.0), "obey": clampf(r.randfn(0.68, 0.22), 0.05, 1.0),
		"start": clampf(r.randfn(0.1, 0.35), -1.0, 1.0), "cons": clampf(r.randfn(0.65, 0.18), 0.2, 1.0),
	}
	if TRAIT_TABLE.has(id):
		for k in TRAIT_TABLE[id].keys():
			t[k] = TRAIT_TABLE[id][k]
	return t


## Kurze Beschreibungen der auffälligsten Eigenschaften (für Anzeige).
static func trait_labels(d: Dictionary) -> Array:
	var t: Dictionary = d.get("traits", {})
	var out: Array = []
	if t.is_empty():
		return out
	if float(t["tyre"]) >= 0.5:
		out.append("Reifenschoner")
	elif float(t["tyre"]) <= -0.5:
		out.append("Reifenfresser")
	if float(t["wet"]) >= 0.5:
		out.append("Regenspezialist")
	elif float(t["wet"]) <= -0.5:
		out.append("Regenschwäche")
	if float(t["aggr"]) >= 0.78:
		out.append("Angreifer")
	elif float(t["aggr"]) <= 0.3:
		out.append("Vorsichtig")
	if float(t["obey"]) >= 0.85:
		out.append("Teamplayer")
	elif float(t["obey"]) <= 0.38:
		out.append("Egoist")
	if float(t["start"]) >= 0.5:
		out.append("Starkstarter")
	if float(t["cons"]) >= 0.85:
		out.append("Konstant")
	return out.slice(0, 3)


static func make_driver(p: Dictionary, year: int, status: String) -> Dictionary:
	var birth: int = int(str(p.get("dob", "1990-01-01")).substr(0, 4))
	var d := {
		"id": p["id"], "code": p["code"], "given": p["given"], "family": p["family"],
		"name": "%s %s" % [p["given"], p["family"]], "nat": p.get("nat", ""), "number": str(p.get("number", "0")),
		"birth": birth, "peak_s": float(p["peak_s"]), "peak_q": float(p["peak_q"]), "crash_rate": float(p["crash"]),
		"skill": 0.0, "qskill": 0.0, "team": "", "contract": {}, "status": status, "morale": 0.62,
		"loyalty": Game.rng.randf_range(0.2, 0.9), "greed": Game.rng.randf_range(0.0, 0.14),
		"agent": _agent_name(), "dowry": 0.0, "free_years": 0, "first": int(p.get("first", year)), "real": true,
		"traits": make_traits(str(p["id"])),
	}
	var age := year - birth
	# Form aus der echten Saison, sonst Karrierewert + Altersgang
	var found := false
	for s in p["seasons"]:
		if int(s["y"]) == year:
			d["skill"] = float(s["skill"])
			d["qskill"] = float(s["qskill"])
			d["crash_rate"] = float(s["crash"])
			found = true
	if not found:
		d["skill"] = float(p["peak_s"]) + age_curve(age) + Game.rng.randfn(0.0, 0.0003)
		d["qskill"] = float(p["peak_q"]) + Game.rng.randfn(0.0, 0.00015)
	_roll_dowry(d)
	return d


static func make_fictional(year: int) -> Dictionary:
	var nats: Array = NAMES.keys()
	var nat: String = nats[Game.rng.randi() % nats.size()]
	var gs: Array = NAMES[nat][0]
	var fs: Array = NAMES[nat][1]
	var given: String = gs[Game.rng.randi() % gs.size()]
	var family: String = fs[Game.rng.randi() % fs.size()]
	var age := Game.rng.randi_range(17, 21)
	var peak_s := Game.rng.randfn(-0.0002, 0.0013)
	var peak_q := Game.rng.randfn(-0.0001, 0.0006)
	var p := {"id": "fic_%d_%d" % [year, Game.rng.randi() % 100000], "code": family.substr(0, 3).to_upper(), "given": given, "family": family,
		"nat": nat, "number": "0", "dob": "%d-06-01" % (year - age), "peak_s": peak_s, "peak_q": peak_q,
		"crash": Game.rng.randf_range(0.05, 0.13), "seasons": [], "first": year}
	var d := make_driver(p, year, "rookie")
	d["real"] = false
	d["traits"] = make_traits(str(d["id"]), true)
	d["skill"] = peak_s + age_curve(age) + Game.rng.randfn(0.0, 0.0004)
	d["qskill"] = peak_q + Game.rng.randfn(0.0, 0.0002)
	return d


static func _agent_name() -> String:
	var a := ["Brandt & Partner", "Delta Management", "Apex Sports", "Rossi Agency", "Nordlicht Sport", "Grid Capital", "Vector Talent", "Meridian"]
	return a[Game.rng.randi() % a.size()]


static func _roll_dowry(d: Dictionary) -> void:
	# Bezahlfahrer: schwächere Fahrer bringen oft Sponsorgelder mit
	var r := rating_of(d)
	d["dowry"] = 0.0
	if r < 72 and Game.rng.randf() < 0.30:
		d["dowry"] = snappedf(Game.rng.randf_range(2.0, 12.0), 0.5)


static func unique_code(d: Dictionary) -> void:
	var used := {}
	for k in Game.drivers.keys():
		var o: Dictionary = Game.drivers[k]
		if o["id"] != d["id"] and o["status"] in ["active", "free", "rookie"]:
			used[o["code"]] = true
	var base: String = str(d["code"])
	var c := base
	var i := 0
	var fam: String = str(d["family"]).to_upper().replace(" ", "")
	while used.has(c) and i < 20:
		i += 1
		c = (fam.substr(0, 2) + fam.substr(fam.length() - i, 1)) if fam.length() > i + 2 else base.substr(0, 2) + str(i)
	d["code"] = c


# ------------------------------------------------------------------ Teamlage

## Aktualisiert Teamwertung (0..1) aus Entwicklungsstand, Tabelle und Ansehen.
static func refresh_scores() -> void:
	var n := Game.teams.size()
	var arr: Array = []
	for t in Game.teams:
		arr.append({"id": t["id"], "pace": float(t["pace"]) + float(Game.dev_pace.get(t["id"], 0.0))})
	arr.sort_custom(func(a, b): return a["pace"] > b["pace"])
	var cur_rank := {}
	var st: Array = Game.team_standings()
	for i in st.size():
		cur_rank[st[i]["id"]] = i
	for i in arr.size():
		var tid: String = arr[i]["id"]
		var meta: Dictionary = Game.team_meta.get(tid, {"prestige": 0.5, "last_rank": i})
		var pace_s := 1.0 - float(i) / maxf(1.0, float(n - 1))
		var last_s := 1.0 - float(meta["last_rank"]) / maxf(1.0, float(n - 1))
		if Game.round_index >= 5:
			var c_s := 1.0 - float(cur_rank.get(tid, i)) / maxf(1.0, float(n - 1))
			last_s = 0.5 * last_s + 0.5 * c_s
		meta["score"] = 0.55 * pace_s + 0.25 * last_s + 0.20 * float(meta["prestige"])
		meta["pace_rank"] = i
		Game.team_meta[tid] = meta


static func team_score(tid: String) -> float:
	return float(Game.team_meta.get(tid, {}).get("score", 0.5))


static func pay_budget(tid: String) -> float:
	return 22.0 + 95.0 * pow(team_score(tid), 1.3)


static func next_year() -> int:
	return Game.year + 1


static func valid_next(d: Dictionary) -> bool:
	return d["team"] != "" and d["status"] == "active" and int(d["contract"].get("end", 0)) >= next_year()


static func next_drivers(tid: String) -> Array:
	var out: Array = []
	for k in Game.drivers.keys():
		var d: Dictionary = Game.drivers[k]
		if d["team"] == tid and valid_next(d):
			out.append(d)
	return out


static func open_seats(tid: String) -> int:
	if Game.is_leaving(tid):
		return 0      # Team steigt aus: keine neuen Fahrer
	return SEATS - next_drivers(tid).size()


static func payroll_next(tid: String) -> float:
	var s := 0.0
	for d in next_drivers(tid):
		s += float(d["contract"]["salary"])
	return s


static func current_drivers(tid: String) -> Array:
	var out: Array = []
	for k in Game.drivers.keys():
		var d: Dictionary = Game.drivers[k]
		if d["team"] == tid and d["status"] == "active":
			out.append(d)
	out.sort_custom(func(a, b): return rating_of(a) > rating_of(b))
	return out


static func partner_rating(tid: String, d: Dictionary) -> int:
	var best := 0
	for o in next_drivers(tid):
		if o["id"] != d["id"]:
			best = maxi(best, rating_of(o))
	return best


# ------------------------------------------------------------------ Bewertung eines Angebots

## Nutzen eines Angebots für den Fahrer. Rückgabe: {"u", "need", "parts", "dem"}.
static func evaluate(d: Dictionary, tid: String, offer: Dictionary) -> Dictionary:
	var a := ambition(d)
	var yr := next_year()
	var dem := ask_salary(d)
	var salary: float = maxf(float(offer["salary"]), 0.1)
	var t_term := team_score(tid) * (20.0 + 50.0 * a)
	var bw := 30.0 - 10.0 * a
	var pay_term := clampf(bw * log(salary / dem) / log(2.0), -45.0, 30.0)
	var role_term := 0.0
	var partner := partner_rating(tid, d)
	var me := rating_of(d)
	match str(offer.get("role", "eq")):
		"n1":
			role_term = 12.0 * a
			if me < partner - 2:
				role_term -= 6.0 * a
		"n2":
			role_term = -14.0 * a
		_:
			if me < partner - 6:
				role_term = -3.0 * a
	var loyal_term := 0.0
	if d["team"] == tid:
		loyal_term = 14.0 * float(d["loyalty"])
	var other := 0.0
	if int(offer.get("exit_rank", 0)) > 0:
		other += 3.0 + 4.0 * a
	if bool(offer.get("option", false)):
		other -= 2.0 + 3.0 * a
	var years := int(offer.get("years", 2))
	if age_of(d, yr) < 25:
		other += 1.5 * float(mini(years, 3) - 1)
	elif a > 0.7 and years > 2:
		other -= 2.0 * float(years - 2)
	other += (stable_noise(str(d["id"]), yr, "u") - 0.5) * 8.0
	# Stimmung: wer unzufrieden ist, wechselt leichter; zufriedene bleiben eher
	if d["team"] == tid:
		other += (float(d["morale"]) - 0.5) * 16.0
	elif d["team"] != "":
		other -= (float(d["morale"]) - 0.5) * 8.0
	var total := t_term + pay_term + role_term + loyal_term + other
	var need := (20.0 + 50.0 * a) * (0.15 + 0.55 * a)
	return {"u": total, "need": need, "dem": dem, "bw": bw,
		"parts": {"team": t_term, "pay": pay_term, "role": role_term, "loyal": loyal_term, "other": other}}


## Wie gut könnte der Fahrer woanders unterkommen? (bestes Angebot eines KI-Teams mit freiem Cockpit)
static func rival_utility(d: Dictionary, exclude_tid: String) -> Dictionary:
	var best := -999.0
	var best_t := ""
	var n := 0
	for t in Game.teams:
		var tid: String = t["id"]
		if tid == exclude_tid or tid == Game.team_id:
			continue
		if open_seats(tid) <= 0:
			continue
		var offer := {"salary": ask_salary(d), "years": 2, "role": "eq", "option": false, "exit_rank": 0}
		if ask_salary(d) - 0.7 * float(d["dowry"]) > (pay_budget(tid) - payroll_next(tid)) / float(open_seats(tid)) * 1.15:
			continue
		var e := evaluate(d, tid, offer)
		if e["u"] >= e["need"]:
			n += 1
			if e["u"] > best:
				best = e["u"]
				best_t = tid
	return {"u": best, "team": best_t, "count": n}


## Antwort eines Fahrers auf ein Angebot des Spielers. Verändert nichts.
static func respond(d: Dictionary, offer: Dictionary) -> Dictionary:
	var tid := Game.team_id
	var res := {"status": "reject", "reason": "", "counter": 0.0, "fee": 0.0, "buyout": 0.0, "u": 0.0, "need": 0.0, "rival": -999.0, "rival_count": 0}
	if d["status"] == "retired":
		res["reason"] = "Hat seine Karriere beendet."
		return res
	var mine: bool = d["team"] == tid
	var fee := agent_fee(d, offer)
	res["fee"] = fee
	# Cockpit verfügbar?
	var seats_used := 0
	for o in next_drivers(tid):
		if o["id"] != d["id"]:
			seats_used += 1
	if seats_used >= SEATS:
		res["reason"] = "Kein freies Cockpit für nächste Saison. Erst einen Vertrag auflösen."
		return res
	if mine and int(d["contract"].get("end", 0)) > next_year():
		res["reason"] = "Vertrag läuft noch bis %d." % int(d["contract"]["end"])
		return res
	# Kostenobergrenze
	var payroll_after := payroll_next(tid) + float(offer["salary"]) - (float(d["contract"]["salary"]) if mine and valid_next(d) else 0.0)
	if payroll_after > Game.cap - CAP_DEV_RESERVE:
		res["reason"] = "Passt nicht unter die Kostenobergrenze (Gehälter %.0f von %.0f, mindestens %.0f müssen für die Entwicklung bleiben)." % [payroll_after, Game.cap, CAP_DEV_RESERVE]
		return res
	if fee > Game.budget:
		res["reason"] = "Das Budget reicht nicht für die Beraterprovision (%.1f Mio.)." % fee
		return res
	# Fahrer unter Vertrag bei anderem Team: Ablöse
	if valid_next(d) and not mine:
		var c: Dictionary = d["contract"]
		var free_exit: bool = int(c.get("exit_rank", 0)) > 0 and Game.final_rank(str(d["team"])) > int(c["exit_rank"])
		if not free_exit:
			var yrs_left := int(c["end"]) - Game.year
			var buyout := float(c["salary"]) * float(yrs_left) * 0.6 + 2.0
			res["buyout"] = buyout
			if buyout > Game.budget - fee:
				res["reason"] = "Die Ablöse (%.1f Mio.) ist zu hoch für dein Budget." % buyout
				return res
	var e := evaluate(d, tid, offer)
	var rv := rival_utility(d, str(d["team"]) if d["team"] != "" else "")
	res["u"] = e["u"]
	res["rival"] = rv["u"]
	res["rival_count"] = rv["count"]
	var target := maxf(float(e["need"]), float(rv["u"]) - 2.0)
	if valid_next(d) and not mine:
		# Fahrer muss sich klar verbessern, sonst bleibt er bei seinem Team
		var cur_offer := {"salary": float(d["contract"]["salary"]), "years": 2, "role": d["contract"].get("role", "eq"), "option": false, "exit_rank": 0}
		var cur := evaluate(d, str(d["team"]), cur_offer)
		target = maxf(target, float(cur["u"]) + 8.0)
	res["need"] = target
	if e["u"] >= target:
		res["status"] = "accept"
		return res
	var gap: float = target - float(e["u"])
	var mult := pow(2.0, gap / float(e["bw"]))
	var pay_need: float = float(e["parts"]["pay"]) + gap
	if mult <= 3.2 and pay_need <= 29.0 and float(offer["salary"]) * mult < 70.0:
		var cs := snappedf(float(offer["salary"]) * mult * 1.02, 0.1)
		if payroll_after - float(offer["salary"]) + cs > Game.cap - CAP_DEV_RESERVE:
			res["reason"] = "Er verlangt %.1f Mio. $, das sprengt die Kostenobergrenze." % cs
			return res
		if cs > Game.budget * 1.5 + 20.0:
			res["reason"] = "Er verlangt %.1f Mio. $ pro Jahr, das kann sich dein Team nicht leisten." % cs
			return res
		res["status"] = "counter"
		res["counter"] = cs
		res["reason"] = "Er will mehr Geld: %.1f Mio. $ pro Jahr." % cs
		return res
	# Ablehnungsgrund: größter Defizit-Posten
	var p: Dictionary = e["parts"]
	var a := ambition(d)
	if p["team"] < (20.0 + 50.0 * a) * 0.35 and a > 0.45:
		res["reason"] = "Dein Team ist ihm sportlich nicht stark genug."
	elif p["role"] < -4.0:
		res["reason"] = "Er will nicht Nummer 2 sein."
	elif rv["u"] > e["u"] and rv["team"] != "":
		res["reason"] = "Ein anderes Team bietet ihm mehr (%s)." % Game.get_team(str(rv["team"])).get("name", "?")
	else:
		res["reason"] = "Das Angebot reicht nicht aus."
	return res


static func agent_fee(d: Dictionary, offer: Dictionary) -> float:
	return snappedf(float(offer["salary"]) * (0.04 + 0.5 * float(d["greed"]) * 0.2) * minf(2.0, float(offer.get("years", 2))), 0.1)


# ------------------------------------------------------------------ Verträge ausführen

static func new_contract(offer: Dictionary) -> Dictionary:
	return {"salary": snappedf(float(offer["salary"]), 0.1), "end": next_year() + int(offer.get("years", 2)) - 1,
		"role": str(offer.get("role", "eq")), "option": bool(offer.get("option", false)), "exit_rank": int(offer.get("exit_rank", 0))}


static func sign_player(d: Dictionary, offer: Dictionary, res: Dictionary) -> void:
	var old_team: String = str(d["team"])
	Game.budget -= float(res["fee"]) + float(res["buyout"])
	Game.cap_spent_fees += float(res["fee"])
	if float(res["buyout"]) > 0.0 and old_team != "" and old_team != Game.team_id:
		news("transfer", "%s wechselt für %.1f Mio. Ablöse von %s zu %s." % [d["name"], res["buyout"], Game.get_team(old_team).get("name", "?"), Game.player_team()["name"]])
	var extension: bool = old_team == Game.team_id
	d["team"] = Game.team_id
	d["status"] = "active"
	d["contract"] = new_contract(offer)
	d["free_years"] = 0
	if extension:
		news("extension", "%s verlängert bei %s bis %d (%.1f Mio. $)." % [d["name"], Game.player_team()["name"], int(d["contract"]["end"]), float(d["contract"]["salary"])])
	else:
		news("signing", "%s unterschreibt bei %s bis %d (%.1f Mio. $)." % [d["name"], Game.player_team()["name"], int(d["contract"]["end"]), float(d["contract"]["salary"])])
	d["morale"] = clampf(float(d["morale"]) + 0.08, 0.0, 1.0)
	unique_code(d)


## Option ziehen (Vertrag um ein Jahr zu gleichen Bedingungen verlängern).
static func exercise_option(d: Dictionary) -> bool:
	if d["team"] != Game.team_id or not bool(d["contract"].get("option", false)):
		return false
	if int(d["contract"]["end"]) > next_year():
		return false
	if payroll_next(Game.team_id) + float(d["contract"]["salary"]) > Game.cap - CAP_DEV_RESERVE:
		return false
	d["contract"]["end"] = int(d["contract"]["end"]) + 1
	d["contract"]["option"] = false
	news("extension", "%s: Teamoption gezogen, Vertrag bei %s bis %d." % [d["name"], Game.player_team()["name"], int(d["contract"]["end"])])
	return true


## Vertrag auflösen. Kosten: ein Großteil des restlichen Gehalts.
static func release_player_driver(d: Dictionary) -> float:
	var left := maxi(0, int(d["contract"]["end"]) - Game.year)
	var cost := snappedf(float(d["contract"]["salary"]) * float(left) * 0.7, 0.1)
	if cost > Game.budget:
		return -1.0
	Game.budget -= cost
	d["team"] = ""
	d["status"] = "free"
	d["contract"] = {}
	news("release", "%s wurde von %s freigestellt (Abfindung %.1f Mio. $)." % [d["name"], Game.player_team()["name"], cost])
	return cost


# ------------------------------------------------------------------ Nachrichten

static func news(kind: String, text: String) -> void:
	Game.news.push_front({"year": Game.year, "round": Game.round_index, "kind": kind, "text": text})
	if Game.news.size() > 160:
		Game.news.resize(160)
	if Game.market_open:
		Game.market_log.push_front({"kind": kind, "text": text})


static func team_name(tid: String) -> String:
	return str(Game.get_team(tid).get("name", tid))


# ------------------------------------------------------------------ Zufriedenheit

## Nach jedem Rennen: Stimmung aller Fahrer anpassen. rows: Ergebnisliste aus Game.finish_race.
static func update_morale(rows: Array) -> void:
	refresh_scores()
	for r in rows:
		var d: Dictionary = {}
		for k in Game.drivers.keys():
			var o: Dictionary = Game.drivers[k]
			if o["code"] == r["code"] and o["team"] == r["team_id"] and o["status"] == "active":
				d = o
				break
		if d.is_empty():
			continue
		var tid: String = r["team_id"]
		var expected := 1.0 + 2.0 * float(Game.team_meta.get(tid, {}).get("pace_rank", 5)) + 0.5
		var actual := float(r["pos"])
		var perf := clampf(0.5 + (expected - actual) / 14.0, 0.0, 1.0)
		if int(r["state"]) == 3:
			perf = 0.30
		var m: float = d["morale"]
		m += 0.09 * (perf - m)
		# Teamkollege geschlagen?
		var mate = null
		for o in Game.drivers.values():
			if o["team"] == tid and o["status"] == "active" and o["id"] != d["id"]:
				mate = o
		if mate != null:
			for r2 in rows:
				if r2["code"] == mate["code"] and r2["team_id"] == tid:
					if int(r["pos"]) < int(r2["pos"]):
						m += 0.012
					else:
						m -= 0.012
		var c: Dictionary = d["contract"]
		if not c.is_empty():
			m += (float(c["salary"]) / ask_salary(d) - 1.0) * 0.004
			var a := ambition(d)
			if c["role"] == "n2":
				m -= 0.006 * a
			elif c["role"] == "n1":
				m += 0.003 * a
		d["morale"] = clampf(m, 0.0, 1.0)


# ------------------------------------------------------------------ Karrierebeginn

## Fahrerbestand für eine neue Karriere aufbauen (Startaufstellung + Pool).
static func init_career(year: int) -> void:
	Game.drivers = {}
	Game.news = []
	Game.market_log = []
	Game.market_open = false
	Game.season_log = []
	var on_grid := {}
	for t in Game.teams:
		for sd in t["drivers"]:
			on_grid[sd["id"]] = t["id"]
	for p in pool():
		var pid: String = p["id"]
		var d: Dictionary
		if on_grid.has(pid):
			d = make_driver(p, year, "active")
			d["team"] = on_grid[pid]
		elif int(p["first"]) > year:
			d = make_driver(p, year, "future")
		elif int(p["last"]) >= year - 1:
			d = make_driver(p, year, "free")
			if year - d["birth"] > 41:
				d["status"] = "retired"
		else:
			continue
		Game.drivers[pid] = d
	refresh_scores_initial()
	# Verträge für die Startaufstellung
	for t in Game.teams:
		var ds: Array = []
		for k in Game.drivers.keys():
			if Game.drivers[k]["team"] == t["id"]:
				ds.append(Game.drivers[k])
		ds.sort_custom(func(a, b): return rating_of(a) > rating_of(b))
		for i in ds.size():
			var d: Dictionary = ds[i]
			var r := Game.rng.randf()
			var extra := 0
			if r > 0.35:
				extra = 1
			if r > 0.65:
				extra = 2
			if r > 0.85:
				extra = 3
			var role := "eq"
			if ds.size() > 1:
				var diff := rating_of(ds[0]) - rating_of(ds[1])
				if diff >= 5:
					role = "n1" if i == 0 else "n2"
			var exit_rank := 0
			if rating_of(d) >= 84 and Game.rng.randf() < 0.55:
				exit_rank = clampi(int(Game.team_meta[t["id"]]["pace_rank"]) + 4, 2, Game.teams.size())
			d["contract"] = {"salary": snappedf(demand(d) * Game.rng.randf_range(0.8, 1.15), 0.1), "end": year + extra, "role": role,
				"option": Game.rng.randf() < 0.25, "exit_rank": exit_rank}
			d["morale"] = 0.62
	for t in Game.teams:
		Game.team_meta[t["id"]]["last_rank"] = int(Game.team_meta[t["id"]]["pace_rank"])
	for k in Game.drivers.keys():
		unique_code(Game.drivers[k])
	Game.sync_teams()


static func refresh_scores_initial() -> void:
	var arr: Array = Game.teams.duplicate()
	arr.sort_custom(func(a, b): return float(a["pace"]) > float(b["pace"]))
	Game.team_meta = {}
	for i in arr.size():
		var s := 1.0 - float(i) / maxf(1.0, float(arr.size() - 1))
		Game.team_meta[arr[i]["id"]] = {"prestige": s, "last_rank": i, "score": s, "pace_rank": i}


# ------------------------------------------------------------------ Saisonende / Marktphase

## Marktphase eröffnen: Ausstiege, Rücktritte, KI-Verlängerungen, Nachwuchs.
static func open_market() -> void:
	Game.market_open = true
	Game.market_log = []
	var yr := Game.year
	# Endstand merken
	var st: Array = Game.team_standings()
	for i in st.size():
		Game.team_meta[st[i]["id"]]["last_rank"] = i
		Game.team_meta[st[i]["id"]]["prestige"] = 0.8 * float(Game.team_meta[st[i]["id"]]["prestige"]) + 0.2 * (1.0 - float(i) / maxf(1.0, float(st.size() - 1)))
	refresh_scores()
	# Teamfeld des nächsten Jahres: Neueinsteiger, Rückzüge, Fusionen (vor den Vertragsverlängerungen der KI)
	Game.plan_field()
	# Ausstiegsklauseln
	for k in Game.drivers.keys():
		var d: Dictionary = Game.drivers[k]
		if d["status"] != "active" or d["team"] == "":
			continue
		var c: Dictionary = d["contract"]
		if int(c["end"]) > yr and int(c.get("exit_rank", 0)) > 0 and Game.final_rank(str(d["team"])) > int(c["exit_rank"]):
			if Game.rng.randf() < 0.85:
				news("exit", "%s zieht die Ausstiegsklausel und verlässt %s." % [d["name"], team_name(d["team"])])
				d["team"] = ""
				d["status"] = "free"
				d["contract"] = {}
	# Wechselwunsch (nur KI): unglückliche Fahrer werden abgegeben
	for k in Game.drivers.keys():
		var d: Dictionary = Game.drivers[k]
		if d["status"] == "active" and d["team"] != "" and d["team"] != Game.team_id and float(d["morale"]) < 0.30 and Game.rng.randf() < 0.6:
			news("release", "%s und %s gehen getrennte Wege." % [d["name"], team_name(d["team"])])
			d["team"] = ""
			d["status"] = "free"
			d["contract"] = {}
	# Rücktritte
	for k in Game.drivers.keys():
		var d: Dictionary = Game.drivers[k]
		if d["status"] in ["retired", "future"]:
			continue
		var age := age_of(d, yr + 1)
		var p := 0.0
		if age >= 34:
			p = 0.05 * float(age - 33)
		if age >= 40:
			p = 0.30
		if age >= 43:
			p = 0.7
		p *= 1.25 - 0.8 * ambition(d)
		if d["status"] != "active":
			p += 0.12 * float(d["free_years"])
			if rating_of(d) < 62:
				p += 0.1
		if rating_of(d) < 58 and age > 30:
			p += 0.25
		if Game.rng.randf() < p:
			if d["status"] == "active" or rating_of(d) > 66:
				news("retire", "%s (%d) beendet seine Karriere." % [d["name"], age])
			d["team"] = ""
			d["status"] = "retired"
			d["contract"] = {}
	# Nachwuchs freischalten (echte Debütanten im Folgejahr) + fiktive ab 2027
	for k in Game.drivers.keys():
		var d: Dictionary = Game.drivers[k]
		if d["status"] == "future" and int(d["first"]) <= yr + 1 and age_of(d, yr + 1) >= 17:
			d["status"] = "rookie"
			d["free_years"] = 0
			d["skill"] = float(d["peak_s"]) + age_curve(age_of(d, yr + 1)) + Game.rng.randfn(0.0, 0.0003)
			d["qskill"] = float(d["peak_q"]) + Game.rng.randfn(0.0, 0.00015)
			_roll_dowry(d)
			news("rookie", "Nachwuchstalent %s (%d, %s) ist verfügbar." % [d["name"], age_of(d, yr + 1), d["nat"]])
	if yr >= 2026:
		for i in 5:
			var f := make_fictional(yr)
			Game.drivers[f["id"]] = f
			unique_code(f)
			news("rookie", "Nachwuchstalent %s (%d, %s) ist verfügbar." % [f["name"], age_of(f, yr + 1), f["nat"]])
	# KI-Teams: auslaufende Verträge
	for t in Game.teams:
		var tid: String = t["id"]
		if tid == Game.team_id:
			continue
		for d in current_drivers(tid):
			if int(d["contract"]["end"]) > yr:
				continue
			_ai_resign(d, tid)
	# Spieler-Fahrer: Hinweise
	for d in current_drivers(Game.team_id):
		if int(d["contract"]["end"]) <= yr:
			news("info", "Dein Fahrer %s hat nur noch einen Vertrag bis Saisonende. Verlängere jetzt oder lass ihn ziehen." % d["name"])
		if float(d["morale"]) < 0.35:
			news("info", "%s ist unzufrieden und denkt über einen Wechsel nach." % d["name"])
	ai_poach()
	_generate_rumors(4)
	Game.save()


static func _ai_resign(d: Dictionary, tid: String) -> void:
	var yr := Game.year
	var c: Dictionary = d["contract"]
	if bool(c.get("option", false)):
		c["end"] = int(c["end"]) + 1
		c["option"] = false
		news("extension", "%s: %s zieht die Option, Vertrag bis %d." % [d["name"], team_name(tid), int(c["end"])])
		return
	var keep := 0.88
	var r := rating_of(d)
	var mates := current_drivers(tid)
	var best_mate := 0
	for o in mates:
		if o["id"] != d["id"]:
			best_mate = maxi(best_mate, rating_of(o))
	if r < 62 and age_of(d, yr + 1) > 31:
		keep -= 0.4
	if float(d["morale"]) < 0.40:
		keep -= 0.45
	if r < team_score(tid) * 40.0 + 55.0 - 12.0:
		keep -= 0.3
	if age_of(d, yr + 1) >= 37 and r < 85:
		keep -= 0.3
	if Game.rng.randf() < keep:
		var years := 1 + (Game.rng.randi() % 3)
		if age_of(d, yr + 1) >= 35:
			years = 1
		var sal := snappedf(ask_salary(d) * Game.rng.randf_range(0.95, 1.1), 0.1)
		if sal + payroll_next(tid) > pay_budget(tid) * 1.15:
			sal = snappedf(maxf(0.8, pay_budget(tid) * 1.1 - payroll_next(tid)), 0.1)
		d["contract"] = {"salary": sal, "end": yr + years, "role": c.get("role", "eq"), "option": Game.rng.randf() < 0.2, "exit_rank": 0}
		news("extension", "%s verlängert bei %s bis %d." % [d["name"], team_name(tid), yr + years])
	else:
		news("release", "%s verlässt %s." % [d["name"], team_name(tid)])
		d["team"] = ""
		d["status"] = "free"
		d["contract"] = {}


## Gerüchte: eine Mischung aus wahren und falschen Meldungen.
static func _generate_rumors(count: int) -> void:
	var cands: Array = []
	for k in Game.drivers.keys():
		var d: Dictionary = Game.drivers[k]
		if d["status"] == "retired" or d["status"] == "future":
			continue
		if rating_of(d) < 70:
			continue
		if d["status"] == "free" or (d["team"] != "" and int(d["contract"].get("end", 9999)) <= next_year()):
			cands.append(d)
	for i in range(cands.size() - 1, 0, -1):     # mischen mit Game.rng (nicht dem globalen Zufall), damit Prognosen reproduzierbar bleiben
		var j := Game.rng.randi() % (i + 1)
		var tmp = cands[i]
		cands[i] = cands[j]
		cands[j] = tmp
	var n := 0
	for d in cands:
		if n >= count:
			break
		var truth := Game.rng.randf() < 0.65
		var rv := rival_utility(d, str(d["team"]))
		var tid := ""
		if truth and rv["team"] != "":
			tid = rv["team"]
		else:
			var ids: Array = []
			for t in Game.teams:
				if t["id"] != d["team"] and not Game.is_leaving(str(t["id"])):
					ids.append(t["id"])
			tid = ids[Game.rng.randi() % ids.size()]
		var txt := "Gerücht: %s soll mit %s verhandeln." % [d["name"], team_name(tid)]
		if tid == Game.team_id:
			txt = "Gerücht: %s zeigt Interesse an deinem Team." % d["name"]
		news("rumor", txt)
		n += 1


## Gerüchte während der Saison (alle paar Rennen).
static func season_rumors() -> void:
	if Game.rng.randf() < 0.5:
		_generate_rumors(1)


## KI-Teams besetzen offene Cockpits. Reihenfolge nach Teamstärke.
static func ai_fill() -> void:
	refresh_scores()
	# Reihenfolge: starke Teams zuerst, mit etwas Zufall
	var order: Array = []
	for t in Game.teams:
		if t["id"] != Game.team_id:
			order.append({"id": t["id"], "k": team_score(t["id"]) + Game.rng.randfn(0.0, 0.05)})
	order.sort_custom(func(a, b): return a["k"] > b["k"])
	for pass_i in 3:
		for o in order:
			var tid: String = o["id"]
			var guard := 0
			while open_seats(tid) > 0 and guard < 3:
				guard += 1
				var pick := _pick_for_team(tid, pass_i >= 2)
				if pick.is_empty():
					break
				_sign_ai(pick["driver"], tid, pick)


static func _pick_for_team(tid: String, desperate: bool, poach: bool = false) -> Dictionary:
	var best: Dictionary = {}
	var best_v := -1e9
	var seats := open_seats(tid)
	var seat_budget := (pay_budget(tid) - payroll_next(tid)) / float(maxi(1, seats))
	for k in Game.drivers.keys():
		var d: Dictionary = Game.drivers[k]
		var buyout := 0.0
		if poach:
			# Abwerben: nur klares Gefälle zwischen den Teams; Spieler-Fahrer nur mit Klausel oder wenn unzufrieden
			if d["status"] != "active" or d["team"] == "" or d["team"] == tid or not valid_next(d):
				continue
			if team_score(tid) < team_score(d["team"]) + 0.2:
				continue
			var c: Dictionary = d["contract"]
			var free_exit: bool = int(c.get("exit_rank", 0)) > 0 and Game.final_rank(str(d["team"])) > int(c["exit_rank"])
			if d["team"] == Game.team_id and not free_exit and float(d["morale"]) >= 0.45:
				continue
			if not free_exit:
				buyout = float(c["salary"]) * float(int(c["end"]) - Game.year) * 0.6 + 2.0
			if buyout > pay_budget(tid) * 0.5:
				continue
		elif d["status"] not in ["free", "rookie"]:
			continue
		var ask := ask_salary(d) * Game.rng.randf_range(0.98, 1.04)
		var eff := ask - 0.7 * float(d["dowry"])
		var offer := {"salary": ask, "years": 2, "role": "eq", "option": false, "exit_rank": 0}
		if age_of(d, next_year()) < 25:
			offer["years"] = 3
		if eff > seat_budget * 1.1 and not desperate:
			continue
		var e := evaluate(d, tid, offer)
		var u: float = e["u"]
		if poach:
			var cur := evaluate(d, str(d["team"]), {"salary": float(d["contract"]["salary"]), "years": 2, "role": d["contract"].get("role", "eq"), "option": false, "exit_rank": 0})
			if u < float(cur["u"]) + 10.0:
				continue
		if u < float(e["need"]) and not desperate:
			var gap: float = float(e["need"]) - u
			var mult := pow(2.0, gap / float(e["bw"]))
			if mult > 1.4 or ask * mult - 0.7 * float(d["dowry"]) > seat_budget * 1.1:
				continue
			ask = ask * mult * 1.02
			offer["salary"] = ask
		var r := float(rating_of(d))
		var pot := float(potential_of(d))
		var young := age_of(d, next_year()) < 26
		var v := r + (0.6 * (pot - r) if young else 0.0) + 0.5 * float(d["dowry"]) - 8.0 * maxf(0.0, (ask - 0.7 * float(d["dowry"])) / maxf(seat_budget, 1.0) - 0.6)
		v += Game.rng.randfn(0.0, 1.5)
		if desperate:
			v = -ask
		if v > best_v:
			best_v = v
			best = {"driver": d, "offer": offer, "buyout": buyout}
	return best


## Starke Teams mit freiem Cockpit werben gelegentlich Fahrer anderer Teams ab.
static func ai_poach() -> void:
	refresh_scores()
	var order: Array = []
	for t in Game.teams:
		if t["id"] != Game.team_id:
			order.append({"id": t["id"], "k": team_score(t["id"])})
	order.sort_custom(func(a, b): return a["k"] > b["k"])
	for o in order:
		var tid: String = o["id"]
		if open_seats(tid) > 0 and Game.rng.randf() < 0.35:
			var pick := _pick_for_team(tid, false, true)
			if not pick.is_empty():
				_sign_ai(pick["driver"], tid, pick)


static func _sign_ai(d: Dictionary, tid: String, pick: Dictionary) -> void:
	var offer: Dictionary = pick["offer"]
	var old_team: String = str(d["team"])
	var buyout: float = pick["buyout"]
	if old_team != "" and buyout > 0.0:
		if old_team == Game.team_id:
			Game.budget += buyout
			news("poach", "%s wechselt zu %s. Du erhältst %.1f Mio. $ Ablöse." % [d["name"], team_name(tid), buyout])
		else:
			news("poach", "%s wechselt von %s zu %s (Ablöse %.1f Mio. $)." % [d["name"], team_name(old_team), team_name(tid), buyout])
	var role := "eq"
	var partner := partner_rating(tid, d)
	if rating_of(d) >= partner + 6:
		role = "n1"
	elif rating_of(d) <= partner - 6 and partner > 0:
		role = "n2"
	offer["role"] = role
	d["team"] = tid
	d["status"] = "active"
	d["contract"] = new_contract(offer)
	if age_of(d, next_year()) < 25:
		d["contract"]["end"] = next_year() + 2
	d["free_years"] = 0
	d["morale"] = 0.7
	if old_team == "":
		news("signing", "%s unterschreibt bei %s bis %d." % [d["name"], team_name(tid), int(d["contract"]["end"])])
	unique_code(d)


## Spieler hat nach Marktschluss ein offenes Cockpit: preiswerten Fahrer verpflichten.
static func auto_fill_player() -> void:
	if Game.team_id == "":
		return
	var guard := 0
	while open_seats(Game.team_id) > 0 and guard < 3:
		guard += 1
		var best: Dictionary = {}
		var best_v := -1e9
		for k in Game.drivers.keys():
			var d: Dictionary = Game.drivers[k]
			if d["status"] not in ["free", "rookie"]:
				continue
			var ask := ask_salary(d)
			var v := float(rating_of(d)) - ask * 1.2
			if v > best_v:
				best_v = v
				best = d
		if best.is_empty():
			return
		best["team"] = Game.team_id
		best["status"] = "active"
		best["contract"] = new_contract({"salary": ask_salary(best), "years": 1, "role": "eq"})
		news("signing", "Notlösung: %s fährt für dich (Vertrag bis %d)." % [best["name"], int(best["contract"]["end"])])
		unique_code(best)


## Marktschluss: nicht verlängerte Fahrer des Spielers gehen, KI besetzt die restlichen Cockpits.
static func close_market() -> void:
	var yr := Game.year
	for d in current_drivers(Game.team_id):
		if int(d["contract"]["end"]) <= yr:
			news("release", "%s verlässt dein Team." % d["name"])
			d["team"] = ""
			d["status"] = "free"
			d["contract"] = {}
	# Teamfeld umbauen (Rückzüge, Fusionen, Neueinsteiger), danach besetzt die KI die offenen Cockpits
	Game.apply_field_plan()
	# Alle anderen Teams: noch laufende Verträge bleiben, restliche Cockpits besetzen
	ai_fill()
	auto_fill_player()
	for k in Game.drivers.keys():
		var d: Dictionary = Game.drivers[k]
		if d["status"] in ["free", "rookie"]:
			d["free_years"] = int(d["free_years"]) + 1

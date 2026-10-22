extends RefCounted
## Pressekonferenz nach dem Rennen: ein bis zwei Fragen passend zum Ergebnis (Sieg, Podium, Ausfall, Duell der Teamkollegen,
## verpasstes Ziel, Sponsorwünsche). Die Antworten wirken auf die Stimmung der Fahrer (die wiederum das Tempo leicht beeinflusst),
## das Vertrauen des Vorstands und das Budget.
## Wirkung (fx): {"mood": {Fahrer-ID: Änderung}, "mood_all": x, "board": x, "budget": x}

const Market = preload("res://scripts/market.gd")


## Fahrer des Spielerteams mit ihrer Ergebniszeile: [{"d": Fahrerdaten, "row": Ergebniszeile}], bester zuerst.
static func team_rows(rows: Array) -> Array:
	var out: Array = []
	for d in Market.current_drivers(Game.team_id):
		for r in rows:
			if r["code"] == d["code"] and r["team_id"] == Game.team_id:
				out.append({"d": d, "row": r})
	out.sort_custom(func(a, b): return int(a["row"]["pos"]) < int(b["row"]["pos"]))
	return out


## Fragen für das letzte Rennen: [{"q", "who" (Reporter), "answers": [{"label", "hint", "fx"}]}]
static func questions(res: Dictionary) -> Array:
	var rows: Array = res.get("rows", [])
	var tr := team_rows(rows)
	if tr.is_empty():
		return []
	var out: Array = []
	var best: Dictionary = tr[0]
	var bpos := int(best["row"]["pos"])
	var bcode := str(best["d"]["code"])
	var bid := str(best["d"]["id"])
	var team := ""
	for t in Game.teams:
		if t["id"] == Game.team_id:
			team = str(t["name"])
	var dnf: Dictionary = {}
	for e in tr:
		if int(e["row"]["state"]) == 3:
			dnf = e
	var gr: Dictionary = res.get("goal", {})
	# 1) Hauptfrage
	if bpos == 1:
		out.append({"who": "Sky Sports", "q": "Sieg für %s! Ist %s jetzt ein Titelkandidat?" % [bcode, team], "answers": [
			{"label": "Wir bleiben auf dem Boden.", "hint": "Vorstand zufrieden (+), ruhige Stimmung", "fx": {"board": 1.5}},
			{"label": "Ja, wir wollen den Titel!", "hint": "Beide Fahrer motiviert (+), Vorstand begeistert (+), Erwartungen steigen", "fx": {"mood_all": 0.03, "board": 2.5}},
			{"label": "Das verdanken wir dem ganzen Team.", "hint": "Beide Fahrer fühlen sich wertgeschätzt (+)", "fx": {"mood_all": 0.04}},
		]})
	elif not dnf.is_empty():
		var dc := str(dnf["d"]["code"])
		var did := str(dnf["d"]["id"])
		var why := str(dnf["row"]["out"])
		var mood := {}
		mood[did] = 0.04
		var mood_bad := {}
		mood_bad[did] = -0.07
		var lw := why.to_lower()
		var crash := lw.contains("unfall") or lw.contains("kollision") or lw.contains("dreher") or lw.contains("crash")
		if crash:
			out.append({"who": "Motorsport-Magazin", "q": "Aus für %s (%s). Was ist da passiert?" % [dc, why], "answers": [
				{"label": "Unser Fehler, ich übernehme die Verantwortung.", "hint": "%s dankbar (+), Vorstand skeptisch (-)" % dc, "fx": {"mood": mood, "board": -1.5}},
				{"label": "Der Fahrer muss daraus lernen.", "hint": "%s verärgert (--), Vorstand mag klare Worte (+)" % dc, "fx": {"mood": mood_bad, "board": 1.5}},
				{"label": "Pech, so ist der Rennsport.", "hint": "keine großen Folgen", "fx": {}},
			]})
		else:
			out.append({"who": "Motorsport-Magazin", "q": "Technisches Aus für %s (%s). Hat das Team versagt?" % [dc, why if why != "" else "Defekt"], "answers": [
				{"label": "Ja, wir haben ihn im Stich gelassen.", "hint": "%s fühlt sich verstanden (+), Vorstand unzufrieden (-)" % dc, "fx": {"mood": mood, "board": -1.5}},
				{"label": "Zuverlässigkeit hat ab sofort Priorität.", "hint": "Vorstand beruhigt (+)", "fx": {"board": 1.5}},
				{"label": "Das kann passieren.", "hint": "%s etwas frustriert (-)" % dc, "fx": {"mood": {did: -0.02}}},
			]})
	elif bpos <= 3:
		var mood2 := {}
		mood2[bid] = 0.05
		out.append({"who": "F1 TV", "q": "Podium für %s! Was war der Schlüssel?" % bcode, "answers": [
			{"label": "Die Strategie hat gepasst.", "hint": "Vorstand zufrieden (+)", "fx": {"board": 1.5}},
			{"label": "Eine starke Leistung von %s." % bcode, "hint": "%s fühlt sich bestätigt (++)" % bcode, "fx": {"mood": mood2}},
			{"label": "Das Auto wird immer besser.", "hint": "beide Fahrer zuversichtlich (+)", "fx": {"mood_all": 0.02, "board": 0.5}},
		]})
	elif not gr.is_empty() and not bool(gr.get("met", true)):
		out.append({"who": "The Race", "q": "Das Ziel wurde verfehlt. Wie geht es weiter?", "answers": [
			{"label": "Wir analysieren das in Ruhe.", "hint": "neutral", "fx": {}},
			{"label": "Ich erwarte mehr von den Fahrern.", "hint": "Fahrer unter Druck (-), Vorstand zufrieden (+)", "fx": {"mood_all": -0.04, "board": 2.0}},
			{"label": "Das Auto ist nicht schnell genug.", "hint": "Fahrer erleichtert (+), Vorstand unzufrieden (-)", "fx": {"mood_all": 0.03, "board": -1.5}},
		]})
	else:
		out.append({"who": "auto motor und sport", "q": "Wie bewerten Sie das Rennen von %s?" % team, "answers": [
			{"label": "Wir sind zufrieden.", "hint": "Fahrer gut gelaunt (+)", "fx": {"mood_all": 0.015}},
			{"label": "Da geht noch mehr.", "hint": "Fahrer etwas unter Druck (-), Vorstand mag den Ehrgeiz (+)", "fx": {"mood_all": -0.015, "board": 1.0}},
		]})
	# 2) Zweite Frage: Duell der Teamkollegen oder Sponsor
	if tr.size() >= 2 and int(tr[0]["row"]["state"]) != 3 and int(tr[1]["row"]["state"]) != 3:
		var a: Dictionary = tr[0]["d"]
		var b: Dictionary = tr[1]["d"]
		var gap := int(tr[1]["row"]["pos"]) - int(tr[0]["row"]["pos"])
		if gap >= 3 or Game.rng.randf() < 0.35:
			var m_a := {}
			m_a[str(a["id"])] = 0.05
			m_a[str(b["id"])] = -0.07
			var m_eq := {}
			m_eq[str(a["id"])] = -0.01
			m_eq[str(b["id"])] = 0.03
			out.append({"who": "Gazzetta dello Sport", "q": "%s war wieder vor %s. Wer ist die Nummer 1 im Team?" % [a["code"], b["code"]], "answers": [
				{"label": "%s ist unsere Nummer 1." % a["code"], "hint": "%s gestärkt (++), %s verärgert (--)" % [a["code"], b["code"]], "fx": {"mood": m_a}},
				{"label": "Beide sind gleichberechtigt.", "hint": "%s erleichtert (+), %s etwas enttäuscht (-)" % [b["code"], a["code"]], "fx": {"mood": m_eq}},
				{"label": "Kein Kommentar.", "hint": "keine Folgen", "fx": {}},
			]})
			return out
	if Game.rng.randf() < 0.3:
		out.append({"who": "Sponsor-Abteilung", "q": "Ihr Sponsor wünscht mehr Medientermine mit den Fahrern.", "answers": [
			{"label": "Machen wir.", "hint": "+1,5 Mio. $, Fahrer etwas genervt (-)", "fx": {"budget": 1.5, "mood_all": -0.02}},
			{"label": "Die Fahrer brauchen Ruhe.", "hint": "Fahrer dankbar (+), Vorstand murrt (-)", "fx": {"mood_all": 0.015, "board": -1.0}},
		]})
	return out


## Antwort anwenden. Rückgabe: Liste der Stimmungsänderungen [{"code", "before", "after"}] für die Anzeige.
static func apply(fx: Dictionary) -> Array:
	var changes: Array = []
	var drs: Array = Market.current_drivers(Game.team_id)
	for d in drs:
		var delta := float(fx.get("mood_all", 0.0))
		var md: Dictionary = fx.get("mood", {})
		delta += float(md.get(str(d["id"]), 0.0))
		if absf(delta) > 0.0001:
			var before := float(d["morale"])
			d["morale"] = clampf(before + delta, 0.0, 1.0)
			changes.append({"code": d["code"], "before": before, "after": float(d["morale"])})
	if fx.has("board"):
		Game.board = clampf(Game.board + float(fx["board"]), 0.0, 100.0)
	if fx.has("budget"):
		Game.budget += float(fx["budget"])
	return changes


## Stimmung als Wort und Farbe.
static func mood_word(m: float) -> Array:
	if m >= 0.78:
		return ["Euphorisch", Color("16a34a")]
	if m >= 0.6:
		return ["Zufrieden", Color("4d9d17")]
	if m >= 0.45:
		return ["Angespannt", Color("d98200")]
	return ["Unzufrieden", Color("d93025")]

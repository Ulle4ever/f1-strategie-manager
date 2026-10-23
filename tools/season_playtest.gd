extends SceneTree
# Aufruf (Summer Engine oder Godot, mit Fenster für Screenshots):
#   OUT=<Ordner> YEAR=2025 TEAM=williams SEED=5 F1_MOBILE=1 Summer.exe --path . --resolution 844x390 -s tools/season_playtest.gd
# Spieltest: eine ganze Saison wie ein Spieler (Zentrale, Meldungen, Training, Qualifying, Strategie, Rennen in Echtzeit
# mit 256x, Funkanfragen beantworten, Ergebnis), danach Markt und Saisonwechsel. Prüft nach jedem Rennen Regeln und
# Plausibilität und meldet Auffälligkeiten mit "[!]". ENV: OUT (Screenshots), YEAR, TEAM, SEED, F1_MOBILE, ROUNDS (optional)
var main
var G
var out := OS.get_environment("OUT")
var rng := RandomNumberGenerator.new()
var issues := 0
var stats := {"sc": 0, "vsc": 0, "dnf": 0, "rain": 0, "decisions": 0, "winners": {}, "poles": {}, "player_pts": 0.0}

func frames(n: int) -> void:
	for i in n:
		await process_frame
func say(t: String) -> void:
	print("[ST] ", t)
func bad(t: String) -> void:
	issues += 1
	print("[!] ", t)
func shot(name: String) -> void:
	if out == "":
		return
	await frames(3)
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
func _initialize() -> void:
	rng.seed = int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 1
	_run()

func _tabs(node, arr: Array) -> void:
	if node is TabContainer and node.is_visible_in_tree():
		arr.append(node)
	for ch in node.get_children():
		_tabs(ch, arr)

func _run() -> void:
	var mobile := OS.get_environment("F1_MOBILE") == "1"
	root.size = Vector2i(844, 390) if mobile else Vector2i(1366, 768)
	DisplayServer.window_set_size(root.size)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	G = root.get_node("Game")
	await frames(10)
	var year := int(OS.get_environment("YEAR")) if OS.get_environment("YEAR") != "" else 2025
	var team := OS.get_environment("TEAM") if OS.get_environment("TEAM") != "" else "williams"
	G.new_season(year, team)
	main.show_hub()
	await frames(20)
	await shot("00_zentrale")
	var n_rounds: int = G.calendar.size()
	if OS.get_environment("ROUNDS") != "":
		n_rounds = mini(n_rounds, int(OS.get_environment("ROUNDS")))
	say("Saison %d mit %s, %d Rennen, Budget %.1f" % [year, team, G.calendar.size(), G.budget])
	var Dev = load("res://scripts/dev.gd")
	for r in n_rounds:
		var hub = main.current
		# Meldung aus der Zentrale beantworten (manchmal liegen lassen)
		if not G.pending_event.is_empty():
			await frames(5)
			if rng.randf() < 0.75 and hub.has_method("_on_event_choice"):
				var id := str(G.pending_event.get("id", ""))
				hub._on_event_choice(rng.randi() % 2)
				await frames(3)
				say("  Meldung %s beantwortet" % id)
		# Entwicklung und Ausbau
		if G.dev_projects.size() < Dev.slots() and G.cap_left() > 8.0 and G.budget > 15.0:
			var areas: Array = Dev.AREAS
			Dev.start(str(areas[rng.randi() % areas.size()]), ["s", "m"][rng.randi() % 2], "cur" if r < n_rounds - 6 else "next")
		if r % 6 == 2:
			G.buy_upgrade(["reliab", "pit", "coach"][rng.randi() % 3])
		var race: Dictionary = G.current_race()
		if r > 0:
			G.intro_seen = "%d-%d" % [G.year, G.round_index]
		main.show_weekend()
		await frames(8)
		if r == 0:
			await shot("01_intro")
			G.intro_seen = "%d-%d" % [G.year, G.round_index]
			main.show_weekend()
			await frames(8)
		# Training jedes dritte Rennen
		if r % 3 == 0:
			main.show_practice()
			await frames(4)
			var pr = main.current
			for s in 3:
				pr.program_opts[s].select(rng.randi() % 4)
				pr._on_run(s)
				await frames(1)
			pr._on_take_estimate()
			main.show_weekend()
			await frames(4)
		# Qualifying: abwechselnd selbst fahren und automatisch
		if r % 2 == 0:
			main.show_quali()
			await frames(4)
			var qs = main.current
			for k in 20:
				for card in qs.cards:
					if rng.randf() < 0.6:
						qs._on_go(card)
				qs._set_speed(4)
				await frames(6)
				qs._skip_phase(true)
				await frames(3)
				if qs.overlay.visible:
					qs._on_continue()
					await frames(3)
					if main.current != qs:
						break
			if main.current == qs:
				bad("R%d Qualifying endet nicht" % (r + 1))
				main.show_weekend()
				await frames(4)
		else:
			main.current._on_auto_quali()
			await frames(4)
		var wk = main.current
		if wk.get("editors") == null:
			main.show_weekend()
			await frames(4)
			wk = main.current
		wk._on_start()
		await frames(8)
		var rs = main.current
		if rs.get("sim") == null:
			bad("R%d Rennbildschirm nicht geöffnet" % (r + 1))
			continue
		var sim = rs.sim
		var pole = sim.cars.filter(func(c): return c.grid == 1)
		if pole.size() == 1:
			stats["poles"][pole[0].code] = int(stats["poles"].get(pole[0].code, 0)) + 1
		rs._lights_out()
		await frames(5)
		rs._set_speed(5)
		var guard := 0
		var shot_mid := r == 1 or r == n_rounds / 2
		while not sim.over and guard < 4000:
			await process_frame
			guard += 1
			if rs.decision_card.visible and rs.decision_data.has("options"):
				var opts: Array = rs.decision_data["options"]
				if shot_mid and guard > 50:
					await shot("%02d_funk_%s" % [r + 1, str(race.get("circuitId", ""))])
					shot_mid = false
				rs._on_decision(str(opts[rng.randi() % opts.size()]["action"]))
				stats["decisions"] += 1
				rs._set_speed(5)
			elif rs.speed_idx < 5 and not rs.decision_card.visible:
				rs._set_speed(5)
			if shot_mid and sim.leader_lap() > sim.laps / 2:
				await shot("%02d_rennen_%s" % [r + 1, str(race.get("circuitId", ""))])
				shot_mid = false
		if not sim.over:
			say("  R%d nach %d Bildern nicht fertig (Runde %d/%d), spule vor" % [r + 1, guard, sim.leader_lap(), sim.laps])
			rs._skip_to_end(true)
		for e in sim.events:
			match str(e["kind"]):
				"sc":
					if "VIRTUAL" in str(e["text"]).to_upper() or "VSC" in str(e["text"]):
						stats["vsc"] += 1
					else:
						stats["sc"] += 1
				"dnf":
					stats["dnf"] += 1
				"weather":
					stats["rain"] += 1
		var before_dp := _sum(G.driver_points)
		var before_tp := _sum(G.team_points)
		var round_before: int = G.round_index
		rs._on_results()
		await frames(10)
		_check_result(r, race, sim, before_dp, before_tp, round_before)
		if r % 6 == 0 or r == n_rounds - 1:
			await shot("%02d_ergebnis_%s" % [r + 1, str(race.get("circuitId", ""))])
		main.show_hub()
		await frames(10)
	# Saisonende
	await shot("90_saisonende")
	say("Endstand Fahrer: %s" % ", ".join(G.driver_standings().slice(0, 5).map(func(d): return "%s %d" % [d["code"], int(d["points"])])))
	say("Endstand Teams: %s" % ", ".join(G.team_standings().slice(0, 5).map(func(t): return "%s %d" % [t["name"], int(t["points"])])))
	var me_rank: int = G.team_standings().map(func(t): return t["id"]).find(G.team_id) + 1
	say("Eigenes Team Platz %d, Budget %.1f, Vorstand %.0f, Sieger: %s, Poles: %s" % [me_rank, G.budget, G.board, str(stats["winners"]), str(stats["poles"])])
	say("Ereignisse: SC %d, VSC %d, Ausfälle %d, Wetter-Meldungen %d, Funkentscheidungen %d" % [stats["sc"], stats["vsc"], stats["dnf"], stats["rain"], stats["decisions"]])
	if n_rounds == G.calendar.size():
		G.begin_market()
		main.show_market()
		await frames(10)
		await shot("91_markt")
		if G.Market.open_seats(G.team_id) > 0:
			G.Market.auto_fill_player()
		var y0: int = G.year
		main.current._on_finish()
		await frames(15)
		await shot("92_aufstellung")
		if G.year != y0 + 1:
			bad("Saisonwechsel: Jahr %d statt %d" % [G.year, y0 + 1])
		if G.round_index != 0:
			bad("Saisonwechsel: Runde %d statt 0" % G.round_index)
		if _sum(G.driver_points) != 0.0:
			bad("Saisonwechsel: Fahrerpunkte nicht zurückgesetzt")
		for t in G.teams:
			if t["drivers"].size() != 2:
				bad("Saison %d: %s hat %d Fahrer" % [G.year, t["name"], t["drivers"].size()])
		var codes := {}
		for t in G.teams:
			for d in t["drivers"]:
				if codes.has(d["code"]):
					bad("Saison %d: Kürzel %s doppelt" % [G.year, d["code"]])
				codes[d["code"]] = true
		say("Neue Saison %d: %d Teams, %d Rennen" % [G.year, G.teams.size(), G.calendar.size()])
		main.show_hub()
		await frames(10)
		await shot("93_neue_saison")
	say("AUFFÄLLIGKEITEN: %d" % issues)
	say("TEST ENDE")
	quit()

func _sum(d: Dictionary) -> float:
	var s := 0.0
	for k in d:
		s += float(d[k])
	return s

func _check_result(r: int, race: Dictionary, sim, before_dp: float, before_tp: float, round_before: int) -> void:
	var res: Dictionary = G.last_result
	var rows: Array = res.get("rows", [])
	var tag := "R%d %s" % [r + 1, str(race.get("name", "?"))]
	if G.round_index != round_before + 1:
		bad("%s: Runde springt von %d auf %d" % [tag, round_before, G.round_index])
	if rows.size() != sim.cars.size():
		bad("%s: %d Ergebniszeilen für %d Autos" % [tag, rows.size(), sim.cars.size()])
	var gained := 0.0
	var finished := 0
	var winner_laps := 0
	var prev_time := 0.0
	var prev_laps := 1 << 30
	var out_after_classified := false
	for i in rows.size():
		var row: Dictionary = rows[i]
		gained += float(row["points"])
		if int(row["pos"]) != i + 1:
			bad("%s: Position %d an Stelle %d" % [tag, int(row["pos"]), i + 1])
		var is_out := int(row["state"]) == 3
		if is_out:
			out_after_classified = true
			if float(row["points"]) > 0.0:
				bad("%s: %s ausgefallen, aber %.0f Punkte" % [tag, row["code"], float(row["points"])])
			continue
		if out_after_classified:
			bad("%s: %s im Ziel hinter einem Ausfall gewertet" % [tag, row["code"]])
		finished += 1
		var laps := int(row["laps"])
		if i == 0:
			winner_laps = laps
		if laps > prev_laps:
			bad("%s: %s mit mehr Runden (%d) hinter einem Auto mit %d" % [tag, row["code"], laps, prev_laps])
		elif laps == prev_laps and float(row["time"]) + 0.001 < prev_time:
			bad("%s: %s schneller (%.1f) als der Vordermann (%.1f) bei gleicher Rundenzahl" % [tag, row["code"], float(row["time"]), prev_time])
		prev_laps = laps
		prev_time = float(row["time"])
		var stops := int(row["stops"])
		if stops > 6:
			bad("%s: %s mit %d Stopps" % [tag, row["code"], stops])
		if G.year >= 2007 and stops == 0 and sim.wet < 0.05 and laps >= sim.laps - 1 and not bool(sim.get("any_wet_used") if sim.get("any_wet_used") != null else false):
			bad("%s: %s ohne Stopp im Ziel (Zwei-Mischungen-Regel?)" % [tag, row["code"]])
		var best := float(row["best"])
		if best <= 0.0 or best > 400.0 or is_nan(best):
			bad("%s: %s beste Runde %.3f" % [tag, row["code"], best])
	if winner_laps != sim.laps:
		bad("%s: Sieger mit %d von %d Runden" % [tag, winner_laps, sim.laps])
	if finished < 8:
		bad("%s: nur %d Autos im Ziel" % [tag, finished])
	var dp := _sum(G.driver_points) - before_dp
	var tp := _sum(G.team_points) - before_tp
	if absf(dp - gained) > 0.01 or absf(tp - gained) > 0.01:
		bad("%s: Punkte stimmen nicht (Zeilen %.1f, Fahrer %.1f, Teams %.1f)" % [tag, gained, dp, tp])
	var table: Array = G.rules["points"]
	var expect := 0.0
	for i in mini(table.size(), finished):
		expect += float(table[i])
	if gained + 0.01 < expect or gained > expect + 1.01:
		bad("%s: vergebene Punkte %.1f, erwartet %.1f" % [tag, gained, expect])
	if is_nan(G.budget) or is_inf(G.budget):
		bad("%s: Budget ungültig" % tag)
	if G.board < 0.0 or G.board > 100.0:
		bad("%s: Vorstand %.1f" % [tag, G.board])
	var win: Dictionary = rows[0]
	stats["winners"][win["code"]] = int(stats["winners"].get(win["code"], 0)) + 1
	var mine: Array = rows.filter(func(x): return bool(x["player"]))
	var my_pts := 0.0
	for m in mine:
		my_pts += float(m["points"])
	stats["player_pts"] += my_pts
	var race_min: float = float(win["time"]) / 60.0
	if race_min < 55.0 or race_min > 190.0:
		bad("%s: Renndauer %.0f min" % [tag, race_min])
	say("%s: Sieger %s (%s, von P%d), %d im Ziel, Renndauer %.0f min, schnellste Runde %s; eigene: %s; Budget %.1f, Vorstand %.0f" % [
		tag, win["code"], win["team"], int(win["grid"]), finished, race_min, str(res.get("fastest", "")),
		", ".join(mine.map(func(m): return "%s P%d (Start P%d, %d Stopps%s)" % [m["code"], int(m["pos"]), int(m["grid"]), int(m["stops"]), ", " + str(m["out"]) if int(m["state"]) == 3 else ""])),
		G.budget, G.board])

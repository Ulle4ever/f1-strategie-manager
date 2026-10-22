extends PanelContainer
## Strategie-Zentrale im Rennwochenende: Plan (Stints, Rundenzeit-Diagramm, Tank), Reifensätze, Varianten A/B/C mit
## Vorschau-Läufen (Monte Carlo), Wenn-Dann-Regeln und Boxencrew.

const U = preload("res://scripts/ui.gd")
const RaceSim = preload("res://scripts/race_sim.gd")
const StintBar = preload("res://scripts/stint_bar.gd")
const LapChart = preload("res://scripts/lap_chart.gd")
const TeamStyle = preload("res://scripts/team_style.gd")

var sim
var laps := 0
var cars: Array = []
var cur := 0
var states := {}
var e: Dictionary = {}                # Bearbeitungsstand des gewählten Autos
var tabs: TabContainer
var car_btns: Array = []
var plan_box: VBoxContainer
var tyre_box: VBoxContainer
var var_box: VBoxContainer
var rule_box: VBoxContainer
var chart
var timeline
var stints_box: VBoxContainer
var sum_label: Label
var warn_label: Label
var fuel_info: Label
var fuel_spin: SpinBox
var detail_labels: Array = []
var stop_fuel_labels: Array = []
# Varianten und Vorschau
var variants: Array = []
var pv_results := {}
var pv_jobs: Array = []
var pv_total := 0
var pv_cur = null
var pv_cur_job := {}
var pv_bar: ProgressBar
var pv_label: Label
var pv_btn: Button
var pv_cards: Dictionary = {}
var var_chart


func setup(p_sim, p_laps: int) -> void:
	sim = p_sim
	laps = p_laps
	for c in sim.cars:
		if c.is_player:
			cars.append(c)
	var sb := U.panel(6 if U.is_mobile() else 14, U.ACCENT)
	add_theme_stylebox_override("panel", sb.get_theme_stylebox("panel"))
	sb.free()
	custom_minimum_size = Vector2(400, 0)
	var root := U.vbox(8)
	add_child(root)
	if not U.is_mobile():
		root.add_child(U.section("Strategie", 14))
	var crow := U.hbox(6)
	for i in cars.size():
		var b := Button.new()
		b.toggle_mode = true
		b.text = cars[i].driver_name
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 30 if U.is_mobile() else 38)
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_on_car.bind(i))
		crow.add_child(b)
		car_btns.append(b)
	if cars.size() > 1:
		root.add_child(crow)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	plan_box = _tab("Plan")
	tyre_box = _tab("Reifen")
	var_box = _tab("Varianten")
	rule_box = _tab("Regeln")
	_on_car(0)


func _tab(tab_name: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = tab_name
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := U.vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	tabs.add_child(sc)
	return v


func _wl(text := "", size := 13, col := U.TEXT, bold := false) -> Label:
	var l := U.label(text, size, col, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _on_car(i: int) -> void:
	cur = i
	for k in car_btns.size():
		car_btns[k].set_pressed_no_signal(k == i)
	var c = cars[i]
	if not states.has(c.index):
		states[c.index] = {"car": c, "start": c.compound, "plan": c.plan.duplicate(true), "extra": c.fuel_extra}
	e = states[c.index]
	variants = []
	pv_results = {}
	pv_jobs = []
	pv_cur = null
	_build_plan()
	_build_tyres()
	_build_variants()
	_build_rules()


## Haltbarkeit: exakt nach Reifentest, sonst als Bereich.
func _life_txt(c, comp: int) -> String:
	var adj: float = sim.life_eff(comp) / sim._pred_wear_rate(c, 55.0)
	if sim.practice["tyre_known"] or comp >= RaceSim.DRY_COUNT:
		return "%d Rd" % int(adj)
	var k: float = sim.known_life(comp) / sim._pred_wear_rate(c, 55.0)
	return "~%d Rd" % (int(round(k / 2.0)) * 2)


func _comp_row(selected: int, cb: Callable, only := -1) -> Dictionary:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	var btns: Array = []
	var c = cars[cur]
	for k in RaceSim.COMPOUNDS.size():
		var cd: Dictionary = RaceSim.COMPOUNDS[k]
		var b := Button.new()
		b.toggle_mode = true
		var cnt: Dictionary = sim.tyre_count(c, k)
		var sets := ""
		if not sim.tyre_unlimited():
			sets = "  %d" % (int(cnt["new"]) + int(cnt["used"]))
		b.text = ("%s %s%s" % [cd["name"], _life_txt(c, k), sets]) if k < RaceSim.DRY_COUNT else ("%s%s" % [cd["name"], sets])
		b.custom_minimum_size = Vector2(0, 34)
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", cd["ink"])
		b.add_theme_color_override("font_hover_color", cd["ink"])
		b.add_theme_color_override("font_disabled_color", Color(cd["ink"], 0.35))
		U.tyre_button(b, cd["color"])
		b.button_pressed = k == selected
		b.pressed.connect(cb.bind(k))
		if only >= 0 and k != only:
			b.disabled = true
		row.add_child(b)
		btns.append(b)
	return {"row": row, "btns": btns}


# ------------------------------------------------------------------ Reiter Plan

func _build_plan() -> void:
	U.clear(plan_box)
	var c = cars[cur]
	var head := U.hbox(8)
	head.add_child(U.color_bar(TeamStyle.ui_color(c.team_id), 6, 26))
	head.add_child(U.label(c.driver_name, 18, U.TEXT, true))
	head.add_child(U.spacer())
	head.add_child(U.chip("Start P%d" % c.grid, U.PANEL3))
	plan_box.add_child(head)
	sum_label = _wl("", 14, U.GOOD, true)
	plan_box.add_child(sum_label)
	chart = LapChart.new()
	plan_box.add_child(chart)
	var leg := _wl("Rundenzeit-Vorhersage: blau = Gewicht des Sprits, farbig = Reifenabbau. Senkrechte Linien = Boxenstopps.", 11, U.MUTED)
	plan_box.add_child(leg)
	timeline = StintBar.new()
	plan_box.add_child(timeline)
	stints_box = U.vbox(6)
	plan_box.add_child(stints_box)
	var arow := U.hbox(8)
	arow.add_child(U.button("+ Boxenstopp", _on_add_stop, 0, 34))
	arow.add_child(U.button("KI-Empfehlung", _on_reset, 0, 34))
	plan_box.add_child(arow)
	# Tank
	var card := U.card(10)
	var fv := U.vbox(6)
	card.add_child(fv)
	fv.add_child(U.section("Tank und Gewicht", 12))
	var frow := U.hbox(8)
	var fl := _wl("Reserve beim Start (Runden)", 13)
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frow.add_child(fl)
	fuel_spin = SpinBox.new()
	fuel_spin.min_value = -4.0
	fuel_spin.max_value = 12.0 if sim.rules["refuel"] else 6.0
	fuel_spin.step = 0.5
	fuel_spin.value = float(e["extra"])
	fuel_spin.value_changed.connect(_on_fuel_extra)
	frow.add_child(fuel_spin)
	fv.add_child(frow)
	fuel_info = _wl("", 13)
	fv.add_child(fuel_info)
	plan_box.add_child(card)
	warn_label = _wl("", 12, U.BAD)
	plan_box.add_child(warn_label)
	_rebuild_stints()


func _rebuild_stints() -> void:
	U.clear(stints_box)
	detail_labels = []
	stop_fuel_labels = []
	var c = cars[cur]
	var plan: Array = e["plan"]
	plan.sort_custom(func(a, b): return int(a["lap"]) < int(b["lap"]))
	# Start-Stint
	var sc0 := U.card(8, U.tint(0.035))
	var cv0 := U.vbox(5)
	sc0.add_child(cv0)
	var r0 := U.hbox(8)
	r0.add_child(U.label("STINT 1  |  START", 12, U.MUTED, true))
	cv0.add_child(r0)
	var sr := _comp_row(int(e["start"]), _on_start_comp, c.forced_start)
	cv0.add_child(sr["row"])
	e["start_btns"] = sr["btns"]
	if c.forced_start >= 0:
		cv0.add_child(_wl("Pflicht: Start auf dem Q2-Reifen (Top 10). Ab Platz 11 ist der Startreifen frei wählbar.", 12, U.WARN))
	var d0 := _wl("", 12, U.TEXT)
	cv0.add_child(d0)
	detail_labels.append(d0)
	stints_box.add_child(sc0)
	for i in plan.size():
		var s: Dictionary = plan[i]
		var sc := U.card(8, U.tint(0.035))
		var cv := U.vbox(5)
		sc.add_child(cv)
		var r1 := U.hbox(8)
		r1.add_child(U.label("STINT %d  |  STOPP %d" % [i + 2, i + 1], 12, U.MUTED, true))
		r1.add_child(U.spacer())
		r1.add_child(U.label("nach Runde", 13))
		var sp := SpinBox.new()
		sp.min_value = 1
		sp.max_value = maxi(1, laps - 1)
		sp.value = int(s["lap"])
		sp.value_changed.connect(_on_stop_lap.bind(s))
		r1.add_child(sp)
		r1.add_child(U.button("x", _on_remove.bind(s), 34, 32))
		cv.add_child(r1)
		var cr := _comp_row(int(s["comp"]), _on_stop_comp.bind(s))
		cv.add_child(cr["row"])
		s["_btns"] = cr["btns"]
		if sim.rules["refuel"]:
			var r3 := U.hbox(8)
			var tl := _wl("Tanken: Reserve (Runden)", 13)
			tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r3.add_child(tl)
			var fs := SpinBox.new()
			fs.min_value = -3.0
			fs.max_value = 12.0
			fs.step = 0.5
			fs.value = float(s.get("fuel", 0.0))
			fs.value_changed.connect(_on_stop_fuel.bind(s))
			r3.add_child(fs)
			cv.add_child(r3)
			var il := _wl("", 12, U.MUTED)
			cv.add_child(il)
			stop_fuel_labels.append({"s": s, "lbl": il})
		var d := _wl("", 12, U.TEXT)
		cv.add_child(d)
		detail_labels.append(d)
		stints_box.add_child(sc)
	for k in RaceSim.COMPOUNDS.size():
		e["start_btns"][k].set_pressed_no_signal(k == int(e["start"]))
	_apply()


func _clean_plan() -> Array:
	var clean: Array = []
	for s in e["plan"]:
		clean.append({"lap": int(s["lap"]), "comp": int(s["comp"]), "fuel": float(s.get("fuel", 0.0))})
	clean.sort_custom(func(a, b): return int(a["lap"]) < int(b["lap"]))
	return clean


## Plan an die Simulation übergeben und alle Anzeigen aktualisieren.
func _apply() -> void:
	var c = cars[cur]
	var clean := _clean_plan()
	sim.set_fuel_extra(c, float(e["extra"]))
	sim.set_plan(c, int(e["start"]), clean)
	var start_wear := 0.0
	var pred: Dictionary = sim.predict_laps(c, int(e["start"]), clean, start_wear)
	chart.set_pred(pred, laps)
	timeline.set_plan(laps, int(e["start"]), clean, func(k): return sim.life_eff(k) / sim._pred_wear_rate(c, 55.0))
	var total: float = pred["total"]
	var avg: float = (total - float(clean.size()) * sim.track.pit_loss * float(sim.rules["pit_loss_scale"])) / float(laps)
	sum_label.text = "Renndauer %s  |  %d Stopp%s  |  Ø Runde %s" % [sim.fmt_race_time(total), clean.size(), "" if clean.size() == 1 else "s", sim.fmt_time(avg)]
	var warns: Array = []
	var used := {int(e["start"]): true}
	for s in clean:
		used[int(s["comp"])] = true
	if int(sim.rules["min_compounds"]) >= 2 and used.size() < 2 and not sim.rain_seen:
		warns.append("Regel: mindestens zwei verschiedene Mischungen nötig, sonst erzwingt das Team einen Zusatzstopp.")
	# Stints mit Details
	var a := 0
	var comp := int(e["start"])
	var idx := 0
	var bounds: Array = []
	for s in clean:
		bounds.append([a, int(s["lap"]), comp])
		a = int(s["lap"])
		comp = int(s["comp"])
	bounds.append([a, laps, comp])
	var need: Dictionary = sim.plan_tyre_need(int(e["start"]), clean)
	var times: Array = pred["times"]
	for k in bounds.size():
		var b: Array = bounds[k]
		var len_l: int = int(b[1]) - int(b[0])
		var cp: int = int(b[2])
		var cd: Dictionary = RaceSim.COMPOUNDS[cp]
		var life: float = sim.life_eff(cp) / sim._pred_wear_rate(c, 55.0)
		var frac: float = float(len_l) / maxf(life, 1.0)
		var verdict := "passt" if frac <= 0.95 else ("grenzwertig" if frac <= 1.1 else "zu lang")
		var cnt: Dictionary = sim.tyre_count(c, cp)
		var sets_txt := "unbegrenzt verfügbar"
		if not sim.tyre_unlimited():
			var parts := []
			if int(cnt["new"]) > 0:
				parts.append("%d neu" % int(cnt["new"]))
			if int(cnt["used"]) > 0:
				parts.append("%d gebraucht (Ø %d Rd)" % [int(cnt["used"]), int(round(float(cnt["laps"])))])
			sets_txt = ", ".join(parts) if not parts.is_empty() else "keine Sätze mehr!"
		var t_start: float = float(times[clampi(int(b[0]), 0, times.size() - 1)])
		var t_end: float = float(times[clampi(int(b[1]) - 1, 0, times.size() - 1)])
		var dtxt := "%d Runden  |  Haltbarkeit %s: %d Rd (%d %% genutzt, %s)\n" % [len_l, "genau" if (sim.practice["tyre_known"] or cp >= RaceSim.DRY_COUNT) else "geschätzt", int(life), int(frac * 100.0), verdict]
		dtxt += "Tempo %+.2f s/Rd ggü. Soft  |  Abbau %.2f s pro Runde\n" % [float(cd["offset"]) * sim.scale_time, float(cd["deg"]) * sim.track.tyre_severity * sim.scale_time]
		dtxt += "Rundenzeit %s bis %s  |  Sätze: %s" % [sim.fmt_time(t_start), sim.fmt_time(t_end), sets_txt]
		if k < detail_labels.size():
			detail_labels[k].text = dtxt
			detail_labels[k].add_theme_color_override("font_color", U.BAD if frac > 1.1 else (U.WARN if frac > 0.95 else U.TEXT))
		if frac > 1.1:
			warns.append("Stint %d: %s hält nur ca. %d Runden, geplant sind %d." % [k + 1, cd["name"], int(life), len_l])
	if not sim.tyre_unlimited():
		for cp2 in need.keys():
			var cnt2: Dictionary = sim.tyre_count(c, int(cp2))
			if int(need[cp2]) > int(cnt2["free"]):
				warns.append("Du brauchst %d x %s, hast aber nur %d Sätze. Das Team montiert dann einen anderen Reifen." % [int(need[cp2]), RaceSim.COMPOUNDS[int(cp2)]["name"], int(cnt2["free"])])
	# Tank
	var burn: float = sim.burn_per_lap
	var first_stop := laps
	if sim.rules["refuel"] and not clean.is_empty():
		first_stop = int(clean[0]["lap"])
	var f0: float = c.fuel
	var range0: float = (f0 - 0.3) / burn
	var pen: float = f0 * RaceSim.FUEL_TIME * sim.scale_time
	var wear_more: float = (sim._pred_wear_rate(c, f0) / sim._pred_wear_rate(c, 50.0) - 1.0) * 100.0
	var ftxt := "Start: %.1f kg (max. %d kg)  |  Reichweite %.1f Runden, Bedarf bis %s: %d\n" % [f0, int(sim.fuel_cap()), range0, "Stopp 1" if sim.rules["refuel"] and not clean.is_empty() else "Ziel", first_stop]
	ftxt += "Gewicht kostet am Start %.1f s pro Runde, jede Runde wird es %.2f s leichter  |  Reifenverschleiß %+d %% gegenüber 50 kg" % [pen, burn * RaceSim.FUEL_TIME * sim.scale_time, int(round(wear_more))]
	if range0 < float(first_stop):
		ftxt += "\nZU WENIG SPRIT: Der Tank wird leer, bevor du %s erreichst. Mit Fahrstil Sparen reicht es nur knapp." % ("Stopp 1" if first_stop < laps else "das Ziel")
		warns.append("Tank reicht nicht bis zum ersten Stopp/Ziel.")
		fuel_info.add_theme_color_override("font_color", U.BAD)
	elif range0 < float(first_stop) + 0.8:
		fuel_info.add_theme_color_override("font_color", U.WARN)
	else:
		fuel_info.add_theme_color_override("font_color", U.TEXT)
	fuel_info.text = ftxt
	if sim.rules["refuel"]:
		for entry in stop_fuel_labels:
			var st: Dictionary = entry["s"]
			var nxt := laps
			for s2 in clean:
				if int(s2["lap"]) > int(st["lap"]):
					nxt = mini(nxt, int(s2["lap"]))
			var need_l := nxt - int(st["lap"])
			var kg: float = sim.fuel_for_laps(float(need_l) + float(st.get("fuel", 0.0)))
			var rng_l: float = (kg - 0.3) / burn
			var add_s: float = maxf(0.0, kg - 2.0) / 9.0 + 1.2
			entry["lbl"].text = "Tank danach %.1f kg = %.1f Rd. (Bedarf %d)  |  Standzeit ca. %.1f s  |  Gewicht +%.1f s/Rd" % [kg, rng_l, need_l, add_s, kg * RaceSim.FUEL_TIME * sim.scale_time]
			entry["lbl"].add_theme_color_override("font_color", U.BAD if rng_l < float(need_l) else U.MUTED)
			if rng_l < float(need_l):
				warns.append("Stopp nach Runde %d: Tank reicht nicht bis zum nächsten Stopp/Ziel." % int(st["lap"]))
	warn_label.text = "\n".join(warns)
	if tabs != null and tyre_box != null and idx == 0:
		_build_tyres()


func _on_start_comp(k: int) -> void:
	e["start"] = k
	_rebuild_stints()


func _on_stop_lap(v: float, s: Dictionary) -> void:
	s["lap"] = int(v)
	_apply()


func _on_stop_comp(k: int, s: Dictionary) -> void:
	s["comp"] = k
	var btns: Array = s.get("_btns", [])
	for i in btns.size():
		btns[i].set_pressed_no_signal(i == k)
	_apply()


func _on_stop_fuel(v: float, s: Dictionary) -> void:
	s["fuel"] = v
	_apply()


func _on_fuel_extra(v: float) -> void:
	e["extra"] = v
	_apply()


func _on_remove(s: Dictionary) -> void:
	e["plan"].erase(s)
	_rebuild_stints()


func _on_add_stop() -> void:
	var plan: Array = e["plan"]
	var last := 0
	for s in plan:
		last = maxi(last, int(s["lap"]))
	var lap := clampi(last + int(laps / (plan.size() + 2)), 2, maxi(2, laps - 1))
	plan.append({"lap": lap, "comp": 1, "fuel": 0.0})
	_rebuild_stints()


func _on_reset() -> void:
	var p: Dictionary = sim.default_plan(cars[cur])
	e["start"] = p["start"]
	e["plan"] = p["plan"].duplicate(true)
	e["extra"] = 0.0
	fuel_spin.set_value_no_signal(0.0)
	_rebuild_stints()


# ------------------------------------------------------------------ Reiter Reifen

class SetsRow extends Control:
	var sets: Array = []
	var need := 0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var x := 0.0
		for i in sets.size():
			var s: Dictionary = sets[i]
			var r := Rect2(x, 2, 16, 16)
			var used: float = float(s["used"])
			draw_rect(r, Color.WHITE)
			if used <= 0.0:
				draw_rect(r.grow(-2.0), Color(0.10, 0.62, 0.35))
			else:
				var fillh: float = clampf(1.0 - used / 20.0, 0.25, 0.9) * 12.0
				draw_rect(Rect2(x + 2, 2 + 14 - fillh, 12, fillh), Color(0.95, 0.65, 0.1))
			draw_rect(r, U.tint(0.45) if i >= need else U.ACCENT, false, 1.5 if i >= need else 2.5)
			x += 20.0


func _build_tyres() -> void:
	U.clear(tyre_box)
	var c = cars[cur]
	var inf := _wl("", 13, U.TEXT)
	if sim.tyre_unlimited():
		inf.text = "In dieser Saison gibt es keine Reifenbegrenzung: Du kannst in jedem Stopp frei wählen."
	else:
		var a: Array = sim.tyre_alloc()
		inf.text = "Pro Wochenende und Auto: %d Soft, %d Medium, %d Hard, %d Inter, %d Wet. Im Training und Qualifying verbrauchte Sätze sind gebraucht (gelb, Füllstand = Restprofil). Jeder Stint im Rennen braucht einen eigenen Satz." % [a[0], a[1], a[2], a[3], a[4]]
	tyre_box.add_child(inf)
	var clean := _clean_plan()
	var need: Dictionary = sim.plan_tyre_need(int(e["start"]), clean)
	for k in RaceSim.COMPOUNDS.size():
		var cd: Dictionary = RaceSim.COMPOUNDS[k]
		var card := U.card(8, Color(cd["ink"], 0.07), Color(cd["ink"], 0.4))
		var v := U.vbox(4)
		card.add_child(v)
		var h := U.hbox(8)
		h.add_child(U.label(str(cd["name"]).to_upper(), 15, cd["ink"], true))
		h.add_child(U.spacer())
		var n_need: int = int(need.get(k, 0))
		if n_need > 0:
			h.add_child(U.chip("im Plan x%d" % n_need, cd["ink"], Color.WHITE))
		v.add_child(h)
		if not sim.tyre_unlimited():
			var row = SetsRow.new()
			var arr: Array = []
			for s in sim.tyre_inv.get(c.index, []):
				if int(s["comp"]) == k:
					arr.append(s)
			arr.sort_custom(func(x, y): return float(x["used"]) < float(y["used"]))
			row.sets = arr
			row.need = n_need
			v.add_child(row)
		var cnt: Dictionary = sim.tyre_count(c, k)
		var txt := ""
		if k < RaceSim.DRY_COUNT:
			txt = "Haltbarkeit %s  |  Tempo %+.2f s/Rd ggü. Soft  |  Abbau %.2f s/Rd" % [_life_txt(c, k), float(cd["offset"]) * sim.scale_time, float(cd["deg"]) * sim.track.tyre_severity * sim.scale_time]
		else:
			txt = "Nur bei nasser Strecke. Haltbarkeit %s." % _life_txt(c, k)
		if not sim.tyre_unlimited():
			txt += "\nSätze: %d neu, %d gebraucht" % [int(cnt["new"]), int(cnt["used"])]
			if n_need > int(cnt["free"]):
				txt += "  |  Plan braucht mehr Sätze als vorhanden!"
		v.add_child(_wl(txt, 12, U.BAD if (not sim.tyre_unlimited() and n_need > int(cnt["free"])) else U.TEXT))
		tyre_box.add_child(card)


# ------------------------------------------------------------------ Reiter Varianten

func _build_variants() -> void:
	U.clear(var_box)
	pv_cards = {}
	var_box.add_child(_wl("Drei fertige Pläne zum Vergleichen. 'Vorschau' fährt das Rennen mehrfach mit Zufall (Safety Car, Gegner, Ausfälle) und zeigt, wie riskant ein Plan ist.", 12, U.MUTED))
	var row := U.hbox(6)
	row.add_child(U.button("Varianten berechnen", _on_calc_variants, 0, 38))
	row.add_child(U.spacer())
	var_box.add_child(row)
	if variants.is_empty():
		var_box.add_child(_wl("Noch nicht berechnet. Tippe auf 'Varianten berechnen'.", 13, U.MUTED))
		return
	# Vergleichsdiagramm
	var c = cars[cur]
	var_chart = LapChart.new()
	var series: Array = []
	for v in variants:
		var p: Dictionary = sim.predict_laps(c, int(v["start"]), v["plan"])
		var pit: Array = p["pit"]
		series.append({"name": v["name"], "color": v["color"], "cum": p["cum"], "pit": pit})
	var_chart.set_series(series, laps)
	var_box.add_child(var_chart)
	var_box.add_child(_wl("Rennzeit-Differenz zum aktuellen Plan über die Distanz (unten = schneller). Punkte = Boxenstopps.", 11, U.MUTED))
	for i in variants.size():
		var_box.add_child(_variant_card(i))
	# Vorschau
	var pc := U.card(10)
	var pv := U.vbox(6)
	pc.add_child(pv)
	pv.add_child(U.section("Vorschau (Monte Carlo)", 12))
	var n_runs := 3 if U.is_mobile() else 4
	pv_btn = U.button("Vorschau starten (%d Läufe je Plan)" % n_runs, _on_pv_start.bind(n_runs), 0, 40)
	pv.add_child(pv_btn)
	pv_bar = ProgressBar.new()
	pv_bar.custom_minimum_size = Vector2(0, 10)
	pv_bar.show_percentage = false
	pv_bar.visible = false
	pv.add_child(pv_bar)
	pv_label = _wl("", 12, U.MUTED)
	pv.add_child(pv_label)
	var_box.add_child(pc)
	_show_pv_results()


func _on_calc_variants() -> void:
	var c = cars[cur]
	variants = []
	var cur_plan := _clean_plan()
	variants.append({"key": "X", "name": "Aktueller Plan", "desc": "Dein Plan aus dem Reiter 'Plan'.", "start": int(e["start"]), "plan": cur_plan, "time": float(sim.estimate_time(c, int(e["start"]), cur_plan)), "stops": cur_plan.size(), "color": U.TEXT})
	var cols := [Color("2563eb"), Color("0f9d58"), Color("d98200")]
	var vs: Array = sim.plan_variants(c)
	for i in vs.size():
		var v: Dictionary = vs[i]
		v["color"] = cols[i % cols.size()]
		variants.append(v)
	pv_results = {}
	_build_variants()


func _variant_card(i: int) -> Control:
	var v: Dictionary = variants[i]
	var col: Color = v["color"]
	var card := U.card(9, Color(col, 0.06), Color(col, 0.45))
	var vb := U.vbox(5)
	card.add_child(vb)
	var h := U.hbox(8)
	h.add_child(U.label(str(v["name"]), 16, col, true))
	h.add_child(U.spacer())
	var dt: float = float(v["time"]) - float(variants[0]["time"])
	h.add_child(U.label(("%+.1f s" % dt) if i > 0 else sim.fmt_race_time(float(v["time"])), 14, U.GOOD if (i > 0 and dt < -0.5) else (U.BAD if (i > 0 and dt > 0.5) else U.TEXT), true))
	vb.add_child(h)
	vb.add_child(_wl(str(v["desc"]), 12, U.MUTED))
	var tl := StintBar.new()
	vb.add_child(tl)
	var c = cars[cur]
	tl.set_plan(laps, int(v["start"]), v["plan"], func(k): return sim.life_eff(k) / sim._pred_wear_rate(c, 55.0))
	var rlab := _wl("", 12, U.TEXT)
	vb.add_child(rlab)
	pv_cards[i] = rlab
	if i > 0:
		vb.add_child(U.button("Diesen Plan übernehmen", _on_take_variant.bind(i), 0, 34))
	return card


func _on_take_variant(i: int) -> void:
	var v: Dictionary = variants[i]
	e["start"] = int(v["start"])
	e["plan"] = v["plan"].duplicate(true)
	e["extra"] = 0.0
	_build_plan()
	_build_tyres()
	tabs.current_tab = 0


func _on_pv_start(n_runs: int) -> void:
	if variants.is_empty():
		return
	if not pv_jobs.is_empty() or pv_cur != null:
		pv_jobs = []
		pv_cur = null
		pv_bar.visible = false
		pv_btn.text = "Vorschau starten (%d Läufe je Plan)" % n_runs
		return
	pv_results = {}
	pv_jobs = []
	for k in n_runs:
		for i in variants.size():
			pv_jobs.append({"v": i, "seed": 9100 + k * 37 + i})
	pv_total = pv_jobs.size()
	pv_bar.max_value = float(pv_total)
	pv_bar.value = 0.0
	pv_bar.visible = true
	pv_btn.text = "Abbrechen"


func _process(_delta: float) -> void:
	if pv_cur == null and pv_jobs.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < 12000:
		if pv_cur == null:
			if pv_jobs.is_empty():
				break
			pv_cur_job = pv_jobs.pop_front()
			var v: Dictionary = variants[int(pv_cur_job["v"])]
			var c = cars[cur]
			pv_cur = sim.preview_clone(int(pv_cur_job["seed"]), c.index, {"start": v["start"], "plan": v["plan"], "extra": 0.0})
			pv_cur.start_race()
		pv_cur.tick(1.0)
		if pv_cur.over or pv_cur.time > 20000.0:
			var c2 = cars[cur]
			var rk: Array = pv_cur.ranking()
			var pos := 0
			var out := false
			for i in rk.size():
				if rk[i].index == c2.index:
					pos = i + 1
					out = rk[i].state == 3
			var key: int = int(pv_cur_job["v"])
			if not pv_results.has(key):
				pv_results[key] = []
			pv_results[key].append({"pos": pos, "out": out})
			pv_cur = null
			pv_bar.value = float(pv_total - pv_jobs.size())
	if pv_cur == null and pv_jobs.is_empty():
		pv_bar.visible = false
		pv_btn.text = "Vorschau erneut starten"
		_show_pv_results()


func _show_pv_results() -> void:
	var pts: Array = sim.rules["points"]
	for i in pv_cards.keys():
		var lbl: Label = pv_cards[i]
		if not pv_results.has(i):
			lbl.text = "Noch keine Vorschau."
			lbl.add_theme_color_override("font_color", U.MUTED)
			continue
		var arr: Array = pv_results[i]
		var sum := 0.0
		var best := 99
		var worst := 0
		var pcount := 0
		var outs := 0
		for r in arr:
			var p: int = int(r["pos"])
			sum += float(p)
			best = mini(best, p)
			worst = maxi(worst, p)
			if p <= pts.size() and not bool(r["out"]):
				pcount += 1
			if bool(r["out"]):
				outs += 1
		var n := float(arr.size())
		lbl.text = "Vorschau (%d Läufe): Ø Platz %.1f  |  bester P%d, schlechtester P%d  |  Punkte in %d %% der Läufe%s" % [arr.size(), sum / n, best, worst, int(100.0 * float(pcount) / n), ("  |  Ausfall in %d Lauf" % outs) if outs > 0 else ""]
		lbl.add_theme_color_override("font_color", U.TEXT)


# ------------------------------------------------------------------ Reiter Regeln und Crew

func _build_rules() -> void:
	U.clear(rule_box)
	rule_box.add_child(_wl("Wenn-Dann-Regeln: Das Team handelt im Rennen automatisch, auch wenn du gerade nicht eingreifst. Die Regeln gelten für beide Autos.", 12, U.MUTED))
	var defs := [
		["sc_pit", "Safety Car: Stopp holen", "Wenn Safety Car oder VSC kommt und die Reifen zu über 35 % verbraucht sind, wird der günstige Stopp genutzt."],
		["rain_switch", "Regen: auf Regenreifen wechseln", "Bei Streckennässe über 28 % geht es auf Inter bzw. Wet (nass über 60 %)."],
		["dry_switch", "Abtrocknen: zurück auf Slicks", "Wenn die Strecke trocken ist und kein Regen fällt, wird auf Slicks gewechselt."],
		["defend", "Konter-Stopp bei Undercut-Gefahr", "Wenn ein Verfolger per Undercut gefährlich wird und die Reifen schon über 40 % verbraucht sind."],
		["fuel_save", "Sprit automatisch sparen", "Wenn der Tank nicht bis zum Stopp bzw. Ziel reicht, fährt der Fahrer im Spar-Modus."],
	]
	for d in defs:
		var cb := U.checkbox(str(d[1]))
		var on := false
		for c in cars:
			if bool(c.rules.get(str(d[0]), false)):
				on = true
		cb.button_pressed = on
		cb.toggled.connect(_on_rule.bind(str(d[0])))
		rule_box.add_child(cb)
		rule_box.add_child(_wl(str(d[2]), 11, U.MUTED))
	rule_box.add_child(HSeparator.new())
	# Boxencrew
	var card := U.card(10)
	var v := U.vbox(5)
	card.add_child(v)
	v.add_child(U.section("Boxencrew", 12))
	var lvl: int = int(Game.upgrades.get("pit", 0))
	var form: float = Game.crew_form
	v.add_child(_wl("Crew-Stufe %d (Entwicklung)  |  Form %d %%" % [lvl, int(form * 100.0)], 14, U.TEXT, true))
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.value = form * 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	v.add_child(bar)
	v.add_child(_wl("Form macht Stopps schneller (bis -0,25 s Standzeit) und seltener langsam (bis -60 %% Pannenrisiko). Sie sinkt von Rennen zu Rennen. Stopp-Training: 1 Mio. $ (zählt zur Kostenobergrenze).".replace("%%", "%"), 12, U.MUTED))
	var msg := _wl("", 12, U.GOOD)
	v.add_child(msg)
	v.add_child(U.button("Stopp-Training (1 Mio. $)", _on_crew_train.bind(msg), 0, 38))
	rule_box.add_child(card)
	# Funk
	var rc := U.card(10)
	var rv := U.vbox(4)
	rc.add_child(rv)
	rv.add_child(U.section("Funkanweisungen im Rennen", 12))
	rv.add_child(_wl("Im Rennen (Reiter Auto) kannst du dem Fahrer Anweisungen geben: Push (3 Runden Angriff), Reifen managen (5 Runden schonen), Lift and Coast (5 Runden Sprit sparen, etwas langsamer). Der Fahrer meldet sich außerdem selbst, wenn die Reifen nachlassen.", 12, U.TEXT))
	rule_box.add_child(rc)


func _on_rule(on: bool, key: String) -> void:
	for c in cars:
		sim.set_rule(c, key, on)


func _on_crew_train(msg: Label) -> void:
	msg.text = Game.crew_train()
	sim.crew_form = Game.crew_form
	_build_rules()

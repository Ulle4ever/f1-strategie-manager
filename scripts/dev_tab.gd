extends VBoxContainer
## Reiter "Entwicklung" der Zentrale: Kostenobergrenze, Stand der sechs Bereiche (dieses Auto und Auto der nächsten Saison),
## laufende Projekte mit Fortschritt, Projekt-Planer (Bereich, Ziel, Größe), gelieferte Teile und Team-Ausbau
## (Zuverlässigkeit, Boxencrew, Fahrertraining).

const U = preload("res://scripts/ui.gd")
const Dev = preload("res://scripts/dev.gd")
const Staff = preload("res://scripts/staff.gd")

signal changed

const TEAM_UPGRADES := ["reliab", "pit", "coach"]

var sel_area := "floor"
var sel_size := "m"
var sel_target := "cur"
var sel_spec := ""
var _msg := ""


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	rebuild()


func _wl(text: String, size := 13, col := U.MUTED, bold := false) -> Label:
	var l := U.label(text, size, col, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func rebuild() -> void:
	U.clear(self)
	var M := U.is_mobile()
	# Kostenobergrenze
	var capp := U.panel(10, U.WARN)
	var capv := U.vbox(4)
	capp.add_child(capv)
	var used := Game.cap_used()
	capv.add_child(U.label("KOSTENOBERGRENZE  %.0f / %.0f Mio. $   (Gehälter %.0f, Entwicklung %.0f, Provisionen %.0f)" % [used, Game.cap, Game.payroll_current(), Game.dev_spent, Game.cap_spent_fees], 13 if M else 15, U.TEXT, true))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.show_percentage = false
	bar.max_value = Game.cap
	bar.value = minf(used, Game.cap)
	var cc := U.GOOD if used < Game.cap * 0.8 else (U.WARN if used < Game.cap * 0.95 else U.BAD)
	bar.add_theme_stylebox_override("fill", U.button_style(cc, cc, 0, 2))
	capv.add_child(bar)
	add_child(capp)
	var td: Dictionary = Game.staff.get("td", {})
	var info := "Technischer Direktor: %s (%d) – %d Projektplätze. Projekte zählen zur Kostenobergrenze." % [str(td.get("name", "-")), int(td.get("rating", 0)), Dev.slots()]
	if Dev.reg_next():
		info += " Achtung: %d kommt ein neues Reglement – Entwicklung fürs nächste Auto zählt dann besonders, das alte Auto wird stark entwertet." % (Game.year + 1)
	add_child(_wl(info, 12, U.MUTED))
	if _msg != "":
		add_child(_wl(_msg, 13, U.BLUE, true))

	# Stand der Bereiche
	add_child(U.section("Dein Auto", 12))
	var g := GridContainer.new()
	g.columns = 2 if M else 3
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 6)
	add_child(g)
	for a in Dev.AREAS:
		var p: Dictionary = Dev.part(a)
		var card := U.card(8)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := U.vbox(2)
		card.add_child(v)
		var top := U.hbox(6)
		v.add_child(top)
		var nl := U.label(str(Dev.AREA[a]["name"]), 13, U.TEXT, true)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.clip_text = true
		top.add_child(nl)
		top.add_child(U.display("+%.2f %%" % float(p["cur"]), 14, U.ACCENT_TEXT))
		var b := ProgressBar.new()
		b.max_value = 1.2
		b.value = float(p["cur"])
		b.show_percentage = false
		b.custom_minimum_size = Vector2(0, 6)
		v.add_child(b)
		var sub := str(Dev.AREA[a]["desc"])
		var fl := _focus_line(a, "cur")
		if fl != "":
			sub = fl
		if float(p["next"]) > 0.001:
			sub = "Auto %d: +%.2f %%  ·  %s" % [Game.year + 1, float(p["next"]), sub]
		var sl := U.label(sub, 11, U.MUTED)
		sl.clip_text = true
		v.add_child(sl)
		g.add_child(card)

	# Charakter des Autos: Profil mit Entwicklung (heller Kreis = Saisonstart)
	add_child(_character())

	# Laufende Projekte
	add_child(U.section("Projekte  %d / %d" % [Game.dev_projects.size(), Dev.slots()], 12))
	for pr in Game.dev_projects:
		add_child(_project_card(pr))
	if Game.dev_projects.size() < Dev.slots():
		add_child(_planner())

	# Gelieferte Teile
	if not Game.dev_log.is_empty():
		add_child(U.section("Geliefert", 12))
		for i in mini(6, Game.dev_log.size()):
			var e: Dictionary = Game.dev_log[i]
			var kind := str(e.get("kind", "flop" if bool(e["failed"]) else "ok"))
			var col := U.BAD if kind == "flop" else (U.WARN if kind == "half" else (U.GOOD if float(e["gain"]) >= (float(e["lo"]) + float(e["hi"])) * 0.5 else U.TEXT))
			add_child(_wl("R%d %d  ·  %s" % [int(e["round"]), int(e["year"]), str(e["text"])], 12, col))

	# Team-Ausbau
	add_child(U.section("Team", 12))
	for key in TEAM_UPGRADES:
		add_child(_upgrade_card(key))


## Größte Schwerpunkte eines Bereichs als Kurztext, z. B. "Spitzenabtrieb +0.20 · Arbeitsfenster +0.05".
func _focus_line(a: String, target: String) -> String:
	var foc: Dictionary = Dev.part(a)["foc_" + target]
	var ids: Array = foc.keys().filter(func(k): return float(foc[k]) > 0.005)
	ids.sort_custom(func(x, y): return float(foc[x]) > float(foc[y]))
	var parts: Array = []
	for id in ids.slice(0, 2):
		parts.append("%s +%.2f" % [str(Dev.focus(a, str(id))["name"]), float(foc[id])])
	return "  ·  ".join(parts)


## Charakter des eigenen Autos: Profilbalken mit Entwicklung und Standfestigkeit.
func _character() -> Control:
	var M := U.is_mobile()
	var box := U.vbox(4)
	box.name = "Character"
	box.add_child(U.section("Charakter des Autos", 12))
	var prof: Dictionary = Game.team_profile(Game.team_id)
	var base: Dictionary = Game.team_profile(Game.team_id, true)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 2)
	box.add_child(g)
	var rows := [["Abtrieb", "df", "Topspeed", "Abtrieb"], ["Motor / Topspeed", "power", "schwach", "stark"], ["Reifenschonung", "tyre", "frisst", "schont"], ["Regen", "wet", "schwach", "stark"]]
	for r in rows:
		var bar = load("res://scripts/profile_bar.gd").new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.setup(str(r[0]), float(prof.get(r[1], 0.0)), str(r[2]), str(r[3]), U.ACCENT, float(base.get(r[1], 0.0)))
		g.add_child(bar)
	# spürbare Wirkung der Profiländerung (wie race_sim.track_fit, Runde etwa 80 s)
	var dd := float(prof["df"]) - float(base["df"])
	var dp := float(prof["power"]) - float(base["power"])
	var slow := (dd * 1.0 * 0.0032 + dp * -0.6 * 0.0026) * 80.0
	var fast := (dd * -1.0 * 0.0032 + dp * 1.0 * 0.0026) * 80.0
	var wear := int(round(-0.09 * (float(prof["tyre"]) - float(base["tyre"])) * 100.0))
	var rel := float(prof.get("rel", 0.0))
	var mf := Dev.mech_factor()
	var rt := "Profil-Wirkung: kurvige Strecke (Monaco) %+.2f s/Runde, schnelle Strecke (Monza) %+.2f s/Runde, Reifenverschleiß %+d %%, technische Defekte %+d %%." % [-slow, -fast, wear, int(round((mf - 1.0) * 100.0))]
	if absf(rel) < 0.02 and absf(dd) + absf(dp) < 0.02 and wear == 0:
		rt = "Noch keine Profil-Änderung in dieser Saison."
	var nx: Dictionary = Dev.profile_shift("next")
	var nparts: Array = []
	for e in [["df", "Abtrieb"], ["power", "Topspeed"], ["tyre", "Reifen"], ["wet", "Regen"]]:
		if absf(float(nx[e[0]])) >= 0.02:
			nparts.append("%s %+.2f" % [e[1], float(nx[e[0]])])
	if not nparts.is_empty():
		rt += "  Auto %d bisher: %s." % [Game.year + 1, ", ".join(nparts)]
	box.add_child(_wl(rt, 11 if M else 12, U.MUTED))
	box.add_child(_wl("Heller Kreis: Auto zum Saisonstart. Der Schwerpunkt eines Projekts verschiebt das Profil – Abtrieb hilft auf kurvigen Strecken, Topspeed auf schnellen.", 11, U.MUTED))
	return box


func _project_card(pr: Dictionary) -> Control:
	var card := U.card(8, Color(U.ACCENT, 0.06), Color(U.ACCENT, 0.4))
	var v := U.vbox(3)
	card.add_child(v)
	var top := U.hbox(6)
	v.add_child(top)
	var a: String = pr["area"]
	var nm := "%s (%s)" % [str(Dev.AREA[a]["name"]), str(Dev.focus(a, str(pr.get("spec", "")))["name"])]
	var tl := U.label("%s  ·  %s" % [nm, str(Dev.SIZES[pr["size"]]["name"])], 14, U.TEXT, true)
	tl.clip_text = true
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tl)
	top.add_child(U.chip("Dieses Auto" if str(pr["target"]) == "cur" else "Auto %d" % (Game.year + 1), U.DARK if str(pr["target"]) == "cur" else U.BLUE))
	var b := ProgressBar.new()
	b.max_value = float(pr["races"])
	b.value = float(int(pr["races"]) - int(pr["left"]))
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 8)
	v.add_child(b)
	var left := int(pr["left"])
	v.add_child(U.label("fertig %s  ·  erwartet +%.2f bis +%.2f %%  ·  Risiko %d %%" % ["nach dem nächsten Rennen" if left <= 1 else "in %d Rennen" % left, float(pr["lo"]), float(pr["hi"]), int(round(float(pr["fail"]) * 100.0))], 12, U.MUTED))
	return card


## Projekt-Planer: Bereich, (Heckflügel: Abtrieb oder Topspeed), Ziel, Größe, Vorschau und Start.
func _planner() -> Control:
	var M := U.is_mobile()
	var p := U.panel(10, U.ACCENT)
	p.name = "Planner"
	var v := U.vbox(6)
	p.add_child(v)
	v.add_child(U.heading("Neues Projekt", 15))
	var af := HFlowContainer.new()
	af.add_theme_constant_override("h_separation", 4)
	af.add_theme_constant_override("v_separation", 4)
	v.add_child(af)
	for a in Dev.AREAS:
		var b := U.button(str(Dev.AREA[a]["name"]), _pick.bind("area", a), 0, 34)
		b.toggle_mode = true
		b.set_pressed_no_signal(a == sel_area)
		b.add_theme_font_size_override("font_size", 12 if M else 13)
		af.add_child(b)
	# Schwerpunkt des Teils
	var fo: Dictionary = Dev.focus(sel_area, sel_spec)
	sel_spec = str(fo["id"])
	v.add_child(U.label("SCHWERPUNKT", 11, U.MUTED, true))
	var sr := U.hbox(4)
	v.add_child(sr)
	for f in Dev.FOCUS[sel_area]:
		var b2 := U.button(str(f["name"]), _pick.bind("spec", str(f["id"])), 0, 32)
		b2.toggle_mode = true
		b2.set_pressed_no_signal(str(f["id"]) == sel_spec)
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b2.add_theme_font_size_override("font_size", 11 if M else 12)
		b2.clip_text = true
		sr.add_child(b2)
	var risk_txt := ""
	if float(fo["risk"]) > 0.0:
		risk_txt = "  Mutiges Konzept: größere Streuung, höheres Risiko."
	elif float(fo["risk"]) < 0.0:
		risk_txt = "  Sicheres Konzept: geringere Streuung, weniger Risiko."
	v.add_child(_wl("%s: %s.  Wirkung: %s.%s" % [str(fo["name"]), str(fo["desc"]), Dev.focus_effect_text(sel_area, sel_spec), risk_txt], 12, U.TEXT))
	var tr := U.hbox(4)
	v.add_child(tr)
	for e in [["cur", "Für dieses Auto"], ["next", "Für das Auto %d" % (Game.year + 1)]]:
		var b3 := U.button(e[1], _pick.bind("target", e[0]), 0, 34)
		b3.toggle_mode = true
		b3.set_pressed_no_signal(e[0] == sel_target)
		b3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b3.add_theme_font_size_override("font_size", 12 if M else 13)
		tr.add_child(b3)
	var sz := U.hbox(4)
	v.add_child(sz)
	for k in ["s", "m", "l"]:
		var q: Dictionary = Dev.quote(sel_area, k, sel_target, sel_spec)
		var b4 := U.button("%s\n%.0f Mio. $ · %d Rd." % [str(Dev.SIZES[k]["name"]), float(q["cost"]), int(q["races"])], _pick.bind("size", k), 0, 46)
		b4.toggle_mode = true
		b4.set_pressed_no_signal(k == sel_size)
		b4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b4.add_theme_font_size_override("font_size", 11 if M else 12)
		sz.add_child(b4)
	var q2: Dictionary = Dev.quote(sel_area, sel_size, sel_target, sel_spec)
	var when := ""
	if sel_target == "cur":
		when = "Kommt zu Runde %d" % (Game.round_index + int(q2["races"]) + 1) if not bool(q2["late"]) else "Kommt erst nach Saisonende – für dieses Auto zu spät!"
	else:
		when = "Fertig in %d Rennen, wirkt ab Saison %d" % [int(q2["races"]), Game.year + 1]
	var eff := Dev.efficiency(sel_area, sel_target)
	var txt := "%s  ·  erwartet +%.2f bis +%.2f %% Tempo  ·  Risiko %d %%" % [when, float(q2["lo"]), float(q2["hi"]), int(round(float(q2["fail"]) * 100.0))]
	if eff < 0.75:
		txt += "  ·  Bereich schon weit entwickelt (Ertrag %d %%)" % int(eff * 100.0)
	v.add_child(_wl(txt, 12, U.BAD if bool(q2["late"]) else U.MUTED))
	var err := Dev.can_start(float(q2["cost"]))
	var go := U.primary_button("PROJEKT STARTEN  (%.0f MIO. $)" % float(q2["cost"]), _start, 0, 42)
	go.disabled = err != "" or bool(q2["late"])
	v.add_child(go)
	if err != "":
		v.add_child(_wl(err, 12, U.BAD))
	return p


func _pick(what: String, val: String) -> void:
	match what:
		"area":
			if sel_area != val:
				sel_spec = ""
			sel_area = val
		"size":
			sel_size = val
		"target":
			sel_target = val
		"spec":
			sel_spec = val
	_msg = ""
	rebuild.call_deferred()


func _start() -> void:
	var err := Dev.start(sel_area, sel_size, sel_target, sel_spec)
	if err == "":
		_msg = "Projekt gestartet: %s, %s (%s)." % [str(Dev.AREA[sel_area]["name"]), str(Dev.focus(sel_area, sel_spec)["name"]), str(Dev.SIZES[sel_size]["name"])]
		Game.save()
	else:
		_msg = err
	changed.emit()
	rebuild.call_deferred()


func _upgrade_card(key: String) -> Control:
	var u: Dictionary = Game.UPGRADES[key]
	var card := U.card(8)
	var row := U.hbox(10)
	card.add_child(row)
	var info := U.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(U.label(str(u["name"]).to_upper(), 14, U.TEXT, true))
	var dl := U.label(str(u["desc"]), 12, U.MUTED)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(dl)
	row.add_child(info)
	var lv: int = Game.upgrades[key]
	row.add_child(U.display("%d/%d" % [lv, Game.MAX_LEVEL], 18, U.ACCENT_TEXT))
	var btn := U.button("MAXIMAL" if lv >= Game.MAX_LEVEL else "%.0f Mio. $" % Game.upgrade_cost(key), _buy.bind(key), 120, 38)
	btn.disabled = lv >= Game.MAX_LEVEL or not Game.can_upgrade(key)
	row.add_child(btn)
	return card


func _buy(key: String) -> void:
	Game.buy_upgrade(key)
	Game.save()
	changed.emit()
	rebuild.call_deferred()

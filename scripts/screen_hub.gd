extends Control
## Saison-Zentrale: Kalender, Meisterschaften, Entwicklung und das nächste Rennen.

const U = preload("res://scripts/ui.gd")
const TrackMap = preload("res://scripts/track_map.gd")
const Market = preload("res://scripts/market.gd")
const DriverPhoto = preload("res://scripts/driver_photo.gd")
const MarketScreen = preload("res://scripts/screen_market.gd")
const TeamStyle = preload("res://scripts/team_style.gd")
const TeamCrest = preload("res://scripts/team_crest.gd")
const TeamCard = preload("res://scripts/team_card.gd")
const Career = preload("res://scripts/career.gd")
const Field = preload("res://scripts/field.gd")

var cap_label: Label
var cap_bar: ProgressBar
var main
var tabs: TabContainer
var budget_label: Label
var dev_box: VBoxContainer
var dev_rows := {}
var save_button: Button
var event_layer: Control = null
var event_card_box: VBoxContainer = null


func _ready() -> void:
	U.fill(self)
	add_child(U.team_backdrop())
	var margin := U.screen_margin(self, 22)
	var M := U.is_mobile()
	var root := U.vbox(6 if M else 12)
	margin.add_child(root)

	var team: Dictionary = Game.player_team()
	var head := U.hbox(12)
	root.add_child(head)
	var tb := U.title_bar("Saison %d" % Game.year, str(team["name"]))
	tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tb)
	head.add_child(TeamCrest.make(Game.team_id, 40.0 if M else 52.0))
	var bud := U.vbox(0)
	bud.add_child(U.label("BUDGET", 11, U.MUTED_DARK, true))
	budget_label = U.display("", 18 if M else 24, Color("4ade80"))
	bud.add_child(budget_label)
	head.add_child(bud)
	save_button = U.dark_button("Speichern", _on_save, 84 if M else 110, 42)
	head.add_child(save_button)
	head.add_child(U.dark_button("Menü" if M else "Hauptmenü", func(): main.show_start(), 80 if M else 120, 42))

	var cols := U.hbox(16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	tabs = TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(tabs)
	if M:
		var nr := _build_next_race()
		nr.custom_minimum_size.x = 0.0
		_scroll(nr, "Rennen")
	_build_team_profile()
	_build_calendar()
	_build_driver_table()
	_build_team_table()
	_build_development()
	_build_drivers_tab()
	_build_career_tab()
	if not M:
		cols.add_child(_build_next_race())
	_refresh_budget()
	if not Game.pending_event.is_empty() and not Game.event_seen:
		_show_event_dialog.call_deferred()


func _scroll(content: Control, tab_name: String) -> void:
	var sc := ScrollContainer.new()
	sc.name = tab_name
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 10)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(content)
	sc.add_child(m)
	tabs.add_child(sc)


## Spielstand sofort speichern und kurz bestätigen (bzw. warnen, wenn der Browser nichts speichert).
func _on_save() -> void:
	Game.save()
	save_button.text = "Gespeichert" if Game.save_ok else "Speichern fehlt!"
	save_button.add_theme_color_override("font_color", U.GOOD if Game.save_ok else U.BAD)
	await get_tree().create_timer(1.8).timeout
	if is_instance_valid(save_button):
		save_button.text = "Speichern"
		save_button.remove_theme_color_override("font_color")


func _build_team_profile() -> void:
	var card := TeamCard.new()
	card.setup(Game.team_id)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll(card, "Team")


func _refresh_budget() -> void:
	budget_label.text = "%.1f Mio. $" % Game.budget


func _build_calendar() -> void:
	var box := U.vbox(4)
	for i in Game.calendar.size():
		var r: Dictionary = Game.calendar[i]
		var is_next: bool = i == Game.round_index
		var done: bool = i < Game.round_index
		var row := PanelContainer.new()
		var sb := U.button_style(U.tint(0.035) if not is_next else Color(U.ACCENT, 0.16), U.ACCENT if is_next else (U.GOOD if done else U.LINE), 5)
		sb.content_margin_top = 5
		sb.content_margin_bottom = 5
		row.add_theme_stylebox_override("panel", sb)
		var h := U.hbox(12)
		row.add_child(h)
		var num := U.label("%02d" % int(r["round"]), 20, U.MUTED if done else U.TEXT, true)
		num.custom_minimum_size = Vector2(36, 0)
		h.add_child(num)
		var col := U.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(U.label(str(r["name"]).to_upper(), 16, U.MUTED if done else U.TEXT, true))
		col.add_child(U.label("%s, %s" % [r["locality"], r["country"]], 13, U.MUTED))
		h.add_child(col)
		if done and i < Game.history.size():
			var o: Array = Game.history[i]["order"]
			if o.size() > 0:
				h.add_child(U.chip("Sieger " + str(o[0]), Color("17432c"), U.GOOD))
		elif is_next:
			h.add_child(U.chip("Nächstes Rennen"))
		box.add_child(row)
	_scroll(box, "Kalender")


func _bar_row(pos: int, col: Color, title: String, sub: String, pts: float, maxp: float, mine: bool, team_id := "") -> Control:
	var row := PanelContainer.new()
	var sb := U.button_style(Color(U.WARN, 0.10) if mine else U.tint(0.035), col, 6)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", sb)
	var h := U.hbox(12)
	row.add_child(h)
	var p := U.label(str(pos), 20, U.TEXT, true)
	p.custom_minimum_size = Vector2(30, 0)
	h.add_child(p)
	if team_id != "":
		h.add_child(TeamCrest.make(team_id, 30.0))
	var c := U.vbox(0)
	c.custom_minimum_size = Vector2(230 if team_id != "" else 260, 0)
	c.add_child(U.label(title, 16, U.WARN if mine else U.TEXT, true))
	if sub != "":
		c.add_child(U.label(sub, 12, U.MUTED))
	h.add_child(c)
	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(60, 8)
	bar.max_value = maxf(maxp, 1.0)
	bar.value = pts
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", U.button_style(col, col, 0, 2))
	h.add_child(bar)
	var pl := U.label(U.fmt_pts(pts), 20, U.TEXT, true)
	pl.custom_minimum_size = Vector2(56, 0)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(pl)
	return row


func _build_driver_table() -> void:
	var box := U.vbox(4)
	var st: Array = Game.driver_standings()
	var maxp: float = st[0]["points"] if st.size() > 0 else 1.0
	var pos := 1
	for d in st:
		box.add_child(_bar_row(pos, d["color"], "%s  %s" % [d["code"], d["name"]], "%s   |   %d Siege" % [d["team"], d["wins"]], d["points"], maxp, d["team_id"] == Game.team_id))
		pos += 1
	_scroll(box, "Fahrer-WM")


func _build_team_table() -> void:
	var box := U.vbox(4)
	var st: Array = Game.team_standings()
	var maxp: float = st[0]["points"] if st.size() > 0 else 1.0
	var pos := 1
	for t in st:
		box.add_child(_bar_row(pos, TeamStyle.ui_color(t["id"]), str(t["name"]).to_upper(), Field.team_note(str(t["id"])), t["points"], maxp, t["id"] == Game.team_id, t["id"]))
		pos += 1
	# Chronik des Teamfelds: Neueinsteiger, Rückzüge, Fusionen, Umbenennungen
	if not Game.field_log.is_empty():
		box.add_child(U.heading("Teamfeld: %d Teams" % Game.teams.size(), 16, U.MUTED))
		var n := 0
		for e in Game.field_log:
			var fst: Array = MarketScreen.KIND_STYLE.get(e["kind"], MarketScreen.KIND_STYLE["info"])
			var row := U.hbox(8)
			var ch := U.chip(fst[0], fst[1], fst[2])
			ch.custom_minimum_size = Vector2(112, 0)
			row.add_child(ch)
			var tl := U.label(str(e["text"]), 13, U.TEXT)
			tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(tl)
			row.add_child(U.label(str(int(e["year"])), 12, U.MUTED))
			box.add_child(row)
			n += 1
			if n >= 10:
				break
	_scroll(box, "Konstrukteurs-WM")


func _build_development() -> void:
	dev_box = U.vbox(8)
	var dintro := U.label("Investiere dein Budget ins Auto. Die Konkurrenz entwickelt sich ebenfalls weiter. Gehälter und Entwicklung teilen sich die Kostenobergrenze.", 14, U.MUTED)
	dintro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dev_box.add_child(dintro)
	var capp := U.panel(10, U.WARN)
	var capv := U.vbox(4)
	capp.add_child(capv)
	cap_label = U.label("", 15, U.TEXT, true)
	capv.add_child(cap_label)
	cap_bar = ProgressBar.new()
	cap_bar.custom_minimum_size = Vector2(0, 8)
	cap_bar.show_percentage = false
	capv.add_child(cap_bar)
	dev_box.add_child(capp)
	for key in Game.UPGRADE_ORDER:
		var u: Dictionary = Game.UPGRADES[key]
		var card := PanelContainer.new()
		var sb := U.button_style(U.tint(0.045), U.ACCENT, 5)
		card.add_theme_stylebox_override("panel", sb)
		var row := U.hbox(14)
		card.add_child(row)
		var info := U.vbox(0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(U.label(str(u["name"]).to_upper(), 18, U.TEXT, true))
		info.add_child(U.label(u["desc"], 13, U.MUTED))
		row.add_child(info)
		var lvl := U.label("", 22, U.WARN, true)
		lvl.custom_minimum_size = Vector2(70, 0)
		lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(lvl)
		var btn := U.button("", _on_upgrade.bind(key), 160, 40)
		row.add_child(btn)
		dev_box.add_child(card)
		dev_rows[key] = {"lvl": lvl, "btn": btn}
	_scroll(dev_box, "Entwicklung")
	_refresh_dev()


func _refresh_dev() -> void:
	var used := Game.cap_used()
	cap_label.text = "KOSTENOBERGRENZE  %.0f / %.0f Mio. $   (Gehälter %.0f, Entwicklung %.0f, Provisionen %.0f)" % [used, Game.cap, Game.payroll_current(), Game.dev_spent, Game.cap_spent_fees]
	cap_bar.max_value = Game.cap
	cap_bar.value = minf(used, Game.cap)
	var cc := U.GOOD if used < Game.cap * 0.8 else (U.WARN if used < Game.cap * 0.95 else U.BAD)
	cap_bar.add_theme_stylebox_override("fill", U.button_style(cc, cc, 0, 2))
	for key in Game.UPGRADE_ORDER:
		var lv: int = Game.upgrades[key]
		var e: Dictionary = dev_rows[key]
		e["lvl"].text = "%d/%d" % [lv, Game.MAX_LEVEL]
		var b: Button = e["btn"]
		if lv >= Game.MAX_LEVEL:
			b.text = "MAXIMAL"
			b.disabled = true
		else:
			b.text = "%.0f Mio. $" % Game.upgrade_cost(key)
			b.disabled = not Game.can_upgrade(key)


func _build_drivers_tab() -> void:
	var box := U.vbox(8)
	var fintro := U.label("Deine Fahrer und ihre Verträge. Die Stimmung hängt von Ergebnissen, Rolle, Gehalt und Teamkollegen ab.", 14, U.MUTED)
	fintro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(fintro)
	box.add_child(_mode_card())
	for d in Market.current_drivers(Game.team_id):
		var p := U.panel(10)
		var h := U.hbox(12)
		p.add_child(h)
		h.add_child(DriverPhoto.make(str(d["id"]), 64))
		var r := Market.rating_of(d)
		var rl := U.label(str(r), 30, Market.rating_color(r), true)
		rl.custom_minimum_size = Vector2(48, 0)
		h.add_child(rl)
		var v := U.vbox(1)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(U.label(str(d["name"]), 18, U.TEXT, true))
		var c: Dictionary = d["contract"]
		v.add_child(U.label("%d Jahre  |  Vertrag bis %d  |  %.1f Mio. $  |  %s" % [Market.age_of(d, Game.year), int(c["end"]), float(c["salary"]), Market.ROLE_NAMES.get(c["role"], "")], 13, U.MUTED))
		h.add_child(v)
		var m: float = d["morale"]
		var mt := "Zufrieden"
		var mc := U.GOOD
		if m < 0.30:
			mt = "Wechselwunsch"
			mc = U.BAD
		elif m < 0.45:
			mt = "Unzufrieden"
			mc = Color("c9690a")
		elif m < 0.55:
			mt = "Gereizt"
			mc = U.WARN
		h.add_child(U.chip(mt, Color(mc, 0.2), mc))
		box.add_child(p)
	box.add_child(U.button("Verträge und Fahrermarkt öffnen", func(): main.show_market(), 0, 44))
	box.add_child(U.heading("Neuigkeiten", 16, U.MUTED))
	var n := 0
	for item in Game.news:
		var st: Array = MarketScreen.KIND_STYLE.get(item["kind"], MarketScreen.KIND_STYLE["info"])
		var row := U.hbox(8)
		var ch := U.chip(st[0], st[1], st[2])
		ch.custom_minimum_size = Vector2(112, 0)
		row.add_child(ch)
		var tl := U.label(str(item["text"]), 13, U.TEXT)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tl)
		box.add_child(row)
		n += 1
		if n >= 8:
			break
	if n == 0:
		box.add_child(U.label("Noch keine Meldungen.", 14, U.MUTED))
	_scroll(box, "Fahrer")


## Spielmodus: beide Autos (Teamchef) oder nur ein Fahrer.
func _mode_card() -> Control:
	var p := U.panel(10, U.BLUE)
	var v := U.vbox(6)
	p.add_child(v)
	v.add_child(U.label("SPIELMODUS", 11, U.MUTED, true))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	v.add_child(row)
	var btns: Array = []
	var opts: Array = [["", "Teamchef: beide Autos"]]
	for d in Market.current_drivers(Game.team_id):
		opts.append([str(d["code"]), "Nur %s" % str(d["name"])])
	var cur := Game.solo_driver()
	for o in opts:
		var b := Button.new()
		b.toggle_mode = true
		b.text = str(o[1])
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 14)
		b.button_pressed = str(o[0]) == cur
		btns.append([b, str(o[0])])
		row.add_child(b)
	for e in btns:
		e[0].pressed.connect(func():
			Game.solo_code = str(e[1])
			Game.goal_cache = {}
			for e2 in btns:
				e2[0].set_pressed_no_signal(e2[1] == Game.solo_code)
			Game.save())
	var info := U.label("Im 1-Fahrer-Modus gibst du nur für einen Fahrer Befehle (Qualifying, Strategie, Funk, Boxenstopps). Sein Teamkollege wird vom Team automatisch geführt wie bei den anderen Teams. Gilt ab dem nächsten Rennwochenende.", 12, U.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)
	return p


func _wl(text: String, size := 13, col := U.TEXT, bold := false) -> Label:
	var l := U.label(text, size, col, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _career_card(title: String, accent: Color) -> Array:
	var p := U.panel(12, accent)
	var v := U.vbox(5)
	p.add_child(v)
	v.add_child(U.label(title, 11, U.MUTED, true))
	return [p, v]


## Reiter Karriere: Vorstand, Saisonziel, Sponsor, Rennziele, Finanzen.
func _build_career_tab() -> void:
	var box := U.vbox(10)
	if not Game.pending_event.is_empty():
		var def: Dictionary = Career.event_def(str(Game.pending_event["id"]))
		var c0 := _career_card("OFFENE ENTSCHEIDUNG", U.WARN)
		c0[1].add_child(_wl(str(def.get("title", "")), 17, U.TEXT, true))
		c0[1].add_child(U.primary_button("Entscheiden", _show_event_dialog, 0, 42))
		box.add_child(c0[0])
	# Vorstand
	var c1 := _career_card("VORSTAND", Career.board_color())
	c1[1].add_child(_wl("Vertrauen: %s (%d von 100)" % [Career.board_word(), int(Game.board)], 18, U.TEXT, true))
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.value = Game.board
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.add_theme_stylebox_override("fill", U.button_style(Career.board_color(), Career.board_color(), 0, 5))
	c1[1].add_child(bar)
	c1[1].add_child(_wl("Das Vertrauen steigt und sinkt mit den Rennzielen und dem Saisonziel. Es wirkt auf deine Einnahmen (bis zu 10 % mehr oder weniger).", 12, U.MUTED))
	box.add_child(c1[0])
	# Saisonziel
	var c2 := _career_card("SAISONZIEL", U.ACCENT)
	c2[1].add_child(_wl("Konstrukteurs-WM: Platz %d oder besser" % maxi(Game.season_goal_rank, 1), 17, U.TEXT, true))
	if Game.season_over():
		c2[1].add_child(_wl(str(Career.season_eval()["text"]), 14, U.WARN, true))
	else:
		c2[1].add_child(_wl("Aktuell Platz %d nach %d von %d Rennen. Erreicht: Prämie und Vertrauen, übertroffen: mehr, verfehlt: Vertrauen sinkt." % [Game.final_rank(Game.team_id), Game.round_index, Game.calendar.size()], 13, U.MUTED))
	box.add_child(c2[0])
	# Sponsor
	var c3 := _career_card("SPONSOR", U.BLUE)
	if Game.sponsor_id == "":
		c3[1].add_child(_wl("Noch kein Vertrag gewählt, es gilt \"Ausgewogen\".", 14, U.TEXT, true))
	var sp: Dictionary = Career.sponsor()
	c3[1].add_child(_wl("%s (%s)" % [str(sp["name"]), str(sp["tag"])], 17, U.TEXT, true))
	c3[1].add_child(_wl("%s Erwartet ca. %.1f Mio. $ pro Rennen aus Sponsor, Punkten und Rennzielen." % [str(sp["desc"]), Career.sponsor_income(sp)], 13, U.MUTED))
	box.add_child(c3[0])
	# Nächstes Rennziel
	if not Game.season_over():
		var g: Dictionary = Career.race_goal()
		var c4 := _career_card("RENNZIEL FÜR DAS NÄCHSTE RENNEN", U.GOOD)
		c4[1].add_child(_wl(str(g["text"]), 17, U.TEXT, true))
		c4[1].add_child(_wl("Prämie %.1f Mio. $, übertroffen %.1f Mio. $." % [float(g["bonus"]), float(g["bonus_hi"])], 13, U.MUTED))
		box.add_child(c4[0])
	# Verlauf der Rennziele
	if not Game.goal_log.is_empty():
		var c5 := _career_card("RENNZIELE DIESER SAISON", U.LINE)
		var start := maxi(0, Game.goal_log.size() - 10)
		for i in range(Game.goal_log.size() - 1, start - 1, -1):
			var e: Dictionary = Game.goal_log[i]
			var ok: bool = str(e["word"]) in ["erreicht", "übertroffen"]
			var row := U.hbox(8)
			var tl := _wl("%s: %s" % [str(e["race"]).replace(" Grand Prix", ""), str(e["goal"])], 12, U.TEXT)
			tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(tl)
			row.add_child(U.label(str(e["word"]), 12, U.GOOD if ok else U.BAD, true))
			c5[1].add_child(row)
		box.add_child(c5[0])
	# Finanzen
	var c6 := _career_card("FINANZEN DIESER SAISON", U.WARN)
	var inc := 0.0
	var sal := 0.0
	var bon := 0.0
	for e in Game.finance_log:
		inc += float(e["income"])
		sal += float(e["salaries"])
		bon += float(e["bonus"])
	c6[1].add_child(_wl("Einnahmen %.1f Mio. $  |  Gehälter %.1f  |  davon Prämien %.1f" % [inc, sal, bon], 14, U.TEXT, true))
	c6[1].add_child(_wl("Kasse: %.1f Mio. $. Kostenobergrenze: %.1f von %.0f Mio. $ gebunden (Gehälter, Entwicklung, Provisionen)." % [Game.budget, Game.cap_used(), Game.cap], 13, U.MUTED))
	box.add_child(c6[0])
	# Entschiedene Meldungen
	if not Game.career_log.is_empty():
		var c7 := _career_card("ENTSCHEIDUNGEN", U.LINE)
		var n := 0
		for e in Game.career_log:
			c7[1].add_child(_wl("%s: %s" % [str(e["title"]), str(e["text"])], 12, U.TEXT))
			n += 1
			if n >= 5:
				break
		box.add_child(c7[0])
	_scroll(box, "Karriere" if Game.pending_event.is_empty() else "Karriere (!)")


## Meldung aus der Zentrale als Dialog über dem Bildschirm.
func _show_event_dialog() -> void:
	if Game.pending_event.is_empty():
		return
	var def: Dictionary = Career.event_def(str(Game.pending_event["id"]))
	if def.is_empty():
		return
	Game.event_seen = true
	if event_layer != null:
		event_layer.queue_free()
	var M := U.is_mobile()
	var vp := get_viewport_rect().size
	event_layer = ColorRect.new()
	(event_layer as ColorRect).color = Color(0.05, 0.08, 0.16, 0.45)
	U.fill(event_layer)
	event_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(event_layer)
	var cc := CenterContainer.new()
	U.fill(cc)
	event_layer.add_child(cc)
	var card := U.panel(14, U.ACCENT)
	card.custom_minimum_size = Vector2(clampf(vp.x - 40.0, 300.0, 660.0), 0)
	cc.add_child(card)
	var v := U.vbox(8)
	card.add_child(v)
	event_card_box = v
	v.add_child(U.label("MELDUNG AUS DER ZENTRALE", 11, U.MUTED, true))
	v.add_child(_wl(str(def["title"]), 20 if not M else 17, U.TEXT, true))
	v.add_child(_wl(str(def["text"]), 14 if not M else 12, U.MUTED))
	var holder: Container = v
	if M:
		# Handy: Optionen zweispaltig in einem Scrollbereich (wenig Höhe)
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.custom_minimum_size = Vector2(0, maxf(vp.y - 190.0, 120.0))
		v.add_child(sc)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(grid)
		holder = grid
	var opts: Array = def["options"]
	for i in opts.size():
		var oc := U.option_card(str(opts[i]["label"]), str(opts[i]["hint"]), U.ACCENT, _on_event_choice.bind(i), i == int(def.get("default", 99)))
		oc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_child(oc)
	v.add_child(U.button("Später entscheiden", _close_event_dialog, 0, 38))


func _close_event_dialog() -> void:
	if event_layer != null:
		event_layer.queue_free()
		event_layer = null
	event_card_box = null


func _on_event_choice(i: int) -> void:
	var def: Dictionary = Career.event_def(str(Game.pending_event["id"]))
	var chosen := str(def["options"][clampi(i, 0, def["options"].size() - 1)]["label"])
	var txt := Career.choose(i)
	Game.save()
	if event_card_box == null:
		return
	U.clear(event_card_box)
	event_card_box.add_child(U.label("DEINE ENTSCHEIDUNG", 11, U.MUTED, true))
	event_card_box.add_child(_wl(chosen, 18, U.TEXT, true))
	event_card_box.add_child(_wl(txt, 14, U.MUTED))
	event_card_box.add_child(U.primary_button("OK", func():
		_close_event_dialog()
		main.show_hub(), 0, 44))


func _on_upgrade(key: String) -> void:
	Game.buy_upgrade(key)
	_refresh_dev()
	_refresh_budget()
	Game.save()


func _build_next_race() -> Control:
	var p := U.panel(16, U.ACCENT)
	p.custom_minimum_size = Vector2(420, 0)
	var v := U.vbox(8)
	p.add_child(v)
	if Game.season_over():
		var ds: Array = Game.driver_standings()
		var ts: Array = Game.team_standings()
		v.add_child(U.heading("Saison beendet", 30, U.ACCENT))
		v.add_child(U.label("Fahrer-Weltmeister", 13, U.MUTED))
		v.add_child(U.label(str(ds[0]["name"]), 24, U.TEXT, true))
		v.add_child(U.label("Konstrukteurs-Weltmeister", 13, U.MUTED))
		v.add_child(U.label(str(ts[0]["name"]), 24, U.TEXT, true))
		v.add_child(U.label("Dein Team: Platz %d bei den Konstrukteuren" % Game.final_rank(Game.team_id), 15, U.WARN, true))
		v.add_child(U.spacer())
		var nxt := U.label("Jetzt beginnt der Fahrermarkt. Verträge laufen aus, Fahrer wechseln, das Auto wird für %d neu entwickelt." % (Game.year + 1), 14, U.MUTED)
		nxt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(nxt)
		v.add_child(U.primary_button("ZUM FAHRERMARKT  >  %d" % (Game.year + 1), func():
			Game.begin_market()
			main.show_market(), 0, 56))
		return p
	var race: Dictionary = Game.current_race()
	var tr = DB.track(race["circuitId"])
	var tag := U.hbox(8)
	tag.add_child(U.chip("Runde %d / %d" % [Game.round_index + 1, Game.calendar.size()]))
	v.add_child(tag)
	var nm := U.label(str(race["name"]).to_upper(), 26, U.TEXT, true)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	var cl := U.label("%s  |  %s, %s" % [race["circuit"], race["locality"], race["country"]], 13, U.MUTED)
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(cl)
	v.add_child(_wl("Rennziel: %s" % str(Career.race_goal()["text"]), 14, U.BLUE, true))
	if tr == null:
		v.add_child(U.label("Streckendaten fehlen für diesen Kurs.", 16, U.BAD))
		return p
	var laps := Game.race_laps(race, tr)
	var map := TrackMap.new()
	map.custom_minimum_size = Vector2(0, 250)
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.set_track(tr)
	v.add_child(map)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 22)
	g.add_theme_constant_override("v_separation", 8)
	g.add_child(U.stat("Länge", "%.3f km" % (tr.length / 1000.0)))
	g.add_child(U.stat("Runden", str(laps)))
	g.add_child(U.stat("Distanz", "%.0f km" % (tr.length * laps / 1000.0)))
	g.add_child(U.stat("Referenzrunde", _fmt(tr.lap_ref)))
	g.add_child(U.stat("Überholen", _rate(tr.overtake_ease, ["sehr schwer", "schwer", "mittel", "leicht", "sehr leicht"])))
	g.add_child(U.stat("Reifenverschleiß", _rate(tr.tyre_severity - 0.75, ["gering", "niedrig", "mittel", "hoch", "sehr hoch"], 0.55)))
	v.add_child(g)
	v.add_child(U.primary_button("ZUM RENNWOCHENENDE", func(): main.show_weekend(), 0, 56))
	if U.is_mobile():
		# Handy: Info links, Karte rechts nebeneinander
		p.remove_child(v)
		var h := U.hbox(10)
		p.add_child(h)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.remove_child(map)
		map.custom_minimum_size = Vector2(240, 250)
		map.size_flags_vertical = Control.SIZE_EXPAND_FILL
		h.add_child(map)
		# der Haupt-Knopf soll ohne Scrollen sichtbar sein
		v.move_child(v.get_child(v.get_child_count() - 1), 4)
	return p


func _fmt(t: float) -> String:
	var m := int(t / 60.0)
	return "%d:%04.1f" % [m, t - m * 60.0]


func _rate(x: float, words: Array, span := 1.0) -> String:
	var i := clampi(int(x / span * words.size()), 0, words.size() - 1)
	return words[i]

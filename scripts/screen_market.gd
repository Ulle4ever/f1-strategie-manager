extends Control
## Fahrermarkt: eigene Fahrer und Verträge, Fahrerliste, Verhandlung, News und Gerüchte.

const U = preload("res://scripts/ui.gd")
const Market = preload("res://scripts/market.gd")
const Field = preload("res://scripts/field.gd")

const KIND_STYLE := {
	"signing": ["VERPFLICHTET", Color("d6f3e3"), Color("0b7a43")], "extension": ["VERLÄNGERT", Color("dbe8ff"), Color("1d4fb8")],
	"release": ["ABGANG", Color("e6e9f0"), Color("5b657b")], "retire": ["RÜCKTRITT", Color("fff0c2"), Color("8a5a00")],
	"rumor": ["GERÜCHT", Color("efdcff"), Color("6b2fb0")], "poach": ["ABGEWORBEN", Color("ffdcd8"), Color("b3261e")],
	"transfer": ["TRANSFER", Color("ffdcd8"), Color("b3261e")], "exit": ["KLAUSEL", Color("ffdcd8"), Color("b3261e")],
	"info": ["INFO", Color("e6e9f0"), Color("3d465a")], "rookie": ["NACHWUCHS", Color("dbe8ff"), Color("1d4fb8")],
	"team_in": ["NEUES TEAM", Color("d6f3e3"), Color("0b7a43")], "team_out": ["RÜCKZUG", Color("ffdcd8"), Color("b3261e")],
	"team_merge": ["FUSION", Color("efdcff"), Color("6b2fb0")], "team_name": ["UMBENANNT", Color("dbe8ff"), Color("1d4fb8")],
	"field": ["TEAMFELD", Color("fff0c2"), Color("8a5a00")],
}

var main
var selected = null
var filter_opt: OptionButton
var sort_opt: OptionButton
var list_box: VBoxContainer
var detail_box: VBoxContainer
var team_box: VBoxContainer
var news_box: VBoxContainer
var budget_label: Label
var cap_label: Label
var cap_bar: ProgressBar
var finish_box: VBoxContainer
var banner := ""
var banner_col := Color.WHITE
# Verhandlungs-Steuerung
var sal_slider: HSlider
var sal_label: Label
var years_opt: OptionButton
var role_opt: OptionButton
var option_check: CheckBox
var exit_check: CheckBox
var preview_box: VBoxContainer
var action_btn: Button
var _res: Dictionary = {}
var _building := false
var main_tabs: TabContainer
var detail_left: VBoxContainer
var detail_right: VBoxContainer


func _ready() -> void:
	U.fill(self)
	add_child(U.team_backdrop())
	var margin := U.screen_margin(self, 20)
	var M := U.is_mobile()
	var root := U.vbox(6 if M else 10)
	margin.add_child(root)

	var head := U.hbox(14)
	root.add_child(head)
	var sub := "Saison %d  >  %d" % [Game.year, Game.year + 1] if Game.market_open else "Vertragsverhandlungen"
	var tb := U.title_bar("Fahrermarkt", "" if M else sub)
	tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tb)
	var bud := U.vbox(0)
	bud.add_child(U.label("BUDGET", 11, U.MUTED, true))
	budget_label = U.label("", 18 if M else 22, U.GOOD, true)
	bud.add_child(budget_label)
	head.add_child(bud)
	var cap_v := U.vbox(2)
	cap_v.custom_minimum_size = Vector2(130 if M else 190, 0)
	cap_v.add_child(U.label("GEHÄLTER / LIMIT", 11, U.MUTED, true))
	cap_label = U.label("", 14 if M else 18, U.TEXT, true)
	cap_v.add_child(cap_label)
	cap_bar = ProgressBar.new()
	cap_bar.custom_minimum_size = Vector2(0, 8)
	cap_bar.show_percentage = false
	cap_v.add_child(cap_bar)
	head.add_child(cap_v)
	head.add_child(U.button("Zentrale", func(): main.show_hub(), 90 if M else 110, 42))

	# Links: mein Team
	var left := U.panel(12, U.WARN)
	left.custom_minimum_size = Vector2(300, 0)
	var lsc := ScrollContainer.new()
	lsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lv := U.vbox(8)
	left.add_child(lv)
	lv.add_child(U.heading("Mein Team", 18, U.WARN))
	team_box = U.vbox(8)
	lsc.add_child(team_box)
	team_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.custom_minimum_size = Vector2(0 if M else 276, 0)
	lv.add_child(lsc)
	finish_box = U.vbox(6)
	if M:
		left.remove_child(lv)
		var lh := U.hbox(12)
		left.add_child(lh)
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lh.add_child(lv)
		finish_box.custom_minimum_size = Vector2(250, 0)
		lh.add_child(finish_box)
	else:
		lv.add_child(finish_box)

	# Mitte: Fahrerliste und News
	var lp := VBoxContainer.new()
	lp.name = "Fahrer"
	lp.add_theme_constant_override("separation", 6)
	var fh := U.hbox(8)
	fh.add_child(U.label("Zeige", 13, U.MUTED))
	filter_opt = OptionButton.new()
	filter_opt.fit_to_longest_item = false
	filter_opt.custom_minimum_size = Vector2(120, 34)
	for t in ["Alle", "Frei", "Läuft aus", "Unter Vertrag", "Nachwuchs"]:
		filter_opt.add_item(t)
	filter_opt.item_selected.connect(func(_i): _refresh_list())
	fh.add_child(filter_opt)
	fh.add_child(U.label("Sortiert", 13, U.MUTED))
	sort_opt = OptionButton.new()
	sort_opt.fit_to_longest_item = false
	sort_opt.custom_minimum_size = Vector2(120, 34)
	for t in ["Stärke", "Alter", "Forderung", "Potenzial"]:
		sort_opt.add_item(t)
	sort_opt.item_selected.connect(func(_i): _refresh_list())
	fh.add_child(sort_opt)
	lp.add_child(fh)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_box = U.vbox(3)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list_box)
	lp.add_child(sc)
	var lm := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		lm.add_theme_constant_override("margin_" + s, 8)
	lm.add_child(lp)
	lm.name = "Fahrer"

	var nsc := ScrollContainer.new()
	nsc.name = "News und Gerüchte"
	nsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	news_box = U.vbox(4)
	news_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		nm.add_theme_constant_override("margin_" + s, 8)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.add_child(news_box)
	nsc.add_child(nm)

	# Rechts: Details und Verhandlung
	var right := U.panel(14, U.ACCENT)
	right.custom_minimum_size = Vector2(365, 0)
	var rsc := ScrollContainer.new()
	rsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_box = U.vbox(8)
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rsc.add_child(detail_box)
	right.add_child(rsc)

	var entries: Array = []
	if M:
		entries = [
			{"name": "Mein Team", "node": left, "self_scroll": true},
			{"name": "Fahrer", "node": lm, "self_scroll": true},
			{"name": "News", "node": nsc, "self_scroll": true},
			{"name": "Angebot", "node": right, "self_scroll": true},
		]
	else:
		var tabs := TabContainer.new()
		tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tabs.add_child(lm)
		tabs.add_child(nsc)
		entries = [
			{"name": "Mein Team", "node": left, "min": 300.0},
			{"name": "Fahrer", "node": tabs, "grow": true},
			{"name": "Angebot", "node": right, "min": 365.0},
		]
	var body := U.columns(entries, 12)
	root.add_child(body)
	if M:
		main_tabs = body

	_refresh_all()


# ------------------------------------------------------------------ Aktualisieren

func _refresh_all() -> void:
	_refresh_header()
	_refresh_team()
	_refresh_list()
	_refresh_news()
	_refresh_detail()


func _refresh_header() -> void:
	budget_label.text = "%.1f Mio. $" % Game.budget
	var pay := Market.payroll_next(Game.team_id)
	var limit := Game.cap - Market.CAP_DEV_RESERVE
	cap_label.text = "%.1f / %.0f Mio. $" % [pay, limit]
	cap_bar.max_value = limit
	cap_bar.value = minf(pay, limit)
	var col := U.GOOD if pay < limit * 0.8 else (U.WARN if pay < limit * 0.95 else U.BAD)
	cap_bar.add_theme_stylebox_override("fill", U.button_style(col, col, 0, 2))
	cap_label.add_theme_color_override("font_color", col)


## Text darf bei Platzmangel abgeschnitten werden, statt das Layout aufzuweiten.
func _clip(l: Label) -> Label:
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(10, 0)
	return l


func _rating_color(r: int) -> Color:
	return Market.rating_color(r)


func _rating_box(r: int, size := 40, fsize := 20) -> Control:
	var p := PanelContainer.new()
	var sb := U.button_style(Color(1, 1, 1, 0.9), _rating_color(r), 2, 6)
	sb.border_width_bottom = 3
	sb.border_width_left = 0
	sb.border_width_top = 0
	sb.border_width_right = 0
	sb.set_content_margin_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(size, 0)
	var l := U.label(str(r), fsize, _rating_color(r), true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _mood_text(m: float) -> Array:
	if m >= 0.72:
		return ["Begeistert", U.GOOD]
	if m >= 0.55:
		return ["Zufrieden", Color("3f9a14")]
	if m >= 0.40:
		return ["Gereizt", U.WARN]
	if m >= 0.30:
		return ["Unzufrieden", Color("c9690a")]
	return ["Wechselwunsch", U.BAD]


func _contract_text(d: Dictionary) -> String:
	var c: Dictionary = d["contract"]
	if c.is_empty():
		return "kein Vertrag"
	var s := "bis %d  |  %.1f Mio. $  |  %s" % [int(c["end"]), float(c["salary"]), Market.ROLE_NAMES.get(c["role"], "")]
	if bool(c.get("option", false)):
		s += "  |  Teamoption"
	if int(c.get("exit_rank", 0)) > 0:
		s += "  |  Klausel Platz %d" % int(c["exit_rank"])
	return s


func _refresh_team() -> void:
	U.clear(team_box)
	var all := Market.current_drivers(Game.team_id)
	all.sort_custom(func(a, b): return (1 if Market.valid_next(a) else 0) > (1 if Market.valid_next(b) else 0))
	for d in all:
		team_box.add_child(_team_card(d))
	var open := Market.open_seats(Game.team_id)
	for i in open:
		var p := U.panel(10)
		var v := U.vbox(2)
		p.add_child(v)
		v.add_child(U.label("COCKPIT FREI", 16, U.BAD, true))
		v.add_child(U.label("Verpflichte einen Fahrer aus der Liste.", 13, U.MUTED))
		team_box.add_child(p)
	_refresh_finish()


func _team_card(d: Dictionary) -> Control:
	var next := Market.valid_next(d)
	var expiring: bool = int(d["contract"]["end"]) <= Game.year
	var p := PanelContainer.new()
	var edge := U.GOOD if next and int(d["contract"]["end"]) > Game.year + 0 and not expiring else U.WARN
	var sb := U.button_style(U.tint(0.05) if d != selected else Color(U.WARN, 0.14), edge, 5)
	sb.set_content_margin_all(9)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(func(ev): _on_click(ev, d))
	var v := U.vbox(3)
	p.add_child(v)
	var top := U.hbox(8)
	v.add_child(top)
	top.add_child(_rating_box(Market.rating_of(d), 38, 18))
	var nv := U.vbox(0)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.add_child(U.label(str(d["name"]), 17, U.TEXT, true))
	var tag := "LÄUFT AUS" if expiring else "VERTRAG %d" % int(d["contract"]["end"])
	nv.add_child(U.label("%s  |  %d Jahre" % [tag, Market.age_of(d, Game.year + 1)], 12, U.WARN if expiring else U.MUTED, true))
	top.add_child(nv)
	var cl := U.label(_contract_text(d), 12, U.MUTED)
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(cl)
	var mt := _mood_text(float(d["morale"]))
	var mh := U.hbox(8)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(110, 6)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = 1.0
	bar.value = float(d["morale"])
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", U.button_style(mt[1], mt[1], 0, 2))
	mh.add_child(bar)
	mh.add_child(U.label("Stimmung: " + mt[0], 12, mt[1], true))
	v.add_child(mh)
	var bh := U.hbox(6)
	if Game.market_open or expiring:
		if Market.valid_next(d) or expiring:
			bh.add_child(U.button("Verhandeln" if expiring else "Details", func(): _select(d), 0, 30))
		if bool(d["contract"].get("option", false)) and int(d["contract"]["end"]) <= Game.year + 1:
			bh.add_child(U.button("Option ziehen", func(): _on_option(d), 0, 30))
		if Game.market_open and Market.valid_next(d) and not expiring:
			bh.add_child(U.button("Freistellen", func(): _on_release(d), 0, 30))
	v.add_child(bh)
	return p


func _refresh_finish() -> void:
	U.clear(finish_box)
	if not Game.market_open:
		var cl := U.label("Der Markt öffnet nach dem letzten Rennen. Bis dahin kannst du auslaufende Verträge verlängern.", 13, U.MUTED)
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		finish_box.add_child(cl)
		return
	var open := Market.open_seats(Game.team_id)
	if open > 0:
		var l := U.label("Du hast noch %d freie(s) Cockpit(s)." % open, 14, U.BAD, true)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		finish_box.add_child(l)
		finish_box.add_child(U.button("Cockpits automatisch füllen", func():
			Market.auto_fill_player()
			Game.save()
			_refresh_all(), 0, 36))
	var b := U.primary_button(("ABSCHLIESSEN  >  %d" if U.is_mobile() else "MARKT ABSCHLIESSEN  >  SAISON %d") % (Game.year + 1), _on_finish, 0, 52)
	b.disabled = open > 0
	finish_box.add_child(b)
	var hint := U.label("Danach besetzen die anderen Teams ihre Cockpits. Nicht verlängerte Fahrer verlassen dich.", 12, U.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	finish_box.add_child(hint)
	var lines: Array = Field.plan_lines()
	if not lines.is_empty():
		finish_box.add_child(U.label("TEAMFELD %d" % (Game.year + 1), 11, U.MUTED, true))
		for ln in lines:
			var fl := U.label(str(ln), 12, U.TEXT)
			fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			finish_box.add_child(fl)


func _refresh_list() -> void:
	U.clear(list_box)
	var rows: Array = []
	var f := filter_opt.selected
	for k in Game.drivers.keys():
		var d: Dictionary = Game.drivers[k]
		if d["status"] in ["retired", "future"]:
			continue
		if d["team"] == Game.team_id:
			continue
		var expiring: bool = d["status"] == "active" and int(d["contract"].get("end", 0)) <= Game.year
		var free: bool = d["status"] == "free" or d["status"] == "rookie"
		match f:
			1:
				if not free:
					continue
			2:
				if not expiring:
					continue
			3:
				if d["status"] != "active" or expiring:
					continue
			4:
				if d["status"] != "rookie":
					continue
		rows.append(d)
	var key := sort_opt.selected
	rows.sort_custom(func(a, b):
		match key:
			1:
				return Market.age_of(a, Game.year) < Market.age_of(b, Game.year)
			2:
				return Market.ask_salary(a) > Market.ask_salary(b)
			3:
				return Market.potential_of(a) > Market.potential_of(b)
		return Market.rating_of(a) > Market.rating_of(b))
	for d in rows:
		list_box.add_child(_list_row(d))
	if rows.is_empty():
		list_box.add_child(U.label("Keine Fahrer in dieser Ansicht.", 15, U.MUTED))


func _list_row(d: Dictionary) -> Control:
	var p := PanelContainer.new()
	var is_sel: bool = d == selected
	var sb := U.button_style(Color(U.ACCENT, 0.16) if is_sel else U.tint(0.035), U.ACCENT if is_sel else U.LINE, 3)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(func(ev): _on_click(ev, d))
	var h := U.hbox(10)
	p.add_child(h)
	h.add_child(_rating_box(Market.rating_of(d), 40, 19))
	var nv := U.vbox(0)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.add_child(_clip(U.label(str(d["name"]), 16, U.TEXT, true)))
	var pot := Market.potential_of(d)
	var sub := "%d Jahre  |  %s" % [Market.age_of(d, Game.year + 1), d["nat"]]
	if pot > Market.rating_of(d) + 2:
		sub += "  |  Potenzial %d" % pot
	nv.add_child(_clip(U.label(sub, 12, U.MUTED)))
	h.add_child(nv)
	var sv := U.vbox(0)
	sv.custom_minimum_size = Vector2(112, 0)
	if d["status"] == "free":
		sv.add_child(U.label("VERTRAGSLOS", 13, U.GOOD, true))
		sv.add_child(U.label("sofort verfügbar", 12, U.MUTED))
	elif d["status"] == "rookie":
		sv.add_child(U.label("NACHWUCHS", 13, U.BLUE, true))
		sv.add_child(U.label("Debüt %d" % (Game.year + 1), 12, U.MUTED))
	else:
		var exp: bool = int(d["contract"].get("end", 0)) <= Game.year
		var th := U.hbox(5)
		th.add_child(U.color_bar(Game.get_team(d["team"]).get("color", Color.GRAY), 4, 14))
		th.add_child(U.label(Market.team_name(d["team"]), 13, U.TEXT, true))
		sv.add_child(th)
		sv.add_child(U.label("Vertrag läuft aus" if exp else "bis %d" % int(d["contract"]["end"]), 12, U.WARN if exp else U.MUTED))
	h.add_child(sv)
	var price := U.vbox(0)
	price.custom_minimum_size = Vector2(62, 0)
	var pl := U.label("%.1f" % Market.ask_salary(d), 17, U.TEXT, true)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.add_child(pl)
	var pc := U.label("Mio. $", 11, U.MUTED)
	pc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.add_child(pc)
	h.add_child(price)
	return p


func _refresh_news() -> void:
	U.clear(news_box)
	var shown := 0
	for n in Game.news:
		var st: Array = KIND_STYLE.get(n["kind"], KIND_STYLE["info"])
		var row := PanelContainer.new()
		var sb := U.button_style(U.tint(0.03), st[2], 3)
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		row.add_theme_stylebox_override("panel", sb)
		var h := U.hbox(10)
		row.add_child(h)
		var c := U.chip(st[0], st[1], st[2])
		c.custom_minimum_size = Vector2(112, 0)
		h.add_child(c)
		var t := U.label(str(n["text"]), 14, U.TEXT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
		h.add_child(U.label("%d" % int(n["year"]), 12, U.MUTED))
		news_box.add_child(row)
		shown += 1
		if shown >= 70:
			break
	if shown == 0:
		news_box.add_child(U.label("Noch keine Meldungen. Gerüchte tauchen während der Saison auf.", 15, U.MUTED))


# ------------------------------------------------------------------ Auswahl und Details

func _on_click(ev: InputEvent, d: Dictionary) -> void:
	var mb := ev as InputEventMouseButton
	if mb != null and not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not U.touch_scrolled:
		_select(d)


func _select(d: Dictionary) -> void:
	selected = d
	banner = ""
	if main_tabs != null:
		main_tabs.current_tab = 3
	_refresh_team()
	_refresh_list()
	_refresh_detail()


func _refresh_detail() -> void:
	U.clear(detail_box)
	sal_slider = null
	detail_left = detail_box
	detail_right = detail_box
	if U.is_mobile():
		var hb := U.hbox(14)
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_left.add_child(hb)
		detail_left = U.vbox(8)
		detail_left.custom_minimum_size = Vector2(300, 0)
		detail_right = U.vbox(8)
		detail_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(detail_left)
		hb.add_child(detail_right)
	if selected == null:
		detail_left.add_child(U.heading("Fahrerprofil", 20))
		var h := U.label("Wähle links einen eigenen Fahrer oder in der Liste einen Kandidaten. Hier handelst du Gehalt, Laufzeit und Rolle aus.", 15, U.MUTED)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_left.add_child(h)
		var tips := U.label("Tipps\n- Starke Fahrer wollen ein starkes Team.\n- Bezahlfahrer bringen Sponsorgeld mit.\n- Wer unter Vertrag steht, kostet Ablöse.\n- Gehälter zählen zur Kostenobergrenze.", 14, U.MUTED)
		tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_left.add_child(tips)
		return
	var d: Dictionary = selected
	var top := U.hbox(12)
	top.add_child(_rating_box(Market.rating_of(d), 62, 34))
	var nv := U.vbox(0)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.add_child(_clip(U.label(str(d["name"]).to_upper(), 20, U.TEXT, true)))
	nv.add_child(_clip(U.label("%d Jahre  |  %s" % [Market.age_of(d, Game.year + 1), d["nat"]], 13, U.MUTED)))
	top.add_child(nv)
	detail_left.add_child(top)
	if banner != "":
		var bl := U.label(banner, 15, banner_col, true)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_left.add_child(bl)
	# Eigenschaften
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 24)
	g.add_theme_constant_override("v_separation", 4)
	g.add_child(U.stat("Potenzial", str(Market.potential_of(d))))
	g.add_child(U.stat("Gehaltsforderung", "%.1f Mio. $" % Market.ask_salary(d)))
	g.add_child(U.stat("Berater", str(d["agent"])))
	var dow := "-" if float(d["dowry"]) <= 0.0 else "+%.1f Mio. $ / Jahr" % float(d["dowry"])
	g.add_child(U.stat("Sponsorgeld", dow, U.GOOD if float(d["dowry"]) > 0.0 else U.TEXT))
	detail_left.add_child(g)
	var tl := Market.trait_labels(d)
	if not tl.is_empty():
		var trow := HFlowContainer.new()
		trow.add_theme_constant_override("h_separation", 6)
		for t in tl:
			trow.add_child(U.chip(str(t), Color("e1e7fb"), Color("2a3a82")))
		detail_left.add_child(trow)
	var status_txt := ""
	if d["status"] == "retired":
		status_txt = "Hat seine Karriere beendet."
	elif d["status"] == "free":
		status_txt = "Vertragslos."
	elif d["status"] == "rookie":
		status_txt = "Nachwuchsfahrer ohne Vertrag."
	else:
		status_txt = "%s: %s" % [Market.team_name(d["team"]), _contract_text(d)]
		if d["team"] != Game.team_id:
			var mt := _mood_text(float(d["morale"]))
			status_txt += "\nStimmung: " + mt[0]
	var sl := U.label(status_txt, 14, U.MUTED)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_left.add_child(sl)
	detail_left.add_child(HSeparator.new())

	var mine: bool = d["team"] == Game.team_id
	if d["status"] == "retired":
		return
	if not Game.market_open and not mine:
		var l := U.label("Verhandlungen mit anderen Teams starten nach dem letzten Rennen der Saison.", 14, U.WARN)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_left.add_child(l)
		return
	if mine and Market.valid_next(d) and int(d["contract"]["end"]) > Game.year + 1:
		var l2 := U.label("Der Vertrag läuft noch bis %d. Verlängern kannst du ein Jahr vor Ablauf." % int(d["contract"]["end"]), 14, U.MUTED)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_left.add_child(l2)
		return
	_build_negotiation(d, mine)


func _build_negotiation(d: Dictionary, mine: bool) -> void:
	_building = true
	detail_right.add_child(U.heading("Angebot", 16, U.MUTED))
	var ask := Market.ask_salary(d)
	var start_sal := ask
	if mine and not d["contract"].is_empty():
		start_sal = maxf(float(d["contract"]["salary"]), ask * 0.9)
	var sh := U.hbox(8)
	sh.add_child(U.label("Gehalt", 15, U.TEXT, true))
	sh.add_child(U.spacer())
	sal_label = U.label("", 20, U.WARN, true)
	sh.add_child(sal_label)
	detail_right.add_child(sh)
	sal_slider = HSlider.new()
	sal_slider.min_value = 0.5
	sal_slider.max_value = clampf(maxf(ask * 3.4, 12.0), 12.0, 70.0)
	sal_slider.step = 0.1
	sal_slider.value = clampf(snappedf(start_sal, 0.1), 0.5, sal_slider.max_value)
	sal_slider.custom_minimum_size = Vector2(0, 26)
	sal_slider.add_theme_stylebox_override("slider", U.button_style(U.PANEL3, U.PANEL3, 0, 3))
	sal_slider.add_theme_stylebox_override("grabber_area", U.button_style(U.ACCENT, U.ACCENT, 0, 3))
	sal_slider.add_theme_stylebox_override("grabber_area_highlight", U.button_style(U.ACCENT_HI, U.ACCENT_HI, 0, 3))
	sal_slider.value_changed.connect(func(_v): _update_preview())
	detail_right.add_child(sal_slider)
	var yh := U.hbox(8)
	yh.add_child(U.label("Laufzeit", 15, U.TEXT, true))
	yh.add_child(U.spacer())
	years_opt = OptionButton.new()
	for y in [1, 2, 3, 4]:
		years_opt.add_item("%d Jahr%s" % [y, "" if y == 1 else "e"], y)
	years_opt.select(1 if Market.age_of(d, Game.year + 1) >= 24 else 2)
	years_opt.item_selected.connect(func(_i): _update_preview())
	yh.add_child(years_opt)
	detail_right.add_child(yh)
	var rh := U.hbox(8)
	rh.add_child(U.label("Rolle", 15, U.TEXT, true))
	rh.add_child(U.spacer())
	role_opt = OptionButton.new()
	for r in ["eq", "n1", "n2"]:
		role_opt.add_item(Market.ROLE_NAMES[r])
	role_opt.item_selected.connect(func(_i): _update_preview())
	rh.add_child(role_opt)
	detail_right.add_child(rh)
	option_check = U.checkbox()
	option_check.text = "Teamoption (+1 Jahr)"
	option_check.toggled.connect(func(_b): _update_preview())
	detail_right.add_child(option_check)
	var rank_guess := clampi(Game.final_rank(Game.team_id) + 1, 2, Game.teams.size())
	exit_check = U.checkbox()
	exit_check.text = "Ausstiegsklausel (ab Platz %d abwärts)" % rank_guess
	exit_check.set_meta("rank", rank_guess)
	exit_check.toggled.connect(func(_b): _update_preview())
	detail_right.add_child(exit_check)
	detail_right.add_child(HSeparator.new())
	preview_box = U.vbox(6)
	detail_right.add_child(preview_box)
	action_btn = U.primary_button("ANGEBOT ABGEBEN", _on_offer, 0, 50)
	detail_right.add_child(action_btn)
	_building = false
	_update_preview()


func _offer() -> Dictionary:
	var roles := ["eq", "n1", "n2"]
	return {"salary": sal_slider.value, "years": years_opt.get_selected_id(), "role": roles[role_opt.selected],
		"option": option_check.button_pressed, "exit_rank": int(exit_check.get_meta("rank")) if exit_check.button_pressed else 0}


func _update_preview() -> void:
	if _building or sal_slider == null or selected == null:
		return
	var d: Dictionary = selected
	var offer := _offer()
	sal_label.text = "%.1f Mio. $" % sal_slider.value
	_res = Market.respond(d, offer)
	U.clear(preview_box)
	var st: String = _res["status"]
	var col := U.GOOD if st == "accept" else (U.WARN if st == "counter" else U.BAD)
	var title := "ZUSAGE WAHRSCHEINLICH" if st == "accept" else ("GEGENANGEBOT" if st == "counter" else "ABSAGE")
	preview_box.add_child(U.chip(title, Color(col, 0.22), col))
	if _res["reason"] != "":
		var rl := U.label(str(_res["reason"]), 14, U.TEXT)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		preview_box.add_child(rl)
	# Interesse
	if float(_res["need"]) > 0.0:
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 8)
		bar.max_value = 1.0
		bar.value = clampf(float(_res["u"]) / float(_res["need"]), 0.0, 1.0)
		bar.show_percentage = false
		bar.add_theme_stylebox_override("fill", U.button_style(col, col, 0, 2))
		preview_box.add_child(U.label("INTERESSE AN DEINEM ANGEBOT", 11, U.MUTED, true))
		preview_box.add_child(bar)
	if int(_res["rival_count"]) > 0:
		preview_box.add_child(U.label("Konkurrenz: %d Team(s) mit freiem Cockpit" % int(_res["rival_count"]), 13, U.MUTED))
	var costs := "Beraterprovision %.1f Mio. $" % float(_res["fee"])
	if float(_res["buyout"]) > 0.0:
		costs += "  |  Ablöse %.1f Mio. $" % float(_res["buyout"])
	var cl := U.label(costs, 13, U.MUTED)
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_box.add_child(cl)
	if st == "counter":
		action_btn.text = "GEGENANGEBOT ÜBERNEHMEN (%.1f)" % float(_res["counter"])
		action_btn.disabled = false
	elif st == "accept":
		action_btn.text = "VERTRAG UNTERSCHREIBEN"
		action_btn.disabled = false
	else:
		action_btn.text = "ANGEBOT ABGEBEN"
		action_btn.disabled = true


func _on_offer() -> void:
	if selected == null:
		return
	var d: Dictionary = selected
	if _res["status"] == "counter":
		sal_slider.max_value = maxf(sal_slider.max_value, float(_res["counter"]))
		sal_slider.value = float(_res["counter"])
		return
	if _res["status"] != "accept":
		return
	var offer := _offer()
	Market.sign_player(d, offer, _res)
	Game.save()
	banner = "OK: %s hat unterschrieben." % d["name"]
	banner_col = U.GOOD
	_refresh_all()


func _on_option(d: Dictionary) -> void:
	if Market.exercise_option(d):
		Game.save()
		banner = "Option bei %s gezogen." % d["name"]
		banner_col = U.GOOD
	else:
		banner = "Option nicht möglich (Kostenobergrenze?)."
		banner_col = U.BAD
	_refresh_all()


func _on_release(d: Dictionary) -> void:
	var c := Market.release_player_driver(d)
	if c < 0.0:
		banner = "Die Abfindung ist zu hoch für dein Budget."
		banner_col = U.BAD
	else:
		banner = "%s wurde freigestellt (Abfindung %.1f)." % [d["name"], c]
		banner_col = U.WARN
		if selected == d:
			selected = null
		Game.save()
	_refresh_all()


func _on_finish() -> void:
	Game.finish_market_and_advance()
	main.show_lineup()

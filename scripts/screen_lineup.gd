extends Control
## Nach dem Fahrermarkt: Transfers und neue Fahrerpaarungen der kommenden Saison.

const U = preload("res://scripts/ui.gd")
const Market = preload("res://scripts/market.gd")
const MarketScreen = preload("res://scripts/screen_market.gd")

var main


func _ready() -> void:
	U.fill(self)
	add_child(U.team_backdrop())
	var margin := U.screen_margin(self, 22)
	var root := U.vbox(6 if U.is_mobile() else 12)
	margin.add_child(root)
	var tb := U.title_bar("Startaufstellung %d" % Game.year, "Nach dem Fahrermarkt")
	root.add_child(tb)


	# Links: Transfers
	var left := U.panel(14, U.ACCENT)
	left.custom_minimum_size = Vector2(470, 0)
	var lv := U.vbox(6)
	left.add_child(lv)
	lv.add_child(U.heading("Transfers und Abgänge", 18, U.ACCENT))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var nb := U.vbox(4)
	nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(nb)
	lv.add_child(sc)
	var shown := 0
	var log: Array = Game.market_log.duplicate()
	log.reverse()
	for n in log:
		if n["kind"] in ["rumor", "info", "rookie"]:
			continue
		var st: Array = MarketScreen.KIND_STYLE.get(n["kind"], ["INFO", Color("e6e9f0"), Color("3d465a")])
		var h := U.hbox(8)
		var c := U.chip(st[0], st[1], st[2])
		c.custom_minimum_size = Vector2(108, 0)
		h.add_child(c)
		var t := U.label(str(n["text"]), 14, U.TEXT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
		nb.add_child(h)
		shown += 1
	if shown == 0:
		nb.add_child(U.label("Es gab keine Wechsel.", 15, U.MUTED))

	# Rechts: Fahrerpaarungen
	var right := U.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gsc := ScrollContainer.new()
	gsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gsc.add_child(grid)
	right.add_child(gsc)
	for t in Game.teams:
		var mine: bool = t["id"] == Game.team_id
		var p := PanelContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := U.button_style(Color(U.WARN, 0.10) if mine else U.tint(0.045), t["color"], 6)
		sb.set_content_margin_all(9)
		p.add_theme_stylebox_override("panel", sb)
		var v := U.vbox(2)
		p.add_child(v)
		v.add_child(U.label(str(t["name"]).to_upper(), 15, U.WARN if mine else U.TEXT, true))
		for d in t["drivers"]:
			var drv: Dictionary = Game.drivers[d["id"]]
			var row := U.hbox(8)
			var r := Market.rating_of(drv)
			var rl := U.label(str(r), 16, Market.rating_color(r), true)
			rl.custom_minimum_size = Vector2(28, 0)
			row.add_child(rl)
			var nl := U.label(str(d["name"]), 14, U.TEXT, true)
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(nl)
			if int(drv["contract"].get("end", 0)) >= Game.year and _is_new(drv):
				row.add_child(U.chip("Neu", U.ACCENT))
			v.add_child(row)
		grid.add_child(p)
	right.add_child(U.primary_button("ZUR SAISON-ZENTRALE", func(): main.show_hub(), 0, 54 if not U.is_mobile() else 44))
	var cols := U.columns([
		{"name": "Transfers", "node": left, "min": 470.0, "self_scroll": true},
		{"name": "Aufstellung", "node": right, "grow": true, "self_scroll": true},
	], 14)
	root.add_child(cols)
	if U.is_mobile():
		(cols as TabContainer).current_tab = 1


## Neu im Team = Vertrag wurde in der Marktphase geschlossen (Vertragsbeginn dieses Jahr).
func _is_new(d: Dictionary) -> bool:
	for n in Game.market_log:
		if n["kind"] in ["signing", "poach", "transfer"] and str(n["text"]).begins_with(str(d["name"])):
			return true
	return false

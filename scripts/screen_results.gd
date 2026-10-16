extends Control
## Rennergebnis: Podium, Klassifikation, Punkte, Einnahmen, Meisterschaftsstand.

const U = preload("res://scripts/ui.gd")

var main


func _ready() -> void:
	U.fill(self)
	add_child(U.backdrop())
	var margin := U.screen_margin(self, 22)
	var M := U.is_mobile()
	var root := U.vbox(6 if M else 12)
	margin.add_child(root)

	var res: Dictionary = Game.last_result
	var race: Dictionary = res["race"]
	var head := U.hbox(12)
	root.add_child(head)
	var tb := U.title_bar("Ergebnis", "%s %d" % [race["name"], Game.year])
	tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tb)
	var inc := U.vbox(0)
	inc.add_child(U.label("BILANZ DIESES RENNENS", 11, U.MUTED, true))
	inc.add_child(U.label("%+.1f Mio. $" % (float(res["income"]) - float(res.get("salaries", 0.0))), 24, U.GOOD, true))
	inc.add_child(U.label("Einnahmen %.1f  |  Gehälter %.1f" % [float(res["income"]), float(res.get("salaries", 0.0))], 12, U.MUTED))
	head.add_child(inc)
	if M:
		head.add_child(U.primary_button("WEITER", func(): main.show_hub(), 120, 42))

	var rows: Array = res["rows"]
	if not M:
		root.add_child(_podium(rows))

	var p1 := U.panel(14, U.ACCENT)
	p1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p1.add_child(sc)
	var g := GridContainer.new()
	g.columns = 8
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 3)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(g)
	for h in ["POS", "", "FAHRER", "ZEIT / ABSTAND", "BESTE RUNDE", "STOPPS", "START", "PKT"]:
		g.add_child(U.label(h, 11, U.MUTED, true))
	for r in rows:
		var col: Color = U.WARN if r["player"] else U.TEXT
		if int(r["state"]) == 3:
			col = U.MUTED
		g.add_child(U.label(str(r["pos"]), 16, col, true))
		g.add_child(U.color_bar(r["color"], 5, 20))
		var nm := U.label("%s  %s" % [r["code"], r["name"]], 15, col, r["player"])
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(nm)
		var gap := ""
		if int(r["state"]) == 3:
			gap = r["out"]
		elif int(r["pos"]) == 1:
			gap = _race_time(float(r["time"]))
		else:
			gap = r["gap"]
		g.add_child(U.label(gap, 14, U.BAD if int(r["state"]) == 3 else col))
		var bl := _fmt(float(r["best"]))
		var is_fl: bool = r["code"] == res["fastest"]
		g.add_child(U.label(bl + ("  FL" if is_fl else ""), 14, U.PURPLE if is_fl else col))
		g.add_child(U.label(str(r["stops"]), 14, col))
		g.add_child(U.label(str(r["grid"]), 14, col))
		g.add_child(U.label(U.fmt_pts(float(r["points"])) if float(r["points"]) > 0.0 else "", 15, U.GOOD, true))

	var p2 := U.panel(14, U.WARN)
	p2.custom_minimum_size = Vector2(380, 0)
	var v := U.vbox(4)
	p2.add_child(v)
	v.add_child(U.heading("Fahrer-WM", 18))
	var pos := 1
	for d in Game.driver_standings():
		if pos > 12:
			break
		var col2: Color = U.WARN if d["team_id"] == Game.team_id else U.TEXT
		var row := U.hbox(8)
		var pl := U.label(str(pos), 15, U.MUTED, true)
		pl.custom_minimum_size = Vector2(24, 0)
		row.add_child(pl)
		row.add_child(U.color_bar(d["color"], 4, 18))
		var nl := U.label("%s  %s" % [d["code"], d["name"]], 14, col2, d["team_id"] == Game.team_id)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nl)
		row.add_child(U.label(U.fmt_pts(d["points"]), 15, col2, true))
		v.add_child(row)
		pos += 1
	v.add_child(U.spacer())
	v.add_child(U.primary_button("WEITER ZUR SAISON-ZENTRALE", func(): main.show_hub(), 0, 56))
	var cols := U.columns([
		{"name": "Ergebnis", "node": p1, "grow": true, "self_scroll": true},
		{"name": "WM-Stand", "node": p2, "min": 380.0},
	], 14)
	root.add_child(cols)


func _podium(rows: Array) -> Control:
	var box := U.hbox(12)
	var order := [1, 0, 2]   # Silber, Gold, Bronze nebeneinander
	var cols_c := [Color("c9ced8"), Color("ffd24a"), Color("d08a52")]
	var heights := [96, 120, 84]
	for k in 3:
		var idx: int = order[k]
		if idx >= rows.size():
			continue
		var r: Dictionary = rows[idx]
		var p := U.panel(10)
		var sb := U.button_style(Color(0.1, 0.12, 0.17, 0.95), r["color"], 0, 3)
		sb.border_width_top = 5
		sb.border_color = cols_c[k]
		sb.set_content_margin_all(10)
		p.add_theme_stylebox_override("panel", sb)
		p.custom_minimum_size = Vector2(0, heights[k])
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := U.hbox(12)
		p.add_child(h)
		var big := U.label("P%d" % (idx + 1), 40, cols_c[k], true)
		h.add_child(big)
		h.add_child(U.color_bar(r["color"], 6, 54))
		var v := U.vbox(0)
		v.add_child(U.label("%s %s" % [r["code"], r["name"]], 20, U.WARN if r["player"] else U.TEXT, true))
		v.add_child(U.label(str(r["team"]).to_upper(), 12, U.MUTED, true))
		var tt := _race_time(float(r["time"])) if idx == 0 else str(r["gap"])
		v.add_child(U.label(tt, 14, U.TEXT))
		h.add_child(v)
		box.add_child(p)
	return box


func _fmt(t: float) -> String:
	if t <= 0.0:
		return "--"
	var m := int(t / 60.0)
	return "%d:%06.3f" % [m, t - m * 60.0]


func _race_time(t: float) -> String:
	var h := int(t / 3600.0)
	var m := int((t - h * 3600.0) / 60.0)
	return "%d:%02d:%06.3f" % [h, m, t - h * 3600.0 - m * 60.0]

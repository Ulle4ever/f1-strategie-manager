extends VBoxContainer
## Teamprofil-Karte: Kopfbereich in Teamfarbe mit Wappen und Auto, Eckdaten, Charakter, Autoprofil, Fahrer.

const U = preload("res://scripts/ui.gd")
const TeamStyle = preload("res://scripts/team_style.gd")
const Market = preload("res://scripts/market.gd")
const Field = preload("res://scripts/field.gd")


class Banner extends Control:
	var team_id := ""
	var team_name := ""

	func _init() -> void:
		custom_minimum_size = Vector2(0, 118)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var col: Color = DB.team_color(team_id)
		var sec := TeamStyle.second_color(team_id)
		var w := size.x
		var h := size.y
		# Verlauf in Teamfarbe
		var steps := 24
		for i in steps:
			var f := float(i) / steps
			draw_rect(Rect2(w * f, 0, w / steps + 1.0, h), col.lerp(col.lightened(0.35), f * f))
		# Diagonale Zierstreifen in der Zweitfarbe
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.46, 0), Vector2(w * 0.52, 0), Vector2(w * 0.40, h), Vector2(w * 0.34, h)]), Color(sec, 0.85))
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.55, 0), Vector2(w * 0.57, 0), Vector2(w * 0.45, h), Vector2(w * 0.43, h)]), Color(sec, 0.5))
		var f := U.font(true)
		var tc := Color.WHITE if col.get_luminance() < 0.6 else Color("0b0e14")
		TeamStyle.draw_crest(self, Vector2(54, h * 0.5), 38.0, team_id)
		draw_string(f, Vector2(104, h * 0.5 - 4), team_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w * 0.6 - 110, 24 if w > 480 else 20, tc)
		var inf := TeamStyle.info(team_id)
		draw_string(U.font(false), Vector2(104, h * 0.5 + 18), "%s  |  seit %s" % [inf["hq"], str(inf["founded"]) if int(inf["founded"]) > 0 else "?"], HORIZONTAL_ALIGNMENT_LEFT, w * 0.6 - 110, 12, Color(tc, 0.85))
		TeamStyle.draw_car(self, Vector2(w - 118, h * 0.5), 170.0, 0.0, team_id)


func setup(team_id: String, show_drivers := true) -> void:
	add_theme_constant_override("separation", 8)
	var team: Dictionary = Game.get_team(team_id)
	var inf := TeamStyle.info(team_id)
	var bn := Banner.new()
	bn.team_id = team_id
	bn.team_name = str(team.get("name", team_id))
	add_child(bn)
	# Eckdaten
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 4)
	var rank: int = Game.team_rank(team_id) + 1
	g.add_child(U.stat("Stärke", "Platz %d" % rank))
	g.add_child(U.stat("Titel", "%d" % int(inf["titles"]) if int(inf["titles"]) > 0 else "keine"))
	g.add_child(U.stat("Punkte", U.fmt_pts(float(Game.team_points.get(team_id, 0.0)))))
	g.add_child(U.stat("Saison", str(Game.year)))
	add_child(g)
	var tl := U.label(str(inf["tag"]), 14, U.TEXT)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(tl)
	var note := Field.team_note(team_id)
	if note != "":
		add_child(U.label(note, 13, U.WARN, true))
	# Autoprofil
	var prof: Dictionary = Game.team_profile(team_id)
	var base: Dictionary = Game.team_profile(team_id, true)
	add_child(U.section("Autoprofil", 12))
	var rows := [["Abtrieb", "df", "Topspeed", "Abtrieb"], ["Motor", "power", "schwach", "stark"], ["Reifenschonung", "tyre", "frisst", "schont"], ["Regen", "wet", "schwach", "stark"]]
	for r in rows:
		var bar = load("res://scripts/profile_bar.gd").new()
		bar.setup(str(r[0]), float(prof.get(r[1], 0.0)), str(r[2]), str(r[3]), TeamStyle.ui_color(team_id), float(base.get(r[1], 0.0)))
		add_child(bar)
	add_child(U.label("Heller Kreis: Auto zum Saisonstart, voller Kreis: mit der Entwicklung dieser Saison.", 11, U.MUTED))
	if show_drivers:
		add_child(U.section("Fahrer", 12))
		for d in Market.current_drivers(team_id):
			var row := U.hbox(8)
			row.add_child(U.color_bar(TeamStyle.ui_color(team_id), 5, 20))
			var nm := U.label("#%s  %s" % [str(d.get("number", "")), str(d["name"])], 15, U.TEXT, true)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(nm)
			row.add_child(U.label("Wertung %d" % int(Market.rating_of(d)), 13, U.MUTED))
			add_child(row)

extends Control
## Startbildschirm: Saison (2000-2026) wählen, Team als Karte auswählen, Spielstand laden.

const U = preload("res://scripts/ui.gd")

var main
var year_option: OptionButton
var grid: GridContainer
var info_label: Label
var start_button: Button
var selected_label: Label
var selected_team := ""
var team_buttons := {}
var size_button: Button
var teams: Array = []


func _ready() -> void:
	U.fill(self)
	add_child(U.backdrop())
	var margin := U.screen_margin(self, 26)
	var M := U.is_mobile()
	var root := U.vbox(6 if M else 12)
	margin.add_child(root)

	root.add_child(U.title_bar("F1 Strategie-Manager", "" if M else "Teamchef-Simulation  2000 - 2026"))
	var intro := U.label("Wähle eine Startsaison und ein Team. Du entscheidest über Reifen, Boxenstopps, Fahrstil, Entwicklung und den Fahrermarkt. Die Karriere läuft über viele Saisons: Verträge, Wechsel, Rücktritte und Nachwuchs. Rennen über die echte Distanz, bis 256x vorspulbar.", 16, U.MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not M:
		root.add_child(intro)

	var top := U.hbox(14)
	root.add_child(top)
	top.add_child(U.heading("Saison", 20, U.MUTED))
	year_option = OptionButton.new()
	year_option.custom_minimum_size = Vector2(130 if M else 150, 42)
	year_option.add_theme_font_size_override("font_size", 20 if M else 22)
	for y in DB.years():
		year_option.add_item(str(y), y)
	year_option.select(0)
	year_option.item_selected.connect(_on_year)
	top.add_child(year_option)
	info_label = U.label("", 16, U.MUTED)
	info_label.visible = not M
	top.add_child(info_label)
	top.add_child(U.spacer())
	if Game.has_save():
		top.add_child(U.button("Laden" if M else "Spielstand laden", _on_load, 90 if M else 190, 42))
	if M:
		size_button = U.button("Größe: %s" % U.LEVEL_NAMES[U.ui_level()], _on_size, 120, 42)
		top.add_child(size_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	var foot := U.hbox(14)
	root.add_child(foot)
	selected_label = U.label("Kein Team gewählt", 18, U.MUTED, true)
	foot.add_child(selected_label)
	foot.add_child(U.spacer())
	if not M:
		foot.add_child(U.label("Daten: Jolpica-F1 (Ergast), OpenStreetMap (ODbL)", 13, U.MUTED))
	start_button = U.primary_button("KARRIERE STARTEN", _on_start, 220 if M else 280, 46 if M else 54)
	start_button.disabled = true
	foot.add_child(start_button)
	_on_year(0)


func _on_year(_i: int) -> void:
	var y := year_option.get_selected_id()
	teams = DB.build_teams(y)
	var cal: Array = DB.season(y)["calendar"]
	info_label.text = "%d Rennen  |  %d Teams" % [cal.size(), teams.size()]
	U.clear(grid)
	team_buttons = {}
	selected_team = ""
	selected_label.text = "Kein Team gewählt"
	start_button.disabled = true
	var rank := 1
	var best := 0.0
	var worst := 2.0
	for t in teams:
		best = maxf(best, float(t["pace"]))
		worst = minf(worst, float(t["pace"]))
	for t in teams:
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 62 if U.is_mobile() else 82)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col: Color = t["color"]
		b.add_theme_stylebox_override("normal", U.button_style(U.PANEL2, col, 10))
		b.add_theme_stylebox_override("hover", U.button_style(U.PANEL3, col, 14))
		var pressed := U.button_style(Color("2c1315"), col, 14)
		pressed.border_width_top = 2
		pressed.border_width_right = 2
		pressed.border_width_bottom = 2
		pressed.border_color = col
		b.add_theme_stylebox_override("pressed", pressed)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		U.fill(row)
		row.offset_left = 28
		row.offset_right = -12
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rk := U.label(str(rank), 26 if U.is_mobile() else 34, Color(1, 1, 1, 0.22), true)
		rk.custom_minimum_size = Vector2(34 if U.is_mobile() else 46, 0)
		rk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(rk)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tn := U.label(str(t["name"]).to_upper(), 17 if U.is_mobile() else 21, U.TEXT, true)
		tn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(tn)
		var names := ""
		for d in t["drivers"]:
			names += "%s    " % d["name"]
		var dn := U.label(names, 12 if U.is_mobile() else 14, U.MUTED)
		dn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(dn)
		row.add_child(info)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(64 if U.is_mobile() else 110, 8)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.max_value = 100.0
		bar.value = 8.0 + 92.0 * (float(t["pace"]) - worst) / maxf(best - worst, 0.0001)
		var fillbox := U.button_style(col, col, 0, 2)
		bar.add_theme_stylebox_override("fill", fillbox)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bar)
		b.add_child(row)
		b.pressed.connect(_on_team.bind(t["id"], t["name"]))
		grid.add_child(b)
		team_buttons[t["id"]] = b
		rank += 1


func _on_size() -> void:
	U.set_ui_level((U.ui_level() + 1) % U.LEVEL_NAMES.size())
	size_button.text = "Größe: %s" % U.LEVEL_NAMES[U.ui_level()]
	main.apply_scale()


func _on_team(id: String, tname: String) -> void:
	selected_team = id
	for k in team_buttons.keys():
		team_buttons[k].set_pressed_no_signal(k == id)
	selected_label.text = "Gewählt: %s" % tname
	selected_label.add_theme_color_override("font_color", U.TEXT)
	start_button.disabled = false


func _on_start() -> void:
	if selected_team == "":
		return
	Game.new_season(year_option.get_selected_id(), selected_team)
	main.show_hub()


func _on_load() -> void:
	if Game.load_game():
		main.show_hub()

extends Control
## Startbildschirm: Saison (2000-2026) wählen, Team als Karte auswählen, Spielstand laden.

const U = preload("res://scripts/ui.gd")
const TeamStyle = preload("res://scripts/team_style.gd")
const TeamCrest = preload("res://scripts/team_crest.gd")

var main
var year_option: OptionButton
var grid: GridContainer
var info_label: Label
var start_button: Button
var selected_label: Label
var selected_team := ""
var team_buttons := {}
var solo_mode := false
var mode_button: Button
var size_button: Button
var year_button: Button
var picker: Control = null
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
	year_option.visible = false          # Datenmodell; Auswahl über den eigenen Auswahldialog (Popup-Listen sind am Handy unzuverlässig)
	top.add_child(year_option)
	year_button = U.button("%d  v" % year_option.get_selected_id(), _open_year_picker, 130 if M else 150, 42)
	year_button.add_theme_font_size_override("font_size", 20 if M else 22)
	top.add_child(year_button)
	info_label = U.label("", 16, U.MUTED)
	info_label.visible = not M
	top.add_child(info_label)
	top.add_child(U.spacer())
	if Game.has_save():
		var si: Dictionary = Game.save_info()
		var lt := "Laden" if M else "Spielstand laden"
		if not si.is_empty() and not M:
			lt = "Laden: Saison %d, Rennen %d" % [int(si["year"]), int(si["round"]) + 1]
		top.add_child(U.button(lt, _on_load, 90 if M else 250, 42))
	if not M:
		top.add_child(U.button("Sicherung kopieren", _on_backup_copy, 170, 42))
		top.add_child(U.button("Sicherung einfügen", _on_backup_paste, 170, 42))
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
	var content := U.vbox(10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	content.add_child(grid)
	if OS.has_feature("web"):
		content.add_child(_web_tools())

	var foot := U.hbox(14)
	root.add_child(foot)
	selected_label = U.label("Kein Team gewählt", 18, U.MUTED, true)
	foot.add_child(selected_label)
	foot.add_child(U.spacer())
	if not M:
		foot.add_child(U.label("Daten: Jolpica-F1 (Ergast), OpenStreetMap (ODbL)", 13, U.MUTED))
	mode_button = U.button("Modus: Teamchef (2 Autos)", _on_mode, 230 if M else 270, 46 if M else 54)
	mode_button.add_theme_font_size_override("font_size", 14 if M else 16)
	foot.add_child(mode_button)
	start_button = U.primary_button("KARRIERE STARTEN", _on_start, 200 if M else 280, 46 if M else 54)
	start_button.disabled = true
	foot.add_child(start_button)
	_on_year(0)


## Saison-Auswahl als eigener Dialog mit scrollbarem Raster.
func _open_year_picker() -> void:
	if picker != null:
		return
	picker = Control.new()
	picker.add_to_group("modal")
	U.fill(picker)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.08, 0.18, 0.55)
	U.fill(dim)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_picker())
	picker.add_child(dim)
	var center := CenterContainer.new()
	U.fill(center)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker.add_child(center)
	var panel := U.panel(12, U.ACCENT)
	var M := U.is_mobile()
	panel.custom_minimum_size = Vector2(360 if M else 520, 0)
	center.add_child(panel)
	var v := U.vbox(8)
	panel.add_child(v)
	var head := U.hbox(8)
	head.add_child(U.heading("Saison wählen", 18))
	head.add_child(U.spacer())
	head.add_child(U.button("Schließen", _close_picker, 0, 36))
	v.add_child(head)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, minf(get_viewport_rect().size.y * 0.62, 360.0))
	v.add_child(sc)
	var g := GridContainer.new()
	g.columns = 4 if M else 5
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	sc.add_child(g)
	var cur := year_option.get_selected_id()
	for i in year_option.item_count:
		var y := year_option.get_item_id(i)
		var b := Button.new()
		b.text = str(y)
		b.toggle_mode = true
		b.button_pressed = y == cur
		b.custom_minimum_size = Vector2(0, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_pick_year.bind(i))
		g.add_child(b)
	add_child(picker)


func _pick_year(idx: int) -> void:
	if U.touch_scrolled:
		return
	year_option.select(idx)
	_on_year(idx)
	_close_picker()


func _close_picker() -> void:
	if picker != null:
		picker.queue_free()
		picker = null


func _on_year(_i: int) -> void:
	var y := year_option.get_selected_id()
	if year_button != null:
		year_button.text = "%d  v" % y
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
		var col: Color = TeamStyle.ui_color(t["id"])
		b.add_theme_stylebox_override("normal", U.button_style(Color.WHITE.lerp(col, 0.07), Color(col, 0.55), 1))
		b.add_theme_stylebox_override("hover", U.button_style(Color.WHITE.lerp(col, 0.14), col, 2))
		var pressed := U.button_style(Color.WHITE.lerp(col, 0.22), col, 2)
		b.add_theme_stylebox_override("pressed", pressed)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		U.fill(row)
		row.offset_left = 14
		row.offset_right = -12
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rk := U.label(str(rank), 22 if U.is_mobile() else 28, U.tint(0.28), true)
		rk.custom_minimum_size = Vector2(30 if U.is_mobile() else 38, 0)
		rk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(rk)
		row.add_child(TeamCrest.make(t["id"], 40.0 if U.is_mobile() else 54.0))
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
		var fillbox := U.button_style(col, col, 0, 5)
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


func _on_mode() -> void:
	solo_mode = not solo_mode
	mode_button.text = "Modus: 1 Fahrer" if solo_mode else "Modus: Teamchef (2 Autos)"


func _on_start() -> void:
	if selected_team == "":
		return
	Game.new_season(year_option.get_selected_id(), selected_team)
	Game.solo_code = "*" if solo_mode else ""
	main.show_hub()


const SHARP := [[1.0, "Sparsam"], [1.25, "Normal"], [1.5, "Hoch"], [2.0, "Sehr hoch"], [3.0, "Maximal"]]


## Web: Bildschärfe wählen (Render-Auflösung) und App installieren.
func _web_tools() -> Control:
	var row := U.hbox(10)
	var cur := float(JavaScriptBridge.eval("window.f1DprCap || 1", true))
	var name := "%sx" % _num(cur)
	for s in SHARP:
		if is_equal_approx(float(s[0]), cur):
			name = "%s (%sx)" % [s[1], _num(cur)]
	var sb := U.button("Schärfe: %s" % name, _on_sharp, 0, 40)
	sb.tooltip_text = "Höhere Schärfe: schärfere Schrift, braucht aber mehr Grafikspeicher (alte Geräte: 'Normal' oder 'Sparsam' wählen). Die Seite lädt neu."
	row.add_child(sb)
	var standalone := bool(JavaScriptBridge.eval("window.f1Standalone ? window.f1Standalone() : false", true))
	if not standalone:
		row.add_child(U.button("App installieren", _on_install, 0, 40))
	row.add_child(U.spacer())
	return row


func _num(v: float) -> String:
	return ("%.2f" % v).rstrip("0").rstrip(".")


func _on_sharp() -> void:
	var cur := float(JavaScriptBridge.eval("window.f1DprCap || 1", true))
	var idx := 0
	for i in SHARP.size():
		if float(SHARP[i][0]) <= cur + 0.01:
			idx = i
	var nxt: float = float(SHARP[(idx + 1) % SHARP.size()][0])
	if Game.active:
		Game.save()
	JavaScriptBridge.eval("window.f1SetDpr(%s)" % str(nxt), true)


func _on_install() -> void:
	if bool(JavaScriptBridge.eval("!!window.f1CanInstall", true)):
		JavaScriptBridge.eval("window.f1Install()", true)
		return
	var ua := str(JavaScriptBridge.eval("navigator.userAgent", true))
	if "iPhone" in ua or "iPad" in ua or "Macintosh" in ua:
		selected_label.text = "iPhone/iPad: In Safari unten auf Teilen tippen, dann 'Zum Home-Bildschirm'."
	else:
		selected_label.text = "Im Browser-Menü 'App installieren' bzw. 'Zum Startbildschirm hinzufügen' wählen."
	selected_label.add_theme_color_override("font_color", U.WARN)


func _on_backup_copy() -> void:
	if not Game.has_save():
		Game.save()
	DisplayServer.clipboard_set(Game.export_text())
	selected_label.text = "Sicherung in der Zwischenablage (zum Aufbewahren in eine Notiz einfügen)"


func _on_backup_paste() -> void:
	if Game.import_text(DisplayServer.clipboard_get()):
		main.show_hub()
	else:
		selected_label.text = "Zwischenablage enthält keine gültige Sicherung"
		selected_label.add_theme_color_override("font_color", U.BAD)


func _on_load() -> void:
	if Game.load_game():
		main.show_hub()

extends RefCounted
## Gemeinsame UI-Hilfen im F1-Broadcast-Stil: Farben, Schrift, Theme, Widget-Fabrik.

const BG0 := Color("090b10")
const BG1 := Color("141824")
const PANEL := Color(0.075, 0.09, 0.13, 0.93)
const PANEL2 := Color("1a202d")
const PANEL3 := Color("252d3f")
const LINE := Color(1, 1, 1, 0.09)
const RADIUS := 9
const ACCENT := Color("e10600")
const ACCENT_HI := Color("ff2a1f")
const ACCENT_DARK := Color("7a0300")
const TEXT := Color("f3f5f9")
const MUTED := Color("8d96aa")
const GOOD := Color("2ee27e")
const WARN := Color("ffc61a")
const BAD := Color("ff4d42")
const PURPLE := Color("c05cff")
const BLUE := Color("3d8bff")
# alte Namen
const BG := BG0

static var _font: Font
static var _font_bold: Font
static var _mobile := -1
static var touch_scrolled := false   # wahr, solange ein Wisch eine Liste scrollt: Antippen-Aktionen werden dann ignoriert
static var _level := -1
const LEVEL_NAMES := ["Klein", "Mittel", "Groß"]
const LEVEL_HEIGHTS := [420, 360, 310]   # virtuelle Bildschirmhöhe am Handy: kleiner = größere Darstellung


## Anzeigegröße am Handy (0 = klein ... 2 = groß), gespeichert in user://settings.cfg.
static func ui_level() -> int:
	if _level < 0:
		_level = 2
		var env := OS.get_environment("F1_SCALE")
		if env != "":
			_level = clampi(int(env), 0, 2)
		else:
			var cf := ConfigFile.new()
			if cf.load("user://settings.cfg") == OK:
				_level = clampi(int(cf.get_value("anzeige", "stufe", 2)), 0, 2)
	return _level


static func set_ui_level(l: int) -> void:
	_level = clampi(l, 0, 2)
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	cf.set_value("anzeige", "stufe", _level)
	cf.save("user://settings.cfg")


## Basisgröße des virtuellen Bildschirms im Handy-Modus.
static func mobile_base_size() -> Vector2i:
	var h: int = LEVEL_HEIGHTS[ui_level()]
	return Vector2i(int(round(float(h) * 900.0 / 420.0)), h)


## Handy-Modus: erzwingbar per Umgebungsvariable F1_MOBILE=1, Kommandozeile (--mobile), Webadresse (?mobile=1)
## oder automatisch auf Touchgeräten mit kleinem Fenster.
static func is_mobile() -> bool:
	if _mobile < 0:
		_mobile = 0
		if OS.get_environment("F1_MOBILE") == "1" or "--mobile" in OS.get_cmdline_user_args() or "--mobile" in OS.get_cmdline_args():
			_mobile = 1
		elif OS.has_feature("web"):
			var flag = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('mobile')", true)
			if flag != null and str(flag) == "1":
				_mobile = 1
			elif flag != null and str(flag) == "0":
				_mobile = 0
			elif DisplayServer.is_touchscreen_available():
				var win := DisplayServer.window_get_size()
				if mini(win.x, win.y) < 1100:
					_mobile = 1
		elif OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
			_mobile = 1
	return _mobile == 1


static func _load_font(path: String, weight: int) -> Font:
	var f = load(path)
	if f == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Helvetica Neue", "Arial"])
		sf.font_weight = weight
		return sf
	var ff: FontFile = f
	if ff.fallbacks.is_empty():
		ff.fallbacks = [ThemeDB.fallback_font]
	return ff


static func font(bold := false) -> Font:
	if _font == null:
		_font = _load_font("res://fonts/TitilliumWeb-Regular.ttf", 450)
		_font_bold = _load_font("res://fonts/TitilliumWeb-Bold.ttf", 750)
	return _font_bold if bold else _font


static func _box(col: Color, radius := RADIUS, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	return sb


## Knopf-/Balkenstil: flach mit feinem Rand (edge). left >= 2 betont den Rand (Auswahl), 0 = ohne Rand.
static func button_style(bg: Color, edge: Color, left := 4, radius := RADIUS) -> StyleBoxFlat:
	var sb := _box(bg, radius, Color(0, 0, 0, 0), 0)
	sb.border_color = edge
	sb.set_border_width_all(0 if left <= 0 else (1 if left < 2 else 2))
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	return sb


static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = font(false)
	th.default_font_size = 17
	th.set_font("font", "Label", font(false))
	th.set_font("font", "Button", font(true))
	th.set_font_size("font_size", "Button", 17)
	th.set_stylebox("normal", "Button", button_style(PANEL2, Color(1, 1, 1, 0.12), 1))
	th.set_stylebox("hover", "Button", button_style(PANEL3, Color(ACCENT, 0.85), 1))
	th.set_stylebox("pressed", "Button", button_style(Color("43141a"), ACCENT_HI, 2))
	th.set_stylebox("disabled", "Button", button_style(Color(0.07, 0.08, 0.11, 0.8), Color(1, 1, 1, 0.05), 1))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color("525b6d"))
	th.set_stylebox("panel", "PanelContainer", _box(PANEL, RADIUS + 1, LINE, 1))
	th.set_color("font_color", "Label", TEXT)
	th.set_stylebox("panel", "PopupMenu", _box(PANEL2, 8, LINE, 1))
	th.set_stylebox("hover", "PopupMenu", _box(PANEL3, 6))
	th.set_color("font_color", "PopupMenu", TEXT)
	th.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	th.set_stylebox("normal", "OptionButton", button_style(PANEL2, Color(1, 1, 1, 0.12), 1))
	th.set_stylebox("hover", "OptionButton", button_style(PANEL3, Color(ACCENT, 0.85), 1))
	th.set_stylebox("pressed", "OptionButton", button_style(PANEL3, ACCENT, 1))
	th.set_color("font_color", "OptionButton", TEXT)
	th.set_stylebox("panel", "TabContainer", _box(PANEL, RADIUS + 1, LINE, 1))
	var tab_sel := _box(Color("2a1519"), 8, Color(ACCENT, 0.9), 1)
	tab_sel.content_margin_top = 6
	tab_sel.content_margin_bottom = 6
	var tab_un := _box(Color(0.1, 0.12, 0.17, 0.9), 8, Color(1, 1, 1, 0.07), 1)
	tab_un.content_margin_top = 6
	tab_un.content_margin_bottom = 6
	var tab_hv := _box(PANEL2, 8, Color(1, 1, 1, 0.12), 1)
	tab_hv.content_margin_top = 6
	tab_hv.content_margin_bottom = 6
	th.set_stylebox("tab_selected", "TabContainer", tab_sel)
	th.set_stylebox("tab_unselected", "TabContainer", tab_un)
	th.set_stylebox("tab_hovered", "TabContainer", tab_hv)
	th.set_color("font_selected_color", "TabContainer", Color.WHITE)
	th.set_color("font_unselected_color", "TabContainer", MUTED)
	th.set_color("font_hovered_color", "TabContainer", TEXT)
	th.set_font("font", "TabContainer", font(true))
	th.set_font_size("font_size", "TabContainer", 17)
	# Scrollbars dezenter
	var sbar := StyleBoxFlat.new()
	sbar.bg_color = Color(1, 1, 1, 0.04)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(1, 1, 1, 0.22)
	grab.set_corner_radius_all(3)
	th.set_stylebox("scroll", "VScrollBar", sbar)
	th.set_stylebox("grabber", "VScrollBar", grab)
	th.set_stylebox("grabber_highlight", "VScrollBar", grab)
	th.set_stylebox("grabber_pressed", "VScrollBar", grab)
	# Fortschrittsbalken
	var pbg := StyleBoxFlat.new()
	pbg.bg_color = Color(1, 1, 1, 0.08)
	pbg.set_corner_radius_all(5)
	var pfill := StyleBoxFlat.new()
	pfill.bg_color = Color.WHITE
	pfill.set_corner_radius_all(5)
	th.set_stylebox("background", "ProgressBar", pbg)
	th.set_stylebox("fill", "ProgressBar", pfill)
	th.set_stylebox("normal", "SpinBox", _box(PANEL2, 7, LINE, 1))
	var trk := StyleBoxFlat.new()
	trk.bg_color = PANEL3
	trk.set_corner_radius_all(5)
	trk.content_margin_top = 3
	trk.content_margin_bottom = 3
	th.set_stylebox("slider", "HSlider", trk)
	var ga := StyleBoxFlat.new()
	ga.bg_color = ACCENT
	ga.set_corner_radius_all(5)
	ga.content_margin_top = 3
	ga.content_margin_bottom = 3
	th.set_stylebox("grabber_area", "HSlider", ga)
	th.set_stylebox("grabber_area_highlight", "HSlider", ga)
	th.set_color("font_color", "CheckBox", TEXT)
	th.set_color("font_hover_color", "CheckBox", Color.WHITE)
	th.set_font("font", "CheckBox", font(false))
	th.set_icon("checked", "CheckBox", _check_icon(true))
	th.set_icon("unchecked", "CheckBox", _check_icon(false))
	th.set_icon("checked_disabled", "CheckBox", _check_icon(true))
	th.set_icon("unchecked_disabled", "CheckBox", _check_icon(false))
	th.set_font_size("font_size", "CheckBox", 14)
	return th


static var _chk_on: ImageTexture
static var _chk_off: ImageTexture


## CheckBox im F1-Stil (eigene Symbole direkt am Knoten, unabhängig vom Theme).
static func checkbox(text := "") -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	if _chk_on == null:
		_chk_on = _check_icon(true)
		_chk_off = _check_icon(false)
	for n in ["checked", "checked_disabled"]:
		c.add_theme_icon_override(n, _chk_on)
	for n in ["unchecked", "unchecked_disabled"]:
		c.add_theme_icon_override(n, _chk_off)
	c.add_theme_font_override("font", font(false))
	c.add_theme_font_size_override("font_size", 14)
	c.add_theme_color_override("font_color", TEXT)
	c.add_theme_color_override("font_hover_color", Color.WHITE)
	c.add_theme_color_override("font_pressed_color", Color.WHITE)
	c.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	return c


## Selbst gezeichnetes Häkchen-Kästchen für CheckBox im F1-Stil.
static func _check_icon(checked: bool) -> ImageTexture:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bg := ACCENT if checked else Color("0d1017")
	var edge := Color("ffffff") if checked else Color("b4bccd")
	for y in range(2, 22):
		for x in range(2, 22):
			var border := x < 4 or x > 19 or y < 4 or y > 19
			img.set_pixel(x, y, edge if border else bg)
	if checked:
		var pts := [Vector2i(7, 12), Vector2i(8, 13), Vector2i(9, 14), Vector2i(10, 15), Vector2i(11, 14), Vector2i(12, 13), Vector2i(13, 12), Vector2i(14, 11), Vector2i(15, 10), Vector2i(16, 9)]
		for p in pts:
			for dx in 2:
				for dy in 2:
					img.set_pixel(p.x + dx, p.y + dy, Color.WHITE)
	return ImageTexture.create_from_image(img)


static func label(text: String, size := 17, col := TEXT, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if bold:
		l.add_theme_font_override("font", font(true))
	return l


static func heading(text: String, size := 22, col := TEXT) -> Label:
	return label(text.to_upper(), size, col, true)


static func button(text: String, cb = null, min_w := 0, min_h := 38) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, min_h)
	if cb != null:
		b.pressed.connect(cb)
	return b


## Roter Haupt-Button.
static func primary_button(text: String, cb = null, min_w := 0, min_h := 50) -> Button:
	var b := button(text, cb, min_w, min_h)
	b.add_theme_stylebox_override("normal", button_style(Color("e8261b"), Color("ff6a5e"), 1, 11))
	b.add_theme_stylebox_override("hover", button_style(ACCENT_HI, Color.WHITE, 1, 11))
	b.add_theme_stylebox_override("pressed", button_style(ACCENT_DARK, Color.WHITE, 1, 11))
	b.add_theme_stylebox_override("disabled", button_style(Color("2a1414"), Color("3a2020"), 1, 11))
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", Color.WHITE)
	return b


static func panel(margin := 14, accent := Color(0, 0, 0, 0)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _box(PANEL, RADIUS + 1, LINE, 1)
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(0, 0, 0, 0.30)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	if accent.a > 0.0:
		sb.border_width_top = 2
		sb.border_color = Color(accent, 0.6)
	p.add_theme_stylebox_override("panel", sb)
	return p


## Dezente Unterkarte innerhalb eines Panels (für Gruppen von Bedienelementen).
static func card(margin := 10, tint := Color(1, 1, 1, 0.04), edge := Color(1, 1, 1, 0.07)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _box(tint, 9, edge, 1)
	sb.set_content_margin_all(margin)
	p.add_theme_stylebox_override("panel", sb)
	return p


## Abschnittsüberschrift mit kleinem roten Marker.
static func section(text: String, size := 12) -> Control:
	var h := hbox(6)
	var m := ColorRect.new()
	m.color = ACCENT
	m.custom_minimum_size = Vector2(3, size + 2)
	m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(m)
	h.add_child(label(text.to_upper(), size, MUTED, true))
	return h


static func vbox(sep := 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func color_bar(col: Color, w := 6, h := 20) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.custom_minimum_size = Vector2(w, h)
	return r


## Kurze "Bitte warten"-Anzeige, damit der Bildschirm neu zeichnet, bevor eine längere Berechnung läuft (Browser).
static func busy(screen: Control, text: String, work: Callable) -> void:
	var p := panel(22, ACCENT)
	p.add_child(label(text, 22, TEXT, true))
	screen.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	await screen.get_tree().process_frame
	await screen.get_tree().process_frame
	work.call()
	p.queue_free()


static func fill(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func clear(node: Node) -> void:
	for ch in node.get_children():
		node.remove_child(ch)
		ch.queue_free()


static func fmt_pts(p: float) -> String:
	if is_equal_approx(p, round(p)):
		return str(int(p))
	return "%.1f" % p


## Dunkler F1-Hintergrund mit Streifen und rotem Akzent; als erstes Kind eines Bildschirms einfügen.
static func backdrop() -> Control:
	var b = load("res://scripts/backdrop.gd").new()
	fill(b)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## Überschriftsleiste mit rotem Schrägbalken. sub = Untertitel.
static func title_bar(title: String, sub := "") -> Control:
	var t = load("res://scripts/title_bar.gd").new()
	t.title = title
	t.subtitle = sub
	t.custom_minimum_size = Vector2(0, 42 if is_mobile() else 58)
	return t


## Bereiche nebeneinander (PC) oder als Reiter (Handy).
## entries: [{"name": Reitername, "node": Control, "min": Mindestbreite am PC, "grow": am PC horizontal wachsen,
##            "self_scroll": Bereich scrollt selbst (am Handy dann ohne zusätzliches Scrollen)}]
static func columns(entries: Array, sep := 14) -> Control:
	if not is_mobile():
		var h := hbox(sep)
		h.size_flags_vertical = Control.SIZE_EXPAND_FILL
		for e in entries:
			var n: Control = e["node"]
			if float(e.get("min", 0.0)) > 0.0:
				n.custom_minimum_size.x = float(e["min"])
			if bool(e.get("grow", false)):
				n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(n)
		return h
	var tc := TabContainer.new()
	tc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for e in entries:
		var n: Control = e["node"]
		n.custom_minimum_size.x = 0.0
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if bool(e.get("self_scroll", false)):
			n.name = str(e["name"])
			n.size_flags_vertical = Control.SIZE_EXPAND_FILL
			tc.add_child(n)
		else:
			var sc := ScrollContainer.new()
			sc.name = str(e["name"])
			sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			n.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			sc.add_child(n)
			tc.add_child(sc)
	return tc


static func screen_margin(screen: Control, m := 22) -> MarginContainer:
	if is_mobile():
		m = mini(m, 8)
	var margin := MarginContainer.new()
	fill(margin)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, m)
	screen.add_child(margin)
	return margin


## Kennzahl-Kachel: kleine Beschriftung, großer Wert.
static func stat(caption: String, value: String, col := TEXT) -> VBoxContainer:
	var v := vbox(0)
	v.add_child(label(caption.to_upper(), 11, MUTED, true))
	v.add_child(label(value, 20, col, true))
	return v


## Kleine farbige Marke (Chip) mit Text.
static func chip(text: String, bg := ACCENT, fg := Color.WHITE) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _box(bg, 11)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(label(text.to_upper(), 12, fg, true))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p

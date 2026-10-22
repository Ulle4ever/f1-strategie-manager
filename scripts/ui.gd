extends RefCounted
## Gemeinsame UI-Hilfen im hellen Glas-Stil: Himmelsverlauf als Grund, halbtransparente weiße Karten mit heller Kante und
## weichem Schatten (Soft UI), gerade Kanten mit kleinem Radius, Reiter mit Unterstrich, die Farbe des eigenen Teams als
## Akzent, kursive Display-Schrift (Saira) für Titel und Zahlen. TV-Grafiken (Zeitentafel, Fahrer-Panel, Karte) bleiben
## dunkel (DARK, ON_DARK). Farben, Schrift, Theme, Widget-Fabrik.

const BG0 := Color("e9eef5")            # Grund unten (Dunst)
const BG1 := Color("cbd8e6")            # Himmel oben
const PANEL := Color(1, 1, 1, 0.66)     # Glas-Karten und Panels
const PANEL2 := Color(1, 1, 1, 0.84)    # Knöpfe, Eingaben
const PANEL3 := Color("e1e7ef")         # Spuren, Chips, Hover
const LINE := Color(1, 1, 1, 0.9)       # helle Glaskante
const SHADOW := Color(0.22, 0.31, 0.45, 0.16)
const RADIUS := 6
const DARK := Color("15171d")           # TV-Grafik: Zeitentafel, Fahrer-Panel
const DARK2 := Color("1f2229")
const DARK3 := Color("2b2f38")
const TEXT := Color("1b2330")
const MUTED := Color("667085")
const INK := Color("1b2330")            # dunkle Schrift auf hellen/kräftigen Flächen (Chips)
const ON_DARK := Color("f3f4f7")        # Text auf dunklen Flächen (TV-Grafik, Karte)
const MUTED_DARK := Color("9aa0ad")
const GOOD := Color("0f9d58")
const WARN := Color("d98200")
const BAD := Color("d93025")
const PURPLE := Color("8a3fd1")
const BLUE := Color("2563eb")
const RED := Color("e10600")
const SKEW := 0.0                        # früher schräge Knöpfe/Reiter; jetzt gerade
# alte Namen
const BG := BG0

## Akzent = Farbe des eigenen Teams (während einer Karriere), sonst F1-Rot. set_accent() setzt alle Ableitungen.
static var ACCENT := RED
static var ACCENT_HI := RED.lightened(0.12)
static var ACCENT_DARK := RED.darkened(0.28)
static var ACCENT_INK := Color.WHITE     # Schrift auf Akzentflächen
static var ACCENT_TEXT := RED.darkened(0.1)   # Akzent als gut lesbare Schrift auf hellem Grund


static var _accent_raw := RED


static func set_accent(c: Color) -> bool:
	if c.is_equal_approx(_accent_raw):
		return false
	_accent_raw = c
	# sehr helle Teamfarben (weiß, hellgelb) heben sich vom hellen Grund nicht ab: abdunkeln
	var n := 0
	while c.get_luminance() > 0.68 and n < 8:
		c = c.darkened(0.1)
		n += 1
	ACCENT = c
	ACCENT_HI = c.lightened(0.12)
	ACCENT_DARK = c.darkened(0.28)
	ACCENT_INK = INK if c.get_luminance() > 0.55 else Color.WHITE
	var t := c
	while t.get_luminance() > 0.42:
		t = t.darkened(0.08)
	ACCENT_TEXT = t
	_chk_on = null
	_chk_off = null
	return true


## Dezente Tönung für Flächen auf hellem Grund (a = Stärke).
static func tint(a: float) -> Color:
	return Color(0.11, 0.15, 0.22, a)


## Glasfläche: halbtransparentes Weiß mit heller Kante und weichem Schatten (Soft UI).
static func glass(bg := PANEL, radius := RADIUS, shadow := 14) -> StyleBoxFlat:
	var sb := _box(bg, radius, LINE, 1)
	if shadow > 0:
		sb.shadow_color = SHADOW
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0, shadow * 0.4)
	return sb


static var _font: Font
static var _font_bold: Font
static var _font_display: Font
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


static var _fx := -1


## Effekte (Animationen beim Öffnen, Hochzählen, lebendiger Hintergrund, wehende Flaggen, Milchglas) an oder aus;
## gespeichert in user://settings.cfg. Aus = ruhiger und schonender für ältere Geräte. F1_FX=0 schaltet sie ab (Tests).
static func fx_on() -> bool:
	if _fx < 0:
		_fx = 1
		var env := OS.get_environment("F1_FX")
		if env != "":
			_fx = 1 if env == "1" else 0
		else:
			var cf := ConfigFile.new()
			if cf.load("user://settings.cfg") == OK:
				_fx = 1 if bool(cf.get_value("anzeige", "effekte", true)) else 0
	return _fx == 1


static func set_fx(on: bool) -> void:
	_fx = 1 if on else 0
	var cf := ConfigFile.new()
	cf.load("user://settings.cfg")
	cf.set_value("anzeige", "effekte", on)
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


## Renn-Schrift für Titel, Rundenzähler, Positionen und große Zahlen: Saira kursiv, fett und leicht breit.
static func display_font() -> Font:
	if _font_display == null:
		var base = load("res://fonts/Saira-Italic.ttf")
		if base == null:
			_font_display = font(true)
		else:
			var fv := FontVariation.new()
			fv.base_font = base
			var ts := TextServerManager.get_primary_interface()
			fv.variation_opentype = {ts.name_to_tag("wght"): 760, ts.name_to_tag("wdth"): 108}
			fv.fallbacks = [font(true)]
			_font_display = fv
	return _font_display


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
	sb.anti_aliasing = true
	return sb


## Knopf-/Balkenstil: flache Fläche; bei Auswahl/Status (left >= 2) ein Farbstreifen links in edge, sonst randlos.
static func button_style(bg: Color, edge: Color, left := 4, radius := 5) -> StyleBoxFlat:
	var sb := _box(bg, mini(radius, 6), Color(0, 0, 0, 0), 0)
	sb.border_color = edge
	sb.set_border_width_all(0)
	if left >= 2:
		sb.border_width_left = 3
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	return sb


## Stil für Hauptknöpfe, Marken und Chips (früher schräg, jetzt gerade mit kleinem Radius).
static func slant_style(bg: Color, edge := Color(0, 0, 0, 0), bw := 0, radius := 5) -> StyleBoxFlat:
	var sb := _box(bg, mini(radius, 6), edge, bw)
	sb.skew = Vector2(SKEW, 0)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	return sb


## Reiter gerade mit Unterstrich: gewählt = helle Glasfläche mit Akzentlinie unten, sonst nur Schrift.
static func tab_style(kind: String, pad := 8) -> StyleBoxFlat:
	var sb: StyleBoxFlat
	match kind:
		"selected":
			sb = _box(Color(1, 1, 1, 0.7), 0)
			sb.border_color = ACCENT
			sb.border_width_bottom = 3
		"hover":
			sb = _box(Color(1, 1, 1, 0.35), 0)
			sb.border_color = Color(ACCENT, 0.35)
			sb.border_width_bottom = 3
		_:
			sb = _box(Color(0, 0, 0, 0), 0)
			sb.border_color = Color(0, 0, 0, 0)
			sb.border_width_bottom = 3
	sb.content_margin_left = pad + 4
	sb.content_margin_right = pad + 4
	sb.content_margin_top = 6
	sb.content_margin_bottom = 4
	return sb


static func compact_tabs(tc: TabContainer, pad := 8, font_size := 14) -> void:
	tc.add_theme_stylebox_override("tab_selected", tab_style("selected", pad))
	tc.add_theme_stylebox_override("tab_unselected", tab_style("unselected", pad))
	tc.add_theme_stylebox_override("tab_hovered", tab_style("hover", pad))
	tc.add_theme_font_size_override("font_size", font_size)


static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = font(false)
	th.default_font_size = 17
	th.set_font("font", "Label", font(false))
	th.set_font("font", "Button", font(true))
	th.set_font_size("font_size", "Button", 17)
	th.set_stylebox("normal", "Button", _btn(Color(1, 1, 1, 0.72)))
	th.set_stylebox("hover", "Button", _btn(Color(1, 1, 1, 0.96)))
	var bp := _btn(ACCENT)
	bp.border_color = ACCENT_DARK
	bp.shadow_color = Color(ACCENT, 0.3)
	th.set_stylebox("pressed", "Button", bp)
	var bhp := _btn(ACCENT_HI)
	bhp.border_color = ACCENT_DARK
	th.set_stylebox("hover_pressed", "Button", bhp)
	var bd := _btn(Color(1, 1, 1, 0.35))
	bd.shadow_size = 0
	th.set_stylebox("disabled", "Button", bd)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", TEXT)
	th.set_color("font_pressed_color", "Button", ACCENT_INK)
	th.set_color("font_hover_pressed_color", "Button", ACCENT_INK)
	th.set_color("font_focus_color", "Button", TEXT)        # sonst bleibt der Text nach einem Tipp fast weiß (Godot-Standard)
	th.set_color("font_focus_color", "OptionButton", TEXT)
	th.set_color("font_focus_color", "CheckBox", TEXT)
	th.set_color("font_hover_pressed_color", "CheckBox", TEXT)
	th.set_color("font_pressed_color", "CheckBox", TEXT)
	th.set_color("font_disabled_color", "Button", Color("a3a8b4"))
	th.set_stylebox("panel", "PanelContainer", glass(PANEL, RADIUS, 0))
	th.set_color("font_color", "Label", TEXT)
	th.set_stylebox("panel", "PopupMenu", glass(Color(1, 1, 1, 0.97), 6, 10))
	th.set_stylebox("hover", "PopupMenu", _box(Color(ACCENT, 0.16), 4))
	th.set_color("font_color", "PopupMenu", TEXT)
	th.set_color("font_hover_color", "PopupMenu", TEXT)
	th.set_stylebox("normal", "OptionButton", _btn(Color(1, 1, 1, 0.72)))
	th.set_stylebox("hover", "OptionButton", _btn(Color(1, 1, 1, 0.96)))
	th.set_stylebox("pressed", "OptionButton", _btn(Color.WHITE))
	th.set_color("font_color", "OptionButton", TEXT)
	th.set_color("font_hover_color", "OptionButton", TEXT)
	th.set_color("font_pressed_color", "OptionButton", TEXT)
	th.set_stylebox("panel", "TabContainer", glass(PANEL, RADIUS, 14))
	th.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())
	th.set_stylebox("tab_selected", "TabContainer", tab_style("selected"))
	th.set_stylebox("tab_unselected", "TabContainer", tab_style("unselected"))
	th.set_stylebox("tab_hovered", "TabContainer", tab_style("hover"))
	th.set_constant("side_margin", "TabContainer", 4)
	th.set_color("font_selected_color", "TabContainer", TEXT)
	th.set_color("font_unselected_color", "TabContainer", MUTED)
	th.set_color("font_hovered_color", "TabContainer", TEXT)
	th.set_font("font", "TabContainer", font(true))
	th.set_font_size("font_size", "TabContainer", 17)
	# Scrollbars schmal und dezent
	var sbar := StyleBoxFlat.new()
	sbar.bg_color = tint(0.05)
	sbar.content_margin_left = 3
	sbar.content_margin_right = 3
	sbar.set_corner_radius_all(3)
	var grab := StyleBoxFlat.new()
	grab.bg_color = tint(0.32)
	grab.set_corner_radius_all(3)
	grab.content_margin_left = 3
	grab.content_margin_right = 3
	var grab_hi := grab.duplicate()
	grab_hi.bg_color = ACCENT
	th.set_stylebox("scroll", "VScrollBar", sbar)
	th.set_stylebox("grabber", "VScrollBar", grab)
	th.set_stylebox("grabber_highlight", "VScrollBar", grab_hi)
	th.set_stylebox("grabber_pressed", "VScrollBar", grab_hi)
	# Fortschrittsbalken: flach, Akzentfüllung
	var pbg := StyleBoxFlat.new()
	pbg.bg_color = tint(0.09)
	pbg.set_corner_radius_all(4)
	var pfill := StyleBoxFlat.new()
	pfill.bg_color = ACCENT
	pfill.set_corner_radius_all(4)
	th.set_stylebox("background", "ProgressBar", pbg)
	th.set_stylebox("fill", "ProgressBar", pfill)
	th.set_stylebox("normal", "SpinBox", _box(PANEL2, 5, tint(0.14), 1))
	var trk := StyleBoxFlat.new()
	trk.bg_color = tint(0.12)
	trk.set_corner_radius_all(3)
	trk.content_margin_top = 3
	trk.content_margin_bottom = 3
	th.set_stylebox("slider", "HSlider", trk)
	var ga := StyleBoxFlat.new()
	ga.bg_color = ACCENT
	ga.set_corner_radius_all(3)
	ga.content_margin_top = 3
	ga.content_margin_bottom = 3
	th.set_stylebox("grabber_area", "HSlider", ga)
	th.set_stylebox("grabber_area_highlight", "HSlider", ga)
	var le := _box(PANEL2, 5, tint(0.14), 1)
	th.set_stylebox("normal", "LineEdit", le)
	th.set_stylebox("focus", "LineEdit", _box(Color.WHITE, 5, ACCENT, 2))
	th.set_stylebox("read_only", "LineEdit", _box(PANEL2, 6, LINE, 1))
	th.set_color("font_color", "LineEdit", TEXT)
	th.set_color("caret_color", "LineEdit", ACCENT)
	th.set_color("selection_color", "LineEdit", Color(ACCENT, 0.25))
	th.set_color("default_color", "RichTextLabel", TEXT)
	for sbn in ["normal", "pressed", "hover", "hover_pressed", "disabled", "focus"]:
		th.set_stylebox(sbn, "CheckBox", StyleBoxEmpty.new())
	th.set_color("font_color", "CheckBox", TEXT)
	th.set_color("font_hover_color", "CheckBox", TEXT)
	th.set_font("font", "CheckBox", font(false))
	th.set_icon("checked", "CheckBox", _check_icon(true))
	th.set_icon("unchecked", "CheckBox", _check_icon(false))
	th.set_icon("checked_disabled", "CheckBox", _check_icon(true))
	th.set_icon("unchecked_disabled", "CheckBox", _check_icon(false))
	th.set_font_size("font_size", "CheckBox", 14)
	var tip := _box(DARK3, 4)
	th.set_stylebox("panel", "TooltipPanel", tip)
	th.set_color("font_color", "TooltipLabel", ON_DARK)
	return th


## Glas-Knopf: halbtransparentes Weiß, helle Kante, kleiner weicher Schatten, gerade Ecken.
static func _btn(bg: Color) -> StyleBoxFlat:
	var sb := _box(bg, 5, LINE, 1)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.shadow_color = Color(SHADOW, 0.12)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	return sb


static var _chk_on: ImageTexture
static var _chk_off: ImageTexture


## CheckBox im Renn-Stil (eigene Symbole direkt am Knoten, unabhängig vom Theme). on_dark = für dunkle Kopfleisten.
static func checkbox(text := "", on_dark := false) -> CheckBox:
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
	var fc := ON_DARK if on_dark else TEXT
	for n in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		c.add_theme_color_override(n, fc)
	return c


## Selbst gezeichnetes Kästchen: gefüllt in der Akzentfarbe mit Häkchen in der passenden Schriftfarbe.
static func _check_icon(checked: bool) -> ImageTexture:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bg := ACCENT if checked else Color.WHITE
	var edge := ACCENT_DARK if checked else Color("8a90a0")
	for y in range(2, 22):
		for x in range(2, 22):
			var border := x < 4 or x > 19 or y < 4 or y > 19
			img.set_pixel(x, y, edge if border else bg)
	if checked:
		var pts := [Vector2i(7, 12), Vector2i(8, 13), Vector2i(9, 14), Vector2i(10, 15), Vector2i(11, 14), Vector2i(12, 13), Vector2i(13, 12), Vector2i(14, 11), Vector2i(15, 10), Vector2i(16, 9)]
		for p in pts:
			for dx in 2:
				for dy in 2:
					img.set_pixel(p.x + dx, p.y + dy, ACCENT_INK)
	return ImageTexture.create_from_image(img)


static func label(text: String, size := 17, col := TEXT, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if bold:
		l.add_theme_font_override("font", font(true))
	return l


## Beschriftung in der Renn-Schrift (kursiv, breit) für Titel und große Zahlen.
static func display(text: String, size := 20, col := TEXT) -> Label:
	var l := label(text, size, col)
	l.add_theme_font_override("font", display_font())
	return l


static func heading(text: String, size := 22, col := TEXT) -> Label:
	return display(text.to_upper(), size, col)


static func button(text: String, cb = null, min_w := 0, min_h := 38) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, min_h)
	if cb != null:
		b.pressed.connect(cb)
	return b


## Hauptknopf: gerade Fläche in der Akzent- bzw. Teamfarbe mit weichem Schatten, Renn-Schrift.
static func primary_button(text: String, cb = null, min_w := 0, min_h := 50) -> Button:
	var b := button(text, cb, min_w, min_h)
	var nb := slant_style(ACCENT)
	nb.shadow_color = Color(ACCENT_DARK, 0.3)
	nb.shadow_size = 8
	nb.shadow_offset = Vector2(0, 3)
	b.add_theme_stylebox_override("normal", nb)
	b.add_theme_stylebox_override("hover", slant_style(ACCENT_HI))
	b.add_theme_stylebox_override("pressed", slant_style(ACCENT_DARK))
	b.add_theme_stylebox_override("hover_pressed", slant_style(ACCENT_DARK))
	b.add_theme_stylebox_override("disabled", slant_style(Color(ACCENT, 0.3)))
	b.add_theme_font_override("font", display_font())
	for n in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(n, ACCENT_INK)
	b.add_theme_color_override("font_disabled_color", Color(ACCENT_INK, 0.6))
	b.add_theme_font_size_override("font_size", 19)
	if fx_on():
		b.clip_contents = true
		var sh = load("res://scripts/shine.gd").new()
		b.add_child(sh)
	return b


## Knopf für Kopfleisten (Zurück, Speichern, Menü, Tempo): helles Glas.
static func dark_button(text: String, cb = null, min_w := 0, min_h := 38) -> Button:
	var b := button(text, cb, min_w, min_h)
	b.add_theme_stylebox_override("normal", _btn(Color(1, 1, 1, 0.55)))
	b.add_theme_stylebox_override("hover", _btn(Color(1, 1, 1, 0.9)))
	b.add_theme_stylebox_override("pressed", _btn(ACCENT))
	b.add_theme_stylebox_override("hover_pressed", _btn(ACCENT_HI))
	b.add_theme_stylebox_override("disabled", _btn(Color(1, 1, 1, 0.25)))
	for n in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(n, TEXT)
	b.add_theme_color_override("font_pressed_color", ACCENT_INK)
	b.add_theme_color_override("font_hover_pressed_color", ACCENT_INK)
	b.add_theme_color_override("font_disabled_color", MUTED)
	return b


static func panel(margin := 14, accent := Color(0, 0, 0, 0)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := glass(PANEL, RADIUS, 16)
	sb.set_content_margin_all(margin)
	if accent.a > 0.0:
		sb.set_border_width_all(0)
		sb.border_width_top = 3
		sb.border_color = accent
	p.add_theme_stylebox_override("panel", sb)
	return p


## Dunkle Fläche (Kopfleiste, Zeitentafel, Funk).
static func dark_panel(margin := 10, accent := Color(0, 0, 0, 0)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _box(DARK, RADIUS, Color(1, 1, 1, 0.06), 1)
	sb.set_content_margin_all(margin)
	if accent.a > 0.0:
		sb.border_width_bottom = 2
		sb.border_color = accent
	p.add_theme_stylebox_override("panel", sb)
	return p


## Dezente Unterkarte innerhalb eines Panels (für Gruppen von Bedienelementen).
static func card(margin := 10, tint_col := Color(1, 1, 1, 0.55), edge := Color(1, 1, 1, 0.9)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _box(tint_col, 5, edge, 1 if edge.a > 0.0 else 0)
	sb.set_content_margin_all(margin)
	p.add_theme_stylebox_override("panel", sb)
	return p


## Antippbare Auswahlkarte: Titel und Erklärung in einer Fläche. strong = hervorgehobene Hauptaktion in der Farbe accent.
static func option_card(title: String, hint: String, accent: Color, cb: Callable, strong := false) -> PanelContainer:
	var p := PanelContainer.new()
	var sbx := _box(Color(accent, 0.12) if strong else PANEL2, 5, Color(accent, 0.8) if strong else LINE, 1)
	if strong:
		sbx.border_width_left = 4
	sbx.content_margin_left = 11
	sbx.content_margin_right = 11
	sbx.content_margin_top = 7
	sbx.content_margin_bottom = 7
	p.add_theme_stylebox_override("panel", sbx)
	var v := vbox(1)
	var t := label(title, 15, TEXT, true)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	if hint != "":
		var h := label(hint, 11, MUTED)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(h)
	p.add_child(v)
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	var hov := _box(Color(accent, 0.08), 5)
	var prs := _box(Color(accent, 0.2), 5)
	var emp := StyleBoxEmpty.new()
	b.add_theme_stylebox_override("normal", emp)
	b.add_theme_stylebox_override("focus", emp)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", prs)
	b.pressed.connect(cb)
	p.add_child(b)
	return p


## Abschnittsüberschrift mit schrägem Marker in der Akzentfarbe.
static func section(text: String, size := 12) -> Control:
	var h := hbox(6)
	var m := PanelContainer.new()
	var ms := _box(ACCENT, 0)
	ms.set_content_margin_all(0)
	m.add_theme_stylebox_override("panel", ms)
	m.custom_minimum_size = Vector2(3, size + 2)
	m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(m)
	var l := label(text.to_upper(), size, MUTED, true)
	l.add_theme_constant_override("outline_size", 0)
	h.add_child(l)
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
	r.color = col.darkened(0.38) if col.get_luminance() > 0.72 else col
	r.custom_minimum_size = Vector2(w, h)
	return r


## Kurze "Bitte warten"-Anzeige, damit der Bildschirm neu zeichnet, bevor eine längere Berechnung läuft (Browser).
static func busy(screen: Control, text: String, work: Callable) -> void:
	var p := dark_panel(22, ACCENT)
	p.add_child(display(text, 22, ON_DARK))
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


## Höhe des dunklen Kopfbands hinter Titel und Kopfleiste (passend zu screen_margin und title_bar).
static func header_height() -> float:
	return 56.0 if is_mobile() else 92.0


## Hintergrund: helle Fläche, oben ein dunkles Kopfband mit Akzentkante; als erstes Kind eines Bildschirms einfügen.
static func backdrop(accent := Color(0, 0, 0, 0)) -> Control:
	var b = load("res://scripts/backdrop.gd").new()
	b.accent = accent if accent.a > 0.0 else ACCENT
	fill(b)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## Hintergrund in der Farbe des eigenen Teams (während einer Karriere), sonst rot.
static func team_backdrop() -> Control:
	return backdrop(ACCENT)      # ACCENT ist während einer Karriere die Teamfarbe (main.gd)


## Überschrift in der Kopfleiste: Schrägstreifen in der Akzentfarbe, Titel in Renn-Schrift, Untertitel. sub = Untertitel.
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


## Kennzahl-Kachel: kleine Beschriftung, großer Wert in Renn-Schrift.
static func stat(caption: String, value: String, col := TEXT) -> VBoxContainer:
	var v := vbox(0)
	v.add_child(label(caption.to_upper(), 11, MUTED, true))
	var d := display(value, 20, col)
	v.add_child(d)
	load("res://scripts/anim.gd").count_label(d)      # Zahl zählt beim ersten Anzeigen hoch (Effekte an)
	return v


## Kleine farbige Marke (Chip) mit Text, schräg wie die Renngrafik.
static func chip(text: String, bg := Color(0, 0, 0, 0), fg := Color(0, 0, 0, 0)) -> PanelContainer:
	if bg.a == 0.0:
		bg = ACCENT
	if fg.a == 0.0:
		fg = Color.WHITE if bg.get_luminance() < 0.5 or bg.a < 0.9 and bg.get_luminance() < 0.7 else INK
	var p := PanelContainer.new()
	var sb := slant_style(bg, Color(0, 0, 0, 0), 0, 3)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(label(text.to_upper(), 12, fg, true))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


## Antipp-Rückmeldung und weiche Übergänge (von main.gd an alle Knöpfe und Reiter gehängt).
static func animate_button(b: BaseButton) -> void:
	if b.has_meta("anim"):
		return
	b.set_meta("anim", true)
	b.button_down.connect(func():
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.95, 0.95), 0.06))
	b.button_up.connect(func():
		var tw := b.create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2.ONE, 0.16))


static func animate_tabs(tc: TabContainer) -> void:
	if tc.has_meta("anim"):
		return
	tc.set_meta("anim", true)
	tc.tab_changed.connect(func(i: int):
		var page := tc.get_tab_control(i)
		if page == null:
			return
		page.modulate.a = 0.0
		var tw := page.create_tween()
		tw.tween_property(page, "modulate:a", 1.0, 0.16)
		# Inhalt des neuen Reiters staffelt sich herein (Effekte an)
		load("res://scripts/anim.gd").stagger_in.call_deferred(page, 0.03, 18))


## Reifenwahl-Knopf: gewählt = dunkle Fläche mit Rand und Schrift in der Reifenfarbe (statt Akzentfläche, auf der Rot/Gelb verschwimmen).
static func tyre_button(b: Button, col: Color) -> void:
	var on := button_style(DARK, col, 2)
	on.border_width_bottom = 4
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_color_override("font_pressed_color", col)
	b.add_theme_color_override("font_hover_pressed_color", col)

extends PanelContainer
## Navigationsleiste am Handy (seitlich, weil das Handy quer gehalten wird): ersetzt die Reiterzeile eines TabContainers
## durch Symbole mit kurzer Beschriftung; die gewählte Seite bekommt eine Pille in der Akzentfarbe.
## items: [{"tab": Reitername, "icon": Symbolname (icon.gd), "label": Kurzname, "badge": bool}]

const U = preload("res://scripts/ui.gd")
const Icon = preload("res://scripts/icon.gd")

var tc: TabContainer
var _btns: Array = []


func setup(p_tc: TabContainer, items: Array) -> void:
	tc = p_tc
	tc.tabs_visible = false
	var sb := U.glass(U.PANEL, U.RADIUS, 12)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(62, 0)
	# scrollt, falls die Anzeige so groß eingestellt ist, dass nicht alle Einträge passen
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(sc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	for it in items:
		var idx := -1
		for i in tc.get_tab_count():
			if tc.get_tab_title(i) == str(it["tab"]) or str(tc.get_tab_control(i).name) == str(it["tab"]):
				idx = i
		if idx < 0:
			continue
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(56, 25)
		b.set_meta("compact", true)     # Handy-Mindesthöhe für Knöpfe (main._touchify) hier nicht erzwingen
		for s in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 0)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		U.fill(inner)
		b.add_child(inner)
		var pill := PanelContainer.new()
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var ps := StyleBoxFlat.new()
		ps.set_corner_radius_all(4)
		ps.content_margin_left = 10
		ps.content_margin_right = 10
		ps.content_margin_top = 0
		ps.content_margin_bottom = 0
		pill.add_theme_stylebox_override("panel", ps)
		var ic = Icon.make(str(it["icon"]), 14.0, U.MUTED)
		pill.add_child(ic)
		inner.add_child(pill)
		var l := U.label(str(it["label"]), 8, U.MUTED, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(l)
		if bool(it.get("badge", false)):
			var dot := ColorRect.new()
			dot.color = U.WARN
			dot.custom_minimum_size = Vector2(7, 7)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dot.position = Vector2(42, 2)
			b.add_child(dot)
		b.pressed.connect(func(): tc.current_tab = idx)
		v.add_child(b)
		_btns.append({"idx": idx, "ps": ps, "icon": ic, "label": l})
	tc.tab_changed.connect(func(_t: int): _refresh())
	_refresh()


func _refresh() -> void:
	for e in _btns:
		var on: bool = int(e["idx"]) == tc.current_tab
		e["ps"].bg_color = Color(U.ACCENT, 0.16) if on else Color(0, 0, 0, 0)
		e["icon"].set_color(U.ACCENT_TEXT if on else U.MUTED)
		e["label"].add_theme_color_override("font_color", U.TEXT if on else U.MUTED)

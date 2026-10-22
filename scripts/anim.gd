extends RefCounted
## Bewegung in der Oberfläche (nur wenn U.fx_on()): Karten staffeln sich beim Öffnen herein, Zahlen zählen hoch, Balken
## füllen sich, der Unterstrich der Reiter gleitet, Milchglas hinter den Glas-Panels, lange Erklärtexte sind einklappbar.
## main.gd hängt die meisten Effekte automatisch an neue Knoten.

const U = preload("res://scripts/ui.gd")
const Icon = preload("res://scripts/icon.gd")

static var _frost_mat: ShaderMaterial = null


## cb einmal ausführen, sobald node das erste Mal sichtbar ist (z. B. erst beim Öffnen seines Reiters).
static func on_first_visible(node: Control, cb: Callable) -> void:
	var done := [false]
	var check := func():
		if done[0] or not is_instance_valid(node) or not node.is_inside_tree() or not node.is_visible_in_tree():
			return
		done[0] = true
		cb.call()
	node.visibility_changed.connect(check)
	if node.is_inside_tree():
		check.call_deferred()
	else:
		node.tree_entered.connect(func(): check.call_deferred(), CONNECT_ONE_SHOT)


# ------------------------------------------------------------------ Hereinstaffeln

## Panels und Karten unter root nacheinander einblenden (oben links zuerst), nur was gerade im Bild ist.
static func stagger_in(root: Control, step := 0.035, cap := 26) -> void:
	if not U.fx_on() or root == null or not is_instance_valid(root) or not root.is_inside_tree():
		return
	var items: Array = []
	_collect(root, items, 0)
	var view := root.get_viewport_rect()
	items = items.filter(func(n): return n.is_visible_in_tree() and n.get_global_rect().intersects(view) and n.modulate.a > 0.99)
	items.sort_custom(func(a, b):
		var pa: Vector2 = a.global_position
		var pb: Vector2 = b.global_position
		return pa.y < pb.y - 6.0 or (absf(pa.y - pb.y) <= 6.0 and pa.x < pb.x))
	for i in mini(items.size(), cap):
		_pop(items[i], step * float(i))


static func _collect(n: Node, out: Array, depth: int) -> void:
	for ch in n.get_children():
		if not (ch is Control) or ch.has_meta("no_anim"):
			continue
		if ch is PanelContainer or ch is TabContainer:
			out.append(ch)
			if depth < 1:
				_collect(ch, out, depth + 1)
		else:
			_collect(ch, out, depth)


static func _pop(n: Control, delay: float) -> void:
	n.modulate.a = 0.0
	n.pivot_offset = Vector2(n.size.x * 0.5, 0.0)
	n.scale = Vector2(0.97, 0.97)
	var tw := n.create_tween().set_parallel(true)
	tw.tween_property(n, "modulate:a", 1.0, 0.28).set_delay(delay)
	tw.tween_property(n, "scale", Vector2.ONE, 0.38).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ Zahlen und Balken

## Die erste Zahl im Text (z. B. "84.0 Mio. $", "+0.03 s", "5.399 km") zählt beim ersten Sichtbarwerden von 0 hoch.
## Zeiten mit ":" und Texte ohne Zahl bleiben unverändert.
static func count_label(l: Label) -> void:
	if not U.fx_on() or l == null:
		return
	var text := l.text
	if text.contains(":"):
		return
	var re := RegEx.new()
	re.compile("^([^0-9+\\-]*)([+\\-]?)(\\d+)(?:([.,])(\\d+))?(.*)$")
	var m := re.search(text)
	if m == null:
		return
	var decs := m.get_string(5).length()
	var sep := m.get_string(4)
	var target := float(m.get_string(3) + ("." + m.get_string(5) if decs > 0 else ""))
	if target < 0.0001:
		return
	if decs == 0 and target >= 1900.0 and target <= 2100.0:
		return      # Jahreszahlen nicht hochzählen
	var prefix := m.get_string(1)
	var sgn := m.get_string(2)
	var suffix := m.get_string(6)
	var fmt := func(v: float) -> String:
		var num := ("%." + str(decs) + "f") % v
		if sep == ",":
			num = num.replace(".", ",")
		return prefix + sgn + num + suffix
	l.text = fmt.call(0.0)
	on_first_visible(l, func():
		var setv := func(v: float) -> void:
			l.text = fmt.call(v)
		var tw := l.create_tween()
		tw.tween_method(setv, 0.0, target, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func(): l.text = text))


## Fortschrittsbalken füllt sich beim ersten Sichtbarwerden von 0 auf seinen Wert.
static func bar_in(pb: ProgressBar) -> void:
	if not U.fx_on() or not is_instance_valid(pb) or pb.has_meta("no_anim"):
		return
	var target := pb.value
	if target <= pb.min_value + 0.0001:
		return
	pb.value = pb.min_value
	on_first_visible(pb, func():
		pb.create_tween().tween_property(pb, "value", target, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT))


# ------------------------------------------------------------------ Reiter

## Der Unterstrich des gewählten Reiters gleitet zum neuen Reiter (statt zu springen).
static func glide_tabs(tc: TabContainer) -> void:
	if not U.fx_on() or tc.has_meta("glide"):
		return
	tc.set_meta("glide", true)
	var bar := tc.get_tab_bar()
	if bar == null:
		return
	var sb = tc.get_theme_stylebox("tab_selected")
	if sb is StyleBoxFlat:
		var s2: StyleBoxFlat = sb.duplicate()
		s2.border_color = Color(0, 0, 0, 0)
		tc.add_theme_stylebox_override("tab_selected", s2)
	var line := Control.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(line)
	var st := {"x": 0.0, "w": 0.0, "ok": false}
	line.draw.connect(func():
		if st["ok"] and st["w"] > 0.0:
			line.draw_rect(Rect2(st["x"], bar.size.y - 3.0, st["w"], 3.0), U.ACCENT))
	var target := func(i: int) -> Rect2:
		if i < 0 or i >= bar.tab_count:
			return Rect2()
		return bar.get_tab_rect(i)
	var snap := func():
		if not is_instance_valid(line):
			return
		line.size = bar.size
		var r: Rect2 = target.call(tc.current_tab)
		st["x"] = r.position.x
		st["w"] = r.size.x
		st["ok"] = true
		line.queue_redraw()
	bar.resized.connect(snap)
	snap.call_deferred()
	tc.tab_changed.connect(func(i: int):
		if not is_instance_valid(line):
			return
		line.size = bar.size
		var r: Rect2 = target.call(i)
		var x0: float = st["x"]
		var w0: float = st["w"]
		var step := func(u: float) -> void:
			st["x"] = lerpf(x0, r.position.x, u)
			st["w"] = lerpf(w0, r.size.x, u)
			line.queue_redraw()
		var tw := line.create_tween()
		tw.tween_method(step, 0.0, 1.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT))


# ------------------------------------------------------------------ Milchglas

## Glas-Panel bekommt echte Unschärfe des Hintergrunds (Shader liest den Bildschirm). Nur für oberste Glas-Ebenen,
## damit verschachtelte Karten nicht doppelt weichzeichnen.
static func frost(n: Control) -> void:
	if not U.fx_on() or not is_instance_valid(n) or n.material != null:
		return
	var sb = n.get_theme_stylebox("panel")
	if not (sb is StyleBoxFlat):
		return
	var bg: Color = sb.bg_color
	if bg.a < 0.4 or bg.a > 0.92 or bg.r < 0.85:
		return
	var p := n.get_parent()
	while p != null:
		if p.has_meta("frost"):
			return
		p = p.get_parent()
	if _frost_mat == null:
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float radius = 5.0;
void fragment() {
	vec4 c = COLOR;
	if (c.a > 0.35 && c.a < 0.97) {
		vec2 px = SCREEN_PIXEL_SIZE * radius;
		vec3 acc = texture(screen_tex, SCREEN_UV).rgb * 0.2;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398 + 0.39;
			vec2 d = vec2(cos(a), sin(a));
			acc += texture(screen_tex, SCREEN_UV + d * px).rgb * 0.06;
			acc += texture(screen_tex, SCREEN_UV + d * px * 2.4).rgb * 0.04;
		}
		COLOR = vec4(mix(acc, c.rgb, c.a), 1.0);
	}
}
"""
		_frost_mat = ShaderMaterial.new()
		_frost_mat.shader = sh
		_frost_mat.set_shader_parameter("radius", 4.0 if U.is_mobile() else 6.0)
	n.material = _frost_mat
	n.set_meta("frost", true)


# ------------------------------------------------------------------ Einklappbare Erklärtexte

## Lange, graue Erklärtexte zeigen nur die erste Zeile mit einem i-Symbol; Antippen klappt sie auf und wieder zu.
static func make_hint(l: Label) -> void:
	if not is_instance_valid(l) or l.has_meta("hint") or l.has_meta("keep_text"):
		return
	l.set_meta("hint", true)
	l.max_lines_visible = 1
	var sb := StyleBoxEmpty.new()
	sb.content_margin_right = 20
	l.add_theme_stylebox_override("normal", sb)
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	var ic = Icon.make("info", 14.0, U.ACCENT)
	ic.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 0)
	ic.position.y = 1.0
	l.add_child(ic)
	l.gui_input.connect(func(ev: InputEvent):
		var mb := ev as InputEventMouseButton
		if mb != null and not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not U.touch_scrolled:
			var open := l.max_lines_visible == 1
			l.max_lines_visible = -1 if open else 1
			ic.set_color(U.MUTED if open else U.ACCENT))

extends Control
## Intro-Karte vor jedem Rennwochenende (wie die Einblendung zu Beginn einer Übertragung): Streckenumriss, der sich zeichnet,
## Name des Grand Prix in Renn-Schrift, Kennzahlen, Rennziel, WM-Stand und frühere Sieger dieser Karriere. Antippen schließt sie.

const U = preload("res://scripts/ui.gd")
const Career = preload("res://scripts/career.gd")
const Flag = preload("res://scripts/flag.gd")
const SECTOR_COLS := [Color("e8364b"), Color("2f7bf6"), Color("f2a900")]

var track
var sim
var laps := 0
var _t := 0.0
var _outline: Control


## Kurzer Streckenumriss, der sich beim Öffnen zeichnet; Start/Ziel als Karomarke.
class Outline extends Control:
	var pts := PackedVector2Array()
	var progress := 0.0
	var col := Color.WHITE

	func _draw() -> void:
		if pts.size() < 3:
			return
		var mn := pts[0]
		var mx := pts[0]
		for p in pts:
			mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
			mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
		var ext := mx - mn
		var s := minf((size.x - 24.0) / maxf(ext.x, 1.0), (size.y - 24.0) / maxf(ext.y, 1.0))
		var off := (size - ext * s) * 0.5 - mn * s
		var n := pts.size()
		var m := int(float(n) * clampf(progress, 0.0, 1.0))
		var line := PackedVector2Array()
		for i in range(0, n, 2):
			line.append(pts[i] * s + off)
		line.append(pts[0] * s + off)
		draw_polyline(line, Color(1, 1, 1, 0.10), 10.0, true)
		# Strecke zeichnet sich Sektor für Sektor in den Sektorfarben
		var font := U.font(true)
		for k in 3:
			var a := n * k / 3
			var b := mini(n * (k + 1) / 3, m)
			if b <= a:
				continue
			var part := PackedVector2Array()
			for i in range(a, b, 2):
				part.append(pts[i] * s + off)
			part.append(pts[mini(b, n - 1)] * s + off)
			if part.size() >= 2:
				draw_polyline(part, Color(SECTOR_COLS[k], 0.35), 14.0, true)
				draw_polyline(part, SECTOR_COLS[k], 5.0, true)
			# Beschriftung, sobald der Sektor fertig gezeichnet ist
			if m >= n * (k + 1) / 3:
				var mp: Vector2 = pts[(a + n * (k + 1) / 3) / 2] * s + off
				var txt := "S%d" % (k + 1)
				var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
				var br := Rect2(mp + Vector2(10, -10), Vector2(tw + 10.0, 19.0))
				draw_rect(br, SECTOR_COLS[k])
				draw_string(font, br.position + Vector2(5, 14.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
			if k > 0 and m >= a:
				var q: Vector2 = pts[a] * s + off
				draw_circle(q, 6.5, Color.WHITE)
				draw_circle(q, 4.5, SECTOR_COLS[k])
		if m > 0 and m < n:
			draw_circle(pts[m - 1] * s + off, 6.0, Color.WHITE)
		var sp := pts[0] * s + off
		draw_rect(Rect2(sp - Vector2(7, 7), Vector2(14, 14)), Color.WHITE)
		draw_rect(Rect2(sp - Vector2(7, 7), Vector2(7, 7)), Color(0.05, 0.05, 0.08))
		draw_rect(Rect2(sp, Vector2(7, 7)), Color(0.05, 0.05, 0.08))


func setup(p_track, p_sim, p_laps: int) -> void:
	track = p_track
	sim = p_sim
	laps = p_laps


func _ready() -> void:
	U.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var M := U.is_mobile()
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.07, 0.99)
	U.fill(bg)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Akzentkeil oben links und Streifen unten
	var deco := Control.new()
	U.fill(deco)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.draw.connect(func():
		var w := deco.size.x
		var h := deco.size.y
		deco.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.34, 0), Vector2(w * 0.28, 8), Vector2(0, 8)]), U.ACCENT)
		deco.draw_rect(Rect2(0, h - 4, w, 4), U.ACCENT)
		var x := w * 0.6
		while x < w + h:
			deco.draw_line(Vector2(x, 0), Vector2(x - h, h), Color(1, 1, 1, 0.018), 1.0)
			x += 9.0)
	add_child(deco)

	var margin := MarginContainer.new()
	U.fill(margin)
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 14 if M else 40)
	add_child(margin)
	var row := U.hbox(14 if M else 36)
	margin.add_child(row)

	_outline = Outline.new()
	_outline.pts = track.pts
	_outline.col = U.ACCENT
	_outline.custom_minimum_size = Vector2(230 if M else 460, 0)
	_outline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_outline)

	var v := U.vbox(4 if M else 10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(v)
	var race: Dictionary = Game.current_race()
	v.add_child(U.label("RUNDE %d VON %d  ·  %d" % [Game.round_index + 1, Game.calendar.size(), Game.year], 12 if M else 15, U.ACCENT.lightened(0.2), true))
	var trow := U.hbox(12 if M else 18)
	trow.add_child(Flag.make(str(track.country), 26.0 if M else 44.0))
	var title := U.display(str(race["name"]).to_upper(), 24 if M else 42, U.ON_DARK)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(title)
	v.add_child(trow)
	v.add_child(U.label("%s  ·  %s, %s" % [str(track.track_name), str(track.locality), str(track.country)], 12 if M else 16, U.MUTED_DARK))

	# Kennzahlen
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 18 if M else 34)
	g.add_theme_constant_override("v_separation", 2 if M else 10)
	v.add_child(g)
	var sev: float = float(track.tyre_severity)
	var sev_w := "hoch" if sev > 1.1 else ("niedrig" if sev < 0.9 else "mittel")
	var ov_w := "leicht" if track.overtake_ease > 0.6 else ("schwer" if track.overtake_ease < 0.35 else "mittel")
	for e in [["Länge", "%.3f km" % (track.length / 1000.0)], ["Runden", str(laps)], ["Distanz", "%.0f km" % (track.length * laps / 1000.0)],
			["Reifenabbau", sev_w], ["Überholen", ov_w], ["Regen", "%d %%" % int(sim.rain_chance * 100.0)]]:
		var st := U.vbox(-2)
		st.add_child(U.label(str(e[0]).to_upper(), 10 if M else 12, U.MUTED_DARK, true))
		var dv := U.display(str(e[1]), 16 if M else 24, U.ON_DARK)
		st.add_child(dv)
		load("res://scripts/anim.gd").count_label(dv)
		g.add_child(st)

	# Ziel, WM-Stand, frühere Sieger
	var info := U.vbox(1 if M else 4)
	v.add_child(info)
	if Game.active:
		var gl: Dictionary = Career.race_goal()
		var gt := U.label("ZIEL  " + str(gl["text"]), 12 if M else 15, Color("fbbf24"), true)
		gt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(gt)
		var ts: Array = Game.team_standings()
		for i in ts.size():
			if ts[i]["id"] == Game.team_id:
				info.add_child(U.label("Konstrukteurs-WM: P%d mit %s Punkten" % [i + 1, U.fmt_pts(float(ts[i]["points"]))], 12 if M else 15, U.ON_DARK))
		var wl: Array = Game.race_winners.get(str(race.get("circuitId", "")), [])
		if not wl.is_empty():
			var parts: Array = []
			for k in range(wl.size() - 1, maxi(-1, wl.size() - 4), -1):
				parts.append("%d %s (%s)" % [int(wl[k]["year"]), str(wl[k]["code"]), str(wl[k]["team"])])
			var wt := U.label("Sieger hier: " + ",  ".join(parts), 11 if M else 14, U.MUTED_DARK)
			wt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info.add_child(wt)
	var b := U.primary_button("ZUM WOCHENENDE", _close, 220 if M else 300, 42 if M else 54)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(b)

	# Einblenden: Inhalt gleitet von rechts herein
	modulate.a = 0.0
	v.position.x += 40.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.3)


func _process(delta: float) -> void:
	_t += delta
	if _outline != null and _outline.progress < 1.0:
		_outline.progress = minf(1.0, _t / 1.6)
		_outline.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _t > 0.6 and not U.touch_scrolled:
		_close()


func _close() -> void:
	set_process(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	tw.tween_callback(queue_free)

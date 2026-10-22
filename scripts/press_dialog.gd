extends Control
## Pressekonferenz als Dialog über dem Ergebnis: Frage eines Reporters, zwei bis drei Antworten mit erwarteter Wirkung,
## darunter die Stimmung der eigenen Fahrer, die sich nach der Antwort sichtbar ändert. Überspringen = keine Wirkung.

const U = preload("res://scripts/ui.gd")
const Press = preload("res://scripts/press.gd")
const DriverPhoto = preload("res://scripts/driver_photo.gd")
const Market = preload("res://scripts/market.gd")

signal finished

var qs: Array = []
var _i := 0
var _box: VBoxContainer
var _mood_box: VBoxContainer
var _bars := {}            # Kürzel -> {"bar": ProgressBar, "word": Label}


func _ready() -> void:
	U.fill(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var M := U.is_mobile()
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.06, 0.72)
	U.fill(dim)
	add_child(dim)
	var center := CenterContainer.new()
	U.fill(center)
	add_child(center)
	var p := U.panel(12 if M else 18, U.ACCENT)
	p.custom_minimum_size = Vector2(600 if M else 680, 0)
	center.add_child(p)
	var v := U.vbox(6 if M else 10)
	p.add_child(v)
	var head := U.hbox(8)
	v.add_child(head)
	head.add_child(U.heading("Pressekonferenz", 18 if M else 22))
	head.add_child(U.spacer())
	head.add_child(U.button("Überspringen", _finish, 0, 32))
	_box = U.vbox(5 if M else 8)
	v.add_child(_box)
	v.add_child(HSeparator.new())
	_mood_box = U.vbox(3)
	v.add_child(_mood_box)
	_mood_box.add_child(U.label("STIMMUNG DEINER FAHRER", 10 if M else 11, U.MUTED, true))
	var row := U.hbox(14)
	_mood_box.add_child(row)
	for d in Market.current_drivers(Game.team_id):
		var h := U.hbox(6)
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(DriverPhoto.make(str(d["id"]), 28.0 if M else 34.0))
		var dv := U.vbox(0)
		dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(dv)
		var mw: Array = Press.mood_word(float(d["morale"]))
		var top := U.hbox(6)
		dv.add_child(top)
		top.add_child(U.display(str(d["code"]), 13 if M else 15))
		var wl := U.label(str(mw[0]), 11 if M else 12, mw[1], true)
		top.add_child(wl)
		var bar := ProgressBar.new()
		bar.max_value = 100.0
		bar.value = float(d["morale"]) * 100.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 7)
		_tint(bar, mw[1])
		dv.add_child(bar)
		row.add_child(h)
		_bars[str(d["code"])] = {"bar": bar, "word": wl}
	_show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func _tint(bar: ProgressBar, col: Color) -> void:
	var f := StyleBoxFlat.new()
	f.bg_color = col
	f.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", f)


func _show() -> void:
	U.clear(_box)
	if _i >= qs.size():
		_finish()
		return
	var M := U.is_mobile()
	var q: Dictionary = qs[_i]
	var who := U.hbox(6)
	_box.add_child(who)
	who.add_child(U.chip(str(q["who"]), U.DARK))
	who.add_child(U.label("Frage %d von %d" % [_i + 1, qs.size()], 11, U.MUTED))
	var ql := U.label("„%s“" % str(q["q"]), 16 if M else 19, U.TEXT, true)
	ql.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(ql)
	var grid := GridContainer.new()
	grid.columns = 3 if (M and q["answers"].size() == 3) else (2 if M else 1)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 5)
	_box.add_child(grid)
	for a in q["answers"]:
		var oc := U.option_card(str(a["label"]), str(a["hint"]), U.ACCENT, _answer.bind(a), false)
		oc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(oc)


func _answer(a: Dictionary) -> void:
	var changes: Array = Press.apply(a["fx"])
	Game.news.push_front({"year": Game.year, "round": Game.round_index, "kind": "press", "text": "Pressekonferenz: %s" % str(a["label"])})
	for ch in changes:
		var b: Dictionary = _bars.get(str(ch["code"]), {})
		if b.is_empty():
			continue
		var mw: Array = Press.mood_word(float(ch["after"]))
		var bar: ProgressBar = b["bar"]
		create_tween().tween_property(bar, "value", float(ch["after"]) * 100.0, 0.5).set_trans(Tween.TRANS_CUBIC)
		_tint(bar, mw[1])
		var wl: Label = b["word"]
		var arrow := "  ▲" if float(ch["after"]) > float(ch["before"]) else "  ▼"
		wl.text = str(mw[0]) + arrow
		wl.add_theme_color_override("font_color", mw[1])
	_i += 1
	# kurz zeigen, wie sich die Stimmung ändert, dann nächste Frage
	U.clear(_box)
	_box.add_child(U.label("Notiert: „%s“" % str(a["label"]), 14, U.MUTED, true))
	get_tree().create_timer(0.9).timeout.connect(_show)


func _finish() -> void:
	if not is_inside_tree() or mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.save()
	finished.emit()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)

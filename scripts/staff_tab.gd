extends VBoxContainer
## Reiter "Personal" der Zentrale: die fünf Schlüsselpositionen mit Bewertung, Gehalt, Vertrag und Wirkung;
## Verlängern oder Ersetzen über den Personalmarkt (Kandidaten mit Bewertung, Gehalt und Kosten des Wechsels).

const U = preload("res://scripts/ui.gd")
const Staff = preload("res://scripts/staff.gd")
const Market = preload("res://scripts/market.gd")

signal changed

var open_role := ""
var _msg := ""


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	rebuild()


func _wl(text: String, size := 13, col := U.MUTED, bold := false) -> Label:
	var l := U.label(text, size, col, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Aktuelle Wirkung einer Person als kurzer Text.
func _effect(role: String) -> String:
	var fx: Dictionary = Staff.race_effects()
	match Staff.kind(role):
		"td":
			var L := Staff.level("td")
			return "Projekte %+d %% Dauer, %+d %% Zuwachs, Risiko %d %%, %d Projektplätze" % [int(round((1.25 - 0.45 * L - 1.0) * 100.0)), int(round((0.8 + 0.45 * L - 1.0) * 100.0)), int(round((0.16 - 0.12 * L) * 100.0)), 3 if Staff.rating("td") >= 80.0 else 2]
		"strat":
			return "Prognosefehler %d %% des Normalwerts%s" % [int(round(float(fx["forecast_k"]) * 100.0)), ", Reifenhaltbarkeit immer bekannt" if bool(fx["tyre_known"]) else ""]
		"eng":
			var e: float = float(fx["eng"][0 if role == "eng1" else 1])
			return "Tempo seines Fahrers %+.2f %%" % (e * 100.0)
		"crew":
			return "Boxenstopps %+.2f s, verpatzte Stopps %d %% des Normalwerts" % [float(fx["pit_skill"]), int(round(float(fx["slow_k"]) * 100.0))]
	return ""


func rebuild() -> void:
	U.clear(self)
	var M := U.is_mobile()
	add_child(_wl("Dein Personal bestimmt, wie schnell das Auto besser wird, wie gut Prognosen und Boxenstopps sind und wie schnell die Fahrer sind. Gehälter zahlst du pro Rennen aus dem Budget (sie zählen nicht zur Kostenobergrenze).", 13))
	add_child(U.label("Gehälter Personal: %.1f Mio. $ pro Saison" % Staff.payroll(), 14, U.TEXT, true))
	if _msg != "":
		add_child(_wl(_msg, 13, U.BLUE, true))
	var drs: Array = Market.current_drivers(Game.team_id)
	for role in Staff.ROLES:
		var p: Dictionary = Game.staff.get(role, {})
		var card := U.panel(10)
		var v := U.vbox(4)
		card.add_child(v)
		var h := U.hbox(10)
		v.add_child(h)
		var r := int(p.get("rating", 0))
		var rl := U.display(str(r), 26 if M else 30, Market.rating_color(r))
		rl.custom_minimum_size = Vector2(46, 0)
		h.add_child(rl)
		var iv := U.vbox(0)
		iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(iv)
		var rn := str(Staff.ROLE_NAMES[role]).to_upper()
		if Staff.kind(role) == "eng":
			var di := 0 if role == "eng1" else 1
			if di < drs.size():
				rn += "  ·  " + str(drs[di]["code"])
		iv.add_child(U.label(rn, 11, U.MUTED, true))
		iv.add_child(U.label(str(p.get("name", "-")), 16, U.TEXT, true))
		var ending := int(p.get("end", 0)) <= Game.year
		iv.add_child(U.label("%d Jahre  ·  %.1f Mio. $ pro Saison  ·  Vertrag bis %d" % [int(p.get("age", 0)), float(p.get("salary", 0.0)), int(p.get("end", 0))], 12, U.BAD if ending else U.MUTED))
		var bv := U.vbox(4)
		h.add_child(bv)
		if ending:
			bv.add_child(U.button("Verlängern", _extend.bind(role), 110, 34))
		var rb := U.button("Schließen" if open_role == role else "Ersetzen", _toggle.bind(role), 110, 34)
		bv.add_child(rb)
		v.add_child(_wl(_effect(role), 12, U.ACCENT_TEXT))
		if open_role == role:
			v.add_child(_candidates(role, r))
		add_child(card)


func _candidates(role: String, cur: int) -> Control:
	var box := U.vbox(4)
	box.add_child(U.section("Kandidaten: " + str(Staff.KIND_TEXT[Staff.kind(role)]), 11))
	var list: Array = Game.staff_pool.filter(func(c): return str(c["role"]) == Staff.kind(role))
	list.sort_custom(func(a, b): return int(a["rating"]) > int(b["rating"]))
	var old: Dictionary = Game.staff.get(role, {})
	var fee := Staff.severance(old) if not old.is_empty() else 0.0
	if list.is_empty():
		box.add_child(_wl("Zurzeit keine Kandidaten. Zur nächsten Saison gibt es neue.", 12))
	for c in list:
		var row := U.hbox(8)
		var r := int(c["rating"])
		var rl := U.display(str(r), 20, Market.rating_color(r))
		rl.custom_minimum_size = Vector2(34, 0)
		row.add_child(rl)
		var iv := U.vbox(0)
		iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(iv)
		iv.add_child(U.label("%s  (%+d)" % [str(c["name"]), r - cur], 14, U.TEXT, true))
		var cost := fee + snappedf(float(c["salary"]) * 0.25, 0.1)
		iv.add_child(U.label("%d Jahre  ·  %.1f Mio. $ pro Saison  ·  bis %d  ·  Wechsel kostet %.1f Mio. $" % [int(c["age"]), float(c["salary"]), int(c["end"]), cost], 11, U.MUTED))
		var hb := U.button("Einstellen", _hire.bind(c, role), 100, 34)
		hb.disabled = Game.budget < cost
		row.add_child(hb)
		box.add_child(row)
	return box


func _toggle(role: String) -> void:
	open_role = "" if open_role == role else role
	_msg = ""
	rebuild.call_deferred()


func _extend(role: String) -> void:
	_msg = Staff.extend(role)
	Game.save()
	changed.emit()
	rebuild.call_deferred()


func _hire(c: Dictionary, role: String) -> void:
	_msg = Staff.hire(c, role)
	open_role = ""
	Game.save()
	changed.emit()
	rebuild.call_deferred()

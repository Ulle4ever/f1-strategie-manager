extends VBoxContainer
## Wetterbericht-Karte: Überschrift, Balkendiagramm, Dauer/Stärke/Sicherheit und eine Handlungsempfehlung.
## Wird im Wochenende und im Rennen verwendet; refresh(sim) aktualisiert die Anzeige.

const U = preload("res://scripts/ui.gd")
const Bars = preload("res://scripts/weather_bars.gd")
const RaceSim = preload("res://scripts/race_sim.gd")

var bars
var head: Label
var l_when: Label
var l_dur: Label
var l_int: Label
var l_conf: Label
var l_now: Label
var l_tip: Label
var l_temp: Label
var _last_key := ""


func _init() -> void:
	add_theme_constant_override("separation", 5)
	var top := U.hbox(8)
	add_child(top)
	top.add_child(U.section("Wetterbericht"))
	top.add_child(U.spacer())
	l_temp = U.label("", 12, U.MUTED)
	top.add_child(l_temp)
	head = U.label("", 18, U.TEXT, true)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(head)
	bars = Bars.new()
	add_child(bars)
	l_when = _line()
	l_dur = _line()
	l_int = _line()
	l_conf = _line()
	l_now = _line()
	l_tip = _line()
	l_tip.add_theme_color_override("font_color", U.WARN)


func _line() -> Label:
	var l := U.label("", 13, U.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(l)
	return l


func refresh(sim) -> void:
	var r: Dictionary = sim.forecast_report(16)
	var key := "%d|%d|%d|%s" % [int(sim.time / 20.0), int(sim.rain * 40.0), int(sim.wet * 40.0), str(r.get("has", false))]
	if key == _last_key:
		return
	_last_key = key
	bars.set_report(r, sim.laps)
	l_temp.text = "Luft %d °C   Asphalt %d °C" % [int(r["temp_air"]), int(r["temp_track"])]
	var clim := "Regenwahrscheinlichkeit der Strecke: %d %%" % int(sim.rain_chance * 100.0)
	if r["has"]:
		var col := U.BLUE
		var sm: float = float(r["start_min"])
		if sm < 1.0:
			head.text = "Es regnet: %s" % str(r["label"]).capitalize()
		else:
			head.text = "Regen ab ca. Runde %d" % int(r["start_lap"])
		head.add_theme_color_override("font_color", col)
		l_when.text = "Beginn in ca. %d min, Ende ca. Runde %d (nach ca. %d min)" % [int(round(sm)), int(r["end_lap"]), int(round(float(r["end_min"])))] if sm >= 1.0 else "Ende voraussichtlich um Runde %d (in ca. %d min)" % [int(r["end_lap"]), int(round(float(r["end_min"])))]
		l_dur.text = "Dauer: ca. %d min" % int(round(float(r["dur_min"])))
		l_int.text = "Stärke: %s, Spitze ca. %.1f mm/h" % [r["label"], r["peak_mm"]]
		l_conf.text = "Sicherheit der Vorhersage: %d %%   |   %s" % [int(float(r["conf"]) * 100.0), clim]
		var tip := ""
		if float(r["conf"]) < 0.5:
			tip = "Unsicher: Radar beobachten, nicht zu früh auf Regenreifen wetten."
		elif float(r["peak_mm"]) >= 7.6:
			tip = "Starker Regen: Full Wets einplanen, Safety Car wahrscheinlicher."
		elif float(r["peak_mm"]) >= 2.5:
			tip = "Mäßiger Regen: Intermediates, Stopp etwa eine Runde vor Regenbeginn."
		else:
			tip = "Leichter Regen: Slicks reichen oft, die Strecke wird nur feucht."
		l_tip.text = "Tipp: " + tip
	else:
		head.text = "Kein Regen erwartet"
		head.add_theme_color_override("font_color", U.GOOD if sim.rain_chance < 0.2 else U.MUTED)
		l_when.text = ""
		l_dur.text = ""
		l_int.text = ""
		l_conf.text = clim
		l_tip.text = "Tipp: Mit Slicks planen." if sim.rain_chance < 0.2 else "Tipp: Die Strecke ist regenanfällig, Prognose im Rennen im Blick behalten."
	l_now.text = "Jetzt: %s" % sim.weather_text()
	for l in [l_when, l_dur, l_int]:
		l.visible = l.text != ""

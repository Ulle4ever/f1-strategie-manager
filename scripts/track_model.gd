extends RefCounted
## Streckenmodell aus OpenStreetMap-Geometrie: Krümmung, Referenz-Geschwindigkeitsprofil
## (Quasi-Steady-State-Rundenzeitsimulation), Überholbarkeit, Reifenbelastung, Boxengassenzeit.

const V_TOP := 96.0           # m/s Höchstgeschwindigkeit
const CAL := 1.0              # Kalibrierfaktor für die Referenzrundenzeit

# Streckenspezifische Werte (Rest wird aus der Geometrie berechnet)
const PIT_LOSS := {
	"monaco": 19.0, "spa": 18.0, "silverstone": 20.0, "baku": 21.0, "jeddah": 18.0, "vegas": 19.0,
	"yas_marina": 20.0, "interlagos": 21.0, "marina_bay": 26.0, "albert_park": 21.0, "zandvoort": 17.0,
	"hungaroring": 21.0, "red_bull_ring": 20.0, "monza": 24.0, "suzuka": 22.0, "shanghai": 23.0,
	"americas": 21.0, "rodriguez": 22.0, "imola": 27.0, "bahrain": 22.0, "losail": 24.0, "miami": 19.0,
	"villeneuve": 17.0, "catalunya": 22.0, "madring": 20.0,
}
# Typische Pole-Zeiten (s) der letzten Jahre für ein Spitzenauto; kalibriert das Referenzprofil je Strecke
const REF_TIME := {
	"albert_park": 75.9, "americas": 94.0, "bahrain": 89.2, "baku": 101.0, "buddh": 84.5, "catalunya": 71.5,
	"fuji": 76.0, "hockenheimring": 72.0, "hungaroring": 76.0, "imola": 75.0, "indianapolis": 69.0,
	"interlagos": 70.0, "istanbul": 84.0, "jeddah": 87.0, "losail": 81.5, "madring": 85.0, "magny_cours": 74.0,
	"marina_bay": 90.0, "miami": 86.0, "monaco": 70.0, "monza": 79.5, "mugello": 75.0, "nurburgring": 85.0,
	"portimao": 77.5, "red_bull_ring": 64.5, "ricard": 89.0, "rodriguez": 76.5, "sepang": 92.0, "shanghai": 92.0,
	"silverstone": 85.0, "sochi": 94.0, "spa": 103.0, "suzuka": 88.5, "valencia": 94.0, "vegas": 92.5,
	"villeneuve": 71.0, "yas_marina": 82.0, "yeongam": 95.0, "zandvoort": 69.5,
}
# Reifenverschleiß (1.0 = Durchschnitt): Erfahrungswerte, Rest wird aus der Geometrie geschätzt
const TYRE_SEV := {
	"bahrain": 1.15, "catalunya": 1.2, "suzuka": 1.2, "silverstone": 1.15, "spa": 1.05, "interlagos": 1.0,
	"americas": 1.1, "shanghai": 1.1, "sepang": 1.15, "hungaroring": 1.0, "monaco": 0.78, "villeneuve": 0.85,
	"monza": 0.85, "baku": 0.85, "jeddah": 0.9, "miami": 0.95, "vegas": 0.85, "yas_marina": 0.95, "losail": 1.2,
	"zandvoort": 1.1, "imola": 0.95, "red_bull_ring": 1.0, "albert_park": 0.9, "marina_bay": 1.0, "rodriguez": 0.9,
	"portimao": 1.1, "mugello": 1.15, "ricard": 1.0, "sochi": 0.9, "nurburgring": 1.05, "hockenheimring": 0.95,
	"magny_cours": 1.0, "istanbul": 1.15, "fuji": 1.05, "buddh": 1.0, "valencia": 0.9, "yeongam": 1.0,
	"indianapolis": 1.05, "madring": 1.0,
}
const DF_NEED := {
	"monza": -0.9, "spa": -0.2, "baku": -0.6, "jeddah": -0.35, "vegas": -0.6, "red_bull_ring": -0.25, "rodriguez": 0.35,
	"interlagos": 0.0, "bahrain": -0.05, "albert_park": -0.1, "americas": 0.1, "suzuka": 0.4, "shanghai": 0.1, "silverstone": 0.3,
	"zandvoort": 0.55, "hungaroring": 0.85, "monaco": 1.0, "marina_bay": 0.85, "catalunya": 0.5, "imola": 0.35, "miami": -0.1,
	"losail": 0.4, "yas_marina": 0.0, "villeneuve": -0.35, "sochi": -0.1, "istanbul": 0.3, "sepang": 0.2, "magny_cours": 0.2,
	"hockenheimring": -0.3, "nurburgring": 0.2, "fuji": 0.0, "yeongam": 0.05, "buddh": 0.0, "valencia": 0.0, "indianapolis": 0.0,
	"portimao": 0.3, "mugello": 0.55, "ricard": 0.0, "madring": 0.4,
}
const OVERTAKE := {
	"monaco": 0.06, "hungaroring": 0.22, "zandvoort": 0.2, "imola": 0.25, "marina_bay": 0.28, "suzuka": 0.3,
	"albert_park": 0.4, "catalunya": 0.33, "magny_cours": 0.3, "valencia": 0.25, "sochi": 0.5, "mugello": 0.4,
	"portimao": 0.55, "ricard": 0.3, "monza": 0.85, "baku": 0.8, "bahrain": 0.75, "spa": 0.75, "americas": 0.75,
	"jeddah": 0.65, "vegas": 0.85, "interlagos": 0.7, "red_bull_ring": 0.75, "yas_marina": 0.65,
}

var id := ""
var track_name := ""
var country := ""
var locality := ""
var n := 0
var length := 0.0
var spacing := 8.0
var pts := PackedVector2Array()
var cum := PackedFloat32Array()        # kumulierte Länge je Punkt
var kappa := PackedFloat32Array()
var vref := PackedFloat32Array()       # Referenzgeschwindigkeit m/s je Punkt
var tcum := PackedFloat32Array()       # kumulierte Referenzzeit je Punkt (s)
var lap_ref := 90.0                    # Referenzrundenzeit (s)
var tyre_severity := 1.0
var overtake_ease := 0.5
var pit_loss := 21.0
var bounds := Rect2()
var straights: Array = []              # [[s0, s1], ...] DRS-taugliche Geraden
var corner_speed_min := 0.0
var mean_lat := 0.0


static func load_track(circuit_id: String):
	var path := "res://data/tracks/%s.json" % circuit_id
	if not FileAccess.file_exists(path):
		return null
	var txt := FileAccess.get_file_as_string(path)
	var d = JSON.parse_string(txt)
	if typeof(d) != TYPE_DICTIONARY:
		return null
	var t = load("res://scripts/track_model.gd").new()
	t.setup(d)
	return t


func setup(d: Dictionary) -> void:
	id = d["id"]
	track_name = d["name"]
	country = d.get("country", "")
	locality = d.get("locality", "")
	var raw: Array = d["points"]
	var start: int = int(d.get("start", 0))
	n = raw.size()
	pts.resize(n)
	for i in n:
		var p: Array = raw[(i + start) % n]
		pts[i] = Vector2(float(p[0]), float(p[1]))
	if bool(d.get("reverse", false)):
		var r := PackedVector2Array()
		for i in n:
			r.append(pts[(n - i) % n])
		pts = r
	_measure()
	_curvature()
	if not d.has("start"):
		_auto_start()
		_measure()
		_curvature()
	_profile()
	pit_loss = PIT_LOSS.get(id, 21.0)


func _measure() -> void:
	cum.resize(n + 1)
	var acc := 0.0
	for i in n:
		cum[i] = acc
		acc += pts[i].distance_to(pts[(i + 1) % n])
	cum[n] = acc
	length = acc
	spacing = length / n
	var rect := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		rect = rect.expand(p)
	bounds = rect


## Start/Ziel auf die längste Gerade legen (ca. 60 % der Geraden).
func _auto_start() -> void:
	var best_len := 0
	var best_start := 0
	var run := 0
	var run_start := 0
	for step in n * 2:
		var i := step % n
		if kappa[i] < 0.0012:
			if run == 0:
				run_start = i
			run += 1
			if run > best_len and run < n:
				best_len = run
				best_start = run_start
		else:
			run = 0
	var start := (best_start + int(best_len * 0.6)) % n
	var rot := PackedVector2Array()
	rot.resize(n)
	for i in n:
		rot[i] = pts[(i + start) % n]
	pts = rot


func _curvature() -> void:
	kappa.resize(n)
	var k := maxi(2, int(round(36.0 / spacing)))
	var raw := PackedFloat32Array()
	raw.resize(n)
	for i in n:
		var a: Vector2 = pts[i] - pts[(i - k + n) % n]
		var b: Vector2 = pts[(i + k) % n] - pts[i]
		var ang := absf(a.angle_to(b))
		raw[i] = ang / maxf(a.length() * 0.5 + b.length() * 0.5, 1.0)
	for i in n:
		kappa[i] = (raw[(i - 1 + n) % n] + 2.0 * raw[i] + raw[(i + 1) % n]) * 0.25


func _profile() -> void:
	vref.resize(n)
	var vmax := PackedFloat32Array()
	vmax.resize(n)
	for i in n:
		var kp: float = kappa[i]
		var v := V_TOP
		if kp > 0.0042:
			v = minf(V_TOP, sqrt(22.0 / (kp - 0.0040)))
		vmax[i] = maxf(v, 14.0)
	for i in n:
		vref[i] = vmax[i]
	# Vorwärts (Beschleunigung) und Rückwärts (Bremsen), zwei Umläufe
	for _pass in 2:
		for step in n * 2:
			var i := step % n
			var j := (i + 1) % n
			var v: float = vref[i]
			var acc: float = 11.0 * (1.0 - pow(v / V_TOP, 2.0)) + 0.3
			var v2: float = sqrt(v * v + 2.0 * maxf(acc, 0.0) * spacing)
			if v2 < vref[j]:
				vref[j] = v2
		for step in n * 2:
			var i := (n - 1 - step % n)
			var j := (i + 1) % n
			var v: float = vref[j]
			var br: float = 35.0 + 0.0025 * v * v
			var v2: float = sqrt(v * v + 2.0 * br * spacing)
			if v2 < vref[i]:
				vref[i] = v2
	tcum.resize(n + 1)
	var t := 0.0
	var vmin := 999.0
	var load_sum := 0.0
	for i in n:
		var j := (i + 1) % n
		var vavg: float = 0.5 * (vref[i] + vref[j])
		tcum[i] = t
		t += spacing / vavg
		vmin = minf(vmin, vref[i])
		load_sum += vref[i] * vref[i] * kappa[i]
	tcum[n] = t
	lap_ref = t * CAL
	if REF_TIME.has(id):
		var k: float = float(REF_TIME[id]) / t
		for i in n:
			vref[i] = vref[i] / k
		for i in n + 1:
			tcum[i] = tcum[i] * k
		lap_ref = REF_TIME[id]
	corner_speed_min = vmin * (t / lap_ref)
	mean_lat = load_sum / n
	tyre_severity = clampf(0.30 + mean_lat / 14.0, 0.85, 1.3)
	if TYRE_SEV.has(id):
		tyre_severity = TYRE_SEV[id]
	# Geraden: Krümmung klein, mind. 280 m
	straights = []
	var run_start := -1
	for step in n * 2:
		var i := step % n
		var is_str: bool = kappa[i] < 0.0012
		if is_str and run_start < 0:
			run_start = step
		elif not is_str and run_start >= 0:
			var l := (step - run_start) * spacing
			if l >= 280.0 and run_start < n:
				straights.append([float(run_start % n) * spacing, float(step % n) * spacing, l])
			run_start = -1
	var longest := 0.0
	var total := 0.0
	for s in straights:
		longest = maxf(longest, float(s[2]))
		total += float(s[2])
	overtake_ease = clampf(0.2 + longest / 1500.0 + total / length * 0.4, 0.1, 0.95)
	if OVERTAKE.has(id):
		overtake_ease = OVERTAKE[id]


## Typisch beste Abtriebs-Einstellung (-1 Topspeed .. +1 maximaler Abtrieb).
func df_need() -> float:
	return float(DF_NEED.get(id, 0.0))


## Wie wichtig Motorleistung/Topspeed ist (-1 .. +1), grob das Gegenstück zum Abtriebsbedarf.
func power_need() -> float:
	return clampf(0.2 - 0.8 * df_need(), -0.6, 1.0)


## Index des Punktes bei Streckenposition s (0..length).
func index_at(s: float) -> int:
	var ss := fposmod(s, length)
	var lo := 0
	var hi := n
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if cum[mid] <= ss:
			lo = mid
		else:
			hi = mid
	return lo


func point_at(s: float) -> Vector2:
	var ss := fposmod(s, length)
	var i := index_at(ss)
	var j := (i + 1) % n
	var seg: float = cum[i + 1] - cum[i]
	var f := 0.0 if seg <= 0.0 else (ss - cum[i]) / seg
	return pts[i].lerp(pts[j], f)


func speed_at(s: float) -> float:
	var ss := fposmod(s, length)
	var i := index_at(ss)
	var j := (i + 1) % n
	var seg: float = cum[i + 1] - cum[i]
	var f := 0.0 if seg <= 0.0 else (ss - cum[i]) / seg
	return lerpf(vref[i], vref[j], f)


## Referenzzeit (s), die ein Auto mit Pace 1.0 vom Start bis zur Gesamtstrecke dist benötigt.
func time_at(dist: float) -> float:
	var laps := floorf(dist / length)
	var ss := dist - laps * length
	var i := index_at(ss)
	var seg: float = cum[i + 1] - cum[i]
	var f := 0.0 if seg <= 0.0 else (ss - cum[i]) / seg
	return laps * tcum[n] + lerpf(tcum[i], tcum[i + 1], f)


## Streckenposition (m) bei Anteil f (0..1) der Referenzrundenzeit.
func dist_at_frac(f: float) -> float:
	var target := clampf(f, 0.0, 1.0) * tcum[n]
	var lo := 0
	var hi := n
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if tcum[mid] <= target:
			lo = mid
		else:
			hi = mid
	var seg: float = tcum[lo + 1] - tcum[lo]
	var fr := 0.0 if seg <= 0.0 else (target - tcum[lo]) / seg
	return cum[lo] + (cum[lo + 1] - cum[lo]) * fr


func in_drs_zone(s: float) -> bool:
	var ss := fposmod(s, length)
	for z in straights:
		var a: float = z[0]
		var b: float = z[1]
		if a <= b:
			if ss >= a and ss <= b:
				return true
		elif ss >= a or ss <= b:
			return true
	return false

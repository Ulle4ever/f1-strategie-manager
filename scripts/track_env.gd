extends RefCounted
## Streckenumgebung für die Karte: je Strecke ein Landschaftstyp (Wüste, Wald, Felder, Stadt, Dünen, Insel ...),
## Wasser (Küste in Himmelsrichtung, See im Innenraum), Gebäude, Bäume und Felder. Alles in Weltkoordinaten (Meter),
## deterministisch aus der Strecken-ID erzeugt, damit es beim Verschieben und Zoomen mitwandert.

const KINDS := {
	"desert": {"ground": Color(0.92, 0.85, 0.68), "dune": 0.55, "scrub": 1.0, "patch": [Color(0.90, 0.82, 0.64), Color(0.95, 0.89, 0.74)]},
	"forest": {"ground": Color(0.60, 0.76, 0.57), "tree": 1.0, "tcol": [Color(0.30, 0.55, 0.32), Color(0.36, 0.62, 0.36), Color(0.26, 0.50, 0.30)]},
	"farm": {"ground": Color(0.81, 0.89, 0.67), "field": 1.0, "tree": 0.18, "fcol": [Color(0.75, 0.86, 0.61), Color(0.87, 0.91, 0.67), Color(0.91, 0.89, 0.63), Color(0.69, 0.83, 0.59)], "tcol": [Color(0.35, 0.60, 0.36), Color(0.40, 0.66, 0.40)]},
	"dry": {"ground": Color(0.89, 0.85, 0.69), "field": 0.9, "scrub": 0.7, "tree": 0.05, "fcol": [Color(0.91, 0.87, 0.67), Color(0.85, 0.81, 0.63), Color(0.94, 0.89, 0.71)], "tcol": [Color(0.50, 0.64, 0.40)]},
	"city": {"ground": Color(0.90, 0.91, 0.93), "bld": 1.0, "tree": 0.12, "bcol": [Color(0.76, 0.79, 0.85), Color(0.82, 0.84, 0.89), Color(0.72, 0.75, 0.82)], "tcol": [Color(0.45, 0.70, 0.45)]},
	"suburb": {"ground": Color(0.85, 0.91, 0.83), "bld": 0.35, "tree": 0.5, "field": 0.3, "bcol": [Color(0.78, 0.80, 0.86), Color(0.84, 0.84, 0.88)], "tcol": [Color(0.40, 0.66, 0.42), Color(0.46, 0.72, 0.46)], "fcol": [Color(0.79, 0.89, 0.73), Color(0.85, 0.91, 0.75)]},
	"tropical": {"ground": Color(0.56, 0.77, 0.53), "palm": 0.8, "tree": 0.9, "tcol": [Color(0.28, 0.58, 0.32), Color(0.33, 0.64, 0.36)], "bld": 0.08, "bcol": [Color(0.78, 0.80, 0.86)]},
	"dunes": {"ground": Color(0.93, 0.87, 0.71), "dune": 0.7, "scrub": 0.8, "tree": 0.25, "tcol": [Color(0.46, 0.64, 0.42)], "patch": [Color(0.94, 0.89, 0.75), Color(0.75, 0.85, 0.63)]},
	"desert_city": {"ground": Color(0.92, 0.86, 0.71), "dune": 0.35, "scrub": 0.6, "bld": 0.5, "bcol": [Color(0.78, 0.80, 0.86), Color(0.84, 0.83, 0.88)], "patch": [Color(0.94, 0.88, 0.73)]},
	"island": {"ground": Color(0.60, 0.79, 0.93), "tree": 0.5, "field": 0.4, "tcol": [Color(0.35, 0.60, 0.36), Color(0.40, 0.66, 0.40)], "fcol": [Color(0.74, 0.86, 0.62)], "bld": 0.25, "bcol": [Color(0.78, 0.80, 0.86)]},
}

# kind, Küste(n): [Himmelsrichtung des Wassers in Grad (0 = Nord, 90 = Ost), Lage der Küste 0..1.2 (1 = am Rand der Strecke)], lake = See im Innenraum (Anteil)
const TRACKS := {
	"albert_park": {"kind": "farm", "lake": 0.55},
	"americas": {"kind": "dry"},
	"bahrain": {"kind": "desert"},
	"baku": {"kind": "city", "coast": [[140.0, 0.55]]},
	"buddh": {"kind": "dry"},
	"catalunya": {"kind": "dry"},
	"fuji": {"kind": "forest"},
	"hockenheimring": {"kind": "forest"},
	"hungaroring": {"kind": "dry"},
	"imola": {"kind": "farm"},
	"indianapolis": {"kind": "suburb"},
	"interlagos": {"kind": "city"},
	"istanbul": {"kind": "dry"},
	"jeddah": {"kind": "desert_city", "coast": [[275.0, 0.8]]},
	"losail": {"kind": "desert"},
	"madring": {"kind": "city"},
	"magny_cours": {"kind": "farm"},
	"marina_bay": {"kind": "city", "coast": [[160.0, 0.75]], "lake": 0.38},
	"miami": {"kind": "suburb", "coast": [[85.0, 1.1]]},
	"monaco": {"kind": "city", "coast": [[165.0, 0.78]]},
	"monza": {"kind": "forest"},
	"mugello": {"kind": "farm"},
	"nurburgring": {"kind": "forest"},
	"portimao": {"kind": "dry"},
	"red_bull_ring": {"kind": "farm"},
	"ricard": {"kind": "dry"},
	"rodriguez": {"kind": "city"},
	"sepang": {"kind": "tropical"},
	"shanghai": {"kind": "suburb"},
	"silverstone": {"kind": "farm"},
	"sochi": {"kind": "suburb", "coast": [[235.0, 0.85]]},
	"spa": {"kind": "forest"},
	"suzuka": {"kind": "forest"},
	"valencia": {"kind": "city", "coast": [[100.0, 0.5]]},
	"vegas": {"kind": "desert_city"},
	"villeneuve": {"kind": "island"},
	"yas_marina": {"kind": "desert", "coast": [[150.0, 0.7]]},
	"yeongam": {"kind": "dry", "coast": [[230.0, 0.75]]},
	"zandvoort": {"kind": "dunes", "coast": [[280.0, 0.92]]},
}

const WATER := Color(0.60, 0.79, 0.93)
const WATER_EDGE := Color(0.40, 0.64, 0.85)


## Umgebung für eine Strecke bauen. mobile = weniger Objekte.
static var _cache := {}


static func build(track, mobile := false) -> Dictionary:
	var key := "%s|%s" % [track.id, mobile]
	if _cache.has(key):
		return _cache[key]
	var env := _build(track, mobile)
	_cache[key] = env
	return env


## Polygon prüfen (Dreiecksaufteilung möglich), sonst konvexe Hülle.
static func _safe_poly(poly: PackedVector2Array) -> PackedVector2Array:
	if poly.size() >= 3 and Geometry2D.triangulate_polygon(poly).size() > 0:
		return poly
	return Geometry2D.convex_hull(poly)


static func _build(track, mobile: bool) -> Dictionary:
	var spec: Dictionary = TRACKS.get(track.id, {"kind": "farm"})
	var kind: String = str(spec["kind"])
	var kd: Dictionary = KINDS[kind]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(track.id) & 0x7fffffff
	var b: Rect2 = track.bounds
	var c: Vector2 = b.position + b.size * 0.5
	var env := {"kind": kind, "ground": kd["ground"], "water": [], "land": [], "items": [], "fields": []}
	var area := b.grow(650.0)
	var corridor := _corridor(track)
	# Wasserflächen
	var waters: Array = []
	for co in spec.get("coast", []):
		var ang := deg_to_rad(float(co[0]))
		var d := Vector2(sin(ang), -cos(ang))
		var nrm := Vector2(-d.y, d.x)
		var half := 0.5 * (absf(d.x) * b.size.x + absf(d.y) * b.size.y)
		var s: float = half * float(co[1]) + 40.0
		var poly := PackedVector2Array()
		var t := -5000.0
		var ph := rng.randf() * TAU
		while t <= 5000.0:
			poly.append(c + d * (s + 38.0 * sin(t / 310.0 + ph) + 22.0 * sin(t / 97.0 + ph * 2.0)) + nrm * t)
			t += 80.0
		poly.append(c + d * (s + 6000.0) + nrm * 5000.0)
		poly.append(c + d * (s + 6000.0) - nrm * 5000.0)
		env["water"].append({"poly": _safe_poly(poly), "kind": "coast", "d": d, "s": s, "c": c})
		waters.append({"kind": "coast", "d": d, "s": s, "c": c})
	if float(spec.get("lake", 0.0)) > 0.0:
		var f: float = float(spec["lake"])
		var cen := Vector2.ZERO
		for p in track.pts:
			cen += p
		cen /= float(track.n)
		var poly2 := PackedVector2Array()
		var st := maxi(1, track.n / 70)
		for i in range(0, track.n, st):
			var q: Vector2 = track.pts[i]
			var pp: Vector2 = cen + (q - cen) * f
			poly2.append(pp + Vector2(rng.randfn(0.0, 6.0), rng.randfn(0.0, 6.0)))
		poly2 = _safe_poly(poly2)
		env["water"].append({"poly": poly2, "kind": "lake"})
		waters.append({"kind": "lake", "poly": poly2})
	if kind == "island":
		var land: Array = []
		var st2 := maxi(1, track.n / 90)
		for i in range(0, track.n, st2):
			land.append({"p": track.pts[i], "r": 210.0 + rng.randf() * 40.0})
		env["land"] = land
	# Objekte
	var scale_n := 0.45 if mobile else 1.0
	var w := area.size.x
	var h := area.size.y
	var asz := w * h
	var tcol: Array = kd.get("tcol", [Color(0.07, 0.2, 0.1)])
	var items: Array = env["items"]
	var n_tree := int(float(kd.get("tree", 0.0)) * asz / 5200.0 * scale_n)
	for i in mini(n_tree, 1400):
		var p := Vector2(area.position.x + rng.randf() * w, area.position.y + rng.randf() * h)
		if _blocked(p, corridor, waters, env, 70.0):
			continue
		items.append({"t": "tree", "p": p, "r": rng.randf_range(9.0, 24.0), "col": tcol[rng.randi() % tcol.size()]})
	var n_palm := int(float(kd.get("palm", 0.0)) * asz / 14000.0 * scale_n)
	for i in mini(n_palm, 500):
		var p := Vector2(area.position.x + rng.randf() * w, area.position.y + rng.randf() * h)
		if _blocked(p, corridor, waters, env, 60.0):
			continue
		items.append({"t": "palm", "p": p, "r": rng.randf_range(10.0, 16.0), "col": Color(0.20, 0.52, 0.28)})
	var n_scrub := int(float(kd.get("scrub", 0.0)) * asz / 6500.0 * scale_n)
	for i in mini(n_scrub, 700):
		var p := Vector2(area.position.x + rng.randf() * w, area.position.y + rng.randf() * h)
		if _blocked(p, corridor, waters, env, 50.0):
			continue
		items.append({"t": "scrub", "p": p, "r": rng.randf_range(4.0, 9.0), "col": Color(0.55, 0.58, 0.38, 0.9)})
	var n_dune := int(float(kd.get("dune", 0.0)) * asz / 52000.0 * scale_n)
	for i in mini(n_dune, 160):
		var p := Vector2(area.position.x + rng.randf() * w, area.position.y + rng.randf() * h)
		if _blocked(p, corridor, waters, env, 90.0):
			continue
		var ang := rng.randf() * TAU
		var ln := rng.randf_range(120.0, 320.0)
		var pts := PackedVector2Array()
		for k in 9:
			var u := float(k) / 8.0 - 0.5
			pts.append(p + Vector2(cos(ang), sin(ang)) * u * ln + Vector2(-sin(ang), cos(ang)) * (u * u * -ln * 0.35))
		items.append({"t": "dune", "pts": pts, "col": Color(0.78, 0.68, 0.48, 0.6), "w": rng.randf_range(10.0, 22.0)})
	# Gebäude auf Straßenraster
	if kd.has("bld"):
		var bcol: Array = kd["bcol"]
		var grid_a := rng.randf() * 0.6 - 0.3
		var gx := Vector2(cos(grid_a), sin(grid_a))
		var gy := Vector2(-gx.y, gx.x)
		var cell := 95.0 if kind != "suburb" else 120.0
		var nb := int(float(kd["bld"]) * 1.0)
		var u0 := -area.size.x * 0.75
		var count := 0
		var max_b := int(1500.0 * scale_n)
		while u0 < area.size.x * 0.75 and count < max_b:
			var v0 := -area.size.y * 0.75
			while v0 < area.size.y * 0.75 and count < max_b:
				var p := c + gx * u0 + gy * v0
				if area.has_point(p) and rng.randf() < float(kd["bld"]) * 0.8:
					var pj := p + gx * rng.randf_range(-12.0, 12.0) + gy * rng.randf_range(-12.0, 12.0)
					if not _blocked(pj, corridor, waters, env, 46.0):
						var bw := rng.randf_range(0.38, 0.8) * cell
						var bh2 := rng.randf_range(0.38, 0.8) * cell
						items.append({"t": "bld", "p": pj, "gx": gx, "gy": gy, "w": bw, "h": bh2, "col": bcol[rng.randi() % bcol.size()]})
						count += 1
				v0 += cell
			u0 += cell
	# Felder (Flickenteppich)
	if kd.has("field"):
		var fcol: Array = kd["fcol"]
		var nf := int(float(kd["field"]) * asz / 62000.0 * scale_n)
		for i in mini(nf, 260):
			var p := Vector2(area.position.x + rng.randf() * w, area.position.y + rng.randf() * h)
			if _blocked(p, corridor, waters, env, 80.0):
				continue
			var fw := rng.randf_range(160.0, 420.0)
			var fh := rng.randf_range(120.0, 320.0)
			var fa := rng.randf_range(-0.5, 0.5)
			var gxx := Vector2(cos(fa), sin(fa))
			var gyy := Vector2(-gxx.y, gxx.x)
			env["fields"].append({"poly": PackedVector2Array([p - gxx * fw * 0.5 - gyy * fh * 0.5, p + gxx * fw * 0.5 - gyy * fh * 0.5, p + gxx * fw * 0.5 + gyy * fh * 0.5, p - gxx * fw * 0.5 + gyy * fh * 0.5]), "col": fcol[rng.randi() % fcol.size()]})
	if kd.has("patch"):
		var pcol: Array = kd["patch"]
		for i in int(42.0 * scale_n) + 8:
			var p := Vector2(area.position.x + rng.randf() * w, area.position.y + rng.randf() * h)
			if _blocked(p, corridor, waters, env, 60.0):
				continue
			var rr := rng.randf_range(120.0, 300.0)
			var poly3 := PackedVector2Array()
			for k in 10:
				var a := TAU * float(k) / 10.0
				poly3.append(p + Vector2(cos(a), sin(a)) * rr * rng.randf_range(0.7, 1.15))
			env["fields"].append({"poly": poly3, "col": pcol[rng.randi() % pcol.size()]})
	return env


## Raster der Streckennähe (Zellen 50 m): dort werden keine Objekte gesetzt.
static func _corridor(track) -> Dictionary:
	var g := {}
	for i in range(0, track.n, 2):
		var p: Vector2 = track.pts[i]
		var cx := int(floor(p.x / 50.0))
		var cy := int(floor(p.y / 50.0))
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				g[Vector2i(cx + dx, cy + dy)] = true
	return g


static func _in_water(p: Vector2, waters: Array) -> bool:
	for w in waters:
		if w["kind"] == "coast":
			if (p - Vector2(w["c"])).dot(Vector2(w["d"])) > float(w["s"]) - 6.0:
				return true
		elif Geometry2D.is_point_in_polygon(p, w["poly"]):
			return true
	return false


static func _blocked(p: Vector2, corridor: Dictionary, waters: Array, env: Dictionary, margin: float) -> bool:
	if corridor.has(Vector2i(int(floor(p.x / 50.0)), int(floor(p.y / 50.0)))):
		return true
	if _in_water(p, waters):
		return true
	if env["kind"] == "island":
		var on_land := false
		for l in env["land"]:
			if p.distance_to(l["p"]) < float(l["r"]):
				on_land = true
				break
		if not on_land:
			return true
	return false

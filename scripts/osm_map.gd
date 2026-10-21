extends RefCounted
## Echte Umgebung der Strecke aus OpenStreetMap (data/env/<id>.json, erzeugt mit tools/fetch_env.js):
## Meer, Flächen, Flüsse, Straßen, Bahn, Gebäude mit Schatten und Bäume. Alles wird einmal zu einem
## Dreiecksnetz (Weltkoordinaten in Metern) zusammengesetzt und dann mit einem einzigen Zeichenaufruf
## skaliert dargestellt. Kartendaten © OpenStreetMap-Mitwirkende (ODbL).

const ATTRIBUTION := "Karte © OpenStreetMap-Mitwirkende"

# Untergrund je Landschaftstyp aus track_env.gd (etwas satter als eine Straßenkarte)
const GROUND := {
	"desert": Color(0.91, 0.85, 0.70), "desert_city": Color(0.91, 0.86, 0.74), "dunes": Color(0.90, 0.87, 0.74),
	"city": Color(0.91, 0.90, 0.87), "suburb": Color(0.88, 0.90, 0.83), "dry": Color(0.89, 0.88, 0.76),
}
const GROUND_DEFAULT := Color(0.84, 0.89, 0.76)
const AREA := {
	"island": Color(0.86, 0.89, 0.80), "resid": Color(0.90, 0.88, 0.85), "indus": Color(0.87, 0.85, 0.89),
	"farm": Color(0.87, 0.90, 0.71), "grass": Color(0.69, 0.84, 0.55), "scrub": Color(0.74, 0.84, 0.60),
	"sand": Color(0.95, 0.88, 0.68), "pitch": Color(0.58, 0.80, 0.50), "sport": Color(0.78, 0.88, 0.72),
	"wood": Color(0.55, 0.75, 0.47), "water": Color(0.47, 0.73, 0.92), "paved": Color(0.84, 0.84, 0.86),
}
const FARM_TINTS := [Color(0.87, 0.90, 0.71), Color(0.82, 0.88, 0.64), Color(0.91, 0.89, 0.69), Color(0.78, 0.86, 0.63), Color(0.90, 0.86, 0.66)]
const WATER := Color(0.47, 0.73, 0.92)
const WATER_DEEP := Color(0.40, 0.66, 0.88)
# Linien: Breite (m), Füllung, Rand (Rand null = ohne)
const LINES := {
	"r_major": [16.0, Color(0.99, 0.87, 0.55), Color(0.86, 0.68, 0.33)],
	"r_mid": [11.0, Color(1.0, 0.97, 0.88), Color(0.80, 0.76, 0.68)],
	"r_minor": [8.0, Color(1.0, 1.0, 1.0), Color(0.78, 0.77, 0.74)],
	"r_service": [5.0, Color(0.98, 0.98, 0.98), Color(0.80, 0.79, 0.77)],
	"r_track": [3.5, Color(0.86, 0.80, 0.68), null],
	"r_path": [2.0, Color(0.97, 0.95, 0.92), null],
	"raceway": [11.0, Color(0.52, 0.55, 0.60), Color(0.90, 0.90, 0.92)],
	"rail": [3.0, Color(0.58, 0.58, 0.64), null],
	"river": [16.0, WATER, null],
	"stream": [4.0, WATER, null],
}
const ROAD_ORDER := ["r_path", "r_track", "r_service", "r_minor", "r_mid", "r_major", "raceway"]
const ROOF := [Color(0.85, 0.83, 0.80), Color(0.88, 0.80, 0.72), Color(0.74, 0.78, 0.86)]   # Gewerbe, Wohnhaus, Tribüne
const TREE := [Color(0.36, 0.60, 0.33), Color(0.42, 0.66, 0.37), Color(0.31, 0.55, 0.31)]
const SHADOW := Color(0.10, 0.12, 0.10, 0.22)
const SUN := Vector2(0.55, 0.85)          # Schattenrichtung (m je m Höhe, gestaucht)
const MAX_TREES := 7000
const MAX_TREES_LITE := 2500
const MAX_BLD_LITE := 6000            # Handy/Tablet: nur die größten Gebäude

static var _cache := {}                   # id -> Dictionary (nur die zuletzt benutzte Strecke)

var id := ""
var mesh: ArrayMesh = null
var ground := GROUND_DEFAULT
var rect := Rect2()
var ok := false

var lite := false                      # Handy/Tablet: weniger Bäume und Schatten
var _v := PackedVector2Array()
var _c := PackedColorArray()
var _i := PackedInt32Array()


static func has_data(circuit_id: String) -> bool:
	return FileAccess.file_exists("res://data/env/%s.json.gz" % circuit_id)


## Liefert die fertige Karte (aus dem Zwischenspeicher, wenn dieselbe Strecke schon gebaut wurde).
static func get_for(circuit_id: String, kind: String, light := false):
	if _cache.has(circuit_id):
		return _cache[circuit_id]
	if not has_data(circuit_id):
		return null
	var m = load("res://scripts/osm_map.gd").new()
	m.lite = light
	m.build(circuit_id, kind)
	if not m.ok:
		return null
	_cache.clear()
	_cache[circuit_id] = m
	return m


func build(circuit_id: String, kind: String) -> void:
	id = circuit_id
	ground = GROUND.get(kind, GROUND_DEFAULT)
	var raw := FileAccess.get_file_as_bytes("res://data/env/%s.json.gz" % circuit_id)
	var d = JSON.parse_string(raw.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8())
	if typeof(d) != TYPE_DICTIONARY:
		return
	var r: Array = d["rect"]
	rect = Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(circuit_id)
	# Untergrund nach dem, was überwiegt: bebaut (Stadt) oder grün
	var areas: Dictionary = d.get("areas", {})
	var built := 0.0
	var green := 0.0
	for cls in areas.keys():
		for p in areas[cls]:
			var a := _area(_pts(p))
			if cls in ["resid", "indus", "paved"]:
				built += a
			elif cls in ["grass", "wood", "farm", "scrub", "pitch"]:
				green += a
	if built > green * 1.2 and not kind.begins_with("desert"):
		ground = GROUND["city"]
	# Meer und Inseln
	var sea: Array = d.get("sea", [])
	for p in sea:
		_poly(_pts(p), WATER_DEEP)
	for p in d.get("land", []):
		_poly(_pts(p), ground)
	# Flächen in fester Reihenfolge
	var woods: Array = []
	for cls in d.get("order", []):
		if not areas.has(cls):
			continue
		for p in areas[cls]:
			var pts := _pts(p)
			var col: Color = AREA.get(cls, ground)
			if cls == "farm":
				col = FARM_TINTS[rng.randi() % FARM_TINTS.size()]
			elif cls == "island":
				col = ground
			_poly(pts, col)
			if cls == "wood":
				woods.append(pts)
	# Flüsse
	var lines: Dictionary = d.get("lines", {})
	for cls in ["river", "stream"]:
		for l in lines.get(cls, []):
			_line(_pts(l), LINES[cls][0], LINES[cls][1])
	# Straßen: erst alle Ränder, dann die Füllungen (Brücken obenauf)
	for pass_i in 2:
		for bridge in [false, true]:
			for cls in ROAD_ORDER:
				var spec: Array = LINES[cls]
				var key: String = cls + ("_b" if bridge else "")
				for l in lines.get(key, []):
					var pts := _pts(l)
					if pass_i == 0:
						if spec[2] != null:
							_line(pts, spec[0] + 2.4, spec[2])
					else:
						_line(pts, spec[0], spec[1])
	for l in lines.get("rail", []):
		_line(_pts(l), LINES["rail"][0], LINES["rail"][1])
	# Gebäude: Schatten, dann Dach
	var blds: Array = d.get("bld", [])
	if lite and blds.size() > MAX_BLD_LITE:
		var sized: Array = []
		for b in blds:
			sized.append([_area(_pts(b, 2)), b])
		sized.sort_custom(func(x, y): return x[0] > y[0])
		blds = []
		for k in MAX_BLD_LITE:
			blds.append(sized[k][1])
	for b in blds:
		var h := float(b[0])
		var pts := _pts(b, 2)
		if lite and (h < 8.0 or _area(pts) < 150.0):
			continue
		var off := SUN * clampf(h * 0.35, 1.2, 14.0)
		var sh := PackedVector2Array()
		for q in pts:
			sh.append(q + off)
		_poly(sh, SHADOW)
	for b in blds:
		var kind_b := int(b[1])
		var pts2 := _pts(b, 2)
		var col2: Color = ROOF[clampi(kind_b, 0, 2)]
		var sz := hash(int(b[2]) * 31 + int(b[3]))
		col2 = col2.lightened(float(sz % 9) * 0.008).darkened(float(sz % 5) * 0.012)
		_poly(pts2, col2)
	# Bäume: echte Einzelbäume plus Kronen in Waldflächen
	var trees := PackedVector2Array()
	var tr: Array = d.get("trees", [])
	for i in range(0, tr.size() - 1, 2):
		trees.append(Vector2(float(tr[i]), float(tr[i + 1])))
	var max_t := MAX_TREES_LITE if lite else MAX_TREES
	if trees.size() > max_t:
		var thin := PackedVector2Array()
		var every := float(trees.size()) / float(max_t)
		var acc := 0.0
		while int(acc) < trees.size():
			thin.append(trees[int(acc)])
			acc += every
		trees = thin
	var budget := max_t - trees.size()
	var wood_area := 0.0
	for w in woods:
		wood_area += _area(w)
	var density := clampf(float(budget) / maxf(wood_area / 90.0, 1.0), 0.0, 1.0)
	for w in woods:
		var bb := Rect2(w[0], Vector2.ZERO)
		for q in w:
			bb = bb.expand(q)
		var want := int(_area(w) / 90.0 * density)
		var tries := want * 2 + 4
		while want > 0 and tries > 0:
			tries -= 1
			var p := Vector2(rng.randf_range(bb.position.x, bb.end.x), rng.randf_range(bb.position.y, bb.end.y))
			if Geometry2D.is_point_in_polygon(p, w):
				trees.append(p)
				want -= 1
	if not lite:
		for p in trees:
			_ngon(p + SUN * 3.0, 4.2, Color(0.08, 0.14, 0.06, 0.20), 6)
	for p in trees:
		var tc: Color = TREE[int(absf(p.x * 7.0 + p.y * 13.0)) % TREE.size()]
		_ngon(p, 4.0 + fmod(absf(p.x * 0.37 + p.y * 0.11), 1.6), tc, 6)
		if not lite:
			_ngon(p - Vector2(1.1, 1.1), 1.8, tc.lightened(0.18), 5)
	if _v.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_COLOR] = _c
	arrays[Mesh.ARRAY_INDEX] = _i
	mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_v = PackedVector2Array()
	_c = PackedColorArray()
	_i = PackedInt32Array()
	ok = true


func vertex_count() -> int:
	return mesh.surface_get_array_len(0) if mesh != null else 0


func index_count() -> int:
	return mesh.surface_get_array_index_len(0) if mesh != null else 0


# ------------------------------------------------------------------ Bausteine

func _pts(a: Array, from: int = 0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var i := from
	while i + 1 < a.size():
		out.append(Vector2(float(a[i]), float(a[i + 1])))
		i += 2
	return out


func _area(p: PackedVector2Array) -> float:
	var s := 0.0
	for i in p.size():
		var q := p[(i + 1) % p.size()]
		s += p[i].x * q.y - q.x * p[i].y
	return absf(s) * 0.5


func _poly(p: PackedVector2Array, col: Color) -> void:
	if p.size() < 3:
		return
	var idx := Geometry2D.triangulate_polygon(p)
	var base := _v.size()
	if idx.is_empty():
		# ungültige (sich schneidende) Polygone: Fächer aus dem Schwerpunkt als Notlösung
		if p.size() > 40:
			return
		var c := Vector2.ZERO
		for q in p:
			c += q
		_v.append(c / float(p.size()))
		_c.append(col)
		for q in p:
			_v.append(q)
			_c.append(col)
		for i in p.size():
			_i.append(base)
			_i.append(base + 1 + i)
			_i.append(base + 1 + (i + 1) % p.size())
		return
	_v.append_array(p)
	for q in p:
		_c.append(col)
	for i in idx:
		_i.append(base + i)


## Linie als Vierecke mit verlängerten Enden (deckt die Knicke ab).
func _line(p: PackedVector2Array, w: float, col: Color) -> void:
	var hw := w * 0.5
	for i in p.size() - 1:
		var a := p[i]
		var b := p[i + 1]
		var d := b - a
		var l := d.length()
		if l < 0.01:
			continue
		d /= l
		var n := Vector2(-d.y, d.x) * hw
		a -= d * hw * 0.8
		b += d * hw * 0.8
		var base := _v.size()
		_v.append(a + n)
		_v.append(b + n)
		_v.append(b - n)
		_v.append(a - n)
		for k in 4:
			_c.append(col)
		_i.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


func _ngon(center: Vector2, r: float, col: Color, sides: int) -> void:
	var base := _v.size()
	_v.append(center)
	_c.append(col)
	for k in sides:
		var a := TAU * float(k) / float(sides)
		_v.append(center + Vector2(cos(a), sin(a)) * r)
		_c.append(col)
	for k in sides:
		_i.append(base)
		_i.append(base + 1 + k)
		_i.append(base + 1 + (k + 1) % sides)

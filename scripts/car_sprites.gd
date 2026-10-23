extends RefCounted
## Draufsicht-Bilder der 3D-Autos für die Streckenkarte: je Team einmal in einem unsichtbaren 3D-Fenster von oben
## gerendert (Teamlackierung wie im Showroom) und zwischengespeichert. Bis das Bild fertig ist – und ohne Grafik
## (Tests ohne Fenster) – liefert get_tex null, die Karte zeichnet dann die alte Form.

const MESH = preload("res://assets/car/car_mesh.res")
const ALBEDO = preload("res://assets/car/car_albedo.jpg")
const LIVERY = preload("res://assets/car/livery.gdshader")
const TeamStyle = preload("res://scripts/team_style.gd")

## Bildausschnitt in Autolängen (Auto liegt längs, Front nach +X): Rechteck um den Mittelpunkt
const RECT := Rect2(-0.5, -0.275, 1.0, 0.55)

static var _cache := {}      # Schlüssel -> ImageTexture oder null (kein Bild möglich)


class Shot extends SubViewport:
	var key := ""
	var n := 0

	func _process(_d: float) -> void:
		n += 1
		if n < 3:
			return
		var img: Image = get_texture().get_image() if get_texture() != null else null
		if img == null or img.is_empty() or img.get_used_rect().size.x < 8:
			load("res://scripts/car_sprites.gd")._cache[key] = null
		else:
			img.generate_mipmaps()
			load("res://scripts/car_sprites.gd")._cache[key] = ImageTexture.create_from_image(img)
		queue_free()


## Draufsicht für eine Lackierung; der Schlüssel ist die Team-ID (oder "sc" fürs Safety Car).
static func get_tex(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	_request(key)
	return null


static func _request(key: String) -> void:
	if DisplayServer.get_name() == "headless":
		_cache[key] = null
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	_cache[key] = null      # läuft; bis zum Ergebnis keine zweite Anfrage
	var vp := Shot.new()
	vp.key = key
	vp.size = Vector2i(256, 141)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.88, 0.95)
	e.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = e
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-70, -30, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var car := make_car(key)
	car.rotation_degrees.y = 180.0      # Modell-Nase zeigt nach -X, die Karte erwartet +X
	vp.add_child(car)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = 1.95
	cam.position = Vector3(0, 3.0, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	vp.add_child(cam)
	tree.root.add_child.call_deferred(vp)


## Auto-Mesh mit Teamlackierung (Showroom und Draufsicht). Für "sc" weiß mit Orange.
static func make_car(key: String) -> MeshInstance3D:
	var car := MeshInstance3D.new()
	car.mesh = MESH
	var m := ShaderMaterial.new()
	m.shader = LIVERY
	m.set_shader_parameter("albedo_tex", ALBEDO)
	if key == "sc":
		m.set_shader_parameter("primary", Color(0.95, 0.95, 0.97))
		m.set_shader_parameter("secondary", Color(1.0, 0.55, 0.05))
	elif key != "":
		m.set_shader_parameter("primary", DB.team_color(key))
		m.set_shader_parameter("secondary", TeamStyle.second_color(key))
	car.material_override = m
	return car

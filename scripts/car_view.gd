extends SubViewportContainer
## Drehbares 3D-Auto in Teamfarben (Showroom): eigenes kleines 3D-Fenster mit Licht und Schatten-Fleck, dreht sich
## langsam von selbst; mit Maus oder Finger ziehen dreht es von Hand, danach läuft es weiter. Ohne Effekte steht es still.

const U = preload("res://scripts/ui.gd")
const TeamStyle = preload("res://scripts/team_style.gd")

var team_id := ""
var yaw := -0.6
var pitch := 0.32
var dist := 4.4
var _spin := 0.35          # Grad pro Sekunde * 0.01 (Bogenmaß/s)
var _drag := false
var _idle := 0.0
var _pivot: Node3D
var _cam: Camera3D
var _mat: ShaderMaterial


static func make(id: String, min_size := Vector2(240, 120)) -> Control:
	var v = load("res://scripts/car_view.gd").new()
	v.team_id = id
	v.custom_minimum_size = min_size
	return v


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.78, 0.84, 0.95)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.97, 0.92)
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_energy = 0.55
	rim.light_color = Color(0.75, 0.85, 1.0)
	vp.add_child(rim)
	_pivot = Node3D.new()
	vp.add_child(_pivot)
	# weicher Schatten unter dem Auto
	var sh := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.3, 1.25)
	q.orientation = PlaneMesh.FACE_Y
	sh.mesh = q
	var sm := ShaderMaterial.new()
	var ss := Shader.new()
	ss.code = "shader_type spatial;\nrender_mode unshaded, blend_mix, depth_draw_never, cull_disabled;\nvoid fragment(){ vec2 d = (UV - 0.5) * 2.0; float a = 1.0 - smoothstep(0.35, 1.0, length(d)); ALBEDO = vec3(0.04, 0.06, 0.12); ALPHA = a * 0.45; }"
	sm.shader = ss
	sh.material_override = sm
	sh.position.y = -0.3
	_pivot.add_child(sh)
	var car: MeshInstance3D = load("res://scripts/car_sprites.gd").make_car("")
	_mat = car.material_override
	_pivot.add_child(car)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	vp.add_child(_cam)
	set_team(team_id)
	_place_cam()
	gui_input.connect(_on_input)
	resized.connect(_place_cam)


func set_team(id: String) -> void:
	team_id = id
	if _mat == null or id == "":
		return
	var p: Color = DB.team_color(id)
	_mat.set_shader_parameter("primary", p)
	_mat.set_shader_parameter("secondary", TeamStyle.second_color(id))


func _place_cam() -> void:
	# Auto liegt längs der X-Achse; Kamera kreist um den Mittelpunkt. Abstand so, dass das Auto das Fenster füllt:
	# in breiten Fenstern zählt die Höhe, in schmalen die Länge des Autos.
	var asp := clampf(size.x / size.y, 0.6, 6.0) if size.x > 1.0 and size.y > 1.0 else 2.0
	var t := tan(deg_to_rad(_cam.fov * 0.5))
	dist = maxf(0.62 / t, 1.15 / (t * asp))
	var d := Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)) * dist
	_cam.position = d
	_cam.look_at(Vector3(0, -0.04, 0), Vector3.UP)


func _process(delta: float) -> void:
	if _drag or not is_visible_in_tree():
		return
	_idle += delta
	if U.fx_on() and _idle > 1.2:
		yaw += _spin * delta
		_place_cam()


func _on_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_drag = ev.pressed
		_idle = 0.0
	elif ev is InputEventScreenTouch:
		_drag = ev.pressed
		_idle = 0.0
	elif (ev is InputEventMouseMotion and _drag) or ev is InputEventScreenDrag:
		yaw -= ev.relative.x * 0.012
		pitch = clampf(pitch + ev.relative.y * 0.006, 0.05, 1.2)
		_place_cam()
		accept_event()

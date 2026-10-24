class_name CharacterActor
extends CharacterBody3D
## A small, code-built person for the valley (session B, character pass).
##
## This is the placeholder actor that future Claude character GLBs will replace. It exists so the people in Halloway
## can stand on the ground, sit on the benches, walk a route, cast a real cape-skin shadow and use a skin material
## with subsurface scattering instead of plastic flat colour.
##
## Design rules:
## - The root origin is between the feet, on the ground. Never put the origin at the hips.
## - The capsule collider sits from the feet to the neck; the legs are visual only.
## - The skin material uses Godot's physical skin path (roughness, weak specular, subsurface scattering).
## - The skin tones and hair styles are a palette, not a race label: the cast is deliberately varied across Black,
##   South Asian, East Asian and white characters, with different hair and ordinary clothes.
## - Walk and idle are procedural on the placeholder. The rig spec in docs/CLAUDE-CHARACTER-BRIEF-2026-11-15.md maps
##   the same joints to a real skeleton for the delivered GLBs.
##
## Usage:
##   var person := CharacterActor.new()
##   add_child(person)
##   person.setup({"terrain": terrain, "skin": 1, "hair": "braids", "outfit": Color(...), "route": [Vector3(...)]})

const SKIN_TONES := [
	{"name": "deep brown", "color": Color(0.235, 0.135, 0.085), "warm": Color(0.38, 0.18, 0.10)},
	{"name": "rich brown", "color": Color(0.345, 0.195, 0.115), "warm": Color(0.50, 0.28, 0.15)},
	{"name": "warm brown", "color": Color(0.455, 0.275, 0.165), "warm": Color(0.62, 0.38, 0.22)},
	{"name": "golden tan", "color": Color(0.665, 0.455, 0.285), "warm": Color(0.82, 0.58, 0.38)},
	{"name": "light tan", "color": Color(0.775, 0.570, 0.410), "warm": Color(0.91, 0.70, 0.52)},
	{"name": "olive", "color": Color(0.665, 0.515, 0.390), "warm": Color(0.83, 0.65, 0.48)},
	{"name": "fair", "color": Color(0.875, 0.700, 0.565), "warm": Color(0.97, 0.82, 0.68)},
	{"name": "east asian light", "color": Color(0.825, 0.645, 0.490), "warm": Color(0.94, 0.76, 0.58)},
	{"name": "south asian medium", "color": Color(0.580, 0.375, 0.235), "warm": Color(0.73, 0.49, 0.30)},
]

const HAIR_TONES := [
	Color(0.035, 0.030, 0.028),  # black
	Color(0.090, 0.060, 0.045),  # dark brown
	Color(0.190, 0.120, 0.075),  # brown
	Color(0.330, 0.160, 0.075),  # auburn
	Color(0.430, 0.400, 0.350),  # grey
	Color(0.720, 0.710, 0.670),  # silver
]

const HAIR_STYLES := ["crop", "short", "braids", "bun", "ponytail", "long"]

var terrain: Terrain
var display_name := "Villager"
var height_scale := 1.0
var walk_speed := 1.1
var route: Array[Vector3] = []
var route_index := 0
var seated := false
var hiker := false
var backpack := false
var seat_height := 0.53
var skin_index := 4
var hair_style := "short"
var hair_index := 0
var outfit_color := Color(0.25, 0.34, 0.32)
var trouser_color := Color(0.16, 0.18, 0.18)
var scarf_color := Color(0.60, 0.22, 0.16)

var _built := false
var _phase := 0.0
var _idle := 0.0
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _hair_root: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _elbow_l: Node3D
var _elbow_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D
var _collider: CollisionShape3D
var _heat: Node3D

func setup(opts: Dictionary) -> void:
	if _built:
		return
	terrain = opts.get("terrain") as Terrain
	display_name = str(opts.get("name", display_name))
	height_scale = clampf(float(opts.get("height", 1.0)), 0.82, 1.12)
	walk_speed = clampf(float(opts.get("speed", 1.1)), 0.4, 2.2)
	skin_index = clampi(int(opts.get("skin", 4)), 0, SKIN_TONES.size() - 1)
	hair_index = clampi(int(opts.get("hair_color", 0)), 0, HAIR_TONES.size() - 1)
	hair_style = str(opts.get("hair", "short"))
	outfit_color = opts.get("outfit", outfit_color) as Color
	trouser_color = opts.get("trousers", trouser_color) as Color
	scarf_color = opts.get("scarf", scarf_color) as Color
	hiker = bool(opts.get("hiker", false))
	backpack = bool(opts.get("backpack", false))
	seat_height = clampf(float(opts.get("seat_height", 0.53)), 0.35, 0.70)
	if opts.has("route"):
		var r: Array = opts["route"]
		for p in r:
			route.append(Vector3(p))
	if opts.has("seated"):
		seated = bool(opts["seated"])
	_build_body()
	_build_collider()
	if bool(opts.get("thermal", false)):
		_heat = ThermalHeat.person(self, Vector3.ZERO)
		_heat.visible = false
	if opts.has("position"):
		global_position = Vector3(opts["position"])
	if opts.has("yaw"):
		rotation.y = float(opts["yaw"])
	if seated:
		_set_pose("sit")
	else:
		_set_pose("walk" if not route.is_empty() else "stand")
	set_physics_process(not seated and (not route.is_empty() or hiker))
	_settle_ground()
	_built = true

func _build_body() -> void:
	scale = Vector3.ONE * height_scale
	var skin_mat: StandardMaterial3D = skin_material(skin_index)
	var hair_mat := _cloth(HAIR_TONES[hair_index], 0.92)
	var cloth := _cloth(outfit_color, 0.84)
	var trouser := _cloth(trouser_color, 0.90)
	var shoe := _cloth(Color(0.075, 0.065, 0.055), 0.78)
	var scarf := _cloth(scarf_color, 0.88)

	_hips = Node3D.new()
	_hips.name = "Hips"
	add_child(_hips)
	_hips.position.y = 0.92

	# torso and coat
	_torso = Node3D.new()
	_torso.name = "Torso"
	_hips.add_child(_torso)
	_add_mesh(_torso, _capsule(0.205, 1.06), cloth, Vector3(0.0, 0.24, 0.0))
	# a jacket panel and a little collar so the silhouette is not a plain capsule
	_add_mesh(_torso, _box(Vector3(0.36, 0.34, 0.20)), cloth, Vector3(0.0, 0.30, 0.11))
	_add_mesh(_torso, _box(Vector3(0.34, 0.08, 0.24)), scarf, Vector3(0.0, 0.49, 0.02))
	if hiker:
		_add_mesh(_torso, _box(Vector3(0.42, 0.42, 0.16)), scarf, Vector3(0.0, 0.27, 0.19), Vector3.ZERO)
	# neck and head
	_add_mesh(_hips, _cylinder(0.075, 0.14), skin_mat, Vector3(0.0, 0.56, 0.0))
	_head = Node3D.new()
	_head.name = "Head"
	_hips.add_child(_head)
	_head.position.y = 0.66
	_add_mesh(_head, _sphere(0.108), skin_mat, Vector3.ZERO)
	# ears
	for sx in [-1.0, 1.0]:
		_add_mesh(_head, _sphere(0.030), skin_mat, Vector3(sx * 0.105, 0.0, 0.0))
	# eyes, facing -Z
	for sx in [-1.0, 1.0]:
		_add_mesh(_head, _sphere(0.018), _cloth(Color(0.90, 0.88, 0.82), 0.45), Vector3(sx * 0.038, 0.025, -0.092))
		_add_mesh(_head, _sphere(0.009), _cloth(Color(0.020, 0.018, 0.015), 0.35), Vector3(sx * 0.038, 0.025, -0.108))
	# nose and mouth
	_add_mesh(_head, _box(Vector3(0.022, 0.052, 0.030)), skin_mat, Vector3(0.0, -0.008, -0.103))
	_add_mesh(_head, _box(Vector3(0.052, 0.010, 0.012)), _cloth(Color(0.30, 0.12, 0.10), 0.6), Vector3(0.0, -0.064, -0.099))
	_build_hair(hair_mat)
	if backpack:
		_build_backpack(cloth, scarf)

	# arms: shoulder -> elbow -> hand
	_arm_l = Node3D.new()
	_arm_l.name = "UpperArmL"
	_hips.add_child(_arm_l)
	_arm_l.position = Vector3(-0.272, 0.46, 0.0)
	_add_mesh(_arm_l, _capsule(0.052, 0.30), cloth, Vector3(0.0, -0.14, 0.0))
	_elbow_l = Node3D.new()
	_elbow_l.position.y = -0.28
	_arm_l.add_child(_elbow_l)
	_add_mesh(_elbow_l, _capsule(0.043, 0.26), skin_mat, Vector3(0.0, -0.12, 0.0))
	_add_mesh(_elbow_l, _sphere(0.052), skin_mat, Vector3(0.0, -0.27, 0.0))
	_arm_r = Node3D.new()
	_arm_r.name = "UpperArmR"
	_hips.add_child(_arm_r)
	_arm_r.position = Vector3(0.272, 0.46, 0.0)
	_add_mesh(_arm_r, _capsule(0.052, 0.30), cloth, Vector3(0.0, -0.14, 0.0))
	_elbow_r = Node3D.new()
	_elbow_r.position.y = -0.28
	_arm_r.add_child(_elbow_r)
	_add_mesh(_elbow_r, _capsule(0.043, 0.26), skin_mat, Vector3(0.0, -0.12, 0.0))
	_add_mesh(_elbow_r, _sphere(0.052), skin_mat, Vector3(0.0, -0.27, 0.0))

	# legs: hip -> knee -> foot
	_leg_l = Node3D.new()
	_leg_l.name = "UpperLegL"
	_hips.add_child(_leg_l)
	_leg_l.position = Vector3(-0.105, 0.0, 0.0)
	_add_mesh(_leg_l, _capsule(0.072, 0.44), trouser, Vector3(0.0, -0.22, 0.0))
	_knee_l = Node3D.new()
	_knee_l.position.y = -0.44
	_leg_l.add_child(_knee_l)
	_add_mesh(_knee_l, _capsule(0.060, 0.42), trouser, Vector3(0.0, -0.21, 0.0))
	_add_mesh(_knee_l, _box(Vector3(0.12, 0.08, 0.24)), shoe, Vector3(0.0, -0.44, -0.055))
	_leg_r = Node3D.new()
	_leg_r.name = "UpperLegR"
	_hips.add_child(_leg_r)
	_leg_r.position = Vector3(0.105, 0.0, 0.0)
	_add_mesh(_leg_r, _capsule(0.072, 0.44), trouser, Vector3(0.0, -0.22, 0.0))
	_knee_r = Node3D.new()
	_knee_r.position.y = -0.44
	_leg_r.add_child(_knee_r)
	_add_mesh(_knee_r, _capsule(0.060, 0.42), trouser, Vector3(0.0, -0.21, 0.0))
	_add_mesh(_knee_r, _box(Vector3(0.12, 0.08, 0.24)), shoe, Vector3(0.0, -0.44, -0.055))

func _build_hair(mat: StandardMaterial3D) -> void:
	_hair_root = Node3D.new()
	_hair_root.name = "Hair"
	_head.add_child(_hair_root)
	var cap := _sphere(0.112)
	_add_mesh(_hair_root, cap, mat, Vector3(0.0, 0.030, 0.018), Vector3.ZERO, Vector3(1.03, 0.86, 1.04))
	if hair_style == "bun":
		_add_mesh(_hair_root, _sphere(0.070), mat, Vector3(0.0, 0.085, 0.100))
	elif hair_style == "ponytail":
		_add_mesh(_hair_root, _capsule(0.045, 0.25), mat, Vector3(0.0, -0.035, 0.135), Vector3(0.25, 0.0, 0.0))
	elif hair_style == "braids":
		for sx in [-1.0, 1.0]:
			_add_mesh(_hair_root, _capsule(0.028, 0.30), mat, Vector3(sx * 0.105, -0.10, 0.045), Vector3(0.08, 0.0, 0.0))
	elif hair_style == "long":
		_add_mesh(_hair_root, _box(Vector3(0.20, 0.30, 0.11)), mat, Vector3(0.0, -0.13, 0.055))

func _build_backpack(cloth: StandardMaterial3D, strap: StandardMaterial3D) -> void:
	var pack := _box(Vector3(0.34, 0.42, 0.18))
	_add_mesh(_hips, pack, cloth, Vector3(0.0, 0.24, 0.20))
	for sx in [-1.0, 1.0]:
		_add_mesh(_hips, _box(Vector3(0.045, 0.36, 0.03)), strap, Vector3(sx * 0.15, 0.28, 0.10))

func _build_collider() -> void:
	_collider = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.58
	_collider.shape = capsule
	_collider.position.y = 0.79
	add_child(_collider)
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35
	up_direction = Vector3.UP

func _physics_process(delta: float) -> void:
	if not _built:
		return
	if route.is_empty() or seated:
		velocity.x = 0.0
		velocity.z = 0.0
		_idle += delta
		_animate(delta, 0.0)
		_settle_ground()
		return
	var target: Vector3 = route[route_index]
	var flat := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if flat.length() < 0.32:
		route_index = (route_index + 1) % route.size()
		target = route[route_index]
		flat = Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if flat.length() > 0.001:
		var dir := flat.normalized()
		velocity.x = dir.x * walk_speed
		velocity.z = dir.z * walk_speed
		var want_yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, want_yaw, clampf(delta * 7.0, 0.0, 1.0))
		_phase += delta * walk_speed * 5.6
	move_and_slide()
	_settle_ground()
	_animate(delta, 1.0)

func _settle_ground() -> void:
	if terrain == null:
		return
	var g := terrain.height(global_position.x, global_position.z)
	global_position.y = g

func _animate(delta: float, moving: float) -> void:
	if seated:
		_hips.position.y = seat_height + 0.02
		_leg_l.rotation.x = 1.45
		_leg_r.rotation.x = 1.45
		_knee_l.rotation.x = -1.42
		_knee_r.rotation.x = -1.42
		_arm_l.rotation.x = 0.20
		_arm_r.rotation.x = 0.20
		_elbow_l.rotation.x = -0.30
		_elbow_r.rotation.x = -0.30
		return
	_hips.position.y = 0.92
	var stride := sin(_phase) * 0.55 * moving
	_leg_l.rotation.x = stride
	_leg_r.rotation.x = -stride
	_knee_l.rotation.x = -maxf(0.0, -stride) * 0.55
	_knee_r.rotation.x = -maxf(0.0, stride) * 0.55
	_arm_l.rotation.x = -stride * 0.70
	_arm_r.rotation.x = stride * 0.70
	_elbow_l.rotation.x = -0.08 - absf(stride) * 0.25
	_elbow_r.rotation.x = -0.08 - absf(stride) * 0.25
	_torso.rotation.z = sin(_phase * 0.5) * 0.025 * moving
	_torso.rotation.x = 0.02 + absf(sin(_phase)) * 0.018 * moving
	if moving <= 0.01:
		var breathe := sin(_idle * 1.7) * 0.018
		_torso.rotation.x = 0.02 + breathe
		_arm_l.rotation.x = 0.08 + breathe
		_arm_r.rotation.x = 0.08 + breathe

func _set_pose(pose: String) -> void:
	seated = pose == "sit"
	if seated:
		_collider.disabled = true
		set_physics_process(false)
		set_process(false)
		_animate(0.0, 0.0)
	else:
		_collider.disabled = false
		set_physics_process(not route.is_empty())
		set_process(true)

func set_thermal_marker(on: bool) -> void:
	if _heat != null:
		_heat.visible = on and not seated

func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

static var _skin_noise: NoiseTexture2D

static func _skin_texture() -> Texture2D:
	if _skin_noise == null:
		var n := FastNoiseLite.new()
		n.frequency = 0.11
		n.fractal_octaves = 2
		n.fractal_gain = 0.45
		var tex := NoiseTexture2D.new()
		tex.width = 64
		tex.height = 64
		tex.seamless = true
		tex.noise = n
		var g := Gradient.new()
		g.add_point(0.0, Color(0.72, 0.72, 0.72))
		g.add_point(0.55, Color(0.90, 0.90, 0.90))
		g.add_point(1.0, Color(1.0, 1.0, 1.0))
		tex.color_ramp = g
		_skin_noise = tex
	return _skin_noise

static func skin_material(index: int) -> StandardMaterial3D:
	var i := clampi(index, 0, SKIN_TONES.size() - 1)
	var tone: Dictionary = SKIN_TONES[i]
	var m := StandardMaterial3D.new()
	m.albedo_color = tone["color"]
	m.albedo_texture = _skin_texture()
	m.roughness = 0.50
	m.roughness_texture = _skin_texture()
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	m.metallic = 0.0
	m.metallic_specular = 0.38
	m.uv1_scale = Vector3(2.0, 2.0, 2.0)
	m.rim_enabled = false
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		# Real subsurface path in Forward+. The deeper tones need slightly less scatter than the fair tones.
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_skin_mode = true
		m.subsurf_scatter_strength = 0.16 + 0.015 * float(i)
	else:
		# Mobile and compatibility renderers do not support SSS. Backlight keeps the skin from reading as clay.
		m.subsurf_scatter_enabled = false
		m.backlight_enabled = true
		m.backlight_color = Color(0.55, 0.18, 0.12)
	return m

func _cloth(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = 0.0
	return m

func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	return m

func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	return m

func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

func _cylinder(radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	return m

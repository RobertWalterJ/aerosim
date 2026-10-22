class_name DroneView
extends Node3D
## The visible drone, built from simple parts to match the airframe: body, arms, motors, spinning props and a camera.
## Body frame: +x right, +y up, forward is -z.

var _props: Array[Node3D] = []
var _discs: Array[MeshInstance3D] = []
var _gimbal: Node3D
var _af: Dictionary
var _omega_max := 1.0
var _fpv := false
var _phase := PackedFloat64Array([0.0, 1.1, 2.3, 3.7])
var _last_t := 0.0

func build(af: Dictionary) -> void:
	for c in get_children(): c.queue_free()
	_props.clear(); _discs.clear()
	_af = af
	_omega_max = af["omegaMax"]
	var is_mini: bool = af["id"] == "mini"
	var d: float = af["armD"]
	var r: float = af["R"]
	var scale_k: float = d / 0.0795          # body parts scale with the arm length
	var carbon := _mat(Color(0.10, 0.11, 0.12), 0.45, 0.15)
	var shell := _mat(Color(0.72, 0.74, 0.76) if is_mini else Color(0.13, 0.14, 0.16), 0.38, 0.1)
	var metal := _mat(Color(0.5, 0.52, 0.55), 0.3, 0.95)
	var accent := _mat(Color(0.9, 0.25, 0.1), 0.5, 0.0)
	var body := _box(Vector3(0.075, 0.032, 0.115) * scale_k, shell, Vector3.ZERO)
	add_child(body)
	add_child(_box(Vector3(0.06, 0.016, 0.09) * scale_k, carbon, Vector3(0, 0.022 * scale_k, 0)))
	if not is_mini:
		add_child(_box(Vector3(0.036, 0.03, 0.105) * scale_k, _mat(Color(0.17, 0.25, 0.42), 0.6, 0.0), Vector3(0, 0.034 * scale_k, 0.0)))
	var ducted: bool = af["id"] == "cinewhoop"
	var positions: Array[Vector3] = [Vector3(d, 0, -d), Vector3(d, 0, d), Vector3(-d, 0, d), Vector3(-d, 0, -d)]
	for i in 4:
		var p := positions[i]
		var arm_len := Vector2(p.x, p.z).length()
		var arm := _box(Vector3(arm_len, 0.008, 0.016), carbon, p * 0.5)
		arm.rotation.y = -atan2(p.z, p.x)
		add_child(arm)
		var motor := MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.top_radius = 0.014 * scale_k; cm.bottom_radius = 0.015 * scale_k; cm.height = 0.022
		motor.mesh = cm; motor.material_override = metal; motor.position = p + Vector3(0, 0.012, 0)
		add_child(motor)
		var prop := Node3D.new(); prop.position = p + Vector3(0, 0.03, 0)
		var blades: int = af["nBlades"]
		for b in blades:
			var bl := _box(Vector3(r * 2.0, 0.0012, 0.011 * scale_k), carbon if i % 2 == 0 else accent, Vector3.ZERO)
			bl.rotation.y = b * PI / blades
			prop.add_child(bl)
		add_child(prop); _props.append(prop)
		var disc := MeshInstance3D.new()
		var dm := CylinderMesh.new(); dm.top_radius = r; dm.bottom_radius = r; dm.height = 0.001; dm.radial_segments = 32
		var dmat := ShaderMaterial.new()
		dmat.shader = load("res://game/shaders/prop_blur.gdshader")
		dmat.set_shader_parameter("radius", r); dmat.set_shader_parameter("n_blades", float(blades))
		dmat.set_shader_parameter("chord", 0.012 * scale_k)
		disc.mesh = dm; disc.material_override = dmat; disc.position = p + Vector3(0, 0.031, 0); disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(disc); _discs.append(disc)
		if ducted:
			var duct := MeshInstance3D.new()
			var tm := TorusMesh.new(); tm.inner_radius = r * 1.02; tm.outer_radius = r * 1.18
			duct.mesh = tm; duct.material_override = carbon; duct.position = p + Vector3(0, 0.02, 0)
			add_child(duct)
	# camera pod
	_gimbal = Node3D.new()
	var co: Vector3 = af["camOffset"]
	_gimbal.position = co + Vector3(0, 0.005, 0)
	var ball := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.02 * scale_k; sm.height = 0.04 * scale_k
	ball.mesh = sm; ball.material_override = carbon; _gimbal.add_child(ball)
	var lens := MeshInstance3D.new(); var lm := CylinderMesh.new(); lm.top_radius = 0.009 * scale_k; lm.bottom_radius = 0.009 * scale_k; lm.height = 0.012
	lens.mesh = lm; lens.rotation.x = PI / 2.0; lens.position = Vector3(0, 0, -0.02 * scale_k)
	lens.material_override = _mat(Color(0.02, 0.04, 0.09), 0.1, 0.9)
	_gimbal.add_child(lens)
	add_child(_gimbal)
	if not af["hasGimbal"]:
		_gimbal.rotation.x = af["camTilt"]

## Through the drone's own camera: the camera pod would fill the picture, so it is hidden, and fast props show as a blur.
func set_fpv(on: bool) -> void:
	_fpv = on
	if _gimbal: _gimbal.visible = not on

func update_props(motor_omega: PackedFloat64Array, t: float, armed: bool) -> void:
	var dt := clampf(t - _last_t, 0.0, 0.1)
	_last_t = t
	for i in _props.size():
		var w := motor_omega[13 + i]
		var spin := 1.0 if i % 2 == 1 else -1.0
		var blur: bool = armed and w > 45.0       # above about 7 turns a second the blades are only ever seen smeared
		_props[i].visible = not blur
		_discs[i].visible = blur
		if not blur:
			if armed: _props[i].rotation.y = fmod(t * w * 0.05 * spin, TAU)
			continue
		_phase[i] = fmod(_phase[i] + spin * w * dt, TAU)
		var m := _discs[i].material_override as ShaderMaterial
		m.set_shader_parameter("phase", _phase[i])
		m.set_shader_parameter("omega", spin * w)

func _mat(c: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c; m.roughness = rough; m.metallic = metal
	return m

func _box(size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm; mi.material_override = mat; mi.position = pos
	return mi

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
	var id: String = af["id"]
	var camera_drone: bool = af["hasGimbal"]
	var d: float = af["armD"]
	var r: float = af["R"]
	var k: float = d / 0.0795          # body parts scale with the arm length
	var blades: int = af["nBlades"]
	var shell_col := Color(0.88, 0.89, 0.91) if id == "mini" else (Color(0.93, 0.93, 0.94) if id == "cinema" else Color(0.10, 0.11, 0.13))
	var carbon := _mat(Color(0.065, 0.07, 0.08), 0.42, 0.25)
	var shell := _mat(shell_col, 0.30, 0.05)
	var dark := _mat(shell_col.darkened(0.18), 0.34, 0.05)
	var metal := _mat(Color(0.52, 0.54, 0.58), 0.26, 0.95)
	var accent_col: Color = {"freestyle": Color(1.0, 0.45, 0.1), "race": Color(0.25, 0.95, 0.5), "cinewhoop": Color(0.25, 0.65, 1.0), "mini": Color(0.96, 0.96, 0.98), "cinema": Color(0.95, 0.25, 0.18)}.get(id, Color(1.0, 0.5, 0.1))
	var accent := _mat(accent_col, 0.5, 0.0)
	var positions: Array[Vector3] = [Vector3(d, 0, -d), Vector3(d, 0, d), Vector3(-d, 0, d), Vector3(-d, 0, -d)]
	# ---- body
	if camera_drone:
		# a smooth fuselage with a battery hump and rubber feet, like a folding camera drone
		add_child(_ellipsoid(Vector3(0.078, 0.044, 0.128) * k, shell, Vector3.ZERO))
		add_child(_ellipsoid(Vector3(0.056, 0.032, 0.096) * k, dark, Vector3(0, 0.02 * k, 0.014 * k)))
		for p in positions:
			var foot := MeshInstance3D.new(); var cm := CapsuleMesh.new(); cm.radius = 0.0055 * k; cm.height = 0.032 * k
			foot.mesh = cm; foot.material_override = carbon; foot.position = Vector3(p.x * 0.5, -0.032 * k, p.z * 0.5)
			add_child(foot)
	else:
		# a carbon frame: two plates on standoffs, a strapped battery, a canopy, an antenna
		add_child(_box(Vector3(0.05, 0.004, 0.1) * k, carbon, Vector3(0, -0.01 * k, 0.005 * k)))
		add_child(_box(Vector3(0.046, 0.004, 0.092) * k, carbon, Vector3(0, 0.022 * k, 0.005 * k)))
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				add_child(_cyl(0.003 * k, 0.003 * k, 0.032 * k, metal, Vector3(sx * 0.017 * k, 0.006 * k, 0.012 * k + sz * 0.034 * k)))
		add_child(_ellipsoid(Vector3(0.036, 0.03, 0.092) * k, _mat(Color(0.14, 0.18, 0.3), 0.55, 0.0), Vector3(0, 0.04 * k, 0.012 * k)))
		add_child(_box(Vector3(0.039, 0.004, 0.012) * k, accent, Vector3(0, 0.04 * k, 0.03 * k)))
		add_child(_ellipsoid(Vector3(0.032, 0.02, 0.05) * k, shell, Vector3(0, 0.0, -0.02 * k)))
		var ant := _cyl(0.0012 * k, 0.0012 * k, 0.05 * k, carbon, Vector3(0, 0.03 * k, 0.07 * k)); ant.rotation_degrees = Vector3(60, 0, 0)
		add_child(ant)
	# ---- arms, motors, propellers
	var blade_even := DroneParts.blade(r, 0.011 * k, maxf(0.17 * r, 0.008), Color(0.06, 0.065, 0.07), accent_col)
	var blade_odd := DroneParts.blade(r, 0.011 * k, maxf(0.17 * r, 0.008), Color(0.06, 0.065, 0.07), Color(0.95, 0.95, 0.97))
	var blade_mat := StandardMaterial3D.new()
	blade_mat.vertex_color_use_as_albedo = true; blade_mat.roughness = 0.42; blade_mat.metallic = 0.1
	blade_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ducted: bool = id == "cinewhoop"
	for i in 4:
		var p := positions[i]
		var arm_len := Vector2(p.x, p.z).length()
		var arm_mesh: ArrayMesh
		if camera_drone:
			arm_mesh = DroneParts.arm(arm_len, 0.022 * k, 0.015 * k, 0.012 * k, 0.009 * k)
		else:
			arm_mesh = DroneParts.arm(arm_len, 0.026 * k, 0.014 * k, 0.007 * k, 0.007 * k)
		var arm := MeshInstance3D.new(); arm.mesh = arm_mesh
		arm.material_override = shell if camera_drone else carbon
		arm.rotation.y = -atan2(p.z, p.x)
		arm.position = Vector3(0, -0.002 * k if camera_drone else -0.004 * k, 0)
		add_child(arm)
		# the motor: a bell with a darker cap
		add_child(_cyl(0.0145 * k, 0.0155 * k, 0.02 * k, metal, p + Vector3(0, 0.008 * k, 0)))
		add_child(_cyl(0.011 * k, 0.0125 * k, 0.006 * k, carbon, p + Vector3(0, 0.021 * k, 0)))
		# navigation lights: green front right, red front left, white behind
		var led := MeshInstance3D.new(); var lsm := SphereMesh.new(); lsm.radius = 0.006 * k; lsm.height = 0.012 * k
		var lc := Color(0.2, 1.0, 0.3) if i == 0 else (Color(1.0, 0.15, 0.1) if i == 3 else Color(1.0, 1.0, 1.0))
		var lm := StandardMaterial3D.new(); lm.albedo_color = lc; lm.emission_enabled = true; lm.emission = lc; lm.emission_energy_multiplier = 3.0
		led.mesh = lsm; led.material_override = lm; led.position = p + Vector3(0, -0.004, 0) + Vector3(sign(p.x), 0, sign(p.z)) * 0.012 * k
		led.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(led)
		# the propeller: a hub spinner and shaped blades, turned as one
		var prop := Node3D.new(); prop.position = p + Vector3(0, 0.03 * k, 0)
		prop.add_child(_cyl(0.0015 * k, 0.0085 * k, 0.012 * k, accent, Vector3(0, 0.004, 0)))
		for b in blades:
			var bm := MeshInstance3D.new(); bm.mesh = blade_even if i % 2 == 0 else blade_odd
			bm.material_override = blade_mat
			bm.rotation.y = TAU * b / blades
			prop.add_child(bm)
		add_child(prop); _props.append(prop)
		var disc := MeshInstance3D.new()
		var dm := CylinderMesh.new(); dm.top_radius = r; dm.bottom_radius = r; dm.height = 0.001; dm.radial_segments = 32
		var dmat := ShaderMaterial.new()
		dmat.shader = load("res://game/shaders/prop_blur.gdshader")
		dmat.set_shader_parameter("radius", r); dmat.set_shader_parameter("n_blades", float(blades))
		dmat.set_shader_parameter("chord", 0.012 * k)
		disc.mesh = dm; disc.material_override = dmat; disc.position = p + Vector3(0, 0.031 * k, 0); disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(disc); _discs.append(disc)
		if ducted:
			var duct := MeshInstance3D.new()
			var tm := TorusMesh.new(); tm.inner_radius = r * 1.03; tm.outer_radius = r * 1.2
			duct.mesh = tm; duct.material_override = carbon; duct.position = p + Vector3(0, 0.02 * k, 0)
			add_child(duct)
			for sa in 3:
				var strut := _box(Vector3(r * 1.1, 0.004, 0.006) * 1.0, carbon, p + Vector3(0, 0.02 * k, 0))
				strut.rotation.y = sa * PI / 3.0 + 0.4
				add_child(strut)
	# ---- camera: a gimbal ball on the camera drones, a small FPV camera block on the quads
	_gimbal = Node3D.new()
	var co: Vector3 = af["camOffset"]
	_gimbal.position = co + Vector3(0, 0.005, 0)
	if camera_drone:
		_gimbal.add_child(_ellipsoid(Vector3(0.04, 0.04, 0.04) * k, carbon, Vector3.ZERO))
		var lens := _cyl(0.0095 * k, 0.0095 * k, 0.014 * k, _mat(Color(0.02, 0.04, 0.09), 0.08, 0.9), Vector3(0, 0, -0.02 * k))
		lens.rotation.x = PI / 2.0
		_gimbal.add_child(lens)
	else:
		_gimbal.add_child(_box(Vector3(0.022, 0.022, 0.018) * k, carbon, Vector3.ZERO))
		var lens2 := _cyl(0.007 * k, 0.007 * k, 0.01 * k, _mat(Color(0.02, 0.04, 0.09), 0.08, 0.9), Vector3(0, 0, -0.012 * k))
		lens2.rotation.x = PI / 2.0
		_gimbal.add_child(lens2)
	add_child(_gimbal)
	if not af["hasGimbal"]:
		_gimbal.rotation.x = af["camTilt"]
	set_fpv(_fpv)

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

## A smooth rounded solid: a sphere stretched to the given full size.
func _ellipsoid(size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.5; sm.height = 1.0; sm.radial_segments = 24; sm.rings = 12
	mi.mesh = sm; mi.scale = size; mi.material_override = mat; mi.position = pos
	return mi

func _cyl(top: float, bottom: float, height: float, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = top; cm.bottom_radius = bottom; cm.height = height; cm.radial_segments = 20
	mi.mesh = cm; mi.material_override = mat; mi.position = pos
	return mi

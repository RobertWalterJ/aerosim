extends Node3D
## AeroSim in Godot. Builds the world in code, runs the ported flight physics at a fixed 2 ms step (four steps per
## 8 ms physics tick), and draws it with Godot's renderer. Controls: left stick throttle and yaw, right stick pitch and roll.
## Keyboard: W/S throttle, A/D yaw, arrows pitch and roll, Q/E gimbal, R reset, C camera, M mode, Esc pause.

const SUBSTEPS := 4
const DT := 0.002
const TREE_CELL := 24.0

var terrain: Terrain
var quad: Quad
var fc: FlightController
var wind := Wind.new()
var drone_node := Node3D.new()
var drone_view := DroneView.new()
var cam := Camera3D.new()
var sun := DirectionalLight3D.new()
var env := Environment.new()
var sky_mat := ProceduralSkyMaterial.new()
var snow_fx: GPUParticles3D
var snow_mat: ParticleProcessMaterial
var hud: Hud
var sticks: TouchSticks
var af: Dictionary
var airframe_id := "mini"
var chase := false
var paused := false
var sim_time := 0.0
var gimbal_pitch := deg_to_rad(-20.0)
var _trees := {}          # cell -> Array of Vector3(x, z, radius) with trunk height in y of a parallel dict
var _tree_h := {}
var _cam_yaw := 0.0
var _chase_pos := Vector3.ZERO
var _snow_level := 0
var _fps_acc := 0.0
var _fps := 60.0
var _wind_now := Vector3.ZERO

func _ready() -> void:
	Engine.physics_ticks_per_second = 125
	Engine.max_physics_steps_per_frame = 8
	var q_arg := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("drone="): airframe_id = a.substr(6)
		if a.begins_with("shot="): q_arg = a.substr(5)
		if a == "selftest": _selftest = true
	_build_world()
	af = Airframes.make(airframe_id)
	quad = Quad.new(af)
	fc = FlightController.new(af, quad)
	fc.set_step(DT)
	quad.ground_h = func(x: float, z: float) -> float: return terrain.height(x, z)
	quad.ground_n = func(x: float, z: float) -> Vector3: return terrain.normal_at(x, z)
	quad.obstacle_hit = _tree_hit
	add_child(drone_node)
	drone_node.add_child(drone_view)
	drone_view.build(af)
	add_child(cam)
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cam.near = 0.03; cam.far = 3000.0; cam.fov = 84.0; cam.current = true
	hud = Hud.new()
	add_child(hud)
	hud.pause_changed.connect(func(p: bool): paused = p; if sticks: sticks.release_all())
	hud.reset_requested.connect(spawn)
	hud.drone_picked.connect(switch_drone)
	hud.mode_changed.connect(func(m: String): fc.mode = m; fc.reset_state())
	hud.camera_changed.connect(func(c: bool): chase = c)
	hud.weather_changed.connect(apply_weather)
	hud.gimbal_changed.connect(func(r: float): gimbal_pitch = r)
	hud.set_airframe(airframe_id)
	sticks = TouchSticks.new()
	hud.add_child(sticks)
	hud.show_gimbal(af["hasGimbal"])
	apply_weather(hud.weather)
	spawn()
	if q_arg != "": _screenshot_mode(q_arg)
	if _selftest: _run_selftest()

# ------------------------------------------------------------------ world
func _build_world() -> void:
	terrain = Terrain.new()
	add_child(terrain)
	terrain.build()
	_scatter_trees()
	# sun, sky and atmosphere
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 350.0
	sun.light_energy = 2.2
	sun.shadow_blur = 1.2
	add_child(sun)
	sky_mat.sky_curve = 0.18
	sky_mat.ground_curve = 0.05
	var sky := Sky.new(); sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.70, 0.80)
	env.fog_density = 0.0007
	env.fog_aerial_perspective = 0.6
	env.fog_sky_affect = 0.4
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		env.ssao_enabled = true
		env.ssao_radius = 1.5
		env.ssil_enabled = false
		env.sdfgi_enabled = false
	var we := WorldEnvironment.new(); we.environment = env
	add_child(we)
	# snow
	snow_fx = GPUParticles3D.new()
	snow_fx.amount = 6000
	snow_fx.lifetime = 9.0
	snow_fx.visibility_aabb = AABB(Vector3(-30, -20, -30), Vector3(60, 40, 60))
	snow_fx.local_coords = false
	snow_fx.emitting = false
	snow_fx.draw_pass_1 = _snow_mesh()
	snow_mat = ParticleProcessMaterial.new()
	snow_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	snow_mat.emission_box_extents = Vector3(30, 1, 30)
	snow_mat.gravity = Vector3(0, -1.2, 0)
	snow_mat.initial_velocity_min = 0.0; snow_mat.initial_velocity_max = 0.3
	snow_mat.turbulence_enabled = true
	snow_mat.turbulence_noise_strength = 0.4
	snow_mat.scale_min = 0.6; snow_mat.scale_max = 1.4
	snow_fx.process_material = snow_mat
	add_child(snow_fx)

func _snow_mesh() -> Mesh:
	var qm := QuadMesh.new()
	qm.size = Vector2(0.035, 0.035)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.95, 0.97, 1.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.material = m
	return qm

func _scatter_trees() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var forest := FastNoiseLite.new(); forest.seed = 31; forest.frequency = 0.004
	var xf: Array[Transform3D] = []; var cols: Array[Color] = []; var heights: Array[float] = []
	var step := 11.0
	var span := 700.0
	var x := -span
	while x < span:
		var z := -span
		while z < span:
			var px := x + rng.randf() * step; var pz := z + rng.randf() * step
			z += step
			var d := sqrt(px * px + pz * pz)
			if d < 34.0: continue
			var dens := forest.get_noise_2d(px, pz) * 0.5 + 0.5
			if rng.randf() > smoothstep(0.35, 0.7, dens) * 0.9: continue
			var n := terrain.normal_at(px, pz)
			if n.y < 0.86: continue
			var y := terrain.height(px, pz)
			if y > 105.0: continue
			var s := 0.7 + rng.randf() * 0.8
			xf.append(Transform3D(Basis().scaled(Vector3(s, s, s)).rotated(Vector3.UP, rng.randf() * TAU), Vector3(px, y - 0.1, pz)))
			cols.append(Color(0.10, 0.22, 0.10).lerp(Color(0.18, 0.30, 0.12), rng.randf()).srgb_to_linear())
			heights.append(21.0 * s)
			var key := Vector2i(floori(px / TREE_CELL), floori(pz / TREE_CELL))
			if not _trees.has(key): _trees[key] = []; _tree_h[key] = []
			_trees[key].append(Vector3(px, y, pz)); _tree_h[key].append([0.32 * s, 21.0 * s])
		x += step
	# one multimesh per part: trunk, lower cone, upper cone
	var parts := [[0.30, 0.34, 4.0, 2.0, Color(0.25, 0.16, 0.10)], [0.0, 3.6, 9.0, 8.0, Color.WHITE], [0.0, 2.6, 8.0, 14.0, Color.WHITE]]
	for p in parts:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var cm := CylinderMesh.new()
		cm.top_radius = p[0]; cm.bottom_radius = p[1]; cm.height = p[2]; cm.radial_segments = 8
		mm.mesh = cm
		mm.instance_count = xf.size()
		for i in xf.size():
			var t := xf[i]
			t.origin.y += p[3] * t.basis.get_scale().y
			mm.set_instance_transform(i, t)
			mm.set_instance_color(i, p[4] if p[4] != Color.WHITE else cols[i])
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.9
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm; mi.material_override = mat
		add_child(mi)

## Trunk collision for the drone: returns the push-out vector, or Vector3.INF when clear.
func _tree_hit(x: float, y: float, z: float, r: float) -> Vector3:
	var key := Vector2i(floori(x / TREE_CELL), floori(z / TREE_CELL))
	for a in range(-1, 2):
		for b in range(-1, 2):
			var k := Vector2i(key.x + a, key.y + b)
			if not _trees.has(k): continue
			var list: Array = _trees[k]
			var hs: Array = _tree_h[k]
			for i in list.size():
				var t: Vector3 = list[i]
				if y < t.y - r or y > t.y + hs[i][1] + r: continue
				var dx := x - t.x
				var dz := z - t.z
				var dd := sqrt(dx * dx + dz * dz)
				var rr: float = hs[i][0] + r
				if dd < rr:
					var sc := (rr - dd) / maxf(dd, 1e-4)
					return Vector3(dx * sc, 0, dz * sc)
	return Vector3.INF

# ------------------------------------------------------------------ weather
func apply_weather(w: Dictionary) -> void:
	wind.speed = float(w["wind"]); wind.gust = float(w["gust"]); wind.from_deg = float(w["from"])
	var el := deg_to_rad(float(w["sun"]))
	var az := deg_to_rad(238.0)
	var to_sun := Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
	sun.global_transform = Transform3D(Basis.looking_at(-to_sun), Vector3.ZERO)
	var warm := 1.0 - smoothstep(4.0, 30.0, float(w["sun"]))
	sun.light_color = Color(1.0, 0.72, 0.5).lerp(Color(1.0, 0.96, 0.9), 1.0 - warm)
	sun.light_energy = 1.6 + 1.0 * smoothstep(4.0, 24.0, float(w["sun"]))
	sky_mat.sky_top_color = Color(0.20, 0.38, 0.68).lerp(Color(0.12, 0.20, 0.40), warm * 0.5)
	sky_mat.sky_horizon_color = Color(0.66, 0.74, 0.84).lerp(Color(0.95, 0.62, 0.42), warm)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color(0.2, 0.24, 0.2)
	var snow := int(w["snow"])
	_snow_level = snow
	terrain.snow = [0.0, 0.55, 1.0][snow]
	env.fog_density = 0.0007 * (1.0 + 2.0 * snow)
	env.fog_light_color = Color(0.62, 0.70, 0.80).lerp(Color(0.78, 0.80, 0.84), 0.5 * minf(snow, 1.0))
	snow_fx.emitting = snow > 0
	snow_fx.amount_ratio = 0.4 if snow == 1 else 1.0
	snow_mat.gravity = Vector3(0, -1.2 if snow < 2 else -2.2, 0)

# ------------------------------------------------------------------ flight
func spawn() -> void:
	var y := terrain.height(0.0, 0.0) + 0.04
	quad.reset(0.0, y, 0.0, deg_to_rad(150.0))
	fc.reset_state(); fc.mode = hud.mode if hud else "N"; fc.heading = deg_to_rad(150.0)
	_cam_yaw = deg_to_rad(150.0)
	_apply_pose()
	drone_node.reset_physics_interpolation()
	if hud: hud.show_crash("")

func switch_drone(id: String) -> void:
	airframe_id = id
	af = Airframes.make(id)
	quad.set_airframe(af)
	fc.set_airframe(af)
	drone_view.build(af)
	hud.set_airframe(id)
	hud.show_gimbal(af["hasGimbal"])
	spawn()

func _read_sticks() -> Vector4:
	# x = throttle, y = yaw, z = pitch, w = roll, each -1..1
	var th := 0.0; var yw := 0.0; var pt := 0.0; var rl := 0.0
	if _auto_climb: th = 1.0
	if Input.is_key_pressed(KEY_W): th += 1.0
	if Input.is_key_pressed(KEY_S): th -= 1.0
	if Input.is_key_pressed(KEY_D): yw += 1.0
	if Input.is_key_pressed(KEY_A): yw -= 1.0
	if Input.is_key_pressed(KEY_UP): pt += 1.0
	if Input.is_key_pressed(KEY_DOWN): pt -= 1.0
	if Input.is_key_pressed(KEY_RIGHT): rl += 1.0
	if Input.is_key_pressed(KEY_LEFT): rl -= 1.0
	# gamepad
	var pads := Input.get_connected_joypads()
	if pads.size() > 0:
		var j: int = pads[0]
		var dz := 0.08
		var f := func(v: float) -> float: return 0.0 if absf(v) < dz else v
		th += f.call(-Input.get_joy_axis(j, JOY_AXIS_LEFT_Y)); yw += f.call(Input.get_joy_axis(j, JOY_AXIS_LEFT_X))
		pt += f.call(-Input.get_joy_axis(j, JOY_AXIS_RIGHT_Y)); rl += f.call(Input.get_joy_axis(j, JOY_AXIS_RIGHT_X))
	if sticks:
		th += sticks.left.y; yw += sticks.left.x; pt += sticks.right.y; rl += sticks.right.x
	return Vector4(clampf(th, -1, 1), clampf(yw, -1, 1), clampf(pt, -1, 1), clampf(rl, -1, 1))

func _physics_process(_delta: float) -> void:
	if paused: return
	var st := _read_sticks()
	var p := quad.position()
	var agl := p.y - terrain.height(p.x, p.z)
	quad.wind = wind.sample(p, maxf(agl, 0.05), sim_time)
	_wind_now = quad.wind
	fc.on_ground = agl < 0.15
	for i in SUBSTEPS:
		fc.update(DT, st.x, st.y, st.z, st.w)
		quad.step(DT)
		sim_time += DT
	_apply_pose()

func _apply_pose() -> void:
	drone_node.global_transform = Transform3D(Basis(quad.attitude()), quad.position())

func _process(delta: float) -> void:
	if quad == null: return
	_fps_acc += delta
	if _fps_acc > 0.5:
		_fps = 1.0 / maxf(delta, 1e-4) * 0.5 + _fps * 0.5
		_fps_acc = 0.0
	var t := drone_node.get_global_transform_interpolated()
	var q := t.basis.get_rotation_quaternion()
	var pos := t.origin
	if chase:
		var fwd := q * Vector3(0, 0, -1)
		var heading := atan2(-fwd.x, -fwd.z)
		_cam_yaw = lerp_angle(_cam_yaw, heading, clampf(delta * 3.0, 0.0, 1.0))
		var back := Vector3(sin(_cam_yaw), 0.0, cos(_cam_yaw))
		var d := 2.2 + 12.0 * float(af["armD"])
		var want := pos + back * d + Vector3(0, 0.9 + 4.0 * float(af["armD"]), 0)
		_chase_pos = want if _chase_pos == Vector3.ZERO else _chase_pos.lerp(want, clampf(delta * 6.0, 0.0, 1.0))
		cam.global_transform = Transform3D(Basis.looking_at((pos - _chase_pos).normalized(), Vector3.UP), _chase_pos)
		cam.fov = 70.0
	else:
		_chase_pos = Vector3.ZERO
		var co: Vector3 = af["camOffset"]
		cam.global_position = pos + q * (co + Vector3(0, 0.015, -0.01))
		if af["hasGimbal"]:
			# stabilised gimbal: follows the drone's heading, holds its own tilt
			var fwd2 := q * Vector3(0, 0, -1)
			var heading2 := atan2(-fwd2.x, -fwd2.z)
			cam.global_transform.basis = Basis(Vector3.UP, heading2) * Basis(Vector3.RIGHT, gimbal_pitch)
		else:
			cam.global_transform.basis = Basis(q) * Basis(Vector3.RIGHT, float(af["camTilt"]))
		cam.fov = 84.0
	drone_view.visible = chase
	drone_view.update_props(quad.s, sim_time, quad.armed)
	# snow follows the camera
	snow_fx.global_position = cam.global_position + Vector3(0, 12, 0)
	var wdir := wind.toward() * wind.speed * 0.8
	snow_mat.direction = Vector3(wdir.x, -1.0, wdir.z).normalized() if _snow_level > 0 else Vector3.DOWN
	# readout
	var ppos := quad.position()
	var agl := ppos.y - terrain.height(ppos.x, ppos.z)
	var gs := sqrt(quad.s[3] * quad.s[3] + quad.s[5] * quad.s[5])
	hud.set_readout("%s   %s\nALT %.0f m   SPD %.1f m/s   CLIMB %+.1f\nBATT %d%%  %.1f V   WIND %.1f m/s\n%d fps" % [
		af["name"], {"N": "NORMAL", "S": "SPORT", "M": "MANUAL"}[fc.mode], agl, gs, quad.s[4], int(quad.battery.soc * 100.0), quad.battery.v_term, _wind_now.length(), int(_fps)])
	hud.show_crash(quad.crash_reason if (quad.crashed or not quad.armed) else "")

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	match event.keycode:
		KEY_R: spawn()
		KEY_C: hud.set_chase(not chase)
		KEY_M: hud.cycle_mode()
		KEY_Q: gimbal_pitch = clampf(gimbal_pitch + 0.1, deg_to_rad(-90.0), deg_to_rad(20.0)); hud.set_gimbal_value(gimbal_pitch)
		KEY_E: gimbal_pitch = clampf(gimbal_pitch - 0.1, deg_to_rad(-90.0), deg_to_rad(20.0)); hud.set_gimbal_value(gimbal_pitch)

# ------------------------------------------------------------------ screenshot helper for development
func _screenshot_mode(arg: String) -> void:
	var parts := arg.split(",")
	var path := parts[0]
	var frames := int(parts[1]) if parts.size() > 1 else 90
	if parts.size() > 2: chase = parts[2] == "chase"; hud.set_chase(chase)
	if parts.size() > 3 and parts[3] == "climb":
		_auto_climb = true
	await get_tree().create_timer(0.1).timeout
	for i in frames: await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved ", path)
	get_tree().quit()

var _auto_climb := false

var _selftest := false

## Headless check: climb for a few seconds, then report. Run with: --headless --path godot -- selftest
func _run_selftest() -> void:
	_auto_climb = true
	var t0 := Time.get_ticks_msec()
	for i in 400:
		await get_tree().physics_frame
	var p := quad.position()
	print("selftest: alt %.1f m over ground, crashed=%s, sim_time=%.2f s, wall=%d ms" % [p.y - terrain.height(p.x, p.z), quad.crashed, sim_time, Time.get_ticks_msec() - t0])
	print("selftest: wind %.2f m/s, battery %.0f%%" % [_wind_now.length(), quad.battery.soc * 100.0])
	get_tree().quit()

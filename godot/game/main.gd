extends Node3D
## AeroSim in Godot. Builds the world in code, runs the ported flight physics at a fixed 2 ms step (four steps per
## 8 ms physics tick), and draws it with Godot's renderer. Controls: left stick throttle and yaw, right stick pitch and roll.
## Keyboard: W/S throttle, A/D yaw, arrows pitch and roll, Q/E gimbal, R reset, C camera, M mode, Esc pause.

const SUBSTEPS := 4
const DT := 0.002

var terrain: Terrain
var forest: Forest
var cemetery: Cemetery
var meadow: Meadow
var grass: Grass
var quad: Quad
var fc: FlightController
var wind := Wind.new()
var drone_node := Node3D.new()
var drone_view := DroneView.new()
var cam := Camera3D.new()
var sun := DirectionalLight3D.new()
var env := Environment.new()
var sky_mat := ShaderMaterial.new()
var wx := WeatherSystem.new()
var rain_fx: GPUParticles3D
var rain_mat: ParticleProcessMaterial
var _base_wind := 1.0
var _base_gust := 0.45
var _sun_el := 14.0
var _last_wet_applied := -1.0
var snow_fx: GPUParticles3D
var snow_mat: ParticleProcessMaterial
var hud: Hud
var osd: Osd
var sensor: SensorPipeline
var _prev_cam_q := Quaternion.IDENTITY
var _sun_dir := Vector3(0, 1, 0)
var _sun_vis := 1.0
var sticks: TouchSticks
var af: Dictionary
var airframe_id := "mini"
var chase := false
var paused := false
var sim_time := 0.0
var gimbal_pitch := deg_to_rad(-20.0)
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
	Grass.add_globals()
	_build_world()
	af = Airframes.make(airframe_id)
	quad = Quad.new(af)
	fc = FlightController.new(af, quad)
	fc.set_step(DT)
	quad.ground_h = func(x: float, z: float) -> float: return terrain.height(x, z)
	quad.ground_n = func(x: float, z: float) -> Vector3: return terrain.normal_at(x, z)
	quad.obstacle_hit = forest.trunk_hit
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
	hud.lens_changed.connect(func(l: String): sensor.set_lens(l))
	# the camera renders into the sensor pipeline's overscan viewport; the window itself only shows the video frame and the HUD
	sensor = SensorPipeline.new()
	add_child(sensor)
	var touch_device := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	sensor.setup(cam, 540 if touch_device else 720, Viewport.MSAA_DISABLED if touch_device else Viewport.MSAA_2X)
	var video := CanvasLayer.new(); video.layer = 1; add_child(video); video.add_child(sensor.screen)
	get_viewport().disable_3d = true
	osd = Osd.new(); osd.name = "Osd"; hud.add_child(osd)
	apply_weather(hud.weather)
	spawn()
	if q_arg != "": _screenshot_mode(q_arg)
	if _selftest: _run_selftest()

# ------------------------------------------------------------------ world
func _build_world() -> void:
	terrain = Terrain.new()
	add_child(terrain)
	terrain.add_flat_rect(Cemetery.CENTRE, Cemetery.HALF + Vector2(3, 3), 14.0)
	terrain.lawn_rects = [{"c": Cemetery.CENTRE, "half": Cemetery.HALF + Vector2(6, 6)}]
	terrain.build()
	cemetery = Cemetery.new()
	add_child(cemetery)
	cemetery.build(terrain)
	forest = Forest.new()
	add_child(forest)
	forest.plant(terrain, func(x: float, z: float) -> bool: return cemetery.contains(x, z, 6.0) or (x * x + z * z) < 900.0)
	var touch_dev := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	var dev_args := OS.get_cmdline_user_args()
	meadow = Meadow.new()
	add_child(meadow)
	if not "nomeadow" in dev_args: meadow.plant(terrain, func(x: float, z: float) -> bool: return cemetery.contains(x, z, 3.0) or (x * x + z * z) < 196.0, 0.12 if touch_dev else 0.3)
	grass = Grass.new()
	add_child(grass)
	var cr := Rect2(Cemetery.CENTRE - Cemetery.HALF - Vector2(1, 1), (Cemetery.HALF + Vector2(1, 1)) * 2.0)
	if not "nograss" in dev_args: grass.build(terrain, "low" if touch_dev else "high", cr)
	# sun, sky and atmosphere
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 350.0
	sun.light_energy = 2.2
	sun.shadow_blur = 1.2
	add_child(sun)
	sky_mat.shader = load("res://game/shaders/sky.gdshader")   # weather-driven sky: clear-sky colour, sun, clouds
	var sky := Sky.new(); sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.7
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_color = Color(0.78, 0.82, 0.62)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR   # the sensor pipeline does exposure, bloom and the tone curve
	env.glow_enabled = false
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.70, 0.80)
	# exponential height fog: thicker in the valley, with forward scattering towards the sun
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.0004
	env.fog_height = 55.0
	env.fog_height_density = 0.0009
	env.fog_sun_scatter = 0.35
	env.fog_aerial_perspective = 0.55
	env.fog_sky_affect = 0.3
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		env.ssao_enabled = true
		env.ssao_radius = 1.5
		env.ssao_intensity = 1.6
		env.ssil_enabled = true            # screen-space bounce light
		env.ssr_enabled = true             # reflections in puddles, wet stone and glossy leaves
		env.ssr_max_steps = 64
		env.ssr_fade_in = 0.15
		env.ssr_fade_out = 2.0
		env.ssr_depth_tolerance = 0.25
		env.sdfgi_enabled = false
	sun.light_angular_distance = 0.5     # soft shadow edges, wider further from the caster
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
	# rain: thin streaks that fall fast and lean with the wind
	rain_fx = GPUParticles3D.new()
	rain_fx.amount = 14000
	rain_fx.lifetime = 1.4
	rain_fx.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 60, 80))
	rain_fx.local_coords = false
	rain_fx.emitting = false
	var rq := QuadMesh.new()
	rq.size = Vector2(0.008, 0.42)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	rm.billboard_keep_scale = true
	rm.albedo_color = Color(0.82, 0.88, 0.95, 0.2)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rq.material = rm
	rain_fx.draw_pass_1 = rq
	rain_mat = ParticleProcessMaterial.new()
	rain_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_mat.emission_box_extents = Vector3(34, 1, 34)
	rain_mat.particle_flag_align_y = true
	rain_mat.gravity = Vector3(0, -22, 0)
	rain_mat.initial_velocity_min = 4.0; rain_mat.initial_velocity_max = 6.0
	rain_mat.direction = Vector3.DOWN
	rain_fx.process_material = rain_mat
	add_child(rain_fx)

func _snow_mesh() -> Mesh:
	var qm := QuadMesh.new()
	qm.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.95, 0.97, 1.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.material = m
	return qm

# ------------------------------------------------------------------ weather
func apply_weather(w: Dictionary) -> void:
	_base_wind = float(w["wind"]); _base_gust = float(w["gust"])
	wind.from_deg = float(w["from"])
	var first := _sun_el < 0.0
	_sun_el = float(w["sun"])
	var el := deg_to_rad(_sun_el)
	var az := deg_to_rad(238.0)
	var to_sun := Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
	_sun_dir = to_sun
	if sensor: sensor.set_sun_direction(to_sun)
	sun.global_transform = Transform3D(Basis.looking_at(-to_sun), Vector3.ZERO)
	sun.light_color = Color.WHITE
	sun.light_temperature = 3300.0 + 1200.0 * smoothstep(5.0, 22.0, _sun_el)
	wx.set_condition(int(w["sky"]), float(w["intensity"]))
	_apply_weather_state(0.0, true)

## Push the weather's current values into the sky, light, fog, particles and surface wetness. Called every frame
## with the time step (the weather eases between conditions) and once with snap = true to jump straight to the target.
func _apply_weather_state(delta: float, snap := false) -> void:
	wx.update(delta, snap)
	var c := wx.cur
	var sun_base := 1.7 * (0.55 + 0.45 * smoothstep(3.0, 18.0, _sun_el))
	var storm_flash := wx.flash
	sun.light_energy = sun_base * float(c["sun"]) + storm_flash * 4.0
	sun.shadow_opacity = clampf(0.25 + 3.0 * float(c["sun"]), 0.0, 1.0)
	env.ambient_light_energy = 1.7 * float(c["amb"]) + storm_flash * 1.2
	sky_mat.set_shader_parameter("sun_dir", _sun_dir)
	sky_mat.set_shader_parameter("cover", float(c["cover"]))
	sky_mat.set_shader_parameter("dark", float(c["dark"]))
	sky_mat.set_shader_parameter("cirrus", float(c["cirrus"]))
	sky_mat.set_shader_parameter("haze", float(c["haze"]))
	sky_mat.set_shader_parameter("fog", float(c["fog"]))
	sky_mat.set_shader_parameter("flash", storm_flash)
	var wd := wind.toward()
	sky_mat.set_shader_parameter("drift", Vector2(wd.x, wd.z) * (0.5 + 0.6 * wind.speed))
	# fog: thicker and greyer in rain, snow and mist
	var grey := clampf(float(c["haze"]) * 0.9 + float(c["fog"]) * 0.4, 0.0, 1.0)
	env.fog_density = 0.0004 * float(c["fogd"])
	env.fog_light_color = Color(0.62, 0.70, 0.80).lerp(Color(0.66, 0.68, 0.72), grey)
	env.fog_sky_affect = 0.3 + 0.5 * float(c["fog"])
	env.fog_height_density = 0.0009 * float(c["fogd"])
	# wind follows the condition
	wind.speed = _base_wind * float(c["wind"])
	wind.gust = clampf(_base_gust + (0.35 if wx.kind == WeatherSystem.Kind.STORM else 0.0), 0.0, 1.0)
	# precipitation
	var rain := float(c["rain"])
	var snow_p := float(c["snow"])
	rain_fx.emitting = rain > 0.03
	rain_fx.amount_ratio = clampf(rain, 0.05, 1.0)
	var lean := wind.toward() * wind.speed * 0.9
	rain_mat.gravity = Vector3(lean.x, -22.0, lean.z)
	snow_fx.emitting = snow_p > 0.03
	snow_fx.amount_ratio = clampf(snow_p, 0.05, 1.0)
	snow_mat.gravity = Vector3(0, -1.2 - 1.2 * snow_p, 0)
	terrain.snow = wx.snow_cover
	RenderingServer.global_shader_parameter_set("g_wet", wx.wet)
	if absf(wx.wet - _last_wet_applied) > 0.015:
		_last_wet_applied = wx.wet
		Assets.set_wetness(wx.wet)

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
	if _gallery_cam:
		return
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
		var d := 3.5 + 16.0 * float(af["armD"])
		var want := pos + back * d + Vector3(0, 0.5 + 4.0 * float(af["armD"]), 0)
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
	# precipitation follows the camera
	snow_fx.global_position = cam.global_position + Vector3(0, 12, 0)
	rain_fx.global_position = cam.global_position + Vector3(0, 16, 0)
	var wdir := wind.toward() * wind.speed * 0.8
	snow_mat.direction = Vector3(wdir.x, -1.0, wdir.z).normalized()
	_apply_weather_state(delta)
	_update_sensor_and_osd(delta)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	match event.keycode:
		KEY_MINUS: sensor.ev_comp = clampf(sensor.ev_comp - 0.33, -3.0, 3.0)
		KEY_EQUAL: sensor.ev_comp = clampf(sensor.ev_comp + 0.33, -3.0, 3.0)
		KEY_L: hud.toggle_lens()
		KEY_H: osd.show_osd = not osd.show_osd
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
	for c in parts.slice(3):
		if c == "climb":
			_auto_climb = true
		if c.begins_with("at"):
			var v := c.substr(2).split("_")   # at<x>_<y_above_ground>_<z>_<yaw_deg>_<gimbal_deg>
			var px := float(v[0]); var pz := float(v[2])
			var py := terrain.height(px, pz) + float(v[1])
			quad.reset(px, py, pz, deg_to_rad(float(v[3])))
			var wh: float = float(af["omegaMax"]) * sqrt(1.0 / float(af["twr"]))
			for i in 4:
				quad.s[13 + i] = wh; quad.cmd[i] = wh
			fc.heading = deg_to_rad(float(v[3])); gimbal_pitch = deg_to_rad(float(v[4]))
			_apply_pose(); drone_node.reset_physics_interpolation()
		if c == "gallery":
			_build_gallery()
		if c.begins_with("menu"):
			hud.set_paused(true); hud._tabs.current_tab = int(c.substr(4))
		if c.begins_with("sky"):
			hud.weather["sky"] = int(c.substr(3)); hud.weather["intensity"] = 0.8; apply_weather(hud.weather); _auto_climb = true
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

var _gallery_cam := false

## Development view: every tree variant and a row of cemetery pieces, close up, to judge the models.
func _build_gallery() -> void:
	_gallery_cam = true
	drone_view.visible = false
	var gy := terrain.height(0.0, 0.0)
	var names := ["spruce_a_l0", "maple_red_l0", "maple_gold_l0", "oak_l0", "spruce_b_l0"]
	for i in names.size():
		var xf := Transform3D(Basis(), Vector3(-24.0 + i * 12.0, gy, -26.0))
		Assets.place(self, "trees/" + names[i], xf)
	var env := ["headstone_0", "headstone_2", "headstone_4", "headstone_6", "crossMonument_0", "angelMonument_0", "urnMonument_1", "kerbedPlot_0", "willowMarker_0", "ironFence_0", "bouquet_0", "deadTree_0"]
	for i in env.size():
		var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(10.0)), Vector3(-15.0 + i * 2.8, gy, -9.0))
		Assets.place(self, "env/" + env[i], xf)
	cam.global_transform = Transform3D(Basis.looking_at(Vector3(0.0, -0.05, -1.0), Vector3.UP), Vector3(0.0, gy + 2.2, 4.0))
	cam.fov = 60.0

# ------------------------------------------------------------------ sensor pipeline and on-screen display
var _rf_dbm := -50.0

## Line of sight from `from` to `to`: false if the terrain is in the way (a few samples are enough at these ranges).
func _terrain_clear(from: Vector3, to: Vector3, steps := 12) -> bool:
	for i in range(1, steps):
		var p := from.lerp(to, float(i) / steps)
		if terrain.height(p.x, p.z) > p.y: return false
	return true

func _update_sensor_and_osd(delta: float) -> void:
	# shared by the grass, foliage and ground shaders: camera, clock, canopy wind and the drone's rotor wash
	var dp := quad.position()
	var agl0 := dp.y - terrain.height(dp.x, dp.z)
	RenderingServer.global_shader_parameter_set("g_cam", cam.global_position)
	RenderingServer.global_shader_parameter_set("g_time", sim_time)
	RenderingServer.global_shader_parameter_set("g_wind", wind.sample(Vector3(dp.x, terrain.height(dp.x, dp.z) + 14.0, dp.z), 14.0, sim_time))
	RenderingServer.global_shader_parameter_set("g_drone", Vector4(dp.x, dp.y, dp.z, 3.5))
	RenderingServer.global_shader_parameter_set("g_wash", clampf(fc.thrust_fraction() * 1.8, 0.0, 1.0) * 0.55 * (1.0 - smoothstep(2.5, 8.0, agl0)) * (1.0 if quad.armed else 0.0))
	var cpos := cam.global_position
	var cq := cam.global_transform.basis.get_rotation_quaternion()
	# camera angular velocity in its own frame (x pitch up, y yaw left, z roll)
	var dq := _prev_cam_q.inverse() * cq
	var ang := Vector3.ZERO
	if delta > 0.0: ang = dq.get_euler() / delta
	_prev_cam_q = cq
	ang = ang.clamp(Vector3(-8, -8, -8), Vector3(8, 8, 8))
	# sun visibility for the flare: blocked by terrain or a tree crown along the ray to the sun
	var sun_target := 1.0
	if not _terrain_clear(cpos, cpos + _sun_dir * 1500.0, 24): sun_target = 0.0
	elif forest.canopy_blocks(cpos, _sun_dir, 90.0): sun_target = 0.0
	sun_target *= smoothstep(0.12, 0.5, float(wx.cur["sun"]))
	_sun_vis += (sun_target - _sun_vis) * clampf(delta * 8.0, 0.0, 1.0)
	sensor.sun_vis = _sun_vis
	# video link: free-space loss with distance, plus a penalty when the terrain blocks the line of sight
	var dpos := quad.position()
	var home_p := Vector3(0.0, terrain.height(0.0, 0.0) + 1.6, 0.0)
	var dist := dpos.distance_to(home_p)
	var dbm := -45.0 - 20.0 * log(maxf(dist, 10.0) / 10.0) / log(10.0)
	if not _terrain_clear(home_p, dpos): dbm -= 28.0
	_rf_dbm += (dbm - _rf_dbm) * clampf(delta * 3.0, 0.0, 1.0)
	var bars := 5 if _rf_dbm > -60.0 else (4 if _rf_dbm > -70.0 else (3 if _rf_dbm > -78.0 else (2 if _rf_dbm > -86.0 else 1)))
	var rf_bad := smoothstep(-80.0, -97.0, _rf_dbm)
	var mean_om := (quad.s[13] + quad.s[14] + quad.s[15] + quad.s[16]) * 0.25
	var vib := clampf(0.12 + quad.vrs * 0.8 + fc.thrust_fraction() * 0.25 + quad.ang_accel.length() / 600.0, 0.0, 1.0)
	sensor.process_frame(delta, sim_time, ang, vib, mean_om / TAU * float(af["nBlades"]), rf_bad)
	osd.frame = sensor.frame_rect()
	hud.layout_for(osd.frame)
	# telemetry for the display
	var cb := cam.global_transform.basis
	var fwd := -cb.z
	var vcam := cb.inverse() * quad.velocity()
	var agl := dpos.y - terrain.height(dpos.x, dpos.z)
	var dfwd := quad.attitude() * Vector3(0, 0, -1)
	osd.t = {
		"mode": fc.mode, "sats": 14 + (3 if agl > 2.0 else 0), "rfDbm": _rf_dbm, "rfBars": bars,
		"battPct": quad.battery.soc * 100.0, "cellV": quad.battery.cell_v(), "battA": quad.battery.current,
		"iso": sensor.iso_shown, "shutter": sensor.shutter_shown, "ev": sensor.ev_comp,
		"pitch": asin(clampf(fwd.y, -1.0, 1.0)), "roll": -asin(clampf(cb.x.y, -1.0, 1.0)),
		"heading": atan2(dfwd.x, -dfwd.z), "velBody": vcam, "aglM": agl, "mslM": dpos.y,
		"gs": sqrt(quad.s[3] * quad.s[3] + quad.s[5] * quad.s[5]), "vs": quad.s[4],
		"homeDist": sqrt(dpos.x * dpos.x + dpos.z * dpos.z),
		"gimbalDeg": rad_to_deg(gimbal_pitch) if af["hasGimbal"] else rad_to_deg(float(af["camTilt"])),
		"histogram": sensor.histogram, "lensName": sensor.lens_info()["name"], "airframe": af["name"],
		"audio": "off", "fps": int(_fps), "crashed": quad.crash_reason if (quad.crashed or not quad.armed) else "",
		"armed": quad.armed, "touch": DisplayServer.is_touchscreen_available(), "mission": [],
		"windMs": _wind_now.length(), "windLevel": "", "homeBearing": atan2(-dpos.x, dpos.z), "stopHit": 0.0, "aero": "",
	}
	hud.show_crash(osd.t["crashed"])

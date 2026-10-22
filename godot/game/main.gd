extends Node3D
## AeroSim in Godot. Builds the world in code, runs the ported flight physics at a fixed 2 ms step (four steps per
## 8 ms physics tick), and draws it with Godot's renderer. Controls: left stick throttle and yaw, right stick pitch and roll.
## Keyboard: W/S throttle, A/D yaw, arrows pitch and roll, Q/E gimbal, R reset, C camera, M mode, Esc pause.

const SUBSTEPS := 4
const DT := 0.002

var terrain: Terrain
var world: World
var home := Vector2(-18.0, 36.0)
var grass: Grass
var quad: Quad
var fc: FlightController
var wind := Wind.new()
var drone_node := Node3D.new()
var drone_view := DroneView.new()
var cam := Camera3D.new()
var sun := DirectionalLight3D.new()
var moon := DirectionalLight3D.new()
var drone_light := SpotLight3D.new()
var env := Environment.new()
var sky_mat := ShaderMaterial.new()
var wx := WeatherSystem.new()
var rain_fx: GPUParticles3D
var rain_mat: ParticleProcessMaterial
var _base_wind := 1.0
var _base_gust := 0.45
var _sun_el := 14.0
var _sun_az := 238.0
# time of day: the sun and moon follow the real clock, or a time the player sets, which can run on or stand still
const DATES := [[3, 21], [6, 21], [9, 22], [12, 21]]
var _clock := 16.0               # local hour, 0..24
var _doy := 295
var _unix := 0.0
var _utc_off := -4.0
var _clock_mode := 0             # 0 real clock, 1 set time
var _clock_speed := 0            # 0 real time, 1 fast, 2 frozen
var _date_pick := 0
var _hour_setting := -1.0
var _celestial_t := 0.0
var _hour_write_t := 0.0
var _moon_el := -20.0
var _moon_dir := Vector3(0, -1, 0)
var _moon_illum := 0.5
var _daylight := 1.0
var _last_wet_applied := -1.0
var snow_fx: GPUParticles3D
var snow_mat: ParticleProcessMaterial
var hud: Hud
var osd: Osd
var sensor: SensorPipeline
var autopilot := AutoPilot.new()
var audio: DroneAudio
var _canopy_wind := Vector3.ZERO
var _wash_now := 0.0
var recording := false
var _rec_time := 0.0
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

var _loaded := false
var _gimbal_rate := 0.0
var _load_layer: CanvasLayer
var _load_label: Label
var _load_bar: ProgressBar

## A plain loading page, so a phone that takes a while to build the valley shows what it is doing and how far along it is.
func _loading_show() -> void:
	_load_layer = CanvasLayer.new(); _load_layer.layer = 100
	var bg := ColorRect.new(); bg.color = Color(0.05, 0.06, 0.08); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_layer.add_child(bg)
	var box := VBoxContainer.new(); box.set_anchors_preset(Control.PRESET_CENTER); box.grow_horizontal = Control.GROW_DIRECTION_BOTH; box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size = Vector2(520, 0); box.add_theme_constant_override("separation", 14)
	var title := Label.new(); title.text = "AeroSim"; title.add_theme_font_size_override("font_size", 44); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_load_label = Label.new(); _load_label.add_theme_font_size_override("font_size", 22); _load_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_load_bar = ProgressBar.new(); _load_bar.show_percentage = false; _load_bar.custom_minimum_size = Vector2(520, 14); _load_bar.max_value = 1.0
	box.add_child(title); box.add_child(_load_label); box.add_child(_load_bar)
	_load_layer.add_child(box)
	add_child(_load_layer)

func _stage(text: String, frac: float) -> void:
	if _load_label == null: return
	_load_label.text = text; _load_bar.value = frac
	await get_tree().process_frame

func _ready() -> void:
	_loading_show()
	await _stage("Starting up", 0.02)
	Engine.physics_ticks_per_second = 125
	Engine.max_physics_steps_per_frame = 8
	var q_arg := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("drone="): airframe_id = a.substr(6)
		if a.begins_with("shot="): q_arg = a.substr(5)
		if a == "selftest": _selftest = true
		if a == "apstest": _apstest = true
	Grass.add_globals()
	await _build_world()
	af = Airframes.make(airframe_id)
	quad = Quad.new(af)
	fc = FlightController.new(af, quad)
	fc.set_step(DT)
	quad.ground_h = func(x: float, z: float) -> float: return terrain.height(x, z)
	quad.ground_n = func(x: float, z: float) -> Vector3: return terrain.normal_at(x, z)
	quad.obstacle_hit = world.obstacle_hit
	add_child(drone_node)
	drone_node.add_child(drone_view)
	# a spotlight on the airframe, pointing forward and a little down, for flying at night
	drone_light.position = Vector3(0, -0.02, -0.1)
	drone_light.rotation_degrees = Vector3(-22, 0, 0)
	drone_light.spot_range = 70.0; drone_light.spot_angle = 34.0; drone_light.spot_attenuation = 0.5
	drone_light.light_energy = 14.0; drone_light.light_color = Color(1.0, 0.96, 0.88)
	drone_light.shadow_enabled = true
	drone_light.visible = false
	drone_node.add_child(drone_light)
	drone_view.build(af)
	add_child(cam)
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cam.near = 0.03; cam.far = 3000.0; cam.fov = 84.0; cam.current = true
	hud = Hud.new()
	add_child(hud)
	hud.pause_changed.connect(func(p: bool): paused = p; if sticks: sticks.release_all(); sticks.enabled = not p; osd.visible = not p)
	hud.reset_requested.connect(spawn)
	hud.drone_picked.connect(switch_drone)
	hud.mode_changed.connect(func(m: String): fc.mode = m; fc.reset_state())
	hud.camera_changed.connect(func(c: bool): chase = c)
	hud.weather_changed.connect(apply_weather)
	hud.light_changed.connect(func(on: bool): drone_light.visible = on)
	hud.grass_changed.connect(func(on: bool): grass.visible = on)
	hud.gimbal_changed.connect(func(r: float): gimbal_pitch = r)
	hud.set_airframe(airframe_id)
	sticks = TouchSticks.new()
	hud.add_child(sticks)
	sticks.blocked = hud.interactive_controls()
	hud.show_gimbal(af["hasGimbal"])
	hud.lens_changed.connect(func(l: String): sensor.set_lens(l))
	hud.ev_changed.connect(func(v: float): sensor.ev_comp = v)
	hud.bloom_changed.connect(func(on: bool): sensor.bloom_on = on)
	hud.noise_changed.connect(func(v: float): sensor.noise_scale = v)
	hud.link_changed.connect(func(on: bool): sensor.link_effects = on)
	hud.osd_changed.connect(func(on: bool): osd.show_osd = on)
	hud.photo_requested.connect(_shutter_pressed)
	hud.sound_changed.connect(func(on: bool): audio.set_enabled(on))
	hud.listening_changed.connect(func(i: int): audio.set_perspective(i))
	hud.volume_changed.connect(func(v: float): audio.set_volume(v))
	hud.takeoff_land_requested.connect(_takeoff_or_land)
	hud.rth_requested.connect(_toggle_rth)
	# the camera renders into the sensor pipeline's overscan viewport; the window itself only shows the video frame and the HUD
	await _stage("Setting up the camera", 0.82)
	sensor = SensorPipeline.new()
	add_child(sensor)
	var touch_device := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	sensor.setup(cam, 540 if touch_device else 720, Viewport.MSAA_DISABLED if touch_device else Viewport.MSAA_2X)
	var video := CanvasLayer.new(); video.layer = 1; add_child(video); video.add_child(sensor.screen)
	get_viewport().disable_3d = not "keep3d" in OS.get_cmdline_user_args()
	osd = Osd.new(); osd.name = "Osd"; hud.add_child(osd)
	# sound: motors, wind, rotor wash, birds in the trees near the start
	await _stage("Tuning the sound", 0.9)
	audio = DroneAudio.new()
	add_child(audio)
	var tl: Array = []
	for tr in world.layout["trees"]:
		tl.append([tr[0], tr[1], tr[2], (21.0 if int(tr[5]) < 2 else 13.0) * float(tr[4])])
	if touch_device: hud.listening = 1
	audio.perspective = hud.listening
	audio.setup(drone_node, Vector3(home.x, terrain.height(home.x, home.y) + 1.7, home.y), tl, float(af["armD"]), home)
	await _stage("Almost ready", 0.97)
	hud.minimap.bake(terrain)
	hud.minimap.home = home
	var pl: Array[PackedVector2Array] = []
	for p in terrain.layout["paths"]:
		var pts := PackedVector2Array()
		for q in p["pts"]: pts.append(Vector2(q[0], q[1]))
		pl.append(pts)
	hud.minimap.paths = pl
	apply_weather(hud.weather)
	spawn()
	_loaded = true
	if _load_layer: _load_layer.queue_free()
	if q_arg != "": _screenshot_mode(q_arg)
	if _selftest: _run_selftest()
	if _apstest: _run_apstest()

# ------------------------------------------------------------------ world
func _build_world() -> void:
	await _stage("Reading the valley", 0.05)
	var touch_dev := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	var dev_args := OS.get_cmdline_user_args()
	terrain = Terrain.new()
	add_child(terrain)
	terrain.load_world()
	await _stage("Shaping the ground", 0.18)
	terrain.build()
	await _stage("Planting the trees", 0.3)
	world = World.new()
	add_child(world)
	world.build(terrain, touch_dev)
	home = world.home
	await _stage("Growing the grass", 0.7)
	grass = Grass.new()
	add_child(grass)
	if not "nograss" in dev_args: grass.build(terrain, "low" if touch_dev else "high", world.exclusions, home)
	# sun, sky and atmosphere
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 350.0
	sun.light_energy = 2.2
	sun.shadow_blur = 1.2
	add_child(sun)
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.directional_shadow_max_distance = 120.0
	moon.light_color = Color(0.62, 0.74, 1.0)
	moon.light_energy = 0.0
	moon.light_angular_distance = 1.0
	add_child(moon)
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
		# sun and sky light bouncing between the ground, grass and trees. Off by default (it blackens the leaf cards); try it with `gi`.
		env.sdfgi_enabled = OS.get_cmdline_user_args().has("gi")
		env.sdfgi_use_occlusion = true
		env.sdfgi_cascades = 5
		env.sdfgi_min_cell_size = 1.0
		env.sdfgi_energy = 1.0
		env.sdfgi_bounce_feedback = 0.4
		if env.sdfgi_enabled: env.ssil_enabled = false
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
	var hour := float(w.get("hour", 16.0))
	var new_mode := int(w.get("clock_mode", 0))
	# a set time starts from the hour in the settings: when first loaded, when switched on, or when the slider moves
	if new_mode == 1 and (_hour_setting < 0.0 or _clock_mode == 0 or absf(hour - _hour_setting) > 0.001): _clock = hour
	_hour_setting = hour
	_clock_mode = new_mode; _clock_speed = int(w.get("clock_speed", 0)); _date_pick = int(w.get("date", 0))
	_apply_date()
	_tick_clock(0.0)
	_update_celestial()
	wx.set_condition(int(w["sky"]), float(w["intensity"]))
	_apply_weather_state(0.0, true)

## The calendar day: today's, or one of the season presets.
func _apply_date() -> void:
	var now := Time.get_datetime_dict_from_system(false)
	var m := int(now["month"]); var d := int(now["day"])
	if _date_pick > 0:
		var pr: Array = DATES[_date_pick - 1]
		m = pr[0]; d = pr[1]
	_doy = Solar.day_of_year(m, d)
	_unix = Time.get_unix_time_from_datetime_dict({"year": int(now["year"]), "month": m, "day": d, "hour": 12, "minute": 0, "second": 0}) + 4.0 * 3600.0
	_utc_off = Solar.utc_offset_for(_doy)

func _tick_clock(delta: float) -> void:
	if _clock_mode == 0:
		var now := Time.get_datetime_dict_from_system(false)
		_clock = float(now["hour"]) + float(now["minute"]) / 60.0 + float(now["second"]) / 3600.0
	elif _clock_speed != 2 and not paused:
		_clock += delta / 3600.0 * (60.0 if _clock_speed == 1 else 1.0)
		if _clock >= 24.0: _clock -= 24.0

## Place the sun and the moon in the sky for the current time.
func _update_celestial() -> void:
	var sp := Solar.sun_position(_doy, _clock, _utc_off)
	_sun_el = sp.x; _sun_az = sp.y
	var to_sun := Solar.direction(sp.x, sp.y)
	_sun_dir = to_sun
	if sensor: sensor.set_sun_direction(to_sun)
	sun.global_transform = Transform3D(Basis.looking_at(-to_sun, Vector3.UP if absf(to_sun.y) < 0.99 else Vector3.FORWARD), Vector3.ZERO)
	sun.light_color = Color.WHITE
	sun.light_temperature = 3300.0 + 1200.0 * smoothstep(5.0, 22.0, _sun_el) + 1500.0 * smoothstep(22.0, 60.0, _sun_el)
	var phase := Solar.moon_phase(_unix + (_clock - 12.0) * 3600.0)
	_moon_illum = Solar.moon_illumination(phase)
	var mp := Solar.moon_position(_doy, _clock, phase, _utc_off)
	_moon_el = mp.x
	_moon_dir = Solar.direction(mp.x, mp.y)
	moon.global_transform = Transform3D(Basis.looking_at(-_moon_dir, Vector3.UP if absf(_moon_dir.y) < 0.99 else Vector3.FORWARD), Vector3.ZERO)
	_daylight = smoothstep(-9.0, 5.0, _sun_el)

func _apply_weather_state(delta: float, snap := false) -> void:
	wx.update(delta, snap)
	var c := wx.cur
	var sun_base := 2.6 * (0.55 + 0.45 * smoothstep(3.0, 18.0, _sun_el)) * smoothstep(-1.5, 3.0, _sun_el)
	var storm_flash := wx.flash
	sun.light_energy = sun_base * float(c["sun"]) + storm_flash * 4.0
	sun.shadow_opacity = clampf(0.25 + 3.0 * float(c["sun"]), 0.0, 1.0)
	# the moon: its light scales with how much of it is lit and how high it stands, and cloud dims it
	var moon_f := _moon_illum * smoothstep(-2.0, 8.0, _moon_el) * (1.0 - _daylight)
	moon.light_energy = 0.14 * pow(_moon_illum, 1.3) * smoothstep(-2.0, 8.0, _moon_el) * (1.0 - _daylight) * (0.25 + 0.75 * float(c["sun"]))
	moon.visible = moon.light_energy > 0.002
	sun.visible = _sun_el > -3.0
	var night_amb := 0.012 + 0.10 * moon_f
	env.ambient_light_energy = 1.15 * float(c["amb"]) * lerpf(night_amb, 1.0, _daylight) + storm_flash * 1.2
	sky_mat.set_shader_parameter("moon_dir", _moon_dir)
	sky_mat.set_shader_parameter("moon_illum", _moon_illum)
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
	env.fog_density = 0.00012 * float(c["fogd"])
	env.fog_light_color = Color(0.62, 0.70, 0.80).lerp(Color(0.66, 0.68, 0.72), grey) * lerpf(0.03 + 0.12 * moon_f, 1.0, _daylight)
	env.fog_sky_affect = 0.05 + 0.6 * float(c["fog"])
	env.fog_height_density = 0.0003 * float(c["fogd"])
	# wind follows the condition
	wind.speed = _base_wind * float(c["wind"])
	RenderingServer.global_shader_parameter_set("g_cloud", Vector4(float(c["cover"]), wd.x * (4.0 + 2.0 * wind.speed), wd.z * (4.0 + 2.0 * wind.speed), sim_time))
	wind.gust = clampf(_base_gust + (0.35 if wx.kind == WeatherSystem.Kind.STORM else 0.0), 0.0, 1.0)
	# precipitation
	var rain := float(c["rain"])
	var snow_p := float(c["snow"])
	rain_fx.emitting = rain > 0.03
	# water collects on the lens in rain and dries slowly once it stops
	_lens_water = move_toward(_lens_water, clampf(rain * 1.4, 0.0, 0.8) if rain > 0.03 else 0.0, delta * (0.25 if rain > 0.03 else 0.03))
	sensor.rain_lens = _lens_water if not chase else 0.0
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
	autopilot.cancel()
	if hud and hud.minimap: hud.minimap.clear_trail()
	var y := terrain.height(home.x, home.y) + 0.04
	quad.reset(home.x, y, home.y, deg_to_rad(150.0))
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
	audio.set_arm(float(af["armD"]))
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
	if not _loaded: return
	if paused: return
	var st := _read_sticks()
	var p := quad.position()
	var agl := p.y - terrain.height(p.x, p.z)
	st = _autopilot_sticks(st, p, agl)
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
	if quad == null or not _loaded: return
	if _gallery_cam:
		return
	# Q and E tilt a gimbal camera smoothly while held: it speeds up, then eases to a stop when released
	var tilt_in := (1.0 if Input.is_key_pressed(KEY_Q) else 0.0) - (1.0 if Input.is_key_pressed(KEY_E) else 0.0)
	if not af["hasGimbal"] or paused: tilt_in = 0.0
	_gimbal_rate = lerpf(_gimbal_rate, tilt_in * deg_to_rad(45.0), 1.0 - exp(-delta * 7.0))
	if absf(_gimbal_rate) > 0.0005:
		gimbal_pitch = clampf(gimbal_pitch + _gimbal_rate * delta, deg_to_rad(-90.0), deg_to_rad(20.0))
		hud.set_gimbal_value(gimbal_pitch)
	_tick_clock(delta)
	_celestial_t -= delta
	if _celestial_t <= 0.0:
		_celestial_t = 0.25
		_update_celestial()
	_hour_write_t -= delta
	if _hour_write_t <= 0.0:
		_hour_write_t = 1.0
		_hour_setting = _clock; hud.weather["hour"] = _clock      # so the settings page shows the time that is running
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
		var d := _chase_d if _chase_d > 0.0 else 3.5 + 16.0 * float(af["armD"])
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
	drone_view.visible = true
	drone_view.set_fpv(not chase)
	drone_view.update_props(quad.s, sim_time, quad.armed)
	# precipitation follows the camera
	snow_fx.global_position = cam.global_position + Vector3(0, 12, 0)
	rain_fx.global_position = cam.global_position + Vector3(0, 16, 0)
	var wdir := wind.toward() * wind.speed * 0.8
	snow_mat.direction = Vector3(wdir.x, -1.0, wdir.z).normalized()
	_apply_weather_state(delta)
	_update_sensor_and_osd(delta)

func _unhandled_key_input(event: InputEvent) -> void:
	if not _loaded: return
	if not (event is InputEventKey and event.pressed and not event.echo): return
	match event.keycode:
		KEY_MINUS: sensor.ev_comp = clampf(sensor.ev_comp - 0.33, -3.0, 3.0)
		KEY_EQUAL: sensor.ev_comp = clampf(sensor.ev_comp + 0.33, -3.0, 3.0)
		KEY_L: hud.toggle_lens()
		KEY_V: hud.listening = (hud.listening + 1) % 3; audio.set_perspective(hud.listening); hud.toast("Sound: " + audio.perspective_name())
		KEY_H: osd.show_osd = not osd.show_osd
		KEY_R: spawn()
		KEY_C: hud.set_chase(not chase)
		KEY_M: hud.cycle_mode()
		KEY_Q, KEY_E:
			if not af["hasGimbal"]: hud.toast("This drone's camera is fixed. Pick the Gimbal Mini or the Cinema drone to tilt it.")

# ------------------------------------------------------------------ screenshot helper for development
func _screenshot_mode(arg: String) -> void:
	var parts := arg.split(",")
	var path := parts[0]
	var frames := int(parts[1]) if parts.size() > 1 else 90
	if parts.size() > 2: chase = parts[2] == "chase"; hud.set_chase(chase)
	for c in parts.slice(3):
		if c.begins_with("drone"): switch_drone(c.substr(5))
		if c.begins_with("lens"): sensor.set_lens(c.substr(4))
		if c == "armed": quad.armed = true
		if c.begins_with("clock"):     # test hook: freeze the clock at that hour (clock7.5), on the date picked with date1..4
			hud.weather["hour"] = float(c.substr(5)); hud.weather["clock_mode"] = 1; hud.weather["clock_speed"] = 2; apply_weather(hud.weather); print("sun el ", snappedf(_sun_el, 0.1), " az ", snappedf(_sun_az, 0.1), " moon el ", snappedf(_moon_el, 0.1), " illum ", snappedf(_moon_illum, 0.01), " dir ", _moon_dir)
		if c.begins_with("date"):
			hud.weather["date"] = int(c.substr(4)); apply_weather(hud.weather)
		if c == "light": drone_light.visible = true
		if c.begins_with("cd"): _chase_d = float(c.substr(2))
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
	var peaks := []
	for bn in ["Master", "Ground", "Onboard", "Ambient", "Birds"]:
		peaks.append("%s %.0f dB" % [bn, AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index(bn), 0)])
	print("audio peaks ", ", ".join(peaks))
	get_tree().quit()

var _auto_climb := false
var _lens_water := 0.0
var _chase_d := 0.0            # test hook: chase camera distance in metres (`cd<m>` in a screenshot run)

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
	var peaks := []
	for bn in ["Master", "Ground", "Onboard", "Ambient", "Birds"]:
		var bi := AudioServer.get_bus_index(bn)
		peaks.append("%s %.0f dB" % [bn, AudioServer.get_bus_peak_volume_left_db(bi, 0)])
	print("selftest: audio peaks ", ", ".join(peaks))
	print("selftest: motor3d playing=", audio._motor_g[0].playing, " bus=", audio._motor_g[0].bus, " vol=", audio._motor_g[0].volume_db, " pitch=", audio._motor_g[0].pitch_scale, " in_tree=", audio._motor_g[0].is_inside_tree(), " dist=", audio._motor_g[0].global_position.distance_to(audio._listener.global_position), " | 2d playing=", audio._motor_o[0].playing, " vol=", audio._motor_o[0].volume_db)
	get_tree().quit()

var _gallery_cam := false

## Development view: every tree variant and a row of cemetery pieces, close up, to judge the models.
func _build_gallery() -> void:
	_gallery_cam = true
	drone_view.visible = false
	var gy := terrain.height(home.x, home.y)
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
	_canopy_wind = wind.sample(Vector3(dp.x, terrain.height(dp.x, dp.z) + 14.0, dp.z), 14.0, sim_time)
	RenderingServer.global_shader_parameter_set("g_wind", _canopy_wind)
	RenderingServer.global_shader_parameter_set("g_drone", Vector4(dp.x, dp.y, dp.z, 3.5))
	_wash_now = clampf(fc.thrust_fraction() * 1.8, 0.0, 1.0) * 0.55 * (1.0 - smoothstep(2.5, 8.0, agl0)) * (1.0 if quad.armed else 0.0)
	RenderingServer.global_shader_parameter_set("g_wash", _wash_now)
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
	elif world.canopy_blocks(cpos, _sun_dir, 90.0): sun_target = 0.0
	sun_target *= smoothstep(0.12, 0.5, float(wx.cur["sun"])) * smoothstep(0.0, 3.0, _sun_el)
	_sun_vis += (sun_target - _sun_vis) * clampf(delta * 8.0, 0.0, 1.0)
	sensor.sun_vis = _sun_vis
	# video link: free-space loss with distance, plus a penalty when the terrain blocks the line of sight
	var dpos := quad.position()
	var home_p := Vector3(home.x, terrain.height(home.x, home.y) + 1.6, home.y)
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
		"heading": atan2(dfwd.x, -dfwd.z), "velBody": vcam, "fov": cam.fov, "aglM": agl, "mslM": dpos.y,
		"gs": sqrt(quad.s[3] * quad.s[3] + quad.s[5] * quad.s[5]), "vs": quad.s[4],
		"homeDist": sqrt((dpos.x - home.x) * (dpos.x - home.x) + (dpos.z - home.y) * (dpos.z - home.y)),
		"gimbalDeg": rad_to_deg(gimbal_pitch) if af["hasGimbal"] else rad_to_deg(float(af["camTilt"])),
		"histogram": sensor.histogram, "lensName": sensor.lens_info()["name"], "airframe": af["name"],
		"audio": audio.perspective_name() if audio.enabled else "off", "fps": int(_fps), "crashed": quad.crash_reason if (quad.crashed or not quad.armed) else "",
		"armed": quad.armed, "touch": DisplayServer.is_touchscreen_available(), "mission": [],
		"windMs": _wind_now.length(), "windLevel": "", "homeBearing": atan2(home.x - dpos.x, -(home.y - dpos.z)), "stopHit": 0.0, "aero": "",
	}
	hud.show_crash(osd.t["crashed"])
	var om := PackedFloat64Array([quad.s[13], quad.s[14], quad.s[15], quad.s[16]])
	var cov_f := terrain.cover_at(dpos.x, dpos.z).x
	audio.update({"omega": om, "blades": af["nBlades"], "thrust": clampf(fc.thrust_fraction() ** 0.5, 0.0, 1.0), "vz": quad.s[4], "jerk": quad.ang_accel.length(), "vrs": quad.vrs,
		"air_speed": (quad.velocity() - _wind_now).length(), "drone_pos": dpos, "drone_vel": quad.velocity(), "agl": agl, "wash": _wash_now,
		"wind": Vector2(_canopy_wind.x, _canopy_wind.z).length(), "conifer": clampf(0.3 + 0.7 * cov_f, 0.0, 1.0), "gust": wind.gust}, delta)
	hud.set_airborne(agl > 0.4)
	hud.set_rth(autopilot.state in [AutoPilot.State.RTH_CLIMB, AutoPilot.State.RTH_FLY, AutoPilot.State.RTH_LAND])
	hud.minimap.update_state(dpos, float(osd.t["heading"]), delta)
	if recording:
		_rec_time += delta
		osd.t["rec"] = "REC %02d:%02d" % [int(_rec_time) / 60, int(_rec_time) % 60]

# ------------------------------------------------------------------ assisted flight, photos
## Mixes the assisted-flight sticks into what the pilot holds. Return to home gives way as soon as the pilot moves a stick.
func _autopilot_sticks(st: Vector4, p: Vector3, agl: float) -> Vector4:
	if not autopilot.active(): return st
	if fc.mode == "M":
		autopilot.cancel("Assisted flight needs Normal or Sport mode")
	else:
		var lim: Dictionary = af["limits"]["S" if fc.mode == "S" else "N"]
		var cmd := autopilot.update(p, quad.velocity(), fc.heading, agl, home, float(lim["vH"]), float(lim["vUp"]))
		var rth := autopilot.state in [AutoPilot.State.RTH_CLIMB, AutoPilot.State.RTH_FLY, AutoPilot.State.RTH_LAND]
		if rth and maxf(maxf(absf(st.x), absf(st.y)), maxf(absf(st.z), absf(st.w))) > 0.25:
			autopilot.cancel("Return to home cancelled")
		elif cmd.is_finite():
			st = cmd
	if autopilot.message != "":
		hud.toast(autopilot.message); autopilot.message = ""
	return st

func _takeoff_or_land() -> void:
	var p := quad.position()
	var agl := p.y - terrain.height(p.x, p.z)
	if quad.crashed or not quad.armed:
		hud.toast("Reset the drone first", true); return
	if autopilot.state == AutoPilot.State.TAKEOFF or autopilot.state == AutoPilot.State.LAND:
		autopilot.cancel("Cancelled"); return
	if agl > 0.4: autopilot.start_landing()
	else: autopilot.start_takeoff()
	if fc.mode == "M": hud.set_mode("N")

func _toggle_rth() -> void:
	var p := quad.position()
	var agl := p.y - terrain.height(p.x, p.z)
	if quad.crashed or not quad.armed:
		hud.toast("Reset the drone first", true); return
	if autopilot.state in [AutoPilot.State.RTH_CLIMB, AutoPilot.State.RTH_FLY, AutoPilot.State.RTH_LAND]:
		autopilot.cancel("Return to home cancelled"); hud.toast("Return to home cancelled"); return
	if agl < 0.4:
		hud.toast("Take off first", true); return
	if fc.mode == "M": hud.set_mode("N")
	autopilot.start_rth(agl)

## The shutter: a photo saves the finished video frame; in video mode it starts and stops a recording indicator.
func _shutter_pressed() -> void:
	if hud.video_mode:
		recording = not recording; _rec_time = 0.0
		hud._shutter.recording = recording; hud._shutter.queue_redraw()
		hud.toast("Recording" if recording else "Recording saved")
		return
	var img := sensor.capture()
	hud.flash_photo()
	if img == null:
		hud.toast("Photo taken"); return
	DirAccess.make_dir_recursive_absolute("user://photos")
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := "user://photos/AeroSim_%s.png" % stamp
	img.save_png(path)
	hud.toast("Photo saved")

var _apstest := false

## Headless check of assisted flight: take off, then fly 60 m away and come home by Return to Home and land.
func _run_apstest() -> void:
	_takeoff_or_land()
	for i in 500: await get_tree().physics_frame
	var p := quad.position()
	print("apstest: after takeoff agl %.2f m, state %d" % [p.y - terrain.height(p.x, p.z), autopilot.state])
	# put the drone 60 m out at 18 m above ground, hovering
	var px := 45.0
	var pz := 40.0
	quad.reset(px, terrain.height(px, pz) + 18.0, pz, deg_to_rad(40.0))
	var wh: float = float(af["omegaMax"]) * sqrt(1.0 / float(af["twr"]))
	for k in 4:
		quad.s[13 + k] = wh; quad.cmd[k] = wh
	fc.heading = deg_to_rad(40.0)
	_toggle_rth()
	var t := 0
	while autopilot.active() and t < 6000:
		await get_tree().physics_frame; t += 1
	p = quad.position()
	print("apstest: rth finished after %.1f s, state %d, %.1f m from home, agl %.2f m, crashed=%s" % [t * 0.008, autopilot.state, sqrt(p.x * p.x + p.z * p.z), p.y - terrain.height(p.x, p.z), quad.crashed])
	get_tree().quit()

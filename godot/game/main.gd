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
var quad            # a Quad or a Plane (the plane shares the same duck-typed interface)
var fc              # FlightController or PlaneController
var wind := Wind.new()
var drone_node := Node3D.new()
var drone_view := DroneView.new()
var cam := Camera3D.new()
var sun := DirectionalLight3D.new()
var moon := DirectionalLight3D.new()
var drone_light := SpotLight3D.new()
var drone_shadow := DroneShadow.new()
var env := Environment.new()
var sky_mat := ShaderMaterial.new()
var _sky_quality := 1            # cloud quality: 0 low, 1 medium, 2 high (set in _build_world)
var _aurora := 0.0               # aurora strength 0..1 (sky A1 test hook)
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
var ambient: AmbientParticles     # drifting leaves, dust motes and rotor-wash debris
var hud: Hud
var phone_notes: PhoneNotes        # session B: the DroneBudz phone notification bundle (game/phone_notes.gd)
var world_life: WorldLife          # session B: the farm, turning mill and discoverable places (game/world_life.gd)
var photo_library: PhotoLibrary    # session B: the in-game photo gallery (game/photo_library.gd)
var jobs: Jobs                     # session B: the opt-in DroneBudz jobs and story layer (game/jobs.gd)
var clips: ClipLibrary             # session B: representative thumbnails from video mode (game/clip_library.gd)
var chat_data: ChatData            # session B: the DroneBudz Discord-style server (game/chat_data.gd)
var phone_os: PhoneOS              # session B: the in-game phone with its apps (game/phone_os.gd)
var guide: GuideCoach              # session B: Kit, the DroneBudz support contact and story-mode tips
var anti_drone: AntiDrone          # session B: Harlan Pike, the north ridge jammer and hunter drones
var case_objects: CaseObjects      # session B: the Lake Car evidence landmarks (game/case_objects.gd)
var story: StoryArc                # session B: the Lake Car story arc (game/story_arc.gd)
var unknown_thread: UnknownThread  # session B: the unknown direct message thread (game/unknown_thread.gd)
var thermal: ThermalCamera         # session B: the heat camera for the last flight (game/thermal.gd)
var night_vision: NightVision      # session B: the Facade night vision add-on (game/night_vision.gd)
var inventory: Inventory           # session B: the pilot's bought kit (game/inventory.gd)
var wildlife_objects: WildlifeObjects  # session B: the sheep and the wolf in the west pasture
var wildlife: WildlifeCase         # session B: Riley's night tracking favour and the thermal tutorial
var launch_sites: LaunchSites       # session B: where the kit is parked and where the next flight starts
var launch_pos := Vector2(-18.0, 36.0)
var launch_yaw := 150.0
var director: StoryDirector        # session B: the one player-facing route through all the story arcs
var finale: Finale                 # session B: the cabin, the ghost and Wren (game/finale.gd)
var ending: Ending                 # session B: the credits and the end of the story (game/ending.gd)
var end_sequence := false         # session B: the slow end wash and the end card
var end_walk := false             # session B: free look and walk after the card, before flying again
var _end_cam_pos := Vector3.ZERO
var _end_yaw := 0.0
var _end_pitch := -0.08
var _end_marker: MeshInstance3D
var roads: Roads                   # session B: the country highways and lanes linking the places (game/roads.gd)
var boat_launch: BoatLaunch        # session B: the Halloway Lake boat launch at the end of the launch lane
var cabin_track: CabinTrack        # session B: the dirt and gravel track, fallen trees, rockfall and cave
var road_signs: RoadSigns          # session B: stop signs, speed limits and junction warnings
var landmark_signs: LandmarkSigns  # session B: the cemetery gateway and the place and business signs
var intersection_signals: IntersectionSignals  # session B: the flashing red beacons over the junctions
var farmland: Farmland             # session B: the farm fields, crops, bales and fences (game/farmland.gd)
var traffic: Traffic               # session B: traffic on the country roads (game/traffic.gd)
var crew: Crew                     # session B: the six friends, each giving the pilot different information (game/crew.gd)
var osd: Osd
var sensor: SensorPipeline
var autopilot := AutoPilot.new()
var audio: DroneAudio
var fireworks: Fireworks           # session B: firework shows over the lake (game/fireworks.gd)
var birds: Birds                   # session B: geese, gulls, starlings and hawks (game/birds.gd)
var weather_events: WeatherEvents  # session B: extreme weather events and courses (game/weather_events.gd)
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
var cam_shake := CamShake.new()   # wind lane: camera buffeting in rough air (game/shake.gd)
var _low_cloud_inside := 0.0      # sky lane (E3): 0 outside the low cloud, 1 fully inside

var _loaded := false
var _air_test := Vector3.ZERO      # test hook: `air<x>_<y>_<head-on>` pins the air speed over the lens
var _gimbal_rate := 0.0
var landing: Landing
var _landing_on := false
var _landing_t := 0.0
var _home_charging := false
var _charge_t := 0.0
var _charge_done := false
var _prev_auto_state := AutoPilot.State.NONE
const RECHARGE_SECONDS := 6.0

## The welcome screen: the valley behind a slowly circling camera, with a short menu. Fly starts the flight.
func _show_landing() -> void:
	if _landing_on: return
	_landing_on = true; _landing_t = 0.0; paused = true
	hud.set_landing(true)
	osd.visible = false
	if sticks: sticks.enabled = false
	landing = Landing.new()
	add_child(landing)
	landing.build(str(af["name"]), hud.story_mode)
	landing.fly_pressed.connect(_start_flight)
	landing.mode_chosen.connect(func(story: bool):
		hud.set_story_mode(story)
		landing.set_story_mode(story))
	landing.drone_pressed.connect(func(): hud.set_paused(true); hud.open_tab(1))
	landing.settings_pressed.connect(func(): hud.set_paused(true); hud.open_tab(3))
	landing.controls_pressed.connect(func(): hud.set_paused(true); hud.open_tab(5))
	landing.quit_pressed.connect(func(): get_tree().quit())
	landing.look_chosen.connect(func(h: float, s: int):
		hud.weather["hour"] = h; hud.weather["clock_mode"] = 1; hud.weather["clock_speed"] = 0; hud.weather["sky"] = s
		hud.apply_look())

func _start_flight() -> void:
	if not _landing_on: return
	_landing_on = false
	if landing: landing.queue_free(); landing = null
	hud.set_landing(false)
	osd.visible = true
	if sticks: sticks.enabled = true
	paused = false
	spawn()
	hud.toast("Take off with the button on the left, or push the left stick up.")

## Phone-safe camera: the plain 3D picture with an ordinary tone map, in place of the HDR sensor passes.
func _apply_simple(on: bool) -> void:
	sensor.set_simple(on)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC if on else Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = on
	env.glow_intensity = 0.25
	env.glow_bloom = 0.02
	hud.toast("Plain camera" if on else "Full sensor camera")

## The drone's shadow is sized to this airframe.
func _after_drone_built() -> void:
	if terrain: drone_shadow.setup(af, terrain)

## The pictures on the drone chooser are drawn once the game is running, a drone at a time.
func _make_drone_pictures() -> void:
	var thumbs: Dictionary = await DroneThumbs.render_all(self, Airframes.IDS)
	hud.set_drone_thumbs(thumbs)
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
	Fireworks.add_globals()        # session B: the burst light colour that the smoke and the lake read (g_fire)
	await _build_world()
	inventory = Inventory.new()
	inventory.setup()
	launch_sites = LaunchSites.new()
	launch_sites.setup()
	launch_pos = launch_sites.pos()
	launch_yaw = launch_sites.yaw()
	af = inventory.apply_airframe(Airframes.make(airframe_id), airframe_id)
	if airframe_id == "wing":
		quad = FPVPlane.new(af)                       # plane lane: fixed wing (physics/plane.gd)
		fc = PlaneController.new(af, quad)
	else:
		quad = Quad.new(af)
		fc = FlightController.new(af, quad)
	fc.set_step(DT)
	quad.ground_h = func(x: float, z: float) -> float: return terrain.height(x, z)
	quad.ground_n = func(x: float, z: float) -> Vector3: return terrain.normal_at(x, z)
	quad.obstacle_hit = world.obstacle_hit
	add_child(drone_node)
	drone_node.add_child(drone_view)
	add_child(drone_shadow)
	# a spotlight on the airframe, pointing forward and a little down, for flying at night
	drone_light.position = Vector3(0, -0.02, -0.1)
	drone_light.rotation_degrees = Vector3(-22, 0, 0)
	drone_light.spot_range = 70.0; drone_light.spot_angle = 34.0; drone_light.spot_attenuation = 0.5
	drone_light.light_energy = 14.0; drone_light.light_color = Color(1.0, 0.96, 0.88)
	drone_light.shadow_enabled = true
	drone_light.visible = false
	drone_node.add_child(drone_light)
	drone_view.build(af)
	_after_drone_built()
	add_child(cam)
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cam.near = 0.03; cam.far = 26000.0; cam.fov = 84.0; cam.current = true
	hud = Hud.new()
	add_child(hud)
	# session B: the phone-style DroneBudz notification bundle for world events (shows, storms, tornadoes, fog).
	# It is a UI overlay only and is switched from Display > Overlay and sound > Phone messages.
	phone_notes = PhoneNotes.new()
	add_child(phone_notes)
	phone_notes.setup(hud)
	hud.pause_changed.connect(func(p: bool): paused = p or _landing_on; if sticks: sticks.release_all(); sticks.enabled = not p and not _landing_on; osd.visible = not p and not _landing_on)
	hud.reset_requested.connect(spawn)
	hud.drone_picked.connect(switch_drone)
	hud.mode_changed.connect(func(m: String): fc.mode = m; fc.reset_state())
	hud.camera_changed.connect(func(c: bool): chase = c)
	hud.weather_changed.connect(apply_weather)
	hud.light_changed.connect(func(on: bool): drone_light.visible = on)
	hud.grass_changed.connect(func(on: bool): grass.visible = on)
	hud.ambient_changed.connect(func(on: bool): ambient.set_enabled(on))
	hud.simple_changed.connect(_apply_simple)
	hud.gimbal_changed.connect(func(r: float): gimbal_pitch = r)
	hud.set_airframe(airframe_id)
	sticks = TouchSticks.new()
	hud.add_child(sticks)
	sticks.blocked = hud.interactive_controls()
	hud.show_gimbal(af["hasGimbal"])
	hud.lens_changed.connect(func(l: String): sensor.set_lens(l))
	hud.ev_changed.connect(func(v: float): sensor.ev_comp = v)
	hud.bloom_changed.connect(func(on: bool): sensor.bloom_on = on)
	hud.look_changed.connect(func(i: int): sensor.look = i)   # camera A3 stage 1.2
	hud.noise_changed.connect(func(v: float): sensor.noise_scale = v)
	hud.link_changed.connect(func(on: bool): sensor.link_effects = on)
	hud.dof_changed.connect(func(m: int): sensor.dof_mode = m)
	hud.focus_changed.connect(func(mf: bool, d: float): sensor.manual_focus = mf; sensor.mf_distance = d)
	sticks.tapped.connect(func(pos: Vector2): sensor.focus_tap(pos))
	hud.osd_changed.connect(func(on: bool): osd.show_osd = on)
	hud.photo_requested.connect(_shutter_pressed)
	hud.sound_changed.connect(func(on: bool): audio.set_enabled(on))
	hud.listening_changed.connect(func(i: int): audio.set_perspective(i))
	hud.volume_changed.connect(func(v: float): audio.set_volume(v))
	hud.takeoff_land_requested.connect(_takeoff_or_land)
	hud.rth_requested.connect(_toggle_rth)
	hud.wind_fx_changed.connect(func(e: bool, s: bool): wind.struggle = e; cam_shake.enabled = s)   # wind lane
	hud.sky_quality_changed.connect(func(i: int): _sky_quality = i)   # sky lane: cloud quality from the menu
	# the camera renders into the sensor pipeline's overscan viewport; the window itself only shows the video frame and the HUD
	await _stage("Setting up the camera", 0.82)
	sensor = SensorPipeline.new()
	add_child(sensor)
	if fireworks: fireworks.set_sensor(sensor)   # session B: bursts flash the lens and nudge the exposure
	var touch_device := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	# real phones start in the plain picture; a laptop with a touch screen keeps the full camera (the Display tab can switch either way)
	sensor.simple = OS.has_feature("mobile") or "simple" in OS.get_cmdline_user_args()
	hud.simple_on = sensor.simple
	hud.sky_quality = _sky_quality   # sky lane: show the phone/desktop cloud-quality default in the menu
	sensor.setup(cam, 540 if touch_device else 720, Viewport.MSAA_DISABLED if touch_device else Viewport.MSAA_2X)
	sensor.focus_message.connect(func(t: String): hud.toast(t))
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
	# session B: fireworks over the lake. The pause menu starts a show; the game moves the clock for it in daylight
	# (21:30 on the same date) and puts the menu choice back to Off when the show ends.
	fireworks = Fireworks.new()
	add_child(fireworks)
	fireworks.setup(terrain, home)
	fireworks.set_sensor(sensor)   # session B: bursts flash the lens and nudge the exposure
	hud.fireworks_changed.connect(func(i: int):
		fireworks.request_show(i)
		if i != 0 and phone_notes: phone_notes.post("show_soon")   # session B: a DroneBudz text before the show
	)
	hud.surprise_changed.connect(func(on: bool): fireworks.surprise_on = on)
	fireworks.show_ended.connect(func(): hud.fireworks_show = 0; hud._sync())
	# session B: show notices go to the phone notification bundle, not the white warning line
	fireworks.toast.connect(func(t: String):
		if phone_notes and t.begins_with("The show is starting"):
			phone_notes.post("show_start")
		elif phone_notes and t.begins_with("The show is over"):
			phone_notes.post("show_over")
		elif t.begins_with("A fireworks show"):
			if phone_notes: phone_notes.post("show_start")
			hud.toast(t)
		else:
			hud.toast(t)
	)
	fireworks.night_needed.connect(func():
		hud.weather["hour"] = 21.5
		hud.weather["clock_mode"] = 1
		hud.weather["clock_speed"] = 2
		apply_weather(hud.weather)
	)
	# session B: the birds of the valley (game/birds.gd): geese crossing in a V, gulls on the lake shore, a starling
	# murmuration at dusk, and the two hawks drawn where their calls already come from.
	birds = Birds.new()
	add_child(birds)
	birds.setup(terrain, home)
	birds.set_audio(audio)
	hud.birds_changed.connect(func(on: bool): birds.enabled = on)
	# session B: the extreme-weather events and the ring courses (game/weather_events.gd, funnel.gd, courses.gd,
	# sky_life.gd). It reads the Weather tab Events section and the Flight tab course choice from hud.events.
	weather_events = WeatherEvents.new()
	add_child(weather_events)
	weather_events.setup(terrain, wind, hud, wx, sensor, birds)
	weather_events.set_notes(phone_notes)   # session B: event notices arrive as DroneBudz phone messages
	# session B: the inhabited valley (farm, turning mill, discoverable places) and the in-game photo library.
	# Both are passive: they add life and discovery without touching the sandbox or forcing any objective.
	world_life = WorldLife.new()
	add_child(world_life)
	world_life.setup(terrain, wind)
	world_life.notes = phone_notes
	photo_library = PhotoLibrary.new()
	add_child(photo_library)
	photo_library.setup(hud, world_life)
	hud.gallery_requested.connect(func(): photo_library.open_gallery())
	# session B: the opt-in jobs and story layer, fed by the photo metadata. Ignoring it changes nothing in the sandbox.
	jobs = Jobs.new()
	add_child(jobs)
	jobs.setup(hud, photo_library, phone_notes)
	clips = ClipLibrary.new()
	add_child(clips)
	clips.setup()
	jobs.set_clips(clips)
	photo_library.photo_saved.connect(jobs.on_photo)
	hud.jobs_requested.connect(func(): jobs.open_page())
	# session B: the phone. The chat server is the story spine; the phone hosts the apps (chat, studio, photos, jobs).
	chat_data = ChatData.new()
	jobs.set_chat(chat_data)
	photo_library.jobs = jobs
	photo_library.chat = chat_data
	# session B: the crew each have their own job and their own information for the pilot
	crew = Crew.new()
	crew.setup(chat_data, hud, jobs, world_life, weather_events, photo_library)
	# session B: the Lake Car story. Rennick appears after the first published clip or finished job.
	story = StoryArc.new()
	add_child(story)
	story.setup(hud, chat_data, jobs, phone_notes, photo_library, case_objects)
	photo_library.photo_saved.connect(story.on_photo)
	# session B: the unknown account that starts as a wrong number and slowly knows too much
	unknown_thread = UnknownThread.new()
	add_child(unknown_thread)
	unknown_thread.setup(chat_data, phone_notes, hud, story)
	# session B: the final flight. Thermal camera, the storm search, the ghost and the credits.
	thermal = ThermalCamera.new()
	add_child(thermal)
	night_vision = NightVision.new()
	add_child(night_vision)
	# session B: the west pasture, the sheep and the wolf, and the thermal-camera tutorial favour
	wildlife_objects = WildlifeObjects.new()
	add_child(wildlife_objects)
	wildlife_objects.setup(terrain)
	wildlife = WildlifeCase.new()
	add_child(wildlife)
	wildlife.setup(hud, chat_data, phone_notes, story, inventory, thermal, wildlife_objects)
	ending = Ending.new()
	add_child(ending)
	ending.setup(jobs)
	ending.began.connect(_on_ending_began)
	ending.card_finished.connect(_on_ending_free)
	finale = Finale.new()
	add_child(finale)
	finale.setup(hud, chat_data, phone_notes, story, unknown_thread, case_objects, weather_events, thermal, ending, inventory, wildlife, launch_sites)
	director = StoryDirector.new()
	add_child(director)
	director.setup(hud, story, unknown_thread, wildlife, inventory, finale, ending)
	phone_os = PhoneOS.new()
	add_child(phone_os)
	phone_os.setup(hud, jobs, photo_library, chat_data, crew, story, inventory, clips, director, roads, launch_sites, finale, wildlife)
	phone_os.fly_drone.connect(switch_drone)
	phone_os.travel_requested.connect(travel_to_site)
	guide = GuideCoach.new()
	add_child(guide)
	guide.setup(hud, chat_data, phone_notes, phone_os, story, director, wildlife, inventory, photo_library, jobs, finale)
	anti_drone = AntiDrone.new()
	add_child(anti_drone)
	anti_drone.setup(hud, chat_data, phone_notes, story, director, finale, quad, terrain)
	anti_drone.forced_return.connect(_on_anti_return)
	finale.anti_drone = anti_drone
	# a notification's "Open DroneBudz" button goes straight into the chat app
	phone_notes.app_requested.connect(func(app: String):
		phone_os.open()
		phone_os._open_app(app))
	await _stage("Almost ready", 0.97)
	hud.minimap.bake(terrain)
	hud.minimap.home = launch_pos
	var pl: Array[PackedVector2Array] = []
	for p in terrain.layout["paths"]:
		var pts := PackedVector2Array()
		for q in p["pts"]: pts.append(Vector2(q[0], q[1]))
		pl.append(pts)
	hud.minimap.paths = pl
	var rp: Array[PackedVector2Array] = []
	for id in roads.paths:
		var pts2 := PackedVector2Array()
		for q in roads.paths[id]:
			pts2.append(q)
		rp.append(pts2)
	hud.minimap.roads = rp
	apply_weather(hud.weather, true)   # snap at start-up so the game begins at the saved weather
	spawn()
	drone_shadow.setup(af, terrain)
	if sensor.simple:
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; env.glow_enabled = true; env.glow_intensity = 0.25; env.glow_bloom = 0.02
	_loaded = true
	if hud != null: hud.set_story_mode(hud.story_mode)
	if q_arg == "" and not _apstest and not _selftest and not "nolanding" in OS.get_cmdline_user_args(): _show_landing()
	if _load_layer: _load_layer.queue_free()
	_make_drone_pictures()
	if q_arg != "": _screenshot_mode(q_arg)
	if _selftest: _run_selftest()
	if _apstest: _run_apstest()

# ------------------------------------------------------------------ world
func _build_world() -> void:
	await _stage("Reading the valley", 0.05)
	var touch_dev := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	RenderingServer.global_shader_parameter_add("g_csun", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.0, 0.0, 0.0, 0.0))   # cloud-shadow sun offset (before the world shaders compile)
	RenderingServer.global_shader_parameter_add("g_storm", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.0, 0.0, 0.0, 0.0))   # storm cell: x = anchor x, y = anchor z, z = strength (session B hangs the funnel here)
	RenderingServer.global_shader_parameter_add("g_bolt", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.0, -1.0, 0.0, 0.0))   # lightning bolt: xyz direction, w strength (session B's bolts)
	RenderingServer.global_shader_parameter_add("g_sky_dark", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)   # other effects darken the sky
	RenderingServer.global_shader_parameter_add("g_spout", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.0, 0.0, 0.0, 0.0))   # xz waterspout foot, radius, strength for the water rings
	var dev_args := OS.get_cmdline_user_args()
	terrain = Terrain.new()
	add_child(terrain)
	terrain.load_world()
	await _stage("Shaping the ground", 0.18)
	terrain.build()
	await _stage("Planting the trees", 0.3)
	CaseObjects.prepare(terrain)   # session B: clear the planting around the Lake Car evidence landmarks
	world = World.new()
	add_child(world)
	world.build(terrain, touch_dev)
	home = world.home
	# session B: the country highways and lanes, laid on the ground after the trees so the cleared corridor reads
	roads = Roads.new()
	add_child(roads)
	roads.setup(terrain)
	road_signs = RoadSigns.new()
	add_child(road_signs)
	road_signs.setup(terrain, roads)
	landmark_signs = LandmarkSigns.new()
	add_child(landmark_signs)
	landmark_signs.setup(terrain, roads)
	intersection_signals = IntersectionSignals.new()
	add_child(intersection_signals)
	intersection_signals.setup(terrain, hud)
	# session B: the farm fields (placeholder planting until Claude's models) and the traffic on the new roads.
	farmland = Farmland.new()
	add_child(farmland)
	farmland.setup(terrain)
	traffic = Traffic.new()
	add_child(traffic)
	traffic.setup(terrain, roads, hud)
	# session B: the physical evidence landmarks for the Lake Car story
	case_objects = CaseObjects.new()
	add_child(case_objects)
	case_objects.setup(terrain)
	var lake := Lake.new()
	add_child(lake)
	lake.build(terrain)
	# session B: the boat launch at the end of the lakeside lane
	boat_launch = BoatLaunch.new()
	add_child(boat_launch)
	boat_launch.setup(terrain)
	cabin_track = CabinTrack.new()
	add_child(cabin_track)
	cabin_track.setup(terrain)
	var hills := FarHills.new()
	add_child(hills)
	hills.build(terrain)
	await _stage("Growing the grass", 0.7)
	grass = Grass.new()
	add_child(grass)
	if not "nograss" in dev_args: grass.build(terrain, "low" if OS.has_feature("mobile") else "high", world.exclusions, home, roads.road_mask)
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
	_sky_quality = 0 if (touch_dev or RenderingServer.get_current_rendering_method() == "mobile") else 1   # cheap clouds on phones and the mobile renderer
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
	ambient = AmbientParticles.new(); add_child(ambient); ambient.setup(terrain, touch_dev)

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
func apply_weather(w: Dictionary, snap := false) -> void:
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
	_apply_weather_state(0.0, snap)

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
	sky_mat.set_shader_parameter("rain", float(c["rain"]))
	sky_mat.set_shader_parameter("snow", float(c["snow"]))
	# low cloud layer (E3): the sky draws the stratus, and the world fog does the inside effect
	var lc_i := int(hud.weather.get("lowcloud", 0))
	var lc_amt := 0.0
	if lc_i == 1: lc_amt = 0.5
	elif lc_i == 2: lc_amt = 1.0
	sky_mat.set_shader_parameter("low_cloud", lc_amt)
	sky_mat.set_shader_parameter("low_cloud_h", float(hud.weather.get("lowcloud_h", 300.0)))
	var wd := wind.toward()
	sky_mat.set_shader_parameter("cam_pos", cam.global_position)   # the volumetric clouds need the camera height
	sky_mat.set_shader_parameter("cloud_quality", _sky_quality)
	# fog: thicker and greyer in rain, snow and mist
	var grey := clampf(float(c["haze"]) * 0.9 + float(c["fog"]) * 0.4, 0.0, 1.0)
	env.fog_density = 0.00012 * float(c["fogd"])
	# low sun: warm golden haze in the air and cool blue light in the shade, the way a real evening looks
	var warm := (1.0 - smoothstep(3.0, 24.0, _sun_el)) * smoothstep(-2.0, 3.0, _sun_el) * (1.0 - 0.7 * float(c["cover"]))
	var fog_c := Color(0.62, 0.70, 0.80).lerp(Color(0.66, 0.68, 0.72), grey).lerp(Color(1.0, 0.66, 0.40), warm * 0.75)
	env.fog_light_color = fog_c * lerpf(0.03 + 0.12 * moon_f, 1.0, _daylight)
	sky_mat.set_shader_parameter("haze_col", Vector3(env.fog_light_color.r, env.fog_light_color.g, env.fog_light_color.b))   # sky horizon shares the fog colour (g_haze)
	sky_mat.set_shader_parameter("aurora", _aurora)   # sky A1: aurora strength (set by the aurora test token)
	RenderingServer.global_shader_parameter_set("g_water", Vector4(env.fog_light_color.r, env.fog_light_color.g, env.fog_light_color.b, 1.0 - 0.35 * grey))   # session B: the lake mirrors this
	env.fog_sun_scatter = 0.35 + 0.5 * warm
	env.ambient_light_color = Color(0.78, 0.82, 0.62).lerp(Color(0.52, 0.62, 0.95), warm * 0.8)
	sun.light_energy = maxf(sun.light_energy, 0.0) * (1.0 + 0.5 * warm)
	env.fog_sky_affect = 0.05 + 0.6 * float(c["fog"])
	env.fog_height_density = 0.0003 * float(c["fogd"])
	# inside the low cloud the view goes bright soft white-grey with a short visibility, blended over 20 m
	var lc_world := 76.0 + float(hud.weather.get("lowcloud_h", 300.0))   # valley floor (Lake.LEVEL) plus the slider
	var lc_thick := lerpf(70.0, 170.0, lc_amt)
	_low_cloud_inside = clampf((lc_thick * 0.5 - absf(cam.global_position.y - lc_world)) / 20.0, 0.0, 1.0)
	if _low_cloud_inside > 0.0:
		env.fog_density = lerpf(env.fog_density, 0.055, _low_cloud_inside)   # about 20 to 60 m visibility
		env.fog_light_color = env.fog_light_color.lerp(Color(0.90, 0.92, 0.95), _low_cloud_inside)
		env.fog_sun_scatter = 0.15
	# wind follows the condition
	wind.speed = _base_wind * float(c["wind"])
	var cloud_drift := Vector2(wd.x, wd.z) * (2.0 + 2.4 * wind.speed)   # world m/s: the clouds and their shadows move together
	sky_mat.set_shader_parameter("drift", cloud_drift)
	RenderingServer.global_shader_parameter_set("g_cloud", Vector4(float(c["cover"]), cloud_drift.x, cloud_drift.y, sim_time))
	var sun_off := Vector2(_sun_dir.x, _sun_dir.z) * clampf(1500.0 / maxf(_sun_dir.y, 0.1), 0.0, 3000.0)   # cloud base 1500 m, matches sky.gdshader CBASE
	RenderingServer.global_shader_parameter_set("g_csun", Vector4(sun_off.x, sun_off.y, 0.0, 0.0))
	wind.gust = clampf(_base_gust + (0.35 if wx.kind == WeatherSystem.Kind.STORM else 0.0), 0.0, 1.0)
	# precipitation
	var rain := float(c["rain"])
	var snow_p := float(c["snow"])
	rain_fx.emitting = rain > 0.03
	# water collects on the lens in rain and dries slowly once it stops
	_lens_water = move_toward(_lens_water, clampf(rain * 1.0, 0.0, 0.55) if rain > 0.03 else 0.0, delta * (0.25 if rain > 0.03 else 0.03))
	sensor.rain_lens = (_lens_water * hud.lens_rain_k + _low_cloud_inside * 0.18) if not chase else 0.0
	# the air the lens moves through: the drone's velocity against the wind, in the camera's own axes (the drops follow it)
	sensor.lens_wash = clampf(_wash_now * 1.6 + 0.3 * fc.thrust_fraction(), 0.0, 1.0) if (quad.armed and not quad.motor_cut) else 0.0
	var rel_air: Vector3 = cam.global_transform.basis.inverse() * (quad.velocity() - _wind_now)
	sensor.lens_air = Vector3(-rel_air.x, -rel_air.y, maxf(-rel_air.z, 0.0)) if _air_test == Vector3.ZERO else _air_test
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
	_home_charging = false
	_charge_t = 0.0
	_charge_done = false
	if hud and hud.minimap: hud.minimap.clear_trail()
	var y := terrain.height(launch_pos.x, launch_pos.y) + 0.04
	quad.reset(launch_pos.x, y, launch_pos.y, deg_to_rad(launch_yaw))
	if airframe_id == "wing":
		# hand launch: 3 m up, 10 m/s along the nose, nose up 10 degrees; the controller climbs gently for 3 s
		# ground roll: on the grass, nose level, no speed; the pilot throttles up to lift off
		var hd := deg_to_rad(launch_yaw)
		if hud and hud.plane_launch == 1:
			var ql := Quaternion(Vector3.UP, hd)
			quad.s[1] = terrain.height(launch_pos.x, launch_pos.y) + 0.2
			quad.s[6] = ql.x; quad.s[7] = ql.y; quad.s[8] = ql.z; quad.s[9] = ql.w
			quad.s[3] = 0.0; quad.s[4] = 0.0; quad.s[5] = 0.0
		else:
			var ql := Quaternion(Vector3.UP, hd) * Quaternion(Vector3.RIGHT, deg_to_rad(10.0))
			quad.s[1] = terrain.height(launch_pos.x, launch_pos.y) + 3.0
			quad.s[6] = ql.x; quad.s[7] = ql.y; quad.s[8] = ql.z; quad.s[9] = ql.w
			var fwd := ql * Vector3(0, 0, -1)
			quad.s[3] = fwd.x * 10.0; quad.s[4] = fwd.y * 10.0; quad.s[5] = fwd.z * 10.0
	fc.reset_state(); fc.mode = hud.mode if hud else "N"; fc.heading = deg_to_rad(launch_yaw)
	if airframe_id == "wing" and hud and hud.plane_launch == 1:
		fc.set_ground_roll()
	_cam_yaw = deg_to_rad(launch_yaw)
	_apply_pose()
	drone_node.reset_physics_interpolation()
	if hud: hud.show_crash("")

func switch_drone(id: String) -> void:
	airframe_id = id
	af = inventory.apply_airframe(Airframes.make(id), id) if inventory != null else Airframes.make(id)
	quad.set_airframe(af)
	fc.set_airframe(af)
	drone_view.build(af)
	_after_drone_built()
	audio.set_arm(float(af["armD"]))
	if landing: landing.set_drone_name(str(af["name"]))
	hud.set_airframe(id)
	hud.show_gimbal(af["hasGimbal"])
	spawn()

## The map app's travel button. The drone has to be on the ground; the kit is then driven to the new site and unpacked.
func travel_to_site(site_id: String) -> void:
	if launch_sites == null or quad == null:
		return
	var p: Vector3 = quad.position()
	var agl := p.y - terrain.height(p.x, p.z)
	if quad.armed and agl > 0.4:
		if phone_os != null and phone_os._map_app != null:
			phone_os._map_app.set_status("Land the drone before driving to a new launch site.", true)
		return
	if not launch_sites.set_active(site_id):
		return
	var s := launch_sites.current()
	launch_pos = s["pos"]
	launch_yaw = float(s["yaw"])
	hud.minimap.home = launch_pos
	spawn()
	if phone_os != null:
		phone_os.close()
	hud.toast("Drove the kit to " + str(s["name"]) + ". Ready at the new launch site.")
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
	var p: Vector3 = quad.position()
	var agl := p.y - terrain.height(p.x, p.z)
	st = _autopilot_sticks(st, p, agl)
	quad.wind = wind.sample(p, maxf(agl, 0.05), sim_time)
	wind.drive(quad, terrain, p, maxf(agl, 0.05), SUBSTEPS * DT)   # wind lane: gusts the controller must fight
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
	if phone_os != null and quad != null:
		phone_os.set_battery(quad.battery.soc)   # the tablet's battery dial reads the drone pack
	if not paused:
		_update_home_recharge(delta)   # after a Return to Home landing: props stopped, battery charging
	_check_home_landing()
	if jobs != null and not paused:
		jobs.tick(delta)   # session B: the channel keeps earning views and money between flights
	if guide != null and not paused:
		guide.update(delta)   # session B: Kit story-mode tips and nudges
	if traffic != null and hud != null:
		traffic.update(delta, float(hud.weather.get("hour", 12.0)), paused)   # session B: life on the roads
	if roads != null and hud != null:
		roads.set_wetness(float(hud.weather.get("wet", 0.0)))   # session B: rain darkens and polishes the asphalt
	if crew != null and not paused:
		crew.update(delta)   # session B: the crew react to weather, storms, uploads and discoveries
	if story != null and not paused:
		story.update(delta)  # session B: the Lake Car story, in game hours
	if unknown_thread != null and not paused:
		unknown_thread.update(delta)   # session B: the unknown account's direct messages
	if wildlife != null and not paused:
		wildlife.update(delta, quad.position())   # session B: the night pasture thermal favour
	if finale != null and not paused:
		finale.update(delta, quad.position())   # session B: the last flight, the storm search and the ending
	if director != null:
		director.update(delta)   # session B: the act and next step for the Casebook
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
		if not sensor.simple: cam_shake.apply(cam, delta, wind.turb, wind.burst, quad.rates(), af["hasGimbal"])   # wind lane: buffeting (Full camera only)
	drone_view.visible = true
	if _landing_on:
		_landing_t += delta
		cam.global_transform = Landing.orbit(pos, _landing_t, terrain.height(pos.x, pos.z), float(af["armD"]))
		cam.fov = 55.0
	drone_view.set_fpv(not chase and not _landing_on)
	if sensor.simple and not chase and not _landing_on: cam.fov = 52.0
	# the shadow follows the light that is up: the sun by day, the moon (much fainter) by night
	var lit_dir := _sun_dir
	var lit_k := float(wx.cur["sun"]) * smoothstep(0.0, 6.0, _sun_el)
	if _sun_el < 3.0 and _moon_el > 3.0:
		lit_dir = _moon_dir; lit_k = 0.3 * float(wx.cur["sun"]) * _moon_illum * (1.0 - _daylight)
	var head_y := atan2(-(q * Vector3(0, 0, -1)).x, -(q * Vector3(0, 0, -1)).z)
	drone_shadow.update(pos, head_y, lit_dir, lit_k)
	drone_view.update_props(quad.s, sim_time, quad.armed and not quad.motor_cut)
	# precipitation follows the camera
	snow_fx.global_position = cam.global_position + Vector3(0, 12, 0)
	rain_fx.global_position = cam.global_position + Vector3(0, 16, 0)
	var wdir := wind.toward() * wind.speed * 0.8
	snow_mat.direction = Vector3(wdir.x, -1.0, wdir.z).normalized()
	_apply_weather_state(delta)
	_update_sensor_and_osd(delta)
	ambient.update(delta, cam, wind.toward() * wind.speed, wind.gust, _sun_el, _sun_dir, _daylight, wx, quad.position(), quad.armed and not quad.motor_cut, _wash_now, float(af["armD"]))

	if fireworks: fireworks.update(delta, cam, quad.position(), _sun_el, _clock, _doy, paused)   # session B: the show clock
	if birds: birds.update(delta, cam, quad.position(), wind, wx, _sun_el, _daylight, _doy, paused)   # session B: the flocks
	if weather_events: weather_events.update(delta, cam, quad.position(), quad.velocity(), _sun_el, _daylight, paused)   # session B: events and courses
	if phone_notes: phone_notes.update(delta, paused)   # session B: the DroneBudz notification bundle
	if world_life: world_life.update(delta, quad.position(), paused)   # session B: mill turning and place discovery

func _unhandled_key_input(event: InputEvent) -> void:
	if not _loaded: return
	if not (event is InputEventKey and event.pressed and not event.echo): return
	match event.keycode:
		KEY_MINUS: sensor.ev_comp = clampf(sensor.ev_comp - 0.33, -3.0, 3.0)
		KEY_EQUAL: sensor.ev_comp = clampf(sensor.ev_comp + 0.33, -3.0, 3.0)
		KEY_L: hud.toggle_lens()
		KEY_V: hud.listening = (hud.listening + 1) % 3; audio.set_perspective(hud.listening); hud.toast("Sound: " + audio.perspective_name())
		KEY_H: osd.show_osd = not osd.show_osd
		KEY_N: phone_notes.toggle_shade()   # session B: open or close the phone notification centre
		KEY_TAB: if phone_os != null: phone_os.toggle()   # session B: the in-game phone home screen
		KEY_G: if hud.paused: photo_library.toggle()   # session B: photo gallery from the menu
		KEY_J: if hud.paused: jobs.toggle()   # session B: DroneBudz jobs page from the menu
		KEY_T:   # session B: thermal camera, bought on Facade and taught in the night pasture
			if inventory != null and inventory.has_addon("thermal_camera") and thermal != null:
				thermal.install()
				thermal.toggle()
				hud.toast("Thermal camera " + ("on" if thermal.is_on() else "off"))
			else:
				hud.toast("No thermal camera. Buy one on Facade, then try Riley's night pasture.", true)
		KEY_K:   # session B: night vision add-on from Facade
			if inventory != null and inventory.has_addon("night_vision") and night_vision != null:
				night_vision.toggle()
				hud.toast("Night vision " + ("on" if night_vision.is_on() else "off"))
			else:
				hud.toast("No night vision module. Facade has one on the board.")
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
		if c.begins_with("look"): sensor.look = int(c.substr(4))   # camera A3 stage 1.2 test hook: colour look 0/1/2
		if c == "nobloom": sensor.bloom_on = false   # camera A3 stage 1.1 test hook: bloom off for the A/B
		if c == "armed": quad.armed = true
		if c == "landing": _show_landing()
		if c == "landingfly":
			_show_landing()
			for i in 40: await get_tree().process_frame
			_start_flight()
		if c.begins_with("air"):
			var av := c.substr(3).split("_")
			if av.size() == 3: _air_test = Vector3(float(av[0]), float(av[1]), float(av[2]))
		if c == "simple": hud.simple_on = true; _apply_simple(true)
		if c.begins_with("clock"):     # test hook: freeze the clock at that hour (clock7.5), on the date picked with date1..4
			hud.weather["hour"] = float(c.substr(5)); hud.weather["clock_mode"] = 1; hud.weather["clock_speed"] = 2; apply_weather(hud.weather, true); print("sun el ", snappedf(_sun_el, 0.1), " az ", snappedf(_sun_az, 0.1), " moon el ", snappedf(_moon_el, 0.1), " illum ", snappedf(_moon_illum, 0.01), " dir ", _moon_dir)
		if c.begins_with("date"):
			hud.weather["date"] = int(c.substr(4)); apply_weather(hud.weather, true)
		if c == "light": drone_light.visible = true
		if c.begins_with("cd"): _chase_d = float(c.substr(2))
		if c == "climb":
			_auto_climb = true
		if c.begins_with("at"):
			var v := c.substr(2).split("_")   # at<x>_<y_above_ground>_<z>_<yaw_deg>_<gimbal_deg>
			var px := float(v[0]); var pz := float(v[2])
			var py := terrain.height(px, pz) + float(v[1])
			quad.reset(px, py, pz, deg_to_rad(float(v[3])))
			if airframe_id == "wing":
				quad.s[13] = float(af["omegaMax"]) * 0.6
				quad.cmd[0] = 0.5; quad.cmd[1] = 0.0; quad.cmd[2] = 0.0; quad.cmd[3] = 0.0
			else:
				var wh: float = float(af["omegaMax"]) * sqrt(1.0 / float(af["twr"]))
				for i in 4:
					quad.s[13 + i] = wh; quad.cmd[i] = wh
			fc.heading = deg_to_rad(float(v[3])); gimbal_pitch = deg_to_rad(float(v[4]))
			if "facesun" in parts:     # test hook: point the camera straight at the sun
				fc.heading = deg_to_rad(_sun_az + 180.0); gimbal_pitch = deg_to_rad(_sun_el)
				quad.reset(px, py, pz, fc.heading)
			_apply_pose(); drone_node.reset_physics_interpolation()
		if c == "gallery":
			_build_gallery()
		if c.begins_with("menu"):
			hud.set_paused(true); hud._tabs.current_tab = int(c.substr(4))
		if c.begins_with("cloudq"): _sky_quality = int(c.substr(6))   # sky test hook: cloud quality 0 low / 1 medium / 2 high
		if c == "aurora": _aurora = 1.0   # sky A1 test hook: aurora on
		if c == "noaurora": _aurora = 0.0
		if c.begins_with("stormcell"):   # sky test hook: storm cell at x_z (sets the funnel anchor and strength for session B)
			var sv := c.substr(9).split("_")
			RenderingServer.global_shader_parameter_set("g_storm", Vector4(float(sv[0]), float(sv[1]), 1.0, 0.0))
		if c == "stormoff": RenderingServer.global_shader_parameter_set("g_storm", Vector4(0.0, 0.0, 0.0, 0.0))
		if c.begins_with("lowcloudh"): hud.weather["lowcloud_h"] = float(c.substr(10))   # sky test hook: low cloud height above the valley floor
		if c.begins_with("lowcloud") and not c.begins_with("lowcloudh"): hud.weather["lowcloud"] = int(c.substr(8))   # sky test hook: low cloud 0 off / 1 thin / 2 thick
		if c.begins_with("skyto"): hud.weather["sky"] = int(c.substr(5)); hud.weather["intensity"] = 0.8; apply_weather(hud.weather); _auto_climb = true   # sky test hook: smooth transition (no snap)
		if c.begins_with("sky") and not c.begins_with("skyto"):
			hud.weather["sky"] = int(c.substr(3)); hud.weather["intensity"] = 0.8; apply_weather(hud.weather, true); _auto_climb = true
		if c.begins_with("windms"): hud.weather["wind"] = float(c.substr(6)); hud.weather["gust"] = 1.0; apply_weather(hud.weather, true)   # wind lane test hook: menu wind in m/s, gusty
		if c == "hover": _auto_climb = false   # wind lane test hook: hold the hover (put it after sky<n>)
		if c == "nowindfx": wind.struggle = false   # wind lane test hook: wind effects Off
	# session B test hooks: `fireworks<1..3|build|quiet|finale>` starts a show even in daylight and `fwskip<seconds>`
	# jumps the show clock forward, so one screenshot can catch a burst that would take a minute of waiting.
	for c in parts.slice(3):
		if c.begins_with("fireworks"):
			var nm := c.substr(9)
			var fidx := 1
			if nm.begins_with("build"): fidx = 1
			elif nm.begins_with("quiet"): fidx = 2
			elif nm.begins_with("finale"): fidx = 3
			elif nm.is_valid_int(): fidx = int(nm)
			fireworks.force_show(fidx)
		elif c.begins_with("fwskip"):
			fireworks.skip_to(float(c.substr(6)))
		elif c == "fwlaunch":     # dev: one shell rising 240 m ahead, to photograph the launch, smoke trail and burst
			fireworks.test_launch(quad.position(), quad.attitude() * Vector3(0.0, 0.0, -1.0))
		elif c.begins_with("fwbig"):     # dev: one big burst close enough to study its flash on the lens and metering
			fireworks.test_big(int(c.substr(5)), quad.position(), quad.attitude() * Vector3(0.0, 0.0, -1.0))
		elif c == "fwfar":     # dev: one break 1.6 km from the pilot, for the far distance sound and delay
			fireworks.test_far()
		elif c == "waterspout":     # session B dev hook: start a waterspout over the lake
			weather_events.debug_event("waterspout")
		elif c == "tornado":
			weather_events.debug_event("tornado")
		elif c.begins_with("vortexstage"):
			weather_events.debug_stage(int(c.substr(11)))
		elif c == "dustdevil":
			weather_events.debug_event("dustdevil")
		elif c == "storm":          # dev: the B2 thunderstorm cell (the sky storm hooks are session A's)
			weather_events.debug_event("storm")
		elif c == "thermals":
			weather_events.debug_event("thermals")
		elif c == "fogbank":
			weather_events.debug_event("fogbank")
		elif c == "snowsquall":
			weather_events.debug_event("snowsquall")
		elif c == "skyfar":
			weather_events.debug_event("far")
		elif c == "parklife":
			weather_events.debug_event("park")
		elif c.begins_with("course"):
			weather_events.debug_course(int(c.substr(6)))
		elif c == "notesdemo":     # session B dev hook: a bundle of three DroneBudz notifications
			phone_notes.debug_demo()
		elif c == "notesios":
			hud.phone_style = 0
		elif c == "notesandroid":
			hud.phone_style = 1
		elif c == "notesstorm":
			phone_notes.debug_one("storm")
		elif c == "notesshade":     # session B dev hook: fill the notification centre and open it
			phone_notes.debug_shade()
		elif c == "notesshadefold":
			phone_notes.debug_shade(true)
		elif c == "notesempty":
			phone_notes.debug_clear()
		elif c == "farm":     # session B dev hook: look at the old farm and its turning mill from the south
			var fp := world_life.farm_pos
			var fpx := fp.x
			var fpz := fp.z + 120.0
			var fpy := terrain.height(fpx, fpz) + 70.0
			quad.reset(fpx, fpy, fpz, 0.0)
			var whf: float = float(af["omegaMax"]) * sqrt(1.0 / float(af["twr"]))
			for i in 4:
				quad.s[13 + i] = whf
				quad.cmd[i] = whf
			fc.heading = 0.0
			gimbal_pitch = deg_to_rad(-8.0)
			_apply_pose()
		elif c == "phototest":     # session B dev hook: take three photos and open the gallery
			_phototest = true
		elif c == "photodetail":     # session B dev hook: open the newest photo's detail
			_photodetail = true
		elif c == "discoverall":
			world_life.debug_discover_all()
		elif c == "jobsopen":     # session B dev hook: the DroneBudz jobs page
			jobs.open_page()
		elif c == "jobsdemo":     # session B dev hook: accept a job, complete it with the newest photo, open the page
			jobs.debug_demo()
		elif c == "jobfail":      # session B dev hook: pull a job for the failure-state page
			jobs.debug_fail("windmill", "too_close")
		elif c == "jobsreset":    # session B dev hook: clear the pulled-job state
			jobs.debug_clear_failures()
		elif c == "jobsoffer":    # session B dev hook: show one job offer with its requirements
			jobs.debug_offer("windmill")
		elif c == "jobsofferreset":  # session B dev hook: remove the debug offer
			jobs.debug_remove_offer("windmill")
		elif c == "jobsedit":     # session B dev hook: complete and publish the current job with Maya's edit
			jobs.debug_demo()
			var act: Array = jobs.active_list()
			if not act.is_empty():
				jobs.submit(str(act[act.size() - 1]["id"]), true)
			jobs.close_page()
			phone_os.open()
			phone_os._open_app("studio")
		elif c == "roadtest":     # session B dev hook: compare the road collider with the bare terrain
			var rx := 286.0
			var rz := 180.0
			var ox := 250.0
			var oz := 240.0
			if roads != null:
				print("ROADTEST on-road: terrain %.3f surface %.3f delta %.3f" % [terrain.height(rx, rz), roads.surface_height(rx, rz), roads.surface_height(rx, rz) - terrain.height(rx, rz)])
				print("ROADTEST off-road: terrain %.3f surface %.3f delta %.3f" % [terrain.height(ox, oz), roads.surface_height(ox, oz), roads.surface_height(ox, oz) - terrain.height(ox, oz)])
		elif c == "roadland":     # session B dev hook: leave the drone on the highway surface
			var rx := 286.0
			var rz := 180.0
			var ry := roads.surface_height(rx, rz) + 0.01 if roads != null else terrain.height(rx, rz) + 0.01
			quad.reset(rx, ry, rz, deg_to_rad(180.0))
			quad.motor_cut = true
			_cam_yaw = deg_to_rad(180.0)
			_apply_pose()
			print("ROADLAND position %.3f %.3f %.3f, terrain %.3f, surface %.3f, and %.3f m above the surface" % [quad.position().x, quad.position().y, quad.position().z, terrain.height(rx, rz), roads.surface_height(rx, rz) if roads != null else terrain.height(rx, rz), quad.position().y - (roads.surface_height(rx, rz) if roads != null else terrain.height(rx, rz))])
		elif c == "phone":        # session B dev hook: the phone home screen
			phone_os.open()
		elif c == "guidetip":     # session B dev hook: force Kit tip and open the DM
			if guide != null:
				guide.debug_tip("welcome")
			phone_os.open()
			phone_os._open_app("chat")
			phone_os._chat_app.open("guide")
		elif c.begins_with("guidetip="):
			if guide != null:
				guide.debug_tip(c.substr(9))
			phone_os.open()
			phone_os._open_app("chat")
			phone_os._chat_app.open("guide")
		elif c == "phonemap":     # session B dev hook: the valley map app
			phone_os.open()
			phone_os._open_app("map")
		elif c.begins_with("travel="):   # session B dev hook: drive the kit to a launch site
			travel_to_site(c.substr(7))
		elif c == "phonechat":    # session B dev hook: straight into the DroneBudz chat
			phone_os.open()
			phone_os._open_app("chat")
		elif c == "phonestudio":  # session B dev hook: the channel studio app
			phone_os.open()
			phone_os._open_app("studio")
		elif c == "phonerecents": # session B dev hook: the app switcher
			phone_os.open()
			phone_os._show_switcher()
		elif c == "phonestory":   # session B dev hook: finish the first job so chat, money, followers and events are populated
			jobs.debug_demo()
			jobs.submit("lake")
			jobs.close_page()
			phone_os.open()
			phone_os._open_app("chat")
		elif c == "phonejobs":    # session B dev hook: the chat open on the jobs channel
			phone_os.open()
			phone_os._open_app("chat")
			phone_os._chat_app.open("jobs")
		elif c == "vidtube":      # session B dev hook: the VidTube Studio app
			phone_os.open()
			phone_os._open_app("studio")
		elif c == "homelanded":  # session B dev hook: put the drone at home, cut the motors and watch the battery charge
			var hy := terrain.height(home.x, home.y) + 0.04
			quad.reset(home.x, hy, home.y, deg_to_rad(150.0))
			quad.battery.soc = 0.2
			_home_landed()
		elif c == "landingstory": # session B dev hook: the welcome screen in Story mode
			hud.set_story_mode(true)
			_show_landing()
		elif c == "landingsandbox":  # session B dev hook: the welcome screen in Sandbox mode
			hud.set_story_mode(false)
			_show_landing()
		elif c == "storyweather":  # session B dev hook: the Weather settings tab in Story mode
			hud.set_story_mode(true)
			hud.set_paused(true)
			hud.open_tab(2)
		elif c == "sandboxweather":  # session B dev hook: the Weather settings tab in Sandbox mode
			hud.set_story_mode(false)
			hud.set_paused(true)
			hud.open_tab(2)
		elif c == "clipdemo":     # session B dev hook: create three representative rushes and open Studio
			for i in 3:
				clips.add_clip(sensor.capture(), _photo_meta(), 8.0 + float(i) * 4.0)
			phone_os.open()
			phone_os._open_app("studio")
		elif c == "clipeditdemo": # session B dev hook: cut the rushes into a single video
			for i in 2:
				clips.add_clip(sensor.capture(), _photo_meta(), 10.0 + float(i) * 3.0)
			jobs.publish_rushes(true)
			phone_os.open()
			phone_os._open_app("studio")
		elif c == "videodetail": # session B dev hook: the latest published video's detail screen
			phone_os.open()
			phone_os._open_app("studio")
			phone_os._studio_app.refresh()
			phone_os._studio_app._open_video(jobs.last_video())
		elif c == "casebook_evidence":
			phone_os.open()
			phone_os._open_app("casebook")
			phone_os._casebook_app._set_tab("evidence")
		elif c == "casebook_chapters":
			phone_os.open()
			phone_os._open_app("casebook")
			phone_os._casebook_app._set_tab("chapters")
		elif c == "casebook_contacts":
			phone_os.open()
			phone_os._open_app("casebook")
			phone_os._casebook_app._set_tab("contacts")
		elif c == "director":    # session B dev hook: the Casebook with the story director act card
			phone_os.open()
			phone_os._open_app("casebook")
		elif c == "market":      # session B dev hook: the Facade marketplace
			phone_os.open()
			phone_os._open_app("market")
		elif c == "marketkit":   # session B dev hook: the owned kit, with a couple of purchases
			jobs.add_money(1000)
			for iid in ["drone_raptor", "night_vision", "motor_mini", "battery"]:
				inventory.add_purchase(FacadeCatalog.item(str(iid)))
			phone_os.open()
			phone_os._open_app("market")
			phone_os._marketplace_app.debug_tab("kit")
		elif c == "marketcheck":  # session B dev hook: buy one item through the real purchase path
			jobs.add_money(500)
			phone_os.open()
			phone_os._open_app("market")
			phone_os._marketplace_app._buy(FacadeCatalog.item("night_vision"))
			print("marketcheck: money=", jobs.money(), " kit=", inventory.stats())
		elif c == "marketbuy":   # session B dev hook: the market after a Raptor and the night vision have been bought
			jobs.add_money(1000)
			for iid in ["drone_raptor", "night_vision", "motor_raptor"]:
				inventory.add_purchase(FacadeCatalog.item(str(iid)))
			phone_os.open()
			phone_os._open_app("market")
		elif c == "nightvisiondemo":  # session B dev hook: the night vision add-on switched on
			if not inventory.has_addon("night_vision"):
				inventory.add_purchase(FacadeCatalog.item("night_vision"))
			night_vision.set_on(true)
		elif c == "wildlife":       # session B dev hook: the night pasture with the thermal camera fitted
			story.debug_jump(2)
			if not inventory.has_addon("thermal_camera"):
				inventory.add_purchase(FacadeCatalog.item("thermal_camera"))
			thermal.install()
			wildlife.debug_start()
			thermal.set_on(true)
			phone_os.open()
			phone_os._open_app("chat")
			phone_os._chat_app.open("general")
		elif c == "wildlifecomplete":  # session B dev hook: finish the night pasture
			story.debug_jump(2)
			if not inventory.has_addon("thermal_camera"):
				inventory.add_purchase(FacadeCatalog.item("thermal_camera"))
			thermal.install()
			wildlife.debug_complete()
			phone_os.open()
			phone_os._open_app("chat")
			phone_os._chat_app.open("general")
		elif c == "wildlifeworld":    # session B dev hook: the night pasture from the air, thermal fitted
			story.debug_jump(2)
			if not inventory.has_addon("thermal_camera"):
				inventory.add_purchase(FacadeCatalog.item("thermal_camera"))
			thermal.install()
			wildlife.debug_start()
			thermal.set_on(true)
		elif c == "raptorflight":     # session B dev hook: fly the bought Raptor
			if not inventory.owns_drone("raptor"):
				inventory.add_purchase(FacadeCatalog.item("drone_raptor"))
			switch_drone("raptor")
		elif c == "trafficdemo":  # session B dev hook: line the traffic up on the valley highway
			traffic.debug_line_up()
		elif c == "crewdemo":     # session B dev hook: ask every friend once and open the weather channel
			crew.ask("weather", "weather")
			crew.ask("storm", "weather")
			crew.ask("gear", "tech")
			crew.ask("spot", "general")
			crew.ask("jobs", "jobs")
			crew.ask("edit", "clips")
			phone_os.open()
			phone_os._open_app("chat")
			phone_os._chat_app.open("weather")
		elif c == "crewtech":     # session B dev hook: ask Alex about gear
			crew.ask("gear", "tech")
			phone_os.open()
			phone_os._open_app("chat")
			phone_os._chat_app.open("tech")
		elif c == "crewjobs":     # session B dev hook: ask Jo about the board
			crew.ask("jobs", "jobs")
			phone_os.open()
			phone_os._open_app("chat")
			phone_os._chat_app.open("jobs")
		elif c == "casebook":     # session B dev hook: the Casebook app
			phone_os.open()
			phone_os._open_app("casebook")
		elif c == "storystart":   # session B dev hook: start the Lake Car and open the casebook
			story.debug_start()
			phone_os.open()
			phone_os._open_app("casebook")
		elif c == "storytown":    # session B dev hook: start the Lake Car and open #town
			story.debug_start()
			phone_os.open()
			phone_os._open_app("chat")
			phone_os._chat_app.open("town")
		elif c == "storydeliver": # session B dev hook: mark the current evidence delivered
			story.debug_deliver()
			phone_os.open()
			phone_os._open_app("casebook")
		elif c == "storynext":    # session B dev hook: force the waiting chapter to begin
			story.debug_next()
			phone_os.open()
			phone_os._open_app("casebook")
		elif c == "storycamp":    # session B dev hook: jump to the camp chapter
			story.debug_jump(3)
			phone_os.open()
			phone_os._open_app("casebook")
		elif c == "storybus":     # session B dev hook: jump to the bus chapter
			story.debug_jump(4)
			phone_os.open()
			phone_os._open_app("casebook")
		elif c == "storyfinish":  # session B dev hook: finish the case and show the ending choice
			story.debug_run_all()
			phone_os.open()
			phone_os._open_app("casebook")
		elif c == "storypublish": # session B dev hook: finish and publish with Maya's cut
			story.debug_run_all()
			story.make_choice("publish")
			phone_os.open()
			phone_os._open_app("casebook")
		elif c == "unknownstart": # session B dev hook: start the unknown direct message thread
			unknown_thread.debug_start()
			phone_os.open()
			phone_os._open_app("chat")
			phone_os._chat_app.open("unknown")
		elif c == "unknownnext":  # session B dev hook: post the next unknown message
			unknown_thread.debug_next()
			phone_os.open()
			phone_os._open_app("chat")
			phone_os._chat_app.open("unknown")
		elif c == "unknowndoubt": # session B dev hook: jump to the questions about Rennick
			story.debug_run_all()
			unknown_thread.debug_jump(4)
			phone_os.open()
			phone_os._open_app("chat")
			phone_os._chat_app.open("unknown")
		elif c == "unknownfinal": # session B dev hook: the last unknown message after a private ending
			story.debug_run_all()
			story.make_choice("private")
			unknown_thread.debug_jump(5)
			phone_os.open()
			phone_os._open_app("chat")
			phone_os._chat_app.open("unknown")
		elif c == "finalestart":  # session B dev hook: start the ghost reveal and the storm
			finale.debug_start()
			phone_os.open()
			phone_os._open_app("chat")
			phone_os._chat_app.open("town")
		elif c == "finalecabin":  # session B dev hook: the cabin, Wren on foot and thermal on
			finale.debug_cabin()
		elif c == "cabinworld":   # session B dev hook: the cabin and the cruiser in the storm, normal camera
			finale.debug_start()
		elif c == "thermalview":  # session B dev hook: thermal camera on, search still live
			finale.debug_thermal_view()
		elif c == "endingdemo":   # session B dev hook: the fade and the credits
			finale.debug_found()
		elif c == "pikezone":      # session B dev hook: drop into the jammer field
			var jp := Vector2(-260.0, -807.0)
			quad.reset(jp.x, terrain.height(jp.x, jp.y) + 8.0, jp.y, deg_to_rad(0.0))
			_apply_pose()
		elif c == "endingcabin":   # session B dev hook: put the ending at the cabin for review
			var cp: Vector3 = case_objects.cabin_world_pos()
			quad.reset(cp.x, terrain.height(cp.x, cp.z) + 18.0, cp.z, deg_to_rad(200.0))
			_apply_pose()
			finale.debug_found()
			if ending != null:
				ending.debug_time(22.1)
		elif c == "endingwash":   # session B dev hook: the blur and wash before the card
			finale.debug_found()
			if ending != null:
				ending.debug_time(6.0)
		elif c == "endingcard":   # session B dev hook: jump to the end card over the washed world
			finale.debug_found()
			if ending != null:
				ending.debug_time(17.5)
		elif c == "endingfree":   # session B dev hook: jump to the free walk after the card
			finale.debug_found()
			if ending != null:
				ending.debug_time(22.1)
		elif c == "storyprivate": # session B dev hook: finish and keep the story private
			story.debug_run_all()
			story.make_choice("private")
			phone_os.open()
			phone_os._open_app("casebook")
		elif c == "uploaddemo":   # session B dev hook: upload the newest photo straight to VidTube
			var pid := -1
			var meta: Dictionary = {}
			if photo_library.count() > 0:
				var rec: Dictionary = photo_library.photos()[-1]
				pid = int(rec.get("id", -1))
				meta = rec.get("meta", {})
			jobs.upload_photo(pid, meta, false)
			phone_os.open()
			phone_os._open_app("studio")
		elif c == "editdemo":     # session B dev hook: Maya edits the newest photo and publishes it
			if not jobs.editor_friend():
				jobs._editor = true
			var pid2 := -1
			var meta2: Dictionary = {}
			if photo_library.count() > 0:
				var rec2: Dictionary = photo_library.photos()[-1]
				pid2 = int(rec2.get("id", -1))
				meta2 = rec2.get("meta", {})
			jobs.upload_photo(pid2, meta2, true)
			phone_os.open()
			phone_os._open_app("chat")
			phone_os._chat_app.open("clips")
		elif c == "notestorm":
			phone_notes.debug_one("storm")
		elif c == "notetornado":
			phone_notes.debug_one("tornado")
		elif c == "noteshow":
			phone_notes.debug_one("show_start")
		elif c == "fwwall":     # dev: one burst of every type in a row, to judge the shapes
			fireworks.test_wall(quad.position(), quad.attitude() * Vector3(0.0, 0.0, -1.0), quad.attitude() * Vector3(1.0, 0.0, 0.0))
		elif c.begins_with("fwburst"):
			fireworks.test_burst(int(c.substr(7)), quad.position(), quad.attitude() * Vector3(0.0, 0.0, -1.0))
		elif c == "nosmoke":
			fireworks.set_smoke(false)
		elif c == "birdsdemo":     # session B dev hook: birds up close, ignoring night, season and weather
			birds.force_visible(true); birds.debug_near(true)
		elif c == "nobirds":
			birds.enabled = false
		elif c == "birdsmenu":     # session B dev hook: open Display > Graphics so the Birds switch can be photographed
			hud.set_paused(true)
			for b in hud.find_children("*", "Button", true, false):
				if (b as Button).text == "Display":
					(b as Button).pressed.emit()
					break
			await get_tree().process_frame
			for sc in hud.find_children("Display", "ScrollContainer", true, false):
				(sc as ScrollContainer).scroll_vertical = 100000
		elif c.begins_with("dof"):
			hud.dof_mode = int(c.substr(3)); sensor.dof_mode = hud.dof_mode
		elif c == "nowaterfx":     # session B dev hook: the "Water detail" switch Off, for an A/B picture
			RenderingServer.global_shader_parameter_set("g_fx", Vector4(1.0, 1.0, 1.0, 0.0))
		elif c == "fwsmoke":
			fireworks.test_smoke(quad.position(), quad.attitude() * Vector3(0.0, 0.0, -1.0))
		elif c == "fwmenu":
			# press the real menu buttons, so the Weather tab "Fireworks show" wiring is what is being tested
			hud.set_paused(true)
			for b in hud.find_children("*", "Button", true, false):
				var bb := b as Button
				if bb != null and bb.text == "Weather":
					bb.pressed.emit()
					break
			await get_tree().process_frame
			for sc in hud.find_children("Weather", "ScrollContainer", true, false):
				(sc as ScrollContainer).scroll_vertical = 100000
			for b in hud.find_children("*", "Button", true, false):
				var bf := b as Button
				if bf != null and bf.text == "Finale":
					bf.pressed.emit()
					break
	await get_tree().create_timer(0.1).timeout
	for i in frames: await get_tree().process_frame
	if _phototest:     # the frame has rendered by now, so the capture is the picture the player would take
		for k in 3:
			var pimg := sensor.capture()
			if pimg:
				photo_library.capture(pimg, _photo_meta())
		photo_library.open_gallery()
		_phototest = false
		await get_tree().process_frame
		await get_tree().process_frame
	if _photodetail:
		photo_library.open_detail_first()
		_photodetail = false
		await get_tree().process_frame
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved ", path)
	print("fireworks: ", fireworks.stats())
	print("camera: exposure %.2f iso %d shutter 1/%d over %.2f meanlog %.2f burstwash %.3f" % [sensor.exposure, sensor.iso_shown, int(round(1.0 / maxf(sensor.shutter_shown, 1e-6))), sensor._over, sensor._mean_log, sensor._burst_wash])
	print("birds: ", birds.stats())
	print("weather events: ", weather_events.stats())
	print("phone notes: ", phone_notes.stats())
	print("world life: ", world_life.stats())
	print("photo library: ", photo_library.stats())
	print("jobs: ", jobs.stats())
	print("phone: ", phone_os.stats())
	print("channel: ", {"views": jobs.views(), "videos": jobs.videos().size(), "editor": jobs.editor_friend()})
	print("roads: ", roads.stats())
	print("road signs: ", road_signs.stats())
	print("landmark signs: ", landmark_signs.stats())
	print("intersection signals: ", intersection_signals.stats())
	print("boat launch: placed at ", CaseObjects.BOAT_LAUNCH_SPOT)
	print("cabin track: placed at ", CaseObjects.CABIN_SPOT)
	print("farmland: ", farmland.stats())
	print("traffic: ", traffic.stats())
	print("crew: ", crew.stats())
	print("story: ", story.stats())
	print("unknown: ", unknown_thread.stats())
	print("kit: ", inventory.stats())
	print("clips: ", clips.stats())
	print("wildlife: ", wildlife.stats())
	print("director: ", director.stats())
	print("bird voices played: ", audio.voices_played())
	var peaks := []
	for bn in ["Master", "Ground", "Onboard", "Ambient", "Birds", "FireworksG", "FireworksM"]:
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
	var p: Vector3 = quad.position()
	print("selftest: alt %.1f m over ground, crashed=%s, sim_time=%.2f s, wall=%d ms" % [p.y - terrain.height(p.x, p.z), quad.crashed, sim_time, Time.get_ticks_msec() - t0])
	print("selftest: wind %.2f m/s, battery %.0f%%" % [_wind_now.length(), quad.battery.soc * 100.0])
	var peaks := []
	for bn in ["Master", "Ground", "Onboard", "Ambient", "Birds", "FireworksG", "FireworksM"]:
		var bi := AudioServer.get_bus_index(bn)
		peaks.append("%s %.0f dB" % [bn, AudioServer.get_bus_peak_volume_left_db(bi, 0)])
	print("selftest: audio peaks ", ", ".join(peaks))
	print("selftest: motor3d playing=", audio._motor_g[0].playing, " bus=", audio._motor_g[0].bus, " vol=", audio._motor_g[0].volume_db, " pitch=", audio._motor_g[0].pitch_scale, " in_tree=", audio._motor_g[0].is_inside_tree(), " dist=", audio._motor_g[0].global_position.distance_to(audio._listener.global_position), " | 2d playing=", audio._motor_o[0].playing, " vol=", audio._motor_o[0].volume_db)
	get_tree().quit()

var _gallery_cam := false
var _phototest := false
var _photodetail := false

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
	var dp: Vector3 = quad.position()
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
	sensor.drone_speed = quad.velocity().length()   # forward-motion blur (camera A3 stage 1.5)
	# video link: free-space loss with distance, plus a penalty when the terrain blocks the line of sight
	var dpos: Vector3 = quad.position()
	var home_p := Vector3(home.x, terrain.height(home.x, home.y) + 1.6, home.y)
	var dist := dpos.distance_to(home_p)
	var dbm := -45.0 - 20.0 * log(maxf(dist, 10.0) / 10.0) / log(10.0)
	if not _terrain_clear(home_p, dpos): dbm -= 28.0
	# weather: heavy rain and storms degrade the link a little (moderate, never fatal)
	dbm -= float(wx.cur["rain"]) * 14.0 + (14.0 if wx.kind == WeatherSystem.Kind.STORM else 0.0)
	_rf_dbm += (dbm - _rf_dbm) * clampf(delta * 3.0, 0.0, 1.0)
	var bars := 5 if _rf_dbm > -70.0 else (4 if _rf_dbm > -80.0 else (3 if _rf_dbm > -88.0 else (2 if _rf_dbm > -95.0 else 1)))
	var rf_bad := smoothstep(-88.0, -99.0, _rf_dbm)   # 5 km link: blocks start around 1.4 km, full around 5 km
	var mean_om: float = (quad.s[13] + quad.s[14] + quad.s[15] + quad.s[16]) * 0.25
	var vib := clampf(0.12 + quad.vrs * 0.8 + fc.thrust_fraction() * 0.25 + quad.ang_accel.length() / 600.0, 0.0, 1.0)
	if not chase: vib = clampf(vib + cam_shake.vibration, 0.0, 1.0)   # wind lane: buffeting shakes the sensor too
	sensor.update_focus(delta, terrain, world, airframe_id, chase or _landing_on, quad.position())
	sensor.process_frame(delta, sim_time, ang, vib, mean_om / TAU * float(af["nBlades"]), rf_bad)
	osd.frame = sensor.frame_rect()
	hud.layout_for(osd.frame)
	# telemetry for the display
	var cb := cam.global_transform.basis
	var fwd := -cb.z
	var vcam: Vector3 = cb.inverse() * quad.velocity()
	var agl := dpos.y - terrain.height(dpos.x, dpos.z)
	var dfwd: Vector3 = quad.attitude() * Vector3(0, 0, -1)
	# plane (wing) airspeed for the OSD; -1 on the quads (they show ground speed instead) -- session A plane branch
	var _plane_as := -1.0
	if quad.get("airspeed") != null: _plane_as = float(quad.get("airspeed"))
	osd.t = {
		"mode": fc.mode, "sats": 14 + (3 if agl > 2.0 else 0), "rfDbm": _rf_dbm, "rfBars": bars,
		"battPct": quad.battery.soc * 100.0, "cellV": quad.battery.cell_v(), "battA": quad.battery.current,
		"iso": sensor.iso_shown, "shutter": sensor.shutter_shown, "ev": sensor.ev_comp, "wb": int(round(sensor.wb_kelvin / 100.0)) * 100,
		"pitch": asin(clampf(fwd.y, -1.0, 1.0)), "roll": -asin(clampf(cb.x.y, -1.0, 1.0)),
		"heading": atan2(dfwd.x, -dfwd.z), "velBody": vcam, "fov": cam.fov, "aglM": agl, "mslM": dpos.y,
		"gs": sqrt(quad.s[3] * quad.s[3] + quad.s[5] * quad.s[5]), "vs": quad.s[4], "as": _plane_as,
		"homeDist": sqrt((dpos.x - home.x) * (dpos.x - home.x) + (dpos.z - home.y) * (dpos.z - home.y)),
		"gimbalDeg": rad_to_deg(gimbal_pitch) if af["hasGimbal"] else rad_to_deg(float(af["camTilt"])),
		"histogram": sensor.histogram, "lensName": sensor.lens_info()["name"], "airframe": af["name"],
		"audio": audio.perspective_name() if audio.enabled else "off", "fps": int(_fps), "crashed": quad.crash_reason if (quad.crashed or not quad.armed) else "",
		"armed": quad.armed and not quad.motor_cut, "touch": DisplayServer.is_touchscreen_available(), "mission": [],
		"windMs": _wind_now.length(), "windLevel": "", "homeBearing": atan2(home.x - dpos.x, -(home.y - dpos.z)), "stopHit": 0.0, "aero": "",
	}
	hud.show_crash(osd.t["crashed"])
	var wmsg := wind.feedback(delta, airframe_id, _wind_now.length(), fc.losing_hold(), osd.t)   # wind lane: strong-wind warning
	if wmsg != "" and quad.armed: hud.toast(wmsg, true)
	audio.strain_in(wind.turb, wind.burst, float(af["omegaMax"]), float(af["twr"]), int(af["nBlades"]))   # wind lane: motor strain sound
	var om := PackedFloat64Array([quad.s[13], quad.s[14], quad.s[15], quad.s[16]])
	var cov_f := terrain.cover_at(dpos.x, dpos.z).x
	var thrust_now := 0.0 if quad.motor_cut else clampf(fc.thrust_fraction() ** 0.5, 0.0, 1.0)
	audio.update({"omega": om, "blades": af["nBlades"], "thrust": thrust_now, "vz": quad.s[4], "jerk": quad.ang_accel.length(), "vrs": quad.vrs,
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
		var was_home_land := autopilot.state == AutoPilot.State.RTH_LAND
		var cmd := autopilot.update(p, quad.velocity(), fc.heading, agl, launch_pos, float(lim["vH"]), float(lim["vUp"]))
		if was_home_land and autopilot.state == AutoPilot.State.NONE and autopilot.message == "Landed":
			_home_landed()
			autopilot.message = ""   # the home landing has its own notice
		var rth := autopilot.state in [AutoPilot.State.RTH_CLIMB, AutoPilot.State.RTH_FLY, AutoPilot.State.RTH_LAND]
		if rth and maxf(maxf(absf(st.x), absf(st.y)), maxf(absf(st.z), absf(st.w))) > 0.25:
			autopilot.cancel("Return to home cancelled")
		elif cmd.is_finite():
			st = cmd
	if autopilot.message != "":
		hud.toast(autopilot.message); autopilot.message = ""
	return st

func _takeoff_or_land() -> void:
	var p: Vector3 = quad.position()
	var agl := p.y - terrain.height(p.x, p.z)
	if quad.crashed or not quad.armed:
		hud.toast("Reset the drone first", true); return
	if autopilot.state == AutoPilot.State.TAKEOFF or autopilot.state == AutoPilot.State.LAND:
		autopilot.cancel("Cancelled"); return
	if _home_charging:
		hud.toast("Recharging at home. " + ("Ready in a moment." if not _charge_done else ""), false)
		return
	if agl > 0.4: autopilot.start_landing()
	else:
		# a new mission starts from a charged, motor-off drone at home
		quad.motor_cut = false
		_charge_done = false
		autopilot.start_takeoff()
	if fc.mode == "M": hud.set_mode("N")

func _toggle_rth() -> void:
	var p: Vector3 = quad.position()
	var agl := p.y - terrain.height(p.x, p.z)
	if quad.crashed or not quad.armed:
		hud.toast("Reset the drone first", true); return
	if autopilot.state in [AutoPilot.State.RTH_CLIMB, AutoPilot.State.RTH_FLY, AutoPilot.State.RTH_LAND]:
		autopilot.cancel("Return to home cancelled"); hud.toast("Return to home cancelled"); return
	if agl < 0.4:
		hud.toast("Take off first", true); return
	if fc.mode == "M": hud.set_mode("N")
	autopilot.start_rth(agl)

func _make_end_marker() -> void:
	if _end_marker != null:
		return
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.025
	mesh.bottom_radius = 0.055
	mesh.height = 3.2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.78, 0.42, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.70, 0.30)
	mat.emission_energy_multiplier = 1.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_end_marker = MeshInstance3D.new()
	_end_marker.mesh = mesh
	_end_marker.material_override = mat
	_end_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_end_marker.visible = false
	add_child(_end_marker)
## The Pike ridge put the drone back at the launch site. Nothing is permanently lost; the flight can be tried again.
func _on_anti_return(reason: String) -> void:
	if end_sequence or end_walk:
		return
	match reason:
		"jammer":
			hud.toast("Harlan Pike's jammer dropped the link. The drone returned to " + launch_sites.name() + ".", true)
		"shotgun":
			hud.toast("Pike fired on the drone. It returned to " + launch_sites.name() + ". Stay high and keep moving.", true)
		_:
			hud.toast("A Pike hunter drone struck the airframe. The drone returned to " + launch_sites.name() + ". Fly faster.", true)
	spawn()
# ------------------------------------------------------------------ the end card and the free walk
func _on_ending_began() -> void:
	end_sequence = true
	end_walk = false
	if quad != null:
		quad.motor_cut = true
		quad.armed = false
		quad.cmd.fill(0.0)
	if phone_os != null:
		phone_os.close()
	if hud != null:
		hud.visible = false
	if osd != null:
		osd.visible = false
	if phone_notes != null:
		phone_notes.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if story != null:
		story.mark_completed()

func _on_ending_free() -> void:
	end_sequence = false
	end_walk = true
	if sensor != null:
		sensor.set_cinematic_blur(0.0)
		sensor.set_focus_overlay(false)
	if quad != null:
		var fwd: Vector3 = quad.attitude() * Vector3(0.0, 0.0, -1.0)
		_end_yaw = atan2(-fwd.x, -fwd.z)
		# the drone is put down at the place the story ended, so the walk starts around a real object
		var p: Vector3 = quad.position()
		quad.reset(p.x, terrain.height(p.x, p.z) + 0.3, p.z, _end_yaw)
		quad.armed = false
		quad.motor_cut = true
		_apply_pose()
		var back := Vector3(sin(_end_yaw), 0.0, cos(_end_yaw))
		_end_cam_pos = quad.position() + back * 4.5
		_end_cam_pos.y = terrain.height(_end_cam_pos.x, _end_cam_pos.z) + 1.7
		var to_drone: Vector3 = (quad.position() + Vector3(0.0, 0.6, 0.0) - _end_cam_pos).normalized()
		_end_yaw = atan2(-to_drone.x, -to_drone.z)
		_end_pitch = asin(clampf(to_drone.y, -0.95, 0.95))
		print("ENDFREE cam ", _end_cam_pos, " drone ", quad.position(), " yaw ", _end_yaw, " pitch ", _end_pitch, " visible ", drone_view.visible)
		print("ENDFREE node ", drone_node.global_position, " node_visible ", drone_node.visible, " view_visible ", drone_view.visible, " scale ", drone_view.scale)
	if hud != null:
		hud.visible = false
	if osd != null:
		osd.visible = false
	if phone_notes != null:
		phone_notes.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _update_end_walk(delta: float) -> void:
	var basis := Basis(Vector3.UP, _end_yaw)
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		dir -= basis.z
	if Input.is_key_pressed(KEY_S):
		dir += basis.z
	if Input.is_key_pressed(KEY_A):
		dir -= basis.x
	if Input.is_key_pressed(KEY_D):
		dir += basis.x
	if dir.length_squared() > 0.0:
		_end_cam_pos += dir.normalized() * 4.2 * delta
	var ground := terrain.height(_end_cam_pos.x, _end_cam_pos.z) + 1.7
	_end_cam_pos.y = maxf(_end_cam_pos.y, ground)
	var eye := Basis(Vector3.UP, _end_yaw) * Basis(Vector3.RIGHT, _end_pitch)
	cam.global_transform = Transform3D(eye, _end_cam_pos)
	cam.fov = 68.0
	if drone_view != null:
		drone_view.visible = true
		drone_view.set_fpv(false)

func _try_end_click() -> void:
	if quad == null or cam == null:
		return
	var p: Vector3 = quad.position() + Vector3(0.0, 0.55, 0.0)
	if cam.is_position_behind(p):
		return
	var sp := cam.unproject_position(p)
	var centre := get_viewport().get_visible_rect().size * 0.5
	if sp.distance_to(centre) < 105.0:
		_resume_after_ending()

func _resume_after_ending() -> void:
	end_walk = false
	end_sequence = false
	if ending != null:
		ending.hide_prompt()
	if quad != null:
		var p: Vector3 = quad.position()
		var gy := terrain.height(p.x, p.z) + 0.25
		quad.reset(p.x, gy, p.z, _end_yaw)
		quad.armed = true
		quad.motor_cut = false
		quad.crashed = false
		quad.crash_reason = ""
		quad.cmd.fill(0.0)
		if fc != null:
			fc.reset_state()
			fc.heading = _end_yaw
		_cam_yaw = _end_yaw
		_apply_pose()
		drone_node.reset_physics_interpolation()
	if sensor != null:
		sensor.set_focus_overlay(true)
	if hud != null:
		hud.visible = true
		hud.toast("Back in the air. The valley is open.")
	if phone_notes != null:
		phone_notes.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
	if not end_walk:
		return
	if event is InputEventMouseMotion:
		_end_yaw -= event.relative.x * 0.0035
		_end_pitch = clampf(_end_pitch - event.relative.y * 0.0025, -1.15, 1.15)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_end_click()
## The RTH landing finished at home: cut the motors and start the battery charging for the next mission.
func _home_landed() -> void:
	if _home_charging:
		return
	quad.motor_cut = true
	quad.cmd.fill(0.0)
	_home_charging = true
	_charge_t = 0.0
	_charge_done = false
	if hud != null:
		hud.toast("At the launch site. Motors off. Recharging for the next flight.")

## Fallback for the RTH-LAND to NONE transition, in case a frame misses the autopilot message.
func _check_home_landing() -> void:
	var ap_now := autopilot.state
	if _prev_auto_state == AutoPilot.State.RTH_LAND and ap_now == AutoPilot.State.NONE and not _home_charging and quad != null:
		var p: Vector3 = quad.position()
		if p.y - terrain.height(p.x, p.z) < 0.35:
			_home_landed()
	_prev_auto_state = ap_now

## While the drone sits at home with the motors cut, bring the battery back up over a few seconds.
func _update_home_recharge(delta: float) -> void:
	if not _home_charging:
		return
	if quad == null or quad.crashed:
		_home_charging = false
		return
	var p: Vector3 = quad.position()
	var agl := p.y - terrain.height(p.x, p.z)
	if agl > 0.35:
		_home_charging = false
		return
	_charge_t += delta
	quad.battery.soc = clampf(quad.battery.soc + delta / RECHARGE_SECONDS, 0.0, 1.0)
	if quad.battery.soc >= 0.999:
		quad.battery.soc = 1.0
		_home_charging = false
		_charge_done = true
		quad.battery.update(0.0, 0.0)
		if hud != null:
			hud.toast("Battery full. Ready for the next flight.")

## A short duration for the HUD and the clip toast.
func _clip_time(sec: float) -> String:
	return "%02d:%02d" % [int(sec) / 60, int(sec) % 60]

## The shutter: a photo saves the finished video frame; in video mode it starts and stops a recording indicator.
func _shutter_pressed() -> void:
	if hud.video_mode:
		if not recording:
			recording = true
			_rec_time = 0.0
			hud._shutter.recording = true
			hud._shutter.queue_redraw()
			hud.toast("Recording clip. Stop to save a representative thumbnail, not a video file.")
		else:
			recording = false
			_rec_time = maxf(_rec_time, 0.4)
			var dur := _rec_time
			hud._shutter.recording = false
			hud._shutter.queue_redraw()
			var img := sensor.capture()
			var rec: Dictionary = {}
			if clips != null:
				rec = clips.add_clip(img, _photo_meta(), dur)
			if rec.is_empty():
				hud.toast("Clip could not be saved", true)
			else:
				hud.toast("Clip saved: %s  ·  VidTube Studio > Rushes" % _clip_time(dur))
				if phone_notes != null:
					phone_notes.post_text("VidTube", "Clip saved", "A %s clip is waiting in VidTube Studio. Maya can cut the rushes into a video." % _clip_time(dur), 0)
			_rec_time = 0.0
		return
	var img := sensor.capture()
	hud.flash_photo()
	if img == null:
		hud.toast("Photo taken"); return
	# session B: the photo goes into the in-game gallery with its metadata. Nothing is written to the player's
	# Downloads or Pictures; Export copy in the gallery is the only way a photo leaves the game.
	if photo_library != null:
		photo_library.capture(img, _photo_meta())
	else:
		hud.toast("Photo taken")

## The facts a photo carries into the gallery and, later, into photo objectives.
func _photo_meta() -> Dictionary:
	var p: Vector3 = quad.position()
	var agl: float = p.y - terrain.height(p.x, p.z)
	var clock := "21:00"
	if hud != null:
		var hour := float(hud.weather.get("hour", 21.0))
		clock = "%02d:%02d" % [int(hour) % 24, int((hour - floorf(hour)) * 60.0) % 60]
	var weather_name := ""
	var weather_i := 0.0
	if wx != null:
		weather_name = str(WeatherSystem.NAMES[wx.kind])
		weather_i = wx.intensity
	var subjects: Array = []
	if world_life != null:
		# only places that are actually close and large in the frame count as in the photo, not the whole horizon
		for s in world_life.subjects_in_frame(cam):
			if float(s.get("dist", 9999.0)) < 700.0 and float(s.get("size", 0.0)) > 14.0:
				subjects.append(s)
	if case_objects != null:
		for s in case_objects.subjects_in_frame(cam):
			subjects.append(s)
	return {"clock": clock, "weather": weather_name, "weather_i": weather_i,
		"pos": [p.x, p.y, p.z], "agl": agl, "drone": hud.airframe_id if hud != null else "drone",
		"lens": hud.lens if hud != null else "standard", "exposure": sensor.exposure,
		"iso": sensor.iso_shown, "shutter": sensor.shutter_shown, "subjects": subjects,
		"night": _sun_el < 0.0,
		"fireworks": fireworks != null and bool(fireworks.stats().get("running", false)),
		"storm": weather_events != null and bool(weather_events.stats().get("storm", false))}

var _apstest := false

## Headless check of assisted flight: take off, then fly 60 m away and come home by Return to Home and land.
func _run_apstest() -> void:
	_takeoff_or_land()
	for i in 500: await get_tree().physics_frame
	var p: Vector3 = quad.position()
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

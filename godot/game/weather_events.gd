class_name WeatherEvents
extends Node3D
## The extreme-weather event runtime for SPEC-EXTREME-WEATHER B1 to B6 (session B).
##
## It owns the scripted events from the Weather tab "Events" section and the Flight tab course choice:
##   B1 waterspout and tornado   one shared Funnel (game/funnel.gd), over the lake / across the open meadow
##   B2 thunderstorm             the sky's Storm cell cloud (session A's g_storm) plus rain shaft, branching lightning
##                               bolts, world flashes (wx.flash / g_bolt), thunder delayed by distance / 343 m/s
##   B3 thermals                 invisible rising columns over open meadow, fed into the wind the drone feels, with the
##                               two hawks circling them (game/birds.gd thermal centres) and a few drifting motes
##   B4 dust devil, fog bank, snow squall   small funnel, drifting mist walls
##   B5 ring courses             game/courses.gd (gates, ghost, best time)
##   B6 far traffic, kites and flag        game/sky_life.gd using Claude's NewModels2 models
##
## Everything is switched from the pause menu. Events never damage the drone beyond the wind lane's turbulence; no
## lightning ever strikes the drone. The funnel/thermal/storm wind fields are added to Wind.sample through
## Wind.add_field() so game/wind.gd never needs another edit.

const HOME := Vector2(-18.0, 36.0)
const EVENT_KEYS := ["waterspout", "tornado", "thunderstorm", "thermals", "dustdevil", "fogbank", "snowsquall", "surprise"]

var terrain: Terrain
var wind: Wind
var hud: Hud
var wx: WeatherSystem
var sensor: SensorPipeline
var birds: Birds
var courses: Courses
var sky_life: SkyLife

var funnels: Array[Funnel] = []
var _motes: Array[GPUParticles3D] = []
var _storm := {}
var _thermal_centres: Array[Vector3] = []
var _thermal_emitters: Array[GPUParticles3D] = []
var _fog: MeshInstance3D
var _fog_mat: ShaderMaterial
var _fog_kind := ""
var _fog_age := 0.0
var _fog_life := 120.0
var _time := 0.0
var _mobile := false
var _sun_el := 20.0
var _daylight := 1.0
var _surprise_t := 90.0

var _rain: GPUParticles3D
var _rain_mat: ShaderMaterial
var _rain_draw: ShaderMaterial
var _bolt_pool: Array[MeshInstance3D] = []
var _bolt_t := PackedFloat32Array()
var _bolt_mesh: ArrayMesh
var _flash := 0.0
var _flash_k := 0.0
var _lightning_t := 0.0
var _storm_warned := false
var _strike_at := Vector3.ZERO

var _rng := RandomNumberGenerator.new()
var _roar: AudioStreamWAV
var _thunder_near: AudioStreamWAV
var _thunder_far: AudioStreamWAV
var _horn: AudioStreamWAV
var _rotor: AudioStreamWAV
var _p_thunder: Array[AudioStreamPlayer3D] = []
var _p_mic: Array[AudioStreamPlayer] = []
var _pending: Array = []
var _p_horn: AudioStreamPlayer3D

func setup(t: Terrain, w: Wind, h: Hud, weather: WeatherSystem, sen: SensorPipeline, b: Birds) -> void:
	terrain = t
	wind = w
	hud = h
	wx = weather
	sensor = sen
	birds = b
	_mobile = OS.has_feature("mobile")
	_rng.seed = 20261023
	_bus("Weather", "Master")
	_synth_audio()
	for i in 4:
		var p := AudioStreamPlayer3D.new()
		p.bus = "Weather"; p.unit_size = 60.0; p.max_distance = 9000.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(p); _p_thunder.append(p)
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.bus = "Weather"
		add_child(p); _p_mic.append(p)
	_p_horn = AudioStreamPlayer3D.new()
	_p_horn.bus = "Weather"; _p_horn.unit_size = 80.0; _p_horn.max_distance = 9000.0
	_p_horn.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_p_horn.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	add_child(_p_horn)
	_build_rain()
	_build_bolts()
	courses = Courses.new()
	add_child(courses)
	courses.setup(t, hud)
	sky_life = SkyLife.new()
	add_child(sky_life)
	sky_life.setup(t, wind)
	wind.add_field(_funnel_wind)
	wind.add_field(_thermal_wind)
	wind.add_field(_storm_gust)
	for k in EVENT_KEYS:
		if not hud.events.has(k):
			hud.events[k] = false
	courses.set_course(int(hud.events.get("course", 0)))

func _process(_d: float) -> void:
	pass   # main.gd calls update once a frame

func _bus(n: String, send: String) -> void:
	if AudioServer.get_bus_index(n) >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, n)
	AudioServer.set_bus_send(i, send)

# ------------------------------------------------------------------ audio: our own synthesis
func _wav(samples: PackedFloat32Array, looped := false) -> AudioStreamWAV:
	var bytes := PackedByteArray(); bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	w.stereo = false
	w.data = bytes
	if looped:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w

func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array(); b.resize(int(sec * 22050)); return b

## The funnel roar: a looped low rumble that grows into a freight-train noise.
func _synth_roar() -> AudioStreamWAV:
	var sec := 4.0
	var out := _buf(sec)
	var n := out.size()
	var lp := 0.0; var lp2 := 0.0; var brown := 0.0
	for i in n:
		var t := float(i) / 22050.0
		var w := _rng.randf() * 2.0 - 1.0
		brown = clampf(brown + w * 0.035, -0.9, 0.9) * 0.997
		lp += (w - lp) * 0.10
		lp2 += (lp - lp2) * 0.06
		var env := 0.75 + 0.25 * sin(TAU * t / sec)          # loop friendly: one slow swell
		out[i] = clampf((brown * 0.9 + lp2 * 3.0) * env * 0.55, -1.0, 1.0)
	return _wav(out, true)

## Thunder: a near one with a crack and a rolling rumble; a far one that is only the roll.
func _synth_thunder(near: bool) -> AudioStreamWAV:
	var sec := 4.5 if near else 6.0
	var out := _buf(sec)
	var n := out.size()
	var lp := 0.0; var lp2 := 0.0; var brown := 0.0
	for i in n:
		var t := float(i) / 22050.0
		var w := _rng.randf() * 2.0 - 1.0
		brown = clampf(brown + w * 0.05, -0.9, 0.9) * 0.996
		lp += (w - lp) * 0.25
		lp2 += (lp - lp2) * 0.08
		var crack := w * exp(-t * 40.0) * (1.0 if near else 0.15)
		var roll := (brown * 0.9 + lp2 * 2.0) * (0.6 + 0.4 * sin(t * 9.0)) * exp(-t * (0.45 if near else 0.32))
		out[i] = clampf((crack * 0.9 + roll) * 0.8, -1.0, 1.0)
	return _wav(out)

## A diesel horn: two low tones, a beat and a soft attack.
func _synth_horn() -> AudioStreamWAV:
	var sec := 2.6
	var out := _buf(sec)
	var n := out.size()
	for i in n:
		var t := float(i) / 22050.0
		var env := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(2.0, 2.6, t))
		var a := sin(TAU * 311.0 * t) + sin(TAU * 370.0 * t) * 0.8 + sin(TAU * 466.0 * t) * 0.35
		out[i] = clampf(a * env * 0.28, -1.0, 1.0)
	return _wav(out)

## The far rescue helicopter: a blade thump about 14 times a second plus a turbine whine, looped.
func _synth_rotor() -> AudioStreamWAV:
	var sec := 1.4
	var out := _buf(sec)
	var n := out.size()
	for i in n:
		var t := float(i) / 22050.0
		var thump := sin(TAU * 14.0 * t + sin(TAU * 14.0 * t) * 0.8) * (0.55 + 0.45 * sin(TAU * 28.0 * t))
		var whine := sin(TAU * 1450.0 * t) * 0.10 + sin(TAU * 2320.0 * t) * 0.05
		out[i] = clampf(thump * 0.35 + whine, -1.0, 1.0)
	return _wav(out, true)

func _synth_audio() -> void:
	_roar = _synth_roar()
	_thunder_near = _synth_thunder(true)
	_thunder_far = _synth_thunder(false)
	_horn = _synth_horn()
	_rotor = _synth_rotor()

# ------------------------------------------------------------------ meshes: rain, bolts
func _build_rain() -> void:
	_rain_mat = ShaderMaterial.new()
	_rain_mat.shader = load("res://game/shaders/funnel_spray.gdshader")
	_rain_mat.set_shader_parameter("mode", 4)
	_rain_mat.set_shader_parameter("seed_off", 11.0)
	_rain = GPUParticles3D.new()
	_rain.amount = 160 if _mobile else 520
	_rain.lifetime = 2.4
	_rain.emitting = false
	_rain.local_coords = false
	_rain.fixed_fps = 0
	_rain.visibility_aabb = AABB(Vector3(-1400, -100, -1400), Vector3(2800, 1800, 2800))
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain.process_material = _rain_mat
	_rain_draw = ShaderMaterial.new()
	_rain_draw.shader = load("res://game/shaders/funnel_spray_draw.gdshader")
	_rain_draw.set_shader_parameter("px_per_m", 0.0010)
	_rain_draw.set_shader_parameter("stretch", 5.0)
	_rain_draw.set_shader_parameter("opacity", 0.11)
	_rain_draw.set_shader_parameter("tint", Vector3(0.68, 0.74, 0.84))
	var q := QuadMesh.new(); q.size = Vector2(1, 1); q.material = _rain_draw
	_rain.draw_pass_1 = q
	add_child(_rain)

func _build_bolts() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.90, 0.93, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.80, 0.85, 1.0)
	mat.emission_energy_multiplier = 12.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	for i in 5:
		var mi := MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		mi.material_override = mat
		add_child(mi)
		_bolt_pool.append(mi)
		_bolt_t.append(0.0)
	_bolt_mesh = null

func _strike_bolt(from: Vector3, to: Vector3, cam: Vector3) -> void:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var segs := 22
	var prev := from
	for i in range(1, segs + 1):
		var t := float(i) / float(segs)
		var p := from.lerp(to, t)
		if i < segs:
			var jitter := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)) * (10.0 + 25.0 * t * (1.0 - t))
			p += jitter
		# a camera facing ribbon between prev and p
		var dir := (p - prev).normalized()
		var side := dir.cross((cam - p).normalized()).normalized() * (1.6 + 2.4 * t)
		var b := verts.size()
		verts.append(prev - side); verts.append(prev + side); verts.append(p + side); verts.append(p - side)
		idx.append_array([b, b + 1, b + 2, b, b + 2, b + 3])
		prev = p
		if _rng.randf() < 0.18 and t < 0.85:
			# a short branch
			var bp := p + (Vector3(_rng.randf_range(-1.0, 1.0), -_rng.randf_range(0.2, 0.8), _rng.randf_range(-1.0, 1.0))).normalized() * (40.0 + 90.0 * _rng.randf())
			var bd := (bp - p).normalized()
			var bs := bd.cross((cam - bp).normalized()).normalized() * 1.2
			var k := verts.size()
			verts.append(p - bs); verts.append(p + bs); verts.append(bp + bs); verts.append(bp - bs)
			idx.append_array([k, k + 1, k + 2, k, k + 2, k + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var i: int = 0
	var lowest := 1e9
	for k in _bolt_t.size():
		if _bolt_t[k] < lowest:
			lowest = _bolt_t[k]; i = k
	_bolt_pool[i].mesh = mesh
	_bolt_pool[i].visible = true
	_bolt_t[i] = 0.22

func _tick_bolts(dt: float) -> void:
	for i in _bolt_t.size():
		if _bolt_t[i] <= 0.0:
			continue
		_bolt_t[i] -= dt
		if _bolt_t[i] <= 0.0:
			_bolt_pool[i].visible = false

# ------------------------------------------------------------------ per frame
func update(delta: float, cam: Camera3D, drone_pos: Vector3, drone_vel: Vector3, sun_el: float, daylight: float, paused: bool) -> void:
	if paused:
		return
	_time += delta
	_sun_el = sun_el
	_daylight = daylight
	var cam_pos := cam.global_position
	_read_events()
	_tick_funnels(delta)
	_tick_storm(delta, cam_pos, drone_pos)
	_tick_thermals(delta)
	_tick_fog(delta)
	_tick_pending(delta)
	_tick_bolts(delta)
	if courses:
		courses.update(delta, drone_pos, drone_vel, cam_pos)
	if sky_life:
		sky_life.update(delta, cam, wind, daylight, sun_el)
	_update_sky_globals()

func _read_events() -> void:
	var ev := hud.events
	# B1 waterspout
	if bool(ev.get("waterspout", false)) and _count_kind(Funnel.WSPOUT) == 0:
		_spawn_funnel(Funnel.WSPOUT)
	if not bool(ev.get("waterspout", false)):
		_clear_kind(Funnel.WSPOUT)
	# B1 tornado
	if bool(ev.get("tornado", false)) and _count_kind(Funnel.TORNADO) == 0:
		_spawn_funnel(Funnel.TORNADO)
	if not bool(ev.get("tornado", false)):
		_clear_kind(Funnel.TORNADO)
	# B2 thunderstorm
	if bool(ev.get("thunderstorm", false)) and not _storm.get("active", false):
		_start_storm()
	if not bool(ev.get("thunderstorm", false)) and _storm.get("active", false):
		_end_storm()
	# B3 thermals
	_set_thermals(bool(ev.get("thermals", false)))
	# B4 dust devil, fog bank, snow squall
	if bool(ev.get("dustdevil", false)) and _count_kind(Funnel.DUST) == 0:
		_spawn_funnel(Funnel.DUST)
	if not bool(ev.get("dustdevil", false)):
		_clear_kind(Funnel.DUST)
	_fog_event("fogbank", bool(ev.get("fogbank", false)), Color(0.78, 0.82, 0.86), 500.0, 55.0)
	_fog_event("snowsquall", bool(ev.get("snowsquall", false)), Color(0.90, 0.93, 0.96), 380.0, 45.0)
	# B6
	if sky_life:
		sky_life.set_far_traffic(bool(ev.get("far_traffic", false)))
		sky_life.set_park_life(bool(ev.get("park_life", false)))
	# courses
	if courses:
		courses.set_course(int(ev.get("course", 0)))
	# surprise events
	if bool(ev.get("surprise", false)):
		_surprise_t -= get_process_delta_time()
		if _surprise_t <= 0.0:
			_surprise_t = _rng.randf_range(150.0, 360.0)
			_surprise()

func _count_kind(k: int) -> int:
	var n := 0
	for f in funnels:
		if f.kind == k and f.alive():
			n += 1
	return n

func _clear_kind(k: int) -> void:
	for f in funnels:
		if f.kind == k:
			f.stop()
	for f in funnels.duplicate():
		if not f.alive():
			f.queue_free(); funnels.erase(f)

func _spawn_funnel(kind: int) -> Funnel:
	var f := Funnel.new()
	add_child(f)
	if kind == Funnel.WSPOUT:
		var p := _lake_point()
		f.setup(kind, Vector3(p.x, Lake.LEVEL, p.y), terrain, _roar)
	else:
		# the open meadow: start upwind of the park, away from the lake and the graves
		var start := Vector3(HOME.x - 260.0 + _rng.randf_range(-80.0, 80.0), 0.0, HOME.y - 180.0 + _rng.randf_range(-80.0, 80.0))
		start.y = terrain.height(start.x, start.z)
		f.setup(kind, start, terrain, _roar)
	f.start()
	funnels.append(f)
	return f

func _lake_point() -> Vector2:
	var centre := Vector2(-690.0, 100.0)
	for i in 30:
		var p := centre + Vector2(_rng.randf_range(-120.0, 120.0), _rng.randf_range(-140.0, 140.0))
		if Lake.is_wet(p.x, p.y):
			return p
	return centre

func _tick_funnels(delta: float) -> void:
	var remove: Array = []
	for f in funnels:
		f.update(delta, wind, terrain)
		if not f.alive():
			remove.append(f)
	for f in remove:
		f.queue_free(); funnels.erase(f)

# ------------------------------------------------------------------ B2 storm
func _start_storm() -> void:
	var a := Vector2(HOME.x - 520.0 + _rng.randf_range(-120.0, 120.0), HOME.y + 60.0 + _rng.randf_range(-120.0, 120.0))
	_storm = {"active": true, "age": 0.0, "form": 25.0, "dur": _rng.randf_range(95.0, 150.0),
		"anchor": Vector3(a.x, terrain.height(a.x, a.y), a.y), "strength": 0.0, "next_bolt": 2.5, "next_warn": 0.0}
	_rain.global_position = _storm["anchor"]
	_rain.emitting = true
	_rain_mat.set_shader_parameter("centre", _storm["anchor"])
	_rain_mat.set_shader_parameter("radius", 320.0)
	_rain_mat.set_shader_parameter("height", 900.0)
	# the warning to the player only once per storm
	if hud != null:
		hud.toast("A thunderstorm is building over the valley.")

func _end_storm() -> void:
	_storm = {}
	_rain.emitting = false
	_flash = 0.0
	_flash_k = 0.0
	if wx != null:
		wx.flash = 0.0
	RenderingServer.global_shader_parameter_set("g_bolt", Vector4(0.0, -1.0, 0.0, 0.0))

func _tick_storm(delta: float, cam_pos: Vector3, drone_pos: Vector3) -> void:
	if not _storm.get("active", false):
		return
	_storm["age"] = float(_storm["age"]) + delta
	var age: float = _storm["age"]
	var life: float = float(_storm["dur"])
	var strength: float = smoothstep(0.0, float(_storm["form"]), age) * (1.0 - smoothstep(life - 20.0, life, age))
	_storm["strength"] = strength
	if age >= life:
		_end_storm()
		return
	var anchor: Vector3 = _storm["anchor"]
	_rain.global_position = anchor
	_rain_mat.set_shader_parameter("centre", anchor)
	_rain_mat.set_shader_parameter("strength", strength)
	# lightning: bolts and sheet flashes at random intervals
	_storm["next_bolt"] = float(_storm["next_bolt"]) - delta
	if _storm["next_bolt"] <= 0.0:
		_storm["next_bolt"] = _rng.randf_range(3.0, 9.5)
		var sheet := _rng.randf() < 0.35
		var strike := anchor + Vector3(_rng.randf_range(-260.0, 260.0), 0.0, _rng.randf_range(-260.0, 260.0))
		strike.y = terrain.height(strike.x, strike.z)
		var cloud_base := anchor + Vector3(strike.x - anchor.x, 720.0, strike.z - anchor.z)
		if not sheet:
			_strike_bolt(cloud_base, strike, cam_pos)
		_strike_at = strike
		_flash = 1.0
		_flash_k = 0.25 if sheet else 0.55
		var dir := (strike - cam_pos)
		dir.y = maxf(dir.y, 120.0)
		RenderingServer.global_shader_parameter_set("g_bolt", Vector4(dir.normalized().x, dir.normalized().y, dir.normalized().z, strength))
		# thunder arrives late, by distance / 343 m/s
		var d := strike.distance_to(_pilot_pos())
		_pending.append({"t": d / 343.0, "kind": "thunder", "pos": strike, "near": d < 900.0, "gain": clampf(900.0 / maxf(d, 150.0), 0.15, 1.0)})
	# the flash fades quickly; main.gd applies wx.flash to the sky, sun and ambient
	_flash = maxf(0.0, _flash - delta * (3.4 if _flash_k > 0.4 else 2.4))
	if wx != null:
		wx.flash = maxf(wx.flash, _flash)
	if _pending.size() > 16:
		_pending = _pending.slice(_pending.size() - 16)
	# warn the player when the drone is near the shaft; never hurt it
	var dstorm := Vector2(drone_pos.x - anchor.x, drone_pos.z - anchor.z).length()
	if dstorm < 420.0 and float(_storm.get("next_warn", 0.0)) <= _time:
		_storm["next_warn"] = _time + 25.0
		if hud != null:
			hud.toast("Storm nearby. The air is rough.")

func _pilot_pos() -> Vector3:
	return Vector3(HOME.x, terrain.height(HOME.x, HOME.y) + 1.7, HOME.y)

# ------------------------------------------------------------------ B3 thermals
func _set_thermals(on: bool) -> void:
	var ok := on and _daylight > 0.35 and _sun_el > 8.0
	if not ok:
		if not _thermal_centres.is_empty():
			_thermal_centres.clear()
			if birds: birds.thermal_centres = []
			for e in _thermal_emitters:
				e.emitting = false
			for m in _motes:
				m.emitting = false
		return
	if not _thermal_centres.is_empty():
		return
	# three rising columns over open, sunny meadow near the park
	var lawn := Vector2(HOME.x - 120.0, HOME.y - 60.0)
	for i in 3:
		var best := lawn + Vector2(_rng.randf_range(-200.0, 340.0), _rng.randf_range(-160.0, 340.0))
		for k in 8:
			var p := lawn + Vector2(_rng.randf_range(-350.0, 420.0), _rng.randf_range(-300.0, 420.0))
			if Lake.is_wet(p.x, p.y):
				continue
			var cover := terrain.cover_at(p.x, p.y)
			if cover.y > 0.35 or cover.x < 0.35:
				best = p
				break
		var y := terrain.height(best.x, best.y)
		_thermal_centres.append(Vector3(best.x, y + 120.0, best.y))
		var e := _make_motes(Vector3(best.x, y, best.y))
		_thermal_emitters.append(e)
	if birds:
		birds.thermal_centres = _thermal_centres
	if hud != null:
		hud.toast("Thermals are rising over the meadow. Watch the hawks.")

func _make_motes(at: Vector3) -> GPUParticles3D:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/shaders/funnel_spray.gdshader")
	mat.set_shader_parameter("mode", 3)
	mat.set_shader_parameter("centre", at)
	mat.set_shader_parameter("radius", 55.0)
	mat.set_shader_parameter("height", 260.0)
	mat.set_shader_parameter("strength", 0.8)
	mat.set_shader_parameter("seed_off", _rng.randf() * 30.0)
	var p := GPUParticles3D.new()
	p.amount = 24 if _mobile else 110
	p.lifetime = 9.0
	p.emitting = true
	p.local_coords = false
	p.fixed_fps = 0
	p.visibility_aabb = AABB(Vector3(-160, -20, -160), Vector3(320, 320, 320))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.process_material = mat
	var dm := ShaderMaterial.new()
	dm.shader = load("res://game/shaders/funnel_spray_draw.gdshader")
	dm.set_shader_parameter("px_per_m", 0.0016)
	dm.set_shader_parameter("stretch", 1.0)
	dm.set_shader_parameter("opacity", 0.35)
	dm.set_shader_parameter("tint", Vector3(0.95, 0.88, 0.70))
	var q := QuadMesh.new(); q.size = Vector2(1, 1); q.material = dm
	p.draw_pass_1 = q
	add_child(p)
	_motes.append(dm)
	return p

func _tick_thermals(delta: float) -> void:
	for e in _thermal_emitters:
		e.global_position = Vector3.ZERO
	# nothing else: the wind field and the birds read the centres

# ------------------------------------------------------------------ B4 fog banks and snow squalls
func _fog_event(kind: String, on: bool, tint: Color, width: float, height: float) -> void:
	if on and _fog_kind != kind:
		if _fog == null:
			_fog = MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(width, height)
			_fog.mesh = pm
			_fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_fog_mat = ShaderMaterial.new()
			_fog_mat.shader = load("res://game/shaders/fog_wall.gdshader")
			_fog.material_override = _fog_mat
			add_child(_fog)
		_fog_kind = kind
		_fog_age = 0.0
		_fog_life = 120.0 if kind == "fogbank" else 70.0
		_fog_mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
		_fog_mat.set_shader_parameter("density", 0.85 if kind == "fogbank" else 1.0)
		_fog_mat.set_shader_parameter("seed", _rng.randf() * 40.0)
		_fog.visible = true
		_place_fog()
		if hud != null:
			hud.toast("A bank of mist is drifting over the lake." if kind == "fogbank" else "A snow squall is moving across the valley.")
	elif not on and _fog_kind == kind:
		_fog_kind = ""
		if _fog: _fog.visible = false

func _place_fog() -> void:
	if _fog_kind == "fogbank":
		var p := _lake_point()
		_fog.global_position = Vector3(p.x, Lake.LEVEL + 34.0, p.y)
	elif _fog_kind == "snowsquall":
		_fog.global_position = Vector3(HOME.x - 200.0, terrain.height(HOME.x - 200.0, HOME.y) + 40.0, HOME.y)
	# a PlaneMesh is horizontal, so stand it up: the wall's face looks across the wind, so it advances broadside
	var toward := wind.toward()
	var yaw := atan2(toward.x, toward.z) + PI * 0.5
	_fog.global_transform.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5)

func _tick_fog(delta: float) -> void:
	if _fog == null or _fog_kind == "":
		return
	_fog_age += delta
	var fade := smoothstep(0.0, 12.0, _fog_age) * (1.0 - smoothstep(_fog_life - 15.0, _fog_life, _fog_age))
	_fog_mat.set_shader_parameter("alpha", 0.82 * fade)
	var toward := wind.toward()
	_fog.global_position += toward * (2.0 if _fog_kind == "fogbank" else 5.0) * delta
	var yaw := atan2(toward.x, toward.z) + PI * 0.5
	_fog.global_transform.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5)
	if _fog_age > _fog_life:
		_fog_kind = ""
		_fog.visible = false

# ------------------------------------------------------------------ surprise events
func _surprise() -> void:
	if _count_kind(Funnel.WSPOUT) + _count_kind(Funnel.TORNADO) > 0 or _storm.get("active", false):
		return
	var pick := _rng.randi() % 4
	if pick == 0:
		hud.events["waterspout"] = true
	elif pick == 1:
		hud.events["thermals"] = true
	elif pick == 2:
		hud.events["dustdevil"] = true
	else:
		hud.events["thunderstorm"] = true
	if hud != null:
		hud.toast("The weather is changing.")

# ------------------------------------------------------------------ wind fields
func _funnel_wind(pos: Vector3) -> Vector3:
	var v := Vector3.ZERO
	for f in funnels:
		v += f.wind_at(pos)
	return v

func _thermal_wind(pos: Vector3) -> Vector3:
	var v := Vector3.ZERO
	for c in _thermal_centres:
		var d := Vector2(pos.x - c.x, pos.z - c.z).length()
		if d < 70.0:
			var k := 1.0 - d / 70.0
			v.y += (1.2 + 1.8 * k) * k
	return v

func _storm_gust(pos: Vector3) -> Vector3:
	if not _storm.get("active", false):
		return Vector3.ZERO
	var a: Vector3 = _storm["anchor"]
	var s: float = _storm["strength"]
	var d := Vector2(pos.x - a.x, pos.z - a.z)
	var dist := d.length()
	if dist < 120.0 or dist > 900.0:
		return Vector3.ZERO
	# the gust front: air rushing outward ahead of the rain shaft
	var dir := Vector3(d.x, 0.0, d.y).normalized()
	return (dir * 9.0 + Vector3(0.0, -2.5, 0.0)) * s * (1.0 - smoothstep(300.0, 900.0, dist))

# ------------------------------------------------------------------ lightning flash state for the sky
var _sky_owned := false

func _update_sky_globals() -> void:
	if _storm.get("active", false):
		var a: Vector3 = _storm["anchor"]
		var s: float = _storm["strength"]
		RenderingServer.global_shader_parameter_set("g_storm", Vector4(a.x, a.z, s, 0.0))
		RenderingServer.global_shader_parameter_set("g_sky_dark", 0.30 * s + 0.45 * _flash)
		_sky_owned = true
		return
	# a funnel hangs from the sky's Storm cell cloud and lowered wall cloud (session A's A2 hook): the funnel anchors
	# the cell, so the top of the tube joins the cloud base instead of ending in mid air.
	var f := _cloud_funnel()
	if f != null:
		RenderingServer.global_shader_parameter_set("g_storm", Vector4(f.anchor.x, f.anchor.z, clampf(f.strength * 0.9, 0.0, 1.0), 0.0))
		RenderingServer.global_shader_parameter_set("g_sky_dark", 0.14 * f.strength)
		_sky_owned = true
	elif _sky_owned:
		# only clear the sky hook we set, so session A's own dev tokens and sky settings are never overwritten
		RenderingServer.global_shader_parameter_set("g_storm", Vector4(0.0, 0.0, 0.0, 0.0))
		RenderingServer.global_shader_parameter_set("g_sky_dark", 0.0)
		_sky_owned = false

func _cloud_funnel() -> Funnel:
	for f in funnels:
		if f.alive() and (f.kind == Funnel.TORNADO or f.kind == Funnel.WSPOUT):
			return f
	return null

func _tick_pending(delta: float) -> void:
	var keep: Array = []
	for s in _pending:
		var t: float = float(s["t"]) - delta
		if t <= 0.0:
			_play_thunder(s)
		else:
			s["t"] = t
			keep.append(s)
	_pending = keep

func _play_thunder(s: Dictionary) -> void:
	var near: bool = bool(s.get("near", false))
	var stream: AudioStream = _thunder_near if near else _thunder_far
	var pos: Vector3 = s["pos"]
	var gain: float = float(s.get("gain", 1.0))
	for p in _p_thunder:
		if not p.playing:
			p.stream = stream
			p.global_position = pos
			p.volume_db = linear_to_db(clampf(gain, 0.02, 1.0))
			p.play()
			break

# ------------------------------------------------------------------ screenshot hooks
## Dev hook for a shot run: start one event immediately, formed and at full strength (so one screenshot shows it).
func debug_event(name: String) -> void:
	if name == "waterspout":
		hud.events["waterspout"] = true
		var f := _spawn_funnel(Funnel.WSPOUT)
		f.age = f.form_time; f.strength = 1.0
	elif name == "tornado":
		hud.events["tornado"] = true
		var f2 := _spawn_funnel(Funnel.TORNADO)
		f2.age = f2.form_time; f2.strength = 1.0
	elif name == "dustdevil":
		hud.events["dustdevil"] = true
		var f3 := _spawn_funnel(Funnel.DUST)
		f3.age = f3.form_time; f3.strength = 1.0
	elif name == "storm":
		hud.events["thunderstorm"] = true
		_start_storm()
		_storm["age"] = float(_storm["form"])
		_storm["next_bolt"] = 1.2
		# the dev shot may be only a few frames long, so put one bolt and its flash in the very first frame
		var a: Vector3 = _storm["anchor"]
		var camg := Vector3(a.x + 80.0, a.y + 160.0, a.z + 600.0)
		_strike_bolt(a + Vector3(20.0, 700.0, -30.0), a + Vector3(10.0, 0.0, 10.0), camg)
		_flash = 1.0
		_flash_k = 1.0
		RenderingServer.global_shader_parameter_set("g_bolt", Vector4(0.0, 0.2, -1.0, 0.9))
	elif name == "thermals":
		hud.events["thermals"] = true
		_set_thermals(true)
	elif name == "fogbank":
		hud.events["fogbank"] = true
		_fog_event("fogbank", true, Color(0.78, 0.82, 0.86), 500.0, 55.0)
		_fog_age = 20.0
	elif name == "snowsquall":
		hud.events["snowsquall"] = true
		_fog_event("snowsquall", true, Color(0.90, 0.93, 0.96), 380.0, 45.0)
		_fog_age = 20.0
	elif name == "far":
		hud.events["far_traffic"] = true
		sky_life.set_far_traffic(true)
	elif name == "park":
		hud.events["park_life"] = true
		sky_life.set_park_life(true)

## Dev hook: start a course (0 off, 1 easy, 2 lake run, 3 tree slalom).
func debug_course(i: int) -> void:
	hud.events["course"] = i
	courses.set_course(i)

## The first funnel of a kind, for shots and checks.
func funnel(kind: int) -> Funnel:
	for f in funnels:
		if f.kind == kind:
			return f
	return null

func stats() -> Dictionary:
	var st := {"funnels": funnels.size(), "storm": _storm.get("active", false), "flash": snappedf(_flash, 0.01),
		"thermals": _thermal_centres.size(), "fog": _fog_kind, "course": courses.course if courses else 0,
		"rain": _rain.emitting if _rain else false}
	if not funnels.is_empty():
		st["funnel0"] = funnels[0].info()
	if sky_life:
		st["sky_life"] = sky_life.stats()
	return st

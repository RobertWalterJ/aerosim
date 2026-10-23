class_name Fireworks
extends Node3D
## Fireworks shows over the lake: three launch barges, shells that rise on a spark trail, bursts in eight shapes,
## short-lived coloured light, drifting smoke and synthesised sound that arrives after the light (distance / 343 m/s).
##
## Built by session B for SPEC-NEW-EXPERIENCES.md E1. The models come from game/new_models.gd (barge, mortar tubes,
## shell proxy); this file only places and drives them.
##
## The bursts are GPU particles (shaders/firework_spark.gdshader and firework_spark_draw.gdshader). One emitter per
## burst type, two of each so bursts can overlap, and each is a single draw call. Every burst restarts its emitter,
## sets the colour set and size, and draws its shape from the particle shader: peony, chrysanthemum, willow, palm,
## ring, heart, crackle, plus the finale shell. Sparks are additive and brighter than white, so the sensor bloom
## picks them up, and they never hurt anything: flying through a burst is only bright and loud.
##
## Shows are lists of burst events on a show clock that runs with the game (pauses with it). Three shows: a three
## minute build up, a quiet ninety seconds, and a twenty second finale. "Surprise shows" starts one by itself on a
## few set evenings. A show only starts at night or twilight (sun lower than -4 degrees); in daylight the main game
## moves the clock to 21:30 and tells the player in plain words.
##
## Global g_fire (rgb = the strongest burst colour, a = strength) is read by the smoke and by the lake water shader,
## so the burst lights the smoke and glints on the lake.

signal show_ended
signal toast(text: String)      # a short plain notice for the player
signal night_needed             # the game moves the clock to 21:30 (main.gd sets hud.weather)

const RATE := 22050
# burst types (the index into every per-type table below)
const PEONY := 0
const CHRYS := 1
const WILLOW := 2
const PALM := 3
const RING := 4
const HEART := 5
const CRACKLE := 6
const FINALE := 7
const CROSSETTE := 8
const FISH := 9
const STROBE := 10
const HORSETAIL := 11
const SALUTE := 12             # light and sound only, no stars (a flash-powder salute)
const TYPES := 13
# shader mode for each burst type (see firework_spark.gdshader; 8 is the shell trail and 9 the lift sparks)
const MODE_OF_TYPE := [0, 1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 6]
const TRAIL := 8
const LIFT_STARS := 9
const SHOW_NAMES := ["Off", "Build up", "Quiet night", "Finale"]
# sparks per emitter, on a computer; phones get a third (the spec: 6000 desktop, 1500 phone). The four newer types get
# one emitter each rather than two, to stay inside the budget.
const AMOUNT := [260, 280, 300, 200, 200, 220, 380, 400, 190, 230, 240, 250, 0]
const LIFE := [2.0, 3.2, 4.2, 2.6, 2.2, 2.4, 1.8, 3.4, 2.4, 2.8, 3.6, 3.0, 0.4]
const SPEED := [52.0, 55.0, 34.0, 62.0, 42.0, 40.0, 32.0, 58.0, 44.0, 34.0, 28.0, 30.0, 0.0]
const STRETCH := [1.0, 5.0, 7.0, 1.7, 1.0, 1.0, 1.0, 1.8, 1.3, 1.0, 1.0, 1.2, 1.0]
const SPARK_HDR := [24.0, 22.0, 22.0, 24.0, 23.0, 23.0, 26.0, 28.0, 23.0, 21.0, 28.0, 19.0, 30.0]
const EMITTERS := [2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 0]
# British/European shell sizes in inches. A bigger shell breaks higher, wider and louder; the star sizes follow from it.
const CALIBRES := [3.0, 4.0, 5.0, 6.0, 8.0]
# colour sets: [main colour, second colour], sRGB; converted to linear when they are set
const COLOURS := {
	"red": [Color(1.0, 0.09, 0.04), Color(1.0, 0.36, 0.10)],
	"gold": [Color(1.0, 0.62, 0.12), Color(1.0, 0.86, 0.42)],
	"green": [Color(0.24, 1.0, 0.30), Color(0.72, 1.0, 0.45)],
	"blue": [Color(0.20, 0.45, 1.0), Color(0.55, 0.78, 1.0)],
	"white": [Color(1.0, 0.95, 0.86), Color(0.86, 0.90, 1.0)],
	"purple": [Color(0.66, 0.25, 1.0), Color(1.0, 0.45, 0.85)],
	"two": [Color(1.0, 0.15, 0.10), Color(0.25, 1.0, 0.40)],
	"warm": [Color(1.0, 0.46, 0.10), Color(1.0, 0.20, 0.05)],
}
# the barge row on the lake (x, z); the model's origin is the waterline, and it is 12 x 5 m with the long axis along z
const BARGE_POS := [Vector2(-812.0, 68.0), Vector2(-792.0, 100.0), Vector2(-812.0, 132.0)]
# where the show fills the sky: over the lake and the west shore, 120 to 220 m over the water
const SHOW_CENTRE := Vector2(-700.0, 100.0)

var enabled := true
var surprise_on := false

var _sun_el := -20.0
var _hour := 22.0
var _doy := 0
var _pilot := Vector3.ZERO
var _drone := Vector3.ZERO
var _cam_pos := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _mobile := false
var _mounted := false

var _spark_shader: Shader
var _spark_draw_shader: Shader
var _smoke_shader: Shader
var _smoke_draw_shader: Shader
var _draw_mats: Array[ShaderMaterial] = []       # all draw materials (one per type, the trail, the smoke): px_per_m
var _smoke_draw: ShaderMaterial
var _trail_smoke_draw: ShaderMaterial        # the shell's own smoke, lit a little so it reads at night
var _trail_draw: ShaderMaterial
var _emitters: Array = []                        # [type][2] GPUParticles3D
var _smoke_emitters: Array[GPUParticles3D] = []
var _smoke_next := 0
var _tube_smoke: Array[GPUParticles3D] = []          # the puff at the mortar when the lift charge fires
var _lift_sparks: Array[GPUParticles3D] = []         # sparks thrown out of the tube at launch
var _tube_next := 0
var _lift_next := 0
var _next_of_type := PackedInt32Array()
var _barges: Array[MeshInstance3D] = []
var _tube_mouths: Array[Vector3] = []            # 3 barges x 20 tubes, world space
var _shells: Array[Shell] = []
var _trail_mat: ShaderMaterial
var _lights: Array[OmniLight3D] = []
var _light_next := 0
var _flashes: Array[MeshInstance3D] = []          # the short bright glow at each burst
var _flash_mats: Array[ShaderMaterial] = []
var _flash_t := PackedFloat32Array()
var _flash_next := 0
var _g_players: Array[AudioStreamPlayer3D] = []
var _m_players: Array[AudioStreamPlayer] = []
var _sounds := {}
var _pending: Array = []                         # delayed sounds, distance / 343 m/s
var _breaks: Array = []                          # second breaks of multi-break shells
var _snd_bands := {"near": 0, "mid": 0, "far": 0}    # how many breaks were played in each distance flavour
var _max_delay := 0.0                                # the longest sound delay used, for the report
var _pending_show := 0
var _surprise_doy := -1
var _running := false
var _show_t := 0.0
var _show_dur := 0.0
var _show_ev: Array = []
var _shows: Array = []
var _max_sparks := 6000
var _sparks_now := 0

var _pilot_pos_ground := Vector3.ZERO
var _sensor: SensorPipeline          # the camera pipeline, so a burst can flash the lens and the exposure

class Shell:
	var node: Node3D
	var mesh: MeshInstance3D
	var trail: GPUParticles3D
	var smoke: GPUParticles3D
	var whistle: AudioStreamPlayer3D
	var mouth := Vector3.ZERO
	var target := Vector3.ZERO
	var vel := Vector3.ZERO
	var t := 0.0
	var rise := 4.5
	var type := 0
	var col := "gold"
	var size := 1.0
	var calibre := 5.0
	var sparky := false
	var active := false

## Register the shader global the smoke and the lake read (before any shader is loaded, so called from main.gd
## next to Grass.add_globals()).
static func add_globals() -> void:
	RenderingServer.global_shader_parameter_add("g_fire", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.0, 0.0, 0.0, 0.0))
	# the lake's mirrored sky colour (water lane, realism 2.5): set from the fog colour every frame in main.gd
	RenderingServer.global_shader_parameter_add("g_water", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.62, 0.70, 0.80, 1.0))

## Build the barges, the particle pools, the lights and the sound. `pilot` is where the pilot stands (the ears for the
## Ground listening position); `home` is (x, z) on the ground.
func setup(terrain: Terrain, home: Vector2) -> void:
	_rng.seed = 20261023
	_mobile = OS.has_feature("mobile")
	_max_sparks = 1500 if _mobile else 6000
	_pilot_pos_ground = Vector3(home.x, terrain.height(home.x, home.y) + 1.7, home.y)
	_spark_shader = load("res://game/shaders/firework_spark.gdshader")
	_spark_draw_shader = load("res://game/shaders/firework_spark_draw.gdshader")
	_smoke_shader = load("res://game/shaders/firework_smoke.gdshader")
	_smoke_draw_shader = load("res://game/shaders/firework_smoke_draw.gdshader")
	_build_barges()
	_build_emitters()
	_build_smoke()
	_build_lights()
	_build_flashes()
	_build_shells()
	_build_launch_fx()
	_build_sound()
	_build_shows()
	_mounted = true
	for ty in TYPES:
		_next_of_type.append(0)

func _process(_delta: float) -> void:
	pass   # main.gd calls update() once a frame, after the camera is placed

# ------------------------------------------------------------------ build
func _build_barges() -> void:
	var mesh: ArrayMesh = NewModels.barge()
	var tubes: Array = NewModels.barge_tubes()
	for i in BARGE_POS.size():
		var b := MeshInstance3D.new()
		b.mesh = mesh
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var yaw: float = -0.10 + 0.10 * float(i)
		b.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(BARGE_POS[i].x, Lake.LEVEL, BARGE_POS[i].y))
		add_child(b)
		_barges.append(b)
		for t in tubes:
			var mouth: Vector3 = t[0]
			_tube_mouths.append(b.global_transform * mouth)

func _quad(mat: ShaderMaterial) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.material = mat
	return q

func _draw_material(shader: Shader, stretch: float, hdr: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("stretch", stretch)
	m.set_shader_parameter("hdr", hdr)
	m.set_shader_parameter("px_per_m", 0.0016)
	_draw_mats.append(m)
	return m

func _build_emitters() -> void:
	_trail_draw = _draw_material(_spark_draw_shader, 1.0, 4.2)
	_trail_mat = ShaderMaterial.new()
	_trail_mat.shader = _spark_shader
	_trail_mat.set_shader_parameter("mode", TRAIL)
	_trail_mat.set_shader_parameter("seed_off", 1.0)
	# one process material per pool emitter, so every burst can have its own colours and seed
	for ty in TYPES:
		var n: int = int(EMITTERS[ty])
		if n <= 0:
			_emitters.append([])
			continue
		var mat: ShaderMaterial = _draw_material(_spark_draw_shader, STRETCH[ty], SPARK_HDR[ty])
		var list: Array = []
		for k in n:
			var p := GPUParticles3D.new()
			p.amount = int(AMOUNT[ty] * (0.32 if _mobile else 1.0))
			p.lifetime = LIFE[ty]
			p.one_shot = true
			p.emitting = false
			p.local_coords = false
			p.fixed_fps = 0
			p.visibility_aabb = AABB(Vector3(-280, -280, -280), Vector3(560, 560, 560))
			p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			p.draw_pass_1 = _quad(mat)
			var pm := ShaderMaterial.new()
			pm.shader = _spark_shader
			pm.set_shader_parameter("mode", MODE_OF_TYPE[ty])
			pm.set_shader_parameter("seed_off", 0.0)
			p.process_material = pm
			add_child(p)
			list.append(p)
		_emitters.append(list)

func _build_smoke() -> void:
	_smoke_draw = ShaderMaterial.new()
	_smoke_draw.shader = _smoke_draw_shader
	_smoke_draw.set_shader_parameter("px_per_m", 0.0016)
	_smoke_draw.set_shader_parameter("tint", Vector3(0.46, 0.45, 0.46))
	_smoke_draw.set_shader_parameter("opacity", 0.040)
	_draw_mats.append(_smoke_draw)
	# the rising shell's smoke trail and the launch puff have no burst to light them yet, so they carry a little light
	_trail_smoke_draw = ShaderMaterial.new()
	_trail_smoke_draw.shader = _smoke_draw_shader
	_trail_smoke_draw.set_shader_parameter("px_per_m", 0.0016)
	_trail_smoke_draw.set_shader_parameter("self_light", 0.22)
	_trail_smoke_draw.set_shader_parameter("opacity", 0.075)
	_trail_smoke_draw.set_shader_parameter("tint", Vector3(0.52, 0.50, 0.50))
	_draw_mats.append(_trail_smoke_draw)
	for k in 6:
		var s := GPUParticles3D.new()
		s.amount = 20 if _mobile else 42
		s.lifetime = 24.0
		s.one_shot = true
		s.emitting = false
		s.local_coords = false
		s.fixed_fps = 0
		s.visibility_aabb = AABB(Vector3(-380, -160, -380), Vector3(760, 320, 760))
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.draw_pass_1 = _quad(_smoke_draw)
		var pm := ShaderMaterial.new()
		pm.shader = _smoke_shader
		pm.set_shader_parameter("seed_off", float(k) * 17.0)
		pm.set_shader_parameter("size_from", 7.0)
		pm.set_shader_parameter("size_to", 52.0)
		s.process_material = pm
		add_child(s)
		_smoke_emitters.append(s)

func _build_lights() -> void:
	for i in 4:
		var l := OmniLight3D.new()
		l.shadow_enabled = false
		l.omni_range = 340.0
		l.omni_attenuation = 0.7
		l.light_energy = 0.0
		l.visible = false
		add_child(l)
		_lights.append(l)

func _build_flashes() -> void:
	var sh := load("res://game/shaders/firework_flash_draw.gdshader")
	for i in 6:
		var m := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("px_per_m", 0.0016)
		q.material = mat
		m.mesh = q
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		_flashes.append(m)
		_flash_mats.append(mat)
		_flash_t.append(0.0)

func _build_shells() -> void:
	var shell_mesh: ArrayMesh = NewModels.firework_shell_proxy()
	for i in 16:
		var s := Shell.new()
		s.node = Node3D.new()
		s.node.visible = false
		add_child(s.node)
		var mi := MeshInstance3D.new()
		mi.mesh = shell_mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.node.add_child(mi)
		s.mesh = mi
		# the rising shell: a faint ember trail (brighter for the odd comet shell) ...
		var tr := GPUParticles3D.new()
		tr.amount = 10 if _mobile else 20
		tr.lifetime = 0.55
		tr.emitting = false
		tr.local_coords = false
		tr.fixed_fps = 0
		tr.visibility_aabb = AABB(Vector3(-6, -80, -6), Vector3(12, 90, 12))
		tr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tr.draw_pass_1 = _quad(_trail_draw)
		tr.process_material = _trail_mat
		s.node.add_child(tr)
		s.trail = tr
		# ... and a grey smoke trail, laid where the shell has been, so the launch reads as an object moving through
		# the sky rather than as a bright line. A real shell is hard to see until it breaks.
		var sm := GPUParticles3D.new()
		sm.amount = 26 if _mobile else 64
		sm.lifetime = 3.2
		sm.emitting = false
		sm.local_coords = false
		sm.fixed_fps = 0
		sm.visibility_aabb = AABB(Vector3(-40, -120, -40), Vector3(80, 260, 80))
		sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sm.draw_pass_1 = _quad(_trail_smoke_draw)
		var smat := ShaderMaterial.new()
		smat.shader = _smoke_shader
		smat.set_shader_parameter("size_from", 0.9)
		smat.set_shader_parameter("size_to", 5.5)
		smat.set_shader_parameter("seed_off", float(i) * 13.0 + 5.0)
		sm.process_material = smat
		s.node.add_child(sm)
		s.smoke = sm
		var wh := AudioStreamPlayer3D.new()
		wh.bus = "FireworksG"
		wh.unit_size = 45.0
		wh.max_distance = 5000.0
		wh.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		wh.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		s.node.add_child(wh)
		s.whistle = wh
		_shells.append(s)

## The flash and the smoke at the mortar tube when the lift charge fires, and a few sparks thrown up with the shell.
func _build_launch_fx() -> void:
	for i in 3:
		var s := GPUParticles3D.new()
		s.amount = 16 if _mobile else 36
		s.one_shot = true
		s.lifetime = 4.0
		s.emitting = false
		s.local_coords = false
		s.fixed_fps = 0
		s.visibility_aabb = AABB(Vector3(-50, -20, -50), Vector3(100, 80, 100))
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.draw_pass_1 = _quad(_trail_smoke_draw)
		var smat := ShaderMaterial.new()
		smat.shader = _smoke_shader
		smat.set_shader_parameter("size_from", 1.0)
		smat.set_shader_parameter("size_to", 11.0)
		smat.set_shader_parameter("seed_off", 100.0 + float(i) * 7.0)
		s.process_material = smat
		add_child(s)
		_tube_smoke.append(s)
	var ldraw: ShaderMaterial = _draw_material(_spark_draw_shader, 1.0, 6.0)
	var lmat := ShaderMaterial.new()
	lmat.shader = _spark_shader
	lmat.set_shader_parameter("mode", LIFT_STARS)
	lmat.set_shader_parameter("speed", 11.0)
	lmat.set_shader_parameter("seed_off", 3.0)
	for i in 3:
		var p := GPUParticles3D.new()
		p.amount = 22 if _mobile else 48
		p.lifetime = 0.85
		p.one_shot = true
		p.emitting = false
		p.local_coords = false
		p.fixed_fps = 0
		p.visibility_aabb = AABB(Vector3(-16, -6, -16), Vector3(32, 36, 32))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.draw_pass_1 = _quad(ldraw)
		p.process_material = lmat
		add_child(p)
		_lift_sparks.append(p)

# ------------------------------------------------------------------ sound: everything synthesised at start-up
func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w

func _buffer(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b

## The launch: a soft whoosh that sweeps up as the shell leaves the tube.
func _snd_launch() -> PackedFloat32Array:
	var sec := 0.75
	var out := _buffer(sec)
	var n := out.size()
	var lp := 0.0
	var bp := 0.0
	for i in n:
		var t: float = float(i) / RATE
		var u: float = t / sec
		var env: float = smoothstep(0.0, 0.05, u) * pow(1.0 - u, 1.5)
		var w: float = _rng.randf() * 2.0 - 1.0
		lp += (w - lp) * (0.08 + 0.20 * smoothstep(0.0, 0.5, u))
		bp += (lp - bp) * 0.06
		var body: float = sin(TAU * (65.0 + 230.0 * u) * t) * 0.22
		out[i] = (bp * 3.0 + body) * env * 0.55
	return out

## A shell burst heard from the park: a sharp thump on top of a long low rumble.
func _snd_thump(big := false) -> PackedFloat32Array:
	var sec := 2.6 if big else 1.8
	var out := _buffer(sec)
	var n := out.size()
	var brown := 0.0
	for i in n:
		var t: float = float(i) / RATE
		var w: float = _rng.randf() * 2.0 - 1.0
		brown = clampf(brown + w * 0.05, -0.9, 0.9) * 0.997
		var f: float = 44.0 - 8.0 * minf(t, 0.4)
		var bass: float = sin(TAU * f * t) * exp(-t * 2.1)
		var rumble: float = brown * exp(-t * (0.8 if big else 1.2)) * 0.85
		var crack: float = w * exp(-t * 20.0) * 0.6
		out[i] = clampf((bass * 0.8 + rumble * 0.6 + crack) * (0.8 if big else 0.6), -1.0, 1.0)
	return out

## Crackle: hundreds of tiny sharp snaps, fading out.
func _snd_crackle() -> PackedFloat32Array:
	var sec := 1.9
	var out := _buffer(sec)
	var n := out.size()
	for k in 150:
		var t0: float = pow(_rng.randf(), 1.4) * (sec - 0.1)
		var i0 := int(t0 * RATE)
		var dur := int((0.015 + _rng.randf() * 0.05) * RATE)
		var amp: float = (0.20 + _rng.randf() * 0.75) * (1.0 - t0 / sec)
		var lp := 0.0
		for j in dur:
			if i0 + j >= n:
				break
			var w: float = _rng.randf() * 2.0 - 1.0
			lp += (w - lp) * 0.45
			out[i0 + j] += lp * amp * exp(-float(j) / maxf(float(dur), 1.0) * 4.0) * 0.5
	return out

## A close burst on the drone's microphone: a low rolling rumble with no sharp edge.
func _snd_rumble() -> PackedFloat32Array:
	var sec := 2.8
	var out := _buffer(sec)
	var n := out.size()
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t: float = float(i) / RATE
		var u: float = t / sec
		var env: float = smoothstep(0.0, 0.08, u) * pow(1.0 - u, 1.4)
		var w: float = _rng.randf() * 2.0 - 1.0
		lp += (w - lp) * 0.045
		lp2 += (lp - lp2) * 0.10
		out[i] = clampf(lp2 * 9.0 * env, -1.0, 1.0)
	return out

func _build_sound() -> void:
	_bus("FireworksG", "Ground")
	_bus("FireworksM", "Onboard")
	var gi := AudioServer.get_bus_index("FireworksG")
	if gi >= 0 and AudioServer.get_bus_effect_count(gi) == 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 3200.0
		AudioServer.add_bus_effect(gi, lp)
		# the valley answers a break: a short open-air reverb so a show has depth instead of dry pops
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.72
		rv.damping = 0.45
		rv.wet = 0.22
		rv.dry = 1.0
		rv.predelay_msec = 45.0
		AudioServer.add_bus_effect(gi, rv)
	for i in 12:
		var p := AudioStreamPlayer3D.new()
		p.bus = "FireworksG"
		p.unit_size = 55.0
		p.max_distance = 9000.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(p)
		_g_players.append(p)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "FireworksM"
		add_child(p)
		_m_players.append(p)
	# the synthesised sounds are the fallback; the asset files (tools/gen_firework_audio.gd) replace them when present
	_sounds = {
		"lift": _wav(_snd_launch()),
		"whoosh": _wav(_snd_launch()),
		"burst_near_a": _wav(_snd_thump(false)),
		"burst_near_b": _wav(_snd_thump(false)),
		"burst_mid": _wav(_snd_thump(false)),
		"burst_far_a": _wav(_snd_thump(true)),
		"burst_far_b": _wav(_snd_thump(true)),
		"salute_near": _wav(_snd_thump(false)),
		"crackle_a": _wav(_snd_crackle()),
		"crackle_b": _wav(_snd_crackle()),
		"rumble_close": _wav(_snd_rumble()),
	}
	_load_audio_assets()

## Load the real generated files over the synthesised fallback. Any file can be replaced by a real recording with the
## same name; the game does not care how the sound was made.
func _load_audio_assets() -> void:
	var dir := DirAccess.open("res://assets/audio/fireworks")
	if dir == null:
		return
	var loaded := 0
	for f in dir.get_files():
		if not f.ends_with(".wav"):
			continue
		var st := load("res://assets/audio/fireworks/" + f) as AudioStreamWAV
		if st != null:
			_sounds[f.get_basename()] = st
			loaded += 1
	if loaded > 0:
		print("fireworks: loaded ", loaded, " sound asset files")

func _bus(name: String, send: String) -> void:
	if AudioServer.get_bus_index(name) >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, name)
	AudioServer.set_bus_send(i, send)

## Add a sound to be played after `delay` seconds (the light comes first). Ground: a 3D source at `pos`, heard from
## the pilot with distance attenuation. Mic: a 2D source on the Onboard bus, sampled by the drone's microphone.
## A show heard from far away loses level faster than the 3D attenuation alone (air and ground), and past 6 km a
## break is not heard at all: by then it is only a soft delayed roll, if anything.
func _hear(what: String, pos: Vector3, vol: float, d_ground: float, d_mic: float) -> void:
	if not _sounds.has(what):
		return
	if d_ground < 6000.0:
		var far_k: float = clampf(1600.0 / maxf(d_ground, 200.0), 0.22, 1.0)
		_max_delay = maxf(_max_delay, d_ground / 343.0)
		_pending.append({"t": minf(d_ground / 343.0, 9.0), "what": what, "pos": pos, "ground": true, "vol": vol * far_k, "gain": 0.0})
	var gain: float = clampf(70.0 / maxf(d_mic, 25.0), 0.03, 0.9) * vol * clampf(3000.0 / maxf(d_mic, 100.0), 0.15, 1.0)
	_pending.append({"t": minf(d_mic / 343.0, 9.0), "what": what, "pos": Vector3.ZERO, "ground": false, "vol": vol, "gain": gain})
	if _pending.size() > 48:
		_pending = _pending.slice(_pending.size() - 48)

func _play(what: String, pos: Vector3, ground: bool, gain: float, vol: float) -> void:
	var s: AudioStream = _sounds.get(what)
	if s == null:
		return
	if ground:
		for p in _g_players:
			if not p.playing:
				p.stream = s
				p.global_position = pos
				p.volume_db = linear_to_db(clampf(vol, 0.01, 2.5))
				p.play()
				return
	else:
		for p in _m_players:
			if not p.playing:
				p.stream = s
				p.volume_db = linear_to_db(maxf(gain, 0.001))
				p.play()
				return

func _tick_pending(delta: float) -> void:
	var keep: Array = []
	for s in _pending:
		var t: float = float(s["t"]) - delta
		if t <= 0.0:
			_play(str(s["what"]), s["pos"], bool(s["ground"]), float(s["gain"]), float(s["vol"]))
		else:
			s["t"] = t
			keep.append(s)
	_pending = keep

# ------------------------------------------------------------------ shows
## One shell break on the show timeline. The calibre (inches) sets the burst size, the height it breaks at and the rise
## time: a 3 inch shell is a quick small break low down, an 8 inch shell climbs for six seconds and fills the sky.
func _make_ev(rng: RandomNumberGenerator, t: float, ty: int, col: String, calibre: float) -> Dictionary:
	var h: float = 105.0 + 16.0 * calibre + rng.randf() * 24.0
	var pos := Vector3(
		SHOW_CENTRE.x + (rng.randf() * 2.0 - 1.0) * 135.0,
		Lake.LEVEL + h,
		SHOW_CENTRE.y + (rng.randf() * 2.0 - 1.0) * 135.0)
	var size: float = 0.55 + 0.11 * calibre
	return {"t": t, "type": ty, "pos": pos, "col": col, "size": size, "calibre": calibre,
		"rise": 3.2 + 0.36 * calibre + rng.randf() * 0.3, "launched": false}

func _sort_ev(a: Dictionary, b: Dictionary) -> bool:
	return float(a["t"]) < float(b["t"])

func _roof_ty(hi: bool, rng: RandomNumberGenerator) -> int:
	# the shells that carry most of a show, with the newer effects mixed in
	var common: Array = [PEONY, CHRYS, WILLOW, RING, HEART, PALM, CROSSETTE, FISH]
	var big: Array = [CHRYS, WILLOW, PALM, CROSSETTE, STROBE, HORSETAIL]
	return big[rng.randi() % big.size()] if hi else common[rng.randi() % common.size()]

func _build_shows() -> void:
	var cols: Array = ["gold", "red", "green", "blue", "white", "purple", "two"]
	# 1. build up: three minutes, single small gold shells first, big breaks and salutes in the last twenty seconds
	var rng := RandomNumberGenerator.new()
	rng.seed = 9101
	var s1: Array = []
	var t := 3.0
	while t < 42.0:
		s1.append(_make_ev(rng, t, PEONY, "gold", CALIBRES[rng.randi() % 2]))
		t += 6.0 + rng.randf() * 2.0
	t = 46.0
	while t < 108.0:
		s1.append(_make_ev(rng, t, _roof_ty(rng.randf() < 0.25, rng), cols[rng.randi() % cols.size()], CALIBRES[rng.randi() % 4]))
		t += 3.0 + rng.randf() * 2.0
	t = 110.0
	while t < 160.0:
		s1.append(_make_ev(rng, t, _roof_ty(rng.randf() < 0.4, rng), cols[rng.randi() % cols.size()], CALIBRES[1 + rng.randi() % 4]))
		t += 1.6 + rng.randf() * 1.0
	t = 160.0
	while t < 179.0:
		var ty: int = SALUTE if rng.randf() < 0.18 else (FINALE if rng.randf() < 0.4 else _roof_ty(true, rng))
		s1.append(_make_ev(rng, t, ty, ["gold", "white", "red", "green"][rng.randi() % 4], CALIBRES[3 + rng.randi() % 2]))
		t += 0.8 + rng.randf() * 0.6
	s1.sort_custom(_sort_ev)
	# 2. quiet night: ninety seconds of slow, big, soft breaks
	rng.seed = 9202
	var s2: Array = []
	var qcol: Array = ["gold", "white", "blue", "purple", "warm"]
	t = 4.0
	while t < 88.0:
		var ty3: int = [WILLOW, RING, HEART, PALM, CHRYS, FISH, HORSETAIL][rng.randi() % 7]
		s2.append(_make_ev(rng, t, ty3, qcol[rng.randi() % qcol.size()], CALIBRES[2 + rng.randi() % 3]))
		t += 4.0 + rng.randf() * 2.5
	s2.sort_custom(_sort_ev)
	# 3. finale: twenty seconds of everything, salutes and the big finale shell
	rng.seed = 9303
	var s3: Array = []
	t = 0.6
	while t < 19.0:
		var ty4: int = SALUTE if rng.randf() < 0.12 else [PEONY, CHRYS, CRACKLE, FINALE, RING, HEART, CROSSETTE, STROBE][rng.randi() % 8]
		s3.append(_make_ev(rng, t, ty4, cols[rng.randi() % cols.size()], CALIBRES[2 + rng.randi() % 3]))
		t += 0.55 + rng.randf() * 0.4
	s3.sort_custom(_sort_ev)
	_shows = [
		{"dur": 180.0, "events": s1},
		{"dur": 90.0, "events": s2},
		{"dur": 20.0, "events": s3},
	]

## "Fireworks show" in the pause menu. 0 stops a running show. In daylight the game moves the clock; the show then
## starts as soon as it is dark.
func request_show(i: int) -> void:
	if i <= 0:
		_pending_show = 0
		if _running:
			_stop_show(false)
		return
	if _sun_el > -4.0:
		_pending_show = i
		toast.emit("It is still light. The clock moves to half past nine.")
		night_needed.emit()
		return
	_start_show(i)

## Test hook: `fireworks<1..3>` in a shot run starts a show even in daylight.
func force_show(i: int) -> void:
	_pending_show = 0
	_start_show(i)

func _start_show(i: int) -> void:
	if i < 1 or i > _shows.size():
		return
	if _running:
		_stop_show(false)
	_show_ev = (_shows[i - 1]["events"] as Array).duplicate(true)
	_show_dur = float(_shows[i - 1]["dur"])
	_show_t = 0.0
	_running = true
	toast.emit("The show is starting.")

func _stop_show(finished: bool) -> void:
	_running = false
	_show_t = 0.0
	_breaks.clear()
	for ev in _show_ev:
		ev["launched"] = true
	for ty in TYPES:
		for p in _emitters[ty]:
			(p as GPUParticles3D).emitting = false
	for s in _smoke_emitters:
		s.emitting = false
	for i in _flashes.size():
		_flash_t[i] = 0.0
		_flashes[i].visible = false
		_flash_mats[i].set_shader_parameter("alpha", 0.0)
	for sh in _shells:
		sh.active = false
		if sh.node:
			sh.node.visible = false
			sh.trail.emitting = false
			sh.smoke.emitting = false
			sh.whistle.stop()
	if finished:
		toast.emit("The show is over.")
		show_ended.emit()

## Test hook: jump the show clock forward (used with `fwskip<seconds>` in a shot run).
func skip_to(seconds: float) -> void:
	if not _running:
		return
	_show_t = maxf(_show_t, seconds)
	for ev in _show_ev:
		if bool(ev["launched"]):
			continue
		var bt: float = float(ev["t"])
		if bt <= _show_t + 2.0 and bt >= _show_t - 3.5:
			# a burst that would be in the air right now starts straight away, so a single screenshot catches it
			ev["launched"] = true
			_burst(ev["pos"], int(ev["type"]), str(ev["col"]), float(ev["size"]), float(ev["calibre"]))
		elif bt < _show_t - 3.5:
			ev["launched"] = true

func _check_surprise() -> void:
	if not surprise_on or _running or _pending_show > 0:
		return
	if _hour < 21.30 or _hour > 21.45:
		return
	if _doy % 9 != 4:
		return
	if _surprise_doy == _doy:
		return
	_surprise_doy = _doy
	_start_show(1)
	toast.emit("A fireworks show starts over the lake.")

# ------------------------------------------------------------------ shells and bursts
func _free_shell() -> Shell:
	for s in _shells:
		if not s.active:
			return s
	return null

func _launch(ev: Dictionary) -> void:
	var s := _free_shell()
	if s == null:
		return
	var bi: int = _rng.randi() % _barges.size()
	var tube: int = _rng.randi() % 20
	var mouth: Vector3 = _tube_mouths[bi * 20 + tube]
	var target: Vector3 = ev["pos"]
	var rise: float = float(ev["rise"])
	var g := 9.8
	s.mouth = mouth
	s.target = target
	s.vel = Vector3(
		(target.x - mouth.x) / rise,
		(target.y - mouth.y + 0.5 * g * rise * rise) / rise,
		(target.z - mouth.z) / rise)
	s.t = 0.0
	s.rise = rise
	s.type = int(ev["type"])
	s.col = str(ev["col"])
	s.size = float(ev["size"])
	s.calibre = float(ev.get("calibre", 5.0))
	s.sparky = _rng.randf() < 0.22          # the odd comet shell, the rest are dark until they break
	s.active = true
	s.node.visible = true
	s.mesh.visible = true
	s.node.global_position = mouth
	s.trail.emitting = true
	s.trail.amount_ratio = 1.0 if s.sparky else 0.32
	s.smoke.emitting = true
	s.smoke.restart()
	_launch_fx(mouth, s.sparky)
	var dg: float = mouth.distance_to(_pilot_pos_ground)
	var dm: float = mouth.distance_to(_drone)
	_hear("lift_near", mouth, 0.55, dg, dm)
	_hear("whoosh_near", mouth, 0.45, dg, dm)
	# the odd whistling shell: a loop riding with the shell until it breaks
	if _rng.randf() < 0.28 and _sounds.has("whistle_up"):
		s.whistle.stream = _sounds["whistle_down"] if _rng.randf() < 0.5 else _sounds["whistle_up"]
		s.whistle.pitch_scale = clampf(1.18 - 0.05 * s.calibre, 0.7, 1.1)
		s.whistle.volume_db = -9.0
		s.whistle.play()

## The lift charge: a flash and a puff of smoke at the mouth of the tube, a few sparks up after the shell, and (for
## the odd comet shell) the sparks that the shell carries up with it.
func _launch_fx(mouth: Vector3, sparky: bool) -> void:
	var l := _lights[_light_next % _lights.size()]
	_light_next += 1
	l.global_position = mouth + Vector3(0.0, 1.0, 0.0)
	l.light_color = Color(1.0, 0.72, 0.42)
	l.light_energy = 190.0
	l.omni_range = 170.0
	l.visible = true
	var sm := _tube_smoke[_tube_next % _tube_smoke.size()]
	_tube_next += 1
	sm.global_position = mouth + Vector3(0.0, 0.6, 0.0)
	sm.emitting = false
	sm.restart()
	sm.emitting = true
	var sp := _lift_sparks[_lift_next % _lift_sparks.size()]
	_lift_next += 1
	sp.global_position = mouth
	sp.amount_ratio = 1.0 if sparky else 0.55
	sp.emitting = false
	sp.restart()
	sp.emitting = true

func _update_shells(delta: float) -> void:
	for s in _shells:
		if not s.active:
			continue
		s.t += delta
		var t: float = s.t
		var p: Vector3 = s.mouth + s.vel * t - Vector3(0.0, 0.5 * 9.8 * t * t, 0.0)
		s.node.global_position = p
		if t >= s.rise:
			_burst(s.target, s.type, s.col, s.size, s.calibre)
			s.active = false
			s.mesh.visible = false                     # the casing is gone, the smoke and embers stay in the sky
			s.trail.emitting = false
			s.smoke.emitting = false
			s.whistle.stop()

func _lin(c: Color) -> Color:
	return c.srgb_to_linear()

func _burst(pos: Vector3, ty: int, col: String, size: float, calibre := 5.0) -> void:
	var set: Array = COLOURS.get(col, COLOURS["gold"])
	var ca: Color = _lin(set[0])
	var cb: Color = _lin(set[1])
	var ember: Color = _lin(Color(1.0, 0.42, 0.10))
	if ty == SALUTE:
		# flash powder only: a very short white-lime flash, no stars
		_flash(pos, Color(1.0, 0.95, 0.85), size * 1.4)
		_flash_glow(pos, Color(1.0, 0.95, 0.85), size * 1.5)
		_sensor_glare(pos, Color(1.0, 0.95, 0.85), size * 1.5)
		_sound_burst(pos, ty, size * 1.3, calibre)
		return
	var list: Array = _emitters[ty]
	var p: GPUParticles3D = null
	for cand in list:
		var cp := cand as GPUParticles3D
		if not cp.emitting:
			p = cp
			break
	if p == null:
		p = list[_next_of_type[ty] % list.size()]
		_next_of_type[ty] += 1
	p.global_position = pos
	var pm := p.process_material as ShaderMaterial
	pm.set_shader_parameter("col_a", Vector3(ca.r, ca.g, ca.b))
	pm.set_shader_parameter("col_b", Vector3(cb.r, cb.g, cb.b))
	pm.set_shader_parameter("col_c", Vector3(ember.r, ember.g, ember.b))
	pm.set_shader_parameter("radius", size)
	pm.set_shader_parameter("speed", SPEED[ty] * (0.85 + 0.25 * size))
	pm.set_shader_parameter("plane_n", _plane_normal(pos))
	pm.set_shader_parameter("seed_off", float(_rng.randi_range(1, 1000000)))
	var share: float = clampf(size / 1.3, 0.55, 1.0)
	p.amount_ratio = share
	_sparks_now += int(float(AMOUNT[ty]) * share)
	p.emitting = false
	p.restart()
	p.emitting = true
	_flash(pos, ca, size)
	_flash_glow(pos, ca, size)
	_sensor_glare(pos, ca, size)
	_smoke(pos)
	_sound_burst(pos, ty, size, calibre)
	# big shells sometimes break twice: a second, smaller break a moment later and a little to the side
	if calibre >= 5.0 and ty != CRACKLE and _rng.randf() < 0.22:
		var d := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.3, 0.8), _rng.randf_range(-1.0, 1.0)) * 34.0 * size
		var ty2: int = [PEONY, CHRYS, RING, CRACKLE, CROSSETTE, STROBE][_rng.randi() % 6]
		_breaks.append({"t": 0.40 + _rng.randf() * 0.35, "pos": pos + d, "ty": ty2, "col": col, "size": size * 0.7, "calibre": calibre * 0.8})

## The pending second breaks of multi-break shells, a fraction of a second after the first.
func _tick_breaks(delta: float) -> void:
	if _breaks.is_empty():
		return
	var keep: Array = []
	for b in _breaks:
		var t: float = float(b["t"]) - delta
		if t <= 0.0:
			_burst(b["pos"], int(b["ty"]), str(b["col"]), float(b["size"]), float(b["calibre"]))
		else:
			b["t"] = t
			keep.append(b)
	_breaks = keep

## The burst in the camera: a lens flash, streak and ghost plus a short exposure dip (SensorPipeline.burst_glare).
## Strength falls off with distance from the pilot, so a far show glints without washing the picture out.
func _sensor_glare(pos: Vector3, col: Color, size: float) -> void:
	if _sensor == null or not _sensor.has_method("burst_glare"):
		return
	var d: float = pos.distance_to(_pilot_pos_ground)
	var k: float = (0.35 + 0.65 * clampf(size - 0.6, 0.0, 1.2)) * clampf(1.55 - d / 1500.0, 0.12, 1.2)
	_sensor.burst_glare(pos, col, k)

## The first visible flash at the burst point: a soft bright glow that fades in a quarter of a second.
func _flash_glow(pos: Vector3, col: Color, size: float) -> void:
	var i: int = _flash_next % _flashes.size()
	_flash_next += 1
	var m := _flashes[i]
	m.global_position = pos
	m.scale = Vector3.ONE * (40.0 * size + 16.0)
	var mat := _flash_mats[i]
	mat.set_shader_parameter("flash_colour", Vector3(col.r, col.g, col.b))
	mat.set_shader_parameter("alpha", 0.55)
	_flash_t[i] = 0.38
	m.visible = true

## The plane a ring or heart faces: the camera if it is close enough to see the face, otherwise the park.
func _plane_normal(pos: Vector3) -> Vector3:
	var eye := _cam_pos if _cam_pos.distance_to(pos) < 1400.0 else _pilot_pos_ground
	var d := Vector3(eye.x - pos.x, 0.0, eye.z - pos.z)
	if d.length() < 1.0:
		return Vector3(0.0, 0.0, 1.0)
	return d.normalized()

func _flash(pos: Vector3, col: Color, size: float) -> void:
	var l := _lights[_light_next % _lights.size()]
	_light_next += 1
	l.global_position = pos
	l.light_color = Color(col.r, col.g, col.b)
	l.light_energy = 500.0 + 340.0 * size
	l.omni_range = 620.0 + 200.0 * size
	l.visible = true

func _smoke(pos: Vector3) -> void:
	var s := _smoke_emitters[_smoke_next % _smoke_emitters.size()]
	_smoke_next += 1
	s.global_position = pos
	s.emitting = false
	s.restart()
	s.emitting = true

func _sound_burst(pos: Vector3, ty: int, size: float, calibre: float) -> void:
	var dg: float = pos.distance_to(_pilot_pos_ground)
	var dm: float = pos.distance_to(_drone)
	var k: float = clampf(calibre / 8.0, 0.35, 1.0)
	var vol: float = (0.55 + 0.55 * k) * clampf(size, 0.7, 1.5)
	var a: bool = _rng.randf() < 0.5
	# three distance flavours: near keeps the crack, mid has lost the top and the first echo, far is a rolling boom
	if dg < 280.0:
		_snd_bands["near"] += 1
		_hear("burst_near_b" if a else "burst_near_a", pos, vol, dg, dm)
	elif dg < 950.0:
		_snd_bands["mid"] += 1
		_hear("burst_mid", pos, vol, dg, dm)
	else:
		_snd_bands["far"] += 1
		_hear("burst_far_a" if a else "burst_far_b", pos, vol, dg, dm)
	if calibre < 4.0 or ty == CRACKLE:
		_hear("salute_near", pos, 0.45 * vol, dg, dm)      # small shells and crackle shells report sharper
	if ty == CRACKLE or ty == FINALE:
		_hear("crackle_b" if a else "crackle_a", pos, 0.55 * vol, dg, dm)
	# a burst close to the drone rumbles on the microphone
	if dm < 110.0:
		_hear("rumble_close", pos, 0.9 * clampf(1.0 - dm / 110.0, 0.15, 1.0), dg, dm)

func _tick_lights(delta: float) -> void:
	var best := 0.0
	var best_c := Color(0.0, 0.0, 0.0)
	for l in _lights:
		if l.light_energy > 0.01:
			l.light_energy *= exp(-delta / 0.55)
			if l.light_energy > best:
				best = l.light_energy
				best_c = l.light_color
		else:
			l.light_energy = 0.0
			l.visible = false
	for i in _flashes.size():
		if _flash_t[i] <= 0.0:
			continue
		_flash_t[i] -= delta
		if _flash_t[i] <= 0.0:
			_flashes[i].visible = false
			_flash_mats[i].set_shader_parameter("alpha", 0.0)
		else:
			_flash_mats[i].set_shader_parameter("alpha", 0.55 * pow(_flash_t[i] / 0.38, 1.6))
	var k: float = clampf(best / 1400.0, 0.0, 1.0)
	var lin: Color = _lin(best_c)
	RenderingServer.global_shader_parameter_set("g_fire", Vector4(lin.r, lin.g, lin.b, k))

# ------------------------------------------------------------------ per frame
func _update_px(cam: Camera3D) -> void:
	var vp_h := 720.0
	if cam.get_viewport():
		vp_h = cam.get_viewport().get_visible_rect().size.y
	var ppm: float = 2.0 * tan(deg_to_rad(cam.fov) * 0.5) / maxf(vp_h, 1.0)
	for m in _draw_mats:
		m.set_shader_parameter("px_per_m", ppm)
	for m in _flash_mats:
		m.set_shader_parameter("px_per_m", ppm)

## Called every frame by main.gd after the camera is placed. `paused` freezes the show, like the game's own clock.
func update(delta: float, cam: Camera3D, drone_pos: Vector3, sun_el: float, hour: float, doy: int, paused: bool) -> void:
	if not _mounted:
		return
	_sun_el = sun_el
	_hour = hour
	_doy = doy
	_drone = drone_pos
	_cam_pos = cam.global_position
	_update_px(cam)
	if paused:
		return
	_tick_pending(delta)
	_tick_breaks(delta)
	if _pending_show > 0 and _sun_el <= -4.0:
		var idx := _pending_show
		_pending_show = 0
		_start_show(idx)
	_tick_lights(delta)
	if not _running:
		_check_surprise()
		return
	_show_t += delta
	for ev in _show_ev:
		if bool(ev["launched"]):
			continue
		if _show_t >= float(ev["t"]) - float(ev["rise"]):
			ev["launched"] = true
			_launch(ev)
	_update_shells(delta)
	if _show_t >= _show_dur:
		_stop_show(true)

## Small read-out for a headless check: how many sparks and lights are alive.
func stats() -> Dictionary:
	return {"running": _running, "show_t": _show_t, "sun_el": _sun_el, "pending_sounds": _pending.size(),
		"max_sound_delay_s": snappedf(_max_delay, 0.01), "sound_bands": _snd_bands.duplicate(),
		"sparks_cap": _max_sparks, "mobile": _mobile}

## Dev hooks for judging the look in a screenshot run: `fwwall` fires one burst of every type in a row 190 m
## ahead, `fwburst<0..7>` fires one, `nosmoke` hides the smoke so the sparks can be seen alone.
func test_wall(from: Vector3, fwd: Vector3, right: Vector3) -> void:
	var sets: Array = ["gold", "red", "green", "blue", "white", "purple", "two", "warm"]
	for i in TYPES:
		if i == SALUTE:
			continue
		var pos: Vector3 = from + fwd * 190.0 + right * (float(i - 5) * 46.0) + Vector3(0.0, 30.0 + 0.06 * float(i * i), 0.0)
		_burst(pos, i, sets[i % sets.size()], 1.15, 6.0)

func test_burst(ty: int, from: Vector3, fwd: Vector3) -> void:
	_burst(from + fwd * 170.0 + Vector3(0.0, 25.0, 0.0), clampi(ty, 0, TYPES - 1), "gold", 1.15)

func set_smoke(on: bool) -> void:
	for s in _smoke_emitters:
		s.visible = on

func set_sensor(s: SensorPipeline) -> void:
	_sensor = s

## Dev hook (`fwlaunch`): one shell lifted from a barge to 150 m above a point 220 m ahead, so a screenshot run can
## catch the dark shell with its smoke trail on the way up, and the burst after it.
func test_launch(from: Vector3, fwd: Vector3) -> void:
	var target: Vector3 = from + fwd * 220.0 + Vector3(0.0, 150.0, 0.0)
	_launch({"pos": target, "rise": 4.6, "type": PEONY, "col": "gold", "size": 1.15, "calibre": 6.0})

## Dev hook (`fwbig<n>`): one burst of type n 140 m ahead and 45 m up, close enough to study its flash on the lens,
## the metering and the exposure recovery.
## Dev hook (`fwfar`): one break about 1.6 km from the pilot, to prove the far distance sound flavour and the long
## light-to-sound delay (about 4.7 s at 343 m/s).
func test_far() -> void:
	_burst(Vector3(-1660.0, Lake.LEVEL + 180.0, 100.0), PEONY, "gold", 1.3, 8.0)

func test_big(ty: int, from: Vector3, fwd: Vector3) -> void:
	_burst(from + fwd * 140.0 + Vector3(0.0, 45.0, 0.0), clampi(ty, 0, TYPES - 1), "gold", 1.45)

func test_smoke(from: Vector3, fwd: Vector3) -> void:
	var pos: Vector3 = from + fwd * 150.0 + Vector3(0.0, 40.0, 0.0)
	for i in 3:
		_smoke(pos + Vector3(float(i) * 34.0 - 34.0, 0.0, 0.0))

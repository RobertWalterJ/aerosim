class_name DroneAudio
extends Node
## What the drone sounds like, and the valley around it. Four motors with five harmonics each (one harmonic-rich loop
## played four times, pitched from each motor's blade-pass frequency), blade-vortex slap in descents and turbulence, wind
## buffet on the microphone at speed, rotor wash on the grass, a short slapback off the ground, and the sound of wind in spruce
## and in autumn leaves. Birds follow a calm, alert and flush pattern: chickadee, robin, blue jay and nuthatch sing in
## the trees; a crow and a hawk circle the valley. Three listening positions: Ground (the pilot at home, with distance and
## Doppler), Onboard (a microphone on the drone) and Cinematic Hybrid (a mix of both). Everything is synthesised at start-up.

const RATE := 44100
const PERSPECTIVES := ["Ground", "Onboard", "Cinematic Hybrid"]
const POOL := 16
const GRATE := 32000        # motor synth sample rate
const TAB := 2048           # one cycle of the motor note

var perspective := 2
var volume := 0.8
var enabled := true
var flushes := 0
signal bird_flush(pos: Vector3)

var _rng := RandomNumberGenerator.new()
var _motor_g: Array[AudioStreamPlayer3D] = []
var _motor_o: Array[AudioStreamPlayer] = []
var _pb_g: Array[AudioStreamGeneratorPlayback] = []
var _pb_o: Array[AudioStreamGeneratorPlayback] = []
var _tab_full := PackedFloat32Array()
var _tab_lite := PackedFloat32Array()
var _m_phase := PackedFloat64Array([0.0, 0.31, 0.57, 0.83])
var _m_freq := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
var _m_amp := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
var _m_tf := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
var _m_ta := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
var _hiss_lp := 0.0
var _wind_a: AudioStreamPlayer
var _wind_b: AudioStreamPlayer
var _wind_lp: AudioEffectLowPassFilter
var _slap_g: AudioStreamPlayer3D
var _slap_o: AudioStreamPlayer
var _wash_g: AudioStreamPlayer3D
var _wash_o: AudioStreamPlayer
var _buffet: AudioStreamPlayer
var _leaf: AudioStreamPlayer
var _spruce: AudioStreamPlayer
var _ground_lp: AudioEffectLowPassFilter
var _delay: AudioEffectDelay
var _pool: Array[AudioStreamPlayer3D] = []
var _pool_i := 0
var _emitters: Array = []        # {pos, species, state, next, silent_until}
var _soarers: Array = []
var _phrases := {}               # species -> Array[AudioStreamWAV]
var _alarm: AudioStreamWAV
var _flutter: AudioStreamWAV
var _crow: AudioStreamWAV
var _hawk: AudioStreamWAV
var _time := 0.0
var _listener: Camera3D   # the pilot's ears: a camera in the window itself (it draws nothing; the 3D view is rendered elsewhere)

## trees: [[x, y, z, height], ...] near the start. home: where the pilot stands (x, z).
func setup(drone: Node3D, pilot_pos: Vector3, trees: Array, arm: float, home: Vector2) -> void:
	_rng.seed = 88
	get_viewport().audio_listener_enable_3d = true
	_listener = Camera3D.new()
	_listener.position = pilot_pos
	add_child(_listener)
	_listener.current = true
	_build_buses()
	_tab_full = _motor_table(5)
	_tab_lite = _motor_table(2)
	var offs := [Vector3(arm, 0, -arm), Vector3(arm, 0, arm), Vector3(-arm, 0, arm), Vector3(-arm, 0, -arm)]
	for m in 4:
		var gs := AudioStreamGenerator.new(); gs.mix_rate = GRATE; gs.buffer_length = 0.1
		var g := _player3d(gs, "Ground", drone, offs[m], 6.0)
		g.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		_motor_g.append(g)
		var os := AudioStreamGenerator.new(); os.mix_rate = GRATE; os.buffer_length = 0.1
		_motor_o.append(_player(os, "Onboard"))
	var wind_wave := _loop(_wind_samples(), RATE)
	_wind_a = _player(wind_wave, "Wind")
	_wind_b = _player(wind_wave, "Wind")
	_wind_b.pitch_scale = 0.77
	_wind_a.volume_db = -80.0; _wind_b.volume_db = -80.0
	var slap := _loop(_noise_samples(51, 17.0, 0.85), RATE)
	_slap_g = _player3d(slap, "SlapG", drone, Vector3.ZERO, 5.0)
	_slap_o = _player(slap, "SlapO")
	var wash := _loop(_noise_samples(0, 0.0, 0.0), RATE)
	_wash_g = _player3d(wash, "WashG", drone, Vector3.ZERO, 4.0)
	_wash_o = _player(wash, "WashO")
	_buffet = _player(wash, "Buffet")
	_leaf = _player(_loop(_noise_samples(21, 7.0, 0.55), RATE), "Leaf")
	_spruce = _player(wash, "Spruce")
	for p in [_slap_g, _slap_o, _wash_g, _wash_o, _buffet, _leaf, _spruce]:
		p.volume_db = -80.0
	_build_birds(trees, home)
	set_perspective(perspective)
	for p in _motor_g:
		p.play(); _pb_g.append(p.get_stream_playback() as AudioStreamGeneratorPlayback)
	for p in _motor_o:
		p.play(); _pb_o.append(p.get_stream_playback() as AudioStreamGeneratorPlayback)
	_wind_a.play(); _wind_b.play(1.7)
	for p in [_slap_g, _slap_o, _wash_g, _wash_o, _buffet, _leaf, _spruce]: p.play()

## Move the four motor sound sources when the drone changes (longer arms on a bigger drone).
func set_arm(arm: float) -> void:
	var offs := [Vector3(arm, 0, -arm), Vector3(arm, 0, arm), Vector3(-arm, 0, arm), Vector3(-arm, 0, -arm)]
	for m in 4: _motor_g[m].position = offs[m]

func set_perspective(i: int) -> void:
	perspective = posmod(i, PERSPECTIVES.size())
	var g: float = [1.0, 0.0, 0.7][perspective]
	var o: float = [0.0, 1.0, 0.65][perspective]
	_set_bus("Ground", g); _set_bus("SlapG", g); _set_bus("WashG", g)
	_set_bus("Onboard", o); _set_bus("SlapO", o); _set_bus("WashO", o); _set_bus("Buffet", o)

func perspective_name() -> String:
	return PERSPECTIVES[perspective]

func cycle_perspective() -> String:
	set_perspective(perspective + 1)
	return perspective_name()

func set_volume(v: float) -> void:
	volume = v
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 1e-4)) if enabled else -80.0)

func set_enabled(on: bool) -> void:
	enabled = on
	set_volume(volume)

# ------------------------------------------------------------------ buses
func _set_bus(name: String, lin: float) -> void:
	var i := AudioServer.get_bus_index(name)
	if i >= 0: AudioServer.set_bus_volume_db(i, linear_to_db(maxf(lin, 1e-4)))

func _bus(name: String, send: String, effects: Array = []) -> void:
	if AudioServer.get_bus_index(name) >= 0: return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, name)
	AudioServer.set_bus_send(i, send)
	for e in effects: AudioServer.add_bus_effect(i, e)

func _bandpass(hz: float, q: float) -> AudioEffectBandPassFilter:
	var f := AudioEffectBandPassFilter.new(); f.cutoff_hz = hz; f.resonance = clampf(q * 0.7, 0.1, 4.0); return f

func _build_buses() -> void:
	var lim := AudioEffectLimiter.new()
	if AudioServer.get_bus_effect_count(0) == 0: AudioServer.add_bus_effect(0, lim)
	_ground_lp = AudioEffectLowPassFilter.new(); _ground_lp.cutoff_hz = 8000.0
	_bus("Ground", "Master", [_ground_lp])
	_delay = AudioEffectDelay.new(); _delay.dry = 1.0; _delay.tap1_active = true; _delay.tap1_delay_ms = 25.0; _delay.tap1_level_db = -80.0; _delay.tap2_active = false; _delay.feedback_active = true; _delay.feedback_level_db = -9.0
	var on_lp := AudioEffectLowPassFilter.new(); on_lp.cutoff_hz = 5200.0
	_bus("Onboard", "Master", [on_lp, _delay])
	_bus("SlapG", "Ground", [_bandpass(210.0, 1.4)])
	_bus("SlapO", "Onboard", [_bandpass(210.0, 1.4)])
	_bus("WashG", "Ground", [_bandpass(3200.0, 0.7)])
	_bus("WashO", "Onboard", [_bandpass(3200.0, 0.7)])
	var dist := AudioEffectDistortion.new(); dist.mode = AudioEffectDistortion.MODE_ATAN; dist.drive = 0.6
	_bus("Buffet", "Onboard", [_bandpass(110.0, 0.5), dist])
	_bus("Leaf", "Ambient", [_bandpass(1500.0, 0.6)])
	_bus("Spruce", "Ambient", [_bandpass(4200.0, 0.8)])
	_wind_lp = AudioEffectLowPassFilter.new(); _wind_lp.cutoff_hz = 500.0
	_bus("Wind", "Master", [_wind_lp])
	_bus("Ambient", "Master")
	_bus("Birds", "Master")

func _player(stream: AudioStream, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream; p.bus = bus
	add_child(p)
	return p

func _player3d(stream: AudioStream, bus: String, parent: Node3D, off: Vector3, unit: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream; p.bus = bus
	p.unit_size = unit; p.max_distance = 4000.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	p.position = off
	parent.add_child(p)
	return p

# ------------------------------------------------------------------ synthesis
func _loop(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var s := _wav(samples, rate)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0; s.loop_end = samples.size()
	return s

func _wav(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var bytes := PackedByteArray(); bytes.resize(samples.size() * 2)
	for i in samples.size(): bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = rate; w.stereo = false; w.data = bytes
	return w

## One cycle of a motor note: a sawtooth fundamental plus softer triangle harmonics. `n_h` harmonics (fewer at high pitch, so nothing folds back).
func _motor_table(n_h: int) -> PackedFloat32Array:
	var out := PackedFloat32Array(); out.resize(TAB)
	for i in TAB:
		var t := float(i) / TAB
		var v := 0.0
		for h in range(1, n_h + 1):
			var ph := fposmod(t * h, 1.0)
			var wave := 2.0 * (ph - 0.5) if h == 1 else 2.0 * absf(2.0 * fposmod(ph + 0.25, 1.0) - 1.0) - 1.0
			v += wave / pow(float(h), 1.15) * (1.3 if h == 1 else 1.0)
		out[i] = v * 0.2
	return out

## Four seconds of low, rolling wind: brown noise, with the ends blended so the loop has no seam.
func _wind_samples() -> PackedFloat32Array:
	var n := RATE * 4
	var raw := PackedFloat32Array(); raw.resize(n)
	var y := 0.0
	var peak := 0.001
	for i in n:
		y = y * 0.985 + (_rng.randf() * 2.0 - 1.0) * 0.12
		raw[i] = y
		peak = maxf(peak, absf(y))
	var xf := RATE / 2
	var out := PackedFloat32Array(); out.resize(n - xf)
	for i in n - xf:
		var v := raw[i]
		if i < xf:
			var k := float(i) / xf
			v = raw[i] * k + raw[n - xf + i] * (1.0 - k)
		out[i] = v / peak * 0.8
	return out

## Fill each motor's audio buffer, gliding smoothly from the last pitch and loudness to the new ones.
func _fill_motors() -> void:
	for m in 4:
		var n := mini(_pb_g[m].get_frames_available(), _pb_o[m].get_frames_available())
		n = mini(n, 1600)
		if n <= 0: continue
		var f1 := _m_freq[m]; var a1 := _m_amp[m]
		var f2 := _m_tf[m]; var a2 := _m_ta[m]
		var tab := _tab_full if f2 * 5.0 < 14000.0 else _tab_lite
		var buf := PackedVector2Array(); buf.resize(n)
		var ph := _m_phase[m]
		var lp := _hiss_lp
		var inv := 1.0 / GRATE
		for i in n:
			var k := float(i) / n
			var f := f1 + (f2 - f1) * k
			var a := a1 + (a2 - a1) * k
			ph += f * inv
			if ph >= 1.0: ph -= 1.0
			var x := ph * TAB
			var i0 := int(x)
			var fr := x - i0
			var v := tab[i0] * (1.0 - fr) + tab[(i0 + 1) & (TAB - 1)] * fr
			lp += ((_rng.randf() * 2.0 - 1.0) - lp) * 0.3
			var s := (v + lp * 0.16) * a
			buf[i] = Vector2(s, s)
		_m_phase[m] = ph
		_m_freq[m] = f2; _m_amp[m] = a2
		_hiss_lp = lp
		_pb_g[m].push_buffer(buf)
		var bo := PackedVector2Array(); bo.resize(n)
		for i in n: bo[i] = buf[i] * 0.708
		_pb_o[m].push_buffer(bo)

## Pink-ish noise, three seconds. `cycles` > 0 shapes it with that many steady pulses per three seconds (slap and rustle).
func _noise_samples(cycles: int, _rate_hz: float, depth: float) -> PackedFloat32Array:
	var n := RATE * 3
	var out := PackedFloat32Array(); out.resize(n)
	var b0 := 0.0; var b1 := 0.0; var b2 := 0.0
	for i in n:
		var w := _rng.randf() * 2.0 - 1.0
		b0 = 0.99765 * b0 + w * 0.099046; b1 = 0.963 * b1 + w * 0.2965164; b2 = 0.57 * b2 + w * 1.0526913
		var v := (b0 + b1 + b2 + w * 0.1848) * 0.18
		if cycles > 0:
			var ph := fposmod(float(i) / n * cycles, 1.0)
			v *= (1.0 - depth) + depth * (1.0 - ph)      # a sawtooth pulse
		out[i] = v
	return out

## Add a bird note into a buffer: a frequency glide from f0 to f1 with a quick attack and an exponential fade.
func _note(buf: PackedFloat32Array, t0: float, f0: float, f1: float, dur: float, vol: float, kind := "sine", vib := 0.0) -> void:
	var i0 := int(t0 * RATE)
	var n := int(dur * RATE)
	var phase := 0.0
	for k in n:
		if i0 + k >= buf.size(): break
		var u := float(k) / n
		var f := f0 * pow(maxf(f1, 50.0) / f0, u)
		if vib > 0.0: f += f0 * vib * sin(TAU * 38.0 * float(k) / RATE)
		phase += f / RATE
		var ph := fposmod(phase, 1.0)
		var w := sin(TAU * ph)
		if kind == "square": w = 1.0 if ph < 0.5 else -1.0
		elif kind == "saw": w = 2.0 * ph - 1.0
		var env := minf(1.0, float(k) / (0.012 * RATE)) * pow(0.0001, u)
		buf[i0 + k] += w * env * vol * 0.5

func _buffer(length: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(length * RATE))
	return buf

func _phrase_wave(sp: String, v: int, j: float) -> AudioStreamWAV:
	var b := _buffer(2.4)
	var r := _rng
	if sp == "chickadee":
		_note(b, 0.0, 3900 * j, 3850 * j, 0.32, 0.18)
		_note(b, 0.42, 3300 * j, 3250 * j, 0.42, 0.18)
		if v != 1:
			for i in 4: _note(b, 1.1 + i * 0.09, 3100 * j, 2700 * j, 0.06, 0.12, "square")
	elif sp == "robin":
		for i in 7:
			var f := (2200 + r.randf() * 1400) * j
			_note(b, i * 0.19, f, f * (0.8 + r.randf() * 0.5), 0.15, 0.16, "sine", 0.01)
	elif sp == "bluejay":
		for i in 3: _note(b, i * 0.28, 2300 * j, 1500 * j, 0.2, 0.1, "saw")
	else:
		for i in 4: _note(b, i * 0.2, 1350 * j, 1250 * j, 0.14, 0.12, "square")
	return _wav(b, RATE)

func _build_birds(trees: Array, home: Vector2) -> void:
	var r := _rng
	for sp in ["chickadee", "robin", "bluejay", "nuthatch"]:
		_phrases[sp] = []
		for v in 3:
			_phrases[sp].append(_phrase_wave(sp, v, 1.0 + (r.randf() - 0.5) * 0.16))
	var ab := _buffer(0.3)
	for i in 2: _note(ab, i * 0.07, 5200 + r.randf() * 500, 4300, 0.04, 0.2, "square")
	_alarm = _wav(ab, RATE)
	var fb := _buffer(0.8)
	for i in fb.size():
		fb[i] = (r.randf() * 2.0 - 1.0) * (0.5 + 0.5 * sin(TAU * 22.0 * float(i) / RATE)) * exp(-float(i) / RATE * 1.8) * 0.4
	_flutter = _wav(fb, RATE)
	var cb := _buffer(1.4)
	for i in 3: _note(cb, i * 0.42, 520, 380, 0.3, 0.55, "saw")
	_crow = _wav(cb, RATE)
	var hb := _buffer(1.8)
	_note(hb, 0.0, 3600, 1900, 1.6, 0.35, "saw", 0.01)
	_hawk = _wav(hb, RATE)
	for i in POOL:
		var p := AudioStreamPlayer3D.new()
		p.bus = "Birds"; p.unit_size = 5.0; p.max_distance = 600.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
		add_child(p); _pool.append(p)
	var species := ["chickadee", "robin", "bluejay", "nuthatch"]
	var near: Array = []
	for t in trees:
		if Vector2(t[0], t[2]).distance_to(home) < 260.0: near.append(t)
	for i in mini(60, near.size()):
		var t: Array = near[r.randi() % near.size()]
		_emitters.append({"pos": Vector3(t[0], t[1] + clampf(8.0 + r.randf() * 10.0, 8.0, t[3] * 0.85), t[2]), "species": species[r.randi() % 4], "state": "calm", "next": r.randf() * 6.0, "silent_until": 0.0})
	_soarers = [
		{"kind": "crow", "c": Vector2(-150, -100), "r": 380.0, "ang": 0.4, "w": 0.025, "alt": 160.0, "next": 6.0, "pos": Vector3.ZERO},
		{"kind": "hawk", "c": Vector2(-400, 200), "r": 520.0, "ang": 2.0, "w": -0.014, "alt": 230.0, "next": 20.0, "pos": Vector3.ZERO},
		{"kind": "crow", "c": Vector2(200, 300), "r": 300.0, "ang": 4.0, "w": 0.03, "alt": 140.0, "next": 12.0, "pos": Vector3.ZERO},
	]

func _voice(pos: Vector3, stream: AudioStream) -> void:
	var p := _pool[_pool_i % POOL]
	_pool_i += 1
	p.stream = stream; p.global_position = pos; p.play()

# ------------------------------------------------------------------ per frame
## a: motor_omega (4, rad/s), blades, thrust (0..1), vz, jerk, vrs, air_speed, drone_pos, drone_vel, agl, wash, wind, conifer, gust.
func update(a: Dictionary, dt: float) -> void:
	_time += dt
	var dpos: Vector3 = a["drone_pos"]
	var pilot := _listener.global_position
	var dist := dpos.distance_to(pilot)
	var air := 1.0 / (1.0 + dist / 120.0)
	_ground_lp.cutoff_hz = clampf(9000.0 * air + 900.0, 900.0, 9000.0)
	var thr: float = a["thrust"]
	var amp := 0.05 + 0.55 * thr * thr
	var omega: PackedFloat64Array = a["omega"]
	for m in 4:
		var f0: float = omega[m] / TAU * float(a["blades"])
		# each motor drifts a hair off the others, so the four beat against each other like real props
		var wob := 1.0 + m * 0.0013 + 0.0025 * sin(_time * (6.0 + m * 1.7) + m * 2.0)
		_m_tf[m] = clampf(f0 * wob, 25.0, 2600.0)
		_m_ta[m] = amp * 0.5
	_fill_motors()
	# blade-vortex slap in descents and turbulence
	var slap := clampf(maxf(0.0, -float(a["vz"]) - 1.5) * 0.12 + float(a["vrs"]) * 0.8 + float(a["jerk"]) * 0.0004, 0.0, 1.0)
	var sp := (14.0 + 40.0 * slap) / 17.0
	var sdb := linear_to_db(maxf(slap * 0.6, 1e-4))
	_slap_g.pitch_scale = sp; _slap_o.pitch_scale = sp; _slap_g.volume_db = sdb; _slap_o.volume_db = sdb
	# wind buffet on the microphone
	var air_speed: float = a["air_speed"]
	_buffet.volume_db = linear_to_db(maxf(clampf((air_speed * air_speed - 25.0) / 400.0, 0.0, 1.0) * 1.1, 1e-4))
	# rotor wash on the grass
	var wdb := linear_to_db(maxf(float(a["wash"]) * 0.5, 1e-4))
	_wash_g.volume_db = wdb; _wash_o.volume_db = wdb
	# slapback from the ground when low
	var agl: float = a["agl"]
	if agl < 12.0:
		_delay.tap1_delay_ms = clampf(2.0 * agl / 343.0, 0.015, 0.035) * 1000.0
		_delay.tap1_level_db = linear_to_db(maxf(0.28 * (1.0 - agl / 12.0), 1e-4))
	else:
		_delay.tap1_level_db = -80.0
	# wind in the trees
	var w := clampf(float(a["wind"]) / 9.0, 0.0, 1.0)
	var con: float = a["conifer"]
	var gust: float = a["gust"]
	_spruce.volume_db = linear_to_db(maxf(0.1 * w * (0.4 + con) * (0.6 + 0.4 * gust), 1e-4))
	_leaf.volume_db = linear_to_db(maxf(0.12 * w * (1.2 - con) * (0.5 + gust), 1e-4))
	# the wind itself: low and rolling, swelling with each gust, brighter when it blows hard
	var gw := clampf(float(a["wind"]) / 8.0, 0.0, 1.0)
	var swell := 0.55 + 0.45 * sin(_time * 0.37) * sin(_time * 0.11 + 1.0)
	var wl := clampf(0.05 + 0.75 * pow(gw, 1.3) * (0.6 + 0.4 * gust) * swell + 0.35 * clampf((air_speed - 4.0) / 14.0, 0.0, 1.0), 0.0, 1.0)
	_wind_a.volume_db = linear_to_db(maxf(wl * 0.55, 1e-4))
	_wind_b.volume_db = linear_to_db(maxf(wl * 0.4 * (0.6 + 0.4 * sin(_time * 0.23 + 2.0)), 1e-4))
	_wind_lp.cutoff_hz = 260.0 + 1700.0 * gw + 900.0 * clampf(air_speed / 20.0, 0.0, 1.0)
	_update_birds(dpos, dt, a["drone_vel"])

func _update_birds(dpos: Vector3, dt: float, _dvel: Vector3) -> void:
	for e in _emitters:
		var d: float = e["pos"].distance_to(dpos)
		if e["state"] == "silent":
			if _time > e["silent_until"]:
				e["state"] = "calm"; e["next"] = _time + 4.0
			continue
		if d > 140.0: continue
		if d <= 15.0:
			_voice(e["pos"], _flutter); flushes += 1; bird_flush.emit(e["pos"])
			e["state"] = "silent"; e["silent_until"] = _time + 60.0
			continue
		if d <= 35.0:
			if e["state"] != "alert":
				e["state"] = "alert"; e["next"] = _time
			if _time >= e["next"]:
				_voice(e["pos"], _alarm); e["next"] = _time + 0.5 + _rng.randf() * 0.7
		else:
			e["state"] = "calm"
			if _time >= e["next"]:
				var list: Array = _phrases[e["species"]]
				_voice(e["pos"], list[_rng.randi() % list.size()])
				e["next"] = _time + 3.0 + _rng.randf() * 9.0
	for s in _soarers:
		s["ang"] += s["w"] * dt
		var c: Vector2 = s["c"]
		s["pos"] = Vector3(c.x + cos(s["ang"]) * s["r"], s["alt"] + sin(s["ang"] * 3.0) * 14.0, c.y + sin(s["ang"]) * s["r"])
		if _time >= s["next"]:
			_voice(s["pos"], _crow if s["kind"] == "crow" else _hawk)
			s["next"] = _time + (9.0 + _rng.randf() * 18.0 if s["kind"] == "crow" else 25.0 + _rng.randf() * 25.0)

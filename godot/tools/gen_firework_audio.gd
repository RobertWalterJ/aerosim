extends SceneTree
## Generates the firework sound asset files in assets/audio/fireworks/ (session B).
## These are our own synthesised recordings, so the project owns them outright: no downloaded or licensed audio.
## Run from the godot folder with:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tools/gen_firework_audio.gd
##
## Design (grounded on how a show is heard from the park, and on the QMUL/outdoor-sound recipe of distance filtering
## plus a reverb tail):
##  - every sound comes in three distance flavours: near (wideband, sharp attack), mid (air absorption, 2.5 kHz low
##    pass, first echo) and far (600 Hz low pass, long rolling tail, two or three echoes). game/fireworks.gd picks the
##    flavour by the listener distance, so a far shell is a soft delayed boom without the crack.
##  - all files are mono 44.1 kHz 16 bit. Names are the keys game/fireworks.gd loads; drop a real recording over any
##    of them and it will be used, as long as the name stays the same.

const RATE := 44100
const DIR := "res://assets/audio/fireworks"

var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	rng.seed = 20261023
	_save("lift_near", _lift())
	_save("whoosh_near", _whoosh())
	_save("whistle_up", _whistle(620.0, 1150.0, 1.9), true)
	_save("whistle_down", _whistle(1250.0, 520.0, 2.1), true)
	_save("burst_near_a", _boom(2.1, 46.0, 1.0, 0.9, 3200.0, 0, 0.0))
	_save("burst_near_b", _boom(2.2, 52.0, 1.1, 1.0, 3600.0, 0, 0.0))
	_save("burst_mid", _boom(3.0, 42.0, 0.55, 1.5, 2500.0, 1, 0.33))
	_save("burst_far_a", _boom(4.0, 38.0, 0.12, 2.4, 600.0, 2, 0.55))
	_save("burst_far_b", _boom(4.4, 34.0, 0.10, 2.8, 500.0, 2, 0.62))
	_save("salute_near", _salute())
	_save("crackle_a", _crackle(2.4, 0.85))
	_save("crackle_b", _crackle(2.0, 0.65))
	_save("rumble_close", _rumble())
	print("firework audio: wrote 13 files to ", ProjectSettings.globalize_path(DIR))
	quit()

func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b

func _save(name: String, samples: PackedFloat32Array, looped := false) -> void:
	_normalise(samples, 0.86)
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if looped:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	w.save_to_wav(ProjectSettings.globalize_path(DIR + "/" + name + ".wav"))
	print("  ", name, ".wav  ", "%.2f" % (float(samples.size()) / RATE), " s")

func _normalise(b: PackedFloat32Array, peak: float) -> void:
	var m := 0.0001
	for i in b.size():
		m = maxf(m, absf(b[i]))
	var k: float = peak / m
	for i in b.size():
		b[i] = clampf(b[i] * k, -1.0, 1.0)

func _lowpass(b: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	var k: float = 1.0 - exp(-TAU * hz / RATE)
	var y := 0.0
	for i in b.size():
		y += (b[i] - y) * k
		b[i] = y
	return b

func _highpass(b: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	var k: float = 1.0 - exp(-TAU * hz / RATE)
	var y := 0.0
	for i in b.size():
		y += (b[i] - y) * k
		b[i] -= y
	return b

## The lift charge at the mortar: a deep thump, the tube ringing, and the hiss of the shell leaving.
func _lift() -> PackedFloat32Array:
	var sec := 1.0
	var out := _buf(sec)
	var n := out.size()
	var lp := 0.0
	for i in n:
		var t: float = float(i) / RATE
		var w: float = rng.randf() * 2.0 - 1.0
		lp += (w - lp) * 0.25
		var f: float = 58.0 - 20.0 * minf(t, 0.25)
		var body: float = sin(TAU * f * t) * exp(-t * 5.0)
		var tube: float = sin(TAU * 210.0 * t) * exp(-t * 18.0) * 0.35
		var hiss: float = lp * exp(-t * 2.6) * 0.9
		out[i] = clampf(body * 0.9 + tube + hiss, -1.0, 1.0)
	return out

## The air off the tube as the shell climbs: a soft rising whoosh.
func _whoosh() -> PackedFloat32Array:
	var sec := 1.3
	var out := _buf(sec)
	var n := out.size()
	var lp := 0.0
	var bp := 0.0
	for i in n:
		var t: float = float(i) / RATE
		var u: float = t / sec
		var env: float = smoothstep(0.0, 0.35, u) * pow(1.0 - u, 1.3)
		var w: float = rng.randf() * 2.0 - 1.0
		lp += (w - lp) * (0.05 + 0.25 * u)
		bp += (lp - bp) * 0.08
		out[i] = bp * 4.0 * env * 0.8
	return out

## A shell whistle. Loops cleanly (both ends fade to silence over a few ms) so it can ride with the shell.
func _whistle(f0: float, f1: float, sec: float) -> PackedFloat32Array:
	var out := _buf(sec)
	var n := out.size()
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var u: float = float(i) / float(n)
		var f: float = lerpf(f0, f1, u * u * (3.0 - 2.0 * u)) * (1.0 + 0.01 * sin(TAU * 7.0 * u))
		ph += f / RATE
		var w: float = rng.randf() * 2.0 - 1.0
		lp += (w - lp) * 0.35
		var tone: float = sin(TAU * ph) + 0.25 * sin(TAU * ph * 2.0) + 0.12 * sin(TAU * ph * 3.0)
		var edge: float = 0.15
		var env: float = smoothstep(0.0, edge, float(i) / RATE) * smoothstep(0.0, edge, (float(n - i) / RATE))
		out[i] = (tone * 0.35 + lp * 0.5) * env
	return out

## A shell break heard from a distance: sharp crack, deep body, rolling tail, then echoes.
## `band` 0 near, 1 mid, 2 far. `echo` is the delay of the first echo in seconds (0 = none).
func _boom(sec: float, sub_hz: float, crack: float, tail: float, lp_hz: float, band: int, echo: float) -> PackedFloat32Array:
	var out := _buf(sec)
	var n := out.size()
	var brown := 0.0
	var lp := 0.0
	var lp2 := 0.0
	var k: float = 1.0 - exp(-TAU * 9000.0 / RATE)
	for i in n:
		var t: float = float(i) / RATE
		var w: float = rng.randf() * 2.0 - 1.0
		brown = clampf(brown + w * 0.045, -0.9, 0.9) * 0.997
		lp += (w - lp) * k
		lp2 += (lp - lp2) * k
		var f: float = sub_hz * (1.0 - 0.30 * exp(-t * 6.0))
		var sub: float = sin(TAU * f * t) * exp(-t * 2.0)
		var punch: float = lp2 * exp(-t * 8.0) * 2.4
		var body: float = lp2 * exp(-t * 3.0) * 0.9
		var rumble: float = brown * exp(-t / maxf(tail, 0.2)) * 1.6
		var snap: float = w * exp(-t * 60.0) * crack
		out[i] = clampf(sub * 0.9 + punch * 0.55 + body * 0.35 + rumble * 0.9 + snap, -1.0, 1.0)
	if lp_hz < 8000.0:
		_lowpass(out, lp_hz)
		_lowpass(out, lp_hz)
	if band >= 1:
		_highpass(out, 26.0)
	if echo > 0.01:
		var d := int(echo * RATE)
		var e1 := out.duplicate()
		for i in range(d, n):
			out[i] += e1[i - d] * (0.32 if band == 1 else 0.42)
		if band >= 2:
			var d2 := int(echo * 2.2 * RATE)
			var e2 := e1.duplicate()
			for i in range(d2, n):
				out[i] += e2[i - d2] * 0.24
			var d3 := int(echo * 3.6 * RATE)
			for i in range(d3, n):
				out[i] += e2[i - d3] * 0.12
	if band >= 1:
		# the long low tail of a distant break
		var tailb := out.duplicate()
		_lowpass(tailb, 260.0)
		_lowpass(tailb, 260.0)
		for i in n:
			var t: float = float(i) / RATE
			out[i] += tailb[i] * exp(-t * 0.35) * 0.30
	return out

## A salute: flash powder, no bass, a hard flat crack and a short rattle.
func _salute() -> PackedFloat32Array:
	var sec := 1.2
	var out := _buf(sec)
	var n := out.size()
	var hp := 0.0
	var lp := 0.0
	for i in n:
		var t: float = float(i) / RATE
		var w: float = rng.randf() * 2.0 - 1.0
		hp += (w - hp) * 0.55
		lp += (w - lp) * 0.02
		var flat: float = (w - hp) * exp(-t * 9.0)
		var crack: float = w * exp(-t * 120.0)
		var body: float = lp * exp(-t * 4.0) * 0.8
		out[i] = clampf(crack * 1.1 + flat * 0.75 + body, -1.0, 1.0)
	return out

## The crackle tail: hundreds of small sharp snaps, denser at the start.
func _crackle(sec: float, density: float) -> PackedFloat32Array:
	var out := _buf(sec)
	var n := out.size()
	var count := int(900.0 * density)
	for k in count:
		var t0: float = pow(rng.randf(), 1.5) * (sec - 0.05)
		var i0 := int(t0 * RATE)
		var dur := int((0.006 + rng.randf() * 0.02) * RATE)
		var amp: float = (0.15 + rng.randf() * 0.85) * (1.0 - 0.6 * t0 / sec)
		var hp := 0.0
		for j in dur:
			if i0 + j >= n:
				break
			var w: float = rng.randf() * 2.0 - 1.0
			hp += (w - hp) * 0.75
			out[i0 + j] += (w - hp) * amp * exp(-float(j) / maxf(float(dur), 1.0) * 3.0) * 0.9
	return out

## What the drone's microphone hears from a break only tens of metres away: no crack, a low rolling chest thump.
func _rumble() -> PackedFloat32Array:
	var sec := 3.2
	var out := _buf(sec)
	var n := out.size()
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t: float = float(i) / RATE
		var u: float = t / sec
		var env: float = smoothstep(0.0, 0.04, u) * pow(1.0 - u, 1.3)
		var w: float = rng.randf() * 2.0 - 1.0
		lp += (w - lp) * 0.10
		lp2 += (lp - lp2) * 0.12
		var sub: float = sin(TAU * 38.0 * t) * exp(-t * 1.2) * 0.9
		out[i] = clampf(lp2 * 6.0 * env + sub * env * 0.8, -1.0, 1.0)
	return out

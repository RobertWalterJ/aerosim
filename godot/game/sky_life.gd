class_name SkyLife
extends Node3D
## Things that cross the sky or stand in the park for SPEC-EXTREME-WEATHER B6 (session B), using Claude's NewModels2
## batch 2: a rescue helicopter far off with its rotor sound, a distant airliner, a freight train on the far ridge with
## a horn heard late, kites on lines in the park and a flag near the chapel that waves in the wind.
##
## Both groups are switched from the Weather tab "Events" section ("Far traffic" and "Kites and flag"). Nothing here
## can be hit or hurt: the train and the helicopter are beyond the play area, and the kites and flag are scenery.

var terrain: Terrain
var wind: Wind
var far_traffic := false
var park_life := false
var _time := 0.0
var _heli: Node3D
var _heli_body: MeshInstance3D
var _heli_main: MeshInstance3D
var _heli_tail: MeshInstance3D
var _heli_pivots := {}
var _heli_spin := {"main": -1.0, "tail": -1.0}
var _heli_player: AudioStreamPlayer3D
var _airliner: MeshInstance3D
var _airliner_t := 0.0
var _train: Array[MeshInstance3D] = []
var _train_x := -900.0
var _train_line_z := -1560.0
var _train_track: MultiMeshInstance3D
var _horn: AudioStreamPlayer3D
var _horn_t := 20.0
var _horn_pending := -1.0
var _kites: Array = []
var _flag: Node3D
var _flag_cloth: MeshInstance3D
var _flag_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _rotor_stream: AudioStreamWAV
var _horn_stream: AudioStreamWAV

func setup(t: Terrain, w: Wind) -> void:
	terrain = t
	wind = w
	_rng.seed = 909
	_rotor_stream = _synth_rotor()
	_horn_stream = _synth_horn()

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

func _synth_rotor() -> AudioStreamWAV:
	var sec := 1.4
	var out := PackedFloat32Array(); out.resize(int(sec * 22050))
	for i in out.size():
		var t := float(i) / 22050.0
		var thump := sin(TAU * 14.0 * t + sin(TAU * 14.0 * t) * 0.9) * 0.35
		var whine := sin(TAU * 1450.0 * t) * 0.08 + sin(TAU * 2320.0 * t) * 0.04
		out[i] = clampf(thump + whine, -1.0, 1.0)
	return _wav(out, true)

func _synth_horn() -> AudioStreamWAV:
	var sec := 2.6
	var out := PackedFloat32Array(); out.resize(int(sec * 22050))
	for i in out.size():
		var t := float(i) / 22050.0
		var env := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(2.0, 2.6, t))
		var a := sin(TAU * 311.0 * t) + sin(TAU * 370.0 * t) * 0.8 + sin(TAU * 466.0 * t) * 0.35
		out[i] = clampf(a * env * 0.26, -1.0, 1.0)
	return _wav(out)

# ------------------------------------------------------------------ switches
func set_far_traffic(on: bool) -> void:
	if on == far_traffic:
		return
	far_traffic = on
	if on:
		_build_heli()
		_build_airliner()
		_build_train()
		if _heli_player and not _heli_player.playing:
			_heli_player.play()
	else:
		if _heli: _heli.visible = false
		if _airliner: _airliner.visible = false
		if _train_track: _train_track.visible = false
		for c in _train: c.visible = false
		if _heli_player: _heli_player.stop()

func set_park_life(on: bool) -> void:
	if on == park_life:
		return
	park_life = on
	if on:
		_build_kites()
		_build_flag()
	else:
		for k in _kites:
			(k["node"] as Node3D).visible = false
		if _flag: _flag.visible = false

# ------------------------------------------------------------------ helicopter and airliner
func _build_heli() -> void:
	if _heli != null:
		_heli.visible = true
		return
	var d := NewModels2.helicopter()
	_heli = Node3D.new()
	add_child(_heli)
	_heli_body = MeshInstance3D.new(); _heli_body.mesh = d["body"]
	_heli_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_heli.add_child(_heli_body)
	_heli_main = MeshInstance3D.new(); _heli_main.mesh = d["main_rotor"]
	_heli_main.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_heli.add_child(_heli_main)
	_heli_tail = MeshInstance3D.new(); _heli_tail.mesh = d["tail_rotor"]
	_heli_tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_heli.add_child(_heli_tail)
	_heli_pivots = {"main": d["rotor_pivot"], "tail": d["tail_pivot"]}
	_heli_main.position = d["rotor_pivot"]
	_heli_tail.position = d["tail_pivot"]
	_heli_spin = {"main": d["main_spin_sign"], "tail": d["tail_spin_sign"]}
	_heli_player = AudioStreamPlayer3D.new()
	_heli_player.bus = "Weather"
	_heli_player.stream = _rotor_stream
	_heli_player.unit_size = 80.0
	_heli_player.max_distance = 9000.0
	_heli_player.volume_db = -14.0
	_heli.add_child(_heli_player)
	_heli.position = Vector3(-420.0, 360.0, -380.0)

func _build_airliner() -> void:
	if _airliner != null:
		_airliner.visible = true
		return
	_airliner = MeshInstance3D.new()
	_airliner.mesh = NewModels2.airliner_far()["mesh"]   # airliner_far() returns a Dictionary since models4 (mesh, mesh_far, length, wingspan, height, gear)
	_airliner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_airliner)
	_airliner.position = Vector3(0.0, 950.0, 0.0)
	_airliner_t = 0.0

# ------------------------------------------------------------------ far train
func _build_train() -> void:
	if _train_track != null:
		_train_track.visible = true
		for c in _train: c.visible = true
		return
	var d := NewModels2.freight_train(7)
	var track: ArrayMesh = NewModels2.track_section()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = track
	var pieces := 92
	mm.instance_count = pieces
	var basis := Basis(Vector3.UP, PI * 0.5)
	for i in pieces:
		var x := _train_x + i * 20.0 - 900.0
		var y := terrain.height(x, _train_line_z) + 0.0
		mm.set_instance_transform(i, Transform3D(basis, Vector3(x, y, _train_line_z)))
	_train_track = MultiMeshInstance3D.new()
	_train_track.multimesh = mm
	_train_track.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_train_track)
	var kinds: Array = ["locomotive"]
	for i in 7:
		kinds.append(["boxcar", "hopper", "tanker", "flatcar"][i % 4])
	var x0 := _train_x
	for i in kinds.size():
		var mi := MeshInstance3D.new()
		mi.mesh = d[kinds[i]]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# the train runs along +X on the far ridge; the model faces -Z, so turn it a quarter
		mi.rotation.y = -PI * 0.5
		add_child(mi)
		_train.append(mi)
	_horn = AudioStreamPlayer3D.new()
	_horn.bus = "Weather"; _horn.stream = _horn_stream
	_horn.unit_size = 90.0; _horn.max_distance = 9000.0
	_horn.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(_horn)

func _train_pos(i: int) -> Vector3:
	var x := _train_x - i * 16.6
	var y := terrain.height(x, _train_line_z) + 0.0
	return Vector3(x, y, _train_line_z)

# ------------------------------------------------------------------ kites and flag
func _build_kites() -> void:
	if not _kites.is_empty():
		for k in _kites:
			(k["node"] as Node3D).visible = true
		return
	var spots := [Vector2(-40.0, 42.0), Vector2(-6.0, 58.0), Vector2(34.0, 30.0)]
	var home := Vector2(-18.0, 36.0)
	for i in spots.size():
		var foot := Vector3(home.x + spots[i].x, terrain.height(home.x + spots[i].x, home.y + spots[i].y), home.y + spots[i].y)
		var node := Node3D.new(); add_child(node)
		var kite := MeshInstance3D.new()
		kite.mesh = NewModels2.kite(i % 2)
		kite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(kite)
		var line := MeshInstance3D.new()
		line.mesh = NewModels2.kite_line()
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(line)
		_kites.append({"node": node, "kite": kite, "line": line, "foot": foot,
			"phase": _rng.randf() * TAU, "height": 42.0 + 9.0 * i, "side": 10.0 + 4.0 * i})
		_kites[-1]["node"].visible = true

func _build_flag() -> void:
	if _flag != null:
		_flag.visible = true
		return
	var d := NewModels2.flag(0)
	_flag = Node3D.new()
	add_child(_flag)
	var pole := MeshInstance3D.new()
	pole.mesh = d["pole"]
	pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flag.add_child(pole)
	_flag_cloth = MeshInstance3D.new()
	_flag_cloth.mesh = d["cloth"]
	_flag_cloth.position = d["cloth_origin"]
	_flag_cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flag_mat = ShaderMaterial.new()
	_flag_mat.shader = load("res://game/shaders/flag_wave.gdshader")
	_flag_cloth.material_override = _flag_mat
	_flag.add_child(_flag_cloth)
	# near the chapel and the start pad: a small flag by the lawn
	var p := Vector2(-18.0 + 26.0, 36.0 - 44.0)
	_flag.position = Vector3(p.x, terrain.height(p.x, p.y), p.y)

# ------------------------------------------------------------------ per frame
func update(delta: float, cam: Camera3D, wind: Wind, daylight: float, sun_el: float) -> void:
	_time += delta
	if far_traffic:
		_update_heli(delta)
		_update_airliner(delta)
		_update_train(delta)
	if park_life:
		_update_kites(delta)
		_update_flag(delta)

func _update_heli(delta: float) -> void:
	if _heli == null:
		return
	var ang := _time * 0.06
	var centre := Vector3(-420.0, 360.0, -380.0)
	var pos := centre + Vector3(cos(ang) * 320.0, sin(ang * 1.7) * 12.0, sin(ang) * 320.0)
	var fwd := Vector3(-sin(ang), 0.0, cos(ang))
	_heli.position = pos
	_heli.rotation.y = atan2(fwd.x, fwd.z) + PI
	_heli_main.rotate_y(_heli_spin["main"] * 30.0 * delta)
	_heli_tail.rotate_x(_heli_spin["tail"] * 150.0 * delta)
	if _heli_player:
		_heli_player.volume_db = -18.0

func _update_airliner(delta: float) -> void:
	if _airliner == null:
		return
	_airliner_t += delta
	if _airliner_t > 90.0:
		_airliner_t = 0.0
		_rng.randf()
	# a long straight pass, high and far
	var k := fmod(_airliner_t / 90.0, 1.0)
	var from := Vector3(-2200.0, 900.0, -1400.0)
	var to := Vector3(2200.0, 980.0, 1400.0)
	_airliner.position = from.lerp(to, k)
	_airliner.rotation.y = atan2(to.x - from.x, to.z - from.z) + PI
	_airliner.visible = _airliner_t < 80.0

func _update_train(delta: float) -> void:
	if _train.is_empty():
		return
	_train_x += 8.0 * delta
	if _train_x > 900.0:
		_train_x = -900.0
	for i in _train.size():
		_train[i].position = _train_pos(i)
		_train[i].visible = true
	if _train_track:
		_train_track.visible = true
	_horn_t -= delta
	if _horn_t <= 0.0:
		_horn_t = 30.0
		var d := _train_pos(0).distance_to(Vector3(-18.0, terrain.height(-18.0, 36.0) + 1.7, 36.0))
		_horn_pending = d / 343.0
		if _horn: _horn.stream = _horn_stream
	if _horn_pending > 0.0:
		_horn_pending -= delta
		if _horn_pending <= 0.0 and _horn != null:
			_horn.global_position = _train_pos(0)
			_horn.volume_db = -6.0
			_horn.play()

func _update_kites(delta: float) -> void:
	var w := wind.toward()
	var ws := wind.speed
	for k in _kites:
		var foot: Vector3 = k["foot"]
		var ph := float(k["phase"])
		var drift := w * (2.0 + 4.0 * ws / 8.0)
		var kite: MeshInstance3D = k["kite"]
		var line: MeshInstance3D = k["line"]
		var side := Vector3(w.z, 0.0, -w.x) * float(k["side"])
		var pos := foot + side + drift + Vector3(0.0, float(k["height"]) + sin(_time * 0.9 + ph) * 2.0, 0.0)
		kite.global_position = pos
		kite.rotation.y = _time * 0.3 + ph
		kite.rotation.z = sin(_time * 1.3 + ph) * 0.3
		var to_foot := foot - pos
		var ln := to_foot.length()
		var rot := Basis(Quaternion(Vector3(0, 0, 1), to_foot.normalized()))
		line.global_transform = Transform3D(rot.scaled(Vector3(1.0, 1.0, ln)), pos)

func _update_flag(delta: float) -> void:
	if _flag == null:
		return
	var toward := wind.toward()
	# the cloth's +X points downwind
	_flag.rotation.y = atan2(-toward.z, toward.x)
	if _flag_mat:
		_flag_mat.set_shader_parameter("wind", wind.speed)

func stats() -> Dictionary:
	return {"far_traffic": far_traffic, "park_life": park_life, "kites": _kites.size(), "train_x": snappedf(_train_x, 0.1)}

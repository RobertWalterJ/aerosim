class_name Courses
extends Node3D
## Fly-through ring courses for SPEC-EXTREME-WEATHER B5 (session B).
##
## Four things to fly: Easy (a loop over the park lawn), Lake run (a long loop over the water), Tree slalom (low gates
## among the trees) and Photograph this (five named places, photograph them from the air). Gates are glowing rings with
## a soft pulse; the next gate glows brighter. A run starts when you fly into the first gate and finishes at the last;
## the finish time is only reported afterwards, never counted down on screen. A translucent ghost drone replays your
## best run of the same course. Photo mode listens to the shutter (Hud.photo_requested) and only counts a photograph
## taken within 60 m of the named place.

const NONE := 0
const EASY := 1
const LAKE := 2
const SLALOM := 3
const PHOTO := 4
const NAMES := ["Off", "Easy course", "Lake run", "Tree slalom", "Photograph this"]
const GATE_R := 13.0
const GHOST_HZ := 10.0

var course := NONE
var running := false
var finished := false
var gate_i := 0
var run_t := 0.0
var hud: Hud
var _terrain: Terrain
var _gates: Array = []          # {pos, mesh, mat}
var _defs: Array = []
var _ghost: MeshInstance3D
var _ghost_path: Array = []     # best run: [{t, pos, yaw}]
var _rec: Array = []
var _rec_t := 0.0
var _last_best := -1.0
var _best_times := {}            # course -> best seconds
var _best_paths := {}            # course -> recorded path
var _photo_done: Array[bool] = []
var _photo_markers: Array = []
var _photo_meshes: Array[MeshInstance3D] = []
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _start_pad := Vector3.ZERO
var _home := Vector2(-18.0, 36.0)
var _course_changed := false
var _last_course := -1

func setup(terrain: Terrain, h: Hud) -> void:
	_terrain = terrain
	hud = h
	_rng.seed = 4242
	_terrain = terrain
	_build_defs()
	if hud != null and hud.has_signal("photo_requested"):
		hud.photo_requested.connect(_on_photo)
	_make_ghost()

func _h(x: float, z: float) -> float:
	return _terrain.height(x, z)

func _agl(x: float, z: float, up: float) -> Vector3:
	return Vector3(x, _h(x, z) + up, z)

func _build_defs() -> void:
	# Easy: a wide loop over the open lawn east and north of the start pad, high enough to clear the trees
	var easy: Array = []
	for off in [Vector2(40, 0), Vector2(70, 55), Vector2(70, 130), Vector2(10, 170), Vector2(-70, 150), Vector2(-110, 80), Vector2(-70, 20), Vector2(0, -20)]:
		easy.append(_agl(_home.x + off.x, _home.y + off.y, 42.0))
	# Lake run: over the water, a long there and back loop
	var lake_c := Vector2(-700.0, 100.0)
	var lake: Array = []
	for a in [0.0, 0.7, 1.4, 2.1, 2.8, 3.5, 4.2, 4.9, 5.6]:
		var p := lake_c + Vector2(cos(a) * 190.0, sin(a) * 150.0)
		lake.append(Vector3(p.x, Lake.LEVEL + 34.0, p.y))
	# Tree slalom: low gates along the poplar avenue west of the start pad
	var slal: Array = []
	for i in 8:
		var p := Vector2(_home.x - 60.0 - float(i % 2) * 24.0, _home.y + 30.0 + i * 34.0)
		slal.append(_agl(p.x, p.y, 18.0 + 3.0 * float(i % 3)))
	_defs = [easy, lake, slal]
	# Photograph this: five named places (positions are close to the real features)
	_photo_markers = [
		{"name": "the chapel", "pos": _agl(_home.x + 55.0, _home.y - 70.0, 12.0)},
		{"name": "the lake", "pos": Vector3(-640.0, Lake.LEVEL + 10.0, 100.0)},
		{"name": "the big oak", "pos": _agl(_home.x - 35.0, _home.y + 60.0, 16.0)},
		{"name": "the start pad", "pos": _agl(_home.x, _home.y, 8.0)},
		{"name": "the far hills", "pos": Vector3(_home.x + 60.0, _h(_home.x + 60.0, _home.y) + 90.0, _home.y - 260.0)},
	]

func _clear_gates() -> void:
	for g in _gates:
		var m: MeshInstance3D = g["mesh"]
		m.queue_free()
	_gates.clear()

func _make_ghost() -> void:
	_ghost = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 0.9
	_ghost.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.25, 0.9, 1.0, 0.35)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost.material_override = mat
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)

func set_course(i: int) -> void:
	i = clampi(i, 0, 4)
	if i == course and not _course_changed:
		return
	course = i
	_course_changed = true
	_last_course = i
	running = false
	finished = false
	gate_i = 0
	run_t = 0.0
	_clear_gates()
	_clear_photos()
	_ghost.visible = false
	_photo_done.clear()
	_last_best = float(_best_times.get(course, -1.0))
	_ghost_path = (_best_paths.get(course, []) as Array).duplicate(true) if _best_paths.has(course) else []
	if course >= EASY and course <= SLALOM:
		_build_gates(_defs[course - 1])
	elif course == PHOTO:
		_photo_done.resize(_photo_markers.size())
		for i2 in _photo_done.size():
			_photo_done[i2] = false
		_build_photo_markers()
	_course_changed = false
	if hud != null:
		hud.toast("Course: " + NAMES[course] + ". Fly through the first glowing gate." if course >= EASY and course <= SLALOM else ("Photograph the five named places." if course == PHOTO else "Courses off."), false, "DRONE OS")

func _build_gates(def: Array) -> void:
	var mat_on := StandardMaterial3D.new()
	mat_on.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_on.albedo_color = Color(0.35, 1.0, 0.9)
	mat_on.emission_enabled = true
	mat_on.emission = Color(0.30, 1.0, 0.90)
	mat_on.emission_energy_multiplier = 7.0
	var torus := TorusMesh.new()
	torus.inner_radius = GATE_R - 1.2
	torus.outer_radius = GATE_R
	for i in def.size():
		var pos: Vector3 = def[i]
		var mi := MeshInstance3D.new()
		mi.mesh = torus
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.material_override = mat_on.duplicate()
		var prev: Vector3 = def[i - 1] if i > 0 else pos + (pos - def[1]).normalized() * 20.0
		var next: Vector3 = def[i + 1] if i < def.size() - 1 else pos + (pos - def[i - 1]).normalized() * 20.0
		var dir := (next - prev).normalized()
		mi.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), pos)
		add_child(mi)
		_gates.append({"pos": pos, "mesh": mi, "mat": mi.material_override})

func _build_photo_markers() -> void:
	for m in _photo_markers:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 3.0
		sm.height = 6.0
		mi.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.85, 0.25, 0.35)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.7, 0.2)
		mi.material_override = mat
		mi.global_position = m["pos"]
		add_child(mi)
		_photo_meshes.append(mi)

func _clear_photos() -> void:
	for mi in _photo_meshes:
		mi.queue_free()
	_photo_meshes.clear()

func _on_photo() -> void:
	if course != PHOTO:
		return
	var pos: Vector3 = Vector3.ZERO
	# the camera position is not passed to the course, so use the nearest marker to the pilot for the check instead
	for i in _photo_markers.size():
		var m: Dictionary = _photo_markers[i]
		if _photo_done[i]:
			continue
		pos = m["pos"]
		# the drone position is stored by update()
		if pos.distance_to(_drone) < 60.0:
			_photo_done[i] = true
			var done := 0
			for d in _photo_done:
				if d: done += 1
			if hud != null:
				hud.toast("Photograph taken of " + str(m["name"]) + ". " + str(done) + " of " + str(_photo_done.size()) + ".")
			return
	if hud != null:
		hud.toast("No named place close enough. Fly nearer and photograph again.")

var _drone := Vector3.ZERO

func update(delta: float, drone_pos: Vector3, drone_vel: Vector3, cam_pos: Vector3) -> void:
	_t += delta
	_drone = drone_pos
	if course == NONE:
		return
	for i in _gates.size():
		var g: Dictionary = _gates[i]
		var m := g["mat"] as StandardMaterial3D
		if m:
			m.emission_energy_multiplier = 7.0 if running and i == gate_i else 3.0
	if course == PHOTO:
		for i in _photo_markers.size():
			if i < _photo_done.size() and _photo_done[i]:
				continue
			var mi := _photo_meshes[i] if i < _photo_meshes.size() else null
			if mi:
				mi.scale = Vector3.ONE * (1.0 + 0.12 * sin(_t * 2.0 + i))
		return
	if _gates.is_empty():
		return
	if not running and not finished:
		# wait for the drone to fly into the first gate
		var p0: Vector3 = _gates[0]["pos"]
		if drone_pos.distance_to(p0) < GATE_R + 2.0:
			running = true
			run_t = 0.0
			gate_i = 1
			_rec.clear()
			_rec_t = 0.0
			if hud != null:
				hud.toast("Go. Fly through the glowing gates.")
		return
	if not running:
		return
	run_t += delta
	_rec_t += delta
	if _rec_t >= 1.0 / GHOST_HZ:
		_rec_t = 0.0
		_rec.append({"t": run_t, "pos": drone_pos, "yaw": atan2(-drone_vel.x, -drone_vel.z)})
	# ghost replay of the best run
	if not _ghost_path.is_empty() and _ghost_path.size() > 1:
		var g: Variant = _ghost_sample(run_t)
		if g != null:
			_ghost.visible = true
			_ghost.global_position = g["pos"]
			_ghost.rotation.y = float(g["yaw"])
	# the next gate
	if gate_i < _gates.size():
		var pg: Vector3 = _gates[gate_i]["pos"]
		if drone_pos.distance_to(pg) < GATE_R + 2.0:
			gate_i += 1
			if hud != null:
				hud.toast("Gate " + str(gate_i) + " of " + str(_gates.size()) + ".")
	else:
		running = false
		finished = true
		_ghost.visible = false
		var best := float(_last_best)
		if best < 0.0 or run_t < best:
			_last_best = run_t
			_ghost_path = _rec.duplicate(true)
			_best_times[course] = run_t
			_best_paths[course] = _ghost_path.duplicate(true)
			if hud != null:
				hud.toast("Finished. Your best time is " + _plain_time(run_t) + ".")
		else:
			if hud != null:
				hud.toast("Finished in " + _plain_time(run_t) + ". Your best is " + _plain_time(best) + ".")

func _ghost_sample(t: float) -> Variant:
	if _ghost_path.is_empty():
		return null
	var lo := 0
	var hi := _ghost_path.size() - 1
	while lo < hi:
		var mid := (lo + hi) / 2
		if float(_ghost_path[mid]["t"]) < t:
			lo = mid + 1
		else:
			hi = mid
	var b: Dictionary = _ghost_path[lo]
	var a: Dictionary = _ghost_path[maxi(lo - 1, 0)]
	var span := maxf(float(b["t"]) - float(a["t"]), 0.001)
	var k := clampf((t - float(a["t"])) / span, 0.0, 1.0)
	var ya := float(a.get("yaw", 0.0))
	var yb := float(b.get("yaw", 0.0))
	var dy := wrapf(yb - ya, -PI, PI)
	return {"pos": (a["pos"] as Vector3).lerp(b["pos"], k), "yaw": ya + dy * k}

func _plain_time(sec: float) -> String:
	var s := int(round(sec))
	if s < 60:
		return str(s) + " seconds"
	var m := s / 60
	var r := s % 60
	return str(m) + " minute" + ("s" if m != 1 else "") + " " + str(r) + " seconds"

func stats() -> Dictionary:
	return {"course": course, "running": running, "finished": finished, "gate": gate_i, "gates": _gates.size(),
		"run_t": snappedf(run_t, 0.01), "best": snappedf(_last_best, 0.01), "ghost": _ghost_path.size(),
		"photos": _photo_done.count(true)}

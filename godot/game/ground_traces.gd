class_name GroundTraces
extends Node3D
## Thermal-only evidence of recent movement: human and animal footprints and vehicle tyre tracks. The meshes are
## heat-code planes shown only while the thermal camera is on, so the normal camera never sees floating marks on the
## grass. Each trace ages and fades, then frees itself. Footprints stay warm longer than tyre tracks.

const HUMAN_LIFE := 55.0
const ANIMAL_LIFE := 42.0
const TYRE_LIFE := 32.0
const MAX_TRACES := 280
const HUMAN_STEP := 0.72
const ANIMAL_STEP := 0.45
const TYRE_STEP := 2.1

var terrain: Terrain
var village: Village
var traffic: Traffic
var animals: WildlifeObjects
var objects: CaseObjects
var _thermal := false
var _traces: Array[Dictionary] = []
var _last: Dictionary = {}
var _human_acc := 0.0
var _animal_acc := 0.0
var _tyre_acc := 0.0

func setup(t: Terrain, v: Village, tr: Traffic, o: CaseObjects) -> void:
	terrain = t
	village = v
	traffic = tr
	objects = o
	visible = false

func set_animal_source(a: WildlifeObjects) -> void:
	animals = a

func set_thermal(on: bool) -> void:
	_thermal = on
	visible = on

func update(delta: float, drone_pos: Vector3) -> void:
	_age(delta)
	if not _thermal:
		return
	_human_acc += delta
	if _human_acc >= 0.30:
		_human_acc = 0.0
		_sample_humans(drone_pos)
	_animal_acc += delta
	if _animal_acc >= 0.26:
		_animal_acc = 0.0
		_sample_animals(drone_pos)
	_tyre_acc += delta
	if _tyre_acc >= 0.22:
		_tyre_acc = 0.0
		_sample_vehicles(drone_pos)

func _sample_humans(drone_pos: Vector3) -> void:
	if village != null:
		for p in village.people_positions():
			_source_step("person_%s" % str(p["key"]), p["pos"], float(p["yaw"]), HUMAN_STEP, 0.9,
				ThermalHeat.WARM, HUMAN_LIFE, Vector2(0.28, 0.62), drone_pos, true)
	if objects != null:
		var w: Dictionary = objects.hiker_trace_source()
		if not w.is_empty():
			_source_step("wren", w["pos"], float(w["yaw"]), 0.60, 0.9,
				ThermalHeat.WARM, HUMAN_LIFE, Vector2(0.25, 0.55), drone_pos, true)

func _sample_animals(drone_pos: Vector3) -> void:
	if animals == null:
		return
	for a in animals.trace_sources():
		_source_step("animal_%s" % str(a["key"]), a["pos"], float(a["yaw"]), ANIMAL_STEP, 0.7,
			ThermalHeat.ANIMAL, ANIMAL_LIFE, Vector2(0.18, 0.30), drone_pos, false)

func _sample_vehicles(drone_pos: Vector3) -> void:
	if traffic == null:
		return
	for v in traffic.trace_sources():
		var key := "vehicle_%s" % str(v["key"])
		var p: Vector3 = v["pos"]
		var yaw: float = float(v["yaw"])
		var old: Vector3 = _last.get(key, p + Vector3(999, 0, 0))
		if Vector2(p.x - old.x, p.z - old.z).length() < TYRE_STEP:
			continue
		_last[key] = p
		if Vector2(p.x - drone_pos.x, p.z - drone_pos.z).length() > 430.0:
			continue
		var side := Vector3(cos(yaw), 0, -sin(yaw))
		for s in [-0.72, 0.72]:
			var q: Vector3 = p + side * s
			var gy := terrain.height(q.x, q.z) + 0.045
			_spawn(Vector3(q.x, gy, q.z), yaw, Vector2(0.30, 3.2), ThermalHeat.ENGINE, 0.42, TYRE_LIFE, key)

func _source_step(key: String, pos: Vector3, yaw: float, step: float, spread: float, code: Color,
		life: float, size: Vector2, drone_pos: Vector3, paired: bool) -> void:
	var old: Vector3 = _last.get(key, pos + Vector3(999, 0, 0))
	if Vector2(pos.x - old.x, pos.z - old.z).length() < step:
		return
	_last[key] = pos
	if Vector2(pos.x - drone_pos.x, pos.z - drone_pos.z).length() > 430.0:
		return
	var side := Vector3(cos(yaw), 0, -sin(yaw))
	if paired:
		for s in [-spread * 0.5, spread * 0.5]:
			var q: Vector3 = pos + side * s
			var gy := terrain.height(q.x, q.z) + 0.055
			_spawn(Vector3(q.x, gy, q.z), yaw, size, code, 0.70, life, key)
	else:
		var gy2 := terrain.height(pos.x, pos.z) + 0.055
		_spawn(Vector3(pos.x, gy2, pos.z), yaw, size, code, 0.62, life, key)

func _spawn(pos: Vector3, yaw: float, size: Vector2, code: Color, alpha: float, life: float, source: String) -> void:
	if _traces.size() >= MAX_TRACES:
		var oldest: Dictionary = _traces.pop_front()
		(oldest["node"] as Node).queue_free()
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	mi.mesh = plane
	mi.material_override = ThermalHeat.trace_material(code, alpha)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("source", source)
	add_child(mi)
	mi.global_position = pos
	mi.rotation.y = yaw
	_traces.append({"node": mi, "age": 0.0, "life": life, "alpha": alpha})

func _age(delta: float) -> void:
	var i := _traces.size() - 1
	while i >= 0:
		var tr: Dictionary = _traces[i]
		tr["age"] = float(tr["age"]) + delta
		var age: float = float(tr["age"])
		var life: float = float(tr["life"])
		if age >= life:
			(tr["node"] as Node).queue_free()
			_traces.remove_at(i)
		else:
			var fade := 1.0 - age / maxf(life, 0.1)
			(tr["node"] as GeometryInstance3D).transparency = clampf(1.0 - fade, 0.0, 1.0)
		i -= 1

func debug_spawn_at(pos: Vector3, kind := "human") -> void:
	var code := ThermalHeat.WARM if kind == "human" else ThermalHeat.ENGINE
	var size := Vector2(1.2, 2.4) if kind == "human" else Vector2(1.0, 5.0)
	_spawn(Vector3(pos.x, terrain.height(pos.x, pos.z) + 0.12, pos.z), 0.0, size, code, 0.95, 90.0, "debug")

func clear() -> void:
	for tr in _traces:
		(tr["node"] as Node).queue_free()
	_traces.clear()
	_last.clear()

func stats() -> Dictionary:
	return {"traces": _traces.size(), "thermal": _thermal}

class_name GroundTraces
extends Node3D
## Thermal-only evidence of movement: human and animal footprints and vehicle tyre tracks. The meshes are heat-code
## planes shown only while the thermal camera is on, so the normal camera never sees floating marks on the grass.
##
## A military thermal imager sees disturbed ground for hours, not seconds: a fresh print is bright, loses contrast
## over the first hour, and is still a faint cold/warm scar several hours later. This class therefore keeps a sparse
## history of trace points for hours, but only builds meshes for the ones near the drone and within a render budget.
## Leaving the area frees the meshes, not the history; flying back later re-creates the old traces at their aged
## brightness.

const HUMAN_LIFE := 6.0 * 3600.0      # six hours
const ANIMAL_LIFE := 5.0 * 3600.0     # five hours
const TYRE_LIFE := 8.0 * 3600.0       # eight hours on a road
const MAX_RECORDS := 20000            # history points, not live meshes
const MAX_RENDERED := 520             # live quads at once
const RENDER_RADIUS := 430.0
const HUMAN_STEP := 1.10
const ANIMAL_STEP := 0.95
const TYRE_STEP := 18.0               # one long strip per wheel every 18 m
const TYRE_LEN := 20.0

var terrain: Terrain
var village: Village
var traffic: Traffic
var animals: WildlifeObjects
var objects: CaseObjects
var _thermal := false
var _records: Array[Dictionary] = []     # {pos, yaw, size, code, alpha, life, age, node}
var _last: Dictionary = {}
var _human_acc := 0.0
var _animal_acc := 0.0
var _tyre_acc := 0.0
var _render_t := 0.0

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
	if not on:
		_free_nodes()

func update(delta: float, drone_pos: Vector3) -> void:
	_age(delta)
	# Tracks are laid whether or not the camera is looking: they are physical heat history, not a view effect.
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
	if not _thermal:
		return
	_render_t += delta
	if _render_t >= 0.14:
		_render_t = 0.0
		_render_near(drone_pos)

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
		if Vector2(p.x - drone_pos.x, p.z - drone_pos.z).length() > RENDER_RADIUS:
			continue
		var side := Vector3(cos(yaw), 0, -sin(yaw))
		for s in [-0.72, 0.72]:
			var q: Vector3 = p + side * s
			var gy := terrain.height(q.x, q.z) + 0.045
			# long strips keep the tyre history cheap while still reading as continuous wheel ruts
			_spawn(Vector3(q.x, gy, q.z), yaw, Vector2(0.32, TYRE_LEN), ThermalHeat.ENGINE, 0.46, TYRE_LIFE, key)

func _source_step(key: String, pos: Vector3, yaw: float, step: float, spread: float, code: Color,
		life: float, size: Vector2, drone_pos: Vector3, paired: bool) -> void:
	var old: Vector3 = _last.get(key, pos + Vector3(999, 0, 0))
	if Vector2(pos.x - old.x, pos.z - old.z).length() < step:
		return
	_last[key] = pos
	if Vector2(pos.x - drone_pos.x, pos.z - drone_pos.z).length() > RENDER_RADIUS:
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
	while _records.size() >= MAX_RECORDS:
		_drop_record(0)
	_records.append({
		"pos": pos, "yaw": yaw, "size": size, "code": code, "alpha": alpha,
		"life": life, "age": 0.0, "node": null, "source": source,
	})

func _make_node(rec: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = rec["size"]
	mi.mesh = plane
	mi.material_override = ThermalHeat.trace_material(rec["code"], float(rec["alpha"]))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = rec["pos"]
	mi.rotation.y = float(rec["yaw"])
	rec["node"] = mi

func _free_node(rec: Dictionary) -> void:
	var node: Node = rec.get("node", null)
	if node != null and is_instance_valid(node):
		node.queue_free()
	rec["node"] = null

func _free_nodes() -> void:
	for rec in _records:
		_free_node(rec)

func _drop_record(i: int) -> void:
	if i < 0 or i >= _records.size():
		return
	_free_node(_records[i])
	_records.remove_at(i)

func _age(delta: float) -> void:
	var i := _records.size() - 1
	while i >= 0:
		var rec: Dictionary = _records[i]
		rec["age"] = float(rec["age"]) + delta
		if float(rec["age"]) >= float(rec["life"]):
			_drop_record(i)
		i -= 1

func _brightness(rec: Dictionary) -> float:
	var t := clampf(float(rec["age"]) / maxf(float(rec["life"]), 1.0), 0.0, 1.0)
	# Fresh: near the source brightness. One hour: still clear. Several hours: a faint scar, not a live heat source.
	return float(rec["alpha"]) * pow(1.0 - t, 2.15)

func _render_near(drone_pos: Vector3) -> void:
	var p := Vector2(drone_pos.x, drone_pos.z)
	var rendered := 0
	var i := _records.size() - 1
	while i >= 0:
		var rec: Dictionary = _records[i]
		var rp: Vector3 = rec["pos"]
		var d := Vector2(rp.x - p.x, rp.z - p.y).length()
		var node: Node = rec.get("node", null)
		if d > RENDER_RADIUS or rendered >= MAX_RENDERED:
			if node != null:
				_free_node(rec)
			i -= 1
			continue
		if node == null:
			_make_node(rec)
			node = rec.get("node", null)
		if node != null and is_instance_valid(node):
			var mi := node as MeshInstance3D
			mi.visible = true
			var m := mi.material_override as StandardMaterial3D
			if m != null:
				m.albedo_color.a = _brightness(rec)
		rendered += 1
		i -= 1

func debug_spawn_at(pos: Vector3, kind := "human") -> void:
	var code := ThermalHeat.WARM if kind == "human" else ThermalHeat.ENGINE
	var size := Vector2(1.2, 2.4) if kind == "human" else Vector2(1.0, 5.0)
	_spawn(Vector3(pos.x, terrain.height(pos.x, pos.z) + 0.12, pos.z), 0.0, size, code, 0.95, HUMAN_LIFE, "debug")

## Fast-forward the history for a screenshot or a thermal-age check. Ages every record; rendering updates next frame.
func debug_age(seconds: float) -> void:
	for rec in _records:
		rec["age"] = float(rec["age"]) + seconds

func clear() -> void:
	_free_nodes()
	_records.clear()
	_last.clear()

func stats() -> Dictionary:
	var visible_n := 0
	for rec in _records:
		if rec.get("node", null) != null:
			visible_n += 1
	return {"records": _records.size(), "traces": visible_n, "thermal": _thermal, "max_records": MAX_RECORDS}

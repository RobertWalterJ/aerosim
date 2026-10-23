class_name WorldLife
extends Node3D
## Things that make the valley feel inhabited and worth exploring, for the sandbox (session B).
##
## Nothing here is a mission or a switch: it is scenery and discovery. The old farm is built from Claude's models on a
## clearing found in the terrain (barn, silo, a Dutch windmill with turning sails and a farm wind pump), and a set of
## named places around the valley can be discovered by flying near them, on the ground or below the tree line as well as
## high up. First discovery sends a DroneBudz message from Riley the ranger, and the discoveries persist between flights
## in user://places.cfg. Photos also record which places were in frame (photo_library.gd), so the same discovery data can
## back photo jobs later without touching the sandbox.
##
## Cost: one farm of four models (about 8,000 triangles in total, all built once), no particles, no per-frame work
## beyond the windmill spin and one distance check per place.

const HOME := Vector2(-18.0, 36.0)
const LAKE_X := -430.0

## Places worth finding. `alt_max` is the highest the drone may be (metres above ground) for the place to count; low
## places are tucked under the tree line on purpose, high ones can be seen from anywhere.
const PLACES := [
	{"id": "pad", "name": "the start pad", "note": "Back at the pad. Everything starts here.", "radius": 55.0, "alt_max": 0.0},
	{"id": "chapel", "name": "the chapel", "note": "The little chapel on the hill. The heritage people would love a photo of it.", "radius": 55.0, "alt_max": 60.0},
	{"id": "graves", "name": "the old graves", "note": "The Victorian graves. Fly gently here.", "radius": 120.0, "alt_max": 0.0},
	{"id": "lane", "name": "the sunken lane", "note": "That old lane under the hedges. Most pilots never come down this low.", "radius": 45.0, "alt_max": 22.0},
	{"id": "lake", "name": "the lake shore", "note": "The whole lake opens up from here at golden hour.", "radius": 130.0, "alt_max": 0.0},
	{"id": "barges", "name": "the firework barges", "note": "The barges are still out on the water, waiting for the show.", "radius": 170.0, "alt_max": 0.0},
	{"id": "farm", "name": "the old farm", "note": "Someone still works the old farm. The barn and silo are older than the park.", "radius": 130.0, "alt_max": 0.0},
	{"id": "windmill", "name": "the windmill", "note": "The mill still turns when the wind gets up. Worth a close look from below.", "radius": 55.0, "alt_max": 35.0},
	{"id": "railway", "name": "the far railway", "note": "You found the railway on the far ridge. Trains cross it all day.", "radius": 320.0, "alt_max": 0.0},
]

var terrain: Terrain
var wind: Wind
var notes: PhoneNotes
var farm_pos := Vector3.ZERO
var _windmill: Node3D
var _sails: MeshInstance3D
var _sails_pivot := Vector3.ZERO
var _sails_sign := -1.0
var _wind_pump: Node3D
var _pump_wheel: MeshInstance3D
var _pump_pivot := Vector3.ZERO
var _pump_sign := -1.0
var _time := 0.0
var _discovered := {}
var _pois: Array[Dictionary] = []

func setup(t: Terrain, w: Wind) -> void:
	terrain = t
	wind = w
	farm_pos = _choose_farm_site()
	_build_places()
	_load_discovered()
	_build_farm()
	_build_props()

## A quiet clearing within about 900 m of the start: open ground, low slope, not on the water, not the park itself.
func _choose_farm_site() -> Vector3:
	var best := Vector3(HOME.x + 380.0, 0.0, HOME.y - 430.0)
	var best_score := -1e9
	var rings: Array = [300.0, 400.0, 520.0, 660.0, 800.0]
	# a farm wants a clearing: penalise close colliders (trees, hedges, stones) and rough ground
	var clutter: Array = []
	for c in terrain.layout.get("colliders", {}).get("cyl", []):
		clutter.append(Vector2(float(c[0]), float(c[1])))
	for ri in rings.size():
		var ring := float(rings[ri])
		for k in 28:
			var a: float = TAU * float(k) / 28.0 + ring * 0.017
			var p: Vector2 = HOME + Vector2(cos(a), sin(a)) * ring
			if Lake.is_wet(p.x, p.y):
				continue
			var cov := terrain.cover_at(p.x, p.y)
			var h := terrain.height(p.x, p.y)
			var slope := absf(terrain.height(p.x + 20.0, p.y) - h) + absf(terrain.height(p.x, p.y + 20.0) - h)
			var near := 0
			for q in clutter:
				if q.distance_to(p) < 42.0:
					near += 1
			if near > 6:
				continue   # not a clearing: something is in the way of the farm
			var score := (1.0 - cov.x) * 1.4 + cov.y * 0.7 - slope * 0.08 - float(near) * 1.6
			if score > best_score:
				best_score = score
				best = Vector3(p.x, h, p.y)
	return best

func _build_places() -> void:
	# the farm and mill places depend on where the farm landed
	var farm_ground := Vector3(farm_pos.x, terrain.height(farm_pos.x, farm_pos.z), farm_pos.z)
	_pois.clear()
	for p in PLACES:
		var poi: Dictionary = p.duplicate()
		match str(p["id"]):
			"pad": poi["pos"] = Vector3(HOME.x, terrain.height(HOME.x, HOME.y), HOME.y)
			"chapel": poi["pos"] = Vector3(188.0, terrain.height(188.0, -74.0), -74.0)
			"graves": poi["pos"] = Vector3(HOME.x + 40.0, terrain.height(HOME.x + 40.0, HOME.y + 45.0), HOME.y + 45.0)
			"lane": poi["pos"] = _lane_point()
			"lake": poi["pos"] = Vector3(LAKE_X, Lake.LEVEL, 100.0)
			"barges": poi["pos"] = Vector3(-806.0, Lake.LEVEL, 100.0)
			"farm": poi["pos"] = farm_ground
			"windmill": poi["pos"] = farm_ground + Vector3(-24.0, 0.0, -15.0)
			"railway": poi["pos"] = Vector3(0.0, terrain.height(0.0, -1560.0), -1560.0)
		poi["discovered"] = false
		_pois.append(poi)

## A point on one of the park paths about 180 m from the start, on the ground, so the low-flying discovery is real.
func _lane_point() -> Vector3:
	var best := Vector3(HOME.x - 120.0, 0.0, HOME.y - 80.0)
	var best_d := 1e9
	var paths: Array = terrain.layout.get("paths", []) if terrain != null else []
	for path in paths:
		var pts: Array = path.get("pts", [])
		for q in pts:
			var v := Vector2(float(q[0]), float(q[1]))
			var d := absf(v.distance_to(HOME) - 185.0)
			if d < best_d:
				best_d = d
				best = Vector3(v.x, terrain.height(v.x, v.y), v.y)
	return best

# ------------------------------------------------------------------ the farm
func _ground(x: float, z: float) -> float:
	return terrain.height(x, z)

func _build_farm() -> void:
	var base := Vector3(farm_pos.x, _ground(farm_pos.x, farm_pos.z), farm_pos.z)
	var yaw := -0.36
	# the barn, long axis along z, then the silo beside its long wall
	var barn := MeshInstance3D.new()
	barn.mesh = NewModels2.barn()
	barn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(barn)
	barn.position = base
	barn.rotation.y = yaw
	var side := Vector3(cos(yaw) * 4.0 + sin(yaw) * 8.0, 0.0, -sin(yaw) * 4.0 + cos(yaw) * 8.0)
	var silo := MeshInstance3D.new()
	silo.mesh = NewModels2.silo()
	add_child(silo)
	silo.position = Vector3(base.x + side.x, _ground(base.x + side.x, base.z + side.z), base.z + side.z)
	silo.rotation.y = yaw
	# the Dutch windmill: tower, cap and the four sails on their pivot
	var wd := NewModels2.windmill()
	_windmill = Node3D.new()
	add_child(_windmill)
	var wpos := Vector3(base.x - 30.0, 0.0, base.z - 22.0)
	_windmill.position = Vector3(wpos.x, _ground(wpos.x, wpos.z), wpos.z)
	_windmill.rotation.y = 0.5
	var tower := MeshInstance3D.new(); tower.mesh = wd["tower"]; _windmill.add_child(tower)
	var cap := MeshInstance3D.new(); cap.mesh = wd["cap"]; _windmill.add_child(cap)
	_sails = MeshInstance3D.new(); _sails.mesh = wd["sails"]; _windmill.add_child(_sails)
	_sails_pivot = wd["sail_pivot"]; _sails.position = _sails_pivot
	_sails_sign = float(wd.get("spin_sign", -1.0))
	# the farm wind pump with its turning wheel
	var pd := NewModels2.wind_pump()
	_wind_pump = Node3D.new()
	add_child(_wind_pump)
	var ppos := Vector3(base.x + 24.0, 0.0, base.z + 20.0)
	_wind_pump.position = Vector3(ppos.x, _ground(ppos.x, ppos.z), ppos.z)
	var ptower := MeshInstance3D.new(); ptower.mesh = pd["tower"]; _wind_pump.add_child(ptower)
	var ptail := MeshInstance3D.new(); ptail.mesh = pd["tail"]; _wind_pump.add_child(ptail)
	_pump_wheel = MeshInstance3D.new(); _pump_wheel.mesh = pd["wheel"]; _wind_pump.add_child(_pump_wheel)
	_pump_pivot = pd["wheel_pivot"]; _pump_wheel.position = _pump_pivot
	_pump_sign = float(pd.get("spin_sign", 1.0))

## Scatter a few fallen planks and branches around the farm and the lane so low flying has something to see.
func _build_props() -> void:
	var pieces := NewModels2.debris_pieces()
	var rng := RandomNumberGenerator.new()
	rng.seed = 8071
	for i in 14:
		var around := farm_pos + Vector3(rng.randf_range(-34.0, 34.0), 0.0, rng.randf_range(-34.0, 34.0))
		if Lake.is_wet(around.x, around.z):
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = pieces[rng.randi() % pieces.size()]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mi)
		mi.position = Vector3(around.x, _ground(around.x, around.z) + 0.05, around.z)
		mi.rotation = Vector3(0.0, rng.randf() * TAU, 0.0)

# ------------------------------------------------------------------ per frame
func update(delta: float, drone: Vector3, paused: bool) -> void:
	if paused:
		return
	_time += delta
	# the mill and the pump turn with the wind
	var omega := 0.25 + wind.speed * 0.22
	if _sails != null:
		_sails.rotation.z += _sails_sign * omega * delta
	if _windmill != null:
		var toward := wind.toward()
		var want := atan2(-toward.x, -toward.z) + 0.5
		_windmill.rotation.y = lerp_angle(_windmill.rotation.y, want, clampf(delta * 0.3, 0.0, 1.0))
	if _pump_wheel != null:
		_pump_wheel.rotation.z += _pump_sign * omega * 1.6 * delta
	# discovery: get close enough, and for the low places stay below the tree line
	for poi in _pois:
		if bool(poi.get("discovered", false)):
			continue
		var pos: Vector3 = poi["pos"]
		var d := Vector2(drone.x - pos.x, drone.z - pos.z).length()
		if d > float(poi["radius"]):
			continue
		var alt_max := float(poi.get("alt_max", 0.0))
		if alt_max > 0.0:
			var agl := drone.y - terrain.height(drone.x, drone.z)
			if agl > alt_max:
				continue
		_discover(poi)

func _discover(poi: Dictionary) -> void:
	poi["discovered"] = true
	var id := str(poi["id"])
	if _discovered.has(id):
		return
	_discovered[id] = true
	_save_discovered()
	if notes != null:
		notes.post_text("Riley", "You found " + str(poi["name"]), str(poi["note"]), 0)

## Called by the photo library: a photo of a place counts as finding it too.
func mark_discovered(names: Array) -> void:
	for poi in _pois:
		if str(poi["id"]) in names or str(poi["name"]) in names:
			_discover(poi)

func discovered_count() -> int:
	var n := 0
	for poi in _pois:
		if bool(poi.get("discovered", false)):
			n += 1
	return n

func place_count() -> int:
	return _pois.size()

## Names and screen data for the places in the photo's frame, for the photo metadata and later photo jobs.
func subjects_in_frame(cam: Camera3D) -> Array:
	var out: Array = []
	if cam == null:
		return out
	var vp := cam.get_viewport().get_visible_rect().size
	for poi in _pois:
		var pos: Vector3 = poi["pos"]
		var d := pos.distance_to(cam.global_position)
		if d > 1600.0 or cam.is_position_behind(pos):
			continue
		var sp := cam.unproject_position(pos)
		if sp.x < -vp.x * 0.05 or sp.x > vp.x * 1.05 or sp.y < -vp.y * 0.05 or sp.y > vp.y * 1.05:
			continue
		var radius := maxf(float(poi["radius"]) * 0.4, 4.0)
		var size := radius / maxf(d, 1.0) * (vp.y * 0.5) / tan(deg_to_rad(cam.fov * 0.5))
		out.append({"id": str(poi["id"]), "name": str(poi["name"]), "dist": d, "size": size})
	return out

## The nearest place to a world point, for messages and tests.
func nearest_place(p: Vector3) -> String:
	var best := ""
	var best_d := 1e9
	for poi in _pois:
		var d := Vector3(poi["pos"]).distance_to(p)
		if d < best_d:
			best_d = d
			best = str(poi["name"])
	return best

# ------------------------------------------------------------------ persistence
func _save_discovered() -> void:
	var cf := ConfigFile.new()
	for k in _discovered:
		cf.set_value("places", str(k), true)
	DirAccess.make_dir_recursive_absolute("user://")
	cf.save("user://places.cfg")

func _load_discovered() -> void:
	_discovered.clear()
	var cf := ConfigFile.new()
	if cf.load("user://places.cfg") != OK:
		return
	for k in cf.get_section_keys("places"):
		_discovered[str(k)] = true
	for poi in _pois:
		if _discovered.has(str(poi["id"])):
			poi["discovered"] = true

func stats() -> Dictionary:
	return {"farm": [snappedf(farm_pos.x, 0.1), snappedf(farm_pos.y, 0.1), snappedf(farm_pos.z, 0.1)],
		"discovered": discovered_count(), "places": place_count()}

## Dev hook: mark every place found, for the field notes shot and tests.
func debug_discover_all() -> void:
	for poi in _pois:
		_discover(poi)

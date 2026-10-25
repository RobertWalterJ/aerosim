class_name Traffic
extends Node3D
## Traffic on the country roads (session B): a handful of cars, a pickup, a van and a slow tractor moving along the
## valley highway, lakeside lane and ridge road, in both directions, with their wheels turning and headlights coming on
## in the dark. Harmless scenery: no collisions, no gameplay, just life on the roads.
##
## The vehicles load the shared GLB fleet from assets/traffic when those files exist, and fall back to the code-built
## placeholders until then. Counts are deliberately low: three on a computer, two on a phone. The valley is meant to
## feel emptier than a traffic sim; a vehicle should be an event, not wallpaper.

const TYPES := [
	{"name": "hatchback", "id": "hatchback_a", "model": "res://assets/models/vehicles/car_hatch_a.glb", "body": Vector3(1.75, 0.62, 3.9), "cab": Vector3(1.55, 0.52, 1.9), "cab_y": 0.78, "speed": 13.5, "colour": Color(0.62, 0.20, 0.16)},
	{"name": "hatchback", "id": "hatchback_b", "model": "res://assets/models/vehicles/car_hatch_b.glb", "body": Vector3(1.75, 0.62, 3.9), "cab": Vector3(1.55, 0.52, 1.9), "cab_y": 0.78, "speed": 12.0, "colour": Color(0.24, 0.32, 0.44)},
	{"name": "pickup", "id": "pickup_a", "model": "res://assets/models/vehicles/pickup_a.glb", "body": Vector3(1.85, 0.72, 4.8), "cab": Vector3(1.65, 0.62, 1.7), "cab_y": 0.86, "speed": 11.0, "colour": Color(0.70, 0.68, 0.60)},
	{"name": "van", "id": "van_a", "model": "res://assets/models/vehicles/van_a.glb", "body": Vector3(1.95, 1.35, 4.6), "cab": Vector3(1.80, 0.80, 1.2), "cab_y": 1.55, "speed": 10.0, "colour": Color(0.82, 0.82, 0.80)},
	{"name": "tractor", "id": "tractor_a", "model": "res://assets/models/vehicles/tractor_a.glb", "body": Vector3(1.55, 0.95, 3.2), "cab": Vector3(1.30, 1.10, 1.4), "cab_y": 1.45, "speed": 6.0, "colour": Color(0.36, 0.44, 0.20)},
]

var terrain: Terrain
var roads: Roads
var hud: Hud
var _vehicles: Array = []
var _thermal_on := false
var _mobile := false
var _debug_freeze := false

func setup(t: Terrain, r: Roads, h: Hud) -> void:
	terrain = t
	roads = r
	hud = h
	_mobile = OS.has_feature("mobile")
	# Sparse, deliberate traffic. Two vehicles pass each other through the village; one car works the
	# empty highway. This keeps the town livelier than the open road and lets headlights carry the night.
	var plan: Array = [
		{"route": "village", "dir": 1.0, "type": 0, "s": 0.16},
		{"route": "village", "dir": -1.0, "type": 3, "s": 0.70},
		{"route": "valley", "dir": -1.0, "type": 2, "s": 0.42, "night": 1},
	]
	if _mobile:
		plan = [
			{"route": "village", "dir": 1.0, "type": 0, "s": 0.16},
			{"route": "valley", "dir": -1.0, "type": 2, "s": 0.42, "night": 1},
		]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4451
	var all_routes: Array = roads.route_ids()
	for p in plan:
		var route := str(p["route"])
		if not route in all_routes:
			if all_routes.is_empty():
				continue
			route = str(all_routes[0])
		var length: float = float(roads._lengths.get(route, 1.0))
		var type: Dictionary = TYPES[int(p["type"]) % TYPES.size()]
		var v: Dictionary = _make_vehicle(type, route, float(p["s"]) * length, float(p["dir"]), rng)
		v["night_only"] = bool(p.get("night", 0))
		_vehicles.append(v)
	print("traffic: ", stats())
func _make_vehicle(type: Dictionary, route: String, s: float, dir: float, rng: RandomNumberGenerator) -> Dictionary:
	var node := Node3D.new()
	add_child(node)
	var model_path := str(type.get("model", ""))
	if model_path != "" and ResourceLoader.exists(model_path):
		var packed := load(model_path) as PackedScene
		if packed != null:
			var inst := packed.instantiate()
			node.add_child(inst)
			var model_wheels: Array = []
			for n in inst.find_children("wheel_*", "Node3D", true, false):
				model_wheels.append(n)
			var lamps: Array = []
			for n in inst.find_children("*", "MeshInstance3D", true, false):
				var mi := n as MeshInstance3D
				var m = mi.get_active_material(0)
				if m is StandardMaterial3D:
					var mm := m as StandardMaterial3D
					if mm.resource_name.to_lower().contains("headlight"):
						lamps.append(mm)
			var heat := ThermalHeat.vehicle(node, type["body"], type["cab"], float(type["cab_y"]))
			heat.visible = _thermal_on
			var lights := _add_vehicle_lights(node, type)
			return {"node": node, "type": type, "route": route, "s": s, "dir": dir,
				"speed": float(type["speed"]) * rng.randf_range(0.9, 1.1),
				"wheels": model_wheels, "wheel_axis": "x", "lamp": null, "lamps": lamps, "lights": lights, "model": true, "heat": heat}
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = type["colour"]
	body_mat.roughness = 0.45
	body_mat.metallic = 0.35
	var body := BoxMesh.new()
	body.size = type["body"]
	var body_mi := MeshInstance3D.new()
	body_mi.mesh = body
	body_mi.material_override = body_mat
	body_mi.position.y = float(type["body"].y) * 0.5 + 0.32
	node.add_child(body_mi)
	var cab := BoxMesh.new()
	cab.size = type["cab"]
	var cab_mi := MeshInstance3D.new()
	cab_mi.mesh = cab
	cab_mi.material_override = body_mat
	cab_mi.position = Vector3(0.0, float(type["cab_y"]) + 0.1, -0.25)
	node.add_child(cab_mi)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.10, 0.12, 0.14)
	glass.metallic = 0.6
	glass.roughness = 0.15
	var win := BoxMesh.new()
	win.size = Vector3(float(type["cab"].x) * 0.88, float(type["cab"].y) * 0.62, 0.06)
	var win_mi := MeshInstance3D.new()
	win_mi.mesh = win
	win_mi.material_override = glass
	win_mi.position = Vector3(0.0, float(type["cab_y"]) + 0.25, -0.25 - float(type["cab"].z) * 0.5)
	node.add_child(win_mi)
	# wheels: cylinders turned on their side
	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = 0.34
	wheel_mesh.bottom_radius = 0.34
	wheel_mesh.height = 0.22
	wheel_mesh.radial_segments = 10
	var wheel_mat := StandardMaterial3D.new()
	wheel_mat.albedo_color = Color(0.06, 0.06, 0.06)
	var wheels: Array = []
	var wx := float(type["body"].x) * 0.5 + 0.06
	var wz := float(type["body"].z) * 0.5 - 0.55
	for p in [Vector3(-wx, 0.34, -wz), Vector3(wx, 0.34, -wz), Vector3(-wx, 0.34, wz), Vector3(wx, 0.34, wz)]:
		var w := MeshInstance3D.new()
		w.mesh = wheel_mesh
		w.material_override = wheel_mat
		w.position = p
		w.rotation = Vector3(0.0, 0.0, PI * 0.5)
		node.add_child(w)
		wheels.append(w)
	# headlights and tail lights (emissive, no real lights: cheap and works on the phone)
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(0.95, 0.92, 0.72)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.92, 0.65)
	lamp_mat.emission_energy_multiplier = 0.0
	for sx in [-1.0, 1.0]:
		var lamp := BoxMesh.new()
		lamp.size = Vector3(0.24, 0.12, 0.06)
		var lamp_mi := MeshInstance3D.new()
		lamp_mi.mesh = lamp
		lamp_mi.material_override = lamp_mat
		lamp_mi.position = Vector3(sx * float(type["body"].x) * 0.28, 0.62, -float(type["body"].z) * 0.5)
		node.add_child(lamp_mi)
	var heat := ThermalHeat.vehicle(node, type["body"], type["cab"], float(type["cab_y"]))
	heat.visible = _thermal_on
	var lights := _add_vehicle_lights(node, type)
	return {"node": node, "type": type, "route": route, "s": s, "dir": dir, "speed": float(type["speed"]) * rng.randf_range(0.9, 1.1), "wheels": wheels, "wheel_axis": "z", "lamp": lamp_mat, "lamps": [lamp_mat], "lights": lights, "heat": heat}

func _add_vehicle_lights(node: Node3D, type: Dictionary) -> Array:
	var out: Array = []
	var body: Vector3 = type["body"]
	var front := -body.z * 0.5 - 0.05
	# extra emissive lamp faces make the headlights unmistakable even where an imported model lamp material is dull.
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1.0, 0.94, 0.78)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.88, 0.62)
	glow_mat.emission_energy_multiplier = 0.0
	for sx in [-1.0, 1.0]:
		var lamp := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.24, 0.12, 0.05)
		lamp.mesh = lm
		lamp.material_override = glow_mat
		lamp.position = Vector3(sx * body.x * 0.30, 0.72, front - 0.42)
		node.add_child(lamp)
		out.append(lamp)
	for sx in [-1.0, 1.0]:
		var spot := SpotLight3D.new()
		spot.position = Vector3(sx * body.x * 0.30, 0.70, front - 0.42)
		spot.spot_range = 48.0
		spot.spot_angle = 24.0
		spot.spot_attenuation = 0.55
		spot.light_color = Color(1.0, 0.93, 0.78)
		spot.light_energy = 0.0
		spot.shadow_enabled = false
		spot.visible = false
		node.add_child(spot)
		out.append(spot)
	# a small red tail glow, so a car going away reads as a car and not a dark box
	var tail_mat := StandardMaterial3D.new()
	tail_mat.albedo_color = Color(0.75, 0.04, 0.02)
	tail_mat.emission_enabled = true
	tail_mat.emission = Color(1.0, 0.04, 0.01)
	tail_mat.emission_energy_multiplier = 0.0
	for sx in [-1.0, 1.0]:
		var tail := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.22, 0.10, 0.05)
		tail.mesh = tm
		tail.material_override = tail_mat
		tail.position = Vector3(sx * body.x * 0.30, 0.62, body.z * 0.5 + 0.03)
		node.add_child(tail)
	return out

func update(delta: float, hour: float, paused: bool) -> void:
	if paused or _debug_freeze:
		return
	var darkness := 0.0
	if hour < 6.0 or hour > 19.0:
		darkness = 1.0
	elif hour < 7.0:
		darkness = 1.0 - (hour - 6.0)
	elif hour > 17.5:
		darkness = clampf((hour - 17.5) / 2.0, 0.0, 1.0)
	for v in _vehicles:
		var route := str(v["route"])
		var pts: Array = roads.path(route)
		if pts.size() < 2:
			continue
		var length: float = float(roads._lengths.get(route, 1.0))
		var limit := roads.speed_limit(route) * 0.44704 * 0.85
		var speed := minf(float(v["speed"]), limit)
		var s: float = float(v["s"]) + speed * delta * float(v["dir"])
		if s > length:
			s = 0.0
		if s < 0.0:
			s = length
		v["s"] = s
		var smp: Dictionary = roads.sample(route, s)
		if smp.is_empty():
			continue
		var pos: Vector2 = smp["pos"]
		var tangent: Vector2 = smp["dir"] * float(v["dir"])
		# Drive on the right: each direction keeps to its own side of the centreline. For a 5 m lane
		# that is 1.25 m from the centre, so opposing cars pass with a real gap instead of sharing a line.
		var side := Vector2(-tangent.y, tangent.x)
		var lane_off := maxf(1.0, roads.width(route) * 0.25)
		var lane := pos + side * lane_off
		var y := terrain.height(lane.x, lane.y) + 0.05
		var node: Node3D = v["node"]
		node.global_position = Vector3(lane.x, y, lane.y)
		node.visible = not bool(v.get("night_only", false)) or darkness > 0.35
		node.rotation.y = atan2(-tangent.x, -tangent.y)
		var wheels: Array = v["wheels"]
		var spin := speed * delta / 0.34
		var wheel_axis := str(v.get("wheel_axis", "z"))
		for w in wheels:
			if wheel_axis == "x":
				(w as Node3D).rotation.x += spin
			else:
				(w as Node3D).rotation.z += spin
		for lm in v.get("lamps", []):
			var lamp := lm as StandardMaterial3D
			if lamp != null:
				lamp.emission_energy_multiplier = 2.4 * darkness
		for light in v.get("lights", []):
			if light is SpotLight3D:
				var spot := light as SpotLight3D
				spot.visible = darkness > 0.28
				spot.light_energy = 4.8 * darkness
			elif light is MeshInstance3D:
				var lm := (light as MeshInstance3D).material_override as StandardMaterial3D
				if lm != null:
					lm.emission_energy_multiplier = 3.2 * darkness
		# brake/tail glow is left off on purpose: no real lights mean no cost on the phone

## Dev hook: line the vehicles up along the valley highway for a look shot.
## The thermal camera sees the engine, cabin and exhaust of every moving vehicle. The body stays cool.
func debug_freeze(on: bool) -> void:
	_debug_freeze = on

func debug_night_vehicle() -> Dictionary:
	if _vehicles.is_empty():
		return {}
	var node: Node3D = _vehicles[_vehicles.size() - 1]["node"]
	var yaw := node.rotation.y
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	return {"pos": node.global_position, "yaw": yaw, "fwd": fwd, "visible": node.visible}

func first_vehicle_position() -> Vector3:
	if _vehicles.is_empty():
		return Vector3.ZERO
	var n: Node3D = _vehicles[0]["node"]
	return n.global_position

func trace_sources() -> Array:
	var out: Array = []
	for i in _vehicles.size():
		var node: Node3D = _vehicles[i]["node"]
		if node != null and node.visible:
			out.append({"key": i, "pos": node.global_position, "yaw": node.rotation.y, "kind": "vehicle"})
	return out

func set_thermal_heat(on: bool) -> void:
	_thermal_on = on
	for v in _vehicles:
		var heat: Node3D = v.get("heat")
		if heat != null:
			heat.visible = on
func debug_line_up() -> void:
	for i in _vehicles.size():
		var v: Dictionary = _vehicles[i]
		v["route"] = "valley"
		v["s"] = 90.0 + float(i) * 26.0
		v["dir"] = 1.0

func stats() -> Dictionary:
	var routes: Array = []
	var dirs: Array = []
	for v in _vehicles:
		routes.append(str(v["route"]))
		dirs.append(float(v["dir"]))
	return {"vehicles": _vehicles.size(), "mobile": _mobile, "routes": routes, "directions": dirs}

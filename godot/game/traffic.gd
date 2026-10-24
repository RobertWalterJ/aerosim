class_name Traffic
extends Node3D
## Traffic on the country roads (session B): a handful of cars, a pickup, a van and a slow tractor moving along the
## valley highway, lakeside lane and ridge road, in both directions, with their wheels turning and headlights coming on
## in the dark. Harmless scenery: no collisions, no gameplay, just life on the roads.
##
## The vehicles load Claude's GLB fleet from assets/traffic when those files exist, and fall back to the code-built placeholders until then. Counts:
## eight on a computer, four on a phone; speeds 7 to 16 m/s and the tractor about 6, so the roads never look empty but
## the drone can easily outpace them.

const TYPES := [
	{"name": "hatchback", "id": "hatchback_a", "model": "res://assets/traffic/hatchback_a.glb", "body": Vector3(1.75, 0.62, 3.9), "cab": Vector3(1.55, 0.52, 1.9), "cab_y": 0.78, "speed": 13.5, "colour": Color(0.62, 0.20, 0.16)},
	{"name": "hatchback", "id": "hatchback_b", "model": "res://assets/traffic/hatchback_b.glb", "body": Vector3(1.75, 0.62, 3.9), "cab": Vector3(1.55, 0.52, 1.9), "cab_y": 0.78, "speed": 12.0, "colour": Color(0.24, 0.32, 0.44)},
	{"name": "pickup", "id": "pickup_a", "model": "res://assets/traffic/pickup_a.glb", "body": Vector3(1.85, 0.72, 4.8), "cab": Vector3(1.65, 0.62, 1.7), "cab_y": 0.86, "speed": 11.0, "colour": Color(0.70, 0.68, 0.60)},
	{"name": "van", "id": "van_a", "model": "res://assets/traffic/van_a.glb", "body": Vector3(1.95, 1.35, 4.6), "cab": Vector3(1.80, 0.80, 1.2), "cab_y": 1.55, "speed": 10.0, "colour": Color(0.82, 0.82, 0.80)},
	{"name": "tractor", "id": "tractor_a", "model": "res://assets/traffic/tractor_a.glb", "body": Vector3(1.55, 0.95, 3.2), "cab": Vector3(1.30, 1.10, 1.4), "cab_y": 1.45, "speed": 6.0, "colour": Color(0.36, 0.44, 0.20)},
]

var terrain: Terrain
var roads: Roads
var hud: Hud
var _vehicles: Array = []
var _mobile := false

func setup(t: Terrain, r: Roads, h: Hud) -> void:
	terrain = t
	roads = r
	hud = h
	_mobile = OS.has_feature("mobile")
	var n := 4 if _mobile else 8
	var all_routes: Array = roads.route_ids()
	var routes: Array = []
	for id in all_routes:
		# keep the tiny gate driveways and field spurs for the player to read; traffic belongs on the real roads
		if float(roads._lengths.get(str(id), 0.0)) >= 100.0:
			routes.append(id)
	if routes.is_empty():
		routes = all_routes
	var rng := RandomNumberGenerator.new()
	rng.seed = 4451
	for i in n:
		var type: Dictionary = TYPES[i % TYPES.size()]
		var route := str(routes[i % routes.size()])
		var length: float = float(roads._lengths.get(route, 1.0))
		_vehicles.append(_make_vehicle(type, route, rng.randf() * length, 1.0 if i % 2 == 0 else -1.0, rng))
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
			return {"node": node, "type": type, "route": route, "s": s, "dir": dir,
				"speed": float(type["speed"]) * rng.randf_range(0.9, 1.1),
				"wheels": model_wheels, "wheel_axis": "x", "lamp": null, "lamps": lamps, "model": true}
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
	return {"node": node, "type": type, "route": route, "s": s, "dir": dir, "speed": float(type["speed"]) * rng.randf_range(0.9, 1.1), "wheels": wheels, "wheel_axis": "z", "lamp": lamp_mat, "lamps": [lamp_mat]}

func update(delta: float, hour: float, paused: bool) -> void:
	if paused:
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
		var side := Vector2(-tangent.y, tangent.x)
		var lane := pos + side * 1.85
		var y := terrain.height(lane.x, lane.y) + 0.05
		var node: Node3D = v["node"]
		node.global_position = Vector3(lane.x, y, lane.y)
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
		# brake/tail glow is left off on purpose: no real lights mean no cost on the phone

## Dev hook: line the vehicles up along the valley highway for a look shot.
func debug_line_up() -> void:
	for i in _vehicles.size():
		var v: Dictionary = _vehicles[i]
		v["route"] = "valley"
		v["s"] = 90.0 + float(i) * 26.0
		v["dir"] = 1.0

func stats() -> Dictionary:
	return {"vehicles": _vehicles.size(), "mobile": _mobile}

class_name IntersectionSignals
extends Node3D
## Rural flashing-red beacons over the main junctions (session B). Country intersections often have a single red beacon
## hanging from a wire between two poles instead of a full traffic light. The beacon flashes, the lens material glows and
## a red OmniLight pulses at night. It is scenery, not a rule: traffic still follows the road loop.
##
## Each beacon can be switched off in the pause menu under Display > World > Intersection beacons.

var terrain: Terrain
var hud: Hud
var _time := 0.0
var _beacons: Array = []

const JUNCTIONS := [
	{"center": Vector2(270.0, 42.0), "axis": Vector2(1.0, 0.0), "span": 20.0},
	{"center": Vector2(286.0, 260.0), "axis": Vector2(0.0, 1.0), "span": 18.0},
	{"center": Vector2(215.0, 505.0), "axis": Vector2(1.0, 0.0), "span": 20.0},
	{"center": Vector2(12.0, -255.0), "axis": Vector2(0.0, 1.0), "span": 18.0},
	{"center": Vector2(-300.0, 300.0), "axis": Vector2(1.0, 0.0), "span": 18.0},
]

func setup(t: Terrain, h: Hud) -> void:
	terrain = t
	hud = h
	for spec in JUNCTIONS:
		_build_beacon(spec)
	print("intersection beacons: ", _beacons.size())

func _build_beacon(spec: Dictionary) -> void:
	var center: Vector2 = spec["center"]
	var axis: Vector2 = spec["axis"]
	var half := float(spec["span"]) * 0.5
	var tops: Array[Vector3] = []
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.22, 0.19, 0.15)
	wood.roughness = 0.92
	for side in [-1.0, 1.0]:
		var p: Vector2 = center + axis * half * float(side)
		var y := terrain.height(p.x, p.y)
		var pole := CylinderMesh.new()
		pole.top_radius = 0.13
		pole.bottom_radius = 0.17
		pole.height = 6.5
		pole.radial_segments = 8
		var pi := MeshInstance3D.new()
		pi.mesh = pole
		pi.material_override = wood
		pi.position = Vector3(p.x, y + 3.25, p.y)
		add_child(pi)
		var top := Vector3(p.x, y + 6.35, p.y)
		tops.append(top)
		var cap := BoxMesh.new()
		cap.size = Vector3(0.34, 0.10, 0.34)
		var ci := MeshInstance3D.new()
		ci.mesh = cap
		ci.material_override = wood
		ci.position = top + Vector3(0.0, 0.05, 0.0)
		add_child(ci)
	# a taut cable between the poles; box along X, aligned to the span
	var a := tops[0]
	var b := tops[1]
	var d := b - a
	var cable := BoxMesh.new()
	cable.size = Vector3(d.length(), 0.035, 0.035)
	var cmi := MeshInstance3D.new()
	cmi.mesh = cable
	var cable_mat := StandardMaterial3D.new()
	cable_mat.albedo_color = Color(0.06, 0.06, 0.055)
	cable_mat.roughness = 0.5
	cmi.material_override = cable_mat
	cmi.position = (a + b) * 0.5
	cmi.rotation.y = atan2(-d.z, d.x)
	cmi.rotation.z = atan2(d.y, Vector2(d.x, d.z).length())
	add_child(cmi)
	# the beacon hanging under the middle of the cable
	var mid := (a + b) * 0.5
	var beacon_y := mid.y - 0.95
	var hanger := BoxMesh.new()
	hanger.size = Vector3(0.035, 0.85, 0.035)
	var hi := MeshInstance3D.new()
	hi.mesh = hanger
	hi.material_override = cable_mat
	hi.position = Vector3(mid.x, beacon_y + 0.42, mid.z)
	add_child(hi)
	var housing := BoxMesh.new()
	housing.size = Vector3(0.62, 0.50, 0.38)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.10, 0.09, 0.07)
	hmat.roughness = 0.6
	var hmi := MeshInstance3D.new()
	hmi.mesh = housing
	hmi.material_override = hmat
	hmi.position = Vector3(mid.x, beacon_y, mid.z)
	add_child(hmi)
	var visor := BoxMesh.new()
	visor.size = Vector3(0.76, 0.12, 0.52)
	var vmi := MeshInstance3D.new()
	vmi.mesh = visor
	vmi.material_override = hmat
	vmi.position = Vector3(mid.x, beacon_y + 0.32, mid.z + 0.06)
	add_child(vmi)
	# the yellow diamond backplate that makes a rural beacon read from a distance
	var backplate := BoxMesh.new()
	backplate.size = Vector3(0.94, 0.94, 0.05)
	var bp_mat := StandardMaterial3D.new()
	bp_mat.albedo_color = Color(0.72, 0.58, 0.10)
	bp_mat.roughness = 0.7
	var bpi := MeshInstance3D.new()
	bpi.mesh = backplate
	bpi.material_override = bp_mat
	bpi.position = Vector3(mid.x, beacon_y, mid.z - 0.31)
	bpi.rotation.z = PI * 0.25
	add_child(bpi)
	var lens := SphereMesh.new()
	lens.radius = 0.20
	lens.height = 0.40
	var lens_mat := StandardMaterial3D.new()
	lens_mat.albedo_color = Color(0.75, 0.08, 0.05)
	lens_mat.emission_enabled = true
	lens_mat.emission = Color(1.0, 0.08, 0.03)
	lens_mat.emission_energy_multiplier = 5.0
	lens_mat.roughness = 0.25
	var lmi := MeshInstance3D.new()
	lmi.mesh = lens
	lmi.material_override = lens_mat
	lmi.position = Vector3(mid.x, beacon_y, mid.z + 0.21)
	add_child(lmi)
	var back_lens := MeshInstance3D.new()
	back_lens.mesh = lens
	back_lens.material_override = lens_mat
	back_lens.position = Vector3(mid.x, beacon_y, mid.z - 0.22)
	add_child(back_lens)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.08, 0.03)
	light.light_energy = 1.2
	light.omni_range = 13.0
	light.shadow_enabled = false
	light.position = Vector3(mid.x, beacon_y, mid.z + 0.35)
	add_child(light)
	_beacons.append({"lens": lens_mat, "light": light})

func _process(delta: float) -> void:
	_time += delta
	var on := hud == null or hud.beacons_on
	var flash := on and fmod(_time, 1.35) < 0.68
	for b in _beacons:
		var lens: StandardMaterial3D = b["lens"]
		var light: OmniLight3D = b["light"]
		lens.emission_energy_multiplier = 6.5 if flash else 0.20
		light.light_energy = 2.2 if flash else 0.0

func stats() -> Dictionary:
	return {"beacons": _beacons.size()}

class_name CaseObjects
extends Node3D
## The physical evidence landmarks for the Lake Car story (session B): the abandoned car by the lake, the Voss and Son
## garage, the camp on the ridge and the old festival bus. Until Claude's models arrive these are simple code built
## placeholders. They exist so the pilot can fly to them, photograph them, and have the photo metadata carry their ids
## into the Casebook and the story state.
##
## The car's shore point is found from the lake shape at startup, and the clearing around every landmark is applied
## before the world is planted. The bus moves from the garage to the festival field when the last chapter begins.
## Nothing here has collisions; the landmarks are harmless scenery like the rest of the valley.

const GARAGE_SPOT := Vector2(55.0, -600.0)
const CAMP_SPOT := Vector2(36.0, -1120.0)
const FESTIVAL_SPOT := Vector2(300.0, 300.0)
const CABIN_SPOT := Vector2(-250.0, -820.0)
const CAVE_SPOT := Vector2(-292.0, -806.0)
const SEARCH_SPOT := Vector2(-70.0, -790.0)
const SHEEP_SPOT := Vector2(55.0, 585.0)
const WOLF_SPOT := Vector2(18.0, 552.0)
const BOAT_LAUNCH_SPOT := Vector2(-430.0, 112.0)

var terrain: Terrain
var _items: Array[Dictionary] = []
var _bus_root: Node3D
var _campfire: OmniLight3D
var _time := 0.0
var _bus_at_festival := false
var _cabin_lights: Array[OmniLight3D] = []
var _cabin_windows: Array[MeshInstance3D] = []
var _cabin_root: Node3D
var _hiker: Node3D
var _hiker_heat: Node3D
var _dog_heat: Node3D
var _cabin_on := false
var _porch_light: OmniLight3D

static var _car_spot := Vector2.INF

## Called before the world is planted so the trees and props can keep clear of the evidence landmarks.
static func prepare(t: Terrain) -> void:
	_car_spot = _compute_shore(t)

static func near_evidence(x: float, z: float, margin := 30.0) -> bool:
	if _car_spot != Vector2.INF and Vector2(x, z).distance_to(_car_spot) < margin:
		return true
	for p in [GARAGE_SPOT, CAMP_SPOT, FESTIVAL_SPOT, CABIN_SPOT, CAVE_SPOT, SEARCH_SPOT, SHEEP_SPOT, WOLF_SPOT, BOAT_LAUNCH_SPOT]:
		if Vector2(x, z).distance_to(p) < margin:
			return true
	return false

func setup(t: Terrain) -> void:
	terrain = t
	var car := _find_shore()
	_items.append({"id": "case_lake_car", "name": "the abandoned car", "pos": Vector3(car.x, t.height(car.x, car.y), car.y), "radius": 3.2})
	_items.append({"id": "case_garage", "name": "Voss and Son Motor Works", "pos": Vector3(GARAGE_SPOT.x, t.height(GARAGE_SPOT.x, GARAGE_SPOT.y), GARAGE_SPOT.y), "radius": 7.0})
	_items.append({"id": "case_camp", "name": "the camp on the ridge", "pos": Vector3(CAMP_SPOT.x, t.height(CAMP_SPOT.x, CAMP_SPOT.y), CAMP_SPOT.y), "radius": 6.0})
	var bus_pos := Vector3(GARAGE_SPOT.x + 10.0, 0.0, GARAGE_SPOT.y - 8.0)
	bus_pos.y = t.height(bus_pos.x, bus_pos.z)
	_items.append({"id": "case_bus", "name": "the old festival bus", "pos": bus_pos, "radius": 7.0})
	_items.append({"id": "case_cabin", "name": "the abandoned cabin", "pos": Vector3(CABIN_SPOT.x, t.height(CABIN_SPOT.x, CABIN_SPOT.y), CABIN_SPOT.y), "radius": 7.0})
	_items.append({"id": "case_cruiser", "name": "the old police cruiser", "pos": Vector3(CABIN_SPOT.x + 9.0, t.height(CABIN_SPOT.x + 9.0, CABIN_SPOT.y - 5.0), CABIN_SPOT.y - 5.0), "radius": 4.0})
	_items.append({"id": "cave_entrance", "name": "the old cave entrance", "pos": Vector3(CAVE_SPOT.x, t.height(CAVE_SPOT.x, CAVE_SPOT.y), CAVE_SPOT.y), "radius": 6.0})
	_items.append({"id": "boat_launch", "name": "the boat launch", "pos": Vector3(BOAT_LAUNCH_SPOT.x, t.height(BOAT_LAUNCH_SPOT.x, BOAT_LAUNCH_SPOT.y), BOAT_LAUNCH_SPOT.y), "radius": 11.0})
	_build_car(_items[0]["pos"])
	_build_garage(_items[1]["pos"])
	_build_camp(_items[2]["pos"])
	_build_bus(bus_pos)
	_build_cabin(_items[4]["pos"])
	_build_cruiser(_items[5]["pos"])
	_build_hiker()
	print("case objects: ", positions())

## Move the old festival bus from the garage yard to the festival field, for the last chapter.
func move_bus_to_festival() -> void:
	if _bus_root == null or _bus_at_festival:
		return
	var p := Vector3(FESTIVAL_SPOT.x, terrain.height(FESTIVAL_SPOT.x, FESTIVAL_SPOT.y), FESTIVAL_SPOT.y)
	_bus_root.position = p
	_bus_root.rotation.y = -0.5
	for it in _items:
		if str(it["id"]) == "case_bus":
			it["pos"] = p
	_bus_at_festival = true

func bus_at_festival() -> bool:
	return _bus_at_festival

# ------------------------------------------------------------------ the shore point
static func _compute_shore(t: Terrain) -> Vector2:
	var best := Vector2(-430.0, -120.0)
	var best_score := -1e9
	for z in range(-520, 281, 20):
		for x in range(-1000, -339, 20):
			if Lake.is_wet(x, z):
				continue
			var wet := false
			for d in [Vector2(20, 0), Vector2(-20, 0), Vector2(0, 20), Vector2(0, -20)]:
				if Lake.is_wet(x + d.x, z + d.y):
					wet = true
					break
			if not wet:
				continue
			var n := t.normal_at(x, z)
			var slope := 1.0 - n.y
			var score := -float(z) - absf(x + 620.0) * 0.15 - slope * 120.0
			if score > best_score:
				best_score = score
				best = Vector2(x, z)
	var water := Vector2.ZERO
	var wd := 1e9
	for dz in range(-40, 41, 4):
		for dx in range(-40, 41, 4):
			var q := best + Vector2(dx, dz)
			if Lake.is_wet(q.x, q.y):
				var dd := Vector2(dx, dz).length()
				if dd < wd:
					wd = dd
					water = q
	if wd < 1e8:
		var dir := (water - best).normalized()
		var p := best
		for i in 24:
			var q2 := p + dir * 3.0
			if Lake.is_wet(q2.x, q2.y):
				break
			p = q2
		best = p - dir * 4.0
	return best

func _find_shore() -> Vector2:
	if _car_spot == Vector2.INF:
		_car_spot = _compute_shore(terrain)
	return _car_spot

func positions() -> Dictionary:
	var out := {}
	for it in _items:
		out[str(it["id"])] = [snappedf(it["pos"].x, 0.1), snappedf(it["pos"].y, 0.1), snappedf(it["pos"].z, 0.1)]
	return out

func item_pos(id: String) -> Vector3:
	for it in _items:
		if str(it["id"]) == id:
			return it["pos"]
	return Vector3.ZERO

func item_name(id: String) -> String:
	for it in _items:
		if str(it["id"]) == id:
			return str(it["name"])
	return id

# ------------------------------------------------------------------ the car
func _build_car(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var faded := StandardMaterial3D.new()
	faded.albedo_color = Color(0.30, 0.36, 0.44)
	faded.roughness = 0.7
	faded.metallic = 0.2
	var body := BoxMesh.new()
	body.size = Vector3(1.85, 0.62, 4.2)
	var bmi := MeshInstance3D.new()
	bmi.mesh = body
	bmi.material_override = faded
	bmi.position.y = 0.58
	root.add_child(bmi)
	var roof := BoxMesh.new()
	roof.size = Vector3(1.62, 0.52, 1.9)
	var rmi := MeshInstance3D.new()
	rmi.mesh = roof
	rmi.material_override = faded
	rmi.position = Vector3(0.0, 1.12, 0.1)
	root.add_child(rmi)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.10, 0.12, 0.13)
	glass.roughness = 0.2
	glass.metallic = 0.6
	var win := BoxMesh.new()
	win.size = Vector3(1.5, 0.34, 1.8)
	var wmi := MeshInstance3D.new()
	wmi.mesh = win
	wmi.material_override = glass
	wmi.position = Vector3(0.0, 1.18, 0.1)
	root.add_child(wmi)
	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = 0.34
	wheel_mesh.bottom_radius = 0.34
	wheel_mesh.height = 0.22
	wheel_mesh.radial_segments = 10
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.06, 0.06, 0.06)
	for p in [Vector3(-0.96, 0.34, -1.35), Vector3(0.96, 0.34, -1.35), Vector3(-0.96, 0.34, 1.35), Vector3(0.96, 0.34, 1.35)]:
		var w := MeshInstance3D.new()
		w.mesh = wheel_mesh
		w.material_override = rubber
		w.position = p
		w.rotation = Vector3(0.0, 0.0, PI * 0.5)
		root.add_child(w)
	var lid := BoxMesh.new()
	lid.size = Vector3(1.7, 0.06, 1.4)
	var lmi := MeshInstance3D.new()
	lmi.mesh = lid
	lmi.material_override = faded
	lmi.position = Vector3(0.0, 1.15, 2.35)
	lmi.rotation = Vector3(-0.9, 0.0, 0.0)
	root.add_child(lmi)
	root.rotation.y = 0.7
	root.rotation.z = 0.04
	# tyre marks leading inland, so the car reads as something that was driven here
	var marks := StandardMaterial3D.new()
	marks.albedo_color = Color(0.22, 0.18, 0.12)
	marks.roughness = 1.0
	for sx in [-1.0, 1.0]:
		var strip := BoxMesh.new()
		strip.size = Vector3(0.28, 0.02, 14.0)
		var smi := MeshInstance3D.new()
		smi.mesh = strip
		smi.material_override = marks
		smi.position = Vector3(sx * 0.8, 0.04, -7.5)
		smi.rotation.y = -0.35
		root.add_child(smi)

# ------------------------------------------------------------------ the garage
func _build_garage(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var wall := StandardMaterial3D.new()
	wall.albedo_color = Color(0.33, 0.29, 0.23)
	wall.roughness = 0.95
	var rust := StandardMaterial3D.new()
	rust.albedo_color = Color(0.26, 0.20, 0.15)
	rust.roughness = 0.98
	var main := BoxMesh.new()
	main.size = Vector3(11.0, 3.6, 7.0)
	var mmi := MeshInstance3D.new()
	mmi.mesh = main
	mmi.material_override = wall
	mmi.position.y = 1.8
	root.add_child(mmi)
	var roof := BoxMesh.new()
	roof.size = Vector3(11.8, 0.25, 7.8)
	var rmi := MeshInstance3D.new()
	rmi.mesh = roof
	rmi.material_override = rust
	rmi.position.y = 3.75
	root.add_child(rmi)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.04, 0.04, 0.04)
	dark.roughness = 1.0
	var opening := BoxMesh.new()
	opening.size = Vector3(3.6, 2.6, 0.08)
	var omi := MeshInstance3D.new()
	omi.mesh = opening
	omi.material_override = dark
	omi.position = Vector3(-1.5, 1.3, -3.54)
	root.add_child(omi)
	var door := BoxMesh.new()
	door.size = Vector3(3.6, 0.9, 0.12)
	var dmi := MeshInstance3D.new()
	dmi.mesh = door
	dmi.material_override = rust
	dmi.position = Vector3(-1.5, 2.9, -3.62)
	root.add_child(dmi)
	var sign := Label3D.new()
	sign.text = "VOSS & SON"
	sign.font_size = 48
	sign.pixel_size = 0.01
	sign.modulate = Color(0.72, 0.64, 0.45)
	sign.position = Vector3(-1.5, 3.2, -3.56)
	sign.rotation = Vector3(0.0, PI, 0.0)
	root.add_child(sign)
	root.rotation.y = 0.25

# ------------------------------------------------------------------ the camp
func _build_camp(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var canvas := StandardMaterial3D.new()
	canvas.albedo_color = Color(0.24, 0.30, 0.24)
	canvas.roughness = 0.95
	var tarp_mat := StandardMaterial3D.new()
	tarp_mat.albedo_color = Color(0.20, 0.30, 0.38)
	tarp_mat.roughness = 0.9
	# A-frame tent from two slanted roofs
	for sx in [-1.0, 1.0]:
		var panel := BoxMesh.new()
		panel.size = Vector3(2.6, 0.08, 3.4)
		var pmi := MeshInstance3D.new()
		pmi.mesh = panel
		pmi.material_override = canvas
		pmi.position = Vector3(sx * 0.9, 0.85, 0.0)
		pmi.rotation = Vector3(0.0, 0.0, sx * -0.85)
		root.add_child(pmi)
	var tarp := BoxMesh.new()
	tarp.size = Vector3(3.2, 0.06, 3.8)
	var tmi := MeshInstance3D.new()
	tmi.mesh = tarp
	tmi.material_override = tarp_mat
	tmi.position = Vector3(0.0, 2.0, 0.5)
	tmi.rotation = Vector3(0.0, 0.0, 0.25)
	root.add_child(tmi)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.30, 0.22, 0.14)
	wood.roughness = 1.0
	var stove := BoxMesh.new()
	stove.size = Vector3(0.5, 0.4, 0.4)
	var smi := MeshInstance3D.new()
	smi.mesh = stove
	smi.material_override = wood
	smi.position = Vector3(1.8, 0.2, 1.0)
	root.add_child(smi)
	var chair := BoxMesh.new()
	chair.size = Vector3(0.6, 0.8, 0.6)
	var cmi := MeshInstance3D.new()
	cmi.mesh = chair
	cmi.material_override = canvas
	cmi.position = Vector3(-2.2, 0.4, 1.4)
	root.add_child(cmi)
	# fire ring and a warm light
	var stones := StandardMaterial3D.new()
	stones.albedo_color = Color(0.30, 0.28, 0.25)
	var ring := CylinderMesh.new()
	ring.top_radius = 0.9
	ring.bottom_radius = 0.9
	ring.height = 0.12
	ring.radial_segments = 12
	var rmi := MeshInstance3D.new()
	rmi.mesh = ring
	rmi.material_override = stones
	rmi.position = Vector3(2.0, 0.06, 2.8)
	root.add_child(rmi)
	_campfire = OmniLight3D.new()
	_campfire.light_color = Color(1.0, 0.55, 0.25)
	_campfire.light_energy = 1.2
	_campfire.omni_range = 7.0
	_campfire.position = Vector3(2.0, 0.8, 2.8)
	root.add_child(_campfire)
	# Biscuit the dog, sitting by the tent
	_build_dog(root, Vector3(-3.0, 0.0, -0.5))
	root.rotation.y = 0.6

func _build_dog(parent: Node3D, p: Vector3) -> void:
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.55, 0.42, 0.28)
	fur.roughness = 0.9
	var body := BoxMesh.new()
	body.size = Vector3(0.55, 0.55, 0.9)
	var bmi := MeshInstance3D.new()
	bmi.mesh = body
	bmi.material_override = fur
	bmi.position = p + Vector3(0.0, 0.45, 0.0)
	parent.add_child(bmi)
	var head := BoxMesh.new()
	head.size = Vector3(0.36, 0.36, 0.4)
	var hmi := MeshInstance3D.new()
	hmi.mesh = head
	hmi.material_override = fur
	hmi.position = p + Vector3(0.0, 0.95, -0.5)
	parent.add_child(hmi)
	for sx in [-1.0, 1.0]:
		var ear := BoxMesh.new()
		ear.size = Vector3(0.12, 0.22, 0.08)
		var emi := MeshInstance3D.new()
		emi.mesh = ear
		emi.material_override = fur
		emi.position = p + Vector3(sx * 0.14, 1.25, -0.48)
		parent.add_child(emi)
		var leg := BoxMesh.new()
		leg.size = Vector3(0.12, 0.45, 0.12)
		var lmi := MeshInstance3D.new()
		lmi.mesh = leg
		lmi.material_override = fur
		lmi.position = p + Vector3(sx * 0.2, 0.22, 0.25)
		parent.add_child(lmi)
	_dog_heat = ThermalHeat.animal(parent, p + Vector3(0.0, 0.0, 0.05), 0.95, 0.58)
	_dog_heat.visible = false

# ------------------------------------------------------------------ the old festival bus
func _build_bus(pos: Vector3) -> void:
	_bus_root = Node3D.new()
	_bus_root.position = pos
	add_child(_bus_root)
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.20, 0.36, 0.24)
	green.roughness = 0.6
	green.metallic = 0.15
	var body := BoxMesh.new()
	body.size = Vector3(2.5, 2.6, 9.0)
	var bmi := MeshInstance3D.new()
	bmi.mesh = body
	bmi.material_override = green
	bmi.position.y = 1.8
	_bus_root.add_child(bmi)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.08, 0.11, 0.13)
	glass.metallic = 0.5
	glass.roughness = 0.2
	var win := BoxMesh.new()
	win.size = Vector3(2.52, 0.7, 7.4)
	var wmi := MeshInstance3D.new()
	wmi.mesh = win
	wmi.material_override = glass
	wmi.position = Vector3(0.0, 2.35, 0.0)
	_bus_root.add_child(wmi)
	var roof := BoxMesh.new()
	roof.size = Vector3(2.4, 0.2, 8.6)
	var rmi := MeshInstance3D.new()
	rmi.mesh = roof
	rmi.material_override = green
	rmi.position.y = 3.2
	_bus_root.add_child(rmi)
	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = 0.55
	wheel_mesh.bottom_radius = 0.55
	wheel_mesh.height = 0.35
	wheel_mesh.radial_segments = 12
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.05, 0.05, 0.05)
	for p in [Vector3(-1.3, 0.55, -3.0), Vector3(1.3, 0.55, -3.0), Vector3(-1.3, 0.55, 3.0), Vector3(1.3, 0.55, 3.0)]:
		var w := MeshInstance3D.new()
		w.mesh = wheel_mesh
		w.material_override = rubber
		w.position = p
		w.rotation = Vector3(0.0, 0.0, PI * 0.5)
		_bus_root.add_child(w)
	var bus_label := Label3D.new()
	bus_label.text = "HALLOWAY\nFESTIVAL"
	bus_label.font_size = 64
	bus_label.pixel_size = 0.012
	bus_label.modulate = Color(0.88, 0.80, 0.55)
	bus_label.position = Vector3(1.27, 1.8, 0.0)
	bus_label.rotation = Vector3(0.0, PI * 0.5, 0.0)
	_bus_root.add_child(bus_label)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.82, 0.55)
	lamp.light_energy = 0.8
	lamp.omni_range = 5.0
	lamp.position = Vector3(0.0, 2.2, 0.0)
	_bus_root.add_child(lamp)
	_bus_root.rotation.y = 0.4

# ------------------------------------------------------------------ the abandoned cabin, the 1980s cruiser and Wren
func cabin_world_pos() -> Vector3:
	return Vector3(CABIN_SPOT.x, terrain.height(CABIN_SPOT.x, CABIN_SPOT.y), CABIN_SPOT.y)

func search_world_pos() -> Vector3:
	return Vector3(SEARCH_SPOT.x, terrain.height(SEARCH_SPOT.x, SEARCH_SPOT.y), SEARCH_SPOT.y)

func set_cabin_lights(on: bool) -> void:
	for l in _cabin_lights:
		l.light_energy = 2.0 if on else 0.0
	if _porch_light != null:
		_porch_light.light_energy = 3.0 if on else 0.0
	for w in _cabin_windows:
		var m := w.material_override as StandardMaterial3D
		if m != null:
			m.emission_energy_multiplier = 4.0 if on else 0.0
	_cabin_on = on

func show_hiker() -> void:
	if _hiker == null:
		return
	_hiker.visible = true
	_hiker.position = search_world_pos()
	_hiker.rotation.y = 2.2
	_hiker.set_physics_process(true)
	if _hiker is CharacterActor:
		(_hiker as CharacterActor).set_animation("stand")

func wave_hiker() -> void:
	if _hiker is CharacterActor:
		(_hiker as CharacterActor).set_animation("wave")

func face_hiker_towards(world_pos: Vector3) -> void:
	if _hiker is CharacterActor:
		(_hiker as CharacterActor).face_towards(world_pos)

func hiker_world_pos() -> Vector3:
	return _hiker.position if _hiker != null else search_world_pos()

func set_thermal_marker(on: bool) -> void:
	if _hiker_heat != null:
		_hiker_heat.visible = on and _hiker != null and _hiker.visible
	if _dog_heat != null:
		_dog_heat.visible = on

func _build_cabin(pos: Vector3) -> void:
	_cabin_root = Node3D.new()
	_cabin_root.position = pos
	add_child(_cabin_root)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.30, 0.24, 0.17)
	wood.roughness = 0.95
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.06, 0.05, 0.04)
	dark.roughness = 1.0
	var win_mat := StandardMaterial3D.new()
	win_mat.albedo_color = Color(0.32, 0.28, 0.18)
	win_mat.emission_enabled = true
	win_mat.emission = Color(1.0, 0.72, 0.35)
	win_mat.emission_energy_multiplier = 0.0
	win_mat.roughness = 0.3
	var floor := BoxMesh.new()
	floor.size = Vector3(8.0, 0.22, 6.0)
	var fmi := MeshInstance3D.new()
	fmi.mesh = floor
	fmi.material_override = wood
	fmi.position.y = 0.11
	_cabin_root.add_child(fmi)
	# four walls with a door and two windows
	var walls := [
		[Vector3(8.0, 2.6, 0.2), Vector3(0.0, 1.3, -3.0)],
		[Vector3(8.0, 2.6, 0.2), Vector3(0.0, 1.3, 3.0)],
		[Vector3(0.2, 2.6, 6.0), Vector3(-4.0, 1.3, 0.0)],
		[Vector3(0.2, 2.6, 6.0), Vector3(4.0, 1.3, 0.0)],
	]
	for w in walls:
		var b := BoxMesh.new()
		b.size = w[0]
		var mi := MeshInstance3D.new()
		mi.mesh = b
		mi.material_override = wood
		mi.position = w[1]
		_cabin_root.add_child(mi)
	var door := BoxMesh.new()
	door.size = Vector3(1.0, 2.1, 0.1)
	var dmi := MeshInstance3D.new()
	dmi.mesh = door
	dmi.material_override = dark
	dmi.position = Vector3(0.0, 1.05, 3.02)
	_cabin_root.add_child(dmi)
	for sx in [-2.2, 2.2]:
		var win := BoxMesh.new()
		win.size = Vector3(1.6, 1.1, 0.08)
		var wmi := MeshInstance3D.new()
		wmi.mesh = win
		wmi.material_override = win_mat
		wmi.position = Vector3(sx, 1.5, 3.04)
		_cabin_root.add_child(wmi)
		_cabin_windows.append(wmi)
	# pitched roof from two slabs and a broken patch
	for sx in [-1.0, 1.0]:
		var slab := BoxMesh.new()
		slab.size = Vector3(4.6, 0.18, 6.6)
		var smi := MeshInstance3D.new()
		smi.mesh = slab
		smi.material_override = wood
		smi.position = Vector3(sx * 2.1, 3.05, 0.0)
		smi.rotation.z = sx * -0.42
		_cabin_root.add_child(smi)
	var hole := BoxMesh.new()
	hole.size = Vector3(1.2, 0.1, 1.4)
	var hmi := MeshInstance3D.new()
	hmi.mesh = hole
	hmi.material_override = dark
	hmi.position = Vector3(-1.5, 3.45, 1.2)
	hmi.rotation.z = 0.42
	_cabin_root.add_child(hmi)
	# porch, old chair, case file and a kettle inside
	var porch := BoxMesh.new()
	porch.size = Vector3(4.0, 0.16, 1.6)
	var pmi := MeshInstance3D.new()
	pmi.mesh = porch
	pmi.material_override = wood
	pmi.position = Vector3(0.0, 0.08, 3.8)
	_cabin_root.add_child(pmi)
	var chair := BoxMesh.new()
	chair.size = Vector3(0.6, 0.9, 0.6)
	var cmi := MeshInstance3D.new()
	cmi.mesh = chair
	cmi.material_override = wood
	cmi.position = Vector3(-2.6, 0.45, 3.7)
	_cabin_root.add_child(cmi)
	var file := BoxMesh.new()
	file.size = Vector3(0.5, 0.08, 0.7)
	var fmi2 := MeshInstance3D.new()
	fmi2.mesh = file
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.76, 0.70, 0.54)
	fmi2.material_override = paper
	fmi2.position = Vector3(1.2, 0.75, -0.8)
	_cabin_root.add_child(fmi2)
	_porch_light = OmniLight3D.new()
	_porch_light.light_color = Color(1.0, 0.72, 0.38)
	_porch_light.light_energy = 0.0
	_porch_light.omni_range = 22.0
	_porch_light.position = Vector3(0.0, 2.5, 4.0)
	_cabin_root.add_child(_porch_light)
	for p in [Vector3(-2.0, 3.0, -1.0), Vector3(2.0, 3.0, 1.0)]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.72, 0.38)
		l.light_energy = 0.0
		l.omni_range = 10.0
		l.position = p
		_cabin_root.add_child(l)
		_cabin_lights.append(l)
	_cabin_root.rotation.y = -0.3

func _build_cruiser(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.78, 0.78, 0.74)
	white.roughness = 0.8
	white.metallic = 0.1
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.08, 0.08, 0.09)
	black.roughness = 0.9
	var body := BoxMesh.new()
	body.size = Vector3(1.95, 0.72, 4.6)
	var bmi := MeshInstance3D.new()
	bmi.mesh = body
	bmi.material_override = white
	bmi.position.y = 0.62
	root.add_child(bmi)
	var roof := BoxMesh.new()
	roof.size = Vector3(1.75, 0.6, 2.2)
	var rmi := MeshInstance3D.new()
	rmi.mesh = roof
	rmi.material_override = black
	rmi.position = Vector3(0.0, 1.28, -0.1)
	root.add_child(rmi)
	var hood := BoxMesh.new()
	hood.size = Vector3(1.8, 0.12, 1.3)
	var hmi := MeshInstance3D.new()
	hmi.mesh = hood
	hmi.material_override = black
	hmi.position = Vector3(0.0, 0.99, -1.7)
	root.add_child(hmi)
	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = 0.37
	wheel_mesh.bottom_radius = 0.37
	wheel_mesh.height = 0.24
	wheel_mesh.radial_segments = 10
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.06, 0.06, 0.06)
	for p in [Vector3(-0.98, 0.37, -1.5), Vector3(0.98, 0.37, -1.5), Vector3(-0.98, 0.37, 1.5), Vector3(0.98, 0.37, 1.5)]:
		var w := MeshInstance3D.new()
		w.mesh = wheel_mesh
		w.material_override = rubber
		w.position = p
		w.rotation = Vector3(0.0, 0.0, PI * 0.5)
		root.add_child(w)
	var bar := BoxMesh.new()
	bar.size = Vector3(1.2, 0.12, 0.32)
	var bmi2 := MeshInstance3D.new()
	bmi2.mesh = bar
	var bar_mat := StandardMaterial3D.new()
	bar_mat.albedo_color = Color(0.55, 0.10, 0.10)
	bar_mat.emission_enabled = true
	bar_mat.emission = Color(0.9, 0.1, 0.1)
	bar_mat.emission_energy_multiplier = 0.0
	bmi2.material_override = bar_mat
	bmi2.position = Vector3(0.0, 1.62, -0.1)
	root.add_child(bmi2)
	var label := Label3D.new()
	label.text = "PROVINCIAL\nPOLICE"
	label.font_size = 42
	label.pixel_size = 0.009
	label.modulate = Color(0.12, 0.15, 0.22)
	label.position = Vector3(1.0, 0.78, 0.2)
	label.rotation = Vector3(0.0, PI * 0.5, 0.0)
	root.add_child(label)
	root.rotation.y = 0.9

func _build_hiker() -> void:
	var actor := CharacterActor.new()
	actor.name = "Wren"
	_hiker = actor
	add_child(actor)
	actor.setup({
		"terrain": terrain,
		"name": "Wren",
		"skin": 1,
		"hair": "crop",
		"hair_color": 0,
		"outfit": Color(0.64, 0.42, 0.18),
		"trousers": Color(0.15, 0.19, 0.18),
		"scarf": Color(0.44, 0.22, 0.12),
		"backpack": true,
		"hiker": true,
		"height": 0.98,
		"position": Vector3(SEARCH_SPOT.x, terrain.height(SEARCH_SPOT.x, SEARCH_SPOT.y), SEARCH_SPOT.y),
	})
	_hiker.visible = false
	_hiker.set_physics_process(false)
	# a white-hot person signature: torso, head and hands, shown only through the thermal camera
	_hiker_heat = ThermalHeat.person(_hiker, Vector3.ZERO)
	_hiker_heat.visible = false
func _process(delta: float) -> void:
	_time += delta
	if _campfire != null:
		_campfire.light_energy = 1.0 + 0.35 * sin(_time * 9.0) + 0.15 * sin(_time * 23.0)
	for l in _cabin_lights:
		if l.light_energy > 0.0:
			l.light_energy = 0.8 + 0.15 * sin(_time * 5.0 + 2.0)

# ------------------------------------------------------------------ evidence subjects for photos
func subjects_in_frame(cam: Camera3D) -> Array:
	var out: Array = []
	if cam == null:
		return out
	var vp := cam.get_viewport().get_visible_rect().size
	for it in _items:
		var pos: Vector3 = it["pos"]
		var d := pos.distance_to(cam.global_position)
		if d > 1600.0 or cam.is_position_behind(pos):
			continue
		var sp := cam.unproject_position(pos)
		if sp.x < -vp.x * 0.08 or sp.x > vp.x * 1.08 or sp.y < -vp.y * 0.08 or sp.y > vp.y * 1.08:
			continue
		var radius := float(it.get("radius", 4.0))
		var size := radius / maxf(d, 1.0) * (vp.y * 0.5) / tan(deg_to_rad(cam.fov * 0.5))
		var nx := sp.x / vp.x
		var ny := sp.y / vp.y
		var margin := minf(minf(nx, 1.0 - nx), minf(ny, 1.0 - ny))
		out.append({"id": str(it["id"]), "name": str(it["name"]), "dist": d, "size": size,
			"frame": [nx, ny], "frame_margin": margin, "screen_r": size / vp.y})
	return out

func stats() -> Dictionary:
	return {"items": _items.size(), "bus_at_festival": _bus_at_festival, "positions": positions()}

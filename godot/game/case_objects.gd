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
const FESTIVAL_SPOT := Vector2(24.0, -96.0)

var terrain: Terrain
var _items: Array[Dictionary] = []
var _bus_root: Node3D
var _campfire: OmniLight3D
var _time := 0.0
var _bus_at_festival := false

static var _car_spot := Vector2.INF

## Called before the world is planted so the trees and props can keep clear of the evidence landmarks.
static func prepare(t: Terrain) -> void:
	_car_spot = _compute_shore(t)

static func near_evidence(x: float, z: float, margin := 30.0) -> bool:
	if _car_spot != Vector2.INF and Vector2(x, z).distance_to(_car_spot) < margin:
		return true
	for p in [GARAGE_SPOT, CAMP_SPOT, FESTIVAL_SPOT]:
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
	_build_car(_items[0]["pos"])
	_build_garage(_items[1]["pos"])
	_build_camp(_items[2]["pos"])
	_build_bus(bus_pos)
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

func _process(delta: float) -> void:
	_time += delta
	if _campfire != null:
		_campfire.light_energy = 1.0 + 0.35 * sin(_time * 9.0) + 0.15 * sin(_time * 23.0)

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
		out.append({"id": str(it["id"]), "name": str(it["name"]), "dist": d, "size": size})
	return out

func stats() -> Dictionary:
	return {"items": _items.size(), "bus_at_festival": _bus_at_festival, "positions": positions()}

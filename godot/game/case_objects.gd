class_name CaseObjects
extends Node3D
## The physical evidence landmarks for the Lake Car story (session B). Until Claude's models arrive these are simple
## code built placeholders: a faded blue estate by the lake, and the old Voss and Son garage on a spur off the ridge
## road. They exist so the pilot can fly to them, photograph them, and have the photo metadata carry their ids into the
## Casebook and the story state.
##
## The car's shore point is found from the lake shape at startup, so it always sits on dry land next to water. Nothing
## here has collisions; the car and the garage are harmless scenery like the rest of the valley.

const ITEMS := [
	{"id": "case_lake_car", "name": "the abandoned car", "kind": "car", "radius": 3.2},
	{"id": "case_garage", "name": "Voss and Son Motor Works", "kind": "garage", "radius": 7.0},
]

var terrain: Terrain
var _items: Array[Dictionary] = []

func setup(t: Terrain) -> void:
	terrain = t
	var car_pos := _find_shore()
	_items.append({"id": "case_lake_car", "name": "the abandoned car", "pos": Vector3(car_pos.x, t.height(car_pos.x, car_pos.y), car_pos.y), "radius": 3.2})
	var g := Vector2(55.0, -600.0)
	_items.append({"id": "case_garage", "name": "Voss and Son Motor Works", "pos": Vector3(g.x, t.height(g.x, g.y), g.y), "radius": 7.0})
	_build_car(_items[0]["pos"])
	_build_garage(_items[1]["pos"])
	print("case objects: ", positions())

static var _car_spot := Vector2.INF

## Called before the world is planted so the trees and props can keep clear of the evidence landmarks.
static func prepare(t: Terrain) -> void:
	_car_spot = _compute_shore(t)

static func near_evidence(x: float, z: float, margin := 30.0) -> bool:
	if _car_spot != Vector2.INF and Vector2(x, z).distance_to(_car_spot) < margin:
		return true
	if Vector2(x, z).distance_to(Vector2(55.0, -600.0)) < margin + 5.0:
		return true
	return false

## A dry point on the lake's north shore, next to water, as flat as possible.
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
			# prefer the northern shore (smaller z), near the middle of the lake, and level ground
			var score := -float(z) * 1.0 - absf(x + 620.0) * 0.15 - slope * 120.0
			if score > best_score:
				best_score = score
				best = Vector2(x, z)
	# march from the chosen point towards the nearest water, then step a few metres back onto the sand
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
	# open boot: a lid lifted at the back
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
	# the roller door, half open: a dark opening with a rusty door above it
	var opening := BoxMesh.new()
	opening.size = Vector3(3.6, 2.6, 0.08)
	var omi := MeshInstance3D.new()
	omi.mesh = opening
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.04, 0.04, 0.04)
	dark.roughness = 1.0
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
	# a sign over the door
	var sign := Label3D.new()
	sign.text = "VOSS & SON"
	sign.font_size = 48
	sign.pixel_size = 0.01
	sign.modulate = Color(0.72, 0.64, 0.45)
	sign.position = Vector3(-1.5, 3.2, -3.56)
	sign.rotation = Vector3(0.0, PI, 0.0)
	root.add_child(sign)
	root.rotation.y = 0.25

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
	return {"items": _items.size(), "positions": positions()}

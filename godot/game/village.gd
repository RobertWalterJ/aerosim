class_name Village
extends Node3D
## Halloway village (session B): the town that the chat keeps talking about, deliberately east of the cemetery and
## south of the festival field. The old cemetery is a separate, walled place; the village is a working street with
## cottages, a pub, a shop, a garage, a green and the small furniture of a valley town.
##
## The buildings are code-built placeholders until Claude's village set lands. Every position is fixed and audited
## against the cemetery, the farm fields, the festival field and the village lane; World clears the trees out of the
## same bounds before it plants.

const BOUNDS := Rect2(330.0, 226.0, 182.0, 92.0)
const CENTRE := Vector2(421.0, 272.0)
const CEMETERY_CORNER := Vector2(238.0, 238.0)
const FESTIVAL := Vector2(300.0, 300.0)

var terrain: Terrain
var _stats := {}
var _car_heats: Array[Node3D] = []
var _people: Array[CharacterActor] = []

static func near_village(x: float, z: float, margin := 5.0) -> bool:
	return BOUNDS.grow(margin).has_point(Vector2(x, z))

static func inside_lot(x: float, z: float, margin := 2.0) -> bool:
	return BOUNDS.grow(margin).has_point(Vector2(x, z))

static func min_cemetery_gap() -> float:
	return maxf(0.0, BOUNDS.position.x - CEMETERY_CORNER.x)

static func min_festival_gap() -> float:
	return maxf(0.0, BOUNDS.position.x - FESTIVAL.x)

func setup(t: Terrain) -> void:
	terrain = t
	_build()
	print("village: ", stats(), "  cemetery gap ", snappedf(min_cemetery_gap(), 0.1), " m")

func _build() -> void:
	var stone := _tex("limestone", Color(0.82, 0.78, 0.68), 0.92, 0.24)
	var stone_dark := _tex("rubble", Color(0.72, 0.68, 0.60), 0.95, 0.22)
	var brick := _tex("brick", Color(0.74, 0.55, 0.44), 0.9, 0.35)
	var slate := _mat(Color(0.20, 0.22, 0.23), 0.86)
	var slate_warm := _mat(Color(0.30, 0.27, 0.24), 0.88)
	var timber := _tex("barnwood", Color(0.72, 0.60, 0.46), 0.84, 0.5)
	var cream := _tex("silocrete", Color(0.92, 0.87, 0.74), 0.92, 0.34)
	var white := _tex("silocrete", Color(0.90, 0.89, 0.82), 0.86, 0.3)
	var glass := _mat(Color(0.13, 0.17, 0.17), 0.30)
	glass.metallic = 0.1
	var lamp := _mat(Color(0.95, 0.75, 0.38), 0.6)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.70, 0.32)
	lamp.emission_energy_multiplier = 1.2

	# the north row, front doors toward the lane
	_cottage(Vector2(358.0, 242.0), PI, 9.5, 8.0, 4.2, stone, slate, cream, glass, "BRAMBLE COTTAGE")
	_cottage(Vector2(392.0, 243.0), PI, 8.5, 7.5, 4.0, cream, slate_warm, timber, glass, "")
	_cottage(Vector2(426.0, 244.0), PI, 10.0, 8.0, 4.6, stone_dark, slate, cream, glass, "")
	_cottage(Vector2(461.0, 245.0), PI, 8.0, 7.0, 3.9, brick, slate_warm, white, glass, "")

	# the south row: the pub, the stores and the garage, with two cottages between
	_cottage(Vector2(347.0, 296.0), 0.0, 9.0, 8.0, 4.3, cream, slate_warm, timber, glass, "")
	_pub(Vector2(382.0, 299.0), 0.0, stone_dark, slate, timber, cream, glass, lamp)
	_shop(Vector2(414.0, 301.0), 0.0, cream, slate, timber, glass)
	_cottage(Vector2(443.0, 303.0), 0.0, 8.5, 7.5, 4.0, stone, slate, cream, glass, "")
	_garage(Vector2(477.0, 306.0), 0.0, brick, slate, white, glass)

	_green(Vector2(342.0, 274.0), slate_warm)
	_phone_box(Vector2(365.0, 268.0))
	_bus_shelter(Vector2(397.0, 253.0))
	_post_box(Vector2(410.0, 282.0))
	_bench(Vector2(350.0, 280.0), 0.2)
	_bench(Vector2(356.0, 282.0), -0.3)
	_lamp(Vector2(372.0, 252.0), lamp)
	_lamp(Vector2(432.0, 260.0), lamp)
	_lamp(Vector2(466.0, 266.0), lamp)
	_hedge(Vector2(352.0, 251.0), 0.0, 9.0)
	_hedge(Vector2(388.0, 252.0), 0.0, 8.0)
	_hedge(Vector2(422.0, 253.0), 0.0, 10.0)
	_hedge(Vector2(455.0, 254.0), 0.0, 8.0)
	_hedge(Vector2(365.0, 288.0), 0.0, 8.0)
	_hedge(Vector2(458.0, 290.0), 0.0, 10.0)
	_parked_car(Vector2(370.0, 282.0), 0.12, Color(0.22, 0.28, 0.32))
	_parked_car(Vector2(430.0, 286.0), -0.08, Color(0.52, 0.48, 0.40))
	# a gravel forecourt for the garage and the stores
	_forecourt(Vector2(470.0, 294.0), 18.0, 9.0, _tex("gravel", Color(0.72, 0.68, 0.60), 0.97, 0.7))
	_driveway(Vector2(414.0, 284.0), 5.0, 24.0, _tex("gravel", Color(0.68, 0.64, 0.56), 0.97, 0.8))
	_driveway(Vector2(470.0, 284.0), 5.0, 24.0, _tex("gravel", Color(0.68, 0.64, 0.56), 0.97, 0.8))
	_build_people()
	_stats["buildings"] = 9
	_stats["furniture"] = 9
	_stats["trees"] = 1
	_stats["people"] = _people.size()

func _cottage(pos: Vector2, yaw: float, w: float, d: float, h: float, wall: StandardMaterial3D, roof: StandardMaterial3D, trim: StandardMaterial3D, glass: StandardMaterial3D, name: String) -> void:
	var node := Node3D.new()
	node.position = Vector3(pos.x, terrain.height(pos.x, pos.y), pos.y)
	node.rotation.y = yaw
	add_child(node)
	_box(node, Vector3(w, h, d), Vector3(0.0, h * 0.5, 0.0), wall)
	_solid(node, Vector3(w, h, d), Vector3(0.0, h * 0.5, 0.0))
	_roof(node, w, d, h, roof)
	_door(node, Vector3(0.0, 1.05, -d * 0.5 - 0.07), 1.05, 2.1, trim)
	_window(node, Vector3(-w * 0.30, h * 0.58, -d * 0.5 - 0.07), 1.0, 1.1, glass)
	_window(node, Vector3(w * 0.30, h * 0.58, -d * 0.5 - 0.07), 1.0, 1.1, glass)
	_chimney(node, Vector3(w * 0.28, h + 0.9, 0.22), 0.55, 1.8, 0.55, wall)
	_footpath(node, Vector3(0.0, 0.02, -d * 0.5 - 1.6), 1.2, 3.0)
	_inc("cottages")
	if name != "":
		_label(node, name, Vector3(0.0, h + 0.12, -d * 0.5 - 0.10), 34, trim, 0.004)

func _pub(pos: Vector2, yaw: float, wall: StandardMaterial3D, roof: StandardMaterial3D, trim: StandardMaterial3D, cream: StandardMaterial3D, glass: StandardMaterial3D, lamp: StandardMaterial3D) -> void:
	var node := Node3D.new()
	node.position = Vector3(pos.x, terrain.height(pos.x, pos.y), pos.y)
	node.rotation.y = yaw
	add_child(node)
	if _try_building_model(node, "town_pub_a", yaw):
		_solid(node, Vector3(15.0, 6.2, 10.0), Vector3(0.0, 3.1, 0.0))
		_inc("pub")
		return
	_box(node, Vector3(15.0, 6.2, 10.0), Vector3(0.0, 3.1, 0.0), wall)
	_solid(node, Vector3(15.0, 6.2, 10.0), Vector3(0.0, 3.1, 0.0))
	_roof(node, 15.0, 10.0, 6.2, roof)
	_door(node, Vector3(-3.4, 1.15, -5.07), 1.4, 2.3, trim)
	_window(node, Vector3(1.0, 3.7, -5.07), 1.5, 1.4, trim)
	_window(node, Vector3(4.1, 3.7, -5.07), 1.5, 1.4, trim)
	_chimney(node, Vector3(4.8, 6.4, 1.6), 0.8, 2.1, 0.8, wall)
	for i in 3:
		var lit := _box(node, Vector3(1.6, 1.2, 0.08), Vector3(-5.0 + float(i) * 2.6, 2.1, -5.07), glass)
		lit.material_override = lamp
	_label(node, "THE HOLLOW CROWN", Vector3(0.0, 6.6, -5.10), 52, cream, 0.005)
	var sign_node := Node3D.new()
	sign_node.position = Vector3(-7.9, 4.2, -3.0)
	sign_node.rotation.y = PI * 0.5
	node.add_child(sign_node)
	_box(sign_node, Vector3(0.10, 1.0, 1.6), Vector3.ZERO, trim)
	_label(sign_node, "ALE  ·  FOOD  ·  ROOMS", Vector3(0.06, 0.0, 0.0), 22, cream, 0.003)
	_footpath(node, Vector3(0.0, 0.02, -6.4), 2.0, 3.4)
	_inc("pub")

func _shop(pos: Vector2, yaw: float, wall: StandardMaterial3D, roof: StandardMaterial3D, trim: StandardMaterial3D, glass: StandardMaterial3D) -> void:
	var node := Node3D.new()
	node.position = Vector3(pos.x, terrain.height(pos.x, pos.y), pos.y)
	node.rotation.y = yaw
	add_child(node)
	if _try_building_model(node, "town_shop_a", yaw):
		_solid(node, Vector3(11.0, 4.6, 8.0), Vector3(0.0, 2.3, 0.0))
		_inc("shop")
		return
	_box(node, Vector3(11.0, 4.6, 8.0), Vector3(0.0, 2.3, 0.0), wall)
	_solid(node, Vector3(11.0, 4.6, 8.0), Vector3(0.0, 2.3, 0.0))
	_roof(node, 11.0, 8.0, 4.6, roof)
	_door(node, Vector3(-3.5, 1.1, -4.07), 1.2, 2.2, trim)
	_window(node, Vector3(1.0, 2.3, -4.07), 3.4, 1.8, glass)
	var awning := _box(node, Vector3(6.4, 0.10, 1.8), Vector3(1.0, 3.25, -4.8), trim)
	awning.rotation.x = deg_to_rad(-12.0)
	_label(node, "HALLOWAY STORES", Vector3(0.0, 4.85, -4.10), 44, trim, 0.005)
	_footpath(node, Vector3(0.0, 0.02, -5.7), 2.6, 3.0)
	_inc("shop")

func _garage(pos: Vector2, yaw: float, wall: StandardMaterial3D, roof: StandardMaterial3D, trim: StandardMaterial3D, glass: StandardMaterial3D) -> void:
	var node := Node3D.new()
	node.position = Vector3(pos.x, terrain.height(pos.x, pos.y), pos.y)
	node.rotation.y = yaw
	add_child(node)
	if _try_building_model(node, "garage_shell_a", yaw):
		_solid(node, Vector3(14.0, 4.8, 9.0), Vector3(0.0, 2.4, 0.0))
		_inc("garage")
		return
	_box(node, Vector3(14.0, 4.8, 9.0), Vector3(0.0, 2.4, 0.0), wall)
	_solid(node, Vector3(14.0, 4.8, 9.0), Vector3(0.0, 2.4, 0.0))
	_roof(node, 14.0, 9.0, 4.8, roof)
	for i in 2:
		var bay := _box(node, Vector3(4.2, 3.1, 0.12), Vector3(-3.4 + float(i) * 6.8, 1.55, -4.57), glass)
		bay.material_override = glass
	_label(node, "HALLOWAY GARAGE", Vector3(0.0, 5.05, -4.60), 44, trim, 0.005)
	_footpath(node, Vector3(0.0, 0.02, -5.5), 3.0, 2.4)
	_inc("garage")

func _green(pos: Vector2, bench_mat: StandardMaterial3D) -> void:
	var node := Node3D.new()
	node.position = Vector3(pos.x, terrain.height(pos.x, pos.y), pos.y)
	add_child(node)
	# the green oak is the real tree asset, not a green sphere
	Assets.place(node, "trees/oak_l0", Transform3D(Basis.from_scale(Vector3(0.72, 0.72, 0.72)), Vector3.ZERO))
	var ring := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 4.0; cm.bottom_radius = 4.0; cm.height = 0.10
	ring.mesh = cm
	ring.material_override = bench_mat
	ring.position = Vector3(0.0, 0.06, 0.0)
	node.add_child(ring)
	_label(node, "THE GREEN", Vector3(0.0, 1.0, -4.2), 28, bench_mat, 0.004)
	_inc("green")

func _phone_box(pos: Vector2) -> void:
	var node := Node3D.new()
	node.position = Vector3(pos.x, terrain.height(pos.x, pos.y), pos.y)
	add_child(node)
	var red := _mat(Color(0.55, 0.08, 0.06), 0.55)
	_box(node, Vector3(1.0, 2.5, 1.0), Vector3(0.0, 1.25, 0.0), red)
	_solid(node, Vector3(1.0, 2.5, 1.0), Vector3(0.0, 1.25, 0.0))
	var glass := _box(node, Vector3(0.72, 1.3, 0.05), Vector3(0.0, 1.45, -0.52), _mat(Color(0.18, 0.24, 0.23), 0.2))
	glass.material_override = _mat(Color(0.18, 0.24, 0.23), 0.2)
	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0; cm.bottom_radius = 0.80; cm.height = 0.30
	cap.mesh = cm
	cap.material_override = red
	cap.position = Vector3(0.0, 2.65, 0.0)
	node.add_child(cap)
	_inc("phone_box")

func _bus_shelter(pos: Vector2) -> void:
	var node := Node3D.new()
	node.position = Vector3(pos.x, terrain.height(pos.x, pos.y), pos.y)
	add_child(node)
	var wood := _mat(Color(0.20, 0.16, 0.12), 0.9)
	var glass := _mat(Color(0.24, 0.30, 0.28), 0.2)
	_box(node, Vector3(4.0, 0.12, 2.2), Vector3(0.0, 2.5, 0.0), wood)
	_solid(node, Vector3(4.0, 2.5, 0.12), Vector3(0.0, 1.25, -1.1))
	_box(node, Vector3(0.12, 2.5, 2.2), Vector3(-2.0, 1.25, 0.0), wood)
	_box(node, Vector3(0.12, 2.5, 2.2), Vector3(2.0, 1.25, 0.0), wood)
	_box(node, Vector3(4.0, 1.8, 0.06), Vector3(0.0, 1.1, -1.1), glass)
	_box(node, Vector3(3.6, 0.18, 0.55), Vector3(0.0, 0.55, 0.4), wood)
	_inc("bus_shelter")

func _post_box(pos: Vector2) -> void:
	var node := Node3D.new()
	node.position = Vector3(pos.x, terrain.height(pos.x, pos.y), pos.y)
	add_child(node)
	var red := _mat(Color(0.56, 0.08, 0.06), 0.6)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.10; pm.bottom_radius = 0.12; pm.height = 1.1
	pole.mesh = pm
	pole.material_override = _mat(Color(0.20, 0.20, 0.18), 0.7)
	pole.position = Vector3(0.0, 0.55, 0.0)
	node.add_child(pole)
	_box(node, Vector3(0.65, 0.9, 0.55), Vector3(0.0, 1.35, 0.0), red)
	_solid(node, Vector3(0.55, 1.4, 0.45), Vector3(0.0, 0.70, 0.0))
	_inc("post_box")

func _bench(pos: Vector2, yaw: float) -> void:
	var node := Node3D.new()
	node.position = Vector3(pos.x, terrain.height(pos.x, pos.y), pos.y)
	node.rotation.y = yaw
	add_child(node)
	var wood := _mat(Color(0.27, 0.19, 0.12), 0.9)
	var iron := _mat(Color(0.13, 0.13, 0.12), 0.7)
	_box(node, Vector3(1.8, 0.10, 0.48), Vector3(0.0, 0.48, 0.0), wood)
	_box(node, Vector3(1.8, 0.48, 0.10), Vector3(0.0, 0.74, 0.20), wood)
	_solid(node, Vector3(1.8, 0.82, 0.50), Vector3(0.0, 0.41, 0.0))
	for sx in [-0.75, 0.75]:
		_box(node, Vector3(0.10, 0.48, 0.10), Vector3(sx, 0.24, 0.0), iron)
	_inc("bench")

func _lamp(pos: Vector2, lamp_mat: StandardMaterial3D) -> void:
	var node := Node3D.new()
	node.position = Vector3(pos.x, terrain.height(pos.x, pos.y), pos.y)
	add_child(node)
	var iron := _mat(Color(0.12, 0.12, 0.11), 0.7)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.06; pm.bottom_radius = 0.10; pm.height = 4.6
	pole.mesh = pm
	pole.material_override = iron
	pole.position = Vector3(0.0, 2.3, 0.0)
	node.add_child(pole)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.22; hm.height = 0.30
	head.mesh = hm
	head.material_override = lamp_mat
	head.position = Vector3(0.0, 4.55, 0.0)
	node.add_child(head)
	_inc("lamp")

func _parked_car(pos: Vector2, yaw: float, colour: Color) -> void:
	var node := Node3D.new()
	node.position = Vector3(pos.x, terrain.height(pos.x, pos.y), pos.y)
	node.rotation.y = yaw
	add_child(node)
	var body_mat := _mat(colour, 0.55)
	var glass := _mat(Color(0.10, 0.14, 0.16), 0.25)
	var rubber := _mat(Color(0.06, 0.06, 0.06), 0.9)
	_box(node, Vector3(1.8, 0.62, 4.0), Vector3(0.0, 0.52, 0.0), body_mat)
	_solid(node, Vector3(1.8, 0.9, 4.0), Vector3(0.0, 0.55, 0.0))
	var cabin := _box(node, Vector3(1.55, 0.55, 2.0), Vector3(0.0, 1.02, 0.10), glass)
	cabin.rotation.x = deg_to_rad(-2.0)
	for wz in [-1.35, 1.35]:
		for wx in [-0.86, 0.86]:
			var wheel := MeshInstance3D.new()
			var wm := CylinderMesh.new()
			wm.top_radius = 0.30; wm.bottom_radius = 0.30; wm.height = 0.20
			wheel.mesh = wm
			wheel.material_override = rubber
			wheel.rotation.z = PI * 0.5
			wheel.position = Vector3(wx, 0.32, wz)
			node.add_child(wheel)
	_box(node, Vector3(0.28, 0.12, 0.06), Vector3(-0.56, 0.62, -2.01), _mat(Color(0.92, 0.86, 0.62), 0.4))
	_box(node, Vector3(0.28, 0.12, 0.06), Vector3(0.56, 0.62, -2.01), _mat(Color(0.92, 0.86, 0.62), 0.4))
	var heat := ThermalHeat.vehicle(node, Vector3(1.8, 0.62, 4.0), Vector3(1.55, 0.55, 2.0), 0.75)
	heat.visible = false
	_car_heats.append(heat)
	_inc("parked_cars")
## The thermal camera sees the parked cars' engines and cabins when it is switched on.
func set_thermal_heat(on: bool) -> void:
	for m in _car_heats:
		m.visible = on
	for p in _people:
		p.set_thermal_marker(on)
func _hedge(pos: Vector2, yaw: float, length: float) -> void:
	var node := Node3D.new()
	node.position = Vector3(pos.x, terrain.height(pos.x, pos.y), pos.y)
	node.rotation.y = yaw
	add_child(node)
	_box(node, Vector3(length, 1.1, 0.7), Vector3(0.0, 0.55, 0.0), _mat(Color(0.17, 0.26, 0.12), 0.95))
	_solid(node, Vector3(length, 1.1, 0.7), Vector3(0.0, 0.55, 0.0))
	_inc("hedge")

func _driveway(pos: Vector2, w: float, d: float, mat: StandardMaterial3D) -> void:
	var node := Node3D.new()
	node.position = Vector3(pos.x, terrain.height(pos.x, pos.y) + 0.045, pos.y)
	add_child(node)
	_box(node, Vector3(w, 0.07, d), Vector3.ZERO, mat)

func _forecourt(pos: Vector2, w: float, d: float, mat: StandardMaterial3D) -> void:
	var node := Node3D.new()
	node.position = Vector3(pos.x, terrain.height(pos.x, pos.y) + 0.035, pos.y)
	add_child(node)
	_box(node, Vector3(w, 0.07, d), Vector3.ZERO, mat)

func _roof(parent: Node3D, w: float, d: float, h: float, mat: StandardMaterial3D) -> void:
	var roof := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(w + 0.9, 2.4, d + 0.9)
	roof.mesh = pm
	roof.material_override = mat
	roof.position = Vector3(0.0, h + 1.15, 0.0)
	parent.add_child(roof)

func _door(parent: Node3D, pos: Vector3, w: float, h: float, mat: StandardMaterial3D) -> void:
	_box(parent, Vector3(w, h, 0.12), pos, mat)
	_inc("doors")

func _window(parent: Node3D, pos: Vector3, w: float, h: float, mat: StandardMaterial3D) -> void:
	var glass := _box(parent, Vector3(w, h, 0.06), pos, mat)
	glass.material_override = mat

func _chimney(parent: Node3D, pos: Vector3, w: float, h: float, d: float, mat: StandardMaterial3D) -> void:
	_box(parent, Vector3(w, h, d), pos + Vector3(0.0, h * 0.5, 0.0), mat)

func _footpath(parent: Node3D, pos: Vector3, w: float, d: float) -> void:
	_box(parent, Vector3(w, 0.05, d), pos, _mat(Color(0.47, 0.44, 0.39), 0.95))


# ------------------------------------------------------------------ the people on the street
## The village cast is deliberately ordinary and deliberately varied. These are the visible Black and Asian
## characters in the valley, alongside white and mixed-heritage neighbours; the roles are jobs, not tokens.
## Wren is the central hiker in case_objects.gd and uses the same actor.
func _build_people() -> void:
	_person({"name": "Ifeoma Okafor", "skin": 0, "hair": "braids", "hair_color": 0,
		"outfit": Color(0.14, 0.36, 0.34), "trousers": Color(0.13, 0.16, 0.16), "scarf": Color(0.76, 0.46, 0.16),
		"height": 0.99, "speed": 0.85, "route": [[356.0, 278.0], [380.0, 280.0], [404.0, 279.0], [380.0, 280.0]]})
	_person({"name": "Mei Lin", "skin": 7, "hair": "short", "hair_color": 0,
		"outfit": Color(0.52, 0.17, 0.15), "trousers": Color(0.16, 0.18, 0.20), "scarf": Color(0.82, 0.66, 0.30),
		"height": 0.94, "speed": 0.95, "route": [[404.0, 286.0], [416.0, 290.0], [410.0, 281.0], [400.0, 278.0]]})
	_person({"name": "Ravi Patel", "skin": 8, "hair": "crop", "hair_color": 0,
		"outfit": Color(0.22, 0.27, 0.38), "trousers": Color(0.14, 0.16, 0.18), "scarf": Color(0.55, 0.16, 0.12),
		"height": 1.05, "speed": 0.9, "route": [[458.0, 292.0], [478.0, 290.0], [470.0, 285.0], [460.0, 294.0]]})
	_person({"name": "Grace Adeyemi", "skin": 2, "hair": "bun", "hair_color": 1,
		"outfit": Color(0.48, 0.34, 0.15), "trousers": Color(0.16, 0.17, 0.15), "scarf": Color(0.18, 0.28, 0.25),
		"height": 0.97, "speed": 0.8, "route": [[368.0, 284.0], [380.0, 284.0], [392.0, 286.0], [380.0, 284.0]]})
	_person({"name": "Hana Sato", "skin": 3, "hair": "ponytail", "hair_color": 0,
		"outfit": Color(0.22, 0.30, 0.44), "trousers": Color(0.18, 0.18, 0.20), "scarf": Color(0.68, 0.22, 0.17),
		"height": 0.93, "speed": 0.9, "route": [[394.0, 258.0], [408.0, 260.0], [420.0, 258.0], [408.0, 260.0]]})
	_person({"name": "Priya Nair", "skin": 5, "hair": "long", "hair_color": 0,
		"outfit": Color(0.20, 0.35, 0.24), "trousers": Color(0.17, 0.16, 0.15), "scarf": Color(0.58, 0.38, 0.18),
		"height": 0.95, "speed": 0.82, "route": [[338.0, 266.0], [346.0, 274.0], [338.0, 280.0], [346.0, 274.0]]})
	_person({"name": "Daniel Whitlock", "skin": 6, "hair": "short", "hair_color": 2,
		"outfit": Color(0.30, 0.34, 0.28), "trousers": Color(0.15, 0.16, 0.15), "scarf": Color(0.40, 0.26, 0.18),
		"height": 1.02, "seated": true, "position": [350.0, 280.0], "yaw": 0.2})
	_person({"name": "Arthur Bell", "skin": 4, "hair": "short", "hair_color": 4,
		"outfit": Color(0.26, 0.25, 0.23), "trousers": Color(0.12, 0.13, 0.13), "scarf": Color(0.36, 0.18, 0.12),
		"height": 1.0, "speed": 0.62, "route": [[428.0, 268.0], [446.0, 270.0], [432.0, 276.0], [446.0, 270.0]]})

func _person(data: Dictionary) -> void:
	var actor := CharacterActor.new()
	actor.name = str(data.get("name", "Villager"))
	add_child(actor)
	var opts := {
		"terrain": terrain,
		"name": str(data.get("name", "Villager")),
		"skin": int(data.get("skin", 4)),
		"hair": str(data.get("hair", "short")),
		"hair_color": int(data.get("hair_color", 0)),
		"outfit": data.get("outfit", Color(0.25, 0.34, 0.32)),
		"trousers": data.get("trousers", Color(0.16, 0.18, 0.18)),
		"scarf": data.get("scarf", Color(0.60, 0.22, 0.16)),
		"height": float(data.get("height", 1.0)),
		"speed": float(data.get("speed", 1.0)),
		"thermal": true,
	}
	if bool(data.get("seated", false)):
		var sp: Array = data.get("position", [350.0, 280.0])
		var sx := float(sp[0])
		var sz := float(sp[1])
		opts["seated"] = true
		opts["seat_height"] = 0.53
		opts["position"] = Vector3(sx, terrain.height(sx, sz), sz)
		opts["yaw"] = float(data.get("yaw", 0.0))
	else:
		var pts: Array = data.get("route", [])
		var route: Array[Vector3] = []
		for point in pts:
			var px := float(point[0])
			var pz := float(point[1])
			route.append(Vector3(px, terrain.height(px, pz), pz))
		if route.is_empty():
			route.append(Vector3(0.0, 0.0, 0.0))
		opts["route"] = route
		opts["position"] = route[0]
	actor.setup(opts)
	_people.append(actor)

func _try_building_model(node: Node3D, name: String, _yaw: float) -> bool:
	var path := "res://assets/models/story/halloway/%s.glb" % name
	if not ResourceLoader.exists(path):
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	var inst := packed.instantiate() as Node3D
	if inst == null:
		return false
	inst.rotation.y = PI
	node.add_child(inst)
	return true

func _solid(parent: Node3D, sz: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = sz
	shape.shape = box
	shape.position = pos
	body.add_child(shape)
	parent.add_child(body)
func _box(parent: Node3D, sz: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _label(parent: Node3D, text: String, pos: Vector3, size: int, mat: StandardMaterial3D, pixel: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = pixel
	l.modulate = mat.albedo_color
	l.outline_size = 0
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	parent.add_child(l)

func _tex(name: String, tint: Color, rough: float, scale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var path := "res://assets/textures/%s_diff.jpg" % name
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	m.albedo_color = tint
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	return m

func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _inc(k: String) -> void:
	_stats[k] = int(_stats.get(k, 0)) + 1

func stats() -> Dictionary:
	return _stats.duplicate()

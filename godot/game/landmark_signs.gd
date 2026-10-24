class_name LandmarkSigns
extends Node3D
## Large location and business signs (session B): the Halloway Cemetery gateway at the east turn, the farm, the lake,
## the boat launch, Voss and Son, the festival field, the ridge camp and the old cabin. These are the signs a driver
## reads before the turn, not the regulatory signs in road_signs.gd. Code placeholder boards until Claude's sign art
## arrives; the final art brief is docs/CLAUDE-LOCATION-SIGNS-ASSETS.md.

var terrain: Terrain
var roads: Roads

var _stone: StandardMaterial3D
var _timber: StandardMaterial3D
var _board: StandardMaterial3D
var _cream: StandardMaterial3D
var _rust: StandardMaterial3D
var _green: StandardMaterial3D

func setup(t: Terrain, r: Roads) -> void:
	terrain = t
	roads = r
	_stone = _mat(Color(0.45, 0.43, 0.38), 0.95)
	_timber = _mat(Color(0.22, 0.18, 0.13), 0.9)
	_board = _mat(Color(0.10, 0.18, 0.13), 0.75)
	_cream = _mat(Color(0.88, 0.84, 0.72), 0.8)
	_rust = _mat(Color(0.46, 0.20, 0.12), 0.85)
	_green = _mat(Color(0.18, 0.34, 0.23), 0.8)
	_gateway()
	_locations()
	print("landmark signs: ", stats())

func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _gateway() -> void:
	_big_sign(Vector2(292.0, 58.0), Vector2(0.0, 1.0),
		"HALLOWAY CEMETERY", "CHAPEL   ·   WAR MEMORIAL   ·   EAST GATE", true)
	# the smaller gate boards on the other three approaches
	_gate_board(Vector2(34.0, 247.0), Vector2(-1.0, 0.0), "HALLOWAY CEMETERY", "SOUTH GATE", 1.0)
	_gate_board(Vector2(28.0, -253.0), Vector2(1.0, 0.0), "HALLOWAY CEMETERY", "NORTH GATE", 1.0)
	_gate_board(Vector2(-252.0, 8.0), Vector2(-1.0, 0.0), "HALLOWAY CEMETERY", "WEST GATE", 1.0)

func _locations() -> void:
	_business(Vector2(207.0, 534.0), Vector2(-0.8, 0.6), "TOBY FARM", "EGGS   ·   FIREWOOD   ·   HAY", 3.6)
	_business(Vector2(68.0, -596.0), Vector2(-1.0, 0.0), "VOSS AND SON", "MOTOR WORKS   ·   REPAIRS", 4.2)
	_business(Vector2(-398.0, 132.0), Vector2(1.0, -0.2), "HALLOWAY LAKE", "BOAT LAUNCH   ·   OVERLOOK", 4.2)
	_business(Vector2(305.0, 294.0), Vector2(-0.8, -0.6), "FESTIVAL FIELD", "HALLOWAY ANNUAL   ·   BUS PARK", 4.2)
	_business(Vector2(30.0, -1106.0), Vector2(0.2, 1.0), "RIDGE CAMP", "PRIVATE TRACK   ·   KEEP GATES CLOSED", 3.6)
	_small_sign(Vector2(-240.0, -812.0), Vector2(1.0, 0.0), "OLD CABIN", "PRIVATE   ·   NO TRESPASSING")
	_small_sign(Vector2(-416.0, 127.0), Vector2(1.0, 0.0), "BOAT LAUNCH", "SLOW   ·   NO WAKE")
	_small_sign(Vector2(264.0, 48.0), Vector2(0.0, -1.0), "CHAPEL", "WAR MEMORIAL   ·   VISITOR PATH")

func _big_sign(center: Vector2, face: Vector2, title: String, subtitle: String, gateway: bool) -> Node3D:
	var f := face.normalized()
	var p := center
	var root := Node3D.new()
	root.position = Vector3(p.x, terrain.height(p.x, p.y), p.y)
	root.rotation.y = atan2(f.x, f.y)
	add_child(root)
	# two stone pillars and a cross beam make the cemetery gateway read as architecture, not a notice
	if gateway:
		for x in [-4.1, 4.1]:
			var pillar := BoxMesh.new()
			pillar.size = Vector3(0.72, 4.3, 0.72)
			var pi := MeshInstance3D.new()
			pi.mesh = pillar
			pi.material_override = _stone
			pi.position = Vector3(x, 2.15, 0.0)
			root.add_child(pi)
			var cap := BoxMesh.new()
			cap.size = Vector3(0.92, 0.22, 0.92)
			var ci := MeshInstance3D.new()
			ci.mesh = cap
			ci.material_override = _stone
			ci.position = Vector3(x, 4.40, 0.0)
			root.add_child(ci)
		var beam := BoxMesh.new()
		beam.size = Vector3(9.0, 0.30, 0.34)
		var bi := MeshInstance3D.new()
		bi.mesh = beam
		bi.material_override = _stone
		bi.position = Vector3(0.0, 4.18, 0.0)
		root.add_child(bi)
		_board_mesh(root, 8.2, 2.0, 3.10)
		_label(root, title, 320, 0.00170, 3.48, 0.95)
		_label(root, subtitle, 230, 0.00072, 2.72, 0.88)
		_label(root, title, 320, 0.00170, 3.48, 0.95, true)
		_label(root, subtitle, 230, 0.00072, 2.72, 0.88, true)
	else:
		_boards_on_posts(root, 5.8, 1.35, 2.6)
		_label(root, title, 240, 0.00150, 2.92, 0.95)
		_label(root, subtitle, 190, 0.00063, 2.28, 0.86)
		_label(root, title, 240, 0.00150, 2.92, 0.95, true)
		_label(root, subtitle, 190, 0.00063, 2.28, 0.86, true)
	return root

func _gate_board(center: Vector2, face: Vector2, title: String, subtitle: String, width: float) -> void:
	var root := _boards_on_posts_root(center, face)
	_label(root, title, 220, 0.00115, 2.47, 0.9)
	_label(root, subtitle, 160, 0.00060, 2.08, 0.86)
	_label(root, title, 220, 0.00115, 2.47, 0.9, true)
	_label(root, subtitle, 160, 0.00060, 2.08, 0.86, true)
	_board_mesh(root, 3.0 * width, 0.95, 2.25)

func _business(center: Vector2, face: Vector2, title: String, subtitle: String, width: float) -> void:
	var root := _boards_on_posts_root(center, face)
	_board_mesh(root, width, 1.05, 2.35)
	_label(root, title, 240, 0.00113, 2.60, 0.92)
	_label(root, subtitle, 180, 0.00055, 2.22, 0.84)
	_label(root, title, 240, 0.00113, 2.60, 0.92, true)
	_label(root, subtitle, 180, 0.00055, 2.22, 0.84, true)

func _small_sign(center: Vector2, face: Vector2, title: String, subtitle: String) -> void:
	var root := _boards_on_posts_root(center, face)
	_board_mesh(root, 2.6, 0.85, 2.1)
	_label(root, title, 180, 0.00100, 2.30, 0.92)
	_label(root, subtitle, 140, 0.00056, 1.95, 0.84)
	_label(root, title, 180, 0.00100, 2.30, 0.92, true)
	_label(root, subtitle, 140, 0.00056, 1.95, 0.84, true)

func _boards_on_posts_root(center: Vector2, face: Vector2) -> Node3D:
	var f := face.normalized()
	var root := Node3D.new()
	root.position = Vector3(center.x, terrain.height(center.x, center.y), center.y)
	root.rotation.y = atan2(f.x, f.y)
	add_child(root)
	for x in [-1.25, 1.25]:
		var post := BoxMesh.new()
		post.size = Vector3(0.16, 2.65, 0.16)
		var pi := MeshInstance3D.new()
		pi.mesh = post
		pi.material_override = _timber
		pi.position = Vector3(x, 1.32, 0.0)
		root.add_child(pi)
	return root

func _boards_on_posts(root: Node3D, width: float, height: float, y: float) -> void:
	for x in [-width * 0.34, width * 0.34]:
		var post := BoxMesh.new()
		post.size = Vector3(0.17, y + 0.4, 0.17)
		var pi := MeshInstance3D.new()
		pi.mesh = post
		pi.material_override = _timber
		pi.position = Vector3(x, (y + 0.4) * 0.5, 0.0)
		root.add_child(pi)
	var back := BoxMesh.new()
	back.size = Vector3(width + 0.18, height + 0.18, 0.08)
	var bi := MeshInstance3D.new()
	bi.mesh = back
	bi.material_override = _rust
	bi.position = Vector3(0.0, y, -0.03)
	root.add_child(bi)
	_board_mesh(root, width, height, y)

func _board_mesh(root: Node3D, width: float, height: float, y: float) -> void:
	var bm := BoxMesh.new()
	bm.size = Vector3(width, height, 0.06)
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = _board
	mi.position = Vector3(0.0, y, 0.015)
	root.add_child(mi)

func _label(root: Node3D, text: String, size: int, pixel: float, y: float, brightness: float, back := false) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = pixel
	l.modulate = Color(0.92 * brightness, 0.89 * brightness, 0.78 * brightness)
	l.position = Vector3(0.0, y, -0.14 if back else 0.14)
	if back:
		l.rotation.y = PI
	l.no_depth_test = false
	root.add_child(l)

func stats() -> Dictionary:
	return {"signs": get_child_count()}

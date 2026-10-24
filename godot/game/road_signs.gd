class_name RoadSigns
extends Node3D
## Road signs for the valley (session B): stop signs on the minor approaches at junctions, speed limit plates at the
## route entries, a couple of junction warnings and a fingerpost at the east gate. Code placeholders until Claude's sign
## art lands. Each sign is placed on the right-hand side of the traffic that approaches it, and faces that traffic.

var terrain: Terrain
var roads: Roads

const SIGN_Y := 2.25
const POST_H := 2.95

var _red: StandardMaterial3D
var _white: StandardMaterial3D
var _black: StandardMaterial3D
var _yellow: StandardMaterial3D
var _green: StandardMaterial3D
var _post: StandardMaterial3D

func setup(t: Terrain, r: Roads) -> void:
	terrain = t
	roads = r
	_red = _mat(Color(0.62, 0.09, 0.07), 0.72)
	_white = _mat(Color(0.86, 0.85, 0.78), 0.75)
	_black = _mat(Color(0.05, 0.05, 0.045), 0.8)
	_yellow = _mat(Color(0.78, 0.62, 0.12), 0.75)
	_green = _mat(Color(0.16, 0.32, 0.22), 0.8)
	_post = _mat(Color(0.35, 0.37, 0.34), 0.6)
	_build_stop_signs()
	_build_speed_signs()
	_build_warning_signs()
	_build_fingerpost()
	print("road signs: ", stats())

func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _sign(center: Vector2, face: Vector2, offset: float, kind: String, text: String) -> Node3D:
	var f := face.normalized()
	var side := Vector2(f.y, -f.x)
	var p := center + side * offset
	var root := Node3D.new()
	root.position = Vector3(p.x, terrain.height(p.x, p.y), p.y)
	root.rotation.y = atan2(f.x, f.y)
	add_child(root)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.055
	pole.bottom_radius = 0.075
	pole.height = POST_H
	pole.radial_segments = 8
	var pi := MeshInstance3D.new()
	pi.mesh = pole
	pi.material_override = _post
	pi.position.y = POST_H * 0.5
	root.add_child(pi)
	match kind:
		"stop":
			_make_stop(root)
		"speed":
			_make_speed(root, text)
		"warn":
			_make_warn(root, text)
		"finger":
			_make_finger(root, text)
	return root

func _make_stop(root: Node3D) -> void:
	# a white octagon behind a slightly smaller red one gives the white rim
	var white := CylinderMesh.new()
	white.top_radius = 0.55
	white.bottom_radius = 0.55
	white.height = 0.045
	white.radial_segments = 8
	var wi := MeshInstance3D.new()
	wi.mesh = white
	wi.material_override = _white
	wi.position.y = SIGN_Y
	wi.rotation.x = PI * 0.5
	wi.rotation.z = PI / 8.0
	root.add_child(wi)
	var red := CylinderMesh.new()
	red.top_radius = 0.47
	red.bottom_radius = 0.47
	red.height = 0.045
	red.radial_segments = 8
	var ri := MeshInstance3D.new()
	ri.mesh = red
	ri.material_override = _red
	ri.position = Vector3(0.0, SIGN_Y, 0.040)
	ri.rotation.x = PI * 0.5
	ri.rotation.z = PI / 8.0
	root.add_child(ri)
	var label := Label3D.new()
	label.text = "STOP"
	label.font_size = 96
	label.pixel_size = 0.0028
	label.modulate = Color(0.93, 0.91, 0.85)
	label.position = Vector3(0.0, SIGN_Y, 0.075)
	root.add_child(label)

func _make_speed(root: Node3D, limit: String) -> void:
	var black_plate := BoxMesh.new()
	black_plate.size = Vector3(0.99, 1.30, 0.03)
	var bp := MeshInstance3D.new()
	bp.mesh = black_plate
	bp.material_override = _black
	bp.position = Vector3(0.0, SIGN_Y, 0.0)
	root.add_child(bp)
	var plate := BoxMesh.new()
	plate.size = Vector3(0.90, 1.21, 0.04)
	var pi := MeshInstance3D.new()
	pi.mesh = plate
	pi.material_override = _white
	pi.position = Vector3(0.0, SIGN_Y, 0.028)
	root.add_child(pi)
	var label := Label3D.new()
	label.text = "SPEED\nLIMIT\n%s" % limit
	label.font_size = 76
	label.pixel_size = 0.0040
	label.modulate = Color(0.05, 0.05, 0.045)
	label.position = Vector3(0.0, SIGN_Y, 0.055)
	root.add_child(label)

func _make_warn(root: Node3D, text: String) -> void:
	var plate := BoxMesh.new()
	plate.size = Vector3(0.95, 0.95, 0.035)
	var pi := MeshInstance3D.new()
	pi.mesh = plate
	pi.material_override = _yellow
	pi.position = Vector3(0.0, SIGN_Y, 0.0)
	pi.rotation.z = PI * 0.25
	root.add_child(pi)
	var label := Label3D.new()
	label.text = text
	label.font_size = 150
	label.pixel_size = 0.0032
	label.modulate = Color(0.05, 0.05, 0.045)
	label.position = Vector3(0.0, SIGN_Y, 0.05)
	root.add_child(label)

func _make_finger(root: Node3D, text: String) -> void:
	var plate := BoxMesh.new()
	plate.size = Vector3(3.0, 0.60, 0.05)
	var pi := MeshInstance3D.new()
	pi.mesh = plate
	pi.material_override = _green
	pi.position = Vector3(0.0, SIGN_Y, 0.0)
	root.add_child(pi)
	var label := Label3D.new()
	label.text = text
	label.font_size = 56
	label.pixel_size = 0.0042
	label.modulate = Color(0.92, 0.90, 0.82)
	label.position = Vector3(0.0, SIGN_Y, 0.05)
	root.add_child(label)

func _build_stop_signs() -> void:
	# each one is on the minor approach to a junction, facing the oncoming driver
	var stops := [
		[Vector2(278.0, 255.0), Vector2(-1.0, 0.0), 4.8],     # south lane approaching the valley highway
		[Vector2(294.0, 270.0), Vector2(0.707, 0.707), 4.8],   # festival lane approaching the valley highway
		[Vector2(270.0, 34.0), Vector2(0.0, -1.0), 5.0],      # east lane approaching the east gate junction
		[Vector2(22.0, -255.0), Vector2(1.0, 0.0), 5.0],      # east lane approaching the north gate junction
		[Vector2(207.0, 505.0), Vector2(-1.0, 0.0), 4.8],     # lakeside lane approaching the farm junction
		[Vector2(-414.0, 115.0), Vector2(-1.0, 0.0), 4.6],    # launch lane approaching the lakeside lane
		[Vector2(38.0, -760.0), Vector2(-1.0, 0.0), 4.6],     # cabin track approaching the ridge road
		[Vector2(-300.0, 292.0), Vector2(0.0, -1.0), 4.6],    # west lane approaching the lakeside lane
	]
	for s in stops:
		var c: Vector2 = s[0]
		var fa: Vector2 = s[1]
		var off := float(s[2])
		_sign(c, fa, off, "stop", "")
		_stop_line(c, fa, 3.2)

func _stop_line(center: Vector2, face: Vector2, width: float) -> void:
	var root := Node3D.new()
	root.position = Vector3(center.x, terrain.height(center.x, center.y) + 0.17, center.y)
	root.rotation.y = atan2(face.x, face.y)
	add_child(root)
	var bm := BoxMesh.new()
	bm.size = Vector3(width, 0.018, 0.34)
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = _white
	root.add_child(mi)

func _build_speed_signs() -> void:
	# one speed plate at each route entry, on the side the traffic reads it from
	var limits := [
		["valley", Vector2(280.0, 110.0), Vector2(0.0, -1.0)],
		["ridge", Vector2(30.0, -320.0), Vector2(0.0, 1.0)],
		["east_link", Vector2(276.0, -60.0), Vector2(0.0, 1.0)],
		["south_lane", Vector2(200.0, 255.0), Vector2(1.0, 0.0)],
		["lake", Vector2(90.0, 470.0), Vector2(-1.0, 0.0)],
		["west_link", Vector2(-292.0, 200.0), Vector2(0.0, 1.0)],
		["cabin", Vector2(-60.0, -790.0), Vector2(1.0, 0.0)],
		["festival", Vector2(293.0, 280.0), Vector2(-0.707, -0.707)],
		["launch", Vector2(-418.0, 118.0), Vector2(1.0, 0.0)],
	]
	for spec in limits:
		var id := str(spec[0])
		var p: Vector2 = spec[1]
		var face: Vector2 = spec[2]
		_sign(p, face, 6.4 if id in ["valley", "ridge"] else 4.8, "speed", str(int(roads.speed_limit(id))))

func _build_warning_signs() -> void:
	_sign(Vector2(284.0, 240.0), Vector2(0.0, -1.0), 6.5, "warn", "!")
	_sign(Vector2(262.0, 50.0), Vector2(0.0, -1.0), 5.2, "warn", "!")
	_sign(Vector2(-302.0, 278.0), Vector2(0.0, -1.0), 4.8, "warn", "!")

func _build_fingerpost() -> void:
	_sign(Vector2(258.0, 44.0), Vector2(0.0, -1.0), 5.5, "finger", "HALLOWAY LAKE  >")

func stats() -> Dictionary:
	return {"signs": get_child_count()}

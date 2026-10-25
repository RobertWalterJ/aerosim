class_name BoatLaunch
extends Node3D
## Halloway Lake boat launch (session B): a gravel parking apron, a concrete ramp down into the water, a short timber
## dock, a small aluminium boat and an empty trailer. Code placeholders until Claude's launch assets arrive. It sits at
## the end of the new launch lane off the lakeside road, so the place is connected and readable from the air.
##
## No collisions: the ramp and dock are scenery like the rest of the world. The parking apron, ramp and trailer keep
## clear of trees through CaseObjects.BOAT_LAUNCH_SPOT.

var terrain: Terrain
var _site_assets := 0

const TOP_SPOT := Vector2(-436.0, 112.0)
const WATER_SPOT := Vector2(-466.0, 112.0)
const RAMP_WIDTH := 6.4

func setup(t: Terrain) -> void:
	terrain = t
	_build_parking()
	_build_dive_van()
	_build_wreck()
	_build_ramp()
	_build_dock()
	_build_boat()
	_build_trailer()
	_build_sign()
	_build_bollards()
	print("boat launch: ramp ", TOP_SPOT, " to water ", WATER_SPOT, "  asset models=", _site_assets)

func _try_site_model(root: Node3D, name: String, yaw: float) -> bool:
	var path := "res://assets/models/sites/%s.glb" % name
	if not ResourceLoader.exists(path):
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	var inst := packed.instantiate() as Node3D
	if inst == null:
		return false
	inst.rotation.y = yaw
	root.add_child(inst)
	_site_assets += 1
	return true

func _build_parking() -> void:
	var c := CaseObjects.BOAT_LAUNCH_SPOT
	var root := Node3D.new()
	root.position = Vector3(c.x, terrain.height(c.x, c.y) + 0.05, c.y)
	add_child(root)
	if _try_site_model(root, "boat_launch_gravel_patch", 0.0):
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.52, 0.45)
	mat.albedo_texture = load("res://assets/textures/gravel_diff.jpg")
	mat.normal_texture = load("res://assets/textures/gravel_nor.jpg")
	mat.roughness = 0.96
	mat.uv1_scale = Vector3(5.0, 5.0, 1.0)
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(20.0, 13.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = Vector3(0.0, 0.03, 0.0)
	root.add_child(mi)
	# two worn wheel strips where the trailers turn around
	var track := StandardMaterial3D.new()
	track.albedo_color = Color(0.27, 0.25, 0.21)
	track.roughness = 0.98
	for z in [-2.4, 2.4]:
		var bm := BoxMesh.new()
		bm.size = Vector3(17.0, 0.02, 0.55)
		var bi := MeshInstance3D.new()
		bi.mesh = bm
		bi.material_override = track
		bi.position = Vector3(0.0, 0.05, z)
		root.add_child(bi)

func _try_vehicle_model(root: Node3D, name: String, yaw: float) -> bool:
	var path := "res://assets/models/vehicles/%s.glb" % name
	if not ResourceLoader.exists(path):
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	var inst := packed.instantiate() as Node3D
	if inst == null:
		return false
	inst.rotation.y = yaw
	root.add_child(inst)
	_site_assets += 1
	return true

## The dive team and the lake wreck (lane/wreckvan): the high-detail vehicles now exist in the shared library.
func _build_dive_van() -> void:
	var root := Node3D.new()
	root.position = Vector3(-424.0, terrain.height(-424.0, 120.0) + 0.08, 120.0)
	root.rotation.y = -1.35
	add_child(root)
	_try_vehicle_model(root, "police_dive_van_a", -1.35)

func _build_wreck() -> void:
	var root := Node3D.new()
	root.position = Vector3(-470.0, Lake.LEVEL - 0.65, 108.0)
	root.rotation.y = 0.7
	add_child(root)
	_try_vehicle_model(root, "anne_car_wreck_a", 0.7)

func _build_ramp() -> void:
	var rroot := Node3D.new()
	rroot.position = Vector3(TOP_SPOT.x, terrain.height(TOP_SPOT.x, TOP_SPOT.y) + 0.06, TOP_SPOT.y)
	add_child(rroot)
	if _try_site_model(rroot, "boat_ramp", 0.0):
		return
	var steps := 9
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var uv := PackedVector2Array()
	for i in steps + 1:
		var f := float(i) / float(steps)
		var p := TOP_SPOT.lerp(WATER_SPOT, f)
		var y := lerpf(terrain.height(TOP_SPOT.x, TOP_SPOT.y) + 0.06, Lake.LEVEL + 0.04, f)
		verts.append(Vector3(p.x, y, p.y - RAMP_WIDTH * 0.5))
		verts.append(Vector3(p.x, y, p.y + RAMP_WIDTH * 0.5))
		norms.append(Vector3.UP); norms.append(Vector3.UP)
		uv.append(Vector2(0.0, f * 6.0)); uv.append(Vector2(1.0, f * 6.0))
	for i in steps:
		var a := i * 2
		var b := (i + 1) * 2
		idx.append_array([a, a + 1, b, a + 1, b + 1, b])
	var mesh := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.64, 0.62, 0.56)
	mat.albedo_texture = load("res://assets/textures/path_diff.jpg")
	mat.normal_texture = load("res://assets/textures/path_nor.jpg")
	mat.roughness = 0.92
	mat.uv1_scale = Vector3(2.0, 1.0, 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	# side curbs and a darker groove every metre, so the ramp reads as concrete, not a flat sheet
	var curb := StandardMaterial3D.new()
	curb.albedo_color = Color(0.36, 0.35, 0.33)
	curb.roughness = 0.95
	for side in [-1.0, 1.0]:
		for i in steps:
			var f0 := float(i) / float(steps)
			var f1 := float(i + 1) / float(steps)
			var p0 := TOP_SPOT.lerp(WATER_SPOT, f0)
			var p1 := TOP_SPOT.lerp(WATER_SPOT, f1)
			var y0 := lerpf(terrain.height(TOP_SPOT.x, TOP_SPOT.y) + 0.06, Lake.LEVEL + 0.04, f0)
			var y1 := lerpf(terrain.height(TOP_SPOT.x, TOP_SPOT.y) + 0.06, Lake.LEVEL + 0.04, f1)
			var seg := Vector2(p0.x - p1.x, p0.y - p1.y)
			var ang := atan2(seg.y, seg.x)
			var bm := BoxMesh.new()
			bm.size = Vector3(seg.length() + 0.05, 0.24, 0.34)
			var bi := MeshInstance3D.new()
			bi.mesh = bm
			bi.material_override = curb
			bi.position = Vector3((p0.x + p1.x) * 0.5, (y0 + y1) * 0.5 + 0.08, (p0.y + p1.y) * 0.5 + side * (RAMP_WIDTH * 0.5 - 0.1))
			bi.rotation.z = ang
			add_child(bi)

func _build_dock() -> void:
	var root := Node3D.new()
	root.position = Vector3(-458.0, 77.25, 116.0)
	add_child(root)
	if _try_site_model(root, "boat_dock", 0.0):
		return
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.30, 0.23)
	wood.roughness = 0.92
	var post := StandardMaterial3D.new()
	post.albedo_color = Color(0.22, 0.19, 0.15)
	post.roughness = 0.96
	for i in 8:
		var plank := BoxMesh.new()
		plank.size = Vector3(1.8, 0.10, 2.4)
		var pi := MeshInstance3D.new()
		pi.mesh = plank
		pi.material_override = wood
		pi.position = Vector3(-float(i) * 1.72, 0.0, 0.0)
		root.add_child(pi)
	for i in 4:
		for z in [-1.1, 1.1]:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.10
			cyl.bottom_radius = 0.12
			cyl.height = 3.4
			var ci := MeshInstance3D.new()
			ci.mesh = cyl
			ci.material_override = post
			ci.position = Vector3(-float(i) * 3.3 - 0.3, -1.35, z)
			root.add_child(ci)
	# a simple cleat at the outer end
	var cleat := BoxMesh.new()
	cleat.size = Vector3(0.5, 0.12, 0.16)
	var cmi := MeshInstance3D.new()
	cmi.mesh = cleat
	cmi.material_override = post
	cmi.position = Vector3(-12.4, 0.12, 0.0)
	root.add_child(cmi)
	# white floats under the deck, so the dock reads from the air and from the water
	var float_mat := StandardMaterial3D.new()
	float_mat.albedo_color = Color(0.80, 0.82, 0.78)
	float_mat.roughness = 0.8
	for i in 4:
		var fb := BoxMesh.new()
		fb.size = Vector3(1.5, 0.38, 2.7)
		var fi := MeshInstance3D.new()
		fi.mesh = fb
		fi.material_override = float_mat
		fi.position = Vector3(-float(i) * 3.3 - 0.8, -0.42, 0.0)
		root.add_child(fi)

func _build_boat() -> void:
	var root := Node3D.new()
	root.position = Vector3(-474.0, Lake.LEVEL + 0.45, 111.0)
	root.rotation.y = 0.18
	add_child(root)
	if _try_site_model(root, "boat_aluminium_hull", 0.0):
		return
	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color(0.72, 0.75, 0.73)
	hull_mat.metallic = 0.45
	hull_mat.roughness = 0.38
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color(0.16, 0.21, 0.24)
	trim.roughness = 0.7
	var hull := BoxMesh.new()
	hull.size = Vector3(3.4, 0.55, 1.35)
	var hi := MeshInstance3D.new()
	hi.mesh = hull
	hi.material_override = hull_mat
	hi.position = Vector3(0.0, 0.05, 0.0)
	root.add_child(hi)
	var bow := BoxMesh.new()
	bow.size = Vector3(1.0, 0.42, 1.1)
	var bi := MeshInstance3D.new()
	bi.mesh = bow
	bi.material_override = hull_mat
	bi.position = Vector3(1.9, 0.02, 0.0)
	bi.rotation.y = 0.35
	root.add_child(bi)
	for z in [-0.42, 0.42]:
		var seat := BoxMesh.new()
		seat.size = Vector3(0.42, 0.07, 1.1)
		var si := MeshInstance3D.new()
		si.mesh = seat
		si.material_override = trim
		si.position = Vector3(-0.55, 0.28, z * 0.0)
		root.add_child(si)
	var motor := BoxMesh.new()
	motor.size = Vector3(0.35, 0.55, 0.28)
	var mi := MeshInstance3D.new()
	mi.mesh = motor
	mi.material_override = trim
	mi.position = Vector3(-1.75, 0.18, 0.0)
	root.add_child(mi)

func _build_trailer() -> void:
	var p := Vector2(-425.0, 112.0)
	var root := Node3D.new()
	root.position = Vector3(p.x, terrain.height(p.x, p.y) + 0.22, p.y)
	root.rotation.y = -0.18
	add_child(root)
	if _try_site_model(root, "boat_trailer", 0.0):
		return
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.19, 0.19, 0.18)
	steel.metallic = 0.5
	steel.roughness = 0.7
	for z in [-0.55, 0.55]:
		var bar := BoxMesh.new()
		bar.size = Vector3(3.9, 0.10, 0.10)
		var bi := MeshInstance3D.new()
		bi.mesh = bar
		bi.material_override = steel
		bi.position = Vector3(0.0, 0.0, z)
		root.add_child(bi)
	for x in [-1.5, 0.0, 1.3]:
		var cross := BoxMesh.new()
		cross.size = Vector3(0.10, 0.10, 1.2)
		var ci := MeshInstance3D.new()
		ci.mesh = cross
		ci.material_override = steel
		ci.position = Vector3(x, 0.0, 0.0)
		root.add_child(ci)
	for z in [-0.58, 0.58]:
		var wheel := CylinderMesh.new()
		wheel.top_radius = 0.34
		wheel.bottom_radius = 0.34
		wheel.height = 0.20
		var wi := MeshInstance3D.new()
		wi.mesh = wheel
		wi.material_override = steel
		wi.position = Vector3(-0.55, -0.18, z)
		wi.rotation.x = PI * 0.5
		root.add_child(wi)
	var winch_post := BoxMesh.new()
	winch_post.size = Vector3(0.12, 1.15, 0.12)
	var wpi := MeshInstance3D.new()
	wpi.mesh = winch_post
	wpi.material_override = steel
	wpi.position = Vector3(1.35, 0.55, 0.0)
	root.add_child(wpi)
	var winch := BoxMesh.new()
	winch.size = Vector3(0.32, 0.28, 0.38)
	var wmi := MeshInstance3D.new()
	wmi.mesh = winch
	wmi.material_override = steel
	wmi.position = Vector3(1.35, 1.10, 0.0)
	root.add_child(wmi)
	var hitch := BoxMesh.new()
	hitch.size = Vector3(0.7, 0.10, 0.10)
	var hmi := MeshInstance3D.new()
	hmi.mesh = hitch
	hmi.material_override = steel
	hmi.position = Vector3(2.1, 0.0, 0.0)
	root.add_child(hmi)
	# a white hull sitting on the trailer bunks, so the launch reads as a working boat launch from the air
	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color(0.78, 0.81, 0.78)
	hull_mat.metallic = 0.35
	hull_mat.roughness = 0.42
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color(0.18, 0.23, 0.25)
	trim.roughness = 0.7
	var hull := BoxMesh.new()
	hull.size = Vector3(3.2, 0.55, 1.3)
	var hi := MeshInstance3D.new()
	hi.mesh = hull
	hi.material_override = hull_mat
	hi.position = Vector3(-0.1, 0.68, 0.0)
	root.add_child(hi)
	var bow := BoxMesh.new()
	bow.size = Vector3(0.9, 0.40, 1.05)
	var bi := MeshInstance3D.new()
	bi.mesh = bow
	bi.material_override = hull_mat
	bi.position = Vector3(1.65, 0.64, 0.0)
	bi.rotation.y = 0.35
	root.add_child(bi)
	var motor := BoxMesh.new()
	motor.size = Vector3(0.32, 0.50, 0.26)
	var mi := MeshInstance3D.new()
	mi.mesh = motor
	mi.material_override = trim
	mi.position = Vector3(-1.8, 0.54, 0.0)
	root.add_child(mi)

func _build_sign() -> void:
	var p := Vector2(-414.0, 112.0)
	var y := terrain.height(p.x, p.y)
	var sroot := Node3D.new()
	sroot.position = Vector3(p.x, y, p.y)
	add_child(sroot)
	if _try_site_model(sroot, "boat_launch_sign", 0.0):
		return
	if _try_site_model(sroot, "boat_launch_notice_board", 0.0):
		return
	var post := StandardMaterial3D.new()
	post.albedo_color = Color(0.23, 0.20, 0.16)
	post.roughness = 0.95
	for z in [-1.2, 1.2]:
		var pole := CylinderMesh.new()
		pole.top_radius = 0.07
		pole.bottom_radius = 0.09
		pole.height = 3.0
		var pi := MeshInstance3D.new()
		pi.mesh = pole
		pi.material_override = post
		pi.position = Vector3(p.x, y + 1.5, p.y + z)
		add_child(pi)
	var board_mat := StandardMaterial3D.new()
	board_mat.albedo_color = Color(0.78, 0.74, 0.58)
	board_mat.roughness = 0.86
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = Color(0.46, 0.17, 0.11)
	trim_mat.roughness = 0.9
	var backing := BoxMesh.new()
	backing.size = Vector3(0.08, 1.15, 3.35)
	var bk := MeshInstance3D.new()
	bk.mesh = backing
	bk.material_override = trim_mat
	bk.position = Vector3(p.x, y + 2.55, p.y)
	add_child(bk)
	var board := BoxMesh.new()
	board.size = Vector3(0.09, 0.98, 3.1)
	var bi := MeshInstance3D.new()
	bi.mesh = board
	bi.material_override = board_mat
	bi.position = Vector3(p.x - 0.02, y + 2.55, p.y)
	add_child(bi)
	var label := Label3D.new()
	label.text = "HALLOWAY LAKE\nBOAT LAUNCH"
	label.font_size = 40
	label.pixel_size = 0.005
	label.modulate = Color(0.13, 0.12, 0.10)
	label.position = Vector3(p.x - 0.10, y + 2.58, p.y)
	label.rotation.y = -PI * 0.5
	label.no_depth_test = false
	add_child(label)
	# a red and white life ring on the sign post
	var ring := TorusMesh.new()
	ring.inner_radius = 0.28
	ring.outer_radius = 0.48
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.72, 0.18, 0.13)
	ring_mat.roughness = 0.8
	var ri := MeshInstance3D.new()
	ri.mesh = ring
	ri.material_override = ring_mat
	ri.position = Vector3(p.x - 0.22, y + 1.75, p.y - 1.2)
	ri.rotation.x = PI * 0.5
	add_child(ri)

func _build_bollards() -> void:
	var broot := Node3D.new()
	broot.position = Vector3(TOP_SPOT.x, terrain.height(TOP_SPOT.x, TOP_SPOT.y) + 0.10, TOP_SPOT.y)
	add_child(broot)
	if _try_site_model(broot, "boat_launch_bollards", 0.0):
		return
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.27, 0.23, 0.18)
	wood.roughness = 0.95
	for z in [-RAMP_WIDTH * 0.5 - 0.5, RAMP_WIDTH * 0.5 + 0.5]:
		var p := TOP_SPOT
		var y := terrain.height(p.x, p.y)
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.14
		cyl.bottom_radius = 0.16
		cyl.height = 1.1
		var ci := MeshInstance3D.new()
		ci.mesh = cyl
		ci.material_override = wood
		ci.position = Vector3(p.x + 0.5, y + 0.55, p.y + z)
		add_child(ci)

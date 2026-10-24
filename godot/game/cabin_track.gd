class_name CabinTrack
extends Node3D
## The old cabin track (session B): after the asphalt ridge road, the last way to the cabin is a dirt and gravel track,
## not a country highway. It is narrow, rutted, edged with grass, and blocked in places by fallen trees and rockfall.
## A cave entrance sits in the outcrop west of the cabin.
##
## The track is scenery: the player flies over it, and the obstacles are there to read from the air and from the cabin.
## They have no collisions.

const POINTS := [
	Vector2(45.0, -760.0), Vector2(18.0, -768.0), Vector2(-16.0, -777.0), Vector2(-50.0, -786.0),
	Vector2(-86.0, -795.0), Vector2(-122.0, -802.0), Vector2(-160.0, -807.0), Vector2(-198.0, -812.0),
	Vector2(-230.0, -817.0), Vector2(-250.0, -820.0),
]
const WIDTH := 3.4
const CAVE := Vector2(-292.0, -806.0)

static var _samples: Array[Vector2] = []

static func _ensure_samples() -> void:
	if not _samples.is_empty():
		return
	for i in POINTS.size() - 1:
		var a: Vector2 = POINTS[i]
		var b: Vector2 = POINTS[i + 1]
		var n := maxi(1, int(ceil(a.distance_to(b) / 2.0)))
		for k in n:
			_samples.append(a.lerp(b, float(k) / float(n)))
	_samples.append(POINTS[POINTS.size() - 1])

static func near_track(x: float, z: float, margin := 7.0) -> bool:
	_ensure_samples()
	var p := Vector2(x, z)
	for q in _samples:
		if p.distance_to(q) < WIDTH * 0.5 + margin:
			return true
	return false

var terrain: Terrain

func setup(t: Terrain) -> void:
	terrain = t
	_build_track()
	_build_ruts()
	_build_fall(-76.0, -789.0, 1.35, 7.0)
	_build_fall(-158.0, -806.0, 1.2, 8.2)
	_build_rocks(Vector2(-206.0, -813.0), 0.25)
	_build_rocks(Vector2(-232.0, -818.0), -0.4)
	_build_cave_apron()
	_build_cave()
	print("cabin track: old road with 2 fallen trees, 2 rockfalls and a cave")

func _build_track() -> void:
	_ensure_samples()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var dist := 0.0
	var prev: Vector2 = _samples[0]
	for i in _samples.size():
		var p: Vector2 = _samples[i]
		if i > 0:
			dist += prev.distance_to(p)
		prev = p
		var t: Vector2
		if i == 0:
			t = (_samples[1] - _samples[0]).normalized()
		elif i == _samples.size() - 1:
			t = (_samples[i] - _samples[i - 1]).normalized()
		else:
			t = (_samples[i + 1] - _samples[i - 1]).normalized()
		var side := Vector2(-t.y, t.x)
		var hc := terrain.height(p.x, p.y)
		var hl := terrain.height(p.x - side.x * WIDTH * 0.5, p.y - side.y * WIDTH * 0.5)
		var hr := terrain.height(p.x + side.x * WIDTH * 0.5, p.y + side.y * WIDTH * 0.5)
		var base := maxf(hc, maxf(hl, hr)) + 0.22
		verts.append(Vector3(p.x - side.x * WIDTH * 0.5, base, p.y - side.y * WIDTH * 0.5))
		verts.append(Vector3(p.x + side.x * WIDTH * 0.5, base, p.y + side.y * WIDTH * 0.5))
		norms.append(Vector3.UP); norms.append(Vector3.UP)
		uvs.append(Vector2(0.0, dist / 6.0)); uvs.append(Vector2(1.0, dist / 6.0))
	for i in _samples.size() - 1:
		var a := i * 2
		var c := (i + 1) * 2
		idx.append_array([a, a + 1, c, a + 1, c + 1, c])
	var mesh := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.58, 0.49, 0.36)
	mat.albedo_texture = load("res://assets/textures/path_diff.jpg")
	mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
	mat.roughness = 0.98
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _build_ruts() -> void:
	_ensure_samples()
	for side_sign in [-1.0, 1.0]:
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var uvs := PackedVector2Array()
		var idx := PackedInt32Array()
		var dist := 0.0
		var prev: Vector2 = _samples[0]
		for i in _samples.size():
			var p: Vector2 = _samples[i]
			if i > 0:
				dist += prev.distance_to(p)
			prev = p
			var t: Vector2
			if i == 0:
				t = (_samples[1] - _samples[0]).normalized()
			elif i == _samples.size() - 1:
				t = (_samples[i] - _samples[i - 1]).normalized()
			else:
				t = (_samples[i + 1] - _samples[i - 1]).normalized()
			var side := Vector2(-t.y, t.x)
			var off := side * (0.82 * float(side_sign))
			var w := side * 0.14
			var a2 := p + off - w
			var b2 := p + off + w
			var rb := maxf(terrain.height(a2.x, a2.y), maxf(terrain.height(b2.x, b2.y), terrain.height(p.x, p.y))) + 0.24
			var ha := rb
			var hb := rb
			verts.append(Vector3(a2.x, ha, a2.y))
			verts.append(Vector3(b2.x, hb, b2.y))
			norms.append(Vector3.UP); norms.append(Vector3.UP)
			uvs.append(Vector2(0.0, dist / 4.0)); uvs.append(Vector2(1.0, dist / 4.0))
		for i in _samples.size() - 1:
			var a3 := i * 2
			var c3 := (i + 1) * 2
			idx.append_array([a3, a3 + 1, c3, a3 + 1, c3 + 1, c3])
		var mesh := ArrayMesh.new()
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.23, 0.20, 0.16)
		mat.roughness = 0.98
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
func _build_fall(x: float, z: float, yaw: float, length: float) -> void:
	var p := Vector2(x, z)
	var root := Node3D.new()
	root.position = Vector3(p.x, terrain.height(p.x, p.y) + 0.38, p.y)
	root.rotation.y = yaw
	add_child(root)
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.26, 0.19, 0.12)
	bark.roughness = 0.95
	var cut := StandardMaterial3D.new()
	cut.albedo_color = Color(0.54, 0.42, 0.25)
	cut.roughness = 0.9
	var trunk := BoxMesh.new()
	trunk.size = Vector3(length, 0.46, 0.58)
	var ti := MeshInstance3D.new()
	ti.mesh = trunk
	ti.material_override = bark
	ti.position = Vector3(0.0, 0.0, 0.0)
	ti.rotation.z = 0.06
	root.add_child(ti)
	var end := CylinderMesh.new()
	end.top_radius = 0.24
	end.bottom_radius = 0.24
	end.height = 0.62
	var ei := MeshInstance3D.new()
	ei.mesh = end
	ei.material_override = cut
	ei.position = Vector3(-length * 0.5, 0.0, 0.0)
	ei.rotation.z = PI * 0.5
	root.add_child(ei)
	# roots at one end and a few snapped branches across the track
	for i in 4:
		var b := BoxMesh.new()
		b.size = Vector3(0.16, 0.16, 1.3 + float(i) * 0.35)
		var bi := MeshInstance3D.new()
		bi.mesh = b
		bi.material_override = bark
		bi.position = Vector3(-length * 0.5 + 0.3, 0.1, 0.0)
		bi.rotation.x = -0.8 + float(i) * 0.35
		bi.rotation.y = float(i) * 0.6
		root.add_child(bi)
	var crown := SphereMesh.new()
	crown.radius = 1.1
	crown.height = 1.4
	var ci := MeshInstance3D.new()
	ci.mesh = crown
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.30, 0.24, 0.12)
	leaf.roughness = 0.95
	ci.material_override = leaf
	ci.position = Vector3(length * 0.35, 0.25, 0.0)
	root.add_child(ci)

func _build_rocks(center: Vector2, _yaw: float) -> void:
	var root := Node3D.new()
	root.position = Vector3(center.x, terrain.height(center.x, center.y), center.y)
	add_child(root)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.34, 0.30)
	mat.roughness = 0.96
	for i in 7:
		var rock := SphereMesh.new()
		rock.radius = 0.7 + 0.24 * float(i % 3)
		rock.height = 1.1 + 0.35 * float(i % 2)
		var ri := MeshInstance3D.new()
		ri.mesh = rock
		ri.material_override = mat
		ri.position = Vector3(-2.2 + 0.72 * float(i), 0.32 + 0.22 * float(i % 2), -1.0 + 0.45 * float(i % 4))
		ri.scale = Vector3(1.1, 0.8 + 0.2 * float(i % 3), 0.8)
		ri.rotation = Vector3(0.0, float(i) * 0.6, 0.0)
		root.add_child(ri)

func _build_cave_apron() -> void:
	var root := Node3D.new()
	root.position = Vector3(CAVE.x, terrain.height(CAVE.x, CAVE.y) + 0.10, CAVE.y)
	add_child(root)
	var seg := 24
	var radius := 8.0
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	verts.append(Vector3(0.0, 0.0, 0.0))
	norms.append(Vector3.UP)
	for i in seg:
		var a := TAU * float(i) / float(seg)
		verts.append(Vector3(cos(a) * radius, 0.0, sin(a) * radius))
		norms.append(Vector3.UP)
	for i in seg:
		idx.append_array([0, 1 + (i + 1) % seg, 1 + i])
	var mesh := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.33, 0.30, 0.24)
	mat.roughness = 0.98
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
func _build_cave() -> void:
	var p := CAVE
	var root := Node3D.new()
	root.position = Vector3(p.x, terrain.height(p.x, p.y), p.y)
	var face := (Vector2(-250.0, -820.0) - p).normalized()
	root.rotation.y = atan2(face.x, face.y)
	add_child(root)
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.31, 0.30, 0.26)
	rock.roughness = 0.97
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.018, 0.016, 0.014)
	dark.roughness = 0.9
	# a broken outcrop around a black mouth, not a cut hole in a flat wall
	for spec in [
		[Vector3(-2.6, 1.5, 0.0), Vector3(1.8, 2.8, 1.4)],
		[Vector3(2.4, 1.7, 0.1), Vector3(2.0, 3.0, 1.5)],
		[Vector3(0.0, 3.5, -0.1), Vector3(2.8, 1.6, 1.3)],
		[Vector3(-1.3, 0.5, 0.9), Vector3(1.2, 0.9, 1.0)],
		[Vector3(1.6, 0.4, 0.8), Vector3(1.4, 0.8, 1.0)],
	]:
		var sph := SphereMesh.new()
		sph.radius = 1.0
		sph.height = 1.6
		var si := MeshInstance3D.new()
		si.mesh = sph
		si.material_override = rock
		si.position = spec[0]
		si.scale = spec[1]
		si.rotation = Vector3(0.2, 0.7, 0.15)
		root.add_child(si)
	var mouth := SphereMesh.new()
	mouth.radius = 1.35
	mouth.height = 2.8
	var mi := MeshInstance3D.new()
	mi.mesh = mouth
	mi.material_override = dark
	mi.position = Vector3(0.0, 1.45, 1.02)
	mi.scale = Vector3(1.2, 1.15, 0.3)
	root.add_child(mi)	# a darker flat mouth behind the boulders, so the entrance reads as a hole from the air
	var mouth_flat := BoxMesh.new()
	mouth_flat.size = Vector3(2.4, 2.6, 0.18)
	var mfi := MeshInstance3D.new()
	mfi.mesh = mouth_flat
	mfi.material_override = dark
	mfi.position = Vector3(0.0, 1.28, 1.85)
	root.add_child(mfi)
	# a fallen slab and a few stones at the mouth
	var slab := BoxMesh.new()
	slab.size = Vector3(3.8, 0.32, 1.6)
	var si2 := MeshInstance3D.new()
	si2.mesh = slab
	si2.material_override = rock
	si2.position = Vector3(-1.8, 0.25, 1.7)
	si2.rotation.z = -0.18
	root.add_child(si2)
	# a simple old warning post
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.24, 0.19, 0.13)
	post_mat.roughness = 0.95
	var post := BoxMesh.new()
	post.size = Vector3(0.14, 2.2, 0.14)
	var pi := MeshInstance3D.new()
	pi.mesh = post
	pi.material_override = post_mat
	pi.position = Vector3(3.4, 1.1, 2.0)
	root.add_child(pi)
	var board := BoxMesh.new()
	board.size = Vector3(2.0, 0.5, 0.06)
	var bi := MeshInstance3D.new()
	bi.mesh = board
	bi.material_override = post_mat
	bi.position = Vector3(3.4, 2.05, 2.0)
	root.add_child(bi)
	var label := Label3D.new()
	label.text = "CAVE\nKEEP OUT"
	label.font_size = 80
	label.pixel_size = 0.0028
	label.modulate = Color(0.86, 0.82, 0.70)
	label.position = Vector3(3.4, 2.05, 2.06)
	root.add_child(label)

class_name Farmland
extends Node3D
## The farm's fields: tilled soil, corn, barley and alfalfa in rows, hay bales, and post-and-rail field fences
## (session B). This is the placeholder planting until Claude's farm models land: the geometry is deliberately simple
## crossed quads and boxes, built here so the valley already reads as working farmland from the air and from the road.
## The field rectangles are fixed and known before the world is planted, so World skips trees and props inside them.
##
## Everything is instanced (MultiMesh) and built once at startup. No collisions: the crops, bales and fences are
## harmless scenery, like the roads, and Claude's models can replace the crop, bale and fence meshes later without
## changing the field layout.

const FARM := Vector2(165.4, 522.6)
const CEMETERY_SOUTH := 238.0
const FIELDS := [
	{"id": "corn", "crop": "corn", "centre": Vector2(300.0, 590.0), "size": Vector2(90.0, 60.0), "yaw": 0.15},
	{"id": "barley", "crop": "barley", "centre": Vector2(120.0, 640.0), "size": Vector2(80.0, 52.0), "yaw": -0.20},
	{"id": "alfalfa", "crop": "alfalfa", "centre": Vector2(330.0, 468.0), "size": Vector2(70.0, 46.0), "yaw": 0.30},
	{"id": "hay", "crop": "hay", "centre": Vector2(55.0, 585.0), "size": Vector2(70.0, 50.0), "yaw": 0.10},
]

var terrain: Terrain
var _stats := {}

## The nearest field edge to the cemetery wall, in metres. The fields are deliberately far south of the park.
static func min_cemetery_gap() -> float:
	var gap := 1e9
	for f in FIELDS:
		var c: Vector2 = f["centre"]
		var s: Vector2 = f["size"]
		var half_extent := absf(sin(float(f["yaw"]))) * s.x * 0.5 + absf(cos(float(f["yaw"]))) * s.y * 0.5
		gap = minf(gap, c.y - half_extent - CEMETERY_SOUTH)
	return gap

static func inside_any(x: float, z: float, margin := 2.0) -> bool:
	for f in FIELDS:
		var c: Vector2 = f["centre"]
		var s: Vector2 = f["size"]
		var yaw := float(f["yaw"])
		var dx := x - c.x
		var dz := z - c.y
		var lx := dx * cos(-yaw) - dz * sin(-yaw)
		var lz := dx * sin(-yaw) + dz * cos(-yaw)
		if absf(lx) < s.x * 0.5 + margin and absf(lz) < s.y * 0.5 + margin:
			return true
	return false

func setup(t: Terrain) -> void:
	terrain = t
	for f in FIELDS:
		_build_field(f)
	_build_yard()
	print("farmland: ", stats(), "  cemetery gap ", snappedf(min_cemetery_gap(), 0.1), " m")

func _build_field(f: Dictionary) -> void:
	var centre: Vector2 = f["centre"]
	var size: Vector2 = f["size"]
	var yaw := float(f["yaw"])
	var crop := str(f["crop"])
	var basis := Basis(Vector3.UP, yaw)
	# soil
	_build_soil(centre, size, yaw)
	if crop != "hay":
		_build_crop(centre, size, yaw, crop)
	else:
		_build_hay(centre, size, yaw)
	_build_fence(centre, size, yaw)

func _rotated(centre: Vector2, yaw: float, lx: float, lz: float) -> Vector2:
	return centre + Vector2(lx * cos(yaw) - lz * sin(yaw), lx * sin(yaw) + lz * cos(yaw))

# ------------------------------------------------------------------ tilled soil
func _build_soil(centre: Vector2, size: Vector2, yaw: float) -> void:
	var step := 4.0
	var nx := maxi(2, int(ceil(size.x / step)))
	var nz := maxi(2, int(ceil(size.y / step)))
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for j in nz + 1:
		for i in nx + 1:
			var lx := -size.x * 0.5 + size.x * float(i) / float(nx)
			var lz := -size.y * 0.5 + size.y * float(j) / float(nz)
			var p := _rotated(centre, yaw, lx, lz)
			verts.append(Vector3(p.x, terrain.height(p.x, p.y) + 0.06, p.y))
			norms.append(Vector3.UP)
			uvs.append(Vector2(lx + size.x * 0.5, lz + size.y * 0.5))
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])
	var mesh := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/shaders/field_soil.gdshader")
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

# ------------------------------------------------------------------ crops
func _crop_mesh(kind: String) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	match kind:
		"corn":
			for i in 10:
				var z := -2.0 + float(i) * 0.4
				# stem
				_quad(v, n, c, Vector3(-0.035, 0.0, z), Vector3(0.035, 0.0, z), Vector3(0.035, 2.1, z), Vector3(-0.035, 2.1, z), Color(0.24, 0.34, 0.14), idx)
				# leaves, each a long angled blade
				for k in 3:
					var h := 0.55 + float(k) * 0.45
					var a := 0.7 * float(k + 1)
					var dir := Vector3(cos(a), 0.0, sin(a)) * 0.55
					var base := Vector3(0.0, h, z)
					_quad(v, n, c, base, base + Vector3(0.0, 0.16, 0.0), base + dir + Vector3(0.0, 0.3, 0.0), base + dir, Color(0.30, 0.42, 0.16), idx)
				# tassel
				_quad(v, n, c, Vector3(-0.05, 2.1, z), Vector3(0.05, 2.1, z), Vector3(0.0, 2.3, z), Vector3(-0.02, 2.32, z), Color(0.66, 0.60, 0.34), idx)
		"barley":
			for i in 24:
				var z := -2.0 + float(i) * 0.166
				var sway := sin(float(i) * 2.1) * 0.08
				for k in 2:
					var a := float(k) * PI * 0.5 + 0.4
					var base := Vector3(0.0, 0.0, z + sway)
					var tip := base + Vector3(cos(a) * 0.10, 0.8, sin(a) * 0.10)
					var wide := Vector3(cos(a + 1.57) * 0.05, 0.0, sin(a + 1.57) * 0.05)
					_quad(v, n, c, base - wide, base + wide, tip, tip - wide, Color(0.52, 0.50, 0.22), idx)
		"alfalfa":
			for i in 14:
				var z := -2.0 + float(i) * 0.285
				var a := float(i) * 1.7
				for k in 2:
					var base := Vector3(0.0, 0.0, z)
					var dir := Vector3(cos(a + float(k) * 1.2) * 0.28, 0.42, sin(a + float(k) * 1.2) * 0.28)
					_quad(v, n, c, base - Vector3(0.10, 0.0, 0.0), base + Vector3(0.10, 0.0, 0.0), base + dir + Vector3(0.06, 0.0, 0.0), base + dir - Vector3(0.06, 0.0, 0.0), Color(0.20, 0.36, 0.14), idx)
	var mesh := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

func _quad(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray,
		a: Vector3, b: Vector3, cc: Vector3, d: Vector3, col: Color, idx: PackedInt32Array) -> void:
	var base := v.size()
	var nn := (b - a).cross(d - a).normalized()
	for p in [a, b, cc, d]:
		v.append(p)
		n.append(nn)
		c.append(col)
	idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

func _crop_arrays(kind: String) -> Dictionary:
	var mesh := _crop_mesh(kind)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0)
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.92
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return {"mesh": mesh, "mat": mat}

func _build_crop(centre: Vector2, size: Vector2, yaw: float, kind: String) -> void:
	var plant := _crop_arrays(kind)
	var spacing_x := 0.9 if kind == "corn" else (0.6 if kind == "barley" else 0.5)
	var chunk := 4.0
	var cols := int(maxf(1.0, floorf(size.x / spacing_x)))
	var rows := int(maxf(1.0, floorf(size.y / chunk)))
	var xforms: Array = []
	for r in rows:
		for i in cols:
			var lx := -size.x * 0.5 + spacing_x * 0.5 + float(i) * spacing_x
			var lz := -size.y * 0.5 + chunk * 0.5 + float(r) * chunk
			var p := _rotated(centre, yaw, lx, lz)
			var h := terrain.height(p.x, p.y) + 0.04
			var b := Basis(Vector3.UP, yaw + float(r) * 0.15 + float(i) * 0.7)
			xforms.append(Transform3D(b, Vector3(p.x, h, p.y)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = plant["mesh"]
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = plant["mat"]
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_stats[kind] = int(_stats.get(kind, 0)) + xforms.size()

# ------------------------------------------------------------------ hay bales
func _cylinder_mesh(radius: float, height: float) -> Mesh:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 10
	cm.rings = 1
	return cm

func _box_mesh(size: Vector3) -> Mesh:
	var bm := BoxMesh.new()
	bm.size = size
	return bm

func _bale_material(wrapped: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.84, 0.84, 0.80) if wrapped else Color(0.60, 0.50, 0.26)
	m.roughness = 0.95
	return m

func _build_hay(centre: Vector2, size: Vector2, yaw: float) -> void:
	# round bales scattered across the meadow, a few wrapped and some square bales in a stack at the edge
	var round_mesh := _cylinder_mesh(0.62, 1.25)
	var square_mesh := _box_mesh(Vector3(0.9, 0.45, 0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = 771
	for wrapped in [false, true]:
		var xforms: Array = []
		for i in (9 if not wrapped else 5):
			var lx := rng.randf_range(-size.x * 0.42, size.x * 0.42)
			var lz := rng.randf_range(-size.y * 0.42, size.y * 0.42)
			var p := _rotated(centre, yaw, lx, lz)
			var h := terrain.height(p.x, p.y) + 0.62
			var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.5)
			xforms.append(Transform3D(b, Vector3(p.x, h, p.y)))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = round_mesh
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _bale_material(wrapped)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	_stats["bales"] = int(_stats.get("bales", 0)) + 14
	# a small square-bale stack near the farmyard
	var stack: Array = []
	for layer in 3:
		for i in (3 - layer):
			var p := _rotated(centre, yaw, -size.x * 0.5 + 4.0, size.y * 0.5 - 3.0 + float(i) * 0.5)
			var h := terrain.height(p.x, p.y) + 0.22 + float(layer) * 0.46
			stack.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, h, p.y)))
	var smm := MultiMesh.new()
	smm.transform_format = MultiMesh.TRANSFORM_3D
	smm.mesh = square_mesh
	smm.instance_count = stack.size()
	for i in stack.size():
		smm.set_instance_transform(i, stack[i])
	var smmi := MultiMeshInstance3D.new()
	smmi.multimesh = smm
	smmi.material_override = _bale_material(false)
	smmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smmi)
	_stats["square"] = int(_stats.get("square", 0)) + stack.size()

# ------------------------------------------------------------------ fences
func _fence_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.38, 0.30, 0.20)
	m.roughness = 0.95
	return m

func _build_fence(centre: Vector2, size: Vector2, yaw: float) -> void:
	var post_mesh := _box_mesh(Vector3(0.13, 1.25, 0.13))
	var rail_mesh := _box_mesh(Vector3(3.0, 0.10, 0.05))
	var posts: Array = []
	var rails: Array = []
	var edges := [
		[Vector3(-size.x * 0.5, 0, -size.y * 0.5), Vector3(size.x, 0, 0)],
		[Vector3(size.x * 0.5, 0, -size.y * 0.5), Vector3(0, 0, size.y)],
		[Vector3(-size.x * 0.5, 0, size.y * 0.5), Vector3(size.x, 0, 0)],
		[Vector3(-size.x * 0.5, 0, -size.y * 0.5), Vector3(0, 0, size.y)],
	]
	for e in edges:
		var start: Vector3 = e[0]
		var dir: Vector3 = e[1]
		if dir.length() < 0.01:
			continue
		var n := maxi(1, int(ceil(dir.length() / 3.0)))
		var step := dir / float(n)
		var edge_angle := atan2(-step.z, step.x)   # a box's +X turned onto this edge
		for i in n + 1:
			var lp := start + step * float(i)
			var wp := _rotated(centre, yaw, lp.x, lp.z)
			posts.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(wp.x, terrain.height(wp.x, wp.y) + 0.62, wp.y)))
			if i < n:
				var mid := lp + step * 0.5
				var wp2 := _rotated(centre, yaw, mid.x, mid.z)
				var h := terrain.height(wp2.x, wp2.y)
				for y in [0.55, 0.95]:
					rails.append(Transform3D(Basis(Vector3.UP, yaw + edge_angle), Vector3(wp2.x, h + float(y), wp2.y)))
	var pmm := MultiMesh.new()
	pmm.transform_format = MultiMesh.TRANSFORM_3D
	pmm.mesh = post_mesh
	pmm.instance_count = posts.size()
	for i in posts.size():
		pmm.set_instance_transform(i, posts[i])
	var pmi := MultiMeshInstance3D.new()
	pmi.multimesh = pmm
	pmi.material_override = _fence_material()
	add_child(pmi)
	var rmm := MultiMesh.new()
	rmm.transform_format = MultiMesh.TRANSFORM_3D
	rmm.mesh = rail_mesh
	rmm.instance_count = rails.size()
	for i in rails.size():
		rmm.set_instance_transform(i, rails[i])
	var rmi := MultiMeshInstance3D.new()
	rmi.multimesh = rmm
	rmi.material_override = _fence_material()
	add_child(rmi)
	_stats["posts"] = int(_stats.get("posts", 0)) + posts.size()

# ------------------------------------------------------------------ farmyard extras
func _build_yard() -> void:
	var s: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	for i in 8:
		var p := FARM + Vector2(rng.randf_range(-38.0, 38.0), rng.randf_range(-30.0, 30.0))
		if Roads.near_road(p.x, p.y, 6.0):
			continue
		s.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, terrain.height(p.x, p.y) + 0.62, p.y)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _cylinder_mesh(0.62, 1.25)
	mm.instance_count = s.size()
	for i in s.size():
		mm.set_instance_transform(i, s[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _bale_material(false)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_stats["yard_bales"] = s.size()

func stats() -> Dictionary:
	return _stats

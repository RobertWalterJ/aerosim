class_name Roads
extends Node3D
## Country highways and lanes linking the valley's places (session B).
##
## The road plan is fixed so the trees can be kept off it while the world is planted: World skips any tree, far tree or
## prop within a few metres of a route centreline. The routes follow the terrain height, with an asphalt ribbon, dashed
## centre line and edge lines, gravel shoulders, and a worn surface shader. Three roads: the valley highway from the
## start pad past the chapel and down to the farm, the lakeside lane from the farm round to the lake overlook, and the
## long ridge road from the pad and the graves north to the railway. None of them is a race track or a gate: they are
## scenery and a way to read the valley from low down.
##
## The mesh is built once at startup. Roughly four metres between samples and about ten metres of clearance for trees.

const STEP := 3.0
const CLEAR_STEP := 6.0
const CLEAR_CELL := 24.0
const TREE_CLEARANCE := 10.0

const ROUTES := [
	{
		"id": "valley", "name": "valley highway", "width": 8.0, "shoulder": 2.4,
		"points": [Vector2(-18.0, 36.0), Vector2(60.0, -20.0), Vector2(188.0, -74.0), Vector2(225.0, 80.0),
			Vector2(240.0, 320.0), Vector2(215.0, 505.0)],
	},
	{
		"id": "lake", "name": "lakeside lane", "width": 5.0, "shoulder": 1.8,
		"points": [Vector2(215.0, 505.0), Vector2(90.0, 470.0), Vector2(-80.0, 420.0), Vector2(-260.0, 300.0),
			Vector2(-380.0, 190.0), Vector2(-410.0, 120.0)],
	},
	{
		"id": "ridge", "name": "ridge road", "width": 7.0, "shoulder": 2.2,
		"points": [Vector2(-18.0, 36.0), Vector2(22.0, 81.0), Vector2(-10.0, -200.0), Vector2(-30.0, -500.0),
			Vector2(0.0, -900.0), Vector2(0.0, -1530.0)],
	},
]

static var _ready := false
static var _clear_grid := {}       # Vector2i cell -> Array[Vector2] of centreline samples
static var _samples_by_route := {} # id -> Array[Vector2] centroid samples

var terrain: Terrain
var paths := {}                    # route id -> Array[Vector2] of the smooth centreline (traffic reads this)
var _lengths := {}

# ------------------------------------------------------------------ clearance for the world planting
static func _ensure_index() -> void:
	if _ready:
		return
	for r in ROUTES:
		var pts: Array = r["points"]
		var samples: Array = []
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var d := a.distance_to(b)
			var n := maxi(1, int(ceil(d / CLEAR_STEP)))
			for k in n:
				samples.append(a.lerp(b, float(k) / float(n)))
		samples.append(pts[pts.size() - 1])
		_samples_by_route[str(r["id"])] = samples
		for p in samples:
			var cell := Vector2i(floori(p.x / CLEAR_CELL), floori(p.y / CLEAR_CELL))
			if not _clear_grid.has(cell):
				_clear_grid[cell] = []
			_clear_grid[cell].append(p)
	_ready = true

## True when (x, z) is inside a road corridor (including shoulders and the tree margin). Cheap: 5x5 coarse cells.
static func near_road(x: float, z: float, margin := TREE_CLEARANCE) -> bool:
	_ensure_index()
	var want := margin + CLEAR_STEP * 0.6
	var cell := Vector2i(floori(x / CLEAR_CELL), floori(z / CLEAR_CELL))
	var p := Vector2(x, z)
	for a in range(-1, 2):
		for b in range(-1, 2):
			for q in _clear_grid.get(Vector2i(cell.x + a, cell.y + b), []):
				if p.distance_to(q) < want:
					return true
	return false

# ------------------------------------------------------------------ meshes
func setup(t: Terrain) -> void:
	terrain = t
	for r in ROUTES:
		paths[str(r["id"])] = _route_points(r)
	for r in ROUTES:
		_build_route(r)
	print("roads: ", stats())

func route_ids() -> Array:
	return paths.keys()

func path(id: String) -> Array:
	return paths.get(id, [])

## The point and direction at a distance along a route (metres), for traffic.
func sample(id: String, s: float) -> Dictionary:
	var pts: Array = paths.get(id, [])
	if pts.size() < 2:
		return {}
	var total := 0.0
	var i := 0
	while i < pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var d := a.distance_to(b)
		if s <= total + d or i == pts.size() - 2:
			var k := clampf((s - total) / maxf(d, 0.001), 0.0, 1.0)
			return {"pos": a.lerp(b, k), "dir": (b - a).normalized(), "length": _lengths.get(id, 0.0)}
		total += d
		i += 1
	return {}

func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

func _route_points(route: Dictionary) -> Array:
	var pts: Array = route["points"]
	var out: Array = []
	for i in pts.size() - 1:
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p0: Vector2 = pts[i - 1] if i > 0 else p1
		var p3: Vector2 = pts[i + 2] if i + 2 < pts.size() else p2
		var seg := p1.distance_to(p2)
		var n := maxi(2, int(ceil(seg / STEP)))
		for k in n:
			out.append(_catmull(p0, p1, p2, p3, float(k) / float(n)))
	out.append(pts[pts.size() - 1])
	return out

func _build_route(route: Dictionary) -> void:
	var pts := _route_points(route)
	if pts.size() < 3:
		return
	var width := float(route["width"])
	var shoulder := float(route["shoulder"])
	var half := width * 0.5
	var outer := half + shoulder
	# -- asphalt
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	# -- shoulders
	var sverts := PackedVector3Array()
	var snorms := PackedVector3Array()
	var suvs := PackedVector2Array()
	var sidx := PackedInt32Array()
	var dist := 0.0
	var prev: Vector2 = pts[0]
	for i in pts.size():
		var p: Vector2 = pts[i]
		if i > 0:
			dist += prev.distance_to(p)
		prev = p
		var t: Vector2
		if i == 0:
			t = (pts[1] - pts[0]).normalized()
		elif i == pts.size() - 1:
			t = (pts[i] - pts[i - 1]).normalized()
		else:
			t = (pts[i + 1] - pts[i - 1]).normalized()
		var side := Vector2(-t.y, t.x)
		var h := terrain.height(p.x, p.y) + 0.14
		var hl := terrain.height(p.x - side.x * half, p.y - side.y * half) + 0.14
		var hr := terrain.height(p.x + side.x * half, p.y + side.y * half) + 0.14
		var ho_l := terrain.height(p.x - side.x * outer, p.y - side.y * outer) + 0.08
		var ho_r := terrain.height(p.x + side.x * outer, p.y + side.y * outer) + 0.08
		verts.append(Vector3(p.x - side.x * half, hl, p.y - side.y * half))
		verts.append(Vector3(p.x + side.x * half, hr, p.y + side.y * half))
		norms.append(Vector3.UP); norms.append(Vector3.UP)
		uvs.append(Vector2(0.0, dist / 8.0)); uvs.append(Vector2(1.0, dist / 8.0))
		sverts.append(Vector3(p.x - side.x * outer, ho_l, p.y - side.y * outer))
		sverts.append(Vector3(p.x - side.x * half, hl, p.y - side.y * half))
		sverts.append(Vector3(p.x + side.x * half, hr, p.y + side.y * half))
		sverts.append(Vector3(p.x + side.x * outer, ho_r, p.y + side.y * outer))
		for k in 4:
			snorms.append(Vector3.UP)
		suvs.append(Vector2(0.0, dist / 4.0)); suvs.append(Vector2(1.0, dist / 4.0))
		suvs.append(Vector2(0.0, dist / 4.0)); suvs.append(Vector2(1.0, dist / 4.0))
	for i in pts.size() - 1:
		var a := i * 2
		var c := (i + 1) * 2
		idx.append_array([a, a + 1, c, a + 1, c + 1, c])
		var sa := i * 4
		var sc := (i + 1) * 4
		sidx.append_array([sa, sa + 1, sc, sa + 1, sc + 1, sc])             # left shoulder
		sidx.append_array([sa + 2, sa + 3, sc + 2, sa + 3, sc + 3, sc + 2]) # right shoulder
	_lengths[str(route["id"])] = dist
	var road_mesh := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	road_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/shaders/road_asphalt.gdshader")
	mat.set_shader_parameter("width_m", width)
	var mi := MeshInstance3D.new()
	mi.mesh = road_mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var sh_mesh := ArrayMesh.new()
	var sarr := []
	sarr.resize(Mesh.ARRAY_MAX)
	sarr[Mesh.ARRAY_VERTEX] = sverts
	sarr[Mesh.ARRAY_NORMAL] = snorms
	sarr[Mesh.ARRAY_TEX_UV] = suvs
	sarr[Mesh.ARRAY_INDEX] = sidx
	sh_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sarr)
	var smat := ShaderMaterial.new()
	smat.shader = load("res://game/shaders/road_gravel.gdshader")
	var smi := MeshInstance3D.new()
	smi.mesh = sh_mesh
	smi.material_override = smat
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smi)

func stats() -> Dictionary:
	var total := 0.0
	for k in _lengths:
		total += float(_lengths[k])
	return {"routes": _lengths.size(), "km": snappedf(total / 1000.0, 0.01), "lengths": _lengths}

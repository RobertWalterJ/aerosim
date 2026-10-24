class_name Roads
extends Node3D
## The roads stay outside the cemetery walls. The park owns its own paths and gates; the asphalt network connects the
## four gates to the farm, the lake, the festival field, the garage, the camp and the cabin. The old plan cut straight
## through the graves and the chapel, which was not acceptable.
##
## The mesh is built once at startup. Roughly four metres between samples and about ten metres of clearance for trees.

const STEP := 3.0
const CLEAR_STEP := 6.0
const CLEAR_CELL := 24.0
const TREE_CLEARANCE := 10.0
const MASK_N := 2048
const JUNCTIONS := [
	Vector2(270.0, 42.0), Vector2(286.0, 260.0), Vector2(215.0, 505.0), Vector2(12.0, -255.0),
	Vector2(-300.0, 300.0), Vector2(-410.0, 120.0),
]

const ROUTES := [
	{
		"id": "valley", "name": "valley highway", "width": 8.0, "shoulder": 2.4, "speed_limit": 40,
		# east gate car park, then around the east and south walls to the farm
		"points": [Vector2(270.0, 42.0), Vector2(280.0, 110.0), Vector2(286.0, 180.0), Vector2(286.0, 260.0),
			Vector2(270.0, 360.0), Vector2(240.0, 440.0), Vector2(215.0, 505.0)],
	},
	{
		"id": "south_lane", "name": "south gate lane", "width": 5.5, "shoulder": 1.8, "speed_limit": 20,
		# from the valley highway along the south wall to the south gate
		"points": [Vector2(286.0, 260.0), Vector2(200.0, 255.0), Vector2(100.0, 252.0), Vector2(17.0, 250.0)],
	},
	{
		"id": "village", "name": "village lane", "width": 5.0, "shoulder": 1.4, "speed_limit": 15,
		# Halloway village, east of the park and south of the festival field
		"points": [Vector2(286.0, 260.0), Vector2(320.0, 258.0), Vector2(370.0, 262.0), Vector2(420.0, 270.0), Vector2(455.0, 276.0)],
	},
	{
		"id": "east_link", "name": "east boundary lane", "width": 6.0, "shoulder": 2.0, "speed_limit": 30,
		# east gate car park north along the east wall to the north gate
		"points": [Vector2(270.0, 42.0), Vector2(276.0, -60.0), Vector2(276.0, -170.0), Vector2(260.0, -245.0),
			Vector2(150.0, -255.0), Vector2(12.0, -255.0)],
	},
	{
		"id": "ridge", "name": "ridge road", "width": 7.0, "shoulder": 2.2, "speed_limit": 40,
		# north gate north to the garage and the camp, outside the west side of the park
		"points": [Vector2(12.0, -255.0), Vector2(30.0, -320.0), Vector2(48.0, -420.0), Vector2(58.0, -520.0),
			Vector2(55.0, -600.0), Vector2(45.0, -760.0), Vector2(36.0, -900.0), Vector2(36.0, -1120.0)],
	},
	{
		"id": "lake", "name": "lakeside lane", "width": 5.0, "shoulder": 1.8, "speed_limit": 25,
		# farm south and west, outside the park, down to the lake overlook
		"points": [Vector2(215.0, 505.0), Vector2(90.0, 470.0), Vector2(-80.0, 420.0), Vector2(-200.0, 360.0),
			Vector2(-300.0, 300.0), Vector2(-340.0, 240.0), Vector2(-380.0, 180.0), Vector2(-410.0, 120.0)],
	},
	{
		"id": "west_link", "name": "west boundary lane", "width": 5.0, "shoulder": 1.8, "speed_limit": 20,
		# from the lakeside lane up the outside of the west wall to the west gate
		"points": [Vector2(-300.0, 300.0), Vector2(-292.0, 200.0), Vector2(-285.0, 100.0), Vector2(-280.0, 0.0),
			Vector2(-252.0, -4.0)],
	},
	{
		"id": "launch", "name": "boat launch lane", "width": 4.5, "shoulder": 1.6, "speed_limit": 10,
		# the last few metres from the lakeside lane to the boat launch parking apron
		"points": [Vector2(-410.0, 120.0), Vector2(-432.0, 112.0)],
	},

]

static var _ready := false
static var _clear_grid := {}       # Vector2i cell -> Array[Vector2] of centreline samples
static var _samples_by_route := {} # id -> Array[Vector2] centroid samples

var terrain: Terrain
var paths := {}                    # route id -> Array[Vector2] of the smooth centreline (traffic reads this)
var _lengths := {}
var _materials: Array[ShaderMaterial] = []
var _wetness := -1.0
var _asphalt_diff: Texture2D
var _asphalt_nor: Texture2D
var _asphalt_arm: Texture2D
var _gravel_diff: Texture2D
var _gravel_nor: Texture2D
var _gravel_arm: Texture2D
var road_mask: ImageTexture       # 2048 px mask of the asphalt and shoulder corridors, for the grass shader
var road_top: ImageTexture        # 2048 px surface-offset field: where the asphalt sits above the terrain
var _road_top_img: Image
var junction_mask: ImageTexture   # white at junctions, so lane markings stop through the crossing

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
	# keep trees and props off the junction aprons as well as the ribbons
	for j in JUNCTIONS:
		if p.distance_to(j) < 13.0 + margin * 0.4:
			return true
	for a in range(-1, 2):
		for b in range(-1, 2):
			for q in _clear_grid.get(Vector2i(cell.x + a, cell.y + b), []):
				if p.distance_to(q) < want:
					return true
	return false

## The ground under the drone: terrain plus the road surface offset where the asphalt, junction apron or old dirt
## track actually sits. This is the road collider in this game; the drone has no rigid-body collision, it samples this
## height at the four corners of its body. Without it the drone lands on the bare terrain inside the raised road.
func surface_height(x: float, z: float) -> float:
	var base := terrain.height(x, z)
	if _road_top_img == null:
		return base
	var px := clampi(int((x / Terrain.SIZE + 0.5) * MASK_N), 0, MASK_N - 1)
	var pz := clampi(int((z / Terrain.SIZE + 0.5) * MASK_N), 0, MASK_N - 1)
	var off := _road_top_img.get_pixel(px, pz).r * 0.30
	return base + maxf(off, 0.0)
# ------------------------------------------------------------------ meshes
func setup(t: Terrain) -> void:
	terrain = t
	_asphalt_diff = load("res://assets/textures/asphalt_diff.jpg")
	_asphalt_nor = load("res://assets/textures/asphalt_nor.jpg")
	_asphalt_arm = load("res://assets/textures/asphalt_arm.jpg")
	_gravel_diff = load("res://assets/textures/gravel_diff.jpg")
	_gravel_nor = load("res://assets/textures/gravel_nor.jpg")
	_gravel_arm = load("res://assets/textures/gravel_arm.jpg")
	for r in ROUTES:
		paths[str(r["id"])] = _route_points(r)
	_build_road_mask()
	_build_junction_mask()
	for r in ROUTES:
		_build_route(r)
	_build_junction_aprons()
	print("roads: ", stats(), " audit: ", audit())

## Rasterise the road corridor into a small mask. Grass reads it and keeps clear of the asphalt and the bare shoulder,
## which is what stops the meadow growing up through the carriageway.
func _build_road_mask() -> void:
	var img := Image.create(MASK_N, MASK_N, false, Image.FORMAT_L8)
	img.fill(Color(0, 0, 0, 1))
	var top := Image.create(MASK_N, MASK_N, false, Image.FORMAT_L8)
	top.fill(Color(0, 0, 0, 1))
	for r in ROUTES:
		var pts: Array = paths.get(str(r["id"]), [])
		var rad := float(r["width"]) * 0.5 + float(r["shoulder"]) + 5.5
		var halfw := float(r["width"]) * 0.5 + 0.2
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var steps := maxi(1, int(ceil(a.distance_to(b) / 1.5)))
			for k in steps:
				var p := a.lerp(b, float(k) / float(steps))
				var cx := int((p.x / Terrain.SIZE + 0.5) * MASK_N)
				var cz := int((p.y / Terrain.SIZE + 0.5) * MASK_N)
				var pr := int(ceil(rad / Terrain.SIZE * MASK_N))
				for dzz in range(-pr, pr + 1):
					for dxx in range(-pr, pr + 1):
						var xx := cx + dxx
						var zz := cz + dzz
						if xx < 0 or zz < 0 or xx >= MASK_N or zz >= MASK_N:
							continue
						var wp := Vector2((float(xx) + 0.5) / MASK_N * Terrain.SIZE - Terrain.SIZE * 0.5,
							(float(zz) + 0.5) / MASK_N * Terrain.SIZE - Terrain.SIZE * 0.5)
						if wp.distance_to(p) <= rad:
							img.set_pixel(xx, zz, Color.WHITE)
						if wp.distance_to(p) <= halfw:
							top.set_pixel(xx, zz, Color(0.20, 0.20, 0.20))   # 0.06 m / 0.30 m
	# the junction aprons are paved, so no meadow grows through the crossing
	for j in JUNCTIONS:
		var jx := int((j.x / Terrain.SIZE + 0.5) * MASK_N)
		var jz := int((j.y / Terrain.SIZE + 0.5) * MASK_N)
		var jr := int(ceil(13.0 / Terrain.SIZE * MASK_N))
		for dzz in range(-jr, jr + 1):
			for dxx in range(-jr, jr + 1):
				var xxj := jx + dxx
				var zzj := jz + dzz
				if xxj < 0 or zzj < 0 or xxj >= MASK_N or zzj >= MASK_N:
					continue
				var wj := Vector2((float(xxj) + 0.5) / MASK_N * Terrain.SIZE - Terrain.SIZE * 0.5,
					(float(zzj) + 0.5) / MASK_N * Terrain.SIZE - Terrain.SIZE * 0.5)
				if wj.distance_to(j) <= 13.0:
					img.set_pixel(xxj, zzj, Color.WHITE)	# the boat launch parking apron and ramp head are paved too, so no meadow grows through the gravel
					top.set_pixel(xxj, zzj, Color(0.667, 0.667, 0.667))   # 0.20 m / 0.30 m
	var launch := CaseObjects.BOAT_LAUNCH_SPOT
	var lx := int((launch.x / Terrain.SIZE + 0.5) * MASK_N)
	var lz := int((launch.y / Terrain.SIZE + 0.5) * MASK_N)
	var lr := int(ceil(18.0 / Terrain.SIZE * MASK_N))
	for dzz in range(-lr, lr + 1):
		for dxx in range(-lr, lr + 1):
			var xx2 := lx + dxx
			var zz2 := lz + dzz
			if xx2 < 0 or zz2 < 0 or xx2 >= MASK_N or zz2 >= MASK_N:
				continue
			var wp2 := Vector2((float(xx2) + 0.5) / MASK_N * Terrain.SIZE - Terrain.SIZE * 0.5,
				(float(zz2) + 0.5) / MASK_N * Terrain.SIZE - Terrain.SIZE * 0.5)
			if wp2.distance_to(launch) <= 18.0:
				img.set_pixel(xx2, zz2, Color.WHITE)
	# the old dirt track to the cabin keeps its own grass-free corridor, but narrower than an asphalt road
	for i in CabinTrack.POINTS.size() - 1:
		var ta: Vector2 = CabinTrack.POINTS[i]
		var tb: Vector2 = CabinTrack.POINTS[i + 1]
		var tsteps := maxi(1, int(ceil(ta.distance_to(tb) / 2.0)))
		for k in tsteps:
			var tp := ta.lerp(tb, float(k) / float(tsteps))
			var tcx := int((tp.x / Terrain.SIZE + 0.5) * MASK_N)
			var tcz := int((tp.y / Terrain.SIZE + 0.5) * MASK_N)
			var tpr := int(ceil(4.5 / Terrain.SIZE * MASK_N))
			for dzz in range(-tpr, tpr + 1):
				for dxx in range(-tpr, tpr + 1):
					var txx := tcx + dxx
					var tzz := tcz + dzz
					if txx < 0 or tzz < 0 or txx >= MASK_N or tzz >= MASK_N:
						continue
					var twp := Vector2((float(txx) + 0.5) / MASK_N * Terrain.SIZE - Terrain.SIZE * 0.5,
						(float(tzz) + 0.5) / MASK_N * Terrain.SIZE - Terrain.SIZE * 0.5)
					if twp.distance_to(tp) <= 4.5:
						img.set_pixel(txx, tzz, Color.WHITE)
					if twp.distance_to(tp) <= 2.0:
						top.set_pixel(txx, tzz, Color(0.80, 0.80, 0.80))   # 0.24 m / 0.30 m
	road_mask = ImageTexture.create_from_image(img)
	_road_top_img = top
	road_top = ImageTexture.create_from_image(top)
## Rasterise the junction aprons. The asphalt shader fades the painted lines through these circles, so a centre line does
## not run straight across a T junction.
func _build_junction_mask() -> void:
	var img := Image.create(MASK_N, MASK_N, false, Image.FORMAT_L8)
	img.fill(Color(0, 0, 0, 1))
	for j in JUNCTIONS:
		var cx := int((j.x / Terrain.SIZE + 0.5) * MASK_N)
		var cz := int((j.y / Terrain.SIZE + 0.5) * MASK_N)
		var pr := int(ceil(8.5 / Terrain.SIZE * MASK_N))
		for dzz in range(-pr, pr + 1):
			for dxx in range(-pr, pr + 1):
				var xx := cx + dxx
				var zz := cz + dzz
				if xx < 0 or zz < 0 or xx >= MASK_N or zz >= MASK_N:
					continue
				var wp := Vector2((float(xx) + 0.5) / MASK_N * Terrain.SIZE - Terrain.SIZE * 0.5,
					(float(zz) + 0.5) / MASK_N * Terrain.SIZE - Terrain.SIZE * 0.5)
				if wp.distance_to(j) <= 8.5:
					img.set_pixel(xx, zz, Color.WHITE)
	junction_mask = ImageTexture.create_from_image(img)
## Rain darkens the roads and lifts a little reflection on the wheel tracks. The weather owns the value; this only
## forwards it to the asphalt and shoulder shaders when it changes.
func set_wetness(w: float) -> void:
	var v := clampf(w, 0.0, 1.0)
	if absf(v - _wetness) < 0.01:
		return
	_wetness = v
	for m in _materials:
		m.set_shader_parameter("wetness", v)

func route_ids() -> Array:
	return paths.keys()

func speed_limit(id: String) -> float:
	for r in ROUTES:
		if str(r["id"]) == id:
			return float(r.get("speed_limit", 25))
	return 25.0

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
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	# -- shoulders
	var sverts := PackedVector3Array()
	var snorms := PackedVector3Array()
	var stangents := PackedFloat32Array()
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
		# three vertices across, each on the real ground: the crown cannot bridge over a rise
		var hc := terrain.height(p.x, p.y) + 0.055
		var hl := terrain.height(p.x - side.x * half, p.y - side.y * half) + 0.055
		var hr := terrain.height(p.x + side.x * half, p.y + side.y * half) + 0.055
		var ho_l := terrain.height(p.x - side.x * outer, p.y - side.y * outer) - 0.12
		var ho_r := terrain.height(p.x + side.x * outer, p.y + side.y * outer) - 0.12
		var nc := (terrain.normal_at(p.x, p.y) + Vector3.UP * 1.6).normalized()
		var nl2 := (terrain.normal_at(p.x - side.x * half, p.y - side.y * half) + Vector3.UP * 1.6).normalized()
		var nr2 := (terrain.normal_at(p.x + side.x * half, p.y + side.y * half) + Vector3.UP * 1.6).normalized()
		var nlo := (terrain.normal_at(p.x - side.x * outer, p.y - side.y * outer) + Vector3.UP * 1.6).normalized()
		var nro := (terrain.normal_at(p.x + side.x * outer, p.y + side.y * outer) + Vector3.UP * 1.6).normalized()
		var tangent := Vector3(t.x, 0.0, t.y).normalized()
		var tc := (tangent - nc * nc.dot(tangent)).normalized()
		var tl := (tangent - nl2 * nl2.dot(tangent)).normalized()
		var tr := (tangent - nr2 * nr2.dot(tangent)).normalized()
		verts.append(Vector3(p.x - side.x * half, hl, p.y - side.y * half))
		verts.append(Vector3(p.x, hc, p.y))
		verts.append(Vector3(p.x + side.x * half, hr, p.y + side.y * half))
		norms.append(nl2); norms.append(nc); norms.append(nr2)
		for tv in [tl, tc, tr]:
			tangents.append_array([tv.x, tv.y, tv.z, 1.0])
		uvs.append(Vector2(0.0, dist / 8.0)); uvs.append(Vector2(0.5, dist / 8.0)); uvs.append(Vector2(1.0, dist / 8.0))
		sverts.append(Vector3(p.x - side.x * outer, ho_l, p.y - side.y * outer))
		sverts.append(Vector3(p.x - side.x * half, hl, p.y - side.y * half))
		sverts.append(Vector3(p.x + side.x * half, hr, p.y + side.y * half))
		sverts.append(Vector3(p.x + side.x * outer, ho_r, p.y + side.y * outer))
		snorms.append(nlo); snorms.append(nl2); snorms.append(nr2); snorms.append(nro)
		stangents.append_array([tl.x, tl.y, tl.z, 1.0, tl.x, tl.y, tl.z, 1.0,
			tr.x, tr.y, tr.z, 1.0, tr.x, tr.y, tr.z, 1.0])
		suvs.append(Vector2(0.0, dist / 4.0)); suvs.append(Vector2(1.0, dist / 4.0))
		suvs.append(Vector2(0.0, dist / 4.0)); suvs.append(Vector2(1.0, dist / 4.0))
	for i in pts.size() - 1:
		var a := i * 3
		var c := (i + 1) * 3
		idx.append_array([a, a + 1, c, a + 1, c + 1, c])
		idx.append_array([a + 1, a + 2, c + 1, a + 2, c + 2, c + 1])
		var sa := i * 4
		var sc := (i + 1) * 4
		sidx.append_array([sa, sa + 1, sc, sa + 1, sc + 1, sc])             # left shoulder
		sidx.append_array([sa + 2, sa + 3, sc + 2, sa + 3, sc + 3, sc + 2]) # right shoulder	_lengths[str(route["id"])] = dist
	var road_mesh := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TANGENT] = tangents
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	road_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/shaders/road_asphalt.gdshader")
	mat.set_shader_parameter("uAlbedo", _asphalt_diff)
	mat.set_shader_parameter("uNormal", _asphalt_nor)
	mat.set_shader_parameter("uArm", _asphalt_arm)
	mat.set_shader_parameter("uJunctionMask", junction_mask)
	var has_lines := width >= 6.5
	# markings are separate meshes at real-world dimensions, not baked into the asphalt UVs
	mat.set_shader_parameter("edge_marks", 0.0)
	mat.set_shader_parameter("center_line", 0.0)
	mat.set_shader_parameter("wetness", maxf(_wetness, 0.0))
	_materials.append(mat)
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
	sarr[Mesh.ARRAY_TANGENT] = stangents
	sarr[Mesh.ARRAY_TEX_UV] = suvs
	sarr[Mesh.ARRAY_INDEX] = sidx
	sh_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sarr)
	var smat := ShaderMaterial.new()
	smat.shader = load("res://game/shaders/road_gravel.gdshader")
	smat.set_shader_parameter("uAlbedo", _gravel_diff)
	smat.set_shader_parameter("uNormal", _gravel_nor)
	smat.set_shader_parameter("uArm", _gravel_arm)
	smat.set_shader_parameter("uJunctionMask", junction_mask)
	smat.set_shader_parameter("wetness", maxf(_wetness, 0.0))
	_materials.append(smat)
	var smi := MeshInstance3D.new()
	smi.mesh = sh_mesh
	smi.material_override = smat
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smi)
	if has_lines:
		_build_reflector_posts(pts, outer, route)
		_build_markings(route, pts, width)
	_build_skirts(pts, half)

## A short vertical face down from each asphalt edge. The shoulder already sinks into the ground, but this face hides
## any remaining sliver of daylight under the ribbon on a crest or a side slope.
func _build_skirts(pts: Array, half: float) -> void:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	for sd in [-1.0, 1.0]:
		var base := verts.size()
		for i in pts.size():
			var p: Vector2 = pts[i]
			var t := _segment_tangent(pts, i)
			var side := Vector2(-t.y, t.x) * float(sd)
			var edge := p + side * half
			var top := terrain.height(edge.x, edge.y) + 0.055
			var bottom := terrain.height(edge.x, edge.y) - 0.16
			verts.append(Vector3(edge.x, top, edge.y))
			verts.append(Vector3(edge.x, bottom, edge.y))
			norms.append(Vector3(side.x, 0.0, side.y)); norms.append(Vector3(side.x, 0.0, side.y))
		for i in pts.size() - 1:
			var a := base + i * 2
			var c := base + (i + 1) * 2
			idx.append_array([a, a + 1, c, a + 1, c + 1, c])
	var mesh := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.16, 0.15)
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
func _near_junction(p: Vector2, radius := 10.0) -> bool:
	for j in JUNCTIONS:
		if p.distance_to(j) < radius:
			return true
	return false

## Painted lines as separate meshes at real-world sizes: a 120 mm edge line and a dashed 120 mm centre line,
## lifted clear of the asphalt. They stop short of the junction aprons.
func _build_markings(_route: Dictionary, pts: Array, width: float) -> void:
	var half := width * 0.5
	var line_half := 0.06
	var edge_inset := 0.55
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	# continuous edge lines
	for sd in [-1.0, 1.0]:
		for i in pts.size() - 1:
			var p0: Vector2 = pts[i]
			var p1: Vector2 = pts[i + 1]
			if _near_junction(p0, 11.0) or _near_junction(p1, 11.0):
				continue
			var t0 := _segment_tangent(pts, i)
			var t1 := _segment_tangent(pts, i + 1)
			var s0 := Vector2(-t0.y, t0.x)
			var s1 := Vector2(-t1.y, t1.x)
			var c0 := p0 + s0 * float(sd) * (half - edge_inset)
			var c1 := p1 + s1 * float(sd) * (half - edge_inset)
			var a0 := c0 + s0 * line_half
			var b0 := c0 - s0 * line_half
			var a1 := c1 + s1 * line_half
			var b1 := c1 - s1 * line_half
			var q := _mark_quad(a0, b0, a1, b1)
			var base := verts.size()
			for qp in q:
				verts.append(qp)
				norms.append(Vector3.UP)
			idx.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
	# dashed centre line, 3 m paint and 9 m gap
	var dist := 0.0
	for i in pts.size() - 1:
		var p0: Vector2 = pts[i]
		var p1: Vector2 = pts[i + 1]
		var seg := p0.distance_to(p1)
		var mid := dist + seg * 0.5
		if fmod(mid, 12.0) < 3.0 and not _near_junction(p0, 11.0) and not _near_junction(p1, 11.0):
			var t0 := _segment_tangent(pts, i)
			var t1 := _segment_tangent(pts, i + 1)
			var s0 := Vector2(-t0.y, t0.x)
			var s1 := Vector2(-t1.y, t1.x)
			var a0 := p0 + s0 * line_half
			var b0 := p0 - s0 * line_half
			var a1 := p1 + s1 * line_half
			var b1 := p1 - s1 * line_half
			var q := _mark_quad(a0, b0, a1, b1)
			var base := verts.size()
			for qp in q:
				verts.append(qp)
				norms.append(Vector3.UP)
			idx.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
		dist += seg
	var mesh := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.88, 0.86, 0.78)
	mat.roughness = 0.62
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _segment_tangent(pts: Array, i: int) -> Vector2:
	var n := pts.size()
	if i <= 0:
		return (pts[1] - pts[0]).normalized()
	if i >= n - 1:
		return (pts[n - 1] - pts[n - 2]).normalized()
	return (pts[i + 1] - pts[i - 1]).normalized()

func _mark_quad(a0: Vector2, b0: Vector2, a1: Vector2, b1: Vector2) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in [a0, b0, a1, b1]:
		out.append(Vector3(p.x, terrain.height(p.x, p.y) + 0.10, p.y))
	return out
## A paved junction apron shaped from the approach roads themselves. Each route that reaches the junction contributes
## the two shoulder corners of its carriageway, and the hull of those corners is filled with asphalt. The route ribbons
## discard their own asphalt and shoulders inside the junction mask, so the apron is the only surface across the
## crossing: no overlapping ribbons, no roundabout disc, no spaghetti of shoulders.
func _build_junction_aprons() -> void:
	var blank_img := Image.create(2, 2, false, Image.FORMAT_L8)
	blank_img.fill(Color(0, 0, 0, 1))
	var blank := ImageTexture.create_from_image(blank_img)
	for j in JUNCTIONS:
		var corners: Array[Vector2] = []
		for id in paths:
			if float(_lengths.get(str(id), 0.0)) < 80.0:
				continue
			var pts: Array = paths[id]
			var size := _route_size(str(id))
			for i in pts.size():
				var p: Vector2 = pts[i]
				var dd := p.distance_to(j)
				if dd < 6.0 or dd > 10.0:
					continue
				var t: Vector2
				if i == 0:
					t = (pts[1] - pts[0]).normalized()
				elif i == pts.size() - 1:
					t = (pts[i] - pts[i - 1]).normalized()
				else:
					t = (pts[i + 1] - pts[i - 1]).normalized()
				var side := Vector2(-t.y, t.x)
				var hw := float(size.x) * 0.5 + 0.35
				corners.append(p + side * hw)
				corners.append(p - side * hw)
		var hull := PackedVector2Array()
		if corners.size() >= 3:
			hull = Geometry2D.convex_hull(PackedVector2Array(corners))
		if hull.size() < 3:
			# a tiny fallback for a junction with only one mapped approach
			for i in 24:
				var a := TAU * float(i) / 24.0
				hull.append(j + Vector2(cos(a), sin(a)) * 10.0)
		var center := Vector2.ZERO
		for p in hull:
			center += p
		center /= float(hull.size())
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var uvs := PackedVector2Array()
		var idx := PackedInt32Array()
		verts.append(Vector3(center.x, terrain.height(center.x, center.y) + 0.20, center.y))
		norms.append(Vector3.UP)
		uvs.append(Vector2(0.5, 0.5))
		for i in hull.size():
			var p: Vector2 = hull[i]
			verts.append(Vector3(p.x, terrain.height(p.x, p.y) + 0.18, p.y))
			norms.append(Vector3.UP)
			uvs.append((p - center) / 24.0 + Vector2(0.5, 0.5))
		for i in hull.size():
			var a2 := 1 + i
			var b2 := 1 + (i + 1) % hull.size()
			idx.append_array([0, b2, a2])
		var mesh := ArrayMesh.new()
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mat := ShaderMaterial.new()
		mat.shader = load("res://game/shaders/road_asphalt.gdshader")
		mat.set_shader_parameter("uAlbedo", _asphalt_diff)
		mat.set_shader_parameter("uNormal", _asphalt_nor)
		mat.set_shader_parameter("uArm", _asphalt_arm)
		mat.set_shader_parameter("uJunctionMask", blank)
		mat.set_shader_parameter("use_junction_mask", 0.0)
		mat.set_shader_parameter("edge_marks", 0.0)
		mat.set_shader_parameter("center_line", 0.0)
		mat.set_shader_parameter("wetness", maxf(_wetness, 0.0))
		_materials.append(mat)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

func _route_size(id: String) -> Vector2:
	for r in ROUTES:
		if str(r["id"]) == id:
			return Vector2(float(r["width"]), float(r["shoulder"]))
	return Vector2(5.0, 1.8)
## White delineator posts with red reflectors along the wider roads, every 60 m on both sides.
func _build_reflector_posts(pts: Array, outer: float, _route: Dictionary) -> void:
	var post_transforms: Array[Transform3D] = []
	var cap_transforms: Array[Transform3D] = []
	var next := 30.0
	var walked := 0.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var seg := a.distance_to(b)
		if seg < 0.01:
			continue
		while next <= walked + seg:
			var f := clampf((next - walked) / seg, 0.0, 1.0)
			var p := a.lerp(b, f)
			var dir := (b - a).normalized()
			var side := Vector2(-dir.y, dir.x)
			for sd in [-1.0, 1.0]:
				var q: Vector2 = p + side * float(sd) * (outer + 0.35)
				var y := terrain.height(q.x, q.y)
				post_transforms.append(Transform3D(Basis(), Vector3(q.x, y + 0.46, q.y)))
				cap_transforms.append(Transform3D(Basis(), Vector3(q.x, y + 0.79, q.y)))
			next += 60.0
		walked += seg
	if post_transforms.is_empty():
		return
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.10, 0.92, 0.10)
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.82, 0.80, 0.72)
	post_mat.roughness = 0.8
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = post_mesh
	mm.instance_count = post_transforms.size()
	for i in post_transforms.size():
		mm.set_instance_transform(i, post_transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = post_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(0.085, 0.11, 0.075)
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.58, 0.10, 0.07)
	cap_mat.emission_enabled = true
	cap_mat.emission = Color(0.42, 0.03, 0.02)
	cap_mat.emission_energy_multiplier = 0.6
	var cm := MultiMesh.new()
	cm.transform_format = MultiMesh.TRANSFORM_3D
	cm.mesh = cap_mesh
	cm.instance_count = cap_transforms.size()
	for i in cap_transforms.size():
		cm.set_instance_transform(i, cap_transforms[i])
	var cmi := MultiMeshInstance3D.new()
	cmi.multimesh = cm
	cmi.material_override = cap_mat
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cmi)

func stats() -> Dictionary:
	var total := 0.0
	for k in _lengths:
		total += float(_lengths[k])
	return {"routes": _lengths.size(), "km": snappedf(total / 1000.0, 0.01), "lengths": _lengths}

## The cemetery walls stand at about x/z +/-238. No road centreline may enter the 248 m square; the gates and their car
## parks sit outside it. This is a cheap guard so a future route edit cannot quietly cut through the graves again.
func audit() -> Dictionary:
	var inside := 0
	var first := Vector2.ZERO
	for id in paths:
		for p in paths[id]:
			if absf(p.x) < 238.0 and absf(p.y) < 238.0:
				inside += 1
				if inside == 1:
					first = p
	return {"inside_cemetery": inside, "first": first}

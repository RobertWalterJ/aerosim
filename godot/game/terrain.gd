class_name Terrain
extends Node3D
## The valley: the web version's baked 4 km heightmap (an overlook park on a bench above a river valley, with a wooded
## ridge), its land-cover map (woodland, mown lawn) and the distance to the park's paths, loaded from godot/assets/world
## (made by tools/export_world.ts). Near the start the mesh is fine (2 m); further out it is coarse (16 m), with a skirt so
## the edge is never a hole. The height grid stays in memory so the physics, the grass and the map can read the ground.

const SIZE := 4000.0
const N := 2049                 # height samples per side
const CELLS := 2048
const DX := SIZE / CELLS
const NEAR_HALF := 256          # near mesh covers +-256 cells (about +-500 m)
const FAR_STRIDE := 8
const PATH_SPAN := 512.0
const DIR := "res://assets/world/"

var layout := {}
var cover_tex: ImageTexture
var height_tex: ImageTexture
var path_tex: ImageTexture
var snow := 0.0 : set = set_snow
var _h := PackedFloat32Array()
var _cover: Image
var _path: Image
var _mat: ShaderMaterial

func load_world() -> void:
	var f := FileAccess.open(DIR + "layout.json", FileAccess.READ)
	layout = JSON.parse_string(f.get_as_text())
	_load_height()
	_cover = Image.load_from_file(ProjectSettings.globalize_path(DIR + "valley_cover.png"))
	_path = Image.load_from_file(ProjectSettings.globalize_path(DIR + "valley_path.png"))
	cover_tex = ImageTexture.create_from_image(_cover)
	path_tex = ImageTexture.create_from_image(_path)

func _load_height() -> void:
	var raw := FileAccess.get_file_as_bytes(DIR + "valley_height.bin")
	var bytes := raw.decompress(N * N * 2, FileAccess.COMPRESSION_DEFLATE)
	var hmin: float = layout["hmin"]
	var hmax: float = layout["hmax"]
	_h.resize(N * N)
	for i in N * N:
		_h[i] = hmin + (hmax - hmin) * float(bytes.decode_u16(i * 2)) / 65535.0
	height_tex = ImageTexture.create_from_image(Image.create_from_data(N, N, false, Image.FORMAT_RF, _h.to_byte_array()))

func build() -> void:
	var mi_near := MeshInstance3D.new()
	mi_near.mesh = _grid(N / 2 - NEAR_HALF, N / 2 + NEAR_HALF, N / 2 - NEAR_HALF, N / 2 + NEAR_HALF, 1, false)
	var mi_far := MeshInstance3D.new()
	mi_far.mesh = _grid(0, N - 1, 0, N - 1, FAR_STRIDE, true)
	var mat := _make_material()
	for mi in [mi_near, mi_far]:
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 4000.0
		add_child(mi)

## A regular grid of the height samples as one mesh. `hole` leaves out the square the near mesh covers.
func _grid(i0: int, i1: int, j0: int, j1: int, stride: int, hole: bool) -> ArrayMesh:
	var nx := (i1 - i0) / stride + 1
	var nz := (j1 - j0) / stride + 1
	var verts := PackedVector3Array(); verts.resize(nx * nz)
	var norms := PackedVector3Array(); norms.resize(nx * nz)
	for b in nz:
		for a in nx:
			var i := i0 + a * stride
			var j := j0 + b * stride
			var il := maxi(i - stride, 0)
			var ir := mini(i + stride, N - 1)
			var ju := maxi(j - stride, 0)
			var jd := mini(j + stride, N - 1)
			var hx := (_h[j * N + ir] - _h[j * N + il]) / float((ir - il) * DX)
			var hz := (_h[jd * N + i] - _h[ju * N + i]) / float((jd - ju) * DX)
			verts[b * nx + a] = Vector3(-SIZE / 2.0 + i * DX, _h[j * N + i], -SIZE / 2.0 + j * DX)
			norms[b * nx + a] = Vector3(-hx, 1.0, -hz).normalized()
	var idx := PackedInt32Array()
	var hi0 := N / 2 - NEAR_HALF
	var hi1 := N / 2 + NEAR_HALF
	for b in nz - 1:
		for a in nx - 1:
			var i := i0 + a * stride
			var j := j0 + b * stride
			if hole and i >= hi0 and i + stride <= hi1 and j >= hi0 and j + stride <= hi1: continue
			var v00 := b * nx + a
			var v10 := v00 + 1
			var v01 := v00 + nx
			var v11 := v01 + 1
			if ((a + b) & 1) == 0:
				idx.append_array([v00, v10, v01, v10, v11, v01])
			else:
				idx.append_array([v00, v11, v01, v00, v10, v11])
	# skirts: a 12 m curtain down the outer edge (and round the hole) so no gap shows where the meshes meet
	var edge := PackedInt32Array()
	for a in nx: edge.append(a)
	for b in range(1, nz): edge.append(b * nx + nx - 1)
	for a in range(nx - 2, -1, -1): edge.append((nz - 1) * nx + a)
	for b in range(nz - 2, 0, -1): edge.append(b * nx)
	edge.append(edge[0])
	_curtain(verts, norms, idx, edge)
	if hole:
		var a0 := (hi0 - i0) / stride
		var a1 := (hi1 - i0) / stride
		var hedge := PackedInt32Array()
		for a in range(a0, a1 + 1): hedge.append(a0 * nx + a)
		for b in range(a0 + 1, a1 + 1): hedge.append(b * nx + a1)
		for a in range(a1 - 1, a0 - 1, -1): hedge.append(a1 * nx + a)
		for b in range(a1 - 1, a0, -1): hedge.append(b * nx + a0)
		hedge.append(hedge[0])
		_curtain(verts, norms, idx, hedge)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _curtain(verts: PackedVector3Array, norms: PackedVector3Array, idx: PackedInt32Array, edge: PackedInt32Array) -> void:
	var base := verts.size()
	for e in edge:
		verts.append(verts[e] + Vector3(0, -12, 0)); norms.append(norms[e])
	for k in edge.size() - 1:
		var s0 := base + k
		idx.append_array([edge[k], edge[k + 1], s0, edge[k + 1], s0 + 1, s0])

# ------------------------------------------------------------------ queries
## Ground height in metres at (x, z), bilinear on the grid.
func height(x: float, z: float) -> float:
	var fx := clampf((x + SIZE / 2.0) / DX, 0.0, N - 1.001)
	var fz := clampf((z + SIZE / 2.0) / DX, 0.0, N - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var a := _h[j * N + i]
	var b := _h[j * N + i + 1]
	var c := _h[(j + 1) * N + i]
	var d := _h[(j + 1) * N + i + 1]
	return a + (b - a) * tx + (c - a) * tz + (a - b - c + d) * tx * tz

func normal_at(x: float, z: float) -> Vector3:
	var e := DX
	var dx := height(x + e, z) - height(x - e, z)
	var dz := height(x, z + e) - height(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()

## Land cover at a point: x woodland, y mown lawn (both 0..1).
func cover_at(x: float, z: float) -> Vector2:
	var i := clampi(int((x + SIZE / 2.0) / SIZE * _cover.get_width()), 0, _cover.get_width() - 1)
	var j := clampi(int((z + SIZE / 2.0) / SIZE * _cover.get_height()), 0, _cover.get_height() - 1)
	var c := _cover.get_pixel(i, j)
	return Vector2(c.r, c.b)

## Distance in metres to the nearest path (99 outside the mapped park).
func dist_to_path(x: float, z: float) -> float:
	var u := (x + PATH_SPAN / 2.0) / PATH_SPAN
	var v := (z + PATH_SPAN / 2.0) / PATH_SPAN
	if u < 0.0 or v < 0.0 or u >= 1.0 or v >= 1.0: return 99.0
	return _path.get_pixel(int(u * _path.get_width()), int(v * _path.get_height())).r * 8.0

# ------------------------------------------------------------------ look
func _make_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://game/shaders/ground.gdshader")
	var tex := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.frequency = 0.04
	fn.fractal_octaves = 4
	tex.noise = fn
	tex.width = 512; tex.height = 512
	tex.seamless = true
	tex.generate_mipmaps = true
	m.set_shader_parameter("uDetail", tex)
	var ntex := NoiseTexture2D.new()
	ntex.noise = fn
	ntex.width = 512; ntex.height = 512
	ntex.seamless = true
	ntex.as_normal_map = true
	ntex.bump_strength = 4.0
	m.set_shader_parameter("uDetailN", ntex)
	m.set_shader_parameter("uCover", cover_tex)
	m.set_shader_parameter("uPath", path_tex)
	m.set_shader_parameter("uSize", SIZE)
	m.set_shader_parameter("uAsphalt", load("res://assets/textures/path_diff.jpg"))
	m.set_shader_parameter("uAsphaltN", load("res://assets/textures/path_nor.jpg"))
	m.set_shader_parameter("uAsphaltARM", load("res://assets/textures/path_arm.jpg"))
	_mat = m
	return m

func set_snow(v: float) -> void:
	snow = v
	RenderingServer.global_shader_parameter_set("g_snow", v)

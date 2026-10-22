class_name Terrain
extends Node3D
## A rolling valley made from noise. The height grid is kept so the physics can ask for the ground height and slope.
## A flat take-off pad around the origin keeps the start clear.

const SIZE := 1600.0            # metres across
const CELLS := 320              # grid squares along each side (5 m)
const PAD_R := 14.0             # flat pad radius around the origin
const PAD_BLEND := 30.0

var _h := PackedFloat32Array()
var _noise := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var snow := 0.0 : set = set_snow
var _mat: ShaderMaterial
var _origin_h := 12.0
var cover_tex: ImageTexture
var height_tex: ImageTexture
var lawn_rects: Array = []   # [{c: Vector2, half: Vector2}] extra mown areas, set before build()
var _forest := FastNoiseLite.new()
var _rag := FastNoiseLite.new()
var _flats: Array = []   # [{c: Vector2, half: Vector2, blend: float, h: float}]

func _init() -> void:
	_forest.seed = 31; _forest.frequency = 0.004
	_rag.seed = 19; _rag.frequency = 0.02
	_noise.seed = 2024
	_noise.frequency = 0.0022
	_noise.fractal_octaves = 5
	_ridge.seed = 77
	_ridge.frequency = 0.0009
	_ridge.fractal_octaves = 3

func raw_height(x: float, z: float) -> float:
	var d := sqrt(x * x + z * z)
	var base := _noise.get_noise_2d(x, z) * 16.0 + _ridge.get_noise_2d(x + 300.0, z - 120.0) * 26.0 + 12.0
	# rise gently towards the valley walls so the horizon is not a flat edge
	base += pow(clampf((d - 250.0) / 550.0, 0.0, 1.5), 2.0) * 60.0
	var pad := smoothstep(PAD_R, PAD_R + PAD_BLEND, d)
	var h := lerpf(_origin_h, base, pad)
	for f in _flats:
		var q: Vector2 = (Vector2(x, z) - f["c"]).abs() - f["half"]
		var out := maxf(q.x, q.y)   # distance outside the rectangle (box approximation)
		h = lerpf(f["h"], h, smoothstep(0.0, f["blend"], out))
	return h

## Level a rectangle of ground (for the cemetery) before build(). Returns the level used.
func add_flat_rect(centre: Vector2, half: Vector2, blend: float) -> float:
	var h := raw_height(centre.x, centre.y)
	_flats.append({"c": centre, "half": half, "blend": blend, "h": h})
	return h

## How much woodland (0..1) there should be at a point: drives both where trees stand and the woodland floor.
func forest_want(x: float, z: float) -> float:
	var d := sqrt(x * x + z * z)
	var dens := _forest.get_noise_2d(x, z) * 0.5 + 0.5
	return smoothstep(0.32, 0.7, dens) * (0.35 + 0.65 * smoothstep(60.0, 320.0, d))

## Mown lawn amount (0..1): the park around the start and the land around any lawn rectangle, with a ragged edge.
func mown(x: float, z: float) -> float:
	var d := sqrt(x * x + z * z)
	var m := 1.0 - smoothstep(55.0, 130.0, d)
	for r in lawn_rects:
		var q: Vector2 = (Vector2(x, z) - r["c"]).abs() - r["half"]
		m = maxf(m, 1.0 - smoothstep(0.0, 45.0, maxf(q.x, q.y)))
	return clampf(m + (_rag.get_noise_2d(x, z)) * 0.4 * minf(m * 2.0, 1.0), 0.0, 1.0)

func build() -> void:
	_origin_h = _noise.get_noise_2d(0.0, 0.0) * 16.0 + _ridge.get_noise_2d(300.0, -120.0) * 26.0 + 12.0
	var n1 := CELLS + 1
	_h.resize(n1 * n1)
	for j in n1:
		for i in n1:
			_h[j * n1 + i] = raw_height(-SIZE / 2.0 + i * SIZE / CELLS, -SIZE / 2.0 + j * SIZE / CELLS)
	var step := SIZE / CELLS
	var verts := PackedVector3Array(); verts.resize(n1 * n1)
	var norms := PackedVector3Array(); norms.resize(n1 * n1)
	var cols := PackedColorArray(); cols.resize(n1 * n1)
	for j in n1:
		for i in n1:
			var x := -SIZE / 2.0 + i * step
			var z := -SIZE / 2.0 + j * step
			var y := _h[j * n1 + i]
			var hx0 := _h[j * n1 + maxi(i - 1, 0)]
			var hx1 := _h[j * n1 + mini(i + 1, CELLS)]
			var hz0 := _h[maxi(j - 1, 0) * n1 + i]
			var hz1 := _h[mini(j + 1, CELLS) * n1 + i]
			var nrm := Vector3(hx0 - hx1, 2.0 * step, hz0 - hz1).normalized()
			verts[j * n1 + i] = Vector3(x, y, z)
			norms[j * n1 + i] = nrm
			cols[j * n1 + i] = _color_at(x, z, y, nrm)
	var idx := PackedInt32Array(); idx.resize(CELLS * CELLS * 6)
	var k := 0
	for j in CELLS:
		for i in CELLS:
			var a := j * n1 + i
			var b := a + 1
			var c := a + n1
			var d := c + 1
			idx[k] = a; idx[k + 1] = b; idx[k + 2] = c
			idx[k + 3] = b; idx[k + 4] = d; idx[k + 5] = c
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_build_cover_textures()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _make_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func h_grid(i: int, j: int) -> float:
	return _h[j * (CELLS + 1) + i]

## Ground height in metres at (x, z), bilinear on the grid.
func height(x: float, z: float) -> float:
	var fx := (x + SIZE / 2.0) / SIZE * CELLS
	var fz := (z + SIZE / 2.0) / SIZE * CELLS
	if fx < 0.0 or fz < 0.0 or fx >= CELLS or fz >= CELLS:
		return raw_height(x, z)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var a := h_grid(i, j)
	var b := h_grid(i + 1, j)
	var c := h_grid(i, j + 1)
	var d := h_grid(i + 1, j + 1)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)

func normal_at(x: float, z: float) -> Vector3:
	var e := SIZE / CELLS
	var dx := height(x + e, z) - height(x - e, z)
	var dz := height(x, z + e) - height(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()

func _color_at(x: float, z: float, y: float, n: Vector3) -> Color:
	var slope := 1.0 - n.y
	var grass := Color(0.34, 0.42, 0.12).lerp(Color(0.46, 0.48, 0.16), clampf(_noise.get_noise_2d(x * 3.0, z * 3.0) * 0.5 + 0.5, 0.0, 1.0))
	var rock := Color(0.40, 0.38, 0.34)
	var c := grass.lerp(rock, smoothstep(0.12, 0.35, slope))
	c = c.lerp(Color(0.55, 0.5, 0.35), smoothstep(60.0, 110.0, y) * 0.5)   # dry upland
	return c * 0.75

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
	m.set_shader_parameter("uSize", SIZE)
	_mat = m
	return m

func set_snow(v: float) -> void:
	snow = v
	RenderingServer.global_shader_parameter_set("g_snow", v)

## Ground data for the shaders: the height grid (for placing grass blades) and the cover map (woodland, mown lawn).
func _build_cover_textures() -> void:
	var n := CELLS + 1
	var hb := PackedFloat32Array(); hb.resize(n * n)
	for i in n * n: hb[i] = _h[i]
	height_tex = ImageTexture.create_from_image(Image.create_from_data(n, n, false, Image.FORMAT_RF, hb.to_byte_array()))
	var cs := 512
	var img := Image.create(cs, cs, false, Image.FORMAT_RGB8)
	for j in cs:
		for i in cs:
			var x := ((i + 0.5) / cs - 0.5) * SIZE
			var z := ((j + 0.5) / cs - 0.5) * SIZE
			var f := clampf(forest_want(x, z) * 1.3, 0.0, 1.0)
			var m := mown(x, z) * (1.0 - f)
			img.set_pixel(i, j, Color(f, 0.0, m))
	cover_tex = ImageTexture.create_from_image(img)

## Cover at a point: x woodland, z mown lawn (the same data the shaders read).
func cover_at(x: float, z: float) -> Vector2:
	var f := clampf(forest_want(x, z) * 1.3, 0.0, 1.0)
	return Vector2(f, mown(x, z) * (1.0 - f))

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

func _init() -> void:
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
	return lerpf(_origin_h, base, pad)

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
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_lambert;
uniform sampler2D detail : source_color, repeat_enable, filter_linear_mipmap;
uniform float snow = 0.0;
varying vec3 wpos;
varying vec3 wnormal;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wnormal = NORMAL; }
void fragment() {
	vec3 d1 = texture(detail, wpos.xz * 0.35).rgb;
	vec3 d2 = texture(detail, wpos.xz * 0.04).rgb;
	vec3 base = COLOR.rgb * (0.55 + 0.9 * d1.r) * (0.75 + 0.5 * d2.r);
	// snow settles on flat ground in uneven drifts
	float drift = smoothstep(0.2, 0.8, d2.g + 0.3 * d1.g);
	float cover = snow * smoothstep(0.55, 0.9, wnormal.y) * mix(0.7, 1.0, drift);
	base = mix(base, vec3(0.62, 0.66, 0.74), cover);
	ALBEDO = base;
	ROUGHNESS = mix(0.95, 0.7, cover);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var tex := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.frequency = 0.04
	fn.fractal_octaves = 4
	tex.noise = fn
	tex.width = 512; tex.height = 512
	tex.seamless = true
	tex.generate_mipmaps = true
	m.set_shader_parameter("detail", tex)
	_mat = m
	return m

func set_snow(v: float) -> void:
	snow = v
	if _mat: _mat.set_shader_parameter("snow", v)

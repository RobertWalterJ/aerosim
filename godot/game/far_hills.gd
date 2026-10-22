class_name FarHills
extends MeshInstance3D
## The land beyond the edge of the modelled valley: a ring of rolling hills that rises from the valley's own edge height out to
## the far horizon, tinted bluer and paler with distance, so the view ends in hills and not in a blank band.

const R_IN := 1400.0
const R_OUT := 22000.0
const RINGS := 70
const SEGS := 256
const HALF := 1990.0

static func _hash(x: float, y: float) -> float:
	return fposmod(sin(x * 127.1 + y * 311.7) * 43758.5453, 1.0)

static func _noise(x: float, y: float) -> float:
	var ix := floorf(x); var iy := floorf(y)
	var fx := x - ix; var fy := y - iy
	fx = fx * fx * (3.0 - 2.0 * fx); fy = fy * fy * (3.0 - 2.0 * fy)
	return lerpf(lerpf(_hash(ix, iy), _hash(ix + 1, iy), fx), lerpf(_hash(ix, iy + 1), _hash(ix + 1, iy + 1), fx), fy)

static func _fbm(x: float, y: float) -> float:
	var s := 0.0; var a := 0.5
	for i in 5:
		s += a * _noise(x, y); x = x * 2.03 + 17.1; y = y * 2.03 + 5.3; a *= 0.5
	return s

func build(terrain: Terrain) -> void:
	var verts := PackedVector3Array(); var cols := PackedColorArray(); var idx := PackedInt32Array()
	var edge_h := PackedFloat32Array()
	for k in SEGS:
		var a := TAU * k / SEGS
		var ex := clampf(cos(a) * 3000.0, -HALF, HALF); var ez := clampf(sin(a) * 3000.0, -HALF, HALF)
		edge_h.append(terrain.height(ex, ez))
	for i in RINGS + 1:
		var t := float(i) / RINGS
		var r := R_IN * pow(R_OUT / R_IN, t)
		for k in SEGS + 1:
			var kk := k % SEGS
			var a := TAU * kk / SEGS
			var x := cos(a) * r; var z := sin(a) * r
			var inside := absf(x) < HALF and absf(z) < HALF
			var y: float
			var d := clampf((r - 2300.0) / 14000.0, 0.0, 1.0)
			var eh := edge_h[kk]
			if inside:
				y = terrain.height(x, z) - 6.0          # hidden under the real land
			else:
				var ex := clampf(x, -HALF, HALF); var ez := clampf(z, -HALF, HALF)
				var base := terrain.height(ex, ez)
				var hills := (_fbm(x * 0.00035 + 3.0, z * 0.00035) - 0.3) * 900.0 * smoothstep(0.0, 0.5, d) + (_fbm(x * 0.0017, z * 0.0017) - 0.5) * 120.0
				y = base + (hills + 160.0 * d) * smoothstep(0.0, 0.35, d) - 4.0 * (1.0 - smoothstep(0.0, 0.1, d))
				y = maxf(y, 20.0)
			verts.append(Vector3(x, y, z))
			var haze := smoothstep(0.0, 0.8, d)
			var near_c := Color(0.30, 0.36, 0.20).lerp(Color(0.42, 0.30, 0.16), _noise(x * 0.0006, z * 0.0006))
			cols.append(near_c.lerp(Color(0.50, 0.60, 0.72), haze))
	for i in RINGS:
		for k in SEGS:
			var a := i * (SEGS + 1) + k
			var b := a + SEGS + 1
			idx.append_array([a, a + 1, b, a + 1, b + 1, b])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts; arrays[Mesh.ARRAY_COLOR] = cols; arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = m
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-R_OUT, -50, -R_OUT), Vector3(R_OUT * 2.0, 1500, R_OUT * 2.0))

class_name FarHills
extends MeshInstance3D
## The land beyond the edge of the modelled valley: a ring of hills that rises from the valley's own edge height out to
## the far horizon. Rolling country near the valley, then three or four layered ridges, each further one higher and
## paler. Slopes and crests carry forest (dark conifer mixed with warm autumn broadleaf), the gentler ground is a
## patchwork of fields with hedgerow lines (shaders/far_hills.gdshader). Forested ground is raised by a canopy layer
## so ridge lines are ragged, and a few thousand low-poly trees stand along the nearer crests to break the skyline.
## Aerial perspective: the shader fades towards the global haze colour g_haze (rgb, a = strength), which this node
## copies from the environment's fog colour every frame, so the hills match the fog and sky at any hour and weather.

const R_IN := 1400.0
const R_OUT := 22000.0
const RINGS := 76
const SEGS := 320
const HALF := 1990.0
## Ridge ranges beyond the valley: [radius m, width m, height m, seed]
const RANGES := [[3700.0, 450.0, 115.0, 1.0], [6400.0, 750.0, 175.0, 2.0], [10500.0, 1300.0, 260.0, 3.0], [16500.0, 2100.0, 340.0, 4.0]]
const CANOPY_H := 16.0           # the forest canopy stands this far above the ground under it

var _tree_mats: Array[ShaderMaterial] = []

static func _hash(x: float, y: float) -> float:
	return fposmod(sin(x * 127.1 + y * 311.7) * 43758.5453, 1.0)

static func _noise(x: float, y: float) -> float:
	var ix := floorf(x); var iy := floorf(y)
	var fx := x - ix; var fy := y - iy
	fx = fx * fx * (3.0 - 2.0 * fx); fy = fy * fy * (3.0 - 2.0 * fy)
	return lerpf(lerpf(_hash(ix, iy), _hash(ix + 1, iy), fx), lerpf(_hash(ix, iy + 1), _hash(ix + 1, iy + 1), fx), fy)

static func _fbm(x: float, y: float, oct := 5) -> float:
	var s := 0.0; var a := 0.5
	for i in oct:
		s += a * _noise(x, y); x = x * 2.03 + 17.1; y = y * 2.03 + 5.3; a *= 0.5
	return s

## A ridged noise: sharp crests, rounded hollows.
static func _ridged(x: float, y: float) -> float:
	var s := 0.0; var a := 0.55
	for i in 4:
		var n := 1.0 - absf(2.0 * _noise(x, y) - 1.0)
		s += a * n * n; x = x * 2.1 + 31.7; y = y * 2.1 + 11.3; a *= 0.5
	return s

## Ground height of the hills (without the forest canopy) at a point outside the valley square.
static func _ground(x: float, z: float, base: float) -> float:
	var r := sqrt(x * x + z * z)
	var a := atan2(z, x)
	var d := clampf((r - 2300.0) / 14000.0, 0.0, 1.0)
	var y := base
	y += (_fbm(x * 0.00035 + 3.0, z * 0.00035) - 0.3) * 520.0 * smoothstep(0.0, 0.5, d) + (_fbm(x * 0.0017, z * 0.0017) - 0.5) * 90.0
	y += 120.0 * d
	for rg in RANGES:
		var R: float = rg[0]; var W: float = rg[1]; var H: float = rg[2]; var sd: float = rg[3]
		var rr := R * (1.0 + 0.07 * sin(a * 3.0 + sd * 1.7) + 0.04 * sin(a * 7.0 + sd))
		var prof := exp(-pow((r - rr) / W, 2.0))
		if prof < 0.01: continue
		var cx := cos(a) * R * 0.0011; var cz := sin(a) * R * 0.0011
		var crest := lerpf(_fbm(cx * 0.8 + sd * 7.0, cz * 0.8, 4), _ridged(cx + sd * 13.0, cz + sd * 5.0), 0.45)   # rounded hills with the odd sharper crest
		var gap := smoothstep(0.25, 0.55, _fbm(cx * 0.35 + sd * 3.0, cz * 0.35))      # ranges break into separate hills
		y += H * prof * (0.25 + 1.2 * crest) * (0.35 + 0.65 * gap)
	# ease up from the valley's own edge so there is no step where the real terrain ends
	return lerpf(base - 4.0, y, smoothstep(0.0, 0.12, d))

func build(terrain: Terrain) -> void:
	GroundDetail.dress(terrain)     # the ground shader's extra maps (canopy, desire lines, path edges): see ground_detail.gd
	if not _haze_added:
		_haze_added = true
		RenderingServer.global_shader_parameter_add("g_haze", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.62, 0.70, 0.80, 1.0))
	var verts := PackedVector3Array(); var cols := PackedColorArray(); var idx := PackedInt32Array()
	var edge_h := PackedFloat32Array()
	for k in SEGS:
		var a := TAU * k / SEGS
		var ex := clampf(cos(a) * 3000.0, -HALF, HALF); var ez := clampf(sin(a) * 3000.0, -HALF, HALF)
		edge_h.append(terrain.height(ex, ez))
	var W := SEGS + 1
	var ground := PackedFloat32Array()
	var inside_v := PackedByteArray()
	for i in RINGS + 1:
		var t := float(i) / RINGS
		var r := R_IN * pow(R_OUT / R_IN, t)
		for k in SEGS + 1:
			var kk := k % SEGS
			var a := TAU * kk / SEGS
			var x := cos(a) * r; var z := sin(a) * r
			var inside := absf(x) < HALF and absf(z) < HALF
			var y: float
			if inside:
				y = terrain.height(x, z) - 6.0          # hidden under the real land
			else:
				var ex := clampf(x, -HALF, HALF); var ez := clampf(z, -HALF, HALF)
				var base := terrain.height(ex, ez)
				# blend the edge height round the ring with the true height at the nearest edge point
				y = maxf(_ground(x, z, lerpf(base, edge_h[kk], 0.3)), 20.0)
			verts.append(Vector3(x, y, z)); ground.append(y); inside_v.append(1 if inside else 0)
	# forest where the ground is steep or high, fields on the gentle ground; conifers mostly up high
	for i in RINGS + 1:
		for k in SEGS + 1:
			var o := i * W + k
			var p := verts[o]
			var steep := 0.0
			if i > 0 and i < RINGS:
				var dr := verts[o + W].distance_to(verts[o - W])
				steep = absf(ground[o + W] - ground[o - W]) / maxf(dr, 1.0)
			var crest := 0.0
			if i > 0 and i < RINGS: crest = clampf((ground[o] - 0.5 * (ground[o + W] + ground[o - W])) / 30.0, 0.0, 1.0)
			var f := _fbm(p.x * 0.0008 + 40.0, p.z * 0.0008, 4)
			var forest := clampf(smoothstep(0.42, 0.62, f) + steep * 2.2 + crest * 0.5, 0.0, 1.0)
			var r := Vector2(p.x, p.z).length()
			forest = lerpf(forest, 0.75, smoothstep(9000.0, 18000.0, r))      # far ranges read as wooded
			var conifer := clampf(_fbm(p.x * 0.0006 + 9.0, p.z * 0.0006 + 2.0, 3) - 0.45 + (p.y - 200.0) / 900.0, 0.0, 1.0)
			cols.append(Color(forest, conifer, crest, 1.0))
			if inside_v[o] == 0:
				verts[o].y += CANOPY_H * smoothstep(0.45, 0.7, forest) * (0.75 + 0.5 * _noise(p.x * 0.02, p.z * 0.02))
	var nrm := PackedVector3Array(); nrm.resize(verts.size())
	for i in RINGS + 1:
		for k in SEGS + 1:
			var o := i * W + k
			var kp := k - 1 if k > 0 else SEGS - 1
			var kn := k + 1 if k < SEGS else 1
			var ip := maxi(i - 1, 0); var inn := mini(i + 1, RINGS)
			var tu := verts[i * W + kn] - verts[i * W + kp]
			var tv := verts[inn * W + k] - verts[ip * W + k]
			var n := tv.cross(tu).normalized()
			if n.y < 0.0: n = -n
			nrm[o] = n
	for i in RINGS:
		for k in SEGS:
			var a := i * W + k
			var b := a + W
			idx.append_array([a, a + 1, b, a + 1, b + 1, b])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts; arrays[Mesh.ARRAY_NORMAL] = nrm; arrays[Mesh.ARRAY_COLOR] = cols; arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = m
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/shaders/far_hills.gdshader")
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-R_OUT, -50, -R_OUT), Vector3(R_OUT * 2.0, 2500, R_OUT * 2.0))
	_crest_trees(verts, cols, inside_v, terrain.layout)

static var _haze_added := false

## Low-poly trees along the nearer forested crests and forest edges, so the skyline is ragged with crowns.
func _crest_trees(verts: PackedVector3Array, cols: PackedColorArray, inside_v: PackedByteArray, layout: Dictionary) -> void:
	var budget := 1200 if OS.has_feature("mobile") else 4500     # phones get fewer (touch laptops keep the full set)
	var rng := RandomNumberGenerator.new(); rng.seed = 4242
	var W := SEGS + 1
	var xfs := {"conifer": [] as Array[Transform3D], "broadleaf": [] as Array[Transform3D]}
	var tint := {"conifer": [] as Array[Color], "broadleaf": [] as Array[Color]}
	var placed := 0
	# the same colour variants the valley's own far trees use (layout farTrees: x y z rot sxz sy r g b)
	var palette := {"conifer": [], "broadleaf": []}
	for src in [["conifer", "conifer"], ["broad", "broadleaf"]]:
		var arr: Array = layout["farTrees"][src[0]]
		for q in range(0, arr.size() / 9, 97):
			palette[src[1]].append(Color(arr[q * 9 + 6], arr[q * 9 + 7], arr[q * 9 + 8]))
	var ring_max := 0
	for i in RINGS:
		if R_IN * pow(R_OUT / R_IN, float(i) / RINGS) > 6500.0: break
		ring_max = i
	# candidate quads: forested, on a crest or at a forest edge, outside the valley square
	var cands: Array = []
	for i in range(1, ring_max):
		for k in SEGS:
			var o := i * W + k
			if inside_v[o] == 1 or inside_v[o + 1] == 1 or inside_v[o + W] == 1 or inside_v[o + W + 1] == 1: continue
			var c := cols[o]
			if c.r < 0.5: continue
			var edge := absf(cols[o + W].r - cols[o - W].r) + absf(cols[o + 1].r - c.r)
			var w := c.b * 2.0 + edge * 1.5 + 0.08
			cands.append([w, i, k])
	cands.sort_custom(func(p: Array, q: Array) -> bool: return p[0] > q[0])
	for cd in cands:
		if placed >= budget: break
		var i: int = cd[1]; var k: int = cd[2]
		var o := i * W + k
		var A := verts[o]; var A1 := verts[o + 1]; var B := verts[o + W]; var B1 := verts[o + W + 1]
		var n := mini(6, 2 + int(cd[0] * 3.0))
		for j in n:
			var u := rng.randf(); var v := rng.randf()
			var p: Vector3
			if u + v <= 1.0: p = A + (A1 - A) * u + (B - A) * v
			else: p = B1 + (B - B1) * (1.0 - u) + (A1 - B1) * (1.0 - v)
			p.y -= CANOPY_H * 0.55       # stand on the ground under the raised canopy, crowns poking through it
			var con := cols[o].g + rng.randf_range(-0.25, 0.25) > 0.5
			var kind := "conifer" if con else "broadleaf"
			var s := rng.randf_range(1.6, 2.6)
			xfs[kind].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.25), s)), p))
			var pal: Array = palette[kind]
			tint[kind].append(pal[rng.randi() % pal.size()] if not pal.is_empty() else Color.WHITE)
			placed += 1
	var sh := load("res://game/shaders/far_tree.gdshader") as Shader
	for kind in xfs:
		var list: Array[Transform3D] = xfs[kind]
		if list.is_empty(): continue
		for part in Assets.parts("trees/far_%s" % kind):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = part["mesh"]
			mm.instance_count = list.size()
			for q in list.size():
				mm.set_instance_transform(q, list[q] * (part["xf"] as Transform3D))
				mm.set_instance_color(q, tint[kind][q])
			var mi := MultiMeshInstance3D.new()
			mi.multimesh = mm
			var tm := ShaderMaterial.new(); tm.shader = sh
			# the colours Assets._tint_far gives the valley's far trees
			tm.set_shader_parameter("uTint", Vector3(0.55, 0.34, 0.13) if kind == "broadleaf" else Vector3(0.15, 0.27, 0.13))
			mi.material_override = tm
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
	print("far hills: %d crest trees" % placed)

func _process(_delta: float) -> void:
	# keep the haze in step with the environment's fog colour (it follows time of day and weather)
	var e = get_parent().get("env")
	if e is Environment:
		var c: Color = (e as Environment).fog_light_color
		RenderingServer.global_shader_parameter_set("g_haze", Vector4(c.r, c.g, c.b, 1.0))

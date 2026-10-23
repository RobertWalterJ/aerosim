class_name NewModels2
extends RefCounted
## The second batch of models drawn by code with the DroneParts kit: a red gambrel barn and a silo, a Dutch tower windmill and a
## farm wind pump, a freight train and its track, a rescue helicopter and a far airliner, kites and a flag, and storm debris
## with the funnel tubes for the tornado and waterspout shaders.
## Real metres. Forward is -z, up is +y, x is right. The contract (what each function returns) is game/README-models.md.
## Each model is one mesh per material and is kept once made. Colour variation (boards, bricks, stones, paint) is vertex
## colour, set face by face so patches stay crisp; the barn and silo instead carry photographed CC0 textures through
## game/shaders/farm.gdshader (farm_material), with the vertex colour choosing the paint or tint of each face. Moving parts
## (sails, rotors, train wheelsets) are separate meshes with a pivot.

static var _cache := {}
static var _mats := {}

# ================================================================== materials
## Shared materials. All but glass and lamp take their colour from the mesh.
static func _mat(key: String) -> StandardMaterial3D:
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	if key != "glass" and key != "lamp":
		m.vertex_color_use_as_albedo = true; m.vertex_color_is_srgb = true
	match key:
		"paint": m.roughness = 0.85; m.metallic_specular = 0.35        # boards, brick, stone, concrete, timber
		"gloss": m.roughness = 0.3                                      # vehicle paint
		"sheet": m.roughness = 0.5; m.metallic = 0.35                   # galvanised and painted steel
		"sheet2": m.roughness = 0.5; m.metallic = 0.35; m.cull_mode = BaseMaterial3D.CULL_DISABLED   # single sheets (pump blades)
		"cloth": m.roughness = 0.7; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"glass": m.albedo_color = Color(0.03, 0.04, 0.06); m.roughness = 0.06; m.metallic = 0.85
		"lamp": m.albedo_color = Color(1.0, 0.95, 0.8); m.emission_enabled = true; m.emission = Color(1.0, 0.93, 0.75); m.emission_energy_multiplier = 2.0
	_mats[key] = m
	return m

## The textured farm-building materials (game/shaders/farm.gdshader): photographed CC0 sets at real size, with rain, snow
## and the cloud and drone shadows. The vertex colour picks the finish (see the shader). key:
##   "wood"     painted boards (barn red, white trim); alpha 0 leaves the boards bare grey
##   "roof"     corrugated galvanised steel on flat faces, corrugations from eave to ridge (also dark ironwork)
##   "stone"    fieldstone (the project's rubble set)
##   "concrete" concrete staves wrapped round the silo
##   "galv"     galvanised steel wrapped round the silo (dome, chute, pipe)
static func farm_material(key: String) -> ShaderMaterial:
	var mk := "farm_" + key
	if _mats.has(mk): return _mats[mk]
	var m := ShaderMaterial.new()
	m.shader = load("res://game/shaders/farm.gdshader") as Shader
	# set name, kind, projection, metres per repeat (across, up), tint gain, metal, normal strength
	var spec: Array = ["barnwood", 0, 0, Vector2(1.5, 1.5), 1.0, 0.0, 1.0]
	match key:
		"roof": spec = ["roofsteel", 1, 0, Vector2(1.12, 1.12), 2.7, 0.35, 1.0]
		"stone": spec = ["rubble", 2, 0, Vector2(2.4, 2.4), 2.0, 0.0, 1.0]
		"concrete": spec = ["silocrete", 3, 1, Vector2(1.5, 1.0), 2.3, 0.0, 0.8]
		"galv": spec = ["roofsteel", 1, 1, Vector2(1.12, 1.12), 2.0, 0.35, 0.7]
	m.set_shader_parameter("set_albedo", load("res://assets/textures/%s_diff.jpg" % spec[0]))
	m.set_shader_parameter("set_normal", load("res://assets/textures/%s_nor.jpg" % spec[0]))
	m.set_shader_parameter("set_arm", load("res://assets/textures/%s_arm.jpg" % spec[0]))
	m.set_shader_parameter("kind", spec[1])
	m.set_shader_parameter("proj", spec[2])
	m.set_shader_parameter("set_metres", spec[3])
	m.set_shader_parameter("tint_gain", spec[4])
	m.set_shader_parameter("metal_amt", spec[5])
	m.set_shader_parameter("normal_amt", spec[6])
	m.set_shader_parameter("cyl_radius", 2.5 if key == "concrete" else 2.6)
	_mats[mk] = m
	return m

# ================================================================== helpers
## Flat-shaded triangles with one colour per face, for parts drawn quad by quad (walls, roofs, panels).
class Buf:
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var cols := PackedColorArray()

	func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, n: Vector3) -> void:
		DroneParts._tri(pos, nrm, cols, a, b, c, n, n, n, col, col, col)

	## A quad a-b-c-d (in order round its edge) facing n.
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, n: Vector3) -> void:
		tri(a, b, c, col, n); tri(a, c, d, col, n)

	func data() -> Array:
		return [pos, nrm, cols]

## A square-section bar from a to b, w across and h deep; the h side faces `up`. ext lengthens both ends (for mitred frames).
static func _beam(a: Vector3, b: Vector3, w: float, h: float, up := Vector3.UP, ext := 0.0) -> Array:
	var z := (b - a).normalized()
	var x := up.cross(z)
	if x.length_squared() < 1e-8: x = Vector3.RIGHT.cross(z) if absf(z.x) < 0.9 else Vector3.FORWARD.cross(z)
	x = x.normalized()
	var y := z.cross(x)
	return DroneParts._apply(NewModels._box(Vector3(w, h, a.distance_to(b) + 2.0 * ext)), Transform3D(Basis(x, y, z), (a + b) * 0.5))

## Two triangle lists ([pos, nrm] or [pos, nrm, cols]) joined into one.
static func _join(a: Array, b: Array) -> Array:
	var p: PackedVector3Array = (a[0] as PackedVector3Array).duplicate(); p.append_array(b[0])
	var n: PackedVector3Array = (a[1] as PackedVector3Array).duplicate(); n.append_array(b[1])
	return [p, n]

## A flat polygon (convex, points in order) as a fan, facing n.
static func _fan(b: Buf, pts: Array, n: Vector3, col: Color) -> void:
	var c := Vector3.ZERO
	for p: Vector3 in pts: c += p
	c /= pts.size()
	for k in pts.size():
		b.tri(c, pts[k], pts[(k + 1) % pts.size()], col, n)

## The colour of a face picked by a cell number, so both triangles of a quad agree.
static func _cell(c: Color, i: float, j: float, amt: float, salt := 0.0) -> Color:
	return NewModels._vary(c, Vector3(i * 1.31 + salt, j * 2.17, salt * 0.7), amt)

# ================================================================== barn and silo
# A classic Ontario bank-style red barn: a gambrel roof (steep lower slopes, shallow upper ones) in weathered grey steel,
# vertical red boards with white trim, sliding double doors hung on a track in front of the gable, a hay loft door under a
# hay hood with its track beam, a louvred cupola, and a fieldstone foundation.
const BN_W := 6.0                        # half width (x), m
const BN_L := 12.0                       # half length (z), m
const BN_FOUND := 0.7                    # top of the fieldstone foundation
const BN_EAVE := 4.3
const BN_BREAK := Vector2(4.3, 7.0)      # where the steep lower roof meets the shallow upper one
const BN_RIDGE := 8.7
const BN_RED := Color(0.55, 0.11, 0.08)
const BN_WHITE := Color(0.9, 0.89, 0.85)
const BN_ROOF := Color(0.42, 0.44, 0.44)

## The height of the roof line over the wall at x.
static func _bn_roof(x: float) -> float:
	var ax := absf(x)
	if ax >= BN_BREAK.x: return lerpf(BN_BREAK.y, BN_EAVE, (ax - BN_BREAK.x) / (BN_W - BN_BREAK.x))
	return lerpf(BN_RIDGE, BN_BREAK.y, ax / BN_BREAK.x)

## The paint on a door or panel: barn red, a little faded or darker from one to the next (the boards' own grain, fading and
## wear come from the texture and the shader).
static func _bn_board(k: int, side: float) -> Color:
	var h := NewModels._h(Vector3(k * 1.37, side * 3.1, 0.5))
	return BN_RED.lerp(Color(0.6, 0.32, 0.27), 0.3 * h * h)

static func _bn_roof_col(i: int, j: int, sx: float) -> Color:
	var c := _cell(BN_ROOF, i, j, 0.08, sx)
	if NewModels._h(Vector3(i * 0.37, sx, 2.0)) > 0.85 and j <= 1: c = c.lerp(Color(0.45, 0.3, 0.2), 0.3)   # rust from the eaves
	return c

## A door or hatch on a barn wall: red boards on a backing, a white frame round it and (if braced) a white X.
## c is the middle of its face on the wall, n the way the wall faces.
static func _bn_door(kit: DroneParts.Kit, c: Vector3, w: float, h: float, n: Vector3, braced: bool, salt: int) -> void:
	var pm := farm_material("wood")
	var up := Vector3.UP
	var r := up.cross(n).normalized()
	kit.add(pm, _beam(c - up * (h * 0.5) + n * 0.03, c + up * (h * 0.5) + n * 0.03, w, 0.06, n), Transform3D.IDENTITY, BN_RED.darkened(0.3))
	var b := Buf.new()
	var f := c + n * 0.062
	b.quad(f - r * (w * 0.5) - up * (h * 0.5), f + r * (w * 0.5) - up * (h * 0.5), f + r * (w * 0.5) + up * (h * 0.5), f - r * (w * 0.5) + up * (h * 0.5), _bn_board(salt, n.x + n.z), n)
	kit.add(pm, b.data())
	var t := 0.15
	var fc := c + n * 0.09
	var hw := w * 0.5 - t * 0.5; var hh := h * 0.5 - t * 0.5
	var q: Array[Vector3] = [fc - r * hw - up * hh, fc + r * hw - up * hh, fc + r * hw + up * hh, fc - r * hw + up * hh]
	for k in 4:
		kit.add(pm, _beam(q[k], q[(k + 1) % 4], t, 0.05, n, t * 0.5), Transform3D.IDENTITY, BN_WHITE)
	if braced:
		kit.add(pm, _beam(q[0], q[2], t * 0.85, 0.045, n), Transform3D.IDENTITY, BN_WHITE)
		kit.add(pm, _beam(q[1], q[3], t * 0.85, 0.035, n), Transform3D.IDENTITY, BN_WHITE)

## A window: a white surround, dark glass and a white cross of glazing bars.
static func _bn_window(kit: DroneParts.Kit, c: Vector3, w: float, h: float, n: Vector3) -> void:
	var pm := farm_material("wood")
	var up := Vector3.UP
	var r := up.cross(n).normalized()
	kit.add(pm, _beam(c - up * (h * 0.5 + 0.12) + n * 0.03, c + up * (h * 0.5 + 0.12) + n * 0.03, w + 0.24, 0.06, n), Transform3D.IDENTITY, BN_WHITE)
	kit.add(_mat("glass"), _beam(c - up * (h * 0.5) + n * 0.05, c + up * (h * 0.5) + n * 0.05, w, 0.06, n))
	kit.add(pm, _beam(c - up * (h * 0.5) + n * 0.085, c + up * (h * 0.5) + n * 0.085, 0.05, 0.02, n), Transform3D.IDENTITY, BN_WHITE)
	kit.add(pm, _beam(c - r * (w * 0.5) + n * 0.085, c + r * (w * 0.5) + n * 0.085, 0.05, 0.02, n), Transform3D.IDENTITY, BN_WHITE)

## The red barn, 12 x 24 m, long axis along z, big doors on the front (-z) gable. Origin: the ground at the middle of the footprint.
static func barn() -> ArrayMesh:
	if _cache.has("barn"): return _cache["barn"]
	var kit := DroneParts.Kit.new()
	var pm := farm_material("wood")
	var rm := farm_material("roof")
	var I := Transform3D.IDENTITY
	# ---- walls: painted boards from the texture (30 cm boards, grain upright); the paint varies a little panel by panel
	var walls := Buf.new()
	for sx: float in [-1.0, 1.0]:
		var n := Vector3(sx, 0, 0)
		var x := sx * BN_W
		for k in 4:
			var z0 := -BN_L + k * 6.0; var z1 := z0 + 6.0
			walls.quad(Vector3(x, BN_FOUND, z0), Vector3(x, BN_FOUND, z1), Vector3(x, BN_EAVE, z1), Vector3(x, BN_EAVE, z0), _bn_board(k, sx), n)
	var xs: Array[float] = [-BN_W, -BN_BREAK.x, 0.0, BN_BREAK.x, BN_W]
	for sz: float in [-1.0, 1.0]:
		var z := sz * BN_L
		var n := Vector3(0, 0, sz)
		for k in xs.size() - 1:
			var x0 := xs[k]; var x1 := xs[k + 1]
			walls.quad(Vector3(x0, BN_FOUND, z), Vector3(x1, BN_FOUND, z), Vector3(x1, _bn_roof(x1) - 0.1, z), Vector3(x0, _bn_roof(x0) - 0.1, z), _bn_board(k + 100, sz), n)
	kit.add(pm, walls.data())
	# ---- fieldstone foundation (the rubble set), a little proud of the boards, with a ledge on top
	var stone := Buf.new()
	var fx := BN_W + 0.1; var fz := BN_L + 0.1; var fy := BN_FOUND + 0.05
	var sides := [[Vector3(-fx, 0, -fz), Vector3(1, 0, 0), 2.0 * fx, Vector3(0, 0, -1)], [Vector3(fx, 0, -fz), Vector3(0, 0, 1), 2.0 * fz, Vector3(1, 0, 0)],
		[Vector3(fx, 0, fz), Vector3(-1, 0, 0), 2.0 * fx, Vector3(0, 0, 1)], [Vector3(-fx, 0, fz), Vector3(0, 0, -1), 2.0 * fz, Vector3(-1, 0, 0)]]
	var stone_col := Color(0.6, 0.6, 0.6)
	for sd in sides:
		var o: Vector3 = sd[0]; var d: Vector3 = sd[1]; var ln: float = sd[2]; var n: Vector3 = sd[3]
		stone.quad(o, o + d * ln, o + d * ln + Vector3(0, fy, 0), o + Vector3(0, fy, 0), stone_col, n)
		stone.quad(o + Vector3(0, fy, 0), o + d * ln + Vector3(0, fy, 0), o + d * ln + Vector3(0, fy, 0) - n * 0.12, o + Vector3(0, fy, 0) - n * 0.12, stone_col.lightened(0.1), Vector3.UP)
	kit.add(farm_material("stone"), stone.data())
	# ---- the gambrel roof: corrugated galvanised sheets (a shade apart, rust at the eaves), overhanging 0.5 m at the eaves
	# and gables, bare boards underneath
	var roof := Buf.new()
	var soffit := Buf.new()
	var bare := Color(0.62, 0.56, 0.5, 0.0)
	var lr := BN_L + 0.5
	var tip := Vector2(BN_W, BN_EAVE) + Vector2(BN_W - BN_BREAK.x, BN_EAVE - BN_BREAK.y).normalized() * 0.5
	var prof: Array[Vector2] = [tip, BN_BREAK, Vector2(0.0, BN_RIDGE)]
	for sx: float in [-1.0, 1.0]:
		for k in 2:
			var a := Vector2(prof[k].x * sx, prof[k].y); var b := Vector2(prof[k + 1].x * sx, prof[k + 1].y)
			var t := b - a
			var n := Vector3(t.y * sx, -t.x * sx, 0.0).normalized()
			var o := Vector3(a.x, a.y, -lr); var u := Vector3(0, 0, 2.0 * lr); var v := Vector3(t.x, t.y, 0)
			var nv := 2 if k == 0 else 3
			for i in 20:
				for j in nv:
					var p0 := o + u * (i / 20.0) + v * (float(j) / nv)
					roof.quad(p0, p0 + u / 20.0, p0 + u / 20.0 + v / nv, p0 + v / nv, _bn_roof_col(i, j + k * 2, sx), n)
			var dn := Vector3(0, -0.18, 0)
			soffit.quad(o + dn, o + u + dn, o + u + v + dn, o + v + dn, bare, -n)
	kit.add(rm, roof.data())
	kit.add(pm, soffit.data())
	kit.add(rm, _beam(Vector3(0, BN_RIDGE + 0.03, -lr), Vector3(0, BN_RIDGE + 0.03, lr), 0.45, 0.08), I, BN_ROOF.darkened(0.2))
	# ---- white trim: rakes along both gables, fascia and frieze along the eaves, corner boards
	for sz: float in [-1.0, 1.0]:
		var z := sz * (lr + 0.03)
		var pts: Array[Vector2] = [Vector2(-tip.x, tip.y), Vector2(-BN_BREAK.x, BN_BREAK.y), Vector2(0, BN_RIDGE), BN_BREAK, tip]
		for k in 4:
			kit.add(pm, _beam(Vector3(pts[k].x, pts[k].y - 0.1, z), Vector3(pts[k + 1].x, pts[k + 1].y - 0.1, z), 0.3, 0.07, Vector3(0, 0, 1), 0.08), I, BN_WHITE)
	for sx: float in [-1.0, 1.0]:
		kit.add(pm, _beam(Vector3(sx * (tip.x + 0.02), tip.y - 0.08, -lr), Vector3(sx * (tip.x + 0.02), tip.y - 0.08, lr), 0.06, 0.24), I, BN_WHITE)
		kit.add(pm, _beam(Vector3(sx * (BN_W + 0.03), BN_EAVE - 0.2, -BN_L), Vector3(sx * (BN_W + 0.03), BN_EAVE - 0.2, BN_L), 0.05, 0.3), I, BN_WHITE)
		for sz: float in [-1.0, 1.0]:
			kit.add(pm, NewModels._box(Vector3(0.22, BN_EAVE - BN_FOUND, 0.22)), NewModels._xf(Vector3(sx * (BN_W - 0.06), (BN_EAVE + BN_FOUND) * 0.5, sz * (BN_L - 0.06))), BN_WHITE)
	# ---- the front gable: sliding doors on a track, the hay loft door, two windows, the hay hood with its track beam
	var nf := Vector3(0, 0, -1)
	for sx: float in [-1.0, 1.0]:
		_bn_door(kit, Vector3(sx * 1.15, 2.1, -BN_L - 0.11), 2.3, 4.0, nf, true, 10 + int(sx * 5.0))
		_bn_window(kit, Vector3(sx * 4.1, 2.7, -BN_L), 0.8, 0.9, nf)
	kit.add(rm, _beam(Vector3(-4.7, 4.24, -BN_L - 0.16), Vector3(4.7, 4.24, -BN_L - 0.16), 0.14, 0.14), I, Color(0.15, 0.15, 0.16))
	kit.add(rm, _beam(Vector3(-4.8, 4.4, -BN_L - 0.2), Vector3(4.8, 4.4, -BN_L - 0.2), 0.35, 0.05), I, BN_ROOF.darkened(0.1))
	_bn_door(kit, Vector3(0, 6.05, -BN_L), 1.7, 1.7, nf, true, 30)
	var hood := Buf.new()
	var hood_under := Buf.new()
	var zt := -BN_L - 1.5
	var apex := BN_RIDGE + 0.02
	for sx: float in [-1.0, 1.0]:
		var n := Vector3(0.6 * sx, 1.0, 0).normalized()
		var a := Vector3(0, apex, -lr); var b := Vector3(0, apex, zt); var c := Vector3(sx * 1.0, apex - 0.6, zt); var d := Vector3(sx * 1.0, apex - 0.6, -lr)
		hood.quad(a, b, c, d, BN_ROOF, n)
		var dn := Vector3(0, -0.06, 0)
		hood_under.quad(a + dn, b + dn, c + dn, d + dn, bare, -n)
		kit.add(pm, _beam(Vector3(0, apex - 0.08, zt - 0.03), Vector3(sx * 1.05, apex - 0.68, zt - 0.03), 0.22, 0.06, Vector3(0, 0, 1), 0.05), I, BN_WHITE)
	kit.add(rm, hood.data())
	kit.add(pm, hood_under.data())
	kit.add(pm, _beam(Vector3(0, BN_RIDGE - 0.4, -BN_L + 0.2), Vector3(0, BN_RIDGE - 0.4, zt + 0.1), 0.18, 0.22), I, Color(0.55, 0.45, 0.36, 0.0))
	kit.add(rm, NewModels._box(Vector3(0.16, 0.35, 0.16)), NewModels._xf(Vector3(0, BN_RIDGE - 0.72, zt + 0.35)), Color(0.12, 0.12, 0.12))
	# ---- the back gable: a smaller pair of doors and a loft window; side windows and a person door on the right
	var nb := Vector3(0, 0, 1)
	for sx: float in [-1.0, 1.0]:
		_bn_door(kit, Vector3(sx * 0.9, 1.8, BN_L + 0.11), 1.8, 3.4, nb, true, 50 + int(sx * 5.0))
	kit.add(rm, _beam(Vector3(-3.7, 3.64, BN_L + 0.16), Vector3(3.7, 3.64, BN_L + 0.16), 0.14, 0.14), I, Color(0.15, 0.15, 0.16))
	_bn_window(kit, Vector3(0, 6.0, BN_L), 1.0, 1.0, nb)
	for sx: float in [-1.0, 1.0]:
		var zs: Array = [-8.5, -2.5, 9.0] if sx > 0.0 else [-8.5, -2.5, 3.0, 9.0]     # the person door is on the right
		for z: float in zs: _bn_window(kit, Vector3(sx * BN_W, 2.9, z), 1.0, 1.1, Vector3(sx, 0, 0))
	_bn_door(kit, Vector3(BN_W + 0.1, 1.8, 5.0), 1.0, 2.1, Vector3(1, 0, 0), false, 70)
	kit.add(farm_material("stone"), NewModels._box(Vector3(0.6, 0.75, 1.3)), NewModels._xf(Vector3(BN_W + 0.35, 0.375, 5.0)), Color(0.6, 0.59, 0.56))
	# ---- the cupola on the ridge: louvred white sides, corner posts, a pyramid roof, a weather vane
	var cb := Buf.new()
	var ch := 0.8; var cy0 := 8.1; var cy1 := 9.6
	for f in 4:
		var ang := f * PI * 0.5
		var n := Vector3(sin(ang), 0, -cos(ang))
		var r := Vector3(cos(ang), 0, sin(ang))
		for j in 8:
			var ya := lerpf(cy0, cy1, j / 8.0); var yb := lerpf(cy0, cy1, (j + 1) / 8.0)
			var c := BN_WHITE if (j < 3 or j == 7 or j % 2 == 1) else Color(0.4, 0.4, 0.4)
			cb.quad(n * ch - r * ch + Vector3(0, ya, 0), n * ch + r * ch + Vector3(0, ya, 0), n * ch + r * ch + Vector3(0, yb, 0), n * ch - r * ch + Vector3(0, yb, 0), c, n)
		var corner := (n + r) * (ch + 0.02)
		kit.add(pm, _beam(Vector3(corner.x, cy0 + 0.3, corner.z), Vector3(corner.x, cy1, corner.z), 0.12, 0.12), I, BN_WHITE)
	kit.add(pm, cb.data())
	kit.add(pm, NewModels._box(Vector3(1.85, 0.12, 1.85)), NewModels._xf(Vector3(0, cy1 + 0.06, 0)), BN_WHITE)
	var pyr := DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, cy1 + 0.12), Vector2(1.35, cy1 + 0.12), Vector2(0, cy1 + 0.78)])), 4)
	kit.add(rm, pyr, NewModels._xf(Vector3.ZERO, Vector3(0, PI * 0.25, 0)), BN_ROOF)
	var vane := Color(0.12, 0.12, 0.12)
	kit.add(rm, DroneParts.tube(Vector3(0, cy1 + 0.7, 0), Vector3(0, cy1 + 1.3, 0), 0.025, 0.02, 5), I, vane)
	kit.add(rm, _beam(Vector3(0, cy1 + 1.18, -0.45), Vector3(0, cy1 + 1.18, 0.45), 0.03, 0.06), I, vane)
	kit.add(rm, NewModels._box(Vector3(0.02, 0.22, 0.2)), NewModels._xf(Vector3(0, cy1 + 1.18, 0.38)), vane)
	kit.add(rm, _beam(Vector3(-0.25, cy1 + 1.0, 0), Vector3(0.25, cy1 + 1.0, 0), 0.02, 0.02), I, vane)
	kit.add(rm, _beam(Vector3(0, cy1 + 1.0, -0.25), Vector3(0, cy1 + 1.0, 0.25), 0.02, 0.02), I, vane)
	var mesh := kit.commit()
	_cache["barn"] = mesh
	return mesh

## A concrete stave silo with steel hoops, a galvanised dome, the unloading chute on its -x side and a blower pipe up the
## side. 5 m wide, 18 m to the top of the dome. Origin: the ground at its centre.
static func silo() -> ArrayMesh:
	if _cache.has("silo"): return _cache["silo"]
	var kit := DroneParts.Kit.new()
	var pm := farm_material("concrete"); var sh := farm_material("galv")
	var R := 2.5
	var wall := PackedVector2Array([Vector2(0.0, 0.0), Vector2(R + 0.15, 0.0), Vector2(R + 0.15, 0.0), Vector2(R + 0.15, 0.45), Vector2(R + 0.15, 0.45), Vector2(R, 0.45), Vector2(R, 0.45)])
	for k in 6:
		var yh := 2.4 + 2.5 * k
		wall.append(Vector2(R, yh)); wall.append(Vector2(R, yh + 0.1))
	wall.append(Vector2(R, 15.75)); wall.append(Vector2(0.0, 15.75))     # closed top and bottom, so the outward vote is right
	var stave := func(p: Vector3, n: Vector3) -> Color:
		if p.y < 0.45 or n.y > 0.5: return Color(0.6, 0.59, 0.56)
		if p.y > 2.3 and fposmod(p.y - 2.4, 2.5) < 0.1: return Color(0.3, 0.28, 0.26)       # steel hoop
		var j := floorf(fposmod(atan2(p.z, p.x), TAU) / (TAU / 16.0))
		var band := floorf((p.y - 0.45) / 2.5)
		var c := _cell(Color(0.74, 0.72, 0.67), j, band, 0.04)
		if NewModels._h(Vector3(j, 3.0, 1.0)) > 0.72: c = c.darkened(0.12)                 # a rain streak down one stave
		if p.y < 2.0: c = c.lerp(Color(0.45, 0.47, 0.4), 0.3)                               # green grime near the ground
		return c
	kit.add(pm, NewModels._paint(DroneParts.lathe(wall, 16), stave))
	var dome := PackedVector2Array([Vector2(2.62, 15.7), Vector2(2.62, 15.86), Vector2(2.62, 15.86), Vector2(2.25, 16.7), Vector2(1.55, 17.45), Vector2(0.75, 17.88), Vector2(0.0, 18.0)])
	var galv := func(p: Vector3, _n: Vector3) -> Color:
		var j := floorf(fposmod(atan2(p.z, p.x), TAU) / (TAU / 16.0))
		var c := _cell(Color(0.72, 0.74, 0.75), j, 0.0, 0.08, 3.0)
		if p.y < 16.0: c = c.darkened(0.15)
		return c
	kit.add(sh, NewModels._paint(DroneParts.lathe(dome, 16), galv))
	# the chute: a column of little doors behind a galvanised casing, capped where it meets the dome
	var cx := -(R + 0.17)
	kit.add(sh, NewModels._box(Vector3(0.45, 15.3, 0.95)), NewModels._xf(Vector3(cx, 0.45 + 7.65, 0)), Color(0.62, 0.64, 0.65))
	var cf := Buf.new()
	for j in 10:
		var ya := 0.45 + 15.3 * j / 10.0; var yb := 0.45 + 15.3 * (j + 1) / 10.0
		var c := Color(0.68, 0.7, 0.71) if j % 2 == 0 else Color(0.58, 0.6, 0.61)
		cf.quad(Vector3(cx - 0.235, ya, -0.48), Vector3(cx - 0.235, ya, 0.48), Vector3(cx - 0.235, yb, 0.48), Vector3(cx - 0.235, yb, -0.48), c, Vector3(-1, 0, 0))
	kit.add(sh, cf.data())
	kit.add(sh, NewModels._box(Vector3(0.75, 0.55, 1.1)), NewModels._xf(Vector3(cx + 0.1, 16.0, 0), Vector3(0, 0, -0.35)), Color(0.66, 0.68, 0.69))
	# the blower pipe from the ground to the top, bending in over the dome
	var a := 2.4
	var pd := Vector3(cos(a), 0, sin(a))
	kit.add(sh, DroneParts.tube(pd * (R + 0.14) + Vector3(0, 0.6, 0), pd * (R + 0.14) + Vector3(0, 16.2, 0), 0.11, 0.11, 6), Transform3D.IDENTITY, Color(0.7, 0.72, 0.73))
	kit.add(sh, DroneParts.tube(pd * (R + 0.14) + Vector3(0, 16.2, 0), pd * 1.2 + Vector3(0, 17.5, 0), 0.11, 0.11, 6), Transform3D.IDENTITY, Color(0.7, 0.72, 0.73))
	var mesh := kit.commit()
	_cache["silo"] = mesh
	return mesh

# ================================================================== windmills
# A Dutch stage mill (stellingmolen): a tapered brick tower with a wooden gallery round it, a thatched cap that turns to
# the wind with its tail pole and capstan wheel reaching down to the gallery, a painted beard board under the windshaft,
# and four lattice sails with their cloths rolled up.
const WM_H := 16.0                       # top of the brick tower, m
const WM_R0 := 3.1                       # radius at the foot
const WM_R1 := 2.15                      # radius at the top
const WM_GAL := 7.5                      # the gallery deck
const WM_PIVOT := Vector3(0.0, 17.3, -3.2)
const WM_SAIL := 8.0                     # from the hub to the sail tip (lattice 7 m long)
const WM_BAR := 0.18                     # sail bars across; nothing on the sails is thinner than 15 cm (they shimmered beyond 100 m)

static func _wm_r(y: float) -> float:
	return lerpf(WM_R0, WM_R1, y / WM_H)

## A door or window set into the tapered tower at angle ang (0 = the front, -z) and height y: a white frame and a filling.
static func _wm_open(kit: DroneParts.Kit, ang: float, y: float, w: float, h: float, fill: Color, glass: bool) -> void:
	var tilt := atan((WM_R0 - WM_R1) / WM_H)
	var b := Basis(Vector3.UP, -ang) * Basis(Vector3.RIGHT, tilt)
	var c := Vector3(sin(ang), 0, -cos(ang)) * _wm_r(y) + Vector3(0, y, 0)
	kit.add(_mat("paint"), NewModels._box(Vector3(w + 0.24, h + 0.24, 0.16)), Transform3D(b, c), Color(0.9, 0.9, 0.86))
	if glass: kit.add(_mat("glass"), NewModels._box(Vector3(w, h, 0.2)), Transform3D(b, c))
	else: kit.add(_mat("paint"), NewModels._box(Vector3(w, h, 0.2)), Transform3D(b, c), fill)

## The windmill: {"tower", "cap", "sails", "sail_pivot", "spin_sign", "sail_radius", "height"}. Tower and cap are in the
## tower's frame (origin: the ground at the middle of the tower). The sails mesh has its hub at its origin and turns about
## its own +Z: place it at sail_pivot and rotate by spin_sign * omega * t (anticlockwise seen from the front, as Dutch mills
## turn). The cap and the sails may also turn together about the tower's +Y to face the wind.
static func windmill() -> Dictionary:
	if _cache.has("windmill"): return _cache["windmill"]
	var pm := _mat("paint")
	var I := Transform3D.IDENTITY
	var green := Color(0.1, 0.3, 0.2); var white := Color(0.9, 0.9, 0.86); var wood := Color(0.3, 0.24, 0.18)
	# ---- the tower: brick in courses, a stone plinth, doors at the foot and onto the gallery, small windows
	var tk := DroneParts.Kit.new()
	var prof := PackedVector2Array([Vector2(0, 0), Vector2(WM_R0 + 0.2, 0.0), Vector2(WM_R0 + 0.2, 0.0), Vector2(WM_R0 + 0.2, 0.7), Vector2(WM_R0 + 0.2, 0.7),
		Vector2(_wm_r(0.7), 0.7), Vector2(_wm_r(0.7), 0.7)])
	for k in range(1, 17): prof.append(Vector2(_wm_r(0.7 + (WM_H - 0.7) * k / 16.0), 0.7 + (WM_H - 0.7) * k / 16.0))
	prof.append(Vector2(0, WM_H))
	var brick := func(p: Vector3, n: Vector3) -> Color:
		if p.y < 0.71 or n.y > 0.5: return _cell(Color(0.55, 0.53, 0.5), floorf(atan2(p.z, p.x) * 3.0), 0.0, 0.08)
		var j := floorf(fposmod(atan2(p.z, p.x), TAU) / (TAU / 20.0))
		var band := floorf((p.y - 0.7) / ((WM_H - 0.7) / 16.0))
		var c := _cell(Color(0.47, 0.22, 0.15), j, band, 0.08)
		if int(band) % 3 == 1: c = c.darkened(0.06)
		if p.y < 2.0: c = c.darkened(0.12)                                                  # splash and damp at the foot
		return c
	tk.add(pm, NewModels._paint(DroneParts.lathe(prof, 20), brick))
	_wm_open(tk, 0.0, 1.85, 1.1, 2.2, green, false)
	_wm_open(tk, PI, 1.85, 1.1, 2.2, green, false)
	_wm_open(tk, 0.0, WM_GAL + 1.1, 1.0, 1.9, green, false)
	_wm_open(tk, PI, WM_GAL + 1.1, 1.0, 1.9, green, false)
	for wdw in [[PI * 0.5, 3.4], [PI * 1.25, 4.4], [PI * 0.75, 11.2], [PI * 1.55, 12.4], [PI * 0.2, 13.8], [PI * 1.0, 13.0]]:
		_wm_open(tk, wdw[0], wdw[1], 0.7, 0.9, Color.WHITE, true)
	tk.add(pm, NewModels._box(Vector3(1.6, 0.25, 0.8)), NewModels._xf(Vector3(0, 0.12, -WM_R0 - 0.6)), Color(0.55, 0.53, 0.5))     # door step
	# ---- the gallery: a plank deck on raking struts, posts and a top rail
	var deck := DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(_wm_r(WM_GAL) - 0.2, WM_GAL), Vector2(5.4, WM_GAL), Vector2(5.4, WM_GAL + 0.15), Vector2(_wm_r(WM_GAL) - 0.2, WM_GAL + 0.15)])), 24)
	var planks := func(p: Vector3, _n: Vector3) -> Color:
		return _cell(Color(0.42, 0.37, 0.31), floorf(fposmod(atan2(p.z, p.x), TAU) / (TAU / 24.0)), 0.0, 0.12)
	tk.add(pm, NewModels._paint(deck, planks))
	var rail_y := WM_GAL + 1.15
	for k in 12:
		var a := TAU * (k + 0.5) / 12.0; var a2 := TAU * (k + 1.5) / 12.0
		var d := Vector3(cos(a), 0, sin(a)); var d2 := Vector3(cos(a2), 0, sin(a2))
		tk.add(pm, _beam(d * 5.3 + Vector3(0, WM_GAL + 0.15, 0), d * 5.3 + Vector3(0, rail_y, 0), 0.09, 0.09), I, white)
		tk.add(pm, _beam(d * 5.3 + Vector3(0, rail_y, 0), d2 * 5.3 + Vector3(0, rail_y, 0), 0.08, 0.06, Vector3.UP, 0.05), I, white)
		tk.add(pm, _beam(d * (_wm_r(5.3) - 0.05) + Vector3(0, 5.3, 0), d * 4.9 + Vector3(0, WM_GAL - 0.02, 0), 0.14, 0.14), I, wood)
	# ---- the cap: a curb ring, then a thatched hood shaped like an upturned boat
	var ck := DroneParts.Kit.new()
	var curb := DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(WM_R1 - 0.1, WM_H - 0.1), Vector2(2.4, WM_H - 0.1), Vector2(2.4, WM_H + 0.45), Vector2(WM_R1 - 0.1, WM_H + 0.45)])), 20)
	ck.add(pm, curb, I, green)
	var yb := WM_H + 0.45
	var rows: Array = []; var cens: Array[Vector3] = []
	for st in [[-2.6, 1.55, 1.5], [-2.42, 2.08, 2.15], [-1.68, 2.42, 2.65], [-0.35, 2.52, 2.85], [1.05, 2.46, 2.7], [2.02, 2.17, 2.3], [2.5, 1.55, 1.6]]:
		var row := PackedVector3Array()
		for j in 13:
			var cx := cos(PI * j / 12.0)
			row.append(Vector3(float(st[1]) * cx, yb + float(st[2]) * (1.0 - pow(absf(cx), 1.5)), st[0]))
		rows.append(row); cens.append(Vector3(0, yb + float(st[2]) * 0.35, st[0]))
	var thatch := func(p: Vector3, n: Vector3) -> Color:
		if n.y < -0.5: return wood
		var c := _cell(Color(0.33, 0.29, 0.22), floorf(p.z * 1.3), floorf(p.y * 2.0), 0.1)
		return c.darkened(0.15) if p.y > yb + 2.5 else c                                   # the ridge darkens with weather
	ck.add(pm, NewModels._paint(NewModels._closed_grid(rows, cens, false), thatch))
	ck.add(pm, _beam(Vector3(0, yb + 2.82, -1.7), Vector3(0, yb + 2.82, 1.1), 0.3, 0.12), I, Color(0.2, 0.18, 0.15))     # ridge cap
	ck.add(pm, DroneParts.tube(Vector3(0, WM_PIVOT.y, -1.0), Vector3(0, WM_PIVOT.y, WM_PIVOT.z + 0.3), 0.3, 0.3, 8), I, wood)   # windshaft
	ck.add(pm, NewModels._box(Vector3(2.5, 1.0, 0.08)), NewModels._xf(Vector3(0, 16.65, -2.66)), white)      # the beard: white edge
	ck.add(pm, NewModels._box(Vector3(2.2, 0.72, 0.1)), NewModels._xf(Vector3(0, 16.65, -2.68)), green)
	# the tail pole down to the gallery, its struts and the capstan wheel the miller turns the cap with
	var tail_a := Vector3(0, 16.8, 2.1); var tail_b := Vector3(0, 8.9, 5.35)
	ck.add(pm, _beam(tail_a, tail_b, 0.3, 0.3), I, wood)
	var on_tail := tail_a.lerp(tail_b, 0.6)
	for sx: float in [-1.0, 1.0]:
		ck.add(pm, _beam(Vector3(sx * 1.95, 16.55, 1.3), on_tail, 0.18, 0.18), I, wood)
	var wheel := DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0.66, -0.05), Vector2(0.76, -0.05), Vector2(0.76, 0.05), Vector2(0.66, 0.05)])), 12)
	var wc := tail_b + Vector3(0, 0.15, 0.25)
	ck.add(pm, wheel, Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), wc), wood)
	for k in 2:
		var a := PI * 0.5 * k + 0.4
		var d := Vector3(0, sin(a), cos(a)) * 0.7
		ck.add(pm, _beam(wc - d, wc + d, 0.06, 0.06, Vector3(1, 0, 0)), I, wood)
	# ---- the sails: two stocks through the shaft head; on the trailing side a bold lattice (eight 18 cm sail bars, two heavy
	# hemlaths) with the cloth spread over its inner third and the rest rolled up along the outer hemlath; a dark leading-edge
	# board on the other side of the stock. Every part is at least 15 cm across, so the sails still read as sails from 250 m.
	var sk := DroneParts.Kit.new()
	var stock := Color(0.24, 0.2, 0.16); var bar := Color(0.86, 0.84, 0.78); var lath := Color(0.55, 0.14, 0.1); var cloth := Color(0.9, 0.86, 0.76)
	var head := DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, -0.85), Vector2(0.3, -0.8), Vector2(0.45, -0.6), Vector2(0.45, 0.6)])), 10)
	sk.add(pm, head, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), Color(0.18, 0.18, 0.19))
	var dirs: Array[Vector3] = [Vector3.UP, Vector3.RIGHT, Vector3.DOWN, Vector3.LEFT]
	var spread := Buf.new()
	var zf := Vector3(0, 0, -1)
	for d in dirs:
		var zs := -0.15 if absf(d.y) > 0.5 else -0.5                     # the two stocks cross one in front of the other
		var zl := Vector3(0, 0, zs - 0.3)
		var lead := Vector3(d.y, -d.x, 0)                                 # the way this sail moves when turning anticlockwise from the front
		sk.add(pm, _beam(Vector3(0, 0, zs), d * WM_SAIL + Vector3(0, 0, zs), 0.32, 0.3, Vector3(0, 0, 1)), I, stock)
		for k in 8:
			var r := 1.0 + k * (WM_SAIL - 1.1) / 7.0
			sk.add(pm, _beam(d * r + lead * 0.12 + zl, d * r - lead * 1.8 + zl, WM_BAR, 0.12, Vector3(0, 0, 1)), I, bar)
		sk.add(pm, _beam(d * 0.9 - lead * 1.8 + zl, d * WM_SAIL - lead * 1.8 + zl, 0.2, 0.14, Vector3(0, 0, 1)), I, lath)
		sk.add(pm, _beam(d * 0.9 - lead * 0.9 + zl, d * WM_SAIL - lead * 0.9 + zl, 0.16, 0.12, Vector3(0, 0, 1)), I, lath)
		sk.add(pm, _beam(d * 1.4 + lead * 0.36 + zl, d * WM_SAIL + lead * 0.36 + zl, 0.44, 0.06, Vector3(0, 0, 1)), I, stock.darkened(0.25))
		# the spread cloth: the inner third of the lattice, just in front of the bars, double-sided
		var r0 := 1.0; var r1 := 1.0 + (WM_SAIL - 1.0) / 3.0
		var cz := zl + zf * 0.09
		spread.quad(d * r0 + lead * 0.1 + cz, d * r1 + lead * 0.1 + cz, d * r1 - lead * 1.82 + cz, d * r0 - lead * 1.82 + cz, cloth, zf)
		# the rest of the cloth rolled up beside the outer hemlath
		sk.add(_mat("cloth"), DroneParts.tube(d * (r1 + 0.05) - lead * 1.6 + zl + zf * 0.12, d * (WM_SAIL - 0.4) - lead * 1.6 + zl + zf * 0.12, 0.13, 0.13, 5), I, cloth.darkened(0.08))
	sk.add(_mat("cloth"), spread.data())
	var out := {"tower": tk.commit(), "cap": ck.commit(), "sails": sk.commit(), "sail_pivot": WM_PIVOT, "spin_sign": -1.0, "sail_radius": WM_SAIL, "height": yb + 3.1}
	_cache["windmill"] = out
	return out

# A farm water-pumping windmill of the classic American kind: a galvanised lattice tower, a wheel of 18 pitched steel blades
# riveted between two rings, a gearbox head with a long tail vane, the pump rod down to a pump stand and a stock tank.
const WP_TOP := 9.6                      # the top of the tower
const WP_PIVOT := Vector3(0.0, 10.2, -0.75)
const WP_R := 1.8                        # a 12 ft wheel

static func _wp_leg(sx: float, sz: float, y: float) -> Vector3:
	var h := lerpf(1.5, 0.32, y / WP_TOP)
	return Vector3(sx * h, y, sz * h)

## The wind pump: {"tower", "wheel", "wheel_pivot", "tail", "head_pivot", "spin_sign", "wheel_radius", "height"}. Tower and tail
## are in the tower's frame (origin: the ground at the middle of the tower). The wheel has its hub at its origin and turns about
## its own +Z: place it at wheel_pivot and rotate by spin_sign * omega * t. The tail (vane, boom and gearbox) and the wheel may
## also turn together about the vertical through head_pivot to face the wind (the wheel faces -Z, the vane trails behind).
static func wind_pump() -> Dictionary:
	if _cache.has("wind_pump"): return _cache["wind_pump"]
	var sh := _mat("sheet"); var pm := _mat("paint")
	var I := Transform3D.IDENTITY
	var galv := Color(0.62, 0.64, 0.65)
	var tk := DroneParts.Kit.new()
	var corners: Array[Vector2] = [Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(-1, 1)]
	var levels: Array[float] = [0.35, 2.6, 4.7, 6.5, 8.1, 9.45]
	for k in 4:
		var c := corners[k]
		tk.add(sh, _beam(_wp_leg(c.x, c.y, 0.0), _wp_leg(c.x, c.y, WP_TOP), 0.12, 0.12), I, _cell(galv, k, 0.0, 0.08))
		tk.add(pm, NewModels._box(Vector3(0.5, 0.4, 0.5)), NewModels._xf(_wp_leg(c.x, c.y, 0.0) + Vector3(0, 0.1, 0)), Color(0.6, 0.59, 0.56))   # footing
	for i in levels.size():
		for k in 4:
			var c := corners[k]; var c2 := corners[(k + 1) % 4]
			tk.add(sh, _beam(_wp_leg(c.x, c.y, levels[i]), _wp_leg(c2.x, c2.y, levels[i]), 0.08, 0.08), I, _cell(galv, k, i, 0.1))
			if i + 1 < levels.size():
				tk.add(sh, _beam(_wp_leg(c.x, c.y, levels[i]), _wp_leg(c2.x, c2.y, levels[i + 1]), 0.04, 0.04), I, galv.darkened(0.1))
				tk.add(sh, _beam(_wp_leg(c2.x, c2.y, levels[i]), _wp_leg(c.x, c.y, levels[i + 1]), 0.04, 0.04), I, galv.darkened(0.1))
	tk.add(pm, NewModels._box(Vector3(1.4, 0.05, 1.4)), NewModels._xf(Vector3(0, WP_TOP - 0.55, 0)), Color(0.42, 0.36, 0.3))    # the little platform
	tk.add(sh, _beam(Vector3(0, 0.9, 0), Vector3(0, WP_TOP, 0), 0.035, 0.035), I, galv.darkened(0.2))                         # pump rod
	# the pump stand, its spout and a round stock tank with water in it
	tk.add(sh, DroneParts.tube(Vector3(0, 0, 0), Vector3(0, 1.1, 0), 0.08, 0.08, 8), I, Color(0.25, 0.25, 0.26))
	tk.add(sh, DroneParts.tube(Vector3(0, 0.95, 0), Vector3(1.25, 0.88, 0), 0.04, 0.04, 6), I, Color(0.25, 0.25, 0.26))
	var tank := DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, 0.02), Vector2(1.1, 0.02), Vector2(1.1, 0.65), Vector2(1.02, 0.65), Vector2(1.02, 0.1)])), 16)
	tk.add(sh, tank, NewModels._xf(Vector3(2.0, 0, 0)), Color(0.66, 0.68, 0.69))
	tk.add(pm, DroneParts.lathe(PackedVector2Array([Vector2(0, 0.55), Vector2(1.02, 0.55)]), 16), NewModels._xf(Vector3(2.0, 0, 0)), Color(0.1, 0.16, 0.18))
	# ---- the head and tail: turntable, gearbox, the shaft to the wheel, the boom and the vane
	var hk := DroneParts.Kit.new()
	hk.add(sh, DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, WP_TOP), Vector2(0.32, WP_TOP), Vector2(0.32, WP_TOP + 0.15), Vector2(0, WP_TOP + 0.15)])), 10), I, galv.darkened(0.15))
	hk.add(sh, DroneParts.rbox(Vector3(0.5, 0.55, 0.8), 5.0, 10), NewModels._xf(Vector3(0, WP_TOP + 0.45, -0.15)), galv)
	hk.add(sh, DroneParts.tube(Vector3(0, WP_PIVOT.y, -0.5), Vector3(0, WP_PIVOT.y, WP_PIVOT.z + 0.1), 0.05, 0.05, 6), I, galv.darkened(0.3))
	for sx: float in [-1.0, 1.0]:
		hk.add(sh, _beam(Vector3(sx * 0.15, WP_TOP + 0.5, 0.2), Vector3(0, WP_TOP + 0.62, 2.7), 0.05, 0.05), I, galv)
	hk.add(sh, _beam(Vector3(0, WP_TOP + 0.25, 0.2), Vector3(0, WP_TOP + 0.5, 2.5), 0.03, 0.03), I, galv)
	var vane := Buf.new()
	var vz0 := 2.4; var vz1 := 4.0; var vy0 := WP_TOP + 0.15; var vy1 := WP_TOP + 1.25
	for sx: float in [-1.0, 1.0]:
		for i in 3:
			var za := lerpf(vz0, vz1, i / 3.0); var zb := lerpf(vz0, vz1, (i + 1) / 3.0)
			vane.quad(Vector3(sx * 0.015, vy0, za), Vector3(sx * 0.015, vy0, zb), Vector3(sx * 0.015, vy1, zb), Vector3(sx * 0.015, vy1, za), _cell(galv, i, sx, 0.1), Vector3(sx, 0, 0))
	hk.add(sh, vane.data())
	hk.add(sh, _beam(Vector3(0, vy0, vz0), Vector3(0, vy1, vz0), 0.05, 0.05), I, galv.darkened(0.2))
	hk.add(sh, _beam(Vector3(0, vy0, vz1), Vector3(0, vy1, vz1), 0.05, 0.05), I, galv.darkened(0.2))
	# ---- the wheel: hub, six arms, an inner and an outer ring, 18 pitched blades
	var wk := DroneParts.Kit.new()
	wk.add(sh, DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, -0.2), Vector2(0.15, -0.15), Vector2(0.15, 0.15), Vector2(0, 0.18)])), 8), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), galv.darkened(0.3))
	for k in 6:
		var a := TAU * k / 6.0
		wk.add(sh, _beam(Vector3(cos(a), sin(a), 0) * 0.1, Vector3(cos(a), sin(a), 0) * (WP_R - 0.02), 0.04, 0.03, Vector3(0, 0, 1)), I, galv.darkened(0.15))
	for rr: float in [0.55, WP_R - 0.03]:
		var ring: Array = []; var rad: Array = []
		for k in 18:
			ring.append(Vector3(cos(TAU * k / 18.0), sin(TAU * k / 18.0), 0) * rr); rad.append(0.022)
		wk.add(sh, NewModels._sweep(ring, rad, rad, 3, Vector3(0, 0, 1), true), I, galv.darkened(0.15))
	var blades := Buf.new()
	var pitch := deg_to_rad(35.0)
	for k in 18:
		var a := TAU * (k + 0.5) / 18.0
		var er := Vector3(cos(a), sin(a), 0); var et := Vector3(-sin(a), cos(a), 0)
		var across := (et * cos(pitch) + Vector3(0, 0, sin(pitch)))
		var bn := er.cross(across).normalized()
		var col := _cell(galv, k, 0.0, 0.12, 5.0)
		var st: Array = []
		for r: float in [0.5, 1.15, WP_R]:
			var w := lerpf(0.19, 0.42, (r - 0.5) / (WP_R - 0.5))      # wide enough that the wheel reads as a disc far off
			st.append([er * r - across * (w * 0.5), er * r + bn * 0.025, er * r + across * (w * 0.5)])
		for i in 2:
			for j in 2:
				blades.quad(st[i][j], st[i + 1][j], st[i + 1][j + 1], st[i][j + 1], col, bn)
	wk.add(_mat("sheet2"), blades.data())
	var out := {"tower": tk.commit(), "wheel": wk.commit(), "wheel_pivot": WP_PIVOT, "tail": hk.commit(), "head_pivot": Vector3(0, WP_TOP, 0),
		"spin_sign": 1.0, "wheel_radius": WP_R, "height": WP_PIVOT.y + WP_R}
	_cache["wind_pump"] = out
	return out

# ================================================================== freight train and track
# A North American style freight: a six-axle diesel hood unit in plain dark blue and yellow (no company marks), and boxcars,
# covered hoppers, tank cars and bulkhead flatcars with lumber, all on standard gauge. Every car is built round its own
# middle with the top of the rail at y = 0 and its front towards -z, so cars can be placed along a track with MultiMesh.
const TR_GAUGE := 1.435
const TR_CAR := 16.6                     # coupled length of every car (over the couplers), m
const TR_LOCO := 21.6                    # coupled length of the locomotive
const TR_BLUE := Color(0.07, 0.12, 0.28)
const TR_YELLOW := Color(0.96, 0.74, 0.1)

const TR_LOCO_WHEEL := 0.51             # 40 inch wheels under the locomotive
const TR_CAR_WHEEL := 0.46              # 36 inch wheels under the cars
const TR_LOCO_TRUCKS := [-6.35, 6.35]
const TR_CAR_TRUCKS := [-5.85, 5.85]

## One wheelset: two wheels and their axle, centred on the axle with the axle along +X (the spin axis). Each wheel is turned
## from a profile: the inner face, a flange that stands 3 cm proud on the inside, the coned tread (worn bright) and the dished
## outer face. The treads sit on the rails (gauge 1.435 m), so placed at (0, r, z) the wheels touch y = 0.
static func _tr_wheelset(r: float) -> ArrayMesh:
	var key := "wheelset_%.2f" % r
	if _cache.has(key): return _cache[key]
	var prof := PackedVector2Array([Vector2(0.11, 0.655), Vector2(r + 0.03, 0.668), Vector2(r, 0.71), Vector2(r - 0.008, 0.82), Vector2(0.12, 0.8)])
	var paint := func(p: Vector3, _n: Vector3) -> Color:
		var rad := Vector2(p.x, p.z).length()
		return Color(0.56, 0.54, 0.51) if rad > r - 0.012 else Color(0.2, 0.16, 0.13)              # bright running surface, rusty plate
	var wheel := NewModels._paint(DroneParts.lathe(prof, 12), paint)
	var kit := DroneParts.Kit.new()
	var sh := _mat("sheet")
	var on_x := Basis(Vector3(0, 0, 1), -PI * 0.5)                       # the lathe's +Y onto +X
	kit.add(sh, wheel, Transform3D(on_x, Vector3.ZERO))
	kit.add(sh, wheel, Transform3D(Basis(Vector3.UP, PI) * on_x, Vector3.ZERO))
	kit.add(sh, DroneParts.tube(Vector3(-0.86, 0, 0), Vector3(0.86, 0, 0), 0.085, 0.085, 6), Transform3D.IDENTITY, Color(0.18, 0.15, 0.13))
	var mesh := kit.commit()
	_cache[key] = mesh
	return mesh

## The far wheelset: the two wheels and axle as one plain six-sided drum (20 triangles), for beyond about 60 m,
## where flanges cannot be seen. Same origin and axis as _tr_wheelset.
static func _tr_wheelset_far(r: float) -> ArrayMesh:
	var key := "wheelset_far_%.2f" % r
	if _cache.has(key): return _cache[key]
	var kit := DroneParts.Kit.new()
	var drum := DroneParts.tube(Vector3(-0.78, 0, 0), Vector3(0.78, 0, 0), r, r, 6)
	var low := 0.0
	for p: Vector3 in (drum[0] as PackedVector3Array): low = minf(low, p.y)
	var turn := 0.0 if low < -r + 0.001 else PI / 6.0                     # stand a corner of the hexagon on the rail
	kit.add(_mat("sheet"), drum, Transform3D(Basis(Vector3.RIGHT, turn), Vector3.ZERO), Color(0.2, 0.17, 0.15))
	var mesh := kit.commit()
	_cache[key] = mesh
	return mesh

## The axle centres of a vehicle's trucks: truck middles zcs, axles per truck, axle spacing, wheel radius.
static func _tr_axles(zcs: Array, axles: int, spacing: float, r: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for zc: float in zcs:
		for k in axles: out.append(Vector3(0, r, zc + (k - (axles - 1) * 0.5) * spacing))
	return out

## A truck (bogie) without its wheelsets (they are separate meshes, see _tr_wheelset): two cast side frames outside the
## wheels, each a top chord arching over a bottom chord with a window between them where the spring nest carries the
## bolster; journal boxes at the axle ends; a brake shoe against each wheel tread. axles 2 or 3, spacing in m, wheel radius r.
static func _tr_truck(kit: DroneParts.Kit, zc: float, axles: int, spacing: float, r: float) -> void:
	var pm := _mat("paint")
	var h := (axles - 1) * spacing * 0.5 + 0.24
	var col := Color(0.15, 0.13, 0.12).lerp(Color(0.32, 0.2, 0.13), 0.35 * NewModels._h(Vector3(zc, 1, 2)))     # some rust
	var w := 0.42 if axles == 2 else 0.5                                   # half width of the spring window
	# the top chord runs level through the journals and arches over the window; the bottom chord dips under it
	var top := PackedVector2Array([Vector2(-h, r - 0.1), Vector2(-h, r + 0.14), Vector2(-w, r + 0.34), Vector2(w, r + 0.34), Vector2(h, r + 0.14), Vector2(h, r - 0.1), Vector2(0, r + 0.12)])
	var bottom := PackedVector2Array([Vector2(-h + 0.1, r - 0.1), Vector2(-w, r - 0.37), Vector2(w, r - 0.37), Vector2(h - 0.1, r - 0.1), Vector2(w - 0.06, r - 0.22), Vector2(-w + 0.06, r - 0.22)])
	var stand := Transform3D(Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)), Vector3.ZERO)   # (z, y) outline stood up, thickness on x
	var top_m := DroneParts._apply(DroneParts.extrude(top, -0.09, 0.09), stand)
	var bot_m := DroneParts._apply(DroneParts.extrude(bottom, -0.08, 0.08), stand)
	for sx: float in [-1.0, 1.0]:
		var xs := sx * 0.98
		kit.add(pm, top_m, NewModels._xf(Vector3(xs, 0, zc)), col)
		kit.add(pm, bot_m, NewModels._xf(Vector3(xs, 0, zc)), col)
		# the spring nest seen through the window, carrying the bolster end
		kit.add(pm, DroneParts.tube(Vector3(xs, r - 0.22, zc), Vector3(xs, r + 0.14, zc), 0.14, 0.14, 4), Transform3D.IDENTITY, Color(0.42, 0.33, 0.24))
	# a brake beam across each outer axle on the inside of the truck, its shoe heads bearing on both treads
	for k in axles:
		var az := (k - (axles - 1) * 0.5) * spacing
		if absf(az) < 0.01: continue
		var dz := -signf(az)
		kit.add(pm, NewModels._box(Vector3(1.62, 0.26, 0.09)), Transform3D(Basis(Vector3.RIGHT, -dz * deg_to_rad(15.0)), Vector3(0, r + 0.08, zc + az + dz * (r + 0.03))), Color(0.12, 0.11, 0.1))
	kit.add(pm, NewModels._box(Vector3(2.1, 0.28, 0.45)), NewModels._xf(Vector3(0, r + 0.2, zc)), col)

static func _tr_couplers(kit: DroneParts.Kit, half: float) -> void:
	for sz: float in [-1.0, 1.0]:
		kit.add(_mat("paint"), NewModels._box(Vector3(0.3, 0.26, 0.7)), NewModels._xf(Vector3(0, 0.87, sz * (half - 0.35))), Color(0.16, 0.15, 0.14))

## A hood or cab: a long box with chamfered top corners from z0 to z1, nz bands along it; ys are extra heights on the sides
## (for stripes and grilles). Painted by f(p, n). Both ends are closed.
static func _tr_hood(z0: float, z1: float, hw: float, y0: float, y1: float, ch: float, nz: int, ys: Array, f: Callable) -> Array:
	var prof: Array[Vector2] = [Vector2(-hw, y0)]
	for y: float in ys: prof.append(Vector2(-hw, y))
	prof.append_array([Vector2(-hw, y1 - ch), Vector2(-hw, y1 - ch), Vector2(-hw + ch, y1), Vector2(-hw + ch, y1), Vector2(hw - ch, y1), Vector2(hw - ch, y1), Vector2(hw, y1 - ch), Vector2(hw, y1 - ch)])
	var rev := ys.duplicate(); rev.reverse()
	for y: float in rev: prof.append(Vector2(hw, y))
	prof.append(Vector2(hw, y0))
	var rows: Array = []
	for i in nz + 1:
		var z := lerpf(z0, z1, float(i) / nz)
		var r := PackedVector3Array()
		for q in prof: r.append(Vector3(q.x, q.y, z))
		rows.append(r)
	var mid := (y0 + y1) * 0.5
	var data := DroneParts.grid(rows, false, false, func(_i: int, _j: int, p: Vector3) -> Vector3: return Vector3(p.x, p.y - mid, 0))
	var caps := Buf.new()
	var ring: Array[Vector3] = []
	for q in [Vector2(-hw, y0), Vector2(-hw, y1 - ch), Vector2(-hw + ch, y1), Vector2(hw - ch, y1), Vector2(hw, y1 - ch), Vector2(hw, y0)]: ring.append(Vector3(q.x, q.y, 0))
	for e: float in [z0, z1]:
		var pts: Array = []
		for p in ring: pts.append(p + Vector3(0, 0, e))
		_fan(caps, pts, Vector3(0, 0, signf(e - (z0 + z1) * 0.5)), Color.WHITE)
	return NewModels._paint(_join(data, caps.data()), f)

## A ladder or grab irons drawn flat: two stiles and rungs as thin strips standing proud of a face.
static func _tr_ladder(b: Buf, base: Vector3, up: Vector3, across: Vector3, n: Vector3, rungs: int, col: Color) -> void:
	var w := 0.035
	var side := across.normalized() * w
	var upn := up.normalized() * w
	for s in [Vector3.ZERO, across]:
		var o: Vector3 = base + s + n * 0.04
		b.quad(o - side * 0.5, o + side * 0.5, o + side * 0.5 + up, o - side * 0.5 + up, col, n)
	for k in rungs:
		var o2 := base + up * ((k + 0.5) / rungs) + n * 0.045
		b.quad(o2 - upn * 0.5, o2 + across - upn * 0.5, o2 + across + upn * 0.5, o2 + upn * 0.5, col, n)

static func _locomotive() -> ArrayMesh:
	var kit := DroneParts.Kit.new()
	var pm := _mat("paint"); var gm := _mat("gloss")
	var I := Transform3D.IDENTITY
	var deck := 1.62
	var hood_col := func(p: Vector3, n: Vector3) -> Color:
		if absf(n.z) > 0.7 and (p.z < -9.9 or p.z > 9.9): return TR_YELLOW                      # the ends, for being seen
		if absf(n.x) > 0.7 and p.y > 2.45 and p.y < 2.7: return TR_YELLOW                        # the stripe along the side
		if n.y > 0.8: return TR_BLUE.darkened(0.3)                                                 # the roof
		if p.z > 6.4 and p.y > 3.25 and absf(n.x) > 0.7: return Color(0.09, 0.09, 0.1)           # radiator grilles
		return _cell(TR_BLUE, floorf(p.z / 1.03), 0.0, 0.05)                                       # door panels, a shade apart
	# ---- frame, walkway and the yellow sill stripe
	kit.add(gm, NewModels._box(Vector3(3.1, 0.42, 20.5)), NewModels._xf(Vector3(0, deck - 0.21, 0)), TR_BLUE.darkened(0.2))
	for sx: float in [-1.0, 1.0]:
		kit.add(gm, _beam(Vector3(sx * 1.565, deck - 0.3, -10.25), Vector3(sx * 1.565, deck - 0.3, 10.25), 0.03, 0.14), I, TR_YELLOW)
	# ---- long hood with fans, the cab, the short nose
	kit.add(gm, _tr_hood(-4.3, 10.05, 0.98, deck, 4.05, 0.14, 14, [2.45, 2.7, 3.25], hood_col))
	for fz: float in [7.3, 8.4, 9.45, 0.6]:
		var fr := 0.42 if fz > 1.0 else 0.6
		kit.add(pm, DroneParts.lathe(PackedVector2Array([Vector2(0, 4.08), Vector2(fr, 4.08), Vector2(fr + 0.05, 4.04)]), 10), NewModels._xf(Vector3(0, 0, fz)), Color(0.12, 0.12, 0.13))
	kit.add(pm, NewModels._box(Vector3(0.28, 0.25, 0.6)), NewModels._xf(Vector3(0, 4.15, -2.2)), Color(0.05, 0.05, 0.05))      # exhaust stack
	var cab_col := func(p: Vector3, n: Vector3) -> Color:
		if n.y > 0.8: return Color(0.2, 0.2, 0.21)
		if absf(n.x) > 0.7 and p.y > 2.45 and p.y < 2.7: return TR_YELLOW
		return TR_BLUE
	kit.add(gm, _tr_hood(-7.55, -4.3, 1.45, deck, 4.6, 0.2, 2, [2.45, 2.7], cab_col))
	kit.add(gm, _tr_hood(-10.05, -7.55, 0.98, deck, 3.55, 0.14, 2, [2.45, 2.7], hood_col))
	var glass := Buf.new()
	for sx: float in [-1.0, 1.0]:
		glass.quad(Vector3(sx * 0.12, 3.45, -7.565), Vector3(sx * 1.25, 3.45, -7.565), Vector3(sx * 1.25, 4.25, -7.565), Vector3(sx * 0.12, 4.25, -7.565), Color.WHITE, Vector3(0, 0, -1))
		glass.quad(Vector3(sx * 1.455, 3.4, -7.3), Vector3(sx * 1.455, 3.4, -5.1), Vector3(sx * 1.455, 4.25, -5.1), Vector3(sx * 1.455, 4.25, -7.3), Color.WHITE, Vector3(sx, 0, 0))
		glass.quad(Vector3(sx * 1.0, 3.45, -4.29), Vector3(sx * 1.38, 3.45, -4.29), Vector3(sx * 1.38, 4.2, -4.29), Vector3(sx * 1.0, 4.2, -4.29), Color.WHITE, Vector3(0, 0, 1))
	kit.add(_mat("glass"), glass.data())
	var lamp := _mat("lamp")
	kit.add(lamp, NewModels._box(Vector3(0.5, 0.18, 0.06)), NewModels._xf(Vector3(0, 3.3, -10.07)))
	kit.add(lamp, NewModels._box(Vector3(0.5, 0.18, 0.06)), NewModels._xf(Vector3(0, 3.75, 10.07)))
	for sx: float in [-1.0, 1.0]:
		kit.add(lamp, NewModels._box(Vector3(0.2, 0.2, 0.06)), NewModels._xf(Vector3(sx * 1.1, 1.0, -10.6)))       # ditch lights
	# ---- pilots (yellow), couplers, steps, horn
	for sz: float in [-1.0, 1.0]:
		kit.add(gm, NewModels._box(Vector3(3.0, 0.62, 0.3)), NewModels._xf(Vector3(0, 0.88, sz * 10.4), Vector3(sz * 0.25, 0, 0)), TR_YELLOW)
		for sx: float in [-1.0, 1.0]:
			kit.add(pm, NewModels._box(Vector3(0.5, 0.7, 0.55)), NewModels._xf(Vector3(sx * 1.3, deck - 0.6, sz * 9.6)), Color(0.12, 0.12, 0.13))
	_tr_couplers(kit, TR_LOCO * 0.5)
	kit.add(pm, NewModels._box(Vector3(0.14, 0.16, 0.45)), NewModels._xf(Vector3(0.5, 4.68, -6.0)), Color(0.15, 0.15, 0.16))
	# ---- fuel tank between the trucks, then the trucks (three axles, 40 inch wheels)
	kit.add(gm, DroneParts.loft([[-3.7, 0.0, 0.88, 1.12, 0.34], [-3.3, 0.0, 0.85, 1.25, 0.42], [3.3, 0.0, 0.85, 1.25, 0.42], [3.7, 0.0, 0.88, 1.12, 0.34]], 4.0, 12, true), I, Color(0.08, 0.09, 0.12))
	for zc: float in [-6.35, 6.35]: _tr_truck(kit, zc, 3, 1.65, 0.51)
	# ---- handrails along the walkways and across the ends
	var rail := Color(0.95, 0.76, 0.12)
	for sx: float in [-1.0, 1.0]:
		var x := sx * 1.48
		kit.add(pm, _beam(Vector3(x, 2.6, -4.2), Vector3(x, 2.6, 10.0), 0.05, 0.05), I, rail)
		kit.add(pm, _beam(Vector3(x, 2.6, -10.1), Vector3(x, 2.6, -7.6), 0.05, 0.05), I, rail)
		for z: float in [-10.1, -7.6, -4.2, 0.9, 5.5, 10.0]:
			kit.add(pm, _beam(Vector3(x, deck, z), Vector3(x, 2.62, z), 0.05, 0.05), I, rail)
	for sz: float in [-1.0, 1.0]:
		kit.add(pm, _beam(Vector3(-1.48, 2.6, sz * 10.1), Vector3(1.48, 2.6, sz * 10.1), 0.05, 0.05), I, rail)
	return kit.commit()

static func _boxcar() -> ArrayMesh:
	var kit := DroneParts.Kit.new()
	var pm := _mat("paint")
	var I := Transform3D.IDENTITY
	var red := Color(0.42, 0.17, 0.11)
	var hx := 1.55; var hz := 7.7; var y0 := 1.25; var y1 := 4.45
	var b := Buf.new()
	for sx: float in [-1.0, 1.0]:
		var n := Vector3(sx, 0, 0)
		var z := -hz
		for k in 20:
			var p := 2.0 * hz / 20.0
			var zp := z + 0.1
			b.quad(Vector3(sx * hx, y0, z), Vector3(sx * hx, y0, zp), Vector3(sx * hx, y1, zp), Vector3(sx * hx, y1, z), red.darkened(0.18), n)     # exterior post
			b.quad(Vector3(sx * hx, y0, zp), Vector3(sx * hx, y0, z + p), Vector3(sx * hx, y1, z + p), Vector3(sx * hx, y1, zp), _cell(red, k, sx, 0.1, 9.0), n)
			z += p
		# the sliding door with its tracks
		kit.add(pm, NewModels._box(Vector3(0.08, 3.0, 3.0)), NewModels._xf(Vector3(sx * (hx + 0.05), 2.8, 0.3)), red.darkened(0.06))
		for y: float in [1.28, 4.32]:
			kit.add(pm, _beam(Vector3(sx * (hx + 0.06), y, -1.4), Vector3(sx * (hx + 0.06), y, 4.6), 0.06, 0.1), I, red.darkened(0.3))
		_tr_ladder(b, Vector3(sx * hx, 1.35, -sx * (hz - 0.15)), Vector3(0, 2.9, 0), Vector3(0, 0, sx * 0.45), n, 5, Color(0.25, 0.1, 0.07))
	for sz: float in [-1.0, 1.0]:
		var n := Vector3(0, 0, sz)
		for j in 6:
			var ya := lerpf(y0, y1, j / 6.0); var yb := lerpf(y0, y1, (j + 1) / 6.0)
			b.quad(Vector3(-hx, ya, sz * hz), Vector3(hx, ya, sz * hz), Vector3(hx, yb, sz * hz), Vector3(-hx, yb, sz * hz), red.darkened(0.12 if j % 2 == 0 else 0.0), n)   # corrugated end
	for i in 10:
		var za := lerpf(-hz - 0.05, hz + 0.05, i / 10.0); var zb := lerpf(-hz - 0.05, hz + 0.05, (i + 1) / 10.0)
		b.quad(Vector3(-hx - 0.04, y1, za), Vector3(hx + 0.04, y1, za), Vector3(hx + 0.04, y1, zb), Vector3(-hx - 0.04, y1, zb), _cell(Color(0.38, 0.17, 0.12), i, 0.0, 0.12, 4.0), Vector3.UP)
	b.quad(Vector3(-hx, y0, -hz), Vector3(hx, y0, -hz), Vector3(hx, y0, hz), Vector3(-hx, y0, hz), Color(0.1, 0.09, 0.08), Vector3.DOWN)
	kit.add(pm, b.data())
	kit.add(pm, NewModels._box(Vector3(0.45, 0.45, 2.0 * hz + 0.3)), NewModels._xf(Vector3(0, 1.02, 0)), Color(0.12, 0.11, 0.1))     # centre sill
	_tr_couplers(kit, TR_CAR * 0.5)
	for zc: float in [-5.85, 5.85]: _tr_truck(kit, zc, 2, 1.73, 0.46)
	return kit.commit()

static func _hopper() -> ArrayMesh:
	var kit := DroneParts.Kit.new()
	var pm := _mat("paint")
	var grey := Color(0.72, 0.73, 0.72)
	var body_col := func(p: Vector3, n: Vector3) -> Color:
		var c := _cell(grey, floorf((p.z + 7.3) / 1.46), 0.0, 0.05)
		if absf(n.x) > 0.6 and int(floorf((p.z + 7.3) / 1.46)) % 2 == 1: c = c.darkened(0.08)   # side panels between the posts
		if n.y < -0.3: c = c.darkened(0.25)
		if p.y < 2.6 and absf(n.x) > 0.6: c = c.lerp(Color(0.5, 0.45, 0.38), 0.25)               # dust and grime low down
		return c
	kit.add(pm, _tr_hood(-7.3, 7.3, 1.55, 2.1, 4.5, 0.45, 10, [2.8], body_col))
	# three hopper bays narrowing to their outlet gates
	var bay := DroneParts.lathe(PackedVector2Array([Vector2(0.5, 0.78), Vector2(2.1, 2.12)]), 4)
	for zc: float in [-4.85, 0.0, 4.85]:
		var xf := Transform3D(Basis.from_scale(Vector3(0.74, 1.0, 1.03)) * Basis(Vector3.UP, PI * 0.25), Vector3(0, 0, zc))   # a square funnel stretched to the bay
		kit.add(pm, bay, xf, grey.darkened(0.15))
		kit.add(pm, NewModels._box(Vector3(0.9, 0.22, 0.9)), NewModels._xf(Vector3(0, 0.7, zc)), Color(0.25, 0.25, 0.26))
	# stub sills to the couplers, end platforms, the roof walk and hatches, ladders
	for sz: float in [-1.0, 1.0]:
		kit.add(pm, NewModels._box(Vector3(0.45, 0.45, 1.9)), NewModels._xf(Vector3(0, 1.02, sz * 7.35)), Color(0.15, 0.15, 0.15))
		kit.add(pm, NewModels._box(Vector3(3.0, 0.08, 0.7)), NewModels._xf(Vector3(0, 1.3, sz * 7.75)), Color(0.25, 0.25, 0.25))
	kit.add(pm, NewModels._box(Vector3(0.6, 0.05, 14.4)), NewModels._xf(Vector3(0, 4.53, 0)), Color(0.35, 0.35, 0.35))
	for k in 4:
		kit.add(pm, NewModels._box(Vector3(0.7, 0.14, 0.9)), NewModels._xf(Vector3(0, 4.58, -5.4 + k * 3.6)), grey.darkened(0.2))
	var b := Buf.new()
	for sz: float in [-1.0, 1.0]:
		_tr_ladder(b, Vector3(-0.6, 1.4, sz * 7.3), Vector3(0, 3.0, 0), Vector3(0.45, 0, 0), Vector3(0, 0, sz), 6, Color(0.3, 0.3, 0.3))
	kit.add(pm, b.data())
	_tr_couplers(kit, TR_CAR * 0.5)
	for zc: float in [-5.85, 5.85]: _tr_truck(kit, zc, 2, 1.73, 0.46)
	return kit.commit()

static func _tanker() -> ArrayMesh:
	var kit := DroneParts.Kit.new()
	var pm := _mat("paint"); var gm := _mat("gloss")
	var I := Transform3D.IDENTITY
	var tank_col := func(p: Vector3, n: Vector3) -> Color:
		var c := Color(0.07, 0.07, 0.075)
		if n.y > 0.3 and absf(p.z) < 1.2: c = Color(0.2, 0.19, 0.17)                              # spill stains round the dome
		if n.y < -0.3: c = c.lerp(Color(0.32, 0.28, 0.22), 0.4)                                    # road dust underneath
		return _cell(c, floorf(atan2(p.y - 2.55, p.x) * 2.0), floorf(p.z), 0.15)
	var secs := [[-7.65, 0.0, 2.55, 0.0, 0.0], [-7.55, 0.0, 2.55, 0.85, 0.85], [-7.3, 0.0, 2.55, 1.3, 1.3], [-6.9, 0.0, 2.55, 1.45, 1.45],
		[6.9, 0.0, 2.55, 1.45, 1.45], [7.3, 0.0, 2.55, 1.3, 1.3], [7.55, 0.0, 2.55, 0.85, 0.85], [7.65, 0.0, 2.55, 0.0, 0.0]]
	kit.add(gm, NewModels._paint(DroneParts.loft(secs, 2.0, 14), tank_col))
	kit.add(gm, DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0.62, 3.8), Vector2(0.62, 4.1), Vector2(0.5, 4.22), Vector2(0, 4.26)])), 10), I, Color(0.12, 0.12, 0.12))
	kit.add(pm, NewModels._box(Vector3(1.8, 0.05, 1.8)), NewModels._xf(Vector3(0, 3.99, 0)), Color(0.3, 0.3, 0.3))
	for sx: float in [-1.0, 1.0]:
		kit.add(pm, _beam(Vector3(sx * 0.9, 4.95, -0.9), Vector3(sx * 0.9, 4.95, 0.9), 0.04, 0.04), I, Color(0.85, 0.7, 0.15))
		kit.add(pm, _beam(Vector3(sx * 0.9, 4.0, 0.0), Vector3(sx * 0.9, 4.95, 0.0), 0.04, 0.04), I, Color(0.85, 0.7, 0.15))
	var b := Buf.new()
	for sx: float in [-1.0, 1.0]:
		_tr_ladder(b, Vector3(sx * 1.5, 1.25, 0.65), Vector3(-sx * 0.75, 2.7, 0), Vector3(0, 0, 0.45), Vector3(sx, 0.25, 0).normalized(), 6, Color(0.3, 0.3, 0.3))
	kit.add(pm, b.data())
	for sz: float in [-1.0, 1.0]:
		kit.add(pm, NewModels._box(Vector3(0.45, 0.45, 2.4)), NewModels._xf(Vector3(0, 1.02, sz * 7.1)), Color(0.12, 0.12, 0.12))
		kit.add(pm, NewModels._box(Vector3(3.0, 0.08, 0.8)), NewModels._xf(Vector3(0, 1.28, sz * 7.7)), Color(0.22, 0.22, 0.22))
		kit.add(pm, NewModels._box(Vector3(2.4, 0.4, 0.5)), NewModels._xf(Vector3(0, 1.25, sz * 5.85)), Color(0.12, 0.12, 0.12))    # saddle on the bolster
	_tr_couplers(kit, TR_CAR * 0.5)
	for zc: float in [-5.85, 5.85]: _tr_truck(kit, zc, 2, 1.73, 0.46)
	return kit.commit()

static func _flatcar(loaded: bool) -> ArrayMesh:
	var kit := DroneParts.Kit.new()
	var pm := _mat("paint")
	var steel := Color(0.14, 0.13, 0.12)
	kit.add(pm, NewModels._box(Vector3(2.8, 0.12, 15.6)), NewModels._xf(Vector3(0, 1.24, 0)), steel)
	var b := Buf.new()
	for i in 20:
		var za := lerpf(-7.8, 7.8, i / 20.0); var zb := lerpf(-7.8, 7.8, (i + 1) / 20.0)
		b.quad(Vector3(-1.38, 1.305, za), Vector3(1.38, 1.305, za), Vector3(1.38, 1.305, zb), Vector3(-1.38, 1.305, zb), _cell(Color(0.42, 0.33, 0.24), i, 0.0, 0.18), Vector3.UP)   # deck boards
	kit.add(pm, b.data())
	var belly := PackedVector2Array([Vector2(-7.8, 1.24), Vector2(7.8, 1.24), Vector2(7.8, 0.98), Vector2(4.4, 0.98), Vector2(3.0, 0.6), Vector2(-3.0, 0.6), Vector2(-4.4, 0.98), Vector2(-7.8, 0.98)])
	var sill := DroneParts.extrude(belly, -0.08, 0.08)
	for sx: float in [-1.0, 1.0]:
		kit.add(pm, sill, Transform3D(Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)), Vector3(sx * 1.32, 0, 0)), steel)
	kit.add(pm, NewModels._box(Vector3(0.5, 0.5, 15.6)), NewModels._xf(Vector3(0, 0.95, 0)), steel)
	if loaded:
		# bulkheads at the ends and three stacks of lumber, the upper bundles in wrap
		for sz: float in [-1.0, 1.0]:
			kit.add(pm, NewModels._box(Vector3(2.8, 2.5, 0.2)), NewModels._xf(Vector3(0, 2.55, sz * 7.6)), Color(0.2, 0.22, 0.2))
		for k in 3:
			var zc := -4.75 + k * 4.75
			kit.add(pm, NewModels._box(Vector3(2.5, 1.0, 4.5)), NewModels._xf(Vector3(0, 1.88, zc)), _cell(Color(0.82, 0.69, 0.48), k, 0.0, 0.08))
			kit.add(pm, NewModels._box(Vector3(2.5, 1.0, 4.5)), NewModels._xf(Vector3(0, 2.95, zc)), Color(0.86, 0.86, 0.82) if k != 1 else _cell(Color(0.8, 0.67, 0.46), k, 1.0, 0.08))
	_tr_couplers(kit, TR_CAR * 0.5)
	for zc: float in [-5.85, 5.85]: _tr_truck(kit, zc, 2, 1.73, 0.46)
	return kit.commit()

## The train: {"locomotive", "boxcar", "hopper", "tanker", "flatcar", "flatcar_empty": ArrayMesh, "car_length", "loco_length",
## "consist", "gauge"}. Each mesh has its origin at the top of the rail under its middle, its front towards -z. "consist" is
## an Array of [kind, z] for the locomotive and `cars` cars behind it (the train runs towards -z, z is each middle).
static func freight_train(cars := 12) -> Dictionary:
	if not _cache.has("train"):
		_cache["train"] = {"locomotive": _locomotive(), "boxcar": _boxcar(), "hopper": _hopper(), "tanker": _tanker(), "flatcar": _flatcar(true), "flatcar_empty": _flatcar(false)}
	var meshes: Dictionary = _cache["train"]
	var kinds := ["boxcar", "hopper", "hopper", "tanker", "flatcar", "boxcar", "hopper", "tanker", "tanker", "flatcar_empty", "boxcar", "hopper"]
	var consist: Array = [["locomotive", 0.0]]
	for k in cars:
		var pick: String = kinds[k % kinds.size()]
		consist.append([pick,TR_LOCO * 0.5 + TR_CAR * (k + 0.5)])
	var out := meshes.duplicate()
	out["car_length"] = TR_CAR; out["loco_length"] = TR_LOCO; out["consist"] = consist; out["gauge"] = TR_GAUGE
	# the wheelsets, separate so the game can turn them: per vehicle kind the wheelset mesh, the axle centres in that
	# vehicle's space and the wheel radius; turn each about its own +X by -distance / radius (rolling towards -z).
	# "mesh_far" is the plain drum for distant cars (swap beyond about 60 m to keep a whole train cheap).
	var loco_w := {"mesh": _tr_wheelset(TR_LOCO_WHEEL), "mesh_far": _tr_wheelset_far(TR_LOCO_WHEEL), "positions": _tr_axles(TR_LOCO_TRUCKS, 3, 1.65, TR_LOCO_WHEEL), "radius": TR_LOCO_WHEEL}
	var wheels := {"locomotive": loco_w}
	for kind in ["boxcar", "hopper", "tanker", "flatcar", "flatcar_empty"]:
		wheels[kind] = {"mesh": _tr_wheelset(TR_CAR_WHEEL), "mesh_far": _tr_wheelset_far(TR_CAR_WHEEL), "positions": _tr_axles(TR_CAR_TRUCKS, 2, 1.73, TR_CAR_WHEEL), "radius": TR_CAR_WHEEL}
	out["wheels"] = wheels
	out["wheel_axis"] = Vector3.RIGHT
	return out

## A 20 m piece of single standard-gauge track along z: two rails, 28 timber sleepers, a ballast bed. Origin: the top of the
## rail at the middle; the foot of the ballast is 0.62 m below it, so lift the piece 0.62 m above the ground. Pieces join
## end to end every 20 m.
static func track_section() -> ArrayMesh:
	if _cache.has("track"): return _cache["track"]
	var kit := DroneParts.Kit.new()
	var pm := _mat("paint")
	var b := Buf.new()
	# ballast: a flat top and two shoulders, in patches of slightly different stone
	var top := -0.19; var foot := -0.62
	for i in 10:
		var za := -10.0 + i * 2.0; var zb := za + 2.0
		b.quad(Vector3(-1.6, top, za), Vector3(1.6, top, za), Vector3(1.6, top, zb), Vector3(-1.6, top, zb), _cell(Color(0.36, 0.35, 0.34), i, 0.0, 0.08), Vector3.UP)
		for sx: float in [-1.0, 1.0]:
			b.quad(Vector3(sx * 1.6, top, za), Vector3(sx * 2.6, foot, za), Vector3(sx * 2.6, foot, zb), Vector3(sx * 1.6, top, zb), _cell(Color(0.4, 0.39, 0.37), i, sx, 0.1), Vector3(sx * 0.43, 1.0, 0).normalized())
	# sleepers: the top and the four sides standing above the ballast
	for k in 28:
		var zc := -10.0 + (k + 0.5) * 20.0 / 28.0
		var za := zc - 0.12; var zb := zc + 0.12
		var y1 := -0.16; var y0 := top - 0.01
		var col := _cell(Color(0.27, 0.21, 0.16), k, 0.0, 0.15)
		b.quad(Vector3(-1.3, y1, za), Vector3(1.3, y1, za), Vector3(1.3, y1, zb), Vector3(-1.3, y1, zb), col, Vector3.UP)
		b.quad(Vector3(-1.3, y0, za), Vector3(1.3, y0, za), Vector3(1.3, y1, za), Vector3(-1.3, y1, za), col.darkened(0.2), Vector3(0, 0, -1))
		b.quad(Vector3(-1.3, y0, zb), Vector3(1.3, y0, zb), Vector3(1.3, y1, zb), Vector3(-1.3, y1, zb), col.darkened(0.2), Vector3(0, 0, 1))
		for sx: float in [-1.0, 1.0]:
			b.quad(Vector3(sx * 1.3, y0, za), Vector3(sx * 1.3, y0, zb), Vector3(sx * 1.3, y1, zb), Vector3(sx * 1.3, y1, za), col.darkened(0.2), Vector3(sx, 0, 0))
	kit.add(pm, b.data())
	# rails: a rusty foot and web, a bright worn head
	var rail_col := func(_p: Vector3, n: Vector3) -> Color: return Color(0.66, 0.66, 0.67) if n.y > 0.5 else Color(0.33, 0.21, 0.14)
	for sx: float in [-1.0, 1.0]:
		var x := sx * (TR_GAUGE * 0.5 + 0.036)
		kit.add(_mat("sheet"), NewModels._paint(NewModels._box(Vector3(0.072, 0.05, 20.0)), rail_col), NewModels._xf(Vector3(x, -0.025, 0)))
		kit.add(_mat("sheet"), NewModels._box(Vector3(0.14, 0.11, 20.0)), NewModels._xf(Vector3(x, -0.105, 0)), Color(0.3, 0.2, 0.14))
	var mesh := kit.commit()
	_cache["track"] = mesh
	return mesh

# ================================================================== aircraft
# A light single-engine rescue helicopter of the AStar kind: a rounded cabin with a big windscreen and chin windows, a
# cowling over the engine, a slim tail boom with a stabiliser and end plates, fins above and below, skids, a rescue hoist
# and a searchlight. White and red, no operator marks. Three main blades 10 m across, a two-bladed tail rotor on the left.
const HC_ROTOR := Vector3(0.0, 3.3, 0.0)
const HC_TAIL := Vector3(-0.32, 2.62, 6.95)
const SYM4 := [Vector2(0, 0), Vector2(0.3, 0.5), Vector2(1.0, 0.0), Vector2(0.3, -0.5)]

## The helicopter: {"body", "main_rotor", "rotor_pivot", "tail_rotor", "tail_pivot", "main_spin_sign", "tail_spin_sign",
## "rotor_radius", "tail_radius", "length"}. Origin: the ground under the mast, between the skids. The main rotor turns about
## its own +Y at rotor_pivot (clockwise seen from above: rotate by main_spin_sign * omega * t); the tail rotor about its own
## +X at tail_pivot (about 5 times as fast).
static func helicopter() -> Dictionary:
	if _cache.has("helicopter"): return _cache["helicopter"]
	var gm := _mat("gloss")
	var I := Transform3D.IDENTITY
	var white := Color(0.94, 0.94, 0.93); var red := Color(0.8, 0.07, 0.06); var win := Color(0.04, 0.06, 0.09); var dark := Color(0.13, 0.13, 0.14)
	var kit := DroneParts.Kit.new()
	var body := [[-3.68, 0.0, 1.3, 0.0, 0.0], [-3.62, 0.0, 1.3, 0.22, 0.25], [-3.45, 0.0, 1.36, 0.48, 0.52], [-3.15, 0.0, 1.45, 0.7, 0.74], [-2.7, 0.0, 1.53, 0.84, 0.86],
		[-2.25, 0.0, 1.57, 0.89, 0.91], [-1.6, 0.0, 1.59, 0.91, 0.93], [-0.95, 0.0, 1.6, 0.92, 0.93], [-0.75, 0.0, 1.6, 0.92, 0.93], [0.0, 0.0, 1.62, 0.9, 0.92],
		[0.65, 0.0, 1.66, 0.84, 0.86], [1.25, 0.0, 1.78, 0.66, 0.68], [1.9, 0.0, 1.93, 0.4, 0.43], [2.6, 0.0, 2.02, 0.24, 0.27], [4.6, 0.0, 2.08, 0.18, 0.2],
		[6.6, 0.0, 2.12, 0.14, 0.16], [7.2, 0.0, 2.14, 0.12, 0.14], [7.25, 0.0, 2.14, 0.0, 0.0]]
	# Colours are picked by the face's angle round the ring and by the station span it sits in, so whole quads change
	# colour together and the window edges run along the mesh lines instead of zig-zagging.
	var body_col := func(p: Vector3, _n: Vector3) -> Color:
		var cy := 1.6
		for k in range(1, body.size()):
			if p.z <= float(body[k][0]):
				cy = lerpf(float(body[k - 1][2]), float(body[k][2]), inverse_lerp(float(body[k - 1][0]), float(body[k][0]), p.z)); break
		var ang := rad_to_deg(atan2(p.y - cy, absf(p.x)))         # 0 at the side, 90 on top, -90 underneath
		if p.z < -2.25 and ang > 18.0: return win                                                # windscreen
		if p.z < -2.7 and p.z > -3.5 and ang < -18.0 and ang > -54.0: return win                 # chin windows
		if ang > 0.0 and ang < 36.0 and ((p.z > -2.25 and p.z < -0.95) or (p.z > -0.75 and p.z < 0.65)): return win   # door windows
		if ang < 0.0: return red                                                                 # red below the waist, the boom too
		if p.z > 0.65 and p.z < 1.9 and ang < 18.0: return red
		return white
	kit.add(gm, NewModels._paint(DroneParts.loft(body, 2.3, 20), body_col))
	var cowl := [[-1.0, 0.0, 2.45, 0.0, 0.0], [-0.85, 0.0, 2.48, 0.35, 0.22], [-0.4, 0.0, 2.55, 0.55, 0.38], [0.6, 0.0, 2.6, 0.55, 0.42], [1.4, 0.0, 2.55, 0.45, 0.32], [2.0, 0.0, 2.3, 0.22, 0.18], [2.15, 0.0, 2.25, 0.0, 0.0]]
	kit.add(gm, DroneParts.loft(cowl, 3.0, 14), I, white)
	for sx: float in [-1.0, 1.0]:
		kit.add(gm, NewModels._box(Vector3(0.05, 0.2, 0.55)), NewModels._xf(Vector3(sx * 0.53, 2.62, -0.2)), dark)        # engine intake grilles
	kit.add(gm, DroneParts.tube(Vector3(0, 2.9, 0), Vector3(0, HC_ROTOR.y - 0.05, 0), 0.11, 0.1, 8), I, dark)                   # mast
	kit.add(gm, DroneParts.tube(Vector3(0.28, 2.78, 1.45), Vector3(0.42, 2.82, 2.05), 0.13, 0.14, 8), I, Color(0.22, 0.22, 0.23))   # exhaust
	# tail: stabiliser with end plates, the upper fin and the ventral fin with its skid
	var sym := PackedVector2Array(SYM4)
	kit.add(gm, NewModels._foil([[Vector3(-1.2, 2.13, 5.62), Vector3(0, 0, 0.5), Vector3(0, 0.07, 0)], [Vector3(0, 2.13, 5.52), Vector3(0, 0, 0.6), Vector3(0, 0.08, 0)], [Vector3(1.2, 2.13, 5.62), Vector3(0, 0, 0.5), Vector3(0, 0.07, 0)]], sym), I, white)
	for sx: float in [-1.0, 1.0]:
		kit.add(gm, NewModels._foil([[Vector3(sx * 1.22, 1.9, 5.6), Vector3(0, 0, 0.5), Vector3(0.06, 0, 0)], [Vector3(sx * 1.22, 2.45, 5.72), Vector3(0, 0, 0.4), Vector3(0.05, 0, 0)]], sym), I, red)
	kit.add(gm, NewModels._foil([[Vector3(0, 2.1, 6.3), Vector3(0, 0, 0.9), Vector3(0.14, 0, 0)], [Vector3(0, 3.05, 7.0), Vector3(0, 0, 0.5), Vector3(0.08, 0, 0)]], sym), I, red)
	kit.add(gm, NewModels._foil([[Vector3(0, 2.1, 6.6), Vector3(0, 0, 0.65), Vector3(0.1, 0, 0)], [Vector3(0, 1.6, 6.95), Vector3(0, 0, 0.4), Vector3(0.06, 0, 0)]], sym), I, red)
	kit.add(gm, DroneParts.tube(Vector3(0, 1.62, 7.1), Vector3(0, 1.5, 7.45), 0.025, 0.02, 5), I, dark)
	kit.add(gm, NewModels._box(Vector3(0.22, 0.3, 0.3)), NewModels._xf(Vector3(-0.12, HC_TAIL.y, HC_TAIL.z)), Color(0.5, 0.5, 0.52))   # tail gearbox
	# skids: two tubes turned up at the front on two bowed cross tubes
	var skid := Color(0.55, 0.56, 0.58)
	for sx: float in [-1.0, 1.0]:
		var pts := [Vector3(sx * 1.1, 0.05, 1.55), Vector3(sx * 1.1, 0.05, -1.6), Vector3(sx * 1.1, 0.12, -2.05), Vector3(sx * 1.1, 0.36, -2.28)]
		var rr := [0.045, 0.045, 0.045, 0.04]
		kit.add(gm, NewModels._sweep(pts, rr, rr, 6, Vector3.UP), I, skid)
	for z: float in [-1.3, 0.9]:
		var pts2 := [Vector3(-1.1, 0.05, z), Vector3(-1.02, 0.35, z), Vector3(-0.82, 0.66, z), Vector3(-0.4, 0.76, z), Vector3(0.4, 0.76, z), Vector3(0.82, 0.66, z), Vector3(1.02, 0.35, z), Vector3(1.1, 0.05, z)]
		var r2: Array = []; r2.resize(pts2.size()); r2.fill(0.045)
		kit.add(gm, NewModels._sweep(pts2, r2, r2, 6, Vector3(0, 0, 1)), I, skid)
	# rescue kit: a hoist on an arm over the right door, a searchlight under the nose, antennas
	kit.add(gm, _beam(Vector3(0.75, 2.45, -1.4), Vector3(1.3, 2.45, -1.4), 0.1, 0.1), I, Color(0.6, 0.6, 0.62))
	kit.add(gm, DroneParts.rbox(Vector3(0.24, 0.26, 0.42), 5.0, 8), NewModels._xf(Vector3(1.3, 2.33, -1.4)), Color(0.6, 0.6, 0.62))
	var light := Transform3D(Basis(Vector3.RIGHT, -PI * 0.6), Vector3(0.3, 0.7, -2.55))
	kit.add(gm, DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, 0.0), Vector2(0.14, 0.0), Vector2(0.14, 0.12), Vector2(0, 0.14)])), 8), light, dark)
	kit.add(_mat("lamp"), DroneParts.lathe(PackedVector2Array([Vector2(0, -0.005), Vector2(0.12, -0.005)]), 8), light)
	kit.add(gm, _beam(Vector3(0, 2.5, 1.3), Vector3(0, 2.9, 1.5), 0.03, 0.08), I, dark)
	kit.add(gm, _beam(Vector3(0, 0.7, -0.5), Vector3(0, 0.45, -0.3), 0.03, 0.08), I, dark)
	# ---- main rotor: hub, grips and three blades with pale tips; its own mesh, turning about +Y
	var rk := DroneParts.Kit.new()
	rk.add(gm, DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, -0.1), Vector2(0.28, -0.1), Vector2(0.28, 0.1), Vector2(0.12, 0.2), Vector2(0, 0.24)])), 10), I, Color(0.3, 0.3, 0.32))
	var blade_col := func(p: Vector3, _n: Vector3) -> Color: return Color(0.9, 0.85, 0.3) if p.x > 4.75 else Color(0.14, 0.14, 0.15)
	var blade := NewModels._paint(NewModels._foil([[Vector3(0.45, 0.02, 0.12), Vector3(0, 0, -0.3), Vector3(0, 0.035, 0)], [Vector3(4.75, -0.02, 0.12), Vector3(0, 0, -0.3), Vector3(0, 0.03, 0)],
		[Vector3(5.0, -0.03, 0.1), Vector3(0, 0, -0.26), Vector3(0, 0.025, 0)]], PackedVector2Array(NewModels.LOOP4)), blade_col)
	for b in 3:
		var bb := Basis(Vector3.UP, TAU * b / 3.0)
		rk.add(gm, blade, Transform3D(bb, Vector3.ZERO))
		rk.add(gm, NewModels._box(Vector3(0.55, 0.12, 0.16)), Transform3D(bb, bb * Vector3(0.4, 0, 0)), Color(0.3, 0.3, 0.32))
	# ---- tail rotor: two blades in the y-z plane, turning about +X
	var tk := DroneParts.Kit.new()
	var tblade := NewModels._foil([[Vector3(0, 0.1, 0.06), Vector3(0, 0, -0.14), Vector3(0.02, 0, 0)], [Vector3(0, 0.93, 0.05), Vector3(0, 0, -0.12), Vector3(0.015, 0, 0)]], PackedVector2Array(NewModels.LOOP4))
	for b in 2:
		tk.add(gm, tblade, Transform3D(Basis(Vector3.RIGHT, PI * b), Vector3.ZERO), red if b == 0 else white)
	tk.add(gm, DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, -0.06), Vector2(0.08, -0.06), Vector2(0.08, 0.04), Vector2(0, 0.08)])), 8), Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3.ZERO), Color(0.3, 0.3, 0.32))
	var out := {"body": kit.commit(), "main_rotor": rk.commit(), "rotor_pivot": HC_ROTOR, "tail_rotor": tk.commit(), "tail_pivot": HC_TAIL,
		"main_spin_sign": -1.0, "tail_spin_sign": 1.0, "rotor_radius": 5.0, "tail_radius": 0.93, "length": 10.93}
	_cache["helicopter"] = out
	return out

## A twin-jet narrowbody seen far away (made to read as an airliner when it is 60 px long): 38 m long, 35.8 m span, low
## swept wings with winglets, two engines under the wings, a tall fin. Plain white, grey belly, a plain dark blue fin, no
## marks. Origin: the middle of the fuselage at the wing root; nose towards -z.
static func airliner_far() -> ArrayMesh:
	if _cache.has("airliner"): return _cache["airliner"]
	var kit := DroneParts.Kit.new()
	var pm := _mat("paint")
	var I := Transform3D.IDENTITY
	var fus := [[-19.0, 0.0, 0.2, 0.0, 0.0], [-18.7, 0.0, 0.25, 0.6, 0.65], [-17.6, 0.0, 0.12, 1.5, 1.6], [-15.5, 0.0, 0.0, 1.95, 2.0], [10.0, 0.0, 0.1, 1.95, 2.0],
		[14.5, 0.0, 0.6, 1.3, 1.3], [18.2, 0.0, 1.2, 0.45, 0.45], [19.0, 0.0, 1.3, 0.0, 0.0]]
	var fus_col := func(p: Vector3, n: Vector3) -> Color:
		if p.z < -17.0 and p.y > 0.4 and n.y > 0.0: return Color(0.06, 0.07, 0.1)               # cockpit windows
		if n.y < -0.35: return Color(0.68, 0.7, 0.72)
		return Color(0.95, 0.95, 0.95)
	kit.add(pm, NewModels._paint(DroneParts.loft(fus, 2.0, 10), fus_col))
	var loop := PackedVector2Array(NewModels.LOOP4)
	var sym := PackedVector2Array(SYM4)
	var grey := Color(0.75, 0.76, 0.78); var fin := Color(0.1, 0.2, 0.45)
	var eng := func(p: Vector3, _n: Vector3) -> Color: return Color(0.12, 0.12, 0.13) if p.y < 0.4 else Color(0.9, 0.9, 0.91)
	var nac := NewModels._paint(DroneParts.lathe(PackedVector2Array([Vector2(0, 0.3), Vector2(0.85, 0.05), Vector2(1.05, 0.5), Vector2(1.0, 2.9), Vector2(0.55, 4.2)]), 8), eng)
	for sx: float in [-1.0, 1.0]:
		kit.add(pm, NewModels._foil([[Vector3(sx * 1.5, -1.3, -3.0), Vector3(0, 0, 7.0), Vector3(0, 0.6, 0)], [Vector3(sx * 6.0, -0.95, 0.2), Vector3(0, 0, 4.6), Vector3(0, 0.35, 0)],
			[Vector3(sx * 17.9, 0.3, 7.2), Vector3(0, 0, 1.5), Vector3(0, 0.12, 0)]], loop), I, grey)
		kit.add(pm, NewModels._foil([[Vector3(sx * 17.85, 0.3, 7.25), Vector3(0, 0, 1.4), Vector3(sx * 0.08, 0, 0)], [Vector3(sx * 17.95, 2.1, 8.35), Vector3(0, 0, 0.6), Vector3(sx * 0.05, 0, 0)]], sym), I, fin)
		kit.add(pm, NewModels._foil([[Vector3(sx * 0.5, 1.2, 14.5), Vector3(0, 0, 3.6), Vector3(0, 0.25, 0)], [Vector3(sx * 6.2, 1.6, 17.2), Vector3(0, 0, 1.5), Vector3(0, 0.1, 0)]], sym), I, grey)
		kit.add(pm, nac, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * 5.9, -2.15, -6.6)))
		kit.add(pm, _beam(Vector3(sx * 5.9, -1.35, -4.4), Vector3(sx * 5.9, -1.15, 0.8), 0.25, 0.55), I, grey)
	kit.add(pm, NewModels._foil([[Vector3(0, 1.4, 12.0), Vector3(0, 0, 5.8), Vector3(0.45, 0, 0)], [Vector3(0, 7.6, 16.3), Vector3(0, 0, 2.5), Vector3(0.2, 0, 0)]], sym), I, fin)
	var mesh := kit.commit()
	_cache["airliner"] = mesh
	return mesh

# ================================================================== kites and a flag
## A kite, 1 m across. kind 0: a diamond kite (two colours, bowed cross spar) with a 2.5 m tail of bows; kind 1: a delta
## with rainbow panels, a keel and a short streamer. The sail faces -Z (towards the flyer); the tail streams to +Z and down.
## Origin: the tow point where the line ties on (on the bridle, about 0.3 m in front of the sail). One mesh, double-sided.
static func kite(kind := 0) -> ArrayMesh:
	var key := "kite_%d" % kind
	if _cache.has(key): return _cache[key]
	var cm := _mat("cloth")
	var I := Transform3D.IDENTITY
	var b := Buf.new()
	var kit := DroneParts.Kit.new()
	var spar := Color(0.2, 0.15, 0.1)
	var fwd := Vector3(0, 0, -1)
	if kind == 1:
		var tow := Vector3(0, 0.05, -0.28)
		var nose := Vector3(0, 0.5, 0) - tow; var tail := Vector3(0, -0.22, 0.02) - tow
		var cols: Array[Color] = [Color(0.9, 0.1, 0.1), Color(1.0, 0.55, 0.05), Color(1.0, 0.88, 0.1), Color(0.15, 0.7, 0.25), Color(0.1, 0.45, 0.9), Color(0.5, 0.2, 0.75)]
		for sx: float in [-1.0, 1.0]:
			var tip := Vector3(sx * 0.5, -0.12, 0.1) - tow
			for k in 3:
				var q0 := tip.lerp(tail, k / 3.0); var q1 := tip.lerp(tail, (k + 1) / 3.0)
				b.tri(nose, q0, q1, cols[k if sx < 0.0 else 5 - k], fwd)
			kit.add(cm, _beam(nose + Vector3(0, 0, 0.01), tip + Vector3(0, 0, 0.01), 0.012, 0.012), I, spar)      # leading edge spars
		b.tri(Vector3(0, 0.32, 0) - tow, Vector3(0, -0.12, 0) - tow, Vector3.ZERO, Color(0.95, 0.95, 0.95), Vector3(1, 0, 0))   # keel
		kit.add(cm, _beam(nose + Vector3(0, 0, 0.012), tail + Vector3(0, 0, 0.012), 0.012, 0.012), I, spar)
		kit.add(cm, _beam(Vector3(-0.3, 0.02, 0.07) - tow, Vector3(0.3, 0.02, 0.07) - tow, 0.01, 0.01), I, spar)   # spreader
		for k in 3:                                                                                 # a streamer from the tail
			var y0 := -0.4 * k; var y1 := -0.4 * (k + 1)
			b.quad(tail + Vector3(-0.03, y0, 0.25 * k), tail + Vector3(0.03, y0, 0.25 * k), tail + Vector3(0.03, y1, 0.25 * (k + 1)), tail + Vector3(-0.03, y1, 0.25 * (k + 1)), cols[k * 2], fwd)
	else:
		var tow := Vector3(0, -0.1, -0.3)
		var top := Vector3(0, 0.36, 0) - tow; var bot := Vector3(0, -0.84, 0) - tow
		var lft := Vector3(-0.5, 0, 0.07) - tow; var rgt := Vector3(0.5, 0, 0.07) - tow; var mid := Vector3(0, 0, 0) - tow
		var red := Color(0.92, 0.12, 0.1); var yel := Color(1.0, 0.82, 0.1)
		b.tri(top, rgt, mid, red, fwd); b.tri(rgt, bot, mid, yel, fwd); b.tri(bot, lft, mid, red, fwd); b.tri(lft, top, mid, yel, fwd)
		kit.add(cm, _beam(top + Vector3(0, 0, 0.012), bot + Vector3(0, 0, 0.012), 0.012, 0.012), I, spar)
		kit.add(cm, _beam(lft + Vector3(0, 0, 0.012), mid + Vector3(0, 0, 0.012), 0.012, 0.012), I, spar)
		kit.add(cm, _beam(mid + Vector3(0, 0, 0.012), rgt + Vector3(0, 0, 0.012), 0.012, 0.012), I, spar)
		# the bridle legs to the tow point, then the tail line with its bows
		for a: Vector3 in [Vector3(0, 0.2, 0) - tow, Vector3(0, -0.6, 0) - tow]:
			b.quad(a + Vector3(-0.004, 0, 0), a + Vector3(0.004, 0, 0), Vector3(0.004, 0, 0), Vector3(-0.004, 0, 0), Color(0.9, 0.9, 0.9), Vector3(0, 1, 0))
		var tail_end := bot + Vector3(0, -2.2, 1.2)
		b.quad(bot + Vector3(-0.006, 0, 0), bot + Vector3(0.006, 0, 0), tail_end + Vector3(0.006, 0, 0), tail_end + Vector3(-0.006, 0, 0), Color(0.9, 0.9, 0.9), fwd)
		for k in 6:
			var p := bot.lerp(tail_end, (k + 1) / 6.5)
			var c := red if k % 2 == 0 else Color(0.1, 0.4, 0.9)
			for sx: float in [-1.0, 1.0]:
				b.tri(p, p + Vector3(sx * 0.09, 0.045, 0), p + Vector3(sx * 0.09, -0.045, 0), c, fwd)
	kit.add(cm, b.data())
	var mesh := kit.commit()
	_cache[key] = mesh
	return mesh

## A kite line: a thin straight cord 1 m long from the origin along +Z (two crossed strips, so it shows from any side).
## Scale z to the line's length and turn +Z towards the flyer's hand.
static func kite_line() -> ArrayMesh:
	if _cache.has("kite_line"): return _cache["kite_line"]
	var b := Buf.new()
	var w := 0.006
	var c := Color(0.92, 0.92, 0.9)
	b.quad(Vector3(-w, 0, 0), Vector3(w, 0, 0), Vector3(w, 0, 1), Vector3(-w, 0, 1), c, Vector3.UP)
	b.quad(Vector3(0, -w, 0), Vector3(0, w, 0), Vector3(0, w, 1), Vector3(0, -w, 1), c, Vector3.RIGHT)
	var kit := DroneParts.Kit.new()
	kit.add(_mat("cloth"), b.data())
	var mesh := kit.commit()
	_cache["kite_line"] = mesh
	return mesh

## A 9 m white flagpole with a ball on top, a halyard and a 1.8 x 0.9 m flag. scheme picks a plain colour (0 red, 1 blue,
## 2 yellow, 3 green; no real flags). Returns {"pole", "cloth", "cloth_origin", "cloth_size"}. The pole's origin is its foot.
## The cloth is a flat grid of 20 x 12 quads in its own x-y plane: origin at the top of the hoist (where it ties to the
## halyard), x out along the fly to 1.8, y down to -0.9, normal +Z, double-sided. UV.x runs 0 at the hoist to 1 at the fly
## and UV.y 0 at the top to 1 at the bottom, so a wind shader can wave it more towards the fly. Place it at cloth_origin and
## turn the whole flag (pole and cloth) about +Y so +X points downwind.
static func flag(scheme := 0) -> Dictionary:
	var key := "flag_%d" % scheme
	if _cache.has(key): return _cache[key]
	var I := Transform3D.IDENTITY
	var pk := DroneParts.Kit.new()
	var white := Color(0.92, 0.92, 0.9)
	pk.add(_mat("sheet"), DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0.16, 0.0), Vector2(0.16, 0.12), Vector2(0.07, 0.16)])), 10), I, Color(0.55, 0.55, 0.53))
	pk.add(_mat("gloss"), DroneParts.tube(Vector3(0, 0.1, 0), Vector3(0, 8.95, 0), 0.065, 0.04, 8), I, white)
	pk.add(_mat("gloss"), DroneParts.sphere(0.075, 8), NewModels._xf(Vector3(0, 9.02, 0)), Color(0.85, 0.7, 0.25))
	var hb := Buf.new()
	hb.quad(Vector3(0.05, 1.2, -0.004), Vector3(0.05, 1.2, 0.004), Vector3(0.05, 8.9, 0.004), Vector3(0.05, 8.9, -0.004), Color(0.85, 0.85, 0.85), Vector3(1, 0, 0))
	pk.add(_mat("cloth"), hb.data())
	pk.add(_mat("sheet"), NewModels._box(Vector3(0.03, 0.15, 0.04)), NewModels._xf(Vector3(0.055, 1.2, 0)), Color(0.4, 0.4, 0.42))   # cleat
	var colours: Array[Color] = [Color(0.8, 0.08, 0.07), Color(0.08, 0.22, 0.6), Color(0.98, 0.78, 0.1), Color(0.08, 0.48, 0.22)]
	var col := colours[posmod(scheme, colours.size())]
	var nu := 20; var nv := 12
	var w := 1.8; var h := 0.9
	var v := PackedVector3Array(); var nr := PackedVector3Array(); var cs := PackedColorArray(); var uv := PackedVector2Array(); var idx := PackedInt32Array()
	for j in nv + 1:
		for i in nu + 1:
			v.append(Vector3(w * i / nu, -h * j / nv, 0)); nr.append(Vector3(0, 0, 1)); uv.append(Vector2(float(i) / nu, float(j) / nv))
			cs.append(white if i == 0 else col)                          # the canvas heading at the hoist
	for j in nv:
		for i in nu:
			var a := j * (nu + 1) + i; var c := a + nu + 1
			idx.append_array([a, a + 1, c, a + 1, c + 1, c])             # clockwise seen from +Z (Godot's front face)
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v; arrays[Mesh.ARRAY_NORMAL] = nr; arrays[Mesh.ARRAY_COLOR] = cs; arrays[Mesh.ARRAY_TEX_UV] = uv; arrays[Mesh.ARRAY_INDEX] = idx
	var cloth := ArrayMesh.new()
	cloth.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	cloth.surface_set_material(0, _mat("cloth"))
	var out := {"pole": pk.commit(), "cloth": cloth, "cloth_origin": Vector3(0.07, 8.85, 0), "cloth_size": Vector2(w, h)}
	_cache[key] = out
	return out

# ================================================================== storm debris and funnels
## Six small dark pieces for particles to carry round a tornado, each under 30 triangles, each centred on its origin:
## a plank (1.2 m), a forked branch (1.5 m), a roof shingle, a cluster of leaves, a bundle of twigs, a sheet of paper.
## Double-sided, one material.
static func debris_pieces() -> Array:
	if _cache.has("debris"): return _cache["debris"]
	var cm := _mat("cloth")
	var I := Transform3D.IDENTITY
	var out: Array = []
	var k1 := DroneParts.Kit.new()
	k1.add(cm, NewModels._box(Vector3(0.18, 0.035, 1.2)), I, Color(0.3, 0.24, 0.17))
	out.append(k1.commit())
	var k2 := DroneParts.Kit.new()
	k2.add(cm, DroneParts.tube(Vector3(0, 0, -0.75), Vector3(0.05, 0.03, 0.75), 0.04, 0.02, 3), I, Color(0.2, 0.15, 0.1))
	k2.add(cm, DroneParts.tube(Vector3(0.02, 0.0, 0.0), Vector3(0.35, 0.08, 0.45), 0.022, 0.01, 3), I, Color(0.2, 0.15, 0.1))
	out.append(k2.commit())
	var k3 := DroneParts.Kit.new()
	k3.add(cm, NewModels._box(Vector3(0.33, 0.01, 0.24)), I, Color(0.16, 0.16, 0.17))
	out.append(k3.commit())
	var b4 := Buf.new()
	for k in 4:
		var a := TAU * k / 4.0 + 0.3
		var d := Vector3(cos(a), 0.25 * sin(a * 2.0), sin(a)) * 0.13
		var s := Vector3(-sin(a), 0, cos(a)) * 0.05
		var n := Vector3(0, 1, 0)
		b4.quad(Vector3.ZERO, d * 0.5 + s, d, d * 0.5 - s, Color(0.2, 0.26, 0.1) if k % 2 == 0 else Color(0.32, 0.24, 0.1), n)
	var k4 := DroneParts.Kit.new(); k4.add(cm, b4.data()); out.append(k4.commit())
	var k5 := DroneParts.Kit.new()
	k5.add(cm, DroneParts.tube(Vector3(-0.02, 0, -0.3), Vector3(0.02, 0.01, 0.3), 0.012, 0.008, 3), I, Color(0.24, 0.18, 0.12))
	k5.add(cm, DroneParts.tube(Vector3(0.03, -0.01, -0.28), Vector3(-0.04, 0.02, 0.27), 0.01, 0.007, 3), I, Color(0.22, 0.16, 0.11))
	out.append(k5.commit())
	var b6 := Buf.new()
	for i in 3:
		var x0 := -0.105 + 0.07 * i; var x1 := x0 + 0.07
		var y0 := 0.02 * sin(i * 1.4); var y1 := 0.02 * sin((i + 1) * 1.4)
		b6.quad(Vector3(x0, y0, -0.15), Vector3(x1, y1, -0.15), Vector3(x1, y1, 0.15), Vector3(x0, y0, 0.15), Color(0.4, 0.39, 0.36), Vector3(0, 1, 0))
	var k6 := DroneParts.Kit.new(); k6.add(cm, b6.data()); out.append(k6.commit())
	_cache["debris"] = out
	return out

## The radius of the funnel tube at height t (0 base to 1 top): narrow at the ground, widening fast towards the cloud.
static func _fn_r(t: float) -> float:
	return 0.07 + 0.43 * pow(clampf(t, 0.0, 1.0), 2.2)

## A tapered, slightly bent tube of unit height for the tornado and waterspout shaders (the game scales it): radius 0.07 at
## the base (y = 0) to 0.5 at the top (y = 1), its middle bowed 0.06 towards +X. No caps, no material (bring the shader).
## UV.x goes round (0 to 1, the seam repeated), UV.y goes up (0 base, 1 top); normals point outward. rings x segments x 2
## triangles.
static func funnel_tube(rings := 24, segments := 24) -> ArrayMesh:
	var key := "funnel_%d_%d" % [rings, segments]
	if _cache.has(key): return _cache[key]
	var v := PackedVector3Array(); var nr := PackedVector3Array(); var uv := PackedVector2Array(); var idx := PackedInt32Array()
	for i in rings + 1:
		var t := float(i) / rings
		var r := _fn_r(t)
		var dr := (_fn_r(t + 0.001) - _fn_r(t - 0.001)) / 0.002
		var cx := 0.06 * sin(PI * t); var dcx := 0.06 * PI * cos(PI * t)
		for j in segments + 1:
			var a := TAU * j / segments
			var ca := cos(a); var sa := sin(a)
			v.append(Vector3(cx + r * ca, t, r * sa))
			var n := Vector3(-sa, 0.0, ca).cross(Vector3(dcx + dr * ca, 1.0, dr * sa)).normalized()
			if n.dot(Vector3(ca, 0, sa)) < 0.0: n = -n
			nr.append(n); uv.append(Vector2(float(j) / segments, t))
	for i in rings:
		for j in segments:
			var a0 := i * (segments + 1) + j
			var b0 := a0 + segments + 1
			idx.append_array([a0, a0 + 1, b0, a0 + 1, b0 + 1, b0])         # clockwise seen from outside
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v; arrays[Mesh.ARRAY_NORMAL] = nr; arrays[Mesh.ARRAY_TEX_UV] = uv; arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache[key] = mesh
	return mesh

## A flat ring for the spray at the foot of a waterspout: inner radius `inner`, outer radius 1, in the x-z plane facing up.
## UV.x goes round, UV.y goes out (0 at the inner edge, 1 at the outer). No material (bring the shader).
static func funnel_ring_disc(segments := 48, inner := 0.55) -> ArrayMesh:
	var key := "ring_%d_%.3f" % [segments, inner]
	if _cache.has(key): return _cache[key]
	var v := PackedVector3Array(); var nr := PackedVector3Array(); var uv := PackedVector2Array(); var idx := PackedInt32Array()
	for j in segments + 1:
		var a := TAU * j / segments
		for k in 2:
			var r := inner if k == 0 else 1.0
			v.append(Vector3(r * cos(a), 0, r * sin(a))); nr.append(Vector3.UP); uv.append(Vector2(float(j) / segments, float(k)))
	for j in segments:
		var i0 := j * 2; var o0 := i0 + 1; var i1 := i0 + 2; var o1 := i0 + 3
		idx.append_array([i0, o0, i1, i1, o0, o1])                        # clockwise seen from above
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v; arrays[Mesh.ARRAY_NORMAL] = nr; arrays[Mesh.ARRAY_TEX_UV] = uv; arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache[key] = mesh
	return mesh

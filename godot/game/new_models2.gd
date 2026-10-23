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

const TR_LOCO_WHEEL := 0.508            # 40 inch wheels under the locomotive (the usual size under a road diesel)
const TR_CAR_WHEEL := 0.4572            # 36 inch (0.91 m) wheels under the freight cars
const TR_LOCO_TRUCKS := [-6.1, 6.1]
const TR_CAR_TRUCKS := [-5.85, 5.85]
const TR_LOCO_AXLE := 2.0               # axle spacing in the locomotive's three-axle trucks
const TR_CAR_AXLE := 1.73               # 5 ft 8 in, a two-axle freight truck
# One wheel across the track (x out from the centre line, m), after the AAR wheel profile: the backs of the flanges are 1.36 m
# apart, so the flanges run just inside the rail heads (which start at 0.7175); the coned tread runs 11.9 cm from the flange
# throat to the outer face of the rim, and the whole rim is 15.5 cm wide. The flange stands 2.5 cm below the tread.
const TR_BACK := 0.68
const TR_THROAT := 0.716
const TR_FACE := 0.835
const TR_FLANGE := 0.025

## The half section of one wheel (radius, x along the axle) as a closed loop for the lathe: the hub on the axle, a thin
## dished plate, the rim with the flange on its inside and the coned tread. detail false is the cheap middle-distance one.
static func _tr_wheel_prof(R: float, detail: bool) -> PackedVector2Array:
	var f := TR_FLANGE
	if not detail:
		return PackedVector2Array([Vector2(0.085, 0.61), Vector2(0.17, 0.61), Vector2(R - 0.07, 0.69), Vector2(R - 0.05, TR_BACK), Vector2(R + f, TR_BACK + 0.008),
			Vector2(R + f * 0.5, TR_THROAT - 0.005), Vector2(R, TR_THROAT + 0.006), Vector2(R - 0.007, TR_FACE), Vector2(R - 0.05, TR_FACE), Vector2(R - 0.12, 0.72),
			Vector2(0.17, 0.78), Vector2(0.085, 0.78)])
	return PackedVector2Array([
		Vector2(0.085, 0.6), Vector2(0.165, 0.6), Vector2(0.165, 0.6), Vector2(0.2, 0.655),               # hub, inboard side
		Vector2(0.3, 0.672), Vector2(R - 0.13, 0.688), Vector2(R - 0.075, 0.692), Vector2(R - 0.052, TR_BACK), Vector2(R - 0.052, TR_BACK),   # dished plate into the rim
		Vector2(R + f - 0.008, TR_BACK), Vector2(R + f, TR_BACK + 0.012), Vector2(R + f * 0.5, TR_THROAT - 0.006),   # flange
		Vector2(R + 0.002, TR_THROAT), Vector2(R, TR_THROAT + 0.008), Vector2(R - 0.0055, TR_FACE - 0.008), Vector2(R - 0.011, TR_FACE), Vector2(R - 0.011, TR_FACE),   # coned tread
		Vector2(R - 0.052, TR_FACE), Vector2(R - 0.052, TR_FACE), Vector2(R - 0.13, 0.716),   # rim face, plate outboard
		Vector2(0.3, 0.698), Vector2(0.2, 0.71), Vector2(0.165, 0.785), Vector2(0.165, 0.785), Vector2(0.085, 0.785)])

## One wheelset: two wheels and their axle, centred on the axle with the axle along +X (the spin axis). Each wheel is turned
## from the profile above, the running band of the tread worn bright, the plate and hub rusty brown. The axle carries a
## roller bearing beyond each wheel with a turning end cap and its three cap screws (so the turning shows). Placed at
## (0, r, z) the treads touch y = 0 on the 1.435 m gauge. detail: 2 close (under about 25 m), 1 middle (to about 80 m),
## 0 far (a plain six-sided disc for each wheel).
static func _tr_wheelset(r: float, detail := 2) -> ArrayMesh:
	var key := "wheelset_%.3f_%d" % [r, detail]
	if _cache.has(key): return _cache[key]
	var kit := DroneParts.Kit.new()
	var sh := _mat("sheet")
	var on_x := Basis(Vector3(0, 0, 1), -PI * 0.5)                       # the lathe's +Y onto +X
	var flip := Basis(Vector3.UP, PI) * on_x                              # and onto -X for the left wheel
	var rust := Color(0.25, 0.16, 0.11)
	if detail == 0:
		# a corner of each hexagon stands on the rail (the lathe's first segment points down after on_x)
		var disc := DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, TR_BACK + 0.01), Vector2(r, TR_BACK + 0.01), Vector2(r, TR_FACE), Vector2(0, TR_FACE)])), 6)
		for bb: Basis in [on_x, flip]: kit.add(sh, disc, Transform3D(bb, Vector3.ZERO), rust)
	else:
		var R := r
		var paint := func(p: Vector3, n: Vector3) -> Color:
			var rad := Vector2(p.x, p.z).length()
			var radial := Vector2(n.x, n.z).length()
			if rad > R - 0.013 and p.y > TR_THROAT - 0.004 and radial > 0.6: return Color(0.66, 0.64, 0.6)    # the running band
			if rad > R + 0.006: return Color(0.38, 0.35, 0.32)                                               # flange, rubbed
			if rad < 0.2: return Color(0.16, 0.13, 0.11)                                                     # hub
			return NewModels._vary(rust, Vector3(floorf(rad * 20.0), p.y, 0.0), 0.12)
		var seg := 16 if detail == 2 else 9
		var wheel := NewModels._paint(DroneParts.lathe(_tr_wheel_prof(R, detail == 2), seg, true), paint)
		kit.add(sh, wheel, Transform3D(on_x, Vector3.ZERO))
		kit.add(sh, wheel, Transform3D(flip, Vector3.ZERO))
		# the axle: wheel seats, journals, the roller bearings and their end caps
		var half := PackedVector2Array([Vector2(0.088, 0.0), Vector2(0.088, 0.78), Vector2(0.098, 0.81), Vector2(0.098, 0.865), Vector2(0.098, 0.865), Vector2(0.118, 0.865),
			Vector2(0.118, 0.865), Vector2(0.118, 1.035), Vector2(0.118, 1.035), Vector2(0.085, 1.035), Vector2(0.085, 1.035), Vector2(0.085, 1.075), Vector2(0.085, 1.075), Vector2(0.0, 1.075)])
		if detail == 1: half = PackedVector2Array([Vector2(0.09, 0.0), Vector2(0.09, 0.82), Vector2(0.115, 0.86), Vector2(0.115, 1.06), Vector2(0.0, 1.06)])
		var ax := PackedVector2Array()
		for k in range(half.size() - 1, -1, -1): ax.append(Vector2(half[k].x, -half[k].y))
		for k in range(1, half.size()): ax.append(half[k])
		var ax_col := func(p: Vector3, _n: Vector3) -> Color:
			var a := absf(p.y)
			if a > 1.03: return Color(0.42, 0.4, 0.37)          # end cap
			if a > 0.86: return Color(0.1, 0.1, 0.1)            # bearing cup
			return Color(0.2, 0.17, 0.15)
		kit.add(sh, NewModels._paint(DroneParts.lathe(ax, 10 if detail == 2 else 7), ax_col), Transform3D(on_x, Vector3.ZERO))
		if detail == 2:
			for sx: float in [-1.0, 1.0]:
				for k in 3:
					var a2 := TAU * k / 3.0 + 0.4
					kit.add(sh, NewModels._box(Vector3(0.022, 0.03, 0.03)), NewModels._xf(Vector3(sx * 1.08, 0.05 * cos(a2), 0.05 * sin(a2))), Color(0.12, 0.12, 0.12))
	var mesh := kit.commit()
	_cache[key] = mesh
	return mesh

## The axle centres of a vehicle's trucks: truck middles zcs, axles per truck, axle spacing, wheel radius.
static func _tr_axles(zcs: Array, axles: int, spacing: float, r: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for zc: float in zcs:
		for k in axles: out.append(Vector3(0, r, zc + (k - (axles - 1) * 0.5) * spacing))
	return out

## A coil spring standing from y0 to y1 at (x, z), d across: a column with dark slanted gaps between the coils on its outer face.
static func _tr_spring(kit: DroneParts.Kit, b: Buf, x: float, z: float, y0: float, y1: float, d: float, col: Color) -> void:
	var h := d * 0.5
	var foot := Vector3(x, y0, z)
	for c: Array in [[Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(1, 0, 0)], [Vector3(h, 0, h), Vector3(-h, 0, h), Vector3(0, 0, 1)], [Vector3(-h, 0, h), Vector3(-h, 0, -h), Vector3(-1, 0, 0)], [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(0, 0, -1)]]:
		var p0: Vector3 = foot + (c[0] as Vector3); var p1: Vector3 = foot + (c[1] as Vector3)
		b.quad(p0, p1, p1 + Vector3(0, y1 - y0, 0), p0 + Vector3(0, y1 - y0, 0), col, c[2])
	var sx := signf(x)
	var xo := x + sx * (d * 0.5 + 0.003)
	var n := 2
	for k in n:
		var y := lerpf(y0, y1, (k + 0.5) / n)
		var dy := (y1 - y0) / n * 0.22
		b.quad(Vector3(xo, y - dy, z - d * 0.5), Vector3(xo, y - dy * 0.2, z + d * 0.5), Vector3(xo, y + dy * 1.6, z + d * 0.5), Vector3(xo, y + dy * 0.8, z - d * 0.5), Color(0.04, 0.04, 0.04), Vector3(sx, 0, 0))

## A thin square bar from a to b without end caps (8 triangles), for handrails, grab irons, hangers and rods.
static func _bar(b: Buf, a: Vector3, c: Vector3, w: float, col: Color) -> void:
	var z := (c - a).normalized()
	var x := Vector3.UP.cross(z)
	if x.length_squared() < 1e-6: x = Vector3.RIGHT.cross(z)
	x = x.normalized()
	var y := z.cross(x)
	var cs: Array[Vector3] = [(x + y) * w * 0.5, (-x + y) * w * 0.5, (-x - y) * w * 0.5, (x - y) * w * 0.5]
	for k in 4:
		var p := cs[k]; var q := cs[(k + 1) % 4]
		b.quad(a + p, a + q, c + q, c + p, col, (p + q).normalized())

## A freight car truck (bogie) without its wheelsets (they are separate meshes, see _tr_wheelset): the classic three-piece
## truck. Two cast side frames outside the wheels, each a top chord arching over a bottom chord with a window between two
## columns, where a nest of three coil springs carries the bolster end; the pedestals sit on the roller bearings (whose end
## caps show outside); a brake beam with its shoes against the treads at each outer side. axles 3 builds the locomotive truck.
static func _tr_truck(kit: DroneParts.Kit, zc: float, axles: int, spacing: float, r: float) -> void:
	if axles == 3:
		_tr_loco_truck(kit, zc)
		return
	var pm := _mat("paint")
	var b := Buf.new()
	var a := spacing * 0.5
	var col := Color(0.15, 0.13, 0.12).lerp(Color(0.32, 0.2, 0.13), 0.35 * NewModels._h(Vector3(zc, 1, 2)))     # some rust
	var w := 0.42                                                         # half width of the spring window
	var top := PackedVector2Array([Vector2(-a - 0.26, r - 0.08), Vector2(-a - 0.26, r + 0.12), Vector2(-w - 0.12, r + 0.36), Vector2(w + 0.12, r + 0.36), Vector2(a + 0.26, r + 0.12),
		Vector2(a + 0.26, r - 0.08), Vector2(a - 0.2, r - 0.08), Vector2(w + 0.1, r + 0.17), Vector2(-w - 0.1, r + 0.17), Vector2(-a + 0.2, r - 0.08)])
	var bottom := PackedVector2Array([Vector2(-a + 0.18, r - 0.05), Vector2(-w - 0.12, r - 0.34), Vector2(w + 0.12, r - 0.34), Vector2(a - 0.18, r - 0.05),
		Vector2(a - 0.3, r - 0.05), Vector2(w + 0.02, r - 0.2), Vector2(-w - 0.02, r - 0.2), Vector2(-a + 0.3, r - 0.05)])
	var stand := Transform3D(Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)), Vector3.ZERO)   # (z, y) outline stood up, thickness on x
	var top_m := DroneParts._apply(DroneParts.extrude(top, -0.07, 0.07), stand)
	var bot_m := DroneParts._apply(DroneParts.extrude(bottom, -0.065, 0.065), stand)
	for sx: float in [-1.0, 1.0]:
		var xs := sx * 0.99
		kit.add(pm, top_m, NewModels._xf(Vector3(xs, 0, zc)), col)
		kit.add(pm, bot_m, NewModels._xf(Vector3(xs, 0, zc)), col)
		for sz: float in [-1.0, 1.0]:
			kit.add(pm, NewModels._box(Vector3(0.13, 0.4, 0.1)), NewModels._xf(Vector3(xs, r - 0.02, zc + sz * (w + 0.06))), col)        # window columns
		for k in 3:
			_tr_spring(kit, b, xs, zc + (k - 1) * 0.25, r - 0.2, r + 0.02, 0.17, Color(0.36, 0.3, 0.24))
	# the bolster across, its ends filling the tops of the windows
	kit.add(pm, NewModels._box(Vector3(2.04, 0.26, 0.62)), NewModels._xf(Vector3(0, r + 0.15, zc)), col.darkened(0.1))
	# a brake beam across each outer side, its heads and shoes bearing on both treads
	for sz: float in [-1.0, 1.0]:
		var zs := zc + sz * (a - r - 0.04)
		kit.add(pm, NewModels._box(Vector3(1.62, 0.1, 0.1)), NewModels._xf(Vector3(0, r + 0.02, zs - sz * 0.06)), Color(0.12, 0.11, 0.1))
		for sx: float in [-1.0, 1.0]:
			kit.add(pm, NewModels._box(Vector3(0.11, 0.3, 0.07)), Transform3D(Basis(Vector3.RIGHT, sz * deg_to_rad(12.0)), Vector3(sx * 0.775, r + 0.04, zs)), Color(0.1, 0.09, 0.08))
	kit.add(pm, b.data())

## The locomotive's three-axle truck (in the manner of an EMD HT-C): a deep cast side frame outside the wheels with a pedestal
## round each journal box, coil springs either side of each box under spring seats, a brake cylinder on the frame between
## axles with hangers carrying a shoe on each wheel tread, and a traction motor hung on every axle between the wheels.
static func _tr_loco_truck(kit: DroneParts.Kit, zc: float) -> void:
	var pm := _mat("paint")
	var b := Buf.new()
	var r := TR_LOCO_WHEEL; var s := TR_LOCO_AXLE
	var col := Color(0.2, 0.19, 0.18).lerp(Color(0.34, 0.22, 0.14), 0.25)
	var dark := Color(0.08, 0.08, 0.08)
	var e := s + 0.55
	var frame := PackedVector2Array([Vector2(-e, r - 0.04), Vector2(-e, r + 0.1), Vector2(-e + 0.15, r + 0.34), Vector2(e - 0.15, r + 0.34), Vector2(e, r + 0.1), Vector2(e, r - 0.04),
		Vector2(s + 0.27, r - 0.18), Vector2(s - 0.27, r - 0.18), Vector2(s - 0.42, r + 0.07), Vector2(0.42, r + 0.07), Vector2(0.27, r - 0.18), Vector2(-0.27, r - 0.18),
		Vector2(-0.42, r + 0.07), Vector2(-s + 0.42, r + 0.07), Vector2(-s + 0.27, r - 0.18), Vector2(-s - 0.27, r - 0.18)])
	var stand := Transform3D(Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)), Vector3.ZERO)
	var fm := DroneParts._apply(DroneParts.extrude(frame, -0.08, 0.08), stand)
	var motor_dir := signf(zc)                                        # motors hung on the side of each axle away from the fuel tank
	for sx: float in [-1.0, 1.0]:
		var xf := sx * 1.06
		kit.add(pm, fm, NewModels._xf(Vector3(xf, 0, zc)), col)
		for k in 3:
			var az := zc + (k - 1) * s
			kit.add(pm, NewModels._box(Vector3(0.2, 0.34, 0.36)), NewModels._xf(Vector3(sx * 1.08, r - 0.02, az)), dark)                  # journal box
			for sz: float in [-1.0, 1.0]:
				_tr_spring(kit, b, sx * 1.2, az + sz * 0.27, r - 0.14, r + 0.13, 0.15, Color(0.33, 0.28, 0.22))
		for k in 2:
			var bz := zc + (k - 0.5) * s
			kit.add(pm, NewModels._box(Vector3(0.22, 0.24, 0.3)), NewModels._xf(Vector3(sx * 1.24, r + 0.18, bz)), Color(0.18, 0.17, 0.16))   # brake cylinder
		_bar(b, Vector3(sx * 1.31, r - 0.1, zc - s - 0.3), Vector3(sx * 1.31, r - 0.1, zc + s + 0.3), 0.035, dark)                     # brake rigging rod
	for k in 3:
		var az2 := zc + (k - 1) * s
		kit.add(pm, DroneParts.tube(Vector3(-0.56, r + 0.02, az2 + motor_dir * 0.44), Vector3(0.56, r + 0.02, az2 + motor_dir * 0.44), 0.35, 0.35, 5), Transform3D.IDENTITY, Color(0.11, 0.11, 0.12))   # traction motor
	for k in 2:
		kit.add(pm, NewModels._box(Vector3(2.12, 0.26, 0.42)), NewModels._xf(Vector3(0, r + 0.33, zc + (k - 0.5) * s)), col.darkened(0.1))       # transoms and bolster
	kit.add(pm, b.data())

## Couplers: a shank from the draft gear, the knuckle head with its knuckle, and the striker casting round the shank.
static func _tr_couplers(kit: DroneParts.Kit, half: float, striker := true) -> void:
	var pm := _mat("paint")
	var dark := Color(0.15, 0.14, 0.13)
	for sz: float in [-1.0, 1.0]:
		kit.add(pm, NewModels._box(Vector3(0.16, 0.16, 0.62)), NewModels._xf(Vector3(0, 0.876, sz * (half - 0.5))), dark)
		kit.add(pm, NewModels._box(Vector3(0.36, 0.3, 0.18)), NewModels._xf(Vector3(0.04, 0.876, sz * (half - 0.15))), dark)
		kit.add(pm, NewModels._box(Vector3(0.12, 0.26, 0.14)), NewModels._xf(Vector3(-0.1, 0.876, sz * (half - 0.07))), dark)
		if striker: kit.add(pm, NewModels._box(Vector3(0.5, 0.36, 0.08)), NewModels._xf(Vector3(0, 0.876, sz * (half - 0.66))), Color(0.1, 0.1, 0.1))

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

## The cross-section of a hood or cab: a flat bottom at ya, upright sides, the top corners rounded with radius rr in n steps.
static func _rrect(hw: float, ya: float, yb: float, rr: float, n: int) -> PackedVector2Array:
	var prof := PackedVector2Array([Vector2(-hw, ya), Vector2(-hw, ya)])
	for k in n + 1:
		var a := PI - PI * 0.5 * k / n
		prof.append(Vector2(-hw + rr + rr * cos(a), yb - rr + rr * sin(a)))
	for k in n + 1:
		var a2 := PI * 0.5 - PI * 0.5 * k / n
		prof.append(Vector2(hw - rr + rr * cos(a2), yb - rr + rr * sin(a2)))
	prof.append(Vector2(hw, ya)); prof.append(Vector2(hw, ya))
	return prof

## Rings of points (all the same length, each going round once) skinned into a smooth shell, the end rings closed flat.
static func _skin(rows: Array, cap0 := true, cap1 := true) -> Array:
	var cens: Array[Vector3] = []
	for rw: PackedVector3Array in rows:
		var c := Vector3.ZERO
		for p in rw: c += p
		cens.append(c / rw.size())
	var hint := func(i: int, _j: int, p: Vector3) -> Vector3: return p - cens[i]
	var data := DroneParts.grid(rows, false, true, hint)
	var pos: PackedVector3Array = data[0]; var nrm: PackedVector3Array = data[1]
	var dummy := PackedColorArray()
	for e in 2:
		if (e == 0 and not cap0) or (e == 1 and not cap1): continue
		var k := 0 if e == 0 else rows.size() - 1
		var ring: PackedVector3Array = rows[k]
		var nb: Vector3 = cens[1] if e == 0 else cens[rows.size() - 2]
		var n := Vector3.ZERO
		for q in ring.size():
			var a := ring[q]; var b := ring[(q + 1) % ring.size()]
			n += Vector3((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y))
		n = n.normalized()
		if n.dot(cens[k] - nb) < 0.0: n = -n
		for q in ring.size():
			DroneParts._tri(pos, nrm, dummy, cens[k], ring[q], ring[(q + 1) % ring.size()], n, n, n, Color.WHITE, Color.WHITE, Color.WHITE)
	return [pos, nrm]

## A hood or cab along z: stations [z, half width, bottom y, top y, corner radius, (lean)], each a rounded-top section
## (_rrect); lean tilts that station's face back by lean m per m of height (the cab front). Ends closed flat.
static func _rhood(stations: Array, n := 3) -> Array:
	var rows: Array = []
	for st: Array in stations:
		var ya: float = st[2]
		var lean: float = st[5] if st.size() > 5 else 0.0
		var row := PackedVector3Array()
		for q in _rrect(float(st[1]), ya, float(st[3]), float(st[4]), n): row.append(Vector3(q.x, q.y, float(st[0]) + lean * (q.y - ya)))
		rows.append(row)
	return _skin(rows)

# A six-axle road-switcher diesel in the manner of an EMD SD40-2 (no real marks): a short low nose with the headlight and
# number boards, a full-width cab with a raked front, big windows and sun visors, the long hood with the dynamic-brake
# blister and its fan behind the cab, engine-room doors, the exhaust stack, and the radiator section at the rear with three
# fans on the roof and grilles along both sides. Walkways with yellow handrails and corner steps, yellow pilots with black
# hazard stripes round the coupler pockets, ditch lights, a bell and a horn, a fuel tank slung between two three-axle trucks.
const TR_DECK := 1.6                     # walkway height above the rail

static func _locomotive() -> ArrayMesh:
	var kit := DroneParts.Kit.new()
	var pm := _mat("paint"); var gm := _mat("gloss")
	var I := Transform3D.IDENTITY
	var deck := TR_DECK
	var y0 := deck - 0.01
	var blue := TR_BLUE
	var roof := TR_BLUE.darkened(0.3)
	var black := Color(0.04, 0.04, 0.045)
	var rail := Color(0.95, 0.76, 0.12)
	var b := Buf.new()                    # small flat details (paint)
	var g := Buf.new()                    # flat painted panels and stripes (gloss)
	var gl := Buf.new()                   # glass
	var body_col := func(_p: Vector3, n: Vector3) -> Color: return roof if n.y > 0.8 else blue
	# ---- frame: a deep side sill with a yellow band, the walkway plate, yellow end sills
	kit.add(gm, NewModels._box(Vector3(3.1, 0.4, 20.62)), NewModels._xf(Vector3(0, deck - 0.24, 0)), blue.darkened(0.2))
	kit.add(pm, NewModels._box(Vector3(3.14, 0.05, 20.66)), NewModels._xf(Vector3(0, deck - 0.02, 0)), Color(0.24, 0.24, 0.25))
	for sx: float in [-1.0, 1.0]:
		var x := sx * 1.553
		g.quad(Vector3(x, deck - 0.4, -10.31), Vector3(x, deck - 0.4, 10.31), Vector3(x, deck - 0.28, 10.31), Vector3(x, deck - 0.28, -10.31), TR_YELLOW, Vector3(sx, 0, 0))
	for sz: float in [-1.0, 1.0]:
		var z := sz * 10.314
		g.quad(Vector3(-1.55, deck - 0.44, z), Vector3(1.55, deck - 0.44, z), Vector3(1.55, deck - 0.04, z), Vector3(-1.55, deck - 0.04, z), TR_YELLOW, Vector3(0, 0, sz))
	# ---- long hood: dynamic-brake blister behind the cab, then the engine room and the radiator section; rounded rear end
	kit.add(gm, NewModels._paint(_rhood([[-5.0, 0.98, y0, 4.2, 0.3], [-2.76, 0.98, y0, 4.2, 0.3], [-2.5, 0.98, y0, 4.0, 0.3],
		[-2.44, 0.98, y0, 3.98, 0.3], [9.44, 0.98, y0, 3.98, 0.3], [9.66, 0.95, y0, 3.86, 0.36], [9.78, 0.9, y0, 3.7, 0.32]], 3), body_col))
	# ---- the short hood (low nose), sloping down at the front
	kit.add(gm, NewModels._paint(_rhood([[-7.45, 0.95, y0, 3.36, 0.24], [-9.36, 0.95, y0, 3.36, 0.24], [-9.62, 0.93, y0, 3.22, 0.3],
		[-9.76, 0.87, y0, 3.0, 0.28]], 3), body_col))
	# ---- the cab: full width, the front raked back above the nose
	var lean := 0.055
	kit.add(gm, NewModels._paint(_rhood([[-7.62, 1.5, y0, 4.55, 0.4, lean], [-4.95, 1.5, y0, 4.55, 0.4]], 3), body_col))
	var zf := func(y: float) -> float: return -7.62 + lean * (y - y0) - 0.012
	var nf := Vector3(0, lean, -1).normalized()
	for sx: float in [-1.0, 1.0]:
		var x0 := sx * 0.15; var x1 := sx * 1.3
		b.quad(Vector3(x0 - sx * 0.03, 3.47, zf.call(3.47) + 0.004), Vector3(x1 + sx * 0.03, 3.47, zf.call(3.47) + 0.004), Vector3(x1 + sx * 0.03, 4.28, zf.call(4.28) + 0.004), Vector3(x0 - sx * 0.03, 4.28, zf.call(4.28) + 0.004), black, nf)
		gl.quad(Vector3(x0, 3.5, zf.call(3.5)), Vector3(x1, 3.5, zf.call(3.5)), Vector3(x1, 4.25, zf.call(4.25)), Vector3(x0, 4.25, zf.call(4.25)), Color.WHITE, nf)
		kit.add(pm, _beam(Vector3(sx * 0.1, 4.36, zf.call(4.36) - 0.11), Vector3(sx * 1.36, 4.36, zf.call(4.36) - 0.11), 0.24, 0.025), I, black)   # sun visor
		# side windows: the big sliding one and the fixed one behind it, rubber surrounds
		var xw := sx * 1.508
		for wz: Array in [[-7.3, -6.4], [-6.3, -5.25]]:
			var za: float = wz[0]; var zb: float = wz[1]
			b.quad(Vector3(xw, 3.33, za - 0.03), Vector3(xw, 3.33, zb + 0.03), Vector3(xw, 4.17, zb + 0.03), Vector3(xw, 4.17, za - 0.03), black, Vector3(sx, 0, 0))
			gl.quad(Vector3(xw + sx * 0.003, 3.36, za), Vector3(xw + sx * 0.003, 3.36, zb), Vector3(xw + sx * 0.003, 4.14, zb), Vector3(xw + sx * 0.003, 4.14, za), Color.WHITE, Vector3(sx, 0, 0))
		gl.quad(Vector3(sx * 1.04, 3.45, -4.945), Vector3(sx * 1.42, 3.45, -4.945), Vector3(sx * 1.42, 4.12, -4.945), Vector3(sx * 1.04, 4.12, -4.945), Color.WHITE, Vector3(0, 0, 1))   # rear cab windows
	# ---- grilles: radiators along the rear of the hood, the dynamic brake, the engine air filter behind the cab
	for sx: float in [-1.0, 1.0]:
		var xg := sx * 0.987
		for gr: Array in [[6.25, 9.45, 3.2, 3.66, 4, true], [-4.75, -2.95, 3.42, 3.88, 5, false], [-2.3, -0.75, 3.2, 3.62, 4, false]]:
			var za2: float = gr[0]; var zb2: float = gr[1]; var ya2: float = gr[2]; var yb2: float = gr[3]; var ns: int = gr[4]
			g.quad(Vector3(xg, ya2, za2), Vector3(xg, ya2, zb2), Vector3(xg, yb2, zb2), Vector3(xg, yb2, za2), Color(0.03, 0.035, 0.05), Vector3(sx, 0, 0))
			for k in ns:
				if gr[5]:
					var yy := lerpf(ya2, yb2, (k + 0.5) / ns)
					g.quad(Vector3(xg + sx * 0.004, yy - 0.012, za2 + 0.03), Vector3(xg + sx * 0.004, yy - 0.012, zb2 - 0.03), Vector3(xg + sx * 0.004, yy + 0.012, zb2 - 0.03), Vector3(xg + sx * 0.004, yy + 0.012, za2 + 0.03), blue.lightened(0.08), Vector3(sx, 0, 0))
				else:
					var zz := lerpf(za2, zb2, (k + 0.5) / ns)
					g.quad(Vector3(xg + sx * 0.004, ya2 + 0.02, zz - 0.02), Vector3(xg + sx * 0.004, ya2 + 0.02, zz + 0.02), Vector3(xg + sx * 0.004, yb2 - 0.02, zz + 0.02), Vector3(xg + sx * 0.004, yb2 - 0.02, zz - 0.02), blue.lightened(0.08), Vector3(sx, 0, 0))
		# engine-room doors, each a shade apart, with a louvre over every other one
		for k in 8:
			var dz := -0.6 + k * 0.85
			var dc := blue.lightened(0.05) if k % 2 == 0 else blue.darkened(0.08)
			g.quad(Vector3(sx * 0.986, 1.84, dz), Vector3(sx * 0.986, 1.84, dz + 0.8), Vector3(sx * 0.986, 3.12, dz + 0.8), Vector3(sx * 0.986, 3.12, dz), dc, Vector3(sx, 0, 0))
			if k % 4 == 1:
				g.quad(Vector3(sx * 0.99, 2.8, dz + 0.12), Vector3(sx * 0.99, 2.8, dz + 0.68), Vector3(sx * 0.99, 3.02, dz + 0.68), Vector3(sx * 0.99, 3.02, dz + 0.12), Color(0.04, 0.05, 0.07), Vector3(sx, 0, 0))
	# ---- roof: radiator fans, the dynamic brake fan, exhaust stack, bell, horn
	for f: Array in [[6.85, 3.98, 0.56], [8.0, 3.98, 0.56], [9.1, 3.98, 0.52], [-3.85, 4.2, 0.42]]:
		var fz: float = f[0]; var fy: float = f[1]; var fr: float = f[2]
		kit.add(pm, DroneParts.lathe(PackedVector2Array([Vector2(0, fy + 0.015), Vector2(fr, fy + 0.015), Vector2(fr + 0.05, fy + 0.07), Vector2(fr + 0.07, fy - 0.01)]), 10), NewModels._xf(Vector3(0, 0, fz)), Color(0.07, 0.07, 0.08))
		for k in 4:
			var aa := TAU * k / 4.0 + 0.3
			var d := Vector3(cos(aa), 0, sin(aa)); var sd := Vector3(-sin(aa), 0, cos(aa))
			var c := Vector3(0, fy + 0.022, fz)
			b.quad(c + d * 0.08 - sd * 0.05, c + d * (fr - 0.06) - sd * 0.13, c + d * (fr - 0.06) + sd * 0.1, c + d * 0.08 + sd * 0.05, Color(0.3, 0.3, 0.31), Vector3.UP)
	kit.add(pm, NewModels._box(Vector3(0.24, 0.2, 0.62)), NewModels._xf(Vector3(0, 4.07, 1.6)), black)                    # exhaust stack
	kit.add(pm, DroneParts.lathe(PackedVector2Array([Vector2(0, 4.3), Vector2(0.05, 4.29), Vector2(0.1, 4.21), Vector2(0.135, 4.08), Vector2(0.15, 4.04), Vector2(0, 4.04)]), 6), NewModels._xf(Vector3(0.3, 0, -2.1)), Color(0.62, 0.48, 0.2))   # bell
	kit.add(pm, NewModels._box(Vector3(0.3, 0.08, 0.24)), NewModels._xf(Vector3(0.55, 4.58, -6.0)), black)                # horn: five trumpets on a manifold
	for hz: Array in [[0.44, -1.0, 0.4], [0.62, -1.0, 0.3], [0.53, 1.0, 0.3]]:
		var hx: float = hz[0]; var hd: float = hz[1]; var hl: float = hz[2]
		kit.add(pm, DroneParts.tube(Vector3(hx, 4.66, -6.0 + hd * 0.08), Vector3(hx, 4.66, -6.0 + hd * (0.08 + hl)), 0.022, 0.06, 5), I, Color(0.18, 0.18, 0.19))
	# ---- headlights and number boards on the nose and on the rear of the long hood, ditch lights on the front pilot
	var lamp := _mat("lamp")
	for e: Array in [[-1.0, -9.762, 2.78, 2.72], [1.0, 9.782, 3.32, 3.42]]:
		var sz2: float = e[0]; var ze: float = e[1]; var hy: float = e[2]; var ny: float = e[3]
		kit.add(pm, NewModels._box(Vector3(0.56, 0.3, 0.06)), NewModels._xf(Vector3(0, hy, ze + sz2 * 0.025)), black)
		for sx: float in [-1.0, 1.0]:
			kit.add(lamp, NewModels._box(Vector3(0.18, 0.18, 0.02)), NewModels._xf(Vector3(sx * 0.13, hy, ze + sz2 * 0.06)))
			var rot := Basis(Vector3.UP, sx * deg_to_rad(28.0) * sz2)
			kit.add(pm, NewModels._box(Vector3(0.42, 0.15, 0.02)), Transform3D(rot, Vector3(sx * 0.56, ny, ze) + rot * Vector3(0, 0, sz2 * 0.03)), Color(0.93, 0.93, 0.88))
	for sx: float in [-1.0, 1.0]:
		kit.add(pm, NewModels._box(Vector3(0.24, 0.24, 0.14)), NewModels._xf(Vector3(sx * 0.85, deck + 0.17, -10.2)), black)
		kit.add(lamp, NewModels._box(Vector3(0.16, 0.16, 0.02)), NewModels._xf(Vector3(sx * 0.85, deck + 0.17, -10.275)))
	# the rear sand box on the back platform
	kit.add(gm, NewModels._box(Vector3(1.1, 0.48, 0.34)), NewModels._xf(Vector3(0, deck + 0.24, 10.02)), blue)
	# ---- pilots: yellow, black hazard chevrons, the coupler pocket; air hoses, uncoupling lever
	for sz: float in [-1.0, 1.0]:
		var pilot := PackedVector2Array([Vector2(sz * 10.32, deck - 0.44), Vector2(sz * 10.32, 0.74), Vector2(sz * 10.12, 0.3), Vector2(sz * 9.7, 0.3), Vector2(sz * 9.7, deck - 0.44)])
		kit.add(gm, DroneParts._apply(DroneParts.extrude(pilot, -1.06, 1.06), Transform3D(Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)), Vector3.ZERO)), I, TR_YELLOW)
		var zs := sz * 10.326
		var ns2 := Vector3(0, 0, sz)
		var yt := deck - 0.46; var yb3 := 0.75
		for sx: float in [-1.0, 1.0]:
			for k in 4:
				var ta := k * 0.34; var tb := ta + 0.17
				var ba := ta + (yt - yb3); var bb := tb + (yt - yb3)
				if ta >= 1.05: continue
				var pts: Array[Vector3] = [Vector3(sx * minf(ta, 1.05), yt, zs), Vector3(sx * minf(tb, 1.05), yt, zs), Vector3(sx * minf(bb, 1.05), yb3, zs), Vector3(sx * minf(ba, 1.05), yb3, zs)]
				g.quad(pts[0], pts[1], pts[2], pts[3], black, ns2)
		g.quad(Vector3(-0.3, 0.68, zs + sz * 0.004), Vector3(0.3, 0.68, zs + sz * 0.004), Vector3(0.3, 1.08, zs + sz * 0.004), Vector3(-0.3, 1.08, zs + sz * 0.004), Color(0.02, 0.02, 0.02), ns2)
		for sx: float in [-1.0, 1.0]:
			_bar(b, Vector3(sx * 0.42, 0.8, sz * 10.34), Vector3(sx * 0.46, 0.5, sz * 10.5), 0.05, Color(0.08, 0.08, 0.08))      # air hoses
		# corner steps: a yellow outer stringer and two treads under each corner of the walkway
		for sx: float in [-1.0, 1.0]:
			kit.add(gm, NewModels._box(Vector3(0.03, 0.86, 0.62)), NewModels._xf(Vector3(sx * 1.535, 0.74, sz * 9.98)), TR_YELLOW)
			kit.add(pm, NewModels._box(Vector3(0.44, 0.03, 0.28)), NewModels._xf(Vector3(sx * 1.31, 0.68, sz * 9.98)), Color(0.3, 0.3, 0.31))
	_tr_couplers(kit, TR_LOCO * 0.5, false)
	# ---- handrails: along both walkways, across the end platforms, grab irons at the steps
	var hr := deck + 0.95
	for sx: float in [-1.0, 1.0]:
		var x2 := sx * 1.5
		_bar(b, Vector3(x2, hr, -4.85), Vector3(x2, hr, 9.62), 0.045, rail)
		_bar(b, Vector3(x2, hr, -9.62), Vector3(x2, hr, -7.72), 0.045, rail)
		for z2: float in [-9.62, -7.72, -4.85, 2.4, 9.62]:
			_bar(b, Vector3(x2, deck, z2), Vector3(x2, hr + 0.02, z2), 0.045, rail)
		for sz: float in [-1.0, 1.0]:
			_bar(b, Vector3(sx * 1.565, 0.5, sz * 10.28), Vector3(sx * 1.565, hr - 0.2, sz * 10.28), 0.04, rail)
	for sz: float in [-1.0, 1.0]:
		_bar(b, Vector3(-1.04, hr, sz * 10.24), Vector3(1.04, hr, sz * 10.24), 0.045, rail)
		for x3: float in [-1.04, 1.04]:
			_bar(b, Vector3(x3, deck, sz * 10.24), Vector3(x3, hr + 0.02, sz * 10.24), 0.045, rail)
	# ---- fuel tank slung between the trucks, with its filler and gauge; then the trucks
	kit.add(gm, DroneParts.loft([[-3.3, 0.0, 0.86, 1.2, 0.26], [-3.18, 0.0, 0.82, 1.36, 0.36], [3.18, 0.0, 0.82, 1.36, 0.36], [3.3, 0.0, 0.86, 1.2, 0.26]], 3.2, 8, true), I, Color(0.05, 0.06, 0.09))
	kit.add(pm, NewModels._box(Vector3(0.06, 0.16, 0.16)), NewModels._xf(Vector3(1.37, 0.95, 1.4)), Color(0.5, 0.5, 0.5))      # fuel filler
	for zc: float in TR_LOCO_TRUCKS: _tr_loco_truck(kit, zc)
	kit.add(gm, g.data())
	kit.add(pm, b.data())
	kit.add(_mat("glass"), gl.data())
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
	for zc: float in TR_CAR_TRUCKS: _tr_truck(kit, zc, 2, TR_CAR_AXLE, TR_CAR_WHEEL)
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
	for zc: float in TR_CAR_TRUCKS: _tr_truck(kit, zc, 2, TR_CAR_AXLE, TR_CAR_WHEEL)
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
	for zc: float in TR_CAR_TRUCKS: _tr_truck(kit, zc, 2, TR_CAR_AXLE, TR_CAR_WHEEL)
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
	for zc: float in TR_CAR_TRUCKS: _tr_truck(kit, zc, 2, TR_CAR_AXLE, TR_CAR_WHEEL)
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
	# "mesh" is the close wheelset (under about 25 m), "mesh_mid" a lighter one (to about 80 m) and "mesh_far" two plain
	# six-sided discs for distant cars, to keep a whole train cheap.
	var loco_w := {"mesh": _tr_wheelset(TR_LOCO_WHEEL, 2), "mesh_mid": _tr_wheelset(TR_LOCO_WHEEL, 1), "mesh_far": _tr_wheelset(TR_LOCO_WHEEL, 0),
		"positions": _tr_axles(TR_LOCO_TRUCKS, 3, TR_LOCO_AXLE, TR_LOCO_WHEEL), "radius": TR_LOCO_WHEEL}
	var wheels := {"locomotive": loco_w}
	for kind in ["boxcar", "hopper", "tanker", "flatcar", "flatcar_empty"]:
		wheels[kind] = {"mesh": _tr_wheelset(TR_CAR_WHEEL, 2), "mesh_mid": _tr_wheelset(TR_CAR_WHEEL, 1), "mesh_far": _tr_wheelset(TR_CAR_WHEEL, 0),
			"positions": _tr_axles(TR_CAR_TRUCKS, 2, TR_CAR_AXLE, TR_CAR_WHEEL), "radius": TR_CAR_WHEEL}
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
## A shell lofted through sections [z, cx, cy, half width, half height] like DroneParts.loft (squareness e), but with the
## ring points at the given angles (degrees, 0 = the +x side, 90 = the top), so paint and window edges can follow mesh lines.
static func _aloft(sections: Array, angles: Array, e := 2.0) -> Array:
	var rows: Array = []
	var cens: Array[Vector3] = []
	var ex := 2.0 / e
	for s: Array in sections:
		var r := PackedVector3Array()
		for ad: float in angles:
			var a := deg_to_rad(ad)
			var ca := cos(a); var sa := sin(a)
			r.append(Vector3(float(s[1]) + float(s[3]) * signf(ca) * pow(absf(ca), ex), float(s[2]) + float(s[4]) * signf(sa) * pow(absf(sa), ex), float(s[0])))
		rows.append(r); cens.append(Vector3(float(s[1]), float(s[2]), float(s[0])))
	var hint := func(i: int, _j: int, p: Vector3) -> Vector3:
		var h := p - cens[i]
		if h.length_squared() < 1e-14: return Vector3(0, 0, signf(cens[i].z - cens[clampi(i + (1 if i == 0 else -1), 0, cens.size() - 1)].z))
		return h
	return DroneParts.grid(rows, false, true, hint)

## The section [cy, half width, half height] of a loft at z, interpolated between its stations (sections as for _aloft).
static func _sec_at(sections: Array, z: float) -> Vector3:
	for k in range(1, sections.size()):
		var s1: Array = sections[k]
		if z <= float(s1[0]) or k == sections.size() - 1:
			var s0: Array = sections[k - 1]
			var t := clampf(inverse_lerp(float(s0[0]), float(s1[0]), z), 0.0, 1.0)
			return Vector3(lerpf(float(s0[2]), float(s1[2]), t), lerpf(float(s0[3]), float(s1[3]), t), lerpf(float(s0[4]), float(s1[4]), t))
	return Vector3.ZERO

## A point on an elliptic loft (e = 2) at z and ring angle a (degrees, 0 the side, 90 the top; sx -1 mirrors it to the
## left), lifted off the surface by `off` (for windows and seams drawn on it).
static func _on_loft(sections: Array, z: float, a: float, sx: float, off: float) -> Vector3:
	var s := _sec_at(sections, z)
	var r := deg_to_rad(a)
	return Vector3(sx * (s.y + off) * cos(r), s.x + (s.z + off) * sin(r), z)

## Triangles [pos, nrm(, cols)] split by keep(centre) into [kept, rest].
static func _split(data: Array, keep: Callable) -> Array:
	var pos: PackedVector3Array = data[0]; var nrm: PackedVector3Array = data[1]
	var pa := PackedVector3Array(); var na := PackedVector3Array(); var pb := PackedVector3Array(); var nb := PackedVector3Array()
	for k in range(0, pos.size(), 3):
		var c := (pos[k] + pos[k + 1] + pos[k + 2]) / 3.0
		if keep.call(c):
			pa.append_array([pos[k], pos[k + 1], pos[k + 2]]); na.append_array([nrm[k], nrm[k + 1], nrm[k + 2]])
		else:
			pb.append_array([pos[k], pos[k + 1], pos[k + 2]]); nb.append_array([nrm[k], nrm[k + 1], nrm[k + 2]])
	return [[pa, na], [pb, nb]]

## The same surface seen from inside (windings and normals reversed): cabin linings behind glass.
static func _inside(data: Array) -> Array:
	var pos: PackedVector3Array = data[0]; var nrm: PackedVector3Array = data[1]
	var p2 := PackedVector3Array(); var n2 := PackedVector3Array()
	for k in range(0, pos.size(), 3):
		p2.append_array([pos[k], pos[k + 2], pos[k + 1]]); n2.append_array([-nrm[k], -nrm[k + 2], -nrm[k + 1]])
	return [p2, n2]

## A lifting-surface station [leading edge, chord vector, thickness vector] for a section loop made at 12 % thickness: the
## chord c along `dir`, the thickness tc along `up`.
static func _st(le: Vector3, dir: Vector3, up: Vector3, c: float, tc: float) -> Array:
	return [le, dir.normalized() * c, up.normalized() * c * tc / 0.12]

## See-through glass for the cockpits (the cabin behind it is drawn).
static func _clear_glass() -> StandardMaterial3D:
	if _mats.has("clear_glass"): return _mats["clear_glass"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.14, 0.18, 0.42); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.04; m.metallic = 0.2; m.metallic_specular = 0.9
	_mats["clear_glass"] = m
	return m

# A light twin rescue helicopter of the EC135 / BK117 kind: a rounded teardrop cabin with a big wraparound bubble windscreen
# and chin windows, two pilots in their seats behind an instrument panel (seen through the glass), hinged cockpit doors and a
# sliding cabin door on its rail, the engine cowling hump with intakes and two exhausts, a slim tail boom with a stabiliser
# and end plates, the fin with a conventional two-bladed tail rotor on its left, skids on arched cross tubes, a searchlight
# under the nose and a rescue hoist. Red and white, no operator marks. Four main blades 10.2 m across.
const HC_ROTOR := Vector3(0.0, 3.38, 0.0)
const HC_TAIL := Vector3(-0.3, 2.78, 6.72)
const HC_R := 5.1
const HC_TR := 0.97
const SYM4 := [Vector2(0, 0), Vector2(0.3, 0.5), Vector2(1.0, 0.0), Vector2(0.3, -0.5)]
const HC_BODY := [[-3.95, 0.0, 1.12, 0.0, 0.0], [-3.9, 0.0, 1.12, 0.22, 0.22], [-3.75, 0.0, 1.14, 0.43, 0.45], [-3.55, 0.0, 1.18, 0.58, 0.6],
	[-3.25, 0.0, 1.24, 0.7, 0.72], [-2.9, 0.0, 1.3, 0.77, 0.8], [-2.55, 0.0, 1.34, 0.8, 0.84], [-2.2, 0.0, 1.36, 0.82, 0.86], [-1.95, 0.0, 1.37, 0.82, 0.87],
	[-1.85, 0.0, 1.37, 0.82, 0.87], [-0.8, 0.0, 1.39, 0.82, 0.86], [-0.65, 0.0, 1.39, 0.82, 0.86], [0.45, 0.0, 1.42, 0.8, 0.84], [1.1, 0.0, 1.5, 0.72, 0.74],
	[1.7, 0.0, 1.62, 0.55, 0.58], [2.3, 0.0, 1.78, 0.36, 0.38], [2.9, 0.0, 1.9, 0.22, 0.23], [4.8, 0.0, 1.96, 0.16, 0.17], [6.7, 0.0, 2.0, 0.12, 0.13],
	[7.0, 0.0, 2.01, 0.1, 0.11], [7.06, 0.0, 2.01, 0.0, 0.0]]

## The helicopter: {"body", "main_rotor", "rotor_pivot", "tail_rotor", "tail_pivot", "main_spin_sign", "tail_spin_sign",
## "rotor_radius", "tail_radius", "length"}. Origin: the ground under the mast, between the skids. The main rotor turns about
## its own +Y at rotor_pivot (clockwise seen from above: rotate by main_spin_sign * omega * t); the tail rotor about its own
## +X at tail_pivot (about 5 times as fast).
static func helicopter() -> Dictionary:
	if _cache.has("helicopter"): return _cache["helicopter"]
	var gm := _mat("gloss"); var pm := _mat("paint")
	var I := Transform3D.IDENTITY
	var white := Color(0.94, 0.94, 0.93); var red := Color(0.78, 0.06, 0.06); var dark := Color(0.12, 0.12, 0.13); var grey := Color(0.55, 0.56, 0.58)
	var kit := DroneParts.Kit.new()
	var b := Buf.new()
	var loop := NewModels._section(0.12, 0.0, 4)
	# ---- the body shell: ring points on the window and paint edges, so the glass and the red follow the mesh lines
	var base := [-90.0, -70.0, -52.0, -36.0, -20.0, -8.0, 0.0, 8.0, 22.0, 36.0, 48.0, 62.0, 76.0, 85.0]
	var ring: Array = base.duplicate()
	ring.append(90.0)
	for k in range(base.size() - 1, 0, -1): ring.append(180.0 - float(base[k]))
	var elev := func(p: Vector3) -> float:                 # the ring angle (0 the side, 90 the top) of a point on the body
		var s := _sec_at(HC_BODY, p.z)
		if s.y < 1e-4 or s.z < 1e-4: return 0.0
		return rad_to_deg(atan2((p.y - s.x) / s.z, absf(p.x) / s.y))
	var is_glass := func(p: Vector3) -> bool:
		var t: float = elev.call(p)
		if p.z < -1.95 and t > 0.0 and t < 85.0: return true            # the wraparound windscreen
		if p.z > -3.55 and p.z < -2.55 and t > -52.0 and t < -20.0: return true         # chin windows
		if p.z > -1.85 and p.z < -0.8 and t > 0.0 and t < 48.0: return true             # cockpit doors
		if p.z > -0.65 and p.z < 0.45 and t > 8.0 and t < 48.0: return true             # sliding cabin door
		return false
	var parts := _split(_aloft(HC_BODY, ring, 2.0), is_glass)
	var body_col := func(p: Vector3, _n: Vector3) -> Color:
		var t: float = elev.call(p)
		if p.z > 2.3: return red if t < 30.0 else white                                 # the boom, red with a white top
		if t < -8.0: return red                                                          # red below the waist
		if p.z < -3.75 and t < 0.0: return red                                           # the nose
		return white
	kit.add(gm, NewModels._paint(parts[1], body_col))
	kit.add(_clear_glass(), parts[0], I, Color.WHITE)
	# the cabin lining (seen through the glass) and the cockpit: floor, panel and glare shield, console, seats, two pilots
	var lining: Array = []
	for s: Array in HC_BODY:
		if float(s[0]) <= 0.45: lining.append([s[0], s[1], s[2], maxf(float(s[3]) - 0.04, 0.0), maxf(float(s[4]) - 0.04, 0.0)])
	kit.add(pm, _inside(DroneParts.loft(lining, 2.0, 14, true)), I, Color(0.2, 0.2, 0.22))
	kit.add(pm, NewModels._box(Vector3(1.4, 0.06, 4.0)), NewModels._xf(Vector3(0, 0.62, -1.6)), Color(0.16, 0.16, 0.17))
	kit.add(pm, NewModels._box(Vector3(1.24, 0.36, 0.14)), Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, 1.3, -2.95)), Color(0.05, 0.05, 0.06))   # instrument panel
	kit.add(pm, NewModels._box(Vector3(1.28, 0.05, 0.34)), NewModels._xf(Vector3(0, 1.5, -2.88)), Color(0.08, 0.08, 0.09))                             # glare shield
	kit.add(pm, NewModels._box(Vector3(0.28, 0.5, 0.7)), NewModels._xf(Vector3(0, 0.9, -2.55)), Color(0.07, 0.07, 0.08))                               # centre console
	for k in 4:      # screens on the panel
		kit.add(pm, NewModels._box(Vector3(0.22, 0.17, 0.02)), Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(-0.45 + k * 0.3, 1.32, -3.03)), Color(0.12, 0.2, 0.28))
	var suit := Color(0.12, 0.16, 0.22)
	for sx: float in [-1.0, 1.0]:
		var x := sx * 0.36
		kit.add(pm, NewModels._box(Vector3(0.48, 0.1, 0.5)), NewModels._xf(Vector3(x, 0.92, -1.9)), Color(0.1, 0.1, 0.11))                              # seat pan
		kit.add(pm, NewModels._box(Vector3(0.48, 0.8, 0.1)), Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(x, 1.36, -1.6)), Color(0.1, 0.1, 0.11))     # seat back
		kit.add(pm, DroneParts.loft([[-0.14, 0.0, 0.0, 0.17, 0.26], [0.0, 0.0, 0.02, 0.21, 0.3], [0.13, 0.0, 0.0, 0.17, 0.26]], 3.0, 8, true), Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(x, 1.3, -1.78)), suit)   # torso
		kit.add(pm, DroneParts.sphere(0.13, 8), NewModels._xf(Vector3(x, 1.76, -1.84)), Color(0.32, 0.33, 0.35))                                                         # helmet
		kit.add(pm, NewModels._box(Vector3(0.22, 0.09, 0.05)), NewModels._xf(Vector3(x, 1.75, -1.96)), Color(0.02, 0.02, 0.03))                         # visor
		for lx: float in [-0.1, 0.1]:
			_bar(b, Vector3(x + lx, 0.98, -2.0), Vector3(x + lx, 0.98, -2.55), 0.12, suit)                                                             # thighs
			_bar(b, Vector3(x + lx, 0.98, -2.55), Vector3(x + lx, 0.7, -2.75), 0.1, suit)                                                              # shins
		_bar(b, Vector3(x + sx * 0.19, 1.48, -1.82), Vector3(x + sx * 0.12, 1.1, -2.2), 0.08, suit)                                                     # arms to the sticks
		_bar(b, Vector3(x - sx * 0.19, 1.48, -1.82), Vector3(x - sx * 0.2, 1.05, -2.15), 0.08, suit)
		_bar(b, Vector3(x, 0.72, -2.25), Vector3(x, 1.05, -2.25), 0.035, dark)                                                                         # cyclic
	kit.add(pm, NewModels._box(Vector3(1.3, 0.1, 0.45)), NewModels._xf(Vector3(0, 0.95, -0.2)), Color(0.15, 0.17, 0.2))     # cabin bench behind the pilots
	kit.add(pm, NewModels._box(Vector3(1.3, 0.6, 0.1)), NewModels._xf(Vector3(0, 1.3, 0.05)), Color(0.15, 0.17, 0.2))
	# door seams: the hinged cockpit doors and the sliding cabin door with its rail
	var seam := Color(0.25, 0.25, 0.27)
	for sx: float in [-1.0, 1.0]:
		var ts := [-34.0, -20.0, -8.0, 0.0, 8.0, 22.0, 36.0, 48.0, 56.0]
		for zs: float in [-1.92, -0.73, 0.52]:
			for k in ts.size() - 1:
				var p0 := _on_loft(HC_BODY, zs, float(ts[k]), sx, 0.004); var p1 := _on_loft(HC_BODY, zs, float(ts[k + 1]), sx, 0.004)
				var nn := Vector3(sx * cos(deg_to_rad(float(ts[k]))), sin(deg_to_rad(float(ts[k]))), 0.0)
				b.quad(p0 - Vector3(0, 0, 0.012), p0 + Vector3(0, 0, 0.012), p1 + Vector3(0, 0, 0.012), p1 - Vector3(0, 0, 0.012), seam, nn)
		for zz: Array in [[-1.92, -0.73], [-0.73, 0.52]]:
			var q0 := _on_loft(HC_BODY, float(zz[0]), 56.0, sx, 0.004); var q1 := _on_loft(HC_BODY, float(zz[1]), 56.0, sx, 0.004)
			b.quad(q0 - Vector3(0, 0.01, 0), q1 - Vector3(0, 0.01, 0), q1 + Vector3(0, 0.01, 0), q0 + Vector3(0, 0.01, 0), seam, Vector3(sx * 0.56, 0.83, 0))
		var r0 := _on_loft(HC_BODY, -0.7, -14.0, sx, 0.03); var r1 := _on_loft(HC_BODY, 1.3, -14.0, sx, 0.03)
		_bar(b, r0, r1, 0.04, grey)                                                                                                                    # door rail
		_bar(b, _on_loft(HC_BODY, -1.1, 18.0, sx, 0.02), _on_loft(HC_BODY, -0.95, 18.0, sx, 0.02), 0.025, dark)                                         # handles
		_bar(b, _on_loft(HC_BODY, 0.15, 18.0, sx, 0.02), _on_loft(HC_BODY, 0.35, 18.0, sx, 0.02), 0.025, dark)
	# ---- engine cowling with intakes and two exhausts, the mast fairing and the mast
	kit.add(gm, DroneParts.loft([[-1.85, 0.0, 2.2, 0.0, 0.0], [-1.75, 0.0, 2.22, 0.35, 0.18], [-1.4, 0.0, 2.26, 0.58, 0.3], [-0.6, 0.0, 2.3, 0.62, 0.36], [0.6, 0.0, 2.3, 0.62, 0.36],
		[1.3, 0.0, 2.2, 0.55, 0.3], [1.9, 0.0, 2.05, 0.34, 0.2], [2.1, 0.0, 2.0, 0.0, 0.0]], 3.0, 16), I, white)
	for sx: float in [-1.0, 1.0]:
		b.quad(Vector3(sx * 0.633, 2.2, -1.05), Vector3(sx * 0.633, 2.2, -0.2), Vector3(sx * 0.633, 2.44, -0.2), Vector3(sx * 0.633, 2.44, -1.05), Color(0.06, 0.06, 0.07), Vector3(sx, 0, 0))
		for k in 5:
			var zg := lerpf(-1.0, -0.25, (k + 0.5) / 5.0)
			b.quad(Vector3(sx * 0.637, 2.21, zg - 0.015), Vector3(sx * 0.637, 2.21, zg + 0.015), Vector3(sx * 0.637, 2.43, zg + 0.015), Vector3(sx * 0.637, 2.43, zg - 0.015), Color(0.35, 0.35, 0.37), Vector3(sx, 0, 0))
		kit.add(gm, DroneParts.tube(Vector3(sx * 0.4, 2.42, 1.0), Vector3(sx * 0.58, 2.5, 1.78), 0.13, 0.12, 8), I, Color(0.24, 0.24, 0.25))
		kit.add(pm, DroneParts.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.1, 0)]), 8), DroneParts.along(Vector3(sx * 0.58, 2.5, 1.78), Vector3(sx * 0.6, 2.5, 1.9)) * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.001)), Color(0.03, 0.03, 0.03))
	kit.add(gm, DroneParts.lathe(PackedVector2Array([Vector2(0.0, 3.0), Vector2(0.18, 2.96), Vector2(0.36, 2.82), Vector2(0.46, 2.66), Vector2(0.5, 2.5)]), 14), I, white)
	kit.add(gm, DroneParts.tube(Vector3(0, 2.95, 0), Vector3(0, HC_ROTOR.y - 0.08, 0), 0.1, 0.09, 8), I, dark)
	# ---- tail: stabiliser with end plates, the fin and ventral fin, tail skid, tail rotor gearbox
	var fw := Vector3(0, 0, 1)
	kit.add(gm, NewModels._foil([_st(Vector3(-1.38, 2.02, 5.08), fw, Vector3.UP, 0.52, 0.12), _st(Vector3(0, 2.02, 4.98), fw, Vector3.UP, 0.64, 0.12), _st(Vector3(1.38, 2.02, 5.08), fw, Vector3.UP, 0.52, 0.12)], loop), I, white)
	for sx: float in [-1.0, 1.0]:
		kit.add(gm, NewModels._foil([_st(Vector3(sx * 1.39, 1.78, 5.0), fw, Vector3(sx, 0, 0), 0.62, 0.1), _st(Vector3(sx * 1.39, 2.38, 5.16), fw, Vector3(sx, 0, 0), 0.44, 0.1)], loop), I, red)
	kit.add(gm, NewModels._foil([_st(Vector3(0, 2.05, 6.12), fw, Vector3(1, 0, 0), 0.9, 0.14), _st(Vector3(0, 2.6, 6.42), fw, Vector3(1, 0, 0), 0.68, 0.13), _st(Vector3(0, 3.22, 6.76), fw, Vector3(1, 0, 0), 0.42, 0.12)], loop), I, red)
	kit.add(gm, NewModels._foil([_st(Vector3(0, 1.98, 6.4), fw, Vector3(1, 0, 0), 0.62, 0.12), _st(Vector3(0, 1.5, 6.78), fw, Vector3(1, 0, 0), 0.32, 0.12)], loop), I, red)
	_bar(b, Vector3(0, 1.55, 6.95), Vector3(0, 1.42, 7.2), 0.04, grey)
	kit.add(gm, NewModels._box(Vector3(0.24, 0.3, 0.32)), NewModels._xf(Vector3(-0.12, HC_TAIL.y, HC_TAIL.z)), grey)
	# ---- skids on two arched cross tubes, with steps
	for sx: float in [-1.0, 1.0]:
		var pts := [Vector3(sx * 1.08, 0.045, 1.65), Vector3(sx * 1.08, 0.045, -1.75), Vector3(sx * 1.08, 0.1, -2.22), Vector3(sx * 1.08, 0.3, -2.46), Vector3(sx * 1.08, 0.5, -2.52)]
		var rr := [0.045, 0.045, 0.045, 0.042, 0.04]
		kit.add(gm, NewModels._sweep(pts, rr, rr, 8, Vector3.UP), I, grey)
		kit.add(pm, NewModels._box(Vector3(0.26, 0.025, 0.42)), NewModels._xf(Vector3(sx * 0.98, 0.32, -1.18)), dark)
	for z: float in [-1.2, 0.9]:
		var pts2 := [Vector3(-1.08, 0.045, z), Vector3(-1.04, 0.3, z), Vector3(-0.88, 0.52, z), Vector3(-0.5, 0.6, z), Vector3(0.5, 0.6, z), Vector3(0.88, 0.52, z), Vector3(1.04, 0.3, z), Vector3(1.08, 0.045, z)]
		var r2: Array = []; r2.resize(pts2.size()); r2.fill(0.045)
		kit.add(gm, NewModels._sweep(pts2, r2, r2, 8, Vector3(0, 0, 1)), I, grey)
	# ---- searchlight under the nose, the hoist over the right door, antennas and pitot tubes
	var light := Transform3D(Basis(Vector3.RIGHT, -PI * 0.62), Vector3(0.28, 0.52, -2.9))
	kit.add(gm, DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, -0.02), Vector2(0.15, -0.02), Vector2(0.15, 0.16), Vector2(0.1, 0.22), Vector2(0, 0.22)])), 12), light, dark)
	kit.add(_mat("lamp"), DroneParts.lathe(PackedVector2Array([Vector2(0, -0.025), Vector2(0.13, -0.025)]), 12), light)
	kit.add(gm, NewModels._box(Vector3(0.08, 0.14, 0.08)), NewModels._xf(Vector3(0.28, 0.6, -2.9)), dark)
	kit.add(gm, _beam(Vector3(0.72, 2.4, -0.25), Vector3(1.28, 2.4, -0.25), 0.1, 0.1), I, grey)
	kit.add(gm, NewModels._box(Vector3(0.26, 0.3, 0.46)), NewModels._xf(Vector3(1.32, 2.28, -0.25)), grey)
	_bar(b, Vector3(1.32, 2.12, -0.25), Vector3(1.32, 1.7, -0.25), 0.012, dark)
	kit.add(gm, NewModels._box(Vector3(0.07, 0.1, 0.07)), NewModels._xf(Vector3(1.32, 1.66, -0.25)), Color(0.85, 0.65, 0.1))
	kit.add(gm, _beam(Vector3(0, 2.5, 1.4), Vector3(0, 2.88, 1.62), 0.03, 0.08), I, dark)
	kit.add(gm, _beam(Vector3(0, 0.55, -0.6), Vector3(0, 0.32, -0.4), 0.03, 0.08), I, dark)
	for sx: float in [-1.0, 1.0]:
		_bar(b, Vector3(sx * 0.22, 1.62, -3.62), Vector3(sx * 0.22, 1.62, -3.98), 0.025, grey)
	kit.add(pm, b.data())
	# ---- main rotor: hub, grips and four blades with a proper aerofoil and a swept tip; its own mesh, turning about +Y
	var rk := DroneParts.Kit.new()
	rk.add(gm, DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, -0.12), Vector2(0.24, -0.12), Vector2(0.24, 0.06), Vector2(0.14, 0.16), Vector2(0, 0.2)])), 12), I, Color(0.3, 0.3, 0.32))
	var bl := NewModels._section(0.12, 0.02, 5)
	var stations: Array = []
	for bs: Array in [[0.3, 0.16, 10.0, 0.0, 0.3], [0.6, 0.26, 9.5, 0.0, 0.16], [1.0, 0.3, 9.0, 0.0, 0.12], [4.4, 0.3, 4.5, 0.0, 0.12], [4.8, 0.27, 4.0, 0.035, 0.11], [5.03, 0.16, 3.5, 0.12, 0.1], [HC_R, 0.05, 3.5, 0.22, 0.08]]:
		var x: float = bs[0]; var c: float = bs[1]; var pit := deg_to_rad(float(bs[2]))
		var d := Vector3(0, -sin(pit), -cos(pit)); var u := Vector3(0, cos(pit), -sin(pit))
		stations.append(_st(Vector3(x, 0, 0) - d * (0.25 * c - float(bs[3])), d, u, c, float(bs[4])))
	var blade_col := func(p: Vector3, _n: Vector3) -> Color:
		if p.x > 4.62 and p.x < 4.85: return Color(0.95, 0.8, 0.15)
		return Color(0.15, 0.15, 0.16)
	var blade := NewModels._paint(NewModels._foil(stations, bl), blade_col)
	for k in 4:
		var bb := Basis(Vector3.UP, TAU * k / 4.0)
		rk.add(gm, blade, Transform3D(bb, Vector3.ZERO))
		rk.add(gm, NewModels._box(Vector3(0.5, 0.1, 0.18)), Transform3D(bb, bb * Vector3(0.38, 0, 0)), Color(0.3, 0.3, 0.32))
	# ---- tail rotor: two blades in the y-z plane, turning about +X
	var tk := DroneParts.Kit.new()
	var tstat: Array = []
	for ts2: Array in [[0.12, 0.17], [0.85, 0.16], [HC_TR - 0.02, 0.12], [HC_TR, 0.05]]:
		tstat.append(_st(Vector3(0, float(ts2[0]), 0.06), Vector3(0, 0, -1), Vector3(1, 0, 0), float(ts2[1]), 0.1))
	var tblade := NewModels._foil(tstat, bl)
	var tcol := func(p: Vector3, _n: Vector3) -> Color: return red if absf(p.y) > 0.7 or absf(p.y) < 0.4 else white
	for k in 2:
		tk.add(gm, NewModels._paint(DroneParts._apply(tblade, Transform3D(Basis(Vector3.RIGHT, PI * k), Vector3.ZERO)), tcol))
	tk.add(gm, DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, -0.06), Vector2(0.08, -0.06), Vector2(0.08, 0.04), Vector2(0, 0.08)])), 8), Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3.ZERO), Color(0.3, 0.3, 0.32))
	var out := {"body": kit.commit(), "main_rotor": rk.commit(), "rotor_pivot": HC_ROTOR, "tail_rotor": tk.commit(), "tail_pivot": HC_TAIL,
		"main_spin_sign": -1.0, "tail_spin_sign": 1.0, "rotor_radius": HC_R, "tail_radius": HC_TR, "length": 11.12}
	_cache["helicopter"] = out
	return out

# A twin-jet narrowbody of the A320 / 737 class: 38 m long, a round fuselage (3.96 m) with a drooped nose, the six-panel
# cockpit windscreen, a dark row of cabin windows, a belly fairing; a low wing with 25 degree quarter-chord sweep, 5 degree
# dihedral, a cranked trailing edge, flap-track fairings and blended winglets; two high-bypass engines under the wings with
# intake lips, fans, core cowls and exhaust plugs; a swept tailplane and a tall swept fin with its rudder hinge, in a plain
# blue with a lighter band. White, grey belly, no marks. Origin: the middle of the fuselage at the wing root; nose towards -z.
const AL_FUS := [[-19.0, 0.0, -0.62, 0.0, 0.0], [-18.93, 0.0, -0.6, 0.24, 0.22], [-18.75, 0.0, -0.55, 0.52, 0.5], [-18.4, 0.0, -0.46, 0.86, 0.86],
	[-17.9, 0.0, -0.34, 1.2, 1.24], [-17.3, 0.0, -0.22, 1.5, 1.56], [-16.6, 0.0, -0.12, 1.74, 1.8], [-15.8, 0.0, -0.04, 1.9, 1.98], [-14.8, 0.0, 0.0, 1.97, 2.06],
	[-13.5, 0.0, 0.0, 1.98, 2.07], [8.0, 0.0, 0.0, 1.98, 2.07], [10.5, 0.0, 0.12, 1.9, 1.95], [13.0, 0.0, 0.42, 1.65, 1.6], [15.3, 0.0, 0.82, 1.2, 1.12],
	[17.2, 0.0, 1.18, 0.72, 0.66], [18.4, 0.0, 1.4, 0.36, 0.33], [18.85, 0.0, 1.48, 0.17, 0.16], [19.0, 0.0, 1.5, 0.0, 0.0]]
const AL_ENG_X := 5.75
const AL_SPAN := 33.95

static func _al_le(x: float) -> float: return -4.3 + (x - 1.95) * 0.5095          # leading edge (27 degrees)
static func _al_te(x: float) -> float: return 2.3 + (x - 1.95) * 0.0575 if x <= 6.3 else 2.55 + (x - 6.3) * 0.197
static func _al_y(x: float) -> float: return -1.25 + (x - 1.95) * 0.0893           # 5.1 degrees dihedral

## Fin station at height y: the dorsal fillet into a 40 degree leading edge.
static func _al_fin(y: float) -> Array:
	var le := 0.0; var c := 0.0
	if y < 2.7:
		var t := inverse_lerp(1.6, 2.7, y); le = lerpf(10.2, 11.85, t); c = lerpf(7.8, 5.9, t)
	else:
		var t2 := inverse_lerp(2.7, 7.9, y); le = lerpf(11.85, 16.6, t2); c = lerpf(5.9, 2.25, t2)
	return _st(Vector3(0, y, le), Vector3(0, 0, 1), Vector3(1, 0, 0), c, 0.1)

## The airliner. gear true draws the landing gear down (nose leg and two twin-wheel main legs with their doors).
## Returns {"mesh": ArrayMesh, "mesh_far": ArrayMesh, "length": 38.0, "wingspan": float, "height": float, "gear": bool}:
## "mesh" for anything nearer than about 2 km, "mesh_far" (about 300 triangles, gear up) beyond.
static func airliner_far(gear := false) -> Dictionary:
	var key := "airliner_%d" % int(gear)
	if _cache.has(key): return _cache[key]
	var out := {"mesh": _al_mesh(gear), "mesh_far": _al_far(), "length": 38.0, "wingspan": AL_SPAN, "height": 11.8 if gear else 7.9, "gear": gear}
	_cache[key] = out
	return out

static func _al_mesh(gear: bool) -> ArrayMesh:
	var kit := DroneParts.Kit.new()
	var pm := _mat("paint"); var gm := _mat("gloss")
	var I := Transform3D.IDENTITY
	var white := Color(0.95, 0.95, 0.95); var belly := Color(0.7, 0.72, 0.74); var wingc := Color(0.78, 0.79, 0.81)
	var fin := Color(0.06, 0.2, 0.46); var band := Color(0.38, 0.66, 0.9)
	var b := Buf.new()
	var gl := Buf.new()
	var loop := NewModels._section(0.12, 0.025, 4)
	var sym := NewModels._section(0.12, 0.0, 4)
	# ---- fuselage, belly fairing
	# ring points on the belly paint line (34 degrees below the side), so the grey belly has a clean edge
	var fus_col := func(p: Vector3, _n: Vector3) -> Color:
		var s := _sec_at(AL_FUS, p.z)
		if s.y < 1e-4: return white
		return belly if rad_to_deg(atan2((p.y - s.x) / s.z, absf(p.x) / s.y)) < -34.0 else white
	kit.add(gm, NewModels._paint(_aloft(AL_FUS, [-90.0, -62.0, -34.0, -12.0, 10.0, 32.0, 55.0, 75.0, 90.0, 105.0, 125.0, 148.0, 170.0, 192.0, 214.0, 242.0], 2.0), fus_col))
	kit.add(gm, DroneParts.loft([[-7.0, 0.0, -1.5, 0.0, 0.0], [-6.3, 0.0, -1.55, 1.2, 0.55], [-4.5, 0.0, -1.62, 1.75, 0.7], [3.5, 0.0, -1.62, 1.8, 0.72], [6.3, 0.0, -1.55, 1.4, 0.55], [7.6, 0.0, -1.4, 0.0, 0.0]], 2.4, 10), I, belly)
	# ---- cockpit: six windscreen panels on the nose (dark glass), a cabin window row with gaps at the doors and exits, doors
	var panels := [[[-18.12, 84.0], [-17.55, 36.0], [-17.0, 60.0], [-17.12, 86.0]], [[-17.45, 32.0], [-16.75, 24.0], [-16.6, 50.0], [-16.92, 60.0]],
		[[-16.65, 23.0], [-16.1, 20.0], [-16.15, 42.0], [-16.5, 48.0]]]
	for sx: float in [-1.0, 1.0]:
		for pi in panels.size():
			var pn: Array = panels[pi]
			var ns := 3 if pi == 0 else 2           # the big front pane wraps the most, so cut it finer
			var st := 1.0 / ns
			var c0: Array = pn[0]; var c1: Array = pn[1]; var c2: Array = pn[2]; var c3: Array = pn[3]
			for i in ns:
				for j in ns:
					var f := func(u: float, v: float) -> Vector3:
						var zb := lerpf(float(c0[0]), float(c1[0]), u); var ab := lerpf(float(c0[1]), float(c1[1]), u)
						var zt := lerpf(float(c3[0]), float(c2[0]), u); var at := lerpf(float(c3[1]), float(c2[1]), u)
						return _on_loft(AL_FUS, lerpf(zb, zt, v), lerpf(ab, at, v), sx, 0.025)
					var p00: Vector3 = f.call(i * st, j * st); var p10: Vector3 = f.call(i * st + st, j * st)
					var p11: Vector3 = f.call(i * st + st, j * st + st); var p01: Vector3 = f.call(i * st, j * st + st)
					var nn := (p10 - p00).cross(p01 - p00).normalized()
					if nn.dot(Vector3(sx, 0.4, -0.3)) < 0.0: nn = -nn
					gl.quad(p00, p10, p11, p01, Color.WHITE, nn)
		for seg: Array in [[-12.9, -2.75], [-1.5, -0.95], [-0.5, 7.5]]:
			var za: float = seg[0]; var zb2: float = seg[1]
			var pa := _on_loft(AL_FUS, za, 14.0, sx, 0.012); var pb := _on_loft(AL_FUS, zb2, 14.0, sx, 0.012)
			var pc := _on_loft(AL_FUS, zb2, 23.5, sx, 0.012); var pd := _on_loft(AL_FUS, za, 23.5, sx, 0.012)
			b.quad(pa, pb, pc, pd, Color(0.06, 0.07, 0.1), Vector3(sx * 0.95, 0.3, 0))
		for dr: Array in [[-14.25, -13.4, -28.0, 30.0], [8.1, 8.9, -28.0, 30.0], [-2.5, -1.75, -6.0, 26.0], [-0.85, -0.6, -6.0, 26.0]]:
			var d0: float = dr[0]; var d1: float = dr[1]; var a0: float = dr[2]; var a1: float = dr[3]
			for k in 3:
				var aa := lerpf(a0, a1, k / 3.0); var ab2 := lerpf(a0, a1, (k + 1) / 3.0)
				b.quad(_on_loft(AL_FUS, d0, aa, sx, 0.008), _on_loft(AL_FUS, d1, aa, sx, 0.008), _on_loft(AL_FUS, d1, ab2, sx, 0.008), _on_loft(AL_FUS, d0, ab2, sx, 0.008), Color(0.8, 0.81, 0.83), Vector3(sx * cos(deg_to_rad(aa)), sin(deg_to_rad(aa)), 0))
	# ---- wings with winglets, flap-track fairings; pylons and engines
	var inc := deg_to_rad(2.0)
	var cv := Vector3(0, -sin(inc), cos(inc))
	for sx: float in [-1.0, 1.0]:
		var dih := Basis(Vector3(0, 0, 1), sx * deg_to_rad(5.1))
		var up := dih * Vector3(0, cos(inc), sin(inc))
		var wst: Array = []
		for x: float in [0.6, 1.95, 6.3, 11.0, 16.0, 16.5]:
			var tc := lerpf(0.15, 0.11, clampf((x - 1.95) / 4.35, 0.0, 1.0)) if x < 6.3 else lerpf(0.11, 0.1, (x - 6.3) / 10.2)
			wst.append(_st(Vector3(sx * x, _al_y(x), _al_le(x)), cv, up, _al_te(x) - _al_le(x), tc))
		kit.add(gm, NewModels._foil(wst, loop), I, wingc)
		var yt := _al_y(16.5)
		kit.add(gm, NewModels._foil([_st(Vector3(sx * 16.45, yt, _al_le(16.45)), Vector3(0, 0, 1), up, 1.42, 0.1), _st(Vector3(sx * 16.8, yt + 0.3, 3.45), Vector3(0, 0, 1), Vector3(-sx * 0.7, 0.7, 0), 1.08, 0.1),
			_st(Vector3(sx * 16.95, yt + 2.3, 4.75), Vector3(0, 0, 1), Vector3(-sx, 0.05, 0), 0.45, 0.1)], loop), I, fin)
		for fx: float in [8.6, 12.6]:
			var te := _al_te(fx); var fy := _al_y(fx)
			kit.add(gm, DroneParts.loft([[te - 1.5, sx * fx, fy - 0.12, 0.0, 0.0], [te - 0.8, sx * fx, fy - 0.2, 0.13, 0.18], [te + 0.3, sx * fx, fy - 0.2, 0.12, 0.17], [te + 1.1, sx * fx, fy - 0.08, 0.0, 0.0]], 2.0, 5), I, wingc)
		kit.add(gm, NewModels._foil([_st(Vector3(sx * AL_ENG_X, -1.25, -4.3), Vector3(0, 0, 1), Vector3(1, 0, 0), 4.7, 0.08), _st(Vector3(sx * AL_ENG_X, -0.98, -2.7), Vector3(0, 0, 1), Vector3(1, 0, 0), 4.2, 0.08)], sym), I, wingc)
		kit.add(gm, _al_engine(10), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * AL_ENG_X, -2.2, -4.85)))
	# ---- tailplane, fin with a lighter band and the rudder hinge line
	for sx: float in [-1.0, 1.0]:
		var tst: Array = []
		for x: float in [0.3, 1.5, 6.2]:
			tst.append(_st(Vector3(sx * x, 0.55 + x * 0.105, 13.2 + x * 0.625), Vector3(0, 0, 1), Basis(Vector3(0, 0, 1), sx * deg_to_rad(6.0)) * Vector3.UP, 3.7 - (x - 0.3) * 0.398, 0.1))
		kit.add(gm, NewModels._foil(tst, sym), I, wingc)
	var fst: Array = []
	for y: float in [1.6, 2.7, 3.9, 4.6, 7.9]: fst.append(_al_fin(y))
	var fin_col := func(p: Vector3, _n: Vector3) -> Color: return band if p.y > 3.9 and p.y < 4.6 else fin
	kit.add(gm, NewModels._paint(NewModels._foil(fst, sym), fin_col))
	for k in 4:
		var ya := lerpf(2.7, 7.9, k / 4.0); var yb := lerpf(2.7, 7.9, (k + 1) / 4.0)
		var sa: Array = _al_fin(ya); var sb: Array = _al_fin(yb)
		var ha: Vector3 = (sa[0] as Vector3) + (sa[1] as Vector3) * 0.7; var hb: Vector3 = (sb[0] as Vector3) + (sb[1] as Vector3) * 0.7
		for sx: float in [-1.0, 1.0]:
			var oa := Vector3(sx * ((sa[1] as Vector3).length() * 0.035 + 0.006), 0, 0); var ob := Vector3(sx * ((sb[1] as Vector3).length() * 0.035 + 0.006), 0, 0)
			b.quad(ha + oa - Vector3(0, 0, 0.025), ha + oa + Vector3(0, 0, 0.025), hb + ob + Vector3(0, 0, 0.025), hb + ob - Vector3(0, 0, 0.025), Color(0.03, 0.1, 0.25), Vector3(sx, 0, 0))
	# ---- the landing gear, down
	if gear:
		var tire := DroneParts.lathe(PackedVector2Array([Vector2(0, -0.1), Vector2(0.3, -0.11), Vector2(0.38, 0.0), Vector2(0.3, 0.11), Vector2(0, 0.1)]), 7)
		var on_x := Basis(Vector3(0, 0, 1), -PI * 0.5)
		var tcol := Color(0.07, 0.07, 0.07); var leg := Color(0.6, 0.61, 0.63)
		kit.add(pm, DroneParts.tube(Vector3(0, -1.9, -15.2), Vector3(0, -3.75, -15.3), 0.09, 0.08, 5), I, leg)
		for sx: float in [-1.0, 1.0]:
			kit.add(pm, tire, Transform3D(on_x.scaled(Vector3(1, 1, 1)), Vector3(sx * 0.22, -3.79, -15.3)), tcol)
			kit.add(gm, NewModels._box(Vector3(0.03, 0.55, 1.3)), NewModels._xf(Vector3(sx * 0.4, -2.25, -15.0)), white)
			var mx := sx * 3.8
			kit.add(pm, DroneParts.tube(Vector3(mx, -1.35, 0.3), Vector3(mx, -3.55, 0.35), 0.13, 0.12, 5), I, leg)
			kit.add(pm, _beam(Vector3(mx - 0.5, -3.6, 0.35), Vector3(mx + 0.5, -3.6, 0.35), 0.12, 0.12), I, leg)
			kit.add(pm, _beam(Vector3(mx, -1.6, 1.3), Vector3(mx, -3.0, 0.4), 0.08, 0.08), I, leg)
			for wx: float in [-0.42, 0.42]:
				kit.add(pm, tire, Transform3D(on_x.scaled(Vector3(1.5, 1.5, 1.5)), Vector3(mx + wx, -3.6, 0.35)), tcol)
			kit.add(gm, NewModels._box(Vector3(0.04, 1.5, 0.9)), Transform3D(Basis(Vector3(0, 0, 1), sx * 0.08), Vector3(sx * 4.18, -2.3, 0.35)), white)
	kit.add(pm, b.data())
	kit.add(_mat("glass"), gl.data())
	return kit.commit()

## An engine nacelle along +Y (rotate onto +Z): spinner and fan face inside the intake, the lip, the fan cowl, the core
## cowl, the core nozzle and the exhaust plug, 4.45 m long and 2.16 m across.
static func _al_engine(seg: int) -> Array:
	var prof := PackedVector2Array([Vector2(0, 0.45), Vector2(0.82, 0.66), Vector2(0.82, 0.66), Vector2(0.86, 0.12), Vector2(0.96, 0.0), Vector2(1.05, 0.08), Vector2(1.08, 0.5),
		Vector2(1.06, 1.9), Vector2(0.93, 3.0), Vector2(0.93, 3.0), Vector2(0.72, 3.02), Vector2(0.6, 3.65), Vector2(0.48, 3.95), Vector2(0.48, 3.95), Vector2(0.34, 3.98), Vector2(0, 4.45)])
	var col := func(p: Vector3, n: Vector3) -> Color:
		var rad := Vector2(p.x, p.z).length()
		if p.y < 0.67 and rad < 0.83: return Color(0.12, 0.12, 0.13)                  # fan and spinner
		if p.y < 0.6 and Vector2(n.x, n.z).dot(Vector2(p.x, p.z)) < 0.0: return Color(0.22, 0.22, 0.24)   # inside the intake
		if p.y < 0.1: return Color(0.78, 0.79, 0.8)                                    # the lip
		if p.y > 3.96: return Color(0.25, 0.24, 0.23)                                  # plug
		if p.y > 3.0: return Color(0.55, 0.56, 0.58)                                   # core cowl
		return Color(0.95, 0.95, 0.95)
	return NewModels._paint(DroneParts.lathe(prof, seg), col)

## The airliner for beyond about 2 km: the same outline in about 300 triangles, gear up.
static func _al_far() -> ArrayMesh:
	if _cache.has("airliner_far_mesh"): return _cache["airliner_far_mesh"]
	var kit := DroneParts.Kit.new()
	var pm := _mat("paint")
	var I := Transform3D.IDENTITY
	var fus := [AL_FUS[0], AL_FUS[3], AL_FUS[6], AL_FUS[9], AL_FUS[10], AL_FUS[12], AL_FUS[15], AL_FUS[17]]
	var fus_col := func(_p: Vector3, n: Vector3) -> Color: return Color(0.7, 0.72, 0.74) if n.y < -0.6 else Color(0.95, 0.95, 0.95)
	kit.add(pm, NewModels._paint(DroneParts.loft(fus, 2.0, 8), fus_col))
	var l4 := PackedVector2Array(NewModels.LOOP4); var s4 := PackedVector2Array(SYM4)
	var grey := Color(0.78, 0.79, 0.81); var fin := Color(0.06, 0.2, 0.46)
	for sx: float in [-1.0, 1.0]:
		kit.add(pm, NewModels._foil([[Vector3(sx * 0.6, _al_y(0.6), _al_le(0.6)), Vector3(0, 0, 7.2), Vector3(0, 0.9, 0)], [Vector3(sx * 6.3, _al_y(6.3), _al_le(6.3)), Vector3(0, 0, 4.6), Vector3(0, 0.45, 0)],
			[Vector3(sx * 16.5, _al_y(16.5), _al_le(16.5)), Vector3(0, 0, 1.45), Vector3(0, 0.14, 0)]], l4), I, grey)
		kit.add(pm, NewModels._foil([[Vector3(sx * 16.45, _al_y(16.5), 3.1), Vector3(0, 0, 1.4), Vector3(sx * 0.1, 0, 0)], [Vector3(sx * 16.95, _al_y(16.5) + 2.3, 4.75), Vector3(0, 0, 0.45), Vector3(sx * 0.05, 0, 0)]], s4), I, fin)
		kit.add(pm, NewModels._foil([[Vector3(sx * 0.3, 0.58, 13.4), Vector3(0, 0, 3.7), Vector3(0, 0.35, 0)], [Vector3(sx * 6.2, 1.2, 16.9), Vector3(0, 0, 1.35), Vector3(0, 0.12, 0)]], s4), I, grey)
		var eng := DroneParts.lathe(PackedVector2Array([Vector2(0.0, 0.5), Vector2(1.06, 0.3), Vector2(1.0, 2.9), Vector2(0.5, 3.9), Vector2(0, 4.4)]), 6)
		kit.add(pm, eng, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(sx * AL_ENG_X, -2.2, -4.85)), Color(0.9, 0.9, 0.91))
	kit.add(pm, NewModels._foil([[Vector3(0, 1.6, 10.2), Vector3(0, 0, 7.8), Vector3(0.6, 0, 0)], [Vector3(0, 2.7, 11.85), Vector3(0, 0, 5.9), Vector3(0.45, 0, 0)], [Vector3(0, 7.9, 16.6), Vector3(0, 0, 2.25), Vector3(0.2, 0, 0)]], s4), I, fin)
	var mesh := kit.commit()
	_cache["airliner_far_mesh"] = mesh
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

## A 9 m flagpole and a 1.8 x 0.9 m flag. Returns {"pole", "cloth", "cloth_origin", "cloth_size", "grid", "schemes"}; the pole's
## origin is its foot. The pole: a base plate with four bolts and a flash collar, a satin aluminium shaft tapering in three
## sections with sleeve joints, the truck (cap) with its pulley, a gilded ball finial, the halyard running down both sides of
## the pulley to a cleat on a plate at 1.2 m.
## The cloth is a grid of FL_NU x FL_NV quads (40 x 24, plus extra lines at the seams and hems so colour edges stay crisp) in
## its own x-y plane: origin at the top of the hoist (where it ties to the halyard), x out along the fly to 1.8, y down to
## -0.9 (with a slight pre-wave droop and ripple, at most 7 cm), normal about +Z, double-sided. UV.x runs 0 at the hoist to 1
## at the fly and UV.y 0 at the top to 1 at the bottom, so a wind shader can wave it more towards the fly. Along the hoist: a
## white canvas header with two brass grommets and the hoist rope; a darker hem round the other three edges; stitched seams
## between the colour panels. Place it at cloth_origin and turn the whole flag (pole and cloth) about +Y so +X points downwind.
## scheme (none is a real national flag, no text): 0 a horizontal tricolour (plum, gold, teal), 1 an orange cross centred on
## green, 2 a crimson border round a cream field, 3 a cream disc on maroon, 4 plain red.
const FL_W := 1.8
const FL_H := 0.9
const FL_NU := 40
const FL_NV := 24
const FL_HEAD := 0.06                    # the canvas header at the hoist
const FL_HEM := 0.022

## The design colour at cloth point (x along the fly, y down from the top), metres; header, hems and seams not included.
static func _fl_field(scheme: int, x: float, y: float) -> Color:
	match scheme:
		0:
			if y < FL_H / 3.0: return Color(0.42, 0.13, 0.36)
			if y < FL_H * 2.0 / 3.0: return Color(0.95, 0.74, 0.16)
			return Color(0.0, 0.44, 0.47)
		1:
			if absf(x - (FL_HEAD + FL_W) * 0.5) < 0.09 or absf(y - FL_H * 0.5) < 0.09: return Color(0.96, 0.52, 0.08)
			return Color(0.08, 0.34, 0.2)
		2:
			if x - FL_HEAD < 0.13 or x > FL_W - 0.13 or y < 0.13 or y > FL_H - 0.13: return Color(0.62, 0.08, 0.14)
			return Color(0.94, 0.9, 0.8)
		3:
			if Vector2(x - (FL_HEAD + FL_W) * 0.5, y - FL_H * 0.5).length() < 0.25: return Color(0.95, 0.9, 0.76)
			return Color(0.44, 0.08, 0.13)
	return Color(0.8, 0.08, 0.07)

## Where a scheme's colour panels meet (stitched seams): [x lines, y lines] in metres.
static func _fl_seams(scheme: int) -> Array:
	var span := FL_W - FL_HEAD
	match scheme:
		0: return [[], [FL_H / 3.0, FL_H * 2.0 / 3.0]]
		1: return [[FL_HEAD + span * 0.5 - 0.09, FL_HEAD + span * 0.5 + 0.09], [FL_H * 0.5 - 0.09, FL_H * 0.5 + 0.09]]
		2: return [[FL_HEAD + 0.13, FL_W - 0.13], [0.13, FL_H - 0.13]]
	return [[], []]

## The cloth's rest shape: a little droop towards the fly and a gentle ripple. (x, y down) -> position, and the normal.
static func _fl_rest(x: float, y: float) -> Array:
	var u := x / FL_W
	var droop := 0.05 * u * u * (0.6 + 0.4 * y / FL_H)
	var rz := 0.035 * sin(u * TAU * 1.15 + 0.3) * u
	var drz := 0.035 * (cos(u * TAU * 1.15 + 0.3) * TAU * 1.15 * u + sin(u * TAU * 1.15 + 0.3)) / FL_W
	return [Vector3(x, -y - droop, rz), Vector3(-drz, 0, 1).normalized()]

static func flag(scheme := 0) -> Dictionary:
	scheme = posmod(scheme, 5)
	var key := "flag_%d" % scheme
	if _cache.has(key): return _cache[key]
	var I := Transform3D.IDENTITY
	var pk := DroneParts.Kit.new()
	var sh := _mat("sheet"); var gm := _mat("gloss")
	var alu := Color(0.78, 0.79, 0.8); var gold := Color(0.85, 0.66, 0.22); var steel := Color(0.45, 0.46, 0.47)
	# ---- base plate, bolts, flash collar; the shaft in three tapering sections with sleeve joints
	pk.add(sh, NewModels._box(Vector3(0.42, 0.025, 0.42)), NewModels._xf(Vector3(0, 0.0125, 0)), steel)
	for bx: float in [-0.16, 0.16]:
		for bz: float in [-0.16, 0.16]:
			pk.add(sh, DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, 0.025), Vector2(0.022, 0.025), Vector2(0.022, 0.045), Vector2(0.01, 0.07), Vector2(0, 0.07)])), 6), NewModels._xf(Vector3(bx, 0, bz)), Color(0.3, 0.3, 0.31))
	pk.add(sh, DroneParts.lathe(PackedVector2Array([Vector2(0.115, 0.025), Vector2(0.11, 0.06), Vector2(0.075, 0.15), Vector2(0.07, 0.16)]), 16), I, alu)
	var shaft := DroneParts.crisp(PackedVector2Array([Vector2(0.0, 0.1), Vector2(0.07, 0.1), Vector2(0.066, 3.0), Vector2(0.073, 3.0), Vector2(0.073, 3.1), Vector2(0.058, 3.1),
		Vector2(0.053, 6.0), Vector2(0.06, 6.0), Vector2(0.06, 6.08), Vector2(0.046, 6.08), Vector2(0.036, 8.9), Vector2(0.0, 8.9)]))
	pk.add(gm, DroneParts.lathe(shaft, 14), I, alu)
	# ---- the truck with its pulley, the gilded ball on its neck
	pk.add(sh, DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, 8.88), Vector2(0.055, 8.88), Vector2(0.06, 8.92), Vector2(0.06, 8.99), Vector2(0.045, 9.01), Vector2(0, 9.01)])), 12), I, steel)
	var pulley := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.075, 8.955, 0))
	pk.add(sh, DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, -0.008), Vector2(0.024, -0.008), Vector2(0.018, 0.0), Vector2(0.024, 0.008), Vector2(0, 0.008)])), 10), pulley, Color(0.6, 0.6, 0.62))
	pk.add(sh, NewModels._box(Vector3(0.03, 0.05, 0.03)), NewModels._xf(Vector3(0.055, 8.955, 0)), steel)
	pk.add(gm, DroneParts.lathe(PackedVector2Array([Vector2(0, 9.01), Vector2(0.018, 9.01), Vector2(0.014, 9.04)]), 10), I, gold)
	pk.add(gm, DroneParts.sphere(0.075, 14), NewModels._xf(Vector3(0, 9.105, 0)), gold)
	# ---- cleat on its plate, and the halyard down both sides of the pulley, wrapped on the cleat
	var hb := Buf.new()
	var rope := Color(0.88, 0.87, 0.82)
	pk.add(sh, NewModels._box(Vector3(0.012, 0.26, 0.09)), NewModels._xf(Vector3(0.071, 1.2, 0)), steel)
	pk.add(sh, NewModels._box(Vector3(0.026, 0.17, 0.026)), NewModels._xf(Vector3(0.098, 1.2, 0)), Color(0.55, 0.56, 0.57))
	for cy: float in [1.16, 1.24]:
		pk.add(sh, NewModels._box(Vector3(0.024, 0.02, 0.02)), NewModels._xf(Vector3(0.084, cy, 0)), Color(0.55, 0.56, 0.57))
	for sx: float in [0.051, 0.099]:
		_bar(hb, Vector3(sx, 8.955, 0), Vector3(sx, 1.29, 0), 0.007, rope)
	for k in 3:
		_bar(hb, Vector3(0.104, 1.28 - k * 0.04, -0.016), Vector3(0.104, 1.24 - k * 0.04, 0.016), 0.008, rope)
		_bar(hb, Vector3(0.104, 1.28 - k * 0.04, 0.016), Vector3(0.104, 1.24 - k * 0.04, -0.016), 0.008, rope)
	pk.add(_mat("cloth"), hb.data())
	# ---- the cloth
	var lx: Array = []
	for i in FL_NU + 1: lx.append(FL_W * i / FL_NU)
	var ly: Array = []
	for j in FL_NV + 1: ly.append(FL_H * j / FL_NV)
	var seams := _fl_seams(scheme)
	lx.append_array([FL_HEAD, FL_W - FL_HEM])
	ly.append_array([FL_HEM, FL_H - FL_HEM])
	for s: float in seams[0]: lx.append_array([s - 0.005, s + 0.005])
	for s: float in seams[1]: ly.append_array([s - 0.005, s + 0.005])
	lx = _fl_lines(lx); ly = _fl_lines(ly)
	var col_at := func(x: float, y: float) -> Color:
		if x < FL_HEAD: return Color(0.93, 0.92, 0.88)                                         # canvas header
		var c := _fl_field(scheme, x, y)
		var hem := x > FL_W - FL_HEM or y < FL_HEM or y > FL_H - FL_HEM
		for s: float in seams[0]:
			if absf(x - s) < 0.005: return c.darkened(0.3)
		for s: float in seams[1]:
			if absf(y - s) < 0.005: return c.darkened(0.3)
		return c.darkened(0.14) if hem else c
	var v := PackedVector3Array(); var nr := PackedVector3Array(); var cs := PackedColorArray(); var uv := PackedVector2Array(); var idx := PackedInt32Array()
	var dc := Vector2((FL_HEAD + FL_W) * 0.5, FL_H * 0.5)
	for j in ly.size() - 1:
		for i in lx.size() - 1:
			var x0: float = lx[i]; var x1: float = lx[i + 1]; var y0: float = ly[j]; var y1: float = ly[j + 1]
			var n := 1
			if scheme == 3 and absf(Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5).distance_to(dc) - 0.25) < 0.033: n = 4      # the disc's edge, cut finer so it stays round
			for sj in n:
				for si in n:
					var ax := lerpf(x0, x1, float(si) / n); var bx := lerpf(x0, x1, float(si + 1) / n)
					var ay := lerpf(y0, y1, float(sj) / n); var by := lerpf(y0, y1, float(sj + 1) / n)
					var cc: Color = col_at.call((ax + bx) * 0.5, (ay + by) * 0.5)
					var base := v.size()
					for q: Vector2 in [Vector2(ax, ay), Vector2(bx, ay), Vector2(ax, by), Vector2(bx, by)]:
						var rest := _fl_rest(q.x, q.y)
						v.append(rest[0]); nr.append(rest[1]); uv.append(Vector2(q.x / FL_W, q.y / FL_H)); cs.append(cc)
					idx.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])      # clockwise seen from +Z (Godot's front face)
	# stitching along the header and the hems: short dark dashes, a line of them just inside each edge
	var stitch := func(a: Vector2, bb: Vector2, n: int) -> void:
		for k in n:
			var p0 := a.lerp(bb, (k + 0.15) / n); var p1 := a.lerp(bb, (k + 0.65) / n)
			var side := (bb - a).normalized().orthogonal() * 0.0016
			_fl_quad(v, nr, cs, uv, idx, [p0 - side, p1 - side, p0 + side, p1 + side], Color(0.2, 0.2, 0.2, 1.0), 0.0012)
	stitch.call(Vector2(FL_HEAD - 0.006, 0.01), Vector2(FL_HEAD - 0.006, FL_H - 0.01), 30)
	stitch.call(Vector2(FL_HEAD + 0.03, FL_HEM - 0.007), Vector2(FL_W - 0.03, FL_HEM - 0.007), 50)
	stitch.call(Vector2(FL_HEAD + 0.03, FL_H - FL_HEM + 0.007), Vector2(FL_W - 0.03, FL_H - FL_HEM + 0.007), 50)
	stitch.call(Vector2(FL_W - FL_HEM + 0.007, 0.03), Vector2(FL_W - FL_HEM + 0.007, FL_H - 0.03), 25)
	# two brass grommets in the header, front and back, and the hoist rope along the hoist edge with its snap hooks
	for gy: float in [0.045, FL_H - 0.045]:
		for k in 10:
			var a0 := TAU * k / 10.0; var a1 := TAU * (k + 1) / 10.0
			var o := Vector2(0.03, gy)
			_fl_quad(v, nr, cs, uv, idx, [o + Vector2(cos(a0), sin(a0)) * 0.008, o + Vector2(cos(a1), sin(a1)) * 0.008, o + Vector2(cos(a0), sin(a0)) * 0.016, o + Vector2(cos(a1), sin(a1)) * 0.016], Color(0.8, 0.62, 0.26), 0.002)
	var rope_r := 0.006
	for k in 6:
		var a2 := TAU * k / 6.0; var a3 := TAU * (k + 1) / 6.0
		var n0 := Vector3(cos(a2), 0, sin(a2)); var n1 := Vector3(cos(a3), 0, sin(a3))
		var top := Vector3(-rope_r, 0.07, 0); var bot := Vector3(-rope_r, -FL_H - 0.07, 0)
		var base2 := v.size()
		for q2: Array in [[top, n0], [top, n1], [bot, n0], [bot, n1]]:
			var qp: Vector3 = q2[0]; var qn: Vector3 = q2[1]
			v.append(qp + qn * rope_r); nr.append(qn); cs.append(Color(0.88, 0.87, 0.82)); uv.append(Vector2(0.0, clampf(-qp.y / FL_H, 0.0, 1.0)))
		_fl_tri(v, nr, idx, base2, base2 + 1, base2 + 2); _fl_tri(v, nr, idx, base2 + 1, base2 + 3, base2 + 2)
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v; arrays[Mesh.ARRAY_NORMAL] = nr; arrays[Mesh.ARRAY_COLOR] = cs; arrays[Mesh.ARRAY_TEX_UV] = uv; arrays[Mesh.ARRAY_INDEX] = idx
	var cloth := ArrayMesh.new()
	cloth.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	cloth.surface_set_material(0, _mat("cloth"))
	var out := {"pole": pk.commit(), "cloth": cloth, "cloth_origin": Vector3(0.075, 8.85, 0), "cloth_size": Vector2(FL_W, FL_H), "grid": Vector2i(FL_NU, FL_NV), "schemes": 5}
	_cache[key] = out
	return out

## Grid line positions: sorted, inside the cloth, without near-duplicates.
static func _fl_lines(a: Array) -> Array:
	a.sort()
	var out: Array = []
	for x: float in a:
		if out.is_empty() or x - float(out[-1]) > 0.002: out.append(x)
	return out

## A triangle of the indexed cloth, wound clockwise seen from the side its normals face (Godot's front face).
static func _fl_tri(v: PackedVector3Array, nr: PackedVector3Array, idx: PackedInt32Array, a: int, b: int, c: int) -> void:
	if (v[b] - v[a]).cross(v[c] - v[a]).dot(nr[a] + nr[b] + nr[c]) > 0.0: idx.append_array([a, c, b])
	else: idx.append_array([a, b, c])

## A small flat patch on both faces of the cloth (stitches, grommets): corners [top-left, top-right, bottom-left,
## bottom-right] in cloth (x, y down), lifted `off` off each face so it follows the cloth (and its UV) when it waves.
static func _fl_quad(v: PackedVector3Array, nr: PackedVector3Array, cs: PackedColorArray, uv: PackedVector2Array, idx: PackedInt32Array, q: Array, col: Color, off: float) -> void:
	for side: float in [1.0, -1.0]:
		var base := v.size()
		for p: Vector2 in q:
			var rest := _fl_rest(p.x, p.y)
			var n: Vector3 = rest[1]
			v.append((rest[0] as Vector3) + n * off * side); nr.append(n * side); cs.append(col); uv.append(Vector2(p.x / FL_W, p.y / FL_H))
		_fl_tri(v, nr, idx, base, base + 1, base + 2); _fl_tri(v, nr, idx, base + 1, base + 3, base + 2)

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

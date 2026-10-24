class_name NewModels3
extends RefCounted
## The third batch of models drawn by code (batch "models5"): rural farm pieces for the fields and roadsides. Fences (post and
## rail, board, rustic, wire, woven wire, a field gate, a corner and a broken section), hay (round bales wrapped and bare, a
## round roll, square bales, a stack), crops as clumps and a row chunk (corn, barley, alfalfa, field-margin weeds) and the
## ground of a field (two tilled strips, a headland turn row, a muddy two-rut track).
## Real metres. Forward is -z, up is +y, x is right. The origin is the ground. Every model is one mesh with a surface per
## material, kept once made. Colour variation is vertex colour. The contract is game/README-models.md.
## One entry point: `NewModels3.mesh(name, lod)` with lod 0 near (under about 25 m), 1 middle (to about 80 m), 2 far.
## `NewModels3.colliders(name)` gives box strips (AABB in the model's own frame) for what a drone can hit.

const NAMES: Array[String] = [
	"fence_post_rail_a", "fence_post_rail_b", "fence_post_rail_c", "fence_wire_a", "fence_wire_b", "fence_gate_a",
	"fence_corner_a", "fence_broken_a",
	"hay_round_a", "hay_round_b", "hay_roll_a", "hay_square_a", "hay_square_b", "hay_stack_a",
	"corn_stand_a", "corn_stand_b", "corn_row_chunk", "barley_patch_a", "barley_patch_b", "alfalfa_patch_a", "alfalfa_patch_b",
	"crop_edge_weeds",
	"field_furrow_a", "field_furrow_b", "field_headland_a", "field_track_a",
]

## The repeat size (x, z) of what is laid side by side: fence sections run +x from the post; the row chunk and the ground
## tiles tile exactly (heights, colours and the row phase all repeat at these sizes).
const TILE := {
	"fence_post_rail_a": Vector2(3.0, 0.0), "fence_post_rail_b": Vector2(3.0, 0.0), "fence_post_rail_c": Vector2(3.0, 0.0),
	"fence_wire_a": Vector2(3.0, 0.0), "fence_wire_b": Vector2(3.0, 0.0), "fence_gate_a": Vector2(3.0, 0.0),
	"corn_row_chunk": Vector2(0.0, 4.0),
	"field_furrow_a": Vector2(3.04, 4.0), "field_furrow_b": Vector2(3.15, 4.2), "field_headland_a": Vector2(6.0, 3.0),
	"field_track_a": Vector2(2.6, 8.0),
}

static var _cache := {}
static var _mats := {}

# ================================================================== materials
## Shared materials, textured through game/shaders/farm_props.gdshader (fences, hay, ground) and farm_plant.gdshader (crops).
## The vertex colour is the finish; see the shaders for what each kind does with it.
static func _mat(key: String) -> ShaderMaterial:
	if _mats.has(key): return _mats[key]
	var m := ShaderMaterial.new()
	if key == "leaf" or key == "plant":
		m.shader = load("res://game/shaders/farm_plant.gdshader") as Shader
		m.set_shader_parameter("kind", 0 if key == "leaf" else 1)
	else:
		m.shader = load("res://game/shaders/farm_props.gdshader") as Shader
		# set name, kind, metres per repeat, normal strength, tint gain, mean luminance of the set, how much of its own colour
		var spec: Array = ["", 1, 1.0, 0.0, 1.0, 0.25, 0.0]
		match key:
			"wood": spec = ["postwood", 0, 1.0, 1.0, 1.0, 0.1325, 0.5]
			"steel": spec = ["", 1, 1.0, 0.0, 1.0, 0.25, 0.0]
			"hay": spec = ["straw", 2, 0.5, 0.9, 1.0, 0.1205, 0.0]
			"plastic": spec = ["", 3, 1.0, 0.5, 1.0, 0.25, 0.0]
			"soil": spec = ["plough", 4, 2.0, 1.3, 1.0, 0.0621, 0.0]
			"mud": spec = ["mudtrack", 5, 2.5, 1.0, 1.0, 0.0434, 0.0]
		if spec[0] != "":
			m.set_shader_parameter("set_albedo", load("res://assets/textures/%s_diff.jpg" % spec[0]))
			m.set_shader_parameter("set_normal", load("res://assets/textures/%s_nor.jpg" % spec[0]))
			m.set_shader_parameter("set_arm", load("res://assets/textures/%s_arm.jpg" % spec[0]))
		m.set_shader_parameter("kind", spec[1])
		m.set_shader_parameter("metres", spec[2])
		m.set_shader_parameter("normal_amt", spec[3])
		m.set_shader_parameter("tint_gain", spec[4])
		m.set_shader_parameter("lum_avg", spec[5])
		m.set_shader_parameter("nat", spec[6])
	_mats[key] = m
	return m

## The parts of one model by material.
class Parts:
	var m := {}
	func b(key: String) -> NewModels2.Buf:
		if not m.has(key): m[key] = NewModels2.Buf.new()
		return m[key]

# ================================================================== entry points
static func mesh(name: String, lod := 0) -> ArrayMesh:
	lod = clampi(lod, 0, 2)
	var k := "%s/%d" % [name, lod]
	if _cache.has(k): return _cache[k]
	var p := Parts.new()
	match name:
		"fence_post_rail_a", "fence_post_rail_b", "fence_post_rail_c": _fence_pr(p, name.right(1), lod)
		"fence_wire_a": _fence_wire_a(p, lod)
		"fence_wire_b": _fence_wire_b(p, lod)
		"fence_gate_a": _fence_gate(p, lod)
		"fence_corner_a": _fence_corner(p, lod)
		"fence_broken_a": _fence_broken(p, lod)
		"hay_round_a": _bale_round(p, 0.6, 1.2, 0, lod)
		"hay_round_b": _bale_round(p, 0.6, 1.2, 1, lod)
		"hay_roll_a": _bale_round(p, 0.75, 1.2, 2, lod)
		"hay_square_a": _bale_sq(p, Vector3(0, 0, 0), 0.0, 0, [4, 2, 2][lod] if lod < 2 else 1, lod < 2, true)
		"hay_square_b": _bale_sq(p, Vector3(0, 0, 0), 0.0, 1, [4, 2, 2][lod] if lod < 2 else 1, lod < 2, true)
		"hay_stack_a": _hay_stack(p, lod)
		"corn_stand_a": _corn_stand(p, 0, lod)
		"corn_stand_b": _corn_stand(p, 1, lod)
		"corn_row_chunk": _corn_row(p, lod)
		"barley_patch_a": _barley(p, 0, lod)
		"barley_patch_b": _barley(p, 1, lod)
		"alfalfa_patch_a": _alfalfa(p, 0, lod)
		"alfalfa_patch_b": _alfalfa(p, 1, lod)
		"crop_edge_weeds": _weeds(p, lod)
		"field_furrow_a": _furrow_a(p, lod)
		"field_furrow_b": _furrow_b(p, lod)
		"field_headland_a": _headland(p, lod)
		"field_track_a": _track(p, lod)
		_:
			push_error("NewModels3: no model called " + name)
			return ArrayMesh.new()
	var kit := DroneParts.Kit.new()
	for key in p.m: kit.add(_mat(key), (p.m[key] as NewModels2.Buf).data())
	var out := kit.commit()
	_cache[k] = out
	return out

## Box strips a drone can hit, in the model's frame (empty for crops, weeds and the field ground).
static func colliders(name: String) -> Array:
	match name:
		"fence_post_rail_a", "fence_post_rail_c": return [AABB(Vector3(-0.07, 0.0, -0.1), Vector3(3.14, 1.25, 0.2))]
		"fence_post_rail_b": return [AABB(Vector3(-0.07, 0.0, -0.07), Vector3(3.14, 1.3, 0.17))]
		"fence_wire_a": return [AABB(Vector3(-0.05, 0.0, -0.05), Vector3(3.1, 1.25, 0.1))]
		"fence_wire_b": return [AABB(Vector3(-0.05, 0.0, -0.06), Vector3(3.1, 1.3, 0.12))]
		"fence_gate_a": return [AABB(Vector3(-0.1, 0.0, -0.1), Vector3(0.2, 1.5, 0.2)), AABB(Vector3(0.12, 0.2, -0.04), Vector3(2.76, 0.97, 0.08)),
			AABB(Vector3(2.9, 0.0, -0.1), Vector3(0.2, 1.5, 0.2))]
		"fence_corner_a": return [AABB(Vector3(-0.1, 0.0, -0.1), Vector3(3.2, 1.35, 0.2)), AABB(Vector3(-0.1, 0.0, -3.1), Vector3(0.2, 1.35, 3.1))]
		"fence_broken_a": return [AABB(Vector3(-0.1, 0.0, -0.1), Vector3(3.2, 0.5, 0.2)), AABB(Vector3(-0.1, 0.0, 0.0), Vector3(0.2, 1.2, 0.6))]
		"hay_round_a", "hay_round_b": return [AABB(Vector3(-0.6, 0.0, -0.6), Vector3(1.2, 1.15, 1.2))]
		"hay_roll_a": return [AABB(Vector3(-0.6, 0.0, -0.75), Vector3(1.2, 1.4, 1.5))]
		"hay_square_a", "hay_square_b": return [AABB(Vector3(-0.45, 0.0, -0.225), Vector3(0.9, 0.35, 0.45))]
		"hay_stack_a": return [AABB(Vector3(-0.9, 0.0, -0.9), Vector3(1.8, 0.7, 1.8)), AABB(Vector3(-0.9, 0.7, -0.9), Vector3(1.8, 0.35, 1.8)),
			AABB(Vector3(-0.45, 1.05, -0.45), Vector3(0.9, 0.35, 0.9))]
	return []

# ================================================================== helpers
static func _rnd(i: float, salt := 0.0) -> float:
	return fposmod(sin(i * 12.9898 + salt * 78.233) * 43758.5453, 1.0)

static func _vc(c: Color, k: float, amt := 0.08) -> Color:
	var o := NewModels._vary(c, Vector3(k * 1.7, k * 0.31, 5.1), amt)
	o.a = c.a
	return o

## The alpha that tells farm_props.gdshader which way the grain runs: 1 up, 0.75 along x, 0.5 along z, 0.25 none.
const G_Y := 1.0
const G_X := 0.75
const G_Z := 0.5
const G_NONE := 0.25
static func _g(c: Color, code: float) -> Color:
	return Color(c.r, c.g, c.b, code)

## The grain code for a direction: along its biggest component.
static func _grain(d: Vector3) -> float:
	var a := d.abs()
	if a.y >= a.x and a.y >= a.z: return G_Y
	return G_X if a.x >= a.z else G_Z

## An oriented box centred on c (basis bas), per-face flat colour; col_top paints the +y face if given.
static func _boxb(b: NewModels2.Buf, c: Vector3, bas: Basis, s: Vector3, col: Color, col_top := Color(-1, 0, 0)) -> void:
	var h := s * 0.5
	var p: Array[Vector3] = []
	for k in 8:
		p.append(c + bas * Vector3(h.x * (1.0 if k & 1 else -1.0), h.y * (1.0 if k & 2 else -1.0), h.z * (1.0 if k & 4 else -1.0)))
	var bx := bas.x.normalized(); var by := bas.y.normalized(); var bz := bas.z.normalized()
	var longest := bx if (s.x >= s.y and s.x >= s.z) else (by if s.y >= s.z else bz)
	var gc := _grain(longest)
	col = _g(col, gc)
	var top := _g(col if col_top.r < 0.0 else col_top, gc)
	b.quad(p[0], p[4], p[6], p[2], col, -bx); b.quad(p[1], p[3], p[7], p[5], col, bx)
	b.quad(p[0], p[1], p[5], p[4], col, -by); b.quad(p[2], p[6], p[7], p[3], top, by)
	b.quad(p[0], p[2], p[3], p[1], col, -bz); b.quad(p[4], p[5], p[7], p[6], col, bz)

static func _boxy(b: NewModels2.Buf, c: Vector3, s: Vector3, yaw: float, col: Color, col_top := Color(-1, 0, 0)) -> void:
	_boxb(b, c, Basis(Vector3.UP, yaw), s, col, col_top)

## A tapered n-sided prism from a (radius r0) to c (radius r1). caps: 1 bottom, 2 top, 3 both.
static func _prism(b: NewModels2.Buf, a: Vector3, c: Vector3, r0: float, r1: float, seg: int, col: Color, caps := 3, vary := 0.07, salt := 0.0) -> void:
	var z := c - a
	var L := z.length()
	if L < 1e-5: return
	z /= L
	var h := Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT
	var x := h.cross(z).normalized()
	var y := z.cross(x)
	var gc := _grain(z)
	col = _g(col, gc)
	var ra: Array[Vector3] = []; var rc: Array[Vector3] = []
	for k in seg:
		var d := x * cos(TAU * k / seg) + y * sin(TAU * k / seg)
		ra.append(a + d * r0); rc.append(c + d * r1)
	for k in seg:
		var k2 := (k + 1) % seg
		var am := TAU * (k + 0.5) / seg
		var cc := _g(_vc(col, k * 1.9 + salt + a.x * 3.1 + a.z * 2.3 + c.y, vary), gc) if vary > 0.0 else col
		b.quad(ra[k], ra[k2], rc[k2], rc[k], cc, x * cos(am) + y * sin(am))
	if caps & 1: NewModels2._fan(b, ra, -z, col)
	if caps & 2: NewModels2._fan(b, rc, z, col)

## A ribbon through pts with widths ws spread along `across`, the colour running from c0 to c1. The vertex alpha is the way
## across it (0, 0.5 at the midrib, 1) for the leaf shader. fold folds the ribbon along its midrib (a leaf's curl). Double-sided.
static func _strip(b: NewModels2.Buf, pts: Array, ws: Array, across: Vector3, c0: Color, c1: Color, fold := 0.0) -> void:
	var n := pts.size()
	for i in n - 1:
		var t0 := float(i) / (n - 1); var t1 := float(i + 1) / (n - 1)
		var ca := c0.lerp(c1, t0); var cb := c0.lerp(c1, t1)
		var p0: Vector3 = pts[i]; var p1: Vector3 = pts[i + 1]
		var nrm := (p1 - p0).cross(across).normalized()
		if nrm.length_squared() < 0.5: continue
		var up := nrm if nrm.y >= 0.0 else -nrm
		var w0 := float(ws[i]) * 0.5; var w1 := float(ws[i + 1]) * 0.5
		var l0 := p0 - across * w0; var r0 := p0 + across * w0; var m0 := p0 + up * (fold * w0 * 2.0)
		var l1 := p1 - across * w1; var r1 := p1 + across * w1; var m1 := p1 + up * (fold * w1 * 2.0)
		var al0 := 0.0 if w0 > 1e-6 else 0.5; var ar0 := 1.0 if w0 > 1e-6 else 0.5
		var al1 := 0.0 if w1 > 1e-6 else 0.5; var ar1 := 1.0 if w1 > 1e-6 else 0.5
		var cl0 := Color(ca.r, ca.g, ca.b, al0); var cr0 := Color(ca.r, ca.g, ca.b, ar0); var cm0 := Color(ca.r, ca.g, ca.b, 0.5)
		var cl1 := Color(cb.r, cb.g, cb.b, al1); var cr1 := Color(cb.r, cb.g, cb.b, ar1); var cm1 := Color(cb.r, cb.g, cb.b, 0.5)
		if fold > 0.0:
			_t(b, l0, m0, m1, cl0, cm0, cm1); _t(b, l0, m1, l1, cl0, cm1, cl1)
			_t(b, m0, r0, r1, cm0, cr0, cr1); _t(b, m0, r1, m1, cm0, cr1, cm1)
		else:
			_t(b, l0, r0, r1, cl0, cr0, cr1); _t(b, l0, r1, l1, cl0, cr1, cl1)

## One double-sided triangle with a vertex colour at each corner (the normal is the face's own).
static func _t(b: NewModels2.Buf, a: Vector3, bb: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var n := (bb - a).cross(c - a).normalized()
	if n.length_squared() < 0.5: return
	DroneParts._tri(b.pos, b.nrm, b.cols, a, bb, c, n, n, n, ca, cb, cc)

static func _curve2(base: Vector3, d0: Vector3, acc: Vector3, ln: float, segs: int) -> Array:
	var out: Array = []
	for k in segs + 1:
		var t := float(k) / segs
		out.append(base + d0 * (ln * t) + acc * (ln * t * t))
	return out

## A grass-like blade: starts in direction d0 and bends by acc (both unit-ish), ln long, w wide, tapering to a point.
static func _blade(b: NewModels2.Buf, base: Vector3, d0: Vector3, acc: Vector3, ln: float, w: float, segs: int, c0: Color, c1: Color, tp := 2.0, fold := 0.0) -> Array:
	var pts := _curve2(base, d0, acc, ln, segs)
	var ws: Array = []
	for k in segs + 1: ws.append(w * (1.0 - pow(float(k) / segs, tp)))
	var ac := d0.cross(acc)
	if ac.length_squared() < 1e-6: ac = Vector3.RIGHT.cross(d0)
	_strip(b, pts, ws, ac.normalized(), c0, c1, fold)
	return pts

## A small octahedron (8 triangles): flower and seed heads.
static func _blob(b: NewModels2.Buf, c: Vector3, r: float, col: Color) -> void:
	var v := [Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, r, 0), Vector3(0, -r * 0.7, 0), Vector3(0, 0, r), Vector3(0, 0, -r)]
	var faces := [[0, 2, 4], [2, 1, 4], [1, 3, 4], [3, 0, 4], [2, 0, 5], [1, 2, 5], [3, 1, 5], [0, 3, 5]]
	for f in faces:
		var a: Vector3 = c + v[f[0]]; var bb: Vector3 = c + v[f[1]]; var cc: Vector3 = c + v[f[2]]
		var n := (a + bb + cc) / 3.0 - c
		b.tri(a, bb, cc, col, n.normalized())

## A flat fan (a double-sided card) from points (x along tangent, y up) with a colour from col_lo at the bottom to col_hi at the top.
static func _card(b: NewModels2.Buf, base: Vector3, tangent: Vector3, pts: PackedVector2Array, ymax: float, col_lo: Color, col_hi: Color) -> void:
	var nrm := tangent.cross(Vector3.UP).normalized()
	var cen := Vector2.ZERO
	for q in pts: cen += q
	cen /= pts.size()
	var w := func(q: Vector2) -> Vector3: return base + tangent * q.x + Vector3(0, q.y, 0)
	var cc := _g(col_lo.lerp(col_hi, clampf(cen.y / ymax, 0.0, 1.0)), 0.3)
	for k in pts.size():
		var q0: Vector2 = pts[k]; var q1: Vector2 = pts[(k + 1) % pts.size()]
		DroneParts._tri(b.pos, b.nrm, b.cols, w.call(cen), w.call(q0), w.call(q1), nrm, nrm, nrm, cc,
			_g(col_lo.lerp(col_hi, clampf(q0.y / ymax, 0.0, 1.0)), 0.3), _g(col_lo.lerp(col_hi, clampf(q1.y / ymax, 0.0, 1.0)), 0.3))

## n cards through the clump's middle, turned evenly: the far version of a crop clump.
static func _cards_x(b: NewModels2.Buf, base: Vector3, width: float, ht: float, n: int, col_lo: Color, col_hi: Color, belly := 0.55) -> void:
	var pts := PackedVector2Array([Vector2(-width * 0.25, 0.0), Vector2(width * 0.25, 0.0), Vector2(width * 0.5, ht * belly),
		Vector2(width * 0.2, ht), Vector2(-width * 0.2, ht), Vector2(-width * 0.5, ht * belly)])
	for k in n:
		var a := PI * k / n
		_card(b, base, Vector3(cos(a), 0.0, sin(a)), pts, ht, col_lo, col_hi)

## A solid with the cross-section poly (x, y) run along z from z0 to z1, the colour running with height (a hedge-like far row).
static func _loaf(b: NewModels2.Buf, poly: PackedVector2Array, z0: float, z1: float, col_lo: Color, col_hi: Color, ymax: float) -> void:
	var m := poly.size()
	for k in m:
		var q0 := poly[k]; var q1 := poly[(k + 1) % m]
		var e := q1 - q0
		var n := Vector3(e.y, -e.x, 0.0).normalized()
		if n.dot(Vector3(q0.x, q0.y - ymax * 0.4, 0.0)) < 0.0: n = -n
		var a := Vector3(q0.x, q0.y, z0); var bb := Vector3(q1.x, q1.y, z0); var c := Vector3(q1.x, q1.y, z1); var d := Vector3(q0.x, q0.y, z1)
		var ca := _g(col_lo.lerp(col_hi, clampf(q0.y / ymax, 0.0, 1.0)), 0.3); var cb := _g(col_lo.lerp(col_hi, clampf(q1.y / ymax, 0.0, 1.0)), 0.3)
		DroneParts._tri(b.pos, b.nrm, b.cols, a, bb, c, n, n, n, ca, cb, cb)
		DroneParts._tri(b.pos, b.nrm, b.cols, a, c, d, n, n, n, ca, cb, ca)

# ================================================================== fences
const GREY := Color(0.50, 0.45, 0.37)
const BROWN := Color(0.37, 0.28, 0.19)
const SILVER := Color(0.62, 0.64, 0.64)

## Post and rail: a end post round with three round rails, b square posts with horizontal boards, c a rustic one with
## two poles crossing the post (the post is at x = 0, the rails run to x = 3 where the next section's post stands).
static func _fence_pr(p: Parts, v: String, lod: int) -> void:
	var w := p.b("wood")
	var seg: int = [12, 6, 4][lod]
	match v:
		"a":
			_prism(w, Vector3(0, -0.05, 0), Vector3(0, 1.25, 0), 0.07, 0.06, seg, GREY, 2, 0.1)
			if lod == 0:      # a weathered, chamfered top and the split that runs down from it
				_prism(w, Vector3(0, 1.25, 0), Vector3(0.004, 1.31, 0.003), 0.06, 0.02, seg, GREY.lightened(0.12), 2, 0.1, 3.0)
				_boxy(w, Vector3(0.03, 1.1, 0.062), Vector3(0.012, 0.3, 0.014), 0.3, Color(0.12, 0.10, 0.08))
			if lod < 2:
				for i in 3:
					var y := 0.38 + 0.37 * i + (_rnd(i, 3.0) - 0.5) * 0.02
					_prism(w, Vector3(0.0, y, 0.0), Vector3(3.0, y + (_rnd(i, 5.0) - 0.5) * 0.02, 0.0), 0.038, 0.034, [6, 4][lod], _vc(GREY, i + 2.0, 0.12), 3, 0.08, i)
			else:
				_boxy(w, Vector3(1.5, 1.12, 0.0), Vector3(3.0, 0.08, 0.07), 0.0, GREY)
				_boxy(w, Vector3(1.5, 0.5, 0.0), Vector3(3.0, 0.08, 0.07), 0.0, GREY)
		"b":
			var post := Vector3(0.12, 1.3, 0.12)
			_boxy(w, Vector3(0, 0.65 - 0.05, 0), post - Vector3(0, 0.1, 0), 0.0, BROWN, BROWN.lightened(0.1))
			if lod == 0:      # a bevelled cap, nail heads and a hairline split in the post
				_boxy(w, Vector3(0, 1.32, 0), Vector3(0.16, 0.03, 0.16), 0.0, BROWN.lightened(0.12))
				_boxy(w, Vector3(0, 1.345, 0), Vector3(0.11, 0.02, 0.11), 0.0, BROWN.lightened(0.18))
				for yy in [0.22, 0.50, 0.78, 1.06]:
					_boxy(w, Vector3(0.0, yy, 0.092), Vector3(0.02, 0.02, 0.01), 0.0, Color(0.18, 0.17, 0.17))
				_boxy(w, Vector3(0.02, 1.0, 0.062), Vector3(0.008, 0.35, 0.012), 0.0, Color(0.09, 0.075, 0.06))
			var ys := [0.22, 0.50, 0.78, 1.06] if lod < 2 else [0.5, 1.06]
			for i in ys.size():
				_boxy(w, Vector3(1.5 + 0.06, ys[i], 0.075), Vector3(3.0 - 0.06, 0.14, 0.03), 0.0, _vc(BROWN, i * 1.3, 0.14), _vc(BROWN, i * 0.7, 0.2).lightened(0.05))
				if lod == 0:      # the checked end of the board
					_boxy(w, Vector3(3.0 - 0.02, ys[i] - 0.03, 0.062), Vector3(0.04, 0.03, 0.012), 0.0, BROWN.darkened(0.3))
		"c":
			var lean := (_rnd(1.0, 7.0) - 0.5) * 0.06
			_prism(w, Vector3(0, -0.05, 0), Vector3(lean, 1.15, 0.0), 0.05, 0.04, seg, Color(0.55, 0.50, 0.43), 2, 0.14)
			if lod < 2:
				for i in 2:
					var y := 0.5 + 0.4 * i
					var zz := 0.055 * (1.0 if i == 0 else -1.0)
					var sag := -0.03 - 0.01 * i
					var a0 := Vector3(0.0, y, zz); var m := Vector3(1.5, y + sag, zz * 1.4); var a1 := Vector3(3.0, y + 0.01, zz)
					_prism(w, a0, m, 0.032, 0.028, [6, 4][lod], _vc(Color(0.56, 0.5, 0.42), i + 9.0, 0.15), 1, 0.1, i)
					_prism(w, m, a1, 0.028, 0.034, [6, 4][lod], _vc(Color(0.56, 0.5, 0.42), i + 19.0, 0.15), 2, 0.1, i + 4)
			else:
				_boxy(w, Vector3(1.5, 0.68, 0.0), Vector3(3.0, 0.08, 0.06), 0.0, Color(0.56, 0.5, 0.42))

static func _wire(s: Parts, a: Vector3, c: Vector3, sag: float, lod: int, wd := 0.016) -> void:
	var st := s.b("steel")
	var n: int = [3, 2, 1][lod]
	var prev := a
	for k in n:
		var t: float = float(k + 1) / n
		var pt := a.lerp(c, t) + Vector3(0, -sag * sin(PI * t), 0)
		NewModels2._bar(st, prev, pt, wd, SILVER)
		prev = pt

static func _tpost(s: Parts, x: float, z: float, ht: float) -> void:
	var st := s.b("steel")
	var col := Color(0.30, 0.36, 0.30)
	_boxy(st, Vector3(x, ht * 0.5 - 0.1, z), Vector3(0.012, ht, 0.05), 0.0, col)
	_boxy(st, Vector3(x, ht * 0.5 - 0.1, z - 0.019), Vector3(0.05, ht, 0.012), 0.0, col)

## Wire and post: a wood post at the end, a steel T-post in the middle and four strands of wire.
static func _fence_wire_a(p: Parts, lod: int) -> void:
	_prism(p.b("wood"), Vector3(0, -0.05, 0), Vector3(0, 1.25, 0), 0.055, 0.05, [7, 5, 4][lod], Color(0.46, 0.38, 0.28), 2, 0.1)
	if lod < 2: _tpost(p, 1.5, 0.0, 1.2)
	var ys := [0.32, 0.58, 0.84, 1.10] if lod < 2 else [0.45, 1.05]
	for i in ys.size():
		_wire(p, Vector3(0.0, ys[i], 0.06), Vector3(3.0, ys[i], 0.06), 0.02 + 0.006 * i, lod, 0.017 if lod < 2 else 0.04)
		if lod == 0 and i == ys.size() - 1:      # barbs on the top strand
			for k in 11:
				var bx := 0.18 + 0.25 * k
				var by: float = ys[i] - 0.02 * sin(PI * bx / 3.0)
				NewModels2._bar(p.b("steel"), Vector3(bx - 0.02, by - 0.025, 0.06), Vector3(bx + 0.02, by + 0.025, 0.06), 0.008, SILVER)

## Woven wire: posts at both 0 and 1.5, a woven panel to 0.8 m (closer lines low, wider high) with a strand of barbed wire on top.
static func _fence_wire_b(p: Parts, lod: int) -> void:
	var wd := p.b("wood")
	for x in [0.0, 1.5]:
		_prism(wd, Vector3(x, -0.05, 0), Vector3(x, 1.3, 0), 0.06, 0.05, [7, 5, 4][lod], Color(0.48, 0.40, 0.30), 2, 0.1, x)
	var hs := [0.1, 0.2, 0.32, 0.46, 0.62, 0.80] if lod == 0 else ([0.1, 0.32, 0.62, 0.8] if lod == 1 else [0.2, 0.62])
	for y in hs: _wire(p, Vector3(0.0, y, 0.06), Vector3(3.0, y, 0.06), 0.012, mini(lod, 1), 0.012 if lod < 2 else 0.04)
	if lod < 2:
		var step := 0.15 if lod == 0 else 0.3
		var n := int(round(3.0 / step))
		for i in range(1, n):
			var x := step * i
			if absf(x - 1.5) < 0.02: continue
			NewModels2._bar(p.b("steel"), Vector3(x, 0.1, 0.06), Vector3(x, 0.8, 0.06), 0.01, SILVER)
	for y in [0.98, 1.12]: _wire(p, Vector3(0.0, y, 0.06), Vector3(3.0, y, 0.06), 0.02, lod, 0.016 if lod < 2 else 0.04)

## A 3 m galvanised pipe field gate between two wood posts: five horizontal bars, three uprights, a diagonal brace, hinges.
## Hinge post at x = 0, latch post at x = 3, the gate hangs between them (closed).
static func _fence_gate(p: Parts, lod: int) -> void:
	var wd := p.b("wood"); var st := p.b("steel")
	var seg: int = [8, 5, 4][lod]
	for x in [0.0, 3.0]:
		_prism(wd, Vector3(x, -0.05, 0), Vector3(x, 1.5, 0), 0.1, 0.09, seg, Color(0.45, 0.36, 0.26), 2, 0.1, x)
	var gal := Color(0.66, 0.69, 0.70)
	var x0 := 0.14; var x1 := 2.86
	var ys := [0.25, 0.46, 0.67, 0.92, 1.17] if lod < 2 else [0.25, 0.71, 1.17]
	for y in ys:
		_prism(st, Vector3(x0, y, 0), Vector3(x1, y, 0), 0.02, 0.02, [6, 4, 3][lod], gal, 3, 0.04, y)
	for x in [x0, 1.5, x1]:
		_prism(st, Vector3(x, 0.25, 0), Vector3(x, 1.17, 0), 0.02, 0.02, [6, 4, 3][lod], gal, 3, 0.04, x)
	_prism(st, Vector3(x0, 0.25, 0), Vector3(x1, 1.17, 0), 0.015, 0.015, [5, 4, 3][lod], gal.darkened(0.08), 3, 0.04)
	if lod < 2:
		for y in [0.4, 1.05]:
			_boxy(st, Vector3(0.1, y, 0.0), Vector3(0.1, 0.05, 0.05), 0.0, Color(0.2, 0.2, 0.2))
		_boxy(st, Vector3(2.92, 0.75, 0.0), Vector3(0.1, 0.08, 0.06), 0.0, Color(0.25, 0.22, 0.2))

## A corner post-and-rail: a thick corner post, sections run +x and -z, a strut and a diagonal brace to a brace post on each leg.
static func _fence_corner(p: Parts, lod: int) -> void:
	var w := p.b("wood")
	var seg: int = [8, 5, 4][lod]
	_prism(w, Vector3(0, -0.05, 0), Vector3(0, 1.35, 0), 0.1, 0.09, seg, Color(0.44, 0.38, 0.31), 2, 0.1)
	for leg in 2:
		var dir := Vector3(1, 0, 0) if leg == 0 else Vector3(0, 0, -1)
		var bp := dir * 1.4
		_prism(w, bp + Vector3(0, -0.05, 0), bp + Vector3(0, 1.2, 0), 0.06, 0.055, seg, GREY, 2, 0.1, leg)
		_prism(w, dir * 3.0 + Vector3(0, -0.05, 0), dir * 3.0 + Vector3(0, 1.25, 0), 0.07, 0.06, seg, GREY, 2, 0.1, leg + 3.0)
		if lod < 2:
			for i in 3:
				var y := 0.38 + 0.37 * i
				_prism(w, Vector3(0, y, 0) + dir * 0.0, Vector3(0, y, 0) + dir * 3.0, 0.036, 0.034, [6, 4][lod], _vc(GREY, i + leg * 3.0, 0.12), 3, 0.08, i + leg * 7.0)
			_prism(w, Vector3(0, 0.95, 0) + dir * 0.0, Vector3(0, 0.95, 0) + dir * 1.4, 0.03, 0.03, [6, 4][lod], GREY.darkened(0.12), 3, 0.08)
			_prism(w, dir * 1.4 + Vector3(0, 0.12, 0), Vector3(0, 0.95, 0), 0.02, 0.02, 4, Color(0.62, 0.63, 0.62), 3, 0.05)
		else:
			_prism(w, Vector3(0, 0.5, 0), Vector3(0, 0.5, 0) + dir * 3.0, 0.05, 0.05, 4, GREY, 3, 0.1)
			_prism(w, Vector3(0, 1.1, 0), Vector3(0, 1.1, 0) + dir * 3.0, 0.05, 0.05, 4, GREY, 3, 0.1, 2.0)

## A broken post-and-rail section: the end post leans over, the top rail is snapped (a stub on the post and the rest lying in
## the grass), the middle rail has dropped to the ground at one end, and the bottom rail is still up.
static func _fence_broken(p: Parts, lod: int) -> void:
	var w := p.b("wood")
	var seg: int = [8, 5, 4][lod]
	var top := Vector3(0.0, 1.2, 0.0).rotated(Vector3(1, 0, 0), -0.28)
	_prism(w, Vector3(0, -0.05, 0), top, 0.07, 0.06, seg, GREY.darkened(0.06), 2, 0.1)
	_prism(w, Vector3(0.0, 0.38, 0.0), Vector3(3.0, 0.4, 0.0), 0.038, 0.034, [6, 4, 3][lod], GREY, 3, 0.08, 1.0)
	_prism(w, Vector3(0.0, 0.7, -0.05), Vector3(2.4, 0.07, 0.3), 0.038, 0.034, [6, 4, 3][lod], _vc(GREY, 5.0, 0.12), 3, 0.08, 2.0)
	_prism(w, Vector3(0.0, 1.0, -0.02), Vector3(0.55, 1.05, 0.12), 0.036, 0.03, [6, 4, 3][lod], GREY.lightened(0.1), 3, 0.08, 3.0)
	_prism(w, Vector3(0.9, 0.05, 0.55), Vector3(2.9, 0.07, 0.42), 0.036, 0.032, [6, 4, 3][lod], _vc(GREY, 9.0, 0.12), 3, 0.08, 4.0)
	if lod < 2:
		_prism(w, Vector3(0.55, 1.05, 0.12), Vector3(0.7, 1.0, 0.15), 0.01, 0.003, 4, Color(0.72, 0.62, 0.45), 3, 0.05)   # the splintered tip

# ================================================================== hay
const STRAW := Color(0.68, 0.58, 0.33)

## A round bale lying on its side (axis along x), r its radius, w its width. kind 0 wrapped in pale plastic with a hay end,
## 1 bare net-wrapped hay, 2 a big tight-wound roll. The ends show the spiral of the wound hay.
static func _bale_round(p: Parts, r: float, w: float, kind: int, lod: int) -> void:
	var sd := p.b("plastic") if kind == 0 else p.b("hay")
	var ed := p.b("hay")
	var seg: int = [24, 12, 6][lod]
	var ts := [0.0, 0.05, 0.14, 0.3, 0.5, 0.7, 0.86, 0.95, 1.0] if lod == 0 else ([0.0, 0.1, 0.9, 1.0] if lod == 1 else [0.0, 1.0])
	var rfs := [0.88, 0.97, 0.995, 1.0, 1.0, 1.0, 0.995, 0.97, 0.88] if lod == 0 else ([0.9, 1.0, 1.0, 0.9] if lod == 1 else [1.0, 1.0])
	var sq := 0.94
	var cy := r * sq
	var base: Color
	match kind:
		0: base = Color(0.82, 0.86, 0.80)
		1: base = Color(0.66, 0.57, 0.33)
		_: base = Color(0.58, 0.48, 0.28)
	var ring := func(i: int, j: int) -> Vector3:
		var a: float = TAU * j / seg
		var R: float = r * rfs[i]
		return Vector3(-w * 0.5 + w * ts[i], cy + R * sq * sin(a), R * cos(a))
	for i in ts.size() - 1:
		for j in seg:
			var j2: int = (j + 1) % seg
			var am: float = TAU * (j + 0.5) / seg
			var c := base
			if kind == 0:
				c = base                                         # film: smooth, the wrinkles come from the shader
				if j % 8 == 3: c = base.darkened(0.08)           # an overlap seam
			elif kind == 1:
				c = base.darkened(0.1 if j % 2 == 0 else 0.0)    # the net lines
			else:
				c = base.darkened(0.08 if (j + i) % 3 == 0 else 0.0)
			c = _g(_vc(c, i * 3.1 + j * 1.3 + kind * 7.0, 0.025 if kind == 0 else 0.06), G_NONE)
			# smooth normals round the barrel (and a little along it at the rounded edges)
			var tilt0: float = (ts[i] - 0.5) * 2.0; var tilt1: float = (ts[i + 1] - 0.5) * 2.0
			var nn := func(jj: int, t: float) -> Vector3:
				var aa := TAU * jj / seg
				var e: float = clampf((absf(t) - 0.8) / 0.2, 0.0, 1.0)
				return Vector3(signf(t) * e * 0.7, sin(aa), cos(aa)).normalized()
			var p00: Vector3 = ring.call(i, j); var p01: Vector3 = ring.call(i, j2); var p11: Vector3 = ring.call(i + 1, j2); var p10: Vector3 = ring.call(i + 1, j)
			DroneParts._tri(sd.pos, sd.nrm, sd.cols, p00, p01, p11, nn.call(j, tilt0), nn.call(j2, tilt0), nn.call(j2, tilt1), c, c, c)
			DroneParts._tri(sd.pos, sd.nrm, sd.cols, p00, p11, p10, nn.call(j, tilt0), nn.call(j2, tilt1), nn.call(j, tilt1), c, c, c)
	# the ends: rings of spiral straw, fan in the middle
	var rings := [0.88, 0.7, 0.52, 0.34, 0.16] if lod == 0 else ([0.9, 0.45] if lod == 1 else [0.9])
	for end in 2:
		var x := -w * 0.5 if end == 0 else w * 0.5
		var nx := Vector3(-1 if end == 0 else 1, 0, 0)
		for j in seg:
			var j2: int = (j + 1) % seg
			var a0: float = TAU * j / seg; var a1: float = TAU * j2 / seg
			var prev := -1.0
			for q in rings.size():
				var rr: float = rings[q] * r
				var c := _vc(STRAW if kind != 2 else Color(0.62, 0.50, 0.26), q * 4.0 + (j + q * 3) % 5 + end * 11.0, 0.14)
				if q % 2 == 1: c = c.darkened(0.1)
				c = _g(c, G_NONE)
				var p0 := Vector3(x, cy + rr * sq * sin(a0), rr * cos(a0)); var p1 := Vector3(x, cy + rr * sq * sin(a1), rr * cos(a1))
				if q == 0:
					pass
				if q + 1 < rings.size():
					var r2: float = rings[q + 1] * r
					var p2 := Vector3(x, cy + r2 * sq * sin(a1), r2 * cos(a1)); var p3 := Vector3(x, cy + r2 * sq * sin(a0), r2 * cos(a0))
					ed.quad(p0, p1, p2, p3, c, nx)
				else:
					ed.tri(p0, p1, Vector3(x, cy, 0.0), c, nx)
				prev = rr

## One square bale at c (centre of its base) turned by yaw: 0.9 long (x), 0.45 wide (z), 0.35 high. kind 0 fresh gold hay with
## orange twine, 1 older grey-brown with green twine. cells splits each face into that many pieces of varied colour.
static func _bale_sq(p: Parts, c: Vector3, yaw: float, kind: int, cells: int, twine: bool, bottom: bool) -> void:
	var h := p.b("hay")
	var bas := Basis(Vector3.UP, yaw)
	var L := 0.9; var Wd := 0.45; var H := 0.35
	var gc := G_X if absf(cos(yaw)) > 0.7 else G_Z
	var base := _g(Color(0.76, 0.64, 0.32) if kind == 0 else Color(0.62, 0.53, 0.34), gc)
	var tw := _g(Color(0.86, 0.45, 0.16) if kind == 0 else Color(0.28, 0.45, 0.25), gc)
	var cx := maxi(1, cells); var cz := maxi(1, cells / 2)
	var P := func(x: float, y: float, z: float) -> Vector3: return c + bas * Vector3(x, y, z)
	var n_up := bas * Vector3.UP
	var salt := c.x * 7.1 + c.z * 3.3 + c.y * 11.0 + kind * 5.0
	# top and bottom, split along x and z
	for i in cx:
		for j in cz:
			var x0 := -L * 0.5 + L * i / cx; var x1 := -L * 0.5 + L * (i + 1) / cx
			var z0 := -Wd * 0.5 + Wd * j / cz; var z1 := -Wd * 0.5 + Wd * (j + 1) / cz
			var col := _vc(base, salt + i * 1.7 + j * 3.1, 0.1)
			h.quad(P.call(x0, H, z0), P.call(x0, H, z1), P.call(x1, H, z1), P.call(x1, H, z0), col, n_up)
			if bottom: h.quad(P.call(x0, 0, z0), P.call(x1, 0, z0), P.call(x1, 0, z1), P.call(x0, 0, z1), col.darkened(0.2), -n_up)
	# long sides (z = ±Wd/2)
	for s in [-1.0, 1.0]:
		var nz: Vector3 = bas * Vector3(0, 0, s)
		for i in cx:
			var x0 := -L * 0.5 + L * i / cx; var x1 := -L * 0.5 + L * (i + 1) / cx
			var col := _vc(base.darkened(0.05), salt + i * 2.3 + s * 4.0, 0.1)
			h.quad(P.call(x0, 0, s * Wd * 0.5), P.call(x1, 0, s * Wd * 0.5), P.call(x1, H, s * Wd * 0.5), P.call(x0, H, s * Wd * 0.5), col, nz)
	# the cut ends (x = ±L/2): stalk ends, darker
	for s in [-1.0, 1.0]:
		var nx: Vector3 = bas * Vector3(s, 0, 0)
		for j in cz:
			var z0 := -Wd * 0.5 + Wd * j / cz; var z1 := -Wd * 0.5 + Wd * (j + 1) / cz
			var col := _vc(base.darkened(0.18), salt + j * 3.7 + s * 2.0, 0.12)
			h.quad(P.call(s * L * 0.5, 0, z0), P.call(s * L * 0.5, H, z0), P.call(s * L * 0.5, H, z1), P.call(s * L * 0.5, 0, z1), col, nx)
	if twine:
		for tx in [-0.22, 0.22]:
			var e := 0.004
			var wd := 0.012
			# a band round the bale at x = tx: top, two sides, bottom
			var top_ := h
			top_.quad(P.call(tx - wd, H + e, -Wd * 0.5 - e), P.call(tx - wd, H + e, Wd * 0.5 + e), P.call(tx + wd, H + e, Wd * 0.5 + e), P.call(tx + wd, H + e, -Wd * 0.5 - e), tw, n_up)
			for s in [-1.0, 1.0]:
				var nz2: Vector3 = bas * Vector3(0, 0, s)
				top_.quad(P.call(tx - wd, 0, s * (Wd * 0.5 + e)), P.call(tx + wd, 0, s * (Wd * 0.5 + e)), P.call(tx + wd, H + e, s * (Wd * 0.5 + e)), P.call(tx - wd, H + e, s * (Wd * 0.5 + e)), tw, nz2)

## A small stack of square bales: 1.8 x 1.8 m at the base, four layers (8, 8, 4, 2 bales), the layers crossed, a little off true.
static func _hay_stack(p: Parts, lod: int) -> void:
	if lod == 2:
		var h := p.b("hay")
		_boxy(h, Vector3(0, 0.35, 0), Vector3(1.8, 0.7, 1.8), 0.0, Color(0.7, 0.58, 0.3), Color(0.74, 0.62, 0.32))
		_boxy(h, Vector3(0, 0.875, 0), Vector3(1.8, 0.35, 1.8), 0.0, Color(0.68, 0.56, 0.3), Color(0.74, 0.62, 0.32))
		_boxy(h, Vector3(0, 1.225, 0), Vector3(0.9, 0.35, 0.9), 0.0, Color(0.7, 0.58, 0.3), Color(0.76, 0.64, 0.33))
		return
	var cells := 2 if lod == 0 else 1
	var k := 0
	# layer 1 and 2: eight bales each
	for layer in 2:
		var y := 0.35 * layer
		for i in 2:
			for j in 4:
				var pos: Vector3
				var yaw := 0.0
				if layer == 0:
					pos = Vector3(-0.45 + 0.9 * i, y, -0.675 + 0.45 * j)
				else:
					pos = Vector3(-0.675 + 0.45 * j, y, -0.45 + 0.9 * i); yaw = PI * 0.5
				pos += Vector3(_rnd(k, 1.0) - 0.5, 0.0, _rnd(k, 2.0) - 0.5) * 0.03
				_bale_sq(p, pos, yaw + (_rnd(k, 3.0) - 0.5) * 0.05, k % 4 == 3 and 1 or 0, cells, lod == 0, layer == 0)
				k += 1
	# layer 3: four bales across the middle, layer 4: two on top
	for i in 2:
		for j in 2:
			_bale_sq(p, Vector3(-0.45 + 0.9 * i, 0.7, -0.225 + 0.45 * j - 0.225 * 0.0) * Vector3(1, 1, 1) + Vector3(0, 0, 0), 0.0, 0, cells, lod == 0, false)
	# the layer 3 bales sit as 2 x 2 (x by z) over the middle of layer 2
	for j in 2:
		_bale_sq(p, Vector3(0.0, 1.05, -0.225 + 0.45 * j), 0.0, 1 if j == 1 else 0, cells, lod == 0, false)

# ================================================================== crops
## One corn plant at pos: a stalk H high, leaves arching, a cob and a tassel. pal 0 green in summer, 1 ripening.
static func _corn(p: Parts, pos: Vector3, H: float, seed: float, pal: int, lod: int) -> void:
	var lf := p.b("leaf"); var pl := p.b("plant")
	var lean := Vector3(_rnd(seed, 1.0) - 0.5, 0.0, _rnd(seed, 2.0) - 0.5) * 0.14
	var sp := func(f: float) -> Vector3: return pos + Vector3(0, H * f, 0) + lean * (H * f * f)
	_prism(pl, pos - Vector3(0, 0.03, 0), sp.call(1.0), 0.02, 0.009, [6, 4][lod], Color(0.44, 0.54, 0.26) if pal == 0 else Color(0.62, 0.58, 0.30), 0, 0.06, seed)
	var n: int = [14, 6][lod]
	for i in n:
		var f: float = 0.10 + 0.72 * float(i) / (n - 1)
		var ang: float = seed * 3.1 + i * 2.39996
		var out := Vector3(cos(ang), 0, sin(ang))
		var ln := lerpf(1.0, 0.55, f) * (0.85 + 0.2 * _rnd(seed + i, 3.0)) * (H / 2.4) * 0.85
		var d0 := (out * 0.7 + Vector3.UP * 0.7).normalized()
		var acc := out * 0.30 - Vector3.UP * 0.85
		var c0 := Color(0.20, 0.38, 0.10); var c1 := Color(0.30, 0.48, 0.14)
		if pal == 1:
			c0 = Color(0.36, 0.45, 0.13).lerp(Color(0.62, 0.52, 0.22), 1.0 - f); c1 = Color(0.58, 0.50, 0.20)
		_blade(lf, sp.call(f), d0, acc, ln, 0.13, [4, 2][lod], _vc(c0, seed + i, 0.1), _vc(c1, seed + i * 2.0, 0.1), 3.0, 0.12 if lod == 0 else 0.0)
	if lod == 0:
		var cb: Vector3 = sp.call(0.58)
		var ang := seed * 5.0 + 1.0
		var out := Vector3(cos(ang), 0, sin(ang))
		var husk := Color(0.40, 0.50, 0.22) if pal == 0 else Color(0.66, 0.60, 0.36)
		_prism(pl, cb + out * 0.02, cb + out * 0.09 + Vector3(0, 0.17, 0), 0.036, 0.015, 5, husk, 3, 0.08, seed)
		_prism(pl, cb + out * 0.09 + Vector3(0, 0.17, 0), cb + out * 0.11 + Vector3(0, 0.23, 0), 0.012, 0.004, 4, Color(0.55, 0.4, 0.2), 3, 0.05)
		for k in 3:      # the husk leaves wrapped round the ear, peeling away at the tip
			var ha := ang + (k - 1) * 1.9
			var ho := Vector3(cos(ha), 0, sin(ha))
			_blade(lf, cb + out * 0.02 + ho * 0.03, (Vector3.UP * 0.9 + out * 0.35 + ho * 0.15).normalized(), ho * 0.35 + out * 0.08, 0.26, 0.05, 2, husk.darkened(0.1), husk.lightened(0.1), 1.6)
		for k in 4:      # silk
			var sa := seed + k * 1.57
			_blade(lf, cb + out * 0.1 + Vector3(0, 0.2, 0), (Vector3.UP + Vector3(cos(sa), 0, sin(sa)) * 0.5).normalized(), Vector3(cos(sa), -0.4, sin(sa)) * 0.3, 0.08, 0.004, 1, Color(0.62, 0.45, 0.25), Color(0.5, 0.35, 0.2), 1.0)
	var tp: Vector3 = sp.call(1.0)
	for i in [5, 3][lod]:
		var a: float = seed + i * 1.2566
		var o := Vector3(cos(a), 0, sin(a))
		_blade(lf, tp - Vector3(0, 0.03, 0), (o * 0.45 + Vector3.UP * 0.9).normalized(), o * 0.25 - Vector3.UP * 0.2, 0.28, 0.03, 2, Color(0.66, 0.58, 0.34), Color(0.78, 0.70, 0.46), 1.2, 0.3)

static func _corn_stand(p: Parts, v: int, lod: int) -> void:
	var offs := [Vector3(-0.18, 0, -0.1), Vector3(0.2, 0, -0.14), Vector3(-0.05, 0, 0.2), Vector3(0.24, 0, 0.18)]
	var hs := [2.5, 2.35, 2.6, 2.25]
	if v == 1:
		offs = [Vector3(-0.2, 0, 0.0), Vector3(0.18, 0, -0.18), Vector3(0.05, 0, 0.18), Vector3(-0.28, 0, 0.26), Vector3(0.28, 0, 0.14)]
		hs = [2.4, 2.2, 2.55, 1.9, 2.3]
	if lod == 2:
		var lo := Color(0.20, 0.34, 0.11) if v == 0 else Color(0.40, 0.42, 0.16)
		var hi := Color(0.34, 0.48, 0.16) if v == 0 else Color(0.66, 0.58, 0.28)
		_cards_x(p.b("leaf"), Vector3.ZERO, 1.0, 2.35, 3, lo, hi)
		return
	for i in offs.size():
		_corn(p, offs[i], hs[i], 1.0 + i * 3.7 + v * 11.0, v, lod)

## A 4 m run of one row of corn along z (z from -2 to 2): stalks about every 0.4 m, tiling end to end.
static func _corn_row(p: Parts, lod: int) -> void:
	if lod == 2:
		_loaf(p.b("leaf"), PackedVector2Array([Vector2(-0.3, 0.0), Vector2(0.3, 0.0), Vector2(0.42, 0.9), Vector2(0.3, 1.8), Vector2(0.0, 2.35), Vector2(-0.3, 1.8), Vector2(-0.42, 0.9)]),
			-2.0, 2.0, Color(0.20, 0.34, 0.11), Color(0.36, 0.50, 0.17), 2.35)
		return
	for i in 10:
		var z := -2.0 + 0.4 * (i + 0.5) + (_rnd(i, 4.0) - 0.5) * 0.12
		_corn(p, Vector3((_rnd(i, 6.0) - 0.5) * 0.1, 0, z), 2.2 + 0.35 * _rnd(i, 8.0), 2.0 + i * 2.9, 0, lod)

## A thin round stem through pts (a tapering run of 4-sided prisms): the stalks the flat ribbons would lose edge-on.
static func _stem(b: NewModels2.Buf, pts: Array, r0: float, r1: float, col0: Color, col1: Color) -> void:
	var n := pts.size()
	for k in n - 1:
		var ra := lerpf(r0, r1, float(k) / (n - 1)); var rb := lerpf(r0, r1, float(k + 1) / (n - 1))
		_prism(b, pts[k], pts[k + 1], ra, rb, 4, col0.lerp(col1, float(k) / (n - 1)), 0, 0.04, k)

## A tuft of barley about 0.5 m wide, 0.8 m high: folded blades, round stems and seed heads with long awns. a ripening
## green-gold, b ripe gold with heads drooping.
static func _barley(p: Parts, v: int, lod: int) -> void:
	if lod == 2:
		var lo := Color(0.42, 0.44, 0.17) if v == 0 else Color(0.58, 0.48, 0.2)
		var hi := Color(0.58, 0.56, 0.26) if v == 0 else Color(0.78, 0.64, 0.3)
		_cards_x(p.b("leaf"), Vector3.ZERO, 0.55, 0.8, 3, lo, hi, 0.7)
		return
	var lf := p.b("leaf"); var pl := p.b("plant")
	var stem0 := Color(0.46, 0.50, 0.19) if v == 0 else Color(0.68, 0.58, 0.26)
	var stem1 := Color(0.60, 0.58, 0.26) if v == 0 else Color(0.78, 0.66, 0.30)
	var head := Color(0.70, 0.62, 0.30) if v == 0 else Color(0.84, 0.70, 0.34)
	var nb: int = [26, 12][lod]; var nh: int = [18, 9][lod]
	for i in nb:
		var base := Vector3((_rnd(i, 1.0) - 0.5) * 0.46, 0, (_rnd(i, 2.0) - 0.5) * 0.46)
		var lean := Vector3(_rnd(i, 3.0) - 0.5, 0, _rnd(i, 4.0) - 0.5) * 0.7
		_blade(lf, base, (Vector3.UP + lean * 0.35).normalized(), lean * 0.5 - Vector3.UP * 0.1, 0.32 + 0.3 * _rnd(i, 5.0), 0.028, 2, _vc(stem0, i, 0.1), _vc(stem1, i, 0.1), 1.5, 0.35)
	for i in nh:
		var base := Vector3((_rnd(i, 11.0) - 0.5) * 0.4, 0, (_rnd(i, 12.0) - 0.5) * 0.4)
		var lean := Vector3(_rnd(i, 13.0) - 0.5, 0, _rnd(i, 14.0) - 0.5)
		var droop := 0.3 if v == 0 else 0.55
		var d0 := (Vector3.UP + lean * 0.3).normalized()
		var acc := lean.normalized() * (0.18 + droop * 0.5) - Vector3.UP * (0.05 + droop * 0.2)
		var ln := 0.55 + 0.2 * _rnd(i, 15.0)
		var pts := _curve2(base, d0, acc, ln, 3)
		_stem(pl, pts, 0.0045, 0.0028, _vc(stem0, i + 20.0, 0.1), _vc(stem1, i + 20.0, 0.1))
		var tip: Vector3 = pts[3]; var tan := ((pts[3] as Vector3) - (pts[2] as Vector3)).normalized()
		_prism(pl, tip - tan * 0.01, tip + tan * 0.09, 0.012, 0.007, 5, _vc(head, i, 0.08), 3, 0.08, i)
		if lod == 0:
			for k in 5:
				var a: float = TAU * k / 5.0 + i
				var sp := (tan + (Vector3(cos(a), 0, sin(a))) * 0.16).normalized()
				_blade(lf, tip + tan * 0.05, sp, -Vector3.UP * 0.02, 0.11, 0.007, 1, head.lightened(0.08), head.lightened(0.2), 1.0, 0.4)

## A patch of alfalfa 0.5 m across and about 0.5 m high: many stems each carrying trifoliate leaves, a with leaves only, b in
## purple flower.
static func _alfalfa(p: Parts, v: int, lod: int) -> void:
	if lod == 2:
		var hi := Color(0.26, 0.42, 0.14) if v == 0 else Color(0.36, 0.38, 0.28)
		_cards_x(p.b("leaf"), Vector3.ZERO, 0.5, 0.5, 3, Color(0.17, 0.32, 0.09), hi, 0.6)
		return
	var lf := p.b("leaf"); var pl := p.b("plant")
	var stems: int = [16, 8][lod]; var nodes: int = [6, 3][lod]
	var green := Color(0.20, 0.42, 0.11)
	for i in stems:
		var base := Vector3((_rnd(i, 1.0) - 0.5) * 0.4, 0, (_rnd(i, 2.0) - 0.5) * 0.4)
		var lean := Vector3(_rnd(i, 3.0) - 0.5, 0, _rnd(i, 4.0) - 0.5) * 0.9
		var d0 := (Vector3.UP + lean * 0.35).normalized()
		var acc := lean * 0.25 - Vector3.UP * 0.05
		var ln := 0.34 + 0.18 * _rnd(i, 5.0)
		var pts := _curve2(base, d0, acc, ln, 3)
		_stem(pl, pts, 0.0045, 0.0025, Color(0.30, 0.44, 0.16), Color(0.38, 0.50, 0.20))
		var fine := _curve2(base, d0, acc, ln, 12)
		for q in nodes:
			var t := 0.2 + 0.8 * float(q) / maxi(1, nodes - 1)
			var node: Vector3 = fine[int(round(t * 12.0))]
			var oa: float = i * 1.9 + q * 2.4
			var o := Vector3(cos(oa), 0.35, sin(oa)).normalized()
			for k in 3:
				var a: float = (k - 1) * 0.6
				var dir := Vector3(o.x * cos(a) - o.z * sin(a), o.y, o.x * sin(a) + o.z * cos(a)).normalized()
				var lenl := 0.06 if k == 1 else 0.05
				var tip := node + dir * lenl
				var mid := node + dir * lenl * 0.5 + Vector3(0, 0.006, 0)
				_strip(lf, [node, mid, tip], [0.0, lenl * 0.7, 0.0], Vector3(-dir.z, 0, dir.x).normalized(), _vc(green, i * 3.0 + q + k, 0.14), _vc(green.lightened(0.1), i + q + k, 0.14), 0.12)
		if v == 1 and lod == 0:
			var tipf: Vector3 = pts[3]
			for k in 5:
				var a: float = TAU * k / 5.0 + i
				_blob(pl, tipf + Vector3(cos(a) * 0.014, 0.012 + 0.014 * k, sin(a) * 0.014), 0.014, _vc(Color(0.46, 0.28, 0.64), i + k, 0.12))

## A margin strip 1.2 x 0.5 m of field-edge weeds and grass: folded tall grass blades, cream umbels (wild carrot) made of
## little flower heads, yellow goldenrod and a few rusty dock spikes.
static func _weeds(p: Parts, lod: int) -> void:
	if lod == 2:
		_cards_x(p.b("leaf"), Vector3.ZERO, 0.9, 0.8, 3, Color(0.30, 0.34, 0.15), Color(0.58, 0.54, 0.30), 0.55)
		return
	var lf := p.b("leaf"); var pl := p.b("plant")
	var nb: int = [30, 12][lod]
	for i in nb:
		var base := Vector3((_rnd(i, 1.0) - 0.5) * 1.15, 0, (_rnd(i, 2.0) - 0.5) * 0.45)
		var lean := Vector3(_rnd(i, 3.0) - 0.5, 0, _rnd(i, 4.0) - 0.5)
		var g := Color(0.40, 0.46, 0.20).lerp(Color(0.66, 0.60, 0.32), _rnd(i, 6.0))
		_blade(lf, base, (Vector3.UP + lean * 0.3).normalized(), lean * 0.45 - Vector3.UP * 0.1, 0.5 + 0.55 * _rnd(i, 5.0), 0.04, 3, _vc(g.darkened(0.15), i, 0.1), _vc(g, i, 0.1), 1.5, 0.3)
	if lod == 0:
		for i in 3:      # umbels
			var base := Vector3(-0.45 + 0.45 * i + (_rnd(i, 21.0) - 0.5) * 0.2, 0, (_rnd(i, 22.0) - 0.5) * 0.3)
			var pts := _curve2(base, Vector3(0.05 * (i - 1), 1.0, 0.0).normalized(), Vector3(0.1, -0.1, 0.0), 0.75 + 0.1 * i, 3)
			_stem(pl, pts, 0.006, 0.004, Color(0.36, 0.46, 0.2), Color(0.44, 0.5, 0.24))
			var tip: Vector3 = pts[3]
			for k in 8:
				var a: float = TAU * k / 8.0
				_prism(pl, tip, tip + Vector3(cos(a) * 0.06, 0.03 - 0.012 * (k % 2), sin(a) * 0.06), 0.002, 0.0015, 3, Color(0.5, 0.58, 0.3), 2, 0.05)
				_blob(pl, tip + Vector3(cos(a) * 0.062, 0.032 - 0.012 * (k % 2), sin(a) * 0.062), 0.017, _vc(Color(0.93, 0.93, 0.85), i * 8 + k, 0.05))
			_blob(pl, tip + Vector3(0, 0.035, 0), 0.018, Color(0.93, 0.93, 0.85))
		for i in 3:      # goldenrod
			var base := Vector3(-0.5 + 0.5 * i + (_rnd(i, 31.0) - 0.5) * 0.2, 0, 0.12 + (_rnd(i, 32.0) - 0.5) * 0.2)
			var pts := _curve2(base, Vector3(0.0, 1.0, 0.04).normalized(), Vector3(0.0, -0.05, 0.1), 0.6, 3)
			_stem(pl, pts, 0.005, 0.003, Color(0.36, 0.46, 0.2), Color(0.42, 0.5, 0.24))
			var tip: Vector3 = pts[3]
			for k in 8:
				_blob(pl, tip + Vector3((k % 2 - 0.5) * 0.035, 0.022 * k - 0.05, (k % 3 - 1) * 0.022), 0.02, _vc(Color(0.88, 0.70, 0.12), i + k, 0.1))
		for i in 2:      # dock spikes
			var base := Vector3(-0.2 + 0.5 * i, 0, -0.14)
			_prism(pl, base, base + Vector3(0.0, 0.7, 0.0), 0.007, 0.004, 4, Color(0.50, 0.30, 0.15), 0, 0.05)
			for k in 7:
				_blob(pl, base + Vector3(0.0, 0.42 + 0.04 * k, 0.0), 0.018, _vc(Color(0.52, 0.26, 0.12), i + k, 0.1))

# ================================================================== field ground
## A height field over sx x sz m, centred on the origin: hf(x, z) gives the height, cf(x, z, h, i, j) the colour. The
## heights and colours repeat across the edges when hf is periodic and cf uses the wrapped (i, j), so tiles meet.
static func _hf(b: NewModels2.Buf, nx: int, nz: int, sx: float, sz: float, hf: Callable, cf: Callable) -> void:
	var pts := PackedVector3Array(); var nrm := PackedVector3Array(); var cols := PackedColorArray()
	var e := minf(sx / nx, sz / nz) * 0.5
	for j in nz + 1:
		for i in nx + 1:
			var x := -sx * 0.5 + sx * i / nx; var z := -sz * 0.5 + sz * j / nz
			var h: float = hf.call(x, z)
			pts.append(Vector3(x, h, z))
			var dx: float = (float(hf.call(x + e, z)) - float(hf.call(x - e, z))) / (2.0 * e)
			var dz: float = (float(hf.call(x, z + e)) - float(hf.call(x, z - e))) / (2.0 * e)
			nrm.append(Vector3(-dx, 1.0, -dz).normalized())
			cols.append(cf.call(x, z, h, i % nx, j % nz))
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i; var bb := a + 1; var c := a + nx + 2; var d := a + nx + 1
			DroneParts._tri(b.pos, b.nrm, b.cols, pts[a], pts[d], pts[c], nrm[a], nrm[d], nrm[c], cols[a], cols[d], cols[c])
			DroneParts._tri(b.pos, b.nrm, b.cols, pts[a], pts[c], pts[bb], nrm[a], nrm[c], nrm[bb], cols[a], cols[c], cols[bb])

## Tilled soil in rows 0.76 m apart (the corn row spacing), running along z: ridges 0.17 m high, small clods on top. 3.04 x 4 m.
static func _furrow_a(p: Parts, lod: int) -> void:
	var sx := 3.04; var sz := 4.0
	var nx: int = [32, 16, 8][lod]; var nz: int = [40, 20, 4][lod]
	var hf := func(x: float, z: float) -> float:
		var ridge := pow(0.5 + 0.5 * cos(TAU * x / 0.76), 1.3)
		return 0.03 + 0.17 * ridge + 0.012 * sin(TAU * (3.0 * z / sz + 7.0 * x / sx) + 1.0) + 0.01 * sin(TAU * (5.0 * z / sz - 11.0 * x / sx) + 2.0)
	var cf := func(x: float, z: float, h: float, i: int, j: int) -> Color:
		var t := clampf((h - 0.03) / 0.2, 0.0, 1.0)
		var c := Color(0.17, 0.115, 0.08).lerp(Color(0.31, 0.22, 0.15), t)
		return c.darkened(0.12 * _rnd(i * 1.0, j * 3.0 + 1.0))
	_hf(p.b("soil"), nx, nz, sx, sz, hf, cf)

## Freshly ploughed soil: slices turned over in an asymmetric wave 0.45 m apart, big clods. 3.15 x 4.2 m.
static func _furrow_b(p: Parts, lod: int) -> void:
	var sx := 3.15; var sz := 4.2
	var nx: int = [42, 21, 28][lod]; var nz: int = [42, 21, 6][lod]
	var hf := func(x: float, z: float) -> float:
		var u := fposmod(x / 0.45, 1.0)
		var saw := pow(u, 0.65) * (1.0 - u * 0.0)
		if u > 0.82: saw = lerpf(saw, 0.0, (u - 0.82) / 0.18)
		return 0.03 + 0.2 * saw + 0.02 * sin(TAU * (3.0 * z / sz + 7.0 * x / sx) + 0.5) + 0.016 * sin(TAU * (6.0 * z / sz - 9.0 * x / sx) + 2.5)
	var cf := func(x: float, z: float, h: float, i: int, j: int) -> Color:
		var t := clampf((h - 0.03) / 0.22, 0.0, 1.0)
		var c := Color(0.15, 0.10, 0.075).lerp(Color(0.26, 0.18, 0.12), t)
		return c.darkened(0.16 * _rnd(i * 1.0, j * 3.0 + 7.0))
	_hf(p.b("soil"), nx, nz, sx, sz, hf, cf)

## A headland turn row 6 x 3 m: flat packed soil with the two tyre ruts of a tractor swinging round in a long S, grass coming in
## along the edges.
static func _headland(p: Parts, lod: int) -> void:
	var sx := 6.0; var sz := 3.0
	var nx: int = [40, 20, 6][lod]; var nz: int = [20, 10, 3][lod]
	var rut := func(x: float, z: float, zc: float) -> float:
		var d := (z - (zc + 0.45 * sin(TAU * x / sx))) / 0.18
		return exp(-d * d)
	var hf := func(x: float, z: float) -> float:
		var v: float = 0.05 - 0.07 * rut.call(x, z, -0.6) - 0.07 * rut.call(x, z, 0.6)
		var edge := smoothstep(1.0, 1.5, absf(z))
		return v + 0.04 * edge + 0.008 * sin(TAU * (3.0 * z / sz + 5.0 * x / sx) + 1.0)
	var cf := func(x: float, z: float, h: float, i: int, j: int) -> Color:
		var c := Color(0.30, 0.23, 0.15)
		var edge := smoothstep(1.0, 1.5, absf(z))
		c = c.lerp(Color(0.30, 0.38, 0.16), edge * (0.5 + 0.5 * _rnd(i * 1.0, j * 2.0)))
		var r: float = maxf(rut.call(x, z, -0.6), rut.call(x, z, 0.6))
		return c.lerp(Color(0.16, 0.115, 0.08), r * 0.8).darkened(0.1 * _rnd(i * 1.0, j * 3.0 + 3.0))
	_hf(p.b("soil"), nx, nz, sx, sz, hf, cf)

## A muddy two-rut farm track 2.6 m wide, 8 m long (along z): ruts 1.7 m apart holding wet mud, a grassy hump between them.
static func _track(p: Parts, lod: int) -> void:
	var sx := 2.6; var sz := 8.0
	var nx: int = [20, 10, 4][lod]; var nz: int = [60, 30, 4][lod]
	var rut := func(x: float, z: float, xc: float) -> float:
		var d := (x - xc - 0.06 * sin(TAU * 2.0 * z / sz)) / 0.26
		return exp(-d * d)
	var hf := func(x: float, z: float) -> float:
		var depth := 0.13 * (0.7 + 0.3 * sin(TAU * (3.0 * z / sz + 1.0 * x / sx)))
		var hump := 0.05 * exp(-pow(x / 0.4, 2.0))
		var shoulder := 0.08 * smoothstep(0.9, 1.3, absf(x))
		return 0.1 - depth * (rut.call(x, z, -0.85) + rut.call(x, z, 0.85)) + hump + shoulder + 0.01 * sin(TAU * (7.0 * z / sz + 3.0 * x / sx) + 1.0)
	var cf := func(x: float, z: float, h: float, i: int, j: int) -> Color:
		var r: float = rut.call(x, z, -0.85) + rut.call(x, z, 0.85)
		var c := Color(0.30, 0.22, 0.14)
		var grass := Color(0.30, 0.38, 0.16)
		var gmix := (exp(-pow(x / 0.35, 2.0)) * 0.8 + smoothstep(0.95, 1.3, absf(x))) * (0.6 + 0.4 * _rnd(i * 1.0, j * 2.0))
		c = c.lerp(grass, clampf(gmix, 0.0, 1.0))
		return c.lerp(Color(0.12, 0.09, 0.07), clampf(r * 0.9, 0.0, 1.0)).darkened(0.08 * _rnd(i * 1.0, j * 3.0 + 5.0))
	_hf(p.b("mud"), nx, nz, sx, sz, hf, cf)

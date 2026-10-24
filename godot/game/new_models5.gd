class_name NewModels5
extends RefCounted
## The fifth batch of models drawn by code (batch "models7"): farm animals, boats and the lake shore, farm machinery and the farmyard,
## and the telegraph wire and a hanging gate. Real metres. Forward is -z, up is +y, x is right. The contract is game/README-models.md.
## Everything is photographic by intent: animals are smooth lofted bodies (not boxes) in the coat shader farm_coat.gdshader (patches,
## hair, wool, sheen), with wet noses and glossy eyes; boats and machinery take the paint shader farm_paint.gdshader (clear coat, wear,
## rust, dried mud) or the photographed CC0 wood and steel of farm_props.gdshader (the same materials as NewModels3).
## Entry points:
##   NewModels5.mesh(name, lod)        the whole model as one ArrayMesh (lod 0 near, 1 middle, 2 far)
##   NewModels5.parts(name, lod)       the movable parts: {part: {"mesh": ArrayMesh drawn about its own pivot, "pivot": Vector3 in the
##                                     model frame}} plus "body" (pivot (0,0,0)); put each part's node at its pivot to turn it
##   NewModels5.colliders(name)        box strips (AABB, model frame) for what a drone can hit
##   NewModels5.NAMES, NewModels5.INFO (what each is, its size, its pivots and where its origin is)

const NAMES: Array[String] = [
	"cow_a", "cow_b", "cow_c", "calf_a", "sheep_a", "sheep_b", "lamb_a", "horse_a", "horse_b", "chicken_a", "dog_a",
	"rowboat_a", "sailboat_a", "sailboat_b", "fishing_boat_a", "jetty_a", "mooring_post_a", "buoy_a",
	"seed_drill_a", "plough_a", "combine_a", "baler_a", "water_trough_a", "feed_rack_a", "wood_pile_a", "oil_tank_a", "grain_silo_a",
	"chicken_coop_a", "dog_kennel_a",
	"telegraph_wire_10m", "fence_gate_hanging_a",
]

static var _cache := {}
static var _pcache := {}
static var _mats := {}

# ================================================================== materials
## key -> the material. Coats (farm_coat.gdshader), paints (farm_paint.gdshader), or the NewModels3 photographed ones.
static func _mat(key: String) -> Material:
	if _mats.has(key): return _mats[key]
	var m: Material
	match key:
		"wood", "steel", "hay", "plastic", "soil", "mud":
			m = NewModels3._mat(key)
		"cloth", "glass":
			m = NewModels2._mat(key)
		"feather":
			var s := ShaderMaterial.new()
			s.shader = load("res://game/shaders/farm_coat.gdshader") as Shader
			s.set_shader_parameter("barring", 0.25); s.set_shader_parameter("scallop", 1.0); s.set_shader_parameter("hair", 0.3); s.set_shader_parameter("sheen", 0.35)
			s.set_shader_parameter("rough_base", 0.6)
			m = s
		"holstein", "hereford", "jersey", "hair", "wool", "horse":
			m = _fur_chain(key, 0, Vector3.ZERO, 0.6)           # a placeholder for code that asks for the bare key (the tests)
		"paint", "paint_matte", "hull", "mudpaint", "bin", "zinc":
			var s := ShaderMaterial.new()
			s.shader = load("res://game/shaders/farm_paint.gdshader") as Shader
			match key:
				"paint": s.set_shader_parameter("gloss", 0.3)
				"paint_matte": s.set_shader_parameter("gloss", 0.55)
				"hull": s.set_shader_parameter("gloss", 0.16)
				"mudpaint": s.set_shader_parameter("gloss", 0.34); s.set_shader_parameter("mud_to", 0.75)
				"bin": s.set_shader_parameter("gloss", 0.38); s.set_shader_parameter("metal_amt", 0.85); s.set_shader_parameter("ripple", 6.0)
				"zinc": s.set_shader_parameter("gloss", 0.42); s.set_shader_parameter("metal_amt", 0.8)
			m = s
		"skin", "eye", "horn", "rope":
			var sm := StandardMaterial3D.new()
			sm.vertex_color_use_as_albedo = true; sm.vertex_color_is_srgb = true
			match key:
				"skin": sm.roughness = 0.32; sm.metallic_specular = 0.6; sm.rim_enabled = true; sm.rim = 0.2     # wet noses, udders, combs
				"eye": sm.roughness = 0.03; sm.metallic_specular = 1.0; sm.clearcoat_enabled = true; sm.clearcoat = 1.0; sm.clearcoat_roughness = 0.02
				"horn": sm.roughness = 0.45; sm.metallic_specular = 0.5                                      # hooves, beaks, horn
				"rope": sm.roughness = 0.95; sm.metallic_specular = 0.1
			m = sm
		_:
			push_error("NewModels5: no material " + key)
			m = StandardMaterial3D.new()
	_mats[key] = m
	return m

## How many shells of fur a level of detail gets: 16 near, 6 middle, none far on a desktop; 6, 3, none on a phone (the Mobile renderer / the simple camera).
static func fur_shells(lod: int) -> int:
	var mobile := OS.has_feature("mobile")
	return [6, 3, 0][lod] if mobile else [16, 6, 0][lod]

## The uniforms of each coat (see game/shaders/fur.gdshader).
const FUR := {
	"holstein": {"fur_len": 0.007, "density": 330.0, "taper": 0.5, "root_dark": 0.5, "tip_light": 1.08, "spec1": 0.4, "spec1_pow": 130.0, "spec2": 0.16,
		"patch_thr": 0.5, "patch_soft": 0.014, "patch_col": Vector3(0.03, 0.028, 0.028), "patch_axis": Vector3(2.6, 3.6, 1.5), "patch_seed": 3.7, "scatter": 0.45},
	"hereford": {"fur_len": 0.011, "density": 280.0, "taper": 0.55, "root_dark": 0.42, "tip_light": 1.12, "spec1": 0.28, "spec1_pow": 90.0, "spec2": 0.14, "scatter": 0.6},
	"jersey": {"fur_len": 0.006, "density": 350.0, "taper": 0.5, "root_dark": 0.5, "tip_light": 1.06, "spec1": 0.5, "spec1_pow": 150.0, "spec2": 0.2, "scatter": 0.5},
	"horse": {"fur_len": 0.0045, "density": 420.0, "taper": 0.5, "root_dark": 0.72, "tip_light": 1.05, "spec1": 0.6, "spec1_pow": 190.0, "spec2": 0.3, "scatter": 0.3},
	"hair": {"fur_len": 0.013, "density": 240.0, "taper": 0.5, "root_dark": 0.4, "tip_light": 1.12, "spec1": 0.4, "spec1_pow": 100.0, "spec2": 0.2, "scatter": 0.6,
		"flow": Vector3(0.0, -0.4, 1.0)},
	"wool": {"fur_len": 0.05, "density": 75.0, "taper": 0.6, "root_dark": 0.6, "tip_light": 1.05, "wool": 1.0, "curl": 0.8, "spec1": 0.12, "spec1_pow": 40.0, "spec2": 0.1,
		"spec2_pow": 14.0, "scatter": 0.9, "dirt": 0.55, "sway": 1.5, "flow": Vector3(0.0, -0.1, 1.0)},
}

static func _fur_chain(key: String, lod: int, off: Vector3, leg_h: float) -> Material:
	var ck := "fur/%s/%d/%.2f,%.2f,%.2f/%.2f" % [key, lod, off.x, off.y, off.z, leg_h]
	if _mats.has(ck): return _mats[ck]
	var shader := load("res://game/shaders/fur.gdshader") as Shader
	var n := fur_shells(lod)
	var prm: Dictionary = FUR[key]
	var first: ShaderMaterial = null
	var prev: ShaderMaterial = null
	for i in n + 1:
		var m := ShaderMaterial.new()
		m.shader = shader
		for k in prm: m.set_shader_parameter(k, prm[k])
		m.set_shader_parameter("part_off", off)
		m.set_shader_parameter("leg_h", leg_h)
		m.set_shader_parameter("shell_t", float(i) / maxf(n, 1.0))
		m.set_shader_parameter("flat_coat", 1.0 if n == 0 else 0.0)
		if prev != null: prev.next_pass = m
		else: first = m
		prev = m
	_mats[ck] = first
	return first

# ================================================================== parts, entry points
## The parts of one model: part name -> material key -> Buf, plus each movable part's pivot.
class Parts:
	var m := {}                 # part -> {key -> Buf}
	var pivot := {}             # part -> Vector3
	var cur := "body"
	var leg_h := 0.6
	func b(key: String) -> NewModels2.Buf:
		if not m.has(cur): m[cur] = {}
		var d: Dictionary = m[cur]
		if not d.has(key): d[key] = NewModels2.Buf.new()
		return d[key]
	func part(name: String, pv := Vector3.ZERO) -> void:
		cur = name
		if name != "body": pivot[name] = pv

static func _build(name: String, lod: int) -> Parts:
	var p := Parts.new()
	match name:
		"cow_a", "cow_b", "cow_c", "calf_a": _cattle(p, name, lod)
		"sheep_a", "sheep_b", "lamb_a": _sheep(p, name, lod)
		"horse_a", "horse_b": _horse(p, name, lod)
		"dog_a": _dog(p, lod)
		"chicken_a": _hen(p, lod)
		"rowboat_a": _rowboat(p, lod)
		"sailboat_a": _sailboat_a(p, lod)
		"sailboat_b": _sailboat_b(p, lod)
		"fishing_boat_a": _fishing_boat(p, lod)
		"jetty_a": _jetty(p, lod)
		"mooring_post_a": _mooring_post(p, lod)
		"buoy_a": _buoy(p, lod)
		"seed_drill_a": _seed_drill(p, lod)
		"plough_a": _plough(p, lod)
		"combine_a": _combine(p, lod)
		"baler_a": _baler(p, lod)
		"water_trough_a": _trough(p, lod)
		"feed_rack_a": _feed_rack(p, lod)
		"wood_pile_a": _wood_pile(p, lod)
		"oil_tank_a": _oil_tank(p, lod)
		"grain_silo_a": _grain_bin(p, lod)
		"chicken_coop_a": _coop(p, lod)
		"dog_kennel_a": _kennel(p, lod)
		"telegraph_wire_10m": _telegraph_wire(p, lod)
		"fence_gate_hanging_a": _gate_hanging(p, lod)
		_:
			push_error("NewModels5: no model called " + name)
	return p

static func _material(key: String, lod: int, off: Vector3, leg_h: float) -> Material:
	if FUR.has(key): return _fur_chain(key, lod, off, leg_h)
	return _mat(key)

static func _commit(p: Parts, lod: int, only := "", offset := Vector3.ZERO) -> ArrayMesh:
	var kit := DroneParts.Kit.new()
	for part in p.m:
		if only != "" and part != only: continue
		for key in p.m[part]:
			var buf: NewModels2.Buf = p.m[part][key]
			var d := buf.data()
			if offset != Vector3.ZERO:
				var pos: PackedVector3Array = (d[0] as PackedVector3Array).duplicate()
				for i in pos.size(): pos[i] -= offset
				d = [pos, d[1], d[2]]
			kit.add(_material(key, lod, offset, p.leg_h), d)
	return kit.commit()

static func mesh(name: String, lod := 0) -> ArrayMesh:
	lod = clampi(lod, 0, 2)
	var k := "%s/%d" % [name, lod]
	if _cache.has(k): return _cache[k]
	var out := _commit(_build(name, lod), lod)
	_cache[k] = out
	return out

static func parts(name: String, lod := 0) -> Dictionary:
	lod = clampi(lod, 0, 2)
	var k := "%s/%d" % [name, lod]
	if _pcache.has(k): return _pcache[k]
	var p := _build(name, lod)
	var out := {}
	for part in p.m:
		var pv: Vector3 = p.pivot.get(part, Vector3.ZERO)
		out[part] = {"mesh": _commit(p, lod, part, pv), "pivot": pv}
	_pcache[k] = out
	return out

# ================================================================== geometry
static func _vc(c: Color, k: float, amt := 0.06) -> Color:
	var o := NewModels._vary(c, Vector3(k * 1.7, k * 0.31, 5.1), amt)
	o.a = c.a
	return o

## A lofted body: rings of an ellipse (rx across, ry deep) at each station, joined with smooth normals. st = [[centre, rx, ry, (colour above), (colour below)], ...]
## in the local frame; xf puts it in the model. Rings follow the path (parallel-transported, so a bending leg does not twist).
## The "above" colour fades to the "below" one from the top of each ring to its underside (a pale belly, a dark back).
static func _sweep(b: NewModels2.Buf, st: Array, seg: int, cu: Color, cl := Color(-1, 0, 0), xf := Transform3D.IDENTITY,
		up := Vector3.UP, caps := 3) -> void:
	var n := st.size()
	if n < 2: return
	if cl.r < 0.0: cl = cu
	var P: Array = []
	var T: Array = []
	var CEN: Array = []
	var xp := Vector3.ZERO
	var tp := Vector3.FORWARD
	for i in n:
		var c: Vector3 = st[i][0]
		var t: Vector3 = (st[mini(i + 1, n - 1)][0] as Vector3) - (st[maxi(i - 1, 0)][0] as Vector3)
		t = t.normalized() if t.length_squared() > 1e-12 else tp
		var x: Vector3
		if i == 0:
			var u := up
			if absf(t.dot(u)) > 0.9: u = Vector3.FORWARD if absf(t.z) < 0.9 else Vector3.RIGHT
			x = u.cross(t).normalized()
		else:
			x = xp - t * xp.dot(t)
			if x.length_squared() < 1e-8: x = t.cross(Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT)
			x = x.normalized()
		var y := t.cross(x).normalized()
		xp = x; tp = t
		var rx: float = st[i][1]; var ry: float = st[i][2]
		var ring := PackedVector3Array()
		for k in seg:
			var a := TAU * k / seg
			ring.append(xf * (c + x * (rx * cos(a)) + y * (ry * sin(a))))
		P.append(ring); T.append(xf.basis * t); CEN.append(xf * c)
	var colv := func(i: int, k: int) -> Color:
		var cu_i: Color = st[i][3] if st[i].size() > 3 else cu
		var cl_i: Color = st[i][4] if st[i].size() > 4 else (cu_i if st[i].size() > 3 else cl)
		var s := sin(TAU * k / seg)
		var w := smoothstep(0.45, -0.7, s)
		var c0 := cu_i.lerp(cl_i, w)
		return _vc(c0, i * 3.1 + k * 0.7, 0.025)
	var nrm: Array = []
	for i in n:
		var rn := PackedVector3Array()
		for k in seg:
			var dU: Vector3 = (P[mini(i + 1, n - 1)][k] as Vector3) - (P[maxi(i - 1, 0)][k] as Vector3)
			var dV: Vector3 = (P[i][(k + 1) % seg] as Vector3) - (P[i][(k + seg - 1) % seg] as Vector3)
			var nn := dU.cross(dV)
			var out: Vector3 = (P[i][k] as Vector3) - (CEN[i] as Vector3)
			if nn.length_squared() < 1e-14:
				nn = -(T[i] as Vector3) if i == 0 else (T[i] as Vector3) if i == n - 1 else out
			if nn.dot(out) < 0.0 and out.length_squared() > 1e-10: nn = -nn
			rn.append(nn.normalized())
		nrm.append(rn)
	for i in n - 1:
		for k in seg:
			var k2 := (k + 1) % seg
			var a: Vector3 = P[i][k]; var bb: Vector3 = P[i][k2]; var c: Vector3 = P[i + 1][k2]; var d: Vector3 = P[i + 1][k]
			var na: Vector3 = nrm[i][k]; var nb: Vector3 = nrm[i][k2]; var nc: Vector3 = nrm[i + 1][k2]; var nd: Vector3 = nrm[i + 1][k]
			var ca: Color = colv.call(i, k); var cb: Color = colv.call(i, k2); var cc: Color = colv.call(i + 1, k2); var cd: Color = colv.call(i + 1, k)
			DroneParts._tri(b.pos, b.nrm, b.cols, a, bb, c, na, nb, nc, ca, cb, cc)
			DroneParts._tri(b.pos, b.nrm, b.cols, a, c, d, na, nc, nd, ca, cc, cd)
	for e in 2:
		if not (caps & (1 << e)): continue
		var i := 0 if e == 0 else n - 1
		var nn: Vector3 = -(T[i] as Vector3) if e == 0 else (T[i] as Vector3)
		for k in seg:
			var k2 := (k + 1) % seg
			DroneParts._tri(b.pos, b.nrm, b.cols, CEN[i], P[i][k], P[i][k2], nn, nn, nn, colv.call(i, 0), colv.call(i, k), colv.call(i, k2))

## An ellipsoid (radii rx, ry, rz) centred at c, axes turned by xf's basis; smooth. cl is the underside colour.
static func _ell(b: NewModels2.Buf, c: Vector3, r: Vector3, seg: int, col: Color, cl := Color(-1, 0, 0), xf := Transform3D.IDENTITY) -> void:
	var rings := maxi(4, seg / 2)
	var st: Array = []
	for j in rings + 1:
		var ph := PI * j / rings
		st.append([c + Vector3(0, 0, -r.z * cos(ph)), r.x * sin(ph), r.y * sin(ph)])
	_sweep(b, st, seg, col, cl, xf, Vector3.UP, 0)

## A tapered round limb or stalk along pts (radii r0 to r1, optionally a second radius for an oval), colour col.
static func _limb(b: NewModels2.Buf, pts: Array, r0: float, r1: float, seg: int, col: Color, ovalise := 1.0, col1 := Color(-1, 0, 0), xf := Transform3D.IDENTITY, caps := 3) -> void:
	var st: Array = []
	var n := pts.size()
	for i in n:
		var t := float(i) / (n - 1)
		var r := lerpf(r0, r1, t)
		st.append([pts[i], r, r * ovalise, col.lerp(col1, t) if col1.r >= 0.0 else col])
	_sweep(b, st, seg, col, Color(-1, 0, 0), xf, Vector3.UP, caps)

static func _rot_x(deg: float) -> Basis:
	return Basis(Vector3.RIGHT, deg_to_rad(deg))

static func vn_(q: Vector3) -> float:
	return fposmod(sin(q.x * 311.7 + q.y * 74.7 + q.z * 127.1) * 43758.5453, 1.0)

static func _rnd(i: float, salt := 0.0) -> float:
	return fposmod(sin(i * 12.9898 + salt * 78.233) * 43758.5453, 1.0)

static func _seg(lod: int, big: int, mid: int, far: int) -> int:
	return [big, mid, far][lod]

# ================================================================== four-legged animals
## The torso profile shared by cattle, sheep, horses and dogs, scaled per species: [u (0 rump, 1 chest), rx, ry, how far the top line sits from the back height].
const PROF := [
	[0.00, 0.10, 0.10, -0.12], [0.08, 0.24, 0.25, -0.02], [0.18, 0.29, 0.34, 0.03], [0.33, 0.31, 0.41, 0.0],
	[0.50, 0.31, 0.44, -0.01], [0.66, 0.30, 0.44, 0.0], [0.80, 0.28, 0.42, 0.01], [0.92, 0.22, 0.34, -0.02], [1.0, 0.12, 0.20, -0.05],
]

## Head tables (local frame: poll at the origin, nose toward -z): [z, y, rx, ry]
const HEAD_COW := [[0.0, 0.0, 0.10, 0.10], [-0.10, -0.015, 0.118, 0.125], [-0.22, -0.085, 0.108, 0.135], [-0.33, -0.13, 0.088, 0.105],
	[-0.43, -0.17, 0.079, 0.088], [-0.51, -0.19, 0.092, 0.084], [-0.56, -0.20, 0.099, 0.078], [-0.59, -0.205, 0.088, 0.06]]
const HEAD_HORSE := [[0.0, 0.0, 0.092, 0.135], [-0.15, -0.085, 0.10, 0.145], [-0.35, -0.2, 0.078, 0.105], [-0.55, -0.3, 0.06, 0.078],
	[-0.67, -0.355, 0.066, 0.062], [-0.725, -0.372, 0.052, 0.046]]
const HEAD_SHEEP := [[0.0, 0.0, 0.058, 0.066], [-0.08, -0.03, 0.054, 0.068], [-0.16, -0.075, 0.044, 0.058], [-0.215, -0.11, 0.036, 0.04],
	[-0.24, -0.12, 0.028, 0.028]]
const HEAD_DOG := [[0.0, 0.0, 0.05, 0.055], [-0.07, -0.012, 0.056, 0.062], [-0.13, -0.04, 0.036, 0.04], [-0.20, -0.06, 0.03, 0.03],
	[-0.235, -0.064, 0.022, 0.02]]

static func _head_table(kind: String) -> Array:
	match kind:
		"horse": return HEAD_HORSE
		"sheep": return HEAD_SHEEP
		"dog": return HEAD_DOG
	return HEAD_COW

## A signed-distance field on a grid, built from smoothly blended ellipsoids and round cones, then turned into a smooth mesh (surface nets).
## This is what lets a code-drawn animal have a neck that grows out of its shoulders and a thigh that melts into its flank, instead of boxes.
class Field:
	var o := Vector3.ZERO
	var h := 0.05
	var nx := 1
	var ny := 1
	var nz := 1
	var f := PackedFloat32Array()

	func _init(lo: Vector3, hi: Vector3, cell: float) -> void:
		h = cell
		o = lo - Vector3.ONE * cell * 3.0
		var sz := (hi - lo) / cell
		nx = int(ceil(sz.x)) + 7; ny = int(ceil(sz.y)) + 7; nz = int(ceil(sz.z)) + 7
		f.resize(nx * ny * nz)
		f.fill(1000.0)

	static func smin(a: float, b: float, k: float) -> float:
		if k <= 0.0: return minf(a, b)
		var t := maxf(k - absf(a - b), 0.0) / k
		return minf(a, b) - t * t * k * 0.25

	var tb := [1 << 30, -1, 1 << 30, -1, 1 << 30, -1]     # the cells any shape has touched (so extraction skips the empty rest)

	func _range(lo: Vector3, hi: Vector3) -> Array:
		var a := ((lo - o) / h).floor()
		var b := ((hi - o) / h).ceil()
		var r := [maxi(int(a.x), 0), mini(int(b.x), nx - 1), maxi(int(a.y), 0), mini(int(b.y), ny - 1), maxi(int(a.z), 0), mini(int(b.z), nz - 1)]
		tb[0] = mini(tb[0], r[0]); tb[1] = maxi(tb[1], r[1]); tb[2] = mini(tb[2], r[2]); tb[3] = maxi(tb[3], r[3]); tb[4] = mini(tb[4], r[4]); tb[5] = maxi(tb[5], r[5])
		return r

	## An ellipsoid centred at c with radii r (rotated by bas, an orthonormal basis), blended with what is there by k (k < 0 carves it out).
	func ell(c: Vector3, r: Vector3, k := 0.1, bas := Basis.IDENTITY) -> void:
		var ext := maxf(r.x, maxf(r.y, r.z)) + absf(k) + h * 2.0
		var rg := _range(c - Vector3.ONE * ext, c + Vector3.ONE * ext)
		var inv := bas.transposed()
		var r2 := r * r
		var mr := minf(r.x, minf(r.y, r.z))
		for kk in range(rg[4], rg[5] + 1):
			for j in range(rg[2], rg[3] + 1):
				var base := nx * (j + ny * kk)
				for i in range(rg[0], rg[1] + 1):
					var p := inv * (o + Vector3(i, j, kk) * h - c)
					var k0 := Vector3(p.x / r.x, p.y / r.y, p.z / r.z).length()
					var k1 := Vector3(p.x / r2.x, p.y / r2.y, p.z / r2.z).length()
					var d := k0 * (k0 - 1.0) / maxf(k1, 1e-6) if k0 > 1e-5 else -mr
					if k >= 0.0: f[base + i] = smin(f[base + i], d, k)
					else: f[base + i] = -smin(-f[base + i], d, -k)

	## A round cone from a (radius ra) to b (radius rb).
	func cone(a: Vector3, b: Vector3, ra: float, rb: float, k := 0.08) -> void:
		var ext := maxf(ra, rb) + absf(k) + h * 2.0
		var rg := _range(a.min(b) - Vector3.ONE * ext, a.max(b) + Vector3.ONE * ext)
		var ab := b - a
		var l2 := maxf(ab.length_squared(), 1e-9)
		for kk in range(rg[4], rg[5] + 1):
			for j in range(rg[2], rg[3] + 1):
				var base := nx * (j + ny * kk)
				for i in range(rg[0], rg[1] + 1):
					var p := o + Vector3(i, j, kk) * h
					var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
					var d := (p - (a + ab * t)).length() - lerpf(ra, rb, t)
					if k >= 0.0: f[base + i] = smin(f[base + i], d, k)
					else: f[base + i] = -smin(-f[base + i], d, -k)

	## A chain of round cones through pts with radii rs.
	func chain(pts: Array, rs: Array, k := 0.08) -> void:
		for i in pts.size() - 1: cone(pts[i], pts[i + 1], rs[i], rs[i + 1], k)

	## The surface at zero as smooth triangles (vertex colours from colf(p) -> Color, normals from the field's gradient), into b.
	func extract(b: NewModels2.Buf, colf: Callable, xf := Transform3D.IDENTITY) -> void:
		var vid := PackedInt32Array(); vid.resize(nx * ny * nz); vid.fill(-1)
		var vp := PackedVector3Array(); var vnn := PackedVector3Array(); var vcol := PackedColorArray()
		var dy := nx; var dz := nx * ny
		var co := [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1)]
		var edges := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
		var v := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		var x0 := maxi(tb[0] - 1, 0); var x1 := mini(tb[1] + 1, nx - 2)
		var y0 := maxi(tb[2] - 1, 0); var y1 := mini(tb[3] + 1, ny - 2)
		var z0 := maxi(tb[4] - 1, 0); var z1 := mini(tb[5] + 1, nz - 2)
		for kk in range(z0, z1 + 1):
			for j in range(y0, y1 + 1):
				for i in range(x0, x1 + 1):
					var ix := i + dy * j + dz * kk
					v[0] = f[ix]; v[1] = f[ix + 1]; v[2] = f[ix + dy]; v[3] = f[ix + dy + 1]
					v[4] = f[ix + dz]; v[5] = f[ix + dz + 1]; v[6] = f[ix + dz + dy]; v[7] = f[ix + dz + dy + 1]
					var neg := 0
					for q in 8:
						if v[q] < 0.0: neg += 1
					if neg == 0 or neg == 8: continue
					var acc := Vector3.ZERO; var cnt := 0
					for e in edges:
						var a: float = v[e[0]]; var c: float = v[e[1]]
						if (a < 0.0) != (c < 0.0):
							var t := a / (a - c)
							acc += (co[e[0]] as Vector3).lerp(co[e[1]], t); cnt += 1
					var local := acc / cnt
					var pos := o + (Vector3(i, j, kk) + local) * h
					var g := Vector3(((v[1] - v[0]) + (v[3] - v[2]) + (v[5] - v[4]) + (v[7] - v[6])),
						((v[2] - v[0]) + (v[3] - v[1]) + (v[6] - v[4]) + (v[7] - v[5])),
						((v[4] - v[0]) + (v[5] - v[1]) + (v[6] - v[2]) + (v[7] - v[3])))
					vid[ix] = vp.size()
					var wp := xf * pos
					vp.append(wp); vnn.append((xf.basis * g).normalized() if g.length_squared() > 1e-14 else Vector3.UP)
					vcol.append(colf.call(pos))
		var tri := func(a: int, bb: int, c: int, d: int) -> void:
			if a < 0 or bb < 0 or c < 0 or d < 0: return
			DroneParts._tri(b.pos, b.nrm, b.cols, vp[a], vp[bb], vp[c], vnn[a], vnn[bb], vnn[c], vcol[a], vcol[bb], vcol[c])
			DroneParts._tri(b.pos, b.nrm, b.cols, vp[a], vp[c], vp[d], vnn[a], vnn[c], vnn[d], vcol[a], vcol[c], vcol[d])
		for kk in range(maxi(z0, 1), mini(z1 + 1, nz - 1)):
			for j in range(maxi(y0, 1), mini(y1 + 1, ny - 1)):
				for i in range(maxi(x0, 1), mini(x1 + 1, nx - 1)):
					var ix := i + dy * j + dz * kk
					var s0 := f[ix] < 0.0
					if (f[ix + 1] < 0.0) != s0:
						tri.call(vid[ix - dy - dz], vid[ix - dz], vid[ix], vid[ix - dy])
					if (f[ix + dy] < 0.0) != s0:
						tri.call(vid[ix - 1 - dz], vid[ix - dz], vid[ix], vid[ix - 1])
					if (f[ix + dz] < 0.0) != s0:
						tri.call(vid[ix - 1 - dy], vid[ix - dy], vid[ix], vid[ix - 1])

## The colour of the coat at p (model frame): the back colour fading to the belly colour, the lower legs to the foot colour, the neck to its own colour.
static func _coat_col(S: Dictionary) -> Callable:
	var cu: Color = S["cu"]; var cl: Color = S["cl"]
	var back: float = S["back"]
	var bell: float = back - 0.9 * float(S["yk"])
	var hgt: float = S["hgt"]
	var foot: Color = S["leg_foot"]; var top: Color = S["leg_top"]
	var neckc: Color = S.get("neck_col", cu); var neckl: Color = S.get("neck_col_l", cl)
	var zc: float = S["zc"]
	var lying: bool = S.get("lying", false)
	return func(p: Vector3) -> Color:
		var tt := clampf((p.y - bell) / maxf(back - bell, 0.1), 0.0, 1.0)
		var c := cl.lerp(cu, smoothstep(0.1, 0.6, tt))
		var nw := smoothstep(zc + 0.3, zc - 0.15, p.z)
		c = c.lerp(neckc.lerp(neckl, 1.0 - smoothstep(0.1, 0.6, tt)), nw)
		if not lying:
			var lw := smoothstep(hgt * 0.62, hgt * 0.1, p.y)
			c = c.lerp(top.lerp(foot, lw), smoothstep(hgt * 1.1, hgt * 0.7, p.y) * 0.9)
		else:
			var lw := smoothstep(0.3, 0.06, p.y)
			c = c.lerp(foot, lw * 0.8)
		c = _vc(c, p.x * 17.0 + p.z * 5.0 + p.y * 3.0, 0.03)
		# the alpha is how much fur there is: full on the body, the species' leg_fur below the belly, none on the hoof
		var legw := smoothstep(bell + 0.05, bell - 0.1, p.y)
		c.a = lerpf(1.0, float(S.get("leg_fur", 1.0)), legw)
		if p.y < 0.07: c.a = 0.0
		return c

## One animal from its description S (see the species functions). Parts: body (torso, neck, legs, udder, mane), head, jaw, tail.
static func _quad(p: Parts, S: Dictionary, lod: int) -> void:
	var xf: Transform3D = S.get("xf", Transform3D.IDENTITY)
	var sc: float = xf.basis.get_scale().x
	var mat: String = S["mat"]
	var cell: float = float(S["cell"]) * [1.0, 1.8, 3.4][lod]
	var segs := _seg(lod, 10, 7, 5)
	var rump: float = S["zr"]; var chest: float = S["zc"]
	var back: float = S["back"]
	var yk: float = S["yk"]; var xk: float = S["xk"]
	var kb := 0.13 * xk
	# ---- the field's bounds: generous round the animal
	var lo := Vector3(-0.7 * xk - 0.3, -0.05, minf(chest, S["neck"][S["neck"].size() - 1][0].z) - 0.5)
	var hi := Vector3(0.7 * xk + 0.3, back + 0.5 * yk + 0.6, rump + 0.7)
	p.leg_h = float(S["hgt"]) * sc
	var fld := Field.new(lo, hi, cell)
	# ---- torso: a chain of ellipsoids along the profile
	var rows: Array = PROF
	for q in rows.size():
		var row: Array = rows[q]
		var u: float = row[0]
		var z := lerpf(rump, chest, u)
		var ry: float = float(row[2]) * yk * (1.0 - float(S.get("tuck", 0.0)) * (1.0 - smoothstep(0.0, 0.7, u)))
		var rx: float = float(row[1]) * xk
		var topy: float = back + float(row[3]) * yk
		var gap := absf(lerpf(rump, chest, rows[mini(q + 1, rows.size() - 1)][0]) - lerpf(rump, chest, rows[maxi(q - 1, 0)][0])) * 0.5
		fld.ell(Vector3(0, topy - ry, z), Vector3(rx, ry, maxf(gap * 1.3, 0.09)), 0.13)
	# ---- neck: ellipsoids along its path (deeper than wide), growing out of the shoulders
	var neck: Array = S["neck"]
	for q in neck.size():
		var c: Vector3 = neck[q][0]
		var prev: Vector3 = neck[maxi(q - 1, 0)][0]; var next: Vector3 = neck[mini(q + 1, neck.size() - 1)][0]
		var seglen := (next - prev).length() * 0.5
		var dir := (next - prev).normalized()
		var bas := Basis.looking_at(-dir, Vector3.UP) if absf(dir.y) < 0.95 else Basis.IDENTITY
		fld.ell(c, Vector3(neck[q][1], neck[q][2], maxf(seglen * 1.3, 0.08)), 0.12, bas)
	var poll: Vector3 = neck[neck.size() - 1][0]
	if S["head"] == "cow":
		fld.ell(Vector3(0, float(neck[1][0].y) - 0.2, float(neck[1][0].z) + 0.12), Vector3(0.1, 0.17, 0.28), 0.12)      # the throat and dewlap
	# ---- legs
	_leg_prims(fld, S)
	var colf := _coat_col(S)
	p.part("body")
	fld.extract(p.b(mat), colf, xf)
	# ---- udder and teats (a dairy cow)
	if S.get("udder", false):
		var uz := lerpf(rump, chest, 0.1)
		var ub := back - 0.9 * yk + 0.1
		_ell(p.b("skin"), Vector3(0, ub + 0.0, uz - 0.05), Vector3(0.15, 0.12, 0.2), segs, Color(0.82, 0.62, 0.58), Color(0.78, 0.55, 0.5), xf)
		if lod == 0:
			for tx in [-1.0, 1.0]:
				for tz in [-0.07, 0.07]:
					var tp := Vector3(tx * 0.065, ub - 0.09, uz - 0.05 + tz)
					_limb(p.b("skin"), [tp + Vector3(0, 0.07, 0), tp + Vector3(0, -0.04, 0)], 0.017, 0.013, 5, Color(0.8, 0.58, 0.54), 1.0, Color(-1, 0, 0), xf)
	# ---- head, jaw, tail
	_head(p, S, lod, poll, xf)
	_tail(p, S, lod, xf)
	if S.has("mane"): _mane(p, S, lod, xf)

## The legs as chains of round cones (thigh, stifle, hock, cannon, fetlock, hoof) that blend into the body.
static func _leg_prims(fld: Field, S: Dictionary) -> void:
	var hgt: float = S["hgt"]; var r: float = S["lr"]
	var sc: float = S.get("bend", 1.0)
	var lying: bool = S.get("lying", false)
	for side in [-1.0, 1.0]:
		var fx: float = float(S["fx"]) * side; var hx: float = float(S["hx"]) * side
		var zf: float = S["zf"]; var zh: float = S["zh"]
		var fp: Array; var fr: Array; var hp: Array; var hr: Array
		if lying:
			fp = [Vector3(fx, hgt * 0.8, zf), Vector3(fx * 1.05, 0.15, zf - 0.3 * sc), Vector3(fx * 1.0, 0.09, zf - 0.55 * sc), Vector3(fx * 0.9, 0.06, zf - 0.28 * sc)]
			fr = [r * 1.2, r * 0.75, r * 0.55, r * 0.55]
			hp = [Vector3(hx * 1.0, hgt * 1.2, zh), Vector3(hx * 1.3, 0.2, zh + 0.0), Vector3(hx * 1.4, 0.1, zh + 0.35 * sc), Vector3(hx * 1.3, 0.06, zh - 0.05)]
			hr = [r * 1.7, r * 1.0, r * 0.6, r * 0.55]
		else:
			fp = [Vector3(fx, float(S["ytop"]), zf), Vector3(fx * 0.97, hgt * 0.62, zf - 0.02 * sc), Vector3(fx * 0.94, hgt * 0.32, zf - 0.035 * sc),
				Vector3(fx * 0.92, hgt * 0.13, zf - 0.04 * sc), Vector3(fx * 0.92, 0.045, zf - 0.045 * sc)]
			fr = [r * 1.15, r * 0.78, r * 0.65, r * 0.6, r * 0.66]
			hp = [Vector3(hx, float(S["ytop"]) + 0.03, zh), Vector3(hx * 1.06, hgt * 0.95, zh - 0.13 * sc), Vector3(hx * 0.98, hgt * 0.5, zh + 0.15 * sc),
				Vector3(hx * 0.96, hgt * 0.26, zh + 0.13 * sc), Vector3(hx * 0.96, hgt * 0.11, zh + 0.115 * sc), Vector3(hx * 0.96, 0.045, zh + 0.11 * sc)]
			hr = [r * 1.7, r * 1.25, r * 0.78, r * 0.62, r * 0.6, r * 0.66]
			# thigh and shoulder muscle: a fat ellipsoid over the top of each leg
			fld.ell(Vector3(fx * 1.05, float(S["ytop"]) - 0.12, zf + 0.02), Vector3(r * 1.5, hgt * 0.5, r * 2.0), 0.1)
			fld.ell(Vector3(hx * 1.1, float(S["ytop"]) - 0.05, zh + 0.0), Vector3(r * 1.8, hgt * 0.5, r * 2.6), 0.12)
		fld.chain(fp, fr, 0.06)
		fld.chain(hp, hr, 0.06)

## An eye: a smooth ball with an iris and a pupil painted in vertex colour by the angle from the gaze (so the pupil is a proper slit
## in a cow's, sheep's or horse's eye, round in a dog's), set in dark lid skin. The `eye` material is clear-coated, so the sun leaves a corneal highlight.
static func _eye(b: NewModels2.Buf, c: Vector3, r: Vector3, gaze: Vector3, xf: Transform3D, seg: int, iris: Color, slit: bool) -> void:
	var g := gaze.normalized()
	var up := Vector3.UP
	var right := g.cross(up).normalized()
	var upv := right.cross(g).normalized()
	var rings := maxi(6, seg / 2)
	var P: Array = []
	var N: Array = []
	var C: Array = []
	for i in rings + 1:
		var ph := PI * i / rings
		var prow: Array[Vector3] = []; var nrow: Array[Vector3] = []; var crow: Array[Color] = []
		for j in seg + 1:
			var th := TAU * j / seg
			var u := Vector3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th))
			var pt := xf * (c + u * r)
			prow.append(pt)
			nrow.append((xf.basis * Vector3(u.x / r.x, u.y / r.y, u.z / r.z)).normalized())
			var ang := rad_to_deg(acos(clampf(u.dot(g), -1.0, 1.0)))
			var ux := u.dot(right); var uy := u.dot(upv)
			var col: Color
			if ang > 64.0: col = Color(0.1, 0.08, 0.07)
			elif ang > 40.0: col = Color(0.26, 0.17, 0.1).lerp(Color(0.1, 0.08, 0.07), smoothstep(52.0, 64.0, ang))
			else:
				col = iris.lerp(iris * 0.55, smoothstep(22.0, 40.0, ang))
				var pe := (ux / 0.34) * (ux / 0.34) + (uy / (0.15 if slit else 0.34)) * (uy / (0.15 if slit else 0.34))
				if pe < 1.0: col = Color(0.008, 0.008, 0.008)
			col.a = 1.0
			crow.append(col)
		P.append(prow); N.append(nrow); C.append(crow)
	for i in rings:
		for j in seg:
			var a: Vector3 = P[i][j]; var bb: Vector3 = P[i][j + 1]; var cc: Vector3 = P[i + 1][j + 1]; var d: Vector3 = P[i + 1][j]
			DroneParts._tri(b.pos, b.nrm, b.cols, a, bb, cc, N[i][j], N[i][j + 1], N[i + 1][j + 1], C[i][j], C[i][j + 1], C[i + 1][j + 1])
			DroneParts._tri(b.pos, b.nrm, b.cols, a, cc, d, N[i][j], N[i + 1][j + 1], N[i + 1][j], C[i][j], C[i + 1][j + 1], C[i + 1][j])

## What a head is made of, in the head's own frame (poll at the origin, the nose toward -z, y up): shapes ["e", centre, radii, k] (ellipsoid) and
## ["c", a, b, ra, rb, k] (round cone), the eye's place and size, the tip of the nose, the jaw's hinge and chin, and the lower jaw's radii.
static func _head_def(kind: String) -> Dictionary:
	match kind:
		"horse":
			return {"prims": [["e", Vector3(0, 0.0, -0.1), Vector3(0.10, 0.12, 0.13), 0.04], ["e", Vector3(0, 0.005, -0.2), Vector3(0.095, 0.08, 0.09), 0.04],
				["e", Vector3(0, -0.15, -0.17), Vector3(0.095, 0.15, 0.19), 0.05],
				["c", Vector3(0, -0.1, -0.25), Vector3(0, -0.3, -0.56), 0.085, 0.056, 0.04], ["e", Vector3(0, -0.335, -0.62), Vector3(0.066, 0.058, 0.08), 0.03],
				["e", Vector3(0, 0.05, -0.05), Vector3(0.05, 0.03, 0.05), 0.03]],
				"eye": Vector3(0.098, 0.015, -0.2), "eye_r": 0.024, "tip": [Vector3(0, -0.335, -0.7), 0.066, 0.058], "nostril": Vector3(0.035, -0.325, -0.695),
				"muzzle_z": -0.665, "jaw": [Vector3(0, -0.2, -0.2), Vector3(0, -0.375, -0.58), 0.08, 0.042], "stub": 0.15}
		"sheep":
			return {"prims": [["e", Vector3(0, 0.0, -0.05), Vector3(0.056, 0.066, 0.078), 0.03], ["e", Vector3(0, 0.012, -0.1), Vector3(0.058, 0.04, 0.05), 0.025],
				["e", Vector3(0, -0.06, -0.08), Vector3(0.05, 0.065, 0.085), 0.03],
				["c", Vector3(0, -0.035, -0.1), Vector3(0, -0.1, -0.2), 0.046, 0.034, 0.03], ["e", Vector3(0, -0.108, -0.212), Vector3(0.034, 0.031, 0.034), 0.02]],
				"eye": Vector3(0.05, 0.012, -0.095), "eye_r": 0.015, "tip": [Vector3(0, -0.108, -0.245), 0.034, 0.031], "nostril": Vector3(0.014, -0.104, -0.243),
				"muzzle_z": -0.222, "jaw": [Vector3(0, -0.075, -0.09), Vector3(0, -0.12, -0.215), 0.03, 0.02], "stub": 0.09}
		"dog":
			return {"prims": [["e", Vector3(0, 0.0, -0.05), Vector3(0.052, 0.06, 0.07), 0.025], ["e", Vector3(0, 0.012, -0.095), Vector3(0.05, 0.036, 0.04), 0.02],
				["e", Vector3(0, -0.03, -0.06), Vector3(0.05, 0.05, 0.065), 0.02],
				["c", Vector3(0, -0.02, -0.1), Vector3(0, -0.045, -0.19), 0.036, 0.024, 0.02], ["e", Vector3(0, -0.05, -0.2), Vector3(0.021, 0.018, 0.022), 0.015]],
				"eye": Vector3(0.037, 0.014, -0.09), "eye_r": 0.0105, "tip": [Vector3(0, -0.05, -0.22), 0.021, 0.018], "nostril": Vector3(0.008, -0.048, -0.218),
				"muzzle_z": -0.205, "jaw": [Vector3(0, -0.04, -0.085), Vector3(0, -0.07, -0.19), 0.026, 0.016], "stub": 0.07}
	return {"prims": [["e", Vector3(0, -0.02, -0.07), Vector3(0.105, 0.115, 0.115), 0.04], ["e", Vector3(0, 0.0, -0.16), Vector3(0.108, 0.07, 0.07), 0.04],
		["e", Vector3(0, -0.13, -0.14), Vector3(0.096, 0.125, 0.14), 0.05],
		["c", Vector3(0, -0.04, -0.2), Vector3(0, -0.15, -0.43), 0.09, 0.076, 0.04], ["e", Vector3(0, -0.19, -0.465), Vector3(0.09, 0.077, 0.066), 0.03],
		["e", Vector3(0.0, 0.05, -0.045), Vector3(0.06, 0.03, 0.05), 0.03]],
		"eye": Vector3(0.104, 0.0, -0.15), "eye_r": 0.021, "tip": [Vector3(0, -0.19, -0.52), 0.088, 0.075], "nostril": Vector3(0.04, -0.18, -0.524),
		"muzzle_z": -0.495, "jaw": [Vector3(0, -0.17, -0.16), Vector3(0, -0.255, -0.44), 0.075, 0.046], "stub": 0.2}

## The head, eyes, ears, nose and jaw of S, at the poll. Parts: head (pivot at the poll), jaw (pivot at its hinge).
static func _head(p: Parts, S: Dictionary, lod: int, poll: Vector3, xf: Transform3D) -> void:
	var def := _head_def(S["head"])
	var hs: float = S.get("hs", 1.0)
	var hb := Basis(Vector3.UP, deg_to_rad(float(S.get("yaw", 0.0)))) * Basis(Vector3.RIGHT, -deg_to_rad(float(S.get("pitch", 30.0))))
	var hw: float = S.get("hw", 1.0)
	var hx := xf * Transform3D(hb * Basis.from_scale(Vector3(hs * hw, hs, hs)), poll)
	var mat: String = S["mat"]
	var hc: Color = S["head_col"]; var hl: Color = S.get("head_col_l", hc)
	var sc: float = xf.basis.get_scale().x * hs
	var cell: float = float(S["cell"]) * 0.5 * [1.0, 1.8, 3.2][lod] / hs
	p.part("head", xf * poll)
	var hfld := Field.new(Vector3(-0.3, -0.5, -0.85), Vector3(0.3, 0.3, 0.3), cell)
	for pr in def["prims"]:
		if pr[0] == "e":
			hfld.ell(pr[1], pr[2], pr[3])
		else:
			hfld.cone(pr[1], pr[2], pr[3], pr[4], pr[5])
	# a stub of neck behind the poll, hidden inside the body's own neck, so there is no gap whatever the head's angle
	var stub: float = def["stub"]
	hfld.cone(Vector3(0, -0.02, 0.0), Vector3(0, 0.0, stub), 0.1 * (0.5 + stub * 2.0), 0.11 * (0.5 + stub * 2.0), 0.06)
	# eye sockets (the bulge round each eye), nostrils carved out of the nose
	var ep: Vector3 = def["eye"]
	for sx in [-1.0, 1.0]:
		hfld.ell(Vector3(sx * ep.x * 0.9, ep.y, ep.z), Vector3(def["eye_r"] * 1.7, def["eye_r"] * 1.7, def["eye_r"] * 1.9), 0.02)
		hfld.ell(Vector3(sx * float(def["nostril"].x), def["nostril"].y, def["nostril"].z), Vector3(def["tip"][1] * 0.2, def["tip"][2] * 0.2, 0.025), -0.01)
	var head_fur: float = S.get("head_fur", 1.0)
	var muzzle_z: float = def["muzzle_z"]
	var pad: Color = S.get("nose_col", Color(0.55, 0.4, 0.38))
	var hcol := func(q: Vector3) -> Color:
		var c := hc.lerp(hl, smoothstep(-0.08, -0.3, q.y) * 0.6)
		c = _vc(c, q.x * 31.0 + q.z * 11.0, 0.03)
		c.a = head_fur
		var mz := smoothstep(muzzle_z + 0.01, muzzle_z - 0.03, q.z)       # the front of the muzzle is bare, wet skin
		if mz > 0.5:
			c = pad.lerp(pad * 0.8, vn_(q))
			c.a = 0.07
		return c
	hfld.extract(p.b(mat), hcol, hx)
	var tip: Array = def["tip"]
	if lod < 2:
		# eyes: glossy black, set into the brow
		var er: float = def["eye_r"]
		for sx in [-1.0, 1.0]:
			_eye(p.b("eye"), Vector3(sx * ep.x, ep.y, ep.z), Vector3(er * 0.8, er * 0.92, er), Vector3(sx, 0.05, -0.5), hx, _seg(lod, 22, 14, 8), S.get("iris", Color(0.4, 0.25, 0.1)), S["head"] != "dog")
		_ears(p, S, hx, lod)
		if S.get("horns", false):
			for sx in [-1.0, 1.0]:
				var hp: Array = [Vector3(sx * 0.07, 0.07, -0.05), Vector3(sx * 0.13, 0.095, -0.05), Vector3(sx * 0.19, 0.14, -0.04), Vector3(sx * 0.215, 0.205, -0.02)]
				var hr := [0.032, 0.026, 0.018, 0.006]
				var hst: Array = []
				for i in 4: hst.append([hp[i], hr[i], hr[i], Color(0.78, 0.74, 0.62) if i < 3 else Color(0.18, 0.15, 0.12)])
				_sweep(p.b("horn"), hst, _seg(lod, 8, 6, 4), Color(0.78, 0.74, 0.62), Color(-1, 0, 0), hx, Vector3.UP, 2)
	# the lower jaw: a field of its own, so it can open and close about the hinge
	var jd: Array = def["jaw"]
	p.part("jaw", hx * (jd[0] as Vector3))
	var jfld := Field.new(Vector3(-0.2, -0.45, -0.7), Vector3(0.2, 0.1, 0.1), cell)
	jfld.cone(jd[0], (jd[0] as Vector3).lerp(jd[1], 0.5) + Vector3(0, -0.01, 0), float(jd[2]), float(jd[2]) * 0.9, 0.03)
	jfld.cone((jd[0] as Vector3).lerp(jd[1], 0.5) + Vector3(0, -0.01, 0), jd[1], float(jd[2]) * 0.9, float(jd[3]), 0.03)
	var jcol := func(q: Vector3) -> Color:
		var c := _vc(hl, q.x * 31.0 + q.z * 11.0, 0.03)
		c.a = head_fur
		return c
	jfld.extract(p.b(mat), jcol, hx)
	p.part("body")

static func _ears(p: Parts, S: Dictionary, hx: Transform3D, lod: int) -> void:
	var kind: String = S["head"]
	var mat: String = S["mat"]
	var ec: Color = S.get("ear_col", S["head_col"])
	var seg := _seg(lod, 8, 6, 4)
	for sx in [-1.0, 1.0]:
		var pts: Array = []
		var wid: Array = []
		var th: Array = []
		var n := 5
		for i in n:
			var t := float(i) / (n - 1)
			var leaf := sin(PI * pow(t, 0.7)) * 0.85 + 0.15 * (1.0 - t)
			match kind:
				"horse":
					pts.append(Vector3(sx * (0.055 + 0.01 * t), 0.09 + 0.2 * t, -0.2 - 0.04 * t)); wid.append(0.045 * leaf); th.append(0.014 * (1.0 - 0.3 * t))
				"sheep":
					pts.append(Vector3(sx * (0.05 + 0.15 * t), 0.0 - 0.02 * t, -0.03 + 0.0 * t)); wid.append(0.035 * leaf); th.append(0.01)
				"dog":
					pts.append(Vector3(sx * (0.04 + 0.06 * t), 0.045 + 0.03 * sin(t * 2.0) - 0.05 * t * t, -0.03 - 0.02 * t)); wid.append(0.026 * leaf); th.append(0.008)
				_:
					pts.append(Vector3(sx * (0.1 + 0.2 * t), 0.035 - 0.05 * t * t, -0.07 - 0.02 * t)); wid.append(0.07 * leaf); th.append(0.011 * (1.0 - 0.3 * t))
		var st: Array = []
		for i in n: st.append([pts[i], maxf(float(wid[i]), 0.004), float(th[i]), ec])
		var up := Vector3.UP
		_sweep(p.b(mat), st, seg, ec, Color(-1, 0, 0), hx, up, 2)

static func _tail(p: Parts, S: Dictionary, lod: int, xf: Transform3D) -> void:
	if not S.has("tail"): return
	var tl: Array = S["tail"]
	var root: Vector3 = tl[0][0]
	p.part("tail", xf * root)
	var st: Array = []
	for i in tl.size(): st.append([tl[i][0], tl[i][1], tl[i][1] * float(S.get("tail_flat", 1.0)), S.get("tail_col", S["cu"])])
	_sweep(p.b(S["mat"]), st, _seg(lod, 8, 6, 4), S["cu"], Color(-1, 0, 0), xf, Vector3.UP, 3)
	if S.has("tuft") and lod < 2:
		var t: Array = S["tuft"]
		_ell(p.b(S["mat"]), t[0], t[1], _seg(lod, 10, 6, 4), t[2], Color(-1, 0, 0), xf)
	p.part("body")

## A horse's mane (locks along the crest) and the long tail hair, as thin tapering strands.
static func _mane(p: Parts, S: Dictionary, lod: int, xf: Transform3D) -> void:
	var m: Dictionary = S["mane"]
	var mat: String = S["mat"]
	var crest: Array = S["neck"]
	var n: int = [22, 10, 5][lod]
	var col: Color = m["col"]
	for i in n:
		var t := (float(i) + 0.5) / n
		var f := t * (crest.size() - 1)
		var i0 := mini(int(f), crest.size() - 2)
		var c0: Vector3 = crest[i0][0]; var c1: Vector3 = crest[i0 + 1][0]
		var ry: float = lerpf(crest[i0][2], crest[i0 + 1][2], f - i0)
		var c := c0.lerp(c1, f - i0) + Vector3(0, ry * 0.98, 0)
		var sway := (_rnd(i, 3.0) - 0.5) * 0.02
		var pts := [c, c + Vector3(0.012 + sway, 0.03, 0.0), c + Vector3(0.05 + sway, 0.0, 0.015), c + Vector3(0.1 + sway * 2.0, -0.12, 0.03)]
		var st: Array = []
		for k in 4: st.append([pts[k], 0.012 * (1.0 - k * 0.2), 0.028 * (1.0 - k * 0.25), col.lerp(col * 0.7, k / 3.0)])
		_sweep(p.b(mat), st, 4 if lod < 2 else 3, col, Color(-1, 0, 0), xf, Vector3.UP, 2)

# ================================================================== species
static func _cattle(p: Parts, name: String, lod: int) -> void:
	var S := {"xk": 1.0, "yk": 1.0, "zr": 1.15, "zc": -1.08, "back": 1.45, "head": "cow", "hs": 1.0, "hgt": 0.6, "lr": 0.112, "bend": 1.0,
		"fx": 0.19, "hx": 0.21, "zf": -0.72, "zh": 0.80, "ytop": 1.0, "cell": 0.075, "eye_r": 0.021, "eye_row": 1, "tail_flat": 1.0}
	match name:
		"cow_a":
			# a Holstein: white with black patches (the shader), pink-grey nose, an udder, head lowered and a little to one side
			S["mat"] = "holstein"
			S["cu"] = Color(0.88, 0.87, 0.84); S["cl"] = Color(0.92, 0.89, 0.85)
			S["head_col"] = Color(0.88, 0.87, 0.84); S["leg_top"] = Color(0.88, 0.87, 0.84); S["leg_foot"] = Color(0.74, 0.7, 0.64)
			S["neck"] = [[Vector3(0, 1.2, -0.7), 0.28, 0.38], [Vector3(0, 1.26, -1.05), 0.23, 0.31], [Vector3(0, 1.32, -1.36), 0.165, 0.21]]
			S["pitch"] = 16.0; S["yaw"] = 14.0; S["hs"] = 0.88; S["hw"] = 1.18; S["udder"] = true; S["nose_col"] = Color(0.62, 0.45, 0.43)
			S["tail"] = [[Vector3(0, 1.36, 1.13), 0.034], [Vector3(0, 1.2, 1.2), 0.03], [Vector3(0, 0.85, 1.24), 0.022], [Vector3(0, 0.5, 1.25), 0.016], [Vector3(0, 0.36, 1.25), 0.014]]
			S["tail_col"] = Color(0.5, 0.48, 0.44)
			S["tuft"] = [Vector3(0, 0.24, 1.25), Vector3(0.05, 0.17, 0.05), Color(0.1, 0.095, 0.09)]
		"cow_b":
			# a Hereford grazing: chestnut with a white face, belly and socks, head down at the grass
			S["mat"] = "hereford"; S["horns"] = true
			S["cu"] = Color(0.42, 0.155, 0.065); S["cl"] = Color(0.86, 0.82, 0.74)
			S["head_col"] = Color(0.86, 0.83, 0.76); S["head_col_l"] = Color(0.86, 0.83, 0.76); S["ear_col"] = Color(0.45, 0.17, 0.08)
			S["leg_top"] = Color(0.5, 0.2, 0.09); S["leg_foot"] = Color(0.84, 0.8, 0.72)
			S["neck"] = [[Vector3(0, 1.2, -0.8), 0.27, 0.34], [Vector3(0, 1.0, -1.18), 0.22, 0.28], [Vector3(0, 0.66, -1.5), 0.155, 0.19]]
			S["neck_col"] = Color(0.46, 0.17, 0.075); S["neck_col_l"] = Color(0.75, 0.68, 0.6)
			S["pitch"] = 66.0; S["yaw"] = 0.0; S["hs"] = 0.88; S["hw"] = 1.18; S["nose_col"] = Color(0.7, 0.5, 0.46); S["eye_r"] = 0.02
			S["tail"] = [[Vector3(0, 1.36, 1.13), 0.034], [Vector3(0, 1.2, 1.2), 0.03], [Vector3(0, 0.85, 1.25), 0.022], [Vector3(0, 0.5, 1.26), 0.016], [Vector3(0, 0.38, 1.26), 0.014]]
			S["tail_col"] = Color(0.44, 0.17, 0.08)
			S["tuft"] = [Vector3(0, 0.26, 1.26), Vector3(0.05, 0.17, 0.05), Color(0.88, 0.85, 0.78)]
		"cow_c":
			# a Jersey lying chewing the cud: fawn, darker face, pale muzzle, head up and turned
			S["mat"] = "jersey"; S["lying"] = true; S["bend"] = 1.0
			S["cu"] = Color(0.52, 0.34, 0.2); S["cl"] = Color(0.68, 0.52, 0.37)
			S["head_col"] = Color(0.34, 0.21, 0.12); S["head_col_l"] = Color(0.44, 0.3, 0.2)
			S["leg_top"] = Color(0.5, 0.32, 0.19); S["leg_foot"] = Color(0.32, 0.2, 0.12)
			S["back"] = 0.98; S["hgt"] = 0.4; S["ytop"] = 0.7
			S["neck"] = [[Vector3(0, 0.78, -0.75), 0.25, 0.32], [Vector3(0, 0.92, -1.05), 0.195, 0.25], [Vector3(0, 1.04, -1.28), 0.145, 0.18]]
			S["pitch"] = 12.0; S["yaw"] = 28.0; S["hs"] = 0.88; S["hw"] = 1.18; S["nose_col"] = Color(0.78, 0.62, 0.56); S["udder"] = false
			S["tail"] = [[Vector3(0, 0.92, 1.13), 0.032], [Vector3(0.06, 0.8, 1.22), 0.028], [Vector3(0.22, 0.5, 1.2), 0.02], [Vector3(0.3, 0.3, 1.0), 0.016]]
			S["tail_col"] = Color(0.4, 0.26, 0.15)
			S["tuft"] = [Vector3(0.3, 0.2, 0.92), Vector3(0.045, 0.045, 0.14), Color(0.12, 0.09, 0.07)]
		"calf_a":
			# a Holstein calf: about 0.9 m at the shoulder, big head, long legs, standing
			S["mat"] = "holstein"
			S["cu"] = Color(0.88, 0.87, 0.84); S["cl"] = Color(0.92, 0.89, 0.85)
			S["head_col"] = Color(0.88, 0.87, 0.84); S["leg_top"] = Color(0.88, 0.87, 0.84); S["leg_foot"] = Color(0.74, 0.7, 0.64)
			S["xk"] = 0.88; S["yk"] = 0.84; S["back"] = 1.5; S["hgt"] = 0.78; S["ytop"] = 1.08; S["lr"] = 0.088; S["hs"] = 1.12
			S["fx"] = 0.17; S["hx"] = 0.19
			S["neck"] = [[Vector3(0, 1.28, -0.75), 0.22, 0.28], [Vector3(0, 1.34, -1.1), 0.17, 0.22], [Vector3(0, 1.38, -1.3), 0.13, 0.165]]
			S["pitch"] = 26.0; S["yaw"] = -10.0; S["nose_col"] = Color(0.7, 0.52, 0.5); S["eye_r"] = 0.024
			S["tail"] = [[Vector3(0, 1.4, 1.13), 0.028], [Vector3(0, 1.26, 1.2), 0.024], [Vector3(0, 0.95, 1.24), 0.018], [Vector3(0, 0.62, 1.25), 0.014]]
			S["tail_col"] = Color(0.5, 0.48, 0.44)
			S["tuft"] = [Vector3(0, 0.5, 1.25), Vector3(0.04, 0.12, 0.04), Color(0.1, 0.095, 0.09)]
			S["xf"] = Transform3D(Basis.from_scale(Vector3.ONE * 0.62), Vector3.ZERO); S["cell"] = 0.1
	_quad(p, S, lod)

static func _sheep(p: Parts, name: String, lod: int) -> void:
	var S := {"mat": "wool", "xk": 0.86, "yk": 0.54, "zr": 0.46, "zc": -0.42, "back": 0.8, "head": "sheep", "hs": 1.0, "hgt": 0.36, "lr": 0.038,
		"bend": 0.55, "fx": 0.1, "hx": 0.11, "zf": -0.3, "zh": 0.34, "ytop": 0.58, "cell": 0.05, "eye_r": 0.015, "eye_row": 2}
	S["cu"] = Color(0.78, 0.73, 0.64); S["cl"] = Color(0.7, 0.65, 0.57)
	S["leg_fur"] = 0.12; S["head_fur"] = 0.12
	S["neck_col"] = Color(0.78, 0.73, 0.64)
	S["neck"] = [[Vector3(0, 0.7, -0.34), 0.1, 0.125], [Vector3(0, 0.74, -0.5), 0.08, 0.1], [Vector3(0, 0.76, -0.6), 0.062, 0.075]]
	S["tail"] = [[Vector3(0, 0.74, 0.47), 0.026], [Vector3(0, 0.62, 0.5), 0.024], [Vector3(0, 0.5, 0.5), 0.018]]
	S["tail_col"] = Color(0.76, 0.7, 0.62)
	S["ear_col"] = Color(0.78, 0.7, 0.62, 0.12)
	match name:
		"sheep_a":
			# a white-faced ewe standing, head up and alert
			S["head_col"] = Color(0.8, 0.74, 0.66); S["leg_top"] = Color(0.74, 0.68, 0.6); S["leg_foot"] = Color(0.66, 0.6, 0.52)
			S["pitch"] = 28.0; S["yaw"] = 10.0; S["nose_col"] = Color(0.6, 0.45, 0.42)
		"sheep_b":
			# a black-faced Suffolk ewe grazing
			S["head_col"] = Color(0.12, 0.1, 0.09); S["leg_top"] = Color(0.1, 0.085, 0.08); S["leg_foot"] = Color(0.07, 0.06, 0.055)
			S["ear_col"] = Color(0.1, 0.085, 0.08, 0.12); S["nose_col"] = Color(0.18, 0.14, 0.13)
			S["neck"] = [[Vector3(0, 0.7, -0.34), 0.1, 0.125], [Vector3(0, 0.6, -0.5), 0.08, 0.1], [Vector3(0, 0.4, -0.62), 0.062, 0.075]]
			S["pitch"] = 66.0; S["yaw"] = -8.0
		"lamb_a":
			# a lamb, a little over half the size, leggier
			S["head_col"] = Color(0.8, 0.74, 0.66); S["leg_top"] = Color(0.74, 0.68, 0.6); S["leg_foot"] = Color(0.66, 0.6, 0.52)
			S["pitch"] = 20.0; S["yaw"] = 18.0; S["nose_col"] = Color(0.66, 0.5, 0.46); S["hs"] = 1.1; S["hgt"] = 0.44; S["ytop"] = 0.6
			S["xf"] = Transform3D(Basis.from_scale(Vector3.ONE * 0.56), Vector3.ZERO); S["cell"] = 0.07
	_quad(p, S, lod)

static func _horse(p: Parts, name: String, lod: int) -> void:
	var S := {"mat": "horse", "xk": 0.86, "yk": 0.86, "zr": 0.88, "zc": -0.78, "back": 1.5, "head": "horse", "hs": 1.0, "hgt": 0.76, "lr": 0.062,
		"bend": 1.05, "fx": 0.15, "hx": 0.165, "zf": -0.58, "zh": 0.66, "ytop": 1.1, "cell": 0.075, "eye_r": 0.022, "eye_row": 2, "tuck": 0.1, "tail_flat": 1.0}
	var coat: Color; var mane: Color
	if name == "horse_a":
		# a bay standing: dark brown, black mane, tail and lower legs
		coat = Color(0.4, 0.19, 0.085); mane = Color(0.05, 0.04, 0.035)
		S["cl"] = Color(0.46, 0.24, 0.12); S["leg_top"] = Color(0.34, 0.15, 0.065); S["leg_foot"] = Color(0.07, 0.06, 0.05)
		S["neck"] = [[Vector3(0, 1.34, -0.66), 0.19, 0.3], [Vector3(0, 1.55, -0.88), 0.15, 0.25], [Vector3(0, 1.7, -1.1), 0.12, 0.2], [Vector3(0, 1.76, -1.26), 0.1, 0.165]]
		S["pitch"] = 44.0; S["yaw"] = 6.0; S["head_col"] = Color(0.36, 0.165, 0.07); S["nose_col"] = Color(0.12, 0.1, 0.09)
	else:
		# a chestnut grazing: ginger with a flaxen mane and tail, a white blaze and white socks
		coat = Color(0.46, 0.2, 0.07); mane = Color(0.74, 0.6, 0.38)
		S["cl"] = Color(0.5, 0.24, 0.09); S["leg_top"] = Color(0.44, 0.19, 0.065); S["leg_foot"] = Color(0.82, 0.78, 0.7)
		S["neck"] = [[Vector3(0, 1.32, -0.66), 0.19, 0.3], [Vector3(0, 1.28, -0.95), 0.15, 0.25], [Vector3(0, 1.04, -1.2), 0.125, 0.2], [Vector3(0, 0.86, -1.36), 0.1, 0.165]]
		S["pitch"] = 72.0; S["yaw"] = -6.0; S["head_col"] = Color(0.5, 0.22, 0.08); S["nose_col"] = Color(0.5, 0.38, 0.35)
	S["cu"] = coat
	S["mane"] = {"col": mane}
	S["tail"] = []
	var tl: Array = []
	tl.append([Vector3(0, 1.45, 0.86), 0.04]); tl.append([Vector3(0, 1.38, 0.97), 0.045]); tl.append([Vector3(0, 1.1, 1.06), 0.07]); tl.append([Vector3(0, 0.75, 1.08), 0.055]); tl.append([Vector3(0, 0.35, 1.04), 0.04]); tl.append([Vector3(0, 0.12, 1.0), 0.014])
	S["tail"] = tl; S["tail_col"] = mane; S["tail_flat"] = 0.55
	if lod < 2: S["tuft"] = [Vector3(0, 0.55, 1.07), Vector3(0.05, 0.4, 0.045), mane]
	_quad(p, S, lod)

static func _dog(p: Parts, lod: int) -> void:
	# a farm dog, black and white (a collie cross): standing, head alert, tail down with a curl
	var S := {"mat": "hair", "xk": 0.34, "yk": 0.3, "zr": 0.24, "zc": -0.22, "back": 0.55, "head": "dog", "hs": 1.0, "hgt": 0.3, "lr": 0.026,
		"bend": 0.4, "fx": 0.055, "hx": 0.06, "zf": -0.16, "zh": 0.2, "ytop": 0.44, "cell": 0.04, "eye_r": 0.011, "eye_row": 2, "tuck": 0.3}
	S["cu"] = Color(0.1, 0.09, 0.085); S["cl"] = Color(0.8, 0.78, 0.74); S["leg_fur"] = 0.45
	S["head_col"] = Color(0.1, 0.09, 0.085); S["head_col_l"] = Color(0.6, 0.58, 0.54); S["head_fur"] = 0.5; S["leg_top"] = Color(0.7, 0.68, 0.64); S["leg_foot"] = Color(0.88, 0.86, 0.82)
	S["neck_col"] = Color(0.05, 0.045, 0.04); S["neck_col_l"] = Color(0.85, 0.83, 0.78)
	S["neck"] = [[Vector3(0, 0.5, -0.16), 0.055, 0.08], [Vector3(0, 0.56, -0.25), 0.05, 0.068], [Vector3(0, 0.63, -0.33), 0.044, 0.058]]
	S["pitch"] = 18.0; S["yaw"] = 0.0; S["nose_col"] = Color(0.05, 0.04, 0.04); S["ear_col"] = Color(0.1, 0.09, 0.085, 0.5)
	S["tail"] = [[Vector3(0, 0.52, 0.23), 0.02], [Vector3(0, 0.45, 0.34), 0.03], [Vector3(0, 0.3, 0.42), 0.034], [Vector3(0, 0.2, 0.43), 0.026], [Vector3(0, 0.14, 0.39), 0.012]]
	S["tail_col"] = Color(0.1, 0.09, 0.085); S["tail_flat"] = 0.8
	S["tuft"] = [Vector3(0, 0.16, 0.4), Vector3(0.022, 0.05, 0.035), Color(0.9, 0.88, 0.84)]
	_quad(p, S, lod)

## A Rhode Island Red hen standing with her head up, smooth and feathered (a distance field like the mammals): full breast, a back that slopes into the
## tail, a wing folded on each side, thighs, a neck with golden hackles, a comb and wattles, a beak, scaled legs. Parts: body, head (neck and head, pivot at the neck base).
static func _hen(p: Parts, lod: int) -> void:
	var cell: float = [0.016, 0.026, 0.04][lod]
	var red := Color(0.4, 0.15, 0.05); var gold := Color(0.62, 0.3, 0.08); var breast := Color(0.5, 0.21, 0.07); var wing := Color(0.27, 0.09, 0.035)
	p.part("body")
	var f := Field.new(Vector3(-0.2, 0.0, -0.3), Vector3(0.2, 0.34, 0.3), cell)
	f.ell(Vector3(0, 0.2, 0.03), Vector3(0.095, 0.1, 0.165), 0.06)
	f.ell(Vector3(0, 0.19, -0.095), Vector3(0.085, 0.105, 0.095), 0.06)
	f.ell(Vector3(0, 0.25, 0.125), Vector3(0.06, 0.065, 0.1), 0.05)
	for sx in [-1.0, 1.0]:
		f.ell(Vector3(sx * 0.085, 0.2, 0.025), Vector3(0.03, 0.075, 0.14), 0.04)          # the folded wing
		f.ell(Vector3(sx * 0.07, 0.14, 0.05), Vector3(0.04, 0.06, 0.07), 0.04)            # the thigh
	f.cone(Vector3(0, 0.25, -0.1), Vector3(0, 0.3, -0.125), 0.05, 0.042, 0.05)           # the neck base joins the body
	var colf := func(q: Vector3) -> Color:
		var c := red.lerp(breast, smoothstep(-0.02, -0.12, q.z) * smoothstep(0.28, 0.12, q.y))
		c = c.lerp(gold, smoothstep(0.25, 0.3, q.y) * smoothstep(0.0, -0.1, q.z))
		if absf(q.x) > 0.06 and q.y > 0.13 and q.z > -0.06: c = c.lerp(wing, smoothstep(0.06, 0.09, absf(q.x)))
		c = c.lerp(Color(0.08, 0.1, 0.07), smoothstep(0.08, 0.15, q.z) * smoothstep(0.22, 0.27, q.y))   # the saddle darkening toward the tail
		c = _vc(c, q.x * 53.0 + q.z * 19.0, 0.06)
		c.a = 1.0
		return c
	f.extract(p.b("feather"), colf)
	# the tail: curved blades, dark with a green sheen
	for i in (5 if lod == 0 else (3 if lod == 1 else 1)):
		var sx := (i - 2) * 0.022
		var pts: Array = [Vector3(sx * 0.3, 0.27, 0.15), Vector3(sx * 0.9, 0.33, 0.215), Vector3(sx * 1.4, 0.375, 0.28), Vector3(sx * 1.8, 0.37, 0.335)]
		var st: Array = []
		for k in 4: st.append([pts[k], 0.032 * (1.0 - k * 0.18), 0.007, Color(0.06, 0.07, 0.05).lerp(Color(0.12, 0.2, 0.1), k * 0.25)])
		_sweep(p.b("feather"), st, 6 if lod == 0 else 4, Color(0.06, 0.07, 0.05), Color(-1, 0, 0), Transform3D.IDENTITY, Vector3.UP, 2)
	# legs: yellow, scaled shanks and three toes forward
	for sx in [-1.0, 1.0]:
		var leg: Array = [Vector3(sx * 0.045, 0.13, 0.05), Vector3(sx * 0.046, 0.065, 0.055), Vector3(sx * 0.046, 0.012, 0.05)]
		_limb(p.b("horn"), leg, 0.011, 0.008, 5 if lod < 2 else 4, Color(0.78, 0.6, 0.18), 1.0)
		if lod == 0:
			for a in [-0.4, 0.0, 0.4]:
				var d := Vector3(sin(a), 0.0, -cos(a))
				_limb(p.b("horn"), [Vector3(sx * 0.046, 0.01, 0.05), Vector3(sx * 0.046, 0.007, 0.05) + d * 0.035, Vector3(sx * 0.046, 0.005, 0.05) + d * 0.065], 0.006, 0.004, 4, Color(0.74, 0.56, 0.16))
	# neck and head (moves)
	p.part("head", Vector3(0, 0.27, -0.12))
	var hf := Field.new(Vector3(-0.1, 0.22, -0.32), Vector3(0.1, 0.5, 0.0), cell * 0.8)
	hf.cone(Vector3(0, 0.26, -0.1), Vector3(0, 0.34, -0.14), 0.05, 0.034, 0.04)
	hf.cone(Vector3(0, 0.34, -0.14), Vector3(0, 0.395, -0.17), 0.034, 0.028, 0.04)
	hf.ell(Vector3(0, 0.41, -0.19), Vector3(0.028, 0.031, 0.042), 0.03)
	var hcol := func(q: Vector3) -> Color:
		var c := gold.lerp(red, smoothstep(0.37, 0.41, q.y))
		c = _vc(c, q.x * 47.0 + q.y * 23.0, 0.06)
		c.a = 1.0
		return c
	hf.extract(p.b("feather"), hcol)
	_limb(p.b("horn"), [Vector3(0, 0.405, -0.225), Vector3(0, 0.398, -0.24), Vector3(0, 0.392, -0.262)], 0.0125, 0.0035, 5, Color(0.8, 0.66, 0.24), 0.9)
	if lod < 2:
		for i in 4:
			var h := 0.012 + 0.012 * sin(PI * (i + 0.5) / 4.0)
			_ell(p.b("skin"), Vector3(0, 0.442 + h * 0.3, -0.172 - i * 0.012), Vector3(0.006, h, 0.007), 5, Color(0.7, 0.07, 0.05))
		_ell(p.b("skin"), Vector3(0, 0.378, -0.222), Vector3(0.007, 0.014, 0.008), 5, Color(0.7, 0.07, 0.05))
		for sx in [-1.0, 1.0]:
			_eye(p.b("eye"), Vector3(sx * 0.027, 0.416, -0.2), Vector3(0.0055, 0.0065, 0.0065), Vector3(sx, 0.0, -0.3), Transform3D.IDENTITY, 12, Color(0.75, 0.38, 0.05), false)
	p.part("body")


# ================================================================== plain helpers for painted and steel parts
## A box with every face flat; alpha stays as given (the paint shader reads it as wear).
static func _pbox(b: NewModels2.Buf, c: Vector3, bas: Basis, s: Vector3, col: Color, col_top := Color(-1, 0, 0)) -> void:
	var h := s * 0.5
	var p: Array[Vector3] = []
	for k in 8:
		p.append(c + bas * Vector3(h.x * (1.0 if k & 1 else -1.0), h.y * (1.0 if k & 2 else -1.0), h.z * (1.0 if k & 4 else -1.0)))
	var bx := bas.x.normalized(); var by := bas.y.normalized(); var bz := bas.z.normalized()
	var top := col if col_top.r < 0.0 else col_top
	b.quad(p[0], p[4], p[6], p[2], col, -bx); b.quad(p[1], p[3], p[7], p[5], col, bx)
	b.quad(p[0], p[1], p[5], p[4], col, -by); b.quad(p[2], p[6], p[7], p[3], top, by)
	b.quad(p[0], p[2], p[3], p[1], col, -bz); b.quad(p[4], p[5], p[7], p[6], col, bz)

static func _pboxy(b: NewModels2.Buf, c: Vector3, s: Vector3, yaw: float, col: Color, col_top := Color(-1, 0, 0)) -> void:
	_pbox(b, c, Basis(Vector3.UP, yaw), s, col, col_top)

## A cylinder or cone from a to c (radius r0 to r1) with smooth sides. caps: 1 bottom, 2 top, 3 both. Colour (alpha = wear) is kept.
static func _pcyl(b: NewModels2.Buf, a: Vector3, c: Vector3, r0: float, r1: float, seg: int, col: Color, caps := 3, col1 := Color(-1, 0, 0)) -> void:
	var z := c - a
	var L := z.length()
	if L < 1e-6: return
	z /= L
	var hh := Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT
	var x := hh.cross(z).normalized()
	var y := z.cross(x)
	var c1 := col if col1.r < 0.0 else col1
	var ra: Array[Vector3] = []; var rc: Array[Vector3] = []; var dirs: Array[Vector3] = []
	for k in seg:
		var d := x * cos(TAU * k / seg) + y * sin(TAU * k / seg)
		dirs.append(d); ra.append(a + d * r0); rc.append(c + d * r1)
	var slope := (r0 - r1) / L
	for k in seg:
		var k2 := (k + 1) % seg
		var n0 := (dirs[k] + z * slope).normalized(); var n1 := (dirs[k2] + z * slope).normalized()
		DroneParts._tri(b.pos, b.nrm, b.cols, ra[k], ra[k2], rc[k2], n0, n1, n1, col, col, c1)
		DroneParts._tri(b.pos, b.nrm, b.cols, ra[k], rc[k2], rc[k], n0, n1, n0, col, c1, c1)
	if caps & 1:
		for k in seg: DroneParts._tri(b.pos, b.nrm, b.cols, a, ra[k], ra[(k + 1) % seg], -z, -z, -z, col, col, col)
	if caps & 2:
		for k in seg: DroneParts._tri(b.pos, b.nrm, b.cols, c, rc[k], rc[(k + 1) % seg], z, z, z, c1, c1, c1)

## A flat sheet quad a-b-c-d with a given normal (double sided by the caller if wanted).
static func _sheet(b: NewModels2.Buf, a: Vector3, bb: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	var n := (bb - a).cross(c - a).normalized()
	b.quad(a, bb, c, d, col, n)
	b.quad(a, d, c, bb, col, -n)

static func _tab(t: float, arr: Array) -> float:
	if t <= arr[0][0]: return arr[0][1]
	for i in arr.size() - 1:
		if t <= arr[i + 1][0]:
			var u: float = (t - arr[i][0]) / maxf(arr[i + 1][0] - arr[i][0], 1e-6)
			u = u * u * (3.0 - 2.0 * u)
			return lerpf(arr[i][1], arr[i + 1][1], u)
	return arr[arr.size() - 1][1]

# ================================================================== boats
## The rings of a hull: nst stations from the bow (-z) to the stern, each with 2*half+1 points from the port gunwale round the keel to the starboard one.
## spec: L length, B half beam table, D depth-below-water table, H gunwale-above-water table (all [t, value] with t 0 bow to 1 stern).
static func _hull_rings(L: float, Bt: Array, Dt: Array, Ht: Array, nst: int, half: int, round_bilge := 2.0) -> Array:
	var rings: Array = []
	for i in nst:
		var t := float(i) / (nst - 1)
		var z := -L * 0.5 + t * L
		var B := _tab(t, Bt); var D := _tab(t, Dt); var H := _tab(t, Ht)
		var ring: Array[Vector3] = []
		for k in range(-half, half + 1):
			var s := float(k) / half
			var a := absf(s)
			var x := signf(s) * B * pow(a, 0.88)
			var y := -D * (1.0 - pow(a, round_bilge)) + H * pow(a, 7.0) * (1.0 + 0.0) - D * 0.0
			# the gunwale line: keep the ring's ends at exactly H
			if k == half or k == -half: y = H
			ring.append(Vector3(x, y, z))
		rings.append(ring)
	return rings

## Draw the outside of a hull in strakes (planks): each strake is its own smooth strip so the laps between them stay crisp. lap pushes each strake out by that much over the one below.
static func _hull_strakes(b: NewModels2.Buf, rings: Array, half: int, strakes: int, col: Color, lap: float, wear := 0.0, inward := false, vary := 0.04, colfn := Callable()) -> void:
	var nst := rings.size()
	var per := maxi(1, half / strakes)
	for side in [-1, 1]:
		for sk in strakes:
			var k0 := sk * per; var k1 := (sk + 1) * per if sk < strakes - 1 else half
			# ring index from keel (k=0) outwards on this side
			var P: Array = []
			for i in nst:
				var row: Array[Vector3] = []
				for k in range(k0, k1 + 1):
					var v: Vector3 = rings[i][half + side * k]
					# step out along the local outward direction (sideways and down) by the lap
					var out := Vector3(side, -0.35, 0.0).normalized()
					v += out * lap * sk
					row.append(v)
				P.append(row)
			var nc := k1 - k0 + 1
			var N: Array = []
			for i in nst:
				var rn: Array[Vector3] = []
				for q in nc:
					var dU: Vector3 = (P[mini(i + 1, nst - 1)][q] as Vector3) - (P[maxi(i - 1, 0)][q] as Vector3)
					var dV: Vector3 = (P[i][mini(q + 1, nc - 1)] as Vector3) - (P[i][maxi(q - 1, 0)] as Vector3)
					var nn := dU.cross(dV)
					if nn.length_squared() < 1e-12: nn = Vector3(side, 0, 0)
					nn = nn.normalized()
					# outward: away from the hull's centre line, up to the keel being down
					var ref := Vector3(side * 1.0, -0.3, 0.0)
					if nn.dot(ref) < 0.0: nn = -nn
					rn.append(-nn if inward else nn)
				N.append(rn)
			for i in nst - 1:
				for q in nc - 1:
					var base_col: Color = colfn.call(sk, strakes) if colfn.is_valid() else col
					var cc := _vc(base_col, sk * 3.1 + i * 0.7 + side, vary)
					cc.a = wear
					var a: Vector3 = P[i][q]; var bb: Vector3 = P[i][q + 1]; var c: Vector3 = P[i + 1][q + 1]; var d: Vector3 = P[i + 1][q]
					DroneParts._tri(b.pos, b.nrm, b.cols, a, bb, c, N[i][q], N[i][q + 1], N[i + 1][q + 1], cc, cc, cc)
					DroneParts._tri(b.pos, b.nrm, b.cols, a, c, d, N[i][q], N[i + 1][q + 1], N[i + 1][q], cc, cc, cc)

## Close the transom (stern) with a flat plate and the bow stem is left as the point of the rings.
static func _hull_transom(b: NewModels2.Buf, rings: Array, half: int, col: Color) -> void:
	var last: Array = rings[rings.size() - 1]
	var n := Vector3(0, 0, 1)
	var cen := Vector3.ZERO
	for v in last: cen += v
	cen /= last.size()
	for k in last.size() - 1:
		DroneParts._tri(b.pos, b.nrm, b.cols, cen, last[k], last[k + 1], n, n, n, col, col, col)

## A strip of coaming/gunwale along the top edge of a hull (both sides), w wide and h high, from the bow stem to the stern.
static func _gunwale(b: NewModels2.Buf, rings: Array, half: int, w: float, h: float, col: Color) -> void:
	for side in [-1, 1]:
		for i in rings.size() - 1:
			var a: Vector3 = rings[i][half + side * half]; var c: Vector3 = rings[i + 1][half + side * half]
			var inn := Vector3(-side * w, 0, 0)
			var up := Vector3(0, h, 0)
			var p0 := a; var p1 := c
			b.quad(p0 + up, p1 + up, p1 + up + inn, p0 + up + inn, col, Vector3.UP)
			b.quad(p0, p1, p1 + up, p0 + up, col, Vector3(side, 0, 0))
			b.quad(p0 + inn, p0 + inn + up, p1 + inn + up, p1 + inn, col, Vector3(-side, 0, 0))

static func _rowboat(p: Parts, lod: int) -> void:
	# a clinker-built rowing dinghy, 3.8 m by 1.5 m: white-painted strakes, varnished inside with thwarts, floorboards, oars and a rope
	var half: int = [30, 18, 10][lod]
	var nst: int = [26, 14, 8][lod]
	var L := 3.8
	var Bt := [[0.0, 0.0], [0.08, 0.28], [0.22, 0.62], [0.45, 0.76], [0.65, 0.73], [0.85, 0.62], [1.0, 0.5]]
	var Dt := [[0.0, 0.0], [0.08, 0.1], [0.3, 0.2], [0.5, 0.24], [0.75, 0.2], [1.0, 0.13]]
	var Ht := [[0.0, 0.55], [0.15, 0.4], [0.5, 0.3], [0.85, 0.34], [1.0, 0.4]]
	var rings := _hull_rings(L, Bt, Dt, Ht, nst, half, 2.4)
	p.part("body")
	var white := Color(0.88, 0.88, 0.84)
	_hull_strakes(p.b("hull"), rings, half, 6 if lod < 2 else 3, white, 0.008, 0.18)
	_hull_transom(p.b("hull"), rings, half, white)
	# the inside: the same strakes seen from within, in varnished wood (a copy pulled in by the plank thickness)
	var inner: Array = []
	for r in rings:
		var rr: Array[Vector3] = []
		for v in r: rr.append(Vector3(v.x * 0.985 - signf(v.x) * 0.014, v.y + 0.018, v.z))
		inner.append(rr)
	var wood := Color(0.5, 0.36, 0.22)
	_hull_strakes(p.b("wood"), inner, half, 6 if lod < 2 else 3, wood, 0.0, 0.0, true, 0.06)
	_gunwale(p.b("wood"), rings, half, 0.05, 0.035, Color(0.5, 0.33, 0.16))
	# thwarts (seats), floorboards, a stern sheets seat
	var tw := Color(0.58, 0.4, 0.2)
	for zt in [-0.8, 0.0, 0.85]:
		var ti := clampi(int((zt + L * 0.5) / L * (nst - 1)), 0, nst - 1)
		var width := absf((rings[ti][half + half] as Vector3).x) * 1.9 * 0.96
		NewModels3._boxy(p.b("wood"), Vector3(0, -0.07 + 0.12, zt), Vector3(width, 0.03, 0.24), 0.0, tw)
	if lod < 2:
		for i in 6:
			NewModels3._boxy(p.b("wood"), Vector3(0, -0.15, -0.9 + i * 0.35), Vector3(0.44, 0.015, 0.3), 0.0, Color(0.55, 0.38, 0.18))
		# ribs: bent timbers every 20 cm
		for i in 14:
			var zr := -1.3 + i * 0.2
			var ti := clampi(int((zr + L * 0.5) / L * (nst - 1)), 0, nst - 1)
			var bw := absf((rings[ti][half + half] as Vector3).x)
			NewModels3._boxy(p.b("wood"), Vector3(0, -0.2, zr), Vector3(bw * 1.6, 0.02, 0.03), 0.0, Color(0.5, 0.34, 0.16))
	# two oars laid along the thwarts, and a coil of rope in the bow
	if lod < 2:
		for sx in [-1.0, 1.0]:
			var ob := Vector3(sx * 0.2, 0.2, 0.9); var ot := Vector3(sx * 0.3, 0.22, -1.2)
			NewModels3._prism(p.b("wood"), ob, ot, 0.022, 0.018, 6, Color(0.7, 0.58, 0.36), 3, 0.05)
			var bl := Vector3(sx * 0.3, 0.22, -1.2); var bt := Vector3(sx * 0.34, 0.22, -2.0)
			NewModels3._prism(p.b("wood"), bl, bt, 0.015, 0.014, 6, Color(0.66, 0.52, 0.32), 1, 0.05)
			_pbox(p.b("paint_matte"), (bt + bt + Vector3(sx * 0.02, 0, -0.12)) * 0.5 + Vector3(0, 0, -0.05), Basis.IDENTITY, Vector3(0.1, 0.012, 0.28), Color(0.55, 0.38, 0.2, 0.2))

## The mooring and shore pieces.
static func _mooring_post(p: Parts, lod: int) -> void:
	p.part("body")
	var seg := _seg(lod, 12, 8, 5)
	var col := Color(0.42, 0.33, 0.24)
	NewModels3._prism(p.b("wood"), Vector3(0, 0, 0), Vector3(0, 0.92, 0), 0.14, 0.125, seg, col, 3, 0.1)
	NewModels3._prism(p.b("wood"), Vector3(0, 0.92, 0), Vector3(0, 0.97, 0), 0.125, 0.1, seg, Color(0.38, 0.3, 0.22), 2, 0.1)
	if lod < 2:
		# a rope wound four times round the post, and the tail hanging
		var pts: Array = []
		for i in 33:
			var t := float(i) / 32.0
			var a := t * TAU * 4.0
			pts.append(Vector3(cos(a) * 0.15, 0.5 + t * 0.2, sin(a) * 0.15))
		pts.append(Vector3(0.2, 0.45, 0.3)); pts.append(Vector3(0.28, 0.12, 0.5)); pts.append(Vector3(0.45, 0.02, 0.6))
		_limb(p.b("rope"), pts, 0.016, 0.014, 5, Color(0.7, 0.62, 0.45), 1.0, Color(0.55, 0.47, 0.32))
		# an iron ring bolted to the side
		var ring: Array = []
		for i in 13: ring.append(Vector3(0.0, 0.3 + sin(i * TAU / 12.0) * 0.06, -0.15 + cos(i * TAU / 12.0) * 0.06 - 0.06))
		_limb(p.b("steel"), ring, 0.009, 0.009, 5, Color(0.25, 0.24, 0.23), 1.0, Color(0.25, 0.24, 0.23), Transform3D.IDENTITY, 0)

static func _buoy(p: Parts, lod: int) -> void:
	# a channel marker buoy: red and white, a steel cage and a lamp on top; origin at the waterline, half of it below
	p.part("body")
	var seg := _seg(lod, 20, 12, 8)
	var red := Color(0.72, 0.1, 0.07, 0.1); var white := Color(0.9, 0.9, 0.88, 0.1)
	var st: Array = []
	var prof := [[-0.62, 0.0], [-0.55, 0.22], [-0.38, 0.38], [-0.15, 0.46], [0.1, 0.47], [0.28, 0.42], [0.42, 0.3], [0.5, 0.2], [0.52, 0.0]]
	for i in prof.size():
		var y: float = prof[i][0]
		var c := red if (y < -0.2 or y > 0.34) else white
		st.append([Vector3(0, y, 0), prof[i][1], prof[i][1], c])
		# a crisp band edge: repeat the station with the colour of the next band
		if i + 1 < prof.size():
			var yn: float = prof[i + 1][0]
			var cn := red if (yn < -0.2 or yn > 0.34) else white
			if cn != c:
				var ym := (y + yn) * 0.5
				var rm := (float(prof[i][1]) + float(prof[i + 1][1])) * 0.5
				st.append([Vector3(0, ym - 0.001, 0), rm, rm, c]); st.append([Vector3(0, ym + 0.001, 0), rm, rm, cn])
	_sweep(p.b("hull"), st, seg, red, Color(-1, 0, 0), Transform3D.IDENTITY, Vector3.FORWARD, 3)
	var steel := Color(0.35, 0.36, 0.37, 0.2)
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		_pcyl(p.b("paint"), Vector3(cos(a) * 0.1, 0.5, sin(a) * 0.1), Vector3(cos(a) * 0.05, 1.05, sin(a) * 0.05), 0.014, 0.012, 5, steel, 3)
	_pcyl(p.b("paint"), Vector3(0, 1.05, 0), Vector3(0, 1.12, 0), 0.07, 0.07, 10, Color(0.85, 0.85, 0.8, 0.0), 3)
	_ell(p.b("glass"), Vector3(0, 1.17, 0), Vector3(0.08, 0.06, 0.08), 10, Color(1, 0.7, 0.2))
	_pcyl(p.b("steel"), Vector3(0, -0.62, 0), Vector3(0, -1.94, 0), 0.02, 0.02, 4, Color(0.2, 0.2, 0.2), 3)
	if lod < 2:
		var chain: Array = []
		for i in 12: chain.append(Vector3(sin(i * 0.9) * 0.015, -0.62 - i * 0.12, cos(i * 0.9) * 0.015))
		_limb(p.b("steel"), chain, 0.012, 0.012, 4, Color(0.25, 0.22, 0.2))


## A sail: a triangle from tack (luff foot) up to head and out to clew, bellied sideways by `belly` metres; panels run across it in slightly different whites.
static func _sail(b: NewModels2.Buf, tack: Vector3, head: Vector3, clew: Vector3, belly: float, side: float, nu: int, nv: int, col: Color) -> void:
	var span := head - tack
	var out := (clew - tack)
	var pn := span.cross(out).normalized() * side
	var P: Array = []
	for i in nu + 1:
		var a := float(i) / nu
		var row: Array[Vector3] = []
		for j in nv + 1:
			var c := float(j) / nv
			var l := tack.lerp(head, a)
			var r := clew.lerp(head, a)
			var pt := l.lerp(r, c) + pn * (belly * 4.0 * c * (1.0 - c) * (1.0 - a * 0.55) * (0.4 + 0.6 * (1.0 - absf(a - 0.35))))
			row.append(pt)
		P.append(row)
	for i in nu:
		for j in nv:
			var a: Vector3 = P[i][j]; var bb: Vector3 = P[i][j + 1]; var c: Vector3 = P[i + 1][j + 1]; var d: Vector3 = P[i + 1][j]
			var n := (bb - a).cross(d - a).normalized()
			if n.length_squared() < 0.5: n = (c - a).cross(d - a).normalized()
			var cc := col * (0.96 + 0.06 * fposmod(float(i) * 0.5, 1.0) * (1.0 if i % 2 == 0 else 0.0))
			cc.a = 1.0
			b.quad(a, bb, c, d, cc, n)
			b.quad(a, d, c, bb, cc, -n)

## A mast: a tube with a head fitting.
static func _mast(b: NewModels2.Buf, base: Vector3, top: Vector3, r: float, seg: int) -> void:
	_pcyl(b, base, top, r * 1.15, r * 0.8, seg, Color(0.75, 0.76, 0.78, 0.12), 3)

static func _sailboat_a(p: Parts, lod: int) -> void:
	# a single-handed sailing dinghy, 4.2 m: white glass-fibre hull and deck, cockpit, aluminium mast and boom, a bellied mainsail, rudder and tiller
	var half: int = [26, 16, 8][lod]
	var nst: int = [24, 12, 7][lod]
	var L := 4.2
	var Bt := [[0.0, 0.0], [0.06, 0.2], [0.2, 0.46], [0.45, 0.62], [0.7, 0.62], [0.9, 0.55], [1.0, 0.5]]
	var Dt := [[0.0, 0.0], [0.1, 0.06], [0.4, 0.14], [0.7, 0.13], [1.0, 0.1]]
	var Ht := [[0.0, 0.42], [0.2, 0.3], [0.55, 0.27], [1.0, 0.3]]
	var rings := _hull_rings(L, Bt, Dt, Ht, nst, half, 2.6)
	p.part("body")
	var white := Color(0.92, 0.92, 0.9)
	_hull_strakes(p.b("hull"), rings, half, 4, white, 0.0, 0.1, false, 0.015)
	_hull_transom(p.b("hull"), rings, half, white)
	# the deck: a plate between the gunwales over the bow third and a coaming round a cockpit
	var deck := p.b("hull")
	var dc := Color(0.9, 0.9, 0.87, 0.08)
	for i in nst - 1:
		var t0: float = float(i) / float(nst - 1)
		var a: Vector3 = rings[i][0]; var bq: Vector3 = rings[i][half * 2]; var c: Vector3 = rings[i + 1][half * 2]; var d: Vector3 = rings[i + 1][0]
		if t0 < 0.4:
			deck.quad(a, d, c, bq, dc, Vector3.UP)
		else:
			# cockpit coaming: two side decks 0.18 wide each side and the aft deck last 15 %
			var w := 0.22
			var ai := Vector3(a.x * 0.0, 0, 0)
			var al := a + Vector3(w, 0, 0); var dl := d + Vector3(w, 0, 0)
			var ar := bq - Vector3(w, 0, 0); var cr := c - Vector3(w, 0, 0)
			deck.quad(a, d, dl, al, dc, Vector3.UP); deck.quad(ar, cr, c, bq, dc, Vector3.UP)
			# the cockpit floor
			NewModels3._boxy(p.b("wood"), Vector3(0, -0.04, (a.z + d.z) * 0.5), Vector3(maxf(absf(a.x) * 2.0 - 2.0 * w - 0.04, 0.1), 0.02, absf(d.z - a.z)), 0.0, Color(0.55, 0.42, 0.26))
	_gunwale(p.b("hull"), rings, half, 0.04, 0.03, Color(0.85, 0.85, 0.83, 0.1))
	# mast, boom, sail
	var mz := -L * 0.5 + 1.15
	_mast(p.b("paint"), Vector3(0, 0.15, mz), Vector3(0, 5.8, mz), 0.032, 8 if lod < 2 else 5)
	var boom_y := 0.7
	var boom_end := Vector3(0, boom_y + 0.1, mz + 2.5)
	_pcyl(p.b("paint"), Vector3(0, boom_y, mz + 0.05), boom_end, 0.022, 0.022, 6, Color(0.72, 0.73, 0.75, 0.12), 3)
	_sail(p.b("cloth"), Vector3(0.03, boom_y + 0.04, mz + 0.05), Vector3(0.03, 5.7, mz), Vector3(0.03, boom_y + 0.14, mz + 2.45), 0.28, 1.0, 10 if lod < 2 else 4, 8 if lod < 2 else 3, Color(0.94, 0.93, 0.88))
	if lod < 2:
		# a numeral stripe on the sail, a red cap and the rudder and tiller
		_sail(p.b("cloth"), Vector3(0.032, 3.7, mz + 0.02), Vector3(0.032, 4.6, mz + 0.0), Vector3(0.032, 3.85, mz + 0.5), 0.04, 1.0, 1, 1, Color(0.7, 0.12, 0.1))
		_pboxy(p.b("hull"), Vector3(0, -0.15, L * 0.5 + 0.05), Vector3(0.05, 0.7, 0.35), 0.0, Color(0.75, 0.75, 0.73, 0.1))
		_pcyl(p.b("paint"), Vector3(0, 0.3, L * 0.5 - 0.12), Vector3(0, 0.38, L * 0.5 - 1.1), 0.014, 0.012, 5, Color(0.55, 0.38, 0.2, 0.1), 3)
		# the centreboard poking out and a mainsheet line
		_pboxy(p.b("hull"), Vector3(0, -0.25, mz + 0.9), Vector3(0.025, 0.5, 0.7), 0.0, Color(0.55, 0.56, 0.58, 0.2))
		_limb(p.b("rope"), [Vector3(0, boom_y + 0.08, mz + 2.2), Vector3(0.02, 0.5, mz + 2.0), Vector3(0.04, 0.2, mz + 1.9)], 0.007, 0.007, 4, Color(0.2, 0.2, 0.22))

static func _sailboat_b(p: Parts, lod: int) -> void:
	# a 7.6 m cruising sloop: white hull with a dark blue stripe and red antifouling below, a doghouse cabin, teak cockpit, mast and boom, mainsail and jib, fin keel
	var half: int = [28, 16, 8][lod]
	var nst: int = [30, 16, 8][lod]
	var L := 7.6
	var Bt := [[0.0, 0.0], [0.05, 0.25], [0.18, 0.78], [0.45, 1.3], [0.7, 1.32], [0.9, 1.15], [1.0, 1.0]]
	var Dt := [[0.0, 0.1], [0.12, 0.3], [0.4, 0.55], [0.7, 0.55], [1.0, 0.4]]
	var Ht := [[0.0, 1.0], [0.2, 0.85], [0.5, 0.78], [0.8, 0.82], [1.0, 0.86]]
	var rings := _hull_rings(L, Bt, Dt, Ht, nst, half, 2.2)
	p.part("body")
	var hullcol := func(sk: int, n: int) -> Color:
		if sk < 2: return Color(0.5, 0.12, 0.08, 0.15)           # antifouling
		if sk == n - 2: return Color(0.08, 0.14, 0.32, 0.05)    # the boot stripe is a sheer stripe: dark blue
		return Color(0.93, 0.93, 0.91, 0.05)
	_hull_strakes(p.b("hull"), rings, half, 8, Color(0.93, 0.93, 0.91), 0.0, 0.05, false, 0.012, hullcol)
	_hull_transom(p.b("hull"), rings, half, Color(0.9, 0.9, 0.88, 0.05))
	var teak := Color(0.5, 0.33, 0.17)
	# the deck: plank-coloured side decks and a cabin trunk
	for i in nst - 1:
		var a: Vector3 = rings[i][0]; var bq: Vector3 = rings[i][half * 2]; var c: Vector3 = rings[i + 1][half * 2]; var d: Vector3 = rings[i + 1][0]
		var dcol := Color(0.9, 0.9, 0.87, 0.05)
		p.b("hull").quad(a, d, c, bq, dcol, Vector3.UP)
	_gunwale(p.b("wood"), rings, half, 0.05, 0.05, teak)
	var cab_z0 := -L * 0.5 + 2.4; var cab_z1 := -L * 0.5 + 5.0
	_pboxy(p.b("hull"), Vector3(0, 0.98, (cab_z0 + cab_z1) * 0.5), Vector3(1.7, 0.42, cab_z1 - cab_z0), 0.0, Color(0.92, 0.92, 0.89, 0.05), Color(0.92, 0.92, 0.89, 0.05))
	_pboxy(p.b("hull"), Vector3(0, 1.22, (cab_z0 + cab_z1) * 0.5 + 0.1), Vector3(1.3, 0.1, cab_z1 - cab_z0 - 0.4), 0.0, Color(0.9, 0.9, 0.87, 0.05))
	for sx in [-1.0, 1.0]:
		for k in 3:
			var wz := cab_z0 + 0.55 + k * 0.7
			_pboxy(p.b("glass"), Vector3(sx * 0.86, 1.0, wz), Vector3(0.02, 0.2, 0.5), 0.0, Color(0.05, 0.07, 0.1))
	# cockpit: a teak floor and coamings, a wheel
	NewModels3._boxy(p.b("wood"), Vector3(0, 0.52, (cab_z1 + L * 0.5) * 0.5 - 0.1), Vector3(1.2, 0.04, L * 0.5 - cab_z1 - 0.2), 0.0, teak)
	for sx in [-1.0, 1.0]: NewModels3._boxy(p.b("wood"), Vector3(sx * 0.66, 0.78, (cab_z1 + L * 0.5) * 0.5 - 0.1), Vector3(0.07, 0.3, L * 0.5 - cab_z1 - 0.2), 0.0, teak)
	if lod < 2:
		_pcyl(p.b("steel"), Vector3(0, 0.55, L * 0.5 - 1.0), Vector3(0, 1.0, L * 0.5 - 1.0), 0.04, 0.04, 6, Color(0.55, 0.55, 0.56), 3)
		var wheel: Array = []
		for i in 25: wheel.append(Vector3(cos(i * TAU / 24.0) * 0.3, 1.0 + sin(i * TAU / 24.0) * 0.3, L * 0.5 - 1.0))
		_limb(p.b("wood"), wheel, 0.016, 0.016, 5, Color(0.5, 0.33, 0.17), 1.0, Color(-1, 0, 0), Transform3D.IDENTITY, 0)
	# keel fin and rudder
	_pboxy(p.b("mudpaint"), Vector3(0, -1.0, 0.2), Vector3(0.07, 0.9, 1.4), 0.0, Color(0.14, 0.14, 0.16, 0.3))
	_pboxy(p.b("mudpaint"), Vector3(0, -0.45, L * 0.5 - 0.3), Vector3(0.05, 0.7, 0.5), 0.0, Color(0.5, 0.12, 0.08, 0.3))
	# mast, boom, rigging, mainsail and jib
	var mz := -L * 0.5 + 3.0
	_mast(p.b("paint"), Vector3(0, 1.2, mz), Vector3(0, 10.2, mz), 0.06, 10 if lod < 2 else 6)
	var by := 1.75
	var bend := Vector3(0, by + 0.15, mz + 3.4)
	_pcyl(p.b("paint"), Vector3(0, by, mz + 0.1), bend, 0.04, 0.035, 8, Color(0.75, 0.76, 0.78, 0.1), 3)
	_sail(p.b("cloth"), Vector3(0.05, by + 0.06, mz + 0.1), Vector3(0.05, 9.9, mz), Vector3(0.05, by + 0.2, mz + 3.3), 0.42, 1.0, 14 if lod < 2 else 5, 10 if lod < 2 else 3, Color(0.95, 0.94, 0.9))
	var jib_tack := Vector3(0, 0.95, -L * 0.5 + 0.2)
	_sail(p.b("cloth"), jib_tack, Vector3(0, 9.0, mz - 0.1), Vector3(0.02, 1.4, mz + 0.1), 0.35, -1.0, 12 if lod < 2 else 4, 8 if lod < 2 else 3, Color(0.95, 0.94, 0.9))
	if lod < 2:
		# stays and shrouds as thin cylinders
		for sx in [-1.0, 1.0]:
			_pcyl(p.b("steel"), Vector3(0, 9.6, mz), Vector3(sx * 1.2, 0.95, mz + 0.05), 0.007, 0.007, 4, Color(0.6, 0.6, 0.62), 3)
		_pcyl(p.b("steel"), Vector3(0, 9.7, mz), jib_tack + Vector3(0, 0.02, 0), 0.007, 0.007, 4, Color(0.6, 0.6, 0.62), 3)
		_pcyl(p.b("steel"), Vector3(0, 9.6, mz), Vector3(0, 0.95, L * 0.5 - 0.05), 0.007, 0.007, 4, Color(0.6, 0.6, 0.62), 3)
		# a bow roller and pulpit rail
		for sx in [-1.0, 1.0]: _pcyl(p.b("steel"), Vector3(sx * 0.3, 0.98, -L * 0.5 + 0.8), Vector3(sx * 0.3, 1.5, -L * 0.5 + 0.8), 0.012, 0.012, 5, Color(0.7, 0.7, 0.72), 3)

static func _fishing_boat(p: Parts, lod: int) -> void:
	# a 6.8 m wooden-looking workboat painted blue and white: flared bow, wheelhouse, mast with a derrick boom, floats, crates and a net pile
	var half: int = [26, 16, 8][lod]
	var nst: int = [26, 14, 8][lod]
	var L := 6.8
	var Bt := [[0.0, 0.0], [0.06, 0.25], [0.2, 0.7], [0.45, 1.05], [0.7, 1.08], [0.9, 0.98], [1.0, 0.85]]
	var Dt := [[0.0, 0.05], [0.12, 0.2], [0.4, 0.38], [0.7, 0.38], [1.0, 0.3]]
	var Ht := [[0.0, 1.25], [0.15, 1.0], [0.45, 0.85], [0.8, 0.82], [1.0, 0.85]]
	var rings := _hull_rings(L, Bt, Dt, Ht, nst, half, 2.0)
	p.part("body")
	var hullcol := func(sk: int, n: int) -> Color:
		if sk < 2: return Color(0.1, 0.1, 0.1, 0.4)
		if sk < n - 2: return Color(0.12, 0.28, 0.4, 0.3)
		return Color(0.88, 0.87, 0.82, 0.3)
	_hull_strakes(p.b("hull"), rings, half, 6, Color(0.12, 0.28, 0.4), 0.012, 0.3, false, 0.03, hullcol)
	_hull_transom(p.b("hull"), rings, half, Color(0.12, 0.28, 0.4, 0.3))
	_gunwale(p.b("wood"), rings, half, 0.08, 0.06, Color(0.45, 0.3, 0.16))
	# deck planks, and the inside of the hull above them in white
	var inner: Array = []
	for r in rings:
		var rr: Array[Vector3] = []
		for v in r: rr.append(Vector3(v.x * 0.97, v.y - 0.01, v.z))
		inner.append(rr)
	_hull_strakes(p.b("hull"), inner, half, 4, Color(0.88, 0.87, 0.82), 0.0, 0.3, true, 0.04)
	var deck_y := 0.12
	for i in 16:
		var z := -L * 0.5 + 0.6 + i * 0.37
		var ti := clampi(int((z + L * 0.5) / L * (nst - 1)), 0, nst - 1)
		var bw: float = absf((rings[ti][half * 2] as Vector3).x) * 0.92
		if z > -0.2 and z < 1.8: continue
		NewModels3._boxy(p.b("wood"), Vector3(0, deck_y, z), Vector3(bw * 2.0, 0.04, 0.36), 0.0, Color(0.5, 0.38, 0.22))
	# wheelhouse
	var wz := 0.55
	_pboxy(p.b("hull"), Vector3(0, 0.95, wz), Vector3(1.6, 1.7, 1.5), 0.0, Color(0.9, 0.89, 0.84, 0.35), Color(0.85, 0.84, 0.8, 0.35))
	_pboxy(p.b("hull"), Vector3(0, 1.85, wz), Vector3(1.8, 0.07, 1.7), 0.0, Color(0.15, 0.3, 0.42, 0.35))
	for sx in [-1.0, 1.0]:
		_pboxy(p.b("glass"), Vector3(sx * 0.805, 1.25, wz - 0.05), Vector3(0.02, 0.5, 1.0), 0.0, Color(0.05, 0.07, 0.1))
	_pboxy(p.b("glass"), Vector3(0, 1.25, wz - 0.755), Vector3(1.2, 0.5, 0.02), 0.0, Color(0.05, 0.07, 0.1))
	_pboxy(p.b("hull"), Vector3(0.0, 0.5, wz + 0.78), Vector3(0.8, 1.0, 0.04), 0.0, Color(0.4, 0.3, 0.2, 0.35))
	# mast and derrick boom, with a pulley and a rope
	_mast(p.b("paint"), Vector3(0, 1.85, wz - 0.4), Vector3(0, 4.6, wz - 0.4), 0.05, 8 if lod < 2 else 5)
	_pcyl(p.b("paint"), Vector3(0.02, 2.6, wz - 0.4), Vector3(1.3, 3.3, wz - 1.8), 0.03, 0.03, 6, Color(0.7, 0.7, 0.72, 0.3), 3)
	if lod < 2:
		_limb(p.b("rope"), [Vector3(1.3, 3.3, wz - 1.8), Vector3(1.34, 2.2, wz - 1.82), Vector3(1.4, 0.7, wz - 1.85)], 0.01, 0.01, 4, Color(0.55, 0.5, 0.38))
		# floats and fenders along the rail; crates on deck; a heap of net
		for i in 6:
			var fz := -2.0 + i * 0.5
			_ell(p.b("hull"), Vector3(0.95 + 0.0 * i, 0.7, fz), Vector3(0.1, 0.1, 0.1), 8, Color(0.85, 0.35, 0.08, 0.2))
		for k in 3:
			NewModels3._boxy(p.b("wood"), Vector3(-0.35 + k * 0.1, 0.3 + k * 0.28, 2.4), Vector3(0.55, 0.26, 0.4), 0.2 * k, Color(0.5, 0.42, 0.3))
		_ell(p.b("rope"), Vector3(-0.2, 0.28, -1.6), Vector3(0.45, 0.2, 0.55), 10, Color(0.35, 0.4, 0.32), Color(0.3, 0.34, 0.27))
		# tyres as fenders on the sides
		for sx in [-1.0, 1.0]:
			var tyre: Array = []
			for i in 13: tyre.append(Vector3(sx * 1.07, 0.6 + sin(i * TAU / 12.0) * 0.14, -0.9 + cos(i * TAU / 12.0) * 0.14))
			_limb(p.b("paint_matte"), tyre, 0.06, 0.06, 6, Color(0.05, 0.05, 0.05, 0.3), 1.0, Color(-1, 0, 0), Transform3D.IDENTITY, 0)

static func _jetty(p: Parts, lod: int) -> void:
	# a timber pier, 8.4 m long and 2.2 m wide, deck 0.6 m over the water: boards with gaps, stringers, round piles (some taller, with ropes and cleats), a ladder
	p.part("body")
	var deck_y := 0.6
	var len := 8.4
	var seg := _seg(lod, 10, 7, 5)
	var nb: int = [56, 28, 1][lod]
	var bw: float = (len - 0.0) / nb
	for i in nb:
		var z: float = -0.15 - bw * (i + 0.5)
		var gap := 0.012 if lod < 2 else 0.0
		var th := 0.05 + 0.006 * (NewModels3._rnd(i, 1.0) - 0.5) * 2.0
		var col := Color(0.4, 0.33, 0.25).lerp(Color(0.5, 0.42, 0.3), NewModels3._rnd(i, 2.0))
		if lod == 2: th = 0.1
		NewModels3._boxy(p.b("wood"), Vector3(0, deck_y - th * 0.5 + (NewModels3._rnd(i, 3.0) - 0.5) * 0.004, z), Vector3(2.2, th, bw - gap), 0.0, col)
	# stringers and cross beams
	for sx in [-0.85, 0.0, 0.85]:
		NewModels3._boxy(p.b("wood"), Vector3(sx, deck_y - 0.18, -0.15 - len * 0.5), Vector3(0.1, 0.2, len), 0.0, Color(0.34, 0.28, 0.21))
	# piles: round timbers in pairs every 2.1 m, to 1.6 m below the water and a little above the deck
	var np := 5 if lod < 2 else 3
	for i in np:
		var z := -0.5 - i * (len - 0.7) / (np - 1)
		for sx in [-1.0, 1.0]:
			var up := 0.95 if (i % 2 == 0) else 0.7
			var lean := (NewModels3._rnd(i * 2.0 + sx, 4.0) - 0.5) * 0.04
			NewModels3._prism(p.b("wood"), Vector3(sx * 1.2, -1.6, z), Vector3(sx * 1.2 + lean, up, z + lean * 0.5), 0.11, 0.095, seg, Color(0.36, 0.3, 0.23), 3, 0.1, i + sx)
	if lod < 2:
		# diagonal braces on the underside
		for i in 4:
			var z := -0.5 - i * (len - 0.7) / 4.0
			NewModels3._prism(p.b("wood"), Vector3(-1.2, -0.9, z), Vector3(1.2, 0.2, z - 0.3), 0.04, 0.04, 5, Color(0.34, 0.28, 0.21), 3)
		# two iron cleats and a coiled rope on the deck, a ladder at the end, a lamp post
		for sx in [-1.0, 1.0]:
			_pboxy(p.b("steel"), Vector3(sx * 0.95, deck_y + 0.04, -3.2), Vector3(0.28, 0.06, 0.07), 0.0, Color(0.2, 0.2, 0.2))
			_pboxy(p.b("steel"), Vector3(sx * 0.95, deck_y + 0.01, -3.2), Vector3(0.06, 0.02, 0.06), 0.0, Color(0.2, 0.2, 0.2))
		var coil: Array = []
		for i in 40:
			var a := float(i) / 39.0 * TAU * 3.0
			coil.append(Vector3(0.5 + cos(a) * (0.12 + a * 0.01), deck_y + 0.02 + float(i) / 39.0 * 0.05, -5.0 + sin(a) * (0.12 + a * 0.01)))
		_limb(p.b("rope"), coil, 0.018, 0.018, 5, Color(0.7, 0.62, 0.45))
		for sx in [-1.0, 1.0]:
			_pcyl(p.b("steel"), Vector3(sx * 0.2, deck_y - 0.05, -len - 0.05), Vector3(sx * 0.2, -1.0, -len - 0.05), 0.02, 0.02, 5, Color(0.25, 0.25, 0.26), 3)
		for r in 5:
			_pcyl(p.b("steel"), Vector3(-0.2, deck_y - 0.2 - r * 0.28, -len - 0.05), Vector3(0.2, deck_y - 0.2 - r * 0.28, -len - 0.05), 0.014, 0.014, 5, Color(0.25, 0.25, 0.26), 3)


# ================================================================== the farmyard
static func _wheel(b: NewModels2.Buf, bm: NewModels2.Buf, c: Vector3, r: float, w: float, seg: int, lugs: int, tyre := Color(0.07, 0.07, 0.07, 0.3), rim := Color(0.85, 0.7, 0.1, 0.3)) -> void:
	# a tractor-type tyre with lugs and a painted rim; axis along x
	var a := c - Vector3(w * 0.5, 0, 0); var e := c + Vector3(w * 0.5, 0, 0)
	_pcyl(b, a, e, r, r, seg, tyre, 3)
	_pcyl(b, a - Vector3(0.012, 0, 0), e + Vector3(0.012, 0, 0), r * 0.62, r * 0.62, seg, rim, 3)
	if lugs > 0:
		for i in lugs:
			var ang := TAU * i / lugs
			var d := Vector3(0, cos(ang), sin(ang))
			var side := 1.0 if i % 2 == 0 else -1.0
			_pbox(b, c + d * (r + 0.02) + Vector3(side * w * 0.22, 0, 0), Basis(Vector3(1, 0, 0), -ang), Vector3(w * 0.5, 0.05, 0.1), Color(0.06, 0.06, 0.06, 0.3))

static func _combine(p: Parts, lod: int) -> void:
	# a grain combine harvester, about 9.4 m long with a 6 m header, 3.9 m to the cab roof: green body, yellow wheels, glazed cab, grain tank, folded unloading auger
	var green := Color(0.14, 0.35, 0.14, 0.18)
	var darkg := Color(0.1, 0.22, 0.1, 0.18)
	var grey := Color(0.3, 0.31, 0.32, 0.2)
	var yel := Color(0.88, 0.72, 0.08, 0.2)
	var seg := _seg(lod, 24, 14, 8)
	var m := "mudpaint"
	p.part("body")
	var b := p.b(m)
	# the main body: lower housing, grain tank, rear engine hood
	_pboxy(b, Vector3(0, 1.45, 0.4), Vector3(2.7, 1.2, 4.6), 0.0, green)
	_pboxy(b, Vector3(0, 2.7, 1.1), Vector3(2.5, 1.2, 3.1), 0.0, green, Color(0.18, 0.4, 0.18, 0.18))
	for sx in [-1.0, 1.0]:                                           # the tank's sloped shoulders
		_pbox(b, Vector3(sx * 1.2, 3.1, 1.1), Basis(Vector3(0, 0, 1), sx * 0.5), Vector3(0.1, 0.5, 3.0), darkg)
	_pboxy(b, Vector3(0, 1.8, 3.2), Vector3(2.3, 1.4, 1.9), 0.0, green, Color(0.17, 0.38, 0.17, 0.18))        # engine hood
	for i in 6:
		_pboxy(b, Vector3(1.16, 1.8, 2.6 + i * 0.22), Vector3(0.03, 0.9, 0.1), 0.0, Color(0.05, 0.1, 0.05, 0.2))   # louvres
	# the cab: a glazed box high at the front
	_pboxy(b, Vector3(0, 3.0, -1.25), Vector3(1.9, 1.7, 1.9), 0.0, Color(0.9, 0.9, 0.86, 0.1), Color(0.9, 0.9, 0.86, 0.1))
	_pboxy(b, Vector3(0, 3.92, -1.25), Vector3(2.1, 0.1, 2.1), 0.0, Color(0.9, 0.9, 0.86, 0.1))
	var gl := p.b("glass")
	_pboxy(gl, Vector3(0, 3.0, -2.205), Vector3(1.7, 1.4, 0.03), 0.0, Color(0.05, 0.07, 0.09))
	for sx in [-1.0, 1.0]:
		_pboxy(gl, Vector3(sx * 0.955, 3.0, -1.25), Vector3(0.03, 1.4, 1.6), 0.0, Color(0.05, 0.07, 0.09))
	_pboxy(gl, Vector3(0, 3.0, -0.295), Vector3(1.7, 1.3, 0.03), 0.0, Color(0.05, 0.07, 0.09))
	# chassis frame, steps, a handrail, exhaust and a beacon
	_pboxy(b, Vector3(0, 0.75, 0.2), Vector3(2.0, 0.5, 5.2), 0.0, grey)
	if lod < 2:
		for i in 5:
			_pboxy(b, Vector3(-1.4, 0.7 + i * 0.5, -0.6), Vector3(0.5, 0.04, 0.3), 0.0, grey)
		for sx in [-1.0, 1.0]:
			_pcyl(b, Vector3(sx * 1.0, 3.9, -0.3), Vector3(sx * 1.0, 4.35, -0.3), 0.025, 0.025, 6, Color(0.2, 0.2, 0.22, 0.3), 3)    # mirrors/aerials
		_pcyl(b, Vector3(0.9, 3.3, 2.2), Vector3(0.9, 4.5, 2.2), 0.09, 0.07, 8, Color(0.15, 0.15, 0.16, 0.5), 3)           # exhaust
		_pcyl(b, Vector3(0.0, 3.92, -1.25), Vector3(0, 4.05, -1.25), 0.1, 0.07, 8, Color(0.9, 0.55, 0.05, 0.0), 3)
	# the unloading auger folded along the top of the tank's left side
	_pcyl(b, Vector3(-1.1, 3.5, 2.6), Vector3(-1.2, 3.65, -0.5), 0.2, 0.17, 10, green, 3)
	_pcyl(b, Vector3(-1.2, 3.65, -0.5), Vector3(-1.25, 3.5, -1.0), 0.22, 0.12, 8, darkg, 3)
	# the big drive wheels at the front, the small steered ones at the back
	var ws := p.b("paint_matte")
	_wheel(ws, b, Vector3(-1.45, 0.9, -0.9), 0.9, 0.7, seg, 22 if lod == 0 else 0)
	_wheel(ws, b, Vector3(1.45, 0.9, -0.9), 0.9, 0.7, seg, 22 if lod == 0 else 0)
	_wheel(ws, b, Vector3(-1.25, 0.6, 3.1), 0.6, 0.45, seg, 16 if lod == 0 else 0)
	_wheel(ws, b, Vector3(1.25, 0.6, 3.1), 0.6, 0.45, seg, 16 if lod == 0 else 0)
	# the feeder housing and the 6 m header: platform, cutter bar, dividers, auger trough
	_pbox(b, Vector3(0, 1.3, -3.0), Basis(Vector3(1, 0, 0), 0.0), Vector3(1.7, 1.0, 1.6), darkg)
	var hz := -4.2
	_pboxy(b, Vector3(0, 0.75, hz), Vector3(6.1, 0.12, 1.5), 0.0, green, Color(0.2, 0.4, 0.2, 0.18))
	_pboxy(b, Vector3(0, 1.12, hz + 0.7), Vector3(6.1, 0.8, 0.12), 0.0, green)
	_pboxy(b, Vector3(0, 0.74, hz - 0.8), Vector3(6.1, 0.07, 0.12), 0.0, Color(0.78, 0.78, 0.8, 0.4))           # cutter bar
	for sx in [-1.0, 1.0]:
		_pboxy(b, Vector3(sx * 3.05, 1.0, hz), Vector3(0.1, 0.7, 1.5), 0.0, darkg)
		_pbox(b, Vector3(sx * 3.05, 0.9, hz - 0.85), Basis(Vector3(1, 0, 0), 0.0), Vector3(0.1, 0.4, 0.3), yel)
	# the reel: a drum with tine bars, turning (a part with its own pivot)
	p.part("reel", Vector3(0, 1.45, hz - 0.1))
	var rb := p.b("paint")
	var rc := Vector3(0, 1.45, hz - 0.1)
	_pcyl(rb, rc - Vector3(2.95, 0, 0), rc + Vector3(2.95, 0, 0), 0.07, 0.07, 6, Color(0.5, 0.5, 0.52, 0.2), 3)
	var bars := 6 if lod < 2 else 4
	for i in bars:
		var a := TAU * i / bars
		var d := Vector3(0, cos(a), sin(a))
		_pcyl(rb, rc + d * 0.1 - Vector3(2.95, 0, 0), rc + d * 0.1 + Vector3(2.95, 0, 0), 0.025, 0.025, 4, yel, 3)
		if lod < 2:
			for k in 12:
				var xk := -2.7 + k * 0.49
				_pcyl(rb, rc + d * 0.1 + Vector3(xk, 0, 0), rc + d * 0.62 + Vector3(xk, 0, 0), 0.01, 0.008, 3, Color(0.8, 0.65, 0.1, 0.2), 1)
	p.part("body")

static func _baler(p: Parts, lod: int) -> void:
	# a towed round baler, 2.5 m wide: red body with a pickup reel, round chamber, tailgate, two wheels and a drawbar
	var red := Color(0.62, 0.12, 0.08, 0.2)
	var dark := Color(0.14, 0.14, 0.15, 0.3)
	var seg := _seg(lod, 28, 16, 8)
	p.part("body")
	var b := p.b("mudpaint")
	# the chamber: a horizontal drum across the machine, seen as two side discs and the belted body
	var cc := Vector3(0, 1.45, 0.3)
	_pcyl(b, cc - Vector3(1.1, 0, 0), cc + Vector3(1.1, 0, 0), 1.0, 1.0, seg, Color(0.55, 0.1, 0.07, 0.25), 3)
	_pcyl(b, cc - Vector3(1.14, 0, 0), cc - Vector3(1.08, 0, 0), 0.82, 0.82, seg, Color(0.35, 0.07, 0.05, 0.25), 3)
	_pcyl(b, cc + Vector3(1.08, 0, 0), cc + Vector3(1.14, 0, 0), 0.82, 0.82, seg, Color(0.35, 0.07, 0.05, 0.25), 3)
	# the front: pickup reel with tines, a guard, the feed rolls
	var pk := Vector3(0, 0.45, -1.15)
	_pcyl(p.b("paint"), pk - Vector3(0.95, 0, 0), pk + Vector3(0.95, 0, 0), 0.28, 0.28, 12 if lod < 2 else 6, Color(0.15, 0.15, 0.16, 0.3), 3)
	if lod < 2:
		for i in 9:
			var a := TAU * i / 9.0
			for k in 10:
				var xk := -0.9 + k * 0.2
				_pcyl(p.b("steel"), pk + Vector3(xk, cos(a) * 0.28, sin(a) * 0.28), pk + Vector3(xk, cos(a) * 0.46, sin(a) * 0.46 - 0.05), 0.007, 0.004, 3, Color(0.7, 0.7, 0.72), 1)
	_pboxy(b, Vector3(0, 0.95, -1.2), Vector3(2.0, 0.08, 0.9), 0.0, red)
	_pboxy(b, Vector3(0, 0.95, -0.68), Vector3(2.2, 0.55, 0.12), 0.0, red)
	# the tailgate (hinged hood on the chamber's top rear)
	_pbox(b, cc + Vector3(0, 0.5, 0.75), Basis(Vector3(1, 0, 0), -0.7), Vector3(2.15, 0.1, 1.2), red)
	# frame, tongue, hitch and jack
	_pboxy(b, Vector3(0, 0.62, -1.9), Vector3(0.18, 0.18, 2.6), 0.0, dark)
	_pbox(b, Vector3(0, 0.62, -3.1), Basis(Vector3(1, 0, 0), 0.0), Vector3(0.2, 0.12, 0.5), dark)
	_pcyl(b, Vector3(0, 0.62, -3.35), Vector3(0, 0.45, -3.35), 0.045, 0.045, 8, Color(0.5, 0.5, 0.52, 0.3), 3)
	_pcyl(b, Vector3(0.0, 0.7, -2.3), Vector3(0.0, 0.0, -2.3), 0.04, 0.04, 8, Color(0.45, 0.45, 0.47, 0.3), 3)
	_pboxy(b, Vector3(0, 0.0 + 0.02, -2.3), Vector3(0.28, 0.04, 0.28), 0.0, dark)
	var ws := p.b("paint_matte")
	_wheel(ws, b, Vector3(-1.38, 0.55, 0.45), 0.55, 0.4, _seg(lod, 20, 12, 8), 14 if lod == 0 else 0, Color(0.07, 0.07, 0.07, 0.3), Color(0.5, 0.5, 0.52, 0.3))
	_wheel(ws, b, Vector3(1.38, 0.55, 0.45), 0.55, 0.4, _seg(lod, 20, 12, 8), 14 if lod == 0 else 0, Color(0.07, 0.07, 0.07, 0.3), Color(0.5, 0.5, 0.52, 0.3))
	# the twine/net box on the front left and a safety guard
	_pboxy(b, Vector3(-0.8, 1.85, -0.55), Vector3(0.45, 0.4, 0.5), 0.0, Color(0.1, 0.1, 0.11, 0.3))
	_pcyl(b, Vector3(0, 1.2, -0.7), Vector3(0, 1.2, -0.7) + Vector3(0.0, 0.0, 0.0), 0.01, 0.01, 3, dark, 0)

## One plough body's mouldboard: a twisted plate from the share edge (low, forward) curling up and out toward the rear, polished steel; double-sided.
static func _mouldboard(b: NewModels2.Buf, o: Vector3, side: float, col: Color, nu: int, nv: int) -> void:
	var P: Array = []
	for i in nu + 1:
		var u := float(i) / nu
		var row: Array[Vector3] = []
		for j in nv + 1:
			var v := float(j) / nv
			var x := side * (0.02 + 0.3 * pow(v, 1.6) * (0.25 + 0.75 * smoothstep(0.0, 0.8, u)))
			var y := -0.52 + 0.55 * v * (0.45 + 0.55 * u)
			var z := -0.2 + 0.78 * u
			row.append(o + Vector3(x, y, z))
		P.append(row)
	for i in nu:
		for j in nv:
			var a: Vector3 = P[i][j]; var bb: Vector3 = P[i][j + 1]; var c: Vector3 = P[i + 1][j + 1]; var d: Vector3 = P[i + 1][j]
			var n := (bb - a).cross(d - a).normalized()
			if n.length_squared() < 0.5: n = (c - a).cross(d - a).normalized()
			var cc := col * (0.94 + 0.1 * float(j) / nv)
			cc.a = col.a
			b.quad(a, bb, c, d, cc, n)
			b.quad(a, d, c, bb, cc, -n)

static func _plough(p: Parts, lod: int) -> void:
	# a four-furrow mounted plough, 4.6 m long: a red box-section beam running at an angle across the bodies, four bodies each with a standard, a share and a twisted polished mouldboard, skimmers and a depth wheel on the rear
	var frame := Color(0.6, 0.11, 0.07, 0.25)
	var steel := Color(0.78, 0.78, 0.8, 0.0)
	p.part("body")
	var b := p.b("mudpaint")
	var bi := p.b("steel")
	var beam_a := Vector3(0.0, 0.9, -1.4)
	var beam_b := Vector3(-0.75, 0.9, 2.6)
	var dir := (beam_b - beam_a).normalized()
	_pbox(b, (beam_a + beam_b) * 0.5, Basis(Vector3.UP, atan2(dir.x, dir.z)), Vector3(0.16, 0.2, beam_a.distance_to(beam_b)), frame)
	_pboxy(b, Vector3(-0.28, 1.25, -1.55), Vector3(0.1, 0.9, 0.12), 0.0, frame)
	_pboxy(b, Vector3(0.28, 1.25, -1.55), Vector3(0.1, 0.9, 0.12), 0.0, frame)
	_pboxy(b, Vector3(0.0, 1.62, -1.55), Vector3(0.7, 0.1, 0.12), 0.0, frame)
	_pboxy(b, Vector3(0.0, 0.95, -1.5), Vector3(0.7, 0.1, 0.14), 0.0, frame)
	_pcyl(b, Vector3(-0.28, 0.9, -1.7), Vector3(-0.28, 0.9, -1.35), 0.03, 0.03, 6, Color(0.3, 0.3, 0.32, 0.3), 3)
	_pcyl(b, Vector3(0.28, 0.9, -1.7), Vector3(0.28, 0.9, -1.35), 0.03, 0.03, 6, Color(0.3, 0.3, 0.32, 0.3), 3)
	for k in 4:
		var t := 0.22 + k * 0.22
		var bp := beam_a.lerp(beam_b, t)
		_pbox(b, bp + Vector3(0.0, -0.3, 0.1), Basis(Vector3(1, 0, 0), -0.15), Vector3(0.06, 0.7, 0.14), Color(0.22, 0.22, 0.24, 0.3))
		_mouldboard(bi, bp + Vector3(0.0, -0.18, 0.0), 1.0, steel, 6 if lod < 2 else 3, 5 if lod < 2 else 2)
		_pbox(b, bp + Vector3(0.08, -0.7, -0.16), Basis(Vector3.UP, -0.3), Vector3(0.3, 0.025, 0.46), Color(0.55, 0.52, 0.48, 0.55))
		if lod < 2:
			_pbox(b, bp + Vector3(0.02, -0.12, -0.28), Basis(Vector3(1, 0, 0), 0.0), Vector3(0.07, 0.22, 0.1), Color(0.3, 0.3, 0.32, 0.3))
	var wc := beam_b + Vector3(0.5, -0.45, 0.25)
	_pcyl(b, beam_b + Vector3(0.0, 0.0, 0.0), wc + Vector3(0, 0.2, 0), 0.04, 0.04, 6, Color(0.3, 0.3, 0.32, 0.3), 3)
	_wheel(p.b("paint_matte"), b, wc, 0.36, 0.2, _seg(lod, 18, 10, 6), 0, Color(0.06, 0.06, 0.06, 0.3), Color(0.5, 0.5, 0.52, 0.3))

static func _seed_drill(p: Parts, lod: int) -> void:
	# a 3 m coulter drill: a long seed hopper with a lid on a frame, a row of coulter discs and tines, press wheels, a drawbar, two transport wheels
	var red := Color(0.55, 0.12, 0.08, 0.2)
	var frame := Color(0.2, 0.2, 0.22, 0.25)
	p.part("body")
	var b := p.b("mudpaint")
	_pboxy(b, Vector3(0, 1.35, 0.0), Vector3(3.0, 0.65, 0.95), 0.0, red, Color(0.62, 0.15, 0.1, 0.2))           # hopper
	_pbox(b, Vector3(0, 1.72, 0.0), Basis(Vector3(1, 0, 0), 0.0), Vector3(3.04, 0.07, 1.0), Color(0.6, 0.13, 0.09, 0.2))   # lid
	for sx in [-1.35, -0.45, 0.45, 1.35]:
		_pboxy(b, Vector3(sx, 0.8, 0.0), Vector3(0.1, 0.9, 0.7), 0.0, frame)
	_pboxy(b, Vector3(0, 0.45, 0.35), Vector3(3.0, 0.1, 0.1), 0.0, frame)
	_pboxy(b, Vector3(0, 0.45, -0.35), Vector3(3.0, 0.1, 0.1), 0.0, frame)
	var nrow := 14 if lod < 2 else 7
	for i in nrow:
		var x := -1.4 + i * (2.8 / (nrow - 1))
		_pcyl(p.b("steel"), Vector3(x - 0.015, 0.22, 0.6), Vector3(x + 0.015, 0.22, 0.6), 0.22, 0.22, 12 if lod < 2 else 6, Color(0.55, 0.55, 0.57), 3)       # coulter disc
		_pboxy(b, Vector3(x, 0.45, 0.6), Vector3(0.05, 0.4, 0.05), 0.0, frame)
		if lod < 2:
			_limb(p.b("rope"), [Vector3(x, 1.05, 0.0), Vector3(x + 0.03, 0.7, 0.3), Vector3(x, 0.4, 0.58)], 0.012, 0.012, 4, Color(0.05, 0.05, 0.05))   # seed tube
			_pcyl(p.b("paint_matte"), Vector3(x - 0.04, 0.12, 1.0), Vector3(x + 0.04, 0.12, 1.0), 0.12, 0.12, 8, Color(0.06, 0.06, 0.06, 0.3), 3)     # press wheel
	# drawbar and the transport wheels
	_pboxy(b, Vector3(0, 0.55, -1.8), Vector3(0.14, 0.14, 2.6), 0.0, frame)
	_pcyl(b, Vector3(0, 0.55, -3.1), Vector3(0, 0.3, -3.1), 0.04, 0.04, 6, frame, 3)
	_wheel(p.b("paint_matte"), b, Vector3(-1.62, 0.4, 0.0), 0.4, 0.22, _seg(lod, 16, 10, 6), 0, Color(0.06, 0.06, 0.06, 0.3), Color(0.55, 0.55, 0.57, 0.3))
	_wheel(p.b("paint_matte"), b, Vector3(1.62, 0.4, 0.0), 0.4, 0.22, _seg(lod, 16, 10, 6), 0, Color(0.06, 0.06, 0.06, 0.3), Color(0.55, 0.55, 0.57, 0.3))

static func _trough(p: Parts, lod: int) -> void:
	# a galvanised cattle trough, 2.0 m long, 0.45 m wide, 0.5 m high, with a float valve, a pipe and water in it
	p.part("body")
	var zn := Color(0.62, 0.64, 0.64, 0.15)
	var b := p.b("zinc")
	_pboxy(b, Vector3(0, 0.25, 0), Vector3(2.0, 0.5, 0.5), 0.0, zn)              # the shell (the water goes in a lid on top)
	# the rolled rim: a rail round the top
	_pboxy(b, Vector3(0, 0.505, 0.235), Vector3(2.0, 0.03, 0.04), 0.0, Color(0.55, 0.57, 0.57, 0.15))
	_pboxy(b, Vector3(0, 0.505, -0.235), Vector3(2.0, 0.03, 0.04), 0.0, Color(0.55, 0.57, 0.57, 0.15))
	for sx in [-1.0, 1.0]:
		_pboxy(b, Vector3(sx * 0.98, 0.505, 0.0), Vector3(0.04, 0.03, 0.5), 0.0, Color(0.55, 0.57, 0.57, 0.15))
	_pboxy(p.b("glass"), Vector3(0, 0.46, 0.0), Vector3(1.92, 0.01, 0.42), 0.0, Color(0.15, 0.2, 0.2))        # the water
	if lod < 2:
		# ribs and end plates (the pressed corrugations), the float valve and the water pipe
		for i in 9:
			_pboxy(b, Vector3(-0.9 + i * 0.225, 0.25, 0.255), Vector3(0.03, 0.46, 0.012), 0.0, Color(0.58, 0.6, 0.6, 0.15))
			_pboxy(b, Vector3(-0.9 + i * 0.225, 0.25, -0.255), Vector3(0.03, 0.46, 0.012), 0.0, Color(0.58, 0.6, 0.6, 0.15))
		_pcyl(b, Vector3(0.8, 0.46, 0.0), Vector3(0.8, 0.95, 0.0), 0.02, 0.02, 6, Color(0.2, 0.2, 0.22, 0.2), 3)
		_pcyl(b, Vector3(0.8, 0.95, 0.0), Vector3(0.55, 0.95, 0.0), 0.02, 0.02, 6, Color(0.2, 0.2, 0.22, 0.2), 3)
		_ell(p.b("paint"), Vector3(0.55, 0.9, 0.0), Vector3(0.05, 0.05, 0.05), 8, Color(0.1, 0.1, 0.12, 0.3))
		_limb(p.b("paint_matte"), [Vector3(0.8, 0.95, 0.0), Vector3(0.8, 0.7, -0.4), Vector3(0.9, 0.0, -0.6), Vector3(1.4, 0.0, -0.9)], 0.015, 0.015, 5, Color(0.04, 0.04, 0.04, 0.3))

static func _feed_rack(p: Parts, lod: int) -> void:
	# a hay rack: a timber trough on legs with a slatted V-shaped rack above, a little hay in it
	p.part("body")
	var wd := p.b("wood")
	var c1 := Color(0.45, 0.36, 0.26); var c2 := Color(0.52, 0.42, 0.3)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			NewModels3._prism(wd, Vector3(sx * 1.1, 0, sz * 0.38), Vector3(sx * 1.1, 0.75, sz * 0.38), 0.045, 0.042, 6, c1, 3, 0.1)
	NewModels3._boxy(wd, Vector3(0, 0.55, 0.38), Vector3(2.4, 0.12, 0.04), 0.0, c2)
	NewModels3._boxy(wd, Vector3(0, 0.55, -0.38), Vector3(2.4, 0.12, 0.04), 0.0, c2)
	NewModels3._boxy(wd, Vector3(0, 0.5, 0.0), Vector3(2.4, 0.04, 0.8), 0.0, c1)
	var n := 13 if lod < 2 else 5
	for i in n:
		var x := -1.15 + i * (2.3 / (n - 1))
		for sz in [-1.0, 1.0]:
			NewModels3._prism(wd, Vector3(x, 0.58, sz * 0.38), Vector3(x, 1.5, sz * 0.62), 0.016, 0.014, 5, c2, 3, 0.1)
	for sz in [-1.0, 1.0]:
		NewModels3._boxy(wd, Vector3(0, 1.5, sz * 0.62), Vector3(2.4, 0.05, 0.06), 0.0, c1)
	if lod < 2:
		for i in 12:
			var x := -1.0 + i * 0.18
			_ell(p.b("hay"), Vector3(x, 0.78 + NewModels3._rnd(i, 5.0) * 0.1, (NewModels3._rnd(i, 6.0) - 0.5) * 0.2), Vector3(0.14, 0.2, 0.28), 6, Color(0.72, 0.62, 0.3))

static func _wood_pile(p: Parts, lod: int) -> void:
	# a stacked cord of split firewood, 2.4 m long, 1.2 m high, 0.5 m deep: bark sides, pale cut ends, a few odd logs
	p.part("body")
	var wd := p.b("wood")
	var rows := 9
	var cols := 14
	var seg := _seg(lod, 7, 5, 4)
	for r in rows:
		for c in cols:
			var off := (r % 2) * 0.08
			var x := -1.1 + c * 0.168 + off + (NewModels3._rnd(r * 17 + c, 7.0) - 0.5) * 0.02
			var y := 0.075 + r * 0.128
			var rad := 0.06 + NewModels3._rnd(r * 17 + c, 8.0) * 0.032
			var d0 := 0.0 + (NewModels3._rnd(r * 17 + c, 9.0) - 0.5) * 0.05
			var bark := Color(0.3, 0.22, 0.15).lerp(Color(0.42, 0.33, 0.24), NewModels3._rnd(r * 17 + c, 10.0))
			if lod == 2:
				continue
			NewModels3._prism(wd, Vector3(x, y, -0.25 + d0), Vector3(x, y, 0.25 + d0), rad, rad * 0.97, seg, bark, 0, 0.06)
			if lod == 0:
				var endc := Color(0.78, 0.65, 0.45).lerp(Color(0.66, 0.5, 0.32), NewModels3._rnd(r * 17 + c, 11.0))
				var cp := p.b("wood")
				NewModels3._prism(cp, Vector3(x, y, 0.25 + d0), Vector3(x, y, 0.253 + d0), rad * 0.97, rad * 0.97, seg, endc, 2, 0.02)
				NewModels3._prism(cp, Vector3(x, y, -0.253 + d0), Vector3(x, y, -0.25 + d0), rad * 0.97, rad * 0.97, seg, endc, 1, 0.02)
	if lod == 2:
		NewModels3._boxy(wd, Vector3(0, 0.58, 0.0), Vector3(2.4, 1.16, 0.5), 0.0, Color(0.4, 0.31, 0.22))
	# two stakes holding the ends
	for sx in [-1.0, 1.0]:
		NewModels3._prism(wd, Vector3(sx * 1.25, 0, 0.3), Vector3(sx * 1.25, 1.3, 0.3), 0.05, 0.045, 6, Color(0.36, 0.28, 0.2), 3, 0.08)
		NewModels3._prism(wd, Vector3(sx * 1.25, 0, -0.3), Vector3(sx * 1.25, 1.3, -0.3), 0.05, 0.045, 6, Color(0.36, 0.28, 0.2), 3, 0.08)

static func _oil_tank(p: Parts, lod: int) -> void:
	# a farm fuel tank: a horizontal steel drum 2.2 m long, 1.1 m across on two cradles, a filler cap, gauge, tap, hose and nozzle
	p.part("body")
	var seg := _seg(lod, 24, 14, 8)
	var tank := Color(0.2, 0.34, 0.22, 0.35)
	var c := Vector3(0, 1.0, 0)
	var b := p.b("paint")
	_pcyl(b, c - Vector3(0, 0, 1.0), c + Vector3(0, 0, 1.0), 0.55, 0.55, seg, tank, 0)
	# domed ends
	for sz in [-1.0, 1.0]:
		var st: Array = []
		for k in 6:
			var t := float(k) / 5.0
			st.append([c + Vector3(0, 0, sz * (1.0 + 0.16 * sin(t * PI * 0.5))), 0.55 * cos(t * PI * 0.5 * 0.97), 0.55 * cos(t * PI * 0.5 * 0.97), tank])
		_sweep(b, st, seg, tank, Color(-1, 0, 0), Transform3D(Basis(Vector3.UP, 0.0), Vector3.ZERO), Vector3.UP, 0)
	# cradles and legs
	for sz in [-0.6, 0.6]:
		_pboxy(b, Vector3(0, 0.3, sz), Vector3(0.9, 0.6, 0.12), 0.0, Color(0.25, 0.25, 0.27, 0.35))
		_pboxy(b, Vector3(0, 0.07, sz), Vector3(1.1, 0.14, 0.2), 0.0, Color(0.5, 0.5, 0.5, 0.2))
	# the top fittings
	_pcyl(b, Vector3(0, 1.54, 0.2), Vector3(0, 1.64, 0.2), 0.12, 0.1, 10, Color(0.15, 0.15, 0.16, 0.3), 3)
	_pcyl(b, Vector3(0, 1.54, -0.5), Vector3(0, 1.6, -0.5), 0.05, 0.05, 8, Color(0.6, 0.55, 0.3, 0.2), 3)
	_pboxy(b, Vector3(0.0, 1.3, 1.02), Vector3(0.24, 0.3, 0.05), 0.0, Color(0.7, 0.7, 0.7, 0.2))
	if lod < 2:
		_pcyl(p.b("steel"), Vector3(0.0, 0.55, 1.1), Vector3(0.0, 0.55, 1.4), 0.025, 0.025, 6, Color(0.5, 0.5, 0.52), 3)
		_limb(p.b("paint_matte"), [Vector3(0.0, 0.55, 1.4), Vector3(0.1, 0.3, 1.5), Vector3(0.4, 0.15, 1.2), Vector3(0.6, 0.12, 0.6), Vector3(0.65, 0.12, 0.2)], 0.02, 0.02, 5, Color(0.04, 0.04, 0.04, 0.3))
		_pboxy(b, Vector3(0.65, 0.2, 0.15), Vector3(0.06, 0.16, 0.1), 0.0, Color(0.3, 0.3, 0.32, 0.3))

static func _grain_bin(p: Parts, lod: int) -> void:
	# a small galvanised corrugated grain bin: 3.2 m across, 3.8 m of wall, a cone roof with a vent, a ladder and door, on a concrete ring
	p.part("body")
	var seg := _seg(lod, 28, 16, 10)
	var zn := Color(0.66, 0.68, 0.68, 0.0)
	var b := p.b("bin")
	_pcyl(b, Vector3(0, 0.25, 0), Vector3(0, 3.95, 0), 1.6, 1.6, seg, zn, 0)
	_pcyl(b, Vector3(0, 3.95, 0), Vector3(0, 5.0, 0), 1.65, 0.28, seg, Color(0.7, 0.72, 0.72, 0.0), 0)
	_pcyl(b, Vector3(0, 5.0, 0), Vector3(0, 5.25, 0), 0.34, 0.34, 10, Color(0.6, 0.62, 0.62, 0.0), 3)
	# the concrete ring and the floor skirt
	var cb := p.b("steel")
	_pcyl(cb, Vector3(0, 0, 0), Vector3(0, 0.28, 0), 1.75, 1.7, seg, Color(0.45, 0.44, 0.42), 3)
	if lod < 2:
		# a ladder on the wall and a hatch, the eave bands, rivet bands
		for sx in [-0.18, 0.18]:
			_pcyl(cb, Vector3(sx, 0.4, -1.62), Vector3(sx, 4.3, -1.62), 0.02, 0.02, 5, Color(0.4, 0.4, 0.42), 3)
		for i in 14:
			_pcyl(cb, Vector3(-0.18, 0.7 + i * 0.26, -1.62), Vector3(0.18, 0.7 + i * 0.26, -1.62), 0.012, 0.012, 4, Color(0.4, 0.4, 0.42), 3)
		_pboxy(cb, Vector3(0, 0.75, 1.59), Vector3(0.7, 1.2, 0.07), 0.0, Color(0.5, 0.52, 0.52))
		for k in 3:
			var y := 1.4 + k * 1.15
			_pcyl(cb, Vector3(0, y, 0), Vector3(0, y + 0.07, 0), 1.63, 1.63, seg, Color(0.55, 0.57, 0.57), 0)
		# the roof's rib lines
		for i in 12:
			var a := TAU * i / 12.0
			_pcyl(cb, Vector3(cos(a) * 1.64, 3.97, sin(a) * 1.64), Vector3(cos(a) * 0.3, 5.0, sin(a) * 0.3), 0.025, 0.02, 4, Color(0.55, 0.57, 0.57), 3)

static func _coop(p: Parts, lod: int) -> void:
	# a timber henhouse on stilts: 1.7 m by 1.2 m by 1.5 m high, a pitched steel roof, a ramp to a pop door, a hinged nest-box lid, a perch window
	p.part("body")
	var wd := p.b("wood")
	var pn := p.b("paint_matte")
	var board := Color(0.55, 0.38, 0.22, 0.45)
	var legh := 0.55
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			NewModels3._prism(wd, Vector3(sx * 0.78, 0, sz * 0.5), Vector3(sx * 0.78, legh, sz * 0.5), 0.05, 0.05, 6, Color(0.4, 0.31, 0.22), 3, 0.08)
	# floor, walls (as upright boards), roof
	NewModels3._boxy(wd, Vector3(0, legh + 0.03, 0), Vector3(1.7, 0.06, 1.2), 0.0, Color(0.45, 0.36, 0.26))
	var nb := 17 if lod < 2 else 4
	var bw := 1.7 / nb
	for i in nb:
		var x := -0.85 + bw * (i + 0.5)
		var col := board.lerp(Color(0.62, 0.45, 0.28, 0.45), NewModels3._rnd(i, 12.0))
		# front (-z) and back (+z) walls, with a gap for the pop door in the front
		if not (x > 0.35 and x < 0.7 and lod < 2):
			NewModels3._boxy(wd, Vector3(x, legh + 0.7, -0.6), Vector3(bw - 0.006, 1.3, 0.025), 0.0, col)
		NewModels3._boxy(wd, Vector3(x, legh + 0.75, 0.6), Vector3(bw - 0.006, 1.4, 0.025), 0.0, col)
	var nz := 12 if lod < 2 else 3
	for i in nz:
		var z := -0.6 + 1.2 * (i + 0.5) / nz
		var col := board.lerp(Color(0.6, 0.43, 0.26, 0.45), NewModels3._rnd(i, 13.0))
		for sx in [-1.0, 1.0]:
			NewModels3._boxy(wd, Vector3(sx * 0.85, legh + 0.7, z), Vector3(0.025, 1.3, 1.2 / nz - 0.005), 0.0, col)
	# a pitched roof of corrugated steel (a bit of overhang)
	var roof := p.b("steel")
	var rcol := Color(0.5, 0.5, 0.5)
	for sz in [-1.0, 1.0]:
		var rb := Basis(Vector3(1, 0, 0), sz * 0.45)
		NewModels3._boxb(roof, Vector3(0, legh + 1.62, sz * 0.32), rb, Vector3(1.95, 0.025, 0.85), rcol)
	if lod < 2:
		for i in 16:
			for sz in [-1.0, 1.0]:
				NewModels3._boxb(roof, Vector3(-0.9 + i * 0.12, legh + 1.625, sz * 0.32), Basis(Vector3(1, 0, 0), sz * 0.45), Vector3(0.04, 0.012, 0.86), Color(0.45, 0.45, 0.46))
		# ramp with cleats, the pop door, nest box with a hinged lid, a perch
		NewModels3._boxb(wd, Vector3(0.52, 0.3, -1.0), Basis(Vector3(1, 0, 0), -0.5), Vector3(0.3, 0.025, 0.95), Color(0.5, 0.4, 0.28))
		for i in 6:
			NewModels3._boxb(wd, Vector3(0.52, 0.12 + i * 0.1, -0.75 - i * 0.14), Basis.IDENTITY, Vector3(0.3, 0.02, 0.025), Color(0.45, 0.36, 0.26))
		NewModels3._boxy(wd, Vector3(1.1, legh + 0.55, 0.0), Vector3(0.38, 0.5, 0.9), 0.0, Color(0.5, 0.38, 0.25, 0.45))
		NewModels3._boxb(wd, Vector3(1.1, legh + 0.88, 0.0), Basis(Vector3(0, 0, 1), -0.25), Vector3(0.44, 0.03, 0.96), Color(0.45, 0.35, 0.24))
		_pboxy(pn, Vector3(0.0, legh + 1.25, -0.62), Vector3(0.35, 0.3, 0.02), 0.0, Color(0.05, 0.05, 0.05, 0.5))
		NewModels3._prism(wd, Vector3(-0.8, legh + 0.35, 0.58), Vector3(0.8, legh + 0.35, 0.58), 0.025, 0.025, 6, Color(0.45, 0.35, 0.25), 3, 0.08)

static func _kennel(p: Parts, lod: int) -> void:
	# a dog kennel: a painted timber gable-roof house, 1.0 m wide, 1.3 m deep, 1.0 m high, with an arched door and a raised floor
	p.part("body")
	var wd := p.b("wood")
	var pn := p.b("paint_matte")
	var paint := Color(0.46, 0.14, 0.1, 0.45)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			NewModels3._boxy(wd, Vector3(sx * 0.45, 0.05, sz * 0.6), Vector3(0.12, 0.1, 0.12), 0.0, Color(0.45, 0.4, 0.34))
	NewModels3._boxy(wd, Vector3(0, 0.13, 0.0), Vector3(1.0, 0.06, 1.3), 0.0, Color(0.4, 0.32, 0.22))
	# the walls: two sides and a back as boards; the front with a door opening (an arch from stacked boxes)
	var nb := 10 if lod < 2 else 3
	for sx in [-1.0, 1.0]:
		_pboxy(pn, Vector3(sx * 0.485, 0.55, 0.0), Vector3(0.03, 0.82, 1.3), 0.0, paint)
	_pboxy(pn, Vector3(0, 0.55, 0.635), Vector3(1.0, 0.82, 0.03), 0.0, paint)
	# front gable wall: left and right of the door, above it, and the triangle
	_pboxy(pn, Vector3(-0.36, 0.5, -0.635), Vector3(0.28, 0.74, 0.03), 0.0, paint)
	_pboxy(pn, Vector3(0.36, 0.5, -0.635), Vector3(0.28, 0.74, 0.03), 0.0, paint)
	_pboxy(pn, Vector3(0, 0.84, -0.635), Vector3(0.5, 0.18, 0.03), 0.0, paint)
	# the gable triangles in front and back
	for sz in [-1.0, 1.0]:
		var a := Vector3(-0.5, 0.96, sz * 0.65); var b := Vector3(0.5, 0.96, sz * 0.65); var c := Vector3(0, 1.4, sz * 0.65)
		pn.tri(a, b, c, paint, Vector3(0, 0, sz)); pn.tri(a, c, b, paint, Vector3(0, 0, -sz))
	# the roof: two sloped planks with felt, a ridge cap
	var roof_c := Color(0.12, 0.12, 0.13, 0.5)
	for sx in [-1.0, 1.0]:
		var rb := Basis(Vector3(0, 0, 1), sx * -0.78)
		_pbox(p.b("paint_matte"), Vector3(sx * 0.31, 1.2, 0.0), rb, Vector3(0.78, 0.04, 1.5), roof_c)
	_pboxy(p.b("paint_matte"), Vector3(0, 1.42, 0.0), Vector3(0.08, 0.05, 1.5), 0.0, Color(0.1, 0.1, 0.11, 0.5))
	if lod < 2:
		# trim round the door and a little name board above it
		for sx in [-1.0, 1.0]:
			NewModels3._boxy(wd, Vector3(sx * 0.225, 0.43, -0.655), Vector3(0.03, 0.62, 0.03), 0.0, Color(0.9, 0.88, 0.8, 0.45))
		NewModels3._boxy(wd, Vector3(0, 0.75, -0.655), Vector3(0.45, 0.04, 0.03), 0.0, Color(0.9, 0.88, 0.8, 0.45))
		# the interior floor shows through the door: a dark mat
		_pboxy(p.b("paint_matte"), Vector3(0, 0.17, 0.0), Vector3(0.7, 0.02, 0.9), 0.0, Color(0.12, 0.09, 0.07, 0.3))

static func _telegraph_wire(p: Parts, lod: int) -> void:
	# one span of telegraph wire, 10 m along +x from the insulator at the origin, drooping 0.35 m at the middle (a catenary); hang many from poles
	p.part("body")
	var n: int = [24, 10, 4][lod]
	var pts: Array = []
	for i in n + 1:
		var t: float = float(i) / n
		var sag: float = 0.35 * 4.0 * t * (1.0 - t)
		pts.append(Vector3(10.0 * t, -sag, 0.0))
	_limb(p.b("steel"), pts, 0.005, 0.005, 4 if lod < 2 else 3, Color(0.2, 0.2, 0.21), 1.0, Color(0.2, 0.2, 0.21), Transform3D.IDENTITY, 0)

static func _gate_hanging(p: Parts, lod: int) -> void:
	# a farm field gate hung on a timber post, open 50 degrees: five-bar timber with a diagonal brace, galvanised hinges and latch, a little sag on its free end
	p.part("body")
	var wd := p.b("wood")
	var st := p.b("steel")
	var zn := Color(0.6, 0.62, 0.62)
	var wcol := Color(0.46, 0.38, 0.28)
	NewModels3._prism(wd, Vector3(0, 0, 0), Vector3(0, 1.7, 0), 0.12, 0.11, _seg(lod, 10, 7, 5), Color(0.38, 0.3, 0.22), 3, 0.1)
	var T := Transform3D(Basis(Vector3.UP, deg_to_rad(-50.0)) * Basis(Vector3(0, 0, 1), deg_to_rad(-2.0)), Vector3(0.0, 0.0, 0.0))
	var Lg := 3.3
	var bars := [0.28, 0.5, 0.78, 1.04, 1.28]
	for i in bars.size():
		var y: float = bars[i]
		NewModels3._boxb(wd, T * Vector3(0.18 + Lg * 0.5, y, 0.0), T.basis, Vector3(Lg, 0.1, 0.04), wcol.lerp(Color(0.55, 0.45, 0.33), NewModels3._rnd(i, 14.0)))
	for x in [0.2, Lg * 0.5, Lg + 0.1]:
		NewModels3._boxb(wd, T * Vector3(x, 0.78, 0.0), T.basis, Vector3(0.09, 1.1, 0.06), wcol)
	# the diagonal brace from the bottom of the hinge stile to the top of the head
	var da := T * Vector3(0.2, 0.28, 0.035); var db := T * Vector3(Lg + 0.05, 1.28, 0.035)
	NewModels3._prism(wd, da, db, 0.035, 0.035, 5, Color(0.5, 0.4, 0.3), 3, 0.08)
	if lod < 2:
		for y in [0.4, 1.15]:
			NewModels3._boxb(st, T * Vector3(0.05, y, 0.0), T.basis, Vector3(0.45, 0.035, 0.012), zn)
			NewModels3._prism(st, Vector3(0, y - 0.03, 0.0), Vector3(0, y + 0.05, 0.0), 0.012, 0.012, 5, zn, 3, 0.02)
		NewModels3._boxb(st, T * Vector3(Lg + 0.1, 0.78, 0.045), T.basis, Vector3(0.06, 0.18, 0.012), zn)

# ================================================================== colliders
## Box strips a drone can hit, in the model's frame.
static func colliders(name: String) -> Array:
	match name:
		"cow_a", "cow_b": return [AABB(Vector3(-0.32, 0.0, -1.1), Vector3(0.64, 1.5, 2.3)), AABB(Vector3(-0.2, 0.6, -1.6), Vector3(0.4, 0.8, 0.6))]
		"cow_c": return [AABB(Vector3(-0.4, 0.0, -1.1), Vector3(0.8, 1.0, 2.3))]
		"calf_a": return [AABB(Vector3(-0.2, 0.0, -0.7), Vector3(0.4, 0.95, 1.4))]
		"sheep_a", "sheep_b": return [AABB(Vector3(-0.22, 0.0, -0.45), Vector3(0.44, 0.85, 0.95))]
		"lamb_a": return [AABB(Vector3(-0.14, 0.0, -0.26), Vector3(0.28, 0.5, 0.55))]
		"horse_a", "horse_b": return [AABB(Vector3(-0.28, 0.0, -0.85), Vector3(0.56, 1.6, 1.8))]
		"dog_a": return [AABB(Vector3(-0.1, 0.0, -0.3), Vector3(0.2, 0.6, 0.7))]
	return []

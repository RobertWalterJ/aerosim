class_name NewModels
extends RefCounted
## The models for the new experiences (SPEC-NEW-EXPERIENCES.md), all drawn by code with the DroneParts kit: the FPV plane,
## four birds with their wing beat, a hot-air balloon, a white-tailed deer, a firework shell and a launch barge.
## Real metres. Forward is -z, up is +y, x is right. The contract (what each function returns) is game/README-models.md.
## Each model is one mesh per material (few draw calls, light on a phone) and is kept once made, so asking again is free.
## Colours that vary over a part (feathers, fur, gores, paint) are vertex colours, painted face by face so patches stay crisp.

static var _cache := {}
static var _mats := {}

# ================================================================== materials
## Shared materials. The vertex-coloured ones take their colour from the mesh.
static func _mat(key: String) -> StandardMaterial3D:
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	if key in ["wing", "prop", "bird", "fur", "fabric", "wicker", "paint"]:
		m.vertex_color_use_as_albedo = true; m.vertex_color_is_srgb = true
	match key:
		"foam": m.albedo_color = Color(0.93, 0.93, 0.91); m.roughness = 0.7
		"wing": m.roughness = 0.5                     # laminated foam: a soft sheen
		"canopy": m.albedo_color = Color(0.03, 0.035, 0.05); m.roughness = 0.06; m.metallic = 0.4
		"carbon": m.albedo_color = Color(0.05, 0.053, 0.06); m.roughness = 0.3; m.metallic = 0.35
		"black": m.albedo_color = Color(0.035, 0.035, 0.04); m.roughness = 0.6
		"metal": m.albedo_color = Color(0.66, 0.68, 0.72); m.roughness = 0.3; m.metallic = 0.9
		"dark_metal": m.albedo_color = Color(0.16, 0.17, 0.19); m.roughness = 0.35; m.metallic = 0.8
		"glass": m.albedo_color = Color(0.02, 0.03, 0.06); m.roughness = 0.05; m.metallic = 0.9
		"prop": m.roughness = 0.4
		"bird": m.roughness = 0.85; m.metallic_specular = 0.3; m.cull_mode = BaseMaterial3D.CULL_DISABLED   # thin primaries are single sheets
		"fur": m.roughness = 0.92; m.metallic_specular = 0.25
		"fabric": m.roughness = 0.62; m.cull_mode = BaseMaterial3D.CULL_DISABLED       # the inside shows through the mouth
		"wicker": m.roughness = 0.9; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"paint": m.roughness = 0.75
	_mats[key] = m
	return m

# ================================================================== helpers
static func _xf(pos: Vector3, rot := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot), pos)

## A repeatable pseudo-random number in 0..1 from a position (for mottling and speckles).
static func _h(p: Vector3) -> float:
	return fposmod(sin(p.x * 127.1 + p.y * 311.7 + p.z * 74.7) * 43758.5453, 1.0)

## A colour made a little lighter or darker at random, so large areas do not look flat.
static func _vary(c: Color, p: Vector3, amt: float) -> Color:
	var k := 1.0 + amt * (_h(p) - 0.5) * 2.0
	return Color(clampf(c.r * k, 0.0, 1.0), clampf(c.g * k, 0.0, 1.0), clampf(c.b * k, 0.0, 1.0))

## Colour a part face by face: f(centre, normal) -> Color is asked once per triangle, so patches keep crisp edges.
static func _paint(data: Array, f: Callable) -> Array:
	var pos: PackedVector3Array = data[0]
	var nrm: PackedVector3Array = data[1]
	var cols := PackedColorArray(); cols.resize(pos.size())
	for k in range(0, pos.size(), 3):
		var c := (pos[k] + pos[k + 1] + pos[k + 2]) / 3.0
		var n := (nrm[k] + nrm[k + 1] + nrm[k + 2]).normalized()
		var col: Color = f.call(c, n)
		cols[k] = col; cols[k + 1] = col; cols[k + 2] = col
	return [pos, nrm, cols]

## A box centred on the origin with flat faces (12 triangles).
static func _box(size: Vector3) -> Array:
	var hx := size.x * 0.5; var hz := size.z * 0.5
	return DroneParts.extrude(PackedVector2Array([Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]), -size.y * 0.5, size.y * 0.5)

## A tiny octahedron (8 triangles): eyes and other dots.
static func _dot(c: Vector3, r: float) -> Array:
	var v := [Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, r, 0), Vector3(0, -r, 0), Vector3(0, 0, r), Vector3(0, 0, -r)]
	var faces := [[0, 2, 4], [2, 1, 4], [1, 3, 4], [3, 0, 4], [2, 0, 5], [1, 2, 5], [3, 1, 5], [0, 3, 5]]
	var pos := PackedVector3Array(); var nrm := PackedVector3Array(); var cols := PackedColorArray()
	for f in faces:
		var a: Vector3 = v[f[0]]; var b: Vector3 = v[f[1]]; var d: Vector3 = v[f[2]]
		var n := (a + b + d).normalized()
		DroneParts._tri(pos, nrm, cols, c + a, c + b, c + d, n, n, n, Color.WHITE, Color.WHITE, Color.WHITE)
	return [pos, nrm]

## A wing section loop: the upper surface from u0 to u1 along the chord, then the lower surface back. y is a fraction of the
## chord: NACA thickness tc with a parabolic camber line. A cut end (a hinge line) gets crisp corners.
static func _section(tc: float, camber: float, m: int, u0 := 0.0, u1 := 1.0) -> PackedVector2Array:
	var up := PackedVector2Array(); var lo := PackedVector2Array()
	for k in m + 1:
		var s := float(k) / m
		var u := u1 * (1.0 - cos(s * PI * 0.5)) if u0 == 0.0 else lerpf(u0, u1, s)   # close spacing round a leading edge
		var yc := camber * 4.0 * u * (1.0 - u)
		var yt := 5.0 * tc * (0.2969 * sqrt(u) - 0.126 * u - 0.3516 * u * u + 0.2843 * u * u * u - 0.1036 * u * u * u * u)
		up.append(Vector2(u, yc + yt)); lo.append(Vector2(u, yc - yt))
	var out := PackedVector2Array()
	if u0 > 0.0: out.append(up[0])
	out.append_array(up)
	if u1 < 1.0:
		out.append(up[m]); out.append(lo[m])
	var stop := 0 if u0 > 0.0 else 1
	for k in range(m, stop - 1, -1): out.append(lo[k])
	if u0 > 0.0: out.append(lo[0])
	return out

## A lifting surface (wing, tail, fin, ear, bird wing): a closed section loop (x along the chord 0..1, y across) swept
## through stations [leading edge point, chord vector, thickness vector]. Both ends are closed flat.
static func _foil(stations: Array, loop: PackedVector2Array) -> Array:
	var rows: Array = []
	var cens: Array[Vector3] = []
	var nj := loop.size()
	for st in stations:
		var o: Vector3 = st[0]; var cv: Vector3 = st[1]; var tv: Vector3 = st[2]
		var r := PackedVector3Array()
		var cen := Vector3.ZERO
		for q in loop:
			var p := o + cv * q.x + tv * q.y
			r.append(p); cen += p
		rows.append(r); cens.append(cen / nj)
	return _closed_grid(rows, cens, false)

## Rows of rings into a closed surface: the first and last rings are repeated (a crease) and pinched to their middles.
static func _closed_grid(rows: Array, cens: Array[Vector3], closed_i: bool) -> Array:
	var r2: Array = []
	var c2: Array[Vector3] = []
	var nj := (rows[0] as PackedVector3Array).size()
	if not closed_i:
		var c0 := PackedVector3Array(); c0.resize(nj); c0.fill(cens[0])
		r2.append(c0); r2.append(rows[0]); c2.append(cens[0]); c2.append(cens[0])
	r2.append_array(rows); c2.append_array(cens)
	if not closed_i:
		var c1 := PackedVector3Array(); c1.resize(nj); c1.fill(cens[-1])
		r2.append(rows[-1]); r2.append(c1); c2.append(cens[-1]); c2.append(cens[-1])
	var hint := func(i: int, _j: int, p: Vector3) -> Vector3: return p - c2[i]
	return DroneParts.grid(r2, closed_i, true, hint)

## A limb, neck or tail swept along a polyline: an elliptical ring at each point, rx across (sideways) and ry in the plane
## of the bend. ref is any direction not along the limb (it sets which way is "across").
static func _sweep(pts: Array, rx: Array, ry: Array, seg: int, ref := Vector3.UP, closed := false) -> Array:
	var n := pts.size()
	var rows: Array = []
	var cens: Array[Vector3] = []
	for i in n:
		var p: Vector3 = pts[i]
		var d := Vector3.ZERO
		if closed: d = (pts[(i + 1) % n] as Vector3) - (pts[(i - 1 + n) % n] as Vector3)
		elif i == 0: d = (pts[1] as Vector3) - p
		elif i == n - 1: d = p - (pts[n - 2] as Vector3)
		else: d = (pts[i + 1] as Vector3) - (pts[i - 1] as Vector3)
		d = d.normalized()
		var side := ref.cross(d)
		if side.length_squared() < 1e-6: side = Vector3.RIGHT.cross(d)
		side = side.normalized()
		var up := d.cross(side)
		var r := PackedVector3Array(); r.resize(seg)
		for j in seg:
			var a := TAU * j / seg
			r[j] = p + side * (cos(a) * float(rx[i])) + up * (sin(a) * float(ry[i]))
		rows.append(r); cens.append(p)
	return _closed_grid(rows, cens, closed)

## The area of a polygon (for picking the outer outline after a union).
static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for k in poly.size():
		var p := poly[k]; var q := poly[(k + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5

## One outline from many overlapping ones (the shadow and chooser silhouette).
static func _union(polys: Array) -> PackedVector2Array:
	var acc: PackedVector2Array = polys[0]
	for k in range(1, polys.size()):
		var merged := Geometry2D.merge_polygons(acc, polys[k])
		var best := 0.0
		for poly in merged:
			var a := _area(poly)
			if a > best: best = a; acc = poly
	return acc

# ================================================================== the FPV plane
# A foam pod-and-boom FPV trainer of the Ranger / Talon kind: a white pod with the camera in its nose, a high orange wing,
# a pusher motor on a pylon behind the wing (so the nose camera sees no propeller), a carbon boom and a conventional tail.
const P_DIH := 3.0                       # dihedral each side, degrees
const P_INC := 2.0                       # wing incidence, degrees
const P_ROOT_C := 0.205                  # wing chord at the root, m
const P_TIP_C := 0.155
const P_HALF := 0.552                    # half span, m
const P_LE_Z := -0.065                   # leading edge at the root (the centre of mass sits near 30 % of the chord)
const P_WING_Y := 0.06
const P_PROP_R := 0.095                  # a 7.5 inch folding prop
const P_PIVOT := Vector3(0.0, 0.1, 0.239)
const P_CAMERA := Vector3(0.0, 0.004, -0.417)
const P_STAB_Y := 0.017
const P_BOOM_A := Vector3(0.0, -0.025, 0.12)
const P_BOOM_B := Vector3(0.0, 0.008, 0.645)
const P_POD := [[-0.405, 0.0, 0.004, 0.014, 0.014], [-0.4, 0.0, 0.004, 0.024, 0.025], [-0.388, 0.0, 0.004, 0.032, 0.034], [-0.375, 0.0, 0.005, 0.036, 0.039],
	[-0.34, 0.0, 0.006, 0.041, 0.044], [-0.27, 0.0, 0.007, 0.045, 0.049], [-0.17, 0.0, 0.008, 0.047, 0.051], [-0.06, 0.0, 0.008, 0.047, 0.051],
	[0.04, 0.0, 0.009, 0.044, 0.047], [0.12, 0.0, 0.013, 0.036, 0.04], [0.17, 0.0, 0.018, 0.026, 0.031], [0.195, 0.0, 0.022, 0.014, 0.019], [0.202, 0.0, 0.023, 0.004, 0.006]]

static func _p_chord(x: float) -> float:
	return P_ROOT_C if x <= 0.24 else lerpf(P_ROOT_C, P_TIP_C, clampf((x - 0.24) / 0.295, 0.0, 1.0))

static func _p_le(x: float) -> float:
	return P_LE_Z + 0.025 * pow(minf(x, P_HALF) / P_HALF, 2.0)     # the leading edge sweeps back a little towards the tip

## A wing station at span x (0 at the centre line): [leading edge, chord vector, thickness vector]. cfrac, back and ts shrink
## the chord, move the leading edge back and thin the section for the rounded tip.
static func _p_st(sx: float, x: float, cfrac := 1.0, back := 0.0, ts := 1.0) -> Array:
	var c := _p_chord(x)
	var inc := deg_to_rad(P_INC)
	var rot := Basis(Vector3(0, 0, 1), deg_to_rad(P_DIH) * sx)
	var le := Vector3(sx * x, P_WING_Y + x * tan(deg_to_rad(P_DIH)), _p_le(x) + back)
	return [le, Vector3(0, -sin(inc), cos(inc)) * c * cfrac, rot * Vector3(0, cos(inc), sin(inc)) * c * ts]

## Tailplane station at span x.
static func _stab_st(x: float, cfrac := 1.0, back := 0.0, ts := 1.0) -> Array:
	var t := clampf(absf(x) / 0.165, 0.0, 1.0)
	var c := lerpf(0.12, 0.09, t)
	return [Vector3(x, P_STAB_Y, lerpf(0.505, 0.525, t) + back), Vector3(0, 0, c * cfrac), Vector3(0, c * ts, 0)]

## Fin station at height y.
static func _fin_st(y: float, cfrac := 1.0, back := 0.0, ts := 1.0) -> Array:
	var t := clampf((y - 0.02) / 0.135, 0.0, 1.0)
	var c := lerpf(0.15, 0.082, t)
	return [Vector3(0, y, lerpf(0.47, 0.538, t) + back), Vector3(0, 0, c * cfrac), Vector3(c * ts, 0, 0)]

static func plane() -> Dictionary:
	if _cache.has("plane"): return _cache["plane"]
	var kit := DroneParts.Kit.new(); kit.record = true
	var foam := _mat("foam"); var wing := _mat("wing"); var black := _mat("black")
	var wcol := func(p: Vector3, n: Vector3) -> Color:
		if n.y < -0.3 and absf(p.x) > 0.42: return Color(0.03, 0.03, 0.035)     # black tips underneath, so the attitude reads from below
		return Color(1.0, 0.4, 0.03)
	# ---- the pod: rounded nose with the camera, a smoked canopy hatch on top, tapering into the boom
	kit.add(foam, DroneParts.loft(P_POD, 2.5, 28, true))
	var cap: Array = []
	for s in P_POD:
		if float(s[0]) <= -0.374: cap.append([float(s[0]) - (0.0015 if cap.is_empty() else 0.0), 0.0, s[2], float(s[3]) + 0.0015, float(s[4]) + 0.0015])
	kit.add(black, DroneParts.loft(cap, 2.5, 28, true), Transform3D.IDENTITY, Color.WHITE, "none")   # the camera pod in the nose
	var canopy := [[-0.35, 0.0, 0.038, 0.012, 0.008], [-0.325, 0.0, 0.042, 0.027, 0.017], [-0.28, 0.0, 0.045, 0.034, 0.023], [-0.2, 0.0, 0.046, 0.035, 0.024],
		[-0.13, 0.0, 0.045, 0.03, 0.018], [-0.09, 0.0, 0.043, 0.016, 0.01]]
	kit.add(_mat("canopy"), DroneParts.loft(canopy, 2.5, 24, true))
	var lens := DroneParts.crisp(PackedVector2Array([Vector2(0, 0), Vector2(0.0075, 0), Vector2(0.0075, 0.009), Vector2(0.0062, 0.011), Vector2(0, 0.011)]))
	kit.add(_mat("dark_metal"), DroneParts.lathe(lens, 16), _xf(Vector3(0, 0.004, -0.405), Vector3(-PI * 0.5, 0, 0)), Color.WHITE, "none")
	kit.add(_mat("glass"), DroneParts.lathe(PackedVector2Array([Vector2(0, 0.001), Vector2(0.0052, 0.0)]), 14), _xf(Vector3(0, 0.004, -0.4165), Vector3(-PI * 0.5, 0, 0)), Color.WHITE, "none")
	kit.add(black, _box(Vector3(0.022, 0.006, 0.26)), _xf(Vector3(0, -0.046, -0.12)), Color.WHITE, "side")     # belly skid
	# ---- the wing: Clark-Y-like section (11.5 % thick), 2 degrees incidence, 3 degrees dihedral, ailerons on the outer half
	var full := _section(0.115, 0.035, 9)
	var fore := _section(0.115, 0.035, 9, 0.0, 0.74)
	var aft := _section(0.115, 0.035, 4, 0.765, 1.0)
	for sx in [-1.0, 1.0]:
		kit.add(wing, _paint(_foil([_p_st(sx, 0.0), _p_st(sx, 0.08), _p_st(sx, 0.16), _p_st(sx, 0.245)], full), wcol))
		kit.add(wing, _paint(_foil([_p_st(sx, 0.245), _p_st(sx, 0.38), _p_st(sx, 0.52)], fore), wcol))
		kit.add(wing, _paint(_foil([_p_st(sx, 0.249), _p_st(sx, 0.38), _p_st(sx, 0.516)], aft), wcol))
		kit.add(wing, _paint(_foil([_p_st(sx, 0.52), _p_st(sx, 0.535, 0.93, 0.006, 0.85), _p_st(sx, 0.546, 0.75, 0.022, 0.6), _p_st(sx, 0.552, 0.45, 0.055, 0.3)], full), wcol))
		# aileron servo, horn and pushrod under the wing
		var wy := P_WING_Y + 0.31 * tan(deg_to_rad(P_DIH))
		kit.add(black, _box(Vector3(0.012, 0.008, 0.024)), _xf(Vector3(sx * 0.3, wy - 0.0, 0.015)), Color.WHITE, "none")
		kit.add(black, _box(Vector3(0.003, 0.012, 0.014)), _xf(Vector3(sx * 0.32, wy - 0.008, 0.094)), Color.WHITE, "none")
		kit.add(_mat("metal"), DroneParts.tube(Vector3(sx * 0.305, wy - 0.006, 0.026), Vector3(sx * 0.32, wy - 0.012, 0.09), 0.0008, 0.0008, 4), Transform3D.IDENTITY, Color.WHITE, "none")
	kit.add(_mat("dark_metal"), _box(Vector3(0.028, 0.009, 0.028)), _xf(Vector3(0, 0.081, 0.0)), Color.WHITE, "none")      # GPS puck on the wing
	# ---- pylon and pusher motor behind the wing
	var pylon := [[0.12, 0.0, 0.07, 0.006, 0.012], [0.14, 0.0, 0.08, 0.015, 0.03], [0.18, 0.0, 0.085, 0.017, 0.034], [0.205, 0.0, 0.088, 0.017, 0.03]]
	kit.add(foam, DroneParts.loft(pylon, 3.0, 16, true))
	kit.add(black, _box(Vector3(0.036, 0.036, 0.004)), _xf(Vector3(0, P_PIVOT.y, 0.205)), Color.WHITE, "side")
	var to_back := Basis(Vector3.RIGHT, PI * 0.5)           # a turned part's +y onto +z (backwards)
	var mb := Vector3(0, P_PIVOT.y, 0.207)
	kit.add(_mat("dark_metal"), DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, 0), Vector2(0.013, 0), Vector2(0.013, 0.004), Vector2(0, 0.004)])), 18), Transform3D(to_back, mb))
	var bell := PackedVector2Array([Vector2(0.0135, 0.004), Vector2(0.014, 0.006), Vector2(0.014, 0.021), Vector2(0.012, 0.025), Vector2(0.004, 0.026), Vector2(0.004, 0.03), Vector2(0, 0.03)])
	kit.add(_mat("metal"), DroneParts.lathe(DroneParts.crisp(bell), 20), Transform3D(to_back, mb))
	kit.add(wing, DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0.0139, 0.011), Vector2(0.0143, 0.011), Vector2(0.0143, 0.016), Vector2(0.0139, 0.016)])), 20), Transform3D(to_back, mb), Color(1.0, 0.4, 0.03), "none")
	# video antenna on the pylon, receiver whiskers under the pod
	kit.add(black, DroneParts.tube(Vector3(0, 0.115, 0.165), Vector3(0, 0.165, 0.185), 0.0028, 0.0022, 8), Transform3D.IDENTITY, Color.WHITE, "side")
	kit.add(black, DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, -0.003), Vector2(0.01, -0.003), Vector2(0.01, 0.003), Vector2(0, 0.003)])), 14), _xf(Vector3(0, 0.168, 0.186), Vector3(-0.38, 0, 0)), Color.WHITE, "side")
	for sx in [-1.0, 1.0]:
		kit.add(black, DroneParts.tube(Vector3(sx * 0.03, -0.035, -0.04), Vector3(sx * 0.075, -0.06, 0.02), 0.0009, 0.0007, 4), Transform3D.IDENTITY, Color.WHITE, "none")
	# ---- boom and tail
	kit.add(_mat("carbon"), DroneParts.tube(P_BOOM_A, P_BOOM_B, 0.0075, 0.0075, 12))
	kit.add(black, _box(Vector3(0.028, 0.012, 0.09)), _xf(Vector3(0, 0.009, 0.565)), Color.WHITE, "none")      # tail mount
	var tail := _section(0.07, 0.0, 6)
	var tail_f := _section(0.07, 0.0, 6, 0.0, 0.66)
	var tail_a := _section(0.07, 0.0, 3, 0.68, 1.0)
	var fin_f := _section(0.07, 0.0, 6, 0.0, 0.6)
	var fin_a := _section(0.07, 0.0, 3, 0.63, 1.0)
	for sx in [-1.0, 1.0]:
		kit.add(wing, _paint(_foil([_stab_st(0.0), _stab_st(sx * 0.09), _stab_st(sx * 0.165)], tail_f), wcol))
		kit.add(wing, _paint(_foil([_stab_st(sx * 0.165), _stab_st(sx * 0.172, 0.9, 0.006, 0.8), _stab_st(sx * 0.178, 0.65, 0.022, 0.55), _stab_st(sx * 0.181, 0.35, 0.05, 0.3)], tail), wcol))
	kit.add(wing, _paint(_foil([_stab_st(-0.163), _stab_st(-0.08), _stab_st(0.0), _stab_st(0.08), _stab_st(0.163)], tail_a), wcol))     # elevator
	kit.add(wing, _paint(_foil([_fin_st(0.02), _fin_st(0.09), _fin_st(0.155)], fin_f), wcol))
	kit.add(wing, _paint(_foil([_fin_st(0.155), _fin_st(0.162, 0.9, 0.006, 0.8), _fin_st(0.168, 0.65, 0.022, 0.55), _fin_st(0.171, 0.35, 0.05, 0.3)], tail), wcol))
	kit.add(wing, _paint(_foil([_fin_st(0.026), _fin_st(0.09), _fin_st(0.153)], fin_a), wcol))      # rudder
	kit.add(black, _foil([[Vector3(0, -0.002, 0.555), Vector3(0, 0, 0.075), Vector3(0.075, 0, 0)], [Vector3(0, -0.038, 0.585), Vector3(0, 0, 0.04), Vector3(0.032, 0, 0)]], _section(0.08, 0.0, 4)))   # tail skid
	# control horns and pushrods along the boom
	kit.add(black, _box(Vector3(0.012, 0.012, 0.003)), _xf(Vector3(0.012, 0.005, 0.6), Vector3(0, 0, 0)), Color.WHITE, "none")
	kit.add(black, _box(Vector3(0.012, 0.003, 0.012)), _xf(Vector3(-0.008, 0.05, 0.6)), Color.WHITE, "none")
	kit.add(_mat("metal"), DroneParts.tube(Vector3(0.012, -0.02, 0.17), Vector3(0.012, 0.0, 0.598), 0.0008, 0.0008, 4), Transform3D.IDENTITY, Color.WHITE, "none")
	kit.add(_mat("metal"), DroneParts.tube(Vector3(-0.012, -0.02, 0.17), Vector3(-0.012, 0.05, 0.598), 0.0008, 0.0008, 4), Transform3D.IDENTITY, Color.WHITE, "none")
	# ---- the folding propeller: its own mesh, spinning about its own +z at prop_pivot
	var spec := {"R": P_PROP_R, "n": 2, "root": 0.021, "c_root": 0.16, "c_max": 0.19, "t_max": 0.3, "c_tip": 0.11, "sweep": 0.06, "pd": 0.62, "tc": 0.12,
		"col": Color(0.07, 0.07, 0.075), "tip_col": Color(0.07, 0.07, 0.075)}
	var pk := DroneParts.Kit.new()
	var pm := _mat("prop")
	var bl := DroneParts.blade(spec, 1)
	var to_z := Basis(Vector3.RIGHT, -PI * 0.5)       # the blade's spin axis (+y) onto -z, so it pushes forward
	for b in 2:
		var bb := Basis(Vector3(0, 0, 1), PI * b) * to_z
		pk.add(pm, bl, Transform3D(bb, Vector3.ZERO), Color.WHITE, "none")
		kit.outline_only(bl, Transform3D(bb, P_PIVOT))
	pk.add(pm, _box(Vector3(0.05, 0.011, 0.01)), Transform3D.IDENTITY, Color(0.13, 0.13, 0.14), "none")        # folding yoke
	for sx in [-1.0, 1.0]:
		pk.add(pm, DroneParts.tube(Vector3(sx * 0.019, 0, -0.007), Vector3(sx * 0.019, 0, 0.007), 0.0022, 0.0022, 6), Transform3D.IDENTITY, Color(0.62, 0.63, 0.66), "none")
	var spin := PackedVector2Array([Vector2(0, 0), Vector2(0.013, 0), Vector2(0.012, 0.008), Vector2(0.009, 0.016), Vector2(0.004, 0.022), Vector2(0, 0.024)])
	pk.add(pm, DroneParts.lathe(spin, 16), Transform3D(to_back, Vector3(0, 0, 0.005)), Color(0.75, 0.76, 0.78), "none")
	var prop_mesh := pk.commit()
	# ---- silhouettes for the shadow and the chooser
	var le_pts := PackedVector2Array(); var te_pts := PackedVector2Array()
	var tipst := [[0.0, 1.0, 0.0], [0.245, 1.0, 0.0], [0.52, 1.0, 0.0], [0.535, 0.93, 0.006], [0.546, 0.75, 0.022], [0.552, 0.45, 0.055]]
	for sx in [-1.0, 1.0]:
		for k in tipst.size():
			var q: Array = tipst[k] if sx > 0.0 else tipst[tipst.size() - 1 - k]
			var x: float = q[0]
			var le := _p_le(x) + float(q[2])
			le_pts.append(Vector2(sx * x, le)); te_pts.append(Vector2(sx * x, le + _p_chord(x) * float(q[1]) * cos(deg_to_rad(P_INC))))
	te_pts.reverse(); le_pts.append_array(te_pts)
	var pod_plan := PackedVector2Array(); var pod_l := PackedVector2Array()
	var pod_side := PackedVector2Array(); var pod_lo := PackedVector2Array()
	for s in P_POD:
		pod_plan.append(Vector2(s[3], s[0])); pod_l.append(Vector2(-float(s[3]), s[0]))
		pod_side.append(Vector2(s[0], float(s[2]) + float(s[3 + 1]))); pod_lo.append(Vector2(s[0], float(s[2]) - float(s[4])))
	pod_l.reverse(); pod_plan.append_array(pod_l)
	pod_lo.reverse(); pod_side.append_array(pod_lo)
	var rect := func(a: Vector2, b: Vector2) -> PackedVector2Array: return PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)])
	var plan_sil := _union([pod_plan, le_pts, rect.call(Vector2(-0.0075, 0.1), Vector2(0.0075, P_BOOM_B.z)),
		PackedVector2Array([Vector2(-0.181, 0.555), Vector2(-0.165, 0.525), Vector2(0, 0.505), Vector2(0.165, 0.525), Vector2(0.181, 0.555), Vector2(0.165, 0.615), Vector2(0, 0.625), Vector2(-0.165, 0.615)]),
		rect.call(Vector2(-0.017, 0.12), Vector2(0.017, 0.236)), rect.call(Vector2(-P_PROP_R, 0.232), Vector2(P_PROP_R, 0.246))])
	var bt := (Vector2(P_BOOM_B.z, P_BOOM_B.y) - Vector2(P_BOOM_A.z, P_BOOM_A.y)).normalized()
	var bn := Vector2(-bt.y, bt.x) * 0.0075
	var ba := Vector2(P_BOOM_A.z, P_BOOM_A.y); var bb2 := Vector2(P_BOOM_B.z, P_BOOM_B.y)
	var side_sil := _union([pod_side,
		PackedVector2Array([Vector2(-0.35, 0.04), Vector2(-0.28, 0.068), Vector2(-0.2, 0.07), Vector2(-0.09, 0.053), Vector2(-0.09, 0.04)]),
		PackedVector2Array([Vector2(-0.065, 0.06), Vector2(-0.03, 0.074), Vector2(0.0, 0.077), Vector2(0.14, 0.055), Vector2(0.0, 0.052)]),
		rect.call(Vector2(0.12, 0.05), Vector2(0.207, 0.119)), rect.call(Vector2(0.205, 0.086), Vector2(0.236, 0.114)),
		rect.call(Vector2(0.231, P_PIVOT.y - P_PROP_R), Vector2(0.247, P_PIVOT.y + P_PROP_R)),
		PackedVector2Array([ba + bn, bb2 + bn, bb2 - bn, ba - bn]),
		rect.call(Vector2(0.505, 0.011), Vector2(0.625, 0.023)),
		PackedVector2Array([Vector2(0.47, 0.02), Vector2(0.538, 0.155), Vector2(0.588, 0.171), Vector2(0.617, 0.168), Vector2(0.62, 0.155), Vector2(0.62, 0.02)]),
		PackedVector2Array([Vector2(0.555, -0.002), Vector2(0.585, -0.038), Vector2(0.625, -0.038), Vector2(0.63, -0.002)])])
	var out := {
		"body": kit.commit(), "prop": prop_mesh, "prop_pivot": P_PIVOT, "prop_radius": P_PROP_R, "prop_chord": DroneParts.chord_at(spec, 0.7),
		"spin_sign": -1.0, "camera": P_CAMERA, "span": P_HALF * 2.0, "length": P_BOOM_B.z - P_CAMERA.z, "mass": 0.9,
		"outline_plan": plan_sil, "outline_side": side_sil, "plan": kit.plan, "side": kit.side,
	}
	_cache["plane"] = out
	return out

# ================================================================== birds
const SWAP := [0, 2, 1]

static func bird_wing_pose_count() -> int:
	return 8

## Real sizes and wing beat for the flock code: length, span (m), flap rate (beats a second, roughly) and the flap value of a
## level glide pose (wings out, neither up nor down).
static func bird_info(kind: String) -> Dictionary:
	match kind:
		"goose": return {"length": 0.98, "span": 1.76, "flap_hz": 2.8, "glide_flap": 0.25}
		"gull": return {"length": 0.57, "span": 1.36, "flap_hz": 2.8, "glide_flap": 0.25}
		"starling": return {"length": 0.21, "span": 0.38, "flap_hz": 10.0, "glide_flap": 0.25}
	return {"length": 0.51, "span": 1.26, "flap_hz": 2.5, "glide_flap": 0.25}

## A bird in one pose of its wing beat: flap 0 is the top of the stroke, 0.5 the bottom, the upstroke (0.5 to 1) folds the
## hand back. One mesh, one material (vertex colours), so a flock is one MultiMesh per pose.
static func bird(kind: String, flap: float) -> ArrayMesh:
	var f := fposmod(flap, 1.0)
	var key := "bird_%s_%.4f" % [kind, f]
	if _cache.has(key): return _cache[key]
	var s := _bird_spec(kind)
	var kit := DroneParts.Kit.new()
	var m := _mat("bird")
	var secs: Array = []
	for q in s["body"]: secs.append([q[0], 0.0, q[1], q[2], q[3]])
	kit.add(m, _paint(DroneParts.loft(secs, 2.0, int(s["seg"])), s["body_col"]))
	kit.add(m, _bird_wings(kind, s, f))
	for e in s["eyes"]:
		var ep: Vector3 = e
		for sx in [-1.0, 1.0]:
			kit.add(m, _dot(Vector3(sx * ep.x, ep.y, ep.z), float(s["eye_r"])), Transform3D.IDENTITY, Color(0.03, 0.03, 0.03))
	var mesh := kit.commit()
	_cache[key] = mesh
	return mesh

## The le and chord of a bird wing at rest at span x (from the shoulder).
static func _wing_at(wing: Array, x: float) -> Vector2:
	for k in range(1, wing.size()):
		var a: Array = wing[k - 1]; var b: Array = wing[k]
		if x <= float(b[0]) or k == wing.size() - 1:
			var t := clampf((x - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-6), 0.0, 1.0)
			return Vector2(lerpf(a[1], b[1], t), lerpf(a[2], b[2], t))
	return Vector2.ZERO

## Both wings in one pose. The right wing is made at rest (straight out along +x from the shoulder, painted), then each
## point is carried by the arm (inside the wrist) or the hand (outside it); the left wing is its mirror image.
static func _bird_wings(kind: String, s: Dictionary, flap: float) -> Array:
	var rest := _bird_wing_rest(kind, s)
	var ph := TAU * flap
	var fold := maxf(0.0, -sin(ph))                      # the upstroke: the hand sweeps back and in
	var th1 := deg_to_rad(float(s["bias1"]) + float(s["amp"]) * cos(ph))
	var th2 := deg_to_rad(float(s["bias2"]) + float(s["amp2"]) * cos(ph - 0.9))   # the hand lags the arm
	var r1 := Basis(Vector3(0, 0, 1), th1) * Basis(Vector3.UP, -deg_to_rad(float(s["fold"]) * 0.35 * fold))
	var r2 := r1 * Basis(Vector3(0, 0, 1), th2) * Basis(Vector3.UP, -deg_to_rad(float(s["fold"]) * fold))
	var wx: float = s["wrist"]
	var wv := Vector3(wx, 0, 0)
	var sh: Vector3 = s["shoulder"]
	var pos: PackedVector3Array = rest[0]; var nrm: PackedVector3Array = rest[1]; var cols: PackedColorArray = rest[2]
	var n := pos.size()
	var P := PackedVector3Array(); P.resize(n * 2)
	var N := PackedVector3Array(); N.resize(n * 2)
	var C := PackedColorArray(); C.resize(n * 2)
	for k in n:
		var p := pos[k]
		var q: Vector3; var mn: Vector3
		if p.x <= wx:
			q = r1 * p; mn = r1 * nrm[k]
		else:
			q = r1 * wv + r2 * (p - wv); mn = r2 * nrm[k]
		P[k] = sh + q; N[k] = mn; C[k] = cols[k]
		# mirroring turns the winding over, so two corners of each triangle swap places
		var k2: int = n + k - (k % 3) + int(SWAP[k % 3])
		P[k2] = Vector3(-(sh.x + q.x), sh.y + q.y, sh.z + q.z); N[k2] = Vector3(-mn.x, mn.y, mn.z); C[k2] = cols[k]
	return [P, N, C]

## The right wing at rest, painted, in the shoulder's frame: the wing surface, and the separated primaries ("fingers").
static func _bird_wing_rest(kind: String, s: Dictionary) -> Array:
	var key := "wingrest_" + kind
	if _cache.has(key): return _cache[key]
	var wing: Array = s["wing"]
	var st: Array = []
	for w in wing:
		st.append([Vector3(w[0], 0.0, w[1]), Vector3(0, 0, w[2]), Vector3(0, w[3], 0)])
	var d := _paint(_foil(st, s["loop"]), s["wing_col"])
	var pos: PackedVector3Array = d[0]; var nrm: PackedVector3Array = d[1]; var cols: PackedColorArray = d[2]
	var fg: Array = s["fingers"]            # [count, length, width, spread (deg), curl]
	var nf: int = fg[0]
	if nf > 0:
		var tip: Array = wing[-1]
		var x0: float = tip[0]
		for k in nf:
			var u := float(k) / (nf - 1)
			var a := deg_to_rad(float(fg[3]) * u)
			var dir := Vector3(cos(a), 0, sin(a))
			var perp := Vector3(-sin(a), 0, cos(a))
			var L: float = float(fg[1]) * (1.0 - 0.3 * absf(u - 0.35))
			var w: float = fg[2]
			var base := Vector3(x0 - 0.45 * L, 0.0, float(tip[1]) + float(tip[2]) * (0.15 + 0.7 * u) - 0.15 * L * u)
			var rows: Array = []
			for t in [0.0, 0.55, 1.0]:
				var c: Vector3 = base + dir * (L * t) + Vector3(0, float(fg[4]) * L * t * t, 0)
				var ww: float = w * (1.0 - 0.7 * t * t)
				rows.append(PackedVector3Array([c - perp * (ww * 0.5), c + perp * (ww * 0.5)]))
			var fd := _paint(DroneParts.grid(rows, false, false, func(_i: int, _j: int, _p: Vector3) -> Vector3: return Vector3.UP), s["wing_col"])
			pos.append_array(fd[0]); nrm.append_array(fd[1]); cols.append_array(fd[2])
	var out := [pos, nrm, cols]
	_cache[key] = out
	return out

## Each kind: body sections [z, cy, half width, half height] from bill tip to tail, the shoulder, wing stations
## [x, le_z, chord, half thickness] at rest from the shoulder, the wrist, fingers, wing-beat angles and colours.
static func _bird_spec(kind: String) -> Dictionary:
	match kind:
		"goose": return _goose()
		"gull": return _gull()
		"starling": return _starling()
	return _hawk()

const LOOP4 := [Vector2(0, 0), Vector2(0.25, 1.0), Vector2(1.0, 0.0), Vector2(0.4, -0.3)]
const LOOP6 := [Vector2(0, 0), Vector2(0.15, 0.85), Vector2(0.5, 0.7), Vector2(1.0, 0.0), Vector2(0.5, -0.1), Vector2(0.15, -0.3)]

## Canada goose: 1 m long, 1.75 m span; black head and long neck, white chinstrap, brown-grey body, pale breast, white vent
## and rump band, black tail; wings brown-grey with dark primaries that part at the tip.
static func _goose() -> Dictionary:
	var wing := [[0.0, -0.02, 0.27, 0.022], [0.14, -0.035, 0.27, 0.02], [0.3, -0.04, 0.25, 0.016], [0.45, -0.02, 0.21, 0.012], [0.62, 0.02, 0.16, 0.009], [0.74, 0.06, 0.11, 0.007]]
	var body_col := func(p: Vector3, n: Vector3) -> Color:
		var black := Color(0.045, 0.045, 0.05)
		var white := Color(0.94, 0.93, 0.9)
		if p.z < -0.505: return black
		if p.z < -0.185:
			if p.z > -0.49 and p.z < -0.425 and p.y < 0.007: return white     # chinstrap
			return black
		if p.z > 0.32: return black
		if p.z > 0.24 and n.y > 0.3: return white                             # white band over the rump
		if p.z > 0.17 and n.y < -0.1: return white                            # white under the tail
		if n.y < -0.35: return _vary(Color(0.78, 0.73, 0.65), p, 0.08)
		if n.y > 0.35: return _vary(Color(0.4, 0.34, 0.27), p, 0.25)
		if p.z < -0.06: return _vary(Color(0.72, 0.65, 0.55), p, 0.1)         # buff breast
		return _vary(Color(0.55, 0.48, 0.4), p, 0.2)
	var wing_col := func(p: Vector3, n: Vector3) -> Color:
		if p.x > 0.5: return _vary(Color(0.13, 0.11, 0.1), p, 0.2)
		if n.y < 0.0: return _vary(Color(0.45, 0.42, 0.38), p, 0.1)
		return _vary(Color(0.4, 0.34, 0.27), p, 0.25)
	return {
		"body": [[-0.56, -0.02, 0.0, 0.0], [-0.545, -0.018, 0.008, 0.006], [-0.51, -0.01, 0.014, 0.012], [-0.495, 0.0, 0.022, 0.024], [-0.46, 0.006, 0.028, 0.031],
			[-0.425, 0.0, 0.024, 0.027], [-0.37, -0.008, 0.021, 0.024], [-0.27, -0.012, 0.025, 0.029], [-0.19, -0.012, 0.045, 0.05], [-0.12, -0.012, 0.085, 0.082],
			[-0.02, -0.006, 0.105, 0.095], [0.1, 0.0, 0.1, 0.085], [0.21, 0.008, 0.075, 0.06], [0.29, 0.015, 0.055, 0.035], [0.36, 0.018, 0.05, 0.016],
			[0.42, 0.02, 0.04, 0.008], [0.425, 0.02, 0.0, 0.0]],
		"seg": 8, "shoulder": Vector3(0.06, 0.035, -0.1), "wing": wing, "wrist": 0.3, "loop": PackedVector2Array(LOOP4),
		"fingers": [3, 0.12, 0.036, 16.0, 0.12], "amp": 32.0, "bias1": 4.0, "amp2": 18.0, "bias2": -2.0, "fold": 30.0, "eyes": [], "eye_r": 0.0,
		"body_col": body_col, "wing_col": wing_col,
	}

## Herring gull: 0.57 m long, 1.36 m span; white with a pale grey back and wings, black wing tips with a white spot, a white
## trailing edge, yellow bill with a red spot. Long slim wings, crooked at the wrist in a glide.
static func _gull() -> Dictionary:
	var wing := [[0.0, -0.01, 0.17, 0.014], [0.12, -0.02, 0.17, 0.013], [0.24, -0.025, 0.16, 0.011], [0.36, 0.0, 0.13, 0.008], [0.48, 0.04, 0.09, 0.006], [0.58, 0.09, 0.04, 0.004], [0.63, 0.125, 0.01, 0.002]]
	var body_col := func(p: Vector3, n: Vector3) -> Color:
		if p.z < -0.268:
			if p.z > -0.292 and p.y < -0.01: return Color(0.85, 0.15, 0.08)      # the red spot on the lower bill
			return Color(0.96, 0.8, 0.2)
		if n.y > 0.45 and p.z > -0.13 and p.z < 0.16: return Color(0.64, 0.68, 0.72)
		return Color(0.95, 0.95, 0.94)
	var wing_col := func(p: Vector3, n: Vector3) -> Color:
		var lc := _wing_at(wing, p.x)
		var u := (p.z - lc.x) / maxf(lc.y, 0.001)
		if p.x > 0.56 and n.y > 0.0: return Color(0.95, 0.95, 0.94)           # the white "mirror" at the tip
		if p.x > 0.42: return Color(0.05, 0.05, 0.055) if n.y > -0.2 else Color(0.18, 0.18, 0.19)
		if u > 0.7: return Color(0.95, 0.95, 0.94)                            # white trailing edge
		if n.y < 0.0: return Color(0.93, 0.93, 0.93)
		return Color(0.64, 0.68, 0.72)
	return {
		"body": [[-0.315, -0.012, 0.0, 0.0], [-0.3, -0.01, 0.006, 0.009], [-0.27, -0.004, 0.009, 0.011], [-0.255, 0.004, 0.022, 0.025], [-0.225, 0.008, 0.032, 0.034],
			[-0.18, 0.0, 0.034, 0.036], [-0.12, -0.004, 0.05, 0.05], [-0.04, 0.0, 0.06, 0.058], [0.06, 0.004, 0.055, 0.05], [0.15, 0.01, 0.038, 0.03],
			[0.21, 0.014, 0.04, 0.012], [0.255, 0.014, 0.038, 0.005], [0.258, 0.014, 0.0, 0.0]],
		"seg": 8, "shoulder": Vector3(0.035, 0.022, -0.075), "wing": wing, "wrist": 0.24, "loop": PackedVector2Array(LOOP6),
		"fingers": [0, 0.0, 0.0, 0.0, 0.0], "amp": 28.0, "bias1": 8.0, "amp2": 14.0, "bias2": -14.0, "fold": 35.0,
		"eyes": [Vector3(0.027, 0.016, -0.232)], "eye_r": 0.0045, "body_col": body_col, "wing_col": wing_col,
	}

## Starling: 0.21 m long, 0.38 m span; a dark glossy teardrop with green and purple sheen and pale speckles, short pointed
## triangular wings, a short square tail, a yellow bill.
static func _starling() -> Dictionary:
	var wing := [[0.0, -0.005, 0.07, 0.005], [0.07, -0.008, 0.065, 0.004], [0.13, 0.008, 0.045, 0.003], [0.175, 0.035, 0.012, 0.0015]]
	var body_col := func(p: Vector3, n: Vector3) -> Color:
		if p.z < -0.088: return Color(0.85, 0.72, 0.2)
		var h := _h(p * 7.0)
		if h > 0.86 and n.y < 0.5: return Color(0.72, 0.66, 0.54)                 # speckle
		if h < 0.3: return Color(0.07, 0.11, 0.08)
		if h < 0.5: return Color(0.11, 0.07, 0.12)
		return Color(0.06, 0.06, 0.07)
	var wing_col := func(_p: Vector3, n: Vector3) -> Color:
		return Color(0.32, 0.3, 0.28) if n.y < 0.0 else Color(0.09, 0.08, 0.08)
	return {
		"body": [[-0.108, -0.004, 0.0, 0.0], [-0.09, -0.002, 0.004, 0.004], [-0.075, 0.003, 0.013, 0.014], [-0.045, 0.002, 0.021, 0.021], [0.0, 0.0, 0.027, 0.025],
			[0.04, 0.003, 0.016, 0.014], [0.07, 0.006, 0.018, 0.004], [0.1, 0.006, 0.02, 0.002], [0.101, 0.006, 0.0, 0.0]],
		"seg": 6, "shoulder": Vector3(0.016, 0.008, -0.03), "wing": wing, "wrist": 0.07,
		"loop": PackedVector2Array([Vector2(0, 0), Vector2(0.3, 1.0), Vector2(1.0, 0.0)]),
		"fingers": [0, 0.0, 0.0, 0.0, 0.0], "amp": 50.0, "bias1": 5.0, "amp2": 15.0, "bias2": 0.0, "fold": 45.0, "eyes": [], "eye_r": 0.0,
		"body_col": body_col, "wing_col": wing_col,
	}

## Red-tailed hawk: 0.51 m long, 1.26 m span; broad wings with five fingered primaries, a fan tail, rich brown above with pale
## mottling, cream below with a streaked belly band, a dark bar on the leading edge and barred flight feathers under the
## wing, a rufous tail.
static func _hawk() -> Dictionary:
	var wing := [[0.0, -0.02, 0.29, 0.018], [0.13, -0.04, 0.3, 0.016], [0.25, -0.045, 0.28, 0.013], [0.36, -0.03, 0.25, 0.01], [0.44, 0.0, 0.18, 0.008], [0.47, 0.03, 0.12, 0.006]]
	var body_col := func(p: Vector3, n: Vector3) -> Color:
		if p.z < -0.235: return Color(0.22, 0.22, 0.24)                              # hooked bill
		if p.z < -0.222: return Color(0.9, 0.75, 0.25)                               # yellow cere
		if p.z > 0.13:
			if n.y > 0.0: return Color(0.25, 0.12, 0.06) if p.z > 0.235 else _vary(Color(0.72, 0.33, 0.14), p, 0.1)
			return Color(0.86, 0.76, 0.68)
		if n.y > 0.2: return _vary(Color(0.36, 0.24, 0.14), p, 0.35)
		if p.z > -0.02 and p.z < 0.07 and _h(p * 3.0) > 0.45: return Color(0.42, 0.28, 0.17)    # belly band
		if n.y < -0.2: return _vary(Color(0.9, 0.84, 0.72), p, 0.06)
		return _vary(Color(0.55, 0.4, 0.27), p, 0.2)
	var wing_col := func(p: Vector3, n: Vector3) -> Color:
		var lc := _wing_at(wing, p.x)
		var u := (p.z - lc.x) / maxf(lc.y, 0.001)
		if p.x > 0.52: return Color(0.14, 0.11, 0.09)                                 # dark finger tips
		if n.y >= 0.0: return _vary(Color(0.34, 0.23, 0.14) if u < 0.5 else Color(0.26, 0.18, 0.11), p, 0.3)
		if u < 0.25 and p.x < 0.24: return Color(0.3, 0.2, 0.12)                      # dark bar on the leading edge
		if u < 0.4 and p.x > 0.24 and p.x < 0.33: return Color(0.25, 0.17, 0.1)      # the dark comma at the wrist
		if u > 0.85: return Color(0.38, 0.33, 0.3)                                    # dark trailing band
		if u > 0.45: return Color(0.62, 0.6, 0.58) if int(floor(p.x / 0.06)) % 2 == 0 else Color(0.86, 0.83, 0.78)   # barring
		return Color(0.9, 0.85, 0.77)
	return {
		"body": [[-0.255, -0.03, 0.0, 0.0], [-0.245, -0.018, 0.008, 0.01], [-0.228, -0.004, 0.016, 0.017], [-0.21, 0.006, 0.03, 0.03], [-0.175, 0.008, 0.038, 0.038],
			[-0.14, 0.002, 0.042, 0.04], [-0.09, -0.004, 0.06, 0.06], [0.0, 0.0, 0.065, 0.062], [0.08, 0.006, 0.05, 0.045], [0.13, 0.012, 0.035, 0.022],
			[0.2, 0.014, 0.07, 0.008], [0.25, 0.014, 0.1, 0.005], [0.256, 0.014, 0.0, 0.0]],
		"seg": 8, "shoulder": Vector3(0.04, 0.025, -0.09), "wing": wing, "wrist": 0.25, "loop": PackedVector2Array(LOOP6),
		"fingers": [5, 0.13, 0.042, 32.0, 0.22], "amp": 24.0, "bias1": 6.0, "amp2": 12.0, "bias2": 2.0, "fold": 25.0,
		"eyes": [Vector3(0.03, 0.016, -0.2)], "eye_r": 0.006, "body_col": body_col, "wing_col": wing_col,
	}

# ================================================================== hot-air balloon
# An AX-7 size envelope (about 2200 cubic metres): 21 m from mouth to crown, 17 m across, 16 gores between load tapes,
# a fire-proof skirt round the mouth, cables down to a burner frame on padded poles, a wicker basket with gas cylinders.
const B_THROAT_Y := 4.4                  # the mouth of the envelope above the basket floor, m
const B_H := 21.0                        # envelope height from the mouth to the crown, m
const B_GORES := 16
const B_PROFILE := [[0.0, 1.6], [0.04, 2.3], [0.1, 3.4], [0.18, 4.8], [0.28, 6.2], [0.38, 7.3], [0.48, 8.1], [0.57, 8.5], [0.64, 8.6], [0.71, 8.4],
	[0.78, 7.9], [0.84, 7.1], [0.89, 6.1], [0.93, 4.9], [0.96, 3.7], [0.98, 2.6], [0.993, 1.5], [1.0, 0.0]]
const B_FLAME := Vector3(0.0, 2.62, 0.0)

static func _b_radius(t: float) -> float:
	for k in range(1, B_PROFILE.size()):
		var a: Array = B_PROFILE[k - 1]; var b: Array = B_PROFILE[k]
		if t <= float(b[0]):
			return lerpf(a[1], b[1], (t - float(a[0])) / (float(b[0]) - float(a[0])))
	return 0.0

## The fabric colour of gore g at height fraction t, for each of the three schemes.
static func _b_gore(scheme: int, g: int, t: float) -> Color:
	var R := Color(0.8, 0.08, 0.07); var Y := Color(0.98, 0.76, 0.06); var B := Color(0.06, 0.24, 0.66)
	var G := Color(0.07, 0.5, 0.22); var W := Color(0.93, 0.93, 0.9)
	match scheme:
		1:
			# red and yellow gores, a blue band round the widest part edged in white, a red crown
			if t > 0.9: return R
			if t > 0.5 and t < 0.66: return B
			if (t > 0.47 and t <= 0.5) or (t >= 0.66 and t < 0.69): return W
			return R if g % 2 == 0 else Y
		2:
			# harlequin chevrons in green, yellow, blue and white, a green crown
			if t > 0.91: return G
			var cols := [G, Y, B, W]
			return cols[posmod(g + absi(int(floor(t * 14.0)) - 7), 4)]
	# the classic: gores in turn red, yellow, blue, green, with a blue crown and a red mouth
	if t > 0.92: return B
	if t < 0.06: return R
	var cols2 := [R, Y, B, G]
	return cols2[g % 4]

## A hot-air balloon. scheme 0, 1 or 2 picks the colours. Origin: the basket floor (the ground contact point).
static func balloon(scheme := 0) -> Dictionary:
	var key := "balloon_%d" % scheme
	if _cache.has(key): return _cache[key]
	var env := DroneParts.Kit.new()
	var fab := _mat("fabric")
	# ---- the envelope: each gore bulges a little between its load tapes (narrow darker strips)
	var ts := [0.0, 0.03, 0.07, 0.12, 0.18, 0.24, 0.3, 0.36, 0.42, 0.49, 0.56, 0.63, 0.7, 0.76, 0.82, 0.87, 0.91, 0.945, 0.97, 0.99, 1.0]
	var fr := [0.0, 0.015, 0.5, 0.985]
	var rows: Array = []
	for t in ts:
		var r := _b_radius(t)
		var y := B_THROAT_Y + float(t) * B_H
		var bul := 0.03 * sqrt(maxf(sin(PI * float(t)), 0.0))
		var row := PackedVector3Array()
		for g in B_GORES:
			for f in fr:
				var a := TAU * (g + float(f)) / B_GORES
				var rr := r * (1.0 + bul * sin(PI * float(f)))
				row.append(Vector3(rr * cos(a), y, rr * sin(a)))
		rows.append(row)
	var mid := Vector3(0, B_THROAT_Y + B_H * 0.55, 0)
	var data := DroneParts.grid(rows, false, true, func(_i: int, _j: int, p: Vector3) -> Vector3: return p - mid)
	var gores := func(p: Vector3, _n: Vector3) -> Color:
		var t := (p.y - B_THROAT_Y) / B_H
		var gf := fposmod(atan2(p.z, p.x), TAU) / TAU * B_GORES
		var g := int(floor(gf))
		var f := gf - g
		var c := _b_gore(scheme, g % B_GORES, t)
		if f < 0.015 or f > 0.985: return c.darkened(0.3)          # load tape
		if absf(t - 0.955) < 0.012: return c.darkened(0.35)        # the seam round the parachute vent
		return c
	env.add(fab, _paint(data, gores))
	# ---- the skirt (scoop): fire-proof fabric hanging below the mouth round the burner
	var skirt: Array = []
	for q in [[0.0, 1.6], [-0.7, 1.68], [-1.5, 1.78]]:
		var sr := PackedVector3Array()
		for j in 32:
			var a := TAU * j / 32.0
			sr.append(Vector3(float(q[1]) * cos(a), B_THROAT_Y + float(q[0]), float(q[1]) * sin(a)))
		skirt.append(sr)
	var sd := DroneParts.grid(skirt, false, true, func(_i: int, _j: int, p: Vector3) -> Vector3: return Vector3(p.x, 0, p.z))
	var trim := _b_gore(scheme, 0, 0.5)
	env.add(fab, _paint(sd, func(p: Vector3, _n: Vector3) -> Color: return trim if p.y < B_THROAT_Y - 1.3 else Color(0.1, 0.1, 0.11)))
	# ---- the basket: wicker walls (woven look from alternating tones), a padded suede rim, rawhide-bound base
	var bas := DroneParts.Kit.new()
	var wick := _mat("wicker")
	var secs: Array = [[0.0, 0.0, 0.0, 0.0, 0.0]]
	for q in [[0.0, 0.63, 0.5], [0.12, 0.635, 0.505], [0.3, 0.64, 0.51], [0.5, 0.645, 0.515], [0.7, 0.65, 0.52], [0.9, 0.655, 0.525], [1.05, 0.66, 0.53], [1.15, 0.66, 0.53]]:
		secs.append([q[0], 0.0, 0.0, q[1], q[2]])
	var up := Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3.ZERO)      # the loft's +z onto +y
	var walls := DroneParts._apply(DroneParts.loft(secs, 10.0, 40), up)
	var weave := func(p: Vector3, n: Vector3) -> Color:
		if n.y > 0.9 and p.y < 0.01: return Color(0.42, 0.32, 0.2)                 # floor boards
		if p.y < 0.12: return Color(0.33, 0.21, 0.12)                              # rawhide skid round the base
		var col := int(floor(fposmod(atan2(p.z, p.x), TAU) / TAU * 40.0))
		var row := int(floor(p.y / 0.18))
		var k := 0.9 if (col + row) % 2 == 0 else 1.06
		return _vary(Color(0.66 * k, 0.5 * k, 0.3 * k), p, 0.12)
	bas.add(wick, _paint(walls, weave))
	var rim: Array = []
	for c in [Vector2(0.48, 0.36), Vector2(-0.48, 0.36), Vector2(-0.48, -0.36), Vector2(0.48, -0.36)]:
		var a0 := atan2(c.y, c.x) - PI * 0.25
		for k in 6:
			var a := a0 + PI * 0.5 * k / 5.0
			rim.append(Vector3(c.x + 0.18 * cos(a), 1.17, c.y + 0.18 * sin(a)))
	var rr: Array = []; rr.resize(rim.size()); rr.fill(0.06)
	bas.add(wick, _sweep(rim, rr, rr, 6, Vector3.UP, true), Transform3D.IDENTITY, Color(0.42, 0.26, 0.14))
	# ---- padded poles up to the burner frame, the frame, the twin burner, cylinders and the flying cables
	var metal := _mat("metal")
	var corners: Array[Vector3] = [Vector3(0.5, 0, 0.4), Vector3(-0.5, 0, 0.4), Vector3(-0.5, 0, -0.4), Vector3(0.5, 0, -0.4)]
	for k in 4:
		var c := corners[k]
		bas.add(wick, DroneParts.tube(Vector3(c.x, 1.1, c.z), Vector3(c.x, 2.25, c.z), 0.03, 0.03, 6), Transform3D.IDENTITY, Color(0.4, 0.25, 0.13))
		var c2 := corners[(k + 1) % 4]
		bas.add(metal, DroneParts.tube(Vector3(c.x, 2.27, c.z), Vector3(c2.x, 2.27, c2.z), 0.02, 0.02, 6))
	bas.add(metal, DroneParts.tube(Vector3(-0.5, 2.27, 0), Vector3(0.5, 2.27, 0), 0.018, 0.018, 6))
	var coil := PackedVector2Array([Vector2(0, 2.3), Vector2(0.13, 2.3), Vector2(0.15, 2.33), Vector2(0.16, 2.37), Vector2(0.15, 2.41), Vector2(0.16, 2.45),
		Vector2(0.15, 2.49), Vector2(0.15, 2.53), Vector2(0.1, 2.56), Vector2(0, 2.56)])
	for sx in [-1.0, 1.0]:
		bas.add(metal, DroneParts.lathe(coil, 10), _xf(Vector3(sx * 0.17, 0, 0)))
		bas.add(_mat("dark_metal"), _box(Vector3(0.06, 0.05, 0.12)), _xf(Vector3(sx * 0.17, 2.24, 0.2)))      # blast valve
	var cyl := PackedVector2Array([Vector2(0, 0), Vector2(0.15, 0), Vector2(0.15, 0.72), Vector2(0.1, 0.8), Vector2(0.03, 0.82), Vector2(0, 0.86)])
	for c in corners:
		bas.add(_mat("paint"), DroneParts.lathe(cyl, 8), _xf(Vector3(c.x * 0.86, 0.0, c.z * 0.8)), Color(0.14, 0.2, 0.42))
	for g in B_GORES:
		var a := TAU * g / B_GORES + 0.001
		var top := Vector3(1.6 * cos(a), B_THROAT_Y, 1.6 * sin(a))
		var to := Vector3(0.5 * signf(cos(a)), 2.29, 0.4 * signf(sin(a)))
		bas.add(_mat("black"), DroneParts.tube(top, to, 0.008, 0.008, 4))
	var out := {"envelope": env.commit(), "basket": bas.commit(), "flame": B_FLAME, "flames": [Vector3(-0.17, 2.6, 0), Vector3(0.17, 2.6, 0)],
		"height": B_THROAT_Y + B_H, "width": 17.2}
	_cache[key] = out
	return out

# ================================================================== white-tailed deer
# A doe, about 1.75 m long and 0.95 m at the shoulder: warm brown above, white belly, white throat patch and muzzle band,
# white round the tail. The head and neck are separate meshes in two poses so the game can swap them; the body also comes
# with the tail raised ("body_flag"), the white flag shown when it runs.
static func deer() -> Dictionary:
	if _cache.has("deer"): return _cache["deer"]
	var out := {"body": _deer_body(false), "body_flag": _deer_body(true), "head_up": _deer_head(true), "head_down": _deer_head(false), "height": 0.95, "length": 1.75}
	_cache["deer"] = out
	return out

static func _deer_coat(p: Vector3, n: Vector3) -> Color:
	var white := Color(0.9, 0.87, 0.8)
	if p.y < 0.055: return Color(0.07, 0.06, 0.055)                                        # hooves
	if p.z > 0.47 and absf(p.x) < 0.07 and p.y > 0.62 and p.y < 0.84 and n.z > 0.2: return white   # round the tail
	if p.y < 0.68 and p.y > 0.42 and n.y < -0.5: return white                             # belly
	var inner := n.x * signf(p.x) < -0.35
	if p.y < 0.5:
		if inner: return Color(0.82, 0.76, 0.66)
		return _vary(Color(0.56, 0.42, 0.29), p, 0.12)
	if inner and p.z > 0.15 and p.y < 0.76: return Color(0.82, 0.76, 0.66)               # inside of the thighs
	var t := clampf((p.y - 0.62) / 0.3, 0.0, 1.0)
	return _vary(Color(0.55, 0.38, 0.24).lerp(Color(0.4, 0.27, 0.17), t), p, 0.12)

static func _deer_body(flag: bool) -> ArrayMesh:
	var kit := DroneParts.Kit.new()
	var fur := _mat("fur")
	var coat := func(p: Vector3, n: Vector3) -> Color: return _deer_coat(p, n)
	var torso := [[-0.7, 0.0, 0.74, 0.0, 0.0], [-0.68, 0.0, 0.74, 0.06, 0.1], [-0.62, 0.0, 0.75, 0.12, 0.17], [-0.5, 0.0, 0.755, 0.16, 0.2], [-0.32, 0.0, 0.75, 0.175, 0.2],
		[-0.08, 0.0, 0.745, 0.185, 0.2], [0.14, 0.0, 0.765, 0.175, 0.18], [0.3, 0.0, 0.79, 0.165, 0.165], [0.43, 0.0, 0.8, 0.135, 0.145], [0.52, 0.0, 0.8, 0.085, 0.105],
		[0.565, 0.0, 0.8, 0.03, 0.04], [0.575, 0.0, 0.8, 0.0, 0.0]]
	kit.add(fur, _paint(DroneParts.loft(torso, 2.3, 16), coat))
	var fwd := Vector3(0, 0, -1)
	for sx in [-1.0, 1.0]:
		var front := [Vector3(sx * 0.1, 0.78, -0.47), Vector3(sx * 0.105, 0.56, -0.44), Vector3(sx * 0.1, 0.34, -0.47), Vector3(sx * 0.095, 0.13, -0.47), Vector3(sx * 0.095, 0.06, -0.485), Vector3(sx * 0.095, 0.022, -0.51)]
		kit.add(fur, _paint(_sweep(front, [0.068, 0.05, 0.03, 0.021, 0.019, 0.019], [0.095, 0.072, 0.036, 0.022, 0.022, 0.028], 10, fwd), coat))
		var hind := [Vector3(sx * 0.11, 0.8, 0.3), Vector3(sx * 0.12, 0.58, 0.2), Vector3(sx * 0.1, 0.4, 0.4), Vector3(sx * 0.095, 0.13, 0.36), Vector3(sx * 0.095, 0.06, 0.345), Vector3(sx * 0.095, 0.022, 0.32)]
		kit.add(fur, _paint(_sweep(hind, [0.08, 0.06, 0.03, 0.021, 0.019, 0.019], [0.13, 0.095, 0.045, 0.022, 0.022, 0.028], 10, fwd), coat))
	var brown := Color(0.42, 0.28, 0.17); var white := Color(0.92, 0.9, 0.85)
	if flag:
		var tail := _sweep([Vector3(0, 0.83, 0.55), Vector3(0, 0.9, 0.6), Vector3(0, 1.0, 0.61), Vector3(0, 1.07, 0.6)], [0.05, 0.075, 0.08, 0.05], [0.02, 0.025, 0.022, 0.012], 8, fwd)
		kit.add(fur, _paint(tail, func(_p: Vector3, n: Vector3) -> Color: return brown if n.z < -0.3 and absf(n.x) < 0.7 else white))
	else:
		var tail2 := _sweep([Vector3(0, 0.83, 0.55), Vector3(0, 0.79, 0.6), Vector3(0, 0.69, 0.63), Vector3(0, 0.63, 0.635)], [0.045, 0.06, 0.055, 0.03], [0.02, 0.025, 0.022, 0.012], 8, fwd)
		kit.add(fur, _paint(tail2, func(_p: Vector3, n: Vector3) -> Color: return brown if n.z > 0.3 and absf(n.x) < 0.7 else white))
	return kit.commit()

static func _deer_head(up: bool) -> ArrayMesh:
	var kit := DroneParts.Kit.new()
	var fur := _mat("fur")
	var neck: Array; var poll: Vector3; var pitch: float; var ear_dir: Vector3
	if up:
		neck = [Vector3(0, 0.84, -0.55), Vector3(0, 0.99, -0.67), Vector3(0, 1.13, -0.73), Vector3(0, 1.25, -0.76)]
		poll = Vector3(0, 1.28, -0.77); pitch = -35.0; ear_dir = Vector3(0.5, 0.85, 0.15)
	else:
		neck = [Vector3(0, 0.84, -0.55), Vector3(0, 0.74, -0.71), Vector3(0, 0.52, -0.83), Vector3(0, 0.33, -0.89)]
		poll = Vector3(0, 0.31, -0.9); pitch = -78.0; ear_dir = Vector3(0.75, 0.5, 0.3)
	# the neck, with a white patch on the throat just under the jaw
	var d := ((neck[3] as Vector3) - (neck[2] as Vector3)).normalized()
	var throat := Vector3(0, d.z, -d.y)
	var top: Vector3 = neck[3]
	var neck_col := func(p: Vector3, n: Vector3) -> Color:
		if p.distance_to(top) < 0.13 and n.dot(throat) > 0.35: return Color(0.92, 0.9, 0.85)
		return _vary(Color(0.5, 0.37, 0.25), p, 0.1)
	kit.add(fur, _paint(_sweep(neck, [0.095, 0.075, 0.06, 0.052], [0.16, 0.125, 0.095, 0.08], 12, Vector3(0, 0, -1)), neck_col))
	# the head, made pointing along -z from the poll, then tipped down by the pose
	var hx := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(pitch)), poll)
	var skull := [[0.04, 0.0, 0.0, 0.0, 0.0], [0.03, 0.0, 0.0, 0.045, 0.05], [-0.01, 0.0, 0.0, 0.062, 0.068], [-0.07, 0.0, -0.01, 0.055, 0.06], [-0.14, 0.0, -0.02, 0.042, 0.048],
		[-0.21, 0.0, -0.03, 0.033, 0.04], [-0.26, 0.0, -0.035, 0.03, 0.035], [-0.29, 0.0, -0.035, 0.024, 0.028], [-0.3, 0.0, -0.035, 0.0, 0.0]]
	var white := Color(0.92, 0.9, 0.85)
	var face := func(p: Vector3, n: Vector3) -> Color:
		if p.z < -0.272: return Color(0.05, 0.045, 0.045)                                  # nose
		if p.z < -0.232 and (p.y < -0.03 or absf(n.x) > 0.6): return white                # pale band round the muzzle
		if p.z < -0.15 and n.y < -0.55: return white                                       # chin
		if absf(absf(p.x) - 0.055) < 0.02 and absf(p.z + 0.06) < 0.035 and p.y > 0.0: return Color(0.78, 0.72, 0.62)   # pale eye ring
		if n.y > 0.55: return _vary(Color(0.38, 0.26, 0.16), p, 0.1)                       # darker forehead
		return _vary(Color(0.5, 0.37, 0.25), p, 0.1)
	kit.add(fur, _paint(DroneParts.loft(skull, 2.2, 12), face), hx)
	for sx in [-1.0, 1.0]:
		kit.add(fur, _dot(Vector3(sx * 0.058, 0.022, -0.065), 0.013), hx, Color(0.03, 0.025, 0.02))
		# a big ear: a cupped leaf, pale and furred inside, brown outside, darker at the rim of the tip
		var A := Vector3(sx * ear_dir.x, ear_dir.y, ear_dir.z).normalized()
		var N := Vector3(0, 0, -1); N = (N - A * N.dot(A)).normalized()
		var W := A.cross(N).normalized()
		var base := Vector3(sx * 0.04, 0.045, 0.02)
		var L := 0.16
		var st: Array = []
		for q in [[0.0, 0.045], [0.45, 0.075], [1.0, 0.016]]:
			var w: float = q[1]
			st.append([base + A * (L * float(q[0])) - W * (w * 0.5), W * w, -N * w])
		var ear_col := func(p: Vector3, n: Vector3) -> Color:
			if (p - base).dot(A) > L * 0.82: return Color(0.2, 0.15, 0.1)
			return Color(0.86, 0.78, 0.72) if n.dot(N) > 0.3 else Color(0.45, 0.33, 0.22)
		kit.add(fur, _paint(_foil(st, PackedVector2Array([Vector2(0, 0), Vector2(0.5, 0.3), Vector2(1, 0), Vector2(0.5, 0.2)])), ear_col), hx)
	return kit.commit()

# ================================================================== fireworks: a shell and the launch barge
## A 6 cm aerial shell: a pasted paper sphere with its lift charge cup below and the quick-match leader from the top.
## Origin: the centre of the sphere.
static func firework_shell_proxy() -> ArrayMesh:
	if _cache.has("shell"): return _cache["shell"]
	var kit := DroneParts.Kit.new()
	var pm := _mat("paint")
	var kraft := func(p: Vector3, _n: Vector3) -> Color:
		return _vary(Color(0.6, 0.47, 0.3), p * 30.0, 0.12)
	kit.add(pm, _paint(DroneParts.sphere(0.03, 12), kraft))
	kit.add(pm, DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, -0.05), Vector2(0.019, -0.05), Vector2(0.021, -0.027), Vector2(0, -0.027)])), 12), Transform3D.IDENTITY, Color(0.55, 0.43, 0.28))
	kit.add(pm, DroneParts.tube(Vector3(0, 0.027, 0), Vector3(0.0, 0.038, 0.014), 0.0035, 0.0035, 6), Transform3D.IDENTITY, Color(0.82, 0.78, 0.68))
	kit.add(pm, DroneParts.tube(Vector3(0.0, 0.038, 0.014), Vector3(0.0, 0.036, 0.04), 0.0035, 0.003, 6), Transform3D.IDENTITY, Color(0.82, 0.78, 0.68))
	kit.add(pm, DroneParts.tube(Vector3(0.0, 0.036, 0.04), Vector3(0.0, 0.035, 0.048), 0.002, 0.002, 6), Transform3D.IDENTITY, Color(0.1, 0.25, 0.1))   # bare green fuse end
	var mesh := kit.commit()
	_cache["shell"] = mesh
	return mesh

## Where the mortar tubes on the barge point: [mouth, direction, base] for each of the 20, in the barge's frame.
static func barge_tubes() -> Array:
	var out: Array = []
	for side in [-1.0, 1.0]:
		for k in 10:
			var base := Vector3(side * 1.0, 0.78, -2.25 + 0.5 * k)
			var dir := (Basis(Vector3(0, 0, 1), -side * deg_to_rad(8.0)) * Basis(Vector3.RIGHT, deg_to_rad(4.0 if k % 2 == 0 else -4.0))) * Vector3.UP
			out.append([base + dir * 0.9, dir, base])
	return out

## A steel launch barge 12 x 5 m with two wooden racks of ten HDPE mortar tubes, sandbags, rails, bollards, a firing box and
## a generator. Origin: the waterline at the middle (the deck is 0.7 m up, the hull goes 0.5 m down). Long axis along z.
static func barge() -> ArrayMesh:
	if _cache.has("barge"): return _cache["barge"]
	var kit := DroneParts.Kit.new()
	var pm := _mat("paint")
	var hull := [[-6.0, 0.0, 0.55, 2.5, 0.15], [-5.6, 0.0, 0.3, 2.5, 0.4], [-5.1, 0.0, 0.1, 2.5, 0.6], [5.1, 0.0, 0.1, 2.5, 0.6], [5.6, 0.0, 0.3, 2.5, 0.4], [6.0, 0.0, 0.55, 2.5, 0.15]]
	var hcol := func(p: Vector3, n: Vector3) -> Color:
		if n.y > 0.8 and p.y > 0.6: return _vary(Color(0.42, 0.42, 0.4), p, 0.15)
		if p.y < -0.2: return Color(0.3, 0.12, 0.08)
		if _h(p) > 0.88: return Color(0.4, 0.23, 0.13)                                 # rust streaks
		return _vary(Color(0.16, 0.21, 0.27), p, 0.12)
	kit.add(pm, _paint(DroneParts.loft(hull, 14.0, 32, true), hcol))
	# rubbing strake round the deck edge
	var edge: Array = []
	for c in [Vector2(2.0, 5.5), Vector2(-2.0, 5.5), Vector2(-2.0, -5.5), Vector2(2.0, -5.5)]:
		var a0 := atan2(c.y, c.x) - PI * 0.25
		for k in 5:
			var a := a0 + PI * 0.5 * k / 4.0
			edge.append(Vector3(c.x + 0.53 * cos(a), 0.62, c.y + 0.53 * sin(a)))
	var er: Array = []; er.resize(edge.size()); er.fill(0.07)
	kit.add(pm, _sweep(edge, er, er, 6, Vector3.UP, true), Transform3D.IDENTITY, Color(0.06, 0.06, 0.06))
	# the racks: a plywood base and sides, cross braces between the tubes, sandbags at the ends
	var ply := Color(0.68, 0.55, 0.38)
	for side in [-1.0, 1.0]:
		kit.add(pm, _box(Vector3(0.75, 0.08, 5.4)), _xf(Vector3(side * 1.0, 0.74, 0.0)), ply)
		for e in [-1.0, 1.0]:
			kit.add(pm, _box(Vector3(0.025, 0.5, 5.4)), _xf(Vector3(side * 1.0 + e * 0.36, 1.03, 0.0)), ply.darkened(0.08))
		for k in 9:
			kit.add(pm, _box(Vector3(0.72, 0.12, 0.025)), _xf(Vector3(side * 1.0, 1.2, -2.0 + 0.5 * k)), ply.darkened(0.15))
		for e in [-1.0, 1.0]:
			kit.add(pm, DroneParts.rbox(Vector3(0.6, 0.2, 0.32), 3.0, 8), _xf(Vector3(side * 1.0, 0.88, e * 2.92)), Color(0.55, 0.5, 0.37))
			kit.add(pm, DroneParts.rbox(Vector3(0.55, 0.18, 0.3), 3.0, 8), _xf(Vector3(side * 1.0, 1.06, e * 2.9), Vector3(0, 0.3, 0)), Color(0.5, 0.46, 0.34))
	# the mortar tubes: black HDPE, open at the top
	var tube := PackedVector2Array([Vector2(0, 0), Vector2(0.065, 0), Vector2(0.065, 0.9), Vector2(0.05, 0.9), Vector2(0.05, 0.35)])
	var tube_d := DroneParts.lathe(tube, 10)
	for t in barge_tubes():
		var dir: Vector3 = t[1]
		kit.add(pm, tube_d, Transform3D(Basis(Quaternion(Vector3.UP, dir)), t[2]), Color(0.07, 0.08, 0.07))
	# rails and stanchions along the sides, bollards at the corners, a firing box and a generator at the stern, a red flag
	var yel := Color(0.95, 0.75, 0.1)
	for sx in [-1.0, 1.0]:
		for z in [-5.6, -3.4, -1.1, 1.1, 3.4, 5.6]:
			kit.add(pm, DroneParts.tube(Vector3(sx * 2.35, 0.7, z), Vector3(sx * 2.35, 1.6, z), 0.025, 0.025, 6), Transform3D.IDENTITY, yel)
		for y in [1.15, 1.6]:
			kit.add(pm, DroneParts.tube(Vector3(sx * 2.35, y, -5.6), Vector3(sx * 2.35, y, 5.6), 0.022, 0.022, 6), Transform3D.IDENTITY, yel)
	var bol := DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0, 0), Vector2(0.12, 0), Vector2(0.12, 0.04), Vector2(0.08, 0.06), Vector2(0.08, 0.25), Vector2(0.11, 0.28), Vector2(0.11, 0.32), Vector2(0, 0.32)])), 10)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			kit.add(pm, bol, _xf(Vector3(sx * 1.7, 0.7, sz * 5.75)), Color(0.1, 0.1, 0.1))
	kit.add(pm, _box(Vector3(0.7, 0.45, 0.55)), _xf(Vector3(0.2, 0.925, 4.6)), Color(0.55, 0.57, 0.58))
	kit.add(pm, _box(Vector3(0.95, 0.6, 0.65)), _xf(Vector3(-1.4, 1.0, 4.6)), Color(0.62, 0.6, 0.18))
	for side in [-1.0, 1.0]:
		kit.add(pm, DroneParts.tube(Vector3(0.2, 0.72, 4.3), Vector3(side * 1.0, 0.72, 2.75), 0.015, 0.015, 5), Transform3D.IDENTITY, Color(0.05, 0.05, 0.05))
	kit.add(pm, DroneParts.tube(Vector3(2.0, 0.7, 5.3), Vector3(2.0, 3.0, 5.3), 0.02, 0.015, 6), Transform3D.IDENTITY, Color(0.85, 0.85, 0.85))
	kit.add(pm, _box(Vector3(0.01, 0.4, 0.6)), _xf(Vector3(2.0, 2.78, 5.6)), Color(0.85, 0.08, 0.06))
	var mesh := kit.commit()
	_cache["barge"] = mesh
	return mesh

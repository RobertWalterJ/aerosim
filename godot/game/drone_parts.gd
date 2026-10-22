class_name DroneParts
extends RefCounted
## The shapes the drone models are made of, all drawn by code: turned parts (motor bells, hubs, ducts), lofted shells
## (bodies, batteries, cameras), flat carbon plates cut from an outline, tubes, and real propeller blades.
## A Kit gathers the parts into one mesh per material (few draw calls, light on a phone) and can also keep the plan and
## side outline of every part, which the drone chooser uses to draw its technical drawings at true scale.

## ---------------------------------------------------------------- the kit: parts merged into one mesh per material
class Kit:
	var record := false            # keep outlines for the technical drawing
	var plan: Array = []           # {"pts": PackedVector2Array (x, z) or "ring": [centre, r_in, r_out], "key": height}
	var side: Array = []           # {"pts": PackedVector2Array (z, y), "key": nearness}
	var _arr := {}                 # Material -> [positions, normals, colours]

	## Add a part. `data` is [positions, normals] or [positions, normals, colours] as triangle lists.
	## outline: "hull" (plan and side outline of the part), "ring" (a turned ring seen from above), "side" (side only), "none".
	## plan_pts: the true outline seen from above, in the part's own (x, z), for parts that are not convex (flat plates).
	func add(m: Material, data: Array, xf := Transform3D.IDENTITY, col := Color.WHITE, outline := "hull", plan_pts := PackedVector2Array()) -> void:
		if not _arr.has(m): _arr[m] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray()]
		var e: Array = _arr[m]
		var pos: PackedVector3Array = data[0]
		var nrm: PackedVector3Array = data[1]
		(e[0] as PackedVector3Array).append_array(xf * pos)
		(e[1] as PackedVector3Array).append_array(Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO) * nrm)
		if data.size() > 2:
			(e[2] as PackedColorArray).append_array(data[2])
		else:
			var cols := PackedColorArray(); cols.resize(pos.size()); cols.fill(col)
			(e[2] as PackedColorArray).append_array(cols)
		if record and outline != "none":
			outline_only(data, xf, outline, plan_pts)

	## Record the outline of a shape without adding it to the mesh.
	func outline_only(data: Array, xf: Transform3D, outline := "hull", plan_pts := PackedVector2Array()) -> void:
		var pos: PackedVector3Array = data[0]
		var pl := PackedVector2Array(); var sd := PackedVector2Array()
		var top := -INF; var near := INF
		var step := maxi(1, pos.size() / 900)
		for k in range(0, pos.size(), step):
			var p: Vector3 = xf * pos[k]
			pl.append(Vector2(p.x, p.z)); sd.append(Vector2(p.z, p.y))
			top = maxf(top, p.y); near = minf(near, p.x)
		if outline == "ring":
			var c3 := xf.origin
			var c := Vector2(c3.x, c3.z)
			var r0 := INF; var r1 := 0.0
			for q in pl:
				r0 = minf(r0, q.distance_to(c)); r1 = maxf(r1, q.distance_to(c))
			plan.append({"ring": [c, r0, r1], "key": top})
		elif outline != "side" and plan_pts.size() > 2:
			var tp := PackedVector2Array()
			for q in plan_pts:
				var w := xf * Vector3(q.x, 0.0, q.y)
				tp.append(Vector2(w.x, w.z))
			plan.append({"pts": tp, "key": top})
		elif outline != "side":
			plan.append({"pts": Geometry2D.convex_hull(pl), "key": top})
		side.append({"pts": Geometry2D.convex_hull(sd), "key": -near})

	## Add a flat outline to the plan drawing by hand (used for the propeller blades, which are not convex).
	func plan_poly(pts: PackedVector2Array, key: float) -> void:
		if record: plan.append({"pts": pts, "key": key, "thin": true})

	func commit() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		for m in _arr:
			var e: Array = _arr[m]
			if (e[0] as PackedVector3Array).is_empty(): continue
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = e[0]; arrays[Mesh.ARRAY_NORMAL] = e[1]; arrays[Mesh.ARRAY_COLOR] = e[2]
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, m)
		_arr.clear()
		return mesh

## ---------------------------------------------------------------- surfaces from a grid of points
## rows: Array of PackedVector3Array (all the same length). hint(i, j, p) gives a rough outward direction, used to
## point the normals the right way. Points repeated in a row or column make a sharp crease there.
static func grid(rows: Array, closed_i: bool, closed_j: bool, hint: Callable, row_cols := PackedColorArray()) -> Array:
	var ni := rows.size()
	var nj := (rows[0] as PackedVector3Array).size()
	var N: Array = []
	var vote := 0.0
	for i in ni:
		var nr := PackedVector3Array(); nr.resize(nj)
		for j in nj:
			var ti := _tan(rows, i, j, true, closed_i, ni, nj)
			var tj := _tan(rows, i, j, false, closed_j, ni, nj)
			var n := tj.cross(ti)
			n = n.normalized() if n.length_squared() > 1e-24 else Vector3.ZERO
			nr[j] = n
			var h: Vector3 = hint.call(i, j, rows[i][j])
			vote += n.dot(h.normalized() if h.length_squared() > 0.0 else h)
		N.append(nr)
	var flip := vote < 0.0
	# points where the surface pinches to a pole take the normal of the row next to them
	for i in ni:
		for j in nj:
			if flip: N[i][j] = -N[i][j]
	for i in ni:
		for j in nj:
			if N[i][j] == Vector3.ZERO:
				var acc := Vector3.ZERO
				for di in [-1, 1]:
					var ii: int = i + di
					if closed_i: ii = posmod(ii, ni)
					if ii >= 0 and ii < ni: acc += N[ii][j]
				N[i][j] = acc.normalized() if acc.length_squared() > 0.0 else Vector3.UP
	var pos := PackedVector3Array(); var nrm := PackedVector3Array(); var cols := PackedColorArray()
	var use_col := row_cols.size() == ni
	var ei := ni if closed_i else ni - 1
	var ej := nj if closed_j else nj - 1
	for i in ei:
		var i2 := (i + 1) % ni
		for j in ej:
			var j2 := (j + 1) % nj
			var a: Vector3 = rows[i][j]; var b: Vector3 = rows[i2][j]; var c: Vector3 = rows[i2][j2]; var d: Vector3 = rows[i][j2]
			var na: Vector3 = N[i][j]; var nb: Vector3 = N[i2][j]; var nc: Vector3 = N[i2][j2]; var nd: Vector3 = N[i][j2]
			var ca := row_cols[i] if use_col else Color.WHITE
			var cb := row_cols[i2] if use_col else Color.WHITE
			_tri(pos, nrm, cols, a, b, c, na, nb, nc, ca, cb, cb)
			_tri(pos, nrm, cols, a, c, d, na, nc, nd, ca, cb, ca)
	return [pos, nrm, cols] if use_col else [pos, nrm]

static func _tan(rows: Array, i: int, j: int, along_i: bool, closed: bool, ni: int, nj: int) -> Vector3:
	var n := ni if along_i else nj
	var k := i if along_i else j
	var p: Vector3 = rows[i][j]
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var kp := k - 1
	var kn := k + 1
	if closed:
		kp = posmod(kp, n); kn = posmod(kn, n)
	if kp >= 0:
		var q: Vector3 = rows[kp][j] if along_i else rows[i][kp]
		a = p - q
	if kn < n:
		var q2: Vector3 = rows[kn][j] if along_i else rows[i][kn]
		b = q2 - p
	var la := a.length()
	var lb := b.length()
	if la < 1e-7 and lb < 1e-7: return Vector3.ZERO
	if la < 1e-7: return b / lb
	if lb < 1e-7: return a / la
	return a / la + b / lb

## One triangle, wound so it faces the way its normals point.
static func _tri(pos: PackedVector3Array, nrm: PackedVector3Array, cols: PackedColorArray, a: Vector3, b: Vector3, c: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var f := (b - a).cross(c - a)
	if f.length_squared() < 1e-22: return
	if f.dot(na + nb + nc) > 0.0:
		pos.append_array([a, c, b]); nrm.append_array([na, nc, nb]); cols.append_array([ca, cc, cb])
	else:
		pos.append_array([a, b, c]); nrm.append_array([na, nb, nc]); cols.append_array([ca, cb, cc])

## ---------------------------------------------------------------- primitives
## A turned part: profile points (radius, height) spun round the Y axis. Repeat a point for a sharp edge.
static func lathe(profile: PackedVector2Array, seg := 24, closed := false) -> Array:
	var rows: Array = []
	for q in profile:
		var r := PackedVector3Array(); r.resize(seg)
		for j in seg:
			var a := TAU * j / seg
			r[j] = Vector3(q.x * cos(a), q.y, q.x * sin(a))
		rows.append(r)
	# the outward side of the profile: away from the middle of its (r, y) outline
	var cen := Vector2.ZERO
	for q in profile: cen += q
	cen /= profile.size()
	var hint := func(i: int, j: int, p: Vector3) -> Vector3:
		var q2 := profile[i] - cen
		var a2 := TAU * j / seg
		return Vector3(q2.x * cos(a2), q2.y, q2.x * sin(a2))
	return grid(rows, closed, true, hint)

## Repeat every inner point of a profile, so a turned part gets crisp edges.
static func crisp(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in pts.size():
		out.append(pts[k])
		if k > 0 and k < pts.size() - 1: out.append(pts[k])
	return out

## A smooth shell lofted along Z through sections [z, cx, cy, half_width, half_height]; e is the squareness
## (2 = round, 4 = soft box, 8 = nearly square). The ends are closed.
static func loft(sections: Array, e := 2.6, seg := 24, flat_ends := false) -> Array:
	var rows: Array = []
	var cens: Array[Vector3] = []
	var secs: Array = []
	if flat_ends:
		var s0: Array = sections[0]; var s1: Array = sections[-1]
		secs.append([s0[0], s0[1], s0[2], 0.0, 0.0]); secs.append(s0)
		for k in sections.size(): secs.append(sections[k])
		secs.append(s1); secs.append([s1[0], s1[1], s1[2], 0.0, 0.0])
	else:
		secs = sections
	var ex := 2.0 / e
	for s in secs:
		var r := PackedVector3Array(); r.resize(seg)
		for j in seg:
			var a := TAU * j / seg
			var ca := cos(a); var sa := sin(a)
			r[j] = Vector3(s[1] + s[3] * signf(ca) * pow(absf(ca), ex), s[2] + s[4] * signf(sa) * pow(absf(sa), ex), s[0])
		rows.append(r); cens.append(Vector3(s[1], s[2], s[0]))
	var hint := func(i: int, _j: int, p: Vector3) -> Vector3:
		var h := p - cens[i]
		if h.length_squared() < 1e-14:
			return Vector3(0, 0, signf(cens[i].z - cens[clampi(i + (1 if i == 0 else -1), 0, cens.size() - 1)].z))
		return h
	return grid(rows, false, true, hint)

## A box with softly rounded edges, centred on the origin.
static func rbox(size: Vector3, e := 6.0, seg := 20) -> Array:
	var b := minf(minf(size.x, size.y), size.z) * 0.12
	var hx := size.x * 0.5; var hy := size.y * 0.5; var hz := size.z * 0.5
	return loft([[-hz, 0.0, 0.0, hx - b, hy - b], [-hz + b * 0.4, 0.0, 0.0, hx - b * 0.25, hy - b * 0.25], [-hz + b, 0.0, 0.0, hx, hy],
		[hz - b, 0.0, 0.0, hx, hy], [hz - b * 0.4, 0.0, 0.0, hx - b * 0.25, hy - b * 0.25], [hz, 0.0, 0.0, hx - b, hy - b]], e, seg, true)

## A flat part cut from an outline in the XZ plane, from height y0 to y1 (carbon plates and arms).
static func extrude(poly: PackedVector2Array, y0: float, y1: float) -> Array:
	var pos := PackedVector3Array(); var nrm := PackedVector3Array(); var cols := PackedColorArray()
	var idx := Geometry2D.triangulate_polygon(poly)
	for k in range(0, idx.size(), 3):
		for face in [[y1, Vector3.UP], [y0, Vector3.DOWN]]:
			var y: float = face[0]; var n: Vector3 = face[1]
			var a := Vector3(poly[idx[k]].x, y, poly[idx[k]].y)
			var b := Vector3(poly[idx[k + 1]].x, y, poly[idx[k + 1]].y)
			var c := Vector3(poly[idx[k + 2]].x, y, poly[idx[k + 2]].y)
			_tri(pos, nrm, cols, a, b, c, n, n, n, Color.WHITE, Color.WHITE, Color.WHITE)
	var cw := Geometry2D.is_polygon_clockwise(poly)
	var m := poly.size()
	var en: Array[Vector3] = []
	for k in m:
		var e := poly[(k + 1) % m] - poly[k]
		var n2 := Vector2(e.y, -e.x).normalized()
		if cw: n2 = -n2
		en.append(Vector3(n2.x, 0.0, n2.y))
	for k in m:
		var k2 := (k + 1) % m
		var n0 := en[k]; var n1 := en[k]
		var prev := en[(k - 1 + m) % m]; var next := en[k2]
		var s0 := n0 if n0.dot(prev) < 0.85 else (n0 + prev).normalized()
		var s1 := n1 if n1.dot(next) < 0.85 else (n1 + next).normalized()
		var a := Vector3(poly[k].x, y0, poly[k].y); var b := Vector3(poly[k2].x, y0, poly[k2].y)
		var c := Vector3(poly[k2].x, y1, poly[k2].y); var d := Vector3(poly[k].x, y1, poly[k].y)
		_tri(pos, nrm, cols, a, b, c, s0, s1, s1, Color.WHITE, Color.WHITE, Color.WHITE)
		_tri(pos, nrm, cols, a, c, d, s0, s1, s0, Color.WHITE, Color.WHITE, Color.WHITE)
	return [pos, nrm]

## Points round a circle (for outlines).
static func circle(c: Vector2, r: float, n := 16, a0 := 0.0, a1 := TAU) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in n + 1:
		var a := lerpf(a0, a1, float(k) / n)
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out

## The outline of an arm: a bar from the body that ends in a round motor pad. Returned convex (hull).
static func arm_outline(from: Vector2, to: Vector2, w0: float, w1: float, pad_r: float, pad_sides := 18) -> PackedVector2Array:
	var dir := (to - from).normalized()
	var nrm := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([from + nrm * w0 * 0.5, from - nrm * w0 * 0.5, to + nrm * w1 * 0.5 - dir * pad_r, to - nrm * w1 * 0.5 - dir * pad_r])
	pts.append_array(circle(to, pad_r, pad_sides))
	return Geometry2D.convex_hull(pts)

## A transform that carries local +Z onto the line from a to b (for tubes and lofted arms).
static func along(a: Vector3, b: Vector3) -> Transform3D:
	var z := (b - a).normalized()
	var helper := Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT
	var x := helper.cross(z).normalized()
	var y := z.cross(x)
	return Transform3D(Basis(x, y, z), a)

## A round tube from a to b (radius r0 at a, r1 at b), closed at both ends.
static func tube(a: Vector3, b: Vector3, r0: float, r1: float, seg := 14) -> Array:
	var L := a.distance_to(b)
	var data := loft([[0.0, 0.0, 0.0, r0, r0], [L, 0.0, 0.0, r1, r1]], 2.0, seg, true)
	var xf := along(a, b)
	return _apply(data, xf)

## Bake a transform into a part (used where a part is built in its own frame).
static func _apply(data: Array, xf: Transform3D) -> Array:
	var pos: PackedVector3Array = data[0]; var nrm: PackedVector3Array = data[1]
	var p2 := xf * pos
	var n2 := Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO) * nrm
	return [p2, n2] if data.size() < 3 else [p2, n2, data[2]]

static func sphere(r: float, seg := 16) -> Array:
	var prof := PackedVector2Array()
	var n := maxi(6, seg / 2)
	for k in n + 1:
		var a := -PI * 0.5 + PI * k / n
		prof.append(Vector2(cos(a) * r, sin(a) * r))
	return lathe(prof, seg)

## ---------------------------------------------------------------- propellers
## A propeller blade. spec: R (tip radius), root (where the blade leaves the hub), c_root, c_max, t_max, c_tip
## (chords as fractions of R; c_tip is the chord just before the rounded tip), sweep (how far the tip trails, x R),
## pd (pitch over diameter), tc (thickness over chord at the root), col, tip_col (a thin band at the tip).
## The blade lies along +X. hand = 1 turns anticlockwise seen from above (leading edge towards -Z), -1 clockwise.
static func chord_at(s: Dictionary, t: float) -> float:
	var R: float = s["R"]
	var tm: float = s["t_max"]
	var cr: float = float(s["c_root"]) * R
	var cm: float = float(s["c_max"]) * R
	var ct: float = float(s["c_tip"]) * R
	var tr := 0.86
	if t <= tm:
		var u := t / tm
		return lerpf(cr, cm, 1.0 - pow(1.0 - u, 2.0))
	if t <= tr:
		var u2 := (t - tm) / (tr - tm)
		return lerpf(cm, ct, pow(u2, 1.15))
	# a round tip: the chord closes on a quarter ellipse
	var u3 := clampf((t - tr) / (1.0 - tr), 0.0, 1.0)
	return ct * sqrt(maxf(1.0 - u3 * u3, 0.0))

## Where the leading and trailing edges are at span fraction t, as z offsets (before twist), for a hand=1 blade.
static func edges_at(s: Dictionary, t: float) -> Vector2:
	var c := chord_at(s, t)
	var sw: float = float(s["sweep"]) * float(s["R"]) * t * t
	var le_frac := 0.30 + 0.12 * t                   # the pitch axis sits near the quarter chord
	return Vector2(-le_frac * c + sw, (1.0 - le_frac) * c + sw)

static func span_r(s: Dictionary, t: float) -> float:
	return lerpf(float(s["root"]), float(s["R"]), t)

static func blade(s: Dictionary, hand: int) -> Array:
	var n := 18
	var m := 7
	var R: float = s["R"]
	var P: float = float(s["pd"]) * 2.0 * R
	var rows: Array = []
	var cols := PackedColorArray()
	var cens: Array[Vector3] = []
	for i in n + 1:
		var t := 1.0 - pow(1.0 - float(i) / n, 1.5)
		var r := span_r(s, t)
		var c := chord_at(s, t)
		var ed := edges_at(s, t)
		var beta := minf(atan(P / (TAU * maxf(r, 0.002))), deg_to_rad(42.0))
		var tc := lerpf(float(s["tc"]), 0.06, t)
		var camber := 0.035
		var ring := PackedVector3Array()
		var pts2: Array[Vector2] = []
		for k in m + 1:      # upper surface, leading edge to trailing edge
			var u := 0.5 - 0.5 * cos(PI * k / m)
			pts2.append(Vector2(u, camber * 4.0 * u * (1.0 - u) + 0.5 * _naca(u, tc)))
		for k in range(m, 0, -1):   # lower surface back to the leading edge (the trailing edge repeats for a crease)
			var u2 := 0.5 - 0.5 * cos(PI * k / m)
			pts2.append(Vector2(u2, camber * 4.0 * u2 * (1.0 - u2) * 0.4 - 0.5 * _naca(u2, tc)))
		var cen := Vector3.ZERO
		for q in pts2:
			var zc := ed.x + q.x * c            # along the chord
			var yc := q.y * c
			# twist: the leading edge (towards -z) rises
			var z := zc * cos(beta) + yc * sin(beta)
			var y := -zc * sin(beta) + yc * cos(beta)
			var v := Vector3(r, y, z * hand)
			ring.append(v); cen += v
		rows.append(ring); cens.append(cen / ring.size())
		var tipc: Color = s.get("tip_col", s["col"])
		cols.append(tipc if t > 0.9 else s["col"])
	var hint := func(i: int, _j: int, p: Vector3) -> Vector3: return p - cens[i]
	return grid(rows, false, false, hint, cols)

## NACA four-digit thickness, closed trailing edge.
static func _naca(u: float, tc: float) -> float:
	return 5.0 * tc * (0.2969 * sqrt(u) - 0.126 * u - 0.3516 * u * u + 0.2843 * u * u * u - 0.1036 * u * u * u * u)

## The plan outline of one blade (x along the blade, z across), for the drawings.
static func blade_outline(s: Dictionary, hand: int) -> PackedVector2Array:
	var le := PackedVector2Array(); var te := PackedVector2Array()
	var n := 22
	var P: float = float(s["pd"]) * 2.0 * float(s["R"])
	for i in n + 1:
		var t := 1.0 - pow(1.0 - float(i) / n, 1.5)
		var r := span_r(s, t)
		var ed := edges_at(s, t)
		var beta := minf(atan(P / (TAU * maxf(r, 0.002))), deg_to_rad(42.0))
		le.append(Vector2(r, ed.x * cos(beta) * hand)); te.append(Vector2(r, ed.y * cos(beta) * hand))
	te.reverse()
	le.append_array(te)
	return le

## A whole propeller: blades, hub and the nut or spinner on top, as one mesh coloured per vertex.
## hub: {r, h, cap_r, cap_h, cap_col, hex (true for a prop nut), col}
static func prop(s: Dictionary, hand: int, hub: Dictionary, mat: Material) -> ArrayMesh:
	var kit := Kit.new()
	var nb: int = s["n"]
	var bl := blade(s, hand)
	for b in nb:
		kit.add(mat, bl, Transform3D(Basis(Vector3.UP, TAU * b / nb + float(s.get("phase", 0.0))), Vector3.ZERO), Color.WHITE, "none")
	var hr: float = hub["r"]; var hh: float = hub["h"]
	var hub_prof := crisp(PackedVector2Array([Vector2(0, -hh * 0.5), Vector2(hr * 0.9, -hh * 0.5), Vector2(hr, -hh * 0.3), Vector2(hr, hh * 0.3), Vector2(hr * 0.9, hh * 0.5), Vector2(0, hh * 0.5)]))
	kit.add(mat, lathe(hub_prof, 20), Transform3D.IDENTITY, hub.get("col", s["col"]), "none")
	var cr: float = hub["cap_r"]; var ch: float = hub["cap_h"]
	var cap := PackedVector2Array()
	if hub.get("hex", false):
		cap = crisp(PackedVector2Array([Vector2(0, hh * 0.5), Vector2(cr, hh * 0.5), Vector2(cr, hh * 0.5 + ch * 0.6), Vector2(0, hh * 0.5 + ch * 0.6)]))
		kit.add(mat, lathe(cap, 6), Transform3D.IDENTITY, hub["cap_col"], "none")
		var dome := PackedVector2Array()
		for k in 6: dome.append(Vector2(cr * 0.75 * cos(PI * 0.5 * k / 5.0), hh * 0.5 + ch * 0.6 + ch * 0.4 * sin(PI * 0.5 * k / 5.0)))
		kit.add(mat, lathe(dome, 16), Transform3D.IDENTITY, hub["cap_col"], "none")
	else:
		for k in 8: cap.append(Vector2(cr * cos(PI * 0.5 * k / 7.0), hh * 0.5 + ch * sin(PI * 0.5 * k / 7.0)))
		kit.add(mat, lathe(cap, 20), Transform3D.IDENTITY, hub["cap_col"], "none")
	return kit.commit()

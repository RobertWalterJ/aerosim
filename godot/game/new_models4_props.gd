class_name NewModels4Props
extends RefCounted
## Roadside furniture for batch "models6" (see new_models4.gd): telegraph and distribution poles, power pylons, road signs,
## a delineator post, a cattle grid, field gates, a bus shelter, a mailbox, road works, a milestone and a bridge rail.
## Real metres, forward -z (a sign's face looks toward -z), up +y, origin on the ground. Wood and galvanised steel use the farm
## materials (photographed set); painted sheet, concrete, glass and lenses use vehicle.gdshader.

const WOOD_UP := 1.0                       # grain code in a wood colour's alpha (see farm_props.gdshader): along y
const WOOD_X := 0.75
const WOOD_Z := 0.5

static var _cache := {}

static func _w(c: Color, code: float) -> Color:
	return Color(c.r, c.g, c.b, code)

static func _wood_bm(P: NewModels4.Parts, a: Vector3, b: Vector3, w: float, h: float, col: Color, up := Vector3.UP, ext := 0.0) -> void:
	var d := (b - a).abs()
	var code := WOOD_UP if (d.y >= d.x and d.y >= d.z) else (WOOD_X if d.x >= d.z else WOOD_Z)
	NewModels4._bm(P, "wood", a, b, w, h, _w(col, code), up, ext)

static func mesh(name: String, lod: int) -> ArrayMesh:
	var k := "%s/%d" % [name, lod]
	if _cache.has(k): return _cache[k]
	var P := NewModels4.Parts.new()
	match name:
		"telegraph_pole_a": _pole_a(P, lod)
		"telegraph_pole_b": _pole_b(P, lod)
		"power_pylon_a": _pylon_lattice(P, lod)
		"power_pylon_b": _pylon_mono(P, lod)
		"road_sign_bend_a": _sign_diamond(P, lod, 0)
		"road_sign_junction_a": _sign_diamond(P, lod, 1)
		"road_sign_speed_a": _sign_speed(P, lod)
		"road_marker_a": _marker(P, lod)
		"cattle_grid_a": _cattle_grid(P, lod)
		"field_gate_a": _gate_wood(P, lod)
		"field_gate_b": _gate_steel(P, lod)
		"bus_shelter_a": _shelter(P, lod)
		"post_box_a": _mailbox(P, lod)
		"road_works_a": _works(P, lod)
		"milestone_a": _milestone(P, lod)
		"road_bridge_rail_a": _bridge_rail(P, lod)
		_:
			push_error("NewModels4Props: no model called " + name)
	var out := NewModels4._finish(P)
	_cache[k] = out
	return out

## The points a wire is hung from, in the model frame (the tops of the insulators), for telegraph and power wires.
static func attachments(name: String) -> Array:
	match name:
		"telegraph_pole_a":
			return [Vector3(-0.8, 8.0, 0), Vector3(-0.28, 8.0, 0), Vector3(0.28, 8.0, 0), Vector3(0.8, 8.0, 0), Vector3(0, 8.72, 0)]
		"telegraph_pole_b":
			return [Vector3(-1.05, 9.8, 0), Vector3(0, 10.1, 0), Vector3(1.05, 9.8, 0)]
		"power_pylon_a":
			return [Vector3(-5.3, 27.5, 0), Vector3(5.3, 27.5, 0), Vector3(-4.6, 22.0, 0), Vector3(4.6, 22.0, 0), Vector3(-3.9, 16.5, 0), Vector3(3.9, 16.5, 0)]
		"power_pylon_b":
			return [Vector3(-2.6, 17.2, 0), Vector3(2.6, 17.2, 0), Vector3(-2.2, 14.5, 0), Vector3(2.2, 14.5, 0), Vector3(-1.8, 12.0, 0), Vector3(1.8, 12.0, 0)]
	return []

static func colliders(name: String) -> Array:
	match name:
		"telegraph_pole_a": return [AABB(Vector3(-0.15, 0, -0.15), Vector3(0.3, 8.6, 0.3)), AABB(Vector3(-1.0, 7.5, -0.07), Vector3(2.0, 0.5, 0.14))]
		"telegraph_pole_b": return [AABB(Vector3(-0.2, 0, -0.2), Vector3(0.4, 10.4, 0.4)), AABB(Vector3(-1.25, 9.4, -0.08), Vector3(2.5, 0.8, 0.16))]
		"power_pylon_a": return [AABB(Vector3(-3.0, 0, -3.0), Vector3(6.0, 17.0, 6.0)), AABB(Vector3(-1.2, 17.0, -1.2), Vector3(2.4, 14.0, 1.4)), AABB(Vector3(-5.6, 16.0, -0.5), Vector3(11.2, 12.0, 1.0))]
		"power_pylon_b": return [AABB(Vector3(-0.5, 0, -0.5), Vector3(1.0, 18.0, 1.0)), AABB(Vector3(-2.6, 11.5, -0.2), Vector3(5.2, 6.2, 0.4))]
		"road_sign_bend_a", "road_sign_junction_a": return [AABB(Vector3(-0.4, 0.0, -0.06), Vector3(0.8, 2.9, 0.12))]
		"road_sign_speed_a": return [AABB(Vector3(-0.35, 0.0, -0.06), Vector3(0.7, 2.6, 0.12))]
		"road_marker_a": return [AABB(Vector3(-0.05, 0, -0.05), Vector3(0.1, 1.15, 0.1))]
		"cattle_grid_a": return []
		"field_gate_a", "field_gate_b": return [AABB(Vector3(-0.15, 0, -0.1), Vector3(0.3, 1.5, 0.2)), AABB(Vector3(0.1, 0.2, -0.04), Vector3(3.5, 1.15, 0.08)), AABB(Vector3(3.55, 0, -0.1), Vector3(0.3, 1.5, 0.2))]
		"bus_shelter_a": return [AABB(Vector3(-1.5, 0, -0.7), Vector3(3.0, 2.55, 1.4))]
		"post_box_a": return [AABB(Vector3(-0.15, 0, -0.3), Vector3(0.3, 1.45, 0.6))]
		"road_works_a": return [AABB(Vector3(-1.0, 0, -0.3), Vector3(2.0, 1.0, 0.6))]
		"milestone_a": return [AABB(Vector3(-0.25, 0, -0.12), Vector3(0.5, 0.95, 0.24))]
		"road_bridge_rail_a": return [AABB(Vector3(-0.15, 0, -0.2), Vector3(4.3, 1.25, 0.4))]
	return []

# ================================================================== poles
static func _insulator(P: NewModels4.Parts, at: Vector3, lod: int) -> void:
	# a steel pin and a glazed brown ceramic insulator (the tops of the skirts are the attachment point)
	var pin := Color(0.55, 0.56, 0.58, 0.8)
	var gl := Color(0.22, 0.14, 0.08, 1.0)
	NewModels4._cyl(P, "steel", at - Vector3(0, 0.1, 0), at + Vector3(0, 0.0, 0), 0.01, 0.009, 6, pin)
	if lod == 2:
		NewModels4._cyl(P, "lens", at - Vector3(0, 0.1, 0), at + Vector3(0, 0.0, 0), 0.04, 0.025, 5, gl)
		return
	NewModels4._put(P, "lens", DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0.0, -0.09), Vector2(0.055, -0.09), Vector2(0.058, -0.06), Vector2(0.032, -0.055),
		Vector2(0.045, -0.025), Vector2(0.026, -0.02), Vector2(0.03, 0.0), Vector2(0.0, 0.0)])), 10 if lod == 0 else 6), Transform3D(Basis.IDENTITY, at), gl)

static func _pole_shaft(P: NewModels4.Parts, h: float, r0: float, r1: float, lod: int, col: Color) -> void:
	var seg: int = [14, 9, 6][lod]
	NewModels4._put(P, "wood", DroneParts.tube(Vector3(0, -0.05, 0), Vector3(0, h, 0), r0, r1, seg), NewModels4.I, _w(col, WOOD_UP))
	if lod == 0:
		# weathering: a check line and a few step bolts; a pole tag, a ground band of lighter wood, a cap of the pole
		for k in 4:
			var y := 2.4 + k * 0.42
			var a := 0.4 + k * 1.7
			var rr := lerpf(r0, r1, y / h) + 0.004
			NewModels4._cyl(P, "steel", Vector3(cos(a) * rr, y, sin(a) * rr), Vector3(cos(a) * (rr + 0.12), y + 0.02, sin(a) * (rr + 0.12)), 0.008, 0.008, 5, Color(0.5, 0.5, 0.52, 0.7))
		NewModels4._bx(P, "sheet", Vector3(0, 1.8, -r0 * 0.93), Vector3(0.1, 0.16, 0.006), Color(0.82, 0.8, 0.7, 0.85))

static func _pole_a(P: NewModels4.Parts, lod: int) -> void:
	var wood := Color(0.34, 0.26, 0.2, 1.0)
	_pole_shaft(P, 8.6, 0.14, 0.095, lod, wood)
	# the crossarm at 7.6 m: two bars sandwich the pole, braces back to the pole, four pins
	var y := 7.82
	_wood_bm(P, Vector3(-1.0, y, 0), Vector3(1.0, y, 0), 0.1, 0.12, wood.darkened(0.1))
	if lod < 2:
		for sx: float in [-1.0, 1.0]:
			_wood_bm(P, Vector3(sx * 0.1, y - 0.65, 0.0), Vector3(sx * 0.62, y - 0.05, 0.0), 0.05, 0.07, wood.darkened(0.05))
	for x: float in [-0.8, -0.28, 0.28, 0.8]:
		_insulator(P, Vector3(x, y + 0.14, 0), lod)
	_insulator(P, Vector3(0, 8.62, 0), lod)

static func _pole_b(P: NewModels4.Parts, lod: int) -> void:
	var wood := Color(0.3, 0.24, 0.19, 1.0)
	_pole_shaft(P, 10.4, 0.18, 0.12, lod, wood)
	# a three-pin crossarm, a pole-top pin, and a pole-mounted transformer can with its bushings
	var y := 9.55
	_wood_bm(P, Vector3(-1.25, y, 0), Vector3(1.25, y, 0), 0.11, 0.14, wood.darkened(0.08))
	if lod < 2:
		for sx: float in [-1.0, 1.0]:
			_wood_bm(P, Vector3(sx * 0.12, y - 0.8, 0.0), Vector3(sx * 0.8, y - 0.06, 0.0), 0.055, 0.08, wood.darkened(0.05))
	for x: float in [-1.05, 1.05]:
		_insulator(P, Vector3(x, y + 0.2, 0), lod)
	_insulator(P, Vector3(0, 10.3, 0), lod)
	var can := Color(0.3, 0.32, 0.31, 0.75)
	NewModels4._cyl(P, "sheet", Vector3(0.34, 8.1, 0), Vector3(0.34, 8.9, 0), 0.24, 0.24, [16, 10, 6][lod], can)
	NewModels4._put(P, "sheet", DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0.0, 8.9), Vector2(0.24, 8.9), Vector2(0.17, 9.02), Vector2(0.0, 9.02)])), 12), Transform3D(Basis.IDENTITY, Vector3(0.34, 0, 0)), can)
	if lod < 2:
		NewModels4._bx(P, "steel", Vector3(0.14, 8.5, 0), Vector3(0.1, 0.06, 0.18), Color(0.5, 0.5, 0.52, 0.7))
		NewModels4._cyl(P, "lens", Vector3(0.34, 9.02, 0), Vector3(0.34, 9.18, 0), 0.03, 0.02, 6, Color(0.5, 0.3, 0.12, 1.0))

# ================================================================== pylons
## An angle-iron leg or brace between two points (the section is a thin square bar: from far it reads as lattice).
static func _lat(P: NewModels4.Parts, a: Vector3, b: Vector3, w: float, col: Color) -> void:
	NewModels4._bm(P, "steel", a, b, w, w, col)

static func _pylon_lattice(P: NewModels4.Parts, lod: int) -> void:
	var steel := Color(0.62, 0.64, 0.66, 0.8)
	var w: float = [0.13, 0.15, 0.2][lod]
	var panels: int = [10, 6, 3][lod]
	var half0 := 3.0                                                    # half base at the ground
	var half1 := 0.95                                                   # half width at the waist (17 m)
	var h_waist := 17.0
	# legs and bracing, base to waist
	var prev_y := 0.0
	var prev_h := half0
	for k in range(1, panels + 1):
		var y := h_waist * k / panels
		var hh := lerpf(half0, half1, float(k) / panels)
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				_lat(P, Vector3(sx * prev_h, prev_y, sz * prev_h), Vector3(sx * hh, y, sz * hh), w * 1.6, steel)
		# horizontals and the two diagonals of each face
		var faces := [[Vector3(1, 0, 0), Vector3(0, 0, 1)], [Vector3(0, 0, 1), Vector3(1, 0, 0)]]
		for sgn: float in [-1.0, 1.0]:
			# faces perpendicular to x (at x = sgn * h): corners at z = +-h
			var a0 := Vector3(sgn * prev_h, prev_y, -prev_h); var a1 := Vector3(sgn * prev_h, prev_y, prev_h)
			var b0 := Vector3(sgn * hh, y, -hh); var b1 := Vector3(sgn * hh, y, hh)
			_lat(P, b0, b1, w, steel)
			if lod < 2:
				_lat(P, a0, b1, w * 0.8, steel); _lat(P, a1, b0, w * 0.8, steel)
			var c0 := Vector3(-prev_h, prev_y, sgn * prev_h); var c1 := Vector3(prev_h, prev_y, sgn * prev_h)
			var d0 := Vector3(-hh, y, sgn * hh); var d1 := Vector3(hh, y, sgn * hh)
			_lat(P, d0, d1, w, steel)
			if lod < 2:
				_lat(P, c0, d1, w * 0.8, steel); _lat(P, c1, d0, w * 0.8, steel)
		prev_y = y; prev_h = hh
	# the upper body: a square mast to the peak with three cross-arms (a double circuit, three tiers)
	var top_y := 33.0
	var mast_h := 0.95
	var pm := 3 if lod == 0 else (2 if lod == 1 else 1)
	for k in range(pm):
		var y0 := h_waist + (top_y - h_waist) * k / pm
		var y1 := h_waist + (top_y - h_waist) * (k + 1) / pm
		var h0 := lerpf(mast_h, 0.55, float(k) / pm); var h1 := lerpf(mast_h, 0.55, float(k + 1) / pm)
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				_lat(P, Vector3(sx * h0, y0, sz * h0), Vector3(sx * h1, y1, sz * h1), w * 1.3, steel)
		for sgn: float in [-1.0, 1.0]:
			_lat(P, Vector3(sgn * h1, y1, -h1), Vector3(sgn * h1, y1, h1), w, steel)
			_lat(P, Vector3(-h1, y1, sgn * h1), Vector3(h1, y1, sgn * h1), w, steel)
			if lod < 2:
				_lat(P, Vector3(sgn * h0, y0, -h0), Vector3(sgn * h1, y1, h1), w * 0.8, steel)
				_lat(P, Vector3(-h0, y0, sgn * h0), Vector3(h1, y1, sgn * h1), w * 0.8, steel)
	# the peak and the earth wire
	NewModels4._cyl(P, "steel", Vector3(0, top_y, 0), Vector3(0, top_y + 2.2, 0), 0.18, 0.05, 6, steel)
	# cross-arms: three tiers, each a tapering truss out to a suspension insulator string
	var tiers := [[27.5, 5.3], [22.0, 4.6], [16.5, 3.9]]
	for t: Array in tiers:
		var ya: float = t[0]; var reach: float = t[1]
		var hm := lerpf(0.95, 0.55, clampf((ya - 17.0) / 16.0, 0.0, 1.0))
		if ya < 17.0: hm = lerpf(half1, 1.3, 0.0)
		for sx: float in [-1.0, 1.0]:
			_lat(P, Vector3(sx * hm, ya, 0), Vector3(sx * reach, ya + 0.12, 0), w * 1.3, steel)
			_lat(P, Vector3(sx * hm, ya + 1.5, 0), Vector3(sx * reach, ya + 0.12, 0), w, steel)
			if lod < 2:
				_lat(P, Vector3(sx * hm, ya - 1.2, 0), Vector3(sx * reach * 0.55, ya + 0.06, 0), w * 0.9, steel)
			if lod < 2:
				for q in range(1, 5):
					var u := q / 5.0
					_lat(P, Vector3(sx * lerpf(hm, reach, u), ya + 0.12 * u, 0), Vector3(sx * lerpf(hm, reach, u), ya + lerpf(1.5, 0.12, u), 0), w * 0.7, steel)
			# the insulator string: a chain of glass discs hanging from the arm tip
			var tip := Vector3(sx * reach, ya + 0.12, 0)
			var n_d: int = [9, 5, 1][lod]
			for q in n_d:
				var yy := tip.y - 0.12 - q * (0.145 if lod < 2 else 0.0)
				if lod == 2: break
				NewModels4._cyl(P, "lens", Vector3(tip.x, yy, 0), Vector3(tip.x, yy - 0.05, 0), 0.1, 0.1, 7 if lod == 0 else 5, Color(0.55, 0.62, 0.52, 1.0))
			if lod == 2:
				NewModels4._cyl(P, "lens", tip - Vector3(0, 0.1, 0), tip - Vector3(0, 1.3, 0), 0.07, 0.07, 4, Color(0.55, 0.62, 0.52, 1.0))
			NewModels4._bx(P, "steel", tip - Vector3(0, 1.5 if lod < 2 else 1.4, 0), Vector3(0.2, 0.18, 0.4), steel)

static func _pylon_mono(P: NewModels4.Parts, lod: int) -> void:
	var steel := Color(0.6, 0.62, 0.62, 0.78)
	var seg: int = [16, 10, 6][lod]
	# a tapered tubular steel pole in two sections with a flange ring, 18 m
	NewModels4._cyl(P, "steel", Vector3(0, 0, 0), Vector3(0, 9.0, 0), 0.5, 0.38, seg, steel)
	NewModels4._cyl(P, "steel", Vector3(0, 9.0, 0), Vector3(0, 18.0, 0), 0.38, 0.22, seg, steel)
	if lod < 2:
		NewModels4._cyl(P, "steel", Vector3(0, 8.9, 0), Vector3(0, 9.1, 0), 0.43, 0.43, seg, Color(0.5, 0.52, 0.52, 0.7))
		NewModels4._cyl(P, "concrete", Vector3(0, -0.1, 0), Vector3(0, 0.45, 0), 0.75, 0.7, seg, Color(0.58, 0.58, 0.56, 0.8))
		NewModels4._cyl(P, "steel", Vector3(0, 0.45, 0), Vector3(0, 0.6, 0), 0.56, 0.52, seg, Color(0.5, 0.52, 0.52, 0.7))
	# three tiers of arms, each a pair of tapering box beams out to a suspension string
	for t: Array in [[17.2, 2.6], [14.5, 2.2], [12.0, 1.8]]:
		var ya: float = t[0]; var reach: float = t[1]
		for sx: float in [-1.0, 1.0]:
			NewModels4._bm(P, "steel", Vector3(sx * 0.15, ya, 0), Vector3(sx * reach, ya + 0.1, 0), 0.22 if lod < 2 else 0.3, 0.2, steel)
			if lod < 2:
				NewModels4._bm(P, "steel", Vector3(sx * 0.15, ya - 0.7, 0), Vector3(sx * reach * 0.8, ya + 0.05, 0), 0.1, 0.1, steel)
			var tip := Vector3(sx * reach, ya + 0.1, 0)
			if lod == 2:
				NewModels4._cyl(P, "lens", tip - Vector3(0, 0.1, 0), tip - Vector3(0, 1.2, 0), 0.06, 0.06, 4, Color(0.6, 0.62, 0.55, 1.0))
			else:
				for q in 7 if lod == 0 else 4:
					NewModels4._cyl(P, "lens", Vector3(tip.x, tip.y - 0.1 - q * 0.15, 0), Vector3(tip.x, tip.y - 0.15 - q * 0.15, 0), 0.09, 0.09, 7 if lod == 0 else 5, Color(0.55, 0.62, 0.52, 1.0))
			NewModels4._bx(P, "steel", tip - Vector3(0, 1.25, 0), Vector3(0.18, 0.16, 0.34), steel)
	NewModels4._cyl(P, "steel", Vector3(0, 18.0, 0), Vector3(0, 19.5, 0), 0.08, 0.03, 5, steel)

# ================================================================== signs
## A sign plate in the local x-y plane facing -z (centre at the origin), moved by xf. rows build the face.
static func _plate(P: NewModels4.Parts, xf: Transform3D, w: float, h: float, face: Color, border: Color, bw: float, key := "sheet") -> NewModels2.Buf:
	var back := NewModels2.Buf.new()
	var b := NewModels2.Buf.new()
	var hw := w * 0.5; var hh := h * 0.5
	# the plate: a thin slab with the back in galvanised grey
	back.quad(Vector3(-hw, -hh, 0.012), Vector3(hw, -hh, 0.012), Vector3(hw, hh, 0.012), Vector3(-hw, hh, 0.012), Color(0.6, 0.62, 0.64, 0.8), Vector3(0, 0, 1))
	NewModels4._put(P, "steel", back.data(), xf)
	var edge := NewModels2.Buf.new()
	var ec := Color(0.55, 0.57, 0.58, 0.8)
	edge.quad(Vector3(-hw, -hh, 0), Vector3(hw, -hh, 0), Vector3(hw, -hh, 0.012), Vector3(-hw, -hh, 0.012), ec, Vector3(0, -1, 0))
	edge.quad(Vector3(-hw, hh, 0.012), Vector3(hw, hh, 0.012), Vector3(hw, hh, 0), Vector3(-hw, hh, 0), ec, Vector3(0, 1, 0))
	edge.quad(Vector3(-hw, -hh, 0.012), Vector3(-hw, hh, 0.012), Vector3(-hw, hh, 0), Vector3(-hw, -hh, 0), ec, Vector3(-1, 0, 0))
	edge.quad(Vector3(hw, -hh, 0), Vector3(hw, hh, 0), Vector3(hw, hh, 0.012), Vector3(hw, -hh, 0.012), ec, Vector3(1, 0, 0))
	NewModels4._put(P, "steel", edge.data(), xf)
	b.quad(Vector3(hw, -hh, -0.002), Vector3(-hw, -hh, -0.002), Vector3(-hw, hh, -0.002), Vector3(hw, hh, -0.002), face, Vector3(0, 0, -1))
	NewModels4._put(P, key, b.data(), xf)
	# the border: a printed band round the edge
	var bb := NewModels2.Buf.new()
	for e: Array in [[Vector3(-hw + bw * 0.5, 0, 0), Vector3(bw, h, 0)], [Vector3(hw - bw * 0.5, 0, 0), Vector3(bw, h, 0)], [Vector3(0, hh - bw * 0.5, 0), Vector3(w - 2 * bw, bw, 0)], [Vector3(0, -hh + bw * 0.5, 0), Vector3(w - 2 * bw, bw, 0)]]:
		var c: Vector3 = e[0]; var sz: Vector3 = e[1]
		bb.quad(c + Vector3(sz.x * 0.5, -sz.y * 0.5, -0.004), c + Vector3(-sz.x * 0.5, -sz.y * 0.5, -0.004), c + Vector3(-sz.x * 0.5, sz.y * 0.5, -0.004), c + Vector3(sz.x * 0.5, sz.y * 0.5, -0.004), border, Vector3(0, 0, -1))
	NewModels4._put(P, key, bb.data(), xf)
	return NewModels2.Buf.new()

## Mirror a printed face left to right: a sign looks toward -z, so seen from the front its local +x is on the viewer's left.
static func _mx(b: NewModels2.Buf) -> NewModels2.Buf:
	for k in b.pos.size():
		var p := b.pos[k]; b.pos[k] = Vector3(-p.x, p.y, p.z)
		var n := b.nrm[k]; b.nrm[k] = Vector3(-n.x, n.y, n.z)
	for k in range(0, b.pos.size(), 3):
		var t := b.pos[k + 1]; b.pos[k + 1] = b.pos[k + 2]; b.pos[k + 2] = t
		var tn := b.nrm[k + 1]; b.nrm[k + 1] = b.nrm[k + 2]; b.nrm[k + 2] = tn
		var tc := b.cols[k + 1]; b.cols[k + 1] = b.cols[k + 2]; b.cols[k + 2] = tc
	return b

## A thick line segment in the plate plane (for arrows and symbols).
static func _seg(b: NewModels2.Buf, a: Vector2, c: Vector2, t: float, col: Color, z := -0.007) -> void:
	var d := (c - a).normalized()
	var n := Vector2(-d.y, d.x) * t * 0.5
	b.quad(Vector3(c.x + n.x, c.y + n.y, z), Vector3(a.x + n.x, a.y + n.y, z), Vector3(a.x - n.x, a.y - n.y, z), Vector3(c.x - n.x, c.y - n.y, z), col, Vector3(0, 0, -1))

static func _tri2(b: NewModels2.Buf, p0: Vector2, p1: Vector2, p2: Vector2, col: Color, z := -0.007) -> void:
	b.tri(Vector3(p0.x, p0.y, z), Vector3(p1.x, p1.y, z), Vector3(p2.x, p2.y, z), col, Vector3(0, 0, -1))

static func _post(P: NewModels4.Parts, x: float, h: float, lod: int) -> void:
	NewModels4._cyl(P, "steel", Vector3(x, 0, 0.03), Vector3(x, h, 0.03), 0.032, 0.032, [10, 7, 5][lod], Color(0.6, 0.62, 0.64, 0.75))
	if lod < 2: NewModels4._cyl(P, "steel", Vector3(x, h, 0.03), Vector3(x, h + 0.001, 0.03), 0.034, 0.0, 8, Color(0.5, 0.52, 0.54, 0.75))

static func _sign_diamond(P: NewModels4.Parts, lod: int, symbol: int) -> void:
	var yellow := Color(0.94, 0.74, 0.04, 0.95)
	var black := Color(0.03, 0.03, 0.03, 1.0)
	var s := 0.76                                                     # the diamond's side
	var cy := 2.3
	var xf := Transform3D(Basis(Vector3(0, 0, 1), PI * 0.25), Vector3(0, cy, -0.03))
	_plate(P, xf, s, s, yellow, black, 0.03)
	_post(P, 0.0, cy - 0.35, lod)
	if lod == 2: return
	NewModels4._bm(P, "steel", Vector3(0, cy - 0.3, 0.012), Vector3(0, cy + 0.3, 0.012), 0.05, 0.015, Color(0.55, 0.57, 0.58, 0.8))
	var b := NewModels2.Buf.new()
	if symbol == 0:
		# a curving arrow: bottom-left stem, a bend to the right, head at the top right
		var pts: Array[Vector2] = []
		for k in range(0, 13):
			var u := k / 12.0
			pts.append(Vector2(lerpf(-0.12, 0.1, u * u * 0.6 + u * 0.4) * 1.0, lerpf(-0.24, 0.12, u)) + Vector2(0.06 * sin(u * PI) , 0.0) * 0.0)
		for k in 12:
			_seg(b, pts[k], pts[k + 1], 0.05, black)
		_tri2(b, Vector2(0.1, 0.12) + Vector2(-0.075, 0.0), Vector2(0.1, 0.12) + Vector2(0.075, 0.0), Vector2(0.1, 0.12) + Vector2(0.0, 0.14), black)
	else:
		# a T junction: the stem from the bottom and a bar across the top with a small head each way
		_seg(b, Vector2(0, -0.26), Vector2(0, 0.1), 0.06, black)
		_seg(b, Vector2(-0.24, 0.1), Vector2(0.24, 0.1), 0.06, black)
	# the diamond's plate faces -z after the 45-degree turn: its face is in the plate plane, so the same transform places the symbol
	NewModels4._put(P, "sheet", _mx(b).data(), xf)

static func _digit(b: NewModels2.Buf, d: int, c: Vector2, h: float, t: float, col: Color) -> void:
	# seven segments: a b c d e f g
	var segs := {0: "abcdef", 1: "bc", 2: "abdeg", 3: "abcdg", 4: "bcfg", 5: "acdfg", 6: "acdefg", 7: "abc", 8: "abcdefg", 9: "abcdfg"}
	var w := h * 0.5
	var hh := h * 0.5
	var P_ := {"a": [Vector2(-w * 0.5, hh), Vector2(w * 0.5, hh)], "b": [Vector2(w * 0.5, hh), Vector2(w * 0.5, 0)], "c": [Vector2(w * 0.5, 0), Vector2(w * 0.5, -hh)],
		"d": [Vector2(-w * 0.5, -hh), Vector2(w * 0.5, -hh)], "e": [Vector2(-w * 0.5, 0), Vector2(-w * 0.5, -hh)], "f": [Vector2(-w * 0.5, hh), Vector2(-w * 0.5, 0)],
		"g": [Vector2(-w * 0.5, 0), Vector2(w * 0.5, 0)]}
	for ch: String in String(segs[d]):
		var pp: Array = P_[ch]
		var a: Vector2 = pp[0] + c; var e: Vector2 = pp[1] + c
		var dir := (e - a).normalized()
		_seg(b, a - dir * t * 0.5, e + dir * t * 0.5, t, col)

static func _sign_speed(P: NewModels4.Parts, lod: int) -> void:
	var white := Color(0.93, 0.93, 0.9, 0.95)
	var black := Color(0.03, 0.03, 0.03, 1.0)
	var w := 0.6; var h := 0.76
	var cy := 2.1
	var xf := Transform3D(Basis.IDENTITY, Vector3(0, cy, -0.03))
	_plate(P, xf, w, h, white, black, 0.025)
	_post(P, 0.0, cy - 0.38, lod)
	if lod == 2: return
	var b := NewModels2.Buf.new()
	_digit(b, 6, Vector2(-0.12, -0.04), 0.3, 0.05, black)
	_digit(b, 0, Vector2(0.12, -0.04), 0.3, 0.05, black)
	# two bars standing for the legend above the number, one below
	_seg(b, Vector2(-0.2, 0.26), Vector2(0.2, 0.26), 0.045, black)
	_seg(b, Vector2(-0.14, -0.26), Vector2(0.14, -0.26), 0.035, black)
	NewModels4._put(P, "sheet", _mx(b).data(), xf)

static func _marker(P: NewModels4.Parts, lod: int) -> void:
	var seg: int = [10, 7, 5][lod]
	NewModels4._cyl(P, "sheet", Vector3(0, 0, 0), Vector3(0, 1.1, 0), 0.04, 0.035, seg, Color(0.92, 0.92, 0.9, 0.7))
	NewModels4._cyl(P, "sheet", Vector3(0, 0.82, 0), Vector3(0, 1.0, 0), 0.0405, 0.0385, seg, Color(0.04, 0.04, 0.04, 0.8))
	NewModels4._cyl(P, "sheet", Vector3(0, 1.1, 0), Vector3(0, 1.101, 0), 0.036, 0.0, seg, Color(0.92, 0.92, 0.9, 0.7))
	if lod < 2:
		NewModels4._bx(P, "lens", Vector3(0, 0.62, -0.036), Vector3(0.045, 0.1, 0.008), Color(0.8, 0.3, 0.05, 1.0))
	if lod == 0:
		NewModels4._cyl(P, "sheet", Vector3(0, -0.05, 0), Vector3(0, 0.03, 0), 0.06, 0.05, 8, Color(0.3, 0.25, 0.18, 0.4))

# ================================================================== roadway pieces
static func _cattle_grid(P: NewModels4.Parts, lod: int) -> void:
	var W := 3.6; var Ln := 2.4                                        # across the road (x) by along it (z)
	var conc := Color(0.62, 0.62, 0.6, 0.7)
	var dark := Color(0.02, 0.02, 0.022, 1.0)
	# the pit floor and the walls round it, below road level
	NewModels4._bx(P, "trim", Vector3(0, -0.2, 0), Vector3(W, 0.02, Ln), dark)
	for sz: float in [-1.0, 1.0]:
		NewModels4._bx(P, "concrete", Vector3(0, -0.1, sz * (Ln * 0.5 - 0.15)), Vector3(W + 0.3, 0.3, 0.3), conc)         # the sills the bars rest on
		NewModels4._bx(P, "concrete", Vector3(0, 0.0, sz * (Ln * 0.5 + 0.18)), Vector3(W + 0.3, 0.04, 0.36), conc)
	for sx: float in [-1.0, 1.0]:
		NewModels4._bx(P, "concrete", Vector3(sx * (W * 0.5 + 0.15), -0.1, 0), Vector3(0.3, 0.3, Ln + 0.4), conc)
	# the bars: round steel tubes across the pit, lengthwise in z, at 0.15 m
	var n_b := 11 if lod == 0 else (8 if lod == 1 else 5)
	var seg: int = [8, 6, 4][lod]
	for k in n_b:
		var x := -W * 0.5 + 0.12 + k * (W - 0.24) / (n_b - 1)
		NewModels4._cyl(P, "steel", Vector3(x, 0.0, -Ln * 0.5 + 0.1), Vector3(x, 0.0, Ln * 0.5 - 0.1), 0.045, 0.045, seg, Color(0.52, 0.53, 0.54, 0.62))
	if lod < 2:
		for k in 3:
			var z := lerpf(-Ln * 0.5 + 0.35, Ln * 0.5 - 0.35, k / 2.0)
			NewModels4._bm(P, "steel", Vector3(-W * 0.5 + 0.1, -0.06, z), Vector3(W * 0.5 - 0.1, -0.06, z), 0.05, 0.04, Color(0.48, 0.48, 0.5, 0.62))
	# white painted edge marks
	for sx: float in [-1.0, 1.0]:
		NewModels4._bx(P, "sheet", Vector3(sx * (W * 0.5 + 0.15), 0.052, 0), Vector3(0.12, 0.002, Ln + 0.2), Color(0.88, 0.88, 0.85, 0.7))

static func _gate_wood(P: NewModels4.Parts, lod: int) -> void:
	var wood := Color(0.42, 0.36, 0.3, 1.0)
	var post := Color(0.35, 0.29, 0.24, 1.0)
	# hinge post at x = 0, latch post at x = 3.6; the five-bar gate hangs between
	for x: float in [0.0, 3.6]:
		_wood_bm(P, Vector3(x, -0.1, 0), Vector3(x, 1.5, 0), 0.2, 0.2, post.darkened(0.04 if x > 1 else 0.0))
		if lod == 0: NewModels4._bx(P, "wood", Vector3(x, 1.54, 0), Vector3(0.24, 0.05, 0.24), _w(post, WOOD_UP) )
	var x0 := 0.15; var x1 := 3.45
	for k in 5:
		var y := 0.28 + k * 0.2 + (0.04 if k > 2 else 0.0)
		_wood_bm(P, Vector3(x0, y, 0), Vector3(x1, y, 0), 0.075, 0.1, wood.darkened(0.03 * k))
	for x: float in [x0 + 0.04, 3.4 + 0.0]:
		_wood_bm(P, Vector3(x, 0.2, 0), Vector3(x, 1.2, 0), 0.08, 0.09, wood)
	if lod < 2:
		_wood_bm(P, Vector3(1.8, 0.2, 0), Vector3(1.8, 1.2, 0), 0.07, 0.08, wood)
	if lod < 2:
		_wood_bm(P, Vector3(x0, 0.24, 0), Vector3(x1, 1.2, 0), 0.07, 0.07, wood.darkened(0.06))        # the diagonal brace
		for y: float in [0.4, 1.05]:
			NewModels4._bm(P, "steel", Vector3(-0.1, y, 0.0), Vector3(0.7, y, 0.0), 0.06, 0.008, Color(0.3, 0.3, 0.32, 0.45))   # strap hinges
			NewModels4._cyl(P, "steel", Vector3(0.0, y - 0.05, -0.11), Vector3(0.0, y + 0.05, -0.11), 0.012, 0.012, 5, Color(0.35, 0.35, 0.37, 0.5))
		NewModels4._bm(P, "steel", Vector3(3.15, 0.8, 0.07), Vector3(3.55, 0.8, 0.07), 0.04, 0.01, Color(0.4, 0.4, 0.42, 0.5))                 # latch bar

static func _gate_steel(P: NewModels4.Parts, lod: int) -> void:
	var gal := Color(0.7, 0.72, 0.74, 0.88)
	var seg: int = [8, 6, 4][lod]
	# two galvanised round posts; the gate is a tube frame with six rails, uprights and a diagonal
	for x: float in [0.0, 3.8]:
		NewModels4._cyl(P, "steel", Vector3(x, -0.1, 0), Vector3(x, 1.55, 0), 0.055, 0.055, seg + 2, gal)
		if lod < 2: NewModels4._cyl(P, "steel", Vector3(x, 1.55, 0), Vector3(x, 1.57, 0), 0.057, 0.0, 8, gal)
	var x0 := 0.12; var x1 := 3.68
	for y: float in [0.22, 0.45, 0.7, 0.93, 1.17, 1.4]:
		NewModels4._cyl(P, "steel", Vector3(x0, y, 0), Vector3(x1, y, 0), 0.02, 0.02, seg, gal)
	for x: float in [x0, 3.68]:
		NewModels4._cyl(P, "steel", Vector3(x, 0.2, 0), Vector3(x, 1.42, 0), 0.025, 0.025, seg, gal)
	if lod < 2:
		for x: float in [1.0, 1.9, 2.8]:
			NewModels4._cyl(P, "steel", Vector3(x, 0.22, 0), Vector3(x, 1.4, 0), 0.015, 0.015, seg - 1 if seg > 4 else 4, gal)
		NewModels4._cyl(P, "steel", Vector3(x0, 0.22, 0), Vector3(x1, 1.4, 0), 0.018, 0.018, seg, gal)
		# a chain and padlock at the latch end, hinge pins at the other
		for k in 6:
			NewModels4._cyl(P, "steel", Vector3(3.72, 0.95 - k * 0.04, 0.06), Vector3(3.75, 0.92 - k * 0.04, 0.06), 0.008, 0.008, 4, Color(0.4, 0.4, 0.42, 0.6))
		NewModels4._bx(P, "metal", Vector3(3.8, 0.8, 0.07), Vector3(0.05, 0.08, 0.03), Color(0.7, 0.55, 0.15, 0.7))
		for y: float in [0.45, 1.17]:
			NewModels4._cyl(P, "steel", Vector3(0.0, y, -0.07), Vector3(0.12, y, -0.02), 0.013, 0.013, 5, Color(0.45, 0.45, 0.47, 0.5))

static func _shelter(P: NewModels4.Parts, lod: int) -> void:
	var frame := Color(0.18, 0.2, 0.22, 0.88)
	var glass := Color(0.5, 0.52, 0.55, 1.0)
	var W := 3.0; var D := 1.4; var H := 2.4
	NewModels4._bx(P, "concrete", Vector3(0, 0.05, 0), Vector3(W + 0.3, 0.1, D + 0.3), Color(0.62, 0.62, 0.6, 0.65))
	# posts and the roof: a shallow shed roof sloping to the back (+z)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			NewModels4._bm(P, "sheet", Vector3(sx * (W * 0.5 - 0.04), 0.1, sz * (D * 0.5 - 0.04)), Vector3(sx * (W * 0.5 - 0.04), H + (0.0 if sz < 0 else -0.14), sz * (D * 0.5 - 0.04)), 0.07, 0.07, frame)
	NewModels4._bx(P, "sheet", Vector3(0, H + 0.05, 0), Vector3(W + 0.4, 0.07, D + 0.35), frame, Basis(Vector3(1, 0, 0), -0.1))
	NewModels4._bx(P, "sheet", Vector3(0, H + 0.09, 0.0), Vector3(W + 0.36, 0.015, D + 0.3), Color(0.5, 0.52, 0.54, 0.75), Basis(Vector3(1, 0, 0), -0.1))
	# glass: the back and two ends; the front stays open
	NewModels4._qd(P, "glass", Vector3(-W * 0.5 + 0.1, 0.35, D * 0.5 - 0.06), Vector3(W * 0.5 - 0.1, 0.35, D * 0.5 - 0.06), Vector3(W * 0.5 - 0.1, H - 0.2, D * 0.5 - 0.06), Vector3(-W * 0.5 + 0.1, H - 0.2, D * 0.5 - 0.06), glass, Vector3(0, 0, -1))
	NewModels4._qd(P, "glass", Vector3(-W * 0.5 + 0.1, 0.35, D * 0.5 - 0.07), Vector3(-W * 0.5 + 0.1, H - 0.2, D * 0.5 - 0.07), Vector3(W * 0.5 - 0.1, H - 0.2, D * 0.5 - 0.07), Vector3(W * 0.5 - 0.1, 0.35, D * 0.5 - 0.07), glass, Vector3(0, 0, 1))
	for sx: float in [-1.0, 1.0]:
		var x := sx * (W * 0.5 - 0.06)
		NewModels4._qd(P, "glass", Vector3(x, 0.35, -D * 0.5 + 0.1), Vector3(x, 0.35, D * 0.5 - 0.1), Vector3(x, H - 0.2, D * 0.5 - 0.1), Vector3(x, H - 0.2, -D * 0.5 + 0.1), glass, Vector3(sx, 0, 0) * -1.0)
		NewModels4._qd(P, "glass", Vector3(x * 1.0 - sx * 0.01, 0.35, -D * 0.5 + 0.1), Vector3(x - sx * 0.01, H - 0.2, -D * 0.5 + 0.1), Vector3(x - sx * 0.01, H - 0.2, D * 0.5 - 0.1), Vector3(x - sx * 0.01, 0.35, D * 0.5 - 0.1), glass, Vector3(sx, 0, 0))
	if lod < 2:
		for k in 3:
			var x := lerpf(-W * 0.5 + 0.06, W * 0.5 - 0.06, k / 2.0)
			NewModels4._bm(P, "sheet", Vector3(x, 0.1, D * 0.5 - 0.05), Vector3(x, H - 0.14, D * 0.5 - 0.05), 0.05, 0.05, frame)
		NewModels4._bm(P, "sheet", Vector3(-W * 0.5, 0.35, D * 0.5 - 0.05), Vector3(W * 0.5, 0.35, D * 0.5 - 0.05), 0.05, 0.06, frame)
		# a bench along the back, a timetable case on the end and a sign pole
		if lod == 0:
			var wood := Color(0.4, 0.3, 0.2, 1.0)
			_wood_bm(P, Vector3(-W * 0.5 + 0.35, 0.46, D * 0.5 - 0.3), Vector3(W * 0.5 - 0.35, 0.46, D * 0.5 - 0.3), 0.36, 0.05, wood)
			for x: float in [-W * 0.5 + 0.5, W * 0.5 - 0.5]:
				NewModels4._bm(P, "sheet", Vector3(x, 0.1, D * 0.5 - 0.3), Vector3(x, 0.44, D * 0.5 - 0.3), 0.05, 0.04, frame)
			NewModels4._bx(P, "sheet", Vector3(-W * 0.5 + 0.8, 1.45, D * 0.5 - 0.075), Vector3(0.7, 0.9, 0.025), Color(0.12, 0.3, 0.55, 0.85))
			NewModels4._bx(P, "sheet", Vector3(-W * 0.5 + 0.8, 1.45, D * 0.5 - 0.092), Vector3(0.62, 0.82, 0.005), Color(0.9, 0.9, 0.88, 0.85))
			NewModels4._cyl(P, "steel", Vector3(W * 0.5 + 0.35, 0, -0.1), Vector3(W * 0.5 + 0.35, 2.6, -0.1), 0.03, 0.03, 7, Color(0.62, 0.64, 0.66, 0.7))
			NewModels4._bx(P, "sheet", Vector3(W * 0.5 + 0.35, 2.45, -0.14), Vector3(0.4, 0.4, 0.015), Color(0.1, 0.35, 0.6, 0.85))

static func _mailbox(P: NewModels4.Parts, lod: int) -> void:
	var wood := Color(0.32, 0.25, 0.2, 1.0)
	_wood_bm(P, Vector3(0, -0.05, 0), Vector3(0, 1.1, 0), 0.1, 0.1, wood)
	if lod < 2:
		_wood_bm(P, Vector3(0, 1.0, 0), Vector3(0, 1.0, -0.4), 0.05, 0.06, wood.darkened(0.05))       # the arm out toward the road
	var box := Color(0.2, 0.22, 0.24, 0.85)
	var seg: int = [14, 8, 6][lod]
	# an arched steel box lying along z, door at -z end
	NewModels4._put(P, "sheet", DroneParts.loft([[-0.28, 0.0, 1.17, 0.095, 0.11], [0.28, 0.0, 1.17, 0.095, 0.11]], 3.2, seg, true), NewModels4.I, box)
	if lod < 2:
		NewModels4._bx(P, "sheet", Vector3(0, 1.055, 0), Vector3(0.22, 0.01, 0.58), Color(0.5, 0.52, 0.54, 0.8))
	if lod < 2:
		NewModels4._bx(P, "sheet", Vector3(0.115, 1.27, 0.05), Vector3(0.012, 0.15, 0.04), Color(0.66, 0.05, 0.04, 0.9))      # the red flag, up
		NewModels4._bx(P, "sheet", Vector3(0.115, 1.2, 0.05), Vector3(0.012, 0.015, 0.05), Color(0.4, 0.4, 0.42, 0.7))

static func _works(P: NewModels4.Parts, lod: int) -> void:
	var red := Color(0.7, 0.05, 0.04, 0.85)
	var white := Color(0.9, 0.9, 0.87, 0.8)
	var orange := Color(0.92, 0.38, 0.03, 0.85)
	# a striped barrier: three boards on two A-frame feet, 1.5 m wide
	var legs := [-0.6, 0.6]
	for x: float in legs:
		NewModels4._bm(P, "sheet", Vector3(x, 0.0, -0.3), Vector3(x, 0.95, 0.0), 0.045, 0.05, Color(0.85, 0.85, 0.85, 0.7))
		NewModels4._bm(P, "sheet", Vector3(x, 0.0, 0.3), Vector3(x, 0.95, 0.0), 0.045, 0.05, Color(0.85, 0.85, 0.85, 0.7))
	for k in 3:
		var y := 0.55 + k * 0.17
		var n_s := 7 if lod == 0 else (5 if lod == 1 else 3)
		for i in n_s:
			var x0 := -0.75 + 1.5 * i / n_s; var x1 := -0.75 + 1.5 * (i + 1) / n_s
			NewModels4._qd(P, "sheet", Vector3(x1, y - 0.075, -0.02), Vector3(x0, y - 0.075, -0.02), Vector3(x0, y + 0.075, -0.02), Vector3(x1, y + 0.075, -0.02), red if i % 2 == 0 else white, Vector3(0, 0, -1))
			NewModels4._qd(P, "sheet", Vector3(x0, y - 0.075, 0.02), Vector3(x1, y - 0.075, 0.02), Vector3(x1, y + 0.075, 0.02), Vector3(x0, y + 0.075, 0.02), red if i % 2 == 0 else white, Vector3(0, 0, 1))
		NewModels4._bx(P, "sheet", Vector3(0, y, 0), Vector3(1.5, 0.15, 0.036), Color(0.85, 0.85, 0.85, 0.7))
	# an amber lamp on top
	NewModels4._cyl(P, "lens", Vector3(0, 1.0, 0), Vector3(0, 1.12, 0), 0.07, 0.065, 8, Color(0.85, 0.5, 0.03, 1.0))
	# cones
	var n_c := 4 if lod < 2 else 2
	for k in n_c:
		var c := Vector3(-1.2 + k * 0.8, 0, -1.3 - (k % 2) * 0.5)
		var seg: int = [14, 9, 6][lod]
		NewModels4._put(P, "sheet", DroneParts.lathe(DroneParts.crisp(PackedVector2Array([Vector2(0.0, 0.7), Vector2(0.03, 0.7), Vector2(0.19, 0.06), Vector2(0.19, 0.0), Vector2(0.0, 0.0)])), seg), Transform3D(Basis.IDENTITY, c), orange)
		NewModels4._bx(P, "sheet", c + Vector3(0, 0.0, 0), Vector3(0.38, 0.04, 0.38), Color(0.04, 0.04, 0.04, 0.8))
		if lod < 2:
			for yy: float in [0.4, 0.55]:
				var r := lerpf(0.19, 0.03, (yy - 0.06) / 0.64) + 0.002
				NewModels4._cyl(P, "sheet", c + Vector3(0, yy - 0.04, 0), c + Vector3(0, yy + 0.04, 0), r, r - 0.005, seg, Color(0.92, 0.92, 0.9, 0.8))
	# a warning plate on a folding stand (blank orange diamond)
	var xf := Transform3D(Basis(Vector3(0, 0, 1), PI * 0.25), Vector3(1.2, 1.15, -0.5))
	_plate(P, xf, 0.8, 0.8, orange, Color(0.03, 0.03, 0.03, 1.0), 0.03)
	for sx: float in [-1.0, 1.0]:
		if lod < 2:
			NewModels4._bm(P, "steel", Vector3(1.2, 0.6, -0.5), Vector3(1.2 + sx * 0.3, 0.0, -0.5 + sx * 0.18), 0.03, 0.03, Color(0.55, 0.57, 0.58, 0.8))
	if lod < 2:
		NewModels4._bm(P, "steel", Vector3(1.2, 0.6, -0.5), Vector3(1.2, 0.0, -0.8), 0.03, 0.03, Color(0.55, 0.57, 0.58, 0.8))

static func _milestone(P: NewModels4.Parts, lod: int) -> void:
	var stone := Color(0.56, 0.56, 0.54, 0.62)
	# a stone post with a rounded top, a white-painted face with a black band and a number
	if lod == 2:
		NewModels4._bx(P, "concrete", Vector3(0, 0.44, 0), Vector3(0.4, 0.88, 0.2), stone)
		return
	NewModels4._put(P, "concrete", DroneParts.rbox(Vector3(0.4, 0.88, 0.2), 6.0, 14 if lod == 0 else 8), Transform3D(Basis.IDENTITY, Vector3(0, 0.44, 0)), stone)
	NewModels4._bx(P, "concrete", Vector3(0, 0.02, 0), Vector3(0.52, 0.04, 0.34), Color(0.4, 0.35, 0.28, 0.5))
	if lod >= 1: return
	var b := NewModels2.Buf.new()
	var white := Color(0.9, 0.9, 0.86, 0.8)
	var black := Color(0.03, 0.03, 0.03, 1.0)
	b.quad(Vector3(0.15, 0.3, 0), Vector3(-0.15, 0.3, 0), Vector3(-0.15, 0.78, 0), Vector3(0.15, 0.78, 0), white, Vector3(0, 0, -1))
	b.quad(Vector3(0.15, 0.7, -0.002), Vector3(-0.15, 0.7, -0.002), Vector3(-0.15, 0.78, -0.002), Vector3(0.15, 0.78, -0.002), black, Vector3(0, 0, -1))
	_digit(b, 1, Vector2(-0.06, 0.5), 0.2, 0.03, black)
	_digit(b, 2, Vector2(0.06, 0.5), 0.2, 0.03, black)
	NewModels4._put(P, "sheet", _mx(b).data(), Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.1015)))

static func _bridge_rail(P: NewModels4.Parts, lod: int) -> void:
	var conc := Color(0.62, 0.62, 0.6, 0.62)
	var gal := Color(0.66, 0.68, 0.7, 0.8)
	# a concrete kerb along x (4 m, from x = 0), steel posts at 0 and 2 and 4, two round rails
	NewModels4._bx(P, "concrete", Vector3(2.0, 0.15, 0), Vector3(4.0, 0.3, 0.4), conc)
	var seg: int = [8, 6, 4][lod]
	for x: float in [0.0, 2.0, 4.0]:
		NewModels4._bm(P, "steel", Vector3(x, 0.3, 0), Vector3(x, 1.1, 0), 0.1, 0.07, gal)
		if lod < 2:
			NewModels4._bx(P, "steel", Vector3(x, 0.31, 0), Vector3(0.22, 0.02, 0.2), gal)
	for y: float in [0.62, 1.0]:
		NewModels4._cyl(P, "steel", Vector3(0.0, y, -0.0), Vector3(4.0, y, 0.0), 0.04, 0.04, seg, gal)
	if lod < 2:
		NewModels4._bx(P, "lens", Vector3(2.0, 1.04, -0.045), Vector3(0.1, 0.05, 0.008), Color(0.8, 0.3, 0.05, 1.0))

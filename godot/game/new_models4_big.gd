class_name NewModels4Big
extends RefCounted
## The farm and heavy vehicles of batch "models6" (see new_models4.gd): a tractor and its wheels, a farm trailer, a milk tanker,
## a bus and a motorcycle. Real metres, forward -z, up +y, origin on the ground in the middle of the length. Each returns the
## body and the wheels apart (see NewModels4.vehicle) so the wheels can spin and the front ones steer.


static func vehicle(name: String, lod: int, paint: Color) -> Dictionary:
	match name:
		"tractor_a": return _tractor(lod, paint)
		"tractor_trailer_a": return _trailer(lod, paint)
		"milk_tanker_a": return _tanker(lod, paint)
		"bus_a": return _bus(lod, paint)
		"motorcycle_a": return _moto(lod, paint)
	push_error("NewModels4Big: no vehicle called " + name)
	return {"body": ArrayMesh.new(), "wheels": [], "size": Vector3.ZERO, "wheel_radius": 0.3, "track": 1.5, "wheelbase": 2.5, "colliders": []}

## The four wheels of the tractor in place on their axles, as one still mesh (a stand-in for a parked or far tractor).
static func tractor_wheels(lod: int) -> ArrayMesh:
	var v := _tractor(lod, Color(0, 0, 0, 0))
	var out := ArrayMesh.new()
	for w: Dictionary in v["wheels"]:
		NewModels4._append_mesh(out, w["mesh"], Transform3D(Basis.IDENTITY, w["pos"]))
	return out

static func vehicle_colliders(name: String, v: Dictionary) -> Array:
	if v.has("colliders"): return v["colliders"]
	var s: Vector3 = v["size"]
	return [AABB(Vector3(-s.x * 0.5, 0.15, -s.z * 0.5), Vector3(s.x, s.y - 0.15, s.z))]

static func _wheel_entry(nm: String, pos: Vector3, R: float, w: float, style: String, lod: int, paint: Color, steer: bool) -> Dictionary:
	return {"name": nm, "pos": pos, "radius": R, "steer": steer, "mesh": NewModels4.wheel_side(R, w, style, lod, paint, pos.x < 0.0)}

static func _pack(P_: NewModels4.Parts, wheels: Array, size: Vector3, R: float, track: float, wb: float, colliders: Array) -> Dictionary:
	return {"body": NewModels4._finish(P_), "wheels": wheels, "size": size, "wheel_radius": R, "track": track, "wheelbase": wb, "colliders": colliders}

# ================================================================== tractor
static func _tractor(lod: int, paint: Color) -> Dictionary:
	var pc: Color = Color(0.1, 0.22, 0.45) if paint.a == 0.0 else paint
	pc = Color(pc.r, pc.g, pc.b, 0.78)
	var Pt := NewModels4.Parts.new()
	var nn: int = [4, 2, 1][lod]
	var dark := Color(0.07, 0.07, 0.075, 0.85)
	var roofc := Color(0.86, 0.86, 0.84, 0.85)
	var zf := -1.55; var zr := 1.05
	var Rf := 0.6; var Rr := 0.85
	var wf := 0.42; var wr := 0.65
	var xf := 1.0; var xr := 1.0 + 0.0                                # hub x (the wheels' outer faces stand at 1.05 and 1.2)
	xf = 1.06 - wf * 0.5 + 0.0
	xr = 1.2 - wr * 0.5
	# ---- engine hood and chassis
	NewModels4._put(Pt, "paint", NewModels4._shell([[-2.02, 0.34, 0.85, 1.26, 0.1], [-1.97, 0.43, 0.76, 1.42, 0.16], [-1.6, 0.47, 0.72, 1.56, 0.2], [-0.62, 0.5, 0.72, 1.62, 0.22],
		[-0.5, 0.5, 0.72, 1.62, 0.2]], nn, 0.04), NewModels4.I, pc)
	NewModels4._bx(Pt, "trim", Vector3(0, 0.78, -1.0), Vector3(0.72, 0.26, 2.0), dark)                   # the chassis under the hood
	for sx: float in [-1.0, 1.0]:
		NewModels4._bx(Pt, "trim", Vector3(sx * 0.42, 0.9, 0.45), Vector3(0.18, 0.34, 2.9), dark)         # side rails under the cab
	# grille and lamps
	NewModels4._rbx(Pt, "trim", Vector3(0, 1.1, -2.0), Vector3(0.52, 0.5, 0.06), dark, Basis.IDENTITY, 8)
	for k in 5:
		NewModels4._bx(Pt, "metal", Vector3(0, 0.92 + k * 0.1, -2.035), Vector3(0.46, 0.014, 0.01), NewModels4.C_ALU)
	for sx: float in [-1.0, 1.0]:
		NewModels4._rbx(Pt, "trim", Vector3(sx * 0.4, 1.34, -1.96), Vector3(0.2, 0.14, 0.12), dark, Basis.IDENTITY, 8)
		NewModels4._bx(Pt, "lens", Vector3(sx * 0.4, 1.34, -2.02), Vector3(0.17, 0.1, 0.02), NewModels4.C_LENS)
	# the front weight carrier and its weights
	NewModels4._bx(Pt, "trim", Vector3(0, 0.62, -2.18), Vector3(0.7, 0.36, 0.3), dark)
	for k in 2:
		NewModels4._bx(Pt, "sheet", Vector3(0, 0.58 + k * 0.17, -2.32), Vector3(0.62, 0.15, 0.1), Color(0.18, 0.18, 0.19, 0.7))
	# the front axle and the steering links; the rear axle with its differential and housings
	NewModels4._cyl(Pt, "trim", Vector3(-xf, Rf, zf), Vector3(xf, Rf, zf), 0.09, 0.09, 10, dark)
	NewModels4._cyl(Pt, "trim", Vector3(-xr, Rr, zr), Vector3(xr, Rr, zr), 0.11, 0.11, 10, dark)
	NewModels4._rbx(Pt, "trim", Vector3(0, Rr - 0.02, zr), Vector3(0.7, 0.5, 0.6), dark, Basis.IDENTITY, 10)
	# ---- the cab: pillars, floor, roof, glass, door detail
	var cz0 := -0.46; var cz1 := 1.3
	var chw := 0.78
	var floor_y := 1.02; var belt_y := 1.5; var roof_y := 2.86
	NewModels4._rbx(Pt, "paint", Vector3(0, floor_y, (cz0 + cz1) * 0.5), Vector3(chw * 2.0 + 0.04, 0.12, cz1 - cz0 + 0.04), pc, Basis.IDENTITY, 10)
	for cx: float in [-chw, chw]:
		for cz: float in [cz0 + 0.04, cz1 - 0.04]:
			NewModels4._bm(Pt, "paint", Vector3(cx, floor_y, cz), Vector3(cx, roof_y, cz), 0.09, 0.09, pc)
		NewModels4._bm(Pt, "paint", Vector3(cx, floor_y, 0.38), Vector3(cx, roof_y, 0.38), 0.07, 0.07, pc)
	# the door-height sill panels below the glass
	for sx: float in [-1.0, 1.0]:
		NewModels4._bx(Pt, "paint", Vector3(sx * chw, (floor_y + belt_y) * 0.5, (cz0 + cz1) * 0.5), Vector3(0.06, belt_y - floor_y, cz1 - cz0), pc)
	NewModels4._bx(Pt, "paint", Vector3(0, (floor_y + belt_y) * 0.5 + 0.05, cz0 + 0.02), Vector3(chw * 2.0, belt_y - floor_y - 0.1, 0.06), pc)
	NewModels4._bx(Pt, "paint", Vector3(0, (floor_y + belt_y) * 0.5 + 0.05, cz1 - 0.02), Vector3(chw * 2.0, belt_y - floor_y - 0.1, 0.06), pc)
	NewModels4._rbx(Pt, "paint", Vector3(0, roof_y + 0.03, (cz0 + cz1) * 0.5 - 0.02), Vector3(chw * 2.0 + 0.18, 0.13, cz1 - cz0 + 0.3), roofc, Basis.IDENTITY, 12)
	# the glass: front, rear, both sides (two panes a side)
	var gl := NewModels4.C_GLASS
	NewModels4._qd(Pt, "glass", Vector3(chw - 0.06, belt_y, cz0 - 0.005), Vector3(-chw + 0.06, belt_y, cz0 - 0.005), Vector3(-chw + 0.06, roof_y - 0.04, cz0 - 0.005), Vector3(chw - 0.06, roof_y - 0.04, cz0 - 0.005), gl, Vector3(0, 0, -1))
	NewModels4._qd(Pt, "glass", Vector3(-chw + 0.06, belt_y, cz1 + 0.005), Vector3(chw - 0.06, belt_y, cz1 + 0.005), Vector3(chw - 0.06, roof_y - 0.04, cz1 + 0.005), Vector3(-chw + 0.06, roof_y - 0.04, cz1 + 0.005), gl, Vector3(0, 0, 1))
	for sx: float in [-1.0, 1.0]:
		var x := sx * (chw + 0.005)
		for seg: Array in [[cz0 + 0.07, 0.34], [0.43, cz1 - 0.07]]:
			var z0: float = seg[0]; var z1: float = seg[1]
			var a := Vector3(x, belt_y, z0); var b := Vector3(x, belt_y, z1); var c := Vector3(x, roof_y - 0.04, z1); var d := Vector3(x, roof_y - 0.04, z0)
			if sx > 0.0: NewModels4._qd(Pt, "glass", a, b, c, d, gl, Vector3(1, 0, 0))
			else: NewModels4._qd(Pt, "glass", b, a, d, c, gl, Vector3(-1, 0, 0))
	# the door handle, steps, a beacon and work lamps on the roof, the exhaust and air intake
	if lod < 2:
		for k in 2:
			NewModels4._bx(Pt, "trim", Vector3(-chw - 0.12, 0.35 + k * 0.4 + 0.2, cz0 + 0.45), Vector3(0.26, 0.04, 0.3), Color(0.2, 0.2, 0.21, 0.7))
		NewModels4._bx(Pt, "metal", Vector3(chw + 0.012, 1.3, cz0 + 0.5), Vector3(0.02, 0.04, 0.16), NewModels4.C_ALU)
		for sx: float in [-1.0, 1.0]:
			NewModels4._bx(Pt, "lens", Vector3(sx * 0.5, roof_y + 0.14, cz0 - 0.1), Vector3(0.2, 0.1, 0.08), NewModels4.C_LENS)
			NewModels4._bx(Pt, "lens", Vector3(sx * 0.5, roof_y + 0.14, cz1 + 0.05), Vector3(0.2, 0.1, 0.08), NewModels4.C_LENS)
			NewModels4._bm(Pt, "trim", Vector3(sx * (chw + 0.03), 1.55, cz0 + 0.03), Vector3(sx * (chw + 0.22), 1.9, cz0 - 0.12), 0.03, 0.025, dark)       # mirror arm
			NewModels4._rbx(Pt, "trim", Vector3(sx * (chw + 0.27), 1.95, cz0 - 0.14), Vector3(0.08, 0.3, 0.2), dark, Basis.IDENTITY, 8)
		NewModels4._cyl(Pt, "lens", Vector3(0.0, roof_y + 0.09, cz0 + 0.3), Vector3(0.0, roof_y + 0.25, cz0 + 0.3), 0.07, 0.065, 8, NewModels4.C_AMBER)
		NewModels4._cyl(Pt, "steel", Vector3(0.26, 1.6, -0.62), Vector3(0.26, 2.35, -0.62), 0.045, 0.04, 8, Color(0.2, 0.2, 0.21, 0.6))                       # exhaust
		NewModels4._cyl(Pt, "metal", Vector3(0.26, 2.35, -0.62), Vector3(0.26, 2.41, -0.62), 0.065, 0.0, 8, NewModels4.C_ALU)
		NewModels4._cyl(Pt, "sheet", Vector3(-0.3, 1.58, -0.8), Vector3(-0.3, 2.0, -0.8), 0.07, 0.07, 8, Color(0.12, 0.12, 0.13, 0.8))                       # air intake
	# ---- rear fenders, the 3-point linkage, the drawbar and the PTO
	for sx: float in [-1.0, 1.0]:
		var fx := sx * xr
		NewModels4._rbx(Pt, "paint", Vector3(fx + sx * 0.02, Rr * 2.0 + 0.1, zr + 0.08), Vector3(wr + 0.18, 0.07, 1.9), pc, Basis(Vector3(1, 0, 0), 0.0), 10)
		NewModels4._rbx(Pt, "paint", Vector3(fx + sx * 0.02, Rr * 2.0 - 0.04, zr - 0.9), Vector3(wr + 0.18, 0.07, 0.4), pc, Basis(Vector3(1, 0, 0), 0.5), 8)
		NewModels4._rbx(Pt, "paint", Vector3(fx + sx * 0.02, Rr * 2.0 - 0.04, zr + 1.05), Vector3(wr + 0.18, 0.07, 0.4), pc, Basis(Vector3(1, 0, 0), -0.5), 8)
		if lod < 2:
			NewModels4._cyl(Pt, "steel", Vector3(sx * 0.3, 0.75, zr + 0.2), Vector3(sx * 0.62, 0.62, zr + 1.0), 0.03, 0.025, 6, Color(0.2, 0.2, 0.21, 0.7))    # lower link
			NewModels4._cyl(Pt, "steel", Vector3(sx * 0.62, 0.62, zr + 1.0), Vector3(sx * 0.66, 0.62, zr + 1.18), 0.035, 0.035, 6, Color(0.5, 0.5, 0.52, 0.6))
			NewModels4._bm(Pt, "trim", Vector3(sx * 0.4, 1.25, zr - 0.2), Vector3(sx * 0.45, 0.72, zr + 0.1), 0.08, 0.06, dark)                                    # lift arm
	if lod < 2:
		NewModels4._cyl(Pt, "steel", Vector3(0, 1.55, zr + 0.2), Vector3(0, 1.2, zr + 0.95), 0.03, 0.03, 6, Color(0.2, 0.2, 0.21, 0.7))                   # top link
		NewModels4._cyl(Pt, "steel", Vector3(0, 0.82, zr + 0.18), Vector3(0, 0.82, zr + 0.4), 0.035, 0.035, 8, Color(0.55, 0.55, 0.57, 0.6))                # PTO stub
		NewModels4._bx(Pt, "trim", Vector3(0, 0.55, zr + 0.8), Vector3(0.32, 0.12, 0.5), dark)                                                          # drawbar
		NewModels4._bx(Pt, "lens", Vector3(0.52, 1.66, 2.31), Vector3(0.18, 0.1, 0.03), NewModels4.C_RED)
		NewModels4._bx(Pt, "lens", Vector3(-0.52, 1.66, 2.31), Vector3(0.18, 0.1, 0.03), NewModels4.C_RED)
	var wheels: Array = []
	for sx: float in [-1.0, 1.0]:
		var side := "l" if sx < 0.0 else "r"
		wheels.append(_wheel_entry("wheel_f" + side, Vector3(sx * xf, Rf, zf), Rf, wf, "tractor_f", lod, pc, true))
		wheels.append(_wheel_entry("wheel_r" + side, Vector3(sx * xr, Rr, zr), Rr, wr, "tractor", lod, pc, false))
	var col := [AABB(Vector3(-0.55, 0.5, -2.35), Vector3(1.1, 1.2, 1.9)), AABB(Vector3(-0.95, 0.9, -0.5), Vector3(1.9, 2.1, 1.85)), AABB(Vector3(-1.25, 0.0, 0.2), Vector3(2.5, 1.75, 1.7))]
	return _pack(Pt, wheels, Vector3(2.4, 2.95, 4.7), Rr, xr * 2.0, zr - zf, col)

# ================================================================== trailer
static func _trailer(lod: int, paint: Color) -> Dictionary:
	var pc: Color = Color(0.45, 0.1, 0.07) if paint.a == 0.0 else paint
	pc = Color(pc.r, pc.g, pc.b, 0.6)
	var Pt := NewModels4.Parts.new()
	var dark := Color(0.07, 0.07, 0.075, 0.8)
	var R := 0.55; var tw := 0.4
	var z0 := -1.8; var z1 := 2.8                                     # the tub, 4.6 m
	var hw := 1.1
	var floor_y := 0.95
	var top := 1.95
	# chassis rails, the floor and the tub's four walls (corrugated ribs on the sides)
	for sx: float in [-1.0, 1.0]:
		NewModels4._bx(Pt, "trim", Vector3(sx * 0.5, 0.84, (z0 + z1) * 0.5), Vector3(0.16, 0.2, z1 - z0), dark)
	NewModels4._rbx(Pt, "paint", Vector3(0, floor_y, (z0 + z1) * 0.5), Vector3(hw * 2.0, 0.08, z1 - z0), pc, Basis.IDENTITY, 8)
	for sx: float in [-1.0, 1.0]:
		NewModels4._rbx(Pt, "paint", Vector3(sx * (hw - 0.03), (floor_y + top) * 0.5, (z0 + z1) * 0.5), Vector3(0.06, top - floor_y, z1 - z0), pc, Basis.IDENTITY, 8)
		if lod == 0:
			var n_r := 22
			for k in n_r:
				var z := lerpf(z0 + 0.2, z1 - 0.2, k / (n_r - 1.0))
				NewModels4._bx(Pt, "paint", Vector3(sx * (hw + 0.012), (floor_y + top) * 0.5 + 0.05, z), Vector3(0.025, top - floor_y - 0.25, 0.08), Color(pc.r * 0.92, pc.g * 0.92, pc.b * 0.92, pc.a))
		# top rail and the pillars
		NewModels4._rbx(Pt, "paint", Vector3(sx * hw, top, (z0 + z1) * 0.5), Vector3(0.1, 0.1, z1 - z0 + 0.1), Color(pc.r * 0.85, pc.g * 0.85, pc.b * 0.85, pc.a), Basis.IDENTITY, 8)
		if lod < 2:
			for z: float in [z0, 0.5, z1]:
				NewModels4._bx(Pt, "paint", Vector3(sx * (hw + 0.03), (floor_y + top) * 0.5, z), Vector3(0.07, top - floor_y, 0.12), Color(pc.r * 0.85, pc.g * 0.85, pc.b * 0.85, pc.a))
	NewModels4._rbx(Pt, "paint", Vector3(0, (floor_y + top) * 0.5 + 0.1, z0 + 0.03), Vector3(hw * 2.0, top - floor_y + 0.2, 0.07), pc, Basis.IDENTITY, 8)           # headboard, taller
	NewModels4._rbx(Pt, "paint", Vector3(0, (floor_y + top) * 0.5, z1), Vector3(hw * 2.0, top - floor_y, 0.07), pc, Basis.IDENTITY, 8)                              # tailgate
	if lod < 2:
		NewModels4._bx(Pt, "trim", Vector3(0, floor_y + 0.2, z1 + 0.04), Vector3(hw * 1.9, 0.04, 0.03), dark)
		for sx: float in [-1.0, 1.0]:
			NewModels4._bx(Pt, "lens", Vector3(sx * (hw - 0.15), 1.15, z1 + 0.06), Vector3(0.2, 0.1, 0.03), NewModels4.C_RED)
			# mudguards over the tandem wheels
			for zc: float in [1.2, 2.2]:
				NewModels4._rbx(Pt, "paint", Vector3(sx * (hw + 0.22), R * 2.0 + 0.08, zc), Vector3(0.52, 0.05, 0.95), Color(pc.r * 0.8, pc.g * 0.8, pc.b * 0.8, pc.a), Basis.IDENTITY, 8)
	# the drawbar: an A-frame of two arms meeting in a hitch eye, with a jack stand
	for sx: float in [-1.0, 1.0]:
		NewModels4._bm(Pt, "trim", Vector3(sx * 0.5, 0.82, z0 + 0.2), Vector3(sx * 0.06, 0.74, z0 - 1.5), 0.1, 0.1, dark)
	NewModels4._bx(Pt, "trim", Vector3(0, 0.74, z0 - 1.55), Vector3(0.2, 0.12, 0.2), dark)
	if lod < 2:
		NewModels4._cyl(Pt, "steel", Vector3(0, 0.68, z0 - 1.58), Vector3(0, 0.8, z0 - 1.58), 0.07, 0.07, 10, Color(0.5, 0.5, 0.52, 0.6))
		NewModels4._cyl(Pt, "steel", Vector3(0.0, 0.7, z0 - 0.9), Vector3(0.0, 0.18, z0 - 0.9), 0.04, 0.04, 6, Color(0.5, 0.5, 0.52, 0.6))
		NewModels4._bx(Pt, "trim", Vector3(0.0, 0.15, z0 - 0.9), Vector3(0.18, 0.04, 0.18), dark)
	# two axles under the floor
	var wheels: Array = []
	for zc: float in [1.2, 2.2]:
		var xh := 1.16 - tw * 0.5
		NewModels4._cyl(Pt, "trim", Vector3(-xh, R, zc), Vector3(xh, R, zc), 0.06, 0.06, 8, dark)
		for sx: float in [-1.0, 1.0]:
			wheels.append(_wheel_entry("wheel_%s%s" % ["a" if zc < 2.0 else "b", "l" if sx < 0.0 else "r"], Vector3(sx * xh, R, zc), R, tw, "heavy", lod, Color(0.7, 0.2, 0.1), false))
	var col := [AABB(Vector3(-1.2, 0.8, z0 - 0.05), Vector3(2.4, top - 0.8, z1 - z0 + 0.1)), AABB(Vector3(-0.3, 0.6, z0 - 1.7), Vector3(0.6, 0.3, 1.7))]
	return _pack(Pt, wheels, Vector3(2.4, top + 0.1, 6.6), R, 2.0 * (1.16 - tw * 0.5), 1.0, col)

# ================================================================== milk tanker
static func _tanker(lod: int, paint: Color) -> Dictionary:
	var pc: Color = Color(0.9, 0.9, 0.88) if paint.a == 0.0 else paint
	pc = Color(pc.r, pc.g, pc.b, 0.85)
	var Pt := NewModels4.Parts.new()
	var nn: int = [4, 2, 1][lod]
	var dark := Color(0.07, 0.07, 0.075, 0.85)
	var steel := Color(0.8, 0.82, 0.84, 0.75)
	var R := 0.52; var tw := 0.32
	var zf := -3.1; var zr1 := 2.35; var zr2 := 3.65
	var xh := 1.2
	var chassis_y := 0.95
	# the chassis rails and cross members
	for sx: float in [-1.0, 1.0]:
		NewModels4._bx(Pt, "trim", Vector3(sx * 0.55, chassis_y - 0.05, 0.4), Vector3(0.2, 0.26, 9.0), dark)
	# the cab: a forward-control day cab, 2.3 wide, 2.2 high above the frame
	var cz0 := -4.45; var cz1 := -2.35
	NewModels4._put(Pt, "paint", NewModels4._shell([[cz0, 1.0, 0.85, 2.45, 0.2], [cz0 + 0.05, 1.14, 0.8, 2.9, 0.22], [cz0 + 0.3, 1.16, 0.78, 3.12, 0.28], [cz0 + 0.55, 1.16, 0.78, 3.2, 0.25],
		[cz1 - 0.12, 1.16, 0.78, 3.2, 0.25], [cz1, 1.1, 0.8, 3.12, 0.2]], nn, 0.05), NewModels4.I, pc)
	# glass: a big windscreen (raked), door windows, a small rear glass
	var gl := NewModels4.C_GLASS
	NewModels4._qd(Pt, "glass", Vector3(1.0, 1.72, cz0 + 0.07), Vector3(-1.0, 1.72, cz0 + 0.07), Vector3(-1.0, 3.02, cz0 + 0.34), Vector3(1.0, 3.02, cz0 + 0.34), gl, Vector3(0, 0.25, -1).normalized())
	for sx: float in [-1.0, 1.0]:
		var x := sx * 1.172
		var a := Vector3(x, 1.85, cz0 + 0.55); var b := Vector3(x, 1.85, cz1 - 0.4); var c := Vector3(x, 3.0, cz1 - 0.4); var d := Vector3(x, 3.0, cz0 + 0.55)
		if sx > 0.0: NewModels4._qd(Pt, "glass", a, b, c, d, gl, Vector3(1, 0, 0))
		else: NewModels4._qd(Pt, "glass", b, a, d, c, gl, Vector3(-1, 0, 0))
		NewModels4._bx(Pt, "trim", Vector3(sx * 1.17, 1.5, (cz0 + cz1) * 0.5 - 0.1), Vector3(0.012, 0.012, 1.4), dark)           # sill line
		NewModels4._bx(Pt, "trim", Vector3(sx * 1.17, 2.2, cz0 + 1.1), Vector3(0.012, 1.3, 0.012), dark)                          # door gap
	# front: bumper, grille, lamps, a visor
	NewModels4._rbx(Pt, "trim", Vector3(0, 0.75, cz0 - 0.03), Vector3(2.3, 0.34, 0.18), dark, Basis.IDENTITY, 10)
	NewModels4._rbx(Pt, "trim", Vector3(0, 1.4, cz0 - 0.005), Vector3(1.2, 0.8, 0.05), Color(0.12, 0.12, 0.13, 0.85), Basis.IDENTITY, 8)
	if lod < 2:
		for k in 6:
			NewModels4._bx(Pt, "metal", Vector3(0, 1.1 + k * 0.12, cz0 - 0.04), Vector3(1.1, 0.02, 0.01), NewModels4.C_ALU)
	for sx: float in [-1.0, 1.0]:
		NewModels4._rbx(Pt, "trim", Vector3(sx * 0.9, 1.15, cz0 + 0.02), Vector3(0.35, 0.22, 0.12), dark, Basis.IDENTITY, 8)
		NewModels4._bx(Pt, "lens", Vector3(sx * 0.9, 1.15, cz0 - 0.04), Vector3(0.31, 0.17, 0.02), NewModels4.C_LENS)
	NewModels4._bx(Pt, "sheet", Vector3(0, 0.9, cz0 - 0.1), Vector3(0.6, 0.12, 0.01), Color(0.9, 0.88, 0.8, 1.0))
	NewModels4._rbx(Pt, "paint", Vector3(0, 3.22, cz0 + 0.28), Vector3(2.2, 0.06, 0.45), Color(pc.r * 0.85, pc.g * 0.85, pc.b * 0.85, pc.a), Basis(Vector3(1, 0, 0), -0.1), 8)
	# mirrors on long arms, a step, a fuel tank and the exhaust stack behind the cab
	for sx: float in [-1.0, 1.0]:
		if lod < 2:
			NewModels4._bm(Pt, "trim", Vector3(sx * 1.17, 2.9, cz0 + 0.7), Vector3(sx * 1.42, 3.0, cz0 + 0.55), 0.04, 0.04, dark)
			NewModels4._rbx(Pt, "trim", Vector3(sx * 1.48, 2.65, cz0 + 0.55), Vector3(0.1, 0.6, 0.28), dark, Basis.IDENTITY, 8)
			NewModels4._bx(Pt, "glass", Vector3(sx * 1.48, 2.65, cz0 + 0.55 - 0.145), Vector3(0.07, 0.55, 0.003), gl)
			NewModels4._bx(Pt, "trim", Vector3(sx * 1.2, 0.6, cz0 + 1.0), Vector3(0.3, 0.05, 0.4), dark)
			NewModels4._cyl(Pt, "metal", Vector3(sx * 0.8, 0.82, -1.9), Vector3(sx * 0.8, 0.82, -0.9), 0.3, 0.3, 14, Color(0.7, 0.72, 0.74, 0.65))               # fuel tank
	if lod < 2:
		NewModels4._cyl(Pt, "steel", Vector3(-1.0, 1.0, cz1 + 0.1), Vector3(-1.0, 3.5, cz1 + 0.1), 0.07, 0.07, 8, Color(0.7, 0.72, 0.74, 0.7))
	# ---- the tank: a stainless ellipse in section, domed at both ends, 6.8 m
	var tz0 := -2.15; var tz1 := 4.65
	var cy := 2.05; var thw := 1.12; var thh := 0.98
	var secs: Array = [[tz0, 0.0, cy, 0.0, 0.0], [tz0 + 0.04, 0.0, cy, thw * 0.55, thh * 0.55], [tz0 + 0.18, 0.0, cy, thw * 0.86, thh * 0.86], [tz0 + 0.4, 0.0, cy, thw * 0.97, thh * 0.97],
		[tz0 + 0.8, 0.0, cy, thw, thh], [tz1 - 0.8, 0.0, cy, thw, thh], [tz1 - 0.4, 0.0, cy, thw * 0.97, thh * 0.97], [tz1 - 0.18, 0.0, cy, thw * 0.86, thh * 0.86],
		[tz1 - 0.04, 0.0, cy, thw * 0.55, thh * 0.55], [tz1, 0.0, cy, 0.0, 0.0]]
	NewModels4._put(Pt, "metal", DroneParts.loft(secs, 2.0, [30, 18, 10][lod]), NewModels4.I, steel)
	# the saddle supports and the compartment bands
	for z: float in [-1.2, 0.8, 2.8, 4.3]:
		NewModels4._bx(Pt, "trim", Vector3(0, 1.2, z), Vector3(1.9, 0.24, 0.22), dark)
		if lod < 2:
			NewModels4._put(Pt, "metal", DroneParts.loft([[z - 0.03, 0.0, cy, thw + 0.012, thh + 0.012], [z + 0.03, 0.0, cy, thw + 0.012, thh + 0.012]], 2.0, [30, 18, 10][lod], true), NewModels4.I, Color(0.6, 0.62, 0.65, 0.6))
	# manways on top: a ring, a lid, a hinge
	for z: float in [-0.9, 1.4, 3.5]:
		if lod == 2: break
		NewModels4._cyl(Pt, "metal", Vector3(0, cy + thh - 0.02, z), Vector3(0, cy + thh + 0.09, z), 0.27, 0.27, 16 if lod == 0 else 8, Color(0.7, 0.72, 0.74, 0.65))
		NewModels4._cyl(Pt, "metal", Vector3(0, cy + thh + 0.09, z), Vector3(0, cy + thh + 0.13, z), 0.25, 0.22, 16 if lod == 0 else 8, Color(0.85, 0.86, 0.88, 0.7))
		NewModels4._bx(Pt, "metal", Vector3(0.27, cy + thh + 0.1, z), Vector3(0.06, 0.06, 0.1), Color(0.5, 0.5, 0.52, 0.7))
	# the walkway rail along the top, a rear ladder, the valve cabinet and the sample pipework at the back
	if lod < 2:
		for sx: float in [-1.0, 1.0]:
			NewModels4._cyl(Pt, "metal", Vector3(sx * 0.42, cy + thh + 0.3, tz0 + 0.5), Vector3(sx * 0.42, cy + thh + 0.3, tz1 - 0.5), 0.016, 0.016, 5, Color(0.8, 0.82, 0.84, 0.7))
			for z: float in [-0.9, 1.4, 3.5, 4.4]:
				NewModels4._cyl(Pt, "metal", Vector3(sx * 0.42, cy + thh - 0.05, z), Vector3(sx * 0.42, cy + thh + 0.3, z), 0.014, 0.014, 5, Color(0.8, 0.82, 0.84, 0.7))
		for k in 7:
			NewModels4._cyl(Pt, "metal", Vector3(-0.3, 1.0 + k * 0.28, tz1 + 0.12), Vector3(0.3, 1.0 + k * 0.28, tz1 + 0.12), 0.016, 0.016, 5, Color(0.8, 0.82, 0.84, 0.7))
		for sx: float in [-1.0, 1.0]:
			NewModels4._cyl(Pt, "metal", Vector3(sx * 0.3, 1.0, tz1 + 0.12), Vector3(sx * 0.3, 2.9, tz1 + 0.12), 0.018, 0.018, 5, Color(0.8, 0.82, 0.84, 0.7))
		NewModels4._rbx(Pt, "metal", Vector3(0.0, 1.35, tz1 + 0.15), Vector3(1.3, 0.7, 0.2), Color(0.7, 0.72, 0.74, 0.65), Basis.IDENTITY, 8)
		NewModels4._cyl(Pt, "metal", Vector3(0.9, 0.55, tz1 + 0.15), Vector3(0.9, 0.55, tz1 + 0.55), 0.045, 0.045, 8, Color(0.7, 0.72, 0.74, 0.65))
		for sx: float in [-1.0, 1.0]:
			NewModels4._bx(Pt, "lens", Vector3(sx * 1.0, 1.0, tz1 + 0.15), Vector3(0.22, 0.12, 0.04), NewModels4.C_RED)
		NewModels4._bx(Pt, "trim", Vector3(0, 0.55, tz1 + 0.3), Vector3(2.3, 0.1, 0.1), dark)                       # rear underrun bar
		# the company band on the tank: a blue stripe round its middle
		var band := Color(0.1, 0.25, 0.55, 0.85)
	# mud flaps and guards
	for z: float in [zr2 + 0.7]:
		for sx: float in [-1.0, 1.0]:
			NewModels4._bx(Pt, "trim", Vector3(sx * 1.05, 0.3, z), Vector3(0.45, 0.4, 0.02), dark)
	for sx: float in [-1.0, 1.0]:
		NewModels4._rbx(Pt, "paint", Vector3(sx * 1.15, R * 2.0 + 0.2, (zr1 + zr2) * 0.5), Vector3(0.5, 0.05, 2.4), Color(pc.r * 0.8, pc.g * 0.8, pc.b * 0.8, pc.a), Basis.IDENTITY, 8)
		if lod < 2:
			NewModels4._bx(Pt, "trim", Vector3(sx * 1.0, 0.5, 0.9), Vector3(0.05, 0.12, 4.0), dark)
	# axles
	var wheels: Array = []
	for zc: float in [zf, zr1, zr2]:
		var front := zc == zf
		NewModels4._cyl(Pt, "trim", Vector3(-xh + tw * 0.5, R, zc), Vector3(xh - tw * 0.5, R, zc), 0.08, 0.08, 8, dark)
		for sx: float in [-1.0, 1.0]:
			var nm := "wheel_%s%s" % ["f" if front else ("a" if zc == zr1 else "b"), "l" if sx < 0.0 else "r"]
			wheels.append(_wheel_entry(nm, Vector3(sx * (xh - tw * 0.5 + 0.02), R, zc), R, tw, "heavy", lod, Color(0.78, 0.78, 0.8), front))
	var col := [AABB(Vector3(-1.2, 0.5, -4.55), Vector3(2.4, 2.8, 2.3)), AABB(Vector3(-1.15, 1.05, -2.2), Vector3(2.3, 2.0, 6.95)), AABB(Vector3(-1.2, 0.3, -2.2), Vector3(2.4, 0.8, 6.95))]
	return _pack(Pt, wheels, Vector3(2.5, 3.4, 9.4), R, 2.0 * (xh - tw * 0.5 + 0.02), zr2 - zf, col)

# ================================================================== bus
static func _bus(lod: int, paint: Color) -> Dictionary:
	var pc: Color = Color(0.86, 0.84, 0.74) if paint.a == 0.0 else paint
	pc = Color(pc.r, pc.g, pc.b, 0.85)
	var Pt := NewModels4.Parts.new()
	var nn: int = [4, 2, 1][lod]
	var dark := Color(0.07, 0.07, 0.075, 0.85)
	var stripe := Color(0.55, 0.08, 0.07, 0.85)
	var L := 10.6; var hw := 1.25
	var R := 0.5; var tw := 0.3
	var zf := -L * 0.5 + 1.55; var zr := L * 0.5 - 2.2
	var xh := hw - tw * 0.5 + 0.02
	var belt := 1.05; var roof := 3.05
	# the body: a rounded box tapering a little at both ends
	NewModels4._put(Pt, "paint", NewModels4._shell([[-L * 0.5, hw - 0.18, 0.5, roof - 0.35, 0.3], [-L * 0.5 + 0.08, hw - 0.04, 0.42, roof - 0.12, 0.3], [-L * 0.5 + 0.5, hw, 0.4, roof, 0.3],
		[L * 0.5 - 0.5, hw, 0.4, roof, 0.3], [L * 0.5 - 0.06, hw - 0.04, 0.45, roof - 0.15, 0.28], [L * 0.5, hw - 0.14, 0.5, roof - 0.4, 0.25]], nn, 0.07), NewModels4.I, pc)
	# the coloured band along the lower body and the black skirt below
	for sx: float in [-1.0, 1.0]:
		NewModels4._bx(Pt, "paint", Vector3(sx * (hw + 0.004), 0.82, 0.0), Vector3(0.012, 0.2, L - 1.0), stripe)
		NewModels4._bx(Pt, "trim", Vector3(sx * (hw + 0.004), 0.5, 0.0), Vector3(0.012, 0.22, L - 0.6), dark)
	# side windows between pillars, a front screen and a rear screen
	var gl := NewModels4.C_GLASS
	var y0 := belt + 0.1; var y1 := roof - 0.42
	var zs := [-L * 0.5 + 2.6, -L * 0.5 + 4.0, -L * 0.5 + 5.4, -L * 0.5 + 6.8, -L * 0.5 + 8.2, L * 0.5 - 0.8]
	for sx: float in [-1.0, 1.0]:
		var x := sx * (hw + 0.006)
		var segs: Array = []
		if sx > 0.0:
			segs = [[-L * 0.5 + 0.9, -L * 0.5 + 2.2, "door"], [zs[0] + 0.1, zs[1] - 0.06, ""], [zs[1] + 0.06, zs[2] - 0.06, ""], [zs[2] + 0.06, zs[3] - 0.06, ""], [zs[3] + 0.06, zs[4] - 0.06, ""], [zs[4] + 0.06, zs[5], ""]]
		else:
			segs = [[-L * 0.5 + 1.4, zs[1] - 0.06, ""], [zs[1] + 0.06, zs[2] - 0.06, ""], [zs[2] + 0.06, zs[3] - 0.06, ""], [zs[3] + 0.06, zs[4] - 0.06, ""], [zs[4] + 0.06, zs[5], ""]]
		for sg: Array in segs:
			var z0: float = sg[0]; var z1: float = sg[1]
			var a := Vector3(x, y0, z0); var b := Vector3(x, y0, z1); var c := Vector3(x, y1, z1); var d := Vector3(x, y1, z0)
			if sx > 0.0: NewModels4._qd(Pt, "glass", a, b, c, d, gl, Vector3(1, 0, 0))
			else: NewModels4._qd(Pt, "glass", b, a, d, c, gl, Vector3(-1, 0, 0))
			if String(sg[2]) == "door":
				# a two-leaf glazed door: a dark frame, a centre seam and a handrail
				NewModels4._bx(Pt, "trim", Vector3(x + 0.006, (belt + 0.1 + y1) * 0.5 - 0.35, (z0 + z1) * 0.5), Vector3(0.01, y1 - belt - 0.1 + 0.7, 0.02), dark)
				NewModels4._bx(Pt, "trim", Vector3(x + 0.006, 1.2, z0), Vector3(0.012, 2.1, 0.03), dark)
				NewModels4._bx(Pt, "trim", Vector3(x + 0.006, 1.2, z1), Vector3(0.012, 2.1, 0.03), dark)
	var wy := roof - 0.46
	# windscreen (two panes under a destination board), a rear window
	for k: float in [-1.0, 1.0]:
		var xa := 0.03 if k < 0.0 else hw - 0.18
		var xb := -hw + 0.18 if k < 0.0 else -0.03
		var zf0 := -L * 0.5 - 0.0
		NewModels4._qd(Pt, "glass", Vector3(-0.03 if k > 0.0 else hw - 0.17, belt + 0.28, zf0 - 0.012), Vector3(-hw + 0.17 if k > 0.0 else 0.03, belt + 0.28, zf0 - 0.012),
			Vector3(-hw + 0.17 if k > 0.0 else 0.03, roof - 0.62, zf0 - 0.012), Vector3(-0.03 if k > 0.0 else hw - 0.17, roof - 0.62, zf0 - 0.012), gl, Vector3(0, 0, -1))
	NewModels4._bx(Pt, "trim", Vector3(0, roof - 0.42, -L * 0.5 - 0.012), Vector3(hw * 2.0 - 0.45, 0.2, 0.012), Color(0.03, 0.03, 0.03, 0.9))
	NewModels4._bx(Pt, "lens", Vector3(0, roof - 0.42, -L * 0.5 - 0.02), Vector3(hw * 2.0 - 0.7, 0.1, 0.006), NewModels4.C_AMBER)
	NewModels4._bx(Pt, "glass", Vector3(0, belt + 0.7, L * 0.5 + 0.006), Vector3(hw * 1.5, 0.6, 0.006), gl)
	# bumpers, lamps, plates, mirrors, roof pods
	NewModels4._rbx(Pt, "trim", Vector3(0, 0.48, -L * 0.5 - 0.0), Vector3(hw * 2.0 - 0.1, 0.3, 0.2), dark, Basis.IDENTITY, 10)
	NewModels4._rbx(Pt, "trim", Vector3(0, 0.5, L * 0.5), Vector3(hw * 2.0 - 0.1, 0.3, 0.2), dark, Basis.IDENTITY, 10)
	for sx: float in [-1.0, 1.0]:
		NewModels4._rbx(Pt, "trim", Vector3(sx * (hw - 0.35), 0.82, -L * 0.5 - 0.03), Vector3(0.3, 0.18, 0.1), dark, Basis.IDENTITY, 8)
		NewModels4._bx(Pt, "lens", Vector3(sx * (hw - 0.35), 0.82, -L * 0.5 - 0.075), Vector3(0.26, 0.14, 0.02), NewModels4.C_LENS)
		NewModels4._bx(Pt, "lens", Vector3(sx * (hw - 0.3), 1.1, L * 0.5 + 0.015), Vector3(0.2, 0.3, 0.03), NewModels4.C_RED)
		if lod < 2:
			NewModels4._bm(Pt, "trim", Vector3(sx * (hw - 0.05), 2.0, -L * 0.5 + 0.8), Vector3(sx * (hw + 0.38), 2.4, -L * 0.5 + 0.55), 0.04, 0.04, dark)
			NewModels4._rbx(Pt, "trim", Vector3(sx * (hw + 0.42), 2.2, -L * 0.5 + 0.55), Vector3(0.09, 0.5, 0.22), dark, Basis.IDENTITY, 8)
	NewModels4._bx(Pt, "sheet", Vector3(0, 0.62, -L * 0.5 - 0.105), Vector3(0.55, 0.11, 0.008), Color(0.9, 0.88, 0.8, 1.0))
	if lod < 2:
		NewModels4._rbx(Pt, "sheet", Vector3(0, roof + 0.1, 0.5), Vector3(1.0, 0.18, 2.6), Color(0.85, 0.85, 0.83, 0.7), Basis.IDENTITY, 8)       # roof vent pod
		NewModels4._rbx(Pt, "sheet", Vector3(0, roof + 0.07, 3.7), Vector3(1.2, 0.12, 1.4), Color(0.85, 0.85, 0.83, 0.7), Basis.IDENTITY, 8)
		# the engine louvres at the rear
		for k in 6:
			NewModels4._bx(Pt, "trim", Vector3(0, 1.55 + k * 0.1, L * 0.5 + 0.01), Vector3(hw * 1.2, 0.04, 0.012), Color(0.1, 0.1, 0.11, 0.8))
	var wheels: Array = []
	for zc: float in [zf, zr]:
		NewModels4._cyl(Pt, "trim", Vector3(-xh + tw * 0.5, R, zc), Vector3(xh - tw * 0.5, R, zc), 0.07, 0.07, 8, dark)
		for sx: float in [-1.0, 1.0]:
			if lod < 2:
				var an := Vector3(sx, 0, 0)
				NewModels4._disc(Pt, "trim", Vector3(sx * (hw + 0.006), R, zc), an, R * 1.2, 24 if lod == 0 else 12, Color(0.015, 0.015, 0.018, 0.9))
			wheels.append(_wheel_entry("wheel_%s%s" % ["f" if zc == zf else "r", "l" if sx < 0.0 else "r"], Vector3(sx * xh, R, zc), R, tw, "heavy", lod, Color(0.7, 0.7, 0.72), zc == zf))
	var col := [AABB(Vector3(-hw, 0.4, -L * 0.5), Vector3(hw * 2.0, roof - 0.4, L))]
	return _pack(Pt, wheels, Vector3(hw * 2.0, roof + 0.2, L), R, 2.0 * xh, zr - zf, col)

# ================================================================== motorcycle
static func _moto(lod: int, paint: Color) -> Dictionary:
	var pc: Color = Color(0.5, 0.06, 0.05) if paint.a == 0.0 else paint
	pc = Color(pc.r, pc.g, pc.b, 0.92)
	var Pt := NewModels4.Parts.new()
	var dark := Color(0.06, 0.06, 0.065, 0.85)
	var R := 0.31; var tw := 0.13
	var zf := -0.7; var zr := 0.68
	var seg: int = [14, 9, 6][lod]
	# frame: a steel spine and cradle, the engine block, the tank, the seat, the tail
	var fr := Color(0.1, 0.1, 0.11, 0.85)
	NewModels4._cyl(Pt, "steel", Vector3(0, 0.88, -0.42), Vector3(0, 0.78, 0.28), 0.03, 0.03, 6, fr)
	NewModels4._cyl(Pt, "steel", Vector3(0, 0.7, -0.42), Vector3(0, 0.35, -0.2), 0.025, 0.025, 6, fr)
	NewModels4._cyl(Pt, "steel", Vector3(0, 0.36, -0.2), Vector3(0, 0.38, 0.4), 0.025, 0.025, 6, fr)
	NewModels4._cyl(Pt, "steel", Vector3(0, 0.78, 0.28), Vector3(0, 0.42, 0.45), 0.028, 0.028, 6, fr)
	NewModels4._rbx(Pt, "metal", Vector3(0, 0.5, -0.02), Vector3(0.28, 0.34, 0.5), Color(0.18, 0.18, 0.19, 0.55), Basis.IDENTITY, 10)                 # engine
	if lod < 2:
		NewModels4._cyl(Pt, "metal", Vector3(0, 0.62, -0.28), Vector3(0, 0.62, -0.12), 0.1, 0.1, 10, Color(0.55, 0.55, 0.57, 0.6))              # cylinder head
		NewModels4._rbx(Pt, "metal", Vector3(0.14, 0.38, 0.1), Vector3(0.04, 0.2, 0.25), Color(0.45, 0.45, 0.47, 0.55), Basis.IDENTITY, 8)     # clutch cover
	NewModels4._put(Pt, "paint", DroneParts.loft([[-0.5, 0.0, 0.98, 0.06, 0.08], [-0.36, 0.0, 0.99, 0.15, 0.13], [-0.1, 0.0, 0.99, 0.17, 0.15], [0.2, 0.0, 0.96, 0.15, 0.11], [0.32, 0.0, 0.94, 0.09, 0.07]], 2.6, [18, 12, 8][lod], true), NewModels4.I, pc)   # tank
	NewModels4._rbx(Pt, "trim", Vector3(0, 0.9, 0.5), Vector3(0.22, 0.09, 0.62), Color(0.05, 0.05, 0.055, 0.9), Basis(Vector3(1, 0, 0), 0.06), 10)  # seat
	NewModels4._put(Pt, "paint", DroneParts.loft([[0.7, 0.0, 0.93, 0.06, 0.04], [0.95, 0.0, 0.97, 0.09, 0.06], [1.05, 0.0, 0.99, 0.08, 0.05]], 2.6, [14, 10, 6][lod], true), NewModels4.I, pc)    # tail
	# the swingarm and the rear shock, the chain and sprocket
	for sx: float in [-1.0, 1.0]:
		NewModels4._bm(Pt, "steel", Vector3(sx * 0.09, 0.38, 0.4), Vector3(sx * 0.09, R, zr), 0.04, 0.04, fr)
	if lod < 2:
		NewModels4._cyl(Pt, "metal", Vector3(0.07, 0.8, 0.48), Vector3(0.1, 0.42, 0.62), 0.022, 0.022, 6, Color(0.7, 0.7, 0.72, 0.6))
		NewModels4._cyl(Pt, "steel", Vector3(0.07, 0.8, 0.48), Vector3(0.1, 0.62, 0.55), 0.03, 0.03, 8, Color(0.75, 0.55, 0.1, 0.7))
		NewModels4._cyl(Pt, "steel", Vector3(0.13, 0.36, 0.3), Vector3(0.13, 0.31, 0.68), 0.01, 0.01, 4, Color(0.1, 0.1, 0.1, 0.6))
	# the front fork, the triple clamp, the bars, the lamp, the clocks, mirrors
	NewModels4._cyl(Pt, "metal", Vector3(0.1, 1.05, -0.5), Vector3(0.09, R, zf), 0.025, 0.02, 8, Color(0.75, 0.77, 0.79, 0.85))
	NewModels4._cyl(Pt, "metal", Vector3(-0.1, 1.05, -0.5), Vector3(-0.09, R, zf), 0.025, 0.02, 8, Color(0.75, 0.77, 0.79, 0.85))
	NewModels4._bx(Pt, "steel", Vector3(0, 1.04, -0.5), Vector3(0.26, 0.04, 0.06), fr)
	NewModels4._cyl(Pt, "steel", Vector3(-0.4, 1.13, -0.4), Vector3(0.4, 1.13, -0.4), 0.014, 0.014, 6, fr)
	NewModels4._rbx(Pt, "trim", Vector3(0, 0.98, -0.66), Vector3(0.22, 0.2, 0.18), dark, Basis.IDENTITY, 10)
	NewModels4._disc(Pt, "lens", Vector3(0, 0.98, -0.755), Vector3(0, 0, -1), 0.085, 12, NewModels4.C_LENS)
	if lod < 2:
		NewModels4._bx(Pt, "paint", Vector3(0, 0.67, zf), Vector3(0.14, 0.03, 0.45), pc, Basis(Vector3(1, 0, 0), 0.0))
	if lod < 2:
		NewModels4._cyl(Pt, "lens", Vector3(0.0, 0.92, 1.07), Vector3(0.0, 0.92, 1.08), 0.05, 0.05, 8, NewModels4.C_RED)
	if lod < 2:
		for sx: float in [-1.0, 1.0]:
			NewModels4._bm(Pt, "trim", Vector3(sx * 0.4, 1.13, -0.4), Vector3(sx * 0.43, 1.25, -0.43), 0.012, 0.012, dark)
			NewModels4._rbx(Pt, "trim", Vector3(sx * 0.43, 1.28, -0.45), Vector3(0.1, 0.07, 0.03), dark, Basis.IDENTITY, 8)
			NewModels4._cyl(Pt, "trim", Vector3(sx * 0.4, 1.13, -0.4), Vector3(sx * 0.5, 1.13, -0.4), 0.017, 0.017, 6, dark)
	# the exhaust: a header pipe curling under the engine into a silencer
	NewModels4._cyl(Pt, "metal", Vector3(-0.12, 0.62, -0.28), Vector3(-0.14, 0.28, -0.2), 0.022, 0.022, 6, Color(0.5, 0.5, 0.52, 0.6))
	NewModels4._cyl(Pt, "metal", Vector3(-0.14, 0.28, -0.2), Vector3(-0.17, 0.3, 0.5), 0.022, 0.022, 6, Color(0.5, 0.5, 0.52, 0.6))
	NewModels4._cyl(Pt, "metal", Vector3(-0.17, 0.3, 0.2), Vector3(-0.19, 0.42, 1.0), 0.05, 0.045, [10, 8, 6][lod], Color(0.75, 0.77, 0.79, 0.7))
	if lod < 2:
		NewModels4._rbx(Pt, "paint", Vector3(0, R * 2.0 + 0.03, zr - 0.02), Vector3(0.14, 0.03, 0.55), pc, Basis(Vector3(1, 0, 0), 0.0), 8)
	if lod < 2:
		NewModels4._rbx(Pt, "paint", Vector3(0, R * 2.0 + 0.04, zf - 0.02), Vector3(0.15, 0.03, 0.5), pc, Basis(Vector3(1, 0, 0), 0.0), 8)
	var wheels: Array = []
	wheels.append(_wheel_entry("wheel_f", Vector3(0.0, R, zf), R, tw, "moto", lod, Color(0.6, 0.6, 0.62), true))
	wheels.append(_wheel_entry("wheel_r", Vector3(0.0, R, zr), R, tw + 0.05, "moto", lod, Color(0.6, 0.6, 0.62), false))
	var col := [AABB(Vector3(-0.2, 0.0, -0.9), Vector3(0.4, 1.2, 2.1))]
	return _pack(Pt, wheels, Vector3(0.8, 1.35, 2.1), R, 0.0, zr - zf, col)

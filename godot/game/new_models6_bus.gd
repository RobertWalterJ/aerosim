class_name NewModels6Bus
extends RefCounted
## Story batch (models8), the festival bus and its parts. A 1960s to 1970s single-decker service bus about 9 m long: green lower
## body, cream upper rail and roof, a hollow body with a floor, seats, a driver's cab and glazed windows you can see through.
## Frame (the story brief's): metres, +Z forward, origin on the ground at the middle. The vehicle's right-hand side (the door
## side, as in Ontario) is -x, the driver's side +x.
## Separate named nodes: wheel_fl, wheel_fr, wheel_rl, wheel_rr (spin about x at the axle), door (hinge pivot at the front
## right post), destination_board, headlamp_glass, interior_light (emissive; the "lamp" material).

const NAMES: Array[String] = [
	"festival_bus_restored", "festival_bus_restored_open", "festival_bus_garage", "festival_bus_destination_a", "festival_bus_plate_a",
	"festival_bus_seats_a", "garage_bus_seats_a",
]

const GREEN := Color(0.105, 0.27, 0.19)
const CREAM := Color(0.80, 0.75, 0.58)
const PRIMER := Color(0.46, 0.21, 0.16)
const CHROME := Color(0.78, 0.8, 0.82)
const MOQUETTE := Color(0.50, 0.20, 0.16)
const HALF_W := 1.2
const Z_BACK := -4.5
const Z_FRONT := 4.5
const AXLE_F := 3.0
const AXLE_R := -2.7
const TRACK := 1.02

static func build(name: String, md: NewModels6.Model, lod: int) -> bool:
	match name:
		"festival_bus_restored": _bus(md, 0, false, lod)
		"festival_bus_restored_open": _bus(md, 0, true, lod)
		"festival_bus_garage": _bus(md, 1, false, lod)
		"festival_bus_destination_a": _board(md)
		"festival_bus_plate_a": _plate(md)
		"festival_bus_seats_a": _loose_seats(md, 3, false)
		"garage_bus_seats_a": _loose_seats(md, 6, true)
		_: return false
	return true

# ================================================================== the bus
static func _dust(c: Color, state: int, amt: float) -> Color:
	if state == 0: return c
	var g := Color(0.62, 0.58, 0.50)
	return c.lerp(g, amt)

static func _bus(md: NewModels6.Model, state: int, open: bool, lod: int) -> void:
	var seg: int = NewModels6.LOD_SEG[lod]
	var green := _dust(GREEN, state, 0.36)
	var cream := _dust(CREAM, state, 0.30)
	var vary := 0.035 if state == 0 else 0.07
	var rail_top := 2.78
	var floor_y := 0.55
	# ---- the underside: chassis, axles, fuel tank, exhaust
	NewModels6.box(md, "rust", Vector3(0, 0.36, 0.1), Vector3(1.55, 0.2, 8.4), Color(0.10, 0.09, 0.08))
	for ax: float in [AXLE_F, AXLE_R]:
		NewModels6.limb(md, "rust", Vector3(-TRACK, 0.5, ax), Vector3(TRACK, 0.5, ax), 0.06, 0.06, Color(0.13, 0.12, 0.11), 8)
	NewModels6.limb(md, "rust", Vector3(0.7, 0.34, -1.2), Vector3(0.7, 0.34, 0.9), 0.17, 0.17, Color(0.18, 0.17, 0.15), 10)
	NewModels6.limb(md, "rust", Vector3(-0.5, 0.3, -4.7), Vector3(-0.5, 0.3, -1.5), 0.045, 0.045, Color(0.24, 0.17, 0.12), 8)
	# ---- the floor and the dark wheel wells
	NewModels6.box(md, "paint", Vector3(0, floor_y, 0.0), Vector3(2.3, 0.07, 8.9), Color(0.17, 0.14, 0.11))
	for ax: float in [AXLE_F, AXLE_R]:
		for sx: float in [-1.0, 1.0]:
			NewModels6.box(md, "rubber", Vector3(sx * 0.80, 0.78, ax), Vector3(0.06, 0.62, 1.4), Color(0.05, 0.05, 0.05))
	# ---- side skirts with wheel arches cut in them
	for sx: float in [-1.0, 1.0]:
		var poly := PackedVector2Array()
		var y0 := 0.36; var y1 := 1.38
		poly.append(Vector2(Z_BACK + 0.12, y0))
		for ax: float in [AXLE_R, AXLE_F]:
			var r := 0.66
			poly.append(Vector2(ax - r, y0))
			for k in range(0, 13):
				var a := PI * float(k) / 12.0
				poly.append(Vector2(ax - r * cos(a), y0 + 0.14 + r * sin(a) * 0.95))
			poly.append(Vector2(ax + r, y0))
		poly.append(Vector2(Z_FRONT - 0.12, y0))
		poly.append(Vector2(Z_FRONT - 0.04, y1))
		poly.append(Vector2(Z_BACK + 0.04, y1))
		# a front-nearside doorway is cut in the right side (-x): the skirt just stops short of it and the steps show
		NewModels6.slab_zy(md, "gloss", poly, sx * HALF_W, 0.05, sx, green, vary)
	# the primed panel on the garage bus (a repaired patch, sanded back)
	if state == 1:
		for sx: float in [-1.0, 1.0]:
			var pz := 0.2 if sx > 0.0 else -1.2
			NewModels6.quad2(md, "rust", Vector3(sx * (HALF_W + 0.004), 0.5, pz), Vector3(sx * (HALF_W + 0.004), 0.5, pz + 1.55),
				Vector3(sx * (HALF_W + 0.004), 1.34, pz + 1.55), Vector3(sx * (HALF_W + 0.004), 1.34, pz), PRIMER, false)
	# ---- waist trim, window pillars, upper rail
	for sx: float in [-1.0, 1.0]:
		NewModels6.slab_zy(md, "gloss", PackedVector2Array([Vector2(Z_BACK + 0.04, 1.38), Vector2(Z_FRONT - 0.04, 1.38), Vector2(Z_FRONT - 0.04, 1.47),
			Vector2(Z_BACK + 0.04, 1.47)]), sx * (HALF_W + 0.012), 0.05, sx, cream, vary)
		NewModels6.slab_zy(md, "gloss", PackedVector2Array([Vector2(Z_BACK + 0.04, 2.46), Vector2(Z_FRONT - 0.04, 2.46), Vector2(Z_FRONT - 0.1, rail_top),
			Vector2(Z_BACK + 0.1, rail_top)]), sx * HALF_W, 0.05, sx, cream, vary)
	var bay_edges: Array[float] = []
	for k in 9: bay_edges.append(-4.2 + 0.925 * k)         # eight bays from the back to the door
	for sx: float in [-1.0, 1.0]:
		for ze in bay_edges:
			NewModels6.box(md, "gloss", Vector3(sx * HALF_W, 1.965, ze), Vector3(0.05, 1.0, 0.08), green)
		# the glass, a little in from the pillars, with a rubber seal round each pane
		for k in 8:
			var za := bay_edges[k] + 0.04; var zb := bay_edges[k + 1] - 0.04
			NewModels6.quad2(md, "glass", Vector3(sx * (HALF_W - 0.015), 1.49, za), Vector3(sx * (HALF_W - 0.015), 1.49, zb),
				Vector3(sx * (HALF_W - 0.015), 2.44, zb), Vector3(sx * (HALF_W - 0.015), 2.44, za), Color.WHITE, true)
			NewModels6.box(md, "rubber", Vector3(sx * (HALF_W - 0.005), 1.47, (za + zb) * 0.5), Vector3(0.04, 0.03, zb - za), Color(0.04, 0.04, 0.04))
			NewModels6.box(md, "rubber", Vector3(sx * (HALF_W - 0.005), 2.45, (za + zb) * 0.5), Vector3(0.04, 0.03, zb - za), Color(0.04, 0.04, 0.04))
	# the driver's side window beside the cab (the right-hand side is the doorway there)
	NewModels6.quad2(md, "glass", Vector3(HALF_W - 0.015, 1.49, 3.3), Vector3(HALF_W - 0.015, 1.49, 4.2), Vector3(HALF_W - 0.015, 2.44, 4.2), Vector3(HALF_W - 0.015, 2.44, 3.3), Color.WHITE, true)
	NewModels6.box(md, "gloss", Vector3(HALF_W, 1.965, 4.25), Vector3(0.05, 1.0, 0.08), green)
	NewModels6.box(md, "gloss", Vector3(HALF_W, 1.965, 3.25), Vector3(0.05, 1.0, 0.08), green)
	NewModels6.box(md, "gloss", Vector3(-HALF_W, 1.965, 4.25), Vector3(0.05, 1.0, 0.08), green)
	# ---- front and back: lower panels, glazing, corner posts
	for zs: float in [-1.0, 1.0]:
		var zf := Z_FRONT if zs > 0.0 else Z_BACK
		NewModels6.box(md, "gloss", Vector3(0, 0.88, zf), Vector3(2.4, 1.02, 0.07), green, 0.0, Color(-1, 0, 0))
		NewModels6.box(md, "gloss", Vector3(0, 1.42, zf), Vector3(2.4, 0.09, 0.07), cream)
		NewModels6.box(md, "gloss", Vector3(0, 2.62, zf), Vector3(2.4, 0.32, 0.07), cream)
		for sx: float in [-1.0, 1.0]:
			NewModels6.cyl(md, "gloss", Vector3(sx * (HALF_W - 0.06), 0.4, zf - zs * 0.02), Vector3(sx * (HALF_W - 0.06), rail_top, zf - zs * 0.02), 0.08, 0.08, 8, green, 3, 0.02)
	# the windscreen (leaning back a little) in two panes with a centre pillar, and the rear window
	NewModels6.quad2(md, "glass", Vector3(-1.1, 1.5, Z_FRONT - 0.01), Vector3(-0.03, 1.5, Z_FRONT - 0.01), Vector3(-0.03, 2.46, Z_FRONT - 0.07), Vector3(-1.1, 2.46, Z_FRONT - 0.07), Color.WHITE, true)
	NewModels6.quad2(md, "glass", Vector3(0.03, 1.5, Z_FRONT - 0.01), Vector3(1.1, 1.5, Z_FRONT - 0.01), Vector3(1.1, 2.46, Z_FRONT - 0.07), Vector3(0.03, 2.46, Z_FRONT - 0.07), Color.WHITE, true)
	NewModels6.box(md, "gloss", Vector3(0, 1.98, Z_FRONT - 0.03), Vector3(0.07, 1.0, 0.07), green)
	NewModels6.quad2(md, "glass", Vector3(-0.8, 1.58, Z_BACK + 0.02), Vector3(0.8, 1.58, Z_BACK + 0.02), Vector3(0.8, 2.42, Z_BACK + 0.02), Vector3(-0.8, 2.42, Z_BACK + 0.02), Color.WHITE, true)
	# ---- bumpers, grille, lamps, mirrors, number plate
	for zs: float in [-1.0, 1.0]:
		var zf2 := Z_FRONT + 0.08 if zs > 0.0 else Z_BACK - 0.08
		NewModels6.box(md, "chrome", Vector3(0, 0.50, zf2), Vector3(2.5, 0.13, 0.11), CHROME)
		for sx: float in [-1.0, 1.0]:
			NewModels6.box(md, "chrome", Vector3(sx * 1.18, 0.50, zf2 - zs * 0.2), Vector3(0.1, 0.13, 0.4), CHROME)
	for k in 6:
		NewModels6.box(md, "chrome", Vector3(0, 0.74 + k * 0.045, Z_FRONT + 0.045), Vector3(0.74, 0.016, 0.02), CHROME)
	NewModels6.box(md, "rubber", Vector3(0, 0.85, Z_FRONT + 0.038), Vector3(0.8, 0.30, 0.012), Color(0.03, 0.03, 0.03))
	for sx: float in [-1.0, 1.0]:
		NewModels6.cyl(md, "chrome", Vector3(sx * 0.82, 1.0, Z_FRONT + 0.03), Vector3(sx * 0.82, 1.0, Z_FRONT + 0.1), 0.15, 0.14, seg, CHROME, 3, 0.0)
		NewModels6.box(md, "paint", Vector3(sx * 1.0, 0.95, Z_BACK - 0.04), Vector3(0.12, 0.3, 0.05), Color(0.55, 0.05, 0.04))
		# mirrors on arms
		NewModels6.limb(md, "chrome", Vector3(sx * 1.2, 2.3, Z_FRONT - 0.2), Vector3(sx * 1.45, 2.05, Z_FRONT + 0.1), 0.014, 0.014, CHROME, 6)
		NewModels6.box(md, "chrome", Vector3(sx * 1.45, 1.95, Z_FRONT + 0.1), Vector3(0.05, 0.3, 0.18), Color(0.55, 0.57, 0.6))
	var hl := md.sub("headlamp_glass", Vector3(0, 1.0, Z_FRONT))
	for sx: float in [-1.0, 1.0]:
		NewModels6.cyl(hl, "lamp" if state == 0 else "lamp_off", Vector3(sx * 0.82, 1.0, Z_FRONT + 0.1), Vector3(sx * 0.82, 1.0, Z_FRONT + 0.125), 0.12, 0.11, seg, Color.WHITE, 3, 0.0)
	# ---- the roof: a soft crown with the ends rolled down
	var rows: Array = []
	var nz := 14 if lod == 0 else (9 if lod == 1 else 5)
	var nx := 11 if lod == 0 else (7 if lod == 1 else 5)
	for i in nz + 1:
		var z := lerpf(Z_BACK, Z_FRONT, float(i) / nz)
		var r := PackedVector3Array(); r.resize(nx + 1)
		for j in nx + 1:
			var x := lerpf(-HALF_W, HALF_W, float(j) / nx)
			var cr := 0.32 * (1.0 - pow(absf(x) / HALF_W, 2.4))
			var endz := maxf(absf(z) - 3.75, 0.0) / 0.75
			var y := rail_top + cr * (1.0 - 0.55 * endz * endz) - 0.16 * endz * endz
			var zz := z + signf(z) * 0.0
			r[j] = Vector3(x, y, zz)
		rows.append(r)
	var up_hint := func(_i: int, _j: int, _p: Vector3) -> Vector3: return Vector3.UP
	NewModels6.gridsurf(md, "gloss", rows, cream, up_hint, vary)
	# a rain gutter along each eave and the roof's two ribs
	for sx: float in [-1.0, 1.0]:
		NewModels6.limb(md, "gloss", Vector3(sx * (HALF_W + 0.02), rail_top, Z_BACK + 0.15), Vector3(sx * (HALF_W + 0.02), rail_top, Z_FRONT - 0.15), 0.025, 0.025, Color(0.9, 0.88, 0.8) * (1.0 if state == 0 else 0.7), 6)
	# the roof vent, and the garage bus's tarp
	NewModels6.box(md, "gloss", Vector3(0, 3.1, -1.0), Vector3(0.55, 0.12, 0.9), green)
	if state == 1:
		_tarp(md, lod)
	elif state == 0 and lod < 2:
		_rack(md, lod)
	# ---- the ceiling and lamps
	NewModels6.box(md, "paint", Vector3(0, 2.72, 0.0), Vector3(2.3, 0.025, 8.85), Color(0.84, 0.82, 0.74) * (1.0 if state == 0 else 0.75))
	var il := md.sub("interior_light", Vector3(0, 2.68, 0))
	for sx: float in [-1.0, 1.0]:
		for z: float in [-3.2, -1.2, 0.8, 2.6]:
			NewModels6.box(il, "lamp" if state == 0 else "lamp_off", Vector3(sx * 0.62, 2.69, z), Vector3(0.14, 0.02, 0.55), Color.WHITE)
	# ---- inside: seats, the driver's cab, the door steps, stanchions
	if lod < 2: _cab(md, state, lod)
	if lod >= 2:
		pass
	elif state == 0:
		for k in 7:
			var z := -3.7 + k * 0.78
			for sx: float in [-1.0, 1.0]:
				_seat_pair(md, Vector3(sx * 0.72, floor_y + 0.035, z), sx, 1.0)
	else:
		for k in 7:
			if k in [1, 2, 5]: continue          # the seats are out of the garage bus, as the story says
			var z := -3.7 + k * 0.78
			_seat_pair(md, Vector3(0.72, floor_y + 0.035, z), 1.0, 0.7)
	# steps at the door
	NewModels6.box(md, "rubber", Vector3(-0.92, 0.40, 3.75), Vector3(0.5, 0.05, 0.8), Color(0.07, 0.07, 0.07))
	NewModels6.box(md, "rubber", Vector3(-0.95, 0.20, 3.75), Vector3(0.42, 0.05, 0.7), Color(0.07, 0.07, 0.07))
	NewModels6.limb(md, "chrome", Vector3(-0.55, floor_y, 3.3), Vector3(-0.55, 2.6, 3.3), 0.02, 0.02, CHROME, 8)
	# ---- lettering (the restored bus only): the festival name along both sides under the windows, a small maker plate behind
	if state == 0 and lod < 2:
		var lc := Color(0.88, 0.84, 0.68)
		for sx: float in [-1.0, 1.0]:
			NewModels6.text(md, "gloss", "HALLOWAY FESTIVAL", Vector3(sx * (HALF_W + 0.06), 0.72, 0.15), Vector3(sx, 0, 0), 0.28, lc)
		NewModels6.text(md, "gloss", "VOSS & SON", Vector3(0, 0.62, Z_BACK - 0.04), Vector3(0, 0, -1), 0.12, lc)
	# ---- the destination board, a node of its own
	var bd := md.sub("destination_board", Vector3(0, 2.62, Z_FRONT))
	NewModels6.box(bd, "paint", Vector3(0, 2.62, Z_FRONT + 0.045), Vector3(1.5, 0.27, 0.025), Color(0.02, 0.02, 0.02))
	if state == 0 and lod == 0:
		NewModels6.text(bd, "lamp", "HALLOWAY FESTIVAL", Vector3(0, 2.52, Z_FRONT + 0.06), Vector3(0, 0, 1), 0.15, Color.WHITE)
	# ---- wheels (separate nodes) and the door
	var names := {"wheel_fl": [1.0, AXLE_F], "wheel_fr": [-1.0, AXLE_F], "wheel_rl": [1.0, AXLE_R], "wheel_rr": [-1.0, AXLE_R]}
	for wn in names:
		var sxw: float = names[wn][0]
		var azw: float = names[wn][1]
		var wsub := md.sub(wn, Vector3(sxw * TRACK, 0.5, azw))
		_wheel(wsub, Vector3(sxw * TRACK, 0.5, azw), sxw, seg, state, lod)
	_door(md, open, state, lod)
	# ---- hulls for the drone to hit: the body, and a lower block for the wheels
	NewModels6.hull(md, Vector3(0, 1.75, 0), Vector3(2.5, 2.7, 9.2))
	NewModels6.hull(md, Vector3(0, 0.45, 0), Vector3(2.4, 0.9, 9.0))

static func _tarp(md: NewModels6.Model, lod: int) -> void:
	var rows: Array = []
	var nz := 7 if lod == 0 else 4
	var nx := 12 if lod == 0 else 6
	for i in nz + 1:
		var z := lerpf(-4.35, 0.3, float(i) / nz)
		var r := PackedVector3Array(); r.resize(nx + 1)
		for j in nx + 1:
			var t := float(j) / nx
			var x := lerpf(-1.55, 1.55, t)
			var ax := absf(x)
			var y := 2.78 + 0.32 * (1.0 - pow(minf(ax, HALF_W) / HALF_W, 2.4)) + 0.04 + 0.03 * sin(z * 7.0 + x * 5.0)
			if ax > HALF_W: y = lerpf(y, 2.45, minf((ax - HALF_W) / 0.35, 1.0))
			# the free end of the tarp tails off over the middle roof
			if i == nz: y -= 0.02
			r[j] = Vector3(x, y, z)
		rows.append(r)
	var hint := func(_i: int, _j: int, _p: Vector3) -> Vector3: return Vector3.UP
	NewModels6.gridsurf(md, "tarp", rows, Color(0.20, 0.32, 0.44), hint, 0.12)
	# the lashing: a rope over the roof every couple of metres
	for z: float in [-3.6, -2.2, -0.9]:
		NewModels6.limb(md, "rubber", Vector3(-1.45, 2.5, z), Vector3(-1.2, 3.12, z), 0.012, 0.012, Color(0.5, 0.42, 0.28), 5)
		NewModels6.limb(md, "rubber", Vector3(1.2, 3.12, z), Vector3(1.45, 2.5, z), 0.012, 0.012, Color(0.5, 0.42, 0.28), 5)

static func _rack(md: NewModels6.Model, lod: int) -> void:
	var y := 3.2
	for sx: float in [-0.78, 0.78]:
		NewModels6.limb(md, "chrome", Vector3(sx, y + 0.22, -3.2), Vector3(sx, y + 0.22, 1.6), 0.016, 0.016, CHROME, 6)
		for k in range(0, 6):
			var z := lerpf(-3.2, 1.6, float(k) / 5.0)
			NewModels6.limb(md, "chrome", Vector3(sx, y - 0.02, z), Vector3(sx, y + 0.22, z), 0.012, 0.012, CHROME, 5)
	for k in range(0, 7):
		var z2 := lerpf(-3.2, 1.6, float(k) / 6.0)
		NewModels6.limb(md, "chrome", Vector3(-0.78, y + 0.22, z2), Vector3(0.78, y + 0.22, z2), 0.01, 0.01, CHROME, 5)
	# a pair of timber crates tied to the rack, as a festival bus would carry
	NewModels6.box(md, "wood", Vector3(-0.2, y + 0.42, -2.2), Vector3(0.7, 0.36, 0.55), Color(0.46, 0.38, 0.27), 0.1)
	NewModels6.box(md, "wood", Vector3(0.35, y + 0.40, -0.5), Vector3(0.6, 0.32, 0.5), Color(0.40, 0.33, 0.22), -0.12)

static func _seat_pair(md: NewModels6.Model, base: Vector3, sx: float, wear: float) -> void:
	# two seats side by side, each: a frame, a cushion, a high back with a chrome grab rail
	for k in 2:
		var x := base.x + (k - 0.5) * 0.42 * 1.0 * sx * -1.0 * -1.0
		x = base.x + (float(k) - 0.5) * 0.44
		var cc := MOQUETTE.lerp(Color(0.32, 0.30, 0.24), 1.0 - wear)
		NewModels6.box(md, "paint", Vector3(x, base.y + 0.38, base.z), Vector3(0.4, 0.08, 0.42), cc)
		NewModels6.box(md, "paint", Vector3(x, base.y + 0.72, base.z - 0.17), Vector3(0.4, 0.55, 0.08), cc * 0.92, 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, 0.14))
		NewModels6.box(md, "rust", Vector3(x, base.y + 0.18, base.z), Vector3(0.36, 0.34, 0.36), Color(0.14, 0.13, 0.12))
	NewModels6.limb(md, "chrome", Vector3(base.x - 0.42, base.y + 1.0, base.z - 0.2), Vector3(base.x + 0.42, base.y + 1.0, base.z - 0.2), 0.012, 0.012, CHROME, 5)

static func _cab(md: NewModels6.Model, state: int, lod: int) -> void:
	var dz := 3.55
	# dashboard, steering wheel, driver's seat, the engine cover beside him
	NewModels6.box(md, "paint", Vector3(0.0, 1.12, 4.28), Vector3(2.2, 0.28, 0.35), Color(0.08, 0.08, 0.08))
	NewModels6.box(md, "paint", Vector3(0.6, 0.85, dz), Vector3(0.5, 0.06, 0.5), Color(0.16, 0.13, 0.10))
	NewModels6.box(md, "paint", Vector3(0.6, 1.2, dz - 0.22), Vector3(0.5, 0.65, 0.08), Color(0.16, 0.13, 0.10))
	# the wheel: a ring of short bars, tilted towards the driver
	var c := Vector3(0.6, 1.18, 4.0)
	var n := 12 if lod == 0 else 8
	for k in n:
		var a0 := TAU * k / n; var a1 := TAU * (k + 1) / n
		var p0 := c + Vector3(cos(a0) * 0.2, sin(a0) * 0.2 * 0.8, sin(a0) * 0.2 * 0.6)
		var p1 := c + Vector3(cos(a1) * 0.2, sin(a1) * 0.2 * 0.8, sin(a1) * 0.2 * 0.6)
		NewModels6.limb(md, "rubber", p0, p1, 0.016, 0.016, Color(0.08, 0.08, 0.08), 5)
	NewModels6.limb(md, "chrome", c, c + Vector3(0, -0.3, -0.4), 0.02, 0.02, Color(0.15, 0.15, 0.16), 6)

static func _door(md: NewModels6.Model, open: bool, state: int, lod: int) -> void:
	# a two-leaf folding door in the right-hand doorway, hinged at the front post. Built with the hinge at the origin, shut,
	# then swung 105 degrees about the hinge when open.
	var hinge := Vector3(-HALF_W, 0.0, Z_FRONT - 0.3)
	var sub := md.sub("door", hinge)
	var leaf := NewModels6.Model.new()
	var green := _dust(GREEN, state, 0.36)
	# frame and glass in local space (door width 0.95 along -z from the hinge)
	NewModels6.box(leaf, "gloss", Vector3(0, 1.45, -0.475), Vector3(0.05, 2.1, 0.95), green)
	NewModels6.box(leaf, "gloss", Vector3(0, 0.46, -0.475), Vector3(0.05, 0.12, 0.95), green)
	for z: float in [0.03, -0.475, -0.92]:
		NewModels6.box(leaf, "gloss", Vector3(0, 1.45, z), Vector3(0.06, 2.1, 0.06), green)
	for k in 2:
		var za := -0.07 - k * 0.45; var zb := za - 0.4
		NewModels6.quad2(leaf, "glass", Vector3(0, 0.62, za), Vector3(0, 0.62, zb), Vector3(0, 2.45, zb), Vector3(0, 2.45, za), Color.WHITE, true)
	NewModels6.box(leaf, "chrome", Vector3(-0.03, 1.05, -0.9), Vector3(0.02, 0.12, 0.02), CHROME)
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(105.0) if open else 0.0), hinge)
	for key in leaf.m:
		var buf: NewModels2.Buf = leaf.m[key]
		var dst := sub.b(key)
		for i in buf.pos.size():
			dst.pos.append(xf * buf.pos[i])
			dst.nrm.append((xf.basis * buf.nrm[i]).normalized())
			dst.cols.append(buf.cols[i])

static func _wheel(sub: NewModels6.Model, c: Vector3, sx: float, seg: int, state: int, lod: int) -> void:
	# tyre and wheel turned about the local y axis, then laid on its side with the outside facing out
	var rot := Basis.from_euler(Vector3(0, 0, -PI * 0.5 * sx))
	var prof := PackedVector2Array([Vector2(0.30, -0.115), Vector2(0.42, -0.13), Vector2(0.49, -0.12), Vector2(0.515, -0.095), Vector2(0.52, -0.06),
		Vector2(0.505, -0.045), Vector2(0.52, -0.03), Vector2(0.52, 0.03), Vector2(0.505, 0.045), Vector2(0.52, 0.06), Vector2(0.515, 0.095),
		Vector2(0.49, 0.12), Vector2(0.42, 0.13), Vector2(0.30, 0.115)])
	var tyre := Color(0.055, 0.055, 0.055) if state == 0 else Color(0.09, 0.085, 0.08)
	var xf := Transform3D(rot, c)
	NewModels6.put(sub, "rubber", DroneParts.lathe(prof, seg), xf, tyre, 0.08)
	# the steel wheel: a dished disc with a rim, painted cream, and a chrome hub cap
	var disc := PackedVector2Array([Vector2(0.0, 0.1), Vector2(0.20, 0.1), Vector2(0.30, 0.115), Vector2(0.31, 0.06), Vector2(0.20, 0.05), Vector2(0.0, 0.05)])
	var wc := CREAM if state == 0 else Color(0.55, 0.52, 0.44)
	NewModels6.put(sub, "gloss", DroneParts.lathe(disc, seg), xf, wc, 0.0)
	NewModels6.put(sub, "chrome", DroneParts.lathe(PackedVector2Array([Vector2(0.0, 0.14), Vector2(0.09, 0.135), Vector2(0.12, 0.11), Vector2(0.12, 0.1)]), seg), xf, CHROME if state == 0 else Color(0.5, 0.5, 0.5), 0.0)
	if lod == 0:
		for k in 8:
			var a := TAU * k / 8.0
			var p := c + rot * Vector3(cos(a) * 0.17, 0.115, sin(a) * 0.17)
			NewModels6.cyl(sub, "chrome", p, p + rot * Vector3(0, 0.03, 0), 0.016, 0.016, 5, CHROME, 3, 0.0)

# ================================================================== loose seats, board, plate
static func _loose_seats(md: NewModels6.Model, n: int, stacked: bool) -> void:
	for k in n:
		if stacked:
			var yb := 0.0 + k * 0.1
			var yaw := (NewModels6.rnd(k, 2.0) - 0.5) * 0.35
			_loose_seat(md, Vector3(0, 0.0, 0), k, yaw, yb)
		else:
			_loose_seat(md, Vector3(k * 0.95, 0.0, (NewModels6.rnd(k, 1.0) - 0.5) * 0.2), k, (NewModels6.rnd(k, 5.0) - 0.5) * 0.7, 0.0)
	NewModels6.hull(md, Vector3(0, 0.4, 0), Vector3(1.0 + (n if not stacked else 0) * 0.6, 0.8, 0.9))

static func _loose_seat(md: NewModels6.Model, o: Vector3, k: int, yaw: float, lift: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	var col := MOQUETTE.lerp(Color(0.30, 0.28, 0.22), 0.3 + 0.2 * NewModels6.rnd(k, 3.0))
	var tilt := Basis(Vector3.RIGHT, 0.16)
	NewModels6.box(md, "paint", o + b * Vector3(0, lift + 0.38, 0), Vector3(0.88, 0.1, 0.46), col, yaw)
	NewModels6.box(md, "paint", o + b * Vector3(0, lift + 0.78, -0.19), Vector3(0.88, 0.62, 0.1), col * 0.9, yaw, Color(-1, 0, 0), tilt)
	for sx: float in [-0.4, 0.4]:
		NewModels6.box(md, "rust", o + b * Vector3(sx, lift + 0.18, 0), Vector3(0.05, 0.34, 0.4), Color(0.14, 0.13, 0.12), yaw)
	NewModels6.limb(md, "chrome", o + b * Vector3(-0.44, lift + 1.1, -0.22), o + b * Vector3(0.44, lift + 1.1, -0.22), 0.012, 0.012, CHROME, 5)

static func _board(md: NewModels6.Model) -> void:
	NewModels6.box(md, "paint", Vector3(0, 0.14, 0), Vector3(1.0, 0.28, 0.05), Color(0.02, 0.02, 0.02))
	var lt := md.sub("lamp_glass", Vector3(0, 0.14, 0.03))
	NewModels6.text(lt, "lamp", "HALLOWAY FESTIVAL", Vector3(0, 0.07, 0.03), Vector3(0, 0, 1), 0.14, Color.WHITE)
	NewModels6.hull(md, Vector3(0, 0.14, 0), Vector3(1.0, 0.28, 0.06))

static func _plate(md: NewModels6.Model) -> void:
	NewModels6.box(md, "chrome", Vector3(0, 0.05, 0), Vector3(0.26, 0.1, 0.008), Color(0.72, 0.58, 0.28))
	NewModels6.text(md, "paint", "VOSS & SON", Vector3(0, 0.055, 0), Vector3(0, 0, 1), 0.026, Color(0.15, 0.1, 0.05), Vector3.UP, 0.005)
	NewModels6.text(md, "paint", "HALLOWAY", Vector3(0, 0.02, 0), Vector3(0, 0, 1), 0.02, Color(0.15, 0.1, 0.05), Vector3.UP, 0.005)

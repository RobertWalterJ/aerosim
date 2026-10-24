class_name NewModels7Cabin
extends RefCounted
## Story batch 9 (models9), part B1: the abandoned cabin of the ending and what stands around it. The cabin is an 8 x 6 m weatherboard
## hut, 4.2 m to the ridge, empty for forty years: hollow, so the interior set (NewModels7Interior) can be placed inside. Weatherboards
## are real geometry (a faded green paint over silver bare timber, photographed wood grain through the farm kit), the roof is
## corrugated steel with a broken variant, the chimney is fieldstone. Named parts: `door` (hinged), `windows` (glass), `window_light`
## (warm panes, hide by day). Colliders only on the cabin and the fallen tree, as the brief says. Metres, +Z front, origin at the
## middle of the footprint on the ground. The old cruiser and the other vehicles are not here.

const NAMES: Array[String] = [
	"cabin_abandoned_a", "cabin_abandoned_a_broken_roof", "cabin_door_a", "cabin_door_a_ajar", "cabin_door_a_open",
	"cabin_window_a", "cabin_window_a_lit", "cabin_window_a_cracked", "cabin_chimney_a", "cabin_porch_light_a", "cabin_porch_light_a_off",
	"cabin_woodpile_a", "cabin_lean_to_a",
	"cabin_fallen_tree_a", "cabin_tyre_ruts_a", "cabin_fence_broken_a", "cabin_old_sign_a", "cabin_yard_tools_a", "cabin_radio_aerial_a",
	"cabin_search_flag_a", "search_tape_a", "cabin_chimney_smoke_a",
]

const FLOOR_Y := 0.35
const EAVE_Y := 2.9
const RIDGE_Y := 4.2
const PAINT := Color(0.36, 0.45, 0.38)
const BARE := Color(0.47, 0.44, 0.39)
const TIMBER := Color(0.4, 0.31, 0.22)
const ROOF_C := Color(0.5, 0.45, 0.4)
const STONE_C := Color(0.5, 0.48, 0.44)

static func build(name: String, md: NewModels6.Model, lod: int) -> bool:
	match name:
		"cabin_abandoned_a": _cabin(md, false, lod)
		"cabin_abandoned_a_broken_roof": _cabin(md, true, lod)
		"cabin_door_a": _door_asset(md, 0.0)
		"cabin_door_a_ajar": _door_asset(md, 0.55)
		"cabin_door_a_open": _door_asset(md, 1.7)
		"cabin_window_a": _window_asset(md, false, false)
		"cabin_window_a_lit": _window_asset(md, true, false)
		"cabin_window_a_cracked": _window_asset(md, false, true)
		"cabin_chimney_a": _chimney(md, 0.0, 0.0)
		"cabin_porch_light_a": _porch_light(md, true)
		"cabin_porch_light_a_off": _porch_light(md, false)
		"cabin_woodpile_a": _woodpile(md)
		"cabin_lean_to_a": _lean_to(md)
		"cabin_fallen_tree_a": NewModels7.merge(md, NewModels6.build("storm_tree_fallen_a", 0), Transform3D(Basis(Vector3.UP, 0.3), Vector3.ZERO), true)
		"cabin_tyre_ruts_a": _ruts(md)
		"cabin_fence_broken_a": NewModels7.merge(md, NewModels6.build("storm_fence_broken_a", 0), Transform3D.IDENTITY, true)
		"cabin_old_sign_a": _old_sign(md)
		"cabin_yard_tools_a": _yard_tools(md)
		"cabin_radio_aerial_a": _aerial(md)
		"cabin_search_flag_a": _search_flag(md)
		"search_tape_a": _search_tape(md)
		"cabin_chimney_smoke_a": _smoke(md)
		_: return false
	return true

# ================================================================== weatherboard cladding
## Horizontal boards along the run from `a` to `b` (same height), rows from y0 to y1, facing `n`; `holes` are [u0, u1, y0, y1] rectangles (u measured
## from a along the run) left open; `gable` = [eave_y, ridge_y] makes the rows shrink toward the ridge (a triangular end).
static func _clad(md: NewModels6.Model, a: Vector3, b: Vector3, n: Vector3, y0: float, y1: float, step: float, holes: Array, key: String, thick: float, off: float, gable := [], salt := 0.0, bare_p := 0.3) -> void:
	var run := (b - a)
	var L := run.length()
	var dir := run / L
	var rows := int(ceil((y1 - y0) / step))
	for r in rows:
		var yc := y0 + (r + 0.5) * (y1 - y0) / rows
		var u_lo := 0.0
		var u_hi := L
		if gable.size() == 2 and yc > float(gable[0]):
			var f := 1.0 - (yc - float(gable[0])) / (float(gable[1]) - float(gable[0]))
			u_lo = L * 0.5 * (1.0 - f)
			u_hi = L * 0.5 * (1.0 + f)
			if u_hi - u_lo < 0.3: continue
		# the segments between the holes this row crosses
		var cuts: Array = [[u_lo, u_hi]]
		for h in holes:
			if yc + step * 0.5 > float(h[2]) and yc - step * 0.5 < float(h[3]):
				var nc: Array = []
				for c in cuts:
					if float(h[1]) <= float(c[0]) or float(h[0]) >= float(c[1]): nc.append(c)
					else:
						if float(h[0]) > float(c[0]): nc.append([c[0], h[0]])
						if float(h[1]) < float(c[1]): nc.append([h[1], c[1]])
				cuts = nc
		var si := 0
		for c in cuts:
			var u0: float = c[0]
			var u1: float = c[1]
			# a long board is cut into two or three lengths with butt joints (and a slightly different tone)
			var pieces := maxi(1, int((u1 - u0) / 2.6))
			for p in pieces:
				var pa := u0 + (u1 - u0) * p / pieces
				var pb := u0 + (u1 - u0) * (p + 1) / pieces - 0.004
				var rr := NewModels6.rnd(r * 13 + si * 5 + p, 101.0 + salt)
				var painted := rr > bare_p
				var col := (PAINT if painted else BARE) * (0.85 + 0.3 * NewModels6.rnd(r * 7 + p, 103.0 + salt))
				col.a = 1.0 if painted else (0.75 if key == "paintwood" else 0.75)
				if key == "paintwood" and not painted: col.a = 0.0
				if key != "paintwood": col = NewModels7.W(BARE * (0.85 + 0.3 * rr) * 0.9, 0.75)
				var base_p := a + dir * pa + n * off + Vector3(0, yc, 0)
				var end_p := a + dir * pb + n * off + Vector3(0, yc, 0)
				NewModels7.board(md, key, base_p, end_p, step * (0.99 if key != "paintwood" else 1.0), thick, col, n)
			si += 1

# ================================================================== the cabin
static func _cabin(md: NewModels6.Model, broken: bool, lod: int) -> void:
	var hx := 4.0
	var hz := 3.0
	var step := 0.14 if lod == 0 else (0.28 if lod == 1 else 0.7)
	var istep := 0.28 if lod == 0 else 0.7
	var fy := FLOOR_Y
	# piers, joists and the floorboards
	for sx in [-3.6, -1.2, 1.2, 3.6]:
		for sz in [-2.6, 0.0, 2.6]:
			NewModels6.rbox(md, "stone", Vector3(sx, fy * 0.5 - 0.02, sz), Vector3(0.4, fy - 0.02, 0.4), NewModels6.vc(STONE_C * 0.8, sx * 3 + sz, 0.1), Basis.IDENTITY, 4.0, 6, 0.1)
	for k in 7:
		NewModels7.board(md, "wood", Vector3(-hx, fy - 0.1, -hz + 0.2 + k * 0.93), Vector3(hx, fy - 0.1, -hz + 0.2 + k * 0.93), 0.1, 0.18, NewModels7.W(TIMBER * 0.7, 0.75))
	for k in 12:
		NewModels7.board(md, "wood", Vector3(-hx + 0.05, fy, -hz + 0.25 + k * 0.5), Vector3(hx - 0.05, fy, -hz + 0.25 + k * 0.5), 0.15, 0.03, NewModels7.W(BARE * (0.8 + 0.3 * NewModels6.rnd(k, 5.0)), 0.75))
	# the walls: outer weatherboard layer (paint over bare silver wood) and an inner layer of plain planking
	var door_u := 5.0
	var win_f := [[1.4, 2.6, 0.9 + fy, 2.1 + fy], [6.8, 8.0, 0.9 + fy, 2.1 + fy]]
	var front_holes := [[door_u - 0.5, door_u + 0.5, fy, fy + 2.05], win_f[0], win_f[1]]
	var back_holes := [[3.4, 4.6, fy + 0.9, fy + 2.1]]
	var walls := [
		[Vector3(-hx, 0, hz), Vector3(hx, 0, hz), Vector3(0, 0, 1), front_holes, []],
		[Vector3(hx, 0, -hz), Vector3(-hx, 0, -hz), Vector3(0, 0, -1), back_holes, []],
		[Vector3(hx, 0, hz), Vector3(hx, 0, -hz), Vector3(1, 0, 0), [], [EAVE_Y, RIDGE_Y]],
		[Vector3(-hx, 0, -hz), Vector3(-hx, 0, hz), Vector3(-1, 0, 0), [[2.5, 3.5, fy + 0.9, fy + 2.1]], [EAVE_Y, RIDGE_Y]],
	]
	var wi := 0
	for w in walls:
		var top := EAVE_Y if (w[4] as Array).is_empty() else RIDGE_Y
		_clad(md, w[0], w[1], w[2], fy, top, step, w[3], "paintwood", 0.022, 0.04, w[4], wi * 3.1, 0.3)
		_clad(md, w[0], w[1], w[2], fy, top, istep, w[3], "wood", 0.05, -0.025, w[4], wi * 5.7 + 1.0, 0.0)
		wi += 1
	# corner boards, a sill plate, the beam under the eaves
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			NewModels7.board(md, "wood", Vector3(sx * (hx + 0.045), fy, sz * (hz + 0.045)), Vector3(sx * (hx + 0.045), EAVE_Y, sz * (hz + 0.045)), 0.1, 0.1, NewModels7.W(BARE * 0.8, 1.0))
	# the roof: corrugated sheets on rafters
	var th := atan2(RIDGE_Y - EAVE_Y, hz + 0.35)
	var sl := sqrt(pow(hz + 0.35, 2.0) + pow(RIDGE_Y - EAVE_Y, 2.0))
	for k in 15:
		var x := -hx - 0.3 + k * (8.6 / 14.0)
		for sz: float in [-1.0, 1.0]:
			var bas := Basis(Vector3.RIGHT, th * sz)
			var mid := Vector3(x, (EAVE_Y + RIDGE_Y) * 0.5 - 0.06, sz * (hz + 0.35) * 0.5)
			NewModels7.board(md, "wood", mid - bas * Vector3(0, 0, sl * 0.5), mid + bas * Vector3(0, 0, sl * 0.5), 0.07, 0.14, NewModels7.W(TIMBER * 0.75, 0.5), bas * Vector3.UP)
	NewModels7.board(md, "wood", Vector3(-hx - 0.3, RIDGE_Y - 0.1, 0), Vector3(hx + 0.3, RIDGE_Y - 0.1, 0), 0.16, 0.12, NewModels7.W(TIMBER * 0.7, 0.75))
	var nsheet := 7
	var sw := 8.8 / nsheet
	var missing: Array = [] if not broken else [[1, 3], [1, 4], [-1, 5]]
	for k in nsheet:
		for sz: float in [-1.0, 1.0]:
			var gone := false
			for m in missing:
				if int(m[0]) == int(sz) and int(m[1]) == k: gone = true
			if gone: continue
			var bas2 := Basis(Vector3.RIGHT, th * sz)
			var cen := Vector3(-hx - 0.4 + (k + 0.5) * sw, (EAVE_Y + RIDGE_Y) * 0.5 + 0.0, sz * (hz + 0.35) * 0.5)
			var rust := 0.8 + 0.4 * NewModels6.rnd(k * 2 + (1 if sz > 0.0 else 0), 111.0)
			NewModels6.box(md, "roof", cen, Vector3(sw - 0.02, 0.04, sl + 0.1), ROOF_C * rust, 0.0, Color(-1, 0, 0), bas2)
	if broken:
		# a sheet torn off and leaning on the porch rail, and the sky-hole showing the rafters
		var lbas := Basis(Vector3.RIGHT, -1.1) * Basis(Vector3.UP, 0.1)
		NewModels6.box(md, "roof", Vector3(-1.5, 1.7, hz + 1.7), Vector3(sw - 0.02, 0.04, sl), ROOF_C * 0.8, 0.0, Color(-1, 0, 0), lbas)
	# the porch: a deck, four posts, a shed roof, a rotten step; the railing is partly gone
	var py := fy
	var pz := hz + 1.0
	for k in 10:
		NewModels7.board(md, "wood", Vector3(-hx, py - 0.02, hz + 0.15 + k * 0.19), Vector3(hx, py - 0.02, hz + 0.15 + k * 0.19), 0.17, 0.035, NewModels7.W(BARE * (0.75 + 0.35 * NewModels6.rnd(k, 33.0)), 0.75))
	for sx in [-3.8, -1.3, 1.3, 3.8]:
		NewModels7.board(md, "wood", Vector3(sx, py, hz + 1.85), Vector3(sx, EAVE_Y - 0.35, hz + 1.85), 0.12, 0.12, NewModels7.W(BARE * 0.8, 1.0))
	NewModels7.board(md, "wood", Vector3(-hx, EAVE_Y - 0.4, hz + 1.85), Vector3(hx, EAVE_Y - 0.4, hz + 1.85), 0.14, 0.14, NewModels7.W(BARE * 0.75, 0.75))
	var pth := atan2(0.45, 1.9)
	NewModels6.box(md, "roof", Vector3(0, EAVE_Y - 0.12, hz + 1.0), Vector3(8.8, 0.04, 2.1), ROOF_C * 0.9, 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, pth))
	for k in 5:
		NewModels6.box(md, "wood", Vector3(-3.8 + k * 0.95, py + 0.45, hz + 1.85), Vector3(0.05, 0.9, 0.05), NewModels7.W(BARE * 0.8, 1.0))
	NewModels7.board(md, "wood", Vector3(-3.8, py + 0.85, hz + 1.85), Vector3(0.0, py + 0.85, hz + 1.85), 0.1, 0.045, NewModels7.W(BARE * 0.8, 0.75))      # the rail stops where it fell
	for k in 2:
		NewModels6.box(md, "wood", Vector3(1.3 - 0.0, py - 0.17 - k * 0.17, hz + 2.1 + k * 0.28), Vector3(1.1, 0.04, 0.3), NewModels7.W(BARE * 0.8, 0.75), 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, 0.05 * (k + 1)))
	# windows and the door
	var glass := md.sub("windows", Vector3(0, fy + 1.5, hz))
	var lit := md.sub("window_light", Vector3(0, fy + 1.5, hz))
	for wcfg in [[-hx + 2.0, hz, 1.2, 1.2], [-hx + 7.4, hz, 1.2, 1.2]]:
		_window(md, glass, lit, Vector3(float(wcfg[0]), fy + 1.5, hz), float(wcfg[2]), float(wcfg[3]), false, Vector3(0, 0, 1))
	_window(md, glass, lit, Vector3(0.0, fy + 1.5, -hz), 1.2, 1.2, true, Vector3(0, 0, -1))
	_window(md, glass, lit, Vector3(-hx, fy + 1.5, 0.0), 1.0, 1.2, false, Vector3(-1, 0, 0))
	var hinge := Vector3(-hx + door_u - 0.45, fy, hz + 0.01)
	var dn := md.sub("door", hinge)
	_door(dn, hinge, 0.0)
	# the chimney on the right-hand gable, leaning cap above the ridge
	NewModels7.merge(md, _chimney_model(), Transform3D(Basis.IDENTITY, Vector3(hx + 0.55, 0.0, 0.0)), false)
	NewModels6.hull(md, Vector3(0, 2.2, 0), Vector3(8.4, 4.4, 6.4))
	NewModels6.hull(md, Vector3(0, 0.35, hz + 1.1), Vector3(8.4, 0.7, 2.2))

## A window in the wall facing `n` at the centre point c: 1.2 x 1.2 m two-over-two sash, weathered frame, dark glass (own node), warm panes in `lit`.
static func _window(md: NewModels6.Model, glass: NewModels6.Model, lit: NewModels6.Model, c: Vector3, w: float, h: float, cracked: bool, n: Vector3) -> void:
	var right := Vector3.UP.cross(n).normalized()
	var frame := NewModels7.W(BARE * 0.75, 0.75)
	var hw := w * 0.5
	var hh := h * 0.5
	for sy: float in [-1.0, 1.0]:
		NewModels7.board(md, "wood", c + right * -hw + Vector3(0, sy * hh, 0) + n * 0.05, c + right * hw + Vector3(0, sy * hh, 0) + n * 0.05, 0.07, 0.06, frame, n)
	for sx: float in [-1.0, 1.0]:
		NewModels7.board(md, "wood", c + right * (sx * hw) + Vector3(0, -hh, 0) + n * 0.05, c + right * (sx * hw) + Vector3(0, hh, 0) + n * 0.05, 0.07, 0.06, frame, n)
	NewModels7.board(md, "wood", c + right * -hw + n * 0.05, c + right * hw + n * 0.05, 0.04, 0.045, frame, n)
	NewModels7.board(md, "wood", c + Vector3(0, -hh, 0) + n * 0.05, c + Vector3(0, hh, 0) + n * 0.05, 0.04, 0.045, frame, n)
	NewModels7.board(md, "wood", c + right * (-hw - 0.05) + Vector3(0, -hh - 0.06, 0) + n * 0.09, c + right * (hw + 0.05) + Vector3(0, -hh - 0.06, 0) + n * 0.09, 0.1, 0.04, frame, Vector3.UP)   # the sill
	var q := [c - right * hw - Vector3(0, hh, 0), c + right * hw - Vector3(0, hh, 0), c + right * hw + Vector3(0, hh, 0), c - right * hw + Vector3(0, hh, 0)]
	NewModels6.quad2(glass, "glass", q[0], q[1], q[2], q[3], Color.WHITE, true)
	var warm := [c - right * (hw - 0.05) - Vector3(0, hh - 0.05, 0) - n * 0.02, c + right * (hw - 0.05) - Vector3(0, hh - 0.05, 0) - n * 0.02, c + right * (hw - 0.05) + Vector3(0, hh - 0.05, 0) - n * 0.02, c - right * (hw - 0.05) + Vector3(0, hh - 0.05, 0) - n * 0.02]
	NewModels6.quad2(lit, "warm", warm[0], warm[1], warm[2], warm[3], Color.WHITE, true)
	if cracked:
		var p0 := c + right * (-hw * 0.5) + Vector3(0, hh * 0.7, 0)
		for k in 6:
			var a := TAU * k / 6.0 + 0.3
			NewModels6.limb(glass, "paper", p0 + n * 0.004, p0 + right * cos(a) * hw * 0.8 + Vector3(0, sin(a) * hh * 0.8, 0) + n * 0.004, 0.0015, 0.0005, Color(0.8, 0.82, 0.85), 3)

static func _window_asset(md: NewModels6.Model, is_lit: bool, cracked: bool) -> void:
	var glass := md.sub("glass", Vector3.ZERO)
	var lit := md.sub("window_light", Vector3.ZERO)
	_window(md, glass, lit, Vector3(0, 0.6, 0.0), 1.2, 1.2, cracked, Vector3(0, 0, 1))
	if not is_lit:
		lit.m.clear()

static func _door(md: NewModels6.Model, hinge: Vector3, ang: float) -> void:
	# a plank door 0.95 x 2.05 m with Z-bracing, a latch and iron strap hinges; hinge is the bottom of the hinge edge, +x runs away from it; ang swings it open (about +Y)
	var rot := Basis(Vector3.UP, -ang)
	var R := func(p: Vector3) -> Vector3: return hinge + rot * (p - hinge)
	for k in 5:
		var x := hinge.x + 0.095 + k * 0.19
		NewModels6.box(md, "wood", R.call(Vector3(x, hinge.y + 1.025, hinge.z)), Vector3(0.185, 2.05, 0.04), NewModels7.W(BARE * (0.7 + 0.3 * NewModels6.rnd(k, 7.0)), 1.0), 0.0, Color(-1, 0, 0), rot)
	NewModels6.box(md, "wood", R.call(Vector3(hinge.x + 0.475, hinge.y + 0.35, hinge.z + 0.04)), Vector3(0.9, 0.12, 0.03), NewModels7.W(BARE * 0.8, 0.75), 0.0, Color(-1, 0, 0), rot)
	NewModels6.box(md, "wood", R.call(Vector3(hinge.x + 0.475, hinge.y + 1.7, hinge.z + 0.04)), Vector3(0.9, 0.12, 0.03), NewModels7.W(BARE * 0.8, 0.75), 0.0, Color(-1, 0, 0), rot)
	NewModels6.limb(md, "wood", R.call(Vector3(hinge.x + 0.05, hinge.y + 0.4, hinge.z + 0.045)), R.call(Vector3(hinge.x + 0.9, hinge.y + 1.7, hinge.z + 0.045)), 0.05, 0.05, NewModels7.W(BARE * 0.8, 1.0), 4)
	for y in [0.3, 1.75]:
		NewModels6.box(md, "rust", R.call(Vector3(hinge.x + 0.25, hinge.y + y, hinge.z + 0.045)), Vector3(0.5, 0.06, 0.012), Color(0.18, 0.1, 0.07), 0.0, Color(-1, 0, 0), rot)
	NewModels6.box(md, "rust", R.call(Vector3(hinge.x + 0.82, hinge.y + 1.0, hinge.z + 0.05)), Vector3(0.14, 0.04, 0.02), Color(0.14, 0.1, 0.08), 0.0, Color(-1, 0, 0), rot)
	NewModels6.cyl(md, "rust", R.call(Vector3(hinge.x + 0.8, hinge.y + 0.98, hinge.z + 0.04)), R.call(Vector3(hinge.x + 0.8, hinge.y + 0.98, hinge.z + 0.08)), 0.018, 0.016, 8, Color(0.14, 0.1, 0.08), 3, 0.0)

static func _door_asset(md: NewModels6.Model, ang: float) -> void:
	var hinge := Vector3.ZERO
	NewModels7.board(md, "wood", Vector3(-0.0, 0.0, -0.0), Vector3(-0.0, 2.1, -0.0), 0.12, 0.1, NewModels7.W(BARE * 0.8, 1.0))      # the jamb
	var dn := md.sub("door", hinge)
	_door(dn, hinge + Vector3(0.05, 0.0, 0.0), ang)

static func _chimney_model() -> NewModels6.Model:
	var m := NewModels6.Model.new()
	_chimney(m, 0.0, 0.0)
	return m

static func _chimney(md: NewModels6.Model, _a: float, _b: float) -> void:
	# a fieldstone chimney, 0.9 m square at the foot, tapering, to 5.0 m with a leaning cap of brick and a rusty pot
	var courses := 22
	for c in courses:
		var y := 0.3 + c * 0.2
		var w := lerpf(0.95, 0.72, float(c) / courses)
		var off := Vector3(0.0, 0.0, 0.0)
		if c > courses - 4: off = Vector3(0.025 * (c - courses + 4), 0.0, 0.0)
		var n := 3 if c % 2 == 0 else 2
		var flip := c % 2 == 1
		for k in n:
			var bw := w / n
			var pc := -w * 0.5 + (k + 0.5) * bw
			var sz := Vector3(w, 0.19, bw - 0.012) if not flip else Vector3(bw - 0.012, 0.19, w)
			var pos := Vector3(off.x, y + 0.1, pc) if not flip else Vector3(off.x + pc, y + 0.1, 0.0)
			NewModels6.rbox(md, "stone", pos, sz, NewModels6.vc(STONE_C * (0.8 + 0.3 * NewModels6.rnd(c * 3 + k, 121.0)), c * 3.7 + k, 0.08), Basis.IDENTITY, 4.0, 6, 0.1)
	NewModels6.rbox(md, "brick", Vector3(0.1, 4.95, 0.0), Vector3(0.82, 0.18, 0.82), Color(0.5, 0.28, 0.22), Basis(Vector3.RIGHT, 0.0) * Basis(Vector3.BACK, 0.05), 4.0, 6, 0.1)
	NewModels6.cyl(md, "rust", Vector3(0.1, 5.04, 0.0), Vector3(0.12, 5.4, 0.02), 0.2, 0.15, 12, Color(0.22, 0.12, 0.08), 3, 0.06)
	NewModels6.cyl(md, "rust", Vector3(0.12, 5.4, 0.02), Vector3(0.12, 5.45, 0.02), 0.17, 0.17, 12, Color(0.12, 0.08, 0.06), 3, 0.04)

static func _porch_light(md: NewModels6.Model, on: bool) -> void:
	# a small exterior lamp on a bracket: a cast housing, a wire cage, a bulb node with a warm glow when on
	NewModels6.box(md, "rust", Vector3(0, 0.15, -0.03), Vector3(0.06, 0.12, 0.03), Color(0.15, 0.13, 0.1))
	NewModels6.limb(md, "rust", Vector3(0, 0.12, -0.02), Vector3(0, 0.12, 0.14), 0.014, 0.014, Color(0.15, 0.13, 0.1), 6)
	NewModels6.cyl(md, "rust", Vector3(0, 0.11, 0.14), Vector3(0, 0.2, 0.14), 0.07, 0.05, 12, Color(0.18, 0.16, 0.12), 3, 0.04)
	NewModels6.cyl(md, "glass", Vector3(0, 0.0, 0.14), Vector3(0, 0.11, 0.14), 0.05, 0.065, 12, Color.WHITE, 2, 0.0)
	var bulb := md.sub("bulb", Vector3(0, 0.06, 0.14))
	if on:
		NewModels6.ball(bulb, "warm", Vector3(0, 0.06, 0.14), Vector3(0.028, 0.036, 0.028), Color.WHITE, 8)
	else:
		NewModels6.ball(bulb, "lamp_off", Vector3(0, 0.06, 0.14), Vector3(0.028, 0.036, 0.028), Color.WHITE, 8)
	for k in 6:
		var a := TAU * k / 6.0
		NewModels6.limb(md, "rust", Vector3(cos(a) * 0.06, 0.0, 0.14 + sin(a) * 0.06), Vector3(cos(a) * 0.045, 0.2, 0.14 + sin(a) * 0.045), 0.003, 0.003, Color(0.14, 0.12, 0.1), 3)

static func _woodpile(md: NewModels6.Model) -> void:
	# split logs stacked under the porch: 4 courses of 7 to 9 logs, bark side out, a pile of kindling and an axe-marked chopping block
	var i := 0
	for r in 5:
		var n := 9 - (r % 2)
		for k in n:
			var rad := 0.075 + 0.025 * NewModels6.rnd(i, 131.0)
			var x := -0.6 + k * 0.15 + (0.075 if r % 2 == 1 else 0.0)
			var y := 0.08 + r * 0.14
			NewModels6.cyl(md, "wood", Vector3(x, y, -0.2), Vector3(x, y, 0.28), rad, rad * 0.97, 8, NewModels7.W(Color(0.4, 0.3, 0.2) * (0.8 + 0.3 * NewModels6.rnd(i, 132.0)), 0.5), 3, 0.06)
			NewModels6.cyl(md, "wood", Vector3(x, y, 0.28), Vector3(x, y, 0.284), rad * 0.95, rad * 0.95, 8, NewModels7.W(Color(0.72, 0.58, 0.4), 0.5), 3, 0.04)
			i += 1
	for k in 14:
		NewModels6.limb(md, "wood", Vector3(0.75 + NewModels6.rnd(k, 133.0) * 0.4, 0.02 + 0.02 * (k % 3), -0.2 + NewModels6.rnd(k, 134.0) * 0.5), Vector3(0.75 + NewModels6.rnd(k, 135.0) * 0.4, 0.04 + 0.02 * (k % 3), 0.15 + NewModels6.rnd(k, 136.0) * 0.3), 0.012, 0.01, NewModels7.W(Color(0.55, 0.42, 0.28), 0.5), 4)
	NewModels6.cyl(md, "wood", Vector3(-1.2, 0.0, 0.5), Vector3(-1.2, 0.36, 0.5), 0.2, 0.19, 12, NewModels7.W(Color(0.4, 0.3, 0.2), 1.0), 3, 0.05)
	NewModels6.cyl(md, "wood", Vector3(-1.2, 0.36, 0.5), Vector3(-1.2, 0.362, 0.5), 0.19, 0.19, 12, NewModels7.W(Color(0.62, 0.48, 0.32), 1.0), 3, 0.04)

static func _lean_to(md: NewModels6.Model) -> void:
	# a small lean-to against the cabin side: post frame, tarpaulin roof sagging, a few tools hanging on the wall and a bench
	for sx: float in [-1.0, 1.0]:
		NewModels7.board(md, "wood", Vector3(sx * 1.1, 0.0, 1.0), Vector3(sx * 1.1, 1.9, 1.0), 0.1, 0.1, NewModels7.W(BARE * 0.8, 1.0))
		NewModels7.board(md, "wood", Vector3(sx * 1.1, 0.0, -0.2), Vector3(sx * 1.1, 2.4, -0.2), 0.1, 0.1, NewModels7.W(BARE * 0.8, 1.0))
		NewModels7.board(md, "wood", Vector3(sx * 1.1, 1.9, 1.0), Vector3(sx * 1.1, 2.4, -0.2), 0.08, 0.08, NewModels7.W(BARE * 0.8, 0.5))
	var f := func(x: float, z: float) -> float:
		return -0.05 * (1.0 - pow(x / 1.25, 2.0)) * (1.0 - pow(z / 0.75, 2.0)) + 0.012 * sin(x * 8.0 + z * 3.0)
	NewModels7.sheet_grid(md, "tarp", 2.5, 1.5, 20, 12, Color(0.1, 0.27, 0.34), f, Transform3D(Basis(Vector3.RIGHT, 0.0), Vector3(0, 2.2, 0.4)) * Transform3D(Basis(Vector3.RIGHT, atan2(0.5, 1.2)), Vector3.ZERO), 0.05)
	# (buildings lane: the tarp used to tilt the other way, high at the front, so it hung in the air off the front rafters
	# and stood 0.4 m clear of the back posts; it now lies on the rafters, high at the back post and low at the front)
	NewModels6.box(md, "wood", Vector3(0, 0.45, 0.8), Vector3(1.8, 0.05, 0.4), NewModels7.W(BARE * 0.9, 0.75))
	for sx: float in [-1.0, 1.0]:
		NewModels6.box(md, "wood", Vector3(sx * 0.8, 0.22, 0.8), Vector3(0.06, 0.44, 0.36), NewModels7.W(BARE * 0.8, 1.0))
	NewModels6.box(md, "wood", Vector3(0, 1.0, -0.15), Vector3(2.0, 0.04, 0.05), NewModels7.W(BARE * 0.8, 0.75))
	for k in 4:
		var x := -0.7 + k * 0.45
		NewModels6.limb(md, "wood", Vector3(x, 1.0, -0.12), Vector3(x, 0.4, -0.12), 0.012, 0.012, NewModels7.W(Color(0.4, 0.3, 0.2), 1.0), 5)
		NewModels6.box(md, "rust", Vector3(x, 0.38, -0.12), Vector3(0.15 if k < 2 else 0.05, 0.1, 0.012), Color(0.35, 0.3, 0.28))
	NewModels7.merge(md, NewModels6.build("cabin_yard_tools_a", 0), Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.6, 0.0, 0.6)))

static func _ruts(md: NewModels6.Model) -> void:
	# two shallow tyre ruts in mud, 8 m long and 1.5 m apart, with a puddle in the low part and tread marks
	var path := func(t: float) -> Vector3: return Vector3(0.6 * sin(t * 3.0), 0.0, -4.0 + t * 8.0)
	for sx: float in [-1.0, 1.0]:
		var rows: Array = []
		for j in 17:
			var t := float(j) / 16.0
			var c: Vector3 = path.call(t)
			var r := PackedVector3Array(); r.resize(7)
			for i in 7:
				var u := (float(i) / 6.0 - 0.5) * 0.4
				r[i] = Vector3(c.x + sx * 0.75 + u, 0.03 - 0.045 * (1.0 - pow(u / 0.2, 2.0)) + 0.008 * sin(t * 40.0), c.z)
			rows.append(r)
		NewModels6.gridsurf(md, "mud", rows, Color(0.18, 0.13, 0.09), func(_i: int, _j: int, _p: Vector3) -> Vector3: return Vector3.UP, 0.08)
		for k in 22:
			var t2 := float(k) / 21.0
			var c2: Vector3 = path.call(t2)
			NewModels6.box(md, "mud", Vector3(c2.x + sx * 0.75, -0.008, c2.z), Vector3(0.34, 0.012, 0.03), Color(0.13, 0.095, 0.065))
	for sx: float in [-1.0, 1.0]:
		var c3: Vector3 = path.call(0.62)
		NewModels6.quad2(md, "water", Vector3(c3.x + sx * 0.75 - 0.13, 0.0, c3.z - 0.4), Vector3(c3.x + sx * 0.75 + 0.13, 0.0, c3.z - 0.4), Vector3(c3.x + sx * 0.75 + 0.13, 0.0, c3.z + 0.4), Vector3(c3.x + sx * 0.75 - 0.13, 0.0, c3.z + 0.4), Color.WHITE, false)

static func _old_sign(md: NewModels6.Model) -> void:
	# THE OLD PLOT: a board sign on a leaning post, the paint gone, the letters still readable
	NewModels7.board(md, "wood", Vector3(0, 0.0, 0), Vector3(0.18, 1.7, 0.0), 0.12, 0.12, NewModels7.W(BARE * 0.8, 1.0))
	var bas := Basis(Vector3.BACK, -0.1)
	NewModels6.box(md, "wood", bas * Vector3(0.16, 1.45, 0.07) , Vector3(1.0, 0.45, 0.04), NewModels7.W(Color(0.4, 0.37, 0.33), 0.75), 0.0, Color(-1, 0, 0), bas)
	NewModels6.text(md, "paint", "THE OLD", bas * Vector3(0.16, 1.55, 0.095), bas * Vector3(0, 0, 1), 0.12, Color(0.78, 0.74, 0.62), bas * Vector3.UP, 0.0)
	NewModels6.text(md, "paint", "PLOT", bas * Vector3(0.16, 1.38, 0.095), bas * Vector3(0, 0, 1), 0.12, Color(0.78, 0.74, 0.62), bas * Vector3.UP, 0.0)
	NewModels6.cyl(md, "rust", bas * Vector3(-0.2, 1.5, 0.09), bas * Vector3(-0.2, 1.5, 0.12), 0.012, 0.012, 6, Color(0.3, 0.2, 0.12), 3, 0.0)
	NewModels6.ball(md, "soil", Vector3(0.0, 0.03, 0), Vector3(0.22, 0.06, 0.22), Color(0.2, 0.15, 0.1), 7)

static func _yard_tools(md: NewModels6.Model) -> void:
	# an old spade, a zinc bucket and a coil of rope lying in the yard
	NewModels6.limb(md, "wood", Vector3(0, 0.1, -0.4), Vector3(0.0, 0.5, 0.5), 0.016, 0.016, NewModels7.W(Color(0.45, 0.35, 0.24), 1.0), 6)
	NewModels6.box(md, "rust", Vector3(0.0, 0.12, -0.5), Vector3(0.2, 0.012, 0.26), Color(0.36, 0.28, 0.24), 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, -0.4))
	NewModels6.cyl(md, "sheet", Vector3(0.6, 0.0, 0.1), Vector3(0.6, 0.28, 0.1), 0.12, 0.16, 16, Color(0.55, 0.57, 0.58), 1, 0.05)
	NewModels6.cyl(md, "rust", Vector3(0.6, 0.0, 0.1), Vector3(0.6, 0.005, 0.1), 0.12, 0.12, 16, Color(0.4, 0.4, 0.4), 3, 0.0)
	for k in 5:
		var rr := 0.09 + k * 0.012
		var prev := Vector3(-0.6 + rr, 0.02 + k * 0.012, 0.2)
		for j in range(1, 17):
			var a := TAU * j / 16.0
			var p := Vector3(-0.6 + cos(a) * rr, 0.02 + k * 0.012, 0.2 + sin(a) * rr)
			NewModels6.limb(md, "cloth", prev, p, 0.009, 0.009, Color(0.6, 0.52, 0.38), 4)
			prev = p

static func _aerial(md: NewModels6.Model) -> void:
	# a radio aerial mast by the cabin: a guyed steel pole, 6 m, with a dipole and three wires
	NewModels6.limb(md, "steel", Vector3(0, 0, 0), Vector3(0.0, 6.0, 0), 0.04, 0.02, Color(0.5, 0.52, 0.55), 8)
	NewModels6.limb(md, "steel", Vector3(-0.8, 5.4, 0), Vector3(0.8, 5.4, 0), 0.01, 0.01, Color(0.5, 0.52, 0.55), 5)
	for k in 3:
		var a := TAU * k / 3.0
		NewModels7.rope(md, "steel", Vector3(0, 4.5, 0), Vector3(cos(a) * 2.5, 0.05, sin(a) * 2.5), 0.1, 0.004, Color(0.4, 0.4, 0.42), 8)
		NewModels6.cyl(md, "rust", Vector3(cos(a) * 2.5, 0.0, sin(a) * 2.5), Vector3(cos(a) * 2.5, 0.2, sin(a) * 2.5), 0.015, 0.012, 6, Color(0.3, 0.2, 0.12), 3, 0.0)
	NewModels6.ball(md, "concrete", Vector3(0, 0.05, 0), Vector3(0.2, 0.1, 0.2), Color(0.5, 0.49, 0.46), 7, Basis.IDENTITY, 0.06)

static func _search_flag(md: NewModels6.Model) -> void:
	# a search marker: a 1.0 m cane with a bright orange pennant, in a small cone of earth
	NewModels6.limb(md, "wood", Vector3(0, 0, 0), Vector3(0, 1.0, 0), 0.008, 0.006, NewModels7.W(Color(0.55, 0.42, 0.26), 1.0), 5)
	NewModels6.sheet(md, "cloth", [Vector3(0, 0.98, 0), Vector3(0.28, 0.9, 0.0), Vector3(0.0, 0.76, 0)], Color(0.95, 0.4, 0.05), Vector3(0, 0, 1))
	NewModels6.ball(md, "soil", Vector3(0, 0.01, 0), Vector3(0.06, 0.03, 0.06), Color(0.2, 0.15, 0.1), 6)

static func _search_tape(md: NewModels6.Model) -> void:
	# blue-and-white police tape strung between two canes 6 m apart, sagging and fluttering
	for sx: float in [-1.0, 1.0]:
		NewModels6.limb(md, "wood", Vector3(sx * 3.0, 0, 0), Vector3(sx * 3.0, 1.2, 0), 0.01, 0.008, NewModels7.W(Color(0.55, 0.42, 0.26), 1.0), 5)
	var prev := Vector3(-3.0, 1.1, 0)
	for k in range(1, 25):
		var t := float(k) / 24.0
		var p := Vector3(-3.0 + 6.0 * t, 1.1 - 0.2 * 4.0 * t * (1.0 - t) + 0.03 * sin(t * 18.0), 0.04 * sin(t * 9.0))
		NewModels6.quad2(md, "cloth", prev, p, p + Vector3(0, -0.06, 0), prev + Vector3(0, -0.06, 0), Color(0.2, 0.35, 0.7) if k % 2 == 0 else Color(0.9, 0.9, 0.92))
		prev = p
	NewModels6.text(md, "paint", "POLICE", Vector3(-1.0, 0.92, 0.004), Vector3(0, 0, 1), 0.04, Color(0.05, 0.06, 0.3), Vector3.UP, 0.0)

static func _smoke(md: NewModels6.Model) -> void:
	# a rising smoke column drawn as soft stacked discs (for a billboard/particle stand-in) and a warm light at the base
	NewModels6.put(md, "steam", DroneParts.lathe(PackedVector2Array([Vector2(0.07, 0.0), Vector2(0.14, 0.6), Vector2(0.28, 1.4), Vector2(0.5, 2.4), Vector2(0.78, 3.6), Vector2(0.0, 3.7)]), 16), Transform3D(Basis(Vector3.BACK, -0.18), Vector3(0, 0.2, 0)), Color.WHITE, 0.0)
	var glow := md.sub("glow", Vector3(0, 0.2, 0))
	NewModels6.ball(glow, "warm", Vector3(0, 0.2, 0), Vector3(0.08, 0.06, 0.08), Color.WHITE, 8)

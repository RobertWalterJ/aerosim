class_name NewModels6Camp
extends RefCounted
## Story batch (models8), the camp: Ellis's tents, tarp, stove, fire, bedding and the small things that make it lived in, plus the
## extra camp detail from the brief's priority 1 (lead, mug, gas bottle, papers). Static props, metres, +Z front, origin on the ground.
## Colliders only on the larger hard things (tents, table, cooler, toolbox); none on soft goods.

const NAMES: Array[String] = [
	"camp_tent_a", "camp_tent_a_open", "camp_tent_b", "camp_tarp_a", "camp_stove_a", "camp_stove_a_cold", "camp_lantern_a", "camp_lantern_a_off",
	"camp_chair_a", "camp_table_a", "camp_cooler_a", "camp_fire_ring_a", "camp_fire_ring_a_cold", "camp_firewood_a", "camp_axe_a", "camp_bedding_a",
	"camp_washbasin_a", "camp_toolbox_a", "camp_sketchbook_a", "camp_programme_a", "camp_programme_a_open", "camp_dog_bed_a", "camp_clothes_line_a",
	"camp_dog_lead_a", "camp_mug_a", "camp_gas_bottle_a", "camp_paper_a",
]

const CANVAS_G := Color(0.17, 0.27, 0.17)
const DARK_CANVAS := Color(0.15, 0.14, 0.11)
const ROPE := Color(0.55, 0.47, 0.32)
const ALU := Color(0.62, 0.64, 0.66)

static func build(name: String, md: NewModels6.Model, lod: int) -> bool:
	match name:
		"camp_tent_a": _tent_a(md, false, lod)
		"camp_tent_a_open": _tent_a(md, true, lod)
		"camp_tent_b": _tent_b(md, lod)
		"camp_tarp_a": _tarp_a(md, lod)
		"camp_stove_a": _stove(md, true)
		"camp_stove_a_cold": _stove(md, false)
		"camp_lantern_a": _lantern(md, true)
		"camp_lantern_a_off": _lantern(md, false)
		"camp_chair_a": NewModels6Chars._camp_chair_under(md, Vector3.ZERO); NewModels6.hull(md, Vector3(0, 0.45, 0), Vector3(0.55, 0.9, 0.55)); md.hulls.clear()
		"camp_table_a": _table(md)
		"camp_cooler_a": _cooler(md)
		"camp_fire_ring_a": _fire_ring(md, true, lod)
		"camp_fire_ring_a_cold": _fire_ring(md, false, lod)
		"camp_firewood_a": _firewood(md, lod)
		"camp_axe_a": _axe(md)
		"camp_bedding_a": _bedding(md)
		"camp_washbasin_a": _washbasin(md)
		"camp_toolbox_a": NewModels6Chars._toolbox(md, Vector3.ZERO, true); NewModels6.hull(md, Vector3(0.1, 0.15, 0), Vector3(1.0, 0.3, 0.5))
		"camp_sketchbook_a": _sketchbook(md)
		"camp_programme_a": _programme(md, false)
		"camp_programme_a_open": _programme(md, true)
		"camp_dog_bed_a": _dog_bed(md)
		"camp_clothes_line_a": _clothes_line(md)
		"camp_dog_lead_a": _lead(md)
		"camp_mug_a": _mug(md)
		"camp_gas_bottle_a": _bottle(md, Vector3.ZERO)
		"camp_paper_a": _papers(md)
		_: return false
	return true

# ---------------------------------------------------------------- small helpers
static func _rope(md: NewModels6.Model, a: Vector3, b: Vector3, sag := 0.0, r := 0.006, col := ROPE) -> void:
	var prev := a
	var n := 5 if sag > 0.0 else 1
	for k in range(1, n + 1):
		var t := float(k) / n
		var p := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		NewModels6.limb(md, "rubber", prev, p, r, r, col, 4)
		prev = p

static func _peg(md: NewModels6.Model, p: Vector3) -> void:
	NewModels6.limb(md, "sheet", p + Vector3(0, 0.12, 0), p + Vector3(0, -0.03, 0), 0.008, 0.006, Color(0.5, 0.52, 0.55), 5)
	NewModels6.ball(md, "sheet", p + Vector3(0, 0.12, 0), Vector3(0.016, 0.01, 0.016), Color(0.55, 0.57, 0.6), 5)

## A canvas panel between four corners (a, b along one edge, d, c along the opposite), with a little sag in the middle.
static func _panel(md: NewModels6.Model, key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, sag := 0.0, nu := 6, nv := 5, vary := 0.07, wr := 0.0) -> void:
	var rows: Array = []
	var nrm := (b - a).cross(d - a).normalized()
	for j in nv + 1:
		var v := float(j) / nv
		var r := PackedVector3Array(); r.resize(nu + 1)
		for i in nu + 1:
			var u := float(i) / nu
			var p := a.lerp(b, u).lerp(d.lerp(c, u), v)
			p += nrm * (-sag * sin(u * PI) * sin(v * PI))
			# the wrinkles of used canvas
			p += nrm * (wr * sin(u * 17.0 + v * 5.0) * sin(v * 11.0))
			r[i] = p
		rows.append(r)
	var hint := func(_i: int, _j: int, _p: Vector3) -> Vector3: return nrm
	NewModels6.gridsurf(md, key, rows, col, hint, vary)

# ---------------------------------------------------------------- tents and shelters
static func _tent_a(md: NewModels6.Model, open: bool, lod: int) -> void:
	var hl := 1.2; var hw := 0.8; var h := 1.2
	var nu := 6 if lod == 0 else 3
	var col := CANVAS_G
	for sx: float in [-1.0, 1.0]:
		_panel(md, "canvas", Vector3(sx * hw, 0.0, -hl), Vector3(sx * hw, 0.0, hl), Vector3(0, h, hl), Vector3(0, h, -hl), col, 0.035 * sx, nu, 4, 0.06, 0.006)
	# the back, with a small vent, and the front with its zip door
	md.b("canvas")
	NewModels6.sheet(md, "canvas", [Vector3(-hw, 0, -hl), Vector3(hw, 0, -hl), Vector3(0, h, -hl)], col * 0.95, Vector3(0, 0, -1))
	NewModels6.box(md, "canvas", Vector3(0, 0.78, -hl - 0.005), Vector3(0.18, 0.1, 0.006), Color(0.08, 0.12, 0.08))
	if not open:
		NewModels6.sheet(md, "canvas", [Vector3(-hw, 0, hl), Vector3(hw, 0, hl), Vector3(0, h, hl)], col, Vector3(0, 0, 1))
		NewModels6.limb(md, "sheet", Vector3(0, 0.04, hl + 0.004), Vector3(0, h * 0.8, hl + 0.004), 0.007, 0.007, Color(0.3, 0.3, 0.3), 4)
	else:
		# the door flap is rolled back to the left; the dark inside shows, with a rolled mat and a pack
		NewModels6.sheet(md, "canvas", [Vector3(-hw, 0, hl), Vector3(-0.28, 0, hl), Vector3(-0.1, h * 0.8, hl), Vector3(0, h, hl)], col, Vector3(0, 0, 1))
		NewModels6.sheet(md, "canvas", [Vector3(0.28, 0, hl), Vector3(hw, 0, hl), Vector3(0, h, hl), Vector3(0.1, h * 0.8, hl)], col, Vector3(0, 0, 1))
		NewModels6.sheet(md, "paint", [Vector3(-0.28, 0.0, hl - 0.02), Vector3(0.28, 0.0, hl - 0.02), Vector3(0.1, h * 0.8, hl - 0.02), Vector3(-0.1, h * 0.8, hl - 0.02)], Color(0.03, 0.04, 0.03), Vector3(0, 0, 1))
		NewModels6.ball(md, "canvas", Vector3(-0.48, 0.02, hl - 0.05), Vector3(0.09, 0.07, 0.07), col * 0.8, 6)       # the flap bundled
	# ground sheet, the ridge pole ends, guy lines and pegs
	NewModels6.box(md, "tarp", Vector3(0, 0.004, 0), Vector3(1.6, 0.006, 2.4), Color(0.1, 0.12, 0.09))
	for z: float in [-hl - 0.02, hl + 0.02]:
		NewModels6.limb(md, "sheet", Vector3(0, h + 0.06, z), Vector3(0, 0.0, z + signf(z) * 0.18), 0.011, 0.011, ALU, 6)
	NewModels6.limb(md, "sheet", Vector3(0, h + 0.01, -hl), Vector3(0, h + 0.01, hl), 0.008, 0.008, ALU, 5)
	for z: float in [-hl - 0.9, hl + 0.9]:
		var pe := Vector3(0, 0.0, z)
		_rope(md, Vector3(0, h * 0.97, signf(z) * hl), pe)
		_peg(md, pe)
	for sx: float in [-1.0, 1.0]:
		for z: float in [-0.7, 0.7]:
			var ps := Vector3(sx * (hw + 0.35), 0.0, z)
			_rope(md, Vector3(sx * hw * 0.99, 0.01, z), ps, 0.0)
			_peg(md, ps)
	NewModels6.hull(md, Vector3(0, 0.6, 0), Vector3(1.7, 1.2, 2.5))

static func _tent_b(md: NewModels6.Model, lod: int) -> void:
	# a basha: one sloping sheet of dark canvas, high at the back, strung off two poles, open at the front
	var col := DARK_CANVAS
	_panel(md, "canvas", Vector3(-1.2, 1.6, -0.9), Vector3(1.2, 1.6, -0.9), Vector3(1.2, 0.45, 0.9), Vector3(-1.2, 0.45, 0.9), col, 0.08, 7, 5, 0.08, 0.012)
	NewModels6.sheet(md, "canvas", [Vector3(-1.2, 1.6, -0.9), Vector3(-1.2, 0.0, -0.9), Vector3(-1.2, 0.0, 0.9), Vector3(-1.2, 0.45, 0.9)], col * 0.92, Vector3(-1, 0, 0))
	for sx: float in [-1.2, 1.2]:
		NewModels6.limb(md, "wood", Vector3(sx, 0.0, -0.9), Vector3(sx, 1.65, -0.9), 0.025, 0.02, Color(0.4, 0.34, 0.26), 7, 0.08)
		_rope(md, Vector3(sx, 0.45, 0.9), Vector3(sx * 1.5, 0.0, 1.5))
		_peg(md, Vector3(sx * 1.5, 0.0, 1.5))
		_rope(md, Vector3(sx, 1.6, -0.9), Vector3(sx * 1.3, 0.0, -1.6))
		_peg(md, Vector3(sx * 1.3, 0.0, -1.6))
	NewModels6.box(md, "tarp", Vector3(0, 0.004, 0), Vector3(2.2, 0.006, 1.6), Color(0.15, 0.13, 0.1))
	NewModels6.hull(md, Vector3(0, 0.8, 0), Vector3(2.5, 1.7, 1.9))

static func _tarp_a(md: NewModels6.Model, lod: int) -> void:
	# a blue tarp over the camp table: high at the back, strung from four poles, the ropes taut, a pool of sag in the middle
	var col := Color(0.12, 0.30, 0.58)
	var a := Vector3(-1.5, 2.3, -1.2); var b := Vector3(1.5, 2.3, -1.2); var c := Vector3(1.5, 1.8, 1.2); var d := Vector3(-1.5, 1.8, 1.2)
	_panel(md, "tarp", a, b, c, d, col, 0.1, 10, 8, 0.05, 0.01)
	for p: Vector3 in [a, b, c, d]:
		var base := Vector3(p.x * 1.07, 0.0, p.z * 1.07)
		NewModels6.limb(md, "wood", base, p + Vector3(0, 0.05, 0), 0.03, 0.025, Color(0.42, 0.36, 0.28), 7, 0.08)
		NewModels6.ball(md, "rubber", p, Vector3(0.025, 0.025, 0.025), Color(0.8, 0.8, 0.75), 5)
		_rope(md, p + Vector3(0, 0.04, 0), Vector3(p.x * 1.55, 0.0, p.z * 1.55), 0.0)
		_peg(md, Vector3(p.x * 1.55, 0.0, p.z * 1.55))
	NewModels6.hull(md, Vector3(0, 1.15, 0), Vector3(3.0, 2.3, 2.4))
	md.hulls.clear()

# ---------------------------------------------------------------- stove, lantern, table, cooler
static func _stove(md: NewModels6.Model, burning: bool) -> void:
	var olive := Color(0.22, 0.25, 0.17)
	NewModels6.box(md, "sheet", Vector3(0, 0.07, 0), Vector3(0.52, 0.12, 0.3), olive)
	NewModels6.box(md, "sheet", Vector3(0, 0.255, -0.15), Vector3(0.52, 0.2, 0.012), olive * 1.05, 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, 0.0))     # the open lid as a windbreak
	for sx: float in [-0.14, 0.14]:
		NewModels6.cyl(md, "chrome", Vector3(sx, 0.13, 0.02), Vector3(sx, 0.145, 0.02), 0.07, 0.065, 12, Color(0.28, 0.28, 0.3), 3, 0.05)
		for k in 4:
			var a := TAU * k / 4.0
			NewModels6.box(md, "chrome", Vector3(sx + cos(a) * 0.045, 0.158, 0.02 + sin(a) * 0.045), Vector3(0.03, 0.02, 0.012), Color(0.2, 0.2, 0.22), a)
	# a dented kettle on the left ring
	NewModels6.cyl(md, "enamel", Vector3(-0.14, 0.15, 0.02), Vector3(-0.14, 0.31, 0.02), 0.085, 0.07, 14, Color(0.2, 0.3, 0.42), 3, 0.05)
	NewModels6.limb(md, "chrome", Vector3(-0.14, 0.31, 0.02), Vector3(-0.14, 0.33, 0.02), 0.02, 0.02, Color(0.15, 0.15, 0.17), 6)
	_bottle(md, Vector3(0.38, 0.0, 0.0))
	NewModels6.limb(md, "rubber", Vector3(0.38, 0.14, 0.0), Vector3(0.26, 0.1, 0.03), 0.008, 0.008, Color(0.05, 0.05, 0.05), 4)
	if burning:
		var fl := md.sub("flame", Vector3(0.14, 0.15, 0.02))
		for k in 10:
			var a := TAU * k / 10.0
			NewModels6.limb(fl, "flame_blue", Vector3(0.14 + cos(a) * 0.04, 0.147, 0.02 + sin(a) * 0.04), Vector3(0.14 + cos(a) * 0.045, 0.19, 0.02 + sin(a) * 0.045), 0.012, 0.004, Color(0.4, 0.55, 1.0), 4)
	NewModels6.hull(md, Vector3(0.1, 0.17, 0), Vector3(0.9, 0.34, 0.4))

static func _bottle(md: NewModels6.Model, o: Vector3) -> void:
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.075, 0.0), Vector2(0.08, 0.02), Vector2(0.082, 0.1), Vector2(0.075, 0.2), Vector2(0.05, 0.245), Vector2(0.025, 0.255), Vector2(0.025, 0.285), Vector2(0.0, 0.285)])
	NewModels6.put(md, "paint", DroneParts.lathe(prof, 14), Transform3D(Basis.IDENTITY, o), Color(0.55, 0.12, 0.1), 0.0)
	NewModels6.cyl(md, "chrome", o + Vector3(0, 0.285, 0), o + Vector3(0, 0.31, 0), 0.03, 0.025, 8, Color(0.6, 0.55, 0.3), 3, 0.0)
	NewModels6.box(md, "paper", o + Vector3(0, 0.12, 0.0) + Vector3(0, 0, 0.083), Vector3(0.1, 0.08, 0.002), Color(0.9, 0.85, 0.7))

static func _lantern(md: NewModels6.Model, on: bool) -> void:
	var tin := Color(0.16, 0.22, 0.17)
	NewModels6.cyl(md, "paint", Vector3(0, 0.0, 0), Vector3(0, 0.05, 0), 0.075, 0.075, 14, tin, 3, 0.04)
	NewModels6.cyl(md, "paint", Vector3(0, 0.2, 0), Vector3(0, 0.235, 0), 0.07, 0.04, 14, tin, 3, 0.04)
	for k in 4:
		var a := TAU * k / 4.0 + 0.78
		NewModels6.limb(md, "sheet", Vector3(cos(a) * 0.06, 0.05, sin(a) * 0.06), Vector3(cos(a) * 0.06, 0.2, sin(a) * 0.06), 0.005, 0.005, ALU, 4)
	var g := md.sub("lamp_glass", Vector3(0, 0.125, 0))
	NewModels6.ball(g, "lamp" if on else "lamp_off", Vector3(0, 0.125, 0), Vector3(0.055, 0.075, 0.055), Color.WHITE, 12)
	NewModels6.limb(md, "sheet", Vector3(-0.05, 0.235, 0), Vector3(0, 0.3, 0), 0.005, 0.005, ALU, 4)
	NewModels6.limb(md, "sheet", Vector3(0.05, 0.235, 0), Vector3(0, 0.3, 0), 0.005, 0.005, ALU, 4)

static func _table(md: NewModels6.Model) -> void:
	NewModels6.box(md, "wood", Vector3(0, 0.72, 0), Vector3(0.95, 0.025, 0.6), Color(0.52, 0.42, 0.3), 0.0, Color(0.55, 0.45, 0.33))
	NewModels6.box(md, "sheet", Vector3(0, 0.695, 0), Vector3(0.9, 0.02, 0.56), Color(0.6, 0.62, 0.64))
	for sx: float in [-1.0, 1.0]:
		NewModels6.limb(md, "sheet", Vector3(sx * 0.4, 0.0, 0.26), Vector3(sx * 0.3, 0.7, -0.22), 0.013, 0.013, ALU, 6)
		NewModels6.limb(md, "sheet", Vector3(sx * 0.4, 0.0, -0.26), Vector3(sx * 0.3, 0.7, 0.22), 0.013, 0.013, ALU, 6)
	NewModels6.hull(md, Vector3(0, 0.36, 0), Vector3(0.95, 0.74, 0.62))

static func _cooler(md: NewModels6.Model) -> void:
	var body := Color(0.22, 0.35, 0.5)
	NewModels6.rbox(md, "gloss", Vector3(0, 0.17, 0), Vector3(0.62, 0.34, 0.4), body, Basis.IDENTITY, 5.0, 12, 0.05)
	NewModels6.rbox(md, "gloss", Vector3(0, 0.355, 0), Vector3(0.64, 0.05, 0.42), Color(0.82, 0.82, 0.78), Basis.IDENTITY, 5.0, 12, 0.05)
	NewModels6.limb(md, "rubber", Vector3(-0.2, 0.38, 0), Vector3(0.2, 0.38, 0), 0.016, 0.016, Color(0.8, 0.8, 0.75), 6)
	for sx: float in [-1.0, 1.0]:
		NewModels6.box(md, "rust", Vector3(sx * 0.31, 0.33, -0.2), Vector3(0.05, 0.03, 0.02), Color(0.4, 0.2, 0.1))
	NewModels6.hull(md, Vector3(0, 0.19, 0), Vector3(0.64, 0.38, 0.42))

# ---------------------------------------------------------------- fire, wood, axe
static func _fire_ring(md: NewModels6.Model, lit: bool, lod: int) -> void:
	var n := 13 if lod == 0 else 9
	for k in n:
		var a := TAU * k / n + NewModels6.rnd(k, 1.0) * 0.1
		var r := 0.44 + (NewModels6.rnd(k, 2.0) - 0.5) * 0.06
		var sz := Vector3(0.1 + NewModels6.rnd(k, 3.0) * 0.05, 0.075 + NewModels6.rnd(k, 4.0) * 0.04, 0.09 + NewModels6.rnd(k, 5.0) * 0.04)
		NewModels6.ball(md, "stone", Vector3(cos(a) * r, sz.y * 0.55, sin(a) * r), sz, Color(0.46, 0.45, 0.42), 7, Basis(Vector3.UP, a + 0.3), 0.18)
	var ash := Color(0.2, 0.19, 0.18) if lit else Color(0.36, 0.35, 0.33)
	NewModels6.cyl(md, "rubber", Vector3(0, 0.0, 0), Vector3(0, 0.025, 0), 0.38, 0.36, 18, ash, 3, 0.15)
	for k in 4:
		var a2 := TAU * k / 4.0 + 0.4
		var c0 := Vector3(cos(a2) * 0.2, 0.06, sin(a2) * 0.2)
		NewModels6.limb(md, "wood", c0, c0 + Vector3(-cos(a2) * 0.28, 0.07 + 0.04 * (k % 2), -sin(a2) * 0.28), 0.04, 0.035, Color(0.1, 0.08, 0.06), 7, 0.1)
	if lit:
		var fl := md.sub("flame", Vector3(0, 0.1, 0))
		for k in 7:
			var a3 := TAU * k / 7.0
			var base := Vector3(cos(a3) * 0.1, 0.08, sin(a3) * 0.1)
			NewModels6.limb(fl, "flame", base, base + Vector3(-cos(a3) * 0.02, 0.28 + 0.12 * NewModels6.rnd(k, 6.0), -sin(a3) * 0.02), 0.07, 0.01, Color(1.0, 0.55, 0.12), 5)
		NewModels6.cyl(fl, "flame", Vector3(0, 0.06, 0), Vector3(0, 0.1, 0), 0.2, 0.15, 10, Color(1.0, 0.3, 0.05), 3, 0.0)

static func _firewood(md: NewModels6.Model, lod: int) -> void:
	var layers := [[5, 0.07, 0.06], [4, 0.065, 0.17], [3, 0.06, 0.27], [2, 0.06, 0.37]]
	var k := 0
	for ly in layers:
		var cnt: int = ly[0]
		for i in cnt:
			var x := (i - (cnt - 1) * 0.5) * 0.125
			var r: float = 0.052 + NewModels6.rnd(k, 7.0) * 0.022
			var ln := 0.46 + NewModels6.rnd(k, 8.0) * 0.08
			var yaw := (NewModels6.rnd(k, 9.0) - 0.5) * 0.14
			var c := Vector3(x, float(ly[2]) * 0.85 + 0.03, 0)
			var d := Basis(Vector3.UP, yaw) * Vector3(0, 0, ln * 0.5)
			NewModels6.cyl(md, "wood", c - d, c + d, r, r * 0.97, 8 if lod == 0 else 6, Color(0.43, 0.32, 0.22), 3, 0.12)
			NewModels6.cyl(md, "wood", c + d, c + d * 1.003, r * 0.9, r * 0.9, 8 if lod == 0 else 6, Color(0.62, 0.5, 0.35), 3, 0.05)
			k += 1
	NewModels6.hull(md, Vector3(0, 0.22, 0), Vector3(0.7, 0.44, 0.5))

static func _axe(md: NewModels6.Model) -> void:
	NewModels6.cyl(md, "wood", Vector3(0, 0.0, 0), Vector3(0, 0.32, 0), 0.17, 0.165, 14, Color(0.42, 0.31, 0.21), 3, 0.1)
	NewModels6.cyl(md, "wood", Vector3(0, 0.32, 0), Vector3(0, 0.322, 0), 0.16, 0.16, 14, Color(0.7, 0.58, 0.4), 3, 0.04)
	# the axe stands in the top, handle sloping back and up, the head buried
	var head := Vector3(0, 0.36, 0.0)
	NewModels6.limb(md, "wood", head + Vector3(0, 0.02, 0.0), head + Vector3(0, 0.62, -0.38), 0.022, 0.016, Color(0.55, 0.42, 0.28), 7, 0.06)
	NewModels6.box(md, "sheet", head + Vector3(0, 0.02, 0.02), Vector3(0.04, 0.14, 0.18), Color(0.34, 0.35, 0.37), 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, 0.6))
	NewModels6.hull(md, Vector3(0, 0.2, 0), Vector3(0.36, 0.4, 0.36))

# ---------------------------------------------------------------- bedding, basin, sketchbook, programme, bed, line
static func _bedding(md: NewModels6.Model) -> void:
	NewModels6.box(md, "paint", Vector3(0, 0.015, 0), Vector3(0.58, 0.03, 1.9), Color(0.55, 0.38, 0.12), 0.0, Color(-1, 0, 0))
	var bag := Color(0.2, 0.26, 0.17)
	NewModels6.shell(md, "cloth", Vector3(0, 0.1, -0.85), Vector3(0, 0.1, 0.85), [[0.0, 0.18, 0.09], [0.15, 0.3, 0.15], [0.6, 0.31, 0.17], [0.92, 0.25, 0.14], [1.0, 0.16, 0.07]], bag, Vector3.RIGHT, 2.4, 12, 0.06)
	NewModels6.ball(md, "cloth", Vector3(0, 0.14, 0.78), Vector3(0.2, 0.09, 0.14), Color(0.8, 0.76, 0.66), 8, Basis.IDENTITY, 0.04)     # a pillow
	for k in 5:
		NewModels6.box(md, "cloth", Vector3(0, 0.25, -0.55 + k * 0.2), Vector3(0.52, 0.006, 0.012), bag * 0.8)

static func _washbasin(md: NewModels6.Model) -> void:
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.11, 0.0), Vector2(0.14, 0.02), Vector2(0.19, 0.07), Vector2(0.2, 0.085), Vector2(0.195, 0.09), Vector2(0.185, 0.082), Vector2(0.12, 0.025), Vector2(0.0, 0.02)])
	NewModels6.put(md, "enamel", DroneParts.lathe(prof, 20), Transform3D.IDENTITY, Color(0.86, 0.85, 0.8), 0.04)
	NewModels6.cyl(md, "glass", Vector3(0, 0.055, 0), Vector3(0, 0.056, 0), 0.155, 0.155, 16, Color.WHITE, 3, 0.0)
	NewModels6.cyl(md, "enamel", Vector3(0.33, 0.0, 0.05), Vector3(0.33, 0.27, 0.05), 0.045, 0.04, 12, Color(0.2, 0.38, 0.6), 3, 0.0)
	NewModels6.cyl(md, "enamel", Vector3(0.33, 0.27, 0.05), Vector3(0.33, 0.3, 0.05), 0.022, 0.022, 8, Color(0.85, 0.85, 0.82), 3, 0.0)

static func _sketchbook(md: NewModels6.Model) -> void:
	var page := Color(0.9, 0.88, 0.8)
	NewModels6.box(md, "paper", Vector3(0, 0.006, 0), Vector3(0.44, 0.012, 0.3), Color(0.12, 0.11, 0.1))
	NewModels6.box(md, "paper", Vector3(-0.108, 0.016, 0.0), Vector3(0.21, 0.008, 0.28), page, 0.0, Color(-1, 0, 0), Basis(Vector3.BACK, 0.03))
	NewModels6.box(md, "paper", Vector3(0.108, 0.016, 0.0), Vector3(0.21, 0.008, 0.28), page, 0.0, Color(-1, 0, 0), Basis(Vector3.BACK, -0.03))
	# pencil sketches of the bus: a body, windows and two wheels, drawn as thin dark lines
	var ink := Color(0.22, 0.22, 0.24)
	var y := 0.0215
	var x0 := -0.19; var z0 := 0.0
	NewModels6.box(md, "paper", Vector3(x0 + 0.08, y, z0), Vector3(0.16, 0.001, 0.003), ink)
	NewModels6.box(md, "paper", Vector3(x0 + 0.08, y, z0 - 0.045), Vector3(0.16, 0.001, 0.003), ink)
	NewModels6.box(md, "paper", Vector3(x0, y, z0 - 0.022), Vector3(0.003, 0.001, 0.045), ink)
	NewModels6.box(md, "paper", Vector3(x0 + 0.16, y, z0 - 0.022), Vector3(0.003, 0.001, 0.045), ink)
	for k in 5:
		NewModels6.box(md, "paper", Vector3(x0 + 0.03 + k * 0.025, y, z0 - 0.024), Vector3(0.018, 0.001, 0.014), ink * 1.2)
	for wx: float in [0.04, 0.12]:
		NewModels6.cyl(md, "paper", Vector3(x0 + wx, y, z0 + 0.006), Vector3(x0 + wx, y + 0.001, z0 + 0.006), 0.012, 0.012, 10, ink, 3, 0.0)
	NewModels6.box(md, "paper", Vector3(0.11, y, 0.02), Vector3(0.14, 0.001, 0.003), ink, 0.1)
	NewModels6.box(md, "paper", Vector3(0.11, y, 0.06), Vector3(0.1, 0.001, 0.003), ink, -0.05)
	NewModels6.cyl(md, "wood", Vector3(0.19, 0.012, 0.1), Vector3(0.05, 0.015, 0.16), 0.004, 0.004, 6, Color(0.7, 0.55, 0.15), 3, 0.0)

static func _programme(md: NewModels6.Model, open: bool) -> void:
	var cream := Color(0.9, 0.86, 0.72)
	var ink := Color(0.12, 0.28, 0.2)
	if not open:
		NewModels6.box(md, "paper", Vector3(0, 0.003, 0), Vector3(0.15, 0.006, 0.21), cream, 0.1)
		NewModels6.box(md, "paper", Vector3(0, 0.0075, 0), Vector3(0.148, 0.003, 0.208), cream * 0.97, 0.1)
		NewModels6.text(md, "paper", "HALLOWAY", Vector3(0.0, 0.0092, 0.05), Vector3(0, 1, 0), 0.016, ink, Vector3(0, 0, 1), 0.0)
		NewModels6.text(md, "paper", "FESTIVAL", Vector3(0.0, 0.0092, 0.02), Vector3(0, 1, 0), 0.016, ink, Vector3(0, 0, 1), 0.0)
		NewModels6.box(md, "paper", Vector3(0, 0.0095, -0.05), Vector3(0.1, 0.0006, 0.07), ink.lerp(cream, 0.5))
		return
	for sx: float in [-1.0, 1.0]:
		NewModels6.box(md, "paper", Vector3(sx * 0.075, 0.004, 0), Vector3(0.15, 0.006, 0.21), cream, 0.0, Color(-1, 0, 0), Basis(Vector3.BACK, -sx * 0.04))
		for k in 7:
			NewModels6.box(md, "paper", Vector3(sx * 0.075, 0.0085, -0.08 + k * 0.025), Vector3(0.11 - NewModels6.rnd(k + sx, 3.0) * 0.04, 0.0006, 0.004), ink)
	NewModels6.text(md, "paper", "PROGRAMME", Vector3(-0.075, 0.0085, 0.075), Vector3(0, 1, 0), 0.014, ink, Vector3(0, 0, 1), 0.0)

static func _dog_bed(md: NewModels6.Model) -> void:
	var f := func(p: Vector3, _n: Vector3) -> Color:
		var stripe := fposmod(p.x * 7.0, 1.0) < 0.5 and fposmod(p.z * 7.0, 1.0) < 0.5
		var base := Color(0.34, 0.2, 0.18)
		return base.lerp(Color(0.5, 0.42, 0.3), 0.7 if stripe else 0.0)
	NewModels6.put_f(md, "cloth", DroneParts.sphere(1.0, 10), Transform3D(Basis.from_scale(Vector3(0.46, 0.065, 0.34)), Vector3(0, 0.06, 0)), f)
	NewModels6.ball(md, "cloth", Vector3(0.18, 0.1, -0.04), Vector3(0.2, 0.05, 0.14), Color(0.38, 0.3, 0.22), 8, Basis(Vector3.UP, 0.5), 0.08)   # a rolled corner

static func _clothes_line(md: NewModels6.Model) -> void:
	for sx: float in [-1.5, 1.5]:
		NewModels6.limb(md, "wood", Vector3(sx, 0.0, 0), Vector3(sx, 2.0, 0), 0.04, 0.032, Color(0.42, 0.35, 0.27), 7, 0.1)
		_rope(md, Vector3(sx, 1.95, 0), Vector3(sx * 1.3, 0.0, 0.8), 0.0)
		_peg(md, Vector3(sx * 1.3, 0.0, 0.8))
	_rope(md, Vector3(-1.5, 1.92, 0), Vector3(1.5, 1.92, 0), 0.18, 0.004, Color(0.7, 0.68, 0.6))
	# a work shirt, a towel and a few socks hung from pegs; the line sags 0.18 m in the middle
	var ly := func(x: float) -> float: return 1.92 - 0.18 * 4.0 * ((x + 1.5) / 3.0) * (1.0 - (x + 1.5) / 3.0)
	var x := -0.9
	var shirt := Color(0.3, 0.38, 0.5)
	NewModels6.sheet(md, "cloth", [Vector3(x - 0.2, ly.call(x), 0), Vector3(x + 0.2, ly.call(x), 0), Vector3(x + 0.2, ly.call(x) - 0.55, 0.005), Vector3(x - 0.2, ly.call(x) - 0.55, 0.005)], shirt, Vector3(0, 0, 1))
	NewModels6.sheet(md, "cloth", [Vector3(x - 0.2, ly.call(x), 0), Vector3(x - 0.38, ly.call(x) - 0.22, 0.01), Vector3(x - 0.3, ly.call(x) - 0.28, 0.01), Vector3(x - 0.2, ly.call(x) - 0.1, 0)], shirt * 0.95, Vector3(0, 0, 1))
	NewModels6.sheet(md, "cloth", [Vector3(x + 0.2, ly.call(x), 0), Vector3(x + 0.38, ly.call(x) - 0.22, 0.01), Vector3(x + 0.3, ly.call(x) - 0.28, 0.01), Vector3(x + 0.2, ly.call(x) - 0.1, 0)], shirt * 0.95, Vector3(0, 0, 1))
	var tx := 0.1
	NewModels6.sheet(md, "cloth", [Vector3(tx - 0.28, ly.call(tx), 0), Vector3(tx + 0.28, ly.call(tx), 0), Vector3(tx + 0.28, ly.call(tx) - 0.62, 0.006), Vector3(tx - 0.28, ly.call(tx) - 0.62, 0.006)], Color(0.62, 0.3, 0.2), Vector3(0, 0, 1))
	for k in 3:
		var sxx := 0.75 + k * 0.17
		NewModels6.sheet(md, "cloth", [Vector3(sxx - 0.04, ly.call(sxx), 0), Vector3(sxx + 0.04, ly.call(sxx), 0), Vector3(sxx + 0.035, ly.call(sxx) - 0.2, 0.004), Vector3(sxx - 0.035, ly.call(sxx) - 0.2, 0.004)], Color(0.55, 0.52, 0.45) * (0.8 + 0.1 * k), Vector3(0, 0, 1))
	for px: float in [x - 0.15, x + 0.15, tx - 0.2, tx + 0.2, 0.75, 0.92, 1.09]:
		NewModels6.box(md, "wood", Vector3(px, ly.call(px) + 0.005, 0), Vector3(0.012, 0.045, 0.014), Color(0.52, 0.4, 0.26))

# ---------------------------------------------------------------- priority 1 extras
static func _lead(md: NewModels6.Model) -> void:
	# a leather collar and a lead coiled beside it
	var lea := Color(0.34, 0.2, 0.1)
	var n := 16
	for k in n:
		var a0 := TAU * k / n; var a1 := TAU * (k + 1) / n
		NewModels6.limb(md, "leather", Vector3(cos(a0) * 0.09, 0.012, sin(a0) * 0.09 - 0.12), Vector3(cos(a1) * 0.09, 0.012, sin(a1) * 0.09 - 0.12), 0.012, 0.012, lea, 5, 0.06)
	NewModels6.box(md, "chrome", Vector3(0.09, 0.016, -0.12), Vector3(0.025, 0.012, 0.02), Color(0.7, 0.62, 0.3))
	NewModels6.cyl(md, "chrome", Vector3(-0.09, 0.02, -0.12), Vector3(-0.09, 0.026, -0.12), 0.02, 0.02, 8, Color(0.7, 0.62, 0.3), 3, 0.0)
	for ring in 3:
		for k in 14:
			var a0 := TAU * k / 14; var a1 := TAU * (k + 1) / 14
			var r := 0.08 - ring * 0.012
			NewModels6.limb(md, "rubber", Vector3(cos(a0) * r, 0.01 + ring * 0.011, sin(a0) * r + 0.1), Vector3(cos(a1) * r, 0.01 + ring * 0.011, sin(a1) * r + 0.1), 0.007, 0.007, Color(0.55, 0.22, 0.15), 4)
	NewModels6.limb(md, "rubber", Vector3(0.07, 0.02, 0.1), Vector3(0.2, 0.01, 0.2), 0.007, 0.007, Color(0.55, 0.22, 0.15), 4)

static func _mug(md: NewModels6.Model) -> void:
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.036, 0.0), Vector2(0.04, 0.006), Vector2(0.041, 0.085), Vector2(0.044, 0.09), Vector2(0.04, 0.092), Vector2(0.036, 0.086), Vector2(0.034, 0.01), Vector2(0.0, 0.008)])
	NewModels6.put(md, "enamel", DroneParts.lathe(prof, 16), Transform3D.IDENTITY, Color(0.78, 0.76, 0.68), 0.05)
	NewModels6.cyl(md, "enamel", Vector3(0, 0.07, 0), Vector3(0, 0.0705, 0), 0.034, 0.034, 14, Color(0.2, 0.12, 0.07), 3, 0.0)
	NewModels6.limb(md, "enamel", Vector3(0.04, 0.075, 0), Vector3(0.062, 0.05, 0), 0.007, 0.007, Color(0.78, 0.76, 0.68), 5)
	NewModels6.limb(md, "enamel", Vector3(0.062, 0.05, 0), Vector3(0.04, 0.02, 0), 0.007, 0.007, Color(0.78, 0.76, 0.68), 5)
	# a curl of steam as thin translucent ribbons
	var st := md.sub("steam", Vector3(0, 0.1, 0))
	for k in 3:
		for j in 5:
			var y := 0.1 + j * 0.035
			var x := sin(j * 1.4 + k * 2.0) * 0.012 + (k - 1) * 0.014
			NewModels6.box(st, "glass", Vector3(x, y, 0.0), Vector3(0.012 - j * 0.001, 0.034, 0.002), Color.WHITE)

static func _papers(md: NewModels6.Model) -> void:
	# a map of the valley (lakes, a road, a bus drawn in as a red mark), a letter, and a loose sheet
	var paper := Color(0.88, 0.85, 0.74)
	NewModels6.box(md, "paper", Vector3(0, 0.002, 0), Vector3(0.5, 0.004, 0.36), paper, 0.15)
	NewModels6.ball(md, "paper", Vector3(-0.1, 0.0045, 0.05), Vector3(0.07, 0.0006, 0.045), Color(0.55, 0.7, 0.8), 6)
	for k in 6:
		NewModels6.box(md, "paper", Vector3(-0.2 + k * 0.07, 0.0045, -0.08 + sin(k * 0.8) * 0.05), Vector3(0.08, 0.0006, 0.006), Color(0.5, 0.35, 0.2), 0.3 * sin(k))
	NewModels6.box(md, "paper", Vector3(0.12, 0.0046, 0.0), Vector3(0.02, 0.0007, 0.02), Color(0.7, 0.1, 0.08))
	NewModels6.box(md, "paper", Vector3(0.23, 0.007, 0.05), Vector3(0.18, 0.003, 0.25), Color(0.93, 0.92, 0.88), -0.3)
	for k in 8:
		NewModels6.box(md, "paper", Vector3(0.23 - 0.02, 0.0085, -0.04 + k * 0.025), Vector3(0.12 - NewModels6.rnd(k, 1.0) * 0.04, 0.0006, 0.004), Color(0.25, 0.25, 0.3), -0.3)
	NewModels6.box(md, "paper", Vector3(-0.28, 0.006, -0.1), Vector3(0.2, 0.003, 0.28), Color(0.9, 0.88, 0.8), 0.5)

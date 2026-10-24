class_name NewModels7Interior
extends RefCounted
## Story batch 9 (models9), part B2: the inside of the abandoned cabin, where a police officer once took shelter and a hiker recently
## stayed: an iron bed, table, two chairs, a pot-belly stove with a kettle, a shelf with tins and an old radio, a 1980s police
## radio set and handheld, the open case file, a wall calendar, a uniform on a hook, wet boots, a storm lantern, a child's drawing,
## a folded valley map and the hiker's left-behind gear; plus two ready-made arrangements (`cabin_interior_set_a` for the 8 x 6 m
## cabin, `cabin_interior_variant_a` a smaller second room with its own walls). No colliders (the brief). Metres, +Z front, origin at
## the base (wall things: at the wall, hanging from y = 0). Named: `door` and `flame` (stove), `steam` (kettle).

const NAMES: Array[String] = [
	"cabin_bed_a", "cabin_bed_a_stripped", "cabin_table_a", "cabin_chair_a", "cabin_chair_b", "cabin_stove_a", "cabin_stove_a_lit", "cabin_shelf_a",
	"cabin_radio_a", "cabin_radio_handheld_a", "cabin_case_file_a", "cabin_calendar_a", "cabin_uniform_a", "cabin_boots_a", "cabin_lantern_a",
	"cabin_lantern_a_off", "cabin_kettle_a", "cabin_drawing_a", "cabin_map_a", "cabin_hiker_gear_a", "cabin_interior_set_a", "cabin_interior_variant_a",
]

const OAK := Color(0.33, 0.24, 0.15)
const IRON := Color(0.09, 0.09, 0.1)
const PAPER := Color(0.88, 0.84, 0.7)
const INK := Color(0.1, 0.08, 0.06)

static func build(name: String, md: NewModels6.Model, lod: int) -> bool:
	match name:
		"cabin_bed_a": _bed(md, false, lod)
		"cabin_bed_a_stripped": _bed(md, true, lod)
		"cabin_table_a": _table(md)
		"cabin_chair_a": _chair(md, 0)
		"cabin_chair_b": _chair(md, 1)
		"cabin_stove_a": _stove(md, false)
		"cabin_stove_a_lit": _stove(md, true)
		"cabin_shelf_a": _shelf(md)
		"cabin_radio_a": _radio(md)
		"cabin_radio_handheld_a": _handheld(md)
		"cabin_case_file_a": _case_file(md)
		"cabin_calendar_a": _calendar(md); _raise(md, 0.34)
		"cabin_uniform_a": _uniform(md); _raise(md, 0.76)
		"cabin_boots_a": _boots(md)
		"cabin_lantern_a": NewModels7.merge(md, NewModels6.build("storm_lantern_a", 0), Transform3D.IDENTITY)
		"cabin_lantern_a_off": NewModels7.merge(md, NewModels6.build("storm_lantern_a_off", 0), Transform3D.IDENTITY)
		"cabin_kettle_a": _kettle(md)
		"cabin_drawing_a": _drawing(md); _raise(md, 0.3)
		"cabin_map_a": _map(md)
		"cabin_hiker_gear_a": _hiker_gear(md)
		"cabin_interior_set_a": _set_a(md, lod)
		"cabin_interior_variant_a": _variant(md, lod)
		_: return false
	return true

static func _put(md: NewModels6.Model, name: String, xf: Transform3D, lod := 1) -> void:
	NewModels7.merge(md, NewModels6.build(name, lod), xf)

# ================================================================== furniture
static func _bed(md: NewModels6.Model, stripped: bool, lod: int) -> void:
	# an iron bed 1.0 x 2.0 m: tall head, low foot, side rails at 0.4 m, a wire-spring base; made it has a ticking mattress and a folded wool blanket
	var iron := Color(0.12, 0.11, 0.1)
	var w := 0.5
	for sx: float in [-1.0, 1.0]:
		NewModels6.limb(md, "rust", Vector3(sx * w, 0.0, -0.95), Vector3(sx * w, 1.1, -0.95), 0.022, 0.02, iron, 8)
		NewModels6.limb(md, "rust", Vector3(sx * w, 0.0, 0.95), Vector3(sx * w, 0.72, 0.95), 0.02, 0.018, iron, 8)
		NewModels6.ball(md, "chrome", Vector3(sx * w, 1.12, -0.95), Vector3(0.03, 0.03, 0.03), Color(0.65, 0.55, 0.3), 8)
		NewModels6.ball(md, "chrome", Vector3(sx * w, 0.74, 0.95), Vector3(0.026, 0.026, 0.026), Color(0.65, 0.55, 0.3), 8)
		NewModels6.limb(md, "rust", Vector3(sx * w, 0.4, -0.95), Vector3(sx * w, 0.4, 0.95), 0.016, 0.016, iron, 6)
	for y in [0.55, 0.85, 1.05]:
		NewModels6.limb(md, "rust", Vector3(-w, y, -0.95), Vector3(w, y, -0.95), 0.012, 0.012, iron, 6)
	for k in 6:
		NewModels6.limb(md, "rust", Vector3(-w + k * 0.2, 0.4, -0.95), Vector3(-w + k * 0.2, 1.0, -0.95), 0.009, 0.009, iron, 4)
	NewModels6.limb(md, "rust", Vector3(-w, 0.62, 0.95), Vector3(w, 0.62, 0.95), 0.012, 0.012, iron, 6)
	# the wire springs
	var nz := 20 if lod == 0 else 10
	for k in nz + 1:
		var z := -0.9 + k * 1.8 / nz
		NewModels6.limb(md, "steel", Vector3(-w + 0.02, 0.38, z), Vector3(w - 0.02, 0.38, z), 0.004, 0.004, Color(0.5, 0.5, 0.52), 3)
	for k in 7:
		NewModels6.limb(md, "steel", Vector3(-w + 0.02 + k * (2.0 * w - 0.04) / 6.0, 0.385, -0.9), Vector3(-w + 0.02 + k * (2.0 * w - 0.04) / 6.0, 0.385, 0.9), 0.004, 0.004, Color(0.5, 0.5, 0.52), 3)
	if stripped:
		NewModels6.rbox(md, "canvas", Vector3(0.15, 0.4, 0.55), Vector3(0.7, 0.1, 0.5), Color(0.55, 0.5, 0.4), Basis(Vector3.UP, 0.2), 3.5, 8, 0.04)       # the rolled mattress left at the foot
		return
	NewModels6.rbox(md, "canvas", Vector3(0, 0.49, 0.0), Vector3(0.96, 0.14, 1.9), Color(0.72, 0.7, 0.62), Basis.IDENTITY, 3.4, 14, 0.03)
	for k in 12:
		NewModels6.box(md, "canvas", Vector3(-0.45 + k * 0.082, 0.562, 0.0), Vector3(0.03, 0.002, 1.84), Color(0.3, 0.38, 0.5))
	NewModels6.rbox(md, "cloth", Vector3(0.0, 0.58, 0.55), Vector3(0.85, 0.1, 0.5), Color(0.35, 0.38, 0.24), Basis.IDENTITY, 3.2, 12, 0.05)
	for k in 3:
		NewModels6.box(md, "cloth", Vector3(0.0, 0.633, 0.35 + k * 0.17), Vector3(0.84, 0.004, 0.025), Color(0.5, 0.2, 0.12))

static func _table(md: NewModels6.Model) -> void:
	# a small kitchen table 1.1 x 0.7 x 0.75 m with a drawer, turned legs and a scrubbed, stained top
	var t := NewModels7.W(Color(0.46, 0.38, 0.28), 0.75)
	NewModels6.box(md, "wood", Vector3(0, 0.74, 0), Vector3(1.1, 0.04, 0.7), t, 0.0, NewModels7.W(Color(0.5, 0.42, 0.31), 0.75))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			NewModels6.limb(md, "wood", Vector3(sx * 0.5, 0.0, sz * 0.3), Vector3(sx * 0.5, 0.72, sz * 0.3), 0.025, 0.035, NewModels7.W(Color(0.4, 0.32, 0.22), 1.0), 8)
	NewModels6.box(md, "wood", Vector3(0, 0.67, 0.32), Vector3(0.9, 0.12, 0.02), t * 0.9)
	NewModels6.box(md, "wood", Vector3(0.0, 0.64, 0.335), Vector3(0.42, 0.1, 0.012), NewModels7.W(Color(0.4, 0.33, 0.23), 0.75))
	NewModels6.ball(md, "chrome", Vector3(0.0, 0.64, 0.348), Vector3(0.016, 0.016, 0.012), Color(0.6, 0.5, 0.28), 8)
	NewModels6.ball(md, "water", Vector3(-0.3, 0.762, -0.1), Vector3(0.05, 0.001, 0.05), Color.WHITE, 12)      # the ring of a cup

static func _chair(md: NewModels6.Model, v: int) -> void:
	# a wooden chair, seat at 0.45 m: variant 0 a ladder back, variant 1 a spindle back
	var wcol := NewModels7.W(Color(0.4, 0.3, 0.2) * (1.0 if v == 0 else 1.15), 1.0)
	NewModels6.box(md, "wood", Vector3(0, 0.45, 0), Vector3(0.42, 0.035, 0.4), NewModels7.W(Color(0.44, 0.34, 0.23), 0.75))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			NewModels6.limb(md, "wood", Vector3(sx * 0.19, 0.0, sz * 0.18), Vector3(sx * 0.19, 0.44, sz * 0.18), 0.017, 0.022, wcol, 6)
	for sx: float in [-1.0, 1.0]:
		NewModels6.limb(md, "wood", Vector3(sx * 0.19, 0.46, -0.18), Vector3(sx * 0.19, 0.95, -0.2), 0.018, 0.016, wcol, 6)
	if v == 0:
		for k in 3:
			NewModels6.box(md, "wood", Vector3(0, 0.62 + k * 0.12, -0.19 - 0.0), Vector3(0.36, 0.07, 0.018), NewModels7.W(Color(0.42, 0.32, 0.22), 0.75), 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, -0.06))
	else:
		for k in 6:
			NewModels6.limb(md, "wood", Vector3(-0.15 + k * 0.06, 0.48, -0.18), Vector3(-0.15 + k * 0.06, 0.9, -0.195), 0.01, 0.009, wcol, 5)
		NewModels6.box(md, "wood", Vector3(0, 0.92, -0.2), Vector3(0.4, 0.05, 0.025), wcol)
	NewModels6.limb(md, "wood", Vector3(-0.19, 0.2, 0.0), Vector3(0.19, 0.2, 0.0), 0.01, 0.01, wcol, 4)

static func _stove(md: NewModels6.Model, lit: bool) -> void:
	# a small cast-iron pot-belly stove: 0.5 m across, 0.75 m tall, on four feet, a front door with a mica window, a flue pipe to 2.0 m with an elbow
	var cast := Color(0.11, 0.1, 0.1)
	var prof := PackedVector2Array([Vector2(0.0, 0.16), Vector2(0.17, 0.16), Vector2(0.23, 0.22), Vector2(0.25, 0.4), Vector2(0.24, 0.6), Vector2(0.2, 0.72), Vector2(0.12, 0.76), Vector2(0.0, 0.76)])
	NewModels6.put(md, "rust", DroneParts.lathe(prof, 24), Transform3D.IDENTITY, cast, 0.03)
	for k in 4:
		var a := TAU * k / 4.0 + 0.78
		NewModels6.limb(md, "rust", Vector3(cos(a) * 0.15, 0.17, sin(a) * 0.15), Vector3(cos(a) * 0.19, 0.0, sin(a) * 0.19), 0.025, 0.02, cast, 6)
	NewModels6.cyl(md, "rust", Vector3(0, 0.76, 0), Vector3(0, 0.82, 0), 0.09, 0.07, 12, cast * 1.1, 3, 0.03)
	NewModels6.limb(md, "rust", Vector3(0, 0.82, 0), Vector3(0, 1.5, 0), 0.055, 0.055, Color(0.18, 0.1, 0.07), 12, 0.05)
	NewModels6.limb(md, "rust", Vector3(0, 1.5, 0), Vector3(-0.3, 1.75, -0.25), 0.055, 0.055, Color(0.18, 0.1, 0.07), 12, 0.05)
	NewModels6.limb(md, "rust", Vector3(-0.3, 1.75, -0.25), Vector3(-0.3, 2.1, -0.25), 0.055, 0.055, Color(0.18, 0.1, 0.07), 12, 0.05)
	var door := md.sub("door", Vector3(-0.1, 0.42, 0.24))
	NewModels6.box(door, "rust", Vector3(0, 0.42, 0.245), Vector3(0.2, 0.22, 0.02), cast * 1.15)
	NewModels6.box(door, "warm" if lit else "glass", Vector3(0, 0.42, 0.258), Vector3(0.1, 0.1, 0.004), Color.WHITE)
	NewModels6.box(door, "chrome", Vector3(0.09, 0.42, 0.262), Vector3(0.02, 0.07, 0.01), Color(0.4, 0.38, 0.35))
	if lit:
		var fl := md.sub("flame", Vector3(0, 0.3, 0.1))
		NewModels6.put(fl, "flame", DroneParts.lathe(PackedVector2Array([Vector2(0.0, 0.26), Vector2(0.03, 0.28), Vector2(0.04, 0.34), Vector2(0.02, 0.44), Vector2(0.0, 0.5)]), 8), Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.1)), Color.WHITE, 0.0)
	NewModels6.cyl(md, "rust", Vector3(0, 0.0, 0.0), Vector3(0, 0.02, 0.0), 0.0, 0.0, 3, cast, 3, 0.0)

static func _shelf(md: NewModels6.Model) -> void:
	# a wall shelf 1.2 m long with two brackets; on it tins, a candle stub in a saucer and an old wooden-cased tube radio
	NewModels6.box(md, "wood", Vector3(0, 0.0, 0.11), Vector3(1.2, 0.03, 0.22), NewModels7.W(Color(0.42, 0.33, 0.23), 0.75))
	for sx: float in [-1.0, 1.0]:
		NewModels6.box(md, "rust", Vector3(sx * 0.5, -0.07, 0.02), Vector3(0.02, 0.14, 0.03), IRON)
		NewModels6.limb(md, "rust", Vector3(sx * 0.5, -0.12, 0.03), Vector3(sx * 0.5, -0.01, 0.2), 0.01, 0.01, IRON, 4)
	for k in 4:
		NewModels6.cyl(md, "sheet", Vector3(-0.5 + k * 0.1, 0.015, 0.1), Vector3(-0.5 + k * 0.1, 0.1 + 0.02 * (k % 2), 0.1), 0.035, 0.035, 12, [Color(0.6, 0.25, 0.18), Color(0.55, 0.55, 0.5), Color(0.3, 0.4, 0.28), Color(0.68, 0.6, 0.32)][k], 3, 0.05)
	NewModels6.cyl(md, "enamel", Vector3(0.0, 0.015, 0.1), Vector3(0.0, 0.025, 0.1), 0.05, 0.045, 12, Color(0.8, 0.8, 0.78), 3, 0.02)
	NewModels6.cyl(md, "paper", Vector3(0.0, 0.025, 0.1), Vector3(0.0, 0.08, 0.1), 0.014, 0.012, 8, Color(0.85, 0.82, 0.7), 3, 0.03)
	NewModels6.rbox(md, "wood", Vector3(0.38, 0.12, 0.11), Vector3(0.3, 0.2, 0.15), NewModels7.W(Color(0.3, 0.2, 0.12), 1.0), Basis.IDENTITY, 5.0, 8, 0.04)
	NewModels6.box(md, "cloth", Vector3(0.355, 0.12, 0.188), Vector3(0.16, 0.12, 0.006), Color(0.7, 0.62, 0.45))
	NewModels6.cyl(md, "chrome", Vector3(0.46, 0.14, 0.186), Vector3(0.46, 0.14, 0.2), 0.03, 0.03, 12, Color(0.55, 0.5, 0.35), 3, 0.0)
	NewModels6.cyl(md, "rubber", Vector3(0.46, 0.09, 0.186), Vector3(0.46, 0.09, 0.205), 0.012, 0.012, 8, Color(0.05, 0.04, 0.04), 3, 0.0)

# ================================================================== things on the table, the walls and the floor
static func _radio(md: NewModels6.Model) -> void:
	# a 1980s police base radio set: a grey enamel box 0.34 x 0.14 x 0.24 m with a speaker grille, a tuning dial and three knobs, a power lamp, and a coiled-cord handset on its cradle
	var grey := Color(0.5, 0.52, 0.5)
	NewModels6.rbox(md, "enamel", Vector3(0, 0.07, 0), Vector3(0.34, 0.14, 0.24), grey, Basis.IDENTITY, 4.0, 8, 0.04)
	NewModels6.box(md, "paper", Vector3(-0.07, 0.085, 0.121), Vector3(0.15, 0.06, 0.003), Color(0.82, 0.78, 0.6))
	NewModels6.text(md, "paper", "HALLOWAY PROV. POLICE", Vector3(-0.07, 0.12, 0.123), Vector3(0, 0, 1), 0.008, INK, Vector3.UP, 0.0)
	for k in 5:
		NewModels6.limb(md, "rust", Vector3(-0.14 + k * 0.014, 0.035, 0.121), Vector3(-0.14 + k * 0.014, 0.066, 0.121), 0.002, 0.002, Color(0.2, 0.2, 0.2), 3)
	for k in 3:
		NewModels6.cyl(md, "rubber", Vector3(0.05 + k * 0.045, 0.08, 0.12), Vector3(0.05 + k * 0.045, 0.08, 0.14), 0.016, 0.014, 12, Color(0.06, 0.06, 0.06), 3, 0.0)
	NewModels6.ball(md, "lamp_red", Vector3(0.13, 0.12, 0.122), Vector3(0.007, 0.007, 0.004), Color.WHITE, 6)
	for k in 8:
		NewModels6.box(md, "rust", Vector3(-0.09 + k * 0.012, 0.142, -0.02), Vector3(0.003, 0.002, 0.1), Color(0.18, 0.18, 0.18))
	# the cradle with its handset (black bakelite) and the coiled cord
	NewModels6.box(md, "rust", Vector3(0.19, 0.1, 0.0), Vector3(0.03, 0.12, 0.08), Color(0.12, 0.12, 0.12))
	NewModels6.rbox(md, "rubber", Vector3(0.215, 0.14, 0.0), Vector3(0.05, 0.05, 0.19), Color(0.06, 0.06, 0.07), Basis.IDENTITY, 4.0, 8, 0.04)
	NewModels6.cyl(md, "rubber", Vector3(0.215, 0.14, 0.1), Vector3(0.215, 0.14, 0.115), 0.026, 0.026, 10, Color(0.08, 0.08, 0.08), 3, 0.0)
	var prev := Vector3(0.2, 0.08, -0.03)
	for k in range(1, 41):
		var t := float(k) / 40.0
		var p := Vector3(0.2 + 0.06 * t + 0.01 * sin(k * 1.2), 0.08 - 0.04 * t + 0.012 * cos(k * 1.2), -0.03 - 0.2 * t)
		NewModels6.limb(md, "rubber", prev, p, 0.0035, 0.0035, Color(0.07, 0.07, 0.08), 3)
		prev = p
	NewModels6.limb(md, "rust", Vector3(-0.1, 0.14, -0.1), Vector3(-0.1, 0.3, -0.1), 0.004, 0.004, Color(0.3, 0.3, 0.32), 4)

static func _handheld(md: NewModels6.Model) -> void:
	# a handheld police set: 0.07 x 0.18 x 0.04 m, a stub aerial, a push-to-talk bar and a belt clip
	NewModels6.rbox(md, "rubber", Vector3(0, 0.09, 0), Vector3(0.07, 0.18, 0.04), Color(0.08, 0.08, 0.09), Basis.IDENTITY, 4.0, 8, 0.03)
	NewModels6.limb(md, "rubber", Vector3(0.02, 0.18, 0), Vector3(0.02, 0.33, 0), 0.006, 0.004, Color(0.07, 0.07, 0.07), 6)
	NewModels6.box(md, "rubber", Vector3(-0.045, 0.11, 0.0), Vector3(0.012, 0.06, 0.03), Color(0.12, 0.12, 0.12))
	for k in 4:
		NewModels6.box(md, "rust", Vector3(-0.012, 0.13 + k * 0.012, 0.021), Vector3(0.036, 0.002, 0.002), Color(0.3, 0.3, 0.3))
	NewModels6.box(md, "rust", Vector3(0.0, 0.06, -0.025), Vector3(0.035, 0.07, 0.006), Color(0.25, 0.25, 0.27))
	NewModels6.ball(md, "lamp_red", Vector3(0.02, 0.165, 0.021), Vector3(0.004, 0.004, 0.003), Color.WHITE, 5)

static func _case_file(md: NewModels6.Model) -> void:
	# an open manila case folder, 0.24 x 0.31 m, with loose typed sheets, a folded map, a clipped photograph and a paper clip
	var manila := Color(0.7, 0.58, 0.36)
	for sx: float in [-1.0, 1.0]:
		NewModels6.box(md, "paper", Vector3(sx * 0.12, 0.002, 0), Vector3(0.24, 0.004, 0.31), manila * (0.95 if sx < 0.0 else 1.0))
	NewModels6.box(md, "paper", Vector3(-0.123, 0.0045, 0.01), Vector3(0.026, 0.006, 0.31), manila * 0.85)
	for k in 4:
		var bas := Basis(Vector3.UP, -0.1 + k * 0.07)
		NewModels6.box(md, "paper", Vector3(0.1 - k * 0.012, 0.006 + k * 0.0012, 0.0), Vector3(0.2, 0.001, 0.28), PAPER * (1.0 - 0.03 * k), 0.0, Color(-1, 0, 0), bas)
	for l in 13:
		NewModels6.box(md, "paper", Vector3(0.1, 0.0125, -0.115 + l * 0.0185), Vector3(0.15 - 0.04 * NewModels6.rnd(l, 21.0), 0.0006, 0.0025), Color(0.15, 0.14, 0.16))
	NewModels6.box(md, "paper", Vector3(0.1, 0.0125, 0.15), Vector3(0.11, 0.0006, 0.004), Color(0.5, 0.1, 0.1))
	NewModels6.box(md, "paper", Vector3(-0.1, 0.0075, 0.03), Vector3(0.1, 0.002, 0.14), Color(0.8, 0.77, 0.66), 0.0, Color(-1, 0, 0), Basis(Vector3.UP, 0.05))
	NewModels6.limb(md, "paper", Vector3(-0.14, 0.0095, -0.03), Vector3(-0.06, 0.0095, 0.09), 0.0012, 0.0012, Color(0.5, 0.3, 0.2), 3)
	NewModels6.box(md, "paper", Vector3(-0.09, 0.0095, -0.09), Vector3(0.075, 0.003, 0.095), Color(0.9, 0.9, 0.88), 0.0, Color(-1, 0, 0), Basis(Vector3.UP, -0.08))      # the photograph
	NewModels6.box(md, "paper", Vector3(-0.09, 0.0115, -0.09), Vector3(0.062, 0.0008, 0.08), Color(0.36, 0.36, 0.38), 0.0, Color(-1, 0, 0), Basis(Vector3.UP, -0.08))
	NewModels6.ball(md, "paper", Vector3(-0.09, 0.0122, -0.082), Vector3(0.012, 0.0006, 0.016), Color(0.62, 0.6, 0.58), 8)
	NewModels6.ball(md, "paper", Vector3(-0.09, 0.0122, -0.108), Vector3(0.018, 0.0006, 0.02), Color(0.5, 0.5, 0.52), 8)
	NewModels6.limb(md, "steel", Vector3(-0.12, 0.013, -0.12), Vector3(-0.12, 0.013, -0.075), 0.001, 0.001, Color(0.6, 0.6, 0.62), 3)

static func _calendar(md: NewModels6.Model) -> void:
	# a wall calendar 0.22 x 0.34 m, hung from a nail: a lake picture above, NOVEMBER 1984 and a grid of days with one date crossed in red
	NewModels6.box(md, "paper", Vector3(0, -0.17, 0.004), Vector3(0.22, 0.34, 0.006), Color(0.82, 0.8, 0.7))
	NewModels6.box(md, "paper", Vector3(0, -0.07, 0.0085), Vector3(0.19, 0.12, 0.002), Color(0.36, 0.46, 0.5))
	NewModels6.box(md, "paper", Vector3(0, -0.095, 0.0098), Vector3(0.19, 0.05, 0.001), Color(0.25, 0.33, 0.28))
	NewModels6.ball(md, "paper", Vector3(0.05, -0.04, 0.0105), Vector3(0.012, 0.012, 0.0006), Color(0.9, 0.78, 0.4), 8, Basis(Vector3.RIGHT, PI * 0.5))
	NewModels6.text(md, "paper", "NOVEMBER 1984", Vector3(0, -0.168, 0.0105), Vector3(0, 0, 1), 0.012, INK, Vector3.UP, 0.0)
	for r in 6:
		NewModels6.box(md, "paper", Vector3(0, -0.19 - r * 0.021, 0.0105), Vector3(0.19, 0.0006, 0.0008), Color(0.4, 0.4, 0.4))
	for c in 8:
		NewModels6.box(md, "paper", Vector3(-0.095 + c * 0.0272, -0.255, 0.0105), Vector3(0.0008, 0.13, 0.0008), Color(0.4, 0.4, 0.4))
	NewModels6.limb(md, "paper", Vector3(0.0, -0.236, 0.011), Vector3(0.025, -0.255, 0.011), 0.0014, 0.0014, Color(0.6, 0.1, 0.08), 3)
	NewModels6.limb(md, "paper", Vector3(0.0, -0.255, 0.011), Vector3(0.025, -0.236, 0.011), 0.0014, 0.0014, Color(0.6, 0.1, 0.08), 3)
	NewModels6.cyl(md, "rust", Vector3(0, 0.0, 0.0), Vector3(0, 0.0, 0.02), 0.004, 0.004, 6, IRON, 3, 0.0)

static func _uniform(md: NewModels6.Model) -> void:
	# a hook board 0.6 m long with brass hooks; on it a dark blue 1980s tunic with brass buttons, a peaked cap on the next hook (all fictional, no badge)
	NewModels6.box(md, "wood", Vector3(0, 0, 0.012), Vector3(0.6, 0.1, 0.024), NewModels7.W(Color(0.4, 0.3, 0.2), 0.75))
	for k in 3:
		NewModels6.limb(md, "chrome", Vector3(-0.2 + k * 0.2, 0.0, 0.025), Vector3(-0.2 + k * 0.2, 0.0, 0.075), 0.007, 0.007, Color(0.7, 0.55, 0.25), 6)
		NewModels6.limb(md, "chrome", Vector3(-0.2 + k * 0.2, 0.0, 0.075), Vector3(-0.2 + k * 0.2, 0.035, 0.09), 0.007, 0.006, Color(0.7, 0.55, 0.25), 6)
	var blue := Color(0.08, 0.1, 0.19)
	var secs := [[0.0, 0.2, 0.06], [0.3, 0.21, 0.065], [0.7, 0.19, 0.06], [1.0, 0.16, 0.045]]
	NewModels6.shell(md, "cloth", Vector3(-0.2, -0.75, 0.115), Vector3(-0.2, -0.05, 0.1), secs, blue, Vector3.RIGHT, 2.4, 14, 0.06)
	for sx: float in [-1.0, 1.0]:
		NewModels6.limb(md, "cloth", Vector3(-0.2 + sx * 0.18, -0.12, 0.1), Vector3(-0.2 + sx * 0.22, -0.65, 0.12), 0.05, 0.04, blue * 0.95, 8, 0.05)
	for k in 5:
		NewModels6.ball(md, "chrome", Vector3(-0.2, -0.2 - k * 0.1, 0.18), Vector3(0.012, 0.012, 0.006), Color(0.7, 0.55, 0.25), 6)
	NewModels6.box(md, "cloth", Vector3(-0.2, -0.17, 0.176), Vector3(0.05, 0.016, 0.008), Color(0.85, 0.85, 0.82))
	NewModels6.cyl(md, "cloth", Vector3(0.2, -0.1, 0.12), Vector3(0.2, -0.04, 0.12), 0.1, 0.095, 14, blue, 3, 0.04)
	NewModels6.ball(md, "cloth", Vector3(0.2, -0.04, 0.12), Vector3(0.105, 0.03, 0.105), blue * 1.05, 10)
	NewModels6.box(md, "leather", Vector3(0.2, -0.11, 0.2), Vector3(0.17, 0.006, 0.08), Color(0.03, 0.03, 0.04), 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, 0.3))

static func _boots(md: NewModels6.Model) -> void:
	# a pair of wet leather boots standing by the door, one tipped over the other's toe, a small puddle round them
	var leather := Color(0.16, 0.1, 0.07)
	for k in 2:
		var o := Vector3(-0.1 + k * 0.22, 0.0, 0.0)
		var yaw := 0.2 - k * 0.5
		var bas := Basis(Vector3.UP, yaw)
		NewModels6.rbox(md, "rubber", o + bas * Vector3(0, 0.02, 0.03), Vector3(0.1, 0.04, 0.3), Color(0.05, 0.045, 0.04), bas, 5.0, 8)
		NewModels6.rbox(md, "leather", o + bas * Vector3(0, 0.07, 0.07), Vector3(0.095, 0.07, 0.24), leather, bas, 5.0, 10, 0.03)
		NewModels6.ball(md, "leather", o + bas * Vector3(0, 0.07, 0.17), Vector3(0.045, 0.04, 0.05), leather * 0.8, 8, bas)
		NewModels6.limb(md, "leather", o + bas * Vector3(0, 0.07, -0.03), o + bas * Vector3(0, 0.27, -0.045), 0.056, 0.06, leather * 1.05, 12, 0.03)
		NewModels6.cyl(md, "cloth", o + bas * Vector3(0, 0.26, -0.045), o + bas * Vector3(0, 0.285, -0.045), 0.062, 0.06, 12, Color(0.3, 0.26, 0.2), 3, 0.03)
		for j in 5:
			NewModels6.box(md, "cloth", o + bas * Vector3(0, 0.11 + j * 0.03, 0.085 - j * 0.02), Vector3(0.07, 0.004, 0.014), Color(0.75, 0.7, 0.55), 0.0, Color(-1, 0, 0), bas)
	NewModels6.ball(md, "water", Vector3(0.02, 0.002, 0.0), Vector3(0.2, 0.0015, 0.16), Color.WHITE, 16)
	NewModels6.ball(md, "mud", Vector3(-0.12, 0.004, 0.14), Vector3(0.04, 0.003, 0.03), Color(0.2, 0.14, 0.09), 8)

static func _kettle(md: NewModels6.Model) -> void:
	# an old enamel kettle: cream with a dark rim and chipped base, 0.2 m across, a bent handle, a long spout and a lid knob; steam is its own node
	var cream := Color(0.78, 0.74, 0.6)
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.1, 0.0), Vector2(0.118, 0.02), Vector2(0.12, 0.08), Vector2(0.105, 0.16), Vector2(0.075, 0.175), Vector2(0.0, 0.18)])
	NewModels6.put(md, "enamel", DroneParts.lathe(prof, 20), Transform3D.IDENTITY, cream, 0.03)
	NewModels6.cyl(md, "enamel", Vector3(0, 0.0, 0), Vector3(0, 0.01, 0), 0.105, 0.108, 20, Color(0.1, 0.1, 0.12), 3, 0.0)
	NewModels6.limb(md, "enamel", Vector3(0.1, 0.06, 0.0), Vector3(0.2, 0.14, 0.0), 0.022, 0.012, cream * 0.95, 8)
	NewModels6.ball(md, "enamel", Vector3(0, 0.185, 0), Vector3(0.016, 0.016, 0.016), Color(0.12, 0.12, 0.14), 8)
	var prev := Vector3(-0.11, 0.14, 0.0)
	for k in range(1, 11):
		var a := PI * float(k) / 10.0
		var p := Vector3(-cos(a) * 0.11, 0.14 + sin(a) * 0.12, 0.0)
		NewModels6.limb(md, "rust", prev, p, 0.0055, 0.0055, Color(0.12, 0.12, 0.13), 4)
		prev = p
	var st := md.sub("steam", Vector3(0.2, 0.15, 0.0))
	NewModels6.put(st, "steam", DroneParts.lathe(PackedVector2Array([Vector2(0.012, 0.0), Vector2(0.022, 0.12), Vector2(0.04, 0.26), Vector2(0.065, 0.42), Vector2(0.09, 0.58), Vector2(0.0, 0.6)]), 12), Transform3D(Basis(Vector3.BACK, -0.25), Vector3(0.2, 0.15, 0.0)), Color.WHITE, 0.0)

static func _drawing(md: NewModels6.Model) -> void:
	# a child's crayon drawing of a funnel, a lake and a house, pinned flat to the wall (0.21 x 0.297 m); it is a sad little picture, not a scary one
	NewModels6.box(md, "paper", Vector3(0, -0.15, 0.002), Vector3(0.21, 0.297, 0.003), PAPER * 1.04)
	for k in 6:
		var t := float(k) / 5.0
		var w := lerpf(0.06, 0.008, t)
		NewModels6.limb(md, "paper", Vector3(-w, -0.05 - t * 0.12, 0.0045), Vector3(w, -0.058 - t * 0.12, 0.0045), 0.0035, 0.0035, Color(0.28, 0.28, 0.3), 4)
	NewModels6.ball(md, "paper", Vector3(0.07, -0.04, 0.0045), Vector3(0.017, 0.017, 0.0006), Color(0.95, 0.8, 0.12), 8, Basis(Vector3.RIGHT, PI * 0.5))
	for k in 4:
		var prev := Vector3(-0.09, -0.21 - k * 0.022, 0.0045)
		for j in range(1, 8):
			var p := Vector3(-0.09 + j * 0.026, -0.21 - k * 0.022 + 0.005 * sin(j * 1.7 + k), 0.0045)
			NewModels6.limb(md, "paper", prev, p, 0.0023, 0.0023, Color(0.2, 0.4, 0.8), 3)
			prev = p
	NewModels6.box(md, "paper", Vector3(0.06, -0.19, 0.0045), Vector3(0.04, 0.032, 0.0006), Color(0.75, 0.2, 0.15))
	NewModels6.sheet(md, "paper", [Vector3(0.036, -0.174, 0.005), Vector3(0.084, -0.174, 0.005), Vector3(0.06, -0.15, 0.005)], Color(0.35, 0.2, 0.12), Vector3(0, 0, 1))
	for sx: float in [-1.0, 1.0]:
		NewModels6.cyl(md, "chrome", Vector3(sx * 0.09, -0.01, 0.002), Vector3(sx * 0.09, -0.01, 0.01), 0.006, 0.004, 6, Color(0.7, 0.2, 0.15), 3, 0.0)

static func _map(md: NewModels6.Model) -> void:
	# a folded 1980s valley map opened flat (0.4 x 0.28 m): the lake, a river, contour rings, roads, and a route marked in red ending in a cross
	var f := func(x: float, _z: float) -> float: return 0.0016 * smoothstep(-0.02, 0.02, x) + 0.0007 * sin(x * 30.0)
	NewModels7.sheet_grid(md, "paper", 0.4, 0.28, 16, 10, PAPER * 0.94, f, Transform3D(Basis.IDENTITY, Vector3(0, 0.002, 0)), 0.04)
	var y := 0.0042
	NewModels6.sheet(md, "paper", [Vector3(-0.15, y, -0.06), Vector3(-0.04, y, -0.1), Vector3(0.0, y, -0.02), Vector3(-0.08, y, 0.04)], Color(0.45, 0.6, 0.72), Vector3.UP, false)
	for k in 3:
		var r := 0.03 + k * 0.025
		var prev := Vector3(0.1 + r, y, 0.04)
		for j in range(1, 17):
			var a := TAU * j / 16.0
			var p := Vector3(0.1 + cos(a) * r, y, 0.04 + sin(a) * r * 0.8)
			NewModels6.limb(md, "paper", prev, p, 0.0007, 0.0007, Color(0.55, 0.45, 0.3), 3)
			prev = p
	var prev2 := Vector3(-0.2, y, -0.1)
	for j in range(1, 10):
		var p2 := Vector3(-0.2 + j * 0.04, y, -0.1 + 0.03 * sin(j * 0.9))
		NewModels6.limb(md, "paper", prev2, p2, 0.0018, 0.0018, Color(0.4, 0.55, 0.7), 3)
		prev2 = p2
	NewModels6.limb(md, "paper", Vector3(-0.19, y, 0.1), Vector3(0.19, y, 0.08), 0.0018, 0.0018, Color(0.3, 0.2, 0.15), 3)
	var rt := [Vector3(-0.17, y + 0.0005, 0.1), Vector3(-0.1, y + 0.0005, 0.04), Vector3(-0.02, y + 0.0005, 0.05), Vector3(0.05, y + 0.0005, -0.03), Vector3(0.12, y + 0.0005, -0.06)]
	for k in rt.size() - 1:
		NewModels6.limb(md, "paper", rt[k], rt[k + 1], 0.0014, 0.0014, Color(0.65, 0.1, 0.08), 3)
	var e: Vector3 = rt[rt.size() - 1]
	NewModels6.limb(md, "paper", e + Vector3(-0.012, 0, -0.012), e + Vector3(0.012, 0, 0.012), 0.0018, 0.0018, Color(0.65, 0.1, 0.08), 3)
	NewModels6.limb(md, "paper", e + Vector3(-0.012, 0, 0.012), e + Vector3(0.012, 0, -0.012), 0.0018, 0.0018, Color(0.65, 0.1, 0.08), 3)
	NewModels6.text(md, "paper", "HALLOWAY VALLEY", Vector3(0.0, y, 0.125), Vector3.UP, 0.012, INK, Vector3(0, 0, -1), 0.0)

static func _hiker_gear(md: NewModels6.Model) -> void:
	# what a hiker left drying: a wet orange rain jacket crumpled on the floor, a pair of folded walking poles and a zip food bag with a bar and a tin mug in it
	var f := func(x: float, z: float) -> float:
		return 0.12 * exp(-(x * x / 0.08 + z * z / 0.05)) + 0.025 * sin(x * 14.0 + z * 6.0) * sin(z * 9.0) + 0.03
	NewModels7.sheet_grid(md, "cloth", 0.8, 0.6, 24, 16, Color(0.8, 0.32, 0.06), f, Transform3D.IDENTITY, 0.05)
	NewModels6.limb(md, "cloth", Vector3(-0.3, 0.07, 0.1), Vector3(-0.5, 0.05, 0.3), 0.045, 0.04, Color(0.78, 0.3, 0.06), 8, 0.06)
	NewModels6.limb(md, "cloth", Vector3(0.3, 0.07, 0.0), Vector3(0.5, 0.05, 0.25), 0.045, 0.04, Color(0.78, 0.3, 0.06), 8, 0.06)
	NewModels6.ball(md, "cloth", Vector3(0.0, 0.1, -0.2), Vector3(0.14, 0.05, 0.1), Color(0.7, 0.26, 0.05), 8, Basis.IDENTITY, 0.06)
	for k in 2:
		var o := Vector3(0.7 + k * 0.05, 0.0, -0.3 + k * 0.06)
		NewModels6.limb(md, "chrome", o, o + Vector3(-0.1, 1.2, -0.15), 0.009, 0.007, Color(0.2, 0.22, 0.24), 6)
		NewModels6.limb(md, "leather", o + Vector3(-0.1, 1.2, -0.15), o + Vector3(-0.11, 1.35, -0.16), 0.018, 0.016, Color(0.1, 0.1, 0.1), 8)
		NewModels6.limb(md, "rubber", o, o + Vector3(-0.01, 0.07, -0.01), 0.014, 0.012, Color(0.5, 0.45, 0.3), 6)
	NewModels6.rbox(md, "tarp", Vector3(-0.8, 0.05, -0.2), Vector3(0.22, 0.1, 0.16), Color(0.7, 0.72, 0.74, 1.0), Basis(Vector3.UP, 0.3), 3.2, 8, 0.03)
	NewModels6.box(md, "paper", Vector3(-0.8, 0.075, -0.2), Vector3(0.1, 0.01, 0.04), Color(0.4, 0.25, 0.15), 0.0, Color(-1, 0, 0), Basis(Vector3.UP, 0.3))
	NewModels6.cyl(md, "sheet", Vector3(-0.55, 0.0, -0.1), Vector3(-0.55, 0.08, -0.1), 0.045, 0.05, 12, Color(0.6, 0.62, 0.64), 1, 0.04)

# ================================================================== arrangements
static func _set_a(md: NewModels6.Model, lod: int) -> void:
	# the cabin interior as the finale finds it, laid out in the 8 x 6 m cabin (floor at y 0.35): bed on the left, table and chairs in the middle,
	# stove in the back right corner, the shelf and calendar on the back wall, the uniform on its hook by the window, the boots by the door
	var fy := 0.35
	var T := func(x: float, y: float, z: float, yaw: float) -> Transform3D: return Transform3D(Basis(Vector3.UP, yaw), Vector3(x, y, z))
	_put(md, "cabin_bed_a", T.call(-3.0, fy, -1.6, 0.0), lod)
	_put(md, "cabin_table_a", T.call(0.4, fy, -1.5, 0.0), lod)
	_put(md, "cabin_chair_a", T.call(-0.4, fy, -0.5, 0.35), lod)
	_put(md, "cabin_chair_b", T.call(1.5, fy, -2.1, -2.6), lod)
	_put(md, "cabin_stove_a", T.call(3.2, fy, -2.4, 0.0), lod)
	_put(md, "cabin_shelf_a", T.call(1.9, fy + 1.5, -2.97, PI), lod)
	_put(md, "cabin_calendar_a", T.call(-1.4, fy + 1.2, -2.96, PI), lod)
	_put(md, "cabin_uniform_a", T.call(-3.95, fy + 1.0, 1.6, PI * 0.5), lod)
	_put(md, "cabin_boots_a", T.call(-1.8, fy, 2.4, 0.4), lod)
	_put(md, "cabin_radio_a", T.call(0.15, fy + 0.76, -1.55, 0.2), lod)
	_put(md, "cabin_case_file_a", T.call(0.65, fy + 0.765, -1.4, -0.3), lod)
	_put(md, "cabin_kettle_a", T.call(3.05, fy + 0.77, -2.3, 0.0), lod)
	_put(md, "cabin_lantern_a_off", T.call(0.8, fy + 0.76, -1.7, 0.0), lod)
	_put(md, "cabin_drawing_a", T.call(-3.97, fy + 1.25, -0.3, PI * 0.5), lod)
	_put(md, "cabin_map_a", T.call(-2.7, fy + 0.5, -1.6, 0.4), lod)
	_put(md, "cabin_hiker_gear_a", T.call(-1.0, fy, 1.5, 0.6), lod)

static func _variant(md: NewModels6.Model, lod: int) -> void:
	# a second cabin interior, a smaller 4 x 3 m room with its own plank walls and a low ceiling: a camp bed, a stove, a table with the lantern, a shelf
	var w := 4.0
	var d := 3.0
	var h := 2.3
	var plank := NewModels7.W(Color(0.4, 0.33, 0.25), 0.75)
	for k in 14:
		NewModels6.box(md, "wood", Vector3(0, 0.0, -d * 0.5 + 0.1 + k * 0.2), Vector3(w - 0.1, 0.03, 0.19), NewModels7.W(Color(0.45, 0.36, 0.27) * (0.85 + 0.25 * NewModels6.rnd(k, 71.0)), 0.75))
	for k in 20:
		var x := -w * 0.5 + 0.1 + k * 0.2
		NewModels6.box(md, "wood", Vector3(x, h * 0.5, -d * 0.5 - 0.03), Vector3(0.19, h, 0.04), NewModels7.W(Color(0.4, 0.33, 0.25) * (0.85 + 0.25 * NewModels6.rnd(k, 72.0)), 1.0))
	for k in 15:
		var z := -d * 0.5 + 0.1 + k * 0.2
		for sx: float in [-1.0, 1.0]:
			NewModels6.box(md, "wood", Vector3(sx * (w * 0.5 + 0.03), h * 0.5, z), Vector3(0.04, h, 0.19), NewModels7.W(Color(0.4, 0.33, 0.25) * (0.85 + 0.25 * NewModels6.rnd(k, 73.0 + sx)), 1.0))
	for k in 5:
		NewModels7.board(md, "wood", Vector3(-w * 0.5, h + 0.07, -d * 0.5 + 0.3 + k * 0.6), Vector3(w * 0.5, h + 0.07, -d * 0.5 + 0.3 + k * 0.6), 0.15, 0.14, plank * 0.9)
	NewModels6.box(md, "wood", Vector3(1.5, h * 0.5 - 0.0, d * 0.5 + 0.03), Vector3(1.0, h, 0.04), NewModels7.W(Color(0.4, 0.33, 0.25), 1.0))
	var T := func(x: float, y: float, z: float, yaw: float) -> Transform3D: return Transform3D(Basis(Vector3.UP, yaw), Vector3(x, y, z))
	_put(md, "cabin_bed_a_stripped", T.call(-1.4, 0.03, -0.3, 0.0), lod)
	_put(md, "cabin_stove_a_lit", T.call(1.5, 0.03, -1.1, 0.0), lod)
	_put(md, "cabin_table_a", T.call(0.7, 0.03, 0.8, 0.0), lod)
	_put(md, "cabin_chair_b", T.call(0.7, 0.03, 1.35, PI), lod)
	_put(md, "cabin_lantern_a", T.call(0.9, 0.805, 0.75, 0.0), lod)
	_put(md, "cabin_shelf_a", T.call(-0.2, 1.5, -d * 0.5 + 0.0, PI), lod)
	_put(md, "cabin_boots_a", T.call(1.0, 0.03, 1.1, 0.6), lod)

## Wall things are drawn hanging from y = 0 down; raise them by their height so the origin is the bottom edge like every other model.
static func _raise(md: NewModels6.Model, h: float) -> void:
	for key in md.m:
		var b: NewModels2.Buf = md.m[key]
		for i in b.pos.size(): b.pos[i] = b.pos[i] + Vector3(0, h, 0)

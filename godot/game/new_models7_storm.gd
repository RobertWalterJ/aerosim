class_name NewModels7Storm
extends RefCounted
## Story batch 9 (models9), part A: what a tornado throws and leaves. Priority 0 debris pieces (centred on their own origin, 0.3 to
## 3 m, for the existing MultiMesh), storm damage props, and the buried shelter (hatch with a stone surround, steps, retaining wall
## and the debris field around it). The weather archive and the later storm props are in NewModels7Archive.
## Metres, +Z front, origin at the base (debris: centred). Colliders only on the barn panel, fallen tree, broken fence and the
## shelter hatch. Nothing gory, no bodies.

const NAMES: Array[String] = [
	"storm_debris_plank_a", "storm_debris_plank_b", "storm_debris_roof_sheet_a", "storm_debris_shingles_a", "storm_debris_branch_a",
	"storm_debris_fence_a", "storm_debris_tin_a", "storm_debris_barrel_a", "storm_debris_sack_a", "storm_debris_leaves_a",
	"storm_barn_panel_a", "storm_tree_fallen_a", "storm_fence_broken_a", "storm_scoured_patch_a", "storm_post_uprooted_a", "storm_sign_twisted_a",
	"storm_shelter_hatch_closed_a", "storm_shelter_hatch_open_a", "storm_shelter_steps_a", "storm_shelter_wall_a", "storm_shelter_debris_a",
]

const GREY_WOOD := Color(0.5, 0.45, 0.38)
const BARN_RED := Color(0.55, 0.13, 0.09)
const GALV := Color(0.62, 0.64, 0.66)
const STONE_C := Color(0.5, 0.48, 0.44)
const BARK := Color(0.2, 0.15, 0.1)
const SOIL_C := Color(0.2, 0.14, 0.1)

static func build(name: String, md: NewModels6.Model, lod: int) -> bool:
	match name:
		"storm_debris_plank_a": _plank_a(md)
		"storm_debris_plank_b": _plank_b(md)
		"storm_debris_roof_sheet_a": _roof_sheet(md, lod)
		"storm_debris_shingles_a": _shingles(md)
		"storm_debris_branch_a": _branch(md, lod)
		"storm_debris_fence_a": _fence_piece(md)
		"storm_debris_tin_a": _tin(md, lod)
		"storm_debris_barrel_a": _barrel(md, lod)
		"storm_debris_sack_a": _sack(md)
		"storm_debris_leaves_a": NewModels7.leaves(md, Vector3.ZERO, 0.3, 36 if lod == 0 else 16, 0.13, 1.0, NewModels7.AUTUMN)
		"storm_barn_panel_a": _barn_panel(md, lod)
		"storm_tree_fallen_a": _fallen_tree(md, lod)
		"storm_fence_broken_a": _broken_fence(md)
		"storm_scoured_patch_a": _scoured(md, lod)
		"storm_post_uprooted_a": _post_uprooted(md)
		"storm_sign_twisted_a": _sign_twisted(md)
		"storm_shelter_hatch_closed_a": _hatch(md, false)
		"storm_shelter_hatch_open_a": _hatch(md, true)
		"storm_shelter_steps_a": _steps(md)
		"storm_shelter_wall_a": _wall(md)
		"storm_shelter_debris_a": _debris_field(md, lod)
		_: return false
	return true

static func _nail(md: NewModels6.Model, p: Vector3, up := Vector3.UP) -> void:
	NewModels6.limb(md, "rust", p, p + up * 0.012, 0.004, 0.003, Color(0.28, 0.16, 0.1), 4)

# ================================================================== debris (centred on origin)
static func _plank_a(md: NewModels6.Model) -> void:
	# a 2.4 m weatherboard plank, split along one end, with the old paint still on a patch and a few bent nails
	NewModels7.board(md, "wood", Vector3(-1.2, 0, 0), Vector3(0.95, 0, 0), 0.14, 0.038, NewModels7.W(GREY_WOOD, 0.75), Vector3.UP)
	NewModels7.board(md, "wood", Vector3(0.95, 0, -0.025), Vector3(1.2, 0.012, -0.05), 0.07, 0.034, NewModels7.W(GREY_WOOD * 1.05, 0.75))
	NewModels7.board(md, "wood", Vector3(0.95, 0, 0.03), Vector3(1.17, -0.004, 0.065), 0.06, 0.034, NewModels7.W(GREY_WOOD * 0.9, 0.75))
	NewModels7.board(md, "paintwood", Vector3(-1.1, 0.0205, 0), Vector3(-0.35, 0.0205, 0), 0.138, 0.004, Color(0.42, 0.1, 0.07, 1.0))
	for k in 3:
		_nail(md, Vector3(-1.12 + k * 0.03, 0.019, (k - 1) * 0.03))

static func _plank_b(md: NewModels6.Model) -> void:
	# a shorter board snapped off ragged at one end (the break is real geometry)
	var poly := PackedVector2Array([Vector2(-0.65, -0.07), Vector2(0.5, -0.07), Vector2(0.64, -0.035), Vector2(0.55, 0.0), Vector2(0.7, 0.045), Vector2(0.6, 0.07), Vector2(-0.65, 0.07)])
	NewModels6.prism_poly(md, "wood", poly, -0.019, 0.019, NewModels7.W(GREY_WOOD * 0.95, 0.75), Transform3D.IDENTITY, 0.06)
	for k in 2:
		NewModels6.cyl(md, "rust", Vector3(-0.55 + k * 0.18, 0.019, 0.0), Vector3(-0.55 + k * 0.18, 0.05, 0.0), 0.004, 0.003, 4, Color(0.3, 0.17, 0.1), 3, 0.0)

static func _roof_sheet(md: NewModels6.Model, lod: int) -> void:
	# a corrugated galvanised roofing sheet, 2.0 m by 0.9 m, bent and twisted by the wind; the corrugation (76 mm pitch) is real geometry
	var nv := 44 if lod == 0 else 22
	var f := func(x: float, z: float) -> float:
		var wave := 0.0095 * sin(z * TAU / 0.076)
		var bend := 0.32 * smoothstep(0.1, 1.0, x) + 0.05 * sin(x * 2.0) - 0.1 * smoothstep(0.6, 1.0, -x)
		var twist := 0.18 * (x * 0.5) * (z / 0.45)
		return wave + bend + twist
	NewModels7.sheet_grid(md, "steel", 2.0, 0.9, 20, nv, Color(0.5, 0.52, 0.54), f, Transform3D.IDENTITY, 0.05)
	# a ragged torn edge and a few fixing holes with washers
	for k in 5:
		NewModels6.cyl(md, "rust", Vector3(-0.85 + k * 0.01, 0.05 + 0.0, -0.4 + k * 0.2), Vector3(-0.85 + k * 0.01, 0.07, -0.4 + k * 0.2), 0.016, 0.014, 6, Color(0.35, 0.2, 0.12), 3, 0.0)

static func _shingles(md: NewModels6.Model) -> void:
	for k in 9:
		var a := NewModels6.rnd(k, 3.0) * TAU
		var p := Vector3(cos(a) * 0.2 * NewModels6.rnd(k, 4.0), (k % 3) * 0.006, sin(a) * 0.2 * NewModels6.rnd(k, 5.0))
		var bas := Basis(Vector3.UP, NewModels6.rnd(k, 6.0) * TAU) * Basis(Vector3.RIGHT, (NewModels6.rnd(k, 7.0) - 0.5) * 0.35)
		var c := Color(0.12, 0.12, 0.13) if k % 4 != 0 else Color(0.2, 0.17, 0.12)
		NewModels6.box(md, "rubber", p, Vector3(0.34, 0.005, 0.15), NewModels6.vc(c, k * 1.7, 0.1), 0.0, Color(-1, 0, 0), bas)
		NewModels6.box(md, "rubber", p + bas * Vector3(0, 0.0035, 0.045), Vector3(0.34, 0.003, 0.012), Color(0.05, 0.05, 0.05), 0.0, Color(-1, 0, 0), bas)

static func _branch(md: NewModels6.Model, lod: int) -> void:
	# a 2.6 m torn-off branch, forked, with broken twigs and a few leaves still on
	var bark := NewModels7.W(BARK * 1.3, 0.75)
	NewModels6.limb(md, "wood", Vector3(-1.25, 0.0, 0.0), Vector3(1.3, 0.1, 0.15), 0.065, 0.026, bark, 8, 0.08)
	# the torn end: pale splintered wood
	NewModels6.limb(md, "wood", Vector3(-1.27, 0.0, 0.0), Vector3(-1.2, 0.0, 0.0), 0.058, 0.064, NewModels7.W(Color(0.62, 0.5, 0.36), 0.75), 8)
	var forks := [[0.0, 0.22, 0.5, 1.0, 0.18], [0.45, 0.45, 0.2, 0.8, 0.12], [0.9, -0.1, -0.4, 0.9, 0.1], [0.2, -0.3, 0.1, 0.6, 0.08], [1.1, 0.05, 0.1, 0.5, 0.07]]
	var i := 0
	for fk in forks:
		var t := (float(fk[0]) + 1.25) / 2.55
		var base := Vector3(-1.25, 0.0, 0.0).lerp(Vector3(1.3, 0.1, 0.15), t)
		var dir := Vector3(float(fk[1]), float(fk[4]) + 0.15, float(fk[2])).normalized()
		var tip := base + dir * float(fk[3])
		NewModels6.limb(md, "wood", base, tip, 0.03 * (1.0 - t * 0.6), 0.01, bark, 6, 0.08)
		if lod == 0:
			for k in 3:
				var tb := base.lerp(tip, 0.45 + k * 0.2)
				var td := (dir + Vector3(NewModels6.rnd(i * 3 + k, 8.0) - 0.5, 0.2, NewModels6.rnd(i * 3 + k, 9.0) - 0.5)).normalized()
				NewModels6.limb(md, "wood", tb, tb + td * 0.3, 0.008, 0.003, bark, 4)
			NewModels7.leaves(md, tip, 0.12, 5, 0.1, 20.0 + i, NewModels7.AUTUMN)
		i += 1

static func _fence_piece(md: NewModels6.Model) -> void:
	# a length of post-and-rail fence torn up: one rail, two post stubs and a loop of wire
	NewModels7.board(md, "wood", Vector3(-1.2, 0.05, 0), Vector3(1.2, 0.05, 0.04), 0.09, 0.05, NewModels7.W(GREY_WOOD * 0.9, 0.75))
	for sx: float in [-1.0, 1.0]:
		var p := Vector3(sx * 0.95, 0.0, 0.0)
		NewModels7.board(md, "wood", p + Vector3(0, 0.1, 0), p + Vector3(sx * 0.1, -0.38, 0.1), 0.09, 0.09, NewModels7.W(GREY_WOOD * 0.85, 0.5), Vector3.FORWARD)
	NewModels7.rope(md, "steel", Vector3(-1.0, 0.1, 0.0), Vector3(0.9, 0.12, 0.1), -0.12, 0.0045, Color(0.55, 0.57, 0.6))
	NewModels7.rope(md, "steel", Vector3(0.8, 0.1, 0.05), Vector3(1.4, -0.15, 0.3), 0.15, 0.0045, Color(0.55, 0.57, 0.6))
	NewModels7.rope(md, "steel", Vector3(-0.9, 0.08, 0.0), Vector3(-1.5, -0.1, -0.35), 0.1, 0.0045, Color(0.55, 0.57, 0.6))

static func _tin(md: NewModels6.Model, lod: int) -> void:
	# a flat galvanised sheet crumpled by the wind
	var f := func(x: float, z: float) -> float:
		return 0.11 * sin(x * 3.3 + z * 1.9) * sin(z * 4.7 + 0.5) + 0.07 * sin(x * 7.0 - z * 2.0) + 0.2 * maxf(0.0, x - 0.35) * (1.0 + z)
	NewModels7.sheet_grid(md, "steel", 1.8, 0.8, 28 if lod == 0 else 12, 14 if lod == 0 else 6, Color(0.5, 0.52, 0.54), f, Transform3D.IDENTITY, 0.05)

static func _barrel(md: NewModels6.Model, lod: int) -> void:
	# a 200 litre steel drum: 0.58 m across, 0.88 m tall, two rolled ribs, a dent in the side and rust at the seams
	var seg := 20 if lod == 0 else 10
	var prof := PackedVector2Array([Vector2(0.0, -0.44), Vector2(0.265, -0.44), Vector2(0.285, -0.42), Vector2(0.29, -0.36), Vector2(0.28, -0.3), Vector2(0.29, -0.27),
		Vector2(0.28, -0.24), Vector2(0.285, -0.1), Vector2(0.285, 0.1), Vector2(0.28, 0.24), Vector2(0.29, 0.27), Vector2(0.28, 0.3), Vector2(0.29, 0.36),
		Vector2(0.285, 0.42), Vector2(0.265, 0.44), Vector2(0.0, 0.44)])
	NewModels6.put(md, "rust", DroneParts.lathe(prof, seg), Transform3D(Basis(Vector3.RIGHT, 0.55) * Basis(Vector3.UP, 0.4), Vector3.ZERO), Color(0.14, 0.24, 0.32), 0.035)
	var tb := Basis(Vector3.RIGHT, 0.55) * Basis(Vector3.UP, 0.4)
	NewModels6.cyl(md, "chrome", tb * Vector3(0.12, 0.44, 0.05), tb * Vector3(0.12, 0.47, 0.05), 0.03, 0.028, 8, Color(0.6, 0.6, 0.62), 3, 0.0)
	NewModels6.cyl(md, "chrome", tb * Vector3(-0.1, 0.44, -0.12), tb * Vector3(-0.1, 0.46, -0.12), 0.022, 0.02, 8, Color(0.6, 0.6, 0.62), 3, 0.0)

static func _sack(md: NewModels6.Model) -> void:
	# a 25 kg feed sack: woven paper, tied at the neck, a printed band
	var col := Color(0.5, 0.42, 0.3)
	NewModels6.rbox(md, "canvas", Vector3(0, 0.0, 0), Vector3(0.62, 0.2, 0.4), col, Basis(Vector3.UP, 0.25), 4.0, 14, 0.02)
	for k in 4:
		NewModels6.ball(md, "canvas", Vector3(-0.2 + k * 0.13, 0.085, 0.02 * (k % 2)), Vector3(0.03, 0.012, 0.15), col * 0.88, 6, Basis(Vector3.UP, 0.25 + 0.15 * (k - 1.5)), 0.02)
	NewModels6.ball(md, "canvas", Vector3(0.0, 0.0, 0.28).rotated(Vector3.UP, 0.25), Vector3(0.1, 0.07, 0.07), col * 0.9, 8)
	NewModels6.limb(md, "canvas", Vector3(0.0, 0.0, 0.3).rotated(Vector3.UP, 0.25), Vector3(0.01, 0.01, 0.4).rotated(Vector3.UP, 0.25), 0.05, 0.03, col * 0.85, 6)
	NewModels6.limb(md, "rubber", Vector3(0.0, 0.0, 0.33).rotated(Vector3.UP, 0.25), Vector3(0.0, 0.0, 0.35).rotated(Vector3.UP, 0.25), 0.045, 0.045, Color(0.5, 0.4, 0.2), 6)
	NewModels6.text(md, "paint", "FEED", Vector3(0.0, -0.05, 0.0) + Vector3(0, 0.103, 0), Vector3.UP, 0.09, Color(0.5, 0.1, 0.08), Vector3(-sin(0.25), 0, -cos(0.25)), 0.0)

# ================================================================== storm damage props
## The red, partly stripped boards of a barn wall torn off its frame (3.0 m by 2.4 m), lying propped on its own rubble.
static func _barn_panel(md: NewModels6.Model, lod: int) -> void:
	var p := NewModels6.Model.new()
	var nb := 12
	var w := 3.0 / nb
	for k in nb:
		var x0 := -1.5 + k * w + 0.004
		var x1 := x0 + w - 0.008
		var L := 2.4 - 0.5 * NewModels6.rnd(k, 11.0) * NewModels6.rnd(k, 12.0)
		var poly := PackedVector2Array([Vector2(x0, 0.0), Vector2(x1, 0.0), Vector2(x1, L), Vector2(lerpf(x1, x0, 0.3), L + 0.08 * NewModels6.rnd(k, 13.0)),
			Vector2(lerpf(x1, x0, 0.65), L - 0.12 * NewModels6.rnd(k, 14.0)), Vector2(x0, L + 0.06 * NewModels6.rnd(k, 15.0))])
		var bare := NewModels6.rnd(k, 16.0) < 0.3
		var col := Color(0.58, 0.14, 0.09, 1.0) if not bare else Color(0.45, 0.42, 0.38, 0.0)
		NewModels6.prism_poly(p, "paintwood", poly, 0.0, 0.024, NewModels6.vc(col, k * 2.1, 0.08), Transform3D.IDENTITY, 0.05)
	# the three 2x6 rails on the back and the studs still nailed to them
	for z in [0.35, 1.2, 2.0]:
		NewModels7.board(p, "wood", Vector3(-1.5, -0.045, z), Vector3(1.5, -0.045, z), 0.14, 0.07, NewModels7.W(GREY_WOOD * 0.8, 0.75))
	for sx in [-1.2, 0.0, 1.35]:
		NewModels7.board(p, "wood", Vector3(sx, -0.045, 0.0), Vector3(sx, -0.045, 1.9 + NewModels6.rnd(sx, 3.0) * 0.4), 0.09, 0.09, NewModels7.W(GREY_WOOD * 0.75, 0.5))
	# bright white trim board along the long edge
	NewModels7.board(p, "paintwood", Vector3(-1.5, 0.026, 0.02), Vector3(-1.5, 0.026, 2.1), 0.09, 0.012, Color(0.85, 0.83, 0.78, 1.0))
	for k in 12:
		_nail(p, Vector3(-1.4 + NewModels6.rnd(k, 17.0) * 2.8, 0.024, 0.3 + NewModels6.rnd(k, 18.0) * 1.7))
	var ang := -0.32
	NewModels7.merge(md, p, Transform3D(Basis(Vector3.RIGHT, ang), Vector3(0, 0.07, 0.0)))
	# rubble under the raised end and a few loose boards beside it
	for k in 5:
		var q := Vector3(-1.2 + k * 0.55, 0.0, 1.8 + NewModels6.rnd(k, 21.0) * 0.5)
		NewModels6.rbox(md, "stone", q + Vector3(0, 0.12, 0), Vector3(0.4, 0.26, 0.3), NewModels6.vc(STONE_C * 0.62, k * 1.3, 0.1), Basis(Vector3.UP, k * 0.9), 5.0, 8, 0.1)
	for k in 3:
		NewModels7.board(md, "wood", Vector3(-1.8 + k * 0.4, 0.03, 0.2 - k * 0.35), Vector3(-1.6 + k * 0.45, 0.03, -1.1 - k * 0.1), 0.14, 0.035, NewModels7.W(GREY_WOOD, 0.5))
	NewModels6.hull(md, Vector3(0, 0.45, 1.1), Vector3(3.1, 0.9, 2.5))

## A mature maple blown over: trunk 9 m, the torn root plate standing on edge with soil still in it, big limbs and an autumn crown.
static func _fallen_tree(md: NewModels6.Model, lod: int) -> void:
	var bark := NewModels7.W(BARK, 0.5)
	var base := Vector3(0, 0.55, 0)
	var tip := Vector3(0.6, 0.4, -9.0)
	# trunk in four tapering segments with a slight lean and a swelling at the base
	var seg := 10 if lod == 0 else 7
	var prev := base
	var r_prev := 0.52
	for k in range(1, 5):
		var t := float(k) / 4.0
		var p := base.lerp(tip, t) + Vector3(sin(t * 3.0) * 0.12, 0.1 * sin(t * PI), 0.0)
		var r := lerpf(0.52, 0.2, t)
		NewModels6.limb(md, "wood", prev, p, r_prev, r, bark, seg, 0.08)
		prev = p
		r_prev = r
	# the root plate: a tilted disc of soil and roots at the base end (z = 0)
	NewModels6.ball(md, "soil", Vector3(0, 1.0, 0.2), Vector3(1.35, 1.2, 0.26), SOIL_C, 14, Basis(Vector3.RIGHT, -0.12), 0.1)
	for k in 14:
		var a := TAU * k / 14.0 + 0.2
		var dir := Vector3(cos(a), sin(a), -0.15)
		var c0 := Vector3(0, 1.0, 0.1) + dir * 0.35
		var c1 := Vector3(0, 1.0, 0.1) + dir * (1.15 + 0.35 * NewModels6.rnd(k, 31.0)) + Vector3(0, 0, 0.35 + 0.25 * NewModels6.rnd(k, 32.0))
		NewModels6.limb(md, "wood", c0, c1, 0.07, 0.015, NewModels7.W(BARK * 1.2, 0.75), 6, 0.1)
		NewModels6.limb(md, "wood", c1, c1 + Vector3(NewModels6.rnd(k, 33.0) - 0.5, NewModels6.rnd(k, 34.0) - 0.5, 0.35) * 0.4, 0.012, 0.004, NewModels7.W(BARK * 1.2, 0.75), 4)
	for k in 9:
		var a2 := NewModels6.rnd(k, 35.0) * TAU
		NewModels6.ball(md, "soil", Vector3(cos(a2) * 0.9, 1.0 + sin(a2) * 0.85, 0.35), Vector3(0.13, 0.1, 0.1), SOIL_C * 0.9, 6, Basis.IDENTITY, 0.1)
	# limbs off the trunk, each with finer branches and leaf clusters
	var limbs := [[0.3, 0.9, 0.5, 2.6], [0.4, -0.8, 0.45, 2.4], [0.55, 0.7, 0.6, 3.0], [0.62, -0.9, 0.5, 2.8], [0.75, 0.5, 0.7, 2.4], [0.82, -0.6, 0.6, 2.0], [0.92, 0.2, 0.8, 1.6]]
	var j := 0
	for lb in limbs:
		var t2 := float(lb[0])
		var tp := base.lerp(tip, t2) + Vector3(sin(t2 * 3.0) * 0.12, 0.1 * sin(t2 * PI), 0.0)
		var d := Vector3(float(lb[1]), float(lb[2]), -0.35).normalized()
		var end := tp + d * float(lb[3])
		NewModels6.limb(md, "wood", tp, end, lerpf(0.52, 0.2, t2) * 0.45, 0.04, bark, 7, 0.08)
		for k in 3:
			var b0 := tp.lerp(end, 0.4 + k * 0.22)
			var bd := (d + Vector3(NewModels6.rnd(j * 3 + k, 40.0) - 0.5, 0.25, NewModels6.rnd(j * 3 + k, 41.0) - 0.7)).normalized()
			var b1 := b0 + bd * 1.1
			NewModels6.limb(md, "wood", b0, b1, 0.03, 0.008, bark, 5, 0.08)
			if lod == 0: NewModels7.leaves(md, b1, 0.35, 16, 0.16, 50.0 + j * 3 + k, NewModels7.AUTUMN)
		if lod == 0: NewModels7.leaves(md, end, 0.45, 22, 0.17, 80.0 + j, NewModels7.AUTUMN)
		j += 1
	NewModels6.hull(md, Vector3(0, 0.55, -1.8), Vector3(1.1, 1.1, 3.6))
	NewModels6.hull(md, Vector3(0.3, 0.5, -5.4), Vector3(0.8, 0.8, 3.6))
	NewModels6.hull(md, Vector3(0, 1.0, 0.2), Vector3(2.6, 2.3, 0.6))

static func _broken_fence(md: NewModels6.Model) -> void:
	# six metres of post-and-wire field fence: one post standing and leaning, one snapped, one flat; the wire sags to the ground
	var post_col := NewModels7.W(GREY_WOOD * 0.85, 0.5)
	var lean := 0.22
	var a := Vector3(-2.6, 0.0, 0.0)
	var top_a := a + Vector3(sin(lean) * 1.25, cos(lean) * 1.25, 0.0)
	NewModels7.board(md, "wood", a, top_a, 0.1, 0.1, post_col, Vector3.FORWARD)
	# the snapped one: a stump and the top half lying across
	NewModels7.board(md, "wood", Vector3(0.0, 0.0, 0.0), Vector3(0.05, 0.42, 0.0), 0.1, 0.1, post_col, Vector3.FORWARD)
	NewModels7.board(md, "wood", Vector3(0.1, 0.12, 0.25), Vector3(1.2, 0.05, 0.9), 0.1, 0.1, NewModels7.W(GREY_WOOD * 0.8, 0.75))
	NewModels6.limb(md, "wood", Vector3(0.05, 0.42, 0.0), Vector3(0.11, 0.35, 0.02), 0.04, 0.01, NewModels7.W(Color(0.62, 0.5, 0.36), 0.5), 5)   # splinters
	# the third post is flat, still wired, root end torn out of the ground
	NewModels7.board(md, "wood", Vector3(2.3, 0.06, 0.2), Vector3(3.3, 0.06, 1.3), 0.1, 0.1, NewModels7.W(GREY_WOOD * 0.9, 0.75))
	NewModels6.ball(md, "soil", Vector3(2.25, 0.08, 0.15), Vector3(0.2, 0.12, 0.2), SOIL_C, 7)
	# four strands of wire, slack
	for k in 4:
		var y := 0.25 + 0.28 * k
		var p0 := a + Vector3(sin(lean) * y / cos(lean) * 0.0 + y * tan(lean), y, 0.0) if y < 1.25 else top_a
		NewModels7.rope(md, "steel", p0, Vector3(0.0, 0.05 + 0.02 * k, 0.1 * k), 0.38 - 0.06 * k, 0.0038, Color(0.52, 0.54, 0.57), 10)
		NewModels7.rope(md, "steel", Vector3(0.0, 0.05 + 0.02 * k, 0.1 * k), Vector3(2.3, 0.05, 0.25 + 0.1 * k), 0.03, 0.0038, Color(0.52, 0.54, 0.57), 10)
		NewModels7.rope(md, "steel", Vector3(2.3, 0.05, 0.25 + 0.1 * k), Vector3(3.8, 0.04, 0.9 + 0.2 * k), 0.0, 0.0038, Color(0.52, 0.54, 0.57), 6)
	NewModels6.hull(md, Vector3(-2.55, 0.62, 0.0), Vector3(0.5, 1.25, 0.3))
	NewModels6.hull(md, Vector3(0.3, 0.3, 0.3), Vector3(1.4, 0.6, 1.0))

## A bare patch of earth where the funnel crossed: scoured radial grooves, a raised rim, stones, torn grass.
static func _scoured(md: NewModels6.Model, lod: int) -> void:
	var f := func(x: float, z: float) -> float:
		var r := sqrt(x * x + z * z)
		var a := atan2(z, x)
		return 0.02 + 0.014 * sin(a * 14.0 + r * 2.2) * (1.0 - clampf(r / 3.4, 0.0, 1.0)) + 0.05 * exp(-pow((r - 2.6) / 0.4, 2.0)) - 0.012 * (1.0 - clampf(r / 3.2, 0.0, 1.0))
	var edge := func(a: float) -> float:
		return 0.82 + 0.1 * sin(a * 5.0) + 0.06 * sin(a * 11.0 + 1.0) + 0.04 * sin(a * 19.0)
	NewModels7.disc_grid(md, "soil", 3.4, 10 if lod == 0 else 5, 40 if lod == 0 else 20, Color(0.2, 0.14, 0.1), f, edge, 0.1)
	for k in 26:
		var a2 := NewModels6.rnd(k, 51.0) * TAU
		var r2 := 2.9 * sqrt(NewModels6.rnd(k, 52.0))
		NewModels6.ball(md, "stone", Vector3(cos(a2) * r2, 0.03, sin(a2) * r2), Vector3(0.05, 0.035, 0.05) * (0.7 + 1.6 * NewModels6.rnd(k, 53.0)), NewModels6.vc(STONE_C, k, 0.1), 6, Basis(Vector3.UP, k), 0.08)
	if lod == 0:
		for k in 18:
			var a3 := NewModels6.rnd(k, 54.0) * TAU
			var r3 := 2.8 + 0.5 * NewModels6.rnd(k, 55.0)
			var c := Vector3(cos(a3) * r3, 0.04, sin(a3) * r3)
			for s in 3:
				NewModels6.limb(md, "hay", c, c + Vector3((NewModels6.rnd(k * 3 + s, 56.0) - 0.5) * 0.18, 0.12, (NewModels6.rnd(k * 3 + s, 57.0) - 0.5) * 0.18), 0.004, 0.0015, Color(0.38, 0.35, 0.16), 3)

static func _post_uprooted(md: NewModels6.Model) -> void:
	# a fence post with its concrete footing still on the end, pulled out and lying at an angle with wire stubs
	var a := Vector3(0.0, 0.12, 0.0)
	var b := Vector3(0.0, 0.62, -1.9)
	NewModels7.board(md, "wood", a + Vector3(0, 0, -0.1), b, 0.12, 0.12, NewModels7.W(GREY_WOOD * 0.85, 0.5), Vector3.RIGHT)
	NewModels6.rbox(md, "concrete", Vector3(0, 0.1, 0.02), Vector3(0.3, 0.2, 0.28), Color(0.5, 0.49, 0.46), Basis(Vector3.UP, 0.4), 4.0, 8, 0.04)
	NewModels6.ball(md, "soil", Vector3(0.1, 0.07, 0.12), Vector3(0.3, 0.1, 0.25), SOIL_C, 8, Basis.IDENTITY, 0.1)
	for k in 3:
		NewModels7.rope(md, "steel", a.lerp(b, 0.55 + k * 0.1) + Vector3(0, 0.05, 0), a.lerp(b, 0.55 + k * 0.1) + Vector3(0.6 + k * 0.3, -0.35, -0.4 - k * 0.2), 0.08, 0.0038, Color(0.52, 0.54, 0.57), 6)

static func _sign_twisted(md: NewModels6.Model) -> void:
	# a warning sign on a steel post: the post bent over, the plate folded and twisted on its single bolt
	var steel := Color(0.55, 0.57, 0.6)
	NewModels6.limb(md, "steel", Vector3(0, 0, 0), Vector3(0, 1.3, 0), 0.032, 0.032, steel, 8)
	NewModels6.limb(md, "steel", Vector3(0, 1.3, 0), Vector3(0.45, 2.0, 0.1), 0.032, 0.03, steel, 8)
	NewModels6.limb(md, "steel", Vector3(0.45, 2.0, 0.1), Vector3(1.0, 2.15, 0.35), 0.03, 0.028, steel, 8)
	NewModels6.ball(md, "soil", Vector3(0, 0.03, 0), Vector3(0.18, 0.05, 0.18), SOIL_C, 6)
	var plate := func(v0: float, v1: float, off: float, col: Color) -> void:
		var rows: Array = []
		for j in 7:
			var u := lerpf(v0, v1, float(j) / 6.0)
			var r := PackedVector3Array(); r.resize(9)
			for i in 9:
				var x := (float(i) / 8.0 - 0.5) * 0.7
				var ang := (x + 0.35) * 2.2 - 0.3
				var y := u * 0.5
				var p := Vector3(x, y * cos(ang), y * sin(ang) + off)
				r[i] = Vector3(0.95, 2.15, 0.35) + Basis(Vector3.UP, 0.7) * (p + Vector3(0, -0.05, 0.03 * sin(x * 9.0)))
			rows.append(r)
		var hint := func(_i: int, _j: int, _p: Vector3) -> Vector3: return Vector3(0.7, 0.2, 0.7)
		NewModels6.gridsurf(md, "sheet", rows, col, hint, 0.05)
	plate.call(-0.5, 0.5, 0.004, Color(0.86, 0.7, 0.08))
	plate.call(-0.28, 0.28, 0.0055, Color(0.06, 0.06, 0.06))
	plate.call(-0.5, 0.5, -0.003, Color(0.5, 0.52, 0.54))

# ================================================================== the buried shelter
static func _hatch(md: NewModels6.Model, open: bool) -> void:
	# a root-cellar style hatch set in a stone surround: 1.0 x 0.8 m opening, heavy plank door with iron straps and a ring
	var surround := Vector3(1.9, 0.2, 1.7)
	var op := Vector2(1.04, 0.84)
	var hz := op.y * 0.5
	for sz: float in [-1.0, 1.0]:
		NewModels6.rbox(md, "concrete", Vector3(0, 0.1, sz * (hz + 0.22)), Vector3(surround.x, 0.2, 0.44), NewModels6.vc(STONE_C, sz * 3.0, 0.1), Basis.IDENTITY, 4.0, 8, 0.12)
	for sx: float in [-1.0, 1.0]:
		NewModels6.rbox(md, "concrete", Vector3(sx * (op.x * 0.5 + 0.22), 0.1, 0), Vector3(0.44, 0.2, op.y), NewModels6.vc(STONE_C, sx * 7.0, 0.1), Basis.IDENTITY, 4.0, 8, 0.12)
	# the dark shaft below and the first stone step visible when open
	NewModels6.box(md, "paint", Vector3(0, 0.02, 0), Vector3(op.x - 0.02, 0.04, op.y - 0.02), Color(0.02, 0.02, 0.02))
	NewModels6.box(md, "stone", Vector3(0, 0.09, hz - 0.1), Vector3(op.x - 0.02, 0.1, 0.2), STONE_C * 0.7, 0.0, Color(-1, 0, 0))
	# the hatch (its own node, pivot on the hinge edge at the back)
	var pivot := Vector3(0, 0.215, -hz)
	var h := md.sub("hatch", pivot)
	var rot := Basis(Vector3.RIGHT, -1.75) if open else Basis.IDENTITY
	var R := func(p: Vector3) -> Vector3: return pivot + rot * (p - pivot)
	var nplank := 5
	var pw := op.x / nplank
	for k in nplank:
		var x := -op.x * 0.5 + pw * (k + 0.5)
		NewModels7.merge(h, _plank_cell(Vector3(pw - 0.012, 0.07, op.y + 0.06), NewModels7.W(Color(0.3, 0.24, 0.17) * (0.9 + 0.2 * NewModels6.rnd(k, 61.0)), 0.5), k), Transform3D(rot, R.call(Vector3(x, 0.255, 0.0))))
	for z in [-0.28, 0.28]:
		NewModels6.box(h, "steel", R.call(Vector3(0, 0.298, z)), Vector3(op.x + 0.04, 0.012, 0.07), Color(0.1, 0.1, 0.1), 0.0, Color(-1, 0, 0), rot)
		for k in 5:
			NewModels6.cyl(h, "steel", R.call(Vector3(-0.45 + k * 0.225, 0.304, z)), R.call(Vector3(-0.45 + k * 0.225, 0.314, z)), 0.012, 0.01, 6, Color(0.14, 0.14, 0.14), 3, 0.0)
	for sx: float in [-1.0, 1.0]:
		NewModels6.box(h, "steel", R.call(Vector3(sx * 0.4, 0.3, -hz + 0.12)), Vector3(0.1, 0.014, 0.28), Color(0.1, 0.1, 0.1), 0.0, Color(-1, 0, 0), rot)
	# the iron ring pull at the front edge
	var ring_c: Vector3 = R.call(Vector3(0, 0.31, hz - 0.1))
	var rr := 0.06
	var prev: Vector3 = Vector3.ZERO
	for k in 13:
		var a := TAU * k / 12.0
		var p: Vector3 = ring_c + rot * Vector3(cos(a) * rr, 0.0, sin(a) * rr)
		if k > 0: NewModels6.limb(h, "steel", prev, p, 0.008, 0.008, Color(0.12, 0.12, 0.12), 4)
		prev = p
	if open:
		NewModels6.hull(md, Vector3(0, 0.1, 0), surround)
		NewModels6.hull(h, Vector3(0, 0.55, hz * 0.9 + 0.5), Vector3(1.1, 0.9, 0.3))
	else:
		NewModels6.hull(md, Vector3(0, 0.15, 0), Vector3(surround.x, 0.3, surround.z))

static func _plank_cell(size: Vector3, col: Color, k: int) -> NewModels6.Model:
	var m := NewModels6.Model.new()
	NewModels7.board(m, "wood", Vector3(0, 0, -size.z * 0.5), Vector3(0, 0, size.z * 0.5), size.x, size.y, col, Vector3.UP)
	return m

static func _steps(md: NewModels6.Model) -> void:
	# five stone steps going down 1.0 m into the shelter, with a low wall each side; origin is the top step at ground level, +Z leads down
	var n := 5
	for k in n:
		var z := 0.2 + k * 0.3
		var y := -k * 0.2
		NewModels6.rbox(md, "stone", Vector3(0, y - 0.1, z), Vector3(1.0, 0.2, 0.3), NewModels6.vc(STONE_C, k * 2.3, 0.1), Basis.IDENTITY, 5.0, 8, 0.1)
	for sx: float in [-1.0, 1.0]:
		for k in 3:
			NewModels6.rbox(md, "stone", Vector3(sx * 0.62, -0.25 + 0.0, 0.1 + k * 0.5), Vector3(0.24, 0.9 - k * 0.12, 0.5), NewModels6.vc(STONE_C, sx * 4.0 + k, 0.1), Basis.IDENTITY, 4.0, 8, 0.12)
	NewModels6.rbox(md, "stone", Vector3(0, 0.02, -0.05), Vector3(1.5, 0.12, 0.3), STONE_C, Basis.IDENTITY, 4.0, 8, 0.1)
	NewModels6.box(md, "paint", Vector3(0, -1.05, 1.9), Vector3(1.0, 0.1, 0.2), Color(0.02, 0.02, 0.02))

static func _wall(md: NewModels6.Model) -> void:
	# a dry-stone retaining wall: 5 m long, 0.7 m high, 0.45 m thick, four courses of irregular blocks and capstones
	var courses := 4
	for c in courses:
		var x := -2.5
		var i := 0
		while x < 2.5:
			var w := 0.35 + 0.35 * NewModels6.rnd(c * 20 + i, 71.0)
			w = minf(w, 2.5 - x)
			var hgt := 0.16 + 0.04 * NewModels6.rnd(c * 20 + i, 72.0)
			var y := c * 0.16 + hgt * 0.5 - 0.0
			NewModels6.rbox(md, "stone", Vector3(x + w * 0.5, y, 0.0), Vector3(w - 0.01, hgt, 0.42 + 0.03 * NewModels6.rnd(c * 20 + i, 73.0)),
				NewModels6.vc(STONE_C * (0.85 + 0.3 * NewModels6.rnd(c * 20 + i, 74.0)), c * 7.0 + i, 0.08), Basis.IDENTITY, 4.0, 8, 0.1)
			x += w
			i += 1
	var xx := -2.5
	var j := 0
	while xx < 2.5:
		var w2 := minf(0.55 + 0.25 * NewModels6.rnd(j, 75.0), 2.5 - xx)
		NewModels6.rbox(md, "stone", Vector3(xx + w2 * 0.5, 0.7, 0.0), Vector3(w2 - 0.015, 0.1, 0.5), NewModels6.vc(STONE_C * 1.05, j * 3.3, 0.08), Basis(Vector3.UP, (NewModels6.rnd(j, 76.0) - 0.5) * 0.06), 4.0, 8, 0.1)
		xx += w2
		j += 1
	NewModels6.hull(md, Vector3(0, 0.37, 0), Vector3(5.0, 0.75, 0.5))

static func _debris_field(md: NewModels6.Model, lod: int) -> void:
	# a 5 m by 5 m spread of what the storm dropped around the shelter, built from the debris pieces lying on the ground
	var pieces := [["storm_debris_plank_a", 7], ["storm_debris_plank_b", 4], ["storm_debris_shingles_a", 3], ["storm_debris_tin_a", 2], ["storm_debris_roof_sheet_a", 1],
		["storm_debris_branch_a", 2], ["storm_debris_sack_a", 1], ["storm_debris_barrel_a", 1], ["storm_debris_leaves_a", 5], ["storm_debris_fence_a", 1]]
	var i := 0
	for pc in pieces:
		var src := NewModels6.build(pc[0], 0 if lod == 0 else 1)
		for k in int(pc[1]):
			var a := NewModels6.rnd(i, 81.0) * TAU
			var r := 2.4 * sqrt(NewModels6.rnd(i, 82.0))
			var lie := Basis(Vector3.UP, NewModels6.rnd(i, 83.0) * TAU)
			var lift := 0.03
			if pc[0] == "storm_debris_barrel_a": lie = Basis(Vector3.UP, 1.0) * Basis(Vector3.FORWARD, PI * 0.5); lift = 0.3
			elif pc[0] == "storm_debris_sack_a": lift = 0.1
			elif pc[0] == "storm_debris_roof_sheet_a" or pc[0] == "storm_debris_tin_a": lift = 0.1
			elif pc[0] == "storm_debris_branch_a": lift = 0.05
			NewModels7.merge(md, src, Transform3D(lie, Vector3(cos(a) * r, lift, sin(a) * r)))
			i += 1

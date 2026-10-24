class_name NewModels6Later
extends RefCounted
## Story batch (models8), priority 2: the high street's later buildings (church, school, chip shop, bakery, a police front desk),
## the field's ice cream van, generator and toilets, the parade tractor and trailer, and the props for the small recurring cases
## (a lost dog and its poster, a crop circle and its stencil, a milk churn, a railway signal lamp). Same frame and rules as the rest
## of the batch: metres, +Z front, origin on the ground, fictional signage, named wheels.

const NAMES: Array[String] = [
	"town_police_interior_a", "town_church_a", "town_school_a", "town_chip_shop_a", "town_bakery_a",
	"festival_ice_cream_van_a", "festival_generator_a", "festival_toilet_a", "parade_tractor_a", "parade_trailer_a",
	"lost_dog_a", "lost_dog_poster_a", "crop_circle_a", "milk_churn_a", "railway_signal_lamp_a",
]
const DECALS: Array[String] = ["crop_circle_stencil_a"]

const IRON := Color(0.08, 0.09, 0.09)
const CREAM := Color(0.88, 0.84, 0.68)
const GREEN := Color(0.12, 0.3, 0.2)

static func build(name: String, md: NewModels6.Model, lod: int) -> bool:
	match name:
		"town_police_interior_a": _interior(md)
		"town_church_a": _church(md, lod)
		"town_school_a": _school(md, lod)
		"town_chip_shop_a": _shopfront(md, "FISH & CHIPS", Color(0.14, 0.2, 0.36), Color(0.82, 0.8, 0.72), lod)
		"town_bakery_a": _shopfront(md, "BAKERY", Color(0.5, 0.2, 0.15), CREAM, lod)
		"festival_ice_cream_van_a": _van(md, lod)
		"festival_generator_a": _generator(md)
		"festival_toilet_a": _toilets(md)
		"parade_tractor_a": _tractor(md, lod)
		"parade_trailer_a": _trailer(md, lod)
		"lost_dog_a": NewModels6Chars._biscuit(md, "stand", lod, Color(0.62, 0.46, 0.24), Color(0.88, 0.8, 0.66))
		"lost_dog_poster_a": _poster(md)
		"crop_circle_a": _crop_circle(md, lod)
		"milk_churn_a": _churn(md)
		"railway_signal_lamp_a": _signal_lamp(md)
		_: return false
	return true

# ---------------------------------------------------------------- the police front desk (a stage-set room, not an interior to walk)
static func _interior(md: NewModels6.Model) -> void:
	var W := 5.0; var D := 4.0; var H := 2.6
	NewModels6.box(md, "wood", Vector3(0, 0.03, 0), Vector3(W, 0.06, D), Color(0.42, 0.34, 0.24), 0.0, Color(0.46, 0.38, 0.27))
	NewModels6.box(md, "paintwood", Vector3(0, H * 0.5, -D * 0.5 + 0.05), Vector3(W, H, 0.1), Color(0.72, 0.74, 0.7))
	for sx: float in [-1.0, 1.0]:
		NewModels6.box(md, "paintwood", Vector3(sx * (W * 0.5 - 0.05), H * 0.5, 0), Vector3(0.1, H, D), Color(0.7, 0.72, 0.68))
	NewModels6.box(md, "paintwood", Vector3(0, 0.9, -D * 0.5 + 0.12), Vector3(W - 0.2, 1.8, 0.04), Color(0.22, 0.3, 0.26))
	# the counter across the room with a flap, a desk lamp, a radio and a ledger behind it
	NewModels6.box(md, "wood", Vector3(-0.5, 0.55, 0.3), Vector3(3.6, 1.1, 0.5), Color(0.34, 0.26, 0.17))
	NewModels6.box(md, "wood", Vector3(-0.5, 1.12, 0.3), Vector3(3.7, 0.05, 0.62), Color(0.46, 0.36, 0.24), 0.0, Color(0.5, 0.4, 0.27))
	NewModels6.cyl(md, "paint", Vector3(-1.5, 1.15, 0.3), Vector3(-1.5, 1.45, 0.3), 0.01, 0.01, 6, IRON, 3, 0.0)
	NewModels6.ball(md, "lamp", Vector3(-1.5, 1.47, 0.3), Vector3(0.12, 0.06, 0.12), Color.WHITE, 8)
	NewModels6.box(md, "paper", Vector3(-0.3, 1.16, 0.2), Vector3(0.4, 0.04, 0.3), Color(0.12, 0.14, 0.22))
	NewModels6.box(md, "paper", Vector3(0.6, 1.16, 0.4), Vector3(0.3, 0.01, 0.4), Color(0.9, 0.88, 0.8), 0.3)
	# a notice board, a wall clock, a key rack and a filing cabinet
	NewModels6.box(md, "wood", Vector3(-1.5, 1.6, -D * 0.5 + 0.17), Vector3(1.2, 0.9, 0.05), Color(0.3, 0.22, 0.14))
	for k in 6:
		NewModels6.box(md, "paper", Vector3(-1.9 + (k % 3) * 0.38, 1.4 + (k / 3) * 0.4, -D * 0.5 + 0.2), Vector3(0.28, 0.32, 0.004), [Color(0.9, 0.9, 0.86), Color(0.9, 0.85, 0.55), Color(0.85, 0.9, 0.95)][k % 3], (NewModels6.rnd(k, 5.0) - 0.5) * 0.2)
	NewModels6.cyl(md, "enamel", Vector3(0.9, 2.0, -D * 0.5 + 0.14), Vector3(0.9, 2.0, -D * 0.5 + 0.18), 0.22, 0.22, 20, Color(0.9, 0.88, 0.8), 3, 0.0)
	NewModels6.box(md, "paint", Vector3(0.9, 2.0, -D * 0.5 + 0.185), Vector3(0.012, 0.15, 0.003), Color(0.05, 0.05, 0.05))
	NewModels6.box(md, "paint", Vector3(0.95, 2.03, -D * 0.5 + 0.185), Vector3(0.1, 0.012, 0.003), Color(0.05, 0.05, 0.05))
	NewModels6.box(md, "paint", Vector3(1.9, 0.65, -D * 0.5 + 0.45), Vector3(0.5, 1.3, 0.6), Color(0.32, 0.36, 0.38))
	for k in 3:
		NewModels6.box(md, "chrome", Vector3(1.9, 0.35 + k * 0.4, -D * 0.5 + 0.76), Vector3(0.16, 0.02, 0.02), Color(0.6, 0.6, 0.62))
	NewModels6.box(md, "wood", Vector3(-1.9, 0.25, D * 0.5 - 0.5), Vector3(1.4, 0.05, 0.4), Color(0.4, 0.32, 0.22))
	NewModels6.hull(md, Vector3(0, 0.3, 0), Vector3(W, 0.6, D))
	md.hulls.clear()

# ---------------------------------------------------------------- church, school, shop fronts
static func _church(md: NewModels6.Model, lod: int) -> void:
	var W := 7.5; var D := 15.0; var WH := 5.5; var RH := 3.6
	var stone := Color(0.78, 0.76, 0.72)
	var wins: Array = [[-2.5, 1.0, 2.6, 1.6], [2.5, 1.0, 2.6, 1.6]]
	NewModels6Hall._front(md, "brick", stone, W, D, WH, [], [[0.0, 1.8, 3.2]])
	NewModels6Hall._door(md, Vector3(0, 0.0, D * 0.5), 1.6, 2.7, Vector3(0, 0, 1), Color(0.26, 0.2, 0.14), Color(0.5, 0.5, 0.47))
	for sx: float in [-1.0, 1.0]:
		var ops: Array = []
		for k in 4: ops.append([2.2 + k * 3.1, 3.2 + k * 3.1, 1.6, 4.4])
		NewModels6Town._wall(md, "brick", stone, Vector3(sx * W * 0.5, 0, D * 0.5), Vector3(sx * W * 0.5, 0, -D * 0.5), WH, 0.5, ops, Vector3(sx, 0, 0))
		for k in 4:
			NewModels6Hall._win(md, Vector3(sx * W * 0.5, 3.0, D * 0.5 - 2.7 - k * 3.1), 1.0, 2.8, Vector3(sx, 0, 0), Color(0.5, 0.5, 0.47), true, 1)
	NewModels6Hall._wall_back(md, "brick", stone, W, D, WH, [[0.0, 1.2, 2.8, 1.8]])
	NewModels6.box(md, "concrete", Vector3(0, 0.03, 0), Vector3(W - 0.4, 0.06, D - 0.4), Color(0.4, 0.38, 0.34))
	NewModels6Hall._roof(md, W, D, WH, RH, Color(0.28, 0.27, 0.3), false)
	# the tower at the front: four stone walls, a belfry with louvres, and a spire
	var tw := 3.6; var th := 9.5
	NewModels6.box(md, "brick", Vector3(0, th * 0.5, D * 0.5 + tw * 0.5 - 0.3), Vector3(tw, th, tw), stone * 0.97)
	for k in 3:
		NewModels6.box(md, "stone", Vector3(0, 2.6 + k * 2.6, D * 0.5 + tw - 0.3 + 0.01), Vector3(tw + 0.2, 0.12, 0.2), Color(0.55, 0.55, 0.52))
	for sx: float in [-1.0, 1.0]:
		NewModels6.box(md, "paint", Vector3(sx * 0.0, 8.0, D * 0.5 + tw - 0.25), Vector3(0.9, 1.6, 0.05), Color(0.1, 0.1, 0.1))
	for sz: float in [-1.0, 1.0]:
		NewModels6.box(md, "paint", Vector3(sz * (tw * 0.5 + 0.0), 8.0, D * 0.5 + tw * 0.5 - 0.3), Vector3(0.05, 1.6, 0.9), Color(0.1, 0.1, 0.1))
	var spire_h := 6.0
	var tri := [Vector3(-tw * 0.5, th, D * 0.5 - 0.3 + 0.0), Vector3(tw * 0.5, th, D * 0.5 - 0.3), Vector3(tw * 0.5, th, D * 0.5 + tw - 0.3), Vector3(-tw * 0.5, th, D * 0.5 + tw - 0.3)]
	var apex := Vector3(0, th + spire_h, D * 0.5 + tw * 0.5 - 0.3)
	for k in 4:
		var a: Vector3 = tri[k]; var b: Vector3 = tri[(k + 1) % 4]
		var n := ((b - a).cross(apex - a)).normalized()
		NewModels6.sheet(md, "roof", [a, b, apex], Color(0.3, 0.32, 0.34), n if n.dot((a + b) * 0.5 - Vector3(0, th, D * 0.5 + tw * 0.5 - 0.3)) > 0.0 else -n)
	NewModels6.limb(md, "steel", apex, apex + Vector3(0, 1.2, 0), 0.03, 0.01, Color(0.6, 0.55, 0.3), 5)
	NewModels6.box(md, "steel", apex + Vector3(0, 0.9, 0), Vector3(0.5, 0.03, 0.03), Color(0.6, 0.55, 0.3))
	NewModels6.hull(md, Vector3(0, WH * 0.5, 0), Vector3(W, WH, D))
	NewModels6.hull(md, Vector3(0, th * 0.5, D * 0.5 + tw * 0.5), Vector3(tw, th, tw))

static func _school(md: NewModels6.Model, lod: int) -> void:
	var W := 16.0; var D := 8.0; var WH := 3.6; var RH := 2.0
	var brick := Color(0.88, 0.8, 0.72)
	var wins: Array = [[-5.5, 1.8, 1.6, 1.2], [-2.8, 1.8, 1.6, 1.2], [2.8, 1.8, 1.6, 1.2], [5.5, 1.8, 1.6, 1.2]]
	NewModels6Hall._front(md, "brick", brick, W, D, WH, wins, [[0.0, 1.6, 2.4]])
	for wn in wins:
		NewModels6Hall._win(md, Vector3(float(wn[0]), float(wn[3]) + float(wn[2]) * 0.5, D * 0.5), float(wn[1]), float(wn[2]), Vector3(0, 0, 1), Color(0.12, 0.3, 0.2), true, 3)
	NewModels6Hall._door(md, Vector3(-0.4, 0.0, D * 0.5), 0.7, 2.2, Vector3(0, 0, 1), Color(0.12, 0.3, 0.2), CREAM)
	NewModels6Hall._door(md, Vector3(0.4, 0.0, D * 0.5), 0.7, 2.2, Vector3(0, 0, 1), Color(0.12, 0.3, 0.2), CREAM)
	NewModels6Hall._floor_and_back(md, W, D, WH, brick, [[-5.0, 1.8, 1.6, 1.2], [-1.5, 1.8, 1.6, 1.2], [1.5, 1.8, 1.6, 1.2], [5.0, 1.8, 1.6, 1.2]], [[4.0, 1.4, 1.6, 1.2]])
	NewModels6Hall._roof(md, W, D, WH, RH, Color(0.34, 0.2, 0.17), true)
	# the bell cupola on the ridge and the name board
	NewModels6.box(md, "paintwood", Vector3(0, WH + RH + 0.6, 0), Vector3(1.0, 1.0, 1.0), CREAM)
	var apex := Vector3(0, WH + RH + 1.9, 0)
	for k in 4:
		var a0 := TAU * k / 4.0 + PI * 0.25; var a1 := TAU * (k + 1) / 4.0 + PI * 0.25
		var p0 := Vector3(cos(a0) * 0.72, WH + RH + 1.1, sin(a0) * 0.72); var p1 := Vector3(cos(a1) * 0.72, WH + RH + 1.1, sin(a1) * 0.72)
		NewModels6.sheet(md, "roof", [p0, p1, apex], Color(0.3, 0.32, 0.34), ((p1 - p0).cross(apex - p0)).normalized())
	NewModels6.ball(md, "chrome", Vector3(0, WH + RH + 0.6, 0), Vector3(0.12, 0.14, 0.12), Color(0.7, 0.58, 0.28), 6)
	NewModels6.box(md, "paintwood", Vector3(0, 3.0, D * 0.5 + 0.1), Vector3(3.8, 0.4, 0.08), GREEN)
	NewModels6.text(md, "paintwood", "HALLOWAY SCHOOL", Vector3(0, 2.87, D * 0.5 + 0.15), Vector3(0, 0, 1), 0.2, CREAM, Vector3.UP, 0.0)
	NewModels6.hull(md, Vector3(0, WH * 0.5, 0), Vector3(W, WH, D))
	NewModels6.hull(md, Vector3(0, WH + RH * 0.5, 0), Vector3(W, RH, D))

static func _shopfront(md: NewModels6.Model, title: String, trim: Color, awn: Color, lod: int) -> void:
	var W := 5.5; var D := 8.0; var WH := 4.0; var RH := 1.5
	var brick := Color(0.78, 0.7, 0.64)
	var wins: Array = [[0.5, 2.6, 1.7, 0.7], [-1.0, 0.9, 1.0, 2.8], [1.0, 0.9, 1.0, 2.8]]
	NewModels6Hall._front(md, "brick", brick, W, D, WH, wins, [[-2.0, 0.9, 2.1]])
	for wn in wins:
		NewModels6Hall._win(md, Vector3(float(wn[0]), float(wn[3]) + float(wn[2]) * 0.5, D * 0.5), float(wn[1]), float(wn[2]), Vector3(0, 0, 1), trim, true, 0 if float(wn[1]) > 2.0 else 2)
	NewModels6Hall._door(md, Vector3(-2.0, 0.0, D * 0.5), 0.8, 2.0, Vector3(0, 0, 1), trim, CREAM)
	NewModels6.box(md, "paintwood", Vector3(0, 2.6, D * 0.5 + 0.1), Vector3(W - 0.2, 0.65, 0.12), trim)
	NewModels6.text(md, "paintwood", title, Vector3(0, 2.44, D * 0.5 + 0.17), Vector3(0, 0, 1), 0.3, CREAM, Vector3.UP, 0.0)
	for k in 8:
		var x0 := -1.4 + k * 0.4
		NewModels6.sheet(md, "canvas", [Vector3(x0, 2.15, D * 0.5 + 0.05), Vector3(x0 + 0.4, 2.15, D * 0.5 + 0.05), Vector3(x0 + 0.4, 1.95, D * 0.5 + 0.9), Vector3(x0, 1.95, D * 0.5 + 0.9)], trim if k % 2 == 0 else awn, Vector3(0, 0.3, 1))
	NewModels6Hall._floor_and_back(md, W, D, WH, brick, [[-1.2, 1.0, 1.3, 1.0], [1.2, 1.0, 1.3, 1.0]], [[3.0, 1.0, 1.2, 1.0], [3.0, 0.9, 1.0, 2.8]])
	NewModels6Hall._roof(md, W, D, WH, RH, Color(0.34, 0.22, 0.2), true)
	NewModels6Hall._chimney(md, 1.6, -1.0, WH + 0.7)
	NewModels6.box(md, "wood", Vector3(2.0, 0.45, D * 0.5 + 0.9), Vector3(0.5, 0.8, 0.04), Color(0.1, 0.12, 0.1), 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, 0.2))
	NewModels6.hull(md, Vector3(0, WH * 0.5, 0), Vector3(W, WH, D))
	NewModels6.hull(md, Vector3(0, WH + RH * 0.5, 0), Vector3(W, RH, D))

# ---------------------------------------------------------------- the field's vehicles and machines
static func _wheel(md: NewModels6.Model, node: String, c: Vector3, r: float, w: float, sx: float, col: Color, rim: Color, seg: int) -> void:
	var sub := md.sub(node, c)
	var rot := Basis.from_euler(Vector3(0, 0, -PI * 0.5 * sx))
	var prof := PackedVector2Array([Vector2(r * 0.6, -w * 0.5), Vector2(r * 0.9, -w * 0.52), Vector2(r, -w * 0.4), Vector2(r, w * 0.4), Vector2(r * 0.9, w * 0.52), Vector2(r * 0.6, w * 0.5)])
	var xf := Transform3D(rot, c)
	NewModels6.put(sub, "rubber", DroneParts.lathe(prof, seg), xf, col, 0.08)
	NewModels6.put(sub, "gloss", DroneParts.lathe(PackedVector2Array([Vector2(0.0, w * 0.46), Vector2(r * 0.6, w * 0.46), Vector2(r * 0.62, w * 0.3), Vector2(0.0, w * 0.3)]), seg), xf, rim, 0.0)

static func _van(md: NewModels6.Model, lod: int) -> void:
	# a 1970s ice cream van: cream and pink box body on a small van chassis, a serving hatch with an awning, a fibreglass cone on the roof
	var cream := Color(0.9, 0.86, 0.74); var pink := Color(0.86, 0.55, 0.6)
	NewModels6.rbox(md, "gloss", Vector3(0, 1.45, -0.6), Vector3(2.0, 1.9, 3.8), cream, Basis.IDENTITY, 5.0, 12, 0.04)
	NewModels6.rbox(md, "gloss", Vector3(0, 1.1, 2.1), Vector3(2.0, 1.3, 1.5), cream, Basis.IDENTITY, 4.0, 12, 0.04)
	NewModels6.box(md, "gloss", Vector3(0, 1.0, -0.6), Vector3(2.04, 0.5, 3.84), pink)
	NewModels6.quad2(md, "glass", Vector3(-0.85, 1.4, 2.86), Vector3(0.85, 1.4, 2.86), Vector3(0.85, 1.95, 2.55), Vector3(-0.85, 1.95, 2.55), Color.WHITE)
	NewModels6.box(md, "chrome", Vector3(0, 0.55, 2.9), Vector3(2.1, 0.12, 0.14), Color(0.75, 0.76, 0.78))
	NewModels6.box(md, "chrome", Vector3(0, 0.55, -2.55), Vector3(2.1, 0.12, 0.14), Color(0.75, 0.76, 0.78))
	# the serving hatch on the left (+x) side with a striped awning, the counter and a menu board
	NewModels6.box(md, "paint", Vector3(1.01, 1.55, -0.3), Vector3(0.04, 0.8, 1.3), Color(0.05, 0.05, 0.06))
	NewModels6.box(md, "chrome", Vector3(1.1, 1.14, -0.3), Vector3(0.25, 0.05, 1.4), Color(0.78, 0.8, 0.82))
	for k in 6:
		var z0 := -1.2 + k * 0.4
		NewModels6.sheet(md, "canvas", [Vector3(1.0, 2.05, z0), Vector3(1.0, 2.05, z0 + 0.4), Vector3(1.55, 1.85, z0 + 0.4), Vector3(1.55, 1.85, z0)], pink if k % 2 == 0 else CREAM, Vector3(0.3, 1, 0))
	NewModels6.box(md, "paint", Vector3(1.01, 1.0, 0.9), Vector3(0.03, 0.6, 0.5), Color(0.15, 0.12, 0.1))
	NewModels6.text(md, "paint", "ICE CREAM", Vector3(1.04, 1.25, 0.9), Vector3(1, 0, 0), 0.06, CREAM, Vector3.UP, 0.0)
	# the cone: a waffle cone on the roof with a swirl of cream on top
	var cone := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.01, 0.0), Vector2(0.28, 0.8), Vector2(0.0, 0.8)])
	NewModels6.put(md, "gloss", DroneParts.lathe(cone, 12), Transform3D(Basis.from_euler(Vector3(PI, 0, 0)), Vector3(0, 3.3, -1.2)), Color(0.75, 0.55, 0.25), 0.05)
	NewModels6.ball(md, "gloss", Vector3(0, 3.55, -1.2), Vector3(0.32, 0.26, 0.32), Color(0.95, 0.9, 0.82), 12)
	NewModels6.ball(md, "gloss", Vector3(0, 3.82, -1.2), Vector3(0.2, 0.16, 0.2), Color(0.95, 0.9, 0.82), 10)
	NewModels6.cyl(md, "paint", Vector3(0, 2.42, -1.2), Vector3(0, 2.9, -1.2), 0.12, 0.2, 8, Color(0.5, 0.5, 0.5), 3, 0.0)
	NewModels6.box(md, "paint", Vector3(0, 2.46, 1.6), Vector3(0.4, 0.2, 0.3), Color(0.15, 0.15, 0.17))     # the chime speaker
	var hl := md.sub("headlamp_glass", Vector3(0, 0.95, 2.86))
	for sx: float in [-1.0, 1.0]:
		NewModels6.cyl(hl, "lamp", Vector3(sx * 0.7, 0.95, 2.86), Vector3(sx * 0.7, 0.95, 2.9), 0.12, 0.11, 12, Color.WHITE, 3, 0.0)
	var seg: int = NewModels6.LOD_SEG[lod]
	for wd in [["wheel_fl", 1.0, 2.1], ["wheel_fr", -1.0, 2.1], ["wheel_rl", 1.0, -1.7], ["wheel_rr", -1.0, -1.7]]:
		_wheel(md, wd[0], Vector3(float(wd[1]) * 0.9, 0.36, float(wd[2])), 0.36, 0.2, float(wd[1]), Color(0.06, 0.06, 0.06), Color(0.8, 0.8, 0.78), seg)
	NewModels6.hull(md, Vector3(0, 1.4, 0), Vector3(2.1, 2.2, 6.0))

static func _generator(md: NewModels6.Model) -> void:
	var yel := Color(0.82, 0.62, 0.1)
	NewModels6.rbox(md, "gloss", Vector3(0, 0.5, 0), Vector3(1.1, 0.7, 0.62), yel, Basis.IDENTITY, 6.0, 10, 0.05)
	NewModels6.box(md, "steel", Vector3(0, 0.12, 0), Vector3(1.2, 0.06, 0.7), Color(0.12, 0.12, 0.12))
	for sx: float in [-1.0, 1.0]:
		NewModels6.limb(md, "steel", Vector3(sx * 0.58, 0.12, -0.3), Vector3(sx * 0.58, 0.9, -0.3), 0.018, 0.018, Color(0.12, 0.12, 0.12), 6)
		NewModels6.limb(md, "steel", Vector3(sx * 0.58, 0.9, -0.3), Vector3(sx * 0.58, 0.9, 0.3), 0.018, 0.018, Color(0.12, 0.12, 0.12), 6)
		NewModels6.limb(md, "steel", Vector3(sx * 0.58, 0.9, 0.3), Vector3(sx * 0.58, 0.12, 0.3), 0.018, 0.018, Color(0.12, 0.12, 0.12), 6)
	NewModels6.box(md, "paint", Vector3(0.0, 0.5, 0.32), Vector3(0.5, 0.3, 0.01), Color(0.08, 0.08, 0.09))
	for k in 3:
		NewModels6.cyl(md, "paint", Vector3(-0.15 + k * 0.15, 0.52, 0.325), Vector3(-0.15 + k * 0.15, 0.52, 0.34), 0.03, 0.03, 8, Color(0.5, 0.5, 0.5), 3, 0.0)
	NewModels6.cyl(md, "rust", Vector3(0.4, 0.8, -0.1), Vector3(0.4, 1.2, -0.1), 0.04, 0.035, 8, Color(0.15, 0.12, 0.1), 3, 0.05)
	NewModels6.ball(md, "gloss", Vector3(-0.3, 0.86, 0.1), Vector3(0.12, 0.08, 0.12), Color(0.8, 0.1, 0.08), 8)
	var prev := Vector3(0.55, 0.45, 0.31)
	for k in 9:
		var t := (k + 1) / 9.0
		var p := Vector3(0.55 + 0.9 * t, 0.45 - 0.42 * t, 0.31 + 0.5 * t + 0.1 * sin(t * 5.0))
		NewModels6.limb(md, "rubber", prev, p, 0.018, 0.018, Color(0.1, 0.1, 0.11), 4)
		prev = p
	NewModels6.hull(md, Vector3(0, 0.5, 0), Vector3(1.2, 1.0, 0.7))

static func _toilets(md: NewModels6.Model) -> void:
	for k in 3:
		var x := (k - 1) * 1.2
		var blue := Color(0.15, 0.35, 0.62) if k != 1 else Color(0.2, 0.5, 0.35)
		NewModels6.rbox(md, "gloss", Vector3(x, 1.2, 0), Vector3(1.15, 2.4, 1.15), Color(0.9, 0.9, 0.88), Basis.IDENTITY, 8.0, 10, 0.04)
		NewModels6.box(md, "gloss", Vector3(x, 1.0, 0.585), Vector3(0.78, 1.8, 0.02), blue)
		NewModels6.box(md, "gloss", Vector3(x, 1.0, 0.598), Vector3(0.7, 1.7, 0.01), blue * 1.12)
		NewModels6.box(md, "chrome", Vector3(x + 0.24, 1.0, 0.61), Vector3(0.05, 0.08, 0.015), Color(0.72, 0.72, 0.74))
		NewModels6.box(md, "paint", Vector3(x, 1.65, 0.61), Vector3(0.1, 0.1, 0.008), Color(0.7, 0.1, 0.08))
		NewModels6.box(md, "gloss", Vector3(x, 2.43, 0.0), Vector3(1.2, 0.08, 1.2), blue * 0.9)
		NewModels6.cyl(md, "paint", Vector3(x - 0.3, 2.47, -0.3), Vector3(x - 0.3, 2.62, -0.3), 0.07, 0.05, 8, Color(0.85, 0.85, 0.85), 3, 0.0)
	NewModels6.hull(md, Vector3(0, 1.2, 0), Vector3(3.6, 2.4, 1.2))

static func _tractor(md: NewModels6.Model, lod: int) -> void:
	# a 1960s red wheeled tractor with a seat but no cab; origin on the ground at the middle; the front is +z
	var red := Color(0.55, 0.1, 0.07)
	var seg: int = NewModels6.LOD_SEG[lod]
	NewModels6.rbox(md, "gloss", Vector3(0, 1.0, 0.85), Vector3(0.75, 0.7, 1.7), red, Basis.IDENTITY, 5.0, 12, 0.04)
	NewModels6.box(md, "gloss", Vector3(0, 0.85, -0.4), Vector3(0.9, 0.7, 0.9), red * 0.95)
	NewModels6.cyl(md, "rust", Vector3(0.0, 1.35, 1.5), Vector3(0.0, 2.15, 1.5), 0.045, 0.04, 8, Color(0.12, 0.11, 0.1), 3, 0.04)
	NewModels6.cyl(md, "paint", Vector3(0.0, 2.15, 1.5), Vector3(0.0, 2.2, 1.5), 0.08, 0.08, 8, Color(0.2, 0.2, 0.2), 3, 0.0)
	# the seat on a spring, the steering wheel on its column
	NewModels6.box(md, "leather", Vector3(0, 1.55, -0.55), Vector3(0.42, 0.1, 0.4), Color(0.1, 0.08, 0.06))
	NewModels6.limb(md, "steel", Vector3(0, 1.3, -0.5), Vector3(0, 1.5, -0.55), 0.03, 0.03, IRON, 6)
	NewModels6.limb(md, "steel", Vector3(0, 1.3, 0.1), Vector3(0, 1.7, 0.0), 0.02, 0.02, IRON, 6)
	for k in 10:
		var a0 := TAU * k / 10; var a1 := TAU * (k + 1) / 10
		NewModels6.limb(md, "rubber", Vector3(cos(a0) * 0.2, 1.72, sin(a0) * 0.14 - 0.05), Vector3(cos(a1) * 0.2, 1.72, sin(a1) * 0.14 - 0.05), 0.014, 0.014, Color(0.07, 0.07, 0.07), 4)
	# the front axle, the grille and a pair of lamps, the drawbar at the back
	NewModels6.box(md, "steel", Vector3(0, 0.45, 1.5), Vector3(1.3, 0.1, 0.12), IRON)
	NewModels6.box(md, "chrome", Vector3(0, 1.0, 1.72), Vector3(0.6, 0.5, 0.05), Color(0.7, 0.7, 0.72))
	NewModels6.box(md, "steel", Vector3(0, 0.55, -1.0), Vector3(0.12, 0.1, 0.9), IRON)
	var hl := md.sub("headlamp_glass", Vector3(0, 1.1, 1.74))
	for sx: float in [-1.0, 1.0]:
		NewModels6.cyl(hl, "lamp", Vector3(sx * 0.35, 1.1, 1.74), Vector3(sx * 0.35, 1.1, 1.78), 0.07, 0.065, 10, Color.WHITE, 3, 0.0)
	for wd in [["wheel_fl", 1.0, 1.5, 0.4, 0.14], ["wheel_fr", -1.0, 1.5, 0.4, 0.14], ["wheel_rl", 1.0, -0.4, 0.75, 0.3], ["wheel_rr", -1.0, -0.4, 0.75, 0.3]]:
		var rr: float = wd[3]
		_wheel(md, wd[0], Vector3(float(wd[1]) * (0.78 if rr > 0.5 else 0.65), rr, float(wd[2])), rr, float(wd[4]), float(wd[1]), Color(0.05, 0.05, 0.05), red, seg)
	NewModels6.hull(md, Vector3(0, 1.0, 0.4), Vector3(1.8, 2.0, 3.6))

static func _trailer(md: NewModels6.Model, lod: int) -> void:
	var seg: int = NewModels6.LOD_SEG[lod]
	NewModels6.box(md, "wood", Vector3(0, 0.85, 0), Vector3(2.0, 0.1, 4.0), Color(0.46, 0.36, 0.25), 0.0, Color(0.5, 0.4, 0.28))
	NewModels6.box(md, "steel", Vector3(0, 0.74, 0), Vector3(1.8, 0.1, 4.1), IRON)
	for sx: float in [-1.0, 1.0]:
		for k in 5:
			NewModels6.box(md, "wood", Vector3(sx * 0.98, 1.1, -1.7 + k * 0.85), Vector3(0.05, 0.4, 0.8), Color(0.44, 0.34, 0.24), 0.0)
		NewModels6.box(md, "paintwood", Vector3(sx * 1.01, 0.95, 0.0), Vector3(0.03, 0.45, 4.0), GREEN)
	NewModels6.box(md, "wood", Vector3(0, 1.1, -2.0), Vector3(2.0, 0.4, 0.05), Color(0.44, 0.34, 0.24))
	NewModels6.limb(md, "steel", Vector3(0, 0.74, 2.0), Vector3(0, 0.6, 3.2), 0.035, 0.03, IRON, 6)
	NewModels6.ball(md, "steel", Vector3(0, 0.62, 3.2), Vector3(0.07, 0.07, 0.07), IRON, 6)
	NewModels6.limb(md, "steel", Vector3(0, 0.74, 2.0), Vector3(-0.4, 0.74, 1.4), 0.03, 0.03, IRON, 6)
	NewModels6.limb(md, "steel", Vector3(0, 0.74, 2.0), Vector3(0.4, 0.74, 1.4), 0.03, 0.03, IRON, 6)
	NewModels6.text(md, "paintwood", "HALLOWAY FESTIVAL", Vector3(1.05, 0.88, 0.0), Vector3(1, 0, 0), 0.2, CREAM, Vector3.UP, 0.0)
	NewModels6.text(md, "paintwood", "HALLOWAY FESTIVAL", Vector3(-1.05, 0.88, 0.0), Vector3(-1, 0, 0), 0.2, CREAM, Vector3.UP, 0.0)
	for wd in [["wheel_l", 1.0], ["wheel_r", -1.0]]:
		_wheel(md, wd[0], Vector3(float(wd[1]) * 1.0, 0.42, -0.3), 0.42, 0.16, float(wd[1]), Color(0.05, 0.05, 0.05), Color(0.8, 0.78, 0.7), seg)
	NewModels6.hull(md, Vector3(0, 0.95, 0.5), Vector3(2.1, 1.3, 5.0))

# ---------------------------------------------------------------- the recurring cases
static func _poster(md: NewModels6.Model) -> void:
	NewModels6.box(md, "paper", Vector3(0, 0.21, 0), Vector3(0.3, 0.42, 0.002), Color(0.95, 0.94, 0.88))
	NewModels6.text(md, "paper", "LOST", Vector3(0, 0.33, 0.0015), Vector3(0, 0, 1), 0.06, Color(0.7, 0.1, 0.08), Vector3.UP, 0.0)
	NewModels6.text(md, "paper", "DOG", Vector3(0, 0.27, 0.0015), Vector3(0, 0, 1), 0.05, Color(0.7, 0.1, 0.08), Vector3.UP, 0.0)
	NewModels6.box(md, "paper", Vector3(0, 0.17, 0.0015), Vector3(0.2, 0.09, 0.0006), Color(0.45, 0.5, 0.35))
	NewModels6.ball(md, "paper", Vector3(0.0, 0.17, 0.002), Vector3(0.045, 0.026, 0.0006), Color(0.62, 0.46, 0.24), 8)
	NewModels6.ball(md, "paper", Vector3(0.05, 0.19, 0.002), Vector3(0.016, 0.016, 0.0006), Color(0.62, 0.46, 0.24), 6)
	NewModels6.text(md, "paper", "REWARD", Vector3(0, 0.085, 0.0015), Vector3(0, 0, 1), 0.026, Color(0.1, 0.1, 0.12), Vector3.UP, 0.0)
	for k in 6:
		NewModels6.box(md, "paper", Vector3(-0.125 + k * 0.05, 0.02, 0.0015), Vector3(0.04, 0.036, 0.0006), Color(0.9, 0.9, 0.84))

static func _crop_circle(md: NewModels6.Model, lod: int) -> void:
	# a 14 m ring of laid-down barley in a standing field: swirled lay, a star in the middle, a wall of standing stalks round the edge
	var R := 7.0
	var rings := 10 if lod == 0 else 6
	var secs := 48 if lod == 0 else 24
	var f := func(r: float, a: float) -> Color:
		var band := int(r / R * 5.0)
		var lay := 0.5 + 0.5 * sin(a * (5.0 + band) + float(band) * 1.7)
		var star := absf(fposmod(a * 5.0 / TAU + 0.5, 1.0) - 0.5)
		var in_star := r < R * 0.45 and star < 0.5 - r / (R * 0.45) * 0.35
		var c := Color(0.72, 0.6, 0.3).lerp(Color(0.58, 0.46, 0.2), lay * 0.5)
		if in_star: c = Color(0.42, 0.33, 0.14).lerp(c, 0.25)
		if band % 2 == 1: c = c * 0.9
		return c
	for ri in rings:
		var r0 := R * ri / rings; var r1 := R * (ri + 1) / rings
		for si in secs:
			var a0 := TAU * si / secs; var a1 := TAU * (si + 1) / secs
			var c: Color = f.call((r0 + r1) * 0.5, (a0 + a1) * 0.5)
			var y := 0.03 + 0.015 * NewModels6.rnd(ri * 97 + si, 1.0)
			md.b("hay").quad(Vector3(cos(a0) * r0, y, sin(a0) * r0), Vector3(cos(a1) * r0, y, sin(a1) * r0), Vector3(cos(a1) * r1, y, sin(a1) * r1), Vector3(cos(a0) * r1, y, sin(a0) * r1), c, Vector3.UP)
	# the standing crop wall at the edge: short tufts of ears all round
	for k in (96 if lod == 0 else 40):
		var a := TAU * k / (96.0 if lod == 0 else 40.0)
		var base := Vector3(cos(a) * (R + 0.2), 0.0, sin(a) * (R + 0.2))
		NewModels6.limb(md, "hay", base, base + Vector3(cos(a) * 0.05, 0.9, sin(a) * 0.05), 0.012, 0.008, Color(0.74, 0.62, 0.3), 3)
		NewModels6.ball(md, "hay", base + Vector3(cos(a) * 0.05, 0.92, sin(a) * 0.05), Vector3(0.02, 0.07, 0.02), Color(0.8, 0.68, 0.34), 4)

static func decal(name: String) -> Image:
	# the stencil for the circle: a star in rings, white on transparent, 512 x 512
	var im := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	for y in 512:
		for x in 512:
			var d := Vector2(x - 256.0, y - 256.0).length()
			var a := atan2(y - 256.0, x - 256.0)
			var ring := (d > 236.0 and d < 250.0) or (d > 196.0 and d < 206.0) or (d > 150.0 and d < 158.0)
			var star := d < 140.0 and absf(fposmod(a * 5.0 / TAU + 0.5, 1.0) - 0.5) < 0.5 - d / 140.0 * 0.32 and d > 20.0
			var hub := d < 14.0
			if ring or star or hub: im.set_pixel(x, y, Color(1, 1, 1, 0.9))
	return im

static func _churn(md: NewModels6.Model) -> void:
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.15, 0.0), Vector2(0.17, 0.03), Vector2(0.17, 0.08), Vector2(0.14, 0.1), Vector2(0.14, 0.45), Vector2(0.16, 0.5), Vector2(0.175, 0.56), Vector2(0.15, 0.62),
		Vector2(0.095, 0.66), Vector2(0.095, 0.7), Vector2(0.12, 0.72), Vector2(0.12, 0.745), Vector2(0.0, 0.745)])
	NewModels6.put(md, "chrome", DroneParts.lathe(prof, 20), Transform3D.IDENTITY, Color(0.62, 0.64, 0.66), 0.04)
	NewModels6.cyl(md, "chrome", Vector3(0, 0.748, 0), Vector3(0, 0.76, 0), 0.11, 0.09, 14, Color(0.6, 0.62, 0.64), 3, 0.0)
	NewModels6.ball(md, "chrome", Vector3(0, 0.78, 0), Vector3(0.025, 0.02, 0.025), Color(0.6, 0.62, 0.64), 6)
	for sx: float in [-1.0, 1.0]:
		NewModels6.limb(md, "chrome", Vector3(sx * 0.15, 0.5, 0), Vector3(sx * 0.22, 0.46, 0), 0.01, 0.01, Color(0.58, 0.6, 0.62), 5)
		NewModels6.limb(md, "chrome", Vector3(sx * 0.22, 0.46, 0), Vector3(sx * 0.22, 0.34, 0), 0.01, 0.01, Color(0.58, 0.6, 0.62), 5)
		NewModels6.limb(md, "chrome", Vector3(sx * 0.22, 0.34, 0), Vector3(sx * 0.16, 0.3, 0), 0.01, 0.01, Color(0.58, 0.6, 0.62), 5)
	NewModels6.box(md, "rust", Vector3(0, 0.3, 0.165), Vector3(0.1, 0.06, 0.004), Color(0.6, 0.2, 0.1))
	NewModels6.hull(md, Vector3(0, 0.38, 0), Vector3(0.4, 0.76, 0.36))

static func _signal_lamp(md: NewModels6.Model) -> void:
	# a railway lamp on a low iron post: a lantern housing with a hood, a red lens that can glow, and a handle
	NewModels6.cyl(md, "paint", Vector3(0, 0.0, 0), Vector3(0, 1.8, 0), 0.05, 0.035, 10, IRON, 3, 0.04)
	NewModels6.cyl(md, "paint", Vector3(0, 0.0, 0), Vector3(0, 0.08, 0), 0.16, 0.1, 12, IRON, 3, 0.04)
	NewModels6.box(md, "paint", Vector3(0, 1.8, 0), Vector3(0.34, 0.5, 0.3), Color(0.12, 0.12, 0.12))
	NewModels6.box(md, "paint", Vector3(0, 2.1, 0.0), Vector3(0.38, 0.05, 0.34), Color(0.1, 0.1, 0.1), 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, 0.05))
	NewModels6.box(md, "paint", Vector3(0, 1.82, 0.17), Vector3(0.3, 0.02, 0.1), Color(0.1, 0.1, 0.1))
	NewModels6.limb(md, "steel", Vector3(-0.1, 2.12, 0.0), Vector3(0.0, 2.3, 0.0), 0.01, 0.01, IRON, 4)
	NewModels6.limb(md, "steel", Vector3(0.1, 2.12, 0.0), Vector3(0.0, 2.3, 0.0), 0.01, 0.01, IRON, 4)
	var lg := md.sub("lamp_glass", Vector3(0, 1.82, 0.16))
	NewModels6.cyl(lg, "lamp_red", Vector3(0, 1.82, 0.15), Vector3(0, 1.82, 0.19), 0.1, 0.1, 14, Color.WHITE, 3, 0.0)
	NewModels6.cyl(md, "chrome", Vector3(0, 1.82, 0.19), Vector3(0, 1.82, 0.2), 0.115, 0.115, 14, Color(0.4, 0.4, 0.42), 3, 0.0)
	NewModels6.hull(md, Vector3(0, 1.1, 0), Vector3(0.4, 2.3, 0.4))

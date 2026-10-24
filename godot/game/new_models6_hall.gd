class_name NewModels6Hall
extends RefCounted
## Story batch (models8), the fictional village of Halloway, phase one: the police house, the pub, the village hall, two shops and
## the street furniture (bus shelter, notice board, post box, bench, lamp post, bin, village sign). Brick and painted board from the
## farm kit's photographed sets, tile roofs from the brick set tinted, glass and warm window lights. Metres, +Z is the street front,
## origin on the ground at the middle of the footprint. Named sub-nodes: `window_light` (the lit panes, hide by day), `door`,
## `blue_lamp`, `lamp_glass`, `card_stand`. Lettering is real geometry from the block alphabet in new_models6.gd (fictional names).

const NAMES: Array[String] = [
	"town_police_house_a", "town_police_house_a_open", "town_pub_a", "town_village_hall_a", "town_shop_a", "town_shop_b",
	"town_bus_shelter_a", "town_noticeboard_a", "town_post_box_a", "town_bench_a", "town_lamp_post_a", "town_bin_a", "town_sign_halloway_a",
]

const WHITE := Color(0.88, 0.86, 0.8)
const IRON := Color(0.08, 0.09, 0.09)
const TIMBER := Color(0.46, 0.37, 0.26)

static func build(name: String, md: NewModels6.Model, lod: int) -> bool:
	match name:
		"town_police_house_a": _police(md, false, lod)
		"town_police_house_a_open": _police(md, true, lod)
		"town_pub_a": _pub(md, lod)
		"town_village_hall_a": _hall(md, lod)
		"town_shop_a": _shop(md, 0, lod)
		"town_shop_b": _shop(md, 1, lod)
		"town_bus_shelter_a": _shelter(md)
		"town_noticeboard_a": _noticeboard(md)
		"town_post_box_a": _postbox(md)
		"town_bench_a": _bench(md)
		"town_lamp_post_a": _lamp_post(md)
		"town_bin_a": _bin(md)
		"town_sign_halloway_a": _village_sign(md)
		_: return false
	return true

# ---------------------------------------------------------------- building helpers
## A window on a wall: frame, cross bars, glass, sill. c is the centre of the opening on the wall's face, n the outward normal.
static func _win(md: NewModels6.Model, c: Vector3, w: float, h: float, n: Vector3, trim: Color, lit := true, bars := 2) -> void:
	var r := Vector3.UP.cross(n).normalized()
	var bas := Basis(r, Vector3.UP, n)
	NewModels6.box(md, "paintwood", c + Vector3(0, h * 0.5 - 0.03, 0) + n * 0.03, Vector3(w + 0.1, 0.07, 0.1), trim, 0.0, Color(-1, 0, 0), bas)
	NewModels6.box(md, "paintwood", c + Vector3(0, -h * 0.5 + 0.03, 0) + n * 0.03, Vector3(w + 0.1, 0.07, 0.1), trim, 0.0, Color(-1, 0, 0), bas)
	for sx: float in [-1.0, 1.0]:
		NewModels6.box(md, "paintwood", c + r * (sx * (w * 0.5 + 0.02)) + n * 0.03, Vector3(0.07, h, 0.1), trim, 0.0, Color(-1, 0, 0), bas)
	if bars >= 1: NewModels6.box(md, "paintwood", c + n * 0.0, Vector3(0.04, h, 0.04), trim, 0.0, Color(-1, 0, 0), bas)
	if bars >= 2: NewModels6.box(md, "paintwood", c + n * 0.0, Vector3(w, 0.04, 0.04), trim, 0.0, Color(-1, 0, 0), bas)
	NewModels6.box(md, "paintwood", c + Vector3(0, -h * 0.5 - 0.05, 0) + n * 0.1, Vector3(w + 0.24, 0.05, 0.16), trim * 0.95, 0.0, Color(-1, 0, 0), bas)
	NewModels6.quad2(md, "glass", c - r * (w * 0.5) - Vector3(0, h * 0.5, 0) - n * 0.06, c + r * (w * 0.5) - Vector3(0, h * 0.5, 0) - n * 0.06,
		c + r * (w * 0.5) + Vector3(0, h * 0.5, 0) - n * 0.06, c - r * (w * 0.5) + Vector3(0, h * 0.5, 0) - n * 0.06, Color.WHITE)
	if lit:
		var wl := md.sub("window_light", Vector3.ZERO)
		NewModels6.quad2(wl, "warm", c - r * (w * 0.48) - Vector3(0, h * 0.48, 0) - n * 0.3, c + r * (w * 0.48) - Vector3(0, h * 0.48, 0) - n * 0.3,
			c + r * (w * 0.48) + Vector3(0, h * 0.48, 0) - n * 0.3, c - r * (w * 0.48) + Vector3(0, h * 0.48, 0) - n * 0.3, Color.WHITE, false)

## A panelled door: bottom-centre point c on the wall face.
static func _door(md: NewModels6.Model, c: Vector3, w: float, h: float, n: Vector3, col: Color, trim: Color) -> void:
	var r := Vector3.UP.cross(n).normalized()
	var bas := Basis(r, Vector3.UP, n)
	NewModels6.box(md, "paintwood", c + Vector3(0, h * 0.5, 0) - n * 0.04, Vector3(w, h, 0.06), col, 0.0, Color(-1, 0, 0), bas)
	for k in 2:
		for j in 2:
			NewModels6.box(md, "paintwood", c + Vector3(0, 0.45 + j * (h * 0.5 - 0.05), 0) + r * ((k - 0.5) * w * 0.4) + n * 0.0, Vector3(w * 0.36, h * 0.38 if j == 0 else h * 0.34, 0.02), col * 0.9, 0.0, Color(-1, 0, 0), bas)
	for sx: float in [-1.0, 1.0]:
		NewModels6.box(md, "paintwood", c + Vector3(0, h * 0.5, 0) + r * (sx * (w * 0.5 + 0.04)) + n * 0.02, Vector3(0.09, h + 0.1, 0.1), trim, 0.0, Color(-1, 0, 0), bas)
	NewModels6.box(md, "paintwood", c + Vector3(0, h + 0.07, 0) + n * 0.02, Vector3(w + 0.26, 0.09, 0.1), trim, 0.0, Color(-1, 0, 0), bas)
	NewModels6.ball(md, "chrome", c + Vector3(0, 1.0, 0) + r * (w * 0.38) + n * 0.04, Vector3(0.03, 0.03, 0.03), Color(0.7, 0.58, 0.28), 6)
	NewModels6.box(md, "stone", c + Vector3(0, 0.04, 0) + n * 0.25, Vector3(w + 0.4, 0.08, 0.6), Color(0.5, 0.5, 0.48), 0.0, Color(-1, 0, 0), bas)

## A gable roof of "tile" (the brick set tinted) over a W x D footprint at wall height WH. ridge_x: the ridge runs along x.
static func _roof(md: NewModels6.Model, W: float, D: float, WH: float, RH: float, col: Color, ridge_x := true) -> void:
	var over := 0.35
	if ridge_x:
		var ang := atan2(RH, D * 0.5)
		var slope := sqrt(RH * RH + D * D * 0.25) + over
		for sz: float in [-1.0, 1.0]:
			var c := Vector3(0, WH + RH * 0.5 + 0.05, sz * (D * 0.25 + 0.05))
			NewModels6.box(md, "brick", c, Vector3(W + 2.0 * over, 0.14, slope), col, 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, sz * ang))
		NewModels6.box(md, "brick", Vector3(0, WH + RH + 0.12, 0), Vector3(W + 2.0 * over, 0.12, 0.34), col * 0.8)
		for sx: float in [-1.0, 1.0]:
			NewModels6.sheet(md, "paintwood", [Vector3(sx * W * 0.5, WH, -D * 0.5), Vector3(sx * W * 0.5, WH, D * 0.5), Vector3(sx * W * 0.5, WH + RH, 0)], WHITE * 0.95, Vector3(sx, 0, 0))
	else:
		var ang2 := atan2(RH, W * 0.5)
		var slope2 := sqrt(RH * RH + W * W * 0.25) + over
		for sx: float in [-1.0, 1.0]:
			var c2 := Vector3(sx * (W * 0.25 + 0.05), WH + RH * 0.5 + 0.05, 0)
			NewModels6.box(md, "brick", c2, Vector3(slope2, 0.14, D + 2.0 * over), col, 0.0, Color(-1, 0, 0), Basis(Vector3.BACK, -sx * ang2))
		NewModels6.box(md, "brick", Vector3(0, WH + RH + 0.12, 0), Vector3(0.34, 0.12, D + 2.0 * over), col * 0.8)
		for sz: float in [-1.0, 1.0]:
			NewModels6.sheet(md, "paintwood", [Vector3(-W * 0.5, WH, sz * D * 0.5), Vector3(W * 0.5, WH, sz * D * 0.5), Vector3(0, WH + RH, sz * D * 0.5)], WHITE * 0.95, Vector3(0, 0, sz))

static func _chimney(md: NewModels6.Model, x: float, z: float, y0: float) -> void:
	NewModels6.box(md, "brick", Vector3(x, y0 + 0.9, z), Vector3(0.7, 1.8, 0.55), Color(0.62, 0.42, 0.34))
	NewModels6.box(md, "stone", Vector3(x, y0 + 1.84, z), Vector3(0.82, 0.1, 0.67), Color(0.5, 0.5, 0.48))
	for dx: float in [-0.14, 0.14]:
		NewModels6.cyl(md, "paint", Vector3(x + dx, y0 + 1.89, z), Vector3(x + dx, y0 + 2.25, z), 0.09, 0.075, 8, Color(0.62, 0.34, 0.2), 3, 0.05)

static func _floor_and_back(md: NewModels6.Model, W: float, D: float, WH: float, col: Color, back_wins: Array, side_wins: Array, key := "brick", trim := WHITE) -> void:
	_wall_back(md, key, col, W, D, WH, back_wins)
	# the two side walls (x = +-W/2), each with windows from side_wins [[z_from_front, w, h, y0]]
	for sx: float in [-1.0, 1.0]:
		var ops: Array = []
		for sw in side_wins: ops.append([float(sw[0]) - float(sw[1]) * 0.5, float(sw[0]) + float(sw[1]) * 0.5, float(sw[3]), float(sw[3]) + float(sw[2])])
		NewModels6Town._wall(md, key, col, Vector3(sx * W * 0.5, 0, D * 0.5), Vector3(sx * W * 0.5, 0, -D * 0.5), WH, 0.3, ops, Vector3(sx, 0, 0))
		for sw in side_wins:
			_win(md, Vector3(sx * W * 0.5, float(sw[3]) + float(sw[2]) * 0.5, D * 0.5 - float(sw[0])), float(sw[1]), float(sw[2]), Vector3(sx, 0, 0), trim, true, 1)
	NewModels6.box(md, "concrete", Vector3(0, 0.03, 0), Vector3(W - 0.4, 0.06, D - 0.4), Color(0.4, 0.38, 0.34))

static func _wall_back(md: NewModels6.Model, key: String, col: Color, W: float, D: float, WH: float, wins: Array) -> void:
	var ops: Array = []
	for w in wins: ops.append([float(w[0]) + W * 0.5 - float(w[1]) * 0.5, float(w[0]) + W * 0.5 + float(w[1]) * 0.5, float(w[3]), float(w[3]) + float(w[2])])
	NewModels6Town._wall(md, key, col, Vector3(-W * 0.5, 0, -D * 0.5), Vector3(W * 0.5, 0, -D * 0.5), WH, 0.3, ops, Vector3(0, 0, -1))
	for w in wins:
		_win(md, Vector3(float(w[0]), float(w[3]) + float(w[2]) * 0.5, -D * 0.5), float(w[1]), float(w[2]), Vector3(0, 0, -1), WHITE, true, 1)

## The front wall with its openings [x_centre, w, h, y0] and `doors` [x_centre, w, h].
static func _front(md: NewModels6.Model, key: String, col: Color, W: float, D: float, WH: float, wins: Array, doors: Array) -> void:
	var ops: Array = []
	for w in wins: ops.append([float(w[0]) + W * 0.5 - float(w[1]) * 0.5, float(w[0]) + W * 0.5 + float(w[1]) * 0.5, float(w[3]), float(w[3]) + float(w[2])])
	for dr in doors: ops.append([float(dr[0]) + W * 0.5 - float(dr[1]) * 0.5, float(dr[0]) + W * 0.5 + float(dr[1]) * 0.5, 0.0, float(dr[2])])
	NewModels6Town._wall(md, key, col, Vector3(-W * 0.5, 0, D * 0.5), Vector3(W * 0.5, 0, D * 0.5), WH, 0.3, ops, Vector3(0, 0, 1))

# ---------------------------------------------------------------- the police house
static func _police(md: NewModels6.Model, open: bool, lod: int) -> void:
	var W := 7.0; var D := 6.0; var WH := 3.7; var RH := 1.9
	var brick := Color(0.86, 0.78, 0.74)
	var wins := [[-2.3, 1.0, 1.3, 0.9], [2.3, 1.0, 1.3, 0.9], [-2.3, 0.9, 1.0, 2.5], [0.0, 0.9, 1.0, 2.5], [2.3, 0.9, 1.0, 2.5]]
	_front(md, "brick", brick, W, D, WH, wins, [[0.0, 1.0, 2.1]])
	for wn in wins:
		_win(md, Vector3(float(wn[0]), float(wn[3]) + float(wn[2]) * 0.5, D * 0.5), float(wn[1]), float(wn[2]), Vector3(0, 0, 1), WHITE, true, 2)
	var navy := Color(0.1, 0.16, 0.3)
	var d := md.sub("door", Vector3(-0.5, 0.0, D * 0.5))
	# the door: a single leaf hinged at the left post; open is swung inwards 100 degrees (the sub node's pivot is the hinge)
	var leaf := NewModels6.Model.new()
	NewModels6.box(leaf, "paintwood", Vector3(0.5, 1.05, -0.04), Vector3(1.0, 2.1, 0.06), navy)
	for j in 2:
		NewModels6.box(leaf, "paintwood", Vector3(0.5, 0.55 + j * 0.95, -0.01), Vector3(0.7, 0.8 if j == 0 else 0.6, 0.02), navy * 0.85)
	NewModels6.ball(leaf, "chrome", Vector3(0.9, 1.0, 0.0), Vector3(0.03, 0.03, 0.03), Color(0.7, 0.58, 0.28), 6)
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(100.0) if open else 0.0), Vector3(-0.5, 0.0, D * 0.5))
	for key in leaf.m:
		var buf: NewModels2.Buf = leaf.m[key]
		var dst := d.b(key)
		for i in buf.pos.size():
			dst.pos.append(xf * buf.pos[i]); dst.nrm.append((xf.basis * buf.nrm[i]).normalized()); dst.cols.append(buf.cols[i])
	NewModels6.box(md, "paint", Vector3(0, 1.05, D * 0.5 - 0.5), Vector3(0.9, 2.1, 0.04), Color(0.25, 0.2, 0.15) if open else navy, 0.0)
	for sx: float in [-1.0, 1.0]:
		NewModels6.box(md, "paintwood", Vector3(sx * 0.54, 1.1, D * 0.5 + 0.02), Vector3(0.09, 2.2, 0.1), WHITE)
	NewModels6.box(md, "paintwood", Vector3(0, 2.2, D * 0.5 + 0.02), Vector3(1.3, 0.09, 0.1), WHITE)
	NewModels6.box(md, "stone", Vector3(0, 0.04, D * 0.5 + 0.35), Vector3(1.4, 0.08, 0.7), Color(0.5, 0.5, 0.48))
	_floor_and_back(md, W, D, WH, brick, [[-2.0, 1.0, 1.3, 0.9], [2.0, 1.0, 1.3, 0.9], [-2.0, 0.9, 1.0, 2.5], [2.0, 0.9, 1.0, 2.5]], [[3.0, 1.0, 1.3, 0.9], [3.0, 0.9, 1.0, 2.5]])
	_roof(md, W, D, WH, RH, Color(0.46, 0.27, 0.22), true)
	_chimney(md, -2.4, 0.0, WH + 1.0)
	# the sign board over the door (HALLOWAY PROVINCIAL POLICE in white on blue) and the blue lamp on a bracket
	NewModels6.box(md, "paintwood", Vector3(0, 2.62, D * 0.5 + 0.1), Vector3(3.6, 0.26, 0.06), navy)
	NewModels6.text(md, "paintwood", "HALLOWAY PROVINCIAL POLICE", Vector3(0, 2.52, D * 0.5 + 0.14), Vector3(0, 0, 1), 0.14, Color(0.92, 0.92, 0.9), Vector3.UP, 0.0)
	NewModels6.limb(md, "steel", Vector3(1.0, 2.35, D * 0.5 + 0.05), Vector3(1.0, 2.35, D * 0.5 + 0.5), 0.012, 0.012, IRON, 5)
	var bl := md.sub("blue_lamp", Vector3(1.0, 2.35, D * 0.5 + 0.5))
	NewModels6.cyl(bl, "lamp_blue", Vector3(1.0, 2.2, D * 0.5 + 0.5), Vector3(1.0, 2.48, D * 0.5 + 0.5), 0.11, 0.11, 10, Color.WHITE, 3, 0.0)
	# the notice board beside the door: glass front, pinned papers
	NewModels6.box(md, "wood", Vector3(-1.2, 1.5, D * 0.5 + 0.06), Vector3(0.8, 1.0, 0.07), Color(0.3, 0.22, 0.14))
	NewModels6.box(md, "paper", Vector3(-1.2, 1.5, D * 0.5 + 0.1), Vector3(0.7, 0.9, 0.01), Color(0.4, 0.38, 0.3))
	for k in 6:
		NewModels6.box(md, "paper", Vector3(-1.4 + (k % 3) * 0.22, 1.2 + (k / 3) * 0.4, D * 0.5 + 0.11), Vector3(0.17, 0.25, 0.004), [Color(0.9, 0.9, 0.86), Color(0.9, 0.85, 0.55), Color(0.85, 0.9, 0.95)][k % 3], (NewModels6.rnd(k, 1.0) - 0.5) * 0.15)
	NewModels6.hull(md, Vector3(0, WH * 0.5, 0), Vector3(W, WH, D))
	NewModels6.hull(md, Vector3(0, WH + RH * 0.5, 0), Vector3(W, RH, D))

# ---------------------------------------------------------------- the pub
static func _pub(md: NewModels6.Model, lod: int) -> void:
	var W := 11.0; var D := 7.0; var WH := 4.0; var RH := 2.3
	var cream := Color(0.9, 0.85, 0.7)
	var green := Color(0.12, 0.26, 0.2)
	var wins := [[-3.6, 1.7, 1.4, 0.85], [2.4, 1.7, 1.4, 0.85], [4.3, 1.0, 1.4, 0.85], [-4.0, 0.95, 1.1, 2.5], [-1.4, 0.95, 1.1, 2.5], [1.4, 0.95, 1.1, 2.5], [4.0, 0.95, 1.1, 2.5]]
	_front(md, "paintwood", cream, W, D, WH, wins, [[-1.0, 1.2, 2.2]])
	for wn in wins:
		_win(md, Vector3(float(wn[0]), float(wn[3]) + float(wn[2]) * 0.5, D * 0.5), float(wn[1]), float(wn[2]), Vector3(0, 0, 1), green, true, 3)
	_door(md, Vector3(-1.0, 0.0, D * 0.5), 1.0, 2.1, Vector3(0, 0, 1), green, WHITE)
	# a small porch over the door and a painted skirting
	NewModels6.box(md, "brick", Vector3(-1.0, 2.55, D * 0.5 + 0.45), Vector3(2.0, 0.12, 1.1), Color(0.45, 0.26, 0.2))
	for sx: float in [-1.0, 1.0]:
		NewModels6.box(md, "paintwood", Vector3(-1.0 + sx * 0.95, 1.25, D * 0.5 + 0.95), Vector3(0.1, 2.5, 0.1), green)
	NewModels6.box(md, "paintwood", Vector3(0, 0.3, D * 0.5 + 0.01), Vector3(W, 0.6, 0.04), green)
	_floor_and_back(md, W, D, WH, cream, [[-3.0, 1.0, 1.3, 0.9], [3.0, 1.0, 1.3, 0.9], [-3.0, 0.9, 1.0, 2.6], [0.0, 0.9, 1.0, 2.6], [3.0, 0.9, 1.0, 2.6]], [[3.0, 1.0, 1.3, 0.9], [3.0, 0.9, 1.0, 2.6]], "paintwood")
	_roof(md, W, D, WH, RH, Color(0.34, 0.2, 0.17), true)
	_chimney(md, -4.0, 0.0, WH + 1.0)
	_chimney(md, 4.2, 0.0, WH + 1.0)
	# the hanging sign (THE PLOUGH) on an iron bracket at the left corner, and a bench under the big window
	NewModels6.limb(md, "steel", Vector3(-W * 0.5 + 0.3, 3.3, D * 0.5 + 0.05), Vector3(-W * 0.5 + 0.3, 3.3, D * 0.5 + 1.1), 0.02, 0.02, IRON, 5)
	NewModels6.limb(md, "steel", Vector3(-W * 0.5 + 0.3, 3.0, D * 0.5 + 0.05), Vector3(-W * 0.5 + 0.3, 3.3, D * 0.5 + 0.8), 0.012, 0.012, IRON, 5)
	NewModels6.box(md, "paintwood", Vector3(-W * 0.5 + 0.3, 2.85, D * 0.5 + 0.95), Vector3(0.06, 0.8, 0.9), Color(0.9, 0.84, 0.64))
	NewModels6.text(md, "paintwood", "THE", Vector3(-W * 0.5 + 0.35, 3.05, D * 0.5 + 0.95), Vector3(1, 0, 0), 0.14, Color(0.4, 0.15, 0.1), Vector3.UP, 0.0)
	NewModels6.text(md, "paintwood", "PLOUGH", Vector3(-W * 0.5 + 0.35, 2.82, D * 0.5 + 0.95), Vector3(1, 0, 0), 0.17, Color(0.4, 0.15, 0.1), Vector3.UP, 0.0)
	NewModels6.hull(md, Vector3(0, WH * 0.5, 0), Vector3(W, WH, D))
	NewModels6.hull(md, Vector3(0, WH + RH * 0.5, 0), Vector3(W, RH, D))

# ---------------------------------------------------------------- the village hall
static func _hall(md: NewModels6.Model, lod: int) -> void:
	var W := 12.0; var D := 8.0; var WH := 3.3; var RH := 3.0
	var cream := Color(0.88, 0.86, 0.78)
	var green := Color(0.14, 0.3, 0.22)
	# the hall's gable faces the street: a pair of tall windows and a porch with a double door
	var wins := [[-3.5, 1.1, 1.8, 1.0], [3.5, 1.1, 1.8, 1.0]]
	_front(md, "paintwood", cream, W, D, WH, wins, [[0.0, 1.8, 2.3]])
	for wn in wins:
		_win(md, Vector3(float(wn[0]), float(wn[3]) + float(wn[2]) * 0.5, D * 0.5), float(wn[1]), float(wn[2]), Vector3(0, 0, 1), green, true, 3)
	_door(md, Vector3(-0.45, 0.0, D * 0.5 + 0.9), 0.85, 2.1, Vector3(0, 0, 1), green, WHITE)
	_door(md, Vector3(0.45, 0.0, D * 0.5 + 0.9), 0.85, 2.1, Vector3(0, 0, 1), green, WHITE)
	# porch: two posts, a lean-to roof, side walls
	for sx: float in [-1.0, 1.0]:
		NewModels6.box(md, "paintwood", Vector3(sx * 1.2, 1.2, D * 0.5 + 1.0), Vector3(0.14, 2.4, 0.14), green)
		NewModels6.box(md, "paintwood", Vector3(sx * 1.2, 1.2, D * 0.5 + 0.5), Vector3(0.05, 2.4, 1.0), cream)
	NewModels6.box(md, "brick", Vector3(0, 2.75, D * 0.5 + 0.55), Vector3(3.0, 0.1, 1.5), Color(0.34, 0.2, 0.17), 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, 0.1))
	NewModels6.box(md, "concrete", Vector3(0, 0.05, D * 0.5 + 0.75), Vector3(3.0, 0.1, 1.5), Color(0.5, 0.48, 0.45))
	_floor_and_back(md, W, D, WH, cream, [[-3.0, 1.1, 1.8, 1.0], [3.0, 1.1, 1.8, 1.0]], [[1.8, 1.1, 1.8, 1.0], [4.0, 1.1, 1.8, 1.0], [6.2, 1.1, 1.8, 1.0]], "paintwood", green)
	_roof(md, W, D, WH, RH, Color(0.3, 0.2, 0.18), false)
	# the stage entrance at the back right and the name over the porch
	_door(md, Vector3(W * 0.5 - 0.01, 0.0, -D * 0.5 + 1.2), 0.9, 2.1, Vector3(1, 0, 0), green, WHITE)
	NewModels6.box(md, "paintwood", Vector3(0, 3.05, D * 0.5 + 0.05), Vector3(4.0, 0.34, 0.08), green)
	NewModels6.text(md, "paintwood", "VILLAGE HALL", Vector3(0, 2.92, D * 0.5 + 0.1), Vector3(0, 0, 1), 0.2, Color(0.9, 0.86, 0.7), Vector3.UP, 0.0)
	# a notice board on the front wall
	NewModels6.box(md, "wood", Vector3(5.0, 1.6, D * 0.5 + 0.06), Vector3(0.9, 1.1, 0.07), Color(0.3, 0.22, 0.14))
	for k in 6:
		NewModels6.box(md, "paper", Vector3(4.7 + (k % 3) * 0.3, 1.3 + (k / 3) * 0.5, D * 0.5 + 0.1), Vector3(0.23, 0.32, 0.004), [Color(0.9, 0.9, 0.86), Color(0.9, 0.7, 0.5), Color(0.8, 0.9, 0.85)][k % 3], (NewModels6.rnd(k, 3.0) - 0.5) * 0.2)
	NewModels6.hull(md, Vector3(0, WH * 0.5, 0), Vector3(W, WH, D))
	NewModels6.hull(md, Vector3(0, WH + RH * 0.5, 0), Vector3(W, RH, D))

# ---------------------------------------------------------------- the shops
static func _shop(md: NewModels6.Model, variant: int, lod: int) -> void:
	var W := 6.5; var D := 9.0; var WH := 4.3; var RH := 1.7
	var brick := Color(0.82, 0.74, 0.7) if variant == 0 else Color(0.62, 0.56, 0.52)
	var trim := Color(0.14, 0.3, 0.22) if variant == 0 else Color(0.12, 0.17, 0.3)
	var wins := [[0.4, 3.0, 1.9, 0.6], [-1.4, 0.9, 1.0, 2.9], [0.4, 0.9, 1.0, 2.9], [2.0, 0.9, 1.0, 2.9]]
	_front(md, "brick", brick, W, D, WH, wins, [[-2.3, 1.0, 2.1]])
	for wn in wins:
		_win(md, Vector3(float(wn[0]), float(wn[3]) + float(wn[2]) * 0.5, D * 0.5), float(wn[1]), float(wn[2]), Vector3(0, 0, 1), trim, true, 0 if float(wn[1]) > 2.0 else 2)
	_door(md, Vector3(-2.3, 0.0, D * 0.5), 0.9, 2.0, Vector3(0, 0, 1), trim, WHITE)
	# the fascia with the name, a striped awning over the window
	NewModels6.box(md, "paintwood", Vector3(0, 2.52, D * 0.5 + 0.1), Vector3(W - 0.2, 0.7, 0.12), trim)
	NewModels6.text(md, "paintwood", "HALLOWAY STORES" if variant == 0 else "MOTOR PARTS", Vector3(0, 2.34, D * 0.5 + 0.17), Vector3(0, 0, 1), 0.34, Color(0.9, 0.86, 0.7), Vector3.UP, 0.0)
	var aw := PackedVector3Array()
	for k in 8:
		var x0 := -1.5 + k * 0.4
		NewModels6.sheet(md, "canvas", [Vector3(x0, 2.1, D * 0.5 + 0.05), Vector3(x0 + 0.4, 2.1, D * 0.5 + 0.05), Vector3(x0 + 0.4, 1.9, D * 0.5 + 0.95), Vector3(x0, 1.9, D * 0.5 + 0.95)], trim if k % 2 == 0 else CREAM_S, Vector3(0, 0.3, 1))
	for sx: float in [-1.0, 1.0]:
		NewModels6.limb(md, "steel", Vector3(sx * 1.6, 2.0, D * 0.5 + 0.95), Vector3(sx * 1.6, 0.0, D * 0.5 + 0.95), 0.015, 0.015, IRON, 5)
	_floor_and_back(md, W, D, WH, brick, [[-1.5, 1.0, 1.3, 1.0], [1.5, 1.0, 1.3, 1.0], [-1.5, 0.9, 1.0, 2.9], [1.5, 0.9, 1.0, 2.9]], [[3.0, 1.0, 1.2, 1.0], [6.0, 1.0, 1.2, 1.0], [3.0, 0.9, 1.0, 2.9], [6.0, 0.9, 1.0, 2.9]])
	_roof(md, W, D, WH, RH, Color(0.34, 0.22, 0.2), true)
	_chimney(md, 1.8, -1.5, WH + 0.8)
	if variant == 0:
		# the postcard stand: a rotating wire rack of cards beside the window, a node of its own
		var cs := md.sub("card_stand", Vector3(2.5, 0.0, D * 0.5 + 0.55))
		NewModels6.limb(cs, "steel", Vector3(2.5, 0.0, D * 0.5 + 0.55), Vector3(2.5, 1.55, D * 0.5 + 0.55), 0.02, 0.02, IRON, 6)
		for k in 6:
			var a := TAU * k / 6.0
			for j in 4:
				var c := Vector3(2.5 + cos(a) * 0.14, 0.7 + j * 0.24, D * 0.5 + 0.55 + sin(a) * 0.14)
				NewModels6.box(cs, "paper", c, Vector3(0.1, 0.15, 0.004), [Color(0.5, 0.7, 0.85), Color(0.9, 0.8, 0.4), Color(0.8, 0.45, 0.4), Color(0.6, 0.8, 0.55)][(k + j) % 4], -a)
	else:
		# a stack of tyres and a sandwich board outside the parts shop
		for k in 3:
			NewModels6.cyl(md, "rubber", Vector3(2.4, 0.1 + k * 0.2, D * 0.5 + 0.7), Vector3(2.4, 0.2 + k * 0.2, D * 0.5 + 0.7), 0.3, 0.3, 14, Color(0.07, 0.07, 0.07), 3, 0.08)
		NewModels6.box(md, "wood", Vector3(-2.3, 0.45, D * 0.5 + 0.9), Vector3(0.55, 0.8, 0.04), Color(0.1, 0.12, 0.1), 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, 0.2))
	NewModels6.hull(md, Vector3(0, WH * 0.5, 0), Vector3(W, WH, D))
	NewModels6.hull(md, Vector3(0, WH + RH * 0.5, 0), Vector3(W, RH, D))

const CREAM_S := Color(0.86, 0.82, 0.68)

# ---------------------------------------------------------------- street furniture
static func _shelter(md: NewModels6.Model) -> void:
	var col := Color(0.28, 0.4, 0.3)
	for sx: float in [-1.2, 1.2]:
		for sz: float in [-0.6, 0.6]:
			NewModels6.box(md, "wood", Vector3(sx, 1.1, sz), Vector3(0.1, 2.2, 0.1), TIMBER)
	for k in 8:
		NewModels6.box(md, "wood", Vector3(0, 0.3 + k * 0.17, -0.62), Vector3(2.4, 0.15, 0.03), col * (0.9 + 0.1 * NewModels6.rnd(k, 1.0)))
		if k < 8:
			for sx: float in [-1.0, 1.0]:
				NewModels6.box(md, "wood", Vector3(sx * 1.22, 0.3 + k * 0.17, 0.0), Vector3(0.03, 0.15, 1.2), col * (0.9 + 0.1 * NewModels6.rnd(k + sx, 2.0)))
	NewModels6.box(md, "wood", Vector3(0, 2.3, 0), Vector3(2.8, 0.1, 1.5), Color(0.2, 0.2, 0.2), 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, 0.08))
	NewModels6.box(md, "wood", Vector3(0, 0.5, -0.4), Vector3(2.0, 0.05, 0.4), TIMBER * 1.1, 0.0, Color(0.5, 0.42, 0.3))
	NewModels6.box(md, "paper", Vector3(0, 1.45, -0.6), Vector3(0.7, 0.9, 0.01), Color(0.9, 0.9, 0.86))
	NewModels6.text(md, "paper", "HALLOWAY", Vector3(0, 1.78, -0.59), Vector3(0, 0, 1), 0.07, Color(0.1, 0.25, 0.17), Vector3.UP, 0.0)
	for k in 7:
		NewModels6.box(md, "paper", Vector3(0, 1.62 - k * 0.1, -0.595), Vector3(0.55 - NewModels6.rnd(k, 3.0) * 0.12, 0.002, 0.014), Color(0.25, 0.25, 0.3))
	NewModels6.hull(md, Vector3(0, 1.15, 0), Vector3(2.8, 2.3, 1.5))

static func _noticeboard(md: NewModels6.Model) -> void:
	for sx: float in [-0.85, 0.85]:
		NewModels6.box(md, "wood", Vector3(sx, 1.05, 0), Vector3(0.12, 2.1, 0.12), TIMBER)
	NewModels6.box(md, "wood", Vector3(0, 1.45, 0), Vector3(1.9, 1.15, 0.08), Color(0.3, 0.22, 0.14))
	NewModels6.box(md, "paper", Vector3(0, 1.45, 0.045), Vector3(1.75, 1.0, 0.01), Color(0.42, 0.38, 0.28))
	NewModels6.box(md, "wood", Vector3(0, 2.1, 0.0), Vector3(2.1, 0.12, 0.28), Color(0.28, 0.2, 0.14), 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, 0.1))
	for k in 12:
		var cc: Color = [Color(0.92, 0.92, 0.88), Color(0.92, 0.85, 0.5), Color(0.85, 0.9, 0.95), Color(0.9, 0.7, 0.65)][k % 4]
		NewModels6.box(md, "paper", Vector3(-0.7 + (k % 4) * 0.46, 1.8 - (k / 4) * 0.34, 0.05), Vector3(0.28, 0.24 + 0.08 * (k % 3), 0.004), cc, (NewModels6.rnd(k, 4.0) - 0.5) * 0.2)
	NewModels6.text(md, "paintwood", "NOTICES", Vector3(0, 2.14, 0.15), Vector3(0, 0, 1), 0.1, Color(0.9, 0.86, 0.7), Vector3.UP, 0.0)
	NewModels6.quad2(md, "glass", Vector3(-0.85, 0.92, 0.07), Vector3(0.85, 0.92, 0.07), Vector3(0.85, 1.95, 0.07), Vector3(-0.85, 1.95, 0.07), Color.WHITE)
	NewModels6.hull(md, Vector3(0, 1.1, 0), Vector3(2.0, 2.2, 0.3))

static func _postbox(md: NewModels6.Model) -> void:
	var red := Color(0.62, 0.08, 0.06)
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.26, 0.0), Vector2(0.26, 0.06), Vector2(0.21, 0.08), Vector2(0.21, 0.12), Vector2(0.22, 0.14), Vector2(0.22, 1.0), Vector2(0.24, 1.04), Vector2(0.24, 1.1), Vector2(0.2, 1.18), Vector2(0.1, 1.27), Vector2(0.0, 1.3)])
	NewModels6.put(md, "gloss", DroneParts.lathe(prof, 20), Transform3D.IDENTITY, red, 0.04)
	NewModels6.box(md, "paint", Vector3(0, 1.0, 0.22), Vector3(0.28, 0.04, 0.03), Color(0.03, 0.03, 0.03))
	NewModels6.box(md, "chrome", Vector3(0, 0.55, 0.222), Vector3(0.14, 0.1, 0.005), Color(0.75, 0.62, 0.3))
	NewModels6.hull(md, Vector3(0, 0.65, 0), Vector3(0.55, 1.3, 0.55))

static func _bench(md: NewModels6.Model) -> void:
	for k in 4:
		NewModels6.box(md, "wood", Vector3(0, 0.45, -0.18 + k * 0.12), Vector3(1.7, 0.035, 0.1), Color(0.48, 0.38, 0.26), 0.0, Color(0.52, 0.42, 0.3))
	for k in 3:
		NewModels6.box(md, "wood", Vector3(0, 0.62 + k * 0.12, -0.24 - k * 0.025), Vector3(1.7, 0.1, 0.03), Color(0.48, 0.38, 0.26), 0.0)
	for sx: float in [-0.78, 0.78]:
		NewModels6.box(md, "steel", Vector3(sx, 0.22, 0.0), Vector3(0.05, 0.45, 0.45), IRON)
		NewModels6.box(md, "steel", Vector3(sx, 0.7, -0.25), Vector3(0.05, 0.5, 0.05), IRON, 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, -0.12))
		NewModels6.box(md, "steel", Vector3(sx, 0.42, 0.0), Vector3(0.05, 0.04, 0.48), IRON)
	NewModels6.hull(md, Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 0.55))

static func _lamp_post(md: NewModels6.Model) -> void:
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.13, 0.0), Vector2(0.13, 0.1), Vector2(0.09, 0.2), Vector2(0.065, 0.5), Vector2(0.05, 0.6), Vector2(0.04, 3.5), Vector2(0.06, 3.55), Vector2(0.06, 3.62), Vector2(0.0, 3.65)])
	NewModels6.put(md, "paint", DroneParts.lathe(prof, 12), Transform3D.IDENTITY, IRON, 0.05)
	NewModels6.limb(md, "paint", Vector3(0, 3.5, 0), Vector3(0.45, 3.75, 0), 0.025, 0.02, IRON, 6)
	NewModels6.cyl(md, "paint", Vector3(0.45, 3.5, 0), Vector3(0.45, 3.6, 0), 0.13, 0.17, 8, IRON, 3, 0.04)
	NewModels6.cyl(md, "paint", Vector3(0.45, 3.68, 0), Vector3(0.45, 3.82, 0), 0.2, 0.04, 8, IRON, 3, 0.04)
	var lg := md.sub("lamp_glass", Vector3(0.45, 3.6, 0))
	NewModels6.ball(lg, "lamp", Vector3(0.45, 3.58, 0), Vector3(0.09, 0.1, 0.09), Color.WHITE, 8)
	NewModels6.hull(md, Vector3(0, 1.8, 0), Vector3(0.3, 3.6, 0.3))

static func _bin(md: NewModels6.Model) -> void:
	var prof := PackedVector2Array([Vector2(0.0, 0.05), Vector2(0.2, 0.05), Vector2(0.22, 0.1), Vector2(0.24, 0.85), Vector2(0.255, 0.9), Vector2(0.255, 0.94), Vector2(0.2, 0.94), Vector2(0.2, 0.88), Vector2(0.0, 0.88)])
	NewModels6.put(md, "paint", DroneParts.lathe(prof, 16), Transform3D.IDENTITY, Color(0.1, 0.22, 0.17), 0.05)
	for k in 3:
		NewModels6.cyl(md, "paint", Vector3(0, 0.3 + k * 0.22, 0), Vector3(0, 0.32 + k * 0.22, 0), 0.248, 0.248, 16, Color(0.06, 0.14, 0.1), 3, 0.0)
	for sx: float in [-1.0, 1.0]:
		NewModels6.limb(md, "steel", Vector3(sx * 0.15, 0.05, 0.0), Vector3(sx * 0.15, 0.0, 0.0), 0.02, 0.02, IRON, 5)
	NewModels6.hull(md, Vector3(0, 0.47, 0), Vector3(0.52, 0.94, 0.52))

static func _village_sign(md: NewModels6.Model) -> void:
	NewModels6.box(md, "wood", Vector3(0, 1.3, 0), Vector3(0.14, 2.6, 0.14), TIMBER)
	NewModels6.box(md, "wood", Vector3(0.45, 2.45, 0), Vector3(1.0, 0.08, 0.08), TIMBER)
	NewModels6.box(md, "paintwood", Vector3(0.65, 1.9, 0), Vector3(1.2, 0.8, 0.06), Color(0.12, 0.27, 0.2))
	NewModels6.box(md, "paintwood", Vector3(0.65, 1.9, 0.035), Vector3(1.12, 0.72, 0.01), Color(0.88, 0.84, 0.66))
	NewModels6.text(md, "paintwood", "HALLOWAY", Vector3(0.65, 1.78, 0.045), Vector3(0, 0, 1), 0.17, Color(0.12, 0.27, 0.2), Vector3.UP, 0.0)
	NewModels6.text(md, "paintwood", "HALLOWAY", Vector3(0.65, 1.78, -0.045), Vector3(0, 0, -1), 0.17, Color(0.12, 0.27, 0.2), Vector3.UP, 0.0)
	# an emblem: a small bus on the board (a green box with two wheels)
	NewModels6.box(md, "paintwood", Vector3(0.65, 2.1, 0.045), Vector3(0.32, 0.12, 0.006), Color(0.12, 0.27, 0.2))
	for sx: float in [-0.1, 0.1]:
		NewModels6.cyl(md, "paintwood", Vector3(0.65 + sx, 2.03, 0.047), Vector3(0.65 + sx, 2.03, 0.052), 0.025, 0.025, 8, Color(0.1, 0.1, 0.1), 3, 0.0)
	for sx: float in [0.12, 1.18]:
		NewModels6.limb(md, "steel", Vector3(sx, 2.45, 0), Vector3(sx, 2.3, 0), 0.006, 0.006, IRON, 4)
	NewModels6.hull(md, Vector3(0.4, 1.3, 0), Vector3(1.4, 2.6, 0.2))

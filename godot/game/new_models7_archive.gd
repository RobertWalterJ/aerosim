class_name NewModels7Archive
extends RefCounted
## Story batch 9 (models9), part A2: the weather archive and the later storm props. Priority 0: the old weather station, rain gauge,
## storm glass and barometer, the storm diary, an archive box and a child's drawing of a funnel (the festival programme is
## camp_programme_a from batch 8). Priority 1: the chapel bell with its rope (the rope is its own node), a hurricane lantern lit and
## unlit, a coat on a fence post that reads as a person from far off, Tom's storm logbook, the old festival map, sandbags and a
## storm tarpaulin (the railway signal lamp is railway_signal_lamp_a from batch 8). Priority 2: the shelter and chapel interior
## shells, a railway hut, a flooded ditch, a fallen power line (dead, with a cone), a storm-damaged village sign and two crowd poses.
## Metres, +Z front, origin at the base. No colliders except the rail hut. Nothing gory, no real insignia.

const NAMES: Array[String] = [
	"storm_weather_station_a", "storm_rain_gauge_a", "storm_glass_a", "storm_barometer_a", "storm_diary_a", "storm_diary_a_open", "storm_archive_box_a", "storm_drawing_a",
	"storm_bell_a", "storm_bell_a_knotted", "storm_lantern_a", "storm_lantern_a_off", "storm_coat_post_a", "storm_logbook_a", "storm_logbook_a_open", "storm_map_a",
	"storm_sandbags_a", "storm_tarp_a",
	"storm_shelter_interior_a", "storm_chapel_interior_a", "storm_rail_hut_a", "storm_ditch_flooded_a", "storm_power_line_a", "storm_sign_damaged_a",
	"storm_crowd_watching_a", "storm_crowd_sheltering_a",
]

const OAK := Color(0.33, 0.24, 0.15)
const IRON := Color(0.09, 0.09, 0.1)
const BRONZE := Color(0.5, 0.33, 0.15)
const PAPER := Color(0.88, 0.84, 0.7)
const WHITE_P := Color(0.84, 0.82, 0.76)
const STONE_C := Color(0.5, 0.48, 0.44)
const INK := Color(0.1, 0.08, 0.06)

static func build(name: String, md: NewModels6.Model, lod: int) -> bool:
	match name:
		"storm_weather_station_a": _station(md, lod)
		"storm_rain_gauge_a": _rain_gauge(md)
		"storm_glass_a": _storm_glass(md)
		"storm_barometer_a": _barometer(md)
		"storm_diary_a": _diary(md, false)
		"storm_diary_a_open": _diary(md, true)
		"storm_archive_box_a": _archive_box(md)
		"storm_drawing_a": _drawing(md)
		"storm_bell_a": _bell(md, false, lod)
		"storm_bell_a_knotted": _bell(md, true, lod)
		"storm_lantern_a": _lantern(md, true)
		"storm_lantern_a_off": _lantern(md, false)
		"storm_coat_post_a": _coat_post(md, lod)
		"storm_logbook_a": _logbook(md, false)
		"storm_logbook_a_open": _logbook(md, true)
		"storm_map_a": _map(md)
		"storm_sandbags_a": _sandbags(md)
		"storm_tarp_a": _tarp(md, lod)
		"storm_shelter_interior_a": _shelter_inside(md, lod)
		"storm_chapel_interior_a": _chapel_inside(md, lod)
		"storm_rail_hut_a": _rail_hut(md, lod)
		"storm_ditch_flooded_a": _ditch(md, lod)
		"storm_power_line_a": _power_line(md)
		"storm_sign_damaged_a": _sign(md)
		"storm_crowd_watching_a": _crowd(md, "watch", lod)
		"storm_crowd_sheltering_a": _crowd(md, "shelter", lod)
		_: return false
	return true

## Rows of wobbly "handwriting" strokes on a flat page: `centre` is the page middle, half size (hw across x, hd along z), strokes lie on the page plane.
static func _scribble(md: NewModels6.Model, centre: Vector3, hw: float, hd: float, lines: int, col: Color, salt: float) -> void:
	for l in lines:
		var z := -hd + (l + 0.5) * (2.0 * hd / lines)
		var x0 := -hw + 0.01
		var x1 := hw - 0.01 - 0.55 * hw * NewModels6.rnd(l, salt)
		var prev := Vector3(x0, 0.0, z)
		for k in range(1, 7):
			var x := lerpf(x0, x1, float(k) / 6.0)
			var p := Vector3(x, 0.0, z + 0.003 * sin(k * 2.7 + l))
			if NewModels6.rnd(l * 9 + k, salt + 3.0) > 0.18:
				NewModels6.limb(md, "paper", centre + prev, centre + p, 0.0012, 0.0012, col, 3)
			prev = p

# ================================================================== the archive
static func _station(md: NewModels6.Model, lod: int) -> void:
	# a Stevenson screen on four legs (0.62 x 0.46 x 0.44 m, louvred, white paint gone grey) and a steel mast with a cup anemometer and a vane (each its own node)
	var paint := Color(0.8, 0.78, 0.72)
	var cy := 1.3
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			NewModels7.board(md, "wood", Vector3(sx * 0.27, 0.0, sz * 0.17), Vector3(sx * 0.27, cy - 0.23, sz * 0.17), 0.06, 0.06, NewModels7.W(Color(0.55, 0.52, 0.46), 1.0))
	NewModels6.box(md, "paintwood", Vector3(0, cy - 0.215, 0), Vector3(0.62, 0.03, 0.4), paint)
	NewModels6.box(md, "paintwood", Vector3(0, cy + 0.0, -0.194), Vector3(0.62, 0.42, 0.012), paint * 0.96)
	var n := 9 if lod == 0 else 5
	for k in n:
		var y := cy - 0.19 + k * (0.38 / (n - 1))
		for sx: float in [-1.0, 1.0]:
			NewModels6.box(md, "paintwood", Vector3(sx * 0.305, y, 0.0), Vector3(0.012, 0.045, 0.4), paint * (0.95 + 0.04 * (k % 2)), 0.0, Color(-1, 0, 0), Basis(Vector3.BACK, sx * 0.62))
		NewModels6.box(md, "paintwood", Vector3(0, y, 0.2), Vector3(0.58, 0.045, 0.012), paint * (0.95 + 0.04 * (k % 2)), 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, 0.62))
	NewModels6.box(md, "paintwood", Vector3(0, cy + 0.255, 0), Vector3(0.7, 0.03, 0.5), paint, 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, 0.05))
	NewModels6.box(md, "steel", Vector3(0.24, cy + 0.03, 0.215), Vector3(0.03, 0.12, 0.012), Color(0.3, 0.3, 0.3))
	NewModels6.cyl(md, "chrome", Vector3(0, cy - 0.08, 0.0), Vector3(0, cy + 0.14, 0.0), 0.006, 0.006, 6, Color(0.7, 0.7, 0.72), 3, 0.0)
	var mx := 0.9
	var metal := Color(0.5, 0.52, 0.55)
	NewModels6.limb(md, "steel", Vector3(mx, 0, 0.0), Vector3(mx, 2.55, 0.0), 0.04, 0.025, metal, 8)
	NewModels6.ball(md, "concrete", Vector3(mx, 0.04, 0), Vector3(0.2, 0.08, 0.2), Color(0.55, 0.54, 0.5), 7, Basis.IDENTITY, 0.1)
	var cups := md.sub("cups", Vector3(mx, 3.05, 0.0))
	NewModels6.limb(cups, "steel", Vector3(mx, 2.95, 0), Vector3(mx, 3.1, 0), 0.015, 0.015, metal, 6)
	var cup := PackedVector2Array([Vector2(0.0, -0.04), Vector2(0.03, -0.035), Vector2(0.05, 0.0), Vector2(0.052, 0.02), Vector2(0.045, 0.03), Vector2(0.04, 0.02), Vector2(0.04, -0.005), Vector2(0.0, -0.03)])
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		var tip := Vector3(mx + cos(a) * 0.19, 3.05, sin(a) * 0.19)
		NewModels6.limb(cups, "steel", Vector3(mx, 3.05, 0), tip, 0.006, 0.006, metal, 4)
		NewModels6.put(cups, "sheet", DroneParts.lathe(cup, 10), Transform3D(Basis(Vector3.UP, -a) * Basis(Vector3.BACK, PI * 0.5), tip), Color(0.8, 0.82, 0.84), 0.0)
	var vane := md.sub("vane", Vector3(mx, 2.64, 0.0))
	NewModels6.limb(vane, "steel", Vector3(mx, 2.55, 0), Vector3(mx, 2.7, 0), 0.01, 0.01, metal, 5)
	NewModels6.limb(vane, "steel", Vector3(mx, 2.64, -0.28), Vector3(mx, 2.64, 0.3), 0.007, 0.007, metal, 5)
	NewModels6.quad2(vane, "sheet", Vector3(mx, 2.58, -0.28), Vector3(mx, 2.7, -0.28), Vector3(mx, 2.74, -0.46), Vector3(mx, 2.54, -0.46), Color(0.2, 0.2, 0.22))
	NewModels6.limb(vane, "steel", Vector3(mx, 2.64, 0.3), Vector3(mx, 2.64, 0.38), 0.016, 0.0, Color(0.2, 0.2, 0.22), 5)

static func _rain_gauge(md: NewModels6.Model) -> void:
	# a copper rain gauge: a funnel and cylinder on a post, a measuring glass beside it
	NewModels7.board(md, "wood", Vector3(0, 0.0, 0), Vector3(0, 0.95, 0), 0.09, 0.09, NewModels7.W(Color(0.5, 0.47, 0.4), 1.0))
	NewModels6.box(md, "wood", Vector3(0, 0.95, 0), Vector3(0.22, 0.03, 0.22), NewModels7.W(OAK, 0.75))
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.075, 0.0), Vector2(0.078, 0.01), Vector2(0.078, 0.3), Vector2(0.08, 0.31), Vector2(0.1, 0.34), Vector2(0.1, 0.36), Vector2(0.095, 0.36), Vector2(0.092, 0.34),
		Vector2(0.06, 0.32), Vector2(0.01, 0.3), Vector2(0.0, 0.3)])
	NewModels6.put(md, "chrome", DroneParts.lathe(prof, 20), Transform3D(Basis.IDENTITY, Vector3(0, 0.965, 0)), Color(0.68, 0.4, 0.22), 0.08)
	NewModels6.cyl(md, "glass", Vector3(0.18, 0.0, 0.08), Vector3(0.18, 0.2, 0.08), 0.02, 0.02, 10, Color.WHITE, 3, 0.0)
	for k in 9:
		NewModels6.box(md, "paper", Vector3(0.18, 0.02 + k * 0.02, 0.1), Vector3(0.012 if k % 2 == 0 else 0.007, 0.002, 0.003), Color(0.1, 0.1, 0.1))

static func _storm_glass(md: NewModels6.Model) -> void:
	# a sealed glass ampoule of cloudy liquid with feathery crystals, on a turned wooden base with a brass cap
	var wood := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.065, 0.0), Vector2(0.068, 0.01), Vector2(0.05, 0.02), Vector2(0.03, 0.03), Vector2(0.024, 0.05), Vector2(0.03, 0.06), Vector2(0.0, 0.06)])
	NewModels6.put(md, "wood", DroneParts.lathe(wood, 16), Transform3D.IDENTITY, NewModels7.W(OAK * 1.1, 1.0), 0.05)
	var glass := PackedVector2Array([Vector2(0.0, 0.06), Vector2(0.022, 0.06), Vector2(0.03, 0.08), Vector2(0.032, 0.16), Vector2(0.03, 0.27), Vector2(0.022, 0.31), Vector2(0.01, 0.32), Vector2(0.0, 0.322)])
	NewModels6.put(md, "glass", DroneParts.lathe(glass, 16), Transform3D.IDENTITY, Color.WHITE, 0.0)
	for k in 14:
		var y := 0.09 + 0.2 * NewModels6.rnd(k, 5.0)
		var a := NewModels6.rnd(k, 6.0) * TAU
		var p := Vector3(cos(a) * 0.012, y, sin(a) * 0.012)
		var d := Vector3(cos(a) * 0.014, 0.025 + 0.02 * NewModels6.rnd(k, 7.0), sin(a) * 0.014)
		NewModels6.limb(md, "paper", p, p + d, 0.0016, 0.0004, Color(0.92, 0.92, 0.9), 3)
	NewModels6.cyl(md, "chrome", Vector3(0, 0.31, 0), Vector3(0, 0.326, 0), 0.016, 0.012, 10, Color(0.75, 0.58, 0.22), 3, 0.0)

static func _barometer(md: NewModels6.Model) -> void:
	# a round aneroid barometer in a wooden case on an easel leg: brass bezel, cream dial with words, needle and setting hand
	var r := 0.11
	var c := Vector3(0, 0.17, 0)
	var rot := Basis(Vector3.RIGHT, -0.28)
	var face_basis := rot * Basis(Vector3.RIGHT, PI * 0.5)
	var nz := rot * Vector3(0, 0, 1)
	var wood := PackedVector2Array([Vector2(0.0, -0.03), Vector2(r + 0.03, -0.03), Vector2(r + 0.035, -0.02), Vector2(r + 0.035, 0.02), Vector2(r + 0.012, 0.012), Vector2(0.0, 0.012)])
	NewModels6.put(md, "wood", DroneParts.lathe(wood, 28), Transform3D(face_basis, c), NewModels7.W(OAK, 1.0), 0.05)
	NewModels6.put(md, "chrome", DroneParts.lathe(PackedVector2Array([Vector2(r + 0.002, 0.0), Vector2(r + 0.012, 0.0), Vector2(r + 0.012, 0.012), Vector2(r, 0.016), Vector2(r - 0.004, 0.012), Vector2(r - 0.004, 0.0)]), 28),
		Transform3D(face_basis, c + nz * 0.022), Color(0.75, 0.58, 0.22), 0.0)
	NewModels6.put(md, "paper", DroneParts.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(r - 0.004, 0.0)]), 28), Transform3D(face_basis, c + nz * 0.0205), Color(0.9, 0.86, 0.72), 0.02)
	var face := c + nz * 0.0225
	for k in 36:
		var a := TAU * k / 36.0
		var ln := 0.014 if k % 3 == 0 else 0.008
		var d := rot * Vector3(sin(a), cos(a), 0.0)
		NewModels6.limb(md, "paper", face + d * (r - 0.012 - ln), face + d * (r - 0.012), 0.0012, 0.0012, INK, 3)
	var up := rot * Vector3.UP
	NewModels6.text(md, "paper", "STORM", face + rot * Vector3(-0.045, -0.025, 0.0), nz, 0.011, INK, up, 0.0)
	NewModels6.text(md, "paper", "FAIR", face + rot * Vector3(0.045, -0.025, 0.0), nz, 0.011, INK, up, 0.0)
	NewModels6.text(md, "paper", "RAIN", face + rot * Vector3(0.0, 0.05, 0.0), nz, 0.011, INK, up, 0.0)
	var nd := rot * Vector3(sin(-1.1), cos(-1.1), 0.0)
	NewModels6.limb(md, "chrome", face - nd * 0.02 + nz * 0.004, face + nd * (r - 0.014) + nz * 0.004, 0.0028, 0.0006, Color(0.04, 0.04, 0.05), 4)
	NewModels6.limb(md, "chrome", face + nz * 0.004, face + rot * Vector3(sin(0.5), cos(0.5), 0.0) * (r - 0.03) + nz * 0.0025, 0.0018, 0.0006, Color(0.75, 0.58, 0.22), 4)
	NewModels6.cyl(md, "chrome", face, face + nz * 0.01, 0.008, 0.008, 8, Color(0.75, 0.58, 0.22), 3, 0.0)
	NewModels6.put(md, "glass", DroneParts.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(r - 0.004, 0.0)]), 24), Transform3D(face_basis, face + nz * 0.011), Color.WHITE, 0.0)
	NewModels7.board(md, "wood", c + rot * Vector3(0, -0.06, -0.03), Vector3(0, 0.0, -0.17), 0.04, 0.012, NewModels7.W(OAK * 0.9, 1.0), Vector3.RIGHT)
	NewModels6.box(md, "wood", Vector3(0, 0.006, 0.05), Vector3(0.22, 0.012, 0.06), NewModels7.W(OAK, 0.75))

static func _diary(md: NewModels6.Model, open: bool) -> void:
	# a leather-bound diary, 0.2 x 0.28 m and 45 mm thick, with raised bands on the spine and a ribbon; open it lies flat showing ruled pages
	var leather := Color(0.24, 0.12, 0.07)
	if not open:
		NewModels6.box(md, "paper", Vector3(0.004, 0.0225, 0.002), Vector3(0.188, 0.036, 0.272), PAPER * 0.92)
		NewModels6.rbox(md, "leather", Vector3(0, 0.0225, 0), Vector3(0.2, 0.045, 0.28), leather, Basis.IDENTITY, 5.0, 8, 0.08)
		for k in 4:
			NewModels6.box(md, "leather", Vector3(-0.1, 0.0225, -0.1 + k * 0.067), Vector3(0.014, 0.05, 0.01), leather * 1.18)
		NewModels6.box(md, "leather", Vector3(0.0, 0.0465, 0.01), Vector3(0.12, 0.003, 0.08), Color(0.62, 0.5, 0.24))
		NewModels6.text(md, "paper", "STORM DIARY", Vector3(0.0, 0.0485, 0.035), Vector3.UP, 0.014, INK, Vector3(0, 0, -1), 0.0)
		NewModels6.limb(md, "cloth", Vector3(0.06, 0.04, 0.14), Vector3(0.07, 0.01, 0.2), 0.004, 0.003, Color(0.5, 0.1, 0.1), 3)
	else:
		for sx: float in [-1.0, 1.0]:
			NewModels6.box(md, "leather", Vector3(sx * 0.1, 0.004, 0), Vector3(0.2, 0.008, 0.28), leather)
			NewModels6.rbox(md, "paper", Vector3(sx * 0.098, 0.02, 0), Vector3(0.185, 0.026, 0.265), PAPER * 0.96, Basis(Vector3.BACK, sx * 0.03), 5.0, 6, 0.04)
			_scribble(md, Vector3(sx * 0.098, 0.034, 0.0), 0.08, 0.12, 16, Color(0.12, 0.1, 0.16), 3.0 + sx)
		NewModels6.limb(md, "cloth", Vector3(0.03, 0.036, 0.14), Vector3(0.06, 0.012, 0.22), 0.004, 0.003, Color(0.5, 0.1, 0.1), 3)
		NewModels6.limb(md, "enamel", Vector3(-0.15, 0.04, -0.14), Vector3(-0.03, 0.04, -0.09), 0.004, 0.0035, Color(0.5, 0.1, 0.08), 5)

static func _archive_box(md: NewModels6.Model) -> void:
	# a cardboard archive box with a lid ajar, hand holes and a typed label, papers showing
	var card := Color(0.36, 0.29, 0.2)
	NewModels6.box(md, "paper", Vector3(0.0, 0.13, 0.153), Vector3(0.42, 0.012, 0.004), card * 0.7)
	NewModels6.box(md, "paper", Vector3(0.0, 0.27, 0.153), Vector3(0.1, 0.14, 0.003), Color(0.62, 0.56, 0.44))
	for sx: float in [-1.0, 1.0]:
		NewModels6.box(md, "paper", Vector3(sx * 0.205, 0.13, 0.0), Vector3(0.01, 0.26, 0.3), card * 0.95)
	for sz: float in [-1.0, 1.0]:
		NewModels6.box(md, "paper", Vector3(0.0, 0.13, sz * 0.145), Vector3(0.4, 0.26, 0.01), card)
	NewModels6.box(md, "paper", Vector3(0.0, 0.003, 0.0), Vector3(0.4, 0.006, 0.3), card * 0.9)
	NewModels6.box(md, "paper", Vector3(0.0, 0.235, 0.0), Vector3(0.38, 0.1, 0.28), PAPER)
	for k in 6:
		NewModels6.box(md, "paper", Vector3(-0.15 + k * 0.06, 0.275, (NewModels6.rnd(k, 31.0) - 0.5) * 0.03), Vector3(0.012, 0.06, 0.26), PAPER * (0.9 + 0.1 * NewModels6.rnd(k, 32.0)), 0.0, Color(-1, 0, 0), Basis(Vector3.BACK, (NewModels6.rnd(k, 33.0) - 0.5) * 0.2))
	NewModels6.box(md, "paper", Vector3(0.05, 0.31, -0.01), Vector3(0.44, 0.012, 0.32), card * 1.05, 0.0, Color(-1, 0, 0), Basis(Vector3.BACK, 0.07))
	NewModels6.box(md, "paper", Vector3(0.0, 0.17, 0.152), Vector3(0.14, 0.09, 0.003), Color(0.88, 0.85, 0.74))
	NewModels6.text(md, "paper", "STORM 1984", Vector3(0.0, 0.2, 0.1545), Vector3(0, 0, 1), 0.016, INK, Vector3.UP, 0.0)
	NewModels6.text(md, "paper", "RECORDS", Vector3(0.0, 0.178, 0.1545), Vector3(0, 0, 1), 0.012, INK, Vector3.UP, 0.0)
	NewModels6.box(md, "paper", Vector3(0.0, 0.07, 0.152), Vector3(0.1, 0.035, 0.003), Color(0.05, 0.04, 0.03))

static func _drawing(md: NewModels6.Model) -> void:
	# a child's crayon drawing of a funnel over a lake on A4, folded once and half open like a book
	var open := 0.45
	for sx: float in [-1.0, 1.0]:
		var bas := Basis(Vector3.BACK, sx * open)
		var cen := bas * Vector3(sx * 0.105, 0.001, 0.0)
		NewModels6.box(md, "paper", cen, Vector3(0.21, 0.002, 0.297), PAPER * 1.04, 0.0, Color(-1, 0, 0), bas)
		var face := bas * Vector3(sx * 0.105, 0.0018, 0.0)
		if sx > 0.0:
			for k in 6:
				var t := float(k) / 5.0
				var w := lerpf(0.07, 0.008, t)
				NewModels6.limb(md, "paper", face + bas * Vector3(-w, 0.0, 0.1 - t * 0.17), face + bas * Vector3(w, 0.0, 0.1 - t * 0.17 - 0.012), 0.004, 0.004, Color(0.25, 0.25, 0.28), 4)
			NewModels6.limb(md, "paper", face + bas * Vector3(-0.05, 0.0, 0.12), face + bas * Vector3(0.0, 0.0, -0.08), 0.002, 0.002, Color(0.1, 0.1, 0.12), 3)
			NewModels6.limb(md, "paper", face + bas * Vector3(0.05, 0.0, 0.12), face + bas * Vector3(0.0, 0.0, -0.08), 0.002, 0.002, Color(0.1, 0.1, 0.12), 3)
			NewModels6.ball(md, "paper", face + bas * Vector3(0.07, 0.0, 0.11), Vector3(0.016, 0.0006, 0.016), Color(0.95, 0.8, 0.12), 8, bas)
		else:
			for k in 5:
				var z := -0.02 - k * 0.026
				var prev := face + bas * Vector3(-0.08, 0.0, z)
				for j in range(1, 7):
					var p := face + bas * Vector3(-0.08 + j * 0.027, 0.0, z + 0.006 * sin(j * 1.9 + k))
					NewModels6.limb(md, "paper", prev, p, 0.0025, 0.0025, Color(0.2, 0.4, 0.8), 3)
					prev = p
			NewModels6.box(md, "paper", face + bas * Vector3(0.05, 0.0, 0.07), Vector3(0.04, 0.0008, 0.035), Color(0.75, 0.2, 0.15), 0.0, Color(-1, 0, 0), bas)
			NewModels6.box(md, "paper", face + bas * Vector3(0.05, 0.0, 0.1), Vector3(0.05, 0.0008, 0.016), Color(0.35, 0.2, 0.12), 0.0, Color(-1, 0, 0), bas)

# ================================================================== priority 1
static func _bell(md: NewModels6.Model, knotted: bool, lod: int) -> void:
	# a chapel bell (0.7 m across the mouth) on an oak headstock between two posts, with its wheel; `bell` swings on the axle, `rope`
	# hangs from the wheel rim and ends in a striped wool sally (the knotted variant is tied up in a bundle, out of reach)
	var ay := 2.0
	var A := Vector3(0, ay, 0)
	for sx: float in [-1.0, 1.0]:
		NewModels7.board(md, "wood", Vector3(sx * 0.62, 0.0, 0.0), Vector3(sx * 0.62, 2.35, 0.0), 0.2, 0.2, NewModels7.W(OAK, 1.0))
		NewModels6.box(md, "wood", Vector3(sx * 0.62, 0.07, 0.0), Vector3(0.3, 0.14, 0.4), NewModels7.W(OAK * 0.9, 0.75))
		NewModels7.board(md, "wood", Vector3(sx * 0.62, 0.3, 0.0), Vector3(sx * 0.3, 1.0, 0.0), 0.12, 0.12, NewModels7.W(OAK * 0.95, 0.75))
		NewModels6.cyl(md, "rust", Vector3(sx * 0.74, ay, 0.0), Vector3(sx * 0.5, ay, 0.0), 0.075, 0.075, 12, IRON, 3, 0.05)
	NewModels6.box(md, "wood", Vector3(0, 2.3, 0.0), Vector3(1.5, 0.16, 0.2), NewModels7.W(OAK * 1.05, 0.75))
	var bl := md.sub("bell", A)
	NewModels6.box(bl, "wood", A, Vector3(1.0, 0.16, 0.16), NewModels7.W(OAK * 1.1, 0.75))
	for sx: float in [-1.0, 1.0]:
		NewModels6.cyl(bl, "rust", A + Vector3(sx * 0.4, 0, 0), A + Vector3(sx * 0.6, 0, 0), 0.032, 0.03, 10, IRON, 3, 0.04)
		NewModels6.box(bl, "rust", A + Vector3(sx * 0.3, 0.0, 0.0), Vector3(0.04, 0.2, 0.2), IRON)
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.09, 0.0), Vector2(0.12, -0.03), Vector2(0.15, -0.11), Vector2(0.17, -0.22), Vector2(0.2, -0.33), Vector2(0.25, -0.45), Vector2(0.31, -0.53),
		Vector2(0.345, -0.56), Vector2(0.35, -0.585), Vector2(0.325, -0.585), Vector2(0.31, -0.56), Vector2(0.27, -0.5), Vector2(0.2, -0.4), Vector2(0.14, -0.28), Vector2(0.08, -0.14), Vector2(0.0, -0.08)])
	NewModels6.put(bl, "chrome", DroneParts.lathe(prof, 28 if lod == 0 else 14), Transform3D(Basis.IDENTITY, A + Vector3(0, -0.08, 0)), BRONZE, 0.1)
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		NewModels6.limb(bl, "chrome", A + Vector3(cos(a) * 0.06, -0.08, sin(a) * 0.06), A + Vector3(cos(a) * 0.06, -0.01, sin(a) * 0.06), 0.022, 0.02, BRONZE * 0.9, 6)
	NewModels6.limb(bl, "rust", A + Vector3(0, -0.2, 0), A + Vector3(0, -0.62, 0.02), 0.012, 0.012, IRON, 5)
	NewModels6.ball(bl, "rust", A + Vector3(0, -0.64, 0.02), Vector3(0.05, 0.05, 0.05), IRON, 8)
	var wc := A + Vector3(0.5, 0, 0)
	var prev := wc + Vector3(0, 0.5, 0)
	var rim_n := 24 if lod == 0 else 12
	for k in range(1, rim_n + 1):
		var a2 := TAU * k / rim_n
		var p := wc + Vector3(0.0, cos(a2) * 0.5, sin(a2) * 0.5)
		NewModels6.limb(bl, "wood", prev, p, 0.04, 0.04, NewModels7.W(OAK * 1.15, 0.75), 6)
		prev = p
	for k in 8:
		var a3 := TAU * k / 8.0
		NewModels6.limb(bl, "wood", wc, wc + Vector3(0.0, cos(a3) * 0.48, sin(a3) * 0.48), 0.025, 0.02, NewModels7.W(OAK, 0.75), 5)
	NewModels6.cyl(bl, "wood", wc + Vector3(-0.06, 0, 0), wc + Vector3(0.06, 0, 0), 0.07, 0.07, 10, NewModels7.W(OAK, 1.0), 3, 0.05)
	var rp := Vector3(0.5, ay - 0.5, 0.5)
	var ro := md.sub("rope", rp)
	var rc := Color(0.62, 0.55, 0.4)
	var pr := rp
	var run := 14 if not knotted else 7
	for k in range(1, run + 1):
		var t := float(k) / 14.0
		var p2 := rp + Vector3(0.0, -t * 1.5, 0.03 * sin(t * 3.0))
		NewModels6.limb(ro, "cloth", pr, p2, 0.017, 0.017, rc, 5, 0.08)
		pr = p2
	if not knotted:
		for k in 7:
			var y0 := rp.y - 0.72 - k * 0.07
			NewModels6.cyl(ro, "cloth", Vector3(rp.x, y0, rp.z), Vector3(rp.x, y0 - 0.065, rp.z), 0.034, 0.032, 8, [Color(0.75, 0.12, 0.1), Color(0.9, 0.9, 0.88), Color(0.15, 0.25, 0.6)][k % 3], 3, 0.04)
	else:
		# tied up out of reach: the rest of the rope laid in three loops and finished with a knot
		var cc := pr + Vector3(0.0, -0.06, 0.0)
		for l in 3:
			var pp := cc + Vector3(0.09, -l * 0.04, 0.0)
			for k in range(1, 13):
				var a4 := TAU * k / 12.0
				var q := cc + Vector3(0.09 * cos(a4), -l * 0.04 - 0.002 * k, 0.09 * sin(a4))
				NewModels6.limb(ro, "cloth", pp, q, 0.017, 0.017, rc, 5, 0.08)
				pp = q
		NewModels6.ball(ro, "cloth", cc + Vector3(0.0, -0.05, 0.1), Vector3(0.055, 0.05, 0.05), rc * 0.95, 8, Basis.IDENTITY, 0.08)
		NewModels6.limb(ro, "cloth", cc + Vector3(0.0, -0.05, 0.1), cc + Vector3(0.03, -0.45, 0.13), 0.015, 0.012, rc, 5)
		NewModels6.cyl(ro, "cloth", cc + Vector3(0.03, -0.4, 0.13), cc + Vector3(0.03, -0.47, 0.13), 0.03, 0.028, 8, Color(0.75, 0.12, 0.1), 3)

static func _lantern(md: NewModels6.Model, lit: bool) -> void:
	# a hurricane (storm) lantern, 0.34 m tall: a pressed-tin base with a fuel font, wire cage, glass globe and a hooped handle
	var tin := Color(0.2, 0.22, 0.2)
	var base := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.065, 0.0), Vector2(0.07, 0.01), Vector2(0.07, 0.05), Vector2(0.055, 0.075), Vector2(0.05, 0.085), Vector2(0.0, 0.085)])
	NewModels6.put(md, "rust", DroneParts.lathe(base, 22), Transform3D.IDENTITY, tin, 0.02)
	NewModels6.cyl(md, "chrome", Vector3(0, 0.085, 0), Vector3(0, 0.1, 0), 0.025, 0.02, 10, Color(0.7, 0.55, 0.22), 3, 0.0)
	var glass := PackedVector2Array([Vector2(0.034, 0.1), Vector2(0.048, 0.12), Vector2(0.053, 0.15), Vector2(0.045, 0.18), Vector2(0.034, 0.2), Vector2(0.03, 0.225)])
	NewModels6.put(md, "glass", DroneParts.lathe(glass, 16), Transform3D.IDENTITY, Color.WHITE, 0.0)
	for k in 2:
		var a := PI * k
		NewModels6.limb(md, "rust", Vector3(cos(a) * 0.06, 0.08, sin(a) * 0.06), Vector3(cos(a) * 0.035, 0.26, sin(a) * 0.035), 0.0035, 0.0035, tin, 4)
	NewModels6.cyl(md, "rust", Vector3(0, 0.23, 0), Vector3(0, 0.26, 0), 0.045, 0.03, 12, tin, 3, 0.05)
	NewModels6.ball(md, "rust", Vector3(0, 0.27, 0), Vector3(0.03, 0.022, 0.03), tin * 1.1, 8)
	var prev := Vector3(0.05, 0.255, 0.0)
	for k in range(1, 11):
		var a2 := PI * float(k) / 10.0
		var p := Vector3(cos(a2) * 0.05, 0.255 + sin(a2) * 0.075, 0.0)
		NewModels6.limb(md, "rust", prev, p, 0.003, 0.003, tin, 4)
		prev = p
	if lit:
		var fl := md.sub("flame", Vector3(0, 0.12, 0))
		NewModels6.put(fl, "flame", DroneParts.lathe(PackedVector2Array([Vector2(0.0, 0.1), Vector2(0.008, 0.105), Vector2(0.01, 0.12), Vector2(0.006, 0.14), Vector2(0.0, 0.16)]), 8), Transform3D.IDENTITY, Color.WHITE, 0.0)
		NewModels6.ball(fl, "warm", Vector3(0, 0.135, 0), Vector3(0.016, 0.03, 0.016), Color.WHITE, 10)

static func _coat_post(md: NewModels6.Model, lod: int) -> void:
	# a fence post with a crossbar, an old waxed coat hung over it and a felt hat on top: from far off it reads as someone standing in the field
	NewModels7.board(md, "wood", Vector3(0, 0.0, 0), Vector3(0, 1.62, 0), 0.11, 0.11, NewModels7.W(Color(0.5, 0.46, 0.4), 1.0))
	NewModels7.board(md, "wood", Vector3(-0.45, 1.3, 0.0), Vector3(0.45, 1.3, 0.0), 0.07, 0.05, NewModels7.W(Color(0.5, 0.46, 0.4), 0.75))
	var coat := Color(0.1, 0.13, 0.1)
	var secs := [[0.0, 0.26, 0.12], [0.35, 0.27, 0.12], [0.75, 0.24, 0.11], [1.0, 0.2, 0.09]]
	NewModels6.shell(md, "cloth", Vector3(0, 0.45, 0.0), Vector3(0, 1.33, 0.0), secs, coat, Vector3.RIGHT, 2.4, 14 if lod == 0 else 8, 0.07)
	NewModels6.ball(md, "cloth", Vector3(0, 1.32, 0), Vector3(0.26, 0.05, 0.12), coat * 1.05, 10, Basis.IDENTITY, 0.06)
	for sx: float in [-1.0, 1.0]:
		NewModels6.limb(md, "cloth", Vector3(sx * 0.24, 1.3, 0.0), Vector3(sx * 0.35, 0.78, 0.06), 0.06, 0.05, coat * 0.96, 8, 0.06)
		NewModels6.limb(md, "cloth", Vector3(sx * 0.35, 0.78, 0.06), Vector3(sx * 0.38, 0.52, 0.1), 0.05, 0.045, coat * 0.96, 8, 0.06)
		NewModels6.ball(md, "cloth", Vector3(sx * 0.38, 0.5, 0.1), Vector3(0.05, 0.045, 0.04), coat * 0.9, 6)
	NewModels6.cyl(md, "cloth", Vector3(0, 1.62, 0), Vector3(0, 1.74, 0), 0.085, 0.07, 12, Color(0.28, 0.24, 0.18), 3, 0.06)
	NewModels6.cyl(md, "cloth", Vector3(0, 1.62, 0), Vector3(0, 1.635, 0), 0.19, 0.19, 14, Color(0.26, 0.22, 0.16), 3, 0.05)
	NewModels6.limb(md, "cloth", Vector3(-0.22, 1.35, 0.1), Vector3(0.12, 1.22, 0.12), 0.03, 0.03, Color(0.55, 0.15, 0.12), 6)

static func _logbook(md: NewModels6.Model, open: bool) -> void:
	# Tom's storm logbook: a clothbound ledger, 0.24 x 0.33 m, 35 mm thick, leather corners; open it shows ruled columns, entries and a barometer trace
	var cloth := Color(0.12, 0.2, 0.16)
	if not open:
		NewModels6.box(md, "paper", Vector3(0.005, 0.0175, 0.002), Vector3(0.225, 0.028, 0.322), PAPER * 0.9)
		NewModels6.rbox(md, "cloth", Vector3(0, 0.0175, 0), Vector3(0.24, 0.035, 0.33), cloth, Basis.IDENTITY, 5.0, 8, 0.06)
		NewModels6.box(md, "leather", Vector3(-0.12, 0.0175, 0.0), Vector3(0.016, 0.038, 0.332), Color(0.3, 0.15, 0.08))
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				NewModels6.box(md, "leather", Vector3(sx * 0.1, 0.037, sz * 0.147), Vector3(0.04, 0.003, 0.04), Color(0.3, 0.15, 0.08))
		NewModels6.box(md, "paper", Vector3(0.0, 0.0365, 0.05), Vector3(0.13, 0.002, 0.1), Color(0.88, 0.85, 0.74))
		NewModels6.text(md, "paper", "STORM LOG", Vector3(0.0, 0.0376, 0.065), Vector3.UP, 0.016, INK, Vector3(0, 0, -1), 0.0)
		NewModels6.text(md, "paper", "T. ASHBY", Vector3(0.0, 0.0376, 0.035), Vector3.UP, 0.012, INK, Vector3(0, 0, -1), 0.0)
	else:
		for sx: float in [-1.0, 1.0]:
			NewModels6.box(md, "cloth", Vector3(sx * 0.12, 0.003, 0), Vector3(0.24, 0.006, 0.33), cloth)
			NewModels6.rbox(md, "paper", Vector3(sx * 0.118, 0.016, 0), Vector3(0.222, 0.02, 0.318), PAPER * 0.96, Basis(Vector3.BACK, sx * 0.025), 5.0, 6, 0.04)
			var topc := Vector3(sx * 0.118, 0.027, 0.0)
			for k in 4:
				NewModels6.box(md, "paper", topc + Vector3((k - 1.5) * 0.045, 0.0, 0.0), Vector3(0.0012, 0.0008, 0.3), Color(0.35, 0.28, 0.2))
			for l in 18:
				NewModels6.box(md, "paper", topc + Vector3(0.0, 0.0, -0.14 + l * 0.0165), Vector3(0.2, 0.0008, 0.0008), Color(0.55, 0.62, 0.7))
			_scribble(md, topc + Vector3(0, 0.0005, 0), 0.09, 0.14, 14, Color(0.1, 0.1, 0.18), 5.0 + sx)
		var prev := Vector3(0.05, 0.0285, 0.12)
		for k in range(1, 9):
			var p := Vector3(0.05 + 0.014 * k, 0.0285, 0.12 - 0.026 * k + 0.008 * sin(k * 2.1))
			NewModels6.limb(md, "paper", prev, p, 0.0013, 0.0013, Color(0.5, 0.1, 0.1), 3)
			prev = p

static func _map(md: NewModels6.Model) -> void:
	# the old festival map: a 0.52 x 0.37 m sheet, sepia, a lake, roads and field blocks printed on it, a ring stain; a soft crease along one fold
	var f := func(x: float, _z: float) -> float:
		return 0.0035 * smoothstep(0.18, 0.26, x)
	NewModels7.sheet_grid(md, "paper", 0.52, 0.37, 20, 14, PAPER * 0.93, f, Transform3D(Basis.IDENTITY, Vector3(0, 0.002, 0)), 0.04)
	var y := 0.0062
	NewModels6.sheet(md, "paper", [Vector3(-0.17, y, -0.05), Vector3(-0.06, y, -0.1), Vector3(0.02, y, -0.06), Vector3(0.0, y, 0.04), Vector3(-0.1, y, 0.08)], Color(0.45, 0.6, 0.7), Vector3.UP, false)
	for k in 5:
		NewModels6.box(md, "paper", Vector3(0.04 + k * 0.045, y, 0.09), Vector3(0.036, 0.0006, 0.05), Color(0.6, 0.65, 0.4) if k % 2 == 0 else Color(0.72, 0.62, 0.4))
	for pr in [[Vector3(-0.24, y, 0.0), Vector3(0.24, y, 0.03)], [Vector3(0.0, y, -0.17), Vector3(0.06, y, 0.17)], [Vector3(-0.2, y, -0.12), Vector3(0.1, y, -0.02)]]:
		NewModels6.limb(md, "paper", pr[0], pr[1], 0.0022, 0.0022, Color(0.35, 0.2, 0.12), 3)
	NewModels6.text(md, "paper", "HALLOWAY", Vector3(0.0, y + 0.0004, 0.15), Vector3.UP, 0.014, Color(0.2, 0.12, 0.08), Vector3(0, 0, -1), 0.0)
	NewModels6.text(md, "paper", "FESTIVAL FIELD", Vector3(0.14, y + 0.0004, -0.13), Vector3.UP, 0.01, Color(0.2, 0.12, 0.08), Vector3(0, 0, -1), 0.0)
	NewModels6.ball(md, "paper", Vector3(-0.15, y - 0.002, 0.1), Vector3(0.03, 0.0006, 0.03), Color(0.5, 0.4, 0.28), 14)

static func _sandbags(md: NewModels6.Model) -> void:
	# twelve hessian sandbags (0.5 x 0.28 x 0.14 m) stacked 5, 4, 3 in running bond, damp at the foot, a little sand spilt
	var rows := [5, 4, 3]
	var hess := Color(0.55, 0.48, 0.34)
	var i := 0
	for r in rows.size():
		var n: int = rows[r]
		var x0 := -(n - 1) * 0.27 * 0.5
		for k in n:
			var wet := 0.7 if r == 0 else 1.0
			var yaw := (NewModels6.rnd(i, 61.0) - 0.5) * 0.12
			var c := Vector3(x0 + k * 0.27, 0.07 + r * 0.125, (NewModels6.rnd(i, 62.0) - 0.5) * 0.03)
			NewModels6.rbox(md, "canvas", c, Vector3(0.5, 0.15, 0.28), NewModels6.vc(hess * wet * (0.9 + 0.2 * NewModels6.rnd(i, 63.0)), i * 1.7, 0.05), Basis(Vector3.UP, yaw), 3.2, 16, 0.025)
			NewModels6.ball(md, "canvas", c + Vector3(0.0, 0.0, -0.14), Vector3(0.05, 0.02, 0.025), hess * wet * 0.85, 6)
			NewModels6.limb(md, "cloth", c + Vector3(0.22, 0.075, 0.0), c + Vector3(0.25, 0.08, 0.02), 0.012, 0.01, Color(0.4, 0.3, 0.2), 4)
			i += 1
	for k in 10:
		NewModels6.ball(md, "soil", Vector3(-0.5 + NewModels6.rnd(k, 64.0) * 1.0, 0.004, 0.2 + NewModels6.rnd(k, 65.0) * 0.1), Vector3(0.03, 0.006, 0.02), Color(0.55, 0.47, 0.32), 5)

static func _tarp(md: NewModels6.Model, lod: int) -> void:
	# a blue 3 x 2 m storm tarpaulin pulled over a heap and weighted with bricks, tied at the grommets, one corner lifting
	var f := func(x: float, z: float) -> float:
		var heap := 0.55 * exp(-(x * x / 0.42 + z * z / 0.3))
		var wrinkle := 0.02 * sin(x * 9.0 + z * 3.0) * sin(z * 7.0) + 0.012 * sin(x * 17.0 - z * 5.0)
		var lift := 0.16 * smoothstep(1.0, 1.5, x) * smoothstep(0.4, 1.0, z) * (1.0 + sin(x * 6.0))
		return heap + wrinkle * (0.3 + heap) + lift + 0.012
	NewModels7.sheet_grid(md, "tarp", 3.0, 2.0, 36 if lod == 0 else 16, 24 if lod == 0 else 10, Color(0.1, 0.27, 0.45), f, Transform3D.IDENTITY, 0.06)
	for pc in [[-1.4, -0.9], [1.4, -0.9], [-1.4, 0.9], [0.0, -0.98], [0.0, 0.98], [-1.2, 0.0]]:
		var x: float = pc[0]
		var z: float = pc[1]
		NewModels6.cyl(md, "rust", Vector3(x, 0.02, z), Vector3(x, 0.034, z), 0.016, 0.016, 8, Color(0.7, 0.72, 0.74), 3, 0.0)
		NewModels7.rope(md, "cloth", Vector3(x, 0.03, z), Vector3(x * 1.12, 0.012, z * 1.15), 0.0, 0.0045, Color(0.85, 0.65, 0.15), 3)
	for k in 3:
		NewModels6.rbox(md, "brick", Vector3(-1.2 + k * 1.2, 0.06, -0.93), Vector3(0.22, 0.07, 0.1), Color(0.55, 0.3, 0.22), Basis(Vector3.UP, 0.2 * k), 3.0, 6, 0.1)
	NewModels6.ball(md, "stone", Vector3(1.35, 0.06, 0.1), Vector3(0.12, 0.07, 0.1), Color(0.5, 0.48, 0.44), 7, Basis.IDENTITY, 0.1)

# ================================================================== priority 2
static func _shelter_inside(md: NewModels6.Model, lod: int) -> void:
	# the inside of the buried shelter: 3 m wide, 4 m deep, 2.2 m high, stone walls, plank benches, a shelf of tins and candles, a lantern on a hook
	var w := 3.0
	var d := 4.0
	var h := 2.2
	for sx: float in [-1.0, 1.0]:
		NewModels6.rbox(md, "stone", Vector3(sx * (w * 0.5 + 0.2), h * 0.5, 0), Vector3(0.4, h + 0.2, d + 0.8), NewModels6.vc(STONE_C * 0.8, sx * 3.0, 0.1), Basis.IDENTITY, 4.0, 6, 0.1)
	NewModels6.rbox(md, "stone", Vector3(0, h * 0.5, -d * 0.5 - 0.2), Vector3(w + 0.8, h + 0.2, 0.4), STONE_C * 0.78, Basis.IDENTITY, 4.0, 6, 0.1)
	NewModels6.rbox(md, "stone", Vector3(0, -0.1, 0), Vector3(w + 0.8, 0.2, d + 0.8), STONE_C * 0.7, Basis.IDENTITY, 4.0, 6, 0.1)
	for k in 6:
		NewModels7.board(md, "wood", Vector3(-w * 0.5, h + 0.07, -d * 0.5 + 0.1 + k * 0.7), Vector3(w * 0.5, h + 0.07, -d * 0.5 + 0.1 + k * 0.7), 0.2, 0.16, NewModels7.W(OAK * 0.9, 0.75))
	NewModels6.box(md, "wood", Vector3(0, h + 0.17, -0.4), Vector3(w + 0.8, 0.06, d), NewModels7.W(OAK * 0.8, 0.5))
	for k in 5:
		NewModels6.rbox(md, "stone", Vector3(0, 0.1 + k * 0.2, d * 0.5 - 0.3), Vector3(1.0, 0.18, 0.3), STONE_C * 0.9, Basis.IDENTITY, 4.0, 6, 0.1)
	for sx: float in [-1.0, 1.0]:
		NewModels7.board(md, "wood", Vector3(sx * (w * 0.5 - 0.25), 0.45, -d * 0.5 + 0.2), Vector3(sx * (w * 0.5 - 0.25), 0.45, d * 0.5 - 1.4), 0.4, 0.045, NewModels7.W(OAK, 0.5))
		for k in 3:
			NewModels6.box(md, "wood", Vector3(sx * (w * 0.5 - 0.25), 0.22, -d * 0.5 + 0.5 + k * 1.0), Vector3(0.38, 0.44, 0.06), NewModels7.W(OAK * 0.9, 1.0))
	NewModels6.box(md, "wood", Vector3(0, 1.3, -d * 0.5 + 0.06), Vector3(1.4, 0.04, 0.24), NewModels7.W(OAK * 0.9, 0.75))
	for k in 6:
		NewModels6.cyl(md, "sheet", Vector3(-0.6 + k * 0.22, 1.32, -d * 0.5 + 0.06), Vector3(-0.6 + k * 0.22, 1.42, -d * 0.5 + 0.06), 0.035, 0.035, 10, [Color(0.7, 0.3, 0.2), Color(0.55, 0.55, 0.5), Color(0.3, 0.45, 0.3)][k % 3], 3, 0.06)
	for k in 2:
		NewModels6.cyl(md, "paper", Vector3(0.45 + k * 0.17, 1.32, -d * 0.5 + 0.06), Vector3(0.45 + k * 0.17, 1.44, -d * 0.5 + 0.06), 0.012, 0.011, 8, WHITE_P, 3, 0.02)
	NewModels7.merge(md, NewModels6.build("storm_lantern_a", 1), Transform3D(Basis.IDENTITY, Vector3(w * 0.5 - 0.5, 0.5, -0.8)))
	NewModels6.rbox(md, "canvas", Vector3(-w * 0.5 + 0.35, 0.58, -0.6), Vector3(0.7, 0.18, 0.4), Color(0.4, 0.42, 0.3), Basis.IDENTITY, 4.0, 8, 0.08)
	NewModels6.cyl(md, "rust", Vector3(0.0, 0.0, -d * 0.5 + 0.4), Vector3(0.0, 0.7, -d * 0.5 + 0.4), 0.26, 0.28, 14, Color(0.28, 0.2, 0.12), 3, 0.06)

static func _chapel_inside(md: NewModels6.Model, lod: int) -> void:
	# the inside of the old chapel: a nave 6 m wide, 12 m long and 5 m to the ridge, eight pews each side of an aisle, an altar rail and altar,
	# narrow windows (the lit panes are the `window_light` node, hide them by day)
	var w := 6.0
	var L := 12.0
	var wall := Color(0.82, 0.8, 0.72)
	NewModels6.box(md, "concrete", Vector3(0, -0.05, 0), Vector3(w + 0.8, 0.1, L + 0.8), Color(0.45, 0.43, 0.4))
	NewModels6.box(md, "wood", Vector3(0, 0.0, 0.0), Vector3(w - 0.2, 0.012, L - 0.2), NewModels7.W(Color(0.5, 0.38, 0.26), 0.5))
	for sx: float in [-1.0, 1.0]:
		NewModels6.box(md, "paintwood", Vector3(sx * (w * 0.5 + 0.2), 2.0, 0.0), Vector3(0.4, 4.0, L + 0.8), wall)
	NewModels6.box(md, "paintwood", Vector3(0, 2.0, -L * 0.5 - 0.2), Vector3(w + 0.8, 4.0, 0.4), wall)
	NewModels6.box(md, "paintwood", Vector3(0, 2.0, L * 0.5 + 0.2), Vector3(w + 0.8, 4.0, 0.4), wall)
	for k in 7:
		var z := -L * 0.5 + 0.7 + k * 1.7
		NewModels7.board(md, "wood", Vector3(-w * 0.5, 4.0, z), Vector3(0.0, 5.2, z), 0.18, 0.12, NewModels7.W(OAK, 0.75))
		NewModels7.board(md, "wood", Vector3(w * 0.5, 4.0, z), Vector3(0.0, 5.2, z), 0.18, 0.12, NewModels7.W(OAK, 0.75))
		NewModels7.board(md, "wood", Vector3(-w * 0.5, 4.0, z), Vector3(w * 0.5, 4.0, z), 0.16, 0.12, NewModels7.W(OAK, 0.75))
	NewModels7.board(md, "wood", Vector3(0, 5.15, -L * 0.5), Vector3(0, 5.15, L * 0.5), 0.14, 0.14, NewModels7.W(OAK, 0.5))
	var pews := 8 if lod == 0 else 4
	for sx: float in [-1.0, 1.0]:
		for k in pews:
			var z2 := -L * 0.5 + 3.0 + k * 0.95 * (8.0 / pews)
			var px := sx * 1.85
			NewModels6.box(md, "wood", Vector3(px, 0.45, z2), Vector3(2.5, 0.05, 0.4), NewModels7.W(Color(0.42, 0.3, 0.2), 0.75))
			NewModels6.box(md, "wood", Vector3(px, 0.75, z2 - 0.2), Vector3(2.5, 0.5, 0.045), NewModels7.W(Color(0.42, 0.3, 0.2), 0.75))
			for ex: float in [-1.0, 1.0]:
				NewModels6.box(md, "wood", Vector3(px + ex * 1.22, 0.4, z2 - 0.05), Vector3(0.06, 0.8, 0.5), NewModels7.W(Color(0.38, 0.27, 0.18), 1.0))
	var win := md.sub("window_light", Vector3(0, 2.2, 0))
	for sx: float in [-1.0, 1.0]:
		for k in 4:
			var z3 := -L * 0.5 + 1.5 + k * 3.0
			NewModels6.box(md, "paint", Vector3(sx * (w * 0.5 - 0.0), 2.4, z3), Vector3(0.45, 1.6, 0.6), Color(0.04, 0.04, 0.05))
			NewModels6.box(win, "warm", Vector3(sx * (w * 0.5 - 0.02), 2.4, z3), Vector3(0.02, 1.4, 0.4), Color.WHITE)
	NewModels6.box(md, "wood", Vector3(0, 0.12, -L * 0.5 + 1.0), Vector3(5.6, 0.24, 2.0), NewModels7.W(Color(0.4, 0.3, 0.2), 0.5))
	NewModels6.box(md, "wood", Vector3(0, 0.95, -L * 0.5 + 1.0), Vector3(1.6, 0.9, 0.7), NewModels7.W(Color(0.36, 0.26, 0.17), 0.75))
	NewModels6.box(md, "cloth", Vector3(0, 1.4, -L * 0.5 + 1.0), Vector3(1.7, 0.02, 0.8), Color(0.82, 0.8, 0.74))
	NewModels6.box(md, "wood", Vector3(0, 1.8, -L * 0.5 + 0.7), Vector3(0.07, 0.8, 0.04), NewModels7.W(OAK, 1.0))
	NewModels6.box(md, "wood", Vector3(0, 1.98, -L * 0.5 + 0.7), Vector3(0.4, 0.07, 0.04), NewModels7.W(OAK, 0.75))
	for sx: float in [-1.0, 1.0]:
		NewModels6.box(md, "wood", Vector3(sx * 1.4, 0.6, -L * 0.5 + 2.3), Vector3(2.4, 0.07, 0.07), NewModels7.W(OAK, 0.75))
		for k in 4:
			NewModels6.box(md, "wood", Vector3(sx * (0.35 + k * 0.6), 0.3, -L * 0.5 + 2.3), Vector3(0.05, 0.6, 0.05), NewModels7.W(OAK, 1.0))

static func _rail_hut(md: NewModels6.Model, lod: int) -> void:
	# a platelayers' hut beside the line: 3.2 x 2.6 m, vertical board walls, a corrugated lean-to roof, a door, a window and a stove pipe
	var w := 3.2
	var d := 2.6
	NewModels6.box(md, "concrete", Vector3(0, 0.05, 0), Vector3(w + 0.2, 0.1, d + 0.2), Color(0.5, 0.49, 0.46))
	for k in 16:
		var x := -w * 0.5 + (k + 0.5) * w / 16.0
		NewModels6.box(md, "wood", Vector3(x, 1.25, d * 0.5), Vector3(w / 16.0 - 0.006, 2.3, 0.04), NewModels7.W(Color(0.38, 0.3, 0.22) * (0.92 + 0.14 * NewModels6.rnd(k, 71.0)), 1.0))
		NewModels6.box(md, "wood", Vector3(x, 1.25, -d * 0.5), Vector3(w / 16.0 - 0.006, 2.3, 0.04), NewModels7.W(Color(0.38, 0.3, 0.22) * (0.92 + 0.14 * NewModels6.rnd(k, 72.0)), 1.0))
	for k in 13:
		var z := -d * 0.5 + (k + 0.5) * d / 13.0
		for sx: float in [-1.0, 1.0]:
			NewModels6.box(md, "wood", Vector3(sx * w * 0.5, 1.25, z), Vector3(0.04, 2.3, d / 13.0 - 0.006), NewModels7.W(Color(0.38, 0.3, 0.22) * (0.92 + 0.14 * NewModels6.rnd(k, 73.0 + sx)), 1.0))
	NewModels6.box(md, "paint", Vector3(-0.6, 1.0, d * 0.5 + 0.02), Vector3(0.9, 1.9, 0.02), Color(0.06, 0.05, 0.04))
	NewModels6.box(md, "wood", Vector3(-0.6, 1.0, d * 0.5 + 0.045), Vector3(0.86, 1.86, 0.03), NewModels7.W(Color(0.3, 0.24, 0.16), 1.0))
	NewModels6.box(md, "steel", Vector3(-0.25, 1.0, d * 0.5 + 0.07), Vector3(0.04, 0.12, 0.02), Color(0.15, 0.15, 0.15))
	NewModels6.box(md, "glass", Vector3(0.85, 1.35, d * 0.5 + 0.02), Vector3(0.7, 0.55, 0.01), Color.WHITE)
	NewModels6.box(md, "wood", Vector3(0.85, 1.35, d * 0.5 + 0.035), Vector3(0.78, 0.04, 0.02), NewModels7.W(OAK, 0.75))
	NewModels6.box(md, "roof", Vector3(0, 2.47, 0.0), Vector3(w + 0.5, 0.04, d + 0.5), Color(0.5, 0.52, 0.52), 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, 0.09))
	NewModels6.cyl(md, "rust", Vector3(w * 0.3, 2.4, -0.4), Vector3(w * 0.3, 3.2, -0.4), 0.06, 0.055, 10, IRON, 3, 0.05)
	NewModels6.cyl(md, "rust", Vector3(w * 0.3, 3.2, -0.4), Vector3(w * 0.3, 3.3, -0.4), 0.08, 0.08, 10, IRON * 1.2, 3, 0.05)
	NewModels6.hull(md, Vector3(0, 1.25, 0), Vector3(w + 0.3, 2.5, d + 0.3))

static func _ditch(md: NewModels6.Model, lod: int) -> void:
	# an 8 m roadside ditch in flood: V-banks of mud, brown water standing 0.28 m below the lip, reeds on the banks, a branch and a sack in it
	var rows: Array = []
	var nz := 16 if lod == 0 else 8
	for j in nz + 1:
		var z := (float(j) / nz - 0.5) * 8.0
		var r := PackedVector3Array(); r.resize(13)
		for i in 13:
			var x := (float(i) / 12.0 - 0.5) * 3.6
			var ax := absf(x)
			var bank := 0.34 * smoothstep(0.0, 0.8, ax) * (1.0 - smoothstep(1.0, 1.8, ax))
			r[i] = Vector3(x, 0.02 + bank + 0.03 * sin(z * 1.7 + x * 3.0) * smoothstep(0.5, 1.2, ax) + 0.008 * sin(z * 5.0 + x * 7.0), z)
		rows.append(r)
	var hint := func(_i: int, _j: int, _p: Vector3) -> Vector3: return Vector3.UP
	NewModels6.gridsurf(md, "mud", rows, Color(0.22, 0.16, 0.1), hint, 0.08)
	NewModels6.quad2(md, "water", Vector3(-1.05, 0.15, -4.0), Vector3(1.05, 0.15, -4.0), Vector3(1.05, 0.15, 4.0), Vector3(-1.05, 0.15, 4.0), Color.WHITE, false)
	for k in 30:
		var z2 := -4.0 + NewModels6.rnd(k, 81.0) * 8.0
		var side := -1.0 if NewModels6.rnd(k, 82.0) < 0.5 else 1.0
		var base := Vector3(side * (0.7 + 0.5 * NewModels6.rnd(k, 83.0)), 0.2, z2)
		for s in 3:
			NewModels6.limb(md, "hay", base, base + Vector3(side * 0.06 * s, 0.5 + 0.3 * NewModels6.rnd(k * 3 + s, 84.0), (NewModels6.rnd(k * 3 + s, 85.0) - 0.5) * 0.12), 0.006, 0.002, Color(0.38, 0.4, 0.16), 3)
	NewModels7.merge(md, NewModels6.build("storm_debris_branch_a", 1), Transform3D(Basis(Vector3.UP, 0.6), Vector3(0.1, 0.2, 1.0)))
	NewModels7.merge(md, NewModels6.build("storm_debris_sack_a", 0), Transform3D(Basis(Vector3.UP, 1.2), Vector3(-0.2, 0.2, -1.6)))

static func _power_line(md: NewModels6.Model) -> void:
	# a wooden pole snapped near the base and leaning, its cross-arm and three insulators on the ground, dead wires looped about, an orange cone and a tape barrier
	var pole := NewModels7.W(Color(0.3, 0.24, 0.17), 1.0)
	NewModels7.board(md, "wood", Vector3(0, 0, 0), Vector3(0.0, 0.7, 0.0), 0.28, 0.28, pole)
	NewModels6.limb(md, "wood", Vector3(0, 0.7, 0), Vector3(0.04, 0.78, 0.04), 0.13, 0.06, NewModels7.W(Color(0.62, 0.5, 0.36), 0.5), 6)
	var top := Vector3(2.7, 0.9, 4.6)
	NewModels6.limb(md, "wood", Vector3(0.12, 0.78, 0.15), top, 0.14, 0.1, pole, 10, 0.08)
	var dir := (top - Vector3(0.12, 0.78, 0.15)).normalized()
	var arm_c := top - dir * 0.2
	var side := Vector3(0.9, 0, -0.3).normalized()
	NewModels7.board(md, "wood", arm_c - side * 0.9, arm_c + side * 0.9, 0.1, 0.1, NewModels7.W(pole * 1.05, 0.75))
	for k in 3:
		var p := arm_c + side * (-0.7 + k * 0.7)
		NewModels6.cyl(md, "enamel", p, p + Vector3(0, 0.22, 0), 0.04, 0.05, 10, Color(0.42, 0.55, 0.5), 3, 0.04)
		for t in 3:
			NewModels6.cyl(md, "enamel", p + Vector3(0, 0.04 + t * 0.055, 0), p + Vector3(0, 0.07 + t * 0.055, 0), 0.065, 0.065, 10, Color(0.42, 0.55, 0.5), 3, 0.04)
		var pw := p + Vector3(0, 0.25, 0)
		NewModels7.rope(md, "steel", pw, pw + Vector3(-1.5 - k * 0.3, -0.2, -2.0 + k * 0.4), -0.1, 0.007, Color(0.2, 0.2, 0.22), 8)
		NewModels7.rope(md, "steel", pw + Vector3(-1.5 - k * 0.3, -0.2, -2.0 + k * 0.4), pw + Vector3(-2.4 - k * 0.2, -0.22, -4.0 + k * 0.5), 0.0, 0.007, Color(0.2, 0.2, 0.22), 6)
	var cone := PackedVector2Array([Vector2(0.0, 0.5), Vector2(0.03, 0.5), Vector2(0.14, 0.02), Vector2(0.17, 0.0), Vector2(0.0, 0.0)])
	NewModels6.put(md, "rubber", DroneParts.lathe(cone, 12), Transform3D(Basis.IDENTITY, Vector3(-1.2, 0, 0.9)), Color(0.95, 0.4, 0.08), 0.04)
	NewModels6.cyl(md, "paper", Vector3(-1.2, 0.2, 0.9), Vector3(-1.2, 0.26, 0.9), 0.07, 0.065, 10, Color(0.9, 0.9, 0.88), 3, 0.0)
	NewModels6.box(md, "rubber", Vector3(-1.2, 0.01, 0.9), Vector3(0.36, 0.02, 0.36), Color(0.08, 0.08, 0.08))
	NewModels7.rope(md, "cloth", Vector3(-1.2, 0.45, 0.9), Vector3(0.1, 0.9, 0.2), 0.1, 0.012, Color(0.9, 0.75, 0.1), 8)

static func _sign(md: NewModels6.Model) -> void:
	# the village sign HALLOWAY on two oak posts after the storm: one post snapped and leaning, the board hanging by one bolt, mud and leaves
	NewModels7.board(md, "wood", Vector3(-0.8, 0, 0), Vector3(-0.8, 1.9, 0), 0.12, 0.12, NewModels7.W(OAK * 0.9, 1.0))
	NewModels7.board(md, "wood", Vector3(0.8, 0, 0), Vector3(0.8, 0.55, 0), 0.12, 0.12, NewModels7.W(OAK * 0.9, 1.0))
	NewModels6.limb(md, "wood", Vector3(0.8, 0.55, 0), Vector3(0.82, 0.62, 0.0), 0.06, 0.02, NewModels7.W(Color(0.62, 0.5, 0.36), 0.5), 5)
	NewModels7.board(md, "wood", Vector3(0.82, 0.55, 0.05), Vector3(1.55, 0.12, 0.7), 0.12, 0.12, NewModels7.W(OAK * 0.85, 0.75))
	var pivot := Vector3(-0.8, 1.7, 0.1)
	var bas := Basis(Vector3.BACK, -0.55)
	var R := func(p: Vector3) -> Vector3: return pivot + bas * (p - pivot)
	var sg := md.sub("board", pivot)
	NewModels6.box(sg, "paintwood", R.call(Vector3(0.0, 1.45, 0.1)), Vector3(1.5, 0.45, 0.05), Color(0.1, 0.27, 0.2), 0.0, Color(-1, 0, 0), bas)
	NewModels6.box(sg, "paintwood", R.call(Vector3(0.0, 1.45, 0.128)), Vector3(1.42, 0.37, 0.006), Color(0.12, 0.31, 0.23), 0.0, Color(-1, 0, 0), bas)
	NewModels6.text(sg, "paint", "HALLOWAY", R.call(Vector3(0.0, 1.35, 0.134)), bas * Vector3(0, 0, 1), 0.2, Color(0.9, 0.85, 0.65), bas * Vector3.UP, 0.0)
	NewModels6.cyl(sg, "steel", pivot + Vector3(0, 0, 0.06), pivot + Vector3(0, 0, 0.15), 0.016, 0.016, 8, Color(0.3, 0.3, 0.3), 3, 0.0)
	NewModels6.ball(md, "mud", Vector3(0.5, 0.02, 0.3), Vector3(0.5, 0.03, 0.4), Color(0.22, 0.16, 0.1), 8, Basis.IDENTITY, 0.1)
	NewModels7.leaves(md, Vector3(0.2, 0.05, 0.5), 0.5, 20, 0.12, 40.0, NewModels7.AUTUMN)

static func _crowd(md: NewModels6.Model, kind: String, lod: int) -> void:
	# two storm-watching poses: an adult shading their eyes to look up at the sky; and an adult and a child close together under one umbrella
	if kind == "watch":
		var st := NewModels6Chars.Style.new()
		st.jacket = Color(0.35, 0.3, 0.12); st.trousers = Color(0.14, 0.14, 0.17); st.boots = Color(0.1, 0.09, 0.07)
		st.skin = Color(0.72, 0.52, 0.42); st.hair = Color(0.3, 0.2, 0.12); st.height = 1.68; st.jacket_k = 1.25
		var pose := {"lean": -0.12, "roll": 0.03, "head_pitch": -0.55, "head_yaw": 0.2, "arm_r": [1.6, 0.3], "elbow_r": 2.3, "arm_l": [0.0, 0.14], "elbow_l": 0.4,
			"hip_r": [0.15, 0.1], "hip_l": [-0.1, 0.12], "knee_l": 0.1, "expr": "neutral", "grip_r": 0.1}
		NewModels6Chars._person(md, st, pose, lod)
	else:
		var st1 := NewModels6Chars.Style.new()
		st1.jacket = Color(0.12, 0.2, 0.3); st1.trousers = Color(0.12, 0.12, 0.15); st1.boots = Color(0.08, 0.07, 0.06)
		st1.skin = Color(0.62, 0.45, 0.35); st1.hair = Color(0.08, 0.06, 0.05); st1.height = 1.72; st1.jacket_k = 1.25
		var p1 := {"lean": 0.08, "roll": -0.04, "head_pitch": 0.08, "arm_r": [1.0, 0.5], "elbow_r": 1.9, "arm_l": [0.3, 0.3], "elbow_l": 0.5, "expr": "neutral", "grip_r": 0.9}
		var j1 := NewModels6Chars._person(md, st1, p1, lod)
		var st2 := NewModels6Chars.Style.new()
		st2.jacket = Color(0.55, 0.15, 0.12); st2.trousers = Color(0.18, 0.2, 0.3); st2.boots = Color(0.5, 0.35, 0.1)
		st2.skin = Color(0.78, 0.58, 0.48); st2.hair = Color(0.45, 0.3, 0.14); st2.height = 1.15; st2.jacket_k = 1.3
		var sub := NewModels6.Model.new()
		NewModels6Chars._person(sub, st2, {"lean": -0.04, "head_pitch": -0.15, "head_yaw": -0.2, "arm_r": [0.2, 0.2], "arm_l": [0.6, 0.2], "elbow_l": 1.2, "expr": "smile"}, lod)
		NewModels7.merge(md, sub, Transform3D(Basis.IDENTITY, Vector3(0.38, 0.0, 0.04)))
		var hand: Vector3 = j1["hand_r"]
		var top := hand + Vector3(0.05, 0.6, 0.0)
		NewModels6.limb(md, "chrome", hand + Vector3(0, -0.05, 0), top + Vector3(0, 0.1, 0), 0.008, 0.007, Color(0.2, 0.2, 0.22), 6)
		var canopy := PackedVector2Array([Vector2(0.0, 0.2), Vector2(0.12, 0.19), Vector2(0.34, 0.14), Vector2(0.62, 0.05), Vector2(0.72, 0.0), Vector2(0.7, -0.015)])
		NewModels6.put(md, "cloth", DroneParts.lathe(canopy, 16), Transform3D(Basis.IDENTITY, top), Color(0.12, 0.28, 0.2), 0.05)
		for k in 8:
			var a := TAU * k / 8.0
			NewModels6.limb(md, "chrome", top + Vector3(0, 0.2, 0), top + Vector3(cos(a) * 0.7, -0.015, sin(a) * 0.7), 0.0035, 0.0025, Color(0.2, 0.2, 0.22), 3)
		NewModels6.cyl(md, "rubber", hand + Vector3(0, -0.04, 0), hand + Vector3(0, 0.05, 0), 0.016, 0.015, 8, Color(0.1, 0.07, 0.05), 3, 0.0)

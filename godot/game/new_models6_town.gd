class_name NewModels6Town
extends RefCounted
## Story batch (models8), the festival field (stage, marquee, stalls, bunting, flags, barriers, lights, PA, banner, sign) and the
## Voss and Son garage (the building and what is in it). Metres, +Z front, origin on the ground. Photographed materials on the
## wood, brick and steel (the farm kit); canvas, rope and lamps from the batch's own materials.

const NAMES: Array[String] = [
	"festival_stage_a", "festival_marquee_a", "festival_stall_a", "festival_stall_a_b", "festival_bunting_a", "festival_bunting_a_b", "festival_bunting_a_c",
	"festival_flag_a", "festival_flag_a_b", "festival_barrier_a", "festival_picnic_table_a", "festival_lamp_string_a", "festival_pa_a", "festival_banner_a",
	"festival_sign_a",
	"garage_shell_a", "garage_workbench_a", "garage_workbench_a_cluttered", "garage_tool_cart_a", "garage_tyre_stack_a", "garage_oil_drum_a", "garage_engine_hoist_a",
	"garage_spare_engine_a", "garage_air_pump_a", "garage_fuel_pump_a", "garage_ramp_a", "garage_parts_shelf_a", "garage_sign_a",
	"garage_bicycle_a", "garage_toolbox_a", "garage_radio_a",
]

const TIMBER := Color(0.46, 0.37, 0.26)
const CREAM := Color(0.86, 0.82, 0.68)
const GREEN := Color(0.12, 0.3, 0.2)
const ROPE := Color(0.55, 0.47, 0.32)
const STEEL := Color(0.45, 0.47, 0.5)
const PAINT_R := Color(0.5, 0.1, 0.08)

static func build(name: String, md: NewModels6.Model, lod: int) -> bool:
	match name:
		"festival_stage_a": _stage(md, lod)
		"festival_marquee_a": _marquee(md, lod)
		"festival_stall_a": _stall(md, 0, lod)
		"festival_stall_a_b": _stall(md, 1, lod)
		"festival_bunting_a": _bunting(md, 0)
		"festival_bunting_a_b": _bunting(md, 1)
		"festival_bunting_a_c": _bunting(md, 2)
		"festival_flag_a": _flag(md, 0)
		"festival_flag_a_b": _flag(md, 1)
		"festival_barrier_a": _barrier(md)
		"festival_picnic_table_a": _picnic(md)
		"festival_lamp_string_a": _lamp_string(md)
		"festival_pa_a": _pa(md)
		"festival_banner_a": _banner(md)
		"festival_sign_a": _fsign(md)
		"garage_shell_a": _garage(md, lod)
		"garage_workbench_a": _workbench(md, false)
		"garage_workbench_a_cluttered": _workbench(md, true)
		"garage_tool_cart_a": _tool_cart(md)
		"garage_tyre_stack_a": _tyres(md)
		"garage_oil_drum_a": _drum(md)
		"garage_engine_hoist_a": _hoist(md)
		"garage_spare_engine_a": _engine(md)
		"garage_air_pump_a": _air_pump(md)
		"garage_fuel_pump_a": _fuel_pump(md)
		"garage_ramp_a": _ramp(md)
		"garage_parts_shelf_a": _shelf(md)
		"garage_sign_a": _gsign(md)
		"garage_bicycle_a": _bicycle(md)
		"garage_toolbox_a": _rolling_toolbox(md)
		"garage_radio_a": _radio(md)
		_: return false
	return true

# ---------------------------------------------------------------- shared helpers
static func _rope(md: NewModels6.Model, a: Vector3, b: Vector3, sag := 0.0, r := 0.006, col := ROPE) -> void:
	var prev := a
	var n := 6 if sag > 0.0 else 1
	for k in range(1, n + 1):
		var t := float(k) / n
		var p := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		NewModels6.limb(md, "rubber", prev, p, r, r, col, 4)
		prev = p

static func _pole(md: NewModels6.Model, base: Vector3, top: Vector3, r := 0.04, col := Color(0.4, 0.33, 0.25)) -> void:
	NewModels6.limb(md, "wood", base, top, r, r * 0.85, col, 7, 0.1)

## A rectangular panel with a little sag, double-sided (same idea as the camp's canvas).
static func _canvas(md: NewModels6.Model, key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, sag := 0.0, nu := 6, nv := 4, vary := 0.05, stripes := 0) -> void:
	var rows: Array = []
	var nrm := (b - a).cross(d - a).normalized()
	for j in nv + 1:
		var v := float(j) / nv
		var r := PackedVector3Array(); r.resize(nu + 1)
		for i in nu + 1:
			var u := float(i) / nu
			r[i] = a.lerp(b, u).lerp(d.lerp(c, u), v) + nrm * (-sag * sin(u * PI) * sin(v * PI))
		rows.append(r)
	var hint := func(_i: int, _j: int, _p: Vector3) -> Vector3: return nrm
	if stripes > 0:
		# alternating stripes by splitting into strips along u
		var per := maxi(1, nu / stripes)
		for s in range(0, nu, per):
			var sub: Array = []
			for j in nv + 1:
				var rr := PackedVector3Array()
				for i in range(s, mini(s + per, nu) + 1): rr.append((rows[j] as PackedVector3Array)[i])
				sub.append(rr)
			var cc := col if (s / per) % 2 == 0 else CREAM
			NewModels6.gridsurf(md, key, sub, cc, hint, vary)
	else:
		NewModels6.gridsurf(md, key, rows, col, hint, vary)

# ================================================================== the festival field
static func _stage(md: NewModels6.Model, lod: int) -> void:
	var w := 5.0; var d := 3.6; var h := 1.0
	# the flatbed: planks on a steel frame, a skirt of boards, three steps at the front
	for k in 10:
		var z := -d * 0.5 + (k + 0.5) * d / 10.0
		NewModels6.box(md, "wood", Vector3(0, h, z), Vector3(w, 0.05, d / 10.0 - 0.006), Color(0.5, 0.4, 0.28), 0.0, Color(0.55, 0.45, 0.32))
	for sx: float in [-1.0, 1.0]:
		NewModels6.box(md, "steel", Vector3(sx * (w * 0.5 - 0.1), h - 0.1, 0), Vector3(0.09, 0.14, d), STEEL)
	for z: float in [-d * 0.5 + 0.1, 0.0, d * 0.5 - 0.1]:
		NewModels6.box(md, "steel", Vector3(0, h - 0.1, z), Vector3(w, 0.1, 0.08), STEEL)
	NewModels6.box(md, "wood", Vector3(0, h * 0.5 - 0.04, d * 0.5 - 0.03), Vector3(w, h - 0.12, 0.04), Color(0.2, 0.2, 0.18))
	for k in 3:
		NewModels6.box(md, "wood", Vector3(1.5, 0.17 + k * 0.28 - 0.14 + 0.0, d * 0.5 + 0.55 - k * 0.2), Vector3(1.0, 0.05, 0.3), Color(0.5, 0.4, 0.28), 0.0, Color(0.55, 0.45, 0.32))
	for sx: float in [-0.3, 0.3]:
		NewModels6.box(md, "steel", Vector3(1.5 + sx * 1.6, 0.36, d * 0.5 + 0.38), Vector3(0.05, 0.72, 0.5), STEEL)
	# four scaffold posts and a roof frame, the canvas roof (green and cream stripes) and a back drape
	var ph := 3.7
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			NewModels6.limb(md, "steel", Vector3(sx * (w * 0.5 - 0.15), h, sz * (d * 0.5 - 0.15)), Vector3(sx * (w * 0.5 - 0.15), h + ph, sz * (d * 0.5 - 0.15)), 0.028, 0.028, Color(0.62, 0.64, 0.66), 8)
	for sx: float in [-1.0, 1.0]:
		NewModels6.limb(md, "steel", Vector3(sx * (w * 0.5 - 0.15), h + ph, -d * 0.5 + 0.15), Vector3(sx * (w * 0.5 - 0.15), h + ph, d * 0.5 - 0.15), 0.022, 0.022, Color(0.62, 0.64, 0.66), 7)
	for sz: float in [-1.0, 1.0]:
		NewModels6.limb(md, "steel", Vector3(-w * 0.5 + 0.15, h + ph, sz * (d * 0.5 - 0.15)), Vector3(w * 0.5 - 0.15, h + ph, sz * (d * 0.5 - 0.15)), 0.022, 0.022, Color(0.62, 0.64, 0.66), 7)
	var y0 := h + ph; var y1 := h + ph + 0.45
	_canvas(md, "canvas", Vector3(-w * 0.5 - 0.1, y0, -d * 0.5 - 0.1), Vector3(w * 0.5 + 0.1, y0, -d * 0.5 - 0.1), Vector3(w * 0.5 + 0.1, y1, 0), Vector3(-w * 0.5 - 0.1, y1, 0), GREEN, 0.03, 10, 3, 0.05, 5)
	_canvas(md, "canvas", Vector3(-w * 0.5 - 0.1, y1, 0), Vector3(w * 0.5 + 0.1, y1, 0), Vector3(w * 0.5 + 0.1, y0, d * 0.5 + 0.3), Vector3(-w * 0.5 - 0.1, y0, d * 0.5 + 0.3), GREEN, 0.03, 10, 3, 0.05, 5)
	_canvas(md, "canvas", Vector3(-w * 0.5, y0, -d * 0.5 + 0.1), Vector3(w * 0.5, y0, -d * 0.5 + 0.1), Vector3(w * 0.5, h + 0.15, -d * 0.5 + 0.1), Vector3(-w * 0.5, h + 0.15, -d * 0.5 + 0.1), Color(0.1, 0.1, 0.12), 0.1, 8, 6, 0.06)
	# lights on the front truss and a pair of stage monitors
	for sx: float in [-1.8, -0.6, 0.6, 1.8]:
		NewModels6.cyl(md, "paint", Vector3(sx, y0 - 0.04, d * 0.5 - 0.2), Vector3(sx, y0 - 0.3, d * 0.5 - 0.05), 0.07, 0.09, 8, Color(0.06, 0.06, 0.07), 3, 0.0)
		var lg := md.sub("lamp_glass_" + str(int(sx * 10.0)), Vector3(sx, y0 - 0.3, d * 0.5 - 0.05))
		NewModels6.cyl(lg, "lamp", Vector3(sx, y0 - 0.3, d * 0.5 - 0.05), Vector3(sx, y0 - 0.32, d * 0.5 - 0.03), 0.075, 0.075, 8, Color(1.0, 0.85, 0.6), 3, 0.0)
	for sx: float in [-1.2, 1.2]:
		NewModels6.box(md, "paint", Vector3(sx, h + 0.17, d * 0.5 - 0.5), Vector3(0.5, 0.34, 0.3), Color(0.05, 0.05, 0.06), 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, 0.5))
	NewModels6.hull(md, Vector3(0, h * 0.5, 0), Vector3(w, h, d))
	NewModels6.hull(md, Vector3(0, h + ph * 0.5, 0), Vector3(w, ph, d))

static func _marquee(md: NewModels6.Model, lod: int) -> void:
	var w := 8.0; var d := 5.0; var wh := 2.0; var rh := 3.6
	var col := CREAM
	# the roof: two long sloping panels from the eaves to the ridge, plus the two gable ends and the side walls with scalloped skirts
	_canvas(md, "canvas", Vector3(-w * 0.5, wh, -d * 0.5), Vector3(w * 0.5, wh, -d * 0.5), Vector3(w * 0.5, rh, 0), Vector3(-w * 0.5, rh, 0), col, 0.05, 10, 4, 0.04)
	_canvas(md, "canvas", Vector3(-w * 0.5, rh, 0), Vector3(w * 0.5, rh, 0), Vector3(w * 0.5, wh, d * 0.5), Vector3(-w * 0.5, wh, d * 0.5), col, 0.05, 10, 4, 0.04)
	for sz: float in [-1.0, 1.0]:
		_canvas(md, "canvas", Vector3(-w * 0.5, 0.0, sz * d * 0.5), Vector3(w * 0.5, 0.0, sz * d * 0.5), Vector3(w * 0.5, wh, sz * d * 0.5), Vector3(-w * 0.5, wh, sz * d * 0.5), col * 0.97, 0.02, 10, 3, 0.04)
		# the scalloped valance
		for k in 16:
			var x := -w * 0.5 + (k + 0.5) * w / 16.0
			NewModels6.sheet(md, "canvas", [Vector3(x - w / 32.0, wh, sz * (d * 0.5 + 0.04)), Vector3(x + w / 32.0, wh, sz * (d * 0.5 + 0.04)), Vector3(x, wh - 0.22, sz * (d * 0.5 + 0.04))], GREEN if k % 2 == 0 else col, Vector3(0, 0, sz))
	# the ends: one closed with a window, one open with the flaps tied back
	NewModels6.sheet(md, "canvas", [Vector3(-w * 0.5, wh, -d * 0.5), Vector3(-w * 0.5, 0.0, -d * 0.5), Vector3(-w * 0.5, 0.0, d * 0.5), Vector3(-w * 0.5, wh, d * 0.5), Vector3(-w * 0.5, rh, 0)], col * 0.96, Vector3(-1, 0, 0))
	for sz: float in [-1.0, 1.0]:
		NewModels6.sheet(md, "canvas", [Vector3(w * 0.5, 0.0, sz * d * 0.5), Vector3(w * 0.5, 0.0, sz * 1.0), Vector3(w * 0.5, rh * 0.8, 0.0), Vector3(w * 0.5, wh, sz * d * 0.5)], col * 0.96, Vector3(1, 0, 0))
		NewModels6.limb(md, "rubber", Vector3(w * 0.5 + 0.02, 0.9, sz * 1.0), Vector3(w * 0.5 + 0.05, 1.0, sz * 1.2), 0.012, 0.012, ROPE, 4)
	# poles: two tall centre poles and the eave poles; ropes to pegs
	for sx: float in [-3.0, 3.0]:
		NewModels6.limb(md, "wood", Vector3(sx, 0.0, 0), Vector3(sx, rh + 0.1, 0), 0.05, 0.04, Color(0.42, 0.34, 0.25), 8, 0.1)
	NewModels6.limb(md, "wood", Vector3(-w * 0.5, rh, 0), Vector3(w * 0.5, rh, 0), 0.03, 0.03, Color(0.42, 0.34, 0.25), 6)
	for sx: float in [-w * 0.5, 0.0, w * 0.5]:
		for sz: float in [-1.0, 1.0]:
			NewModels6.limb(md, "wood", Vector3(sx, 0.0, sz * (d * 0.5 + 0.05)), Vector3(sx, wh, sz * (d * 0.5 + 0.05)), 0.03, 0.03, Color(0.42, 0.34, 0.25), 6)
			var peg := Vector3(sx, 0.0, sz * (d * 0.5 + 1.1))
			_rope(md, Vector3(sx, wh - 0.1, sz * (d * 0.5 + 0.05)), peg)
			NewModels6.limb(md, "steel", peg + Vector3(0, 0.15, 0), peg - Vector3(0, 0.03, 0), 0.01, 0.007, STEEL, 5)
	# the floor: matting, and a few trestle tables and stacked chairs inside to give it a use
	NewModels6.box(md, "rubber", Vector3(0, 0.01, 0), Vector3(w - 0.3, 0.015, d - 0.3), Color(0.25, 0.26, 0.2), 0.0, Color(-1, 0, 0))
	for k in 3:
		NewModels6.box(md, "wood", Vector3(-2.4 + k * 2.4, 0.74, -1.2), Vector3(1.8, 0.035, 0.7), Color(0.55, 0.47, 0.35), 0.0, Color(0.58, 0.5, 0.38))
		for sx: float in [-0.8, 0.8]:
			NewModels6.limb(md, "steel", Vector3(-2.4 + k * 2.4 + sx, 0.0, -1.0), Vector3(-2.4 + k * 2.4 + sx, 0.73, -1.4), 0.02, 0.02, STEEL, 5)
			NewModels6.limb(md, "steel", Vector3(-2.4 + k * 2.4 + sx, 0.0, -1.4), Vector3(-2.4 + k * 2.4 + sx, 0.73, -1.0), 0.02, 0.02, STEEL, 5)
	NewModels6.hull(md, Vector3(0, 1.5, 0), Vector3(w, 3.0, d))

static func _stall(md: NewModels6.Model, variant: int, lod: int) -> void:
	var w := 2.6; var d := 1.3; var ph := 2.35
	var col := GREEN if variant == 0 else PAINT_R
	# counter, back shelves, four posts, the striped awning with a scalloped front
	NewModels6.box(md, "wood", Vector3(0, 0.45, d * 0.5 - 0.15), Vector3(w, 0.9, 0.5), Color(0.4, 0.31, 0.22))
	NewModels6.box(md, "wood", Vector3(0, 0.92, d * 0.5 - 0.15), Vector3(w + 0.1, 0.04, 0.56), Color(0.52, 0.43, 0.32), 0.0, Color(0.56, 0.47, 0.35))
	NewModels6.box(md, "wood", Vector3(0, 1.0, -d * 0.5 + 0.12), Vector3(w - 0.2, 0.03, 0.3), Color(0.45, 0.36, 0.26))
	NewModels6.box(md, "wood", Vector3(0, 1.6, -d * 0.5 + 0.12), Vector3(w - 0.2, 0.03, 0.3), Color(0.45, 0.36, 0.26))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			NewModels6.limb(md, "wood", Vector3(sx * (w * 0.5 - 0.03), 0.0, sz * (d * 0.5 - 0.05)), Vector3(sx * (w * 0.5 - 0.03), ph, sz * (d * 0.5 - 0.05)), 0.04, 0.035, Color(0.42, 0.34, 0.25), 7, 0.1)
	_canvas(md, "canvas", Vector3(-w * 0.5 - 0.1, ph, -d * 0.5), Vector3(w * 0.5 + 0.1, ph, -d * 0.5), Vector3(w * 0.5 + 0.1, ph - 0.35, d * 0.5 + 0.4), Vector3(-w * 0.5 - 0.1, ph - 0.35, d * 0.5 + 0.4), col, 0.03, 10, 3, 0.05, 10)
	for k in 10:
		var x := -w * 0.5 - 0.1 + (k + 0.5) * (w + 0.2) / 10.0
		NewModels6.sheet(md, "canvas", [Vector3(x - (w + 0.2) / 20.0, ph - 0.35, d * 0.5 + 0.4), Vector3(x + (w + 0.2) / 20.0, ph - 0.35, d * 0.5 + 0.4), Vector3(x, ph - 0.55, d * 0.5 + 0.4)], col if k % 2 == 0 else CREAM, Vector3(0, -0.3, 1))
	# wares: crates of apples, jars, a cloth, a chalk board
	for k in 4:
		NewModels6.box(md, "wood", Vector3(-0.9 + k * 0.58, 1.02, d * 0.5 - 0.12), Vector3(0.45, 0.14, 0.34), Color(0.5, 0.4, 0.28), (NewModels6.rnd(k, 1.0) - 0.5) * 0.2)
		for j in 5:
			NewModels6.ball(md, "paint", Vector3(-0.9 + k * 0.58 + (j % 3 - 1) * 0.1, 1.12, d * 0.5 - 0.12 + (j / 3 - 0.5) * 0.12), Vector3(0.045, 0.045, 0.045), Color(0.55 + 0.1 * (k % 2), 0.12 + 0.3 * (k % 2), 0.08), 6)
	for k in 6:
		NewModels6.cyl(md, "glass", Vector3(-0.8 + k * 0.3, 1.03, -d * 0.5 + 0.12), Vector3(-0.8 + k * 0.3, 1.2, -d * 0.5 + 0.12), 0.045, 0.045, 8, Color(0.7, 0.55, 0.2), 3, 0.0)
	NewModels6.box(md, "wood", Vector3(0.0, 0.45, d * 0.5 + 0.12), Vector3(0.7, 0.55, 0.03), Color(0.08, 0.1, 0.09), 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, -0.2))
	NewModels6.hull(md, Vector3(0, 1.1, 0), Vector3(w, 2.2, d))

static func _bunting(md: NewModels6.Model, set: int) -> void:
	# 10 m of string from x = 0 to 10 at 2.5 m, sagging 0.35 m; triangular flags hang every 0.33 m. Ends are level so segments repeat.
	var sets := [[Color(0.7, 0.12, 0.1), CREAM, Color(0.12, 0.3, 0.2)], [Color(0.9, 0.7, 0.15), Color(0.12, 0.3, 0.5), CREAM], [Color(0.55, 0.2, 0.35), Color(0.9, 0.55, 0.15), Color(0.15, 0.5, 0.45)]]
	var cols: Array = sets[set]
	var sag := 0.35
	var h0 := 2.5
	var prev := Vector3(0, h0, 0)
	var n := 30
	for k in range(1, n + 1):
		var x := 10.0 * k / n
		var t := float(k) / n
		var p := Vector3(x, h0 - sag * 4.0 * t * (1.0 - t), 0)
		NewModels6.limb(md, "rubber", prev, p, 0.004, 0.004, Color(0.75, 0.7, 0.6), 3)
		prev = p
	for k in 30:
		var x := 0.17 + k * 0.325
		var t := x / 10.0
		var y := h0 - sag * 4.0 * t * (1.0 - t)
		var c: Color = cols[k % 3]
		var tilt := sin(k * 1.7) * 0.03
		NewModels6.sheet(md, "cloth", [Vector3(x - 0.11, y, 0), Vector3(x + 0.11, y, 0), Vector3(x + tilt, y - 0.3, 0.01)], c, Vector3(0, 0, 1))

static func _flag(md: NewModels6.Model, variant: int) -> void:
	# a 6 m festival pole with a swallow-tailed pennant, fictional colours
	NewModels6.limb(md, "wood", Vector3(0, 0, 0), Vector3(0, 6.0, 0), 0.055, 0.03, Color(0.78, 0.76, 0.7), 8, 0.05)
	NewModels6.ball(md, "chrome", Vector3(0, 6.04, 0), Vector3(0.04, 0.04, 0.04), Color(0.8, 0.7, 0.3), 8)
	NewModels6.cyl(md, "wood", Vector3(0, 0, 0), Vector3(0, 0.25, 0), 0.09, 0.075, 8, Color(0.3, 0.3, 0.3), 3, 0.0)
	var c0 := GREEN if variant == 0 else Color(0.55, 0.14, 0.1)
	var c1 := CREAM
	var y1 := 5.9; var y0 := 5.1
	# the pennant streaming out in +x with the wind, in four panels
	for k in 4:
		var x0 := 0.04 + k * 0.5
		var x1 := x0 + 0.5
		var dy0 := sin(k * 0.8) * 0.06
		var dy1 := sin((k + 1) * 0.8) * 0.06
		var cc := c0 if k % 2 == 0 else c1
		NewModels6.sheet(md, "cloth", [Vector3(x0, y1 + dy0, 0.0), Vector3(x1, y1 + dy1, 0.0), Vector3(x1, y0 + dy1 * 0.5, 0.0), Vector3(x0, y0 + dy0 * 0.5, 0.0)], cc, Vector3(0, 0, 1))
	NewModels6.sheet(md, "cloth", [Vector3(2.04, y1, 0), Vector3(2.4, y1 + 0.02, 0.0), Vector3(2.15, (y0 + y1) * 0.5, 0.0), Vector3(2.4, y0 - 0.02, 0.0), Vector3(2.04, y0, 0)], c0, Vector3(0, 0, 1))
	NewModels6.hull(md, Vector3(0, 3.0, 0), Vector3(0.12, 6.0, 0.12))

static func _barrier(md: NewModels6.Model) -> void:
	for sx: float in [-0.85, 0.85]:
		NewModels6.box(md, "wood", Vector3(sx, 0.55, 0), Vector3(0.06, 1.1, 0.08), TIMBER, 0.0)
		NewModels6.limb(md, "wood", Vector3(sx, 0.9, -0.0), Vector3(sx, 0.0, 0.5), 0.025, 0.025, TIMBER * 0.9, 6, 0.1)
		NewModels6.limb(md, "wood", Vector3(sx, 0.9, 0.0), Vector3(sx, 0.0, -0.5), 0.025, 0.025, TIMBER * 0.9, 6, 0.1)
	for y: float in [0.45, 0.78, 1.05]:
		NewModels6.box(md, "wood", Vector3(0, y, 0), Vector3(2.0, 0.09, 0.03), TIMBER * 1.05, 0.0)
	NewModels6.box(md, "paint", Vector3(0, 0.78, 0.019), Vector3(0.9, 0.09, 0.003), Color(0.7, 0.1, 0.08))
	NewModels6.hull(md, Vector3(0, 0.55, 0), Vector3(2.0, 1.1, 1.0))

static func _picnic(md: NewModels6.Model) -> void:
	for k in 5:
		NewModels6.box(md, "wood", Vector3(0, 0.77, -0.35 + k * 0.175), Vector3(1.8, 0.04, 0.165), Color(0.5, 0.4, 0.28), 0.0, Color(0.55, 0.45, 0.32))
	for sz: float in [-1.0, 1.0]:
		for k in 3:
			NewModels6.box(md, "wood", Vector3(0, 0.45, sz * (0.5 + 0.16 * (k - 1))), Vector3(1.8, 0.04, 0.12), Color(0.5, 0.4, 0.28), 0.0)
	for sx: float in [-0.7, 0.7]:
		NewModels6.limb(md, "wood", Vector3(sx, 0.0, -0.55), Vector3(sx, 0.75, -0.1), 0.04, 0.04, TIMBER, 6, 0.1)
		NewModels6.limb(md, "wood", Vector3(sx, 0.0, 0.55), Vector3(sx, 0.75, 0.1), 0.04, 0.04, TIMBER, 6, 0.1)
		NewModels6.box(md, "wood", Vector3(sx, 0.38, 0.0), Vector3(0.05, 0.05, 1.2), TIMBER)
	NewModels6.hull(md, Vector3(0, 0.45, 0), Vector3(1.9, 0.9, 1.7))

static func _lamp_string(md: NewModels6.Model) -> void:
	# 8 m of black cable between two points at 2.6 m with a bulb every 0.4 m, sagging 0.25 m
	var prev := Vector3(0, 2.6, 0)
	var n := 24
	for k in range(1, n + 1):
		var t := float(k) / n
		var p := Vector3(8.0 * t, 2.6 - 0.25 * 4.0 * t * (1.0 - t), 0)
		NewModels6.limb(md, "rubber", prev, p, 0.005, 0.005, Color(0.05, 0.05, 0.05), 3)
		prev = p
	var bulbs := md.sub("bulbs", Vector3(0, 2.6, 0))
	for k in 21:
		var t2 := float(k) / 20.0
		var p2 := Vector3(8.0 * t2, 2.6 - 0.25 * 4.0 * t2 * (1.0 - t2), 0)
		NewModels6.cyl(md, "rubber", p2, p2 - Vector3(0, 0.04, 0), 0.012, 0.012, 5, Color(0.1, 0.1, 0.1), 3, 0.0)
		NewModels6.ball(bulbs, "lamp", p2 - Vector3(0, 0.075, 0), Vector3(0.04, 0.05, 0.04), Color.WHITE, 8)

static func _pa(md: NewModels6.Model) -> void:
	for k in 3:
		var a := TAU * k / 3.0
		NewModels6.limb(md, "steel", Vector3(0, 1.3, 0), Vector3(cos(a) * 0.45, 0.0, sin(a) * 0.45), 0.014, 0.014, Color(0.08, 0.08, 0.09), 6)
	NewModels6.limb(md, "steel", Vector3(0, 0.5, 0), Vector3(0, 1.45, 0), 0.02, 0.02, Color(0.12, 0.12, 0.13), 7)
	NewModels6.rbox(md, "paint", Vector3(0, 1.75, 0), Vector3(0.42, 0.62, 0.36), Color(0.07, 0.07, 0.08), Basis(Vector3.RIGHT, 0.08), 5.0, 10, 0.05)
	NewModels6.cyl(md, "rubber", Vector3(0, 1.62, 0.17), Vector3(0, 1.62, 0.19), 0.13, 0.13, 14, Color(0.03, 0.03, 0.03), 3, 0.0)
	NewModels6.cyl(md, "rubber", Vector3(0, 1.9, 0.17), Vector3(0, 1.9, 0.19), 0.05, 0.05, 10, Color(0.03, 0.03, 0.03), 3, 0.0)
	NewModels6.limb(md, "rubber", Vector3(0, 1.45, -0.1), Vector3(0.25, 0.1, -0.5), 0.006, 0.006, Color(0.05, 0.05, 0.05), 4)
	NewModels6.hull(md, Vector3(0, 0.9, 0), Vector3(0.9, 1.8, 0.9))

static func _banner(md: NewModels6.Model) -> void:
	# a 4 m banner between two poles: dark green cloth with the festival name in cream block letters
	for sx: float in [-2.15, 2.15]:
		_pole(md, Vector3(sx, 0.0, 0), Vector3(sx, 3.4, 0), 0.045)
		NewModels6.limb(md, "steel", Vector3(sx, 0.0, 0), Vector3(sx, 0.2, 0), 0.07, 0.07, STEEL, 8)
	_canvas(md, "cloth", Vector3(-2.0, 3.2, 0), Vector3(2.0, 3.2, 0), Vector3(2.0, 2.2, 0), Vector3(-2.0, 2.2, 0), Color(0.1, 0.25, 0.17), 0.04, 12, 5, 0.04)
	NewModels6.text(md, "cloth", "HALLOWAY FESTIVAL", Vector3(0, 2.46, 0.0), Vector3(0, 0, 1), 0.5, Color(0.9, 0.86, 0.7), Vector3.UP, 0.02)
	NewModels6.text(md, "cloth", "HALLOWAY FESTIVAL", Vector3(0, 2.46, 0.0), Vector3(0, 0, -1), 0.5, Color(0.9, 0.86, 0.7), Vector3.UP, 0.02)
	for sx: float in [-2.0, 2.0]:
		NewModels6.limb(md, "rubber", Vector3(sx, 3.2, 0), Vector3(sx * 1.03, 3.35, 0), 0.006, 0.006, ROPE, 3)
	NewModels6.hull(md, Vector3(0, 1.7, 0), Vector3(4.4, 3.4, 0.2))
	md.hulls.clear()

static func _fsign(md: NewModels6.Model) -> void:
	_pole(md, Vector3(0, 0, 0), Vector3(0, 2.4, 0), 0.06)
	var bd := PackedVector2Array([Vector2(-0.9, 0.28), Vector2(0.55, 0.28), Vector2(1.0, 0.0), Vector2(0.55, -0.28), Vector2(-0.9, -0.28)])
	NewModels6.put(md, "paint", DroneParts.extrude(bd, 0.0, 0.04), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 2.0, 0.025)), Color(0.78, 0.74, 0.58), 0.04)
	NewModels6.text(md, "paint", "FESTIVAL", Vector3(-0.05, 1.89, 0.05), Vector3(0, 0, 1), 0.24, Color(0.1, 0.25, 0.17), Vector3.UP, 0.0)
	NewModels6.text(md, "paint", "FESTIVAL", Vector3(-0.05, 1.89, -0.0), Vector3(0, 0, -1), 0.24, Color(0.1, 0.25, 0.17), Vector3.UP, 0.0)
	NewModels6.hull(md, Vector3(0, 1.2, 0), Vector3(0.2, 2.4, 0.2))

# ================================================================== the garage
static func _garage(md: NewModels6.Model, lod: int) -> void:
	# 12 m wide, 9 m deep, wall 3.8 m, brick lower walls and a corrugated steel roof; a roller door half open, an office window,
	# a yard gate and a fuel pump. Front faces +z.
	var w := 12.0; var d := 9.0; var wh := 3.8; var rh := 1.6
	var brick := Color(0.55, 0.33, 0.25)
	# front wall: the roller door opening 4 m wide x 3.2 m, an office door and a window to its right
	_wall(md, "brick", brick, Vector3(-w * 0.5, 0, d * 0.5), Vector3(w * 0.5, 0, d * 0.5), wh, 0.3, [[2.0, 6.0, 0.0, 3.2], [8.0, 9.0, 0.0, 2.1], [9.8, 11.2, 1.0, 2.2]], Vector3(0, 0, 1))
	_wall(md, "brick", brick, Vector3(-w * 0.5, 0, -d * 0.5), Vector3(w * 0.5, 0, -d * 0.5), wh, 0.3, [[3.0, 5.0, 1.2, 2.4], [7.0, 9.0, 1.2, 2.4]], Vector3(0, 0, -1))
	_wall(md, "brick", brick, Vector3(-w * 0.5, 0, -d * 0.5), Vector3(-w * 0.5, 0, d * 0.5), wh, 0.3, [[2.0, 4.0, 1.2, 2.4], [5.5, 7.5, 1.2, 2.4]], Vector3(-1, 0, 0))
	_wall(md, "brick", brick, Vector3(w * 0.5, 0, d * 0.5), Vector3(w * 0.5, 0, -d * 0.5), wh, 0.3, [[3.0, 6.0, 0.0, 2.6]], Vector3(1, 0, 0))
	# gable ends rising to a low-pitched roof
	for sx: float in [-1.0, 1.0]:
		NewModels6.sheet(md, "brick", [Vector3(sx * w * 0.5, wh, -d * 0.5), Vector3(sx * w * 0.5, wh, d * 0.5), Vector3(sx * w * 0.5, wh + rh, 0)], brick * 0.95, Vector3(sx, 0, 0))
	var ang := atan2(rh, d * 0.5)
	var slope := sqrt(rh * rh + d * d * 0.25)
	for sz: float in [-1.0, 1.0]:
		var c := Vector3(0, wh + rh * 0.5 + 0.06, sz * d * 0.25)
		NewModels6.box(md, "roof", c + Vector3(0, 0.0, sz * 0.3), Vector3(w + 0.6, 0.1, slope + 0.6), Color(0.52, 0.52, 0.5), 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, sz * ang))
	NewModels6.box(md, "roof", Vector3(0, wh + rh + 0.12, 0), Vector3(w + 0.6, 0.1, 0.5), Color(0.5, 0.5, 0.48))
	# floor, an inspection pit in the middle bay, the office door and window, the half-open roller door with its slats
	NewModels6.box(md, "concrete", Vector3(0, 0.02, 0), Vector3(w - 0.5, 0.04, d - 0.5), Color(0.45, 0.45, 0.43))
	NewModels6.box(md, "rubber", Vector3(0, 0.012, 0.8), Vector3(1.2, 0.03, 4.5), Color(0.05, 0.05, 0.05))
	NewModels6.box(md, "paintwood", Vector3(-w * 0.5 + 8.5, 1.05, d * 0.5 - 0.02), Vector3(0.85, 2.05, 0.06), Color(0.14, 0.27, 0.2))
	NewModels6.quad2(md, "glass", Vector3(-w * 0.5 + 9.82, 1.05, d * 0.5 - 0.05), Vector3(-w * 0.5 + 11.18, 1.05, d * 0.5 - 0.05), Vector3(-w * 0.5 + 11.18, 2.18, d * 0.5 - 0.05), Vector3(-w * 0.5 + 9.82, 2.18, d * 0.5 - 0.05), Color.WHITE)
	for sx: float in [-w * 0.5 + 9.8, -w * 0.5 + 11.2]:
		NewModels6.box(md, "paintwood", Vector3(sx, 1.6, d * 0.5 - 0.02), Vector3(0.06, 1.3, 0.08), CREAM)
	NewModels6.box(md, "paintwood", Vector3(-w * 0.5 + 10.5, 1.0, d * 0.5 - 0.02), Vector3(1.5, 0.06, 0.12), CREAM)
	NewModels6.box(md, "paintwood", Vector3(-w * 0.5 + 10.5, 2.22, d * 0.5 - 0.02), Vector3(1.5, 0.06, 0.1), CREAM)
	var rd := md.sub("roller_door", Vector3(0, 3.2, d * 0.5 - 0.1))
	for k in 22:
		NewModels6.box(rd, "roof", Vector3(-w * 0.5 + 4.0, 3.15 - 0.07 * k, d * 0.5 - 0.1), Vector3(4.0, 0.066, 0.05), Color(0.55, 0.5, 0.42) * (0.9 + 0.1 * NewModels6.rnd(k, 1.0)))
	NewModels6.box(rd, "steel", Vector3(-w * 0.5 + 4.0, 3.28, d * 0.5 - 0.1), Vector3(4.2, 0.18, 0.2), STEEL)
	# the VOSS & SON board over the doors
	NewModels6.box(md, "paintwood", Vector3(0, wh + 0.35, d * 0.5 + 0.2), Vector3(7.2, 0.8, 0.1), Color(0.12, 0.26, 0.19))
	NewModels6.text(md, "paintwood", "VOSS & SON", Vector3(0, wh + 0.35, d * 0.5 + 0.26), Vector3(0, 0, 1), 0.42, Color(0.9, 0.86, 0.7), Vector3.UP, 0.0)
	NewModels6.text(md, "paintwood", "MOTOR WORKS", Vector3(0, wh + 0.12, d * 0.5 + 0.26), Vector3(0, 0, 1), 0.18, Color(0.9, 0.86, 0.7), Vector3.UP, 0.0)
	NewModels6.hull(md, Vector3(0, wh * 0.5, 0), Vector3(w, wh, d))
	NewModels6.hull(md, Vector3(0, wh + rh * 0.5, 0), Vector3(w, rh, d))

## A wall from p0 to p1 (horizontal), thick, h high, with openings [t0, t1, y0, y1] in metres along it; `n` is the outward normal.
static func _wall(md: NewModels6.Model, key: String, col: Color, p0: Vector3, p1: Vector3, h: float, thick: float, ops: Array, n: Vector3) -> void:
	var dir := (p1 - p0)
	var L := dir.length()
	dir /= L
	var bas := Basis(dir, Vector3.UP, dir.cross(Vector3.UP))
	var ts: Array = [0.0, L]
	for o in ops: ts.append(float(o[0])); ts.append(float(o[1]))
	ts.sort()
	for i in ts.size() - 1:
		var t0: float = ts[i]; var t1: float = ts[i + 1]
		if t1 - t0 < 0.001: continue
		var ys: Array = [0.0, h]
		for o in ops:
			if float(o[0]) < t1 - 0.0001 and float(o[1]) > t0 + 0.0001: ys.append(float(o[2])); ys.append(float(o[3]))
		ys.sort()
		for j in ys.size() - 1:
			var y0: float = ys[j]; var y1: float = ys[j + 1]
			if y1 - y0 < 0.001: continue
			var inside := false
			for o in ops:
				if float(o[0]) < t1 - 0.0001 and float(o[1]) > t0 + 0.0001 and float(o[2]) < y1 - 0.0001 and float(o[3]) > y0 + 0.0001: inside = true
			if inside: continue
			var c := p0 + dir * ((t0 + t1) * 0.5) + Vector3(0, (y0 + y1) * 0.5, 0)
			NewModels6.box(md, key, c, Vector3(t1 - t0, y1 - y0, thick), NewModels6.vc(col, float(i) * 3.1 + float(j) * 1.7, 0.05), 0.0, Color(-1, 0, 0), bas)

static func _workbench(md: NewModels6.Model, cluttered: bool) -> void:
	var w := 2.2; var d := 0.75
	NewModels6.box(md, "wood", Vector3(0, 0.88, 0), Vector3(w, 0.07, d), Color(0.45, 0.36, 0.26), 0.0, Color(0.5, 0.42, 0.3))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			NewModels6.box(md, "wood", Vector3(sx * (w * 0.5 - 0.06), 0.42, sz * (d * 0.5 - 0.06)), Vector3(0.09, 0.84, 0.09), TIMBER * 0.9)
	NewModels6.box(md, "wood", Vector3(0, 0.25, 0), Vector3(w - 0.2, 0.04, d - 0.1), TIMBER * 0.95)
	NewModels6.box(md, "wood", Vector3(0, 1.45, -d * 0.5 + 0.02), Vector3(w, 0.9, 0.03), Color(0.38, 0.32, 0.24))      # a peg board behind
	# a vice on the left end
	NewModels6.box(md, "steel", Vector3(-0.85, 0.99, 0.2), Vector3(0.16, 0.15, 0.18), Color(0.15, 0.2, 0.17))
	NewModels6.limb(md, "steel", Vector3(-0.85, 0.99, 0.32), Vector3(-0.85, 0.99, 0.5), 0.012, 0.012, Color(0.3, 0.3, 0.32), 6)
	NewModels6.limb(md, "steel", Vector3(-0.95, 0.99, 0.5), Vector3(-0.75, 0.99, 0.5), 0.008, 0.008, Color(0.3, 0.3, 0.32), 5)
	# tools on the peg board: hammers, spanners
	for k in 8:
		var x := -0.9 + k * 0.26
		NewModels6.limb(md, "wood", Vector3(x, 1.55, -d * 0.5 + 0.06), Vector3(x, 1.2, -d * 0.5 + 0.06), 0.01, 0.01, Color(0.5, 0.38, 0.22), 5)
		NewModels6.box(md, "steel", Vector3(x, 1.57, -d * 0.5 + 0.06), Vector3(0.08, 0.05, 0.03), Color(0.3, 0.3, 0.33))
	if cluttered:
		for k in 7:
			NewModels6.box(md, "chrome", Vector3(-0.3 + k * 0.15, 0.93, -0.1 + (NewModels6.rnd(k, 2.0) - 0.5) * 0.3), Vector3(0.025, 0.012, 0.18), Color(0.55, 0.56, 0.6), (NewModels6.rnd(k, 3.0) - 0.5) * 2.0)
		NewModels6.cyl(md, "paint", Vector3(0.5, 0.915, 0.1), Vector3(0.5, 1.02, 0.1), 0.06, 0.06, 10, Color(0.55, 0.45, 0.1), 3, 0.05)
		NewModels6.box(md, "rust", Vector3(0.75, 0.97, -0.05), Vector3(0.28, 0.1, 0.2), Color(0.42, 0.14, 0.1))
		NewModels6.ball(md, "rust", Vector3(0.1, 0.96, 0.2), Vector3(0.09, 0.06, 0.07), Color(0.18, 0.16, 0.14), 6)
		NewModels6.box(md, "paper", Vector3(-0.5, 0.92, 0.1), Vector3(0.3, 0.004, 0.22), Color(0.82, 0.8, 0.7), 0.4)
		NewModels6.cyl(md, "enamel", Vector3(0.95, 0.915, 0.2), Vector3(0.95, 1.0, 0.2), 0.04, 0.04, 8, Color(0.78, 0.76, 0.68), 3, 0.0)
	else:
		for k in 3:
			NewModels6.box(md, "chrome", Vector3(-0.3 + k * 0.05, 0.93, 0.15), Vector3(0.025, 0.012, 0.16), Color(0.55, 0.56, 0.6))
	NewModels6.hull(md, Vector3(0, 0.45, 0), Vector3(w, 0.9, d))

static func _tool_cart(md: NewModels6.Model) -> void:
	var red := Color(0.45, 0.1, 0.08)
	NewModels6.box(md, "paint", Vector3(0, 0.62, 0), Vector3(0.7, 0.62, 0.45), red)
	NewModels6.box(md, "paint", Vector3(0, 0.95, 0), Vector3(0.74, 0.03, 0.49), Color(0.5, 0.5, 0.52))
	for k in 4:
		NewModels6.box(md, "paint", Vector3(0, 0.38 + k * 0.14, 0.23), Vector3(0.64, 0.115, 0.01), red * 1.1)
		NewModels6.box(md, "chrome", Vector3(0, 0.38 + k * 0.14, 0.24), Vector3(0.2, 0.015, 0.015), Color(0.7, 0.7, 0.72))
	for sx: float in [-0.3, 0.3]:
		for sz: float in [-0.18, 0.18]:
			NewModels6.cyl(md, "rubber", Vector3(sx - 0.015, 0.05, sz), Vector3(sx + 0.015, 0.05, sz), 0.05, 0.05, 10, Color(0.06, 0.06, 0.06), 3, 0.0)
	NewModels6.limb(md, "steel", Vector3(-0.3, 0.95, -0.22), Vector3(-0.3, 1.1, -0.28), 0.012, 0.012, STEEL, 5)
	NewModels6.limb(md, "steel", Vector3(0.3, 0.95, -0.22), Vector3(0.3, 1.1, -0.28), 0.012, 0.012, STEEL, 5)
	NewModels6.limb(md, "steel", Vector3(-0.3, 1.1, -0.28), Vector3(0.3, 1.1, -0.28), 0.012, 0.012, STEEL, 5)
	NewModels6.hull(md, Vector3(0, 0.55, 0), Vector3(0.74, 1.1, 0.5))

static func _tyres(md: NewModels6.Model) -> void:
	var prof := PackedVector2Array([Vector2(0.17, -0.1), Vector2(0.28, -0.11), Vector2(0.33, -0.08), Vector2(0.34, 0.0), Vector2(0.33, 0.08), Vector2(0.28, 0.11), Vector2(0.17, 0.1), Vector2(0.15, 0.0)])
	for k in 5:
		var off := Vector3((NewModels6.rnd(k, 1.0) - 0.5) * 0.06, 0.1 + k * 0.205, (NewModels6.rnd(k, 2.0) - 0.5) * 0.06)
		NewModels6.put(md, "rubber", DroneParts.lathe(prof, 16), Transform3D(Basis(Vector3.UP, k * 0.9), off), Color(0.07, 0.07, 0.07) * (0.8 + 0.4 * NewModels6.rnd(k, 3.0)), 0.1)
	NewModels6.hull(md, Vector3(0, 0.55, 0), Vector3(0.7, 1.1, 0.7))

static func _drum(md: NewModels6.Model) -> void:
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.28, 0.0), Vector2(0.295, 0.02), Vector2(0.295, 0.05), Vector2(0.285, 0.06), Vector2(0.285, 0.28), Vector2(0.295, 0.3), Vector2(0.295, 0.58), Vector2(0.285, 0.6), Vector2(0.285, 0.82), Vector2(0.295, 0.84), Vector2(0.295, 0.88), Vector2(0.0, 0.88)])
	NewModels6.put(md, "paint", DroneParts.lathe(prof, 22), Transform3D.IDENTITY, Color(0.16, 0.22, 0.33), 0.05)
	NewModels6.box(md, "paper", Vector3(0, 0.45, 0.292), Vector3(0.36, 0.22, 0.004), Color(0.8, 0.76, 0.62))
	NewModels6.box(md, "rust", Vector3(0.1, 0.12, 0.29), Vector3(0.14, 0.2, 0.006), Color(0.4, 0.16, 0.08), 0.2)
	NewModels6.hull(md, Vector3(0, 0.44, 0), Vector3(0.6, 0.88, 0.6))

static func _hoist(md: NewModels6.Model) -> void:
	var blue := Color(0.1, 0.22, 0.4)
	for sx: float in [-1.0, 1.0]:
		NewModels6.box(md, "paint", Vector3(sx * 0.55, 0.1, 0.35), Vector3(0.08, 0.08, 1.5), blue)
		NewModels6.cyl(md, "rubber", Vector3(sx * 0.55 - 0.02, 0.06, 1.05), Vector3(sx * 0.55 + 0.02, 0.06, 1.05), 0.06, 0.06, 8, Color(0.05, 0.05, 0.05), 3, 0.0)
		NewModels6.cyl(md, "rubber", Vector3(sx * 0.55 - 0.02, 0.06, -0.35), Vector3(sx * 0.55 + 0.02, 0.06, -0.35), 0.06, 0.06, 8, Color(0.05, 0.05, 0.05), 3, 0.0)
	NewModels6.box(md, "paint", Vector3(0, 0.1, -0.3), Vector3(1.1, 0.08, 0.08), blue)
	NewModels6.box(md, "paint", Vector3(0, 1.0, -0.3), Vector3(0.1, 1.9, 0.1), blue)
	NewModels6.box(md, "paint", Vector3(0, 1.95, 0.3), Vector3(0.1, 0.1, 1.3), blue)
	NewModels6.limb(md, "steel", Vector3(0, 0.2, -0.3), Vector3(0, 1.9, 0.6), 0.03, 0.03, blue * 0.9, 6)
	NewModels6.limb(md, "chrome", Vector3(0, 1.9, 0.8), Vector3(0, 1.1, 0.8), 0.01, 0.01, Color(0.4, 0.4, 0.42), 4)
	NewModels6.ball(md, "steel", Vector3(0, 1.08, 0.8), Vector3(0.05, 0.07, 0.05), Color(0.15, 0.15, 0.16), 6)
	NewModels6.hull(md, Vector3(0, 1.0, 0.3), Vector3(1.3, 2.0, 1.6))

static func _engine(md: NewModels6.Model) -> void:
	NewModels6.box(md, "wood", Vector3(0, 0.07, 0), Vector3(1.0, 0.14, 1.0), Color(0.5, 0.4, 0.28), 0.0, Color(0.55, 0.45, 0.32))
	NewModels6.box(md, "wood", Vector3(0, 0.05, 0), Vector3(1.02, 0.05, 0.08), Color(0.4, 0.32, 0.22))
	var iron := Color(0.2, 0.2, 0.21)
	NewModels6.box(md, "rust", Vector3(0, 0.42, 0), Vector3(0.52, 0.5, 0.78), iron * 1.2)         # block
	for k in 6:
		NewModels6.box(md, "rust", Vector3(0, 0.77, -0.3 + k * 0.12), Vector3(0.44, 0.2, 0.09), iron)
		NewModels6.cyl(md, "rust", Vector3(0.0, 0.88, -0.3 + k * 0.12), Vector3(0.0, 0.93, -0.3 + k * 0.12), 0.03, 0.03, 6, Color(0.5, 0.45, 0.4), 3, 0.0)
	NewModels6.box(md, "rust", Vector3(0, 0.92, 0.0), Vector3(0.5, 0.05, 0.74), Color(0.4, 0.15, 0.1))
	NewModels6.cyl(md, "rust", Vector3(0, 0.45, -0.38), Vector3(0, 0.45, -0.52), 0.2, 0.2, 14, Color(0.15, 0.15, 0.16), 3, 0.0)
	NewModels6.limb(md, "rust", Vector3(-0.28, 0.6, 0.1), Vector3(-0.28, 0.2, 0.4), 0.03, 0.03, Color(0.35, 0.17, 0.1), 6)
	NewModels6.hull(md, Vector3(0, 0.5, 0), Vector3(1.0, 1.0, 1.0))

static func _air_pump(md: NewModels6.Model) -> void:
	NewModels6.cyl(md, "steel", Vector3(0, 0.0, 0), Vector3(0, 0.55, 0), 0.04, 0.04, 10, Color(0.6, 0.12, 0.1), 3, 0.04)
	NewModels6.box(md, "steel", Vector3(0, 0.02, 0), Vector3(0.2, 0.04, 0.2), Color(0.1, 0.1, 0.11))
	NewModels6.limb(md, "chrome", Vector3(0, 0.55, 0), Vector3(0, 0.9, 0), 0.012, 0.012, Color(0.7, 0.7, 0.72), 6)
	NewModels6.limb(md, "rubber", Vector3(-0.17, 0.9, 0), Vector3(0.17, 0.9, 0), 0.014, 0.014, Color(0.08, 0.08, 0.08), 6)
	var prev := Vector3(0.0, 0.5, 0.045)
	for k in 10:
		var t := (k + 1) / 10.0
		var p := Vector3(0.2 * sin(t * 6.0), 0.5 - 0.45 * t, 0.045 + 0.18 * t + 0.03 * sin(t * 9.0))
		NewModels6.limb(md, "rubber", prev, p, 0.011, 0.011, Color(0.05, 0.05, 0.05), 4)
		prev = p
	NewModels6.cyl(md, "chrome", prev, prev + Vector3(0.0, 0.0, 0.07), 0.018, 0.018, 6, Color(0.6, 0.6, 0.62), 3, 0.0)
	NewModels6.hull(md, Vector3(0, 0.45, 0), Vector3(0.4, 0.9, 0.4))

static func _fuel_pump(md: NewModels6.Model) -> void:
	# an old roadside pump: a rusted red column with a glass-less dial head and a hose and nozzle
	var red := Color(0.5, 0.1, 0.08)
	NewModels6.box(md, "concrete", Vector3(0, 0.05, 0), Vector3(0.7, 0.1, 0.55), Color(0.4, 0.4, 0.38))
	NewModels6.box(md, "rust", Vector3(0, 0.62, 0), Vector3(0.42, 1.1, 0.34), red, 0.0, red * 1.05)
	NewModels6.box(md, "rust", Vector3(0, 1.31, 0), Vector3(0.46, 0.32, 0.38), red * 0.9)
	NewModels6.cyl(md, "enamel", Vector3(0, 1.32, 0.19), Vector3(0, 1.32, 0.205), 0.12, 0.12, 14, Color(0.82, 0.8, 0.72), 3, 0.0)
	NewModels6.limb(md, "rubber", Vector3(0, 1.32, 0.205), Vector3(0.05, 1.37, 0.205), 0.004, 0.004, Color(0.1, 0.1, 0.1), 3)
	NewModels6.ball(md, "rust", Vector3(0, 1.52, 0.0), Vector3(0.14, 0.04, 0.14), red * 0.8, 8)
	NewModels6.box(md, "paper", Vector3(0, 0.85, 0.172), Vector3(0.28, 0.14, 0.004), Color(0.76, 0.7, 0.5))
	NewModels6.cyl(md, "chrome", Vector3(0.24, 0.55, 0.0), Vector3(0.24, 0.85, 0.0), 0.012, 0.012, 6, Color(0.1, 0.1, 0.1), 3, 0.0)
	var prev := Vector3(0.21, 0.9, 0.0)
	for k in 8:
		var t := (k + 1) / 8.0
		var p := Vector3(0.21 + 0.18 * t, 0.9 - 0.4 * t, 0.0 + 0.1 * sin(t * 4.0))
		NewModels6.limb(md, "rubber", prev, p, 0.014, 0.014, Color(0.07, 0.07, 0.07), 4)
		prev = p
	NewModels6.hull(md, Vector3(0.1, 0.8, 0), Vector3(0.8, 1.6, 0.6))

static func _ramp(md: NewModels6.Model) -> void:
	for sx: float in [-0.55, 0.55]:
		NewModels6.box(md, "steel", Vector3(sx, 0.22, 0.05), Vector3(0.38, 0.05, 2.5), Color(0.28, 0.3, 0.32), 0.0, Color(-1, 0, 0), Basis(Vector3.RIGHT, 0.0))
		NewModels6.box(md, "steel", Vector3(sx, 0.35, -1.0), Vector3(0.38, 0.06, 0.5), Color(0.3, 0.32, 0.34))
		for k in 5:
			NewModels6.limb(md, "steel", Vector3(sx - 0.18, 0.19, -0.7 + k * 0.5), Vector3(sx - 0.18, 0.0, -0.7 + k * 0.5), 0.02, 0.02, Color(0.2, 0.22, 0.24), 5)
			NewModels6.limb(md, "steel", Vector3(sx + 0.18, 0.19, -0.7 + k * 0.5), Vector3(sx + 0.18, 0.0, -0.7 + k * 0.5), 0.02, 0.02, Color(0.2, 0.22, 0.24), 5)
	NewModels6.box(md, "steel", Vector3(0, 0.12, 1.2), Vector3(1.5, 0.05, 0.1), Color(0.25, 0.27, 0.3))
	NewModels6.hull(md, Vector3(0, 0.3, 0), Vector3(1.6, 0.6, 2.7))

static func _shelf(md: NewModels6.Model) -> void:
	var steel := Color(0.22, 0.28, 0.32)
	for sx: float in [-0.5, 0.5]:
		NewModels6.box(md, "paint", Vector3(sx, 1.0, 0), Vector3(0.05, 2.0, 0.3), steel)
	for y: float in [0.2, 0.7, 1.2, 1.7]:
		NewModels6.box(md, "paint", Vector3(0, y, 0), Vector3(1.05, 0.03, 0.34), steel * 1.1)
	# tins, belts in coils, boxes
	for k in 4:
		NewModels6.cyl(md, "paint", Vector3(-0.35 + k * 0.1, 0.215, 0.0), Vector3(-0.35 + k * 0.1, 0.33, 0.0), 0.04, 0.04, 8, [Color(0.7, 0.55, 0.1), Color(0.5, 0.12, 0.1), Color(0.15, 0.3, 0.2), Color(0.75, 0.75, 0.72)][k], 3, 0.05)
	for k in 3:
		NewModels6.cyl(md, "rubber", Vector3(-0.3 + k * 0.28, 0.72, 0.0), Vector3(-0.3 + k * 0.28, 0.82, 0.0), 0.1, 0.1, 12, Color(0.06, 0.06, 0.06), 3, 0.0)
		NewModels6.cyl(md, "rubber", Vector3(-0.3 + k * 0.28, 0.72, 0.0), Vector3(-0.3 + k * 0.28, 0.83, 0.0), 0.05, 0.05, 8, Color(0.02, 0.02, 0.02), 3, 0.0)
	for k in 5:
		NewModels6.box(md, "paper", Vector3(-0.38 + k * 0.19, 1.3, 0.0), Vector3(0.16, 0.18 + 0.03 * (k % 2), 0.22), Color(0.6, 0.5, 0.35) * (0.85 + 0.2 * NewModels6.rnd(k, 1.0)), 0.1 * k)
	for k in 4:
		NewModels6.box(md, "paper", Vector3(-0.35 + k * 0.23, 1.8, 0.0), Vector3(0.2, 0.2, 0.24), Color(0.52, 0.42, 0.3) * (0.85 + 0.2 * NewModels6.rnd(k, 2.0)), 0.0)
	NewModels6.hull(md, Vector3(0, 1.0, 0), Vector3(1.1, 2.0, 0.4))

static func _gsign(md: NewModels6.Model) -> void:
	# an old painted board, the lettering faded and chipped, on two rusty brackets
	NewModels6.box(md, "paintwood", Vector3(0, 0.0, 0), Vector3(2.2, 0.62, 0.05), Color(0.14, 0.27, 0.2))
	NewModels6.box(md, "paintwood", Vector3(0, 0.0, 0.03), Vector3(2.1, 0.52, 0.01), Color(0.12, 0.24, 0.17))
	NewModels6.text(md, "paintwood", "VOSS & SON", Vector3(0, 0.02, 0.04), Vector3(0, 0, 1), 0.3, Color(0.82, 0.76, 0.58), Vector3.UP, 0.0)
	NewModels6.text(md, "paintwood", "MOTOR WORKS", Vector3(0, -0.2, 0.04), Vector3(0, 0, 1), 0.12, Color(0.78, 0.72, 0.55), Vector3.UP, 0.0)
	NewModels6.box(md, "rust", Vector3(0.7, -0.2, 0.01), Vector3(0.28, 0.12, 0.012), Color(0.36, 0.2, 0.12), 0.0)     # a rust bloom
	for sx: float in [-0.9, 0.9]:
		NewModels6.box(md, "rust", Vector3(sx, 0.38, -0.05), Vector3(0.05, 0.22, 0.1), Color(0.3, 0.14, 0.08))

static func _bicycle(md: NewModels6.Model) -> void:
	# an old roadster leaning (the lean is the model's tilt: it leans on +x at 8 degrees), two 0.66 m wheels, a basket
	var frame := Color(0.1, 0.11, 0.1)
	var tilt := Basis(Vector3.BACK, 0.14)
	for wz: float in [-0.55, 0.55]:
		var c := tilt * Vector3(0, 0.34, wz)
		var n := 16
		for k in n:
			var a0 := TAU * k / n; var a1 := TAU * (k + 1) / n
			NewModels6.limb(md, "rubber", c + tilt * Vector3(0, cos(a0) * 0.34, sin(a0) * 0.34), c + tilt * Vector3(0, cos(a1) * 0.34, sin(a1) * 0.34), 0.017, 0.017, Color(0.05, 0.05, 0.05), 4)
		for k in 6:
			var a := TAU * k / 6.0
			NewModels6.limb(md, "chrome", c, c + tilt * Vector3(0, cos(a) * 0.33, sin(a) * 0.33), 0.002, 0.002, Color(0.7, 0.7, 0.72), 3)
	var P := func(y: float, z: float) -> Vector3: return tilt * Vector3(0, y, z)
	NewModels6.limb(md, "paint", P.call(0.34, -0.55), P.call(0.62, -0.2), 0.014, 0.014, frame, 6)
	NewModels6.limb(md, "paint", P.call(0.62, -0.2), P.call(0.64, 0.4), 0.014, 0.014, frame, 6)
	NewModels6.limb(md, "paint", P.call(0.64, 0.4), P.call(0.34, 0.55), 0.014, 0.014, frame, 6)
	NewModels6.limb(md, "paint", P.call(0.34, -0.55), P.call(0.36, 0.0), 0.012, 0.012, frame, 6)
	NewModels6.limb(md, "paint", P.call(0.36, 0.0), P.call(0.64, 0.4), 0.012, 0.012, frame, 6)
	NewModels6.limb(md, "chrome", P.call(0.64, 0.4), P.call(0.86, 0.42), 0.012, 0.012, Color(0.7, 0.7, 0.72), 6)
	NewModels6.limb(md, "chrome", P.call(0.86, 0.34), P.call(0.86, 0.5), 0.011, 0.011, Color(0.7, 0.7, 0.72), 6)
	NewModels6.box(md, "leather", P.call(0.7, -0.22), Vector3(0.12, 0.04, 0.26), Color(0.12, 0.08, 0.05), 0.0, Color(-1, 0, 0), tilt)
	NewModels6.box(md, "wood", P.call(0.86, 0.7), Vector3(0.3, 0.18, 0.24), Color(0.45, 0.35, 0.22), 0.0, Color(-1, 0, 0), tilt)
	NewModels6.hull(md, Vector3(0.05, 0.45, 0), Vector3(0.4, 0.9, 1.4))

static func _rolling_toolbox(md: NewModels6.Model) -> void:
	var red := Color(0.5, 0.1, 0.08)
	NewModels6.box(md, "paint", Vector3(0, 0.45, 0), Vector3(0.8, 0.8, 0.45), red)
	NewModels6.box(md, "paint", Vector3(0, 0.88, 0), Vector3(0.84, 0.06, 0.48), Color(0.35, 0.35, 0.37))
	for k in 5:
		NewModels6.box(md, "paint", Vector3(0, 0.15 + k * 0.14, 0.23), Vector3(0.7, 0.12, 0.01), red * 1.1)
		NewModels6.box(md, "chrome", Vector3(0, 0.15 + k * 0.14, 0.24), Vector3(0.18, 0.015, 0.015), Color(0.7, 0.7, 0.72))
	for sx: float in [-0.34, 0.34]:
		NewModels6.cyl(md, "rubber", Vector3(sx - 0.02, 0.05, -0.15), Vector3(sx + 0.02, 0.05, -0.15), 0.05, 0.05, 10, Color(0.05, 0.05, 0.05), 3, 0.0)
		NewModels6.cyl(md, "rubber", Vector3(sx - 0.02, 0.05, 0.15), Vector3(sx + 0.02, 0.05, 0.15), 0.05, 0.05, 10, Color(0.05, 0.05, 0.05), 3, 0.0)
	NewModels6.hull(md, Vector3(0, 0.45, 0), Vector3(0.85, 0.92, 0.5))

static func _radio(md: NewModels6.Model) -> void:
	# an old workshop radio on a shelf: a cream and brown cabinet with a dial and a speaker cloth
	NewModels6.rbox(md, "paint", Vector3(0, 0.1, 0), Vector3(0.36, 0.2, 0.15), Color(0.5, 0.36, 0.22), Basis.IDENTITY, 6.0, 10, 0.05)
	NewModels6.box(md, "paint", Vector3(-0.07, 0.1, 0.076), Vector3(0.17, 0.14, 0.004), Color(0.4, 0.3, 0.18))
	NewModels6.box(md, "enamel", Vector3(0.1, 0.12, 0.076), Vector3(0.11, 0.07, 0.004), Color(0.82, 0.78, 0.6))
	NewModels6.limb(md, "paint", Vector3(0.07, 0.12, 0.08), Vector3(0.13, 0.12, 0.08), 0.002, 0.002, Color(0.6, 0.1, 0.08), 3)
	for sx: float in [0.06, 0.14]:
		NewModels6.cyl(md, "paint", Vector3(sx, 0.05, 0.075), Vector3(sx, 0.05, 0.095), 0.017, 0.015, 8, Color(0.1, 0.08, 0.06), 3, 0.0)
	NewModels6.limb(md, "chrome", Vector3(-0.15, 0.2, -0.05), Vector3(-0.28, 0.45, -0.1), 0.003, 0.002, Color(0.7, 0.7, 0.72), 3)

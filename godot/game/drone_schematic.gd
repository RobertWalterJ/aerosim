class_name DroneSchematic
extends Control
## A technical drawing of a drone for the drone chooser, drawn as line art from the same parts the 3D model is built from.
## Every drawing on the Drone page uses one scale (PPM pixels per metre), so the drones can be compared by eye:
## a plan (seen from above, front at the top) and a side view, with the wheelbase and the prop size dimensioned,
## a 5 cm grid, a 20 cm scale bar and a phone drawn at the same scale.
## With lineup = true it draws all five side by side at true size instead, with the phone for scale.

const PPM := 420.0                          # pixels per metre on screen: the one scale of the Drone page
const PHONE := Vector2(0.0715, 0.147)       # a typical phone, metres (width, length)
const GRID := 0.05                          # grid squares, metres
const SHEET := Color(0.035, 0.062, 0.098)
const FILL := Color(0.05, 0.085, 0.13)

static var _cache := {}

var id := "mini"
var lineup := false
var selected := ""

var _pad := 14.0
var _plan_box := 0.0
var _side_h := 0.0

## The drawing data for one drone, built once from the 3D model in drawing mode and kept.
static func data(drone_id: String) -> Dictionary:
	if _cache.has(drone_id): return _cache[drone_id]
	var af := Airframes.make(drone_id)
	var md := DroneView.model(af)
	var plan: Array = (md["plan"] as Array).duplicate()
	plan.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["key"]) < float(b["key"]))
	var side: Array = (md["side"] as Array).duplicate()
	side.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["key"]) < float(b["key"]))
	var lo := Vector2(INF, INF); var hi := Vector2(-INF, -INF)
	for s in plan:
		if s.has("pts"):
			for q in s["pts"]: lo = lo.min(q); hi = hi.max(q)
	for dc in md["discs"]:
		var c: Vector3 = dc[0]; var r: float = dc[1]
		lo = lo.min(Vector2(c.x - r, c.z - r)); hi = hi.max(Vector2(c.x + r, c.z + r))
	for s in plan:
		if s.has("ring"):
			var rc: Vector2 = s["ring"][0]; var rr: float = s["ring"][2]
			lo = lo.min(rc - Vector2(rr, rr)); hi = hi.max(rc + Vector2(rr, rr))
	var ylo := INF; var yhi := -INF
	for s in side:
		for q in s["pts"]: ylo = minf(ylo, q.y); yhi = maxf(yhi, q.y)
	var out := {"af": af, "plan": plan, "side": side, "discs": md["discs"], "lo": lo, "hi": hi, "ylo": ylo, "yhi": yhi, "reach": DroneView.reach(af)}
	_cache[drone_id] = out
	return out

## The facts shown beside a drawing, all worked out from the airframe numbers.
static func facts(af: Dictionary) -> Array:
	var span := 2.0 * (float(af["armD"]) + DroneView.reach(af))     # tip to tip across the props (or ducts)
	var cam := "Gimbal, tilts" if af["hasGimbal"] else "Fixed, %d° up" % int(round(rad_to_deg(float(af["camTilt"]))))
	var top_speed: float = float(af["limits"]["S"]["vH"]) * 3.6
	return [
		["Weight", ("%d g" % int(round(float(af["mass"]) * 1000.0))) if float(af["mass"]) < 1.0 else ("%s kg" % str(snappedf(float(af["mass"]), 0.1)))],
		["Wheelbase", "%d mm" % int(round(2.0 * sqrt(2.0) * float(af["armD"]) * 1000.0))],
		["Tip to tip", "%d mm" % int(round(span * 1000.0))],
		["Props", "%.1f in, %d blades" % [float(af["R"]) * 2.0 / 0.0254, int(af["nBlades"])]],
		["Camera", cam],
		["Battery", "%dS, %d mAh" % [int(af["cells"]), int(round(float(af["capacityAh"]) * 1000.0))]],
		["Top speed", "%d km/h" % int(round(top_speed))],
		["Thrust", "%s × its weight" % str(snappedf(float(af["twr"]), 0.1)).trim_suffix(".0")],
	]

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	_plan_box = 0.54 * PPM
	_side_h = 0.135 * PPM
	if lineup:
		var tallest := 0.0
		for i in Airframes.IDS:
			var af := Airframes.make(i)
			tallest = maxf(tallest, 2.0 * (float(af["armD"]) + DroneView.reach(af)))
		custom_minimum_size = Vector2(320, tallest * PPM + 78)
	else:
		custom_minimum_size = Vector2(_pad * 2.0 + _plan_box * 2.0 + 40.0, _pad + 18.0 + 26.0 + _plan_box + 6.0)

func _font() -> Font:
	return get_theme_default_font()

func _draw() -> void:
	if lineup: _draw_lineup()
	else: _draw_sheet()

# ------------------------------------------------------------------ one drone: plan, side view, scale
func _draw_sheet() -> void:
	var d := data(id)
	var af: Dictionary = d["af"]
	var ac := MenuStyle.ACCENT
	var sb := StyleBoxFlat.new(); sb.bg_color = SHEET; sb.set_corner_radius_all(10); sb.set_border_width_all(1)
	sb.border_color = Color(ac.r, ac.g, ac.b, 0.22); sb.anti_aliasing = true
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var f := _font()
	var plan_rect := Rect2(_pad, _pad + 18.0 + 26.0, _plan_box, _plan_box)
	var pc := plan_rect.get_center()
	var side_rect := Rect2(plan_rect.end.x + 24.0, _pad + 18.0, _plan_box + 16.0, _side_h)
	# ---- the grid and the centre lines, at the same scale as the drone
	_grid(Rect2(plan_rect.position, Vector2(plan_rect.size.x, size.y - plan_rect.position.y - 10.0)), pc)
	_label(Vector2(plan_rect.position.x, _pad + 12.0), "FROM ABOVE", 13, Color(ac.r, ac.g, ac.b, 0.75))
	var to_plan := func(q: Vector2) -> Vector2: return pc + q * PPM
	# ---- parts, lowest first, each filled so it hides what is under it
	_parts(d["plan"], to_plan, ac, 1.3)
	for dc in d["discs"]:
		var c: Vector3 = dc[0]
		_dashed_circle(pc + Vector2(c.x, c.z) * PPM, float(dc[1]) * PPM, Color(ac.r, ac.g, ac.b, 0.5))
	# the centre of mass mark
	_com(pc, 5.0)
	# front arrow, at the top left of the drawing (the prop size sits top right)
	var fa := Vector2(plan_rect.position.x + 6.0, plan_rect.position.y - 14.0)
	draw_colored_polygon(PackedVector2Array([fa + Vector2(0, -6), fa + Vector2(5, 3), fa + Vector2(-5, 3)]), Color(1, 1, 1, 0.7))
	_label(fa + Vector2(9, 5), "Front", 13, Color(1, 1, 1, 0.7))
	# ---- dimensions: wheelbase on the diagonal (its figure just past the rear right prop), prop diameter over the front right prop
	var arm: float = af["armD"]
	var r: float = af["R"]
	var m_fl := pc + Vector2(-arm, -arm) * PPM
	var m_rr := pc + Vector2(arm, arm) * PPM
	var dim_col := Color(1, 1, 1, 0.85)
	_dim_line(m_fl, m_rr, dim_col)
	var diag := (m_rr - m_fl).normalized()
	var reach := float(d["reach"]) * PPM + 6.0
	_dashed(m_rr + diag * 9.0, m_rr + diag * reach, Color(1, 1, 1, 0.4), 1.0, 3.0, 2.0)
	var wb := "%d mm" % int(round(2.0 * sqrt(2.0) * arm * 1000.0))
	var wbs := _font().get_string_size(wb, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	_pill(m_rr + diag * reach + Vector2(wbs.x * 0.5 + 4.0, 8.0), wb, dim_col)
	var fr := pc + Vector2(arm, -arm) * PPM
	var yy := fr.y - r * PPM - 8.0
	draw_line(fr + Vector2(-r * PPM, -r * PPM * 0.2), Vector2(fr.x - r * PPM, yy - 4.0), Color(1, 1, 1, 0.35), 1.0)
	draw_line(fr + Vector2(r * PPM, -r * PPM * 0.2), Vector2(fr.x + r * PPM, yy - 4.0), Color(1, 1, 1, 0.35), 1.0)
	_dim_line(Vector2(fr.x - r * PPM, yy), Vector2(fr.x + r * PPM, yy), dim_col)
	_pill(Vector2(fr.x, yy - 1.0), "%.1f in" % (r * 2.0 / 0.0254), dim_col)
	# ---- side view, seen from the left: nose to the left, standing on the ground
	_label(Vector2(side_rect.position.x, _pad + 12.0), "FROM THE SIDE", 13, Color(ac.r, ac.g, ac.b, 0.75))
	var ground_y := side_rect.position.y + side_rect.size.y - 12.0
	var sc := Vector2(side_rect.position.x + _plan_box * 0.5, ground_y - 0.03 * PPM)    # body origin (ground contact is 3 cm below it)
	var to_side := func(q: Vector2) -> Vector2: return sc + Vector2(q.x, -q.y) * PPM
	_parts(d["side"], to_side, ac, 1.2)
	for dc in d["discs"]:
		var c2: Vector3 = dc[0]
		if c2.x > 0.0: continue
		var a := to_side.call(Vector2(c2.z - float(dc[1]), c2.y)) as Vector2
		var b := to_side.call(Vector2(c2.z + float(dc[1]), c2.y)) as Vector2
		_dashed(a, b, Color(ac.r, ac.g, ac.b, 0.7), 2.0, 5.0, 3.0)
	draw_line(Vector2(side_rect.position.x, ground_y), Vector2(side_rect.end.x - 6.0, ground_y), Color(1, 1, 1, 0.45), 1.0)
	var hx := side_rect.position.x
	while hx < side_rect.end.x - 10.0:
		draw_line(Vector2(hx + 6.0, ground_y), Vector2(hx, ground_y + 6.0), Color(1, 1, 1, 0.18), 1.0)
		hx += 7.0
	# height on the ground, at the tail end
	var top_y := sc.y - float(d["yhi"]) * PPM
	var hxp := side_rect.end.x - 8.0
	_dim_line(Vector2(hxp, ground_y), Vector2(hxp, top_y), dim_col)
	var htxt := "%d mm" % int(round((float(d["yhi"]) + 0.03) * 1000.0))
	var hs := f.get_string_size(htxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	_pill(Vector2(hxp - hs.x * 0.5 - 8.0, top_y - 12.0), htxt, dim_col)
	# ---- scale bar and a phone, both at the drawing's scale
	var bar_y := side_rect.end.y + 34.0
	_scale_bar(Vector2(side_rect.position.x, bar_y), PPM)
	var ph := Rect2(Vector2(side_rect.end.x - PHONE.x * PPM - 30.0, side_rect.end.y + 16.0), PHONE * PPM)
	_phone(ph)
	_label(Vector2(ph.position.x - 52.0, ph.position.y + ph.size.y * 0.5 + 5.0), "Phone", 13, Color(1, 1, 1, 0.55))

# ------------------------------------------------------------------ all five, side by side at true size
func _draw_lineup() -> void:
	var ac := MenuStyle.ACCENT
	var gaps := 26.0
	var total := PHONE.x
	for i in Airframes.IDS:
		var d := data(i)
		total += ((d["hi"] as Vector2) - (d["lo"] as Vector2)).x
	var ppm := minf(PPM, (size.x - gaps * Airframes.IDS.size() - 10.0) / total)
	var x := (size.x - (total * ppm + gaps * Airframes.IDS.size())) * 0.5
	var base := size.y - 44.0
	for i in Airframes.IDS:
		var d := data(i)
		var lo: Vector2 = d["lo"]; var hi: Vector2 = d["hi"]
		var w := (hi.x - lo.x) * ppm
		var origin := Vector2(x - lo.x * ppm, base - hi.y * ppm)
		var on := i == selected
		var col := ac if on else Color(MenuStyle.MUTED.r, MenuStyle.MUTED.g, MenuStyle.MUTED.b, 0.85)
		var to := func(q: Vector2) -> Vector2: return origin + q * ppm
		_parts(d["plan"], to, col, 1.4 if on else 1.0)
		for dc in d["discs"]:
			var c: Vector3 = dc[0]
			_dashed_circle(origin + Vector2(c.x, c.z) * ppm, float(dc[1]) * ppm, Color(col.r, col.g, col.b, 0.45))
		var name: String = (d["af"] as Dictionary)["name"]
		var fs := 14
		var tw := _font().get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_label(Vector2(x + w * 0.5 - tw * 0.5, base + 22.0), name, fs, MenuStyle.TEXT if on else MenuStyle.MUTED)
		x += w + gaps
	var ph := Rect2(Vector2(x, base - PHONE.y * ppm), PHONE * ppm)
	_phone(ph)
	var pw := _font().get_string_size("Phone", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	_label(Vector2(ph.get_center().x - pw * 0.5, base + 22.0), "Phone", 14, MenuStyle.MUTED)
	draw_line(Vector2(8, base + 4.0), Vector2(size.x - 8.0, base + 4.0), Color(1, 1, 1, 0.12), 1.0)
	_scale_bar(Vector2(10.0, 16.0), ppm)

# ------------------------------------------------------------------ drawing helpers
## Fill and outline each part in turn, lowest (or furthest) first, so nearer parts hide the ones behind.
func _parts(shapes: Array, to: Callable, col: Color, width: float) -> void:
	for s in shapes:
		if s.has("ring"):
			var c: Vector2 = to.call(s["ring"][0])
			var r0: float = float(s["ring"][1]) * _ppm_of(to)
			var r1: float = float(s["ring"][2]) * _ppm_of(to)
			if r0 < 0.5:
				draw_circle(c, r1, FILL)
			else:
				draw_arc(c, (r0 + r1) * 0.5, 0.0, TAU, 48, FILL, r1 - r0)
				draw_arc(c, r0, 0.0, TAU, 48, col, width, true)
			draw_arc(c, r1, 0.0, TAU, 48, col, width, true)
			continue
		var pts := PackedVector2Array()
		for q in s["pts"]: pts.append(to.call(q))
		if pts.size() < 3: continue
		var thin: bool = s.get("thin", false)
		if Geometry2D.triangulate_polygon(pts).size() > 0:
			draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.16) if thin else FILL)
		var closed := pts.duplicate(); closed.append(pts[0])
		draw_polyline(closed, Color(col.r, col.g, col.b, 0.8) if thin else col, width * (0.8 if thin else 1.0), true)

## The scale a mapping callable draws at (pixels per metre), measured.
func _ppm_of(to: Callable) -> float:
	var a: Vector2 = to.call(Vector2.ZERO)
	var b: Vector2 = to.call(Vector2(1.0, 0.0))
	return a.distance_to(b)

func _grid(r: Rect2, c: Vector2) -> void:
	var ac := MenuStyle.ACCENT
	var g := GRID * PPM
	var k := floori((r.position.x - c.x) / g)
	while c.x + k * g <= r.end.x:
		var xx := c.x + k * g
		if xx >= r.position.x: draw_line(Vector2(xx, r.position.y), Vector2(xx, r.end.y), Color(ac.r, ac.g, ac.b, 0.07), 1.0)
		k += 1
	k = floori((r.position.y - c.y) / g)
	while c.y + k * g <= r.end.y:
		var yy := c.y + k * g
		if yy >= r.position.y: draw_line(Vector2(r.position.x, yy), Vector2(r.end.x, yy), Color(ac.r, ac.g, ac.b, 0.07), 1.0)
		k += 1
	# centre lines (long dash, short dash) through the centre of mass
	_dashdot(Vector2(r.position.x, c.y), Vector2(r.end.x, c.y), Color(ac.r, ac.g, ac.b, 0.28))
	_dashdot(Vector2(c.x, r.position.y), Vector2(c.x, r.end.y), Color(ac.r, ac.g, ac.b, 0.28))

func _dashed(a: Vector2, b: Vector2, col: Color, w: float, dash: float, gap: float) -> void:
	var L := a.distance_to(b)
	if L < 0.5: return
	var dir := (b - a) / L
	var t := 0.0
	while t < L:
		draw_line(a + dir * t, a + dir * minf(t + dash, L), col, w)
		t += dash + gap

func _dashdot(a: Vector2, b: Vector2, col: Color) -> void:
	var L := a.distance_to(b)
	var dir := (b - a) / maxf(L, 0.001)
	var t := 0.0
	while t < L:
		draw_line(a + dir * t, a + dir * minf(t + 12.0, L), col, 1.0)
		if t + 15.0 < L: draw_line(a + dir * (t + 15.0), a + dir * minf(t + 17.0, L), col, 1.0)
		t += 20.0

func _dashed_circle(c: Vector2, r: float, col: Color) -> void:
	var n := maxi(12, int(r * TAU / 7.0))
	for k in n:
		if k % 2 == 1: continue
		draw_arc(c, r, TAU * k / n, TAU * (k + 1) / n, 4, col, 1.0, true)

func _com(c: Vector2, r: float) -> void:
	draw_circle(c, r + 1.5, SHEET)
	draw_arc(c, r, 0.0, TAU, 20, Color(1, 1, 1, 0.9), 1.2, true)
	for q in [0, 2]:
		var pts := PackedVector2Array([c])
		for k in 7: pts.append(c + Vector2.from_angle(PI * 0.5 * q + PI * 0.5 * k / 6.0) * r)
		draw_colored_polygon(pts, Color(1, 1, 1, 0.9))

## A dimension line with arrowheads at both ends.
func _dim_line(a: Vector2, b: Vector2, col: Color) -> void:
	draw_line(a, b, col, 1.0, true)
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x)
	for e in [[a, dir], [b, -dir]]:
		var p: Vector2 = e[0]; var dd: Vector2 = e[1]
		draw_colored_polygon(PackedVector2Array([p, p + dd * 8.0 + n * 3.0, p + dd * 8.0 - n * 3.0]), col)

## A short label on a small dark tab, so it reads over the drawing.
func _pill(c: Vector2, text: String, col: Color) -> void:
	var f := _font()
	var fs := 14
	var s := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var r := Rect2(c - Vector2(s.x * 0.5 + 6.0, s.y * 0.5 + 1.0), Vector2(s.x + 12.0, s.y + 2.0))
	var sb := StyleBoxFlat.new(); sb.bg_color = SHEET; sb.set_corner_radius_all(5); sb.set_border_width_all(1); sb.border_color = Color(col.r, col.g, col.b, 0.35)
	draw_style_box(sb, r)
	draw_string(f, Vector2(r.position.x + 6.0, r.position.y + 1.0 + f.get_ascent(fs)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _label(p: Vector2, text: String, fs: int, col: Color) -> void:
	draw_string(_font(), p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

## A 20 cm scale bar in alternating 5 cm blocks.
func _scale_bar(p: Vector2, ppm: float) -> void:
	var seg := 0.05 * ppm
	for k in 4:
		var r := Rect2(p + Vector2(k * seg, 0), Vector2(seg, 5.0))
		if k % 2 == 0: draw_rect(r, Color(1, 1, 1, 0.8))
		draw_rect(r, Color(1, 1, 1, 0.8), false, 1.0)
	_label(p + Vector2(0, -5.0), "0", 12, Color(1, 1, 1, 0.6))
	_label(p + Vector2(2.0 * seg - 9.0, -5.0), "10", 12, Color(1, 1, 1, 0.6))
	_label(p + Vector2(4.0 * seg - 9.0, -5.0), "20 cm", 12, Color(1, 1, 1, 0.75))

## A phone, as a simple outline: rounded corners, a camera dot, a home bar.
func _phone(r: Rect2) -> void:
	var col := Color(1, 1, 1, 0.5)
	var sb := StyleBoxFlat.new(); sb.draw_center = false; sb.set_corner_radius_all(int(r.size.x * 0.16)); sb.set_border_width_all(1); sb.border_color = col; sb.anti_aliasing = true
	draw_style_box(sb, r)
	draw_circle(Vector2(r.get_center().x, r.position.y + r.size.x * 0.14), maxf(1.2, r.size.x * 0.04), col)
	draw_line(Vector2(r.get_center().x - r.size.x * 0.18, r.end.y - r.size.x * 0.12), Vector2(r.get_center().x + r.size.x * 0.18, r.end.y - r.size.x * 0.12), col, 1.0)

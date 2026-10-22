class_name HudIcons
extends RefCounted
## One drawing kit for every icon on the flight screen, so they all share one look: thin white line art with round
## ends, drawn on a 24 unit grid and scaled to whatever size is asked for. Icons are drawn as vectors each frame, so
## they stay sharp at any screen size (desktop or phone) and need no image files. Colour is always passed in, so the
## caller decides the normal, lit (active), pressed and greyed out (disabled) looks.
##
## icon() kinds: back, more (also gear), takeoff, land, home (return to home), camera (photo), video, eye (first
## person view), chase (view from behind), drone, rc, gps, hd, or a one letter flight mode such as N, S, M.

const GRID := 24.0
const STROKE := 1.9                       # line width in grid units
const WHITE := Color(1, 1, 1)
const ACCENT := Color(0.30, 0.78, 0.98)   # lit: a mode or action that is on (the same blue as the settings page)
const DISABLED := Color(0.50, 0.52, 0.56) # greyed out: drawn solid, never see-through, so strokes do not show seams
const RED := Color(0.96, 0.24, 0.22)
const AMBER := Color(1.0, 0.75, 0.25)
const INK := Color(0.07, 0.08, 0.10)      # dark text on a light chip
const MODE_TINT := {"N": Color(0.95, 0.96, 0.98), "S": Color(1.0, 0.74, 0.26), "M": Color(1.0, 0.46, 0.40), "A": Color(0.95, 0.56, 1.0)}

static var _bold: Font
static var _semi: Font

## A clean bold sans serif for letters inside icons (Segoe UI on Windows, Roboto on Android).
static func bold_font() -> Font:
	if _bold == null: _bold = _sys_font(700)
	return _bold

## The caption font under the round buttons.
static func label_font() -> Font:
	if _semi == null: _semi = _sys_font(600)
	return _semi

static func _sys_font(weight: int) -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI", "Roboto", "Helvetica Neue", "Noto Sans", "Arial", "sans-serif"])
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	return f

static func mode_tint(m: String) -> Color:
	return MODE_TINT.get(m, WHITE)

# ------------------------------------------------------------------ the pen: grid units in, pixels out
class Pen:
	var ci: CanvasItem
	var o: Vector2        # where grid point (0, 0) lands
	var k: float          # pixels per grid unit
	var w: float          # stroke width in pixels
	var col: Color

	func _init(c: CanvasItem, center: Vector2, box: float, colour: Color, stroke_units: float, min_px: float) -> void:
		ci = c; k = box / GRID; o = center - Vector2(12, 12) * k; col = colour
		w = maxf(stroke_units * k, min_px)

	func p(x: float, y: float) -> Vector2:
		return o + Vector2(x, y) * k

	## A stroke through grid points, with round ends and round corners.
	func line(pts: Array, wm := 1.0, closed := false) -> void:
		var q := PackedVector2Array()
		for v in pts: q.append(o + (v as Vector2) * k)
		if closed: q.append(q[0])
		var wd := w * wm
		ci.draw_polyline(q, col, wd, true)
		for v in q: ci.draw_circle(v, wd * 0.5, col, true, -1.0, true)

	## A smooth curve already in pixels: round ends only.
	func curve(q: PackedVector2Array, wm := 1.0, closed := false) -> void:
		if closed: q.append(q[0])
		var wd := w * wm
		ci.draw_polyline(q, col, wd, true)
		if not closed:
			ci.draw_circle(q[0], wd * 0.5, col, true, -1.0, true)
			ci.draw_circle(q[q.size() - 1], wd * 0.5, col, true, -1.0, true)

	func arc(cx: float, cy: float, r: float, a0: float, a1: float, wm := 1.0) -> void:
		var n := maxi(8, int(absf(a1 - a0) / TAU * 48.0))
		var q := PackedVector2Array()
		for i in n + 1:
			var a := lerpf(a0, a1, float(i) / n)
			q.append(p(cx + cos(a) * r, cy + sin(a) * r))
		curve(q, wm)

	func ellipse(cx: float, cy: float, rx: float, ry: float, wm := 1.0) -> void:
		var q := PackedVector2Array()
		for i in 48:
			var a := TAU * i / 48.0
			q.append(p(cx + cos(a) * rx, cy + sin(a) * ry))
		curve(q, wm, true)

	func rrect(x: float, y: float, wd: float, ht: float, r: float, wm := 1.0) -> void:
		var q := PackedVector2Array()
		var corners := [[Vector2(x + wd - r, y + r), -90.0], [Vector2(x + wd - r, y + ht - r), 0.0], [Vector2(x + r, y + ht - r), 90.0], [Vector2(x + r, y + r), 180.0]]
		for cn in corners:
			for i in 7:
				var a := deg_to_rad(cn[1] + 90.0 * i / 6.0)
				var cc: Vector2 = cn[0]
				q.append(p(cc.x + cos(a) * r, cc.y + sin(a) * r))
		curve(q, wm, true)

	func dot(x: float, y: float, r: float, c := Color(0, 0, 0, 0)) -> void:
		ci.draw_circle(p(x, y), r * k, col if c.a == 0.0 else c, true, -1.0, true)

	## A filled rounded box with smooth edges (a style box draws it with anti-aliasing).
	func fill_rrect(x: float, y: float, wd: float, ht: float, r: float, c: Color) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(int(round(r * k)))
		sb.anti_aliasing = true
		sb.anti_aliasing_size = 0.8
		sb.corner_detail = 10
		sb.draw(ci.get_canvas_item(), Rect2(p(x, y), Vector2(wd, ht) * k))

	## A filled shape, its edge smoothed with a thin stroke of the same colour.
	func fill_poly(pts: Array, c: Color) -> void:
		var q := PackedVector2Array()
		for v in pts: q.append(o + (v as Vector2) * k)
		ci.draw_colored_polygon(q, c)
		q.append(q[0])
		ci.draw_polyline(q, c, 1.0, true)

	## Text centred on a grid point; size in grid units.
	func text(s: String, x: float, y: float, size_u: float, c: Color) -> void:
		var f := HudIcons.bold_font()
		var fs := maxi(6, int(round(size_u * k)))
		var sz := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var cap := fs * 0.70
		ci.draw_string(f, p(x, y) + Vector2(-sz.x * 0.5, cap * 0.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)

# ------------------------------------------------------------------ icons
## The same icon with a soft dark shadow under it, for glyphs that sit straight on the video with no disc behind.
static func icon_shadowed(ci: CanvasItem, kind: String, center: Vector2, box: float, col: Color, stroke := STROKE, min_px := 1.3) -> void:
	var off := maxf(1.0, box * 0.05)
	icon(ci, kind, center + Vector2(off * 0.6, off), box, Color(0, 0, 0, 0.42), stroke, min_px)
	icon(ci, kind, center, box, col, stroke, min_px)

## Draw one icon centred on `center`, `box` pixels across (the 24 unit grid is fitted to it).
static func icon(ci: CanvasItem, kind: String, center: Vector2, box: float, col: Color, stroke := STROKE, min_px := 1.3) -> void:
	var pen := Pen.new(ci, center, box, col, stroke, min_px)
	match kind:
		"back":
			pen.line([Vector2(15, 4.5), Vector2(7.8, 12), Vector2(15, 19.5)], 1.25)
		"gear", "more":
			for x in [4.6, 12.0, 19.4]: pen.dot(x, 12, 2.05)
		"takeoff":
			_pad(pen)
			pen.line([Vector2(12, 14.6), Vector2(12, 3.4)])
			pen.line([Vector2(7.6, 7.8), Vector2(12, 3.4), Vector2(16.4, 7.8)])
		"land":
			_pad(pen)
			pen.line([Vector2(12, 3.4), Vector2(12, 14.2)])
			pen.line([Vector2(7.6, 9.8), Vector2(12, 14.2), Vector2(16.4, 9.8)])
		"home", "rth":
			# the home pad with its H, and a curved arrow coming over the top and down onto it
			pen.ellipse(12, 17.4, 9.0, 4.4)
			_h(pen, 12, 17.4, 2.5, 1.9, 0.72)
			# starts at the right of the pad, sweeps up and over to the left and ends in an arrow pointing down at the pad
			var a0 := deg_to_rad(8.0)
			var a1 := deg_to_rad(-150.0)
			var cx := 12.0; var cy := 10.0; var r := 7.2
			pen.arc(cx, cy, r, a0, a1)
			var tip := Vector2(cx + cos(a1) * r, cy + sin(a1) * r)
			var tan := Vector2(sin(a1), -cos(a1))
			var nrm := Vector2(-tan.y, tan.x)
			pen.line([tip - tan * 2.8 + nrm * 2.6, tip, tip - tan * 2.8 - nrm * 2.6])
		"camera", "photo":
			pen.rrect(2.8, 7.4, 18.4, 12.6, 3.0)
			pen.line([Vector2(8.2, 7.4), Vector2(9.7, 4.6), Vector2(14.3, 4.6), Vector2(15.8, 7.4)])
			pen.ellipse(12, 13.7, 3.9, 3.9)
		"video":
			pen.rrect(2.4, 6.6, 13.2, 10.8, 2.6)
			pen.line([Vector2(15.6, 10.2), Vector2(21.6, 7.0), Vector2(21.6, 17.0), Vector2(15.6, 13.8)])
		"eye", "fpv":
			# what the drone's own camera sees: viewfinder corners round a centre point
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var kx: float = 12.0 + sx * 8.6
					var ky: float = 12.0 + sy * 6.8
					pen.line([Vector2(kx, ky - sy * 3.6), Vector2(kx, ky), Vector2(kx - sx * 3.8, ky)])
			pen.ellipse(12, 12, 2.7, 2.7)
			pen.dot(12, 12, 0.9)
		"chase", "drone":
			_quad(pen)
		"rc":
			pen.rrect(3.4, 9.0, 17.2, 11.0, 2.8)
			pen.line([Vector2(6.6, 9.0), Vector2(6.6, 3.6)])
			pen.line([Vector2(17.4, 9.0), Vector2(17.4, 3.6)])
			pen.ellipse(8.4, 14.5, 1.7, 1.7)
			pen.ellipse(15.6, 14.5, 1.7, 1.7)
		"gps":
			_satellite(pen)
		"hd":
			pen.text("HD", 12, 12, 13.0, col)
		_:
			mode_chip(ci, kind, center, box, col)

## The landing pad seen at a slant, shared by takeoff, land and return to home so the three read as a family.
static func _pad(pen: Pen) -> void:
	pen.ellipse(12, 18.9, 8.6, 2.9)

## A small H drawn as three strokes.
static func _h(pen: Pen, cx: float, cy: float, hw: float, hh: float, wm: float) -> void:
	pen.line([Vector2(cx - hw, cy - hh), Vector2(cx - hw, cy + hh)], wm)
	pen.line([Vector2(cx + hw, cy - hh), Vector2(cx + hw, cy + hh)], wm)
	pen.line([Vector2(cx - hw, cy), Vector2(cx + hw, cy)], wm)

## A quadcopter seen from above: four rotor rings on an X, a small body in the middle.
static func _quad(pen: Pen) -> void:
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var m: Vector2 = Vector2(12 + sx * 6.3, 12 + sy * 6.3)
			pen.ellipse(m.x, m.y, 3.4, 3.4, 0.9)
			pen.line([Vector2(12 + sx * 2.3, 12 + sy * 2.3), m - Vector2(sx, sy) * 2.45], 0.9)
	pen.rrect(9.2, 8.6, 5.6, 6.8, 2.2, 0.9)

## A navigation satellite: a round body with an open solar wing either side, tilted, and a signal arc under it.
static func _satellite(pen: Pen) -> void:
	var c := Vector2(10.6, 10.6)
	var ax := Vector2(1, -1).normalized()     # along the wings
	var ay := Vector2(1, 1).normalized()      # across them
	pen.dot(c.x, c.y, 2.6)
	for s in [-1.0, 1.0]:
		var a: Vector2 = c + ax * s * 4.4
		var b: Vector2 = c + ax * s * 9.2
		pen.line([a - ay * 3.2, b - ay * 3.2, b + ay * 3.2, a + ay * 3.2], 0.8, true)
		pen.line([c + ax * s * 2.4, a], 0.8)
	# the signal, sent down to the ground
	pen.arc(c.x, c.y, 6.4, deg_to_rad(20), deg_to_rad(70), 0.85)
	pen.arc(c.x, c.y, 10.2, deg_to_rad(24), deg_to_rad(66), 0.85)

## The flight mode as a chip: a rounded tag in the mode's colour with the letter cut out of it in dark ink.
static func mode_chip(ci: CanvasItem, letter: String, center: Vector2, box: float, col: Color) -> void:
	var pen := Pen.new(ci, center, box, col, STROKE, 1.3)
	pen.fill_rrect(3.2, 3.2, 17.6, 17.6, 4.4, col)
	pen.text(letter, 12, 12.2, 14.5 if letter.length() == 1 else 9.0, INK)

# ------------------------------------------------------------------ status bar pieces
## Signal strength bars, bottom-left at `origin`, `h` pixels tall. Lit bars in `col`, the rest faint.
static func bars(ci: CanvasItem, origin: Vector2, h: float, on: int, col: Color, total := 5) -> void:
	var bw := maxf(1.6, h * 0.17)
	var gap := bw * 0.75
	for i in total:
		var bh := h * (0.34 + 0.66 * float(i) / float(total - 1))
		var rc := Rect2(origin.x + i * (bw + gap), origin.y - bh, bw, bh)
		ci.draw_rect(Rect2(rc.position + Vector2(0.8, 1.0), rc.size), Color(0, 0, 0, 0.3))
		var sb := StyleBoxFlat.new()
		sb.bg_color = col if i < on else Color(1, 1, 1, 0.28)
		sb.set_corner_radius_all(int(ceil(bw * 0.5)))
		sb.anti_aliasing = true; sb.anti_aliasing_size = 0.6
		sb.draw(ci.get_canvas_item(), rc)

static func bars_width(h: float, total := 5) -> float:
	var bw := maxf(1.6, h * 0.17)
	return total * bw + (total - 1) * bw * 0.75

## The bar colour for a signal: white when good, amber when fair, red when poor.
static func signal_colour(on: int) -> Color:
	return RED if on <= 1 else (AMBER if on == 2 else WHITE)

## A battery on its side with its charge level, `h` pixels tall, left edge at `origin.x`, centred on `origin.y`.
static func battery(ci: CanvasItem, origin: Vector2, h: float, pct: float, col: Color) -> float:
	var wd := h * 2.0
	var lw := maxf(1.3, h * 0.11)
	var r := h * 0.24
	var outer := Rect2(origin.x, origin.y - h * 0.5, wd, h)
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = col
	sb.set_border_width_all(int(round(lw)))
	sb.set_corner_radius_all(int(round(r)))
	sb.anti_aliasing = true; sb.anti_aliasing_size = 0.7
	sb.draw(ci.get_canvas_item(), outer)
	var pad := lw + maxf(1.0, h * 0.09)
	var inner := Rect2(outer.position + Vector2(pad, pad), outer.size - Vector2(pad, pad) * 2.0)
	inner.size.x *= clampf(pct / 100.0, 0.04, 1.0)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(int(round(maxf(r - pad, 1.0))))
	fill.anti_aliasing = true; fill.anti_aliasing_size = 0.6
	fill.draw(ci.get_canvas_item(), inner)
	var nub := StyleBoxFlat.new()
	nub.bg_color = col
	nub.corner_radius_top_right = int(ceil(h * 0.12)); nub.corner_radius_bottom_right = nub.corner_radius_top_right
	nub.anti_aliasing = true; nub.anti_aliasing_size = 0.6
	nub.draw(ci.get_canvas_item(), Rect2(outer.end.x + h * 0.06, origin.y - h * 0.2, h * 0.16, h * 0.4))
	return wd + h * 0.22

## The home point on a map: an amber disc with a dark H.
static func home_marker(ci: CanvasItem, p: Vector2, r: float) -> void:
	ci.draw_circle(p, r + 1.3, Color(0, 0, 0, 0.45), true, -1.0, true)
	ci.draw_circle(p, r, AMBER, true, -1.0, true)
	var pen := Pen.new(ci, p, r * 2.0, INK, 2.4, 1.4)
	_h(pen, 12, 12, 3.4, 4.6, 1.0)

## The drone on a map: an arrowhead pointing along `dir` (radians, 0 = up the screen), filled, with a white edge.
static func drone_marker(ci: CanvasItem, p: Vector2, s: float, dir: float, fill: Color) -> void:
	var pts := [Vector2(0, -1.0), Vector2(0.72, 0.78), Vector2(0, 0.42), Vector2(-0.72, 0.78)]
	var q := PackedVector2Array()
	for v in pts: q.append(p + (v as Vector2).rotated(dir) * s)
	var halo := q.duplicate(); halo.append(q[0])
	ci.draw_polyline(halo, Color(0, 0, 0, 0.4), 3.6, true)
	ci.draw_colored_polygon(q, fill)
	var edge := q.duplicate(); edge.append(q[0])
	ci.draw_polyline(edge, WHITE, 1.5, true)
	for v in q: ci.draw_circle(v, 0.75, WHITE, true, -1.0, true)

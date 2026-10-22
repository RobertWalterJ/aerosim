class_name RoundButton
extends Control
## A round translucent button with a line icon, like the controls on a drone app: dark glass disc, thin white ring.
## Fires `pressed` on a tap. Listens for touch events directly, so a thumb on a flight stick and a second finger on a
## button both work (the mouse also arrives as touch because the project emulates touch from the mouse).
## kind: back, gear, home, takeoff, land, camera, eye, video, or a short text such as "N".

signal pressed

var kind := "gear"
var active := false                 # lit blue, for a mode that is on
var accent := Color(0.30, 0.65, 1.0)
var label := ""                     # small caption under the disc
var _down := false
var _finger := -1

func _init(k := "gear", diameter := 56.0) -> void:
	kind = k
	custom_minimum_size = Vector2(diameter, diameter)
	size = Vector2(diameter, diameter)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		var inside := get_global_rect().has_point(e.position)
		if e.pressed and inside and _finger == -1:
			_finger = e.index; _down = true; queue_redraw()
			get_viewport().set_input_as_handled()
		elif not e.pressed and e.index == _finger:
			var fire := inside
			_finger = -1; _down = false; queue_redraw()
			if fire: pressed.emit()
			get_viewport().set_input_as_handled()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 1.5
	var bg := Color(0.05, 0.06, 0.08, 0.42)
	if _down: bg = Color(0.3, 0.4, 0.55, 0.6)
	draw_circle(c, r, bg)
	draw_arc(c, r, 0, TAU, 48, accent if active else Color(1, 1, 1, 0.85), 2.0, true)
	var w := 2.6
	var col := accent if active else Color(1, 1, 1, 0.96)
	var s := r * 0.55
	match kind:
		"back":
			_line(PackedVector2Array([c + Vector2(s * 0.3, -s * 0.95), c + Vector2(-s * 0.5, 0), c + Vector2(s * 0.3, s * 0.95)]), col, w)
		"gear":
			# three dots, the way a drone app shows "more"
			for i in 3: draw_circle(c + Vector2((i - 1) * s * 0.62, 0), s * 0.2, col)
		"home":
			# a curved arrow coming back round to a landing pad marked H
			_pad(c, s, 0.78, col, w)
			var hy := c + Vector2(0, s * 0.72)
			_line(PackedVector2Array([hy + Vector2(-s * 0.17, -s * 0.2), hy + Vector2(-s * 0.17, s * 0.2)]), col, w * 0.8)
			_line(PackedVector2Array([hy + Vector2(s * 0.17, -s * 0.2), hy + Vector2(s * 0.17, s * 0.2)]), col, w * 0.8)
			_line(PackedVector2Array([hy + Vector2(-s * 0.17, 0), hy + Vector2(s * 0.17, 0)]), col, w * 0.8)
			_arc_line(c + Vector2(0, -s * 0.18), s * 0.78, deg_to_rad(150), deg_to_rad(405), col, w)
			var tip := c + Vector2(0, -s * 0.18) + Vector2(cos(deg_to_rad(405)), sin(deg_to_rad(405))) * s * 0.78
			_head(tip, Vector2(0.45, 0.9).normalized(), s * 0.42, col, w)
		"takeoff":
			_pad(c, s, 0.82, col, w)
			_line(PackedVector2Array([c + Vector2(0, s * 0.35), c + Vector2(0, -s * 0.72)]), col, w)
			_head(c + Vector2(0, -s * 0.8), Vector2(0, -1), s * 0.52, col, w)
		"land":
			_pad(c, s, 0.82, col, w)
			_line(PackedVector2Array([c + Vector2(0, -s * 0.85), c + Vector2(0, s * 0.3)]), col, w)
			_head(c + Vector2(0, s * 0.45), Vector2(0, 1), s * 0.52, col, w)
		"camera":
			# a camera body with a big lens and the little bump on top
			_rrect(Rect2(c + Vector2(-s * 1.05, -s * 0.6), Vector2(s * 2.1, s * 1.45)), s * 0.28, col, w)
			_line(PackedVector2Array([c + Vector2(-s * 0.45, -s * 0.6), c + Vector2(-s * 0.3, -s * 0.9), c + Vector2(s * 0.3, -s * 0.9), c + Vector2(s * 0.45, -s * 0.6)]), col, w)
			draw_arc(c + Vector2(0, s * 0.15), s * 0.5, 0, TAU, 28, col, w, true)
			draw_circle(c + Vector2(0, s * 0.15), s * 0.16, col)
		"video":
			_rrect(Rect2(c + Vector2(-s * 1.05, -s * 0.58), Vector2(s * 1.45, s * 1.16)), s * 0.25, col, w)
			_line(PackedVector2Array([c + Vector2(s * 0.5, -s * 0.12), c + Vector2(s * 1.05, -s * 0.5), c + Vector2(s * 1.05, s * 0.5), c + Vector2(s * 0.5, s * 0.12)]), col, w)
		"eye":
			# the view through the drone's own camera: a viewfinder with a centre dot
			_brackets(c, s * 0.95, s * 0.42, col, w)
			draw_circle(c, s * 0.2, col)
		"chase":
			# the view from behind: a small quad inside the viewfinder
			_brackets(c, s * 0.95, s * 0.42, col, w)
			for sx in [-1.0, 1.0]:
				_line(PackedVector2Array([c + Vector2(sx * s * 0.12, s * 0.02), c + Vector2(sx * s * 0.5, -s * 0.3)]), col, w * 0.8)
				draw_arc(c + Vector2(sx * s * 0.5, -s * 0.34), s * 0.18, 0, TAU, 14, col, w * 0.8, true)
			draw_circle(c + Vector2(0, s * 0.05), s * 0.17, col)
		_:
			var f := ThemeDB.fallback_font
			var fs := int(r * 0.95)
			var sz := f.get_string_size(kind, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(f, c + Vector2(-sz.x * 0.5, fs * 0.35), kind, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if label != "":
		var f2 := ThemeDB.fallback_font
		var l := f2.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		draw_string(f2, Vector2(c.x - l.x * 0.5 + 1, size.y + 15), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.6))
		draw_string(f2, Vector2(c.x - l.x * 0.5, size.y + 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.9))

# ---- line-art helpers: every stroke ends in a round cap, so the icons read like a drone app's
func _line(pts: PackedVector2Array, col: Color, w: float) -> void:
	draw_polyline(pts, col, w, true)
	draw_circle(pts[0], w * 0.5, col)
	draw_circle(pts[pts.size() - 1], w * 0.5, col)

func _arc_line(center: Vector2, rad: float, a0: float, a1: float, col: Color, w: float) -> void:
	draw_arc(center, rad, a0, a1, 32, col, w, true)
	draw_circle(center + Vector2(cos(a0), sin(a0)) * rad, w * 0.5, col)

## A pad seen at a slant: a flat ellipse.
func _pad(c: Vector2, s: float, y: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * s * 0.95, y * s + sin(a) * s * 0.3))
	draw_polyline(pts, col, w, true)

## An arrow head: two strokes laid back from the tip.
func _head(tip: Vector2, dir: Vector2, size_: float, col: Color, w: float) -> void:
	var perp := Vector2(-dir.y, dir.x)
	_line(PackedVector2Array([tip - dir * size_ + perp * size_ * 0.75, tip, tip - dir * size_ - perp * size_ * 0.75]), col, w)

func _rrect(rc: Rect2, rad: float, col: Color, w: float) -> void:
	var p := rc.position; var q := rc.end
	var pts := PackedVector2Array()
	for corner in [[Vector2(q.x - rad, p.y + rad), -90.0], [Vector2(q.x - rad, q.y - rad), 0.0], [Vector2(p.x + rad, q.y - rad), 90.0], [Vector2(p.x + rad, p.y + rad), 180.0]]:
		for k in 7:
			var a := deg_to_rad(corner[1] + 90.0 * k / 6.0)
			pts.append(corner[0] + Vector2(cos(a), sin(a)) * rad)
	pts.append(pts[0])
	draw_polyline(pts, col, w, true)

## Four corner brackets, like a camera viewfinder.
func _brackets(c: Vector2, half: float, arm: float, col: Color, w: float) -> void:
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var k := c + Vector2(sx * half, sy * half * 0.78)
			_line(PackedVector2Array([k + Vector2(-sx * arm, 0), k, k + Vector2(0, -sy * arm * 0.8)]), col, w)

func set_kind(k: String) -> void:
	if k != kind:
		kind = k
		queue_redraw()

func set_active(on: bool) -> void:
	if on != active:
		active = on
		queue_redraw()

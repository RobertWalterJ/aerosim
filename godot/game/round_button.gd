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
	var w := 2.4
	var col := accent if active else Color(1, 1, 1, 0.95)
	var s := r * 0.55
	match kind:
		"back":
			draw_polyline(PackedVector2Array([c + Vector2(s * 0.35, -s), c + Vector2(-s * 0.45, 0), c + Vector2(s * 0.35, s)]), col, w, true)
		"gear":
			draw_arc(c, s * 0.5, 0, TAU, 20, col, w, true)
			for i in 8:
				var a := i * TAU / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * s * 0.78, c + Vector2(cos(a), sin(a)) * s * 1.0, col, w + 0.6, true)
		"home":
			draw_polyline(PackedVector2Array([c + Vector2(-s, 0.05 * s), c + Vector2(0, -s * 0.85), c + Vector2(s, 0.05 * s)]), col, w, true)
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.7, 0.0), c + Vector2(-s * 0.7, s * 0.8), c + Vector2(s * 0.7, s * 0.8), c + Vector2(s * 0.7, 0.0)]), col, w, true)
		"takeoff":
			draw_line(c + Vector2(0, s * 0.9), c + Vector2(0, -s * 0.8), col, w, true)
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.6, -s * 0.2), c + Vector2(0, -s * 0.85), c + Vector2(s * 0.6, -s * 0.2)]), col, w, true)
		"land":
			draw_line(c + Vector2(0, -s * 0.9), c + Vector2(0, s * 0.8), col, w, true)
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.6, s * 0.2), c + Vector2(0, s * 0.85), c + Vector2(s * 0.6, s * 0.2)]), col, w, true)
			draw_line(c + Vector2(-s * 0.8, s * 1.0), c + Vector2(s * 0.8, s * 1.0), col, w, true)
		"camera":
			draw_rect(Rect2(c + Vector2(-s, -s * 0.55), Vector2(s * 2, s * 1.4)), col, false, w, true)
			draw_arc(c + Vector2(0, s * 0.15), s * 0.42, 0, TAU, 20, col, w, true)
			draw_line(c + Vector2(-s * 0.4, -s * 0.55), c + Vector2(-s * 0.25, -s * 0.85), col, w, true)
			draw_line(c + Vector2(-s * 0.25, -s * 0.85), c + Vector2(s * 0.25, -s * 0.85), col, w, true)
		"eye":
			draw_arc(c + Vector2(0, s * 0.55), s * 1.05, -2.2, -0.94, 16, col, w, true)
			draw_arc(c + Vector2(0, -s * 0.55), s * 1.05, 0.94, 2.2, 16, col, w, true)
			draw_circle(c, s * 0.32, col)
		"video":
			draw_rect(Rect2(c + Vector2(-s, -s * 0.5), Vector2(s * 1.3, s)), col, false, w, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.45, 0), c + Vector2(s, -s * 0.5), c + Vector2(s, s * 0.5)]), col)
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

func set_kind(k: String) -> void:
	if k != kind:
		kind = k
		queue_redraw()

func set_active(on: bool) -> void:
	if on != active:
		active = on
		queue_redraw()

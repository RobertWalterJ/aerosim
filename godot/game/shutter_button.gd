class_name ShutterButton
extends Control
## The big shutter button: a white ring with a solid centre. In photo mode the centre is white; in video mode it is a
## red dot that turns into a square while recording. Taps arrive as touch events so it works with a thumb on a stick.

signal pressed

var video_mode := false
var recording := false
var _down := false
var _finger := -1

func _init(diameter := 76.0) -> void:
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
	var r := minf(size.x, size.y) * 0.5 - 2.0
	draw_circle(c, r, Color(0.05, 0.06, 0.08, 0.35))
	draw_arc(c, r, 0, TAU, 56, Color(1, 1, 1, 0.95), 3.0, true)
	var inner := r * (0.70 if not _down else 0.62)
	if video_mode:
		if recording:
			var q := inner * 0.62
			draw_rect(Rect2(c - Vector2(q, q), Vector2(q, q) * 2.0), Color(0.95, 0.2, 0.2))
		else:
			draw_circle(c, inner, Color(0.95, 0.2, 0.2))
	else:
		draw_circle(c, inner, Color(1, 1, 1, 0.95))

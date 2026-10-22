class_name ShutterButton
extends Control
## The big shutter button: a white ring with a solid centre. In photo mode the centre is white; in video mode it is a
## red dot that turns into a square while recording. Taps arrive as touch events so it works with a thumb on a stick.

signal pressed

var video_mode := false
var recording := false
var disabled := false
var _down := false
var _finger := -1

func _init(diameter := 76.0) -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	size = Vector2(diameter, diameter)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1   # above the data overlay, whose top bar band would otherwise dim the glyphs

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
			if fire and not disabled: pressed.emit()
			get_viewport().set_input_as_handled()

func _draw() -> void:
	var c := size * 0.5
	var d := minf(size.x, size.y)
	var r := d * 0.5 - 2.0
	var lw := maxf(2.4, d * 0.042)
	var ring := Color(0.55, 0.57, 0.6) if disabled else Color(1, 1, 1, 0.97)
	# dark glass behind, a hairline shadow so the ring holds up against a bright sky, then the white ring
	draw_circle(c, r, Color(0.04, 0.05, 0.07, 0.40 if not _down else 0.55), true, -1.0, true)
	draw_circle(c, r + lw * 0.5 + 0.6, Color(0, 0, 0, 0.22), false, 1.2, true)
	draw_circle(c, r - lw * 0.5 + 0.5, ring, false, lw, true)
	var inner := r * (0.74 if not _down else 0.66)
	var fill := Color(1, 1, 1, 0.97)
	if video_mode: fill = HudIcons.RED
	if disabled: fill = Color(0.45, 0.47, 0.5)
	elif _down: fill = fill.darkened(0.12)
	if video_mode and recording:
		# recording: the dot becomes a rounded square, the stop sign
		var q := inner * 0.56
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		sb.set_corner_radius_all(int(round(q * 0.36)))
		sb.anti_aliasing = true; sb.anti_aliasing_size = 0.8
		sb.draw(get_canvas_item(), Rect2(c - Vector2(q, q), Vector2(q, q) * 2.0))
	else:
		draw_circle(c, inner, fill, true, -1.0, true)

## Grey the shutter out: it still shows, but a tap does nothing.
func set_disabled(on: bool) -> void:
	if on != disabled:
		disabled = on
		queue_redraw()

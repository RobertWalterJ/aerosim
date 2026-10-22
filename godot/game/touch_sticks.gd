class_name TouchSticks
extends Control
## Two floating thumb sticks, like an RC transmitter (Mode 2).
## Left thumb: throttle (up and down) and yaw (left and right). Right thumb: pitch (up = forward) and roll.
## A stick appears where the thumb lands and springs back to centre on release.

var left := Vector2.ZERO     # x = yaw, y = throttle (up = +1)
var right := Vector2.ZERO    # x = roll, y = pitch (up = forward = +1)
var enabled := true:
	set(v):
		enabled = v
		queue_redraw()
var blocked: Array[Control] = []   # controls whose area never starts a stick
var _touches := {}           # finger index -> {side, origin, pos}
var radius := 70.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_resize()
	get_viewport().size_changed.connect(_resize)
	resized.connect(queue_redraw)

func _resize() -> void:
	# this node sits in a canvas layer, not inside another control, so its area is the window itself
	set_deferred("size", get_viewport_rect().size)
	position = Vector2.ZERO
	var vs := get_viewport_rect().size
	radius = clampf(minf(vs.x, vs.y) * 0.16, 46.0, 90.0)
	queue_redraw()

static func _shape(v: float) -> float:
	var a := absf(v)
	var dz := 0.06
	if a < dz: return 0.0
	var n := (a - dz) / (1.0 - dz)
	return signf(v) * (0.35 * n + 0.65 * n * n * n)

func _input(event: InputEvent) -> void:
	if not enabled: return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			var side := "L" if e.position.x < size.x * 0.5 else "R"
			# keep the top strip and the far-right gimbal strip free for buttons
			if e.position.y < size.y * 0.16: return
			for c in blocked:
				if c.is_visible_in_tree() and c.get_global_rect().has_point(e.position): return
			for t in _touches.values():
				if t.side == side: return
			_touches[e.index] = {"side": side, "origin": e.position, "pos": e.position}
		else:
			if _touches.has(e.index):
				var side: String = _touches[e.index].side
				_touches.erase(e.index)
				if side == "L": left = Vector2.ZERO
				else: right = Vector2.ZERO
		queue_redraw()
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if _touches.has(e.index):
			var t = _touches[e.index]
			t.pos = e.position
			var d: Vector2 = (t.pos - t.origin) / radius
			if d.length() > 1.0: d = d.normalized()
			var v := Vector2(_shape(d.x), _shape(-d.y))
			if t.side == "L": left = v
			else: right = v
			queue_redraw()

func release_all() -> void:
	_touches.clear(); left = Vector2.ZERO; right = Vector2.ZERO; queue_redraw()

const LEFT_COL := Color(0.55, 0.88, 1.0)      # left stick: height and turning, cool blue
const RIGHT_COL := Color(1.0, 0.82, 0.45)     # right stick: where the drone travels, warm amber

func _home(side: String) -> Vector2:
	return Vector2(size.x * (0.24 if side == "L" else 0.75), size.y * 0.72)

## Each stick always shows where it is and what it does, like the gimbals of a real transmitter; it moves to the thumb when touched.
func _draw() -> void:
	if not enabled: return
	var font := ThemeDB.fallback_font
	var fs := int(clampf(radius * 0.17, 10.0, 15.0))
	for side in ["L", "R"]:
		var col: Color = LEFT_COL if side == "L" else RIGHT_COL
		var origin := _home(side)
		var pos := origin
		var live := false
		for t in _touches.values():
			if t.side == side:
				origin = t.origin; pos = t.pos; live = true
		if not live: continue      # a stick only appears while a thumb is on it
		var a := 0.55
		draw_circle(origin, radius, Color(0.04, 0.08, 0.1, 0.22 if live else 0.10))
		draw_arc(origin, radius, 0.0, TAU, 48, Color(col.r, col.g, col.b, a + 0.2), 2.0, true)
		# the cross the stick travels along, with an arrowhead at each end
		for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var tip: Vector2 = origin + dir * radius * 0.86
			draw_line(origin + dir * radius * 0.28, tip, Color(col.r, col.g, col.b, a), 1.5, true)
			var perp := Vector2(-dir.y, dir.x)
			draw_line(tip, tip - dir * 8.0 + perp * 5.0, Color(col.r, col.g, col.b, a + 0.15), 1.5, true)
			draw_line(tip, tip - dir * 8.0 - perp * 5.0, Color(col.r, col.g, col.b, a + 0.15), 1.5, true)
		var lab := Color(col.r, col.g, col.b, 0.8 if live else 0.55)
		var names: Array = ["Climb", "Descend", "Left", "Right"] if side == "L" else ["Forward", "Back", "Left", "Right"]
		draw_string(font, origin + Vector2(-radius, -radius - 8.0), "THROTTLE and TURN" if side == "L" else "MOVE", HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, fs, lab)
		draw_string(font, origin + Vector2(-radius, -radius * 0.86 + fs * 1.6), names[0], HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, fs - 1, lab)
		draw_string(font, origin + Vector2(-radius, radius * 0.86 - fs * 0.9), names[1], HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, fs - 1, lab)
		draw_string(font, origin + Vector2(-radius - 4.0, 4.0), names[2], HORIZONTAL_ALIGNMENT_LEFT, radius * 0.7, fs - 2, lab)
		draw_string(font, origin + Vector2(radius * 0.3, 4.0), names[3], HORIZONTAL_ALIGNMENT_RIGHT, radius * 0.7 + 4.0, fs - 2, lab)
		var d: Vector2 = pos - origin
		if d.length() > radius: d = d.normalized() * radius
		draw_circle(origin + d, radius * 0.40, Color(col.r, col.g, col.b, 0.55 if live else 0.20))
		draw_arc(origin + d, radius * 0.40, 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.8 if live else 0.35), 2.0, true)

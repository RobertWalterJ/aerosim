class_name TouchSticks
extends Control
## Two floating thumb sticks, like an RC transmitter (Mode 2).
## Left thumb: throttle (up and down) and yaw (left and right). Right thumb: pitch (up = forward) and roll.
## A stick appears where the thumb lands and springs back to centre on release.

var left := Vector2.ZERO     # x = yaw, y = throttle (up = +1)
var right := Vector2.ZERO    # x = roll, y = pitch (up = forward = +1)
var enabled := true
var _touches := {}           # finger index -> {side, origin, pos}
var radius := 70.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_resize()
	get_viewport().size_changed.connect(_resize)

func _resize() -> void:
	radius = clampf(minf(size.x, size.y) * 0.16, 46.0, 90.0)

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

func _draw() -> void:
	for t in _touches.values():
		draw_circle(t.origin, radius, Color(0.04, 0.08, 0.1, 0.22))
		draw_arc(t.origin, radius, 0.0, TAU, 48, Color(0.86, 1.0, 0.94, 0.5), 2.0, true)
		var d: Vector2 = t.pos - t.origin
		if d.length() > radius: d = d.normalized() * radius
		draw_circle(t.origin + d, radius * 0.46, Color(0.86, 1.0, 0.94, 0.5))

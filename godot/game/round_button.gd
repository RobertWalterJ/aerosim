class_name RoundButton
extends Control
## A round translucent button with a line icon, like the controls on a drone app: dark glass disc, thin white ring.
## Fires `pressed` on a tap. Listens for touch events directly, so a thumb on a flight stick and a second finger on a
## button both work (the mouse also arrives as touch because the project emulates touch from the mouse).
## kind: back, gear (more), home, takeoff, land, camera, video, eye, chase, drone, rc, or a flight mode letter such as
## "N", shown as a coloured mode chip. The icons themselves are drawn by HudIcons so the whole screen shares one look.

signal pressed

var kind := "gear"
var active := false                 # lit blue, for a mode that is on
var accent := HudIcons.ACCENT
var label := ""                     # small caption under the disc
var disabled := false               # greyed out and does not fire
var _down := false
var _finger := -1

func _init(k := "gear", diameter := 56.0) -> void:
	kind = k
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
	var r := d * 0.5 - 1.0
	# back and more sit in the top bar as bare glyphs, the way a drone app shows them; the rest are glass discs
	var bare := kind in ["back", "gear", "more"]
	var icol := HudIcons.WHITE
	if disabled: icol = HudIcons.DISABLED
	elif active: icol = accent
	if not bare:
		var bg := Color(0.05, 0.06, 0.08, 0.46)
		if active and not disabled: bg = Color(0.06, 0.16, 0.30, 0.58)
		if _down: bg = Color(0.32, 0.36, 0.42, 0.62)
		draw_circle(c, r + 0.8, Color(0, 0, 0, 0.18), false, 1.2, true)
		draw_circle(c, r, bg, true, -1.0, true)
		var ring := Color(1, 1, 1, 0.34)
		if disabled: ring = Color(1, 1, 1, 0.14)
		elif active: ring = accent
		draw_circle(c, r - 0.6, ring, false, 2.0 if active and not disabled else 1.2, true)
	elif _down:
		draw_circle(c, r, Color(1, 1, 1, 0.18), true, -1.0, true)
	var box := d * (0.56 if bare else 0.5)
	if _down: box *= 0.92
	if HudIcons.MODE_TINT.has(kind) or kind.length() == 1:
		# the flight mode chip keeps its own colour; greyed out when disabled
		var chip := HudIcons.DISABLED if disabled else HudIcons.mode_tint(kind)
		HudIcons.mode_chip(self, kind, c, d * 0.52 * (0.92 if _down else 1.0), chip)
	elif bare:
		HudIcons.icon_shadowed(self, kind, c, box, icol)
	else:
		HudIcons.icon(self, kind, c, box, icol)
	if label != "":
		var f := HudIcons.label_font()
		var fs := int(round(clampf(d * 0.25, 11.0, 18.0)))
		var l := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var lp := Vector2(c.x - l.x * 0.5, size.y + fs + 1.0)
		draw_string_outline(f, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, int(fs * 0.3)), Color(0, 0, 0, 0.5))
		draw_string(f, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.55) if disabled else Color(1, 1, 1, 0.95))

func set_kind(k: String) -> void:
	if k != kind:
		kind = k
		queue_redraw()

## Grey the button out: it still shows, but a tap does nothing.
func set_disabled(on: bool) -> void:
	if on != disabled:
		disabled = on
		queue_redraw()

func set_active(on: bool) -> void:
	if on != active:
		active = on
		queue_redraw()

class_name TabletIcon
extends Control
## A hand-drawn tablet app icon (session B UI pass). The icons are drawn in code with layered shapes, a warm highlight and
## a quiet shadow so the home screen reads like a real Android tablet rather than labelled buttons.

var kind := "chat"
var accent := UniverseUI.MOSS

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(64, 64)
	resized.connect(queue_redraw)

func set_kind(k: String, tint: Color) -> void:
	kind = k
	accent = tint
	queue_redraw()

func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 4.0:
		return
	var c := size * 0.5
	var r := s * 0.24
	var body := StyleBoxFlat.new()
	body.bg_color = accent.darkened(0.58)
	body.set_corner_radius_all(int(r))
	body.border_width_left = 1
	body.border_width_top = 1
	body.border_width_right = 1
	body.border_width_bottom = 1
	body.border_color = Color(accent.r, accent.g, accent.b, 0.34)
	body.shadow_color = Color(0, 0, 0, 0.35)
	body.shadow_size = 6
	body.shadow_offset = Vector2(0, 2)
	draw_style_box(body, Rect2(Vector2(2, 2), size - Vector2(4, 4)))
	# a soft highlight across the top-left
	var hl := StyleBoxFlat.new()
	hl.bg_color = Color(1.0, 0.93, 0.76, 0.055)
	hl.set_corner_radius_all(int(r * 0.7))
	draw_style_box(hl, Rect2(Vector2(s * 0.12, s * 0.10), Vector2(s * 0.52, s * 0.20)))
	var ink := UniverseUI.CREAM
	match kind:
		"chat":
			# a speech bubble with a small drone silhouette inside it
			var bubble := StyleBoxFlat.new()
			bubble.bg_color = Color(ink.r, ink.g, ink.b, 0.94)
			bubble.set_corner_radius_all(int(s * 0.11))
			draw_style_box(bubble, Rect2(c + Vector2(-s * 0.27, -s * 0.22), Vector2(s * 0.54, s * 0.34)))
			var tail := PackedVector2Array([c + Vector2(-s * 0.12, s * 0.12), c + Vector2(-s * 0.02, s * 0.12), c + Vector2(-s * 0.15, s * 0.24)])
			draw_polygon(tail, PackedColorArray([Color(ink.r, ink.g, ink.b, 0.94)]))
			draw_circle(c + Vector2(-s * 0.14, -s * 0.05), s * 0.035, UniverseUI.MOSS.darkened(0.2))
			draw_circle(c + Vector2(s * 0.14, -s * 0.05), s * 0.035, UniverseUI.MOSS.darkened(0.2))
			draw_line(c + Vector2(-s * 0.10, s * 0.01), c + Vector2(0, s * 0.035), UniverseUI.MOSS.darkened(0.2), maxf(1.0, s * 0.025))
			draw_line(c + Vector2(s * 0.10, s * 0.01), c + Vector2(0, s * 0.035), UniverseUI.MOSS.darkened(0.2), maxf(1.0, s * 0.025))
		"studio":
			# VidTube play mark in a rounded frame
			var frame := StyleBoxFlat.new()
			frame.bg_color = Color(ink.r, ink.g, ink.b, 0.12)
			frame.set_corner_radius_all(int(s * 0.12))
			draw_style_box(frame, Rect2(c + Vector2(-s * 0.28, -s * 0.20), Vector2(s * 0.56, s * 0.40)))
			var tri := PackedVector2Array([c + Vector2(-s * 0.08, -s * 0.14), c + Vector2(-s * 0.08, s * 0.14), c + Vector2(s * 0.20, 0)])
			draw_polygon(tri, PackedColorArray([ink]))
		"photos":
			# aperture blades over a valley line
			for i in 6:
				var a := float(i) * TAU / 6.0 + 0.26
				var p1 := c + Vector2(cos(a), sin(a)) * s * 0.23
				var p2 := c + Vector2(cos(a + 1.0), sin(a + 1.0)) * s * 0.23
				draw_line(p1, p2, ink, maxf(1.4, s * 0.045), true)
			draw_circle(c, s * 0.075, Color(accent.r, accent.g, accent.b, 0.8))
			draw_line(c + Vector2(-s * 0.28, s * 0.23), c + Vector2(-s * 0.05, s * 0.08), ink, maxf(1.0, s * 0.025))
			draw_line(c + Vector2(-s * 0.05, s * 0.08), c + Vector2(s * 0.15, s * 0.20), ink, maxf(1.0, s * 0.025))
		"jobs":
			var board := StyleBoxFlat.new()
			board.bg_color = Color(ink.r, ink.g, ink.b, 0.92)
			board.set_corner_radius_all(int(s * 0.05))
			draw_style_box(board, Rect2(c + Vector2(-s * 0.22, -s * 0.24), Vector2(s * 0.44, s * 0.48)))
			draw_style_box(board, Rect2(c + Vector2(-s * 0.10, -s * 0.29), Vector2(s * 0.20, s * 0.10)))
			for i in 3:
				draw_line(c + Vector2(-s * 0.13, -s * 0.10 + s * 0.13 * i), c + Vector2(s * 0.13, -s * 0.10 + s * 0.13 * i), Color(accent.r, accent.g, accent.b, 0.85), maxf(1.0, s * 0.022))
			draw_circle(c + Vector2(-s * 0.16, -s * 0.10), s * 0.018, UniverseUI.AMBER)
			draw_circle(c + Vector2(-s * 0.16, s * 0.03), s * 0.018, UniverseUI.AMBER)
			draw_circle(c + Vector2(-s * 0.16, s * 0.16), s * 0.018, UniverseUI.AMBER)
		"casebook":
			# a case folder with a brass tab
			var folder := StyleBoxFlat.new()
			folder.bg_color = Color(ink.r, ink.g, ink.b, 0.92)
			folder.set_corner_radius_all(int(s * 0.05))
			draw_style_box(folder, Rect2(c + Vector2(-s * 0.24, -s * 0.18), Vector2(s * 0.48, s * 0.40)))
			var tab := StyleBoxFlat.new()
			tab.bg_color = Color(accent.r, accent.g, accent.b, 1.0)
			tab.set_corner_radius_all(int(s * 0.03))
			draw_style_box(tab, Rect2(c + Vector2(-s * 0.20, -s * 0.26), Vector2(s * 0.30, s * 0.10)))
			draw_line(c + Vector2(-s * 0.14, 0.0), c + Vector2(s * 0.14, 0.0), Color(accent.r, accent.g, accent.b, 0.8), maxf(1.0, s * 0.020))
			draw_line(c + Vector2(-s * 0.14, s * 0.09), c + Vector2(s * 0.10, s * 0.09), Color(accent.r, accent.g, accent.b, 0.8), maxf(1.0, s * 0.020))
			draw_circle(c + Vector2(s * 0.02, s * 0.20), s * 0.04, UniverseUI.AMBER)
		"market":
			# a price tag from MugShot Motors
			var tag := PackedVector2Array([c + Vector2(-s * 0.26, -s * 0.18), c + Vector2(s * 0.12, -s * 0.18), c + Vector2(s * 0.28, 0), c + Vector2(s * 0.12, s * 0.18), c + Vector2(-s * 0.26, s * 0.18)])
			draw_polygon(tag, PackedColorArray([Color(ink.r, ink.g, ink.b, 0.94)]))
			draw_circle(c + Vector2(-s * 0.14, 0), s * 0.045, Color(accent.r, accent.g, accent.b, 0.9))
			draw_line(c + Vector2(0, -s * 0.08), c + Vector2(0, s * 0.08), Color(accent.r, accent.g, accent.b, 0.9), maxf(1.2, s * 0.03))
		"settings":
			for i in 8:
				var a2 := float(i) * TAU / 8.0
				draw_line(c + Vector2(cos(a2), sin(a2)) * s * 0.20, c + Vector2(cos(a2), sin(a2)) * s * 0.28, ink, maxf(1.6, s * 0.055), true)
			draw_arc(c, s * 0.18, 0, TAU, 28, ink, maxf(1.6, s * 0.045), true)
			draw_circle(c, s * 0.07, Color(accent.r, accent.g, accent.b, 0.9))
		_:
			draw_circle(c, s * 0.24, Color(ink.r, ink.g, ink.b, 0.22))
			draw_circle(c, s * 0.10, ink)

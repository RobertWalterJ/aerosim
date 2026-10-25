class_name PhoneBackground
extends Control
## The phone wallpaper (session B UI pass): a dark valley at dusk, with slow topographic contours and a low warm sun.
## It is drawn in code, so it costs nothing to ship and matches the palette of the HUD and the apps.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), UniverseUI.NIGHT)
	# warm low sun behind the valley haze
	draw_circle(Vector2(w * 0.82, h * 0.20), w * 0.22, Color(0.88, 0.64, 0.33, 0.055))
	draw_circle(Vector2(w * 0.82, h * 0.20), w * 0.13, Color(0.94, 0.72, 0.40, 0.045))
	draw_circle(Vector2(w * 0.82, h * 0.20), w * 0.028, Color(0.97, 0.82, 0.55, 0.20))
	# cool lake light in the lower left
	draw_circle(Vector2(w * 0.10, h * 0.78), w * 0.26, Color(0.30, 0.50, 0.52, 0.055))
	# topographic contours: ten slow lines across the lower two thirds
	for i in 11:
		var base := h * (0.44 + float(i) * 0.052)
		var pts := PackedVector2Array()
		var segs := 48
		var amp := 6.0 + float(i) * 1.6
		for s in segs + 1:
			var x := w * float(s) / float(segs)
			var y := base + sin(float(s) * 0.32 + float(i) * 0.9) * amp + sin(float(s) * 0.11 + float(i) * 2.1) * amp * 0.6
			pts.append(Vector2(x, y))
		var a := 0.038 + float(i) * 0.003
		draw_polyline(pts, Color(0.88, 0.72, 0.46, a), 1.0, true)
	# a thin fence line and two field marks, to read as the valley rather than a generic gradient
	var fence_y := h * 0.63
	for i in 15:
		var x := w * (0.06 + float(i) * 0.066)
		draw_line(Vector2(x, fence_y - 5.0), Vector2(x, fence_y + 5.0), Color(0.88, 0.72, 0.46, 0.10), 1.0)
	draw_line(Vector2(w * 0.04, fence_y), Vector2(w * 0.96, fence_y + sin(1.0) * 4.0), Color(0.88, 0.72, 0.46, 0.075), 1.0)
	# bottom vignette
	for i in 14:
		var t := float(i) / 13.0
		draw_rect(Rect2(0.0, h - h * 0.22 + h * 0.22 * t, w, h * 0.018 + 1.0), Color(0.02, 0.03, 0.025, 0.10 + t * 0.22))

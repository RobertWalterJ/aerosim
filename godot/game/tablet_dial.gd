class_name TabletDial
extends Control
## A small analogue instrument for the tablet home screen (session B UI pass). Two modes: a wind compass and a battery
## gauge. Drawn in code so it stays crisp at any resolution and matches the brass and pine palette.

var mode := "wind"
var value := 0.35                 # wind: 0..1 strength, battery: 0..1 charge
var heading := 250.0              # wind direction in degrees
var caption := "WIND"
var accent := UniverseUI.AMBER

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(104, 104)
	resized.connect(queue_redraw)

func set_dial(m: String, v: float, cap: String, tint: Color) -> void:
	mode = m
	value = clampf(v, 0.0, 1.0)
	caption = cap
	accent = tint
	queue_redraw()

func set_heading(deg: float) -> void:
	heading = deg
	queue_redraw()

func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var r := s * 0.43
	# face
	draw_circle(c, r, Color(0.055, 0.070, 0.060, 0.88))
	draw_arc(c, r, 0, TAU, 48, Color(UniverseUI.CREAM.r, UniverseUI.CREAM.g, UniverseUI.CREAM.b, 0.22), 1.2, true)
	draw_arc(c, r * 0.78, 0, TAU, 40, Color(accent.r, accent.g, accent.b, 0.22), 1.0, true)
	var font := ThemeDB.fallback_font
	if mode == "wind":
		for i in 24:
			var a := float(i) * TAU / 24.0 - PI * 0.5
			var inner := r * (0.70 if i % 6 != 0 else 0.62)
			draw_line(c + Vector2(cos(a), sin(a)) * inner, c + Vector2(cos(a), sin(a)) * (r * 0.90), Color(1, 1, 1, 0.28 if i % 6 != 0 else 0.58), 1.0 if i % 6 != 0 else 1.6, true)
		if font != null:
			var fs := int(s * 0.10)
			for pair in [["N", -90.0], ["E", 0.0], ["S", 90.0], ["W", 180.0]]:
				var a := deg_to_rad(float(pair[1]))
				var p := c + Vector2(cos(a), sin(a)) * (r * 0.78)
				var tw := font.get_string_size(str(pair[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(font, p - Vector2(tw * 0.5, -fs * 0.35), str(pair[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UniverseUI.CREAM.r, UniverseUI.CREAM.g, UniverseUI.CREAM.b, 0.62))
		var ha := deg_to_rad(heading - 90.0)
		var tip := c + Vector2(cos(ha), sin(ha)) * (r * 0.66)
		var left := c + Vector2(cos(ha + 2.5), sin(ha + 2.5)) * (r * 0.16)
		var right := c + Vector2(cos(ha - 2.5), sin(ha - 2.5)) * (r * 0.16)
		draw_polygon(PackedVector2Array([tip, left, right]), PackedColorArray([accent]))
		draw_circle(c, s * 0.035, UniverseUI.CREAM)
		if font != null:
			var fs2 := int(s * 0.095)
			var txt := "%d°" % int(round(fposmod(heading, 360.0)))
			var tw2 := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
			draw_string(font, c + Vector2(-tw2 * 0.5, r * 0.40), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(UniverseUI.CREAM.r, UniverseUI.CREAM.g, UniverseUI.CREAM.b, 0.82))
	else:
		# battery arc from about 150 degrees clockwise for 240 degrees
		var start := deg_to_rad(150.0)
		var span := deg_to_rad(240.0)
		draw_arc(c, r * 0.78, start, start + span, 40, Color(1, 1, 1, 0.06), maxf(5.0, s * 0.075), true)
		var col := UniverseUI.MOSS if value > 0.35 else UniverseUI.AMBER
		if value < 0.16:
			col = UniverseUI.RUST
		draw_arc(c, r * 0.78, start, start + span * value, 40, col, maxf(5.0, s * 0.075), true)
		if font != null:
			var fs3 := int(s * 0.16)
			var txt2 := "%d%%" % int(round(value * 100.0))
			var tw3 := font.get_string_size(txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3).x
			draw_string(font, c + Vector2(-tw3 * 0.5, fs3 * 0.36), txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs3, UniverseUI.CREAM)
			var fs4 := int(s * 0.085)
			var cap := caption
			var tw4 := font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, fs4).x
			draw_string(font, c + Vector2(-tw4 * 0.5, fs4 * 2.3), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, fs4, UniverseUI.MUTED)

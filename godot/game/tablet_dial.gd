class_name TabletDial
extends Control
## A small analogue instrument for the tablet home screen. Two modes: a wind compass and a battery gauge.
##
## The faces, needles and the battery fill are the real Claude tablet UI kit art (assets/ui/tablet/dials). The kit
## contract: 512 px faces, needles point up from the exact centre (256, 256), the battery arc starts at 150 degrees and
## sweeps 240 degrees clockwise at radius 176, 32 px wide. The fill is drawn as a textured annulus sector, so the arc
## reveals smoothly at any size and the live number stays crisp on top. If the kit is ever missing, a code-drawn
## fallback keeps the widget readable.

var mode := "wind"
var value := 0.35                 # wind: 0..1 strength, battery: 0..1 charge
var heading := 250.0              # wind direction in degrees
var caption := "WIND"
var accent := UniverseUI.AMBER

const KIT := "res://assets/ui/tablet/dials/"
const ARC_START := 150.0
const ARC_SPAN := 240.0
const FACE_RADIUS := 176.0 / 512.0
const FACE_WIDTH := 32.0 / 512.0

static var _cache := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(104, 104)
	resized.connect(queue_redraw)

func set_dial(m: String, v: float, cap: String, tint: Color) -> void:
	v = clampf(v, 0.0, 1.0)
	var changed := m != mode or not is_equal_approx(v, value) or cap != caption or tint != accent
	mode = m
	value = v
	caption = cap
	accent = tint
	if changed:
		queue_redraw()

func set_heading(deg: float) -> void:
	heading = deg
	queue_redraw()

static func _cached_texture(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path] as Texture2D
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_cache[path] = tex
	return tex

static func _font() -> Font:
	if _cache.has("font"):
		return _cache["font"] as Font
	var f: Font = null
	var inter := "res://assets/ui/tablet/Inter.woff2"
	if ResourceLoader.exists(inter):
		f = load(inter) as Font
	if f == null:
		f = ThemeDB.fallback_font
	_cache["font"] = f
	return f

func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var face := _cached_texture(KIT + ("dial_wind_face.png" if mode == "wind" else "dial_battery_face.png"))
	if face == null:
		_draw_fallback(s, c)
		return
	draw_texture_rect(face, Rect2(Vector2.ZERO, size), false)
	var needle := _cached_texture(KIT + ("dial_needle_wind.png" if mode == "wind" else "dial_needle_battery.png"))
	if mode == "battery":
		_draw_battery_fill(c, s)
		if needle != null:
			_draw_needle(needle, c, size, ARC_START + ARC_SPAN * value)
	elif needle != null:
		# The kit face puts N at the top, so a compass bearing maps to a screen angle 90 degrees anticlockwise of it.
		_draw_needle(needle, c, size, heading - 90.0)
	_draw_text(s, c)

func _draw_battery_fill(c: Vector2, s: float) -> void:
	if value <= 0.001:
		return
	var path := KIT + "dial_battery_fill.png"
	if value <= 0.16:
		path = KIT + "dial_battery_fill_rust.png"
	elif value <= 0.35:
		path = KIT + "dial_battery_fill_amber.png"
	var tex := _cached_texture(path)
	if tex == null:
		return
	var r_out := s * (FACE_RADIUS + FACE_WIDTH * 0.5)
	var r_in := s * (FACE_RADIUS - FACE_WIDTH * 0.5)
	var end := ARC_START + ARC_SPAN * value
	var steps := maxi(3, int(ceil((end - ARC_START) / 3.0)) + 1)
	var pts := PackedVector2Array()
	var uv := PackedVector2Array()
	var cols := PackedColorArray()
	for i in steps:
		var a := deg_to_rad(lerpf(ARC_START, end, float(i) / float(steps - 1)))
		var p := c + Vector2(cos(a), sin(a)) * r_out
		pts.append(p)
		uv.append(p / s)
		cols.append(Color.WHITE)
	for i in steps:
		var a := deg_to_rad(lerpf(end, ARC_START, float(i) / float(steps - 1)))
		var p := c + Vector2(cos(a), sin(a)) * r_in
		pts.append(p)
		uv.append(p / s)
		cols.append(Color.WHITE)
	draw_polygon(pts, cols, uv, tex)

## Rotate a kit needle (art points up, i.e. screen angle -90) to the given screen angle, measured clockwise from +X.
func _draw_needle(tex: Texture2D, c: Vector2, size: Vector2, screen_angle: float) -> void:
	var rot := deg_to_rad(screen_angle + 90.0)
	draw_set_transform(c, rot, Vector2.ONE)
	draw_texture_rect(tex, Rect2(-c, size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_text(s: float, c: Vector2) -> void:
	var f := _font()
	if f == null:
		return
	var cream := UniverseUI.CREAM
	if mode == "wind":
		var fs := maxi(9, int(round(s * 0.105)))
		var txt := "%d°" % int(round(fposmod(heading, 360.0)))
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, c + Vector2(-tw * 0.5, fs * 0.30), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cream)
		var cs := maxi(7, int(round(s * 0.080)))
		var cw := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
		draw_string(f, c + Vector2(-cw * 0.5, cs * 2.55), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, UniverseUI.MUTED)
	else:
		var fs2 := maxi(10, int(round(s * 0.150)))
		var txt2 := "%d%%" % int(round(value * 100.0))
		var tw2 := f.get_string_size(txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		draw_string(f, c + Vector2(-tw2 * 0.5, fs2 * 0.36), txt2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, cream)
		var cs2 := maxi(7, int(round(s * 0.080)))
		var cw2 := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cs2).x
		draw_string(f, c + Vector2(-cw2 * 0.5, cs2 * 2.55), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cs2, UniverseUI.MUTED)

## Code-drawn fallback for a checkout without the kit: keeps the widget legible instead of blank.
func _draw_fallback(s: float, c: Vector2) -> void:
	var r := s * 0.43
	draw_circle(c, r, Color(0.055, 0.070, 0.060, 0.88))
	draw_arc(c, r, 0, TAU, 48, Color(UniverseUI.CREAM.r, UniverseUI.CREAM.g, UniverseUI.CREAM.b, 0.22), 1.2, true)
	if mode == "wind":
		var a := deg_to_rad(heading - 90.0)
		draw_line(c, c + Vector2(cos(a), sin(a)) * r * 0.66, accent, maxf(1.6, s * 0.03), true)
	else:
		draw_arc(c, r * 0.78, deg_to_rad(ARC_START), deg_to_rad(ARC_START + ARC_SPAN * value), 40,
			UniverseUI.MOSS if value > 0.35 else UniverseUI.AMBER, maxf(5.0, s * 0.075), true)
		_draw_text(s, c)

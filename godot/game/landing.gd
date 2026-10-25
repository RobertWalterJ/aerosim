class_name Landing
extends CanvasLayer
## The landing screen: the real valley behind a slowly circling camera, framed like a film title card. A soft vignette,
## top and bottom letterbox bars, and a shaded left edge hold the words; the title and menu ease in over the world.
## Nothing here is a separate scene: the world behind it is the game itself, so it costs almost nothing.

signal fly_pressed
signal drone_pressed
signal settings_pressed
signal controls_pressed
signal quit_pressed
signal look_chosen(hour: float, sky: int)

# The field-kit accent (brass), matching Claude's UI direction, used for the one main action instead of cyan.
const BRASS := Color(0.878, 0.671, 0.349)          # #E0AB59
const ON_BRASS := Color(0.251, 0.176, 0.0)          # #402D00
const BRASS_DIM := Color(0.878, 0.671, 0.349, 0.62)
const INK := Color(0.01, 0.02, 0.04)

var _drone_label: Label
var _root: Control
var _fade_in: Array[CanvasItem] = []
var _fade := 0.0

func _init() -> void:
	layer = 5          # under the pause menu (layer 10), over the video

func build(drone_name: String) -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := MenuStyle.make_theme()
	# recolor the one main action to brass (the settings pages keep their own accent)
	MenuStyle._button(t, "Primary",
		MenuStyle.box(BRASS, 14, Color(0, 0, 0, 0), 0, 26.0, 12.0),
		MenuStyle.box(BRASS.lightened(0.08), 14, Color(0, 0, 0, 0), 0, 26.0, 12.0),
		MenuStyle.box(BRASS.darkened(0.08), 14, Color(0, 0, 0, 0), 0, 26.0, 12.0),
		MenuStyle.box(BRASS.darkened(0.08), 14, Color(0, 0, 0, 0), 0, 26.0, 12.0),
		ON_BRASS, ON_BRASS)
	t.set_font_size("font_size", "Primary", 24)
	_root.theme = t
	add_child(_root)

	# --- the cinematic frame -------------------------------------------------
	_root.add_child(_vignette())          # edges fall away
	_root.add_child(_letterbox(true))     # top bar
	_root.add_child(_letterbox(false))    # bottom bar
	var shade := TextureRect.new()        # soft shade on the left so the words read on any picture
	var g := Gradient.new(); g.set_color(0, Color(INK.r, INK.g, INK.b, 0.86)); g.set_color(1, Color(INK.r, INK.g, INK.b, 0.0))
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill_from = Vector2(0, 0.5); gt.fill_to = Vector2(1, 0.5); gt.width = 512; gt.height = 8
	shade.texture = gt; shade.stretch_mode = TextureRect.STRETCH_SCALE; shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.anchor_right = 0.58; shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	# --- the menu column -----------------------------------------------------
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 7)
	col.anchor_left = 0.06; col.anchor_right = 0.44; col.anchor_top = 0.0; col.anchor_bottom = 1.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(col)

	var overline := Label.new(); overline.text = "HALLOWAY VALLEY"
	overline.add_theme_font_size_override("font_size", 15)
	overline.add_theme_color_override("font_color", BRASS_DIM)
	var fv := FontVariation.new(); fv.base_font = ThemeDB.fallback_font; fv.spacing_glyph = 10
	overline.add_theme_font_override("font", fv)
	col.add_child(overline)

	var title := Label.new(); title.text = "AeroSim"
	title.add_theme_font_size_override("font_size", 70)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 4)
	col.add_child(title)

	var rule := ColorRect.new(); rule.color = BRASS_DIM
	rule.custom_minimum_size = Vector2(46, 2)
	col.add_child(rule)

	var tagline := Label.new(); tagline.text = "Fly to feel free."
	tagline.add_theme_font_size_override("font_size", 19)
	tagline.add_theme_color_override("font_color", MenuStyle.MUTED)
	col.add_child(tagline)

	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 14); col.add_child(gap)

	var fly := Button.new(); fly.text = "Fly"; fly.theme_type_variation = "Primary"; fly.custom_minimum_size = Vector2(0, 62)
	fly.add_theme_font_size_override("font_size", 28)
	fly.pressed.connect(func(): fly_pressed.emit())
	col.add_child(fly)

	_drone_label = Label.new(); _drone_label.text = drone_name
	_drone_label.add_theme_font_size_override("font_size", 16)
	_drone_label.add_theme_color_override("font_color", MenuStyle.MUTED)
	col.add_child(_drone_label)

	# secondary actions in a quiet row
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	for item in [["Choose a drone", drone_pressed], ["Settings", settings_pressed], ["Controls", controls_pressed]]:
		var b := Button.new(); b.text = item[0]; b.theme_type_variation = "Ghost"; b.custom_minimum_size = Vector2(0, 42)
		b.add_theme_font_size_override("font_size", 16)
		var sig: Signal = item[1]
		b.pressed.connect(func(): sig.emit())
		row.add_child(b)

	var q := Button.new(); q.text = "Quit"; q.theme_type_variation = "Danger"; q.custom_minimum_size = Vector2(0, 40)
	q.alignment = HORIZONTAL_ALIGNMENT_LEFT
	q.add_theme_font_size_override("font_size", 15)
	q.pressed.connect(func(): quit_pressed.emit())
	col.add_child(q)

	# --- the corners ---------------------------------------------------------
	var hint := Label.new(); hint.text = "Esc opens the menu while you fly."
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.42))
	hint.anchor_left = 0.0; hint.anchor_top = 1.0; hint.anchor_right = 0.6; hint.anchor_bottom = 1.0
	hint.offset_left = 42; hint.offset_top = -34; hint.offset_right = 0; hint.offset_bottom = -14
	_root.add_child(hint)

	var ver := Label.new(); ver.text = "Halloway Valley"
	ver.add_theme_font_size_override("font_size", 13)
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.42))
	ver.anchor_left = 1.0; ver.anchor_top = 1.0; ver.anchor_right = 1.0; ver.anchor_bottom = 1.0
	ver.offset_left = -220; ver.offset_top = -34; ver.offset_right = -42; ver.offset_bottom = -14
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(ver)

	# fade the menu and corners in over the world
	_fade_in = [col, hint, ver]
	for item in _fade_in: item.modulate.a = 0.0

func _process(delta: float) -> void:
	if _fade >= 1.0 or _fade_in.is_empty(): return
	_fade = minf(1.0, _fade + delta * 1.6)
	var a := 1.0 - pow(1.0 - _fade, 3.0)     # ease-out cubic
	for item in _fade_in: item.modulate.a = a

func set_drone_name(n: String) -> void:
	if _drone_label: _drone_label.text = n

# --- frame helpers -----------------------------------------------------------
func _vignette() -> TextureRect:
	var r := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0.0, Color(0, 0, 0, 0.0))
	g.set_color(0.68, Color(0, 0, 0, 0.10))
	g.set_color(1.0, Color(0, 0, 0, 0.34))
	var gt := GradientTexture2D.new(); gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5); gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 512; gt.height = 512
	r.texture = gt; r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _letterbox(top: bool) -> TextureRect:
	var r := TextureRect.new()
	var g := Gradient.new()
	if top:
		g.set_color(0.0, Color(0, 0, 0, 0.45)); g.set_color(1.0, Color(0, 0, 0, 0.0))
	else:
		g.set_color(0.0, Color(0, 0, 0, 0.0)); g.set_color(1.0, Color(0, 0, 0, 0.45))
	var gt := GradientTexture2D.new(); gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0); gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 8; gt.height = 256
	r.texture = gt; r.stretch_mode = TextureRect.STRETCH_SCALE
	if top:
		r.set_anchors_preset(Control.PRESET_TOP_WIDE)
		r.anchor_bottom = 0.20
	else:
		r.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		r.anchor_top = 0.80
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## Where the camera is while the landing screen is up: a slow circle around the drone, a little above it, looking at it.
static func orbit(centre: Vector3, t: float, ground_h: float, arm: float) -> Transform3D:
	var a := 0.9 + t * 0.07
	var r := (1.9 + 11.0 * arm) * (1.0 + 0.12 * sin(t * 0.13))
	var h := 0.5 + 6.0 * arm + 0.25 * sin(t * 0.09)
	var pos := centre + Vector3(sin(a) * r, h, cos(a) * r)
	pos.y = maxf(pos.y, ground_h + 0.35)
	# aim a little to the drone's left so it sits in the right-hand half of the screen, clear of the menu
	var side := Vector3(cos(a), 0.0, -sin(a))
	var aim := centre + Vector3(0, 0.15 + 2.0 * arm, 0) - side * (0.45 * r)
	return Transform3D(Basis.looking_at((aim - pos).normalized(), Vector3.UP), pos)

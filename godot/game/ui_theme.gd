class_name UniverseUI
extends RefCounted
## The shared look of the phone, its apps and the HUD menus (session B UI pass).
##
## The universe is a wet autumn valley and a small provincial town, so the interface is built like a field notebook and
## an old broadcast kit: deep pine and charcoal surfaces, warm paper text, brass and amber for actions, moss for the
## channel and lake teal for the weather. It is deliberately not a silicon-valley dark theme.
##
## One Theme is applied to the phone root, so every app inherits the same buttons, fields, scrollbars and type. Apps
## style their own cards and headers from the palette below.

const NIGHT := Color(0.043, 0.047, 0.055, 1.0)
const DEEP := Color(0.063, 0.071, 0.086, 1.0)
const PANEL := Color(0.086, 0.094, 0.110, 1.0)
const CARD := Color(0.110, 0.118, 0.137, 1.0)
const FIELD := Color(0.145, 0.153, 0.176, 1.0)
const FIELD_HOVER := Color(0.190, 0.200, 0.227, 1.0)
const CREAM := Color(0.902, 0.890, 0.913, 1.0)
const CREAM_DIM := Color(0.780, 0.770, 0.800, 1.0)
const MUTED := Color(0.590, 0.575, 0.615, 1.0)
const FAINT := Color(0.390, 0.380, 0.415, 1.0)
const AMBER := Color(0.658, 0.780, 0.980, 1.0)
const AMBER_HOVER := Color(0.760, 0.850, 1.0, 1.0)
const AMBER_SOFT := Color(0.658, 0.780, 0.980, 0.16)
const ON_AMBER := Color(0.035, 0.080, 0.125, 1.0)
const MOSS := Color(0.560, 0.835, 0.650, 1.0)
const MOSS_SOFT := Color(0.560, 0.835, 0.650, 0.16)
const LAKE := Color(0.520, 0.780, 0.850, 1.0)
const RUST := Color(0.940, 0.720, 0.640, 1.0)
const DANGER := Color(1.0, 0.705, 0.670, 1.0)
const LINE := Color(0.902, 0.890, 0.913, 0.11)
const LINE_STRONG := Color(0.780, 0.830, 0.950, 0.26)

static func box(bg: Color, radius := 12, border := LINE, bw := 1, mx := 16.0, my := 10.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.set_border_width_all(bw)
		s.border_color = border
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	s.anti_aliasing = true
	return s

static func card(radius := 16, bg := CARD, border := LINE, bw := 1) -> StyleBoxFlat:
	return box(bg, radius, border, bw, 18.0, 16.0)

static func label(text: String, size := 15, colour := CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l

static func small_caps(text: String) -> Label:
	var l := label(text.to_upper(), 10, MUTED)
	l.add_theme_constant_override("line_spacing", 2)
	return l

static func pill(text: String, colour := AMBER) -> Label:
	var l := label(text.to_upper(), 10, colour)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

## Optional Claude UI art. Every helper returns null or a fallback when the file has not been delivered yet, so the
## app layout never depends on an asset that is still in the brief.
static func ui_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

static func avatar_texture(key: String) -> Texture2D:
	return ui_texture("res://assets/ui/avatar_%s.png" % key)

static func case_art(key: String) -> Texture2D:
	return ui_texture("res://assets/ui/%s.png" % key)

static func initials(name: String) -> String:
	var bits := name.strip_edges().split(" ", false)
	if bits.is_empty():
		return "?"
	if bits.size() == 1:
		return bits[0].substr(0, 1).to_upper()
	return (bits[0].substr(0, 1) + bits[bits.size() - 1].substr(0, 1)).to_upper()

## A portrait tile with a real Claude avatar when it exists, otherwise the warm initials placeholder.
static func avatar(key: String, size := 38, tint := MOSS) -> Control:
	var holder := PanelContainer.new()
	holder.custom_minimum_size = Vector2(size, size)
	holder.add_theme_stylebox_override("panel", box(tint.darkened(0.45), int(size * 0.5), tint.darkened(0.1), 1, 0.0, 0.0))
	holder.clip_contents = true
	var tex := avatar_texture(key)
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
		holder.add_child(pic)
	else:
		var lab := label(initials(key.capitalize()), int(size * 0.36), CREAM)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		holder.add_child(lab)
	return holder
## A Claude app icon when the file exists, otherwise the drawn tablet glyph. The caller keeps the same Control slot.
static func app_icon(key: String, size := 48, tint := MOSS) -> Control:
	var tex := ui_texture("res://assets/ui/icon_%s.png" % key)
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.custom_minimum_size = Vector2(size, size)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return pic
	var fallback := TabletIcon.new()
	fallback.custom_minimum_size = Vector2(size, size)
	fallback.set_kind(key, tint)
	return fallback
static func app_colour(key: String) -> Color:
	match key:
		"chat": return MOSS
		"studio": return RUST
		"photos": return LAKE
		"jobs": return AMBER
		"casebook": return Color(0.545, 0.575, 0.700)
		"market": return Color(0.760, 0.520, 0.280)
		"map": return Color(0.470, 0.640, 0.470)
		_: return MUTED

static func _button(t: Theme, type: String, normal: StyleBox, hover: StyleBox, pressed: StyleBox, font: Color, font_pressed: Color) -> void:
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("hover_pressed", type, pressed)
	t.set_stylebox("disabled", type, normal)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_color("font_color", type, font)
	t.set_color("font_hover_color", type, font)
	t.set_color("font_pressed_color", type, font_pressed)
	t.set_color("font_hover_pressed_color", type, font_pressed)
	t.set_color("font_focus_color", type, font)
	t.set_color("font_disabled_color", type, FAINT)

static func make_theme() -> Theme:
	var t := Theme.new()
	var inter := load("res://assets/ui/tablet/Inter.woff2") as Font
	if inter != null:
		t.default_font = inter
	t.default_font_size = 16
	t.set_color("font_color", "Label", CREAM)
	t.set_constant("line_spacing", "Label", 3)
	t.set_color("font_color", "RichTextLabel", CREAM)
	t.set_color("default_color", "RichTextLabel", CREAM)
	# the ordinary phone button: a pressed field with a warm hairline
	_button(t, "Button", box(FIELD, 10, LINE, 1, 16.0, 9.0), box(FIELD_HOVER, 10, LINE_STRONG, 1, 16.0, 9.0),
		box(AMBER, 10, AMBER, 1, 16.0, 9.0), CREAM, ON_AMBER)
	# one clear action per screen
	t.set_type_variation("Primary", "Button")
	_button(t, "Primary", box(AMBER, 11, AMBER, 1, 20.0, 10.0), box(AMBER_HOVER, 11, AMBER_HOVER, 1, 20.0, 10.0),
		box(AMBER.darkened(0.12), 11, AMBER.darkened(0.12), 1, 20.0, 10.0), ON_AMBER, ON_AMBER)
	t.set_font_size("font_size", "Primary", 17)
	# a quiet outline
	t.set_type_variation("Ghost", "Button")
	_button(t, "Ghost", box(Color(1, 1, 1, 0.02), 10, LINE, 1, 16.0, 9.0), box(Color(1, 1, 1, 0.07), 10, LINE_STRONG, 1, 16.0, 9.0),
		box(AMBER_SOFT, 10, AMBER, 1, 16.0, 9.0), CREAM_DIM, CREAM)
	# a channel row: quiet until selected
	t.set_type_variation("Channel", "Button")
	_button(t, "Channel", box(Color(0, 0, 0, 0), 8, Color(0, 0, 0, 0), 0, 12.0, 6.0), box(Color(1, 1, 1, 0.045), 8, Color(0, 0, 0, 0), 0, 12.0, 6.0),
		box(AMBER_SOFT, 8, AMBER, 0, 12.0, 6.0), MUTED, CREAM)
	t.set_font_size("font_size", "Channel", 15)
	# quick question chips and small actions
	t.set_type_variation("Chip", "Button")
	_button(t, "Chip", box(FIELD, 8, LINE, 1, 10.0, 4.0), box(FIELD_HOVER, 8, LINE_STRONG, 1, 10.0, 4.0),
		box(AMBER_SOFT, 8, AMBER, 1, 10.0, 4.0), CREAM_DIM, CREAM)
	t.set_font_size("font_size", "Chip", 12)
	# cards
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", card(16))
	t.set_type_variation("FlatCard", "PanelContainer")
	t.set_stylebox("panel", "FlatCard", card(12, PANEL, LINE, 1))
	# text fields
	t.set_stylebox("normal", "LineEdit", box(FIELD, 10, LINE, 1, 14.0, 9.0))
	t.set_stylebox("focus", "LineEdit", box(FIELD_HOVER, 10, AMBER, 1, 14.0, 9.0))
	t.set_stylebox("read_only", "LineEdit", box(PANEL, 10, LINE, 1, 14.0, 9.0))
	t.set_color("font_color", "LineEdit", CREAM)
	t.set_color("font_placeholder_color", "LineEdit", FAINT)
	t.set_color("caret_color", "LineEdit", AMBER)
	t.set_color("selection_color", "LineEdit", AMBER_SOFT)
	t.set_font_size("font_size", "LineEdit", 15)
	# scrollbars: quiet brass
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0), 3, Color(0, 0, 0, 0), 0, 3.0, 0.0))
	t.set_stylebox("grabber", "VScrollBar", box(Color(0.88, 0.67, 0.35, 0.30), 3, Color(0, 0, 0, 0), 0, 3.0, 0.0))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(Color(0.88, 0.67, 0.35, 0.55), 3, Color(0, 0, 0, 0), 0, 3.0, 0.0))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(AMBER, 3, Color(0, 0, 0, 0), 0, 3.0, 0.0))
	return t

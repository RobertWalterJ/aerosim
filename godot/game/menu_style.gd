class_name MenuStyle
extends RefCounted
## The look of the settings page: a dark, quiet surface with one cool accent, grouped into rounded cards.
## Everything is drawn from styleboxes in one Theme, so a button, slider or tab looks the same wherever it appears.
## Variations: SideTab (the tab list), Primary (the one main action), Ghost (quiet outline), Danger (leave the game), DroneCard.

const BG := Color(0.045, 0.055, 0.075, 0.975)
const CARD := Color(0.09, 0.105, 0.135, 1.0)
const FIELD := Color(0.135, 0.155, 0.195, 1.0)
const FIELD_HOVER := Color(0.175, 0.2, 0.25, 1.0)
const ACCENT := Color(0.30, 0.78, 0.98)
const ON_ACCENT := Color(0.02, 0.07, 0.11)
const TEXT := Color(0.93, 0.955, 0.98)
const MUTED := Color(0.60, 0.67, 0.76)
const DANGER := Color(0.98, 0.45, 0.45)
const LINE := Color(1, 1, 1, 0.07)

static func box(bg: Color, radius := 12, border := Color(0, 0, 0, 0), bw := 0, mx := 18.0, my := 12.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.set_border_width_all(bw); s.border_color = border
	s.content_margin_left = mx; s.content_margin_right = mx; s.content_margin_top = my; s.content_margin_bottom = my
	s.anti_aliasing = true
	return s

static func _dot(radius: int, fill: Color, rim: Color) -> ImageTexture:
	var d := radius * 2 + 4
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(d * 0.5, d * 0.5)
	for y in d:
		for x in d:
			var r := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(radius + 0.5 - r, 0.0, 1.0)
			var rim_k := clampf(r - (radius - 3.0), 0.0, 1.0)
			var col := fill.lerp(rim, rim_k)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)

## Style a toggle or push button in every state, from one set of colours.
static func _button(t: Theme, type: String, normal: StyleBoxFlat, hover: StyleBoxFlat, pressed: StyleBoxFlat, hover_pressed: StyleBoxFlat,
		font: Color, font_pressed: Color) -> void:
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("hover_pressed", type, hover_pressed)
	t.set_stylebox("disabled", type, normal)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_color("font_color", type, font)
	t.set_color("font_hover_color", type, font)
	t.set_color("font_focus_color", type, font)
	t.set_color("font_pressed_color", type, font_pressed)
	t.set_color("font_hover_pressed_color", type, font_pressed)

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 19
	t.set_color("font_color", "Label", TEXT)
	t.set_constant("line_spacing", "Label", 4)
	# the default button: a soft field, and when switched on it fills with the accent colour
	var accent_hover := ACCENT.lightened(0.15)
	_button(t, "Button", box(FIELD, 12, LINE, 1), box(FIELD_HOVER, 12, LINE, 1), box(ACCENT, 12), box(accent_hover, 12), TEXT, ON_ACCENT)
	# the tab list down the left side
	t.set_type_variation("SideTab", "Button")
	var tab_on := box(Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.14), 12, ACCENT, 0, 20.0, 14.0)
	tab_on.border_width_left = 4; tab_on.border_color = ACCENT
	_button(t, "SideTab", box(Color(0, 0, 0, 0), 12, Color(0, 0, 0, 0), 0, 20.0, 14.0), box(Color(1, 1, 1, 0.05), 12, Color(0, 0, 0, 0), 0, 20.0, 14.0), tab_on, tab_on, MUTED, ACCENT)
	t.set_font_size("font_size", "SideTab", 21)
	# the one main action
	t.set_type_variation("Primary", "Button")
	_button(t, "Primary", box(ACCENT, 14, Color(0, 0, 0, 0), 0, 26.0, 12.0), box(accent_hover, 14, Color(0, 0, 0, 0), 0, 26.0, 12.0), box(ACCENT.darkened(0.1), 14, Color(0, 0, 0, 0), 0, 26.0, 12.0), box(ACCENT.darkened(0.1), 14, Color(0, 0, 0, 0), 0, 26.0, 12.0), ON_ACCENT, ON_ACCENT)
	t.set_font_size("font_size", "Primary", 21)
	# a quiet outline
	t.set_type_variation("Ghost", "Button")
	_button(t, "Ghost", box(Color(0, 0, 0, 0), 14, Color(1, 1, 1, 0.16), 1, 22.0, 12.0), box(Color(1, 1, 1, 0.07), 14, Color(1, 1, 1, 0.26), 1, 22.0, 12.0), box(Color(1, 1, 1, 0.12), 14, Color(1, 1, 1, 0.3), 1, 22.0, 12.0), box(Color(1, 1, 1, 0.12), 14, Color(1, 1, 1, 0.3), 1, 22.0, 12.0), TEXT, TEXT)
	# leaving the game
	t.set_type_variation("Danger", "Button")
	_button(t, "Danger", box(Color(0, 0, 0, 0), 14, Color(DANGER.r, DANGER.g, DANGER.b, 0.45), 1, 22.0, 12.0), box(Color(DANGER.r, DANGER.g, DANGER.b, 0.12), 14, Color(DANGER.r, DANGER.g, DANGER.b, 0.7), 1, 22.0, 12.0), box(DANGER, 14, DANGER, 1, 22.0, 12.0), box(DANGER, 14, DANGER, 1, 22.0, 12.0), DANGER, ON_ACCENT)
	# a choice of drone: a card that lights its edge when chosen
	t.set_type_variation("DroneCard", "Button")
	var drone_on := box(Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.13), 14, ACCENT, 2, 20.0, 14.0)
	_button(t, "DroneCard", box(FIELD, 14, LINE, 1, 20.0, 14.0), box(FIELD_HOVER, 14, LINE, 1, 20.0, 14.0), drone_on, drone_on, TEXT, TEXT)
	# cards
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", box(CARD, 18, LINE, 1, 22.0, 18.0))
	# sliders: a slim track, filled with the accent up to a round handle
	var track := box(Color(1, 1, 1, 0.10), 4, Color(0, 0, 0, 0), 0, 0.0, 3.0)
	var fill := box(ACCENT, 4, Color(0, 0, 0, 0), 0, 0.0, 3.0)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var dot := _dot(14, Color.WHITE, ACCENT)
	t.set_icon("grabber", "HSlider", dot)
	t.set_icon("grabber_highlight", "HSlider", _dot(16, Color.WHITE, ACCENT))
	t.set_icon("grabber_disabled", "HSlider", dot)
	# the scroll bar: thin and quiet
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0), 4, Color(0, 0, 0, 0), 0, 4.0, 0.0))
	t.set_stylebox("grabber", "VScrollBar", box(Color(1, 1, 1, 0.22), 4, Color(0, 0, 0, 0), 0, 3.0, 0.0))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(Color(1, 1, 1, 0.35), 4, Color(0, 0, 0, 0), 0, 3.0, 0.0))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(ACCENT, 4, Color(0, 0, 0, 0), 0, 3.0, 0.0))
	t.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	return t

## Group a page into cards: every section heading starts a new card and takes the controls that follow it.
static func cardify(page: VBoxContainer) -> void:
	var kids := page.get_children()
	var card: VBoxContainer = null
	for k in kids:
		if k is Label and k.has_meta("heading"):
			var panel := PanelContainer.new()
			panel.theme_type_variation = "Card"
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card = VBoxContainer.new()
			card.add_theme_constant_override("separation", 14)
			panel.add_child(card)
			page.add_child(panel)
			page.remove_child(k)
			card.add_child(k)
		elif card != null:
			page.remove_child(k)
			card.add_child(k)

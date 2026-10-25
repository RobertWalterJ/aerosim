class_name Landing
extends CanvasLayer
## The landing screen: the real valley seen from a slowly circling camera around the drone, with the title,
## a one-line invitation, and the menu on the left. Nothing here is a separate scene: the world behind it is
## the game itself, so it costs almost nothing. Fly starts the flight; the rest open the pause-menu pages.

signal fly_pressed
signal drone_pressed
signal settings_pressed
signal controls_pressed
signal quit_pressed
signal look_chosen(hour: float, sky: int)

const LOOKS := [
	{"name": "Golden hour", "hour": 17.9, "sky": 1},
	{"name": "Clear morning", "hour": 9.5, "sky": 0},
	{"name": "Overcast", "hour": 13.0, "sky": 2},
	{"name": "Misty dawn", "hour": 6.7, "sky": 3},
	{"name": "Night", "hour": 22.0, "sky": 0},
	{"name": "Snow", "hour": 11.0, "sky": 6},
]

# The field-kit accent (brass), matching Claude's UI direction, used for the one main action instead of cyan.
const BRASS := Color(0.878, 0.671, 0.349)          # #E0AB59
const ON_BRASS := Color(0.251, 0.176, 0.0)          # #402D00
const BRASS_DIM := Color(0.878, 0.671, 0.349, 0.62)

var _drone_label: Label
var _look_btns: Array[Button] = []
var _root: Control

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

	# a soft shade on the left so the words read on any picture
	var shade := TextureRect.new()
	var g := Gradient.new(); g.set_color(0, Color(0.01, 0.02, 0.04, 0.86)); g.set_color(1, Color(0.01, 0.02, 0.04, 0.0))
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill_from = Vector2(0, 0.5); gt.fill_to = Vector2(1, 0.5); gt.width = 512; gt.height = 8
	shade.texture = gt; shade.stretch_mode = TextureRect.STRETCH_SCALE; shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.anchor_right = 0.60; shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 8)
	col.anchor_left = 0.05; col.anchor_right = 0.42; col.anchor_top = 0.0; col.anchor_bottom = 1.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(col)

	# title block: a quiet overline, the name, and a one-line invitation
	var overline := Label.new(); overline.text = "HALLOWAY VALLEY"
	overline.add_theme_font_size_override("font_size", 15)
	overline.add_theme_color_override("font_color", BRASS_DIM)
	col.add_child(overline)

	var title := Label.new(); title.text = "AeroSim"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	col.add_child(title)

	var tagline := Label.new(); tagline.text = "Some stories only surface from the air."
	tagline.add_theme_font_size_override("font_size", 20)
	tagline.add_theme_color_override("font_color", MenuStyle.MUTED)
	col.add_child(tagline)

	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 16); col.add_child(gap)

	var fly := Button.new(); fly.text = "Fly"; fly.theme_type_variation = "Primary"; fly.custom_minimum_size = Vector2(0, 60)
	fly.add_theme_font_size_override("font_size", 28)
	fly.pressed.connect(func(): fly_pressed.emit())
	col.add_child(fly)

	_drone_label = Label.new(); _drone_label.text = drone_name
	_drone_label.add_theme_font_size_override("font_size", 17)
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

	# time and weather quick looks
	var lh := Label.new(); lh.text = "TIME AND WEATHER"; lh.add_theme_font_size_override("font_size", 13); lh.add_theme_color_override("font_color", BRASS_DIM)
	col.add_child(lh)
	var flow := HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 8); flow.add_theme_constant_override("v_separation", 8)
	col.add_child(flow)
	for i in LOOKS.size():
		var b := Button.new(); b.text = LOOKS[i]["name"]; b.toggle_mode = true; b.custom_minimum_size = Vector2(0, 36)
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(func():
			for j in _look_btns.size(): _look_btns[j].set_pressed_no_signal(j == i)
			look_chosen.emit(float(LOOKS[i]["hour"]), int(LOOKS[i]["sky"])))
		flow.add_child(b); _look_btns.append(b)

	var q := Button.new(); q.text = "Quit"; q.theme_type_variation = "Danger"; q.custom_minimum_size = Vector2(0, 40)
	q.alignment = HORIZONTAL_ALIGNMENT_LEFT
	q.add_theme_font_size_override("font_size", 15)
	q.pressed.connect(func(): quit_pressed.emit())
	col.add_child(q)

	var hint := Label.new(); hint.text = "Esc opens the menu while you fly."
	hint.add_theme_font_size_override("font_size", 14); hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	col.add_child(hint)

func set_drone_name(n: String) -> void:
	if _drone_label: _drone_label.text = n

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

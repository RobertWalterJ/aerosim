class_name Landing
extends CanvasLayer
## The welcome screen: the valley seen from a slowly circling camera around the drone, with the title and a short menu.
##
## Story is the normal game: the investigation, the jobs and the festival, with the valley owning its weather and its
## clock. Sandbox is the opt-in creator mode: the time and weather quick looks and all the old event powers come back.
## The mode is chosen here and saved; the HUD hides the weather controls in Story mode.

signal fly_pressed
signal drone_pressed
signal settings_pressed
signal controls_pressed
signal quit_pressed
signal look_chosen(hour: float, sky: int)
signal mode_chosen(story: bool)

const LOOKS := [
	{"name": "Golden hour", "hour": 17.9, "sky": 1},
	{"name": "Clear morning", "hour": 9.5, "sky": 0},
	{"name": "Overcast", "hour": 13.0, "sky": 2},
	{"name": "Misty dawn", "hour": 6.7, "sky": 3},
	{"name": "Night", "hour": 22.0, "sky": 0},
	{"name": "Snow", "hour": 11.0, "sky": 6},
]

var _drone_label: Label
var _look_btns: Array[Button] = []
var _root: Control
var _story_mode := true
var _looks_section: VBoxContainer
var _story_note: Label
var _mode_desc: Label
var _story_btn: Button
var _sandbox_btn: Button

func _init() -> void:
	layer = 5          # under the pause menu (layer 10), over the video

func build(drone_name: String, story_mode := true) -> void:
	_story_mode = story_mode
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = MenuStyle.make_theme()
	add_child(_root)
	# a soft shade on the left so the words read on any picture, and a thin one at the bottom
	var shade := TextureRect.new()
	var g := Gradient.new(); g.set_color(0, Color(0.01, 0.02, 0.04, 0.82)); g.set_color(1, Color(0.01, 0.02, 0.04, 0.0))
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill_from = Vector2(0, 0.5); gt.fill_to = Vector2(1, 0.5); gt.width = 512; gt.height = 8
	shade.texture = gt; shade.stretch_mode = TextureRect.STRETCH_SCALE; shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.anchor_right = 0.62; shade.offset_right = 0; shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 8)
	col.anchor_left = 0.05; col.anchor_right = 0.44; col.anchor_top = 0.0; col.anchor_bottom = 1.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(col)
	var title := Label.new(); title.text = "AeroSim"
	title.add_theme_font_size_override("font_size", 54); title.add_theme_color_override("font_color", Color.WHITE)
	var sub := Label.new(); sub.text = "A drone flight simulator  ·  the valley and the story"
	sub.add_theme_font_size_override("font_size", 17); sub.add_theme_color_override("font_color", MenuStyle.MUTED)
	col.add_child(title); col.add_child(sub)
	# mode
	var mode_head := Label.new(); mode_head.text = "MODE"
	mode_head.add_theme_font_size_override("font_size", 11); mode_head.add_theme_color_override("font_color", MenuStyle.ACCENT)
	col.add_child(mode_head)
	var mode_row := HBoxContainer.new(); mode_row.add_theme_constant_override("separation", 8)
	_story_btn = Button.new(); _story_btn.text = "Story"; _story_btn.toggle_mode = true; _story_btn.custom_minimum_size = Vector2(0, 38)
	_sandbox_btn = Button.new(); _sandbox_btn.text = "Sandbox"; _sandbox_btn.toggle_mode = true; _sandbox_btn.custom_minimum_size = Vector2(0, 38)
	_story_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sandbox_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_story_btn.pressed.connect(func(): _set_mode(true))
	_sandbox_btn.pressed.connect(func(): _set_mode(false))
	mode_row.add_child(_story_btn); mode_row.add_child(_sandbox_btn)
	col.add_child(mode_row)
	_mode_desc = Label.new()
	_mode_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mode_desc.add_theme_font_size_override("font_size", 12)
	_mode_desc.add_theme_color_override("font_color", MenuStyle.MUTED)
	col.add_child(_mode_desc)
	var fly := Button.new(); fly.text = "Fly"; fly.theme_type_variation = "Primary"; fly.custom_minimum_size = Vector2(0, 52)
	fly.add_theme_font_size_override("font_size", 26)
	fly.pressed.connect(func(): fly_pressed.emit())
	col.add_child(fly)
	_drone_label = Label.new(); _drone_label.text = drone_name
	_drone_label.add_theme_font_size_override("font_size", 16); _drone_label.add_theme_color_override("font_color", MenuStyle.MUTED)
	col.add_child(_drone_label)
	for item in [["Choose a drone", drone_pressed], ["Settings", settings_pressed], ["Controls", controls_pressed]]:
		var b := Button.new(); b.text = item[0]; b.theme_type_variation = "Ghost"; b.custom_minimum_size = Vector2(0, 40)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var sig: Signal = item[1]
		b.pressed.connect(func(): sig.emit())
		col.add_child(b)
	_story_note = Label.new()
	_story_note.text = "STORY MODE  ·  the valley owns the weather and the clock. The story, the jobs and the investigation set the conditions."
	_story_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_note.add_theme_font_size_override("font_size", 12)
	_story_note.add_theme_color_override("font_color", MenuStyle.ACCENT)
	col.add_child(_story_note)
	# quick looks only exist in sandbox
	_looks_section = VBoxContainer.new(); _looks_section.add_theme_constant_override("separation", 6)
	col.add_child(_looks_section)
	var lh := Label.new(); lh.text = "SANDBOX TIME AND WEATHER"; lh.add_theme_font_size_override("font_size", 11); lh.add_theme_color_override("font_color", MenuStyle.ACCENT)
	_looks_section.add_child(lh)
	var flow := HFlowContainer.new(); flow.add_theme_constant_override("h_separation", 6); flow.add_theme_constant_override("v_separation", 6)
	_looks_section.add_child(flow)
	for i in LOOKS.size():
		var b := Button.new(); b.text = LOOKS[i]["name"]; b.toggle_mode = true; b.custom_minimum_size = Vector2(0, 36)
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(func():
			for j in _look_btns.size(): _look_btns[j].set_pressed_no_signal(j == i)
			look_chosen.emit(float(LOOKS[i]["hour"]), int(LOOKS[i]["sky"])))
		flow.add_child(b); _look_btns.append(b)
	var q := Button.new(); q.text = "Quit"; q.theme_type_variation = "Danger"; q.custom_minimum_size = Vector2(0, 40)
	q.alignment = HORIZONTAL_ALIGNMENT_LEFT
	q.pressed.connect(func(): quit_pressed.emit())
	col.add_child(q)
	var hint := Label.new(); hint.text = "Esc opens the menu while you fly."
	hint.add_theme_font_size_override("font_size", 14); hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	col.add_child(hint)
	_apply_mode()

func _set_mode(story: bool) -> void:
	_story_mode = story
	_apply_mode()
	mode_chosen.emit(story)

func set_story_mode(story: bool) -> void:
	_story_mode = story
	_apply_mode()

func _apply_mode() -> void:
	if _story_btn == null:
		return
	_story_btn.set_pressed_no_signal(_story_mode)
	_sandbox_btn.set_pressed_no_signal(not _story_mode)
	_story_btn.add_theme_color_override("font_color", MenuStyle.ON_ACCENT if _story_mode else MenuStyle.TEXT)
	_sandbox_btn.add_theme_color_override("font_color", MenuStyle.ON_ACCENT if not _story_mode else MenuStyle.TEXT)
	if _mode_desc != null:
		_mode_desc.text = "Story: the investigation, the jobs and the festival. Weather, time and storms belong to the valley." if _story_mode else "Sandbox: the old free-play powers. Time, weather, storms, events and quick looks are yours."
	if _story_note != null:
		_story_note.visible = _story_mode
	if _looks_section != null:
		_looks_section.visible = not _story_mode
	if _drone_label != null:
		_drone_label.text = _drone_label.text

func set_drone_name(n: String) -> void:
	if _drone_label: _drone_label.text = n

## Where the camera is while the welcome screen is up: a slow circle around the drone, a little above it, looking at it.
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

class_name Ending
extends CanvasLayer
## The end of the story (session B, UI pass 2): not a hard cut to black, but the lens slowly losing the valley.
##
## The last flight ends when Wren is found. The picture first goes soft and warm through full-screen post processing and
## an even softer focus, then a quiet A24-style card arrives over the blurred world: THE LAKE CAR, a few lines and
## THE END. After the card the world comes back and the player is on foot in it: move the mouse to look, WASD to walk,
## click the drone to fly again.

signal began
signal card_finished

const BLUR_TIME := 8.0
const CARD_AT := 7.0
const FREE_AT := 22.0

var started := false
var free := false
var blur := 0.0
var wash := 0.0
var _t := 0.0
var _post: ColorRect
var _veil: ColorRect
var _card: Control
var _title: Label
var _sub: Label
var _epi: Label
var _end: Label
var _note: Label
var _prompt: Control
var _drone_hint: Label
var _free_emitted := false

func setup(_j: Jobs = null) -> void:
	layer = 60
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_post = ColorRect.new()
	_post.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post.color = Color.WHITE
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/shaders/end_wash.gdshader")
	mat.set_shader_parameter("screen_tex", null)
	_post.material = mat
	add_child(_post)
	_veil = ColorRect.new()
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(0.025, 0.022, 0.018, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	_build_card()
	_build_prompt()

func _build_card() -> void:
	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	add_child(_card)
	var top_bar := ColorRect.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 52.0
	top_bar.color = Color(0.015, 0.014, 0.012, 0.92)
	_card.add_child(top_bar)
	var bottom_bar := ColorRect.new()
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_top = -52.0
	bottom_bar.color = Color(0.015, 0.014, 0.012, 0.92)
	_card.add_child(bottom_bar)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(760, 0)
	col.add_theme_constant_override("separation", 0)
	center.add_child(col)
	var kicker := _label("A HALLOWAY VALLEY STORY", 9, Color(0.66, 0.62, 0.53))
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(kicker)
	_title = _label("T H E   L A K E   C A R", 44, Color(0.94, 0.90, 0.79))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	_sub = _label("AFTER THE STORM", 11, Color(0.58, 0.60, 0.56))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_sub)
	col.add_child(_gap(30))
	_epi = _label("Some lights are not the storm.\n\nSome stories arrive forty years late.\n\nThe valley keeps its weather. The cabin keeps its light.", 17, Color(0.78, 0.76, 0.68))
	_epi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_epi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_epi)
	col.add_child(_gap(38))
	_end = _label("T H E   E N D", 25, Color(0.88, 0.76, 0.54))
	_end.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_end)
	col.add_child(_gap(16))
	var note := _label("Thank you for flying the valley.", 12, Color(0.52, 0.54, 0.50))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note = note
	col.add_child(note)
	_card.modulate.a = 0.0
	_note.modulate.a = 0.0

func _build_prompt() -> void:
	_prompt = Control.new()
	_prompt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	add_child(_prompt)
	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -86.0
	bottom.offset_bottom = -22.0
	bottom.add_theme_stylebox_override("panel", UniverseUI.box(Color(0.03, 0.035, 0.03, 0.86), 14, UniverseUI.LINE_STRONG, 1, 22.0, 10.0))
	_prompt.add_child(bottom)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 6)
	bottom.add_child(m)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	m.add_child(row)
	var hint := _label("MOUSE   look around        WASD   walk        CLICK THE DRONE   fly again", 11, UniverseUI.CREAM_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hint)
	_drone_hint = _label("◆\nDRONE", 15, UniverseUI.AMBER)
	_drone_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drone_hint.visible = false
	_drone_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_child(_drone_hint)

func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func play() -> void:
	if started:
		return
	started = true
	free = false
	_free_emitted = false
	_t = 0.0
	blur = 0.0
	wash = 0.0
	visible = true
	_post.visible = true
	_veil.color.a = 0.0
	_card.visible = false
	_card.modulate.a = 0.0
	_note.modulate.a = 0.0
	_prompt.visible = false
	began.emit()

func _process(delta: float) -> void:
	if not started or free:
		return
	_t += delta
	blur = smoothstep(0.0, BLUR_TIME, _t)
	wash = smoothstep(1.0, BLUR_TIME + 2.0, _t)
	var mat := _post.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("blur_amount", blur)
		mat.set_shader_parameter("wash", wash)
	if _t > CARD_AT:
		_card.visible = true
		_veil.color.a = smoothstep(CARD_AT, CARD_AT + 3.2, _t) * 0.94
		_card.modulate.a = smoothstep(CARD_AT, CARD_AT + 2.2, _t)
		_title.modulate.a = smoothstep(CARD_AT + 1.0, CARD_AT + 4.0, _t)
		_sub.modulate.a = smoothstep(CARD_AT + 2.0, CARD_AT + 5.0, _t)
		_epi.modulate.a = smoothstep(CARD_AT + 4.5, CARD_AT + 8.0, _t)
		_end.modulate.a = smoothstep(CARD_AT + 9.5, CARD_AT + 11.5, _t)
		_note.modulate.a = smoothstep(CARD_AT + 11.0, CARD_AT + 12.5, _t)
	if _t >= FREE_AT and not _free_emitted:
		_free_emitted = true
		free = true
		_card.visible = false
		_post.visible = false
		_veil.color.a = 0.0
		_prompt.visible = true
		card_finished.emit()

func debug_time(t: float) -> void:
	_t = t

## The player is walking in the world: keep a small marker over the drone so the click target is obvious.
func set_drone_hint(pos: Vector2, on_screen: bool) -> void:
	if _drone_hint == null:
		return
	_drone_hint.visible = on_screen
	_drone_hint.position = pos - Vector2(34.0, 12.0)
	_drone_hint.size = Vector2(68.0, 48.0)

func hide_prompt() -> void:
	if _prompt != null:
		_prompt.visible = false
	if _drone_hint != null:
		_drone_hint.visible = false
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	# The ending no longer quits on Escape. Escape closes the hint, and the player can keep walking or return to the
	# drone. The main scene owns the free walk input so the camera and the drone stay in one place.
	if free and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		hide_prompt()

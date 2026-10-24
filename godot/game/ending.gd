class_name Ending
extends CanvasLayer
## The end of the story (session B): the screen fades, the credits roll, and the game is over.
##
## When the finale finds Wren alive, the flight stops and this layer takes the screen. It fades from the storm to black,
## then rolls a short epilogue and the credits over the frozen view. There is no timer and no failure state; the
## only input is Escape to leave the game.

const FADE := 1.2
const ROLL_START := 1.8
const ROLL_SPEED := 46.0

var started := false
var _t := 0.0
var _black: ColorRect
var _scroll: ScrollContainer
var _content: VBoxContainer
var _end: Label
var _jobs: Jobs

func setup(j: Jobs) -> void:
	_jobs = j
	layer = 60
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_black = ColorRect.new()
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.color = Color(0.0, 0.0, 0.0, 1.0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	_scroll.add_child(_content)
	_build_content()
	_end = Label.new()
	_end.text = "THE END"
	_end.add_theme_font_size_override("font_size", 44)
	_end.add_theme_color_override("font_color", Color(0.92, 0.88, 0.74))
	_end.position = Vector2(500, 610)
	_end.visible = false
	add_child(_end)

func _build_content() -> void:
	var top := Control.new()
	top.custom_minimum_size = Vector2(0, 260)
	_content.add_child(top)
	_content.add_child(_line("The Lake Car", 42, Color(0.95, 0.93, 0.86)))
	_content.add_child(_line("Halloway, after the storm", 18, Color(0.72, 0.78, 0.82)))
	_content.add_child(_gap(28))
	_content.add_child(_line("Wren was found alive in the treeline east of the old cabin, cold and turned around and very glad to see a drone.", 18, Color(0.86, 0.87, 0.88)))
	_content.add_child(_line("The cruiser outside the cabin belonged to Constable Ada Rennick. She died there in the spring of 1984, answering a call about a missing woman on the lake road. A pilot had reported lights in the storm. The officer went out that evening and never came home.", 18, Color(0.78, 0.80, 0.82)))
	_content.add_child(_line("The missing woman was Anne Voss, who had gone for a drive on the stormy lake road. Her car was never found. Ellis Voss kept the old blue estate at the lake and the festival bus in the garage, and waited forty years for someone to ask the right questions.", 18, Color(0.78, 0.80, 0.82)))
	_content.add_child(_line("The lake gave Anne back the following spring. Ellis put an empty seat on the festival bus and drove the parade route one more time.", 18, Color(0.78, 0.80, 0.82)))
	_content.add_child(_gap(34))
	_content.add_child(_line("Thank you for flying.", 26, Color(0.94, 0.90, 0.78)))
	_content.add_child(_gap(30))
	var followers := _jobs.followers() if _jobs != null else 0
	var views := _jobs.views() if _jobs != null else 0
	var money := _jobs.money() if _jobs != null else 0
	var videos := _jobs.videos().size() if _jobs != null else 0
	_content.add_child(_line("%d followers   ·   %d views   ·   %d videos   ·   %d money" % [followers, views, videos, money], 17, Color(0.72, 0.80, 0.82)))
	_content.add_child(_gap(34))
	_content.add_child(_line("CREDITS", 22, Color(0.90, 0.86, 0.72)))
	_content.add_child(_line("DroneBudz crew: Maya, Alex, Sam, Tom, Riley, Jo", 16, Color(0.74, 0.76, 0.78)))
	_content.add_child(_line("Halloway: Constable Ada Rennick, Ellis and Anne Voss, Wren, Biscuit", 16, Color(0.74, 0.76, 0.78)))
	_content.add_child(_line("The valley, the weather, and the drone", 16, Color(0.74, 0.76, 0.78)))
	_content.add_child(_line("Thermal camera technology, fitted by Alex", 16, Color(0.66, 0.70, 0.72)))
	_content.add_child(_line("Built by session B, with the AeroSim project", 16, Color(0.66, 0.70, 0.72)))
	_content.add_child(_gap(80))
	_content.add_child(_line("Press Escape to leave the valley", 15, Color(0.58, 0.62, 0.64)))
	_content.add_child(_gap(160))

func _line(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_t = 0.0
	visible = true
	_black.color = Color(0.0, 0.0, 0.0, 0.0)
	_end.visible = false

func _process(delta: float) -> void:
	if not started:
		return
	_t += delta
	_black.color.a = clampf(_t / FADE, 0.0, 1.0)
	if _t > ROLL_START:
		_scroll.scroll_vertical = int((_t - ROLL_START) * ROLL_SPEED)
	if _t > 16.0:
		_end.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_tree().quit()

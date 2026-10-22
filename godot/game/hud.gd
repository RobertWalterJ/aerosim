class_name Hud
extends CanvasLayer
## On-screen display and the pause window. The flight screen keeps only what you need mid-flight (mode, camera,
## the readout, and Pause). Everything else lives in the pause window: Fly, Drone, Weather and Display tabs.
## Resume and "Hold to peek" stay at the bottom of every tab.

signal pause_changed(paused: bool)
signal reset_requested
signal drone_picked(id: String)
signal mode_changed(mode: String)
signal camera_changed(chase: bool)
signal weather_changed(w: Dictionary)
signal gimbal_changed(pitch_rad: float)

const WEATHER_FILE := "user://weather.cfg"
const DEFAULT_WEATHER := {"wind": 1.0, "gust": 0.45, "from": 250.0, "sun": 14.0, "snow": 0}
const PRESETS := [["Still", 0.0, 0.0], ["Calm", 1.0, 0.45], ["Light", 3.0, 0.65], ["Breezy", 5.0, 0.85], ["Strong", 7.5, 1.0]]
const COMPASS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

var weather := DEFAULT_WEATHER.duplicate()
var paused := false
var mode := "N"
var chase := false
var airframe_id := "mini"

var _root: Control
var _readout: Label
var _crash_box: VBoxContainer
var _crash_label: Label
var _gimbal: VSlider
var _panel: PanelContainer
var _menu_dim: ColorRect
var _tabs: TabContainer
var _mode_btn: Button
var _cam_btn: Button
var _refreshers: Array[Callable] = []
var _drone_buttons := {}
var _sliders := {}
var _slider_labels := {}

func _ready() -> void:
	layer = 10
	_load_weather()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)
	_build_flight_hud()
	_build_pause_menu()
	_sync()

func _safe_margin() -> Vector4:
	var r := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if r.size.x <= 0 or win.x <= 0: return Vector4(10, 10, 10, 10)
	return Vector4(maxf(10, r.position.x), maxf(10, r.position.y), 10, 10)

# ------------------------------------------------------------------ look
func _box(bg: Color, border: Color = Color(0.86, 1, 0.94, 0.35), radius: int = 12, margin: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg; sb.border_color = border; sb.set_border_width_all(1); sb.set_corner_radius_all(radius); sb.set_content_margin_all(margin)
	return sb

func _grabber(radius: int, col: Color) -> ImageTexture:
	var n := radius * 2 + 2
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length()
			var a := clampf(radius + 0.5 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)

func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 22
	var idle := Color(0.14, 0.24, 0.27, 0.92)
	th.set_stylebox("normal", "Button", _box(idle))
	th.set_stylebox("hover", "Button", _box(Color(0.20, 0.33, 0.37, 0.95)))
	th.set_stylebox("pressed", "Button", _box(Color(0.10, 0.46, 0.34, 0.97), Color.WHITE))
	th.set_stylebox("hover_pressed", "Button", _box(Color(0.13, 0.52, 0.39, 0.97), Color.WHITE))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		th.set_color(c, "Button", Color.WHITE)
	# sliders: a thick track and a big round handle, easy to hit with a thumb
	var track := _box(Color(0.30, 0.40, 0.42, 0.9), Color(0, 0, 0, 0), 6, 0); track.content_margin_top = 5; track.content_margin_bottom = 5
	var fill := _box(Color(0.30, 0.85, 0.65, 0.95), Color(0, 0, 0, 0), 6, 0); fill.content_margin_top = 5; fill.content_margin_bottom = 5
	for t in ["HSlider", "VSlider"]:
		th.set_stylebox("slider", t, track)
		th.set_stylebox("grabber_area", t, fill)
		th.set_stylebox("grabber_area_highlight", t, fill)
		th.set_icon("grabber", t, _grabber(18, Color(0.95, 1, 0.97)))
		th.set_icon("grabber_highlight", t, _grabber(20, Color.WHITE))
		th.set_icon("grabber_disabled", t, _grabber(18, Color(0.6, 0.6, 0.6)))
	th.set_constant("center_grabber", "HSlider", 1)
	# tabs
	var tab_on := _box(Color(0.10, 0.46, 0.34, 0.97), Color.WHITE, 10, 14); tab_on.content_margin_left = 26; tab_on.content_margin_right = 26
	var tab_off := _box(idle, Color(0.86, 1, 0.94, 0.25), 10, 14); tab_off.content_margin_left = 26; tab_off.content_margin_right = 26
	th.set_stylebox("tab_selected", "TabContainer", tab_on)
	th.set_stylebox("tab_unselected", "TabContainer", tab_off)
	th.set_stylebox("tab_hovered", "TabContainer", _box(Color(0.20, 0.33, 0.37, 0.95), Color(0.86, 1, 0.94, 0.4), 10, 14))
	th.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	th.set_font_size("font_size", "TabContainer", 24)
	for c in ["font_selected_color", "font_unselected_color", "font_hovered_color"]:
		th.set_color(c, "TabContainer", Color.WHITE)
	th.set_constant("side_margin", "TabContainer", 4)
	return th

# ------------------------------------------------------------------ flight screen
func _build_flight_hud() -> void:
	var m := _safe_margin()
	_readout = Label.new()
	_readout.position = Vector2(m.x + 6, m.y + 4)
	_readout.add_theme_font_size_override("font_size", 20)
	_readout.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_readout.add_theme_constant_override("outline_size", 6)
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_readout)

	var pause_btn := Button.new()
	pause_btn.text = "II  PAUSE"
	pause_btn.custom_minimum_size = Vector2(150, 56)
	pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.position = Vector2(-160 - m.z, m.y)
	pause_btn.pressed.connect(func(): set_paused(true))
	_root.add_child(pause_btn)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	row.position = Vector2(-150, m.y)
	row.add_theme_constant_override("separation", 8)
	_root.add_child(row)
	_mode_btn = Button.new(); _mode_btn.custom_minimum_size = Vector2(140, 52)
	_mode_btn.pressed.connect(cycle_mode)
	row.add_child(_mode_btn)
	_cam_btn = Button.new(); _cam_btn.custom_minimum_size = Vector2(140, 52)
	_cam_btn.pressed.connect(func(): set_chase(not chase))
	row.add_child(_cam_btn)

	_gimbal = VSlider.new()
	_gimbal.min_value = -90.0; _gimbal.max_value = 20.0; _gimbal.step = 1.0; _gimbal.value = -20.0
	_gimbal.custom_minimum_size = Vector2(56, 260)
	_gimbal.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_gimbal.position = Vector2(-70 - m.z, -130)
	_gimbal.value_changed.connect(func(v: float): gimbal_changed.emit(deg_to_rad(v)))
	_root.add_child(_gimbal)

	_crash_box = VBoxContainer.new()
	_crash_box.set_anchors_preset(Control.PRESET_CENTER)
	_crash_box.position = Vector2(-150, -10)
	_crash_box.add_theme_constant_override("separation", 10)
	_crash_box.visible = false
	_root.add_child(_crash_box)
	_crash_label = Label.new()
	_crash_label.add_theme_font_size_override("font_size", 30)
	_crash_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	_crash_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_crash_label.add_theme_constant_override("outline_size", 8)
	_crash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crash_label.custom_minimum_size = Vector2(300, 0)
	_crash_box.add_child(_crash_label)
	var rb := Button.new(); rb.text = "RESET"; rb.custom_minimum_size = Vector2(300, 72)
	rb.add_theme_font_size_override("font_size", 30)
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.78, 0.16, 0.16, 0.9); sb.set_corner_radius_all(14); sb.set_border_width_all(2); sb.border_color = Color.WHITE
	rb.add_theme_stylebox_override("normal", sb); rb.add_theme_stylebox_override("hover", sb); rb.add_theme_stylebox_override("pressed", sb)
	rb.pressed.connect(func(): reset_requested.emit())
	_crash_box.add_child(rb)

func set_readout(text: String) -> void:
	_readout.text = text

func show_crash(reason: String) -> void:
	_crash_box.visible = reason != ""
	_crash_label.text = reason.to_upper()

func show_gimbal(on: bool) -> void:
	_gimbal.visible = on

func set_gimbal_value(rad: float) -> void:
	_gimbal.set_value_no_signal(rad_to_deg(rad))

func cycle_mode() -> void:
	set_mode({"N": "S", "S": "M", "M": "N"}[mode])

func set_mode(m: String) -> void:
	mode = m; mode_changed.emit(m); _sync()

func set_chase(on: bool) -> void:
	chase = on; camera_changed.emit(on); _sync()

# ------------------------------------------------------------------ pause window
func _build_pause_menu() -> void:
	_menu_dim = ColorRect.new()
	_menu_dim.color = Color(0.02, 0.03, 0.04, 0.6)
	_menu_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_dim.visible = false
	_root.add_child(_menu_dim)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.anchor_left = 0.08; _panel.anchor_right = 0.92; _panel.anchor_top = 0.05; _panel.anchor_bottom = 0.95
	_panel.offset_left = 0; _panel.offset_right = 0; _panel.offset_top = 0; _panel.offset_bottom = 0
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.05, 0.09, 0.10, 0.97); sb.set_corner_radius_all(16)
	sb.set_border_width_all(1); sb.border_color = Color(0.86, 1, 0.94, 0.4); sb.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", sb)
	_menu_dim.add_child(_panel)
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 10)
	_panel.add_child(col)
	_tabs = TabContainer.new(); _tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_tabs)
	_build_fly_tab(); _build_drone_tab(); _build_weather_tab(); _build_display_tab()
	var foot := HBoxContainer.new(); foot.add_theme_constant_override("separation", 12)
	col.add_child(foot)
	var peek := Button.new(); peek.text = "Hold to peek"; peek.custom_minimum_size = Vector2(220, 56)
	peek.button_down.connect(func(): _tabs.modulate.a = 0.05; _panel.self_modulate.a = 0.0; _menu_dim.color.a = 0.0)
	peek.button_up.connect(func(): _tabs.modulate.a = 1.0; _panel.self_modulate.a = 1.0; _menu_dim.color.a = 0.6)
	foot.add_child(peek)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; foot.add_child(sp)
	var go := Button.new(); go.text = "Resume"; go.custom_minimum_size = Vector2(220, 56)
	go.pressed.connect(func(): set_paused(false))
	foot.add_child(go)

func _page(title: String) -> VBoxContainer:
	var sc := ScrollContainer.new(); sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(sc)
	var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	sc.add_child(v)
	return v

func _heading(parent: Control, text: String) -> void:
	var l := Label.new(); l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 16); l.add_theme_color_override("font_color", Color(0.6, 1, 0.85))
	parent.add_child(l)

func _choice(parent: Control, title: String, options: Array, get_i: Callable, set_i: Callable) -> void:
	_heading(parent, title)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var btns: Array[Button] = []
	for i in options.size():
		var b := Button.new(); b.text = options[i]; b.toggle_mode = true; b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): set_i.call(i); _sync())
		row.add_child(b); btns.append(b)
	_refreshers.append(func():
		for i in btns.size(): btns[i].set_pressed_no_signal(i == int(get_i.call())))

func _action(parent: Control, text: String, fn: Callable) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(0, 56); b.pressed.connect(fn)
	parent.add_child(b); return b

func _build_fly_tab() -> void:
	var p := _page("Fly")
	_choice(p, "Flight mode", ["Normal", "Sport", "Manual"], func(): return ["N", "S", "M"].find(mode), func(i): set_mode(["N", "S", "M"][i]))
	_choice(p, "Camera view", ["First person", "Chase"], func(): return 1 if chase else 0, func(i): set_chase(i == 1))
	_heading(p, "Actions")
	_action(p, "Reset drone to the start", func(): reset_requested.emit(); set_paused(false))

func _build_drone_tab() -> void:
	var p := _page("Drone")
	_heading(p, "Choose a drone. It returns to the start.")
	for id in Airframes.IDS:
		var af := Airframes.make(id)
		var b := Button.new(); b.toggle_mode = true; b.custom_minimum_size = Vector2(0, 80)
		b.text = "%s\n%s" % [af["name"], af["blurb"]]; b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 20)
		b.clip_text = false; b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(func(): if id != airframe_id: drone_picked.emit(id); set_paused(false))
		p.add_child(b); _drone_buttons[id] = b

func _slider(parent: Control, key: String, title: String, lo: float, hi: float, step: float) -> void:
	var row := HBoxContainer.new(); parent.add_child(row)
	var l := Label.new(); l.text = title; l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(l)
	var v := Label.new(); v.add_theme_color_override("font_color", Color.WHITE); row.add_child(v)
	var s := HSlider.new(); s.min_value = lo; s.max_value = hi; s.step = step; s.custom_minimum_size = Vector2(0, 44)
	s.value = float(weather[key])
	s.value_changed.connect(func(x: float): weather[key] = x; _weather_edited())
	parent.add_child(s); _sliders[key] = s; _slider_labels[key] = v

func _build_weather_tab() -> void:
	var p := _page("Weather")
	_heading(p, "Wind")
	var seg := HBoxContainer.new(); seg.add_theme_constant_override("separation", 8); p.add_child(seg)
	for pr in PRESETS:
		var b := Button.new(); b.text = pr[0]; b.custom_minimum_size = Vector2(0, 56); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): weather["wind"] = pr[1]; weather["gust"] = pr[2]; _weather_edited())
		seg.add_child(b)
	_slider(p, "wind", "Wind speed", 0.0, 10.0, 0.1)
	_slider(p, "gust", "Gusts", 0.0, 1.0, 0.01)
	_slider(p, "from", "Wind comes from", 0.0, 359.0, 1.0)
	_heading(p, "Time of day")
	_slider(p, "sun", "Sun height", 4.0, 40.0, 1.0)
	_choice(p, "Precipitation", ["Clear", "Light snow", "Heavy snow"], func(): return int(weather["snow"]), func(i): weather["snow"] = i; _weather_edited())
	_action(p, "Reset weather", func(): weather = DEFAULT_WEATHER.duplicate(); _weather_edited())

func _build_display_tab() -> void:
	var p := _page("Display")
	_choice(p, "Frame rate", ["60 fps", "30 fps"], func(): return 0 if Engine.max_fps in [0, 60] else 1, func(i): Engine.max_fps = 60 if i == 0 else 30)
	_heading(p, "Screen")
	_action(p, "Full screen", func():
		var m := DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if m == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN))
	_action(p, "Quit", func(): get_tree().quit())

func _weather_edited() -> void:
	_sync(); weather_changed.emit(weather); _save_weather()

func _sync() -> void:
	if _mode_btn == null: return
	_mode_btn.text = "MODE " + mode
	_cam_btn.text = "CHASE" if chase else "FPV"
	for f in _refreshers: f.call()
	for id in _drone_buttons: _drone_buttons[id].set_pressed_no_signal(id == airframe_id)
	for k in _sliders:
		_sliders[k].set_value_no_signal(float(weather[k]))
		var v := float(weather[k])
		match k:
			"wind": _slider_labels[k].text = "%.1f m/s" % v
			"gust": _slider_labels[k].text = "Steady" if v < 0.34 else ("Some gusts" if v < 0.7 else "Gusty")
			"from": _slider_labels[k].text = "%s (%d°)" % [COMPASS[int(round(v / 45.0)) % 8], int(v)]
			"sun": _slider_labels[k].text = "Sunset glow" if v < 8 else ("Late afternoon" if v < 18 else ("Afternoon" if v < 30 else "Midday"))

func set_paused(on: bool) -> void:
	paused = on
	_menu_dim.visible = on
	if on: _sync()
	pause_changed.emit(on)

func set_airframe(id: String) -> void:
	airframe_id = id; _sync()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		set_paused(not paused)
		get_viewport().set_input_as_handled()

func _load_weather() -> void:
	var cf := ConfigFile.new()
	if cf.load(WEATHER_FILE) == OK:
		for k in DEFAULT_WEATHER:
			var v = cf.get_value("weather", k, DEFAULT_WEATHER[k])
			if v is float or v is int: weather[k] = v

func _save_weather() -> void:
	var cf := ConfigFile.new()
	for k in weather: cf.set_value("weather", k, weather[k])
	cf.save(WEATHER_FILE)

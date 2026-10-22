class_name Hud
extends CanvasLayer
## The flight app: what a phone clipped into a drone remote shows. The live video fills the screen with the drone's
## data overlay (osd.gd) on top. Round glass buttons sit at the edges the way they do in a drone app: back and settings
## in the top bar, flight mode, auto takeoff or landing, return to home and the camera view down the left, the shutter
## and photo or video switch on the right, and a map thumbnail in the corner. Notices appear under the top bar.
## Settings opens a full-screen phone-style page (Flight, Drone, Weather, Camera, Display) and pauses the flight.

signal pause_changed(paused: bool)
signal reset_requested
signal drone_picked(id: String)
signal mode_changed(mode: String)
signal camera_changed(chase: bool)
signal weather_changed(w: Dictionary)
signal gimbal_changed(pitch_rad: float)
signal lens_changed(lens: String)
signal photo_requested
signal takeoff_land_requested
signal rth_requested
signal ev_changed(ev: float)
signal bloom_changed(on: bool)
signal noise_changed(amount: float)
signal link_changed(on: bool)
signal osd_changed(on: bool)
signal sound_changed(on: bool)
signal listening_changed(i: int)
signal volume_changed(v: float)
signal light_changed(on: bool)
signal grass_changed(on: bool)

const WEATHER_FILE := "user://weather.cfg"
const DEFAULT_WEATHER := {"wind": 1.0, "gust": 0.45, "from": 250.0, "sun": 14.0, "sky": 0, "intensity": 0.6, "clock_mode": 0, "clock_speed": 0, "date": 0, "hour": 16.0}
const PRESETS := [["Still", 0.0, 0.0], ["Calm", 1.0, 0.45], ["Light", 3.0, 0.65], ["Breezy", 5.0, 0.85], ["Strong", 7.5, 1.0]]
const COMPASS := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
const TABS := ["Flight", "Drone", "Weather", "Camera", "Display", "Controls"]

var weather := DEFAULT_WEATHER.duplicate()
var paused := false
var mode := "N"
var chase := false
var airframe_id := "mini"
var lens := "standard"
var ev_comp := 0.0
var bloom := true
var noise := 1.0
var link_fx := true
var osd_on := true
var video_mode := false
var airborne := false
var rth_active := false
var light_on := false
var fx_cloud := true
var fx_trees := true
var sound_on := true
var listening := 2
var sound_vol := 0.8

var minimap: MiniMap

var _root: Control
var _back_btn: RoundButton
var _gear_btn: RoundButton
var _mode_btn: RoundButton
var _tl_btn: RoundButton
var _rth_btn: RoundButton
var _view_btn: RoundButton
var _pv_btn: RoundButton
var _shutter: ShutterButton
var _gimbal: VSlider
var _toast: Label
var _toast_tween: Tween
var _flash: ColorRect
var _crash_box: VBoxContainer
var _crash_label: Label
var _menu_dim: ColorRect
var _panel: PanelContainer
var _tabs: TabContainer
var _tab_btns: Array[Button] = []
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
	_build_settings()
	_sync()

# ------------------------------------------------------------------ look
func _box(bg: Color, border: Color = Color(1, 1, 1, 0.22), radius: int = 12, margin: int = 12) -> StyleBoxFlat:
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
	var idle := Color(0.13, 0.15, 0.19, 0.96)
	var blue := Color(0.17, 0.42, 0.78, 0.98)
	th.set_stylebox("normal", "Button", _box(idle))
	th.set_stylebox("hover", "Button", _box(Color(0.19, 0.22, 0.28, 0.98)))
	th.set_stylebox("pressed", "Button", _box(blue, Color(1, 1, 1, 0.7)))
	th.set_stylebox("hover_pressed", "Button", _box(Color(0.2, 0.47, 0.85, 0.98), Color(1, 1, 1, 0.8)))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		th.set_color(c, "Button", Color.WHITE)
	var track := _box(Color(0.30, 0.33, 0.40, 0.9), Color(0, 0, 0, 0), 6, 0); track.content_margin_top = 4; track.content_margin_bottom = 4
	var fill := _box(Color(0.30, 0.62, 1.0, 0.95), Color(0, 0, 0, 0), 6, 0); fill.content_margin_top = 4; fill.content_margin_bottom = 4
	for t in ["HSlider", "VSlider"]:
		th.set_stylebox("slider", t, track)
		th.set_stylebox("grabber_area", t, fill)
		th.set_stylebox("grabber_area_highlight", t, fill)
		th.set_icon("grabber", t, _grabber(16, Color(1, 1, 1)))
		th.set_icon("grabber_highlight", t, _grabber(18, Color.WHITE))
		th.set_icon("grabber_disabled", t, _grabber(16, Color(0.6, 0.6, 0.6)))
	th.set_constant("center_grabber", "HSlider", 1)
	th.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	th.set_color("font_color", "Label", Color(0.93, 0.95, 0.98))
	return th

# ------------------------------------------------------------------ flight screen
func _build_flight_hud() -> void:
	_back_btn = RoundButton.new("back", 40); _back_btn.pressed.connect(func(): set_paused(true)); _root.add_child(_back_btn)
	_gear_btn = RoundButton.new("gear", 40); _gear_btn.pressed.connect(func(): set_paused(true)); _root.add_child(_gear_btn)
	_mode_btn = RoundButton.new("N", 52); _mode_btn.label = "Mode"; _mode_btn.pressed.connect(cycle_mode); _root.add_child(_mode_btn)
	_tl_btn = RoundButton.new("takeoff", 52); _tl_btn.label = "Takeoff"; _tl_btn.pressed.connect(func(): takeoff_land_requested.emit()); _root.add_child(_tl_btn)
	_rth_btn = RoundButton.new("home", 52); _rth_btn.label = "Return"; _rth_btn.pressed.connect(func(): rth_requested.emit()); _root.add_child(_rth_btn)
	_view_btn = RoundButton.new("eye", 52); _view_btn.label = "View"; _view_btn.pressed.connect(func(): set_chase(not chase)); _root.add_child(_view_btn)
	_pv_btn = RoundButton.new("camera", 44); _pv_btn.pressed.connect(toggle_photo_video); _root.add_child(_pv_btn)
	_shutter = ShutterButton.new(80); _shutter.pressed.connect(func(): photo_requested.emit()); _root.add_child(_shutter)
	minimap = MiniMap.new(150); _root.add_child(minimap)
	# the gimbal: the data overlay draws the scale; this invisible slider sits over it to take the touch
	_gimbal = VSlider.new()
	_gimbal.min_value = -90.0; _gimbal.max_value = 20.0; _gimbal.step = 1.0; _gimbal.value = -20.0
	_gimbal.modulate = Color(1, 1, 1, 0.01)
	_gimbal.value_changed.connect(func(v: float): gimbal_changed.emit(deg_to_rad(v)))
	_root.add_child(_gimbal)
	# notices under the top bar
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.add_theme_color_override("font_color", Color.WHITE)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	_root.add_child(_toast)
	# photo flash
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)
	# crash notice with a big reset
	_crash_box = VBoxContainer.new()
	_crash_box.add_theme_constant_override("separation", 10)
	_crash_box.visible = false
	_root.add_child(_crash_box)
	_crash_label = Label.new()
	_crash_label.add_theme_font_size_override("font_size", 30)
	_crash_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	_crash_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_crash_label.add_theme_constant_override("outline_size", 8)
	_crash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crash_label.custom_minimum_size = Vector2(320, 0)
	_crash_box.add_child(_crash_label)
	var rb := Button.new(); rb.text = "RESET"; rb.custom_minimum_size = Vector2(320, 72)
	rb.add_theme_font_size_override("font_size", 30)
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.78, 0.16, 0.16, 0.9); sb.set_corner_radius_all(14); sb.set_border_width_all(2); sb.border_color = Color.WHITE
	rb.add_theme_stylebox_override("normal", sb); rb.add_theme_stylebox_override("hover", sb); rb.add_theme_stylebox_override("pressed", sb)
	rb.pressed.connect(func(): reset_requested.emit())
	_crash_box.add_child(rb)

func _place(c: Control, pos: Vector2, d: float) -> void:
	c.position = pos
	if c.size != Vector2(d, d):
		c.custom_minimum_size = Vector2(d, d)
		c.size = Vector2(d, d)
		c.queue_redraw()

## Place everything around the video frame (called each frame with its rectangle).
func layout_for(frame: Rect2) -> void:
	var u := maxf(0.6, minf(frame.size.x / 1280.0, frame.size.y / 720.0))
	var vp := get_viewport().get_visible_rect().size
	var m := 14.0 * u
	var bar := 36.0 * u
	var left := maxf(frame.position.x, 0.0) + m
	var right := minf(frame.end.x, vp.x) - m
	var top := frame.position.y + bar + 10.0 * u
	var bottom := frame.end.y - 56.0 * u - 10.0 * u
	var cy := frame.position.y + frame.size.y * 0.5
	_place(_back_btn, Vector2(frame.position.x + 4.0 * u, frame.position.y - 2.0 * u), 40.0 * u)
	_place(_gear_btn, Vector2(minf(frame.end.x, vp.x) - 44.0 * u, frame.position.y - 2.0 * u), 40.0 * u)
	var step := 82.0 * u
	var y0 := top + 4.0 * u
	_place(_mode_btn, Vector2(left, y0), 52.0 * u)
	_place(_tl_btn, Vector2(left, y0 + step), 52.0 * u)
	_place(_rth_btn, Vector2(left, y0 + step * 2.0), 52.0 * u)
	_place(_view_btn, Vector2(left, y0 + step * 3.0), 52.0 * u)
	var sx := right - 80.0 * u - 18.0 * u
	_place(_shutter, Vector2(sx, cy - 40.0 * u), 80.0 * u)
	_place(_pv_btn, Vector2(sx + 18.0 * u, cy - 40.0 * u - 62.0 * u), 44.0 * u)
	_place(minimap, Vector2(left + 66.0 * u, bottom - 150.0 * u), 150.0 * u)
	_gimbal.size = Vector2(44.0 * u, frame.size.y * 0.44)
	_gimbal.position = Vector2(frame.end.x - 48.0 * u, frame.position.y + frame.size.y * 0.28)
	_toast.size = Vector2(vp.x, 36.0)
	_toast.position = Vector2(0, frame.position.y + bar + 6.0 * u)
	_crash_box.position = Vector2(vp.x * 0.5 - 160.0, vp.y * 0.5 - 10.0)
	_flash.size = vp

# ------------------------------------------------------------------ notices and state shown on the buttons
## A short notice under the top bar, like "Returning to home".
func toast(text: String, warn := false) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", Color(1, 0.72, 0.35) if warn else Color.WHITE)
	if _toast_tween != null and _toast_tween.is_valid(): _toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)

func flash_photo() -> void:
	_flash.color = Color(1, 1, 1, 0.75)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.35)

func set_airborne(on: bool) -> void:
	if on == airborne: return
	airborne = on
	_tl_btn.set_kind("land" if on else "takeoff"); _tl_btn.label = "Land" if on else "Takeoff"

func set_rth(on: bool) -> void:
	rth_active = on
	_rth_btn.set_active(on)

func show_crash(reason: String) -> void:
	_crash_box.visible = reason != ""
	_crash_label.text = reason.to_upper()

func show_gimbal(on: bool) -> void:
	_gimbal.visible = on

func set_gimbal_value(rad: float) -> void:
	_gimbal.set_value_no_signal(rad_to_deg(rad))

func toggle_photo_video() -> void:
	video_mode = not video_mode
	_shutter.video_mode = video_mode; _shutter.queue_redraw()
	_pv_btn.set_kind("video" if video_mode else "camera")
	toast("Video mode" if video_mode else "Photo mode")

func cycle_mode() -> void:
	set_mode({"N": "S", "S": "M", "M": "N"}[mode])

func set_mode(m: String) -> void:
	mode = m; mode_changed.emit(m); _sync()

func set_chase(on: bool) -> void:
	chase = on; camera_changed.emit(on); _sync()

func set_lens(l: String) -> void:
	lens = l; lens_changed.emit(l); _sync()

func toggle_lens() -> void:
	set_lens("wide" if lens == "standard" else "standard")

func set_airframe(id: String) -> void:
	airframe_id = id; _sync()

## The controls a stick must not start under (so tapping a button does not also put down a thumb stick).
func interactive_controls() -> Array[Control]:
	return [_back_btn, _gear_btn, _mode_btn, _tl_btn, _rth_btn, _view_btn, _pv_btn, _shutter, _gimbal]

# ------------------------------------------------------------------ settings page
func _build_settings() -> void:
	_menu_dim = ColorRect.new()
	_menu_dim.color = Color(0.02, 0.03, 0.04, 0.55)
	_menu_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_dim.visible = false
	_root.add_child(_menu_dim)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.anchor_left = 0.03; _panel.anchor_right = 0.97; _panel.anchor_top = 0.04; _panel.anchor_bottom = 0.96
	_panel.offset_left = 0; _panel.offset_right = 0; _panel.offset_top = 0; _panel.offset_bottom = 0
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.07, 0.08, 0.10, 0.985); sb.set_corner_radius_all(18)
	sb.set_border_width_all(1); sb.border_color = Color(1, 1, 1, 0.14); sb.set_content_margin_all(0)
	_panel.add_theme_stylebox_override("panel", sb)
	_menu_dim.add_child(_panel)
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 0)
	_panel.add_child(col)
	# header
	var head := HBoxContainer.new(); head.custom_minimum_size = Vector2(0, 64)
	var title := Label.new(); title.text = "  Settings"; title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	var close := Button.new(); close.text = "Done"; close.custom_minimum_size = Vector2(120, 48)
	close.pressed.connect(func(): set_paused(false))
	head.add_child(close)
	head.add_child(Control.new())
	col.add_child(head)
	var line := ColorRect.new(); line.color = Color(1, 1, 1, 0.1); line.custom_minimum_size = Vector2(0, 1); col.add_child(line)
	# side tabs and the page
	var row := HBoxContainer.new(); row.size_flags_vertical = Control.SIZE_EXPAND_FILL; col.add_child(row)
	var side := VBoxContainer.new(); side.custom_minimum_size = Vector2(210, 0); side.add_theme_constant_override("separation", 6)
	var side_wrap := MarginContainer.new()
	side_wrap.add_theme_constant_override("margin_left", 12); side_wrap.add_theme_constant_override("margin_top", 12); side_wrap.add_theme_constant_override("margin_right", 6)
	side_wrap.add_child(side); row.add_child(side_wrap)
	var vline := ColorRect.new(); vline.color = Color(1, 1, 1, 0.1); vline.custom_minimum_size = Vector2(1, 0); row.add_child(vline)
	_tabs = TabContainer.new(); _tabs.tabs_visible = false; _tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var page_wrap := MarginContainer.new(); page_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_wrap.add_theme_constant_override("margin_left", 16); page_wrap.add_theme_constant_override("margin_right", 16); page_wrap.add_theme_constant_override("margin_top", 10)
	page_wrap.add_child(_tabs); row.add_child(page_wrap)
	for i in TABS.size():
		var b := Button.new(); b.text = TABS[i]; b.toggle_mode = true; b.custom_minimum_size = Vector2(0, 56); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): _tabs.current_tab = i; _sync())
		side.add_child(b); _tab_btns.append(b)
	_build_flight_tab(); _build_drone_tab(); _build_weather_tab(); _build_camera_tab(); _build_display_tab(); _build_controls_tab()
	# footer
	var line2 := ColorRect.new(); line2.color = Color(1, 1, 1, 0.1); line2.custom_minimum_size = Vector2(0, 1); col.add_child(line2)
	var foot := HBoxContainer.new(); foot.custom_minimum_size = Vector2(0, 68); foot.add_theme_constant_override("separation", 12)
	var peek := Button.new(); peek.text = "Hold to see the video"; peek.custom_minimum_size = Vector2(300, 52)
	peek.button_down.connect(func(): _panel.modulate.a = 0.0; _menu_dim.color.a = 0.0)
	peek.button_up.connect(func(): _panel.modulate.a = 1.0; _menu_dim.color.a = 0.55)
	var fm := MarginContainer.new(); fm.add_theme_constant_override("margin_left", 14); fm.add_theme_constant_override("margin_top", 8); fm.add_child(peek)
	foot.add_child(fm)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; foot.add_child(sp)
	var go := Button.new(); go.text = "Resume flight"; go.custom_minimum_size = Vector2(260, 52)
	go.pressed.connect(func(): set_paused(false))
	var gm := MarginContainer.new(); gm.add_theme_constant_override("margin_right", 14); gm.add_theme_constant_override("margin_top", 8); gm.add_child(go)
	foot.add_child(gm)
	col.add_child(foot)

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
	l.add_theme_font_size_override("font_size", 15); l.add_theme_color_override("font_color", Color(0.55, 0.72, 0.95))
	parent.add_child(l)

func _choice(parent: Control, title: String, options: Array, get_i: Callable, set_i: Callable) -> void:
	_heading(parent, title)
	var row := HFlowContainer.new(); row.add_theme_constant_override("h_separation", 8); row.add_theme_constant_override("v_separation", 8)
	parent.add_child(row)
	var btns: Array[Button] = []
	for i in options.size():
		var b := Button.new(); b.text = options[i]; b.toggle_mode = true; b.custom_minimum_size = Vector2(150, 54)
		b.pressed.connect(func(): set_i.call(i); _sync())
		row.add_child(b); btns.append(b)
	_refreshers.append(func():
		for i in btns.size(): btns[i].set_pressed_no_signal(i == int(get_i.call())))

func _action(parent: Control, text: String, fn: Callable) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(0, 54); b.pressed.connect(fn)
	parent.add_child(b); return b

func _build_flight_tab() -> void:
	var p := _page("Flight")
	_choice(p, "Flight mode", ["Normal", "Sport", "Manual"], func(): return ["N", "S", "M"].find(mode), func(i): set_mode(["N", "S", "M"][i]))
	_choice(p, "Camera view", ["First person", "Chase"], func(): return 1 if chase else 0, func(i): set_chase(i == 1))
	_heading(p, "Assisted flight")
	_action(p, "Auto takeoff or landing", func(): takeoff_land_requested.emit(); set_paused(false))
	_action(p, "Return to home", func(): rth_requested.emit(); set_paused(false))
	_action(p, "Reset drone to the start", func(): reset_requested.emit(); set_paused(false))

func _build_drone_tab() -> void:
	var p := _page("Drone")
	_heading(p, "Choose a drone. It returns to the start.")
	for id in Airframes.IDS:
		var af := Airframes.make(id)
		var b := Button.new(); b.toggle_mode = true; b.custom_minimum_size = Vector2(0, 78)
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

## A slider for a setting that is not part of the saved weather.
func _gslider(parent: Control, title: String, lo: float, hi: float, step: float, get_v: Callable, set_v: Callable, fmt: Callable) -> void:
	var row := HBoxContainer.new(); parent.add_child(row)
	var l := Label.new(); l.text = title; l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(l)
	var v := Label.new(); v.add_theme_color_override("font_color", Color.WHITE); row.add_child(v)
	var s := HSlider.new(); s.min_value = lo; s.max_value = hi; s.step = step; s.custom_minimum_size = Vector2(0, 44)
	s.value_changed.connect(func(x: float): set_v.call(x); _sync())
	parent.add_child(s)
	_refreshers.append(func(): s.set_value_no_signal(float(get_v.call())); v.text = str(fmt.call(float(get_v.call()))))

func _build_weather_tab() -> void:
	var p := _page("Weather")
	_choice(p, "Conditions", WeatherSystem.NAMES, func(): return int(weather["sky"]), func(i): weather["sky"] = i; _weather_edited())
	_slider(p, "intensity", "Intensity (rain, snow, fog)", 0.0, 1.0, 0.01)
	_heading(p, "Time of day")
	_choice(p, "Clock", ["Real clock", "Set the time"], func(): return int(weather["clock_mode"]), func(i): weather["clock_mode"] = i; _weather_edited())
	_slider(p, "hour", "Hour of day (moving this sets the time)", 0.0, 23.99, 0.05)
	_choice(p, "Time passes", ["Real time", "Fast (a minute a second)", "Frozen"], func(): return int(weather["clock_speed"]), func(i): weather["clock_speed"] = i; _weather_edited())
	_choice(p, "Date", ["Today", "Spring (21 Mar)", "Summer (21 Jun)", "Autumn (22 Sep)", "Winter (21 Dec)"], func(): return int(weather["date"]), func(i): weather["date"] = i; _weather_edited())
	_heading(p, "Wind")
	var seg := HFlowContainer.new(); seg.add_theme_constant_override("h_separation", 8); p.add_child(seg)
	for pr in PRESETS:
		var b := Button.new(); b.text = pr[0]; b.custom_minimum_size = Vector2(130, 54)
		b.pressed.connect(func(): weather["wind"] = pr[1]; weather["gust"] = pr[2]; _weather_edited())
		seg.add_child(b)
	_slider(p, "wind", "Wind speed", 0.0, 10.0, 0.1)
	_slider(p, "gust", "Gusts", 0.0, 1.0, 0.01)
	_slider(p, "from", "Wind comes from", 0.0, 359.0, 1.0)
	_action(p, "Reset weather", func(): weather = DEFAULT_WEATHER.duplicate(); _weather_edited())

func _build_camera_tab() -> void:
	var p := _page("Camera")
	_choice(p, "Lens", ["84° Standard", "150° Wide"], func(): return 0 if lens == "standard" else 1, func(i): set_lens("standard" if i == 0 else "wide"))
	_choice(p, "Drone light", ["Off", "On"], func(): return 1 if light_on else 0, func(i): light_on = i == 1; light_changed.emit(light_on))
	_gslider(p, "Exposure compensation", -3.0, 3.0, 0.33, func(): return ev_comp, func(x): ev_comp = x; ev_changed.emit(x), func(v): return "%+.1f EV" % v)
	_choice(p, "Bloom", ["On", "Off"], func(): return 0 if bloom else 1, func(i): bloom = i == 0; bloom_changed.emit(bloom))
	_gslider(p, "Video noise", 0.0, 1.5, 0.05, func(): return noise, func(x): noise = x; noise_changed.emit(x), func(v): return "%d%%" % int(round(v * 100.0)))
	_choice(p, "Video link effects", ["On", "Off"], func(): return 0 if link_fx else 1, func(i): link_fx = i == 0; link_changed.emit(link_fx))

func _build_controls_tab() -> void:
	var p := _page("Controls")
	_heading(p, "Keyboard")
	var kb := KeyboardGuide.new(); kb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(kb)
	_heading(p, "Also")
	var extra := Label.new(); extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	extra.text = "Mouse or touch: Take off or land, Return to home, Mode, View and the shutter are the round buttons on the flight screen. Press and drag on the left half of the picture for the left stick, and on the right half for the right stick. Drag the scale on the right edge, or hold Q and E, to tilt a gimbal camera (only the Gimbal Mini and the Cinema drone have one).

Game controller: left stick climbs, descends and turns; right stick moves forward, back and leans.

The picture shown is the drone's own camera. Hold \"Hold to see the video\" at the bottom to look past this page."
	p.add_child(extra)

func _apply_fx() -> void:
	RenderingServer.global_shader_parameter_set("g_fx", Vector4(1.0 if fx_cloud else 0.0, 1.0 if fx_trees else 0.0, 0.0, 0.0))

func _build_display_tab() -> void:
	var p := _page("Display")
	_choice(p, "Data overlay", ["On", "Off"], func(): return 0 if osd_on else 1, func(i): osd_on = i == 0; osd_changed.emit(osd_on))
	_choice(p, "Sound", ["On", "Off"], func(): return 0 if sound_on else 1, func(i): sound_on = i == 0; sound_changed.emit(sound_on))
	_choice(p, "Listening position", ["Ground (the pilot)", "Onboard microphone", "Cinematic mix"], func(): return listening, func(i): listening = i; listening_changed.emit(i))
	_gslider(p, "Volume", 0.0, 1.0, 0.05, func(): return sound_vol, func(x): sound_vol = x; volume_changed.emit(x), func(v): return "%d%%" % int(round(v * 100.0)))
	_choice(p, "Frame rate", ["60 fps", "30 fps"], func(): return 0 if Engine.max_fps in [0, 60] else 1, func(i): Engine.max_fps = 60 if i == 0 else 30)
	_heading(p, "Graphics (if the picture looks wrong on a phone, try these)")
	_choice(p, "Cloud shadows on the land", ["On", "Off"], func(): return 0 if fx_cloud else 1, func(i): fx_cloud = i == 0; _apply_fx())
	_choice(p, "Tree colour variety", ["On", "Off"], func(): return 0 if fx_trees else 1, func(i): fx_trees = i == 0; _apply_fx())
	_choice(p, "Grass", ["On", "Off"], func(): return 0, func(i): grass_changed.emit(i == 0))
	_heading(p, "Screen")
	_action(p, "Full screen", func():
		var m := DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if m == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN))
	_action(p, "Quit", func(): get_tree().quit())

func _weather_edited() -> void:
	_sync(); weather_changed.emit(weather); _save_weather()

func _sync() -> void:
	if _mode_btn == null: return
	_mode_btn.set_kind(mode)
	_view_btn.set_active(chase)
	for i in _tab_btns.size(): _tab_btns[i].set_pressed_no_signal(i == _tabs.current_tab)
	for f in _refreshers: f.call()
	for id in _drone_buttons: _drone_buttons[id].set_pressed_no_signal(id == airframe_id)
	for k in _sliders:
		_sliders[k].set_value_no_signal(float(weather[k]))
		var v := float(weather[k])
		match k:
			"wind": _slider_labels[k].text = "%.1f m/s" % v
			"gust": _slider_labels[k].text = "Steady" if v < 0.34 else ("Some gusts" if v < 0.7 else "Gusty")
			"from": _slider_labels[k].text = "%s (%d°)" % [COMPASS[int(round(v / 45.0)) % 8], int(v)]
			"hour": _slider_labels[k].text = "%02d:%02d" % [int(v), int((v - floorf(v)) * 60.0)]
			"intensity": _slider_labels[k].text = "Light" if v < 0.34 else ("Moderate" if v < 0.7 else "Heavy")

func set_paused(on: bool) -> void:
	paused = on
	_menu_dim.visible = on
	# the settings page covers the flight screen the way an app's settings page does
	for c in [_back_btn, _gear_btn, _mode_btn, _tl_btn, _rth_btn, _view_btn, _pv_btn, _shutter, _gimbal, minimap, _toast, _crash_box]:
		(c as CanvasItem).visible = not on
	if on: _sync()
	pause_changed.emit(on)

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

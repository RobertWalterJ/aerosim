class_name PhoneOS
extends CanvasLayer

signal fly_drone(id: String)
signal travel_requested(site_id: String)
## The in-game phone (session B): a home screen, an app switcher and full-screen apps, opened with Tab.
##
## The phone exists because the DroneBudz story lives in apps: a Discord-style server where the crew talk about the
## channel, a Studio app with the two numbers that matter (followers and money), the photo library, the jobs board and
## the Casebook. It sits under the gallery and jobs pages so those can open on top of it, and closing them returns to the
## phone.
##
## The sandbox keeps running behind the phone on purpose: there is no forced pause and nothing in here gates flying.
## Nothing here writes to disk except the chat and job state their own classes already keep.
##
## UI pass: one UniverseUI theme on the root, a drawn valley wallpaper, a warmer home and a proper app switcher.

var hud: Hud
var jobs: Jobs
var photos: PhotoLibrary
var chat: ChatData
var crew: Crew
var _chat_app: ChatApp
var _studio_app: StudioApp
var story: StoryArc
var _casebook_app: CasebookApp
var _marketplace_app: MarketplaceApp
var _map_app: MapApp
var inventory: Inventory
var clips: ClipLibrary
var director: StoryDirector
var roads: Roads
var sites: LaunchSites
var finale: Finale
var wildlife: WildlifeCase
var _root: Control
var _screen: Control              # content rect inside the device bezel; every OS surface lives here
var _frame_inset := 0.0
var _home: Control
var _apps: Control
var _drawer: Control
var _drawer_search: LineEdit
var _drawer_grid: GridContainer
var _drawer_cells: Array[Control] = []
var _drawer_shown := false
var _switcher: Control
var _switcher_panel: PanelContainer
var _sys_nav: PanelContainer
var _sys_nav_name: Label
var _status_bar: MarginContainer
var _status_icons: HBoxContainer
var _clock: Label
var _metrics: Label
var _weather: Label
var _field_weather: Label
var _field_crew: Label
var _field_case: Label
var _drone_budz_badge: Label
var _studio_badge: Label
var _badges := {}                    # app key -> red Android count badge on the home icon
var _wind_dial: TabletDial
var _battery_dial: TabletDial
var _credit: Label
var _status_sig: Label
var _mode_label: Label
var _battery_pct := 0.74
var _open := false
var _current_app := "home"
var _u := 1.0

func setup(h: Hud, j: Jobs, p: PhotoLibrary, c: ChatData, cr: Crew, st: StoryArc, inv: Inventory, cl: ClipLibrary, dr: StoryDirector = null,
		rd: Roads = null, ls: LaunchSites = null, fn: Finale = null, wl: WildlifeCase = null) -> void:
	hud = h
	jobs = j
	photos = p
	chat = c
	crew = cr
	story = st
	inventory = inv
	clips = cl
	director = dr
	roads = rd
	sites = ls
	finale = fn
	wildlife = wl
	layer = 28
	_build()
	_show_home()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = UniverseUI.make_theme()
	add_child(_root)
	var tex := load("res://assets/ui/tablet_red_barn.jpg") as Texture2D
	if tex != null:
		var photo := TextureRect.new()
		photo.set_anchors_preset(Control.PRESET_FULL_RECT)
		photo.texture = tex
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(photo)
	else:
		var bg := PhoneBackground.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		_root.add_child(bg)
	# Design unit. During _ready the viewport may still be the physical window size before the canvas stretch is
	# applied, so do not derive the build-time layout from it; _resize_insets() refreshes it once the game is up.
	_u = 1.0
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.025, 0.035, 0.028, 0.10)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(scrim)
	# The kit ships a warm edge vignette for the wallpaper: it keeps the photograph bright and gives the launcher the
	# darker edges Android wallpapers have, without darkening the whole screen.
	var vignette_path := "res://assets/ui/tablet/polish/wallpaper_vignette.png"
	if ResourceLoader.exists(vignette_path):
		var vignette := TextureRect.new()
		vignette.texture = load(vignette_path) as Texture2D
		vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
		vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		vignette.stretch_mode = TextureRect.STRETCH_SCALE
		vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(vignette)
	var top_shade := TextureRect.new()
	var g := Gradient.new(); g.set_color(0, Color(0.02, 0.03, 0.025, 0.62)); g.set_color(1, Color(0.02, 0.03, 0.025, 0.0))
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill_from = Vector2(0.0, 0.0); gt.fill_to = Vector2(0.0, 1.0); gt.width = 8; gt.height = 96
	top_shade.texture = gt
	top_shade.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_shade.offset_bottom = 96.0 * _u
	top_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top_shade)
	# status bar (Android tablet: 24 dp, clock and notification glyphs left, signal/relay/battery right)
	_status_bar = MarginContainer.new()
	_status_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_status_bar.offset_bottom = _status_h()
	_status_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for m in ["left", "right"]:
		_status_bar.add_theme_constant_override("margin_" + m, int(round(16.0 * _u)))
	_status_bar.z_index = 30
	_root.add_child(_status_bar)
	var st := HBoxContainer.new()
	st.add_theme_constant_override("separation", int(round(8.0 * _u)))
	_status_bar.add_child(st)
	_clock = UniverseUI.label("", 13, UniverseUI.CREAM)
	_clock.add_theme_font_size_override("font_size", int(round(13.0 * _u)))
	_clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	st.add_child(_clock)
	_status_icons = HBoxContainer.new()
	_status_icons.add_theme_constant_override("separation", int(round(8.0 * _u)))
	_status_icons.alignment = BoxContainer.ALIGNMENT_END
	st.add_child(_status_icons)
	for icon_name in ["status_signal", "status_wifi", "status_battery"]:
		var icon := TextureRect.new()
		icon.texture = load("res://assets/ui/tablet/status/64/%s.png" % icon_name) as Texture2D
		icon.custom_minimum_size = Vector2(18.0 * _u, 18.0 * _u)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color(0.92, 0.90, 0.82)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_status_icons.add_child(icon)
	_status_sig = UniverseUI.label("100%", 11, UniverseUI.CREAM_DIM)
	_status_sig.add_theme_font_size_override("font_size", int(round(11.0 * _u)))
	_status_sig.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	st.add_child(_status_sig)
	# home screen
	_home = Control.new()
	_home.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_home)
	var hcol := VBoxContainer.new()
	hcol.set_anchors_preset(Control.PRESET_FULL_RECT)
	hcol.add_theme_constant_override("separation", 0)
	_home.add_child(hcol)
	var hm := MarginContainer.new()
	for m in ["left", "right"]:
		hm.add_theme_constant_override("margin_" + m, int(round(44.0 * _u)))
	hm.add_theme_constant_override("margin_top", int(round(54.0 * _u)))
	hm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hcol.add_child(hm)
	var hbox := VBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(round(4.0 * _u)))
	hm.add_child(hbox)
	var date := UniverseUI.label("AUTUMN  ·  NORTH VALLEY  ·  52°N", 10, UniverseUI.AMBER)
	hbox.add_child(date)
	_mode_label = UniverseUI.label("", 9, UniverseUI.MOSS)
	hbox.add_child(_mode_label)
	var big := UniverseUI.label("00:00", 48, UniverseUI.CREAM)
	big.name = "BigClock"
	hbox.add_child(big)
	var sub := HBoxContainer.new()
	sub.add_theme_constant_override("separation", 12)
	hbox.add_child(sub)
	_weather = UniverseUI.label("", 13, UniverseUI.MUTED)
	sub.add_child(_weather)
	var dot := UniverseUI.label("·", 13, UniverseUI.FAINT)
	sub.add_child(dot)
	_metrics = UniverseUI.label("", 13, UniverseUI.MOSS)
	sub.add_child(_metrics)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	hbox.add_child(gap)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", int(round(8.0 * _u)))
	grid.add_theme_constant_override("v_separation", int(round(14.0 * _u)))
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	hbox.add_child(content)
	content.add_child(grid)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	var note := PanelContainer.new()
	note.custom_minimum_size = Vector2(320, 0)
	note.add_theme_stylebox_override("panel", UniverseUI.card(16, Color(0.075, 0.090, 0.078, 0.92)))
	content.add_child(note)
	var nm := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		nm.add_theme_constant_override("margin_" + m, 14)
	note.add_child(nm)
	var ncol := VBoxContainer.new()
	ncol.add_theme_constant_override("separation", 6)
	nm.add_child(ncol)
	ncol.add_child(UniverseUI.label("FIELD NOTE", 10, UniverseUI.AMBER))
	var field_title := UniverseUI.label("Halloway Valley", 18, UniverseUI.CREAM)
	ncol.add_child(field_title)
	_field_weather = UniverseUI.label("", 12, UniverseUI.MUTED)
	_field_weather.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ncol.add_child(_field_weather)
	var dial_row := HBoxContainer.new()
	dial_row.add_theme_constant_override("separation", 8)
	ncol.add_child(dial_row)
	_wind_dial = TabletDial.new()
	_wind_dial.custom_minimum_size = Vector2(92.0 * _u, 92.0 * _u)
	_wind_dial.set_dial("wind", 0.35, "WIND", UniverseUI.AMBER)
	dial_row.add_child(_wind_dial)
	_battery_dial = TabletDial.new()
	_battery_dial.custom_minimum_size = Vector2(92.0 * _u, 92.0 * _u)
	_battery_dial.set_dial("battery", _battery_pct, "DRONE", UniverseUI.MOSS)
	dial_row.add_child(_battery_dial)
	var div := HSeparator.new()
	div.add_theme_constant_override("separation", 8)
	ncol.add_child(div)
	_field_crew = UniverseUI.label("", 11, UniverseUI.MOSS)
	_field_crew.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ncol.add_child(_field_crew)
	_field_case = UniverseUI.label("", 11, UniverseUI.CREAM_DIM)
	_field_case.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ncol.add_child(_field_case)
	var apps := [
		{"key": "chat", "letter": "DB", "name": "DroneBudz", "kind": "server"},
		{"key": "studio", "letter": "VT", "name": "VidTube Studio", "kind": "channel"},
		{"key": "photos", "letter": "PH", "name": "Photos", "kind": "camera roll"},
		{"key": "jobs", "letter": "JB", "name": "Jobs", "kind": "board"},
		{"key": "casebook", "letter": "CB", "name": "Casebook", "kind": "case file"},
		{"key": "market", "letter": "FC", "name": "Facade", "kind": "marketplace"},
		{"key": "map", "letter": "MP", "name": "Map", "kind": "road atlas"},
	]
	for a in apps:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", int(round(4.0 * _u)))
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(64.0 * _u, 64.0 * _u)
		btn.focus_mode = Control.FOCUS_NONE
		var empty := StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty)
		btn.add_theme_stylebox_override("hover", empty)
		btn.add_theme_stylebox_override("pressed", empty)
		var key := str(a["key"])
		var tint := UniverseUI.app_colour(key)
		var icon := UniverseUI.app_icon(key, 64.0 * _u, tint)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.add_child(icon)
		# Android notification badge: a red count pill on the icon's top-right, never a caption under the name.
		if key in ["chat", "studio", "jobs", "market", "casebook"]:
			var badge := Label.new()
			var bsb := StyleBoxFlat.new()
			bsb.bg_color = Color(0.702, 0.149, 0.118, 1.0)
			bsb.set_corner_radius_all(int(round(9.0 * _u)))
			bsb.content_margin_left = 4.0 * _u
			bsb.content_margin_right = 4.0 * _u
			badge.add_theme_stylebox_override("normal", bsb)
			badge.add_theme_font_size_override("font_size", int(round(10.0 * _u)))
			badge.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.anchor_left = 1.0
			badge.anchor_right = 1.0
			badge.anchor_top = 0.0
			badge.anchor_bottom = 0.0
			badge.offset_left = -22.0 * _u
			badge.offset_right = 2.0 * _u
			badge.offset_top = -6.0 * _u
			badge.offset_bottom = 12.0 * _u
			badge.visible = false
			btn.add_child(badge)
			_badges[key] = badge
		btn.pressed.connect(func(): _open_app(key))
		cell.add_child(btn)
		var lab := UniverseUI.label(str(a["name"]), 12, UniverseUI.CREAM_DIM)
		lab.add_theme_font_size_override("font_size", int(round(12.0 * _u)))
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.clip_text = true
		lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		# Material launcher labels get 100 dp, enough for "VidTube Studio" without an ellipsis.
		lab.custom_minimum_size = Vector2(100.0 * _u, 0)
		lab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(lab)
		grid.add_child(cell)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(filler)
	var tip_card := PanelContainer.new()
	tip_card.theme_type_variation = "FlatCard"
	tip_card.visible = false
	hbox.add_child(tip_card)
	var tm := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		tm.add_theme_constant_override("margin_" + m, 12)
	tip_card.add_child(tm)
	var tip := UniverseUI.label("Tab closes the phone. Land to use it safely. The valley keeps flying behind it.", 10, UniverseUI.MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tm.add_child(tip)
	# All apps entry. The launcher is one page plus a drawer, so the row under the grid is the touch route into the
	# app list (the page-dot row would be decoration without paging).
	var drawer_row := HBoxContainer.new()
	drawer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	drawer_row.custom_minimum_size = Vector2(0, int(round(34.0 * _u)))
	var all_btn := Button.new()
	all_btn.text = "All apps"
	all_btn.theme_type_variation = "Ghost"
	all_btn.custom_minimum_size = Vector2(140.0 * _u, 34.0 * _u)
	all_btn.add_theme_font_size_override("font_size", int(round(12.0 * _u)))
	var all_glyph := "res://assets/ui/tablet/glyphs/nav_allapps.png"
	if ResourceLoader.exists(all_glyph):
		all_btn.icon = load(all_glyph) as Texture2D
		all_btn.expand_icon = true
		all_btn.add_theme_constant_override("icon_max_width", int(round(15.0 * _u)))
	all_btn.pressed.connect(_show_drawer)
	drawer_row.add_child(all_btn)
	hcol.add_child(drawer_row)
	# dock: the kit dock tray, centred, five app shortcuts, no labels (Android)
	var dock := PanelContainer.new()
	var dock_tex := "res://assets/ui/tablet/polish/dock_tray.png"
	if ResourceLoader.exists(dock_tex):
		var dsb := StyleBoxTexture.new()
		dsb.texture = load(dock_tex) as Texture2D
		dsb.set_texture_margin_all(44.0 * (84.0 * _u / 128.0))
		dsb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		dock.add_theme_stylebox_override("panel", dsb)
	else:
		dock.add_theme_stylebox_override("panel", UniverseUI.box(Color(0.07, 0.085, 0.075, 0.96), 24, Color(0, 0, 0, 0), 0, 26.0, 10.0))
	dock.custom_minimum_size = Vector2(0, int(round(84.0 * _u)))
	hcol.add_child(dock)
	var dm := MarginContainer.new()
	for m in ["left", "right"]:
		dm.add_theme_constant_override("margin_" + m, int(round(24.0 * _u)))
	dock.add_child(dm)
	var drow := HBoxContainer.new()
	drow.alignment = BoxContainer.ALIGNMENT_CENTER
	drow.add_theme_constant_override("separation", int(round(16.0 * _u)))
	dm.add_child(drow)
	for pair in [["chat", "DroneBudz"], ["studio", "VidTube Studio"], ["photos", "Photos"], ["market", "Facade"], ["map", "Map"]]:
		var dock_btn := Button.new()
		dock_btn.custom_minimum_size = Vector2(56.0 * _u, 56.0 * _u)
		dock_btn.tooltip_text = str(pair[1])
		dock_btn.focus_mode = Control.FOCUS_NONE
		var empty := StyleBoxEmpty.new()
		dock_btn.add_theme_stylebox_override("normal", empty)
		dock_btn.add_theme_stylebox_override("hover", UniverseUI.box(Color(1, 1, 1, 0.06), 14, Color(0, 0, 0, 0), 0, 0.0, 0.0))
		dock_btn.add_theme_stylebox_override("pressed", UniverseUI.box(Color(1, 1, 1, 0.10), 14, Color(0, 0, 0, 0), 0, 0.0, 0.0))
		var der := str(pair[0])
		var dicon := UniverseUI.app_icon(der, 56.0 * _u, UniverseUI.app_colour(der))
		dicon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dock_btn.add_child(dicon)
		dock_btn.pressed.connect(func(): _open_app(der))
		drow.add_child(dock_btn)
	# app host: below the status bar, above the navigation bar (Android system insets)
	_apps = Control.new()
	_apps.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apps.offset_top = _status_h()
	_apps.offset_bottom = -_nav_h()
	_root.add_child(_apps)
	_chat_app = ChatApp.new()
	_chat_app.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chat_app.visible = false
	_apps.add_child(_chat_app)
	_chat_app.setup(chat, hud, jobs, photos, crew)
	_studio_app = StudioApp.new()
	_studio_app.set_anchors_preset(Control.PRESET_FULL_RECT)
	_studio_app.visible = false
	_apps.add_child(_studio_app)
	_studio_app.setup(hud, jobs, chat, photos, clips)
	_studio_app.chat_requested.connect(func(): _open_app("chat"))
	_studio_app.jobs_requested.connect(func(): jobs.open_page())
	_studio_app.upload_requested.connect(func(): photos.open_gallery())
	_studio_app.market_requested.connect(func(): _open_app("market"))
	_casebook_app = CasebookApp.new()
	_casebook_app.set_anchors_preset(Control.PRESET_FULL_RECT)
	_casebook_app.visible = false
	_apps.add_child(_casebook_app)
	_casebook_app.setup(story, photos, director, sites)
	_casebook_app.chat_requested.connect(func(person: String):
		_open_app("chat")
		var channel := "general"
		if person == "rennick":
			channel = "town"
		elif person == "wren":
			channel = "unknown"
		_chat_app.open(channel))
	_casebook_app.close_requested.connect(_show_home)
	_casebook_app.map_requested.connect(func(): _open_app("map"))
	_marketplace_app = MarketplaceApp.new()
	_marketplace_app.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marketplace_app.visible = false
	_apps.add_child(_marketplace_app)
	_marketplace_app.setup(jobs, inventory, hud)
	_map_app = MapApp.new()
	_map_app.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_app.visible = false
	_apps.add_child(_map_app)
	_map_app.setup(hud, roads, sites, story, wildlife, finale)
	_map_app.travel_requested.connect(func(id: String): travel_requested.emit(id))
	_marketplace_app.fly_requested.connect(func(id: String):
		fly_drone.emit(id)
		close())
	# switcher
	_switcher = Control.new()
	_switcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_switcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_switcher.visible = false
	_root.add_child(_switcher)
	var sdim := ColorRect.new()
	sdim.set_anchors_preset(Control.PRESET_FULL_RECT)
	sdim.color = Color(0.02, 0.03, 0.025, 0.82)
	sdim.mouse_filter = Control.MOUSE_FILTER_STOP
	_switcher.add_child(sdim)
	_build_drawer()
	_build_system_nav()
	_add_device_frame()
	get_viewport().size_changed.connect(_resize_insets)
	visible = false

func open() -> void:
	_open = true
	visible = true
	_resize_insets()
	_show_home()
	_refresh()

## ------------------------------------------------------------------ system metrics
## One scale unit for 720p, 1080p and 16:10 windows. The project stretches canvas items, so at 16:9 this is 1.0 at
## 1280x720 and 1.5 at 1920x1080; at 16:10 the logical height is still 720 and the extra width is absorbed by the
## centred layouts. Every insets value below is a 720-baseline number multiplied by this.
func _compute_u() -> float:
	var vp := get_viewport().get_visible_rect().size
	return clampf(vp.y / 720.0, 0.6, 4.0)

func _status_h() -> float:
	return 28.0 * _u

func _nav_h() -> float:
	return 56.0 * _u

## Android system insets: apps sit below the status bar and above the nav bar. Re-applied when the viewport changes
## size, so a resized desktop window or a 16:10 tablet keeps the same layout instead of the old fixed 38/54 values.
func _resize_insets() -> void:
	_u = _compute_u()
	if _status_bar != null:
		_status_bar.offset_bottom = _status_h()
		for m in ["left", "right"]:
			_status_bar.add_theme_constant_override("margin_" + m, int(round(16.0 * _u)))
	if _apps != null:
		_apps.offset_top = _status_h()
		_apps.offset_bottom = -_nav_h()
	if _sys_nav != null:
		_sys_nav.offset_top = -_nav_h()

## ------------------------------------------------------------------ app drawer
## The Android app drawer: search pill, alphabetical grid, wallpaper dimmed behind. Replaces the fake page dots the
## launcher had; the home is one page and the drawer is the all-apps surface.
func _build_drawer() -> void:
	_drawer = Control.new()
	_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	_drawer.z_index = 60
	_drawer.visible = false
	_root.add_child(_drawer)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.025, 0.58)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_close_drawer())
	_drawer.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	# Material surface at 94 percent: the wallpaper stays faintly visible the way an Android drawer shows it.
	sb.bg_color = Color(UniverseUI.NIGHT.r, UniverseUI.NIGHT.g, UniverseUI.NIGHT.b, 0.94)
	panel.add_theme_stylebox_override("panel", sb)
	_drawer.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, int(round(28.0 * _u)))
	margin.add_theme_constant_override("margin_top", int(round(34.0 * _u)))
	margin.add_theme_constant_override("margin_bottom", int(round(20.0 * _u)))
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(round(12.0 * _u)))
	margin.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(round(10.0 * _u)))
	col.add_child(head)
	var title := UniverseUI.label("All apps", 22, UniverseUI.CREAM)
	title.add_theme_font_size_override("font_size", int(round(22.0 * _u)))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	var close_btn := _nav_button("nav_back", "Close", _close_drawer)
	close_btn.icon = load("res://assets/ui/tablet/glyphs/nav_back.png") as Texture2D
	head.add_child(close_btn)
	# Search bar: a clean Material pill rather than the kit nine-patch. The kit art is a single fixed 640x96 lozenge
	# with a 48 px cap radius, which cannot be nine-patched at a 48 dp row height without the ends bulging, so the pill
	# surface is a StyleBoxFlat and only the magnifier glyph comes from the kit.
	var search_wrap := Control.new()
	search_wrap.custom_minimum_size = Vector2(720.0 * _u, 48.0 * _u)
	search_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(search_wrap)
	var search_pill := Panel.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = UniverseUI.FIELD
	psb.set_corner_radius_all(int(round(24.0 * _u)))
	psb.border_width_left = 1; psb.border_width_top = 1; psb.border_width_right = 1; psb.border_width_bottom = 1
	psb.border_color = UniverseUI.LINE
	search_pill.add_theme_stylebox_override("panel", psb)
	search_pill.set_anchors_preset(Control.PRESET_FULL_RECT)
	search_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	search_wrap.add_child(search_pill)
	var search_icon := TextureRect.new()
	search_icon.texture = load("res://assets/ui/tablet/glyphs/qs_search.png") as Texture2D
	search_icon.custom_minimum_size = Vector2(18.0 * _u, 18.0 * _u)
	search_icon.position = Vector2(20.0 * _u, 15.0 * _u)
	search_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	search_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	search_icon.modulate = UniverseUI.CREAM_DIM
	search_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	search_wrap.add_child(search_icon)
	_drawer_search = LineEdit.new()
	_drawer_search.placeholder_text = "Search apps"
	_drawer_search.add_theme_font_size_override("font_size", int(round(14.0 * _u)))
	_drawer_search.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_drawer_search.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_drawer_search.add_theme_color_override("font_placeholder_color", UniverseUI.FAINT)
	_drawer_search.anchor_left = 0.0; _drawer_search.anchor_right = 1.0
	_drawer_search.anchor_top = 0.0; _drawer_search.anchor_bottom = 1.0
	_drawer_search.offset_left = 52.0 * _u
	_drawer_search.offset_right = -18.0 * _u
	_drawer_search.offset_top = 0.0
	_drawer_search.offset_bottom = 0.0
	_drawer_search.text_changed.connect(_filter_drawer)
	search_wrap.add_child(_drawer_search)
	# Material drawer grid: four columns of 120 dp cells, centred, labels always visible and single-line.
	_drawer_grid = GridContainer.new()
	_drawer_grid.columns = 4
	_drawer_grid.add_theme_constant_override("h_separation", int(round(20.0 * _u)))
	_drawer_grid.add_theme_constant_override("v_separation", int(round(16.0 * _u)))
	_drawer_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_drawer_grid)
	_drawer_cells.clear()
	for entry in [["casebook", "Casebook"], ["chat", "DroneBudz"], ["market", "Facade"], ["jobs", "Jobs"],
			["map", "Map"], ["photos", "Photos"], ["studio", "VidTube Studio"]]:
		var key := str(entry[0])
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", int(round(6.0 * _u)))
		cell.custom_minimum_size = Vector2(120.0 * _u, 0)
		cell.set_meta("app_name", str(entry[1]).to_lower())
		cell.set_meta("app_key", key)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(64.0 * _u, 64.0 * _u)
		btn.focus_mode = Control.FOCUS_NONE
		var empty := StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty)
		btn.add_theme_stylebox_override("hover", empty)
		btn.add_theme_stylebox_override("pressed", empty)
		var icon := UniverseUI.app_icon(key, 64.0 * _u, UniverseUI.app_colour(key))
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.add_child(icon)
		btn.pressed.connect(func(): _open_app(key))
		cell.add_child(btn)
		var lab := UniverseUI.label(str(entry[1]), 13, UniverseUI.CREAM_DIM)
		lab.add_theme_font_size_override("font_size", int(round(13.0 * _u)))
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.clip_text = true
		lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lab.custom_minimum_size = Vector2(120.0 * _u, 0)
		lab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(lab)
		_drawer_grid.add_child(cell)
		_drawer_cells.append(cell)

func _show_drawer() -> void:
	if _drawer == null:
		return
	_drawer_shown = true
	_drawer.visible = true
	_current_app = "drawer"
	_sys_nav.visible = false
	_switcher.visible = false
	_drawer_search.text = ""
	_filter_drawer("")
	_drawer_search.grab_focus()

func _close_drawer() -> void:
	_drawer_shown = false
	if _drawer != null:
		_drawer.visible = false
	if _current_app == "drawer":
		_current_app = "home"
	_sys_nav.visible = false
	_refresh()

func _filter_drawer(text: String) -> void:
	var q := text.strip_edges().to_lower()
	for cell in _drawer_cells:
		var nm := str(cell.get_meta("app_name", ""))
		cell.visible = q.is_empty() or nm.contains(q)

## A real tablet bezel overlay from the UI kit. It makes the screen read as a physical Android tablet instead of a
## bordered desktop rectangle; the frame is transparent over the display and only the bezel is opaque. It is only
## drawn on a 16:9 window: real tablets are 16:10/3:2/4:3, and stretching this art to those aspects would bend the
## bezel and the screen corners.
func _add_device_frame() -> void:
	var frame := TextureRect.new()
	var win := DisplayServer.window_get_size()
	var aspect := float(win.x) / maxf(1.0, float(win.y))
	if absf(aspect - 16.0 / 9.0) > 0.02:
		return
	# Choose the frame export from the physical window size so the bezel is sharp on 1080p, 1440p and 4K monitors.
	var path := "res://assets/ui/tablet/frame/tablet_frame_2560x1440.png" if win.x > 2400 else (
		"res://assets/ui/tablet/frame/tablet_frame_1920x1080.png" if win.x > 1600 else
		"res://assets/ui/tablet/frame/tablet_frame_1280x720.png")
	if not ResourceLoader.exists(path):
		return
	frame.texture = load(path) as Texture2D
	frame.name = "DeviceFrame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.z_index = 300
	_root.add_child(frame)
	# The bezel is 2.5 percent of the frame height: 18 logical px on the 1280x720 export. Inset every OS surface so the
	# status bar, app bars, dock and dialogs sit inside the glass instead of under the opaque bezel.
	_frame_inset = 18.0
	_apply_frame_inset()
	_add_bezel_matte()

## Solid matte under the frame's bezel ring. The frame art already draws the bezel, but the ring is also the window edge:
## without an opaque matte, any HUD/OSD text at the extreme top or bottom edge can show through the 18 px border region
## when the launcher is open. The matte sits above the OS surfaces and below the frame, so it is invisible under the art.
func _add_bezel_matte() -> void:
	var col := Color(0.040, 0.047, 0.043, 1.0)
	var top := ColorRect.new()
	top.color = col
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = _frame_inset
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.z_index = 299
	_root.add_child(top)
	var bottom := ColorRect.new()
	bottom.color = col
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -_frame_inset
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.z_index = 299
	_root.add_child(bottom)
	for side in ["left", "right"]:
		var edge := ColorRect.new()
		edge.color = col
		edge.anchor_top = 0.0
		edge.anchor_bottom = 1.0
		if side == "left":
			edge.anchor_left = 0.0
			edge.anchor_right = 0.0
			edge.offset_right = _frame_inset
		else:
			edge.anchor_left = 1.0
			edge.anchor_right = 1.0
			edge.offset_left = -_frame_inset
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		edge.z_index = 299
		_root.add_child(edge)

## Move every OS surface under a content rect inset by the device bezel, leaving the frame overlay on the root. Without
## this the status bar clock and the screen edges are covered by the frame's opaque bezel.
func _apply_frame_inset() -> void:
	if _screen != null or _frame_inset <= 0.0:
		return
	_screen = Control.new()
	_screen.name = "Screen"
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.offset_left = _frame_inset
	_screen.offset_top = _frame_inset
	_screen.offset_right = -_frame_inset
	_screen.offset_bottom = -_frame_inset
	_screen.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(_screen)
	for child in _root.get_children():
		if child == _screen:
			continue
		if child is TextureRect and child.name == "DeviceFrame":
			continue
		child.reparent(_screen, false)

func is_drawer_open() -> bool:
	return _drawer_shown

## The persistent bottom navigation bar. Android 3-button order: back on the left, home and recents on the right, with
## the tablet's "put away" action as the fourth control. Material glyphs come from the kit's generated glyph set.
func _build_system_nav() -> void:
	_sys_nav = PanelContainer.new()
	_sys_nav.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_sys_nav.offset_top = -_nav_h()
	_sys_nav.z_index = 40
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.050, 0.060, 0.052, 0.97)
	sb.border_width_top = 1
	sb.border_color = UniverseUI.LINE
	_sys_nav.add_theme_stylebox_override("panel", sb)
	_root.add_child(_sys_nav)
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, int(round(20.0 * _u)))
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, int(round(4.0 * _u)))
	_sys_nav.add_child(m)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(round(8.0 * _u)))
	m.add_child(row)
	row.add_child(_nav_button("nav_back", "Back", _show_home))
	var stretch := Control.new()
	stretch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stretch)
	_sys_nav_name = UniverseUI.label("", 12, UniverseUI.MUTED)
	_sys_nav_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sys_nav_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sys_nav_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sys_nav_name.visible = false
	row.add_child(_sys_nav_name)
	row.add_child(_nav_button("nav_home", "Home", _show_home))
	row.add_child(_nav_button("nav_recents", "Recents", _show_switcher))
	row.add_child(_nav_button("nav_phone", "Put the tablet away", close))
	_sys_nav.visible = false

func _nav_button(glyph: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(48.0 * _u, 48.0 * _u)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	var path := "res://assets/ui/tablet/glyphs/%s.png" % glyph
	if ResourceLoader.exists(path):
		b.icon = load(path) as Texture2D
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", int(round(24.0 * _u)))
	var empty := StyleBoxEmpty.new()
	b.add_theme_stylebox_override("normal", empty)
	b.add_theme_stylebox_override("hover", UniverseUI.box(Color(1, 1, 1, 0.07), 12, Color(0, 0, 0, 0), 0, 0.0, 0.0))
	b.add_theme_stylebox_override("pressed", UniverseUI.box(Color(1, 1, 1, 0.12), 12, Color(0, 0, 0, 0), 0, 0.0, 0.0))
	b.pressed.connect(cb)
	return b

func _update_system_nav(app_key: String) -> void:
	if _sys_nav == null:
		return
	_sys_nav.visible = app_key != "home" and app_key != "switcher" and app_key != "drawer"
	_sys_nav_name.text = _app_title(app_key).to_upper()

func _app_title(key: String) -> String:
	match key:
		"chat": return "DroneBudz"
		"studio": return "VidTube Studio"
		"photos": return "Photos"
		"jobs": return "Jobs"
		"casebook": return "Casebook"
		"market": return "Facade"
		"map": return "Map"
		"switcher": return "Recents"
		"drawer": return "All apps"
		_: return "Home"
func close() -> void:
	_open = false
	visible = false
	_switcher.visible = false
	_close_drawer()
	_update_system_nav("home")

func toggle() -> void:
	if _open:
		close()
	else:
		open()

func is_open() -> bool:
	return _open

func _show_home() -> void:
	_current_app = "home"
	_home.visible = true
	_apps.visible = false
	_switcher.visible = false
	_drawer_shown = false
	if _drawer != null:
		_drawer.visible = false
	_update_system_nav("home")
	_refresh()

func _show_switcher() -> void:
	_current_app = "switcher"
	_drawer_shown = false
	if _drawer != null:
		_drawer.visible = false
	_update_system_nav("switcher")
	if _switcher_panel != null and is_instance_valid(_switcher_panel):
		_switcher_panel.queue_free()
	_switcher_panel = PanelContainer.new()
	var sb := UniverseUI.box(UniverseUI.DEEP, 22, UniverseUI.LINE_STRONG, 1, 24.0, 20.0)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 24
	_switcher_panel.add_theme_stylebox_override("panel", sb)
	_switcher.add_child(_switcher_panel)
	_switcher_panel.anchor_left = 0.10; _switcher_panel.anchor_right = 0.90
	_switcher_panel.anchor_top = 0.13; _switcher_panel.anchor_bottom = 0.87
	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 20)
	_switcher_panel.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	m.add_child(col)
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 10)
	col.add_child(head_row)
	var hcol := VBoxContainer.new()
	hcol.add_theme_constant_override("separation", 0)
	hcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(hcol)
	hcol.add_child(UniverseUI.label("RECENTS", 10, UniverseUI.AMBER))
	hcol.add_child(UniverseUI.label("Apps", 28, UniverseUI.CREAM))
	var close_btn := Button.new(); close_btn.text = "Close"; close_btn.theme_type_variation = "Ghost"
	close_btn.custom_minimum_size = Vector2(80, 34)
	close_btn.pressed.connect(_show_home)
	head_row.add_child(close_btn)
	var hint := UniverseUI.label("Choose an app. Tab puts the phone away. Esc leaves an app.", 11, UniverseUI.MUTED)
	col.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(grid)
	var apps := [
		{"key": "chat", "name": "DroneBudz", "desc": "Crew chat, channels and DMs"},
		{"key": "studio", "name": "VidTube Studio", "desc": "Channel numbers and uploads"},
		{"key": "photos", "name": "Photos", "desc": "Everything the drone shot"},
		{"key": "jobs", "name": "Jobs", "desc": "Paid work on the valley board"},
		{"key": "casebook", "name": "Casebook", "desc": "Rennick's file and evidence"},
		{"key": "market", "name": "Facade", "desc": "Classifieds, drones and kit"},
		{"key": "map", "name": "Map", "desc": "The road map and launch sites"},
	]
	for a in apps:
		var key := str(a["key"])
		var card := PanelContainer.new()
		var csb := UniverseUI.card(14, UniverseUI.CARD, UniverseUI.AMBER if key == _current_app else UniverseUI.LINE, 1)
		card.add_theme_stylebox_override("panel", csb)
		grid.add_child(card)
		var cm := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			cm.add_theme_constant_override("margin_" + side, 8)
		card.add_child(cm)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		cm.add_child(row)
		var icon := UniverseUI.app_icon(key, 40, UniverseUI.app_colour(key))
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 1)
		row.add_child(text)
		text.add_child(UniverseUI.label(str(a["name"]), 14, UniverseUI.CREAM))
		var d := UniverseUI.label(str(a["desc"]), 10, UniverseUI.MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(d)
		var open_btn := Button.new(); open_btn.text = "Open"; open_btn.theme_type_variation = "Primary"
		open_btn.custom_minimum_size = Vector2(54, 30)
		open_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		open_btn.add_theme_font_size_override("font_size", 11)
		open_btn.pressed.connect(func(): _open_app(key))
		row.add_child(open_btn)
	_switcher.visible = true

func _app_letter(key: String) -> String:
	match key:
		"chat": return "DB"
		"studio": return "VT"
		"photos": return "PH"
		"jobs": return "JB"
		"casebook": return "CB"
		"market": return "FC"
		"map": return "MP"
	return "?"

func _open_app(key: String) -> void:
	_switcher.visible = false
	_drawer_shown = false
	if _drawer != null:
		_drawer.visible = false
	if _map_app != null:
		_map_app.visible = false
	match key:
		"chat":
			_current_app = "chat"
			_home.visible = false
			_apps.visible = true
			_studio_app.visible = false
			_casebook_app.visible = false
			_marketplace_app.visible = false
			_chat_app.visible = true
			_chat_app.open("general")
			chat.unread_total()
		"studio":
			_current_app = "studio"
			_home.visible = false
			_apps.visible = true
			_chat_app.visible = false
			_casebook_app.visible = false
			_marketplace_app.visible = false
			_studio_app.visible = true
			_studio_app.refresh()
		"casebook":
			_current_app = "casebook"
			_home.visible = false
			_apps.visible = true
			_chat_app.visible = false
			_studio_app.visible = false
			_marketplace_app.visible = false
			_casebook_app.visible = true
			_casebook_app.refresh()
		"map":
			_current_app = "map"
			_home.visible = false
			_apps.visible = true
			_chat_app.visible = false
			_studio_app.visible = false
			_casebook_app.visible = false
			_marketplace_app.visible = false
			_map_app.visible = true
			_map_app.refresh()
		"market":
			_current_app = "market"
			_home.visible = false
			_apps.visible = true
			_chat_app.visible = false
			_studio_app.visible = false
			_casebook_app.visible = false
			_marketplace_app.visible = true
			_marketplace_app.refresh()
		"photos":
			if photos != null:
				photos.open_gallery()
		"jobs":
			if jobs != null:
				jobs.open_page()
	_update_system_nav(key)
	_refresh()

func _refresh() -> void:
	if not _open:
		return
	var hour := 12.0
	if hud != null:
		hour = float(hud.weather.get("hour", 12.0))
	var hh := int(hour) % 24
	var mm := int((hour - floorf(hour)) * 60.0) % 60
	_clock.text = "%02d:%02d" % [hh, mm]
	var big := _home.find_child("BigClock", true, false) as Label
	if big != null:
		big.text = "%02d:%02d" % [hh, mm]
	if hud != null:
		var temp := float(hud.weather.get("temp", 10.0))
		var wind := float(hud.weather.get("wind", 3.0))
		_weather.text = "%.0f°C   WIND %.1f m/s" % [temp, wind]
	if jobs != null:
		_metrics.text = "%d FOLLOWERS   ·   $%d" % [jobs.followers(), jobs.money()]
	if _badges.has("chat"):
		_set_badge("chat", chat.unread_total() if chat != null else 0)
	if _field_weather != null and hud != null:
		var temp2 := float(hud.weather.get("temp", 10.0))
		var wind2 := float(hud.weather.get("wind", 3.0))
		_field_weather.text = "%.0f°C, wind %.1f m/s. The valley is holding its autumn colour." % [temp2, wind2]
	if _field_crew != null:
		var unread2 := chat.unread_total() if chat != null else 0
		_field_crew.text = "CREW  ·  %d on the server" % (chat.member_count() if chat != null else 0) + (("   9+ unread" if unread2 > 9 else "   %d unread" % unread2) if unread2 > 0 else "")
	if _field_case != null:
		_field_case.text = "CASEBOOK  ·  " + (story.current_status() if story != null else "No case yet.")
	if _badges.has("studio"):
		_set_badge("studio", clips.rushes().size() if clips != null else 0)
	if _mode_label != null:
		_mode_label.text = "FIELD KIT  ·  weather station online"
	if _wind_dial != null and hud != null:
		var wind3 := float(hud.weather.get("wind", 3.0))
		var from3 := float(hud.weather.get("from", 250.0))
		_wind_dial.set_heading(from3)
		_wind_dial.set_dial("wind", clampf(wind3 / 10.0, 0.0, 1.0), "WIND", UniverseUI.AMBER)
	if _battery_dial != null:
		_battery_dial.set_dial("battery", _battery_pct, "DRONE", UniverseUI.MOSS if _battery_pct > 0.25 else UniverseUI.RUST)
	if _status_sig != null:
		_status_sig.text = "%d%%" % int(round(_battery_pct * 100.0))
	if _current_app == "studio" and _studio_app.visible:
		_studio_app.refresh()

## Android notification badge on a home icon: red pill, count, capped at 9+.
func _set_badge(key: String, count: int) -> void:
	var badge: Label = _badges.get(key) as Label
	if badge == null:
		return
	badge.visible = count > 0
	badge.text = "9+" if count > 9 else str(count)

## The drone battery, pushed from main while the phone is open. The dial reads this.
func set_battery(pct: float) -> void:
	_battery_pct = clampf(pct, 0.0, 1.0)
	if _status_sig != null:
		_status_sig.text = "%d%%" % int(round(_battery_pct * 100.0))
	if _battery_dial != null and _open:
		_battery_dial.set_dial("battery", _battery_pct, "DRONE", UniverseUI.MOSS if _battery_pct > 0.25 else UniverseUI.RUST)

func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _drawer_shown:
			_close_drawer()
		elif _current_app != "home":
			_show_home()
		else:
			close()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _open:
		_refresh()

func stats() -> Dictionary:
	return {"open": _open, "app": _current_app, "chat": chat.stats(), "followers": jobs.followers() if jobs else 0}



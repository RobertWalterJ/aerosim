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
var _home: Control
var _apps: Control
var _switcher: Control
var _switcher_panel: PanelContainer
var _sys_nav: PanelContainer
var _sys_nav_name: Label
var _clock: Label
var _metrics: Label
var _weather: Label
var _field_weather: Label
var _field_crew: Label
var _field_case: Label
var _drone_budz_badge: Label
var _studio_badge: Label
var _wind_dial: TabletDial
var _battery_dial: TabletDial
var _credit: Label
var _status_sig: Label
var _mode_label: Label
var _battery_pct := 0.74
var _open := false
var _current_app := "home"

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
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.025, 0.035, 0.028, 0.50)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(scrim)
	var top_shade := TextureRect.new()
	var g := Gradient.new(); g.set_color(0, Color(0.02, 0.03, 0.025, 0.72)); g.set_color(1, Color(0.02, 0.03, 0.025, 0.0))
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill_from = Vector2(0.0, 0.0); gt.fill_to = Vector2(0.0, 1.0); gt.width = 8; gt.height = 256
	top_shade.texture = gt
	top_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	top_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top_shade)
	# status bar
	var status := MarginContainer.new()
	status.set_anchors_preset(Control.PRESET_TOP_WIDE)
	status.offset_bottom = 40
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for m in ["left", "right"]:
		status.add_theme_constant_override("margin_" + m, 30)
	status.z_index = 30
	_root.add_child(status)
	var st := HBoxContainer.new()
	st.add_theme_constant_override("separation", 10)
	status.add_child(st)
	_clock = UniverseUI.label("", 12, UniverseUI.CREAM_DIM)
	_clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.add_child(_clock)
	var carrier := UniverseUI.label("HALLOWAY VALLEY", 10, UniverseUI.MUTED)
	carrier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carrier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.add_child(carrier)
	_status_sig = UniverseUI.label("LINK   ·   100%", 10, UniverseUI.MUTED)
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
		hm.add_theme_constant_override("margin_" + m, 44)
	hm.add_theme_constant_override("margin_top", 54)
	hm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hcol.add_child(hm)
	var hbox := VBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
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
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 24)
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
	_wind_dial.custom_minimum_size = Vector2(92, 92)
	_wind_dial.set_dial("wind", 0.35, "WIND", UniverseUI.AMBER)
	dial_row.add_child(_wind_dial)
	_battery_dial = TabletDial.new()
	_battery_dial.custom_minimum_size = Vector2(92, 92)
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
		cell.add_theme_constant_override("separation", 4)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(96, 96)
		btn.focus_mode = Control.FOCUS_NONE
		var empty := StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty)
		btn.add_theme_stylebox_override("hover", empty)
		btn.add_theme_stylebox_override("pressed", empty)
		var key := str(a["key"])
		var tint := UniverseUI.app_colour(key)
		var icon := UniverseUI.app_icon(key, 96, tint)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.add_child(icon)
		btn.pressed.connect(func(): _open_app(key))
		cell.add_child(btn)
		if key == "chat":
			_drone_budz_badge = UniverseUI.label("", 10, UniverseUI.AMBER)
			_drone_budz_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(_drone_budz_badge)
		elif key == "studio":
			_studio_badge = UniverseUI.label("", 9, UniverseUI.AMBER)
			_studio_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(_studio_badge)
		var lab := UniverseUI.label(str(a["name"]), 11, UniverseUI.CREAM_DIM)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(lab)
		var kind := UniverseUI.label(str(a["kind"]).to_upper(), 8, UniverseUI.FAINT)
		kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(kind)
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
	# dock
	var dock := PanelContainer.new()
	var dsb := UniverseUI.box(Color(0.07, 0.085, 0.075, 0.96), 0, UniverseUI.LINE, 1, 26.0, 10.0)
	dsb.border_width_left = 0
	dsb.border_width_right = 0
	dsb.border_width_bottom = 0
	dock.add_theme_stylebox_override("panel", dsb)
	dock.custom_minimum_size = Vector2(0, 58)
	hcol.add_child(dock)
	var dm := MarginContainer.new()
	for m in ["left", "right"]:
		dm.add_theme_constant_override("margin_" + m, 30)
	dock.add_child(dm)
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 12)
	dm.add_child(drow)
	var home_btn := Button.new(); home_btn.text = "Home"; home_btn.theme_type_variation = "Ghost"
	home_btn.custom_minimum_size = Vector2(86, 36)
	home_btn.pressed.connect(_show_home)
	drow.add_child(home_btn)
	var recents := Button.new(); recents.text = "Recents"; recents.theme_type_variation = "Ghost"
	recents.custom_minimum_size = Vector2(96, 36)
	recents.pressed.connect(_show_switcher)
	drow.add_child(recents)
	var dock_gap := Control.new(); dock_gap.custom_minimum_size = Vector2(18, 0)
	drow.add_child(dock_gap)
	for pair in [["chat", "DroneBudz"], ["studio", "VidTube Studio"], ["photos", "Photos"], ["market", "Facade"]]:
		var dock_btn := Button.new()
		dock_btn.custom_minimum_size = Vector2(44, 44)
		dock_btn.tooltip_text = str(pair[1])
		dock_btn.focus_mode = Control.FOCUS_NONE
		var empty := StyleBoxEmpty.new()
		dock_btn.add_theme_stylebox_override("normal", empty)
		dock_btn.add_theme_stylebox_override("hover", UniverseUI.box(Color(1, 1, 1, 0.06), 10, Color(0, 0, 0, 0), 0, 0.0, 0.0))
		dock_btn.add_theme_stylebox_override("pressed", UniverseUI.box(Color(1, 1, 1, 0.10), 10, Color(0, 0, 0, 0), 0, 0.0, 0.0))
		var der := str(pair[0])
		var dicon := UniverseUI.app_icon(der, 40, UniverseUI.app_colour(der))
		dicon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dock_btn.add_child(dicon)
		dock_btn.pressed.connect(func(): _open_app(der))
		drow.add_child(dock_btn)
	var st2 := Control.new(); st2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drow.add_child(st2)
	var put_away := Button.new(); put_away.text = "Put phone away  (Tab)"; put_away.theme_type_variation = "Ghost"
	put_away.custom_minimum_size = Vector2(176, 36)
	put_away.pressed.connect(close)
	drow.add_child(put_away)
	# app host
	_apps = Control.new()
	_apps.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apps.offset_top = 38.0
	_apps.offset_bottom = -54.0
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
	_build_system_nav()
	visible = false

func open() -> void:
	_open = true
	visible = true
	_show_home()
	_refresh()

## The persistent bottom tablet bar: every app gets the same Home, app title, Recents and Put away controls.
func _build_system_nav() -> void:
	_sys_nav = PanelContainer.new()
	_sys_nav.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_sys_nav.offset_top = -54.0
	_sys_nav.z_index = 40
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.045, 0.055, 0.048, 0.97)
	sb.border_width_top = 1
	sb.border_color = UniverseUI.LINE_STRONG
	_sys_nav.add_theme_stylebox_override("panel", sb)
	_root.add_child(_sys_nav)
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 24)
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 6)
	_sys_nav.add_child(m)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	m.add_child(row)
	var home_btn := Button.new()
	home_btn.text = "Home"
	home_btn.theme_type_variation = "Ghost"
	home_btn.custom_minimum_size = Vector2(92, 38)
	home_btn.pressed.connect(_show_home)
	row.add_child(home_btn)
	_sys_nav_name = UniverseUI.label("", 12, UniverseUI.MUTED)
	_sys_nav_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sys_nav_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sys_nav_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_sys_nav_name)
	var recents_btn := Button.new()
	recents_btn.text = "Recents"
	recents_btn.theme_type_variation = "Ghost"
	recents_btn.custom_minimum_size = Vector2(100, 38)
	recents_btn.pressed.connect(_show_switcher)
	row.add_child(recents_btn)
	var hide_btn := Button.new()
	hide_btn.text = "Put away"
	hide_btn.theme_type_variation = "Ghost"
	hide_btn.custom_minimum_size = Vector2(110, 38)
	hide_btn.pressed.connect(close)
	row.add_child(hide_btn)
	_sys_nav.visible = false

func _update_system_nav(app_key: String) -> void:
	if _sys_nav == null:
		return
	_sys_nav.visible = app_key != "home" and app_key != "switcher"
	_sys_nav_name.text = _app_title(app_key).to_upper() + "   ·   HALLOWAY PERSONAL"

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
		_: return "Home"
func close() -> void:
	_open = false
	visible = false
	_switcher.visible = false
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
	_update_system_nav("home")
	_refresh()

func _show_switcher() -> void:
	_current_app = "switcher"
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
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(grid)
	var apps := [
		{"key": "chat", "name": "DroneBudz", "desc": "The crew's Discord-style server: channels, DMs, jobs talk"},
		{"key": "studio", "name": "VidTube Studio", "desc": "The channel's numbers, uploads and editor"},
		{"key": "photos", "name": "Photos", "desc": "Everything the drone has photographed"},
		{"key": "jobs", "name": "Jobs", "desc": "Paid work on the valley board"},
		{"key": "casebook", "name": "Casebook", "desc": "Rennick's file, evidence and chapter trail"},
		{"key": "market", "name": "Facade", "desc": "The valley classifieds: drones, cameras, motors and parts"},
		{"key": "map", "name": "Map", "desc": "The valley road map and launch sites"},
	]
	for a in apps:
		var key := str(a["key"])
		var card := PanelContainer.new()
		var csb := UniverseUI.card(14, UniverseUI.CARD, UniverseUI.AMBER if key == _current_app else UniverseUI.LINE, 1)
		card.add_theme_stylebox_override("panel", csb)
		grid.add_child(card)
		var cm := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			cm.add_theme_constant_override("margin_" + side, 10)
		card.add_child(cm)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		cm.add_child(row)
		var icon := UniverseUI.app_icon(key, 48, UniverseUI.app_colour(key))
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 1)
		row.add_child(text)
		text.add_child(UniverseUI.label(str(a["name"]), 15, UniverseUI.CREAM))
		var d := UniverseUI.label(str(a["desc"]), 11, UniverseUI.MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(d)
		var open_btn := Button.new(); open_btn.text = "Open"; open_btn.theme_type_variation = "Primary"
		open_btn.custom_minimum_size = Vector2(66, 32)
		open_btn.add_theme_font_size_override("font_size", 12)
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
		if _drone_budz_badge != null:
			var unread := chat.unread_total()
			_drone_budz_badge.text = (("9+ NEW" if unread > 9 else "%d NEW" % unread) if unread > 0 else "")
	if _field_weather != null and hud != null:
		var temp2 := float(hud.weather.get("temp", 10.0))
		var wind2 := float(hud.weather.get("wind", 3.0))
		_field_weather.text = "%.0f°C, wind %.1f m/s. The valley is holding its autumn colour." % [temp2, wind2]
	if _field_crew != null:
		var unread2 := chat.unread_total() if chat != null else 0
		_field_crew.text = "CREW  ·  %d on the server" % (chat.member_count() if chat != null else 0) + (("   9+ unread" if unread2 > 9 else "   %d unread" % unread2) if unread2 > 0 else "")
	if _field_case != null:
		_field_case.text = "CASEBOOK  ·  " + (story.current_status() if story != null else "No case yet.")
	if _studio_badge != null:
		var rushes := clips.rushes().size() if clips != null else 0
		_studio_badge.text = ("%d RUSHES" % rushes) if rushes > 0 else ""
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
		_status_sig.text = "LINK   ·   %d%%" % int(round(_battery_pct * 100.0))
	if _current_app == "studio" and _studio_app.visible:
		_studio_app.refresh()

## The drone battery, pushed from main while the phone is open. The dial reads this.
func set_battery(pct: float) -> void:
	_battery_pct = clampf(pct, 0.0, 1.0)
	if _status_sig != null:
		_status_sig.text = "LINK   ·   %d%%" % int(round(_battery_pct * 100.0))
	if _battery_dial != null and _open:
		_battery_dial.set_dial("battery", _battery_pct, "DRONE", UniverseUI.MOSS if _battery_pct > 0.25 else UniverseUI.RUST)

func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _current_app != "home":
			_show_home()
		else:
			close()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _open:
		_refresh()

func stats() -> Dictionary:
	return {"open": _open, "app": _current_app, "chat": chat.stats(), "followers": jobs.followers() if jobs else 0}

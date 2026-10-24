class_name PhoneOS
extends CanvasLayer
## The in-game phone (session B): a home screen, an app switcher and full-screen apps, opened with Tab.
##
## The phone exists because the DroneBudz story lives in apps: a Discord-style server where the crew talk about the
## channel, a Studio app with the two numbers that matter (followers and money), the photo library, and the jobs board.
## It sits under the gallery and jobs pages so those can open on top of it, and closing them returns to the phone.
##
## The sandbox keeps running behind the phone on purpose: there is no forced pause and nothing in here gates flying.
## Nothing here writes to disk except the chat and job state their own classes already keep.

var hud: Hud
var jobs: Jobs
var photos: PhotoLibrary
var chat: ChatData
var crew: Crew
var _chat_app: ChatApp
var _studio_app: StudioApp
var story: StoryArc
var _casebook_app: CasebookApp
var _root: Control
var _home: Control
var _apps: Control
var _switcher: Control
var _clock: Label
var _metrics: Label
var _drone_budz_badge: Label
var _open := false
var _current_app := "home"

func setup(h: Hud, j: Jobs, p: PhotoLibrary, c: ChatData, cr: Crew, st: StoryArc) -> void:
	hud = h
	jobs = j
	photos = p
	chat = c
	crew = cr
	story = st
	layer = 28
	_build()
	_show_home()

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	# wallpaper
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.055, 0.065, 0.075, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	var glow := PanelContainer.new()
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(0.10, 0.28, 0.22, 0.28)
	gsb.set_corner_radius_all(280)
	glow.add_theme_stylebox_override("panel", gsb)
	glow.position = Vector2(-140, -180)
	glow.custom_minimum_size = Vector2(560, 560)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(glow)
	# status bar
	var status := MarginContainer.new()
	status.set_anchors_preset(Control.PRESET_TOP_WIDE)
	status.offset_bottom = 36
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for m in ["left", "right"]:
		status.add_theme_constant_override("margin_" + m, 24)
	_root.add_child(status)
	var st := HBoxContainer.new()
	st.add_theme_constant_override("separation", 10)
	status.add_child(st)
	_clock = Label.new()
	_clock.add_theme_font_size_override("font_size", 13)
	_clock.add_theme_color_override("font_color", Color(0.85, 0.88, 0.90))
	_clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.add_child(_clock)
	var carrier := Label.new()
	carrier.text = "DroneBudz"
	carrier.add_theme_font_size_override("font_size", 12)
	carrier.add_theme_color_override("font_color", Color(0.62, 0.68, 0.66))
	carrier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carrier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.add_child(carrier)
	var sig := Label.new()
	sig.text = "LTE   ▮▮▮   100%"
	sig.add_theme_font_size_override("font_size", 12)
	sig.add_theme_color_override("font_color", Color(0.78, 0.81, 0.84))
	st.add_child(sig)
	# home screen
	_home = Control.new()
	_home.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_home)
	var hcol := VBoxContainer.new()
	hcol.set_anchors_preset(Control.PRESET_FULL_RECT)
	hcol.add_theme_constant_override("separation", 8)
	_home.add_child(hcol)
	var hm := MarginContainer.new()
	for m in ["left", "right"]:
		hm.add_theme_constant_override("margin_" + m, 40)
	for m in ["top", "bottom"]:
		hm.add_theme_constant_override("margin_" + m, 18)
	hm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hcol.add_child(hm)
	var hbox := VBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hm.add_child(hbox)
	var big := Label.new()
	big.name = "BigClock"
	big.add_theme_font_size_override("font_size", 46)
	big.add_theme_color_override("font_color", Color(0.94, 0.95, 0.96))
	hbox.add_child(big)
	_metrics = Label.new()
	_metrics.add_theme_font_size_override("font_size", 15)
	_metrics.add_theme_color_override("font_color", Color(0.66, 0.74, 0.70))
	hbox.add_child(_metrics)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	hbox.add_child(gap)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 26)
	hbox.add_child(grid)
	var apps := [
		{"key": "chat", "letter": "DB", "name": "DroneBudz", "colour": Color(0.20, 0.45, 0.34)},
		{"key": "studio", "letter": "VT", "name": "VidTube", "colour": Color(0.62, 0.34, 0.26)},
		{"key": "photos", "letter": "PH", "name": "Photos", "colour": Color(0.24, 0.38, 0.58)},
		{"key": "jobs", "letter": "JB", "name": "Jobs", "colour": Color(0.50, 0.40, 0.18)},
		{"key": "casebook", "letter": "CB", "name": "Casebook", "colour": Color(0.34, 0.38, 0.55)},
	]
	for a in apps:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(108, 108)
		var sb := StyleBoxFlat.new()
		sb.bg_color = a["colour"]
		sb.set_corner_radius_all(24)
		btn.add_theme_stylebox_override("normal", sb)
		var sbh := sb.duplicate() as StyleBoxFlat
		sbh.bg_color = (a["colour"] as Color).lightened(0.15)
		btn.add_theme_stylebox_override("hover", sbh)
		btn.text = str(a["letter"])
		btn.add_theme_font_size_override("font_size", 30)
		btn.add_theme_color_override("font_color", Color(0.96, 0.97, 0.98))
		var key := str(a["key"])
		btn.pressed.connect(func(): _open_app(key))
		cell.add_child(btn)
		if key == "chat":
			_drone_budz_badge = Label.new()
			_drone_budz_badge.add_theme_font_size_override("font_size", 11)
			_drone_budz_badge.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35))
			_drone_budz_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(_drone_budz_badge)
		var lab := Label.new()
		lab.text = str(a["name"])
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 13)
		lab.add_theme_color_override("font_color", Color(0.84, 0.86, 0.88))
		cell.add_child(lab)
		grid.add_child(cell)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(filler)
	var tip := Label.new()
	tip.text = "Land to check the phone. Tab opens and closes it, Esc closes an app."
	tip.add_theme_font_size_override("font_size", 12)
	tip.add_theme_color_override("font_color", Color(0.52, 0.56, 0.60))
	hbox.add_child(tip)
	# dock
	var dock := PanelContainer.new()
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0.08, 0.09, 0.10, 0.95)
	dsb.border_width_top = 1
	dsb.border_color = Color(1, 1, 1, 0.06)
	dock.add_theme_stylebox_override("panel", dsb)
	dock.custom_minimum_size = Vector2(0, 62)
	hcol.add_child(dock)
	var dm := MarginContainer.new()
	for m in ["left", "right"]:
		dm.add_theme_constant_override("margin_" + m, 30)
	dock.add_child(dm)
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 18)
	dm.add_child(drow)
	var home_btn := Button.new(); home_btn.text = "Home"; home_btn.flat = true
	home_btn.add_theme_font_size_override("font_size", 15)
	home_btn.pressed.connect(_show_home)
	drow.add_child(home_btn)
	var recents := Button.new(); recents.text = "Recents"; recents.flat = true
	recents.add_theme_font_size_override("font_size", 15)
	recents.pressed.connect(_show_switcher)
	drow.add_child(recents)
	var st2 := Control.new(); st2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drow.add_child(st2)
	var put_away := Button.new(); put_away.text = "Put phone away (Tab)"; put_away.flat = true
	put_away.add_theme_font_size_override("font_size", 14)
	put_away.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78))
	put_away.pressed.connect(close)
	drow.add_child(put_away)
	# app host
	_apps = Control.new()
	_apps.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	_studio_app.setup(hud, jobs, chat, photos)
	_studio_app.chat_requested.connect(func(): _open_app("chat"))
	_studio_app.jobs_requested.connect(func(): jobs.open_page())
	_studio_app.upload_requested.connect(func(): photos.open_gallery())
	_casebook_app = CasebookApp.new()
	_casebook_app.set_anchors_preset(Control.PRESET_FULL_RECT)
	_casebook_app.visible = false
	_apps.add_child(_casebook_app)
	_casebook_app.setup(story, photos)
	_casebook_app.chat_requested.connect(func():
		_open_app("chat")
		_chat_app.open("town"))
	# switcher
	_switcher = Control.new()
	_switcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_switcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_switcher.visible = false
	_root.add_child(_switcher)
	var sdim := ColorRect.new()
	sdim.set_anchors_preset(Control.PRESET_FULL_RECT)
	sdim.color = Color(0.02, 0.02, 0.03, 0.78)
	sdim.mouse_filter = Control.MOUSE_FILTER_STOP
	_switcher.add_child(sdim)
	visible = false

func open() -> void:
	_open = true
	visible = true
	_show_home()
	_refresh()

func close() -> void:
	_open = false
	visible = false
	_switcher.visible = false

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
	_refresh()

func _show_switcher() -> void:
	_current_app = "switcher"
	for c in _switcher.get_children():
		if c is PanelContainer:
			c.queue_free()
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.125, 0.98)
	sb.set_corner_radius_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	_switcher.add_child(panel)
	panel.anchor_left = 0.12; panel.anchor_right = 0.88
	panel.anchor_top = 0.16; panel.anchor_bottom = 0.84
	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 20)
	panel.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	m.add_child(col)
	var h := Label.new()
	h.text = "Recents"
	h.add_theme_font_size_override("font_size", 24)
	h.add_theme_color_override("font_color", Color(0.95, 0.96, 0.97))
	col.add_child(h)
	var apps := [
		{"key": "chat", "name": "DroneBudz", "desc": "The crew's Discord-style server: chat, jobs, channel talk"},
		{"key": "studio", "name": "VidTube", "desc": "The channel on VidTube: followers, views, earnings and videos"},
		{"key": "photos", "name": "Photos", "desc": "The gallery of everything the drone has taken"},
		{"key": "jobs", "name": "Jobs", "desc": "Paid work on the board, ready to accept"},
		{"key": "casebook", "name": "Casebook", "desc": "Rennick's case: the requests, the evidence and the chapter trail"},
	]
	for a in apps:
		var b := Button.new()
		b.text = "%s   ·   %s" % [str(a["name"]), str(a["desc"])]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 62)
		b.add_theme_font_size_override("font_size", 15)
		var key := str(a["key"])
		b.pressed.connect(func(): _open_app(key))
		col.add_child(b)
	_switcher.visible = true

func _open_app(key: String) -> void:
	_switcher.visible = false
	match key:
		"chat":
			_current_app = "chat"
			_home.visible = false
			_apps.visible = true
			_studio_app.visible = false
			_casebook_app.visible = false
			_chat_app.visible = true
			_chat_app.open("general")
			chat.unread_total()
		"studio":
			_current_app = "studio"
			_home.visible = false
			_apps.visible = true
			_chat_app.visible = false
			_casebook_app.visible = false
			_studio_app.visible = true
			_studio_app.refresh()
		"casebook":
			_current_app = "casebook"
			_home.visible = false
			_apps.visible = true
			_chat_app.visible = false
			_studio_app.visible = false
			_casebook_app.visible = true
			_casebook_app.refresh()
		"photos":
			if photos != null:
				photos.open_gallery()
		"jobs":
			if jobs != null:
				jobs.open_page()
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
	if jobs != null:
		_metrics.text = "%d followers      $%d" % [jobs.followers(), jobs.money()]
		if _drone_budz_badge != null:
			var unread := chat.unread_total()
			_drone_budz_badge.text = ("%d new" % unread) if unread > 0 else ""
	if _current_app == "studio" and _studio_app.visible:
		_studio_app.refresh()

func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _open and _current_app == "home":
		_refresh()

func stats() -> Dictionary:
	return {"open": _open, "app": _current_app, "chat": chat.stats(), "followers": jobs.followers() if jobs else 0}

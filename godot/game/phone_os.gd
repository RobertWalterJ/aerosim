class_name PhoneOS
extends CanvasLayer
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
var _root: Control
var _home: Control
var _apps: Control
var _switcher: Control
var _switcher_panel: PanelContainer
var _clock: Label
var _metrics: Label
var _weather: Label
var _field_weather: Label
var _field_crew: Label
var _field_case: Label
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
	_root.theme = UniverseUI.make_theme()
	add_child(_root)
	var bg := PhoneBackground.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	# status bar
	var status := MarginContainer.new()
	status.set_anchors_preset(Control.PRESET_TOP_WIDE)
	status.offset_bottom = 40
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for m in ["left", "right"]:
		status.add_theme_constant_override("margin_" + m, 30)
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
	var sig := UniverseUI.label("LTE   ▮▮▮   100%", 10, UniverseUI.MUTED)
	st.add_child(sig)
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
	hm.add_theme_constant_override("margin_top", 70)
	hm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hcol.add_child(hm)
	var hbox := VBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	hm.add_child(hbox)
	var date := UniverseUI.label("AUTUMN  ·  NORTH VALLEY  ·  47°N", 10, UniverseUI.AMBER)
	hbox.add_child(date)
	var big := UniverseUI.label("00:00", 56, UniverseUI.CREAM)
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
	gap.custom_minimum_size = Vector2(0, 34)
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
	note.custom_minimum_size = Vector2(300, 0)
	note.add_theme_stylebox_override("panel", UniverseUI.card(16, Color(0.075, 0.090, 0.078, 0.92)))
	content.add_child(note)
	var nm := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		nm.add_theme_constant_override("margin_" + m, 16)
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
	]
	for a in apps:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 7)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(112, 112)
		btn.focus_mode = Control.FOCUS_NONE
		var tint := UniverseUI.app_colour(str(a["key"]))
		var sb := UniverseUI.box(tint.darkened(0.58), 25, Color(tint.r, tint.g, tint.b, 0.36), 1, 0.0, 0.0)
		sb.shadow_color = Color(0, 0, 0, 0.34)
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, 3)
		btn.add_theme_stylebox_override("normal", sb)
		var sbh := sb.duplicate() as StyleBoxFlat
		sbh.bg_color = tint.darkened(0.46)
		btn.add_theme_stylebox_override("hover", sbh)
		var sbp := sb.duplicate() as StyleBoxFlat
		sbp.bg_color = tint.darkened(0.32)
		btn.add_theme_stylebox_override("pressed", sbp)
		btn.text = str(a["letter"])
		btn.add_theme_font_size_override("font_size", 29)
		btn.add_theme_color_override("font_color", UniverseUI.CREAM)
		var key := str(a["key"])
		btn.pressed.connect(func(): _open_app(key))
		cell.add_child(btn)
		if key == "chat":
			_drone_budz_badge = UniverseUI.label("", 10, UniverseUI.AMBER)
			_drone_budz_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(_drone_budz_badge)
		var lab := UniverseUI.label(str(a["name"]), 12, UniverseUI.CREAM_DIM)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(lab)
		var kind := UniverseUI.label(str(a["kind"]).to_upper(), 9, UniverseUI.FAINT)
		kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(kind)
		grid.add_child(cell)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(filler)
	var tip_card := PanelContainer.new()
	tip_card.theme_type_variation = "FlatCard"
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
	dock.custom_minimum_size = Vector2(0, 62)
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
	var st2 := Control.new(); st2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drow.add_child(st2)
	var put_away := Button.new(); put_away.text = "Put phone away  (Tab)"; put_away.theme_type_variation = "Ghost"
	put_away.custom_minimum_size = Vector2(176, 36)
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
	sdim.color = Color(0.02, 0.03, 0.025, 0.82)
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
		var icon := PanelContainer.new()
		icon.custom_minimum_size = Vector2(48, 48)
		var tint := UniverseUI.app_colour(key)
		icon.add_theme_stylebox_override("panel", UniverseUI.box(tint.darkened(0.5), 13, Color(tint.r, tint.g, tint.b, 0.5), 1, 0.0, 0.0))
		var il := UniverseUI.label(_app_letter(key), 17, UniverseUI.CREAM)
		il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		il.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.add_child(il)
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
	return "?"

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
	if hud != null:
		var temp := float(hud.weather.get("temp", 10.0))
		var wind := float(hud.weather.get("wind", 3.0))
		_weather.text = "%.0f°C   WIND %.1f m/s" % [temp, wind]
	if jobs != null:
		_metrics.text = "%d FOLLOWERS   ·   $%d" % [jobs.followers(), jobs.money()]
		if _drone_budz_badge != null:
			var unread := chat.unread_total()
			_drone_budz_badge.text = ("%d NEW" % unread) if unread > 0 else ""
	if _field_weather != null and hud != null:
		var temp2 := float(hud.weather.get("temp", 10.0))
		var wind2 := float(hud.weather.get("wind", 3.0))
		_field_weather.text = "%.0f°C, wind %.1f m/s. The valley is holding its autumn colour." % [temp2, wind2]
	if _field_crew != null:
		var unread2 := chat.unread_total() if chat != null else 0
		_field_crew.text = "CREW  ·  6 on the server" + (("   %d unread" % unread2) if unread2 > 0 else "")
	if _field_case != null:
		_field_case.text = "CASEBOOK  ·  " + (story.current_status() if story != null else "No case yet.")
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

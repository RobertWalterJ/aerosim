class_name StudioApp
extends Control
## VidTube Studio (session B UI pass): the channel's numbers, uploads and editor, in the voice of a small valley
## broadcaster. Rust and cream, a channel card, four honest counters and a list of what has been published.
##
## Followers and money are the two things the crew cares about. Money comes from paid jobs and pays for gear and
## travel; followers are the audience and bring the next job. Read only, nothing is spent here yet.

signal chat_requested
signal jobs_requested
signal upload_requested
signal market_requested

var hud: Hud
var jobs: Jobs
var chat: ChatData
var photos: PhotoLibrary
var _followers: Label
var _money: Label
var _videos: Label
var _views: Label
var _editor_label: Label
var _list: VBoxContainer

func setup(h: Hud, j: Jobs, c: ChatData, p: PhotoLibrary) -> void:
	hud = h
	jobs = j
	chat = c
	photos = p
	_build()

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UniverseUI.make_theme()
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.045, 0.055, 0.048, 1.0)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	# ---------------- channel banner
	var banner := PanelContainer.new()
	banner.custom_minimum_size = Vector2(0, 146)
	banner.add_theme_stylebox_override("panel", UniverseUI.box(UniverseUI.DEEP, 0, UniverseUI.LINE, 1, 0.0, 0.0))
	col.add_child(banner)
	var bm := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		bm.add_theme_constant_override("margin_" + m, 22)
	banner.add_child(bm)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	bm.add_child(row)
	var mark := PanelContainer.new()
	mark.custom_minimum_size = Vector2(78, 78)
	mark.add_theme_stylebox_override("panel", UniverseUI.box(UniverseUI.RUST.darkened(0.32), 20, UniverseUI.RUST, 1, 0.0, 0.0))
	var mark_label := UniverseUI.label("DB", 24, UniverseUI.CREAM)
	mark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_child(mark_label)
	row.add_child(mark)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 1)
	row.add_child(text)
	text.add_child(UniverseUI.label("VIDTUBE  ·  STUDIO", 10, UniverseUI.AMBER))
	var title := UniverseUI.label("DroneBudz", 32, UniverseUI.CREAM)
	text.add_child(title)
	text.add_child(UniverseUI.label("Halloway Valley  ·  six crew  ·  one pilot  ·  whatever weather the valley gives us", 12, UniverseUI.MUTED))
	_editor_label = UniverseUI.label("", 11, UniverseUI.MOSS)
	text.add_child(_editor_label)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	row.add_child(actions)
	var chat_btn := Button.new()
	chat_btn.text = "Open DroneBudz"
	chat_btn.theme_type_variation = "Ghost"
	chat_btn.custom_minimum_size = Vector2(172, 36)
	chat_btn.pressed.connect(func(): chat_requested.emit())
	actions.add_child(chat_btn)
	var up_btn := Button.new()
	up_btn.text = "Upload from camera roll"
	up_btn.theme_type_variation = "Primary"
	up_btn.custom_minimum_size = Vector2(216, 38)
	up_btn.pressed.connect(func(): upload_requested.emit())
	actions.add_child(up_btn)
	var market_btn := Button.new()
	market_btn.text = "Spend on Facade"
	market_btn.theme_type_variation = "Ghost"
	market_btn.custom_minimum_size = Vector2(172, 34)
	market_btn.pressed.connect(func(): market_requested.emit())
	actions.add_child(market_btn)
	# ---------------- metrics
	var metrics_pad := MarginContainer.new()
	metrics_pad.add_theme_constant_override("margin_left", 22)
	metrics_pad.add_theme_constant_override("margin_right", 22)
	metrics_pad.add_theme_constant_override("margin_top", 16)
	col.add_child(metrics_pad)
	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 12)
	metrics_pad.add_child(metrics)
	var m1 := _metric("FOLLOWERS", "0", "the audience", UniverseUI.MOSS)
	_followers = m1["value"]
	metrics.add_child(m1["card"])
	var m2 := _metric("MONEY", "$0", "fuel and gear", UniverseUI.AMBER)
	_money = m2["value"]
	metrics.add_child(m2["card"])
	var m3 := _metric("VIDEOS", "0", "on the channel", UniverseUI.RUST)
	_videos = m3["value"]
	metrics.add_child(m3["card"])
	var m4 := _metric("VIEWS", "0", "all time", UniverseUI.LAKE)
	_views = m4["value"]
	metrics.add_child(m4["card"])
	# ---------------- uploads
	var body := MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for m in ["left", "right", "bottom"]:
		body.add_theme_constant_override("margin_" + m, 22)
	col.add_child(body)
	var bcol := VBoxContainer.new()
	bcol.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bcol.add_theme_constant_override("separation", 8)
	body.add_child(bcol)
	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 10)
	bcol.add_child(heading_row)
	var hcol := VBoxContainer.new()
	hcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hcol.add_theme_constant_override("separation", 0)
	heading_row.add_child(hcol)
	hcol.add_child(UniverseUI.label("UPLOADS", 10, UniverseUI.AMBER))
	hcol.add_child(UniverseUI.label("What the channel has made", 18, UniverseUI.CREAM))
	var jobs_btn := Button.new()
	jobs_btn.text = "Jobs board"
	jobs_btn.theme_type_variation = "Ghost"
	jobs_btn.custom_minimum_size = Vector2(112, 32)
	jobs_btn.pressed.connect(func(): jobs_requested.emit())
	heading_row.add_child(jobs_btn)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 160)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bcol.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)

func _metric(name: String, value: String, sub: String, accent: Color) -> Dictionary:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 86)
	var sb := UniverseUI.card(14)
	sb.border_width_left = 3
	sb.border_color = accent
	card.add_theme_stylebox_override("panel", sb)
	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 13)
	card.add_child(m)
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 0)
	m.add_child(c)
	c.add_child(UniverseUI.label(name, 9, UniverseUI.MUTED))
	var v := UniverseUI.label(value, 28, UniverseUI.CREAM)
	c.add_child(v)
	var sub_label := UniverseUI.label(sub, 10, accent)
	c.add_child(sub_label)
	return {"card": card, "value": v}

func refresh() -> void:
	if jobs != null:
		_followers.text = str(jobs.followers())
		_money.text = "$" + str(jobs.money())
		_views.text = str(jobs.views())
		if _editor_label != null:
			_editor_label.text = "EDITOR: Maya  ·  send a photo to #clips and she cuts it" if jobs.editor_friend() else "EDITOR: none yet  ·  uploads go straight to VidTube"
	var uploads: Array = jobs.videos() if jobs != null else []
	_videos.text = str(uploads.size())
	for ch in _list.get_children():
		ch.queue_free()
	if uploads.is_empty():
		var empty := PanelContainer.new()
		empty.add_theme_stylebox_override("panel", UniverseUI.card(14, UniverseUI.CARD))
		_list.add_child(empty)
		var em := MarginContainer.new()
		for s in ["left", "right", "top", "bottom"]:
			em.add_theme_constant_override("margin_" + s, 18)
		empty.add_child(em)
		var ecol := VBoxContainer.new()
		ecol.add_theme_constant_override("separation", 3)
		em.add_child(ecol)
		ecol.add_child(UniverseUI.label("No uploads yet", 18, UniverseUI.CREAM))
		var hint := UniverseUI.label("Finish a job or send a photo from the camera roll to #clips. Maya will cut it, or it goes straight to VidTube.", 12, UniverseUI.MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ecol.add_child(hint)
		return
	for up in uploads:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UniverseUI.card(12, UniverseUI.CARD))
		_list.add_child(row)
		var rm := MarginContainer.new()
		for s in ["left", "right", "top", "bottom"]:
			rm.add_theme_constant_override("margin_" + s, 10)
		row.add_child(rm)
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 12)
		rm.add_child(r)
		var thumb := PanelContainer.new()
		thumb.custom_minimum_size = Vector2(102, 58)
		thumb.add_theme_stylebox_override("panel", UniverseUI.box(UniverseUI.NIGHT, 9, UniverseUI.RUST, 1, 0.0, 0.0))
		var play := UniverseUI.label("▶", 20, UniverseUI.AMBER)
		play.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		play.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		thumb.add_child(play)
		r.add_child(thumb)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_constant_override("separation", 2)
		r.add_child(text)
		var edited := bool(up.get("edited", false))
		text.add_child(UniverseUI.label(str(up.get("title", "Clip")), 16, UniverseUI.CREAM))
		var tag := "EDITED BY MAYA" if edited else "DIRECT UPLOAD"
		text.add_child(UniverseUI.label(tag, 9, UniverseUI.MOSS if edited else UniverseUI.MUTED))
		var meta := UniverseUI.label("%d views   ·   +%d followers   ·   +$%d" % [int(up.get("views", 0)), int(up.get("followers", 0)), int(up.get("money", 0))], 11, UniverseUI.MUTED)
		text.add_child(meta)
		var num := UniverseUI.label(str(int(up.get("views", 0))), 20, UniverseUI.CREAM)
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		r.add_child(num)

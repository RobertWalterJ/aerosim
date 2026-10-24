class_name StudioApp
extends Control
## The DroneBudz Studio app: the channel's numbers and what it has made (session B).
##
## Followers and money are the two things the crew cares about. Money comes from paid jobs and pays for gear and
## travel; followers are the audience and bring the next job. This page shows both, the videos already made (completed
## jobs), the photos in the library, and a way into the chat and the jobs board. Read only, nothing is spent here yet.

signal chat_requested
signal jobs_requested
signal upload_requested

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
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	# banner
	var banner := PanelContainer.new()
	banner.custom_minimum_size = Vector2(0, 150)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.10, 0.13, 0.16)
	bsb.border_width_bottom = 3
	bsb.border_color = Color(0.35, 0.75, 0.55)
	banner.add_theme_stylebox_override("panel", bsb)
	col.add_child(banner)
	var bm := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		bm.add_theme_constant_override("margin_" + m, 22)
	banner.add_child(bm)
	var bcol := VBoxContainer.new()
	bcol.add_theme_constant_override("separation", 2)
	bm.add_child(bcol)
	var title := Label.new()
	title.text = "VidTube  ·  Studio"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.96, 0.97, 0.98))
	bcol.add_child(title)
	var sub := Label.new()
	sub.text = "The DroneBudz channel on VidTube. Six crew, one pilot, whatever weather the valley gives us."
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.70, 0.74, 0.78))
	bcol.add_child(sub)
	_editor_label = Label.new()
	_editor_label.add_theme_font_size_override("font_size", 13)
	_editor_label.add_theme_color_override("font_color", Color(0.60, 0.78, 0.66))
	bcol.add_child(_editor_label)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	bcol.add_child(btn_row)
	var chat_btn := Button.new()
	chat_btn.text = "Open DroneBudz chat"
	chat_btn.custom_minimum_size = Vector2(190, 38)
	chat_btn.pressed.connect(func(): chat_requested.emit())
	btn_row.add_child(chat_btn)
	var jobs_btn := Button.new()
	jobs_btn.text = "Jobs board"
	jobs_btn.custom_minimum_size = Vector2(130, 38)
	jobs_btn.pressed.connect(func(): jobs_requested.emit())
	btn_row.add_child(jobs_btn)
	var up_btn := Button.new()
	up_btn.text = "Upload from camera roll"
	up_btn.custom_minimum_size = Vector2(200, 38)
	up_btn.pressed.connect(func(): upload_requested.emit())
	btn_row.add_child(up_btn)
	# metrics row
	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 12)
	var pad := MarginContainer.new()
	for m in ["left", "right", "top"]:
		pad.add_theme_constant_override("margin_" + m, 22)
	pad.add_child(metrics)
	col.add_child(pad)
	var m1 := _metric("Followers", "0")
	_followers = m1["value"]
	metrics.add_child(m1["card"])
	var m2 := _metric("Money", "$0")
	_money = m2["value"]
	metrics.add_child(m2["card"])
	var m3 := _metric("Videos", "0")
	_videos = m3["value"]
	metrics.add_child(m3["card"])
	var m4 := _metric("Views", "0")
	_views = m4["value"]
	metrics.add_child(m4["card"])
	# content
	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var bp := MarginContainer.new()
	bp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for m in ["left", "right", "bottom"]:
		bp.add_theme_constant_override("margin_" + m, 22)
	bp.add_child(body)
	col.add_child(bp)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 10)
	body.add_child(gap2)
	var heading := Label.new()
	heading.text = "Videos on the channel"
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Color(0.94, 0.95, 0.96))
	body.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)

func _metric(name: String, value: String) -> Dictionary:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 92)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.135, 0.15)
	sb.set_corner_radius_all(14)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(1, 1, 1, 0.06)
	card.add_theme_stylebox_override("panel", sb)
	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 14)
	card.add_child(m)
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 2)
	m.add_child(c)
	var n := Label.new()
	n.text = name
	n.add_theme_font_size_override("font_size", 13)
	n.add_theme_color_override("font_color", Color(0.62, 0.66, 0.70))
	c.add_child(n)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 30)
	v.add_theme_color_override("font_color", Color(0.96, 0.96, 0.97))
	c.add_child(v)
	return {"card": card, "value": v}

func refresh() -> void:
	if jobs != null:
		_followers.text = str(jobs.followers())
		_money.text = "$" + str(jobs.money())
		_views.text = str(jobs.views())
		if _editor_label != null:
			_editor_label.text = "Editor: Maya (friend) · send a photo to #clips and she cuts it" if jobs.editor_friend() else "No editor yet · uploads go straight to VidTube"
	var st: Dictionary = jobs.stats() if jobs != null else {}
	var uploads: Array = jobs.videos() if jobs != null else []
	_videos.text = str(int(st.get("done", 0)) + uploads.size())
	for ch in _list.get_children():
		ch.queue_free()
	var names := {"lake": "Lake at golden hour", "chapel": "The chapel for the heritage page", "fireworks": "Festival fireworks coverage"}
	var done_ids: Array = []
	if jobs != null:
		done_ids = jobs._done.duplicate()
	if done_ids.is_empty() and uploads.is_empty():
		var none := Label.new()
		none.text = "No videos yet. Finish a job or upload a photo from the camera roll."
		none.add_theme_font_size_override("font_size", 15)
		none.add_theme_color_override("font_color", Color(0.66, 0.68, 0.72))
		_list.add_child(none)
		return
	for up in uploads:
		var row := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.135, 0.15)
		sb.set_corner_radius_all(10)
		row.add_theme_stylebox_override("panel", sb)
		var m := MarginContainer.new()
		for s in ["left", "right", "top", "bottom"]:
			m.add_theme_constant_override("margin_" + s, 12)
		row.add_child(m)
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 2)
		m.add_child(c)
		var t := Label.new()
		t.text = str(up.get("title", "Clip")) + ("  ·  edited by Maya" if bool(up.get("edited", false)) else "  ·  direct upload")
		t.add_theme_font_size_override("font_size", 16)
		t.add_theme_color_override("font_color", Color(0.92, 0.93, 0.95))
		c.add_child(t)
		var d := Label.new()
		d.text = "%d views · +%d followers · +$%d" % [int(up.get("views", 0)), int(up.get("followers", 0)), int(up.get("money", 0))]
		d.add_theme_font_size_override("font_size", 12)
		d.add_theme_color_override("font_color", Color(0.62, 0.72, 0.66))
		c.add_child(d)
		_list.add_child(row)
	for jid in done_ids:
		var row := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.135, 0.15)
		sb.set_corner_radius_all(10)
		row.add_theme_stylebox_override("panel", sb)
		var m := MarginContainer.new()
		for s in ["left", "right", "top", "bottom"]:
			m.add_theme_constant_override("margin_" + s, 12)
		row.add_child(m)
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 2)
		m.add_child(c)
		var t := Label.new()
		t.text = str(names.get(str(jid), str(jid)))
		t.add_theme_font_size_override("font_size", 16)
		t.add_theme_color_override("font_color", Color(0.92, 0.93, 0.95))
		c.add_child(t)
		var d := Label.new()
		d.text = "Published on the channel. The crew is still talking about it in #clips."
		d.add_theme_font_size_override("font_size", 12)
		d.add_theme_color_override("font_color", Color(0.62, 0.65, 0.69))
		c.add_child(d)
		_list.add_child(row)

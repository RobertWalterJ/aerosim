class_name ChatApp
extends Control
## The DroneBudz app: a Discord-style server for the crew (session B).
##
## Left: the server name and the channel list with unread dots. Right: the channel header and topic, the messages in
## order (avatars, names, times, system job events, the player's own posts) and an input where the player can type.
## The look follows a real chat client: dark slate panels, one wide message column, no bubbles, a thin divider per day.
## The app is hosted by game/phone_os.gd; it never forces anything, and the sandbox keeps running behind it.

var chat: ChatData
var hud: Hud
var jobs: Jobs
var photos: PhotoLibrary
var crew: Crew
var _current := "general"
var _sidebar_channels: VBoxContainer
var _messages: VBoxContainer
var _scroll: ScrollContainer
var _title: Label
var _topic: Label
var _input: LineEdit
var _crew_label: Label
var _root: HBoxContainer
var _build_t := 0.0

func setup(c: ChatData, h: Hud, j: Jobs, p: PhotoLibrary, cr: Crew) -> void:
	chat = c
	hud = h
	jobs = j
	photos = p
	crew = cr
	_build()

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_root = HBoxContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_theme_constant_override("separation", 0)
	add_child(_root)
	# ---------------- server sidebar
	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(250, 0)
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.17, 0.18, 0.20, 1.0)
	side.add_theme_stylebox_override("panel", ssb)
	_root.add_child(side)
	var side_col := VBoxContainer.new()
	side.add_child(side_col)
	var server := PanelContainer.new()
	var srv_sb := StyleBoxFlat.new()
	srv_sb.bg_color = Color(0.13, 0.14, 0.16, 1.0)
	srv_sb.border_width_bottom = 1
	srv_sb.border_color = Color(1, 1, 1, 0.06)
	server.add_theme_stylebox_override("panel", srv_sb)
	side_col.add_child(server)
	var srv := Label.new()
	srv.text = "  DroneBudz"
	srv.add_theme_font_size_override("font_size", 20)
	srv.add_theme_color_override("font_color", Color(0.96, 0.96, 0.97))
	srv.custom_minimum_size = Vector2(0, 56)
	srv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	server.add_child(srv)
	var chan_pad := MarginContainer.new()
	for m in ["left", "right", "top"]:
		chan_pad.add_theme_constant_override("margin_" + m, 10)
	side_col.add_child(chan_pad)
	_sidebar_channels = VBoxContainer.new()
	_sidebar_channels.add_theme_constant_override("separation", 2)
	chan_pad.add_child(_sidebar_channels)
	var stretch := Control.new()
	stretch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_col.add_child(stretch)
	var me := PanelContainer.new()
	var me_sb := StyleBoxFlat.new()
	me_sb.bg_color = Color(0.13, 0.14, 0.16, 1.0)
	me.add_theme_stylebox_override("panel", me_sb)
	side_col.add_child(me)
	var me_margin := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		me_margin.add_theme_constant_override("margin_" + m, 10)
	me.add_child(me_margin)
	var me_box := VBoxContainer.new()
	me_box.add_theme_constant_override("separation", 2)
	me_margin.add_child(me_box)
	var me_name := Label.new()
	me_name.text = "You  ·  pilot"
	me_name.add_theme_font_size_override("font_size", 14)
	me_name.add_theme_color_override("font_color", Color(0.86, 0.87, 0.90))
	me_box.add_child(me_name)
	_crew_label = Label.new()
	_crew_label.add_theme_font_size_override("font_size", 12)
	_crew_label.add_theme_color_override("font_color", Color(0.66, 0.68, 0.72))
	me_box.add_child(_crew_label)
	# ---------------- main column
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 0)
	_root.add_child(main)
	var head := PanelContainer.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.20, 0.21, 0.23, 1.0)
	hsb.border_width_bottom = 1
	hsb.border_color = Color(0, 0, 0, 0.35)
	head.add_theme_stylebox_override("panel", hsb)
	main.add_child(head)
	var hm := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		hm.add_theme_constant_override("margin_" + m, 14)
	head.add_child(hm)
	var hcol := VBoxContainer.new()
	hcol.add_theme_constant_override("separation", 1)
	hm.add_child(hcol)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", Color(0.96, 0.96, 0.97))
	hcol.add_child(_title)
	_topic = Label.new()
	_topic.add_theme_font_size_override("font_size", 12)
	_topic.add_theme_color_override("font_color", Color(0.64, 0.66, 0.70))
	hcol.add_child(_topic)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(_scroll)
	_messages = VBoxContainer.new()
	_messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_messages.add_theme_constant_override("separation", 2)
	_scroll.add_child(_messages)
	var input_row := PanelContainer.new()
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0.20, 0.21, 0.23, 1.0)
	input_row.add_theme_stylebox_override("panel", isb)
	main.add_child(input_row)
	var im := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		im.add_theme_constant_override("margin_" + m, 10)
	input_row.add_child(im)
	var in_col := VBoxContainer.new()
	in_col.add_theme_constant_override("separation", 6)
	im.add_child(in_col)
	# quick asks: each friend gives a different kind of answer (Sam weather, Tom storms, Alex gear, Riley places, Jo jobs, Maya edits)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	in_col.add_child(chips)
	for pair in [["Weather?", "weather", "Sam"], ["Storm?", "storm", "Tom"], ["Gear?", "gear", "Alex"],
			["Where to fly?", "spot", "Riley"], ["Jobs?", "jobs", "Jo"], ["Edit?", "edit", "Maya"]]:
		var b := Button.new()
		b.text = str(pair[0])
		b.tooltip_text = "Ask " + str(pair[2])
		b.add_theme_font_size_override("font_size", 12)
		b.custom_minimum_size = Vector2(0, 26)
		var key := str(pair[1])
		b.pressed.connect(func(): _ask(key))
		chips.add_child(b)
	var in_row := HBoxContainer.new()
	in_row.add_theme_constant_override("separation", 8)
	in_col.add_child(in_row)
	_input = LineEdit.new()
	_input.placeholder_text = "Message #general"
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.custom_minimum_size = Vector2(0, 40)
	_input.text_submitted.connect(func(_t): _send())
	in_row.add_child(_input)
	var send := Button.new()
	send.text = "Send"
	send.custom_minimum_size = Vector2(84, 40)
	send.pressed.connect(_send)
	in_row.add_child(send)
	_refresh_sidebar()

func open(channel := "general") -> void:
	visible = true
	_current = channel
	_refresh_sidebar()
	_refresh_channel()

func _refresh_sidebar() -> void:
	for c in _sidebar_channels.get_children():
		c.queue_free()
	for ch in chat.channels():
		var id := str(ch["id"])
		var b := Button.new()
		var unread := chat.unread(id)
		b.text = "  #  " + str(ch["name"]) + (("   (%d)" % unread) if unread > 0 else "")
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 34)
		b.add_theme_font_size_override("font_size", 15)
		var selected := id == _current
		b.add_theme_color_override("font_color", Color(0.96, 0.96, 0.97) if selected else Color(0.66, 0.68, 0.72))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.07) if selected else Color(0, 0, 0, 0)
		sb.set_corner_radius_all(6)
		b.add_theme_stylebox_override("normal", sb)
		b.pressed.connect(func(): open(id))
		_sidebar_channels.add_child(b)
	_crew_label.text = "%d followers · %d money" % [jobs.followers(), jobs.money()] if jobs != null else ""

func _refresh_channel() -> void:
	var ch := chat.channel_info(_current)
	_title.text = "#  " + str(ch.get("name", _current))
	_topic.text = str(ch.get("topic", ""))
	_input.placeholder_text = "Message #" + str(ch.get("name", _current))
	for m in _messages.get_children():
		m.queue_free()
	var msgs := chat.messages(_current)
	var last_key := ""
	for msg in msgs:
		var key := str(msg.get("from", "")) + "|" + _plain_text(str(msg.get("text", "")))
		if key == last_key:
			continue
		last_key = key
		_messages.add_child(_message_row(msg))
	_refresh_sidebar()
	await get_tree().process_frame
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func _message_row(msg: Dictionary) -> Control:
	var from := str(msg.get("from", ""))
	var system := bool(msg.get("system", false))
	var mine := bool(msg.get("mine", false))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var pad := MarginContainer.new()
	for m in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + m, 14)
	for m in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + m, 5)
	pad.add_child(row)
	# avatar
	var av := PanelContainer.new()
	av.custom_minimum_size = Vector2(38, 38)
	var asb := StyleBoxFlat.new()
	asb.bg_color = chat.cast_colour(from)
	asb.set_corner_radius_all(19)
	av.add_theme_stylebox_override("panel", asb)
	row.add_child(av)
	var initial := Label.new()
	initial.text = from.substr(0, 1)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial.add_theme_font_size_override("font_size", 18)
	initial.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98))
	av.add_child(initial)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	row.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)
	var who := Label.new()
	who.text = from
	who.add_theme_font_size_override("font_size", 14)
	who.add_theme_color_override("font_color", chat.cast_colour(from) if not mine else Color(0.55, 0.80, 0.65))
	top.add_child(who)
	if not system:
		var role := Label.new()
		role.text = chat.cast_role(from)
		role.add_theme_font_size_override("font_size", 11)
		role.add_theme_color_override("font_color", Color(0.55, 0.57, 0.61))
		top.add_child(role)
	var tm := Label.new()
	tm.text = str(msg.get("time", ""))
	tm.add_theme_font_size_override("font_size", 11)
	tm.add_theme_color_override("font_color", Color(0.50, 0.52, 0.56))
	top.add_child(tm)
	var body := Label.new()
	body.text = str(msg.get("text", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.82, 0.84, 0.87) if not system else Color(0.62, 0.64, 0.68))
	col.add_child(body)
	var photo_id := int(msg.get("photo", -1))
	if photo_id >= 0 and photos != null:
		var tex := photos.texture_for(photo_id)
		if tex != null:
			var pic := TextureRect.new()
			pic.texture = tex
			pic.custom_minimum_size = Vector2(280, 158)
			pic.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			col.add_child(pic)
	return pad

func _send() -> void:
	var text := _input.text.strip_edges()
	if text == "":
		return
	chat.post(_current, "You", text, false, true)
	_input.text = ""
	# typed questions go to the friend whose job it is
	var low := text.to_lower()
	if crew != null:
		if low.contains("weather") or low.contains("forecast") or low.contains("wind"):
			crew.ask("weather", _current)
		elif low.contains("storm") or low.contains("tornado") or low.contains("funnel"):
			crew.ask("storm", _current)
		elif low.contains("gear") or low.contains("drone") or low.contains("lens") or low.contains("battery"):
			crew.ask("gear", _current)
		elif low.contains("where") or low.contains("place") or low.contains("fly"):
			crew.ask("spot", _current)
		elif low.contains("job") or low.contains("work") or low.contains("money"):
			crew.ask("jobs", _current)
		elif low.contains("edit") or low.contains("video") or low.contains("upload") or low.contains("clip"):
			crew.ask("edit", _current)
	_refresh_channel()

func _plain_text(t: String) -> String:
	for p in ["FORECAST: ", "GEAR: ", "WORK: ", "PLACES: ", "EDIT: ", "Storm watch: ", "Forecast: ", "Gear note: ", "Jobs: ", "Places: ", "Edit note: "]:
		if t.begins_with(p):
			return t.substr(p.length())
	return t

func _ask(kind: String) -> void:
	if crew == null:
		return
	var questions := {
		"weather": "What is the weather doing?",
		"storm": "Anything on the storm front?",
		"gear": "What should I fly today?",
		"spot": "Where should I go?",
		"jobs": "What is on the board?",
		"edit": "How is the channel doing?",
	}
	var question: String = str(questions.get(kind, "What do you think?"))
	chat.post(_current, "You", question, false, true)
	crew.ask(kind, _current)
	_refresh_channel()

func stats() -> Dictionary:
	return chat.stats()

class_name ChatApp
extends Control
## The DroneBudz app: a Discord-style server for the crew (session B).
##
## Left: the server mark and the channel list, grouped into channels and direct messages. Right: the channel header,
## the messages in order (avatars, names, roles, times, system job events, the pilot's own posts, photo attachments) and
## a composer. The look is a small provincial server at dusk: warm paper text, brass and moss, never a generic dark app.
##
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
var _members: Label
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
	chat.posted.connect(_on_chat_posted)

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.045, 0.055, 0.048, 1.0)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	_root = HBoxContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_theme_constant_override("separation", 0)
	add_child(_root)
	# ---------------- server sidebar
	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(272, 0)
	var ssb := UniverseUI.box(UniverseUI.PANEL, 0, UniverseUI.LINE, 1, 0.0, 0.0)
	ssb.border_width_top = 0; ssb.border_width_bottom = 0; ssb.border_width_left = 0
	side.add_theme_stylebox_override("panel", ssb)
	_root.add_child(side)
	var side_col := VBoxContainer.new()
	side_col.add_theme_constant_override("separation", 0)
	side.add_child(side_col)
	var server := PanelContainer.new()
	var srv_sb := UniverseUI.box(UniverseUI.DEEP, 0, UniverseUI.LINE, 1, 16.0, 12.0)
	srv_sb.border_width_top = 0; srv_sb.border_width_left = 0; srv_sb.border_width_right = 0
	server.add_theme_stylebox_override("panel", srv_sb)
	side_col.add_child(server)
	var srv_row := HBoxContainer.new()
	srv_row.add_theme_constant_override("separation", 10)
	server.add_child(srv_row)
	var mark := PanelContainer.new()
	mark.custom_minimum_size = Vector2(40, 40)
	mark.add_theme_stylebox_override("panel", UniverseUI.box(Color(0.20, 0.38, 0.26), 12, UniverseUI.MOSS, 1, 0.0, 0.0))
	var mark_label := UniverseUI.label("DB", 14, UniverseUI.CREAM)
	mark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_child(mark_label)
	srv_row.add_child(mark)
	var srv_text := VBoxContainer.new()
	srv_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srv_text.add_theme_constant_override("separation", 0)
	srv_row.add_child(srv_text)
	srv_text.add_child(UniverseUI.label("DroneBudz", 17, UniverseUI.CREAM))
	srv_text.add_child(UniverseUI.label("HALLOWAY VALLEY", 9, UniverseUI.MUTED))
	var chan_pad := MarginContainer.new()
	chan_pad.add_theme_constant_override("margin_left", 12)
	chan_pad.add_theme_constant_override("margin_right", 10)
	chan_pad.add_theme_constant_override("margin_top", 10)
	side_col.add_child(chan_pad)
	_sidebar_channels = VBoxContainer.new()
	_sidebar_channels.add_theme_constant_override("separation", 2)
	chan_pad.add_child(_sidebar_channels)
	var stretch := Control.new()
	stretch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_col.add_child(stretch)
	var me := PanelContainer.new()
	var me_sb := UniverseUI.box(UniverseUI.DEEP, 0, UniverseUI.LINE, 1, 12.0, 10.0)
	me_sb.border_width_top = 1; me_sb.border_width_bottom = 0; me_sb.border_width_left = 0; me_sb.border_width_right = 0
	me.add_theme_stylebox_override("panel", me_sb)
	side_col.add_child(me)
	var me_row := HBoxContainer.new()
	me_row.add_theme_constant_override("separation", 9)
	me.add_child(me_row)
	var you := PanelContainer.new()
	you.custom_minimum_size = Vector2(34, 34)
	you.add_theme_stylebox_override("panel", UniverseUI.box(Color(0.18, 0.32, 0.22), 17, UniverseUI.MOSS, 1, 0.0, 0.0))
	var yl := UniverseUI.label("YOU", 8, UniverseUI.CREAM)
	yl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	yl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	you.add_child(yl)
	me_row.add_child(you)
	var me_text := VBoxContainer.new()
	me_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	me_text.add_theme_constant_override("separation", 0)
	me_row.add_child(me_text)
	me_text.add_child(UniverseUI.label("You  ·  pilot", 13, UniverseUI.CREAM_DIM))
	_crew_label = UniverseUI.label("", 10, UniverseUI.MUTED)
	me_text.add_child(_crew_label)
	# ---------------- main column
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 0)
	_root.add_child(main)
	var head := PanelContainer.new()
	var hsb := UniverseUI.box(UniverseUI.DEEP, 0, UniverseUI.LINE, 1, 18.0, 12.0)
	hsb.border_width_top = 0; hsb.border_width_left = 0; hsb.border_width_right = 0
	head.add_theme_stylebox_override("panel", hsb)
	main.add_child(head)
	var hm := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		hm.add_theme_constant_override("margin_" + m, 16)
	head.add_child(hm)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 12)
	hm.add_child(hrow)
	var hcol := VBoxContainer.new()
	hcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hcol.add_theme_constant_override("separation", 1)
	hrow.add_child(hcol)
	_title = UniverseUI.label("", 19, UniverseUI.CREAM)
	hcol.add_child(_title)
	_topic = UniverseUI.label("", 11, UniverseUI.MUTED)
	hcol.add_child(_topic)
	_members = UniverseUI.label("●  6 CREW", 10, UniverseUI.MOSS)
	_members.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hrow.add_child(_members)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(_scroll)
	_messages = VBoxContainer.new()
	_messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_messages.add_theme_constant_override("separation", 0)
	_scroll.add_child(_messages)
	var input_row := PanelContainer.new()
	var isb := UniverseUI.box(UniverseUI.DEEP, 0, UniverseUI.LINE, 1, 14.0, 10.0)
	isb.border_width_bottom = 0; isb.border_width_left = 0; isb.border_width_right = 0
	input_row.add_theme_stylebox_override("panel", isb)
	main.add_child(input_row)
	var in_col := VBoxContainer.new()
	in_col.add_theme_constant_override("separation", 7)
	input_row.add_child(in_col)
	# quick asks: each friend gives a different kind of answer
	var chips_row := HBoxContainer.new()
	chips_row.add_theme_constant_override("separation", 6)
	in_col.add_child(chips_row)
	var quick := UniverseUI.label("ASK", 9, UniverseUI.MUTED)
	quick.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chips_row.add_child(quick)
	for pair in [["Weather?", "weather", "Sam"], ["Storm?", "storm", "Tom"], ["Gear?", "gear", "Alex"],
			["Where?", "spot", "Riley"], ["Jobs?", "jobs", "Jo"], ["Edit?", "edit", "Maya"]]:
		var b := Button.new()
		b.text = str(pair[0])
		b.tooltip_text = "Ask " + str(pair[2])
		b.theme_type_variation = "Chip"
		b.custom_minimum_size = Vector2(0, 24)
		var key := str(pair[1])
		b.pressed.connect(func(): _ask(key))
		chips_row.add_child(b)
	var in_row := HBoxContainer.new()
	in_row.add_theme_constant_override("separation", 8)
	in_col.add_child(in_row)
	_input = LineEdit.new()
	_input.placeholder_text = "Message #general"
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.custom_minimum_size = Vector2(0, 38)
	_input.text_submitted.connect(func(_t): _send())
	in_row.add_child(_input)
	var send := Button.new()
	send.text = "Send"
	send.theme_type_variation = "Primary"
	send.custom_minimum_size = Vector2(78, 38)
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
	var has_unknown := not chat.messages("unknown", false).is_empty()
	var added_group := false
	var direct_group := false
	for ch in chat.channels():
		var id := str(ch["id"])
		if id == "unknown" and not has_unknown:
			continue
		if id == "unknown" and not direct_group:
			var dg := UniverseUI.small_caps("DIRECT MESSAGES")
			dg.add_theme_constant_override("margin_top", 6)
			_sidebar_channels.add_child(dg)
			direct_group = true
		elif id != "unknown" and not added_group:
			_sidebar_channels.add_child(UniverseUI.small_caps("CHANNELS"))
			added_group = true
		var unread := chat.unread(id)
		var b := Button.new()
		b.text = ("  DM  " + str(ch["name"]) if id == "unknown" else "  #  " + str(ch["name"])) + (("   %d" % unread) if unread > 0 else "")
		b.theme_type_variation = "Channel"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 32)
		var selected := id == _current
		b.add_theme_color_override("font_color", UniverseUI.CREAM if selected else UniverseUI.MUTED)
		var sb := UniverseUI.box(UniverseUI.AMBER_SOFT if selected else Color(0, 0, 0, 0), 8, UniverseUI.AMBER if selected else Color(0, 0, 0, 0), 0, 12.0, 6.0)
		b.add_theme_stylebox_override("normal", sb)
		b.pressed.connect(func(): open(id))
		_sidebar_channels.add_child(b)
	if jobs != null:
		_crew_label.text = "%d followers  ·  $%d" % [jobs.followers(), jobs.money()]
	else:
		_crew_label.text = ""

func _refresh_channel() -> void:
	var ch := chat.channel_info(_current)
	if _current == "unknown":
		_title.text = "Unknown"
		_input.placeholder_text = "Message Unknown"
	else:
		_title.text = "#  " + str(ch.get("name", _current))
		_input.placeholder_text = "Message #" + str(ch.get("name", _current))
	_topic.text = str(ch.get("topic", ""))
	_members.text = "●  DIRECT" if _current == "unknown" else "●  6 CREW"
	for m in _messages.get_children():
		m.queue_free()
	_messages.add_child(_day_label("TODAY"))
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

func _day_label(text: String) -> Control:
	var holder := MarginContainer.new()
	holder.add_theme_constant_override("margin_top", 12)
	holder.add_theme_constant_override("margin_bottom", 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	holder.add_child(row)
	row.add_child(UniverseUI.label("—  " + text + "  —", 9, UniverseUI.FAINT))
	return holder

func _message_row(msg: Dictionary) -> Control:
	var from := str(msg.get("from", ""))
	var system := bool(msg.get("system", false))
	var mine := bool(msg.get("mine", false))
	var pad := MarginContainer.new()
	for m in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + m, 18)
	for m in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + m, 3)
	if system:
		var sc := CenterContainer.new()
		pad.add_child(sc)
		var line := UniverseUI.label("◈  " + str(msg.get("text", "")), 10, UniverseUI.MUTED)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sc.add_child(line)
		return pad
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 11)
	pad.add_child(row)
	var col := chat.cast_colour(from) if not mine else UniverseUI.MOSS
	row.add_child(UniverseUI.avatar(from.to_lower(), 36, col))
	var col2 := VBoxContainer.new()
	col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col2.add_theme_constant_override("separation", 1)
	row.add_child(col2)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 7)
	col2.add_child(top)
	var who := UniverseUI.label(from, 13, col if not mine else UniverseUI.MOSS)
	top.add_child(who)
	var role := UniverseUI.label(chat.cast_role(from).to_upper(), 8, UniverseUI.FAINT)
	role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(role)
	var tm := UniverseUI.label(str(msg.get("time", "")), 9, UniverseUI.FAINT)
	tm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(tm)
	var body := UniverseUI.label(str(msg.get("text", "")), 14, UniverseUI.CREAM_DIM)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col2.add_child(body)
	var photo_id := int(msg.get("photo", -1))
	if photo_id >= 0 and photos != null:
		var tex := photos.texture_for(photo_id)
		if tex != null:
			var frame := PanelContainer.new()
			frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			frame.add_theme_stylebox_override("panel", UniverseUI.box(UniverseUI.DEEP, 10, UniverseUI.LINE_STRONG, 1, 4.0, 4.0))
			var pic := TextureRect.new()
			pic.texture = tex
			pic.custom_minimum_size = Vector2(300, 169)
			pic.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			frame.add_child(pic)
			col2.add_child(frame)
	return pad

func _send() -> void:
	var text := _input.text.strip_edges()
	if text == "":
		return
	chat.post(_current, "You", text, false, true)
	_input.text = ""
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

func _on_chat_posted(ch: String) -> void:
	if ch == "unknown":
		_refresh_sidebar()
	if ch == _current:
		_refresh_channel()

func stats() -> Dictionary:
	return chat.stats()

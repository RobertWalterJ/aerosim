class_name CasebookApp
extends Control
## The Casebook app (session B, UI pass 2): a proper case-file proxy rather than a single scrolling sheet.
##
## Layout: a constabulary app bar, a case-file rail with the file identity and four sections, and a separate reading
## pane for the current section. Overview carries the request and next step, Evidence is a photographed evidence register,
## Chapters is the timeline, Contacts is the small cast directory. The case is optional; with the story switched off or
## not started this still reads as a quiet, empty official app.

signal chat_requested(person: String)
signal map_requested
signal close_requested

const CASE_NO := "HV-84-017"
const ACCENT := Color(0.545, 0.575, 0.700)

var story: StoryArc
var photos: PhotoLibrary
var director: StoryDirector
var sites: LaunchSites
var _tab := "overview"
var _tabs := {}
var _content: VBoxContainer
var _header_status: Label
var _header_case: Label
var _side_file: Label
var _side_status: Label

func setup(s: StoryArc, p: PhotoLibrary, d: StoryDirector = null, ls: LaunchSites = null) -> void:
	story = s
	photos = p
	director = d
	sites = ls
	_build()
	if director != null:
		director.act_changed.connect(_on_director_act)

func _on_director_act(_act: int) -> void:
	refresh()

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.038, 0.047, 0.041, 1.0)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	col.add_child(_app_bar())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	col.add_child(body)
	body.add_child(_rail())
	var pane := MarginContainer.new()
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for m in ["left", "right"]:
		pane.add_theme_constant_override("margin_" + m, 26)
	pane.add_theme_constant_override("margin_top", 20)
	pane.add_theme_constant_override("margin_bottom", 18)
	body.add_child(pane)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pane.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)

func _app_bar() -> Control:
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UniverseUI.DEEP
	sb.border_width_bottom = 2
	sb.border_color = ACCENT
	bar.add_theme_stylebox_override("panel", sb)
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 20)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_bottom", 10)
	bar.add_child(m)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	m.add_child(row)
	var back := Button.new()
	back.text = "Back"
	back.theme_type_variation = "Ghost"
	back.custom_minimum_size = Vector2(76, 38)
	back.pressed.connect(func(): close_requested.emit())
	row.add_child(back)
	var icon := TabletIcon.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.set_kind("casebook", ACCENT)
	row.add_child(icon)
	var title_col := VBoxContainer.new()
	title_col.add_theme_constant_override("separation", 0)
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_col)
	title_col.add_child(UniverseUI.label("HALLOWAY VALLEY CONSTABULARY", 9, ACCENT))
	title_col.add_child(UniverseUI.label("Casebook", 23, UniverseUI.CREAM))
	_header_case = UniverseUI.label("CASE FILE  ·  " + CASE_NO, 10, UniverseUI.MUTED)
	title_col.add_child(_header_case)
	var status_wrap := PanelContainer.new()
	status_wrap.add_theme_stylebox_override("panel", UniverseUI.box(UniverseUI.MOSS_SOFT, 12, UniverseUI.MOSS, 1, 12.0, 5.0))
	row.add_child(status_wrap)
	_header_status = UniverseUI.label("", 10, UniverseUI.MOSS)
	status_wrap.add_child(_header_status)
	var message := Button.new()
	message.text = "Message Rennick"
	message.custom_minimum_size = Vector2(162, 38)
	message.pressed.connect(func(): chat_requested.emit("rennick"))
	row.add_child(message)
	return bar

func _rail() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(272, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.060, 0.074, 0.064, 1.0)
	sb.border_width_right = 1
	sb.border_color = UniverseUI.LINE
	panel.add_theme_stylebox_override("panel", sb)
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 18)
	m.add_theme_constant_override("margin_top", 18)
	m.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	m.add_child(col)
	# file identity card
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UniverseUI.box(Color(0.10, 0.115, 0.105), 12, ACCENT.darkened(0.3), 1, 14.0, 12.0))
	col.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 3)
	card.add_child(cv)
	cv.add_child(UniverseUI.label("CASE FILE", 9, ACCENT))
	_side_file = UniverseUI.label("The Lake Car", 20, UniverseUI.CREAM)
	cv.add_child(_side_file)
	cv.add_child(UniverseUI.label(CASE_NO + "   ·   AUTUMN", 10, UniverseUI.MUTED))
	_side_status = UniverseUI.label("", 11, UniverseUI.MOSS)
	cv.add_child(_side_status)
	col.add_child(UniverseUI.label("SECTIONS", 9, UniverseUI.MUTED))
	for entry in [["overview", "Overview"], ["evidence", "Evidence"], ["chapters", "Chapters"], ["contacts", "Contacts"]]:
		var key := str(entry[0])
		var b := Button.new()
		b.text = "   " + str(entry[1])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 38)
		b.toggle_mode = true
		b.pressed.connect(func(): _set_tab(key))
		col.add_child(b)
		_tabs[key] = b
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(filler)
	# assigned officer
	var assigned := PanelContainer.new()
	assigned.add_theme_stylebox_override("panel", UniverseUI.card(12, UniverseUI.CARD, UniverseUI.LINE, 1))
	col.add_child(assigned)
	var am := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		am.add_theme_constant_override("margin_" + side, 10)
	assigned.add_child(am)
	var ac := VBoxContainer.new()
	ac.add_theme_constant_override("separation", 6)
	am.add_child(ac)
	var ar := HBoxContainer.new()
	ar.add_theme_constant_override("separation", 8)
	ac.add_child(ar)
	ar.add_child(UniverseUI.avatar("rennick", 36, ACCENT))
	var an := VBoxContainer.new()
	an.add_theme_constant_override("separation", 0)
	an.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ar.add_child(an)
	an.add_child(UniverseUI.label("Constable Rennick", 13, UniverseUI.CREAM))
	an.add_child(UniverseUI.label("CASE OFFICER", 9, UniverseUI.MUTED))
	ac.add_child(UniverseUI.label("Plain clothes. Quiet authority. Keeps the file in a drawer.", 10, UniverseUI.CREAM_DIM))
	var open_chat := Button.new()
	open_chat.text = "Open #town"
	open_chat.theme_type_variation = "Ghost"
	open_chat.custom_minimum_size = Vector2(0, 30)
	open_chat.pressed.connect(func(): chat_requested.emit("rennick"))
	ac.add_child(open_chat)
	col.add_child(UniverseUI.label("AUTUMN  ·  NORTH VALLEY  ·  FILE OPENED IN THE FIELD", 8, UniverseUI.FAINT))
	return panel

func _set_tab(key: String) -> void:
	_tab = key
	refresh()

func refresh() -> void:
	if _content == null:
		return
	_update_header()
	_sync_tabs()
	for c in _content.get_children():
		c.queue_free()
	match _tab:
		"evidence": _evidence_view()
		"chapters": _chapters_view()
		"contacts": _contacts_view()
		_: _overview_view()

func _update_header() -> void:
	var display := "The Lake Car"
	var status := "NO CASE YET"
	var detail := CASE_NO
	if story != null:
		if story.story_off_hint():
			status = "STORY OFF"
		elif not story.started:
			status = "NO CASE YET"
		elif story.case_closed():
			status = "CASE CLOSED"
			display = "The Lake Car  ·  closed"
		else:
			status = "OPEN"
		if director != null:
			detail = CASE_NO + "   ·   ACT %d  ·  %s" % [director.act_number(), director.act_name().to_upper()]
	_side_file.text = display
	_side_status.text = "STATUS  ·  " + status
	_header_status.text = status + (("   ·   ACT %d" % director.act_number()) if director != null and story != null and story.started and not story.case_closed() else "")
	_header_case.text = detail

func _sync_tabs() -> void:
	for key in _tabs:
		var b: Button = _tabs[key]
		var on: bool = str(key) == _tab
		b.button_pressed = on
		b.text = ("▸ " if on else "   ") + str(key).capitalize()
		b.add_theme_color_override("font_color", UniverseUI.AMBER if on else UniverseUI.CREAM_DIM)
		b.add_theme_stylebox_override("normal", UniverseUI.box(UniverseUI.AMBER_SOFT if on else Color(0, 0, 0, 0), 9, UniverseUI.AMBER if on else Color(0, 0, 0, 0), 1, 12.0, 7.0))
		b.add_theme_stylebox_override("hover", UniverseUI.box(UniverseUI.FIELD, 9, UniverseUI.LINE, 1, 12.0, 7.0))

func _page_title(title: String, subtitle := "") -> void:
	_content.add_child(UniverseUI.label(title, 26, UniverseUI.CREAM))
	if subtitle != "":
		var s := UniverseUI.label(subtitle, 11, UniverseUI.MUTED)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(s)

func _section(text: String) -> void:
	var s := UniverseUI.label(text.to_upper(), 9, UniverseUI.AMBER)
	_content.add_child(s)

func _card(accent := UniverseUI.LINE, bg := UniverseUI.CARD) -> Dictionary:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UniverseUI.card(12, bg, accent, 1))
	_content.add_child(p)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 15)
	p.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	m.add_child(v)
	return {"panel": p, "body": v}

func _empty(title: String, body: String) -> void:
	var c := _card(UniverseUI.LINE, Color(0.09, 0.105, 0.095))
	var v: VBoxContainer = c["body"]
	v.add_child(UniverseUI.label(title, 17, UniverseUI.CREAM))
	var b := UniverseUI.label(body, 12, UniverseUI.MUTED)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(b)

func _overview_view() -> void:
	_page_title("Case overview", "The working file for the Lake Car inquiry.")
	if story == null:
		_empty("No case loaded", "The constabulary file is empty.")
		return
	if story.story_off_hint():
		_empty("The file is resting", "The constable has put the file aside. It will be here when story and jobs are switched on again.")
		return
	if not story.started:
		_empty("No case yet", "Rennick will get in touch when something comes up. The file stays sealed until then.")
		return
	# current request: only while the file is open. A closed file should not show a stale open request.
	if not story.case_closed():
		var request := _card(ACCENT)
		var rv: VBoxContainer = request["body"]
		rv.add_child(UniverseUI.label("CURRENT REQUEST", 9, ACCENT))
		var req := story.active_request()
		var rtext := "All evidence is in. The file is ready to close." if story.has_choice() else req
		if rtext == "":
			rtext = "No open request right now. Rennick will come back when there is something."
		var r := UniverseUI.label(rtext, 16, UniverseUI.CREAM)
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rv.add_child(r)
		var st := UniverseUI.label("Status  ·  " + story.current_status(), 11, UniverseUI.MUTED)
		rv.add_child(st)
	# next step + director
	if director != null:
		_section("Next step")
		var nxt := _card(UniverseUI.MOSS)
		var nv: VBoxContainer = nxt["body"]
		nv.add_child(UniverseUI.label("ACT %d  ·  %s" % [director.act_number(), director.act_name().to_upper()], 9, UniverseUI.MOSS))
		var step := UniverseUI.label(director.next_step(), 15, UniverseUI.CREAM)
		step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nv.add_child(step)
		var gate := UniverseUI.label("THERMAL %s    ·    NIGHT PASTURE %s    ·    %s" % [
			"READY" if director.thermal_ready() else "NOT FITTED",
			"DONE" if director.wildlife_done() else "OPEN",
			director.chapter_line(),
		], 10, UniverseUI.MUTED)
		gate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nv.add_child(gate)
	# evidence progress
	if story.case_closed():
		var totals := story.evidence_totals()
		_section("Evidence register")
		var filed := _card(UniverseUI.LINE)
		var fv: VBoxContainer = filed["body"]
		var ft := HBoxContainer.new()
		fv.add_child(ft)
		var ftl := UniverseUI.label("Filed evidence", 14, UniverseUI.CREAM)
		ftl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ft.add_child(ftl)
		ft.add_child(UniverseUI.label("%d / %d" % [int(totals.get("have", 0)), int(totals.get("count", 0))], 12, UniverseUI.MOSS))
		fv.add_child(_progress_bar(int(totals.get("have", 0)), int(totals.get("count", 0))))
		_empty("The file is closed", "The evidence register is archived. Rennick has the photographs and the case is closed.")
	else:
		_section("Evidence register")
		var progs := story.evidence_progress()
		if progs.is_empty():
			_empty("No evidence yet", "Photographs taken for the case will be filed here.")
		else:
			for p in progs:
				var pc := _card(UniverseUI.LINE)
				var pv: VBoxContainer = pc["body"]
				var top := HBoxContainer.new()
				pv.add_child(top)
				var t := UniverseUI.label(str(p.get("text", "Evidence")), 14, UniverseUI.CREAM)
				t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				top.add_child(t)
				top.add_child(UniverseUI.label("%d / %d" % [int(p.get("have", 0)), int(p.get("count", 1))], 12, UniverseUI.MOSS))
				pv.add_child(_progress_bar(int(p.get("have", 0)), int(p.get("count", 1))))
	# suggested launch site
	if sites != null:
		_section("Approach")
		var lc := _card(UniverseUI.LAKE)
		var lv: VBoxContainer = lc["body"]
		var lt := HBoxContainer.new()
		lv.add_child(lt)
		var lname := UniverseUI.label("Suggested launch site", 14, UniverseUI.CREAM)
		lname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lt.add_child(lname)
		lt.add_child(UniverseUI.label("KIT PARKED  ·  " + sites.name().to_upper(), 10, UniverseUI.MUTED))
		var s := UniverseUI.label("Use the Map app to drive the kit to a closer site before a long chapter.", 11, UniverseUI.MUTED)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lv.add_child(s)
		var open_map := Button.new()
		open_map.text = "Open map"
		open_map.theme_type_variation = "Ghost"
		open_map.custom_minimum_size = Vector2(120, 32)
		open_map.pressed.connect(func(): map_requested.emit())
		lv.add_child(open_map)
	# ending choice
	if story.has_choice():
		_section("Close the file")
		_choice_card()
	elif story.case_closed():
		_section("File closed")
		_closed_card()

func _evidence_view() -> void:
	if story != null and story.case_closed():
		_page_title("Evidence register", "The photographs filed with the closed Lake Car file.")
		var any := false
		for ch in story.chapter_entries():
			var reqs: Array = ch.get("requirements", [])
			var filed_reqs: Array = []
			for p in reqs:
				if int(p.get("have", 0)) > 0:
					filed_reqs.append(p)
			if filed_reqs.is_empty():
				continue
			any = true
			_section("%d. %s" % [int(ch.get("index", 0)) + 1, str(ch.get("title", "Chapter"))])
			for p in filed_reqs:
				_add_evidence_card(p)
		if not any:
			_empty("Nothing filed", "The file is closed with no photographs in this register.")
		return
	_page_title("Evidence register", "Every photograph filed against the open request.")
	if story == null or not story.started:
		_empty("Nothing filed yet", "The evidence register fills as the case progresses.")
		return
	var progs := story.evidence_progress()
	if progs.is_empty():
		_empty("Nothing filed yet", "Take a photograph that matches the request and it will appear here.")
		return
	for p in progs:
		_add_evidence_card(p)
	var stamp := UniverseUI.case_art("stamp_evidence")
	if stamp != null:
		var pic := TextureRect.new()
		pic.texture = stamp
		pic.custom_minimum_size = Vector2(140, 140)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_content.add_child(pic)

func _add_evidence_card(p: Dictionary) -> void:
	var c := _card(UniverseUI.LINE)
	var v: VBoxContainer = c["body"]
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := UniverseUI.label(str(p.get("text", "Evidence")), 15, UniverseUI.CREAM)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	top.add_child(UniverseUI.label("%d / %d FILED" % [int(p.get("have", 0)), int(p.get("count", 1))], 10, UniverseUI.MOSS if int(p.get("have", 0)) >= int(p.get("count", 1)) else UniverseUI.MUTED))
	v.add_child(_progress_bar(int(p.get("have", 0)), int(p.get("count", 1))))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	var added := 0
	for pid in p.get("photos", []):
		if int(pid) >= 0 and photos != null:
			var tex := photos.texture_for(int(pid))
			if tex != null:
				grid.add_child(_photo_tile(tex, 152, 86))
				added += 1
	if added == 0:
		var empty_text := "No photograph filed for this requirement yet." if int(p.get("have", 0)) == 0 else "Filed, but the photographs are no longer in the camera roll."
		var empty := UniverseUI.label(empty_text, 11, UniverseUI.MUTED)
		v.add_child(empty)

func _chapters_view() -> void:
	_page_title("Chapter trail", "The inquiry as it happened, in the order it happened.")
	if story == null:
		_empty("No chapters", "The file has no chapter trail yet.")
		return
	var entries := story.chapter_entries()
	if entries.is_empty():
		_empty("No chapters", "The chapter trail appears when the case begins.")
		return
	for ch in entries:
		var status := str(ch["status"])
		var accent := UniverseUI.MOSS if status == "done" else (UniverseUI.AMBER if status == "active" else UniverseUI.LINE)
		var c := _card(accent, UniverseUI.CARD if status != "active" else Color(0.145, 0.155, 0.125))
		var v: VBoxContainer = c["body"]
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 10)
		v.add_child(top)
		var node := PanelContainer.new()
		node.custom_minimum_size = Vector2(34, 34)
		node.add_theme_stylebox_override("panel", UniverseUI.box(UniverseUI.MOSS_SOFT if status == "done" else (UniverseUI.AMBER_SOFT if status == "active" else UniverseUI.FIELD), 17, accent, 1, 0.0, 0.0))
		top.add_child(node)
		var nl := UniverseUI.label("✓" if status == "done" else ("●" if status == "active" else "%d" % (int(ch["index"]) + 1)), 13, accent)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		node.add_child(nl)
		var t := UniverseUI.label(str(ch["title"]), 16, UniverseUI.CREAM if status != "locked" else UniverseUI.FAINT)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(t)
		top.add_child(UniverseUI.label(("DONE" if status == "done" else ("OPEN" if status == "active" else "WAITING")), 9, accent))
		if status == "active":
			for rq in ch["requirements"]:
				var d := UniverseUI.label("%s   %d/%d photographs" % [str(rq.get("text", "")), int(rq.get("have", 0)), int(rq.get("count", 1))], 11, UniverseUI.CREAM_DIM)
				d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				v.add_child(d)
	if story.has_choice():
		_section("Close the file")
		_choice_card()
	elif story.case_closed():
		_section("File closed")
		_closed_card()

func _contacts_view() -> void:
	_page_title("Contacts", "The people connected to the file.")
	var wren_found := story != null and story.is_completed()
	var people := [
		{"key": "rennick", "name": "Constable Rennick", "role": "CASE OFFICER", "note": "Halloway Valley Constabulary. Keeps the file by the phone and the notes short."},
		{"key": "wren", "name": "Wren", "role": "FOUND" if wren_found else "MISSING HIKER", "note": "Found east of the cabin. The file is closed and Wren is safe." if wren_found else "Last seen north of the cabin. The reason the file is still open."},
		{"key": "riley", "name": "Riley", "role": "PARK RANGER", "note": "Knows the pasture, the flock and every track on the ridge."},
		{"key": "maya", "name": "Maya", "role": "EDITOR", "note": "Cuts the channel footage. Has opinions about the last shot."},
		{"key": "jo", "name": "Jo", "role": "EVENTS", "note": "Runs the festival and knows who was where on the night."},
		{"key": "sam", "name": "Sam", "role": "METEOROLOGIST", "note": "Forecasts the valley and hears things before the town does."},
	]
	for p in people:
		var c := _card(UniverseUI.LINE)
		var v: VBoxContainer = c["body"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		v.add_child(row)
		row.add_child(UniverseUI.avatar(str(p["key"]), 42, ACCENT))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(UniverseUI.label(str(p["name"]), 15, UniverseUI.CREAM))
		col.add_child(UniverseUI.label(str(p["role"]), 9, UniverseUI.MUTED))
		var note := UniverseUI.label(str(p["note"]), 11, UniverseUI.CREAM_DIM)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(note)
		var msg := Button.new()
		msg.text = "Message"
		msg.theme_type_variation = "Ghost"
		msg.custom_minimum_size = Vector2(96, 30)
		msg.pressed.connect(func(): chat_requested.emit(str(p["key"])))
		v.add_child(msg)

func _progress_bar(have: int, count: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.max_value = maxi(count, 1)
	bar.value = clampi(have, 0, count)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", UniverseUI.box(UniverseUI.FIELD, 4, UniverseUI.LINE, 1, 0.0, 0.0))
	bar.add_theme_stylebox_override("fill", UniverseUI.box(UniverseUI.MOSS, 4, UniverseUI.MOSS, 0, 0.0, 0.0))
	return bar

func _photo_tile(tex: Texture2D, w: int, h: int) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(w, h)
	p.add_theme_stylebox_override("panel", UniverseUI.box(UniverseUI.FIELD, 7, UniverseUI.LINE_STRONG, 1, 0.0, 0.0))
	var pic := TextureRect.new()
	pic.texture = tex
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.custom_minimum_size = Vector2(w, h)
	p.add_child(pic)
	return p

func _choice_card() -> void:
	var c := _card(UniverseUI.AMBER)
	var v: VBoxContainer = c["body"]
	v.add_child(UniverseUI.label("The file is ready to close.", 16, UniverseUI.CREAM))
	v.add_child(UniverseUI.label("What happens to the Lake Car story?", 12, UniverseUI.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var pub := Button.new()
	pub.text = "Publish with Maya's cut"
	pub.custom_minimum_size = Vector2(220, 40)
	pub.tooltip_text = "Maya edits the festival footage and puts it on VidTube. Views and followers are earned, not promised."
	pub.pressed.connect(func(): story.make_choice("publish"); refresh())
	row.add_child(pub)
	var keep := Button.new()
	keep.text = "Keep it private"
	keep.theme_type_variation = "Ghost"
	keep.custom_minimum_size = Vector2(170, 40)
	keep.tooltip_text = "The story stays with the people who were there. The detachment sends a fuel payment."
	keep.pressed.connect(func(): story.make_choice("private"); refresh())
	row.add_child(keep)

func _closed_card() -> void:
	var c := _card(UniverseUI.MOSS)
	var v: VBoxContainer = c["body"]
	var done := UniverseUI.label("Case closed. " + ("The story is published with Maya's cut." if story.choice == "published" else "The story stays with the crew and the town."), 14, UniverseUI.CREAM)
	done.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(done)
	if story.choice == "published" and not story.last_result.is_empty():
		var r := UniverseUI.label("The cut is at %d views so far, with %d new followers and $%d." % [int(story.last_result.get("views", 0)), int(story.last_result.get("followers", 0)), int(story.last_result.get("money", 0))], 11, UniverseUI.MUTED)
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(r)
	var stamp := UniverseUI.case_art("stamp_case_closed")
	if stamp != null:
		var pic := TextureRect.new()
		pic.texture = stamp
		pic.custom_minimum_size = Vector2(120, 120)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		v.add_child(pic)

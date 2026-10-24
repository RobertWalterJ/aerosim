class_name CasebookApp
extends Control
## The Casebook app (session B): the story's file on the phone. It shows the current case, the officer's request, the
## evidence already photographed, and the chapter trail. Nothing here starts or advances the story by itself; it just
## shows what Rennick has asked for and what the pilot has delivered.
##
## The case is optional. If it has not started yet the page explains that the officer will be in touch, and if the story
## switch is off it stays quiet.

signal chat_requested

var story: StoryArc
var photos: PhotoLibrary
var _status: Label
var _request: Label
var _progress: Label
var _evidence_list: VBoxContainer
var _chapters: VBoxContainer
var _open_btn: Button

func setup(s: StoryArc, p: PhotoLibrary) -> void:
	story = s
	photos = p
	_build()

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	# header
	var head := PanelContainer.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.10, 0.12, 0.16, 1.0)
	hsb.border_width_bottom = 3
	hsb.border_color = Color(0.36, 0.50, 0.68)
	head.add_theme_stylebox_override("panel", hsb)
	col.add_child(head)
	var hm := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		hm.add_theme_constant_override("margin_" + m, 22)
	head.add_child(hm)
	var hcol := VBoxContainer.new()
	hcol.add_theme_constant_override("separation", 4)
	hm.add_child(hcol)
	var title := Label.new()
	title.text = "Casebook  ·  The Lake Car"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.96, 0.97, 0.98))
	hcol.add_child(title)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 14)
	_status.add_theme_color_override("font_color", Color(0.72, 0.78, 0.84))
	hcol.add_child(_status)
	_open_btn = Button.new()
	_open_btn.text = "Open #town in DroneBudz"
	_open_btn.custom_minimum_size = Vector2(230, 36)
	_open_btn.pressed.connect(func(): chat_requested.emit())
	hcol.add_child(_open_btn)
	# current request
	var body := MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for m in ["left", "right", "bottom"]:
		body.add_theme_constant_override("margin_" + m, 22)
	col.add_child(body)
	var main := VBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 14)
	body.add_child(main)
	var req_card := PanelContainer.new()
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.12, 0.14, 0.17)
	rsb.set_corner_radius_all(14)
	rsb.border_width_left = 3
	rsb.border_color = Color(0.36, 0.50, 0.68)
	req_card.add_theme_stylebox_override("panel", rsb)
	main.add_child(req_card)
	var rm := MarginContainer.new()
	for m in ["left", "right", "top", "bottom"]:
		rm.add_theme_constant_override("margin_" + m, 16)
	req_card.add_child(rm)
	var rcol := VBoxContainer.new()
	rcol.add_theme_constant_override("separation", 6)
	rm.add_child(rcol)
	var what := Label.new()
	what.text = "Open request"
	what.add_theme_font_size_override("font_size", 14)
	what.add_theme_color_override("font_color", Color(0.62, 0.76, 0.90))
	rcol.add_child(what)
	_request = Label.new()
	_request.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_request.add_theme_font_size_override("font_size", 15)
	_request.add_theme_color_override("font_color", Color(0.90, 0.92, 0.94))
	rcol.add_child(_request)
	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 13)
	_progress.add_theme_color_override("font_color", Color(0.66, 0.82, 0.70))
	rcol.add_child(_progress)
	_evidence_list = VBoxContainer.new()
	_evidence_list.add_theme_constant_override("separation", 6)
	rcol.add_child(_evidence_list)
	# chapter trail
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 240)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(scroll)
	_chapters = VBoxContainer.new()
	_chapters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chapters.add_theme_constant_override("separation", 8)
	scroll.add_child(_chapters)

func refresh() -> void:
	if story.story_off_hint():
		_status.text = "Story and jobs are switched off in the menu. The case will wait."
	elif not story.started:
		_status.text = "No case yet. The officer will get in touch when something comes up."
		_request.text = "Rennick has not asked for anything yet. When she does, the request will appear here and in #town."
		_progress.text = ""
	else:
		_status.text = story.current_status()
		var req := story.active_request()
		if req == "":
			_request.text = "No open request right now. Rennick will come back when she has something."
		else:
			_request.text = req
		var p := story.evidence_progress()
		if p.is_empty():
			_progress.text = ""
		else:
			_progress.text = "%s  ·  %d of %d photographs" % [str(p.get("text", "")), int(p.get("have", 0)), int(p.get("count", 1))]
	for c in _evidence_list.get_children():
		c.queue_free()
	var p2 := story.evidence_progress()
	if not p2.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		for pid in p2.get("photos", []):
			if int(pid) >= 0 and photos != null:
				var tex := photos.texture_for(int(pid))
				if tex != null:
					var pic := TextureRect.new()
					pic.texture = tex
					pic.custom_minimum_size = Vector2(200, 112)
					pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
					pic.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
					row.add_child(pic)
		if row.get_child_count() > 0:
			_evidence_list.add_child(row)
	for c in _chapters.get_children():
		c.queue_free()
	for ch in story.chapter_entries():
		var status := str(ch["status"])
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.11, 0.12, 0.145) if status != "active" else Color(0.13, 0.16, 0.20)
		sb.set_corner_radius_all(10)
		card.add_theme_stylebox_override("panel", sb)
		var m := MarginContainer.new()
		for s in ["left", "right", "top", "bottom"]:
			m.add_theme_constant_override("margin_" + s, 12)
		card.add_child(m)
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 3)
		m.add_child(c)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		c.add_child(top)
		var mark := Label.new()
		mark.text = "✓" if status == "done" else ("●" if status == "active" else "○")
		mark.add_theme_font_size_override("font_size", 16)
		mark.add_theme_color_override("font_color", Color(0.62, 0.86, 0.66) if status == "done" else (Color(0.66, 0.80, 0.94) if status == "active" else Color(0.46, 0.49, 0.53)))
		top.add_child(mark)
		var t := Label.new()
		t.text = "%d. %s" % [int(ch["index"]) + 1, str(ch["title"])]
		t.add_theme_font_size_override("font_size", 16)
		t.add_theme_color_override("font_color", Color(0.92, 0.93, 0.95) if status != "locked" else Color(0.52, 0.55, 0.59))
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(t)
		var badge := Label.new()
		badge.text = "done" if status == "done" else ("open" if status == "active" else "waiting")
		badge.add_theme_font_size_override("font_size", 11)
		badge.add_theme_color_override("font_color", Color(0.56, 0.60, 0.65))
		top.add_child(badge)
		if status == "active":
			var d := Label.new()
			d.text = "%s  %d/%d photographs" % [str(ch["evidence_text"]), int(ch["have"]), int(ch["count"])]
			d.add_theme_font_size_override("font_size", 12)
			d.add_theme_color_override("font_color", Color(0.72, 0.80, 0.86))
			c.add_child(d)
		_chapters.add_child(card)
	if story.started and story.chapter >= CHAPTERS_SIZE - 1:
		var more := Label.new()
		more.text = "The next part of the case is still being written."
		more.add_theme_font_size_override("font_size", 12)
		more.add_theme_color_override("font_color", Color(0.56, 0.60, 0.65))
		_chapters.add_child(more)

const CHAPTERS_SIZE := 3

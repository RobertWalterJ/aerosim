class_name Jobs
extends CanvasLayer
## The opt-in story and jobs layer (session B). DroneBudz sends small jobs; the player can ignore every one of them and
## keep flying any drone, any time.
##
## A job arrives as a DroneBudz message and waits in the Jobs page (Flight > DroneBudz jobs, or J while paused). Accept
## one and its objectives appear; photos taken with the shutter are checked against the objectives using the metadata
## the photo library already stores (the places in frame, the in-game clock, the weather, whether a fireworks show or a
## storm was running). A qualifying photo is attached to the objective and the friend replies. When every objective is
## done, Submit finishes the job, adds followers to the little channel and may open the next job.
##
## Story and jobs can be switched off in Display > Overlay and sound > Story and jobs. Nothing ever blocks the sandbox:
## no failure states, no deadlines, no forced camera, and the free flight, courses, weather events and all the aircraft
## stay exactly as they are.

const STATE := "user://story.cfg"
const FOLLOWERS := "followers"
const JOBS := [
	{
		"id": "lake", "from": "Maya", "title": "The lake at golden hour",
		"brief": "First video for the channel. Get me the lake with the light low over the water, something with the hills in it. Any drone will do.",
		"potential": {"followers": 2, "views": 3}, "next": "chapel",
		"objectives": [{"kind": "photo", "subject": "lake", "max_dist": 900.0, "text": "Photograph the lake"}],
	},
	{
		"id": "chapel", "from": "Riley", "title": "The chapel for the heritage page",
		"brief": "The trust is restoring the chapel and wants a clean photograph of it from the air for their page. Please keep clear of the graves on the way in.",
		"potential": {"followers": 2, "views": 2}, "next": "fireworks",
		"objectives": [{"kind": "photo", "subject": "chapel", "max_dist": 400.0, "text": "Photograph the chapel"}],
	},
	{
		"id": "fireworks", "from": "Jo", "title": "Fireworks coverage",
		"brief": "The festival needs one good burst for the poster. Wait for a show, get up high and catch a shell while the show is running. Night only, obviously.",
		"potential": {"followers": 3, "views": 3}, "next": "fields",
		"objectives": [{"kind": "photo", "fireworks": true, "night": true, "text": "Photograph a burst during a night show"}],
	},
	{
		"id": "fields", "from": "Riley", "title": "The harvest postcard",
		"brief": "The farm trust wants one good picture of the fields for their harvest postcard. Corn, barley, hay bales, whatever looks best. Get low over the rows if you can.",
		"potential": {"followers": 2, "views": 3}, "next": "",
		"objectives": [{"kind": "photo", "subject": "fields", "max_dist": 600.0, "text": "Photograph the farm fields"}],
	},
]

var hud: Hud
var library: PhotoLibrary
var notes: PhoneNotes
var _offers: Array = []          # job ids offered but not accepted
var _active: Array = []          # accepted job ids
var _done: Array = []            # completed job ids
var _followers := 0
var _money := 0
var _chat: ChatData              # the DroneBudz server; job events are posted there when it exists
var _views := 0
var _videos: Array = []          # every published video: uploads from the camera roll and edited cuts
var _editor := false             # has Maya become the pilot's editor friend yet
var _view_frac := 0.0
var _money_frac := 0.0
var _obj_done := {}              # job id -> Array of completed objective indices
var _obj_photo := {}             # "job:index" -> photo id
var _root: Control
var _list: VBoxContainer
var _followers_label: Label
var _open := false

func setup(h: Hud, lib: PhotoLibrary, n: PhoneNotes) -> void:
	hud = h
	library = lib
	notes = n
	layer = 31
	_load_state()
	_build_ui()
	if _offers.is_empty() and _active.is_empty() and _done.is_empty():
		_offers.append("lake")
		_save_state()
		_announce_offer("lake")

func _story_on() -> bool:
	return hud == null or bool(hud.story_on)

# ------------------------------------------------------------------ state
func _save_state() -> void:
	var cf := ConfigFile.new()
	cf.set_value(FOLLOWERS, "count", _followers)
	cf.set_value("economy", "money", _money)
	cf.set_value("channel", "views", _views)
	cf.set_value("channel", "videos", _videos)
	cf.set_value("channel", "editor", _editor)
	cf.set_value("jobs", "offers", _offers)
	cf.set_value("jobs", "active", _active)
	cf.set_value("jobs", "done", _done)
	cf.set_value("progress", "done", _obj_done)
	cf.set_value("progress", "photo", _obj_photo)
	cf.save(STATE)

func _load_state() -> void:
	var cf := ConfigFile.new()
	if cf.load(STATE) != OK:
		return
	_followers = int(cf.get_value(FOLLOWERS, "count", 0))
	_money = int(cf.get_value("economy", "money", 0))
	_views = int(cf.get_value("channel", "views", 0))
	_videos = cf.get_value("channel", "videos", [])
	_editor = bool(cf.get_value("channel", "editor", false))
	_offers = cf.get_value("jobs", "offers", [])
	_active = cf.get_value("jobs", "active", [])
	_done = cf.get_value("jobs", "done", [])
	_obj_done = cf.get_value("progress", "done", {})
	_obj_photo = cf.get_value("progress", "photo", {})

func followers() -> int:
	return _followers

func money() -> int:
	return _money

func views() -> int:
	return _views

func videos() -> Array:
	return _videos

func editor_friend() -> bool:
	return _editor

# ------------------------------------------------------------------ uploads, edits and passive channel growth
## The player publishes a photo from the camera roll. Straight to VidTube it does modestly; if Maya edits it first it
## does much better. The first self-upload is also how Maya becomes the pilot's editor friend: she watches it, messages
## the channel and offers to cut the next one.
func upload_photo(photo_id: int, meta: Dictionary, via_editor := false) -> Dictionary:
	var subjects: Array = meta.get("subjects", [])
	var quality := _quality(meta)
	var mult := 2.3 if via_editor else 1.0
	var base_views := 30.0 + float(_followers) * 0.45
	var views_gain := int(base_views * quality * mult)
	var gain := maxi(1, int((1.0 + quality * 2.0) * mult))
	var money_gain := int((3.0 + float(views_gain) * 0.03) * mult)
	_views += views_gain
	_followers += gain
	_money += money_gain
	var title := "DroneBudz clip " + str(_videos.size() + 1)
	if not subjects.is_empty():
		title = str(subjects[0].get("name", title))
	var rec := {"title": title, "views": views_gain, "followers": gain, "money": money_gain,
		"edited": via_editor, "photo": photo_id, "quality": snappedf(quality, 0.01)}
	_videos.append(rec)
	_save_state()
	if not _editor and not via_editor:
		_editor = true
		_save_state()
		if _chat != null:
			_chat.post("clips", "Maya", "Watched your upload. The light on that is really good, but the edit is doing nothing. I am your editor now. Send the next one in here and I will cut it before it goes up.", false)
		if notes != null:
			notes.post_text("Maya", "Maya is now your editor", "Upload to the DroneBudz #clips channel and she will edit it before it is published.", 1)
	elif via_editor and _chat != null:
		_chat.post("clips", "Maya", "Cut it and published it. %d views already. This is what happens when you let me edit." % views_gain, false)
	if _chat != null and not via_editor:
		_chat.post("clips", "You", "Uploaded a clip to VidTube." , false, true, photo_id)
	if notes != null and not (not _editor and not via_editor):
		notes.post_text("VidTube", "Your video is live", "%s earned %d views, %d followers and %d money." % [title, views_gain, gain, money_gain], 0)
	return rec

## Views and earnings keep ticking over between flights. Slow on purpose: the channel is small.
func tick(delta: float) -> void:
	var per_second := 0.04 + float(_followers) * 0.006
	_view_frac += per_second * delta
	var whole := int(_view_frac)
	if whole > 0:
		_view_frac -= float(whole)
		_views += whole
		_money_frac += float(whole) * 0.012
	var m := int(_money_frac)
	if m > 0:
		_money_frac -= float(m)
		_money += m

## The DroneBudz server: job events are also posted as chat messages there, so the story lives in one place.
func set_chat(c: ChatData) -> void:
	_chat = c

# ------------------------------------------------------------------ job flow
func _job(id: String) -> Dictionary:
	for j in JOBS:
		if str(j["id"]) == id:
			return j
	return {}

# ------------------------------------------------------------------ potential, not promises
const POTENTIAL_NAMES := ["low", "moderate", "high", "very high"]

func _potential_word(n: int) -> String:
	return POTENTIAL_NAMES[clampi(n, 0, POTENTIAL_NAMES.size() - 1)]

## What the job could do for the channel, in words. Exact numbers are never promised: the same job lands differently
## depending on the shot, the timing and whether Maya cuts it first.
func potential_text(job: Dictionary) -> String:
	var p: Dictionary = job.get("potential", {})
	var f := _potential_word(int(p.get("followers", 1)))
	var v := _potential_word(int(p.get("views", 1)))
	var text := "Follower potential: %s. View potential: %s." % [f, v]
	if _editor:
		text += " A proper edit by Maya lifts both further."
	else:
		text += " An editor would lift both further."
	return text

## The same idea for a single photo in the camera roll, before it is published.
func photo_potential(meta: Dictionary) -> String:
	var q := _quality(meta)
	var f := _potential_word(0 if q < 0.9 else (1 if q < 1.2 else (2 if q < 1.5 else 3)))
	var v := _potential_word(1 if q < 0.9 else (2 if q < 1.3 else 3))
	var text := "Reach potential: %s views, %s followers." % [v, f]
	if _editor:
		text += " Maya's edit can lift this a lot."
	else:
		text += " An editor could lift this a lot."
	return text

func _quality(meta: Dictionary) -> float:
	var subjects: Array = meta.get("subjects", [])
	var q := 0.65 + 0.14 * minf(subjects.size(), 3)
	if bool(meta.get("night", false)):
		q += 0.08
	if bool(meta.get("fireworks", false)):
		q += 0.35
	if bool(meta.get("storm", false)):
		q += 0.25
	return clampf(q, 0.5, 1.8)

func _announce_offer(job_id: String) -> void:
	var job := _job(job_id)
	if job.is_empty() or notes == null:
		return
	notes.post_text(str(job["from"]), "New job: " + str(job["title"]),
		str(job["brief"]) + "  Open Flight > DroneBudz jobs to take it.", 0)
	if _chat != null:
		_chat.post("jobs", str(job["from"]), "New job on the board: %s. %s" % [str(job["title"]), str(job["brief"])], true)

func accept(job_id: String) -> void:
	if not job_id in _offers:
		return
	_offers.erase(job_id)
	if not job_id in _active:
		_active.append(job_id)
	_save_state()
	if notes != null:
		var job := _job(job_id)
		notes.post_text(str(job["from"]), "On it", "Thanks! Send it over when it is done.", 0)
		if _chat != null:
			_chat.post("jobs", "You", "Accepted: " + str(job["title"]), false, true)
	_refresh()

func decline(job_id: String) -> void:
	if job_id in _offers:
		_offers.erase(job_id)
		_save_state()
		_refresh()

## A photo was saved. Check it against every open objective.
func on_photo(photo_id: int, meta: Dictionary) -> void:
	var changed := false
	for jid in _active:
		var job := _job(jid)
		if job.is_empty():
			continue
		var done: Array = _obj_done.get(jid, [])
		for oi in job["objectives"].size():
			if oi in done:
				continue
			if _matches(job["objectives"][oi], meta):
				done.append(oi)
				_obj_done[jid] = done
				_obj_photo["%s:%d" % [jid, oi]] = photo_id
				changed = true
				if notes != null:
					notes.post_text(str(job["from"]), "Got it",
						"That is exactly the sort of shot I wanted. Thank you!" if done.size() < job["objectives"].size() else "That is the last one. Submit the job and I will send it up.", 0)
		if done.size() == job["objectives"].size() and changed:
			if notes != null:
				notes.post_text(str(job["from"]), "Ready to send",
					"The job is complete. Open Flight > DroneBudz jobs and hit Submit.", 1)
	if changed:
		_save_state()
		_refresh()

func _matches(o: Dictionary, meta: Dictionary) -> bool:
	if o.get("night", false) and not bool(meta.get("night", false)):
		return false
	if o.get("fireworks", false) and not bool(meta.get("fireworks", false)):
		return false
	if o.get("storm", false) and not bool(meta.get("storm", false)):
		return false
	if o.has("subject"):
		var want := str(o["subject"])
		var max_d := float(o.get("max_dist", 900.0))
		for s in meta.get("subjects", []):
			if str(s.get("id", "")) == want and float(s.get("dist", 9999.0)) <= max_d:
				return true
		return false
	return true

func submit(job_id: String, edited := false) -> void:
	if not job_id in _active:
		return
	var done: Array = _obj_done.get(job_id, [])
	var job := _job(job_id)
	if job.is_empty() or done.size() < job["objectives"].size():
		return
	if edited and not _editor:
		edited = false
	_active.erase(job_id)
	_done.append(job_id)
	var before_followers := _followers
	var before_money := _money
	# the payout is earned, not promised: the job's potential, the photo quality and Maya's cut all matter
	var pot: Dictionary = job.get("potential", {})
	var pid := photo_for(job_id, 0)
	var meta: Dictionary = {}
	if library != null and pid >= 0:
		meta = library.meta_for(pid)
	var quality := _quality(meta) if not meta.is_empty() else 1.0
	var mult := 1.9 if edited else 1.0
	var views_gain := int((90.0 + 110.0 * float(int(pot.get("views", 1)))) * (1.0 + float(_followers) * 0.012) * quality * mult)
	var gain := maxi(2, int((4.0 + 6.0 * float(int(pot.get("followers", 1)))) * (1.0 + float(_followers) * 0.004) * quality * (1.6 if edited else 1.0)))
	var money_gain := int(float(views_gain) * 0.025 * (1.5 if edited else 1.0)) + 10
	_views += views_gain
	_followers += gain
	_money += money_gain
	_videos.append({"title": str(job.get("title", "")), "views": views_gain, "followers": gain,
		"money": money_gain, "edited": edited, "photo": pid, "quality": snappedf(quality, 0.01)})
	_save_state()
	if notes != null:
		notes.post_text(str(job["from"]), "Published: +%d followers, +%d money" % [gain, money_gain],
			"The channel is at %d followers and %d views from this one. Nice work." % [_followers, views_gain], 0)
	if _chat != null:
		_chat.post("jobs", str(job["from"]),
			"Published: %s. %d views, %d followers and %d money so far." % [str(job.get("title", "")), views_gain, gain, money_gain], true)
		if edited:
			_chat.post("clips", "Maya", "I cut the job footage before it went up. %d views so far. That is what an edit does." % views_gain, false)
		for th in [30, 60, 120, 250]:
			if before_followers < th and _followers >= th:
				_chat.post("clips", "Maya", "%d followers! That is the biggest week this channel has had. Keep the shots coming." % th, false)
		for th in [100, 250, 500]:
			if before_money < th and _money >= th:
				_chat.post("general", "Alex", "%d in the channel pot. That is the new props paid for, and maybe a second battery." % th, false)
	var nxt := str(job.get("next", ""))
	if nxt != "" and not nxt in _done and not nxt in _active and not nxt in _offers:
		_offers.append(nxt)
		_save_state()
		_announce_offer(nxt)
	_refresh()

func objective_done(job_id: String, index: int) -> bool:
	return index in _obj_done.get(job_id, [])

func photo_for(job_id: String, index: int) -> int:
	return int(_obj_photo.get("%s:%d" % [job_id, index], -1))

# ------------------------------------------------------------------ the page
func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.76)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.095, 0.11, 0.99)
	sb.set_corner_radius_all(22)
	sb.border_width_left = 1; sb.border_width_top = 1; sb.border_width_right = 1; sb.border_width_bottom = 1
	sb.border_color = Color(1, 1, 1, 0.08)
	panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(panel)
	panel.anchor_left = 0.08; panel.anchor_right = 0.92
	panel.anchor_top = 0.06; panel.anchor_bottom = 0.94
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.text = "DroneBudz jobs"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.97, 0.97, 0.98))
	head.add_child(title)
	_followers_label = Label.new()
	_followers_label.add_theme_font_size_override("font_size", 15)
	_followers_label.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78))
	_followers_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_followers_label)
	var stretch := Control.new()
	stretch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(stretch)
	var close := Button.new()
	close.text = "Close"
	close.flat = true
	close.add_theme_font_size_override("font_size", 16)
	close.add_theme_color_override("font_color", Color(0.80, 0.82, 0.86))
	close.pressed.connect(close_page)
	head.add_child(close)
	var hint := Label.new()
	hint.text = "Optional jobs from the DroneBudz group. Ignore them and the sandbox is unchanged."
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.60, 0.62, 0.66))
	col.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	_root.visible = false

func _refresh() -> void:
	if _list == null:
		return
	for ch in _list.get_children():
		ch.queue_free()
	_followers_label.text = "   %d followers" % _followers
	if not _story_on():
		var off := Label.new()
		off.text = "Story and jobs are switched off in Display > Overlay and sound."
		off.add_theme_font_size_override("font_size", 15)
		off.add_theme_color_override("font_color", Color(0.66, 0.68, 0.72))
		_list.add_child(off)
	# offers
	for jid in _offers:
		_list.add_child(_offer_card(str(jid)))
	# active
	for jid in _active:
		_list.add_child(_active_card(str(jid)))
	# done
	for jid in _done:
		var job := _job(str(jid))
		var l := Label.new()
		l.text = "Done: %s  ·  published" % str(job.get("title", ""))
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", Color(0.62, 0.74, 0.66))
		_list.add_child(l)
	if _offers.is_empty() and _active.is_empty():
		var none := Label.new()
		none.text = "No open jobs right now. The group will message you when something comes up."
		none.add_theme_font_size_override("font_size", 15)
		none.add_theme_color_override("font_color", Color(0.68, 0.70, 0.74))
		_list.add_child(none)

func _card(title_text: String, from: String) -> Dictionary:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.145, 0.15, 0.165, 0.98)
	sb.set_corner_radius_all(18)
	card.add_theme_stylebox_override("panel", sb)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	card.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	pad.add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	var t := Label.new()
	t.text = title_text
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", Color(0.96, 0.96, 0.97))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var who := Label.new()
	who.text = from
	who.add_theme_font_size_override("font_size", 14)
	who.add_theme_color_override("font_color", Color(0.70, 0.76, 0.82))
	top.add_child(who)
	return {"card": card, "col": col}

func _offer_card(jid: String) -> PanelContainer:
	var job := _job(jid)
	var parts := _card(str(job["title"]), str(job["from"]))
	var col: VBoxContainer = parts["col"]
	var brief := Label.new()
	brief.text = str(job["brief"])
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.add_theme_font_size_override("font_size", 14)
	brief.add_theme_color_override("font_color", Color(0.76, 0.78, 0.82))
	col.add_child(brief)
	var potential := Label.new()
	potential.text = potential_text(job)
	potential.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	potential.add_theme_font_size_override("font_size", 13)
	potential.add_theme_color_override("font_color", Color(0.66, 0.82, 0.70))
	col.add_child(potential)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var take := Button.new(); take.text = "Accept job"; take.custom_minimum_size = Vector2(130, 40)
	take.pressed.connect(func(): accept(jid))
	row.add_child(take)
	var skip := Button.new(); skip.text = "Not now"; skip.flat = true; skip.custom_minimum_size = Vector2(100, 40)
	skip.pressed.connect(func(): decline(jid))
	row.add_child(skip)
	return parts["card"]

func _active_card(jid: String) -> PanelContainer:
	var job := _job(jid)
	var parts := _card(str(job["title"]), str(job["from"]))
	var col: VBoxContainer = parts["col"]
	var objectives: Array = job["objectives"]
	var done: Array = _obj_done.get(jid, [])
	for oi in objectives.size():
		var o: Dictionary = objectives[oi]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		col.add_child(row)
		var tick := Label.new()
		var ok: bool = oi in done
		tick.text = "✓" if ok else "○"
		tick.add_theme_font_size_override("font_size", 18)
		tick.add_theme_color_override("font_color", Color(0.62, 0.86, 0.66) if ok else Color(0.62, 0.64, 0.68))
		row.add_child(tick)
		var line := Label.new()
		line.text = str(o.get("text", "Objective"))
		line.add_theme_font_size_override("font_size", 15)
		line.add_theme_color_override("font_color", Color(0.92, 0.92, 0.94) if ok else Color(0.76, 0.78, 0.82))
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(line)
		var pid := photo_for(jid, oi)
		if pid >= 0 and library != null:
			var tex := library.texture_for(pid)
			if tex != null:
				var pic := TextureRect.new()
				pic.texture = tex
				pic.custom_minimum_size = Vector2(96, 54)
				pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				row.add_child(pic)
	var all_done := done.size() >= objectives.size()
	var potential := Label.new()
	potential.text = potential_text(job)
	potential.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	potential.add_theme_font_size_override("font_size", 13)
	potential.add_theme_color_override("font_color", Color(0.66, 0.82, 0.70))
	col.add_child(potential)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	col.add_child(row2)
	var raw_btn := Button.new(); raw_btn.text = "Publish raw"; raw_btn.custom_minimum_size = Vector2(120, 40)
	raw_btn.disabled = not all_done
	raw_btn.tooltip_text = "Publish the footage as it is. The result depends on the shot and the channel."
	raw_btn.pressed.connect(func(): submit(jid, false))
	row2.add_child(raw_btn)
	if _editor:
		var edit_btn := Button.new(); edit_btn.text = "Send to Maya (edited)"; edit_btn.custom_minimum_size = Vector2(180, 40)
		edit_btn.disabled = not all_done
		edit_btn.tooltip_text = "Maya cuts it first. A proper edit lifts views and followers a lot."
		edit_btn.pressed.connect(func(): submit(jid, true))
		row2.add_child(edit_btn)
	return parts["card"]

func open_page() -> void:
	_refresh()
	_root.visible = true
	_open = true

func close_page() -> void:
	_root.visible = false
	_open = false

func toggle() -> void:
	if _open:
		close_page()
	else:
		open_page()

func is_open() -> bool:
	return _open

func stats() -> Dictionary:
	return {"offers": _offers.size(), "active": _active.size(), "done": _done.size(),
		"followers": _followers, "money": _money, "open": _open}

## What Jo can talk about in the crew chat: the open offers and the accepted work.
func offers_list() -> Array:
	var out: Array = []
	for id in _offers:
		var job := _job(str(id))
		if not job.is_empty():
			out.append(job)
	return out

func active_list() -> Array:
	var out: Array = []
	for id in _active:
		var job := _job(str(id))
		if not job.is_empty():
			out.append(job)
	return out

func last_video() -> Dictionary:
	return _videos[-1] if not _videos.is_empty() else {}

## Dev hook: take the first offer, mark its objectives done with the newest photo if there is one, and open the page.
func debug_demo() -> void:
	if _offers.is_empty() and _active.is_empty():
		_offers.append("lake")
	if not _offers.is_empty():
		accept(str(_offers[0]))
	var jid := str(_active[0]) if not _active.is_empty() else ""
	if jid != "":
		var job := _job(jid)
		var done: Array = _obj_done.get(jid, [])
		var pid := -1
		if library != null and library.count() > 0:
			pid = int(library.photos()[-1].get("id", -1))
		for oi in job["objectives"].size():
			if not oi in done:
				done.append(oi)
				_obj_photo["%s:%d" % [jid, oi]] = pid
		_obj_done[jid] = done
		_save_state()
	open_page()

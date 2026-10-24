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
		"objectives": [{"kind": "photo", "subject": "lake", "max_dist": 900.0, "frame_margin": 0.10, "ideal_min": 80.0, "ideal_max": 420.0, "text": "Photograph the lake"}],
	},
	{
		"id": "chapel", "from": "Riley", "title": "The chapel for the heritage page",
		"brief": "The trust is restoring the chapel and wants a clean photograph of it from the air for their page. Please keep clear of the graves on the way in.",
		"potential": {"followers": 2, "views": 2}, "next": "fireworks",
		"objectives": [{"kind": "photo", "subject": "chapel", "min_dist": 18.0, "max_dist": 400.0, "frame_margin": 0.16, "ideal_min": 35.0, "ideal_max": 180.0, "text": "Photograph the chapel", "safety": "Keep at least 18 m clear of the graves", "too_close": "I called. You went right over the graves. The trust has pulled the job."}],
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
		"potential": {"followers": 2, "views": 3}, "next": "windmill",
		"objectives": [{"kind": "photo", "subject": "fields", "min_dist": 30.0, "max_dist": 600.0, "frame_margin": 0.12, "ideal_min": 70.0, "ideal_max": 300.0, "text": "Photograph the farm fields", "safety": "Keep at least 30 m clear of the stock", "too_close": "I called. You came down over the sheep and scattered them. The job is pulled."}],
	},
	{
		"id": "favour_lake", "from": "Sam", "title": "A favour: lake reading",
		"brief": "Not a channel job. I need a photograph of the lake for the weather board, same view every week. I will put something in the channel pot for the fuel.",
		"potential": {"followers": 1, "views": 1}, "next": "", "favour_pay": 35,
		"objectives": [{"kind": "photo", "subject": "lake", "max_dist": 900.0, "frame_margin": 0.10, "ideal_min": 100.0, "ideal_max": 450.0, "text": "Photograph the lake for Sam"}],
	},
	{
		"id": "favour_chapel", "from": "Jo", "title": "A favour: chapel handbill",
		"brief": "The festival committee needs one clean photograph of the chapel for a handbill. Small thing, but they pay in cash and cake. Mostly cake.",
		"potential": {"followers": 1, "views": 1}, "next": "", "favour_pay": 30,
		"objectives": [{"kind": "photo", "subject": "chapel", "min_dist": 15.0, "max_dist": 500.0, "frame_margin": 0.14, "ideal_min": 30.0, "ideal_max": 200.0, "text": "Photograph the chapel for Jo", "safety": "Keep at least 15 m clear of the graves", "too_close": "I called. The committee saw the drone over the graves. They have taken the job back."}],
	},
	{
		"id": "favour_fields", "from": "Alex", "title": "A favour: field check",
		"brief": "Riley wants to know which field is still standing after the wind. One photo over the rows will do. I will cover the fuel and a set of props.",
		"potential": {"followers": 1, "views": 1}, "next": "", "favour_pay": 40,
		"objectives": [{"kind": "photo", "subject": "fields", "min_dist": 30.0, "max_dist": 700.0, "frame_margin": 0.12, "ideal_min": 80.0, "ideal_max": 320.0, "text": "Photograph the fields for Alex", "safety": "Keep at least 30 m clear of the stock", "too_close": "I called. Riley saw the flock break for the hedges. The job is pulled."}],
	},
	{
		"id": "windmill", "from": "Jo", "title": "The mill in detail",
		"brief": "The heritage group wants a close study of the sails for their repair appeal. Get the mill large in frame, but keep a safe distance from the turning sails. If it is too small it is no use, and if you are too close they will call the estate.",
		"potential": {"followers": 3, "views": 2}, "next": "",
		"objectives": [{"kind": "photo", "subject": "windmill", "min_dist": 14.0, "max_dist": 90.0, "frame_margin": 0.18, "ideal_min": 22.0, "ideal_max": 60.0, "text": "Photograph the mill sails close but safe", "safety": "Keep at least 14 m clear of the turning sails", "too_close": "I called. The estate says you nearly hit the sails. They have pulled the job."}],
	},
]

var hud: Hud
var library: PhotoLibrary
var notes: PhoneNotes
var _offers: Array = []          # job ids offered but not accepted
var _active: Array = []          # accepted job ids
var _done: Array = []            # completed job ids
var _failed: Array = []          # jobs pulled for a safety or repeated framing/range failure
var _fail_reason := {}           # job id -> "too_close", "too_far" or "frame"
var _misses := {}                # "job:objective:mode" -> count of retake warnings
var _followers := 0
var _money := 0
var _chat: ChatData              # the DroneBudz server; job events are posted there when it exists
var clips: ClipLibrary            # the representative rushes from video mode (no video files)
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
		_offers.append_array(["lake", "favour_lake", "favour_chapel", "favour_fields"])
		_save_state()
		for jid in ["lake", "favour_lake", "favour_chapel", "favour_fields"]:
			_announce_offer(str(jid))

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
	cf.set_value("jobs", "failed", _failed)
	cf.set_value("jobs", "fail_reason", _fail_reason)
	cf.set_value("jobs", "misses", _misses)
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
	_failed = cf.get_value("jobs", "failed", [])
	_fail_reason = cf.get_value("jobs", "fail_reason", {})
	_misses = cf.get_value("jobs", "misses", {})
	_obj_done = cf.get_value("progress", "done", {})
	_obj_photo = cf.get_value("progress", "photo", {})

func followers() -> int:
	return _followers

func money() -> int:
	return _money

## Story rewards, community fund payments and other one-off additions to the channel pot.
func add_money(amount: int) -> void:
	_money += amount
	_save_state()

func add_followers(amount: int) -> void:
	_followers += amount
	_save_state()

## Facade purchases come out of the same channel pot the Studio shows. Returns false when the pot is too small.
func spend(amount: int) -> bool:
	if amount <= 0:
		return true
	if _money < amount:
		return false
	_money -= amount
	_save_state()
	return true

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
			notes.post_text("Maya", "Your editor", "I am your editor now. Send the next clip to #clips and I will cut it before it goes up.", 1)
	elif via_editor and _chat != null:
		_chat.post("clips", "Maya", "Cut it and published it. %d views already. This is what happens when you let me edit." % views_gain, false)
	if _chat != null and not via_editor:
		_chat.post("clips", "You", "Uploaded a clip to VidTube." , false, true, photo_id)
	if notes != null and not (not _editor and not via_editor):
		notes.post_text("VidTube", "Your video is live", "%s earned %d views, %d followers and $%d." % [title, views_gain, gain, money_gain], 0)
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

func set_clips(c: ClipLibrary) -> void:
	clips = c

## Publish one representative clip. There is no video file to render; the thumbnail and duration are the representation.
func upload_clip(clip: Dictionary, via_editor := false) -> Dictionary:
	if clip.is_empty():
		return {}
	var quality := float(clip.get("quality", 1.0))
	var mult := 2.3 if via_editor else 1.0
	var views_gain := int((30.0 + float(_followers) * 0.45) * quality * mult)
	var gain := maxi(1, int((1.0 + quality * 2.0) * mult))
	var money_gain := int((3.0 + float(views_gain) * 0.03) * mult)
	_views += views_gain
	_followers += gain
	_money += money_gain
	var title := str(clip.get("title", "A valley clip"))
	if via_editor:
		title += "  ·  Maya cut"
	var rec := {
		"title": title, "views": views_gain, "followers": gain, "money": money_gain,
		"edited": via_editor, "photo": -1, "thumb": str(clip.get("thumb", "")),
		"duration": float(clip.get("duration", 0.0)), "clip_ids": [int(clip.get("id", -1))],
		"clips": 1, "clip_thumbs": [str(clip.get("thumb", ""))], "quality": quality,
	}
	_videos.append(rec)
	_save_state()
	if clips != null:
		clips.mark_published(rec["clip_ids"], title)
	_editor = true
	_save_state()
	if _chat != null:
		if via_editor:
			_chat.post("clips", "Maya", "Cut and published. %d views already. One clean clip, one good thumbnail, that is all it takes." % views_gain, false)
		else:
			_chat.post("clips", "You", "Uploaded a clip to VidTube.", false, true)
	if notes != null:
		notes.post_text("VidTube", "Your video is live", "%s earned %d views, %d followers and $%d." % [title, views_gain, gain, money_gain], 0)
	return rec

## String every waiting rush into one polished video. The result is a single representative video with a clip count and
## the best thumbnail; no footage is rendered or written.
func publish_rushes(via_editor := true) -> Dictionary:
	if clips == null:
		return {}
	var rushes := clips.rushes()
	if rushes.is_empty():
		return {}
	var ids: Array = []
	var thumbs: Array = []
	var duration := 0.0
	var quality := 0.0
	for r in rushes:
		ids.append(int(r.get("id", -1)))
		if thumbs.size() < 4:
			thumbs.append(str(r.get("thumb", "")))
		duration += float(r.get("duration", 0.0))
		quality += float(r.get("quality", 1.0))
	quality = quality / float(rushes.size())
	var best := clips.best_thumbnail(rushes)
	var title := "The valley in %d clips" % rushes.size() if rushes.size() > 1 else str(best.get("title", "A valley clip"))
	if via_editor:
		title = ("The valley, cut by Maya" if rushes.size() > 1 else str(best.get("title", "A valley clip")) + "  ·  Maya cut")
		quality += 0.30
	if rushes.size() > 1:
		quality += 0.18
	var mult := 2.3 if via_editor else 1.0
	var views_gain := int((30.0 + float(_followers) * 0.45) * quality * mult)
	var gain := maxi(1, int((1.0 + quality * 2.0) * mult))
	var money_gain := int((3.0 + float(views_gain) * 0.03) * mult)
	_views += views_gain
	_followers += gain
	_money += money_gain
	var rec := {
		"title": title, "views": views_gain, "followers": gain, "money": money_gain,
		"edited": via_editor, "photo": -1, "thumb": str(best.get("thumb", "")),
		"duration": duration, "clip_ids": ids, "clips": rushes.size(), "clip_thumbs": thumbs,
		"quality": snappedf(quality, 0.01),
	}
	_videos.append(rec)
	_save_state()
	clips.mark_published(ids, title)
	_editor = true
	_save_state()
	if _chat != null:
		_chat.post("clips", "Maya", "Cut and published. %d views already. %d rushes, one thumbnail, one story. That is what an edit does." % [views_gain, rushes.size()], false)
	if notes != null:
		notes.post_text("VidTube", "Your cut is live", "%s earned %d views, %d followers and $%d." % [title, views_gain, gain, money_gain], 0)
	return rec

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
	notes.post_text(str(job["from"]), "New job: " + str(job["title"]), str(job["brief"]), 0)
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
		notes.post_text(str(job["from"]), "Job accepted", "Send it over when it is done.", 0)
		if _chat != null:
			_chat.post("jobs", "You", "Accepted: " + str(job["title"]), false, true)
	_refresh()

func decline(job_id: String) -> void:
	if job_id in _offers:
		_offers.erase(job_id)
		_save_state()
		_refresh()

## A photo was saved. Check it against every open objective. A photo that breaks a keep-clear distance fails the
## job immediately; a photo that is too far away or clips the subject gets a retake warning, and three warnings pull
## the job. A good photo attaches to the objective as before.
func on_photo(photo_id: int, meta: Dictionary) -> void:
	var changed := false
	for jid in _active.duplicate():
		var job := _job(jid)
		if job.is_empty():
			continue
		var done: Array = _obj_done.get(jid, [])
		var pulled := false
		for oi in job["objectives"].size():
			if oi in done:
				continue
			var o: Dictionary = job["objectives"][oi]
			var status := _objective_status(o, meta)
			if status == "ok":
				done.append(oi)
				_obj_done[jid] = done
				_obj_photo["%s:%d" % [jid, oi]] = photo_id
				changed = true
				if notes != null:
					notes.post_text(str(job["from"]), "Got it",
						"That is exactly the sort of shot I wanted. Thank you!" if done.size() < job["objectives"].size() else "That is the last one. Submit the job and I will send it up.", 0)
			elif status == "too_close":
				_fail_job(jid, "too_close", o)
				changed = true
				pulled = true
				break
			elif status == "too_far" or status == "frame":
				_miss(jid, oi, status, o)
				changed = true
				break
		if pulled:
			continue
		if done.size() == job["objectives"].size() and changed:
			if notes != null:
				notes.post_text(str(job["from"]), "Ready to send", "The job is complete. Send it up when you are ready.", 1)
	if changed:
		_save_state()
		_refresh()

func _best_subject(o: Dictionary, meta: Dictionary) -> Dictionary:
	if not o.has("subject"):
		return {}
	var want := str(o["subject"])
	var best: Dictionary = {}
	var best_d := 1e9
	for s in meta.get("subjects", []):
		if str(s.get("id", "")) == want:
			var d := float(s.get("dist", 9999.0))
			if d < best_d:
				best_d = d
				best = s
	return best

## ok: the photo satisfies the objective. too_close: unsafe; fail the job. too_far / frame: retake.
func _objective_status(o: Dictionary, meta: Dictionary) -> String:
	if not o.has("subject"):
		return "ok" if _matches(o, meta) else "none"
	var s := _best_subject(o, meta)
	if s.is_empty():
		return "none"
	var d := float(s.get("dist", 9999.0))
	var min_d := float(o.get("min_dist", 0.0))
	var max_d := float(o.get("max_dist", 900.0))
	if min_d > 0.0 and d < min_d:
		return "too_close"
	if d > max_d:
		return "too_far"
	var need := float(o.get("frame_margin", 0.0))
	if need > 0.0 and float(s.get("frame_margin", 1.0)) < need:
		return "frame"
	return "ok"

func _fail_job(jid: String, mode: String, o: Dictionary) -> void:
	if jid in _failed:
		return
	_active.erase(jid)
	_failed.append(jid)
	_fail_reason[jid] = mode
	_save_state()
	var job := _job(jid)
	var who := str(job.get("from", "the contact"))
	var msg := ""
	if mode == "too_close":
		msg = str(o.get("too_close", ""))
		if msg == "":
			msg = "I called. You were too close to the subject and the job has been pulled."
	elif mode == "too_far":
		msg = "I called. The subject stayed out of useful range and the job has been pulled."
	else:
		msg = "I called. The subject was never held cleanly inside the frame and the job has been pulled."
	if _chat != null:
		_chat.post("jobs", who, msg, false)
	if notes != null:
		notes.post_text(who, "Job pulled", msg, 1)
	if hud != null:
		hud.toast("Job pulled: " + failure_text(jid), true, "DRONEBUDZ")
	_refresh()

func _miss(jid: String, oi: int, mode: String, o: Dictionary) -> void:
	var key := "%s:%d:%s" % [jid, oi, mode]
	var count := int(_misses.get(key, 0)) + 1
	_misses[key] = count
	var job := _job(jid)
	var who := str(job.get("from", "the contact"))
	if count >= 3:
		_fail_job(jid, mode, o)
		return
	var msg := ""
	if mode == "too_far":
		msg = "That is too far away. The subject is only a speck in the frame. Get inside %.0f m and send another." % float(o.get("max_dist", 900.0))
	else:
		msg = "The subject is clipped at the edge of the frame. Keep it fully inside and send another."
	if _chat != null:
		_chat.post("jobs", who, msg, false)
	if notes != null:
		notes.post_text(who, "Retake needed (%d/3)" % count, msg, 0)
	if hud != null:
		hud.toast("Retake needed: " + ("too far" if mode == "too_far" else "subject clipped"), true, "DRONEBUDZ")
	_save_state()

func failure_text(jid: String) -> String:
	var mode := str(_fail_reason.get(jid, ""))
	if mode == "too_close":
		return "too close and pulled"
	if mode == "too_far":
		return "never in range"
	if mode == "frame":
		return "never held in frame"
	return "pulled"

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
		var min_d := float(o.get("min_dist", 0.0))
		var need := float(o.get("frame_margin", 0.0))
		for s in meta.get("subjects", []):
			if str(s.get("id", "")) != want:
				continue
			var d := float(s.get("dist", 9999.0))
			if d > max_d:
				continue
			if min_d > 0.0 and d < min_d:
				continue
			if need > 0.0 and float(s.get("frame_margin", 1.0)) < need:
				continue
			return true
		return false
	return true

## A job can be good, but a really well framed shot inside the sweet distance band gets a genuinely warm response.
func _grade(job: Dictionary) -> String:
	var excellent := true
	var poor := false
	var objectives: Array = job["objectives"]
	for oi in objectives.size():
		var o: Dictionary = objectives[oi]
		var pid := photo_for(str(job["id"]), oi)
		if pid < 0 or library == null:
			return "good"
		var meta: Dictionary = library.meta_for(pid)
		if _objective_status(o, meta) != "ok":
			return "good"
		if o.has("subject"):
			var s := _best_subject(o, meta)
			var fm := float(s.get("frame_margin", 1.0))
			var frame_need := maxf(float(o.get("frame_margin", 0.10)) * 1.5, 0.20)
			if fm < frame_need:
				excellent = false
			if fm < maxf(float(o.get("frame_margin", 0.10)) * 1.05, 0.12):
				poor = true
			var d := float(s.get("dist", 9999.0))
			var lo := float(o.get("ideal_min", maxf(float(o.get("min_dist", 0.0)) * 1.3, 20.0)))
			var hi := float(o.get("ideal_max", float(o.get("max_dist", 900.0)) * 0.6))
			if d < lo or d > hi:
				excellent = false
			if _quality(meta) < 0.76:
				excellent = false
			if _quality(meta) < 0.70:
				poor = true
		elif _quality(meta) < 1.05:
			excellent = false
	if excellent:
		return "excellent"
	if poor:
		return "poor"
	return "good"
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
	var grade := _grade(job)
	var grade_mult := 1.45 if grade == "excellent" else (0.72 if grade == "poor" else 1.0)
	var mult := (1.9 if edited else 1.0) * grade_mult
	var views_gain := int((90.0 + 110.0 * float(int(pot.get("views", 1)))) * (1.0 + float(_followers) * 0.012) * quality * mult)
	var gain := maxi(2, int((4.0 + 6.0 * float(int(pot.get("followers", 1)))) * (1.0 + float(_followers) * 0.004) * quality * (1.6 if edited else 1.0)))
	var money_gain := int(float(views_gain) * 0.025 * (1.5 if edited else 1.0)) + 10 + int(job.get("favour_pay", 0))
	if grade == "excellent":
		gain += 2
		money_gain += 25
	_views += views_gain
	_followers += gain
	_money += money_gain
	_videos.append({"title": str(job.get("title", "")), "views": views_gain, "followers": gain,
		"money": money_gain, "edited": edited, "photo": pid, "quality": snappedf(quality, 0.01), "grade": grade})
	_save_state()
	if notes != null:
		var body := "The channel is at %d followers and %d views from this one. Nice work." % [_followers, views_gain]
		var title := "Your shot is live: +%d followers, +$%d" % [gain, money_gain]
		if grade == "excellent":
			title = "That is the shot: +%d followers, +$%d" % [gain, money_gain]
			body = "The contact says that is better than the brief and added a $25 bonus to the pot. %d followers and %d views from this one." % [gain, views_gain]
		elif grade == "poor":
			title = "It is up, but not the shot they wanted: +%d followers, +$%d" % [gain, money_gain]
			body = "The contact wanted more from it. The channel is at %d followers and %d views." % [_followers, views_gain]
		notes.post_text("VidTube", title, body, 0)
	if _chat != null:
		_chat.post("jobs", str(job["from"]),
			"Published: %s. %d views, %d followers and $%d so far." % [str(job.get("title", "")), views_gain, gain, money_gain], true)
		if grade == "excellent":
			_chat.post("jobs", str(job["from"]), "That is not a job shot, that is a portfolio shot. I have put a bonus in the pot and told the committee your name.", false)
			_chat.post("clips", "Maya", "I saw the frame. That is the cleanest one that has come through this channel. Keep that up.", false)
		elif grade == "poor":
			_chat.post("jobs", str(job["from"]), "It is up, but it is not the shot I hoped for. The next one needs cleaner framing and a closer look.", false)
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
	_root.theme = UniverseUI.make_theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.035, 0.03, 0.80)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.075, 0.090, 0.078, 0.99)
	sb.set_corner_radius_all(22)
	sb.border_width_left = 1; sb.border_width_top = 1; sb.border_width_right = 1; sb.border_width_bottom = 1
	sb.border_color = Color(0.88, 0.74, 0.50, 0.22)
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
	title.add_theme_color_override("font_color", Color(0.94, 0.912, 0.82))
	head.add_child(title)
	_followers_label = Label.new()
	_followers_label.add_theme_font_size_override("font_size", 15)
	_followers_label.add_theme_color_override("font_color", Color(0.60, 0.63, 0.555))
	_followers_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_followers_label)
	var stretch := Control.new()
	stretch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(stretch)
	var close := Button.new()
	close.text = "Close"
	close.flat = true
	close.add_theme_font_size_override("font_size", 16)
	close.add_theme_color_override("font_color", Color(0.94, 0.912, 0.82))
	close.pressed.connect(close_page)
	head.add_child(close)
	var hint := Label.new()
	hint.text = "Jobs from the DroneBudz crew. Take one when you want the work. Nothing is forced."
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.60, 0.63, 0.555))
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
		off.text = "The board is resting. Story and jobs are switched off in the kit settings."
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
	# pulled
	for jid in _failed:
		var job := _job(str(jid))
		var fl := Label.new()
		fl.text = "Pulled: %s  ·  %s" % [str(job.get("title", "")), failure_text(str(jid))]
		fl.add_theme_font_size_override("font_size", 14)
		fl.add_theme_color_override("font_color", Color(0.82, 0.48, 0.38))
		_list.add_child(fl)
	if _offers.is_empty() and _active.is_empty():
		var none := Label.new()
		none.text = "No open jobs right now. The group will message you when something comes up."
		none.add_theme_font_size_override("font_size", 15)
		none.add_theme_color_override("font_color", Color(0.68, 0.70, 0.74))
		_list.add_child(none)

func _requirement_text(o: Dictionary) -> String:
	var bits: Array[String] = []
	var min_d := float(o.get("min_dist", 0.0))
	var max_d := float(o.get("max_dist", 0.0))
	if min_d > 0.0:
		bits.append("Keep %.0f m clear" % min_d)
	if max_d > 0.0:
		bits.append("Stay within %.0f m" % max_d)
	if float(o.get("frame_margin", 0.0)) > 0.0:
		bits.append("Subject fully inside the frame")
	return "   ·   ".join(bits)
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
	var hint := _requirement_text(job["objectives"][0]) if not job["objectives"].is_empty() else ""
	if hint != "":
		var hl := Label.new()
		hl.text = hint
		hl.add_theme_font_size_override("font_size", 12)
		hl.add_theme_color_override("font_color", Color(0.78, 0.62, 0.44))
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(hl)
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
		var hint := _requirement_text(o)
		if hint != "":
			var hl := Label.new()
			hl.text = hint
			hl.add_theme_font_size_override("font_size", 12)
			hl.add_theme_color_override("font_color", Color(0.78, 0.62, 0.44))
			hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(hl)
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
## Dev hook: pull a job for a failure state so the jobs page can be photographed.
func debug_fail(jid: String, mode: String) -> void:
	var job := _job(jid)
	if job.is_empty():
		return
	var o: Dictionary = job["objectives"][0]
	_fail_job(jid, mode, o)
	open_page()
## Dev hook: clear the pulled-job state after a screenshot.
func debug_clear_failures() -> void:
	_failed.clear()
	_fail_reason.clear()
	_misses.clear()
	_save_state()
	_refresh()
## Dev hook: put one job on the offer board so the requirement line can be photographed.
func debug_offer(jid: String) -> void:
	if jid in _offers or jid in _active or jid in _done or jid in _failed:
		pass
	else:
		_offers.append(jid)
		_save_state()
	_refresh()
	open_page()

## Dev hook: remove a debug offer again.
func debug_remove_offer(jid: String) -> void:
	_offers.erase(jid)
	_save_state()
	_refresh()
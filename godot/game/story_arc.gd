class_name StoryArc
extends Node
## The Lake Car, the first DroneBudz story arc (session B). Constable Rennick, new at the fictional Halloway detachment,
## joins the server over an abandoned blue estate on the north shore of the lake. The pilot photographs the evidence,
## the officer replies, and the case grows a chapter at a time.
##
## This first slice covers chapters 0 to 2: the car, the VIN and the old Voss garage. The later chapters (the camp, the
## bus and the festival reunion) are planned in docs/story/TOWN-ARC.md and will follow. The officer appears after the
## pilot has published their first clip or finished their first job. Nothing here is forced: the story waits, can be
## ignored, and honours the Story and jobs switch in the menu.
##
## All state is kept in user://story_lake_car.cfg. Evidence is ordinary camera roll photos whose case subject matches
## the request, so the same photo can also be uploaded or kept.

const SAVE := "user://story_lake_car.cfg"
const CHANNEL := "town"

const CHAPTERS := [
	{
		"id": "car", "title": "A favour", "from": "Rennick",
		"request": "There is an old blue estate on the north shore of the lake. No plates, nobody has claimed it. Could you get me two clear photographs of it and the ground around it, from the air, within eighty metres? Do not land.",
		"evidence": {"subject": "case_lake_car", "max_dist": 80.0, "count": 2, "text": "Photograph the abandoned car (2 angles)"},
		"reveal": "Thank you. No plates, and the boot will not open. There is a tow sticker on the back window, Voss and Son Motor Works. That garage closed before I moved here. Does the name mean anything to anyone?",
		"beats": [
			{"from": "Tom", "channel": "general", "text": "That car has been there since before the storm. I thought it was the ranger's."},
			{"from": "Riley", "channel": "general", "text": "It is not ours. And the reeds on that shore are nesting ground, so keep some height."},
			{"from": "Maya", "channel": "general", "text": "A car with no plates and a police officer asking nicely. That is a story, not a job."},
		],
		"next_hours": 3.0,
	},
	{
		"id": "vin", "title": "No plates", "from": "Rennick",
		"request": "The car is locked. I need the VIN plate under the windscreen or inside the driver's door, and the tow sticker if it is still there. A close pass within fifteen metres, a torch at night is fine, whatever gets the number.",
		"evidence": {"subject": "case_lake_car", "max_dist": 18.0, "count": 1, "text": "Close-up of the VIN or the tow sticker"},
		"reveal": "The VIN comes back to a 1987 blue estate, first registered to Ellis Voss. There is no missing person report and no crime report. He is not in trouble. I would just like to know he is all right.",
		"beats": [
			{"from": "Alex", "channel": "tech", "text": "1987 estate, if the shape is right. Someone looked after it once."},
			{"from": "Sam", "channel": "weather", "text": "Wind is light tonight. If you need the close pass, now is the window."},
			{"from": "Maya", "channel": "clips", "text": "So it is a person, not a car. Do we ask before we put this on the channel?"},
		],
		"next_hours": 3.0,
	},
	{
		"id": "garage", "title": "The garage", "from": "Rennick",
		"request": "One more favour. Voss and Son Motor Works is on the spur off the ridge road. Photograph the roller door, the workshop window and the yard. Do not go inside.",
		"evidence": {"subject": "case_garage", "max_dist": 90.0, "count": 2, "text": "Photograph the old garage and its yard"},
		"reveal": "Twenty years closed and there is fresh oil on that yard. Someone is working in there. I am going to knock on the door myself. Thank you for the eyes.",
		"beats": [
			{"from": "Jo", "channel": "general", "text": "Voss. The old garage. He built the first festival bus."},
			{"from": "Alex", "channel": "tech", "text": "That is a bus under that tarp. I would bet the barn on it."},
			{"from": "Riley", "channel": "general", "text": "The lot belongs to the town. If someone is working there, the gate being open is not a surprise."},
		],
		"next_hours": 0.0,
	},
]

var hud: Hud
var chat: ChatData
var jobs: Jobs
var notes: PhoneNotes
var photos: PhotoLibrary
var objects: CaseObjects

var started := false
var chapter := -1
var waiting := false
var _done := {}
var _evidence := {}         # chapter index -> Array of photo ids
var _abs_hours := 0.0
var _last_hour := 0.0
var _next_at := 0.0
var _start_notified := false

func setup(h: Hud, c: ChatData, j: Jobs, n: PhoneNotes, p: PhotoLibrary, o: CaseObjects) -> void:
	hud = h
	chat = c
	jobs = j
	notes = n
	photos = p
	objects = o
	_last_hour = float(hud.weather.get("hour", 12.0)) if hud != null else 12.0
	_load()

# ------------------------------------------------------------------ time and triggers
func update(delta: float) -> void:
	if hud == null:
		return
	var h := float(hud.weather.get("hour", 12.0))
	var d := h - _last_hour
	if d < -12.0:
		d += 24.0
	elif d > 12.0:
		d -= 24.0
	if d > 0.0:
		_abs_hours += d
	_last_hour = h
	if hud.story_on == false:
		return
	if not started:
		if jobs != null and (jobs.videos().size() > 0 or jobs._done.size() > 0):
			_start()
		return
	if waiting and _next_at > 0.0 and _abs_hours >= _next_at:
		waiting = false
		_begin(chapter + 1)

func _start() -> void:
	started = true
	_save()
	if chat != null:
		chat.post(CHANNEL, "Rennick", "Afternoon. I am Constable Rennick, new at the Halloway detachment. This is a favour, not a case yet. Is one of you the pilot with the drone?")
	_begin(0)
	if notes != null and not _start_notified:
		_start_notified = true
		notes.post_text("Rennick", "A favour", "The new constable at the Halloway detachment would like a word. Open DroneBudz and check #town.", 1)

func _begin(i: int) -> void:
	if i < 0 or i >= CHAPTERS.size():
		return
	chapter = i
	_evidence[i] = _evidence.get(i, [])
	_next_at = 0.0
	_save()
	var ch: Dictionary = CHAPTERS[i]
	if chat != null:
		chat.post(CHANNEL, "Rennick", str(ch["request"]))
	for b in ch.get("beats", []):
		if chat != null:
			chat.post(str(b.get("channel", "general")), str(b.get("from", "")), str(b.get("text", "")), false)
	if notes != null:
		notes.post_text("Rennick", "Casebook: " + str(ch["title"]), str(ch["request"]), 0)

func on_photo(photo_id: int, meta: Dictionary) -> void:
	if not started or chapter < 0 or chapter >= CHAPTERS.size() or bool(_done.get(chapter, false)):
		return
	var ch: Dictionary = CHAPTERS[chapter]
	var ev: Dictionary = ch["evidence"]
	var subject := str(ev.get("subject", ""))
	var max_d := float(ev.get("max_dist", 9999.0))
	var hit := false
	for s in meta.get("subjects", []):
		if str(s.get("id", "")) == subject and float(s.get("dist", 9999.0)) <= max_d:
			hit = true
			break
	if not hit:
		return
	var ids: Array = _evidence.get(chapter, [])
	if not photo_id in ids:
		ids.append(photo_id)
		_evidence[chapter] = ids
		_save()
	if ids.size() >= int(ev.get("count", 1)):
		_complete()

func _complete() -> void:
	if chapter < 0 or chapter >= CHAPTERS.size():
		return
	var ch: Dictionary = CHAPTERS[chapter]
	_done[chapter] = true
	if chat != null:
		chat.post(CHANNEL, "Rennick", str(ch["reveal"]))
		for b in ch.get("beats", []):
			chat.post(str(b.get("channel", "general")), str(b.get("from", "")), str(b.get("text", "")), false)
		if chapter + 1 < CHAPTERS.size():
			chat.post(CHANNEL, "Rennick", "I will come back to you when I have had a look. Thank you.")
		else:
			chat.post(CHANNEL, "Rennick", "That is everything for now. I have a garage to visit, and a name to check. The trail goes cold here until I know more.")
	if notes != null:
		var title := "Evidence received: " + str(ch["title"])
		var body := "Rennick has the photographs. Open the Casebook to see the file."
		if chapter + 1 >= CHAPTERS.size():
			body = "Rennick has what she needs for now. The next part of the case is still being written."
		notes.post_text("Rennick", title, body, 0)
	var nxt := float(ch.get("next_hours", 0.0))
	if chapter + 1 < CHAPTERS.size() and nxt > 0.0:
		waiting = true
		_next_at = _abs_hours + nxt
	elif chapter + 1 >= CHAPTERS.size():
		waiting = false
	_save()

# ------------------------------------------------------------------ what the Casebook shows
func chapter_entries() -> Array:
	var out: Array = []
	for i in CHAPTERS.size():
		var status := "locked"
		if bool(_done.get(i, false)):
			status = "done"
		elif i == chapter:
			status = "active"
		var ch: Dictionary = CHAPTERS[i]
		var ev: Dictionary = ch["evidence"]
		var ids: Array = _evidence.get(i, [])
		out.append({
			"index": i, "title": str(ch["title"]), "status": status,
			"request": str(ch.get("request", "")), "count": int(ev.get("count", 1)),
			"have": ids.size(), "photos": ids.duplicate(),
			"evidence_text": str(ev.get("text", "")),
		})
	return out

func current_status() -> String:
	if not started:
		return "No case yet. The officer will get in touch when something comes up."
	if chapter < 0:
		return "Waiting for Rennick."
	if bool(_done.get(chapter, false)) and chapter + 1 >= CHAPTERS.size():
		return "The trail is open. Rennick is checking the garage and the name. The next part of the case is still being written."
	if waiting:
		return "Evidence delivered. Rennick is looking into it and will be in touch."
	if chapter < CHAPTERS.size():
		return "Chapter " + str(chapter + 1) + ": " + str(CHAPTERS[chapter]["title"])
	return "The case is quiet for now."

func active_request() -> String:
	if not started or chapter < 0 or chapter >= CHAPTERS.size():
		return ""
	if bool(_done.get(chapter, false)):
		return ""
	return str(CHAPTERS[chapter]["request"])

func evidence_progress() -> Dictionary:
	if chapter < 0 or chapter >= CHAPTERS.size():
		return {}
	var ev: Dictionary = CHAPTERS[chapter]["evidence"]
	var ids: Array = _evidence.get(chapter, [])
	return {"text": str(ev.get("text", "")), "have": ids.size(), "count": int(ev.get("count", 1)), "photos": ids.duplicate()}

func item_pos(id: String) -> Vector3:
	return objects.item_pos(id) if objects != null else Vector3.ZERO

func story_off_hint() -> bool:
	return hud != null and hud.story_on == false

func chapter_count() -> int:
	return CHAPTERS.size()

# ------------------------------------------------------------------ persistence and dev hooks
func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("case", "started", started)
	cf.set_value("case", "chapter", chapter)
	cf.set_value("case", "waiting", waiting)
	cf.set_value("case", "done", _done)
	cf.set_value("case", "evidence", _evidence)
	cf.set_value("case", "abs_hours", _abs_hours)
	cf.set_value("case", "next_at", _next_at)
	cf.set_value("case", "notified", _start_notified)
	cf.save(SAVE)

func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE) != OK:
		return
	started = bool(cf.get_value("case", "started", false))
	chapter = int(cf.get_value("case", "chapter", -1))
	waiting = bool(cf.get_value("case", "waiting", false))
	_done = cf.get_value("case", "done", {})
	_evidence = cf.get_value("case", "evidence", {})
	_abs_hours = float(cf.get_value("case", "abs_hours", 0.0))
	_next_at = float(cf.get_value("case", "next_at", 0.0))
	_start_notified = bool(cf.get_value("case", "notified", false))

## Dev hooks for screenshots and tests. `storystart` begins the case, `storydeliver` marks the current evidence done
## without a flight, `storynext` forces the waiting chapter to begin.
func debug_start() -> void:
	if not started:
		_start()
	elif chapter < 0:
		_begin(0)

func debug_deliver() -> void:
	if not started:
		debug_start()
	if chapter < 0 or chapter >= CHAPTERS.size():
		return
	var ev: Dictionary = CHAPTERS[chapter]["evidence"]
	var ids: Array = _evidence.get(chapter, [])
	var count := int(ev.get("count", 1))
	while ids.size() < count:
		ids.append(-1)
	_evidence[chapter] = ids
	_save()
	_complete()

func debug_next() -> void:
	if not started:
		debug_start()
	if waiting:
		waiting = false
		_next_at = 0.0
		_begin(chapter + 1)

func stats() -> Dictionary:
	return {"started": started, "chapter": chapter, "waiting": waiting, "done": _done.keys(), "evidence": _evidence}

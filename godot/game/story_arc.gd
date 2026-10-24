class_name StoryArc
extends Node
## The Lake Car, the first DroneBudz story arc (session B). Constable Rennick, new at the fictional Halloway detachment,
## joins the server over an abandoned blue estate on the north shore of the lake. The pilot photographs the evidence,
## the officer replies, and the case grows a chapter at a time.
##
## Six chapters: the car, the VIN, the garage, the camp on the ridge, the festival bus, and the reunion at the festival.
## The officer appears after the pilot has published their first clip or finished their first job. Nothing here is
## forced: the story waits, can be ignored, and honours the Story and jobs switch in the menu.
##
## All state is kept in user://story_lake_car.cfg. Evidence is ordinary camera roll photos whose case subjects and
## distances match the request, so the same photo can also be uploaded or kept. The last chapter ends with a choice:
## publish the story with Maya's cut, or keep it private for the community.

const SAVE := "user://story_lake_car.cfg"
const CHANNEL := "town"

const CHAPTERS := [
	{
		"id": "car", "title": "A favour", "from": "Rennick",
		"request": "There is an old blue estate on the north shore of the lake. No plates, nobody has claimed it. Could you get me two clear photographs of it and the ground around it, from the air, within eighty metres? Do not land.",
		"evidence": [{"subject": "case_lake_car", "max_dist": 80.0, "count": 2, "text": "Photograph the abandoned car (2 angles)"}],
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
		"evidence": [{"subject": "case_lake_car", "max_dist": 18.0, "count": 1, "text": "Close-up of the VIN or the tow sticker"}],
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
		"evidence": [{"subject": "case_garage", "max_dist": 90.0, "count": 2, "text": "Photograph the old garage and its yard"}],
		"reveal": "Twenty years closed and there is fresh oil on that yard. Someone is working in there. Riley is going to knock on the door for me. Thank you for the eyes.",
		"beats": [
			{"from": "Jo", "channel": "general", "text": "Voss. The old garage. He built the first festival bus."},
			{"from": "Alex", "channel": "tech", "text": "That is a bus under that tarp. I would bet the barn on it."},
			{"from": "Riley", "channel": "general", "text": "The lot belongs to the town. If someone is working there, the gate being open is not a surprise."},
		],
		"next_hours": 3.0,
	},
	{
		"id": "camp", "title": "Lights on the ridge", "from": "Rennick",
		"request": "Tom saw a light near the railway last night. There is a camp in the trees on the ridge. I need photographs of it from a respectful distance, at least twenty five metres away, no close pass and no people. If someone is living rough, I want to know he is safe, not move him on.",
		"evidence": [{"subject": "case_camp", "max_dist": 160.0, "min_dist": 25.0, "count": 2, "text": "Photograph the camp from a respectful distance"}],
		"reveal": "A tent, a tarp, a stove and a dog. There is a festival programme on the camp table. Riley is going up there tomorrow morning. Do not publish these, please. This is a welfare check, not a story yet.",
		"beats": [
			{"from": "Sam", "channel": "weather", "text": "It is going to be a cold night up on the ridge. If he is out there, I hope he has a proper sleeping bag."},
			{"from": "Tom", "channel": "general", "text": "I saw the light around midnight. I thought it was the railway signal."},
			{"from": "Riley", "channel": "general", "text": "The rangers will leave the camp alone. Nobody is going to move him on from our side."},
		],
		"next_hours": 3.0,
	},
	{
		"id": "bus", "title": "The man who fixed things", "from": "Rennick",
		"request": "Riley has spoken to him. His name is Ellis Voss and he is fine, though he does not want a fuss. He has agreed to photographs of the bus only, not of him. The garage door is open, the old festival bus is in the yard. Two photographs, and one close enough to read the lettering on its side.",
		"evidence": [
			{"subject": "case_bus", "max_dist": 80.0, "count": 2, "text": "Photograph the old festival bus and the yard"},
			{"subject": "case_bus", "max_dist": 22.0, "count": 1, "text": "Close detail of the festival lettering"},
		],
		"reveal": "That is the bus he built for the first festival, twenty two years ago. He has been restoring it in secret since the spring. The blue estate was his project car. He left it at the lake when he left town and never reported it. There is no case here. There is a man who needs a hand with a bus.",
		"beats": [
			{"from": "Jo", "channel": "general", "text": "If he gets that bus running, the festival committee will find it a place in the parade. I can ask."},
			{"from": "Alex", "channel": "tech", "text": "A bus that has sat for twenty years will need a battery, fuel lines and a lot of patience. I can bring tools."},
			{"from": "Maya", "channel": "clips", "text": "If he says yes, this is the best story the channel has ever had. If he says no, we leave it."},
		],
		"next_hours": 3.0,
	},
	{
		"id": "festival", "title": "The festival", "from": "Rennick",
		"request": "The festival committee has given him the parade slot. The bus is at the festival field now, waiting for its first run in twenty two years. Get me two photographs of it there, from the air. This one can be published if Ellis agrees, and I think he will.",
		"evidence": [{"subject": "case_bus", "max_dist": 220.0, "count": 2, "text": "Photograph the festival bus at the festival field"}],
		"reveal": "He made it. The bus ran the whole parade route with the band on board and the festival committee in tears. He asked me to thank you properly, and he gave me the original festival programme for the archive. The file is closed, and the detachment owes you a favour.",
		"beats": [
			{"from": "Jo", "channel": "general", "text": "The bus led the parade. The committee has already asked about next year."},
			{"from": "Alex", "channel": "tech", "text": "It sounded terrible and it ran perfectly. That is the best kind of old bus."},
			{"from": "Maya", "channel": "clips", "text": "Tell me what you want to do with the footage. A cut, a short, or we keep it for the people who were there."},
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
var choice := ""                 # "", "published", "private" after the last chapter
var completed := false           # the end card has played and the whole story is finished
var last_result := {}
var _done := {}
var _evidence := {}              # chapter -> {requirement index (String) -> Array of photo ids}
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
	if started and chapter >= _last_index() and objects != null:
		objects.move_bus_to_festival()

func _last_index() -> int:
	return CHAPTERS.size() - 1

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
		notes.post_text("Rennick", "A favour", "I am new at the Halloway detachment. This is a favour, not a case yet. I have put a note in #town.", 1)

func _begin(i: int) -> void:
	if i < 0 or i >= CHAPTERS.size():
		return
	chapter = i
	_evidence[i] = _evidence.get(i, {})
	_next_at = 0.0
	_save()
	var ch: Dictionary = CHAPTERS[i]
	if i == _last_index() and objects != null:
		objects.move_bus_to_festival()
	if chat != null:
		chat.post(CHANNEL, "Rennick", str(ch["request"]))
	if notes != null:
		notes.post_text("Rennick", "Casebook: " + str(ch["title"]), str(ch["request"]), 0)
	_save()

func on_photo(photo_id: int, meta: Dictionary) -> void:
	if not started or chapter < 0 or chapter >= CHAPTERS.size() or bool(_done.get(chapter, false)):
		return
	var reqs: Array = CHAPTERS[chapter]["evidence"]
	var ev: Dictionary = _evidence.get(chapter, {})
	for ri in reqs.size():
		var req: Dictionary = reqs[ri]
		var subject := str(req.get("subject", ""))
		var max_d := float(req.get("max_dist", 9999.0))
		var min_d := float(req.get("min_dist", 0.0))
		var hit := false
		for s in meta.get("subjects", []):
			if str(s.get("id", "")) != subject:
				continue
			var d := float(s.get("dist", 9999.0))
			if d <= max_d and d >= min_d:
				hit = true
				break
		if not hit:
			continue
		var key := str(ri)
		var ids: Array = ev.get(key, [])
		if not photo_id in ids:
			ids.append(photo_id)
			ev[key] = ids
			_evidence[chapter] = ev
			_save()
	# complete when every requirement has enough photographs
	var all := true
	for ri in reqs.size():
		var req: Dictionary = reqs[ri]
		var ids: Array = _evidence.get(chapter, {}).get(str(ri), [])
		if ids.size() < int(req.get("count", 1)):
			all = false
			break
	if all:
		_complete()

func _complete() -> void:
	if chapter < 0 or chapter >= CHAPTERS.size() or bool(_done.get(chapter, false)):
		return
	var ch: Dictionary = CHAPTERS[chapter]
	_done[chapter] = true
	if chat != null:
		chat.post(CHANNEL, "Rennick", str(ch["reveal"]))
		for b in ch.get("beats", []):
			chat.post(str(b.get("channel", "general")), str(b.get("from", "")), str(b.get("text", "")), false)
		if chapter < _last_index():
			chat.post(CHANNEL, "Rennick", "I will come back to you when I have had a look. Thank you.")
	if notes != null:
		var title := "Evidence received: " + str(ch["title"])
		var body := "I have the photographs. The file is in the Casebook."
		if chapter >= _last_index():
			body = "The case is ready to close. The file is in the Casebook when you are ready to decide what happens to the story."
		notes.post_text("Rennick", title, body, 0)
	var nxt := float(ch.get("next_hours", 0.0))
	if chapter < _last_index():
		waiting = true
		_next_at = _abs_hours + nxt
	else:
		waiting = false
		choice = ""
	_save()

# ------------------------------------------------------------------ the ending choice
func has_choice() -> bool:
	return started and chapter >= _last_index() and bool(_done.get(chapter, false)) and choice == ""

func make_choice(kind: String) -> void:
	if not has_choice():
		return
	if kind == "publish":
		var pid := _first_photo(chapter)
		var meta: Dictionary = {}
		if photos != null and pid >= 0:
			meta = photos.meta_for(pid)
		var rec: Dictionary = {}
		if jobs != null:
			rec = jobs.upload_photo(pid, meta, true)
			jobs.add_money(120)
		last_result = rec
		choice = "published"
		_save()
		if chat != null:
			_chat_case("Rennick", "Then it is public. Thank you. The detachment still owes you a favour, and Ellis has asked for a copy of the programme photo.")
			chat.post("clips", "Maya", "The cut is up. %d views and counting. This one feels different from the other jobs." % int(rec.get("views", 0)), false)
		if notes != null:
			notes.post_text("Rennick", "Case closed: published", "The Lake Car story is out with Maya's cut. The community fund has sent a fuel payment.", 0)
	elif kind == "private":
		choice = "private"
		if jobs != null:
			jobs.add_money(240)
		_save()
		if chat != null:
			_chat_case("Rennick", "Then it stays between us, the crew and the people who were there. The detachment has sent a fuel payment. Thank you for doing this the careful way.")
			chat.post("clips", "Maya", "We keep this one for the people who were there. It was the right call.", false)
		if notes != null:
			notes.post_text("Rennick", "Case closed: kept private", "The story stays with the crew. A fuel payment has gone into the channel pot.", 0)

func _chat_case(from: String, text: String) -> void:
	chat.post(CHANNEL, from, text, false)

func _first_photo(i: int) -> int:
	var reqs: Array = CHAPTERS[i]["evidence"]
	for ri in reqs.size():
		var ids: Array = _evidence.get(i, {}).get(str(ri), [])
		for pid in ids:
			if int(pid) >= 0:
				return int(pid)
	return -1

func case_closed() -> bool:
	return choice != ""

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
		var reqs: Array = ch["evidence"]
		var req_views: Array = []
		var total_have := 0
		var total_count := 0
		for ri in reqs.size():
			var req: Dictionary = reqs[ri]
			var ids: Array = _evidence.get(i, {}).get(str(ri), [])
			total_have += ids.size()
			total_count += int(req.get("count", 1))
			req_views.append({"text": str(req.get("text", "")), "have": ids.size(), "count": int(req.get("count", 1)), "photos": ids.duplicate()})
		out.append({
			"index": i, "title": str(ch["title"]), "status": status,
			"request": str(ch.get("request", "")), "requirements": req_views,
			"have": total_have, "count": total_count,
		})
	return out

## A single count across every chapter, for the Casebook when the file is closed or ready to close.
func evidence_totals() -> Dictionary:
	var have := 0
	var count := 0
	for i in CHAPTERS.size():
		var reqs: Array = CHAPTERS[i]["evidence"]
		for ri in reqs.size():
			var req: Dictionary = reqs[ri]
			have += _evidence.get(i, {}).get(str(ri), []).size()
			count += int(req.get("count", 1))
	return {"have": have, "count": count}

func current_status() -> String:
	if not started:
		return "No case yet. The officer will get in touch when something comes up."
	if chapter < 0:
		return "Waiting for Rennick."
	if has_choice():
		return "Case ready to close. Decide what happens to the story."
	if case_closed():
		return "Case closed. Rennick has the file and the festival has its bus."
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

func evidence_progress() -> Array:
	var out: Array = []
	if chapter < 0 or chapter >= CHAPTERS.size():
		return out
	var reqs: Array = CHAPTERS[chapter]["evidence"]
	for ri in reqs.size():
		var req: Dictionary = reqs[ri]
		var ids: Array = _evidence.get(chapter, {}).get(str(ri), [])
		out.append({"text": str(req.get("text", "")), "have": ids.size(), "count": int(req.get("count", 1)), "photos": ids.duplicate()})
	return out

func item_pos(id: String) -> Vector3:
	return objects.item_pos(id) if objects != null else Vector3.ZERO

## The end card has been seen. The story is complete and the valley is simply the sandbox again.
func mark_completed() -> void:
	completed = true
	_save()

func is_completed() -> bool:
	return completed

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
	cf.set_value("case", "choice", choice)
	cf.set_value("case", "abs_hours", _abs_hours)
	cf.set_value("case", "next_at", _next_at)
	cf.set_value("case", "notified", _start_notified)
	cf.set_value("case", "completed", completed)
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
	choice = str(cf.get_value("case", "choice", ""))
	_abs_hours = float(cf.get_value("case", "abs_hours", 0.0))
	_next_at = float(cf.get_value("case", "next_at", 0.0))
	_start_notified = bool(cf.get_value("case", "notified", false))
	completed = bool(cf.get_value("case", "completed", false))
	# older saves stored a flat Array of photo ids for a chapter; lift it into requirement 0
	for k in _evidence.keys():
		if _evidence[k] is Array:
			_evidence[k] = {"0": _evidence[k]}

## Dev hooks for screenshots and tests.
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
	var reqs: Array = CHAPTERS[chapter]["evidence"]
	var ev: Dictionary = _evidence.get(chapter, {})
	for ri in reqs.size():
		var req: Dictionary = reqs[ri]
		var ids: Array = ev.get(str(ri), [])
		while ids.size() < int(req.get("count", 1)):
			ids.append(-1)
		ev[str(ri)] = ids
	_evidence[chapter] = ev
	_save()
	_complete()

func debug_next() -> void:
	if not started:
		debug_start()
	if waiting:
		waiting = false
		_next_at = 0.0
		_begin(chapter + 1)

## Jump straight to a chapter with all earlier chapters done, for the look shots.
func debug_jump(i: int) -> void:
	if not started:
		started = true
	for k in range(i):
		_done[k] = true
	chapter = i
	_evidence[i] = {}
	waiting = false
	_next_at = 0.0
	_begin(i)

func debug_run_all() -> void:
	debug_start()
	for i in CHAPTERS.size():
		if chapter != i:
			debug_jump(i)
		debug_deliver()
	if chapter == _last_index() and not _done.get(chapter, false):
		debug_deliver()

func debug_choose(kind: String) -> void:
	make_choice(kind)

func stats() -> Dictionary:
	return {"started": started, "chapter": chapter, "waiting": waiting, "done": _done.keys(), "choice": choice, "evidence": _evidence}

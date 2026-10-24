class_name GuideCoach
extends Node
## Kit, the DroneBudz support contact (session B UI pass 2): a quiet guide who sends contextual tips in a direct
## message, and only in story mode. The tips cover the tablet, apps, controls, the Casebook, jobs, buying the thermal
## camera and travelling to the last launch site. A tip that needs an action gets one gentle follow-up if the player has
## not done it, then Kit leaves them alone.
##
## Nothing here pauses, scores, fails or gates the game. It only posts messages and notifications.

const SAVE := "user://guide_tips.cfg"
const VERSION := 3
const CTRL := "#E0AB59"     # amber: keys and physical controls
const APP := "#74A87A"      # moss: apps and channels
const UI := "#5C959F"       # lake: a place inside an app

var hud: Hud
var chat: ChatData
var notes: PhoneNotes
var phone_os: PhoneOS
var story: StoryArc
var director: StoryDirector
var wildlife: WildlifeCase
var inventory: Inventory
var photos: PhotoLibrary
var jobs: Jobs
var finale: Finale
var _sent := {}
var _t := 0.0
var _welcome_at := -1.0
var _phone_at := -1.0
var _chat_at := -1.0
var _channel_at := -1.0
var _last_tip_at := -99.0
var _seen_act := -1
var _seen_story := false
var _seen_jobs := false
var _seen_wildlife := false
var _seen_photo := false
var _seen_closed := false
var _seen_choice := false
var _phone_seen := false
var _chat_seen := false
var _other_channel_seen := false

func setup(h: Hud, c: ChatData, n: PhoneNotes, p: PhoneOS, s: StoryArc, d: StoryDirector, w: WildlifeCase,
		inv: Inventory, ph: PhotoLibrary, j: Jobs, f: Finale = null) -> void:
	hud = h
	chat = c
	notes = n
	phone_os = p
	story = s
	director = d
	wildlife = w
	inventory = inv
	photos = ph
	jobs = j
	finale = f
	_load()
	set_process(true)

func update(delta: float) -> void:
	if hud == null or not hud.story_mode or chat == null:
		return
	_t += delta
	_watch()
	if story == null or story.story_off_hint():
		return
	# Do not fire the first tip until the case actually begins.
	if not _sent.has("welcome") and story.started and _t > 4.0:
		_welcome_at = _t
		_send("welcome", "A quick word before you fly",
			"Hi, I'm Kit from DroneBudz support. I keep an eye on new pilots in the valley.\n\n" +
			"Press [color=%s]Tab[/color] to open the tablet. From the home screen tap [color=%s]DroneBudz[/color], then choose a channel on the left. " % [CTRL, APP] +
			"[color=%s]Casebook[/color] keeps the file, [color=%s]Jobs[/color] pays, [color=%s]Facade[/color] sells gear. " % [APP, APP, APP] +
			"If you get lost, the bottom bar always has [color=%s]Home[/color]." % UI)
		_phone_at = _t
	# Follow-up: the tablet was not opened.
	if _sent.has("welcome") and not _phone_seen and not _sent.has("home_help") and _t > _welcome_at + 18.0:
		_send("home_help", "Getting back to the home screen",
			"Still not seeing the server? Press [color=%s]Tab[/color] to open the tablet. If an app is in front, tap [color=%s]Home[/color] on the bottom bar. " % [CTRL, UI] +
			"Then tap [color=%s]DroneBudz[/color] and pick a channel on the left. I'll wait." % APP)
	# Follow-up: the phone was opened but chat was not.
	if _phone_seen and not _chat_seen and not _sent.has("chat_help") and _t > _phone_at + 20.0:
		_send("chat_help", "The DroneBudz app",
			"[color=%s]DroneBudz[/color] is the green app on the home screen. Open it, then tap [color=%s]#town[/color] or [color=%s]#clips[/color] in the left column. " % [APP, APP, APP] +
			"The story and job talk live there.")
	# Follow-up: only #general was read.
	if _chat_seen and not _other_channel_seen and not _sent.has("channel_help") and _t > _chat_at + 24.0:
		_send("channel_help", "A few channels worth reading",
			"Try the other channels in DroneBudz: [color=%s]#town[/color] for valley notices, [color=%s]#clips[/color] for the channel plan and [color=%s]#jobs[/color] for paid work. " % [APP, APP, APP] +
			"The case starts in #town.")
	# The first useful story beat: the Casebook.
	if director != null and director.act_number() != _seen_act:
		_seen_act = director.act_number()
		if _seen_act >= 1 and not _sent.has("casebook_help"):
			_send("casebook_help", "The file on your tablet",
				"[color=%s]Casebook[/color] holds Rennick's file. [color=%s]Overview[/color] shows what she needs next; [color=%s]Evidence[/color] shows the photographs you have filed." % [APP, UI, UI])
		if _seen_act >= 2 and not _sent.has("evidence_help"):
			_send("evidence_help", "A clean shot for the file",
				"Keep the subject inside the frame and read the request before the shutter. A photo only files itself if it matches what [color=%s]Casebook[/color] is asking for." % APP)
	# Jobs are on the board.
	if jobs != null and not jobs.offers_list().is_empty() and not _seen_jobs:
		_seen_jobs = true
		_send("jobs_help", "There is paid work on the board",
			"Paid work is in [color=%s]Jobs[/color]. Accept a job, read its requirement line, take the photograph and then publish. " % APP +
			"If you get too close to the subject, the client can pull the job. Keep the distance it asks for.")
	# The thermal camera is the next piece of gear the story needs.
	if wildlife != null and wildlife.started and inventory != null and not inventory.has_addon("thermal_camera") and not _sent.has("thermal_help"):
		_send("thermal_help", "The thermal camera on Facade",
			"The last flight needs a [color=%s]thermal camera[/color]. Open [color=%s]Facade[/color], choose [color=%s]Cameras[/color], buy the module with the channel pot, " % [UI, APP, UI] +
			"then open [color=%s]Your kit[/color] and fit it. If the pot is short, [color=%s]Jobs[/color] pays." % [APP, APP])
	# The last flight is a drive, not a teleport.
	if story.case_closed() and not _seen_closed:
		_seen_closed = true
		_send("map_help", "The last flight starts north",
			"For the last flight, open [color=%s]Map[/color]. Pick [color=%s]Ridge trailhead[/color] or [color=%s]North gate pull-off[/color] and press [color=%s]Drive here[/color]. " % [APP, UI, UI, CTRL] +
			"Land first; the kit cannot travel in the air.")
	# The ending choice is in the file.
	if story.has_choice() and not _seen_choice:
		_seen_choice = true
		_send("choice_help", "The file is ready to close",
			"Open [color=%s]Casebook[/color] and look at the [color=%s]Overview[/color] tab. The closing choice is in the file; either path is yours to take." % [APP, UI])
	# A first photograph has been taken.
	if photos != null and photos.count() > 0 and not _seen_photo:
		_seen_photo = true
		_send("photo_help", "The first frame is in the roll",
			"Nice. The shutter is the round button on the right; the [color=%s]Photos[/color] app keeps every frame. " % APP +
			"Completed jobs and published clips pay from the channel pot.")
	# The controls, once the pilot has the tablet open and the drone is airborne.
	if _phone_seen and not _sent.has("flight_help") and _t > _welcome_at + 30.0:
		_send("flight_help", "The flight controls",
			"[color=%s]Takeoff[/color] and [color=%s]Land[/color] are the left buttons. [color=%s]Return[/color] brings the drone home. " % [CTRL, CTRL, CTRL] +
			"[color=%s]Esc[/color] opens the pause menu; [color=%s]Tab[/color] opens the tablet. The round shutter on the right takes a photo. " % [CTRL, CTRL] +
			"Move with [color=%s]W A S D[/color] and the arrow keys, or use the touch sticks.")

func _watch() -> void:
	if phone_os == null:
		return
	if phone_os._open:
		if not _phone_seen:
			_phone_seen = true
			_phone_at = _t
		if phone_os._current_app == "chat":
			if not _chat_seen:
				_chat_seen = true
				_chat_at = _t
			if chat != null and chat.current_channel() != "general":
				_other_channel_seen = true

func _send(id: String, title: String, body: String) -> void:
	if _sent.has(id) or _t - _last_tip_at < 8.0:
		return
	_sent[id] = true
	_last_tip_at = _t
	if chat != null:
		var already := false
		for m in chat.messages("guide", false):
			if str(m.get("text", "")) == body:
				already = true
				break
		if not already:
			chat.post("guide", "Kit", body, false, false, -1, true)
	if notes != null:
		notes.post_text("Kit", title, _plain(body), 0)
	_save()

func _plain(body: String) -> String:
	var re := RegEx.new()
	re.compile("\\[(?:/?)color[^\\]]*\\]")
	return re.sub(body, "", true)

func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE) == OK:
		# a version bump clears the test/legacy sent list without touching the player data
		if int(cf.get_value("meta", "version", 0)) < VERSION:
			_sent.clear()
			return
		for k in cf.get_section_keys("sent"):
			_sent[str(k)] = true

func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("meta", "version", VERSION)
	for k in _sent:
		cf.set_value("sent", str(k), true)
	cf.save(SAVE)

func stats() -> Dictionary:
	return {"sent": _sent.size(), "phone_seen": _phone_seen, "chat_seen": _chat_seen}

## Dev hook for UI screenshots and review: force one tip and open the Kit DM.
func debug_tip(id: String) -> void:
	var texts := {
		"welcome": ["A quick word before you fly", "Hi, I'm Kit from DroneBudz support. Press [color=%s]Tab[/color] to open the tablet, then open [color=%s]DroneBudz[/color] and pick a channel on the left. The bottom bar always has [color=%s]Home[/color]." % [CTRL, APP, UI]],
		"home_help": ["Getting back to the home screen", "Press [color=%s]Tab[/color], tap [color=%s]Home[/color] on the bottom bar, then open [color=%s]DroneBudz[/color]." % [CTRL, UI, APP]],
		"chat_help": ["The DroneBudz app", "Open [color=%s]DroneBudz[/color] and tap [color=%s]#town[/color] on the left. The story and job talk live there." % [APP, APP]],
		"thermal_help": ["The thermal camera on Facade", "Open [color=%s]Facade[/color], choose [color=%s]Cameras[/color], buy the thermal module, then fit it in [color=%s]Your kit[/color]." % [APP, UI, APP]],
		"map_help": ["The last flight starts north", "Open [color=%s]Map[/color], pick [color=%s]Ridge trailhead[/color] and press [color=%s]Drive here[/color]. Land first." % [APP, UI, CTRL]],
	}
	var pair: Array = texts.get(id, ["A word from Kit", "I'm here if you need a hand with the tablet."])
	_sent.erase(id)
	_t = 100.0
	_last_tip_at = -99.0
	_send(id, str(pair[0]), str(pair[1]))

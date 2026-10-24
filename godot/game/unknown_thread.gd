class_name UnknownThread
extends Node
## The unknown account that messages the pilot in DroneBudz (session B).
##
## A direct message thread that starts as a wrong number, turns into friendly questions, then quietly shows that the
## sender knows more about the Lake Car investigation than a stranger should, and finally starts asking questions about
## Constable Rennick herself. The player can answer or leave it. The thread never threatens and never gives a clean
## answer about who is on the other end. It is the spooky, ambiguous counterweight to the warm police story.
##
## The channel is hidden in the chat until the first message arrives. Beats are paced by in game hours and by how far
## the Lake Car story has progressed, so the unknown does not know about the camp before the pilot has found it. State is
## saved in user://unknown_thread.cfg.

const SAVE := "user://unknown_thread.cfg"
const CHANNEL := "unknown"

const MESSAGES := [
	[
		"hey. is this alex? the one with the drone?",
		"sorry, wrong number. or wrong pilot. i'm looking for the person who flies over the lake.",
	],
	[
		"ok. so you are the pilot.",
		"i grew up out past the ridge. the valley hasn't changed as much as i thought.",
		"your videos make it look like the festival never stopped.",
	],
	[
		"what else does the crew have you flying for?",
		"the police are asking about the old car, aren't they. the blue one.",
		"you don't have to answer. i'm just working out who else is looking.",
	],
	[
		"they found the tow sticker, didn't they. and someone has been camping up by the railway.",
		"the constable doesn't tell you everything. ask her about the file. ask her about 1974.",
		"she is new here. but she knew the garage before she knew the town.",
	],
	[
		"why do you think she came here? first week, and she asks a stranger with a drone to photograph a car.",
		"did she tell you who called it in? or what she is really looking for?",
		"be careful what you send her. some people collect favours.",
	],
	[
		"i'm not the one you should be worried about.",
		"the cabin past the north shore. i can see the lights in the storm. please come.",
	],
]
const PUBLISHED_LAST := [
	"you put it on the channel. i hope ellis was ready for that.",
	"the cabin past the north shore. i can see the lights in the storm. please come.",
]
const MIN_CHAPTER := [0, 1, 2, 3, 5, 5]
const DELAY_HOURS := [2.0, 3.0, 3.0, 4.0, 5.0, 0.0]

var chat: ChatData
var notes: PhoneNotes
var hud: Hud
var story: StoryArc

var beat := -1
var _abs_hours := 0.0
var _last_hour := 0.0
var _next_at := 0.0

func setup(c: ChatData, n: PhoneNotes, h: Hud, s: StoryArc) -> void:
	chat = c
	notes = n
	hud = h
	story = s
	_last_hour = float(hud.weather.get("hour", 12.0)) if hud != null else 12.0
	_load()

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
	if hud.story_on == false or story == null or not story.started:
		return
	if beat < 0:
		_post(0)
		return
	if beat >= MESSAGES.size() - 1:
		return
	if _abs_hours < _next_at:
		return
	var n := beat + 1
	if story.chapter < int(MIN_CHAPTER[n]):
		return
	if n == MESSAGES.size() - 1 and not story.case_closed():
		return
	_post(n)

func _post(i: int) -> void:
	if i < 0 or i >= MESSAGES.size():
		return
	beat = i
	var lines: Array = MESSAGES[i]
	if i == MESSAGES.size() - 1 and story != null and story.choice == "published":
		lines = PUBLISHED_LAST
	for line in lines:
		chat.post(CHANNEL, "Unknown", str(line))
	if notes != null:
		notes.post_text("Unknown", "Direct message", str(lines[0]), 0 if i < 3 else 1)
	if i + 1 < MESSAGES.size():
		_next_at = _abs_hours + float(DELAY_HOURS[i])
	_save()

# ------------------------------------------------------------------ persistence and dev hooks
func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("unknown", "beat", beat)
	cf.set_value("unknown", "abs_hours", _abs_hours)
	cf.set_value("unknown", "next_at", _next_at)
	cf.save(SAVE)

func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE) != OK:
		return
	beat = int(cf.get_value("unknown", "beat", -1))
	_abs_hours = float(cf.get_value("unknown", "abs_hours", 0.0))
	_next_at = float(cf.get_value("unknown", "next_at", 0.0))

func debug_start() -> void:
	if story != null and not story.started:
		story.debug_start()
	if beat < 0:
		_post(0)

func debug_next() -> void:
	if beat < 0:
		debug_start()
		return
	_post(mini(beat + 1, MESSAGES.size() - 1))

func debug_jump(i: int) -> void:
	if story != null and not story.started:
		story.debug_start()
	_post(clampi(i, 0, MESSAGES.size() - 1))

func stats() -> Dictionary:
	return {"beat": beat, "next_at": snappedf(_next_at, 0.1)}

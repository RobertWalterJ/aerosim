class_name ChatData
extends RefCounted
## The DroneBudz Discord-style server (session B): channels, the crew's messages and the player's own posts.
##
## The crew are friends running a small drone YouTube channel together: Maya runs the channel and edits, Alex reviews
## the tech, Tom chases storms, Sam does the forecasting, Riley gets the park work and Jo books the festival. The seeds
## below set the story up in their own voices; jobs, photo results and payouts are posted into #jobs as events, and the
## player can type into any channel. Unread counts drive the home-screen badge. Everything the player and the crew say
## persists in user://chat.json; the opening seeds are rebuilt on load.

const SAVE := "user://chat.json"
const CHANNELS := [
	{"id": "general", "name": "general", "topic": "Say hi, plan the week, post the odd meme"},
	{"id": "town", "name": "town", "topic": "Halloway notices, the festival, and the odd favour"},
	{"id": "weather", "name": "weather", "topic": "Forecasts, storms and chase plans"},
	{"id": "clips", "name": "clips", "topic": "The channel: what we still need for the edit"},
	{"id": "tech", "name": "tech", "topic": "Gear, drones and honest reviews"},
	{"id": "jobs", "name": "jobs", "topic": "Paid work for the channel"},
]
const CAST := {
	"Maya": {"role": "editor and channel owner", "colour": Color(0.78, 0.38, 0.50)},
	"Alex": {"role": "tech reviewer", "colour": Color(0.68, 0.52, 0.24)},
	"Tom": {"role": "storm chaser", "colour": Color(0.30, 0.48, 0.74)},
	"Sam": {"role": "meteorologist", "colour": Color(0.24, 0.56, 0.52)},
	"Riley": {"role": "park ranger", "colour": Color(0.72, 0.33, 0.26)},
	"Jo": {"role": "events and bookings", "colour": Color(0.47, 0.35, 0.72)},
	"Rennick": {"role": "Provincial Police, Halloway", "colour": Color(0.36, 0.46, 0.60)},
	"You": {"role": "pilot", "colour": Color(0.30, 0.65, 0.45)},
}

var _dyn := {}          # channel -> Array of messages (the player's and event messages)
var _unread := {}       # channel -> int
var _current := "general"

func _init() -> void:
	_load()

func channels() -> Array:
	return CHANNELS

func channel_info(id: String) -> Dictionary:
	for c in CHANNELS:
		if str(c["id"]) == id:
			return c
	return {}

func messages(channel: String, mark_read := true) -> Array:
	var out: Array = _seed_for(channel)
	for m in _dyn.get(channel, []):
		out.append(m)
	if mark_read:
		_unread[channel] = 0
		_current = channel
		_save()
	return out

func post(channel: String, from: String, text: String, system := false, mine := false, photo := -1) -> void:
	if not _dyn.has(channel):
		_dyn[channel] = []
	_dyn[channel].append({"from": from, "text": text, "time": _now_label(), "system": system, "mine": mine, "photo": photo})
	if channel != _current and not mine:
		_unread[channel] = int(_unread.get(channel, 0)) + 1
	_save()

func unread(channel: String) -> int:
	return int(_unread.get(channel, 0))

func unread_total() -> int:
	var n := 0
	for c in CHANNELS:
		n += int(_unread.get(str(c["id"]), 0))
	return n

func cast_colour(name: String) -> Color:
	var c: Dictionary = CAST.get(name, {})
	return c.get("colour", Color(0.5, 0.5, 0.5))

func cast_role(name: String) -> String:
	var c: Dictionary = CAST.get(name, {})
	return str(c.get("role", "crew"))

# ------------------------------------------------------------------ the opening story
func _seed_for(channel: String) -> Array:
	match channel:
		"general":
			return [
				_msg("Maya", "Right, the server is up. Welcome to DroneBudz. Channel is at 120 followers, which is 120 more than last month."),
				_msg("Alex", "New props arrived, going to test them this afternoon. If they hold up I will do the review video."),
				_msg("Tom", "Storm week is coming. I can feel it. Keep the fast drone charged."),
				_msg("Jo", "Festival dates are confirmed. Fireworks on the Saturday, we have press access for the channel."),
				_msg("Sam", "I will post forecasts in #weather. Nothing dramatic for two days, then it turns."),
				_msg("Riley", "The park trust asked about footage of the chapel. I said we know a pilot."),
				_msg("Jo", "The new road out to the farm is open. Makes the festival run a lot easier, and there is a good hard shoulder for the chase car."),
				_msg("Riley", "Ridge road is open again too. If you follow it low there are some new angles of the valley from the old hedge line."),
				_msg("Maya", "That is you by the way. Check #jobs when you land, there is paid work on the board."),
			]
		"weather":
			return [
				_msg("Sam", "Forecast for today: light wind from the west, good visibility, no rain until late."),
				_msg("Tom", "If the cells build on Thursday I am going out to the west meadow with the long lens."),
				_msg("Sam", "Thursday has the best instability of the week. If you want a storm shot, that is the day."),
				_msg("Jo", "And if it storms on Saturday the fireworks will be a nightmare to film. Fingers crossed."),
			]
		"clips":
			return [
				_msg("Maya", "This week's video needs three things: the lake at golden hour, the chapel for the heritage bit, and one good firework burst for the thumbnail."),
				_msg("Maya", "If you get them, I can cut the whole thing in an evening and we might actually grow this channel."),
				_msg("Riley", "The farm trust wants a harvest postcard too. The corn and hay are in the fields past the farm now, so there is something worth pointing a camera at."),
				_msg("Alex", "I will do the gear section. New props, the cinema drone, and that cheap action cam nobody trusts."),
				_msg("Tom", "And if the weather turns I want a storm segment. Real weather, not stock footage."),
			]
		"tech":
			return [
				_msg("Alex", "First impressions of the new props: smoother at low throttle, but they sing a bit at full punch."),
				_msg("Alex", "Cinema drone is the best camera platform we have, but it is not fast enough for a storm."),
				_msg("Tom", "The racing quad is the only thing that can keep up with a gust front."),
				_msg("Maya", "Reviews do well. People like the honest ones where something is rubbish."),
			]
		"jobs":
			return [
				_msg("Maya", "Paid jobs go here. Take one from the jobs board in the menu, get the shot, submit it, and the channel pays the pilot."),
				_msg("Maya", "Money pays for gear and travel. Followers are what gets us the next job. We need both."),
			]
	return []

func _msg(from: String, text: String) -> Dictionary:
	return {"from": from, "text": text, "time": "", "system": false, "mine": false}

func _now_label() -> String:
	var t := Time.get_time_dict_from_system()
	return "%02d:%02d" % [int(t.get("hour", 0)), int(t.get("minute", 0))]

# ------------------------------------------------------------------ persistence
func _save() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"dyn": _dyn, "unread": _unread, "current": _current}))

func _load() -> void:
	if not FileAccess.file_exists(SAVE):
		return
	var f := FileAccess.open(SAVE, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		var d: Variant = data.get("dyn", {})
		if d is Dictionary:
			_dyn = d
		var u: Variant = data.get("unread", {})
		if u is Dictionary:
			_unread = u
		_current = str(data.get("current", "general"))

func stats() -> Dictionary:
	return {"channels": CHANNELS.size(), "unread": unread_total(), "dynamic": _dyn.size()}

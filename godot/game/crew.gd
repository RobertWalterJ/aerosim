class_name Crew
extends RefCounted
## The six friends in the DroneBudz server, each with a job of their own (session B). They do not just fill a channel:
## Sam tells the pilot the forecast and the wind, Tom warns about storms and funnels, Alex gives gear advice for the
## current conditions, Riley suggests where to fly and which places are still unfound, Jo talks about the paid work, and
## Maya talks about editing, uploads and the channel. The player can ask any of them from the chat with the quick chips,
## and they also speak up on their own when the weather, a job, an upload or a discovery changes.
##
## Each friend has a role and a channel they prefer. The text is generated from the live game state (the weather menu,
## the funnels and storms, the pilot's current drone, the job board, the camera roll and the discovery list), so two
## flights never get exactly the same answer.

var chat: ChatData
var hud: Hud
var jobs: Jobs
var world_life: WorldLife
var events: WeatherEvents
var photos: PhotoLibrary

var _cooldown := 0.0
var _chatter_t := 75.0
var _rotate := 0
var _last_sky := -1
var _last_funnels := 0
var _last_uploads := 0
var _last_discoveries := 0
var _poll_t := 0.0

const CHAT_ROLES := {
	"Sam": {"channel": "weather", "role": "meteorologist"},
	"Tom": {"channel": "weather", "role": "storm chaser"},
	"Alex": {"channel": "tech", "role": "tech reviewer"},
	"Riley": {"channel": "general", "role": "park ranger"},
	"Jo": {"channel": "jobs", "role": "events and bookings"},
	"Maya": {"channel": "clips", "role": "editor and channel owner"},
}

func setup(c: ChatData, h: Hud, j: Jobs, wl: WorldLife, ev: WeatherEvents, p: PhotoLibrary) -> void:
	chat = c
	hud = h
	jobs = j
	world_life = wl
	events = ev
	photos = p
	_last_sky = _sky()
	_last_funnels = _funnel_count()
	_last_uploads = jobs.videos().size()
	_last_discoveries = world_life.discovered_count()
	# one real, useful post per channel on a fresh save: each friend's own kind of information
	_seed("weather", "Sam", _forecast_text())
	_seed("tech", "Alex", _gear_text())
	_seed("general", "Riley", _spot_text())
	_seed("jobs", "Jo", _jobs_text())
	_seed("clips", "Maya", _edit_text())

func _seed(channel: String, from: String, text: String) -> void:
	for m in chat.messages(channel, false):
		if str(m.get("text", "")).begins_with(text.substr(0, 20)):
			return
	chat.post(channel, from, text, false)

func _post(channel: String, from: String, text: String) -> void:
	chat.post(channel, from, text, false)

# ------------------------------------------------------------------ live information
func _sky() -> int:
	return int(hud.weather.get("sky", 0))

func _hour() -> float:
	return float(hud.weather.get("hour", 12.0))

func _clock_text() -> String:
	var h := _hour()
	return "%02d:%02d" % [int(h) % 24, int((h - floorf(h)) * 60.0) % 60]

func _wind() -> float:
	return float(hud.weather.get("wind", 1.0))

func _wind_word() -> String:
	var w := _wind()
	if w < 3.0: return "calm"
	if w < 6.0: return "light"
	if w < 9.0: return "breezy"
	return "strong"

func _funnel_count() -> int:
	var n := 0
	if events != null:
		for f in events.funnels:
			if f.alive() and f.kind != Funnel.DUST:
				n += 1
	return n

func _forecast_text() -> String:
	var sky := str(WeatherSystem.NAMES[clampi(_sky(), 0, WeatherSystem.NAMES.size() - 1)])
	var intensity := int(float(hud.weather.get("intensity", 0.6)) * 100.0)
	var text := "%s at %s, wind %s at %.1f m/s from %d degrees, gusts at %d%%." % [sky, _clock_text(), _wind_word(), _wind(), int(float(hud.weather.get("from", 250.0))), int(float(hud.weather.get("gust", 0.45)) * 100.0)]
	if _funnel_count() > 0:
		text += " There is a funnel on the ground. Stay upwind of it and keep a way out."
	elif _sky() == 5:
		text += " Storm conditions. The light after it passes is the best of the day."
	elif _sky() == 4:
		text += " Rain is set in. Good for a moody shot, bad for the lens. Keep a cloth on it."
	elif _sky() == 3:
		text += " Fog. Fly low and slow, and keep the hill behind you so you can find your way home."
	elif _sky() == 6:
		text += " Snow. The lake will look completely different for an hour."
	else:
		if _hour() < 16.0:
			text += " Good flying weather. The golden hour is still ahead."
		else:
			text += " Good flying weather. The golden hour has gone, so the blue hour is next."
	if int(hud.weather.get("lowcloud", 0)) > 0:
		text += " Low cloud at %d m, so keep under it." % int(float(hud.weather.get("lowcloud_h", 300.0)))
	return text

func _storm_text() -> String:
	var text := ""
	if events != null and _funnel_count() > 0:
		for f in events.funnels:
			if f.alive() and f.kind != Funnel.DUST:
				var pos: Vector3 = f.anchor
				text = "Funnel on the ground, %s. That is the shot of the week if you stay upwind." % _bearing(pos)
				break
	elif events != null and bool(events.stats().get("storm", false)):
		text = "Thunderstorm cell over the meadow. Lightning is lighting the whole valley, but keep the drone out of the rain shaft."
	elif _sky() == 5:
		text = "This is the day I have been waiting for. Storm light after the rain, and the ridge road gives the clearest view west."
	else:
		text = "Nothing on the ground yet. Storm week is coming though, so keep the fast quad charged and the camera batteries warm."
	return text

func _gear_text() -> String:
	var current := "the drone you are flying"
	if hud.airframe_id != "":
		var af := Airframes.make(hud.airframe_id)
		if not af.is_empty():
			current = str(af.get("name", current))
	var text := "You are on the %s. " % current
	if _wind() >= 9.0:
		text += "That wind will push the cinema drone all over the sky. Race quad or the wing if you actually want to get somewhere."
	elif _wind() >= 6.0:
		text += "It is breezy. The mini will hold, but the five inch is the better camera for a moving shot today."
	else:
		text += "Air is easy. This is cinema drone weather, low and slow, and the gimbal will earn its keep."
	if _sky() == 4 or _sky() == 5:
		text += " Keep the lens hood on and bring a spare battery, rain costs you about a third of the flight time."
	if _hour() < 7.0 or _hour() > 19.0:
		text += " It is dark enough that ISO will cost you detail. Open up, fly slow, and do not push the shutter."
	return text

func _spot_text() -> String:
	if world_life == null:
		return "The valley is big. Follow a road and see where it takes you."
	var un := world_life.undiscovered_places()
	if un.is_empty():
		return "You have found every place I know about. Now get the light right: the fields at golden hour, the lake when the wind drops, the ridge road at dusk."
	var poi: Dictionary = un[0]
	var pos: Vector3 = poi["pos"]
	return "Still unfound: %s, %s. %s" % [str(poi["name"]), _bearing(pos), str(poi.get("note", ""))]

func _bearing(pos: Vector3) -> String:
	var home := world_life.home_position() if world_life != null else Vector2(-18.0, 36.0)
	var d := Vector2(pos.x - home.x, pos.z - home.y)
	var dist := int(round(d.length()))
	var ang := rad_to_deg(atan2(d.x, -d.y))
	if ang < 0.0: ang += 360.0
	var dirs := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	var dir: String = str(dirs[int(round(ang / 45.0)) % 8])
	return "about %d m %s of the pad" % [dist, dir]

func _jobs_text() -> String:
	var offers: Array = jobs.offers_list()
	var active: Array = jobs.active_list()
	var text := ""
	if offers.is_empty() and active.is_empty():
		text = "The board is clear. Upload something, or take the next thing that comes in. We are at %d followers and %d in the pot." % [jobs.followers(), jobs.money()]
	else:
		if not offers.is_empty():
			var titles: Array = []
			for j in offers:
				titles.append(str(j.get("title", "")))
			text += "On the board: %s. " % ", ".join(titles)
		if not active.is_empty():
			var atitles: Array = []
			for j in active:
				atitles.append(str(j.get("title", "")))
			text += "You are on %s. " % ", ".join(atitles)
		text += "Take one from the jobs board when you are ready. The pot pays for gear and the followers bring the next job."
	return text

func _edit_text() -> String:
	var v := jobs.last_video()
	if v.is_empty():
		return "Send me a clip when you have one. I will cut it, and I promise the first one will not be perfect. The channel needs a first cut."
	if bool(v.get("edited", false)):
		return "The cut I made is on %d views. That is what editing does. Keep sending the raw stuff to #clips and let me work." % int(v.get("views", 0))
	return "That last one went up raw. It is on %d views, which is fine, but send the next one to #clips and I will cut it. Same clip, better numbers." % int(v.get("views", 0))

func _upload_feedback() -> String:
	var v := jobs.last_video()
	if v.is_empty():
		return "I saw the upload. Give me the next one to cut."
	return "The new upload is doing %d views. If you send me the next one before it goes up, I can make it %d." % [int(v.get("views", 0)), int(int(v.get("views", 0)) * 2.3)]

# ------------------------------------------------------------------ per frame
func update(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_poll_t -= delta
	if _poll_t <= 0.0:
		_poll_t = 1.0
		_poll_changes()
	_chatter_t -= delta
	if _chatter_t <= 0.0 and _cooldown <= 0.0:
		_chatter_t = 95.0
		_rotate = (_rotate + 1) % 6
		_role_chatter(_rotate)

func _poll_changes() -> void:
	var sky := _sky()
	if sky != _last_sky and _cooldown <= 0.0:
		_last_sky = sky
		_cooldown = 18.0
		_post("weather", "Sam", _forecast_text())
	var fc := _funnel_count()
	if fc > _last_funnels and _cooldown <= 0.0:
		_last_funnels = fc
		_cooldown = 12.0
		_post("weather", "Tom", _storm_text())
	elif fc < _last_funnels:
		_last_funnels = fc
	var uploads := jobs.videos().size()
	if uploads > _last_uploads:
		_last_uploads = uploads
		if _cooldown <= 0.0:
			_cooldown = 10.0
			_post("clips", "Maya", _upload_feedback())
			_post("tech", "Alex", _gear_text())
	var disc := world_life.discovered_count()
	if disc > _last_discoveries:
		_last_discoveries = disc
		if _cooldown <= 0.0:
			_cooldown = 10.0
			_post("general", "Riley", _spot_text())

func _role_chatter(i: int) -> void:
	match i:
		0: _post("weather", "Sam", _forecast_text())
		1: _post("tech", "Alex", _gear_text())
		2: _post("weather", "Tom", _storm_text())
		3: _post("general", "Riley", _spot_text())
		4: _post("jobs", "Jo", _jobs_text())
		5: _post("clips", "Maya", _edit_text())

## The chat's quick chips and typed questions call this. The right friend answers in the channel the player is in.
func ask(kind: String, channel: String) -> void:
	match kind:
		"weather":
			_post(channel, "Sam", _forecast_text())
		"storm":
			_post(channel, "Tom", _storm_text())
		"gear":
			_post(channel, "Alex", _gear_text())
		"spot":
			_post(channel, "Riley", _spot_text())
		"jobs":
			_post(channel, "Jo", _jobs_text())
		"edit":
			_post(channel, "Maya", _edit_text())
		_:
			_post(channel, "Maya", "Ask us anything. We each know our own part of this valley.")

func stats() -> Dictionary:
	return {"funnels": _funnel_count(), "uploads": jobs.videos().size(), "discoveries": world_life.discovered_count()}

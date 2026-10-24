class_name Finale
extends Node
## The last flight (session B): the ghost of Constable Rennick, the abandoned cabin, Wren, the storm and the thermal
## camera. This runs after the Lake Car case is closed and the unknown account has sent its last message.
##
## The player is guided north by messages from the dead officer. The cabin lights come on through the storm, Wren has
## already set out again, and the only way to find them is the thermal camera Alex fits before the flight. Flying close
## to the heat signature ends the story and starts the credits.

var hud: Hud
var chat: ChatData
var notes: PhoneNotes
var story: StoryArc
var unknown: UnknownThread
var objects: CaseObjects
var weather_events: WeatherEvents
var thermal: ThermalCamera
var ending: Ending
var inventory: Inventory
var wildlife: WildlifeCase
var sites: LaunchSites
var anti_drone: AntiDrone

var started := false
var ended := false
var stage := 0
var auto_start := true
var _objective_layer: CanvasLayer
var _objective: Label
var _hint: Label
var _auto_timer := 0.0
var _last_waypoint := -1
var _found_announced := false
var _debug_frozen := false
var _missing_prompt := ""

const CABIN_CLOSE := 190.0
const HIKER_FIND := 105.0
const WAYPOINTS := [700.0, 420.0, 190.0]

func setup(h: Hud, c: ChatData, n: PhoneNotes, s: StoryArc, u: UnknownThread, o: CaseObjects, w: WeatherEvents, t: ThermalCamera, e: Ending, inv: Inventory, wild: WildlifeCase, ls: LaunchSites = null) -> void:
	hud = h
	chat = c
	notes = n
	story = s
	unknown = u
	objects = o
	weather_events = w
	thermal = t
	ending = e
	inventory = inv
	wildlife = wild
	sites = ls
	_build_objective()

func _build_objective() -> void:
	# The old top-of-screen objective box was an out-of-world game card. The last flight now uses Rennick's messages,
	# the phone notes and the flight app NAV strip on the HUD instead.
	_objective_layer = CanvasLayer.new()
	_objective_layer.layer = 3
	_objective_layer.visible = false
	add_child(_objective_layer)

func _nav_to(pos: Vector3, label: String) -> void:
	if hud != null:
		hud.set_nav_target(pos, label)
func _set_objective(text: String, hint := "") -> void:
	# Kept only as a debug/state note; the player sees the route as a NAV waypoint and hears it from Rennick.
	pass

func update(delta: float, drone_pos: Vector3) -> void:
	if ended or ending == null:
		return
	if not started:
		if auto_start and hud != null and hud.story_on and story != null and story.case_closed() and unknown != null and unknown.beat >= 5:
			_auto_timer += delta
			if _auto_timer > 3.0:
				var missing := _missing_requirement()
				if missing != "":
					if _missing_prompt != missing:
						_missing_prompt = missing
						_prompt_missing(missing)
					return
				start()
		return
	if thermal == null:
		return
	objects.set_thermal_marker(thermal.is_on())
	if _debug_frozen:
		return
	var cabin := objects.cabin_world_pos()
	var dist := drone_pos.distance_to(cabin)
	if stage == 0 and dist <= WAYPOINTS[0] and _last_waypoint < 0:
		_last_waypoint = 0
		stage = 1
		_ghost("The old plot is off the north shore track. The trees close in before the cabin. I remember this road.", "Rennick")
		_set_objective("Follow the old track north to the abandoned cabin", "The storm is getting worse. T toggles the thermal camera.")
	elif stage == 1 and dist <= WAYPOINTS[1] and _last_waypoint < 1:
		_last_waypoint = 1
		stage = 2
		_ghost("You are getting close. The cruiser should be outside. I never made it inside. I can see the cabin lights from here.", "Rennick")
	elif stage == 2 and dist <= WAYPOINTS[2] and _last_waypoint < 2:
		_last_waypoint = 2
		stage = 3
		_arrive_cabin()
	if stage == 3 and not ended:
		var hiker := objects.hiker_world_pos()
		var hd := drone_pos.distance_to(hiker)
		if thermal.is_on() and hd <= HIKER_FIND:
			_found()

func _missing_requirement() -> String:
	if inventory == null or not inventory.has_addon("thermal_camera"):
		return "thermal"
	if wildlife == null or not wildlife.completed():
		return "wildlife"
	if sites != null and not (str(sites.active_id) in ["cabin_track", "north_ridge"]):
		return "site"
	return ""

func _prompt_missing(kind: String) -> void:
	if kind == "thermal":
		chat.post("town", "Rennick", "Not yet. There is one piece of kit you need before the last flight. A thermal camera, from Facade. Riley's night pasture will show you how to use it.", false)
		notes.post_text("Rennick", "One more thing", "You need the thermal camera from Facade before the last flight. Riley's night pasture is the place to learn it.", 1)
	elif kind == "wildlife":
		chat.post("town", "Riley", "Before the last flight, come and find what has been taking my sheep. The west pasture will teach you the thermal camera, and I need the answer.", false)
		notes.post_text("Riley", "Night pasture first", "The last flight needs the thermal camera you learn in the west pasture. Finish Riley's favour first.", 1)
	elif kind == "site":
		chat.post("town", "Rennick", "Come north. The last flight should start from the ridge trailhead, not from the home pad. Drive the kit up, then open the map if you need the way.", false)
		notes.post_text("Rennick", "Launch from the trailhead", "The last flight starts from the ridge trailhead or the north gate pull-off. Use the Map app to drive the kit there.", 1)

func _arrive_cabin() -> void:
	objects.set_cabin_lights(true)
	objects.show_hiker()
	hud.toast("The cabin lights are on. Wren has set out again on foot.", false, "DRONEBUDZ")
	_nav_to(objects.hiker_world_pos(), "HEAT")
	_ghost("The cabin is ahead. Wren set out again on foot, east of the cabin near the treeline. I cannot see them from here. Use the thermal camera.", "Rennick")
	notes.post_text("Rennick", "The cabin", "Wren is on foot east of the cabin. Press T for the thermal camera and search the treeline.", 0)
	_set_objective("Search east of the cabin for Wren", "Press T for the thermal camera. Warm bodies show white and orange.")

func _found() -> void:
	if _found_announced:
		return
	_found_announced = true
	ended = true
	stage = 4
	_ghost("You found them. Thank you. Tell Wren the lights in the cabin were not the storm. Tell them I am sorry it took so long.", "Rennick")
	chat.post("unknown", "Unknown", "thank you. i can see the drone. i am waving.", false)
	if hud != null:
		hud.clear_nav_target()
	if thermal != null:
		thermal.set_on(false)
	if ending != null:
		ending.play()

func start() -> void:
	if started:
		return
	var missing := _missing_requirement()
	if missing != "":
		_prompt_missing(missing)
		return
	started = true
	stage = 0
	_last_waypoint = -1
	_nav_to(objects.cabin_world_pos(), "CABIN")
	_set_objective("Fly north to the abandoned cabin", "A storm is coming in. Press T for the thermal camera once it is installed.")
	if weather_events != null:
		weather_events.debug_event("storm")
	if hud != null:
		hud.weather["hour"] = 20.5
		hud.weather["wind"] = 8.5
		hud.apply_look()
		hud.toast("Thermal camera patched into the gimbal. The camera button is on the flight screen.", false, "CAMERA")
		chat.post("tech", "Alex", "The thermal camera is in the gimbal. The camera button is on your flight screen now. Press T or tap it. Warm bodies show white and orange.", false)
	if thermal != null:
		thermal.install()
	_ghost("The Pike jammer is off us now. The hunter drones are not. Do not slow down over the trees.", "Rennick")
	# The reveal. The officer the player has been talking to died forty years ago.
	_ghost("I have to tell you something I should have told you at the start.", "Rennick")
	_ghost("I am not the new constable. I died out here forty years ago, on the old plot past the north shore.", "Rennick")
	_ghost("A woman went missing on the lake road in a storm. A pilot saw lights and called it in. I went out to look for her. My cruiser is still outside the cabin.", "Rennick")
	_ghost("The person messaging you is Wren. They are lost. They were in the cabin watching your videos to work out where they were. I have been borrowing their phone.", "Rennick")
	_ghost("I am sorry I lied. Please find Wren. Then I can go.", "Rennick")
	chat.post("unknown", "Unknown", "please hurry. the lights in the cabin are not mine.", false)
	notes.post_text("Rennick", "The last flight", "The constable has one more favour. Fly north to the old cabin and find Wren.", 1)
	_print_reveal()

func _ghost(text: String, from: String) -> void:
	chat.post("town", from, text, false)
	notes.post_text(from, "Rennick", text, 0)

func _print_reveal() -> void:
	print("finale: started; state=", stats())

func is_started() -> bool:
	return started

func is_ended() -> bool:
	return ended

func stats() -> Dictionary:
	return {"started": started, "ended": ended, "stage": stage, "waypoint": _last_waypoint, "thermal": thermal.is_on() if thermal != null else false}

## Dev hooks for screenshots and the gate.
func debug_start() -> void:
	if inventory != null and not inventory.has_addon("thermal_camera"):
		inventory.add_purchase(FacadeCatalog.item("thermal_camera"))
	if wildlife != null and not wildlife.completed():
		wildlife.debug_complete()
	if sites != null:
		sites.set_active("cabin_track")
	start()

func debug_cabin() -> void:
	if not started:
		start()
	stage = 3
	_last_waypoint = 2
	objects.set_cabin_lights(true)
	objects.show_hiker()
	if thermal != null:
		thermal.install()
		thermal.set_on(true)
		objects.set_thermal_marker(true)
	_ghost("The Pike jammer is off us now. The hunter drones are not. Do not slow down over the trees.", "Rennick")
	_nav_to(objects.hiker_world_pos(), "HEAT")
	_set_objective("Search east of the cabin for Wren", "Thermal camera on. Warm bodies show white and orange.")

func debug_found() -> void:
	if not started:
		debug_cabin()
	_found()

## A look at the thermal camera while the search is still live, so it does not trigger the ending.
func debug_thermal_view() -> void:
	if not started:
		start()
	stage = 2
	_debug_frozen = true
	objects.set_cabin_lights(true)
	objects.show_hiker()
	if thermal != null:
		thermal.install()
		thermal.set_on(true)
		objects.set_thermal_marker(true)
	_ghost("The Pike jammer is off us now. The hunter drones are not. Do not slow down over the trees.", "Rennick")
	_nav_to(objects.hiker_world_pos(), "HEAT")
	_set_objective("Search east of the cabin for Wren", "Thermal camera on. Warm bodies show white and orange.")

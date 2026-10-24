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

const CABIN_CLOSE := 190.0
const HIKER_FIND := 105.0
const WAYPOINTS := [700.0, 420.0, 190.0]

func setup(h: Hud, c: ChatData, n: PhoneNotes, s: StoryArc, u: UnknownThread, o: CaseObjects, w: WeatherEvents, t: ThermalCamera, e: Ending) -> void:
	hud = h
	chat = c
	notes = n
	story = s
	unknown = u
	objects = o
	weather_events = w
	thermal = t
	ending = e
	_build_objective()

func _build_objective() -> void:
	_objective_layer = CanvasLayer.new()
	_objective_layer.layer = 3
	_objective_layer.visible = false
	add_child(_objective_layer)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 300
	panel.offset_right = -300
	panel.offset_top = 74
	panel.offset_bottom = 142
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.11, 0.88)
	sb.set_corner_radius_all(10)
	sb.border_width_left = 3
	sb.border_color = Color(0.72, 0.56, 0.30)
	panel.add_theme_stylebox_override("panel", sb)
	_objective_layer.add_child(panel)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	m.add_child(col)
	_objective = Label.new()
	_objective.add_theme_font_size_override("font_size", 16)
	_objective.add_theme_color_override("font_color", Color(0.95, 0.92, 0.80))
	col.add_child(_objective)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Color(0.68, 0.74, 0.80))
	col.add_child(_hint)

func _set_objective(text: String, hint := "") -> void:
	_objective.text = text
	_hint.text = hint

func update(delta: float, drone_pos: Vector3) -> void:
	if ended or ending == null:
		return
	if not started:
		if auto_start and hud != null and hud.story_on and story != null and story.case_closed() and unknown != null and unknown.beat >= 5:
			_auto_timer += delta
			if _auto_timer > 3.0:
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

func _arrive_cabin() -> void:
	objects.set_cabin_lights(true)
	objects.show_hiker()
	hud.toast("The cabin lights are on. Wren has set out again on foot.")
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
	_objective_layer.visible = false
	if thermal != null:
		thermal.set_on(false)
	if ending != null:
		ending.play()

func start() -> void:
	if started:
		return
	started = true
	stage = 0
	_last_waypoint = -1
	_objective_layer.visible = true
	_set_objective("Fly north to the abandoned cabin", "A storm is coming in. Press T for the thermal camera once it is installed.")
	if weather_events != null:
		weather_events.debug_event("storm")
	if hud != null:
		hud.weather["hour"] = 20.5
		hud.weather["wind"] = 8.5
		hud.apply_look()
		hud.toast("Alex: thermal camera patched into the gimbal. Press T to toggle it.")
	if thermal != null:
		thermal.install()
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
	_set_objective("Search east of the cabin for Wren", "Thermal camera on. Warm bodies show white and orange.")

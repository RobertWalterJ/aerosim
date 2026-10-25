class_name WildlifeCase
extends Node
## The night pasture favour (session B): Riley's sheep have been taken, and the pilot learns the thermal camera before the
## last flight. The player must buy the thermal camera module on Facade, fit it, fly the west pasture and find the wolf
## with the heat camera. It is a small story-side mission, not a fail state, and the resolution is humane: the flock is
## moved and penned, the wolf is not hunted.
##
## This mission is also the gate for the last flight: the finale will not start until the thermal camera is owned and the
## night pasture has been completed.

const SAVE := "user://wildlife_case.cfg"
const FIND_DIST := 110.0

var hud: Hud
var chat: ChatData
var notes: PhoneNotes
var story: StoryArc
var inventory: Inventory
var thermal: ThermalCamera
var objects: WildlifeObjects

var started := false
var done := false
var stage := 0                 # 0 thermal not fitted, 1 tracking, 2 done
var _layer: CanvasLayer
var _objective: Label
var _hint: Label
var _prompted_purchase := false

func setup(h: Hud, c: ChatData, n: PhoneNotes, s: StoryArc, inv: Inventory, t: ThermalCamera, o: WildlifeObjects) -> void:
	hud = h
	chat = c
	notes = n
	story = s
	inventory = inv
	thermal = t
	objects = o
	_build_objective()
	_load()
	if done:
		_layer.visible = false

func _build_objective() -> void:
	# No out-of-world objective card. Riley's messages, the phone note and the flight app NAV waypoint carry the favour.
	_layer = CanvasLayer.new()
	_layer.layer = 3
	_layer.visible = false
	add_child(_layer)
func _set_objective(title: String, hint := "") -> void:
	# Kept as a state note only; the player hears the favour from Riley and sees the route as a NAV waypoint.
	pass

func update(delta: float, drone_pos: Vector3) -> void:
	if done:
		return
	if not started:
		if story != null and story.started and story.chapter >= 2:
			_start()
		return
	if thermal != null and objects != null:
		objects.set_thermal_markers(thermal.is_on())
	var has_thermal := inventory != null and inventory.has_addon("thermal_camera")
	if has_thermal and thermal != null and not thermal.is_installed():
		thermal.install()
	if not has_thermal:
		if stage == 0:
			_set_objective("Get a thermal camera from Facade", "Facade has a thermal module. Buy it, fit it, then fly the west pasture. The farm gate is the closest launch site on the map.")
		return
	if stage == 0:
		stage = 1
		_save()
		if objects != null:
			objects.show_wolf()
		if chat != null:
			chat.post("general", "Riley", "That is the thermal camera fitted. West pasture, after dark. The flock is in the hay field, the wolf is somewhere along the trees. Keep high and do not land.", false)
			chat.post("general", "Riley", "If it sees the drone it will stand its ground and warn you for a moment, then break for the trees. Do not chase it into the wood; a sighting from a respectful distance is the whole favour.", false)
		if notes != null:
			notes.post_text("Riley", "Night pasture", "Thermal camera fitted. Fly the west pasture with the thermal camera on and find the wolf.", 0)
		if hud != null and objects != null:
			hud.set_nav_target(objects.wolf_position(), "WOLF")
	_set_objective("Night pasture: find the wolf with the thermal camera", "Press T for thermal. Fly the west pasture, keep high, and look for the heat signature along the trees. If it faces you, hold back: it will warn, then run. Launch from the farm gate if you are far away.")
	if thermal != null and thermal.is_on() and objects != null:
		if drone_pos.distance_to(objects.wolf_position()) < FIND_DIST:
			_complete()

func _start() -> void:
	started = true
	_save()
	if chat != null:
		chat.post("general", "Riley", "Not a channel job, a favour. Something has been taking sheep out of the west pasture at night. I have found prints and wool, no blood worth photographing. If it is a wolf I want to know which one and where it is going, not a rifle.", false)
		chat.post("general", "Riley", "A thermal pass after dark would tell us. Alex has a thermal camera on Facade if you have not got one. Fit it, come out to the hay field, and keep high.", false)
	if notes != null:
		notes.post_text("Riley", "Something in the west pasture", "A night tracking favour. Fit a thermal camera from Facade and fly the west pasture.", 0)
	_set_objective("Get a thermal camera from Facade", "Buy the thermal module, then fly the west pasture at night.")

func _complete() -> void:
	if done:
		return
	done = true
	stage = 2
	_save()
	if hud != null:
		hud.clear_nav_target()
	if chat != null:
		chat.post("general", "Riley", "There it is. A young wolf, thin, no collar, a long way from the hills. It has been taking the weakest sheep because the flock is out in the open.", false)
		chat.post("general", "Riley", "We are moving the flock to the home field and putting up a proper night pen. Nobody is shooting it. Thank you for the pass. You know how to use that camera now.", false)
	if notes != null:
		notes.post_text("Riley", "Night pasture solved", "The wolf is young and hungry, not a monster. The flock is being penned. The thermal camera is part of the kit now.", 0)
	if hud != null:
		hud.toast("Night pasture solved. The wolf was real, and the sheep will be safer for it.", false, "DRONEBUDZ")

func completed() -> bool:
	return done

func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("wildlife", "started", started)
	cf.set_value("wildlife", "done", done)
	cf.set_value("wildlife", "stage", stage)
	cf.save(SAVE)

func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE) != OK:
		return
	started = bool(cf.get_value("wildlife", "started", false))
	done = bool(cf.get_value("wildlife", "done", false))
	stage = int(cf.get_value("wildlife", "stage", 0))

## Dev hooks for screenshots and the gate.
func debug_start() -> void:
	if not started:
		_start()
	if inventory != null and not inventory.has_addon("thermal_camera"):
		inventory.add_purchase(FacadeCatalog.item("thermal_camera"))
	if thermal != null:
		thermal.install()
	if stage == 0:
		stage = 1
		if objects != null:
			objects.show_wolf()
	_set_objective("Night pasture: find the wolf with the thermal camera", "Press T for thermal. Fly the west pasture, keep high, and look for the heat signature along the trees. If it faces you, hold back: it will warn, then run. Launch from the farm gate if you are far away.")

func debug_complete() -> void:
	debug_start()
	_complete()

func stats() -> Dictionary:
	return {"started": started, "done": done, "stage": stage}

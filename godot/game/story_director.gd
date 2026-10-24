class_name StoryDirector
extends Node
## The story director (session B): one place that knows which act of the Halloway story is running and what the player
## needs to do next. The actual chapters stay in StoryArc, the unknown thread in UnknownThread, the night pasture in
## WildlifeCase, the last flight in Finale and the credits in Ending; this node only reads their state and turns it into
## a clean player-facing route. The Casebook shows the director's act card at the top of the file.

signal act_changed(act: int)

const ACTS := ["Waiting", "The Lake Car", "The Last Flight", "The Cabin", "The End"]

var hud: Hud
var story: StoryArc
var unknown: UnknownThread
var wildlife: WildlifeCase
var inventory: Inventory
var finale: Finale
var ending: Ending

var act := 0

func setup(h: Hud, s: StoryArc, u: UnknownThread, w: WildlifeCase, inv: Inventory, f: Finale, e: Ending) -> void:
	hud = h
	story = s
	unknown = u
	wildlife = w
	inventory = inv
	finale = f
	ending = e
	act = _act_from_state()

func update(_delta: float) -> void:
	var next := _act_from_state()
	if next != act:
		act = next
		act_changed.emit(act)

func _act_from_state() -> int:
	if ending != null and ending.started:
		return 4
	if finale != null and finale.is_started():
		return 3
	if story != null and story.case_closed():
		return 2
	if story != null and story.started:
		return 1
	return 0

func act_name() -> String:
	return ACTS[clampi(act, 0, ACTS.size() - 1)]

func act_number() -> int:
	return clampi(act + 1, 1, ACTS.size())

func next_step() -> String:
	if ending != null and ending.started:
		return "The story is complete. The credits are rolling."
	if finale != null and finale.is_started():
		return "The last flight. Follow Rennick's messages north, find the cabin lights and use the thermal camera to find Wren."
	if story == null:
		return "The valley is quiet."
	if not story.started:
		return "Publish a clip or finish a job in DroneBudz. The constable will get in touch."
	if story.case_closed():
		if inventory == null or not inventory.has_addon("thermal_camera"):
			return "Rennick needs one more thing before the cabin: buy the thermal camera on Facade, then try Riley's night pasture."
		if wildlife == null or not wildlife.completed():
			return "The night pasture is still open. Use the thermal camera in the west pasture to find the wolf."
		return "Everything is ready. Rennick is waiting at the cabin. Open #town and take the last flight."
	if wildlife != null and story.chapter >= 2 and not wildlife.completed():
		return "Riley's night pasture is open. Buy the thermal camera on Facade if you have not, then find the wolf in the west pasture."
	return str(story.current_status())

func chapter_line() -> String:
	if story == null or not story.started:
		return "No case yet"
	if story.case_closed():
		return "The Lake Car closed"
	return "Chapter %d of %d  ·  %s" % [story.chapter + 1, story.chapter_count(), _act_title()]

func _act_title() -> String:
	if story == null or story.chapter < 0 or story.chapter >= story.chapter_count():
		return "Halloway"
	return "The Lake Car"

func thermal_ready() -> bool:
	return inventory != null and inventory.has_addon("thermal_camera")

func wildlife_done() -> bool:
	return wildlife != null and wildlife.completed()

func stats() -> Dictionary:
	return {"act": act, "name": act_name(), "thermal": thermal_ready(), "wildlife": wildlife_done(), "next": next_step()}

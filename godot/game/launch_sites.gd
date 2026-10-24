class_name LaunchSites
extends RefCounted
## The valley launch sites (session B): the pilot cannot fly from every road junction, but a handful of places make
## sense as a place to unpack the drone. The map app lets the player drive the kit to a site; this class owns the sites,
## the current one and the small save file.

const SAVE := "user://launch_site.cfg"

const SITES := [
	{"id": "home", "name": "Cemetery home pad", "pos": Vector2(-18.0, 36.0), "yaw": 150.0,
		"note": "The old home pad inside the cemetery. Close to the chapel and the east gate."},
	{"id": "east_gate", "name": "East gate car park", "pos": Vector2(264.0, 58.0), "yaw": 180.0,
		"note": "The cemetery car park. Good for the chapel, the east lane and the valley highway."},
	{"id": "north_ridge", "name": "North gate pull-off", "pos": Vector2(24.0, -263.0), "yaw": 0.0,
		"note": "The lane outside the north gate. The ridge road and the camp are close."},
	{"id": "farm", "name": "Toby Farm gate", "pos": Vector2(188.0, 512.0), "yaw": 120.0,
		"note": "The farm gate above the sheep pasture and the hay field."},
	{"id": "lake", "name": "Boat launch", "pos": Vector2(-424.0, 118.0), "yaw": 90.0,
		"note": "The gravel apron at Halloway Lake. The water, the launch and the long shore."},
	{"id": "garage", "name": "Voss and Son yard", "pos": Vector2(66.0, -592.0), "yaw": 180.0,
		"note": "The old garage forecourt. Good for the ridge and the camp."},
	{"id": "cabin_track", "name": "Ridge trailhead", "pos": Vector2(38.0, -752.0), "yaw": 170.0,
		"note": "The pull-off where the old dirt track leaves the ridge road for the cabin."},
	{"id": "camp", "name": "Ridge camp", "pos": Vector2(42.0, -1108.0), "yaw": 180.0,
		"note": "The camp track at the north end. The railway and the high ridge are close."},
	{"id": "festival", "name": "Festival field", "pos": Vector2(292.0, 292.0), "yaw": 180.0,
		"note": "The field gate by the festival ground and the south lane."},
]

var active_id := "home"

func setup() -> void:
	_load()

func list() -> Array:
	return SITES

func site(id: String) -> Dictionary:
	for s in SITES:
		if str(s["id"]) == id:
			return s
	return SITES[0]

func current() -> Dictionary:
	return site(active_id)

func set_active(id: String) -> bool:
	for s in SITES:
		if str(s["id"]) == id:
			active_id = id
			_save()
			return true
	return false

func pos(id := "") -> Vector2:
	return site(id if id != "" else active_id)["pos"]

func yaw(id := "") -> float:
	return float(site(id if id != "" else active_id)["yaw"])

func name(id := "") -> String:
	return str(site(id if id != "" else active_id)["name"])

func distance_m(a: Vector2, b: Vector2) -> float:
	return a.distance_to(b)

func drive_minutes(from: Vector2, to: Vector2) -> int:
	return maxi(1, int(round(distance_m(from, to) / (35.0 * 1000.0 / 60.0))))

func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("launch", "active", active_id)
	cf.save(SAVE)

func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE) != OK:
		return
	var id := str(cf.get_value("launch", "active", "home"))
	for s in SITES:
		if str(s["id"]) == id:
			active_id = id
			return

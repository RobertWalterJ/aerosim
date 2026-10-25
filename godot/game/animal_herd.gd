class_name AnimalHerd
extends Node3D
## A small herd of Claude's rigged Blender animals that graze, wander and flee from the drone. Each animal is an
## AnimalAssets instance moved at the clip's ground speed (AnimalInfo.INFO.speeds), facing its direction of travel, and
## switching clips graze / walk / run as it grazes, wanders or bolts. Set `threat` to the drone position each frame; an
## animal within `flee_radius` runs directly away and only calms once the drone is past `calm_radius`.
##
## Usage:
##     var herd := AnimalHerd.new(terrain)
##     herd.add("cow_a", pos); herd.add("sheep_a", pos, "cream")
##     add_child(herd)
##     ... each frame:  herd.threat = drone.global_position

var terrain: Object                    # duck-typed: height(x, z) -> float
var threat := Vector3.INF              # the drone; INF = none
var flee_radius := 26.0                # run when the threat is closer than this
var calm_radius := 44.0                # stop running when it is farther than this
var graze_radius := 12.0               # how far an animal wanders from its home spot

var _animals: Array[Dictionary] = []

func _init(t: Object) -> void:
	terrain = t

## Add one animal at a world position (grounded to the terrain). Returns its root node.
func add(animal_name: String, pos: Vector3, tint := "white") -> Node3D:
	pos.y = _ground(pos)
	var opts := {"clip": "graze", "seed": _animals.size(), "tint": tint}
	var node := AnimalAssets.place(self, animal_name, Transform3D(Basis.IDENTITY, pos), opts)
	var info: Dictionary = AnimalInfo.INFO.get(animal_name, {})
	var clips: Array = info.get("clips", ["idle", "walk", "run"])
	_animals.append({
		"node": node, "base": pos, "heading": randf() * TAU,
		"mode": "graze", "timer": randf_range(2.0, 6.0),
		"info": info, "clips": clips, "graze": "graze" in clips,
	})
	return node

func count() -> int:
	return _animals.size()

func _process(delta: float) -> void:
	for a in _animals:
		_step(a, delta)

func _ground(p: Vector3) -> float:
	if terrain != null and terrain.has_method("height"):
		return terrain.height(p.x, p.z)
	return 0.0

func _step(a: Dictionary, delta: float) -> void:
	var node: Node3D = a["node"]
	var pos := node.global_position
	var near := threat.is_finite() and pos.distance_squared_to(threat) < flee_radius * flee_radius
	var far := (not threat.is_finite()) or pos.distance_squared_to(threat) > calm_radius * calm_radius

	# decide the mode
	if near:
		a["mode"] = "flee"
	elif a["mode"] == "flee" and far:
		a["mode"] = "wander"; a["timer"] = 1.0
	elif a["mode"] != "flee":
		a["timer"] -= delta
		if a["timer"] <= 0.0:
			a["mode"] = "wander" if a["mode"] == "graze" else "graze"
			a["timer"] = randf_range(2.5, 7.0)
			if a["mode"] == "wander":
				a["heading"] = randf() * TAU

	# pick the clip and speed, and turn to face travel
	var clip := "idle"
	var speed := 0.0
	match a["mode"]:
		"flee":
			clip = "run"
			speed = float(a["info"].get("speeds", {}).get("run", 3.0))
			var away := pos - threat; away.y = 0.0
			if away.length() > 0.01:
				a["heading"] = atan2(away.x, away.z)
		"wander":
			clip = "walk"
			speed = float(a["info"].get("speeds", {}).get("walk", 0.6))
		"graze":
			clip = "graze" if a["graze"] else "idle"

	AnimalAssets.play(node, clip, 0.25)

	if speed <= 0.0:
		node.rotation.y = a["heading"]
		return

	var dir := Vector3(sin(a["heading"]), 0.0, cos(a["heading"]))
	var npos := pos + dir * speed * delta
	if a["mode"] != "flee":
		# stay inside the grazing circle; turn back toward home at the edge
		var off: Vector3 = npos - (a["base"] as Vector3); off.y = 0.0
		if off.length() > graze_radius:
			a["heading"] = atan2(-off.x, -off.z)
			dir = Vector3(sin(a["heading"]), 0.0, cos(a["heading"]))
			npos = a["base"] + dir * graze_radius
	npos.y = _ground(npos)
	node.global_position = npos
	node.rotation.y = a["heading"]

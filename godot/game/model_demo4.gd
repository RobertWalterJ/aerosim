class_name ModelDemo4
extends RefCounted
## A test hook for the batch-6 models (game/new_models4.gd): puts them in the real scene, in a row across the drone's view, on
## the terrain, so they can be checked under the game's own sky, sun, haze and camera. Used by main.gd's screenshot token
## `models4demo:<name>+<name>...`. Not used in play.

## Place the models in a row `dist` m ahead of `from`, looking along `heading`, `gap` m apart, at lod 0.
static func spawn(parent: Node, terrain: Terrain, from: Vector3, heading: float, names: Array, dist := 22.0, gap := 6.5) -> void:
	var list: Array = []
	for n0 in names:
		if String(n0).begins_with("@"): dist = float(String(n0).substr(1))        # "@12" sets the distance
		elif String(n0).begins_with("g"): gap = float(String(n0).substr(1))      # "g5" sets the gap
		else: list.append(n0)
	names = list
	var fwd := Vector3(-sin(heading), 0.0, -cos(heading))
	var right := Vector3(cos(heading), 0.0, -sin(heading))
	var centre := from + fwd * dist
	var n := names.size()
	for i in n:
		var nm: String = String(names[i])
		var node := NewModels4.build_node(nm, 0)
		var p := centre + right * (float(i) - (n - 1) * 0.5) * gap
		var h := terrain.height(p.x, p.z)
		node.position = Vector3(p.x, h, p.z)
		node.rotation.y = heading + PI * 0.75                # three-quarter view, front toward the camera
		parent.add_child(node)

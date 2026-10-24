class_name Gallery5
extends RefCounted
## A test hook for the models of game/new_models5.gd in the REAL scene (terrain, grass, sky, light and the sensor pipeline): the game's screenshot
## token `props5<set>` puts a set of them on the meadow near the start (animals, farm) or on the lake shore (lake). It is never used in play.
## Fly the camera to look at them with the usual `at<x>_<up>_<z>_<yaw>_<gimbal>` token.
##   Godot --path <godot dir> -- "shot=out.png,300,fpv,props5animals,clock16.0,at-18_6_30_180_-12"
## It prints where it put them. B places the models for real; this is only for looking.

static func build(parent: Node, terrain: Terrain, home: Vector2, which: String) -> void:
	match which:
		"animals": _row(parent, terrain, Vector2(home.x - 14.0, home.y - 24.0), 3.4,
			["cow_a", "cow_b", "calf_a", "sheep_a", "sheep_b", "lamb_a", "horse_a", "horse_b", "dog_a", "chicken_a"], 0.0)
		"cows": _row(parent, terrain, Vector2(home.x - 8.0, home.y - 22.0), 3.2, ["cow_a", "cow_b", "cow_c", "calf_a"], 0.0)
		"farm": _row(parent, terrain, Vector2(home.x - 18.0, home.y - 30.0), 7.5,
			["combine_a", "baler_a", "plough_a", "seed_drill_a", "grain_silo_a", "oil_tank_a", "chicken_coop_a", "dog_kennel_a", "water_trough_a", "feed_rack_a", "wood_pile_a", "fence_gate_hanging_a"], 0.0)
		"lake": _lake(parent, terrain, home)

static func _put(parent: Node, terrain: Terrain, name: String, x: float, z: float, yaw: float, y_extra := 0.0, lod := 0, sink_to := -1000.0) -> void:
	var y := terrain.height(x, z) + y_extra
	if sink_to > -999.0: y = sink_to
	var mi := MeshInstance3D.new()
	mi.mesh = NewModels5.mesh(name, lod)
	mi.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(x, y, z))
	mi.name = name
	parent.add_child(mi)

static func _row(parent: Node, terrain: Terrain, start: Vector2, gap: float, names: Array, yaw: float) -> void:
	var x := start.x
	for nm: String in names:
		var bb := NewModels5.mesh(nm, 0).get_aabb()
		var w := maxf(bb.size.x, bb.size.z) * 0.5 + gap * 0.5
		x += w
		_put(parent, terrain, nm, x, start.y, yaw + deg_to_rad(25.0))
		x += w
	print("gallery5: ", names.size(), " models in a row on z=", start.y, " from x=", start.x, " to ", x)

## Boats, a jetty, a buoy and a mooring post on the lake: the nearest shore to the start.
static func _lake(parent: Node, terrain: Terrain, home: Vector2) -> void:
	var best := Vector2.ZERO
	var found := false
	var r := 40.0
	while r < 3000.0 and not found:
		for k in 72:
			var a := TAU * k / 72.0
			var p := home + Vector2(cos(a), sin(a)) * r
			if Lake.is_wet(p.x, p.y) and terrain.height(p.x, p.y) < Lake.LEVEL - 0.3:
				best = p; found = true; break
		r += 40.0
	if not found:
		print("gallery5: no lake found")
		return
	# walk to the water's edge: from the first wet cell back toward home until the ground is above the water
	var toward := (home - best).normalized()
	var edge := best
	for i in 400:
		var q := best + toward * (float(i) * 0.5)
		if terrain.height(q.x, q.y) > Lake.LEVEL:
			edge = q; break
	var out := -toward           # direction into the lake
	var yaw := atan2(-out.x, -out.y)        # the jetty runs along -z in its own frame
	print("gallery5: shore at ", edge, " into the lake along ", out, " yaw ", rad_to_deg(yaw))
	var lvl := Lake.LEVEL
	# the jetty starts on the land and runs out 8 m
	_put(parent, terrain, "jetty_a", edge.x, edge.y, yaw, 0.0, 0, lvl)
	var side := Vector2(-out.y, out.x)
	for i in 5:
		var d := 14.0 + i * 7.0
		var s := (-1.0 if i % 2 == 0 else 1.0) * (6.0 + i * 1.5)
		var p := edge + out * d + side * s
		var nm: String = ["rowboat_a", "sailboat_a", "sailboat_b", "fishing_boat_a", "buoy_a"][i]
		_put(parent, terrain, nm, p.x, p.y, yaw + 0.5 * i, 0.0, 0, lvl)
	var mp := edge - out * 1.5 + side * 2.0
	_put(parent, terrain, "mooring_post_a", mp.x, mp.y, yaw, 0.0, 0)

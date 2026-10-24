extends SceneTree
## Headless check of the Blender drones (lane/drones, game/drone_assets.gd, assets/models/drones/):
## every file and level of detail loads, carries its named nodes, has a material on every surface, sits on its base with the
## nose towards +Z, stays inside its triangle budget (falling from near to far), its props are on the motors and twist the
## right way for the way DroneView spins them, its lamps glow, the manifest agrees with the file, and DroneView builds the
## Facade drones from these files (four spinning props, blur discs, FPV hiding) while the other airframes keep their code models.
## Godot --headless --path <godot dir> -s res://test/drones_blender_test.gd
var fails := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", what)

func _walk(n: Node, out: Dictionary) -> void:
	out[String(n.name)] = n
	for c in n.get_children(): _walk(c, out)

## World-space (model frame) vertices of every mesh under n.
func _verts(n: Node, xf: Transform3D, out: PackedVector3Array) -> void:
	var t := xf
	if n is Node3D: t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var m := (n as MeshInstance3D).mesh
		for s in m.get_surface_count():
			for v in (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array): out.append(t * v)
	for c in n.get_children(): _verts(c, t, out)

const BUDGET := {
	"raptor_race_a": [22000, 9000, 6000],
	"nightowl_a": [24000, 11000, 7500],
	"night_vision_pod_a": [2500, 1000, 600],
}
const NODES := {
	"raptor_race_a": ["body", "battery", "prop_fr", "prop_rr", "prop_rl", "prop_fl", "camera_fpv", "camera_lens", "action_cam", "action_cam_lens",
		"action_cam_led", "status_led", "led_fr", "led_rr", "led_rl", "led_fl"],
	"nightowl_a": ["body", "battery", "prop_fr", "prop_rr", "prop_rl", "prop_fl", "gimbal_yaw", "gimbal_roll", "gimbal_pitch", "camera_lens",
		"nv_pod", "nv_lens", "nv_led", "landing_light", "status_led", "led_fr", "led_rr", "led_rl", "led_fl"],
	"night_vision_pod_a": ["body", "camera_lens", "status_led"],
}

func _initialize() -> void:
	Grass.add_globals()
	for name in DroneAssets.NAMES:
		var prev := 1 << 30
		var man := DroneAssets.manifest(name)
		check(not man.is_empty(), name + " has a manifest")
		for lod in 3:
			check(DroneAssets.has_file(name, lod), "%s lod%d file" % [name, lod])
			var inst := DroneAssets.instance(name, lod)
			var nodes := {}
			_walk(inst, nodes)
			for nn in NODES[name]:
				if lod == 0 or not nn.ends_with("_ir"):
					check(nodes.has(nn), "%s lod%d has node %s" % [name, lod, nn])
			var tris := DroneAssets.triangles(inst)
			check(tris > 0 and tris <= int(BUDGET[name][lod]), "%s lod%d triangles %d within %d" % [name, lod, tris, BUDGET[name][lod]])
			check(tris < prev, "%s lod%d lighter than the level before" % [name, lod])
			prev = tris
			var unmat := 0
			var lamps := 0
			var textured := 0
			for k in nodes:
				var mi := nodes[k] as MeshInstance3D
				if mi == null or mi.mesh == null: continue
				for s in mi.mesh.get_surface_count():
					var m := mi.get_surface_override_material(s)
					if m == null: m = mi.mesh.surface_get_material(s)
					if m == null: unmat += 1
					elif m is BaseMaterial3D and (m as BaseMaterial3D).normal_texture != null and (m as BaseMaterial3D).roughness_texture != null: textured += 1
					elif m is BaseMaterial3D and (m as BaseMaterial3D).emission_enabled and (m as BaseMaterial3D).emission_energy_multiplier > 1.0: lamps += 1
			check(unmat == 0, "%s lod%d every surface has a material (%d without)" % [name, lod, unmat])
			check(textured >= (2 if name == "night_vision_pod_a" else 4), "%s lod%d shared textures are back on (%d textured materials)" % [name, lod, textured])
			check(lamps >= (1 if name == "night_vision_pod_a" else 5), "%s lod%d lamps glow (%d)" % [name, lod, lamps])
			var vs := PackedVector3Array()
			_verts(inst, Transform3D.IDENTITY, vs)
			var lo := Vector3(INF, INF, INF); var hi := -lo
			for v in vs: lo = lo.min(v); hi = hi.max(v)
			if lod == 0: print(name, " size ", (hi - lo).snappedf(0.001), " min ", lo.snappedf(0.001), " max ", hi.snappedf(0.001), " triangles ", tris)
			if name == "night_vision_pod_a":
				check(absf(hi.y) < 0.002 and lo.y < -0.03 and lo.y > -0.045, "pod hangs under its mounting face (top y %.4f, bottom %.4f)" % [hi.y, lo.y])
				check((hi - lo).x < 0.05 and (hi - lo).z < 0.065, "pod is component sized %s" % str(hi - lo))
			else:
				check(absf(lo.y) < 0.001, "%s lod%d base on y 0 (lowest %.4f)" % [name, lod, lo.y])
				var cam := _pos(nodes["camera_lens"])
				check(cam.z > 0.04, "%s lod%d nose (camera lens) towards +Z (z %.3f)" % [name, lod, cam.z])
				# props: over the motors at +-0.08, spinning the right way
				for pn in DroneAssets.PROPS:
					var pp := _pos(nodes[pn])
					var c := String(pn).substr(5)
					var want := Vector2(-0.08 if c.ends_with("r") else 0.08, 0.08 if c.begins_with("f") else -0.08)    # story frame: right is -x
					check(Vector2(pp.x, pp.z).distance_to(want) < 0.002, "%s %s over its motor (%s)" % [name, pn, str(pp)])
					if lod < 2:
						var slope := _twist(nodes[pn], int(man["prop_blades"]))
						var spin: int = DroneAssets.SPIN[pn]
						check(signf(slope) == float(spin), "%s lod%d %s twists for spin %d (slope %.3f)" % [name, lod, pn, spin, slope])
				if lod == 0:
					var r := float(man["prop_radius"])
					var span := 0.0
					for v in vs: span = maxf(span, absf(v.x))
					check(absf(span - (0.08 + r)) < 0.004, "%s tip to tip %.3f (motor 0.08 + prop %.4f)" % [name, span, r])
			inst.free()
	# DroneView: the Facade airframes build from the files; the others keep the code models
	for id in ["raptor", "nightowl"]:
		var af := Airframes.make("race" if id == "raptor" else "mini")
		af = af.duplicate(true)
		af["id"] = id
		var md := DroneView.model(af)
		check(md.has("glb") and md["glb"] == DroneAssets.model_for(id), id + " uses its Blender model")
		check((md["plan"] as Array).size() > 10 and (md["side"] as Array).size() > 10, id + " has drawing outlines")
		var v := DroneView.new()
		root.add_child(v)
		v.build(af)
		var props := 0
		var discs := 0
		for c in v.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh is CylinderMesh: discs += 1
		var nodes := {}
		_walk(v, nodes)
		for pn in DroneAssets.PROPS:
			if nodes.has(pn): props += 1
		check(props == 4 and discs == 4, "%s DroneView has 4 props (%d) and 4 blur discs (%d)" % [id, props, discs])
		# the props are where the model data says, in the body frame (forward -z, right +x)
		var p0 := _pos(nodes["prop_fr"], v)
		check(p0.x > 0.07 and p0.z < -0.07, "%s front-right prop is at +x, -z in the body frame (%s)" % [id, str(p0)])
		v.set_fpv(true)
		var hidden: String = DroneAssets.FPV_HIDE[DroneAssets.model_for(id)][0]
		check(not (nodes[hidden] as Node3D).visible, "%s hides %s in FPV" % [id, hidden])
		v.set_fpv(false)
		var st := PackedFloat64Array(); st.resize(17)
		for i in 4: st[13 + i] = 20.0
		v.update_props(st, 1.0, true)
		v.update_props(st, 1.2, true)
		check(absf((nodes["prop_rr"] as Node3D).rotation.y) > 0.01, id + " props turn")
		v.queue_free()
	var mini := DroneView.model(Airframes.make("mini"))
	check(not mini.has("glb"), "the Gimbal Mini keeps its own code model")
	var race := DroneView.model(Airframes.make("race"))
	check(not race.has("glb"), "the Race quad keeps its own code model")
	print("drones blender test: ", fails, " failures")
	print("RESULT: PASS" if fails == 0 else "RESULT: FAIL")
	quit(0 if fails == 0 else 1)

## A node's position in its model's frame (sum of the local offsets up to the model root).
func _pos(n: Node, top: Node = null) -> Vector3:
	var p := Vector3.ZERO
	var q := n
	while q != null and q is Node3D and q != top:
		p = (q as Node3D).transform * p
		q = q.get_parent()
	return p

## Twist of a prop: regress the height of its blade points on how far ahead they sit in the anticlockwise direction
## (seen from above) from the middle line of their blade. Folding the angle by the blade count puts every blade on one.
## Positive: the edge that leads when turning anticlockwise is the high one, so the prop lifts turning anticlockwise.
func _twist(n: Node, blades: int) -> float:
	var vs := PackedVector3Array()
	_verts(n, (n as Node3D).transform.affine_inverse(), vs)      # in the prop's own frame, the hub at the origin
	var pts: Array = []
	var cx := 0.0; var cy := 0.0
	for v in vs:
		var rr := Vector2(v.x, v.z).length()
		if rr < 0.02: continue
		var phi := atan2(-v.z, v.x)               # grows anticlockwise seen from above
		var psi := fposmod(phi * blades, TAU)
		cx += cos(psi); cy += sin(psi)
		pts.append([psi, rr, v.y])
	if pts.size() < 4: return 0.0
	var psi0 := atan2(cy, cx)
	var sx := 0.0; var sy := 0.0; var sxx := 0.0; var sxy := 0.0; var k := 0
	for q in pts:
		var d := wrapf(float(q[0]) - psi0, -PI, PI) / blades * float(q[1])     # metres ahead of the blade's middle line
		sx += d; sy += float(q[2]); sxx += d * d; sxy += d * float(q[2]); k += 1
	return (k * sxy - sx * sy) / maxf(k * sxx - sx * sx, 1e-12)

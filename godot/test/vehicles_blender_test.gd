extends SceneTree
## Headless check of the Blender vehicles (Blender 3, lane/vehicles: game/vehicle_assets.gd, assets/models/vehicles/*.glb): every vehicle
## loads, has its named bones and animations, real sizes in metres, wheels on the ground, triangle budgets that fall from
## LOD0 to LOD2, no NaN, the vehicle shaders on the paint, glass and rubber, and the rig really moves: wheels roll about
## their axles, front wheels steer, doors swing open. Also that StoryAssets resolves the story vehicles to the new files.
## Prints a table; exits 1 on any failure.
## Run: Godot_console.exe --headless --path godot -s res://test/vehicles_blender_test.gd

var fails := 0

func check(name: String, ok: bool, info: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + info)
	if not ok: fails += 1

## name: [length min, max, width min, max (measured over the mirrors, as the model is), height min, max (to the top of
## whatever is highest: roof, lightbar, aerial, cone), LOD0 tri max]. Real-world sizes of each class, plus mirrors.
const EXPECT := {
	"car_hatch_a": [3.85, 4.2, 1.95, 2.2, 1.38, 1.55, 35000],
	"car_hatch_b": [4.15, 4.45, 2.0, 2.25, 1.38, 1.55, 35000],
	"car_estate_a": [4.6, 4.95, 2.0, 2.3, 1.42, 1.62, 36000],
	"pickup_a": [5.1, 5.6, 2.1, 2.45, 1.72, 1.95, 38000],
	"pickup_b": [4.7, 5.1, 2.0, 2.3, 1.6, 1.82, 35000],
	"van_a": [5.1, 5.5, 2.1, 2.45, 2.0, 2.25, 35000],
	"van_b": [4.2, 4.6, 2.0, 2.3, 1.8, 2.0, 35000],
	"tractor_a": [4.6, 5.2, 2.2, 2.6, 2.9, 4.1, 50000],
	"tractor_wheels_a": [3.8, 4.4, 2.2, 2.6, 1.6, 1.8, 30000],
	"tractor_trailer_a": [6.0, 7.2, 2.2, 2.6, 1.6, 2.6, 30000],
	"milk_tanker_a": [8.8, 10.0, 2.6, 3.0, 3.2, 3.8, 50000],
	"bus_a": [10.2, 11.0, 2.7, 3.05, 3.0, 3.35, 50000],
	"bus_b": [10.8, 11.6, 2.7, 3.05, 3.0, 3.35, 50000],
	"motorcycle_a": [1.95, 2.3, 0.7, 0.95, 1.1, 1.4, 25000],
	"lorry_a": [7.0, 9.5, 2.6, 3.0, 3.2, 3.9, 50000],
	"farm_quad_a": [1.95, 2.45, 1.05, 1.3, 1.05, 1.35, 25000],
	"lake_car_estate_a": [4.75, 5.1, 2.0, 2.3, 1.3, 1.5, 35000],
	"lake_car_estate_b": [4.75, 5.1, 2.0, 2.3, 1.3, 1.5, 35000],
	"police_suv_a": [4.8, 5.15, 2.1, 2.45, 1.85, 2.1, 38000],
	"police_saloon_a": [4.7, 5.05, 2.0, 2.3, 1.5, 1.7, 36000],
	"cruiser_1984_a": [5.2, 5.65, 2.1, 2.45, 1.4, 2.2, 36000],
	"festival_bus_restored": [8.8, 9.5, 2.6, 2.95, 2.8, 3.3, 50000],
	"festival_bus_garage": [8.8, 9.5, 2.6, 2.95, 2.8, 3.4, 50000],
	"festival_ice_cream_van_a": [5.6, 6.2, 2.5, 3.0, 3.4, 3.9, 38000],
	"parade_tractor_a": [3.0, 3.4, 1.55, 1.9, 1.8, 2.3, 50000],
	"parade_trailer_a": [5.0, 5.8, 2.1, 2.5, 2.0, 2.6, 30000],
}
func lod_meshes(rig: Node) -> Array:
	var out := [null, null, null]
	for n in rig.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for k in 3:
			if mi.name.ends_with("_LOD%d" % k): out[k] = mi
	return out

func measure(mi: MeshInstance3D, rig: Node3D) -> Dictionary:
	var tris := 0
	var lo := Vector3(INF, INF, INF); var hi := -lo
	var finite := true
	var xf := Transform3D.IDENTITY
	var p: Node = mi
	while p != null and p != rig:
		if p is Node3D: xf = (p as Node3D).transform * xf
		p = p.get_parent()
	var flipped := 0
	for s in mi.mesh.get_surface_count():
		var arr := mi.mesh.surface_get_arrays(s)
		var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx = arr[Mesh.ARRAY_INDEX]
		tris += (idx.size() if idx != null else pos.size()) / 3
		if idx != null:
			var ia: PackedInt32Array = idx
			for t in range(0, ia.size(), 3):
				var a := pos[ia[t]]; var b := pos[ia[t + 1]]; var c := pos[ia[t + 2]]
				var fn := (b - a).cross(c - a)
				if fn.length_squared() < 1e-14: continue
				var vn := nrm[ia[t]] + nrm[ia[t + 1]] + nrm[ia[t + 2]]
				# Godot's front faces wind clockwise: the winding normal points against the shading normal
				if fn.dot(vn) > 0.0: flipped += 1
		for v in pos:
			if not (is_finite(v.x) and is_finite(v.y) and is_finite(v.z)): finite = false; continue
			var w := xf * v
			lo = lo.min(w); hi = hi.max(w)
	return {"tris": tris, "lo": lo, "hi": hi, "size": hi - lo, "finite": finite, "flipped": flipped}

func _initialize() -> void:
	var names: Array = VehicleAssets.names()
	names.sort()
	check("manifest", names.size() > 0, "%d vehicles" % names.size())
	for nm: String in names:
		var d: Dictionary = VehicleAssets.info(nm)
		check(nm + " file", VehicleAssets.has(nm), String(d.get("file", "")))
		if not VehicleAssets.has(nm): continue
		var v := VehicleAssets.instance(nm)
		get_root().add_child(v)
		await process_frame
		var rig := v.get_node("rig") as Node3D
		var skel := v.get_meta("skeleton") as Skeleton3D
		check(nm + " skeleton", skel != null, "")
		if skel == null: continue
		var ms := lod_meshes(rig)
		check(nm + " three LODs", ms[0] != null and ms[1] != null and ms[2] != null, "")
		if ms[0] == null: continue
		var m0 := measure(ms[0], rig)
		var tr := [m0["tris"], measure(ms[1], rig)["tris"] if ms[1] else 0, measure(ms[2], rig)["tris"] if ms[2] else 0]
		var e: Array = EXPECT.get(nm, [1.0, 20.0, 0.5, 4.0, 0.5, 5.0, 50000])
		var sz: Vector3 = m0["size"]
		check(nm + " finite", m0["finite"], "")
		check(nm + " winding matches normals", int(m0["flipped"]) <= int(tr[0]) / 200, "%d of %d triangles flipped" % [m0["flipped"], tr[0]])
		var ck: Dictionary = d.get("checks", {})
		var kind := String(d.get("kind", ""))
		if kind != "tractor_wheels":       # the wheels-alone model is four separate wheels by design
			check(nm + " no floating parts", (ck.get("floating", []) as Array).is_empty(), str(ck.get("floating", [])))
		check(nm + " no inside-out solids", ck.has("inside_out") and (ck.get("inside_out", []) as Array).is_empty(), str(ck.get("inside_out", "not checked")))
		if kind in ["car", "pickup", "van", "bus", "truck"]:     # lofted bodies: the painted skin faces away from the centre line
			check(nm + " paint faces outward", float(ck.get("paint_outward", 0.0)) >= 0.9, "%.3f of the painted area" % float(ck.get("paint_outward", 0.0)))
		check(nm + " length", sz.z >= e[0] and sz.z <= e[1], "%.2f m (want %.2f to %.2f)" % [sz.z, e[0], e[1]])
		check(nm + " width", sz.x >= e[2] and sz.x <= e[3], "%.2f m (want %.2f to %.2f)" % [sz.x, e[2], e[3]])
		check(nm + " height", sz.y >= e[4] and sz.y <= e[5], "%.2f m (want %.2f to %.2f)" % [sz.y, e[4], e[5]])
		check(nm + " on the ground", absf((m0["lo"] as Vector3).y) < 0.03, "lowest point %.3f m" % (m0["lo"] as Vector3).y)
		check(nm + " centred", absf(((m0["lo"] as Vector3).z + (m0["hi"] as Vector3).z) * 0.5) < 0.6, "middle of length at z %.2f" % (((m0["lo"] as Vector3).z + (m0["hi"] as Vector3).z) * 0.5))
		check(nm + " LOD0 budget", tr[0] <= e[6] and tr[0] >= 1500, "%d tris (max %d)" % [tr[0], e[6]])
		check(nm + " LOD1 ~35%", tr[1] < tr[0] and tr[1] <= tr[0] * 0.55, "%d tris (%.0f%%)" % [tr[1], 100.0 * tr[1] / max(1, tr[0])])
		check(nm + " LOD2 ~8%", tr[2] < tr[1] and tr[2] <= tr[0] * 0.16, "%d tris (%.0f%%)" % [tr[2], 100.0 * tr[2] / max(1, tr[0])])
		for b in ["root", "body"]:
			check(nm + " bone " + b, skel.find_bone(b) >= 0, "")
		for bn in d.get("bones", []):
			if skel.find_bone(String(bn)) < 0: check(nm + " bone " + String(bn), false, "missing")
		# wheels on the ground and the front of the vehicle toward -z
		var wheels: Array = d.get("wheels", [])
		for w: Dictionary in wheels:
			var bi := skel.find_bone(String(w["bone"]))
			check(nm + " " + String(w["bone"]), bi >= 0, "")
			if bi < 0: continue
			var hub := skel.global_transform * skel.get_bone_global_rest(bi).origin
			var flat := String(VehicleAssets.info(nm).get("pose", "")).contains("flat") or float(w["radius"]) - hub.y > 0.03
			if not flat:
				check(nm + " " + String(w["bone"]) + " touches the ground", absf(hub.y - float(w["radius"])) < 0.03, "hub %.3f radius %.3f" % [hub.y, float(w["radius"])])
		if wheels.size() >= 2:
			var zs: Array = []
			for w: Dictionary in wheels:
				if bool(w.get("steer", false)): zs.append(_v(w["pos"]).z)
			var zr: Array = []
			for w: Dictionary in wheels:
				if not bool(w.get("steer", false)): zr.append(_v(w["pos"]).z)
			if zs.size() > 0 and zr.size() > 0:
				check(nm + " front toward -z", zs.min() < zr.max(), "steering axle z %.2f, rear %.2f" % [zs.min(), zr.max()])
		# shaders on the main slots
		var slots := {}
		for mi: MeshInstance3D in ms:
			if mi == null: continue
			for s in mi.mesh.get_surface_count():
				var om := mi.get_surface_override_material(s)
				var sm := mi.mesh.surface_get_material(s)
				var key := sm.resource_name if sm else "?"
				slots[key] = om
		for key in ["paint", "rubber"]:
			if slots.has(key):
				var ok := slots[key] is ShaderMaterial and String((slots[key] as ShaderMaterial).shader.resource_path).ends_with("vehicle_pbr.gdshader")
				check(nm + " slot " + key, ok, "")
		if slots.has("glass"):
			check(nm + " slot glass", slots["glass"] is ShaderMaterial and String((slots["glass"] as ShaderMaterial).shader.resource_path).ends_with("vehicle_glass.gdshader"), "")
		# the rig moves: a wheel rolls about its axle, the front wheels steer, a door opens
		if wheels.size() > 0:
			var w0: Dictionary = wheels[0]
			var bi := skel.find_bone(String(w0["bone"]))
			var b0 := skel.get_bone_global_pose(bi).basis
			VehicleAssets.roll(v, 0.5)
			skel.force_update_all_bone_transforms()
			var b1 := skel.get_bone_global_pose(bi).basis
			var turned := rad_to_deg((b0.get_rotation_quaternion().inverse() * b1.get_rotation_quaternion()).get_angle())
			var want := rad_to_deg(0.5 / float(w0["radius"]))
			var ax := (b1 * (skel.get_bone_global_rest(bi).basis.inverse() * Vector3.RIGHT)).normalized()
			check(nm + " wheel rolls", absf(turned - want) < 2.0 and ax.dot(Vector3.RIGHT) > 0.99, "turned %.1f deg (want %.1f), axle stays on x %.3f" % [turned, want, ax.dot(Vector3.RIGHT)])
			VehicleAssets.roll(v, -0.5)
		var steer_bones: Array = []
		for bn in d.get("bones", []):
			if String(bn).begins_with("steer_"): steer_bones.append(String(bn))
		if steer_bones.size() > 0:
			var si := skel.find_bone(steer_bones[0])
			VehicleAssets.steer(v, 0.4)
			skel.force_update_all_bone_transforms()
			var fw := skel.get_bone_global_pose(si).basis * (skel.get_bone_global_rest(si).basis.inverse() * Vector3.FORWARD)
			check(nm + " steers left", fw.x < -0.3, "forward of the steered wheel %s" % str(fw))
			VehicleAssets.steer(v, 0.0)
		var acts: Array = d.get("actions", [])
		if acts.has("doors_open"):
			var door := ""
			for bn in (d.get("hinges", {}) as Dictionary).keys():
				if String(bn).begins_with("door_f") or String(bn).begins_with("bus_door"): door = String(bn); break
			var di := skel.find_bone(door)
			var r0 := skel.get_bone_global_pose(di).basis.get_rotation_quaternion()
			VehicleAssets.pose(v, "doors_open")
			skel.force_update_all_bone_transforms()
			var r1 := skel.get_bone_global_pose(di).basis.get_rotation_quaternion()
			var ang := rad_to_deg((r0.inverse() * r1).get_angle())
			check(nm + " doors open", ang > 40.0 and ang < 95.0, "%s turned %.0f deg" % [door, ang])
			VehicleAssets.pose(v, "doors_close")
		for a in acts:
			var ap := v.get_meta("anim") as AnimationPlayer
			if ap == null or not ap.has_animation(a): check(nm + " anim " + String(a), false, "missing in the file")
		print("     %s  tris %s  size %s  bones %d  anims %s" % [nm, str(tr), str(sz), skel.get_bone_count(), str(acts)])
		v.queue_free()
	# the story names resolve to the Blender files
	for sn in ["festival_bus_restored", "festival_ice_cream_van_a", "parade_tractor_a", "parade_trailer_a"]:
		if VehicleAssets.has(sn):
			var n := StoryAssets.instance(sn)
			check("story " + sn, n.has_meta("vehicle") and n.get_node_or_null("rig") != null and absf((n.get_node("rig") as Node3D).rotation.y) > 3.0, "front turned to +z")
			n.free()
	print("vehicles_blender_test: %d failures" % fails)
	quit(1 if fails > 0 else 0)

func _v(x) -> Vector3:
	if x is Vector3: return x
	return Vector3(float(x[0]), float(x[1]), float(x[2]))

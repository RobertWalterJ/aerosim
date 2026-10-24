extends SceneTree
## Headless: loads every exported story asset of a group through StoryAssets (the .glb written by tools/export_story.gd, with the kit materials swapped
## back in) and checks it has a body mesh with triangles, the named sub-nodes the code builds, and a material on every surface.
## Godot --headless --path <godot dir> -s res://test/story_load_test.gd -- group=storm [lod=0]
func _initialize() -> void:
	Grass.add_globals()
	var group := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("group="): group = a.substr(6)
	var fails := 0
	var n := 0
	for nm in NewModels6.names():
		if group != "" and NewModels6.group_of(nm) != group: continue
		var path := StoryAssets.path_of(nm, 0)
		if not ResourceLoader.exists(path):
			print("FAIL ", nm, " no file ", path)
			fails += 1
			continue
		var inst := StoryAssets.instance(nm, 0)
		var md := NewModels6.build(nm, 0)
		var tris := 0
		var meshes := 0
		var unmat := 0
		var names_found := {}
		var stack: Array = [inst]
		while not stack.is_empty():
			var c: Node = stack.pop_back()
			names_found[String(c.name)] = true
			if c is MeshInstance3D and (c as MeshInstance3D).mesh != null and not String(c.name).ends_with("-colonly"):
				meshes += 1
				var m := (c as MeshInstance3D).mesh
				for s in m.get_surface_count():
					tris += (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
					if m.surface_get_material(s) == null and (c as MeshInstance3D).get_surface_override_material(s) == null: unmat += 1
			for ch in c.get_children(): stack.append(ch)
		var missing: Array = []
		for sn in md.subs:
			if not names_found.has(String(sn)): missing.append(sn)
		var bad := tris == 0 or unmat > 0 or not missing.is_empty()
		if bad:
			print("FAIL ", nm, " tris=", tris, " unmaterialled=", unmat, " missing nodes=", missing)
			fails += 1
		n += 1
		inst.free()
	print("story load test: ", n, " assets, ", fails, " failures")
	print("RESULT: PASS" if fails == 0 else "RESULT: FAIL")
	quit(0 if fails == 0 else 1)

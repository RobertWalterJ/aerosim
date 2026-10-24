extends SceneTree
## Writes the story batch (game/new_models6.gd and its group files) as glTF 2.0 binaries under assets/models/story/<group>/.
## Run: Godot --headless --path <godot dir> -s res://tools/export_story.gd -- [only=<name prefix>]
## Needs the global shader parameters registered because the group builders load the farm materials.

func _initialize() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="): only = a.substr(5)
	Grass.add_globals()
	var n := 0
	for nm in NewModels6.names():
		if only != "" and not nm.begins_with(only): continue
		var lods := [0] if not NewModels6.LODS.has(nm) else [0, 1, 2]
		for lod in lods:
			var root := NewModels6.scene(nm, lod, true)
			var doc := GLTFDocument.new()
			var st := GLTFState.new()
			var err := doc.append_from_scene(root, st)
			if err != OK:
				push_error("export failed for %s: %d" % [nm, err])
				continue
			var dir := "res://assets/models/story/%s" % NewModels6.group_of(nm)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
			var path := "%s/%s%s.glb" % [dir, nm, "" if lod == 0 else "_lod%d" % lod]
			err = doc.write_to_filesystem(st, path)
			print("%s %s" % ["OK  " if err == OK else "FAIL", path])
			root.free()
			n += 1
	if only == "" or only.begins_with("livery") or only.begins_with("casebook") or only.begins_with("crop"):
		for d in NewModels6Evid.DECALS:
			var dir2 := ProjectSettings.globalize_path("res://assets/models/story/reward")
			DirAccess.make_dir_recursive_absolute(dir2)
			var err2 := NewModels6Evid.decal(d).save_png("%s/%s.png" % [dir2, d])
			print("%s %s/%s.png" % ["OK  " if err2 == OK else "FAIL", dir2, d])
		for d in NewModels6Later.DECALS:
			var dir3 := ProjectSettings.globalize_path("res://assets/models/story/cases")
			DirAccess.make_dir_recursive_absolute(dir3)
			var err3 := NewModels6Later.decal(d).save_png("%s/%s.png" % [dir3, d])
			print("%s %s/%s.png" % ["OK  " if err3 == OK else "FAIL", dir3, d])
	print("exported ", n)
	quit()

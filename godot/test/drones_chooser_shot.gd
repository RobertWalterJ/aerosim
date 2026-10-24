extends SceneTree
## What the drone chooser would show for the Facade drones once their airframes exist (lane/notify adds `raptor` and
## `nightowl` to physics/airframes.gd): the DroneThumbs picture and the DroneSchematic drawing, both built from the
## Blender files through DroneView.model(). Needs a window and those airframe ids:
## Godot --path <godot dir> --resolution 1280x720 -s res://test/drones_chooser_shot.gd -- out=<png> [ids=raptor,nightowl]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := "user://drones_chooser.png"
	var ids: Array = ["raptor", "nightowl"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
		if a.begins_with("ids="): ids = Array(a.substr(4).split(","))
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720); vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	var bg := ColorRect.new(); bg.color = DroneSchematic.SHEET; bg.size = Vector2(1280, 720); vp.add_child(bg)
	var thumbs: Dictionary = await DroneThumbs.render_all(vp, ids)
	for i in ids.size():
		var id: String = ids[i]
		var x := 20 + i * 630
		var tr := TextureRect.new(); tr.texture = thumbs[id]; tr.position = Vector2(x, 20); vp.add_child(tr)
		var sc := DroneSchematic.new(); sc.id = id; sc.position = Vector2(x, 230); sc.size = Vector2(600, 470); vp.add_child(sc)
		var lab := Label.new(); lab.text = "%s  (model %s)" % [Airframes.make(id)["name"], DroneAssets.model_for(id)]
		lab.position = Vector2(x + 340, 30); lab.add_theme_font_size_override("font_size", 20); vp.add_child(lab)
	for k in 6: await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var err := img.save_png(out)
	print("chooser shot: ", out, " ", error_string(err))
	quit()

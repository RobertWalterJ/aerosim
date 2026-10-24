extends SceneTree
## Contact sheet of the story models (game/new_models6.gd): each name from three views on a plain field, in a low golden-hour
## sun or an overcast sky. Needs a window (not headless):
## Godot --path <godot dir> --resolution 480x270 -s res://test/story_sheet.gd -- names=a,b,c [group=<characters|camp|...>] [light=golden|overcast] [out=<jpg>] [lod=0] [tag=<word>]

const CELL := Vector2i(520, 390)
const COLS := 3
var _out := ""
var _light := "golden"
var _names: Array[String] = []
var _lod := 0
var _tag := "sheet"

func _initialize() -> void:
	var group := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
		if a.begins_with("light="): _light = a.substr(6)
		if a.begins_with("lod="): _lod = int(a.substr(4))
		if a.begins_with("tag="): _tag = a.substr(4)
		if a.begins_with("group="): group = a.substr(6)
		if a.begins_with("names="):
			for n in a.substr(6).split(","): _names.append(n)
	if group != "":
		for n in NewModels6.names():
			if NewModels6.group_of(n) == group: _names.append(n)
	if _out == "": _out = "res://docs/realism/models/story_%s_%s.jpg" % [_tag, _light]
	Grass.add_globals()
	RenderingServer.global_shader_parameter_add("g_csun", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.0, 0.0, 0.0, 0.0))
	RenderingServer.global_shader_parameter_set("g_cloud", Vector4(0.0, 0.0, 0.0, 0.0))
	RenderingServer.global_shader_parameter_set("g_dsB", Vector4(0.0, 0.0, 1.0, 1.0))
	RenderingServer.global_shader_parameter_set("g_wind", Vector3(2.0, 0.0, 0.6))
	RenderingServer.global_shader_parameter_set("g_time", 3.0)
	_run.call_deferred()

func _entries() -> Array:
	var out: Array = []
	for nm in _names:
		var views := [[Vector3(-0.75, 0.35, 1.0), ""], [Vector3(-1.0, 0.1, 0.0), ""], [Vector3(0.7, 0.4, -1.0), ""]]
		out.append([nm, views])
	return out

func _run() -> void:
	var entries := _entries()
	var rows := int(ceil(entries.size() * 3.0 / COLS))
	var sheet := Image.create(CELL.x * COLS, CELL.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.5, 0.55, 0.6))
	var vp := SubViewport.new()
	vp.size = CELL; vp.own_world_3d = true; vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	var sky := ProceduralSkyMaterial.new()
	var key := DirectionalLight3D.new()
	if _light == "golden":
		sky.sky_top_color = Color(0.30, 0.42, 0.65); sky.sky_horizon_color = Color(0.95, 0.68, 0.48)
		sky.ground_horizon_color = Color(0.55, 0.42, 0.33); sky.ground_bottom_color = Color(0.2, 0.17, 0.15)
		key.light_energy = 2.6; key.light_color = Color(1.0, 0.72, 0.46); key.rotation_degrees = Vector3(-13, -38, 0)
		env.ambient_light_energy = 0.8
	else:
		sky.sky_top_color = Color(0.58, 0.62, 0.68); sky.sky_horizon_color = Color(0.72, 0.75, 0.78)
		sky.ground_horizon_color = Color(0.5, 0.5, 0.48); sky.ground_bottom_color = Color(0.3, 0.3, 0.28)
		key.light_energy = 0.0; key.rotation_degrees = Vector3(-60, -38, 0)
		env.ambient_light_energy = 1.1
	var skyres := Sky.new(); skyres.sky_material = sky
	env.background_mode = Environment.BG_SKY; env.sky = skyres
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new(); we.environment = env; vp.add_child(we)
	key.shadow_enabled = _light == "golden"
	vp.add_child(key)
	# a field to stand them in: dull green-brown with a little darker mottle, big enough to fill the frame
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(80, 80)
	ground.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.20, 0.23, 0.10); gm.roughness = 1.0
	ground.material_override = gm
	ground.position = Vector3(0, -0.01, 0)
	vp.add_child(ground)
	var cam := Camera3D.new(); cam.fov = 30.0; cam.current = true
	vp.add_child(cam)
	var holder := Node3D.new(); vp.add_child(holder)
	var labels: Array = []
	var cell := 0
	for e in entries:
		for c in e[1]:
			for ch in holder.get_children(): ch.free()
			var inst := NewModels6.scene(e[0], _lod, false)
			holder.add_child(inst)
			var box := AABB()
			var first := true
			for ch in inst.get_children():
				if not (ch is MeshInstance3D) or (ch as Node).name.ends_with("-colonly"): continue
				var bb2: AABB = (ch as MeshInstance3D).transform * (ch as MeshInstance3D).mesh.get_aabb()
				box = bb2 if first else box.merge(bb2)
				first = false
			var centre := box.get_center()
			var radius := box.size.length() * 0.5
			var dir: Vector3 = (c[0] as Vector3).normalized()
			var dist := radius / sin(deg_to_rad(cam.fov * 0.5)) * 0.95
			cam.position = centre + dir * dist
			cam.near = dist * 0.01; cam.far = dist * 6.0
			cam.look_at(centre, Vector3.UP if absf(dir.y) < 0.95 else Vector3(0, 0, -1))
			key.directional_shadow_max_distance = dist * 2.5
			for i in 5: await process_frame
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			var at := Vector2i((cell % COLS) * CELL.x, (cell / COLS) * CELL.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), at)
			labels.append([at, e[0] if c == e[1][0] else ""])
			cell += 1
	vp.queue_free()
	var v2 := SubViewport.new()
	v2.size = sheet.get_size(); v2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(v2)
	var tr := TextureRect.new(); tr.texture = ImageTexture.create_from_image(sheet); v2.add_child(tr)
	for l in labels:
		var at2: Vector2i = l[0]
		var line := ColorRect.new(); line.color = Color(1, 1, 1, 0.5); line.position = Vector2(at2.x, at2.y); line.size = Vector2(1, CELL.y); v2.add_child(line)
		if l[1] == "": continue
		var lab := Label.new(); lab.text = l[1]; lab.position = Vector2(at2.x + 8, at2.y + 6)
		lab.add_theme_font_size_override("font_size", 18); lab.add_theme_color_override("font_color", Color(1, 1, 1))
		lab.add_theme_color_override("font_outline_color", Color(0, 0, 0)); lab.add_theme_constant_override("outline_size", 5)
		v2.add_child(lab)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var final := v2.get_texture().get_image()
	var path := ProjectSettings.globalize_path(_out) if _out.begins_with("res://") else _out
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := final.save_jpg(path, 0.88)
	print("contact sheet: %s (%s)" % [path, error_string(err)])
	quit()

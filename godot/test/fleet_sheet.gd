extends SceneTree
## The vehicle brief's fleet together at real scale (lane/sites): every file in assets/traffic/manifest.json loaded RAW, the
## way traffic.gd loads it (load + instantiate, the imported materials as they are), parked side by side on gravel with a
## 1.8 m figure post for scale, from the front three-quarter and from above; then a dusk shot with the headlights raised the
## way traffic.gd does (emission_energy_multiplier on the materials named `headlight`).
## Needs a window: Godot --path <godot dir> --resolution 640x360 -s res://test/fleet_sheet.gd -- [out=<jpg>]

var _out := "res://docs/realism/models/sites_fleet.jpg"
const W := 1600
const H := 520

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
	_run.call_deferred()

func _env(vp: SubViewport, dusk: bool) -> DirectionalLight3D:
	var env := Environment.new()
	var sky := ProceduralSkyMaterial.new()
	var key := DirectionalLight3D.new()
	if dusk:
		sky.sky_top_color = Color(0.05, 0.07, 0.14); sky.sky_horizon_color = Color(0.35, 0.25, 0.25)
		sky.ground_horizon_color = Color(0.1, 0.09, 0.08); sky.ground_bottom_color = Color(0.03, 0.03, 0.03)
		key.light_energy = 0.15; key.rotation_degrees = Vector3(-6, -120, 0)
		env.ambient_light_energy = 0.35
		env.glow_enabled = true; env.glow_intensity = 0.8
	else:
		sky.sky_top_color = Color(0.32, 0.45, 0.68); sky.sky_horizon_color = Color(0.85, 0.78, 0.7)
		sky.ground_horizon_color = Color(0.5, 0.45, 0.38); sky.ground_bottom_color = Color(0.22, 0.2, 0.17)
		key.light_energy = 2.0; key.light_color = Color(1.0, 0.88, 0.74); key.rotation_degrees = Vector3(-32, -35, 0)
		env.ambient_light_energy = 0.8
	var skyres := Sky.new(); skyres.sky_material = sky
	env.background_mode = Environment.BG_SKY; env.sky = skyres
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new(); we.environment = env; vp.add_child(we)
	key.shadow_enabled = true; key.directional_shadow_max_distance = 120.0
	vp.add_child(key)
	return key

func _shot(dusk: bool, cam_pos: Vector3, look: Vector3, fov: float, files: Array) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H); vp.own_world_3d = true; vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	_env(vp, dusk)
	var ground := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(300, 300); ground.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_texture = load("res://assets/textures/site_gravel_diff.jpg")
	gm.uv1_scale = Vector3(150, 150, 1); gm.albedo_color = Color(0.8, 0.8, 0.82); gm.roughness = 1.0
	ground.material_override = gm; vp.add_child(ground)
	var x := 0.0
	for f in files:
		var e: Dictionary = f
		var ps := load(String(e["file"])) as PackedScene
		if ps == null: continue
		var n := ps.instantiate() as Node3D
		var sz: Array = e["size_m"]
		x += float(sz[0]) * 0.5 + 0.9
		n.position = Vector3(x, 0, 0)
		x += float(sz[0]) * 0.5
		vp.add_child(n)
		if dusk:
			for mi in n.find_children("*", "MeshInstance3D", true, false):
				var m := mi as MeshInstance3D
				for s in m.mesh.get_surface_count():
					var mat := m.get_active_material(s) as StandardMaterial3D
					if mat != null and mat.resource_name.to_lower().contains("headlight"):
						mat.emission_energy_multiplier = 2.4
	# a 1.8 m post for scale
	var post := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.3, 1.8, 0.3); post.mesh = bm
	post.position = Vector3(-0.6, 0.9, 0); vp.add_child(post)
	var cam := Camera3D.new(); cam.fov = fov; cam.position = cam_pos; vp.add_child(cam); cam.current = true
	cam.look_at(look, Vector3.UP)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image(); img.convert(Image.FORMAT_RGBA8)
	vp.queue_free()
	return img

func _run() -> void:
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/traffic/manifest.json"))
	var keys := man.keys(); keys.sort()
	var files: Array = []
	for k in keys: files.append(man[k])
	var total := 0.0
	for e in files: total += float((e["size_m"] as Array)[0]) + 0.9
	var mid := total * 0.5
	var a: Image = await _shot(false, Vector3(mid - 14.0, 9.0, -20.0), Vector3(mid, 0.8, 0), 52.0, files)
	var b: Image = await _shot(false, Vector3(mid, 26.0, 9.0), Vector3(mid, 0, 0.5), 60.0, files)
	var c: Image = await _shot(true, Vector3(mid + 10.0, 4.0, -22.0), Vector3(mid, 0.8, 0), 52.0, files)
	var sheet := Image.create(W, H * 3, false, Image.FORMAT_RGBA8)
	sheet.blit_rect(a, Rect2i(0, 0, W, H), Vector2i(0, 0))
	sheet.blit_rect(b, Rect2i(0, 0, W, H), Vector2i(0, H))
	sheet.blit_rect(c, Rect2i(0, 0, W, H), Vector2i(0, H * 2))
	var v2 := SubViewport.new(); v2.size = sheet.get_size(); v2.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(v2)
	var tr := TextureRect.new(); tr.texture = ImageTexture.create_from_image(sheet); v2.add_child(tr)
	var names := ""
	for k in keys: names += String(k).get_file() + "   "
	for i in 3:
		var lab := Label.new()
		lab.text = ["Fleet at real scale, front three-quarter (left to right, sorted by path; grey post 1.8 m)",
			"From above", "Dusk: headlights raised through the `headlight` material, as traffic.gd does"][i] + ("\n" + names if i == 0 else "")
		lab.position = Vector2(8, 6 + i * H); lab.add_theme_font_size_override("font_size", 15)
		lab.add_theme_color_override("font_outline_color", Color(0, 0, 0)); lab.add_theme_constant_override("outline_size", 5)
		v2.add_child(lab)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(_out) if _out.begins_with("res://") else _out
	var err := v2.get_texture().get_image().save_jpg(path, 0.88)
	print("fleet sheet: %s (%s)" % [path, error_string(err)])
	quit()

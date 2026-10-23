extends SceneTree
## Close and distant views of the models4 rework in game/new_models2.gd, for checking by eye. Needs a window (not headless):
## Godot --path <godot dir> --resolution 480x270 -s res://test/models4_views.gd -- set=<loco|airliner|heli|flag> [tag=<suffix>]
##   loco      the locomotive side, front and rear three-quarter at 6 m, a truck and a lone wheelset at 2 m -> loco_close<tag>.jpg
##   airliner  nose and cockpit at 8 m, three-quarter at 30 m (gear up and down), 150 m, 1 km, 2.5 km (far mesh) -> airliner_close<tag>.jpg
##   heli      nose and cockpit at 5 m, side, three-quarter, top, rear -> heli_close<tag>.jpg
##   flag      the pole top, the foot, the cloth of every scheme, the whole flag -> flag_close<tag>.jpg
## All in docs/realism/models/.

var _set := "loco"
var _tag := ""

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("set="): _set = a.substr(4)
		if a.begins_with("tag="): _tag = a.substr(4)
	Grass.add_globals()
	RenderingServer.global_shader_parameter_add("g_csun", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.0, 0.0, 0.0, 0.0))
	RenderingServer.global_shader_parameter_set("g_cloud", Vector4(0.0, 0.0, 0.0, 0.0))
	RenderingServer.global_shader_parameter_set("g_dsB", Vector4(0.0, 0.0, 1.0, 1.0))
	_run.call_deferred()

## Each shot: [title, parts ([mesh, xf]), camera position, look-at point, fov].
func _shots() -> Array:
	var I := Transform3D.IDENTITY
	var out: Array = []
	if _set == "loco":
		var tr := NewModels2.freight_train(2)
		var trk := NewModels2.track_section()
		var track := [[trk, Transform3D(Basis.IDENTITY, Vector3(0, 0, -20))], [trk, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0))], [trk, Transform3D(Basis.IDENTITY, Vector3(0, 0, 20))]]
		var loco: Array = track.duplicate()
		loco.append_array(_vehicle(tr, "locomotive", 0.0, "mesh"))
		out.append(["side, front half, 6 m", loco, Vector3(6.6, 2.0, -5.0), Vector3(0.0, 2.0, -5.0), 70.0])
		out.append(["side, rear half, 6 m", loco, Vector3(6.6, 2.0, 5.0), Vector3(0.0, 2.0, 5.0), 70.0])
		out.append(["front 3/4, 6 m", loco, Vector3(4.2, 3.0, -15.0), Vector3(0.0, 2.2, -9.0), 70.0])
		out.append(["rear 3/4, 6 m", loco, Vector3(-4.2, 3.2, 15.0), Vector3(0.0, 2.3, 9.0), 70.0])
		out.append(["cab and nose, 4 m", loco, Vector3(3.3, 4.2, -11.2), Vector3(0.0, 3.4, -7.4), 70.0])
		out.append(["whole, 30 m", loco, Vector3(22.0, 7.0, -18.0), Vector3(0.0, 2.0, 0.0), 45.0])
		out.append(["truck, 2 m", loco, Vector3(3.3, 0.75, -7.9), Vector3(1.0, 0.55, -6.1), 70.0])
		var ws: Array = track.duplicate()
		ws.append([(tr["wheels"] as Dictionary)["boxcar"]["mesh"], Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0, NewModels2.TR_CAR_WHEEL, 0))])
		out.append(["car wheelset alone, 2 m", ws, Vector3(1.7, 0.75, -1.3), Vector3(0.35, 0.35, 0.0), 60.0])
		var car: Array = track.duplicate()
		car.append_array(_vehicle(tr, "boxcar", 0.0, "mesh"))
		out.append(["car truck, 2.5 m", car, Vector3(2.6, 0.9, -7.6), Vector3(0.7, 0.5, -5.85), 65.0])
	elif _set == "airliner":
		var up := NewModels2.airliner_far(false)
		var dn := NewModels2.airliner_far(true)
		var a := [[up["mesh"], I]]
		var g := [[dn["mesh"], I]]
		out.append(["nose and cockpit, 8 m", a, Vector3(6.5, 1.6, -22.5), Vector3(0.0, 0.5, -17.0), 50.0])
		out.append(["nose, front, 8 m", a, Vector3(2.0, 1.2, -27.0), Vector3(0.0, 0.3, -17.5), 50.0])
		out.append(["3/4 front, 30 m", a, Vector3(22.0, 9.0, -24.0), Vector3(0.0, 0.0, -1.0), 60.0])
		out.append(["gear down, 30 m", g, Vector3(24.0, -6.0, -20.0), Vector3(0.0, -1.0, -1.0), 60.0])
		out.append(["rear 3/4, 30 m", a, Vector3(-20.0, 6.0, 28.0), Vector3(0.0, 1.0, 2.0), 60.0])
		out.append(["from below, 150 m", a, Vector3(70.0, -120.0, -60.0), Vector3(0.0, 0.0, 0.0), 40.0])
		out.append(["side, 150 m", g, Vector3(150.0, -30.0, 10.0), Vector3(0.0, 0.0, 0.0), 40.0])
		out.append(["1 km", a, Vector3(700.0, -300.0, -640.0), Vector3(0.0, 0.0, 0.0), 40.0])
		out.append(["far mesh, 2.5 km", [[up["mesh_far"], I]], Vector3(1800.0, -700.0, -1600.0), Vector3(0.0, 0.0, 0.0), 40.0])
	elif _set == "heli":
		var hc := NewModels2.helicopter()
		var hp := [[hc["body"], I], [hc["main_rotor"], Transform3D(Basis(Vector3.UP, 0.4), hc["rotor_pivot"])], [hc["tail_rotor"], Transform3D(Basis(Vector3.RIGHT, 0.6), hc["tail_pivot"])]]
		out.append(["nose and cockpit, 5 m", hp, Vector3(3.0, 1.9, -7.4), Vector3(0.0, 1.4, -2.5), 55.0])
		out.append(["cockpit, 3 m", hp, Vector3(2.0, 2.0, -5.2), Vector3(0.0, 1.4, -2.2), 55.0])
		out.append(["side, 12 m", hp, Vector3(13.0, 1.8, 1.6), Vector3(0.0, 1.8, 1.6), 50.0])
		out.append(["3/4 front, 10 m", hp, Vector3(7.5, 4.0, -8.5), Vector3(0.0, 1.6, 0.5), 55.0])
		out.append(["rear 3/4, 10 m", hp, Vector3(-7.0, 3.5, 13.0), Vector3(0.0, 1.8, 2.0), 55.0])
		out.append(["top, 15 m", hp, Vector3(0.3, 16.0, 1.6), Vector3(0.0, 1.5, 1.5), 55.0])
	else:
		var trs: Array = []
		for sc in 5:
			var fl := NewModels2.flag(sc)
			trs.append([[fl["pole"], I], [fl["cloth"], Transform3D(Basis.IDENTITY, fl["cloth_origin"])]])
		out.append(["pole top, 1.2 m", trs[0], Vector3(0.9, 9.15, 0.8), Vector3(0.15, 8.85, 0.0), 55.0])
		out.append(["foot and cleat, 1.5 m", trs[0], Vector3(1.1, 1.3, 1.2), Vector3(0.05, 0.6, 0.0), 60.0])
		for sc in 5:
			out.append(["scheme %d, 3 m" % sc, trs[sc], Vector3(1.0, 8.6, 3.0), Vector3(1.0, 8.4, 0.0), 45.0])
		out.append(["whole, 14 m", trs[1], Vector3(6.0, 5.0, 12.0), Vector3(0.6, 4.8, 0.0), 45.0])
	return out

func _vehicle(tr: Dictionary, kind: String, z: float, level: String) -> Array:
	var out: Array = [[tr[kind], Transform3D(Basis.IDENTITY, Vector3(0, 0, z))]]
	var wd: Dictionary = (tr["wheels"] as Dictionary)[kind]
	for p: Vector3 in wd["positions"]:
		out.append([wd[level], Transform3D(Basis(Vector3.RIGHT, 0.4), p + Vector3(0, 0, z))])
	return out

func _run() -> void:
	var shots := _shots()
	var cell := Vector2i(800, 450)
	var cols := 3
	var rows := int(ceil(shots.size() / float(cols)))
	var sheet := Image.create(cell.x * cols, cell.y * rows, false, Image.FORMAT_RGBA8)
	var vp := SubViewport.new()
	vp.size = cell; vp.own_world_3d = true; vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	var sky := Sky.new(); var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.35, 0.5, 0.75); psm.sky_horizon_color = Color(0.72, 0.78, 0.86)
	psm.ground_horizon_color = Color(0.5, 0.52, 0.5); psm.ground_bottom_color = Color(0.3, 0.32, 0.28)
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY; env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; env.ambient_light_energy = 0.8
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new(); we.environment = env; vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_energy = 2.0; key.light_color = Color(1.0, 0.96, 0.9); key.rotation_degrees = Vector3(-38, -140, 0); key.shadow_enabled = true
	key.directional_shadow_max_distance = 300.0
	if _set == "flag": key.rotation_degrees = Vector3(-35, 20, 0)      # sun behind the camera, on the flag's +Z face
	vp.add_child(key)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(1200, 1200)
	ground.mesh = pm
	var gmat := StandardMaterial3D.new(); gmat.albedo_color = Color(0.28, 0.36, 0.18); gmat.roughness = 0.95
	ground.material_override = gmat
	ground.position.y = -0.62 if _set == "loco" else -0.01
	ground.visible = _set != "airliner"
	vp.add_child(ground)
	var cam := Camera3D.new(); cam.current = true; cam.near = 0.05; cam.far = 6000.0
	vp.add_child(cam)
	var holder := Node3D.new(); vp.add_child(holder)
	var labels: Array = []
	var k := 0
	for s in shots:
		for ch in holder.get_children(): ch.free()
		for part in s[1]:
			var mi := MeshInstance3D.new(); mi.mesh = part[0]; mi.transform = part[1]
			holder.add_child(mi)
		cam.fov = s[4]
		cam.position = s[2]
		cam.look_at(s[3], Vector3.UP)
		key.directional_shadow_max_distance = maxf(60.0, (s[2] as Vector3).length() * 1.5)
		RenderingServer.global_shader_parameter_set("g_wet", 0.0)
		RenderingServer.global_shader_parameter_set("g_snow", 0.0)
		for i in 6: await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var at := Vector2i((k % cols) * cell.x, (k / cols) * cell.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, cell), at)
		labels.append([at, s[0]])
		k += 1
	vp.queue_free()
	var v2 := SubViewport.new()
	v2.size = sheet.get_size(); v2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(v2)
	var trc := TextureRect.new(); trc.texture = ImageTexture.create_from_image(sheet); v2.add_child(trc)
	for l in labels:
		var at2: Vector2i = l[0]
		var bg := ColorRect.new(); bg.color = Color(1, 1, 1, 0.7); bg.position = Vector2(at2.x + 4, at2.y + 4); bg.size = Vector2(250, 26); v2.add_child(bg)
		var lab := Label.new(); lab.text = l[1]; lab.position = Vector2(at2.x + 10, at2.y + 5)
		lab.add_theme_font_size_override("font_size", 17); lab.add_theme_color_override("font_color", Color(0.05, 0.05, 0.08))
		v2.add_child(lab)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var final := v2.get_texture().get_image()
	var names := {"loco": "loco_close", "airliner": "airliner_close", "heli": "heli_close", "flag": "flag_close"}
	var path := ProjectSettings.globalize_path("res://docs/realism/models/%s%s.jpg" % [names.get(_set, _set), _tag])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := final.save_jpg(path, 0.9)
	print("views: %s (%s)" % [path, error_string(err)])
	quit()

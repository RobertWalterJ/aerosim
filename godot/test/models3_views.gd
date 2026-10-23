extends SceneTree
## Close and distant views of the models3 work in game/new_models2.gd, for checking by eye. Needs a window (not headless):
## Godot --path <godot dir> --resolution 480x270 -s res://test/models3_views.gd -- set=<barn|mills|train> [tag=<suffix>]
##   barn   the textured barn and silo at 8 m and 40 m, dry, wet and snow    -> docs/realism/models/barn_views<tag>.jpg
##   mills  the windmill and the wind pump at 20, 60, 120 and 250 m         -> docs/realism/models/mills_distance<tag>.jpg
##          (640 x 360 cells with a 40 degree vertical field: about the same angle per pixel as the game's FPV camera,
##          and no MSAA, so thin parts shimmer or drop out here as they would in flight)
##   train  the locomotive and a boxcar from the side and three-quarter at 3 m -> docs/realism/models/train_close<tag>.jpg

var _set := "barn"
var _tag := ""

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("set="): _set = a.substr(4)
		if a.begins_with("tag="): _tag = a.substr(4)
	# the world shaders read these globals (main.gd and Grass add them in the game)
	Grass.add_globals()
	RenderingServer.global_shader_parameter_add("g_csun", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.0, 0.0, 0.0, 0.0))
	RenderingServer.global_shader_parameter_set("g_cloud", Vector4(0.0, 0.0, 0.0, 0.0))
	RenderingServer.global_shader_parameter_set("g_dsB", Vector4(0.0, 0.0, 1.0, 1.0))
	_run.call_deferred()

## Each shot: [title, parts ([mesh, xf]), camera position, look-at point, fov, wet, snow].
func _shots() -> Array:
	var I := Transform3D.IDENTITY
	var out: Array = []
	if _set == "barn":
		var silo_xf := Transform3D(Basis.IDENTITY, Vector3(-10.5, 0, 4.0))
		var parts := [[NewModels2.barn(), I], [NewModels2.silo(), silo_xf]]
		for w in [["dry", 0.0, 0.0], ["wet", 1.0, 0.0], ["snow", 0.0, 1.0]]:
			out.append(["8 m, " + w[0], parts, Vector3(6.5, 1.8, -19.0), Vector3(2.0, 3.2, -12.0), 55.0, w[1], w[2]])
		for w in [["dry", 0.0, 0.0], ["wet", 1.0, 0.0], ["snow", 0.0, 1.0]]:
			out.append(["40 m, " + w[0], parts, Vector3(26.0, 14.0, -33.0), Vector3(-2.0, 5.0, -2.0), 45.0, w[1], w[2]])
	elif _set == "mills":
		var wm := NewModels2.windmill()
		var sail_xf := Transform3D(Basis(Vector3(0, 0, 1), 0.3), wm["sail_pivot"])
		var mill := [[wm["tower"], I], [wm["cap"], I], [wm["sails"], sail_xf]]
		for d: float in [20.0, 60.0, 120.0, 250.0]:
			var e := Vector3(0.35, 0.0, -1.0).normalized() * (d + 3.0)
			out.append(["windmill %d m" % int(d), mill, Vector3(e.x, 6.0, e.z), Vector3(0, 13.0, 0), 40.0, 0.0, 0.0])
		var wp := NewModels2.wind_pump()
		var pump := [[wp["tower"], I], [wp["tail"], I], [wp["wheel"], Transform3D(Basis(Vector3(0, 0, 1), 0.2), wp["wheel_pivot"])]]
		for d: float in [20.0, 60.0, 120.0, 250.0]:
			var e2 := Vector3(0.3, 0.0, -1.0).normalized() * d
			out.append(["wind pump %d m" % int(d), pump, Vector3(e2.x, 4.0, e2.z), Vector3(0, 8.0, 0), 40.0, 0.0, 0.0])
	else:
		var tr := NewModels2.freight_train(2)
		var trk := NewModels2.track_section()
		var track := [[trk, Transform3D(Basis.IDENTITY, Vector3(0, 0, -10))], [trk, Transform3D(Basis.IDENTITY, Vector3(0, 0, 10))], [trk, Transform3D(Basis.IDENTITY, Vector3(0, 0, 30))]]
		var loco: Array = track.duplicate()
		loco.append_array(_vehicle(tr, "locomotive", 0.0))
		var car: Array = track.duplicate()
		car.append_array(_vehicle(tr, "boxcar", 0.0))
		# 3 m from the side of the car, at a person's eye height, aimed at the front truck; then the three-quarter view
		out.append(["locomotive, side, 3 m", loco, Vector3(4.6, 1.2, -6.35), Vector3(0.0, 0.7, -6.35), 70.0, 0.0, 0.0])
		out.append(["locomotive, 3/4, 3 m", loco, Vector3(3.6, 1.5, -10.0), Vector3(0.6, 0.7, -6.35), 70.0, 0.0, 0.0])
		out.append(["locomotive, whole", loco, Vector3(17.0, 4.0, -14.0), Vector3(0.0, 2.0, 0.0), 50.0, 0.0, 0.0])
		out.append(["boxcar, side, 3 m", car, Vector3(4.6, 1.2, -5.85), Vector3(0.0, 0.6, -5.85), 70.0, 0.0, 0.0])
		out.append(["boxcar, 3/4, 3 m", car, Vector3(3.6, 1.5, -9.3), Vector3(0.6, 0.6, -5.85), 70.0, 0.0, 0.0])
		out.append(["boxcar, whole", car, Vector3(14.0, 3.5, -12.0), Vector3(0.0, 1.8, 0.0), 50.0, 0.0, 0.0])
	return out

## A vehicle's parts: the body mesh, plus its wheel meshes at their positions when the model has separate wheels.
func _vehicle(tr: Dictionary, kind: String, z: float) -> Array:
	var out: Array = [[tr[kind], Transform3D(Basis.IDENTITY, Vector3(0, 0, z))]]
	if tr.has("wheels"):
		var wd: Dictionary = (tr["wheels"] as Dictionary)[kind]
		for p: Vector3 in wd["positions"]:
			out.append([wd["mesh"], Transform3D(Basis(Vector3.RIGHT, 0.4), p + Vector3(0, 0, z))])
	return out

func _run() -> void:
	var shots := _shots()
	var cell := Vector2i(640, 360) if _set == "mills" else Vector2i(800, 450)
	var cols := 4 if _set == "mills" else 3
	var rows := int(ceil(shots.size() / float(cols)))
	var sheet := Image.create(cell.x * cols, cell.y * rows, false, Image.FORMAT_RGBA8)
	var vp := SubViewport.new()
	vp.size = cell; vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED if _set == "mills" else Viewport.MSAA_4X
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
	vp.add_child(key)
	# a ground: green field (white in the snow shots)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(1200, 1200)
	ground.mesh = pm
	var gmat := StandardMaterial3D.new(); gmat.albedo_color = Color(0.28, 0.36, 0.18); gmat.roughness = 0.95
	ground.material_override = gmat
	ground.position.y = -0.62 if _set == "train" else -0.01
	vp.add_child(ground)
	var cam := Camera3D.new(); cam.current = true; cam.near = 0.05; cam.far = 3000.0
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
		RenderingServer.global_shader_parameter_set("g_wet", s[5])
		RenderingServer.global_shader_parameter_set("g_snow", s[6])
		gmat.albedo_color = Color(0.7, 0.72, 0.78) if float(s[6]) > 0.5 else (Color(0.2, 0.26, 0.13) if float(s[5]) > 0.5 else Color(0.28, 0.36, 0.18))
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
		var bg := ColorRect.new(); bg.color = Color(1, 1, 1, 0.7); bg.position = Vector2(at2.x + 4, at2.y + 4); bg.size = Vector2(190, 26); v2.add_child(bg)
		var lab := Label.new(); lab.text = l[1]; lab.position = Vector2(at2.x + 10, at2.y + 5)
		lab.add_theme_font_size_override("font_size", 17); lab.add_theme_color_override("font_color", Color(0.05, 0.05, 0.08))
		v2.add_child(lab)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var final := v2.get_texture().get_image()
	var names := {"barn": "barn_views", "mills": "mills_distance", "train": "train_close"}
	var path := ProjectSettings.globalize_path("res://docs/realism/models/%s%s.jpg" % [names.get(_set, _set), _tag])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := final.save_jpg(path, 0.9)
	print("views: %s (%s)" % [path, error_string(err)])
	quit()

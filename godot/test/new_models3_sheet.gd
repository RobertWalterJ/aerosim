extends SceneTree
## Contact sheet of the farm models (game/new_models3.gd): every model from three views on a plain field, lit either by a low
## golden-hour sun or by an overcast sky, for checking by eye. Not part of the game (test/ is left out of exports). Needs a
## window (not headless):
## Godot --path <godot dir> --resolution 480x270 -s res://test/new_models3_sheet.gd -- [light=golden|overcast] [set=fences|crops|ground|all] [out=<jpg>] [only=<title word>]

const CELL := Vector2i(400, 300)
const COLS := 6
var _out := ""
var _only := ""
var _light := "golden"
var _set := "all"
var _time := 3.0
var _wind := 2.0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
		if a.begins_with("only="): _only = a.substr(5)
		if a.begins_with("light="): _light = a.substr(6)
		if a.begins_with("set="): _set = a.substr(4)
		if a.begins_with("time="): _time = float(a.substr(5))
		if a.begins_with("wind="): _wind = float(a.substr(5))
	if _out == "": _out = "res://docs/realism/models/new_models3_%s_%s.jpg" % [_set, _light]
	Grass.add_globals()
	RenderingServer.global_shader_parameter_add("g_csun", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.0, 0.0, 0.0, 0.0))
	RenderingServer.global_shader_parameter_set("g_cloud", Vector4(0.0, 0.0, 0.0, 0.0))
	RenderingServer.global_shader_parameter_set("g_dsB", Vector4(0.0, 0.0, 1.0, 1.0))
	RenderingServer.global_shader_parameter_set("g_wind", Vector3(_wind, 0.0, _wind * 0.3))
	RenderingServer.global_shader_parameter_set("g_time", _time)
	_run.call_deferred()

## One entry: a title and three cells; each cell: the meshes (with where they go) and the direction the camera looks from.
func _entries() -> Array:
	var out: Array = []
	var q34 := Vector3(0.7, 0.35, -1.0)
	var side := Vector3(0.0, 0.18, -1.0)
	var low := Vector3(1.0, 0.12, -0.3)
	var top := Vector3(0.1, 1.0, 0.25)
	if _set == "all" or _set == "fences":
		for nm: String in ["fence_post_rail_a", "fence_post_rail_b", "fence_post_rail_c", "fence_wire_a", "fence_wire_b", "fence_gate_a", "fence_corner_a", "fence_broken_a"]:
			var run := [[NewModels3.mesh(nm, 0), _at(0, 0, 0)]]
			if nm.begins_with("fence_post") or nm.begins_with("fence_wire"):
				run.append([NewModels3.mesh(nm, 0), _at(3, 0, 0)]); run.append([NewModels3.mesh(nm, 0), _at(6, 0, 0)])
			var lods := [[NewModels3.mesh(nm, 0), _at(0, 0, 0)], [NewModels3.mesh(nm, 1), _at(0, 0, 2.0)], [NewModels3.mesh(nm, 2), _at(0, 0, 4.0)]]
			out.append([nm, [[run, q34], [run, Vector3(0.0, 0.1, -1.0) if nm != "fence_corner_a" else top], [lods, Vector3(-0.6, 0.45, -1.0)]]])
		for nm: String in ["hay_round_a", "hay_round_b", "hay_roll_a", "hay_square_a", "hay_square_b", "hay_stack_a"]:
			var one := [[NewModels3.mesh(nm, 0), _at(0, 0, 0)]]
			var trio := [[NewModels3.mesh(nm, 0), _at(0, 0, 0)], [NewModels3.mesh(nm, 0), _at(1.7, 0, 0.8)], [NewModels3.mesh(nm, 0), _at(-1.5, 0, 1.3)]]
			var lods := [[NewModels3.mesh(nm, 0), _at(-2.2, 0, 0)], [NewModels3.mesh(nm, 1), _at(0, 0, 0)], [NewModels3.mesh(nm, 2), _at(2.2, 0, 0)]]
			out.append([nm, [[one, q34], [trio, low], [lods, Vector3(0.0, 0.35, -1.0)]]])
	if _set == "all" or _set == "crops":
		for nm: String in ["corn_stand_a", "corn_stand_b", "barley_patch_a", "barley_patch_b", "alfalfa_patch_a", "alfalfa_patch_b", "crop_edge_weeds"]:
			var tall := nm.begins_with("corn")
			var sp := 1.5 if tall else 0.7
			var one := [[NewModels3.mesh(nm, 0), _at(0, 0, 0)]]
			var trio: Array = []
			for i in 5: trio.append([NewModels3.mesh(nm, 0), _at((i - 2) * sp, 0, (i % 2) * sp * 0.6)])
			var lods := [[NewModels3.mesh(nm, 0), _at(-sp * 1.4, 0, 0)], [NewModels3.mesh(nm, 1), _at(0, 0, 0)], [NewModels3.mesh(nm, 2), _at(sp * 1.4, 0, 0)]]
			out.append([nm, [[one, q34], [trio, Vector3(0.0, 0.18, -1.0)], [lods, Vector3(0.0, 0.3, -1.0)]]])
		var chunk := NewModels3.mesh("corn_row_chunk", 0)
		var rows: Array = []
		for r in 4:
			for k in 2: rows.append([chunk, _at(r * 0.76, 0, k * 4.0)])
		var far: Array = []
		for r in 4:
			for k in 2: far.append([NewModels3.mesh("corn_row_chunk", 2), _at(r * 0.76, 0, k * 4.0)])
		out.append(["corn_row_chunk", [[[[chunk, _at(0, 0, 0)]], q34], [rows, Vector3(0.0, 0.25, -1.0)], [rows, Vector3(1.0, 0.12, 0.0)]]])
		out.append(["corn rows near and far (lod 0 and 2)", [[rows, Vector3(0.0, 1.0, -0.6)], [far, Vector3(0.0, 0.35, -1.0)], [far, Vector3(0.6, 0.2, -1.0)]]])
	if _set == "all" or _set == "ground":
		for nm: String in ["field_furrow_a", "field_furrow_b", "field_headland_a", "field_track_a"]:
			var t: Vector2 = NewModels3.TILE[nm]
			var one := [[NewModels3.mesh(nm, 0), _at(0, 0, 0)]]
			var tiled: Array = []
			for i in 2:
				for j in 2: tiled.append([NewModels3.mesh(nm, 0), _at(i * t.x, 0, j * t.y)])
			var lods := [[NewModels3.mesh(nm, 0), _at(0, 0, 0)], [NewModels3.mesh(nm, 1), _at(t.x * 1.05, 0, 0)], [NewModels3.mesh(nm, 2), _at(t.x * 2.1, 0, 0)]]
			out.append([nm, [[one, Vector3(0.5, 0.45, -1.0)], [tiled, Vector3(0.2, 0.9, -0.4)], [lods, Vector3(0.0, 0.5, -1.0)]]])
	return out

func _at(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))

func _run() -> void:
	var entries := _entries()
	if _only != "":
		var keep: Array = []
		for e in entries:
			if (e[0] as String).contains(_only): keep.append(e)
		entries = keep
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
			var box := AABB()
			var first := true
			for part in c[0]:
				var mi := MeshInstance3D.new(); mi.mesh = part[0]; mi.transform = part[1]
				holder.add_child(mi)
				var bb: AABB = (part[1] as Transform3D) * (part[0] as Mesh).get_aabb()
				box = bb if first else box.merge(bb)
				first = false
			var centre := box.get_center()
			var radius := box.size.length() * 0.5
			var dir: Vector3 = (c[1] as Vector3).normalized()
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

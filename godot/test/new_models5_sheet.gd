extends SceneTree
## Contact sheet of the models (game/new_models5.gd): every model from three views on a plain field, lit either by a low
## golden-hour sun or by an overcast sky, for checking by eye. Not part of the game (test/ is left out of exports). Needs a
## window (not headless):
## Godot --path <godot dir> --resolution 480x270 -s res://test/new_models3_sheet.gd -- [light=golden|overcast] [set=animals|boats|machinery|all] [out=<jpg>] [only=<title word>]

var CELL := Vector2i(400, 300)
var COLS := 4
var _out := ""
var _only := ""
var _light := "golden"
var _set := "all"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
		if a.begins_with("only="): _only = a.substr(5)
		if a.begins_with("cell="): CELL = Vector2i(int(a.substr(5)), int(a.substr(5)) * 3 / 4)
		if a.begins_with("light="): _light = a.substr(6)
		if a.begins_with("set="): _set = a.substr(4)
	if _set == "final": COLS = 6
	if _out == "": _out = "res://docs/realism/models/new_models5_%s_%s.jpg" % [_set, _light]
	Grass.add_globals()
	RenderingServer.global_shader_parameter_add("g_csun", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.0, 0.0, 0.0, 0.0))
	RenderingServer.global_shader_parameter_set("g_cloud", Vector4(0.0, 0.0, 0.0, 0.0))
	RenderingServer.global_shader_parameter_set("g_dsB", Vector4(0.0, 0.0, 1.0, 1.0))
	RenderingServer.global_shader_parameter_set("g_wind", Vector3(2.0, 0.0, 0.6))
	RenderingServer.global_shader_parameter_set("g_time", 3.0)
	_run.call_deferred()

## One entry: a title and three cells; each cell: the meshes (with where they go), the direction the camera looks from, and optionally a focus point and radius.
func _entries() -> Array:
	var out: Array = []
	if _set == "final":
		for nm: String in NewModels5.NAMES:
			var bb := NewModels5.mesh(nm, 0).get_aabb()
			var dir := Vector3(0.75, 0.3, -1.0)
			if nm == "telegraph_wire_10m": dir = Vector3(0.2, 0.25, -1.0)
			out.append([nm, [[[[NewModels5.mesh(nm, 0), _at(0, 0, 0)]], dir]]])
		return out
	var q34 := Vector3(0.75, 0.3, -1.0)
	var side := Vector3(1.0, 0.12, 0.0)
	var front := Vector3(0.25, 0.2, -1.0)
	if _set == "all" or _set == "animals":
		for nm: String in ["cow_a", "cow_b", "cow_c", "calf_a", "sheep_a", "sheep_b", "lamb_a", "horse_a", "horse_b", "dog_a", "chicken_a"]:
			var whole := [[NewModels5.mesh(nm, 0), _at(0, 0, 0)]]
			var pr := NewModels5.parts(nm, 0)
			var hp: Vector3 = pr["head"]["pivot"] if pr.has("head") else Vector3(0, 1, -1)
			var hd := [[NewModels5.mesh(nm, 0), _at(0, 0, 0)]]
			var rad := 0.5 if nm.begins_with("horse") else (0.38 if (nm.begins_with("cow") or nm == "calf_a") else 0.22)
			if nm == "chicken_a": rad = 0.1
			var lods := [[NewModels5.mesh(nm, 0), _at(-1.8, 0, 0)], [NewModels5.mesh(nm, 1), _at(0, 0, 0)], [NewModels5.mesh(nm, 2), _at(1.8, 0, 0)]]
			out.append([nm, [[whole, q34], [whole, side], [hd, Vector3(0.75, 0.2, -1.0), hp + Vector3(0, -0.22, -0.28), rad], [lods, Vector3(0.0, 0.25, -1.0)]]])
	var groups := {"boats": ["rowboat_a", "sailboat_a", "sailboat_b", "fishing_boat_a", "jetty_a", "mooring_post_a", "buoy_a"],
		"machinery": ["combine_a", "baler_a", "plough_a", "seed_drill_a", "water_trough_a", "feed_rack_a", "wood_pile_a", "oil_tank_a", "grain_silo_a"],
		"yard": ["chicken_coop_a", "dog_kennel_a", "telegraph_wire_10m", "fence_gate_hanging_a"]}
	for g in groups:
		if _set != "all" and _set != g: continue
		for nm: String in groups[g]:
			var whole := [[NewModels5.mesh(nm, 0), _at(0, 0, 0)]]
			var bb := NewModels5.mesh(nm, 0).get_aabb()
			var gap := maxf(bb.size.x, bb.size.z) * 1.05
			var lods := [[NewModels5.mesh(nm, 0), _at(-gap, 0, 0)], [NewModels5.mesh(nm, 1), _at(0, 0, 0)], [NewModels5.mesh(nm, 2), _at(gap, 0, 0)]]
			out.append([nm, [[whole, Vector3(0.75, 0.35, -1.0)], [whole, Vector3(1.0, 0.1, 0.0)], [whole, Vector3(-0.6, 0.5, 1.0)], [lods, Vector3(0.0, 0.4, -1.0)]]])
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
	var per := 1 if _set == "final" else 4
	var rows := int(ceil(entries.size() * float(per) / COLS))
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
	elif _light == "back":
		sky.sky_top_color = Color(0.32, 0.45, 0.66); sky.sky_horizon_color = Color(1.0, 0.8, 0.55)
		sky.ground_horizon_color = Color(0.6, 0.45, 0.33); sky.ground_bottom_color = Color(0.2, 0.17, 0.15)
		key.light_energy = 3.0; key.light_color = Color(1.0, 0.82, 0.58); key.rotation_degrees = Vector3(-14, 0, 0)
		env.ambient_light_energy = 0.9
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
			if c.size() > 2:
				centre = c[2]; radius = c[3]
			var dir: Vector3 = (c[1] as Vector3).normalized()
			if _light == "back":
				var tr := key.global_transform.basis * Vector3(0, 0, -1)
				dir = Vector3(tr.x + dir.x * 0.5, 0.12, tr.z + dir.z * 0.5).normalized()
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

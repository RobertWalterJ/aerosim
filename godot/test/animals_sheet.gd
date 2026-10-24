extends SceneTree
## Contact sheets of the Blender animals (game/animal_assets.gd) in Godot's own renderer, with the game's fur shader.
## Needs a window (not headless):
##   Godot --path <godot dir> --resolution 480x270 -s res://test/animals_sheet.gd -- names=cow_a,horse_a [light=golden|overcast|backlit]
##        [views=front,side,34,rear,head] [clip=idle] [t=0.0] [strip=walk:8] [fur=1] [dist=0] [out=<jpg>] [cell=WxH] [cols=N]
## views: front, side, 34 (three-quarter front), rear, head (close-up), 34r (three-quarter rear). strip=<clip>:<n> instead
## renders n frames of a clip from the side. dist=<m> puts the camera at that distance (the level of detail switches as in play).

var CELL := Vector2i(480, 360)
var COLS := 5
var _out := ""
var _light := "golden"
var _names: Array[String] = []
var _views: Array[String] = ["front", "side", "34", "rear", "head"]
var _clip := "idle"
var _t := 0.0
var _strip := ""
var _strip_n := 8
var _fur := true
var _dist := 0.0
var _label := true

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
		elif a.begins_with("light="): _light = a.substr(6)
		elif a.begins_with("names="):
			for n in a.substr(6).split(","): _names.append(n)
		elif a.begins_with("views="):
			_views.clear()
			for v in a.substr(6).split(","): _views.append(v)
		elif a.begins_with("clip="): _clip = a.substr(5)
		elif a.begins_with("t="): _t = float(a.substr(2))
		elif a.begins_with("strip="):
			var sp := a.substr(6).split(":")
			_strip = sp[0]; _strip_n = int(sp[1]) if sp.size() > 1 else 8
		elif a.begins_with("fur="): _fur = a.substr(4) != "0"
		elif a.begins_with("dist="): _dist = float(a.substr(5))
		elif a.begins_with("cols="): COLS = int(a.substr(5))
		elif a.begins_with("nolabel"): _label = false
		elif a.begins_with("cell="):
			var c := a.substr(5).split("x"); CELL = Vector2i(int(c[0]), int(c[1]))
	if _names.is_empty(): _names.assign(AnimalAssets.NAMES)
	if _out == "": _out = "res://docs/realism/models/animals_%s.jpg" % _light
	Grass.add_globals()
	RenderingServer.global_shader_parameter_add("g_csun", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.0, 0.0, 0.0, 0.0))
	RenderingServer.global_shader_parameter_set("g_cloud", Vector4(0.0, 0.0, 0.0, 0.0))
	RenderingServer.global_shader_parameter_set("g_dsB", Vector4(0.0, 0.0, 1.0, 1.0))
	RenderingServer.global_shader_parameter_set("g_wind", Vector3(1.0, 0.0, 0.4))
	RenderingServer.global_shader_parameter_set("g_time", 3.0)
	_run.call_deferred()

func _dir(v: String) -> Vector3:
	match v:
		"front": return Vector3(0.0, 0.12, 1.0)
		"side": return Vector3(1.0, 0.08, 0.0)
		"lside": return Vector3(-1.0, 0.08, 0.0)
		"34": return Vector3(0.8, 0.3, 0.9)
		"34r": return Vector3(-0.8, 0.35, -0.9)
		"rear": return Vector3(0.0, 0.15, -1.0)
		"top": return Vector3(0.05, 1.0, 0.1)
		"head": return Vector3(0.75, 0.2, 0.8)
	return Vector3(1, 0.2, 1)

func _run() -> void:
	var cells: Array = []        # [name, view, clip, time, label]
	for nm in _names:
		if _strip != "":
			for i in _strip_n:
				cells.append([nm, "side", _strip, float(i) / _strip_n, "%s %s %d/%d" % [nm, _strip, i + 1, _strip_n]])
		else:
			for v in _views:
				cells.append([nm, v, _clip, _t, "%s  %s" % [nm, v]])
	var rows := int(ceil(cells.size() / float(COLS)))
	var sheet := Image.create(CELL.x * COLS, CELL.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.3, 0.3, 0.3))
	var vp := SubViewport.new()
	vp.size = CELL; vp.own_world_3d = true; vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	var sky := ProceduralSkyMaterial.new()
	var key := DirectionalLight3D.new()
	match _light:
		"golden":
			sky.sky_top_color = Color(0.30, 0.42, 0.65); sky.sky_horizon_color = Color(0.95, 0.68, 0.48)
			sky.ground_horizon_color = Color(0.55, 0.42, 0.33); sky.ground_bottom_color = Color(0.2, 0.17, 0.15)
			key.light_energy = 2.4; key.light_color = Color(1.0, 0.74, 0.5); key.rotation_degrees = Vector3(-14, 40, 0)
			env.ambient_light_energy = 0.7
		"backlit":
			sky.sky_top_color = Color(0.32, 0.45, 0.68); sky.sky_horizon_color = Color(0.92, 0.75, 0.55)
			sky.ground_horizon_color = Color(0.5, 0.42, 0.35); sky.ground_bottom_color = Color(0.2, 0.18, 0.15)
			key.light_energy = 2.8; key.light_color = Color(1.0, 0.8, 0.6); key.rotation_degrees = Vector3(-18, 180, 0)
			env.ambient_light_energy = 0.6
		_:
			sky.sky_top_color = Color(0.58, 0.62, 0.68); sky.sky_horizon_color = Color(0.72, 0.75, 0.78)
			sky.ground_horizon_color = Color(0.5, 0.5, 0.48); sky.ground_bottom_color = Color(0.3, 0.3, 0.28)
			key.light_energy = 0.0; key.rotation_degrees = Vector3(-60, -38, 0)
			env.ambient_light_energy = 1.1
	var skyres := Sky.new(); skyres.sky_material = sky
	env.background_mode = Environment.BG_SKY; env.sky = skyres
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new(); we.environment = env; vp.add_child(we)
	key.shadow_enabled = key.light_energy > 0.0
	vp.add_child(key)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(400, 400)
	ground.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.20, 0.23, 0.10); gm.roughness = 1.0
	ground.material_override = gm
	ground.position = Vector3(0, -0.005, 0)
	vp.add_child(ground)
	var cam := Camera3D.new(); cam.fov = 30.0; cam.current = true
	vp.add_child(cam)
	var holder := Node3D.new(); vp.add_child(holder)
	var labels: Array = []
	var cell := 0
	var cur_name := ""
	var inst: Node3D = null
	for e in cells:
		if e[0] != cur_name:
			for ch in holder.get_children(): ch.free()
			inst = WildlifeAssets.instance(e[0]) if e[0] in WildlifeAssets.NAMES else AnimalAssets.instance(e[0], {"fur": _fur, "clip": e[2], "seed": 1})
			holder.add_child(inst)
			cur_name = e[0]
		var ap := AnimalAssets.find_player(inst)
		if ap != null:
			if ap.current_animation != e[2] and ap.has_animation(e[2]): ap.play(e[2])
			ap.seek(float(e[3]) * (ap.current_animation_length if _strip != "" else 1.0) if _strip != "" else float(e[3]), true)
			ap.pause()
		await process_frame
		var info: Dictionary = AnimalInfo.INFO.get(AnimalAssets.ALIASES.get(e[0], [e[0]])[0], {})
		var h: float = float(info.get("height", 1.2)); var ln: float = float(info.get("length", 2.0))
		var centre := Vector3(0, h * 0.5, 0)
		var radius := Vector3(0.6 * h, h, ln).length() * 0.5
		if info.is_empty():
			# a prop: frame its meshes' bounds
			var bb := AABB(); var first := true
			for mi: MeshInstance3D in AnimalAssets.meshes(inst):
				if mi.mesh == null or String(mi.name).ends_with("_LOD1") or "-colonly" in String(mi.name): continue
				var t := Transform3D.IDENTITY; var c: Node = mi
				while c != null and c != inst:
					if c is Node3D: t = (c as Node3D).transform * t
					c = c.get_parent()
				var b2: AABB = t * mi.mesh.get_aabb()
				bb = b2 if first else bb.merge(b2); first = false
			centre = bb.get_center(); radius = maxf(bb.size.length() * 0.5, 0.15); h = bb.size.y
		var v: String = e[1]
		var dir := _dir(v).normalized()
		if v == "head":
			var sk := AnimalAssets.find_skeleton(inst)
			var bi := sk.find_bone("head") if sk != null else -1
			if bi >= 0:
				var hp := sk.global_transform * sk.get_bone_global_pose(bi)
				var tail := hp.origin + hp.basis.y * h * 0.32
				centre = (hp.origin + tail) * 0.5
			radius = h * 0.24
		var dist := radius / sin(deg_to_rad(cam.fov * 0.5)) * 0.95
		if _dist > 0.0 and v != "head":
			dist = _dist; cam.fov = rad_to_deg(2.0 * asin(clampf(radius / _dist, 0.001, 0.95)))
		else:
			cam.fov = 30.0
		cam.position = centre + dir * dist
		cam.near = maxf(dist * 0.01, 0.02); cam.far = dist * 8.0 + 50.0
		cam.look_at(centre, Vector3.UP if absf(dir.y) < 0.95 else Vector3(0, 0, -1))
		key.directional_shadow_max_distance = dist * 2.5 + 5.0
		for i in 6: await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var at := Vector2i((cell % COLS) * CELL.x, (cell / COLS) * CELL.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), at)
		labels.append([at, e[4]])
		cell += 1
	vp.queue_free()
	var v2 := SubViewport.new()
	v2.size = sheet.get_size(); v2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(v2)
	var tr := TextureRect.new(); tr.texture = ImageTexture.create_from_image(sheet); v2.add_child(tr)
	if _label:
		for l in labels:
			var at2: Vector2i = l[0]
			var lab := Label.new(); lab.text = l[1]; lab.position = Vector2(at2.x + 8, at2.y + 6)
			lab.add_theme_font_size_override("font_size", 16); lab.add_theme_color_override("font_color", Color(1, 1, 1))
			lab.add_theme_color_override("font_outline_color", Color(0, 0, 0)); lab.add_theme_constant_override("outline_size", 5)
			v2.add_child(lab)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var final := v2.get_texture().get_image()
	var path := ProjectSettings.globalize_path(_out) if _out.begins_with("res://") else _out
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := final.save_jpg(path, 0.9)
	print("animals sheet: %s (%s)" % [path, error_string(err)])
	quit()

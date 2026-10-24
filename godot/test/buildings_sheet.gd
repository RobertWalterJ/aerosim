extends SceneTree
## Contact sheets for the buildings pass (lane/buildings). Each model is loaded the way the game loads it (StoryAssets: the
## .glb with the photographed materials swapped in by name; `code:<x>` for the in-code farm buildings) and photographed
## from front, three-quarter front, side, rear-aerial and straight down (the roof), in a low golden-hour sun, an overcast
## sky or at night (window_light shown). mode=roofs frames the roof: eaves-level views along and across the ridge that show
## the ridge above the eaves, and a close oblique of the ridge, chimney and verge.
## Needs a window (not headless):
## Godot --path <godot dir> --resolution 640x360 -s res://test/buildings_sheet.gd -- names=a,b [light=golden|overcast|night]
##   [mode=views|roofs|close] [cell=480x360] [out=<jpg>]

var CELL := Vector2i(480, 360)
var _out := ""
var _light := "golden"
var _mode := "views"
var _names: Array[String] = []
var _focus := Vector3.INF
var _ground_y := 0.0

const VIEWS := {
	"views": [["front", Vector3(0.0, 0.12, 1.0), 1.0], ["3/4 front", Vector3(-0.8, 0.32, 1.0), 1.0], ["side", Vector3(-1.0, 0.1, 0.05), 1.0],
		["rear aerial", Vector3(0.7, 0.75, -1.0), 1.0], ["roof (top)", Vector3(0.0, 1.0, 0.0), 1.0]],
	"roofs": [["gable end, eye level", Vector3(-1.0, 0.04, 0.0), 0.9], ["front, eye level", Vector3(0.0, 0.04, 1.0), 0.9],
		["roof close", Vector3(-0.55, 0.45, 0.7), 0.45], ["ridge and chimney", Vector3(0.6, 0.3, -0.7), 0.4]],
	"close": [["front close", Vector3(-0.25, 0.08, 1.0), 0.42], ["door close", Vector3(0.15, 0.02, 1.0), 0.22], ["corner close", Vector3(-0.7, 0.2, 0.7), 0.5]],
}

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
		if a.begins_with("light="): _light = a.substr(6)
		if a.begins_with("mode="): _mode = a.substr(5)
		if a.begins_with("cell="):
			var p := a.substr(5).split("x")
			CELL = Vector2i(int(p[0]), int(p[1]))
		if a.begins_with("ground="): _ground_y = float(a.substr(7))
		if a.begins_with("focus="):
			var f := a.substr(6).split("_")
			_focus = Vector3(float(f[0]), float(f[1]), float(f[2]))
		if a.begins_with("names="):
			for n in a.substr(6).split(","): _names.append(n)
	if _out == "": _out = "res://docs/realism/models/buildings_%s_%s.jpg" % [_mode, _light]
	Grass.add_globals()
	RenderingServer.global_shader_parameter_add("g_csun", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.0, 0.0, 0.0, 0.0))
	RenderingServer.global_shader_parameter_set("g_cloud", Vector4(0.0, 0.0, 0.0, 0.0))
	RenderingServer.global_shader_parameter_set("g_dsB", Vector4(0.0, 0.0, 1.0, 1.0))
	RenderingServer.global_shader_parameter_set("g_wind", Vector3(2.0, 0.0, 0.6))
	RenderingServer.global_shader_parameter_set("g_time", 3.0)
	_run.call_deferred()

static func make(nm: String) -> Node3D:
	if nm.begins_with("res://"):
		# a file as it stands (e.g. a broken-roof fixture), with the kit materials swapped in by name like StoryAssets
		var r0 := (load(nm) as PackedScene).instantiate() as Node3D
		StoryAssets._remap(r0)
		return r0
	if nm.begins_with("code:"):
		var mi := MeshInstance3D.new()
		var what := nm.substr(5)
		match what:
			"barn": mi.mesh = NewModels2.barn()
			"silo": mi.mesh = NewModels2.silo()
			_: mi.mesh = NewModels5.mesh(what, 0) if what in NewModels5.NAMES else NewModels4.mesh(what, 0)
		var r := Node3D.new(); r.add_child(mi); r.name = what
		return r
	var lod := 0
	var base := nm
	for l in [1, 2]:
		if nm.ends_with("_lod%d" % l): lod = l; base = nm.substr(0, nm.length() - 5)
	return StoryAssets.instance(base, lod)

func _env(vp: SubViewport) -> DirectionalLight3D:
	var env := Environment.new()
	var sky := ProceduralSkyMaterial.new()
	var key := DirectionalLight3D.new()
	if _light == "golden":
		sky.sky_top_color = Color(0.28, 0.42, 0.68); sky.sky_horizon_color = Color(0.95, 0.72, 0.52)
		sky.ground_horizon_color = Color(0.55, 0.45, 0.36); sky.ground_bottom_color = Color(0.22, 0.2, 0.17)
		key.light_energy = 2.4; key.light_color = Color(1.0, 0.76, 0.52); key.rotation_degrees = Vector3(-16, -40, 0)
		env.ambient_light_energy = 0.75
	elif _light == "night":
		sky.sky_top_color = Color(0.01, 0.015, 0.035); sky.sky_horizon_color = Color(0.05, 0.06, 0.1)
		sky.ground_horizon_color = Color(0.03, 0.03, 0.04); sky.ground_bottom_color = Color(0.01, 0.01, 0.01)
		key.light_energy = 0.12; key.light_color = Color(0.6, 0.7, 1.0); key.rotation_degrees = Vector3(-40, 30, 0)
		env.ambient_light_energy = 0.25
		env.glow_enabled = true; env.glow_intensity = 0.6
	else:
		sky.sky_top_color = Color(0.6, 0.64, 0.7); sky.sky_horizon_color = Color(0.76, 0.78, 0.8)
		sky.ground_horizon_color = Color(0.5, 0.5, 0.48); sky.ground_bottom_color = Color(0.3, 0.3, 0.28)
		key.light_energy = 0.25; key.rotation_degrees = Vector3(-65, -30, 0)
		env.ambient_light_energy = 1.15
	var skyres := Sky.new(); skyres.sky_material = sky
	env.background_mode = Environment.BG_SKY; env.sky = skyres
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true; env.ssao_radius = 0.6; env.ssao_intensity = 1.6
	var we := WorldEnvironment.new(); we.environment = env; vp.add_child(we)
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	vp.add_child(key)
	return key

func _run() -> void:
	var views: Array = VIEWS[_mode]
	var cols := views.size()
	var rows := _names.size()
	var sheet := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGBA8)
	var vp := SubViewport.new()
	vp.size = CELL; vp.own_world_3d = true; vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	root.add_child(vp)
	var key := _env(vp)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(160, 160)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = load("res://assets/textures/gravel_diff.jpg")
	gm.albedo_color = Color(0.62, 0.6, 0.56)
	gm.uv1_scale = Vector3(80, 80, 80); gm.roughness = 1.0
	ground.material_override = gm
	ground.position = Vector3(0, _ground_y - 0.005, 0)
	vp.add_child(ground)
	var cam := Camera3D.new(); cam.fov = 32.0; cam.current = true
	vp.add_child(cam)
	var holder := Node3D.new(); vp.add_child(holder)
	var labels: Array = []
	for ri in rows:
		var nm := _names[ri]
		for ch in holder.get_children(): ch.free()
		var inst := make(nm)
		holder.add_child(inst)
		var wl := inst.find_child("window_light", true, false)
		if wl: (wl as Node3D).visible = _light == "night"
		var box := AABB(); var first := true
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			if String(mi.name).ends_with("-colonly"): continue
			var bb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).mesh.get_aabb()
			box = bb if first else box.merge(bb)
			first = false
		for ci in cols:
			var v: Array = views[ci]
			var dir: Vector3 = (v[1] as Vector3).normalized()
			var zoom: float = v[2]
			var centre := box.get_center()
			var radius := box.size.length() * 0.5
			if _mode == "roofs" or _mode == "close":
				# aim at the roof (upper part of the box) for roof views; at the ground floor for the close views
				if _mode == "roofs": centre.y = box.position.y + box.size.y * 0.72
				else: centre.y = box.position.y + box.size.y * (0.2 if ci == 1 else 0.35)
			if _focus != Vector3.INF: centre = _focus
			var dist := radius / sin(deg_to_rad(cam.fov * 0.5)) * 0.92 * zoom
			cam.position = centre + dir * dist
			if cam.position.y < 1.2 and box.size.y > 3.0: cam.position.y = 1.2
			cam.near = maxf(dist * 0.005, 0.05); cam.far = dist * 8.0
			cam.look_at(centre, Vector3.UP if absf(dir.y) < 0.95 else Vector3(0, 0, -1))
			key.directional_shadow_max_distance = dist * 3.0
			for i in 6: await process_frame
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			var at := Vector2i(ci * CELL.x, ri * CELL.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), at)
			labels.append([at, (nm.get_file() + "  " if ci == 0 else "") + String(v[0])])
	vp.queue_free()
	var v2 := SubViewport.new()
	v2.size = sheet.get_size(); v2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(v2)
	var tr := TextureRect.new(); tr.texture = ImageTexture.create_from_image(sheet); v2.add_child(tr)
	for l in labels:
		var at2: Vector2i = l[0]
		var line := ColorRect.new(); line.color = Color(1, 1, 1, 0.6); line.position = Vector2(at2.x, at2.y); line.size = Vector2(1, CELL.y); v2.add_child(line)
		var line2 := ColorRect.new(); line2.color = Color(1, 1, 1, 0.6); line2.position = Vector2(at2.x, at2.y); line2.size = Vector2(CELL.x, 1); v2.add_child(line2)
		var lab := Label.new(); lab.text = l[1]; lab.position = Vector2(at2.x + 6, at2.y + 4)
		lab.add_theme_font_size_override("font_size", 15); lab.add_theme_color_override("font_color", Color(1, 1, 1))
		lab.add_theme_color_override("font_outline_color", Color(0, 0, 0)); lab.add_theme_constant_override("outline_size", 5)
		v2.add_child(lab)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var final := v2.get_texture().get_image()
	var path := ProjectSettings.globalize_path(_out) if _out.begins_with("res://") else _out
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := final.save_jpg(path, 0.88)
	print("buildings sheet: %s (%s)" % [path, error_string(err)])
	quit()

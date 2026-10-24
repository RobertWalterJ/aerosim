extends SceneTree
## Contact sheets of the Blender vehicles (game/vehicle_assets.gd) in the game's own shaders. Needs a window (not headless):
## Godot --path <godot dir> --resolution 480x270 -s res://test/vehicles_blender_sheet.gd -- [names=a,b] [views=front34,side,rear34,top,interior,wheel,tail]
##        [light=golden|overcast|backlit|wet] [cols=N] [cell=WxH] [out=<jpg>] [strip=<name>] [title=<text>] [lights=1]
## views: front34 side rear34 top interior (through the side glass) wheel (front wheel close) tail (tail lamp close) front rear.
## strip=<name> renders the animation frame strip instead: wheels rolling, steering left and right, doors (and the vehicle's
## other actions) at five points of each.

var CELL := Vector2i(480, 300)
var COLS := 4
var _views: Array = ["front34", "rear34"]
var _out := ""
var _light := "golden"
var _names: Array = []
var _strip := ""
var _title := ""
var _lamps := false
var _mixed := false

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
		if a.begins_with("light="): _light = a.substr(6)
		if a.begins_with("cols="): COLS = int(a.substr(5))
		if a.begins_with("views="): _views = Array(a.substr(6).split(","))
		if a.begins_with("strip="): _strip = a.substr(6)
		if a.begins_with("title="): _title = a.substr(6).replace("_", " ")
		if a == "lights=1": _lamps = true
		if a == "mixed=1": _mixed = true
		if a.begins_with("cell="):
			var p := a.substr(5).split("x")
			CELL = Vector2i(int(p[0]), int(p[1]))
		if a.begins_with("names="):
			for n in a.substr(6).split(","): _names.append(n)
	if _names.is_empty():
		_names = VehicleAssets.names()
		_names.sort()
	if _out == "": _out = "res://docs/realism/models/vehicles_%s.jpg" % (_light if _strip == "" else "strip_" + _strip)
	Grass.add_globals()
	RenderingServer.global_shader_parameter_add("g_csun", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0.0, 0.0, 0.0, 0.0))
	RenderingServer.global_shader_parameter_set("g_cloud", Vector4(0.0, 0.0, 0.0, 0.0))
	RenderingServer.global_shader_parameter_set("g_dsB", Vector4(0.0, 0.0, 1.0, 1.0))
	RenderingServer.global_shader_parameter_set("g_time", 3.0)
	_run.call_deferred()

var vp: SubViewport
var key: DirectionalLight3D
var env: Environment
var cam: Camera3D
var ground_mat: StandardMaterial3D

func _set_light(mode: String) -> void:
	var sky := ProceduralSkyMaterial.new()
	RenderingServer.global_shader_parameter_set("g_wet", 1.0 if mode == "wet" else 0.0)
	RenderingServer.global_shader_parameter_set("g_snow", 0.0)
	match mode:
		"golden":
			sky.sky_top_color = Color(0.30, 0.42, 0.65); sky.sky_horizon_color = Color(0.95, 0.68, 0.48)
			sky.ground_horizon_color = Color(0.55, 0.42, 0.33); sky.ground_bottom_color = Color(0.2, 0.17, 0.15)
			key.light_energy = 2.6; key.light_color = Color(1.0, 0.72, 0.46); key.rotation_degrees = Vector3(-21, -38, 0)
			env.ambient_light_energy = 0.8
		"backlit":
			sky.sky_top_color = Color(0.32, 0.45, 0.68); sky.sky_horizon_color = Color(0.98, 0.78, 0.56)
			sky.ground_horizon_color = Color(0.5, 0.42, 0.35); sky.ground_bottom_color = Color(0.2, 0.17, 0.15)
			key.light_energy = 3.0; key.light_color = Color(1.0, 0.8, 0.58); key.rotation_degrees = Vector3(-20, 150, 0)
			env.ambient_light_energy = 0.7
		"wet":
			sky.sky_top_color = Color(0.40, 0.43, 0.48); sky.sky_horizon_color = Color(0.58, 0.6, 0.63)
			sky.ground_horizon_color = Color(0.35, 0.36, 0.37); sky.ground_bottom_color = Color(0.2, 0.2, 0.2)
			key.light_energy = 0.35; key.light_color = Color(0.85, 0.9, 1.0); key.rotation_degrees = Vector3(-50, -30, 0)
			env.ambient_light_energy = 0.95
		_:
			sky.sky_top_color = Color(0.58, 0.62, 0.68); sky.sky_horizon_color = Color(0.72, 0.75, 0.78)
			sky.ground_horizon_color = Color(0.5, 0.5, 0.48); sky.ground_bottom_color = Color(0.3, 0.3, 0.28)
			key.light_energy = 0.0; key.rotation_degrees = Vector3(-60, -38, 0)
			env.ambient_light_energy = 1.1
	var skyres := Sky.new(); skyres.sky_material = sky
	env.sky = skyres
	key.shadow_enabled = mode != "overcast"
	# the ground: dry tarmac, or wet and glossy
	ground_mat.albedo_color = Color(0.12, 0.12, 0.12) if mode == "wet" else Color(0.22, 0.22, 0.21)
	ground_mat.roughness = 0.12 if mode == "wet" else 0.95
	ground_mat.metallic_specular = 0.6 if mode == "wet" else 0.4

func _setup() -> void:
	vp = SubViewport.new()
	vp.size = CELL; vp.own_world_3d = true; vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.positional_shadow_atlas_size = 2048
	root.add_child(vp)
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssr_enabled = true
	var we := WorldEnvironment.new(); we.environment = env; vp.add_child(we)
	key = DirectionalLight3D.new()
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	vp.add_child(key)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(120, 120)
	ground.mesh = pm
	ground_mat = StandardMaterial3D.new()
	var asphalt := load("res://assets/textures/asphalt_diff.jpg") as Texture2D
	if asphalt:
		ground_mat.albedo_texture = asphalt
		ground_mat.uv1_scale = Vector3(24, 24, 1)
	ground.material_override = ground_mat
	vp.add_child(ground)
	cam = Camera3D.new(); cam.fov = 30.0; cam.current = true
	vp.add_child(cam)

func _aabb(v: Node3D) -> AABB:
	var d := VehicleAssets.info(String(v.get_meta("vehicle", "")))
	if d.has("aabb_lo"):
		var lo: Vector3 = VehicleAssets._v3(d["aabb_lo"]); var hi: Vector3 = VehicleAssets._v3(d["aabb_hi"])
		return AABB(lo, hi - lo)
	return AABB(Vector3(-1, 0, -2), Vector3(2, 1.5, 4))

## Put the camera for a named view of the vehicle v (box in its frame, front -z).
func _view(v: Node3D, view: String) -> void:
	var box := _aabb(v)
	var c := box.get_center()
	var r := box.size.length() * 0.5
	var dir := Vector3(0.75, 0.32, -1.0)
	var fov := 30.0
	var target := c
	var dist := 0.0
	match view:
		"front34": dir = Vector3(0.85, 0.3, -1.0)
		"rear34": dir = Vector3(-0.85, 0.35, 1.0)
		"side": dir = Vector3(1.0, 0.08, 0.0)
		"front": dir = Vector3(0.0, 0.12, -1.0)
		"rear": dir = Vector3(0.0, 0.15, 1.0)
		"top": dir = Vector3(0.12, 1.0, 0.25)
		"interior":
			# close to the front side window, looking in and across
			var d := VehicleAssets.info(String(v.get_meta("vehicle", "")))
			target = Vector3(-0.1, box.size.y * 0.62, box.position.z + box.size.z * 0.42)
			cam.fov = 55.0
			cam.position = target + Vector3(box.size.x * 0.5 + 0.55, 0.35, 0.35)
			cam.look_at(target, Vector3.UP)
			cam.near = 0.05; cam.far = 80.0
			return
		"wheel":
			var w := _wheel_pos(v, true)
			cam.fov = 32.0
			cam.position = w + Vector3(1.6, 0.25, -0.6)
			cam.look_at(w, Vector3.UP)
			cam.near = 0.05; cam.far = 60.0
			return
		"tail":
			target = Vector3(box.end.x - 0.3, box.size.y * 0.55, box.end.z)
			cam.fov = 34.0
			cam.position = target + Vector3(0.9, 0.25, 1.6)
			cam.look_at(target, Vector3.UP)
			cam.near = 0.05; cam.far = 60.0
			return
	cam.fov = fov
	dist = r / sin(deg_to_rad(fov * 0.5)) * 0.92
	cam.position = target + dir.normalized() * dist
	cam.near = dist * 0.01; cam.far = dist * 8.0
	cam.look_at(target, Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3(0, 0, -1))
	key.directional_shadow_max_distance = dist * 2.5

func _wheel_pos(v: Node3D, front: bool) -> Vector3:
	var d := VehicleAssets.info(String(v.get_meta("vehicle", "")))
	var best := Vector3(0.8, 0.3, -1.2)
	for w in d.get("wheels", []):
		var p: Vector3 = VehicleAssets._v3(w["pos"])
		if p.x > 0.0 and (bool(w["steer"]) == front):
			best = p
	return best

func _shoot() -> Image:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img

func _run() -> void:
	_setup()
	_set_light(_light)
	var cells: Array = []        # [image, label]
	if _strip != "":
		cells = await _strip_cells(_strip)
	else:
		var k := 0
		for nm in _names:
			for view in _views:
				var lt := _light
				if _mixed: lt = ["golden", "overcast", "backlit", "wet"][k % 4]
				_set_light(lt)
				var v := VehicleAssets.instance(String(nm))
				vp.add_child(v)
				if _lamps: VehicleAssets.set_lights(v, {"head": 1.0, "tail": 1.0, "beacon_red": 1.0, "beacon_blue": 1.0})
				_view(v, String(view))
				var img := await _shoot()
				cells.append([img, "%s  %s%s" % [nm, view, ("  (" + lt + ")") if _mixed else ""]])
				v.free()
				k += 1
	await _compose(cells)
	quit()

func _strip_cells(nm: String) -> Array:
	var out: Array = []
	var v := VehicleAssets.instance(nm)
	vp.add_child(v)
	var d := VehicleAssets.info(nm)
	# wheels rolling: the front wheel close up, turned by quarter turns
	var r := 0.3
	for w in d.get("wheels", []):
		r = float(w["radius"])
	for k in 5:
		VehicleAssets.roll(v, k * 0.25 * PI * 0.5 * r * 2.0)
		_view(v, "wheel")
		out.append([await _shoot(), "%s  roll %d deg" % [nm, k * 45]])
	VehicleAssets.roll(v, -float(v.get_meta("roll")))
	# steering: from above
	for a in [-30.0, -15.0, 0.0, 15.0, 30.0]:
		VehicleAssets.steer(v, deg_to_rad(a))
		_view(v, "top")
		out.append([await _shoot(), "%s  steer %+d deg (+ = left)" % [nm, int(a)]])
	VehicleAssets.steer(v, 0.0)
	# every baked animation that opens something, at 0, 25, 50, 75 and 100 per cent
	var acts: Array = d.get("actions", [])
	for an in acts:
		var s := String(an)
		if not (s.ends_with("_open") or s == "wipers" or s == "tip_raise" or s == "pto_spin"):
			continue
		for t in [0.0, 0.25, 0.5, 0.75, 1.0]:
			VehicleAssets.pose(v, s, t)
			_view(v, "front34" if not s.begins_with("tailgate") and not s.begins_with("boot") and not s.begins_with("rear") and not s.begins_with("tip") else "rear34")
			out.append([await _shoot(), "%s  %s %d%%" % [nm, s, int(t * 100)]])
	v.free()
	return out

func _compose(cells: Array) -> void:
	var rows := int(ceil(cells.size() / float(COLS)))
	var top := 46 if _title != "" else 0
	var sheet := Image.create(CELL.x * COLS, CELL.y * rows + top, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.11))
	for i in cells.size():
		var at := Vector2i((i % COLS) * CELL.x, (i / COLS) * CELL.y + top)
		sheet.blit_rect(cells[i][0], Rect2i(Vector2i.ZERO, CELL), at)
	var v2 := SubViewport.new()
	v2.size = sheet.get_size(); v2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(v2)
	var tr := TextureRect.new(); tr.texture = ImageTexture.create_from_image(sheet); v2.add_child(tr)
	if _title != "":
		var tl := Label.new(); tl.text = _title; tl.position = Vector2(14, 8)
		tl.add_theme_font_size_override("font_size", 24); tl.add_theme_color_override("font_color", Color(1, 1, 1))
		v2.add_child(tl)
	for i in cells.size():
		var at2 := Vector2((i % COLS) * CELL.x, (i / COLS) * CELL.y + top)
		var lab := Label.new(); lab.text = cells[i][1]; lab.position = at2 + Vector2(8, 5)
		lab.add_theme_font_size_override("font_size", 15); lab.add_theme_color_override("font_color", Color(1, 1, 1))
		lab.add_theme_color_override("font_outline_color", Color(0, 0, 0)); lab.add_theme_constant_override("outline_size", 5)
		v2.add_child(lab)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var final := v2.get_texture().get_image()
	var path := ProjectSettings.globalize_path(_out) if _out.begins_with("res://") else _out
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	print("WROTE sheet: %s (%s)" % [path, error_string(final.save_jpg(path, 0.88))])

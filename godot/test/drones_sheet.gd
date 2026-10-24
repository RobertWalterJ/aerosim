extends SceneTree
## Contact sheet of the Blender drones in the game's own renderer (lane/drones): each drone from the front, side,
## three-quarter, top and below, and close-ups of the motor, cameras, gimbal, stack, battery and night-vision pod, in a
## low golden-hour sun or an overcast sky. Loaded through DroneAssets, so this is the look the game gets. Needs a window:
## Godot --path <godot dir> --resolution 480x270 -s res://test/drones_sheet.gd -- [light=golden|overcast] [out=<jpg>] [lod=0]

var CELL := Vector2i(480, 360)
var COLS := 5
var _light := "golden"
var _out := ""
var _lod := 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("light="): _light = a.substr(6)
		if a.begins_with("out="): _out = a.substr(4)
		if a.begins_with("lod="): _lod = int(a.substr(4))
	if _out == "": _out = "res://docs/realism/models/drones_views_%s.jpg" % _light
	Grass.add_globals()
	_run.call_deferred()

## [title, model, view direction (from the target towards the camera, file frame: +z is the nose, right is -x),
##  target node ("" = middle of the model), distance factor or metres]
func _entries() -> Array:
	var out: Array = []
	for nm in ["raptor_race_a", "nightowl_a"]:
		var t := "Raptor" if nm == "raptor_race_a" else "Night Owl"
		out.append([t + " front", nm, Vector3(0.0, 0.16, 1.0), "", 1.0])
		out.append([t + " side", nm, Vector3(-1.0, 0.12, 0.0), "", 1.0])
		out.append([t + " three-quarter", nm, Vector3(-0.75, 0.55, 0.85), "", 1.0])
		out.append([t + " top", nm, Vector3(0.0, 1.0, 0.02), "", 1.0])
		out.append([t + " rear, low", nm, Vector3(0.55, 0.12, -1.0), "", 1.0])
	out.append(["Raptor motor and prop", "raptor_race_a", Vector3(-0.7, 0.6, 0.9), "prop_fr", 0.085])
	out.append(["Raptor FPV camera", "raptor_race_a", Vector3(-0.35, 0.25, 1.0), "camera_lens", 0.085])
	out.append(["Raptor action camera", "raptor_race_a", Vector3(-0.6, 0.45, 1.0), "action_cam_lens", 0.1])
	out.append(["Raptor stack and wiring", "raptor_race_a", Vector3(-1.0, 0.32, -0.2), "status_led", 0.1])
	out.append(["Raptor battery and leads", "raptor_race_a", Vector3(0.55, 0.6, -0.9), "battery", 0.16])
	out.append(["Night Owl gimbal", "nightowl_a", Vector3(-0.75, 0.05, 1.0), "gimbal_pitch", 0.1])
	out.append(["Night Owl motor", "nightowl_a", Vector3(0.7, 0.55, 0.9), "prop_fl", 0.075])
	out.append(["Night Owl NV pod, landing light", "nightowl_a", Vector3(0.4, -0.25, 1.0), "nv_pod", 0.17])
	out.append(["Night-vision pod", "night_vision_pod_a", Vector3(-0.5, 0.3, 1.0), "", 1.25])
	out.append(["Night-vision pod, back", "night_vision_pod_a", Vector3(0.6, 0.35, -1.0), "", 1.25])
	return out

func _box(n: Node, xf: Transform3D, box: Array) -> void:
	var t := xf
	if n is Node3D: t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var bb: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		box[0] = bb if box[0] == null else (box[0] as AABB).merge(bb)
	for c in n.get_children(): _box(c, t, box)

func _pos(n: Node, top: Node) -> Vector3:
	var p := Vector3.ZERO
	var q := n
	while q != null and q != top and q is Node3D:
		p = (q as Node3D).transform * p
		q = q.get_parent()
	return p

func _run() -> void:
	var entries := _entries()
	var rows := int(ceil(entries.size() / float(COLS)))
	var sheet := Image.create(CELL.x * COLS, CELL.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.11))
	var vp := SubViewport.new()
	vp.size = CELL; vp.own_world_3d = true; vp.msaa_3d = Viewport.MSAA_8X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.positional_shadow_atlas_size = 4096
	root.add_child(vp)
	var env := Environment.new()
	var sky := ProceduralSkyMaterial.new()
	var key := DirectionalLight3D.new()
	if _light == "golden":
		sky.sky_top_color = Color(0.30, 0.42, 0.65); sky.sky_horizon_color = Color(0.95, 0.68, 0.48)
		sky.ground_horizon_color = Color(0.55, 0.42, 0.33); sky.ground_bottom_color = Color(0.2, 0.17, 0.15)
		key.light_energy = 2.4; key.light_color = Color(1.0, 0.74, 0.5); key.rotation_degrees = Vector3(-14, -38, 0)
		env.ambient_light_energy = 0.75
	else:
		sky.sky_top_color = Color(0.58, 0.62, 0.68); sky.sky_horizon_color = Color(0.72, 0.75, 0.78)
		sky.ground_horizon_color = Color(0.5, 0.5, 0.48); sky.ground_bottom_color = Color(0.3, 0.3, 0.28)
		key.light_energy = 0.35; key.light_color = Color(0.9, 0.93, 1.0); key.rotation_degrees = Vector3(-62, -38, 0)
		env.ambient_light_energy = 1.1
	var skyres := Sky.new(); skyres.sky_material = sky
	env.background_mode = Environment.BG_SKY; env.sky = skyres
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true; env.ssao_radius = 0.02; env.ssao_intensity = 1.5
	var we := WorldEnvironment.new(); we.environment = env; vp.add_child(we)
	key.shadow_enabled = true
	key.shadow_bias = 0.002; key.shadow_normal_bias = 0.4
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	vp.add_child(key)
	# a concrete launch pad with a little texture, as on the Blender sheets
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(20, 20)
	ground.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.36, 0.36, 0.34); gm.roughness = 0.9
	var nt := NoiseTexture2D.new(); var fn := FastNoiseLite.new(); fn.frequency = 0.08; nt.noise = fn; nt.seamless = true
	gm.albedo_texture = nt; gm.uv1_scale = Vector3(40, 40, 40)
	ground.material_override = gm
	vp.add_child(ground)
	var cam := Camera3D.new(); cam.fov = 30.0; cam.current = true
	vp.add_child(cam)
	var holder := Node3D.new(); vp.add_child(holder)
	var labels: Array = []
	var cell := 0
	for e in entries:
		for ch in holder.get_children(): ch.free()
		var nm: String = e[1]
		var inst := DroneAssets.instance(nm, _lod)
		holder.add_child(inst)
		var lift := 0.06 if nm == "night_vision_pod_a" else 0.0
		inst.position = Vector3(0, lift, 0)
		var box: Array = [null]
		_box(inst, Transform3D.IDENTITY, box)
		var bb: AABB = box[0]
		var centre := bb.get_center()
		var dist := 0.0
		var target := String(e[3])
		if target != "":
			var tn := inst.find_child(target, true, false)
			centre = _pos(tn, holder) if tn != null else centre
			dist = float(e[4])
		else:
			dist = bb.size.length() * 0.5 / sin(deg_to_rad(cam.fov * 0.5)) * 0.62 * float(e[4])
		var dir: Vector3 = (e[2] as Vector3).normalized()
		ground.visible = not (dir.y < -0.05)
		cam.position = centre + dir * dist
		cam.near = dist * 0.02; cam.far = dist * 40.0
		cam.look_at(centre, Vector3.UP if absf(dir.y) < 0.95 else Vector3(0, 0, -1))
		key.directional_shadow_max_distance = maxf(dist * 3.0, 1.0)
		for i in 6: await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var at := Vector2i((cell % COLS) * CELL.x, (cell / COLS) * CELL.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), at)
		labels.append([at, e[0]])
		cell += 1
	vp.queue_free()
	var v2 := SubViewport.new()
	v2.size = sheet.get_size(); v2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(v2)
	var tr := TextureRect.new(); tr.texture = ImageTexture.create_from_image(sheet); v2.add_child(tr)
	for l in labels:
		var at2: Vector2i = l[0]
		var line := ColorRect.new(); line.color = Color(1, 1, 1, 0.5); line.position = Vector2(at2.x, at2.y); line.size = Vector2(1, CELL.y); v2.add_child(line)
		var lab := Label.new(); lab.text = l[1] + ("   (Godot, %s)" % _light if l == labels[0] else "")
		lab.position = Vector2(at2.x + 8, at2.y + 6)
		lab.add_theme_font_size_override("font_size", 17); lab.add_theme_color_override("font_color", Color(1, 1, 1))
		lab.add_theme_color_override("font_outline_color", Color(0, 0, 0)); lab.add_theme_constant_override("outline_size", 5)
		v2.add_child(lab)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var final := v2.get_texture().get_image()
	var path := ProjectSettings.globalize_path(_out) if _out.begins_with("res://") else _out
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := final.save_jpg(path, 0.9)
	print("drones sheet: %s (%s)" % [path, error_string(err)])
	quit()

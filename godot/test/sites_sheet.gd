extends SceneTree
## Contact sheets for lane/sites (boat launch, cabin track and cave). Each asset is loaded the way the game loads it
## (SiteAssets.instance: the .glb with the photographed materials swapped in by name and the LOD ranges set) and photographed
## from the front three-quarter, the side, the rear from above, straight down and a close look, in a low golden sun or under
## an overcast sky. Water assets (dock, marker, floating hull) stand in a water plane at y 0.
## Needs a window (not headless):
## Godot --path <godot dir> --resolution 640x360 -s res://test/sites_sheet.gd -- names=a,b [light=golden|overcast]
##   [mode=views|scene] [cell=420x300] [out=<jpg>] [lod=1]

var CELL := Vector2i(420, 300)
var _out := ""
var _light := "golden"
var _mode := "views"
var _names: Array[String] = []
var _lod1 := false

const VIEWS := [["3/4 front", Vector3(-0.75, 0.42, 1.0), 1.0], ["side", Vector3(-1.0, 0.12, 0.02), 1.0],
	["rear, above", Vector3(0.7, 0.85, -0.9), 1.0], ["top", Vector3(0.0, 1.0, 0.0), 1.0], ["close", Vector3(-0.45, 0.28, 1.0), 0.45]]
const WATER := ["boat_dock", "boat_launch_marker", "boat_aluminium_hull", "boat_aluminium_hull_b"]

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
		if a.begins_with("light="): _light = a.substr(6)
		if a.begins_with("mode="): _mode = a.substr(5)
		if a.begins_with("lod="): _lod1 = a.substr(4) == "1"
		if a.begins_with("cell="):
			var p := a.substr(5).split("x")
			CELL = Vector2i(int(p[0]), int(p[1]))
		if a.begins_with("names="):
			for n in a.substr(6).split(","): _names.append(n)
	if _out == "": _out = "res://docs/realism/models/sites_%s_%s.jpg" % [_mode, _light]
	Grass.add_globals()
	_run.call_deferred()

func _env(vp: SubViewport) -> DirectionalLight3D:
	var env := Environment.new()
	var sky := ProceduralSkyMaterial.new()
	var key := DirectionalLight3D.new()
	if _light == "golden":
		sky.sky_top_color = Color(0.28, 0.42, 0.68); sky.sky_horizon_color = Color(0.95, 0.72, 0.52)
		sky.ground_horizon_color = Color(0.55, 0.45, 0.36); sky.ground_bottom_color = Color(0.22, 0.2, 0.17)
		key.light_energy = 2.4; key.light_color = Color(1.0, 0.76, 0.52); key.rotation_degrees = Vector3(-18, -40, 0)
		env.ambient_light_energy = 0.75
	else:
		sky.sky_top_color = Color(0.6, 0.64, 0.7); sky.sky_horizon_color = Color(0.76, 0.78, 0.8)
		sky.ground_horizon_color = Color(0.5, 0.5, 0.48); sky.ground_bottom_color = Color(0.3, 0.3, 0.28)
		key.light_energy = 0.3; key.rotation_degrees = Vector3(-65, -30, 0)
		env.ambient_light_energy = 1.15
	var skyres := Sky.new(); skyres.sky_material = sky
	env.background_mode = Environment.BG_SKY; env.sky = skyres
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true; env.ssao_radius = 0.6; env.ssao_intensity = 1.4
	var we := WorldEnvironment.new(); we.environment = env; vp.add_child(we)
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	vp.add_child(key)
	return key

func _ground(vp: SubViewport) -> Array:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(200, 200)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = load("res://assets/textures/soil_leaves_diff.jpg")
	gm.normal_enabled = true; gm.normal_texture = load("res://assets/textures/soil_leaves_nor.jpg")
	gm.albedo_color = Color(0.72, 0.7, 0.6)
	gm.uv1_scale = Vector3(80, 80, 80); gm.roughness = 1.0
	ground.material_override = gm
	ground.position = Vector3(0, -0.002, 0)
	vp.add_child(ground)
	var water := MeshInstance3D.new()
	var wm := PlaneMesh.new(); wm.size = Vector2(200, 200)
	water.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.08, 0.13, 0.14, 0.82)
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.roughness = 0.06; wmat.metallic_specular = 0.8
	water.material_override = wmat
	vp.add_child(water)
	return [ground, water]

## "a+b@x_z_yawdeg" builds a group: each part placed at its offset (the cave entrance, the whole launch)
func _make(nm: String) -> Node3D:
	var opts := {"lod_scale": 0.001 if _lod1 else 1000.0}
	if not nm.contains("+") and not nm.contains("@"):
		return SiteAssets.instance(nm, opts)
	var g := Node3D.new()
	for part in nm.split("+"):
		var bits := part.split("@")
		var n := SiteAssets.instance(bits[0], opts)
		if bits.size() > 1:
			var o := bits[1].split("_")
			n.position = Vector3(float(o[0]), 0.0, float(o[1]))
			if o.size() > 2: n.rotation.y = deg_to_rad(float(o[2]))
		g.add_child(n)
	return g

func _run() -> void:
	if _mode == "grid":
		await _grid()
		return
	var cols := VIEWS.size()
	var rows := _names.size()
	var sheet := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGBA8)
	var vp := SubViewport.new()
	vp.size = CELL; vp.own_world_3d = true; vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	root.add_child(vp)
	var key := _env(vp)
	var gw := _ground(vp)
	var ground: MeshInstance3D = gw[0]
	var water: MeshInstance3D = gw[1]
	var cam := Camera3D.new(); cam.fov = 32.0; cam.current = true
	vp.add_child(cam)
	var holder := Node3D.new(); vp.add_child(holder)
	var labels: Array = []
	for ri in rows:
		var nm := _names[ri]
		for ch in holder.get_children(): ch.free()
		var inst := _make(nm)
		holder.add_child(inst)
		var wet := nm in WATER
		water.visible = wet
		ground.position.y = -1.2 if wet else -0.002
		if nm.begins_with("boat_aluminium_hull"): inst.position.y = -0.12
		var box := AABB(); var first := true
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if _lod1 != String(m.name).ends_with("_LOD1") and String(m.name).contains("_LOD"): continue
			var bb: AABB = m.global_transform * m.mesh.get_aabb()
			box = bb if first else box.merge(bb)
			first = false
		if wet:
			# frame what is above the water
			var top := box.end.y
			box.position.y = maxf(box.position.y, -0.3)
			box.size.y = top - box.position.y
		for ci in cols:
			var v: Array = VIEWS[ci]
			var dir: Vector3 = (v[1] as Vector3).normalized()
			var zoom: float = v[2]
			var centre := box.get_center()
			var radius := box.size.length() * 0.5
			if ci == cols - 1:
				centre = box.position + box.size * Vector3(0.45, 0.45, 0.62)
			var dist := radius / sin(deg_to_rad(cam.fov * 0.5)) * 0.95 * zoom
			cam.position = centre + dir * dist
			cam.near = maxf(dist * 0.004, 0.02); cam.far = dist * 10.0 + 50.0
			cam.look_at(centre, Vector3.UP if absf(dir.y) < 0.95 else Vector3(0, 0, -1))
			key.directional_shadow_max_distance = dist * 3.0 + 10.0
			for i in 6: await process_frame
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			var at := Vector2i(ci * CELL.x, ri * CELL.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), at)
			labels.append([at, (nm.split("+")[0].split("@")[0] + ("  (group)" if nm.contains("+") else "") + "  " if ci == 0 else "") + String(v[0])])
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
		lab.add_theme_font_size_override("font_size", 14); lab.add_theme_color_override("font_color", Color(1, 1, 1))
		lab.add_theme_color_override("font_outline_color", Color(0, 0, 0)); lab.add_theme_constant_override("outline_size", 5)
		v2.add_child(lab)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var final := v2.get_texture().get_image()
	var path := ProjectSettings.globalize_path(_out) if _out.begins_with("res://") else _out
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := final.save_jpg(path, 0.88)
	print("sites sheet: %s (%s)" % [path, error_string(err)])
	quit()


## mode=grid: one three-quarter view per asset, GRID_COLS across (the final overview sheet)
var GRID_COLS := 7
func _grid() -> void:
	var n := _names.size()
	var rows := int(ceil(float(n) / GRID_COLS))
	var sheet := Image.create(CELL.x * GRID_COLS, CELL.y * rows, false, Image.FORMAT_RGBA8)
	var vp := SubViewport.new()
	vp.size = CELL; vp.own_world_3d = true; vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var key := _env(vp)
	var gw := _ground(vp)
	var ground: MeshInstance3D = gw[0]
	var water: MeshInstance3D = gw[1]
	var cam := Camera3D.new(); cam.fov = 32.0; cam.current = true
	vp.add_child(cam)
	var holder := Node3D.new(); vp.add_child(holder)
	var labels: Array = []
	for i in n:
		var nm := _names[i]
		for ch in holder.get_children(): ch.free()
		var inst := _make(nm)
		holder.add_child(inst)
		var wet := nm in WATER
		water.visible = wet
		ground.position.y = -1.2 if wet else -0.002
		if nm.begins_with("boat_aluminium_hull"): inst.position.y = -0.12
		var box := AABB(); var first := true
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if String(m.name).ends_with("_LOD1"): continue
			var bb: AABB = m.global_transform * m.mesh.get_aabb()
			box = bb if first else box.merge(bb)
			first = false
		if wet:
			var top := box.end.y
			box.position.y = maxf(box.position.y, -0.3)
			box.size.y = top - box.position.y
		var dir := Vector3(-0.75, 0.5, 1.0).normalized()
		var centre := box.get_center()
		var dist := box.size.length() * 0.5 / sin(deg_to_rad(cam.fov * 0.5)) * 0.9
		cam.position = centre + dir * dist
		cam.near = maxf(dist * 0.004, 0.02); cam.far = dist * 10.0 + 50.0
		cam.look_at(centre, Vector3.UP)
		key.directional_shadow_max_distance = dist * 3.0 + 10.0
		for f in 6: await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		var at := Vector2i((i % GRID_COLS) * CELL.x, (i / GRID_COLS) * CELL.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), at)
		labels.append([at, nm.split("+")[0].split("@")[0] + (" (group)" if nm.contains("+") else "")])
	vp.queue_free()
	var v2 := SubViewport.new()
	v2.size = sheet.get_size(); v2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(v2)
	var tr := TextureRect.new(); tr.texture = ImageTexture.create_from_image(sheet); v2.add_child(tr)
	for l in labels:
		var at2: Vector2i = l[0]
		var lab := Label.new(); lab.text = l[1]; lab.position = Vector2(at2.x + 6, at2.y + 4)
		lab.add_theme_font_size_override("font_size", 14); lab.add_theme_color_override("font_color", Color(1, 1, 1))
		lab.add_theme_color_override("font_outline_color", Color(0, 0, 0)); lab.add_theme_constant_override("outline_size", 5)
		v2.add_child(lab)
	for f in 4: await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(_out) if _out.begins_with("res://") else _out
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := v2.get_texture().get_image().save_jpg(path, 0.87)
	print("sites sheet: %s (%s)" % [path, error_string(err)])
	quit()

extends SceneTree
## Contact sheet of the second batch of models (game/new_models2.gd): every model from three angles on a neutral background,
## for checking by eye. Not part of the game (test/ is left out of exports). Needs a window (not headless):
## Godot --path <godot dir> --resolution 480x270 -s res://test/new_models2_sheet.gd -- [out=<jpg>] [only=<title word>]

const CELL := Vector2i(400, 300)
const COLS := 6
var _out := "res://docs/realism/models/new_models2_sheet.jpg"
var _only := ""

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
		if a.begins_with("only="): _only = a.substr(5)
	_run.call_deferred()

## Each entry: a title and three cells; each cell: the meshes (with where they go) and the direction the camera looks from.
func _entries() -> Array:
	var I := Transform3D.IDENTITY
	var q34 := Vector3(0.8, 0.5, -1.0)          # front three-quarter, from above
	var side := Vector3(1.0, 0.08, 0.0)
	var top := Vector3(0.15, 1.0, 0.35)
	var out: Array = []
	var bn := [[NewModels2.barn(), I]]
	out.append(["barn (12 x 24 m)", [[bn, Vector3(0.9, 0.35, -1.0)], [bn, Vector3(-1.0, 0.2, 0.7)], [bn, Vector3(0.5, 1.0, -0.6)]]])
	var si := [[NewModels2.silo(), I]]
	out.append(["silo (18 m)", [[si, Vector3(-1.0, 0.3, -0.5)], [si, Vector3(1.0, 0.1, 0.4)], [si, top]]])
	var wm := NewModels2.windmill()
	var wmp := [[wm["tower"], I], [wm["cap"], I], [wm["sails"], Transform3D(Basis(Vector3(0, 0, 1), 0.35), wm["sail_pivot"])]]
	out.append(["Dutch windmill (16 m tower)", [[wmp, Vector3(0.7, 0.3, -1.0)], [wmp, Vector3(-1.0, 0.15, 0.6)], [wmp, Vector3(0.4, 1.0, -0.5)]]])
	var wp := NewModels2.wind_pump()
	var wpp := [[wp["tower"], I], [wp["tail"], I], [wp["wheel"], Transform3D(Basis.IDENTITY, wp["wheel_pivot"])]]
	out.append(["wind pump (12 m)", [[wpp, Vector3(0.8, 0.3, -1.0)], [wpp, Vector3(1.0, 0.1, 0.0)], [[[wp["wheel"], I], [wp["tail"], Transform3D(Basis.IDENTITY, -wp["wheel_pivot"])]], Vector3(0.5, 0.4, -1.0)]]])
	var tr := NewModels2.freight_train(4)
	var trk := NewModels2.track_section()
	var train := [[trk, I], [trk, Transform3D(Basis.IDENTITY, Vector3(0, 0, 20))], [trk, Transform3D(Basis.IDENTITY, Vector3(0, 0, 40))], [trk, Transform3D(Basis.IDENTITY, Vector3(0, 0, 60))]]
	for c in tr["consist"]:
		train.append([tr[c[0]], Transform3D(Basis.IDENTITY, Vector3(0, 0, float(c[1]) - 8.0))])
	out.append(["freight train on track", [[train, Vector3(0.6, 0.35, -0.5)], [train, Vector3(1.0, 0.25, 0.0)], [train, Vector3(0.3, 1.0, 0.2)]]])
	var lo := [[tr["locomotive"], I], [trk, I]]
	out.append(["locomotive (21 m)", [[lo, Vector3(0.8, 0.3, -1.0)], [lo, Vector3(1.0, 0.1, 0.05)], [lo, Vector3(-0.7, 0.5, 0.8)]]])
	out.append(["boxcar, hopper", [[[[tr["boxcar"], I]], Vector3(0.9, 0.3, -1.0)], [[[tr["hopper"], I]], Vector3(0.9, 0.3, -1.0)], [[[tr["hopper"], I]], Vector3(1.0, 0.05, 0.0)]]])
	out.append(["tanker, flatcars", [[[[tr["tanker"], I]], Vector3(0.9, 0.3, -1.0)], [[[tr["flatcar"], I]], Vector3(0.9, 0.4, -1.0)], [[[tr["flatcar_empty"], I], [trk, I]], Vector3(0.9, 0.5, -1.0)]]])
	out.append(["track section (20 m)", [[[[trk, I]], Vector3(0.5, 0.4, -1.0)], [[[trk, I]], Vector3(1.0, 0.15, 0.4)], [[[trk, I]], top]]])
	var hc := NewModels2.helicopter()
	var hp := [[hc["body"], I], [hc["main_rotor"], Transform3D(Basis(Vector3.UP, 0.4), hc["rotor_pivot"])], [hc["tail_rotor"], Transform3D(Basis(Vector3.RIGHT, 0.6), hc["tail_pivot"])]]
	out.append(["rescue helicopter", [[hp, Vector3(0.8, 0.35, -1.0)], [hp, Vector3(-1.0, 0.1, 0.1)], [hp, Vector3(0.3, 1.0, 0.3)]]])
	var hb := [[hc["body"], I]]
	out.append(["helicopter body, close", [[hb, Vector3(0.6, 0.2, -1.0)], [hb, Vector3(1.0, 0.15, 0.2)], [hb, Vector3(-0.8, 0.4, 1.0)]]])
	var al := [[NewModels2.airliner_far(), I]]
	out.append(["airliner (far, 38 m)", [[al, Vector3(0.7, 0.4, -1.0)], [al, Vector3(0.3, -1.0, 0.25)], [al, Vector3(1.0, 0.05, 0.0)]]])
	var k0 := [[NewModels2.kite(0), I]]; var k1 := [[NewModels2.kite(1), I]]
	out.append(["kites: diamond, delta", [[k0, Vector3(0.3, 0.2, -1.0)], [k0, Vector3(1.0, 0.1, 0.3)], [k1, Vector3(0.3, 0.2, -1.0)]]])
	var fl := NewModels2.flag(0); var fl1 := NewModels2.flag(1)
	var fp := [[fl["pole"], I], [fl["cloth"], Transform3D(Basis.IDENTITY, fl["cloth_origin"])]]
	out.append(["flag (9 m), cloth, kite line", [[fp, Vector3(0.4, 0.15, -1.0)], [[[fl1["cloth"], I]], Vector3(0.2, 0.2, 1.0)],
		[[[NewModels2.kite(1), I], [NewModels2.kite_line(), Transform3D(Basis.IDENTITY.scaled(Vector3(1, 1, 3)), Vector3.ZERO)]], Vector3(1.0, 0.4, 0.2)]]])
	var deb := NewModels2.debris_pieces()
	var dp: Array = []
	for k in deb.size(): dp.append([deb[k], Transform3D(Basis.IDENTITY, Vector3((k % 3) * 1.6 - 1.6, 0, (k / 3) * 1.2))])
	out.append(["storm debris (6 pieces)", [[dp, Vector3(0.2, 1.0, 0.6)], [dp, Vector3(0.6, 0.5, -1.0)], [[[deb[3], I], [deb[5], Transform3D(Basis.IDENTITY, Vector3(0.4, 0, 0))]], Vector3(0.3, 0.8, -0.6)]]])
	var fu := [[NewModels2.funnel_tube(), I]]
	out.append(["funnel tube, ring disc", [[fu, Vector3(1.0, 0.1, 0.0)], [fu, Vector3(0.4, 0.8, -0.6)], [[[NewModels2.funnel_ring_disc(), I]], Vector3(0.3, 0.8, -0.6)]]])
	return out

func _run() -> void:
	var entries := _entries()
	if _only != "":
		var keep: Array = []
		for e in entries:
			if (e[0] as String).contains(_only): keep.append(e)
		entries = keep
	var rows := int(ceil(entries.size() * 3.0 / COLS))
	var sheet := Image.create(CELL.x * COLS, CELL.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.6, 0.62, 0.65))
	var vp := SubViewport.new()
	vp.size = CELL; vp.own_world_3d = true; vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.6, 0.62, 0.65)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.75, 0.8, 0.9); env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new(); we.environment = env; vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_energy = 2.0; key.light_color = Color(1.0, 0.97, 0.92); key.rotation_degrees = Vector3(-50, -35, 0); key.shadow_enabled = true
	vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.6; fill.light_color = Color(0.7, 0.8, 1.0); fill.rotation_degrees = Vector3(30, 150, 0)
	vp.add_child(fill)
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
			var dist := radius / sin(deg_to_rad(cam.fov * 0.5)) * 1.0
			cam.position = centre + dir * dist
			cam.near = dist * 0.01; cam.far = dist * 4.0
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
	# the titles, drawn over the sheet by a 2D viewport
	var v2 := SubViewport.new()
	v2.size = sheet.get_size(); v2.render_target_update_mode = SubViewport.UPDATE_ALWAYS; v2.transparent_bg = false
	root.add_child(v2)
	var tr := TextureRect.new(); tr.texture = ImageTexture.create_from_image(sheet); v2.add_child(tr)
	for l in labels:
		var at2: Vector2i = l[0]
		var line := ColorRect.new(); line.color = Color(1, 1, 1, 0.5); line.position = Vector2(at2.x, at2.y); line.size = Vector2(1, CELL.y); v2.add_child(line)
		if l[1] == "": continue
		var lab := Label.new(); lab.text = l[1]; lab.position = Vector2(at2.x + 8, at2.y + 6)
		lab.add_theme_font_size_override("font_size", 18); lab.add_theme_color_override("font_color", Color(0.05, 0.05, 0.08))
		v2.add_child(lab)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var final := v2.get_texture().get_image()
	var path := ProjectSettings.globalize_path(_out) if _out.begins_with("res://") else _out
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := final.save_jpg(path, 0.88)
	print("contact sheet: %s (%s)" % [path, error_string(err)])
	quit()

extends SceneTree
## Contact sheet of the new models (game/new_models.gd): every model from three angles on a neutral background, for checking
## by eye. Not part of the game (test/ is left out of exports). Needs a window (not headless):
## Godot --path <godot dir> --resolution 480x270 -s res://test/new_models_sheet.gd -- [out=<jpg>]

const CELL := Vector2i(400, 300)
const COLS := 6
var _out := "res://docs/realism/models/new_models_sheet.jpg"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): _out = a.substr(4)
	_run.call_deferred()

## Each entry: a title and three cells; each cell: the meshes (with where they go) and the direction the camera looks from.
func _entries() -> Array:
	var I := Transform3D.IDENTITY
	var q34 := Vector3(0.8, 0.5, -1.0)          # front three-quarter, from above
	var side := Vector3(1.0, 0.08, 0.0)
	var top := Vector3(0.15, 1.0, 0.35)
	var below := Vector3(0.35, -0.85, -0.45)     # how birds are mostly seen from a drone
	var pl := NewModels.plane()
	var plane_parts := [[pl["body"], I], [pl["prop"], Transform3D(Basis.IDENTITY, pl["prop_pivot"])]]
	var out: Array = []
	out.append(["FPV plane (1.1 m)", [[plane_parts, q34], [plane_parts, side], [plane_parts, Vector3(-0.9, 0.7, 0.8)]]])
	for kind in ["goose", "gull", "starling", "hawk"]:
		var b := [[NewModels.bird(kind, 0.25), I]]
		out.append([kind + " (glide pose)", [[[[NewModels.bird(kind, 0.125), I]], q34], [b, below], [b, top]]])
	var bal := NewModels.balloon(0)
	var bp := [[bal["envelope"], I], [bal["basket"], I]]
	out.append(["balloon, scheme 0", [[bp, Vector3(1.0, 0.25, -0.6)], [bp, Vector3(0.2, -0.6, -1.0)], [[[bal["basket"], I]], Vector3(0.7, 0.9, -0.8)]]])
	var s1 := NewModels.balloon(1); var s2 := NewModels.balloon(2)
	out.append(["balloon, schemes 1 and 2", [[[[s1["envelope"], I], [s1["basket"], I]], Vector3(1.0, 0.2, -0.6)], [[[s2["envelope"], I], [s2["basket"], I]], Vector3(1.0, 0.2, -0.6)],
		[[[s2["envelope"], I]], Vector3(0.1, 1.0, 0.2)]]])
	var d := NewModels.deer()
	var du := [[d["body"], I], [d["head_up"], I]]
	var dd := [[d["body"], I], [d["head_down"], I]]
	out.append(["deer, head up (alert)", [[du, Vector3(-1.0, 0.35, -0.9)], [du, Vector3(-1.0, 0.05, 0.0)], [[[d["body_flag"], I], [d["head_up"], I]], Vector3(0.7, 0.4, 1.0)]]])
	out.append(["deer, head down (grazing)", [[dd, Vector3(-1.0, 0.35, -0.9)], [dd, Vector3(-1.0, 0.05, 0.0)], [dd, Vector3(0.4, 1.0, 0.5)]]])
	var g := [NewModels.bird("goose", 0.0), NewModels.bird("goose", 0.5), NewModels.bird("goose", 0.75)]
	out.append(["goose wing beat: 0, 0.5, 0.75", [[[[g[0], I]], Vector3(0.2, 0.15, -1.0)], [[[g[1], I]], Vector3(0.2, 0.15, -1.0)], [[[g[2], I]], Vector3(0.2, 0.15, -1.0)]]])
	var h := [NewModels.bird("hawk", 0.0), NewModels.bird("hawk", 0.5), NewModels.bird("gull", 0.6)]
	out.append(["hawk 0, 0.5 and gull 0.6", [[[[h[0], I]], Vector3(0.3, 0.2, -1.0)], [[[h[1], I]], Vector3(0.3, 0.2, -1.0)], [[[h[2], I]], Vector3(0.6, 0.6, -1.0)]]])
	var bg := [[NewModels.barge(), I]]
	out.append(["launch barge (12 x 5 m)", [[bg, Vector3(1.0, 0.7, -1.0)], [bg, Vector3(1.0, 0.15, 0.0)], [bg, Vector3(0.1, 1.0, 0.3)]]])
	var sh := [[NewModels.firework_shell_proxy(), I]]
	out.append(["firework shell (6 cm)", [[sh, q34], [sh, side], [sh, top]]])
	return out

func _run() -> void:
	var entries := _entries()
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
			var dist := radius / sin(deg_to_rad(cam.fov * 0.5)) * 0.82
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

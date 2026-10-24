extends SceneTree
## Blender 2 people, close views in Godot (the game's own materials, skeletons, clips and props):
##   Godot --path godot --resolution 640x800 -s res://test/people_sheet.gd -- out=<dir> names=a,b,c [views=front,threeq,side,back,face] [light=golden|overcast|backlit] [t=0.3]
## Writes <dir>/<name>_<view>_<light>.png. Not headless (it renders).

var out_dir := "user://people_sheet"
var names: PackedStringArray = []
var views: PackedStringArray = ["front", "threeq"]
var light := "golden"
var t_frac := 0.3

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out_dir = a.substr(4)
		elif a.begins_with("names="): names = a.substr(6).split(",")
		elif a.begins_with("views="): views = a.substr(6).split(",")
		elif a.begins_with("light="): light = a.substr(6)
		elif a.begins_with("t="): t_frac = float(a.substr(2))
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.22, 0.26, 0.15)
	gm.roughness = 0.95
	ground.material_override = gm
	world.add_child(ground)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	for nm in names:
		var n := PeopleAssets.instance(nm)
		if n == null:
			n = StoryAssets.instance(nm)
		world.add_child(n)
		var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for k in 3: await process_frame
		if ap != null and ap.current_animation != "":
			ap.seek(ap.current_animation_length * t_frac, true)
			ap.pause()
		var top := 1.75
		var head := Vector3(0, 1.6, 0)
		var skel := n.find_child("Skeleton3D", true, false) as Skeleton3D
		if skel != null:
			head = skel.global_transform * skel.get_bone_global_pose(skel.find_bone("Head")).origin + Vector3(0, 0.08, 0)
			top = head.y + 0.12
		for v in views:
			var yaw := {"front": 0.0, "threeq": 0.7, "side": PI * 0.5, "back": PI, "face": 0.35}.get(v, 0.0) as float
			var target := Vector3(0, top * 0.5, 0)
			var dist := 1.8 * top + 0.8
			if nm == "crowd_band_a": dist = 7.0; target = Vector3(0, 0.9, -0.3)
			if v == "face":
				target = head + Vector3(0, -0.05, 0)
				dist = 0.75
			cam.fov = 40.0 if v != "face" else 30.0
			cam.global_position = target + Vector3(sin(yaw) * dist, 0.05 if v == "face" else 0.15, cos(yaw) * dist)
			cam.look_at(target)
			var sy := yaw
			match light:
				"golden":
					sun.light_color = Color(1.0, 0.8, 0.6); sun.light_energy = 2.0
					sun.rotation = Vector3(deg_to_rad(-10), sy + 0.7, 0)
					psm.sky_top_color = Color(0.35, 0.5, 0.75); psm.sky_horizon_color = Color(0.9, 0.75, 0.6); psm.ground_horizon_color = Color(0.5, 0.45, 0.4)
				"overcast":
					sun.light_energy = 0.15
					sun.rotation = Vector3(deg_to_rad(-60), sy, 0)
					psm.sky_top_color = Color(0.62, 0.65, 0.7); psm.sky_horizon_color = Color(0.72, 0.74, 0.76); psm.ground_horizon_color = Color(0.5, 0.5, 0.5)
					psm.sky_energy_multiplier = 1.4
				"backlit":
					sun.light_color = Color(1.0, 0.85, 0.7); sun.light_energy = 2.4
					sun.rotation = Vector3(deg_to_rad(-14), sy + PI + 0.3, 0)
					psm.sky_top_color = Color(0.35, 0.5, 0.75); psm.sky_horizon_color = Color(0.95, 0.8, 0.65)
			for k in 4: await process_frame
			var img := root.get_texture().get_image()
			img.save_png(out_dir.path_join("%s_%s_%s.png" % [nm, v, light]))
		n.queue_free()
		await process_frame
	print("people sheet done: ", out_dir)
	quit()

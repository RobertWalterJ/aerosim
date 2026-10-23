extends SceneTree
## Development probe for the tree models: prints each part's material name, the swapped shader and its textures.
## Run: Godot --headless --path . -s test/tree_probe.gd

func _init() -> void:
	for n in ["trees/maple_red_l0", "trees/spruce_a_l0", "trees/far_broadleaf"]:
		var parts := Assets.parts(n)
		for p in parts:
			var mesh: Mesh = p["mesh"]
			for i in mesh.get_surface_count():
				var m := mesh.surface_get_material(i)
				var info := "%s surface %d: %s" % [n, i, m]
				if m is ShaderMaterial:
					var sm := m as ShaderMaterial
					info += " shader=%s albedo=%s normal=%s" % [sm.shader.resource_path, sm.get_shader_parameter("albedo_tex"), sm.get_shader_parameter("normal_tex")]
				elif m != null:
					info += " name='%s'" % m.resource_name
				print(info)
	quit()

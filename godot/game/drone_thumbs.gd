class_name DroneThumbs
extends RefCounted
## A small picture of each drone for the drone chooser: the real model, lit from above and seen from the front and a little
## to the side, rendered once into a texture on a transparent background.

const SIZE := Vector2i(320, 192)

## Returns {airframe id: ImageTexture}. Call from a node in the tree; it waits a few frames per drone.
static func render_all(host: Node, ids: Array) -> Dictionary:
	var out := {}
	for id in ids:
		var af := Airframes.make(id)
		var vp := SubViewport.new()
		vp.size = SIZE
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.msaa_3d = Viewport.MSAA_4X
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		host.add_child(vp)
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.78, 0.84, 0.95)
		env.ambient_light_energy = 0.75
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		var we := WorldEnvironment.new(); we.environment = env; vp.add_child(we)
		var key := DirectionalLight3D.new()
		key.light_energy = 2.2; key.light_color = Color(1.0, 0.97, 0.92)
		key.rotation_degrees = Vector3(-48, -35, 0)
		vp.add_child(key)
		var fill := DirectionalLight3D.new()
		fill.light_energy = 0.7; fill.light_color = Color(0.7, 0.8, 1.0)
		fill.rotation_degrees = Vector3(-20, 150, 0)
		vp.add_child(fill)
		var view := DroneView.new()
		vp.add_child(view)
		view.build(af)
		view.update_props(PackedFloat64Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]), 0.0, false)
		var extent: float = float(af["armD"]) * 1.41 + float(af["R"])
		var cam := Camera3D.new()
		cam.fov = 28.0
		cam.current = true
		vp.add_child(cam)
		var dist := extent * 1.35 / tan(deg_to_rad(cam.fov * 0.5)) * 0.40
		var dir := Vector3(0.75, 0.62, -1.0).normalized()
		cam.position = dir * dist + Vector3(0, extent * 0.04, 0)
		cam.look_at(Vector3(0, extent * 0.02, 0), Vector3.UP)
		for i in 4: await host.get_tree().process_frame
		var img := vp.get_texture().get_image()
		vp.queue_free()
		out[id] = ImageTexture.create_from_image(img)
	return out

extends SceneTree
## Headless: builds the named story models and prints triangle counts, sizes and build time. -- names=a,b,c [group=x] [lod=0]
func _initialize() -> void:
	Grass.add_globals()
	var names: Array[String] = []
	var lod := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("names="):
			for n in a.substr(6).split(","): names.append(n)
		if a.begins_with("group="):
			for n in NewModels6.names():
				if NewModels6.group_of(n) == a.substr(6): names.append(n)
		if a.begins_with("lod="): lod = int(a.substr(4))
	if names.is_empty(): names = NewModels6.names()
	for nm in names:
		var t0 := Time.get_ticks_msec()
		var m := NewModels6.mesh(nm, lod)
		var tris := 0
		var bad := false
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			tris += pos.size() / 3
			for p in pos:
				if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)): bad = true
		var bb := m.get_aabb()
		print("%-34s tris %5d  size %.2f x %.2f x %.2f  y %.2f..%.2f  %d ms %s" % [nm, tris, bb.size.x, bb.size.y, bb.size.z, bb.position.y, bb.end.y, Time.get_ticks_msec() - t0, "NAN!" if bad else ""])
	quit()

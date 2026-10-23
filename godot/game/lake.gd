class_name Lake
extends MeshInstance3D
## The big lake in the long basin on the west side of the valley. Its outline is not drawn by hand: it is the part of the
## land that lies below the water level and is joined to the basin (worked out once from the height data and saved as
## assets/world/lake_mask.png, one pixel per 7.8 m). The water sheet is built only over that outline, so the shore is wherever
## the land really meets the water level, and the ground shader paints mud, sand and rock along it. Trees, graves and
## other props are kept out of the water with `is_wet`.

const LEVEL := 76.0
const N := 512
const SIZE := 4000.0

static var _mask: Image
static var _wet_grow: PackedByteArray      # the mask grown by about two cells, so nothing stands in the water or on the very edge

static func _load() -> void:
	if _mask != null: return
	var tex := load("res://assets/world/lake_mask.png") as Texture2D
	if tex != null: _mask = tex.get_image()
	if _mask == null: _mask = Image.load_from_file(ProjectSettings.globalize_path("res://assets/world/lake_mask.png"))
	if _mask == null:
		_mask = Image.create(N, N, false, Image.FORMAT_L8)
	if _mask.is_compressed(): _mask.decompress()
	_mask.convert(Image.FORMAT_L8)
	var raw := _mask.get_data()
	var w := _mask.get_width()
	var grown := PackedByteArray(); grown.resize(w * w)
	for y in w:
		for x in w:
			if raw[y * w + x] > 127:
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						var xx := x + dx; var yy := y + dy
						if xx >= 0 and yy >= 0 and xx < w and yy < w: grown[yy * w + xx] = 1
	_wet_grow = grown

## True where a tree, grave or prop must not stand: in the lake or within about two cells (16 m) of the water's edge.
static func is_wet(x: float, z: float) -> bool:
	_load()
	var w := _mask.get_width()
	var ix := int((x / SIZE + 0.5) * w)
	var iz := int((z / SIZE + 0.5) * w)
	if ix < 0 or iz < 0 or ix >= w or iz >= w: return false
	return _wet_grow[iz * w + ix] == 1

func build(terrain: Terrain) -> void:
	_load()
	var raw := _mask.get_data()
	var w := _mask.get_width()
	var cs := SIZE / float(w)
	var verts := PackedVector3Array(); var idx := PackedInt32Array()
	# a cell gets water if it, or a neighbour, is water: the land hides the spare edge, so the shore is exact
	for y in w:
		for x in w:
			var any := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var xx := x + dx; var yy := y + dy
					if xx >= 0 and yy >= 0 and xx < w and yy < w and raw[yy * w + xx] > 127: any = true
			if not any: continue
			var x0 := -SIZE * 0.5 + x * cs; var z0 := -SIZE * 0.5 + y * cs
			var b := verts.size()
			verts.append(Vector3(x0, LEVEL, z0)); verts.append(Vector3(x0 + cs, LEVEL, z0))
			verts.append(Vector3(x0, LEVEL, z0 + cs)); verts.append(Vector3(x0 + cs, LEVEL, z0 + cs))
			idx.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = m
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/shaders/water.gdshader")
	mat.set_shader_parameter("uLevel", LEVEL)
	mat.set_shader_parameter("uHeight", terrain.height_tex)   # session B: depth tint and shore foam read the real ground
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-SIZE * 0.5, LEVEL - 2.0, -SIZE * 0.5), Vector3(SIZE, 4.0, SIZE))

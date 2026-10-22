class_name Lake
extends MeshInstance3D
## The lake in the low ground to the west of the park: a flat sheet of water at the height the valley floor floods to.
## The water shader leaves out the woods (no tree stands in water) and the ground shader draws mud, sand and rocks along the
## shore. The level and extent were chosen from the valley's height data (the lowest 8% of the land, one connected basin).

const LEVEL := 68.9
const CENTRE := Vector2(-850.0, 100.0)
const SIZE := Vector2(1000.0, 2800.0)

func build(terrain: Terrain) -> void:
	var pm := PlaneMesh.new()
	pm.size = SIZE
	pm.subdivide_width = 1; pm.subdivide_depth = 1
	mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://game/shaders/water.gdshader")
	m.set_shader_parameter("uCover", terrain.cover_tex)
	m.set_shader_parameter("uSize", Terrain.SIZE)
	material_override = m
	position = Vector3(CENTRE.x, LEVEL, CENTRE.y)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-SIZE.x * 0.5, -2, -SIZE.y * 0.5), Vector3(SIZE.x, 4, SIZE.y))

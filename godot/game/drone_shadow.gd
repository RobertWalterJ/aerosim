class_name DroneShadow
extends Node
## The drone's shadow on the ground, so you can judge its height and where it is. The ground, the grass and the leaves darken
## in their own shaders around the shadow's position (see cloud_shadow.gdshaderinc), so grass blades go dark too. Two parts:
## a sharp plan silhouette (body, arms, motors and faint spinning props) that turns with the drone and fades as it climbs,
## and a soft blob that grows, softens and stretches along the light as the drone rises or the sun sinks. The light is the sun
## by day and the moon by night; cloud takes the shadow away.

var _terrain: Terrain
var _armd := 0.1
var _r := 0.064

func setup(af: Dictionary, terrain: Terrain) -> void:
	_terrain = terrain
	_armd = float(af["armD"])
	_r = float(af["R"])

## drone_pos: where the drone is; heading: its yaw; light_dir: unit vector towards the light; strength 0..1.
func update(drone_pos: Vector3, heading: float, light_dir: Vector3, strength: float) -> void:
	if _terrain == null: return
	if strength < 0.01 or light_dir.y < 0.02:
		RenderingServer.global_shader_parameter_set("g_dsB", Vector4(0, 0, 1, 1))
		return
	# where the line from the drone along the light meets the land
	var ly := maxf(light_dir.y, 0.08)
	var p := drone_pos
	var gy := _terrain.height(p.x, p.z)
	for i in 3:
		var h0 := maxf(drone_pos.y - gy, 0.0)
		var kk := h0 / ly
		p = Vector3(drone_pos.x - light_dir.x * kk, 0.0, drone_pos.z - light_dir.z * kk)
		gy = _terrain.height(p.x, p.z)
	var h := maxf(drone_pos.y - gy, 0.0)
	var span := (_armd * 1.4142 + _r) * 2.0
	var hl := Vector2(light_dir.x, light_dir.z)
	hl = hl.normalized() if hl.length() > 1e-4 else Vector2(0, 1)
	var detail_a := strength * 0.8 * (1.0 - smoothstep(1.2, 9.0, h))
	var blob_a := strength * 0.7 / (1.0 + h / 14.0)
	var blob_w := span * (1.5 + h * 0.08)
	RenderingServer.global_shader_parameter_set("g_dsA", Vector4(p.x, p.z, heading, _armd))
	RenderingServer.global_shader_parameter_set("g_dsB", Vector4(detail_a, blob_a, blob_w, clampf(1.0 / ly, 1.0, 3.2)))
	RenderingServer.global_shader_parameter_set("g_dsC", Vector4(-hl.x, -hl.y, _r, drone_pos.y))

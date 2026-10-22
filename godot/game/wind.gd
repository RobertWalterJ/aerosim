class_name Wind
extends RefCounted
## Wind at a point: a logarithmic profile with height plus drifting gusts. Wind speed, gustiness and direction
## are set from the pause menu. `from_deg` is the compass bearing the wind blows FROM (0 = north = -z).

var speed := 1.0            # m/s at 30 m above the ground
var gust := 0.45            # 0 steady .. 1 gusty
var from_deg := 250.0
var _noise := FastNoiseLite.new()
const Z0 := 0.05
const KAPPA := 0.4
const REF_H := 30.0

func _init() -> void:
	_noise.seed = 5
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.02

func toward() -> Vector3:
	var f := deg_to_rad(from_deg)
	return Vector3(-sin(f), 0.0, cos(f))

func sample(pos: Vector3, agl: float, t: float) -> Vector3:
	var u_star := speed * KAPPA / log(REF_H / Z0)
	var prof := maxf(0.0, (u_star / KAPPA) * log(maxf(agl, 0.12) / Z0)) * (1.0 + 0.25 * smoothstep(20.0, 120.0, agl))
	var ti := (0.10 + 0.22 * exp(-agl / 12.0)) * gust
	var d := toward()
	var adv := t * speed * 0.8
	var gx := _noise.get_noise_3d(pos.x * 1.0 - d.x * adv, pos.y * 2.0, pos.z * 1.0 - d.z * adv)
	var fast := _noise.get_noise_3d(pos.x * 10.0 + t * 65.0, pos.y * 10.0, pos.z * 10.0 - t * 45.0)
	var u := prof * maxf(0.1, 1.0 + ti * 3.2 * gx)
	var w := d * u
	w += Vector3(fast, 0.4 * gx, fast) * ti * u * 0.8
	return w

class_name Wind
extends RefCounted
## Wind at a point: a logarithmic profile with height plus drifting gusts. Wind speed, gustiness and direction
## are set from the pause menu. `from_deg` is the compass bearing the wind blows FROM (0 = north = -z).
##
## The wind struggle (`drive`, called once per physics tick for the drone only): small eddies the size of the
## airframe push one side of the drone harder than the other. That is a body torque the flight controller must
## fight, so the drone wobbles a few degrees and the four motors run unevenly. The torque grows with the airspeed
## times the turbulence (pressure fluctuation), with the drag area and the arm length, and is divided by the
## inertia in the physics, so a light drone is thrown about more than a heavy one. Turbulence is stronger near the
## ground and in the lee of woodland. A gust change also tips the drone downwind for a moment (rotor flapping), and
## a side wind turns the nose a little into the wind (weathervaning). Off (`struggle = false`) leaves the old model.

var speed := 1.0            # m/s at 30 m above the ground
var gust := 0.45            # 0 steady .. 1 gusty
var from_deg := 250.0
var _noise := FastNoiseLite.new()
const Z0 := 0.05
const KAPPA := 0.4
const REF_H := 30.0

# ---- wind struggle state (drone only)
## "Wind effects on the drone": Off / Natural.
var struggle := true
## Comfortable wind for each airframe (m/s at the drone). Above it the display warns "Strong wind".
const COMFORT := {"mini": 8.0, "freestyle": 12.0, "race": 12.0, "cinewhoop": 9.0, "cinema": 14.0}
const TORQUE_K := 0.7       # overall scale of the eddy torque (calibrated by test/wind_test.gd)
const FLAP_K := 0.004       # rotor flapping: body torque per (m/s of gust change) per (N m of hover thrust x rotor radius)
const VANE_L := 0.04        # weathervane: centre of side pressure behind the centre of mass, as a fraction of the arm
var turb := 0.0             # 0..1 how rough the air at the drone is (sound, camera shake, display)
var burst := 0.0            # 0..1 the intermittent gust bursts (the occasional jolt)
var sigma := 0.0            # turbulence velocity at the drone, m/s
var shelter := 0.0          # 0..1 woodland upwind and low enough to be in its lee
var _ou := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])   # two-stage smooth noise for pitch, yaw, roll
var _hp_ref := Vector3.ZERO      # slow-following wind, for the high-passed gust change
var _gh := Vector3.ZERO          # gust puffs (unit noise, about a second long)
const GUST_H := 1.2              # gust puff strength, as a fraction of the turbulence velocity
var _shelter_t := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _log := false                # dev: `windlog` on the command line prints the struggle once a second
var _log_t := 0.0
var _log_acc := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])   # tilt^2 sum, tilt peak, rpm spread sum, count

func _init() -> void:
	_log = OS.get_cmdline_user_args().has("windlog")
	_noise.seed = 5
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.02
	_rng.seed = 4242

func toward() -> Vector3:
	var f := deg_to_rad(from_deg)
	return Vector3(-sin(f), 0.0, cos(f))

## Mean wind speed at height `agl` (log profile, a little stronger up high).
func profile(agl: float) -> float:
	var u_star := speed * KAPPA / log(REF_H / Z0)
	return maxf(0.0, (u_star / KAPPA) * log(maxf(agl, 0.12) / Z0)) * (1.0 + 0.25 * smoothstep(20.0, 120.0, agl))

## Turbulence intensity at height `agl`: rougher near the ground.
func intensity(agl: float) -> float:
	return (0.10 + 0.22 * exp(-agl / 12.0)) * gust

func sample(pos: Vector3, agl: float, t: float) -> Vector3:
	var prof := profile(agl)
	var ti := intensity(agl)
	var d := toward()
	var adv := t * speed * 0.8
	var gx := _noise.get_noise_3d(pos.x * 1.0 - d.x * adv, pos.y * 2.0, pos.z * 1.0 - d.z * adv)
	var fast := _noise.get_noise_3d(pos.x * 10.0 + t * 65.0, pos.y * 10.0, pos.z * 10.0 - t * 45.0)
	var u := prof * maxf(0.1, 1.0 + ti * 3.2 * gx)
	var w := d * u
	w += Vector3(fast, 0.4 * gx, fast) * ti * u * 0.8
	return w

## The wind struggle for the drone, once per physics tick (`dt` seconds), after `quad.wind = sample(...)`.
## Sets `quad.gust_tau` (body torque) and trims the wind in the lee of trees. `terrain` may be null (tests).
func drive(quad, terrain: Terrain, pos: Vector3, agl: float, dt: float) -> void:
	_t += dt
	if not struggle:
		quad.gust_tau = Vector3.ZERO
		turb = 0.0; burst = 0.0; sigma = 0.0; shelter = 0.0
		_hp_ref = quad.wind
		return
	# shelter: woodland upwind, a few times every second (cheap: three map reads)
	_shelter_t -= dt
	if _shelter_t <= 0.0 and terrain != null:
		_shelter_t = 0.25
		var up := -toward()
		var w := 0.0
		w += 0.40 * terrain.cover_at(pos.x + up.x * 8.0, pos.z + up.z * 8.0).x
		w += 0.35 * terrain.cover_at(pos.x + up.x * 20.0, pos.z + up.z * 20.0).x
		w += 0.25 * terrain.cover_at(pos.x + up.x * 40.0, pos.z + up.z * 40.0).x
		shelter = clampf(w, 0.0, 1.0) * (1.0 - smoothstep(8.0, 40.0, agl))
	# in the lee: less mean wind, rougher air
	if shelter > 0.0:
		quad.wind.x *= 1.0 - 0.35 * shelter
		quad.wind.z *= 1.0 - 0.35 * shelter
	var u_mean := profile(agl)
	sigma = intensity(agl) * u_mean * (1.0 + 1.0 * shelter)
	# smooth unit noise: two first-order stages per axis, exact for any dt (correlation about 0.15 s)
	var a := exp(-dt / 0.15)
	var b := sqrt(maxf(1.0 - a * a, 0.0))
	for k in 3:
		_ou[k] = a * _ou[k] + b * _gauss()
		_ou[3 + k] = a * _ou[3 + k] + (1.0 - a) * _ou[k]
	# intermittent bursts: gusty air comes in spells, with calmer spells between
	var env := _noise.get_noise_2d(_t * 9.0, 17.0)
	burst = smoothstep(-0.15, 0.55, env)
	var spell := 0.55 + 0.9 * burst
	# gust puffs at the drone (a few seconds long): they push it off its spot, then position hold brings it back
	var ag := exp(-dt / 2.5)
	var bg := sqrt(maxf(1.0 - ag * ag, 0.0))
	_gh.x = ag * _gh.x + bg * _gauss()
	_gh.y = ag * _gh.y + bg * _gauss()
	_gh.z = ag * _gh.z + bg * _gauss()
	var af: Dictionary = quad.af
	# light airframes are thrown about more than heavy ones (the owner's direction): 1.36 for the Mini, 0.74 for the Cinema
	var susc := clampf(pow(0.6 / float(af["mass"]), 0.35), 0.7, 1.4)
	var gs := GUST_H * sigma / (1.0 + sigma / 6.0) * spell * susc
	quad.wind += Vector3(_gh.x * gs, 0.3 * _gh.y * gs, _gh.z * gs)
	# eddy torque: pressure fluctuation (relative airspeed x turbulence), soft-limited so a storm stays flyable
	var vrel: Vector3 = quad.velocity() - quad.wind
	var x := (vrel.length() + sigma) * sigma
	var xs := x / (1.0 + x / 10.0)
	var dcd: Vector3 = af["dragCd"]; var da: Vector3 = af["dragA"]
	var arm: float = af["armD"]
	var k_t: float = TORQUE_K * 1.41421 * quad.rho * dcd.x * da.x * arm * xs * spell * susc   # 1.41: the second noise stage halves the variance
	var tau := Vector3(_ou[3] * k_t, 0.3 * _ou[4] * k_t, _ou[5] * k_t)
	# rotor flapping on a gust change: the discs tip away from the new wind for a moment (high-passed, 0.5 s)
	var hp: Vector3 = quad.wind - _hp_ref
	_hp_ref += hp * (1.0 - exp(-dt / 0.5))
	var qi: Quaternion = quad.attitude().inverse()
	var g_b := qi * hp
	var k_f: float = FLAP_K * float(af["mass"]) * 9.80665 * float(af["R"])
	tau.x += k_f * g_b.z           # air speeding up from ahead (towards +z) lifts the nose
	tau.z -= k_f * g_b.x           # air speeding up towards the right lifts the left side
	# weathervane: side wind turns the nose a little into the wind (the yaw loop catches it after a few degrees)
	var vb := qi * vrel
	var vh := sqrt(vb.x * vb.x + vb.z * vb.z)
	tau.y += 0.5 * quad.rho * dcd.x * da.x * vh * vb.x * VANE_L * arm
	quad.gust_tau = tau * (1.0 if quad.armed else 0.3)   # props stopped: only the body catches the wind
	turb = clampf(sigma / 3.0, 0.0, 1.0)
	if _log: _log_tick(quad, dt)

func _log_tick(quad, dt: float) -> void:
	var up: Vector3 = quad.attitude() * Vector3.UP
	var tilt := rad_to_deg(acos(clampf(up.y, -1.0, 1.0)))
	var om: PackedFloat64Array = quad.s
	var mo := maxf((om[13] + om[14] + om[15] + om[16]) * 0.25, 1.0)
	var spread := (maxf(maxf(om[13], om[14]), maxf(om[15], om[16])) - minf(minf(om[13], om[14]), minf(om[15], om[16]))) / mo
	_log_acc[0] += tilt * tilt; _log_acc[1] = maxf(_log_acc[1], tilt); _log_acc[2] += spread; _log_acc[3] += 1.0
	_log_t += dt
	if _log_t >= 1.0:
		var n := maxf(_log_acc[3], 1.0)
		print("windlog t=%.0f wind %.1f m/s sigma %.2f turb %.2f burst %.2f shelter %.2f | tilt rms %.1f peak %.1f deg | pos %.1f %.1f %.1f | rpm mean %.0f spread %.1f%% | %.1f A" % [_t, quad.wind.length(), sigma, turb, burst, shelter, sqrt(_log_acc[0] / n), _log_acc[1], quad.s[0], quad.s[1], quad.s[2], mo, 100.0 * _log_acc[2] / n, quad.battery.current])
		_log_t = 0.0; _log_acc.fill(0.0)

const LEVEL_WORDS := ["", "Strong", "Too strong"]
const WARN_WORDS := ["", "Strong wind", "Wind too strong to hold position"]
var _w_avg := 0.0
var _w_level := 0
var _w_told := 0
var _sat_t := 0.0
var _calm_t := 0.0

## The pilot's warning, once a frame. Sets t["windLevel"] (beside the WIND readout) and t["windWarn"] (a quiet line on
## the display). Returns a notice to show once per windy spell, or "". `saturated`: position hold is at its bank limit
## and still being pushed off its spot (FlightController.losing_hold). A spell ends when the wind drops well below the comfortable limit.
func feedback(dt: float, id: String, w_now: float, saturated: bool, t: Dictionary) -> String:
	_w_avg += (w_now - _w_avg) * (1.0 - exp(-dt / 1.5))
	_sat_t = minf(_sat_t + dt, 3.0) if saturated else maxf(_sat_t - dt * 0.5, 0.0)
	var lim: float = COMFORT.get(id, 10.0)
	var lv := warn_level(id, _w_avg, _sat_t > 1.5)
	if lv < _w_level:
		# step down only when clearly calmer, so the words do not flicker at the edge
		if (_w_level == 1 and _w_avg > lim * 0.9) or (_w_level == 2 and _sat_t > 0.3):
			lv = _w_level
	_w_level = lv
	# a windy spell is over after a long calm (about twenty seconds well under the limit); only then can it warn again
	_calm_t = _calm_t + dt if (lv == 0 and _w_avg < lim * 0.75) else 0.0
	if _calm_t > 20.0: _w_told = 0
	t["windLevel"] = LEVEL_WORDS[lv]
	t["windWarn"] = WARN_WORDS[lv]
	if lv > _w_told:
		_w_told = lv
		return str(t["windWarn"])
	return ""

## 0 fine, 1 strong (above the airframe's comfortable wind), 2 too strong to hold position.
## `w` is the smoothed wind speed at the drone; `saturated` is true when the controller has been at its bank limit
## for a while, holding position (so Manual mode, with no position hold, never says "too strong to hold").
static func warn_level(id: String, w: float, saturated: bool) -> int:
	var lim: float = COMFORT.get(id, 10.0)
	if saturated and w > lim * 0.8: return 2     # at the bank limit and still pushed off its spot
	if w > lim: return 1
	return 0

func _gauss() -> float:
	var u := 0.0
	var v := 0.0
	while u == 0.0: u = _rng.randf()
	while v == 0.0: v = _rng.randf()
	return sqrt(-2.0 * log(u)) * cos(TAU * v)

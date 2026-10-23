class_name FPVPlane
extends RefCounted
## Fixed-wing FPV plane, a 6-DOF rigid body with a simple honest aerodynamic model. Shares the Quad's
## interface where the rest of the game reads it (position, velocity, attitude, rates, armed, s[], battery,
## ground_h/n, obstacle_hit, vrs, ang_accel), so it can sit behind the same `quad` handle in main.gd.
## Body frame: +x right, +y up, forward is -z (as the quad). Rates: w.x pitch (nose up +), w.y yaw (left +),
## w.z roll (left +), matching FlightController's signs. cmd = [throttle, elevator, aileron, rudder], -1..1
## (throttle 0..1; elevator +1 pulls up; aileron +1 banks right; rudder +1 yaws right).

const G := 9.80665
const N_STATE := 17

var af: Dictionary
var battery: Battery
## state: pos(3) vel(3) quat xyzw(4) omegaBody(3) motorOmega(1)
var s := PackedFloat64Array()
var prev_pos := Vector3.ZERO
var prev_quat := Quaternion.IDENTITY
var cmd := PackedFloat64Array([0.5, 0.0, 0.0, 0.0])
var armed := true
var crashed := false
var crash_reason := ""
var ground_contact := false
var max_impact := 0.0
var rho := 1.225
var vrs := 0.0
var ang_accel := Vector3.ZERO
var p_elec := 0.0

# environment, set by the caller before step()
var wind := Vector3.ZERO
var gust_tau := Vector3.ZERO
var ground_h: Callable
var ground_n: Callable
var obstacle_hit: Callable

# OSD outputs
var airspeed := 0.0
var alpha := 0.0
var on_ground := false

var _rng := RandomNumberGenerator.new()
var _turb := Vector3.ZERO
var _gh0 := 0.0
var _gn := Vector3.UP
var _k: Array[PackedFloat64Array] = []
var _tmp := PackedFloat64Array()

class Battery extends RefCounted:
	var cells: int
	var capacity_ah: float
	var r_int: float
	var soc := 1.0
	var v_term := 0.0
	var current := 0.0
	var v_oc := 0.0
	func _init(c: int, cap: float, r: float) -> void:
		cells = c; capacity_ah = cap; r_int = r
		v_oc = ocv(1.0) * cells
		v_term = v_oc
	func ocv(soc_in: float) -> float:
		var x := clampf(soc_in, 0.0, 1.0)
		if x > 0.9: return 4.05 + (x - 0.9) * 1.5
		if x > 0.2: return 3.70 + (x - 0.2) * (0.35 / 0.7)
		if x > 0.05: return 3.45 + (x - 0.05) * (0.25 / 0.15)
		return 3.0 + x * 9.0
	func update(p_elec_w: float, dt: float) -> void:
		v_oc = ocv(soc) * cells
		var disc := maxf(v_oc * v_oc - 4.0 * r_int * p_elec_w, 0.25 * v_oc * v_oc)
		v_term = (v_oc + sqrt(disc)) / 2.0
		current = p_elec_w / v_term
		soc = maxf(0.0, soc - (current * dt) / (capacity_ah * 3600.0))
	func cell_v() -> float:
		return v_term / cells
	func voltage_scale() -> float:
		return v_term / (cells * 4.1)

func _init(airframe: Dictionary) -> void:
	_rng.seed = 2345
	s.resize(N_STATE)
	_tmp.resize(N_STATE)
	for i in 4:
		var k := PackedFloat64Array(); k.resize(N_STATE); _k.append(k)
	ground_h = func(_x: float, _z: float) -> float: return 0.0
	ground_n = func(_x: float, _z: float) -> Vector3: return Vector3.UP
	set_airframe(airframe)
	reset(0.0, 0.0, 0.0, 0.0)

func set_airframe(airframe: Dictionary) -> void:
	af = airframe
	battery = Battery.new(af["cells"], af["capacityAh"], af["rInt"])

func reset(x: float, y: float, z: float, yaw: float) -> void:
	s.fill(0.0)
	s[0] = x; s[1] = y; s[2] = z
	s[6] = 0.0; s[7] = sin(yaw / 2.0); s[8] = 0.0; s[9] = cos(yaw / 2.0)
	prev_pos = Vector3(x, y, z); prev_quat = Quaternion(0, s[7], 0, s[9])
	armed = true; crashed = false; crash_reason = ""; cmd.fill(0.0)
	battery.soc = 1.0; battery.update(0.0, 0.0)

func position() -> Vector3: return Vector3(s[0], s[1], s[2])
func velocity() -> Vector3: return Vector3(s[3], s[4], s[5])
func attitude() -> Quaternion: return Quaternion(s[6], s[7], s[8], s[9])
func rates() -> Vector3: return Vector3(s[10], s[11], s[12])

func omega_cap() -> float:
	return af["omegaMax"] * minf(1.02, battery.voltage_scale())

## Lift coefficient: cambered, linear to the stall angle, then it drops.
func _cl(a: float) -> float:
	var aa := absf(a)
	var stall: float = af["stallA"]
	if aa < stall:
		return float(af["CL0"]) + float(af["CLa"]) * a
	var peak := float(af["CL0"]) + float(af["CLa"]) * stall
	var drop := 1.4 * (aa - stall)
	return signf(a) * maxf(peak - drop, 0.2)

func _deriv(sv: PackedFloat64Array, out: PackedFloat64Array) -> void:
	var m: float = af["mass"]
	var q := Quaternion(sv[6], sv[7], sv[8], sv[9])
	var qi := Quaternion(-sv[6], -sv[7], -sv[8], sv[9])
	var v_rel_b := qi * (Vector3(sv[3], sv[4], sv[5]) - wind)
	var w := Vector3(sv[10], sv[11], sv[12])
	var F := Vector3.ZERO
	var tau := Vector3.ZERO
	var V := v_rel_b.length()
	airspeed = V
	# aerodynamic forces and moments (wind axes resolved to body axes)
	var S: float = af["S"]
	var cbar: float = af["cbar"]
	var b: float = af["span"]
	var qd := 0.5 * rho * V * V
	var fwd := -v_rel_b.z               # forward airspeed along -z
	alpha = atan2(v_rel_b.y, fwd) if V > 1.0 else 0.0
	var beta := atan2(v_rel_b.x, fwd) if V > 1.0 else 0.0
	var cl := _cl(alpha)
	var stalled := absf(alpha) > float(af["stallA"])
	var cd := float(af["CD0"]) + float(af["kD"]) * cl * cl + (0.35 if stalled else 0.0)
	var ca := cos(alpha); var sa := sin(alpha)
	F.y += qd * S * (cl * ca - cd * sa)     # lift (mostly up) minus the drag's vertical part
	F.z += qd * S * (cl * sa + cd * ca)     # drag (backward, +z) plus the lift's rearward part
	F.x -= qd * S * 0.35 * beta            # sideslip side force (nose into the wind)
	# propeller thrust along -z, falling with airspeed
	var om := sv[13]
	var kT: float = float(af["Tmax"]) / (float(af["omegaMax"]) * float(af["omegaMax"]))
	var advance := clampf(fwd / float(af["Vpitch"]), 0.0, 1.2)
	var T := kT * om * om * (1.0 - advance)
	F.z -= T                                # thrust forward (-z)
	# control moments (body): elevator pitch, aileron roll, rudder yaw, plus adverse yaw and damping
	var el := cmd[1]; var ai := cmd[2]; var rd := cmd[3]
	tau.x += qd * S * cbar * (float(af["Cm_a"]) * alpha + float(af["Cm_e"]) * el)   # + = nose up
	tau.z += qd * S * b * (-float(af["Cl_a"]) * ai)                                  # + = roll left
	tau.y += qd * S * b * (-float(af["Cn_r"]) * rd + float(af["Cn_adv"]) * ai)       # rudder yaw + adverse yaw
	tau.x -= qd * S * cbar * 1.4 * w.x       # pitch damping
	tau.y -= qd * S * b * 0.9 * w.y          # yaw damping
	tau.z -= qd * S * b * 0.7 * w.z          # roll damping
	tau += gust_tau
	# weight and integrate
	var fw := q * F
	fw.y -= m * G
	# ground contact: belly skid, normal force plus friction, only near the ground
	ground_contact = false
	on_ground = false
	if sv[1] - _gh0 < 0.25:
		var pos0 := Vector3(sv[0], sv[1], sv[2])
		var cps: Array[Vector3] = [Vector3(0, -0.08, 0.1), Vector3(0, -0.08, -0.4)]
		var n := _gn
		for cp in cps:
			var pw := q * cp
			var p := pos0 + pw
			var pen := float(ground_h.call(p.x, p.z)) - p.y
			if pen <= 0.0: continue
			ground_contact = true; on_ground = true
			var vw := q * w.cross(cp) + Vector3(sv[3], sv[4], sv[5])
			var vn := vw.dot(n)
			var kc := (m * G / 2.0) / 0.02
			var fn := maxf(0.0, kc * minf(pen, 0.05) - 2.0 * 0.6 * sqrt(kc * m / 2.0) * vn)
			var t := vw - n * vn
			var fr := 0.35 * fn / (t.length() + 0.04)   # a skid on the grass
			var f := n * fn - t * fr
			fw += f
			var fb := qi * f
			tau += cp.cross(fb)
	var inertia: Vector3 = af["I"]
	var iw := Vector3(inertia.x * w.x, inertia.y * w.y, inertia.z * w.z)
	var wxiw := w.cross(iw)
	out[0] = sv[3]; out[1] = sv[4]; out[2] = sv[5]
	out[3] = fw.x / m; out[4] = fw.y / m; out[5] = fw.z / m
	var qx := sv[6]; var qy := sv[7]; var qz := sv[8]; var qw := sv[9]
	out[6] = 0.5 * (qw * w.x + qy * w.z - qz * w.y)
	out[7] = 0.5 * (qw * w.y + qz * w.x - qx * w.z)
	out[8] = 0.5 * (qw * w.z + qx * w.y - qy * w.x)
	out[9] = 0.5 * (-qx * w.x - qy * w.y - qz * w.z)
	out[10] = (tau.x - wxiw.x) / inertia.x
	out[11] = (tau.y - wxiw.y) / inertia.y
	out[12] = (tau.z - wxiw.z) / inertia.z
	ang_accel = Vector3(out[10], out[11], out[12])
	# motor follows the throttle with the quad's time constants
	var target := omega_cap() * clampf(cmd[0], 0.0, 1.0)
	var tau_m := float(af["tauUp"]) if target > sv[13] else float(af["tauDown"])
	out[13] = (target - sv[13]) / tau_m

func step(dt: float) -> void:
	prev_pos = Vector3(s[0], s[1], s[2])
	prev_quat = Quaternion(s[6], s[7], s[8], s[9])
	rho = 1.225 * exp(-maxf(s[1], 0.0) / 8500.0)
	_gh0 = ground_h.call(s[0], s[2])
	_gn = ground_n.call(s[0], s[2])
	if not armed: cmd.fill(0.0)
	cmd[0] = clampf(cmd[0], 0.0, 1.0)
	# RK4
	var k1 := _k[0]; var k2 := _k[1]; var k3 := _k[2]; var k4 := _k[3]
	_deriv(s, k1)
	for i in N_STATE: _tmp[i] = s[i] + 0.5 * dt * k1[i]
	_deriv(_tmp, k2)
	for i in N_STATE: _tmp[i] = s[i] + 0.5 * dt * k2[i]
	_deriv(_tmp, k3)
	for i in N_STATE: _tmp[i] = s[i] + dt * k3[i]
	_deriv(_tmp, k4)
	for i in N_STATE: s[i] += (dt / 6.0) * (k1[i] + 2.0 * k2[i] + 2.0 * k3[i] + k4[i])
	# robustness: a degenerate frame (e.g. a wild tumble) must not poison the state
	for i in N_STATE:
		if is_nan(s[i]):
			reset(s[0], 40.0, s[2], 0.0)
			return
	var qn := 1.0 / sqrt(s[6] * s[6] + s[7] * s[7] + s[8] * s[8] + s[9] * s[9])
	for i in range(6, 10): s[i] *= qn
	s[13] = clampf(s[13], 0.0, omega_cap() * 1.05)
	s[14] = 0.0; s[15] = 0.0; s[16] = 0.0
	# electrical power: prop shaft power / efficiency + avionics
	p_elec = (T_nominal() * 14.0) / float(af["motorEff"]) + (2.5 if armed else 0.5)
	battery.update(p_elec, dt)
	if battery.soc <= 0.0 and armed:
		armed = false; crash_reason = "BATTERY DEPLETED"
	_check_impacts()

## nominal thrust at the current throttle, for the battery drain estimate
func T_nominal() -> float:
	var om := s[13]
	var kT: float = float(af["Tmax"]) / (float(af["omegaMax"]) * float(af["omegaMax"]))
	return kT * om * om * clampf(cmd[0], 0.0, 1.0)

func _check_impacts() -> void:
	if crashed: return
	var q := Quaternion(s[6], s[7], s[8], s[9])
	var v_impact := 0.0
	if s[1] - _gh0 < 0.25:
		var cps: Array[Vector3] = [Vector3(0, -0.08, 0.1), Vector3(0, -0.08, -0.4)]
		for cp in cps:
			var pw := q * cp
			var pen := float(ground_h.call(s[0] + pw.x, s[2] + pw.z)) - (s[1] + pw.y)
			if pen > 0.004:
				v_impact = maxf(v_impact, -s[4])
	max_impact = v_impact
	if v_impact > 5.5 and ground_contact:
		_mark_crash("HARD IMPACT %.1f m/s" % v_impact); return
	if obstacle_hit.is_valid():
		var push: Vector3 = obstacle_hit.call(s[0], s[1], s[2], 0.12)
		if push != Vector3.INF:
			s[0] += push.x; s[2] += push.z
			var sp := sqrt(s[3] * s[3] + s[4] * s[4] + s[5] * s[5])
			s[3] *= -0.2; s[5] *= -0.2
			if sp > 2.0: _mark_crash("COLLISION")

func _mark_crash(why: String) -> void:
	crashed = true; armed = false; crash_reason = why; cmd.fill(0.0)

func _gauss() -> float:
	var u := 0.0
	var v := 0.0
	while u == 0.0: u = _rng.randf()
	while v == 0.0: v = _rng.randf()
	return sqrt(-2.0 * log(u)) * cos(TAU * v)

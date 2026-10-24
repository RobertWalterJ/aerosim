class_name Quad
extends RefCounted
## Six-degree-of-freedom quadcopter, ported from Quadcopter6DOF.ts. RK4 integration, a blade-element rotor
## model, a battery with voltage sag, gyroscopic precession, ground contact and crash detection.
## Body frame: +x right, +y up, forward is -z. Quaternions are (x, y, z, w).

const G := 9.80665
const N_STATE := 17
const SPIN: Array[float] = [-1.0, 1.0, -1.0, 1.0]   # FR, RR, RL, FL

var af: Dictionary
var rotor: Rotor
var battery: Battery
## state: pos(3) vel(3) quat xyzw(4) omegaBody(3) motorOmega(4)
var s := PackedFloat64Array()
var prev_pos := Vector3.ZERO
var prev_quat := Quaternion.IDENTITY
var cmd := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
var armed := true
var motor_cut := false             # home landing: props stopped, battery recharging
var crashed := false
var crash_reason := ""
var ground_contact := false
var max_impact := 0.0
var rho := 1.225
var thrust := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
var torque_q := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
var vrs := 0.0
var ge := 1.0
var p_elec := 0.0
var ang_accel := Vector3.ZERO

# environment, set by the caller before step()
var wind := Vector3.ZERO
## body torque from small gust eddies, flapping and weathervaning (game/wind.gd `drive`); zero keeps the web parity
var gust_tau := Vector3.ZERO
var ground_h: Callable            # (x: float, z: float) -> float
var ground_n: Callable            # (x: float, z: float) -> Vector3
var obstacle_hit: Callable        # optional (x, y, z, r) -> Vector3 push, or Vector3.INF for no hit

var rpos: Array[Vector3] = []
var _contact_pts: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()
var _turb := Vector3.ZERO
var _vrs_noise := 0.0
var _n_time := 0.0
var _k: Array[PackedFloat64Array] = []
var _tmp := PackedFloat64Array()
var _gn := Vector3.UP
var _gh0 := 0.0

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
	## scale on achievable motor speed (KV x voltage)
	func voltage_scale() -> float:
		return v_term / (cells * 4.1)

func _init(airframe: Dictionary) -> void:
	_rng.seed = 1234
	s.resize(N_STATE)
	_tmp.resize(N_STATE)
	for i in 4:
		var k := PackedFloat64Array(); k.resize(N_STATE); _k.append(k)
	ground_h = func(_x: float, _z: float) -> float: return 0.0
	ground_n = func(_x: float, _z: float) -> Vector3: return Vector3.UP
	set_airframe(airframe)
	reset(0.0, 0.0, 0.0, 0.0)

## Swap the airframe (used by the drone picker).
func set_airframe(airframe: Dictionary) -> void:
	af = airframe
	rotor = Rotor.new(af)
	battery = Battery.new(af["cells"], af["capacityAh"], af["rInt"])
	var d: float = af["armD"]
	rpos = [Vector3(d, 0, -d), Vector3(d, 0, d), Vector3(-d, 0, d), Vector3(-d, 0, -d)]
	var f := 0.03
	_contact_pts.clear()
	for p in rpos: _contact_pts.append(Vector3(p.x, -f, p.z))
	for p in rpos: _contact_pts.append(Vector3(p.x * 0.8, f + 0.012, p.z * 0.8))

func reset(x: float, y: float, z: float, yaw: float) -> void:
	s.fill(0.0)
	s[0] = x; s[1] = y; s[2] = z
	s[6] = 0.0; s[7] = sin(yaw / 2.0); s[8] = 0.0; s[9] = cos(yaw / 2.0)
	prev_pos = Vector3(x, y, z); prev_quat = Quaternion(0, s[7], 0, s[9])
	armed = true; motor_cut = false; crashed = false; crash_reason = ""; cmd.fill(0.0)
	battery.soc = 1.0; battery.update(0.0, 0.0)

func position() -> Vector3: return Vector3(s[0], s[1], s[2])
func velocity() -> Vector3: return Vector3(s[3], s[4], s[5])
func attitude() -> Quaternion: return Quaternion(s[6], s[7], s[8], s[9])
func rates() -> Vector3: return Vector3(s[10], s[11], s[12])

## cap on motor speed from battery voltage (KV x V)
func omega_cap() -> float:
	return af["omegaMax"] * minf(1.02, battery.voltage_scale())

func _deriv(sv: PackedFloat64Array, out: PackedFloat64Array) -> void:
	var m: float = af["mass"]
	var q := Quaternion(sv[6], sv[7], sv[8], sv[9])
	var qi := Quaternion(-sv[6], -sv[7], -sv[8], sv[9])
	var v_rel_b := qi * (Vector3(sv[3], sv[4], sv[5]) - wind)
	var w := Vector3(sv[10], sv[11], sv[12])
	var F := Vector3.ZERO
	var tau := Vector3.ZERO
	var sum_spin := 0.0
	vrs = 0.0
	for i in 4:
		var r := rpos[i]
		var v := v_rel_b + w.cross(r)   # rotor velocity relative to air, includes w x r
		var rw := q * r
		var z_agl := sv[1] + rw.y - _gh0
		rotor.compute(sv[13 + i], v.y, sqrt(v.x * v.x + v.z * v.z), z_agl, rho, _vrs_noise + 0.35 * sin(i * 1.7 + _n_time * 31.0))
		var T := rotor.T
		thrust[i] = T; torque_q[i] = rotor.Q
		var hx := -rotor.H * v.x    # in-plane H-force opposing edgewise airspeed
		var hz := -rotor.H * v.z
		F.x += hx; F.y += T; F.z += hz
		tau.x += r.y * hz - r.z * T
		tau.y += r.z * hx - r.x * hz
		tau.z += r.x * T - r.y * hx
		tau.y += -SPIN[i] * rotor.Q   # reaction torque
		sum_spin += SPIN[i] * sv[13 + i]
		if i == 0: ge = rotor.ge
		vrs = maxf(0.0 if i == 0 else vrs, rotor.vrs)
	# body drag
	var drag_cd: Vector3 = af["dragCd"]; var drag_a: Vector3 = af["dragA"]
	F.x -= 0.5 * rho * drag_cd.x * drag_a.x * absf(v_rel_b.x) * v_rel_b.x
	F.y -= 0.5 * rho * drag_cd.y * drag_a.y * absf(v_rel_b.y) * v_rel_b.y
	F.z -= 0.5 * rho * drag_cd.z * drag_a.z * absf(v_rel_b.z) * v_rel_b.z
	# gyroscopic precession from rotor angular momentum (about body Y)
	var hr: float = af["Jr"] * sum_spin
	tau.x -= -w.z * hr
	tau.z -= w.x * hr
	tau += _turb   # propwash / VRS turbulence torque
	tau += gust_tau   # wind struggle: gust eddies the controller must fight
	var inertia: Vector3 = af["I"]
	var iw := Vector3(inertia.x * w.x, inertia.y * w.y, inertia.z * w.z)
	var wxiw := w.cross(iw)
	var fw := q * F
	fw.y -= m * G
	# ground contact points: penalty spring-damper with friction. Skipped when well clear of the ground.
	ground_contact = false
	var tau_c := Vector3.ZERO
	if sv[1] - _gh0 < 0.6:
		var kc := (m * G / 4.0) / 0.003
		var cc := 2.0 * 0.55 * sqrt(kc * m / 4.0)
		var n := _gn
		var pos0 := Vector3(sv[0], sv[1], sv[2])
		for cp in _contact_pts:
			var pw := q * cp
			var p := pos0 + pw
			var pen := float(ground_h.call(p.x, p.z)) - p.y
			if pen <= 0.0: continue
			ground_contact = true
			var vw := q * w.cross(cp) + Vector3(sv[3], sv[4], sv[5])
			var vn := vw.dot(n)
			var fn := maxf(0.0, kc * minf(pen, 0.05) - cc * vn)
			var t := vw - n * vn
			var fr := 0.7 * fn / (t.length() + 0.04)
			var f := n * fn - t * fr
			fw += f
			var fb := qi * f
			tau_c += cp.cross(fb)
	tau += tau_c
	if ground_contact: tau -= w * 0.002
	out[0] = sv[3]; out[1] = sv[4]; out[2] = sv[5]
	out[3] = fw.x / m; out[4] = fw.y / m; out[5] = fw.z / m
	# q_dot = 0.5 q (x) (w, 0)
	var qx := sv[6]; var qy := sv[7]; var qz := sv[8]; var qw := sv[9]
	out[6] = 0.5 * (qw * w.x + qy * w.z - qz * w.y)
	out[7] = 0.5 * (qw * w.y + qz * w.x - qx * w.z)
	out[8] = 0.5 * (qw * w.z + qx * w.y - qy * w.x)
	out[9] = 0.5 * (-qx * w.x - qy * w.y - qz * w.z)
	out[10] = (tau.x - wxiw.x) / inertia.x
	out[11] = (tau.y - wxiw.y) / inertia.y
	out[12] = (tau.z - wxiw.z) / inertia.z
	ang_accel = Vector3(out[10], out[11], out[12])
	var tau_up: float = af["tauUp"]; var tau_down: float = af["tauDown"]
	for i in 4:
		var c := cmd[i]
		var o := sv[13 + i]
		out[13 + i] = (c - o) / (tau_up if c > o else tau_down)

func step(dt: float) -> void:
	prev_pos = Vector3(s[0], s[1], s[2])
	prev_quat = Quaternion(s[6], s[7], s[8], s[9])
	rho = 1.225 * exp(-maxf(s[1], 0.0) / 8500.0)
	_gh0 = ground_h.call(s[0], s[2])
	_gn = ground_n.call(s[0], s[2])
	var cap := omega_cap()
	if not armed or motor_cut: cmd.fill(0.0)
	for i in 4: cmd[i] = clampf(cmd[i], 0.0, cap)
	# propwash / VRS stochastic terms, held across the RK stages
	_n_time += dt
	_vrs_noise = 0.8 * _vrs_noise + 0.2 * _gauss() * 0.6
	var spd := sqrt(s[3] * s[3] + s[4] * s[4] + s[5] * s[5])
	var t_amp: float = (0.00015 + 0.0006 * vrs) * float(af["mass"]) * (1.0 + 0.03 * spd) * (4.0 if af["id"] == "freestyle" else 1.0)
	_turb = Vector3(t_amp * _gauss(), 0.2 * t_amp * _gauss(), t_amp * _gauss())
	# RK4
	var k1 := _k[0]; var k2 := _k[1]; var k3 := _k[2]; var k4 := _k[3]
	vrs = 0.0
	_deriv(s, k1)
	for i in N_STATE: _tmp[i] = s[i] + 0.5 * dt * k1[i]
	_deriv(_tmp, k2)
	for i in N_STATE: _tmp[i] = s[i] + 0.5 * dt * k2[i]
	_deriv(_tmp, k3)
	for i in N_STATE: _tmp[i] = s[i] + dt * k3[i]
	_deriv(_tmp, k4)
	for i in N_STATE: s[i] += (dt / 6.0) * (k1[i] + 2.0 * k2[i] + 2.0 * k3[i] + k4[i])
	var qn := 1.0 / sqrt(s[6] * s[6] + s[7] * s[7] + s[8] * s[8] + s[9] * s[9])
	for i in range(6, 10): s[i] *= qn
	for i in 4: s[13 + i] = clampf(s[13 + i], 0.0, cap * 1.05)
	# electrical power: shaft power / efficiency + avionics
	var p_shaft := 0.0
	for i in 4: p_shaft += torque_q[i] * s[13 + i]
	p_elec = p_shaft / float(af["motorEff"]) + (2.5 if armed else 0.5)
	battery.update(p_elec, dt)
	if battery.soc <= 0.0 and armed:
		armed = false; crash_reason = "BATTERY DEPLETED"
	_check_impacts()

func _check_impacts() -> void:
	if crashed: return
	var q := Quaternion(s[6], s[7], s[8], s[9])
	var v_impact := 0.0
	if s[1] - _gh0 < 0.6:
		for i in _contact_pts.size():
			var pw := q * _contact_pts[i]
			var pen := float(ground_h.call(s[0] + pw.x, s[2] + pw.z)) - (s[1] + pw.y)
			if pen > 0.004:
				if i >= 4:
					_mark_crash("INVERTED / BODY STRIKE"); return
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
			if sp > 1.2: _mark_crash("COLLISION")

func _mark_crash(why: String) -> void:
	crashed = true; armed = false; crash_reason = why; cmd.fill(0.0)

func _gauss() -> float:
	var u := 0.0
	var v := 0.0
	while u == 0.0: u = _rng.randf()
	while v == 0.0: v = _rng.randf()
	return sqrt(-2.0 * log(u)) * cos(TAU * v)

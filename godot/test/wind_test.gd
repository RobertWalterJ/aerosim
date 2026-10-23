extends SceneTree
## Headless check of the wind struggle: hover at 10 m in N mode for 60 s per airframe and wind, then take off, hover
## and land with the sticks in the worst wind. Prints a table and asserts the owner's limits.
## Run: Godot_console.exe --headless --path godot -s test/wind_test.gd [-- secs=60 ids=mini,cinema]

const DT := 0.002
const SUB := 4
var fails := 0

func check(name: String, ok: bool, info: String) -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + info)
	if not ok: fails += 1

## The conditions: name, menu wind (m/s), gust, weather multiplier (storm is 2.8x and +0.35 gust).
const CONDS := [["calm", 1.0, 0.45, false], ["breezy", 5.0, 0.85, false], ["strong", 7.5, 1.0, false], ["storm", 1.0, 0.45, true], ["strong storm", 7.5, 1.0, true]]

func make_wind(c: Array) -> Wind:
	var w := Wind.new()
	w.from_deg = 250.0
	w.speed = float(c[1]) * (2.8 if c[3] else 1.0)
	w.gust = clampf(float(c[2]) + (0.35 if c[3] else 0.0), 0.0, 1.0)
	return w

func tick(q: Quad, fc: FlightController, w: Wind, t: float, st: Vector4) -> void:
	var p := q.position()
	var agl := p.y
	q.wind = w.sample(p, maxf(agl, 0.05), t)
	w.drive(q, null, p, maxf(agl, 0.05), DT * SUB)
	fc.on_ground = agl < 0.15
	for i in SUB:
		fc.update(DT, st.x, st.y, st.z, st.w)
		q.step(DT)

## Hover at 10 m with the sticks centred. Returns the measured numbers.
func hover(id: String, c: Array, secs: float, struggle := true, shelter := 0.0, mode := "N") -> Dictionary:
	var af := Airframes.make(id)
	var q := Quad.new(af)
	var fc := FlightController.new(af, q)
	fc.set_step(DT); fc.mode = mode
	var w := make_wind(c)
	w.struggle = struggle; w.shelter = shelter
	var yaw := deg_to_rad(150.0)
	q.reset(0.0, 10.0, 0.0, yaw); fc.heading = yaw
	var wh: float = float(af["omegaMax"]) * sqrt(1.0 / float(af["twr"]))
	for i in 4:
		q.s[13 + i] = wh; q.cmd[i] = wh
	var t := 0.0
	var n := 0
	var ema := Vector2.ZERO
	var sw2 := 0.0; var wpk := 0.0; var sway2 := 0.0
	var pe2 := 0.0; var pemax := 0.0
	var spread := 0.0; var thr := 0.0; var pw := 0.0; var wsum := 0.0; var lean := 0.0
	var hdg0 := 0.0; var hdg_dev := 0.0
	var rec_n := 0; var rec_sum := 0.0; var in_ev := false; var ev_t := 0.0
	var ticks := int(secs / (DT * SUB))
	var settle := int(4.0 / (DT * SUB))
	var hist := PackedFloat32Array()
	var warn := 0
	var tdict := {}
	var toasts := 0
	for k in ticks:
		var st := Vector4.ZERO
		tick(q, fc, w, t, st)
		t += DT * SUB
		if q.crashed: break
		if w.feedback(DT * SUB, id, q.wind.length(), fc.losing_hold(), tdict) != "": toasts += 1
		warn = maxi(warn, ["", "Strong", "Too strong"].find(str(tdict["windLevel"])))
		# tilt as (forward, right) components of the up vector in the heading frame
		var qa := q.attitude()
		var up := qa * Vector3.UP
		var f := qa * Vector3(0, 0, -1)
		var hd := atan2(-f.x, -f.z)
		var fh := Vector3(-sin(hd), 0, -cos(hd)); var rh := Vector3(cos(hd), 0, -sin(hd))
		var tv := Vector2(up.dot(fh), up.dot(rh))
		ema = tv if k == 0 else ema + (tv - ema) * (1.0 - exp(-DT * SUB / 1.0))
		if k < settle:
			hdg0 = hd
			continue
		var sv := rad_to_deg((tv - ema).length())
		sway2 += sv * sv
		var dv := rad_to_deg(fc.tilt_error())
		hist.append(dv)
		sw2 += dv * dv; wpk = maxf(wpk, dv)
		lean += rad_to_deg(asin(clampf(tv.length(), 0.0, 1.0)))
		var pe := Vector2(q.s[0], q.s[2]).length()
		pe2 += pe * pe; pemax = maxf(pemax, pe)
		var om := [q.s[13], q.s[14], q.s[15], q.s[16]]
		var mo: float = (om[0] + om[1] + om[2] + om[3]) / 4.0
		spread += (maxf(maxf(om[0], om[1]), maxf(om[2], om[3])) - minf(minf(om[0], om[1]), minf(om[2], om[3]))) / maxf(mo, 1.0)
		thr += fc.thrust_fraction(); pw += q.p_elec; wsum += q.wind.length()
		hdg_dev = maxf(hdg_dev, absf(rad_to_deg(angle_difference(hdg0, hd))))
		n += 1
	var nn := maxf(n, 1)
	var rms := sqrt(sw2 / nn)
	# recovery: from a big wobble (over twice the RMS) until it is back under half the RMS
	for i in hist.size():
		if not in_ev and hist[i] > 2.0 * rms and rms > 0.05:
			in_ev = true; ev_t = 0.0
		elif in_ev:
			ev_t += DT * SUB
			if hist[i] < 0.5 * rms:
				in_ev = false; rec_n += 1; rec_sum += ev_t
	return {"rms": rms, "peak": wpk, "sway": sqrt(sway2 / nn), "pos_rms": sqrt(pe2 / nn), "pos_max": pemax, "spread": 100.0 * spread / nn, "thr": thr / nn, "pw": pw / nn,
		"wind": wsum / nn, "lean": lean / nn, "crashed": q.crashed, "why": q.crash_reason, "rec": rec_sum / maxf(rec_n, 1), "yaw": hdg_dev, "warn": warn, "toasts": toasts}

## Take off from the ground with the throttle stick, hover, then land with the throttle stick.
func stick_flight(id: String, c: Array) -> Dictionary:
	var af := Airframes.make(id)
	var q := Quad.new(af)
	var fc := FlightController.new(af, q)
	fc.set_step(DT)
	var w := make_wind(c)
	var yaw := deg_to_rad(150.0)
	q.reset(0.0, 0.04, 0.0, yaw); fc.heading = yaw
	var t := 0.0
	var top := 0.0
	var phase := 0
	var landed := false
	for k in int(70.0 / (DT * SUB)):
		var st := Vector4.ZERO
		if t < 3.0: st.x = 1.0
		elif t < 18.0: st.x = 0.0
		else: st.x = -0.7
		tick(q, fc, w, t, st)
		t += DT * SUB
		top = maxf(top, q.s[1])
		if q.crashed: break
		if t > 20.0 and q.s[1] < 0.1 and absf(q.s[4]) < 0.05:
			landed = true; break
	return {"top": top, "landed": landed, "crashed": q.crashed, "why": q.crash_reason, "t": t, "drift": Vector2(q.s[0], q.s[2]).length()}

## A single sharp gust jolt (a 60 ms torque pulse about the roll axis) in still air: how far it tips and how fast it recovers.
func jolt(id: String) -> Dictionary:
	var af := Airframes.make(id)
	var q := Quad.new(af)
	var fc := FlightController.new(af, q)
	fc.set_step(DT)
	q.reset(0.0, 10.0, 0.0, 0.0)
	var wh: float = float(af["omegaMax"]) * sqrt(1.0 / float(af["twr"]))
	for i in 4:
		q.s[13 + i] = wh; q.cmd[i] = wh
	for k in 500: fc.update(DT, 0, 0, 0, 0); q.step(DT)
	var inertia: Vector3 = af["I"]
	var peak := 0.0; var t_peak := 0.0; var t_back := -1.0
	var t := 0.0
	for k in int(2.0 / DT):
		q.gust_tau = Vector3(0, 0, inertia.z * 60.0) if t < 0.06 else Vector3.ZERO
		fc.update(DT, 0, 0, 0, 0); q.step(DT); t += DT
		var tilt := rad_to_deg(acos(clampf((q.attitude() * Vector3.UP).y, -1.0, 1.0)))
		if tilt > peak: peak = tilt; t_peak = t
		elif t_back < 0.0 and tilt < 0.25 * peak: t_back = t
	return {"peak": peak, "back": t_back}

func _init() -> void:
	var secs := 60.0
	var ids: Array = Airframes.IDS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("secs="): secs = float(a.substr(5))
		if a.begins_with("ids="): ids = a.substr(4).split(",")
	var t0 := Time.get_ticks_msec()
	var res := {}
	print("Hover at 10 m, sticks centred, Normal mode, %d s. Wobble = attitude off what the controller wants (deg); sway = all tilt motion off its 1 s mean (deg)." % int(secs))
	print("%-10s %-13s %6s %6s %6s %6s %6s %6s %6s %6s %6s %6s %6s %6s %4s %5s" % ["drone", "wind", "w m/s", "rms", "peak", "sway", "recov", "lean", "posRMS", "posMax", "rpm%", "thr", "watts", "yaw", "warn", "ok"])
	for id in ids:
		for c in CONDS:
			var r := hover(id, c, secs)
			res[id + "/" + str(c[0])] = r
			print("%-10s %-13s %6.1f %6.2f %6.2f %6.2f %6.2f %6.1f %6.2f %6.2f %6.2f %6.2f %6.1f %6.1f %4d %5s" % [id, c[0], r["wind"], r["rms"], r["peak"], r["sway"], r["rec"], r["lean"], r["pos_rms"], r["pos_max"], r["spread"], r["thr"], r["pw"], r["yaw"], r["warn"], "yes" if not r["crashed"] else "NO"])
	# extras: Off in calm, the lee of a wood, and Sport mode
	var off := hover("mini", CONDS[0], secs, false)
	print("mini calm with wind effects Off: rms %.3f peak %.3f posRMS %.2f" % [off["rms"], off["peak"], off["pos_rms"]])
	if ids.has("mini"):
		var lee := hover("mini", CONDS[2], secs, true, 1.0)
		print("mini strong in the lee of a wood: wind %.1f rms %.2f peak %.2f posMax %.2f" % [lee["wind"], lee["rms"], lee["peak"], lee["pos_max"]])
		var sport := hover("mini", CONDS[2], secs, true, 0.0, "S")
		print("mini strong in Sport: rms %.2f peak %.2f posRMS %.2f posMax %.2f" % [sport["rms"], sport["peak"], sport["pos_rms"], sport["pos_max"]])
	# checks
	for id in ids:
		check("calm wobble under 0.3 deg (" + id + ")", float(res[id + "/calm"]["rms"]) < 0.3, "%.3f" % float(res[id + "/calm"]["rms"]))
		for cn in ["storm", "strong storm"]:
			check(cn + " wobble RMS under 6 deg (" + id + ")", float(res[id + "/" + cn]["rms"]) < 6.0, "%.2f" % float(res[id + "/" + cn]["rms"]))
		for c in CONDS:
			var r: Dictionary = res[id + "/" + str(c[0])]
			check("no crash hovering in " + str(c[0]) + " (" + id + ")", not r["crashed"], str(r["why"]))
		check("no wind warning in calm (" + id + ")", int(res[id + "/calm"]["warn"]) == 0, "")
		for c in CONDS:
			check("at most two notices per flight in " + str(c[0]) + " (" + id + ")", int(res[id + "/" + str(c[0])]["toasts"]) <= 2, str(res[id + "/" + str(c[0])]["toasts"]))
	if ids.has("mini"):
		check("Mini: too strong to hold in the strong storm", int(res["mini/strong storm"]["warn"]) == 2, "")
	if ids.has("freestyle"):
		check("Freestyle holds in the strong storm (no too-strong notice)", int(res["freestyle/strong storm"]["warn"]) < 2, "")
	if ids.has("mini") and ids.has("cinema"):
		for cn in ["breezy", "strong", "strong storm"]:
			var m: Dictionary = res["mini/" + cn]; var ci: Dictionary = res["cinema/" + cn]
			check("Mini wobbles more than the Cinema in " + cn, float(m["rms"]) > float(ci["rms"]), "%.2f vs %.2f" % [float(m["rms"]), float(ci["rms"])])
			check("Mini drifts more than the Cinema in " + cn, float(m["pos_rms"]) > float(ci["pos_rms"]), "%.2f vs %.2f m" % [float(m["pos_rms"]), float(ci["pos_rms"])])
	print("One sharp jolt (60 ms, 60 rad/s2): peak tilt, and time from the jolt until back under a quarter of the peak:")
	for id in ids:
		var j := jolt(id)
		print("  %-10s peak %.1f deg, back after %.2f s" % [id, j["peak"], j["back"]])
		check("jolt recovers within 0.7 s (" + id + ")", float(j["back"]) > 0.0 and float(j["back"]) < 0.7, "%.2f s" % float(j["back"]))
	print("Take off, hover and land with the sticks:")
	for id in ids:
		for c in [CONDS[2], CONDS[3], CONDS[4]]:
			var r := stick_flight(id, c)
			print("  %-10s %-13s top %.1f m, landed=%s after %.0f s, drift %.1f m %s" % [id, c[0], r["top"], r["landed"], r["t"], r["drift"], r["why"]])
			check("stick flight in " + str(c[0]) + " (" + id + ")", r["landed"] and not r["crashed"] and float(r["top"]) > 5.0, str(r["why"]))
	print("wall %d ms" % (Time.get_ticks_msec() - t0))
	print("ALL PASS" if fails == 0 else str(fails) + " FAILURES")
	quit(1 if fails else 0)

class_name AutoPilot
extends RefCounted
## The drone's assisted flight, like the buttons in a drone app: Auto Takeoff, Auto Landing and Return to Home.
## It does not touch the physics: it produces stick positions (throttle, yaw, pitch, roll) that the flight controller
## treats as if a pilot held them. Moving a stick yourself cancels Return to Home, as on a real drone.

enum State { NONE, TAKEOFF, LAND, RTH_CLIMB, RTH_FLY, RTH_LAND }

const TAKEOFF_HEIGHT := 1.8
const RTH_HEIGHT := 22.0

var state := State.NONE
var rth_height := RTH_HEIGHT
var message := ""               # set when the state changes: main shows it as a notice

func active() -> bool:
	return state != State.NONE

func cancel(text := "") -> void:
	if state != State.NONE:
		state = State.NONE
		message = text

func start_takeoff() -> void:
	state = State.TAKEOFF; message = "Taking off"

func start_landing() -> void:
	state = State.LAND; message = "Landing"

func start_rth(agl: float) -> void:
	rth_height = maxf(RTH_HEIGHT, agl + 3.0)
	state = State.RTH_CLIMB; message = "Returning to the launch site"

## One step. pos/vel in world metres, heading in radians (fc.heading), agl above the ground, home point (x, z),
## limits from the airframe's current flight mode. Returns Vector4(throttle, yaw, pitch, roll) or Vector4.INF for no control.
func update(pos: Vector3, vel: Vector3, heading: float, agl: float, home: Vector2, vh: float, v_up: float) -> Vector4:
	match state:
		State.NONE:
			return Vector4.INF
		State.TAKEOFF:
			if agl >= TAKEOFF_HEIGHT:
				state = State.NONE; message = "Ready"
				return Vector4(0, 0, 0, 0)
			return Vector4(clampf(1.4 / maxf(v_up, 1.0), 0.15, 0.6), 0, 0, 0)
		State.LAND:
			if agl < 0.12 and absf(vel.y) < 0.3:
				state = State.NONE; message = "Landed"
				return Vector4(-0.2, 0, 0, 0)
			# descend gently, slower near the ground
			var vd := 1.3 if agl > 3.0 else 0.6
			return _hold_xz(vel, heading, vh, Vector4(-clampf(vd / maxf(v_up, 1.0) * 1.4, 0.15, 0.5), 0, 0, 0))
		State.RTH_CLIMB:
			if agl >= rth_height - 1.0:
				state = State.RTH_FLY
			var th := clampf((rth_height - agl) * 0.35, -0.5, 1.0)
			return _hold_xz(vel, heading, vh, Vector4(th, 0, 0, 0))
		State.RTH_FLY:
			var d := home - Vector2(pos.x, pos.z)
			var dist := d.length()
			if dist < 3.0:
				state = State.RTH_LAND; message = "Landing at the launch site"
				return Vector4(0, 0, 0, 0)
			var speed := minf(vh * 0.8, dist * 0.45 + 1.0)
			var v_des := d / dist * speed
			var fwd := Vector2(-sin(heading), -cos(heading))
			var right := Vector2(cos(heading), -sin(heading))
			var v_xz := Vector2(vel.x, vel.z)
			var pitch := clampf((v_des - Vector2.ZERO).dot(fwd) / maxf(vh, 1.0), -1.0, 1.0)
			var roll := clampf((v_des).dot(right) / maxf(vh, 1.0), -1.0, 1.0)
			# turn to face home so the camera looks where it is going
			var want := atan2(-d.x, -d.y)
			var diff := wrapf(want - heading, -PI, PI)
			var yaw := clampf(-diff * 1.2, -0.7, 0.7)
			var th := clampf((rth_height - agl) * 0.35, -0.5, 0.6)
			v_xz = v_xz
			return Vector4(th, yaw, pitch, roll)
		State.RTH_LAND:
			var d2 := home - Vector2(pos.x, pos.z)
			var fwd2 := Vector2(-sin(heading), -cos(heading))
			var right2 := Vector2(cos(heading), -sin(heading))
			var v_des2 := d2 * 0.5
			var pitch2 := clampf(v_des2.dot(fwd2) / maxf(vh, 1.0), -0.3, 0.3)
			var roll2 := clampf(v_des2.dot(right2) / maxf(vh, 1.0), -0.3, 0.3)
			if agl < 0.12 and absf(vel.y) < 0.3:
				state = State.NONE; message = "Landed"
				return Vector4(-0.2, 0, 0, 0)
			var vd2 := 1.3 if agl > 3.0 else 0.6
			return Vector4(-clampf(vd2 / maxf(v_up, 1.0) * 1.4, 0.15, 0.5), 0, pitch2, roll2)
	return Vector4.INF

## Keeps the drone from drifting while it climbs or descends: pushes against the horizontal velocity.
func _hold_xz(vel: Vector3, heading: float, vh: float, base: Vector4) -> Vector4:
	var fwd := Vector2(-sin(heading), -cos(heading))
	var right := Vector2(cos(heading), -sin(heading))
	var v := Vector2(vel.x, vel.z)
	base.z = clampf(-v.dot(fwd) / maxf(vh, 1.0) * 0.3, -0.2, 0.2)
	base.w = clampf(-v.dot(right) / maxf(vh, 1.0) * 0.3, -0.2, 0.2)
	return base

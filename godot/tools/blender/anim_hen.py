# Hen clips: idle (looks about in jerks, fluffs, tail flicks), walk and run (the head holds still in space then
# thrusts forward, as a bird's does), peck (bobs down to the ground and back).
import math
from mathutils import Vector, Quaternion
from anim import blink, set_ctrl, smooth, TAU

def rotw(pb, arm, name, axis, ang):
    """Turn a bone by `ang` about a world axis (x: right-left, so +ang pitches the bone's tip down; z: up)."""
    if name not in pb: return
    R = arm.data.bones[name].matrix_local.to_3x3().inverted()
    b = pb[name]
    b.rotation_quaternion = b.rotation_quaternion @ Quaternion(R @ Vector(axis), ang)

def _lids(pb, arm, t, times):
    b = blink(t, times, 0.12)
    for s in ("_L", "_R"):
        pb["eyelid" + s].rotation_quaternion = pb["eyelid" + s].rotation_quaternion @ Quaternion((0, 1, 0), -math.radians(80) * b)

def _stand(pb, arm):
    for s in ("_L", "_R"):
        set_ctrl(pb, arm, "ctrl_H" + s, 0.0, 0.0, 0.0)

def idle(t, pb, arm, dur):
    _stand(pb, arm)
    # the head snaps between a few positions (birds look in jerks)
    keys = [(0.0, 0.0, 0.0), (0.7, 0.5, -0.1), (1.5, -0.4, 0.1), (2.4, 0.2, 0.25), (3.2, -0.3, -0.05), (4.0, 0.0, 0.0)]
    yaw = pit = 0.0
    for i in range(len(keys) - 1):
        a, b = keys[i], keys[i + 1]
        if a[0] <= t <= b[0]:
            k = smooth(min(1.0, (t - a[0]) / 0.08))           # a quick turn, then a hold
            yaw = a[1] + (b[1] - a[1]) * (k if t - a[0] < 0.08 else 1.0) if False else (a[1] if (t - a[0]) > 0.0 and (b[0] - t) > 0.08 else b[1])
            pit = a[2] if (b[0] - t) > 0.08 else b[2]
    rotw(pb, arm, "neck_03", (0, 0, 1), yaw * 0.6); rotw(pb, arm, "head", (0, 0, 1), yaw * 0.6)
    rotw(pb, arm, "head", (1, 0, 0), pit)
    br = math.sin(TAU * 2 * t / dur)
    rotw(pb, arm, "spine_01", (1, 0, 0), 0.02 * br)
    rotw(pb, arm, "tail_01", (1, 0, 0), -0.1 * math.exp(-((t - 2.8) ** 2) / 0.01))
    _lids(pb, arm, t, (1.0, 3.0))

def walk(t, pb, arm, dur, stride, lift, run=False):
    ph = t / dur
    duty = 0.6 if not run else 0.42
    for s, off in (("_L", 0.0), ("_R", 0.5)):
        p = (ph + off) % 1.0
        if p < duty:
            x = p / duty; fwd = stride * (0.5 - x); up = 0.0; fold = 0.0
        else:
            x = (p - duty) / (1 - duty); fwd = stride * (-0.5 + smooth(x)); up = lift * math.sin(math.pi * x); fold = -0.9 * math.sin(math.pi * x)
        set_ctrl(pb, arm, "ctrl_H" + s, fwd, up, fold)
    # body sways side to side and bobs
    pb["hips"].location = Vector((0.0, 0.0, -0.006 * math.cos(TAU * 2 * ph)))
    rotw(pb, arm, "hips", (0, 1, 0), 0.06 * math.sin(TAU * ph))
    rotw(pb, arm, "hips", (1, 0, 0), 0.08 if run else 0.0)
    # head bob: hold in space during most of each step, thrust forward at the end (twice a cycle)
    h = (ph * 2) % 1.0
    thrust = smooth(h / 0.25) if h < 0.25 else 1.0 - (h - 0.25) / 0.75
    rotw(pb, arm, "neck_01", (1, 0, 0), 0.25 * thrust - 0.1)
    rotw(pb, arm, "neck_02", (1, 0, 0), -0.25 * thrust + 0.05)
    rotw(pb, arm, "head", (1, 0, 0), 0.05 * thrust)
    for s, sg in (("_L", 1), ("_R", -1)):
        rotw(pb, arm, "wing" + s, (0, 1, 0), sg * (0.25 if run else 0.0))
    rotw(pb, arm, "tail_01", (1, 0, 0), 0.05 * math.sin(TAU * 2 * ph))
    _lids(pb, arm, t, (0.3,) if dur > 0.6 else ())

def peck(t, pb, arm, dur):
    """Pecks at the ground three times, with a look between."""
    _stand(pb, arm)
    d = 0.0
    for t0 in (0.3, 0.75, 1.9):
        x = (t - t0) / 0.32
        if 0 <= x < 1:
            d = max(d, math.sin(math.pi * x) ** 0.6)
    look = 0.25 * math.sin(TAU * t / dur)
    rotw(pb, arm, "hips", (1, 0, 0), 0.35 * d)
    rotw(pb, arm, "spine_01", (1, 0, 0), 0.25 * d)
    rotw(pb, arm, "neck_01", (1, 0, 0), 0.75 * d)
    rotw(pb, arm, "neck_02", (1, 0, 0), 0.45 * d)
    rotw(pb, arm, "head", (1, 0, 0), 0.25 * d)
    rotw(pb, arm, "neck_03", (0, 0, 1), look * (1 - d))
    rotw(pb, arm, "tail_01", (1, 0, 0), -0.25 * d)
    _lids(pb, arm, t, (1.4,))

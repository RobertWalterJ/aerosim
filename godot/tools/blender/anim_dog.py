# Dog and wolf clips (see anim.py for the conventions): idle, sit, lie, tail_wag, bark, pant, look.
import math
from mathutils import Vector
from anim import qx, qy, qz, rot, blink, stand_legs, set_ctrl, smooth, TAU

def _tail(pb, amp, freq, t, base=0.0, lag=0.55, droop=0.0):
    for i in range(1, 6):
        rot(pb, "tail_%02d" % i, qz(amp * math.sin(TAU * freq * t - i * lag) * (0.5 + 0.18 * i)) @ qx(base if i == 1 else droop))

def _lids(pb, t, times):
    b = blink(t, times)
    for s in ("_L", "_R"):
        rot(pb, "eyelid" + s, qy(-math.radians(80) * b))

def _breathe(pb, t, rate, amp):
    br = math.sin(TAU * rate * t)
    rot(pb, "spine_02", qx(amp * br)); rot(pb, "chest", qx(-amp * br))

def _mouth(pb, open_):
    rot(pb, "jaw", qx(-open_))

def idle(t, pb, arm, dur, sp):
    stand_legs(pb, arm)
    _breathe(pb, t, 3 / dur, 0.012)
    yaw = 0.25 * math.sin(TAU * t / dur)
    rot(pb, "neck_01", qz(yaw * 0.4)); rot(pb, "neck_02", qz(yaw * 0.3)); rot(pb, "head", qz(yaw * 0.4) @ qx(0.05 * math.sin(TAU * 2 * t / dur)))
    _mouth(pb, 0.02 + 0.015 * math.sin(TAU * 9 * t / dur))        # mouth closed, a little movement
    _tail(pb, 0.18, 1.0 / dur * 3, t, base=-0.1)
    for s, sg in (("_L", 1), ("_R", -1)):
        rot(pb, "ear" + s, qx(0.15 * math.sin(TAU * t / dur + sg)) @ qz(0.15 * math.exp(-((t - (2.0 if sg > 0 else 4.2)) ** 2) / 0.03) * sg))
    _lids(pb, t, (1.3, 4.0))

def look(t, pb, arm, dur, sp):
    """The wolf stands still and looks: head up, turns slowly one way then the other, ears pricked toward it."""
    stand_legs(pb, arm)
    _breathe(pb, t, 3 / dur, 0.01)
    yaw = 0.55 * math.sin(TAU * t / dur)
    rot(pb, "neck_01", qx(0.12) @ qz(yaw * 0.45)); rot(pb, "neck_02", qx(0.08) @ qz(yaw * 0.3)); rot(pb, "head", qx(-0.1) @ qz(yaw * 0.35))
    _tail(pb, 0.05, 1.0 / dur, t, base=-0.15)
    for s in ("_L", "_R"):
        rot(pb, "ear" + s, qx(0.1) @ qz(-yaw * 0.4))
    _lids(pb, t, (2.4,))

def sit(t, pb, arm, dur, sp):
    """Sitting, looking up: the hips are lowered to the ground and the spine pitched up about 45 degrees; the front legs
    stay straight, the hind legs fold (IK), the tail lies on the ground; head up toward the person."""
    s = sp.s
    lift = sp.J["shoulder_L"][2] / 0.40
    pb["hips"].location = Vector((0.0, -0.02 * lift, -0.30 * lift))
    rot(pb, "hips", qx(0.78))
    rot(pb, "spine_01", qx(0.05)); rot(pb, "spine_02", qx(0.0))
    for side in ("_L", "_R"):
        set_ctrl(pb, arm, "ctrl_F" + side, -0.035 * lift, 0.0, 0.0)
        set_ctrl(pb, arm, "ctrl_H" + side, 0.07 * lift, 0.0, 0.0, lat=(0.015 if side == "_L" else -0.015) * lift)
    rot(pb, "neck_01", qx(-0.55)); rot(pb, "neck_02", qx(-0.15)); rot(pb, "head", qx(-0.25 + 0.04 * math.sin(TAU * t / dur)))
    _breathe(pb, t, 2 / dur, 0.01)
    _mouth(pb, 0.02)
    for i in range(1, 6):
        rot(pb, "tail_%02d" % i, qx(-0.5 if i == 1 else 0.25) @ qz(0.15 * math.sin(TAU * 2 * t / dur - i * 0.5)))
    for s_ in ("_L", "_R"):
        rot(pb, "ear" + s_, qx(0.1))
    _lids(pb, t, (1.5,))

def lie(t, pb, arm, dur, sp):
    """Lying down on the chest (sphinx): body lowered to the ground, front legs forward, hind legs folded beside the body,
    head up and resting easy."""
    lift = sp.J["shoulder_L"][2] / 0.40
    pb["hips"].location = Vector((0.0, 0.0, -0.27 * lift))
    rot(pb, "hips", qx(0.03))
    for side, sg in (("_L", 1), ("_R", -1)):
        set_ctrl(pb, arm, "ctrl_F" + side, 0.16 * lift, 0.0, -0.6)
        set_ctrl(pb, arm, "ctrl_H" + side, 0.16 * lift, 0.0, -0.9, lat=sg * 0.05 * lift)
    rot(pb, "chest", qx(0.05))
    rot(pb, "neck_01", qx(0.1)); rot(pb, "head", qx(-0.12 + 0.03 * math.sin(TAU * t / dur)))
    _breathe(pb, t, 2 / dur, 0.015)
    _mouth(pb, 0.05)
    for i in range(1, 6):
        rot(pb, "tail_%02d" % i, qx(-0.6 if i == 1 else 0.15) @ qz((0.3 if i > 1 else 0.0) + 0.05 * math.sin(TAU * t / dur)))
    _lids(pb, t, (2.0, 4.6))

def wag(t, pb, arm, dur, sp):
    stand_legs(pb, arm)
    w = math.sin(TAU * 4 * t / dur * 2)
    _tail(pb, 0.55, 8 / dur, t, base=0.25, lag=0.45)
    rot(pb, "hips", qz(0.06 * w))
    rot(pb, "neck_01", qx(0.1)); rot(pb, "head", qx(-0.05))
    _mouth(pb, 0.2 + 0.05 * math.sin(TAU * 6 * t / dur))
    _breathe(pb, t, 6 / dur, 0.015)
    _lids(pb, t, (0.9,))

def bark(t, pb, arm, dur, sp):
    """Two pairs of barks a loop: the jaw snaps open, the head jerks up and forward, the chest heaves."""
    stand_legs(pb, arm)
    o = 0.0
    for t0 in (0.15, 0.45, 1.15, 1.45):
        x = (t - t0) / 0.18
        if 0 <= x < 1:
            o = max(o, math.sin(math.pi * x) ** 0.7)
    _mouth(pb, 0.05 + 0.5 * o)
    rot(pb, "head", qx(0.12 * o)); rot(pb, "neck_02", qx(0.08 * o))
    rot(pb, "chest", qx(-0.04 * o)); rot(pb, "spine_02", qx(0.03 * o))
    _tail(pb, 0.15, 2 / dur, t, base=0.35)
    for s_ in ("_L", "_R"):
        rot(pb, "ear" + s_, qx(0.15))
    _lids(pb, t, (0.9,))

def pant(t, pb, arm, dur, sp):
    """Mouth open, tongue showing, quick shallow breaths (3 a second)."""
    stand_legs(pb, arm)
    f = 6.0 / dur * 1.0
    _breathe(pb, t, f, 0.02)
    _mouth(pb, 0.42 + 0.06 * math.sin(TAU * f * t))
    rot(pb, "head", qx(0.04 * math.sin(TAU * f * t)))
    _tail(pb, 0.12, 1 / dur, t, base=-0.05)
    _lids(pb, t, (1.2,))

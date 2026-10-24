# Animation clips for the AeroSim animals, written as functions of time that pose the control rig.
# Legs are driven by IK controls (ctrl_F_L etc. at the fetlock; the pastern copies the control's rotation, so the hoof
# stays flat in stance and folds in the swing). Spine, neck, head, tail, ears, jaw and lids are forward kinematics.
#
# Sign convention (all bones are rolled so their local X is the animal's right-left axis): a positive rotation about
# local X turns the bone's tip up / forward (a raised head, a raised tail, a leg swung forward).
import math
from mathutils import Vector, Matrix, Quaternion

TAU = 2 * math.pi

def qx(a):
    return Quaternion((1, 0, 0), a)

def qy(a):
    return Quaternion((0, 1, 0), a)

def qz(a):
    return Quaternion((0, 0, 1), a)

def rot(pb, name, q):
    if name in pb:
        b = pb[name]
        b.rotation_quaternion = b.rotation_quaternion @ q

def smooth(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)

def blink(t, times, dur=0.16):
    """0 open .. 1 closed for blinks starting at `times`."""
    for t0 in times:
        if t0 <= t < t0 + dur:
            return math.sin(math.pi * (t - t0) / dur)
    return 0.0

# ------------------------------------------------------------------ legs
LEGS = ("F_L", "F_R", "H_L", "H_R")

def leg_offset(phase, duty, stride, lift, front):
    """Foot path relative to its rest place, in (forward, up) metres, and the fetlock fold (radians).
    phase 0 = the foot touches down at the front of its stride; it sweeps back on the ground until `duty`, then swings."""
    phase %= 1.0
    if phase < duty:
        s = phase / duty
        fwd = stride * (0.5 - s)
        up = 0.0
        fold = 0.0
        # heel off at the end of stance: the fetlock rises a little and the pastern starts to fold
        if s > 0.82:
            k = (s - 0.82) / 0.18
            up = lift * 0.15 * k * k
            fold = 0.35 * k
    else:
        s = (phase - duty) / (1 - duty)
        fwd = stride * (-0.5 + smooth(s * 1.05))
        up = lift * math.sin(math.pi * min(s * 1.08, 1.0)) ** 0.8
        # fold hardest early in the swing, open out to reach forward before the strike
        fold = (0.35 + 0.55 * math.sin(math.pi * min(s * 1.4, 1.0))) * (1.0 if s < 0.75 else max(0.0, 1 - (s - 0.75) / 0.25))
        if front:
            fold *= 1.15
    return fwd, up, fold

def set_ctrl(pb, arm, name, fwd, up, fold, lat=0.0):
    b = arm.data.bones[name]
    rest = b.matrix_local.copy()
    loc = rest.to_translation() + Vector((lat, -fwd, up))
    R = Matrix.Rotation(fold, 4, "X") @ rest.to_3x3().to_4x4()
    pb[name].matrix = Matrix.Translation(loc) @ R

def gait(t, pb, arm, g):
    """g: period, duty, phases {leg: phase0}, stride, lift_f, lift_h, bob, pitch, roll, nod, scap, tail, head_up."""
    T = g["period"]
    ph = t / T
    for leg in LEGS:
        p = ph + g["phases"][leg]
        front = leg.startswith("F")
        fwd, up, fold = leg_offset(p, g["duty"], g["stride"] * (g.get("stride_f", 1.0) if front else 1.0), g["lift_f"] if front else g["lift_h"], front)
        set_ctrl(pb, arm, "ctrl_" + leg, fwd + g.get("reach_f" if front else "reach_h", 0.0), up, fold)
        if front:
            # the shoulder blade swings with the leg
            rot(pb, "scapula_" + leg[-1], qx(g["scap"] * fwd / max(g["stride"], 1e-3)))
    # body: bob (twice a cycle at walk and trot, once at canter), pitch and roll
    nb = g.get("bob_n", 2)
    bob = g["bob"] * math.cos(TAU * nb * ph + g.get("bob_ph", 0.0))
    pb["hips"].location = Vector((0.0, 0.0, bob))
    rot(pb, "hips", qx(g["pitch"] * math.sin(TAU * nb * ph + g.get("pitch_ph", 0.0))))
    rot(pb, "hips", Quaternion((0, 1, 0), g["roll"] * math.sin(TAU * ph)))
    rot(pb, "spine_01", qz(g.get("yaw", 0.0) * math.sin(TAU * ph)))
    rot(pb, "chest", qz(-g.get("yaw", 0.0) * math.sin(TAU * ph)))
    rot(pb, "chest", qx(-g["pitch"] * 0.5 * math.sin(TAU * nb * ph + g.get("pitch_ph", 0.0))))
    # neck and head: carriage and a nod
    nod = g["nod"] * math.sin(TAU * nb * ph + g.get("nod_ph", 0.0))
    rot(pb, "neck_01", qx(g.get("head_up", 0.0) * 0.6 + nod * 0.5))
    rot(pb, "neck_02", qx(g.get("head_up", 0.0) * 0.4 + nod * 0.3))
    rot(pb, "head", qx(-g.get("head_up", 0.0) * 0.6 - nod * 0.4))
    # tail
    tl = g.get("tail", 0.0)
    for i in range(1, 6):
        rot(pb, "tail_%02d" % i, qz(tl * math.sin(TAU * ph - i * 0.6)) @ qx(g.get("tail_up", 0.0) * (1.0 if i == 1 else 0.3)))
    # ears: carried a little back when moving fast
    for s in ("_L", "_R"):
        rot(pb, "ear" + s, qx(g.get("ears", 0.0)))

def stand_legs(pb, arm, shift=None):
    for leg in LEGS:
        d = (shift or {}).get(leg, (0.0, 0.0, 0.0))
        set_ctrl(pb, arm, "ctrl_" + leg, d[0], d[1], d[2])

def idle(t, pb, arm, dur, look=0.15, chew=True, tail=0.25, ear=0.25, blinks=(1.1, 3.7, 5.2)):
    stand_legs(pb, arm)
    br = math.sin(TAU * 3 * t / dur)          # breathing, three breaths a loop
    rot(pb, "spine_02", qx(0.01 * br))
    rot(pb, "chest", qx(-0.01 * br))
    # look around slowly and come back
    yaw = look * math.sin(TAU * t / dur) * (0.6 + 0.4 * math.sin(TAU * 2 * t / dur))
    rot(pb, "neck_01", qz(yaw * 0.5)); rot(pb, "neck_02", qz(yaw * 0.3)); rot(pb, "head", qz(yaw * 0.3))
    rot(pb, "head", qx(0.05 * math.sin(TAU * 2 * t / dur + 1.0)))
    if chew:
        rot(pb, "jaw", qx(-0.06 * max(0.0, math.sin(TAU * 8 * t / dur))) @ qz(0.03 * math.sin(TAU * 8 * t / dur)))
    for i in range(1, 6):
        rot(pb, "tail_%02d" % i, qz(tail * math.sin(TAU * 2 * t / dur - i * 0.5) * (0.4 + 0.15 * i)))
    for s, sg in (("_L", 1), ("_R", -1)):
        flick = math.exp(-((t - (1.8 if sg > 0 else 4.4)) ** 2) / 0.02)
        rot(pb, "ear" + s, qx(ear * 0.3 * math.sin(TAU * t / dur + sg)) @ qz(ear * flick * sg))
    b = blink(t, blinks)
    for s in ("_L", "_R"):
        rot(pb, "eyelid" + s, qy(-math.radians(80) * b))

def head_down(pb, arm, k, head_world=-1.75):
    """Neck lowered by k; the head is then turned so it hangs at `head_world` radians from the horizontal (about
    -100 degrees: nearly vertical, the muzzle a little back, as a grazing animal holds it)."""
    nk = (-0.10, -0.62, -0.48)
    rot(pb, "chest", qx(nk[0] * k))
    rot(pb, "neck_01", qx(nk[1] * k))
    rot(pb, "neck_02", qx(nk[2] * k))
    hb = arm.data.bones["head"]
    v = hb.tail_local - hb.head_local
    rest = math.atan2(v.z, -v.y)
    rot(pb, "head", qx((head_world - rest - sum(nk) * k) * min(1.0, k)))

def solve_graze(pb, arm, spec, update):
    """Finds how far down the neck must go for the muzzle to touch the grass, by bisection on the real rig."""
    lo, hi = 0.0, 2.2
    for _ in range(16):
        k = (lo + hi) / 2
        for b in pb:
            b.rotation_quaternion = (1, 0, 0, 0); b.location = (0, 0, 0)
        stand_legs(pb, arm)
        head_down(pb, arm, k)
        update()
        tip = (arm.matrix_world @ pb["head"].tail)
        if tip.z > spec.graze_h:
            lo = k
        else:
            hi = k
    return (lo + hi) / 2

def graze(t, pb, arm, dur, k, step=True):
    # front feet a little apart and forward, as cattle stand when grazing
    stand_legs(pb, arm, {"F_L": (0.12, 0, 0), "F_R": (-0.05, 0, 0)})
    sw = math.sin(TAU * t / dur)
    head_down(pb, arm, k * (1.0 + 0.03 * math.sin(TAU * 4 * t / dur)))
    rot(pb, "neck_01", qz(0.18 * sw)); rot(pb, "neck_02", qz(0.1 * sw))
    # tear and chew
    tear = max(0.0, math.sin(TAU * 6 * t / dur)) ** 3
    rot(pb, "head", qx(0.12 * tear))
    rot(pb, "jaw", qx(-0.08 * max(0.0, math.sin(TAU * 12 * t / dur))))
    for i in range(1, 6):
        rot(pb, "tail_%02d" % i, qz(0.3 * math.sin(TAU * 2 * t / dur - i * 0.5) * (0.4 + 0.15 * i)))
    b = blink(t, (2.0, 4.9))
    for s in ("_L", "_R"):
        rot(pb, "eyelid" + s, qy(-math.radians(80) * b))
        rot(pb, "ear" + s, qx(-0.15))

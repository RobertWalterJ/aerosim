# The hen (chicken_a): a brown laying hen about 0.40 m to the top of the comb. Body feathers are sculpted as layered
# scallops (baked into the normal map), wings fold against the sides, the tail fans up; yellow scaled legs with three toes
# forward and one back; single red comb and wattles.
import numpy as np
import math
from sdf import P, Field, Ellipsoid, RoundCone, RBox, Displaced, frame, norm, rot_x, rot_y, rot_z, fbm
from species import Quad, HeadFrame, L, near, sstep, win, UP, FWD

def scallops(scale=0.012, seed=0):
    """Overlapping rounded feather tips: a bumpy relief in rows down and back along the body."""
    def fn(p):
        q = p / scale
        q = q + 0.35 * np.stack([fbm(p, 15, 2, seed), fbm(p, 15, 2, seed + 1), fbm(p, 15, 2, seed + 2)], 1)
        cy = q[:, 1] + 0.5 * np.floor(q[:, 2])          # rows offset by half a feather
        fy = cy - np.floor(cy) - 0.5; fz = q[:, 2] - np.floor(q[:, 2])
        return 0.6 * (1.0 - np.clip(np.sqrt(fy * fy * 3.0 + fz * fz), 0, 1)) + 0.2 * fbm(p, 120, 1, seed + 5)
    return fn

class Hen(Quad):
    preview_vox = 0.0025
    vox_m = 0.0016
    cage_m = 0.012
    eye_kind = "round"
    iris = (0.85, 0.45, 0.08)
    lid_col = (0.7, 0.55, 0.4)
    detail_keys = ("coat", "fleece", "skin")
    tex = 1024
    lod0 = 4200
    lod_ratio = (0.38, 0.12)

    def __init__(self, name, seed=3):
        super().__init__(name)
        self.s = 1.0; self.seed = seed; self.hs = 1.0
        self.lo = np.array([-0.13, -0.17, -0.005]); self.hi = np.array([0.13, 0.26, 0.45])
        J = self.j
        J("hips", 0, -0.04, 0.215); J("chest", 0, 0.05, 0.23); J("neck0", 0, 0.085, 0.27); J("neck1", 0, 0.10, 0.31)
        J("neck2", 0, 0.11, 0.345); J("headc", 0, 0.115, 0.365); J("beak", 0, 0.168, 0.352)
        J("hip_L", 0.045, -0.02, 0.19); J("knee_L", 0.048, 0.025, 0.135); J("hock_L", 0.042, -0.015, 0.085); J("foot_L", 0.042, 0.002, 0.014)
        J("toe_L", 0.042, 0.065, 0.003)
        J("shoulder_L", 0.06, 0.06, 0.25); J("elbow_L", 0.072, -0.02, 0.24); J("wrist_L", 0.07, 0.02, 0.215); J("wtip_L", 0.06, -0.14, 0.205)
        J("tail0", 0, -0.12, 0.26); J("tail1", 0, -0.16, 0.31); J("tail2", 0, -0.19, 0.37)
        self.head = HeadFrame(self.J["headc"] + P(0, -0.012, 0.012), self.J["beak"], up_hint=(0, 0, 1))
        self.jaw = (P(0, 0.135, 0.355), P(0, 0.162, 0.347))
        self.eyes = [(P(sd * 0.019, 0.124, 0.372), 0.0056) for sd in (1, -1)]
        self.ears = []

    @property
    def mat_name(self):
        return self.name + "_feathers"

    def eye_gaze(self, i):
        return np.array([1.0 if i == 0 else -1.0, -0.35, 0.05])

    def eye_up(self, i):
        return np.array([0, 0, 1.0])

    def field(self, vox):
        F = Field(self.lo, self.hi, vox)
        J = self.J
        E = lambda c, r, R=None, tag="body": Ellipsoid(P(*c), L(r), R, tag)
        feath = lambda prim, amp=0.0016, sc=0.011, sd=0: Displaced(prim, amp, 1.0, fn=scallops(sc, self.seed + sd))
        F.add(feath(E((0, 0.0, 0.215), (0.085, 0.15, 0.10), rot_x(math.radians(14)))), 0)              # body
        F.add(feath(E((0, 0.075, 0.185), (0.075, 0.085, 0.09)), sd=2), 0.03)                        # breast
        F.add(feath(E((0, -0.07, 0.265), (0.07, 0.10, 0.05)), sd=3), 0.03)                          # saddle
        F.add(feath(E((0, -0.05, 0.14), (0.065, 0.09, 0.05), None, "fluff"), 0.003, 0.008, 4), 0.03)  # fluff under the vent
        # tail: a fan of stiff feathers, upright and a little back
        for k, (el, lat) in enumerate(((28, 0.0), (42, 0.012), (55, -0.012), (66, 0.006), (76, -0.006), (50, 0.0))):
            d = P(0, -math.cos(math.radians(el)), math.sin(math.radians(el)))
            base = P(lat, -0.135, 0.265)
            R = frame(d, (1, 0, 0))                      # local z is the hen's left-right: the feather is thin that way
            F.add(Displaced(Ellipsoid(base + d * 0.055, L([0.017, 0.06, 0.0045]), R, "tail"), 0.001, 1.0, fn=scallops(0.02, 10 + k)), 0.01)
        # neck and hackles
        F.add(feath(RoundCone(P(0, 0.07, 0.25), J["neck2"], 0.05, 0.026, "hackle"), 0.003, 0.009, 6), 0.03)
        # wings folded against the sides, primaries crossing over the back toward the tail
        for sg in (1, -1):
            R = frame(P(0, -1.0, -0.12), (0, 0, 1))
            F.add(Displaced(Ellipsoid(P(sg * 0.072, -0.03, 0.225), L([0.022, 0.11, 0.055]), R, "wing"), 0.002, 1.0, fn=scallops(0.014, 20 + sg)), 0.015)
            F.add(Displaced(Ellipsoid(P(sg * 0.06, -0.12, 0.215), L([0.012, 0.07, 0.03]), R, "primary"), 0.0012, 1.0, fn=scallops(0.03, 30 + sg)), 0.01)
            side = "_L" if sg > 0 else "_R"
            # legs: feathered thigh, bare scaled tarsus, toes with nails
            F.add(feath(RoundCone(J["hip" + side], J["knee" + side], 0.03, 0.022, "fluff"), 0.002, 0.008, 7), 0.02)
            F.add(RoundCone(J["knee" + side], J["hock" + side], 0.014, 0.008, "fluff"), 0.012)
            F.add(Ellipsoid(J["hock" + side], L([0.007, 0.008, 0.008]), None, "leg"), 0.004)
            F.add(Displaced(RoundCone(J["hock" + side], J["foot" + side], 0.0062, 0.0058, "leg"), 0.0006, 1.0, fn=scallops(0.004, 40)), 0.003)
            f = J["foot" + side]
            for dx, dy, ln in ((0.0, 1.0, 0.058), (0.42, 0.85, 0.045), (-0.42, 0.85, 0.045), (0.0, -1.0, 0.028)):
                d = norm(P(dx * sg, dy, -0.12))
                tip = f + d * ln; tip[2] = 0.003
                F.add(RoundCone(f, tip, 0.005, 0.0032, "leg"), 0.003)
                F.add(RoundCone(tip, tip + d * 0.008 + P(0, 0, -0.002), 0.0022, 0.0008, "nail"), 0.001)
        self._head(F)
        F.cut_below(0.0)
        return F

    def _head(self, F):
        J = self.J
        F.add(Ellipsoid(J["headc"], L([0.021, 0.03, 0.024]), rot_x(math.radians(-10)), "head"), 0.012)
        F.add(Ellipsoid(J["headc"] + P(0, 0.02, -0.006), L([0.014, 0.02, 0.016]), None, "head"), 0.008)
        # beak: upper and lower, hooked a little
        F.add(RoundCone(P(0, 0.136, 0.360), P(0, 0.158, 0.352), 0.0085, 0.004, "beak"), 0.003)
        F.add(RoundCone(P(0, 0.158, 0.352), J["beak"] + P(0, 0.0, -0.004), 0.004, 0.0012, "beak"), 0.002)
        F.add(RoundCone(P(0, 0.138, 0.351), P(0, 0.158, 0.346), 0.006, 0.002, "beak"), 0.002)
        # single comb: a serrated blade from the beak root back over the head
        for k in range(6):
            t = k / 5.0
            base = P(0, 0.14 - t * 0.05, 0.383 + 0.012 * math.sin(math.pi * t))
            F.add(RoundCone(base, base + P(0, -0.004, 0.012 + 0.006 * math.sin(math.pi * t)), 0.0035, 0.0018, "comb"), 0.004)
        F.add(Ellipsoid(P(0, 0.115, 0.388), L([0.0025, 0.03, 0.009]), None, "comb"), 0.004)
        # wattles and ear lobes
        for sd in (1, -1):
            F.add(Ellipsoid(P(sd * 0.006, 0.138, 0.33), L([0.0045, 0.008, 0.014]), None, "comb"), 0.004)
            F.add(Ellipsoid(P(sd * 0.019, 0.10, 0.355), L([0.003, 0.006, 0.007]), None, "comb"), 0.003)
            F.add(Ellipsoid(P(sd * 0.015, 0.124, 0.372), L([0.008, 0.009, 0.008]), None, "face"), 0.004)   # bare red skin round the eye
        self.place_eyes(F, protrude=0.4)

    # ---------------------------------------------------------------- rig
    def bones(self):
        J = self.J
        out = []
        def b(name, h, t, parent, zref, deform=True):
            out.append((name, tuple(h), tuple(t), parent, tuple(zref), deform))
        b("root", (0, 0, 0), P(0, 0.1, 0), None, UP, False)
        b("hips", J["hips"], J["chest"], "root", UP)
        b("spine_01", J["chest"], J["neck0"], "hips", UP)
        b("neck_01", J["neck0"], J["neck1"], "spine_01", FWD)
        b("neck_02", J["neck1"], J["neck2"], "neck_01", FWD)
        b("neck_03", J["neck2"], J["headc"], "neck_02", FWD)
        b("head", J["headc"], J["beak"], "neck_03", UP)
        b("jaw", self.jaw[0], self.jaw[1], "head", UP)
        for i, sd in enumerate(("_L", "_R")):
            c, r = self.eyes[i]
            g = norm(self.eye_gaze(i)); u = norm(self.eye_up(i)); sx = norm(np.cross(g, u))
            b("eyelid" + sd, c, c + sx * 0.01, "head", u)
            b("wing" + sd, J["shoulder" + sd], J["elbow" + sd], "spine_01", UP)
            b("forewing" + sd, J["elbow" + sd], J["wrist" + sd], "wing" + sd, UP)
            b("hand" + sd, J["wrist" + sd], J["wtip" + sd], "forewing" + sd, UP)
            b("thigh" + sd, J["hip" + sd], J["knee" + sd], "hips", FWD)
            b("shin" + sd, J["knee" + sd], J["hock" + sd], "thigh" + sd, FWD)
            b("tarsus" + sd, J["hock" + sd], J["foot" + sd], "shin" + sd, FWD)
            b("toe" + sd, J["foot" + sd], J["toe" + sd], "tarsus" + sd, UP)
            b("ctrl_H" + sd, J["foot" + sd], J["toe" + sd], "root", UP, False)
        b("tail_01", J["tail0"], J["tail1"], "hips", UP)
        b("tail_02", J["tail1"], J["tail2"], "tail_01", UP)
        return out

    def setup_controls(self, arm):
        pb = arm.pose.bones
        for sd in ("_L", "_R"):
            c = pb["tarsus" + sd].constraints.new("IK")
            c.target = arm; c.subtarget = "ctrl_H" + sd; c.chain_count = 3; c.use_tail = True; c.use_stretch = False
            for bn in ("tarsus", "shin", "thigh"):
                pb[bn + sd].lock_ik_y = True; pb[bn + sd].lock_ik_z = True
            cr = pb["toe" + sd].constraints.new("COPY_ROTATION")
            cr.target = arm; cr.subtarget = "ctrl_H" + sd; cr.target_space = "WORLD"; cr.owner_space = "WORLD"
        for b_ in pb: b_.rotation_mode = "QUATERNION"

    def jaw_weight(self, co):
        v = co - np.array(self.jaw[0])
        return ((co[:, 2] < 0.351) & (-co[:, 1] > 0.137) & (np.abs(co[:, 0]) < 0.012)).astype(float) * (co[:, 2] > 0.338)

    # ---------------------------------------------------------------- coat
    def paint(self, Pt, nrm, tags):
        n = len(Pt)
        T = lambda k: tags.get(k, np.full(n, 1e9))
        up = Pt[:, 2]; fwd = -Pt[:, 1]
        tone = fbm(Pt, 20.0, 3, 31)
        edge = np.clip(scallops(0.011, self.seed)(Pt), 0, 1)                       # pale feather edges
        body = np.array([0.40, 0.21, 0.10])[None] * (0.8 + 0.35 * edge[:, None]) * (1 + 0.1 * tone[:, None])
        hackle = win(tags, "hackle", n)
        body = body * (1 - hackle[:, None]) + np.array([0.66, 0.42, 0.16]) * (0.85 + 0.3 * edge[:, None]) * hackle[:, None]
        dark = np.maximum(win(tags, "tail", n), win(tags, "primary", n))
        body = body * (1 - dark[:, None]) + np.array([0.13, 0.07, 0.035]) * (0.9 + 0.3 * edge[:, None]) * dark[:, None]
        fl = win(tags, "fluff", n)
        body = body * (1 - fl[:, None] * 0.4) + np.array([0.62, 0.48, 0.32]) * fl[:, None] * 0.4
        col = body; rough = np.full(n, 0.7)
        for key, c, r in (("comb", (0.66, 0.06, 0.05), 0.45), ("face", (0.72, 0.12, 0.08), 0.5), ("beak", (0.76, 0.62, 0.36), 0.35),
                          ("leg", (0.82, 0.66, 0.26), 0.45), ("nail", (0.55, 0.48, 0.38), 0.4)):
            m = win(tags, key, n, 0.002)
            cc = np.array(c)[None] * (1 + 0.12 * fbm(Pt, 200, 2, 5))[:, None]
            col = col * (1 - m[:, None]) + cc * m[:, None]
            rough = rough * (1 - m) + r * m
        hd = win(tags, "head", n, 0.002)
        col = col * (1 - hd[:, None]) + np.array([0.55, 0.30, 0.12]) * hd[:, None]
        return np.clip(col, 0, 1), rough

    def fur_amount(self, Pt, tags):
        return np.ones(len(Pt)) * 0.0      # no shell fur on feathers

    def detail_kind(self, Pt, tags):
        n = len(Pt)
        bare = np.maximum.reduce([win(tags, k, n, 0.002) for k in ("comb", "face", "beak", "leg", "nail")])
        return np.where(bare > 0.5, 2.0, 0.0)

    def extra_fix(self, body, arm, co, W, vg):
        pass

    # ---------------------------------------------------------------- clips
    def clips(self, arm, update):
        import anim_hen as H
        return [
            dict(name="idle", dur=4.0, fn=lambda t, pb: H.idle(t, pb, arm, 4.0)),
            dict(name="walk", dur=0.8, fn=lambda t, pb: H.walk(t, pb, arm, 0.8, 0.075, 0.035)),
            dict(name="run", dur=0.42, fn=lambda t, pb: H.walk(t, pb, arm, 0.42, 0.12, 0.05, run=True)),
            dict(name="peck", dur=3.0, fn=lambda t, pb: H.peck(t, pb, arm, 3.0)),
        ]

    def clip_speeds(self):
        return {"walk": round(0.075 / 0.6 / 0.8 * 2 / 2, 2), "run": round(0.12 / 0.45 / 0.42, 2)}

# Horses: a riding horse of about 16 hands (1.63 m at the withers), bay with black points or dapple grey.
import numpy as np
import math
from sdf import P, Field, Ellipsoid, RoundCone, RBox, Displaced, frame, norm, rot_x, rot_y, rot_z, fbm
from species import Cattle, Quad, HeadFrame, L, near, sstep
from sp_more import ear_leaf

def streaks(direction, perp=90.0, along=4.0, seed=0):
    """Noise stretched along `direction`: locks of hair (mane, tail, feathering) rather than lumps."""
    d = norm(direction)
    a = norm(np.cross(d, [0.3, 0.5, 0.8])); b = np.cross(d, a)
    def fn(p):
        q = np.stack([p @ a * perp, p @ b * perp, p @ d * along], axis=1)
        return 0.65 * fbm(q, 1.0, 3, seed) + 0.35 * fbm(q * 2.3, 1.0, 2, seed + 4)
    return fn

class Horse(Cattle):
    preview_vox = 0.01
    vox_m = 0.005
    eye_kind = "oval"
    iris = (0.14, 0.08, 0.04)
    detail_keys = ("coat", "fleece", "skin")
    gait_k = 1.05

    def __init__(self, name, coat="bay", seed=4):
        Quad.__init__(self, name)
        self.s = 1.0; self.coat = coat; self.seed = seed; self.calf = 0.0
        self.tex = 2048; self.lod0 = 18000
        self.lo = np.array([-0.55, -1.62, -0.01]); self.hi = np.array([0.55, 1.18, 2.12])
        self.lid_col = (0.08, 0.06, 0.05) if coat == "bay" else (0.25, 0.24, 0.23)
        self._skeleton()

    def _skeleton(self):
        j = self.j
        j("tail1", 0, -0.84, 1.50); j("sacrum", 0, -0.60, 1.50); j("lumbar", 0, -0.25, 1.45)
        j("thorax", 0, 0.15, 1.40); j("withers", 0, 0.46, 1.46)
        j("neck0", 0, 0.62, 1.30); j("neck1", 0, 0.95, 1.60); j("poll", 0, 1.22, 1.93)
        j("muzzle", 0, 1.56, 1.45)
        j("scap_L", 0.16, 0.40, 1.56); j("shoulder_L", 0.20, 0.70, 1.12); j("elbow_L", 0.19, 0.55, 0.88)
        j("carpus_L", 0.17, 0.60, 0.50); j("fetF_L", 0.17, 0.615, 0.21); j("corF_L", 0.17, 0.665, 0.10); j("toeF_L", 0.17, 0.74, 0.0)
        j("hip_L", 0.20, -0.62, 1.22); j("stifle_L", 0.21, -0.42, 0.92); j("hock_L", 0.16, -0.78, 0.58)
        j("fetH_L", 0.16, -0.745, 0.21); j("corH_L", 0.16, -0.695, 0.10); j("toeH_L", 0.16, -0.62, 0.0)
        j("tail2", 0, -0.92, 1.40); j("tail3", 0, -0.97, 1.22); j("tail4", 0, -0.99, 1.02); j("tail5", 0, -1.0, 0.80)
        self.head = HeadFrame(self.J["poll"], self.J["muzzle"], up_hint=P(0, 1, 0.6))
        H = self.head; self.hs = 1.0
        self.jaw = (H.p(0, 0.14, -0.22), H.p(0, 0.56, -0.15))
        self.ears = []; self.eyes = []
        for sd in (1, -1):
            base = H.p(sd * 0.055, 0.005, -0.035)
            d = norm(H.R @ L([sd * 0.3, -0.45, 1.0]))
            self.ears.append((base, base + d * 0.16, H.R @ L([0, 1.0, 0.2])))
            self.eyes.append((H.p(sd * 0.10, 0.17, -0.065), 0.024))
        self.graze_h = 0.04

    def eye_gaze(self, i):
        sd = 1 if i == 0 else -1
        return self.head.R @ L([sd * 1.0, 0.3, 0.3])

    def jaw_weight(self, co):
        q = (co - self.head.o) @ self.head.R
        return sstep(0.12, 0.17, -q[:, 2]) * sstep(0.30, 0.42, q[:, 1])

    def field(self, vox):
        F = Field(self.lo, self.hi, vox)
        J = self.J
        E = lambda c, r, R=None, tag="body": Ellipsoid(P(*c), L(r), R, tag)
        RC = lambda a, b, ra, rb, tag="body", **kw: RoundCone(P(*a), P(*b), ra, rb, tag, **kw)
        F.add(E((0, 0.38, 1.20), (0.24, 0.40, 0.36)), 0)
        F.add(E((0, 0.0, 1.16), (0.28, 0.46, 0.36)), 0.16)
        F.add(E((0, -0.42, 1.24), (0.26, 0.36, 0.30)), 0.14)
        F.add(RC((0, 0.46, 1.50), (0, -0.58, 1.55), 0.10, 0.13), 0.12)
        F.add(E((0, 0.46, 1.49), (0.075, 0.20, 0.08)), 0.06)
        for sg in (1, -1):
            F.add(E((sg * 0.135, -0.62, 1.40), (0.155, 0.26, 0.21)), 0.10)
            F.add(E((sg * 0.12, -0.80, 1.22), (0.12, 0.12, 0.27)), 0.08)
            F.add(E((sg * 0.17, -0.62, 1.03), (0.10, 0.19, 0.27), rot_x(math.radians(-10))), 0.08)
            F.add(E((sg * 0.19, 0.55, 1.25), (0.07, 0.15, 0.30), rot_x(math.radians(32))), 0.07)
            F.add(E((sg * 0.19, 0.72, 1.12), (0.08, 0.08, 0.08)), 0.06)
            F.add(E((sg * 0.07, 0.74, 1.04), (0.09, 0.10, 0.14)), 0.07)
        lat = (1, 0, 0)
        F.add(RC((0, 0.52, 1.26), (0, 0.88, 1.56), 0.24, 0.15, flat=0.72, flat_axis=lat), 0.10)
        F.add(RC((0, 0.88, 1.56), (0, 1.15, 1.85), 0.15, 0.10, flat=0.72, flat_axis=lat), 0.08)
        F.add(RC((0, 0.46, 1.54), (0, 0.85, 1.78), 0.09, 0.08, flat=0.8, flat_axis=lat), 0.08)
        F.add(RC((0, 0.85, 1.78), (0, 1.18, 1.97), 0.08, 0.06, flat=0.8, flat_axis=lat), 0.06)
        F.add(RC((0, 0.72, 1.10), (0, 1.18, 1.68), 0.13, 0.075, flat=0.8, flat_axis=lat), 0.08)
        self.add_legs(F, {"arm": (0.11, 0.09), "fore": (0.072, 0.044), "knee": 0.048, "cannon": (0.031, 0.029), "fet": 0.041,
                          "past": (0.031, 0.036), "thigh": (0.12, 0.10), "gaskin": (0.08, 0.04), "hock": 0.044, "hockpt": (0.03, 0.02),
                          "hoofr": 0.062, "flank": 0.11}, foot="hoof")
        F.add(RoundCone(J["tail1"] + P(0, 0.03, 0.0), J["tail3"], 0.055, 0.04, "body"), 0.05)
        F.add(RoundCone(J["tail3"], J["tail4"], 0.04, 0.03, "tailhair"), 0.02)
        F.add(Displaced(RoundCone(J["tail2"] + P(0, -0.04, -0.06), P(0, -1.06, 0.55), 0.045, 0.075, "tailhair", flat=0.6, flat_axis=(1, 0, 0)), 0.035, 1.0,
                        fn=streaks(P(0, -0.12, -1.0), 55, 3, 21)), 0.04)
        self._head(F)
        self._mane(F)
        F.cut_below(0.0)
        return F

    def _head(self, F):
        H = self.head
        E = lambda x, u, v, r, extra=None, tag="head": Ellipsoid(H.p(x, u, v), L(r), H.rot(extra), tag)
        RCh = lambda a, b_, ra, rb, tag="head", **kw: RoundCone(H.p(*a), H.p(*b_), ra, rb, tag, **kw)
        F.add(E(0, 0.07, -0.08, (0.10, 0.11, 0.09)), 0.05)
        F.add(RCh((0, 0.12, -0.075), (0, 0.46, -0.07), 0.085, 0.052, flat=0.85, flat_axis=H.R[:, 0]), 0.06)
        F.add(E(0, 0.52, -0.095, (0.062, 0.075, 0.075), tag="muzzle"), 0.05)
        F.add(E(0, 0.575, -0.13, (0.048, 0.04, 0.035), tag="muzzle"), 0.03)
        F.add(E(0, 0.55, -0.175, (0.035, 0.045, 0.028), tag="muzzle"), 0.03)
        for sd in (1, -1):
            F.add(E(sd * 0.062, 0.15, -0.20, (0.055, 0.11, 0.105)), 0.05)
            F.add(RCh((sd * 0.05, 0.22, -0.25), (sd * 0.02, 0.52, -0.16), 0.042, 0.028), 0.05)
            F.add(E(sd * 0.09, 0.155, -0.055, (0.04, 0.05, 0.04)), 0.03)
            F.add(E(sd * 0.042, 0.555, -0.085, (0.022, 0.03, 0.03), tag="nose"), 0.015)
            F.sub(Ellipsoid(H.p(sd * 0.04, 0.575, -0.082), L([0.011, 0.02, 0.022]), H.rot(rot_y(math.radians(sd * 25))), "nose"), 0.004)
        self.place_eyes(F, protrude=0.45)
        for i, sd in enumerate((1, -1)):
            base, tip, face = self.ears[i]
            ear_leaf(F, base, norm(tip - base), face, 0.16, 0.045, 0.012, cup=0.8, k=0.02)
        F.add(Displaced(Ellipsoid(H.p(0, 0.08, 0.005), L([0.045, 0.10, 0.02]), H.R, "mane"), 0.012, 1.0, fn=streaks(H.R[:, 1], 120, 4, 31)), 0.02)

    def _mane(self, F):
        """Mane along the crest, falling to the horse's right (-x)."""
        pts = [P(0, 0.48, 1.62), P(0, 0.68, 1.76), P(0, 0.88, 1.88), P(0, 1.06, 1.98), P(0, 1.18, 2.03)]
        for i in range(len(pts) - 1):
            a, b = pts[i], pts[i + 1]
            c = (a + b) / 2 + np.array([-0.04, 0, -0.06])
            R = frame(norm(b - a), [-0.6, 0, 1.0])
            F.add(Displaced(Ellipsoid(c + np.array([-0.045, 0, -0.04]), L([0.045, 0.13, 0.15]), R, "mane"), 0.03, 1.0, fn=streaks([-0.3, 0, -1.0], 80, 5, 41 + i)), 0.03)
            F.add(Displaced(RoundCone(a + np.array([0, 0, 0.035]), b + np.array([0, 0, 0.035]), 0.03, 0.03, "mane"), 0.015, 1.0, fn=streaks([-0.2, 0, -1.0], 90, 5, 51 + i)), 0.02)

    def paint(self, Pt, nrm, tags):
        n = len(Pt)
        T = lambda k: tags.get(k, np.full(n, 1e9))
        up = Pt[:, 2]; fwd = -Pt[:, 1]
        tone = fbm(Pt, 3.0, 3, 31)
        q = self.head_local(Pt)
        hair = np.maximum(near(T("mane"), 0.01), near(T("tailhair"), 0.01))
        legs = np.maximum(sstep(0.62, 0.48, up) * (fwd > 0.2), sstep(0.72, 0.56, up) * (fwd < -0.2))
        if self.coat == "bay":
            body = np.array([0.42, 0.21, 0.10])[None] * (1 + 0.12 * tone[:, None])
            body = body * (1 - 0.25 * sstep(1.35, 1.6, up)[:, None])
            black = np.array([0.04, 0.032, 0.028])
            col = body * (1 - legs[:, None]) + black * legs[:, None]
            col = col * (1 - hair[:, None]) + black * (1 + 0.5 * np.clip(fbm(Pt, 40, 2, 3), 0, 1))[:, None] * hair[:, None]
            star = (np.hypot(q[:, 0], q[:, 1] - 0.13) < 0.025 + 0.01 * fbm(Pt, 60, 2, 5)) & (q[:, 2] > -0.03)
            col[star] = [0.85, 0.82, 0.78]
            mz = near(T("muzzle"), 0.01) * (q[:, 1] > 0.48)
            col = col * (1 - mz[:, None] * 0.7) + np.array([0.06, 0.05, 0.045]) * mz[:, None] * 0.7
            hoof = np.array([0.05, 0.045, 0.04])
        else:
            base = np.array([0.70, 0.70, 0.68])
            ring = sstep(0.0, 0.25, fbm(Pt, 24.0, 2, 17))                                    # small pale dapples in a grey net
            body = base[None] * (0.82 + 0.18 * ring[:, None]) * (1 + 0.05 * tone[:, None])
            dark = np.clip(0.6 * legs + 0.35 * sstep(1.0, 0.75, up) * (1 - legs), 0, 1)
            col = body * (1 - dark[:, None]) + np.array([0.30, 0.30, 0.30]) * dark[:, None]
            head = near(T("head"), 0.01)
            col = col * (1 - head[:, None] * 0.5) + np.array([0.80, 0.80, 0.78]) * head[:, None] * 0.5
            hc = np.array([0.82, 0.81, 0.78])[None] * (0.75 + 0.35 * np.clip(fbm(Pt, 50, 2, 9), 0, 1))[:, None]
            col = col * (1 - hair[:, None]) + hc * hair[:, None]
            mz = near(T("muzzle"), 0.01) * (q[:, 1] > 0.48)
            col = col * (1 - mz[:, None] * 0.75) + np.array([0.13, 0.12, 0.12]) * mz[:, None] * 0.75
            hoof = np.array([0.12, 0.115, 0.11])
        rough = 0.62 + 0.06 * tone
        rough = rough * (1 - hair) + 0.5 * hair
        nose = near(T("nose"), 0.004)
        col = col * (1 - nose[:, None]) + np.array([0.05, 0.045, 0.045]) * nose[:, None]
        rough = rough * (1 - nose) + 0.3 * nose
        h = near(T("hoof"), 0.003)
        col = col * (1 - h[:, None]) + hoof * h[:, None] * (1 + 0.3 * fbm(Pt, 60, 2, 51))[:, None]
        rough = rough * (1 - h) + 0.45 * h
        return np.clip(col, 0, 1), np.clip(rough, 0.05, 1)

    def fur_amount(self, Pt, tags):
        n = len(Pt)
        T = lambda k: tags.get(k, np.full(n, 1e9))
        f = np.ones(n) * 0.9
        f = np.minimum(f, 1.0 - 0.93 * near(T("nose"), 0.004))
        f = np.minimum(f, 1.0 - 0.6 * near(T("muzzle"), 0.006))
        f = np.minimum(f, 1.0 - 0.95 * np.maximum(near(T("mane"), 0.01), near(T("tailhair"), 0.01)))
        return np.minimum(f, 1.0 - near(T("hoof"), 0.003))

    def detail_kind(self, Pt, tags):
        n = len(Pt)
        T = lambda k: tags.get(k, np.full(n, 1e9))
        bare = np.maximum(near(T("nose"), 0.004), near(T("hoof"), 0.003))
        return np.where(bare > 0.5, 2.0, 0.0)

    def extra_fix(self, body, arm, co, W, vg):
        """The tail hair rides the tail bones (bone heat would share it with the thighs)."""
        tb = [(f"tail_{k:02d}", (np.array(arm.data.bones[f"tail_{k:02d}"].head_local) + np.array(arm.data.bones[f"tail_{k:02d}"].tail_local)) / 2) for k in range(1, 6)]
        for i in range(len(co)):
            p = co[i]
            if p[1] > 0.86 and abs(p[0]) < 0.14 and p[2] > 0.45:
                best = min(tb, key=lambda t: np.linalg.norm(p - t[1]))
                self.set_group(vg, i, best[0])

# Dogs and the wolf: one canine skeleton (digitigrade: the dog stands on its toes; cannon_F/H are the metacarpals and
# metatarsals, pastern_F/H and foot_F/H the toes) with breed parameters.
#   biscuit_a: the story's collie cross, 0.55 m at the shoulder, sable and white, medium-long coat with ruff, feathering, plume tail
#   dog_a:     a black-and-white working border collie, 0.53 m
#   wolf_a:    a thin young timber wolf, about 0.75 m at the shoulder, 1.3 m nose to rump, grey agouti
import numpy as np
import math
from sdf import P, Field, Ellipsoid, RoundCone, RBox, Displaced, frame, norm, rot_x, rot_y, rot_z, fbm
from species import Cattle, Quad, HeadFrame, L, near, sstep, win
from sp_more import ear_leaf
from sp_horse import streaks

class Canine(Cattle):
    preview_vox = 0.005
    vox_m = 0.0026
    cage_m = 0.025
    eye_kind = "round"
    detail_keys = ("coat", "fleece", "skin")
    gait_k = 1.0
    foot = "paw"

    def __init__(self, name, s=1.0, coat="sable", seed=6, longhair=1.0, leggy=0.0, muzzle=1.0, prick=0.5, wolf=False, drop=False, broad=1.0):
        Quad.__init__(self, name)
        self.s = s; self.coat = coat; self.seed = seed; self.lh = longhair; self.leggy = leggy; self.mz = muzzle
        self.prick = prick; self.wolf = wolf; self.calf = 0.0; self.drop = drop; self.broad = broad
        self.tex = 1024; self.lod0 = 9000 if not wolf else 11000
        self.iris = (0.55, 0.38, 0.1) if wolf else (0.32, 0.18, 0.07)
        self.lid_col = (0.05, 0.04, 0.035)
        self.lo = np.array([-0.26, -0.62, -0.01]) * s * (1 + 0.1 * leggy)
        self.hi = np.array([0.26, 0.52, 0.86]) * s * (1 + 0.1 * leggy)
        self._skeleton()

    def _skeleton(self):
        s = self.s; lg = 1.0 + 0.16 * self.leggy
        j = lambda k, a, b, z: self.j(k, a * s, b * s, z * s)
        # legs scale up (lg), the body rides on them
        up = lambda z: z * lg if z < 0.42 else z + 0.42 * (lg - 1)
        jj = lambda k, a, b, z: j(k, a, b, up(z))
        jj("tail1", 0, -0.30, 0.50); jj("sacrum", 0, -0.22, 0.50); jj("lumbar", 0, -0.05, 0.505)
        jj("thorax", 0, 0.12, 0.49); jj("withers", 0, 0.23, 0.50)
        jj("neck0", 0, 0.26, 0.46); jj("neck1", 0, 0.34, 0.56); jj("poll", 0, 0.41, 0.655)
        m = self.mz
        jj("muzzle", 0, 0.41 + 0.215 * m, 0.655 - 0.055 * m)
        jj("scap_L", 0.065, 0.17, 0.52); jj("shoulder_L", 0.075, 0.30, 0.40); jj("elbow_L", 0.07, 0.215, 0.28)
        jj("carpus_L", 0.06, 0.235, 0.075); jj("fetF_L", 0.06, 0.26, 0.032); jj("corF_L", 0.06, 0.28, 0.018); jj("toeF_L", 0.06, 0.305, 0.0)
        jj("hip_L", 0.07, -0.20, 0.44); jj("stifle_L", 0.08, -0.10, 0.30); jj("hock_L", 0.06, -0.26, 0.13)
        jj("fetH_L", 0.06, -0.225, 0.032); jj("corH_L", 0.06, -0.205, 0.018); jj("toeH_L", 0.06, -0.18, 0.0)
        if self.wolf:
            jj("tail2", 0, -0.35, 0.45); jj("tail3", 0, -0.38, 0.36); jj("tail4", 0, -0.39, 0.27); jj("tail5", 0, -0.39, 0.19)
        else:
            jj("tail2", 0, -0.355, 0.44); jj("tail3", 0, -0.39, 0.35); jj("tail4", 0, -0.405, 0.26); jj("tail5", 0, -0.40, 0.18)
        self.head = HeadFrame(self.J["poll"], self.J["muzzle"], up_hint=(0, 0, 1))
        H = self.head; hs = self.hs = s * (1.0 + 0.04 * self.wolf)
        self.jaw = (H.p(0, 0.05 * hs, -0.06 * hs), H.p(0, self.head.len * 0.92, -0.06 * hs))
        self.ears = []; self.eyes = []
        for sd in (1, -1):
            base = H.p(sd * 0.033 * hs, 0.005 * hs, -0.002 * hs)
            d = norm(H.R @ L([sd * (0.55 - 0.3 * self.prick), -0.25, 1.0])) if not self.drop else norm(H.R @ L([sd * 0.35, 0.25, -1.0]))
            if self.drop: base = H.p(sd * 0.042 * hs, 0.012 * hs, -0.008 * hs)
            self.ears.append((base, base + d * (0.09 + 0.02 * self.wolf) * hs, H.R @ L([0, 1.0, 0.1])))
            self.eyes.append((H.p(sd * 0.03 * hs, 0.07 * hs, -0.018 * hs), 0.0095 * hs))
        self.graze_h = 0.06 * s

    def eye_gaze(self, i):
        sd = 1 if i == 0 else -1
        return self.head.R @ L([sd * 0.55, 1.0, 0.15])

    def eye_up(self, i):
        return self.head.R @ L([0, 0, 1.0])

    def jaw_weight(self, co):
        q = (co - self.head.o) @ self.head.R / self.hs
        mv = -0.057
        return sstep(mv + 0.004, mv - 0.004, q[:, 2]) * sstep(0.03, 0.08, q[:, 1])

    def field(self, vox):
        s = self.s; F = Field(self.lo, self.hi, vox); J = self.J
        w = 0.88 if self.wolf else 1.0
        lg = 1.0 + 0.16 * self.leggy
        zz = lambda z: z + 0.42 * (lg - 1)
        E = lambda c, r, R=None, tag="body": Ellipsoid(P(c[0] * s, c[1] * s, zz(c[2]) * s), L(r) * s, R, tag)
        RC = lambda a, b, ra, rb, tag="body", **kw: RoundCone(P(a[0] * s, a[1] * s, zz(a[2]) * s), P(b[0] * s, b[1] * s, zz(b[2]) * s), ra * s, rb * s, tag, **kw)
        F.add(E((0, 0.13, 0.385), (0.085 * w, 0.16, 0.125)), 0)                      # deep chest
        F.add(E((0, -0.07, 0.43), (0.075 * w, 0.15, 0.08)), 0.13 * s)                # loin, tucked belly
        F.add(E((0, -0.20, 0.445), (0.072 * w, 0.09, 0.075)), 0.06 * s)              # croup
        F.add(RC((0, 0.24, 0.47), (0, -0.24, 0.455), 0.05, 0.05), 0.10 * s)            # top line
        for sg in (1, -1):
            F.add(E((sg * 0.065 * w, 0.21, 0.42), (0.035, 0.07, 0.10), rot_x(math.radians(30))), 0.04 * s)   # shoulder
            F.add(E((sg * 0.058 * w, -0.20, 0.36), (0.045, 0.085, 0.115), rot_x(math.radians(-20))), 0.06 * s)   # thigh
            F.add(E((sg * 0.06 * w, -0.17, 0.25), (0.032, 0.06, 0.07), rot_x(math.radians(25))), 0.04 * s)      # second thigh
        lat = (1, 0, 0)
        F.add(RC((0, 0.18, 0.42), (0, 0.37, 0.60), 0.10 * w, 0.062, flat=0.85, flat_axis=lat), 0.08 * s)      # neck
        self.add_legs(F, {"arm": (0.04 * s, 0.033 * s), "fore": (0.026 * s, 0.016 * s), "knee": 0.016 * s, "cannon": (0.0135 * s, 0.013 * s),
                          "fet": 0.014 * s, "past": (0.012 * s, 0.012 * s), "thigh": (0.045 * s, 0.035 * s), "gaskin": (0.035 * s, 0.016 * s),
                          "hock": 0.014 * s, "hockpt": (0.011 * s, 0.008 * s), "paw": (0.02 + 0.005 * self.wolf) * s, "k": 0.4}, foot="paw")
        # tail
        tl = [J["tail%d" % k] for k in range(1, 6)]
        for a, b, ra, rb in ((tl[0], tl[1], 0.022, 0.017), (tl[1], tl[2], 0.017, 0.014), (tl[2], tl[3], 0.014, 0.011), (tl[3], tl[4], 0.011, 0.008)):
            F.add(RoundCone(a, b, ra * s, rb * s, "body"), 0.01 * s)
        # the coat's volume: ruff, feathering, trousers, plume (long-haired), streaked along the way the hair falls
        h = self.lh
        if h > 0:
            F.add(Displaced(Ellipsoid(P(0, 0.30 * s, zz(0.47) * s), L([0.095 * w, 0.085, 0.12]) * s * (0.8 + 0.25 * h), rot_x(math.radians(-35)), "ruff"),
                            0.012 * s * h, 1.0, fn=streaks(P(0, 0.4, -1.0), 110 / s, 6, 61)), 0.03 * s)
            for sg in (1, -1):
                el, ca = J["elbow" + ("_L" if sg > 0 else "_R")], J["carpus" + ("_L" if sg > 0 else "_R")]
                F.add(Displaced(RoundCone(el + P(0, -0.02 * s, 0), ca + P(0, -0.012 * s, 0.05 * s), 0.02 * s * h, 0.008 * s, "feather"),
                                0.006 * s * h, 1.0, fn=streaks(P(0, -0.3, -1.0), 140 / s, 6, 63)), 0.012 * s)
                F.add(Displaced(Ellipsoid(P(sg * 0.06 * w * s, -0.27 * s, zz(0.33) * s), L([0.035, 0.05, 0.085]) * s * (0.8 + 0.3 * h), None, "feather"),
                                0.008 * s * h, 1.0, fn=streaks(P(0, -0.3, -1.0), 120 / s, 6, 65)), 0.025 * s)
        plume = 0.022 * (1 + 0.6 * h) * s if not self.wolf else 0.035 * s
        F.add(Displaced(RoundCone(tl[0] + (tl[1] - tl[0]) * 0.5, tl[4] + P(0, 0, -0.04 * s), plume * 0.7, plume, "plume"),
                        0.008 * s * (1 + h), 1.0, fn=streaks(tl[4] - tl[0], 120 / s, 5, 67)), 0.015 * s)
        self._head(F)
        F.cut_below(0.0)
        return F

    def _head(self, F):
        s = self.hs; H = self.head; m = self.mz
        E = lambda x, u, v, r, extra=None, tag="head": Ellipsoid(H.p(x * s, u * s, v * s), L(r) * s, H.rot(extra), tag)
        RCh = lambda a, b_, ra, rb, tag="head", **kw: RoundCone(H.p(*(L(a) * s)), H.p(*(L(b_) * s)), ra * s, rb * s, tag, **kw)
        ml = 0.21 * m
        F.add(E(0, 0.05, -0.03, (0.056 * self.broad, 0.066, 0.054)), 0.025 * s)                                      # skull
        F.add(E(0, 0.0, -0.005, (0.012, 0.05, 0.012)), 0.015 * s)                                       # sagittal crest
        F.add(RCh((0, 0.10, -0.048), (0, ml - 0.014, -0.046), 0.03, 0.023, flat=0.9, flat_axis=H.R[:, 0]), 0.018 * s)   # muzzle, below the stop
        F.add(E(0, ml - 0.006, -0.036, (0.0155, 0.013, 0.013), tag="nose"), 0.006 * s)
        for sd in (1, -1):
            F.add(E(sd * 0.036, 0.06, -0.045, (0.026, 0.04, 0.03)), 0.015 * s)                         # cheek (zygomatic)
            F.add(RCh((sd * 0.032, 0.04, -0.074), (sd * 0.014, ml - 0.03, -0.072), 0.018, 0.012), 0.012 * s)   # jaw
            F.add(RCh((sd * 0.019, 0.10, -0.057), (sd * 0.012, ml - 0.02, -0.055), 0.012, 0.01, tag="lip"), 0.006 * s)   # upper lip
            F.add(E(sd * 0.03, 0.07, -0.012, (0.016, 0.02, 0.014)), 0.01 * s)                         # brow
            F.sub(Ellipsoid(H.p(sd * 0.0065 * s, (ml + 0.002) * s, -0.034 * s), L([0.004, 0.004, 0.006]) * s, H.rot(rot_y(math.radians(sd * 30))), "nose"), 0.002 * s)
        # the mouth: a slit along the lip line so the jaw can open (bark, pant), a tongue on the floor of the mouth
        F.sub(RBox(H.p(0, (0.10 + ml) / 2 * s, -0.0575 * s), L([0.022, (ml - 0.09) / 2 + 0.004, 0.0022]) * s, H.R, rad=0.0015 * s, tag="mouth", taper=-0.3), 0.0015 * s)
        F.add(Ellipsoid(H.p(0, (ml - 0.05) * s, -0.063 * s), L([0.014, 0.055 * m, 0.006]) * s, H.R, "tongue"), 0.002 * s)
        self.mouth_box = (H.p(0, (0.10 + ml) / 2 * s, -0.0575 * s), (ml - 0.09) / 2 * s)
        self.place_eyes(F, protrude=0.4)
        for i, sd in enumerate((1, -1)):
            base, tip, face = self.ears[i]
            ln = np.linalg.norm(tip - base)
            d = norm(tip - base)
            if self.drop:
                # a drop ear: a soft leaf hanging against the cheek, its front edge about level with the eye
                ear_leaf(F, base, d, H.R @ L([sd * 1.0, 0.0, 0.0]), ln * 1.05, ln * 0.42, 0.006 * s, cup=0.0, k=0.01 * s)
                continue
            # a triangular ear: wide at the base, a pointed tip, thin front to back (the tip folds forward on a collie)
            fold = 0.0 if self.prick > 0.8 else 0.45 * (1 - self.prick)
            mid = base + d * ln * 0.55
            tipp = mid + norm(d + face * fold) * ln * 0.45
            F.add(RoundCone(base, mid, 0.026 * s, 0.014 * s, "ear", flat=0.25, flat_axis=face), 0.008 * s)
            F.add(RoundCone(mid, tipp, 0.012 * s, 0.002 * s, "ear", flat=0.3, flat_axis=face), 0.004 * s)

    # ---------------------------------------------------------------- coat
    def paint(self, Pt, nrm, tags):
        s = self.s; n = len(Pt)
        T = lambda k: tags.get(k, np.full(n, 1e9))
        up = Pt[:, 2] / s; fwd = -Pt[:, 1] / s; lat = Pt[:, 0] / s
        q = self.head_local(Pt)
        tone = fbm(Pt / s, 5.0, 3, 31)
        jit = fbm(Pt / s, 40.0, 2, 21) * 0.02
        # white markings: blaze, muzzle, collar, chest, belly, feet and legs, tail tip
        head = np.maximum(win(tags, "head", n), np.maximum(near(T("nose"), 0.002), near(T("lip"), 0.003)))
        ml = 0.21 * self.mz
        white = np.zeros(n)
        if not self.wolf and self.coat != "golden":
            blaze = (np.abs(q[:, 0]) < 0.006 + 0.03 * sstep(0.08, ml, q[:, 1]) + jit) & (q[:, 2] > -0.03) & (q[:, 1] > -0.01)
            white = np.maximum(white, blaze * head)
            white = np.maximum(white, sstep(0.13, 0.16, q[:, 1]) * head * (q[:, 2] < 0.0))               # muzzle
            collar = sstep(0.06, 0.03, np.abs(fwd - 0.32 - 0.25 * (up - 0.5)) + jit * 2) * (up > 0.38)
            white = np.maximum(white, collar * (self.coat != "tri"))
            white = np.maximum(white, sstep(0.36, 0.30, up + jit * 2) * (fwd > 0.15))                     # chest
            white = np.maximum(white, sstep(0.34, 0.30, up + jit * 2) * (np.abs(fwd) < 0.2))              # belly
            white = np.maximum(white, sstep(0.16, 0.10, up + jit * 2))                                    # legs and feet
            white = np.maximum(white, near(T("plume"), 0.01) * sstep(0.26, 0.21, up))                     # tail tip
            white = sstep(0.4, 0.6, np.clip(white + jit * 4, 0, 1))
        if self.coat == "golden":
            white = np.zeros(n)
            base = np.array([0.66, 0.46, 0.22])[None] * (1 + 0.10 * tone[:, None])
            light = np.clip(sstep(0.36, 0.28, up) + win(tags, "feather", n) * 0.8 + win(tags, "ruff", n) * 0.4 + near(T("plume"), 0.01) * 0.6, 0, 1)
            base = base * (1 - light[:, None] * 0.6) + np.array([0.88, 0.78, 0.6]) * light[:, None] * 0.6
            base = base * (1 - 0.15 * sstep(0.42, 0.52, up)[:, None])
            wc = np.array([0.9, 0.82, 0.66])
        elif self.coat == "sable":
            base = np.array([0.56, 0.34, 0.15])[None] * (1 + 0.12 * tone[:, None])
            tips = sstep(0.42, 0.52, up) * (np.abs(lat) < 0.07)                                          # darker sable saddle tips
            base = base * (1 - 0.35 * tips[:, None])
            wc = np.array([0.86, 0.84, 0.78])
        elif self.coat == "bw":
            base = np.array([0.035, 0.032, 0.03])[None] * (1 + 0.2 * tone[:, None])
            wc = np.array([0.85, 0.84, 0.80])
        else:  # wolf: grey agouti, tawny legs and head, pale underside, dark saddle and tail tip
            base = np.array([0.50, 0.49, 0.46])[None] * (1 + 0.12 * tone[:, None])
            band = np.clip(fbm(Pt / s, 150.0, 2, 77), 0, 1)
            base = base * (0.92 + 0.16 * band[:, None])
            saddle = sstep(0.44, 0.55, up) * (np.abs(lat) < 0.08) * (np.abs(fwd) < 0.3)
            grizzle = np.clip(fbm(Pt / s, 300.0, 1, 79), 0, 1)
            base = base * (1 - 0.5 * saddle[:, None] * (0.6 + 0.8 * grizzle[:, None]))
            tawny = np.clip(sstep(0.3, 0.1, up) + 0.5 * head, 0, 1)
            base = base * (1 - tawny[:, None] * 0.3) + np.array([0.55, 0.45, 0.33]) * tawny[:, None] * 0.3
            pale = np.clip(sstep(0.36, 0.30, up) * (np.abs(fwd) < 0.3) + sstep(0.16, 0.13, q[:, 1] * 0 + 0.2) * 0
                           + head * (q[:, 2] < -0.045) + head * sstep(0.02, 0.0, np.abs(q[:, 2] + 0.02) - 0.03) * 0, 0, 1)
            base = base * (1 - pale[:, None] * 0.6) + np.array([0.82, 0.78, 0.70]) * pale[:, None] * 0.6
            tip = near(T("plume"), 0.01) * sstep(0.24, 0.19, up)
            base = base * (1 - tip[:, None]) + np.array([0.05, 0.045, 0.04]) * tip[:, None]
            wc = np.array([0.8, 0.77, 0.7])
        col = base * (1 - white[:, None]) + wc * white[:, None]
        rough = 0.75 + 0.05 * tone
        nose = near(T("nose"), 0.002)
        col = col * (1 - nose[:, None]) + np.array([0.035, 0.03, 0.03]) * nose[:, None]
        rough = rough * (1 - nose) + 0.2 * nose
        # inside the mouth and the tongue: pink, wet; lips black
        mc, mh = self.mouth_box
        dm = np.linalg.norm((Pt - mc) / [1, 1, 1], axis=1)
        inner = np.maximum(near(T("tongue"), 0.002) * 0.7, (dm < mh * 1.1) * (np.abs(q[:, 2] + 0.0575) < 0.003))
        col = col * (1 - inner[:, None]) + np.array([0.28, 0.14, 0.14]) * inner[:, None]
        rough = rough * (1 - inner) + 0.25 * inner
        lip = near(T("lip"), 0.002) * (q[:, 2] < -0.05)
        col = col * (1 - lip[:, None] * 0.8) + np.array([0.04, 0.035, 0.035]) * lip[:, None] * 0.8
        nail = near(T("hoof"), 0.0015)
        col = col * (1 - nail[:, None]) + np.array([0.05, 0.045, 0.04]) * nail[:, None]
        rough = rough * (1 - nail) + 0.4 * nail
        return np.clip(col, 0, 1), np.clip(rough, 0.05, 1)

    def fur_amount(self, Pt, tags):
        n = len(Pt)
        T = lambda k: tags.get(k, np.full(n, 1e9))
        f = np.ones(n)
        f = np.minimum(f, 1.0 - 0.93 * np.maximum.reduce([near(T("nose"), 0.002), near(T("tongue"), 0.002), near(T("lip"), 0.002)]))
        f = np.minimum(f, 1.0 - near(T("hoof"), 0.0015))
        return f

    def detail_kind(self, Pt, tags):
        n = len(Pt)
        T = lambda k: tags.get(k, np.full(n, 1e9))
        bare = np.maximum.reduce([near(T("nose"), 0.002), near(T("tongue"), 0.002), near(T("hoof"), 0.0015)])
        return np.where(bare > 0.5, 2.0, 0.0)

    def extra_fix(self, body, arm, co, W, vg):
        """The plume rides the tail bones."""
        tb = [(f"tail_{k:02d}", (np.array(arm.data.bones[f"tail_{k:02d}"].head_local) + np.array(arm.data.bones[f"tail_{k:02d}"].tail_local)) / 2) for k in range(1, 6)]
        t1 = np.array(arm.data.bones["tail_01"].head_local)
        for i in range(len(co)):
            p = co[i]
            if p[1] > t1[1] + 0.01 * self.s and abs(p[0]) < 0.05 * self.s:
                best = min(tb, key=lambda t: np.linalg.norm(p - t[1]))
                self.set_group(vg, i, best[0])

    # ---------------------------------------------------------------- the tracking collar (wolf_collar_a)
    def extras(self, texs):
        if not getattr(self, "collar", False):
            return []
        import bpy
        from mathutils import Vector, Matrix
        J = self.J; s = self.s
        a, b = Vector(J["neck0"]), Vector(J["neck1"])
        c = a + (b - a) * 0.75
        d = (b - a).normalized()
        R = Vector((0, 0, 1)).rotation_difference(d).to_matrix()
        # the collar follows the neck: its radius at each angle is where the sculpt's surface is (plus the strap)
        F = self._field
        import math as _m
        radii = []
        for k in range(32):
            ang = 2 * _m.pi * k / 32
            dirn = R @ Vector((_m.cos(ang), _m.sin(ang), 0))
            S = F.surface_along(np.array(c), np.array(dirn), max_d=0.3 * s)
            radii.append((Vector(S) - c).length + 0.004 * s)
        bpy.ops.mesh.primitive_torus_add(major_radius=1.0, minor_radius=0.007 * s, major_segments=32, minor_segments=6)
        col = bpy.context.active_object; col.name = self.name + "_collar"
        for v in col.data.vertices:
            p = v.co
            ang = _m.atan2(p.y, p.x) % (2 * _m.pi)
            k = ang / (2 * _m.pi) * 32
            k0 = int(k) % 32; f = k - int(k)
            r = radii[k0] * (1 - f) + radii[(k0 + 1) % 32] * f
            rad = Vector((p.x, p.y, 0)).normalized()
            off = p - rad * 1.0
            v.co = rad * r + off
        bpy.ops.mesh.primitive_cube_add(size=1.0)
        box = bpy.context.active_object
        # the transmitter under the throat (toward -z of the neck frame, which faces down for a forward-up neck)
        dn = R.inverted() @ Vector((0, 0, -1)); dn.z = 0; dn.normalize()
        ang = _m.atan2(dn.y, dn.x) % (2 * _m.pi); k0 = int(ang / (2 * _m.pi) * 32) % 32
        box.scale = (0.03 * s, 0.025 * s, 0.022 * s); box.location = dn * (radii[k0] + 0.012 * s)
        bpy.ops.object.transform_apply(scale=True, location=True)
        for o in bpy.context.scene.objects: o.select_set(False)
        col.select_set(True); box.select_set(True); bpy.context.view_layer.objects.active = col
        bpy.ops.object.join()
        col.matrix_world = Matrix.Translation(c) @ R.to_4x4()
        bpy.ops.object.transform_apply(location=True, rotation=True)
        m = bpy.data.materials.new(self.name + "_collar_mat"); m.use_nodes = True
        bb = m.node_tree.nodes["Principled BSDF"]; bb.inputs["Base Color"].default_value = (0.05, 0.06, 0.04, 1); bb.inputs["Roughness"].default_value = 0.6
        col.data.materials.clear(); col.data.materials.append(m)
        col.data.uv_layers.new(name="UVMap")
        return [(col, "neck_01")]

    def weight_extra(self, o, arm, bone):
        o.vertex_groups.clear()
        g = o.vertex_groups.new(name=bone); g.add(list(range(len(o.data.vertices))), 1.0, "REPLACE")
        o.parent = arm
        md = o.modifiers.new("Armature", "ARMATURE"); md.object = arm

    # ---------------------------------------------------------------- clips
    def clips(self, arm, update):
        import anim
        k = self.J["shoulder_L"][2] / 0.40
        walk = dict(period=0.75 * k ** 0.5, duty=0.6, phases={"H_L": 0.0, "F_L": 0.25, "H_R": 0.5, "F_R": 0.75}, stride=0.26 * k,
                    lift_f=0.05 * k, lift_h=0.045 * k, bob=0.006 * k, pitch=0.01, roll=0.02, nod=0.04, nod_ph=1.0, scap=0.3, tail=0.25, yaw=0.03)
        trot = dict(period=0.48 * k ** 0.5, duty=0.42, phases={"H_L": 0.0, "F_R": 0.0, "H_R": 0.5, "F_L": 0.5}, stride=0.34 * k,
                    lift_f=0.08 * k, lift_h=0.07 * k, bob=0.01 * k, pitch=0.01, roll=0.01, nod=0.0, scap=0.35, tail=0.15, yaw=0.01, ears=-0.1)
        run = dict(period=0.36 * k ** 0.5, duty=0.3, phases={"H_L": 0.0, "H_R": 0.08, "F_R": 0.45, "F_L": 0.55}, stride=0.42 * k,
                   lift_f=0.1 * k, lift_h=0.09 * k, bob=0.03 * k, bob_n=1, pitch=0.16, pitch_ph=0.2, roll=0.0, nod=0.08, nod_ph=0.6,
                   scap=0.5, tail=0.1, tail_up=0.3, head_up=-0.05, ears=-0.5)
        Pg = lambda g: (lambda t, pb: anim.gait(t, pb, arm, g))
        self._speeds = {}
        for nm, g in (("walk", walk), ("trot", trot), ("run", run)):
            self._speeds[nm] = round(g["stride"] / g["duty"] / g["period"], 2)
        import anim_dog
        D = anim_dog
        out = [
            dict(name="idle", dur=6.0, fn=lambda t, pb: D.idle(t, pb, arm, 6.0, self)),
            dict(name="walk", dur=walk["period"], fn=Pg(walk)),
            dict(name="trot", dur=trot["period"], fn=Pg(trot)),
            dict(name="run", dur=run["period"], fn=Pg(run)),
        ]
        if self.wolf:
            out.append(dict(name="look", dur=6.0, fn=lambda t, pb: D.look(t, pb, arm, 6.0, self)))
        else:
            out += [
                dict(name="sit", dur=4.0, fn=lambda t, pb: D.sit(t, pb, arm, 4.0, self)),
                dict(name="lie", dur=6.0, fn=lambda t, pb: D.lie(t, pb, arm, 6.0, self)),
                dict(name="tail_wag", dur=2.0, fn=lambda t, pb: D.wag(t, pb, arm, 2.0, self)),
                dict(name="bark", dur=2.0, fn=lambda t, pb: D.bark(t, pb, arm, 2.0, self)),
                dict(name="pant", dur=2.0, fn=lambda t, pb: D.pant(t, pb, arm, 2.0, self)),
            ]
        return out

    def clip_speeds(self):
        k = self.J["shoulder_L"][2] / 0.40
        return {"walk": round(0.26 * k / 0.6 / (0.75 * k ** 0.5), 2), "trot": round(0.34 * k / 0.42 / (0.48 * k ** 0.5), 2),
                "run": round(0.42 * k / 0.3 / (0.36 * k ** 0.5), 2)}

def get(name):
    if name == "biscuit_a": return Canine("biscuit_a", s=1.0, coat="sable", seed=6, longhair=1.0, prick=0.35)
    if name == "dog_a": return Canine("dog_a", s=0.96, coat="bw", seed=12, longhair=0.6, prick=0.5)
    if name == "lost_dog_a": return Canine("lost_dog_a", s=1.02, coat="golden", seed=23, longhair=0.75, prick=0.0, drop=True, broad=1.12, muzzle=0.95)
    if name == "wolf_collar_a":
        w = Canine("wolf_collar_a", s=1.3, coat="wolf", seed=19, longhair=0.55, leggy=1.0, muzzle=1.08, prick=1.0, wolf=True)
        w.collar = True
        return w
    if name == "wolf_a": return Canine("wolf_a", s=1.3, coat="wolf", seed=19, longhair=0.55, leggy=1.0, muzzle=1.08, prick=1.0, wolf=True)
    raise KeyError(name)

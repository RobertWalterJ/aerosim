# Sheep, horses, dogs (and the wolf) and the hen: skeletons from real proportions and the sculpts built on them.
import numpy as np
import math
from sdf import P, Field, Ellipsoid, RoundCone, RBox, Displaced, frame, norm, rot_x, rot_y, rot_z, fbm, vnoise
from species import Cattle, Quad, HeadFrame, L, near, sstep, UP, FWD, win

def ear_leaf(F, base, d, face, length, width, thick, cup=0.7, tag="ear", k=0.01):
    """An ear: a flattened ellipsoid from `base` along `d`, its open face toward `face`, hollowed (cupped)."""
    Re = frame(d, face)
    F.add(Ellipsoid(base + d * length * 0.5, L([width, length * 0.55, thick]), Re, tag), k)
    if cup > 0:
        F.sub(Ellipsoid(base + d * length * 0.58 + Re[:, 2] * thick * 0.9, L([width * 0.78, length * 0.45, thick * cup]), Re, tag), thick * 0.3)

# ======================================================================= sheep
class Sheep(Cattle):
    """Suffolk-type ewe (black bare face and legs) or a white-faced ewe; lambs at about 0.6 scale with short wool."""
    preview_vox = 0.006
    vox_m = 0.0035
    cage_m = 0.03
    eye_kind = "bar"
    iris = (0.55, 0.38, 0.14)
    detail_keys = ("coat", "wool", "skin")
    gait_k = 0.9

    def __init__(self, name, s=1.0, face="black", lamb=0.0, seed=5, tint=(0.86, 0.83, 0.74), ram=False):
        Quad.__init__(self, name)
        self.s = s; self.face = face; self.lamb = lamb; self.seed = seed; self.tint = np.array(tint); self.ram = ram
        self.calf = 1.0 if lamb else 0.0
        self.tex = 1024
        self.lod0 = 10000 if not lamb else 7000
        self.lo = np.array([-0.40, -0.92, -0.01]) * s
        self.hi = np.array([0.40, 0.62, 1.05]) * s
        self.lid_col = (0.05, 0.045, 0.045) if face == "black" else (0.55, 0.45, 0.42)
        self._skeleton()

    def _skeleton(self):
        s = self.s; lb = self.lamb
        j = lambda k, a, b, z: self.j(k, a * s, b * s, z * s)
        lg = 1.0 + 0.15 * lb            # lambs: longer legs for their size
        j("tail1", 0, -0.42, 0.70); j("sacrum", 0, -0.30, 0.69); j("lumbar", 0, -0.10, 0.67)
        j("thorax", 0, 0.12, 0.65); j("withers", 0, 0.27, 0.66)
        j("neck0", 0, 0.34, 0.60); j("neck1", 0, 0.45, 0.68); j("poll", 0, 0.55, 0.80)
        j("muzzle", 0, 0.71, 0.585)
        j("scap_L", 0.10, 0.21, 0.72); j("shoulder_L", 0.11, 0.36, 0.52); j("elbow_L", 0.10, 0.27, 0.40)
        j("carpus_L", 0.09, 0.29, 0.20); j("fetF_L", 0.09, 0.30, 0.06); j("corF_L", 0.09, 0.315, 0.028); j("toeF_L", 0.09, 0.36, 0.0)
        j("hip_L", 0.10, -0.30, 0.60); j("stifle_L", 0.11, -0.20, 0.44); j("hock_L", 0.085, -0.37, 0.26)
        j("fetH_L", 0.085, -0.35, 0.06); j("corH_L", 0.085, -0.335, 0.028); j("toeH_L", 0.085, -0.29, 0.0)
        j("tail2", 0, -0.47, 0.64); j("tail3", 0, -0.49, 0.58); j("tail4", 0, -0.50, 0.53); j("tail5", 0, -0.50, 0.49)
        self.head = HeadFrame(self.J["poll"], self.J["muzzle"], up_hint=P(0, 1, 0.6))
        hs = s * (1.18 + 0.12 * lb); H = self.head; self.hs = hs
        self.jaw = (H.p(0, 0.05 * hs, -0.085 * hs), H.p(0, 0.21 * hs, -0.07 * hs))
        self.ears = []; self.eyes = []
        for sd in (1, -1):
            base = H.p(sd * 0.045 * hs, 0.025 * hs, -0.05 * hs)
            d = norm(H.R @ L([sd * 1.0, -0.15, -0.55 if face_down(self) else -0.15]))
            self.ears.append((base, base + d * 0.11 * hs, H.R @ L([0, 0.3, 1.0])))
            self.eyes.append((H.p(sd * 0.045 * hs, 0.085 * hs, -0.03 * hs), 0.0125 * hs))
        self.graze_h = 0.03 * s

    def field(self, vox):
        s = self.s; lb = self.lamb; J = self.J
        F = Field(self.lo, self.hi, vox)
        Pp = lambda a, f, u: P(a * s, f * s, u * s)
        wool = 1.0 - 0.65 * lb             # lambs have a short, tight coat
        def lumpy(prim, amp=0.016, fr=16.0, seed=0):
            def fn(p):
                return 0.6 * fbm(p / s, fr, 3, self.seed + seed) + 0.4 * np.abs(fbm(p / s, fr * 2.6, 2, self.seed + seed + 9)) * 2 - 0.3
            return Displaced(prim, amp * s * wool, fr, 3, self.seed + seed, tag="wool", fn=fn)
        # the fleece: a deep barrel of wool from the shoulders to the rump, the neck, the top of the head (Suffolk: to the poll)
        F.add(lumpy(Ellipsoid(Pp(0, -0.03, 0.57), L([0.20 + 0.04 * wool, 0.41, 0.20 + 0.03 * wool]) * s, None, "wool")), 0)
        F.add(lumpy(Ellipsoid(Pp(0, -0.30, 0.58), L([0.19 + 0.04 * wool, 0.18, 0.18 + 0.02 * wool]) * s, None, "wool"), seed=3), 0.06 * s)
        F.add(lumpy(Ellipsoid(Pp(0, 0.22, 0.58), L([0.18 + 0.03 * wool, 0.17, 0.19 + 0.02 * wool]) * s, None, "wool"), seed=5), 0.06 * s)
        F.add(lumpy(RoundCone(Pp(0, 0.28, 0.60), Pp(0, 0.47, 0.72), (0.15 + 0.03 * wool) * s, (0.085 + 0.015 * wool) * s, "wool"), seed=7), 0.07 * s)
        # wool on the upper legs (the breeches and the forearm)
        for sg in (1, -1):
            F.add(lumpy(Ellipsoid(Pp(sg * 0.1, -0.30, 0.42), L([0.08, 0.11, 0.13]) * s, None, "wool"), seed=11), 0.05 * s)
            F.add(lumpy(Ellipsoid(Pp(sg * 0.1, 0.30, 0.40), L([0.06, 0.07, 0.10]) * s, None, "wool"), seed=13), 0.05 * s)
        # docked tail in wool
        F.add(lumpy(RoundCone(J["tail1"], J["tail5"], 0.05 * s, 0.035 * s, "wool"), seed=15), 0.04 * s)
        # legs: slim, bare below the knee and hock
        self.add_legs(F, {"arm": (0.045 * s, 0.038 * s), "fore": (0.032 * s, 0.018 * s), "knee": 0.02 * s, "cannon": (0.0135 * s, 0.012 * s),
                          "fet": 0.0155 * s, "past": (0.012 * s, 0.014 * s), "thigh": (0.05 * s, 0.04 * s), "gaskin": (0.036 * s, 0.017 * s),
                          "hock": 0.017 * s, "hockpt": (0.014 * s, 0.01 * s), "claw": 0.0135 * s}, foot="cloven")
        self._head(F)
        F.cut_below(0.0)
        return F

    def _head(self, F):
        s = self.hs; H = self.head
        E = lambda x, u, v, r, extra=None, tag="head": Ellipsoid(H.p(x * s, u * s, v * s), L(r) * s, H.rot(extra), tag)
        RCh = lambda a, b_, ra, rb, tag="head": RoundCone(H.p(*(L(a) * s)), H.p(*(L(b_) * s)), ra * s, rb * s, tag)
        F.add(E(0, 0.05, -0.045, (0.05, 0.065, 0.055)), 0.03 * s)                         # cranium
        F.add(RCh((0, 0.07, -0.04), (0, 0.20, -0.038), 0.042, 0.03), 0.03 * s)           # face
        F.add(E(0, 0.13, -0.022, (0.026, 0.07, 0.022)), 0.03 * s)                         # Roman nose
        F.add(E(0, 0.215, -0.05, (0.03, 0.035, 0.037), tag="muzzle"), 0.025 * s)
        F.add(E(0, 0.232, -0.045, (0.026, 0.018, 0.03), tag="nose"), 0.01 * s)
        for sd in (1, -1):
            F.add(RCh((sd * 0.03, 0.05, -0.095), (sd * 0.012, 0.21, -0.075), 0.024, 0.014), 0.02 * s)     # jaw
            F.add(E(sd * 0.034, 0.085, -0.075, (0.02, 0.05, 0.035)), 0.02 * s)                            # cheek
            F.add(E(sd * 0.04, 0.08, -0.033, (0.018, 0.022, 0.02)), 0.015 * s)                           # orbit
            F.sub(Ellipsoid(H.p(sd * 0.014 * s, 0.243 * s, -0.04 * s), L([0.005, 0.005, 0.011]) * s, H.rot(rot_y(math.radians(sd * 35))), "nose"), 0.003 * s)
        self.place_eyes(F, protrude=0.36)
        for i, sd in enumerate((1, -1)):
            base, tip, face = self.ears[i]
            ear_leaf(F, base, norm(tip - base), face, 0.12 * s, 0.034 * s, 0.007 * s, k=0.012 * s)
        if self.ram:
            # a ram's horns: ridged spirals from the poll, back, down and forward round the ear
            for sd in (1, -1):
                pts = []
                for k in range(15):
                    t = k / 14.0
                    a = t * 1.65 * math.pi
                    r = 0.055 * (1 - 0.35 * t)
                    # spiral in the head's side plane (u along the head, v up), stepping outward as it turns
                    pts.append(H.p(sd * (0.05 + 0.055 * t) * s, (0.0 - r * math.sin(a) + 0.01) * s, (0.005 + r * math.cos(a) - r * 0.4) * s))
                for k in range(len(pts) - 1):
                    t = k / 14.0
                    F.add(Displaced(RoundCone(pts[k], pts[k + 1], (0.022 - 0.014 * t) * s, (0.021 - 0.014 * t) * s, "horn"), 0.0015 * s, 1.0,
                                    fn=lambda p_: np.sin(np.linalg.norm(p_ - H.o, axis=1) * 900.0)), 0.004 * s)
        if self.face == "white" or self.lamb:
            # a white-faced ewe keeps a little wool on the poll
            F.add(Displaced(Ellipsoid(H.p(0, 0.0, -0.045 * s), L([0.05, 0.05, 0.04]) * s, H.R, "wool"), 0.006 * s, 30, 2, 3), 0.02 * s)

    # ---------------------------------------------------------------- coat
    def paint(self, Pt, nrm, tags):
        s = self.s; n = len(Pt)
        T = lambda k: tags.get(k, np.full(n, 1e9))
        up = Pt[:, 2] / s
        wool = self.wool_mask(Pt, tags)
        tone = fbm(Pt, 6.0, 3, 31)
        wcol = self.tint[None] * (1 + 0.08 * tone[:, None]) * (1 - 0.18 * np.clip(fbm(Pt, 30.0, 2, 33), 0, 1)[:, None])
        # dirt: browner low on the belly and the breech, lanolin yellow in the crevices
        dirt = np.clip(sstep(0.45, 0.30, up) * 0.6 + 0.25 * np.clip(fbm(Pt, 9.0, 2, 37), 0, 1), 0, 1)
        wcol = wcol * (1 - dirt[:, None] * 0.35) + np.array([0.45, 0.36, 0.24])[None] * dirt[:, None] * 0.35
        if self.face == "black":
            skin = np.array([0.045, 0.04, 0.038]) * (1 + 0.3 * tone[:, None])
        else:
            skin = np.array([0.78, 0.74, 0.66]) * (1 + 0.06 * tone[:, None])
        col = wcol * wool[:, None] + skin * (1 - wool[:, None])
        rough = 0.85 * wool + 0.7 * (1 - wool)
        nose = near(T("nose"), 0.003)
        ncol = np.array([0.05, 0.045, 0.045]) if self.face == "black" else np.array([0.55, 0.42, 0.40])
        col = col * (1 - nose[:, None]) + ncol * nose[:, None]
        rough = rough * (1 - nose) + 0.25 * nose
        horn = near(T("horn"), 0.002)
        if horn.any():
            col = col * (1 - horn[:, None]) + np.array([0.66, 0.6, 0.48]) * (1 + 0.15 * fbm(Pt, 120, 2, 3))[:, None] * horn[:, None]
            rough = rough * (1 - horn) + 0.5 * horn
        hoof = near(T("hoof"), 0.002)
        col = col * (1 - hoof[:, None]) + np.array([0.06, 0.055, 0.05]) * hoof[:, None]
        rough = rough * (1 - hoof) + 0.5 * hoof
        return np.clip(col, 0, 1), rough

    def wool_mask(self, Pt, tags):
        """Fleece everywhere except the bare face, ears, horns, lower legs and feet: one complement mask, so there is no
        seam where two parts of the fleece meet."""
        n = len(Pt)
        up = Pt[:, 2] / self.s
        skin = np.maximum.reduce([win(tags, k, n) for k in ("head", "muzzle", "nose", "ear", "leg", "hoof", "horn") if k in tags] + [np.zeros(n)])
        skin = np.maximum(skin, win(tags, "body", n) * sstep(0.33, 0.27, up))
        return np.clip(1.0 - skin, 0.0, 1.0)

    def fur_amount(self, Pt, tags):
        n = len(Pt)
        T = lambda k: tags.get(k, np.full(n, 1e9))
        wool = self.wool_mask(Pt, tags)
        f = 0.1 + 0.9 * wool                                       # short hair on the face and legs
        f = np.minimum(f, 1.0 - 0.93 * near(T("nose"), 0.003))
        f = np.minimum(f, 1.0 - near(T("horn"), 0.002))
        return np.minimum(f, 1.0 - near(T("hoof"), 0.002))

    def detail_kind(self, Pt, tags):
        n = len(Pt)
        T = lambda k: tags.get(k, np.full(n, 1e9))
        w = self.wool_mask(Pt, tags)
        bare = np.maximum.reduce([near(T("nose"), 0.003), near(T("hoof"), 0.002), near(T("horn"), 0.002)])
        return np.where(bare > 0.5, 2.0, np.where(w > 0.5, 1.0, 0.0))

    def extra_fix(self, body, arm, co, W, vg):
        pass

def face_down(sp):
    return getattr(sp, "face", "black") == "black"

# ======================================================================= registry
def get(name):
    if name == "sheep_a": return Sheep("sheep_a", face="black", seed=5)
    if name == "ram_a": return Sheep("ram_a", s=1.12, face="white", seed=13, tint=(0.86, 0.84, 0.77), ram=True)
    if name == "sheep_b": return Sheep("sheep_b", s=0.96, face="white", seed=9, tint=(0.88, 0.86, 0.79))
    if name == "lamb_a": return Sheep("lamb_a", s=0.62, face="black", lamb=1.0, seed=7, tint=(0.9, 0.88, 0.82))
    if name in ("horse_a", "horse_b"):
        import sp_horse
        return sp_horse.Horse(name, coat="bay" if name == "horse_a" else "grey", seed=4 if name == "horse_a" else 8)
    if name in ("biscuit_a", "dog_a", "wolf_a", "lost_dog_a", "wolf_collar_a"):
        import sp_dog
        return sp_dog.get(name)
    if name == "chicken_a":
        import sp_hen
        return sp_hen.Hen("chicken_a")
    raise KeyError(name)

# The animals: skeletons (joint positions in metres from real proportions) and the sculpt built on them.
# Frame: (lat, fwd, up) -> Blender (x, -y, z) through sdf.P. Left side is +lat. Origin on the ground under the middle.
import numpy as np
import math
from sdf import P, Field, Ellipsoid, RoundCone, RBox, Displaced, frame, norm, rot_x, rot_y, rot_z, fbm, vnoise

def L(v):
    return np.asarray(v, float)

def mirror(p):
    q = np.array(p, float); q[0] = -q[0]; return q

class HeadFrame:
    """Head-local frame: origin at the poll (top of the head between the ears), y along the head to the muzzle tip,
    z the face's front (forehead side), x the animal's left."""
    def __init__(self, poll, muzzle, up_hint=(0, 0, 1)):
        self.o = L(poll)
        self.R = frame(L(muzzle) - L(poll), L(up_hint))
        self.len = float(np.linalg.norm(L(muzzle) - L(poll)))
    def p(self, x, u, v):
        return self.o + self.R @ L([x, u, v])
    def rot(self, extra=None):
        return self.R if extra is None else self.R @ extra

class Spec:
    preview_vox = 0.008
    def __init__(self, name):
        self.name = name
        self.J = {}           # joint name -> Blender point (left side joints end in _L)
        self.eyes = []        # (centre, radius) left then right
    def j(self, k, lat, fwd, up):
        self.J[k] = P(lat, fwd, up)
        if k.endswith("_L"):
            self.J[k[:-2] + "_R"] = P(-lat, fwd, up)

def near(d, w):
    """1 inside a tagged part, falling to 0 at distance w outside it."""
    return np.clip(1.0 - np.maximum(d, 0.0) / w, 0.0, 1.0)

def win(tags, key, n, soft=0.012):
    """Soft mask of where `key` is the closest tagged part (works across smooth blends, unlike a distance threshold)."""
    d = tags.get(key, np.full(n, 1e9))
    others = [v for k, v in tags.items() if k != key]
    o = np.min(np.stack(others), axis=0) if others else np.full(n, 1e9)
    t = np.clip(0.5 - (d - o) / (2 * soft), 0.0, 1.0)
    return t * t * (3 - 2 * t)

def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)

UP = np.array([0.0, 0.0, 1.0])
FWD = np.array([0.0, -1.0, 0.0])

class Quad(Spec):
    """Shared by every four-legged animal: the bone layout (same names for all), the controls, weight fixes and eyes."""
    detail_keys = ("coat", "fleece", "skin")
    eye_kind = "oval"
    iris = (0.16, 0.09, 0.05)
    lid_col = (0.2, 0.15, 0.12)
    graze_h = 0.05
    foot = "hoof"
    tex = 1024
    lod0 = 12000
    lod_ratio = (0.35, 0.10)
    vox_m = 0.005                 # voxel size for an animal of scale 1
    cage_m = 0.03

    @property
    def vox(self):
        return self.vox_m * max(self.s, 0.6)

    @property
    def cage(self):
        return self.cage_m * self.s

    @property
    def mat_name(self):
        return self.name + "_coat"

    def eye_gaze(self, i):
        sd = 1 if i == 0 else -1
        return self.head.R @ L([sd * 1.0, 0.35, 0.25])

    def eye_up(self, i):
        return self.head.R @ L([0, -0.3, 1.0])

    def bones(self):
        J = self.J; s = self.s
        out = []
        def b(name, h, t, parent, zref, deform=True):
            out.append((name, tuple(h), tuple(t), parent, tuple(zref), deform))
        b("root", (0, 0, 0), P(0, 0.3 * s, 0), None, UP, False)
        hipc = (J["hip_L"] + J["hip_R"]) / 2 + P(0, 0, 0.06 * s)
        b("hips", hipc, J["lumbar"], "root", UP)
        b("spine_01", J["lumbar"], J["thorax"], "hips", UP)
        b("spine_02", J["thorax"], J["withers"], "spine_01", UP)
        b("chest", J["withers"], J["neck0"], "spine_02", UP)
        b("neck_01", J["neck0"], J["neck1"], "chest", UP)
        b("neck_02", J["neck1"], J["poll"], "neck_01", UP)
        b("head", J["poll"], J["muzzle"], "neck_02", self.head.R[:, 2])
        b("jaw", self.jaw[0], self.jaw[1], "head", self.head.R[:, 2])
        for i in range(2):
            base, tip, zr = self.ears[i]
            sd = "_L" if base[0] > 0 else "_R"          # named by where it is (the head frame's x is the animal's right)
            b("ear" + sd, base, tip, "head", zr)
            c, r = self.eyes[i]
            sd = "_L" if c[0] > 0 else "_R"
            g = norm(self.eye_gaze(i)); u = norm(self.eye_up(i))
            sx = norm(np.cross(g, u))
            b("eyelid" + sd, c, c + sx * max(r * 1.5, 0.012 * s), "head", u)
        tails = [J["tail%d" % k] for k in range(1, 6)]
        tails.append(tails[-1] + (tails[-1] - tails[-2]) * 0.8)
        par = "hips"
        for k in range(5):
            b("tail_%02d" % (k + 1), tails[k], tails[k + 1], par, UP); par = "tail_%02d" % (k + 1)
        for sd in ("_L", "_R"):
            b("scapula" + sd, J["scap" + sd], J["shoulder" + sd], "chest", FWD)
            b("upperarm" + sd, J["shoulder" + sd], J["elbow" + sd], "scapula" + sd, FWD)
            b("forearm" + sd, J["elbow" + sd], J["carpus" + sd], "upperarm" + sd, FWD)
            b("cannon_F" + sd, J["carpus" + sd], J["fetF" + sd], "forearm" + sd, FWD)
            b("pastern_F" + sd, J["fetF" + sd], J["corF" + sd], "cannon_F" + sd, FWD)
            b("foot_F" + sd, J["corF" + sd], J["toeF" + sd], "pastern_F" + sd, FWD)
            b("thigh" + sd, J["hip" + sd], J["stifle" + sd], "hips", FWD)
            b("shin" + sd, J["stifle" + sd], J["hock" + sd], "thigh" + sd, FWD)
            b("cannon_H" + sd, J["hock" + sd], J["fetH" + sd], "shin" + sd, FWD)
            b("pastern_H" + sd, J["fetH" + sd], J["corH" + sd], "cannon_H" + sd, FWD)
            b("foot_H" + sd, J["corH" + sd], J["toeH" + sd], "pastern_H" + sd, FWD)
            b("ctrl_F" + sd, J["fetF" + sd], J["corF" + sd], "root", FWD, False)
            b("ctrl_H" + sd, J["fetH" + sd], J["corH" + sd], "root", FWD, False)
        return out

    def setup_controls(self, arm):
        """IK from the cannon bone up three bones to each leg's control; the pastern copies the control's rotation."""
        pb = arm.pose.bones
        for sd in ("_L", "_R"):
            for leg, chain in (("F", ("cannon_F", "forearm", "upperarm")), ("H", ("cannon_H", "shin", "thigh"))):
                c = pb[chain[0] + sd].constraints.new("IK")
                c.target = arm; c.subtarget = "ctrl_%s%s" % (leg, sd); c.chain_count = 3; c.use_tail = True; c.use_stretch = False
                for bn in chain:
                    pb[bn + sd].lock_ik_y = True; pb[bn + sd].lock_ik_z = True
                cr = pb["pastern_%s%s" % (leg, sd)].constraints.new("COPY_ROTATION")
                cr.target = arm; cr.subtarget = "ctrl_%s%s" % (leg, sd)
                cr.target_space = "WORLD"; cr.owner_space = "WORLD"
        for b in pb:
            b.rotation_mode = "QUATERNION"

    def fix_weights(self, body, arm):
        """Lids belong to the lid meshes only; the lower jaw goes to the jaw bone by a geometric split; any vertex that
        bone heat missed takes the nearest bone; species extras (udder on the hips) in extra_fix."""
        me = body.data
        vg = body.vertex_groups
        for nm in ("eyelid_L", "eyelid_R", "root"):
            if nm in vg: vg.remove(vg[nm])
        co = np.array([v.co[:] for v in me.vertices])
        names = [g.name for g in vg]
        W = [dict() for _ in range(len(co))]
        for v in me.vertices:
            for g in v.groups:
                W[v.index][names[g.group]] = g.weight
        if "jaw" in vg and "head" in vg:
            jw = self.jaw_weight(co)
            for i, w in enumerate(W):
                h = w.get("head", 0.0) + w.get("jaw", 0.0)
                if h > 0.0:
                    vg["head"].add([i], h * (1 - jw[i]), "REPLACE")
                    vg["jaw"].add([i], h * jw[i], "REPLACE")
        self.extra_fix(body, arm, co, W, vg)
        idx = set(g.name for g in vg)
        bones = [(bn.name, np.array(bn.head_local), np.array(bn.tail_local)) for bn in arm.data.bones if bn.use_deform and bn.name in idx]
        for v in me.vertices:
            if sum(g.weight for g in v.groups) < 1e-4:
                p = np.array(v.co)
                best, bd = None, 1e9
                for nm, h, t in bones:
                    ab = t - h; tt = np.clip(np.dot(p - h, ab) / max(np.dot(ab, ab), 1e-9), 0, 1)
                    d = np.linalg.norm(p - (h + ab * tt))
                    if d < bd: best, bd = nm, d
                vg[best].add([v.index], 1.0, "REPLACE")

    def jaw_weight(self, co):
        H = self.head
        q = (co - H.o) @ H.R / self.hs
        return sstep(0.105, 0.15, -q[:, 2]) * sstep(0.06, 0.16, q[:, 1])

    def extra_fix(self, body, arm, co, W, vg):
        pass

    def place_eyes(self, F, protrude=0.4, socket=1.06):
        """Sets each eyeball so it stands proud of the skin by `protrude` of its radius (found on the sculpt itself), and
        carves a socket for it."""
        for i, (ec0, er) in enumerate(self.eyes):
            g = norm(self.eye_gaze(i))
            S = F.surface_along(ec0 - g * er * 1.5, g, max_d=er * 3.5)
            ec = S - g * er * (1.0 - protrude)
            self.eyes[i] = (ec, er)
            # no socket is carved: the eyeball stands out of the skin and the skin closes round it (a carved pit makes
            # the low-poly bake miss the sculpt and leaves a dark ring)

    def add_legs(self, F, R, foot="cloven"):
        """Four legs from the joints, radii (metres) from R: arm, fore, knee, cannon, fet, past, thigh, gaskin, hock, hockpt,
        flank (r of the fold from stifle to belly), each a (start, end) pair or a single radius. foot: cloven, hoof or paw."""
        J = self.J; s = self.s
        lat = np.array([1.0, 0, 0])
        g = lambda k: R[k] if isinstance(R[k], (tuple, list)) else (R[k], R[k])
        k = R.get("k", 0.6)
        for side in ("_L", "_R"):
            sg = 1 if side == "_L" else -1
            sh, el, ca, fe, co, to = (J[n + side] for n in ("shoulder", "elbow", "carpus", "fetF", "corF", "toeF"))
            F.add(RoundCone(sh, el, *g("arm"), "body"), g("arm")[0] * 0.9)
            F.add(Ellipsoid(el + (el - sh) * 0.0 + P(0, -g("fore")[0] * 0.7, g("fore")[0] * 0.2), L([g("fore")[0] * 0.6] * 3), None, "body"), g("fore")[0] * 0.5)
            F.add(RoundCone(el, ca + P(0, 0, g("knee")[0] * 0.5), *g("fore"), "body", flat=0.8, flat_axis=lat), g("fore")[0] * 0.6)
            F.add(Ellipsoid(ca, L([g("knee")[0], g("knee")[0] * 1.08, g("knee")[0] * 1.1]), None, "body"), g("knee")[0] * 0.6)
            F.add(RoundCone(ca, fe, *g("cannon"), "leg", flat=0.85, flat_axis=lat), g("cannon")[0] * 0.6)
            F.add(Ellipsoid(fe, L([g("fet")[0], g("fet")[0] * 1.05, g("fet")[0] * 0.95]), None, "leg"), g("fet")[0] * 0.4)
            F.add(RoundCone(fe, co, *g("past"), "leg"), g("past")[0] * 0.4)
            self.add_foot(F, co, to, foot, sg, R, front=True)
            hp, st, hk, fe2, co2, to2 = (J[n + side] for n in ("hip", "stifle", "hock", "fetH", "corH", "toeH"))
            F.add(RoundCone(hp, st, *g("thigh"), "body"), g("thigh")[0] * 0.8)
            if "flank" in R:
                fl = (st + hp) / 2 + P(-sg * 0.0, 0.03 * s, -0.02 * s); fl[0] *= 0.8
                F.add(Ellipsoid(fl, L([R["flank"] * 0.9, R["flank"], R["flank"]]), None, "body"), R["flank"] * 0.8)
            F.add(RoundCone(st, hk + P(0, 0, g("hock")[0] * 0.8), *g("gaskin"), "body", flat=0.7, flat_axis=lat), g("gaskin")[0] * 0.6)
            F.add(RoundCone(hk + P(0, -g("hock")[0] * 0.3, g("hock")[0] * 0.3), hk + P(0, -g("hock")[0] * 1.15, g("hock")[0] * 1.2), g("hockpt")[0], g("hockpt")[1], "leg"), g("hockpt")[0] * 0.6)
            F.add(Ellipsoid(hk, L([g("hock")[0], g("hock")[0] * 1.3, g("hock")[0] * 1.1]), None, "leg"), g("hock")[0] * 0.5)
            F.add(RoundCone(hk, fe2, *g("cannon"), "leg", flat=0.8, flat_axis=lat), g("cannon")[0] * 0.6)
            F.add(Ellipsoid(fe2, L([g("fet")[0], g("fet")[0] * 1.05, g("fet")[0] * 0.95]), None, "leg"), g("fet")[0] * 0.4)
            F.add(RoundCone(fe2, co2, *g("past"), "leg"), g("past")[0] * 0.4)
            self.add_foot(F, co2, to2, foot, sg, R, front=False)

    def add_foot(self, F, co, to, foot, sg, R, front):
        s = self.s
        if foot == "cloven":
            cw = R.get("claw", 0.03)                     # claw radius at the coronet
            for kk in (1, -1):
                o = P(kk * cw * 0.75, 0, 0)
                F.add(RoundCone(co + o, to + o * 0.75 + P(0, -cw * 0.6, cw * 0.4), cw, cw * 0.4, "hoof"), cw * 0.25)
                F.add(Ellipsoid(co + o + P(0, cw * 0.8, -cw * 1.1), L([cw * 0.85, cw * 1.6, cw]), None, "hoof"), cw * 0.3)
            F.sub(RBox((co + to) / 2 + P(0, cw * 0.6, -cw * 0.6), L([cw * 0.11, cw * 2.3, cw * 1.6]), rad=cw * 0.06, tag="hoof"), cw * 0.1)
        elif foot == "hoof":
            hr = R.get("hoofr", 0.06)
            base = np.array(to, float); base[2] = 0.0
            F.add(RoundCone(co + P(0, -hr * 0.1, 0), base + P(0, -hr * 0.55, hr * 0.15), hr * 0.85, hr, "hoof"), hr * 0.15)
        else:  # paw: a pad and four toes, nails
            pr = R.get("paw", 0.025)
            base = np.array(to, float)
            F.add(Ellipsoid(base + P(0, -pr * 0.6, pr * 0.75), L([pr * 1.05, pr * 1.25, pr * 0.8]), None, "leg"), pr * 0.5)
            for i, (dx, dy) in enumerate(((-0.55, 0.55), (-0.2, 0.85), (0.2, 0.85), (0.55, 0.55))):
                tc = base + P(dx * pr * 1.4, dy * pr * 1.0, pr * 0.45)
                F.add(Ellipsoid(tc, L([pr * 0.38, pr * 0.48, pr * 0.42]), None, "leg"), pr * 0.25)
                F.add(RoundCone(tc + P(0, pr * 0.3, 0.0), tc + P(0, pr * 0.62, -pr * 0.3), pr * 0.12, pr * 0.05, "hoof"), pr * 0.05)

    def set_group(self, vg, i, name, w=1.0):
        """Give vertex i entirely to bone `name`."""
        for g in vg:
            g.remove([i])
        vg[name].add([i], w, "REPLACE")

# ======================================================================= cattle
class Cattle(Quad):
    """Dairy and beef cattle. `s` scales the whole animal (calf, Jersey); `beef` fills out the body (Hereford)."""
    preview_vox = 0.009
    lod0 = 16000
    def __init__(self, name, s=1.0, beef=0.0, horns=0.0, calf=0.0, dished=0.0, coat="holstein", seed=3):
        super().__init__(name)
        self.s = s; self.beef = beef; self.horns = horns; self.calf = calf; self.dished = dished
        self.coat = coat; self.seed = seed
        self.tex = 2048 if s > 0.8 else 1024
        self.lod0 = 16000 if s > 0.8 else 11000
        self.lo = P(-0.6, 1.6, -0.01) * 0 + np.array([-0.62, -1.62, -0.01]) * s
        self.hi = np.array([0.62, 1.15, 1.75]) * s
        self._skeleton()

    def _skeleton(self):
        s = self.s; c = self.calf
        j = lambda k, a, b, z: self.j(k, a * s, b * s, z * s)
        # spine (vertebral line, inside the body)
        j("tail1", 0, -0.86, 1.36); j("sacrum", 0, -0.62, 1.32); j("lumbar", 0, -0.22, 1.27)
        j("thorax", 0, 0.20, 1.22); j("withers", 0, 0.52, 1.20)
        j("neck0", 0, 0.64, 1.08); j("neck1", 0, 0.90, 1.18); j("poll", 0, 1.10, 1.32)
        j("muzzle", 0, 1.43, 0.88)
        # front leg (left)
        j("scap_L", 0.17, 0.42, 1.36); j("shoulder_L", 0.20, 0.68, 1.02); j("elbow_L", 0.19, 0.52, 0.76)
        j("carpus_L", 0.19, 0.57, 0.42); j("fetF_L", 0.19, 0.59, 0.14); j("corF_L", 0.19, 0.635, 0.065); j("toeF_L", 0.19, 0.72, 0.0)
        # hind leg
        j("hip_L", 0.20, -0.60, 1.12); j("stifle_L", 0.21, -0.47, 0.80); j("hock_L", 0.17, -0.78, 0.50)
        j("fetH_L", 0.17, -0.74, 0.14); j("corH_L", 0.17, -0.705, 0.065); j("toeH_L", 0.17, -0.62, 0.0)
        j("tail2", 0, -0.94, 1.18); j("tail3", 0, -0.97, 0.90); j("tail4", 0, -0.975, 0.66); j("tail5", 0, -0.97, 0.50)
        self.head = HeadFrame(self.J["poll"], self.J["muzzle"], up_hint=P(0, 1, 0.6))
        hs = s * (1.1 + 0.12 * c); H = self.head
        self.hs = hs
        self.jaw = (H.p(0, 0.10 * hs, -0.17 * hs), H.p(0, 0.45 * hs, -0.15 * hs))
        self.ears = []
        self.eyes = []
        er = 0.021 * s * (1.0 + 0.15 * c)
        for sd in (1, -1):
            base = H.p(sd * 0.10 * hs, 0.05 * hs, -0.11 * hs)
            d = norm(H.R @ L([sd * 1.0, -0.15, -0.35]))
            self.ears.append((base, base + d * 0.21 * hs, H.R @ L([0, 0.3, 1.0])))
            self.eyes.append((H.p(sd * 0.108 * hs, 0.17 * hs, -0.062 * hs), er))
        self.graze_h = 0.05 * s

    def field(self, vox):
        s = self.s; b = self.beef; c = self.calf
        F = Field(self.lo, self.hi, vox)
        Pp = lambda a, f, u: P(a * s, f * s, u * s)
        E = lambda c_, r, R=None, tag="body": Ellipsoid(c_, L(r) * s, R, tag)
        RC = lambda a_, b_, ra, rb, tag="body", **kw: RoundCone(a_, b_, ra * s, rb * s, tag, **kw)
        # ---- barrel: three overlapping sections from chest to flank
        F.add(E(Pp(0, 0.42, 1.06), (0.24 + 0.03 * b, 0.40, 0.37)), 0.0)
        F.add(E(Pp(0, -0.02, 1.02 + 0.03 * c), (0.31 + 0.03 * b, 0.48, 0.37 - 0.04 * c)), 0.16 * s)
        F.add(E(Pp(0, -0.46, 1.12), (0.25 + 0.04 * b, 0.36, 0.29)), 0.14 * s)
        # top line: withers to hooks, nearly level
        F.add(RC(Pp(0, 0.55, 1.36), Pp(0, -0.50, 1.40), 0.11 + 0.03 * b, 0.12 + 0.03 * b), 0.10 * s)
        F.add(E(Pp(0, 0.52, 1.37), (0.10, 0.20, 0.10), tag="body"), 0.08 * s)       # withers
        # rump: flat and broad, hooks to pins
        F.add(RBox(Pp(0, -0.72, 1.33), L([0.20 + 0.04 * b, 0.17, 0.09]) * s, rad=0.08 * s), 0.08 * s)
        for side in (1, -1):
            F.add(E(Pp(side * (0.235 + 0.03 * b), -0.52, 1.38), (0.055, 0.07, 0.05)), 0.07 * s)        # hook bones
            F.add(E(Pp(side * 0.11, -0.88, 1.33), (0.045, 0.05, 0.045)), 0.04 * s)                   # pin bones
            # hindquarter: thigh and buttock muscle
            F.add(E(Pp(side * (0.18 + 0.03 * b), -0.66, 0.98), (0.12 + 0.03 * b, 0.21 + 0.03 * b, 0.34), rot_x(math.radians(-12))), 0.07 * s)
            F.add(E(Pp(side * 0.12, -0.82, 1.08), (0.10 + 0.02 * b, 0.10 + 0.02 * b, 0.26)), 0.05 * s)
            # shoulder blade and point of shoulder
            F.add(E(Pp(side * 0.215, 0.55, 1.14), (0.07, 0.15, 0.26), rot_x(math.radians(28))), 0.06 * s)
            F.add(E(Pp(side * 0.22, 0.70, 1.01), (0.08, 0.08, 0.08)), 0.06 * s)
        # brisket and dewlap
        F.add(E(Pp(0, 0.70, 0.86), (0.16, 0.16, 0.15)), 0.10 * s)
        F.add(E(Pp(0, 0.86, 0.92), (0.045 + 0.02 * b, 0.10, 0.17), rot_x(math.radians(-25))), 0.07 * s)
        # neck: deep at the base, slim at the throat
        F.add(RC(Pp(0, 0.62, 1.10), Pp(0, 1.00, 1.18), 0.27 + 0.03 * b, 0.15), 0.10 * s)
        F.add(RC(Pp(0, 0.52, 1.33), Pp(0, 1.04, 1.31), 0.10, 0.075), 0.08 * s)          # crest
        F.add(RC(Pp(0, 0.78, 0.92), Pp(0, 1.04, 1.06), 0.11, 0.085), 0.08 * s)          # throat
        # udder and teats (cows, not calves)
        if c < 0.5:
            F.add(Ellipsoid(Pp(0, -0.46, 0.66), L([0.16, 0.19, 0.13]) * s, tag="udder"), 0.07 * s)
            for side in (1, -1):
                for fz in (-0.37, -0.55):
                    F.add(RoundCone(Pp(side * 0.065, fz, 0.56), Pp(side * 0.07, fz + 0.005, 0.49), 0.017 * s, 0.012 * s, "teat"), 0.012 * s)
        # legs
        J = self.J
        for side in ("_L", "_R"):
            sg = 1 if side == "_L" else -1
            lat = np.array([1.0, 0, 0])
            sh, el, ca, fe, co, to = (J[k + side] for k in ("shoulder", "elbow", "carpus", "fetF", "corF", "toeF"))
            F.add(RC(sh, el, 0.085 + 0.02 * b, 0.075), 0.09 * s)                            # upper arm in the chest wall
            F.add(E(el + P(0, -0.06, 0.02) * s, (0.05, 0.06, 0.06)), 0.04 * s)            # point of elbow
            F.add(RC(el, ca + P(0, 0, 0.03) * s, 0.082 + 0.01 * b, 0.048, flat=0.8, flat_axis=lat), 0.05 * s)   # forearm
            F.add(E(ca, (0.048, 0.052, 0.052)), 0.03 * s)                                  # knee (carpus)
            F.add(RC(ca, fe, 0.04, 0.036, flat=0.85, flat_axis=lat), 0.025 * s)            # cannon
            F.add(E(fe + P(0, -0.008, 0) * s, (0.044, 0.046, 0.042)), 0.02 * s)            # fetlock
            F.add(RC(fe, co, 0.035, 0.04), 0.015 * s)                                      # pastern
            self._claws(F, co, to, s, sg)
            F.add(E(fe + P(0, -0.05, -0.03) * s + P(sg * 0.022, 0, 0) * s, (0.013, 0.02, 0.015), tag="hoof"), 0.006 * s)   # dewclaws
            F.add(E(fe + P(0, -0.05, -0.03) * s + P(-sg * 0.022, 0, 0) * s, (0.013, 0.02, 0.015), tag="hoof"), 0.006 * s)
            hp, st, hk, fe2, co2, to2 = (J[k + side] for k in ("hip", "stifle", "hock", "fetH", "corH", "toeH"))
            F.add(RC(hp, st, 0.10 + 0.03 * b, 0.08), 0.08 * s)                              # thigh
            F.add(E(P(sg * 0.17, -0.42, 0.90) * s, (0.10, 0.13, 0.12)), 0.10 * s)      # flank fold to the stifle
            F.add(E(st + P(0, 0.0, 0.02) * s, (0.055, 0.05, 0.065)), 0.05 * s)              # stifle
            F.add(RC(st, hk + P(0, 0.0, 0.04) * s, 0.085 + 0.02 * b, 0.045, flat=0.7, flat_axis=lat), 0.06 * s)  # gaskin
            F.add(RC(hk + P(0, -0.02, 0.02) * s, hk + P(0, -0.085, 0.07) * s, 0.04, 0.03), 0.03 * s)   # point of hock
            F.add(E(hk, (0.045, 0.06, 0.05)), 0.025 * s)
            F.add(RC(hk, fe2, 0.042, 0.036, flat=0.8, flat_axis=lat), 0.025 * s)
            F.add(E(fe2 + P(0, -0.008, 0) * s, (0.044, 0.046, 0.042)), 0.02 * s)
            F.add(RC(fe2, co2, 0.035, 0.04), 0.015 * s)
            self._claws(F, co2, to2, s, sg)
            F.add(E(fe2 + P(0, -0.05, -0.03) * s + P(sg * 0.022, 0, 0) * s, (0.013, 0.02, 0.015), tag="hoof"), 0.006 * s)
            F.add(E(fe2 + P(0, -0.05, -0.03) * s + P(-sg * 0.022, 0, 0) * s, (0.013, 0.02, 0.015), tag="hoof"), 0.006 * s)
        # tail: a slim tail hanging to the hocks with a switch
        F.add(RC(J["tail1"] + P(0, 0.03, 0.02) * s, J["tail2"], 0.04, 0.03), 0.06 * s)
        F.add(RC(J["tail2"], J["tail3"], 0.03, 0.022), 0.01 * s)
        F.add(RC(J["tail3"], J["tail4"], 0.022, 0.018), 0.008 * s)
        F.add(RC(J["tail4"], J["tail5"], 0.018, 0.016), 0.006 * s)
        F.add(Displaced(Ellipsoid(J["tail5"] + P(0, 0, -0.05) * s, L([0.04, 0.04, 0.12]) * s, tag="switch"), 0.012 * s, 60 / s, 3, 5), 0.02 * s)
        self._head(F)
        F.cut_below(0.0)
        return F

    def _claws(self, F, co, to, s, sg):
        """Cloven hoof: two claws from the coronet to the toe, a cleft between, flat on the ground."""
        for k in (1, -1):
            o = P(k * 0.024, 0, 0) * s
            F.add(RoundCone(co + o + P(0, -0.005, 0.0) * s, to + o * 0.75 + P(0, -0.02, 0.012) * s, 0.034 * s, 0.014 * s, "hoof"), 0.008 * s)
            F.add(Ellipsoid(co + o + P(0, 0.025, -0.035) * s, L([0.026, 0.05, 0.03]) * s, tag="hoof"), 0.01 * s)
        F.sub(RBox((co + to) / 2 + P(0, 0.02, -0.02) * s, L([0.0035, 0.07, 0.05]) * s, rad=0.002 * s, tag="hoof"), 0.003 * s)

    def _head(self, F):
        b = self.beef; c = self.calf
        s = self.s * (1.1 + 0.12 * c); H = self.head      # the head's own scale: cattle heads are long (0.55 m)
        R = H.R
        # head frame shapes: x lateral, u along the face toward the muzzle, v toward the forehead (front of the face)
        E = lambda x, u, v, r, extra=None, tag="head": Ellipsoid(H.p(x * s, u * s, v * s), L(r) * s, H.rot(extra), tag)
        RCh = lambda a, b_, ra, rb, tag="head": RoundCone(H.p(*(L(a) * s)), H.p(*(L(b_) * s)), ra * s, rb * s, tag)
        F.add(E(0, 0.09, -0.08, (0.105 + 0.01 * b, 0.11, 0.09)), 0.06 * s)                 # cranium, forehead
        F.add(RCh((-0.085, 0.015, -0.05), (0.085, 0.015, -0.05), 0.045, 0.045), 0.05 * s)  # poll ridge
        F.add(RCh((0, 0.13, -0.065 + 0.01 * self.dished), (0, 0.42, -0.06), 0.082, 0.066), 0.06 * s)   # face (nasal bones)
        F.add(E(0, 0.45, -0.085, (0.075, 0.07, 0.068), tag="muzzle"), 0.06 * s)              # muzzle
        F.add(E(0, 0.49, -0.075, (0.07, 0.035, 0.055), tag="nose"), 0.02 * s)                # nose pad
        for sd in (1, -1):
            F.add(RCh((sd * 0.066, 0.11, -0.19), (sd * 0.03, 0.44, -0.15), 0.045, 0.03), 0.05 * s)   # jaw
            F.add(E(sd * 0.07, 0.18, -0.15, (0.042, 0.095, 0.07)), 0.05 * s)                      # cheek
            F.add(E(sd * 0.093, 0.165, -0.06, (0.042, 0.05, 0.045)), 0.03 * s)                       # orbit
        F.add(E(0, 0.45, -0.14, (0.05, 0.06, 0.03), tag="muzzle"), 0.03 * s)                      # chin
        # eyes: socket and the eyeball (separate mesh), set into the orbit
        self.place_eyes(F, protrude=0.42)
        # nostrils and the mouth line
        for sd in (1, -1):
            F.sub(Ellipsoid(H.p(sd * 0.036 * s, 0.51 * s, -0.055 * s), L([0.012, 0.012, 0.022]) * s, H.rot(rot_y(math.radians(sd * 30))), "nose"), 0.006 * s)
        # ears: out to the side, leaf-shaped and cupped
        for i, sd in enumerate((1, -1)):
            base = self.ears[i][0]
            d = norm(self.ears[i][1] - base)
            Re = frame(d, H.R @ L([0, 0.3, 1.0]))          # local y along the ear, z the ear's open face
            F.add(Ellipsoid(base + d * 0.11 * s, L([0.058, 0.115, 0.016]) * s, Re, "ear"), 0.025 * s)
            F.sub(Ellipsoid(base + d * 0.12 * s + Re[:, 2] * 0.016 * s, L([0.045, 0.095, 0.012]) * s, Re, "ear"), 0.006 * s)
            if self.horns > 0:
                hb = H.p(sd * 0.085 * s, 0.0, -0.035 * s)
                h1 = hb + norm(H.R @ L([sd * 1.0, -0.1, 0.25])) * 0.09 * s * self.horns
                h2 = h1 + norm(H.R @ L([sd * 0.3, 0.4, 0.9])) * 0.08 * s * self.horns
                F.add(RoundCone(hb, h1, 0.032 * s, 0.024 * s, "horn"), 0.015 * s)
                F.add(RoundCone(h1, h2, 0.024 * s, 0.008 * s, "horn"), 0.006 * s)

    # ---------------------------------------------------------------- coat
    def head_local(self, Pt):
        H = self.head
        return (Pt - H.o) @ H.R / self.hs

    def paint(self, Pt, nrm, tags):
        """Per-vertex colour (sRGB) and roughness on the sculpt. Patterns live on the animal's own rest-pose body."""
        s = self.s; n = len(Pt)
        lat, fwd, up = Pt[:, 0] / s, -Pt[:, 1] / s, Pt[:, 2] / s
        q = self.head_local(Pt)
        T = lambda k: tags.get(k, np.full(n, 1e9))
        head = np.maximum(near(T("head"), 0.01), np.maximum(near(T("muzzle"), 0.01), near(T("ear"), 0.006)))
        warp = np.stack([fbm(Pt * 2.0, 1.0, 2, 11), fbm(Pt * 2.0, 1.0, 2, 12), fbm(Pt * 2.0, 1.0, 2, 13)], axis=1) * 0.12
        jit = fbm(Pt, 40.0, 2, 21) * 0.02 + fbm(Pt, 160.0, 1, 22) * 0.012       # hair-scale wobble on every edge
        tone = fbm(Pt, 3.0, 3, 31)                                            # broad tonal variation of the coat
        coat = self.coat
        if coat == "holstein":
            white = np.array([0.80, 0.79, 0.75]); black = np.array([0.035, 0.032, 0.03])
            pat = fbm((Pt + warp) / s, 1.7, 4, self.seed) + jit
            m = sstep(-0.01, 0.01, pat - 0.02)                                # 1 = black
            legs = sstep(0.50, 0.40, up)                                     # white below the knees and hocks
            belly = sstep(0.74, 0.66, up) * (np.abs(fwd) < 0.75)
            m = m * (1 - np.maximum(legs, belly))
            # head mostly black with a white blaze down the face
            blaze = (np.abs(q[:, 0]) < 0.025 + 0.035 * np.clip(q[:, 1], 0, 1) + jit) & (q[:, 2] > -0.04) & (q[:, 1] > 0.02) & (q[:, 1] < 0.42)
            m = np.where(head > 0.5, np.where(blaze, 0.0, sstep(-0.2, 0.0, pat + 0.25)), m)
            col = white[None] * (1 - m[:, None]) + black[None] * m[:, None]
            col *= (1 + 0.06 * tone)[:, None]
            switch = np.array([0.82, 0.8, 0.76])
        elif coat == "hereford":
            red = np.array([0.43, 0.17, 0.075]); white = np.array([0.82, 0.79, 0.72])
            col = red[None] * (1 + 0.10 * tone + 0.05 * fbm(Pt, 9.0, 2, 33))[:, None]
            w = np.zeros(n)
            w = np.maximum(w, head * (1 - sstep(0.08, 0.02, np.abs(np.abs(q[:, 0]) - 0.105) + np.abs(q[:, 1] - 0.17) * 0.6 + 0.0 * jit) * 0.9))
            w = np.maximum(w, sstep(0.84, 0.92, fwd + 0.5 * (1.25 - up)) * sstep(1.35, 1.05, up) * (fwd > 0.6))   # brisket and throat
            w = np.maximum(w, sstep(0.06, 0.03, np.abs(lat) + jit) * sstep(0.62, 0.75, fwd) * (up > 1.15))          # crest
            w = np.maximum(w, sstep(0.72, 0.64, up + jit * 2) * (np.abs(fwd) < 0.7))                                 # underline
            w = np.maximum(w, sstep(0.38, 0.30, up + jit * 2))                                                        # socks
            w = np.clip(w + jit * 3, 0, 1)
            w = sstep(0.45, 0.55, w)
            col = col * (1 - w[:, None]) + white[None] * w[:, None]
            switch = white
        else:  # jersey
            fawn = np.array([0.60, 0.42, 0.25]); dark = np.array([0.30, 0.20, 0.13])
            shade = np.clip(0.55 * head + 0.5 * sstep(0.9, 1.2, fwd) * sstep(0.9, 1.3, up) + 0.45 * sstep(-0.55, -0.85, fwd) * sstep(0.7, 1.2, up)
                            + 0.35 * sstep(0.45, 0.25, up), 0, 1)
            shade = np.clip(shade + 0.15 * tone, 0, 1)
            col = fawn[None] * (1 - shade[:, None]) + dark[None] * shade[:, None]
            col = np.where((sstep(0.75, 0.68, up) * (np.abs(fwd) < 0.6))[:, None] > 0.5, col * 1.12, col)
            # pale ring round the muzzle and round the eyes
            nose_c = self.head.p(0, 0.49 * self.hs, -0.075 * self.hs)
            dn = np.linalg.norm(Pt - nose_c, axis=1) / self.hs
            ring = (dn > 0.06) & (dn < 0.085) & (head > 0.5) & (q[:, 1] > 0.38)           # the pale ring round a Jersey's dark nose
            col[ring] = np.array([0.72, 0.62, 0.48])
            for ec, er in self.eyes:
                d = np.linalg.norm(Pt - ec, axis=1)
                col[(d < er * 1.9) & (d > er * 1.05)] *= 1.35
            switch = np.array([0.05, 0.04, 0.035])
        rough = np.full(n, 0.78) + 0.06 * tone
        # nose pad: wet and dark or pink and mottled
        nose = near(T("nose"), 0.004) * (q[:, 1] > 0.44)
        if coat == "jersey":
            ncol = np.array([0.06, 0.05, 0.05])
        else:
            ncol = np.array([0.55, 0.36, 0.34]) * (1 - 0.6 * (fbm(Pt, 60.0, 2, 41) > 0.25)[:, None])
            if coat == "holstein":
                ncol = np.where((fbm(Pt, 25.0, 2, 42) > 0.1)[:, None], np.array([0.06, 0.05, 0.05])[None], ncol)
        col = col * (1 - nose[:, None]) + ncol * nose[:, None]
        rough = rough * (1 - nose) + 0.22 * nose
        # hooves, dew claws, horns, udder, teats, switch
        hoof = near(T("hoof"), 0.003)
        hcol = np.array([0.07, 0.065, 0.06]) if coat != "jersey" else np.array([0.04, 0.035, 0.03])
        col = col * (1 - hoof[:, None]) + hcol * hoof[:, None] * (1 + 0.25 * fbm(Pt, 50, 2, 51))[:, None]
        rough = rough * (1 - hoof) + 0.5 * hoof
        horn = near(T("horn"), 0.002)
        if horn.any():
            hb = np.linalg.norm(Pt - self.head.o, axis=1)
            tip = sstep(0.12 * s, 0.2 * s, hb)
            hc = np.array([0.78, 0.72, 0.58])[None] * (1 - tip[:, None]) + np.array([0.12, 0.1, 0.08])[None] * tip[:, None]
            col = col * (1 - horn[:, None]) + hc * horn[:, None]
            rough = rough * (1 - horn) + 0.4 * horn
        ud = np.maximum(near(T("udder"), 0.004), near(T("teat"), 0.003))
        ucol = np.array([0.80, 0.60, 0.55]) if coat != "jersey" else np.array([0.62, 0.48, 0.40])
        col = col * (1 - 0.8 * ud[:, None]) + ucol * 0.8 * ud[:, None]
        rough = rough * (1 - ud) + 0.55 * ud
        sw = near(T("switch"), 0.01)
        col = col * (1 - sw[:, None]) + switch * sw[:, None]
        # inside of the ears: paler, pinker skin with sparse hair
        ear = near(T("ear"), 0.003)
        col = col * (1 - 0.0 * ear[:, None])
        # occlusion-like darkening in deep creases is left to the baked AO
        return np.clip(col, 0, 1), np.clip(rough, 0.05, 1.0)

    def fur_amount(self, Pt, tags):
        s = self.s; n = len(Pt)
        T = lambda k: tags.get(k, np.full(n, 1e9))
        up = Pt[:, 2] / s
        f = 1.0 - 0.4 * sstep(0.5, 0.3, up) - 0.25 * near(T("head"), 0.01) - 0.3 * near(T("ear"), 0.005)
        f = np.minimum(f, 1.0 - 0.93 * np.maximum.reduce([near(T("nose"), 0.004), near(T("udder"), 0.004), near(T("teat"), 0.003)]))
        f = np.minimum(f, 1.0 - np.maximum(near(T("hoof"), 0.003), near(T("horn"), 0.002)))
        return f

    def detail_kind(self, Pt, tags):
        n = len(Pt)
        T = lambda k: tags.get(k, np.full(n, 1e9))
        bare = np.maximum.reduce([near(T("nose"), 0.004), near(T("hoof"), 0.003), near(T("horn"), 0.002), near(T("udder"), 0.004), near(T("teat"), 0.003)])
        return np.where(bare > 0.5, 2.0, 0.0)

    def extra_fix(self, body, arm, co, W, vg):
        """The udder and teats hang from the hips, not from the thighs (otherwise they would swing with the legs)."""
        s = self.s
        fwd = -co[:, 1] / s; up = co[:, 2] / s; lat = co[:, 0] / s
        ud = ((lat / 0.19) ** 2 + ((fwd + 0.46) / 0.24) ** 2 + ((up - 0.6) / 0.19) ** 2) < 1.0       # the udder and teats only
        if self.calf < 0.5:
            for i in np.nonzero(ud)[0]:
                self.set_group(vg, int(i), "hips")

    # ---------------------------------------------------------------- clips
    gait_k = 1.0                    # stride and period scale relative to the leg length (a sheep steps quicker)
    def clips(self, arm, update):
        import anim
        s = self.J["shoulder_L"][2] / 1.02 * self.gait_k
        gk = anim.solve_graze(arm.pose.bones, arm, self, update)
        walk = dict(period=1.2 * s ** 0.5, duty=0.64, phases={"H_L": 0.0, "F_L": 0.25, "H_R": 0.5, "F_R": 0.75},
                    stride=0.62 * s, lift_f=0.11 * s, lift_h=0.09 * s, bob=0.015 * s, pitch=0.012, roll=0.02, nod=0.05,
                    nod_ph=1.2, scap=0.25, tail=0.08, yaw=0.02)
        trot = dict(period=0.74 * s ** 0.5, duty=0.48, phases={"H_L": 0.0, "F_R": 0.02, "H_R": 0.5, "F_L": 0.52},
                    stride=0.82 * s, lift_f=0.17 * s, lift_h=0.14 * s, bob=0.025 * s, pitch=0.01, roll=0.015, nod=0.03,
                    scap=0.3, tail=0.12, yaw=0.01, head_up=0.05, ears=-0.15)
        run = dict(period=0.62 * s ** 0.5, duty=0.38, phases={"H_L": 0.0, "H_R": 0.12, "F_L": 0.42, "F_R": 0.52},
                   stride=0.95 * s, lift_f=0.22 * s, lift_h=0.16 * s, bob=0.05 * s, bob_n=1, pitch=0.06, pitch_ph=0.6, roll=0.01,
                   nod=0.10, nod_ph=0.4, scap=0.35, tail=0.15, tail_up=0.4, head_up=0.1, ears=-0.3)
        P = lambda g: (lambda t, pb: anim.gait(t, pb, arm, g))
        return [
            dict(name="idle", dur=6.0, fn=lambda t, pb: anim.idle(t, pb, arm, 6.0)),
            dict(name="walk", dur=walk["period"], fn=P(walk)),
            dict(name="trot", dur=trot["period"], fn=P(trot)),
            dict(name="run", dur=run["period"], fn=P(run)),
            dict(name="graze", dur=6.0, fn=lambda t, pb: anim.graze(t, pb, arm, 6.0, gk)),
        ]

    # speeds the clips are made for (metres per second over the ground), for the game to match
    def clip_speeds(self):
        out = {}
        k = self.J["shoulder_L"][2] / 1.02 * self.gait_k
        for c, (stride, period, duty) in {"walk": (0.62, 1.2, 0.64), "trot": (0.82, 0.74, 0.48), "run": (0.95, 0.62, 0.38)}.items():
            out[c] = round(stride * k / duty / (period * k ** 0.5), 2)
        return out

# ======================================================================= registry
def get(name):
    if name == "cow_a": return Cattle("cow_a", coat="holstein", seed=3)
    if name == "cow_b": return Cattle("cow_b", s=0.95, beef=1.0, horns=1.0, coat="hereford")
    if name == "cow_c": return Cattle("cow_c", s=0.84, dished=1.0, coat="jersey")
    if name == "calf_a": return Cattle("calf_a", s=0.58, calf=1.0, coat="holstein", seed=8)
    import sp_more
    return sp_more.get(name)


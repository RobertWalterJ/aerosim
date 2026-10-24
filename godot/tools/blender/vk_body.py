# AeroSim vehicle kit: the lofted body shell.
# A body is a grid of stations along the length (d = distance back from the front bumper) and a half ring of named roles
# from the underbody centre round the side to the roof centre, mirrored. Panel lines (door shuts, bonnet, tailgate,
# bumpers) are edges of that grid, so they become real gaps with return flanges, and the doors, bonnet and tailgate come
# apart as their own islands for the rig. Wheel arches are cut with an exact boolean whose cylinder becomes the wheel well.
import bpy, bmesh, math
from mathutils import Vector as V, Matrix
from vk_core import Fillet, smoothstep, lerp, material, Part

# roles of the half ring (bottom centre to roof centre)
R_BOT, R_FLOOR, R_ROCK, R_SILL, R_LOW, R_MID, R_SH, R_BELT, R_GL0, R_GL1, R_CANT, R_ROOF1, R_ROOF2, R_TOP = range(14)
NROLE = 14


class BodySpec:
    """Numbers for one body. d is metres back from the front of the front bumper; z is height above the ground."""

    def __init__(self, **k):
        self.L = 4.0; self.W = 1.72; self.H = 1.46
        self.top = [(0, 0.7, 0), (0.1, 0.74, 0.1), (1.2, 0.9, 0.12), (2.0, 1.44, 0.25), (3.3, 1.44, 0.3), (3.9, 0.98, 0.1), (4.0, 0.95, 0)]
        self.bot = [(0, 0.32, 0), (0.25, 0.2, 0.15), (0.8, 0.16, 0.2), (3.3, 0.16, 0.2), (3.85, 0.24, 0.15), (4.0, 0.36, 0)]
        self.sill = [(0, 0.40, 0), (0.6, 0.30, 0.2), (3.4, 0.30, 0.2), (4.0, 0.44, 0)]
        self.belt = [(0, 0.85, 0), (4.0, 0.93, 0)]
        self.sh_drop = 0.07
        self.th = 0.20              # tumblehome: roof half width = body half width - th
        self.belt_in = 0.035        # belt step in from the shoulder
        self.front_face = [(0.0, 0.05), (0.25, 0.03), (0.45, 0.0), (0.58, 0.0), (0.66, 0.04), (0.80, 0.08)]   # (z, d) nose face
        self.rear_face = [(0.0, 0.06), (0.30, 0.02), (0.5, 0.0), (0.62, 0.0), (0.75, 0.03), (1.2, 0.08)]
        self.plan_rf = 0.32; self.plan_rr = 0.24     # plan corner radii
        self.cap_bulge_f = 0.05; self.cap_bulge_r = 0.03
        self.side_bulge = 0.012     # door side convex
        self.fz = 0.55; self.rz = 0.45   # lengths of the front and rear end zones (where stations bend to the face)
        self.erode = 0.10           # plan rounding of the greenhouse (how far the edges lag the centre on the slopes)
        self.crown = 0.03           # bonnet and roof crown
        self.creases = {R_SH: True, R_BELT: True, R_GL0: True, R_GL1: True, R_CANT: True, R_SILL: False, R_LOW: False}
        self.windscreen = (1.30, 2.02)      # d range of the glass (bottom, top)
        self.backlight = None               # (d0, d1) for the rear window on the top surface
        self.windows = [(1.45, 2.55), (2.6, 3.3)]   # side glass d ranges (between are black pillars)
        self.pillar_mat = "trim"            # B pillar / window frame finish
        self.frame_mat = "trim"
        self.seal_mat = "trim"
        self.panels = []                    # closed loops that come apart: dicts {name, bone, kind, d0, d1, r0, r1}
        self.grooves = []                   # open panel lines
        self.arches = []                    # (d_axle, radius)
        self.arch_x = 0.34                  # how deep the wheel well goes in from the side
        self.extra_stations = []
        self.paint2 = None                  # fn(face info) -> True for the second colour
        self.flat_sides = False
        for a, b in k.items():
            setattr(self, a, b)
        self.f_top = Fillet(self.top)
        self.f_bot = Fillet(self.bot)
        self.f_sill = Fillet(self.sill)
        self.f_belt = Fillet(self.belt)
        self.f_ff = Fillet([(z, d, 0.0) for (z, d) in self.front_face])
        self.f_rf = Fillet([(z, d, 0.0) for (z, d) in self.rear_face])


# ------------------------------------------------------------------ the section
def half_width(s, d, d_start, d_end):
    Wh = s.W * 0.5
    w = Wh
    e = d - d_start
    if e < s.plan_rf:
        w = min(w, Wh - s.plan_rf + math.sqrt(max(0.0, s.plan_rf ** 2 - (s.plan_rf - max(e, 0.0)) ** 2)))
    e = d_end - d
    if e < s.plan_rr:
        w = min(w, Wh - s.plan_rr + math.sqrt(max(0.0, s.plan_rr ** 2 - (s.plan_rr - max(e, 0.0)) ** 2)))
    return w


def top_at(s, d, delta):
    if delta <= 0:
        return s.f_top(d)
    return min(s.f_top(max(d - delta, 0.0)), s.f_top(min(d + delta, s.L)))


def section(s, d, d_start=0.0, d_end=None):
    """The 14 control points (x, z) of the right half at distance d."""
    if d_end is None:
        d_end = s.L
    w = half_width(s, d, d_start, d_end)
    ztc = s.f_top(d)
    zbot = s.f_bot(d)
    # edges of the top surface lag the centre on slopes (plan curvature of the screen and the bonnet)
    zte = top_at(s, d, s.erode)
    zb = min(s.f_belt(d), zte - s.crown)
    zb = max(zb, zbot + 0.2)
    zsh = zb - s.sh_drop
    zs = max(s.f_sill(d), zbot + 0.06)
    zs = min(zs, zsh - 0.08)
    hg = ztc - zb
    g = smoothstep(0.08, 0.32, hg)
    wr = max(w - s.th, 0.25)
    sb = s.side_bulge
    P = [None] * NROLE
    P[R_BOT] = (0.0, zbot)
    P[R_FLOOR] = (max(w - 0.16, 0.05), zbot)
    P[R_ROCK] = (w - 0.06, zbot + 0.04)
    P[R_SILL] = (w - 0.03, zs)
    P[R_LOW] = (w - 0.006 + sb * 0.6, lerp(zs, zsh, 0.38))
    P[R_MID] = (w + sb * 0.5, lerp(zs, zsh, 0.78))
    P[R_SH] = (w, zsh)
    P[R_BELT] = (w - s.belt_in, zb)
    # bonnet / deck layout
    hb = max(ztc - zb, 0.004)
    B = [(w - s.belt_in - 0.03, zb + 0.004), (w - s.belt_in - 0.075, zb + 0.10 * hb), (w - s.belt_in - 0.14, zb + 0.28 * hb),
         (w * 0.62, zb + 0.72 * hb), (w * 0.3, zb + 0.94 * hb), (0.0, ztc)]
    # greenhouse layout
    zr_e = top_at(s, d, s.erode)            # roof edge height (lagging)
    zr_m = top_at(s, d, s.erode * 0.55)
    G = [(w - s.belt_in - 0.012, zb + 0.018), (wr + 0.02, zr_e - 0.075), (wr, zr_e - 0.035),
         (wr * 0.72, zr_m - 0.008), (wr * 0.38, top_at(s, d, s.erode * 0.2) - 0.002), (0.0, ztc)]
    for k in range(6):
        bx, bz = B[k]; gx, gz = G[k]
        P[R_GL0 + k] = (lerp(bx, gx, g), lerp(bz, gz, g))
    # keep the top roles from crossing
    for k in range(R_GL0, R_TOP):
        x, z = P[k]
        P[k] = (x, min(z, ztc))
    return P


# ------------------------------------------------------------------ refinement round the ring
def catmull(p0, p1, p2, p3, t):
    t2 = t * t; t3 = t2 * t
    return tuple(0.5 * ((2 * p1[i]) + (-p0[i] + p2[i]) * t + (2 * p0[i] - 5 * p1[i] + 4 * p2[i] - p3[i]) * t2 +
                        (-p0[i] + 3 * p1[i] - 3 * p2[i] + p3[i]) * t3) for i in range(2))


def refine_ring(P, subs, creases):
    """Half ring control points -> refined points with their role (float)."""
    out = []
    n = len(P)
    for r in range(n - 1):
        p1, p2 = P[r], P[r + 1]
        if r == 0 or creases.get(r, False):
            p0 = (2 * p1[0] - p2[0], 2 * p1[1] - p2[1])
        else:
            p0 = P[r - 1]
        if r + 1 == n - 1 or creases.get(r + 1, False):
            p3 = (2 * p2[0] - p1[0], 2 * p2[1] - p1[1])
        else:
            p3 = P[r + 2]
        m = subs[r]
        for k in range(m):
            t = k / m
            q = catmull(p0, p1, p2, p3, t) if k else p1
            out.append((q, r + t))
    out.append((P[-1], float(n - 1)))
    # the centre points stay on x = 0, nothing crosses it
    out = [((max(q[0], 0.0) if i not in (0, len(out) - 1) else 0.0, q[1]), role) for i, (q, role) in enumerate(out)]
    return out


# ------------------------------------------------------------------ build
class Body:
    def __init__(self, s, lod=0):
        self.s = s
        self.lod = lod
        self.subs = self._subs(lod)
        self.stations = self._stations(lod)
        self.H = sum(self.subs) + 1               # refined half ring count
        self.role_h = []                          # refined index of each control role
        acc = 0
        for r in range(NROLE):
            self.role_h.append(acc)
            if r < NROLE - 1:
                acc += self.subs[r]
        self.M = 2 * (self.H - 1)

    def _subs(self, lod):
        base = [3, 2, 2, 2, 2, 2, 2, 1, 1, 3, 1, 2, 2]
        if lod == 1:
            base = [2, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1, 1]
        if lod >= 2:
            base = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        return base

    def _stations(self, lod):
        s = self.s
        step = [0.055, 0.12, 0.30][min(lod, 2)]
        must = set([0.0, s.L])
        for (a, b) in [s.windscreen] + ([s.backlight] if s.backlight else []) + list(s.windows):
            must.add(round(a, 4)); must.add(round(b, 4))
        for p in s.panels + s.grooves:
            for key in ("d0", "d1", "d1_low"):
                if key in p:
                    must.add(round(p[key], 4))
        for d in s.extra_stations:
            must.add(round(d, 4))
        if lod == 0:
            # pillar widths for the frit / pillar bands
            pass
        must = sorted(x for x in must if 0.0 <= x <= s.L)
        out = []
        for i in range(len(must) - 1):
            a, b = must[i], must[i + 1]
            n = max(1, int(math.ceil((b - a) / step - 1e-6)))
            if lod >= 2 and (b - a) < step * 0.5 and i > 0:
                n = 1
            for k in range(n):
                out.append(a + (b - a) * k / n)
        out.append(s.L)
        # merge stations closer than 5 mm
        res = [out[0]]
        for x in out[1:]:
            if x - res[-1] > 0.005:
                res.append(x)
        return res

    # the d of role r at station d (bent toward the face in the end zones)
    def _role_d(self, d, z):
        s = self.s
        ds = s.f_ff(z)
        de = s.L - s.f_rf(z)
        if d < s.fz:
            return ds + d / s.fz * (s.fz - ds), ds, de
        if d > s.L - s.rz:
            t = (d - (s.L - s.rz)) / s.rz
            return (s.L - s.rz) + t * (de - (s.L - s.rz)), ds, de
        return d, ds, de

    def ring(self, d):
        """Refined right half ring at station d: list of ((x, y, z), role)."""
        s = self.s
        P0 = section(s, d)
        P = []
        for r in range(NROLE):
            z = P0[r][1]
            dr, ds, de = self._role_d(d, z)
            for _ in range(2):
                q = section(s, dr, ds, de)[r]
                dr, ds, de = self._role_d(d, q[1])
            q = section(s, dr, ds, de)[r]
            P.append((q[0], q[1], dr))
        # refine round the ring in (x, z), carry d along linearly
        xs = [(p[0], p[1]) for p in P]
        ref = refine_ring(xs, self.subs, s.creases)
        out = []
        for (q, role) in ref:
            r0 = min(int(role), NROLE - 2); t = role - r0
            dd = lerp(P[r0][2], P[r0 + 1][2], t) if role < NROLE - 1 else P[-1][2]
            out.append(((q[0], s.L * 0.5 - dd, q[1]), role))
        return out

    def build(self):
        s = self.s
        bm = bmesh.new()
        self.bm = bm
        st = self.stations
        H, M = self.H, self.M
        grid = []
        self.roles = None
        for d in st:
            hr = self.ring(d)
            if self.roles is None:
                self.roles = [r for (_, r) in hr]
            row = [None] * M
            for h in range(H):
                (x, y, z), _ = hr[h]
                if h == 0 or h == H - 1:
                    row[h] = bm.verts.new((0.0, y, z))
                else:
                    row[h] = bm.verts.new((x, y, z))
                    row[M - h] = bm.verts.new((-x, y, z))
            grid.append(row)
        self.grid = grid
        # faces between stations
        self.face_info = {}
        for i in range(len(st) - 1):
            for j in range(M):
                a, b = grid[i][j], grid[i][(j + 1) % M]
                c, dv = grid[i + 1][(j + 1) % M], grid[i + 1][j]
                try:
                    f = bm.faces.new([a, b, c, dv])
                except ValueError:
                    continue
                f.smooth = True
                h = j if j < H - 1 else M - j - 1     # the half index of the face's lower edge on its side
                side = 1 if j < H - 1 else -1
                self.face_info[f] = (i, h, side)
        self.caps = []
        self._cap(0, front=True)
        self._cap(len(st) - 1, front=False)
        bm.normal_update()
        # outward normals: the right side faces must point +x
        self._assign_materials()
        return bm

    def _cap(self, i, front):
        s = self.s
        bm = self.bm
        H, M = self.H, self.M
        row = self.grid[i]
        bulge = s.cap_bulge_f if front else s.cap_bulge_r
        sgn = 1.0 if front else -1.0
        cols = 3 if self.lod < 2 else 1
        # cap rows: interior vertices between right point and left point through the centre
        caprows = []
        for h in range(H):
            R = row[h]
            if h == 0 or h == H - 1:
                caprows.append([R] * (2 * cols + 1))
                continue
            Lv = row[M - h]
            r = [R]
            x0 = R.co.x
            for c in range(1, 2 * cols):
                f = 1.0 - c / cols          # 1 at right, 0 centre, -1 left
                x = x0 * f
                y = R.co.y + sgn * bulge * (1.0 - f * f)
                r.append(bm.verts.new((x, y, R.co.z)))
            r.append(Lv)
            caprows.append(r)
        if not hasattr(self, 'capcols'):
            self.capcols = {}
        self.capcols[front] = [caprows[h][cols] for h in range(H)]
        for h in range(H - 1):
            for c in range(2 * cols):
                q = [caprows[h][c], caprows[h][c + 1], caprows[h + 1][c + 1], caprows[h + 1][c]]
                uq = []
                for v in q:
                    if v not in uq:
                        uq.append(v)
                if len(uq) < 3:
                    continue
                if not front:
                    pass
                try:
                    f = bm.faces.new(uq if front else list(reversed(uq)))
                except ValueError:
                    continue
                f.smooth = True
                self.caps.append(f)
                self.face_info[f] = (-1 if front else -2, h, 0)
        # fix the cap's winding so it faces out
        for f in self.caps:
            f.normal_update()
        want = V((0, 1, 0)) if front else V((0, -1, 0))
        caps_here = [f for f in self.caps if self.face_info[f][0] == (-1 if front else -2)]
        tot = V((0, 0, 0))
        for f in caps_here:
            tot += f.normal * f.calc_area()
        if tot.dot(want) < 0:
            bmesh.ops.reverse_faces(bm, faces=caps_here)

    # ------------------------------------------------------------------ material regions
    def in_range(self, i, rng):
        d0 = self.stations[i]; d1 = self.stations[i + 1]
        dm = (d0 + d1) * 0.5
        return rng[0] - 1e-4 <= d0 and d1 <= rng[1] + 1e-4

    def _assign_materials(self):
        s = self.s
        rh = self.role_h
        part_mats = self.mats = ["paint", "glass", "trim", "paint2", "chrome", "trim_grey"]
        for m in [rg["mat"] for rg in getattr(s, "regions", [])] + [cg.get("mat", "glass") for cg in getattr(s, "cap_glass", [])] + \
                [s.pillar_mat, s.frame_mat, s.seal_mat, getattr(s, "apillar_mat", s.frame_mat)]:
            if m not in part_mats:
                part_mats.append(m)
        idx = {m: k for k, m in enumerate(part_mats)}
        for f, (i, h, side) in self.face_info.items():
            mat = "paint"
            if i >= 0:
                dm = (self.stations[i] + self.stations[i + 1]) * 0.5
                if h < rh[R_FLOOR]:
                    mat = "trim_grey"
                elif rh[R_CANT] <= h:
                    if self.in_range(i, s.windscreen):
                        mat = "glass"
                    elif s.backlight and self.in_range(i, s.backlight):
                        # the rear window: glass in the middle, a black frit band at its edges (the corners fold round)
                        mat = "glass" if h >= rh[R_ROOF1] else "trim"
                elif rh[R_GL0] <= h < rh[R_GL1]:
                    win = any(self.in_range(i, w) for w in s.windows)
                    if win:
                        mat = "glass"
                    elif self.in_range(i, (s.windows[0][0], s.windows[-1][1])) if s.windows else False:
                        mat = s.pillar_mat
                elif rh[R_GL1] <= h < rh[R_CANT]:
                    if self.in_range(i, s.windscreen):
                        mat = s.apillar_mat if hasattr(s, "apillar_mat") else s.frame_mat
                    elif s.windows and self.in_range(i, (s.windows[0][0], s.windows[-1][1])):
                        mat = s.frame_mat
                elif rh[R_BELT] <= h < rh[R_GL0]:
                    if s.windows and self.in_range(i, (s.windows[0][0], s.windows[-1][1])):
                        mat = s.seal_mat
                # extra regions: {d0, d1, r0, r1, side (0 both), mat}
                for rg in getattr(s, "regions", []):
                    if rh[rg["r0"]] <= h < rh[rg["r1"]] and self.in_range(i, (rg["d0"], rg["d1"])) and rg.get("side", 0) in (0, side):
                        mat = rg["mat"]
                if mat == "paint" and s.paint2 is not None and s.paint2(self, f, i, h, side, dm):
                    mat = "paint2"
            else:
                # end caps: glass in the cap (bus and van screens, rear door windows): {front, r0, r1, x0, x1, mat}
                c = f.calc_center_median()
                for cg in getattr(s, "cap_glass", []):
                    if cg.get("front", True) != (i == -1):
                        continue
                    if rh[cg["r0"]] <= h < rh[cg["r1"]] and cg.get("x0", 0.0) - 1e-4 <= abs(c.x) <= cg["x1"] + 1e-4:
                        mat = cg.get("mat", "glass")
                if mat == "paint" and s.paint2 is not None and s.paint2(self, f, i, h, 0, -1.0 if i == -1 else s.L + 1.0):
                    mat = "paint2"
            f.material_index = idx[mat]

    # ------------------------------------------------------------------ panel lines
    def edges_station(self, d, r0, r1, side):
        """Grid edges along the station ring at d between roles r0..r1 on a side (+1, -1); side 0 = across the top (r0
        on the right over the centre to r0 on the left)."""
        i = min(range(len(self.stations)), key=lambda k: abs(self.stations[k] - d))
        row = self.grid[i]
        H, M = self.H, self.M
        h0, h1 = self.role_h[r0], self.role_h[r1]
        js = []
        if side == 0:
            js = list(range(h0, H)) + list(range(H, M - h0 + 1))
        elif side > 0:
            js = list(range(h0, h1 + 1))
        else:
            js = [M - h if h > 0 else 0 for h in range(h0, h1 + 1)]
        es = []
        for a, b in zip(js[:-1], js[1:]):
            e = self.bm.edges.get([row[a % M], row[b % M]])
            if e:
                es.append(e)
        return es

    def edges_role(self, r, d0, d1, side):
        """Grid edges along role r from station d0 to d1 on a side."""
        H, M = self.H, self.M
        h = self.role_h[r]
        j = h if side > 0 else (M - h if h > 0 else 0)
        es = []
        for i in range(len(self.stations) - 1):
            if self.stations[i] >= d0 - 1e-4 and self.stations[i + 1] <= d1 + 1e-4:
                e = self.bm.edges.get([self.grid[i][j % M], self.grid[i + 1][j % M]])
                if e:
                    es.append(e)
        return es

    def edges_caprow(self, h_role, front):
        """The cap row at a role height (front or rear cap), right ring point to left ring point."""
        i = 0 if front else len(self.stations) - 1
        H, M = self.H, self.M
        h = self.role_h[h_role]
        R = self.grid[i][h]; Lv = self.grid[i][M - h]
        # walk the cap faces: collect cap edges whose both verts are at this z and on this cap
        z = R.co.z
        es = []
        for f in self.caps:
            if self.face_info[f][0] != (-1 if front else -2):
                continue
            for e in f.edges:
                a, b = e.verts
                if abs(a.co.z - z) < 1e-6 and abs(b.co.z - z) < 1e-6 and e not in es:
                    es.append(e)
        return es

    def panel_edges(self):
        """Every panel line as a list of edge keys (coordinate pairs), so they survive the boolean."""
        s = self.s
        out = []
        loops = []
        for p in s.panels + s.grooves:
            es = []
            k = p["kind"]
            sides = [p["side"]] if "side" in p else [1, -1]
            for sd in sides:
                if k == "door":            # d0..d1, roles r0 (bottom) to r1 (top); optional step round the rear arch
                    es += self.edges_station(p["d0"], p["r0"], p["r1"], sd)
                    es += self.edges_role(p["r1"], p["d0"], p["d1"], sd)
                    if "d1_low" in p:
                        rs = p["r_step"]
                        es += self.edges_station(p["d1_low"], p["r0"], rs, sd)
                        es += self.edges_role(rs, p["d1_low"], p["d1"], sd)
                        es += self.edges_station(p["d1"], rs, p["r1"], sd)
                        es += self.edges_role(p["r0"], p["d0"], p["d1_low"], sd)
                    else:
                        es += self.edges_station(p["d1"], p["r0"], p["r1"], sd)
                        es += self.edges_role(p["r0"], p["d0"], p["d1"], sd)
                elif k == "line_role":
                    es += self.edges_role(p["r"], p["d0"], p["d1"], sd)
                elif k == "line_station":
                    es += self.edges_station(p["d0"], p["r0"], p["r1"], sd)
            if k == "lid":                 # bonnet or boot lid / tailgate: role r along both sides d0..d1, across at d0/d1
                for sd in (1, -1):
                    es += self.edges_role(p["r"], p["d0"], p["d1"], sd)
                if p.get("across0", True):
                    es += self.edges_station(p["d0"], p["r"], p["r"], 0)
                if p.get("across1", True):
                    es += self.edges_station(p["d1"], p["r"], p["r"], 0)
                if p.get("cap_front"):
                    es += self.edges_caprow(p["r"], True)
                if p.get("cap_rear"):
                    es += self.edges_caprow(p["r"], False)
                if p.get("cap_rear_role") is not None:
                    es += self.edges_caprow(p["cap_rear_role"], False)
                    for sd in (1, -1):
                        es += self.edges_station(s.L, p["cap_rear_role"], p["r"], sd)
            if k == "caprow":
                es += self.edges_caprow(p["r"], p.get("front", True))
            if k == "rear_doors":          # van barn doors: rear corners rb..rt, cap rows rb and rt, the centre split
                for sd in (1, -1):
                    es += self.edges_station(s.L, p["rb"], p["rt"], sd)
                es += self.edges_caprow(p["rb"], False)
                es += self.edges_caprow(p["rt"], False)
                col = self.capcols[False]
                h0, h1 = self.role_h[p["rb"]], self.role_h[p["rt"]]
                for h in range(h0, h1):
                    e = self.bm.edges.get([col[h], col[h + 1]])
                    if e:
                        es.append(e)
            if k == "tailgate":            # a tailgate: role r along the sides from d0 to the rear, across the roof at d0,
                # down the rear corners (last station from role r down to role rb), across the rear cap at rb
                for sd in (1, -1):
                    es += self.edges_role(p["r"], p["d0"], s.L, sd)
                    es += self.edges_station(s.L, p["rb"], p["r"], sd)
                es += self.edges_station(p["d0"], p["r"], p["r"], 0)
                es += self.edges_caprow(p["rb"], False)
            keys = [edge_key(e) for e in es]
            p["_keys"] = set(keys)
            out += keys
        return set(out)


def edge_key(e):
    a, b = e.verts
    ka = (round(a.co.x, 5), round(a.co.y, 5), round(a.co.z, 5))
    kb = (round(b.co.x, 5), round(b.co.y, 5), round(b.co.z, 5))
    return (ka, kb) if ka < kb else (kb, ka)


# ------------------------------------------------------------------ boolean wheel arches
def cut_arches(ob, s, lod):
    """Cut the wheel arches with exact booleans. The cutter's surface becomes the black wheel well."""
    if not s.arches:
        return
    segs = [64, 36, 16][min(lod, 2)]
    cutters = []
    for (d_ax, Ra) in s.arches:
        y = s.L * 0.5 - d_ax
        for sx in (1, -1):
            bm = bmesh.new()
            depth = s.arch_x + 0.4
            xc = sx * (s.W * 0.5 - s.arch_x + depth * 0.5)
            bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=Ra, radius2=Ra, depth=depth)
            bmesh.ops.transform(bm, matrix=Matrix.Translation((xc, y, s.arch_z if hasattr(s, "arch_z") else Ra * 0.0 + s.wheel_R)) @
                                Matrix.Rotation(math.pi / 2, 4, 'Y'), verts=bm.verts)
            for f in bm.faces:
                f.smooth = len(f.verts) == 4
            me = bpy.data.meshes.new("arch_cut")
            bm.to_mesh(me)
            me.materials.append(material("trim"))
            co = bpy.data.objects.new("arch_cut", me)
            bpy.context.scene.collection.objects.link(co)
            co.hide_render = True
            cutters.append(co)
    # one boolean per cutter (exact)
    for co in cutters:
        mod = ob.modifiers.new("arch", 'BOOLEAN')
        mod.operation = 'DIFFERENCE'
        mod.solver = 'EXACT'
        mod.object = co
        try:
            mod.material_mode = 'TRANSFER'
        except Exception:
            pass
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev)
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    bpy.data.meshes.remove(old)
    for co in cutters:
        m = co.data
        bpy.data.objects.remove(co)
        bpy.data.meshes.remove(m)


# ------------------------------------------------------------------ gaps and islands
def make_gaps(bm, keys, gap=0.0045, depth=0.022):
    """Split the panel-line edges, pull each side back by half the gap and turn a return flange in."""
    edges = [e for e in bm.edges if edge_key(e) in keys]
    if not edges:
        return
    res = bmesh.ops.split_edges(bm, edges=edges)
    bm.normal_update()
    bnd = [e for e in bm.edges if e.is_boundary]
    keyset = set()
    for e in res.get("edges", []):
        keyset.add(e)
    # pull back
    moves = {}
    for v in set(x for e in bnd for x in e.verts):
        be = [e for e in v.link_edges if e.is_boundary]
        if len(be) != 2:
            continue
        o0 = be[0].other_vert(v).co - v.co
        o1 = be[1].other_vert(v).co - v.co
        if o0.length < 1e-7 or o1.length < 1e-7:
            continue
        if o0.normalized().dot(o1.normalized()) > 0.9:     # slit tip
            continue
        t = (o1.normalized() - o0.normalized())
        if t.length < 1e-6:
            continue
        t.normalize()
        n = v.normal
        inward = n.cross(t)
        # point into the faces of v
        c = V((0, 0, 0))
        for f in v.link_faces:
            c += f.calc_center_median()
        c /= max(1, len(v.link_faces))
        if inward.dot(c - v.co) < 0:
            inward = -inward
        moves[v] = inward * (gap * 0.5)
    for v, m in moves.items():
        v.co += m
    # return flanges
    bnd = [e for e in bm.edges if e.is_boundary and (moves.get(e.verts[0]) is not None or moves.get(e.verts[1]) is not None)]
    if not bnd:
        return
    ex = bmesh.ops.extrude_edge_only(bm, edges=bnd)
    newv = [g for g in ex["geom"] if isinstance(g, bmesh.types.BMVert)]
    bm.normal_update()
    for v in newv:
        # the vertex it came from is the neighbour along the new edge
        src = None
        for e in v.link_edges:
            o = e.other_vert(v)
            if o not in newv:
                src = o
        if src is None:
            continue
        v.co = src.co - src.normal * depth
    for f in [g for g in ex["geom"] if isinstance(g, bmesh.types.BMFace)]:
        f.smooth = False
        # copy the material of the face it grew from
        for e in f.edges:
            for lf in e.link_faces:
                if lf is not f and lf.material_index is not None:
                    f.material_index = lf.material_index
                    break
    bm.normal_update()


def islands(bm):
    """Connected face groups (through shared edges)."""
    seen = set()
    groups = []
    for f in bm.faces:
        if f in seen:
            continue
        stack = [f]
        seen.add(f)
        g = []
        while stack:
            x = stack.pop()
            g.append(x)
            for e in x.edges:
                for y in e.link_faces:
                    if y not in seen:
                        seen.add(y)
                        stack.append(y)
        groups.append(g)
    return groups

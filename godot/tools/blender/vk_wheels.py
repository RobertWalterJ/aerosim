# AeroSim vehicle kit: wheels. A tyre turned from a real section (sidewall bulge, shoulder, tread with circumferential and
# lateral grooves), an alloy, steel, truck or tractor rim with its nuts, and a brake disc with a caliper. Built for the
# right-hand side (outer face toward +X) about the axle (X) through the origin; the left side is mirrored.
import bmesh, math
from mathutils import Vector as V, Matrix
from vk_core import Part, bm_lathe, bm_cyl, bm_box, bm_rbox, mirror_x


def tyre_bm(R, Rr, tw, segs, lod, kind="road"):
    """Tyre section from the outer bead round the tread to the inner bead. Returns bmesh (material 0 = rubber)."""
    sw = R - Rr
    hw = tw * 0.5
    if lod >= 2:
        prof = [(Rr + 0.004, hw * 0.82), (Rr + 0.55 * sw, hw * 1.0), (R - 0.012, hw * 0.92), (R, hw * 0.66),
                (R, -hw * 0.66), (R - 0.012, -hw * 0.92), (Rr + 0.55 * sw, -hw * 1.0), (Rr + 0.004, -hw * 0.82)]
        groove = []
    else:
        prof = [(Rr + 0.004, hw * 0.80), (Rr + 0.28 * sw, hw * 0.97), (Rr + 0.62 * sw, hw * 1.0),
                (R - 0.024, hw * 0.90), (R - 0.006, hw * 0.76)]
        if lod == 0:
            # tread half: shoulder, one circumferential groove, the centre
            tr = [(R, 0.62), (R, 0.38), (R - 0.008, 0.36), (R - 0.008, 0.29), (R, 0.27), (R, 0.0)]
        else:
            tr = [(R, 0.62), (R, 0.0)]
        prof_t = [(r, hw * x) for (r, x) in tr]
        mirror = [(r, -a) for (r, a) in reversed(prof_t[:-1])]
        prof = prof + prof_t + mirror + [(r, -a) for (r, a) in reversed(prof)]
    # a closed tube: carry on from the inner bead along the inside back to the outer bead
    prof = prof + [(Rr + 0.004, prof[0][1])]
    bm, rings = bm_lathe(prof, segs, axis='X')
    # lateral grooves: push alternate tread vertices in
    if lod == 0 and kind in ("road", "van", "truck"):
        step = 2
        for v in bm.verts:
            r = math.hypot(v.co.y, v.co.z)
            if r > R - 0.0015 and abs(v.co.x) < hw * 0.6:
                a = math.atan2(v.co.z, v.co.y)
                k = int(round(a / (2 * math.pi) * segs)) % segs
                half = 1 if v.co.x > 0 else 0
                if (k + half) % step == 0 and abs(v.co.x) > hw * 0.08:
                    s = (R - 0.0055) / r
                    v.co.y *= s; v.co.z *= s
    for f in bm.faces:
        f.material_index = 0
    return bm


def flatten(bm, R, drop):
    """A flat tyre: the bottom squashed onto the ground (the hub sits `drop` lower) and the sidewalls bulged."""
    zf = -(R - drop)
    for v in bm.verts:
        if v.co.z < zf:
            k = (zf - v.co.z) / max(drop, 1e-4)
            v.co.z = zf - 0.004 * k
            v.co.x *= 1.0 + 0.22 * min(k, 1.0)
            v.co.y *= 1.0 + 0.10 * min(k, 1.0)
        elif v.co.z < zf + 0.08:
            k = 1.0 - (v.co.z - zf) / 0.08
            v.co.x *= 1.0 + 0.12 * k


def tractor_lugs(R, tw, n, h=0.045, lod=0):
    """Chevron lugs on a tractor tyre: n per side, staggered."""
    bm = bmesh.new()
    for side in (1, -1):
        for k in range(n):
            a = 2 * math.pi * (k + (0.5 if side < 0 else 0.0)) / n
            # a lug is a bar from the centre line out to the shoulder, leaning back
            p0x, p1x = side * tw * 0.04, side * tw * 0.52
            lean = 0.32
            lb = bm_box((abs(p1x - p0x), 0.055, h), ((p0x + p1x) * 0.5, 0, R + h * 0.5 - 0.004))
            bmesh.ops.transform(lb, matrix=Matrix.Rotation(side * lean, 4, 'Z'), verts=lb.verts)
            bmesh.ops.transform(lb, matrix=Matrix.Rotation(a, 4, 'X'), verts=lb.verts)
            me_v = {}
            for v in lb.verts:
                me_v[v] = bm.verts.new(v.co)
            for f in lb.faces:
                nf = bm.faces.new([me_v[v] for v in f.verts]); nf.smooth = False
            lb.free()
    return bm


def alloy_face_bm(Rr, spokes, lod, dish=0.025, style="alloy5"):
    """The spoked face of an alloy wheel in the y-z plane facing +x, solid with windows between the spokes."""
    bm = bmesh.new()
    na = {0: spokes * 8, 1: spokes * 4, 2: spokes * 2}[min(lod, 2)]
    radii = [0.0, 0.035, 0.07, 0.10, Rr * 0.86, Rr * 0.95, Rr + 0.004]
    if lod >= 1:
        radii = [0.0, 0.05, 0.08, Rr * 0.86, Rr + 0.004]
    def x_at(r):
        t = r / (Rr + 0.004)
        return -dish * (1.0 - t) * 0.6 + 0.004 * t - (0.006 if r < 0.04 else 0.0) + (0.008 if r < 0.035 else 0.0)
    grid = []
    for ri, r in enumerate(radii):
        row = []
        for k in range(na):
            a = 2 * math.pi * k / na
            if r == 0.0:
                row.append(None)
            else:
                row.append(bm.verts.new((x_at(r), math.cos(a) * r, math.sin(a) * r)))
        grid.append(row)
    centre = bm.verts.new((x_at(0.0) + 0.006, 0, 0))
    faces = []
    for ri in range(len(radii) - 1):
        for k in range(na):
            k1 = (k + 1) % na
            a = 2 * math.pi * (k + 0.5) / na
            rm = (radii[ri] + radii[ri + 1]) * 0.5
            # spoke test: angle to the nearest spoke centre, in metres at this radius
            sp = 2 * math.pi / spokes
            off = abs(((a + sp * 0.5) % sp) - sp * 0.5)
            if style == "alloy5":
                halfw = 0.024 + 0.012 * max(0.0, 1.0 - rm / (Rr * 0.8))
            else:
                halfw = 0.012
            is_window = (0.085 < rm < Rr * 0.85) and off * rm > halfw
            if style == "multi":
                is_window = (0.085 < rm < Rr * 0.85) and off * rm > 0.011
            if is_window:
                continue
            if radii[ri] == 0.0:
                f = bm.faces.new([centre, grid[ri + 1][k], grid[ri + 1][k1]])
            else:
                f = bm.faces.new([grid[ri][k], grid[ri + 1][k], grid[ri + 1][k1], grid[ri][k1]])
            f.smooth = True
            faces.append(f)
    bm.normal_update()
    for f in bm.faces:
        if f.normal.x < 0:
            f.normal_flip()
    bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=0.028 if lod == 0 else 0.03)
    for f in bm.faces:
        f.material_index = 0
    return bm


def steel_face_bm(Rr, lod, holes=8):
    """A pressed steel wheel centre: dished disc with ventilation holes and a raised nut circle."""
    bm = bmesh.new()
    na = {0: max(holes, 8) * 4, 1: max(holes, 8) * 2, 2: 10}[min(lod, 2)]
    radii = [0.0, 0.045, 0.075, 0.105, 0.12, 0.145, Rr * 0.86, Rr + 0.004]
    xs = [0.006, 0.0, -0.004, -0.024, -0.03, -0.034, -0.02, 0.004]
    if lod >= 1:
        radii = [0.0, 0.05, 0.12, Rr * 0.9, Rr + 0.004]; xs = [0.004, 0.0, -0.028, -0.02, 0.004]
    grid = []
    for ri, r in enumerate(radii):
        row = []
        for k in range(na):
            a = 2 * math.pi * k / na
            row.append(bm.verts.new((xs[ri], math.cos(a) * r, math.sin(a) * r)) if r > 0 else None)
        grid.append(row)
    centre = bm.verts.new((xs[0], 0, 0))
    for ri in range(len(radii) - 1):
        for k in range(na):
            k1 = (k + 1) % na
            if lod == 0 and ri == 4 and holes > 0:
                hk = k % (na // holes)
                if 1 <= hk <= 2:
                    continue
            if radii[ri] == 0.0:
                f = bm.faces.new([centre, grid[ri + 1][k], grid[ri + 1][k1]])
            else:
                f = bm.faces.new([grid[ri][k], grid[ri + 1][k], grid[ri + 1][k1], grid[ri][k1]])
            f.smooth = True
    bm.normal_update()
    for f in bm.faces:
        if f.normal.x < 0:
            f.normal_flip()
    bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=0.006)
    return bm


def barrel_bm(Rr, tw, segs):
    """The rim barrel and its outer lip (inside the tyre)."""
    hw = tw * 0.5
    prof = [(Rr - 0.004, hw * 0.98), (Rr + 0.016, hw * 0.96), (Rr + 0.017, hw * 0.86), (Rr + 0.004, hw * 0.80),
            (Rr - 0.006, hw * 0.6), (Rr - 0.012, 0.0), (Rr - 0.012, -hw * 0.8), (Rr + 0.006, -hw * 0.86), (Rr - 0.004, -hw * 0.95)]
    bm, _ = bm_lathe(prof, segs, axis='X')
    return bm


def nuts_bm(n, pcd_r, x, r=0.0105, h=0.016, segs=6):
    bm = bmesh.new()
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        c = bm_cyl(r, r * 0.85, h, segs, 'X', (x + h * 0.5, math.cos(a) * pcd_r, math.sin(a) * pcd_r))
        vm = {v: bm.verts.new(v.co) for v in c.verts}
        for f in c.faces:
            nf = bm.faces.new([vm[v] for v in f.verts]); nf.smooth = False
        c.free()
    return bm


def brake_bm(Rd, lod):
    """Ventilated disc (two plates and a hat) facing +x, behind the rim face."""
    bm = bmesh.new()
    segs = [32, 18, 10][min(lod, 2)]
    prof = [(0.07, -0.02), (Rd, -0.02), (Rd, -0.046), (0.07, -0.046), (0.07, -0.02)]
    d, _ = bm_lathe(prof, segs, axis='X')
    hat = bm_cyl(0.075, 0.075, 0.03, segs, 'X', (-0.008, 0, 0))
    for src in (d, hat):
        vm = {v: bm.verts.new(v.co) for v in src.verts}
        for f in src.faces:
            nf = bm.faces.new([vm[v] for v in f.verts]); nf.smooth = len(f.verts) == 4
        src.free()
    return bm


def caliper_bm(Rd, angle, lod):
    """A caliper straddling the disc edge at `angle` (radians round the axle from +Y, the front)."""
    bm = bm_rbox((0.06, 0.085, 0.13), 0.012, 1 if lod == 0 else 0, (-0.033, 0, 0))
    # bend it round the disc: place at radius Rd - 0.02
    bmesh.ops.transform(bm, matrix=Matrix.Translation((0, 0, Rd - 0.03)), verts=bm.verts)
    bmesh.ops.transform(bm, matrix=Matrix.Rotation(angle, 4, 'X'), verts=bm.verts)
    return bm


def build_wheel(spec, side, lod, name, hub, steer, caliper=True, parts=None, rim_mat="rim", bone=None):
    """Return Parts for one wheel at hub (x, y, z). spec: dict R, Rr, tw, style, spokes."""
    R, Rr, tw = spec["R"], spec["Rr"], spec["tw"]
    style = spec.get("style", "alloy5")
    segs = {0: spec.get("segs", 36), 1: 22, 2: 10}[min(lod, 2)]
    bone = bone or ("wheel_" + name)
    p = Part("wheel_" + name, bone)
    if spec.get("tyre") == "tractor" and lod <= 1:
        # lugged tyre: the carcass is lug-height smaller, so the lug tips (not the carcass) touch the ground at R
        tb = tyre_bm(R - spec.get("lug_h", 0.045) + 0.004, Rr, tw, segs, lod, "tractor")
    else:
        tb = tyre_bm(R, Rr, tw, segs, lod, spec.get("tyre", "road"))
    if spec.get("flat"):
        flatten(tb, R, spec.get("flat_drop", 0.07))
    p.add_bm(tb, "rubber"); tb.free()
    if spec.get("tyre") == "tractor" and lod <= 1:
        lb = tractor_lugs(R - spec.get("lug_h", 0.045), tw, spec.get("lugs", 22) if lod == 0 else spec.get("lugs", 22) * 2 // 3, spec.get("lug_h", 0.045), lod)
        p.add_bm(lb, "rubber"); lb.free()
    if spec.get("sidewall") and lod == 0:
        # moulded sidewall lettering (fictional), raised 2 mm, twice round the outer wall
        from vk_core import text_bm
        sw = R - Rr
        rt = Rr + 0.55 * sw
        size = min(0.045, sw * 0.22)
        for k in range(2):
            tb = text_bm(spec["sidewall"], size, 0.0)
            a0 = k * math.pi
            for v in tb.verts:
                ang = a0 - (1 if side > 0 else -1) * v.co.x / rt     # the left wheel is mirrored after: keep it reading forwards
                rr = rt + v.co.y
                v.co = V((tw * 0.5 * 0.99 + 0.002, math.cos(ang) * rr, math.sin(ang) * rr))
            tb.normal_update()
            for f in tb.faces:
                if f.normal.x < 0:
                    f.normal_flip()
            p.add_bm(tb, "rubber"); tb.free()
    if lod <= 1:
        bb = barrel_bm(Rr, tw, max(12, segs * 2 // 3))
        p.add_bm(bb, rim_mat if style.startswith("alloy") or style == "multi" else spec.get("barrel_mat", "rim_steel")); bb.free()
    face_x = tw * 0.5 * 0.86
    if style.startswith("alloy") or style == "multi":
        fb = alloy_face_bm(Rr, spec.get("spokes", 5), lod, 0.03, style)
        bmesh.ops.transform(fb, matrix=Matrix.Translation((face_x - 0.006, 0, 0)), verts=fb.verts)
        p.add_bm(fb, rim_mat); fb.free()
        if lod == 0:
            nb = nuts_bm(spec.get("nuts", 5), 0.055, face_x - 0.02, 0.0095, 0.014)
            p.add_bm(nb, "chrome"); nb.free()
            cb = bm_cyl(0.028, 0.026, 0.008, 20, 'X', (face_x - 0.004, 0, 0))
            p.add_bm(cb, spec.get("cap_mat", "trim")); cb.free()
    else:
        fb = steel_face_bm(Rr, lod, spec.get("holes", 8))
        bmesh.ops.transform(fb, matrix=Matrix.Translation((face_x - 0.004, 0, 0)), verts=fb.verts)
        p.add_bm(fb, spec.get("face_mat", "rim_steel")); fb.free()
        if lod <= 1:
            n_nuts = spec.get("nuts", 4)
            nb = nuts_bm(n_nuts, spec.get("pcd", 0.05), face_x - 0.004, spec.get("nut_r", 0.0095), 0.014)
            p.add_bm(nb, "chrome" if spec.get("chrome_nuts") else "metal"); nb.free()
            cr = spec.get("cap_r", 0.032)
            cb = bm_cyl(cr, cr * 0.94, 0.022 if spec.get("hubcap") else 0.012, 20, 'X', (face_x + 0.004, 0, 0))
            p.add_bm(cb, spec.get("cap_mat", "metal")); cb.free()
        if spec.get("trim_cover") and lod <= 1:
            # a plastic wheel trim over the steel wheel (1980s / fleet cars)
            prof = [(0.0, face_x + 0.012), (0.06, face_x + 0.012), (0.09, face_x + 0.004), (Rr * 0.7, face_x + 0.0),
                    (Rr * 0.92, face_x + 0.006), (Rr + 0.012, face_x - 0.004)]
            tb2, rings = bm_lathe(prof, segs, axis='X')
            p.add_bm(tb2, spec.get("trim_mat", "rim")); tb2.free()
    parts = parts if parts is not None else []
    if lod <= 1 and spec.get("disc", True):
        db = brake_bm(min(Rr * 0.78, Rr - 0.045), lod)
        bmesh.ops.transform(db, matrix=Matrix.Translation((face_x - 0.03, 0, 0)), verts=db.verts)
        p.add_bm(db, "metal"); db.free()
    if side < 0:
        mirror_x(p.bm)
    bmesh.ops.transform(p.bm, matrix=Matrix.Translation(V(hub)), verts=p.bm.verts)
    parts.append(p)
    if caliper and lod <= 1 and spec.get("disc", True):
        cbone = ("steer_" + name.rstrip("2")) if steer else spec.get("hub_bone", "root")
        c = Part("caliper_" + name, cbone)
        ang = math.radians(spec.get("caliper_deg", 115 if steer else 60))
        cb = caliper_bm(min(Rr * 0.78, Rr - 0.045), ang, lod)
        bmesh.ops.transform(cb, matrix=Matrix.Translation((face_x - 0.03, 0, 0)), verts=cb.verts)
        c.add_bm(cb, spec.get("caliper_mat", "caliper")); cb.free()
        if side < 0:
            mirror_x(c.bm)
        bmesh.ops.transform(c.bm, matrix=Matrix.Translation(V(hub)), verts=c.bm.verts)
        parts.append(c)
    return parts

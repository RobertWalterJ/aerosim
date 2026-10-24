# AeroSim vehicle kit: the details laid onto a car body: lamp units with reflectors behind clear lenses, tail lamps with
# separate tail, brake, indicator and reverse sections, grille, intakes, number plates in recesses (blank fictional
# plates), door handles, mirrors, wipers, exhaust, side repeaters, badges, roof rails, aerial and police lightbars.
import bmesh, math
from mathutils import Vector as V, Matrix
from vk_core import Part, decal, rounded_rect, quad_outline, bm_rbox, bm_box, bm_cyl, bm_tube, bm_sweep, mirror_x, text_bm
from vk_body import section, R_BELT, R_SH, R_CANT, R_GL0, R_TOP


def _add(parts, name, bone, bm, mat, side_mat=None):
    if bm is None:
        return
    p = None
    for q in parts:
        if q.name == name:
            p = q
    if p is None:
        p = Part(name, bone)
        parts.append(p)
    if side_mat is None:
        p.add_bm(bm, mat)
    else:
        p.add_bm(bm, keep_mats=[mat, side_mat])
    bm.free()


def lamp_front(parts, surf, cfg, lod, bone="body"):
    """Headlamp units on both sides. cfg: x (centre), z, w, h, r (corner radius), bowls (count), ind (True), slant."""
    for sx in (1, -1):
        x, z, w, h = cfg["x"] * sx, cfg["z"], cfg["w"], cfg["h"]
        r = cfg.get("r", 0.04)
        slant = cfg.get("slant", 0.0)
        shape = cfg.get("shape", "rect")
        nx, ny = (8, 3) if lod == 0 else (4, 2)
        plane = 'front'
        if cfg.get("auto"):
            fr = surf.frame_at(x, z, 'front', cfg.get("turn", 0.5))
            if fr is None:
                continue
            plane = fr
            x, z = 0.0, 0.0
        def outline(u, v, x=x, z=z, w=w, h=h, sx=sx):
            if shape == "round":
                a = (u - 0.5) * 2; b = (v - 0.5) * 2
                m = max(abs(a), abs(b))
                n = math.hypot(a, b) or 1.0
                return (x + a * m / n * w * 0.5, z + b * m / n * h * 0.5)
            fx, fz = rounded_rect(x, z, w, h, r)(u, v)
            # outer end higher (slant), inner lower
            t = (fx - x) / max(w, 1e-4) * sx
            return (fx, fz + slant * t)
        # black backing, then chrome bowls, then the clear lens
        b = decal(surf, outline, plane, nx, ny, 0.002, 0.002, None, rim=False)
        _add(parts, "lamps", bone, b, "trim")
        n = cfg.get("bowls", 2)
        if lod == 0 and shape != "round":
            for k in range(n):
                cx = x + sx * (-w * 0.5 + w * (k + 0.5) / n) * 0.85
                rr = min(h * 0.36, w / n * 0.35)
                hit = surf.project([(cx, z + slant * ((cx - x) / w * sx))], plane, 0.0)[0]
                if hit:
                    loc, nrm = hit
                    bb = bm_cyl(rr, rr * 0.55, 0.012, 16, 'Y', (0, 0, 0), caps=True)
                    q = V((0, 1, 0)).rotation_difference(nrm)
                    bmesh.ops.transform(bb, matrix=Matrix.Translation(loc + nrm * 0.006) @ q.to_matrix().to_4x4(), verts=bb.verts)
                    _add(parts, "lamps", bone, bb, "lamp_reflector")
                    # the bulb / projector lens in the middle
                    pb = bm_cyl(rr * 0.35, rr * 0.3, 0.01, 10, 'Y', (0, 0, 0))
                    bmesh.ops.transform(pb, matrix=Matrix.Translation(loc + nrm * 0.011) @ q.to_matrix().to_4x4(), verts=pb.verts)
                    _add(parts, "lamps", bone, pb, "lamp_front")
        elif shape == "round":
            hit = surf.project([(x, z)], plane, 0.0)[0]
            if hit:
                loc, nrm = hit
                rr = min(w, h) * 0.42
                bb = bm_cyl(rr, rr * 0.5, 0.012, 20, 'Y')
                q = V((0, 1, 0)).rotation_difference(nrm)
                bmesh.ops.transform(bb, matrix=Matrix.Translation(loc + nrm * 0.006) @ q.to_matrix().to_4x4(), verts=bb.verts)
                _add(parts, "lamps", bone, bb, "lamp_reflector")
        if cfg.get("ind", True):
            iw = w * 0.22
            ix = x + sx * (w * 0.5 - iw * 0.5 - 0.01)
            def ind_out(u, v, ix=ix, iw=iw):
                return rounded_rect(ix, z - h * 0.18 + slant * 0.4, iw, h * 0.4, 0.01)(u, v)
            ib = decal(surf, ind_out, plane, 3, 2, 0.008, 0.004, None, rim=False)
            _add(parts, "lamps", bone, ib, "lamp_ind_r" if sx > 0 else "lamp_ind_l")
        lb = decal(surf, outline, plane, nx, ny, 0.016, 0.016, None, rim=True)
        _add(parts, "lamps", bone, lb, "lamp_front", "lamp_front")
        # a chrome bezel for older cars
        if cfg.get("bezel"):
            def bez(u, v, x=x, z=z, w=w, h=h):
                return rounded_rect(x, z, w + 0.03, h + 0.03, r + 0.01)(u, v)
            bz = decal(surf, bez, plane, nx, ny, 0.004, 0.004, None, rim=True)
            _add(parts, "lamps", bone, bz, "chrome", "chrome")


def lamp_rear(parts, surf, cfg, lod, bone="body"):
    """Tail lamp clusters. cfg: x, z, w, h, r, layout: list of (material, u0, u1, v0, v1) inside the unit."""
    layout = cfg.get("layout", [("lamp_tail", 0.0, 1.0, 0.55, 1.0), ("lamp_brake", 0.0, 1.0, 0.2, 0.55),
                                 ("lamp_ind", 0.0, 0.6, 0.0, 0.2), ("lamp_reverse", 0.6, 1.0, 0.0, 0.2)])
    plane0 = cfg.get("plane", "rear")
    for sx in (1, -1):
        x, z, w, h = cfg["x"] * sx, cfg["z"], cfg["w"], cfg["h"]
        r = cfg.get("r", 0.03)
        plane = plane0
        if cfg.get("auto"):
            fr = surf.frame_at(x, z, plane0, cfg.get("turn", 0.35))
            if fr is None:
                continue
            plane = fr
            x, z = 0.0, 0.0
        # black body under it
        def back(u, v, x=x):
            return rounded_rect(x, z, w + 0.012, h + 0.012, r)(u, v)
        b = decal(surf, back, plane, 6, 3, 0.002, 0.002, None, rim=False)
        _add(parts, "lamps", bone, b, "trim")
        for (mat, u0, u1, v0, v1) in layout:
            if mat == "lamp_ind":
                mat = "lamp_ind_r" if sx > 0 else "lamp_ind_l"
            # u runs from the outer edge inward
            if sx > 0:
                xa, xb = x + w * 0.5 - w * u1, x + w * 0.5 - w * u0
            else:
                xa, xb = x - w * 0.5 + w * u0, x - w * 0.5 + w * u1
            za, zb = z - h * 0.5 + h * v0, z - h * 0.5 + h * v1
            def sec(u, v, xa=xa, xb=xb, za=za, zb=zb):
                return (xa + (xb - xa) * u + (0.003 if u == 0 else (-0.003 if u == 1 else 0)), za + (zb - za) * v + (0.003 if v == 0 else (-0.003 if v == 1 else 0)))
            nx = max(2, int((xb - xa) / 0.05)) if lod == 0 else 2
            lb = decal(surf, sec, plane, nx, 2, 0.012, 0.010, None, rim=True)
            _add(parts, "lamps", bone, lb, mat, mat)


def plate(parts, surf, plane, x, z, w=0.52, h=0.112, bone="body", recess=True, lod=0):
    def pl(u, v):
        return rounded_rect(x, z, w, h, 0.01)(u, v)
    if recess:
        def rc(u, v):
            return rounded_rect(x, z, w + 0.05, h + 0.04, 0.02)(u, v)
        rb = decal(surf, rc, plane, 4, 2, 0.0015, 0.0015, None, rim=False)
        _add(parts, "plates", bone, rb, "trim")
    pb = decal(surf, pl, plane, 4, 2, 0.006, 0.006, None, rim=True)
    _add(parts, "plates", bone, pb, "plate", "trim")
    if lod == 0:
        # a thin printed border, blank otherwise (fictional, no registration)
        for (a, b, c, d) in [(x - w * 0.47, x + w * 0.47, z + h * 0.40, z + h * 0.43), (x - w * 0.47, x + w * 0.47, z - h * 0.43, z - h * 0.40)]:
            def ln(u, v, a=a, b=b, c=c, d=d):
                return (a + (b - a) * u, c + (d - c) * v)
            lb = decal(surf, ln, plane, 2, 1, 0.0068, 0.0005, None, rim=False)
            _add(parts, "plates", bone, lb, "plate_text")


def grille(parts, surf, cfg, lod, bone="body"):
    x, z, w, h = 0.0, cfg["z"], cfg["w"], cfg["h"]
    r = cfg.get("r", 0.03)
    def g(u, v):
        return rounded_rect(x, z, w, h, r)(u, v)
    b = decal(surf, g, 'front', 8, 2, 0.002, 0.002, None, rim=False)
    _add(parts, "grille", bone, b, cfg.get("back", "trim"))
    slat_mat = cfg.get("slat", "trim_grey")
    n = cfg.get("slats", 3)
    if lod <= 1:
        for k in range(n):
            zz = z - h * 0.5 + h * (k + 0.5) / n
            def sl(u, v, zz=zz):
                return (x - w * 0.47 + w * 0.94 * u, zz - 0.006 + 0.012 * v)
            sb = decal(surf, sl, 'front', 8, 1, 0.009, 0.008, None, rim=True)
            _add(parts, "grille", bone, sb, slat_mat, slat_mat)
        if cfg.get("vbars"):
            for k in range(cfg["vbars"]):
                xx = x - w * 0.45 + w * 0.9 * (k + 0.5) / cfg["vbars"]
                def vb(u, v, xx=xx):
                    return (xx - 0.004 + 0.008 * u, z - h * 0.46 + h * 0.92 * v)
                vbb = decal(surf, vb, 'front', 1, 2, 0.009, 0.008, None, rim=True)
                _add(parts, "grille", bone, vbb, slat_mat, slat_mat)
    if cfg.get("frame"):
        def fr(u, v):
            return rounded_rect(x, z, w + 0.024, h + 0.024, r + 0.008)(u, v)
        fb = decal(surf, fr, 'front', 8, 2, 0.0035, 0.0035, None, rim=True)
        _add(parts, "grille", bone, fb, cfg["frame"], cfg["frame"])


def front_panel(parts, surf, x, z, w, h, mat, r=0.02, bone="body", offset=0.003, plane='front', name="trimbits"):
    def g(u, v):
        return rounded_rect(x, z, w, h, r)(u, v)
    b = decal(surf, g, plane, 6, 2, offset, offset, None, rim=True)
    _add(parts, name, bone, b, mat, mat)


def handle(parts, surf, side, d, z, L, bone, mat="paint", lod=0):
    y = L * 0.5 - d
    def hd(u, v):
        return rounded_rect(y, z, 0.15, 0.032, 0.012)(u, v)
    plane = 'right' if side > 0 else 'left'
    # a dark recess, then the grip
    rb = decal(surf, lambda u, v: rounded_rect(y, z - 0.004, 0.17, 0.05, 0.02)(u, v), plane, 3, 2, 0.0012, 0.0012, None, rim=False)
    _add(parts, "handle_" + bone, bone, rb, "trim")
    hb = decal(surf, hd, plane, 4 if lod == 0 else 2, 2, 0.011, 0.011, None, rim=True)
    _add(parts, "handle_" + bone, bone, hb, mat, mat)


def strip_side(parts, surf, side, d0, d1, z, hgt, L, mat, bone="body", offset=0.004, name="strips"):
    plane = 'right' if side > 0 else 'left'
    y0, y1 = L * 0.5 - d0, L * 0.5 - d1
    def st(u, v):
        return (y0 + (y1 - y0) * u, z - hgt * 0.5 + hgt * v)
    n = max(2, int(abs(d1 - d0) / 0.08))
    b = decal(surf, st, plane, n, 1, offset, offset, None, rim=True)
    _add(parts, name, bone, b, mat, mat)


def mirror(parts, s, side, d, bone, lod, mat="paint", stalk_mat="trim"):
    P = section(s, d)
    x = P[R_BELT][0] + 0.005
    zb = P[R_BELT][1]
    y = s.L * 0.5 - d
    out = 0.20
    hsz = (out, 0.085, 0.115)
    c = V((side * (x + out * 0.5 + 0.035), y - 0.02, zb + 0.09))
    hb = bm_rbox(hsz, 0.035, 2 if lod == 0 else 1, (0, 0, 0))
    # taper the housing: the outer end a little smaller, the back rounded
    for v in hb.verts:
        t = (v.co.x + out * 0.5) / out
        v.co.z *= 1.0 - 0.15 * t
        v.co.y *= 1.0 - 0.1 * t
    bmesh.ops.transform(hb, matrix=Matrix.Translation(c) @ Matrix.Rotation(side * 0.06, 4, 'Z'), verts=hb.verts)
    if side < 0:
        pass
    _add(parts, "mirror_" + bone, bone, hb, mat)
    # glass on the back
    gb = bm_box((out * 0.86, 0.004, 0.095), (0, 0, 0))
    bmesh.ops.transform(gb, matrix=Matrix.Translation(c + V((0, -0.044, 0))) @ Matrix.Rotation(side * 0.06, 4, 'Z'), verts=gb.verts)
    _add(parts, "mirror_" + bone, bone, gb, "mirror")
    # stalk to the door
    sb = bm_rbox((0.07, 0.05, 0.04), 0.012, 1, (side * (x + 0.035), y - 0.03, zb + 0.045))
    _add(parts, "mirror_" + bone, bone, sb, stalk_mat)


def wipers(parts, surf, s, lod, pivots=(0.40, -0.18), length=0.56, park_dir=-1):
    """Wiper arms lying along the bottom of the windscreen, each on its own bone (wiper_r, wiper_l). Returns pivot info."""
    info = []
    d_ws = s.windscreen[0] + 0.035
    y = s.L * 0.5 - d_ws
    for k, px in enumerate(pivots):
        bone = "wiper_r" if k == 0 else "wiper_l"
        pts = []
        n = 8
        for i in range(n + 1):
            t = i / n
            xx = px + park_dir * length * t
            yy = y - 0.03 * t
            pts.append((xx, yy))
        hits = surf.project(pts, 'top', 0.0)
        path = [h[0] + h[1] * 0.016 for h in hits if h]
        if len(path) < 3:
            continue
        nrm0 = hits[0][1]
        arm = bm_sweep([(-0.008, -0.005), (0.008, -0.005), (0.008, 0.005), (-0.008, 0.005)], path, True, up=nrm0)
        _add(parts, "wiper_" + bone, bone, arm, "trim")
        if lod == 0:
            bl = [h[0] + h[1] * 0.008 for h in hits[2:] if h]
            blade = bm_sweep([(-0.004, -0.008), (0.004, -0.008), (0.004, 0.006), (-0.004, 0.006)], bl, True, up=nrm0)
            _add(parts, "wiper_" + bone, bone, blade, "rubber")
            hub = bm_cyl(0.018, 0.016, 0.03, 12, 'Z', (0, 0, 0))
            q = V((0, 0, 1)).rotation_difference(nrm0)
            bmesh.ops.transform(hub, matrix=Matrix.Translation(path[0]) @ q.to_matrix().to_4x4(), verts=hub.verts)
            _add(parts, "wiper_" + bone, bone, hub, "trim")
        info.append((bone, tuple(hits[0][0]), tuple(nrm0)))
    return info


def exhaust(parts, s, x, lod, d_back=0.04, z=0.24, r=0.032, mat="chrome"):
    y = -s.L * 0.5 + d_back
    tb = bm_cyl(r, r, 0.42, 14 if lod == 0 else 8, 'Y', (x, y + 0.21, z), caps=False)
    _add(parts, "exhaust", "body", tb, "metal")
    if lod == 0:
        tip = bm_cyl(r + 0.004, r + 0.004, 0.08, 16, 'Y', (x, y + 0.02, z), caps=False)
        _add(parts, "exhaust", "body", tip, mat)
        inner = bm_cyl(r * 0.8, r * 0.8, 0.002, 12, 'Y', (x, y + 0.04, z), caps=True)
        _add(parts, "exhaust", "body", inner, "trim")


def roof_rails(parts, s, d0, d1, lod, mat="trim", inset=0.11):
    for sx in (1, -1):
        path = []
        n = 10
        for i in range(n + 1):
            d = d0 + (d1 - d0) * i / n
            P = section(s, d)
            x = P[R_CANT][0] - inset * 0.3
            z = P[R_CANT][1] + 0.05 + 0.012 * math.sin(math.pi * i / n)
            path.append((sx * x, s.L * 0.5 - d, z))
        rb = bm_sweep([(-0.012, -0.016), (0.012, -0.016), (0.012, 0.016), (-0.012, 0.016)], path, True)
        _add(parts, "roof_rails", "body", rb, mat)
        for d in (d0 + 0.02, d1 - 0.02):
            P = section(s, d)
            fb = bm_rbox((0.04, 0.08, 0.06), 0.012, 1, (sx * (P[R_CANT][0] - inset * 0.3), s.L * 0.5 - d, P[R_CANT][1] + 0.025))
            _add(parts, "roof_rails", "body", fb, mat)


def lightbar(parts, s, d, lod, style="modern", width=1.15):
    """A police lightbar across the roof at d: base, red lens on the left half, blue on the right (fictional)."""
    P = section(s, d)
    zt = P[R_TOP][1]
    y = s.L * 0.5 - d
    if style == "modern":
        h, dep = 0.075, 0.26
        base = bm_rbox((width, dep, 0.03), 0.01, 1, (0, y, zt + 0.03))
        _add(parts, "lightbar", "body", base, "trim")
        for sx, mat in ((-1, "lightbar_red"), (1, "lightbar_blue")):
            lb = bm_rbox((width * 0.49, dep * 0.92, h), 0.03, 2 if lod == 0 else 1, (sx * width * 0.25, y, zt + 0.045 + h * 0.5))
            _add(parts, "lightbar", "body", lb, mat)
        # feet
        for sx in (1, -1):
            fb = bm_rbox((0.06, 0.2, 0.05), 0.01, 1, (sx * width * 0.42, y, zt + 0.01))
            _add(parts, "lightbar", "body", fb, "trim")
        # inner reflector shapes (seen through the lens at lod 0)
    else:
        # 1980s: chrome base, two rotating-beacon domes on a bar with a centre box
        h, dep = 0.12, 0.30
        base = bm_rbox((width, dep, 0.05), 0.015, 1, (0, y, zt + 0.05))
        _add(parts, "lightbar", "body", base, "chrome")
        for sx, mat in ((-1, "lightbar_red"), (1, "lightbar_blue")):
            dm = bm_rbox((width * 0.36, dep * 0.9, h), 0.05, 3 if lod == 0 else 1, (sx * width * 0.31, y, zt + 0.075 + h * 0.5))
            _add(parts, "lightbar", "body", dm, mat)
        cb = bm_rbox((width * 0.24, dep * 0.9, 0.08), 0.02, 1, (0, y, zt + 0.115))
        _add(parts, "lightbar", "body", cb, "paint2")
        for sx in (1, -1):
            fb = bm_rbox((0.05, 0.24, 0.07), 0.01, 1, (sx * width * 0.45, y, zt + 0.02))
            _add(parts, "lightbar", "body", fb, "chrome")


def aerial(parts, s, d, x, lod, length=0.18, whip=False):
    P = section(s, d)
    zt = P[R_TOP][1]
    y = s.L * 0.5 - d
    if whip:
        tb = bm_tube((x, y, zt), (x, y - 0.25, zt + 1.05), 0.0035, 5)
        # slightly bent near the top
        _add(parts, "aerial", "body", tb, "trim")
        bb = bm_cyl(0.022, 0.016, 0.03, 10, 'Z', (x, y, zt + 0.012))
        _add(parts, "aerial", "body", bb, "chrome")
    else:
        sb = bm_rbox((0.03, 0.12, 0.05), 0.012, 1, (x, y, zt + 0.02))
        bmesh.ops.transform(sb, matrix=Matrix.Translation((0, 0, 0)), verts=sb.verts)
        _add(parts, "aerial", "body", sb, "trim")
        tb = bm_tube((x, y + 0.02, zt + 0.04), (x, y - 0.08, zt + 0.04 + length), 0.004, 5)
        _add(parts, "aerial", "body", tb, "trim")


def badge_text(parts, surf, txt, plane, x, z, size, mat="chrome", bone="body"):
    """Fictional marque lettering laid on the rear (or front) face."""
    bm = text_bm(txt, size, 0.0)
    for v in bm.verts:
        a, b = v.co.x, v.co.y
        if plane == 'rear':
            o, dr = V((x + a, -20, z + b)), V((0, 1, 0))
        else:
            o, dr = V((x - a, 20, z + b)), V((0, -1, 0))
        loc, nrm = surf.hit(o, dr, 40)
        v.co = (loc + (-dr) * 0.003) if loc is not None else o
    bm.normal_update()
    want = V((0, -1, 0)) if plane == 'rear' else V((0, 1, 0))
    for f in bm.faces:
        if f.normal.dot(want) < 0:
            f.normal_flip()
    _add(parts, "badges", bone, bm, mat)

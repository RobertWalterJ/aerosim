# AeroSim vehicle kit: a simple interior to see through the glass: the cabin tub (floor, door cards that move with their
# doors, headliner), a dashboard with an instrument hood and centre stack, a steering wheel on its own bone, front seats
# and a rear bench, a parcel shelf or load floor. Left-hand drive (driver on the left, -x), as in the game's province.
import bmesh, math
from mathutils import Vector as V, Matrix
from vk_core import Part, bm_rbox, bm_box, bm_cyl, bm_tube, bm_sweep, bm_lathe
from vk_body import section, R_BELT, R_CANT, R_TOP, R_FLOOR, R_GL0


def _add(parts, name, bone, bm, mat):
    for q in parts:
        if q.name == name and q.bone == bone:
            q.add_bm(bm, mat); bm.free(); return
    p = Part(name, bone)
    p.add_bm(bm, mat)
    parts.append(p)
    bm.free()


def tub(parts, s, d0, d1, z_floor, door_ranges, lod, mat="interior"):
    """Floor, door cards and headliner from d0 (dash) to d1 (rear of the cabin), facing in. door_ranges: list of
    (d0, d1, bone_right, bone_left) whose door card pieces ride on the doors."""
    step = 0.12 if lod == 0 else 0.3
    n = max(2, int((d1 - d0) / step))
    ds = sorted(set([d0 + (d1 - d0) * i / n for i in range(n + 1)] + [x for r in door_ranges for x in r[:2] if d0 < x < d1]))
    def wall_x(d):
        P = section(s, d)
        return P[R_BELT][0] - 0.07, P[R_BELT][1] - 0.02, P[R_CANT][0] - 0.06, P[R_CANT][1] - 0.06, P[R_TOP][1] - 0.065
    for i in range(len(ds) - 1):
        da, db = ds[i], ds[i + 1]
        ya, yb = s.L * 0.5 - da, s.L * 0.5 - db
        xa, za, xca, zca, zta = wall_x(da)
        xb, zb_, xcb, zcb, ztb = wall_x(db)
        dm = (da + db) * 0.5
        bone_r = bone_l = "body"
        for (r0, r1, br, bl) in door_ranges:
            if r0 - 1e-4 <= da and db <= r1 + 1e-4:
                bone_r, bone_l = br, bl
        for sx, bone in ((1, bone_r), (-1, bone_l)):
            bm = bmesh.new()
            v = [bm.verts.new((sx * xa, ya, z_floor)), bm.verts.new((sx * xa, ya, za)), bm.verts.new((sx * xb, yb, zb_)), bm.verts.new((sx * xb, yb, z_floor))]
            f = bm.faces.new(v if sx < 0 else list(reversed(v)))
            # armrest ledge on the door card
            if lod == 0:
                zr = z_floor + (za - z_floor) * 0.55
                v2 = [bm.verts.new((sx * (xa - 0.05), ya, zr)), bm.verts.new((sx * xa, ya, zr)), bm.verts.new((sx * xb, yb, zr)), bm.verts.new((sx * (xb - 0.05), yb, zr))]
                f2 = bm.faces.new(v2 if sx > 0 else list(reversed(v2)))
            bm.normal_update()
            for ff in bm.faces:
                if ff.normal.x * sx > 0 and abs(ff.normal.x) > 0.5:
                    ff.normal_flip()
            _add(parts, "cabin", bone, bm, mat)
        # floor
        bm = bmesh.new()
        v = [bm.verts.new((-xa, ya, z_floor)), bm.verts.new((xa, ya, z_floor)), bm.verts.new((xb, yb, z_floor)), bm.verts.new((-xb, yb, z_floor))]
        f = bm.faces.new(v)
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
        _add(parts, "cabin", "body", bm, "trim")
        # headliner (a shallow arch, facing down)
        bm = bmesh.new()
        k = 4
        ra, rb = [], []
        for j in range(k + 1):
            t = j / k * 2 - 1
            ra.append(bm.verts.new((t * xca, ya, lerp_arch(zca, zta, t))))
            rb.append(bm.verts.new((t * xcb, yb, lerp_arch(zcb, ztb, t))))
        for j in range(k):
            f = bm.faces.new([ra[j], ra[j + 1], rb[j + 1], rb[j]])
            f.normal_update()
            if f.normal.z > 0:
                f.normal_flip()
        _add(parts, "cabin", "body", bm, "interior")


def lerp_arch(z_edge, z_top, t):
    return z_edge + (z_top - z_edge) * (1 - t * t)


def dashboard(parts, s, d_ws, z_floor, lod, lhd=True, mat="dash"):
    """Dashboard just behind the screen base; returns the steering wheel centre and its axis."""
    P = section(s, d_ws + 0.25)
    w = P[R_BELT][0] - 0.07
    zb = P[R_BELT][1]
    y = s.L * 0.5 - (d_ws + 0.22)
    # main body: a rounded block whose top meets the screen, face sloping to the floor
    top = bm_rbox((w * 2, 0.42, 0.16), 0.05, 2 if lod == 0 else 1, (0, y + 0.02, zb - 0.02))
    _add(parts, "dash", "body", top, mat)
    lower = bm_rbox((w * 2 - 0.04, 0.22, 0.22), 0.04, 1, (0, y - 0.12, zb - 0.2))
    _add(parts, "dash", "body", lower, mat)
    # centre stack and console down to the floor
    st = bm_rbox((0.24, 0.2, zb - 0.1 - z_floor), 0.03, 1, (0, y - 0.15, (zb - 0.1 + z_floor) * 0.5))
    _add(parts, "dash", "body", st, mat)
    cons = bm_rbox((0.2, 0.62, 0.16), 0.03, 1, (0, y - 0.55, z_floor + 0.08))
    _add(parts, "dash", "body", cons, mat)
    dx = -0.37 if lhd else 0.37
    if lod == 0:
        # instrument hood and the dials' faces
        hood = bm_rbox((0.38, 0.18, 0.09), 0.04, 2, (dx, y - 0.08, zb + 0.07))
        _add(parts, "dash", "body", hood, mat)
        face = bm_box((0.32, 0.01, 0.07), (dx, y - 0.165, zb + 0.045))
        _add(parts, "dash", "body", face, "trim_grey")
        # screen and vents in the centre
        scr = bm_box((0.2, 0.01, 0.1), (0, y - 0.16, zb - 0.03))
        _add(parts, "dash", "body", scr, "glass_tint")
        for vx in (-0.62, -0.08, 0.08, 0.62):
            vb = bm_box((0.1, 0.012, 0.045), (vx * w / 0.75 if abs(vx) > 0.5 else vx, y - 0.19, zb - 0.07))
            _add(parts, "dash", "body", vb, "trim")
        # gear lever
        gl = bm_tube((0, y - 0.45, z_floor + 0.16), (0, y - 0.47, z_floor + 0.32), 0.008, 6)
        _add(parts, "dash", "body", gl, "trim")
        knob = bm_rbox((0.04, 0.04, 0.05), 0.018, 2, (0, y - 0.47, z_floor + 0.33))
        _add(parts, "dash", "body", knob, "trim")
    # steering wheel: rim, three spokes, hub; tilted about 25 degrees back from vertical
    wc = V((dx, y - 0.36, zb + 0.0))
    tilt = math.radians(62.0)      # the wheel plane's angle from horizontal
    axis = V((0, math.cos(tilt) * -1, math.sin(tilt)))   # pointing up and back toward the driver
    axis = V((0, -math.sin(math.radians(25)), math.cos(math.radians(25))))
    axis = V((0, -math.cos(math.radians(65)), math.sin(math.radians(65)))).normalized()
    # build in the x-z plane facing -y, then tilt
    sw = bmesh.new()
    rim_r, tube = 0.185, 0.016
    segs, tsegs = (32, 8) if lod == 0 else (16, 5)
    prof = [(rim_r + tube * math.cos(a), tube * math.sin(a)) for a in [2 * math.pi * k / tsegs for k in range(tsegs + 1)]]
    rb_, _ = bm_lathe([(r, ax) for (r, ax) in prof], segs, axis='Y')
    _add(parts, "steering", "steering_wheel", rb_, "trim")
    hub = bm_rbox((0.12, 0.05, 0.1), 0.03, 2 if lod == 0 else 1, (0, 0.0, 0))
    _add(parts, "steering", "steering_wheel", hub, "trim")
    for a in (math.radians(-90), math.radians(20), math.radians(160)):
        sp = bm_tube((math.cos(a) * 0.05, 0.0, math.sin(a) * 0.05), (math.cos(a) * rim_r, 0.0, math.sin(a) * rim_r), 0.012, 6)
        _add(parts, "steering", "steering_wheel", sp, "trim")
    # place it: the wheel lies in x-z facing -y; tip it back
    for p in parts:
        if p.name == "steering":
            rot = Matrix.Rotation(-math.radians(25), 4, 'X')
            bmesh.ops.transform(p.bm, matrix=Matrix.Translation(wc) @ rot, verts=p.bm.verts)
    ax = (Matrix.Rotation(-math.radians(25), 3, 'X') @ V((0, -1, 0))).normalized()
    col = bm_tube(wc + ax * 0.03, wc - ax * 0.32, 0.03, 8)
    _add(parts, "dash", "body", col, mat)
    return wc, ax


def seat(parts, x, y, z_floor, lod, w=0.5, mat="seat", bench=False, height=0.3, back_h=0.6, recline=20.0, head=True):
    """One seat (cushion, backrest, headrest), facing +y (forward)."""
    zc = z_floor + height
    segs = 2 if lod == 0 else 1
    cush = bm_rbox((w, 0.5, 0.12), 0.05, segs, (x, y, zc))
    _add(parts, "seats", "body", cush, mat)
    base = bm_box((w * 0.8, 0.4, max(height - 0.06, 0.05)), (x, y, z_floor + (height - 0.06) * 0.5))
    _add(parts, "seats", "body", base, "trim")
    bk = bm_rbox((w, 0.12, back_h), 0.05, segs, (0, 0, back_h * 0.5))
    bmesh.ops.transform(bk, matrix=Matrix.Translation((x, y - 0.25, zc + 0.03)) @ Matrix.Rotation(-math.radians(recline), 4, 'X'),
                        verts=bk.verts)
    if not bench and lod == 0:
        # side bolsters
        for sx in (1, -1):
            bl = bm_rbox((0.06, 0.14, back_h * 0.7), 0.025, 1, (sx * (w * 0.5 - 0.02), 0.03, back_h * 0.4))
            bmesh.ops.transform(bl, matrix=Matrix.Translation((x, y - 0.25, zc + 0.03)) @ Matrix.Rotation(-math.radians(recline), 4, 'X'),
                                verts=bl.verts)
            _add(parts, "seats", "body", bl, mat)
    _add(parts, "seats", "body", bk, mat)
    if head:
        hs = [x] if not bench else [x - w * 0.33, x + w * 0.33]
        for hx in hs:
            hr = bm_rbox((0.24, 0.09, 0.17), 0.04, segs, (0, 0, 0))
            top = Matrix.Translation((hx, y - 0.25, zc + 0.03)) @ Matrix.Rotation(-math.radians(recline), 4, 'X') @ Matrix.Translation((0, 0, back_h + 0.12))
            bmesh.ops.transform(hr, matrix=top, verts=hr.verts)
            _add(parts, "seats", "body", hr, mat)


def steering_wheel(parts, centre, tilt_deg, lod, rim_r=0.185, col_len=0.32):
    """A steering wheel (rim, three spokes, hub) on its own bone, tipped back by tilt_deg from upright. Returns (centre, axis)."""
    segs, tsegs = (32, 8) if lod == 0 else (16, 5)
    tube = 0.016 if rim_r < 0.22 else 0.02
    prof = [(rim_r + tube * math.cos(a), tube * math.sin(a)) for a in [2 * math.pi * k / tsegs for k in range(tsegs + 1)]]
    p = Part("steering", "steering_wheel")
    rb_, _ = bm_lathe(prof, segs, axis='Y')
    p.add_bm(rb_, "trim"); rb_.free()
    hub = bm_rbox((0.12, 0.05, 0.1), 0.03, 2 if lod == 0 else 1, (0, 0.0, 0))
    p.add_bm(hub, "trim"); hub.free()
    for a in (math.radians(-90), math.radians(20), math.radians(160)):
        sp = bm_tube((math.cos(a) * 0.05, 0.0, math.sin(a) * 0.05), (math.cos(a) * rim_r, 0.0, math.sin(a) * rim_r), 0.012, 6)
        p.add_bm(sp, "trim"); sp.free()
    rot = Matrix.Rotation(-math.radians(tilt_deg), 4, 'X')
    bmesh.ops.transform(p.bm, matrix=Matrix.Translation(V(centre)) @ rot, verts=p.bm.verts)
    parts.append(p)
    ax = (Matrix.Rotation(-math.radians(tilt_deg), 3, 'X') @ V((0, -1, 0))).normalized()
    col = bm_tube(V(centre) + ax * 0.03, V(centre) - ax * col_len, 0.03, 8)
    _add(parts, "dash", "body", col, "dash")
    return V(centre), ax


def bus_cabin(parts, s, cfg, lod):
    """A bus saloon: floor, walls (gap at the door), headliner, rows of double seats either side of the aisle, a driver's
    seat, dash and a big, nearly flat steering wheel on the left."""
    zf = cfg.get("z_floor", 0.4)
    d0, d1 = cfg["d_dash"], cfg["d_end"]
    door = cfg.get("door", (0.3, 1.45))
    W2 = s.W * 0.5 - 0.09
    zt = s.H - 0.14
    zb = cfg.get("z_belt", 1.12)
    y = lambda d: s.L * 0.5 - d
    # floor and headliner
    for (z, up) in ((zf, True), (zt, False)):
        bm = bmesh.new()
        v = [bm.verts.new((-W2, y(d0), z)), bm.verts.new((W2, y(d0), z)), bm.verts.new((W2, y(d1), z)), bm.verts.new((-W2, y(d1), z))]
        f = bm.faces.new(v); f.normal_update()
        if (f.normal.z > 0) != up:
            f.normal_flip()
        _add(parts, "cabin", "body", bm, "trim" if up else "interior")
    # walls below the windows
    for sx in (1, -1):
        spans = [(d0, d1)] if sx < 0 else [(d0, door[0]), (door[1], d1)]
        for (a, b) in spans:
            if b - a < 0.05:
                continue
            bm = bmesh.new()
            v = [bm.verts.new((sx * W2, y(a), zf)), bm.verts.new((sx * W2, y(a), zb)), bm.verts.new((sx * W2, y(b), zb)), bm.verts.new((sx * W2, y(b), zf))]
            f = bm.faces.new(v); f.normal_update()
            if f.normal.x * sx > 0:
                f.normal_flip()
            _add(parts, "cabin", "body", bm, "interior")
    # rear bulkhead
    bm = bmesh.new()
    v = [bm.verts.new((-W2, y(d1), zf)), bm.verts.new((W2, y(d1), zf)), bm.verts.new((W2, y(d1), zt)), bm.verts.new((-W2, y(d1), zt))]
    f = bm.faces.new(v); f.normal_update()
    if f.normal.y < 0:
        f.normal_flip()
    _add(parts, "cabin", "body", bm, "interior")
    # seat rows
    pitch = cfg.get("pitch", 0.8)
    d = cfg.get("d_seats", door[1] + 0.35)
    k = 0
    while d < d1 - 0.5:
        for sx in (1, -1):
            seat(parts, sx * (W2 - 0.48), y(d), zf, lod if lod == 0 and k < 6 else 1, w=0.86, bench=True, height=0.38, back_h=0.62,
                 recline=12, head=False)
        d += pitch
        k += 1
    # driver: seat, dash, wheel
    dx = -W2 + 0.45
    seat(parts, dx, y(d0 + 0.95), zf, lod, w=0.5, height=0.42)
    dash = bm_rbox((0.9, 0.35, 0.35), 0.05, 1, (dx + 0.05, y(d0 + 0.2), zb - 0.05))
    _add(parts, "dash", "body", dash, "dash")
    return steering_wheel(parts, (dx, y(d0 + 0.5), zb + 0.05), 55.0, lod, rim_r=0.24, col_len=0.5)


def cabin(parts, s, cfg, lod):
    """The whole interior for a car body. cfg: z_floor, d_dash (screen base), d_front_seat, d_rear_seat (or None),
    d_end (rear of cabin / load floor), shelf (z of the parcel shelf or None), doors (ranges for door cards)."""
    zf = cfg.get("z_floor", 0.30)
    d_ws = cfg["d_dash"]
    tub(parts, s, d_ws + 0.1, cfg["d_end"], zf, cfg.get("doors", []), lod)
    wc, ax = dashboard(parts, s, d_ws, zf, lod)
    P = section(s, cfg["d_front_seat"])
    w_in = P[R_BELT][0] - 0.08
    yfs = s.L * 0.5 - cfg["d_front_seat"]
    for sx in (-1, 1):
        seat(parts, sx * w_in * 0.47, yfs, zf, lod, w=min(0.52, w_in * 0.75))
    if cfg.get("d_rear_seat"):
        P = section(s, cfg["d_rear_seat"])
        w_in = P[R_BELT][0] - 0.08
        seat(parts, 0.0, s.L * 0.5 - cfg["d_rear_seat"], zf, lod, w=w_in * 1.85, bench=True, height=0.32, back_h=0.56, recline=24)
    if cfg.get("shelf") is not None:
        d0 = cfg.get("shelf_d0", cfg["d_rear_seat"] + 0.3 if cfg.get("d_rear_seat") else cfg["d_end"] - 0.6)
        d1 = cfg["d_end"]
        P0 = section(s, d0); P1 = section(s, d1)
        z = cfg["shelf"]
        bm = bmesh.new()
        x0 = P0[R_BELT][0] - 0.09; x1 = P1[R_BELT][0] - 0.12
        y0 = s.L * 0.5 - d0; y1 = s.L * 0.5 - d1
        v = [bm.verts.new((-x0, y0, z)), bm.verts.new((x0, y0, z)), bm.verts.new((x1, y1, z)), bm.verts.new((-x1, y1, z))]
        f = bm.faces.new(v)
        f.normal_update()
        if f.normal.z < 0:
            f.normal_flip()
        _add(parts, "cabin", "body", bm, "interior")
    # rear bulkhead behind the cabin (closes the view into the body)
    d1 = cfg["d_end"]
    P1 = section(s, d1)
    y1 = s.L * 0.5 - d1
    x1 = P1[R_BELT][0] - 0.07
    zt = P1[R_TOP][1] - 0.06
    bm = bmesh.new()
    v = [bm.verts.new((-x1, y1, zf)), bm.verts.new((x1, y1, zf)), bm.verts.new((x1, y1, zt)), bm.verts.new((-x1, y1, zt))]
    f = bm.faces.new(v)
    f.normal_update()
    if f.normal.y < 0:
        f.normal_flip()
    _add(parts, "cabin", "body", bm, "interior")
    return wc, ax

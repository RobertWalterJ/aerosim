# AeroSim vehicle kit: the farm tractors in detail (second pass, at the owner's request).
# tractor_a: a 1990s four-post-cab utility tractor of about 100 hp (the class of a mid-size row-crop tractor: about 4.6 m long,
# 2.4 m wide, 2.95 m to the cab roof, 2.6 m wheelbase, 18.4R38 rears and 14.9R28 fronts). Studied from general references of
# that class (manufacturer spec sheets and farm-show photographs, for proportions only; no make, badge or livery copied).
# parade_tractor_a: a 1950s open utility tractor (about 3.2 m long, 1.75 m wide, 11-28 rears, 6.00-16 fronts, narrow front
# track), restored in red with cream wheels, as driven in a village festival.
# Everything is fictional: the marque is HALDEN (modern) and TAMSIN (vintage).
import math
import bmesh
from mathutils import Vector as V, Matrix
from vk_core import Part, bm_rbox, bm_box, bm_cyl, bm_tube, bm_sweep, bm_lathe, text_bm
from vk_recipes import tyre
import vk_wheels
import vk_interior as inter


def _add(parts, name, bone, bm, mat):
    for q in parts:
        if q.name == name and q.bone == bone:
            q.add_bm(bm, mat); bm.free(); return
    p = Part(name, bone)
    p.add_bm(bm, mat)
    parts.append(p)
    bm.free()


def box(parts, name, bone, size, c, mat, r=0.0, seg=1):
    _add(parts, name, bone, bm_rbox(size, r, seg, c) if r > 0 else bm_box(size, c), mat)


def tube(parts, name, bone, a, b, r, mat, segs=8):
    _add(parts, name, bone, bm_tube(a, b, r, segs), mat)


def text_plane(parts, name, bone, txt, size, origin, right, up, mat, extrude=0.002):
    """Lettering as real glyph geometry on a plane (reads left to right along `right`, upright along `up`)."""
    bm = text_bm(txt, size, extrude)
    o, r, u = V(origin), V(right).normalized(), V(up).normalized()
    n = r.cross(u)
    for v in bm.verts:
        v.co = o + r * v.co.x + u * v.co.y + n * (v.co.z + extrude)
    bm.normal_update()
    _add(parts, name, bone, bm, mat)


def cylinder_ram(parts, name, bone_a, bone_b, a, b, r_body, r_rod, lod):
    """A hydraulic ram: the barrel on one part, the chrome rod on the other (so it can slide when the parts move)."""
    a, b = V(a), V(b)
    m = a.lerp(b, 0.58)
    tube(parts, name, bone_a, a, m, r_body, "paint2" if False else "trim", 12 if lod == 0 else 6)
    tube(parts, name, bone_b, m - (b - a).normalized() * 0.12, b, r_rod, "chrome", 10 if lod == 0 else 5)
    for p, bn in ((a, bone_a), (b, bone_b)):
        _add(parts, name, bn, bm_cyl(r_body * 1.15, r_body * 1.15, 0.06, 10 if lod == 0 else 6, 'X', tuple(p)), "metal")


def perforated_panel(parts, name, bone, x, y0, y1, z0, z1, n, mat_bar, mat_back, side):
    """A side grille: a dark backing and n horizontal louvres standing proud of it."""
    box(parts, name, bone, (0.012, y1 - y0, z1 - z0), (x, (y0 + y1) * 0.5, (z0 + z1) * 0.5), mat_back)
    for k in range(n):
        z = z0 + (z1 - z0) * (k + 0.5) / n
        bm = bm_box((0.02, y1 - y0 - 0.02, 0.012), (x + side * 0.008, (y0 + y1) * 0.5, z))
        bmesh.ops.transform(bm, matrix=Matrix.Translation((x + side * 0.008, (y0 + y1) * 0.5, z)) @ Matrix.Rotation(side * 0.5, 4, 'Y') @
                            Matrix.Translation((-(x + side * 0.008), -(y0 + y1) * 0.5, -z)), verts=bm.verts)
        _add(parts, name, bone, bm, mat_bar)


def mudguard(parts, name, bone, centre, radius, width, a0, a1, mat, lod, lip=0.035, flat_top=0.0):
    """A sheet-metal mudguard over a wheel: angles from +Y (front) over the top; rolled edges both sides."""
    n = 22 if lod == 0 else 9
    path = []
    for k in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * k / n)
        rr = radius + flat_top * max(0.0, math.sin(a) - 0.85)
        path.append((centre[0], centre[1] + math.cos(a) * rr, centre[2] + math.sin(a) * rr))
    w = width * 0.5
    sec = [(-w, -0.006), (w, -0.006), (w, lip), (w - 0.018, lip), (w - 0.018, 0.0), (-w + 0.018, 0.0), (-w + 0.018, lip), (-w, lip)]
    _add(parts, name, bone, bm_sweep(sec, path, True, up=(1, 0, 0)), mat)


def wheel(parts, info, spec, side, lod, nm, hub, steer):
    vk_wheels.build_wheel(spec, side, lod, nm, hub, steer, parts=parts)
    info["hubs"].append((nm, hub, steer))


# ============================================================================================ tractor_a (modern, cab)
def tractor_parts(rc, lod, wheels_only=False):
    parts = []
    info = {"spec": None, "hubs": [], "wipers": [], "steering": None, "bones": [], "hinges": {}, "body_z": 1.0}
    seg = 2 if lod == 0 else 1
    yr, yf = -1.02, 1.58
    RR, RF = tyre(467, 85, 38), tyre(378, 85, 28)       # 18.4R38 and 14.9R28 (section width in mm, 85 % aspect)
    rspec = {"R": RR[0], "Rr": RR[1], "tw": 0.467, "style": "steel", "holes": 0, "tyre": "tractor", "lugs": 23, "lug_h": 0.055,
             "face_mat": "paint2", "barrel_mat": "paint2", "nuts": 10, "pcd": 0.21, "nut_r": 0.017, "hubcap": True, "cap_r": 0.13,
             "disc": False, "segs": 40, "sidewall": "HARROWFIELD 18.4R38"}
    fspec = {"R": RF[0], "Rr": RF[1], "tw": 0.378, "style": "steel", "holes": 0, "tyre": "tractor", "lugs": 19, "lug_h": 0.045,
             "face_mat": "paint2", "barrel_mat": "paint2", "nuts": 8, "pcd": 0.15, "nut_r": 0.015, "hubcap": True, "cap_r": 0.1,
             "disc": False, "segs": 36, "sidewall": "HARROWFIELD 14.9R28"}
    xr = 1.2 - 0.467 * 0.5
    xf = 1.06 - 0.378 * 0.5
    for side, sn in ((-1, "l"), (1, "r")):
        wheel(parts, info, rspec, side, lod, "r" + sn, (side * xr, yr, rspec["R"]), False)
        wheel(parts, info, fspec, side, lod, "f" + sn, (side * xf, yf, fspec["R"]), True)
    if wheels_only:
        return parts, info
    P, P2 = "paint", "paint2"
    # ---------------------------------------------------------------- engine, frame and the bonnet
    box(parts, "frame", "body", (0.62, 2.3, 0.36), (0, 1.0, 0.86), "trim", 0.03)              # engine block and sump
    box(parts, "frame", "body", (0.5, 0.5, 0.4), (0, 0.15, 0.95), "metal", 0.03)              # bell housing
    for sx in (1, -1):
        box(parts, "frame", "body", (0.06, 1.9, 0.14), (sx * 0.27, 1.2, 0.66), "trim")          # front frame rails
    hood_y0, hood_y1 = 0.18, 2.08
    hood = bm_rbox((0.86, hood_y1 - hood_y0, 0.6), 0.1, seg + 1, (0, (hood_y0 + hood_y1) * 0.5, 1.33))
    for v in hood.verts:
        t = max(0.0, (v.co.y - 0.7) / 1.4)
        if v.co.z > 1.2:
            v.co.z -= 0.13 * t * t                       # the bonnet slopes down to the nose
        v.co.x *= 1.0 - 0.06 * t                         # and narrows a little
    _add(parts, "hood", "body", hood, P)
    # the black lower side panels with perforated louvres, the white stripe and the model lettering
    for sx in (1, -1):
        perforated_panel(parts, "hood", "body", sx * 0.435, 0.95, 1.95, 1.06, 1.32, 7, "trim", "trim_grey", sx)
        box(parts, "hood", "body", (0.012, 1.7, 0.035), (sx * 0.44, 1.1, 1.42), "sheet_white")
        if lod <= 1:
            yy = 0.55
            r = V((0, 1, 0)) if sx > 0 else V((0, -1, 0))   # read from outside: +y is the viewer's right on the +x side
            text_plane(parts, "badges", "body", "HALDEN", 0.11, (sx * 0.447, yy, 1.5),
                       r, (0, 0, 1), "sheet_white")
            text_plane(parts, "badges", "body", "6140", 0.08, (sx * 0.447, 1.65, 1.2),
                       r, (0, 0, 1), "sheet_white")
    # the grille: frame, black mesh, horizontal bars, the two headlamps set in it, a badge plate on the nose
    box(parts, "grille", "body", (0.74, 0.07, 0.52), (0, 2.13, 1.25), P, 0.04, seg)
    box(parts, "grille", "body", (0.62, 0.02, 0.36), (0, 2.17, 1.2), "trim")
    if lod <= 1:
        for k in range(9):
            box(parts, "grille", "body", (0.6, 0.025, 0.012), (0, 2.185, 1.04 + k * 0.04), "trim_grey")
        for k in range(5):
            box(parts, "grille", "body", (0.012, 0.025, 0.34), (-0.24 + k * 0.12, 2.188, 1.2), "trim_grey")
    for sx in (1, -1):
        box(parts, "lamps", "body", (0.17, 0.04, 0.08), (sx * 0.22, 2.175, 1.43), "trim", 0.01)
        box(parts, "lamps", "body", (0.14, 0.012, 0.06), (sx * 0.22, 2.197, 1.43), "lamp_reflector")
        box(parts, "lamps", "body", (0.15, 0.006, 0.07), (sx * 0.22, 2.205, 1.43), "lamp_front")
    box(parts, "grille", "body", (0.3, 0.012, 0.05), (0, 2.18, 1.55), "chrome")
    if lod == 0:
        text_plane(parts, "badges", "body", "HALDEN", 0.04, (0.0, 2.188, 1.535), (-1, 0, 0), (0, 0, 1), "trim")
    # front weight carrier with eight suitcase weights and their handles; front tow pin
    box(parts, "weights", "body", (0.78, 0.22, 0.3), (0, 2.25, 0.8), "trim", 0.02)
    for k in range(8):
        x = -0.35 + k * 0.1
        box(parts, "weights", "body", (0.085, 0.3, 0.42), (x, 2.42, 0.82), "trim_grey" if k % 2 else "metal", 0.012)
        if lod == 0:
            tube(parts, "weights", "body", (x, 2.56, 1.0), (x, 2.6, 1.07), 0.012, "metal", 5)
    tube(parts, "weights", "body", (-0.12, 2.25, 0.62), (0.12, 2.25, 0.62), 0.03, "metal")
    # front axle: beam, pivot, steering ram and track rod, the hub reduction housings
    tube(parts, "axle", "body", (-xf + 0.16, yf, fspec["R"]), (xf - 0.16, yf, fspec["R"]), 0.075, "trim", 12)
    box(parts, "axle", "body", (0.26, 0.3, 0.24), (0, yf, fspec["R"] + 0.05), "trim", 0.03)
    if lod <= 1:
        cylinder_ram(parts, "axle", "body", "body", (-0.45, yf - 0.16, fspec["R"] + 0.06), (0.4, yf - 0.16, fspec["R"] + 0.06), 0.04, 0.02, lod)
    for sx, sn in ((1, "r"), (-1, "l")):
        _add(parts, "axle", "steer_f" + sn, bm_cyl(0.13, 0.1, 0.16, 14 if lod == 0 else 8, 'X', (sx * (xf - 0.1), yf, fspec["R"])), "trim")
        # front mudguards: they turn with the wheels
        mudguard(parts, "guards", "steer_f" + sn, (sx * xf, yf, fspec["R"]), fspec["R"] + 0.07, 0.46, 25, 155, P, lod)
        tube(parts, "guards", "steer_f" + sn, (sx * (xf - 0.25), yf - 0.05, fspec["R"] + 0.05), (sx * (xf - 0.25), yf - 0.05, fspec["R"] * 2 + 0.03), 0.018, "trim")
        box(parts, "lamps", "steer_f" + sn, (0.06, 0.035, 0.05), (sx * (xf + 0.18), yf + 0.18, fspec["R"] * 2 + 0.08), "lamp_ind_r" if sx > 0 else "lamp_ind_l")
    # ---------------------------------------------------------------- transmission, rear axle, fenders
    box(parts, "trans", "body", (0.62, 1.0, 0.62), (0, yr + 0.35, 0.92), "trim", 0.06, seg)
    box(parts, "trans", "body", (0.78, 0.72, 0.66), (0, yr + 0.03, rspec["R"] + 0.04), "trim", 0.08, seg)
    for sx in (1, -1):
        tube(parts, "trans", "body", (sx * 0.35, yr, rspec["R"]), (sx * (xr - 0.17), yr, rspec["R"]), 0.11, "trim", 14 if lod == 0 else 8)
        _add(parts, "trans", "body", bm_cyl(0.16, 0.12, 0.12, 14 if lod == 0 else 8, 'X', (sx * (xr - 0.2), yr, rspec["R"])), "trim")
    cz0, cz1 = 1.30, 2.86
    cy0, cy1 = -1.6, 0.22
    cx = 0.78
    for sx, sn in ((1, "r"), (-1, "l")):
        mudguard(parts, "guards", "body", (sx * xr, yr, rspec["R"]), rspec["R"] + 0.08, 0.64, 4, 176, P, lod, flat_top=0.06)
        # mud flap at the back, the lamp cluster and the reflector on the fender
        box(parts, "guards", "body", (0.5, 0.012, 0.32), (sx * xr, yr - rspec["R"] - 0.04, 0.42), "rubber")
        box(parts, "lamps", "body", (0.17, 0.05, 0.16), (sx * (xr + 0.13), yr - rspec["R"] - 0.02, 1.05), "trim", 0.01)
        for k, (m, zz) in enumerate((("lamp_tail", 1.1), ("lamp_brake", 1.05), ("lamp_ind_r" if sx > 0 else "lamp_ind_l", 1.0))):
            box(parts, "lamps", "body", (0.14, 0.012, 0.04), (sx * (xr + 0.13), yr - rspec["R"] - 0.05, zz), m)
        box(parts, "lamps", "body", (0.07, 0.01, 0.07), (sx * (xr + 0.13), yr - rspec["R"] - 0.05, 0.9), "lamp_tail")
    # ---------------------------------------------------------------- the cab
    box(parts, "cab", "body", (cx * 2 + 0.06, cy1 - cy0 + 0.04, 0.1), (0, (cy0 + cy1) * 0.5, cz0), "trim", 0.02)        # floor
    box(parts, "cab", "body", (cx * 2 + 0.04, 0.08, 0.46), (0, cy1 - 0.02, cz0 + 0.23), P, 0.02)                     # lower front panel
    for sx in (1, -1):
        for yy in (cy0 + 0.04, cy1):
            box(parts, "cab", "body", (0.07, 0.07, cz1 - cz0), (sx * cx, yy, (cz0 + cz1) * 0.5), "trim", 0.025, seg)
        # the inner wheel arch humps
        _add(parts, "cab", "body", bm_rbox((0.42, 1.1, 0.42), 0.12, seg, (sx * (cx - 0.21), yr + 0.05, cz0 + 0.14)), "interior")
    roof = bm_rbox((cx * 2 + 0.26, cy1 - cy0 + 0.34, 0.17), 0.07, seg + 1, (0, (cy0 + cy1) * 0.5 + 0.03, cz1 + 0.07))
    _add(parts, "cab", "body", roof, "sheet_white")
    box(parts, "cab", "body", (cx * 2 + 0.1, cy1 - cy0 + 0.2, 0.02), (0, (cy0 + cy1) * 0.5, cz1 - 0.02), "trim")           # gutter line
    box(parts, "cab", "body", (0.6, 0.6, 0.04), (0, (cy0 + cy1) * 0.5 - 0.1, cz1 + 0.17), "trim", 0.02)                # roof hatch
    box(parts, "cab", "body", (cx * 2 - 0.1, cy1 - cy0 - 0.08, 0.012), (0, (cy0 + cy1) * 0.5, cz1 - 0.03), "interior")    # headliner (thin)
    # glass: windscreen, the right side, the rear window (the left side is the door)
    box(parts, "glass", "body", (cx * 2 - 0.06, 0.012, cz1 - cz0 - 0.55), (0, cy1 + 0.015, cz0 + 0.46 + (cz1 - cz0 - 0.55) * 0.5), "glass")
    box(parts, "glass", "body", (cx * 2 - 0.06, 0.012, cz1 - cz0 - 0.12), (0, cy0 + 0.01, (cz0 + cz1) * 0.5 + 0.04), "glass")
    box(parts, "glass", "body", (0.012, cy1 - cy0 - 0.1, cz1 - cz0 - 0.62), (cx + 0.015, (cy0 + cy1) * 0.5, cz0 + 0.56 + (cz1 - cz0 - 0.62) * 0.5), "glass")
    box(parts, "glass", "body", (0.03, cy1 - cy0 - 0.08, 0.5), (cx + 0.01, (cy0 + cy1) * 0.5, cz0 + 0.27), P, 0.01)        # right lower panel
    # the door: full glass in a black frame, handle, hinged on the rear post (opens forward)
    dz0 = cz0 + 0.1
    box(parts, "door", "door_fl", (0.012, cy1 - cy0 - 0.12, cz1 - dz0 - 0.08), (-cx - 0.02, (cy0 + cy1) * 0.5, (dz0 + cz1) * 0.5 - 0.02), "glass")
    for zz in (dz0, cz1 - 0.06):
        box(parts, "door", "door_fl", (0.035, cy1 - cy0 - 0.08, 0.045), (-cx - 0.025, (cy0 + cy1) * 0.5, zz), "trim")
    for yy in (cy0 + 0.1, cy1 - 0.06):
        box(parts, "door", "door_fl", (0.035, 0.045, cz1 - dz0 - 0.06), (-cx - 0.025, yy, (dz0 + cz1) * 0.5 - 0.02), "trim")
    box(parts, "door", "door_fl", (0.05, 0.16, 0.035), (-cx - 0.06, cy1 - 0.2, 1.95), "chrome", 0.01)
    info["bones"].append({"name": "door_fl", "head": (-cx, cy0 + 0.06, 2.05), "tail": (-cx, cy0 + 0.06, 2.35), "parent": "body"})
    info["hinges"]["door_fl"] = (-1, True, 85.0)
    # steps up to the door, with tread plate edges
    for k, zz in enumerate((0.5, 0.82, 1.12)):
        box(parts, "steps", "body", (0.3, 0.36, 0.03), (-cx - 0.12, -0.25, zz), "metal")
        box(parts, "steps", "body", (0.3, 0.02, 0.06), (-cx - 0.12, -0.07, zz + 0.015), "trim")
    for yy in (-0.43, -0.07):
        tube(parts, "steps", "body", (-cx - 0.27, yy, 0.45), (-cx - 0.27, yy, 1.2), 0.015, "trim")
    tube(parts, "steps", "body", (-cx - 0.05, cy1 + 0.02, 1.4), (-cx - 0.05, cy1 + 0.02, 2.35), 0.016, "chrome")             # grab handle
    # exhaust stack with its perforated heat shield and rain cap; the air pre-cleaner on the left post
    ex_x, ex_y = 0.55, 0.36
    tube(parts, "exhaust", "body", (ex_x, ex_y, 1.55), (ex_x, ex_y, 3.05), 0.052, "metal", 14 if lod == 0 else 8)
    _add(parts, "exhaust", "body", bm_cyl(0.075, 0.075, 0.9, 16 if lod == 0 else 8, 'Z', (ex_x, ex_y, 2.15)), "trim")
    if lod == 0:
        for k in range(10):
            for j in range(8):
                a = j * math.pi / 4 + (k % 2) * 0.39
                box(parts, "exhaust", "body", (0.02, 0.02, 0.03), (ex_x + math.cos(a) * 0.075, ex_y + math.sin(a) * 0.075, 1.75 + k * 0.08), "metal")
    cap = bm_cyl(0.06, 0.06, 0.01, 14, 'Z', (0, 0, 0))
    bmesh.ops.transform(cap, matrix=Matrix.Translation((ex_x, ex_y - 0.03, 3.08)) @ Matrix.Rotation(-0.35, 4, 'X'), verts=cap.verts)
    _add(parts, "exhaust", "body", cap, "metal")
    _add(parts, "exhaust", "body", bm_cyl(0.075, 0.075, 0.6, 14 if lod == 0 else 8, 'Z', (-0.55, ex_y, 2.2)), "trim")
    _add(parts, "exhaust", "body", bm_cyl(0.09, 0.075, 0.12, 14 if lod == 0 else 8, 'Z', (-0.55, ex_y, 2.56)), "trim_grey")
    # roof: amber beacon, four front work lamps, two rear, mirrors on long arms, a whip aerial, the slow-moving-vehicle sign
    _add(parts, "roofgear", "body", bm_cyl(0.07, 0.07, 0.04, 14, 'Z', (0.5, -1.2, cz1 + 0.17)), "trim")
    _add(parts, "roofgear", "body", bm_cyl(0.065, 0.055, 0.14, 14 if lod == 0 else 8, 'Z', (0.5, -1.2, cz1 + 0.26)), "lamp_beacon")
    for sx in (1, -1):
        for xx in (0.25, 0.62):
            box(parts, "lamps", "body", (0.13, 0.09, 0.09), (sx * xx, cy1 + 0.16, cz1 + 0.04), "trim", 0.015)
            box(parts, "lamps", "body", (0.11, 0.008, 0.07), (sx * xx, cy1 + 0.205, cz1 + 0.04), "lamp_reflector")
        box(parts, "lamps", "body", (0.13, 0.09, 0.09), (sx * 0.5, cy0 - 0.15, cz1 + 0.04), "trim", 0.015)
        box(parts, "lamps", "body", (0.11, 0.008, 0.07), (sx * 0.5, cy0 - 0.195, cz1 + 0.04), "lamp_reflector")
        tube(parts, "mirrors", "body", (sx * cx, cy1 - 0.02, 2.55), (sx * (cx + 0.42), cy1 + 0.1, 2.62), 0.014, "trim")
        tube(parts, "mirrors", "body", (sx * cx, cy1 - 0.02, 2.2), (sx * (cx + 0.38), cy1 + 0.1, 2.5), 0.012, "trim")
        box(parts, "mirrors", "body", (0.05, 0.18, 0.3), (sx * (cx + 0.43), cy1 + 0.1, 2.5), "trim", 0.015)
        box(parts, "mirrors", "body", (0.008, 0.16, 0.27), (sx * (cx + 0.43), cy1 + 0.07, 2.5), "mirror")
    tube(parts, "roofgear", "body", (-0.6, -1.4, cz1 + 0.15), (-0.62, -1.5, cz1 + 1.1), 0.004, "trim", 5)
    smv = bmesh.new()
    vs = [smv.verts.new((0.0 - 0.18, cy0 - 0.06, 2.0)), smv.verts.new((0.18, cy0 - 0.06, 2.0)), smv.verts.new((0.0, cy0 - 0.06, 2.31))]
    smv.faces.new([vs[1], vs[0], vs[2]])
    _add(parts, "roofgear", "body", smv, "lamp_beacon")
    # ---------------------------------------------------------------- inside the cab
    if lod <= 1:
        inter.seat(parts, 0.0, -0.78, cz0 + 0.06, lod, w=0.52, height=0.42, back_h=0.62)
        box(parts, "seats", "body", (0.08, 0.36, 0.06), (0.32, -0.75, cz0 + 0.68), "seat", 0.02)                # armrest
        box(parts, "console", "body", (0.26, 0.6, 0.55), (0.52, -0.82, cz0 + 0.3), "dash", 0.03)               # right console
        if lod == 0:
            for k in range(4):
                tube(parts, "console", "body", (0.45 + k * 0.045, -0.7, cz0 + 0.57), (0.45 + k * 0.045, -0.62, cz0 + 0.78), 0.01, "trim", 5)
                _add(parts, "console", "body", bm_rbox((0.03, 0.03, 0.04), 0.012, 1, (0.45 + k * 0.045, -0.62, cz0 + 0.8)), "lamp_tail" if k == 3 else "trim")
            _add(parts, "console", "body", bm_rbox((0.05, 0.06, 0.1), 0.02, 2, (0.6, -0.55, cz0 + 0.65)), "trim")      # joystick
        box(parts, "console", "body", (0.5, 0.34, 0.5), (0.0, -0.08, cz0 + 0.3), "dash", 0.04)                # dash pod and column cover
        box(parts, "console", "body", (0.3, 0.02, 0.12), (0.0, -0.25, cz0 + 0.56), "glass_tint")             # instrument face
        for sx in (-0.12, 0.0, 0.14):
            box(parts, "console", "body", (0.07, 0.12, 0.02), (sx, -0.28, cz0 + 0.07), "trim")               # pedals
        info["steering"] = inter.steering_wheel(parts, (0.0, -0.36, cz0 + 0.86), 38.0, lod, rim_r=0.2, col_len=0.55)
        box(parts, "seats", "body", (0.36, 0.3, 0.06), (-0.55, -0.6, cz0 + 0.42), "seat", 0.03)              # buddy seat
    # ---------------------------------------------------------------- three-point linkage, PTO, couplers, drawbar
    lz = 0.62
    for sx in (1, -1):
        # lower links from the axle housing to the ball ends, lift arms on the top, lift rods between them
        tube(parts, "linkage", "body", (sx * 0.28, yr - 0.15, 0.55), (sx * 0.43, -2.3, lz - 0.08), 0.032, "trim", 8)
        _add(parts, "linkage", "body", bm_cyl(0.05, 0.05, 0.06, 10, 'X', (sx * 0.43, -2.31, lz - 0.08)), "metal")
        tube(parts, "linkage", "body", (sx * 0.24, yr - 0.15, 1.28), (sx * 0.32, -1.85, 1.2), 0.035, "trim", 8)
        tube(parts, "linkage", "body", (sx * 0.32, -1.85, 1.2), (sx * 0.39, -1.95, lz - 0.02), 0.022, "paint2" if False else "metal", 8)
        if lod <= 1:
            cylinder_ram(parts, "linkage", "body", "body", (sx * 0.4, yr - 0.4, 0.55), (sx * 0.33, -1.7, 1.18), 0.045, 0.024, lod)
        # stabiliser chains
        tube(parts, "linkage", "body", (sx * 0.45, yr - 0.3, 0.5), (sx * 0.45, -1.9, lz - 0.05), 0.012, "metal", 5)
    tube(parts, "linkage", "body", (0, yr - 0.5, 1.22), (0, -2.15, 1.0), 0.04, P2, 8)                          # top link
    if lod == 0:
        _add(parts, "linkage", "body", bm_cyl(0.05, 0.05, 0.2, 6, 'Y', (0, -1.82, 1.13)), "metal")             # its turnbuckle
    _add(parts, "pto", "pto", bm_cyl(0.035, 0.035, 0.24, 12, 'Y', (0, -1.72, 0.72)), "metal")
    if lod == 0:
        for k in range(6):
            a = k * math.pi / 3
            box(parts, "pto", "pto", (0.012, 0.2, 0.012), (math.cos(a) * 0.037, -1.74, 0.72 + math.sin(a) * 0.037), "metal")
    guard = bm_lathe([(0.11, 0.0), (0.11, 0.18)], 14, axis='Y', a0=0.0, a1=math.pi, closed=False)[0]
    bmesh.ops.transform(guard, matrix=Matrix.Translation((0, -1.78, 0.72)), verts=guard.verts)
    _add(parts, "linkage", "body", guard, P2)
    info["bones"].append({"name": "pto", "head": (0, -1.6, 0.72), "tail": (0, -1.9, 0.72), "parent": "body"})
    for k, m in enumerate(("flag_a", "flag_c", "flag_a", "flag_c", "trim", "trim")):
        x = -0.32 + k * 0.13
        _add(parts, "couplers", "body", bm_cyl(0.022, 0.022, 0.07, 10, 'Y', (x, -1.62, 1.42)), "metal")
        _add(parts, "couplers", "body", bm_cyl(0.025, 0.025, 0.03, 10, 'Y', (x, -1.67, 1.42)), m)
    box(parts, "couplers", "body", (0.85, 0.05, 0.12), (0, -1.58, 1.42), "trim")
    box(parts, "linkage", "body", (0.12, 0.6, 0.06), (0, -1.9, 0.42), "metal")                                   # swinging drawbar
    _add(parts, "linkage", "body", bm_cyl(0.025, 0.025, 0.14, 8, 'Z', (0, -2.15, 0.45)), "chrome")
    info["bones"].append({"name": "hitch", "head": (0, -2.18, 0.45), "tail": (0, -2.18, 0.75), "parent": "root"})
    info["pto"] = True
    # windscreen wiper (its own bone, sweeping)
    wz = cz0 + 0.5
    _add(parts, "wiper", "wiper_f", bm_tube((0.0, cy1 + 0.035, wz), (-0.62, cy1 + 0.035, wz + 0.42), 0.008, 5), "trim")
    _add(parts, "wiper", "wiper_f", bm_box((0.012, 0.012, 0.55), (-0.45, cy1 + 0.04, wz + 0.35)), "rubber")
    info["bones"].append({"name": "wiper_f", "head": (0.0, cy1 + 0.035, wz), "tail": (0.0, cy1 + 0.2, wz), "parent": "body"})
    info["wipers"] = [("wiper_f", (0.0, cy1 + 0.035, wz), (0, 1, 0))]
    return parts, info


def tractor_condition(co, n):
    """Field-worn: dirt and wear low down, clean high up."""
    low = max(0.0, 1.0 - co.z / 1.1)
    return max(0.25, 1.0 - 0.55 * low - 0.1 * (0.5 + 0.5 * math.sin(co.x * 9 + co.y * 5)))


# ========================================================================================== parade_tractor_a (1950s)
def parade_tractor_parts(rc, lod):
    parts = []
    info = {"spec": None, "hubs": [], "wipers": [], "steering": None, "bones": [], "hinges": {}, "body_z": 0.8}
    seg = 2 if lod == 0 else 1
    yr, yf = -0.78, 1.12
    rspec = {"R": 0.655, "Rr": 0.356, "tw": 0.28, "style": "steel", "holes": 0, "tyre": "tractor", "lugs": 18, "lug_h": 0.05,
             "face_mat": "paint2", "barrel_mat": "paint2", "nuts": 8, "pcd": 0.17, "nut_r": 0.016, "hubcap": True, "cap_r": 0.09,
             "disc": False, "segs": 40, "sidewall": "TRACTION KING 11-28"}
    fspec = {"R": 0.36, "Rr": 0.203, "tw": 0.15, "style": "steel", "holes": 0, "face_mat": "paint2", "barrel_mat": "paint2", "nuts": 5,
             "pcd": 0.07, "nut_r": 0.012, "hubcap": True, "cap_r": 0.065, "disc": False, "segs": 32, "tyre": "rib"}
    xr, xf = 0.66, 0.5
    for side, sn in ((-1, "l"), (1, "r")):
        wheel(parts, info, rspec, side, lod, "r" + sn, (side * xr, yr, rspec["R"]), False)
        wheel(parts, info, fspec, side, lod, "f" + sn, (side * xf, yf, fspec["R"]), True)
    P, P2 = "paint", "paint2"
    # the engine and its block, the curved bonnet (a half round top on straight sides), the radiator shell
    box(parts, "engine", "body", (0.42, 1.1, 0.42), (0, 0.55, 0.72), "trim", 0.04)
    if lod <= 1:
        for k in range(4):
            _add(parts, "engine", "body", bm_cyl(0.05, 0.05, 0.12, 10, 'Z', (0.22, 0.25 + k * 0.17, 0.98)), "metal")       # spark plug bosses
        _add(parts, "engine", "body", bm_cyl(0.09, 0.09, 0.14, 12, 'X', (0.25, 0.6, 0.75)), "trim_grey")                 # generator
    n = 14 if lod == 0 else 7
    prof = [(0.27 * math.sin(math.pi * k / n) + 0.001, 0.27 * math.cos(math.pi * k / n)) for k in range(n + 1)]
    hood = bmesh.new()
    rows = []
    y0, y1 = -0.15, 1.18
    for yy in (y0, y1):
        row = []
        for (r_, zc) in [(0.27 * math.cos(math.pi * k / n), 0.27 * math.sin(math.pi * k / n)) for k in range(n + 1)]:
            row.append(hood.verts.new((r_, yy, 1.08 + zc)))
        row.insert(0, hood.verts.new((0.27, yy, 0.86)))
        row.append(hood.verts.new((-0.27, yy, 0.86)))
        rows.append(row)
    for j in range(len(rows[0]) - 1):
        f = hood.faces.new([rows[0][j], rows[0][j + 1], rows[1][j + 1], rows[1][j]])
        f.smooth = True
    hood.normal_update()
    for f in hood.faces:
        c = f.calc_center_median()
        if f.normal.dot(V((c.x, 0, c.z - 1.0))) < 0:
            f.normal_flip()
    _add(parts, "hood", "body", hood, P)
    # radiator shell: rounded, with vertical bars, the badge and the crank hole
    shell = bm_rbox((0.6, 0.14, 0.78), 0.14, seg + 1, (0, 1.22, 1.0))
    _add(parts, "hood", "body", shell, P)
    box(parts, "hood", "body", (0.46, 0.02, 0.56), (0, 1.29, 0.98), "trim")
    if lod <= 1:
        for k in range(11):
            box(parts, "hood", "body", (0.012, 0.03, 0.54), (-0.2 + k * 0.04, 1.3, 0.98), "chrome" if lod == 0 else "trim_grey")
    if lod <= 1:
        text_plane(parts, "badges", "body", "TAMSIN", 0.07, (0.0, 1.31, 1.33), (-1, 0, 0), (0, 0, 1), "chrome")
        for sx in (1, -1):
            r = V((0, 1, 0)) if sx > 0 else V((0, -1, 0))   # read from outside: +y is the viewer's right on the +x side
            text_plane(parts, "badges", "body", "TAMSIN", 0.09, (sx * 0.276, 0.5, 1.12), r, (0, 0, 1), P2)
            text_plane(parts, "badges", "body", "SERIES 2", 0.045, (sx * 0.276, 0.5, 1.02), r, (0, 0, 1), P2)
    _add(parts, "hood", "body", bm_cyl(0.03, 0.03, 0.05, 8, 'Y', (0, 1.31, 0.7)), "trim")
    # fuel tank under the cowl, filler cap, gauge; steering column, wheel, seat on its spring, footplates
    box(parts, "tank", "body", (0.5, 0.42, 0.24), (0, -0.25, 1.24), P, 0.08, seg)
    _add(parts, "tank", "body", bm_cyl(0.045, 0.045, 0.05, 12, 'Z', (0.1, -0.22, 1.39)), "chrome")
    _add(parts, "tank", "body", bm_cyl(0.035, 0.035, 0.012, 12, 'Y', (0.0, -0.47, 1.2)), "chrome")
    _add(parts, "tank", "body", bm_cyl(0.03, 0.03, 0.006, 12, 'Y', (0.0, -0.478, 1.2)), "glass_tint")
    if lod <= 1:
        info["steering"] = inter.steering_wheel(parts, (0.0, -0.62, 1.66), 28.0, lod, rim_r=0.21, col_len=0.95)
    box(parts, "seat", "body", (0.08, 0.5, 0.04), (0, -1.1, 0.96), "trim")
    tube(parts, "seat", "body", (0, -0.86, 0.95), (0, -1.22, 1.22), 0.035, "trim")
    pan = bm_rbox((0.44, 0.4, 0.07), 0.06, seg, (0, -1.24, 1.26))
    for v in pan.verts:
        d = abs(v.co.x) / 0.22
        v.co.z += 0.06 * d * d + 0.05 * max(0.0, (-1.24 - v.co.y) / 0.2)
    _add(parts, "seat", "body", pan, "chrome" if lod == 0 else "metal")
    if lod == 0:
        for k in range(12):
            a = k * math.tau / 12
            _add(parts, "seat", "body", bm_cyl(0.015, 0.015, 0.005, 6, 'Z', (math.cos(a) * 0.12, -1.24 + math.sin(a) * 0.1, 1.32)), "trim")
    for sx in (1, -1):
        box(parts, "plates", "body", (0.24, 0.62, 0.025), (sx * 0.36, -0.3, 0.62), "metal")
        if lod == 0:
            for k in range(5):
                box(parts, "plates", "body", (0.22, 0.012, 0.008), (sx * 0.36, -0.55 + k * 0.12, 0.637), "trim_grey")
    # transmission and rear axle, the clamshell fenders with lamps, the drawbar and PTO
    box(parts, "trans", "body", (0.56, 0.7, 0.55), (0, yr + 0.15, 0.72), "trim", 0.06, seg)
    for sx in (1, -1):
        tube(parts, "trans", "body", (sx * 0.25, yr, rspec["R"]), (sx * (xr - 0.12), yr, rspec["R"]), 0.075, "trim", 12)
        mudguard(parts, "guards", "body", (sx * xr, yr, rspec["R"]), rspec["R"] + 0.08, 0.38, 0, 180, P, lod, flat_top=0.04)
        box(parts, "guards", "body", (0.38, 0.5, 0.03), (sx * xr, yr - 0.1, rspec["R"] * 2 + 0.13), P, 0.01)
        _add(parts, "lamps", "body", bm_cyl(0.045, 0.04, 0.06, 12, 'Y', (sx * (xr + 0.08), yr - 0.75, 0.95)), "chrome")
        _add(parts, "lamps", "body", bm_cyl(0.04, 0.04, 0.006, 12, 'Y', (sx * (xr + 0.08), yr - 0.782, 0.95)), "lamp_tail")
    # headlamps on brackets either side of the radiator, the exhaust, the air cleaner
    for sx in (1, -1):
        tube(parts, "lamps", "body", (sx * 0.27, 1.1, 1.1), (sx * 0.4, 1.18, 1.22), 0.015, "trim", 6)
        _add(parts, "lamps", "body", bm_cyl(0.085, 0.07, 0.11, 16, 'Y', (sx * 0.42, 1.2, 1.24)), "chrome")
        _add(parts, "lamps", "body", bm_cyl(0.075, 0.075, 0.008, 16, 'Y', (sx * 0.42, 1.258, 1.24)), "lamp_reflector")
        _add(parts, "lamps", "body", bm_cyl(0.078, 0.078, 0.004, 16, 'Y', (sx * 0.42, 1.263, 1.24)), "lamp_front")
    tube(parts, "exhaust", "body", (0.2, 0.9, 1.2), (0.2, 0.9, 1.95), 0.045, "metal", 12)
    rcap = bm_cyl(0.05, 0.05, 0.008, 12, 'Z', (0, 0, 0))
    bmesh.ops.transform(rcap, matrix=Matrix.Translation((0.2, 0.88, 1.97)) @ Matrix.Rotation(-0.4, 4, 'X'), verts=rcap.verts)
    _add(parts, "exhaust", "body", rcap, "metal")
    _add(parts, "exhaust", "body", bm_cyl(0.07, 0.07, 0.45, 12, 'Z', (-0.18, 0.95, 1.55)), P)
    _add(parts, "exhaust", "body", bm_cyl(0.085, 0.07, 0.1, 12, 'Z', (-0.18, 0.95, 1.82)), "trim")
    # front axle: a narrow beam on a centre pivot, the drag link to the steering box
    tube(parts, "axle", "body", (-xf + 0.08, yf, fspec["R"] + 0.04), (xf - 0.08, yf, fspec["R"] + 0.04), 0.045, "trim", 10)
    box(parts, "axle", "body", (0.16, 0.18, 0.2), (0, yf, fspec["R"] + 0.1), "trim", 0.02)
    tube(parts, "axle", "body", (0.25, 0.2, 0.95), (0.4, yf - 0.1, fspec["R"] + 0.1), 0.018, "metal", 6)
    for sx, sn in ((1, "r"), (-1, "l")):
        tube(parts, "axle", "steer_f" + sn, (sx * (xf - 0.1), yf, fspec["R"] - 0.04), (sx * (xf - 0.1), yf, fspec["R"] + 0.16), 0.03, "trim", 8)
    box(parts, "linkage", "body", (0.1, 0.55, 0.06), (0, -1.32, 0.5), P2)
    _add(parts, "linkage", "body", bm_cyl(0.02, 0.02, 0.12, 8, 'Z', (0, -1.55, 0.53)), "chrome")
    _add(parts, "pto", "pto", bm_cyl(0.03, 0.03, 0.18, 10, 'Y', (0, -1.25, 0.65)), "metal")
    info["bones"].append({"name": "pto", "head": (0, -1.16, 0.65), "tail": (0, -1.4, 0.65), "parent": "body"})
    info["bones"].append({"name": "hitch", "head": (0, -1.58, 0.5), "tail": (0, -1.58, 0.8), "parent": "root"})
    info["pto"] = True
    # a festival rosette on the radiator
    if lod == 0:
        for k, m in enumerate(("flag_c", "sheet_white", "flag_c")):
            ros = bm_cyl(0.07 - k * 0.02, 0.07 - k * 0.02, 0.006, 16, 'Y', (0.18, 1.32 + k * 0.004, 0.8))
            _add(parts, "rosette", "body", ros, m)
        for sx in (-1, 1):
            tail = bm_box((0.025, 0.004, 0.12), (0.18 + sx * 0.02, 1.322, 0.7))
            _add(parts, "rosette", "body", tail, "flag_c")
    return parts, info

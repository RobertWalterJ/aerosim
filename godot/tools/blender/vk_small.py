# AeroSim vehicle kit, second pass (owner's request): the farm quad and the two trailers in detail.
# farm_quad_a: a utility four-wheel-drive ATV of the 450 cc class (about 2.05 m long, 1.18 m wide, 1.2 m to the bars, 1.28 m
# wheelbase, 25x8-12 front and 25x10-12 rear tyres), studied from dealers' spec sheets and photographs of the class for
# proportions only. tractor_trailer_a: a 6 t tandem-axle tipping farm trailer. parade_trailer_a: a single-axle flatbed with
# timber sides dressed for the festival. All lettering fictional (KESTREL, HALLOWAY FESTIVAL), real glyph geometry.
import math
import bmesh
from mathutils import Vector as V, Matrix
from vk_core import Part, bm_rbox, bm_box, bm_cyl, bm_tube, bm_sweep, bm_lathe, text_bm
from vk_recipes import add, tyre
import vk_wheels
from vk_recipes_custom import std_bones, trailer_actions
from vk_tractor import mudguard, text_plane, cylinder_ram


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


def spring(parts, name, bone, a, b, r, wire, turns, mat, lod):
    """A coil spring from a to b."""
    if lod >= 2:
        return
    a, b = V(a), V(b)
    ax = (b - a)
    L = ax.length
    ax.normalize()
    u = ax.cross(V((1, 0, 0)) if abs(ax.x) < 0.9 else V((0, 1, 0))).normalized()
    v = ax.cross(u)
    n = int(turns * (12 if lod == 0 else 6))
    pts = [a + ax * (L * k / n) + (u * math.cos(k / n * turns * math.tau) + v * math.sin(k / n * turns * math.tau)) * r for k in range(n + 1)]
    sec = [(math.cos(t) * wire, math.sin(t) * wire) for t in [k * math.tau / 6 for k in range(6)]]
    _add(parts, name, bone, bm_sweep(sec, pts, True, up=tuple(ax)), mat)


def rack(parts, name, bone, y0, y1, x, z, lod):
    for sx in (1, -1):
        tube(parts, name, bone, (sx * x, y0, z), (sx * x, y1, z), 0.012, "trim", 6)
    tube(parts, name, bone, (-x, y0, z), (x, y0, z), 0.012, "trim", 6)
    tube(parts, name, bone, (-x, y1, z), (x, y1, z), 0.012, "trim", 6)
    n = 7 if lod == 0 else 3
    for k in range(1, n):
        yy = y0 + (y1 - y0) * k / n
        tube(parts, name, bone, (-x, yy, z + 0.002), (x, yy, z + 0.002), 0.007, "trim", 4)
    for xx in (-x * 0.33, x * 0.33):
        tube(parts, name, bone, (xx, y0, z + 0.004), (xx, y1, z + 0.004), 0.007, "trim", 4)


# ================================================================================================================ quad
def quad_parts(rc, lod):
    parts = []
    info = {"spec": None, "hubs": [], "wipers": [], "steering": None, "bones": [], "hinges": {}, "body_z": 0.6}
    seg = 2 if lod == 0 else 1
    R = 0.3175
    fs = {"R": R, "Rr": 0.152, "tw": 0.2, "style": "steel", "holes": 0, "tyre": "tractor", "lugs": 16, "lug_h": 0.02,
          "face_mat": "rim", "barrel_mat": "rim", "nuts": 4, "pcd": 0.055, "nut_r": 0.01, "hubcap": True, "cap_r": 0.035, "disc": False,
          "segs": 32, "sidewall": "TRAILGRIP 25x8-12"}
    rs = dict(fs, tw=0.25, lugs=17, sidewall="TRAILGRIP 25x10-12")
    yf, yr = 0.64, -0.64
    xf, xr = 0.47, 0.465
    for side, sn in ((-1, "l"), (1, "r")):
        vk_wheels.build_wheel(fs, side, lod, "f" + sn, (side * xf, yf, R), True, parts=parts)
        info["hubs"].append(("f" + sn, (side * xf, yf, R), True))
        vk_wheels.build_wheel(rs, side, lod, "r" + sn, (side * xr, yr, R), False, parts=parts)
        info["hubs"].append(("r" + sn, (side * xr, yr, R), False))
    P = "paint"
    # ---- frame, skid plate, engine and drive
    for sx in (1, -1):
        tube(parts, "frame", "body", (sx * 0.17, 0.85, 0.3), (sx * 0.17, -0.8, 0.28), 0.022, "trim")
        tube(parts, "frame", "body", (sx * 0.15, 0.8, 0.62), (sx * 0.15, -0.75, 0.6), 0.02, "trim")
        for yy in (0.62, 0.0, -0.55):
            tube(parts, "frame", "body", (sx * 0.17, yy, 0.3), (sx * 0.15, yy - 0.05, 0.6), 0.016, "trim", 6)
    box(parts, "frame", "body", (0.38, 1.4, 0.012), (0, 0.0, 0.26), "metal")
    box(parts, "engine", "body", (0.32, 0.42, 0.3), (0, 0.0, 0.46), "metal", 0.04, seg)
    _add(parts, "engine", "body", bm_cyl(0.075, 0.075, 0.2, 14 if lod == 0 else 8, 'Z', (0, 0.12, 0.68)), "metal")
    if lod == 0:
        for k in range(6):
            box(parts, "engine", "body", (0.2, 0.2, 0.008), (0, 0.12, 0.6 + k * 0.03), "metal")
    box(parts, "engine", "body", (0.06, 0.48, 0.28), (-0.19, 0.0, 0.46), "trim", 0.05, seg)            # drive belt cover
    tube(parts, "drive", "body", (0, 0.2, 0.36), (0, yf - 0.05, R), 0.025, "metal")                     # prop shafts
    tube(parts, "drive", "body", (0, -0.2, 0.36), (0, yr + 0.05, R), 0.025, "metal")
    box(parts, "drive", "body", (0.2, 0.18, 0.18), (0, yf, R), "trim", 0.03)                               # front diff
    tube(parts, "drive", "body", (-xr + 0.1, yr, R), (xr - 0.1, yr, R), 0.035, "trim", 10)                 # rear axle
    box(parts, "drive", "body", (0.24, 0.2, 0.2), (0, yr, R), "trim", 0.03)
    # ---- front suspension: double wishbones, coil-over shocks, CV shafts, knuckles (steer)
    for sx, sn in ((1, "r"), (-1, "l")):
        for zz in (R - 0.07, R + 0.09):
            for dy in (0.1, -0.1):
                tube(parts, "susp", "body", (sx * 0.16, yf + dy, zz + 0.02), (sx * (xf - 0.13), yf, zz), 0.012, P, 6)
        tube(parts, "susp", "body", (sx * 0.05, yf, R), (sx * (xf - 0.12), yf, R), 0.014, "metal", 6)
        _add(parts, "susp", "steer_f" + sn, bm_rbox((0.05, 0.08, 0.2), 0.015, 1, (sx * (xf - 0.11), yf, R)), "metal")
        spring(parts, "susp", "body", (sx * (xf - 0.18), yf + 0.04, R + 0.08), (sx * 0.2, yf + 0.04, 0.68), 0.032, 0.006, 6, "flag_a", lod)
        tube(parts, "susp", "body", (sx * (xf - 0.18), yf + 0.04, R + 0.08), (sx * 0.2, yf + 0.04, 0.68), 0.012, "chrome", 6)
        # rear shocks
        spring(parts, "susp", "body", (sx * 0.2, yr + 0.1, R + 0.05), (sx * 0.16, yr + 0.3, 0.66), 0.03, 0.006, 6, "flag_a", lod)
    # ---- body plastics: front pod with the lamps, fenders over all four wheels, footwells, the tank, the seat, rear fender pod
    pod = bm_rbox((0.62, 0.62, 0.3), 0.12, seg + 1, (0, 0.62, 0.74))
    for v in pod.verts:
        t = max(0.0, (v.co.y - 0.5) / 0.4)
        if v.co.z > 0.74:
            v.co.z -= 0.12 * t                             # the nose slopes down
    _add(parts, "body", "body", pod, P)
    for sx in (1, -1):
        mudguard(parts, "body", "body", (sx * (xf + 0.01), yf, R), R + 0.07, 0.32, 15, 170, P, lod, lip=0.02, flat_top=0.04)
        mudguard(parts, "body", "body", (sx * (xr + 0.01), yr, R), R + 0.07, 0.36, 10, 165, P, lod, lip=0.02, flat_top=0.04)
        # footwell with tread pattern
        box(parts, "body", "body", (0.26, 0.62, 0.02), (sx * 0.36, -0.02, 0.36), "trim")
        if lod == 0:
            for k in range(8):
                box(parts, "body", "body", (0.24, 0.012, 0.008), (sx * 0.36, -0.3 + k * 0.08, 0.375), "trim_grey")
        box(parts, "body", "body", (0.03, 0.62, 0.12), (sx * 0.49, -0.02, 0.42), P, 0.01)                      # footwell edge
        for yy, m in ((yf + 0.28, "lamp_reflector"),):
            box(parts, "lamps", "body", (0.13, 0.05, 0.07), (sx * 0.17, 0.95, 0.72), "trim", 0.015)
            box(parts, "lamps", "body", (0.11, 0.006, 0.05), (sx * 0.17, 0.977, 0.72), "lamp_reflector")
            box(parts, "lamps", "body", (0.115, 0.004, 0.055), (sx * 0.17, 0.981, 0.72), "lamp_front")
        if lod <= 1:
            r = V((0, 1, 0)) if sx > 0 else V((0, -1, 0))   # read from outside: +y is the viewer's right on the +x side
            text_plane(parts, "badges", "body", "KESTREL 450", 0.05, (sx * 0.322, 0.62, 0.82), r, (0, 0, 1),
                       "sheet_white", 0.0015)
            text_plane(parts, "badges", "body", "4x4", 0.04, (sx * 0.322, 0.62, 0.76), r, (0, 0, 1), "sheet_white", 0.0015)
    rpod = bm_rbox((0.58, 0.55, 0.22), 0.1, seg + 1, (0, -0.68, 0.72))
    _add(parts, "body", "body", rpod, P)
    box(parts, "body", "body", (0.3, 0.38, 0.22), (0, 0.18, 0.78), P, 0.08, seg)                                # tank cover
    _add(parts, "body", "body", bm_cyl(0.035, 0.035, 0.03, 12, 'Z', (0, 0.25, 0.9)), "trim")                   # filler cap
    seat = bm_rbox((0.3, 0.7, 0.1), 0.05, seg + 1, (0, -0.33, 0.9))
    for v in seat.verts:
        v.co.z += 0.02 * math.cos(v.co.y * 3.0)
    _add(parts, "seat", "body", seat, "seat")
    box(parts, "seat", "body", (0.28, 0.66, 0.06), (0, -0.33, 0.83), "trim")
    box(parts, "lamps", "body", (0.1, 0.012, 0.05), (0, -0.955, 0.72), "lamp_tail")
    box(parts, "lamps", "body", (0.1, 0.012, 0.02), (0, -0.955, 0.685), "lamp_brake")
    # racks, bumpers, hitch, winch
    rack(parts, "racks", "body", 0.42, 0.98, 0.42, 0.92, lod)
    rack(parts, "racks", "body", -0.48, -1.0, 0.44, 0.9, lod)
    for sx in (1, -1):
        tube(parts, "racks", "body", (sx * 0.4, 0.95, 0.92), (sx * 0.3, 0.95, 0.7), 0.012, "trim", 6)
        tube(parts, "racks", "body", (sx * 0.42, -0.98, 0.9), (sx * 0.3, -0.98, 0.7), 0.012, "trim", 6)
    for zz in (0.42, 0.62):
        tube(parts, "bumper", "body", (-0.3, 1.02, zz), (0.3, 1.02, zz), 0.016, "trim", 8)
    for sx in (1, -1):
        tube(parts, "bumper", "body", (sx * 0.3, 1.02, 0.42), (sx * 0.3, 1.02, 0.62), 0.016, "trim", 8)
    box(parts, "bumper", "body", (0.26, 0.12, 0.1), (0, 0.98, 0.5), "trim", 0.02)                                 # winch
    _add(parts, "bumper", "body", bm_cyl(0.035, 0.035, 0.2, 10, 'X', (0, 0.98, 0.5)), "metal")
    box(parts, "hitch", "body", (0.08, 0.12, 0.03), (0, -1.02, 0.38), "metal")
    _add(parts, "hitch", "body", bm_cyl(0.02, 0.02, 0.03, 10, 'Z', (0, -1.05, 0.4)), "chrome")
    # exhaust under the right side to the silencer at the back
    tube(parts, "exhaust", "body", (0.06, 0.18, 0.66), (0.22, -0.2, 0.55), 0.022, "metal", 8)
    tube(parts, "exhaust", "body", (0.22, -0.2, 0.55), (0.25, -0.62, 0.6), 0.022, "metal", 8)
    _add(parts, "exhaust", "body", bm_cyl(0.05, 0.045, 0.28, 12, 'Y', (0.25, -0.78, 0.6)), "metal")
    # handlebars, pod light, grips, levers, guards on the handlebar bone
    hb = V((0, 0.36, 0.92))
    info["bones"].append({"name": "handlebar", "head": tuple(hb), "tail": (0, 0.34, 1.12), "parent": "body"})
    tube(parts, "bars", "handlebar", (0, 0.36, 0.86), (0, 0.33, 1.02), 0.018, "trim")
    tube(parts, "bars", "handlebar", (-0.4, 0.28, 1.06), (0.4, 0.28, 1.06), 0.012, "trim")
    for sx in (1, -1):
        _add(parts, "bars", "handlebar", bm_cyl(0.017, 0.017, 0.12, 10, 'X', (sx * 0.35, 0.28, 1.06)), "rubber")
        tube(parts, "bars", "handlebar", (sx * 0.24, 0.3, 1.07), (sx * 0.33, 0.36, 1.06), 0.005, "metal", 4)
        box(parts, "bars", "handlebar", (0.12, 0.08, 0.1), (sx * 0.4, 0.32, 1.08), "trim", 0.02)                     # hand guard
    box(parts, "bars", "handlebar", (0.26, 0.16, 0.12), (0, 0.38, 1.08), P, 0.04, seg)
    box(parts, "bars", "handlebar", (0.12, 0.006, 0.06), (0, 0.461, 1.08), "lamp_reflector")
    box(parts, "bars", "handlebar", (0.13, 0.004, 0.07), (0, 0.465, 1.08), "lamp_front")
    box(parts, "bars", "handlebar", (0.12, 0.012, 0.05), (0, 0.3, 1.13), "glass_tint")                           # the clocks
    return parts, info


def quad_actions(rc, info):
    lock = math.radians(32)
    A = {}
    for nm, sg in (("steer_left", 1), ("steer_right", -1)):
        A[nm] = {"steer_fl": [(1, 0.0), (18, sg * lock)], "steer_fr": [(1, 0.0), (18, sg * lock)], "handlebar": [(1, 0.0), (18, sg * lock)]}
    return A


add({"name": "farm_quad_a", "kind": "quad", "maker": quad_parts, "bones_fn": std_bones, "actions_fn": quad_actions,
     "paint": (0.10, 0.28, 0.13), "paint2": (0.12, 0.12, 0.12), "wheel": {"R": 0.3175}, "dirt": 0.75,
     "condition": lambda co, n: max(0.35, 1.0 - 0.5 * max(0.0, 1.0 - co.z / 0.8)),
     "mat_colours": {"flag_a": (0.75, 0.12, 0.06)}})


# ============================================================================================================ trailers
def trailer_parts(rc, lod, parade=False):
    parts = []
    info = {"spec": None, "hubs": [], "wipers": [], "steering": None, "bones": [], "hinges": {}, "body_z": 0.9}
    seg = 2 if lod == 0 else 1
    if not parade:
        W = 2.35
        y0, y1, zf, zs = 2.05, -3.2, 1.0, 0.62
        axles = [(-1.15, "f"), (-2.2, "r")]
        R_ = tyre(400, 80, 15)
        spec = {"R": R_[0], "Rr": R_[1], "tw": 0.38, "style": "steel", "holes": 6, "nuts": 6, "pcd": 0.1, "face_mat": "paint2",
                "barrel_mat": "paint2", "disc": False, "sidewall": "FIELDLINE 400/60-15.5"}
        hitch_y = 3.25
    else:
        W = 2.2
        y0, y1, zf, zs = 1.6, -2.6, 0.78, 0.3
        axles = [(-1.25, "r")]
        R_ = tyre(185, 80, 14)
        spec = {"R": R_[0], "Rr": R_[1], "tw": 0.19, "style": "steel", "holes": 8, "nuts": 4, "face_mat": "paint2", "barrel_mat": "paint2",
                "disc": False, "sidewall": "ROADSTAR 185R14"}
        hitch_y = 2.75
    x = W * 0.5 - spec["tw"] * 0.5 - (0.05 if not parade else 0.14)
    for (yy, tag) in axles:
        for side, sn in ((-1, "l"), (1, "r")):
            vk_wheels.build_wheel(spec, side, lod, tag + sn, (side * x, yy, spec["R"]), False, parts=parts)
            info["hubs"].append((tag + sn, (side * x, yy, spec["R"]), False))
    bed = "tip_bed" if not parade else "body"
    # chassis rails and cross members, leaf springs on the axles, drawbar A-frame to the eye, jack leg
    for sx in (1, -1):
        box(parts, "chassis", "body", (0.1, y0 - y1 - 0.1, 0.16), (sx * 0.5, (y0 + y1) * 0.5, zf - 0.16), "trim")
        tube(parts, "chassis", "drawbar", (sx * 0.5, y0 - 0.15, zf - 0.18), (0, hitch_y - 0.18, zf - 0.36), 0.045, "paint2", 8)
        for (yy, tag) in axles:
            for k in range(4 if lod == 0 else 2):
                box(parts, "chassis", "body", (0.07, 0.95 - k * 0.18, 0.012), (sx * x * 0.6 + sx * 0.0, yy, spec["R"] + 0.06 + k * 0.014), "metal")
            box(parts, "chassis", "body", (0.08, 0.1, 0.16), (sx * 0.5, yy, spec["R"] + 0.12), "trim")
    for k in range(6):
        yy = y1 + 0.1 + (y0 - y1 - 0.2) * k / 5
        box(parts, "chassis", "body", (1.1, 0.08, 0.1), (0, yy, zf - 0.14), "trim")
    for (yy, tag) in axles:
        tube(parts, "chassis", "body", (-x + 0.12, yy, spec["R"]), (x - 0.12, yy, spec["R"]), 0.045, "trim", 10)
    eye = bm_lathe([(0.035, -0.025), (0.07, -0.025), (0.07, 0.025), (0.035, 0.025), (0.035, -0.025)], 16, axis='Z')[0]
    bmesh.ops.transform(eye, matrix=Matrix.Translation((0, hitch_y, zf - 0.36)), verts=eye.verts)
    _add(parts, "chassis", "drawbar", eye, "metal")
    box(parts, "chassis", "drawbar", (0.12, 0.25, 0.08), (0, hitch_y - 0.2, zf - 0.36), "paint2")
    _add(parts, "chassis", "drawbar", bm_cyl(0.035, 0.035, 0.45, 10, 'Z', (0.25, y0 + 0.45, zf - 0.5)), "metal")     # jack
    _add(parts, "chassis", "drawbar", bm_cyl(0.07, 0.07, 0.02, 12, 'Z', (0.25, y0 + 0.45, zf - 0.73)), "metal")
    tube(parts, "chassis", "drawbar", (0.25, y0 + 0.45, zf - 0.27), (0.35, y0 + 0.45, zf - 0.2), 0.008, "trim", 5)
    # the bed: floor, sides, front board and tailboard
    if not parade:
        box(parts, "bed", bed, (W, y0 - y1, 0.06), (0, (y0 + y1) * 0.5, zf), "metal")
        for sx in (1, -1):
            box(parts, "bed", bed, (0.04, y0 - y1, zs), (sx * (W * 0.5 - 0.02), (y0 + y1) * 0.5, zf + zs * 0.5), "paint", 0.008)
            box(parts, "bed", bed, (0.06, y0 - y1 + 0.04, 0.06), (sx * (W * 0.5), (y0 + y1) * 0.5, zf + zs), "paint2", 0.01)
            box(parts, "bed", bed, (0.06, y0 - y1 + 0.04, 0.05), (sx * (W * 0.5), (y0 + y1) * 0.5, zf + 0.02), "paint2", 0.01)
            for k in range(1, 8):
                yy = y1 + (y0 - y1) * k / 8
                box(parts, "bed", bed, (0.05, 0.05, zs), (sx * (W * 0.5 + 0.005), yy, zf + zs * 0.5), "paint", 0.008)
            if lod == 0:
                for k in range(3):
                    box(parts, "bed", bed, (0.035, 0.08, 0.05), (sx * (W * 0.5 + 0.02), y0 - 0.6 - k * 1.8, zf + 0.04), "metal")     # hinge pins
        box(parts, "bed", bed, (W, 0.05, zs + 0.45), (0, y0, zf + (zs + 0.45) * 0.5), "paint", 0.008)                       # tall front board
        box(parts, "bed", bed, (W - 0.08, 0.05, zs), (0, y1, zf + zs * 0.5), "paint", 0.008)                               # tailboard
        for k in range(3):
            box(parts, "bed", bed, (W - 0.04, 0.03, 0.05), (0, y1 - 0.03, zf + 0.08 + k * zs * 0.42), "paint2")
        # tipping ram from the chassis to the front of the bed
        cylinder_ram(parts, "ram", "body", bed, (0, y0 - 0.55, zf - 0.22), (0, y0 - 0.45, zf - 0.04), 0.08, 0.05, lod)
        info["bones"].append({"name": "tip_bed", "head": (0, y1 + 0.05, zf - 0.06), "tail": (0.3, y1 + 0.05, zf - 0.06), "parent": "body"})
        info["hinges"]["tip_bed"] = (0, False, 48.0)
    else:
        # planked timber deck with gaps, timber sides and corner posts
        n = 14 if lod == 0 else 4
        for k in range(n):
            xx = -W * 0.5 + W * (k + 0.5) / n
            box(parts, "bed", bed, (W / n - 0.012, y0 - y1, 0.04), (xx, (y0 + y1) * 0.5, zf), "wood")
        for sx in (1, -1):
            for k in range(2):
                box(parts, "bed", bed, (0.04, y0 - y1, 0.12), (sx * (W * 0.5 - 0.02), (y0 + y1) * 0.5, zf + 0.09 + k * 0.14), "wood", 0.005)
        for yy in (y0, y1):
            for k in range(2):
                box(parts, "bed", bed, (W, 0.04, 0.12), (0, yy, zf + 0.09 + k * 0.14), "wood", 0.005)
        # straw bales with their twine, a few loose straws
        for (bx, by, bz, rot) in ((-0.5, 0.95, 0, 0), (0.5, 0.95, 0, 0), (-0.5, -0.1, 0, 0), (0.5, -0.1, 0, 0), (0.0, -1.3, 0, 1.57),
                                   (0.0, 0.45, 0.36, 0)):
            b = bm_rbox((0.9, 0.46, 0.36), 0.035, 1, (0, 0, 0))
            bmesh.ops.transform(b, matrix=Matrix.Translation((bx, by, zf + 0.2 + bz)) @ Matrix.Rotation(rot, 4, 'Z'), verts=b.verts)
            _add(parts, "bales", "body", b, "straw")
            if lod <= 1:
                for tx in (-0.22, 0.22):
                    t = bm_box((0.012, 0.47, 0.37), (tx, 0, 0))
                    bmesh.ops.transform(t, matrix=Matrix.Translation((bx, by, zf + 0.2 + bz)) @ Matrix.Rotation(rot, 4, 'Z'), verts=t.verts)
                    _add(parts, "bales", "body", t, "flag_b")
        # bunting on four poles round the deck, sagging lines of flags in three colours
        poles = [(sx * (W * 0.5 - 0.05), yy) for sx in (1, -1) for yy in (y0 - 0.05, y1 + 0.05)]
        for (px, py) in poles:
            tube(parts, "bunting", "body", (px, py, zf), (px, py, zf + 1.5), 0.02, "wood", 6)
        cols = ["flag_a", "flag_b", "flag_c"]
        for (a, b) in ((poles[0], poles[1]), (poles[2], poles[3]), (poles[0], poles[2]), (poles[1], poles[3])):
            pa, pb = V((a[0], a[1], zf + 1.47)), V((b[0], b[1], zf + 1.47))
            n = max(3, int((pb - pa).length / 0.3))
            sag = lambda t: -0.25 * 4 * t * (1 - t)
            for k in range(n):
                t0, t1 = k / n, (k + 0.8) / n
                p0 = pa.lerp(pb, t0) + V((0, 0, sag(t0)))
                p1 = pa.lerp(pb, t1) + V((0, 0, sag(t1)))
                tip_ = (p0 + p1) * 0.5 + V((0, 0, -0.2))
                bm = bmesh.new()
                f = bm.faces.new([bm.verts.new(p0), bm.verts.new(p1), bm.verts.new(tip_)])
                _add(parts, "bunting", "body", bm, cols[k % 3])
            pts = [pa.lerp(pb, k / 10) + V((0, 0, sag(k / 10))) for k in range(11)]
            _add(parts, "bunting", "body", bm_sweep([(0.003, 0), (0, 0.003), (-0.003, 0), (0, -0.003)], pts, True), "trim")
        # the banner on both sides, lettered
        for sx in (1, -1):
            box(parts, "banner", "body", (0.012, 2.8, 0.36), (sx * (W * 0.5 + 0.025), -0.5, zf - 0.07), "sheet_white")
            if lod <= 1:
                r = V((0, 1, 0)) if sx > 0 else V((0, -1, 0))   # read from outside: +y is the viewer's right on the +x side
                text_plane(parts, "banner", "body", "HALLOWAY FESTIVAL", 0.19, (sx * (W * 0.5 + 0.032), -0.5, zf - 0.14),
                           r, (0, 0, 1), "flag_a", 0.002)
    # mudguards, lamp boards, reflectors, plate
    for sx in (1, -1):
        y_mid = sum(a for a, _ in axles) / len(axles)
        span = (abs(axles[0][0] - axles[-1][0]) + spec["R"] * 2 + 0.25)
        box(parts, "guards", "body", (spec["tw"] + 0.14, span, 0.02), (sx * x, y_mid, spec["R"] * 2 + 0.07), "trim", 0.008)
        box(parts, "guards", "body", (spec["tw"] + 0.14, 0.02, 0.2), (sx * x, y_mid - span * 0.5, spec["R"] * 2 - 0.03), "trim")
        box(parts, "lamps", bed, (0.16, 0.04, 0.1), (sx * (W * 0.5 - 0.15), y1 - 0.05, zf + 0.08), "trim", 0.01)
        box(parts, "lamps", bed, (0.07, 0.008, 0.07), (sx * (W * 0.5 - 0.19), y1 - 0.074, zf + 0.08), "lamp_tail")
        box(parts, "lamps", bed, (0.06, 0.008, 0.07), (sx * (W * 0.5 - 0.115), y1 - 0.074, zf + 0.08), "lamp_ind_r" if sx > 0 else "lamp_ind_l")
        box(parts, "lamps", bed, (0.06, 0.008, 0.04), (sx * (W * 0.5 - 0.15), y1 - 0.074, zf - 0.0), "lamp_brake")
        box(parts, "lamps", "body", (0.05, 0.01, 0.08), (sx * (W * 0.5 - 0.02), y0 - 0.02, zf - 0.1), "lamp_beacon")      # side reflectors
    box(parts, "plates", bed, (0.52, 0.01, 0.11), (0, y1 - 0.06, zf - 0.05), "plate")
    info["bones"].append({"name": "drawbar", "head": (0, y0, zf - 0.2), "tail": (0, y0, zf + 0.1), "parent": "body"})
    info["bones"].append({"name": "hitch", "head": (0, hitch_y, zf - 0.36), "tail": (0, hitch_y, zf - 0.06), "parent": "root"})
    return parts, info


add({"name": "tractor_trailer_a", "kind": "trailer", "maker": trailer_parts, "bones_fn": std_bones, "actions_fn": trailer_actions,
     "paint": (0.55, 0.08, 0.06), "paint2": (0.1, 0.1, 0.1), "wheel": {"R": tyre(400, 80, 15)[0]}, "dirt": 0.85,
     "condition": lambda co, n: max(0.3, 1.0 - 0.45 * max(0.0, 1.0 - co.z / 1.2) - 0.15 * (0.5 + 0.5 * math.sin(co.y * 4.0)))})
add({"name": "parade_trailer_a", "kind": "trailer", "maker": lambda rc, lod: trailer_parts(rc, lod, True), "bones_fn": std_bones,
     "actions_fn": trailer_actions, "paint": (0.55, 0.08, 0.06), "paint2": (0.2, 0.2, 0.2), "wheel": {"R": tyre(185, 80, 14)[0]},
     "mat_colours": {"wood": (0.42, 0.28, 0.16)}, "dirt": 0.3, "condition": lambda co, n: 0.85})

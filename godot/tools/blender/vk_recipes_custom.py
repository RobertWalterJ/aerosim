# AeroSim vehicle kit: the vehicles built part by part rather than lofted: a modern cab tractor (and its wheels alone), a
# 1950s parade tractor, a tipping farm trailer, the festival parade trailer, a motorcycle and a farm quad.
# Frame as everywhere: +X right, +Y front, +Z up, origin on the ground at the middle of the length (Blender).
import math
import bmesh
from mathutils import Vector as V, Matrix
from vk_recipes import add, tyre
from vk_core import Part, bm_rbox, bm_box, bm_cyl, bm_tube, bm_sweep, bm_lathe, mirror_x, text_bm
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


def arc_guard(parts, name, bone, centre, radius, width, a0, a1, mat, lod, thick=0.012, lip=0.03):
    """A mudguard: a curved sheet over a wheel (centre (x, y, z)), angles from +Y (front) round over the top."""
    n = 18 if lod == 0 else 8
    path = []
    for k in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * k / n)
        path.append((centre[0], centre[1] + math.cos(a) * radius, centre[2] + math.sin(a) * radius))
    sec = [(-width * 0.5, -thick), (width * 0.5, -thick), (width * 0.5, lip), (width * 0.5 - 0.02, lip), (width * 0.5 - 0.02, 0.0),
           (-width * 0.5 + 0.02, 0.0), (-width * 0.5 + 0.02, lip), (-width * 0.5, lip)]
    bm = bm_sweep(sec, path, True, up=(1, 0, 0))
    _add(parts, name, bone, bm, mat)


def lamp_box(parts, bone, c, size, mat, bezel="trim"):
    _add(parts, "lamps", bone, bm_rbox((size[0] + 0.02, size[1], size[2] + 0.02), 0.01, 1, c), bezel)
    _add(parts, "lamps", bone, bm_box(size, (c[0], c[1] + (0.01 if c[1] > 0 else -0.01) * 0 + 0.0, c[2])), mat)


def round_lamp(parts, bone, c, r, facing, lod, lens="lamp_reflector", shell="trim"):
    """A round lamp facing +Y (facing=1) or -Y (-1): a shell and a lens."""
    segs = 16 if lod == 0 else 8
    sh = bm_cyl(r * 1.05, r * 0.8, 0.1, segs, 'Y', (c[0], c[1] - facing * 0.04, c[2]))
    _add(parts, "lamps", bone, sh, shell)
    ln = bm_cyl(r, r, 0.01, segs, 'Y', (c[0], c[1] + facing * 0.012, c[2]))
    _add(parts, "lamps", bone, ln, lens)


def std_bones(rc, info):
    """root, body, wheels and steering pivots from info['hubs'], plus info['bones'] (extra pivots)."""
    bones = [{"name": "root", "head": (0, 0, 0), "tail": (0, 0, 0.4)},
             {"name": "body", "head": (0, 0, info.get("body_z", 0.5)), "tail": (0, 0, info.get("body_z", 0.5) + 0.4), "parent": "root"}]
    axes = info.get("steer_axis", {})
    for (nm, hub, steer) in info["hubs"]:
        if steer:
            ax = V(axes.get(nm, (0, 0, 1))).normalized()
            bones.append({"name": "steer_" + nm, "head": hub, "tail": tuple(V(hub) + ax * 0.25), "parent": info.get("steer_parent", "root")})
            bones.append({"name": "wheel_" + nm, "head": hub, "tail": (hub[0] + 0.2, hub[1], hub[2]), "parent": "steer_" + nm})
        else:
            bones.append({"name": "wheel_" + nm, "head": hub, "tail": (hub[0] + 0.2, hub[1], hub[2]), "parent": info.get("wheel_parent", "root")})
    if info.get("steering"):
        wc, ax = info["steering"]
        bones.append({"name": "steering_wheel", "head": tuple(wc), "tail": tuple(V(wc) + V(ax) * 0.15),
                      "parent": info.get("steering_parent", "body")})
    for b in info.get("bones", []):
        bones.append(b)
    info.setdefault("hinges", {})
    return bones


def wheel(parts, spec, side, lod, nm, hub, steer, hubs, bone=None):
    vk_wheels.build_wheel(spec, side, lod, nm, hub, steer, parts=parts, bone=bone)
    hubs.append((nm, hub, steer))


# ============================================================================================================ tractor
def tractor_parts(rc, lod, wheels_only=False):
    parts = []
    info = {"spec": None, "hubs": [], "wipers": [], "steering": None, "bones": [], "hinges": {}, "body_z": 1.0}
    pc = "paint"
    yr, yf = -1.0, 1.6                 # rear and front axles
    Rr_, Rf_ = tyre(540, 85, 38), tyre(420, 85, 28)
    rspec = {"R": Rr_[0], "Rr": Rr_[1], "tw": 0.54, "style": "steel", "holes": 0, "tyre": "tractor", "lugs": 23, "lug_h": 0.05,
             "face_mat": "paint2", "barrel_mat": "paint2", "nuts": 10, "pcd": 0.2, "nut_r": 0.016, "hubcap": True, "cap_r": 0.12,
             "disc": False, "segs": 36}
    fspec = {"R": Rf_[0], "Rr": Rf_[1], "tw": 0.42, "style": "steel", "holes": 0, "tyre": "tractor", "lugs": 18, "lug_h": 0.04,
             "face_mat": "paint2", "barrel_mat": "paint2", "nuts": 8, "pcd": 0.13, "nut_r": 0.014, "hubcap": True, "cap_r": 0.09,
             "disc": False, "segs": 32}
    xr = 1.2 - 0.54 * 0.5
    xf = 1.08 - 0.42 * 0.5
    for side, sn in ((-1, "l"), (1, "r")):
        wheel(parts, rspec, side, lod, "r" + sn, (side * xr, yr, rspec["R"]), False, info["hubs"])
        wheel(parts, fspec, side, lod, "f" + sn, (side * xf, yf, fspec["R"]), True, info["hubs"])
    if wheels_only:
        return parts, info
    seg = 2 if lod == 0 else 1
    # bonnet: a long rounded block, its nose lower than the back, with louvres
    hood = bm_rbox((0.84, 1.95, 0.62), 0.12, seg, (0, 1.2, 1.32))
    for v in hood.verts:
        t = max(0.0, (v.co.y - 0.9) / 1.3)
        if v.co.z > 1.32:
            v.co.z -= 0.14 * t * t
    _add(parts, "hood", "body", hood, pc)
    _add(parts, "hood", "body", bm_box((0.66, 1.9, 0.42), (0, 1.15, 0.86)), "trim")            # engine and frame under it
    grille = bm_rbox((0.72, 0.06, 0.5), 0.03, 1, (0, 2.16, 1.28))
    _add(parts, "hood", "body", grille, "trim")
    if lod <= 1:
        for k in range(6):
            _add(parts, "hood", "body", bm_box((0.6, 0.02, 0.02), (0, 2.2, 1.08 + k * 0.075)), "trim_grey")
        for sx in (1, -1):
            for k in range(5):
                _add(parts, "hood", "body", bm_box((0.02, 0.24, 0.02), (sx * 0.425, 1.55 + k * 0.08 * 0, 1.2 + k * 0.05)), "trim")
    for sx in (1, -1):
        lamp_box(parts, "body", (sx * 0.24, 2.2, 1.46), (0.18, 0.03, 0.07), "lamp_reflector")
    # front weights and carrier
    _add(parts, "hood", "body", bm_box((0.8, 0.3, 0.32), (0, 2.25, 0.78)), "trim")
    for k in range(4):
        _add(parts, "hood", "body", bm_rbox((0.7, 0.07, 0.3), 0.01, 1, (0, 2.26 + k * 0.075 - 0.1, 0.78)), "metal")
    # front axle and the rear axle housings
    _add(parts, "chassis", "body", bm_tube((-xf + 0.1, yf, fspec["R"]), (xf - 0.1, yf, fspec["R"]), 0.07, 10), "trim")
    _add(parts, "chassis", "body", bm_rbox((0.75, 0.75, 0.62), 0.08, seg, (0, yr + 0.05, rspec["R"] + 0.02)), "trim")
    for sx in (1, -1):
        _add(parts, "chassis", "body", bm_tube((sx * 0.3, yr, rspec["R"]), (sx * (xr - 0.12), yr, rspec["R"]), 0.1, 12), "trim")
    # cab
    cz0, cz1 = 1.28, 2.88
    cy0, cy1 = -1.55, 0.2
    cx = 0.76
    _add(parts, "cab", "body", bm_rbox((cx * 2 + 0.06, cy1 - cy0 + 0.06, 0.12), 0.03, 1, (0, (cy0 + cy1) * 0.5, cz0)), pc)
    for sx in (1, -1):
        for yy in (cy0, cy1):
            _add(parts, "cab", "body", bm_rbox((0.07, 0.07, cz1 - cz0), 0.02, 1, (sx * cx, yy, (cz0 + cz1) * 0.5)), "trim")
    _add(parts, "cab", "body", bm_rbox((cx * 2 + 0.22, cy1 - cy0 + 0.3, 0.16), 0.06, seg, (0, (cy0 + cy1) * 0.5 + 0.02, cz1 + 0.06)), "sheet_white")
    # glass: front, right side, rear (the left side is the door)
    _add(parts, "cab", "body", bm_box((cx * 2 - 0.06, 0.012, cz1 - cz0 - 0.32), (0, cy1 + 0.02, (cz0 + cz1) * 0.5 + 0.12)), "glass")
    _add(parts, "cab", "body", bm_box((cx * 2 - 0.06, 0.012, cz1 - cz0 - 0.28), (0, cy0 - 0.02, (cz0 + cz1) * 0.5 + 0.12)), "glass")
    _add(parts, "cab", "body", bm_box((0.012, cy1 - cy0 - 0.06, cz1 - cz0 - 0.2), (cx + 0.02, (cy0 + cy1) * 0.5, (cz0 + cz1) * 0.5 + 0.08)), "glass")
    # the door (left), hinged on the rear post, with its frame and handle
    door = bm_box((0.012, cy1 - cy0 - 0.08, cz1 - cz0 - 0.2), (-cx - 0.02, (cy0 + cy1) * 0.5, (cz0 + cz1) * 0.5 + 0.08))
    _add(parts, "door", "door_fl", door, "glass")
    for zz in (cz0 + 0.18, cz1 - 0.04):
        _add(parts, "door", "door_fl", bm_box((0.03, cy1 - cy0 - 0.06, 0.04), (-cx - 0.025, (cy0 + cy1) * 0.5, zz)), "trim")
    _add(parts, "door", "door_fl", bm_box((0.03, 0.04, cz1 - cz0 - 0.2), (-cx - 0.025, cy1 - 0.05, (cz0 + cz1) * 0.5 + 0.08)), "trim")
    _add(parts, "door", "door_fl", bm_box((0.04, 0.14, 0.03), (-cx - 0.05, cy1 - 0.15, 1.85)), "chrome")
    info["bones"].append({"name": "door_fl", "head": (-cx, cy0 + 0.03, 2.0), "tail": (-cx, cy0 + 0.03, 2.3), "parent": "body"})
    info["hinges"]["door_fl"] = (-1, True, 85.0)
    # steps on the left
    for k, zz in enumerate((0.55, 0.85, 1.12)):
        _add(parts, "cab", "body", bm_box((0.28, 0.4, 0.03), (-cx - 0.08 + k * 0.0, -0.3, zz)), "metal")
    # mudguards over the rear wheels, with the tail lamps on them
    for sx in (1, -1):
        arc_guard(parts, "guards", "body", (sx * xr, yr, rspec["R"]), rspec["R"] + 0.07, 0.62, 5, 175, pc, lod)
        lamp_box(parts, "body", (sx * (xr + 0.05), yr - 0.88, 1.0), (0.12, 0.03, 0.06), "lamp_tail")
        lamp_box(parts, "body", (sx * (xr + 0.05), yr - 0.88, 0.92), (0.12, 0.03, 0.05), "lamp_ind_r" if sx > 0 else "lamp_ind_l")
        arc_guard(parts, "guards", "steer_f" + ("r" if sx > 0 else "l"), (sx * xf, yf, fspec["R"]), fspec["R"] + 0.06, 0.48, 30, 150, pc, lod)
    # exhaust stack, air intake, beacon, work lamps, mirrors
    _add(parts, "cab", "body", bm_cyl(0.055, 0.055, 1.5, 12, 'Z', (0.5, 0.32, 2.2)), "metal")
    _add(parts, "cab", "body", bm_cyl(0.065, 0.065, 0.12, 12, 'Z', (0.5, 0.32, 2.98)), "trim")
    _add(parts, "cab", "body", bm_cyl(0.07, 0.07, 1.0, 12, 'Z', (-0.5, 0.32, 2.0)), "trim")
    _add(parts, "lamps", "body", bm_cyl(0.07, 0.06, 0.12, 12, 'Z', (0.45, -0.9, cz1 + 0.2)), "lamp_beacon")
    for sx in (1, -1):
        for yy in (cy1 + 0.12, cy0 - 0.12):
            lamp_box(parts, "body", (sx * 0.62, yy, cz1 + 0.04), (0.14, 0.04, 0.08), "lamp_reflector")
        _add(parts, "cab", "body", bm_tube((sx * cx, cy1, 2.5), (sx * (cx + 0.35), cy1 + 0.1, 2.55), 0.012, 6), "trim")
        _add(parts, "cab", "body", bm_rbox((0.04, 0.16, 0.26), 0.01, 1, (sx * (cx + 0.36), cy1 + 0.1, 2.5)), "trim")
    # inside: seat, steering wheel, console
    if lod <= 1:
        inter.seat(parts, 0.0, -0.75, cz0 + 0.06, lod, w=0.52, height=0.4)
        _add(parts, "cab", "body", bm_rbox((0.3, 0.5, 0.5), 0.04, 1, (0.45, -0.75, cz0 + 0.3)), "dash")
        info["steering"] = inter.steering_wheel(parts, (0.0, -0.05, 2.02), 40.0, lod, rim_r=0.2, col_len=0.5)
    # three-point linkage and the PTO stub on its own bone
    for sx in (1, -1):
        _add(parts, "linkage", "body", bm_tube((sx * 0.35, yr - 0.2, 0.55), (sx * 0.42, -2.25, 0.5), 0.03, 8), "trim")
        _add(parts, "linkage", "body", bm_box((0.05, 0.1, 0.05), (sx * 0.42, -2.28, 0.5)), "metal")
    _add(parts, "linkage", "body", bm_tube((0, yr - 0.4, 1.2), (0, -2.2, 0.95), 0.035, 8), "paint2")
    pto = bm_cyl(0.035, 0.035, 0.22, 12, 'Y', (0, -1.7, 0.68))
    _add(parts, "pto", "pto", pto, "metal")
    if lod == 0:
        for k in range(6):
            a = k * math.pi / 3
            _add(parts, "pto", "pto", bm_box((0.012, 0.18, 0.012), (math.cos(a) * 0.036, -1.72, 0.68 + math.sin(a) * 0.036)), "metal")
    _add(parts, "linkage", "body", bm_cyl(0.07, 0.07, 0.05, 12, 'Y', (0, -1.57, 0.68)), "paint")
    info["bones"].append({"name": "pto", "head": (0, -1.58, 0.68), "tail": (0, -1.88, 0.68), "parent": "body"})
    info["bones"].append({"name": "hitch", "head": (0, -2.3, 0.5), "tail": (0, -2.3, 0.8), "parent": "root"})
    info["pto"] = True
    # one big wiper on the front screen
    wb = bm_tube((0.0, cy1 + 0.04, cz0 + 0.25), (-0.55, cy1 + 0.04, cz0 + 0.62), 0.008, 5)
    _add(parts, "wiper", "wiper_f", wb, "trim")
    info["bones"].append({"name": "wiper_f", "head": (0.0, cy1 + 0.04, cz0 + 0.25), "tail": (0.0, cy1 + 0.2, cz0 + 0.25), "parent": "body"})
    info["wipers"] = [("wiper_f", (0.0, cy1 + 0.04, cz0 + 0.25), (0, 1, 0))]
    info["wipers_have_bones"] = True
    return parts, info


def tractor_actions(rc, info):
    import vk_build
    A = vk_build.car_actions(rc, info)
    if info.get("pto"):
        A["pto_spin"] = {"pto": [(1, 0.0), (7, math.radians(120)), (13, math.radians(240)), (19, math.radians(360))]}
    return A


def tractor_bones(rc, info):
    b = std_bones(rc, info)
    # std_bones adds the wiper from info['bones']; car_actions reads info['wipers'] for the sweep
    return b


add({"name": "tractor_a", "kind": "tractor", "maker": tractor_parts, "bones_fn": tractor_bones, "actions_fn": tractor_actions,
     "paint": (0.12, 0.24, 0.46), "paint2": (0.78, 0.78, 0.76), "wheel": {"R": tyre(540, 85, 38)[0]}, "wiper_sweep": 100,
     "wheel_r_of": lambda nm: tyre(540, 85, 38)[0] if nm.startswith("r") else tyre(420, 85, 28)[0], "lock": 40})
add({"name": "tractor_wheels_a", "kind": "tractor_wheels", "maker": lambda rc, lod: tractor_parts(rc, lod, True), "bones_fn": std_bones,
     "actions_fn": lambda rc, info: {}, "paint": (0.12, 0.24, 0.46), "paint2": (0.78, 0.78, 0.76),
     "wheel": {"R": tyre(540, 85, 38)[0]}, "wheel_r_of": lambda nm: tyre(540, 85, 38)[0] if nm.startswith("r") else tyre(420, 85, 28)[0]})


# ====================================================================================================== parade tractor
def parade_tractor_parts(rc, lod):
    parts = []
    info = {"spec": None, "hubs": [], "wipers": [], "steering": None, "bones": [], "hinges": {}, "body_z": 0.8}
    yr, yf = -0.75, 1.15
    rspec = {"R": 0.66, "Rr": 0.36, "tw": 0.3, "style": "steel", "holes": 0, "tyre": "tractor", "lugs": 18, "lug_h": 0.045,
             "face_mat": "paint2", "barrel_mat": "paint2", "nuts": 8, "pcd": 0.16, "nut_r": 0.015, "hubcap": True, "cap_r": 0.09,
             "disc": False, "segs": 36}
    fspec = {"R": 0.36, "Rr": 0.2, "tw": 0.14, "style": "steel", "holes": 0, "face_mat": "paint2", "barrel_mat": "paint2", "nuts": 5,
             "pcd": 0.06, "hubcap": True, "cap_r": 0.06, "disc": False, "segs": 28}
    xr, xf = 0.72, 0.42
    for side, sn in ((-1, "l"), (1, "r")):
        wheel(parts, rspec, side, lod, "r" + sn, (side * xr, yr, rspec["R"]), False, info["hubs"])
        wheel(parts, fspec, side, lod, "f" + sn, (side * xf, yf, fspec["R"]), True, info["hubs"])
    seg = 2 if lod == 0 else 1
    # the rounded bonnet: a half cylinder on a box
    n = 16 if lod == 0 else 8
    prof = [(0.0, -0.95), (0.27, -0.95), (0.27, 0.95), (0.0, 0.95)]
    hood = bm_rbox((0.56, 1.75, 0.5), 0.2, seg + 1, (0, 0.5, 1.12))
    _add(parts, "hood", "body", hood, "paint")
    _add(parts, "hood", "body", bm_box((0.44, 1.7, 0.4), (0, 0.45, 0.72)), "trim")
    # radiator grille (curved front), the badge and side louvres
    gr = bm_rbox((0.5, 0.12, 0.62), 0.12, seg, (0, 1.36, 1.05))
    _add(parts, "hood", "body", gr, "paint")
    for k in range(9):
        _add(parts, "hood", "body", bm_box((0.012, 0.04, 0.48), (-0.18 + k * 0.045, 1.42, 1.02)), "trim")
    if lod == 0:
        tb = text_bm("TAMSIN", 0.05, 0.0)
        for v in tb.verts:
            v.co = V((-v.co.x, 1.43, 1.32 + v.co.y))
        pt = Part("badge", "body"); pt.add_bm(tb, "chrome"); tb.free(); parts.append(pt)
    # headlamps on brackets, the fuel tank, the seat on its spring, the steering column and wheel
    for sx in (1, -1):
        _add(parts, "hood", "body", bm_tube((sx * 0.2, 1.1, 1.2), (sx * 0.38, 1.18, 1.32), 0.015, 6), "trim")
        round_lamp(parts, "body", (sx * 0.4, 1.22, 1.32), 0.08, 1, lod)
    _add(parts, "hood", "body", bm_rbox((0.42, 0.5, 0.26), 0.08, seg, (0, -0.2, 1.42)), "paint")
    _add(parts, "seat", "body", bm_tube((0, -0.9, 0.95), (0, -1.15, 1.25), 0.03, 8), "trim")
    seat = bm_rbox((0.42, 0.38, 0.08), 0.06, seg, (0, -1.15, 1.3))
    for v in seat.verts:
        v.co.z += 0.05 * (abs(v.co.x) / 0.21) ** 2
    _add(parts, "seat", "body", seat, "trim_grey")
    if lod <= 1:
        info["steering"] = inter.steering_wheel(parts, (0.0, -0.55, 1.78), 30.0, lod, rim_r=0.2, col_len=0.9)
    # clamshell mudguards with the rear lamps
    for sx in (1, -1):
        arc_guard(parts, "guards", "body", (sx * xr, yr, rspec["R"]), rspec["R"] + 0.07, 0.38, 0, 180, "paint", lod)
        round_lamp(parts, "body", (sx * (xr + 0.1), yr - 0.62, 0.92), 0.04, -1, lod, "lamp_tail")
    _add(parts, "chassis", "body", bm_rbox((0.6, 0.6, 0.55), 0.08, seg, (0, yr, 0.7)), "trim")
    for sx in (1, -1):
        _add(parts, "chassis", "body", bm_tube((sx * 0.25, yr, 0.66), (sx * (xr - 0.08), yr, 0.66), 0.08, 10), "trim")
    _add(parts, "chassis", "body", bm_tube((-xf + 0.05, yf, 0.36), (xf - 0.05, yf, 0.36), 0.04, 8), "trim")
    _add(parts, "chassis", "body", bm_cyl(0.045, 0.045, 0.9, 10, 'Z', (0.18, 0.95, 1.75)), "metal")
    _add(parts, "chassis", "body", bm_cyl(0.06, 0.06, 0.08, 10, 'Z', (-0.15, 0.95, 1.42)), "trim")
    # footplates, drawbar and PTO
    for sx in (1, -1):
        _add(parts, "chassis", "body", bm_box((0.22, 0.6, 0.03), (sx * 0.38, -0.2, 0.62)), "metal")
    _add(parts, "chassis", "body", bm_box((0.1, 0.5, 0.06), (0, -1.45, 0.48)), "paint2")
    _add(parts, "pto", "pto", bm_cyl(0.03, 0.03, 0.18, 10, 'Y', (0, -1.35, 0.62)), "metal")
    info["bones"].append({"name": "pto", "head": (0, -1.26, 0.62), "tail": (0, -1.5, 0.62), "parent": "body"})
    info["bones"].append({"name": "hitch", "head": (0, -1.66, 0.48), "tail": (0, -1.66, 0.78), "parent": "root"})
    info["pto"] = True
    # a festival rosette on the grille
    if lod == 0:
        ros, _ = bm_lathe([(0.0, 0.0), (0.07, 0.0)], 12, axis='Y')
        bmesh.ops.transform(ros, matrix=Matrix.Translation((0.0, 1.45, 0.92)), verts=ros.verts)
        _add(parts, "rosette", "body", ros, "flag_c")
    return parts, info


add({"name": "parade_tractor_a", "kind": "tractor", "maker": parade_tractor_parts, "bones_fn": std_bones, "actions_fn": tractor_actions,
     "paint": (0.62, 0.06, 0.04), "paint2": (0.86, 0.80, 0.62), "wheel": {"R": 0.66}, "lock": 40,
     "wheel_r_of": lambda nm: 0.66 if nm.startswith("r") else 0.36})


# ============================================================================================================ trailers
def trailer_parts(rc, lod, parade=False):
    parts = []
    info = {"spec": None, "hubs": [], "wipers": [], "steering": None, "bones": [], "hinges": {}, "body_z": 0.9}
    if not parade:
        L, W = 6.6, 2.35
        bed_y0, bed_y1, zf, zs = 2.15, -3.25, 1.02, 0.62     # bed front and back, floor, side height
        axles = [(-1.15, "f"), (-2.15, "r")]
        R_ = tyre(400, 80, 15)
        spec = {"R": R_[0], "Rr": R_[1], "tw": 0.38, "style": "steel", "holes": 6, "nuts": 6, "pcd": 0.1, "face_mat": "paint2",
                "barrel_mat": "paint2", "disc": False}
        hitch_y = 3.3
    else:
        L, W = 5.4, 2.2
        bed_y0, bed_y1, zf, zs = 1.55, -2.65, 0.78, 0.25
        axles = [(-1.4, "r")]
        R_ = tyre(185, 80, 14)
        spec = {"R": R_[0], "Rr": R_[1], "tw": 0.19, "style": "steel", "holes": 8, "nuts": 4, "face_mat": "paint2", "barrel_mat": "paint2",
                "disc": False}
        hitch_y = 2.7
    x = W * 0.5 - spec["tw"] * 0.5 - (0.05 if not parade else 0.12)
    for (yy, tag) in axles:
        for side, sn in ((-1, "l"), (1, "r")):
            wheel(parts, spec, side, lod, tag + sn, (side * x, yy, spec["R"]), False, info["hubs"])
    tip = "tip_bed" if not parade else "body"
    seg = 1
    # chassis and drawbar to the hitch eye
    for sx in (1, -1):
        _add(parts, "chassis", "body", bm_box((0.12, bed_y0 - bed_y1 - 0.2, 0.16), (sx * 0.55, (bed_y0 + bed_y1) * 0.5, zf - 0.17)), "trim")
        _add(parts, "chassis", "drawbar", bm_tube((sx * 0.5, bed_y0 - 0.1, zf - 0.2), (0, hitch_y - 0.15, zf - 0.38), 0.05, 8), "paint2")
    eye = bm_lathe([(0.04, -0.02), (0.07, -0.02), (0.07, 0.02), (0.04, 0.02), (0.04, -0.02)], 14, axis='Z')[0]
    bmesh.ops.transform(eye, matrix=Matrix.Translation((0, hitch_y, zf - 0.38)), verts=eye.verts)
    _add(parts, "chassis", "drawbar", eye, "metal")
    _add(parts, "chassis", "drawbar", bm_box((0.08, 0.1, 0.5), (0, hitch_y - 0.6, zf - 0.6)), "trim")       # parking leg
    for (yy, tag) in axles:
        _add(parts, "chassis", "body", bm_tube((-x + 0.1, yy, spec["R"]), (x - 0.1, yy, spec["R"]), 0.05, 8), "trim")
    # the bed: floor, sides, front board, tailboard (paint, or timber on the parade trailer)
    sidem = "paint" if not parade else "wood"
    floor = bm_box((W, bed_y0 - bed_y1, 0.06), (0, (bed_y0 + bed_y1) * 0.5, zf))
    _add(parts, "bed", tip, floor, sidem if parade else "metal")
    for sx in (1, -1):
        sb = bm_rbox((0.05, bed_y0 - bed_y1, zs), 0.01, seg, (sx * (W * 0.5 - 0.025), (bed_y0 + bed_y1) * 0.5, zf + zs * 0.5))
        _add(parts, "bed", tip, sb, sidem)
        if lod <= 1 and not parade:
            for k in range(1, 6):
                yy = bed_y1 + (bed_y0 - bed_y1) * k / 6
                _add(parts, "bed", tip, bm_box((0.03, 0.06, zs), (sx * (W * 0.5 + 0.01), yy, zf + zs * 0.5)), "paint")
            _add(parts, "bed", tip, bm_box((0.05, bed_y0 - bed_y1, 0.05), (sx * (W * 0.5 + 0.0), (bed_y0 + bed_y1) * 0.5, zf + zs)), "paint2")
    _add(parts, "bed", tip, bm_box((W, 0.05, zs + (0.4 if not parade else 0.0)), (0, bed_y0, zf + (zs + (0.4 if not parade else 0.0)) * 0.5)), sidem)
    _add(parts, "bed", tip, bm_box((W - 0.1, 0.05, zs), (0, bed_y1, zf + zs * 0.5)), sidem)
    # mudguards and lamps
    for sx in (1, -1):
        y_mid = sum(a for a, _ in axles) / len(axles)
        span = (abs(axles[0][0] - axles[-1][0]) + spec["R"] * 2 + 0.2)
        _add(parts, "chassis", "body", bm_box((spec["tw"] + 0.12, span, 0.02), (sx * x, y_mid, spec["R"] * 2 + 0.06)), "trim")
        lamp_box(parts, tip, (sx * (W * 0.5 - 0.15), bed_y1 - 0.04, zf + 0.12), (0.14, 0.03, 0.08), "lamp_tail")
        lamp_box(parts, tip, (sx * (W * 0.5 - 0.32), bed_y1 - 0.04, zf + 0.12), (0.1, 0.03, 0.08), "lamp_ind_r" if sx > 0 else "lamp_ind_l")
    _add(parts, "plates", tip, bm_box((0.52, 0.01, 0.11), (0, bed_y1 - 0.04, zf + 0.12)), "plate")
    if not parade:
        # the tipping ram
        _add(parts, "chassis", "body", bm_cyl(0.07, 0.07, 0.5, 10, 'Z', (0, bed_y0 - 0.6, zf - 0.1)), "metal")
        info["bones"].append({"name": "tip_bed", "head": (0, bed_y1 + 0.05, zf - 0.05), "tail": (0.3, bed_y1 + 0.05, zf - 0.05), "parent": "body"})
        info["hinges"]["tip_bed"] = (0, False, 48.0)
    else:
        # festival: straw bales, bunting on poles, the banner
        for (bx, by) in ((-0.55, 0.9), (0.55, 0.9), (-0.55, -0.2), (0.55, -0.2), (0.0, -1.6)):
            _add(parts, "bales", "body", bm_rbox((0.9, 0.45, 0.36), 0.03, 1, (bx, by, zf + 0.21)), "straw")
        poles = [(sx * (W * 0.5 - 0.05), yy) for sx in (1, -1) for yy in (bed_y0 - 0.05, bed_y1 + 0.05)]
        for (px, py) in poles:
            _add(parts, "bunting", "body", bm_tube((px, py, zf), (px, py, zf + 1.45), 0.02, 6), "wood")
        cols = ["flag_a", "flag_b", "flag_c"]
        for (a, b) in ((poles[0], poles[1]), (poles[2], poles[3]), (poles[0], poles[2]), (poles[1], poles[3])):
            pa, pb = V((a[0], a[1], zf + 1.42)), V((b[0], b[1], zf + 1.42))
            n = max(3, int((pb - pa).length / 0.32))
            for k in range(n):
                t0, t1 = k / n, (k + 0.8) / n
                sag = lambda t: -0.25 * 4 * t * (1 - t)
                p0 = pa.lerp(pb, t0) + V((0, 0, sag(t0)))
                p1 = pa.lerp(pb, t1) + V((0, 0, sag(t1)))
                tip_ = (p0 + p1) * 0.5 + V((0, 0, -0.2))
                bm = bmesh.new()
                bm.faces.new([bm.verts.new(p0), bm.verts.new(p1), bm.verts.new(tip_)])
                _add(parts, "bunting", "body", bm, cols[k % 3])
            line = bm_tube(pa, pb, 0.004, 4)
            _add(parts, "bunting", "body", line, "trim")
        for sx in (1, -1):
            bn = bm_box((0.01, 2.6, 0.36), (sx * (W * 0.5 + 0.02), -0.5, zf - 0.05))
            _add(parts, "banner", "body", bn, "sheet_white")
            if lod <= 1:
                tb = text_bm("HALLOWAY FESTIVAL", 0.2, 0.0)
                pt = Part("letters", "body")
                for v in tb.verts:
                    a, b = v.co.x, v.co.y
                    v.co = V((sx * (W * 0.5 + 0.03), -0.5 + (a if sx > 0 else -a), zf - 0.05 + b))
                tb.normal_update()
                for f in tb.faces:
                    if f.normal.x * sx < 0:
                        f.normal_flip()
                pt.add_bm(tb, "flag_a"); tb.free(); parts.append(pt)
    info["bones"].append({"name": "drawbar", "head": (0, bed_y0, zf - 0.2), "tail": (0, bed_y0, zf + 0.1), "parent": "body"})
    info["bones"].append({"name": "hitch", "head": (0, hitch_y, zf - 0.38), "tail": (0, hitch_y, zf - 0.08), "parent": "root"})
    return parts, info


def trailer_actions(rc, info):
    A = {}
    if "tip_bed" in info.get("hinges", {}):
        a = math.radians(info["hinges"]["tip_bed"][2])
        A["tip_raise"] = {"tip_bed": [(1, 0.0), (60, a)]}
        A["tip_lower"] = {"tip_bed": [(1, a), (60, 0.0)]}
    return A


add({"name": "tractor_trailer_a", "kind": "trailer", "maker": trailer_parts, "bones_fn": std_bones, "actions_fn": trailer_actions,
     "paint": (0.55, 0.08, 0.06), "paint2": (0.1, 0.1, 0.1), "wheel": {"R": tyre(400, 80, 15)[0]}})
add({"name": "parade_trailer_a", "kind": "trailer", "maker": lambda rc, lod: trailer_parts(rc, lod, True), "bones_fn": std_bones,
     "actions_fn": trailer_actions, "paint": (0.55, 0.08, 0.06), "paint2": (0.2, 0.2, 0.2), "wheel": {"R": tyre(185, 80, 14)[0]},
     "mat_colours": {"wood": (0.42, 0.28, 0.16)}})


# ============================================================================================================ motorcycle
def moto_parts(rc, lod):
    parts = []
    info = {"spec": None, "hubs": [], "wipers": [], "steering": None, "bones": [], "hinges": {}, "body_z": 0.6}
    yf, yr = 0.72, -0.71                   # 1.43 m wheelbase
    fR = tyre(120, 70, 17); rR = tyre(180, 55, 17)
    fs = {"R": fR[0], "Rr": fR[1], "tw": 0.12, "style": "alloy5", "spokes": 3, "nuts": 0, "segs": 40, "disc": True, "caliper_deg": 95}
    rs = {"R": rR[0], "Rr": rR[1], "tw": 0.18, "style": "alloy5", "spokes": 3, "nuts": 0, "segs": 40, "disc": True, "caliper_deg": 40, "hub_bone": "body"}
    rake = math.radians(25.0)
    ax = V((0, math.sin(rake), math.cos(rake)))          # steering axis: tipped back
    ax = V((0, -math.sin(rake), math.cos(rake)))
    hf = (0.0, yf, fs["R"])
    vk_wheels.build_wheel(fs, 1, lod, "f", (0.0, yf, fs["R"]), True, parts=parts, bone="wheel_f")
    vk_wheels.build_wheel(rs, 1, lod, "r", (0.0, yr, rs["R"]), False, parts=parts, bone="wheel_r")
    # put the wheels back on the centre line (build_wheel offsets the face outward)
    for p in parts:
        if p.bone in ("wheel_f", "wheel_r") or p.name.startswith("caliper"):
            pass
    info["hubs"] = [("f", (0.0, yf, fs["R"]), True), ("r", (0.0, yr, rs["R"]), False)]
    info["steer_axis"] = {"f": tuple(ax)}
    head = V((0, yf, fs["R"])) + ax * 0.78                 # top of the forks (steering head)
    seg = 2 if lod == 0 else 1
    # forks, yokes, bars, lamp, clocks: on the steering bone
    for sx in (1, -1):
        _add(parts, "forks", "steer_f", bm_tube((sx * 0.1, yf, fs["R"]), (sx * 0.1, head.y, head.z), 0.022, 10), "chrome")
        _add(parts, "forks", "steer_f", bm_tube((sx * 0.1, yf + 0.02, fs["R"] + 0.02), (sx * 0.1, yf - 0.1, fs["R"] + 0.3), 0.03, 10), "trim")
    _add(parts, "forks", "steer_f", bm_rbox((0.26, 0.08, 0.04), 0.015, 1, (0, head.y, head.z)), "trim")
    _add(parts, "forks", "steer_f", bm_tube((-0.36, head.y - 0.12, head.z + 0.1), (0.36, head.y - 0.12, head.z + 0.1), 0.012, 8), "trim")
    for sx in (1, -1):
        _add(parts, "forks", "steer_f", bm_cyl(0.017, 0.017, 0.12, 8, 'X', (sx * 0.32, head.y - 0.12, head.z + 0.1)), "rubber")
        _add(parts, "forks", "steer_f", bm_tube((sx * 0.25, head.y - 0.1, head.z + 0.1), (sx * 0.28, head.y - 0.05, head.z + 0.3), 0.006, 5), "trim")
        _add(parts, "forks", "steer_f", bm_rbox((0.1, 0.02, 0.06), 0.01, 1, (sx * 0.3, head.y - 0.05, head.z + 0.32)), "trim")
    round_lamp(parts, "steer_f", (0, head.y + 0.12, head.z - 0.05), 0.085, 1, lod)
    _add(parts, "forks", "steer_f", bm_rbox((0.18, 0.06, 0.1), 0.02, 1, (0, head.y - 0.02, head.z + 0.1)), "dash")
    for sx in (1, -1):
        _add(parts, "forks", "steer_f", bm_box((0.04, 0.03, 0.03), (sx * 0.14, head.y + 0.06, head.z - 0.12)), "lamp_ind_r" if sx > 0 else "lamp_ind_l")
    # frame, tank, seat, tail
    piv = V((0, -0.12, 0.42))
    for sx in (1, -1):
        _add(parts, "frame", "body", bm_tube((sx * 0.07, head.y, head.z - 0.05), (sx * 0.12, piv.y + 0.05, piv.z + 0.1), 0.022, 8), "trim")
        _add(parts, "frame", "body", bm_tube((sx * 0.06, head.y - 0.02, head.z - 0.18), (sx * 0.12, piv.y + 0.1, 0.36), 0.02, 8), "trim")
        _add(parts, "frame", "body", bm_tube((sx * 0.1, piv.y, piv.z + 0.15), (sx * 0.08, -0.62, 0.86), 0.014, 6), "trim")
    tank = bm_rbox((0.32, 0.56, 0.26), 0.11, seg + 1, (0, head.y - 0.36, head.z - 0.04))
    for v in tank.verts:
        t = (v.co.y - (head.y - 0.36)) / 0.28          # teardrop: wide and tall at the front, tapering to the seat
        v.co.z += 0.04 * t
        v.co.x *= 1.0 + 0.12 * t
    # front mudguard on the forks and a radiator in front of the engine
    mg = bm_lathe([(fs["R"] + 0.03, -0.055), (fs["R"] + 0.05, -0.06), (fs["R"] + 0.05, 0.06), (fs["R"] + 0.03, 0.055)], 12, axis='X',
                  a0=0.3, a1=1.9, closed=False)[0]
    bmesh.ops.transform(mg, matrix=Matrix.Translation((0, yf, fs["R"])), verts=mg.verts)
    _add(parts, "forks", "steer_f", mg, "paint")
    _add(parts, "engine", "body", bm_rbox((0.3, 0.05, 0.26), 0.02, 1, (0, 0.36, 0.62)), "trim")
    _add(parts, "tank", "body", tank, "paint")
    seat = bm_rbox((0.28, 0.6, 0.09), 0.04, seg, (0, -0.32, 0.86))
    _add(parts, "seat", "body", seat, "seat")
    tail = bm_rbox((0.2, 0.42, 0.12), 0.05, seg, (0, -0.75, 0.9))
    for v in tail.verts:
        if v.co.y < -0.75:
            v.co.x *= 0.6; v.co.z += 0.04
    _add(parts, "tank", "body", tail, "paint")
    lamp_box(parts, "body", (0, -0.96, 0.92), (0.1, 0.02, 0.04), "lamp_tail")
    _add(parts, "lamps", "body", bm_box((0.1, 0.02, 0.02), (0, -0.963, 0.89)), "lamp_brake")
    _add(parts, "plates", "body", bm_box((0.2, 0.01, 0.13), (0, -1.0, 0.76)), "plate")
    _add(parts, "plates", "body", bm_tube((0, -0.9, 0.86), (0, -0.99, 0.8), 0.01, 5), "trim")
    for sx in (1, -1):
        _add(parts, "lamps", "body", bm_box((0.03, 0.04, 0.03), (sx * 0.12, -0.95, 0.85)), "lamp_ind_r" if sx > 0 else "lamp_ind_l")
    # engine: block, cylinders, cases, the exhaust down and back to the silencer
    _add(parts, "engine", "body", bm_rbox((0.34, 0.4, 0.3), 0.04, seg, (0, 0.08, 0.42)), "metal")
    for k in range(2):
        _add(parts, "engine", "body", bm_rbox((0.3, 0.12, 0.22), 0.03, 1, (0, 0.2 - k * 0.0, 0.64 + k * 0.0)), "metal")
    if lod == 0:
        for k in range(6):
            _add(parts, "engine", "body", bm_box((0.33, 0.13, 0.008), (0, 0.2, 0.56 + k * 0.03)), "trim")
    _add(parts, "engine", "body", bm_cyl(0.11, 0.11, 0.04, 16, 'X', (-0.19, 0.0, 0.38)), "chrome")
    _add(parts, "exhaust", "body", bm_tube((0.08, 0.3, 0.55), (0.12, 0.28, 0.24), 0.025, 8), "chrome")
    _add(parts, "exhaust", "body", bm_tube((0.12, 0.28, 0.24), (0.16, -0.3, 0.28), 0.025, 8), "chrome")
    _add(parts, "exhaust", "body", bm_cyl(0.055, 0.05, 0.42, 14, 'Y', (0.17, -0.5, 0.36)), "metal")
    # swingarm (on the body: the rear wheel spins on its own bone)
    for sx in (1, -1):
        _add(parts, "swingarm", "body", bm_box((0.04, piv.y - yr, 0.06), (sx * 0.12, (piv.y + yr) * 0.5, (piv.z + rs["R"]) * 0.5)), "metal")
    _add(parts, "swingarm", "body", bm_tube((0.0, -0.3, 0.5), (0.0, -0.55, 0.78), 0.03, 8), "lamp_ind_r")    # the shock spring
    # foot pegs, side stand, mirrors done; rear hugger and the chain guard
    for sx in (1, -1):
        _add(parts, "pegs", "body", bm_tube((sx * 0.1, -0.12, 0.34), (sx * 0.22, -0.12, 0.34), 0.012, 6), "metal")
    _add(parts, "stand", "stand", bm_tube((-0.12, -0.05, 0.3), (-0.14, -0.3, 0.12), 0.012, 6), "metal")
    info["bones"].append({"name": "stand", "head": (-0.12, -0.05, 0.3), "tail": (-0.12, -0.35, 0.3), "parent": "body"})
    info["steering_parent"] = "steer_f"
    info["steer_parent"] = "body"
    info["wheel_parent"] = "body"
    return parts, info


def moto_bones(rc, info):
    b = std_bones(rc, info)
    return b


add({"name": "motorcycle_a", "kind": "motorcycle", "maker": moto_parts, "bones_fn": moto_bones,
     "actions_fn": lambda rc, info: {"steer_left": {"steer_f": [(1, 0.0), (18, math.radians(28))]},
                                     "steer_right": {"steer_f": [(1, 0.0), (18, -math.radians(28))]},
                                     "stand_down": {"stand": [(1, 0.0), (18, math.radians(-75))]}},
     "paint": (0.08, 0.08, 0.09), "paint2": (0.55, 0.06, 0.04), "wheel": {"R": tyre(120, 70, 17)[0]},
     "wheel_r_of": lambda nm: tyre(120, 70, 17)[0] if nm == "f" else tyre(180, 55, 17)[0]})


# ============================================================================================================ farm quad
def quad_parts(rc, lod):
    parts = []
    info = {"spec": None, "hubs": [], "wipers": [], "steering": None, "bones": [], "hinges": {}, "body_z": 0.6}
    R = 0.32
    spec = {"R": R, "Rr": 0.152, "tw": 0.22, "style": "steel", "holes": 6, "tyre": "tractor", "lugs": 14, "lug_h": 0.018,
            "face_mat": "paint2", "barrel_mat": "paint2", "nuts": 4, "pcd": 0.045, "disc": False, "segs": 28}
    yf, yr = 0.62, -0.6
    x = 0.47
    for side, sn in ((-1, "l"), (1, "r")):
        wheel(parts, spec, side, lod, "f" + sn, (side * x, yf, R), True, info["hubs"])
        wheel(parts, spec, side, lod, "r" + sn, (side * x, yr, R), False, info["hubs"])
    seg = 2 if lod == 0 else 1
    # frame, engine, the plastic body with its front and rear fenders
    _add(parts, "frame", "body", bm_box((0.4, 1.3, 0.18), (0, 0, 0.36)), "trim")
    _add(parts, "frame", "body", bm_rbox((0.36, 0.4, 0.32), 0.04, 1, (0, -0.05, 0.5)), "metal")
    for (yy, ln) in ((yf + 0.05, 0.62), (yr - 0.05, 0.66)):
        fd = bm_rbox((1.18, ln, 0.16), 0.06, seg, (0, yy, R * 2 + 0.06))
        for v in fd.verts:
            if abs(v.co.x) > 0.3:
                v.co.z -= 0.08 * (abs(v.co.x) - 0.3) / 0.29
        _add(parts, "body", "body", fd, "paint")
    _add(parts, "body", "body", bm_rbox((0.42, 0.8, 0.24), 0.08, seg, (0, 0.0, 0.74)), "paint")
    _add(parts, "seat", "body", bm_rbox((0.32, 0.62, 0.1), 0.05, seg, (0, -0.2, 0.9)), "seat")
    # racks front and rear
    for (yy, ln) in ((yf + 0.05, 0.5), (yr - 0.05, 0.55)):
        for sx in (1, -1):
            _add(parts, "racks", "body", bm_tube((sx * 0.4, yy - ln * 0.5, 0.85), (sx * 0.4, yy + ln * 0.5, 0.85), 0.012, 6), "trim")
        for k in range(5):
            yk = yy - ln * 0.5 + ln * k / 4
            _add(parts, "racks", "body", bm_tube((-0.4, yk, 0.85), (0.4, yk, 0.85), 0.01, 5), "trim")
    # bars on the steering bone, lamps in the nose
    hb = V((0, 0.32, 0.88))
    info["bones"].append({"name": "handlebar", "head": tuple(hb), "tail": (0, 0.3, 1.1), "parent": "body"})
    _add(parts, "bars", "handlebar", bm_tube((0, 0.32, 0.86), (0, 0.3, 1.0), 0.02, 8), "trim")
    _add(parts, "bars", "handlebar", bm_tube((-0.38, 0.25, 1.02), (0.38, 0.25, 1.02), 0.014, 8), "trim")
    for sx in (1, -1):
        _add(parts, "bars", "handlebar", bm_cyl(0.019, 0.019, 0.11, 8, 'X', (sx * 0.34, 0.25, 1.02)), "rubber")
    _add(parts, "bars", "handlebar", bm_rbox((0.24, 0.14, 0.1), 0.03, 1, (0, 0.34, 1.02)), "paint")
    for sx in (1, -1):
        round_lamp(parts, "body", (sx * 0.14, yf + 0.36, 0.66), 0.045, 1, lod)
        lamp_box(parts, "body", (sx * 0.2, yr - 0.38, 0.66), (0.07, 0.02, 0.04), "lamp_tail")
    _add(parts, "frame", "body", bm_rbox((0.6, 0.06, 0.12), 0.02, 1, (0, yf + 0.38, 0.45)), "trim")      # bumper
    info["handlebar"] = True
    return parts, info


def quad_actions(rc, info):
    import vk_build
    lock = math.radians(32)
    A = {}
    for nm, sg in (("steer_left", 1), ("steer_right", -1)):
        A[nm] = {"steer_fl": [(1, 0.0), (18, sg * lock)], "steer_fr": [(1, 0.0), (18, sg * lock)], "handlebar": [(1, 0.0), (18, sg * lock)]}
    return A


add({"name": "farm_quad_a", "kind": "quad", "maker": quad_parts, "bones_fn": std_bones, "actions_fn": quad_actions,
     "paint": (0.12, 0.30, 0.14), "paint2": (0.12, 0.12, 0.12), "wheel": {"R": 0.32}})


# ---------------------------------------------------------------------------------------------- second pass (detail)
# The tractors were rebuilt in detail in vk_tractor.py; these entries replace the first-pass ones above.
import vk_tractor
add({"name": "tractor_a", "kind": "tractor", "maker": vk_tractor.tractor_parts, "bones_fn": tractor_bones, "actions_fn": tractor_actions,
     "paint": (0.12, 0.24, 0.46), "paint2": (0.80, 0.80, 0.78), "wheel": {"R": tyre(467, 85, 38)[0]}, "wiper_sweep": 100,
     "wheel_r_of": lambda nm: tyre(467, 85, 38)[0] if nm.startswith("r") else tyre(378, 85, 28)[0], "lock": 40,
     "condition": vk_tractor.tractor_condition, "dirt": 0.85, "ao_dist": 0.6})
add({"name": "tractor_wheels_a", "kind": "tractor_wheels", "maker": lambda rc, lod: vk_tractor.tractor_parts(rc, lod, True),
     "bones_fn": std_bones, "actions_fn": lambda rc, info: {}, "paint": (0.12, 0.24, 0.46), "paint2": (0.80, 0.80, 0.78),
     "wheel": {"R": tyre(467, 85, 38)[0]}, "dirt": 0.85,
     "wheel_r_of": lambda nm: tyre(467, 85, 38)[0] if nm.startswith("r") else tyre(378, 85, 28)[0]})
add({"name": "parade_tractor_a", "kind": "tractor", "maker": vk_tractor.parade_tractor_parts, "bones_fn": std_bones,
     "actions_fn": tractor_actions, "paint": (0.66, 0.07, 0.04), "paint2": (0.88, 0.82, 0.64), "wheel": {"R": 0.655}, "lock": 40,
     "wheel_r_of": lambda nm: 0.655 if nm.startswith("r") else 0.36, "condition": lambda co, n: 0.92, "dirt": 0.25})

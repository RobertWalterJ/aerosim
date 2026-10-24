# AeroSim vehicle kit, sites lane additions for the vehicle brief (godot/docs/CLAUDE-VEHICLE-ASSETS.md on lane/notify):
#   farm_trailer_a     a 3.0 m single-axle general-purpose farm trailer: timber deck, galvanised mesh sides and a rear ramp
#                      gate (the small livestock / flatbed trailer a tractor or pickup pulls; proportions from the common
#                      10 x 5 ft class)
#   hay_trailer_a      a 7.3 m tandem flat bale trailer with a ladder headboard, loaded with three layers of small square bales
#   farm_truck_a       the older farm pickup (pickup_b's cab) on a flatbed: timber deck, headache rack, side toolbox
#   car_estate_roofbox_a  car_estate_a with a black roof box on its rails
#   car_estate_dogguard_a car_estate_a with a dog guard behind the rear seats
#   cruiser_1984_flat  the 1984 cruiser with its rear left tyre flat (the story's "one tyre flat")
# Frame and rig as the rest of the kit (vk_build.py): x right, y forward, z up while building; std_bones; LOD0..2.
import math
import bmesh
from mathutils import Vector as V, Matrix
from vk_core import Part, bm_rbox, bm_box, bm_cyl, bm_tube, bm_sweep, bm_lathe
from vk_recipes import add, tyre, RECIPES
import vk_wheels
from vk_recipes_custom import std_bones, trailer_actions
import vk_recipes_cars as C
import vk_extras as X


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


def mesh_panel(parts, name, bone, x, y0, y1, z0, z1, lod, mat="metal", frame="metal"):
    """a galvanised mesh side panel in the y-z plane at x: a tube frame and a grid of bars"""
    tube(parts, name, bone, (x, y0, z0), (x, y1, z0), 0.02, frame, 6)
    tube(parts, name, bone, (x, y0, z1), (x, y1, z1), 0.02, frame, 6)
    tube(parts, name, bone, (x, y0, z0), (x, y0, z1), 0.02, frame, 6)
    tube(parts, name, bone, (x, y1, z0), (x, y1, z1), 0.02, frame, 6)
    ny = int(abs(y1 - y0) / (0.1 if lod == 0 else 0.3))
    nz = int(abs(z1 - z0) / (0.1 if lod == 0 else 0.3))
    if lod >= 2:
        box(parts, name, bone, (0.006, abs(y1 - y0), abs(z1 - z0)), (x, (y0 + y1) / 2, (z0 + z1) / 2), mat)
        return
    for k in range(1, ny):
        y = y0 + (y1 - y0) * k / ny
        box(parts, name, bone, (0.006, 0.006, abs(z1 - z0)), (x, y, (z0 + z1) / 2), mat)
    for k in range(1, nz):
        z = z0 + (z1 - z0) * k / nz
        box(parts, name, bone, (0.006, abs(y1 - y0), 0.006), (x, (y0 + y1) / 2, z), mat)


def _chassis(parts, info, W, y0, y1, zf, axles, spec, hitch_y, lod):
    x = W * 0.5 - spec["tw"] * 0.5 + 0.12
    for (yy, tag) in axles:
        for side, sn in ((-1, "l"), (1, "r")):
            vk_wheels.build_wheel(spec, side, lod, tag + sn, (side * x, yy, spec["R"]), False, parts=parts)
            info["hubs"].append((tag + sn, (side * x, yy, spec["R"]), False))
    for sx in (1, -1):
        box(parts, "chassis", "body", (0.08, y0 - y1 - 0.1, 0.14), (sx * 0.45, (y0 + y1) * 0.5, zf - 0.13), "paint2")
        tube(parts, "chassis", "drawbar", (sx * 0.45, y0 - 0.1, zf - 0.14), (0, hitch_y - 0.18, zf - 0.32), 0.04, "paint2", 8)
        for (yy, tag) in axles:
            for k in range(3 if lod == 0 else 1):
                box(parts, "chassis", "body", (0.06, 0.85 - k * 0.2, 0.012), (sx * 0.45, yy, spec["R"] + 0.06 + k * 0.014), "metal")
            box(parts, "chassis", "body", (0.07, 0.1, zf - 0.2 - spec["R"] - 0.04), (sx * 0.45, yy, (zf - 0.2 + spec["R"] + 0.04) * 0.5 + 0.01), "paint2")
    for k in range(5):
        yy = y1 + 0.1 + (y0 - y1 - 0.2) * k / 4
        box(parts, "chassis", "body", (0.98, 0.07, 0.08), (0, yy, zf - 0.11), "paint2")
    for (yy, tag) in axles:
        tube(parts, "chassis", "body", (-x + 0.1, yy, spec["R"]), (x - 0.1, yy, spec["R"]), 0.04, "paint2", 10)
    eye = bm_lathe([(0.03, -0.022), (0.065, -0.022), (0.065, 0.022), (0.03, 0.022), (0.03, -0.022)], 14, axis='Z')[0]
    bmesh.ops.transform(eye, matrix=Matrix.Translation((0, hitch_y, zf - 0.32)), verts=eye.verts)
    _add(parts, "chassis", "drawbar", eye, "metal")
    box(parts, "chassis", "drawbar", (0.12, 0.25, 0.08), (0, hitch_y - 0.2, zf - 0.32), "paint2")
    jl = zf - 0.3 - 0.03                    # the jack leg reaches the ground: foot plate at 0..0.02 m
    _add(parts, "chassis", "drawbar", bm_cyl(0.03, 0.03, jl, 10, 'Z', (0.22, y0 + 0.4, 0.02 + jl * 0.5)), "metal")
    _add(parts, "chassis", "drawbar", bm_cyl(0.06, 0.06, 0.02, 12, 'Z', (0.22, y0 + 0.4, 0.01)), "metal")
    # mudguards, lamp boards, plate
    for sx in (1, -1):
        y_mid = sum(a for a, _ in axles) / len(axles)
        span = (abs(axles[0][0] - axles[-1][0]) + spec["R"] * 2 + 0.25)
        box(parts, "guards", "body", (spec["tw"] + 0.12, span, 0.02), (sx * x, y_mid, spec["R"] * 2 + 0.06), "metal", 0.008)
        box(parts, "guards", "body", (0.05, 0.06, spec["R"] * 2 + 0.06 - zf + 0.1), (sx * (x - spec["tw"] * 0.5 - 0.04), y_mid, (spec["R"] * 2 + 0.06 + zf - 0.1) / 2), "metal")
        box(parts, "lamps", "body", (0.16, 0.04, 0.1), (sx * (W * 0.5 - 0.15), y1 - 0.05, zf - 0.1), "trim", 0.01)
        box(parts, "lamps", "body", (0.07, 0.008, 0.07), (sx * (W * 0.5 - 0.19), y1 - 0.074, zf - 0.1), "lamp_tail")
        box(parts, "lamps", "body", (0.06, 0.008, 0.07), (sx * (W * 0.5 - 0.115), y1 - 0.074, zf - 0.1), "lamp_ind_r" if sx > 0 else "lamp_ind_l")
    box(parts, "plates", "body", (0.52, 0.01, 0.11), (0, y1 - 0.06, zf - 0.2), "plate")
    info["bones"].append({"name": "drawbar", "head": (0, y0, zf - 0.2), "tail": (0, y0, zf + 0.1), "parent": "body"})
    info["bones"].append({"name": "hitch", "head": (0, hitch_y, zf - 0.32), "tail": (0, hitch_y, zf - 0.02), "parent": "root"})


def farm_trailer_parts(rc, lod):
    """3.0 x 1.5 m deck, single axle, galvanised mesh sides 0.9 m high, a rear ramp gate hinged at the bottom"""
    parts = []
    info = {"spec": None, "hubs": [], "wipers": [], "steering": None, "bones": [], "hinges": {}, "body_z": 0.7}
    W, y0, y1, zf = 1.62, 1.5, -1.5, 0.62
    R_ = tyre(155, 80, 13)
    spec = {"R": R_[0], "Rr": R_[1], "tw": 0.155, "style": "steel", "holes": 4, "nuts": 4, "face_mat": "rim_steel",
            "barrel_mat": "rim_steel", "disc": False, "sidewall": "ROADSTAR 155R13"}
    _chassis(parts, info, W, y0, y1, zf, [(-0.15, "r")], spec, 2.55, lod)
    n = 10 if lod == 0 else 4
    for k in range(n):
        xx = -W * 0.5 + W * (k + 0.5) / n
        box(parts, "bed", "body", (W / n - 0.01, y0 - y1, 0.035), (xx, (y0 + y1) * 0.5, zf), "wood")
    box(parts, "bed", "body", (W + 0.04, y0 - y1 + 0.04, 0.05), (0, (y0 + y1) * 0.5, zf - 0.035), "metal")
    zt = zf + 0.9
    for sx in (1, -1):
        mesh_panel(parts, "sides", "body", sx * (W * 0.5 + 0.01), y0, y1, zf + 0.02, zt, lod)
        for yy in (y0, (y0 + y1) / 2, y1):
            box(parts, "sides", "body", (0.05, 0.05, 0.92), (sx * (W * 0.5 + 0.015), yy, zf + 0.46), "metal")
    # front panel (mesh) and the rear ramp gate
    for k in range(9 if lod == 0 else 3):
        x = -W * 0.5 + W * (k + 0.5) / (9 if lod == 0 else 3)
        box(parts, "front", "body", (0.006, 0.006, 0.88), (x, y0, zf + 0.46), "metal")
    for z in (zf + 0.04, zf + 0.46, zt):
        tube(parts, "front", "body", (-W * 0.5, y0, z), (W * 0.5, y0, z), 0.02, "metal", 6)
    box(parts, "gate", "tailgate", (W - 0.06, 0.05, 0.9), (0, y1 - 0.02, zf + 0.47), "metal", 0.01)
    for k in range(1, 6):
        box(parts, "gate", "tailgate", (W - 0.1, 0.012, 0.02), (0, y1 - 0.05, zf + 0.04 + k * 0.17), "trim_grey")
    info["bones"].append({"name": "tailgate", "head": (0, y1 - 0.02, zf), "tail": (0.3, y1 - 0.02, zf), "parent": "body"})
    info["hinges"]["tailgate"] = (0, True, 75.0)
    return parts, info


def hay_trailer_parts(rc, lod):
    """7.3 x 2.45 m flat bale trailer on tandem axles, ladder headboard, three layers of small square bales"""
    parts = []
    info = {"spec": None, "hubs": [], "wipers": [], "steering": None, "bones": [], "hinges": {}, "body_z": 0.9}
    W, y0, y1, zf = 2.45, 3.3, -4.0, 1.0
    R_ = tyre(400, 60, 15)
    spec = {"R": R_[0], "Rr": R_[1], "tw": 0.3, "style": "steel", "holes": 6, "nuts": 6, "pcd": 0.1, "face_mat": "paint2",
            "barrel_mat": "paint2", "disc": False, "sidewall": "FIELDLINE 400/60-15.5"}
    _chassis(parts, info, 2.1, y0, y1, zf, [(-1.6, "f"), (-2.6, "r")], spec, 4.35, lod)
    n = 16 if lod == 0 else 5
    for k in range(n):
        xx = -W * 0.5 + W * (k + 0.5) / n
        box(parts, "bed", "body", (W / n - 0.012, y0 - y1, 0.04), (xx, (y0 + y1) * 0.5, zf), "wood")
    for sx in (1, -1):
        box(parts, "bed", "body", (0.06, y0 - y1, 0.12), (sx * (W * 0.5 - 0.03), (y0 + y1) * 0.5, zf - 0.04), "paint")
    # ladder headboard
    for sx in (-1, 1):
        box(parts, "head", "body", (0.06, 0.06, 1.5), (sx * (W * 0.5 - 0.05), y0, zf + 0.75), "paint")
    for k in range(6):
        box(parts, "head", "body", (W - 0.1, 0.04, 0.04), (0, y0, zf + 0.2 + k * 0.25), "paint")
    # small square bales 0.9 x 0.46 x 0.36 stacked three high in rows of five across... laid lengthwise
    bh, bw, bl = 0.36, 0.46, 0.9
    nx = int((W - 0.05) // bw)
    ny = int((y0 - y1 - 0.1) // bl)
    layers = 3 if lod <= 1 else 3
    for zl in range(layers):
        for ix in range(nx):
            for iy in range(ny):
                if zl == 2 and (ix in (0, nx - 1) or iy == ny - 1):
                    continue
                bx = -W * 0.5 + 0.03 + bw * (ix + 0.5)
                by = y0 - 0.1 - bl * (iy + 0.5)
                bz = zf + 0.02 + bh * (zl + 0.5)
                b = bm_rbox((bw - 0.01, bl - 0.01, bh - 0.01), 0.03 if lod == 0 else 0.0, 1, (bx, by, bz)) if lod == 0 else bm_box((bw - 0.01, bl - 0.01, bh - 0.01), (bx, by, bz))
                _add(parts, "bales", "body", b, "straw")
                if lod == 0 and zl == layers - 1 or (lod == 0 and ix in (0, nx - 1)):
                    for t in (-0.12, 0.12):
                        tw_ = bm_box((bw - 0.0, 0.012, bh + 0.002), (bx, by + t * 2.2, bz))
                        _add(parts, "bales", "body", tw_, "flag_b")
    return parts, info


def flatbed(L_bed, W, z_deck):
    """a timber flatbed with a steel frame, low drop sides, a headache rack and a side toolbox; replaces the pickup tub"""
    def ex(parts, s, surf, lod, info):
        yf = s.L * 0.5 - (s.L) - 0.06           # just behind the cab (the cab body is built about its own middle)
        y0, y1 = yf, yf - L_bed
        box(parts, "flatbed", "body", (W, L_bed, 0.1), (0, (y0 + y1) / 2, z_deck - 0.08), "trim")
        n = 9 if lod == 0 else 3
        for k in range(n):
            xx = -W * 0.5 + W * (k + 0.5) / n
            box(parts, "flatbed", "body", (W / n - 0.008, L_bed, 0.035), (xx, (y0 + y1) / 2, z_deck), "wood")
        for sx in (1, -1):
            box(parts, "flatbed", "body", (0.03, L_bed, 0.22), (sx * (W * 0.5 - 0.015), (y0 + y1) / 2, z_deck + 0.12), "wood")
            for yy in (y0 - 0.02, (y0 + y1) / 2, y1 + 0.02):
                box(parts, "flatbed", "body", (0.04, 0.04, 0.25), (sx * (W * 0.5 - 0.02), yy, z_deck + 0.12), "metal")
        box(parts, "flatbed", "body", (W, 0.03, 0.22), (0, y1 + 0.015, z_deck + 0.12), "wood")
        # headache rack
        for sx in (1, -1):
            tube(parts, "rack", "body", (sx * (W * 0.5 - 0.05), y0 - 0.04, z_deck), (sx * (W * 0.5 - 0.05), y0 - 0.04, z_deck + 0.85), 0.025, "metal", 8)
        for z in (z_deck + 0.4, z_deck + 0.85):
            tube(parts, "rack", "body", (-(W * 0.5 - 0.05), y0 - 0.04, z), ((W * 0.5 - 0.05), y0 - 0.04, z), 0.022, "metal", 8)
        if lod <= 1:
            for k in range(1, 7):
                x = -(W * 0.5 - 0.05) + (W - 0.1) * k / 7
                tube(parts, "rack", "body", (x, y0 - 0.04, z_deck + 0.4), (x, y0 - 0.04, z_deck + 0.85), 0.008, "metal", 4)
        # toolbox under the deck on the right side, chequer plate, padlock hasp
        box(parts, "toolbox", "body", (0.38, 0.9, 0.38), (W * 0.5 - 0.22, y0 - 0.65, z_deck - 0.32), "metal", 0.01)
        box(parts, "toolbox", "body", (0.01, 0.84, 0.32), (W * 0.5 - 0.025, y0 - 0.65, z_deck - 0.32), "chrome")
        box(parts, "toolbox", "body", (0.012, 0.05, 0.06), (W * 0.5 - 0.018, y0 - 0.65, z_deck - 0.2), "trim")
        # rear lamps and plate on the deck's rear bar
        for sx in (1, -1):
            box(parts, "lamps", "body", (0.2, 0.03, 0.1), (sx * (W * 0.5 - 0.15), y1 - 0.02, z_deck - 0.1), "trim", 0.008)
            box(parts, "lamps", "body", (0.09, 0.008, 0.07), (sx * (W * 0.5 - 0.2), y1 - 0.038, z_deck - 0.1), "lamp_tail")
            box(parts, "lamps", "body", (0.06, 0.008, 0.07), (sx * (W * 0.5 - 0.1), y1 - 0.038, z_deck - 0.1), "lamp_ind_r" if sx > 0 else "lamp_ind_l")
        box(parts, "plates", "body", (0.52, 0.01, 0.11), (0, y1 - 0.03, z_deck - 0.2), "plate")
        box(parts, "flatbed", "body", (1.2, 0.08, 0.08), (0, y1 + 0.05, z_deck - 0.25), "trim")
    return ex


def _farm_truck():
    rc = C.pickup("farm_truck_a", 4.9, 1.82, 1.70, 3.0, 0.84, tyre(205, 75, 15), (0.52, 0.56, 0.48), "BRASK", 2.75, 1.12, "steel_cap",
                  cond=C.rust_cond(0.6, seed=6), older=True)
    rc["extras"] = [flatbed(4.9 - 2.75 - 0.08, 1.9, 0.98), X.bumpers(0.48, None, h=0.14, depth=0.12, mat="chrome", wrap=0.25)]
    rc.pop("tails_after_aux", None)
    rc["detail"].pop("plate_r_aux", None)
    rc["dirt"] = 0.8
    return rc


def roofbox():
    """a black plastic roof box on the rails (estate cars)"""
    def ex(parts, s, surf, lod, info):
        from vk_body import section, R_TOP
        d0, d1 = 1.95, 3.85
        P = section(s, (d0 + d1) / 2)
        z = P[R_TOP][1] + 0.08
        y = s.L * 0.5 - (d0 + d1) / 2
        _add(parts, "roofbox", "body", bm_rbox((0.82, d1 - d0, 0.36), 0.12 if lod == 0 else 0.0, 3 if lod == 0 else 1, (0, y, z + 0.2)), "trim")
        _add(parts, "roofbox", "body", bm_box((0.86, d1 - d0 - 0.2, 0.012), (0, y, z + 0.17)), "trim_grey")
        for yy in (y - 0.55, y + 0.55):
            _add(parts, "roofbox", "body", bm_box((1.1, 0.05, 0.035), (0, yy, z + 0.0)), "trim")
    return ex


def dogguard():
    """a dog guard behind the rear seats: a steel frame of vertical bars from the seat back to the roof lining"""
    def ex(parts, s, surf, lod, info):
        from vk_body import section, R_BELT, R_CANT
        d = info.get("dog_d", 3.12)
        P = section(s, d)
        y = s.L * 0.5 - d
        zb, zt = P[R_BELT][1] - 0.05, P[R_CANT][1] - 0.06
        hw = P[R_CANT][0] - 0.1
        tube(parts, "dogguard", "body", (-hw, y, zt), (hw, y, zt), 0.012, "metal", 6)
        tube(parts, "dogguard", "body", (-hw, y, zb), (hw, y, zb), 0.012, "metal", 6)
        n = 14 if lod == 0 else 5
        for k in range(n + 1):
            x = -hw + 2 * hw * k / n
            tube(parts, "dogguard", "body", (x, y, zb), (x, y, zt), 0.006, "metal", 4)
    return ex


def _estate(name, extra):
    rc = C.modern(name, "estate", 4.77, 1.83, 1.49, 2.79, 0.93, tyre(215, 55, 17), (0.42, 0.50, 0.58), "VELIA",
                  style="multi", spokes=10, nose=0.78, cowl_d=1.22, cowl_z=1.0, roof_d=2.05, rails=True, belt1=1.02,
                  cond=lambda co, n: 0.8, extras=[extra])
    rc["dirt"] = 0.6
    return rc


def _cruiser_flat():
    rc = C._cruiser()
    rc["name"] = "cruiser_1984_flat"
    rc["flat_tyre"] = "rl"
    return rc


add({"name": "farm_trailer_a", "kind": "trailer", "maker": farm_trailer_parts, "bones_fn": std_bones,
     "actions_fn": lambda rc, info: {"tailgate_open": {"tailgate": [(1, 0.0), (30, math.radians(-95))]},
                                     "tailgate_close": {"tailgate": [(1, math.radians(-95)), (30, 0.0)]}},
     "paint": (0.62, 0.63, 0.62), "paint2": (0.12, 0.12, 0.12), "wheel": {"R": tyre(155, 80, 13)[0]}, "dirt": 0.8,
     "mat_colours": {"wood": (0.36, 0.28, 0.2)},
     "condition": lambda co, n: max(0.4, 1.0 - 0.5 * max(0.0, 1.0 - co.z / 0.9))})
add({"name": "hay_trailer_a", "kind": "trailer", "maker": hay_trailer_parts, "bones_fn": std_bones, "actions_fn": trailer_actions,
     "paint": (0.20, 0.32, 0.18), "paint2": (0.1, 0.1, 0.1), "wheel": {"R": tyre(400, 60, 15)[0]}, "dirt": 0.85,
     "mat_colours": {"wood": (0.34, 0.26, 0.18), "flag_b": (0.6, 0.45, 0.2)},
     "condition": lambda co, n: max(0.35, 1.0 - 0.45 * max(0.0, 1.0 - co.z / 1.1))})
add(_farm_truck())
add(_estate("car_estate_roofbox_a", roofbox()))
add(_estate("car_estate_dogguard_a", dogguard()))
add(_cruiser_flat())

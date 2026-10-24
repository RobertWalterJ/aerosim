# AeroSim vehicle kit: buses, the ice cream van, the lorry and the milk tanker (lofted bodies, through vk_build.car_parts),
# and the custom-built ones: farm tractor and its wheels, the vintage parade tractor, farm and parade trailers, a motorcycle
# and a farm quad (their own makers below). Registered into vk_recipes.RECIPES on import.
import math, random
import bmesh
from mathutils import Vector as V, Matrix
from vk_recipes import add, tyre
from vk_body import (R_BOT, R_FLOOR, R_ROCK, R_SILL, R_LOW, R_MID, R_SH, R_BELT, R_GL0, R_GL1, R_CANT, R_ROOF1, R_ROOF2, R_TOP, section)
from vk_core import Part, bm_rbox, bm_box, bm_cyl, bm_tube, bm_sweep, bm_lathe, mirror_x, text_bm, Surface, decal, rounded_rect
import vk_extras as X
import vk_details as det
import vk_wheels
import vk_interior as inter
from vk_recipes_cars import rust_cond


def _add(parts, name, bone, bm, mat):
    for q in parts:
        if q.name == name and q.bone == bone:
            q.add_bm(bm, mat); bm.free(); return
    p = Part(name, bone)
    p.add_bm(bm, mat)
    parts.append(p)
    bm.free()


HEAVY_WHEEL = {"style": "steel", "holes": 0, "nuts": 10, "pcd": 0.16, "nut_r": 0.014, "chrome_nuts": True, "hubcap": True,
               "cap_r": 0.11, "disc": False, "face_mat": "rim_steel"}


# ================================================================================================================ buses
def bus(name, L, W, H, d_front_axle, wb, paint, paint2, livery, *, vintage=False, cond=None, extras=None, dest="",
        lettering=None, pose=""):
    R, Rr, tw = tyre(275, 70, 22.5) if not vintage else tyre(250, 90, 20)
    ra = R + 0.08
    zf = 0.36 if not vintage else 0.72          # floor
    belt = 1.16 if not vintage else 1.42
    roof = H
    erode = 0.16 if not vintage else 0.32
    top = [(0, roof - 0.22, 0), (0.07, roof - 0.08, 0.12), (0.45, roof, 0.35 if vintage else 0.25), (L - 0.4, roof, 0.3), (L - 0.05, roof - 0.12, 0.1),
           (L, roof - 0.22, 0)]
    door = (0.32, 1.42) if not vintage else (0.25, 1.2)
    # window bays: a driver/door bay, then equal bays to the back
    bays = [(door[0] + 0.03, door[1] - 0.02)]
    d = door[1] + 0.12
    bay = 1.25 if not vintage else 1.05
    while d + bay < L - 0.45:
        bays.append((d, d + bay - 0.1))
        d += bay
    panels = [{"kind": "door", "d0": door[0], "d1": (door[0] + door[1]) * 0.5, "r0": R_SILL, "r1": R_CANT, "bone": {1: "bus_door_a"},
               "side": 1, "open": 88},
              {"kind": "door", "d0": (door[0] + door[1]) * 0.5, "d1": door[1], "r0": R_SILL, "r1": R_CANT, "bone": {1: "bus_door_b"},
               "side": 1, "open": 88, "rear_hinged": True}]
    regions = [{"d0": door[0], "d1": door[1], "r0": R_LOW, "r1": R_BELT, "side": 1, "mat": "glass"},
               {"d0": 0.0, "d1": L, "r0": R_FLOOR, "r1": R_SILL, "mat": "trim"}]
    body = dict(
        L=L, W=W, H=H, top=top,
        bot=[(0, zf - 0.0 if vintage else 0.4, 0), (0.3, 0.32 if not vintage else 0.55, 0.1), (L - 0.3, 0.32 if not vintage else 0.55, 0.1), (L, 0.45 if not vintage else 0.6, 0)],
        sill=[(0, 0.46 if not vintage else 0.62, 0), (0.3, 0.38 if not vintage else 0.6, 0.1), (L - 0.3, 0.38 if not vintage else 0.6, 0.1), (L, 0.47 if not vintage else 0.64, 0)],
        belt=[(0, belt, 0), (L, belt, 0)],
        front_face=[(0.0, 0.04), (0.45, 0.0), (1.1, 0.0), (1.3, 0.02), (roof - 0.6, 0.10), (roof - 0.2, 0.16)] if not vintage else
                   [(0.0, 0.03), (0.6, 0.0), (1.4, 0.0), (1.6, 0.03), (roof - 0.6, 0.12), (roof - 0.2, 0.2)],
        rear_face=[(0.0, 0.04), (0.5, 0.0), (roof - 0.4, 0.03), (roof - 0.2, 0.07)],
        fz=0.3, rz=0.25, sh_drop=0.06, belt_in=0.02, th=0.10 if not vintage else 0.14, side_bulge=0.008, plan_rf=0.18 if not vintage else 0.3,
        plan_rr=0.15 if not vintage else 0.28, cap_bulge_f=0.04 if not vintage else 0.07, cap_bulge_r=0.03, erode=erode, crown=0.06,
        windscreen=(0, 0), backlight=None, windows=bays, panels=panels, grooves=[],
        arches=[(d_front_axle, ra), (d_front_axle + wb, ra)], arch_x=0.5,
        extra_stations=[door[0], door[1], (door[0] + door[1]) * 0.5],
        regions=regions,
        cap_glass=[{"front": True, "r0": R_MID if not vintage else R_BELT, "r1": R_GL1, "x0": 0.0 if not vintage else 0.035, "x1": W * 0.5 - 0.09},
                   {"front": True, "r0": R_GL1, "r1": R_CANT, "x0": 0.0, "x1": W * 0.5 - 0.16, "mat": "trim"},
                   {"front": False, "r0": R_BELT, "r1": R_GL1, "x0": 0.0, "x1": W * 0.5 - 0.16}],
        paint2=livery,
        creases={R_SH: True, R_BELT: True, R_GL0: True, R_GL1: True, R_CANT: False},
    )
    hz = 0.62 if not vintage else 0.95
    detail = {
        "head": ({"x": W * 0.5 - 0.3, "z": hz, "w": 0.34, "h": 0.12, "r": 0.03, "bowls": 2, "auto": True, "turn": 0.4} if not vintage else
                 {"x": W * 0.5 - 0.32, "z": hz, "w": 0.2, "h": 0.2, "shape": "round", "bezel": True, "auto": True, "turn": 0.4, "ind": False}),
        "tail": {"x": W * 0.5 - 0.06, "z": 0.95, "w": 0.1, "h": 0.5, "r": 0.02, "auto": True, "turn": 0.4,
                 "layout": [("lamp_ind", 0.0, 1.0, 0.8, 1.0), ("lamp_tail", 0.0, 1.0, 0.45, 0.8), ("lamp_brake", 0.0, 1.0, 0.15, 0.45),
                            ("lamp_reverse", 0.0, 1.0, 0.0, 0.15)]},
        "grille": {"z": 0.42 if not vintage else 0.85, "w": 1.2 if not vintage else 0.9, "h": 0.12 if not vintage else 0.28,
                   "slats": 2 if not vintage else 0, "vbars": 0 if not vintage else 12, "frame": "chrome", "slat": "trim_grey" if not vintage else "chrome", "r": 0.02},
        "plate_f": 0.35 if not vintage else 0.62, "plate_r": 0.62 if not vintage else 0.85,
        "mirror": {"d": 0.25, "mat": "trim", "bone_r": "body", "bone_l": "body"},
        "wipers": {"pivots": (0.75, -0.25), "length": 0.85},
        "exhaust": -0.8, "exhaust_z": 0.34 if not vintage else 0.58,
    }
    interior = {"kind": "bus", "z_floor": zf + 0.02, "d_dash": 0.15, "d_end": L - 0.25, "door": door, "z_belt": belt - 0.04, "pitch": 0.82}
    rc = {
        "name": name, "kind": "bus", "body": body, "paint": paint, "paint2": paint2, "pose": pose,
        "wheel": dict(HEAVY_WHEEL, R=R, Rr=Rr, tw=tw), "track": W - tw - 0.15, "track_rear": W - 2 * tw - 0.2,
        "axles": [d_front_axle, d_front_axle + wb], "steer_axles": [0], "dual_axles": [1],
        "detail": detail, "interior": interior, "condition": cond, "extras": extras or [], "wiper_sweep": 80, "lock": 38,
        "actions_alias": {"bus_door_open": "doors_open", "bus_door_close": "doors_close"},
        "mat_colours": {"lettering": (0.92, 0.82, 0.45), "lettering2": (0.95, 0.62, 0.1)},
    }
    extras = rc["extras"]
    extras.append(destination_board(dest, vintage))
    if lettering:
        rc["detail"]["lettering"] = lettering
    if vintage:
        extras.append(X.bumpers(0.66, 0.68, h=0.12, depth=0.1, mat="chrome", wrap=0.25, proud=0.04))
        rc["detail"]["roof_rails"] = (1.2, L - 1.3)
    return rc


def destination_board(text, vintage):
    """The destination blind above the windscreen: a box on its own bone with amber lettering facing forward."""
    def ex(parts, s, surf, lod, info):
        P = section(s, 0.0)
        z = s.H - (0.32 if not vintage else 0.36)
        hit = surf.project([(0.0, z)], 'front', 0.0)[0]
        if hit is None:
            return
        loc, n = hit
        w, h = (1.5, 0.22) if not vintage else (1.2, 0.2)
        bm = bm_box((w, 0.03, h), (0, 0, 0))
        q = V((0, 1, 0)).rotation_difference(n)
        bmesh.ops.transform(bm, matrix=Matrix.Translation(loc + n * 0.012) @ q.to_matrix().to_4x4(), verts=bm.verts)
        _add(parts, "destination", "destination_board", bm, "trim")
        if text and lod <= 1:
            tb = text_bm(text, 0.11 if not vintage else 0.1, 0.0)
            right = V((-1, 0, 0)).cross(V((0, 0, 0))) if False else None
            for v in tb.verts:
                v.co = loc + n * 0.029 + V((-v.co.x, 0, v.co.y))
            tb.normal_update()
            for f in tb.faces:
                if f.normal.dot(n) < 0:
                    f.normal_flip()
            _add(parts, "destination", "destination_board", tb, "lamp_ind_r" if not vintage else "lettering")
        info["destination"] = tuple(loc + n * 0.012)
    return ex


def band(z0, z1, roof_from=None):
    def f(B, face, i, h, side, dm):
        c = face.calc_center_median()
        if roof_from is not None and c.z > roof_from:
            return True
        return z0 <= c.z <= z1
    return f


add(bus("bus_a", 10.6, 2.52, 3.12, 2.55, 5.3, (0.90, 0.88, 0.80), (0.62, 0.06, 0.05), band(0.80, 1.06), dest="HALLOWAY",
        lettering=[{"text": "VALLEY LINES", "d": 5.5, "z": 0.75, "size": 0.18, "mat": "paint2"}]))
add(bus("bus_b", 11.2, 2.52, 3.2, 2.6, 5.6, (0.94, 0.94, 0.92), (0.07, 0.20, 0.40), band(0.0, 1.06, roof_from=None), dest="RIVERSIDE",
        lettering=[{"text": "KESTREL COACHES", "d": 5.8, "z": 0.72, "size": 0.2, "mat": "sheet_white"}]))


def _festival(name, restored):
    def fest_livery(B, face, i, h, side, dm):
        c = face.calc_center_median()
        return c.z > 2.62 or 1.30 <= c.z <= 1.46          # cream roof band and waist rail
    if restored:
        extras = [X.sticker("VOSS & SON\nMOTOR WORKS", 1, 7.6, 1.05, 0.16, 0.09, "lettering", "chrome", bone="body")]
        cond = lambda co, n: 0.9
        lettering = [{"text": "HALLOWAY FESTIVAL", "d": 4.4, "z": 1.02, "size": 0.2, "mat": "lettering"}]
        rc = bus(name, 9.0, 2.42, 3.0, 1.75, 4.9, (0.11, 0.30, 0.17), (0.88, 0.84, 0.70), fest_livery, vintage=True, cond=cond,
                 extras=extras, dest="HALLOWAY FESTIVAL", lettering=lettering)
    else:
        extras = [tarp(3.4, 8.6), primer_panel()]
        rc = bus(name, 9.0, 2.42, 3.0, 1.75, 4.9, (0.18, 0.33, 0.22), (0.72, 0.68, 0.58), fest_livery, vintage=True,
                 cond=rust_cond(0.55, seed=11), extras=extras, dest="")
        rc["body"]["regions"].append({"d0": 5.0, "d1": 6.5, "r0": R_SILL, "r1": R_BELT, "side": -1, "mat": "primer"})
        rc["mat_colours"] = dict(rc["mat_colours"], canvas=(0.10, 0.22, 0.48))
    rc["interior"]["pitch"] = 0.78
    return rc


def tarp(d0, d1):
    """A blue tarpaulin half over the roof, sagging over the sides with a few folds."""
    def ex(parts, s, surf, lod, info):
        n = 26 if lod == 0 else 10
        m = 16 if lod == 0 else 8
        bm = bmesh.new()
        rows = []
        for i in range(n + 1):
            d = d0 + (d1 - d0) * i / n
            row = []
            for j in range(m + 1):
                t = -1.0 + 2.0 * j / m          # across the roof and down the sides
                x = t * (s.W * 0.5 + 0.04)
                a = abs(t)
                y = s.L * 0.5 - d
                hit = surf.hit(V((x * 0.98, y, 10.0)), V((0, 0, -1)), 20)[0]
                ztop = hit.z if hit is not None else s.H
                z = ztop + 0.03 + 0.02 * math.sin(d * 9.0 + t * 3.0)
                if a > 0.93:                     # hang down the side
                    z -= (a - 0.93) / 0.07 * (0.55 + 0.25 * math.sin(d * 3.1))
                row.append(bm.verts.new((x, y, z)))
            rows.append(row)
        for i in range(n):
            for j in range(m):
                f = bm.faces.new([rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]])
                f.smooth = True
        bm.normal_update()
        for f in bm.faces:
            if f.normal.z < -0.2 and abs(f.calc_center_median().x) < s.W * 0.4:
                f.normal_flip()
        _add(parts, "tarp", "body", bm, "canvas")
    return ex


def primer_panel():
    def ex(parts, s, surf, lod, info):
        pass
    return ex


add(_festival("festival_bus_restored", True))
add(_festival("festival_bus_garage", False))


# ========================================================================================================== ice cream van
def _ice_cream():
    from vk_recipes_cars import van
    L = 5.6
    def livery(B, face, i, h, side, dm):
        c = face.calc_center_median()
        return c.z < 0.95 or (1.95 < c.z < 2.08)
    rc = van("festival_ice_cream_van_a", L, 2.05, 2.62, 3.4, 0.95, tyre(215, 65, 16), (0.96, 0.93, 0.84), "CORVAN",
             rear_glass=False, slide=False, paint2=(0.86, 0.45, 0.58),
             body_over={"th": 0.05, "erode": 0.12, "crown": 0.05, "paint2": livery,
                        "windows": [(1.06, 1.89)],
                        "regions": [{"d0": 0.0, "d1": L, "r0": R_FLOOR, "r1": R_SILL, "mat": "trim"},
                                    {"d0": 2.35, "d1": 3.95, "r0": R_GL0, "r1": R_GL1, "side": 1, "mat": "glass"}]})
    rc["body"]["panels"].append({"kind": "door", "d0": 2.35, "d1": 3.95, "r0": R_GL0, "r1": R_GL1, "bone": {1: "serving_hatch"},
                                 "side": 1, "flap": True, "open": 82})
    rc["body"]["extra_stations"] = rc["body"].get("extra_stations", []) + [2.35, 3.95]
    rc["detail"]["lettering"] = [{"text": "HALLOWAY ICES", "d": 3.15, "z": 0.72, "size": 0.16, "mat": "lettering2", "bone": "body"},
                                 {"text": "SOFT SERVE * CONES * LOLLIES", "d": 3.15, "z": 2.3, "size": 0.08, "mat": "lettering2", "bone": "body"}]
    rc["mat_colours"] = {"lettering2": (0.35, 0.12, 0.25), "lettering": (0.9, 0.85, 0.6)}
    rc["extras"].append(cone_sign())
    rc["interior"]["d_end"] = L - 0.15
    return rc


def cone_sign():
    """A big ice cream cone on the roof over the cab, and the awning over the hatch."""
    def ex(parts, s, surf, lod, info):
        y = s.L * 0.5 - 1.9
        z = s.H + 0.02
        segs = 16 if lod == 0 else 8
        cone, _ = bm_lathe([(0.0, 0.0), (0.16, 0.42), (0.17, 0.44)], segs, axis='Z')
        bmesh.ops.transform(cone, matrix=Matrix.Translation((0, y, z)), verts=cone.verts)
        _add(parts, "sign", "body", cone, "wood")
        sc, _ = bm_lathe([(math.sin(a) * 0.2 + 0.0001, -math.cos(a) * 0.2) for a in [math.pi * k / 8 for k in range(9)]], segs, axis='Z')
        bmesh.ops.transform(sc, matrix=Matrix.Translation((0, y, z + 0.58)), verts=sc.verts)
        _add(parts, "sign", "body", sc, "paint2")
        # awning over the serving hatch
        ya, yb = s.L * 0.5 - 2.3, s.L * 0.5 - 4.0
        P = section(s, 3.1)
        x = P[R_SH][0]
        zt = P[R_GL1][1] + 0.08
        bm = bmesh.new()
        v = [bm.verts.new((x, ya, zt)), bm.verts.new((x, yb, zt)), bm.verts.new((x + 0.45, yb, zt - 0.18)), bm.verts.new((x + 0.45, ya, zt - 0.18))]
        bm.faces.new(v)
        _add(parts, "sign", "body", bm, "canvas")
    return ex


add(_ice_cream())


# ===================================================================================================== lorry and tanker
def cab_over(name, L, W, cab_len, d_front_axle, axles, paint, cargo, *, cond=None, mat_colours=None, dual=(1,), wheel_rear=None):
    R, Rr, tw = tyre(295, 80, 22.5)
    ra = R + 0.07
    H = 3.05
    Lc = cab_len
    zbot = 0.82
    top = [(0, 2.88, 0), (0.08, 2.98, 0.08), (0.45, 3.05, 0.35), (Lc - 0.06, 3.05, 0.05), (Lc, 2.98, 0)]
    panels = [{"kind": "door", "d0": 0.35, "d1": 1.55, "r0": R_SILL, "r1": R_CANT, "bone": {1: "door_fr", -1: "door_fl"}, "open": 75}]
    body = dict(
        L=Lc, W=W, H=H, top=top,
        bot=[(0, zbot + 0.05, 0), (0.25, zbot, 0.1), (Lc, zbot, 0)],
        sill=[(0, zbot + 0.12, 0), (0.25, zbot + 0.1, 0.1), (Lc, zbot + 0.1, 0)],
        belt=[(0, 1.78, 0), (Lc, 1.78, 0)],
        front_face=[(zbot, 0.03), (zbot + 0.15, 0.0), (1.70, 0.0), (1.82, 0.03), (2.6, 0.12), (2.88, 0.17)],
        rear_face=[(0.0, 0.0), (4.0, 0.0)], fz=0.32, rz=0.1, sh_drop=0.05, belt_in=0.02, th=0.08, side_bulge=0.006,
        plan_rf=0.2, plan_rr=0.04, cap_bulge_f=0.04, cap_bulge_r=0.0, erode=0.18, crown=0.04,
        windscreen=(0, 0), backlight=None, windows=[(0.42, 1.48)], panels=panels, grooves=[],
        arches=[(d_front_axle, ra)], arch_x=0.45,
        cap_glass=[{"front": True, "r0": R_BELT, "r1": R_GL1, "x0": 0.0, "x1": W * 0.5 - 0.08}],
        regions=[],
    )
    detail = {
        "head": {"x": W * 0.5 - 0.3, "z": 1.0, "w": 0.3, "h": 0.14, "r": 0.02, "bowls": 2, "auto": True, "turn": 0.3},
        "grille": {"z": 1.42, "w": 1.6, "h": 0.42, "slats": 6, "frame": "trim", "slat": "trim_grey", "r": 0.03},
        "mirror": {"d": 0.2, "mat": "trim", "bone_r": "door_fr", "bone_l": "door_fl"},
        "wipers": {"pivots": (0.6, -0.3), "length": 0.8},
        "badge": {"text": "BRASK", "plane": "front", "z": 1.72, "x": 0.0, "size": 0.09},
    }
    interior = {"z_floor": zbot + 0.35, "d_dash": 0.18, "d_front_seat": 1.25, "d_rear_seat": None, "d_end": Lc - 0.08, "shelf": None,
                "doors": [(0.35, 1.55, "door_fr", "door_fl")]}
    rc = {
        "name": name, "kind": "truck", "body": body, "paint": paint,
        "wheel": dict(HEAVY_WHEEL, R=R, Rr=Rr, tw=tw), "track": W - tw - 0.12, "track_rear": W - 2 * tw - 0.22,
        "axles": [d_front_axle] + list(axles), "steer_axles": [0], "dual_axles": list(dual),
        "detail": detail, "interior": interior, "condition": cond, "extras": [truck_chassis(L, Lc, W, min(axles), d_front_axle, R), X.bumpers(0.6, None, h=0.42, depth=0.12, mat="trim", wrap=0.1, proud=0.03, rub=False), cargo],
        "shift_y": (L - Lc) * 0.5, "wiper_sweep": 80, "lock": 36,
        "mat_colours": mat_colours or {},
    }
    if wheel_rear:
        rc["wheel_rear"] = dict(rc["wheel"], **wheel_rear)
    return rc


def truck_chassis(L, Lc, W, d_rear1=None, d_front=1.3, R=0.5):
    """Chassis rails, fuel tank, steps, side guards and the rear light bar, in the cab's frame (shifted later)."""
    def ex(parts, s, surf, lod, info):
        yf = s.L * 0.5                      # the cab's front
        yr = yf - L + 0.1
        for sx in (1, -1):
            r = bm_box((0.09, yf - yr - 0.3, 0.26), (sx * 0.43, (yf - 0.3 + yr) * 0.5, 0.88))
            _add(parts, "chassis", "body", r, "trim")
        tank = bm_cyl(0.28, 0.28, 1.0, 14 if lod == 0 else 8, 'Y', (-W * 0.5 + 0.35, yf - Lc - 0.65, 0.78))
        _add(parts, "chassis", "body", tank, "rim")
        box = bm_rbox((0.5, 0.6, 0.45), 0.03, 1, (W * 0.5 - 0.35, yf - Lc - 0.6, 0.78))
        _add(parts, "chassis", "body", box, "trim")
        for sx in (1, -1):
            for zz in (0.42, 0.68):
                st = bm_box((0.32, 0.36, 0.03), (sx * (W * 0.5 - 0.17), yf - 0.85, zz))
                _add(parts, "chassis", "body", st, "metal")
            # side guard rails between the axles
            # side guards between the front wheel and the first rear wheel, clear of both tyres
            g0 = yf - d_front - R - 0.15
            g1 = (yf - d_rear1 + R + 0.15) if d_rear1 is not None else yr + 1.6
            if g0 - g1 > 0.6:
                for zz in (0.55, 0.8):
                    gr = bm_box((0.04, g0 - g1, 0.07), (sx * (W * 0.5 - 0.05), (g0 + g1) * 0.5, zz))
                    _add(parts, "chassis", "body", gr, "rim")
        lb = bm_box((W - 0.1, 0.08, 0.14), (0, yr + 0.02, 0.62))
        _add(parts, "chassis", "body", lb, "trim")
        for sx in (1, -1):
            for k, m in enumerate(("lamp_ind_r" if sx > 0 else "lamp_ind_l", "lamp_tail", "lamp_brake", "lamp_reverse")):
                lm = bm_box((0.09, 0.02, 0.08), (sx * (W * 0.5 - 0.12 - k * 0.1), yr - 0.03, 0.62))
                _add(parts, "lamps", "body", lm, m)
        pl = bm_box((0.52, 0.01, 0.11), (0.35, yr - 0.025, 0.42))
        _add(parts, "plates", "body", pl, "plate")
        # exhaust stack behind the cab
        ex_ = bm_cyl(0.06, 0.06, 1.4, 12, 'Z', (W * 0.5 - 0.25, yf - Lc - 0.12, 2.35))
        _add(parts, "chassis", "body", ex_, "metal")
    return ex


def box_body(L, Lc, W, H0, H1, firm):
    """A rigid box body (the lorry) with corner posts, top rails, a roller shutter on the back (its own bone) and lettering."""
    def ex(parts, s, surf, lod, info):
        yf = s.L * 0.5
        y0 = yf - Lc - 0.12
        y1 = yf - L + 0.05
        b = bm_rbox((W - 0.02, y0 - y1, H1 - H0), 0.03, 1 if lod <= 1 else 0, (0, (y0 + y1) * 0.5, (H0 + H1) * 0.5))
        _add(parts, "box", "body", b, "paint2")
        fl = bm_box((W, y0 - y1, 0.12), (0, (y0 + y1) * 0.5, H0 - 0.06))
        _add(parts, "box", "body", fl, "trim")
        if lod <= 1:
            for sx in (1, -1):
                for yy in (y0, y1):
                    post = bm_box((0.06, 0.06, H1 - H0 + 0.02), (sx * (W * 0.5 - 0.0), yy, (H0 + H1) * 0.5))
                    _add(parts, "box", "body", post, "rim")
                rail = bm_box((0.05, y0 - y1, 0.06), (sx * (W * 0.5), (y0 + y1) * 0.5, H1))
                _add(parts, "box", "body", rail, "rim")
                n = int((y0 - y1) / 0.6)
                for k in range(1, n):
                    yy = y1 + (y0 - y1) * k / n
                    rib = bm_box((0.02, 0.04, H1 - H0 - 0.1), (sx * (W * 0.5), yy, (H0 + H1) * 0.5))
                    _add(parts, "box", "body", rib, "paint2")
        # roller shutter on the back, on its own bone (slides up)
        sh = bm_box((W - 0.16, 0.03, H1 - H0 - 0.1), (0, y1 - 0.02, (H0 + H1) * 0.5))
        _add(parts, "shutter", "shutter", sh, "rim")
        if lod == 0:
            for k in range(12):
                zz = H0 + 0.08 + (H1 - H0 - 0.16) * k / 11
                ln = bm_box((W - 0.17, 0.012, 0.012), (0, y1 - 0.037, zz))
                _add(parts, "shutter", "shutter", ln, "metal")
        info["shutter"] = (0, y1 - 0.02, (H0 + H1) * 0.5, H1 - H0 - 0.25)
        if firm and lod <= 1:
            for sx in (1, -1):
                tb = text_bm(firm, 0.32, 0.0)
                pt = Part("letters", "body")
                for v in tb.verts:
                    a, b2 = v.co.x, v.co.y
                    yy = (y0 + y1) * 0.5 + (a if sx > 0 else -a)
                    v.co = V((sx * (W * 0.5 - 0.01 + 0.006), yy, (H0 + H1) * 0.5 + 0.1 + b2))
                tb.normal_update()
                for f in tb.faces:
                    if f.normal.x * sx < 0:
                        f.normal_flip()
                pt.add_bm(tb, "lettering2")
                tb.free()
                parts.append(pt)
    return ex


def tank_body(L, Lc, W):
    """An insulated stainless milk tank: elliptical section, domed ends, saddles, walkway and rail, manways, a ladder, the
    rear cabinet with its hose and the outlet valve (its own bone, the hand wheel turns)."""
    def ex(parts, s, surf, lod, info):
        yf = s.L * 0.5
        y0 = yf - Lc - 0.2
        y1 = yf - L + 0.45
        cz, a, b = 2.18, W * 0.5 - 0.04, 0.98
        n_around = 32 if lod == 0 else (16 if lod == 1 else 8)
        n_len = 6 if lod <= 1 else 2
        bm = bmesh.new()
        rings = []
        ys = []
        # domed ends: a few rings shrinking at each end
        dome = [(-0.32, 0.25), (-0.22, 0.72), (-0.1, 0.93), (0.0, 1.0)] if lod <= 1 else [(-0.3, 0.4), (0.0, 1.0)]
        rows = [(y0 - (d_ + 0.32), k) for (d_, k) in dome]                 # tip at y0 (d_=-0.32), full at y0-0.32
        for t in range(1, n_len):
            rows.append((y0 - 0.32 + (y1 + 0.32 - (y0 - 0.32)) * t / n_len, 1.0))
        rows += [(y1 + (d_ + 0.32), k) for (d_, k) in reversed(dome)]      # full at y1+0.32, tip at y1
        for (yy, k) in rows:
            ring = []
            for j in range(n_around):
                t = 2 * math.pi * j / n_around
                ring.append(bm.verts.new((math.cos(t) * a * k, yy, cz + math.sin(t) * b * k)))
            rings.append(ring)
        for i in range(len(rings) - 1):
            for j in range(n_around):
                f = bm.faces.new([rings[i][j], rings[i][(j + 1) % n_around], rings[i + 1][(j + 1) % n_around], rings[i + 1][j]])
                f.smooth = True
        for ring, rev in ((rings[0], True), (rings[-1], False)):
            f = bm.faces.new(list(reversed(ring)) if rev else ring)
        bm.normal_update()
        cen = V((0, (y0 + y1) * 0.5, cz))
        for f in bm.faces:
            if f.normal.dot(f.calc_center_median() - cen) < 0:
                f.normal_flip()
        _add(parts, "tank", "body", bm, "chrome")
        # bands round the tank
        if lod <= 1:
            for t in range(1, 5):
                yy = y0 - 0.32 + (y1 + 0.64 - y0) * t / 5
                band_, _ = bm_lathe([(1.0, -0.03), (1.0, 0.03)], n_around, axis='Y')
                for v in band_.verts:
                    ang = math.atan2(v.co.z, v.co.x)
                    v.co = V((math.cos(ang) * (a + 0.012), yy + v.co.y, cz + math.sin(ang) * (b + 0.012)))
                _add(parts, "tank", "body", band_, "rim")
        # saddles
        for yy in (y0 - 0.5, (y0 + y1) * 0.5, y1 + 0.5):
            sd = bm_box((W - 0.5, 0.18, 0.5), (0, yy, 1.3))
            _add(parts, "tank", "body", sd, "trim")
        # walkway, rails, manways
        wk = bm_box((0.45, y0 - y1 - 0.6, 0.03), (0, (y0 + y1) * 0.5, cz + b + 0.02))
        _add(parts, "tank", "body", wk, "metal")
        if lod <= 1:
            for sx in (1, -1):
                rl = bm_tube((sx * 0.3, y0 - 0.4, cz + b + 0.55), (sx * 0.3, y1 + 0.4, cz + b + 0.55), 0.016, 6)
                _add(parts, "tank", "body", rl, "rim")
                for k in range(5):
                    yy = y0 - 0.4 + (y1 - y0 + 0.8) * k / 4
                    st = bm_tube((sx * 0.3, yy, cz + b), (sx * 0.3, yy, cz + b + 0.55), 0.014, 6)
                    _add(parts, "tank", "body", st, "rim")
            for k in range(3):
                yy = y0 - 0.9 - (y0 - y1 - 1.8) * k / 2
                mw = bm_cyl(0.24, 0.24, 0.1, 18 if lod == 0 else 10, 'Z', (0, yy, cz + b + 0.06))
                _add(parts, "tank", "body", mw, "rim")
            # ladder at the back
            for sx in (-0.2, 0.2):
                lr = bm_tube((sx, y1 - 0.25, 1.0), (sx, y1 - 0.25, cz + b + 0.4), 0.016, 6)
                _add(parts, "tank", "body", lr, "rim")
            for k in range(8):
                zz = 1.1 + (cz + b - 1.1) * k / 7
                rg = bm_tube((-0.2, y1 - 0.25, zz), (0.2, y1 - 0.25, zz), 0.012, 5)
                _add(parts, "tank", "body", rg, "rim")
        # rear cabinet, hose and the valve (its own bone: the hand wheel turns)
        cab = bm_rbox((1.2, 0.5, 0.7), 0.03, 1, (0.0, y1 - 0.05, 1.05))
        _add(parts, "tank", "body", cab, "rim")
        hose = bm_cyl(0.07, 0.07, 1.1, 12, 'X', (0.0, y1 - 0.33, 1.25))
        _add(parts, "tank", "body", hose, "rubber")
        vx, vy, vz = -0.75, y1 - 0.15, 0.95
        pipe = bm_tube((vx, y1 + 0.3, vz), (vx, vy, vz), 0.045, 10)
        _add(parts, "tank", "body", pipe, "chrome")
        wheel_, _ = bm_lathe([(0.11, -0.012), (0.13, -0.012), (0.13, 0.012), (0.11, 0.012), (0.11, -0.012)], 18, axis='Y')
        bmesh.ops.transform(wheel_, matrix=Matrix.Translation((vx, vy - 0.04, vz)), verts=wheel_.verts)
        _add(parts, "valve", "valve", wheel_, "caliper")
        for k in range(3):
            ang = k * 2 * math.pi / 3
            sp = bm_tube((vx, vy - 0.04, vz), (vx + math.cos(ang) * 0.12, vy - 0.04, vz + math.sin(ang) * 0.12), 0.008, 5)
            _add(parts, "valve", "valve", sp, "caliper")
        info["valve"] = (vx, vy - 0.04, vz)
        # lettering on the tank sides
        if lod <= 1:
            for sx in (1, -1):
                tb = text_bm("VALLEY DAIRY", 0.3, 0.0)
                pt = Part("letters", "body")
                for v in tb.verts:
                    aa, bb = v.co.x, v.co.y
                    yy = (y0 + y1) * 0.5 + (aa if sx > 0 else -aa)
                    zz = cz + bb
                    xx = a * math.sqrt(max(0.0, 1.0 - ((zz - cz) / b) ** 2)) + 0.012
                    v.co = V((sx * xx, yy, zz))
                tb.normal_update()
                for f in tb.faces:
                    if f.normal.x * sx < 0:
                        f.normal_flip()
                pt.add_bm(tb, "lettering2")
                tb.free()
                parts.append(pt)
    return ex


def _lorry():
    L, Lc, W = 8.4, 2.25, 2.5
    rc = cab_over("lorry_a", L, W, Lc, 1.3, [5.4], (0.86, 0.86, 0.84), box_body(L, Lc, W, 1.18, 3.72, "MARSH & DAUGHTERS"),
                  mat_colours={"lettering2": (0.08, 0.2, 0.35)})
    rc["paint2"] = (0.93, 0.93, 0.9)
    rc["bones_extra"] = []
    return rc


def _tanker():
    L, Lc, W = 9.4, 2.25, 2.5
    rc = cab_over("milk_tanker_a", L, W, Lc, 1.3, [L - 2.25, L - 0.95], (0.15, 0.32, 0.55), tank_body(L, Lc, W),
                  dual=(), mat_colours={"lettering2": (0.08, 0.22, 0.45)}, wheel_rear={"tw": 0.385, "R": tyre(385, 65, 22.5)[0], "Rr": tyre(385, 65, 22.5)[1]})
    rc["track_rear"] = W - 0.385 - 0.1
    return rc


add(_lorry())
add(_tanker())

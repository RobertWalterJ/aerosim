# AeroSim vehicle kit: the festival ice cream van in detail (second pass, at the owner's request).
# A soft-serve van of the classic coachbuilt kind: a light van's cab and bonnet with a tall box body on the chassis behind,
# a big sliding serving window with a stainless counter on the kerb side (+x), a striped awning, menu boards, a fibreglass
# cone and swirl on the roof, chime horns, a lit roof sign, a soft-serve machine, freezer and counter inside. About 5.7 m long,
# 2.1 m wide, 2.95 m to the roof (3.4 m to the top of the cone). Proportions studied from photographs of the type at shows and
# from coachbuilders' published sizes (for proportions only; nothing copied). Lettering is fictional and real glyph geometry.
import math
import bmesh
from mathutils import Vector as V, Matrix
from vk_core import Part, bm_rbox, bm_box, bm_cyl, bm_tube, bm_sweep, bm_lathe, text_bm
from vk_body import (R_BOT, R_FLOOR, R_ROCK, R_SILL, R_LOW, R_MID, R_SH, R_BELT, R_GL0, R_GL1, R_CANT, R_ROOF1, R_ROOF2, R_TOP)
from vk_recipes import add, tyre
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


def text_side(parts, bone, txt, size, side, x_face, y_mid, z, mat, extrude=0.003):
    """Lettering on a flat body side (side +1 right, -1 left), reading front to back... as seen from outside."""
    bm = text_bm(txt, size, extrude)
    for v in bm.verts:
        a, b, c = v.co.x, v.co.y, v.co.z
        yy = y_mid + a if side > 0 else y_mid - a
        v.co = V((side * (x_face + 0.002 + c + extrude), yy, z + b))
    bm.normal_update()          # both mappings keep handedness, so the glyphs' own normals stay outward
    _add(parts, "letters", bone, bm, mat)


def text_rear(parts, bone, txt, size, y_face, x_mid, z, mat, extrude=0.003):
    bm = text_bm(txt, size, extrude)
    for v in bm.verts:
        a, b, c = v.co.x, v.co.y, v.co.z
        v.co = V((x_mid + a, y_face - 0.002 - c - extrude, z + b))          # read from behind: +a goes to +x
    bm.normal_update()
    _add(parts, "letters", bone, bm, mat)


def icecream_cab_spec(L, Lc, W, H_cab):
    """The van's cab and bonnet as a lofted body Lc long whose back is cut off square where the box body starts."""
    nose, cowl_d, cowl_z, roof_d = 0.92, 0.84, 1.15, 1.6
    top = [(0, nose, 0), (0.05, nose + 0.04, 0.04), (0.45, nose + 0.16, 0.35), (cowl_d, cowl_z, 0.1), (roof_d, H_cab - 0.01, 0.28),
           (Lc - 0.05, H_cab - 0.02, 0.04), (Lc, H_cab - 0.05, 0)]
    d_a, d_b = cowl_d + 0.12, cowl_d + 1.07
    return dict(
        L=Lc, W=W, H=H_cab, top=top,
        bot=[(0, 0.36, 0), (0.3, 0.24, 0.15), (0.9, 0.22, 0.2), (Lc, 0.22, 0)],
        sill=[(0, 0.5, 0), (0.7, 0.38, 0.2), (Lc, 0.38, 0)],
        belt=[(0, nose - 0.02, 0), (cowl_d + 0.05, 1.1, 0.3), (Lc, 1.11, 0)],
        front_face=[(0.0, 0.08), (0.35, 0.03), (0.45, 0.0), (0.6, 0.0), (0.75, 0.02), (nose + 0.04, 0.06)],
        rear_face=[(0.0, 0.0), (4.0, 0.0)], fz=0.45, rz=0.08,
        sh_drop=0.05, belt_in=0.03, th=0.12, side_bulge=0.01, plan_rf=0.3, plan_rr=0.02, cap_bulge_f=0.05, cap_bulge_r=0.0,
        erode=0.06, crown=0.03,
        windscreen=(cowl_d + 0.06, roof_d - 0.05), backlight=None, windows=[(d_a + 0.05, d_b - 0.04)],
        panels=[{"kind": "door", "d0": d_a, "d1": d_b, "r0": R_SILL, "r1": R_CANT, "bone": {1: "door_fr", -1: "door_fl"}, "open": 70},
                {"kind": "lid", "r": R_BELT, "d0": 0.0, "d1": cowl_d - 0.04, "across0": False, "cap_front": True, "bone": "bonnet", "open": 50}],
        grooves=[{"kind": "caprow", "r": R_LOW, "front": True}],
        arches=[(0.95, tyre(215, 65, 16)[0] + 0.05)], extra_stations=[cowl_d - 0.04],
        regions=[{"d0": 0.0, "d1": Lc, "r0": R_FLOOR, "r1": R_SILL, "mat": "trim"},
                 {"d0": 0.0, "d1": Lc, "r0": R_SILL, "r1": R_LOW, "mat": "paint2"}],
    ), d_a, d_b


def box_body(L, Lc, W):
    """The coachbuilt body and everything on it."""
    def ex(parts, s, surf, lod, info):
        seg = 2 if lod == 0 else 1
        yf = s.L * 0.5                     # the cab's front, in the cab's frame
        y0 = yf - Lc + 0.02                # box front (against the cab back)
        y1 = yf - L + 0.03                 # box back
        ym = (y0 + y1) * 0.5
        bl = y0 - y1
        hw = W * 0.5
        z0, z1 = 0.62, 2.95
        # the shell: a box with rounded vertical corners and a rounded roof edge; a pink skirt and two pastel stripes
        shell = bm_rbox((W, bl, z1 - z0), 0.1, seg + 1, (0, ym, (z0 + z1) * 0.5))
        _add(parts, "box", "body", shell, "paint")
        box(parts, "box", "body", (W + 0.012, bl - 0.12, 0.5), (0, ym, 0.88), "paint2", 0.03)
        for (zz, m) in ((1.18, "flag_b"), (1.235, "flag_c")):
            box(parts, "box", "body", (W + 0.016, bl - 0.14, 0.04), (0, ym, zz), m, 0.01)
        box(parts, "box", "body", (W - 0.3, bl - 0.2, 0.25), (0, ym, 0.48), "trim")                       # sub-frame
        for sx in (1, -1):
            box(parts, "box", "body", (0.02, bl - 0.2, 0.025), (sx * (hw + 0.012), ym, 1.32), "chrome", 0.006)   # rubbing strips
            box(parts, "box", "body", (0.02, bl - 0.2, 0.025), (sx * (hw + 0.012), ym, 0.66), "chrome", 0.006)
        # rear wheel arch spats over the rear wheels (the wheels sit under the box)
        rax = info["rear_axle_y"]
        R = info["R"]
        for sx in (1, -1):
            n = 16 if lod == 0 else 8
            path = [(sx * (hw + 0.01), rax + math.cos(math.radians(a)) * (R + 0.08), R + math.sin(math.radians(a)) * (R + 0.08))
                    for a in [12 + 156 * k / n for k in range(n + 1)]]
            _add(parts, "box", "body", bm_sweep([(-0.03, -0.012), (0.03, -0.012), (0.03, 0.03), (-0.03, 0.03)], path, True, up=(1, 0, 0)), "chrome")
            # a black wheel-well liner inside the arch
            liner = bm_lathe([(R + 0.06, -0.12), (R + 0.06, 0.12)], 16 if lod == 0 else 8, axis='X', a0=0.2, a1=math.pi - 0.2, closed=False)[0]
            bmesh.ops.transform(liner, matrix=Matrix.Translation((sx * (hw - 0.12), rax, R)), verts=liner.verts)
            _add(parts, "box", "body", liner, "trim")
        # ------------------------------------------------ the serving window on the kerb side (+x)
        sw_y0, sw_y1 = y0 - 0.55, y0 - 2.15
        sz0, sz1 = 1.3, 2.25
        box(parts, "hatch", "body", (0.03, sw_y0 - sw_y1 + 0.08, sz1 - sz0 + 0.08), (hw + 0.006, (sw_y0 + sw_y1) * 0.5, (sz0 + sz1) * 0.5), "chrome")
        box(parts, "hatch", "body", (0.012, sw_y0 - sw_y1, sz1 - sz0), (hw + 0.016, (sw_y0 + sw_y1) * 0.5, (sz0 + sz1) * 0.5), "trim")
        # the hole: glass panes in front of the black opening (one slides: its own bone)
        half = (sw_y0 - sw_y1) * 0.5
        box(parts, "hatch", "body", (0.01, half - 0.02, sz1 - sz0 - 0.04), (hw + 0.026, sw_y1 + half * 0.5, (sz0 + sz1) * 0.5), "glass")
        box(parts, "hatch", "serving_window", (0.01, half - 0.02, sz1 - sz0 - 0.04), (hw + 0.036, sw_y0 - half * 0.5, (sz0 + sz1) * 0.5), "glass")
        box(parts, "hatch", "serving_window", (0.02, 0.025, sz1 - sz0 - 0.03), (hw + 0.036, sw_y0 - 0.02, (sz0 + sz1) * 0.5), "chrome")
        info["serving"] = (hw + 0.036, sw_y0 - half * 0.5, (sz0 + sz1) * 0.5, half)
        # stainless counter shelf with brackets, a cone holder on it
        box(parts, "hatch", "body", (0.26, sw_y0 - sw_y1, 0.03), (hw + 0.13, (sw_y0 + sw_y1) * 0.5, sz0 - 0.03), "chrome", 0.006)
        for yy in (sw_y0 - 0.1, sw_y1 + 0.1):
            br = bmesh.new()
            vs = [br.verts.new((hw, yy, sz0 - 0.05)), br.verts.new((hw + 0.24, yy, sz0 - 0.05)), br.verts.new((hw, yy, sz0 - 0.3))]
            br.faces.new(vs)
            _add(parts, "hatch", "body", br, "chrome")
        # the striped awning over the window, on its arms
        aw_z, aw_out, aw_drop = sz1 + 0.15, 0.62, 0.22
        n = 10
        for k in range(n):
            ya = sw_y0 + 0.1 - (sw_y0 - sw_y1 + 0.2) * k / n
            yb = sw_y0 + 0.1 - (sw_y0 - sw_y1 + 0.2) * (k + 1) / n
            aw = bmesh.new()
            vs = [aw.verts.new((hw + 0.02, ya, aw_z)), aw.verts.new((hw + 0.02, yb, aw_z)), aw.verts.new((hw + aw_out, yb, aw_z - aw_drop)),
                  aw.verts.new((hw + aw_out, ya, aw_z - aw_drop))]
            aw.faces.new(vs)
            # the scalloped valance
            v2 = [aw.verts.new((hw + aw_out, ya, aw_z - aw_drop)), aw.verts.new((hw + aw_out, yb, aw_z - aw_drop)),
                  aw.verts.new((hw + aw_out, (ya + yb) * 0.5, aw_z - aw_drop - 0.12))]
            aw.faces.new(v2)
            aw.normal_update()
            for f in aw.faces:
                if f.normal.z < 0 and abs(f.normal.z) > 0.3:
                    f.normal_flip()
            _add(parts, "awning", "body", aw, "flag_a" if k % 2 == 0 else "sheet_white")
        for yy in (sw_y0 + 0.08, sw_y1 - 0.08):
            _add(parts, "awning", "body", bm_tube((hw, yy, aw_z - 0.45), (hw + aw_out, yy, aw_z - aw_drop), 0.012, 6), "chrome")
        # menu boards either side of the window: framed panels of coloured pictures and lettered prices (fictional)
        for (ya, yb) in ((y0 - 0.12, sw_y0 + 0.08), (sw_y1 - 0.08, y1 + 0.12)):
            box(parts, "menu", "body", (0.012, ya - yb, 0.95), (hw + 0.008, (ya + yb) * 0.5, 1.82), "sheet_white")
            box(parts, "menu", "body", (0.008, ya - yb + 0.03, 0.98), (hw + 0.004, (ya + yb) * 0.5, 1.82), "chrome")
            cols = ["flag_a", "flag_b", "flag_c", "paint2"]
            m = max(1, int((ya - yb) / 0.2))
            for j in range(m):
                yc = ya - (ya - yb) * (j + 0.5) / m
                box(parts, "menu", "body", (0.008, (ya - yb) / m - 0.05, 0.16), (hw + 0.015, yc, 2.14), cols[j % 4])
                _add(parts, "menu", "body", bm_cyl(0.04, 0.0, 0.1, 10, 'Z', (hw + 0.02, yc, 1.92)), "wood")       # a cone picture
                _add(parts, "menu", "body", bm_rbox((0.02, 0.07, 0.06), 0.025, 1, (hw + 0.02, yc, 2.0)), cols[(j + 2) % 4])
            if lod <= 1:
                if lod == 0:
                    text_side(parts, "body", "SOFT SERVE  CONES", 0.045, 1, hw + 0.015, (ya + yb) * 0.5, 1.6, "lettering2")
                if lod == 0:
                    text_side(parts, "body", "LOLLIES  DRINKS", 0.045, 1, hw + 0.015, (ya + yb) * 0.5, 1.5, "lettering2")
        # side lettering and the left-side menu panel
        if lod <= 1:
            for sx in (1, -1):
                text_side(parts, "body", "HALLOWAY ICES", 0.17, sx, hw + 0.006, ym if sx < 0 else ym - 0.1, 0.84, "sheet_white", 0.004)
            text_side(parts, "body", "HALLOWAY ICES", 0.22, -1, hw, ym, 2.15, "lettering2")
            if lod == 0:
                text_side(parts, "body", "SOFT SERVE * CONES * LOLLIES", 0.08, -1, hw, ym, 1.8, "paint2")
            text_rear(parts, "body", "PLEASE MIND", 0.085, y1, 0.52, 2.15, "lettering2")
            text_rear(parts, "body", "THE CHILDREN", 0.085, y1, 0.52, 2.0, "lettering2")
        # back: a window, the door (its own bone, hinged on the left), lamps, plate, step
        box(parts, "rear", "door_rear", (0.72, 0.03, 1.75), (-0.3, y1 - 0.012, 1.55), "paint", 0.015)
        box(parts, "rear", "door_rear", (0.5, 0.01, 0.42), (-0.3, y1 - 0.03, 2.05), "glass")
        box(parts, "rear", "door_rear", (0.04, 0.05, 0.14), (-0.0, y1 - 0.04, 1.4), "chrome")
        info["rear_door"] = (-0.66, y1 - 0.01, 1.55)
        for sx in (1, -1):
            for k, (m, zz) in enumerate((("lamp_tail", 0.95), ("lamp_brake", 0.87), ("lamp_ind_r" if sx > 0 else "lamp_ind_l", 0.79), ("lamp_reverse", 0.71))):
                box(parts, "lamps", "body", (0.12, 0.02, 0.07), (sx * (hw - 0.1), y1 - 0.012, zz), m)
        box(parts, "plates", "body", (0.52, 0.012, 0.11), (0.45, y1 - 0.012, 0.75), "plate")
        box(parts, "rear", "body", (1.0, 0.25, 0.04), (0.0, y1 - 0.13, 0.42), "metal")
        # ------------------------------------------------ the roof: cone and swirl, the lit sign, chime horns, vents
        cy = y0 - 0.35
        segs = 20 if lod == 0 else 10
        cone, _ = bm_lathe([(0.0, z1 + 0.02), (0.17, z1 + 0.46), (0.185, z1 + 0.48)], segs, axis='Z')
        bmesh.ops.transform(cone, matrix=Matrix.Translation((0, cy, 0)), verts=cone.verts)
        _add(parts, "cone", "body", cone, "wood")
        if lod == 0:
            for k in range(8):                     # the wafer grid lines
                a = k * math.pi / 4
                _add(parts, "cone", "body", bm_tube((0.0, cy, z1 + 0.03), (math.cos(a) * 0.17, cy + math.sin(a) * 0.17, z1 + 0.46), 0.005, 4), "trim_grey")
        # soft-serve swirl: a spiral of tube rising and narrowing
        pts = []
        turns, nseg = 3.2, 70 if lod == 0 else 24
        for k in range(nseg + 1):
            t = k / nseg
            a = t * turns * math.tau
            r = 0.17 * (1.0 - t) + 0.02
            pts.append((math.cos(a) * r, cy + math.sin(a) * r, z1 + 0.52 + t * 0.3))
        sw = bm_sweep([(math.cos(a) * 0.065, math.sin(a) * 0.065) for a in [k * math.tau / 8 for k in range(8)]], pts, True)
        _add(parts, "cone", "body", sw, "sheet_white")
        flake = bm_box((0.03, 0.03, 0.16), (0.07, cy, z1 + 0.82))
        _add(parts, "cone", "body", flake, "wood")
        box(parts, "cone", "body", (0.5, 0.5, 0.04), (0, cy, z1 + 0.02), "trim", 0.02)
        # the lit roof sign at the back half, lettered on both faces
        sy = y0 - 1.9
        box(parts, "sign", "body", (1.5, 0.12, 0.42), (0, sy, z1 + 0.27), "sheet_white", 0.03, seg)
        box(parts, "sign", "body", (1.56, 0.14, 0.04), (0, sy, z1 + 0.05), "chrome")
        if lod <= 1:
            for fy, rdir in ((sy + 0.062, V((-1, 0, 0))), (sy - 0.062, V((1, 0, 0)))):
                bm = text_bm("ICES", 0.24, 0.004)
                for v in bm.verts:
                    v.co = V((v.co.x * rdir.x, fy + (0.004 + v.co.z) * (1 if fy > sy else -1), z1 + 0.27 + v.co.y))
                bm.normal_update()
                _add(parts, "sign", "body", bm, "flag_a")
        # chime horns (two trumpets) and their bracket
        for sx in (1, -1):
            horn, _ = bm_lathe([(0.018, 0.0), (0.03, 0.22), (0.08, 0.3), (0.085, 0.305)], 14 if lod == 0 else 8, axis='Y')
            bmesh.ops.transform(horn, matrix=Matrix.Translation((sx * 0.5, y0 - 0.15, z1 + 0.12)), verts=horn.verts)
            _add(parts, "horns", "body", horn, "chrome")
        box(parts, "horns", "body", (1.1, 0.06, 0.04), (0, y0 - 0.1, z1 + 0.06), "chrome")
        for yy in (y0 - 2.6, y0 - 3.2):
            box(parts, "vents", "body", (0.4, 0.4, 0.08), (0.3, yy, z1 + 0.04), "trim_grey", 0.03)
        # ------------------------------------------------ inside: soft-serve machine, freezer, counter, shelves
        if lod <= 1:
            zf = 0.66
            box(parts, "inside", "body", (W - 0.12, bl - 0.12, 0.02), (0, ym, zf), "trim")                       # floor
            box(parts, "inside", "body", (0.6, 0.55, 1.05), (0.55, sw_y0 - 0.35, zf + 0.52), "chrome", 0.02)     # the machine
            for k in range(3):
                _add(parts, "inside", "body", bm_cyl(0.025, 0.012, 0.08, 8, 'Z', (0.82, sw_y0 - 0.2 - k * 0.12, zf + 0.62)), "chrome")
                box(parts, "inside", "body", (0.03, 0.02, 0.12), (0.84, sw_y0 - 0.2 - k * 0.12, zf + 0.8), "trim")
            box(parts, "inside", "body", (0.62, 1.1, 0.85), (0.6, sw_y1 + 0.6, zf + 0.42), "sheet_white", 0.02)    # chest freezer
            box(parts, "inside", "body", (0.3, 1.4, 0.03), (0.85, (sw_y0 + sw_y1) * 0.5, sz0 - 0.03), "chrome")     # inner counter
            for k in range(2):
                box(parts, "inside", "body", (0.3, 1.6, 0.02), (-hw + 0.2, ym, 1.6 + k * 0.4), "wood")            # shelves
                for j in range(8):
                    _add(parts, "inside", "body", bm_cyl(0.03, 0.0, 0.11, 8, 'Z', (-hw + 0.2, ym - 0.7 + j * 0.2, 1.62 + k * 0.4)), "wood")
            box(parts, "inside", "body", (W - 0.14, 0.02, z1 - z0 - 0.1), (0, y0 - 0.02, (z0 + z1) * 0.5), "interior")   # bulkhead
    return ex


def _recipe():
    L, Lc, W = 5.75, 2.05, 2.1
    R, Rr, tw = tyre(215, 65, 16)
    spec, d_a, d_b = icecream_cab_spec(L, Lc, W, 2.12)
    rax_d = 0.95 + 3.45
    rc = {
        "name": "festival_ice_cream_van_a", "kind": "van", "body": spec, "paint": (0.97, 0.95, 0.88), "paint2": (0.90, 0.48, 0.62),
        "wheel": {"R": R, "Rr": Rr, "tw": tw, "style": "steel_trim", "nuts": 5, "trim_cover": True, "trim_mat": "chrome", "disc": True},
        "track": W - tw - 0.12, "axles": [0.95, rax_d], "steer_axles": [0],
        "detail": {
            "head": {"x": W * 0.5 - 0.28, "z": 0.82, "w": 0.34, "h": 0.17, "r": 0.04, "slant": 0.04, "bowls": 2, "auto": True, "turn": 0.6},
            "grille": {"z": 0.75, "w": 0.75, "h": 0.12, "slats": 3, "frame": "chrome", "r": 0.03, "slat": "chrome"},
            "front_panels": [(0.0, 0.42, 1.35, 0.13, "chrome", 0.03)],
            "plate_f": 0.45,
            "handles": [(d_b - 0.17, 0.98, "door_fr", "door_fl", "chrome")],
            "mirror": {"d": d_a + 0.1, "mat": "chrome"},
            "wipers": {"pivots": (0.42, -0.24), "length": 0.68},
            "badge": {"text": "CORVAN", "plane": "front", "z": 0.93, "x": 0.0, "size": 0.04},
        },
        "interior": {"z_floor": 0.48, "d_dash": 0.86, "d_front_seat": d_a + 0.85, "d_rear_seat": None, "d_end": Lc - 0.05, "shelf": None,
                     "doors": [(d_a, d_b, "door_fr", "door_fl")]},
        "condition": lambda co, n: 0.92, "extras": [], "shift_y": (L - Lc) * 0.5, "dirt": 0.25,
        "mat_colours": {"lettering2": (0.42, 0.10, 0.26), "wood": (0.78, 0.55, 0.26), "flag_b": (0.98, 0.86, 0.45), "flag_c": (0.55, 0.78, 0.92),
                        "flag_a": (0.92, 0.36, 0.52)},
    }

    def prep(parts, s, surf, lod, info):
        info["rear_axle_y"] = s.L * 0.5 - rax_d
        info["R"] = R
    rc["extras"] = [prep, box_body(L, Lc, W)]
    return rc


add(_recipe())

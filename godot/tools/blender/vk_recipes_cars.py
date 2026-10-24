# AeroSim vehicle kit: car-type recipes (lofted bodies): modern hatchbacks, estate, saloon, SUV, the 1980s estate of the
# Lake Car story and the 1984 cruiser, pickups and vans. Registered into vk_recipes.RECIPES on import.
import math, random
from vk_recipes import add, tyre, bumper_grooves, doors, door_list
from vk_body import (R_BOT, R_FLOOR, R_ROCK, R_SILL, R_LOW, R_MID, R_SH, R_BELT, R_GL0, R_GL1, R_CANT, R_ROOF1, R_ROOF2, R_TOP)
import vk_extras as X


def modern(name, cls, L, W, H, wb, fo, tyre_rt, paint, marque, *, three=False, style="alloy5", spokes=5, cond=None,
           nose=0.78, cowl_d=1.15, cowl_z=0.99, roof_d=1.95, roof_end=None, belt0=0.84, belt1=1.0, sill=0.31, gc=0.155,
           extras=None, detail_over=None, interior_over=None, body_over=None, plan_rf=0.28, mirror_mat="paint",
           handle_mat="paint", cladding=False, rails=False, kind="car", pose="", flat=None, paint2=None, mat_colours=None,
           head=None, tail=None, grille=None, boxy=False):
    R, Rr, tw = tyre_rt
    ra = R + 0.045
    fa, rax = fo, fo + wb
    if roof_end is None:
        roof_end = {"hatch": L - 0.5, "estate": L - 0.42, "saloon": L - 1.45, "suv": L - 0.4}[cls]
    fil = 0.35 if boxy else 1.0          # older cars: tighter radii everywhere
    zr = L - 0.16
    if cls == "hatch":
        tail_top = [(roof_end, H - 0.025, 0.12 * fil), (zr, 1.035, 0.03), (L, 1.0, 0)]
        backlight = (roof_end + 0.04, zr - 0.035)
    elif cls in ("estate", "suv"):
        zt = belt1 + 0.03
        tail_top = [(roof_end, H - 0.03, 0.1 * fil), (L - 0.1, zt + 0.03, 0.03), (L, zt, 0)]
        backlight = (roof_end + 0.03, L - 0.13)
    else:
        deck_d = L - 0.92
        zd = belt1 + 0.045
        tail_top = [(roof_end, H - 0.03, 0.18 * fil), (deck_d, zd + 0.02, 0.08 * fil), (L - 0.06, zd, 0.03), (L, zd - 0.02, 0)]
        backlight = (roof_end + 0.05, deck_d - 0.03)
    top = [(0, nose, 0), (0.06, nose + 0.04 * fil, 0.04), (0.30, nose + 0.1 * fil, 0.3 * fil), (cowl_d, cowl_z, 0.08 * fil),
           (roof_d, H - 0.01, 0.22 * fil)] + tail_top
    if cls == "saloon":
        rear_face = [(0.0, 0.10), (0.36, 0.05), (0.46, 0.006), (0.55, 0.0), (0.66, 0.0), (0.86, 0.02), (belt1 + 0.02, 0.05), (belt1 + 0.07, 0.09)]
    else:
        rear_face = [(0.0, 0.10), (0.36, 0.05), (0.46, 0.006), (0.55, 0.0), (0.66, 0.0), (0.86, 0.018), (0.98, 0.04), (1.04, 0.07)]
    sc = min(1.1, max(0.9, wb / 2.64))
    d_door_a = cowl_d + 0.08
    d_door_b = d_door_a + (1.20 if not three else 1.62) * sc
    if cls == "saloon":
        d_door_c = roof_end + 0.06
    else:
        d_door_c = min(rax - ra + 0.18, roof_end - 0.08)
    windows = [(d_door_a + 0.06, d_door_b - 0.05)]
    if not three:
        windows.append((d_door_b + 0.05, d_door_c - (0.10 if cls != "saloon" else 0.16)))
    else:
        windows.append((d_door_b + 0.08, roof_end - 0.14))
    if cls in ("estate", "suv"):
        windows.append((d_door_c + 0.07, roof_end - 0.08))
    panels = doors(d_door_a, d_door_b, d_door_c, (rax - ra - 0.04) if cls != "saloon" else None, three)
    panels.append({"kind": "lid", "r": R_BELT, "d0": 0.0, "d1": cowl_d, "across0": False, "cap_front": True, "bone": "bonnet"})
    if cls == "saloon":
        panels.append({"kind": "lid", "r": R_BELT, "d0": backlight[1] + 0.03, "d1": L, "across1": False, "cap_rear_role": R_MID,
                       "bone": "boot", "open": 72})
    else:
        panels.append({"kind": "tailgate", "r": R_CANT, "rb": R_MID, "d0": roof_end - 0.02, "bone": "tailgate", "open": 80})
    body = dict(
        L=L, W=W, H=H, top=top,
        bot=[(0, 0.33, 0), (0.28, gc + 0.05, 0.15), (0.85, gc, 0.2), (L - 0.85, gc, 0.2), (L - 0.3, gc + 0.1, 0.15), (L, 0.36, 0)],
        sill=[(0, 0.44, 0), (0.62, sill, 0.2), (L - 0.62, sill, 0.2), (L, 0.47, 0)],
        belt=[(0, belt0, 0), (cowl_d + 0.05, belt0 + 0.13 * fil, 0.3), (L * 0.75, belt1, 0.2), (L, belt1 + 0.03, 0)],
        front_face=[(0.0, 0.10), (0.33, 0.055), (0.40, 0.014), (0.47, 0.0), (0.57, 0.004), (0.63, 0.028 * fil), (nose - 0.05, 0.04 * fil),
                    (nose + 0.04, 0.07 * fil)],
        rear_face=rear_face, fz=0.5, rz=0.4,
        sh_drop=0.065, belt_in=0.042, th=0.21 if cls != "suv" else 0.16, side_bulge=0.016 * fil, plan_rf=plan_rf, plan_rr=0.22 * fil + 0.04,
        cap_bulge_f=0.06 * fil, windscreen=(cowl_d + 0.07, roof_d - 0.04), backlight=backlight, windows=windows,
        panels=panels, grooves=bumper_grooves(L, fa - ra - 0.02, rax + ra + 0.02),
        arches=[(fa, ra), (rax, ra)], extra_stations=[fa - ra - 0.02, rax + ra + 0.02],
    )
    if boxy:
        body.update(erode=0.04, crown=0.012)
    elif cls in ("estate", "suv"):
        # the tailgate glass is nearly upright: carry the rear face up to the roof so the top roles do not bunch at the tail
        body.update(erode=0.05)
    if cladding:
        body["regions"] = [{"d0": 0.0, "d1": L, "r0": R_FLOOR, "r1": R_SILL, "mat": "trim"}]
    if body_over:
        body.update(body_over)
    hz = nose - 0.08
    detail = {
        "head": head or {"x": W * 0.5 - 0.24, "z": hz + 0.01, "w": 0.46, "h": 0.10, "r": 0.035, "slant": 0.045, "bowls": 2, "auto": True,
                         "turn": 0.55},
        "tail": tail or {"x": W * 0.5 - 0.17, "z": (0.90 if cls != "saloon" else belt1 - 0.07), "w": 0.26, "h": 0.15, "r": 0.03,
                         "auto": True, "turn": 0.35},
        "grille": grille or {"z": hz - 0.08, "w": 0.62, "h": 0.085, "slats": 2, "frame": "chrome", "r": 0.02},
        "front_panels": [(0.0, 0.40, 1.0, 0.11, "trim", 0.03)],
        "plate_f": 0.47, "plate_r": (0.70 if cls != "saloon" else 0.60), "plate_r_bone": "tailgate" if cls != "saloon" else "boot",
        "handles": [(d_door_b - 0.17, belt0 + 0.02, "door_fr", "door_fl", handle_mat)] +
                   ([] if three else [(d_door_c - 0.2, belt0 + 0.05, "door_rr", "door_rl", handle_mat)]),
        "mirror": {"d": d_door_a + 0.1, "mat": mirror_mat},
        "wipers": {"pivots": (0.38, -0.20), "length": 0.56 * min(1.1, W / 1.8)},
        "exhaust": -0.48,
        "badge": {"text": marque, "z": (0.83 if cls != "saloon" else belt1 - 0.17), "x": 0.0, "size": 0.035,
                  "bone": "tailgate" if cls != "saloon" else "boot"},
    }
    if rails:
        detail["roof_rails"] = (roof_d + 0.1, roof_end - 0.05)
    if detail_over:
        for kk, vv in detail_over.items():
            if vv is None:
                detail.pop(kk, None)
            else:
                detail[kk] = vv
    interior = {"z_floor": 0.30, "d_dash": cowl_d + 0.05, "d_front_seat": d_door_a + 0.95, "d_rear_seat": d_door_a + 1.82 * min(1.08, sc),
                "d_end": L - 0.22 if cls != "saloon" else backlight[1] - 0.1,
                "shelf": belt1 - 0.02 if cls in ("hatch", "saloon") else None,
                "shelf_d0": roof_end - 0.15 if cls == "hatch" else d_door_c + 0.05, "doors": door_list(d_door_a, d_door_b, d_door_c, three)}
    if three:
        interior["d_rear_seat"] = d_door_b + 0.42
    if interior_over:
        interior.update(interior_over)
    rc = {
        "name": name, "kind": kind, "body": body, "paint": paint, "pose": pose,
        "wheel": {"R": R, "Rr": Rr, "tw": tw, "style": style, "spokes": spokes, "holes": 8, "nuts": 5 if style in ("alloy5", "multi") else 4,
                  "trim_cover": style == "steel_trim", "hubcap": style == "steel_cap"},
        "track": W - tw - 0.07, "axles": [fa, rax], "steer_axles": [0],
        "detail": detail, "interior": interior, "condition": cond, "extras": extras or [],
    }
    if paint2:
        rc["paint2"] = paint2
    if mat_colours:
        rc["mat_colours"] = mat_colours
    if flat:
        rc["flat_tyre"] = flat
    return rc


def rust_cond(level, seed=1):
    """A condition field: worse low down, round the arches and sills, in patches. level 0 (new) to 1 (rusted out)."""
    def f(co, n):
        low = max(0.0, 1.0 - (co.z - 0.15) / 0.55)
        patch = 0.5 + 0.5 * math.sin(co.x * 7.1 + seed) * math.sin(co.y * 5.3 + 2 * seed) * math.sin(co.z * 9.7)
        c = 1.0 - level * (0.35 + 0.55 * low + 0.3 * patch)
        return max(0.05, min(1.0, c))
    return f


# --------------------------------------------------------------------------------------------- everyday traffic cars
add(modern("car_hatch_a", "hatch", 4.0, 1.72, 1.46, 2.46, 0.80, tyre(185, 60, 15), (0.62, 0.64, 0.66), "TAMSIN", three=True,
           style="alloy5", nose=0.76, cowl_d=1.05, cowl_z=0.97, roof_d=1.85, plan_rf=0.3))
add(modern("car_hatch_b", "hatch", 4.3, 1.80, 1.45, 2.64, 0.88, tyre(205, 55, 16), (0.50, 0.05, 0.04), "ARDEN",
           cond=lambda co, n: 0.86))
add(modern("car_estate_a", "estate", 4.77, 1.83, 1.49, 2.79, 0.93, tyre(215, 55, 17), (0.16, 0.20, 0.22), "VELIA",
           style="multi", spokes=10, nose=0.78, cowl_d=1.22, cowl_z=1.0, roof_d=2.05, rails=True, belt1=1.02))


# --------------------------------------------------------------------------------------------------- the police cars
def police_livery(L, d0, d1, z, band=0.12, word_d=None, text="HALLOWAY PROVINCIAL POLICE", text_z=None, size=0.07):
    return {
        "strips": [{"d0": d0, "d1": d1, "z": z, "h": band, "mat": "lettering2", "off": 0.0035},
                   {"d0": d0, "d1": d1, "z": z + band * 0.5 + 0.012, "h": 0.016, "mat": "lightbar_red" if False else "lettering", "off": 0.0038},
                   {"d0": d0, "d1": d1, "z": z - band * 0.5 - 0.012, "h": 0.016, "mat": "lettering", "off": 0.0038}],
    }


def _police_suv():
    L = 4.92
    rc = modern("police_suv_a", "suv", L, 1.93, 1.78, 2.87, 0.92, tyre(235, 65, 17), (0.93, 0.93, 0.91), "KESTREL",
                style="steel_trim", nose=0.98, cowl_d=1.28, cowl_z=1.16, roof_d=2.0, belt0=1.02, belt1=1.12, sill=0.42, gc=0.2,
                cladding=True, rails=False, plan_rf=0.24, mirror_mat="trim", handle_mat="trim", paint2=(0.06, 0.12, 0.32),
                mat_colours={"lettering2": (0.05, 0.12, 0.38), "lettering": (0.92, 0.75, 0.1)},
                extras=[X.push_bar(0.38, 0.92, 0.95)])
    lv = police_livery(L, 0.55, L - 0.35, 0.78)
    rc["detail"]["strips"] = lv["strips"]
    rc["detail"]["lightbar"] = {"d": 2.3, "style": "modern", "w": 1.2}
    rc["detail"]["aerial"] = {"d": 2.95, "x": 0.25}
    rc["detail"]["lettering"] = [{"text": "HALLOWAY PROVINCIAL POLICE", "d": 2.35, "z": 0.93, "size": 0.055, "mat": "lettering2"},
                                 {"text": "POLICE", "d": 0.72, "z": 0.62, "size": 0.07, "mat": "lettering2"}]
    rc["wheel"]["trim_mat"] = "rim_steel"
    return rc


add(_police_suv())


def _police_saloon():
    L = 4.85
    rc = modern("police_saloon_a", "saloon", L, 1.83, 1.46, 2.8, 0.93, tyre(215, 55, 17), (0.22, 0.23, 0.25), "HALDEN",
                style="steel_trim", nose=0.76, cowl_d=1.25, cowl_z=0.98, roof_d=2.08, belt0=0.86, belt1=1.0,
                mat_colours={"lettering2": (0.05, 0.12, 0.38), "lettering": (0.85, 0.85, 0.82)})
    rc["detail"]["strips"] = [{"d0": 0.7, "d1": L - 0.4, "z": 0.70, "h": 0.05, "mat": "lettering", "off": 0.0035},
                              {"d0": 0.7, "d1": L - 0.4, "z": 0.665, "h": 0.022, "mat": "lettering2", "off": 0.0037}]
    rc["detail"]["lightbar"] = {"d": 2.4, "style": "modern", "w": 1.05}
    rc["detail"]["lettering"] = [{"text": "HALLOWAY PROVINCIAL POLICE", "d": 2.45, "z": 0.80, "size": 0.045, "mat": "lettering"}]
    rc["detail"]["aerial"] = {"d": 3.6, "x": 0.0}
    rc["wheel"]["trim_mat"] = "rim_steel"
    return rc


add(_police_saloon())


# ------------------------------------------------------------------------------------ the Lake Car: a late-1980s estate
def _lake_car(name, sticker):
    L = 4.79
    W = 1.72
    head = {"x": W * 0.5 - 0.28, "z": 0.66, "w": 0.40, "h": 0.15, "r": 0.012, "slant": 0.0, "bowls": 1, "bezel": True,
            "auto": True, "turn": 0.7}
    tail = {"x": W * 0.5 - 0.09, "z": 0.78, "w": 0.14, "h": 0.36, "r": 0.012, "auto": True, "turn": 0.5,
            "layout": [("lamp_ind", 0.0, 1.0, 0.75, 1.0), ("lamp_tail", 0.0, 1.0, 0.36, 0.75), ("lamp_brake", 0.0, 1.0, 0.14, 0.36),
                       ("lamp_reverse", 0.0, 1.0, 0.0, 0.14)]}
    grille = {"z": 0.64, "w": 0.66, "h": 0.15, "slats": 0, "vbars": 9, "frame": "chrome", "r": 0.008, "slat": "chrome", "back": "trim"}
    extras = [X.bumpers(0.40, 0.44, h=0.12, depth=0.11, mat="chrome", wrap=0.3), X.gutters("chrome"),
              X.broken_glass("tailgate", centre=(-0.12, 1.12), radius=0.30)]
    if sticker:
        extras.append(X.sticker("VOSS & SON\nMOTOR WORKS", -1, 3.95, 1.12, 0.14, 0.11, "lettering", "lettering2", bone="body"))
    rc = modern(name, "estate", L, W, 1.44, 2.64, 0.97, tyre(185, 70, 14), (0.24, 0.36, 0.55), "BRASK",
                style="steel_cap", nose=0.74, cowl_d=1.36, cowl_z=0.95, roof_d=2.0, roof_end=L - 0.36, belt0=0.86, belt1=0.92,
                sill=0.33, gc=0.17, plan_rf=0.12, mirror_mat="chrome", handle_mat="chrome", boxy=True,
                head=head, tail=tail, grille=grille, cond=rust_cond(0.6, seed=4), extras=extras, flat="rr",
                pose="tailgate_open", body_over={"th": 0.16, "sh_drop": 0.03, "belt_in": 0.02, "side_bulge": 0.004,
                                                 "front_face": [(0.0, 0.04), (0.3, 0.02), (0.45, 0.0), (0.62, 0.0), (0.70, 0.01), (0.78, 0.03)],
                                                 "rear_face": [(0.0, 0.05), (0.3, 0.02), (0.45, 0.0), (0.9, 0.0), (1.0, 0.03), (1.1, 0.06)],
                                                 "seal_mat": "chrome", "frame_mat": "trim", "pillar_mat": "trim"})
    rc["detail"]["front_panels"] = []
    rc["detail"].pop("plate_f", None)       # the plates are missing (the story)
    rc["detail"]["plate_r"] = None
    rc["detail"].pop("plate_r", None)
    rc["detail"]["strips"] = [{"d0": 0.35, "d1": L - 0.3, "z": 0.58, "h": 0.035, "mat": "trim", "off": 0.006}]
    rc["detail"]["wipers"] = {"pivots": (0.36, -0.22), "length": 0.5}
    rc["detail"].pop("exhaust", None)
    rc["detail"]["badge"]["text"] = "BRASK 245"
    rc["wheel"]["cap_mat"] = "chrome"
    rc["mat_colours"] = {"lettering": (0.9, 0.86, 0.7), "lettering2": (0.12, 0.25, 0.15)}
    rc["interior"]["shelf"] = None
    return rc


add(_lake_car("lake_car_estate_a", False))
add(_lake_car("lake_car_estate_b", True))


# ---------------------------------------------------------------------------------- the 1984 provincial police cruiser
def _cruiser():
    L, W = 5.30, 1.92
    head = {"x": W * 0.5 - 0.27, "z": 0.70, "w": 0.36, "h": 0.12, "r": 0.008, "slant": 0.0, "bowls": 2, "bezel": True, "auto": True,
            "turn": 0.7}
    tail = {"x": W * 0.5 - 0.3, "z": 0.74, "w": 0.52, "h": 0.12, "r": 0.008, "auto": True, "turn": 0.6,
            "layout": [("lamp_tail", 0.0, 0.55, 0.0, 1.0), ("lamp_brake", 0.55, 0.85, 0.0, 1.0), ("lamp_reverse", 0.85, 1.0, 0.0, 1.0)]}
    grille = {"z": 0.66, "w": 0.70, "h": 0.15, "slats": 5, "vbars": 7, "frame": "chrome", "r": 0.006, "slat": "chrome", "back": "trim"}

    def two_tone(B, f, i, h, side, dm):
        rh = B.role_h
        if h >= rh[R_CANT]:
            return True            # the dark roof
        for (a, b) in ((1.43, 2.6), (2.6, 3.62)):
            if a <= dm <= b and rh[R_SILL] <= h < rh[R_BELT]:
                return True        # the dark doors
        return False

    rc = modern("cruiser_1984_a", "saloon", L, W, 1.42, 2.95, 1.06, tyre(225, 70, 15), (0.90, 0.90, 0.87), "HALDEN",
                style="steel_cap", nose=0.80, cowl_d=1.62, cowl_z=1.0, roof_d=2.25, roof_end=L - 1.62, belt0=0.92, belt1=0.98,
                sill=0.35, gc=0.17, plan_rf=0.1, mirror_mat="chrome", handle_mat="chrome", boxy=True, head=head, tail=tail,
                grille=grille, paint2=(0.07, 0.09, 0.14), cond=rust_cond(0.42, seed=9),
                mat_colours={"lettering": (0.86, 0.85, 0.8), "lettering2": (0.75, 0.62, 0.2)},
                extras=[X.bumpers(0.44, 0.47, h=0.13, depth=0.12, mat="chrome", wrap=0.34), X.gutters("chrome"), X.spotlight(-1)],
                body_over={"th": 0.18, "sh_drop": 0.025, "belt_in": 0.02, "side_bulge": 0.003, "paint2": two_tone,
                           "front_face": [(0.0, 0.04), (0.3, 0.02), (0.45, 0.0), (0.66, 0.0), (0.74, 0.01), (0.82, 0.03)],
                           "rear_face": [(0.0, 0.05), (0.3, 0.02), (0.45, 0.0), (0.85, 0.0), (0.98, 0.02), (1.04, 0.05)],
                           "seal_mat": "chrome", "frame_mat": "chrome", "pillar_mat": "trim"})
    d = rc["detail"]
    d["front_panels"] = []
    d["strips"] = [{"d0": 0.4, "d1": L - 0.35, "z": 0.62, "h": 0.03, "mat": "chrome", "off": 0.006}]
    d["lightbar"] = {"d": 2.55, "style": "1980s", "w": 1.3}
    d["aerial"] = {"d": 4.6, "x": 0.3, "whip": True}
    d["lettering"] = [{"text": "HALLOWAY", "d": 2.55, "z": 0.84, "size": 0.075, "mat": "lettering"},
                      {"text": "PROVINCIAL POLICE", "d": 2.55, "z": 0.73, "size": 0.05, "mat": "lettering"}]
    d["badge"]["text"] = "HALDEN 400"
    d["wipers"] = {"pivots": (0.42, -0.22), "length": 0.55}
    rc["wheel"]["cap_mat"] = "chrome"
    rc["interior"]["shelf"] = 0.97
    return rc


add(_cruiser())


# ---------------------------------------------------------------------------------------------------------- pickups
def pickup(name, L, W, H, wb, fo, tyre_rt, paint, marque, cab_len, bed_h, style, cond=None, older=False):
    """A pickup: a lofted cab and nose, and a separate bed body with an open tub and a tailgate."""
    R, Rr, tw = tyre_rt
    ra = R + 0.05
    fa, rax = fo, fo + wb
    nose = 1.0 if not older else 0.92
    cowl_d, cowl_z = (1.42, 1.22) if not older else (1.25, 1.12)
    roof_d = cowl_d + 0.72
    Lc = cab_len
    top = [(0, nose, 0), (0.05, nose + 0.04, 0.03), (0.4, nose + 0.08, 0.3), (cowl_d, cowl_z, 0.06), (roof_d, H - 0.01, 0.16),
           (Lc - 0.06, H - 0.02, 0.06), (Lc, H - 0.08, 0)]
    belt = cowl_z - 0.02
    d_a = cowl_d + 0.08
    crew = not older
    d_b = d_a + (1.05 if crew else 1.15)
    d_c = Lc - 0.08
    windows = [(d_a + 0.06, d_b - 0.05)] + ([(d_b + 0.05, d_c - 0.06)] if crew else [])
    panels = [{"kind": "door", "d0": d_a, "d1": d_b, "r0": R_SILL, "r1": R_CANT, "bone": {1: "door_fr", -1: "door_fl"}, "open": 66}]
    if crew:
        panels.append({"kind": "door", "d0": d_b, "d1": d_c, "r0": R_SILL, "r1": R_CANT, "bone": {1: "door_rr", -1: "door_rl"}, "open": 70})
    panels.append({"kind": "lid", "r": R_BELT, "d0": 0.0, "d1": cowl_d, "across0": False, "cap_front": True, "bone": "bonnet"})
    sill = 0.45 if not older else 0.42
    body = dict(
        L=Lc, W=W, H=H, top=top,
        bot=[(0, 0.42, 0), (0.3, 0.33, 0.15), (0.9, 0.3, 0.2), (Lc, 0.3, 0)],
        sill=[(0, 0.55, 0), (0.7, sill, 0.2), (Lc, sill, 0)],
        belt=[(0, nose - 0.02, 0), (cowl_d, belt, 0.2), (Lc, belt + 0.02, 0)],
        front_face=[(0.0, 0.06), (0.4, 0.02), (0.5, 0.0), (0.7, 0.0), (nose - 0.05, 0.01), (nose + 0.05, 0.05)],
        rear_face=[(0.0, 0.0), (H, 0.0)], fz=0.45, rz=0.12, sh_drop=0.05, belt_in=0.03, th=0.15, side_bulge=0.008, plan_rf=0.16,
        plan_rr=0.05, cap_bulge_f=0.03, cap_bulge_r=0.0, erode=0.05, crown=0.02,
        windscreen=(cowl_d + 0.06, roof_d - 0.04), backlight=None, windows=windows, panels=panels,
        grooves=[{"kind": "caprow", "r": R_LOW, "front": True}, {"kind": "line_role", "r": R_LOW, "d0": 0.0, "d1": fa - ra - 0.02}],
        arches=[(fa, ra)], extra_stations=[fa - ra - 0.02],
        cap_glass=[{"front": False, "r0": R_GL0, "r1": R_GL1, "x0": 0.0, "x1": W * 0.5 - 0.28}],
        regions=[{"d0": 0.0, "d1": Lc, "r0": R_FLOOR, "r1": R_SILL, "mat": "trim"}] if not older else [],
    )
    bed_L = L - Lc - 0.05
    bed = dict(L=bed_L, W=W, H=bed_h,
               top=[(0, bed_h, 0), (bed_L, bed_h, 0)],
               bot=[(0, 0.42, 0), (bed_L - 0.3, 0.42, 0.1), (bed_L, 0.5, 0)],
               sill=[(0, 0.52, 0), (bed_L, 0.56, 0)],
               belt=[(0, bed_h - 0.02, 0), (bed_L, bed_h - 0.02, 0)],
               front_face=[(0.0, 0.0), (2.0, 0.0)], rear_face=[(0.0, 0.03), (0.5, 0.0), (2.0, 0.0)], fz=0.1, rz=0.15,
               sh_drop=0.06, belt_in=0.02, th=0.04, side_bulge=0.006, plan_rf=0.03, plan_rr=0.06, cap_bulge_f=0.0, cap_bulge_r=0.0,
               crown=0.004, erode=0.0, windscreen=(0, 0), backlight=None, windows=[], panels=[], grooves=[],
               arches=[(rax - (Lc + 0.05), ra)], creases={R_SH: True, R_BELT: True})
    extras = [X.aux_body(bed, Lc + 0.05, "body", tub=(0.07, 0.62, True), tailgate=(0.58, bed_h - 0.02, W - 0.16))]
    if older:
        extras.append(X.bumpers(0.48, None, h=0.14, depth=0.12, mat="chrome", wrap=0.25))
    hz = nose - 0.12
    detail = {
        "head": {"x": W * 0.5 - 0.26, "z": hz, "w": 0.38 if not older else 0.3, "h": 0.17 if not older else 0.13, "r": 0.03 if not older else 0.01,
                 "slant": 0.0, "bowls": 2, "auto": True, "turn": 0.6, "bezel": older},
        "grille": {"z": hz - 0.04, "w": 0.95 if not older else 0.7, "h": 0.26 if not older else 0.14, "slats": 3 if not older else 4,
                   "vbars": 0 if not older else 10, "frame": "chrome", "r": 0.03, "slat": "chrome" if not older else "trim_grey"},
        "front_panels": [(0.0, 0.47, 1.25, 0.14, "trim" if not older else "chrome", 0.02)] if not older else [],
        "plate_f": 0.42,
        "handles": [(d_b - 0.17, belt - 0.12, "door_fr", "door_fl", "trim")] + ([(d_c - 0.2, belt - 0.1, "door_rr", "door_rl", "trim")] if crew else []),
        "mirror": {"d": d_a + 0.1, "mat": "trim"},
        "wipers": {"pivots": (0.4, -0.22), "length": 0.6},
        "badge": {"text": marque, "plane": "front", "z": nose - 0.02, "x": 0.0, "size": 0.05},
    }
    interior = {"z_floor": 0.48, "d_dash": cowl_d + 0.05, "d_front_seat": d_a + 0.92, "d_rear_seat": (d_b + 0.7) if crew else None,
                "d_end": Lc - 0.06, "shelf": None, "doors": [(d_a, d_b, "door_fr", "door_fl")] + ([(d_b, d_c, "door_rr", "door_rl")] if crew else [])}
    tail = [{"x": W * 0.5 - 0.06, "z": 0.95 if not older else 0.85, "w": 0.1, "h": 0.32, "r": 0.01, "auto": False,
             "plane": "rear", "layout": [("lamp_tail", 0.0, 1.0, 0.55, 1.0), ("lamp_brake", 0.0, 1.0, 0.25, 0.55),
                                         ("lamp_ind", 0.0, 1.0, 0.1, 0.25), ("lamp_reverse", 0.0, 1.0, 0.0, 0.1)]}]
    rc = {
        "name": name, "kind": "pickup", "body": body, "paint": paint,
        "wheel": {"R": R, "Rr": Rr, "tw": tw, "style": style, "spokes": 6, "holes": 8, "nuts": 6, "trim_cover": False, "hubcap": style == "steel_cap",
                  "pcd": 0.07},
        "track": W - tw - 0.08, "axles": [fa, rax], "steer_axles": [0],
        "detail": detail, "interior": interior, "condition": cond, "extras": extras,
        "tails_after_aux": tail, "shift_y": (L - Lc) * 0.5,
    }
    rc["detail"]["plate_r_aux"] = 0.78
    return rc


add(pickup("pickup_a", 5.3, 1.98, 1.84, 3.2, 0.95, tyre(265, 65, 17), (0.12, 0.18, 0.34), "CORVAN", 3.2, 1.26, "alloy5"))
add(pickup("pickup_b", 4.9, 1.82, 1.70, 3.0, 0.84, tyre(205, 75, 15), (0.62, 0.55, 0.40), "BRASK", 2.75, 1.12, "steel_cap",
           cond=rust_cond(0.55, seed=2), older=True))


# ------------------------------------------------------------------------------------------------------------- vans
def van(name, L, W, H, wb, fo, tyre_rt, paint, marque, rear_glass=True, slide=True, cond=None, extras=None, paint2=None,
        regions=None, body_over=None, detail_over=None, box=None):
    """A one-box van: short bonnet, raked screen, long flat roof, upright rear with barn doors, a sliding side door."""
    R, Rr, tw = tyre_rt
    ra = R + 0.05
    fa, rax = fo, fo + wb
    nose = 0.92
    cowl_d, cowl_z = 0.82, 1.14
    roof_d = 1.62
    top = [(0, nose, 0), (0.05, nose + 0.04, 0.04), (0.45, nose + 0.16, 0.35), (cowl_d, cowl_z, 0.1), (roof_d, H - 0.01, 0.3),
           (L - 0.1, H - 0.02, 0.06), (L, H - 0.07, 0)]
    belt0 = 1.08
    d_a = cowl_d + 0.12
    d_b = d_a + 0.95
    d_c = d_b + 1.0
    panels = [{"kind": "door", "d0": d_a, "d1": d_b, "r0": R_SILL, "r1": R_CANT, "bone": {1: "door_fr", -1: "door_fl"}, "open": 70},
              {"kind": "lid", "r": R_BELT, "d0": 0.0, "d1": cowl_d - 0.04, "across0": False, "cap_front": True, "bone": "bonnet", "open": 50},
              {"kind": "rear_doors", "rb": R_SILL, "rt": R_CANT, "bone": {1: "door_rear_r", -1: "door_rear_l"}, "open": 100}]
    if slide:
        panels.append({"kind": "door", "d0": d_b + 0.06, "d1": d_c, "r0": R_SILL, "r1": R_CANT, "bone": {1: "door_slide_r"}, "side": 1,
                       "slide": True})
    body = dict(
        L=L, W=W, H=H, top=top,
        bot=[(0, 0.36, 0), (0.3, 0.24, 0.15), (0.9, 0.2, 0.2), (L - 0.6, 0.22, 0.2), (L, 0.36, 0)],
        sill=[(0, 0.5, 0), (0.7, 0.36, 0.2), (L - 0.5, 0.38, 0.2), (L, 0.48, 0)],
        belt=[(0, nose - 0.02, 0), (cowl_d + 0.05, belt0, 0.3), (L, belt0 + 0.02, 0)],
        front_face=[(0.0, 0.08), (0.35, 0.03), (0.45, 0.0), (0.6, 0.0), (0.75, 0.02), (nose + 0.04, 0.06)],
        rear_face=[(0.0, 0.05), (0.42, 0.0), (H, 0.0)], fz=0.45, rz=0.18,
        sh_drop=0.05, belt_in=0.03, th=0.10, side_bulge=0.012, plan_rf=0.3, plan_rr=0.08, cap_bulge_f=0.05, cap_bulge_r=0.01,
        erode=0.06, crown=0.03,
        windscreen=(cowl_d + 0.06, roof_d - 0.05), backlight=None, windows=[(d_a + 0.05, d_b - 0.04)],
        panels=panels, grooves=[{"kind": "caprow", "r": R_LOW, "front": True}, {"kind": "line_role", "r": R_LOW, "d0": 0.0, "d1": fa - ra - 0.02}],
        arches=[(fa, ra), (rax, ra)], extra_stations=[fa - ra - 0.02, cowl_d - 0.04],
        cap_glass=([{"front": False, "r0": R_GL0, "r1": R_CANT, "x0": 0.07, "x1": W * 0.5 - 0.17}] if rear_glass else []),
        regions=regions or [{"d0": 0.0, "d1": L, "r0": R_FLOOR, "r1": R_SILL, "mat": "trim"}],
    )
    if paint2:
        pass
    if body_over:
        body.update(body_over)
    hz = nose - 0.1
    detail = {
        "head": {"x": W * 0.5 - 0.27, "z": hz, "w": 0.36, "h": 0.17, "r": 0.04, "slant": 0.04, "bowls": 2, "auto": True, "turn": 0.6},
        "grille": {"z": hz - 0.06, "w": 0.75, "h": 0.12, "slats": 3, "frame": "trim", "r": 0.03, "slat": "trim_grey"},
        "front_panels": [(0.0, 0.42, 1.3, 0.13, "trim", 0.03)],
        "plate_f": 0.45, "plate_r": 0.55, "plate_r_x": -0.36, "plate_r_bone": "door_rear_l",
        "tail": {"x": W * 0.5 - 0.035, "z": 0.75, "w": 0.06, "h": 0.32, "r": 0.01, "auto": True, "turn": 0.45,
                 "layout": [("lamp_tail", 0.0, 1.0, 0.55, 1.0), ("lamp_brake", 0.0, 1.0, 0.25, 0.55), ("lamp_ind", 0.0, 1.0, 0.1, 0.25),
                            ("lamp_reverse", 0.0, 1.0, 0.0, 0.1)]},
        "handles": [(d_b - 0.17, belt0 - 0.1, "door_fr", "door_fl", "trim")],
        "mirror": {"d": d_a + 0.1, "mat": "trim"},
        "wipers": {"pivots": (0.42, -0.24), "length": 0.68},
        "badge": {"text": marque, "z": 1.2, "x": 0.4, "size": 0.04, "bone": "door_rear_r"},
    }
    if detail_over:
        for kk, vv in detail_over.items():
            if vv is None:
                detail.pop(kk, None)
            else:
                detail[kk] = vv
    interior = {"z_floor": 0.48, "d_dash": cowl_d + 0.02, "d_front_seat": d_a + 0.85, "d_rear_seat": None, "d_end": L - 0.12,
                "shelf": None, "doors": [(d_a, d_b, "door_fr", "door_fl")]}
    rc = {
        "name": name, "kind": "van", "body": body, "paint": paint,
        "wheel": {"R": R, "Rr": Rr, "tw": tw, "style": "steel_trim", "nuts": 5, "trim_cover": True, "trim_mat": "rim_steel"},
        "track": W - tw - 0.09, "axles": [fa, rax], "steer_axles": [0],
        "detail": detail, "interior": interior, "condition": cond, "extras": extras or [],
    }
    if paint2:
        rc["paint2"] = paint2
    return rc


add(van("van_a", 5.3, 1.98, 2.12, 3.3, 0.95, tyre(215, 65, 16), (0.88, 0.88, 0.86), "CORVAN", rear_glass=True, slide=True))
add(van("van_b", 4.4, 1.80, 1.86, 2.78, 0.82, tyre(205, 60, 16), (0.18, 0.28, 0.45), "TAMSIN", rear_glass=False, slide=True))

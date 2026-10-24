# AeroSim vehicle kit: the recipes. Real dimensions from the classes of vehicle they stand for (no real makes: the marques
# are invented: Arden, Velia, Corvan, Halden, Brask, Tamsin, Kestrel). d is metres back from the front of the front bumper;
# z metres above the ground. Paints are sRGB.
import math
from vk_body import (R_BOT, R_FLOOR, R_ROCK, R_SILL, R_LOW, R_MID, R_SH, R_BELT, R_GL0, R_GL1, R_CANT, R_ROOF1, R_ROOF2, R_TOP)

RECIPES = {}


def add(r):
    RECIPES[r["name"]] = r
    return r


def tyre(width_mm, aspect, rim_in):
    """Tyre size to radii: (R overall, Rr rim, tw width) in metres."""
    Rr = rim_in * 0.0254 * 0.5
    return (Rr + width_mm * 0.001 * aspect * 0.01, Rr, width_mm * 0.001)


def bumper_grooves(L, d_front_arch, d_rear_arch, rf=R_LOW, rr=R_LOW):
    return [{"kind": "caprow", "r": rf, "front": True}, {"kind": "line_role", "r": rf, "d0": 0.0, "d1": d_front_arch},
            {"kind": "caprow", "r": rr, "front": False}, {"kind": "line_role", "r": rr, "d0": d_rear_arch, "d1": L}]


def doors(d_a, d_b, d_c=None, d_c_low=None, three=False):
    p = [{"kind": "door", "d0": d_a, "d1": d_b, "r0": R_SILL, "r1": R_CANT, "bone": {1: "door_fr", -1: "door_fl"}, "open": 66}]
    if d_c and not three:
        q = {"kind": "door", "d0": d_b, "d1": d_c, "r0": R_SILL, "r1": R_CANT, "bone": {1: "door_rr", -1: "door_rl"}, "open": 70}
        if d_c_low:
            q["d1_low"] = d_c_low
            q["r_step"] = R_MID
        p.append(q)
    return p


def door_list(d_a, d_b, d_c, three):
    if three:
        return [(d_a, d_b, "door_fr", "door_fl")]
    return [(d_a, d_b, "door_fr", "door_fl"), (d_b, d_c, "door_rr", "door_rl")]

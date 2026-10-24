"""The lake buoys with real lettering (lane/buildings): letters are Blender text in an OFL font (PT Sans Narrow Bold),
extruded 2 to 4 mm and wrapped round the float so they follow its curve, read left to right from outside, and are not
mirrored.
  - story gear lake_buoy_a.glb: the police dive buoy, white sphere, blue band lettered POLICE DIVE (twice round).
  - story gear dive_marker_a.glb: an orange marker float lettered DIVER (twice round), an Alpha flag (white hoist, blue
    swallowtail), the weighted line.
  - assets/models/lettering/buoy_a_lettering.glb: the number 4 (both sides) and HALLOWAY LAKE for the code-built red and
    white channel buoy (NewModels5 buoy_a merges it into its paint).
Waterline y = 0, +Z front, as before. Run: blender -b --factory-startup --python tools/blender/build_buoys.py"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
from bldg_lib import Kit, Acc, V, UP, reset_scene, export, text_obj

GODOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
FONT = "PTSansNarrow-Bold.ttf"


def wrapped(kit, node, txt, size, depth, radius_at, y_base, theta, mat, col, spacing=1.0):
    """Lettering wrapped round the y axis: made flat facing +z, then each point (x along, y up, z out) goes to angle
    theta + x / r at radius r(y) + z."""
    tmp = Acc("tmp")
    ob = text_obj(txt, FONT, size, depth, mat, V(0, 0, 0), V(0, 0, 1), res=4, spacing=spacing)
    kit.take(ob, {mat: col}, node=tmp)
    acc = kit.nodes[node] if isinstance(node, str) else node
    for f in tmp.faces:
        pts = []
        for i in f[0]:
            p = tmp.verts[i]
            y = p.y + y_base
            r = radius_at(y) + p.z
            a = theta + p.x / radius_at(y)
            pts.append(V(r * math.sin(a), y, r * math.cos(a)))
        acc.poly(pts, f[1], f[2], smooth=False)


def lake_buoy(kit):
    R, cy = 0.2, 0.06
    k = kit
    # the float: a white sphere, a blue band round the middle standing 3 mm proud
    prof = [(0.0, cy - R)] + [(R * math.sin(math.pi * i / 16), cy - R * math.cos(math.pi * i / 16)) for i in range(1, 16)] + [(0.0, cy + R)]
    k.lathe(V(0, 0, 0), prof, 32, "enamel", (0.9, 0.9, 0.88))
    band0, band1 = cy - 0.045, cy + 0.045
    br = lambda y: math.sqrt(max(R * R - (y - cy) ** 2, 0.0)) + 0.003
    rings = [(br(band0) - 0.002, band0 - 0.002)] + [(br(band0 + (band1 - band0) * i / 6), band0 + (band1 - band0) * i / 6) for i in range(7)] + [(br(band1) - 0.002, band1 + 0.002)]
    k.lathe(V(0, 0, 0), rings, 48, "enamel", (0.1, 0.22, 0.58))
    for th in (0.0, math.pi):
        wrapped(k, "body", "POLICE DIVE", 0.052, 0.003, br, cy - 0.026, th, "enamel", (0.95, 0.95, 0.93))
    # the stainless eye on top and a cut end of anchor line
    k.cyl(V(0, cy + R - 0.01, 0), V(0, cy + R + 0.05, 0), 0.03, 0.025, 12, "chrome", (0.66, 0.67, 0.69))
    for i in range(12):
        a0, a1 = math.tau * i / 12, math.tau * (i + 1) / 12
        p0 = V(0, cy + R + 0.08 + 0.028 * math.sin(a0), 0.028 * math.cos(a0))
        p1 = V(0, cy + R + 0.08 + 0.028 * math.sin(a1), 0.028 * math.cos(a1))
        k.cyl(p0, p1, 0.006, 0.006, 6, "chrome", (0.66, 0.67, 0.69), caps=0)
    prev = V(0, cy + R + 0.052, 0.028)
    for i in range(1, 9):
        p = V(0.03 * math.sin(i * 0.7), cy + R + 0.05 - i * 0.03, 0.03 + i * 0.03)
        k.cyl(prev, p, 0.008, 0.008, 6, "cloth", (0.86, 0.84, 0.76))
        prev = p


def dive_marker(kit):
    k = kit
    R = 0.07
    # an orange foam float (slightly tapered), DIVER round it in black
    k.cyl(V(0, -0.03, 0), V(0, 0.09, 0), R, R * 0.92, 32, "enamel", (0.96, 0.42, 0.06))
    rad = lambda y: R - (y + 0.03) / 0.12 * R * 0.08 + 0.001
    for th in (0.0, math.pi):
        wrapped(k, "body", "DIVER", 0.038, 0.002, rad, 0.012, th, "enamel", (0.05, 0.05, 0.05))
    # the staff and the Alpha flag: white at the hoist, blue swallowtail at the fly (both faces)
    k.cyl(V(0, 0.09, 0), V(0, 0.52, 0), 0.007, 0.006, 8, "wood", (0.62, 0.5, 0.32))
    top, bot = 0.5, 0.34
    white = [V(0, top, 0.0), V(0, top, 0.1), V(0, bot, 0.1), V(0, bot, 0.0)]
    blue = [V(0, top, 0.1), V(0, top, 0.22), V(0, (top + bot) / 2, 0.16), V(0, bot, 0.22), V(0, bot, 0.1)]
    acc = k.nodes["body"]
    for pts, col in ((white, (0.93, 0.93, 0.95)), (blue, (0.1, 0.24, 0.66))):
        q = [p + V(0.001, 0, 0) for p in pts]
        acc.poly(list(reversed(q)) if False else q[:1] + q[1:], "cloth", col)
        q2 = [p - V(0.001, 0, 0) for p in pts]
        acc.poly(list(reversed(q2)), "cloth", col)
    # the weighted line, 2 m shown, and a lead weight
    prev = V(0, -0.03, 0)
    for i in range(1, 11):
        p = V(0.01 * math.sin(i), -0.03 - i * 0.2, 0.012 * math.cos(i))
        k.cyl(prev, p, 0.004, 0.004, 5, "cloth", (0.7, 0.68, 0.55))
        prev = p
    k.cyl(prev, prev + V(0, -0.12, 0), 0.04, 0.05, 12, "rust", (0.35, 0.36, 0.4))


def channel_lettering(kit):
    """For NewModels5 buoy_a: the hull profile (y, r) from new_models5.gd; letters stand 3 mm proud of it."""
    prof = [(-0.62, 0.0), (-0.55, 0.22), (-0.38, 0.38), (-0.15, 0.46), (0.1, 0.47), (0.28, 0.42), (0.42, 0.3), (0.5, 0.2), (0.52, 0.0)]

    def r_at(y):
        for (y0, r0), (y1, r1) in zip(prof, prof[1:]):
            if y0 <= y <= y1:
                return r0 + (r1 - r0) * (y - y0) / (y1 - y0) + 0.003
        return 0.2
    for th in (0.0, math.pi):
        wrapped(kit, "body", "4", 0.3, 0.004, r_at, -0.13, th, "paint", (0.08, 0.08, 0.08))
    for th in (math.pi / 2, -math.pi / 2):
        wrapped(kit, "body", "HALLOWAY LAKE", 0.06, 0.003, r_at, 0.02, th, "paint", (0.08, 0.08, 0.08))


def main():
    jobs = [
        ("lake_buoy_a", os.path.join(GODOT, "assets", "models", "story", "gear", "lake_buoy_a.glb"), lake_buoy),
        ("dive_marker_a", os.path.join(GODOT, "assets", "models", "story", "gear", "dive_marker_a.glb"), dive_marker),
        ("buoy_a_lettering", os.path.join(GODOT, "assets", "models", "lettering", "buoy_a_lettering.glb"), channel_lettering),
    ]
    for name, path, fn in jobs:
        reset_scene()
        kit = Kit(name, 0)
        fn(kit)
        tris = export(kit, path, 0.0)
        print("BUILT %-20s %6d tris  %s" % (name, tris, path))


main()

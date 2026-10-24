"""Builds the Halloway buildings, the garage and the cabin in Blender and writes them as .glb (lod 0, 1, 2).

Run (headless, from anywhere):
  blender.exe -b --factory-startup --python tools/blender/build_buildings.py -- [only=<name>,<name>] [lods=0,1,2] [out=<dir>]
Default out is godot/assets/models/story. The names, origin (ground, middle of the footprint), +Z front and the named
nodes (door, window_light, windows, blue_lamp, card_stand, roller_door, hullN-colonly) keep the contract of
game/README-models.md (Batch 8 and Batch 9), so StoryAssets and the story code load them unchanged.

Real references studied for proportion and detail (looked at, never copied): Wikimedia Commons photographs of brick
high-street shops (Victorian shopfronts with pilasters, consoles and fascias), a village police house, village halls in
painted weatherboard, a stone parish church with a broach spire, a Victorian board school with a bell turret, rural motor
garages with corrugated roofs, and weatherboard cabins on stone piers; dimensions from standard British practice (see
bldg_parts.py)."""
import sys, os, math, time, zlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
from bldg_lib import Kit, V, UP, reset_scene, export, text_obj, text_width, G
from bldg_parts import (Shell, Roof, sash_window, door, quoins, band, chimney, shopfront, streak, facades, _glass,
                        WHITE, CREAM, IRON, LEAD, CLAY, STONE, SLATE, GLASS, INTERIOR, BRASS, ccw)

GODOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

BRICK = (0.97, 0.94, 0.92)
BRICK_B = (0.92, 0.9, 0.9)
NAVY = (0.10, 0.15, 0.30)
GREEN = (0.11, 0.27, 0.19)
MAROON = (0.42, 0.13, 0.11)
BLUE = (0.10, 0.18, 0.36)
BLACK = (0.06, 0.06, 0.065)
GOLD = (0.86, 0.70, 0.36)


def hulls_house(kit, W, D, WH, RH):
    kit.hulls.append((V(0, WH / 2, 0), V(W, WH, D)))
    kit.hulls.append((V(0, WH + RH / 2, 0), V(W, RH, D)))


# ============================================================================ the police house
def police_house(kit, open_door=False):
    W, D, WH, RH = 7.0, 6.0, 5.7, 2.3
    sh = Shell(kit, W, D, WH, RH, "x", 0.3, "bld_brick", BRICK)
    for u in (-2.2, 2.2):
        sash_window(kit, sh, "front", u, 0.85, 1.0, 1.7, head="arch", panes=(2, 2))
    for u in (-2.2, 0.0, 2.2):
        sash_window(kit, sh, "front", u, 3.65, 0.95, 1.45, head="lintel", panes=(2, 2))
    door(kit, sh, "front", 0.0, 0.95, 2.1, leaf=NAVY, node="door", pivot=V(-0.5, 0.15, D / 2 - 0.12),
         open_deg=100.0 if open_door else 0.0, surround="pilaster", fanlight=0.32, number="1")
    for u in (-1.9, 1.9):
        sash_window(kit, sh, "back", u, 0.9, 0.95, 1.5, head="arch")
        sash_window(kit, sh, "back", u, 3.65, 0.9, 1.4, head="lintel")
    sash_window(kit, sh, "right", -1.0, 0.9, 0.9, 1.5, head="arch")
    sash_window(kit, sh, "right", -1.0, 3.65, 0.9, 1.4, head="lintel")
    sash_window(kit, sh, "left", 1.2, 3.65, 0.8, 1.3, head="lintel")
    sh.build(extra_heights=(2.95, 3.1))
    # plinth of dark engineering brick, a stone string course at the first floor, quoins
    band(kit, W, D, 0.0, 0.45, 0.025, "bld_brick", (0.42, 0.36, 0.38))
    band(kit, W, D, 2.98, 0.14, 0.03, "bld_stone", STONE)
    if kit.lod < 2:
        quoins(kit, W, D, WH)
    roof = Roof(kit, W, D, WH, RH, "x", mat="bld_slate", tint=SLATE)
    roof.build()
    for e in (-1, 1):
        chimney(kit, roof, e * (W / 2 - 0.5), 0.0, 0.95, 0.6, 1.0, pots=2, tint=BRICK)
        roof.downpipe(e * (W / 2 - 0.2), 1, D / 2)
        roof.downpipe(-e * (W / 2 - 0.2), -1, D / 2)
    F = sh.F["front"]
    ax = (F.r, UP, F.n)
    # the sign: HALLOWAY PROVINCIAL POLICE in white on a navy board between the floors
    kit.box(F.P(0, 3.33, -0.03), V(3.9, 0.36, 0.04), "bld_paint", NAVY, ax)
    kit.box(F.P(0, 3.33, -0.052), V(3.84, 0.30, 0.004), "bld_paint", tuple(c * 1.25 for c in NAVY), ax)
    if kit.lod < 2:
        ob = text_obj("HALLOWAY PROVINCIAL POLICE", "PTSansNarrow-Bold.ttf", 0.2, 0.006, "bld_paint", F.P(0, 3.26, -0.054), F.n, res=3 if kit.lod == 0 else 2)
        kit.take(ob, {"bld_paint": (0.95, 0.95, 0.93)})
    # the blue lamp on a wrought bracket right of the door, POLICE on its glass
    bp = F.P(1.05, 2.55, 0.0)
    lamp_c = bp + F.n * 0.48 + UP * 0.05
    kit.cyl(bp, bp + F.n * 0.5, 0.014, 0.014, 6, "bld_iron", IRON)
    kit.cyl(bp - UP * 0.25, bp + F.n * 0.35, 0.01, 0.01, 6, "bld_iron", IRON)
    kit.box(bp, V(0.08, 0.3, 0.02), "bld_iron", IRON, ax)
    bl = kit.node("blue_lamp", lamp_c)
    kit.box(lamp_c + UP * 0.2, V(0.3, 0.04, 0.3), "bld_iron", IRON, ax, node=bl)
    kit.box(lamp_c - UP * 0.2, V(0.27, 0.04, 0.27), "bld_iron", IRON, ax, node=bl)
    kit.box(lamp_c, V(0.24, 0.36, 0.24), "lamp_blue", (1, 1, 1), ax, node=bl)
    kit.cyl(lamp_c + UP * 0.22, lamp_c + UP * 0.32, 0.06, 0.02, 8, "bld_iron", IRON, node=bl)
    if kit.lod < 2:
        for nn, rr in ((F.n, F.r), (F.r, -F.n), (-F.r, F.n)):
            ob = text_obj("POLICE", "PTSansNarrow-Bold.ttf", 0.055, 0.003, "bld_paint", lamp_c + nn * 0.121 - UP * 0.02, nn, res=2)
            kit.take(ob, {"bld_paint": (0.96, 0.96, 0.96)}, node=bl)
    # a notice board left of the door
    kit.box(F.P(-1.25, 1.55, -0.04), V(0.75, 0.95, 0.06), "bld_paint", (0.25, 0.18, 0.12), ax)
    if kit.lod == 0:
        for i in range(6):
            kit.box(F.P(-1.48 + (i % 3) * 0.23, 1.32 + (i // 3) * 0.42, -0.075), V(0.17, 0.26, 0.004), "bld_paint", [(0.92, 0.92, 0.88), (0.92, 0.86, 0.55), (0.85, 0.9, 0.95)][i % 3], ax)
        kit.nodes["body"].poly([F.P(-1.6, 1.1, -0.08), F.P(-0.9, 1.1, -0.08), F.P(-0.9, 2.0, -0.08), F.P(-1.6, 2.0, -0.08)], "bld_glass", GLASS)
        for u in (-2.2, 2.2):
            streak(kit, F, u, 0.8, 0.9, 0.7, alpha=0.4)
    # floors inside: ground floor boards and the first floor seen from below
    kit.box(V(0, 0.16, 0), V(W - 0.6, 0.04, D - 0.6), "bld_floor", (0.8, 0.75, 0.7))
    kit.box(V(0, 3.0, 0), V(W - 0.6, 0.2, D - 0.6), "bld_plaster_int", (0.8, 0.78, 0.72))
    hulls_house(kit, W, D, WH, RH)
    return WH


# ============================================================================ the pub
def pub(kit):
    W, D, WH, RH = 11.0, 7.0, 6.0, 2.6
    sh = Shell(kit, W, D, WH, RH, "x", 0.35, "bld_render", CREAM)
    F = sh.F["front"]
    ax = (F.r, UP, F.n)
    for u in (-3.7, -1.6, 2.4, 4.2):
        sash_window(kit, sh, "front", u, 0.75, 1.25 if abs(u) > 3 else 1.1, 1.7, head="none", panes=(3, 2), frame=WHITE, sill_mat="bld_stone")
    for u in (-4.0, -1.4, 1.4, 4.0):
        sash_window(kit, sh, "front", u, 3.75, 1.0, 1.5, head="keystone", panes=(3, 2))
    door(kit, sh, "front", 0.4, 1.05, 2.2, leaf=GREEN, fanlight=0.35, surround=None, panels=4, glazed=True)
    for u in (-3.0, 0.0, 3.0):
        sash_window(kit, sh, "back", u, 0.9, 1.0, 1.5, head="none")
        sash_window(kit, sh, "back", u, 3.75, 1.0, 1.4, head="none")
    for side in ("left", "right"):
        sash_window(kit, sh, side, 1.2, 0.9, 1.0, 1.5, head="none")
        sash_window(kit, sh, side, 1.2, 3.75, 1.0, 1.4, head="none")
    sh.build(extra_heights=(2.95, 3.4))
    # black-painted plinth, the dark green fascia across the ground floor with THE PLOUGH in gold, painted quoins
    band(kit, W, D, 0.0, 0.5, 0.02, "bld_paint", BLACK)
    kit.box(F.P(0, 2.95 + 0.28, -0.05), V(W + 0.04, 0.56, 0.1), "bld_paint", GREEN, ax)
    kit.box(F.P(0, 3.55, -0.09), V(W + 0.12, 0.08, 0.18), "bld_paint", GREEN, ax)
    if kit.lod < 2:
        quoins(kit, W, D, WH, tint=(0.92, 0.92, 0.9), mat="bld_render")
        ob = text_obj("THE PLOUGH", "PlayfairDisplaySC-Bold.ttf", 0.36, 0.008, "bld_paint", F.P(-2.3, 3.09, -0.1), F.n, res=4 if kit.lod == 0 else 2)
        kit.take(ob, {"bld_paint": GOLD})
        ob = text_obj("FREE HOUSE", "PTSansNarrow-Bold.ttf", 0.2, 0.006, "bld_paint", F.P(3.2, 3.14, -0.1), F.n, res=2)
        kit.take(ob, {"bld_paint": GOLD})
    # a porch hood on brackets over the door
    kit.box(F.P(0.4, 2.95 - 0.12, -0.35), V(1.8, 0.08, 0.7), "bld_lead", LEAD, ax)
    if kit.lod < 2:
        for s in (-1, 1):
            kit.slab_poly([(0.0, 0.0), (0.0, 0.5), (-0.6, 0.5), (-0.1, 0.0)], F.P(0.4 + s * 0.75 + 0.03, 2.33, 0.0), -F.n, UP, 0.06, "bld_paint", WHITE)
    roof = Roof(kit, W, D, WH, RH, "x", mat="bld_slate", tint=(0.76, 0.78, 0.82))
    roof.build()
    for x in (-4.0, 4.3):
        chimney(kit, roof, x, 0.0, 1.0, 0.65, 1.0, pots=3 if x > 0 else 2, tint=BRICK, mat="bld_brick")
    for e in (-1, 1):
        roof.downpipe(e * (W / 2 - 0.25), 1, D / 2)
        roof.downpipe(e * (W / 2 - 0.25), -1, D / 2)
    # the hanging sign on a scrolled iron bracket at the left corner, lettered on both faces
    corner = F.P(-W / 2 + 0.35, 3.55, 0.0)
    kit.cyl(corner, corner + F.n * 1.15, 0.022, 0.022, 8, "bld_iron", IRON)
    kit.cyl(corner - UP * 0.45, corner + F.n * 0.8, 0.014, 0.014, 6, "bld_iron", IRON)
    kit.box(corner, V(0.12, 0.6, 0.03), "bld_iron", IRON, ax)
    sc = corner + F.n * 0.75 - UP * 0.62
    for s in (0.05, 1.0):
        kit.cyl(corner + F.n * (0.75 + (s - 0.5) * 0.7) , sc + F.n * ((s - 0.5) * 0.7) + UP * 0.42, 0.006, 0.006, 4, "bld_iron", IRON)
    sax = (F.n, UP, -F.r)
    kit.box(sc, V(0.82, 0.86, 0.05), "bld_paint", (0.18, 0.12, 0.08), sax)
    for side in (-1, 1):
        kit.box(sc + F.r * (side * 0.027), V(0.74, 0.78, 0.004), "bld_paint", (0.86, 0.80, 0.62), sax)
    if kit.lod < 2:
        for side in (-1, 1):
            nn = F.r * side
            ob = text_obj("THE", "PlayfairDisplaySC-Bold.ttf", 0.12, 0.004, "bld_paint", sc + nn * 0.029 + UP * 0.16, nn, res=2)
            kit.take(ob, {"bld_paint": MAROON})
            ob = text_obj("PLOUGH", "PlayfairDisplaySC-Bold.ttf", 0.16, 0.004, "bld_paint", sc + nn * 0.029 - UP * 0.05, nn, res=2)
            kit.take(ob, {"bld_paint": MAROON})
            # a little plough emblem: beam, handles and share
            kit.box(sc + nn * 0.03 - UP * 0.22, V(0.4, 0.03, 0.004) if False else V(0.004, 0.03, 0.4), "bld_paint", BLACK, (F.n, UP, -F.r)) if False else None
    # benches and a menu board by the door
    if kit.lod == 0:
        for u in (-3.7, 2.4):
            kit.box(F.P(u, 0.45, -0.35), V(1.4, 0.05, 0.38), "bld_wood", (0.6, 0.48, 0.34), ax)
            for s in (-1, 1):
                kit.box(F.P(u + s * 0.6, 0.22, -0.35), V(0.06, 0.44, 0.34), "bld_wood", (0.5, 0.4, 0.28), ax)
        kit.box(F.P(1.6, 0.55, -0.45), V(0.55, 0.9, 0.04), "bld_paint", BLACK, (F.r, (UP * 0.97 + F.n * 0.24).normalized(), (F.n * 0.97 - UP * 0.24).normalized()))
    kit.box(V(0, 0.16, 0), V(W - 0.7, 0.04, D - 0.7), "bld_floor", (0.7, 0.62, 0.55))
    kit.box(V(0, 3.0, 0), V(W - 0.7, 0.2, D - 0.7), "bld_plaster_int", (0.55, 0.45, 0.35))
    hulls_house(kit, W, D, WH, RH)
    return WH


# ============================================================================ the village hall
def village_hall(kit):
    W, D, WH, RH = 12.0, 8.0, 4.0, 3.6
    paint = (0.92, 0.89, 0.80)
    sh = Shell(kit, W, D, WH, RH, "z", 0.25, "bld_weatherboard", paint)
    F = sh.F["front"]
    ax = (F.r, UP, F.n)
    for u in (-3.6, 3.6):
        sash_window(kit, sh, "front", u, 1.1, 1.1, 2.1, head="none", panes=(2, 3), frame=GREEN, sill_mat="bld_paint", reveal=0.06)
    sash_window(kit, sh, "front", 0.0, WH + 0.6, 0.9, 1.3, head="none", panes=(1, 1), frame=GREEN, sill_mat="bld_paint", shape="round", style="fixed", reveal=0.06)
    for side in ("left", "right"):
        for u in (-2.6, 0.0, 2.6):
            sash_window(kit, sh, side, u, 1.1, 1.1, 2.1, head="none", panes=(2, 3), frame=GREEN, sill_mat="bld_paint", reveal=0.06)
    sash_window(kit, sh, "back", -2.5, 1.1, 1.1, 2.0, head="none", frame=GREEN, sill_mat="bld_paint", reveal=0.06)
    door(kit, sh, "right", -2.8 + 4.0 - 4.0, 0.9, 2.1, leaf=GREEN, fanlight=0.0, step=True, panels=4, reveal=0.06) if False else None
    door(kit, sh, "back", 2.6, 0.95, 2.1, leaf=GREEN, fanlight=0.0, panels=4, reveal=0.06)
    # the porch: double doors in the gable under a small gabled porch roof on posts
    door(kit, sh, "front", -0.45, 0.88, 2.25, leaf=GREEN, fanlight=0.0, step=False, panels=4, reveal=0.06)
    door(kit, sh, "front", 0.45, 0.88, 2.25, leaf=GREEN, fanlight=0.0, step=False, panels=4, reveal=0.06)
    sh.build(extra_heights=(WH + 0.4,))
    # corner boards, a skirting board, window architraves
    for cx in (-1, 1):
        for cz in (-1, 1):
            kit.box(V(cx * (W / 2 + 0.01), WH / 2, cz * (D / 2 + 0.01)), V(0.16, WH, 0.16), "bld_paint", WHITE)
    band(kit, W, D, 0.0, 0.3, 0.025, "bld_paint", GREEN)
    band(kit, W, D, WH - 0.2, 0.2, 0.02, "bld_paint", WHITE, sides=("left", "right"))
    roof = Roof(kit, W, D, WH, RH, "z", oe=0.35, ov=0.3, mat="bld_slate", tint=(0.78, 0.8, 0.84))
    roof.build(finial=True, barge=WHITE)
    for e in (-1, 1):
        roof.downpipe(e * (D / 2 - 0.25), 1, W / 2)
        roof.downpipe(e * (D / 2 - 0.25), -1, W / 2)
    chimney(kit, roof, 0.0, -D / 2 + 0.6, 0.7, 0.55, 0.8, pots=1, tint=BRICK)
    # porch: floor, posts, side rails, its own gable roof (ridge running out from the hall)
    pw, pd = 3.2, 1.8
    pz = D / 2 + pd / 2
    kit.box(V(0, 0.08, pz), V(pw, 0.16, pd), "bld_concrete", (0.6, 0.58, 0.55))
    for s in (-1, 1):
        kit.box(V(s * (pw / 2 - 0.1), 1.25, D / 2 + pd - 0.1), V(0.14, 2.5, 0.14), "bld_paint", WHITE)
        kit.box(V(s * (pw / 2 - 0.1), 0.85, pz), V(0.06, 0.06, pd - 0.2), "bld_paint", WHITE)
        if kit.lod == 0:
            for i in range(6):
                kit.box(V(s * (pw / 2 - 0.1), 0.45, D / 2 + 0.15 + i * 0.28), V(0.04, 0.75, 0.04), "bld_paint", WHITE)
    proof = Roof(kit, pw, pd + 0.1, 2.5, 1.0, "z", oe=0.2, ov=0.15, T=0.1, mat="bld_slate", tint=(0.78, 0.8, 0.84), offset=V(0, 0, D / 2 + pd / 2 + 0.05))
    proof.build(strips=2, gutters=False, barge=WHITE, finial=True)
    # the gable of the porch roof (boarding) and the VILLAGE HALL board on the main gable
    gz = D / 2 + pd + 0.05
    kit.nodes["body"].poly([V(-pw / 2, 2.5, gz), V(pw / 2, 2.5, gz), V(0, 3.5, gz)], "bld_weatherboard", paint)
    kit.nodes["body"].poly([V(0, 3.5, gz - 0.02), V(pw / 2, 2.5, gz - 0.02), V(-pw / 2, 2.5, gz - 0.02)], "bld_weatherboard", paint)
    kit.box(V(0, 2.5 - 0.1, gz - 0.05), V(pw, 0.2, 0.1), "bld_paint", WHITE)
    by = 3.75
    kit.box(F.P(0, by, -0.03), V(3.2, 0.42, 0.05), "bld_paint", GREEN, ax)
    if kit.lod < 2:
        ob = text_obj("VILLAGE HALL", "PlayfairDisplaySC-Bold.ttf", 0.25, 0.006, "bld_paint", F.P(0, by - 0.09, -0.056), F.n, res=3)
        kit.take(ob, {"bld_paint": CREAM})
        ob = text_obj("1897", "PlayfairDisplaySC-Bold.ttf", 0.16, 0.006, "bld_paint", F.P(0, WH + 0.25, -0.01), F.n, res=2)
        kit.take(ob, {"bld_paint": GREEN})
    # the notice board on the front wall
    kit.box(F.P(5.0, 1.6, -0.05), V(0.9, 1.1, 0.07), "bld_paint", GREEN, ax)
    if kit.lod == 0:
        for i in range(6):
            kit.box(F.P(4.7 + (i % 3) * 0.3, 1.32 + (i // 3) * 0.5, -0.09), V(0.23, 0.32, 0.004), "bld_paint", [(0.92, 0.92, 0.88), (0.9, 0.7, 0.5), (0.8, 0.9, 0.85)][i % 3], ax)
    kit.box(V(0, 0.12, 0), V(W - 0.5, 0.04, D - 0.5), "bld_floor", (0.8, 0.72, 0.62))
    kit.hulls.append((V(0, WH / 2, 0), V(W, WH, D)))
    kit.hulls.append((V(0, WH + RH / 2, 0), V(W, RH, D)))
    return WH


# ============================================================================ shops
def _goods_stores(k, F, span, back):
    ax = (F.r, UP, F.n)
    o0, o1 = span
    for j in range(3):
        y = 0.75 + j * 0.55
        k.box(F.P((o0 + o1) / 2, y, back - 0.2), V(o1 - o0 - 0.3, 0.03, 0.35), "bld_wood", (0.55, 0.45, 0.32), ax)
        x = o0 + 0.25
        while x < o1 - 0.3:
            col = k.rng.choice([(0.8, 0.2, 0.15), (0.2, 0.4, 0.7), (0.9, 0.8, 0.3), (0.3, 0.6, 0.3), (0.9, 0.9, 0.85), (0.6, 0.3, 0.5)])
            h = 0.14 + 0.16 * k.rng.random()
            wdt = 0.08 + 0.1 * k.rng.random()
            k.box(F.P(x + wdt / 2, y + 0.015 + h / 2, back - 0.22), V(wdt, h, 0.12), "bld_goods", col, ax)
            x += wdt + 0.02


def _goods_bakery(k, F, span, back):
    ax = (F.r, UP, F.n)
    o0, o1 = span
    for j in range(2):
        y = 0.7 + j * 0.45
        k.box(F.P((o0 + o1) / 2, y, 0.45 + j * 0.25), V(o1 - o0 - 0.3, 0.03, 0.3), "bld_wood", (0.55, 0.45, 0.32), ax)
        x = o0 + 0.3
        while x < o1 - 0.3:
            c = F.P(x, y + 0.06, 0.45 + j * 0.25)
            k.lathe(c, [(0.0, 0.0), (0.09, 0.0), (0.1, 0.04), (0.07, 0.09), (0.0, 0.1)], 8, "bld_goods", k.jit((0.78, 0.52, 0.26), 0.1))
            x += 0.24


def _goods_chips(k, F, span, back):
    ax = (F.r, UP, F.n)
    o0, o1 = span
    k.box(F.P((o0 + o1) / 2, 0.55, 0.9), V(o1 - o0 - 0.4, 1.1, 0.6), "bld_iron", (0.75, 0.76, 0.78), ax)     # the steel range
    k.box(F.P((o0 + o1) / 2, 1.12, 0.9), V(o1 - o0 - 0.3, 0.04, 0.7), "bld_iron", (0.85, 0.85, 0.86), ax)
    k.box(F.P((o0 + o1) / 2, 2.2, back - 0.05), V(1.4, 0.7, 0.03), "bld_paint", BLACK, ax)                  # the menu board


def shop(kit, variant):
    if variant in ("a", "b"):
        W, D, WH, RH = 6.5, 9.0, 6.2, 2.9
    else:
        W, D, WH, RH = 5.5, 8.0, 5.9, 2.6
    spec = {
        "a": dict(mat="bld_brick", tint=BRICK, title="HALLOWAY STORES", sub="GROCER & POST OFFICE", trim=GREEN, aw=((0.12, 0.30, 0.20), (0.92, 0.88, 0.76)), goods=_goods_stores),
        "b": dict(mat="bld_brick2", tint=BRICK_B, title="MOTOR PARTS", sub="TYRES  BATTERIES  SPARES", trim=BLUE, aw=((0.12, 0.2, 0.42), (0.92, 0.92, 0.9)), goods=_goods_stores),
        "bakery": dict(mat="bld_brick2", tint=(0.9, 0.86, 0.84), title="BAKERY", sub="FRESH BREAD DAILY", trim=MAROON, aw=((0.45, 0.14, 0.12), (0.92, 0.86, 0.72)), goods=_goods_bakery),
        "chips": dict(mat="bld_render", tint=(0.93, 0.92, 0.88), title="FISH & CHIPS", sub="OPEN 11 TILL LATE", trim=NAVY, aw=((0.12, 0.18, 0.38), (0.9, 0.9, 0.88)), goods=_goods_chips),
    }[variant]
    sh = Shell(kit, W, D, WH, RH, "x", 0.3, spec["mat"], spec["tint"])
    F = sh.F["front"]
    ax = (F.r, UP, F.n)
    # first floor: two sash windows over the shop; second-floor attic light in the gable at the back
    for u in ((-1.5, 1.5) if W > 6 else (-1.25, 1.25)):
        sash_window(kit, sh, "front", u, 4.25, 1.0, 1.55, head="arch" if spec["mat"] != "bld_render" else "keystone", panes=(2, 2))
    shopfront(kit, sh, -W / 2 + 0.05, W / 2 - 0.05, spec["title"], spec["trim"], letter=GOLD if variant != "chips" else (0.95, 0.95, 0.92),
              awning=spec["aw"], door_u=-W / 2 + 0.95, fascia_y=3.05, goods=spec["goods"], subtitle=spec["sub"])
    for u in (-1.4, 1.4):
        sash_window(kit, sh, "back", u, 1.0, 0.95, 1.4, head="arch")
        sash_window(kit, sh, "back", u, 4.25, 0.95, 1.4, head="arch")
    door(kit, sh, "back", 0.0 if W < 6 else 0.0, 0.85, 2.0, leaf=spec["trim"], fanlight=0.0, panels=4) if False else None
    for side in ("left", "right"):
        sash_window(kit, sh, side, -1.5, 4.25, 0.9, 1.4, head="arch")
    sh.build(extra_heights=(3.85, 4.0))
    band(kit, W, D, 0.0, 0.4, 0.02, spec["mat"], tuple(c * 0.8 for c in spec["tint"]), sides=("back", "left", "right"))
    band(kit, W, D, 3.95, 0.12, 0.03, "bld_stone", STONE)
    if kit.lod < 2 and spec["mat"] != "bld_render":
        quoins(kit, W, D, WH)
    roof = Roof(kit, W, D, WH, RH, "x", mat="bld_slate", tint=SLATE)
    roof.build()
    chimney(kit, roof, W / 2 - 0.55, -0.4, 0.9, 0.6, 1.0, pots=2, tint=spec["tint"], mat=spec["mat"] if spec["mat"] != "bld_render" else "bld_brick")
    roof.downpipe(W / 2 - 0.2, 1, D / 2)
    roof.downpipe(-W / 2 + 0.2, -1, D / 2)
    if variant == "a":
        # the postcard stand: a revolving wire rack of cards beside the window, a node of its own
        p = F.P(2.25, 0.0, -0.6)
        cs = kit.node("card_stand", p)
        kit.cyl(p, p + UP * 1.55, 0.015, 0.015, 6, "bld_iron", IRON, node=cs)
        kit.cyl(p, p + UP * 0.02, 0.18, 0.18, 10, "bld_iron", IRON, node=cs)
        for kk in range(6):
            a = math.tau * kk / 6
            dirv = F.r * math.cos(a) + F.n * math.sin(a)
            for j in range(4):
                c = p + dirv * 0.13 + UP * (0.7 + j * 0.22)
                col = [(0.5, 0.7, 0.85), (0.9, 0.8, 0.4), (0.8, 0.45, 0.4), (0.6, 0.8, 0.55)][(kk + j) % 4]
                kit.box(c, V(0.1, 0.15, 0.004), "bld_goods", col, (dirv.cross(UP).normalized() * -1, UP, dirv), node=cs)
    elif variant == "b":
        if kit.lod < 2:
            for kk in range(3):
                c = F.P(2.2, 0.11 + kk * 0.21, -0.75)
                kit.cyl(c - UP * 0.1, c + UP * 0.1, 0.31, 0.31, 16, "bld_goods", (0.07, 0.07, 0.07), caps=3)
            kit.box(F.P(-2.0, 0.45, -0.9), V(0.55, 0.85, 0.04), "bld_paint", BLUE, (F.r, (UP * 0.98 + F.n * 0.2).normalized(), (F.n * 0.98 - UP * 0.2).normalized()))
    kit.box(V(0, 0.16, 0), V(W - 0.6, 0.04, D - 0.6), "bld_floor", (0.7, 0.62, 0.55))
    kit.box(V(0, 3.85, 0), V(W - 0.6, 0.2, D - 0.6), "bld_plaster_int", (0.8, 0.78, 0.72))
    hulls_house(kit, W, D, WH, RH)
    return WH


# ============================================================================ the church
def church(kit):
    W, D, WH, RH = 7.5, 15.0, 5.6, 4.4
    stone = (0.92, 0.9, 0.86)
    sh = Shell(kit, W, D, WH, RH, "z", 0.6, "bld_ashlar", stone)
    for side in ("left", "right"):
        for u in (-5.1, -1.7, 1.7, 5.1):
            sash_window(kit, sh, side, u, 1.7, 0.85, 3.0, shape="pointed", style="fixed", head="none", sill=True, frame=STONE, reveal=0.25, curtains=False)
    for u in (-0.8, 0.0, 0.8):
        sash_window(kit, sh, "back", u, 2.0 if u else 1.8, 0.6, 3.6 if u == 0 else 3.0, shape="pointed", style="fixed", head="none", frame=STONE, reveal=0.25, curtains=False)
    sh.build(extra_heights=(1.2, 1.7))
    band(kit, W, D, 0.0, 0.55, 0.06, "bld_ashlar", (0.8, 0.78, 0.74), sides=("back", "left", "right"))
    # buttresses between the bays, stepped twice, with weathered stone tops
    for side, sx in (("left", -1), ("right", 1)):
        for zz in (-6.8, -3.4, 0.0, 3.4, 6.8):
            for (h0, h1, dep) in ((0.0, 2.6, 0.7), (2.6, 4.4, 0.45)):
                kit.box(V(sx * (W / 2 + dep / 2), (h0 + h1) / 2, zz), V(dep, h1 - h0, 0.6), "bld_ashlar", stone)
                kit.box(V(sx * (W / 2 + dep / 2), h1 + 0.06, zz), V(dep + 0.06, 0.12, 0.66), "bld_stone", STONE)
    roof = Roof(kit, W, D, WH, RH, "z", oe=0.35, ov=0.0, T=0.14, mat="bld_slate2", tint=(0.82, 0.84, 0.88))
    roof.build(barge=STONE, verge_mat="bld_stone", strips=5)
    for e in (-1, 1):
        for s in (-1, 1):
            roof.downpipe(e * (D / 2 - 0.4), s, W / 2)
    # gable copings (stone) and a cross on the east gable
    for e in (-1,):
        tip = V(0, WH + RH + 0.15, e * (D / 2))
        kit.box(tip + V(0, 0.4, 0), V(0.1, 0.8, 0.1), "bld_stone", STONE)
        kit.box(tip + V(0, 0.55, 0), V(0.5, 0.1, 0.1), "bld_stone", STONE)
    # the tower at the west (street) end: 3.8 m square, 12 m to the parapet, belfry openings, broach spire
    tw, th = 3.8, 12.0
    tz = D / 2 + tw / 2 - 0.3
    tsh = Shell(kit, tw, tw, th, 0.0, "x", 0.6, "bld_ashlar", stone, offset=V(0, 0, tz))
    door(kit, tsh, "front", 0.0, 1.4, 2.6, leaf=(0.28, 0.18, 0.1), fanlight=0.0, step=True, panels=2, reveal=0.45) if False else None
    tsh.hole("front", 0.0, 0.15, 1.5, 3.0, "pointed")
    for side in ("front", "left", "right", "back"):
        sash_window(kit, tsh, side, 0.0, 8.6, 0.9, 1.9, shape="pointed", style="fixed", head="none", frame=STONE, reveal=0.3, curtains=False, lit=False, bars=False)
    sash_window(kit, tsh, "front", 0.0, 4.8, 0.5, 1.4, shape="pointed", style="fixed", head="none", frame=STONE, reveal=0.3, curtains=False)
    tsh.build(extra_heights=(3.4, 7.4))
    F = tsh.F["front"]
    ax = (F.r, UP, F.n)
    # the west door: two oak leaves with iron straps in the pointed arch
    for s in (-1, 1):
        kit.box(F.P(s * 0.37, 0.15 + 1.25, 0.4), V(0.72, 2.5, 0.08), "bld_wood", (0.42, 0.3, 0.2), ax)
        if kit.lod == 0:
            for y in (0.5, 1.4, 2.3):
                kit.box(F.P(s * 0.37, 0.15 + y, 0.355), V(0.6, 0.05, 0.01), "bld_iron", IRON, ax)
    kit.box(F.P(0, 0.07, -0.3), V(2.2, 0.15, 0.7), "bld_stone", STONE, ax)
    # louvres in the belfry openings
    if kit.lod < 2:
        for side in ("front", "left", "right", "back"):
            Fs = tsh.F[side]
            for j in range(7):
                kit.box(Fs.P(0.0, 8.8 + j * 0.2, 0.32), V(0.86, 0.04, 0.16), "bld_wood", (0.35, 0.3, 0.25), (Fs.r, (UP + Fs.n * 0.6).normalized(), (Fs.n - UP * 0.6).normalized()))
    # string courses, the parapet and corner pinnacles
    for y in (3.5, 7.6):
        kit.box(V(0, y, tz), V(tw + 0.1, 0.15, tw + 0.1), "bld_stone", STONE)
    kit.box(V(0, th + 0.3, tz), V(tw + 0.15, 0.6, tw + 0.15), "bld_ashlar", stone, skip=("+y",)) if False else None
    for cx in (-1, 1):
        for cz in (-1, 1):
            p = V(cx * (tw / 2 - 0.15), th, tz + cz * (tw / 2 - 0.15))
            kit.box(p + V(0, 0.4, 0), V(0.32, 0.8, 0.32), "bld_ashlar", stone)
            kit.cyl(p + V(0, 0.8, 0), p + V(0, 1.5, 0), 0.16, 0.02, 4, "bld_stone", STONE, smooth=False)
    # broach spire: an octagonal slate spire standing on the tower walls (its cardinal faces start on the square's edges),
    # half-pyramid broaches over the four corners, a weathercock on top
    base_y = th
    sh_ = 8.0
    apex = V(0, base_y + sh_, tz)
    hs = tw / 2 - 0.15                         # half the square the spire stands on (inside the wall's outer face)
    ro = hs / math.cos(math.pi / 8)            # octagon vertex radius with apothem hs
    oct_pts = [V(ro * math.cos(math.pi / 8 + math.tau * i / 8), base_y, tz + ro * math.sin(math.pi / 8 + math.tau * i / 8)) for i in range(8)]
    acc = kit.nodes["body"]
    cen = V(0, base_y, tz)
    for i in range(8):
        a, b = oct_pts[i], oct_pts[(i + 1) % 8]
        tri = [a, b, apex]
        if (b - a).cross(apex - a).dot((a + b) / 2 - cen) < 0:
            tri = [b, a, apex]
        acc.poly(tri, "bld_slate2", kit.jit((0.8, 0.82, 0.86), 0.03))
    for cx in (-1, 1):
        for cz in (-1, 1):
            c = V(cx * hs, base_y, tz + cz * hs)
            d2 = sorted(range(8), key=lambda i: (oct_pts[i] - c).length)[:2]
            p1, p2 = oct_pts[d2[0]], oct_pts[d2[1]]
            q = ((p1 + p2) / 2).lerp(apex, 0.16)
            for (u1, u2) in ((p1, q), (q, p2)):
                tri = [c, u1, u2]
                if (u1 - c).cross(u2 - c).y < 0:
                    tri = [c, u2, u1]
                acc.poly(tri, "bld_slate2", (0.78, 0.8, 0.84))
    kit.cyl(apex - V(0, 0.2, 0), apex + V(0, 1.4, 0), 0.03, 0.015, 6, "bld_iron", IRON)
    if kit.lod < 2:
        kit.box(apex + V(0, 1.0, 0), V(0.7, 0.02, 0.02), "bld_iron", IRON)
        kit.box(apex + V(0, 1.0, 0), V(0.02, 0.02, 0.7), "bld_iron", IRON)
        kit.slab_poly([(-0.3, 0.0), (0.25, 0.0), (0.3, 0.1), (0.05, 0.12), (0.0, 0.3), (-0.12, 0.2), (-0.3, 0.12)], apex + V(0, 1.25, 0), V(1, 0, 0), V(0, 1, 0), 0.01, "bld_brass", BRASS)
    kit.box(V(0, 0.2, 0), V(W - 1.2, 0.04, D - 1.2), "bld_floor", (0.6, 0.55, 0.5))
    kit.hulls.append((V(0, WH / 2, 0), V(W, WH, D)))
    kit.hulls.append((V(0, th / 2, tz), V(tw, th, tw)))
    return WH


# ============================================================================ the school
def school(kit):
    W, D, WH, RH = 16.0, 8.0, 4.4, 3.0
    sh = Shell(kit, W, D, WH, RH, "x", 0.35, "bld_brick", (0.95, 0.9, 0.86))
    for u in (-6.0, -3.6, 3.6, 6.0):
        sash_window(kit, sh, "front", u, 1.0, 1.4, 2.6, head="arch", panes=(3, 3), frame=CREAM)
    for u in (-6.0, -3.0, 0.0, 3.0, 6.0):
        sash_window(kit, sh, "back", u, 1.0, 1.4, 2.6, head="arch", panes=(3, 3), frame=CREAM)
    for side in ("left", "right"):
        sash_window(kit, sh, side, 0.0, 1.0, 1.4, 2.6, head="arch", panes=(3, 3), frame=CREAM)
        sash_window(kit, sh, side, 0.0, WH + 0.6, 0.8, 1.2, shape="round", style="fixed", head="none", frame=CREAM, curtains=False)
    sh.build(extra_heights=(3.8,))
    band(kit, W, D, 0.0, 0.5, 0.025, "bld_brick", (0.45, 0.38, 0.38))
    band(kit, W, D, 3.85, 0.15, 0.03, "bld_stone", STONE, sides=("front", "back"))
    if kit.lod < 2:
        quoins(kit, W, D, WH)
    roof = Roof(kit, W, D, WH, RH, "x", mat="bld_slate", tint=SLATE)
    roof.build()
    for x in (-5.0, 5.0):
        chimney(kit, roof, x, -1.2, 0.9, 0.6, 1.0, pots=2, tint=(0.95, 0.9, 0.86))
    for e in (-1, 1):
        roof.downpipe(e * (W / 2 - 0.25), 1, D / 2)
        roof.downpipe(e * (W / 2 - 0.25), -1, D / 2)
    # the entrance porch: a gabled brick wing on the front with the name on a stone panel
    pw, pd, pwh, prh = 3.6, 2.4, 3.6, 2.0
    pz = D / 2 + pd / 2
    psh = Shell(kit, pw, pd + 0.6, pwh, prh, "z", 0.3, "bld_brick", (0.95, 0.9, 0.86), offset=V(0, 0, pz - 0.3))
    door(kit, psh, "front", -0.45, 0.85, 2.3, leaf=GREEN, fanlight=0.0, step=True, panels=4, reveal=0.15)
    door(kit, psh, "front", 0.45, 0.85, 2.3, leaf=GREEN, fanlight=0.0, step=False, panels=4, reveal=0.15)
    psh.build()
    Fp = psh.F["front"]
    axp = (Fp.r, UP, Fp.n)
    proof = Roof(kit, pw, pd + 0.6, pwh, prh, "z", oe=0.25, ov=0.2, mat="bld_slate", tint=SLATE, offset=V(0, 0, pz - 0.3))
    proof.build(strips=2, finial=True)
    kit.box(Fp.P(0, 2.95, -0.02), V(2.9, 0.42, 0.04), "bld_stone", STONE, axp)
    if kit.lod < 2:
        ob = text_obj("HALLOWAY SCHOOL", "PlayfairDisplaySC-Bold.ttf", 0.22, 0.006, "bld_stone", Fp.P(0, 2.86, -0.04), Fp.n, res=3)
        kit.take(ob, {"bld_stone": (0.35, 0.32, 0.28)})
        ob = text_obj("1874", "PlayfairDisplaySC-Bold.ttf", 0.14, 0.005, "bld_stone", Fp.P(0, pwh + 0.5, -0.004), Fp.n, res=2)
        kit.take(ob, {"bld_stone": (0.35, 0.32, 0.28)})
        kit.box(Fp.P(0, pwh + 0.57, -0.002), V(0.6, 0.3, 0.004), "bld_stone", STONE, axp)
    # the bell turret on the ridge: louvred box, lead pyramid, weathervane
    yb = WH + RH + 0.1
    kit.box(V(0, yb + 0.3, 0), V(1.2, 0.6, 1.2), "bld_paint", CREAM)
    for s in (-1, 1):
        for t in (-1, 1):
            kit.box(V(s * 0.5, yb + 1.0, t * 0.5), V(0.12, 0.8, 0.12), "bld_paint", CREAM)
    if kit.lod < 2:
        for j in range(4):
            for sx, sz in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                c = V(sx * 0.55, yb + 0.7 + j * 0.18, sz * 0.55)
                kit.box(c, V(0.9 if sz else 0.1, 0.04, 0.1 if sz else 0.9), "bld_paint", CREAM)
    kit.lathe(V(0, yb + 1.0, 0), [(0.0, 0.25), (0.15, 0.3), (0.04, 0.35), (0.0, 0.35)], 8, "bld_brass", BRASS) if kit.lod == 0 else None
    pyr = [V(-0.75, yb + 1.4, -0.75), V(0.75, yb + 1.4, -0.75), V(0.75, yb + 1.4, 0.75), V(-0.75, yb + 1.4, 0.75)]
    tip = V(0, yb + 2.4, 0)
    for i in range(4):
        a, b = pyr[i], pyr[(i + 1) % 4]
        kit.nodes["body"].poly([b, a, tip], "bld_lead", LEAD)
    kit.box(V(0, yb + 1.4 - 0.03, 0), V(1.5, 0.06, 1.5), "bld_paint", CREAM)
    kit.cyl(tip, tip + V(0, 0.8, 0), 0.02, 0.01, 6, "bld_iron", IRON)
    if kit.lod < 2:
        kit.slab_poly([(-0.35, 0.0), (0.25, 0.0), (0.35, 0.06), (0.25, 0.12), (-0.25, 0.12), (-0.35, 0.2)], tip + V(0, 0.55, 0), V(1, 0, 0), V(0, 1, 0), 0.01, "bld_iron", IRON)
    kit.box(V(0, 0.16, 0), V(W - 0.7, 0.04, D - 0.7), "bld_floor", (0.7, 0.62, 0.55))
    kit.hulls.append((V(0, WH / 2, 0), V(W, WH, D)))
    kit.hulls.append((V(0, WH + RH / 2, 0), V(W, RH, D)))
    return WH


# ============================================================================ the garage (VOSS & SON MOTOR WORKS)
def garage(kit):
    W, D, WH, RH = 12.0, 9.0, 4.2, 1.5
    brick = (0.9, 0.82, 0.78)
    sh = Shell(kit, W, D, WH, RH, "x", 0.3, "bld_brick2", brick)
    F = sh.F["front"]
    ax = (F.r, UP, F.n)
    # the workshop door: 4.2 m wide, 3.4 m high, a steel lintel; the office door and window to its right
    sh.hole("front", -2.0, 0.0, 4.2, 3.4)
    kit.box(F.P(-2.0, 3.48, -0.01), V(4.6, 0.16, 0.06), "bld_iron", (0.18, 0.2, 0.22), ax, skip=("-z",))
    door(kit, sh, "front", 2.6, 0.9, 2.1, leaf=GREEN, fanlight=0.0, step=True, panels=2, glazed=True, reveal=0.1)
    sash_window(kit, sh, "front", 4.4, 1.0, 1.4, 1.3, style="fixed", panes=(3, 2), head="lintel", frame=CREAM, curtains=False)
    for side in ("left", "right"):
        for u in (-2.2, 2.2):
            sash_window(kit, sh, side, u, 1.4, 1.8, 1.3, style="fixed", panes=(4, 3), head="lintel", frame=(0.25, 0.3, 0.3), curtains=False, lit=False)
    for u in (-3.5, 0.0, 3.5):
        sash_window(kit, sh, "back", u, 1.4, 1.8, 1.3, style="fixed", panes=(4, 3), head="lintel", frame=(0.25, 0.3, 0.3), curtains=False, lit=False)
    sh.build(extra_heights=(3.4, 3.6))
    band(kit, W, D, 0.0, 0.4, 0.02, "bld_brick2", (0.6, 0.5, 0.48))
    if kit.lod < 2:
        quoins(kit, W, D, WH, tint=(0.75, 0.6, 0.5), mat="bld_brick2")
    roof = Roof(kit, W, D, WH, RH, "x", oe=0.25, ov=0.25, T=0.1, mat="bld_corrugated", tint=(0.86, 0.87, 0.88))
    roof.build(strips=3, ridge_tiles=False)
    # ridge capping: a bent galvanised sheet
    yr = roof.top_y(0.0)
    L = W / 2 + 0.25
    for s in (-1, 1):
        a0, a1 = 0.0, s * 0.3
        bot = [roof.g(-L, yr - 0.01, a0), roof.g(L, yr - 0.01, a0), roof.g(L, roof.top_y(a1) - 0.01, a1), roof.g(-L, roof.top_y(a1) - 0.01, a1)]
        top = [p + V(0, 0.012, 0) for p in bot]
        kit.hexa(ccw(bot), ccw(top), "bld_iron", (0.62, 0.63, 0.64))
    for e in (-1, 1):
        roof.downpipe(e * (W / 2 - 0.25), 1, D / 2)
        roof.downpipe(e * (W / 2 - 0.25), -1, D / 2)
    # timber trusses inside, seen through the doors
    if kit.lod < 2:
        for x in (-3.0, 0.0, 3.0):
            for s in (-1, 1):
                a = V(x, WH - 0.05, s * (D / 2 - 0.3))
                b = V(x, WH + RH - 0.15, 0)
                kit.cyl(a, b, 0.06, 0.06, 4, "bld_wood", (0.5, 0.4, 0.3), smooth=False)
            kit.cyl(V(x, WH - 0.05, -D / 2 + 0.3), V(x, WH - 0.05, D / 2 - 0.3), 0.06, 0.06, 4, "bld_wood", (0.5, 0.4, 0.3), smooth=False)
            kit.cyl(V(x, WH - 0.05, 0), V(x, WH + RH - 0.15, 0), 0.04, 0.04, 4, "bld_wood", (0.5, 0.4, 0.3), smooth=False)
    # the board: VOSS & SON over MOTOR WORKS, cream on green, across the front above the doors
    kit.box(F.P(-0.6, 3.92, -0.06), V(8.6, 0.78, 0.08), "bld_paint", GREEN, ax)
    kit.box(F.P(-0.6, 3.92, -0.105), V(8.45, 0.66, 0.01), "bld_paint", tuple(c * 1.2 for c in GREEN), ax)
    if kit.lod < 2:
        ob = text_obj("VOSS & SON", "AlfaSlabOne-Regular.ttf", 0.38, 0.01, "bld_paint", F.P(-0.6, 3.92 - 0.02, -0.11), F.n, res=3 if kit.lod == 0 else 2)
        kit.take(ob, {"bld_paint": (0.93, 0.88, 0.72)})
        ob = text_obj("MOTOR WORKS", "PTSansNarrow-Bold.ttf", 0.15, 0.006, "bld_paint", F.P(-0.6, 3.6, -0.11), F.n, res=2, spacing=1.3)
        kit.take(ob, {"bld_paint": (0.93, 0.88, 0.72)})
        # an enamel sign by the office door
        kit.box(F.P(3.35, 2.2, -0.012), V(0.5, 0.35, 0.01), "bld_paint", (0.85, 0.1, 0.08), ax)
        ob = text_obj("OIL", "PTSansNarrow-Bold.ttf", 0.16, 0.003, "bld_paint", F.P(3.35, 2.13, -0.018), F.n, res=2)
        kit.take(ob, {"bld_paint": (0.96, 0.95, 0.9)})
    # the roller door: corrugated slats rolled half down, its barrel box and guides (node roller_door)
    rd = kit.node("roller_door", F.P(-2.0, 3.4, 0.22))
    kit.box(F.P(-2.0, 3.25, 0.25), V(4.3, 0.36, 0.36), "bld_iron", (0.32, 0.34, 0.33), ax, node=rd)
    nsl = 22 if kit.lod == 0 else 6
    hgt = 1.6
    for i in range(nsl):
        y = 3.07 - (i + 0.5) * hgt / nsl
        kit.box(F.P(-2.0, y, 0.26), V(4.1, hgt / nsl - 0.004, 0.03), "bld_corrugated", kit.jit((0.62, 0.6, 0.56), 0.05), ax, node=rd)
    kit.box(F.P(-2.0, 3.07 - hgt - 0.03, 0.26), V(4.1, 0.06, 0.05), "bld_iron", (0.3, 0.3, 0.3), ax, node=rd)
    for s in (-1, 1):
        kit.box(F.P(-2.0 + s * 2.08, 1.7, 0.26), V(0.06, 3.4, 0.08), "bld_iron", (0.3, 0.32, 0.31), ax)
    # concrete floor with the inspection pit, a dado of green paint on the inside walls
    kit.box(V(0, 0.03, 0), V(W - 0.6, 0.06, D - 0.6), "bld_concrete", (0.75, 0.73, 0.7))
    kit.box(V(-2.0, 0.065, 0.3), V(1.0, 0.01, 4.4), "bld_iron", (0.02, 0.02, 0.02))
    if kit.lod < 2:
        for x in (-2.55, -1.45):
            kit.box(V(x, 0.07, 0.3), V(0.1, 0.02, 4.5), "bld_iron", (0.35, 0.35, 0.33))
        for s in (-1, 1):
            kit.box(V(0, 0.75, s * (D / 2 - 0.305)), V(W - 0.62, 1.4, 0.01), "bld_paint", (0.42, 0.44, 0.38))
            kit.box(V(s * (W / 2 - 0.305), 0.75, 0), V(0.01, 1.4, D - 0.62), "bld_paint", (0.42, 0.44, 0.38))
    kit.hulls.append((V(0, WH / 2, 0), V(W, WH, D)))
    kit.hulls.append((V(0, WH + RH / 2, 0), V(W, RH, D)))
    return WH


# ============================================================================ the cabin
FLOOR_Y, EAVE_Y, RIDGE_Y = 0.35, 2.9, 4.2


def cabin(kit, broken=False):
    hx, hz = 4.0, 3.0
    W, D = 2 * hx, 2 * hz
    wood = (0.95, 0.93, 0.9)
    bare = (0.62, 0.58, 0.52)
    sh = Shell(kit, W, D, EAVE_Y, RIDGE_Y - EAVE_Y, "x", 0.08, "bld_timber", wood, y_base=FLOOR_Y - 0.12)
    fy = FLOOR_Y
    # windows: two on the front, one at the back, one on the left gable (the contract's positions)
    wn = dict(head="none", panes=(2, 2), frame=(0.56, 0.54, 0.48), sill_mat="bld_wood", reveal=0.02, glass_node="windows", curtains=False)
    kit.node("windows", V(0, fy + 1.5, hz))
    kit.node("window_light", V(0, fy + 1.5, hz))
    sash_window(kit, sh, "front", -2.0, fy + 0.9, 1.2, 1.2, **wn)
    sash_window(kit, sh, "front", 3.4, fy + 0.9, 1.2, 1.2, **wn)
    sash_window(kit, sh, "back", 0.0, fy + 0.9, 1.2, 1.2, **wn)
    sash_window(kit, sh, "left", 0.0, fy + 0.9, 1.0, 1.2, **wn)
    sh.hole("front", 1.025, fy, 1.05, 2.1)
    sh.build(extra_heights=(fy + 0.4, fy + 2.15))
    F = sh.F["front"]
    ax = (F.r, UP, F.n)
    # stone piers, sole plate, corner boards and door casing
    for sx in (-3.6, -1.2, 1.2, 3.6):
        for sz in (-2.6, 0.0, 2.6):
            kit.box(V(sx, (fy - 0.12) / 2, sz), V(0.42, fy - 0.12, 0.42), "bld_stone", kit.jit((0.62, 0.6, 0.56), 0.1))
    kit.box(V(0, fy - 0.17, 0), V(W + 0.04, 0.1, D + 0.04), "bld_wood", bare)
    for cx in (-1, 1):
        for cz in (-1, 1):
            kit.box(V(cx * (hx + 0.03), (fy + EAVE_Y) / 2, cz * (hz + 0.03)), V(0.12, EAVE_Y - fy + 0.1, 0.12), "bld_wood", bare)
    for s in (-1, 1):
        kit.box(F.P(1.025 + s * 0.58, fy + 1.07, -0.02), V(0.1, 2.15, 0.05), "bld_wood", bare, ax)
    kit.box(F.P(1.025, fy + 2.17, -0.02), V(1.26, 0.1, 0.05), "bld_wood", bare, ax)
    # floorboards inside at y 0.35 (the interior set stands on them)
    kit.box(V(0, fy - 0.02, 0), V(W - 0.16, 0.04, D - 0.16), "bld_wood", (0.7, 0.64, 0.55))
    # the door: planked, Z-braced, strap hinges; hinge at the left jamb (node door)
    hinge = V(-hx + 5.0 - 0.45, fy, hz + 0.01)
    dn = kit.node("door", hinge)
    for k in range(5):
        x = hinge.x + 0.095 + k * 0.19
        kit.box(V(x, fy + 1.025, hz + 0.01), V(0.185, 2.05, 0.04), "bld_wood", kit.jit(bare, 0.12), node=dn)
    for y in (0.35, 1.7):
        kit.box(V(hinge.x + 0.475, fy + y, hz + 0.045), V(0.9, 0.12, 0.03), "bld_wood", bare, node=dn)
    d0 = V(hinge.x + 0.08, fy + 0.4, hz + 0.045); d1 = V(hinge.x + 0.88, fy + 1.66, hz + 0.045)
    kit.box((d0 + d1) / 2, V(0.1, (d1 - d0).length, 0.03), "bld_wood", bare, (( (d1 - d0).normalized().cross(V(0, 0, 1))).normalized(), (d1 - d0).normalized(), V(0, 0, 1)), node=dn)
    if kit.lod == 0:
        for y in (0.3, 1.75):
            kit.box(V(hinge.x + 0.25, fy + y, hz + 0.034), V(0.5, 0.04, 0.008), "bld_iron", (0.2, 0.15, 0.12), node=dn)
        kit.box(V(hinge.x + 0.85, fy + 1.0, hz + 0.04), V(0.03, 0.15, 0.02), "bld_iron", (0.2, 0.15, 0.12), node=dn)
    # rafters (seen through the broken roof and from the porch), then the corrugated sheets
    roof = Roof(kit, W, D, EAVE_Y, RIDGE_Y - EAVE_Y, "x", oe=0.35, ov=0.3, T=0.1, mat="bld_corrugated_rust", tint=(0.95, 0.92, 0.9))
    if kit.lod < 2:
        nr = 13
        for i in range(nr):
            x = -hx + 0.1 + (W - 0.2) * i / (nr - 1)
            for s in (-1, 1):
                a = V(x, EAVE_Y - 0.06, s * (hz - 0.04))
                b = V(x, RIDGE_Y - 0.08, 0)
                dvec = (b - a).normalized()
                kit.box((a + b) / 2, V(0.05, (b - a).length, 0.12), "bld_wood", (0.5, 0.42, 0.32), (V(1, 0, 0), dvec, V(1, 0, 0).cross(dvec)))
        kit.box(V(0, RIDGE_Y - 0.12, 0), V(W + 0.5, 0.16, 0.05), "bld_wood", (0.5, 0.42, 0.32))
    holes = []
    if broken:
        holes = [(1, -1.6, 0.4, 0.25, 0.75), (-1, 0.8, 2.2, 0.5, 1.0)]
    roof.build(strips=4, ridge_tiles=False, fascia=bare, barge=bare, verge_mat="bld_wood", gutters=False, holes=holes)
    L = hx + 0.3
    yr = roof.top_y(0.0)
    for s in (-1, 1):
        bot = [roof.g(-L, yr - 0.01, 0.0), roof.g(L, yr - 0.01, 0.0), roof.g(L, roof.top_y(s * 0.25) - 0.01, s * 0.25), roof.g(-L, roof.top_y(s * 0.25) - 0.01, s * 0.25)]
        kit.hexa(ccw(bot), ccw([p + V(0, 0.01, 0) for p in bot]), "bld_corrugated_rust", (0.8, 0.7, 0.6))
    if broken:
        # a torn sheet hanging into the hole and another fallen against the porch rail
        a = V(-1.6, roof.top_y(1.5), 1.5); b = V(-0.4, roof.top_y(1.5), 1.5)
        kit.box(V(-1.0, roof.top_y(1.5) - 0.35, 1.45), V(1.1, 0.012, 1.0), "bld_corrugated_rust", (0.9, 0.85, 0.8), (V(1, 0, 0), V(0, 0.45, 0.89).normalized(), V(1, 0, 0).cross(V(0, 0.45, 0.89).normalized())))
        kit.box(V(-1.5, 1.2, hz + 2.2), V(1.1, 0.012, 2.3), "bld_corrugated_rust", (0.9, 0.85, 0.8), (V(1, 0, 0), V(0, 0.95, -0.3).normalized(), V(1, 0, 0).cross(V(0, 0.95, -0.3).normalized())))
    # the porch: deck, posts, beam, its own lean-to roof bearing on the cabin wall and the beam, rail and a rotten step
    py = fy
    for k in range(10):
        kit.box(V(0, py - 0.02, hz + 0.15 + k * 0.19), V(W, 0.035, 0.17), "bld_wood", kit.jit(bare, 0.15))
    for sx in (-3.8, -1.3, 1.3, 3.8):
        kit.box(V(sx, (py + EAVE_Y - 0.35) / 2, hz + 1.85), V(0.12, EAVE_Y - 0.35 - py, 0.12), "bld_wood", bare)
        kit.box(V(sx, (py - 0.12) / 2, hz + 1.85), V(0.3, py - 0.12, 0.3), "bld_stone", (0.6, 0.58, 0.54))
    kit.box(V(0, EAVE_Y - 0.42, hz + 1.85), V(W, 0.14, 0.14), "bld_wood", bare)
    # lean-to: underside from the cabin wall at EAVE_Y - 0.12 down to the beam top at EAVE_Y - 0.35, overhang 0.3
    y_w, y_b = EAVE_Y - 0.12, EAVE_Y - 0.35
    z_w, z_b = hz + 0.04, hz + 1.85
    sl = (y_w - y_b) / (z_b - z_w)
    z_e = z_b + 0.35
    y_e = y_b - 0.35 * sl
    bot = [V(-hx - 0.3, y_w, z_w), V(hx + 0.3, y_w, z_w), V(hx + 0.3, y_e, z_e), V(-hx - 0.3, y_e, z_e)]
    top = [p + V(0, 0.06, 0) for p in bot]
    kit.hexa(ccw(bot), ccw(top), "bld_corrugated_rust", (0.9, 0.86, 0.82))
    kit.box(V(0, y_w + 0.03, z_w + 0.02), V(W + 0.6, 0.12, 0.04), "bld_wood", bare)       # the ledger on the wall
    for k in range(5):
        kit.box(V(-3.8 + k * 0.95, py + 0.45, hz + 1.85), V(0.05, 0.9, 0.05), "bld_wood", bare)
    kit.box(V(-1.9, py + 0.85, hz + 1.85), V(3.8, 0.045, 0.1), "bld_wood", bare)
    for k in range(2):
        kit.box(V(1.3, py - 0.17 - k * 0.17, hz + 2.1 + k * 0.28), V(1.1, 0.04, 0.3), "bld_wood", bare)
    # the stone chimney on the right gable, outside the wall, rising past the ridge
    cx = hx + 0.55
    for i in range(int((RIDGE_Y + 0.9) / 0.25)):
        y = i * 0.25 + 0.125
        w = 1.0 if y < 2.2 else 0.7
        kit.box(V(cx + (0.0 if y < 2.2 else -0.05), y, 0.0), V(w * 0.95, 0.24, w * 0.95 + (0.25 if y < 2.2 else 0.0)), "bld_stone", kit.jit((0.6, 0.57, 0.52), 0.12))
    kit.box(V(cx - 0.05, RIDGE_Y + 0.95, 0), V(0.8, 0.08, 0.8), "bld_stone", (0.5, 0.48, 0.45))
    if kit.lod < 2:
        kit.lathe(V(cx - 0.05, RIDGE_Y + 0.99, 0), [(0.13, 0.0), (0.11, 0.35), (0.13, 0.42), (0.09, 0.42), (0.0, 0.1)], 10, "bld_iron", (0.2, 0.17, 0.15))
    # board shutters on the front windows (the right one hangs off one hinge), a rain barrel, boards sprung off the wall
    if kit.lod < 2:
        for u, hang in ((-2.0, False), (3.4, True)):
            for e in (-1, 1):
                c = F.P(u + e * 0.92, fy + 1.5, -0.03)
                if hang and e > 0:
                    tilt = (F.r * math.cos(0.5) - UP * math.sin(0.5), F.r * math.sin(0.5) + UP * math.cos(0.5), F.n)
                    kit.box(c + V(0.12, -0.2, 0.02), V(0.6, 1.25, 0.035), "bld_wood", kit.jit(bare, 0.1), tilt)
                else:
                    kit.box(c, V(0.6, 1.25, 0.035), "bld_wood", kit.jit((0.42, 0.5, 0.44), 0.1), (F.r, UP, F.n))
                    for y in (-0.4, 0.4):
                        kit.box(c + UP * y + F.n * 0.02, V(0.56, 0.1, 0.02), "bld_wood", kit.jit(bare, 0.1), (F.r, UP, F.n))
        bc = V(-hx - 0.5, 0.0, hz - 0.6)
        kit.cyl(bc, bc + V(0, 0.9, 0), 0.3, 0.32, 16, "bld_wood", (0.45, 0.36, 0.26))
        for y in (0.15, 0.75):
            kit.cyl(bc + V(0, y - 0.02, 0), bc + V(0, y + 0.03, 0), 0.315, 0.315, 16, "bld_iron", (0.25, 0.18, 0.14))
        for i, (u, y) in enumerate(((-3.2, 1.2), (0.0, 0.6), (2.2, 2.1))):
            kit.box(F.P(u, fy + y, -0.05), V(0.9, 0.15, 0.025), "bld_wood", kit.jit(bare, 0.12), (F.r, (UP + F.n * 0.12 * (i - 1)).normalized(), (F.n - UP * 0.12 * (i - 1)).normalized()))
    # weathering: streaks down the boards under the windows
    if kit.lod == 0:
        for u in (-2.0, 3.4):
            streak(kit, F, u, fy + 0.85, 1.1, 0.7, alpha=0.5)
    kit.hulls.append((V(0, 2.2, 0), V(8.4, 4.4, 6.4)))
    kit.hulls.append((V(0, 0.35, hz + 1.1), V(8.4, 0.7, 2.2)))
    return EAVE_Y


BUILDINGS = {
    "town_police_house_a": ("halloway", lambda k: police_house(k, False)),
    "town_police_house_a_open": ("halloway", lambda k: police_house(k, True)),
    "town_pub_a": ("halloway", pub),
    "town_village_hall_a": ("halloway", village_hall),
    "town_shop_a": ("halloway", lambda k: shop(k, "a")),
    "town_shop_b": ("halloway", lambda k: shop(k, "b")),
    "town_bakery_a": ("halloway", lambda k: shop(k, "bakery")),
    "town_chip_shop_a": ("halloway", lambda k: shop(k, "chips")),
    "town_church_a": ("halloway", church),
    "town_school_a": ("halloway", school),
    "garage_shell_a": ("halloway", garage),
    "cabin_abandoned_a": ("cabin", lambda k: cabin(k, False)),
    "cabin_abandoned_a_broken_roof": ("cabin", lambda k: cabin(k, True)),
}


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only, lods, out = None, [0, 1, 2], os.path.join(GODOT, "assets", "models", "story")
    for a in args:
        if a.startswith("only="): only = a[5:].split(",")
        if a.startswith("lods="): lods = [int(x) for x in a[5:].split(",")]
        if a.startswith("out="): out = a[4:]
    for name, (group, fn) in BUILDINGS.items():
        if only and name not in only:
            continue
        for lod in lods:
            t0 = time.time()
            reset_scene()
            kit = Kit(name, lod, seed=zlib.crc32(name.encode()))
            wh = fn(kit)
            path = os.path.join(out, group, name + ("" if lod == 0 else "_lod%d" % lod) + ".glb")
            tris = export(kit, path, wh)
            print("BUILT %-32s lod %d  %6d tris  %.1fs  %s" % (name, lod, tris, time.time() - t0, path))


main()

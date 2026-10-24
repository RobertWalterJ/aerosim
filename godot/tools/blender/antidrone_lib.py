# AeroSim anti-drone kit (lane/antidrone): Harlan Pike's ridge (docs/CLAUDE-ANTI-DRONE-ASSETS.md on lane/notify).
# Built on the sites kit (sites_lib.py): the same game-frame primitives, Mesh/Asset classes, occlusion-and-weathering
# vertex colours, floating / inside-out / probe checks and LOD decimation. What this adds:
#   - the ad_* material keys (game/antidrone_assets.gd swaps in the photographed or plain PBR material by name; site_*
#     keys are swapped by SiteAssets, so the two lanes share one set of photographed materials);
#   - NODE HIERARCHY: asset.parents = {child: parent} so moving parts nest (mast > mast_stage_2 > mast_stage_3 > dish,
#     beacon), each with its own pivot; the exported local transform is the child's pivot relative to its parent's;
#   - emissive lamp materials (ad_lamp_*), switched by the loader, not by light nodes;
#   - per-asset meta: text rectangles for Label3D faces, the mast hinge axis, rotor spin directions, the hunter's centre.
import bpy, bmesh, math, os, json, random
from mathutils import Vector as V, Matrix
import sites_lib as S
from sites_lib import (box, grid_box, cyl, sphere, torus, sweep, loft, grid, disc_patch, rock, Mesh, Asset, mrot,
                       fbm, mix, smooth, srgb_lin)

OUT = os.path.join(S.GODOT, "assets", "models", "antidrone")

# key -> (fallback base colour sRGB, roughness, metallic): what a bare import shows; the game replaces each by name.
AD_MATS = {
    "ad_trailer_paint": ((0.24, 0.29, 0.22), 0.7, 0.0),     # faded olive enamel over steel (rust in the vertex colour)
    "ad_rust": ((0.38, 0.19, 0.09), 0.85, 0.25),
    "ad_galv": ((0.60, 0.61, 0.60), 0.45, 0.85),
    "ad_steel_dark": ((0.13, 0.13, 0.13), 0.55, 0.7),
    "ad_ply": ((0.62, 0.52, 0.38), 0.85, 0.0),
    "ad_planks": ((0.45, 0.42, 0.38), 0.9, 0.0),
    "ad_corrugated": ((0.45, 0.33, 0.25), 0.7, 0.6),
    "ad_tarp": ((0.27, 0.30, 0.20), 0.8, 0.0),
    "ad_tarp_blue": ((0.16, 0.27, 0.42), 0.75, 0.0),
    "ad_paint_white": ((0.82, 0.80, 0.74), 0.75, 0.0),
    "ad_paint_red": ((0.55, 0.12, 0.08), 0.6, 0.0),
    "ad_paper": ((0.86, 0.80, 0.62), 0.92, 0.0),          # the blank taped sheet (Label3D face)
    "ad_paper_lined": ((0.86, 0.80, 0.62), 0.92, 0.0),    # pike_manifesto_paper.png (unreadable lines)
    "ad_notices": ((0.86, 0.84, 0.78), 0.92, 0.0),        # pike_notice_stack.png
    "ad_tape": ((0.80, 0.74, 0.55), 0.5, 0.0),
    "ad_cable": ((0.05, 0.05, 0.05), 0.6, 0.0),
    "ad_cable_orange": ((0.80, 0.33, 0.06), 0.55, 0.0),
    "ad_plastic_dark": ((0.07, 0.075, 0.08), 0.45, 0.0),
    "ad_plastic_grey": ((0.32, 0.33, 0.33), 0.5, 0.0),
    "ad_carbon": ((0.05, 0.05, 0.055), 0.35, 0.0),
    "ad_motor": ((0.12, 0.12, 0.13), 0.35, 0.8),
    "ad_prop": ((0.04, 0.04, 0.045), 0.4, 0.0),
    "ad_battery": ((0.10, 0.11, 0.10), 0.5, 0.0),
    "ad_strap": ((0.12, 0.12, 0.12), 0.8, 0.0),
    "ad_glass": ((0.25, 0.27, 0.27), 0.08, 0.0),
    "ad_lens": ((0.03, 0.03, 0.035), 0.05, 0.0),
    "ad_canvas": ((0.18, 0.25, 0.16), 0.85, 0.0),         # camp chair
    "ad_bone": ((0.84, 0.80, 0.70), 0.75, 0.0),
    "ad_ribbon": ((0.62, 0.08, 0.07), 0.8, 0.0),
    "ad_engine": ((0.30, 0.31, 0.30), 0.55, 0.5),
    "ad_jerrycan": ((0.25, 0.30, 0.17), 0.55, 0.0),
    "ad_thermos": ((0.18, 0.30, 0.22), 0.4, 0.3),
    "ad_toolbox_red": ((0.55, 0.08, 0.06), 0.45, 0.2),
    "ad_chrome": ((0.75, 0.75, 0.76), 0.2, 1.0),
    "ad_water": ((0.06, 0.07, 0.06), 0.05, 0.0),
    "ad_ground": ((0.45, 0.40, 0.28), 0.95, 0.0),         # pike_ridge_clearing (u, v 0..1 over the 12 m patch)
    "ad_decal_stencil": ((0.62, 0.06, 0.05), 0.8, 0.0),   # pike_no_drone_stencil.png
    "ad_decal_tyre": ((0.20, 0.16, 0.12), 0.9, 0.0),      # pike_tyre_marks.png
    "ad_smoke": ((0.55, 0.55, 0.54), 1.0, 0.0),           # pike_smoke_card.png (alpha, unshaded)
    "ad_strobe": ((1.0, 0.25, 0.2), 1.0, 0.0),            # pike_strobe_card.png (additive)
    "ad_lamp_red": ((0.75, 0.05, 0.03), 0.2, 0.0),        # beacon (emissive; on by default)
    "ad_lamp_eye": ((0.85, 0.04, 0.03), 0.1, 0.0),        # hunter forward eye (emissive; on by default)
    "ad_lamp_strobe": ((1.0, 0.1, 0.06), 0.1, 0.0),       # racing hunter strobe (emissive)
    "ad_lamp_amber": ((0.95, 0.50, 0.05), 0.2, 0.0),      # generator warning lamp
    "ad_lamp_white": ((0.95, 0.92, 0.80), 0.15, 0.0),     # floodlight lens
    "ad_lamp_green": ((0.10, 0.85, 0.20), 0.2, 0.0),      # radio / status LEDs
}
S.MATS.update(AD_MATS)
LAMPS = [k for k in AD_MATS if k.startswith("ad_lamp")]


def material(key):
    m = S.material(key)
    if key in LAMPS:
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Emission Color"].default_value = srgb_lin(AD_MATS[key][0]) + (1.0,)
        b.inputs["Emission Strength"].default_value = 2.0
    return m


class AD(Asset):
    """an Asset with a node hierarchy: parents = {child: parent}"""

    def __init__(self, name, parents=None, **kw):
        kw.setdefault("ao_dist", 0.35)
        super().__init__(name, **kw)
        self.parents = dict(parents or {})


def _world(asset, nm):
    mesh, pivot, rot = asset.nodes[nm]
    return S.G2B @ S.node_matrix(pivot, rot) @ S.G2B.inverted()


def build(asset, out_dir=OUT):
    """as sites_lib.build, with nested nodes and emissive lamps; returns the manifest entry"""
    S.clear_scene()
    os.makedirs(out_dir, exist_ok=True)
    S._pose(asset)
    chk = S.checks(asset)
    S.bake_colours(asset)
    coll = bpy.context.scene.collection
    objs = []
    empties = {}
    tris0 = tris1 = 0
    nodes_info = {}
    for nm in asset.order:
        mesh, pivot, rot = asset.nodes[nm]
        if len(mesh.bm.faces) == 0 and nm not in asset.parents.values():
            continue
        e = bpy.data.objects.new(nm, None)
        coll.objects.link(e)
        empties[nm] = e
        objs.append(e)
        info = {"pivot": [round(x, 3) for x in pivot], "rot": list(rot), "tris": [], "materials": list(mesh.mats),
                "parent": asset.parents.get(nm, "")}
        if len(mesh.bm.faces):
            o0 = S._make_object(nm + "_LOD0", mesh, pivot, rot, coll)
            for k in mesh.mats:
                if k in LAMPS:
                    material(k)
            o0.parent = e
            objs.append(o0)
            t0 = S.tri_count(o0)
            tris0 += t0
            info["tris"].append(t0)
            if asset.lod1 and t0 > 150:
                o1 = S.decimate(o0, asset.lod1, nm + "_LOD1")
                o1.parent = e
                objs.append(o1)
                info["tris"].append(S.tri_count(o1))
                tris1 += S.tri_count(o1)
            else:
                tris1 += t0
        nodes_info[nm] = info
    # transforms: a top-level node keeps its world matrix; a child's matrix_basis is relative to its parent
    for nm, e in empties.items():
        W = _world(asset, nm)
        par = asset.parents.get(nm)
        if par and par in empties:
            e.parent = empties[par]
            e.matrix_parent_inverse = Matrix.Identity(4)
            e.matrix_basis = _world(asset, par).inverted() @ W
        else:
            e.matrix_basis = W
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    path = os.path.join(out_dir, asset.name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=False, export_yup=True,
                              export_texcoords=True, export_normals=True, export_tangents=True, export_materials='EXPORT',
                              export_vertex_color='ACTIVE', export_all_vertex_colors=False,
                              export_active_vertex_color_when_no_material=True, export_image_format='NONE',
                              export_animations=False, export_extras=False)
    lo, hi = chk["aabb"]
    size = [round(hi[i] - lo[i], 3) for i in range(3)]
    span = max(size)
    lod_end = asset.lod_end or max(18.0, min(70.0, span * 9.0))
    man = {"file": asset.name + ".glb", "tris": [tris0, tris1], "size": size, "aabb_lo": lo, "aabb_hi": hi,
           "nodes": nodes_info, "lod_end": round(lod_end, 1), "checks": chk, "meta": asset.meta,
           "buried_ok": asset.buried_ok, "budget": asset.budget, "bytes": os.path.getsize(path)}
    print("AD %-26s tris %6d/%6d  size %s  floating %s  inside_out %s  probes %s" % (
        asset.name, tris0, tris1, size, chk["floating"], chk["inside_out"], [p["ok"] for p in chk["probes"]]), flush=True)
    return man


# ------------------------------------------------------------------------------------------------ small helpers
def quad(w, h, c=(0, 0, 0), rot=(0, 0, 0)):
    """a single double-sidable quad in the x-y plane facing +z, centred on c (UVs 0..1 set by the caller via uv01)"""
    bm = bmesh.new()
    vs = [bm.verts.new((-w / 2, -h / 2, 0)), bm.verts.new((w / 2, -h / 2, 0)), bm.verts.new((w / 2, h / 2, 0)),
          bm.verts.new((-w / 2, h / 2, 0))]
    bm.faces.new(vs)
    bmesh.ops.transform(bm, matrix=Matrix.Translation(V(c)) @ mrot(rot), verts=bm.verts)
    return bm


def uv01(w, h, c=(0, 0, 0), rot=(0, 0, 0), flip_u=False):
    """UV function mapping a quad made by quad(w, h, c, rot) to 0..1 (v up)"""
    M = (Matrix.Translation(V(c)) @ mrot(rot)).inverted()

    def f(co, n):
        p = M @ co
        u = p.x / w + 0.5
        return ((1 - u) if flip_u else u, p.y / h + 0.5)
    return f


def wheel(mesh, c, r, w, axis_x=True, rim_mat="ad_galv", tyre_mat="site_rubber", seg=16):
    """a tyre and a pressed-steel rim, axle along x"""
    a = V(c) - V((w / 2, 0, 0)); b = V(c) + V((w / 2, 0, 0))
    mesh.add(cyl(r, r, a, b, seg=seg), tyre_mat, smooth=True, uv='cyl', grain=(1, 0, 0))
    mesh.add(cyl(r * 0.92, r * 0.92, a - V((0.004, 0, 0)), b + V((0.004, 0, 0)), seg=seg), tyre_mat, smooth=True)
    for s in (-1, 1):
        p = V(c) + V((s * (w / 2 + 0.006), 0, 0))
        mesh.add(cyl(r * 0.62, r * 0.55, p - V((s * 0.01, 0, 0)), p + V((s * 0.012, 0, 0)), seg=seg), rim_mat)
        mesh.add(cyl(r * 0.16, r * 0.12, p, p + V((s * 0.03, 0, 0)), seg=8), rim_mat)


def rotor(mesh, c, r, blades=2, chord=0.03, pitch=12.0, seed=0, hub_r=0.016, tip_up=0.004):
    """a propeller in the x-z plane at height c.y: hub plus twisted blades (thin lofts)"""
    c = V(c)
    mesh.add(cyl(hub_r, hub_r * 0.85, c - V((0, 0.006, 0)), c + V((0, 0.012, 0)), seg=10), "ad_motor", smooth=True)
    for k in range(blades):
        a0 = k * math.tau / blades + seed * 0.3
        rings = []
        n = 6
        for i in range(n + 1):
            t = i / n
            rr = hub_r * 0.8 + (r - hub_r * 0.8) * t
            ch = chord * (0.75 + 0.6 * math.sin(math.pi * min(1.0, t * 1.2)) * (1 - 0.6 * t))
            tw = math.radians(pitch * (1.2 - 0.8 * t))
            th = 0.0035 * (1 - 0.6 * t)
            d = V((math.cos(a0), 0, math.sin(a0)))
            sd = V((-math.sin(a0), 0, math.cos(a0)))
            up = V((0, 1, 0))
            cen = c + d * rr + up * (tip_up * t * t)
            # section: a flat lozenge, chord along sd, tilted by the twist
            lead = sd * math.cos(tw) + up * math.sin(tw)
            nrm = up * math.cos(tw) - sd * math.sin(tw)
            rings.append([cen + lead * ch * 0.5, cen + nrm * th, cen - lead * ch * 0.5, cen - nrm * th])
        mesh.add(loft(rings, close_ring=True, cap0=True, cap1=True), "ad_prop", smooth=False)


def tube_path(pts, r, mat, mesh, seg=6, caps=True):
    mesh.add(sweep(pts, r, seg=seg, caps=caps), mat, smooth=True, uv='cyl', grain=(V(pts[-1]) - V(pts[0])).normalized())


def sag(a, b, n=10, drop=0.1, wob=0.0, seed=0):
    """points along a hanging wire from a to b"""
    rnd = random.Random(seed)
    a, b = V(a), V(b)
    out = []
    for i in range(n + 1):
        t = i / n
        p = a.lerp(b, t)
        p.y -= drop * 4 * t * (1 - t)
        if wob and 0 < i < n:
            p += V((rnd.uniform(-wob, wob), rnd.uniform(-wob, wob) * 0.5, rnd.uniform(-wob, wob)))
        out.append(p)
    return out


def rust_colour(seed=0.0, amount=0.5, scale=3.0):
    """weathering: rust blooms and streaks below edges (as a vertex-colour multiplier pulled toward rust brown)"""
    def f(co, n, mat, node, tag):
        if mat in ("ad_lamp_red", "ad_lamp_eye", "ad_lamp_strobe", "ad_lamp_amber", "ad_lamp_white", "ad_lamp_green",
                   "ad_glass", "ad_lens", "ad_paper", "ad_paper_lined", "ad_notices", "ad_decal_stencil", "ad_smoke",
                   "ad_strobe", "ad_decal_tyre", "ad_ground"):
            return (1.0, 1.0, 1.0)
        g = fbm(co, scale, 3, seed)
        streak = fbm((co[0] * 6, co[1] * 0.8, co[2] * 6), 1.0, 2, seed + 3.0)
        dirt = 1.0 - 0.18 * smooth(0.35, 0.0, co[1]) if co[1] < 0.35 else 1.0      # splash dirt near the ground
        if mat in ("ad_trailer_paint", "ad_paint_white", "ad_paint_red", "ad_jerrycan", "ad_toolbox_red", "ad_galv",
                   "ad_corrugated"):
            r = smooth(0.15, 0.6, g * 0.5 + 0.5 + amount - 0.5) * 0.85 + 0.15 * smooth(0.3, 0.9, streak)
            r = min(1.0, r * amount * 1.4)
            c = mix((1.0, 1.0, 1.0), (0.62, 0.36, 0.20), r)
            return tuple(x * dirt for x in c)
        if mat in ("ad_planks", "ad_ply", "site_timber", "site_board"):
            d = smooth(-0.4, 0.6, g) * 0.25
            return tuple(x * dirt for x in mix((1.0, 1.0, 1.0), (0.62, 0.62, 0.55), d))
        v = 1.0 - 0.12 * smooth(-0.2, 0.8, g)
        return (v * dirt, v * dirt, v * dirt)
    return f

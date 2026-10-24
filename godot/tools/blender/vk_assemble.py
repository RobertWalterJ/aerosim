# AeroSim vehicle kit: turning a Body into rigged parts (body island, doors, lids), and the export.
import bpy, bmesh, math
from mathutils import Vector as V, Matrix
from vk_core import Part, material, tri_count, box_uv
from vk_body import Body, cut_arches, make_gaps, islands, edge_key


def body_parts(s, lod, gaps=True):
    """Build the body shell, cut the arches, open the panel gaps and split off the moving panels.
    Returns (parts, body_object_for_projection_bm, Body)."""
    B = Body(s, lod)
    bm = B.build()
    keys = B.panel_edges() if lod <= 1 else set()
    # panel centres for naming islands
    me = bpy.data.meshes.new("shell")
    bm.to_mesh(me)
    for m in B.mats:
        me.materials.append(material(m))
    ob = bpy.data.objects.new("shell", me)
    bpy.context.scene.collection.objects.link(ob)
    cut_arches(ob, s, lod)
    bm2 = bmesh.new()
    bm2.from_mesh(ob.data)
    mats = [m.name for m in ob.data.materials]
    surf_bm = bm2.copy()          # the closed-ish shell for projecting details onto
    if gaps and keys:
        make_gaps(bm2, keys, gap=0.0045 if lod == 0 else 0.007, depth=0.022 if lod == 0 else 0.012)
    groups = islands(bm2)
    parts = []
    # name the islands by the panels' boxes
    panel_boxes = []
    for p in s.panels:
        if "bone" in p:
            panel_boxes.append(p)
    big = max(groups, key=len)
    for g in groups:
        bone = "body"
        name = "body"
        if g is not big and len(g) > 3:
            c = V((0, 0, 0))
            for f in g:
                c += f.calc_center_median()
            c /= len(g)
            d = s.L * 0.5 - c.y
            best = None
            for p in panel_boxes:
                sides = p.get("sides")
                if p["kind"] == "door":
                    if not (p["d0"] - 0.02 <= d <= p["d1"] + 0.02):
                        continue
                    sd = 1 if c.x > 0 else -1
                    bn = p["bone"][sd]
                    best = bn
                    break
                elif p["kind"] == "rear_doors":
                    if d > s.L - 0.35 and abs(c.x) > 0.02:
                        best = p["bone"][1 if c.x > 0 else -1]
                        break
                elif p["kind"] in ("lid", "tailgate"):
                    if p["d0"] - 0.1 <= d <= p.get("d1", s.L) + 0.15 and abs(c.x) < s.W * 0.3:
                        best = p["bone"]
                        break
            if best:
                bone = best
                name = best
        pt = Part(name, bone)
        pt.sharp_angle = 40.0
        sub = bmesh.new()
        vm = {}
        for f in g:
            vs = []
            for v in f.verts:
                if v not in vm:
                    vm[v] = sub.verts.new(v.co)
                vs.append(vm[v])
            try:
                nf = sub.faces.new(vs)
            except ValueError:
                continue
            nf.material_index = f.material_index
            nf.smooth = f.smooth
        pt.add_bm(sub, keep_mats=mats)
        sub.free()
        parts.append(pt)
    # merge parts with the same bone
    merged = {}
    for p in parts:
        if p.bone in merged:
            merged[p.bone].add_bm(p.bm, keep_mats=p.mats)
        else:
            merged[p.bone] = p
    dme = ob.data
    bpy.data.objects.remove(ob)
    if dme.users == 0:
        bpy.data.meshes.remove(dme)
    bm.free(); bm2.free()
    return list(merged.values()), surf_bm, B

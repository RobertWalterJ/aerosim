# The vehicle brief's file paths (godot/docs/CLAUDE-VEHICLE-ASSETS.md on lane/notify), made from the Blender vehicles of
# lane/vehicles so traffic.gd and the story code can load them directly, without VehicleAssets:
#   assets/traffic/hatchback_a.glb hatchback_b.glb pickup_a.glb van_a.glb tractor_a.glb
#   assets/story/lake_car.glb festival_bus.glb police_cruiser.glb
#   assets/vehicles/parked_car_a.glb parked_car_b.glb parked_car_c.glb parked_van_a.glb farm_trailer_a.glb farm_truck_a.glb
#                   hay_trailer_a.glb car_roofbox_a.glb car_dogguard_a.glb
# Each is a STATIC copy of a rigged vehicle (assets/models/vehicles/<src>.glb) in the brief's contract:
#   metres, Y up, origin on the ground under the middle of the vehicle, forward -Z, right +X;
#   wheel_fl wheel_fr wheel_rl wheel_rr (and wheel_m1l...) as their own nodes with the origin at the hub (spin about local X);
#   lamp_head_l/_r and lamp_tail_l/_r as their own meshes with materials named exactly `headlight` and `taillight` (emissive,
#   at a near-zero strength so Godot imports them with emission on and the game can raise it);
#   the vertex colour carries baked occlusion x rust and road dirt (so a bare import already looks weathered);
#   paint recoloured to the brief; a few additions (van ladder, pickup load); posed where the brief asks (bus door open);
#   parked vehicles get a box collider (<name>-colonly). LOD: the file holds one mesh level (LOD0 for story vehicles,
#   the lane's LOD1 for traffic and parked cars); Godot's importer builds its automatic mesh LODs from it.
#   blender -b --factory-startup --python build_vehicle_aliases.py -- [only=hatchback_a,...]
import sys, os, json, math
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy, bmesh
from mathutils import Vector as V, Matrix

GODOT = os.path.normpath(os.path.join(HERE, "..", ".."))
VEH = os.path.join(GODOT, "assets", "models", "vehicles")
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
opt = dict(a.split("=", 1) for a in args if "=" in a)
only = set(opt["only"].split(",")) if opt.get("only") else None


def lin(c):
    return tuple(((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c)


# out path -> spec. paint sRGB; lod 0/1; pose (action, at end); rust tint strength; dirt (0..1); extras; collider
SPECS = {
    "traffic/hatchback_a": {"src": "car_hatch_b", "paint": (0.36, 0.05, 0.05), "lod": 1, "dirt": 0.35, "rust": 0.3,
                            "what": "small five-door hatchback, dark red, alloys (ARDEN)", "plate": "HY 07 KTL"},
    "traffic/hatchback_b": {"src": "car_estate_a", "paint": (0.36, 0.45, 0.55), "lod": 1, "dirt": 0.6, "rust": 0.3,
                            "what": "small estate, dusty blue, roof rails (VELIA)", "plate": "HY 11 DRW"},
    "traffic/pickup_a": {"src": "pickup_a", "paint": (0.80, 0.80, 0.76), "lod": 1, "dirt": 0.8, "rust": 0.5, "extras": ["load"],
                         "what": "double-cab farm pickup, faded white, loaded tray (CORVAN)", "plate": "VX 16 FARM"},
    "traffic/van_a": {"src": "van_a", "paint": (0.90, 0.90, 0.88), "lod": 1, "dirt": 0.6, "rust": 0.8, "extras": ["ladder"],
                      "what": "white panel van with a ladder on the roof (CORVAN)", "plate": "HY 09 VAN"},
    "traffic/tractor_a": {"src": "tractor_a", "paint": (0.18, 0.34, 0.16), "lod": 1, "dirt": 1.0, "rust": 0.6,
                          "what": "farm tractor, green, four-post cab (HALDEN 6140)", "plate": ""},
    "story/lake_car": {"src": "lake_car_estate_a", "paint": None, "lod": 0, "dirt": 1.0, "rust": 1.0, "algae": True,
                       "what": "the Lake Car: late-1980s blue estate (BRASK 245), rust, algae line, flat tyre, smashed rear "
                               "window, plates missing (the story), tailgate closed", "plate": "missing (story)"},
    "story/festival_bus": {"src": "festival_bus_garage", "paint": None, "lod": 0, "dirt": 0.7, "rust": 0.9,
                           "pose": "bus_door_open", "what": "the festival bus before restoration, HALLOWAY FESTIVAL, "
                                                           "passenger door open", "plate": ""},
    "story/police_cruiser": {"src": "cruiser_1984_flat", "paint": None, "lod": 0, "dirt": 0.6, "rust": 0.8,
                             "what": "1984 provincial police cruiser, rear left tyre flat, lightbar unlit", "plate": ""},
    "vehicles/parked_car_a": {"src": "car_estate_a", "paint": (0.45, 0.46, 0.47), "lod": 1, "dirt": 1.0, "rust": 0.4, "collider": True,
                              "what": "parked estate, grey, muddy"},
    "vehicles/parked_car_b": {"src": "car_hatch_a", "paint": (0.36, 0.45, 0.34), "lod": 1, "dirt": 0.6, "rust": 0.5, "collider": True,
                              "what": "parked small hatchback, faded green"},
    "vehicles/parked_car_c": {"src": "pickup_b", "paint": None, "lod": 1, "dirt": 0.9, "rust": 0.9, "collider": True,
                              "what": "parked older farm pickup (BRASK)"},
    "vehicles/parked_van_a": {"src": "van_b", "paint": (0.88, 0.88, 0.85), "lod": 1, "dirt": 0.6, "rust": 0.6, "collider": True,
                              "what": "parked delivery van, white, blank panels"},
    "vehicles/farm_trailer_a": {"src": "farm_trailer_a", "paint": None, "lod": 1, "dirt": 0.8, "rust": 0.5, "collider": True,
                                "what": "small farm trailer, mesh sides and a ramp gate"},
    "vehicles/farm_truck_a": {"src": "farm_truck_a", "paint": None, "lod": 1, "dirt": 0.9, "rust": 0.8, "collider": True,
                              "what": "older farm pickup on a flatbed with a toolbox"},
    "vehicles/hay_trailer_a": {"src": "hay_trailer_a", "paint": None, "lod": 1, "dirt": 0.8, "rust": 0.5, "collider": True,
                               "what": "tandem bale trailer loaded with small square bales"},
    "vehicles/car_roofbox_a": {"src": "car_estate_roofbox_a", "paint": None, "lod": 1, "dirt": 0.6, "rust": 0.3, "collider": True,
                               "what": "estate with a roof box"},
    "vehicles/car_dogguard_a": {"src": "car_estate_dogguard_a", "paint": None, "lod": 1, "dirt": 0.6, "rust": 0.3, "collider": True,
                                "what": "estate with a dog guard behind the rear seats"},
}

MAN = json.load(open(os.path.join(VEH, "manifest.json")))
RUST = lin((0.48, 0.24, 0.12))
MUD = lin((0.40, 0.33, 0.25))


def g2b(p):
    return V((p[0], -p[2], p[1]))


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mesh_of(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    me.transform(ob.matrix_world)
    return me


def box_obj(name, lo, hi, mat):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    c = (V(lo) + V(hi)) / 2
    s = V(hi) - V(lo)
    bmesh.ops.scale(bm, vec=s, verts=bm.verts)
    bmesh.ops.translate(bm, vec=c, verts=bm.verts)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    if mat:
        me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def tube_obj(name, a, b, r, mat, seg=8):
    a, b = V(a), V(b)
    d = b - a
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=d.length)
    q = V((0, 0, 1)).rotation_difference(d.normalized())
    bmesh.ops.transform(bm, matrix=Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4(), verts=bm.verts)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def matnamed(name, base=None, metal=0.0, rough=0.8):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    if base:
        b.inputs["Base Color"].default_value = base + (1,)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    return m


def extras(kind, info):
    """additions in Blender coords (x right, y forward, z up), on the ground origin"""
    out = []
    L = info["size"][2]
    H = info["size"][1]
    if kind == "ladder":
        alu = matnamed("metal")
        z = H + 0.06
        for x in (-0.22, 0.22):
            out.append(tube_obj("ladder_rail", (x, 1.2, z), (x, -2.3, z), 0.022, alu))
        for k in range(12):
            y = 1.1 - k * 0.3
            out.append(tube_obj("ladder_rung", (-0.22, y, z), (0.22, y, z), 0.014, alu))
        for y in (0.9, -0.6, -2.0):
            out.append(box_obj("roof_bar", (-0.8, y - 0.02, H - 0.01), (0.8, y + 0.02, z - 0.02), matnamed("trim")))
    if kind == "load":
        straw = matnamed("straw", lin((0.6, 0.48, 0.24)), 0, 0.95)
        out.append(box_obj("load_bale", (-0.4, -1.95, 0.88), (0.42, -1.05, 1.24), straw))
        out.append(box_obj("load_toolbox", (0.25, -2.4, 0.88), (0.75, -2.15, 1.1), matnamed("toolbox_red", lin((0.6, 0.08, 0.05)), 0.2, 0.5)))
        out.append(box_obj("load_jerrycan", (-0.75, -2.45, 0.88), (-0.55, -2.15, 1.25), matnamed("jerrycan", lin((0.12, 0.2, 0.1)), 0.0, 0.6)))
        out.append(box_obj("load_feed_sack", (-0.6, -1.0, 0.88), (-0.05, -0.65, 1.02), matnamed("sack", lin((0.7, 0.66, 0.55)), 0.0, 0.9)))
    return out


def build(out_rel, sp):
    clear()
    src = sp["src"]
    info = MAN[src]
    bpy.ops.import_scene.gltf(filepath=os.path.join(VEH, src + ".glb"))
    arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    lodname = "%s_LOD%d" % (src, sp["lod"])
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    keep = next(o for o in meshes if o.name.startswith(lodname))
    # pose (bus door open): the action at its last frame
    if sp.get("pose"):
        act = next((a for a in bpy.data.actions if a.name.startswith(sp["pose"])), None)
        if act:
            arm.animation_data_create()
            for t in list(arm.animation_data.nla_tracks):
                t.mute = True
            arm.animation_data.action = act
            bpy.context.scene.frame_set(int(act.frame_range[1]))
    else:
        if arm.animation_data:
            arm.animation_data.action = None
            for t in arm.animation_data.nla_tracks:
                t.mute = True
        bpy.context.scene.frame_set(0)
        for pb in arm.pose.bones:
            pb.matrix_basis = Matrix()
    bpy.context.view_layer.update()
    # dominant bone per vertex (rigid skin: weight 1)
    groups = {g.index: g.name for g in keep.vertex_groups}
    vbone = []
    for v in keep.data.vertices:
        best = max(v.groups, key=lambda g: g.weight, default=None)
        vbone.append(groups.get(best.group, "body") if best else "body")
    me = mesh_of(keep)
    # vertex colours: occlusion x rust (from the finish condition) x road dirt low down; alpha 1
    ca = me.color_attributes.get("Col") or (me.color_attributes[0] if len(me.color_attributes) else None)
    paint_idx = [i for i, m in enumerate(me.materials) if m and m.name.split(".")[0] in ("paint", "paint2", "primer")]
    if ca is not None:
        corner = ca.domain == 'CORNER'
        vco = [v.co.copy() for v in me.vertices]
        loop_poly = [0] * len(me.loops)
        for p in me.polygons:
            for li in p.loop_indices:
                loop_poly[li] = p.index
        def shade(c, z, painted):
            ao = c[0]
            cond = c[3]
            r = max(0.0, 1.0 - cond) * sp.get("rust", 0.5) * (1.0 if painted else 0.4)
            col = [ao * (1 - r) + ao * RUST[i] * r * 1.6 for i in range(3)]
            d = sp.get("dirt", 0.4) * max(0.0, 1.0 - z / 0.75) ** 1.5
            col = [col[i] * (1 - d * 0.7) + col[i] * MUD[i] * d * 0.7 * 2.0 for i in range(3)]
            if sp.get("algae") and z < 0.45:
                k = max(0.0, 1.0 - abs(z - 0.38) / 0.05) * 0.6
                col = [col[0] * (1 - k) + 0.12 * k, col[1] * (1 - k) + 0.16 * k, col[2] * (1 - k) + 0.07 * k]
            return (max(0, min(1, col[0])), max(0, min(1, col[1])), max(0, min(1, col[2])), 1.0)
        if corner:
            for li, l in enumerate(me.loops):
                p = me.polygons[loop_poly[li]]
                c = ca.data[li].color
                ca.data[li].color = shade(c, vco[l.vertex_index].z, p.material_index in paint_idx)
        else:
            vpaint = [False] * len(me.vertices)
            for p in me.polygons:
                if p.material_index in paint_idx:
                    for vi in p.vertices:
                        vpaint[vi] = True
            for vi in range(len(me.vertices)):
                ca.data[vi].color = shade(ca.data[vi].color, vco[vi].z, vpaint[vi])
        me.color_attributes.active_color = ca
    # clean materials from the kit's definitions (the imported ones route colour through vertex-colour nodes that do not
    # survive a re-export), with the recipe's paints and colours, then the brief's paint
    import vk_core
    import vk_recipes, vk_recipes_cars, vk_recipes_heavy, vk_recipes_custom, vk_icecream, vk_small, vk_farm
    rc = vk_recipes.RECIPES.get(src, {})
    cols = {"paint": lin(sp["paint"]) if sp.get("paint") else lin(rc.get("paint", info.get("paint") or (0.5, 0.5, 0.5)))}
    if rc.get("paint2") or info.get("paint2"):
        cols["paint2"] = lin(rc.get("paint2") or info["paint2"])
    for k, v in rc.get("mat_colours", {}).items():
        cols[k] = lin(v)
    for i, m in enumerate(me.materials):
        if not m:
            continue
        base = m.name.split(".")[0]
        if base not in vk_core.MAT_DEFS:
            continue
        old = bpy.data.materials.get(base)
        if old is not None and old.get("aliased") is None:
            old.name = base + "_imported"
        nm_ = vk_core.material(base)
        nm_["aliased"] = 1
        if base in cols:
            vk_core.set_material_colour(base, cols[base])
        me.materials[i] = nm_
    # lamp materials named for the traffic code
    for m in me.materials:
        if not m:
            continue
        base = m.name.split(".")[0]
        if base in ("lamp_front", "lamp_tail"):
            m.name = "headlight" if base == "lamp_front" else "taillight"
            b = m.node_tree.nodes.get("Principled BSDF")
            b.inputs["Emission Color"].default_value = ((1.0, 0.92, 0.7, 1) if base == "lamp_front" else (0.9, 0.03, 0.02, 1))
            b.inputs["Emission Strength"].default_value = 1.0     # full colour; the game scales emission_energy_multiplier
            if base == "lamp_front":
                # an opaque pale lens so the raised emission reads (the kit's clear lens over a chrome bowl shows little)
                b.inputs["Alpha"].default_value = 1.0
                b.inputs["Base Color"].default_value = (0.75, 0.74, 0.70, 1.0)
                try:
                    m.surface_render_method = 'DITHERED'
                except Exception:
                    pass
                m.blend_method = 'OPAQUE'
        if base in ("lightbar_red", "lightbar_blue"):
            b = m.node_tree.nodes.get("Principled BSDF")
            b.inputs["Emission Strength"].default_value = 0.0
    # split: wheels by bone, lamps by material and side, the rest is the body
    bm = bmesh.new(); bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    pieces = {}
    mat_names = [m.name if m else "" for m in me.materials]
    for f in bm.faces:
        bones = {vbone[v.index] for v in f.verts}
        bone = bones.pop() if len(bones) == 1 else "body"
        if bone.startswith("wheel_"):
            key = bone
        else:
            mn = mat_names[f.material_index] if f.material_index < len(mat_names) else ""
            cx = f.calc_center_median().x
            if mn == "headlight":
                key = "lamp_head_l" if cx < 0 else "lamp_head_r"
            elif mn == "taillight":
                key = "lamp_tail_l" if cx < 0 else "lamp_tail_r"
            else:
                key = "body"
        pieces.setdefault(key, []).append(f.index)
    hubs = {w["bone"]: g2b(w["pos"]) for w in info.get("wheels", [])}
    name = os.path.basename(out_rel)
    objs = []
    body_ob = None
    for key, fidx in pieces.items():
        b2 = bm.copy()
        b2.faces.ensure_lookup_table()
        keepset = set(fidx)
        bmesh.ops.delete(b2, geom=[f for f in b2.faces if f.index not in keepset], context='FACES')
        loose = [v for v in b2.verts if not v.link_faces]
        bmesh.ops.delete(b2, geom=loose, context='VERTS')
        origin = V((0, 0, 0))
        if key.startswith("wheel_") and key in hubs:
            origin = hubs[key]
            # a flat tyre's hub sits lower than the manifest's: use the middle of the rim instead (x, y), keep hub z
            bmesh.ops.translate(b2, vec=-origin, verts=b2.verts)
        m2 = bpy.data.meshes.new(key)
        b2.to_mesh(m2); b2.free()
        for m in me.materials:
            m2.materials.append(m)
        if len(m2.color_attributes):
            m2.color_attributes.active_color = m2.color_attributes[0]
            m2.color_attributes.render_color_index = 0
        ob = bpy.data.objects.new(key if key != "body" else name + "_body", m2)
        bpy.context.scene.collection.objects.link(ob)
        ob.location = origin
        objs.append(ob)
        if key == "body":
            body_ob = ob
    bm.free()
    for k in sp.get("extras", []):
        for e in extras(k, info):
            e.parent = body_ob
            objs.append(e)
    if sp.get("collider"):
        lo, hi = info["aabb_lo"], info["aabb_hi"]
        c = box_obj(name + "-colonly", (lo[0], -hi[2], 0.15), (hi[0], -lo[2], hi[1] * 0.92), None)
        objs.append(c)
    # remove the import
    for o in list(bpy.context.scene.objects):
        if o not in objs:
            bpy.data.objects.remove(o, do_unlink=True)
    for o in objs:
        o.select_set(True)
    path = os.path.join(GODOT, "assets", out_rel + ".glb")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=False, export_yup=True,
                              export_texcoords=True, export_normals=True, export_tangents=False, export_materials='EXPORT',
                              export_vertex_color='ACTIVE', export_all_vertex_colors=False,
                              export_active_vertex_color_when_no_material=True, export_image_format='NONE',
                              export_animations=False, export_skins=False)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs if o.type == "MESH" and "-colonly" not in o.name)
    entry = {"file": "res://assets/%s.glb" % out_rel, "source": src, "what": sp.get("what", ""), "tris": tris,
             "size_m": [round(x, 2) for x in info["size"]], "origin": "ground under the middle of the vehicle",
             "forward": "-Z", "right": "+X", "wheels": sorted(k for k in pieces if k.startswith("wheel_")),
             "wheel_radius": info["wheels"][0]["radius"] if info.get("wheels") else None,
             "lamps": sorted(k for k in pieces if k.startswith("lamp_")), "materials": sorted({m.name for m in me.materials if m}),
             "plate": sp.get("plate", ""), "collider": bool(sp.get("collider")), "bytes": os.path.getsize(path),
             "lod": "one level (lane LOD%d); Godot generates mesh LODs on import" % sp["lod"]}
    print("ALIAS", out_rel, tris, "tris", entry["wheels"], entry["lamps"], "%.1f MB" % (entry["bytes"] / 1e6), flush=True)
    return entry


man_path = os.path.join(GODOT, "assets", "traffic", "manifest.json")
os.makedirs(os.path.dirname(man_path), exist_ok=True)
manifest = json.load(open(man_path)) if os.path.exists(man_path) else {}
for out_rel, sp in SPECS.items():
    if only and os.path.basename(out_rel) not in only:
        continue
    manifest[out_rel] = build(out_rel, sp)
    json.dump(manifest, open(man_path, "w"), indent=1, sort_keys=True)
print("DONE", len(manifest))

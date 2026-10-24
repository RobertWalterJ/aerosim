# AeroSim vehicle kit: build one vehicle from a recipe at three levels of detail, rig it, bake AO, export the .glb and
# return its manifest entry (sizes, bones, actions, wheels, triangle counts) for game/vehicle_manifest.gd.
import bpy, bmesh, math, os
from mathutils import Vector as V, Matrix
import vk_core, vk_body, vk_wheels, vk_details as det, vk_interior as inter, vk_assemble, vk_rig
from vk_core import Part, Surface, tri_count, set_material_colour, srgb_to_lin, clear_scene
from vk_body import BodySpec, section, R_SH, R_BELT, R_CANT, R_TOP, R_MID, R_SILL


def lin(c):
    return tuple(srgb_to_lin(x) for x in c[:3])


# ------------------------------------------------------------------ a car-type vehicle (lofted body)
def car_parts(rc, lod):
    s = BodySpec(**rc["body"])
    s.wheel_R = rc["wheel"]["R"]
    parts, surf_bm, B = vk_assemble.body_parts(s, lod, gaps=lod <= 1)
    surf = Surface(surf_bm)
    L = s.L
    info = {"spec": s, "body": B}
    d = rc.get("detail", {})
    # lamps, grille, plates
    if "head" in d:
        det.lamp_front(parts, surf, d["head"], lod)
    if "tail" in d:
        det.lamp_rear(parts, surf, d["tail"], lod, bone=d["tail"].get("bone", "body"))
        if d["tail"].get("bone2"):
            pass
    for t in d.get("tails_extra", []):
        det.lamp_rear(parts, surf, t, lod, bone=t.get("bone", "body"))
    if "grille" in d:
        det.grille(parts, surf, d["grille"], lod)
    for fp in d.get("front_panels", []):
        det.front_panel(parts, surf, fp[0], fp[1], fp[2], fp[3], fp[4], r=fp[5] if len(fp) > 5 else 0.02,
                        plane=fp[6] if len(fp) > 6 else 'front', bone=fp[7] if len(fp) > 7 else "body")
    if "plate_f" in d:
        det.plate(parts, surf, 'front', 0.0, d["plate_f"], lod=lod)
    if d.get("plate_r") is not None:
        det.plate(parts, surf, 'rear', d.get("plate_r_x", 0.0), d["plate_r"], bone=d.get("plate_r_bone", "body"), lod=lod)
    # handles on doors
    if lod <= 1:
        for (dd, z, bone_r, bone_l, mat) in d.get("handles", []):
            det.handle(parts, surf, 1, dd, z, L, bone_r, mat, lod)
            det.handle(parts, surf, -1, dd, z, L, bone_l, mat, lod)
    # livery bands and lettering ride on whichever panel they lie on (split at the door shuts)
    door_ranges = []
    for p in s.panels:
        if p["kind"] == "door":
            door_ranges.append((p["d0"], p["d1"], p["bone"]))

    def bone_at(dm, sx):
        for (a, b, bn) in door_ranges:
            if a <= dm <= b and sx in bn:
                return bn[sx]
        return "body"
    for st in d.get("strips", []):
        cuts = sorted(set([st["d0"], st["d1"]] + [x for (a, b, _) in door_ranges for x in (a, b) if st["d0"] < x < st["d1"]]))
        for sx in (1, -1):
            for a, b in zip(cuts[:-1], cuts[1:]):
                det.strip_side(parts, surf, sx, a + 0.004, b - 0.004, st["z"], st["h"], L, st["mat"], bone=bone_at((a + b) * 0.5, sx),
                               offset=st.get("off", 0.004))
    if "mirror" in d:
        md = d["mirror"]
        det.mirror(parts, s, 1, md["d"], md.get("bone_r", "door_fr"), lod, md.get("mat", "paint"))
        det.mirror(parts, s, -1, md["d"], md.get("bone_l", "door_fl"), lod, md.get("mat", "paint"))
    wiper_info = []
    if lod <= 1 and "wipers" in d:
        wiper_info = det.wipers(parts, surf, s, lod, **d["wipers"])
    if "exhaust" in d:
        det.exhaust(parts, s, d["exhaust"], lod, z=d.get("exhaust_z", 0.24))
    if "roof_rails" in d:
        det.roof_rails(parts, s, d["roof_rails"][0], d["roof_rails"][1], lod)
    if "lightbar" in d:
        det.lightbar(parts, s, d["lightbar"]["d"], lod, d["lightbar"].get("style", "modern"), d["lightbar"].get("w", 1.15))
    if "aerial" in d:
        a = d["aerial"]
        det.aerial(parts, s, a["d"], a.get("x", 0.0), lod, whip=a.get("whip", False))
    if lod == 0 and "badge" in d:
        b = d["badge"]
        det.badge_text(parts, surf, b["text"], b.get("plane", "rear"), b.get("x", 0.0), b["z"], b.get("size", 0.04),
                       bone=b.get("bone", "body"))
    for lt in d.get("lettering", []):
        if lod <= 1:
            for sx in (1, -1):
                pt = None
                for q in parts:
                    if q.name == "letters_" + lt.get("bone", "body") + str(sx):
                        pt = q
                bone = lt.get("bone", None) or bone_at(lt["d"], sx)
                if isinstance(bone, dict):
                    bone = bone[sx]
                pt = Part("letters", bone)
                vk_core.text_on_side(surf, lt["text"], sx, L * 0.5 - lt["d"], lt["z"], lt["size"], lt.get("mat", "lettering"), pt,
                                     offset=lt.get("off", 0.003))
                parts.append(pt)
    # interior
    wheel_c = None
    if "interior" in rc and lod <= 1:
        if rc["interior"].get("kind") == "bus":
            wheel_c = inter.bus_cabin(parts, s, rc["interior"], lod)
        else:
            wheel_c = inter.cabin(parts, s, rc["interior"], lod)
    elif "interior" in rc and lod == 2:
        pass
    # wheels
    w = rc["wheel"]
    tr = rc["track"]
    hubs = []
    for ai, d_ax in enumerate(rc["axles"]):
        steer = ai in rc.get("steer_axles", [0])
        tag = "f" if ai == 0 else ("r" if ai == len(rc["axles"]) - 1 else "m%d" % ai)
        dual = ai in rc.get("dual_axles", [])
        wsrc = rc.get("wheel_rear", w) if ai > 0 else w
        trk = rc.get("track_rear", tr) if ai > 0 else tr
        for side, sn in ((-1, "l"), (1, "r")):
            nm = tag + sn
            hub = (side * trk * 0.5, L * 0.5 - d_ax, wsrc["R"] + rc.get("hub_dz", 0.0))
            ws = dict(wsrc)
            if rc.get("flat_tyre") == nm:
                ws["flat"] = True
                hub = (hub[0], hub[1], hub[2] - ws.get("flat_drop", 0.07))
            if dual:
                # twin tyres: the outer wheel at the hub, the inner one a tyre width further in, both on the same bone
                vk_wheels.build_wheel(ws, side, lod, nm, (hub[0] + side * ws["tw"] * 0.55, hub[1], hub[2]), steer, parts=parts,
                                      caliper=False)
                wi = dict(ws); wi["inner"] = True
                vk_wheels.build_wheel(wi, -side, lod, nm + "2", (hub[0] - side * ws["tw"] * 0.55, hub[1], hub[2]), steer,
                                      parts=parts, caliper=False, bone="wheel_" + nm)
            else:
                vk_wheels.build_wheel(ws, side, lod, nm, hub, steer, parts=parts)
            hubs.append((nm, hub, steer))
    info["hubs"] = hubs
    info["wipers"] = wiper_info
    info["steering"] = wheel_c
    for extra in rc.get("extras", []):
        extra(parts, s, surf, lod, info)
    if info.get("aux_surf") and rc.get("tails_after_aux"):
        import bmesh as _bm
        allb = surf_bm.copy()
        for ab in info["aux_surf"]:
            allb2 = ab
            vm = {}
            ab.verts.index_update()
            for v in ab.verts:
                vm[v.index] = allb.verts.new(v.co)
            for f in ab.faces:
                try:
                    allb.faces.new([vm[v.index] for v in f.verts])
                except ValueError:
                    pass
        surf2 = Surface(allb)
        for t in rc["tails_after_aux"]:
            det.lamp_rear(parts, surf2, t, lod, bone=t.get("bone", "body"))
        if d.get("plate_r_aux") is not None:
            det.plate(parts, surf2, 'rear', 0.0, d["plate_r_aux"], bone="tailgate" if "tailgate_hinge" in info else "body", lod=lod)
    return parts, info


def car_bones(rc, info):
    s = info["spec"]
    L = s.L
    R = rc["wheel"]["R"]
    bones = [{"name": "root", "head": (0, 0, 0), "tail": (0, 0, 0.4)},
             {"name": "body", "head": (0, 0, R), "tail": (0, 0, R + 0.4), "parent": "root"}]
    for (nm, hub, steer) in info["hubs"]:
        if steer:
            bones.append({"name": "steer_" + nm, "head": hub, "tail": (hub[0], hub[1], hub[2] + 0.25), "parent": "root"})
            bones.append({"name": "wheel_" + nm, "head": hub, "tail": (hub[0] + 0.2, hub[1], hub[2]), "parent": "steer_" + nm})
        else:
            bones.append({"name": "wheel_" + nm, "head": hub, "tail": (hub[0] + 0.2, hub[1], hub[2]), "parent": "root"})
    hinges = {}
    for p in s.panels:
        if p["kind"] == "rear_doors":
            for sd in (1, -1):
                bn = p["bone"][sd]
                P = section(s, s.L - 0.02)
                x = sd * (P[R_SH][0] - 0.04)
                z = (P[R_SILL][1] + P[R_BELT][1]) * 0.5
                y = -L * 0.5 + 0.03
                bones.append({"name": bn, "head": (x, y, z), "tail": (x, y, z + 0.3), "parent": "body"})
                hinges[bn] = (sd, "rear", p.get("open", 95.0))
            continue
        if p["kind"] == "door":
            for sd in ([p["side"]] if "side" in p else (1, -1)):
                bn = p["bone"][sd]
                if p.get("flap"):
                    # a top-hinged hatch (the ice cream van's serving hatch): axis along the length at its top edge
                    P = section(s, (p["d0"] + p["d1"]) * 0.5)
                    zt = section(s, p["d0"])[p["r1"]][1]
                    x = sd * (P[R_SH][0] - 0.01)
                    ym = L * 0.5 - (p["d0"] + p["d1"]) * 0.5
                    bones.append({"name": bn, "head": (x, ym, zt), "tail": (x, ym + 0.3, zt), "parent": "body"})
                    hinges[bn] = (sd, "flap", p.get("open", 80.0))
                    continue
                if p.get("slide"):
                    P = section(s, p["d0"])
                    x = sd * (P[R_SH][0] - 0.03)
                    z = (P[R_SILL][1] + P[R_BELT][1]) * 0.5
                    bones.append({"name": bn, "head": (x, L * 0.5 - p["d0"], z), "tail": (x, L * 0.5 - p["d0"], z + 0.3), "parent": "body"})
                    hinges[bn] = (sd, "slide", p["d1"] - p["d0"])
                    continue
                hinge_d = p["d0"] if not p.get("rear_hinged") else p["d1"]
                P = section(s, hinge_d)
                x = sd * (P[R_SH][0] - 0.03)
                z = (P[R_SILL][1] + P[R_BELT][1]) * 0.5
                y = L * 0.5 - hinge_d
                bones.append({"name": bn, "head": (x, y, z), "tail": (x, y, z + 0.3), "parent": "body"})
                hinges[bn] = (sd, p.get("rear_hinged", False), p.get("open", 68.0))
        elif p["kind"] in ("lid", "tailgate"):
            bn = p["bone"]
            if bn == "bonnet":
                hd = p["d1"]
                P = section(s, hd)
                z = P[R_TOP][1] - 0.01
                y = L * 0.5 - hd
                bones.append({"name": bn, "head": (0, y, z), "tail": (0.3, y, z), "parent": "body"})
                hinges[bn] = (0, False, p.get("open", 55.0))
            else:
                hd = p["d0"]
                P = section(s, hd)
                z = P[R_TOP][1] - 0.01
                y = L * 0.5 - hd
                bones.append({"name": bn, "head": (0, y, z), "tail": (0.3, y, z), "parent": "body"})
                hinges[bn] = (0, True, p.get("open", 78.0))
    if info.get("destination"):
        p = info["destination"]
        bones.append({"name": "destination_board", "head": p, "tail": (p[0], p[1], p[2] + 0.2), "parent": "body"})
    if info.get("shutter"):
        x, y, z, travel = info["shutter"]
        bones.append({"name": "shutter", "head": (x, y, z), "tail": (x, y, z + 0.3), "parent": "body"})
        hinges["shutter"] = (0, "lift", travel)
    if info.get("valve"):
        x, y, z = info["valve"]
        bones.append({"name": "valve", "head": (x, y, z), "tail": (x, y - 0.15, z), "parent": "body"})
        hinges["valve"] = (0, "valve", 540.0)
    if info.get("serving"):
        x, y, z, half = info["serving"]
        bones.append({"name": "serving_window", "head": (x, y, z), "tail": (x, y, z + 0.3), "parent": "body"})
        hinges["serving_window"] = (0, "slide_y", -half * 0.92)
    if info.get("rear_door"):
        x, y, z = info["rear_door"]
        bones.append({"name": "door_rear", "head": (x, y, z), "tail": (x, y, z + 0.3), "parent": "body"})
        hinges["door_rear"] = (-1, "rear", 100.0)
    if info.get("tailgate_hinge"):
        hx, hy, hz = info["tailgate_hinge"]
        bones.append({"name": "tailgate", "head": (0, hy, hz), "tail": (0.3, hy, hz), "parent": "body"})
        hinges["tailgate"] = (0, False, 88.0)
    for (bn, pos, nrm) in info.get("wipers", []):
        n = V(nrm)
        bones.append({"name": bn, "head": pos, "tail": tuple(V(pos) + n * 0.15), "parent": "body"})
    if info.get("steering"):
        wc, ax = info["steering"]
        bones.append({"name": "steering_wheel", "head": tuple(wc), "tail": tuple(wc + ax * 0.15), "parent": "body"})
    for b in rc.get("bones_extra", []):
        bones.append(b)
    info["hinges"] = hinges
    return bones


def car_actions(rc, info):
    A = {}
    hinges = info.get("hinges", {})
    rad = math.radians
    side_doors = [b for b, h in hinges.items() if h[0] != 0 and h[1] in (False, True)]
    if side_doors:
        A["doors_open"] = {b: [(1, 0.0), (24, (1 if hinges[b][0] > 0 else -1) * rad(hinges[b][2]) * (-1 if hinges[b][1] is True else 1))] for b in side_doors}
        A["doors_close"] = {b: [(1, v[-1][1]), (24, 0.0)] for b, v in A["doors_open"].items()}
        drv = "door_fl" if "door_fl" in hinges else None
        if drv:
            A["door_driver_open"] = {drv: A["doors_open"][drv]}
            A["door_driver_close"] = {drv: A["doors_close"][drv]}
    rear = [b for b, h in hinges.items() if h[1] == "rear"]
    if rear:
        A["rear_doors_open"] = {b: [(1, 0.0), (30, (1 if hinges[b][0] > 0 else -1) * rad(hinges[b][2]))] for b in rear}
        A["rear_doors_close"] = {b: [(1, v[-1][1]), (30, 0.0)] for b, v in A["rear_doors_open"].items()}
    for b, h in hinges.items():
        if h[1] == "lift":
            A[b + "_open"] = {b: [(1, ('loc', (0, 0, 0))), (36, ('loc', (0, 0, h[2])))]}
            A[b + "_close"] = {b: [(1, ('loc', (0, 0, h[2]))), (36, ('loc', (0, 0, 0)))]}
        if h[1] == "slide_y":
            A[b + "_open"] = {b: [(1, ('loc', (0, 0, 0))), (30, ('loc', (0, h[2], 0)))]}
            A[b + "_close"] = {b: [(1, ('loc', (0, h[2], 0))), (30, ('loc', (0, 0, 0)))]}
        if h[1] == "valve":
            A["valve_open"] = {b: [(1, 0.0), (12, rad(h[2]) / 3), (24, rad(h[2]) * 2 / 3), (36, rad(h[2]))]}
            A["valve_close"] = {b: [(1, rad(h[2])), (12, rad(h[2]) * 2 / 3), (24, rad(h[2]) / 3), (36, 0.0)]}
        if h[1] == "flap":
            A[b + "_open"] = {b: [(1, 0.0), (30, -h[0] * rad(h[2]))]}
            A[b + "_close"] = {b: [(1, -h[0] * rad(h[2])), (30, 0.0)]}
    slide = [b for b, h in hinges.items() if h[1] == "slide"]
    for b in slide:
        sd, _, travel = hinges[b]
        A["slide_door_open"] = {b: [(1, ('loc', (0, 0, 0))), (8, ('loc', (sd * 0.07, 0, 0))), (30, ('loc', (sd * 0.085, -travel * 0.92, 0)))]}
        A["slide_door_close"] = {b: [(1, ('loc', (sd * 0.085, -travel * 0.92, 0))), (22, ('loc', (sd * 0.07, 0, 0))), (30, ('loc', (0, 0, 0)))]}
    for b in ("bonnet", "tailgate", "boot"):
        if b in hinges:
            sgn = -1 if hinges[b][1] else 1
            A[b + "_open"] = {b: [(1, 0.0), (30, sgn * rad(hinges[b][2]))]}
            A[b + "_close"] = {b: [(1, sgn * rad(hinges[b][2])), (30, 0.0)]}
    wb = [b for (b, _, _) in info.get("wipers", [])]
    if wb:
        A["wipers"] = {b: [(1, 0.0), (14, -rad(rc.get("wiper_sweep", 92))), (28, 0.0)] for b in wb}
    steer = [("steer_" + nm) for (nm, hub, st) in info["hubs"] if st]
    if steer:
        lock = rad(rc.get("lock", 33))
        for nm, sg in (("steer_left", 1), ("steer_right", -1)):
            k = {b: [(1, 0.0), (18, sg * lock)] for b in steer}
            if info.get("steering"):
                k["steering_wheel"] = [(1, 0.0), (6, -sg * rad(150)), (12, -sg * rad(300)), (18, -sg * rad(450))]
            A[nm] = k
    for nm, k in rc.get("actions_extra", {}).items():
        A[nm] = k
    for nm, src in rc.get("actions_alias", {}).items():
        if src in A:
            A[nm] = A[src]
    return A


# ------------------------------------------------------------------ build and export
def build(rc, out_dir, lods=(0, 1, 2), bake=True):
    clear_scene()
    name = rc["name"]
    for k in list(vk_core.MAT_DEFS.keys()):
        pass
    # paint colours (sRGB in the recipe)
    set_material_colour("paint", lin(rc.get("paint", (0.5, 0.5, 0.5))))
    if rc.get("paint2"):
        set_material_colour("paint2", lin(rc["paint2"]))
    for mname, col in rc.get("mat_colours", {}).items():
        set_material_colour(mname, lin(col))
    maker = rc.get("maker", car_parts)
    lod_obs = []
    info0 = None
    bones = None
    for lod in lods:
        parts, info = maker(rc, lod)
        if lod >= 2:
            # far level: drop the small pieces (under 30 cm across) that cannot be seen beyond 80 m; keep wheels and lamps
            def diag(p):
                if not p.bm.verts:
                    return 0.0
                lo = V((min(v.co.x for v in p.bm.verts), min(v.co.y for v in p.bm.verts), min(v.co.z for v in p.bm.verts)))
                hi = V((max(v.co.x for v in p.bm.verts), max(v.co.y for v in p.bm.verts), max(v.co.z for v in p.bm.verts)))
                return (hi - lo).length
            parts = [p for p in parts if p.bone.startswith("wheel_") or p.name == "lamps" or diag(p) > 0.3]
        sy = rc.get("shift_y", 0.0)
        if lod == lods[0]:
            info0 = info
            bones = rc.get("bones_fn", car_bones)(rc, info)
            if sy:
                # the body was built about its own middle (a pickup's cab): move everything to the vehicle's middle
                for b in bones:
                    b["head"] = (b["head"][0], b["head"][1] + sy, b["head"][2])
                    b["tail"] = (b["tail"][0], b["tail"][1] + sy, b["tail"][2])
                info["hubs"] = [(nm, (h[0], h[1] + sy, h[2]), st) for (nm, h, st) in info["hubs"]]
        if sy:
            for p in parts:
                bmesh.ops.translate(p.bm, vec=(0, sy, 0), verts=p.bm.verts)
        names = [b["name"] for b in bones]
        for p in parts:
            if p.bone not in names:
                p.bone = "body"
        if lod == 0:
            info["checks"] = part_checks(parts)
            agg = {}
            for p in parts:
                n = sum(len(f.verts) - 2 for f in p.bm.faces)
                key = p.name.split("_")[0]
                agg[key] = agg.get(key, 0) + n
            print("TRIS parts", sorted(agg.items(), key=lambda x: -x[1]))
        ob = vk_rig.merge_parts("%s_LOD%d" % (name, lod), parts, names)
        if lod > 0 and lod_obs:
            # if the rebuilt lower level is still too heavy, collapse-decimate it to its share of LOD0 (35 % and 8 %)
            target = {1: 0.35, 2: 0.08}[lod] * tri_count(lod_obs[0])
            have = tri_count(ob)
            if have > target * 1.12:
                mod = ob.modifiers.new("dec", 'DECIMATE')
                mod.decimate_type = 'COLLAPSE'
                mod.ratio = max(0.05, target / have)
                mod.use_collapse_triangulate = True
                dg = bpy.context.evaluated_depsgraph_get()
                nme = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
                ob.modifiers.clear()
                old = ob.data
                ob.data = nme
                bpy.data.meshes.remove(old)
        for p in parts:
            p.bm.free()
        lod_obs.append(ob)
    # bake AO one level at a time (the others hidden)
    if bake:
        for ob in lod_obs:
            for o in lod_obs:
                o.hide_render = o is not ob
            vk_rig.bake_ao([ob], distance=rc.get("ao_dist", 0.45), samples=32)
        for o in lod_obs:
            o.hide_render = False
    cond = rc.get("condition")
    for ob in lod_obs:
        if cond:
            vk_rig.set_condition(ob, cond)
    arm = vk_rig.armature(name, bones)
    for ob in lod_obs:
        vk_rig.bind(ob, arm)
    acts = rc.get("actions_fn", car_actions)(rc, info0)
    for an, keys in acts.items():
        vk_rig.add_action(arm, an, keys)
    path = os.path.join(out_dir, name + ".glb")
    vk_rig.export_glb(path, arm, lod_obs)
    # manifest
    lo = V((1e9, 1e9, 1e9)); hi = -lo
    for v in lod_obs[0].data.vertices:
        lo = V((min(lo.x, v.co.x), min(lo.y, v.co.y), min(lo.z, v.co.z)))
        hi = V((max(hi.x, v.co.x), max(hi.y, v.co.y), max(hi.z, v.co.z)))
    man = {
        "file": name + ".glb",
        "tris": [tri_count(o) for o in lod_obs],
        # in the game frame: x right, y up, z back (front is -z)
        "size": (round(hi.x - lo.x, 3), round(hi.z - lo.z, 3), round(hi.y - lo.y, 3)),
        "aabb_lo": (round(lo.x, 3), round(lo.z, 3), round(-hi.y, 3)),
        "aabb_hi": (round(hi.x, 3), round(hi.z, 3), round(-lo.y, 3)),
        "bones": [b["name"] for b in bones],
        "actions": list(acts.keys()),
        "wheels": [{"bone": "wheel_" + nm, "pos": (round(h[0], 4), round(h[2], 4), round(-h[1], 4)),
                    "radius": rc["wheel"]["R"] if not rc.get("wheel_r_of") else rc["wheel_r_of"](nm), "steer": st}
                   for (nm, h, st) in info0["hubs"]],
        "paint": tuple(rc.get("paint", (0.5, 0.5, 0.5))),
        "paint2": tuple(rc.get("paint2", (0.8, 0.8, 0.78))) if rc.get("paint2") else None,
        "materials": sorted(set(m.name for o in lod_obs for m in o.data.materials)),
        "hinges": {k: v[2] for k, v in info0.get("hinges", {}).items()},
        "kind": rc.get("kind", "car"),
        "checks": info0.get("checks", {}),
        "dirt": rc.get("dirt", 0.35),
        "pose": rc.get("pose", ""),
        "colliders": rc.get("colliders_fn", default_colliders)(lo, hi),
    }
    return man


def part_checks(parts):
    """Defect checks made on the parts before they are merged: floating parts (a part whose box is more than 3 cm from every
    other part's box), and paint that faces inward (the share of painted area whose normal points toward the vehicle's
    centre line rather than away from it). The test fails on either."""
    boxes = []
    for p in parts:
        if not p.bm.verts:
            continue
        lo = V((min(v.co.x for v in p.bm.verts), min(v.co.y for v in p.bm.verts), min(v.co.z for v in p.bm.verts)))
        hi = V((max(v.co.x for v in p.bm.verts), max(v.co.y for v in p.bm.verts), max(v.co.z for v in p.bm.verts)))
        boxes.append((p.name, lo, hi))
    floating = []
    for i, (n, lo, hi) in enumerate(boxes):
        best = 1e9
        for j, (n2, lo2, hi2) in enumerate(boxes):
            if i == j:
                continue
            gap = max(0.0, lo2.x - hi.x, lo.x - hi2.x, lo2.y - hi.y, lo.y - hi2.y, lo2.z - hi.z, lo.z - hi2.z)
            best = min(best, gap)
        if best > 0.03 and len(boxes) > 1:
            floating.append(n)
    # paint orientation: compare each painted face's normal with the direction from the centre line (x = 0, z = mid height)
    zmid = 0.5 * (min(b[1].z for b in boxes) + max(b[2].z for b in boxes)) if boxes else 0.8
    out_a = in_a = 0.0
    for p in parts:
        if "paint" not in p.mats:
            continue
        pi = p.mats.index("paint")
        p.bm.normal_update()
        for f in p.bm.faces:
            if f.material_index != pi:
                continue
            c = f.calc_center_median()
            r = V((c.x, 0.0, c.z - zmid))
            if r.length < 0.25:
                continue
            a = f.calc_area()
            if f.normal.dot(r.normalized()) >= -0.2:
                out_a += a
            else:
                in_a += a
    # inside-out pieces: every closed piece (each connected group of faces that is watertight) must enclose a positive volume
    inside_out = []
    for p in parts:
        bm = p.bm
        seen = set()
        for f0 in bm.faces:
            if f0 in seen:
                continue
            stack = [f0]; seen.add(f0); grp = []
            while stack:
                f = stack.pop(); grp.append(f)
                for e in f.edges:
                    for g in e.link_faces:
                        if g not in seen:
                            seen.add(g); stack.append(g)
            edges = set(e for f in grp for e in f.edges)
            if any(len(e.link_faces) != 2 for e in edges) or len(grp) < 4:
                continue
            vol = 0.0
            for f in grp:
                vs = [v.co for v in f.verts]
                for k in range(1, len(vs) - 1):
                    vol += vs[0].dot(vs[k].cross(vs[k + 1])) / 6.0
            if vol < -1e-7:
                inside_out.append(p.name)
                break
    return {"floating": floating, "paint_outward": round(out_a / max(out_a + in_a, 1e-9), 3), "inside_out": sorted(set(inside_out))}


def default_colliders(lo, hi):
    # one box for the lower body and one inset box for the cabin, in the game frame (x, y up, z back)
    zlo, zhi = -hi.y, -lo.y
    h = hi.z
    return [[(round(lo.x, 3), 0.18, round(zlo, 3)), (round(hi.x, 3), round(h * 0.62, 3), round(zhi, 3))],
            [(round(lo.x * 0.85, 3), round(h * 0.62, 3), round(zlo * 0.6, 3)), (round(hi.x * 0.85, 3), round(h, 3), round(zhi * 0.6, 3))]]

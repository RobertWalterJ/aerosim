# Blender helpers for the AeroSim animals: mesh creation from arrays, clay previews, cleanup.
import bpy, bmesh
import numpy as np
import math, os
from mathutils import Vector, Matrix

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def mesh_from_arrays(name, pts, tris, quads, coll=None):
    me = bpy.data.meshes.new(name)
    faces = [tuple(int(i) for i in f) for f in quads] + [tuple(int(i) for i in f) for f in tris]
    me.from_pydata([tuple(p) for p in pts], [], faces)
    me.validate()
    ob = bpy.data.objects.new(name, me)
    (coll or bpy.context.scene.collection).objects.link(ob)
    clean(ob)
    return ob

def clean(ob, dist=0.0004):
    """Merge near-duplicate vertices and dissolve degenerate faces (QuadriFlow refuses edges under 0.1 mm), drop tiny
    loose pieces, make the normals consistent."""
    me = ob.data
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=dist)
    bmesh.ops.dissolve_degenerate(bm, dist=dist, edges=bm.edges[:])
    # pieces of less than 0.5 per cent of the surface (slivers left by carving) go
    seen = set(); kill = []
    total = len(bm.faces)
    for f in bm.faces:
        if f in seen: continue
        st = [f]; comp = []; seen.add(f)
        while st:
            g = st.pop(); comp.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h not in seen: seen.add(h); st.append(h)
        if len(comp) < total * 0.005:
            kill.extend(comp)
    if kill:
        bmesh.ops.delete(bm, geom=list({v for f in kill for v in f.verts}), context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = True
    me.update()
    make_outward(ob)

def signed_volume(me):
    v = np.zeros(len(me.vertices) * 3); me.vertices.foreach_get("co", v); v = v.reshape(-1, 3)
    me.calc_loop_triangles()
    t = np.zeros(len(me.loop_triangles) * 3, dtype=np.int64); me.loop_triangles.foreach_get("vertices", t); t = t.reshape(-1, 3)
    a, b, c = v[t[:, 0]], v[t[:, 1]], v[t[:, 2]]
    return float(np.einsum("ij,ij->i", a, np.cross(b, c)).sum() / 6.0)

def make_outward(ob):
    """Every closed animal surface must enclose positive volume: if it is inside out, flip it."""
    me = ob.data
    if len(me.polygons) and signed_volume(me) < 0:
        me.flip_normals()
        me.update()
        print("[animal] flipped inside-out mesh", ob.name)

def set_active(ob):
    for o in bpy.context.scene.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)

def tri_count(ob):
    me = ob.data
    return sum(len(p.vertices) - 2 for p in me.polygons)

def clay_material():
    m = bpy.data.materials.get("clay") or bpy.data.materials.new("clay")
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (0.55, 0.5, 0.45, 1)
    b.inputs["Roughness"].default_value = 0.6
    return m

def render_views(objs, out_path, views=None, res=(560, 420), engine="BLENDER_EEVEE_NEXT", clay=True, sun_rot=(50, 0, 140), sun_energy=4.0, world=0.6):
    """Renders each object set from several directions (side, front three-quarter, front, rear three-quarter, top) and
    saves one strip image. The camera frames the bounding box."""
    scn = bpy.context.scene
    scn.render.engine = engine
    scn.render.resolution_x, scn.render.resolution_y = res
    scn.render.film_transparent = False
    if engine == "CYCLES":
        scn.cycles.samples = 24; scn.cycles.device = "CPU"
    if scn.world is None:
        scn.world = bpy.data.worlds.new("w")
    scn.world.use_nodes = True
    bg = scn.world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.62, 0.68, 0.75, 1); bg.inputs["Strength"].default_value = world
    sun = bpy.data.objects.get("prev_sun")
    if sun is None:
        ld = bpy.data.lights.new("prev_sun", "SUN"); ld.energy = sun_energy; ld.angle = math.radians(3)
        sun = bpy.data.objects.new("prev_sun", ld); scn.collection.objects.link(sun)
    sun.rotation_euler = [math.radians(a) for a in sun_rot]
    if clay:
        cm = clay_material()
        for o in objs:
            if o.type == "MESH":
                o.data.materials.clear(); o.data.materials.append(cm)
    # bounds
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    ctr = (lo + hi) / 2; rad = (hi - lo).length / 2
    cd = bpy.data.cameras.new("prev_cam"); cd.lens = 50
    cam = bpy.data.objects.new("prev_cam", cd); scn.collection.objects.link(cam); scn.camera = cam
    views = views or [("side", (1, 0, 0.12)), ("3/4 front", (0.8, -1.0, 0.35)), ("front", (0, -1, 0.15)), ("3/4 rear", (-0.8, 1.0, 0.4)), ("head", None)]
    imgs = []
    for name, d in views:
        if d is None:
            continue
        dv = Vector(d).normalized()
        fov = cd.angle
        dist = rad / math.sin(fov / 2) * 0.9
        cam.location = ctr + dv * dist
        cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
        cd.clip_start = dist * 0.01; cd.clip_end = dist * 10
        p = out_path.replace(".png", "_%s.png" % name.replace("/", "").replace(" ", ""))
        scn.render.filepath = p
        bpy.ops.render.render(write_still=True)
        imgs.append(p)
    bpy.data.objects.remove(cam)
    return imgs

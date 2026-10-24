# The AeroSim animal pipeline (Blender 4.2, headless): sculpt -> game mesh -> UVs -> baked PBR textures -> armature and
# weights -> baked animation clips -> LODs -> glTF 2.0 (.glb).
#
#   blender -b --python build_animal.py -- name=cow_a [vox=0.005] [tex=2048] [out=<dir>]
#
# Everything here is deterministic: the same species definition gives the same file.
import bpy, bmesh
import numpy as np
import math, os, time
from mathutils import Vector, Matrix, Quaternion, Euler
import sdf, blib

CACHE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "..", "_tools", "blender-cache"))

def log(*a):
    print("[animal]", *a, flush=True)

# ------------------------------------------------------------------ colour helpers
def srgb_to_lin(c):
    c = np.asarray(c, float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)

# ------------------------------------------------------------------ 1. sculpt and painted attributes
def build_sculpt(spec, vox):
    t = time.time()
    F = spec.field(vox)
    pts, tris, quads = F.mesh()
    log("sculpt field", F.n, "verts", len(pts), "%.1fs" % (time.time() - t))
    hi = blib.mesh_from_arrays(spec.name + "_hi", pts, tris, quads)
    me = hi.data
    P = np.zeros(len(me.vertices) * 3); me.vertices.foreach_get("co", P); P = P.reshape(-1, 3)
    tags = sdf.nearest_tags(F.ops, P)
    nrm = np.zeros(len(me.vertices) * 3); me.vertices.foreach_get("normal", nrm); nrm = nrm.reshape(-1, 3)
    col, rough = spec.paint(P, nrm, tags)
    lin = srgb_to_lin(np.clip(col, 0, 1))
    a = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    rgba = np.concatenate([lin, np.ones((len(P), 1))], axis=1).astype(np.float32)
    a.data.foreach_set("color", rgba.ravel())
    r = me.attributes.new("Rgh", "FLOAT", "POINT")
    r.data.foreach_set("value", np.clip(rough, 0.02, 1).astype(np.float32))
    fa = me.attributes.new("Fur", "FLOAT", "POINT")         # how much fur (the fur shader's vertex alpha): 1 coat, 0.07 bare skin, 0 hoof
    fa.data.foreach_set("value", np.clip(spec.fur_amount(P, tags), 0, 1).astype(np.float32))
    d = me.attributes.new("Det", "FLOAT", "POINT")          # which photographed detail set: 0 coat, 1 wool, 2 leather (bare skin)
    d.data.foreach_set("value", spec.detail_kind(P, tags).astype(np.float32))
    spec._field = F
    return hi

# ------------------------------------------------------------------ 2. game mesh
def make_lowpoly(hi, name, target_tris, symmetric=True, field=None):
    """QuadriFlow quad remesh of the sculpt (all quads, even spacing, symmetric), run on a coarser meshing of the same
    field so it is quick, then projected back onto the full sculpt."""
    if field is not None:
        import pyopenvdb as vdb
        d = field.d[::2, ::2, ::2].copy()
        g = vdb.FloatGrid(1.0); g.copyFromArray(d)
        pts, tris, quads = g.convertToPolygons(isovalue=0.0, adaptivity=0.0)
        pts = np.asarray(pts, dtype=np.float64) * field.vox * 2 + field.lo
        lo = blib.mesh_from_arrays(name, pts, np.asarray(tris), np.asarray(quads))

    else:
        lo = hi.copy(); lo.data = hi.data.copy(); lo.name = name
        bpy.context.scene.collection.objects.link(lo)
    blib.set_active(lo)
    ok = False
    t = blib.tri_count(lo)
    # QuadriFlow runs in a child Blender (it can crash on some inputs); tries: as is, then voxel-remeshed (it refuses
    # hair-thin features), with different seeds
    import subprocess, tempfile
    tmp = tempfile.mkdtemp(prefix="qf_")
    src = os.path.join(tmp, "in.obj")
    blib.set_active(lo)
    bpy.ops.wm.obj_export(filepath=src, export_selected_objects=True, export_materials=False, export_uv=False, export_normals=False,
                          forward_axis="Y", up_axis="Z")
    vox = field.vox if field is not None else 0.005
    for k, (seed, vv) in enumerate(((7, 0.0), (3, vox * 2.5), (11, vox * 3.2), (5, vox * 4.0))):
        dst = os.path.join(tmp, "out%d.obj" % k)
        try:
            r = subprocess.run([bpy.app.binary_path, "-b", "--python", os.path.join(os.path.dirname(os.path.abspath(__file__)), "qf_child.py"),
                                "--", src, dst, str(int(target_tris / 2)), str(seed), str(vv)], capture_output=True, text=True, timeout=900)
            line = [l for l in r.stdout.splitlines() if l.startswith("QFCHILD")]
            log("quadriflow try", k, "seed", seed, "voxel", round(vv, 4), line[0] if line else "crashed (exit %d)" % r.returncode)
        except Exception as e:
            log("quadriflow try", k, "failed:", e)
            continue
        if os.path.exists(dst):
            before = set(bpy.data.objects)
            bpy.ops.wm.obj_import(filepath=dst, forward_axis="Y", up_axis="Z")
            new = [o for o in bpy.data.objects if o not in before][0]
            tn = blib.tri_count(new)
            if target_tris * 0.5 <= tn <= target_tris * 1.6:
                old = lo.data
                lo.data = new.data
                bpy.data.objects.remove(new)
                bpy.data.meshes.remove(old)
                ok = True; t = tn
                break
            bpy.data.objects.remove(new)
    blib.set_active(lo)
    if not ok or t < target_tris * 0.5 or t > target_tris * 1.6:
        log("quadriflow gave", t, "tris; falling back to decimate")
        m = lo.modifiers.new("dec", "DECIMATE"); m.ratio = target_tris / blib.tri_count(lo); m.use_symmetry = symmetric; m.symmetry_axis = "X"
        bpy.ops.object.modifier_apply(modifier="dec")
    # project back onto the sculpt (quadriflow smooths a little)
    sw = lo.modifiers.new("sw", "SHRINKWRAP"); sw.target = hi; sw.wrap_method = "NEAREST_SURFACEPOINT"
    bpy.ops.object.modifier_apply(modifier="sw")
    for a in list(lo.data.attributes):
        if a.name in ("Col", "Rgh", "Det"):
            try: lo.data.attributes.remove(a)
            except Exception: pass
    for p in lo.data.polygons: p.use_smooth = True
    blib.make_outward(lo)
    log("game mesh", name, blib.tri_count(lo), "tris", "volume %.4f m3" % blib.signed_volume(lo.data))
    return lo

def fur_to_vertex_colour(hi, lo):
    """Vertex colour (1, 1, 1, fur) on the game mesh, from the nearest sculpt vertex: the fur shader reads the alpha."""
    from mathutils.kdtree import KDTree
    hv = hi.data.vertices
    kd = KDTree(len(hv))
    for v in hv: kd.insert(v.co, v.index)
    kd.balance()
    fur = np.zeros(len(hv), np.float32); hi.data.attributes["Fur"].data.foreach_get("value", fur)
    me = lo.data
    for a in list(me.color_attributes): me.color_attributes.remove(a)
    ca = me.color_attributes.new("Col", "BYTE_COLOR", "POINT")
    rgba = np.ones((len(me.vertices), 4), np.float32)
    for v in me.vertices:
        co, i, d = kd.find(v.co)
        rgba[v.index, 3] = fur[i]
    ca.data.foreach_set("color", rgba.ravel())
    me.color_attributes.active_color = ca
    me.color_attributes.render_color_index = 0

def uv_metres(ob):
    """Metres of hide per unit of UV (the fur shader lays its strands out in UV space with this)."""
    me = ob.data
    uv = me.uv_layers.active.data
    a3 = 0.0; a2 = 0.0
    for p in me.polygons:
        a3 += p.area
        li = list(p.loop_indices)
        u = [uv[i].uv for i in li]
        s2 = 0.0
        for k in range(1, len(u) - 1):
            s2 += abs((u[k].x - u[0].x) * (u[k + 1].y - u[0].y) - (u[k + 1].x - u[0].x) * (u[k].y - u[0].y)) / 2
        a2 += s2
    return math.sqrt(a3 / max(a2, 1e-9))

def uv_unwrap(ob, margin=0.004):
    blib.set_active(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=margin, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.pack_islands(margin=margin, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")

# ------------------------------------------------------------------ 3. bake
def _img(name, size, data=False, alpha=False):
    im = bpy.data.images.get(name)
    if im: bpy.data.images.remove(im)
    im = bpy.data.images.new(name, size, size, alpha=alpha, float_buffer=False, is_data=data)
    if data: im.colorspace_settings.name = "Non-Color"
    return im

def _load(path, data=False):
    im = bpy.data.images.load(path, check_existing=True)
    if data: im.colorspace_settings.name = "Non-Color"
    return im

DETAIL_SETS = {
    # key: (poly haven id, tile size in metres, strength of the albedo variation, normal strength)
    "coat": ("velour_velvet", 0.10, 0.10, 0.35),
    "wool": ("curly_teddy_natural", 0.12, 0.35, 1.0),
    "skin": ("brown_leather", 0.10, 0.25, 0.6),
    "fleece": ("polar_fleece", 0.08, 0.12, 0.5),
}

def _detail_nodes(nt, key, coord):
    pid, tile, kc, kn = DETAIL_SETS[key]
    base = os.path.join(CACHE, "polyhaven", pid)
    nodes = nt.nodes
    mp = nodes.new("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (1 / tile,) * 3
    nt.links.new(coord.outputs["Object"], mp.inputs["Vector"])
    td = nodes.new("ShaderNodeTexImage"); td.image = _load(base + "_diff.jpg"); td.projection = "BOX"; td.projection_blend = 0.3
    tn = nodes.new("ShaderNodeTexImage"); tn.image = _load(base + "_nor.jpg", True); tn.projection = "BOX"; tn.projection_blend = 0.3
    nt.links.new(mp.outputs["Vector"], td.inputs["Vector"]); nt.links.new(mp.outputs["Vector"], tn.inputs["Vector"])
    bw = nodes.new("ShaderNodeRGBToBW"); nt.links.new(td.outputs["Color"], bw.inputs["Color"])
    # factor = 1 + kc * (bw / mean - 1)
    mean = float(np.mean(np.asarray(td.image.pixels[:]).reshape(-1, 4)[:, :3] @ [0.2126, 0.7152, 0.0722]))
    m1 = nodes.new("ShaderNodeMath"); m1.operation = "MULTIPLY_ADD"; m1.inputs[1].default_value = kc / max(mean, 1e-3); m1.inputs[2].default_value = 1 - kc
    nt.links.new(bw.outputs["Val"], m1.inputs[0])
    nm = nodes.new("ShaderNodeNormalMap"); nm.inputs["Strength"].default_value = kn
    nt.links.new(tn.outputs["Color"], nm.inputs["Color"])
    return m1, nm

def bake_material(spec):
    """Material on the sculpt for baking: painted colour and roughness from attributes, times a photographed detail set
    chosen per vertex (coat, wool or bare skin)."""
    m = bpy.data.materials.new(spec.name + "_bake")
    m.use_nodes = True
    nt = m.node_tree; nodes = nt.nodes
    bsdf = nodes.get("Principled BSDF")
    coord = nodes.new("ShaderNodeTexCoord")
    ca = nodes.new("ShaderNodeAttribute"); ca.attribute_name = "Col"
    ra = nodes.new("ShaderNodeAttribute"); ra.attribute_name = "Rgh"
    da = nodes.new("ShaderNodeAttribute"); da.attribute_name = "Det"
    keys = spec.detail_keys
    facs = []; nms = []
    for k in keys:
        f, n = _detail_nodes(nt, k, coord); facs.append(f); nms.append(n)
    # pick by Det: 0, 1, 2 -> keys[0], keys[1], keys[2] with soft blends
    def pick(outs, sock_type):
        cur = outs[0]
        for i in range(1, len(outs)):
            mr = nodes.new("ShaderNodeMapRange"); mr.inputs["From Min"].default_value = i - 0.5; mr.inputs["From Max"].default_value = i - 0.5 + 0.2
            nt.links.new(da.outputs["Fac"], mr.inputs["Value"])
            mx = nodes.new("ShaderNodeMix"); mx.data_type = sock_type
            nt.links.new(mr.outputs["Result"], mx.inputs["Factor"])
            if sock_type == "FLOAT":
                nt.links.new(cur, mx.inputs[2]); nt.links.new(outs[i], mx.inputs[3]); cur = mx.outputs[0]
            else:
                nt.links.new(cur, mx.inputs[6]); nt.links.new(outs[i], mx.inputs[7]); cur = mx.outputs[2]
        return cur
    fac = pick([f.outputs["Value"] for f in facs], "FLOAT")
    nrm = pick([n.outputs["Normal"] for n in nms], "VECTOR")
    mul = nodes.new("ShaderNodeMix"); mul.data_type = "RGBA"; mul.blend_type = "MULTIPLY"; mul.inputs["Factor"].default_value = 1.0
    nt.links.new(ca.outputs["Color"], mul.inputs[6])
    cv = nodes.new("ShaderNodeCombineColor"); nt.links.new(fac, cv.inputs[0]); nt.links.new(fac, cv.inputs[1]); nt.links.new(fac, cv.inputs[2])
    nt.links.new(cv.outputs["Color"], mul.inputs[7])
    nt.links.new(mul.outputs[2], bsdf.inputs["Base Color"])
    # roughness varies a little with the detail too
    rr = nodes.new("ShaderNodeMath"); rr.operation = "MULTIPLY"
    nt.links.new(ra.outputs["Fac"], rr.inputs[0]); nt.links.new(fac, rr.inputs[1])
    rc = nodes.new("ShaderNodeClamp"); nt.links.new(rr.outputs["Value"], rc.inputs["Value"])
    nt.links.new(rc.outputs["Result"], bsdf.inputs["Roughness"])
    nt.links.new(nrm, bsdf.inputs["Normal"])
    bsdf.inputs["Metallic"].default_value = 0.0
    return m

def bake_maps(spec, hi, lo, size, out_dir, cage=0.02):
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.cycles.samples = 8
    scn.render.bake.use_selected_to_active = True
    scn.render.bake.cage_extrusion = cage
    scn.render.bake.max_ray_distance = cage * 3
    scn.render.bake.margin = 12
    scn.render.bake.margin_type = "EXTEND"
    hi.data.materials.clear(); hi.data.materials.append(bake_material(spec))
    lo.data.materials.clear()
    target = bpy.data.materials.new(spec.name + "_target"); target.use_nodes = True
    lo.data.materials.append(target)
    tn = target.node_tree.nodes.new("ShaderNodeTexImage")
    target.node_tree.nodes.active = tn
    for o in bpy.context.scene.objects: o.select_set(False)
    hi.select_set(True); lo.select_set(True); bpy.context.view_layer.objects.active = lo
    res = {}
    t = time.time()
    # (occlusion is not baked: a Cycles AO bake on these smart-projected UVs came out as noise; the game's own SSAO and the
    # fur shader's shell occlusion do that job, so the ORM red channel is 1)
    for kind, btype, data in (("albedo", "DIFFUSE", False), ("rough", "ROUGHNESS", True), ("normal", "NORMAL", True)):
        im = _img(spec.name + "_" + kind, size, data=data)
        tn.image = im
        kw = {}
        if btype == "DIFFUSE":
            scn.render.bake.use_pass_direct = False; scn.render.bake.use_pass_indirect = False; scn.render.bake.use_pass_color = True
        if btype == "AO":
            # occlusion is soft: bake it small and quick, it is scaled up when the maps are written
            im = _img(spec.name + "_" + kind, max(size // 4, 256), data=True); tn.image = im
            scn.cycles.samples = 16
            # AO is baked on the game mesh itself (the body occludes the inside of the legs, the belly, the ears)
            scn.render.bake.use_selected_to_active = False
            hi.select_set(False)
        bpy.ops.object.bake(type=btype, normal_space="TANGENT")
        scn.render.bake.use_selected_to_active = True; hi.select_set(True); scn.cycles.samples = 8
        res[kind] = im
        log("baked", kind, "%.1fs" % (time.time() - t))
    return res, target

def _pixels(im):
    return np.asarray(im.pixels[:], dtype=np.float32).reshape(im.size[1], im.size[0], 4)

def write_textures(spec, maps, out_dir, size_out):
    """albedo (sRGB jpg), normal (OpenGL, jpg), orm (r occlusion, g roughness, b metal = 0)."""
    os.makedirs(out_dir, exist_ok=True)
    paths = {}
    alb = maps["albedo"]
    def save(arr, name, colorspace, key=None):
        im = bpy.data.images.new(name, arr.shape[1], arr.shape[0], alpha=False, is_data=(colorspace != "sRGB"))
        if colorspace != "sRGB": im.colorspace_settings.name = "Non-Color"
        im.pixels.foreach_set(arr.astype(np.float32).ravel())
        if arr.shape[0] != size_out: im.scale(size_out, size_out)
        p = os.path.join(out_dir, name + ".jpg")
        im.filepath_raw = p; im.file_format = "JPEG"
        bpy.context.scene.render.image_settings.quality = 92
        im.save()
        im2 = bpy.data.images.load(p); im2.name = name.split("_")[-1]       # "albedo", "normal", "orm": Godot names the extracted file <animal>_<this>
        if colorspace != "sRGB": im2.colorspace_settings.name = "Non-Color"
        bpy.data.images.remove(im)
        return im2
    # albedo: Blender stores the byte image as sRGB already
    a = _pixels(alb)
    paths["albedo"] = save(a, spec.name + "_albedo", "sRGB")
    r = _pixels(maps["rough"])
    ao = np.ones_like(r[..., 0])
    orm = np.stack([ao, r[..., 0], np.zeros_like(ao), np.ones_like(ao)], axis=-1)
    paths["orm"] = save(orm, spec.name + "_orm", "data")
    n = _pixels(maps["normal"])
    paths["normal"] = save(n, spec.name + "_normal", "data")
    return paths

def game_material(spec, tex):
    m = bpy.data.materials.new(spec.mat_name)
    m.use_nodes = True
    nt = m.node_tree; nodes = nt.nodes
    b = nodes.get("Principled BSDF")
    ta = nodes.new("ShaderNodeTexImage"); ta.image = tex["albedo"]
    nt.links.new(ta.outputs["Color"], b.inputs["Base Color"])
    to = nodes.new("ShaderNodeTexImage"); to.image = tex["orm"]
    sp = nodes.new("ShaderNodeSeparateColor"); nt.links.new(to.outputs["Color"], sp.inputs["Color"])
    nt.links.new(sp.outputs["Green"], b.inputs["Roughness"]); nt.links.new(sp.outputs["Blue"], b.inputs["Metallic"])
    tn = nodes.new("ShaderNodeTexImage"); tn.image = tex["normal"]
    nm = nodes.new("ShaderNodeNormalMap"); nt.links.new(tn.outputs["Color"], nm.inputs["Color"]); nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    # occlusion for the glTF exporter
    g = bpy.data.node_groups.get("glTF Material Output")
    if g is None:
        g = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
        g.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
    gn = nodes.new("ShaderNodeGroup"); gn.node_tree = g
    nt.links.new(sp.outputs["Red"], gn.inputs["Occlusion"])
    b.inputs["Specular IOR Level"].default_value = 0.5
    return m

# ------------------------------------------------------------------ 4. eyes and eyelids
def eye_texture(kind, size=256, iris=(0.20, 0.12, 0.06)):
    """Eyeball albedo: dark iris and a pupil (horizontal bar for grazing animals, round for dogs and hens), on an
    equirectangular map of the eyeball whose +Y (front of the eye) maps to the middle."""
    h = size // 2
    v, u = np.mgrid[0:h, 0:size].astype(float)
    lon = (u / size) * 2 * math.pi - math.pi
    lat = (v / h) * math.pi - math.pi / 2
    # direction on the sphere; the eye looks along local -z (the uv sphere's pole) after we orient it; we use the pole
    x = np.cos(lat) * np.cos(lon); y = np.cos(lat) * np.sin(lon); z = np.sin(lat)
    ang = np.arccos(np.clip(z, -1, 1))            # angle from the +z pole
    col = np.ones((h, size, 3)) * np.array([0.82, 0.78, 0.72])        # sclera (rarely seen)
    ir = np.array(iris)
    ri = 1.1                                     # iris angular radius (what shows of the eye is nearly all iris)
    mix = np.clip((ri - ang) / 0.06, 0, 1)[..., None]
    # iris texture: radial streaks
    streak = 0.85 + 0.15 * np.sin(lon * 40.0)[..., None]
    col = col * (1 - mix) + ir * streak * mix
    # pupil
    if kind == "bar":
        px, py = np.sin(ang) * np.cos(lon), np.sin(ang) * np.sin(lon)
        pm = ((np.abs(px) / 0.55) ** 4 + (np.abs(py) / 0.22) ** 4) < 1
    elif kind == "oval":
        px, py = np.sin(ang) * np.cos(lon), np.sin(ang) * np.sin(lon)
        pm = ((px / 0.5) ** 2 + (py / 0.3) ** 2) < 1
    else:
        pm = ang < 0.42
    col[pm] = [0.012, 0.01, 0.01]
    rgba = np.concatenate([col, np.ones((h, size, 1))], axis=-1)
    im = bpy.data.images.new("eye_" + kind, size, h, alpha=False)
    im.pixels.foreach_set(rgba[::-1].astype(np.float32).ravel() if False else rgba.astype(np.float32).ravel())
    return im

def make_eyes(spec, arm):
    """Two eyeballs (glossy, with a clear cornea highlight) and two upper eyelids (bones eyelid_L/R close them)."""
    mat = bpy.data.materials.new(spec.name + "_eye")
    mat.use_nodes = True
    nt = mat.node_tree; b = nt.nodes.get("Principled BSDF")
    ti = nt.nodes.new("ShaderNodeTexImage"); ti.image = eye_texture(spec.eye_kind, iris=spec.iris)
    nt.links.new(ti.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.04
    b.inputs["Specular IOR Level"].default_value = 0.8
    b.inputs["Coat Weight"].default_value = 1.0
    b.inputs["Coat Roughness"].default_value = 0.02
    lidm = bpy.data.materials.new(spec.name + "_lid")
    lidm.use_nodes = True
    lb = lidm.node_tree.nodes.get("Principled BSDF")
    lb.inputs["Base Color"].default_value = tuple(srgb_to_lin(spec.lid_col)) + (1,)
    lb.inputs["Roughness"].default_value = 0.7
    eyes = []
    for i, (c, r) in enumerate(spec.eyes):
        side = "_L" if c[0] > 0 else "_R"           # named by where it is: the animal's left is +x
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=r)
        me = bpy.data.meshes.new("eye" + side); bm.to_mesh(me); bm.free()
        # the sphere's pole (+z) is the eye's gaze: point it out of the head, sideways and a little forward
        gaze = sdf.norm(spec.eye_gaze(i))
        q = Vector((0, 0, 1)).rotation_difference(Vector(gaze))
        ob = bpy.data.objects.new(spec.name + "_eye" + side, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.matrix_world = Matrix.Translation(Vector(c)) @ q.to_matrix().to_4x4()
        for p in me.polygons: p.use_smooth = True
        me.materials.append(mat)
        # uv for the equirect map
        uvl = me.uv_layers.new(name="UVMap")
        for poly in me.polygons:
            for li in poly.loop_indices:
                v = me.vertices[me.loops[li].vertex_index].co
                n = v.normalized()
                lon = math.atan2(n.y, n.x); lat = math.asin(max(-1, min(1, n.z)))
                uvl.data[li].uv = ((lon + math.pi) / (2 * math.pi), (lat + math.pi / 2) / math.pi)
        blib.set_active(ob); bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        vg = ob.vertex_groups.new(name="head"); vg.add(list(range(len(me.vertices))), 1.0, "REPLACE")
        eyes.append(ob)
        # upper lid: a shell a little bigger than the eye, the top half, rotated up out of sight (open); the eyelid bone
        # turns it down over the eye (blink)
        # lid frame: x = up x gaze (along the head), y = up, z = gaze. Keep the cap from 15 degrees below the gaze line
        # over the top (the closed lid), then turn it 80 degrees up into the head (open): the eyelid bone turns it back.
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=14, radius=r * 1.1)
        kill = [v for v in bm.verts if not (-0.27 <= math.atan2(v.co.y, v.co.z) <= 1.75)]
        bmesh.ops.delete(bm, geom=kill, context="VERTS")
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(-80), 3, "X"), verts=bm.verts)
        me2 = bpy.data.meshes.new("lid" + side); bm.to_mesh(me2); bm.free()
        lid = bpy.data.objects.new(spec.name + "_lid" + side, me2)
        bpy.context.scene.collection.objects.link(lid)
        up = Vector(spec.eye_up(i)).normalized()
        g = Vector(gaze)
        side_ax = up.cross(g).normalized(); up = g.cross(side_ax).normalized()
        R = Matrix((side_ax, up, g)).transposed()
        lid.matrix_world = Matrix.Translation(Vector(c)) @ R.to_4x4()
        for p in me2.polygons: p.use_smooth = True
        me2.materials.append(lidm)
        lid.data.uv_layers.new(name="UVMap")
        blib.set_active(lid); bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        vg = lid.vertex_groups.new(name="eyelid" + side); vg.add(list(range(len(me2.vertices))), 1.0, "REPLACE")
        eyes.append(lid)
    return eyes

# ------------------------------------------------------------------ 5. armature
def build_armature(spec):
    ad = bpy.data.armatures.new(spec.name + "_rig")
    arm = bpy.data.objects.new(spec.name, ad)        # the root node of the export is named after the animal
    bpy.context.scene.collection.objects.link(arm)
    blib.set_active(arm)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = ad.edit_bones
    for b in spec.bones():
        name, head, tail, parent, zref, deform = b
        e = eb.new(name)
        e.head = Vector(head); e.tail = Vector(tail)
        e.align_roll(Vector(zref))
        e.use_deform = deform
        if parent:
            e.parent = eb[parent]
            e.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    ad.display_type = "STICK"
    return arm

def skin(spec, arm, body, extra):
    """Automatic (bone heat) weights on the body, then clean-up: smooth, at most four bones per vertex, normalised.
    The jaw takes the lower jaw by a geometric split, the eyes and lids are rigid."""
    for o in bpy.context.scene.objects: o.select_set(False)
    body.select_set(True); arm.select_set(True); bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    # bone heat sometimes leaves a vertex with no weight: give those the nearest bone
    blib.set_active(body)
    spec.fix_weights(body, arm)
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=0.5, repeat=2, expand=0.0)
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in extra:
        o.parent = arm
        md = o.modifiers.new("Armature", "ARMATURE"); md.object = arm

def transfer_weights(src, dst, arm):
    blib.set_active(dst)
    dst.vertex_groups.clear()
    for g in src.vertex_groups:
        dst.vertex_groups.new(name=g.name)
    m = dst.modifiers.new("dt", "DATA_TRANSFER")
    m.object = src; m.use_vert_data = True; m.data_types_verts = {"VGROUP_WEIGHTS"}
    m.vert_mapping = "POLYINTERP_NEAREST"
    m.layers_vgroup_select_src = "ALL"; m.layers_vgroup_select_dst = "NAME"
    bpy.ops.object.modifier_apply(modifier="dt")
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    dst.parent = arm
    md = dst.modifiers.new("Armature", "ARMATURE"); md.object = arm

# ------------------------------------------------------------------ 6. LODs
def make_lod(lo, name, ratio):
    ob = lo.copy(); ob.data = lo.data.copy(); ob.name = name
    bpy.context.scene.collection.objects.link(ob)
    for md in list(ob.modifiers): ob.modifiers.remove(md)
    blib.set_active(ob)
    m = ob.modifiers.new("dec", "DECIMATE"); m.ratio = ratio; m.use_symmetry = True; m.symmetry_axis = "X"
    m.delimit = {"UV"}
    bpy.ops.object.modifier_apply(modifier="dec")
    log("lod", name, blib.tri_count(ob), "tris")
    return ob

# ------------------------------------------------------------------ 7. animation
def bake_clips(spec, arm, clips, fps=30):
    """Each clip is a function f(t, pose) that poses the control rig at time t (seconds); the deform bones' resulting
    local transforms are sampled every frame into a new action (the IK and copy-rotation constraints are then muted, so
    the exported action is plain forward kinematics)."""
    scn = bpy.context.scene
    scn.render.fps = fps
    blib.set_active(arm)
    bpy.ops.object.mode_set(mode="POSE")
    pb = arm.pose.bones
    deform = [b.name for b in arm.data.bones if b.use_deform]
    ad = arm.animation_data_create()
    actions = []
    for clip in clips:
        name, dur, fn = clip["name"], clip["dur"], clip["fn"]
        n = max(2, int(round(dur * fps)))
        for c in arm.pose.bones:
            for con in c.constraints: con.mute = False
        frames = []
        for f in range(n + 1):
            t = f / fps
            for b in pb:
                b.location = (0, 0, 0); b.rotation_mode = "QUATERNION"; b.rotation_quaternion = (1, 0, 0, 0); b.scale = (1, 1, 1)
            fn(t, pb)
            bpy.context.view_layer.update()
            snap = {}
            for bn in deform:
                b = pb[bn]
                m = arm.convert_space(pose_bone=b, matrix=b.matrix, from_space="POSE", to_space="LOCAL")
                loc, rot, sc = m.decompose()
                snap[bn] = (loc.copy(), rot.copy(), sc.copy())
            frames.append(snap)
        if clip.get("loop", True):
            frames[-1] = frames[0]
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        for bn in deform:
            prev = None
            fcs_l = [act.fcurves.new('pose.bones["%s"].location' % bn, index=i, action_group=bn) for i in range(3)]
            fcs_r = [act.fcurves.new('pose.bones["%s"].rotation_quaternion' % bn, index=i, action_group=bn) for i in range(4)]
            for i in range(3): fcs_l[i].keyframe_points.add(n + 1)
            for i in range(4): fcs_r[i].keyframe_points.add(n + 1)
            for f, snap in enumerate(frames):
                loc, rot, sc = snap[bn]
                if prev is not None and prev.dot(rot) < 0: rot = -rot
                prev = rot
                for i in range(3):
                    k = fcs_l[i].keyframe_points[f]; k.co = (f, loc[i]); k.interpolation = "LINEAR"
                for i in range(4):
                    k = fcs_r[i].keyframe_points[f]; k.co = (f, rot[i]); k.interpolation = "LINEAR"
        act.frame_range = (0, n)
        actions.append(act)
        log("clip", name, n + 1, "frames")
    for c in arm.pose.bones:
        for con in c.constraints: con.mute = True
        c.location = (0, 0, 0); c.rotation_quaternion = (1, 0, 0, 0)
    bpy.ops.object.mode_set(mode="OBJECT")
    # one NLA track per clip: the exporter writes each track as a named glTF animation
    for tr in list(ad.nla_tracks): ad.nla_tracks.remove(tr)
    for act in actions:
        act.id_root = "OBJECT"
        tr = ad.nla_tracks.new(); tr.name = act.name
        st = tr.strips.new(act.name, 0, act)
        tr.mute = True
    ad.action = None
    return actions

# ------------------------------------------------------------------ 8. export
def export_glb(path, objs, arm):
    for o in bpy.context.scene.objects: o.select_set(False)
    for o in objs: o.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=False,
                              export_animations=True, export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                              export_frame_step=1, export_def_bones=True, export_optimize_animation_size=True,
                              export_skins=True, export_all_influences=False, export_morph=False,
                              export_image_format="JPEG", export_jpeg_quality=90, export_texcoords=True, export_normals=True,
                              export_tangents=False, export_materials="EXPORT", export_yup=True, export_extras=False,
                              export_vertex_color="ACTIVE", export_reset_pose_bones=True, export_rest_position_armature=True, export_anim_single_armature=True)
    log("exported", path, "%.2f MB" % (os.path.getsize(path) / 1e6))

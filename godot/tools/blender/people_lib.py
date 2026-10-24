# AeroSim people pipeline (Blender 2, lane people): shared code for building rigged, game-ready people in Blender 4.2.
#
# How a person is made (see README-models.md "Blender 2" for the contract):
#   1. MPFB 2 builds a MakeHuman body from macro sliders (age, gender, weight, height, race), with the game_engine rig,
#      the low-poly body proxy (male1591 / female1605), low-poly eyes, eyebrows, eyelashes, hair and fitted clothes.
#      All the MakeHuman data (base mesh, targets, proxies, skins, eyes, hair, the CC0 and CC-BY clothes) is listed with its
#      licence in godot/assets/models/people/README.md.
#   2. The skin is trimmed: body faces hidden under clothes are deleted (cheaper and nothing pokes through when it bends).
#   3. The head is re-detailed: the proxy's head and neck are subdivided once and each vertex is projected back onto the full
#      13k-quad MakeHuman surface, so the face keeps its real shape (nose, lids, lips, ears) at about 2k triangles.
#   4. Facial shape keys (blink, smile, a few mouth shapes, brows up) come from the MakeHuman expression units, refitted and
#      run through the same head processing, so they line up exactly with the game mesh.
#   5. Clothes are decimated to budget, given a rim (thickness at openings) and a material rebuilt from the MakeHuman
#      texture with a photographed Poly Haven fabric (CC0) blended in for real weave, normal and roughness.
#   6. Bones are renamed to Godot's SkeletonProfileHumanoid names, eye bones are added, and three LODs are made.
#   7. Export: glTF 2.0 binary, metres, +Z forward (Blender -Y), origin at the feet, nodes Armature/<part>_LOD<n>.
import bpy, bmesh, os, sys, math, json, random
import numpy as np
from mathutils import Vector, Matrix, Quaternion
from mathutils.bvhtree import BVHTree

from bl_ext.user_default.mpfb.services.humanservice import HumanService
from bl_ext.user_default.mpfb.services.targetservice import TargetService
from bl_ext.user_default.mpfb.services.locationservice import LocationService
from bl_ext.user_default.mpfb.services.clothesservice import ClothesService

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(GODOT, "assets", "models", "people")
TOOLS = os.path.normpath(os.path.join(GODOT, "..", "..", "_tools", "people"))
FABRIC = os.path.join(TOOLS, "fabric")
TEXCACHE = os.path.join(TOOLS, "texcache")
MPFB_DATA = None

def data_dir():
    global MPFB_DATA
    if MPFB_DATA is None:
        MPFB_DATA = LocationService.get_user_data()
    return MPFB_DATA

def asset_path(kind, name):
    """Find the .mhclo/.proxy/.mhmat file for an asset folder name."""
    d = os.path.join(data_dir(), kind, name)
    for f in sorted(os.listdir(d)):
        if f.endswith(".mhclo") or f.endswith(".proxy"):
            return os.path.join(d, f)
    raise IOError("no mhclo in " + d)

# Godot SkeletonProfileHumanoid names for the MPFB game_engine rig.
BONE_MAP = {"Root": "Root", "pelvis": "Hips", "spine_01": "Spine", "spine_02": "Chest", "spine_03": "UpperChest",
            "neck_01": "Neck", "head": "Head"}
for s, S in (("l", "Left"), ("r", "Right")):
    BONE_MAP.update({f"clavicle_{s}": f"{S}Shoulder", f"upperarm_{s}": f"{S}UpperArm", f"lowerarm_{s}": f"{S}LowerArm",
                     f"hand_{s}": f"{S}Hand", f"thigh_{s}": f"{S}UpperLeg", f"calf_{s}": f"{S}LowerLeg",
                     f"foot_{s}": f"{S}Foot", f"ball_{s}": f"{S}Toes",
                     f"thumb_01_{s}": f"{S}ThumbMetacarpal", f"thumb_02_{s}": f"{S}ThumbProximal", f"thumb_03_{s}": f"{S}ThumbDistal"})
    for f, F in (("index", "Index"), ("middle", "Middle"), ("ring", "Ring"), ("pinky", "Little")):
        BONE_MAP.update({f"{f}_01_{s}": f"{S}{F}Proximal", f"{f}_02_{s}": f"{S}{F}Intermediate", f"{f}_03_{s}": f"{S}{F}Distal"})

# Facial shape keys: name -> list of (MakeHuman expression unit, weight)
EXPRESSIONS = {
    "blink": [("eye-left-closure", 1.0), ("eye-right-closure", 1.0)],
    "smile": [("mouth-corner-puller", 0.75), ("eye-left-slit", 0.15), ("eye-right-slit", 0.15)],
    "mouth_open": [("mouth-open", 0.55)],
    "mouth_o": [("mouth-pursing", 0.7), ("mouth-open", 0.22)],
    "mouth_e": [("mouth-retraction", 0.55), ("mouth-open", 0.12)],
    "mouth_mbp": [("mouth-compression", 0.6)],
    "brow_up": [("eyebrows-left-up", 0.7), ("eyebrows-right-up", 0.7)],
}

# ---------------------------------------------------------------------------------------------------------------- utils
def log(*a):
    print("[people]", *a, flush=True)

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def link(obj):
    bpy.context.scene.collection.objects.link(obj)

def select_only(objs, active=None):
    for o in bpy.context.scene.objects:
        if o is not None:
            o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or (objs[0] if objs else None)

def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)

def apply_modifier(obj, name):
    select_only([obj])
    bpy.ops.object.modifier_apply(modifier=name)

def body_mesh_eval(basemesh):
    """The full MakeHuman surface (helpers masked away) as a world-space BVH, with shape keys applied."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = basemesh.evaluated_get(dg)
    me = ev.to_mesh()
    verts = [basemesh.matrix_world @ v.co for v in me.vertices]
    polys = [tuple(p.vertices) for p in me.polygons]
    bvh = BVHTree.FromPolygons(verts, polys)
    ev.to_mesh_clear()
    return bvh

# ------------------------------------------------------------------------------------------------------- the MPFB body
class Person:
    """Everything built for one character before export."""
    def __init__(self, spec):
        self.spec = spec
        self.basemesh = None
        self.rig = None
        self.proxy = None
        self.eyes = None
        self.brows = None
        self.lashes = None
        self.hair = None
        self.hat = None
        self.clothes = []      # (object, garment spec)

def race_units(race):
    r = max(race, key=race.get)
    return os.path.join(LocationService.get_mpfb_data("targets"), "expression", "units", r)

def build_mpfb(spec):
    """Create the MakeHuman body, rig, proxy and fitted assets for a spec dict (see people_roster.py)."""
    p = Person(spec)
    macro = TargetService.get_default_macro_info_dict()
    macro.update(spec["macro"])
    macro["race"] = dict(spec["race"])
    bm = HumanService.create_human(macro_detail_dict=macro, scale=0.1)
    # extra modelling targets (e.g. older face, nose shape) on top of the macros
    tdir = LocationService.get_mpfb_data("targets")
    for tname, w in spec.get("targets", {}).items():
        path = None
        for root, _, files in os.walk(tdir):
            for f in files:
                if f == tname + ".target.gz":
                    path = os.path.join(root, f)
        if path:
            TargetService.load_target(bm, path, weight=w, name=tname)
        else:
            log("missing target", tname)
    p.basemesh = bm
    p.rig = HumanService.add_builtin_rig(bm, "game_engine")
    proxy_name = spec.get("proxy", "male1591" if spec["macro"].get("gender", 0.5) >= 0.5 else "female1605")
    p.proxy = HumanService.add_mhclo_asset(asset_path("proxymeshes", proxy_name), bm, asset_type="Proxymeshes", subdiv_levels=0)
    p.eyes = HumanService.add_mhclo_asset(asset_path("eyes", "low-poly"), bm, asset_type="Eyes", subdiv_levels=0)
    p.brows = HumanService.add_mhclo_asset(asset_path("eyebrows", spec.get("brows", "eyebrow001")), bm, asset_type="Eyebrows", subdiv_levels=0)
    p.lashes = HumanService.add_mhclo_asset(asset_path("eyelashes", spec.get("lashes", "eyelashes01")), bm, asset_type="Eyelashes", subdiv_levels=0)
    if spec.get("hair"):
        p.hair = HumanService.add_mhclo_asset(asset_path("hair", spec["hair"]["asset"]), bm, asset_type="Hair", subdiv_levels=0)
    for g in spec.get("clothes", []):
        o = HumanService.add_mhclo_asset(asset_path("clothes", g["asset"]), bm, asset_type="Clothes", subdiv_levels=0)
        p.clothes.append((o, g))
    # expression units as zero-weight targets for the facial shape keys
    udir = race_units(spec["race"])
    needed = sorted({u for parts in EXPRESSIONS.values() for u, _ in parts})
    for u in needed:
        TargetService.load_target(bm, os.path.join(udir, u + ".target.gz"), weight=0.0, name="expr_" + u)
    return p

def set_expression(p, expr):
    kb = p.basemesh.data.shape_keys.key_blocks
    for k in kb:
        if k.name.startswith("expr_"):
            k.value = 0.0
    if expr:
        for u, w in EXPRESSIONS[expr]:
            kb["expr_" + u].value = w
    for o in [p.proxy, p.brows, p.lashes]:
        ClothesService.fit_clothes_to_human(o, p.basemesh, set_parent=False)

def coords(obj):
    a = np.zeros(len(obj.data.vertices) * 3, dtype=np.float64)
    obj.data.vertices.foreach_get("co", a)
    return a.reshape(-1, 3)

# ---------------------------------------------------------------------------------------------------- skin processing
def covered_vertices(p, margin=0.045):
    """Proxy vertices hidden under clothes: a ray outward along the normal hits a garment within `margin` metres."""
    cloth_polys, cloth_verts = [], []
    for o, g in p.clothes:
        if g.get("covers", True) is False:
            continue
        base = len(cloth_verts)
        cloth_verts.extend(o.matrix_world @ v.co for v in o.data.vertices)
        cloth_polys.extend(tuple(base + i for i in pl.vertices) for pl in o.data.polygons)
    if not cloth_polys:
        return set()
    bvh = BVHTree.FromPolygons(cloth_verts, cloth_polys)
    hidden = set()
    me = p.proxy.data
    head_g = me.vertices  # noqa
    for v in me.vertices:
        co = p.proxy.matrix_world @ v.co
        n = (p.proxy.matrix_world.to_3x3() @ v.normal).normalized()
        hit = bvh.ray_cast(co - n * 0.002, n, margin)
        if hit[0] is not None:
            # also require a hit in a slightly tilted direction, so edges (cuffs, collars) keep a little skin under them
            hidden.add(v.index)
    return hidden

def group_weights(obj, names):
    idx = {obj.vertex_groups[n].index for n in names if n in obj.vertex_groups}
    w = np.zeros(len(obj.data.vertices))
    for v in obj.data.vertices:
        for g in v.groups:
            if g.group in idx:
                w[v.index] += g.weight
    return w

class SkinPlan:
    """Deterministic topology edit of the body proxy: which faces are deleted, which are subdivided as 'head'."""
    def __init__(self, p):
        me = p.proxy.data
        hidden = covered_vertices(p) if p.spec.get("trim_skin", True) else set()
        keep = p.spec.get("keep_skin_groups", [])
        if keep:
            kw = group_weights(p.proxy, keep)
            hidden = {i for i in hidden if kw[i] < 0.3}
        self.delete_faces = [pl.index for pl in me.polygons if all(i in hidden for i in pl.vertices)]
        hw = group_weights(p.proxy, ["head"])
        ec = coords(p.eyes)
        eye_z = float(ec[:, 2].mean()) + p.eyes.matrix_world.translation.z
        head_y = float(np.mean([p.proxy.matrix_world @ me.vertices[i].co for i in range(len(me.vertices)) if hw[i] > 0.9], axis=0)[1])
        mw = p.proxy.matrix_world
        def face_zone(pl):
            c = mw @ pl.center
            return c.z < eye_z + p.spec.get("detail_above_eyes", 0.03) and c.y < head_y + p.spec.get("detail_behind", 0.03)
        self.head_faces = [pl.index for pl in me.polygons if min(hw[i] for i in pl.vertices) > 0.5 and face_zone(pl)]
        # the part of the skin exported as the head node (face and neck above the collar)
        hw2 = group_weights(p.proxy, ["head"])
        self.head_part_faces = set(pl.index for pl in me.polygons if sum(hw2[i] for i in pl.vertices) / len(pl.vertices) > 0.5)

def process_skin(p, plan, bvh, src_coords):
    """Return a bmesh of the trimmed, head-detailed skin built from the proxy topology with `src_coords`."""
    bm = bmesh.new()
    bm.from_mesh(p.proxy.data)
    bm.verts.ensure_lookup_table()
    for v, c in zip(bm.verts, src_coords):
        v.co = Vector(c)
    bm.faces.ensure_lookup_table()
    # tag head faces (layer survives the delete) and the head node part
    tag = bm.faces.layers.int.new("headpart")
    for f in bm.faces:
        f[tag] = 1 if f.index in plan.head_part_faces else 0
    head = [bm.faces[i] for i in plan.head_faces]
    dele = [bm.faces[i] for i in plan.delete_faces]
    head_set = set(head)
    dele = [f for f in dele if f not in head_set]
    bmesh.ops.delete(bm, geom=dele, context="FACES_ONLY")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.faces.ensure_lookup_table()
    head = [f for f in head if f.is_valid]
    edges = list({e for f in head for e in f.edges})
    res = bmesh.ops.subdivide_edges(bm, edges=edges, cuts=1, use_grid_fill=True, smooth=0.0, quad_corner_type="INNER_VERT")
    # project every head vertex back onto the full-resolution surface
    hv = set()
    for f in bm.faces:
        if f[tag] == 1 or any(v in hv for v in f.verts):
            pass
    head_verts = set()
    for f in bm.faces:
        if f[tag] == 1:
            head_verts.update(f.verts)
    hfaces = set(head)
    for e in edges:
        if e.is_valid:
            head_verts.update(e.verts)
    for g in res["geom_inner"] + res["geom_split"]:
        if isinstance(g, bmesh.types.BMVert):
            head_verts.add(g)
    bm.normal_update()
    for v in head_verts:
        co = v.co
        n = v.normal
        best = None
        for d in (n, -n):
            hit = bvh.ray_cast(co, d, 0.008)
            if hit[0] is not None and (best is None or hit[3] < best[3]):
                best = hit
        if best is None:
            nb = bvh.find_nearest(co, 0.004)
            if nb[0] is not None:
                best = nb
        if best is not None:
            v.co = best[0]
    ngons = [f for f in bm.faces if len(f.verts) > 4]
    if ngons:
        bmesh.ops.triangulate(bm, faces=ngons)
    return bm

def build_skin(p):
    """Make the game skin object (trimmed body + detailed head) with facial shape keys."""
    plan = SkinPlan(p)
    set_expression(p, None)
    bvh = body_mesh_eval(p.basemesh)
    bm = process_skin(p, plan, bvh, coords(p.proxy))
    me = bpy.data.meshes.new("skin")
    bm.to_mesh(me)
    bm.free()
    skin = bpy.data.objects.new("skin", me)
    link(skin)
    skin.matrix_world = p.proxy.matrix_world
    # copy vertex group names (the deform layer is carried by bmesh)
    for g in p.proxy.vertex_groups:
        skin.vertex_groups.new(name=g.name)
    for poly in me.polygons:
        poly.use_smooth = True
    base_brows, base_lashes = coords(p.brows), coords(p.lashes)
    skin.shape_key_add(name="Basis")
    p.brows.shape_key_add(name="Basis")
    p.lashes.shape_key_add(name="Basis")
    for expr in EXPRESSIONS:
        set_expression(p, expr)
        bvh_e = body_mesh_eval(p.basemesh)
        bm = process_skin(p, plan, bvh_e, coords(p.proxy))
        bm.verts.ensure_lookup_table()
        k = skin.shape_key_add(name=expr, from_mix=False)
        for i, v in enumerate(bm.verts):
            k.data[i].co = v.co
        bm.free()
        for o in (p.brows, p.lashes):
            kk = o.shape_key_add(name=expr, from_mix=False)
            c = coords(o)
            for i in range(len(c)):
                kk.data[i].co = Vector(c[i])
    set_expression(p, None)
    p.skin = skin
    return skin

# ---------------------------------------------------------------------------------------------------- textures
def _img(path):
    from PIL import Image  # noqa (not available in Blender; we use bpy images instead)

def load_px(path, size=None):
    """Load an image file as a float32 HxWx4 array (0..1), optionally resized (square)."""
    im = bpy.data.images.load(path, check_existing=False)
    if size and (im.size[0] != size or im.size[1] != size):
        im.scale(size, size)
    w, h = im.size
    a = np.empty(w * h * 4, dtype=np.float32)
    im.pixels.foreach_get(a)
    bpy.data.images.remove(im)
    return a.reshape(h, w, 4)

def save_px(arr, path, fmt="JPEG", quality=88):
    h, w = arr.shape[:2]
    im = bpy.data.images.new(os.path.basename(path), w, h, alpha=(fmt == "PNG"))
    im.pixels.foreach_set(np.ascontiguousarray(arr, dtype=np.float32).ravel())
    im.filepath_raw = path
    im.file_format = fmt
    sc = bpy.context.scene
    sc.render.image_settings.quality = quality
    im.save(quality=quality)
    bpy.data.images.remove(im)
    return path

def tile(arr, n, size):
    """Tile a texture n times over a size x size square (nearest resample)."""
    h, w = arr.shape[:2]
    ys = (np.arange(size) * n * h // size) % h
    xs = (np.arange(size) * n * w // size) % w
    return arr[ys][:, xs]

def srgb_to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)

def mhmat_textures(mhclo_path):
    """diffuse / normal / alpha texture paths of an MH asset from its .mhmat."""
    d = os.path.dirname(mhclo_path)
    mat = None
    with open(mhclo_path, encoding="utf8", errors="ignore") as f:
        for line in f:
            if line.startswith("material "):
                mat = os.path.join(d, line.split(None, 1)[1].strip())
    if mat is None or not os.path.exists(mat):
        mats = [x for x in os.listdir(d) if x.endswith(".mhmat")]
        mat = os.path.join(d, mats[0]) if mats else None
    out = {}
    if mat:
        with open(mat, encoding="utf8", errors="ignore") as f:
            for line in f:
                parts = line.split(None, 1)
                if len(parts) < 2:
                    continue
                k, v = parts[0], parts[1].strip()
                path = os.path.join(d, os.path.basename(v))
                if k == "diffuseTexture" and os.path.exists(path):
                    out["diffuse"] = path
                elif k in ("normalmapTexture", "bumpTexture", "bumpmapTexture") and os.path.exists(path):
                    if "norm" in v.lower() or k == "normalmapTexture":
                        out["normal"] = path
                elif k == "diffuseColor":
                    out["color"] = [float(x) for x in v.split()[:3]]
    return out

def fabric(name, size):
    d = load_px(os.path.join(FABRIC, f"{name}_diff.jpg"), size)
    n = load_px(os.path.join(FABRIC, f"{name}_nor.jpg"), size)
    r = load_px(os.path.join(FABRIC, f"{name}_rough.jpg"), size)
    return d, n, r

def make_garment_textures(key, mhclo_path, g, size=1024, obj=None):
    """Diffuse/normal/ORM for a garment: MakeHuman texture (folds, seams, details) recoloured by the tint, with a
    photographed fabric tiled over it for weave and roughness. Cached by key."""
    os.makedirs(TEXCACHE, exist_ok=True)
    out = {k: os.path.join(TEXCACHE, f"{key}_{k}.jpg") for k in ("diff", "nor", "orm")}
    if all(os.path.exists(v) for v in out.values()) and not os.environ.get("PEOPLE_RETEX"):
        return out
    tx = mhmat_textures(mhclo_path)
    size = g.get("tex", size)
    if "diffuse" in tx:
        base = load_px(tx["diffuse"], size)
    else:
        c = tx.get("color", [0.6, 0.6, 0.6])
        base = np.ones((size, size, 4), np.float32)
        base[..., :3] = c
    if "normal" in tx:
        nrm = load_px(tx["normal"], size)
    else:
        nrm = np.zeros((size, size, 4), np.float32); nrm[..., 0] = 0.5; nrm[..., 1] = 0.5; nrm[..., 2] = 1.0; nrm[..., 3] = 1
    rough = np.full((size, size), g.get("rough", 0.85), np.float32)
    rgb = base[..., :3]
    if g.get("regions") or g.get("lower") or g.get("patches"):
        # lane/rennick: region-aware recolouring (shirt, tie, buttons, a trousers/jacket split, emblem patches)
        rgb = region_tint(rgb, g, obj, size)
    elif g.get("tint") is not None and not g.get("keep_color"):
        luma = rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32)
        m = None
        if obj is not None and obj.data.uv_layers:
            # the garment's own texels only (sampled at its UVs), not the empty parts of the image
            uv = np.zeros(len(obj.data.loops) * 2, np.float32)
            obj.data.uv_layers.active.data.foreach_get("uv", uv)
            uv = uv.reshape(-1, 2) % 1.0
            h, w = luma.shape
            ys = np.clip((uv[:, 1] * h).astype(int), 0, h - 1)
            xs = np.clip((uv[:, 0] * w).astype(int), 0, w - 1)
            m = float(np.median(luma[ys, xs]))
        if m is None or m < 0.005:
            m = np.median(luma[luma > 0.02]) if np.any(luma > 0.02) else 0.5
        shade = np.clip(luma / max(m, 1e-3), 0.0, 2.0) ** g.get("shade_gamma", 0.8)
        t = np.array(g["tint"], np.float32)
        mix = g.get("tint_mix", 1.0)
        rgb = rgb * (1 - mix) + (shade[..., None] * t[None, None, :]) * mix
    if g.get("fabric"):
        fd, fn, fr = fabric(g["fabric"], 512)
        n = g.get("tile", 6)
        fd = tile(fd, n, size); fn = tile(fn, n, size); fr = tile(fr, n, size)
        fl = fd[..., :3] @ np.array([0.2126, 0.7152, 0.0722], np.float32)
        detail = fl / max(float(fl.mean()), 1e-3)
        k = g.get("detail", 0.7)
        rgb = rgb * (1 - k + k * detail[..., None])
        # whiteout blend of the two tangent-space normal maps
        a = nrm[..., :3] * 2 - 1
        b = fn[..., :3] * 2 - 1
        b[..., :2] *= g.get("weave", 1.0)
        c = np.stack([a[..., 0] + b[..., 0], a[..., 1] + b[..., 1], a[..., 2] * b[..., 2]], -1)
        c /= np.linalg.norm(c, axis=-1, keepdims=True) + 1e-6
        nrm = np.concatenate([c * 0.5 + 0.5, np.ones_like(c[..., :1])], -1)
        rough = np.clip(fr[..., 0] * g.get("rough_scale", 1.0), 0.3, 1.0)
    diff = np.concatenate([np.clip(rgb, 0, 1), np.ones_like(rgb[..., :1])], -1)
    orm = np.stack([np.ones_like(rough), rough, np.zeros_like(rough), np.ones_like(rough)], -1)
    save_px(diff, out["diff"]); save_px(nrm, out["nor"], quality=92); save_px(orm, out["orm"])
    return out

def uv_mask(obj, size, face_test, islands=True):
    """size x size mask (row 0 = bottom, as Blender stores images) of the UV area of the faces where face_test(world
    centre) is true. A small rasteriser: each polygon's UVs are fanned into triangles and filled by barycentric test."""
    mask = np.zeros((size, size), bool)
    if obj is None or not obj.data.uv_layers:
        return mask
    uvl = obj.data.uv_layers.active.data
    mw = obj.matrix_world
    polys = obj.data.polygons
    chosen = [face_test(mw @ pl.center) for pl in polys]
    if islands:
        # decide per UV island (faces joined by an edge with the same UVs): the island goes with the majority of its area
        parent = list(range(len(polys)))
        def find(i):
            while parent[i] != i:
                parent[i] = parent[parent[i]]
                i = parent[i]
            return i
        seen = {}
        loops = obj.data.loops
        for pl in polys:
            n = len(pl.loop_indices)
            for k in range(n):
                l0, l1 = pl.loop_indices[k], pl.loop_indices[(k + 1) % n]
                a = (loops[l0].vertex_index, round(uvl[l0].uv[0], 4), round(uvl[l0].uv[1], 4))
                b = (loops[l1].vertex_index, round(uvl[l1].uv[0], 4), round(uvl[l1].uv[1], 4))
                e = (a, b) if a < b else (b, a)
                if e in seen:
                    ra, rb = find(seen[e]), find(pl.index)
                    if ra != rb:
                        parent[ra] = rb
                else:
                    seen[e] = pl.index
        votes = {}
        for pl in polys:
            r = find(pl.index)
            v = votes.setdefault(r, [0.0, 0.0])
            v[0 if chosen[pl.index] else 1] += pl.area
        chosen = [votes[find(pl.index)][0] > votes[find(pl.index)][1] for pl in polys]
    for pl in polys:
        if not chosen[pl.index]:
            continue
        uv = np.array([uvl[li].uv[:] for li in pl.loop_indices], np.float64) * size
        for k in range(1, len(uv) - 1):
            a, b, c = uv[0], uv[k], uv[k + 1]
            x0, y0 = np.floor(np.minimum(np.minimum(a, b), c)).astype(int) - 1
            x1, y1 = np.ceil(np.maximum(np.maximum(a, b), c)).astype(int) + 1
            x0, y0 = max(x0, 0), max(y0, 0)
            x1, y1 = min(x1, size - 1), min(y1, size - 1)
            if x1 < x0 or y1 < y0:
                continue
            ys, xs = np.mgrid[y0:y1 + 1, x0:x1 + 1]
            px, py = xs + 0.5, ys + 0.5
            d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(d) < 1e-9:
                continue
            l1 = ((b[1] - c[1]) * (px - c[0]) + (c[0] - b[0]) * (py - c[1])) / d
            l2 = ((c[1] - a[1]) * (px - c[0]) + (a[0] - c[0]) * (py - c[1])) / d
            inside = (l1 >= -0.02) & (l2 >= -0.02) & (1 - l1 - l2 >= -0.02)
            mask[y0:y1 + 1, x0:x1 + 1] |= inside
    return mask

def region_tint(rgb, g, obj, size):
    """Recolour a garment texture by region, keeping its shading (each region is shaded against its own median):
      g["tint"]      the main cloth colour
      g["regions"]   {"white": colour, "grey": colour, "dark": colour, "other": colour}: classes of the source texture
                     (white = shirt and tape, grey = collars and linings, dark = print and lettering, other = anything far
                     from the garment's main colour: ties, buttons, prints). Unlisted classes take the main tint.
      g["lower"]     {"tint": colour, "z": world height}: faces below z (trousers of a one-piece suit) take this colour
      g["patches"]   [(x0, y0, x1, y1, painter)]: UV rectangles (0..1, from the image's top-left) painted by painter(h, w)
                     -> RGB array; used to replace a real organisation's logo with a fictional emblem."""
    luma = rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1e-3)
    own = None
    if obj is not None and obj.data.uv_layers:
        uv = np.zeros(len(obj.data.loops) * 2, np.float32)
        obj.data.uv_layers.active.data.foreach_get("uv", uv)
        uv = uv.reshape(-1, 2) % 1.0
        ys = np.clip((uv[:, 1] * size).astype(int), 0, size - 1)
        xs = np.clip((uv[:, 0] * size).astype(int), 0, size - 1)
        own = rgb[ys, xs]
    dom = np.median(own if own is not None and len(own) else rgb.reshape(-1, 3), axis=0)
    dist = np.linalg.norm(rgb - dom[None, None, :], axis=-1)
    cls = np.zeros(luma.shape, np.int8)                      # 0 main
    regions = g.get("regions", {})
    if "other" in regions:
        cls[dist > g.get("other_dist", 0.22)] = 4
    if "grey" in regions:
        cls[(sat < 0.18) & (luma > 0.22) & (luma <= 0.7) & (dist > 0.12)] = 2
    if "dark" in regions:
        cls[(luma < 0.12) & (dist > 0.12)] = 3
    if "white" in regions:
        cls[(luma > 0.7) & (sat < 0.2)] = 1
    tints = {0: g["tint"], 1: regions.get("white"), 2: regions.get("grey"), 3: regions.get("dark"), 4: regions.get("other")}
    out = np.zeros_like(rgb)
    sg = g.get("shade_gamma", 0.8)
    for c, t in tints.items():
        m = cls == c
        if t is None or not m.any():
            if m.any():
                out[m] = rgb[m]
            continue
        med = max(float(np.median(luma[m])), 1e-3)
        gam = g.get("other_gamma", 0.12) if c == 4 else sg     # prints (a floral tie) go nearly flat
        shade = np.clip(luma[m] / med, 0.0, 2.0) ** gam
        out[m] = shade[:, None] * np.array(t, np.float32)[None, :]
    if g.get("lower"):
        lw = g["lower"]
        mask = uv_mask(obj, size, lambda c: c.z < lw["z"]) & (cls == 0)
        if mask.any():
            med = max(float(np.median(luma[mask])), 1e-3)
            shade = np.clip(luma[mask] / med, 0.0, 2.0) ** sg
            out[mask] = shade[:, None] * np.array(lw["tint"], np.float32)[None, :]
    patches = g.get("patches", [])
    if isinstance(patches, str):
        import people_rennick
        patches = people_rennick.PATCHES[patches]
    for (x0, y0, x1, y1, painter) in patches:
        r0, r1 = int((1 - y1) * size), int((1 - y0) * size)      # image rows run bottom-up
        c0, c1 = int(x0 * size), int(x1 * size)
        out[r0:r1, c0:c1] = painter(r1 - r0, c1 - c0)[::-1]
    return out

def make_skin_texture(key, skin_name, size=1024, tint=None):
    os.makedirs(TEXCACHE, exist_ok=True)
    out = os.path.join(TEXCACHE, f"{key}_skin.jpg")
    if os.path.exists(out) and not os.environ.get("PEOPLE_RETEX"):
        return out
    d = os.path.join(data_dir(), "skins", skin_name)
    f = [x for x in os.listdir(d) if x.endswith(".png") and "diffuse" in x][0]
    px = load_px(os.path.join(d, f), size)
    if tint:
        px[..., :3] *= np.array(tint, np.float32)
    px[..., 3] = 1
    save_px(np.clip(px, 0, 1), out)
    return out

def copy_alpha_texture(key, src, size=512, tint=None, fmt="PNG"):
    os.makedirs(TEXCACHE, exist_ok=True)
    out = os.path.join(TEXCACHE, f"{key}.png")
    if os.path.exists(out) and not os.environ.get("PEOPLE_RETEX"):
        return out
    px = load_px(src, size)
    if tint is not None:
        luma = px[..., :3] @ np.array([0.2126, 0.7152, 0.0722], np.float32)
        m = np.median(luma[px[..., 3] > 0.5]) if np.any(px[..., 3] > 0.5) else 0.5
        shade = np.clip(luma / max(m, 1e-3), 0, 2.2) ** 0.9
        px[..., :3] = np.clip(shade[..., None] * np.array(tint, np.float32), 0, 1)
    # posterize a little and clear the colour under fully transparent texels: much smaller PNGs
    px[..., :3] = np.round(px[..., :3] * 63) / 63
    px[..., :3] *= (px[..., 3:4] > 0.02)
    save_px(px, out, fmt="PNG")
    return out

# ---------------------------------------------------------------------------------------------------- materials
def new_material(name, diff=None, nor=None, orm=None, color=(0.8, 0.8, 0.8), rough=0.6, alpha=None, blend="OPAQUE",
                 double=False, emission=None, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if diff:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(diff, check_existing=True)
        nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
        if alpha:
            nt.links.new(t.outputs["Alpha"], bsdf.inputs["Alpha"])
    if nor:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(nor, check_existing=True)
        t.image.colorspace_settings.name = "Non-Color"
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(t.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if orm:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = bpy.data.images.load(orm, check_existing=True)
        t.image.colorspace_settings.name = "Non-Color"
        sp = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(t.outputs["Color"], sp.inputs["Color"])
        nt.links.new(sp.outputs["Green"], bsdf.inputs["Roughness"])
        nt.links.new(sp.outputs["Blue"], bsdf.inputs["Metallic"])
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission[:3], 1)
        bsdf.inputs["Emission Strength"].default_value = emission[3] if len(emission) > 3 else 1.0
    if alpha:
        m.blend_method = blend
    m.use_backface_culling = not double
    return m

def atlas_grid(n):
    if n <= 1: return 1, 1
    if n == 2: return 2, 1
    if n <= 4: return 2, 2
    if n <= 6: return 3, 2
    if n <= 9: return 3, 3
    return 4, 4

def build_cloth_atlas(key, garments, size=1024, pad=0.012):
    """One material for every garment of a character: each garment's textures are packed into a cell of an atlas and
    its UVs moved into that cell (fewer draw calls, one set of images per character)."""
    cols, rows = atlas_grid(len(garments))
    imgs = {k: np.zeros((size, size, 4), np.float32) for k in ("diff", "nor", "orm")}
    imgs["nor"][..., :] = (0.5, 0.5, 1.0, 1.0)
    imgs["orm"][..., :] = (1.0, 0.8, 0.0, 1.0)
    cw, ch = size // cols, size // rows
    for i, (o, tex) in enumerate(garments):
        cx, cy = i % cols, i // cols
        # pixel rectangle (the image's row 0 is the bottom, as in Blender)
        x0, y0 = cx * cw, cy * ch
        px, py = int(cw * pad) + 1, int(ch * pad) + 1
        iw, ih = cw - 2 * px, ch - 2 * py
        for k in imgs:
            a = load_px(tex[k], None)
            h, w = a.shape[:2]
            ys = (np.arange(ih) * h // ih).clip(0, h - 1)
            xs = (np.arange(iw) * w // iw).clip(0, w - 1)
            r = a[ys][:, xs]
            # bleed the edges into the padding so mipmaps do not pick up the neighbour
            r = np.pad(r, ((py, py), (px, px), (0, 0)), mode="edge")
            imgs[k][y0:y0 + ch, x0:x0 + cw] = r
        u0, v0 = (x0 + px) / size, (y0 + py) / size
        su, sv = iw / size, ih / size
        uv = o.data.uv_layers.active.data
        a = np.zeros(len(uv) * 2, np.float32)
        uv.foreach_get("uv", a)
        a = a.reshape(-1, 2)
        a[:, 0] = u0 + np.clip(a[:, 0] % 1.0 if False else a[:, 0], 0, 1) * su
        a[:, 1] = v0 + np.clip(a[:, 1], 0, 1) * sv
        uv.foreach_set("uv", a.ravel())
    out = {}
    for k in imgs:
        out[k] = os.path.join(TEXCACHE, f"{key}_cloth_{k}.jpg")
        q = 90 if k == "nor" else 84
        arr = imgs[k]
        if k == "orm" and size > 512:
            arr = arr[::2, ::2]
        save_px(arr, out[k], quality=q)
    m = new_material("cloth", diff=out["diff"], nor=out["nor"], orm=out["orm"], double=True)
    for o, _ in garments:
        assign_single_material(o, m)
    return m

def assign_single_material(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    for pl in obj.data.polygons:
        pl.material_index = 0

# ---------------------------------------------------------------------------------------------------- armature
def rename_bones(rig, objs):
    for b in rig.data.bones:
        if b.name in BONE_MAP:
            b.name = BONE_MAP[b.name]
    # vertex groups follow bone renames automatically only for bones; rename groups explicitly
    for o in objs:
        for g in o.vertex_groups:
            if g.name in BONE_MAP:
                g.name = BONE_MAP[g.name]

def add_eye_bones(rig, eyes):
    """Two eye bones (LeftEye/RightEye) under Head at the eyeball centres; the eye mesh is weighted to them."""
    c = coords(eyes)
    mw = eyes.matrix_world
    left = [i for i in range(len(c)) if (mw @ Vector(c[i])).x > 0]
    right = [i for i in range(len(c)) if (mw @ Vector(c[i])).x <= 0]
    centres = {}
    for nm, ids in (("LeftEye", left), ("RightEye", right)):
        pts = np.array([mw @ Vector(c[i]) for i in ids])
        lo, hi = pts.min(0), pts.max(0)
        centres[nm] = Vector(((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2 + (hi[1] - lo[1]) * 0.08, (lo[2] + hi[2]) / 2))
    select_only([rig])
    bpy.ops.object.mode_set(mode="EDIT")
    eb = rig.data.edit_bones
    inv = rig.matrix_world.inverted()
    for nm, cc in centres.items():
        b = eb.new(nm)
        b.head = inv @ cc
        b.tail = inv @ (cc + Vector((0, -0.025, 0)))
        b.parent = eb["Head"]
        b.use_deform = True
    bpy.ops.object.mode_set(mode="OBJECT")
    for g in list(eyes.vertex_groups):
        eyes.vertex_groups.remove(g)
    for nm, ids in (("LeftEye", left), ("RightEye", right)):
        g = eyes.vertex_groups.new(name=nm)
        g.add(ids, 1.0, "REPLACE")

def limit_weights(obj, max_influences=4):
    select_only([obj])
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=max_influences)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="BONE_DEFORM", lock_active=False)
    bpy.ops.object.mode_set(mode="OBJECT")

def ensure_armature_mod(obj, rig):
    for m in list(obj.modifiers):
        if m.type in ("ARMATURE", "MASK", "SUBSURF"):
            obj.modifiers.remove(m)
    m = obj.modifiers.new("Armature", "ARMATURE")
    m.object = rig
    obj.parent = rig
    obj.matrix_parent_inverse = rig.matrix_world.inverted()

def decimate(obj, ratio):
    if ratio >= 0.999:
        return
    if obj.data.shape_keys:
        select_only([obj])
        bpy.ops.object.shape_key_remove(all=True)
    m = obj.modifiers.new("Decimate", "DECIMATE")
    m.ratio = ratio
    m.use_collapse_triangulate = True
    # keep it ahead of the armature modifier
    while obj.modifiers[0].name != "Decimate":
        select_only([obj])
        bpy.ops.object.modifier_move_up(modifier="Decimate")
    apply_modifier(obj, "Decimate")

def add_rim(obj, thickness=0.004):
    """Thickness at the openings of a single-sided garment (rim only: no inner shell, so it costs few triangles)."""
    m = obj.modifiers.new("Rim", "SOLIDIFY")
    m.thickness = thickness
    m.offset = -1.0
    m.use_rim = True
    m.use_rim_only = True
    m.use_even_offset = False
    m.thickness_clamp = 0.5
    while obj.modifiers[0].name != "Rim":
        select_only([obj])
        bpy.ops.object.modifier_move_up(modifier="Rim")
    apply_modifier(obj, "Rim")

def duplicate(obj, name):
    o = obj.copy()
    o.data = obj.data.copy()
    o.name = name
    link(o)
    return o

def join(objs, name):
    objs = [o for o in objs if o is not None]
    if not objs:
        return None
    select_only(objs, objs[0])
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    o.data.name = name
    bm = bmesh.new()
    bm.from_mesh(o.data)
    ng = [f for f in bm.faces if len(f.verts) > 4]
    if ng:
        bmesh.ops.triangulate(bm, faces=ng)
        bm.to_mesh(o.data)
    bm.free()
    return o

# ---------------------------------------------------------------------------------------------------- assembling
LOD_RATIOS = (1.0, 0.4, 0.12)

def eye_texture(color, iris=None):
    src = os.path.join(data_dir(), "eyes", "materials", f"{color}_eye.png")
    out = os.path.join(TEXCACHE, f"eye_{color}.jpg" if iris is None else "eye_%s_%02d%02d%02d.jpg" % (color, *[int(c * 99) for c in iris]))
    if not os.path.exists(out):
        os.makedirs(TEXCACHE, exist_ok=True)
        px = load_px(src, 256)
        if iris is not None:
            # lane/rennick: recolour the iris (the saturated texels) to a natural dark brown, keeping its fibres
            rgb = px[..., :3]
            mx, mn = rgb.max(-1), rgb.min(-1)
            sat = (mx - mn) / np.maximum(mx, 1e-3)
            m = sat > 0.35
            lum = rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32)
            med = max(float(np.median(lum[m])), 1e-3) if m.any() else 0.3
            k = np.clip((sat - 0.25) / 0.2, 0, 1)[..., None]
            new = np.clip(lum / med, 0, 2)[..., None] ** 0.8 * np.array(iris, np.float32)
            px[..., :3] = rgb * (1 - k) + new * k
        save_px(px, out)
    return out

def small_normal(key, src, size):
    out = os.path.join(TEXCACHE, f"{key}.jpg")
    if src and (not os.path.exists(out) or os.environ.get("PEOPLE_RETEX")):
        os.makedirs(TEXCACHE, exist_ok=True)
        save_px(load_px(src, size), out, quality=88)
    return out if src else None

def remove_outliers(p, limit=0.25):
    """Delete garment vertices far from the body (a few MakeHuman clothes carry a stray vertex that fits metres away)."""
    me = p.proxy.data
    bvh = BVHTree.FromPolygons([p.proxy.matrix_world @ v.co for v in me.vertices], [tuple(pl.vertices) for pl in me.polygons])
    for o, g in p.clothes:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bad = []
        for v in bm.verts:
            hit = bvh.find_nearest(o.matrix_world @ v.co, limit)
            if hit[0] is None:
                bad.append(v)
        if bad:
            log("outliers removed", o.name, len(bad))
            bmesh.ops.delete(bm, geom=bad, context="VERTS")
            bm.to_mesh(o.data)
        bm.free()

def flatten_hair_under_hat(p, above_eyes):
    """Hair above the hat line is pressed onto the scalp (it is under the hat; otherwise it pokes through)."""
    ez = p.eyes.matrix_world.translation.z + float(coords(p.eyes)[:, 2].mean())
    bvh = body_mesh_eval(p.basemesh)
    mw = p.hair.matrix_world
    inv = mw.inverted()
    for v in p.hair.data.vertices:
        w = mw @ v.co
        if w.z > ez + above_eyes:
            loc, nrm, _, _ = bvh.find_nearest(w)
            if loc is not None:
                k = min(1.0, (w.z - ez - above_eyes) / 0.02)
                v.co = inv @ w.lerp(loc + nrm * 0.004, k)

def shrink_hair(p, k, min_lift=0.004):
    """Pull the hair toward the scalp by factor k (0.5 = half the volume): a close natural crop from a fuller asset."""
    bvh = body_mesh_eval(p.basemesh)
    mw = p.hair.matrix_world
    inv = mw.inverted()
    for v in p.hair.data.vertices:
        w = mw @ v.co
        loc, nrm, _, dist = bvh.find_nearest(w)
        if loc is None:
            continue
        lift = max((w - loc).length * k, min_lift)
        v.co = inv @ (loc + (w - loc).normalized() * lift)

def build_character(spec):
    """Build a character from a roster spec. Returns (rig, {lod: [objects]}) ready to export."""
    key = spec["name"]
    p = build_mpfb(spec)
    skin = build_skin(p)
    rig = p.rig
    rig.name = "Armature"
    rig.data.name = "Armature"
    # ------------------------------------------------ materials
    mats = {}
    mats["skin"] = new_material("skin", diff=make_skin_texture(key, spec["skin"], spec.get("skin_tex", 1024), spec.get("skin_tint")), rough=0.52)
    mats["eye"] = new_material("eye", diff=eye_texture(spec.get("eye_color", "brown"), spec.get("iris")), rough=0.08)
    brow_src = mhmat_textures(asset_path("eyebrows", spec.get("brows", "eyebrow001"))).get("diffuse")
    lash_src = mhmat_textures(asset_path("eyelashes", spec.get("lashes", "eyelashes01"))).get("diffuse")
    hair_tint = spec.get("hair", {}).get("tint")
    mats["brow"] = new_material("brow", diff=copy_alpha_texture(f"{key}_brow", brow_src, 256, spec.get("brow_tint", hair_tint)), alpha=True, blend="HASHED", double=True, rough=0.8)
    mats["lash"] = new_material("lash", diff=copy_alpha_texture(f"{key}_lash", lash_src, 256), alpha=True, blend="HASHED", double=True, rough=0.8)
    assign_single_material(skin, mats["skin"])
    assign_single_material(p.eyes, mats["eye"])
    assign_single_material(p.brows, mats["brow"])
    assign_single_material(p.lashes, mats["lash"])
    parts = {"head": [], "body": [skin], "clothes": []}
    if p.hair is not None:
        hs = spec["hair"]
        tx = mhmat_textures(asset_path("hair", hs["asset"]))
        hsize = hs.get("tex", 512 if spec.get("hero") else 256)
        hd = copy_alpha_texture(f"{key}_hair", tx["diffuse"], hsize, hs.get("tint"))
        hn = small_normal(f"{key}_hair_nor", tx.get("normal"), hsize // 2)
        mats["hair"] = new_material("hair", diff=hd, nor=hn, alpha=True, blend="HASHED", double=True, rough=hs.get("rough", 0.62))
        assign_single_material(p.hair, mats["hair"])
        if hs.get("shrink"):
            shrink_hair(p, hs["shrink"], hs.get("min_lift", 0.004))
        if any(g.get("hat") for _, g in p.clothes) or "peaked_cap" in spec.get("extras", []) or "uniform_cap" in spec.get("extras", []):
            flatten_hair_under_hat(p, spec.get("hat_line", 0.035))
        decimate(p.hair, min(1.0, hs.get("budget", 900) / max(tri_count(p.hair), 1)))
    cloth_tris = sum(tri_count(o) for o, _ in p.clothes)
    gear_est = {"backpack": 1300, "belt_kit": 450, "peaked_cap": 420, "scarf": 300, "uniform_cap": 700, "duty_belt": 900,
                "shoulder_radio": 150}
    fixed = tri_count(skin) + min(tri_count(p.hair) if p.hair else 0, 900) + tri_count(p.eyes) + tri_count(p.brows) + tri_count(p.lashes)
    budget = spec.get("clothes_budget", min(3300, spec.get("tri_budget", 8100) - fixed - sum(gear_est.get(e, 400) for e in spec.get("extras", []))))
    cloth_ratio = min(1.0, max(budget, 1200) / max(cloth_tris, 1))
    log("clothes tris", cloth_tris, "ratio", round(cloth_ratio, 3), "head skin", tri_count(skin))
    remove_outliers(p)
    garments = []
    for i, (o, g) in enumerate(p.clothes):
        mk = g.get("mat", g["asset"])
        if g.get("lower") and "dz" in g["lower"]:
            g = dict(g)
            g["lower"] = dict(g["lower"], z=(rig.matrix_world @ rig.data.bones["pelvis"].head_local).z + g["lower"]["dz"])
        tex = make_garment_textures(f"{key}_{mk}", asset_path("clothes", g["asset"]), g, obj=o)
        garments.append((o, tex))
        decimate(o, g.get("decimate", cloth_ratio))
        if g.get("rim", True):
            add_rim(o, g.get("thickness", 0.004))
        o["node"] = g.get("node", "clothes")
    # extras modelled in Blender (backpack, belt kit, scarf...) share the clothes atlas
    import people_gear
    import people_rennick  # noqa: registers lane/rennick gear (uniform caps, duty belts, radios) in people_gear.BUILDERS
    for extra in spec.get("extras", []):
        for o, tex, node in people_gear.build(extra, p, spec):
            log("gear", extra, o.name, tri_count(o))
            o["node"] = node
            garments.append((o, tex))
            p.clothes.append((o, {"asset": extra}))
    if garments:
        mats["cloth"] = build_cloth_atlas(key, garments, spec.get("cloth_tex", 1024))
    # ------------------------------------------------ rig: names, eye bones, weights
    meshes = [skin, p.eyes, p.brows, p.lashes] + ([p.hair] if p.hair else []) + [o for o, _ in p.clothes]
    rename_bones(rig, meshes)
    add_eye_bones(rig, p.eyes)
    for o in meshes:
        ensure_armature_mod(o, rig)
        limit_weights(o)
    # ------------------------------------------------ split skin into head and body nodes
    select_only([skin])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    lay = skin.data.attributes.get("headpart")
    if lay is not None:
        vals = [0] * len(skin.data.polygons)
        lay.data.foreach_get("value", vals)
        for pl, v in zip(skin.data.polygons, vals):
            pl.select = v == 1
    # keep normals continuous across the cut
    skin.data.shade_smooth()
    select_only([skin])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    head_skin = [o for o in bpy.context.selected_objects if o is not skin][0]
    head_skin.name = "head_skin"
    select_only([skin])
    bpy.ops.object.shape_key_remove(all=True)
    parts["body"] = [skin]
    parts["head"] = [head_skin, p.eyes, p.brows, p.lashes] + ([p.hair] if p.hair else [])
    gear = {}
    for o, g in p.clothes:
        gear.setdefault(o["node"], []).append(o)
    # ------------------------------------------------ LODs
    lods = {}
    sources = {"head": parts["head"], "body": parts["body"]}
    sources.update(gear)
    for lod, ratio in enumerate(LOD_RATIOS):
        lods[lod] = []
        for node, objs in sources.items():
            copies = []
            for o in objs:
                if lod == 2 and o in (p.brows, p.lashes):
                    continue
                if lod >= 1 and o is p.lashes:
                    continue
                c = duplicate(o, f"{o.name}_l{lod}")
                if lod > 0:
                    r = ratio
                    if o is p.eyes:
                        r = 1.0 if lod == 1 else 0.5
                    if o is p.hair:
                        r = max(ratio * 1.6, 0.25)
                    decimate(c, r)
                copies.append(c)
            j = join(copies, f"{node}_LOD{lod}")
            if j is not None:
                if lod > 0 and j.data.shape_keys:
                    select_only([j]); bpy.ops.object.shape_key_remove(all=True)
                lods[lod].append(j)
    # remove the working objects (originals) from the export
    keep = {o for l in lods.values() for o in l} | {rig}
    for o in list(bpy.data.objects):
        if o not in keep:
            bpy.data.objects.remove(o, do_unlink=True)
    # feet on the ground: lowest point of LOD0 at z = 0
    zs = np.array([(o.matrix_world @ v.co).z for o in lods[0] for v in o.data.vertices])
    zmin = float(np.percentile(zs, 0.05))
    log("zmin", round(zmin, 4), "lowest", round(float(zs.min()), 4), "highest", round(float(zs.max()), 4))
    rig.location.z -= zmin
    return rig, lods, mats

def stats(rig, lods):
    out = {}
    for lod, objs in lods.items():
        out[lod] = {o.name: tri_count(o) for o in objs}
        out[lod]["total"] = sum(tri_count(o) for o in objs)
    return out

def export_glb(path, rig, objs, animations=False):
    select_only([rig] + list(objs), rig)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_yup=True,
        export_apply=False, export_skins=True, export_morph=True, export_morph_normal=False,
        export_animations=animations, export_def_bones=False, export_image_format="AUTO",
        export_jpeg_quality=85, export_texcoords=True, export_normals=True, export_tangents=True,
        export_materials="EXPORT", export_extras=False, export_lights=False, export_cameras=False,
        export_all_influences=False, export_rest_position_armature=True)

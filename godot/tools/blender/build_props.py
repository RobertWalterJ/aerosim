# The wildlife brief's props (godot/docs/CLAUDE-WILDLIFE-ASSETS.md on lane/notify): night pen, troughs and racks, evidence,
# the advisory sign and the farm odds and ends. Modelled in Blender from simple parts with bevels, textured with the repo's
# photographed CC0 sets (assets/textures: barnwood, postwood, straw, wool, roofsteel, mudtrack) and plain PBR metals.
#   blender -b --python build_props.py -- [only=<name prefix>]
# Writes godot/assets/models/wildlife/<name>.glb (+Z front, metres, origin at the base; LOD0 and LOD1 nodes; named moving
# parts; "-colonly" collision boxes on the pen, gates and trough).
import sys, os, math, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix, Euler
import blib

args = dict(a.split("=", 1) for a in sys.argv[sys.argv.index("--") + 1:] if "=" in a) if "--" in sys.argv else {}
GODOT = os.path.normpath(os.path.join(HERE, "..", ".."))
TEX = os.path.join(GODOT, "assets", "textures")
CACHE = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", "_tools", "blender-cache", "polyhaven"))
OUT = os.path.join(GODOT, "assets", "models", "wildlife")
WORK = os.path.join(os.environ.get("TEMP", "."), "aerosim_animals", "props")
os.makedirs(OUT, exist_ok=True); os.makedirs(WORK, exist_ok=True)
RNG = np.random.default_rng(7)

# ------------------------------------------------------------------ materials
_M = {}
def img(path, data=False, size=512):
    """The repo's 1k sets, halved for the props (they are small things; keeps each file well under a megabyte)."""
    key = os.path.basename(path) + "_%d" % size
    if key in bpy.data.images: return bpy.data.images[key]
    im = bpy.data.images.load(path, check_existing=False)
    if data: im.colorspace_settings.name = "Non-Color"
    if im.size[0] > size:
        im.scale(size, size)
    im.name = key
    im.pack()
    return im

def mat(key):
    """PBR materials named by what they are (the glb keeps the names): photographed sets for wood, straw, wool, galvanised
    steel and mud; flat PBR for brass, salt, water, paint, glass and flame."""
    if key in _M: return _M[key]
    m = bpy.data.materials.new(key); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    sets = {"wood": "barnwood", "post": "postwood", "straw": "straw", "wool": "wool", "galv": "roofsteel", "mud": "mudtrack", "board": "barnwood"}
    if key in sets:
        base = os.path.join(TEX, sets[key])
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = img(base + "_diff.jpg")
        nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
        if os.path.exists(base + "_nor.jpg"):
            tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = img(base + "_nor.jpg", True)
            nm = nt.nodes.new("ShaderNodeNormalMap"); nt.links.new(tn.outputs["Color"], nm.inputs["Color"]); nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
        if os.path.exists(base + "_arm.jpg"):
            ta = nt.nodes.new("ShaderNodeTexImage"); ta.image = img(base + "_arm.jpg", True)
            sp = nt.nodes.new("ShaderNodeSeparateColor"); nt.links.new(ta.outputs["Color"], sp.inputs["Color"])
            nt.links.new(sp.outputs["Green"], b.inputs["Roughness"]); nt.links.new(sp.outputs["Blue"], b.inputs["Metallic"])
        else:
            b.inputs["Roughness"].default_value = 0.85
        if key == "board":                       # painted board: dark green paint over the boards
            mx = nt.nodes.new("ShaderNodeMix"); mx.data_type = "RGBA"; mx.blend_type = "MULTIPLY"; mx.inputs["Factor"].default_value = 0.85
            nt.links.new(t.outputs["Color"], mx.inputs[6]); mx.inputs[7].default_value = (0.09, 0.2, 0.12, 1)
            nt.links.new(mx.outputs[2], b.inputs["Base Color"])
    else:
        P = {"brass": ((0.78, 0.56, 0.24), 1.0, 0.32), "leather": ((0.24, 0.13, 0.07), 0.0, 0.6), "salt": ((0.86, 0.78, 0.74), 0.0, 0.75),
             "water": ((0.03, 0.04, 0.035), 0.0, 0.04), "paint": ((0.86, 0.84, 0.76), 0.0, 0.6), "glass": ((0.8, 0.85, 0.8), 0.0, 0.05),
             "flame": ((1.0, 0.7, 0.3), 0.0, 0.5), "red": ((0.55, 0.06, 0.04), 0.0, 0.5), "steel": ((0.5, 0.5, 0.52), 1.0, 0.45),
             "black": ((0.03, 0.03, 0.03), 0.0, 0.5), "plastic": ((0.12, 0.13, 0.12), 0.0, 0.45), "orange": ((0.85, 0.35, 0.05), 0.0, 0.5),
             "zinc": ((0.62, 0.63, 0.64), 1.0, 0.38), "furtuft": ((0.42, 0.40, 0.36), 0.0, 0.9), "rope": ((0.62, 0.52, 0.34), 0.0, 0.9), "canvas": ((0.42, 0.38, 0.3), 0.0, 0.9)}[key]
        b.inputs["Base Color"].default_value = tuple(P[0]) + (1,)
        b.inputs["Metallic"].default_value = P[1]; b.inputs["Roughness"].default_value = P[2]
        if key == "flame":
            b.inputs["Emission Color"].default_value = (1.0, 0.62, 0.25, 1); b.inputs["Emission Strength"].default_value = 6.0
        if key == "glass":
            b.inputs["Alpha"].default_value = 0.35; m.blend_method = "BLEND"
    _M[key] = m
    return m

TILE = {"wood": 1.5, "post": 1.0, "straw": 0.5, "wool": 0.45, "galv": 1.12, "mud": 2.0, "board": 1.5}

# ------------------------------------------------------------------ parts
class Part:
    def __init__(self):
        self.bm = bmesh.new(); self.uv = self.bm.loops.layers.uv.new("UVMap"); self.mats = []
    def _mi(self, key):
        if key not in self.mats: self.mats.append(key)
        return self.mats.index(key)
    def _finish(self, geom, key, grain, tile):
        faces = [g for g in geom if isinstance(g, bmesh.types.BMFace)]
        mi = self._mi(key)
        tile = tile or TILE.get(key, 1.0)
        ga = Vector(grain).normalized()
        for f in faces:
            f.material_index = mi
            n = f.normal
            # project on the plane of the face's main axis, u along the grain where the grain lies in that plane
            ax = max(range(3), key=lambda i: abs(n[i]))
            u_ax = ga if abs(ga[ax]) < 0.7 else Vector((0, 0, 1)) if ax != 2 else Vector((1, 0, 0))
            v_ax = n.cross(u_ax).normalized() if n.cross(u_ax).length > 1e-6 else Vector((0, 1, 0))
            for l in f.loops:
                p = l.vert.co
                l[self.uv].uv = (p.dot(u_ax) / tile, p.dot(v_ax) / tile)
        return faces
    def box(self, size, loc, rot=(0, 0, 0), key="wood", bevel=0.006, grain=(1, 0, 0), tile=None):
        before = set(self.bm.faces)
        r = bmesh.ops.create_cube(self.bm, size=1.0)
        vs = r["verts"]
        bmesh.ops.scale(self.bm, vec=Vector(size), verts=vs)
        M = Matrix.Translation(Vector(loc)) @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()
        bmesh.ops.transform(self.bm, matrix=M, verts=vs)
        faces = list({f for v in vs for f in v.link_faces})
        if bevel > 0:
            edges = list({e for v in vs for e in v.link_edges})
            bmesh.ops.bevel(self.bm, geom=edges, offset=bevel, segments=1, affect="EDGES", profile=0.5)
            faces = [f for f in self.bm.faces if f not in before]
        g = (Euler([math.radians(a) for a in rot]).to_matrix() @ Vector(grain))
        self._finish(faces, key, g, tile)
    def cyl(self, r1, r2, h, loc, rot=(0, 0, 0), key="post", seg=10, caps=True, grain=(0, 0, 1), tile=None):
        res = bmesh.ops.create_cone(self.bm, cap_ends=caps, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=h)
        vs = res["verts"]
        bmesh.ops.translate(self.bm, vec=Vector((0, 0, h / 2)), verts=vs)
        M = Matrix.Translation(Vector(loc)) @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()
        bmesh.ops.transform(self.bm, matrix=M, verts=vs)
        faces = list({f for v in vs for f in v.link_faces})
        g = (Euler([math.radians(a) for a in rot]).to_matrix() @ Vector(grain))
        self._finish(faces, key, g, tile)
    def sphere(self, r, loc, scale=(1, 1, 1), key="wool", seg=10, noise=0.0, seed=0, tile=None):
        res = bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=max(4, seg // 2 + 1), radius=r)
        vs = res["verts"]
        rng = np.random.default_rng(seed)
        for v in vs:
            v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2]))
            if noise: v.co += v.co.normalized() * float(rng.normal(0, noise))
        bmesh.ops.translate(self.bm, vec=Vector(loc), verts=vs)
        faces = list({f for v in vs for f in v.link_faces})
        self._finish(faces, key, (1, 0, 0), tile)
    def quad(self, w, d, loc, key, rot=(0, 0, 0)):
        vs = [self.bm.verts.new(Vector(p)) for p in ((-w / 2, -d / 2, 0), (w / 2, -d / 2, 0), (w / 2, d / 2, 0), (-w / 2, d / 2, 0))]
        f = self.bm.faces.new(vs)
        M = Matrix.Translation(Vector(loc)) @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()
        bmesh.ops.transform(self.bm, matrix=M, verts=vs)
        f.material_index = self._mi(key)
        for l, uv in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
            l[self.uv].uv = uv
        return f
    def mesh_from(self, me, M, key, tile=None):
        """Adds a Blender mesh (text, curves) at matrix M."""
        tmp = bmesh.new(); tmp.from_mesh(me); tmp.transform(M)
        me2 = bpy.data.meshes.new("t"); tmp.to_mesh(me2); tmp.free()
        n0 = len(self.bm.faces)
        self.bm.from_mesh(me2)
        self.bm.faces.ensure_lookup_table()
        self._finish(self.bm.faces[n0:], key, (1, 0, 0), tile)
    def obj(self, name, parent=None, loc=(0, 0, 0)):
        me = bpy.data.meshes.new(name)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces[:])
        self.bm.to_mesh(me); self.bm.free()
        for k in self.mats: me.materials.append(mat(k))
        for p in me.polygons: p.use_smooth = False
        ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
        if parent: ob.parent = parent
        # convert to the frame Blender exports (+Z front in Godot is Blender -Y): parts are modelled with +Y forward
        # (lat, fwd, up) and turned here
        me.transform(Matrix.Rotation(math.pi, 4, "Z"))
        ob.location = Matrix.Rotation(math.pi, 4, "Z") @ Vector(loc)
        return ob

def collider(name, size, loc, parent=None):
    bm = bmesh.new(); r = bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=r["verts"]); bmesh.ops.translate(bm, vec=Vector(loc), verts=r["verts"])
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    me.transform(Matrix.Rotation(math.pi, 4, "Z"))
    ob = bpy.data.objects.new(name + "-colonly", me); bpy.context.scene.collection.objects.link(ob)
    if parent: ob.parent = parent
    return ob

def root(name):
    ob = bpy.data.objects.new(name, None); bpy.context.scene.collection.objects.link(ob)
    return ob

def lod1(ob, ratio=0.45):
    """A lighter copy for the middle distance (decimated, same materials)."""
    c = ob.copy(); c.data = ob.data.copy(); c.name = ob.name.replace("_LOD0", "") + "_LOD1"
    bpy.context.scene.collection.objects.link(c)
    blib.set_active(c)
    m = c.modifiers.new("d", "DECIMATE"); m.ratio = ratio
    bpy.ops.object.modifier_apply(modifier="d")
    return c

def export(name, objs):
    for o in bpy.context.scene.objects: o.select_set(False)
    for o in objs: o.select_set(True)
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True,
                              export_image_format="JPEG", export_jpeg_quality=85, export_animations=False, export_materials="EXPORT")
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs if o.type == "MESH" and "-colonly" not in o.name and "LOD1" not in o.name)
    print("PROP", name, "%.2f MB" % (os.path.getsize(path) / 1e6), tris, "tris")
    return {"name": name, "tris_lod0": tris, "bytes": os.path.getsize(path)}

# ------------------------------------------------------------------ the props (lat, fwd, up); Part.obj turns them to face +Z
def plank_noise(i):
    return float(RNG.uniform(-1, 1))

def trough():
    R = root("sheep_trough_a"); p = Part()
    L, W, H = 1.5, 0.42, 0.32
    for i, z in enumerate((0.10, 0.20)):                       # side boards, two per side
        for sg in (1, -1):
            p.box((0.03, L, 0.1), (sg * W / 2, 0, z + 0.03), (plank_noise(i) * 0.8, 0, 0), "wood", grain=(0, 1, 0))
    for sg in (1, -1):
        p.box((W, 0.03, 0.22), (0, sg * L / 2, 0.16), (0, 0, 0), "wood", grain=(1, 0, 0))
        for sl in (1, -1):
            p.box((0.06, 0.06, 0.12), (sl * (W / 2 + 0.01), sg * (L / 2 - 0.08), 0.06), (0, 0, 0), "post", grain=(0, 0, 1))
    p.box((W, L, 0.03), (0, 0, 0.065), (0, 0, 0), "wood", grain=(0, 1, 0))
    p.quad(W - 0.04, L - 0.04, (0, 0, 0.215), "water")
    p.box((0.02, L * 0.98, 0.02), (0, 0, 0.275), (0, 0, 0), "galv", bevel=0.002)      # a steel strap down the middle
    ob = p.obj("sheep_trough_a_LOD0", R)
    c = collider("hull0", (W + 0.04, L, H), (0, 0, H / 2), R)
    return [R, ob, lod1(ob, 0.6), c]

def hay(p, c, r, n=40, h=0.18, seed=3):
    """A loose heap of hay: a lumpy mound plus stalks."""
    p.sphere(r, c, (1.0, 1.0, h / r), "straw", seg=14, noise=r * 0.06, seed=seed)
    rng = np.random.default_rng(seed)
    for i in range(n):
        a = rng.uniform(0, 2 * math.pi); d = rng.uniform(0, r)
        base = (c[0] + math.cos(a) * d * 0.9, c[1] + math.sin(a) * d * 0.9, c[2] + h * 0.5)
        p.box((0.004, 0.18, 0.004), base, (rng.uniform(-40, 40), rng.uniform(-30, 30), rng.uniform(0, 180)), "straw", bevel=0, grain=(0, 1, 0), tile=0.5)

def hay_rack():
    R = root("sheep_hay_rack_a"); p = Part()
    L = 1.2
    for sx in (1, -1):
        for sy in (1, -1):
            p.box((0.06, 0.06, 1.0), (sx * 0.3, sy * L / 2, 0.5), (0, 0, 0), "post", grain=(0, 0, 1))
    for sy in (1, -1):
        p.box((0.6, 0.05, 0.08), (0, sy * L / 2, 0.92), (0, 0, 0), "wood")
        p.box((0.6, 0.05, 0.08), (0, sy * L / 2, 0.38), (0, 0, 0), "wood")
    # V of slats: the sheep pull hay through them
    for i in range(9):
        y = -L / 2 + 0.1 + i * (L - 0.2) / 8
        for sx in (1, -1):
            p.box((0.03, 0.02, 0.62), (sx * 0.15, y, 0.66), (0, sx * 22, 0), "wood", bevel=0.003, grain=(0, 0, 1))
    p.box((0.32, L, 0.03), (0, 0, 0.36), (0, 0, 0), "wood", grain=(0, 1, 0))           # trough board below
    hay(p, (0, 0, 0.62), 0.25, 60, 0.32, 5)
    ob = p.obj("sheep_hay_rack_a_LOD0", R)
    c = collider("hull0", (0.66, L + 0.06, 1.0), (0, 0, 0.5), R)
    return [R, ob, lod1(ob, 0.5), c]

def salt_lick():
    R = root("sheep_salt_lick_a"); p = Part()
    p.cyl(0.17, 0.15, 0.32, (0, 0, 0), (0, 0, 0), "post", seg=14, grain=(0, 0, 1), tile=0.5)    # stump
    p.box((0.22, 0.22, 0.12), (0, 0, 0.38), (0, 0, 8), "salt", bevel=0.03)
    ob = p.obj("sheep_salt_lick_a_LOD0", R)
    return [R, ob, lod1(ob, 0.6)]

def bell():
    R = root("sheep_bell_a"); p = Part()
    p.cyl(0.028, 0.017, 0.055, (0, 0, 0.0), (0, 0, 0), "brass", seg=16, caps=False)
    p.cyl(0.017, 0.006, 0.012, (0, 0, 0.055), (0, 0, 0), "brass", seg=16)
    p.sphere(0.008, (0, 0, 0.006), key="brass", seg=8)                                 # clapper
    p.cyl(0.003, 0.003, 0.02, (0, 0, 0.065), (0, 0, 0), "brass", seg=6)
    # leather collar: an upright loop the bell hangs from at its lowest point
    for k in range(20):
        a = 2 * math.pi * k / 20
        p.box((0.03, 0.025, 0.006), (math.cos(a) * 0.09, 0.0, 0.165 + math.sin(a) * 0.09), (0, -math.degrees(a) + 90, 0), "leather", bevel=0.001)
    ob = p.obj("sheep_bell_a_LOD0", R)
    return [R, ob]

def wool_on_wire(v):
    R = root("wool_on_wire_%s" % v); p = Part()
    rng = np.random.default_rng(11 + ord(v))
    for z, sag in ((0.0, 0.0), (0.0, 0.0)) if False else ((0.0, 0.0),):
        pass
    # two strands of barbed wire 1.2 m with barbs, wool snagged on barbs
    for zi, z in enumerate((0.0, 0.25)):
        p.cyl(0.0018, 0.0018, 1.2, (-0.6, 0, z), (0, 90, 0), "galv", seg=5, caps=False)
        for k in range(8):
            x = -0.55 + k * 0.15
            for a in (30, 120):
                p.box((0.002, 0.03, 0.002), (x, 0, z), (a, 0, rng.uniform(0, 180)), "galv", bevel=0)
    for k in range(3 if v == "a" else 5):
        x = rng.uniform(-0.45, 0.45); z = rng.choice([0.0, 0.25])
        for j in range(4):
            p.sphere(0.022, (x + rng.normal(0, 0.012), rng.normal(0, 0.008), z - 0.012 - j * 0.012), (1.0, 0.8, 1.3), "wool", seg=8, noise=0.004, seed=k * 7 + j)
    ob = p.obj("wool_on_wire_%s_LOD0" % v, R)
    return [R, ob]

def print_decal(kind, v):
    """Tracks in soft ground: a thin quad textured with a generated print map (darker damp mud in the hollows, alpha
    cut-out) and a normal map, laid 5 mm above the ground. Four prints in a walking line."""
    S = 512
    yy, xx = np.mgrid[0:S, 0:S] / S
    depth = np.zeros((S, S))
    rng = np.random.default_rng(31 + ord(v) + (7 if kind == "wolf" else 0))
    def blob(cx, cy, rx, ry, d, ang=0.0):
        c, s = math.cos(ang), math.sin(ang)
        X = (xx - cx) * c + (yy - cy) * s; Y = -(xx - cx) * s + (yy - cy) * c
        r = (X / rx) ** 2 + (Y / ry) ** 2
        return d * np.clip(1 - r, 0, 1) ** 0.7
    steps = [(0.30, 0.15), (0.70, 0.38), (0.32, 0.62), (0.68, 0.86)] if v == "a" else [(0.4, 0.15), (0.6, 0.38), (0.42, 0.62), (0.58, 0.86)]
    for i, (cx, cy) in enumerate(steps):
        cx += rng.normal(0, 0.01); a = rng.normal(0, 0.12)
        if kind == "wolf":
            depth = np.maximum(depth, blob(cx, cy + 0.02, 0.055, 0.045, 1.0, a))                 # heel pad
            for dx, dy in ((-0.05, -0.055), (-0.018, -0.08), (0.018, -0.08), (0.05, -0.055)):   # four toes
                depth = np.maximum(depth, blob(cx + dx, cy + dy, 0.019, 0.026, 0.9, a))
                depth = np.maximum(depth, blob(cx + dx * 1.1, cy + dy - 0.035, 0.005, 0.008, 0.8, a))   # claw marks
        else:
            for dx in (-0.02, 0.02):                                                            # cloven hoof
                depth = np.maximum(depth, blob(cx + dx, cy, 0.017, 0.035, 1.0, a + dx * 3))
    depth += rng.normal(0, 0.02, depth.shape) * (depth > 0.05)
    alpha = np.clip(depth * 3, 0, 1)
    rim = np.clip(np.abs(np.gradient(depth)[0]) + np.abs(np.gradient(depth)[1]), 0, 1) * 20
    col = np.stack([0.20 - 0.08 * depth, 0.15 - 0.06 * depth, 0.10 - 0.04 * depth], -1)
    col = col + np.clip(rim, 0, 1)[..., None] * 0.06
    rgba = np.concatenate([np.clip(col, 0, 1), alpha[..., None]], -1)
    gy, gx = np.gradient(-depth * 6.0)
    nrm = np.stack([-gx, -gy, np.ones_like(gx)], -1); nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    nimg = np.concatenate([nrm * 0.5 + 0.5, np.ones((S, S, 1))], -1)
    name = "%s_%s" % ("wolf_track" if kind == "wolf" else "sheep_print", v)
    ia = bpy.data.images.new(name + "_albedo", S, S, alpha=True); ia.pixels.foreach_set(rgba.astype(np.float32).ravel())
    ia.filepath_raw = os.path.join(WORK, name + "_albedo.png"); ia.file_format = "PNG"; ia.save()
    inn = bpy.data.images.new(name + "_normal", S, S, is_data=True); inn.colorspace_settings.name = "Non-Color"
    inn.pixels.foreach_set(nimg.astype(np.float32).ravel()); inn.filepath_raw = os.path.join(WORK, name + "_normal.png"); inn.file_format = "PNG"; inn.save()
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    ta = nt.nodes.new("ShaderNodeTexImage"); ta.image = ia
    nt.links.new(ta.outputs["Color"], b.inputs["Base Color"]); nt.links.new(ta.outputs["Alpha"], b.inputs["Alpha"])
    tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = inn
    nm = nt.nodes.new("ShaderNodeNormalMap"); nt.links.new(tn.outputs["Color"], nm.inputs["Color"]); nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = 0.55
    m.blend_method = "CLIP"
    _M[name] = m
    R = root(name); p = Part()
    length = 1.6 if kind == "wolf" else 1.0
    p.quad(length * 0.5, length, (0, 0, 0.005), name)
    ob = p.obj(name + "_LOD0", R)
    return [R, ob]

def pen(open_=False):
    """Timber night pen 6 x 4 m: posts every 2 m, three rails, a 1.8 m gate in the front (+Z) side. Panels are named
    nodes (panel_back, panel_left, panel_right, panel_front_l, panel_front_r), the gate is `gate` with its pivot on
    the hinge post."""
    name = "night_pen_a_open" if open_ else "night_pen_a"
    R = root(name)
    objs = [R]
    W, D = 6.0, 4.0
    def panel(nm, a, b, rails=3):
        p = Part()
        a = Vector(a); b = Vector(b); d = b - a; ln = d.length
        n = max(1, round(ln / 2.0))
        for k in range(n + 1):
            q = a + d * (k / n)
            p.box((0.1, 0.1, 1.2), (q.x, q.y, 0.6), (0, 0, RNG.uniform(-3, 3)), "post", bevel=0.01, grain=(0, 0, 1))
        ang = math.degrees(math.atan2(d.y, d.x))
        for r in range(rails):
            z = 0.3 + r * 0.32
            mid = (a + b) / 2
            p.box((ln, 0.035, 0.14), (mid.x, mid.y, z), (RNG.uniform(-0.6, 0.6), 0, ang), "wood", bevel=0.005, grain=(1, 0, 0))
        ob = p.obj(name + "_" + nm, R)
        c = collider(nm + "_hull", (abs(d.x) + 0.12 if abs(d.x) > 0.01 else 0.12, abs(d.y) + 0.12 if abs(d.y) > 0.01 else 0.12, 1.2), ((a + b) / 2).to_tuple()[:2] + (0.6,), R)
        objs.extend([ob, c])
    panel("panel_back", (-W / 2, -D / 2), (W / 2, -D / 2))
    panel("panel_left", (-W / 2, -D / 2), (-W / 2, D / 2))
    panel("panel_right", (W / 2, -D / 2), (W / 2, D / 2))
    panel("panel_front_l", (-W / 2, D / 2), (-0.9, D / 2))
    panel("panel_front_r", (0.9, D / 2), (W / 2, D / 2))
    g = gate_part(1.8)
    gob = g.obj(name + "_gate", R, loc=(-0.9, D / 2, 0))
    if open_:
        gob.rotation_euler = (0, 0, math.radians(-100))
    objs.append(gob)
    straw = Part(); straw.box((W - 0.3, D - 0.3, 0.02), (0, 0, 0.01), (0, 0, 0), "straw", bevel=0.0, grain=(1, 0, 0), tile=0.5)
    objs.append(straw.obj(name + "_straw", R))
    return objs

def gate_part(w=1.8, key="wood"):
    """A timber gate: hinge at x = 0, latch end at x = w; five bars, a diagonal brace, two uprights."""
    p = Part()
    for k in range(5):
        p.box((w, 0.03, 0.09), (w / 2, 0, 0.25 + k * 0.2), (0, 0, 0), key, bevel=0.004)
    for x in (0.04, w - 0.04):
        p.box((0.07, 0.04, 1.0), (x, 0, 0.62), (0, 0, 0), key, bevel=0.005, grain=(0, 0, 1))
    p.box((w * 1.08, 0.03, 0.08), (w / 2, 0.01, 0.65), (0, -math.degrees(math.atan2(0.8, w)), 0), key, bevel=0.004)
    for z in (0.35, 0.95):
        p.box((0.12, 0.05, 0.02), (0.05, 0, z), (0, 0, 0), "steel", bevel=0.002)          # hinges
    p.box((0.08, 0.06, 0.03), (w - 0.02, 0, 0.9), (0, 0, 0), "steel", bevel=0.002)        # latch
    return p

def pen_gate():
    R = root("pen_gate_a")
    g = gate_part(1.8)
    ob = g.obj("pen_gate_a_gate", R)
    c = collider("hull0", (1.8, 0.08, 1.1), (0.9, 0, 0.6), R)
    return [R, ob, c]

def pasture_gate():
    R = root("pasture_gate_a")
    objs = [R]
    p = Part()
    for x in (-0.1, 3.7):
        p.cyl(0.09, 0.08, 1.45, (x, 0, 0), (0, 0, 0), "post", seg=10)
    objs.append(p.obj("pasture_gate_a_posts", R))
    g = gate_part(3.6)
    objs.append(g.obj("pasture_gate_a_gate", R))
    objs.append(collider("hull0", (3.9, 0.12, 1.2), (1.8, 0, 0.6), R))
    return objs

def sign():
    """A small hand-painted advisory board on a stake. No threat language."""
    R = root("farm_warning_sign_a"); p = Part()
    p.box((0.06, 0.06, 1.3), (0, -0.03, 0.65), (0, 0, 0), "post", bevel=0.008, grain=(0, 0, 1))
    p.box((0.62, 0.025, 0.42), (0, 0.0, 1.05), (0, 0, 0), "board", bevel=0.006, grain=(1, 0, 0))
    lines = ["WILDLIFE ADVISORY", "Wolf seen near the", "west pasture.", "Sheep penned at night.", "Dogs on leads please."]
    for i, t in enumerate(lines):
        cu = bpy.data.curves.new("txt", "FONT"); cu.body = t; cu.align_x = "CENTER"; cu.resolution_u = 2
        cu.size = 0.055 if i == 0 else 0.042
        tob = bpy.data.objects.new("txt", cu); bpy.context.scene.collection.objects.link(tob)
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(tob.evaluated_get(dg))
        bpy.data.objects.remove(tob)
        # text is made in the XY plane facing +Z; stand it up facing +Y (the sign's front here) and readable from there
        M = Matrix.Translation((0.0, 0.0135, 1.19 - i * 0.07 - (0.0 if i == 0 else 0.015))) @ Matrix.Rotation(math.pi, 4, "Z") @ Matrix.Rotation(math.radians(90), 4, "X")
        p.mesh_from(me, M, "paint" if i else "red")
    ob = p.obj("farm_warning_sign_a_LOD0", R)
    return [R, ob]

def hay_bale_small():
    R = root("hay_bale_small_a"); p = Part()
    p.box((0.9, 0.45, 0.35), (0, 0, 0.175), (0, 0, 0), "straw", bevel=0.03, grain=(1, 0, 0), tile=0.5)
    for x in (-0.22, 0.22):
        p.box((0.012, 0.47, 0.37), (x, 0, 0.175), (0, 0, 0), "orange", bevel=0.002)
    hay(p, (0, 0, 0.33), 0.2, 30, 0.04, 9)
    ob = p.obj("hay_bale_small_a_LOD0", R)
    return [R, ob, lod1(ob, 0.5)]

def straw_patch():
    R = root("straw_patch_a"); p = Part()
    hay(p, (0, 0, 0.0), 0.9, 160, 0.05, 13)
    ob = p.obj("straw_patch_a_LOD0", R)
    return [R, ob, lod1(ob, 0.4)]

def bucket():
    R = root("sheep_feed_bucket_a"); p = Part()
    p.cyl(0.13, 0.15, 0.3, (0, 0, 0), (0, 0, 0), "zinc", seg=20, caps=False)
    p.cyl(0.13, 0.13, 0.008, (0, 0, 0.0), (0, 0, 0), "zinc", seg=20)
    p.cyl(0.143, 0.143, 0.01, (0, 0, 0.24), (0, 0, 0), "straw", seg=20)                   # feed nuts inside
    for k in range(12):                                                                    # handle
        a = math.pi * k / 11
        p.box((0.006, 0.006, 0.03), (math.cos(a) * 0.15, 0, 0.3 + math.sin(a) * 0.09), (0, -math.degrees(a), 0), "steel", bevel=0)
    p.cyl(0.05, 0.05, 0.08, (0.25, 0.05, 0.0), (0, 0, 0), "plastic", seg=12, caps=False)    # scoop
    p.box((0.12, 0.02, 0.02), (0.33, 0.05, 0.03), (0, 0, 0), "plastic")
    ob = p.obj("sheep_feed_bucket_a_LOD0", R)
    return [R, ob]

def fur_tufts():
    """Tufts of grey-brown winter wolf fur caught in the grass: soft clumps of fine hair."""
    R = root("wolf_ear_tuft_a"); p = Part()
    rng = np.random.default_rng(41)
    for k in range(6):
        c = (rng.normal(0, 0.12), rng.normal(0, 0.12), 0.012)
        for j in range(3):
            p.sphere(0.018, (c[0] + rng.normal(0, 0.008), c[1] + rng.normal(0, 0.008), 0.012), (1.6, 0.8, 0.5), "furtuft", seg=8, noise=0.004, seed=k * 5 + j)
    ob = p.obj("wolf_ear_tuft_a_LOD0", R)
    return [R, ob]

def lantern():
    R = root("farm_lantern_a"); p = Part()
    p.cyl(0.07, 0.065, 1.3, (0, 0, 0), (0, 0, 0), "post", seg=10)
    p.box((0.18, 0.02, 0.02), (0.08, 0, 1.15), (0, 0, 0), "steel")                       # bracket
    x = 0.16
    p.cyl(0.055, 0.055, 0.03, (x, 0, 0.92), (0, 0, 0), "red", seg=14)                     # fount
    p.cyl(0.04, 0.04, 0.11, (x, 0, 0.95), (0, 0, 0), "glass", seg=14, caps=False)          # globe
    p.sphere(0.012, (x, 0, 0.99), (1, 1, 1.6), "flame", seg=8)
    p.cyl(0.05, 0.02, 0.04, (x, 0, 1.06), (0, 0, 0), "red", seg=14)                        # top
    for a in (0, 90):
        p.box((0.004, 0.004, 0.17), (x + 0.045 * math.cos(math.radians(a)), 0.045 * math.sin(math.radians(a)), 1.0), (0, 0, 0), "red", bevel=0)
    for k in range(10):
        an = math.pi * k / 9
        p.box((0.004, 0.004, 0.02), (x + math.cos(an) * 0.05, 0, 1.1 + math.sin(an) * 0.04), (0, -math.degrees(an), 0), "steel", bevel=0)
    ob = p.obj("farm_lantern_a_LOD0", R)
    return [R, ob]

def tracker():
    R = root("wolf_collar_tracker_a"); p = Part()
    p.box((0.09, 0.04, 0.16), (0, 0, 0.08), (0, 0, 0), "plastic", bevel=0.008)            # receiver
    p.box((0.06, 0.005, 0.04), (0, 0.021, 0.12), (0, 0, 0), "black", bevel=0.002)         # screen
    p.cyl(0.006, 0.006, 0.3, (0, 0, 0.16), (0, 0, 0), "black", seg=8)                     # handle
    p.box((0.012, 0.012, 0.5), (0, 0, 0.46), (0, 0, 0), "zinc", bevel=0)                  # Yagi boom (horizontal below)
    for k in range(3):
        p.box((0.34 - k * 0.04, 0.006, 0.006), (0, 0, 0.30 + k * 0.15), (0, 0, 0), "zinc", bevel=0)
    for k in range(4):
        p.cyl(0.004, 0.004, 0.02, (0.03 * k - 0.045, 0.021, 0.04), (90, 0, 0), "orange", seg=6)   # knobs
    ob = p.obj("wolf_collar_tracker_a_LOD0", R)
    return [R, ob]

def shearing_kit():
    R = root("sheep_shearing_kit_a"); p = Part()
    p.box((0.5, 0.3, 0.02), (0, 0, 0.01), (0, 0, 0), "canvas", bevel=0.005)               # mat
    p.box((0.05, 0.22, 0.05), (-0.1, 0.0, 0.045), (0, 0, 10), "zinc", bevel=0.01)         # handpiece
    p.box((0.08, 0.05, 0.012), (-0.11, 0.13, 0.035), (0, 0, 10), "steel", bevel=0.002)    # comb and cutter
    for k in range(8):
        p.cyl(0.012, 0.012, 0.07, (-0.06 + k * 0.012, -0.2 - k * 0.03, 0.02), (0, 90, 0), "black", seg=8)   # drive cable
    p.box((0.14, 0.08, 0.12), (0.15, 0.05, 0.06), (0, 0, -8), "red", bevel=0.01)          # oil tin and tool box
    p.box((0.03, 0.18, 0.004), (0.17, -0.09, 0.022), (0, 0, 20), "steel", bevel=0.001)     # hand shears, blades closed
    p.box((0.03, 0.18, 0.004), (0.18, -0.09, 0.026), (0, 0, 24), "steel", bevel=0.001)
    ob = p.obj("sheep_shearing_kit_a_LOD0", R)
    return [R, ob]

PROPS = {
    "sheep_trough_a": trough, "sheep_hay_rack_a": hay_rack, "sheep_salt_lick_a": salt_lick, "sheep_bell_a": bell,
    "wool_on_wire_a": lambda: wool_on_wire("a"), "wool_on_wire_b": lambda: wool_on_wire("b"),
    "wolf_track_a": lambda: print_decal("wolf", "a"), "wolf_track_b": lambda: print_decal("wolf", "b"),
    "sheep_print_a": lambda: print_decal("sheep", "a"), "sheep_print_b": lambda: print_decal("sheep", "b"),
    "night_pen_a": lambda: pen(False), "night_pen_a_open": lambda: pen(True), "pen_gate_a": pen_gate,
    "farm_warning_sign_a": sign, "hay_bale_small_a": hay_bale_small, "straw_patch_a": straw_patch, "sheep_feed_bucket_a": bucket,
    "wolf_ear_tuft_a": fur_tufts, "pasture_gate_a": pasture_gate, "farm_lantern_a": lantern, "wolf_collar_tracker_a": tracker,
    "sheep_shearing_kit_a": shearing_kit,
}

if __name__ == "__main__":
    only = args.get("only", "")
    info = []
    for nm, fn in PROPS.items():
        if only and not nm.startswith(only): continue
        blib.clear_scene(); _M.clear()
        objs = fn()
        info.append(export(nm, objs))
    if not only:
        json.dump(info, open(os.path.join(HERE, "props_info.json"), "w"), indent=1)

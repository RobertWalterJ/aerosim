# Hand-held and ground props for the people: assets/models/people/people_props.glb (one root node per prop, origin at the
# grip or the base). PeopleAssets attaches them to the hand bones (grip frame computed from the skeleton) or the ground.
# blender.exe -b --python people_props.py
# Grip frame (for a prop held in a fist): origin at the middle of the palm, x across the knuckles (index to little
# finger), y along the fingers, z out of the palm. Props are modelled with their grip at the origin and the handle along x.
import bpy, bmesh, os, sys, math, json
import numpy as np
from mathutils import Vector, Matrix, Quaternion
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import people_lib as L

L.reset_scene()
OUT = os.path.join(L.OUT_DIR, "people_props.glb")

MATS = {}
def mat(name, color, rough=0.5, metal=0.0, emit=None, alpha=None):
    if name in MATS:
        return MATS[name]
    m = L.new_material("prop_" + name, color=color, rough=rough, metal=metal, emission=emit)
    if alpha:
        m.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND"
    MATS[name] = m
    return m

def obj_from(bm, name, material, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me)
    L.link(o)
    o.data.materials.append(material)
    for p in me.polygons:
        p.use_smooth = smooth
    return o

def cyl(name, material, r1, r2, h, seg=16, z0=0.0, cap=True, axis="Z", loc=(0, 0, 0), smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=h)
    bmesh.ops.translate(bm, vec=Vector((0, 0, z0 + h / 2)), verts=bm.verts[:])
    if axis == "X":
        bmesh.ops.rotate(bm, verts=bm.verts[:], cent=Vector(), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    elif axis == "Y":
        bmesh.ops.rotate(bm, verts=bm.verts[:], cent=Vector(), matrix=Matrix.Rotation(-math.pi / 2, 3, "X"))
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts[:])
    return obj_from(bm, name, material, smooth)

def box(name, material, size, loc=(0, 0, 0), bevel=0.0, rot=None):
    bm = bmesh.new()
    r = bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=r["verts"])
    o = obj_from(bm, name, material, smooth=False)
    if bevel:
        b = o.modifiers.new("b", "BEVEL"); b.width = bevel; b.segments = 2; b.limit_method = "ANGLE"
        L.apply_modifier(o, "b")
        for p in o.data.polygons:
            p.use_smooth = True
    if rot:
        o.rotation_euler = rot
    o.location = loc
    return o

def lathe(name, material, prof, seg=20, axis="Z", loc=(0, 0, 0)):
    """prof: [(radius, z)] bottom to top."""
    bm = bmesh.new()
    rings = []
    for r, z in prof:
        rings.append([bm.verts.new((math.cos(i / seg * math.tau) * r, math.sin(i / seg * math.tau) * r, z)) for i in range(seg)])
    for a, b in zip(rings, rings[1:]):
        for i in range(seg):
            bm.faces.new((a[i], a[(i + 1) % seg], b[(i + 1) % seg], b[i]))
    bm.faces.new(rings[0][::-1])
    if axis == "X":
        bmesh.ops.rotate(bm, verts=bm.verts[:], cent=Vector(), matrix=Matrix.Rotation(math.pi / 2, 3, "Y"))
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts[:])
    return obj_from(bm, name, material)

def group(name, objs):
    for o in objs:
        o.select_set(False)
    o = L.join(objs, name)
    L.select_only([o])
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return o

PROPS = []
def prop(o):
    PROPS.append(o)
    return o

# ----------------------------------------------------------------- hand-held (grip at origin, handle along x)
enamel = mat("enamel", (0.86, 0.86, 0.82), 0.25)
rim = mat("enamel_rim", (0.08, 0.1, 0.16), 0.3)
# camp mug: handle in the fist, the cup out past the thumb (+z side of the palm... toward -y? the cup sits beyond the index)
cup = lathe("cup", enamel, [(0.0, 0.0), (0.037, 0.0), (0.04, 0.005), (0.04, 0.085), (0.036, 0.085), (0.036, 0.01), (0.0, 0.012)], 20)
cup.location = (0, 0.0, -0.045)
handle = cyl("h", enamel, 0.008, 0.008, 0.06, 8, axis="Z", loc=(0, 0, -0.03))
rimo = lathe("rim", rim, [(0.0395, 0.083), (0.0415, 0.085), (0.0395, 0.087)], 20)
rimo.location = (0, 0, -0.045)
mug = group("prop_mug", [cup, handle, rimo])
# turn: cup axis along x (the fist holds the handle across the knuckles), cup hanging off the thumb side (+z out of palm), toward the index (-x)
mug.rotation_euler = (0, math.pi / 2, 0)
mug.location = (0, 0.0, 0.0)
L.select_only([mug]); bpy.ops.object.transform_apply(location=True, rotation=True)
for v in mug.data.vertices:
    v.co.z += 0.055 if False else 0
prop(mug)

# clipboard (held flat against the forearm in the left hand: board in the y-x plane of the grip)
board = mat("board", (0.42, 0.3, 0.18), 0.7)
paper = mat("paper", (0.92, 0.91, 0.87), 0.85)
metal = mat("steel", (0.7, 0.7, 0.72), 0.3, 1.0)
# held by its side edge, thumb on top: the board lies in the fingers (y) / palm (z) plane, the paper on the -x face
# (which is up for a left hand held thumb-up), the clip at the far end along the fingers
b = box("b", board, (0.005, 0.32, 0.23), (0, 0.06, 0.10))
pa = box("p", paper, (0.002, 0.28, 0.21), (-0.0035, 0.045, 0.10))
cl = box("c", metal, (0.012, 0.025, 0.08), (-0.006, 0.21, 0.10), bevel=0.003)
clip = group("prop_clipboard", [b, pa, cl])
prop(clip)

pen = cyl("prop_pen", mat("pen", (0.05, 0.08, 0.25), 0.4), 0.0045, 0.004, 0.14, 8, z0=-0.03, axis="X")
prop(pen)
nb = group("prop_notebook", [box("n", mat("notebook", (0.12, 0.12, 0.13), 0.6), (0.1, 0.15, 0.012), bevel=0.002),
                             box("np", paper, (0.095, 0.145, 0.013), (0.003, 0, 0))])
prop(nb)
# phone: held upright in the palm, screen facing the face (-z of the grip is toward the palm; screen on +z?)
ph_body = box("pb", mat("phone", (0.03, 0.03, 0.035), 0.25, 0.3), (0.072, 0.15, 0.008), bevel=0.004)
ph_scr = box("ps", mat("screen", (0.05, 0.08, 0.1), 0.1, 0.0, emit=(0.55, 0.75, 1.0, 2.5)), (0.064, 0.138, 0.001), (0, 0, 0.0045))
phone = group("prop_phone", [ph_body, ph_scr])
for v in phone.data.vertices:
    v.co.z -= 0.022
    v.co.y += 0.02
prop(phone)
# torch: handle along x, lens pointing toward -x... along the forearm forward: lens at +y? handle across fist, beam out of the thumb end (-x)
t_body = cyl("tb", mat("torch", (0.12, 0.12, 0.13), 0.35, 0.6), 0.016, 0.016, 0.16, 12, z0=-0.06, axis="X")
t_head = cyl("th", mat("torch", (0.12, 0.12, 0.13), 0.35, 0.6), 0.016, 0.024, 0.045, 12, z0=0.1, axis="X")
t_lens = cyl("tl", mat("lens", (1.0, 0.95, 0.8), 0.1, 0.0, emit=(1.0, 0.92, 0.75, 6.0)), 0.021, 0.021, 0.003, 12, z0=0.145, axis="X")
torch = group("prop_torch", [t_body, t_head, t_lens])
prop(torch)
# little festival flag on a stick (stick along x through the fist; flag up the stick)
stick = cyl("st", mat("wood", (0.62, 0.5, 0.33), 0.7), 0.005, 0.004, 0.55, 6, z0=-0.08, axis="X")
bm = bmesh.new()
vs = [bm.verts.new(v) for v in ((0.25, 0, 0), (0.46, 0, 0), (0.46, 0, 0.0), (0.25, 0, 0))]
bm.free()
bm = bmesh.new()
pts = [(0.27, 0.0, 0.0), (0.46, 0.0, 0.0), (0.46, -0.0, 0.0)]
v1 = bm.verts.new((0.27, 0, 0.004)); v2 = bm.verts.new((0.46, 0, 0.004)); v3 = bm.verts.new((0.46, 0, 0.30)); v4 = bm.verts.new((0.27, 0, 0.30))
bm.faces.new((v1, v2, v3, v4))
flagcloth = obj_from(bm, "fc", mat("flag", (0.12, 0.45, 0.22), 0.8))
flagcloth.data.materials[0].use_backface_culling = False
# a cream band across the flag (fictional festival colours, no text)
bm = bmesh.new()
w1 = bm.verts.new((0.27, -0.001, 0.12)); w2 = bm.verts.new((0.46, -0.001, 0.12)); w3 = bm.verts.new((0.46, -0.001, 0.18)); w4 = bm.verts.new((0.27, -0.001, 0.18))
bm.faces.new((w1, w2, w3, w4))
band = obj_from(bm, "fb", mat("flag_band", (0.9, 0.84, 0.62), 0.8))
flag = group("prop_flag", [stick, flagcloth, band])
# the flag stands up the stick: stick along x in the grip, flag in the x-z plane... rotate so flag hangs off the stick sideways
prop(flag)
# handheld microphone (singer)
mic = group("prop_mic", [cyl("mb", mat("mic", (0.06, 0.06, 0.065), 0.4, 0.5), 0.013, 0.019, 0.17, 12, z0=-0.07, axis="X"),
                         lathe("mh", mat("mesh", (0.5, 0.5, 0.52), 0.5, 1.0), [(0.0, 0.0), (0.024, 0.005), (0.026, 0.03), (0.018, 0.05), (0.0, 0.056)], 12, axis="X", loc=(0.1, 0, 0))])
prop(mic)
# drumsticks (one per hand)
for side in ("l", "r"):
    prop(cyl(f"prop_stick_{side}", mat("hickory", (0.78, 0.62, 0.42), 0.6), 0.007, 0.005, 0.40, 8, z0=-0.1, axis="X"))
# fiddle bow (right hand) and fiddle (left hand at the neck, body under the chin)
bow = group("prop_bow", [cyl("bw", mat("bowwood", (0.3, 0.14, 0.06), 0.5), 0.004, 0.003, 0.72, 6, z0=-0.06, axis="X"),
                         cyl("bh", mat("hair", (0.92, 0.9, 0.84), 0.8), 0.0015, 0.0015, 0.66, 4, z0=-0.03, axis="X", loc=(0, 0, 0.012))])
prop(bow)
spruce = mat("violin", (0.42, 0.16, 0.05), 0.3)
fb = mat("ebony", (0.03, 0.025, 0.02), 0.4)
# fiddle modelled along +x from the grip at the neck: scroll behind the hand, body out at +x 0.15..0.5
bm = bmesh.new()
outline = []
for i in range(24):
    a = i / 24 * math.tau
    x = 0.33 + math.cos(a) * 0.175
    w = 0.1 * (1 - 0.18 * math.cos(2 * a) ** 2) * (1.0 if math.cos(a) > 0 else 0.9)
    outline.append((x, math.sin(a) * w))
top = [bm.verts.new((x, y, 0.02)) for x, y in outline]
bot = [bm.verts.new((x, y, -0.02)) for x, y in outline]
bm.faces.new(top); bm.faces.new(bot[::-1])
for i in range(24):
    bm.faces.new((bot[i], bot[(i + 1) % 24], top[(i + 1) % 24], top[i]))
vbody = obj_from(bm, "vb", spruce)
neck = box("vn", fb, (0.27, 0.025, 0.012), (0.06, 0, 0.022))
scroll = box("vs", spruce, (0.06, 0.03, 0.03), (-0.1, 0, 0.012), bevel=0.008)
fiddle = group("prop_fiddle", [vbody, neck, scroll])
prop(fiddle)
# acoustic guitar on a strap (rides on the chest): modelled in chest space, origin at the strap centre on the chest
bm = bmesh.new()
outline = []
for i in range(32):
    a = i / 32 * math.tau
    x = math.cos(a)
    y = math.sin(a)
    lower = 0.2 if x < 0 else 0.16
    outline.append((x * 0.24, y * (lower if x < 0 else 0.15) * (1 - 0.12 * math.exp(-((x - 0.15) ** 2) * 20))))
top = [bm.verts.new((x, y, 0.05)) for x, y in outline]
bot = [bm.verts.new((x, y, -0.05)) for x, y in outline]
bm.faces.new(top); bm.faces.new(bot[::-1])
for i in range(32):
    bm.faces.new((bot[i], bot[(i + 1) % 32], top[(i + 1) % 32], top[i]))
gb = obj_from(bm, "gb", mat("guitar", (0.55, 0.32, 0.14), 0.3))
hole = cyl("gh", fb, 0.045, 0.045, 0.002, 16, z0=0.05, loc=(0.06, 0, 0))
gneck = box("gn", mat("guitar_neck", (0.2, 0.1, 0.05), 0.4), (0.46, 0.05, 0.025), (0.46, 0, 0.04))
ghead = box("gk", mat("guitar_neck", (0.2, 0.1, 0.05), 0.4), (0.18, 0.08, 0.02), (0.76, 0, 0.035))
guitar = group("prop_guitar", [gb, hole, gneck, ghead])
prop(guitar)

# ----------------------------------------------------------------- ground props (origin on the ground)
# mechanic's creeper (Ellis under the bus)
cr_board = box("crb", mat("creeper", (0.42, 0.1, 0.06), 0.5), (0.42, 1.0, 0.03), (0, 0.0, 0.085), bevel=0.01)
wheels = [cyl(f"w{i}", mat("rubber", (0.04, 0.04, 0.04), 0.7), 0.03, 0.03, 0.025, 10, axis="X", loc=(x, y, 0.03))
          for i, (x, y) in enumerate(((-0.17, -0.42), (0.17, -0.42), (-0.17, 0.42), (0.17, 0.42)))]
pad = box("crp", mat("pad", (0.08, 0.08, 0.09), 0.8), (0.3, 0.22, 0.03), (0, 0.38, 0.11), bevel=0.012)
prop(group("prop_creeper", [cr_board, pad] + wheels))
# steel toolbox, open (tray up, spanners) and closed
red = mat("toolbox", (0.5, 0.06, 0.04), 0.4, 0.3)
tb_body = box("tbb", red, (0.5, 0.22, 0.2), (0, 0, 0.1), bevel=0.006)
tb_lid = box("tbl", red, (0.5, 0.22, 0.03), (0, 0, 0.215), bevel=0.006)
tb_h = box("tbh", metal, (0.2, 0.02, 0.02), (0, 0, 0.245), bevel=0.004)
prop(group("prop_toolbox_closed", [tb_body, tb_lid, tb_h]))
tb_body = box("tbb", red, (0.5, 0.22, 0.2), (0, 0, 0.1), bevel=0.006)
tb_lid = box("tbl", red, (0.5, 0.03, 0.2), (0, 0.13, 0.3), bevel=0.006, rot=(math.radians(-15), 0, 0))
tray = box("tbt", red, (0.48, 0.2, 0.05), (0, -0.02, 0.215), bevel=0.004)
spanners = [box(f"sp{i}", metal, (0.16 - i * 0.02, 0.018, 0.006), (-0.12 + i * 0.06, -0.03 + (i % 2) * 0.05, 0.245), bevel=0.002, rot=(0, 0, 0.2 * i))
            for i in range(5)]
prop(group("prop_toolbox_open", [tb_body, tb_lid, tray] + spanners))
# folding camp chair (Ellis sitting)
canvas = mat("canvas", (0.16, 0.22, 0.16), 0.85)
frame = mat("frame", (0.18, 0.18, 0.19), 0.4, 0.8)
seat = box("cs", canvas, (0.5, 0.44, 0.02), (0, 0.04, 0.43), bevel=0.008)
back = box("cb", canvas, (0.5, 0.02, 0.4), (0, 0.27, 0.68), bevel=0.008, rot=(math.radians(-12), 0, 0))
legs = []
for sx in (-1, 1):
    legs.append(cyl(f"l{sx}a", frame, 0.012, 0.012, 0.62, 8, loc=(sx * 0.24, -0.2, 0)))
    legs[-1].rotation_euler = (math.radians(-30), 0, 0)
    legs.append(cyl(f"l{sx}b", frame, 0.012, 0.012, 0.62, 8, loc=(sx * 0.24, 0.28, 0)))
    legs[-1].rotation_euler = (math.radians(30), 0, 0)
    legs.append(cyl(f"l{sx}c", frame, 0.012, 0.012, 0.5, 8, axis="Y", loc=(sx * 0.25, -0.2, 0.62)))
prop(group("prop_camp_chair", [seat, back] + legs))
# small drum kit for the drummer: bass drum, snare on a stand, one cymbal and a stool
kit = []
kit.append(cyl("bd", mat("drumshell", (0.5, 0.06, 0.06), 0.25, 0.2), 0.25, 0.25, 0.36, 24, axis="Y", loc=(0, -0.65, 0.26)))
kit.append(cyl("bdh", mat("drumhead", (0.92, 0.9, 0.85), 0.5), 0.235, 0.235, 0.005, 24, axis="Y", loc=(0, -0.835, 0.26)))
kit.append(cyl("sn", mat("drumshell", (0.5, 0.06, 0.06), 0.25, 0.2), 0.17, 0.17, 0.13, 20, loc=(0.0, -0.36, 0.55)))
kit.append(cyl("snh", mat("drumhead", (0.92, 0.9, 0.85), 0.5), 0.165, 0.165, 0.004, 20, loc=(0.0, -0.36, 0.68)))
kit.append(cyl("sns", metal, 0.01, 0.01, 0.55, 8, loc=(0.0, -0.36, 0.0)))
kit.append(cyl("cs", metal, 0.01, 0.01, 1.05, 8, loc=(-0.45, -0.55, 0.0)))
kit.append(cyl("cy", mat("brass", (0.75, 0.55, 0.22), 0.25, 1.0), 0.2, 0.02, 0.025, 24, loc=(-0.45, -0.55, 1.05)))
kit.append(cyl("st", mat("stool", (0.05, 0.05, 0.05), 0.6), 0.17, 0.17, 0.06, 16, loc=(0, 0.05, 0.4)))
kit.append(cyl("stl", metal, 0.015, 0.015, 0.4, 8, loc=(0, 0.05, 0.0)))
prop(group("prop_drum_kit", kit))
# microphone stand for the singer (ground, in front)
prop(group("prop_mic_stand", [cyl("ms", metal, 0.008, 0.008, 1.45, 8, loc=(0, -0.35, 0)),
                              cyl("mb", metal, 0.12, 0.12, 0.012, 16, loc=(0, -0.35, 0))]))

# ----------------------------------------------------------------- export the props (each at the world origin)
for o in PROPS:
    o.location = (0, 0, 0)
L.select_only(PROPS)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_yup=True,
                          export_materials="EXPORT", export_animations=False, export_tangents=False)
L.log("wrote", OUT, os.path.getsize(OUT), [o.name for o in PROPS])

import os
# Stage B: texture work.
#  - paints a short full beard, moustache and a close-cropped hairline into the skin diffuse
#  - writes the beard RGBA map used by the beard volume shells (stage C)
#  - recolours the long-sleeve top of the casual suit to a plain white crewneck (no logo)
import bpy, numpy as np, os
OUT = os.path.join(os.environ.get('PILOT_WORK', os.getcwd()), 'tex')
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)

def sm(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)

def img_to_np(img):
    w, h = img.size; a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4); return a

def np_to_png(a, path):
    h, w, _ = a.shape
    im = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    im.pixels.foreach_set(np.clip(a, 0, 1).astype(np.float32).ravel()); im.filepath_raw = path; im.file_format = 'PNG'; im.save()
    return im

def raster(obj, vals, W, H, tri_filter=None):
    """Rasterise per-vertex values (N, C) into UV space. Returns (H, W, C) and coverage mask."""
    me = obj.data; me.calc_loop_triangles()
    uv = np.zeros((len(me.loops), 2)); me.uv_layers.active.data.foreach_get('uv', uv.ravel())
    C = vals.shape[1]; out = np.zeros((H, W, C), np.float32); cov = np.zeros((H, W), bool)
    for t in me.loop_triangles:
        vi = list(t.vertices)
        if tri_filter is not None and not tri_filter(vi): continue
        p = uv[list(t.loops)] * [W, H]
        x0, y0 = np.floor(p.min(0)).astype(int); x1, y1 = np.ceil(p.max(0)).astype(int)
        x0 = max(x0, 0); y0 = max(y0, 0); x1 = min(x1, W - 1); y1 = min(y1, H - 1)
        if x1 < x0 or y1 < y0: continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        (ax, ay), (bx, by), (cx, cy) = p
        d = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(d) < 1e-12: continue
        l1 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / d
        l2 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / d
        l3 = 1 - l1 - l2
        m = (l1 >= -0.02) & (l2 >= -0.02) & (l3 >= -0.02)
        if not m.any(): continue
        v = vals[vi]
        val = l1[..., None] * v[0] + l2[..., None] * v[1] + l3[..., None] * v[2]
        sub = out[y0:y1 + 1, x0:x1 + 1]; sub[m] = val[m]; cov[y0:y1 + 1, x0:x1 + 1] |= m
    return out, cov

def blur(a, r):
    """separable box blur repeated 3x (close to gaussian), 2D arrays"""
    a = a.astype(np.float32)
    for _ in range(3):
        for ax in (0, 1):
            pad = [(0, 0), (0, 0)]; pad[ax] = (r + 1, r)
            c = np.cumsum(np.pad(a, pad, mode='edge'), axis=ax)
            n = a.shape[ax]
            if ax == 0: a = (c[2 * r + 1:2 * r + 1 + n] - c[:n]) / (2 * r + 1)
            else: a = (c[:, 2 * r + 1:2 * r + 1 + n] - c[:, :n]) / (2 * r + 1)
    return a

# ------------------------------------------------------------------ skin
bm = bpy.data.objects['Human_x']
co = np.array([bm.matrix_world @ v.co for v in bm.data.vertices])
N = len(co)
def gw(name):
    gi = bm.vertex_groups[name].index; w = np.zeros(N)
    for i, v in enumerate(bm.data.vertices):
        for g in v.groups:
            if g.group == gi: w[i] = g.weight
    return w
lips, ears = gw('lips'), gw('ears')
x, y, z = co[:, 0], co[:, 1], co[:, 2]
f = -0.046 - y                       # forward of the ear plane (metres)
t = np.clip(f / 0.105, 0, 1)
zTop = 1.626 + (0.075 + (0.016 - 0.075) * t ** 1.3)
must = sm(0.034, 0.02, np.abs(x)) * sm(0.8, 0.95, t)
zTop = zTop + must * 0.012
zBot = 1.61 + (1.545 - 1.61) * t
beard = sm(zTop + 0.007, zTop - 0.007, z) * sm(zBot - 0.012, zBot + 0.01, z) * sm(-0.014, 0.004, f) * (z > 1.5)
beard *= (1 - sm(0.05, 0.4, lips)) * (1 - sm(0.1, 0.5, ears))
# sparser on the upper cheeks, densest on chin, jaw and moustache
dens = beard * (1 - 0.45 * sm(1.632, 1.672, z) * sm(0.25, 0.5, t) * (1 - must))
# hair: close crop under the cap, visible at the sides and back
hl = np.where(y < -0.1, 1.772, np.where(y < -0.06, 1.722, np.where(y < 0.0, 1.703, 1.703 - (y - 0.0) * 1.9)))
hair = sm(hl - 0.006, hl + 0.006, z) * (1 - sm(0.1, 0.5, ears)) * (z > 1.55)
# smooth the masks over the mesh (a few Laplacian passes)
adj = [[] for _ in range(N)]
for e in bm.data.edges:
    a, b = e.vertices; adj[a].append(b); adj[b].append(a)
def smooth(w, n):
    for _ in range(n):
        w = np.array([0.5 * w[i] + 0.5 * (w[adj[i]].mean() if adj[i] else w[i]) for i in range(N)])
    return w
headv = z > 1.45
dens = smooth(dens, 2); hair = smooth(hair, 2)
skin_img = bm.data.materials[0].node_tree.nodes['Image Texture'].image if 'Image Texture' in bm.data.materials[0].node_tree.nodes else [n for n in bm.data.materials[0].node_tree.nodes if n.type == 'TEX_IMAGE'][0].image
S = img_to_np(skin_img); H, W = S.shape[:2]
vals = np.stack([dens, hair], 1)
masks, cov = raster(bm, vals, W, H, tri_filter=lambda vi: headv[vi].any())
dm = blur(masks[..., 0], 2); hm = blur(masks[..., 1], 2)
# coily short-hair grain: two scales of thresholded noise
n1 = blur(rng.random((H, W)).astype(np.float32), 1); n1 = (n1 - n1.mean()) / n1.std()
n2 = blur(rng.random((H, W)).astype(np.float32), 3); n2 = (n2 - n2.mean()) / n2.std()
grain = np.clip(0.55 + 0.32 * n1 + 0.18 * n2, 0, 1)
beardCol = np.array([0.075, 0.058, 0.05])   # sRGB
amtB = np.clip(dm * (0.55 + 0.6 * grain), 0, 0.97)[..., None]
amtH = np.clip(hm * (0.6 + 0.5 * grain), 0, 0.95)[..., None]
skin_lin = np.clip(S[..., :3] * np.array([1.13, 1.1, 1.06]), 0, 1)  # a touch lighter and warmer
out = skin_lin * (1 - amtH) + beardCol * amtH
out = out * (1 - amtB) + beardCol * 1.15 * amtB
S2 = S.copy(); S2[..., :3] = out
np_to_png(S2, OUT + '/skin_diffuse.png')
# beard RGBA for the volume shells: colour with slight variation, alpha = density x grain
B = np.zeros((H, W, 4), np.float32)
strand = rng.random((H, W)).astype(np.float32)          # one value per texel = one hair tuft
strand = 0.65 * strand + 0.35 * blur(strand, 1) / max(1e-6, blur(strand, 1).max())
tone = rng.random((H, W)).astype(np.float32)
B[..., :3] = np.array([0.095, 0.075, 0.064]) * (0.75 + 0.6 * tone[..., None]) + 0.05 * (tone[..., None] > 0.985)
patch = blur(rng.random((H, W)).astype(np.float32), 10); patch = (patch - patch.mean()) / patch.std()
dmp = np.clip(dm * 1.25 * (1 + 0.35 * patch * (1 - np.clip(dm * 1.6 - 0.6, 0, 1))), 0, 1)   # patchy where thin
B[..., 3] = np.clip(dmp ** 1.4 * (0.2 + 0.8 * strand), 0, 1)
np_to_png(B, OUT + '/beard_rgba.png')
np.save(OUT + '/beard_vertex_density.npy', dens)
print("BEARD verts", int((dens > 0.3).sum()), "HAIR verts", int((hair > 0.3).sum()))

# ------------------------------------------------------------------ white crewneck top
cl = bpy.data.objects['Human.male_casualsuit02_x']
cco = np.array([cl.matrix_world @ v.co for v in cl.data.vertices])
mat = cl.data.materials[0]
cimg = [n for n in mat.node_tree.nodes if n.type == 'TEX_IMAGE' and 'diffuse' in n.image.name][0].image
Cimg = img_to_np(cimg); CH, CW = Cimg.shape[:2]
# shirt and jeans are separate pieces of the mesh: classify connected components by height
par = list(range(len(cco)))
def find(a):
    while par[a] != a: par[a] = par[par[a]]; a = par[a]
    return a
for poly in cl.data.polygons:
    vs = list(poly.vertices)
    for v in vs[1:]:
        ra, rb = find(vs[0]), find(v)
        if ra != rb: par[ra] = rb
roots = np.array([find(i) for i in range(len(cco))])
top = np.zeros(len(cco), np.float32)
for r in np.unique(roots):
    m = roots == r
    if cco[m, 2].mean() > 1.05: top[m] = 1
print('COMPONENTS', len(np.unique(roots)), 'top verts', int(top.sum()))
tm, tcov = raster(cl, top[:, None], CW, CH)
tm = (tm[..., 0] > 0.5) & tcov
# keep a little of the original large-scale shading (folds/AO) but drop the print
lum = Cimg[..., :3] @ np.array([0.2126, 0.7152, 0.0722])
big = blur(lum, 24)
rel = np.clip(big / max(1e-4, big[tm].mean()), 0.75, 1.15)
fabric = np.clip(0.97 + 0.02 * n1[:CH, :CW] if n1.shape[0] >= CH else 0.97, 0, 1)
white = np.array([0.93, 0.93, 0.91]) * (rel * fabric)[..., None]
C2 = Cimg.copy(); C2[tm, :3] = white[tm]
np_to_png(C2, OUT + '/top_jeans_diffuse.png')
print("TOP texels", int(tm.sum()))

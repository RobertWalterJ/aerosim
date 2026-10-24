"""The textures of the sites lane (boat launch, cabin track and cave). Run: python -I make_site_textures.py <godot dir>

Copies (resized to 1024 px) the photographed CC0 Poly Haven sets that are on this PC but not yet in the game, and authors
the site-specific sets from photographed sources plus drawn masks (own work, CC0):
  site_concrete_*   Poly Haven concrete_floor_worn_001 (Dimitrios Savva, Rico Cilliers), 3.0 m
  site_ramp_*       the same concrete with a 45 degree waffle of V grooves (25 mm wide, 20 mm deep, 200 mm apart: the
                    Western Australian boat-ramp guideline), dirt in the grooves; one repeat 2.0 m
  site_gravel_*     Poly Haven gravel_road (Amal Kumar), 2.0 m
  site_dirt_*       Poly Haven park_dirt (Christopher Melani), 3.0 m
  site_bark_beech_* Poly Haven japanese_hackberry_bark (Charlotte Baglioni), 1.89 m (smooth grey bark for the beech)
  site_track_*      the cabin track: 4.4 m across (u 0..1) by 8 m along (v), tiling along v: gravel and dirt between two
                    worn ruts (aerial_mud_1), a grass centre strip (sparse_grass), leaf litter (brown_mud_leaves_01) and
                    grass creeping in from the edges; normal map carries the rut walls
  site_alu_*        riveted aluminium (own work): brushed grain, oxidation, lap seams and rivet rows; 1.0 m repeat
  site_wood_end_*   sawn end grain with growth rings and a chainsaw kerf (own work), one face 0.6 m
  site_decal_*.png  alpha decals (own work): rust run, algae, waterline, crack, oil, tyre print, damp, chalk
Writes .import files (VRAM compression, mipmaps, normal maps flagged). Sources and licences: assets/textures/README.md."""
import os, sys, math, random
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

GODOT = sys.argv[1]
DST = os.path.join(GODOT, "assets", "textures")
TEX = DST
ROOT = os.path.normpath(os.path.join(GODOT, "..", ".."))
SH = os.path.join(ROOT, "RWJ-Shared-Assets", "godot", "addons", "rwj_procgen", "textures")
RS = os.path.join(ROOT, "_tools", "road_sources")

IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://assets/textures/{name}"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map={nm}
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""


def write_import(name, normal):
    with open(os.path.join(DST, name + ".import"), "w", newline="\n") as f:
        f.write(IMPORT.format(name=name, nm=1 if normal else 0))


def save(arr, name, normal=False, q=None):
    a = np.clip(arr, 0, 1)
    if a.ndim == 2:
        im = Image.fromarray((a * 255 + 0.5).astype(np.uint8), "L").convert("RGB")
    elif a.shape[2] == 4:
        im = Image.fromarray((a * 255 + 0.5).astype(np.uint8), "RGBA")
    else:
        im = Image.fromarray((a * 255 + 0.5).astype(np.uint8), "RGB")
    path = os.path.join(DST, name)
    if name.endswith(".png"):
        im.save(path, optimize=True)
    else:
        im.save(path, quality=q or (90 if normal else 85))
    write_import(name, normal)
    print(name, im.size)


def load(path, size=None):
    im = Image.open(path).convert("RGB")
    if size and im.size != size:
        im = im.resize(size, Image.LANCZOS)
    return np.asarray(im).astype(np.float32) / 255.0


def tnoise(h, w, px, seed, octaves=1):
    """periodic smooth noise (tiles in both directions): white noise filtered in the frequency domain; px = feature size"""
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w), np.float32)
    amp = 1.0
    for o in range(octaves):
        f = rng.standard_normal((h, w))
        F = np.fft.fft2(f)
        ky = np.fft.fftfreq(h)[:, None]
        kx = np.fft.fftfreq(w)[None, :]
        s = px / (2.0 ** o)
        g = np.exp(-((kx ** 2 + ky ** 2) * (s ** 2) * 2.0 * math.pi ** 2 / 4.0))
        n = np.real(np.fft.ifft2(F * g))
        n = (n - n.mean()) / (n.std() + 1e-9)
        out += n * amp
        amp *= 0.5
    return out / max(1e-9, np.abs(out).max())


def tile_to(src, src_m, out_hw, out_m):
    """resample a tiling source (repeat src_m metres) onto an output of out_hw pixels covering out_m metres (h, w)"""
    H, W = out_hw
    hm, wm = out_m
    sh, sw = src.shape[:2]
    ys = (np.arange(H) + 0.5) / H * hm / src_m * sh
    xs = (np.arange(W) + 0.5) / W * wm / src_m * sw
    y0 = np.floor(ys).astype(int); x0 = np.floor(xs).astype(int)
    fy = (ys - y0)[:, None, None]; fx = (xs - x0)[None, :, None]
    y0 %= sh; x0 %= sw; y1 = (y0 + 1) % sh; x1 = (x0 + 1) % sw
    s = src if src.ndim == 3 else src[:, :, None]
    a = s[y0][:, x0]; b = s[y0][:, x1]; c = s[y1][:, x0]; d = s[y1][:, x1]
    r = (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy
    return r if src.ndim == 3 else r[:, :, 0]


def unpack_n(n):
    v = n * 2.0 - 1.0
    return v


def pack_n(v):
    l = np.linalg.norm(v, axis=2, keepdims=True) + 1e-9
    return (v / l) * 0.5 + 0.5


def height_to_n(h, px_m, strength=1.0):
    """height field (metres) to an OpenGL tangent normal (x right, y up the image)"""
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) / (2 * px_m)
    drow = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) / (2 * px_m)
    v = np.dstack([-dx * strength, drow * strength, np.ones_like(h)])
    return v


def whiteout(a, b):
    """blend two tangent normals (unpacked)"""
    return np.dstack([a[:, :, 0] + b[:, :, 0], a[:, :, 1] + b[:, :, 1], a[:, :, 2] * b[:, :, 2]])


def copy_set(key, src_d, src_n, src_a, size=1024):
    d = load(src_d, (size, size)); save(d, key + "_diff.jpg")
    n = load(src_n, (size, size)); save(n, key + "_nor.jpg", True)
    if src_a:
        a = load(src_a, (size, size)); save(a, key + "_arm.jpg")


# ------------------------------------------------------------------ copied sets
copy_set("site_concrete", os.path.join(SH, "sidewalk_diff.jpg"), os.path.join(SH, "sidewalk_nor.jpg"), os.path.join(SH, "sidewalk_arm.jpg"))
copy_set("site_gravel", os.path.join(RS, "gravel_road_diff_2k.jpg"), os.path.join(RS, "gravel_road_nor_gl_2k.jpg"), None)
# the gravel_road ARM on this PC has an empty roughness channel (it would make the gravel a mirror): keep its occlusion,
# write a stony roughness (0.82 to 0.95, a little lower on the bigger stones' tops from the albedo) and no metal
_g = load(os.path.join(RS, "gravel_road_arm_2k.jpg"), (1024, 1024))
_d = load(os.path.join(RS, "gravel_road_diff_2k.jpg"), (1024, 1024)).mean(axis=2)
_g[:, :, 1] = np.clip(0.95 - 0.13 * (_d - _d.min()) / (np.ptp(_d) + 1e-6), 0, 1)
_g[:, :, 2] = 0.0
save(_g, "site_gravel_arm.jpg")
copy_set("site_dirt", os.path.join(SH, "dirt_diff.jpg"), os.path.join(SH, "dirt_nor.jpg"), os.path.join(SH, "dirt_arm.jpg"))
copy_set("site_bark_beech", os.path.join(SH, "bark_smooth_diff.jpg"), os.path.join(SH, "bark_smooth_nor.jpg"), None, 1024)

# ------------------------------------------------------------------ autumn leaf litter: brown_mud_leaves with its green
# leaves turned to the brown and ochre of late October (hue moved from green to 25-40 degrees, a little less saturated)
_im = Image.open(os.path.join(TEX, "soil_leaves_diff.jpg")).convert("HSV")
_h, _s, _v = [np.asarray(c).astype(np.float32) for c in _im.split()]
_deg = _h / 255 * 360
_green = np.clip(1 - np.abs(_deg - 95) / 60, 0, 1) * np.clip(_s / 255 * 2.5, 0, 1)
_new = 22 + 18 * (tnoise(_h.shape[0], _h.shape[1], 8, 61) * 0.5 + 0.5)
_deg2 = _deg * (1 - _green) + _new * _green
_s2 = _s * (1 - 0.25 * _green)
_v2 = _v * (1 - 0.1 * _green)
_out = Image.merge("HSV", [Image.fromarray(np.clip(_deg2 / 360 * 255, 0, 255).astype(np.uint8)),
                          Image.fromarray(np.clip(_s2, 0, 255).astype(np.uint8)), Image.fromarray(np.clip(_v2, 0, 255).astype(np.uint8))])
_out.convert("RGB").save(os.path.join(DST, "site_leaflitter_diff.jpg"), quality=85)
write_import("site_leaflitter_diff.jpg", False)
print("site_leaflitter_diff.jpg")
save(load(os.path.join(TEX, "soil_leaves_nor.jpg")), "site_leaflitter_nor.jpg", True)
save(load(os.path.join(TEX, "soil_leaves_arm.jpg")), "site_leaflitter_arm.jpg")

# ------------------------------------------------------------------ the ramp: concrete with a 45 degree waffle of V grooves
N = 1024
TM = 2.0
pxm = TM / N
cd = tile_to(load(os.path.join(SH, "sidewalk_diff.jpg")), 3.0, (N, N), (TM, TM))
cn = tile_to(load(os.path.join(SH, "sidewalk_nor.jpg")), 3.0, (N, N), (TM, TM))
ca = tile_to(load(os.path.join(SH, "sidewalk_arm.jpg")), 3.0, (N, N), (TM, TM))
yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
u = (xx + 0.5) * pxm; v = (yy + 0.5) * pxm
sp = 0.2
hw = 0.0125
h = np.zeros((N, N), np.float32)
groove = np.zeros((N, N), np.float32)
for s in ((u + v), (u - v)):
    # distance to the nearest groove centre line along the diagonal (lines s = k * sp)
    t = s / sp
    dist = np.abs(t - np.round(t)) * sp / math.sqrt(2)
    g = np.clip(1.0 - dist / hw, 0, 1)
    h = np.minimum(h, -0.02 * g)
    groove = np.maximum(groove, g)
wear = 0.5 + 0.5 * tnoise(N, N, 60, 3)
h = h * (0.75 + 0.25 * wear)
gn = height_to_n(h, pxm, 0.35)
nrm = pack_n(whiteout(unpack_n(cn), gn / np.linalg.norm(gn, axis=2, keepdims=True)))
dirt = np.clip(groove * (0.55 + 0.45 * wear), 0, 1)[:, :, None]
ramp_d = cd * (1 - 0.42 * dirt) + np.array([0.20, 0.17, 0.13]) * 0.42 * dirt * 0.4
ramp_a = ca.copy()
ramp_a[:, :, 0] = ca[:, :, 0] * (1 - 0.55 * groove)
ramp_a[:, :, 1] = np.clip(ca[:, :, 1] + 0.05 * groove, 0, 1)
save(ramp_d, "site_ramp_diff.jpg"); save(nrm, "site_ramp_nor.jpg", True); save(ramp_a, "site_ramp_arm.jpg")

# ------------------------------------------------------------------ the cabin track: 4.4 m across, 8 m along, tiles along
H, W = 2048, 1024
WM, HM = 4.4, 8.0
gd = tile_to(load(os.path.join(RS, "gravel_road_diff_2k.jpg")), 2.0, (H, W), (HM, WM))
gn = tile_to(load(os.path.join(RS, "gravel_road_nor_gl_2k.jpg")), 2.0, (H, W), (HM, WM))
ga = tile_to(load(os.path.join(DST, "site_gravel_arm.jpg")), 2.0, (H, W), (HM, WM))
dd = tile_to(load(os.path.join(SH, "dirt_diff.jpg")), 2.0, (H, W), (HM, WM))
dn = tile_to(load(os.path.join(SH, "dirt_nor.jpg")), 2.0, (H, W), (HM, WM))
da = tile_to(load(os.path.join(SH, "dirt_arm.jpg")), 2.0, (H, W), (HM, WM))
md = tile_to(load(os.path.join(TEX, "mudtrack_diff.jpg")), 2.0, (H, W), (HM, WM))
mn = tile_to(load(os.path.join(TEX, "mudtrack_nor.jpg")), 2.0, (H, W), (HM, WM))
sd = tile_to(load(os.path.join(SH, "grass_dry_diff.jpg")), 2.0, (H, W), (HM, WM))
sn = tile_to(load(os.path.join(SH, "grass_dry_nor.jpg")), 2.0, (H, W), (HM, WM))
sa = tile_to(load(os.path.join(SH, "grass_dry_arm.jpg")), 2.0, (H, W), (HM, WM))
ld = tile_to(load(os.path.join(TEX, "soil_leaves_diff.jpg")), 2.0, (H, W), (HM, WM))
ln = tile_to(load(os.path.join(TEX, "soil_leaves_nor.jpg")), 2.0, (H, W), (HM, WM))
la = tile_to(load(os.path.join(TEX, "soil_leaves_arm.jpg")), 2.0, (H, W), (HM, WM))
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
x = (xx + 0.5) / W * WM - WM * 0.5          # metres across, 0 at the centre line
vv = (yy + 0.5) / H * HM
# meander of the ruts and patchiness, periodic along v (the noise tiles in both axes)
mea = tnoise(H, W, 260, 11)[:, :1] * 0.06
patch = tnoise(H, W, 90, 12, 2)
patch2 = tnoise(H, W, 40, 13, 2)
wet = tnoise(H, W, 140, 14)
gauge = 0.78
rut_w = 0.16
rut = np.zeros((H, W), np.float32)
for s in (-1, 1):
    d = np.abs(x - (s * gauge + mea))
    rut = np.maximum(rut, np.clip(1.0 - (d - rut_w * 0.5) / 0.09, 0, 1))
rut_h = -0.055 * rut ** 0.8
centre = np.clip(1.0 - (np.abs(x - mea * 0.5) - 0.22) / 0.16, 0, 1) * np.clip(0.55 + 0.6 * patch, 0, 1)
edge = np.clip((np.abs(x) - 1.45 - 0.12 * patch2) / 0.35, 0, 1)
leafy = np.clip((np.abs(x) - 1.25 - 0.25 * patch) / 0.5, 0, 1) * np.clip(0.6 + 0.6 * patch2, 0, 1)
grass_e = np.clip((np.abs(x) - 1.75 - 0.2 * patch) / 0.3, 0, 1) * np.clip(0.5 + 0.7 * patch, 0, 1)
dirt_m = np.clip(0.3 + 0.55 * patch2, 0, 1)
# layer the surfaces: gravel, dirt, ruts (mud), centre grass, leaf litter, edge grass
alb = gd * (1 - dirt_m[:, :, None]) + dd * dirt_m[:, :, None]
nor = gn * (1 - dirt_m[:, :, None]) + dn * dirt_m[:, :, None]
arm = ga * (1 - dirt_m[:, :, None]) + da * dirt_m[:, :, None]
def lay(a, n, r, m):
    global alb, nor, arm
    m3 = m[:, :, None]
    alb = alb * (1 - m3) + a * m3
    nor = nor * (1 - m3) + n * m3
    if r is not None:
        arm = arm * (1 - m3) + r * m3
rutm = np.clip(rut * 1.2, 0, 1)
# the ruts: the same dirt, compacted, darker and finer (the gravel is pressed in), damp
lay(dd * np.array([0.72, 0.68, 0.64]), dn * 0.5 + np.array([0.25, 0.25, 0.5]), da, rutm)
green = np.array([0.82, 1.08, 0.62])
lay(np.clip(sd * green, 0, 1), sn, sa, np.clip(centre * 1.3, 0, 1))
lay(ld * np.array([1.0, 0.92, 0.8]), ln, la, leafy)
lay(np.clip(sd * green, 0, 1), sn, sa, grass_e)
# wet dark patches in the ruts: darker, smoother
wm = np.clip(rut * (wet - 0.1) * 2.2, 0, 1)
alb = alb * (1 - 0.35 * wm[:, :, None])
arm[:, :, 1] = np.clip(arm[:, :, 1] * (1 - 0.55 * wm), 0, 1)
hn = height_to_n(rut_h, WM / W, 1.0)
nor = pack_n(whiteout(unpack_n(nor), hn / np.linalg.norm(hn, axis=2, keepdims=True)))
arm[:, :, 0] = np.clip(arm[:, :, 0] * (1 - 0.25 * rut), 0, 1)
save(alb, "site_track_diff.jpg"); save(nor, "site_track_nor.jpg", True); save(arm, "site_track_arm.jpg")

# ------------------------------------------------------------------ aluminium (1 m repeat): brushed, oxidised, seams, rivets
N = 1024
pxm = 1.0 / N
yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
u = (xx + 0.5) * pxm                      # along the boat (metres)
v = (yy + 0.5) * pxm                      # girth from the keel (metres), image row
brush = tnoise(N, N, 2, 21)
brush = np.repeat(np.mean(brush.reshape(N, N // 64, 64), axis=2), 64, axis=1)      # long streaks along u
brush = (brush + tnoise(N, N, 1.5, 22) * 0.4) * 0.5
ox = tnoise(N, N, 70, 23, 3)
spots = np.clip(tnoise(N, N, 6, 24, 2) - 0.55, 0, 1) * 3.0
base = 0.70 + 0.04 * brush - 0.08 * np.clip(ox, 0, 1) + 0.06 * np.clip(-ox, 0, 1) * 0 - 0.05 * spots
alb = np.dstack([base * 0.985, base * 0.995, base * 1.0])
h = np.zeros((N, N), np.float32)
seams = [0.02, 0.36, 0.70]
for s in seams:
    d = v - s
    # a lap joint: the upper plate overlaps the lower one by 25 mm; a 1.5 mm step and a dark line in the gap
    step = np.clip(1.0 - np.abs(d) / 0.0015, 0, 1)
    h += np.where(d > 0, 0.0015, 0.0) * np.clip(1.0 - (d - 0.025) / 0.002, 0, 1) * (d < 0.03)
    alb *= (1 - 0.35 * np.clip(1.0 - np.abs(d) / 0.0012, 0, 1))[:, :, None]
    for rv in (s + 0.012,):
        for k in range(20):
            ru = (k + 0.5) / 20.0
            dist = np.sqrt(((u - ru + 0.5) % 1.0 - 0.5) ** 2 + (v - rv) ** 2)
            cap = np.clip(1.0 - (dist / 0.0045) ** 2, 0, 1)
            h += 0.002 * np.sqrt(cap)
            alb *= (1 - 0.12 * np.clip(1 - np.abs(dist - 0.0045) / 0.001, 0, 1))[:, :, None]
for ru in (0.0, 0.5):
    for k in range(20):
        rv = (k + 0.5) / 20.0
        dist = np.sqrt(((u - ru + 0.5) % 1.0 - 0.5) ** 2 + (v - rv) ** 2)
        cap = np.clip(1.0 - (dist / 0.004) ** 2, 0, 1)
        h += 0.0018 * np.sqrt(cap)
hn = height_to_n(h, pxm, 1.0)
bn = height_to_n(brush * 0.00008, pxm, 1.0)
nor = pack_n(whiteout(hn / np.linalg.norm(hn, axis=2, keepdims=True), bn / np.linalg.norm(bn, axis=2, keepdims=True)))
arm = np.dstack([np.ones((N, N)) * 0.95, np.clip(0.48 + 0.14 * np.clip(ox, 0, 1) + 0.25 * spots + 0.04 * brush, 0, 1), np.clip(0.9 - 0.3 * spots, 0, 1)])
save(np.clip(alb, 0, 1), "site_alu_diff.jpg"); save(nor, "site_alu_nor.jpg", True); save(arm, "site_alu_arm.jpg")

# ------------------------------------------------------------------ sawn end grain (0.6 m across): growth rings, kerf marks
N = 512
yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
cx, cy = N * 0.47, N * 0.52
r = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / N * 0.6
ang = np.arctan2(yy - cy, xx - cx)
wob = tnoise(N, N, 30, 31) * 0.006
rings = 0.5 + 0.5 * np.cos((r + wob) / 0.0042 * 2 * math.pi)
late = np.clip(rings - 0.6, 0, 1) * 2.0
heart = np.clip(1.0 - r / 0.09, 0, 1)
saw = 0.5 + 0.5 * np.sin((xx + yy * 0.08) / N * 0.6 / 0.012 * 2 * math.pi)
col = np.array([0.78, 0.63, 0.45]) * (1 - 0.25 * late[:, :, None]) * (1 - 0.18 * heart[:, :, None])
col = col * (0.95 + 0.05 * saw[:, :, None])
checks = np.zeros((N, N), np.float32)
rng = random.Random(5)
for k in range(6):
    a0 = rng.uniform(-math.pi, math.pi)
    checks = np.maximum(checks, np.clip(1 - np.abs(((ang - a0 + math.pi) % (2 * math.pi)) - math.pi) / 0.012, 0, 1) * (r < 0.2) * (r > 0.03))
col *= (1 - 0.6 * checks)[:, :, None]
weather = np.clip((r - 0.24) / 0.04, 0, 1)
col = col * (1 - 0.45 * weather[:, :, None]) + np.array([0.3, 0.27, 0.24]) * 0.45 * weather[:, :, None]
save(col, "site_wood_end_diff.jpg")
hh = rings * 0.0004 + saw * 0.00025 - checks * 0.002
hn = height_to_n(hh, 0.6 / N, 1.0)
save(pack_n(hn), "site_wood_end_nor.jpg", True)


# ------------------------------------------------------------------ alpha decals (own work)
def rgba(col, a):
    a = np.clip(a, 0, 1)
    c = np.broadcast_to(np.array(col, np.float32), a.shape + (3,)) if np.ndim(col) == 1 else col
    return np.dstack([c, a])


S = 512
yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
U = (xx + 0.5) / S; Vv = (yy + 0.5) / S
n1 = tnoise(S, S, 18, 41, 3); n2 = tnoise(S, S, 6, 42, 2)
# rust run: from a bolt near the top, fanning down with drips
a = np.exp(-((U - 0.5) / (0.06 + 0.25 * Vv)) ** 2) * (1 - Vv) ** 0.8 * np.clip(0.7 + 0.5 * n1, 0, 1)
a += np.exp(-((U - 0.5) / 0.035) ** 2 - ((Vv - 0.08) / 0.04) ** 2) * 0.9
for k, (fx, fl) in enumerate(((0.42, 0.85), (0.55, 0.95), (0.6, 0.7), (0.47, 0.6))):
    a += 0.45 * np.exp(-((U - fx) / 0.01) ** 2) * (Vv < fl) * (1 - Vv / fl)
col = np.dstack([0.42 + 0.1 * n2, 0.20 + 0.05 * n2, 0.08 + 0.02 * n2])
save(rgba(col, a * 0.9), "site_decal_rust.png")
# algae: green-brown slime, patchy, densest at the bottom
a = np.clip((Vv - 0.25) / 0.5, 0, 1) * np.clip(0.55 + 0.8 * n1 + 0.3 * n2, 0, 1)
col = np.dstack([0.16 + 0.06 * n2, 0.22 + 0.06 * n1, 0.09 + 0.03 * n2])
save(rgba(col, a), "site_decal_algae.png")
# waterline: a horizontal tide band with a sharp top, drips and a lighter scum line
top = 0.42 + 0.015 * tnoise(S, S, 25, 43)[:1, :]
a = np.clip((Vv - top) / 0.02, 0, 1) * np.clip(1.0 - (Vv - top - 0.25) / 0.2, 0, 1) * np.clip(0.75 + 0.3 * n2, 0, 1)
scum = np.exp(-((Vv - top) / 0.008) ** 2) * 0.7
col = np.dstack([np.full((S, S), 0.24), np.full((S, S), 0.21), np.full((S, S), 0.16)])
col = col * (1 - scum[:, :, None]) + np.array([0.62, 0.58, 0.48]) * scum[:, :, None]
save(rgba(col, np.maximum(a, scum)), "site_decal_waterline.png")
# crack: a branching hairline crack across concrete
im = Image.new("L", (S, S), 0)
dr = ImageDraw.Draw(im)
rng = random.Random(44)
def crack(x, y, ang, L, w, depth):
    for i in range(int(L)):
        nx = x + math.cos(ang) * 4; ny = y + math.sin(ang) * 4
        dr.line((x, y, nx, ny), fill=255, width=max(1, int(w)))
        x, y = nx, ny
        ang += rng.uniform(-0.35, 0.35)
        w = max(1.0, w * 0.995)
        if depth < 3 and rng.random() < 0.03:
            crack(x, y, ang + rng.choice((-1, 1)) * rng.uniform(0.5, 1.0), L * 0.4, w * 0.6, depth + 1)
crack(10, 260, 0.05, 125, 3.2, 0)
crack(250, 250, 1.4, 50, 2.0, 1)
cm = np.asarray(im.filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32) / 255
halo = np.asarray(im.filter(ImageFilter.GaussianBlur(5))).astype(np.float32) / 255
save(rgba(np.array([0.10, 0.10, 0.09]), np.clip(cm + halo * 0.35, 0, 1)), "site_decal_crack.png")
# oil: dark blot with soft edge and a faint sheen ring
r = np.sqrt((U - 0.5) ** 2 + (Vv - 0.5) ** 2) * (1 + 0.25 * n1)
a = np.clip(1 - (r - 0.25) / 0.12, 0, 1) * 0.85
ring = np.exp(-((r - 0.3) / 0.02) ** 2) * 0.3
col = np.dstack([0.05 + ring * 0.2, 0.05 + ring * 0.15, 0.06 + ring * 0.25])
save(rgba(col, a), "site_decal_oil.png")
# tyre print: a 200 mm wide strip of tread blocks pressed into mud, 1.6 m long (128 x 1024)
TH, TW = 1024, 128
yy2, xx2 = np.mgrid[0:TH, 0:TW].astype(np.float32)
uu = (xx2 + 0.5) / TW; vv2 = (yy2 + 0.5) / TH * 1.6
blk = ((np.floor(vv2 / 0.035) + (uu > 0.5)) % 2 == 0) & (np.abs(uu - 0.5) > 0.06) & (np.abs(uu - 0.5) < 0.46)
groove = (np.abs(((vv2 + (uu - 0.5) * 0.04) % 0.035) - 0.0175) < 0.006)
fade = np.clip(1 - np.abs(uu - 0.5) / 0.5, 0, 1) ** 0.3 * np.clip(0.6 + 0.6 * tnoise(TH, TW, 40, 45), 0, 1)
a = (0.35 + 0.5 * blk + 0.25 * groove) * fade
save(rgba(np.array([0.18, 0.15, 0.11]), a), "site_decal_tyre.png")
# damp: a dark wet stain spreading from the top with runs
a = np.clip(1 - np.sqrt(((U - 0.5) / 0.42) ** 2 + ((Vv - 0.35) / 0.4) ** 2) + 0.25 * n1, 0, 1)
for fx in (0.3, 0.38, 0.52, 0.6, 0.71):
    a = np.maximum(a, np.exp(-((U - fx) / 0.012) ** 2) * (Vv > 0.4) * np.clip(1 - (Vv - 0.4) / rng.uniform(0.3, 0.55), 0, 1))
save(rgba(np.array([0.06, 0.06, 0.05]), np.clip(a, 0, 1) * 0.75), "site_decal_damp.png")
# chalk: faint unreadable scrawl (arcs and strokes, nothing that reads as a letter or a symbol)
im = Image.new("L", (S, S), 0)
dr = ImageDraw.Draw(im)
rng = random.Random(46)
for k in range(9):
    x0, y0 = rng.uniform(80, 420), rng.uniform(120, 380)
    pts = [(x0, y0)]
    a0 = rng.uniform(0, 6.28)
    for i in range(rng.randint(6, 14)):
        a0 += rng.uniform(-0.5, 0.5)
        pts.append((pts[-1][0] + math.cos(a0) * 9, pts[-1][1] + math.sin(a0) * 9))
    dr.line(pts, fill=rng.randint(120, 220), width=rng.randint(3, 6))
ch = np.asarray(im.filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255
ch *= np.clip(0.5 + 0.7 * n2, 0, 1)
save(rgba(np.array([0.86, 0.86, 0.82]), ch * 0.65), "site_decal_chalk.png")
print("done")

# ------------------------------------------------------------------ vehicle dirt overlay atlas (own work), 1024 px RGBA
# Four 512 px quadrants, RGB = the dirt colour (dried road mud), A = coverage; lay them over a body or wheel with a second
# UV or a decal. Top left: lower-body splash (dense at the bottom edge, spatter fading up, for sills and bumpers).
# Top right: wheel-arch spray fan (centred on the bottom middle = the tyre's contact patch). Bottom left: brake dust on a
# rim (a ring, darker at the inner edge). Bottom right: windscreen grime with the two wiper arcs wiped clean.
S2 = 512
yy, xx = np.mgrid[0:S2, 0:S2].astype(np.float32)
U = (xx + 0.5) / S2; Vv = (yy + 0.5) / S2
nA = tnoise(S2, S2, 10, 71, 3); nB = tnoise(S2, S2, 3, 72, 2)
mud = np.dstack([0.36 + 0.05 * nA, 0.29 + 0.04 * nA, 0.21 + 0.03 * nA])
splash = np.clip((Vv - 0.35) / 0.65, 0, 1) ** 1.6 + np.clip(nB - 0.55, 0, 1) * 1.5 * Vv
d = np.sqrt((U - 0.5) ** 2 + (Vv - 1.0) ** 2)
ang = np.arctan2(1.0 - Vv, U - 0.5)
spray = np.clip(1 - d / 0.95, 0, 1) * np.clip(np.sin(ang) * 1.3, 0, 1) * np.clip(0.6 + 0.7 * nA + 0.6 * np.clip(nB - 0.4, 0, 1), 0, 1)
r = np.sqrt((U - 0.5) ** 2 + (Vv - 0.5) ** 2)
brake = np.clip(1 - np.abs(r - 0.3) / 0.16, 0, 1) * np.clip(0.7 + 0.5 * nA, 0, 1)
dust = np.dstack([0.16 + 0.03 * nA, 0.14 + 0.02 * nA, 0.12 + 0.02 * nA])
wipe = np.ones((S2, S2), np.float32)
for cx in (0.3, 0.72):
    rr = np.sqrt((U - cx) ** 2 + (Vv - 1.02) ** 2)
    wipe *= 1 - np.clip(1 - np.abs(rr - 0.3) / 0.22, 0, 1) * (Vv < 1.0)
grime = np.clip(0.35 + 0.4 * nA, 0, 1) * np.clip(wipe + 0.15, 0, 1) * (0.5 + 0.5 * Vv)
atlas = np.zeros((1024, 1024, 4), np.float32)
atlas[:512, :512] = np.dstack([mud, np.clip(splash * (0.75 + 0.3 * nA), 0, 1)])
atlas[:512, 512:] = np.dstack([mud, np.clip(spray, 0, 1)])
atlas[512:, :512] = np.dstack([dust, np.clip(brake, 0, 1)])
atlas[512:, 512:] = np.dstack([mud * 0.8, np.clip(grime, 0, 1)])
save(atlas, "vehicle_dirt_atlas.png")

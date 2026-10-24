"""Textures of lane/antidrone (Harlan Pike's ridge, docs/CLAUDE-ANTI-DRONE-ASSETS.md on lane/notify).
Run: python -I make_antidrone_textures.py <godot dir>

Photographed CC0 sources already on this PC, composited with drawn masks (own work, CC0):
  pike_ridge_clearing.jpg (+ _nor, _arm)  the 12 x 12 m clearing, NOT tiling (u, v 0..1 over the patch): beaten dry grass
                    (Poly Haven dry grass, the shared rwj_procgen set), a bare dirt patch under the trailer (park_dirt),
                    two wheel ruts curving in from the south edge (aerial_mud_1), oil stains by the generator, a jerked
                    drag mark and boot-trodden paths to the shack
Drawn decals and cards (own work, CC0; no readable text anywhere):
  pike_no_drone_stencil.png   spray-painted quadcopter in a circle with a slash, red over black, overspray and drips
  pike_manifesto_paper.png    one taped page, yellowed, with unreadable typed lines (bars, not glyphs)
  pike_paper_blank.png        the same page with nothing on it (the face the game writes on with Label3D)
  pike_notice_stack.png       a damp stack of notices and envelopes, seen from above, unreadable
  pike_strobe_card.png        a red strobe flare card (additive) the code can flash on the beacon
  pike_smoke_card.png         a thin smoke wisp card (alpha) for the broken mast
  pike_tyre_marks.png         tyre tread prints and a skid in mud (alpha decal)
Writes .import files next to them. Sources and licences: assets/textures/README.md (lane/antidrone section)."""
import os, sys, math
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

GODOT = sys.argv[1]
DST = os.path.join(GODOT, "assets", "textures")
ROOT = os.path.normpath(os.path.join(GODOT, "..", ".."))
SH = os.path.join(ROOT, "RWJ-Shared-Assets", "godot", "addons", "rwj_procgen", "textures")
TX = DST

IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://assets/textures/{name}"

[params]

compress/mode={mode}
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
        f.write(IMPORT.format(name=name, nm=1 if normal else 0, mode=2))


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
    """periodic smooth noise in -1..1; px = feature size in pixels"""
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
    """resample a tiling source (one repeat = src_m metres) onto out_hw pixels covering out_m metres"""
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


def pack_n(v):
    l = np.linalg.norm(v, axis=2, keepdims=True) + 1e-9
    return (v / l) * 0.5 + 0.5


def height_to_n(h, px_m, strength=1.0):
    gy, gx = np.gradient(h)
    v = np.stack([-gx / px_m * strength, gy / px_m * strength, np.ones_like(h)], axis=2)
    return v


def whiteout(a, b):
    """blend two tangent-space normals (unpacked -1..1)"""
    return np.stack([a[..., 0] + b[..., 0], a[..., 1] + b[..., 1], a[..., 2] * b[..., 2]], axis=2)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


# ============================================================================================ the clearing (12 x 12 m)
N = 2048
M = 12.0
px_m = M / N
yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
X = (xx + 0.5) / N * M - M / 2          # metres, +x right
Z = (yy + 0.5) / N * M - M / 2          # metres, image down = +z (south, toward the track)

gd = tile_to(load(os.path.join(SH, "grass_dry_diff.jpg")), 2.0, (N, N), (M, M))
gn = tile_to(load(os.path.join(SH, "grass_dry_nor.jpg")), 2.0, (N, N), (M, M))
ga = tile_to(load(os.path.join(SH, "grass_dry_arm.jpg")), 2.0, (N, N), (M, M))
g2 = tile_to(load(os.path.join(SH, "grass2_diff.jpg")), 2.5, (N, N), (M, M))
dd = tile_to(load(os.path.join(SH, "dirt_diff.jpg")), 2.0, (N, N), (M, M))
dn = tile_to(load(os.path.join(SH, "dirt_nor.jpg")), 2.0, (N, N), (M, M))
da = tile_to(load(os.path.join(SH, "dirt_arm.jpg")), 2.0, (N, N), (M, M))
md = tile_to(load(os.path.join(TX, "mudtrack_diff.jpg")), 2.5, (N, N), (M, M))
mn = tile_to(load(os.path.join(TX, "mudtrack_nor.jpg")), 2.5, (N, N), (M, M))
ma = tile_to(load(os.path.join(TX, "mudtrack_arm.jpg")), 2.5, (N, N), (M, M))

n1 = tnoise(N, N, 90, 11, 3)
n2 = tnoise(N, N, 30, 12, 2)
n3 = tnoise(N, N, 8, 13, 1)

# beaten grass: the dry set, trodden darker and flatter toward the middle, with the greener set where nobody walks
r = np.sqrt(X ** 2 + Z ** 2)
trod = smoothstep(5.8, 2.2, r + n1 * 0.9)
outer = (smoothstep(3.5, 6.0, r + n1) * 0.5)[..., None]
alb = (gd * (1 - outer) + g2 * 0.95 * outer) * (1 - trod[..., None] * 0.07)
nor = gn * 2 - 1
arm = ga.copy()

# the bare patch under the trailer (trailer stands at the middle, hitch toward +z), ragged edge
bare = smoothstep(1.05, 0.6, ((np.abs(X) / 1.7) ** 3 + (np.abs(Z + 0.3) / 2.5) ** 3) ** (1 / 3) + n2 * 0.16 + n1 * 0.12)
# boot paths: trailer -> shack (north-west) and trailer -> generator (east)
def path_mask(p0, p1, w):
    p0 = np.array(p0, np.float32); p1 = np.array(p1, np.float32)
    d = p1 - p0
    L2 = float(d @ d)
    t = np.clip(((X - p0[0]) * d[0] + (Z - p0[1]) * d[1]) / L2, 0, 1)
    px = p0[0] + d[0] * t; pz = p0[1] + d[1] * t
    dist = np.sqrt((X - px) ** 2 + (Z - pz) ** 2)
    return smoothstep(w, w * 0.35, dist + n2 * w * 0.5)
paths = np.maximum(path_mask((-0.6, -1.4), (-4.4, -4.6), 0.45), path_mask((1.3, -0.4), (3.6, 0.3), 0.38))
paths *= np.clip(0.55 + 0.45 * tnoise(N, N, 12, 14, 1), 0, 1)          # trodden in patches, not a painted stripe
bare = np.maximum(bare, paths * 0.6)
alb = alb * (1 - bare[..., None]) + dd * 0.92 * bare[..., None]
nor = nor * (1 - bare[..., None]) + (dn * 2 - 1) * bare[..., None]
arm = arm * (1 - bare[..., None]) + da * bare[..., None]

# wheel ruts: two arcs coming in from the south edge to the trailer wheels (x = +-0.82), 0.22 m wide, sunk
def arc_dist(x0):
    # the rut follows x = x0 + k (z - z0)^2 from the wheel (z = 0) to the south edge
    k = 0.035
    xc = x0 + k * np.maximum(Z, 0.0) ** 2 * np.sign(x0 + 1e-6) * 0.6 + 0.25 * np.maximum(Z, 0) * 0.08
    return np.abs(X - xc)
rut = np.zeros_like(X)
rut_edge = np.zeros_like(X)
for x0 in (-0.82, 0.82):
    dist = arc_dist(x0)
    w = 0.13 + 0.03 * n2
    m = smoothstep(w, w * 0.45, dist + n3 * 0.025 + n2 * 0.03) * smoothstep(-0.4, 0.8, Z)
    e = smoothstep(w + 0.12, w, dist + n2 * 0.04) * smoothstep(-0.4, 0.8, Z)
    rut = np.maximum(rut, m)
    rut_edge = np.maximum(rut_edge, e)
# rut floor: the dirt set, darker and wetter, with tread lugs; a band of crushed grass along each side
mud = dd * np.array([0.62, 0.58, 0.54]) * (0.9 + 0.1 * n3[..., None])
lug = (np.sin(Z * 2 * math.pi / 0.11) > 0.2).astype(np.float32) * 0.12
alb = alb * (1 - rut_edge[..., None] * 0.22) + dd * 0.85 * rut_edge[..., None] * 0.22
alb = alb * (1 - rut[..., None]) + mud * (1 - lug[..., None] * rut[..., None]) * rut[..., None]
arm[..., 1] = arm[..., 1] * (1 - rut * 0.4)                             # wet ruts are a little glossier
hgt = -rut * 0.06 - lug * rut * 0.008

# the jerked drag mark: the trailer was pulled sideways once; a faint skid scuff behind the left wheel
drag = path_mask((-0.82, 0.5), (-1.5, 2.2), 0.10) * smoothstep(0.0, 0.4, Z)
alb = alb * (1 - drag[..., None] * 0.35) + dd * 0.7 * drag[..., None] * 0.35
hgt -= drag * 0.01

# oil stains by the generator (east of the trailer) and under the hitch: warped, splattered, a darker core and a
# brownish halo where the oil has wicked into the soil
oil = np.zeros_like(X)
halo = np.zeros_like(X)
warp = tnoise(N, N, 22, 15, 2)
rng = np.random.default_rng(3)
spots = [(2.6, 0.1, 0.5), (3.1, 0.55, 0.28), (0.05, 1.9, 0.3), (-0.3, -0.6, 0.22)]
for k in range(10):
    spots.append((2.7 + rng.uniform(-0.8, 0.8), 0.3 + rng.uniform(-0.6, 0.6), rng.uniform(0.04, 0.10)))
for (ox, oz, rr) in spots:
    d = np.sqrt((X - ox) ** 2 + (Z - oz) ** 2) * (1 + 0.35 * warp) + n2 * rr * 0.3
    oil = np.maximum(oil, smoothstep(rr, rr * 0.55, d))
    halo = np.maximum(halo, smoothstep(rr * 1.6, rr * 0.9, d))
alb = alb * (1 - halo[..., None] * 0.18) * (1 - oil[..., None] * 0.55)
alb = alb + oil[..., None] * np.array([0.015, 0.012, 0.008])
arm[..., 1] = arm[..., 1] * (1 - oil * 0.6)
arm[..., 0] = arm[..., 0] * (1 - oil * 0.15)

# fine grit and a slight overall dimming toward the edge (the forest shades it)
alb *= 1.12 * (1.0 + n3[..., None] * 0.03) * (0.98 - 0.08 * smoothstep(4.5, 6.0, r))[..., None]
hgt += n2 * 0.004
nrm = whiteout(nor, height_to_n(hgt, px_m, 1.0))
save(alb, "pike_ridge_clearing.jpg", q=86)
save(pack_n(nrm), "pike_ridge_clearing_nor.jpg", normal=True)
arm[..., 2] = 0.0
save(arm, "pike_ridge_clearing_arm.jpg")


# ============================================================================================ drawn cards and decals
def spray_noise(h, w, seed):
    rng = np.random.default_rng(seed)
    return rng.random((h, w)).astype(np.float32)


def stencil():
    S = 1024
    im = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(im)
    c = S / 2
    # circle
    d.ellipse((c - 430, c - 430, c + 430, c + 430), outline=255, width=64)
    # the quadcopter: an X of arms, a body and four rotor rings
    for sx in (-1, 1):
        for sz in (-1, 1):
            ex, ez = c + sx * 200, c + sz * 200
            d.line((c, c, ex, ez), fill=255, width=44)
            d.ellipse((ex - 110, ez - 110, ex + 110, ez + 110), outline=255, width=30)
    d.rounded_rectangle((c - 80, c - 62, c + 80, c + 62), radius=24, fill=255)
    red = np.asarray(im).astype(np.float32) / 255.0
    sl = Image.new("L", (S, S), 0)
    ds = ImageDraw.Draw(sl)
    ds.line((c - 310, c - 310, c + 310, c + 310), fill=255, width=78)
    slash = np.asarray(sl).astype(np.float32) / 255.0
    # spray: soft edge, overspray halo, grain, drips under the slash and the ring
    def soften(a, rad):
        return np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(rad))).astype(np.float32) / 255.0
    grain = spray_noise(S, S, 5)
    core = np.clip(soften(red, 3.0) * 1.15, 0, 1)
    halo = soften(red, 18.0) * 0.45 * (grain > 0.55)
    sl_core = np.clip(soften(slash, 3.0) * 1.15, 0, 1)
    sl_halo = soften(slash, 16.0) * 0.4 * (grain > 0.5)
    drips = np.zeros((S, S), np.float32)
    rng = np.random.default_rng(9)
    for k in range(14):
        x = int(rng.uniform(c - 330, c + 330)); y0 = int(c + (x - c) + 30) if rng.random() < 0.6 else int(c + math.sqrt(max(0.0, 430 ** 2 - (x - c) ** 2)) + 20)
        L = int(rng.uniform(40, 180)); w = int(rng.uniform(5, 10))
        drips[max(0, y0):min(S, y0 + L), max(0, x - w // 2):min(S, x + w // 2)] = 1.0
        yy2 = min(S - 1, y0 + L)
        drips[max(0, yy2 - w):yy2 + w // 2, max(0, x - w):min(S, x + w)] = 1.0
    drips = soften(drips, 1.5)
    a_red = np.clip(core + halo * (1 - core) + drips * 0.85, 0, 1) * (0.82 + 0.18 * grain)
    a_blk = np.clip(sl_core + sl_halo * (1 - sl_core), 0, 1) * (0.85 + 0.15 * grain)
    rgb = np.zeros((S, S, 3), np.float32)
    redc = np.array([0.62, 0.06, 0.05]); blk = np.array([0.04, 0.035, 0.03])
    rgb[:] = redc
    rgb = rgb * (1 - a_blk[..., None]) + blk * a_blk[..., None]
    a = np.clip(a_red + a_blk, 0, 1)
    img = np.concatenate([rgb, a[..., None]], axis=2)
    small = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGBA").resize((512, 512), Image.LANCZOS)
    save(np.asarray(small).astype(np.float32) / 255.0, "pike_no_drone_stencil.png")


def paper(lined, name):
    W, H = 512, 724
    rng = np.random.default_rng(21 if lined else 22)
    n1 = tnoise(H, W, 60, 31, 3); n2 = tnoise(H, W, 6, 32, 1)
    base = np.array([0.86, 0.80, 0.62])
    yy3, xx3 = np.mgrid[0:H, 0:W].astype(np.float32)
    edge = np.minimum(np.minimum(xx3, W - 1 - xx3), np.minimum(yy3, H - 1 - yy3))
    yellow = 0.06 + 0.10 * smoothstep(60, 0, edge + n1 * 18)
    rgb = base[None, None, :] * (1 - yellow[..., None]) + np.array([0.70, 0.58, 0.32]) * yellow[..., None]
    rgb *= (1 + n2[..., None] * 0.025)
    # a water stain: a pale ring and a darker rim
    cx, cy, rr = W * 0.7, H * 0.78, 90
    d = np.sqrt((xx3 - cx) ** 2 + (yy3 - cy) ** 2) + n1 * 14
    ring = smoothstep(8, 0, np.abs(d - rr)) * 0.35
    rgb = rgb * (1 - ring[..., None] * 0.3) + np.array([0.55, 0.42, 0.22]) * ring[..., None] * 0.3
    if lined:
        ink = np.zeros((H, W), np.float32)
        im = Image.new("L", (W, H), 0); dr = ImageDraw.Draw(im)
        # heading bar, then justified-looking typed lines: bars only, nothing readable
        dr.rectangle((70, 58, 442, 84), fill=230)
        y = 120
        while y < H - 70:
            if rng.random() < 0.12:
                y += 16
                continue
            x = 52
            end = W - 52 - (rng.uniform(0, 220) if rng.random() < 0.2 else rng.uniform(0, 14))
            while x < end:
                wl = rng.uniform(10, 46)
                dr.rectangle((x, y, min(end, x + wl), y + 6), fill=int(rng.uniform(150, 220)))
                x += wl + rng.uniform(5, 8)
            y += 14
        # an underlined "important" bit and a hand-scrawled margin note (scribble, not letters)
        dr.rectangle((52, 300, 300, 302), fill=200)
        pts = [(440 + 18 * math.sin(t * 0.9), 360 + t * 3.2) for t in range(40)]
        dr.line(pts, fill=170, width=2)
        ink = np.asarray(im.filter(ImageFilter.GaussianBlur(0.9))).astype(np.float32) / 255.0
        ink *= (0.75 + 0.25 * (tnoise(H, W, 3, 33, 1) * 0.5 + 0.5))          # uneven toner
        rgb = rgb * (1 - ink[..., None] * 0.82) + np.array([0.08, 0.07, 0.07]) * ink[..., None] * 0.82
    # tape at the four corners: translucent, slightly yellow, with a lifted edge
    alpha = np.ones((H, W), np.float32)
    for (tx, ty, ang) in ((0, 0, 40), (W, 0, -40), (0, H, -40), (W, H, 40)):
        im = Image.new("L", (W, H), 0); dr = ImageDraw.Draw(im)
        a = math.radians(ang); ux, uy = math.cos(a), math.sin(a); vx, vy = -uy, ux
        L, Wt = 70, 22
        pts = [(tx + ux * L + vx * Wt, ty + uy * L + vy * Wt), (tx - ux * L + vx * Wt, ty - uy * L + vy * Wt),
               (tx - ux * L - vx * Wt, ty - uy * L - vy * Wt), (tx + ux * L - vx * Wt, ty + uy * L - vy * Wt)]
        dr.polygon(pts, fill=255)
        t = np.asarray(im).astype(np.float32) / 255.0
        rgb = rgb * (1 - t[..., None] * 0.28) + np.array([0.92, 0.86, 0.62]) * t[..., None] * 0.28
    # slightly ragged, dog-eared outline in alpha (a page, not a rectangle of colour)
    alpha = smoothstep(0.0, 2.0, edge + n2 * 1.5)
    img = np.concatenate([np.clip(rgb, 0, 1), alpha[..., None]], axis=2)
    save(img, name)


def notice_stack():
    S = 512
    rng = np.random.default_rng(41)
    out = np.zeros((S, S, 4), np.float32)
    for k in range(9):
        w = rng.uniform(250, 340); h = w * (0.6 if k % 3 == 0 else 1.35)
        h = min(h, 400)
        cx, cy = S / 2 + rng.uniform(-50, 50), S / 2 + rng.uniform(-40, 40)
        ang = rng.uniform(-22, 22)
        im = Image.new("L", (S, S), 0); dr = ImageDraw.Draw(im)
        a = math.radians(ang); ux, uy = math.cos(a), math.sin(a); vx, vy = -uy, ux
        P = lambda u, v: (cx + ux * u + vx * v, cy + uy * u + vy * v)
        dr.polygon([P(-w / 2, -h / 2), P(w / 2, -h / 2), P(w / 2, h / 2), P(-w / 2, h / 2)], fill=255)
        m = np.asarray(im).astype(np.float32) / 255.0
        env = k % 3 == 0
        col = np.array([0.80, 0.74, 0.58]) if env else np.array([0.88, 0.86, 0.80]) * rng.uniform(0.85, 1.0)
        layer = np.zeros((S, S, 3), np.float32) + col
        im2 = Image.new("L", (S, S), 0); d2 = ImageDraw.Draw(im2)
        if env:
            d2.line([P(-w / 2, -h / 2), P(0, 0), P(w / 2, -h / 2)], fill=120, width=2)       # flap
            for i in range(3):
                d2.line([P(-w * 0.1, h * 0.05 + i * 12), P(w * 0.3, h * 0.05 + i * 12)], fill=170, width=4)
            d2.rectangle([P(w * 0.3, -h * 0.4), P(w * 0.42, -h * 0.22)], outline=150, width=2)
        else:
            d2.line([P(-w * 0.35, -h * 0.4), P(w * 0.2, -h * 0.4)], fill=200, width=8)
            for i in range(14):
                L = w * rng.uniform(0.4, 0.7)
                d2.line([P(-w * 0.38, -h * 0.3 + i * 15), P(-w * 0.38 + L, -h * 0.3 + i * 15)], fill=150, width=3)
        ink = np.asarray(im2.filter(ImageFilter.GaussianBlur(0.8))).astype(np.float32) / 255.0
        layer = layer * (1 - ink[..., None] * 0.7) + 0.1 * ink[..., None] * 0.7
        damp = (tnoise(S, S, 40, 50 + k, 2) * 0.5 + 0.5)
        layer *= (1 - 0.25 * smoothstep(0.55, 0.85, damp))[..., None]
        out[..., :3] = out[..., :3] * (1 - m[..., None]) + layer * m[..., None]
        out[..., 3] = np.maximum(out[..., 3], m)
    # shadow between sheets is in the vertex AO; keep the edge soft
    out[..., 3] = np.asarray(Image.fromarray((out[..., 3] * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7))).astype(np.float32) / 255.0
    save(out, "pike_notice_stack.png")


def strobe_card():
    S = 256
    yy4, xx4 = np.mgrid[0:S, 0:S].astype(np.float32)
    dx, dy = (xx4 - S / 2 + 0.5) / (S / 2), (yy4 - S / 2 + 0.5) / (S / 2)
    r = np.sqrt(dx ** 2 + dy ** 2)
    core = np.exp(-(r / 0.08) ** 2)
    glow = np.exp(-(r / 0.35) ** 2) * 0.55
    ang = np.arctan2(dy, dx)
    streak = (np.abs(np.cos(ang * 2)) ** 40 + 0.5 * np.abs(np.cos(ang * 2 + math.pi / 4)) ** 60) * np.exp(-(r / 0.75) ** 2) * 0.6
    a = np.clip(core + glow + streak, 0, 1) * smoothstep(1.0, 0.85, r)
    rgb = np.stack([np.ones_like(a), 0.25 + 0.75 * core, 0.18 + 0.82 * core], axis=2) * np.array([1.0, 0.35, 0.3])
    rgb = np.clip(rgb + core[..., None] * 0.6, 0, 1)
    save(np.concatenate([rgb, a[..., None]], axis=2), "pike_strobe_card.png")


def smoke_card():
    W, H = 256, 1024
    yy5, xx5 = np.mgrid[0:H, 0:W].astype(np.float32)
    v = 1.0 - yy5 / H                    # 0 at the bottom (source), 1 at the top
    n1 = tnoise(H, W, 48, 61, 3); n2 = tnoise(H, W, 14, 62, 2)
    sway = (np.sin(v * 5.5) * 0.12 + n1 * 0.08) * v
    width = 0.05 + 0.32 * v ** 0.8
    d = np.abs((xx5 / W - 0.5) - sway) / width
    dens = np.exp(-d ** 2 * 2.2) * (0.55 + 0.45 * (n2 * 0.5 + 0.5))
    dens *= smoothstep(0.0, 0.06, v) * smoothstep(1.0, 0.55, v)
    a = np.clip(dens * 1.6, 0, 1)
    grey = 0.42 + 0.22 * v + n2 * 0.04
    rgb = np.stack([grey, grey * 0.99, grey * 0.97], axis=2)
    save(np.concatenate([np.clip(rgb, 0, 1), a[..., None]], axis=2), "pike_smoke_card.png")


def tyre_marks():
    """two tread prints running up the card (v) and a sideways skid at the top; alpha decal, mud colour"""
    W, H = 512, 1024
    yy6, xx6 = np.mgrid[0:H, 0:W].astype(np.float32)
    n1 = tnoise(H, W, 30, 71, 2); n2 = tnoise(H, W, 5, 72, 1)
    a = np.zeros((H, W), np.float32)
    for cx in (0.25, 0.75):
        u = (xx6 / W - cx) / 0.09
        band = smoothstep(1.0, 0.8, np.abs(u))
        lug = ((np.floor(yy6 / 22 + (np.sign(u) * 0.5)) % 2) == 0).astype(np.float32)
        tread = np.clip(0.55 + 0.45 * lug * smoothstep(0.15, 0.4, np.abs(u)), 0, 1)
        a = np.maximum(a, band * tread * smoothstep(0.0, 0.08, yy6 / H))
    skid = smoothstep(0.1, 0.0, np.abs(yy6 / H - 0.12 - (xx6 / W) * 0.12)) * smoothstep(0.95, 0.6, xx6 / W)
    a = np.maximum(a, skid * 0.8)
    a *= (0.75 + 0.25 * (n1 * 0.5 + 0.5)) * (0.85 + 0.15 * n2)
    rgb = np.stack([0.19 + n2 * 0.02, 0.15 + n2 * 0.02, 0.11 + n2 * 0.015], axis=2)
    save(np.concatenate([rgb, np.clip(a, 0, 1)[..., None] * 0.9], axis=2), "pike_tyre_marks.png")


stencil()
paper(True, "pike_manifesto_paper.png")
paper(False, "pike_paper_blank.png")
notice_stack()
strobe_card()
smoke_card()
tyre_marks()
print("done")

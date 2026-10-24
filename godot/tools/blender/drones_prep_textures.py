# Prepare the drone texture sets (run with the system Python, which has PIL and numpy; Blender's Python has neither).
# Input: the downloaded CC0 sets (ambientCG 1K-JPG zips, extracted) in a folder given as argv[1].
# Output: godot/assets/textures/drones/drone_*.jpg, 1024 px. Blender embeds them in the .glb files (so the files stand on
# their own outside the game); Godot imports these copies once (VRAM compressed, mipmapped) and game/drone_assets.gd puts
# them on the drones by material name, so every drone and level of detail shares one set (see assets/textures/README.md).
#
# Every set is written as a normal map (OpenGL, +Y up) and an ORM map (r occlusion = 1, g roughness, b metal), with the
# roughness remapped into the range the material needs, so the glTF file can carry it as-is (glTF has no roughness
# remap). Base colours are constants in the materials, except carbon and the strap, which keep their weave colour.
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SRC = sys.argv[1]
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "textures", "drones")
OUT = os.path.abspath(OUT)
os.makedirs(OUT, exist_ok=True)
N = 1024


def load(rel, mode="L"):
    return Image.open(os.path.join(SRC, rel)).convert(mode).resize((N, N), Image.LANCZOS)


def remap(img, lo, hi):
    a = np.asarray(img, dtype=np.float32) / 255.0
    a = (a - a.mean()) / max(a.std(), 1e-3)          # normalise the source's contrast, then fit the wanted range
    a = np.clip(0.5 + a * 0.22, 0.0, 1.0)
    return lo + (hi - lo) * a


def save_orm(name, rough, metal):
    r = np.ones((N, N), np.float32)
    g = rough
    b = np.full((N, N), float(metal), np.float32)
    rgb = np.stack([r, g, b], -1)
    Image.fromarray((rgb * 255.0 + 0.5).astype(np.uint8)).save(os.path.join(OUT, name + "_orm.jpg"), quality=90)


def save_nor(name, rel, strength=1.0):
    n = np.asarray(load(rel, "RGB"), dtype=np.float32) / 127.5 - 1.0
    n[..., 0] *= strength
    n[..., 1] *= strength
    n[..., 2] = np.sqrt(np.clip(1.0 - n[..., 0] ** 2 - n[..., 1] ** 2, 0.0, 1.0))
    Image.fromarray(((n + 1.0) * 127.5 + 0.5).clip(0, 255).astype(np.uint8)).save(os.path.join(OUT, name + "_nor.jpg"), quality=92)


# carbon: the 2x2 twill of a frame plate. Colour from the weave (dark, the tows a little lighter), resin gloss on top.
col = np.asarray(load("x_Fabric004/Fabric004_1K-JPG_Color.jpg", "RGB"), dtype=np.float32) / 255.0
lum = col.mean(-1, keepdims=True)
lum = (lum - lum.min()) / max(lum.max() - lum.min(), 1e-3)
carbon = 0.018 + 0.075 * lum ** 1.4                         # sRGB 0.02 to 0.09: carbon is nearly black with a silvery tow sheen
carbon = np.concatenate([carbon * 0.97, carbon * 0.99, carbon * 1.04], -1)
Image.fromarray((carbon * 255.0 + 0.5).clip(0, 255).astype(np.uint8)).save(os.path.join(OUT, "drone_carbon_diff.jpg"), quality=92)
save_nor("drone_carbon", "x_Fabric004/Fabric004_1K-JPG_NormalGL.jpg", 0.8)
save_orm("drone_carbon", remap(load("x_Fabric004/Fabric004_1K-JPG_Roughness.jpg"), 0.16, 0.34), 0.0)

# brushed aluminium (standoffs, anodised parts): Metal009, linear brushing
save_nor("drone_brushed", "x_Metal009/Metal009_1K-JPG_NormalGL.jpg", 0.6)
save_orm("drone_brushed", remap(load("x_Metal009/Metal009_1K-JPG_Roughness.jpg"), 0.2, 0.42), 1.0)

# spun aluminium (motor bell tops): Metal051A, circular brushing round the middle of the tile
save_nor("drone_spun", "x_Metal051A/Metal051A_1K-JPG_NormalGL.jpg", 0.7)
save_orm("drone_spun", remap(load("x_Metal051A/Metal051A_1K-JPG_Roughness.jpg"), 0.16, 0.34), 1.0)

# moulded plastic with handling scratches (camera bodies, shells, connectors): Plastic012B
save_nor("drone_plastic", "x_Plastic012B/Plastic012B_1K-JPG_NormalGL.jpg", 0.5)
save_orm("drone_plastic", remap(load("x_Plastic012B/Plastic012B_1K-JPG_Roughness.jpg"), 0.3, 0.62), 0.0)

# rubber and printed TPU: Rubber004
save_nor("drone_rubber", "x_Rubber004/Rubber004_1K-JPG_NormalGL.jpg", 0.6)
save_orm("drone_rubber", remap(load("x_Rubber004/Rubber004_1K-JPG_Roughness.jpg"), 0.68, 0.92), 0.0)

# woven battery strap: Fabric036, kept as a near-black weave
col = np.asarray(load("x_Fabric036/Fabric036_1K-JPG_Color.jpg", "RGB"), dtype=np.float32) / 255.0
lum = col.mean(-1, keepdims=True)
strap = 0.03 + 0.07 * (lum - lum.min()) / max(lum.max() - lum.min(), 1e-3)
Image.fromarray((np.concatenate([strap, strap, strap * 1.05], -1) * 255.0 + 0.5).clip(0, 255).astype(np.uint8)).save(os.path.join(OUT, "drone_strap_diff.jpg"), quality=90)
save_nor("drone_strap", "x_Fabric036/Fabric036_1K-JPG_NormalGL.jpg", 1.0)
save_orm("drone_strap", remap(load("x_Fabric036/Fabric036_1K-JPG_Roughness.jpg"), 0.7, 0.95), 0.0)


# battery wraps: drawn here, no words and no brand: a printed shrink-wrap with a colour band, a pale rating panel with
# lines of tiny "print" and a bar code. One for each drone. UV: u along the pack's length, v round it.
def wrap(name, base, band, band2):
    W, H = 1024, 512
    im = Image.new("RGB", (W, H), base)
    d = ImageDraw.Draw(im)
    d.rectangle([0, int(H * 0.42), W, int(H * 0.58)], fill=band)
    d.rectangle([0, int(H * 0.585), W, int(H * 0.61)], fill=band2)
    # a carbon-look chevron print on the dark part
    for k in range(-20, 60):
        x = k * 34
        d.line([(x, 0), (x + 90, int(H * 0.4))], fill=tuple(min(255, c + 9) for c in base), width=10)
    # rating panel on one side (v 0.05..0.35 is the top face of the pack)
    px0, py0, px1, py1 = int(W * 0.2), int(H * 0.7), int(W * 0.56), int(H * 0.9)
    d.rounded_rectangle([px0, py0, px1, py1], radius=10, fill=(112, 112, 110))
    rng = np.random.default_rng(7)
    y = py0 + 12
    for row in range(7):
        x = px0 + 14
        while x < px1 - 90:
            w = int(rng.integers(6, 22))
            d.rectangle([x, y, min(x + w, px1 - 90), y + 3], fill=(48, 48, 50))
            x += w + int(rng.integers(5, 9))
        y += 11
    bx = px1 - 80
    for k in range(17):
        bw = 1 if k % 3 else 3
        d.rectangle([bx + k * 4, py1 - 40, bx + k * 4 + bw - 1, py1 - 12], fill=(30, 30, 32))
    # big blank cell-count panel on the top face
    d.rounded_rectangle([int(W * 0.66), int(H * 0.08), int(W * 0.94), int(H * 0.34)], radius=18, outline=band, width=8)
    for k in range(3):
        d.rectangle([int(W * 0.7), int(H * (0.13 + k * 0.065)), int(W * (0.9 - 0.06 * k)), int(H * (0.155 + k * 0.065))], fill=band)
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    im.save(os.path.join(OUT, name), quality=92)


wrap("drone_wrap_raptor.jpg", (24, 24, 27), (232, 92, 18), (250, 170, 60))
wrap("drone_wrap_nightowl.jpg", (16, 19, 30), (40, 70, 150), (120, 160, 230))

# printed circuit detail for the flight controller and ESC boards: black solder mask, gold pads, silk-screen lines,
# no words. UV 0..1 over a 36 mm board.
W = 1024
im = Image.new("RGB", (W, W), (14, 15, 17))
d = ImageDraw.Draw(im)
rng = np.random.default_rng(3)
for k in range(140):                                         # copper traces under the mask
    x, y = rng.integers(60, W - 60, 2)
    L = rng.integers(40, 220)
    if rng.random() < 0.5:
        d.line([(x, y), (x + L, y)], fill=(22, 24, 27), width=5)
    else:
        d.line([(x, y), (x, y + L)], fill=(22, 24, 27), width=5)
for cx, cy in [(70, 70), (W - 70, 70), (70, W - 70), (W - 70, W - 70)]:   # mounting holes with gold rings
    d.ellipse([cx - 52, cy - 52, cx + 52, cy + 52], fill=(196, 160, 82))
    d.ellipse([cx - 34, cy - 34, cx + 34, cy + 34], fill=(8, 8, 8))
for side in range(4):                                         # solder pads along the edges
    for k in range(9):
        t = 190 + k * 72
        box = {0: (t, 18, t + 40, 58), 1: (t, W - 58, t + 40, W - 18), 2: (18, t, 58, t + 40), 3: (W - 58, t, W - 18, t + 40)}[side]
        d.rectangle(box, fill=(205, 168, 88))
d.rectangle([150, 150, W - 150, W - 150], outline=(170, 172, 168), width=3)   # silk-screen outline
for k in range(30):
    x, y = rng.integers(170, W - 230, 2)
    d.rectangle([x, y, x + 26, y + 12], outline=(170, 172, 168), width=2)
im.filter(ImageFilter.GaussianBlur(0.5)).save(os.path.join(OUT, "drone_pcb_diff.jpg"), quality=92)

print("wrote", sorted(os.listdir(OUT)))

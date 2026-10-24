"""Chat and Casebook avatars as illustrated emblems (lane avatars). Replaces the appui2 MakeHuman portrait renders.

Robert does not want people-model renders as avatars. Each account gets a profile-picture emblem that says something
about the person: a prop, an animal, a mascot or a mark. One tile shape, one border and one palette (docs/UI-STYLE.md)
hold the set together; the drawing style varies a little per person (cut paper, sticker, flat vector, line drawing,
badge, pixel, hand-drawn doodle). No text, no real crests, brands or likenesses.

Everything is drawn in code at 2048 px (4x supersampling of the 512 root file) with hand-built vector shapes in
Pillow, then downsampled with Lanczos. Outputs, at the exact paths UniverseUI.avatar() and the manifest use:
  assets/ui/avatar_<key>.png             512 x 512 tile, rounded square, transparent outside the corners
  assets/ui/avatars/cutout/<key>.png     512 x 512 the emblem alone on transparent (no tile, no border)
  assets/ui/sizes/96|48/avatar_<key>.png native downscales from the 2048 master, lightly sharpened
Usage: python build_avatars.py [--sheet]     (--sheet also writes docs/realism/models/avatars_final_views.jpg)
"""
import math, os, sys
import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
UI = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "ui"))
N = 2048                      # master canvas, 4x the 512 root file

# Palette: docs/UI-STYLE.md plus one tile colour per person.
CREAM = "#F0E9D1"
PAPER = "#E9DDBE"
INK = "#1F241F"
INK2 = "#2A2F29"
BRASS = "#E0AB59"
BRASS_D = "#B9853A"
MOSS = "#74A87A"
LAKE = "#5C959F"
RUST = "#B36447"
RED = "#DB5C52"
DIM = "#C2C0AE"

TILE = {
    "maya": "#8E3E5C",      # raspberry
    "jo": "#6A5592",        # violet
    "riley": "#5E8A5F",     # moss
    "tom": "#587795",       # storm steel blue
    "sam": "#3B8584",       # lake teal
    "alex": "#B36447",      # rust
    "rennick": "#25314A",   # deep constabulary navy
    "unknown": "#1A1E20",   # charcoal
    "you": "#E0AB59",       # brass, the player's action colour
    "wren": "#E9DDBE",      # field-map paper
    "kit": "#9CC4C8",       # pale lake
}

CAST = [  # key, person, concept, style, one-line rationale
    ("maya", "Maya, editor and channel owner", "clapperboard", "cut paper",
     "Maya cuts every clip before it goes up: a cut-paper clapperboard says editor and channel owner."),
    ("jo", "Jo, events and bookings", "festival ticket", "sticker",
     "Jo books the festival and the parade: a die-cut admit-one ticket with a star punched in."),
    ("riley", "Riley, park ranger", "sheep", "flat vector",
     "Riley guards the pasture, the flock and the graves: a sheep she is protecting."),
    ("tom", "Tom, storm chaser", "storm cloud and bolt", "flat vector",
     "Tom is restless and chases weather: a thundercloud throwing a mustard bolt."),
    ("sam", "Sam, meteorologist", "windsock", "line drawing",
     "Sam is precise about wind windows: a striped windsock drawn in clean lines, gusts trailing."),
    ("alex", "Alex, tech reviewer", "gear and spanner", "embroidered badge",
     "Alex reviews gear and offers tools: a stitched workshop patch with a gear and a spanner."),
    ("rennick", "Constable Rennick, Halloway Valley Constabulary", "peaked cap with a lamp", "badge",
     "Rennick is quiet authority from 1984: a constable's peaked cap carrying a lit lamp, no crest."),
    ("unknown", "Unknown account", "pixel question mark", "pixel",
     "The anonymous account: a low-resolution question mark glowing on charcoal, no face at all."),
    ("you", "You, the pilot", "smiling quadcopter", "sticker",
     "The player: a friendly top-down quadcopter sticker with two LED eyes, on brass."),
    ("wren", "Wren, lost hiker", "wren bird in a scarf", "hand-drawn doodle",
     "Wren is the bird they are named for, in their red scarf, on a dotted trail across map paper."),
    ("kit", "Kit, DroneBudz support", "lifebuoy", "flat vector",
     "Kit is the help desk: a rust-and-cream lifebuoy, the universal sign for 'I can help'."),
]


# ---------------------------------------------------------------- drawing kit (unit coordinates 0..1)

def hx(c, a=255):
    c = c.lstrip("#")
    return (int(c[0:2], 16), int(c[2:4], 16), int(c[4:6], 16), a)


def P(x, y):
    return (x * N, y * N)


def blank():
    return Image.new("L", (N, N), 0)


def m_poly(pts):
    m = blank()
    ImageDraw.Draw(m).polygon([P(*p) for p in pts], fill=255)
    return m


def m_ell(cx, cy, rx, ry=None):
    ry = rx if ry is None else ry
    m = blank()
    ImageDraw.Draw(m).ellipse([P(cx - rx, cy - ry), P(cx + rx, cy + ry)], fill=255)
    return m


def m_rrect(x0, y0, x1, y1, r):
    m = blank()
    ImageDraw.Draw(m).rounded_rectangle([P(x0, y0), P(x1, y1)], radius=r * N, fill=255)
    return m


def m_line(pts, w):
    m = blank()
    d = ImageDraw.Draw(m)
    pp = [P(*p) for p in pts]
    d.line(pp, fill=255, width=max(1, int(w * N)), joint="curve")
    r = w * N / 2
    for x, y in (pp[0], pp[-1]):
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return m


def m_union(*ms):
    out = ms[0]
    for m in ms[1:]:
        out = ImageChops.lighter(out, m)
    return out


def m_sub(a, b):
    return ImageChops.subtract(a, b)


def m_and(a, b):
    return ImageChops.multiply(a, b)


def m_rot(m, deg, cx=0.5, cy=0.5):
    return m.rotate(deg, resample=Image.BICUBIC, center=P(cx, cy))


def m_shift(m, dx, dy):
    return ImageChops.offset(m, int(dx * N), int(dy * N))


def m_grow(m, r):
    """Dilate by roughly r (unit) with a blur + threshold, cheap at 2048."""
    b = m.filter(ImageFilter.GaussianBlur(r * N * 0.5))
    return b.point(lambda v: 255 if v > 8 else int(v * 255 / 8))


def m_scale_alpha(m, a):
    return m.point(lambda v: int(v * a))


def jitter(pts, amp, seed, closed=True, step=0.02):
    """Subdivide a path and push each point by smooth noise: the hand-cut or hand-drawn wobble."""
    rng = np.random.default_rng(seed)
    out = []
    seq = list(pts) + ([pts[0]] if closed else [])
    ph = rng.random(4) * 6.28
    t = 0.0
    for (x0, y0), (x1, y1) in zip(seq[:-1], seq[1:]):
        L = math.hypot(x1 - x0, y1 - y0)
        k = max(1, int(L / step))
        for i in range(k):
            f = i / k
            x, y = x0 + (x1 - x0) * f, y0 + (y1 - y0) * f
            t += L / k
            out.append((x + amp * math.sin(t * 37 + ph[0]) * math.cos(t * 13 + ph[1]),
                        y + amp * math.sin(t * 29 + ph[2]) * math.cos(t * 17 + ph[3])))
    if not closed:
        out.append(seq[-1])
    return out


def circle_pts(cx, cy, r, n=72, ry=None):
    ry = r if ry is None else ry
    return [(cx + r * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)]


class Layer:
    def __init__(self):
        self.img = Image.new("RGBA", (N, N), (0, 0, 0, 0))

    def fill(self, mask, col, alpha=1.0):
        lay = Image.new("RGBA", (N, N), hx(col))
        lay.putalpha(m_scale_alpha(mask, alpha) if alpha < 1 else mask)
        self.img = Image.alpha_composite(self.img, lay)

    def shadow(self, mask, dx=0.010, dy=0.016, blur=0.010, alpha=0.38, col="#0B0D0C"):
        s = m_shift(mask, dx, dy).filter(ImageFilter.GaussianBlur(blur * N))
        self.fill(s, col, alpha)

    def sticker(self, mask, edge=0.030, col=CREAM):
        """Die-cut sticker: a cream margin round the motif and a soft lift shadow."""
        out = m_grow(mask, edge)
        self.shadow(out, 0.006, 0.014, 0.012, 0.42)
        self.fill(out, col)
        return out


# ---------------------------------------------------------------- the tile, shared by every avatar

TILE_R = 0.22          # corner radius as a fraction of the side: the one corner shape of the set
RING_IN = 0.034        # inset of the cream hairline ring
RING_W = 0.014


def tile_mask():
    return m_rrect(0.0, 0.0, 1.0, 1.0, TILE_R)


def tile_background(key):
    base = np.array(hx(TILE[key])[:3], np.float32)
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32) / N
    light = 1.0 + 0.10 * np.exp(-(((xx - 0.30) ** 2 + (yy - 0.22) ** 2) / 0.30)) - 0.07 * yy
    rng = np.random.default_rng(sum(map(ord, key)))
    g = rng.normal(0, 1, (N // 8, N // 8)).astype(np.float32)
    g = np.asarray(Image.fromarray(((g * 0.5 + 0.5).clip(0, 1) * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC),
                   np.float32) / 255.0
    img = base[None, None, :] * light[..., None] * (0.975 + 0.05 * g)[..., None]
    rgba = np.concatenate([np.clip(img, 0, 255), np.full((N, N, 1), 255, np.float32)], -1).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def frame(img, key):
    """Clip to the rounded tile, add the cream hairline ring and a thin dark outer edge (reads on light and dark)."""
    tm = tile_mask()
    out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    out.paste(img, (0, 0), tm)
    lay = Layer()
    lay.img = out
    ring = m_sub(m_rrect(RING_IN, RING_IN, 1 - RING_IN, 1 - RING_IN, TILE_R - RING_IN),
                 m_rrect(RING_IN + RING_W, RING_IN + RING_W, 1 - RING_IN - RING_W, 1 - RING_IN - RING_W,
                         TILE_R - RING_IN - RING_W))
    light_tile = key in ("wren", "kit", "you")
    lay.fill(ring, INK if light_tile else CREAM, 0.30 if light_tile else 0.42)
    edge = m_sub(tm, m_rrect(0.008, 0.008, 0.992, 0.992, TILE_R - 0.008))
    lay.fill(edge, "#0B0D0C", 0.55)
    return lay.img


# ---------------------------------------------------------------- the eleven emblems

def maya():
    """Cut paper: a clapperboard, slate open, each piece a slightly wobbly cut with a paper shadow."""
    L = Layer()
    body = m_poly(jitter([(0.22, 0.47), (0.78, 0.47), (0.78, 0.78), (0.22, 0.78)], 0.0025, 1))
    L.shadow(body)
    L.fill(body, CREAM)
    # lower fixed stripe band on the board
    band = m_poly(jitter([(0.22, 0.47), (0.78, 0.47), (0.78, 0.555), (0.22, 0.555)], 0.002, 2))
    stripes = blank()
    d = ImageDraw.Draw(stripes)
    for i in range(-2, 8):
        x = 0.22 + i * 0.11
        d.polygon([P(x, 0.555), P(x + 0.055, 0.555), P(x + 0.105, 0.47), P(x + 0.05, 0.47)], fill=255)
    L.fill(m_and(band, stripes), INK)
    # two written lines on the slate, as cut strips
    for y, x1 in ((0.62, 0.70), (0.69, 0.56)):
        L.fill(m_poly(jitter([(0.29, y), (x1, y), (x1, y + 0.03), (0.29, y + 0.03)], 0.0015, int(y * 100))), RUST)
    # the clapper arm, hinged at the left, raised
    arm = m_poly(jitter([(0.22, 0.36), (0.78, 0.36), (0.78, 0.445), (0.22, 0.445)], 0.0025, 3))
    st2 = blank()
    d = ImageDraw.Draw(st2)
    for i in range(-2, 8):
        x = 0.22 + i * 0.11
        d.polygon([P(x, 0.445), P(x + 0.055, 0.445), P(x + 0.105, 0.36), P(x + 0.05, 0.36)], fill=255)
    arm_r = m_rot(arm, 16, 0.235, 0.445)
    st_r = m_rot(st2, 16, 0.235, 0.445)
    L.shadow(arm_r, 0.008, 0.012)
    L.fill(arm_r, CREAM)
    L.fill(m_and(arm_r, st_r), INK)
    L.fill(m_ell(0.245, 0.452, 0.022), BRASS)        # hinge pin
    L.fill(m_ell(0.245, 0.452, 0.009), INK)
    return L


def jo():
    """Sticker: a festival ticket with notched sides, a perforation and a punched star."""
    L = Layer()
    t = m_rrect(0.18, 0.33, 0.82, 0.67, 0.045)
    t = m_sub(t, m_union(m_ell(0.18, 0.50, 0.055), m_ell(0.82, 0.50, 0.055)))
    t = m_rot(t, 12)
    L.sticker(t, 0.032)
    L.fill(t, BRASS)
    # perforation line and stub
    perf = blank()
    d = ImageDraw.Draw(perf)
    for i in range(7):
        y = 0.355 + i * 0.045
        d.ellipse([P(0.655 - 0.009, y - 0.009), P(0.655 + 0.009, y + 0.009)], fill=255)
    L.fill(m_rot(perf, 12), "#8C5E25")
    # star
    cx, cy, r1, r2 = 0.425, 0.50, 0.135, 0.058
    star = [(cx + (r1 if i % 2 == 0 else r2) * math.sin(i * math.pi / 5), cy - (r1 if i % 2 == 0 else r2) * math.cos(i * math.pi / 5))
            for i in range(10)]
    sm = m_rot(m_poly(star), 12)
    L.fill(sm, TILE["jo"])
    L.fill(m_rot(m_line([(0.745, 0.43), (0.745, 0.57)], 0.022), 12), "#8C5E25")
    return L


def riley():
    """Flat vector: a sheep's face, wool crown, dark face and ears."""
    L = Layer()
    wool = m_union(*[m_ell(0.5 + 0.20 * math.cos(a), 0.47 + 0.16 * math.sin(a), 0.105)
                     for a in np.linspace(0, 2 * math.pi, 9)[:-1]], m_ell(0.5, 0.47, 0.20, 0.17))
    L.shadow(wool, 0.0, 0.014, 0.014, 0.30)
    L.fill(wool, CREAM)
    ear_l = m_rot(m_ell(0.235, 0.50, 0.095, 0.040), -25, 0.235, 0.50)
    ear_r = m_rot(m_ell(0.765, 0.50, 0.095, 0.040), 25, 0.765, 0.50)
    L.fill(ear_l, INK2); L.fill(ear_r, INK2)
    face = m_ell(0.5, 0.585, 0.135, 0.185)
    L.fill(face, INK2)
    # fringe of wool over the brow
    fringe = m_union(m_ell(0.43, 0.43, 0.065), m_ell(0.5, 0.415, 0.07), m_ell(0.57, 0.43, 0.065))
    L.fill(fringe, CREAM)
    for x in (0.445, 0.555):
        L.fill(m_ell(x, 0.555, 0.034), CREAM)
        L.fill(m_ell(x + 0.006, 0.56, 0.018), INK)
    L.fill(m_ell(0.475, 0.685, 0.014, 0.010), "#4A4A42"); L.fill(m_ell(0.525, 0.685, 0.014, 0.010), "#4A4A42")
    return L


def tom():
    """Flat vector: a thundercloud with a big mustard bolt and a few rain dashes."""
    L = Layer()
    cloud = m_union(m_ell(0.36, 0.44, 0.115), m_ell(0.52, 0.37, 0.15), m_ell(0.67, 0.45, 0.11),
                    m_rrect(0.25, 0.42, 0.78, 0.55, 0.065))
    L.shadow(cloud, 0.0, 0.016, 0.012, 0.30)
    L.fill(cloud, CREAM)
    L.fill(m_and(cloud, m_rrect(0.2, 0.50, 0.8, 0.6, 0.0)), DIM, 0.8)   # darker belly
    bolt = m_poly([(0.52, 0.45), (0.37, 0.67), (0.485, 0.67), (0.42, 0.87), (0.65, 0.59), (0.535, 0.59), (0.625, 0.45)])
    L.fill(m_grow(bolt, 0.020), INK)
    L.fill(bolt, "#E7B84A")
    for x, y in ((0.31, 0.62), (0.70, 0.62), (0.66, 0.72)):
        L.fill(m_line([(x, y), (x - 0.025, y + 0.06)], 0.022), CREAM, 0.85)
    return L


def sam():
    """Line drawing: a windsock on a mast, bands in rust, the gusts drawn as clean strokes."""
    L = Layer()
    W = 0.030
    L.fill(m_line([(0.28, 0.24), (0.28, 0.80)], W), CREAM)
    L.fill(m_line([(0.20, 0.80), (0.36, 0.80)], W), CREAM)
    L.fill(m_ell(0.28, 0.24, 0.026), CREAM)
    # sock: a tapering cone from the mast, slightly drooping
    top0, bot0 = (0.30, 0.30), (0.30, 0.47)
    top1, bot1 = (0.80, 0.39), (0.80, 0.48)
    def lerp(a, b, f): return (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)
    for i in range(4):
        f0, f1 = i / 4, (i + 1) / 4
        seg = m_poly([lerp(top0, top1, f0), lerp(top0, top1, f1), lerp(bot0, bot1, f1), lerp(bot0, bot1, f0)])
        L.fill(seg, RUST if i % 2 == 0 else CREAM)
    out = m_sub(m_grow(m_poly([top0, top1, bot1, bot0]), W * 0.9), m_poly([top0, top1, bot1, bot0]))
    L.fill(out, INK)
    for i in range(1, 4):
        f = i / 4
        L.fill(m_line([lerp(top0, top1, f), lerp(bot0, bot1, f)], 0.010), INK)
    L.fill(m_line([(0.28, 0.30), (0.31, 0.30)], 0.02), INK)
    # gusts
    for y, x0, x1 in ((0.60, 0.42, 0.78), (0.69, 0.48, 0.72)):
        pts = [(x0 + (x1 - x0) * t, y + 0.018 * math.sin(t * math.pi * 2)) for t in np.linspace(0, 1, 24)]
        L.fill(m_line(pts, 0.024), CREAM)
    L.fill(m_line([(0.78, 0.60), (0.80, 0.585), (0.815, 0.565)], 0.024), CREAM)
    return L


def gear_pts(cx, cy, r_out, r_in, teeth, frac=0.45):
    pts = []
    for i in range(teeth):
        a0 = 2 * math.pi * i / teeth
        da = 2 * math.pi / teeth
        for a, r in ((a0, r_in), (a0 + da * 0.12, r_out), (a0 + da * frac, r_out), (a0 + da * (frac + 0.12), r_in)):
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def alex():
    """Embroidered badge: a round patch with a stitched edge, a gear and a spanner across it."""
    L = Layer()
    patch = m_ell(0.5, 0.5, 0.33)
    L.shadow(patch, 0.0, 0.014, 0.012, 0.35)
    L.fill(patch, INK2)
    stitch = blank()
    d = ImageDraw.Draw(stitch)
    for i in range(36):
        a0 = 2 * math.pi * i / 36
        a1 = a0 + 2 * math.pi / 36 * 0.55
        d.line([P(0.5 + 0.295 * math.cos(a0), 0.5 + 0.295 * math.sin(a0)),
                P(0.5 + 0.295 * math.cos(a1), 0.5 + 0.295 * math.sin(a1))], fill=255, width=int(0.014 * N))
    L.fill(stitch, BRASS, 0.9)
    gear = m_sub(m_poly(gear_pts(0.5, 0.5, 0.215, 0.165, 9)), m_ell(0.5, 0.5, 0.075))
    L.fill(gear, CREAM)
    # spanner: handle with an open jaw at one end, ring at the other
    sp = m_union(m_rrect(0.47, 0.25, 0.53, 0.75, 0.03), m_ell(0.5, 0.24, 0.07), m_ell(0.5, 0.76, 0.062))
    sp = m_sub(sp, m_union(m_rrect(0.477, 0.13, 0.523, 0.245, 0.0), m_ell(0.5, 0.76, 0.03)))
    sp = m_rot(sp, -45)
    L.fill(m_grow(sp, 0.018), INK2)
    L.fill(sp, BRASS)
    return L


def rennick():
    """Badge: a constable's peaked cap, front on, with a lit lamp where a crest would be. No real insignia."""
    L = Layer()
    L.fill(m_ell(0.5, 0.47, 0.30, 0.26).filter(ImageFilter.GaussianBlur(0.06 * N)), BRASS, 0.20)   # lamp glow
    crown = m_poly(jitter([(0.20, 0.36), (0.80, 0.36), (0.74, 0.56), (0.26, 0.56)], 0.0, 1))
    crown = m_union(crown, m_ell(0.5, 0.37, 0.30, 0.09))
    band = m_rrect(0.255, 0.52, 0.745, 0.63, 0.02)
    peak = m_union(m_poly([(0.24, 0.62), (0.76, 0.62), (0.70, 0.71), (0.30, 0.71)]), m_ell(0.5, 0.69, 0.20, 0.05))
    allm = m_union(crown, band, peak)
    L.shadow(allm, 0.0, 0.016, 0.012, 0.45)
    L.fill(m_grow(allm, 0.024), CREAM)
    L.fill(crown, "#4C618A")
    L.fill(m_and(crown, m_ell(0.42, 0.30, 0.22, 0.07)), "#6A7FA8", 0.8)      # crown highlight
    # band: a plain two-tone chequer, generic, cream and navy
    chq = blank()
    d = ImageDraw.Draw(chq)
    cw = 0.49 / 9
    for i in range(9):
        for j in range(2):
            if (i + j) % 2 == 0:
                d.rectangle([P(0.255 + i * cw, 0.52 + j * 0.055), P(0.255 + (i + 1) * cw, 0.52 + (j + 1) * 0.055)], fill=255)
    L.fill(band, "#1A2234")
    L.fill(m_and(band, chq), CREAM, 0.92)
    L.fill(peak, "#11161F")
    L.fill(m_and(peak, m_ell(0.5, 0.64, 0.22, 0.02)), "#39445C", 0.9)
    # the lamp: lantern on the cap front
    L.fill(m_ell(0.5, 0.42, 0.10).filter(ImageFilter.GaussianBlur(0.025 * N)), "#FFE6A8", 0.55)
    lamp_body = m_union(m_rrect(0.435, 0.335, 0.565, 0.50, 0.02), m_poly([(0.42, 0.338), (0.58, 0.338), (0.5, 0.285)]))
    L.fill(m_grow(lamp_body, 0.014), "#1A2234")
    L.fill(lamp_body, BRASS)
    L.fill(m_rrect(0.457, 0.36, 0.543, 0.478, 0.012), "#FFE6A8")
    L.fill(m_ell(0.5, 0.42, 0.022, 0.034), "#FFFFFF", 0.7)                    # the flame
    L.fill(m_ell(0.5, 0.272, 0.020), BRASS)
    return L


QMARK = [
    "....######....",
    "...########...",
    "..###....###..",
    "..##......##..",
    "..........##..",
    ".........###..",
    "........###...",
    "......####....",
    ".....###......",
    ".....##.......",
    ".....##.......",
    "..............",
    ".....##.......",
    ".....##.......",
]


def unknown():
    """Pixel: a coarse question mark with a warm backlit glow, plus a few stray pixels."""
    L = Layer()
    L.fill(m_ell(0.5, 0.48, 0.27).filter(ImageFilter.GaussianBlur(0.05 * N)), "#E0A05C", 0.35)
    px = 0.040
    ox = 0.5 - len(QMARK[0]) * px / 2 + px * 0.5
    oy = 0.5 - len(QMARK) * px / 2
    q = blank()
    d = ImageDraw.Draw(q)
    for j, row in enumerate(QMARK):
        for i, ch in enumerate(row):
            if ch == "#":
                d.rectangle([P(ox + i * px, oy + j * px), P(ox + (i + 1) * px - 0.0005, oy + (j + 1) * px - 0.0005)], fill=255)
    L.fill(m_shift(q, 0.010, 0.010), "#000000", 0.6)
    L.fill(q, CREAM)
    s = blank()
    d = ImageDraw.Draw(s)
    for i, j in ((11, 1), (12, 8), (1, 10), (10, 12)):
        d.rectangle([P(ox + i * px, oy + j * px), P(ox + (i + 1) * px, oy + (j + 1) * px)], fill=255)
    L.fill(s, BRASS, 0.55)
    return L


def you():
    """Sticker: a friendly quadcopter from above, rotor discs, two LED eyes."""
    L = Layer()
    arms = m_union(m_line([(0.30, 0.30), (0.70, 0.70)], 0.06), m_line([(0.70, 0.30), (0.30, 0.70)], 0.06))
    rotors = m_union(*[m_ell(x, y, 0.125) for x in (0.29, 0.71) for y in (0.29, 0.71)])
    body = m_rrect(0.385, 0.385, 0.615, 0.615, 0.07)
    allm = m_union(arms, rotors, body)
    L.sticker(allm, 0.026)
    for x in (0.29, 0.71):
        for y in (0.29, 0.71):
            L.fill(m_ell(x, y, 0.125), "#3E5A4A")
            L.fill(m_sub(m_ell(x, y, 0.125), m_ell(x, y, 0.105)), INK)
            blade = m_rot(m_rrect(x - 0.105, y - 0.017, x + 0.105, y + 0.017, 0.017), 25 if x < 0.5 else -25, x, y)
            L.fill(blade, CREAM, 0.85)
            L.fill(m_ell(x, y, 0.025), INK)
    L.fill(arms, INK)
    L.fill(body, "#1F3A2E")
    L.fill(m_rrect(0.405, 0.405, 0.595, 0.595, 0.055), "#2E5240")
    for x in (0.46, 0.54):
        L.fill(m_ell(x, 0.485, 0.024), "#FFE6A8")
    L.fill(m_line([(0.465, 0.545), (0.5, 0.565), (0.535, 0.545)], 0.014), "#FFE6A8")
    return L


def wren():
    """Hand-drawn doodle: a round little wren, tail cocked, red scarf, dotted trail on map paper."""
    L = Layer()
    # map hints on the paper: contour and a dotted trail
    cont = jitter([(0.10 + t * 0.8, 0.80 + 0.03 * math.sin(t * 7)) for t in np.linspace(0, 1, 12)], 0.002, 4, closed=False)
    L.fill(m_line(cont, 0.008), LAKE, 0.55)
    dots = blank()
    d = ImageDraw.Draw(dots)
    for t in np.linspace(0, 1, 9):
        x = 0.15 + t * 0.33
        y = 0.86 - t * 0.12 + 0.02 * math.sin(t * 5)
        d.ellipse([P(x - 0.011, y - 0.011), P(x + 0.011, y + 0.011)], fill=255)
    L.fill(dots, RUST, 0.85)
    body_pts = jitter(circle_pts(0.52, 0.53, 0.20, 40, 0.165), 0.004, 7)
    tail = jitter([(0.34, 0.50), (0.21, 0.27), (0.27, 0.24), (0.42, 0.44)], 0.003, 8)
    head = jitter(circle_pts(0.66, 0.40, 0.095, 32), 0.003, 9)
    beak = [(0.745, 0.375), (0.83, 0.395), (0.75, 0.415)]
    bm = m_union(m_poly(body_pts), m_poly(tail), m_poly(head), m_poly(beak))
    L.fill(m_grow(bm, 0.026), INK2)          # the doodle outline
    L.fill(m_poly(tail), "#7A4E33")
    L.fill(m_poly(body_pts), "#9A6440")
    L.fill(m_and(m_poly(body_pts), m_ell(0.56, 0.62, 0.16, 0.08)), "#D9B48A")   # pale breast
    L.fill(m_poly(head), "#9A6440")
    L.fill(m_poly(beak), BRASS_D)
    # wing bars and tail bars, drawn strokes
    for i in range(3):
        y = 0.48 + i * 0.045
        L.fill(m_line(jitter([(0.40, y), (0.50, y + 0.02)], 0.002, 20 + i, closed=False), 0.012), INK2)
    for i in range(2):
        L.fill(m_line([(0.255 + i * 0.04, 0.31 + i * 0.05), (0.30 + i * 0.04, 0.30 + i * 0.05)], 0.010), INK2)
    # eye stripe and eye
    L.fill(m_line([(0.62, 0.355), (0.71, 0.37)], 0.012), "#E9D9B4")
    L.fill(m_ell(0.685, 0.395, 0.020), INK)
    L.fill(m_ell(0.690, 0.389, 0.006), CREAM)
    # the red scarf, wrapped at the neck with a tail
    # a curved wrap that follows the neck, and one short tail blowing back over the shoulder
    wrap_top = [(0.575 + 0.13 * t, 0.445 + 0.045 * math.sin(t * math.pi * 0.9)) for t in np.linspace(0, 1, 10)]
    wrap_bot = [(0.575 + 0.13 * t, 0.50 + 0.04 * math.sin(t * math.pi * 0.9)) for t in np.linspace(1, 0, 10)]
    sc = m_poly(jitter(wrap_top + wrap_bot, 0.0015, 11))
    sct = m_poly(jitter([(0.59, 0.47), (0.60, 0.51), (0.47, 0.56), (0.45, 0.52)], 0.002, 12))
    L.fill(m_grow(m_union(sc, sct), 0.010), INK2)
    L.fill(sct, "#B8443A")
    L.fill(sc, RED)
    # legs
    for x in (0.50, 0.56):
        L.fill(m_line([(x, 0.69), (x - 0.01, 0.76), (x + 0.02, 0.765)], 0.012), INK2)
    return L


def kit():
    """Flat vector: a lifebuoy with four rust bands and a rope loop."""
    L = Layer()
    ring = m_sub(m_ell(0.5, 0.5, 0.29), m_ell(0.5, 0.5, 0.145))
    L.shadow(ring, 0.0, 0.016, 0.012, 0.32)
    L.fill(ring, CREAM)
    bands = blank()
    d = ImageDraw.Draw(bands)
    for k in range(4):
        a = math.radians(45 + 90 * k)
        da = math.radians(22)
        d.pieslice([P(0.19, 0.19), P(0.81, 0.81)], math.degrees(a - da), math.degrees(a + da), fill=255)
    L.fill(m_and(ring, bands), RUST)
    rope = m_sub(m_ell(0.5, 0.5, 0.228), m_ell(0.5, 0.5, 0.212))
    L.fill(m_sub(rope, bands), "#9A8A66")
    # rope grab loops between the bands
    for k in range(4):
        a = math.radians(90 * k)
        cx, cy = 0.5 + 0.30 * math.cos(a), 0.5 + 0.30 * math.sin(a)
        L.fill(m_sub(m_ell(cx, cy, 0.04), m_ell(cx, cy, 0.026)), INK2)
    L.fill(m_sub(m_ell(0.5, 0.5, 0.29), m_ell(0.5, 0.5, 0.276)), INK2, 0.6)
    L.fill(m_sub(m_ell(0.5, 0.5, 0.157), m_ell(0.5, 0.5, 0.145)), INK2, 0.6)
    return L


EMBLEM = {"maya": maya, "jo": jo, "riley": riley, "tom": tom, "sam": sam, "alex": alex, "rennick": rennick,
          "unknown": unknown, "you": you, "wren": wren, "kit": kit}


# ---------------------------------------------------------------- output

def render(key):
    """Returns (tile 2048 RGBA, emblem-only 2048 RGBA)."""
    em = EMBLEM[key]().img
    bg = tile_background(key)
    tile = frame(Image.alpha_composite(bg, em), key)
    return tile, em


def small(img, s):
    return img.resize((s, s), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=0.6, percent=55, threshold=1))


def note(key):
    for k, person, concept, style, _ in CAST:
        if k == key:
            return f"{person.split(',')[0]}: {concept}, {style} emblem"
    return ""


def manifest_rows():
    """Rows in appui_lib.MANIFEST form, so a full build_appui.py run keeps the avatar entries."""
    rows = []
    for key in TILE:
        rows.append((f"avatar_{key}.png", 512, 512, None, note(key)))
        rows.append((f"avatars/cutout/{key}.png", 512, 512, None, "emblem only, transparent"))
        for s in (96, 48):
            rows.append((f"sizes/{s}/avatar_{key}.png", s, s, None, ""))
    return rows


def update_manifest():
    """Rewrite the avatar rows of APPUI-MANIFEST.md in place; every other row is left exactly as it was."""
    p = os.path.join(UI, "APPUI-MANIFEST.md")
    lines = open(p, encoding="utf-8").read().splitlines()
    out = []
    for ln in lines:
        for key in TILE:
            if ln.startswith(f"| `avatar_{key}.png` |"):
                ln = f"| `avatar_{key}.png` | 512 x 512 | - | {note(key)} |"
            elif ln.startswith(f"| `avatars/cutout/{key}.png` |"):
                ln = f"| `avatars/cutout/{key}.png` | 512 x 512 | - | emblem only, transparent |"
        out.append(ln)
    open(p, "w", encoding="utf-8").write("\n".join(out) + "\n")


def build(sheet=False):
    masters = {}
    for key in TILE:
        tile, em = render(key)
        masters[key] = tile
        tile.resize((512, 512), Image.LANCZOS).save(os.path.join(UI, f"avatar_{key}.png"), optimize=True)
        for s in (96, 48):
            os.makedirs(os.path.join(UI, "sizes", str(s)), exist_ok=True)
            small(tile, s).save(os.path.join(UI, "sizes", str(s), f"avatar_{key}.png"), optimize=True)
        os.makedirs(os.path.join(UI, "avatars", "cutout"), exist_ok=True)
        em.resize((512, 512), Image.LANCZOS).save(os.path.join(UI, "avatars", "cutout", f"{key}.png"), optimize=True)
        print("avatar", key)
    update_manifest()
    if sheet:
        import avatars_sheet
        avatars_sheet.build(masters, CAST, TILE)
    return masters


if __name__ == "__main__":
    build(sheet="--sheet" in sys.argv)

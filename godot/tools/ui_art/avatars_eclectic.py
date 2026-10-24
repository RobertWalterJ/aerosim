"""The eclectic avatar set (lane avatars, round 2): each account looks like a picture the person uploaded themselves.

No shared tile, border or palette. Sources are mixed on purpose: real CC0 photographs (Sam, You, Wren, Tom's composite),
cartoons (Maya's cat, Riley's dog), a logo and a badge (Kit's mascot, Rennick's constabulary emblem), a stock-style vector
(Jo), a product shot (Alex) and a glitched default (Unknown). Photos come from avatar_sources/ (avatar_photo_prep.py).
Every function returns a 2048 x 2048 RGBA master; build_avatars.py downsamples and writes the files.
"""
import math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance, ImageChops
import build_avatars as B
from build_avatars import N, P, blank, m_poly, m_ell, m_rrect, m_line, m_union, m_sub, m_and, m_rot, m_shift, m_grow, Layer, hx

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "avatar_sources")
UI = B.UI
TEX = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "textures"))

# key: (what it is, kind of image, source line, licence, one-line rationale)
CAST = {
    "maya": ("a cartoon of her ginger cat", "cartoon", "drawn in code (own work)", "original",
             "An editor who lives online posts her cat, drawn as a cheeky cartoon on a sunny yellow."),
    "jo": ("festival bunting and string lights at dusk", "stock-style vector", "drawn in code (own work)", "original",
           "Jo books the festival: her picture is the bunting and lights she spends every summer hanging."),
    "riley": ("a cartoon of her sheepdog", "cartoon", "drawn in code (own work)", "original",
              "The ranger protecting the flock picks her working dog, a black-and-white collie, not herself."),
    "tom": ("a tornado over the Kansas plains", "photo",
            "NOAA Photo Library nssl0232 'Tornado over the Kansas plains' (Wikimedia Commons; full URL in APPUI-README),"
            " Sean Waugh, NOAA/NSSL, 23 May 2008",
            "public domain (NOAA employee work)",
            "Tom chases storms, so his picture is the one he is proudest of: a tornado roping down over a wheat field."),
    "sam": ("fair-weather cumulus in a blue sky", "photo",
            "Poly Haven kloofendal_48d_partly_cloudy_puresky, https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky,"
            " Greg Zaal", "CC0", "A precise meteorologist posts a textbook cumulus sky, the kind he reads windows from."),
    "alex": ("his own race drone on the workbench", "product shot",
             "Raptor render from lane appui2 (items/cutout/raptor.png, own work) on Poly Haven wood_planks_grey"
             " (https://polyhaven.com/a/wood_planks_grey, Rob Tuytel)", "own work + CC0",
             "The tech reviewer's picture is gear: his Raptor quad shot like a review thumbnail on the bench."),
    "rennick": ("Halloway Provincial Constabulary emblem", "logo / badge", "drawn in code (own work); fictional service,"
                " no real crest, motto or text", "original",
                "The constable uses the service emblem: shield, crown, laurel and a lamp, blue and gold, fictional."),
    "unknown": ("a glitched default silhouette", "pixel / glitch", "drawn in code (own work)", "original",
                "Never set a picture: the grey default placeholder, corrupted with pixel glitches."),
    "you": ("a sunrise over a misty field", "photo",
            "Poly Haven HDRI bundled with Blender 4.2.3 (studiolights/world/sunrise.exr), Greg Zaal", "CC0",
            "The pilot's own dawn shot: low sun through mist over a field, the light every drone flyer waits for."),
    "wren": ("a gravel trail through the woods", "photo",
             "Poly Haven HDRI bundled with Blender 4.2.3 (studiolights/world/forest.exr), Greg Zaal", "CC0",
             "A hiker's own trail photo: a gravel path curving off into green woods, the kind of walk Wren set out on."),
    "kit": ("DroneBudz support mascot", "logo / mascot", "drawn in code (own work)", "original",
            "The support desk uses the app's mascot: a friendly little prop-bot wearing a headset."),
}


def photo(name, size=N):
    return Image.open(os.path.join(SRC, name + ".jpg")).convert("RGB").resize((size, size), Image.LANCZOS)


def solid(col):
    return Image.new("RGBA", (N, N), hx(col))


def over(base, layer):
    return Image.alpha_composite(base, layer.img)


# ------------------------------------------------------------------ cartoons

def maya():
    bg = solid("#F5C542")
    L = Layer()
    INK = "#2B1B12"
    ears = [m_poly([(0.22, 0.40), (0.25, 0.12), (0.45, 0.28)]), m_poly([(0.78, 0.40), (0.75, 0.12), (0.55, 0.28)])]
    head = m_ell(0.5, 0.56, 0.33, 0.29)
    body = m_union(head, *ears)
    L.fill(m_grow(body, 0.026), INK)
    L.fill(body, "#E8893A")
    for e, (x0, x1) in zip(ears, ((0.25, 0.37), (0.75, 0.63))):
        L.fill(m_poly([(x0 + (0.0 if x0 < 0.5 else 0.0), 0.19), ((x0 + x1) / 2 + (-0.02 if x0 < 0.5 else 0.02), 0.31),
                       (x0 + (0.03 if x0 < 0.5 else -0.03), 0.36)]), "#F4A6A0")
    for dx in (-0.07, 0.0, 0.07):                                   # tabby stripes
        L.fill(m_line([(0.5 + dx, 0.30), (0.5 + dx * 0.8, 0.40)], 0.028), "#B85D1E")
    L.fill(m_line([(0.19, 0.55), (0.27, 0.56)], 0.022), "#B85D1E")
    L.fill(m_line([(0.81, 0.55), (0.73, 0.56)], 0.022), "#B85D1E")
    muzzle = m_union(m_ell(0.445, 0.66, 0.085, 0.07), m_ell(0.555, 0.66, 0.085, 0.07))
    L.fill(muzzle, "#FFF4E2")
    for x in (0.39, 0.61):                                          # eyes, half-lidded and smug
        L.fill(m_ell(x, 0.52, 0.062, 0.058), "#FFFFFF")
        L.fill(m_ell(x, 0.53, 0.050, 0.050), "#7DBA3F")
        L.fill(m_ell(x, 0.53, 0.014, 0.042), INK)
        L.fill(m_ell(x + 0.016, 0.51, 0.010), "#FFFFFF")
        L.fill(m_rrect(x - 0.07, 0.455, x + 0.07, 0.50, 0.0), "#E8893A")      # lid
        L.fill(m_line([(x - 0.065, 0.50), (x + 0.065, 0.50)], 0.014), INK)
    L.fill(m_poly([(0.47, 0.61), (0.53, 0.61), (0.5, 0.645)]), "#E86F7F")
    L.fill(m_line([(0.5, 0.645), (0.5, 0.67), (0.47, 0.69)], 0.012), INK)
    L.fill(m_line([(0.5, 0.67), (0.53, 0.69)], 0.012), INK)
    for y, s in ((0.64, 1), (0.68, 1)):
        L.fill(m_line([(0.36, y), (0.16, y - 0.03 * s)], 0.008), INK)
        L.fill(m_line([(0.64, y), (0.84, y - 0.03 * s)], 0.008), INK)
    return over(bg, L)


def riley():
    bg = solid("#E76F51")
    L = Layer()
    INK = "#1B1B1F"
    BLACK = "#24242A"
    WHITE = "#FAF7F0"
    L.fill(m_ell(0.5, 0.56, 0.30, 0.26).filter(ImageFilter.GaussianBlur(0.05 * N)), "#B5442A", 0.5)
    ear_l = m_rot(m_ell(0.26, 0.30, 0.075, 0.14), 28, 0.26, 0.30)
    ear_r = m_rot(m_ell(0.74, 0.30, 0.075, 0.14), -28, 0.74, 0.30)
    head = m_ell(0.5, 0.50, 0.27, 0.25)
    muzzle = m_ell(0.5, 0.66, 0.15, 0.12)
    allm = m_union(ear_l, ear_r, head, muzzle)
    L.fill(m_grow(allm, 0.024), INK)
    L.fill(m_union(ear_l, ear_r, head), BLACK)
    blaze = m_union(m_poly([(0.46, 0.27), (0.54, 0.27), (0.60, 0.56), (0.40, 0.56)]), muzzle)
    L.fill(blaze, WHITE)
    L.fill(m_and(m_ell(0.5, 0.80, 0.20, 0.08), m_rrect(0, 0.74, 1, 1, 0)), WHITE)
    L.fill(m_rot(m_ell(0.27, 0.32, 0.035, 0.08), 28, 0.27, 0.32), "#6B4A4A")
    L.fill(m_rot(m_ell(0.73, 0.32, 0.035, 0.08), -28, 0.73, 0.32), "#6B4A4A")
    for x in (0.39, 0.61):
        L.fill(m_ell(x, 0.47, 0.048), "#C98A3A")                     # tan eyebrow spots
        L.fill(m_ell(x, 0.51, 0.045), "#FFFFFF")
        L.fill(m_ell(x + 0.006, 0.515, 0.032), "#3A2414")
        L.fill(m_ell(x + 0.016, 0.502, 0.010), "#FFFFFF")
    L.fill(m_ell(0.5, 0.615, 0.052, 0.038), INK)                      # nose
    L.fill(m_ell(0.488, 0.605, 0.014, 0.009), "#FFFFFF", 0.7)
    L.fill(m_line([(0.5, 0.65), (0.5, 0.68)], 0.012), INK)
    mouth = m_sub(m_ell(0.5, 0.69, 0.07, 0.055), m_rrect(0.3, 0.6, 0.7, 0.69, 0))
    L.fill(mouth, "#7A1F2B")
    L.fill(m_and(m_ell(0.5, 0.74, 0.04, 0.04), mouth), "#F07C8A")   # tongue
    return over(bg, L)


# ------------------------------------------------------------------ stock-style vector

def jo():
    yy = np.linspace(0, 1, N, dtype=np.float32)[:, None]
    top, bot = np.array(hx("#1E1B4B")[:3], np.float32), np.array(hx("#E0577A")[:3], np.float32)
    mid = np.array(hx("#7B3F8C")[:3], np.float32)
    g = np.where(yy < 0.55, top + (mid - top) * (yy / 0.55), mid + (bot - mid) * ((yy - 0.55) / 0.45))
    img = np.repeat(g[:, None, :], N, 1)
    bg = Image.fromarray(np.concatenate([img, np.full((N, N, 1), 255, np.float32)], -1).astype(np.uint8), "RGBA")
    L = Layer()
    rng = np.random.default_rng(5)
    for _ in range(26):                                              # warm bokeh
        x, y, r = rng.random(), 0.15 + rng.random() * 0.75, 0.02 + rng.random() * 0.05
        L.fill(m_ell(x, y, r).filter(ImageFilter.GaussianBlur(r * N * 0.25)), "#FFD27A", 0.25 + rng.random() * 0.35)
    L.fill(m_poly([(0.0, 1.0), (0.0, 0.86), (0.18, 0.80), (0.42, 0.84), (0.62, 0.78), (0.85, 0.83), (1.0, 0.79), (1.0, 1.0)]),
           "#16132F")                                               # hill line
    L.fill(m_poly([(0.58, 0.82), (0.72, 0.66), (0.86, 0.82)]), "#16132F")   # marquee tent
    cols = ["#F2C14E", "#E8505B", "#3FB8AF", "#F7F3E8", "#8EC63F", "#F28C38"]
    for sw, (y0, sag, n, size) in enumerate(((0.14, 0.16, 7, 0.085), (0.36, 0.14, 6, 0.10))):
        pts = [(t, y0 + sag * 4 * t * (1 - t)) for t in np.linspace(-0.05, 1.05, 40)]
        L.fill(m_line(pts, 0.008), "#2A2440")
        for k in range(n):
            t = (k + 0.5) / n
            x, y = -0.05 + 1.1 * t, y0 + sag * 4 * t * (1 - t)
            a = math.atan(sag * 4 * (1 - 2 * t) / 1.1)
            w = size * 0.55
            tri = [(x - w * math.cos(a), y - w * math.sin(a)), (x + w * math.cos(a), y + w * math.sin(a)),
                   (x + size * 1.2 * math.sin(a) * -1 + 0.0, y + size * 1.2 * math.cos(a))]
            m = m_poly(tri)
            L.shadow(m, 0.004, 0.010, 0.006, 0.35)
            L.fill(m, cols[(k + sw * 2) % len(cols)])
            L.fill(m_and(m, m_shift(m_poly(tri), -0.012, 0)), "#FFFFFF", 0.12)
    for k in range(9):                                               # string lights
        t = (k + 0.3) / 9
        x, y = 0.05 + 0.9 * t, 0.58 + 0.08 * 4 * t * (1 - t)
        L.fill(m_ell(x, y, 0.03).filter(ImageFilter.GaussianBlur(0.012 * N)), "#FFE08A", 0.9)
        L.fill(m_ell(x, y, 0.010), "#FFF6D6")
    return over(bg, L)


# ------------------------------------------------------------------ logos and badges

def rennick():
    """Fictional Halloway Provincial Constabulary emblem: crown over a shield with a lamp, laurel, blank ribbon. Blue and gold."""
    bg = solid("#FBFAF6")
    L = Layer()
    NAVY, NAVY2, GOLD, GOLD_D, GOLD_L = "#16306A", "#22448C", "#D4A532", "#9C7419", "#F2D27A"
    # laurel: leaves along two arcs either side
    for side in (-1, 1):
        for k in range(9):
            t = k / 8.0
            x =0.5 + side * (0.30 + 0.06 * math.sin(math.pi * t))
            y = 0.80 - 0.52 * t
            leaf = m_rot(m_ell(x, y, 0.028, 0.062), side * (25 + 40 * t), x, y)
            L.fill(m_grow(leaf, 0.006), GOLD_D)
            L.fill(leaf, GOLD)
        L.fill(m_line([(0.5 + side * (0.30 + 0.06 * math.sin(math.pi * t)), 0.80 - 0.52 * t)
                       for t in np.linspace(0, 1, 20)], 0.010), GOLD_D)
    # shield
    sh = [(0.29, 0.30), (0.71, 0.30), (0.71, 0.55)] + \
         [(0.5 + 0.21 * math.cos(a), 0.55 + 0.27 * math.sin(a)) for a in np.linspace(0, math.pi, 30)] + [(0.29, 0.55)]
    shield = m_poly(sh)
    def scaled(f):
        return m_poly([(0.5 + (x - 0.5) * f, 0.53 + (y - 0.53) * f) for x, y in sh])
    L.shadow(scaled(1.11), 0.0, 0.012, 0.010, 0.25)
    L.fill(scaled(1.11), GOLD_D)                                     # crisp rims, not blurred growth
    L.fill(scaled(1.085), GOLD)
    L.fill(shield, NAVY)
    L.fill(m_sub(m_poly([(x + (0.5 - x) * 0.07, y + (0.55 - y) * 0.06) for x, y in sh]),
                 m_poly([(x + (0.5 - x) * 0.10, y + (0.55 - y) * 0.085) for x, y in sh])), GOLD, 0.9)
    L.fill(m_and(shield, m_ell(0.40, 0.36, 0.20, 0.12)), NAVY2, 0.6)
    # the device: a lit lamp with rays
    for k in range(8):
        a = math.radians(-90 + (k - 3.5) * 22)
        L.fill(m_line([(0.5 + 0.11 * math.cos(a), 0.53 + 0.11 * math.sin(a)),
                       (0.5 + 0.17 * math.cos(a), 0.53 + 0.17 * math.sin(a))], 0.016), GOLD_L)
    lamp = m_union(m_rrect(0.455, 0.47, 0.545, 0.63, 0.016), m_poly([(0.44, 0.475), (0.56, 0.475), (0.5, 0.425)]),
                   m_rrect(0.445, 0.625, 0.555, 0.655, 0.01), m_ell(0.5, 0.418, 0.017))
    L.fill(m_grow(lamp, 0.010), NAVY)
    L.fill(lamp, GOLD)
    L.fill(m_rrect(0.472, 0.49, 0.528, 0.61, 0.010), "#FFF1C2")
    L.fill(m_ell(0.5, 0.55, 0.014, 0.026), "#FFFFFF")
    # crown
    crown = m_union(m_rrect(0.39, 0.215, 0.61, 0.27, 0.01),
                    m_poly([(0.39, 0.23), (0.40, 0.12), (0.45, 0.19), (0.5, 0.10), (0.55, 0.19), (0.60, 0.12), (0.61, 0.23)]))
    L.fill(m_grow(crown, 0.010), GOLD_D)
    L.fill(crown, GOLD)
    for x, y in ((0.40, 0.115), (0.5, 0.095), (0.60, 0.115)):
        L.fill(m_ell(x, y, 0.016), GOLD_L)
    for x in (0.43, 0.5, 0.57):
        L.fill(m_ell(x, 0.243, 0.011), "#B8323A")
    # ribbon scroll, blank, with folded ends
    rib = m_poly([(0.22, 0.80), (0.5, 0.835), (0.78, 0.80), (0.78, 0.87), (0.5, 0.905), (0.22, 0.87)])
    for side in (-1, 1):
        x0 = 0.5 + side * 0.28
        tail = m_poly([(x0, 0.815), (x0 + side * 0.09, 0.83), (x0 + side * 0.06, 0.865), (x0 + side * 0.09, 0.90), (x0, 0.885)])
        L.fill(m_grow(tail, 0.008), GOLD_D)
        L.fill(tail, NAVY2)
    L.fill(m_grow(rib, 0.010), GOLD_D)
    L.fill(rib, NAVY)
    L.fill(m_line([(0.26, 0.852), (0.5, 0.886), (0.74, 0.852)], 0.008), GOLD, 0.8)
    return over(bg, L)


def kit():
    bg = solid("#13A89E")
    L = Layer()
    INK = "#0B3B3A"
    L.fill(m_sub(m_ell(0.5, 0.52, 0.44), m_ell(0.5, 0.52, 0.415)), "#FFFFFF", 0.35)     # logo ring
    # propeller on top
    L.fill(m_line([(0.5, 0.25), (0.5, 0.18)], 0.026), "#FFFFFF")
    L.fill(m_ell(0.5, 0.165, 0.18, 0.03), "#FFFFFF")
    L.fill(m_ell(0.5, 0.165, 0.025), INK)
    head = m_rrect(0.25, 0.26, 0.75, 0.70, 0.17)
    L.shadow(head, 0, 0.016, 0.012, 0.25)
    L.fill(head, "#FFFFFF")
    L.fill(m_rrect(0.31, 0.34, 0.69, 0.60, 0.11), "#0E2E2D")                            # visor
    for x in (0.42, 0.58):
        L.fill(m_rrect(x - 0.035, 0.40, x + 0.035, 0.49, 0.035), "#7FF5DF")
    L.fill(m_sub(m_ell(0.5, 0.51, 0.06, 0.045), m_rrect(0.4, 0.45, 0.6, 0.51, 0)), "#7FF5DF")
    # headset: band, ear cups, boom mic
    band = m_sub(m_ell(0.5, 0.48, 0.30, 0.28), m_ell(0.5, 0.48, 0.265, 0.245))
    L.fill(m_and(band, m_rrect(0, 0, 1, 0.47, 0)), INK)
    for x in (0.215, 0.785):
        L.fill(m_rrect(x - 0.05, 0.40, x + 0.05, 0.56, 0.04), INK)
    L.fill(m_line([(0.235, 0.54), (0.27, 0.66), (0.40, 0.68)], 0.022), INK)
    L.fill(m_ell(0.415, 0.68, 0.03), "#F2C14E")
    # little body and arm waving
    L.fill(m_rrect(0.37, 0.70, 0.63, 0.86, 0.06), "#FFFFFF")
    L.fill(m_line([(0.63, 0.75), (0.74, 0.70), (0.78, 0.62)], 0.04), "#FFFFFF")
    L.fill(m_ell(0.5, 0.78, 0.03), "#F2C14E")
    return over(bg, L)


# ------------------------------------------------------------------ pixel / glitch

def unknown():
    S = 48
    small = Image.new("RGB", (S, S), (154, 160, 166))
    d = ImageDraw.Draw(small)
    d.ellipse([16, 9, 32, 27], fill=(214, 217, 221))
    d.ellipse([7, 30, 41, 62], fill=(214, 217, 221))
    big = small.resize((N, N), Image.NEAREST)
    a = np.asarray(big).astype(np.int16)
    rng = np.random.default_rng(11)
    out = a.copy()
    for _ in range(7):                                                # sliced row shifts, small enough to keep the shape
        y0 = int(rng.integers(0, N - 120)); h = int(rng.integers(30, 120)); sh = int(rng.integers(-80, 80))
        out[y0:y0 + h] = np.roll(a[y0:y0 + h], sh, axis=1)
    out[..., 0] = np.roll(out[..., 0], 26, axis=1)                    # channel split
    out[..., 2] = np.roll(out[..., 2], -26, axis=1)
    px = N // S
    for _ in range(40):                                               # dead pixels
        i, j = int(rng.integers(0, S)), int(rng.integers(0, S))
        c = [(225, 60, 90), (60, 220, 230), (240, 240, 240), (30, 30, 34)][int(rng.integers(0, 4))]
        out[j * px:(j + 1) * px, i * px:(i + 1) * px] = c
    for y in range(0, N, 8):                                          # scanlines
        out[y:y + 2] = (out[y:y + 2] * 0.86).astype(np.int16)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


# ------------------------------------------------------------------ photographs

def _grade(img, contrast=1.0, sat=1.0, bright=1.0, sharp=True):
    img = ImageEnhance.Contrast(img).enhance(contrast)
    img = ImageEnhance.Color(img).enhance(sat)
    img = ImageEnhance.Brightness(img).enhance(bright)
    if sharp:
        img = img.filter(ImageFilter.UnsharpMask(radius=6, percent=60, threshold=2))
    return img


def sam():
    return _grade(photo("cumulus"), 1.08, 1.05).convert("RGBA")


def you():
    return _grade(photo("sunrise_field"), 1.12, 1.15).convert("RGBA")


def wren():
    return _grade(photo("woodland_trail"), 1.12, 1.12).convert("RGBA")


def tom():
    """The real NOAA tornado photo when present (avatar_sources/tom_photo.jpg), else the lightning composite."""
    if os.path.exists(os.path.join(SRC, "tom_photo.jpg")):
        return _grade(photo("tom_photo"), 1.32, 1.08, 0.94).convert("RGBA")
    return tom_lightning()


def tom_lightning():
    """Round-2 composite: CC0 cloud regraded as a storm, CC0 field, painted lightning. Kept as an alternate."""
    sky =np.asarray(photo("storm_cloud"), np.float32) / 255
    lum = (sky * [0.3, 0.59, 0.11]).sum(-1)
    t = np.clip((lum - 0.45) / 0.55, 0, 1) ** 1.6                     # cloud light -> storm palette
    dark, light = np.array([0.12, 0.14, 0.15]), np.array([0.74, 0.79, 0.77])
    storm = dark + (light - dark) * t[..., None]
    yy = np.linspace(0, 1, N)[:, None, None]
    storm *= (1.05 - 0.35 * yy)                                       # heavier toward the horizon
    ground = np.asarray(photo("storm_ground"), np.float32) / 255
    g_lum = (ground * [0.3, 0.59, 0.11]).sum(-1, keepdims=True)
    ground = (ground * 0.35 + g_lum * 0.65) * np.array([0.42, 0.48, 0.40])
    hz = 0.74
    mix = np.clip((yy - hz) / 0.02, 0, 1)
    gy = np.clip(((yy - hz) / (1 - hz)) * 0.5 + 0.5, 0, 1)              # take the lower half of the field photo
    rows = (gy[:, 0, 0] * (N - 1)).astype(int)
    ground_s = ground[rows]
    img = storm * (1 - mix) + ground_s * mix
    base = Image.fromarray(np.clip(img * 255, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    # the strike: jagged random walk from the cloud base to the ground, with a branch
    rng = np.random.default_rng(7)
    def walk(x, y, y1, step=0.035):
        pts = [(x, y)]
        while y < y1:
            y += step * (0.6 + 0.8 * rng.random()); x += (rng.random() - 0.5) * 0.07
            pts.append((x, min(y, y1)))
        return pts
    main = walk(0.56, 0.24, hz + 0.01, 0.02)
    br = walk(main[8][0], main[8][1], 0.56, 0.018)
    br = [(main[8][0] + (x - main[8][0]) * 1.0 - (y - main[8][1]) * 0.7, y) for x, y in br]
    br2 = walk(main[15][0], main[15][1], 0.66, 0.018)
    br2 = [(main[15][0] + (x - main[15][0]) + (y - main[15][1]) * 0.8, y) for x, y in br2]
    L = Layer()
    bolt = m_union(m_line(main, 0.013), m_line(br, 0.006), m_line(br2, 0.005))
    L.fill(m_grow(bolt, 0.14).filter(ImageFilter.GaussianBlur(0.06 * N)), "#9EB7FF", 0.55)
    L.fill(m_grow(bolt, 0.03).filter(ImageFilter.GaussianBlur(0.012 * N)), "#CFE0FF", 0.95)
    L.fill(bolt, "#FFFFFF")
    L.fill(m_ell(main[-1][0], hz + 0.01, 0.12, 0.03).filter(ImageFilter.GaussianBlur(0.02 * N)), "#CFE0FF", 0.55)
    img = over(base, L).convert("RGB")
    img = img.filter(ImageFilter.UnsharpMask(radius=5, percent=40, threshold=2))
    a = np.asarray(img, np.float32)
    a += np.random.default_rng(2).normal(0, 3.0, a.shape[:2])[..., None]          # a little sensor noise
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def alex():
    wood = Image.open(os.path.join(TEX, "barnwood_diff.jpg")).convert("RGB")
    wood = wood.rotate(90, expand=True).resize((N, N), Image.LANCZOS).filter(ImageFilter.GaussianBlur(10))
    w = np.asarray(wood, np.float32)
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32) / N
    light = 0.55 + 0.75 * np.exp(-(((xx - 0.45) ** 2) / 0.18 + ((yy - 0.35) ** 2) / 0.12))
    w = w * light[..., None] * np.array([1.12, 1.0, 0.86])           # warm lamp on the bench
    bg = Image.fromarray(np.clip(w, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    drone = Image.open(os.path.join(UI, "items", "cutout", "raptor.png")).convert("RGBA")
    S = int(N * 1.22)
    drone = drone.resize((S, S), Image.LANCZOS)
    L = Layer()
    L.fill(m_ell(0.5, 0.70, 0.46, 0.13).filter(ImageFilter.GaussianBlur(0.04 * N)), "#000000", 0.6)
    out = over(bg, L)
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    layer.paste(drone, (-(S - N) // 2, -(S - N) // 2 + int(N * 0.02)), drone)
    out.alpha_composite(layer)
    return ImageEnhance.Brightness(out).enhance(1.12)


EMBLEM = {"maya": maya, "jo": jo, "riley": riley, "tom": tom, "sam": sam, "alex": alex, "rennick": rennick,
          "unknown": unknown, "you": you, "wren": wren, "kit": kit}

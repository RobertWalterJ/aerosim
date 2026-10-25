"""Generate the missing kit assets for the AeroSim-notify lane:
   - icons/icon_map.png (+ 128/64/44, layers bg/fg, mono) in the same style as the kit
   - glyphs/64|128/*.png Material-style navigation and quick-setting glyphs
Reuses the sibling kit generator's drawing library without touching the sibling checkout.
"""
import os, sys, math
from PIL import Image, ImageDraw

SIB = r"C:\Users\Robert Walter-Joseph\Documents\RWJ Coding Projects\AeroSim\godot\tools\ui_art"
OUT = os.path.dirname(os.path.abspath(__file__))    # this folder
sys.path.insert(0, SIB)

import gen_icons
from lib import hx, vgrad, Gradient
import numpy as np

CREAM_HI = hx("#FDF8E6")
CREAM_LO = hx("#E2D8B8")
BRASS_HI = hx("#F6D590")
BRASS = hx("#E0AB59")
BRASS_LO = hx("#C58A3A")
DARK = hx("#241C0C")


def fg_map(c):
    """A folded survey map with a route and a brass pin, centred in the adaptive safe zone."""
    # three folded paper panels (slight fan)
    p1 = c.poly([(-46, -24), (-16, -32), (-16, 34), (-46, 28)], 2.0)
    p2 = c.poly([(-16, -32), (14, -26), (14, 40), (-16, 34)], 2.0)
    p3 = c.poly([(14, -26), (46, -32), (46, 28), (14, 40)], 2.0)
    c.fill(p1, vgrad(hx("#F8F1DA"), hx("#DCD0AE"), -32, 34))
    c.fill(p3, vgrad(hx("#F1E8CE"), hx("#D2C6A2"), -32, 40))
    c.fill(p2, vgrad(hx("#FBF5E0"), hx("#E2D6B4"), -32, 40))
    # fold creases
    c.fill(c.line([(-16, -32), (-16, 34)], 1.3), hx("#8E8468"), 0.55)
    c.fill(c.line([(14, -26), (14, 40)], 1.3), hx("#8E8468"), 0.55)
    # contour rings on the paper
    for cx, cy, rr in ((-32, -8, 14), (-32, -8, 8), (30, 12, 12), (30, 12, 6)):
        c.fill(c.arc(cx, cy, rr, 20, 320, 1.1), hx("#B3A783"), 0.55)
    # roads
    c.fill(c.line([(-42, 20), (-26, 8), (-8, 12), (8, -4), (30, 0), (42, -14)], 2.2), hx("#9A8E6E"), 0.85)
    c.fill(c.line([(-40, -18), (-24, -8), (-10, -12), (4, -20), (22, -16)], 1.6), hx("#9A8E6E"), 0.55)
    # brass route with rounded caps over the roads
    c.fill(c.line([(-38, 26), (-22, 12), (0, 18), (20, 4), (38, 10)], 3.0), Gradient([(0, BRASS_HI), (1, BRASS_LO)], p0=(-38, 0), p1=(38, 0)))
    # start dot
    c.fill(c.circle(-38, 26, 2.6), DARK)
    # the pin: a brass disc with a dark centre and a short drop shadow
    c.fill(c.circle(21, -8, 10.5), hx("#1A1F1B"), 0.35)
    c.fill(c.circle(20, -10, 9.0), Gradient([(0, BRASS_HI), (0.6, BRASS), (1, BRASS_LO)], p0=(14, -18), p1=(26, -2)))
    c.fill(c.circle(20, -10, 3.4), hx("#233024"))
    c.fill(c.circle(17, -13, 2.2), CREAM_HI, 0.30)


def render_icon_set(name, top, bot, art):
    for S in (512, 128, 64, 44):
        c, bgc, fgc = gen_icons.make_icon(name, top, bot, art, S)
        img = c.render()
        sub = "" if S == 512 else "%d/" % S
        path = os.path.join(OUT, "icons", sub if sub else "")
        os.makedirs(path, exist_ok=True)
        img.save(os.path.join(path, name + ".png"), optimize=True)
        if S == 512:
            bgc.render().save(os.path.join(OUT, "icons", "layers", name + "_bg.png"), optimize=True)
            fgc.render().save(os.path.join(OUT, "icons", "layers", name + "_fg.png"), optimize=True)
        m = gen_icons.mono_icon(art, S)
        mpath = os.path.join(OUT, "icons", "mono", sub if sub else "")
        os.makedirs(mpath, exist_ok=True)
        m.render().save(os.path.join(mpath, name + "_mono.png"), optimize=True)
    print("icon set:", name)


# ---------------------------------------------------------------- glyphs
CREAM = (239, 232, 208, 255)
SHADE = (214, 206, 180, 255)


def _grad_cream(img):
    """Vertical cream gradient over the drawn alpha."""
    a = img.getchannel("A")
    w, h = img.size
    grad = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = grad.load()
    for y in range(h):
        t = y / max(1, h - 1)
        r = int(CREAM[0] + (SHADE[0] - CREAM[0]) * t)
        g = int(CREAM[1] + (SHADE[1] - CREAM[1]) * t)
        b = int(CREAM[2] + (SHADE[2] - CREAM[2]) * t)
        for x in range(w):
            px[x, y] = (r, g, b, 255)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(grad, (0, 0), a)
    return out


def make_glyph(name, draw_fn, out_size=64):
    ss = 8
    S = out_size * ss
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_fn(d, S)
    img = img.resize((out_size, out_size), Image.LANCZOS)
    return img


def rounded_line(d, pts, width, fill=CREAM, caps=True):
    d.line(pts, fill=fill, width=width, joint="curve")
    if caps:
        r = width / 2.0
        for p in (pts[0], pts[-1]):
            d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=fill)


def g_back(d, S):
    s = S / 64.0
    w = int(5.2 * s)
    rounded_line(d, [(38 * s, 14 * s), (22 * s, 32 * s), (38 * s, 50 * s)], w)
    rounded_line(d, [(24 * s, 32 * s), (52 * s, 32 * s)], w)


def g_home(d, S):
    s = S / 64.0
    w = int(5.0 * s)
    rounded_line(d, [(12 * s, 31 * s), (32 * s, 13 * s), (52 * s, 31 * s)], w)
    rounded_line(d, [(17 * s, 27 * s), (17 * s, 51 * s), (47 * s, 51 * s), (47 * s, 27 * s)], w)


def g_recents(d, S):
    s = S / 64.0
    w = int(4.6 * s)
    r = 7 * s
    d.rounded_rectangle([15 * s, 17 * s, 49 * s, 47 * s], radius=r, outline=CREAM, width=w)
    d.ellipse([29 * s, 29 * s, 35 * s, 35 * s], fill=CREAM)


def g_phone(d, S):
    s = S / 64.0
    w = int(4.4 * s)
    d.rounded_rectangle([21 * s, 9 * s, 43 * s, 55 * s], radius=5 * s, outline=CREAM, width=w)
    d.rounded_rectangle([24 * s, 13 * s, 40 * s, 46 * s], radius=2 * s, fill=CREAM)


def g_bell(d, S):
    s = S / 64.0
    body = [
        (20 * s, 45 * s), (22 * s, 38 * s), (22 * s, 27 * s),
        (26 * s, 18 * s), (32 * s, 15 * s), (38 * s, 18 * s),
        (42 * s, 27 * s), (42 * s, 38 * s), (44 * s, 45 * s),
    ]
    d.polygon(body, fill=CREAM)
    d.rounded_rectangle([17 * s, 44 * s, 47 * s, 49 * s], radius=2.5 * s, fill=CREAM)
    d.ellipse([28 * s, 50 * s, 36 * s, 58 * s], fill=CREAM)


def g_bluetooth(d, S):
    s = S / 64.0
    w = int(4.4 * s)
    rounded_line(d, [(32 * s, 10 * s), (32 * s, 54 * s)], w)
    rounded_line(d, [(32 * s, 10 * s), (46 * s, 24 * s), (18 * s, 44 * s), (32 * s, 54 * s)], w)
    rounded_line(d, [(32 * s, 32 * s), (46 * s, 42 * s), (32 * s, 54 * s)], w)


def g_dnd(d, S):
    s = S / 64.0
    w = int(4.2 * s)
    d.ellipse([12 * s, 12 * s, 52 * s, 52 * s], outline=CREAM, width=w)
    rounded_line(d, [(20 * s, 32 * s), (44 * s, 32 * s)], int(5.2 * s))


def g_airplane(d, S):
    s = S / 64.0
    pts = [(32, 7), (36, 20), (36, 30), (55, 38), (55, 44), (36, 41), (36, 51), (43, 57), (43, 61),
           (32, 57), (21, 61), (21, 57), (28, 51), (28, 41), (9, 44), (9, 38), (28, 30), (28, 20)]
    d.polygon([(x * s, y * s) for x, y in pts], fill=CREAM)


def g_rotation(d, S):
    s = S / 64.0
    w = int(4.2 * s)
    d.rounded_rectangle([25 * s, 16 * s, 43 * s, 48 * s], radius=4 * s, outline=CREAM, width=w)
    d.arc([14 * s, 12 * s, 54 * s, 52 * s], 200, 520, fill=CREAM, width=w)
    d.polygon([(52 * s, 14 * s), (58 * s, 26 * s), (45 * s, 25 * s)], fill=CREAM)


def g_flashlight(d, S):
    s = S / 64.0
    d.rounded_rectangle([25 * s, 10 * s, 39 * s, 30 * s], radius=3 * s, fill=CREAM)
    d.polygon([(23 * s, 33 * s), (41 * s, 33 * s), (49 * s, 58 * s), (15 * s, 58 * s)], fill=CREAM)
    d.rounded_rectangle([22 * s, 10 * s, 42 * s, 16 * s], radius=2 * s, fill=(255, 250, 224, 255))


def g_battery_saver(d, S):
    s = S / 64.0
    w = int(4.2 * s)
    d.rounded_rectangle([10 * s, 22 * s, 48 * s, 42 * s], radius=4 * s, outline=CREAM, width=w)
    d.rounded_rectangle([49 * s, 28 * s, 55 * s, 36 * s], radius=1.5 * s, fill=CREAM)
    rounded_line(d, [(29 * s, 27 * s), (29 * s, 37 * s)], int(4.4 * s))
    rounded_line(d, [(24 * s, 32 * s), (34 * s, 32 * s)], int(4.4 * s))


def g_screen_record(d, S):
    s = S / 64.0
    w = int(4.2 * s)
    d.ellipse([12 * s, 12 * s, 52 * s, 52 * s], outline=CREAM, width=w)
    d.ellipse([25 * s, 25 * s, 39 * s, 39 * s], fill=CREAM)


def g_gear(d, S):
    s = S / 64.0
    w = int(4.0 * s)
    cx = cy = 32 * s
    for i in range(8):
        a = math.radians(i * 45)
        x0 = cx + math.cos(a) * 15 * s
        y0 = cy + math.sin(a) * 15 * s
        x1 = cx + math.cos(a) * 25 * s
        y1 = cy + math.sin(a) * 25 * s
        rounded_line(d, [(x0, y0), (x1, y1)], w)
    d.ellipse([cx - 16 * s, cy - 16 * s, cx + 16 * s, cy + 16 * s], outline=CREAM, width=w)
    d.ellipse([cx - 5.5 * s, cy - 5.5 * s, cx + 5.5 * s, cy + 5.5 * s], outline=CREAM, width=w)


def g_power(d, S):
    s = S / 64.0
    w = int(4.2 * s)
    d.arc([14 * s, 12 * s, 50 * s, 50 * s], 120, 420, fill=CREAM, width=w)
    rounded_line(d, [(32 * s, 10 * s), (32 * s, 28 * s)], w)


def g_mic(d, S):
    s = S / 64.0
    w = int(4.2 * s)
    d.rounded_rectangle([26 * s, 9 * s, 38 * s, 34 * s], radius=6 * s, fill=CREAM)
    d.arc([20 * s, 22 * s, 44 * s, 44 * s], 0, 180, fill=CREAM, width=w)
    rounded_line(d, [(32 * s, 44 * s), (32 * s, 53 * s)], w)


def g_search(d, S):
    s = S / 64.0
    w = int(4.2 * s)
    d.ellipse([12 * s, 12 * s, 40 * s, 40 * s], outline=CREAM, width=w)
    rounded_line(d, [(38 * s, 38 * s), (52 * s, 52 * s)], w)

def g_allapps(d, S):
    s = S / 64.0
    r = 4.6 * s
    for gy in range(3):
        for gx in range(3):
            cx = (18 + gx * 14) * s
            cy = (18 + gy * 14) * s
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=CREAM)




GLYPHS = {
    "nav_back": g_back,
    "nav_home": g_home,
    "nav_recents": g_recents,
    "nav_phone": g_phone,
    "nav_bell": g_bell,
    "qs_bluetooth": g_bluetooth,
    "qs_dnd": g_dnd,
    "qs_airplane": g_airplane,
    "qs_rotation": g_rotation,
    "qs_flashlight": g_flashlight,
    "qs_battery_saver": g_battery_saver,
    "qs_screen_record": g_screen_record,
    "qs_gear": g_gear,
    "qs_power": g_power,
    "qs_mic": g_mic,
    "qs_search": g_search,
    "nav_allapps": g_allapps,
}


def build_glyphs():
    for name, fn in GLYPHS.items():
        for size in (64, 128):
            img = make_glyph(name, fn, size)
            img = _grad_cream(img)
            folder = "glyphs" if size == 64 else "glyphs/128"
            path = os.path.join(OUT, *folder.split("/"))
            os.makedirs(path, exist_ok=True)
            img.save(os.path.join(path, name + ".png"), optimize=True)
    print("glyphs:", len(GLYPHS))


if __name__ == "__main__":
    render_icon_set("icon_map", "#7C8A5E", "#3B4A2F", fg_map)
    build_glyphs()
    print("done ->", OUT)




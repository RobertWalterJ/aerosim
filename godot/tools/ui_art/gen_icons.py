"""Priority 0 app icons (adaptive: bg + fg layers, composite tile, sizes) and Priority 2 monochrome versions."""
import math
import numpy as np
from lib import *
from glyphs import *

UNIT = 3.38          # 512 * 0.66 / 100 : 100 art units = the 66 percent adaptive safe zone
SIZES = (512, 128, 64, 44)
MOSS_D = hx("#2C4A36")
RUST_D = hx("#8A432C")
SLATE_D = hx("#2F4156")
LAKE_DD = hx("#1F4E5A")
PINE_I = hx("#243428")


# ---------------------------------------------------------------- foreground art (units, origin = tile centre)
def fg_dronebudz(c):
    bub = c.rrect(-38, -34, 38, 20, 15) | c.poly([(-24, 14), (-4, 14), (-26, 36)], 1.6)
    c.fill(bub, vgrad(CREAM_HI, CREAM_LO, -34, 38))
    cx, cy = 0, -7
    for sx in (-1, 1):
        for sy in (-1, 1):
            c.fill(c.line([(0, cy), (sx * 16, cy + sy * 12)], 3.0), MOSS_D)
    for sx in (-1, 1):
        for sy in (-1, 1):
            rx, ry = sx * 16, cy + sy * 12
            c.fill(c.circle(rx, ry, 7.6), MOSS_D, 0.20)
            c.fill(c.ring(rx, ry, 7.0, 2.1), MOSS_D)
            c.fill(c.circle(rx, ry, 1.7), MOSS_D)
    c.fill(c.rrect(-7.5, cy - 6, 7.5, cy + 5, 4.2), vgrad(hx("#3F6A4B"), MOSS_D, cy - 6, cy + 5))
    c.fill(c.circle(0, cy - 0.5, 2.1), CREAM_HI)


def fg_vidtube(c):
    c.fill(c.rrect(-44, -30, 44, 30, 19) - c.rrect(-42, -28, 42, 28, 17), CREAM_HI, 0.38)
    c.fill(c.rrect(-38, -24, 38, 24, 14), vgrad(CREAM_HI, CREAM_LO, -24, 24))
    tri = c.poly([(-9, -14), (-9, 14), (16, 0)], 2.2)
    c.fill(tri, vgrad(hx("#C4714F"), RUST_D, -14, 14))
    c.fill(c.line([(-30, 39), (30, 39)], 4.0), CREAM_HI, 0.35)
    c.fill(c.line([(-30, 39), (-3, 39)], 4.0), BRASS)
    c.fill(c.circle(-3, 39, 4.2), BRASS_HI)


def fg_photos(c):
    c.fill(c.ring(0, 0, 36, 4.4), CREAM_HI, 0.55)
    c.fill(c.circle(0, 0, 32), vgrad(CREAM_HI, CREAM_LO, -32, 32))
    R, r = 32.0, 15.0
    verts = [(r * math.cos(math.radians(60 * k - 90)), r * math.sin(math.radians(60 * k - 90))) for k in range(6)]
    for k in range(6):
        v, pv = verts[k], verts[k - 1]
        d = (v[0] - pv[0], v[1] - pv[1])
        L = math.hypot(*d)
        d = (d[0] / L, d[1] / L)
        b = v[0] * d[0] + v[1] * d[1]
        t = -b + math.sqrt(b * b - (r * r - R * R))
        c.fill(c.line([v, (v[0] + d[0] * t, v[1] + d[1] * t)], 2.4), LAKE_DD, 0.85)
    hexm = c.poly(verts, 0.5)
    c.fill(hexm, vgrad(hx("#BFD9D2"), hx("#F0D9A0"), -15, 15))
    land = c.poly([(-17, 4), (-9, -3), (-3, 3), (4, -6), (10, -1), (17, 4), (17, 17), (-17, 17)], 0)
    c.fill(land & hexm, LAKE_D)
    valley = c.poly([(-17, 9), (-6, 2), (0, 11), (6, 4), (17, 10), (17, 17), (-17, 17)], 0)
    c.fill(valley & hexm, LAKE_DD)
    c.fill(c.circle(7, -6, 3.0) & hexm, BRASS)
    c.fill(c.ring(0, 0, 15, 1.3), LAKE_DD)


def fg_jobs(c):
    c.fill(c.rrect(-27, -33, 27, 40, 8), vgrad(CREAM_HI, CREAM_LO, -33, 40))
    c.fill(c.rrect(-13, -40, 13, -26, 5), vgrad(hx("#4A5C4E"), PINE_I, -40, -26))
    for i, done in enumerate((True, True, False)):
        y = -12 + i * 17
        if done:
            c.fill(c.line([(-20, y + 0.5), (-16.5, y + 4), (-10, y - 4)], 3.4), hx("#4D8A58"))
        else:
            c.fill(c.rrect(-20.5, y - 4.5, -11.5, y + 4.5, 2.4) - c.rrect(-18.7, y - 2.7, -13.3, y + 2.7, 1.2), MUTED)
        c.fill(c.line([(-4, y), (18, y)], 3.0), PINE_I, 0.78 if done else 0.45)
    c.fill(c.circle(0, -33, 4.6), vgrad(BRASS_HI, BRASS_LO, -38, -28))
    c.fill(c.circle(-1.2, -34.2, 1.4), hx("#FFF3CF"), 0.8)


def fg_casebook(c):
    c.fill(c.rrect(-36, -20, 36, 34, 7), vgrad(hx("#D8CCA6"), hx("#B9AC86"), -20, 34))
    c.fill(c.rrect(-36, -30, -2, -14, 5.5), vgrad(BRASS_HI, BRASS_LO, -30, -14))
    c.fill(c.rrect(-36, -12, 36, 36, 7), vgrad(CREAM_HI, CREAM_LO, -12, 36))
    c.fill(c.line([(-26, 2), (4, 2)], 3.0), SLATE_D, 0.7)
    c.fill(c.line([(-26, 12), (-4, 12)], 3.0), SLATE_D, 0.45)
    c.fill(c.line([(-26, 22), (-10, 22)], 3.0), SLATE_D, 0.3)
    # evidence seal with ribbon tails
    c.fill(c.poly([(18, 24), (13, 44), (19, 40), (24, 46), (26, 26)], 0.6), RUST_D)
    seal = c.circle(20, 20, 11)
    for i in range(12):
        a = math.radians(i * 30)
        seal = seal | c.circle(20 + 11 * math.cos(a), 20 + 11 * math.sin(a), 3.2)
    c.fill(seal, Gradient([(0, BRASS_HI), (0.6, BRASS), (1, BRASS_LO)], center=(16, 16), radius=20))
    c.fill(c.ring(20, 20, 7.0, 1.6), RUST_D, 0.8)
    c.fill(c.poly([(20, 15), (21.7, 19), (25.5, 19.3), (22.6, 21.8), (23.5, 25.5), (20, 23.4), (16.5, 25.5), (17.4, 21.8), (14.5, 19.3), (18.3, 19)], 0), RUST_D, 0.85)


def fg_facade(c):
    # storefront
    c.fill(c.rrect(-32, -12, 32, 36, 5), vgrad(CREAM_HI, CREAM_LO, -12, 36))
    c.fill(c.rrect(-26, -2, 4, 24, 3), vgrad(hx("#3F4B42"), hx("#1E2822"), -2, 24))
    c.fill(c.poly([(-24, 2), (-14, 2), (-22, 22), (-24, 22)], 0), CREAM_HI, 0.12)
    # awning with scallops
    n = 6
    x0, w = -40, 80 / n
    for i in range(n):
        col = RUST if i % 2 == 0 else CREAM_HI
        lo = RUST_D if i % 2 == 0 else CREAM_LO
        xa, xb = x0 + i * w, x0 + (i + 1) * w
        top_in = 0.0 if i in (0, n - 1) else 0
        stripe = c.poly([(xa + (3 if i == 0 else 0), -34), (xb - (3 if i == n - 1 else 0), -34), (xb + 0.2, -16), (xa - 0.2, -16)], 0)
        stripe = stripe | c.circle((xa + xb) / 2, -16, w / 2 + 0.05)
        c.fill(stripe, vgrad(col, lo, -34, -10))
    c.fill(c.rrect(-41, -37, 41, -31, 3), vgrad(hx("#C4714F"), RUST_D, -37, -31))
    # hanging price tag
    tag = c.poly([(12, 2), (28, 2), (31, 7), (31, 30), (9, 30), (9, 7)], 1.0)
    c.fill(tag, vgrad(BRASS_HI, BRASS_LO, 2, 30))
    c.fill(c.circle(20, 8, 2.2), hx("#6E4A1C"))
    c.fill(c.line([(20, 8), (20, -12)], 1.0), hx("#6E4A1C"), 0.6)
    c.fill(c.line([(14, 18), (26, 18)], 2.4), RUST_D, 0.85)
    c.fill(c.line([(14, 24), (22, 24)], 2.4), RUST_D, 0.55)


def fg_settings(c):
    teeth = None
    for i in range(8):
        a = math.radians(i * 45)
        ca, sa = math.cos(a), math.sin(a)
        pa, pb = (-sa, ca), (ca, sa)
        def P(rad, off):
            return (pb[0] * rad + pa[0] * off, pb[1] * rad + pa[1] * off)
        tooth = c.poly([P(26, -7.5), P(26, 7.5), P(39, 5.4), P(39, -5.4)], 1.2)
        teeth = tooth if teeth is None else (teeth | tooth)
    body = c.circle(0, 0, 30) | teeth
    body = body - c.circle(0, 0, 14)
    c.fill(body, Gradient([(0, CREAM_HI), (1, CREAM_LO)], p0=(-30, -30), p1=(30, 30)))
    c.fill(c.ring(0, 0, 14, 2.2), CREAM_LO)
    c.fill(c.circle(0, 0, 10.5), Gradient([(0, BRASS_HI), (0.6, BRASS), (1, BRASS_LO)], center=(-3, -3), radius=16))
    c.fill(c.circle(0, 0, 3.6), hx("#7A5420"), 0.55)


def fg_recents(c):
    c.fill(c.rrect(-27, -38, 27, -14, 8), vgrad(hx("#8DBEC6"), LAKE, -38, -14), 0.95)
    c.fill(c.rrect(-33, -24, 33, 0, 9), vgrad(hx("#93C79A"), MOSS, -24, 0))
    c.fill(c.rrect(-39, -9, 39, 38, 11), vgrad(CREAM_HI, CREAM_LO, -9, 38))
    c.fill(c.circle(-24, 6, 5.5), vgrad(BRASS_HI, BRASS_LO, 0, 12))
    c.fill(c.line([(-12, 4), (22, 4)], 3.6), PINE_I, 0.75)
    c.fill(c.line([(-12, 12), (8, 12)], 3.0), PINE_I, 0.38)
    c.fill(c.line([(-30, 26), (30, 26)], 2.6), PINE_I, 0.16)


def fg_weather(c):
    draw_sun(c, 16, -16, 13)
    draw_cloud(c, -6, 6, 33)
    c.fill(c.line([(-36, 40), (8, 40)], 3.6), CREAM_HI, 0.92)
    c.fill(c.arc(8, 34.4, 5.6, 90, -150, 3.6), CREAM_HI, 0.92)
    c.fill(c.line([(-18, 32), (-5, 32)], 3.0), CREAM_HI, 0.55)


def fg_camera(c):
    c.fill(c.circle(0, 0, 40), Gradient([(0, hx("#F4D590")), (0.55, BRASS), (1, hx("#9C6C28"))], p0=(-30, -34), p1=(30, 36)))
    c.fill(c.circle(0, 0, 35), Gradient([(0, hx("#5A5F58")), (1, hx("#1D211E"))], p0=(-20, -24), p1=(22, 28)))
    c.fill(c.ring(0, 0, 31.5, 1.3), CREAM_HI, 0.5)
    glass = c.circle(0, 0, 29)
    c.fill(glass, vgrad(hx("#2E6C78"), hx("#7FB2B8"), -29, 29))
    c.fill(c.circle(10, -12, 5.0) & glass, hx("#F6E6B8"))
    c.fill(c.ellipse(-4, 36, 40, 17) & glass, vgrad(hx("#4C7A52"), hx("#2A4A33"), 14, 29))
    c.fill(c.ellipse(26, 40, 28, 13) & glass, hx("#2A4A33"))
    c.fill(c.ring(0, 0, 29, 1.6), hx("#101412"), 0.8)
    c.fill(c.circle(-10, -12, 9.5) & glass, CREAM_HI, 0.10)
    c.fill(c.arc(0, 0, 22, 200, 255, 3.0), CREAM_HI, 0.55)
    c.fill(c.circle(36, -38, 4.2), DANGER)


def fg_home(c):
    c.fill(c.poly([(-29, -8), (0, -33), (29, -8), (29, 36), (-29, 36)], 2.0), vgrad(CREAM_HI, CREAM_LO, -33, 36))
    c.fill(c.rrect(14, -34, 24, -14, 2), vgrad(hx("#D9CDAA"), hx("#B8AC88"), -34, -14))
    c.fill(c.line([(-40, -2), (0, -37), (40, -2)], 8.0), Gradient([(0, BRASS_HI), (1, BRASS_LO)], p0=(0, -40), p1=(0, 0)))
    c.fill(c.rrect(-8, 8, 8, 36, 3.2), vgrad(hx("#4A6B4F"), MOSS_D, 8, 36))
    c.fill(c.circle(4, 23, 1.4), BRASS_HI)
    c.fill(c.rrect(-24, 4, -13, 15, 2), vgrad(hx("#6E9AA3"), hx("#3F6870"), 4, 15))
    c.fill(c.rrect(13, 4, 24, 15, 2), vgrad(hx("#6E9AA3"), hx("#3F6870"), 4, 15))


def fg_phone(c):
    c.fill(c.rrect(-42, -30, 42, 30, 9), vgrad(hx("#F6EED5"), hx("#CFC4A2"), -30, 30))
    scr = c.rrect(-37, -25, 37, 25, 5)
    c.fill(scr, vgrad(hx("#406C73"), hx("#E8C98A"), -25, 25))
    c.fill(c.circle(14, 4, 5.2) & scr, hx("#FFE9B0"))
    c.fill(c.ellipse(-20, 30, 36, 14) & scr, hx("#35563B"))
    c.fill(c.ellipse(24, 32, 30, 13) & scr, hx("#27422E"))
    for i, col in enumerate((CREAM_HI, BRASS, CREAM_HI)):
        c.fill(c.rrect(-10 + i * 9, 17, -3 + i * 9, 23.5, 2.2) & scr, col, 0.9)
    c.fill(c.circle(-40, 0, 1.2), hx("#1A1F1B"), 0.8)
    c.fill(c.line([(-37, 38), (37, 38)], 0.01), CREAM_HI, 0.0)


ICONS = [
    # name, tile top, tile bottom, art
    ("icon_dronebudz", "#6BA175", "#2B4D37", fg_dronebudz),
    ("icon_vidtube", "#CE7F5A", "#7A3C29", fg_vidtube),
    ("icon_photos", "#4A9893", "#1D5258", fg_photos),
    ("icon_jobs", "#41584A", "#17231C", fg_jobs),
    ("icon_casebook", "#7690AA", "#2F4157", fg_casebook),
    ("icon_facade", "#E0AB59", "#8E5F25", fg_facade),
    ("icon_settings", "#5D6358", "#242823", fg_settings),
    ("icon_recents", "#50655A", "#1B2620", fg_recents),
    ("icon_weather", "#72ADBB", "#2A6070", fg_weather),
    ("icon_camera", "#4C534C", "#181B18", fg_camera),
    ("icon_home", "#82A064", "#38502D", fg_home),
    ("icon_phone", "#46666A", "#1A2C2F", fg_phone),
]


# ---------------------------------------------------------------- compositing
def new_icon_canvas(S):
    return Canvas(S).unit(0, 0, S / 512.0)


def bg_layer(S, top, bot):
    c = new_icon_canvas(S)
    full = c.rrect(0, 0, 512, 512, 0)
    c.fill(full, dgrad(hx(top), hx(bot), (60, 0, 452, 512)))
    c.fill(full, Gradient([(0, (255, 244, 214, 70)), (1, (255, 244, 214, 0))], center=(140, 100), radius=360))
    for r in (150, 225, 300, 375):
        c.fill(c.ring(470, 560, r, 6), (255, 244, 214, 255), 0.07)
    c.fill(full, Gradient([(0, (0, 0, 0, 0)), (1, (0, 0, 0, 56))], center=(256, 256), radius=380))
    return c


def fg_layer(S, art, scale=1.0):
    c = Canvas(S).unit(S / 2.0, S / 2.0, S / 512.0 * UNIT * scale)
    art(c)
    return c


def safe_ok(fg, S):
    """True if all visible art lies inside the 66 percent adaptive safe zone (small tolerance)."""
    a = np.array(fg.img.getchannel("A")) > 12
    ys, xs = np.where(a)
    half = (S * fg.ss) / 2.0
    lim = 0.66 * (S * fg.ss) / 2.0 * 1.01
    return max(abs(xs.min() - half), abs(xs.max() - half), abs(ys.min() - half), abs(ys.max() - half)) <= lim


def make_icon(name, top, bot, art, S):
    s = S / 512.0
    bgc = bg_layer(S, top, bot)
    fgc = fg_layer(S, art)
    assert safe_ok(fgc, S), f"{name}: art leaves the 66% safe zone"
    c = new_icon_canvas(S)
    tile = c.rrect(6, 6, 506, 506, 112)
    c.shadow(tile, dy=3 if S >= 100 else 1, blur=4 if S >= 100 else 1.5, alpha=0.33)
    layer = bgc.img.copy()
    layer.putalpha(tile.img)
    c.img = Image.alpha_composite(c.img, layer)
    c.sheen(tile, 6, 240, 0.20, 0.0)
    # rim light on the top edge, dark rim on the bottom, warm hairline all round
    n = max(1, int(round(1.6 * s * c.ss)))
    edge = tile.edge(n)
    c.sheen(edge, 6, 330, 0.55, 0.10, (255, 246, 220, 255))
    c.sheen(edge, 250, 506, 0.0, 0.40, (20, 14, 8, 255))
    # art with a short contact shadow
    sh = Canvas(S)
    sh.shadow(fgc.alpha_mask(), dy=2.5 if S >= 100 else 1, blur=3 if S >= 100 else 1, alpha=0.30, color=(8, 12, 9, 255))
    c.paste(sh)
    c.paste(fgc)
    return c, bgc, fgc


def mono_icon(art, S):
    fgc = fg_layer(S, art, scale=1.22)
    arr = np.array(fgc.img).astype(np.float32)
    lum = (0.299 * arr[..., 0] + 0.587 * arr[..., 1] + 0.114 * arr[..., 2]) / 255.0
    keep = np.clip((lum - 0.42) / 0.22, 0, 1)
    a = arr[..., 3] * keep
    out = np.zeros_like(arr)
    out[..., 0:3] = 255
    out[..., 3] = a
    fgc.img = Image.fromarray(out.astype(np.uint8), "RGBA")
    return fgc


def build():
    done = []
    for name, top, bot, art in ICONS:
        for S in SIZES:
            c, bgc, fgc = make_icon(name, top, bot, art, S)
            sub = "" if S == 512 else f"{S}/"
            save(c.render(), f"icons/{sub}{name}.png")
            if S == 512:
                save(bgc.render(), f"icons/layers/{name}_bg.png")
                save(fgc.render(), f"icons/layers/{name}_fg.png")
            m = mono_icon(art, S)
            save(m.render(), f"icons/mono/{sub}{name}_mono.png")
        done.append(name)
    return done


if __name__ == "__main__":
    print(build())

"""Casebook kit, ink stamps and paper surfaces (CLAUDE-PHONE-APP-UI-PASS.md P0, CLAUDE-APP-ASSETS.md P1).

No readable text anywhere: stamps use bars, rules, stars and pictograms where a real stamp would have words.
"""
import math
from appui_lib import *
from gen_app_glyphs import GLYPHS


# ------------------------------------------------------------------ paper
def paper(n=2048, seed=11, base=(239, 231, 210), fib=900, grid=None, folds=None):
    """Warm recycled paper, tileable: periodic mottling, wrapped fibres, very fine tooth. Optional survey grid and folds."""
    rng = np.random.default_rng(seed)
    mott = tile_noise(n, seed, ((4, 1.0), (9, 0.6), (22, 0.3)))
    tooth = tile_noise(n, seed + 1, ((180, 1.0), (400, 0.7)))
    img = np.zeros((n, n, 3), np.float32)
    for ch in range(3):
        img[..., ch] = base[ch]
    shade = (mott - 0.5)[..., None] * np.array([15.0, 14.0, 12.0]) + (tooth - 0.5)[..., None] * np.array([7.0, 7.0, 6.5])
    img = img + shade
    # fibres: short wavy strokes, a few darker, a few lighter; drawn with wrap-around so the tile is seamless
    fl = Image.new("L", (n, n), 0)
    fd = Image.new("L", (n, n), 0)
    dl, dd = ImageDraw.Draw(fl), ImageDraw.Draw(fd)
    for i in range(fib):
        x, y = rng.random() * n, rng.random() * n
        a = rng.random() * math.tau
        ln = 8 + rng.random() * 36
        cur = (rng.random() - 0.5) * 0.08
        pts = []
        for k in range(8):
            a += cur
            pts.append((x, y))
            x += math.cos(a) * ln / 7
            y += math.sin(a) * ln / 7
        tgt = dd if rng.random() < 0.55 else dl
        val = int(60 + rng.random() * 120)
        for ox in (-n, 0, n):
            for oy in (-n, 0, n):
                tgt.line([(p[0] + ox, p[1] + oy) for p in pts], fill=val, width=1)
    fl = np.asarray(fl.filter(ImageFilter.GaussianBlur(0.6)), np.float32) / 255.0
    fd = np.asarray(fd.filter(ImageFilter.GaussianBlur(0.6)), np.float32) / 255.0
    img += fl[..., None] * 12.0 - fd[..., None] * np.array([16.0, 17.0, 19.0])
    if grid:
        step, col, a = grid
        yy, xx = np.mgrid[0:n, 0:n]
        g = ((xx % step) < 1.6) | ((yy % step) < 1.6)
        g2 = ((xx % (step * 5)) < 2.6) | ((yy % (step * 5)) < 2.6)
        for ch in range(3):
            img[..., ch] = np.where(g, img[..., ch] * (1 - a) + col[ch] * a, img[..., ch])
            img[..., ch] = np.where(g2, img[..., ch] * (1 - a * 1.6) + col[ch] * a * 1.6, img[..., ch])
    if folds:
        yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
        for fx in folds[0]:
            d = np.abs(xx - fx * n)
            img -= (np.exp(-(d / 3.0) ** 2) * 18 - np.exp(-((xx - fx * n - 5) / 5.0) ** 2) * 6)[..., None]
        for fy in folds[1]:
            d = np.abs(yy - fy * n)
            img -= (np.exp(-(d / 3.0) ** 2) * 18 - np.exp(-((yy - fy * n - 5) / 5.0) ** 2) * 6)[..., None]
        edge = np.minimum(np.minimum(xx, n - xx), np.minimum(yy, n - yy)) / n
        img *= (0.93 + 0.07 * np.clip(edge / 0.12, 0, 1))[..., None]
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")


def grain_overlay(n=512, seed=5):
    """Very quiet paper grain: neutral warm grey with alpha 0..~18 percent, tileable, for Casebook and Jobs cards."""
    t = tile_noise(n, seed, ((60, 1.0), (140, 0.8), (300, 0.6)))
    m = tile_noise(n, seed + 3, ((5, 1.0), (12, 0.5)))
    a = np.clip((t - 0.35) * 0.30 + m * 0.06, 0, 0.18)
    out = np.zeros((n, n, 4), np.uint8)
    out[..., 0], out[..., 1], out[..., 2] = 120, 104, 80
    out[..., 3] = (a * 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


# ------------------------------------------------------------------ ink stamps
def ink(c, mask, col, seed, amount=0.45):
    c.fill(mask, col, 0.92)
    return c


def stamp_canvas(S):
    return Canvas(S).unit(S / 2, S / 2, S / 100.0)


def bars(c, x0, x1, y, h=3.2, n=5, seed=1):
    """A row of blocky marks standing in for stamped words (deliberately not letters)."""
    rng = np.random.default_rng(seed)
    m = None
    x = x0
    while x < x1 - 2:
        w = min(x1 - x, 3 + rng.random() * 9)
        r = c.rrect(x, y - h / 2, x + w, y + h / 2, 0.6)
        m = r if m is None else (m | r)
        x += w + 2.2
    return m


def finish(c, m, col, seed, S, amount=0.42, rot=0.0):
    c.fill(m, col)
    im = c.render()
    im = recolor(im, col)
    im = distress(im, seed, amount)
    if rot:
        im = im.rotate(rot, resample=Image.BICUBIC)
    return im


def stamp_case(S, kind, seed):
    """Rectangular case stamp: double frame, a folder pictogram, rows of bars. kind: open / closed."""
    c = stamp_canvas(S)
    m = orrect(c, -44, -27, 44, 27, 5, 3.4) | orrect(c, -39, -22, 39, 22, 3, 1.4)
    pic = Canvas(S).unit(S / 2 - S * 0.24, S / 2, S / 100.0 * 1.25)
    GLYPHS["casefile"](pic, (0, 0, 0, 255))
    m = m | Mask(pic.img.getchannel("A"))
    m = m | bars(c, -14, 33, -8, 5.0, seed=seed) | bars(c, -14, 26, 3, 3.2, seed=seed + 1) | bars(c, -14, 30, 12, 3.2, seed=seed + 2)
    if kind == "closed":
        m = m | c.line([(-38, 21), (38, -21)], 3.2)
    col = INK_SLATE if kind == "open" else INK_RUST
    return finish(c, m, col, seed, S, rot=-6 if kind == "open" else 5)


def stamp_round(S, seed, col, inner, star_ring=True):
    c = stamp_canvas(S)
    m = c.ring(0, 0, 45, 3.6) | c.ring(0, 0, 38.5, 1.4) | c.ring(0, 0, 25, 1.6)
    if star_ring:
        for i in range(16):
            a = math.radians(i * 22.5)
            m = m | c.circle(31.8 * math.cos(a), 31.8 * math.sin(a), 1.6 if i % 4 else 2.6)
    m = m | inner(c)
    return finish(c, m, col, seed, S, rot=(seed % 7) - 3)


def inner_star_hills(c):
    pts = []
    for i in range(10):
        a = math.radians(-90 + i * 36)
        r = 9 if i % 2 == 0 else 3.8
        pts.append((r * math.cos(a), r * math.sin(a) - 6))
    m = c.poly(pts, 0.3)
    m = m | c.line([(-21, 13), (-10, 5), (-3, 10), (6, 2), (21, 13)], 2.6)
    m = m | c.line([(-19, 17.5), (19, 17.5)], 1.6)
    return m


def inner_folder_check(c):
    m = c.line([(-15, 1), (-5, 11), (15, -11)], 5.0)
    return m


def seal(S):
    """casebook_stamp_evidence: a brass and rust evidence seal (no crest): scalloped disc, valley and star, ribbon tails."""
    c = Canvas(S).unit(S / 2, S / 2, S / 100.0)
    c.fill(c.poly([(-4, 18), (-22, 48), (-14, 45), (-9, 52), (6, 22)], 1.2), Gradient([(0, hx("#A64A33")), (1, hx("#6E2C1F"))], p0=(-20, 20), p1=(0, 50)))
    c.fill(c.poly([(4, 18), (22, 48), (14, 45), (9, 52), (-6, 22)], 1.2), Gradient([(0, hx("#B65439")), (1, hx("#7A3324"))], p0=(20, 20), p1=(0, 50)))
    m = c.circle(0, -4, 31)
    for i in range(24):
        a = math.radians(i * 15)
        m = m | c.circle(31 * math.cos(a), -4 + 31 * math.sin(a), 4.2)
    c.shadow(m, dy=2.0, blur=3.0, alpha=0.35)
    c.fill(m, Gradient([(0, hx("#F8DC9C")), (0.5, BRASS), (1, hx("#9E6A27"))], center=(-12, -18), radius=50))
    c.fill(c.ring(0, -4, 25.5, 1.6), hx("#8A5A1E"), 0.85)
    c.fill(c.ring(0, -4, 22.0, 0.9), hx("#8A5A1E"), 0.7)
    for i in range(20):
        a = math.radians(i * 18)
        c.fill(c.circle(23.8 * math.cos(a), -4 + 23.8 * math.sin(a), 0.8), hx("#8A5A1E"), 0.8)
    inner = c.circle(0, -4, 19.5)
    c.fill(inner, Gradient([(0, hx("#F3D08A")), (1, hx("#C99645"))], p0=(0, -24), p1=(0, 16)))
    c.fill(c.poly([(-20, 8), (-9, -2), (-3, 3), (5, -6), (20, 6), (20, 20), (-20, 20)], 0) & inner, hx("#9C6A28"), 0.85)
    c.fill(c.poly([(-20, 12), (-6, 5), (2, 10), (20, 9), (20, 20), (-20, 20)], 0) & inner, hx("#7E5220"), 0.9)
    pts = []
    for i in range(10):
        a = math.radians(-90 + i * 36)
        r = 7.2 if i % 2 == 0 else 3.0
        pts.append((r * math.cos(a), -12 + r * math.sin(a)))
    c.fill(c.poly(pts, 0.2), hx("#8E3B2A"))
    c.sheen(m, -36, 0, 0.35, 0.0)
    return c.render()


def timeline_node(S, kind):
    c = Canvas(S).unit(S / 2, S / 2, S / 24.0)
    if kind == "open":
        c.fill(c.circle(0, 0, 10.5), hx("#2A2F29"))
        c.fill(c.ring(0, 0, 8.2, 3.2), Gradient([(0, BRASS_HI), (1, BRASS_LO)], p0=(0, -9), p1=(0, 9)))
        c.fill(c.circle(0, 0, 3.0), BRASS)
    elif kind == "done":
        c.fill(c.circle(0, 0, 10.5), Gradient([(0, hx("#8DBE92")), (1, hx("#4F7F57"))], p0=(0, -10), p1=(0, 10)))
        c.fill(c.line([(-4.8, 0.3), (-1.4, 3.8), (5, -3.6)], 2.6), CREAM_HI)
    else:
        c.fill(c.circle(0, 0, 10.5), hx("#1F241F"), 0.9)
        c.fill(c.ring(0, 0, 8.4, 2.0), GREY, 0.9)
    return c.render()


def folder_9patch(W=256, H=256):
    """Manila case folder for a 9-patch: tab on the top-left, brass corner protector bottom-right. Margins in the manifest."""
    c = Canvas(W, H).unit(0, 0, 1.0)
    back = c.rrect(4, 34, W - 4, H - 4, 14) | c.rrect(4, 6, 110, 60, 12)
    c.shadow(back, dy=2, blur=4, alpha=0.3)
    c.fill(back, dgrad(hx("#E2CB95"), hx("#BFA266"), (0, 0, W, H)))
    c.fill(c.rrect(4, 6, 110, 60, 12) - c.rrect(4, 40, W, H, 0), hx("#CDB277"))
    c.fill(c.line([(16, 22), (80, 22)], 3), hx("#9C834E"), 0.45)
    c.fill(c.rrect(4, 34, W - 4, 40, 2), hx("#A88E57"), 0.5)
    corner = c.poly([(W - 4, H - 50), (W - 4, H - 4), (W - 50, H - 4)], 0)
    c.fill(corner & c.rrect(4, 34, W - 4, H - 4, 14), Gradient([(0, BRASS_HI), (1, BRASS_LO)], p0=(W - 40, H - 40), p1=(W, H)))
    for x, y in ((W - 16, H - 30), (W - 30, H - 16)):
        c.fill(c.circle(x, y, 2.4), hx("#7A5420"))
    c.fill(c.rrect(4, 34, W - 4, H - 4, 14).edge(4), (255, 246, 220, 255), 0.25)
    im = c.render()
    arr = np.asarray(im).astype(np.float32)
    nz = tile_noise(max(W, H), 21, ((20, 1.0), (60, 0.5), (140, 0.4)))[:H, :W]
    arr[..., :3] *= (0.95 + 0.08 * nz)[..., None]
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def photo_frame_9patch(S=192, corner=True, border=18):
    """Cream mount: transparent window, soft inner shadow, paper photo corners."""
    c = Canvas(S).unit(0, 0, 1.0)
    outer = c.rrect(2, 2, S - 2, S - 2, 4)
    win = c.rrect(border, border, S - border, S - border, 1)
    c.shadow(outer, dy=1.5, blur=3, alpha=0.3)
    c.fill(outer - win, vgrad(hx("#F6EFDC"), hx("#E3D8BC"), 0, S))
    c.fill(win.edge(3) , (60, 45, 25, 255), 0.25)
    if corner:
        for sx, sy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            x = border - 6 if sx == 0 else S - border + 6
            y = border - 6 if sy == 0 else S - border + 6
            dx = 1 if sx == 0 else -1
            dy = 1 if sy == 0 else -1
            tri = c.poly([(x, y), (x + dx * 30, y), (x, y + dy * 30)], 0)
            c.fill(tri, hx("#D7C9A6"))
            c.fill(tri.edge(2), (90, 70, 40, 255), 0.25)
    # the window stays see-through: only a 3 px inner shadow survives inside it
    hole = c.rrect(border + 3, border + 3, S - border - 3, S - border - 3, 1)
    keep = 1 - np.asarray(hole.img, np.float32) / 255.0
    if corner:
        for sx, sy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            x = border - 6 if sx == 0 else S - border + 6
            y = border - 6 if sy == 0 else S - border + 6
            dx = 1 if sx == 0 else -1
            dy = 1 if sy == 0 else -1
            keep = np.maximum(keep, np.asarray(c.poly([(x, y), (x + dx * 30, y), (x, y + dy * 30)], 0).img, np.float32) / 255.0)
    a = np.asarray(c.img.getchannel("A"), np.float32) * keep
    c.img.putalpha(Image.fromarray(a.astype(np.uint8)))
    return c.render()


def empty_folder(S=512):
    c = Canvas(S).unit(S / 2, S / 2, S / 100.0)
    back = c.rrect(-40, -24, 40, 32, 4) | c.rrect(-40, -32, -10, -18, 4)
    c.shadow(back, dy=3, blur=5, alpha=0.3)
    c.fill(back, vgrad(hx("#CDB277"), hx("#A88E57"), -32, 32))
    c.fill(c.rrect(-36, -20, 36, 26, 2), hx("#EFE7D2"), 0.35)
    front = c.poly([(-44, -6), (44, -6), (40, 32), (-40, 32)], 1.5)
    c.shadow(front, dy=2, blur=3, alpha=0.25)
    c.fill(front, vgrad(hx("#E6D09C"), hx("#C2A66B"), -6, 32))
    c.fill(c.line([(-36, 0), (36, 0)], 0.6), hx("#FFF4D6"), 0.4)
    clip = c.line([(18, -30), (18, -4), (25, -4), (25, -27), (21, -27), (21, -10)], 1.6)
    c.fill(clip, Gradient([(0, hx("#D9DCD6")), (1, hx("#8E938B"))], p0=(18, -30), p1=(26, -4)))
    return c.render()


def pin(S):
    c = Canvas(S).unit(S / 2, S / 2, S / 24.0)
    c.fill(c.line([(1, 2), (6.5, 10)], 1.4), hx("#9A9C95"))
    c.shadow(c.circle(-1.5, -2.5, 7.2), dy=1.0 if S < 48 else 1.6, blur=1.2 if S < 48 else 2.2, alpha=0.35)
    c.fill(c.circle(-1.5, -2.5, 7.2), Gradient([(0, hx("#F0897A")), (0.6, PIN_RED), (1, hx("#7E2219"))], center=(-4, -5.5), radius=10))
    c.fill(c.ellipse(-4, -5.2, 2.4, 1.6), (255, 240, 230, 255), 0.7)
    return c.render()


# ------------------------------------------------------------------ pictorial ink stamps (acts, jobs, facade)
def act_inner(kind):
    def f(c):
        if kind == "act_1_waiting":
            m = c.poly([(-2, -14), (2, -14), (14, 20), (-14, 20)], 0) - c.poly([(-0.6, -10), (0.6, -10), (1.6, 18), (-1.6, 18)], 0)
            for y, h in ((-6, 2), (2, 2.6), (11, 3.4)):
                m = m - c.rrect(-0.8 - y * 0.02, y, 0.8 + y * 0.02, y + h, 0)
            m = m | c.line([(-22, -14), (22, -14)], 1.6)
            m = m | c.line([(-14, -14), (-14, -20)], 1.4) | c.line([(-17, -18), (-11, -18)], 1.4)
            return m
        if kind == "act_2_lake_car":
            car = c.poly([(-15, 0), (-11, -7), (6, -7), (11, 0), (16, 1), (16, 6), (-16, 6), (-16, 1)], 0.8)
            car = car - c.poly([(-9, -5), (-2, -5), (-2, -0.5), (-12, -0.5)], 0) - c.poly([(0, -5), (5, -5), (8.5, -0.5), (0, -0.5)], 0)
            m = car | c.circle(-9, 6.5, 3.2) | c.circle(9, 6.5, 3.2)
            for i, y in enumerate((12, 17)):
                m = m | c.line([(x, y + 1.2 * math.sin(x * 0.5 + i)) for x in np.linspace(-22, 22, 30)], 1.8)
            return m
        if kind == "act_3_last_flight":
            m = None
            for i, x in enumerate(np.linspace(-22, 22, 9)):
                h = 10 + 5 * ((i * 7) % 3)
                t = c.poly([(x - 4.5, 10), (x, 10 - h), (x + 4.5, 10)], 0.2)
                m = t if m is None else m | t
            cab = c.poly([(-7, 12), (-7, 2), (0, -4), (7, 2), (7, 12)], 0.3)
            m = (m - c.rrect(-10, -6, 10, 14, 0)) | cab
            m = m - c.rrect(-3, 4, 1.5, 8.5, 0.4)
            m = m | c.line([(-24, 12.5), (24, 12.5)], 1.6)
            m = m | c.rrect(-2, 4.8, 0.5, 7.7, 0.2)
            return m
        if kind == "act_4_cabin":
            cab = c.poly([(-22, 10), (-22, 0), (-14, -7), (-6, 0), (-6, 10)], 0.3) - c.rrect(-17, 2, -13, 6, 0.3)
            car = c.poly([(2, 10), (2, 4), (6, 0), (16, 0), (20, 4), (22, 4), (22, 10)], 0.6) | c.circle(7, 10.5, 2.4) | c.circle(18, 10.5, 2.4)
            car = car | c.rrect(9, -2.4, 14, 0.2, 0.4)
            beam = c.poly([(-3, -12), (-1, -10), (-14, 2), (-17, -1)], 0)
            torch = c.rrect(-4, -14, 1, -10, 1)
            return cab | car | torch | Mask(beam.img.point(lambda v: int(v * 0.6))) | c.line([(-24, 13), (24, 13)], 1.6)
        if kind == "act_5_end":
            m = c.line([(-24, 10), (-12, 2), (-4, 7), (6, -1), (24, 10)], 2.2)
            m = m | c.line([(-24, 15), (24, 15)], 1.4)
            sun = c.circle(0, 2, 6.5) - c.rrect(-10, 4, 10, 12, 0)
            m = m | sun
            for i in range(7):
                a = math.radians(-180 + 15 + i * 25)
                m = m | c.line([(10 * math.cos(a), 2 + 10 * math.sin(a)), (15 * math.cos(a), 2 + 15 * math.sin(a))], 1.6)
            return m
        return None
    return f


def job_stamp(S, kind, seed):
    c = stamp_canvas(S)
    if kind == "pulled":
        m = orrect(c, -42, -26, 42, 26, 6, 3.4) | bars(c, -30, 30, -4, 6, seed=seed) | bars(c, -24, 24, 8, 3.4, seed=seed + 1)
        m = m | c.line([(-40, 24), (40, -24)], 4.0) | c.line([(-40, -24), (40, 24)], 4.0)
        return finish(c, m, INK_RUST, seed, S, rot=-8)
    m = c.ring(0, 0, 44, 3.4)
    for side in (-1, 1):
        for i in range(6):
            a = math.radians(115 + i * 22) if side < 0 else math.radians(65 - i * 22)
            x, y = 33 * math.cos(a), 33 * math.sin(a)
            m = m | c.ellipse(x, y, 3.4, 1.8)
    pts = []
    for i in range(10):
        a = math.radians(-90 + i * 36)
        r = 20 if i % 2 == 0 else 8.5
        pts.append((r * math.cos(a), r * math.sin(a) - 2))
    m = m | c.poly(pts, 0.8) | bars(c, -18, 18, 24, 3.4, seed=seed)
    return finish(c, m, INK_BRASS, seed, S, rot=6)


def sold_mark(S):
    c = stamp_canvas(S)
    tag = c.poly([(-30, -18), (24, -18), (40, 0), (24, 18), (-30, 18)], 3)
    m = (tag - tag.erode(int(3.5 * c.k))) | c.circle(22, 0, 4.2)
    m = m | c.line([(-18, 0), (-9, 9), (8, -9)], 5.0)
    return finish(c, m, hx("#5E8A63"), 41, S, amount=0.3, rot=-10)


def photos_empty(S=512):
    c = Canvas(S).unit(S / 2, S / 2, S / 100.0)
    sheet = c.rrect(-34, -40, 34, 40, 2)
    c.shadow(sheet, dy=3, blur=5, alpha=0.3)
    c.fill(sheet, vgrad(hx("#F3ECD8"), hx("#E2D6B7"), -40, 40))
    for r in range(4):
        for k in range(3):
            x0, y0 = -28 + k * 19.5, -32 + r * 17
            c.fill(c.rrect(x0, y0, x0 + 16, y0 + 12, 0.6), hx("#2B302A"), 0.10)
            c.fill(c.rrect(x0, y0, x0 + 16, y0 + 12, 0.6).edge(int(0.5 * c.k)), hx("#2B302A"), 0.25)
    for k in range(9):
        c.fill(c.rrect(-33, -38 + k * 9, -31.4, -36 + k * 9, 0.2), hx("#2B302A"), 0.18)
        c.fill(c.rrect(31.4, -38 + k * 9, 33, -36 + k * 9, 0.2), hx("#2B302A"), 0.18)
    clip = c.line([(10, -48), (10, -30), (16, -30), (16, -45), (13, -45), (13, -34)], 1.4)
    c.fill(clip, Gradient([(0, hx("#D9DCD6")), (1, hx("#8E938B"))], p0=(10, -48), p1=(16, -30)))
    return c.render()


def seller_strip(W=192, H=48):
    c = Canvas(W, H).unit(0, 0, 1.0)
    m = c.rrect(1, 1, W - 1, H - 1, 10)
    c.fill(m, dgrad(hx("#3A3326"), hx("#2A2620"), (0, 0, W, H)))
    c.fill(c.rrect(1, 1, 7, H - 1, 3) & m, BRASS)
    c.fill(m.edge(2), (224, 171, 89, 255), 0.35)
    c.sheen(m, 0, H, 0.08, 0.0)
    return c.render()


def build():
    save_ui(paper(), "casebook_paper.jpg", note="2048 tileable recycled paper, no text")
    save_ui(grain_overlay(), "paper_grain.png", note="tileable 512 grain overlay, alpha 0-18 percent, for Casebook and Jobs cards")
    save_ui(folder_9patch(), "casebook_folder.png", nine=(48, 72, 48, 48), note="9-patch manila folder; margins left, top, right, bottom")
    save_ui(stamp_case(384, "open", 3), "casebook_stamp_open.png", note="blue-grey ink, no readable text")
    save_ui(stamp_case(384, "closed", 5), "casebook_stamp_closed.png", note="red-brown ink, no readable text")
    save_ui(stamp_case(384, "closed", 5), "stamp_case_closed.png", note="same as casebook_stamp_closed (case_art key)")
    save_ui(seal(512), "casebook_stamp_evidence.png", note="evidence seal, 256 nominal, no crest")
    save_ui(seal(256), "sizes/256/casebook_stamp_evidence.png")
    save_ui(stamp_round(384, 9, INK_SLATE, inner_star_hills), "stamp_evidence.png", note="ink evidence stamp (case_art key)")
    save_ui(photo_frame_9patch(), "casebook_photo_frame.png", nine=(24, 24, 24, 24), note="9-patch mount, transparent window")
    save_ui(photo_frame_9patch(corner=False, border=12), "photos_frame_clean.png", nine=(16, 16, 16, 16), note="9-patch warm photo border")
    for k in ("open", "done", "waiting"):
        save_ui(timeline_node(64, k), f"casebook_timeline_node_{k}.png", note="32 and 64 px")
        save_ui(timeline_node(32, k), f"sizes/32/casebook_timeline_node_{k}.png")
    save_ui(empty_folder(), "casebook_empty_folder.png", note="512 empty-state")
    save_ui(pin(64), "casebook_pin_red.png", note="32 px nominal")
    save_ui(pin(32), "sizes/32/casebook_pin_red.png")
    for i, k in enumerate(("act_1_waiting", "act_2_lake_car", "act_3_last_flight", "act_4_cabin", "act_5_end")):
        col = (INK_SLATE, LAKE_D, hx("#5B4A3A"), INK_RUST, hx("#5E7F4E"))[i]
        im = stamp_round(384, 30 + i, col, act_inner(k), star_ring=False)
        save_ui(im, f"{k}.png", note="act stamp, works at 64-180 px")
    save_ui(job_stamp(192, "pulled", 51), "job_stamp_pulled.png", note="96 px nominal")
    save_ui(job_stamp(192, "excellent", 52), "job_stamp_excellent.png", note="96 px nominal")
    save_ui(sold_mark(128), "facade_sold.png", note="sold / in-collection mark, 64 nominal")
    save_ui(photos_empty(), "photos_empty.png", note="512 empty contact sheet")
    save_ui(seller_strip(), "facade_seller_strip.png", nine=(16, 12, 12, 12), note="9-patch seller strip")


if __name__ == "__main__":
    build()

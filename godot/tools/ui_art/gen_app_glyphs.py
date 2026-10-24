"""Line glyphs and small badges for the phone apps (CLAUDE-PHONE-APP-UI-PASS.md and CLAUDE-APP-ASSETS.md).

One family: a 24-unit grid, 2-unit round strokes (1.5 px at 18 px), a 20-unit live area, cream or brass on transparent.
Coloured badges are a filled disc or rounded tile in the app colour with the glyph in cream on top.
"""
import math
from appui_lib import *

W = 2.0


def L(c, pts, w=W):
    return c.line(pts, w)


# ------------------------------------------------------------------ system: status bar and navigation
def g_signal(c, col):
    for i in range(4):
        h = 4 + i * 4.2
        x = -9 + i * 5.2
        c.fill(c.rrect(x, 9 - h, x + 3.4, 9, 1.0), col, 1.0 if i < 3 else 0.38)


def g_wifi(c, col):
    for r in (13, 8.6, 4.2):
        c.fill(c.arc(0, 8, r, -136, -44, W), col)
    c.fill(c.circle(0, 8, 1.7), col)


def g_battery(c, col, level=0.72, fillcol=None):
    c.fill(orrect(c, -10, -5.5, 8, 5.5, 2.2, 1.8), col)
    c.fill(c.rrect(8.8, -2.4, 11.2, 2.4, 0.8), col)
    c.fill(c.rrect(-7.6, -3.1, -7.6 + 13.2 * level, 3.1, 0.9), fillcol or col)


def g_battery_low(c, col):
    g_battery(c, col, 0.2, DANGER)


def g_bell(c, col):
    bell = c.poly([(-7.5, 5), (-6, 2), (-6, -3), (-3.5, -7), (3.5, -7), (6, -3), (6, 2), (7.5, 5)], 1.2)
    c.fill(bell | c.rrect(-8.5, 4, 8.5, 6.4, 1.2), col)
    c.fill(c.circle(0, -8.2, 1.4), col)
    c.fill(c.ellipse(0, 8.4, 2.6, 1.9), col)


def g_search(c, col):
    c.fill(c.ring(-2, -2, 6.4, W + 0.2), col)
    c.fill(L(c, [(2.8, 2.8), (9, 9)], W + 0.6), col)


def g_home(c, col):
    c.fill(L(c, [(-10, -0.5), (0, -9), (10, -0.5)], W), col)
    c.fill(L(c, [(-7, -2.5), (-7, 9), (7, 9), (7, -2.5)], W), col)
    c.fill(c.rrect(-2.2, 3, 2.2, 9.5, 0.8), col)


def g_back(c, col):
    c.fill(L(c, [(-1, -8), (-9, 0), (-1, 8)], W + 0.2), col)
    c.fill(L(c, [(-8, 0), (9, 0)], W + 0.2), col)


def g_recents(c, col):
    c.fill(orrect(c, -9, -4, 5, 9, 2.4, W), col)
    c.fill(L(c, [(-5, -8.5), (7, -8.5), (9.3, -6.5), (9.3, 5)], W), col)


def g_close(c, col):
    c.fill(L(c, [(-7.5, -7.5), (7.5, 7.5)], W + 0.3), col)
    c.fill(L(c, [(7.5, -7.5), (-7.5, 7.5)], W + 0.3), col)


def g_more(c, col):
    for y in (-7, 0, 7):
        c.fill(c.circle(0, y, 1.9), col)


def g_mic(c, col):
    c.fill(c.rrect(-3.6, -10, 3.6, 3, 3.6), col)
    c.fill(c.arc(0, -1, 7.2, 15, 165, W), col)
    c.fill(L(c, [(0, 6.3), (0, 10)], W), col)
    c.fill(L(c, [(-4, 10), (4, 10)], W), col)


# ------------------------------------------------------------------ casebook tabs
def g_leaf(c, col):
    c.fill(L(c, [(-7, -10), (3, -10), (8, -5), (8, 10), (-7, 10), (-7, -10)], W), col)
    c.fill(L(c, [(3, -10), (3, -5), (8, -5)], W * 0.8), col)
    for i, ln in enumerate((9, 11, 7)):
        c.fill(L(c, [(-3.5, -1 + i * 4), (-3.5 + ln, -1 + i * 4)], W * 0.75), col, 0.85)


def g_photo_seal(c, col):
    c.fill(orrect(c, -10, -8, 6, 6, 1.6, W), col)
    c.fill(c.poly([(-8, 4), (-4, -1), (-1, 2), (2, -2), (4.5, 4)], 0.2), col, 0.85)
    m = c.circle(6.5, 6, 5.4)
    for i in range(10):
        a = math.radians(i * 36)
        m = m | c.circle(6.5 + 5.4 * math.cos(a), 6 + 5.4 * math.sin(a), 1.3)
    c.fill(c.circle(6.5, 6, 7.6), (0, 0, 0, 255), 0.0)
    c.img = Image.alpha_composite(c.img, Image.new("RGBA", c.img.size, (0, 0, 0, 0)))
    # punch a gap round the seal so it reads at 24 px
    gap = c.circle(6.5, 6, 7.8)
    a = np.asarray(c.img.getchannel("A")).astype(np.float32) * (1 - np.asarray(gap.img, np.float32) / 255.0)
    c.img.putalpha(Image.fromarray(a.astype(np.uint8)))
    c.fill(m, col)
    c.fill(c.circle(6.5, 6, 2.0), (0, 0, 0, 255), 0.0)


def g_timeline(c, col):
    c.fill(L(c, [(-6, -8), (-6, 8)], W * 0.8), col, 0.7)
    for i, y in enumerate((-8, 0, 8)):
        if i == 0:
            c.fill(c.circle(-6, y, 2.8), col)
        else:
            c.fill(c.ring(-6, y, 2.4, 1.6), col)
        c.fill(L(c, [(0, y), (9 - i * 2, y)], W * 0.8), col, 0.9)


def g_people(c, col):
    c.fill(c.circle(-3.5, -4, 3.6), col)
    c.fill(c.poly([(-10.5, 9.5), (-9.5, 3), (-6, 0.6), (-1, 0.6), (2.5, 3), (3.5, 9.5)], 1.0), col)
    gap = c.circle(4.5, -2.5, 4.8) | c.poly([(-0.5, 10.5), (0.5, 4), (3.5, 1.6), (9, 1.6), (12, 4), (12.5, 10.5)], 1.6)
    a = np.asarray(c.img.getchannel("A")).astype(np.float32) * (1 - np.asarray(gap.img, np.float32) / 255.0)
    c.img.putalpha(Image.fromarray(a.astype(np.uint8)))
    c.fill(c.circle(4.5, -2.5, 3.2), col, 0.8)
    c.fill(c.poly([(-1.5, 9.5), (-0.5, 4.5), (2.5, 2.4), (7, 2.4), (10, 4.5), (11, 9.5)], 1.0), col, 0.8)


# ------------------------------------------------------------------ DroneBudz
def g_compose(c, col):
    c.fill(L(c, [(2, -8), (-8, -8), (-8, 9), (9, 9), (9, -1)], W), col)
    c.fill(L(c, [(-2, 3), (8, -7)], W + 0.6), col)
    c.fill(c.poly([(-3.4, 4.4), (-1.6, 0.8), (0.6, 3)], 0.3), col)
    c.fill(L(c, [(7, -9.4), (10.4, -6)], W), col)


def g_attach(c, col):
    c.fill(c.arc(0, -4.5, 4.2, 180, 360, W), col)
    c.fill(L(c, [(-4.2, -4.5), (-4.2, 5)], W), col)
    c.fill(L(c, [(4.2, -4.5), (4.2, 6)], W), col)
    c.fill(c.arc(-0.6, 5, 3.6, 0, 180, W), col)
    c.fill(L(c, [(-0.6 + 3.6 - 7.2, 5), (-4.2, 5)], W), col)
    c.fill(c.arc(0.4, -3, 1.7, 180, 360, W * 0.8), col)
    c.fill(L(c, [(-1.3, -3), (-1.3, 4.5)], W * 0.8), col)
    c.fill(L(c, [(2.1, -3), (2.1, 5)], W * 0.8), col)


def g_send(c, col):
    c.fill(c.poly([(-10, -8.5), (10, 0), (-10, 8.5), (-6.5, 0)], 0.6), col)
    c.fill(L(c, [(-6.2, 0), (2, 0)], 1.2), (0, 0, 0, 255), 0.35)


def g_hash(c, col):
    c.fill(L(c, [(-3, -9), (-5, 9)], W), col)
    c.fill(L(c, [(4, -9), (2, 9)], W), col)
    c.fill(L(c, [(-8.5, -3.5), (8.5, -3.5)], W), col)
    c.fill(L(c, [(-9.5, 3.5), (7.5, 3.5)], W), col)


def g_voice(c, col):
    c.fill(c.poly([(-10, -3), (-6, -3), (-1, -8), (-1, 8), (-6, 3), (-10, 3)], 0.6), col)
    c.fill(c.arc(0, 0, 4.2, -50, 50, W), col)
    c.fill(c.arc(0, 0, 8.4, -55, 55, W), col)


def g_clipboard(c, col):
    c.fill(orrect(c, -8, -7.5, 8, 10, 2, W), col)
    c.fill(c.rrect(-4, -10.5, 4, -5.5, 1.4), col)
    c.fill(L(c, [(-4.5, 0), (-2.5, 2), (1, -2)], W * 0.9), col)
    c.fill(L(c, [(-4.5, 6), (4.5, 6)], W * 0.8), col, 0.8)


def g_reply(c, col):
    c.fill(L(c, [(-3, -8), (-9, -2.5), (-3, 3)], W + 0.2), col)
    pts = c.bez((-8, -2.5), (2, -2.5), (9, -2), (9, 8))
    c.fill(L(c, pts, W + 0.2), col)


def g_pin(c, col):
    c.fill(c.circle(3.5, -4.5, 5.2), col)
    c.fill(c.poly([(-2.5, -3.5), (2.5, 1.5), (-1.5, 3.5), (-4.5, 0.5)], 0.6), col)
    c.fill(L(c, [(-2.5, 1.5), (-9, 8)], W * 0.8), col)
    c.fill(c.circle(5.0, -6.0, 1.6), (0, 0, 0, 255), 0.0)


def g_pencil(c, col):
    c.fill(L(c, [(-6.5, 6.5), (6, -6)], W * 2.0), col)
    c.fill(c.poly([(-9.5, 9.5), (-8.6, 4.4), (-4.4, 8.6)], 0.4), col)
    c.fill(L(c, [(4.2, -8.6), (8.6, -4.2)], W * 0.8), (0, 0, 0, 255), 0.0)


# ------------------------------------------------------------------ VidTube Studio
def g_followers(c, col):
    g_people(c, col)


def g_money(c, col):
    for i in range(4):
        y = 8 - i * 3.6
        c.fill(c.rrect(-8, y - 1.6, 8, y + 1.6, 1.4), col, 1.0 if i < 3 else 1.0)
        if i < 3:
            c.fill(L(c, [(-6.5, y - 1.8), (6.5, y - 1.8)], 0.7), (0, 0, 0, 255), 0.0)
    c.fill(c.ellipse(0, -5.2, 8, 2.6), col)
    c.fill(c.ring(0, -5.2, 0.01, 0.01), col, 0.0)


def g_videos(c, col):
    c.fill(orrect(c, -10, -7.5, 10, 7.5, 2, W), col)
    for x in (-7, -2.5, 2.5, 7):
        c.fill(c.rrect(x - 1, -6.4, x + 1, -4.6, 0.3), col)
        c.fill(c.rrect(x - 1, 4.6, x + 1, 6.4, 0.3), col)
    c.fill(c.poly([(-2.5, -3), (-2.5, 3), (3, 0)], 0.5), col)


def g_views(c, col):
    eye = c.poly([(-11, 0)] + [(-11 + 22 * t, -6.5 * math.sin(math.pi * t)) for t in np.linspace(0, 1, 20)] +
                 [(-11 + 22 * t, 6.5 * math.sin(math.pi * t)) for t in np.linspace(1, 0, 20)], 0)
    c.fill(eye - eye.erode(int(W * c.k * 0.9)), col)
    c.fill(c.circle(0, 0, 3.6), col)


def g_play(c, col):
    c.fill(c.poly([(-6, -9), (9, 0), (-6, 9)], 1.3), col)


def g_upload(c, col):
    c.fill(L(c, [(0, 4), (0, -9)], W + 0.2), col)
    c.fill(L(c, [(-6, -3), (0, -9), (6, -3)], W + 0.2), col)
    c.fill(L(c, [(-9, 3), (-9, 9), (9, 9), (9, 3)], W), col)


def g_cut(c, col):
    c.fill(c.ring(-5, 6, 3.2, W), col)
    c.fill(c.ring(5, 6, 3.2, W), col)
    c.fill(L(c, [(-3, 3.5), (6, -10)], W), col)
    c.fill(L(c, [(3, 3.5), (-6, -10)], W), col)
    c.fill(c.circle(0, -1.6, 1.0), (0, 0, 0, 255), 0.0)


# ------------------------------------------------------------------ Photos
def g_album(c, col):
    c.fill(L(c, [(-7, -9.5), (9.5, -9.5), (9.5, 6)], W), col, 0.7)
    c.fill(orrect(c, -10, -6, 6, 9.5, 1.4, W), col)
    c.fill(c.poly([(-8, 8), (-4, 2), (-1.5, 4.5), (1.5, 1), (4.5, 8)], 0.2), col)
    c.fill(c.circle(1.5, -2.5, 1.6), col)


def g_grid(c, col):
    for x in (-9.5, 2):
        for y in (-9.5, 2):
            c.fill(orrect(c, x, y, x + 7.5, y + 7.5, 1.4, W), col)


def g_detail(c, col):
    c.fill(orrect(c, -10, -7.5, 10, 7.5, 1.6, W), col)
    c.fill(c.poly([(-8, 6), (-3, -1), (0, 2), (4, -3), (8.5, 6)], 0.2), col)
    c.fill(c.circle(-4, -3.5, 1.8), col)


def g_bin(c, col):
    c.fill(L(c, [(-9, -6), (9, -6)], W), col)
    c.fill(L(c, [(-3, -6), (-3, -9), (3, -9), (3, -6)], W), col)
    c.fill(L(c, [(-6.5, -5), (-5.5, 9.5), (5.5, 9.5), (6.5, -5)], W), col)
    for x in (-2.2, 2.2):
        c.fill(L(c, [(x, -1.5), (x, 6)], W * 0.75), col, 0.85)


def g_share(c, col):
    c.fill(c.circle(6, -7, 3), col)
    c.fill(c.circle(-6, 0, 3), col)
    c.fill(c.circle(6, 7, 3), col)
    c.fill(L(c, [(-6, 0), (6, -7)], W * 0.85), col)
    c.fill(L(c, [(-6, 0), (6, 7)], W * 0.85), col)


# ------------------------------------------------------------------ Jobs
def g_keepclear(c, col):
    for i in range(12):
        a0 = i * 30
        c.fill(c.arc(0, 0, 9, a0, a0 + 17, W), col)
    c.fill(c.circle(0, 0, 2.8), col)


def g_range(c, col):
    c.fill(c.circle(-6, 6, 2.6), col)
    for r in (6, 11):
        c.fill(c.arc(-6, 6, r, -90, 0, W), col)
    c.fill(c.arc(-6, 6, 16, -80, -10, W), col, 0.6)


def g_frame(c, col):
    for sx in (-1, 1):
        for sy in (-1, 1):
            c.fill(L(c, [(sx * 9.5, sy * 4), (sx * 9.5, sy * 8), (sx * 5.5, sy * 8)], W), col)
    c.fill(c.circle(0, 0, 2.2), col)
    c.fill(L(c, [(-4, 0), (-2.8, 0)], W * 0.6), col)


def g_retake(c, col):
    c.fill(c.arc(0, 0, 8, -60, 230, W + 0.2), col)
    a = math.radians(-60)
    x, y = 8 * math.cos(a), 8 * math.sin(a)
    c.fill(c.poly([(x + 3.8, y - 1.2), (x - 2.4, y - 3.4), (x - 0.4, y + 3.6)], 0.4), col)
    c.fill(c.circle(0, 0, 2.2), col)


def g_pulled(c, col):
    c.fill(orrect(c, -8, -9, 8, 9, 2, W), col)
    c.fill(L(c, [(-4, -4), (4, -4)], W * 0.75), col, 0.6)
    c.fill(L(c, [(-4, 0.5), (2, 0.5)], W * 0.75), col, 0.6)
    c.fill(L(c, [(-11, 10), (11, -10)], W + 0.4), col)


def g_star(c, col):
    pts = []
    for i in range(10):
        a = math.radians(-90 + i * 36)
        r = 10 if i % 2 == 0 else 4.3
        pts.append((r * math.cos(a), r * math.sin(a) + 0.8))
    c.fill(c.poly(pts, 0.8), col)


def g_camera(c, col):
    c.fill(orrect(c, -10, -5, 10, 8.5, 2.2, W), col)
    c.fill(c.poly([(-4.5, -5), (-2.8, -8.5), (2.8, -8.5), (4.5, -5)], 0.6), col)
    c.fill(c.ring(0, 1.8, 3.8, W), col)
    c.fill(c.circle(6.5, -2.2, 1.0), col)


def g_barn(c, col):
    c.fill(L(c, [(-10, -1), (-6, -7), (0, -10), (6, -7), (10, -1)], W), col)
    c.fill(L(c, [(-8.5, -2), (-8.5, 9.5), (8.5, 9.5), (8.5, -2)], W), col)
    c.fill(orrect(c, -3.5, 2, 3.5, 9.5, 0.4, W * 0.8), col)
    c.fill(L(c, [(-3.5, 2), (3.5, 9.5)], W * 0.7), col)
    c.fill(L(c, [(3.5, 2), (-3.5, 9.5)], W * 0.7), col)


def g_lake(c, col):
    for i, y in enumerate((-2.5, 2.5, 7.5)):
        pts = [(x, y + 1.5 * math.sin(x * 0.75 + i)) for x in np.linspace(-10, 10, 30)]
        c.fill(L(c, pts, W), col, 1.0 - i * 0.18)
    c.fill(c.circle(5.5, -8.6, 2.2), col)


def g_civic(c, col):
    c.fill(c.poly([(-10.5, -4), (0, -10.5), (10.5, -4)], 0.8), col)
    for x in (-7, -2.4, 2.4, 7):
        c.fill(L(c, [(x, -1.5), (x, 6.5)], W), col)
    c.fill(L(c, [(-10, 9), (10, 9)], W + 0.3), col)


# ------------------------------------------------------------------ Facade
def g_drone(c, col):
    for sx in (-1, 1):
        for sy in (-1, 1):
            c.fill(L(c, [(0, 0), (sx * 6, sy * 6)], W), col)
            c.fill(c.ring(sx * 6.5, sy * 6.5, 3.4, W * 0.8), col)
    c.fill(c.rrect(-3, -3.5, 3, 3.5, 1.5), col)


def g_bolt_battery(c, col):
    c.fill(orrect(c, -6.5, -8, 6.5, 10, 2, W), col)
    c.fill(c.rrect(-2.6, -10.6, 2.6, -8.4, 0.6), col)
    c.fill(c.poly([(1, -5), (-3.5, 2), (-0.5, 2), (-1.5, 7), (3.5, -0.5), (0.5, -0.5)], 0.3), col)


def g_gear(c, col):
    m = c.circle(0, 0, 6.6)
    for i in range(8):
        a = math.radians(i * 45)
        ca, sa = math.cos(a), math.sin(a)
        m = m | c.poly([(ca * 5 - sa * 1.8, sa * 5 + ca * 1.8), (ca * 9.6 - sa * 1.4, sa * 9.6 + ca * 1.4),
                        (ca * 9.6 + sa * 1.4, sa * 9.6 - ca * 1.4), (ca * 5 + sa * 1.8, sa * 5 - ca * 1.8)], 0.3)
    c.fill(m - c.circle(0, 0, 3), col)


def g_tag_check(c, col):
    c.fill(L(c, [(-9, -1), (-3, 5.5), (9, -7)], W + 1.0), col)


# ------------------------------------------------------------------ App-assets badges
def g_film(c, col):
    c.fill(orrect(c, -7.5, -10, 7.5, 10, 1.4, W), col)
    for y in (-6.5, -2, 2.5, 7):
        c.fill(c.rrect(-6.2, y - 1, -4.2, y + 1, 0.3), col)
        c.fill(c.rrect(4.2, y - 1, 6.2, y + 1, 0.3), col)
    c.fill(L(c, [(-2.2, -4.5), (2.2, -4.5)], W * 0.6), col, 0.6)
    c.fill(L(c, [(-2.2, 4.5), (2.2, 4.5)], W * 0.6), col, 0.6)


def g_bubble(c, col):
    b = c.rrect(-10, -8.5, 10, 5.5, 4.5) | c.poly([(-5, 4), (0, 4), (-6.5, 10)], 0.4)
    c.fill(b - b.erode(int(W * c.k * 0.95)), col)
    for x in (-4.5, 0, 4.5):
        c.fill(c.circle(x, -1.5, 1.4), col)


def g_casefile(c, col):
    c.fill(L(c, [(-10, -6), (-10, 9), (10, 9), (10, -4), (-1, -4), (-3, -7.5), (-10, -7.5), (-10, -6)], W), col)
    c.fill(c.circle(5.5, 4, 2.4), col)


def g_photo(c, col):
    g_detail(c, col)


def g_houses(c, col):
    c.fill(L(c, [(-10, 1), (-5.5, -4), (-1, 1), (-1, 9), (-10, 9), (-10, 1)], W), col)
    c.fill(L(c, [(-1, -3), (4.5, -9), (10, -3), (10, 9), (-1, 9)], W), col)
    c.fill(c.rrect(3, 3.5, 6, 9, 0.5), col)


def g_cloud(c, col):
    m = c.circle(-4, 1.5, 4.6) | c.circle(1.5, -2, 6.2) | c.circle(6.5, 2.5, 4.0) | c.rrect(-8.6, 1, 10.5, 6.6, 3)
    c.fill(m - m.erode(int(W * c.k * 0.95)), col)


def g_scissors_star(c, col):
    g_cut(c, col)


def g_lock(c, col):
    c.fill(c.rrect(-6.5, -1.5, 6.5, 9, 2), col)
    c.fill(c.arc(0, -2, 4.4, 180, 360, W + 0.4), col)
    c.fill(L(c, [(-4.4, -2), (-4.4, -1)], W + 0.4), col)
    c.fill(L(c, [(4.4, -2), (4.4, -1)], W + 0.4), col)


GLYPHS = {
    "signal": g_signal, "wifi": g_wifi, "battery": g_battery, "battery_low": g_battery_low, "bell": g_bell,
    "search": g_search, "home": g_home, "back": g_back, "recents": g_recents, "close": g_close, "more": g_more,
    "mic": g_mic, "leaf": g_leaf, "photo_seal": g_photo_seal, "timeline": g_timeline, "people": g_people,
    "compose": g_compose, "attach": g_attach, "send": g_send, "hash": g_hash, "voice": g_voice,
    "clipboard": g_clipboard, "reply": g_reply, "pin": g_pin, "pencil": g_pencil, "money": g_money,
    "videos": g_videos, "views": g_views, "play": g_play, "upload": g_upload, "cut": g_cut, "album": g_album,
    "grid": g_grid, "detail": g_detail, "bin": g_bin, "share": g_share, "keepclear": g_keepclear, "range": g_range,
    "frame": g_frame, "retake": g_retake, "pulled": g_pulled, "star": g_star, "camera": g_camera, "barn": g_barn,
    "lake": g_lake, "civic": g_civic, "drone": g_drone, "power": g_bolt_battery, "gear": g_gear, "check": g_tag_check,
    "film": g_film, "bubble": g_bubble, "casefile": g_casefile, "houses": g_houses, "cloud": g_cloud, "lock": g_lock,
}


def glyph(kind, S, col=CREAM, scale=1.0):
    c = Canvas(S).unit(S / 2, S / 2, S / 24.0 * scale)
    GLYPHS[kind](c, col)
    return c.render()


def disc_badge(kind, S, base, col=CREAM_HI, shape="disc", gscale=0.62):
    """A filled app-colour disc (or rounded tile) with a cream glyph: badges and channel marks."""
    c = Canvas(S).unit(S / 2, S / 2, S / 24.0)
    m = c.circle(0, 0, 11.2) if shape == "disc" else c.rrect(-11.2, -11.2, 11.2, 11.2, 4.2)
    c.shadow(m, dy=0.6 if S < 80 else 1.2, blur=0.8 if S < 80 else 1.6, alpha=0.28)
    c.fill(m, dgrad(lighten(base, 0.16), darken(base, 0.22), (-11, -11, 11, 11)))
    c.fill(m.edge(max(1, int(S / 48 * c.ss))), (255, 246, 220, 255), 0.30)
    g = Canvas(S).unit(S / 2, S / 2, S / 24.0 * gscale)
    GLYPHS[kind](g, col)
    c.paste(g)
    return c.render()


# name -> (glyph kind, nominal px, style) ; style: "line" cream glyph, or ("badge", colour[, shape])
SYSTEM = {
    "status_signal": ("signal", 18), "status_wifi": ("wifi", 18), "status_battery": ("battery", 18),
    "status_battery_low": ("battery_low", 18), "status_notification": ("bell", 18), "status_search": ("search", 18),
    "nav_home": ("home", 18), "nav_back": ("back", 18), "nav_recents": ("recents", 18), "nav_close": ("close", 18),
    "nav_more": ("more", 18), "nav_search": ("search", 18),
}
CASE_TABS = {"casebook_tab_overview": "leaf", "casebook_tab_evidence": "photo_seal", "casebook_tab_chapters": "timeline",
             "casebook_tab_contacts": "people"}
APP_LINE = {   # P1 app glyphs: name -> (kind, nominal)
    "chat_compose": ("compose", 32), "chat_attach": ("attach", 32), "chat_mic": ("mic", 32), "chat_send": ("send", 32),
    "chat_channel_hash": ("hash", 24), "chat_channel_voice": ("voice", 24), "chat_channel_jobs": ("clipboard", 24),
    "chat_reply_arrow": ("reply", 20), "chat_pinned": ("pin", 20), "chat_edited": ("pencil", 20),
    "studio_metric_followers": ("people", 32), "studio_metric_money": ("money", 32), "studio_metric_videos": ("videos", 32),
    "studio_metric_views": ("views", 32), "metric_followers": ("people", 32), "metric_money": ("money", 32),
    "metric_videos": ("videos", 32), "metric_views": ("views", 32),
    "studio_play": ("play", 32), "studio_upload": ("upload", 32), "studio_cut": ("cut", 32),
    "photos_album": ("album", 24), "photos_grid": ("grid", 24), "photos_detail": ("detail", 24),
    "photos_delete": ("bin", 24), "photos_share": ("share", 24),
    "job_category_photo": ("camera", 24), "job_category_farm": ("barn", 24), "job_category_lake": ("lake", 24),
    "job_category_civic": ("civic", 24),
    "facade_drones": ("drone", 24), "facade_cameras": ("camera", 24), "facade_power": ("power", 24), "facade_parts": ("gear", 24),
}
BADGES = {     # coloured discs: name -> (kind, nominal, colour, shape)
    "badge_work": ("clipboard", 18, BRASS, "disc"), "badge_guide": ("bubble", 18, MOSS, "disc"),
    "job_badge_distance": ("keepclear", 32, hx("#B98A3A"), "disc"), "job_badge_range": ("range", 32, LAKE, "disc"),
    "job_badge_frame": ("frame", 32, MOSS, "disc"), "job_badge_retake": ("retake", 32, hx("#8C8A6C"), "disc"),
    "job_badge_pulled": ("pulled", 32, RUST, "disc"), "job_badge_excellent": ("star", 32, hx("#C99A45"), "disc"),
    "badge_rush": ("film", 32, RUST, "disc"), "badge_dm": ("bubble", 32, MOSS, "disc"), "badge_job": ("clipboard", 32, BRASS, "disc"),
    "badge_story": ("casefile", 32, SLATE, "disc"), "badge_edited": ("cut", 32, hx("#9C5A3E"), "disc"),
    "notify_clip": ("film", 64, RUST, "tile"), "notify_video": ("play", 64, hx("#A85A3F"), "tile"),
    "notify_photo": ("detail", 64, LAKE, "tile"), "notify_job": ("clipboard", 64, hx("#B98A3A"), "tile"),
    "channel_clips": ("film", 48, RUST, "tile"), "channel_town": ("houses", 48, MOSS, "tile"),
    "channel_weather": ("cloud", 48, LAKE, "tile"), "channel_jobs": ("clipboard", 48, hx("#B98A3A"), "tile"),
}


def badge_dot(S):
    c = Canvas(S).unit(S / 2, S / 2, S / 24.0)
    c.fill(c.circle(0, 0, 10.5), CREAM)
    c.fill(c.circle(0, 0, 8), Gradient([(0, hx("#F07A66")), (1, hx("#C0443A"))], p0=(-6, -7), p1=(6, 7)))
    return c.render()


def badge_unread(w, h):
    c = Canvas(w, h).unit(w / 2, h / 2, h / 24.0)
    k = w / h * 12
    c.fill(c.rrect(-k + 0.5, -11.5, k - 0.5, 11.5, 11.5), CREAM)
    c.fill(c.rrect(-k + 2.5, -9.5, k - 2.5, 9.5, 9.5), Gradient([(0, hx("#F07A66")), (1, hx("#C0443A"))], p0=(-6, -9), p1=(6, 9)))
    return c.render()


def build():
    out = []
    for name, (kind, nom) in SYSTEM.items():
        save_ui(glyph(kind, nom * 2), f"{name}.png", note=f"cream glyph, {nom} px nominal (root is 2x)")
        save_ui(glyph(kind, nom * 2, BRASS), f"sizes/brass/{name}.png", note="brass variant")
        for S in (18, 24, 32, 48, 64):
            save_ui(glyph(kind, S), f"sizes/{S}/{name}.png", note="native render")
        out.append(name)
    save_ui(badge_dot(32), "badge_dot.png", note="16 px nominal")
    save_ui(badge_dot(16), "sizes/16/badge_dot.png")
    save_ui(badge_unread(48, 32), "badge_unread.png", note="pill, the count goes on top; 24 x 16 nominal")
    for nm in ("page_dot_on", "page_dot_off"):
        im = Image.open(os.path.join(TABLET, "polish", nm + ".png")).convert("RGBA")
        save_ui(im, f"{nm}.png", note="copy of the tablet kit page dot")
    for name, kind in CASE_TABS.items():
        save_ui(glyph(kind, 64, CREAM), f"{name}.png", note="tab glyph, 32 px nominal")
        for S in (24, 32):
            save_ui(glyph(kind, S), f"sizes/{S}/{name}.png")
    for name, (kind, nom) in APP_LINE.items():
        save_ui(glyph(kind, nom * 2), f"{name}.png", note=f"{nom} px nominal")
        save_ui(glyph(kind, nom), f"sizes/{nom}/{name}.png")
        if nom > 24:
            save_ui(glyph(kind, 24), f"sizes/24/{name}.png")
    for name, (kind, nom, col, shape) in BADGES.items():
        save_ui(disc_badge(kind, nom * 2, col, shape=shape), f"{name}.png", note=f"{nom} px nominal")
        save_ui(disc_badge(kind, nom, col, shape=shape), f"sizes/{nom}/{name}.png")
    return out


if __name__ == "__main__":
    build()

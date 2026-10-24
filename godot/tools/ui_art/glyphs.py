"""Shared glyph drawing functions (weather, status) used by icons, dials and sheets."""
import math
from lib import *

CREAM_HI = hx("#FDF8E6")
CREAM_LO = hx("#E2D8B8")
BRASS_HI = hx("#F6D590")
BRASS_LO = hx("#C58A3A")
LAKE_HI = hx("#A9D0D6")
LAKE_D = hx("#2B6370")


def cloud_mask(c, x, y, s):
    m = c.circle(x - 0.50 * s, y + 0.12 * s, 0.34 * s)
    m = m | c.circle(x - 0.02 * s, y - 0.10 * s, 0.48 * s)
    m = m | c.circle(x + 0.52 * s, y + 0.14 * s, 0.32 * s)
    m = m | c.rrect(x - 0.84 * s, y + 0.06 * s, x + 0.84 * s, y + 0.46 * s, 0.2 * s)
    return m


def draw_cloud(c, x, y, s, hi=CREAM_HI, lo=CREAM_LO):
    m = cloud_mask(c, x, y, s)
    c.fill(m, vgrad(hi, lo, y - 0.58 * s, y + 0.46 * s))
    return m


def draw_sun(c, x, y, r, rays=True):
    if rays:
        for i in range(8):
            a = math.radians(i * 45 + 22.5)
            p0 = (x + math.cos(a) * r * 1.38, y + math.sin(a) * r * 1.38)
            p1 = (x + math.cos(a) * r * 1.82, y + math.sin(a) * r * 1.82)
            c.fill(c.line([p0, p1], r * 0.30), BRASS)
    c.fill(c.circle(x, y, r), Gradient([(0, BRASS_HI), (0.55, BRASS), (1, BRASS_LO)], center=(x - r * 0.3, y - r * 0.3), radius=r * 1.5))


def draw_moon(c, x, y, r):
    m = c.circle(x, y, r) - c.circle(x + r * 0.55, y - r * 0.28, r * 0.88)
    c.fill(m, vgrad(CREAM_HI, CREAM_LO, y - r, y + r))


def draw_rain(c, x, y, s, n=3, col=None):
    col = col or LAKE_HI
    for i in range(n):
        dx = (i - (n - 1) / 2) * 0.46 * s
        c.fill(c.line([(x + dx + 0.10 * s, y), (x + dx - 0.10 * s, y + 0.34 * s)], 0.13 * s), col)


def draw_bolt(c, x, y, s):
    pts = [(x + 0.10 * s, y - 0.30 * s), (x - 0.22 * s, y + 0.06 * s), (x - 0.02 * s, y + 0.06 * s),
           (x - 0.14 * s, y + 0.42 * s), (x + 0.24 * s, y - 0.06 * s), (x + 0.04 * s, y - 0.06 * s)]
    c.fill(c.poly(pts, 0.03 * s), vgrad(BRASS_HI, BRASS_LO, y - 0.3 * s, y + 0.42 * s))


def draw_flake(c, x, y, r, w, col=CREAM_HI):
    for i in range(3):
        a = math.radians(i * 60 + 90)
        c.fill(c.line([(x - math.cos(a) * r, y - math.sin(a) * r), (x + math.cos(a) * r, y + math.sin(a) * r)], w), col)
        # little barbs
        for sgn in (-1, 1):
            bx, by = x + math.cos(a) * r * 0.6 * sgn, y + math.sin(a) * r * 0.6 * sgn
            for side in (-1, 1):
                aa = a + math.radians(40) * side * sgn
                c.fill(c.line([(bx, by), (bx + math.cos(aa) * r * 0.3 * sgn, by + math.sin(aa) * r * 0.3 * sgn)], w * 0.8), col)


def draw_fog(c, x, y, s, col=CREAM_HI):
    for i, (dx, ln) in enumerate([(-0.1, 1.5), (0.18, 1.6), (-0.05, 1.3)]):
        yy = y + (i - 1) * 0.28 * s
        c.fill(c.line([(x + dx * s - ln * s / 2, yy), (x + dx * s + ln * s / 2, yy)], 0.13 * s), col, 0.95 - i * 0.15)


def draw_wind(c, x, y, s, col=CREAM_HI, w=0.13):
    """Three streaks: top one curls up, middle runs straight, bottom curls down."""
    for yy, ln, curl, d in [(-0.34, 1.30, 0.15, -1), (0.0, 1.70, 0.0, 0), (0.34, 1.10, 0.15, 1)]:
        x0 = x - ln * s / 2
        R = curl * s
        x1 = x + ln * s / 2 - R
        cy = y + yy * s
        c.fill(c.line([(x0, cy), (x1 if d else x + ln * s / 2, cy)], w * s), col)
        if d < 0:
            c.fill(c.arc(x1, cy - R, R, 90, -160, w * s), col)
        elif d > 0:
            c.fill(c.arc(x1, cy + R, R, -90, 160, w * s), col)

"""Tiny supersampled vector-style drawing kit for the AeroSim tablet UI art.

Everything is drawn as antialiased masks at SS x the final size, painted with flat colours or gradients,
and downsampled with premultiplied alpha, so edges stay crisp at 44, 64, 128 and 512 px.
Coordinates are in "units"; Canvas.unit() maps units to final pixels.
"""
import math
import os
import numpy as np
from PIL import Image, ImageDraw, ImageChops, ImageFilter, ImageFont

SS = 4
HERE = os.path.dirname(os.path.abspath(__file__))
FONT_PATH = os.path.join(HERE, "fonts", "Inter.woff2")   # Inter, SIL OFL 1.1
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "ui", "tablet"))


def hx(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


def rgba(c, a=None):
    return (c[0], c[1], c[2], c[3] if a is None else int(a))


def mix(c1, c2, t):
    return tuple(int(round(c1[i] + (c2[i] - c1[i]) * t)) for i in range(4))


def lighten(c, t):
    return mix(c, (255, 255, 255, c[3]), t)


def darken(c, t):
    return mix(c, (0, 0, 0, c[3]), t)


# Palette: UI-STYLE.md plus a few tile depths.
PINE_BLACK = hx("#0E110F")
PINE = hx("#131714")
PANEL = hx("#181D1A")
CARD = hx("#1F241F")
FIELD = hx("#2A2F29")
CREAM = hx("#F0E9D1")
CREAM_DIM = hx("#C2C0AE")
MUTED = hx("#999F8D")
BRASS = hx("#E0AB59")
MOSS = hx("#74A87A")
LAKE = hx("#5C959F")
RUST = hx("#B36447")
DANGER = hx("#DB5C52")
SLATE = hx("#5A7088")
INK = hx("#1B2A22")


class Gradient:
    """Linear or radial multi-stop gradient defined in canvas units."""

    def __init__(self, stops, p0=None, p1=None, center=None, radius=None):
        self.stops = stops
        self.p0, self.p1, self.center, self.radius = p0, p1, center, radius

    def render(self, cv):
        X, Y = cv.grid()
        if self.center is not None:
            cx, cy = cv.pt(*self.center)
            t = np.sqrt((X - cx) ** 2 + (Y - cy) ** 2) / (self.radius * cv.k)
        else:
            x0, y0 = cv.pt(*self.p0)
            x1, y1 = cv.pt(*self.p1)
            dx, dy = x1 - x0, y1 - y0
            t = ((X - x0) * dx + (Y - y0) * dy) / (dx * dx + dy * dy)
        t = np.clip(t, 0, 1)
        ts = [s[0] for s in self.stops]
        out = np.zeros(t.shape + (4,), np.float32)
        for ch in range(4):
            out[..., ch] = np.interp(t, ts, [s[1][ch] for s in self.stops])
        return Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8), "RGBA")


def vgrad(c0, c1, y0, y1):
    return Gradient([(0, c0), (1, c1)], p0=(0, y0), p1=(0, y1))


def dgrad(c0, c1, box):
    x0, y0, x1, y1 = box
    return Gradient([(0, c0), (1, c1)], p0=(x0, y0), p1=(x1, y1))


class Mask:
    def __init__(self, img):
        self.img = img

    def __or__(self, o):
        return Mask(ImageChops.lighter(self.img, o.img))

    def __sub__(self, o):
        return Mask(ImageChops.subtract(self.img, o.img))

    def __and__(self, o):
        return Mask(ImageChops.multiply(self.img, o.img))

    def scaled(self, f):
        return Mask(self.img.point(lambda v: int(v * f)))

    def blur(self, px, ss):
        return Mask(self.img.filter(ImageFilter.GaussianBlur(px * ss)))

    def shifted(self, dx, dy):
        return Mask(ImageChops.offset(self.img, int(dx), int(dy)))

    def erode(self, n):
        im = self.img
        for _ in range(int(n)):
            im = im.filter(ImageFilter.MinFilter(3))
        return Mask(im)

    def edge(self, n):
        return self - self.erode(n)


class Canvas:
    def __init__(self, w, h=None, ss=SS):
        h = h or w
        self.w, self.h, self.ss = w, h, ss
        self.W, self.H = w * ss, h * ss
        self.img = Image.new("RGBA", (self.W, self.H), (0, 0, 0, 0))
        self.ox = self.oy = 0.0
        self.k = float(ss)
        self._grid = None

    # ---- coordinates
    def unit(self, cx, cy, px_per_unit):
        """Origin at final-pixel (cx, cy); one unit = px_per_unit final pixels."""
        self.ox, self.oy, self.k = cx * self.ss, cy * self.ss, px_per_unit * self.ss
        return self

    def pt(self, x, y):
        return (self.ox + x * self.k, self.oy + y * self.k)

    def grid(self):
        if self._grid is None:
            self._grid = np.meshgrid(np.arange(self.W, dtype=np.float32) + 0.5,
                                     np.arange(self.H, dtype=np.float32) + 0.5)
        return self._grid

    # ---- masks
    def blank(self):
        return Image.new("L", (self.W, self.H), 0)

    def circle(self, x, y, r):
        im = self.blank()
        cx, cy = self.pt(x, y)
        ImageDraw.Draw(im).ellipse([cx - r * self.k, cy - r * self.k, cx + r * self.k, cy + r * self.k], fill=255)
        return Mask(im)

    def ellipse(self, x, y, rx, ry):
        im = self.blank()
        cx, cy = self.pt(x, y)
        ImageDraw.Draw(im).ellipse([cx - rx * self.k, cy - ry * self.k, cx + rx * self.k, cy + ry * self.k], fill=255)
        return Mask(im)

    def rrect(self, x0, y0, x1, y1, r):
        im = self.blank()
        a = self.pt(x0, y0)
        b = self.pt(x1, y1)
        ImageDraw.Draw(im).rounded_rectangle([a[0], a[1], b[0] - 1, b[1] - 1], radius=r * self.k, fill=255)
        return Mask(im)

    def poly(self, pts, round_=0.0):
        im = self.blank()
        p = [self.pt(*q) for q in pts]
        d = ImageDraw.Draw(im)
        d.polygon(p, fill=255)
        m = Mask(im)
        if round_ > 0:
            m = m | self.line(list(pts) + [pts[0]], round_ * 2)
        return m

    def line(self, pts, w, cap=True):
        im = self.blank()
        d = ImageDraw.Draw(im)
        p = [self.pt(*q) for q in pts]
        d.line(p, fill=255, width=max(1, int(round(w * self.k))), joint="curve")
        if cap:
            r = w * self.k / 2
            for q in (p[0], p[-1]):
                d.ellipse([q[0] - r, q[1] - r, q[0] + r, q[1] + r], fill=255)
        return Mask(im)

    def arc(self, x, y, r, a0, a1, w, cap=True, step=None):
        """Round-brush stroke: stamps discs along the arc (clean, no joint artefacts)."""
        im = self.blank()
        d = ImageDraw.Draw(im)
        rad = w * self.k / 2
        arclen = abs(math.radians(a1 - a0)) * r * self.k
        n = max(2, int(arclen / max(0.5, rad * 0.35)) + 2)
        for i in range(n):
            a = math.radians(a0 + (a1 - a0) * i / (n - 1))
            px, py = self.pt(x + r * math.cos(a), y + r * math.sin(a))
            d.ellipse([px - rad, py - rad, px + rad, py + rad], fill=255)
        return Mask(im)

    def ring(self, x, y, r, w):
        return self.circle(x, y, r + w / 2) - self.circle(x, y, r - w / 2)

    def bez(self, p0, p1, p2, p3, n=48):
        out = []
        for i in range(n + 1):
            t = i / n
            u = 1 - t
            out.append((u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0],
                        u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1]))
        return out

    def text(self, s, x, y, size, anchor="mm", weight="SemiBold", tracking=0.0):
        im = self.blank()
        f = ImageFont.truetype(FONT_PATH, max(1, int(round(size * self.k))))
        try:
            f.set_variation_by_name(weight)
        except Exception:
            pass
        d = ImageDraw.Draw(im)
        cx, cy = self.pt(x, y)
        if tracking == 0:
            d.text((cx, cy), s, font=f, fill=255, anchor=anchor)
        else:
            adv = [f.getlength(ch) + tracking * self.k for ch in s]
            total = sum(adv) - tracking * self.k
            px = cx - total / 2 if anchor[0] == "m" else cx
            for ch, a in zip(s, adv):
                d.text((px, cy), ch, font=f, fill=255, anchor="l" + anchor[1])
                px += a
        return Mask(im)

    # ---- painting
    def fill(self, mask, paint, opacity=1.0):
        if isinstance(paint, Gradient):
            layer = paint.render(self)
        else:
            layer = Image.new("RGBA", (self.W, self.H), paint)
        a = ImageChops.multiply(layer.getchannel("A"), mask.img)
        if opacity < 1:
            a = a.point(lambda v: int(v * opacity))
        layer.putalpha(a)
        self.img = Image.alpha_composite(self.img, layer)
        return self

    def shadow(self, mask, dy=2.0, blur=2.0, alpha=0.28, color=(0, 0, 0, 255), dx=0.0):
        """dy and blur are FINAL pixels; keep the total spread at or under 8 px."""
        assert dy + blur <= 8.01, "baked shadow too big"
        m = mask.shifted(dx * self.ss, dy * self.ss).blur(blur / 2, self.ss)
        return self.fill(m, color, alpha)

    def sheen(self, mask, top, bottom, a0=0.22, a1=0.0, color=(255, 250, 235, 255)):
        return self._vfade(mask, top, bottom, a0, a1, color)

    def _vfade(self, mask, top, bottom, a0, a1, color):
        Y = self.grid()[1]
        y0 = self.pt(0, top)[1]
        y1 = self.pt(0, bottom)[1]
        t = np.clip((Y - y0) / (y1 - y0), 0, 1)
        a = (a0 + (a1 - a0) * t) * 255.0
        am = Image.fromarray(a.astype(np.uint8), "L")
        layer = Image.new("RGBA", (self.W, self.H), color)
        layer.putalpha(ImageChops.multiply(am, mask.img))
        self.img = Image.alpha_composite(self.img, layer)
        return self

    def paste(self, other, alpha=1.0):
        im = other.img
        if alpha < 1:
            a = im.getchannel("A").point(lambda v: int(v * alpha))
            im = im.copy()
            im.putalpha(a)
        self.img = Image.alpha_composite(self.img, im)
        return self

    def alpha_mask(self):
        return Mask(self.img.getchannel("A"))

    # ---- output
    def render(self, w=None, h=None):
        w = w or self.w
        h = h or self.h
        im = self.img.convert("RGBa").resize((w, h), Image.LANCZOS).convert("RGBA")
        return im


def save(im, rel, size=None):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if size and im.size != (size, size):
        im = im.resize((size, size), Image.LANCZOS)
    im.save(path, optimize=True)
    return path

"""Shared helpers for lane osui: Material 3 tokens (warm field-kit palette), an SVG builder in dp, resvg rendering.

Everything here is vector. Mocks and component art are authored as SVG in dp and rendered with resvg
(`pip install --use-feature=truststore resvg-py`), so every PNG is a native render at its size, never a downscale.
"""
import os, re, io
import resvg_py
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
UI = os.path.join(GODOT, "assets", "ui")
OUT = os.path.join(UI, "osui")
SVGLIB = os.path.join(UI, "svg")
FONTDIR = os.path.join(UI, "fonts_osui")
DOCS = os.path.join(GODOT, "docs")
REAL = os.path.join(DOCS, "realism", "osui")
FONT_FILES = [os.path.join(FONTDIR, f) for f in ("Roboto-Regular.ttf", "Roboto-Medium.ttf", "Roboto-Bold.ttf",
                                                  "RobotoMono-Medium.ttf", "RobotoMono-Bold.ttf")]
MANIFEST = []   # (relpath, w, h, nine, note)

# ------------------------------------------------------------------ tokens
# Material 3 colour roles, tuned to the valley field kit (pine, paper, brass, moss, lake, rust).
DARK = {
    "primary": "#E0AB59", "on-primary": "#402D00", "primary-container": "#5B4320", "on-primary-container": "#FFDEA6",
    "secondary": "#BFCBB0", "on-secondary": "#29341F", "secondary-container": "#3E4A37", "on-secondary-container": "#DBE7CB",
    "tertiary": "#8FCAD3", "on-tertiary": "#00363C", "tertiary-container": "#1F4E55", "on-tertiary-container": "#B5EDF5",
    "error": "#FFB4AB", "on-error": "#690005", "error-container": "#93000A", "on-error-container": "#FFDAD6",
    "surface": "#121512", "surface-dim": "#121512", "surface-bright": "#383C36",
    "surface-container-lowest": "#0D100D", "surface-container-low": "#1A1D19", "surface-container": "#1E221D",
    "surface-container-high": "#282C27", "surface-container-highest": "#333731",
    "on-surface": "#F0E9D1", "on-surface-variant": "#C8C4B0", "outline": "#929080", "outline-variant": "#46493F",
    "inverse-surface": "#E6E2D3", "inverse-on-surface": "#2F312B", "inverse-primary": "#7A5900",
    "scrim": "#000000", "shadow": "#000000",
    "moss": "#74A87A", "lake": "#5C959F", "rust": "#C9714F", "brass": "#E0AB59", "badge": "#E5484D",
}
LIGHT = {
    "primary": "#7A5900", "on-primary": "#FFFFFF", "primary-container": "#FFDEA6", "on-primary-container": "#261900",
    "secondary": "#55624C", "on-secondary": "#FFFFFF", "secondary-container": "#D8E7CB", "on-secondary-container": "#131F0D",
    "tertiary": "#36656C", "on-tertiary": "#FFFFFF", "tertiary-container": "#BAEBF3", "on-tertiary-container": "#001F23",
    "error": "#BA1A1A", "on-error": "#FFFFFF", "error-container": "#FFDAD6", "on-error-container": "#410002",
    "surface": "#FCF8EF", "surface-dim": "#DDD9CF", "surface-bright": "#FCF8EF",
    "surface-container-lowest": "#FFFFFF", "surface-container-low": "#F6F2E9", "surface-container": "#F0ECE3",
    "surface-container-high": "#EBE7DD", "surface-container-highest": "#E5E1D8",
    "on-surface": "#1D1C16", "on-surface-variant": "#4B4739", "outline": "#7C7768", "outline-variant": "#CDC6B4",
    "inverse-surface": "#32302A", "inverse-on-surface": "#F5F0E6", "inverse-primary": "#F1BD6C",
    "scrim": "#000000", "shadow": "#000000",
    "moss": "#4F7D56", "lake": "#2F6A74", "rust": "#A4502F", "brass": "#9A6D1E", "badge": "#D92D20",
}
# Type scale (Material 3, sp): role -> (size, line height, weight, tracking in px)
TYPE = {
    "display-large": (57, 64, 400, -0.25), "display-medium": (45, 52, 400, 0), "display-small": (36, 44, 400, 0),
    "headline-large": (32, 40, 400, 0), "headline-medium": (28, 36, 400, 0), "headline-small": (24, 32, 400, 0),
    "title-large": (22, 28, 400, 0), "title-medium": (16, 24, 500, 0.15), "title-small": (14, 20, 500, 0.1),
    "body-large": (16, 24, 400, 0.5), "body-medium": (14, 20, 400, 0.25), "body-small": (12, 16, 400, 0.4),
    "label-large": (14, 20, 500, 0.1), "label-medium": (12, 16, 500, 0.5), "label-small": (11, 16, 500, 0.5),
}


def esc(s):
    return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def render(svg, w=None, h=None, path=None, bg=None):
    """Render SVG markup with resvg; returns a PIL RGBA image and optionally saves it."""
    kw = dict(svg_string=svg, font_files=FONT_FILES, skip_system_fonts=True, font_family="Roboto",
              sans_serif_family="Roboto", monospace_family="Roboto Mono", resources_dir=GODOT)
    if w: kw["width"] = int(w)
    if h: kw["height"] = int(h)
    if bg: kw["background"] = bg
    png = bytes(resvg_py.svg_to_bytes(**kw))
    im = Image.open(io.BytesIO(png)).convert("RGBA")
    if path:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if path.lower().endswith(".jpg"):
            im.convert("RGB").save(path, quality=90)
        else:
            im.save(path, optimize=True)
    return im


def save_svg(path, svg):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(svg)


def rel(path):
    return os.path.relpath(path, GODOT).replace("\\", "/")


def note(path, w, h, nine=None, text=""):
    MANIFEST.append((rel(path), w, h, nine, text))


# ------------------------------------------------------------------ icon library access
_sym_cache = {}


def sym_paths(name, setname="material", filled=False):
    """Return (viewBox tuple, inner svg markup) of a downloaded icon."""
    key = (name, setname, filled)
    if key in _sym_cache:
        return _sym_cache[key]
    p = os.path.join(SVGLIB, setname, "filled" if filled else "", name + ".svg")
    if not os.path.exists(p):
        p = os.path.join(SVGLIB, setname, name + ".svg")
    txt = open(p, encoding="utf-8").read()
    vb = tuple(float(v) for v in re.search(r'viewBox="([^"]+)"', txt).group(1).split())
    inner = re.sub(r"^.*?<svg[^>]*>", "", txt, flags=re.S)
    inner = re.sub(r"</svg>\s*$", "", inner, flags=re.S)
    root_attr = re.search(r"<svg([^>]*)>", txt, flags=re.S).group(1)
    stroke = None
    m = re.search(r'stroke-width="([\d.]+)"', root_attr)
    if 'stroke="currentColor"' in root_attr or "stroke=\"currentColor\"" in txt[:400]:
        stroke = float(m.group(1)) if m else 2.0
    _sym_cache[key] = (vb, inner, stroke)
    return _sym_cache[key]


def sym(name, x, y, size, colour, setname="material", filled=False, stroke_w=None, opacity=1.0):
    """Place an icon from the library with its top-left at (x, y), `size` square, tinted `colour`."""
    vb, inner, stroke = sym_paths(name, setname, filled)
    s = size / vb[2]
    tr = f"translate({x:.2f},{y:.2f}) scale({s:.5f}) translate({-vb[0]:.2f},{-vb[1]:.2f})"
    inner = inner.replace("currentColor", colour)
    if stroke is not None:   # stroked sets (Lucide, Tabler): keep a stroke that reads at the target size
        sw = stroke_w if stroke_w is not None else stroke
        return (f'<g transform="{tr}" fill="none" stroke="{colour}" stroke-width="{sw}" stroke-linecap="round" '
                f'stroke-linejoin="round" opacity="{opacity}">{inner}</g>')
    return f'<g transform="{tr}" fill="{colour}" opacity="{opacity}">{inner}</g>'


_uri_cache = {}


def data_uri(href, max_px=None):
    """Embed a local image (path relative to godot/ or absolute) as a data URI; resvg needs no file access then."""
    if href.startswith("data:"):
        return href
    if href in _uri_cache:
        return _uri_cache[href]
    import base64
    p = href if os.path.isabs(href) else os.path.join(GODOT, href)
    ext = os.path.splitext(p)[1].lower()
    mime = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".svg": "image/svg+xml"}[ext]
    data = open(p, "rb").read()
    _uri_cache[href] = f"data:{mime};base64," + base64.b64encode(data).decode()
    return _uri_cache[href]


# ------------------------------------------------------------------ SVG builder in dp
class Svg:
    def __init__(self, w_dp, h_dp, px_w=None, px_h=None):
        self.w, self.h = w_dp, h_dp
        self.px_w, self.px_h = px_w or w_dp, px_h or h_dp
        self.defs, self.body = [], []
        self._id = 0

    def uid(self, p="i"):
        self._id += 1
        return f"{p}{self._id}"

    def add(self, s):
        self.body.append(s)
        return self

    def rect(self, x, y, w, h, fill, r=0, stroke=None, sw=1, opacity=1.0, extra=""):
        st = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
        return self.add(f'<rect x="{x:.2f}" y="{y:.2f}" width="{w:.2f}" height="{h:.2f}" rx="{r}" fill="{fill}"{st} opacity="{opacity}" {extra}/>')

    def circle(self, cx, cy, r, fill, stroke=None, sw=1, opacity=1.0):
        st = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
        return self.add(f'<circle cx="{cx:.2f}" cy="{cy:.2f}" r="{r:.2f}" fill="{fill}"{st} opacity="{opacity}"/>')

    def text(self, x, y, s, size=14, fill="#fff", weight=400, anchor="start", family="Roboto", opacity=1.0,
             tracking=0.0, halo=None):
        fam = "Roboto Mono" if family == "mono" else family
        ls = f' letter-spacing="{tracking}"' if tracking else ""
        h = ""
        if halo:
            h = (f'<text x="{x:.2f}" y="{y:.2f}" font-family="{fam}" font-size="{size}" font-weight="{weight}" '
                 f'text-anchor="{anchor}" fill="none" stroke="{halo[0]}" stroke-width="{halo[1]}" stroke-linejoin="round"'
                 f'{ls} opacity="{opacity}">{esc(s)}</text>')
        return self.add(h + f'<text x="{x:.2f}" y="{y:.2f}" font-family="{fam}" font-size="{size}" font-weight="{weight}" '
                        f'text-anchor="{anchor}" fill="{fill}"{ls} opacity="{opacity}">{esc(s)}</text>')

    def t(self, x, y, s, role, fill, anchor="start", opacity=1.0, halo=None):
        size, _lh, wt, tr = TYPE[role]
        return self.text(x, y, s, size, fill, wt, anchor, tracking=tr, opacity=opacity, halo=halo)

    def image(self, x, y, w, h, href, preserve="xMidYMid slice", opacity=1.0, clip=None):
        cp = f' clip-path="url(#{clip})"' if clip else ""
        href = data_uri(href)
        return self.add(f'<image x="{x:.2f}" y="{y:.2f}" width="{w:.2f}" height="{h:.2f}" href="{href}" '
                        f'preserveAspectRatio="{preserve}" opacity="{opacity}"{cp}/>')

    def icon(self, name, x, y, size, colour, setname="material", filled=False, opacity=1.0, stroke_w=None):
        return self.add(sym(name, x, y, size, colour, setname, filled, stroke_w, opacity))

    def shadow(self, level=1):
        """Return a filter id for M3 elevation level 1..5 (key + ambient shadow)."""
        fid = f"elev{level}"
        if not any(fid in d for d in self.defs):
            dy, blur, a = {1: (1, 1.5, 0.30), 2: (2, 3, 0.30), 3: (4, 5, 0.32), 4: (6, 7, 0.34), 5: (8, 10, 0.36)}[level]
            self.defs.append(f'<filter id="{fid}" x="-30%" y="-30%" width="160%" height="170%">'
                             f'<feDropShadow dx="0" dy="{dy}" stdDeviation="{blur}" flood-color="#000" flood-opacity="{a}"/>'
                             f'<feDropShadow dx="0" dy="{dy/3:.1f}" stdDeviation="{blur/3:.1f}" flood-color="#000" flood-opacity="0.2"/></filter>')
        return fid

    def lin(self, stops, x1=0, y1=0, x2=0, y2=1):
        gid = self.uid("g")
        st = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops)
        self.defs.append(f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{st}</linearGradient>')
        return f"url(#{gid})"

    def clip_rect(self, x, y, w, h, r=0):
        cid = self.uid("c")
        self.defs.append(f'<clipPath id="{cid}"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}"/></clipPath>')
        return cid

    def clip_circle(self, cx, cy, r):
        cid = self.uid("c")
        self.defs.append(f'<clipPath id="{cid}"><circle cx="{cx}" cy="{cy}" r="{r}"/></clipPath>')
        return cid

    def group(self, inner, transform="", opacity=1.0, filt=None, clip=None):
        f = f' filter="url(#{filt})"' if filt else ""
        c = f' clip-path="url(#{clip})"' if clip else ""
        return self.add(f'<g transform="{transform}" opacity="{opacity}"{f}{c}>{inner}</g>')

    def markup(self):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
                f'width="{self.px_w}" height="{self.px_h}" viewBox="0 0 {self.w} {self.h}">'
                f'<defs>{"".join(self.defs)}</defs>{"".join(self.body)}</svg>')

    def save(self, path, svg_path=None):
        m = self.markup()
        if svg_path:
            save_svg(svg_path, m)
        return render(m, self.px_w, self.px_h, path)

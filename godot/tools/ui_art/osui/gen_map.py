"""Map app symbology (lane osui): style tokens, POI markers, pins, location puck, controls, plus a reference renderer
that draws the valley the way the Map app should (used for the mock renders and as the implementation reference).

Outputs (assets/ui/osui/map/):
  map_style.json                      colour tokens and road widths per zoom, light ("Valley") and dark ("Night")
  poi/<px>/<icon>.png                 white POI glyphs from Maki/Temaki (CC0), 14/18/24/36 px
  marker/<category>_<icon>.png        2x composited POI markers (22 dp circle + glyph), 44 x 44 px
  pin/*.png                           launch-site pins, dropped pin, drone marker (2x, pivot = bottom tip / centre)
  puck/*.png                          my-location dot, accuracy ring, heading cone (2x)
  control/*.png                       compass, zoom, recentre, layers, scale bar ends (2x)
The base raster is computed from the real world data (heightmap, cover map, lake mask, road routes, village layout)
in the notify lane; B builds the same layers in GDScript (see the MAP STYLE section of the spec).
"""
import os, json, math, zlib
import numpy as np
from PIL import Image, ImageFilter
import osui_lib as L

OUT = os.path.join(L.OUT, "map")
WORLD = os.path.normpath(os.path.join(L.GODOT, "..", "..", "AeroSim-notify", "godot", "assets", "world"))
SIZE_M = 4000.0

STYLE = {
    "light": {
        "land": "#F4F0E6", "farmland": "#EEE8D3", "lawn": "#CFE5BD", "park": "#C6E2B3", "forest": "#B3D69F",
        "cemetery": "#D6E4C9", "builtup": "#EDE7DB", "building": "#E2DBCC", "building_stroke": "#CFC6B4",
        "water": "#A3D3EA", "water_stroke": "#8CC2DC", "water_label": "#2E6F8F", "contour": "#D9CDB2",
        "contour_index": "#C7B794", "hillshade_strength": 0.20,
        "road_highway": "#FBE29A", "road_highway_casing": "#E0B85E", "road_secondary": "#FFFFFF",
        "road_secondary_casing": "#D3CBB8", "road_lane": "#FFFFFF", "road_lane_casing": "#DAD3C3",
        "path": "#A99877", "track": "#B79E73", "label": "#4C473C", "label_halo": "#FFFFFF", "place_label": "#3A362D",
        "route": "#3E86F5", "route_casing": "#2462C9", "route_alt": "#A8B9D3", "route_walk": "#3E86F5",
        "location": "#3E86F5", "location_ring": "#FFFFFF", "accuracy_fill": "#3E86F5", "accuracy_fill_opacity": 0.14,
    },
    "dark": {
        "land": "#1D221E", "farmland": "#22271F", "lawn": "#223123", "park": "#213222", "forest": "#1D3020",
        "cemetery": "#253226", "builtup": "#262A25", "building": "#30352F", "building_stroke": "#3B4139",
        "water": "#173A47", "water_stroke": "#1F4B5B", "water_label": "#7FB6C9", "contour": "#2D332B",
        "contour_index": "#3A4237", "hillshade_strength": 0.30,
        "road_highway": "#7A6538", "road_highway_casing": "#2A2A22", "road_secondary": "#4E534A",
        "road_secondary_casing": "#23271F", "road_lane": "#434840", "road_lane_casing": "#23271F",
        "path": "#6E6550", "track": "#6E6550", "label": "#C8C4B0", "label_halo": "#121512", "place_label": "#E6E0CB",
        "route": "#6AA7FF", "route_casing": "#1F4E9C", "route_alt": "#4C5A70", "route_walk": "#6AA7FF",
        "location": "#6AA7FF", "location_ring": "#FFFFFF", "accuracy_fill": "#6AA7FF", "accuracy_fill_opacity": 0.18,
    },
}
# road class per game route id, with the real carriageway width in metres (Roads.ROUTES)
ROAD_CLASS = {"valley": "highway", "ridge": "highway", "east_link": "secondary", "south_lane": "secondary",
              "village": "lane", "lake": "lane", "west_link": "lane", "launch": "lane"}
# minimum on-screen widths in dp by zoom (zoom 0 = whole 4 km valley on screen; each step doubles scale)
WIDTH_DP = {   # zoom: (highway, secondary, lane, path) fill widths; casing adds 2 dp total
    13: (2.5, 1.6, 1.0, 0), 14: (3.5, 2.4, 1.6, 0.8), 15: (5.0, 3.5, 2.6, 1.0),
    16: (7.0, 5.0, 4.0, 1.2), 17: (10.0, 7.5, 6.0, 1.5), 18: (16.0, 12.0, 10.0, 2.0),
}
CATEGORIES = {   # category: colour, Maki/Temaki icons in it
    "food": ("#E37C2D", ["cafe", "restaurant", "beer", "bar"]),
    "shop": ("#4D7CC7", ["shop", "grocery", "post"]),
    "lodging": ("#C25488", ["lodging", "campsite"]),
    "outdoors": ("#3E8E57", ["park", "picnic-site", "viewpoint", "playground", "garden", "dog-park"]),
    "transport": ("#3F7FB5", ["bus", "rail", "ferry", "parking", "fuel", "harbor", "slipway"]),
    "emergency": ("#D04B4B", ["police", "hospital", "fire-station"]),
    "civic": ("#7E6FC4", ["town-hall", "library", "school", "information"]),
    "worship": ("#77808A", ["place-of-worship", "religious-christian", "cemetery", "monument"]),
    "farm": ("#8F7A35", ["farm", "barn", "silo", "windmill", "water_tower"]),
    "water": ("#2F86A8", ["boat_ramp", "boating", "fishing_pier", "pier_fixed", "swimming"]),
    "story": ("#C8902F", ["marker", "attraction"]),
}


def _hex(c):
    c = c.lstrip("#")
    return np.array([int(c[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32) / 255.0


_height = None


def height():
    global _height
    if _height is None:
        raw = open(os.path.join(WORLD, "valley_height.bin"), "rb").read()
        lay = json.load(open(os.path.join(WORLD, "layout.json")))
        n = lay["n"]
        h = np.frombuffer(zlib.decompress(raw), dtype="<u2").astype(np.float32).reshape(n, n)
        _height = lay["hmin"] + (lay["hmax"] - lay["hmin"]) * h / 65535.0
    return _height


def _sample(arr, xs, zs):
    """Bilinear sample of a world-covering grid over the regular grid xs (columns) by zs (rows)."""
    n = arr.shape[0]
    src = Image.fromarray(arr.astype(np.float32), "F")
    l, r = (xs[0] + SIZE_M / 2) / SIZE_M * n, (xs[-1] + SIZE_M / 2) / SIZE_M * n
    t, b = (zs[0] + SIZE_M / 2) / SIZE_M * n, (zs[-1] + SIZE_M / 2) / SIZE_M * n
    out = src.transform((len(xs), len(zs)), Image.EXTENT, (l, t, r, b), Image.BILINEAR)
    return np.asarray(out, dtype=np.float32)

def base_raster(x0, z0, x1, z1, w_px, h_px, theme="light"):
    """Land cover + water + hillshade + contours for the world rect (x0,z0)-(x1,z1), as an RGB PIL image."""
    S = STYLE[theme]
    xs = np.linspace(x0, x1, w_px)
    zs = np.linspace(z0, z1, h_px)
    cov = np.asarray(Image.open(os.path.join(WORLD, "valley_cover.png")).convert("RGBA")).astype(np.float32) / 255.0
    wood = _sample(cov[..., 0], xs, zs)
    lawn = _sample(cov[..., 2], xs, zs)
    lake = np.asarray(Image.open(os.path.join(WORLD, "lake_mask.png")).convert("L").filter(ImageFilter.GaussianBlur(1.6))).astype(np.float32) / 255.0
    water = _sample(lake, xs, zs)
    water = np.clip((water - 0.5) * 6.0 + 0.5, 0, 1)   # crisp shoreline from the soft 512 px mask
    hgt = _sample(height(), xs, zs)
    img = np.ones((h_px, w_px, 3), np.float32) * _hex(S["farmland"])
    img = img * (1 - lawn[..., None] * 0.9) + _hex(S["lawn"]) * lawn[..., None] * 0.9
    img = img * (1 - wood[..., None]) + _hex(S["forest"]) * wood[..., None]
    # hillshade from the heightmap (sun from the north-west, as on printed maps)
    gy, gx = np.gradient(hgt, (z1 - z0) / h_px, (x1 - x0) / w_px)
    nrm = np.dstack([-gx, np.ones_like(gx), -gy])
    nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
    sun = np.array([-0.55, 0.65, -0.52]); sun /= np.linalg.norm(sun)
    shade = np.clip(nrm @ sun, 0, 1)
    k = S["hillshade_strength"]
    img *= (1 - k + k * (shade[..., None] / max(sun[1], 0.01)))
    # contours every 10 m, index every 50 m
    for step, col, wid in ((10.0, S["contour"], 0.55), (50.0, S["contour_index"], 0.9)):
        f = hgt / step
        d = np.abs(f - np.round(f)) * step
        g = np.hypot(gx, gy) * ((x1 - x0) / w_px) + 1e-4
        line = np.clip(1.0 - d / (g * 1.2 + 1e-3), 0, 1) * wid
        line *= (1 - water)
        img = img * (1 - line[..., None]) + _hex(col) * line[..., None]
    img = img * (1 - water[..., None]) + _hex(S["water"]) * water[..., None]
    out = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGB")
    return out


def routes():
    """Road centrelines from roads.gd ROUTES (copied values; B reads Roads.paths at runtime instead)."""
    return {
        "valley": [(270, 42), (280, 110), (286, 180), (286, 260), (270, 360), (240, 440), (215, 505)],
        "south_lane": [(286, 260), (200, 255), (100, 252), (17, 250)],
        "village": [(286, 260), (320, 258), (370, 262), (420, 270), (455, 276)],
        "east_link": [(270, 42), (276, -60), (276, -170), (260, -245), (150, -255), (12, -255)],
        "ridge": [(12, -255), (30, -320), (48, -420), (58, -520), (55, -600), (45, -760), (36, -900), (36, -1120)],
        "lake": [(215, 505), (90, 470), (-80, 420), (-200, 360), (-300, 300), (-340, 240), (-380, 180), (-410, 120)],
        "west_link": [(-300, 300), (-292, 200), (-285, 100), (-280, 0), (-252, -4)],
        "launch": [(-410, 120), (-432, 112)],
    }


ROAD_NAMES = {"valley": "Valley Highway", "ridge": "Ridge Road", "east_link": "East Boundary Lane",
              "south_lane": "South Gate Lane", "village": "Village Lane", "lake": "Lakeside Lane",
              "west_link": "West Boundary Lane"}
SITES = [("home", "Cemetery home pad", -18, 36), ("east_gate", "East gate car park", 264, 58),
         ("south_gate", "South gate car park", 34, 246), ("north_ridge", "North gate pull-off", 28, -246),
         ("west_gate", "West gate car park", -247, 8), ("farm", "Toby Farm gate", 188, 512),
         ("lake", "Boat launch", -424, 118), ("garage", "Voss and Son yard", 66, -592),
         ("cabin_track", "Ridge trailhead", 38, -752), ("camp", "Ridge camp", 42, -1108),
         ("festival", "Festival field", 292, 292), ("village", "Halloway village", 438, 268)]
BUILDINGS = [(358, 242, 9.5, 8), (392, 243, 8.5, 7.5), (426, 244, 10, 8), (461, 245, 8, 7), (347, 296, 9, 8),
             (382, 299, 14, 9), (414, 301, 10, 8), (443, 303, 8.5, 7.5), (477, 306, 12, 9), (188, 126, 9, 16)]
POIS = [("food", "beer", 382, 299, "The Kestrel"), ("shop", "shop", 414, 301, "Village Stores"),
        ("transport", "bus", 397, 253, "Bus stop"), ("shop", "post", 410, 282, ""),
        ("worship", "cemetery", 0, -150, "Halloway Cemetery"), ("worship", "place-of-worship", 188, 126, "Chapel"),
        ("water", "boat_ramp", -430, 112, "Boat launch"), ("farm", "farm", 200, 540, "Toby Farm"),
        ("transport", "parking", 264, 58, ""), ("transport", "parking", 34, 246, ""), ("transport", "parking", -247, 8, ""),
        ("transport", "fuel", 477, 306, "Voss Garage"), ("outdoors", "viewpoint", 38, -752, "Ridge trailhead"),
        ("lodging", "campsite", 42, -1108, "Ridge camp"), ("outdoors", "picnic-site", 292, 292, "Festival field")]


def poi_glyph(icon):
    for s in ("maki", "temaki"):
        if os.path.exists(os.path.join(L.SVGLIB, s, icon + ".svg")):
            return s
    return "maki"


def marker_svg(cat, icon, d=22):
    col = CATEGORIES[cat][0]
    g = L.sym(icon, d * 0.2, d * 0.2, d * 0.6, "#FFFFFF", poi_glyph(icon))
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{d}" height="{d}" viewBox="-1 -1 {d+2} {d+2}">'
            f'<circle cx="{d/2}" cy="{d/2 + 0.6}" r="{d/2}" fill="#000" opacity="0.18"/>'
            f'<circle cx="{d/2}" cy="{d/2}" r="{d/2 - 0.5}" fill="{col}" stroke="#FFFFFF" stroke-width="1.2"/>{g}</svg>')


def pin_svg(colour, glyph=None, glyph_set="material", inner="#FFFFFF"):
    """Teardrop pin 28 x 38 dp, tip at (14, 37)."""
    g = L.sym(glyph, 6.5, 5.5, 15, inner, glyph_set, glyph_set == "material") if glyph else f'<circle cx="14" cy="13" r="5" fill="{inner}"/>'
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="28" height="38" viewBox="0 0 28 38">'
            '<ellipse cx="14" cy="36.5" rx="4.5" ry="1.4" fill="#000" opacity="0.25"/>'
            f'<path d="M14 36 C9 29.5 2 22 2 13.5 A12 12 0 0 1 26 13.5 C26 22 19 29.5 14 36 Z" fill="{colour}" stroke="#000" stroke-opacity="0.18" stroke-width="1"/>'
            f'{g}</svg>')


def puck_svg(theme="light", heading=True):
    S = STYLE[theme]
    c = S["location"]
    cone = (f'<defs><radialGradient id="cg" cx="40" cy="40" r="38" gradientUnits="userSpaceOnUse"><stop offset="0.15" stop-color="{c}" stop-opacity="0.55"/>'
            f'<stop offset="1" stop-color="{c}" stop-opacity="0"/></radialGradient></defs>'
            f'<path d="M40 40 L{40 + 38*math.sin(math.radians(-30)):.2f} {40 - 38*math.cos(math.radians(-30)):.2f} A38 38 0 0 1 {40 + 38*math.sin(math.radians(30)):.2f} {40 - 38*math.cos(math.radians(30)):.2f} Z" fill="url(#cg)"/>') if heading else ""
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="80" height="80" viewBox="0 0 80 80">' + cone +
            '<circle cx="40" cy="41" r="10" fill="#000" opacity="0.22"/>'
            f'<circle cx="40" cy="40" r="10" fill="{S["location_ring"]}"/><circle cx="40" cy="40" r="7.2" fill="{c}"/></svg>')


def build():
    os.makedirs(OUT, exist_ok=True)
    style = {"version": 1, "notes": "dp widths at 1280x720 logical; colours sRGB; zoom 13 = 1 px per 2 m, each zoom doubles",
             "themes": STYLE, "road_class": ROAD_CLASS, "road_width_dp": {str(k): v for k, v in WIDTH_DP.items()},
             "categories": {k: {"colour": v[0], "icons": v[1]} for k, v in CATEGORIES.items()},
             "labels": {"road": {"size_sp": 11, "weight": 500, "halo_dp": 2, "min_zoom": 15},
                        "place_village": {"size_sp": 15, "weight": 500, "halo_dp": 2.5, "min_zoom": 13},
                        "poi": {"size_sp": 11, "weight": 500, "halo_dp": 1.5, "min_zoom": 16, "colour": "category"},
                        "water": {"size_sp": 12, "weight": 400, "italic": True, "min_zoom": 13},
                        "contour": {"size_sp": 9, "every_m": 50, "min_zoom": 16}}}
    with open(os.path.join(OUT, "map_style.json"), "w", encoding="utf-8") as f:
        json.dump(style, f, indent=1)
    L.note(os.path.join(OUT, "map_style.json"), 0, 0, None, "map style tokens: colours, road widths per zoom, label rules")
    icons = sorted({i for _, (_, ic) in CATEGORIES.items() for i in ic})
    for ic in icons:
        for px in (14, 18, 24, 36):
            svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 {px} {px}">{L.sym(ic, 0, 0, px, "#FFFFFF", poi_glyph(ic))}</svg>'
            L.render(svg, px, px, os.path.join(OUT, "poi", str(px), f"{ic}.png"))
    for cat, (col, ics) in CATEGORIES.items():
        for ic in ics:
            L.render(marker_svg(cat, ic), 48, 48, os.path.join(OUT, "marker", f"{cat}_{ic}.png"))
    L.note(os.path.join(OUT, "poi", "<px>", "<icon>.png"), 0, 0, None, f"{len(icons)} POI glyphs (Maki/Temaki CC0), white, 14/18/24/36")
    L.note(os.path.join(OUT, "marker", "<category>_<icon>.png"), 48, 48, None, "POI marker 22 dp (2x), category colour, white ring")
    pins = {"site_current": ("#E0AB59", "flight_takeoff", "material"), "site_suggested": ("#4F8F5B", "flag", "material"),
            "site_open": ("#6F7468", "location_on", "material"), "site_locked": ("#8C8F88", "lock", "material"),
            "dropped": ("#D93A2E", None, None), "destination": ("#D93A2E", "flag", "material")}
    for n, (c, g, gs) in pins.items():
        L.render(pin_svg(c, g, gs or "material"), 56, 76, os.path.join(OUT, "pin", f"pin_{n}.png"))
        L.save_svg(os.path.join(OUT, "pin", f"pin_{n}.svg"), pin_svg(c, g, gs or "material"))
    L.note(os.path.join(OUT, "pin", "pin_<kind>.png"), 56, 76, None, "pins 28 x 38 dp (2x), pivot = tip at (28, 74) px")
    drone = ('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">'
             '<path d="M16 3 L26 27 L16 21.5 L6 27 Z" fill="#E0573A" stroke="#FFFFFF" stroke-width="2" stroke-linejoin="round"/></svg>')
    L.render(drone, 64, 64, os.path.join(OUT, "pin", "drone_arrow.png"))
    L.note(os.path.join(OUT, "pin", "drone_arrow.png"), 64, 64, None, "drone position arrow, rotate by heading, pivot centre")
    for th in ("light", "dark"):
        L.render(puck_svg(th, True), 160, 160, os.path.join(OUT, "puck", f"location_heading_{th}.png"))
        L.render(puck_svg(th, False), 160, 160, os.path.join(OUT, "puck", f"location_{th}.png"))
        S = STYLE[th]
        acc = (f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><circle cx="64" cy="64" r="62" '
               f'fill="{S["accuracy_fill"]}" fill-opacity="{S["accuracy_fill_opacity"]}" stroke="{S["accuracy_fill"]}" stroke-opacity="0.35" stroke-width="1.5"/></svg>')
        L.render(acc, 256, 256, os.path.join(OUT, "puck", f"accuracy_{th}.png"))
    L.note(os.path.join(OUT, "puck", "location_heading_<theme>.png"), 160, 160, None, "my-location puck 80 dp (2x): dot 20 dp + heading cone 60 deg; pivot centre")
    L.note(os.path.join(OUT, "puck", "accuracy_<theme>.png"), 256, 256, None, "accuracy ring, scale to the accuracy radius in metres")
    # controls
    ctl = {
        "compass": '<circle cx="20" cy="20" r="19" fill="#FFFFFF"/><path d="M20 6 L25 20 H15 Z" fill="#D93A2E"/><path d="M20 34 L25 20 H15 Z" fill="#9AA09A"/>',
        "compass_dark": '<circle cx="20" cy="20" r="19" fill="#282C27"/><path d="M20 6 L25 20 H15 Z" fill="#FF6B5B"/><path d="M20 34 L25 20 H15 Z" fill="#8E928A"/>',
        "zoom": '<rect x="0" y="0" width="40" height="80" rx="8" fill="#FFFFFF"/><path d="M12 20 H28 M20 12 V28 M12 60 H28" stroke="#3E3A31" stroke-width="2.4" stroke-linecap="round"/><path d="M8 40 H32" stroke="#E2DBCC"/>',
        "zoom_dark": '<rect x="0" y="0" width="40" height="80" rx="8" fill="#282C27"/><path d="M12 20 H28 M20 12 V28 M12 60 H28" stroke="#F0E9D1" stroke-width="2.4" stroke-linecap="round"/><path d="M8 40 H32" stroke="#46493F"/>',
        "recentre": '<rect x="0" y="0" width="56" height="56" rx="16" fill="#FFFFFF"/>' + L.sym("my_location", 16, 16, 24, "#3E86F5"),
        "recentre_dark": '<rect x="0" y="0" width="56" height="56" rx="16" fill="#282C27"/>' + L.sym("my_location", 16, 16, 24, "#6AA7FF"),
        "layers": '<circle cx="20" cy="20" r="20" fill="#FFFFFF"/>' + L.sym("layers", 8, 8, 24, "#3E3A31"),
        "layers_dark": '<circle cx="20" cy="20" r="20" fill="#282C27"/>' + L.sym("layers", 8, 8, 24, "#F0E9D1"),
    }
    for n, inner in ctl.items():
        w = 40 if not n.startswith("recentre") else 56
        h = 80 if n.startswith("zoom") else w
        svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="-2 -2 {w+4} {h+4}"><defs><filter id="s"><feDropShadow dx="0" dy="1" stdDeviation="1.4" flood-opacity="0.3"/></filter></defs><g filter="url(#s)">{inner}</g></svg>'
        L.render(svg, (w + 4) * 2, (h + 4) * 2, os.path.join(OUT, "control", f"{n}.png"))
    L.note(os.path.join(OUT, "control", "<name>.png"), 0, 0, None, "map floating controls (2x): compass, zoom, recentre FAB, layers; _dark variants")
    # route line swatch (for docs) and scale bar end cap
    L.render('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="12" viewBox="0 0 96 12"><path d="M4 6 H92" stroke="#2462C9" stroke-width="9" stroke-linecap="round"/><path d="M4 6 H92" stroke="#3E86F5" stroke-width="6" stroke-linecap="round"/></svg>',
             192, 24, os.path.join(OUT, "control", "route_swatch.png"))
    return icons


def overlay(s, x0, z0, ppm, ox, oy, theme="light", zoom=15, labels=True, dp_scale=1.0):
    """Draw roads, buildings, POIs and labels into Svg `s` (dp space). World (x,z) -> (ox + (x-x0)*ppm, oy + (z-z0)*ppm)."""
    S = STYLE[theme]
    P = lambda x, z: (ox + (x - x0) * ppm, oy + (z - z0) * ppm)
    wd = WIDTH_DP[zoom]
    real = {"valley": 8, "ridge": 7, "east_link": 6, "south_lane": 5.5, "village": 5, "lake": 5, "west_link": 5, "launch": 4.5}
    R = routes()
    order = ["lane", "secondary", "highway"]
    # park paths (dashed)
    try:
        lay = json.load(open(os.path.join(WORLD, "layout.json")))
        for p in lay["paths"]:
            pts = " ".join("%.1f,%.1f" % P(q[0], q[1]) for q in p["pts"][::3])
            s.add(f'<polyline points="{pts}" fill="none" stroke="{S["path"]}" stroke-width="{max(wd[3],0.8)}" stroke-dasharray="3 2.5" opacity="0.9"/>')
    except Exception:
        pass
    for layer in ("casing", "fill"):
        for cls in order:
            for rid, pts in R.items():
                if ROAD_CLASS[rid] != cls:
                    continue
                w = max(wd[order.index(cls) if False else {"highway": 0, "secondary": 1, "lane": 2}[cls]], real[rid] * ppm)
                d = "M" + " L".join("%.1f %.1f" % P(*p) for p in pts)
                col = S[f"road_{cls}_casing"] if layer == "casing" else S[f"road_{cls}"]
                ww = w + 2.0 if layer == "casing" else w
                s.add(f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{ww:.2f}" stroke-linecap="round" stroke-linejoin="round"/>')
    # cemetery wall
    a, b = P(-238, -238), P(238, 238)
    s.add(f'<rect x="{a[0]:.1f}" y="{a[1]:.1f}" width="{b[0]-a[0]:.1f}" height="{b[1]-a[1]:.1f}" fill="{S["cemetery"]}" fill-opacity="0.35" stroke="{S["building_stroke"]}" stroke-width="0.8"/>')
    # buildings
    for x, z, w, d2 in BUILDINGS:
        c = P(x - w / 2, z - d2 / 2)
        s.add(f'<rect x="{c[0]:.1f}" y="{c[1]:.1f}" width="{w*ppm:.1f}" height="{d2*ppm:.1f}" fill="{S["building"]}" stroke="{S["building_stroke"]}" stroke-width="0.6"/>')
    if not labels:
        return
    halo = (S["label_halo"], 2.6)
    # road labels at the midpoint of the longest segment
    for rid, name in ROAD_NAMES.items():
        pts = R[rid]
        best = max(range(len(pts) - 1), key=lambda i: math.dist(pts[i], pts[i + 1]))
        (xa, za), (xb, zb) = pts[best], pts[best + 1]
        pa, pb = P(xa, za), P(xb, zb)
        ang = math.degrees(math.atan2(pb[1] - pa[1], pb[0] - pa[0]))
        if ang > 90: ang -= 180
        if ang < -90: ang += 180
        mx, my = (pa[0] + pb[0]) / 2, (pa[1] + pb[1]) / 2
        s.add(f'<g transform="translate({mx:.1f} {my:.1f}) rotate({ang:.1f})">'
              f'<text x="0" y="3.6" font-family="Roboto" font-size="{10.5*dp_scale}" font-weight="500" text-anchor="middle" fill="none" stroke="{halo[0]}" stroke-width="{halo[1]}" stroke-linejoin="round">{name}</text>'
              f'<text x="0" y="3.6" font-family="Roboto" font-size="{10.5*dp_scale}" font-weight="500" text-anchor="middle" fill="{S["label"]}">{name}</text></g>')
    v = P(421, 272)
    s.text(v[0], v[1] - 44, "Halloway", 15 * dp_scale, S["place_label"], 500, "middle", halo=halo)
    lk = P(-560, 40)
    s.add(f'<text x="{lk[0]:.1f}" y="{lk[1]:.1f}" font-family="Roboto" font-style="italic" font-size="{12*dp_scale}" text-anchor="middle" fill="{S["water_label"]}">Halloway Lake</text>')
    placed = []   # simple label collision, the way a real map drops lower-priority POIs
    for cat, ic, x, z, name in POIS:
        p = P(x, z)
        tw = len(name) * 6.0 * dp_scale
        box = (p[0] - 11, p[1] - 11, p[0] + 16 + tw, p[1] + 11)
        if any(not (box[2] < b[0] or box[0] > b[2] or box[3] < b[1] or box[1] > b[3]) for b in placed):
            continue
        placed.append(box)
        s.add(f'<g transform="translate({p[0]-11:.1f} {p[1]-11:.1f})">' + marker_svg(cat, ic).split(">", 1)[1].rsplit("</svg>", 1)[0] + "</g>")
        if name:
            s.text(p[0] + 14, p[1] + 4, name, 11 * dp_scale, CATEGORIES[cat][0], 500, "start", halo=(S["label_halo"], 2.4))


if __name__ == "__main__":
    print(len(build()), "poi icons")

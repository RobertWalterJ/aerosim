"""One consistent DJI-style icon set for the flight HUD (lane osui).

Grid: 24 x 24 dp, 2 dp padding (live area 20 dp), stroke 1.75 dp, round caps and joins, white on transparent.
Glyphs that carry letters (AF, MF, EV, WB, ISO, mode letters) use Roboto Medium and are shipped as PNG; their SVG
sources contain <text>, which Godot's SVG importer does not render reliably, so B must load the PNGs for those.

Outputs (assets/ui/osui/hud/):
  glyph/<name>.svg                  vector source, 24 x 24
  glyph/<px>/<name>.png             white glyph, px in 24, 32, 48, 96 (modulate in code)
  button/<state>/<px>/<name>.png    pre-composited round button, state in default, pressed, active, disabled,
                                    px in 40, 48, 56, 64, 96, 128 (button diameter; glyph is 50 percent of it)
  pill/handle_*.png                 the pull-up handle for the camera drawer
"""
import os
import osui_lib as L

OUT = os.path.join(L.OUT, "hud")
S = 'fill="none" stroke="#FFF" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"'
F = 'fill="#FFF"'


def txt(s, size=8.2, y=15.0, x=12, weight=700):
    return (f'<text x="{x}" y="{y}" font-family="Roboto" font-weight="{weight}" font-size="{size}" '
            f'text-anchor="middle" fill="#FFF">{s}</text>')


def quad(cx=12, cy=11, k=1.0):
    ox, oy, r = 5.0 * k, 3.6 * k, 2.4 * k
    return (f'<g {S} style="stroke-width:{1.5 if k < 0.95 else 1.75}"><path d="M{cx-ox} {cy-oy} L{cx+ox} {cy+oy} M{cx+ox} {cy-oy} L{cx-ox} {cy+oy}"/>'
            f'<ellipse cx="{cx-ox}" cy="{cy-oy}" rx="{r}" ry="{r*0.62}"/><ellipse cx="{cx+ox}" cy="{cy-oy}" rx="{r}" ry="{r*0.62}"/>'
            f'<ellipse cx="{cx-ox}" cy="{cy+oy}" rx="{r}" ry="{r*0.62}"/><ellipse cx="{cx+ox}" cy="{cy+oy}" rx="{r}" ry="{r*0.62}"/></g>'
            f'<rect x="{cx-2*k}" y="{cy-1.6*k}" width="{4*k}" height="{3.2*k}" rx="1" {F}/>')

G = {
    # flight
    "takeoff": quad(12, 15.6, 0.9) + f'<path {S} d="M12 9.2 V2.8 M9.2 5.4 L12 2.6 L14.8 5.4"/>',
    "land": quad(12, 7.2, 0.9) + f'<path {S} d="M12 12.6 V19 M9.2 16.4 L12 19.2 L14.8 16.4"/><path {S} d="M5 21.2 H19"/>',
    "rth": f'<path {S} d="M4 11 L12 4 L20 11 M6.2 9.4 V20 H17.8 V9.4"/>' + txt("H", 7.6, 17.8),
    "rth_cancel": f'<path {S} d="M4 11 L12 4 L20 11 M6.2 9.4 V20 H17.8 V9.4 M9.5 12.5 L14.5 17.5 M14.5 12.5 L9.5 17.5"/>',
    "hover": quad(12, 10, 1.15) + f'<path {S} d="M6 19 H18" stroke-dasharray="2 2.2"/>',
    "brake": f'<rect x="4.5" y="4.5" width="15" height="15" rx="4" {S}/><path {S} d="M9.5 9 V15 M14.5 9 V15"/>',
    # views
    "view_fpv": f'<path {S} d="M2.8 12 C5.5 7 9 5.4 12 5.4 S18.5 7 21.2 12 C18.5 17 15 18.6 12 18.6 S5.5 17 2.8 12 Z"/><circle cx="12" cy="12" r="3.2" {S}/>',
    "view_chase": quad(12, 8.5, 0.95) + f'<path {S} d="M3 20 L8 15.5 M21 20 L16 15.5"/><path {S} d="M8.5 20 H15.5" stroke-dasharray="1.5 2"/>',
    "view_map": f'<path {S} d="M3.5 6 L9 4 L15 6 L20.5 4 V18 L15 20 L9 18 L3.5 20 Z M9 4 V18 M15 6 V20"/>',
    "view_swap": f'<rect x="3" y="5" width="12" height="9" rx="2" {S}/><rect x="9" y="10" width="12" height="9" rx="2" {S}/>',
    # camera capture
    "photo": f'<path {S} d="M3.5 8.5 A2 2 0 0 1 5.5 6.5 H8 L9.6 4.5 H14.4 L16 6.5 H18.5 A2 2 0 0 1 20.5 8.5 V17.5 A2 2 0 0 1 18.5 19.5 H5.5 A2 2 0 0 1 3.5 17.5 Z"/><circle cx="12" cy="12.8" r="3.6" {S}/>',
    "video": f'<rect x="2.8" y="6.5" width="12.8" height="11" rx="2.4" {S}/><path {S} d="M15.6 10.2 L21 7.5 V16.5 L15.6 13.8"/>',
    "record": f'<circle cx="12" cy="12" r="8.2" {S}/><circle cx="12" cy="12" r="4.6" fill="#FFF"/>',
    "stop": f'<circle cx="12" cy="12" r="8.2" {S}/><rect x="8.6" y="8.6" width="6.8" height="6.8" rx="1.4" fill="#FFF"/>',
    "playback": f'<rect x="3.5" y="4.5" width="17" height="15" rx="2.5" {S}/><path d="M10 9 L15.5 12 L10 15 Z" fill="#FFF" stroke="#FFF" stroke-width="1" stroke-linejoin="round"/>',
    "photo_video": f'<path {S} d="M3 7.5 H11 V15 H3 Z M11 10 L14 8.4 V14.1 L11 12.5"/><circle cx="17.5" cy="15.5" r="3.4" {S}/>',
    # camera add-ons and image
    "thermal": f'<rect x="3.5" y="4.5" width="17" height="15" rx="3" {S}/><path {S} style="stroke-width:1.5" d="M8 16.5 C6.6 14.8 9.4 13.2 8 11.5 S9.4 8.2 8 6.8 M12 16.5 C10.6 14.8 13.4 13.2 12 11.5 S13.4 8.2 12 6.8 M16 16.5 C14.6 14.8 17.4 13.2 16 11.5 S17.4 8.2 16 6.8"/>',
    "night": f'<path {S} d="M3 11.5 A3 3 0 0 1 6 8.5 H18 A3 3 0 0 1 21 11.5 V14 A3.5 3.5 0 0 1 17.5 17.5 H15 L13.4 15.4 H10.6 L9 17.5 H6.5 A3.5 3.5 0 0 1 3 14 Z"/><circle cx="7.6" cy="12.9" r="2.1" {S} style="stroke-width:1.5"/><circle cx="16.4" cy="12.9" r="2.1" {S} style="stroke-width:1.5"/><path {S} d="M12 8.5 V4.5 M9.5 4.5 H14.5"/>',
    "light": f'<path {S} d="M11 5.5 C6.5 5.5 4 8.5 4 12 S6.5 18.5 11 18.5 Z"/><path {S} d="M14.5 7 L20.5 6 M14.5 10.4 L20.5 10 M14.5 13.6 L20.5 14 M14.5 17 L20.5 18"/>',
    "af": f'<path {S} d="M3.5 8 V5.5 A2 2 0 0 1 5.5 3.5 H8 M16 3.5 H18.5 A2 2 0 0 1 20.5 5.5 V8 M20.5 16 V18.5 A2 2 0 0 1 18.5 20.5 H16 M8 20.5 H5.5 A2 2 0 0 1 3.5 18.5 V16"/>' + txt("AF", 7.4, 14.7),
    "mf": f'<path {S} d="M3.5 8 V5.5 A2 2 0 0 1 5.5 3.5 H8 M16 3.5 H18.5 A2 2 0 0 1 20.5 5.5 V8 M20.5 16 V18.5 A2 2 0 0 1 18.5 20.5 H16 M8 20.5 H5.5 A2 2 0 0 1 3.5 18.5 V16"/>' + txt("MF", 7.4, 14.7),
    "ev": f'<rect x="3.5" y="3.5" width="17" height="17" rx="3" {S}/><path {S} d="M6.5 8.5 H10.5 M8.5 6.5 V10.5 M13.5 15.5 H17.5 M17.5 6.5 L6.5 17.5"/>',
    "wb": f'<rect x="3.5" y="5" width="17" height="14" rx="3" {S}/>' + txt("WB", 7.2, 14.6),
    "iso": f'<rect x="3.5" y="5" width="17" height="14" rx="3" {S}/>' + txt("ISO", 6.2, 14.3),
    "lens_wide": f'<path {S} d="M3 7 C9 4.5 15 4.5 21 7 V17 C15 19.5 9 19.5 3 17 Z"/><path {S} d="M9 12 H15 M7.5 12 L9.5 10 M7.5 12 L9.5 14 M16.5 12 L14.5 10 M16.5 12 L14.5 14"/>',
    "lens_standard": f'<rect x="4" y="6" width="16" height="12" rx="2.5" {S}/><circle cx="12" cy="12" r="3.2" {S}/>',
    "gimbal": f'<path {S} d="M12 3.5 V7 M8 7 H16 V10.5"/><rect x="7.5" y="10.5" width="9" height="7" rx="2" {S}/><circle cx="12" cy="14" r="1.6" fill="#FFF"/><path {S} d="M5 13 A7.5 7.5 0 0 0 8 20 M19 13 A7.5 7.5 0 0 1 16 20"/>',
    "focus_point": f'<circle cx="12" cy="12" r="1.6" fill="#FFF"/><path {S} d="M4 8.5 V4 H8.5 M15.5 4 H20 V8.5 M20 15.5 V20 H15.5 M8.5 20 H4 V15.5"/>',
    "histogram": f'<path {S} d="M3.5 20 H20.5"/><path d="M4.5 19 V16 L7 12 L9.5 14 L12 7 L14.5 11 L17 9 L19.5 15 V19 Z" fill="#FFF" opacity="0.85"/>',
    "grid": f'<rect x="3.5" y="3.5" width="17" height="17" rx="2.5" {S}/><path {S} d="M9.2 3.5 V20.5 M14.8 3.5 V20.5 M3.5 9.2 H20.5 M3.5 14.8 H20.5"/>',
    # system / utility
    "back": f'<path {S} d="M14.8 4.8 L7.6 12 L14.8 19.2"/>',
    "settings": f'<circle cx="12" cy="12" r="3" {S}/><path {S} d="M12 2.8 L13.6 5.2 L16.5 4.4 L17.1 7.2 L19.9 8 L19.1 10.8 L21.2 12.9 L19 14.7 L19.4 17.6 L16.5 17.9 L15.2 20.5 L12.6 19.2 L10 20.6 L8.5 18 L5.6 17.8 L5.8 14.9 L3.4 13.2 L5.3 11 L4.4 8.2 L7.2 7.3 L7.7 4.4 L10.6 5 Z"/>',
    "more": '<circle cx="5.5" cy="12" r="1.9" fill="#FFF"/><circle cx="12" cy="12" r="1.9" fill="#FFF"/><circle cx="18.5" cy="12" r="1.9" fill="#FFF"/>',
    "tablet": f'<rect x="5" y="2.8" width="14" height="18.4" rx="2.6" {S}/><path {S} d="M10 18 H14"/>',
    "bell": f'<path {S} d="M6 16.8 V11 A6 6 0 0 1 18 11 V16.8 L19.5 18.4 H4.5 Z M10 20.6 H14"/>',
    "bell_dot": f'<path {S} d="M6 16.8 V11 A6 6 0 0 1 14.2 5.4 M18 11 V16.8 L19.5 18.4 H4.5 L6 16.8 M10 20.6 H14"/><circle cx="18" cy="6" r="3" fill="#FFF"/>',
    "map": f'<path {S} d="M12 21 C8 16.5 5.5 13.3 5.5 9.8 A6.5 6.5 0 0 1 18.5 9.8 C18.5 13.3 16 16.5 12 21 Z"/><circle cx="12" cy="9.8" r="2.4" {S}/>',
    "chevron_up": f'<path {S} d="M5.5 15 L12 8.5 L18.5 15"/>',
    "chevron_down": f'<path {S} d="M5.5 9 L12 15.5 L18.5 9"/>',
    "lock": f'<rect x="5" y="10.5" width="14" height="10" rx="2.5" {S}/><path {S} d="M8.5 10.5 V7.5 A3.5 3.5 0 0 1 15.5 7.5 V10.5"/>',
    "close": f'<path {S} d="M6 6 L18 18 M18 6 L6 18"/>',
    # telemetry status (top bar)
    "battery": f'<rect x="2.5" y="7" width="17" height="10" rx="2.4" {S}/><path {S} d="M21.5 10.5 V13.5"/><rect x="4.8" y="9.3" width="10" height="5.4" rx="1" fill="#FFF"/>',
    "signal": '<g fill="#FFF"><rect x="3" y="16" width="3" height="4.5" rx="1"/><rect x="7.6" y="12.5" width="3" height="8" rx="1"/><rect x="12.2" y="9" width="3" height="11.5" rx="1"/><rect x="16.8" y="5" width="3" height="15.5" rx="1"/></g>',
    "gps": f'<g transform="rotate(-45 11 12)"><rect x="8.6" y="9.6" width="4.8" height="4.8" rx="0.8" {S}/><rect x="2.4" y="10.3" width="5" height="3.4" rx="0.6" {S}/><rect x="14.6" y="10.3" width="5" height="3.4" rx="0.6" {S}/></g><path {S} d="M15.6 20.4 A4.6 4.6 0 0 0 20.2 15.8"/><path {S} d="M11.5 21 L13 18.5"/>',
    "rc": f'<rect x="3" y="9" width="18" height="11" rx="3.5" {S}/><circle cx="8" cy="14.5" r="2" {S}/><circle cx="16" cy="14.5" r="2" {S}/><path {S} d="M6 9 L5 4 M18 9 L19 4"/>',
    "hd": f'<rect x="3" y="6" width="18" height="12" rx="3" {S}/>' + txt("HD", 6.6, 14.4),
    "wind": f'<path {S} d="M3 9 H14.5 A2.8 2.8 0 1 0 11.7 6.2 M3 13 H18 A2.8 2.8 0 1 1 15.2 15.8 M3 17 H9"/>',
    "obstacle": f'<path {S} d="M12 3.5 L20.5 19.5 H3.5 Z M12 9.5 V14"/><circle cx="12" cy="16.8" r="1.1" fill="#FFF"/>',
    "home_point": f'<circle cx="12" cy="12" r="8.5" {S}/>' + txt("H", 9, 15.3),
    "thermal_palette": '<defs><linearGradient id="ib" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#FFF" stop-opacity="0.15"/><stop offset="1" stop-color="#FFF"/></linearGradient></defs>'
                       f'<rect x="7" y="3.5" width="10" height="17" rx="2.5" fill="url(#ib)"/><rect x="7" y="3.5" width="10" height="17" rx="2.5" {S}/>',
    "night_phosphor": f'<circle cx="12" cy="12" r="8.2" {S}/><path {S} d="M8 12 A4 4 0 0 1 16 12"/><circle cx="12" cy="12" r="1.6" fill="#FFF"/>',
}
MODES = {"mode_N": ("N", "#3FA34D"), "mode_S": ("S", "#E0A23B"), "mode_M": ("M", "#D9573C"), "mode_A": ("A", "#B05CC8"),
         "mode_C": ("C", "#4C8FD6")}
for k, (letter, col) in MODES.items():
    G[k] = f'<rect x="3.5" y="3.5" width="17" height="17" rx="4.5" fill="{col}"/>' + txt(letter, 11, 16.1, weight=700)

STATES = {
    # disc fill, ring colour, ring width, glyph colour, glyph opacity
    "default": ("#0B0D0C", 0.52, "#FFFFFF", 0.34, 1.0, "#FFFFFF", 1.0),
    "pressed": ("#FFFFFF", 0.24, "#FFFFFF", 0.60, 1.0, "#FFFFFF", 1.0),
    "active": ("#2B2213", 0.70, "#E0AB59", 1.0, 1.6, "#F2C77E", 1.0),
    "disabled": ("#0B0D0C", 0.36, "#FFFFFF", 0.14, 1.0, "#FFFFFF", 0.36),
}


def glyph_svg(name, colour="#FFF", px=24):
    inner = G[name]
    if colour.upper() not in ("#FFF", "#FFFFFF"):
        inner = inner.replace("#FFF", colour)
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 24 24">{inner}</svg>'


# Camera modes keep the round-button language; when active the ring takes the mode's own colour treatment
# (ironbow gradient for thermal, green phosphor for night vision) instead of brass, so the mode reads at a glance.
MODE_RING = {
    "thermal": ('<linearGradient id="ring" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#2A0A5E"/>'
                '<stop offset="0.35" stop-color="#B0186A"/><stop offset="0.65" stop-color="#F0602A"/><stop offset="1" stop-color="#FFE45C"/></linearGradient>',
                "url(#ring)", "#FFD27A", "#26110F"),
    "night": ('<linearGradient id="ring" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#2F8F3A"/><stop offset="1" stop-color="#B7FF9A"/></linearGradient>',
              "url(#ring)", "#B7FF9A", "#0C1F10"),
}
KEY_HINT = {"thermal": "T", "night": "K"}


def button_svg(name, state, px, key=None):
    fill, fa, ring, ra, rw, gc, go = STATES[state]
    defs = ""
    if state == "active" and name in MODE_RING:
        defs, ring, gc, fill = MODE_RING[name]
        ra, rw, fa = 1.0, 2.2, 0.72
    inner = G[name] if name.startswith("mode_") else G[name].replace("#FFF", gc)
    if name.startswith("mode_") and state == "disabled":
        inner = inner.replace(MODES[name][1], "#6B6F68")
    badge = ""
    if key:
        # key-hint chip: 15 x 15 dp at the lower right, over the ring, only shown when the last input was keyboard/mouse
        badge = (f'<rect x="32" y="32" width="15" height="15" rx="4" fill="#0B0D0C" fill-opacity="0.86" stroke="#FFF" stroke-opacity="0.5" stroke-width="1"/>'
                 f'<text x="39.5" y="43.4" font-family="Roboto" font-weight="700" font-size="10" text-anchor="middle" fill="#FFF" fill-opacity="{go}">{key}</text>')
    # disc on a 48 grid; the glyph is 24 in the centre (50 percent), ring sits 0.75 inside the edge
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 48 48"><defs>{defs}</defs>'
            f'<circle cx="24" cy="24" r="23.4" fill="#000" opacity="0.16"/>'
            f'<circle cx="24" cy="24" r="22.6" fill="{fill}" fill-opacity="{fa}"/>'
            f'<circle cx="24" cy="24" r="22.2" fill="none" stroke="{ring}" stroke-opacity="{ra}" stroke-width="{rw}"/>'
            f'<g transform="translate(12 12)" opacity="{go}">{inner}</g>{badge}</svg>')


PALETTES = {   # thermal and night colour treatments: name -> gradient stops (cold to hot / dark to bright)
    "whitehot": ["#000000", "#FFFFFF"], "blackhot": ["#FFFFFF", "#000000"],
    "ironbow": ["#05011F", "#3B0A6E", "#A3186B", "#E2452E", "#F9A03A", "#FFF6B0"],
    "rainbow": ["#1A1A8C", "#1F8FD6", "#2FBF5A", "#F2E33A", "#F0602A", "#C21A1A"],
    "green_phosphor": ["#020A03", "#1E5C25", "#7EE06A", "#E6FFD8"], "white_phosphor": ["#05070A", "#5B6670", "#DDE6EE", "#FFFFFF"],
}


def chip_svg(name, selected):
    stops = PALETTES[name]
    st = "".join(f'<stop offset="{i/(len(stops)-1):.3f}" stop-color="{c}"/>' for i, c in enumerate(stops))
    ring = (f'<rect x="1" y="1" width="46" height="26" rx="8" fill="none" stroke="#E0AB59" stroke-width="2"/>' if selected else
            f'<rect x="1.5" y="1.5" width="45" height="25" rx="7.5" fill="none" stroke="#FFF" stroke-opacity="0.35"/>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="48" height="28" viewBox="0 0 48 28"><defs><linearGradient id="p" x1="0" y1="0" x2="1" y2="0">{st}</linearGradient></defs>'
            f'<rect x="4" y="4" width="40" height="20" rx="5" fill="url(#p)"/>{ring}</svg>')


def tag_svg(kind, text):
    """On-screen mode indicator under the OSD top bar, e.g. THERMAL . IRONBOW. 24 dp tall pill."""
    col = {"thermal": "#F0602A", "night": "#7EE06A"}[kind]
    w = 40 + len(text) * 7.9 if text else 34
    g = G[kind].replace("#FFF", col)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w:.0f}" height="24" viewBox="0 0 {w:.0f} 24">'
            f'<rect x="0.5" y="0.5" width="{w-1:.0f}" height="23" rx="11.5" fill="#0B0D0C" fill-opacity="0.62" stroke="{col}" stroke-opacity="0.85"/>'
            f'<g transform="translate(6 3) scale(0.75)">{g}</g>'
            f'<text x="28" y="16.2" font-family="Roboto" font-weight="700" font-size="11" letter-spacing="0.8" fill="#FFF">{text}</text></svg>')


def build():
    for name in G:
        L.save_svg(os.path.join(OUT, "glyph", f"{name}.svg"), glyph_svg(name))
        for px in (24, 32, 48, 64, 96):
            L.render(glyph_svg(name, px=px), px, px, os.path.join(OUT, "glyph", str(px), f"{name}.png"))
        for st in STATES:
            for px in (40, 48, 56, 64, 96, 128):
                L.render(button_svg(name, st, px), px, px, os.path.join(OUT, "button", st, str(px), f"{name}.png"))
            if name in KEY_HINT:
                L.save_svg(os.path.join(OUT, "button", st, f"{name}_key.svg"), button_svg(name, st, 48, KEY_HINT[name]))
                for px in (40, 48, 56, 64, 96, 128):
                    L.render(button_svg(name, st, px, KEY_HINT[name]), px, px, os.path.join(OUT, "button", st, str(px), f"{name}_key.png"))
        if name in KEY_HINT:
            for st in STATES:
                L.save_svg(os.path.join(OUT, "button", st, f"{name}.svg"), button_svg(name, st, 48))
    for n in PALETTES:
        for sel in (False, True):
            L.render(chip_svg(n, sel), 96, 56, os.path.join(OUT, "chip", f"palette_{n}{'_selected' if sel else ''}.png"))
    for kind, texts in (("thermal", ["THERMAL", "THERMAL · WHITE HOT", "THERMAL · BLACK HOT", "THERMAL · IRONBOW", "THERMAL · RAINBOW"]),
                        ("night", ["NIGHT", "NIGHT · GREEN", "NIGHT · WHITE"])):
        for t in texts:
            svg = tag_svg(kind, t)
            w = int(float(svg.split('width="')[1].split('"')[0]))
            slug = t.lower().replace(" · ", "_").replace(" ", "")
            L.render(svg, w * 2, 48, os.path.join(OUT, "tag", f"tag_{slug}.png"))
        L.render(tag_svg(kind, "").replace("</svg>", "</svg>"), 68, 48, os.path.join(OUT, "tag", f"tag_{kind}_bg.png"))
    # the camera drawer pull-up handle: a 36 x 5 dp pill with a chevron above, on a soft dark plate
    h = ('<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 96 32">'
         '<rect x="0" y="4" width="96" height="28" rx="14" fill="#0B0D0C" fill-opacity="0.55"/>'
         '<rect x="0.5" y="4.5" width="95" height="27" rx="13.5" fill="none" stroke="#FFF" stroke-opacity="0.30"/>'
         '<path d="M38 22 L48 14 L58 22" fill="none" stroke="#FFF" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>')
    for sc in (1, 2):
        L.render(h.format(w=96 * sc, h=32 * sc), 96 * sc, 32 * sc, os.path.join(OUT, "pill", f"handle_up_{sc}x.png"))
        L.render(h.replace("M38 22 L48 14 L58 22", "M38 14 L48 22 L58 14").format(w=96 * sc, h=32 * sc), 96 * sc, 32 * sc,
                 os.path.join(OUT, "pill", f"handle_down_{sc}x.png"))
    # notification shade hover hint at the top edge: 48 x 4 dp pill over a 28 dp soft top glow, plus the chevron cue
    hint = ('<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 160 40">'
            '<defs><radialGradient id="g" cx="80" cy="0" r="80" gradientTransform="matrix(1 0 0 0.35 0 0)" gradientUnits="userSpaceOnUse">'
            '<stop offset="0" stop-color="#000" stop-opacity="0.55"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient></defs>'
            '<rect width="160" height="40" fill="url(#g)"/>'
            '<rect x="56" y="8" width="48" height="4" rx="2" fill="#FFF" fill-opacity="0.92"/>'
            '<path d="M73 20 L80 26 L87 20" fill="none" stroke="#FFF" stroke-opacity="0.85" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>')
    for sc in (1, 2):
        L.render(hint.format(w=160 * sc, h=40 * sc), 160 * sc, 40 * sc, os.path.join(OUT, "pill", f"shade_hint_{sc}x.png"))
    L.save_svg(os.path.join(OUT, "pill", "shade_hint.svg"), hint.format(w=160, h=40))
    L.note(os.path.join(OUT, "glyph", "<px>", "<name>.png"), 0, 0, None, f"HUD glyphs ({len(G)}): white, 24/32/48/64/96 px, modulate in code")
    L.note(os.path.join(OUT, "glyph", "<name>.svg"), 24, 24, None, "HUD glyph vector source (letters need the PNG)")
    L.note(os.path.join(OUT, "button", "<state>", "<px>", "<name>.png"), 0, 0, None,
           "round HUD button, states default/pressed/active/disabled, diameters 40/48/56/64/96/128")
    L.note(os.path.join(OUT, "button", "<state>", "<px>", "thermal_key.png"), 0, 0, None,
           "thermal / night buttons with the T / K key-hint corner chip; active ring = ironbow / green phosphor")
    L.note(os.path.join(OUT, "chip", "palette_<name>[_selected].png"), 96, 56, None, "thermal/night palette chips 48 x 28 dp (2x)")
    L.note(os.path.join(OUT, "tag", "tag_<mode>.png"), 0, 48, None, "active-mode indicator pill, 24 dp tall (2x); _bg = icon-only pill for code text")
    L.note(os.path.join(OUT, "pill", "handle_up_1x.png"), 96, 32, None, "camera drawer pull-up handle (and _down, 2x)")
    L.note(os.path.join(OUT, "pill", "shade_hint_1x.png"), 160, 40, None, "notification-shade hover hint at the top edge (and 2x, svg)")
    return list(G)

if __name__ == "__main__":
    print(len(build()), "hud glyphs")

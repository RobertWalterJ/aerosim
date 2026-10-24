"""Material 3 adaptive app icons for the in-game tablet (lane osui).

Android adaptive icon geometry, in dp on a 108 x 108 canvas:
  * background layer: full bleed 108 x 108
  * foreground layer: transparent, art kept inside the 66 dp safe circle (r 33) and mostly the 48 dp keyline
  * visible mask: 72 dp (circle by default, or the Pixel squircle), centred
  * monochrome layer (Android 13 themed icons): one colour silhouette of the foreground with details cut out

Roles of every foreground part:  b = body (white in mono), a = accent (white in mono), d = detail (cut out in mono).
Outputs under assets/ui/osui/icons/ (see OSUI-MANIFEST.md).
"""
import os, math
import osui_lib as L

OUT = os.path.join(L.OUT, "icons")
CREAM = "#F6EEDA"
CREAM2 = "#E9DDBF"

SIZES = [48, 64, 96, 128, 192]


def gear_path(cx, cy, r_out, r_in, teeth=8, tw=0.42):
    pts = []
    for i in range(teeth):
        a0 = (i / teeth) * math.tau
        step = math.tau / teeth
        for frac, r in ((0.0, r_in), (0.5 - tw / 2 - 0.08, r_in), (0.5 - tw / 2, r_out), (0.5 + tw / 2, r_out), (0.5 + tw / 2 + 0.08, r_in)):
            a = a0 + step * frac
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return "M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in pts) + " Z"


def sym_fg(name, colour, size=50, filled=True, setname="material"):
    return L.sym(name, 54 - size / 2, 54 - size / 2, size, colour, setname, filled)


# app key -> (display name, bg top, bg bottom, [ (svg, role) ... ], game key used by TabletIcon/UniverseUI)
def apps():
    A = {}
    d = "#2F5537"
    A["dronebudz"] = ("DroneBudz", "#6FA073", "#527C57", [
        ('<path d="M42 31 H66 A12 12 0 0 1 78 43 V55 A12 12 0 0 1 66 67 H50 L38 77 L40 67 A12 12 0 0 1 30 55 V43 A12 12 0 0 1 42 31 Z" fill="%s"/>' % CREAM, "b"),
        (f'<g stroke="{d}" stroke-width="3" stroke-linecap="round"><line x1="45" y1="40" x2="63" y2="58"/><line x1="63" y1="40" x2="45" y2="58"/></g>', "d"),
        (f'<g fill="none" stroke="{d}" stroke-width="2.6"><circle cx="44" cy="39" r="5.2"/><circle cx="64" cy="39" r="5.2"/><circle cx="44" cy="59" r="5.2"/><circle cx="64" cy="59" r="5.2"/></g>', "d"),
        (f'<rect x="49.5" y="44.5" width="9" height="9" rx="2.5" fill="{d}"/>', "d"),
    ], "chat")
    A["vidtube"] = ("VidTube Studio", "#CF724D", "#AA5133", [
        (f'<rect x="28" y="32" width="52" height="38" rx="10" fill="{CREAM}"/>', "b"),
        ('<path d="M48 41.5 L65 51 L48 60.5 Z" fill="#B4532F" stroke="#B4532F" stroke-width="2" stroke-linejoin="round"/>', "d"),
        (f'<rect x="42" y="74" width="24" height="4" rx="2" fill="{CREAM}"/>', "a"),
    ], "studio")
    A["photos"] = ("Photos", "#4C8F99", "#356F79", [
        (f'<rect x="29" y="31" width="50" height="46" rx="9" fill="{CREAM}"/>', "b"),
        ('<path d="M34 72 L46 54 L54 64 L60 57 L74 72 Z" fill="#2E6169" stroke="#2E6169" stroke-width="2" stroke-linejoin="round"/>', "d"),
        ('<circle cx="66" cy="43" r="5.5" fill="#E2A24B"/>', "d"),
    ], "photos")
    A["jobs"] = ("Jobs", "#4B6A54", "#33493A", [
        (f'<rect x="33" y="30" width="42" height="49" rx="7" fill="{CREAM}"/>', "b"),
        ('<rect x="44" y="25" width="20" height="10" rx="4" fill="#E0AB59"/>', "a"),
        ('<rect x="44" y="25" width="20" height="10" rx="4" fill="none" stroke="#4B6A54" stroke-width="2"/>', "d"),
    ] + [(f'<path d="M39 {y} l3.5 3.5 l6.5 -7" fill="none" stroke="#3A6A47" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/>'
          f'<rect x="53" y="{y-1.5}" width="16" height="3.4" rx="1.7" fill="#5C6B60"/>', "d") for y in (46, 57, 68)], "jobs")
    A["casebook"] = ("Casebook", "#5B7194", "#435677", [
        ('<path d="M29 39 A4 4 0 0 1 33 35 H47 L52 40 H75 A4 4 0 0 1 79 44 V71 A4 4 0 0 1 75 75 H33 A4 4 0 0 1 29 71 Z" fill="#D7B064"/>', "b"),
        ('<rect x="29" y="45" width="50" height="30" rx="4" fill="#F0D595"/>', "b"),
        ('<line x1="29" y1="45.5" x2="79" y2="45.5" stroke="#B88F43" stroke-width="1.6"/>', "d"),
        ('<circle cx="68" cy="66" r="12" fill="#435677"/>', "d"),
        ('<circle cx="68" cy="66" r="9.2" fill="#C9714F"/>', "a"),
        ('<path d="M68 59.6 L69.9 63.9 L74.5 64.3 L71 67.3 L72.1 71.8 L68 69.4 L63.9 71.8 L65 67.3 L61.5 64.3 L66.1 63.9 Z" fill="#F6EEDA"/>', "d"),
    ], "casebook")
    stripes = "".join(f'<rect x="{29 + i*10}" y="33" width="5" height="12" fill="{CREAM}"/>' for i in range(5))
    scal = "".join(f'<circle cx="{31.5 + i*5}" cy="45" r="2.5" fill="{"#B4532F" if i % 2 == 0 else CREAM}"/>' for i in range(10))
    A["facade"] = ("Facade", "#D6A352", "#B58133", [
        (f'<rect x="32" y="44" width="44" height="33" rx="3" fill="{CREAM}"/>', "b"),
        ('<rect x="29" y="31" width="50" height="14" rx="3" fill="#B4532F"/>', "a"),
        (stripes, "d"), (scal, "a"),
        ('<rect x="37" y="54" width="16" height="12" rx="2" fill="#3E4B45"/>', "d"),
        ('<rect x="58" y="55" width="13" height="22" rx="2" fill="#8A5A2B"/>', "d"),
    ], "market")
    A["map"] = ("Map", "#8DA676", "#6B865A", [
        (f'<path d="M29 37 L45 32 L62 37 L79 32 V72 L62 77 L45 72 L29 77 Z" fill="{CREAM}"/>', "b"),
        (f'<path d="M45 32 L62 37 V77 L45 72 Z" fill="{CREAM2}"/>', "a"),
        ('<path d="M45 32 V72 M62 37 V77" stroke="#C9B98E" stroke-width="1.4"/>', "d"),
        ('<path d="M31 62 C40 58 44 66 52 63 S66 52 77 56" fill="none" stroke="#4E8E99" stroke-width="3.2" stroke-linecap="round"/>', "d"),
        ('<path d="M61 63 C55 56 52 52 52 47.5 A9 9 0 0 1 70 47.5 C70 52 67 56 61 63 Z" fill="none" stroke="#7B9566" stroke-width="3.5"/>', "d"),
        ('<path d="M61 63 C55 56 52 52 52 47.5 A9 9 0 0 1 70 47.5 C70 52 67 56 61 63 Z" fill="#C9563A"/>', "a"),
        ('<circle cx="61" cy="47.5" r="3.3" fill="#F6EEDA"/>', "d"),
    ], "map")
    A["settings"] = ("Settings", "#5E6459", "#454A42", [
        (f'<path d="{gear_path(54, 54, 25, 19, 8)}" fill="{CREAM}" stroke="{CREAM}" stroke-width="2.5" stroke-linejoin="round"/>', "b"),
        ('<circle cx="54" cy="54" r="8.5" fill="#545A50"/>', "d"),
    ], "settings")
    cloud = '<path d="M42 76 A11 11 0 0 1 40.5 54.2 A14 14 0 0 1 66.5 52 A12 12 0 0 1 70 76 Z" %s/>'
    A["weather"] = ("Weather", "#5E9EC4", "#3F7CA2", [
        ('<circle cx="64" cy="43" r="12" fill="#F2B84B"/>', "a"),
        (cloud % 'fill="none" stroke="#4F8DB3" stroke-width="5" stroke-linejoin="round"', "d"),
        (cloud % f'fill="{CREAM}"', "b"),
    ], "weather")
    A["camera"] = ("Camera", "#41463F", "#2A2E29", [
        (f'<rect x="27" y="38" width="54" height="37" rx="9" fill="{CREAM}"/><rect x="41" y="31" width="18" height="10" rx="3" fill="{CREAM}"/>', "b"),
        ('<circle cx="54" cy="57" r="14" fill="#2F3530"/>', "d"),
        ('<circle cx="54" cy="57" r="11" fill="none" stroke="#E0AB59" stroke-width="2"/>', "d"),
        ('<circle cx="54" cy="57" r="7.5" fill="#3E7884"/>', "d"),
        ('<circle cx="51" cy="54" r="2.3" fill="#BFE3E8"/>', "d"),
        ('<circle cx="72" cy="46" r="2.6" fill="#D9573C"/>', "d"),
    ], "camera")
    A["phone"] = ("Phone", "#64A170", "#4A7F55", [(sym_fg("call", CREAM, 56), "b")], "phone")
    A["recents"] = ("Recents", "#727A6C", "#565D52", [
        ('<rect x="38" y="28" width="32" height="44" rx="6" fill="#D9CFB4"/>', "a"),
        ('<rect x="38" y="28" width="32" height="44" rx="6" fill="none" stroke="#636A5E" stroke-width="1"/>', "d"),
        ('<rect x="31" y="35" width="32" height="44" rx="6" fill="#636A5E"/>', "d"),
        (f'<rect x="33" y="37" width="32" height="44" rx="6" fill="{CREAM}"/>', "b"),
        ('<rect x="38" y="44" width="16" height="3.4" rx="1.7" fill="#8C9182"/><rect x="38" y="51" width="22" height="3.4" rx="1.7" fill="#8C9182"/>', "d"),
    ], "recents")
    ticks = "".join(f'<line x1="{54 + math.cos(i*math.pi/6)*19:.2f}" y1="{54 + math.sin(i*math.pi/6)*19:.2f}" x2="{54 + math.cos(i*math.pi/6)*22:.2f}" y2="{54 + math.sin(i*math.pi/6)*22:.2f}"/>' for i in range(12))
    A["clock"] = ("Clock", "#3A4D66", "#26364B", [
        (f'<circle cx="54" cy="54" r="26" fill="{CREAM}"/>', "b"),
        (f'<g stroke="#8C9182" stroke-width="2" stroke-linecap="round">{ticks}</g>', "d"),
        ('<g stroke="#26364B" stroke-width="3.6" stroke-linecap="round"><line x1="54" y1="54" x2="54" y2="38"/><line x1="54" y1="54" x2="65" y2="61"/></g>', "d"),
        ('<circle cx="54" cy="54" r="3" fill="#C9714F"/>', "d"),
    ], "clock")
    A["files"] = ("Files", "#A6803F", "#86632D", [
        (f'<path d="M28 38 A5 5 0 0 1 33 33 H47 L53 39 H75 A5 5 0 0 1 80 44 V71 A5 5 0 0 1 75 76 H33 A5 5 0 0 1 28 71 Z" fill="{CREAM}"/>', "b"),
        ('<rect x="28" y="45" width="52" height="2" fill="#C6B48A"/>', "d"),
    ], "files")
    A["installer"] = ("Package installer", "#43807F", "#2E6264", [
        (f'<path d="M30 48 L54 38 L78 48 V70 A4 4 0 0 1 75.5 73.7 L54 82 L32.5 73.7 A4 4 0 0 1 30 70 Z" fill="{CREAM}"/>', "b"),
        ('<path d="M30 48 L54 58 L78 48 M54 58 V82" fill="none" stroke="#9FB7AE" stroke-width="1.6"/>', "d"),
        ('<path d="M54 22 V40 M46 33 L54 41 L62 33" fill="none" stroke="#E0AB59" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>', "a"),
    ], "installer")
    A["store"] = ("Facade Apps", "#D6A352", "#B58133", [
        (f'<path d="M34 42 H74 L71 76 A4 4 0 0 1 67 80 H41 A4 4 0 0 1 37 76 Z" fill="{CREAM}"/>', "b"),
        ('<path d="M45 42 V38 A9 9 0 0 1 63 38 V42" fill="none" stroke="#F6EEDA" stroke-width="3.4"/>', "a"),
        ('<path d="M50 55 L62 62 L50 69 Z" fill="#B4532F" stroke="#B4532F" stroke-width="2" stroke-linejoin="round"/>', "d"),
    ], "store")
    A["notes"] = ("Field Notes", "#7A6A4E", "#5D5039", [
        (f'<rect x="32" y="28" width="44" height="52" rx="6" fill="{CREAM}"/>', "b"),
        ('<rect x="32" y="28" width="9" height="52" rx="4" fill="#C9714F"/>', "a"),
        ('<g fill="#8C9182"><rect x="47" y="41" width="22" height="3" rx="1.5"/><rect x="47" y="50" width="22" height="3" rx="1.5"/><rect x="47" y="59" width="15" height="3" rx="1.5"/></g>', "d"),
    ], "notes")
    return A


SQUIRCLE = ("M54 18 C80.5 18 90 27.5 90 54 C90 80.5 80.5 90 54 90 C27.5 90 18 80.5 18 54 C18 27.5 27.5 18 54 18 Z")


def layer_svg(inner, w=108):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{w}" viewBox="0 0 108 108">{inner}</svg>'


def bg_markup(top, bot):
    return (f'<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/>'
            f'<stop offset="1" stop-color="{bot}"/></linearGradient></defs><rect width="108" height="108" fill="url(#bg)"/>')


def fg_markup(parts):
    return "".join(p for p, _ in parts)


def mono_markup(parts, colour="#FFFFFF", mid="m"):
    """Monochrome: body and accent white, details cut out (SVG mask)."""
    mask = []
    for p, role in parts:
        if role == "d":
            mask.append(f'<g style="filter:none">{_recolour(p, "#000")}</g>')
        else:
            mask.append(_recolour(p, "#FFF"))
    return (f'<defs><mask id="{mid}" maskUnits="userSpaceOnUse" x="0" y="0" width="108" height="108">{"".join(mask)}</mask></defs>'
            f'<rect width="108" height="108" fill="{colour}" mask="url(#{mid})"/>')


def _recolour(p, c):
    import re
    p = re.sub(r'fill="(?!none)[^"]+"', f'fill="{c}"', p)
    p = re.sub(r'stroke="(?!none)[^"]+"', f'stroke="{c}"', p)
    return p


def composite(bg, fg, shape="circle", themed=None):
    if themed:
        back = f'<rect width="108" height="108" fill="{themed[0]}"/>'
        front = mono_markup(themed[2], themed[1], "tm")
    else:
        back, front = bg, fg
    clip = '<circle cx="54" cy="54" r="36"/>' if shape == "circle" else f'<path d="{SQUIRCLE}"/>'
    # the 72 dp mask is scaled up to fill the exported canvas: content box 18..90 maps to the full image
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="72" height="72" viewBox="18 18 72 72">'
            f'<defs><clipPath id="k">{clip}</clipPath></defs><g clip-path="url(#k)">{back}{front}</g></svg>')


THEMED = {"dark": ("#3A3122", "#F3D59E"), "light": ("#FFE2B0", "#5E4300")}


def build():
    A = apps()
    for key, (name, top, bot, parts, game) in A.items():
        bg, fg, mono = bg_markup(top, bot), fg_markup(parts), mono_markup(parts)
        for lname, inner in (("bg", bg), ("fg", fg), ("mono", mono)):
            svg = layer_svg(inner)
            p = os.path.join(OUT, "layers", f"{key}_{lname}.svg")
            L.save_svg(p, svg)
            L.note(p, 108, 108, None, f"{name}: adaptive {lname} layer, 108 dp canvas (vector)")
            png = os.path.join(OUT, "layers", f"{key}_{lname}.png")
            L.render(svg, 432, 432, png)
            L.note(png, 432, 432, None, f"{name}: {lname} layer at 4x (432 px)")
        for shape in ("circle", "squircle"):
            svg = composite(bg, fg, shape)
            L.save_svg(os.path.join(OUT, shape, f"{key}.svg"), svg)
            L.render(svg, 512, 512, os.path.join(OUT, shape, f"{key}.png"))
            L.note(os.path.join(OUT, shape, f"{key}.png"), 512, 512, None, f"{name}: {shape} launcher icon, master")
            for px in SIZES:
                p = os.path.join(OUT, shape, str(px), f"{key}.png")
                L.render(svg, px, px, p)
        for mode, (tb, tg) in THEMED.items():
            svg = composite(bg, fg, "circle", (tb, tg, parts))
            for px in [64, 96, 128, 192]:
                L.render(svg, px, px, os.path.join(OUT, "themed", mode, str(px), f"{key}.png"))
            L.save_svg(os.path.join(OUT, "themed", mode, f"{key}.svg"), svg)
        # notification / status-bar glyph: the mono foreground cropped to the safe zone, white on transparent
        msvg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="66" height="66" viewBox="21 21 66 66">{mono}</svg>')
        L.save_svg(os.path.join(OUT, "mono", f"{key}.svg"), msvg)
        for px in (24, 36, 48, 96):
            L.render(msvg, px, px, os.path.join(OUT, "mono", str(px), f"{key}.png"))
    for shape in ("circle", "squircle"):
        for px in SIZES:
            L.note(os.path.join(OUT, shape, str(px), "<app>.png"), px, px, None, f"{shape} launcher icon native render")
    for mode in THEMED:
        L.note(os.path.join(OUT, "themed", mode, "<px>", "<app>.png"), 0, 0, None,
               f"themed ({mode}) icon: tonal disc + monochrome glyph, 64/96/128/192")
    L.note(os.path.join(OUT, "mono", "<px>", "<app>.png"), 0, 0, None, "white silhouette for status bar and notifications, 24/36/48/96")
    return A


if __name__ == "__main__":
    build()
    print("icons done")

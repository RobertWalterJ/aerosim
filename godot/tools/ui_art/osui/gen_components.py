"""Material 3 component art for the tablet OS (lane osui), light and dark, with state variants.

Every component is exported as:
  components/<theme>/svg/<name>_<state>.svg   vector, dp-sized (Godot can import SVG directly)
  components/<theme>/<name>_<state>.png       2x render for StyleBoxTexture / NinePatchRect (margins in the manifest)
States follow Material 3: default, pressed (10 percent on-colour state layer), focused (3 dp focus ring, 2 dp gap),
disabled (container on-surface 12 percent, content 38 percent), plus on/off/selected/error where the component has them.
Code-drawn StyleBoxFlat equivalents are given in the spec; the PNGs are for exact-match art and the component sheet.
"""
import os
import osui_lib as L

OUT = os.path.join(L.OUT, "components")
SC = 2   # export density


def svgwrap(w, h, inner, pad=4):
    """pad leaves room for the focus ring and shadows; the 9-patch margins include it."""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w + 2*pad}" height="{h + 2*pad}" '
            f'viewBox="{-pad} {-pad} {w + 2*pad} {h + 2*pad}">{inner}</svg>')


def shadow_def(level):
    dy, blur, a = {1: (1, 1.5, 0.30), 2: (2, 3, 0.30), 3: (4, 5, 0.32)}[level]
    return (f'<defs><filter id="e" x="-30%" y="-30%" width="160%" height="170%"><feDropShadow dx="0" dy="{dy}" '
            f'stdDeviation="{blur}" flood-color="#000" flood-opacity="{a}"/></filter></defs>')


def surf(w, h, r, fill, state, on_colour, outline=None, elev=0, sw=1, fill_op=1.0):
    """Container + state layer + focus ring for a w x h surface with radius r (r may be 'pill')."""
    r = h / 2 if r == "pill" else r
    s = shadow_def(elev) if elev and state != "disabled" else ""
    f = ' filter="url(#e)"' if s else ""
    if state == "disabled":
        if fill != "none":
            fill, fill_op = on_colour, 0.12
        if outline:
            outline = on_colour
    s += f'<rect width="{w}" height="{h}" rx="{r}" fill="{fill}" fill-opacity="{fill_op}"{f}/>'
    if outline:
        oo = 0.12 if state == "disabled" else 1.0
        s += f'<rect x="{sw/2}" y="{sw/2}" width="{w-sw}" height="{h-sw}" rx="{max(r-sw/2,0)}" fill="none" stroke="{outline}" stroke-opacity="{oo}" stroke-width="{sw}"/>'
    if state in ("pressed", "focused"):
        s += f'<rect width="{w}" height="{h}" rx="{r}" fill="{on_colour}" fill-opacity="0.10"/>'
    if state == "hovered":
        s += f'<rect width="{w}" height="{h}" rx="{r}" fill="{on_colour}" fill-opacity="0.08"/>'
    if state == "focused":
        s += f'<rect x="-2.5" y="-2.5" width="{w+5}" height="{h+5}" rx="{r+2.5}" fill="none" stroke="{FOCUS}" stroke-width="3"/>'
    return s


FOCUS = "#C9A86A"


def label(x, y, s, colour, state, size=14, weight=500, anchor="middle"):
    op = 0.38 if state == "disabled" else 1.0
    return (f'<text x="{x}" y="{y}" font-family="Roboto" font-size="{size}" font-weight="{weight}" text-anchor="{anchor}" '
            f'fill="{colour}" fill-opacity="{op}" letter-spacing="0.1">{L.esc(s)}</text>')


def build_theme(theme, T):
    global FOCUS
    FOCUS = T["secondary"]
    items = []   # (name, state, w, h, inner, nine_margin_dp, note)
    st4 = ("default", "pressed", "focused", "disabled")
    # ---------------- buttons (40 dp, pill)
    btns = {
        "button_filled": (T["primary"], T["on-primary"], None, 0),
        "button_tonal": (T["secondary-container"], T["on-secondary-container"], None, 0),
        "button_outlined": ("none", T["primary"], T["outline"], 0),
        "button_text": ("none", T["primary"], None, 0),
        "button_elevated": (T["surface-container-low"], T["primary"], None, 1),
        "button_danger": (T["error"], T["on-error"], None, 0),
    }
    for n, (fill, on, ol, el) in btns.items():
        for st in st4:
            fc = fill if fill != "none" else "none"
            inner = surf(120, 40, "pill", fc if fc != "none" else on, st, on, ol, el,
                         fill_op=1.0 if fc != "none" else 0.0)
            inner += label(60, 25, "Label", on if st != "disabled" else T["on-surface"], st)
            items.append((n, st, 120, 40, inner, 20, "M3 common button, 40 dp tall, 24 dp side padding, label-large"))
    # ---------------- FABs
    for n, w, h, r in (("fab", 56, 56, 16), ("fab_small", 40, 40, 12), ("fab_large", 96, 96, 28), ("fab_extended", 140, 56, 16)):
        for st in st4:
            inner = surf(w, h, r, T["primary-container"], st, T["on-primary-container"], None, 3)
            col = T["on-primary-container"] if st != "disabled" else T["on-surface"]
            op = 0.38 if st == "disabled" else 1
            isz = 36 if n == "fab_large" else 24
            ix = (20 if n == "fab_extended" else (w - isz) / 2)
            inner += f'<g opacity="{op}">' + L.sym("add", ix, (h - isz) / 2, isz, col) + '</g>'
            if n == "fab_extended":
                inner += label(56, 33, "Upload", col, st, anchor="start")
            items.append((n, st, w, h, inner, r, "FAB, primary-container, elevation 3"))
    # ---------------- icon buttons (40 dp visual in a 48 dp target)
    for n, fill, on, ol in (("icon_button", "none", T["on-surface-variant"], None),
                            ("icon_button_filled", T["primary"], T["on-primary"], None),
                            ("icon_button_tonal", T["secondary-container"], T["on-secondary-container"], None),
                            ("icon_button_outlined", "none", T["on-surface-variant"], T["outline"])):
        for st in st4 + ("selected",):
            f2, on2 = fill, on
            if st == "selected" and n == "icon_button":
                on2 = T["primary"]
            if st == "selected" and n == "icon_button_outlined":
                f2, on2, ol2 = T["inverse-surface"], T["inverse-on-surface"], None
            else:
                ol2 = ol
            inner = surf(40, 40, 20, f2 if f2 != "none" else on2, st, on2, ol2, 0, fill_op=1.0 if f2 != "none" else 0.0)
            col = on2 if st != "disabled" else T["on-surface"]
            inner += f'<g opacity="{0.38 if st == "disabled" else 1}">' + L.sym("settings", 8, 8, 24, col) + "</g>"
            items.append((n, st, 40, 40, inner, None, "icon button 40 dp in a 48 dp target"))
    # ---------------- switch 52 x 32
    for on in (True, False):
        for st in st4:
            dis = st == "disabled"
            if on:
                track = f'<rect width="52" height="32" rx="16" fill="{T["on-surface"] if dis else T["primary"]}" fill-opacity="{0.12 if dis else 1}"/>'
                hx, hr, hc = 36, 12, (T["surface"] if dis else T["on-primary"])
                icon = L.sym("check", 28, 8, 16, T["on-primary-container"] if not dis else T["on-surface"], opacity=0.38 if dis else 1)
            else:
                track = (f'<rect x="1" y="1" width="50" height="30" rx="15" fill="{T["surface-container-highest"]}" fill-opacity="{0.12 if dis else 1}" '
                         f'stroke="{T["on-surface"] if dis else T["outline"]}" stroke-opacity="{0.12 if dis else 1}" stroke-width="2"/>')
                hx, hr, hc = 16, 8, T["outline"] if not dis else T["on-surface"]
                icon = ""
            halo = ""
            if st in ("pressed", "focused"):
                halo = f'<circle cx="{hx}" cy="16" r="20" fill="{T["primary"] if on else T["on-surface"]}" fill-opacity="0.10"/>'
            ring = f'<rect x="-2.5" y="-2.5" width="57" height="37" rx="18.5" fill="none" stroke="{FOCUS}" stroke-width="3"/>' if st == "focused" else ""
            hr2 = 14 if st == "pressed" else hr
            knob = f'<circle cx="{hx}" cy="16" r="{hr2}" fill="{hc}" fill-opacity="{0.38 if dis and not on else 1}"/>'
            items.append((f"switch_{'on' if on else 'off'}", st, 52, 32, halo + track + ring + knob + icon, None, "M3 switch 52 x 32, handle 24 on / 16 off, 28 pressed"))
    # ---------------- checkbox / radio (18 dp control centred in a 40 dp state layer)
    for kind in ("checkbox_on", "checkbox_off", "checkbox_mixed", "radio_on", "radio_off"):
        for st in st4 + ("error",):
            dis = st == "disabled"
            col = T["error"] if st == "error" else (T["on-surface"] if dis else (T["primary"] if kind.endswith(("on", "mixed")) else T["on-surface-variant"]))
            op = 0.38 if dis else 1
            layer = ""
            if st in ("pressed", "focused"):
                layer = f'<circle cx="20" cy="20" r="20" fill="{col}" fill-opacity="0.10"/>'
            if st == "focused":
                layer += f'<circle cx="20" cy="20" r="21.5" fill="none" stroke="{FOCUS}" stroke-width="3"/>'
            if kind.startswith("checkbox"):
                if kind == "checkbox_off":
                    c = f'<rect x="12" y="12" width="16" height="16" rx="2" fill="none" stroke="{col}" stroke-width="2" opacity="{op}"/>'
                else:
                    mark = ('<path d="M15 20.2 L18.6 23.6 L25.2 16.6" fill="none" stroke="{c}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>'
                            if kind == "checkbox_on" else '<path d="M15.5 20 H24.5" stroke="{c}" stroke-width="2.2" stroke-linecap="round"/>')
                    c = (f'<rect x="11" y="11" width="18" height="18" rx="2" fill="{col}" opacity="{op}"/>' +
                         mark.format(c=T["on-error"] if st == "error" else (T["surface"] if dis else T["on-primary"])))
            else:
                c = f'<circle cx="20" cy="20" r="9" fill="none" stroke="{col}" stroke-width="2" opacity="{op}"/>'
                if kind == "radio_on":
                    c += f'<circle cx="20" cy="20" r="5" fill="{col}" opacity="{op}"/>'
            items.append((kind, st, 40, 40, layer + c, None, "selection control, 18 dp box in a 40 dp state layer"))
    # ---------------- slider (M3: 16 dp track, 4 dp handle bar 44 tall) and brightness slider (QS)
    for st in ("default", "pressed", "focused", "disabled"):
        dis = st == "disabled"
        a = T["on-surface"] if dis else T["primary"]
        b = T["on-surface"] if dis else T["secondary-container"]
        hw = 2 if st == "pressed" else 4
        inner = (f'<rect x="0" y="14" width="96" height="16" rx="8" fill="{a}" fill-opacity="{0.38 if dis else 1}"/>'
                 f'<rect x="108" y="14" width="92" height="16" rx="8" fill="{b}" fill-opacity="{0.12 if dis else 1}"/>'
                 f'<circle cx="196" cy="22" r="2" fill="{a}" opacity="{0.38 if dis else 1}"/>'
                 f'<rect x="{102 - hw/2}" y="0" width="{hw}" height="44" rx="{hw/2}" fill="{a}" fill-opacity="{0.38 if dis else 1}"/>')
        if st == "focused":
            inner += f'<rect x="97.5" y="-3" width="9" height="50" rx="4.5" fill="none" stroke="{FOCUS}" stroke-width="2"/>'
        items.append(("slider", st, 200, 44, inner, None, "M3 slider: 16 dp track, 4 dp x 44 dp handle, 6 dp gap"))
    for st in ("default", "pressed", "disabled"):
        dis = st == "disabled"
        inner = (f'<rect width="300" height="48" rx="24" fill="{T["surface-container-highest"]}"/>'
                 f'<rect width="{180 if st != "pressed" else 196}" height="48" rx="24" fill="{T["on-surface"] if dis else T["primary"]}" fill-opacity="{0.38 if dis else 1}"/>'
                 + L.sym("brightness_high", 14, 12, 24, T["on-primary"] if not dis else T["surface"]))
        items.append(("brightness_slider", st, 300, 48, inner, 24, "Quick Settings brightness slider, 48 dp pill"))
    # ---------------- progress
    items.append(("progress_linear", "default", 200, 4,
                  f'<rect width="200" height="4" rx="2" fill="{T["secondary-container"]}"/><rect width="120" height="4" rx="2" fill="{T["primary"]}"/>', 2, "linear progress, 4 dp"))
    items.append(("progress_circular", "default", 48, 48,
                  f'<circle cx="24" cy="24" r="20" fill="none" stroke="{T["secondary-container"]}" stroke-width="4"/>'
                  f'<path d="M24 4 A20 20 0 1 1 6.7 34" fill="none" stroke="{T["primary"]}" stroke-width="4" stroke-linecap="round"/>', None, "circular progress, 48 dp, 4 dp stroke"))
    # ---------------- chips (32 dp, r 8)
    for n, sel in (("chip_assist", False), ("chip_filter", False), ("chip_filter_selected", True), ("chip_input", False), ("chip_suggestion", False)):
        for st in st4:
            dis = st == "disabled"
            if sel:
                inner = surf(96, 32, 8, T["secondary-container"], st, T["on-secondary-container"])
                inner += f'<g opacity="{0.38 if dis else 1}">' + L.sym("check", 8, 7, 18, T["on-secondary-container"]) + "</g>"
                inner += label(32, 21, "Drones", T["on-secondary-container"] if not dis else T["on-surface"], st, anchor="start")
            else:
                inner = surf(96, 32, 8, T["primary"], st, T["on-surface-variant"], T["outline-variant"] if not dis else T["on-surface"], fill_op=0.0)
                ic = {"chip_assist": "route", "chip_input": "person", "chip_filter": None, "chip_suggestion": None}[n]
                tx = 16
                if ic:
                    inner += f'<g opacity="{0.38 if dis else 1}">' + L.sym(ic, 8, 7, 18, T["primary"]) + "</g>"
                    tx = 32
                inner += label(tx, 21, "Drones", T["on-surface-variant"] if not dis else T["on-surface"], st, anchor="start")
                if n == "chip_input":
                    inner += L.sym("close", 74, 8, 16, T["on-surface-variant"], opacity=0.38 if dis else 1)
            items.append((n, st, 96, 32, inner, 8, "M3 chip, 32 dp tall, r 8, label-large"))
    # ---------------- text fields (56 dp)
    for n in ("textfield_filled", "textfield_outlined"):
        for st in ("default", "focused", "error", "disabled"):
            dis = st == "disabled"
            ac = T["error"] if st == "error" else (T["primary"] if st == "focused" else (T["on-surface"] if dis else T["on-surface-variant"]))
            if n == "textfield_filled":
                inner = (f'<path d="M0 4 A4 4 0 0 1 4 0 H236 A4 4 0 0 1 240 4 V56 H0 Z" fill="{T["surface-container-highest"] if not dis else T["on-surface"]}" fill-opacity="{0.04 if dis else 1}"/>'
                         f'<rect x="0" y="{54 if st in ("focused", "error") else 55}" width="240" height="{2 if st in ("focused", "error") else 1}" fill="{ac}" fill-opacity="{0.38 if dis else 1}"/>')
                y1, y2 = 20, 42
            else:
                inner = (f'<rect x="0.5" y="0.5" width="239" height="55" rx="4" fill="none" stroke="{ac if st != "default" else T["outline"]}" '
                         f'stroke-width="{2 if st in ("focused", "error") else 1}" stroke-opacity="{0.12 if dis else 1}"/>')
                inner += f'<rect x="12" y="-3" width="74" height="6" fill="{T["surface"]}"/>'
                y1, y2 = 4, 34
            inner += label(16, y1, "Pilot name", ac, st, 12, 400, "start")
            inner += label(16, y2, "Wren Halloway", T["on-surface"], st, 16, 400, "start")
            if st == "focused":
                inner += f'<rect x="{16 + 118}" y="{y2 - 15}" width="2" height="19" fill="{T["primary"]}"/>'
            if st == "error":
                inner += L.sym("error", 208, 16, 24, T["error"], filled=True)
            items.append((n, st, 240, 56, inner, None, "M3 text field 56 dp, label body-small, input body-large"))
    # ---------------- surfaces (9-patch)
    surfaces = [
        ("card_filled", 200, 120, 12, T["surface-container-highest"], None, 0),
        ("card_elevated", 200, 120, 12, T["surface-container-low"], None, 1),
        ("card_outlined", 200, 120, 12, T["surface"], T["outline-variant"], 0),
        ("dialog", 312, 200, 28, T["surface-container-high"], None, 3),
        ("menu", 200, 160, 4, T["surface-container"], None, 2),
        ("snackbar", 344, 48, 4, T["inverse-surface"], None, 3),
        ("tooltip", 120, 24, 4, T["inverse-surface"], None, 0),
        ("search_bar", 360, 56, 28, T["surface-container-high"], None, 0),
        ("qs_tile_on", 168, 64, 32, T["primary"], None, 0),
        ("qs_tile_off", 168, 64, 32, T["surface-container-highest"], None, 0),
        ("qs_tile_unavailable", 168, 64, 32, T["surface-container"], None, 0),
        ("qs_tile_small_on", 64, 64, 32, T["primary"], None, 0),
        ("qs_tile_small_off", 64, 64, 32, T["surface-container-highest"], None, 0),
        ("notification", 400, 88, 24, T["surface-container-high"], None, 0),
        ("notification_heads_up", 400, 88, 24, T["surface-container-high"], None, 3),
        ("list_item_selected", 300, 56, 28, T["secondary-container"], None, 0),
        ("nav_indicator", 64, 32, 16, T["secondary-container"], None, 0),
        ("rail_indicator", 56, 32, 16, T["secondary-container"], None, 0),
        ("widget", 240, 160, 24, T["surface-container"], None, 0),
    ]
    for n, w, h, r, fill, ol, el in surfaces:
        for st in (("default", "pressed") if not n.startswith(("dialog", "snackbar", "tooltip", "menu", "nav_", "rail_")) else ("default",)):
            items.append((n, st, w, h, surf(w, h, r, fill, st, T["on-surface"], ol, el), r, "surface, 9-patch"))
    # bottom sheet (top corners only) + drag handle
    items.append(("bottom_sheet", "default", 360, 200,
                  f'<path d="M0 28 A28 28 0 0 1 28 0 H332 A28 28 0 0 1 360 28 V200 H0 Z" fill="{T["surface-container-low"]}"/>'
                  f'<rect x="164" y="22" width="32" height="4" rx="2" fill="{T["on-surface-variant"]}" fill-opacity="0.4"/>', 28,
                  "modal bottom sheet, top radius 28, drag handle 32 x 4 at 22 dp"))
    items.append(("shade_panel", "default", 400, 300,
                  f'<path d="M0 0 H400 V272 A28 28 0 0 1 372 300 H28 A28 28 0 0 1 0 272 Z" fill="{T["surface-container"]}"/>', 28,
                  "notification shade sheet, bottom radius 28"))
    # top app bar, nav bar, rail
    items.append(("top_app_bar", "default", 400, 64, f'<rect width="400" height="64" fill="{T["surface"]}"/>', 0, "small top app bar, 64 dp"))
    items.append(("top_app_bar", "scrolled", 400, 64, f'<rect width="400" height="64" fill="{T["surface-container"]}"/>', 0, "on scroll: surface-container"))
    items.append(("navigation_bar", "default", 400, 80, f'<rect width="400" height="80" fill="{T["surface-container"]}"/>', 0, "navigation bar 80 dp"))
    items.append(("navigation_rail", "default", 80, 400, f'<rect width="80" height="400" fill="{T["surface"]}"/>', 0, "navigation rail 80 dp"))
    items.append(("scrim", "default", 32, 32, '<rect width="32" height="32" fill="#000" fill-opacity="0.32"/>', 0, "modal scrim 32 percent"))
    # badges
    items.append(("badge_small", "default", 6, 6, f'<circle cx="3" cy="3" r="3" fill="{T["badge"]}"/>', None, "small badge dot 6 dp"))
    items.append(("badge_large", "default", 16, 16, f'<rect width="16" height="16" rx="8" fill="{T["badge"]}"/>', 8, "large badge 16 dp, 9-patch for 2-3 digits, label-small on-error"))
    items.append(("scroll_fade_top", "default", 32, 32,
                  f'<defs><linearGradient id="f" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{T["surface"]}"/><stop offset="1" stop-color="{T["surface"]}" stop-opacity="0"/></linearGradient></defs><rect width="32" height="32" fill="url(#f)"/>', 0, "drawer/list scroll fade, stretch horizontally, 32 dp tall"))
    items.append(("scroll_fade_bottom", "default", 32, 32,
                  f'<defs><linearGradient id="f" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="{T["surface"]}"/><stop offset="1" stop-color="{T["surface"]}" stop-opacity="0"/></linearGradient></defs><rect width="32" height="32" fill="url(#f)"/>', 0, "bottom scroll fade"))
    for name, st, w, h, inner, nine, note in items:
        svg = svgwrap(w, h, inner)
        base = f"{name}_{st}"
        L.save_svg(os.path.join(OUT, theme, "svg", base + ".svg"), svg)
        p = os.path.join(OUT, theme, base + ".png")
        L.render(svg, (w + 8) * SC, (h + 8) * SC, p)
        nm = None if nine is None else [int((nine + 4) * SC)] * 4
        L.note(p, (w + 8) * SC, (h + 8) * SC, nm, f"{theme}: {note} ({st})")
    return items


def build():
    a = build_theme("dark", L.DARK)
    b = build_theme("light", L.LIGHT)
    return a, b


if __name__ == "__main__":
    a, b = build()
    print(len(a), len(b), "components per theme")

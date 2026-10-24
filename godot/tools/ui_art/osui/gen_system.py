"""Pre-rasterise the Material Symbols the OS needs (status bar, nav, Quick Settings, Settings rows, store, lock screen).

White on transparent at 24, 32, 48 and 96 px (tint in code with `modulate` / `self_modulate`).
  assets/ui/osui/system/<px>/<name>.png        outlined (weight 400, grade 0, optical size 24)
  assets/ui/osui/system/<px>/<name>_fill.png   filled variant, used for the "on" state of QS tiles and nav
Source SVGs stay in assets/ui/svg/material/ (Apache-2.0, see assets/ui/svg/LICENSES.md).
"""
import os
import osui_lib as L

OUT = os.path.join(L.OUT, "system")
SIZES = (24, 32, 48, 96)


def build():
    mat = os.path.join(L.SVGLIB, "material")
    names = sorted(f[:-4] for f in os.listdir(mat) if f.endswith(".svg"))
    filled = sorted(f[:-4] for f in os.listdir(os.path.join(mat, "filled")) if f.endswith(".svg"))
    for n in names:
        for px in SIZES:
            svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 24 24">{L.sym(n, 0, 0, 24, "#FFFFFF")}</svg>'
            L.render(svg, px, px, os.path.join(OUT, str(px), f"{n}.png"))
    for n in filled:
        for px in SIZES:
            svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 24 24">{L.sym(n, 0, 0, 24, "#FFFFFF", filled=True)}</svg>'
            L.render(svg, px, px, os.path.join(OUT, str(px), f"{n}_fill.png"))
    L.note(os.path.join(OUT, "<px>", "<name>.png"), 0, 0, None,
           f"Material Symbols, {len(names)} outlined + {len(filled)} filled (_fill), white, 24/32/48/96 px")
    return names, filled


if __name__ == "__main__":
    a, b = build()
    print(len(a), len(b))

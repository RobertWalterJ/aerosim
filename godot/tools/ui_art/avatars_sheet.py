"""Contact sheet for lane avatars: docs/realism/models/avatars_final_views.jpg.

Top: the whole set side by side at 36 and 48 px on light and dark (the distinctness test), also blown up 4x with nearest
filtering so the actual pixels can be judged. Below: one row per person at 512, 96, 48 and 36 px on light and dark, plus
a 36 px sample made the way Godot draws a 512 texture into a 36 px slot without mipmaps (bilinear), and the rationale.
Also writes docs/realism/models/avatars_final_textures.jpg: the palette swatches used (no photographed textures)."""
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
UI = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "ui"))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "docs", "realism", "models"))
FONTS = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "fonts"))
LIGHT = (237, 230, 211)
DARK = (14, 17, 15)
CARD = (31, 36, 31)
INKC = (27, 32, 28)
CREAMC = (240, 233, 209)


def font(sz, bold=False):
    return ImageFont.truetype(os.path.join(FONTS, "ui_sans_bold.ttf" if bold else "ui_sans.ttf"), sz)


def build(masters, cast, tiles):
    os.makedirs(OUT, exist_ok=True)
    keys = [c[0] for c in cast]
    root = {k: Image.open(os.path.join(UI, f"avatar_{k}.png")).convert("RGBA") for k in keys}
    s96 = {k: Image.open(os.path.join(UI, "sizes", "96", f"avatar_{k}.png")).convert("RGBA") for k in keys}
    s48 = {k: Image.open(os.path.join(UI, "sizes", "48", f"avatar_{k}.png")).convert("RGBA") for k in keys}
    s36 = {k: masters[k].resize((36, 36), Image.LANCZOS) for k in keys}
    g36 = {k: root[k].resize((36, 36), Image.BILINEAR, reducing_gap=None) for k in keys}   # no-mipmap approximation

    W = 1880
    top_h = 430
    row_h = 560
    H = 90 + top_h + row_h * len(keys) + 30
    im = Image.new("RGB", (W, H), DARK)
    d = ImageDraw.Draw(im)
    d.text((24, 18), "Avatars (lane avatars): illustrated emblems, not portraits", font=font(34, True), fill=CREAMC)
    d.text((24, 60), "One tile shape, border and palette; a different style family per person. Drawn in code at 2048 px, downsampled.",
           font=font(18), fill=(194, 192, 174))

    # --- distinctness strip
    y0 = 100
    for band, (bg, fg, label) in enumerate(((LIGHT, INKC, "light"), (CARD, CREAMC, "dark"))):
        yb = y0 + band * 200
        d.rectangle([20, yb, W - 20, yb + 185], fill=bg)
        d.text((34, yb + 8), f"The whole set on {label}: 36 px and 48 px at true size (left), and 36 px blown up 2.5x, nearest (right)",
               font=font(16, True), fill=fg)
        x = 34
        for k in keys:
            im.paste(s36[k], (x, yb + 40), s36[k])
            im.paste(s48[k], (x - 6, yb + 90), s48[k])
            x += 56
        x = 34 + 56 * len(keys) + 20
        for k in keys:
            big = s36[k].resize((90, 90), Image.NEAREST)
            im.paste(big, (x, yb + 40), big)
            nm = font(13)
            d.text((x + 45 - d.textlength(k, font=nm) / 2, yb + 136), k, font=nm, fill=fg)
            x += 98

    # --- one row per person
    y = 90 + top_h
    for k, person, concept, style, why in cast:
        d.rectangle([20, y, W - 20, y + row_h - 20], fill=(24, 28, 25))
        d.rectangle([30, y + 10, 30 + 532, y + 10 + 532], fill=LIGHT)
        im.paste(root[k], (40, y + 20), root[k])
        # light small set
        xl = 590
        d.rectangle([xl, y + 10, xl + 320, y + 260], fill=LIGHT)
        d.rectangle([xl, y + 280, xl + 320, y + 530], fill=CARD)
        for bgy, fg in ((y + 10, INKC), (y + 280, CREAMC)):
            xx = xl + 14
            for lab, imgs, s in (("96", s96, 96), ("48", s48, 48), ("36", s36, 36)):
                im.paste(imgs[k], (xx, bgy + 40 + (96 - s) // 2), imgs[k])
                d.text((xx, bgy + 150), lab + " px", font=font(14), fill=fg)
                xx += s + 26
            im.paste(g36[k], (xx, bgy + 40 + 30), g36[k])
            d.text((xx - 4, bgy + 150), "36 nomip", font=font(12), fill=fg)
            d.text((xl + 14, bgy + 12), "on light" if fg == INKC else "on dark", font=font(14, True), fill=fg)
            # chat row mock: 36 px avatar, a name, a line
            im.paste(s36[k], (xl + 14, bgy + 182), s36[k])
            d.text((xl + 60, bgy + 182), person.split(",")[0], font=font(15, True), fill=fg)
            d.text((xl + 60, bgy + 202), "a message line in the chat", font=font(13), fill=fg)
        tx = 945
        d.text((tx, y + 24), person, font=font(28, True), fill=CREAMC)
        d.text((tx, y + 66), f"{concept}  ·  {style}  ·  tile {tiles[k]}", font=font(18), fill=(224, 171, 89))
        words, line, ly = why.split(), "", y + 110
        for w in words:
            t = (line + " " + w).strip()
            if d.textlength(t, font=font(20)) > W - tx - 50:
                d.text((tx, ly), line, font=font(20), fill=(194, 192, 174))
                ly += 30
                line = w
            else:
                line = t
        d.text((tx, ly), line, font=font(20), fill=(194, 192, 174))
        d.text((tx, y + 480), f"assets/ui/avatar_{k}.png  ·  sizes/96, sizes/48  ·  avatars/cutout/{k}.png", font=font(15),
               fill=(153, 159, 141))
        y += row_h
    p = os.path.join(OUT, "avatars_final_views.jpg")
    im.save(p, quality=90, optimize=True)
    print("sheet", p)
    textures(tiles)
    return p


def textures(tiles):
    import build_avatars as B
    sw = [("cream", B.CREAM), ("paper", B.PAPER), ("ink", B.INK), ("ink 2", B.INK2), ("brass", B.BRASS),
          ("brass deep", B.BRASS_D), ("moss", B.MOSS), ("lake", B.LAKE), ("rust", B.RUST), ("danger red", B.RED),
          ("dim", B.DIM)] + [(f"tile {k}", v) for k, v in tiles.items()]
    cols = 6
    W, cell = 1400, 220
    rows = (len(sw) + cols - 1) // cols
    im = Image.new("RGB", (W, 120 + rows * cell), DARK)
    d = ImageDraw.Draw(im)
    d.text((24, 18), "Avatars: colours used (no photographed textures; everything is flat code-drawn colour)", font=font(26, True),
           fill=CREAMC)
    d.text((24, 58), "Source: docs/UI-STYLE.md palette plus one tile colour per person. Licence: original to this project.",
           font=font(17), fill=(194, 192, 174))
    for i, (name, hexc) in enumerate(sw):
        x = 24 + (i % cols) * 228
        y = 110 + (i // cols) * cell
        d.rounded_rectangle([x, y, x + 200, y + 150], radius=28, fill=B.hx(hexc)[:3], outline=(80, 84, 76), width=2)
        d.text((x, y + 160), f"{name}  {hexc}", font=font(16), fill=CREAMC)
    p = os.path.join(OUT, "avatars_final_textures.jpg")
    im.save(p, quality=90)
    print("sheet", p)

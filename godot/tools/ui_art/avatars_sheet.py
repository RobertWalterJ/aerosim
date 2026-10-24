"""Contact sheet for lane avatars: docs/realism/models/avatars_final_views.jpg (+ avatars_final_textures.jpg).

Top: the active set side by side at 36 and 48 px on light and dark (the distinctness test), also blown up 2.5x with
nearest filtering. Then one row per person: 512, 96, 48, 36 px on light and dark, the 36 px circle the chat's round
holder shows, a 36 px sample made the way Godot draws a 512 texture without mipmaps, the rationale and the source and
licence. Last: the alternate set (round-1 emblems) so both sets are on one sheet."""
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
DIMC = (194, 192, 174)
BRASSC = (224, 171, 89)


def font(sz, bold=False):
    return ImageFont.truetype(os.path.join(FONTS, "ui_sans_bold.ttf" if bold else "ui_sans.ttf"), sz)


def roundel(img, s):
    """What UniverseUI.avatar() looks like at s px: the image in a circle."""
    im = img.resize((s * 4, s * 4), Image.LANCZOS)
    m = Image.new("L", im.size, 0)
    ImageDraw.Draw(m).ellipse([0, 0, im.size[0] - 1, im.size[1] - 1], fill=255)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(im, (0, 0), m)
    return out.resize((s, s), Image.LANCZOS)


def wrap(d, text, x, y, width, f, fill, lh):
    line = ""
    for w in text.split():
        t = (line + " " + w).strip()
        if d.textlength(t, font=f) > width:
            d.text((x, y), line, font=f, fill=fill)
            y += lh
            line = w
        else:
            line = t
    d.text((x, y), line, font=f, fill=fill)
    return y + lh


def info(k, active):
    import avatars_eclectic as E
    import build_avatars as B
    person = next(p for kk, p, *_ in B.CAST if kk == k)
    if active == "eclectic":
        return (person,) + tuple(E.CAST[k])
    for kk, p, concept, style, why in B.CAST:
        if kk == k:
            return person, concept, style + " emblem", "drawn in code (own work)", "original", why


def build(masters_by_set, active):
    import build_avatars as B
    os.makedirs(OUT, exist_ok=True)
    keys = list(B.TILE)
    alt = [s for s in masters_by_set if s != active][0]
    root = {k: Image.open(os.path.join(UI, f"avatar_{k}.png")).convert("RGBA") for k in keys}
    s96 = {k: Image.open(os.path.join(UI, "sizes", "96", f"avatar_{k}.png")).convert("RGBA") for k in keys}
    s48 = {k: Image.open(os.path.join(UI, "sizes", "48", f"avatar_{k}.png")).convert("RGBA") for k in keys}
    s36 = {k: masters_by_set[active][k].resize((36, 36), Image.LANCZOS) for k in keys}
    r36 = {k: roundel(masters_by_set[active][k], 36) for k in keys}
    g36 = {k: root[k].resize((36, 36), Image.BILINEAR, reducing_gap=None) for k in keys}

    W, top_h, row_h, alt_h = 1880, 420, 560, 380
    H = 100 + top_h + row_h * len(keys) + alt_h
    im = Image.new("RGB", (W, H), DARK)
    d = ImageDraw.Draw(im)
    d.text((24, 18), f"Avatars (lane avatars): active set '{active}', alternate set '{alt}'", font=font(34, True), fill=CREAMC)
    d.text((24, 62), "Active: pictures each person might upload themselves (photos, cartoons, logos, pixel). Same files and "
           "sizes, no code change. Switch: python build_avatars.py --switch " + alt, font=font(18), fill=DIMC)

    y0 = 104
    for band, (bg, fg, label) in enumerate(((LIGHT, INKC, "light"), (CARD, CREAMC, "dark"))):
        yb = y0 + band * 200
        d.rectangle([20, yb, W - 20, yb + 185], fill=bg)
        d.text((34, yb + 8), f"Active set on {label}: square 36 and 48 px, then the 36 px round holder (left); 36 px blown up "
               "2.5x, nearest (right)", font=font(16, True), fill=fg)
        x = 34
        for k in keys:
            im.paste(s36[k], (x, yb + 36), s36[k])
            im.paste(s48[k], (x - 6, yb + 80), s48[k])
            im.paste(r36[k], (x, yb + 138), r36[k])
            x += 56
        x = 34 + 56 * len(keys) + 20
        for k in keys:
            big = s36[k].resize((90, 90), Image.NEAREST)
            im.paste(big, (x, yb + 40), big)
            d.text((x + 45 - d.textlength(k, font=font(13)) / 2, yb + 136), k, font=font(13), fill=fg)
            x += 98

    y = 100 + top_h
    for k in keys:
        person, what, kind, src, lic, why = info(k, active)
        d.rectangle([20, y, W - 20, y + row_h - 20], fill=(24, 28, 25))
        d.rectangle([30, y + 10, 30 + 532, y + 10 + 532], fill=LIGHT)
        im.paste(root[k], (40, y + 20), root[k])
        xl = 590
        for bgy, bgc, fg in ((y + 10, LIGHT, INKC), (y + 280, CARD, CREAMC)):
            d.rectangle([xl, bgy, xl + 330, bgy + 250], fill=bgc)
            d.text((xl + 14, bgy + 12), "on light" if fg == INKC else "on dark", font=font(14, True), fill=fg)
            xx = xl + 14
            for lab, imgs, s in (("96", s96, 96), ("48", s48, 48), ("36", s36, 36)):
                im.paste(imgs[k], (xx, bgy + 40 + (96 - s) // 2), imgs[k])
                d.text((xx, bgy + 150), lab + " px", font=font(14), fill=fg)
                xx += s + 24
            im.paste(g36[k], (xx, bgy + 70), g36[k])
            d.text((xx - 6, bgy + 150), "36 nomip", font=font(12), fill=fg)
            im.paste(r36[k], (xl + 14, bgy + 184), r36[k])
            d.text((xl + 60, bgy + 182), person.split(",")[0], font=font(15, True), fill=fg)
            d.text((xl + 60, bgy + 202), "round holder, as in the chat", font=font(13), fill=fg)
        tx = 950
        d.text((tx, y + 24), person, font=font(28, True), fill=CREAMC)
        d.text((tx, y + 66), f"{what}  ·  {kind}", font=font(19), fill=BRASSC)
        ny = wrap(d, why, tx, y + 108, W - tx - 50, font(20), DIMC, 30)
        wrap(d, f"Source: {src}. Licence: {lic}.", tx, ny + 14, W - tx - 50, font(16), (153, 159, 141), 24)
        d.text((tx, y + 480), f"assets/ui/avatar_{k}.png  ·  sizes/96|48  ·  avatars/cutout/{k}.png  ·  "
               f"alternate: avatars_alt/{k}_{alt}.png", font=font(14), fill=(153, 159, 141))
        y += row_h

    d.rectangle([20, y, W - 20, y + alt_h - 30], fill=(24, 28, 25))
    d.text((34, y + 12), f"Alternate set '{alt}' (kept in assets/ui/avatars_alt/), 128 px and 36 px", font=font(22, True),
           fill=CREAMC)
    x = 34
    for k in keys:
        a = masters_by_set[alt][k]
        t = a.resize((128, 128), Image.LANCZOS)
        im.paste(t, (x, y + 56), t)
        t36 = a.resize((36, 36), Image.LANCZOS)
        im.paste(t36, (x + 46, y + 196), t36)
        d.text((x + 64 - d.textlength(k, font=font(14)) / 2, y + 244), k, font=font(14), fill=DIMC)
        x += 166
    d.text((34, y + 290), f"Switch with  python build_avatars.py --switch {alt}  (copies avatars_alt/*_{alt}.png over the "
           f"active files; --switch {active} switches back).", font=font(17), fill=DIMC)
    p = os.path.join(OUT, "avatars_final_views.jpg")
    im.save(p, quality=90, optimize=True)
    print("sheet", p)
    textures()
    return p


def textures():
    """Sources sheet: the photographs and textures actually used, with source and licence."""
    import avatars_eclectic as E
    items = [("cumulus.jpg", "Sam"), ("sunrise_field.jpg", "You"), ("woodland_trail.jpg", "Wren"),
             ("tom_photo.jpg", "Tom: NOAA nssl0232, PD"), ("storm_cloud.jpg", "Tom alt composite, sky")]
    W = 1880
    im = Image.new("RGB", (W, 760), DARK)
    d = ImageDraw.Draw(im)
    d.text((24, 18), "Avatars: photographs and textures used (all CC0 or own work)", font=font(28, True), fill=CREAMC)
    d.text((24, 58), "Panorama crops made by tools/ui_art/avatar_photo_prep.py from Poly Haven HDRIs by Greg Zaal (CC0); "
           "list in tools/ui_art/avatar_sources/SOURCES.md", font=font(17), fill=DIMC)
    x = 24
    for f, who in items:
        t = Image.open(os.path.join(E.SRC, f)).convert("RGB").resize((340, 340), Image.LANCZOS)
        im.paste(t, (x, 100))
        d.text((x, 450), f"{f}  ·  {who}", font=font(16), fill=CREAMC)
        x += 366
    wood = Image.open(os.path.join(E.TEX, "barnwood_diff.jpg")).convert("RGB").resize((340, 200))
    im.paste(wood, (24, 500))
    d.text((24, 710), "barnwood_diff.jpg (Poly Haven wood_planks_grey, Rob Tuytel, CC0): Alex's bench", font=font(16), fill=CREAMC)
    r = Image.open(os.path.join(UI, "items", "cutout", "raptor.png")).convert("RGBA").resize((200, 200))
    im.paste(r, (760, 500), r)
    d.text((760, 710), "items/cutout/raptor.png (appui2 render, own work): Alex's drone", font=font(16), fill=CREAMC)
    p = os.path.join(OUT, "avatars_final_textures.jpg")
    im.save(p, quality=90)
    print("sheet", p)

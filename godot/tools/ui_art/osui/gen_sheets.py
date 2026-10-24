"""Contact sheets for lane osui: component sheets, the icon/HUD sheet, osui_final_views.jpg and osui_final_textures.jpg."""
import os, glob
from PIL import Image, ImageDraw, ImageFont
import osui_lib as L
import gen_map as M
import gen_hud as Hd

F = lambda sz, b=False: ImageFont.truetype(os.path.join(L.FONTDIR, "Roboto-Medium.ttf" if b else "Roboto-Regular.ttf"), sz)
SHEETS = os.path.join(L.DOCS, "realism", "models")


def component_sheet(theme):
    T = L.DARK if theme == "dark" else L.LIGHT
    d = os.path.join(L.OUT, "components", theme)
    files = sorted(glob.glob(os.path.join(d, "*.png")))
    groups = {}
    for f in files:
        base = os.path.basename(f)[:-4]
        name, st = base.rsplit("_", 1)
        groups.setdefault(name, []).append((st, f))
    W = 2400
    x, y, rowh = 20, 70, 0
    canvas = Image.new("RGB", (W, 14000), T["surface"])
    dr = ImageDraw.Draw(canvas)
    dr.text((20, 18), f"Material 3 component kit ({theme}) - assets/ui/osui/components/{theme}/  (2x renders; states left to right)", fill=T["on-surface"], font=F(26, True))
    for name, items in groups.items():
        ims = [(st, Image.open(f)) for st, f in items]
        gw = sum(min(im.width, 720) for _, im in ims) + 16 * len(ims) + 20
        gh = max(min(im.height, 420) for _, im in ims) + 54
        if x + gw > W:
            x, y = 20, y + rowh + 16
            rowh = 0
        dr.text((x, y), name, fill=T["primary"], font=F(18, True))
        xx = x
        for st, im in ims:
            if im.width > 720 or im.height > 420:
                im.thumbnail((720, 420))
            canvas.paste(im, (xx, y + 26), im)
            dr.text((xx, y + 30 + im.height), st, fill=T["on-surface-variant"], font=F(14))
            xx += im.width + 16
        x += gw
        rowh = max(rowh, gh + 10)
    canvas = canvas.crop((0, 0, W, y + rowh + 20))
    p = os.path.join(L.REAL, f"70_component_sheet_{theme}.jpg")
    canvas.save(p, quality=90)
    return p


def icon_sheet():
    W = 2400
    canvas = Image.new("RGB", (W, 2300), (24, 28, 24))
    dr = ImageDraw.Draw(canvas)
    keys = sorted(os.path.basename(f)[:-4] for f in glob.glob(os.path.join(L.OUT, "icons", "circle", "*.png")))
    dr.text((20, 16), "App icons (assets/ui/osui/icons/): circle 128, squircle 96, themed dark 96, themed light 96, mono 48, layers bg/fg/mono", fill="#F0E9D1", font=F(24, True))
    cw = W // len(keys)
    for i, k in enumerate(keys):
        x = i * cw + 8
        for j, (sub, sz) in enumerate((("circle/128", 128), ("squircle/96", 96), ("themed/dark/96", 96), ("themed/light/96", 96), ("mono/48", 48))):
            im = Image.open(os.path.join(L.OUT, "icons", *sub.split("/"), k + ".png"))
            if "light" in sub:
                canvas.paste(Image.new("RGB", (cw - 6, 104), "#FCF8EF"), (x - 4, 64 + 136 + 104 * 2 - 4))
            canvas.paste(im, (x + (cw - 16 - im.width) // 2, 64 + [0, 136, 240, 344, 450][j]), im)
        for j, ln in enumerate(("bg", "fg", "mono")):
            im = Image.open(os.path.join(L.OUT, "icons", "layers", f"{k}_{ln}.png")).resize((44, 44))
            bgc = Image.new("RGB", (44, 44), (60, 64, 58)); bgc.paste(im, (0, 0), im)
            canvas.paste(bgc, (x + j * 46, 510))
        dr.text((x, 562), k, fill="#C8C4B0", font=F(15))
    y0 = 610
    dr.text((20, y0), f"Flight HUD set (assets/ui/osui/hud/): {len(Hd.G)} glyphs; button states default / pressed / active / disabled at 64 px; glyph 48 and 24", fill="#F0E9D1", font=F(24, True))
    names = list(Hd.G)
    cols = 10
    for i, n in enumerate(names):
        x, y = 20 + (i % cols) * 238, y0 + 50 + (i // cols) * 150
        bg = Image.new("RGB", (232, 140), (92, 104, 84))
        canvas.paste(bg, (x, y))
        for j, st in enumerate(("default", "pressed", "active", "disabled")):
            im = Image.open(os.path.join(L.OUT, "hud", "button", st, "48", n + ".png"))
            canvas.paste(im, (x + 6 + j * 56, y + 6), im)
        g = Image.open(os.path.join(L.OUT, "hud", "glyph", "48", n + ".png")); canvas.paste(g, (x + 8, y + 62), g)
        g = Image.open(os.path.join(L.OUT, "hud", "glyph", "24", n + ".png")); canvas.paste(g, (x + 66, y + 74), g)
        dr.text((x + 100, y + 80), n, fill="#FFFFFF", font=F(15))
    y1 = y0 + 50 + ((len(names) + cols - 1) // cols) * 150 + 10
    dr.text((20, y1), "Camera-mode buttons with key-hint chips, palette chips, mode tags, shade hint, drawer handle", fill="#F0E9D1", font=F(24, True))
    x = 20
    bg = Image.new("RGB", (W - 40, 220), (92, 104, 84)); canvas.paste(bg, (20, y1 + 40))
    for n in ("thermal", "night"):
        for st in ("default", "pressed", "active", "disabled"):
            im = Image.open(os.path.join(L.OUT, "hud", "button", st, "64", n + "_key.png")); canvas.paste(im, (x + 10, y1 + 50), im); x += 74
    for f in sorted(glob.glob(os.path.join(L.OUT, "hud", "chip", "*.png"))):
        im = Image.open(f).resize((72, 42)); canvas.paste(im, (x + 10, y1 + 60), im); x += 80
    x = 30
    for f in sorted(glob.glob(os.path.join(L.OUT, "hud", "tag", "tag_*.png"))):
        if f.endswith("_bg.png"):
            continue
        im = Image.open(f)
        if x + im.width > W - 300:
            break
        canvas.paste(im, (x, y1 + 140), im); x += im.width + 10
    for i, f in enumerate(("shade_hint_2x.png", "handle_up_2x.png", "handle_down_2x.png")):
        im = Image.open(os.path.join(L.OUT, "hud", "pill", f)); canvas.paste(im, (W - 600 + i * 0 + (0 if i == 0 else 340), y1 + 200 - (60 if i else 0) + (i - 1) * 70 if i else y1 + 60), im)
    canvas = canvas.crop((0, 0, W, y1 + 280))
    p = os.path.join(L.REAL, "71_icon_and_hud_sheet.jpg")
    canvas.save(p, quality=90)
    return p


def views_sheet():
    mocks = sorted(glob.glob(os.path.join(L.REAL, "[1-6]*.jpg")))
    W = 2400
    cell_w = 590
    tiles = []
    for p in mocks:
        im = Image.open(p).convert("RGB")
        im.thumbnail((cell_w, 330))
        tiles.append((os.path.basename(p), im))
    rows = []
    x, y, rowh = 10, 60, 0
    canvas = Image.new("RGB", (W, 6000), (20, 22, 20))
    dr = ImageDraw.Draw(canvas)
    dr.text((10, 14), "Lane osui - final views: tablet 1920x1080, phone 1080x2400, HUD 16:9 and 20:9 (docs/realism/osui/)", fill="#F0E9D1", font=F(28, True))
    for name, im in tiles:
        if x + im.width > W:
            x, y = 10, y + rowh + 40
            rowh = 0
        canvas.paste(im, (x, y))
        dr.text((x, y + im.height + 4), name, fill="#C8C4B0", font=F(17))
        x += im.width + 12
        rowh = max(rowh, im.height)
    y += rowh + 50
    for extra in ("71_icon_and_hud_sheet.jpg", "70_component_sheet_dark.jpg"):
        im = Image.open(os.path.join(L.REAL, extra)).convert("RGB")
        im.thumbnail((W - 20, 1800))
        canvas.paste(im, (10, y)); y += im.height + 20
    canvas = canvas.crop((0, 0, W, y))
    p = os.path.join(SHEETS, "osui_final_views.jpg")
    canvas.save(p, quality=86)
    return p


def textures_sheet():
    W = 2400
    canvas = Image.new("RGB", (W, 3000), (250, 247, 240))
    dr = ImageDraw.Draw(canvas)
    dr.text((20, 16), "Lane osui - textures, colour tokens and sources (everything is generated vector art; no photo textures)", fill="#1D1C16", font=F(28, True))
    y = 70
    for theme, T in (("dark", L.DARK), ("light", L.LIGHT)):
        dr.text((20, y), f"Material 3 colour roles, {theme} (warm field-kit palette)", fill="#1D1C16", font=F(22, True)); y += 36
        x = 20
        for k, v in T.items():
            if x + 180 > W:
                x, y = 20, y + 96
            dr.rectangle((x, y, x + 168, y + 54), fill=v, outline="#00000030")
            dr.text((x, y + 58), k, fill="#1D1C16", font=F(13)); dr.text((x, y + 74), v, fill="#55524A", font=F(12))
            x += 178
        y += 120
    for theme in ("light", "dark"):
        dr.text((20, y), f"Map style '{theme}' (assets/ui/osui/map/map_style.json)", fill="#1D1C16", font=F(22, True)); y += 36
        x = 20
        for k, v in M.STYLE[theme].items():
            if not isinstance(v, str):
                continue
            if x + 150 > W:
                x, y = 20, y + 86
            dr.rectangle((x, y, x + 140, y + 46), fill=v, outline="#00000030")
            dr.text((x, y + 50), k, fill="#1D1C16", font=F(12)); dr.text((x, y + 64), v, fill="#55524A", font=F(11))
            x += 150
        y += 100
    dr.text((20, y), "POI category colours", fill="#1D1C16", font=F(22, True)); y += 36
    x = 20
    for cat, (col, ics) in M.CATEGORIES.items():
        im = Image.open(os.path.join(L.OUT, "map", "marker", f"{cat}_{ics[0]}.png"))
        canvas.paste(im, (x, y), im)
        dr.text((x + 56, y + 6), cat, fill="#1D1C16", font=F(15)); dr.text((x + 56, y + 26), col, fill="#55524A", font=F(12))
        x += 200
    y += 80
    dr.text((20, y), "Thermal / night palettes (HUD chips)", fill="#1D1C16", font=F(22, True)); y += 36
    x = 20
    for n in Hd.PALETTES:
        im = Image.open(os.path.join(L.OUT, "hud", "chip", f"palette_{n}.png")).resize((144, 84))
        canvas.paste(im, (x, y), im); dr.text((x, y + 88), n, fill="#1D1C16", font=F(14)); x += 170
    y += 130
    dr.text((20, y), "Map base raster (light and dark), computed from the valley heightmap, cover map and lake mask", fill="#1D1C16", font=F(22, True)); y += 36
    for i, th in enumerate(("light", "dark")):
        im = M.base_raster(-700, -400, 560, 600, 560, 444, th)
        canvas.paste(im, (20 + i * 580, y))
    y += 460
    rows = [("Material Symbols", "Google, github.com/google/material-design-icons", "Apache-2.0"),
            ("Lucide", "lucide-static@0.460.0", "ISC"), ("Tabler Icons", "@tabler/icons@3.19.0", "MIT"),
            ("Phosphor", "@phosphor-icons/core@2.1.1", "MIT"), ("Maki", "@mapbox/maki@8.0.1", "CC0-1.0"),
            ("Temaki", "@rapideditor/temaki@5.8.0", "CC0-1.0"), ("Roboto", "googlefonts/roboto (hinted)", "Apache-2.0"),
            ("Roboto Mono", "googlefonts/RobotoMono", "OFL-1.1"),
            ("Wallpaper in mocks", "Mt. Toby Farm, Lance Cheung / USDA NRCS (notify lane)", "Public domain"),
            ("Lane art (icons, HUD, components, markers, map)", "tools/ui_art/osui/*.py, this lane", "project original")]
    dr.text((20, y), "Sources and licences (full table: assets/ui/svg/LICENSES.md)", fill="#1D1C16", font=F(22, True)); y += 36
    for a, b, c in rows:
        dr.text((20, y), a, fill="#1D1C16", font=F(16, True)); dr.text((520, y), b, fill="#1D1C16", font=F(16)); dr.text((1500, y), c, fill="#1D1C16", font=F(16)); y += 26
    canvas = canvas.crop((0, 0, W, y + 20))
    p = os.path.join(SHEETS, "osui_final_textures.jpg")
    canvas.save(p, quality=90)
    return p


def build():
    out = [component_sheet("dark"), component_sheet("light"), icon_sheet(), views_sheet(), textures_sheet()]
    for o in out:
        print(o)


if __name__ == "__main__":
    build()

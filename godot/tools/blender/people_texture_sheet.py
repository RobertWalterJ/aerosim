# "Textures used" contact sheet for the people (system Python with Pillow):
#   python people_texture_sheet.py <out.jpg>
# Swatches of every texture applied: the Poly Haven fabrics (albedo and normal), and per person the skin, hair and the
# clothes atlas actually embedded in the .glb, each labelled with name, source and licence.
import os, sys, json, ast
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", "_tools", "people"))
FAB = os.path.join(TOOLS, "fabric")
TC = os.path.join(TOOLS, "texcache")
out = sys.argv[1]

# the roster, read without Blender
src = open(os.path.join(HERE, "people_roster.py"), encoding="utf8").read()
ns = {}
exec(compile(src, "people_roster.py", "exec"), ns)
ROSTER = ns["ROSTER"]
CCBY = {"elvs_": "Elvaerwyn, CC BY", "mindfront_": "Mindfront, CC BY 4.0", "punkduck_": "punkduck, CC BY"}

def lic(asset):
    for k, v in CCBY.items():
        if asset.startswith(k):
            return v
    return "MakeHuman, CC0"

try:
    F = ImageFont.truetype("arial.ttf", 13); FB = ImageFont.truetype("arialbd.ttf", 15); FT = ImageFont.truetype("arialbd.ttf", 24)
except Exception:
    F = FB = FT = ImageFont.load_default()

S = 150
cells = []   # (title, [(image path, small caption)], lines)
fab_used = {}
for p in ROSTER.values():
    for g in p.get("clothes", []):
        if g.get("fabric"):
            fab_used.setdefault(g["fabric"], set()).add(p["name"])
for f in ("terlenka", "poly_wool_herringbone", "knitted_fleece", "brown_leather"):
    fab_used.setdefault(f, set()).add("gear")
for f in sorted(fab_used):
    info = json.load(open(os.path.join(FAB, f + ".json")))
    au = ", ".join(info.get("authors", {}).keys())
    cells.append((f, [(os.path.join(FAB, f + "_diff.jpg"), "albedo"), (os.path.join(FAB, f + "_nor.jpg"), "normal")],
                  ["Poly Haven, CC0", au[:34], "polyhaven.com/a/" + f]))
people_cells = []
for nm, p in ROSTER.items():
    ims = [(os.path.join(TC, f"{nm}_skin.jpg"), "skin: " + p["skin"][:16]),
           (os.path.join(TC, f"{nm}_hair.png"), "hair: " + p.get("hair", {}).get("asset", "-")[:16]),
           (os.path.join(TC, f"{nm}_cloth_diff.jpg"), "clothes atlas"),
           (os.path.join(TC, f"{nm}_cloth_nor.jpg"), "atlas normal")]
    lines = []
    for g in p.get("clothes", []):
        lines.append(f"{g['asset'][:30]} ({lic(g['asset'])})" + (f" + {g['fabric']}" if g.get("fabric") else ""))
    for e in p.get("extras", []):
        lines.append(f"{e} (modelled, original)")
    lines.append(f"skin, eyes ({p.get('eye_color', 'brown')}), brows, lashes: MakeHuman, CC0")
    people_cells.append((nm, ims, lines))

def draw_block(d, sheet, x, y, title, ims, lines, w):
    d.text((x, y), title, fill=(240, 240, 240), font=FB)
    yy = y + 20
    for i, (path, cap) in enumerate(ims):
        xx = x + i * (S + 6)
        if os.path.exists(path):
            im = Image.open(path)
            if im.mode == "RGBA":
                bg = Image.new("RGBA", im.size, (90, 90, 90, 255)); bg.alpha_composite(im); im = bg
            sheet.paste(im.convert("RGB").resize((S, S)), (xx, yy))
        d.text((xx, yy + S + 2), cap, fill=(200, 200, 200), font=F)
    ly = yy + S + 20
    for l in lines:
        d.text((x, ly), l, fill=(185, 185, 185), font=F)
        ly += 15
    return ly

colw = 4 * (S + 6) + 30
fab_w = 2 * (S + 6) + 20
fab_cols = 7
fab_rows = (len(cells) + fab_cols - 1) // fab_cols
pcols = 4
prows = (len(people_cells) + pcols - 1) // pcols
row_h_fab = 20 + S + 20 + 3 * 15 + 18
row_h_p = 20 + S + 20 + 7 * 15 + 18
W = max(fab_cols * fab_w, pcols * colw) + 20
H = 60 + 30 + fab_rows * row_h_fab + 40 + prows * row_h_p
sheet = Image.new("RGB", (W, H), (24, 24, 26))
d = ImageDraw.Draw(sheet)
d.text((12, 12), "People (Blender 2): every texture and material applied", fill=(240, 240, 240), font=FT)
y = 60
d.text((12, y), "Photographed fabrics blended into the clothes (weave, normal, roughness), tiled; one repeat about 0.27 m", fill=(220, 200, 150), font=FB)
y += 30
for i, (t, ims, lines) in enumerate(cells):
    draw_block(d, sheet, 12 + (i % fab_cols) * fab_w, y + (i // fab_cols) * row_h_fab, t, ims, lines, fab_w)
y += fab_rows * row_h_fab + 10
d.text((12, y), "Per person, as embedded in assets/models/people/<person>.glb (skin, hair, clothes atlas and its normal map)", fill=(220, 200, 150), font=FB)
y += 30
for i, (t, ims, lines) in enumerate(people_cells):
    draw_block(d, sheet, 12 + (i % pcols) * colw, y + (i // pcols) * row_h_p, t, ims, lines, colw)
sheet.save(out, quality=85)
print("wrote", out, sheet.size)

# "Textures used" sheet for Constable Rennick (lane/rennick), system Python with Pillow:
#   python rennick_texture_sheet.py <out.jpg>
# Per variant, the textures embedded in its .glb (skin, hair, eyes, clothes atlas and its normal map), the ghost's drained
# versions beside the 1984 originals, the Poly Haven fabrics behind the clothes, and the fictional emblem. Each is labelled
# with its source and licence.
import os, sys, json
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", "_tools", "people"))
FAB = os.path.join(TOOLS, "fabric")
TC = os.path.join(TOOLS, "texcache")
out = sys.argv[1]
try:
    F = ImageFont.truetype("arial.ttf", 14); FB = ImageFont.truetype("arialbd.ttf", 17); FT = ImageFont.truetype("arialbd.ttf", 26)
except Exception:
    F = FB = FT = ImageFont.load_default()
S = 210
def tile(path):
    if not os.path.exists(path):
        im = Image.new("RGB", (S, S), (60, 20, 20)); ImageDraw.Draw(im).text((8, 8), "missing", fill=(255, 200, 200), font=F)
        return im
    im = Image.open(path)
    if im.mode == "RGBA":
        bg = Image.new("RGBA", im.size, (110, 110, 110, 255)); bg.alpha_composite(im); im = bg
    return im.convert("RGB").resize((S, S))

def eye(name):
    c = [os.path.join(TC, f) for f in os.listdir(TC) if f.startswith("eye_brown_")]
    return c[0] if c else ""

rows = []
for nm, label, extra in (
        ("rennick", "rennick (plain clothes)", "toigo_female_double-breasted_suit, toigo_ankle_boots_female (MRT, CC0)"),
        ("rennick_uniform", "rennick_uniform (today)", "elvs_hooded_sweat_jacket1 (Elvaerwyn, CC BY); cortu_cargo_pants (CC0); mindfront_shoes_biker_boots_female (Mindfront, CC BY 4.0); cap, belt, radio, torch, flashes modelled (original)"),
        ("rennick_1984", "rennick_1984", "toigo_female_suit_2, toigo_ankle_boots_male (MRT, CC0); cap, leather duty belt, radio, torch modelled (original)")):
    rows.append((label, [(os.path.join(TC, f"{nm}_skin.jpg"), "skin, tone 2"),
                         (os.path.join(TC, f"{nm}_hair.png"), "hair afro01, cropped"),
                         (eye(nm), "eyes, iris darker"),
                         (os.path.join(TC, f"{nm}_cloth_diff.jpg"), "clothes atlas, albedo"),
                         (os.path.join(TC, f"{nm}_cloth_nor.jpg"), "clothes atlas, normal"),
                         (os.path.join(TC, f"{nm}_cloth_orm.jpg"), "atlas ORM")],
                 ["Skin, hair, eyes, brows, lashes: MakeHuman (CC0). " + extra]))
g = "rennick_1984_ghost_"
rows.append(("rennick_1984_ghost (the 1984 textures drained: pale, faintly cool, own tones kept)",
             [(os.path.join(TC, g + "rennick_1984_skin.jpg"), "ghost skin"),
              (os.path.join(TC, g + "rennick_1984_hair.png"), "ghost hair"),
              (os.path.join(TC, g + os.path.basename(eye("x"))), "ghost eyes (grey iris)"),
              (os.path.join(TC, g + "rennick_1984_cloth_diff.jpg"), "ghost clothes atlas"),
              (os.path.join(TC, "rennick_1984_capbadge_diff.jpg"), "1984 cap badge"),
              (os.path.join(TC, "rennick_uniform_flash_diff.jpg"), "sleeve flash (emblem)")],
             ["Derived from the 1984 textures by tools/blender/people_rennick.py (ghostify). Emblem: fictional Halloway "
              "constabulary lantern, drawn in code, original, no lettering."]))
fabs = [("caban", "jacket, 1984 tunic, cap crowns"), ("poly_wool_herringbone", "trousers"),
        ("stretch_poplin", "soft-shell jacket, cap bands"), ("brown_leather", "boots, 1984 belt"), ("terlenka", "modern nylon belt")]
W = 6 * (S + 10) + 30
H = 70 + len(rows) * (S + 90) + 60 + (S + 80)
sheet = Image.new("RGB", (W, H), (24, 24, 26))
d = ImageDraw.Draw(sheet)
d.text((14, 14), "Constable Rennick (lane/rennick): every texture applied, with source and licence", fill=(240, 240, 240), font=FT)
y = 64
for label, ims, lines in rows:
    d.text((14, y), label, fill=(235, 210, 150), font=FB)
    for i, (p, cap) in enumerate(ims):
        x = 14 + i * (S + 10)
        sheet.paste(tile(p), (x, y + 24))
        d.text((x, y + 26 + S), cap, fill=(205, 205, 205), font=F)
    yy = y + 46 + S
    for l in lines:
        d.text((14, yy), l[:190], fill=(180, 180, 180), font=F); yy += 16
    y += S + 90
d.text((14, y), "Poly Haven fabrics blended into her clothes (albedo shown; normal and roughness also used). All CC0.", fill=(235, 210, 150), font=FB)
y += 26
for i, (f, use) in enumerate(fabs):
    x = 14 + i * (S + 10)
    sheet.paste(tile(os.path.join(FAB, f + "_diff.jpg")), (x, y))
    info = json.load(open(os.path.join(FAB, f + ".json"))) if os.path.exists(os.path.join(FAB, f + ".json")) else {}
    au = ", ".join(info.get("authors", {}).keys())
    d.text((x, y + S + 2), f, fill=(225, 225, 225), font=FB)
    d.text((x, y + S + 22), use, fill=(190, 190, 190), font=F)
    d.text((x, y + S + 38), ("CC0. " + au)[:30], fill=(170, 170, 170), font=F)
sheet.save(out, quality=88)
print("wrote", out, sheet.size)

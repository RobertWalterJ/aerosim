# The "textures used" contact sheet: labelled swatches of every texture the Blender animals and wildlife props use, with
# the source and licence. System Python with Pillow (not Blender):
#   python tools/blender/sheet_textures.py  -> docs/realism/models/animals_final_textures.jpg
import os, glob, json
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.normpath(os.path.join(HERE, "..", ".."))
WORK = os.path.join(os.environ.get("TEMP", "."), "aerosim_animals")
CACHE = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", "_tools", "blender-cache", "polyhaven"))
TEX = os.path.join(GODOT, "assets", "textures")
OUT = os.path.join(GODOT, "docs", "realism", "models", "animals_final_textures.jpg")

ANIMALS = ["cow_a", "cow_b", "cow_c", "calf_a", "sheep_a", "sheep_b", "lamb_a", "ram_a", "horse_a", "horse_b", "chicken_a",
           "dog_a", "biscuit_a", "lost_dog_a", "wolf_a", "wolf_collar_a"]
COATS = {"cow_a": "Holstein", "cow_b": "Hereford", "cow_c": "Jersey", "calf_a": "Holstein calf", "sheep_a": "Suffolk ewe",
         "sheep_b": "white-faced ewe", "lamb_a": "Suffolk lamb", "ram_a": "horned ram", "horse_a": "bay", "horse_b": "dapple grey",
         "chicken_a": "brown hen", "dog_a": "black and white collie", "biscuit_a": "sable and white collie cross",
         "lost_dog_a": "golden retriever", "wolf_a": "grey agouti wolf", "wolf_collar_a": "wolf, tracking collar"}
DETAIL = {"cow_a": "velour, leather", "sheep_a": "velour, curly fleece, leather", "chicken_a": "velour, leather"}

def font(sz):
    for f in ("C:/Windows/Fonts/segoeui.ttf", "C:/Windows/Fonts/arial.ttf"):
        if os.path.exists(f): return ImageFont.truetype(f, sz)
    return ImageFont.load_default()

def thumb(path, s):
    im = Image.open(path).convert("RGB")
    return im.resize((s, s), Image.LANCZOS)

def main():
    S = 180; PAD = 10
    cells = []          # (image, title, lines)
    for a in ANIMALS:
        d = os.path.join(WORK, a)
        for k in ("albedo", "normal", "orm"):
            p = os.path.join(d, "%s_%s.jpg" % (a, k))
            if not os.path.exists(p): continue
            det = "velour" + ("+fleece" if a.startswith(("sheep", "lamb", "ram")) else "") + "+leather"
            cells.append((thumb(p, S), "%s %s" % (a, k), [COATS[a] + ", Blender bake", "coat paint: own work, CC0",
                                                           ("detail: PH %s, CC0" % det) if k != "orm" else "r 1, g roughness, b metal 0"]))
    for pid, use, by in (("velour_velvet", "coat detail", "colormass, Rico Cilliers"), ("curly_teddy_natural", "wool detail", "colormass, Rico Cilliers"),
                         ("brown_leather", "bare skin detail", "Rob Tuytel")):
        for k in ("diff", "nor"):
            p = os.path.join(CACHE, "%s_%s.jpg" % (pid, k))
            if os.path.exists(p):
                cells.append((thumb(p, S), "%s %s" % (pid, k), ["Poly Haven, CC0", by, use]))
    for nm, src, use in (("barnwood", "Poly Haven wood_planks_grey", "pen boards, gates, sign"), ("postwood", "Poly Haven rough_wood", "posts, stump"),
                         ("straw", "Poly Haven riet_01", "hay and straw"), ("wool", "Poly Haven curly_teddy_natural", "wool on the wire"),
                         ("roofsteel", "Poly Haven corrugated_iron", "wire, straps")):
        p = os.path.join(TEX, nm + "_diff.jpg")
        if os.path.exists(p):
            cells.append((thumb(p, S), "%s (props)" % nm, [src, "CC0", use]))
    for p in sorted(glob.glob(os.path.join(WORK, "props", "*_albedo.png"))):
        n = os.path.basename(p).replace("_albedo.png", "")
        im = Image.open(p).convert("RGBA"); bg = Image.new("RGBA", im.size, (150, 130, 100, 255)); bg.alpha_composite(im)
        cells.append((bg.convert("RGB").resize((S, S)), n + " decal", ["generated print map", "own work, CC0", "damp mud, alpha cut-out"]))
    for p in sorted(glob.glob(os.path.join(GODOT, "assets", "models", "animals", "*_eye_*.jpg")))[:4]:
        cells.append((thumb(p, S), os.path.basename(p), ["generated eye map", "own work, CC0", "iris and pupil"]))
    plain = [("brass", (199, 143, 61)), ("zinc", (158, 160, 163)), ("leather", (61, 33, 18)), ("salt", (219, 199, 189)), ("water", (8, 10, 9)),
             ("paint", (219, 214, 194)), ("glass", (204, 217, 204)), ("flame", (255, 178, 76))]
    for nm, c in plain:
        cells.append((Image.new("RGB", (S, S), c), nm + " (props)", ["plain PBR value", "no texture", ""]))
    cols = 8
    rows = (len(cells) + cols - 1) // cols
    W = cols * (S + PAD) + PAD; H = rows * (S + 70 + PAD) + 80
    sheet = Image.new("RGB", (W, H), (34, 34, 34))
    dr = ImageDraw.Draw(sheet)
    dr.text((PAD, 20), "AeroSim Blender animals and wildlife props: every texture used (name, source, licence)", fill=(240, 240, 240), font=font(28))
    f1 = font(14); f2 = font(12)
    for i, (im, title, lines) in enumerate(cells):
        x = PAD + (i % cols) * (S + PAD); y = 80 + (i // cols) * (S + 70 + PAD)
        sheet.paste(im, (x, y))
        dr.text((x, y + S + 3), title, fill=(255, 255, 255), font=f1)
        for k, l in enumerate(lines):
            dr.text((x, y + S + 21 + k * 15), l, fill=(190, 190, 190), font=f2)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    sheet.save(OUT, quality=88)
    print("textures sheet", OUT, len(cells), "swatches", sheet.size)

if __name__ == "__main__":
    main()

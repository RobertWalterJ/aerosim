# Put together the drone check sheets (system Python with PIL), from godot/:
#   python tools/blender/drones_sheets.py
# docs/realism/models/drones_final_views.jpg: the in-game (Godot) sheets in golden hour and overcast, with the Blender
#   Cycles marketplace photos as a last row.
# docs/realism/models/drones_final_textures.jpg: every texture the drones use, as labelled swatches with source and licence.
import os

from PIL import Image, ImageDraw, ImageFont

G = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
M = os.path.join(G, "docs", "realism", "models")
T = os.path.join(G, "assets", "textures", "drones")


def font(sz):
    for f in ("C:/Windows/Fonts/segoeui.ttf", "C:/Windows/Fonts/arial.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, sz)
    return ImageFont.load_default()


# ---------------------------------------------------------------- views
a = Image.open(os.path.join(M, "drones_views_golden.jpg")).convert("RGB")
b = Image.open(os.path.join(M, "drones_views_overcast.jpg")).convert("RGB")
W = a.width
th = [Image.open(os.path.join(M, "drones_thumbs", f)).convert("RGB") for f in ("thumb_raptor_race_a.png", "thumb_nightowl_a.png", "thumb_parts.png")]
row_h = W // 5
out = Image.new("RGB", (W, 60 + a.height + 60 + b.height + 60 + row_h), (18, 18, 20))
d = ImageDraw.Draw(out)
y = 0
for title, im in (("In the game's renderer, golden hour (test/drones_sheet.gd)", a), ("In the game's renderer, overcast", b)):
    d.text((16, y + 14), title, font=font(30), fill=(235, 235, 235))
    y += 60
    out.paste(im, (0, y))
    y += im.height
d.text((16, y + 14), "Blender Cycles, the marketplace listing photos (512 px): Raptor, Night Owl, parts", font=font(30), fill=(235, 235, 235))
y += 60
for i, im in enumerate(th):
    out.paste(im.resize((row_h, row_h)), (i * row_h, y))
out.save(os.path.join(M, "drones_final_views.jpg"), quality=88)

# ---------------------------------------------------------------- textures
AMB = "ambientCG (Lennart Demes), CC0"
SETS = [
    ("drone_carbon_diff / _nor / _orm", ["drone_carbon_diff.jpg", "drone_carbon_nor.jpg", "drone_carbon_orm.jpg"],
     "ambientCG Fabric004 (2x2 twill carbon weave), 1K, recoloured", AMB, "carbon plates, arms, legs, gimbal plate; 14 mm repeat"),
    ("drone_brushed_nor / _orm", ["drone_brushed_nor.jpg", "drone_brushed_orm.jpg"],
     "ambientCG Metal009 (brushed metal), 1K", AMB, "anodised standoffs, bell sides, rails, pod case, gimbal arms; 20 mm"),
    ("drone_spun_nor / _orm", ["drone_spun_nor.jpg", "drone_spun_orm.jpg"],
     "ambientCG Metal051A (circular brushed aluminium), 1K", AMB, "motor bell tops, gimbal rotors (centred on the axis)"),
    ("drone_plastic_nor / _orm", ["drone_plastic_nor.jpg", "drone_plastic_orm.jpg"],
     "ambientCG Plastic012B (scratched black plastic), 1K", AMB, "camera bodies, canopy, paddles, connectors; 50 mm"),
    ("drone_rubber_nor / _orm", ["drone_rubber_nor.jpg", "drone_rubber_orm.jpg"],
     "ambientCG Rubber004, 1K", AMB, "printed TPU mounts and pads, rubber dampers and feet; 10 to 12 mm"),
    ("drone_strap_diff / _nor / _orm", ["drone_strap_diff.jpg", "drone_strap_nor.jpg", "drone_strap_orm.jpg"],
     "ambientCG Fabric036 (woven fabric), 1K, darkened", AMB, "battery straps; 20 mm"),
    ("drone_wrap_raptor / _nightowl", ["drone_wrap_raptor.jpg", "drone_wrap_nightowl.jpg"],
     "drawn by tools/blender/drones_prep_textures.py", "own work, CC0, no words or brands", "battery shrink wraps (UV wraps the pack)"),
    ("drone_pcb_diff", ["drone_pcb_diff.jpg"],
     "drawn by tools/blender/drones_prep_textures.py", "own work, CC0, no words", "flight controller, ESC and VTX boards"),
]
SW = 200
rowh = SW + 20
img = Image.new("RGB", (1900, 90 + rowh * len(SETS) + 60), (22, 22, 24))
d = ImageDraw.Draw(img)
d.text((20, 18), "Drone textures (lane/drones): files in godot/assets/textures/drones, 1024 px; normal maps OpenGL; ORM = occlusion, roughness, metal",
       font=font(26), fill=(240, 240, 240))
d.text((20, 54), "ambientCG sets are CC0 but made procedurally (no CC0 photographed carbon weave was found on Poly Haven or ambientCG)",
       font=font(20), fill=(200, 180, 140))
y = 90
for (title, files, src, lic, use) in SETS:
    for k, f in enumerate(files):
        t = Image.open(os.path.join(T, f)).convert("RGB")
        t = t.crop((0, 0, min(t.width, t.height), min(t.width, t.height))).resize((SW, SW))
        img.paste(t, (20 + k * (SW + 8), y))
    x = 20 + 3 * (SW + 8) + 20
    d.text((x, y + 10), title, font=font(26), fill=(255, 255, 255))
    d.text((x, y + 52), "Source: " + src, font=font(21), fill=(210, 210, 210))
    d.text((x, y + 84), "Licence: " + lic, font=font(21), fill=(170, 220, 170))
    d.text((x, y + 116), "Used for: " + use, font=font(21), fill=(210, 210, 210))
    y += rowh
d.text((20, y + 14), "Plain-colour materials (no texture): steel, titanium, copper windings, nickel magnets, gold pads, glass, lens coatings, lamps, silicone wire, nylon",
       font=font(20), fill=(200, 200, 200))
img.save(os.path.join(M, "drones_final_textures.jpg"), quality=88)
print("wrote drones_final_views.jpg and drones_final_textures.jpg")

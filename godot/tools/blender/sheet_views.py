# The final labelled views sheet: the Godot contact sheets of the animals (front, side, three-quarter, rear, head close-up
# in golden light) and the wildlife props, stacked under one title. System Python with Pillow:
#   python tools/blender/sheet_views.py -> docs/realism/models/animals_final_views.jpg
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.normpath(os.path.join(HERE, "..", "..", "docs", "realism", "models"))

def font(sz):
    for f in ("C:/Windows/Fonts/segoeuib.ttf", "C:/Windows/Fonts/arialbd.ttf"):
        if os.path.exists(f): return ImageFont.truetype(f, sz)
    return ImageFont.load_default()

def main():
    parts = [("Animals, Godot renderer with the fur shader, golden hour: front, side, three-quarter, rear, head", "animals_golden.jpg"),
             ("Animals, overcast: side, three-quarter, head", "animals_overcast.jpg"),
             ("Wildlife props (night pen, gates, trough, hay rack, salt lick, bell, wool on wire, tracks, sign, farm odds and ends)", "wildlife_props_golden.jpg")]
    ims = [(t, Image.open(os.path.join(D, f)).convert("RGB")) for t, f in parts if os.path.exists(os.path.join(D, f))]
    W = max(im.width for _, im in ims)
    H = sum(im.height + 60 for _, im in ims) + 80
    out = Image.new("RGB", (W, H), (28, 28, 28))
    dr = ImageDraw.Draw(out)
    dr.text((16, 18), "AeroSim: Blender animals and wildlife assets (lane/animals), final views", fill=(245, 245, 245), font=font(34))
    y = 80
    for t, im in ims:
        dr.text((16, y + 14), t, fill=(230, 210, 160), font=font(24))
        y += 60
        out.paste(im, (0, y))
        y += im.height
    p = os.path.join(D, "animals_final_views.jpg")
    out.save(p, quality=86)
    print("views sheet", p, out.size)

if __name__ == "__main__":
    main()

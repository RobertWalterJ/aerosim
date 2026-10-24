# Compose rendered panels into a labelled contact sheet (system Python with Pillow).
# python people_compose.py <out.jpg> <title> <cols> <img1>[=label] <img2>[=label] ...
import sys, os
from PIL import Image, ImageDraw, ImageFont

out, title, cols = sys.argv[1], sys.argv[2], int(sys.argv[3])
items = []
for a in sys.argv[4:]:
    p, _, lab = a.partition("=")
    items.append((p, lab or os.path.splitext(os.path.basename(p))[0]))
ims = [Image.open(p).convert("RGB") for p, _ in items]
w = max(i.width for i in ims); h = max(i.height for i in ims)
rows = (len(ims) + cols - 1) // cols
pad, lab_h, top = 6, 26, 44
sheet = Image.new("RGB", (cols * (w + pad) + pad, top + rows * (h + lab_h + pad) + pad), (24, 24, 26))
d = ImageDraw.Draw(sheet)
try:
    f = ImageFont.truetype("arial.ttf", 18); ft = ImageFont.truetype("arialbd.ttf", 24)
except Exception:
    f = ft = ImageFont.load_default()
d.text((pad + 4, 10), title, fill=(235, 235, 235), font=ft)
for k, (im, (p, lab)) in enumerate(zip(ims, items)):
    x = pad + (k % cols) * (w + pad); y = top + (k // cols) * (h + lab_h + pad)
    sheet.paste(im, (x, y))
    d.text((x + 4, y + h + 3), lab, fill=(220, 220, 220), font=f)
sheet.save(out, quality=88)
print("wrote", out, sheet.size)

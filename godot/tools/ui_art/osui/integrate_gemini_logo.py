from PIL import Image
import numpy as np
import os

gemini = r"C:\Users\Robert Walter-Joseph\Downloads\Gemini_Generated_Image_eze0jheze0jheze0.jpeg"
here = os.path.dirname(os.path.abspath(__file__))
godot_root = os.path.abspath(os.path.join(here, "..", "..", ".."))
ref_path = os.path.join(godot_root, "assets", "ui", "icon_map.png")

# 1. Gemini image
gem = Image.open(gemini).convert("RGB")
g = np.array(gem).astype(float)

# 2. mark mask: bright pixels (cream + brass) vs dark-green background
bright = g.sum(axis=2)
mark_mask = bright > 350
ys, xs = np.where(mark_mask)
if len(xs) == 0:
    raise SystemExit("no mark found")

m = 26
x0, x1 = max(0, xs.min() - m), min(g.shape[1], xs.max() + m + 1)
y0, y1 = max(0, ys.min() - m), min(g.shape[0], ys.max() + m + 1)
crop = g[y0:y1, x0:x1]

# 3. soft alpha from brightness within the crop
cb = crop.sum(axis=2)
alpha = np.clip((cb - 230) / 240, 0, 1)

rgba = np.zeros((crop.shape[0], crop.shape[1], 4), dtype=np.uint8)
rgba[:, :, :3] = crop.astype(np.uint8)
rgba[:, :, 3] = (alpha * 255).astype(np.uint8)
mark = Image.fromarray(rgba, "RGBA")

# 4. fit inside a 200 px safe zone
S = 200 / max(crop.shape[0], crop.shape[1])
mark = mark.resize((max(1, int(crop.shape[1] * S)), max(1, int(crop.shape[0] * S))), Image.LANCZOS)

# 5. pine adaptive-icon background (from the reference icon)
ref = Image.open(ref_path).convert("RGBA")
a = np.array(ref)
mask = a[:, :, 3] > 200
region = a[200:236, 16:60]
region = region[region[:, :, 3] > 200]
bg = tuple(int(x) for x in np.median(region[:, :3], axis=0))
pine = np.zeros((256, 256, 4), dtype=np.uint8)
pine[mask] = [bg[0], bg[1], bg[2], 255]
icon = Image.fromarray(pine, "RGBA")

# 6. paste the mark centred
icon.paste(mark, ((256 - mark.width) // 2, (256 - mark.height) // 2), mark)

# 7. re-apply the adaptive mask so corners stay transparent
ia = np.array(icon)
ia[mask == 0] = 0
icon = Image.fromarray(ia, "RGBA")

out = os.path.join(godot_root, "assets", "ui", "icon_aerolink.png")
icon.save(out)
print("saved", out, "| crop", crop.shape[1], "x", crop.shape[0], "| resized", mark.size)

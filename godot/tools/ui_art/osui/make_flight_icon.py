from PIL import Image, ImageDraw
import numpy as np
import os

here = os.path.dirname(os.path.abspath(__file__))     # godot/tools/ui_art/osui
godot_root = os.path.abspath(os.path.join(here, "..", "..", ".."))   # godot

# Reference icon for the exact background shape + colour
ref = Image.open(os.path.join(godot_root, "assets", "ui", "icon_map.png")).convert("RGBA")
a = np.array(ref)
mask = a[:, :, 3] > 200                      # opaque shape (the adaptive-icon squircle)

# Background colour: median of opaque pixels in the bottom-left region (background, not the glyph)
region = a[200:236, 16:60]
region = region[region[:, :, 3] > 200]
bg = tuple(int(x) for x in np.median(region[:, :3], axis=0))
print("background colour:", bg)

# New icon, same shape, same background
im = np.zeros((256, 256, 4), dtype=np.uint8)
im[mask] = [bg[0], bg[1], bg[2], 255]
icon = Image.fromarray(im, "RGBA")
draw = ImageDraw.Draw(icon)
cream = (250, 245, 226, 255)

c = 128
# four arms (diagonal X, like a quadcopter seen from above)
for dx, dy in [(-50, -50), (50, -50), (-50, 50), (50, 50)]:
    draw.line([(c, c), (c + dx, c + dy)], fill=cream, width=13)

# four rotors (rings, like propeller discs)
rr = 21
for dx, dy in [(-50, -50), (50, -50), (-50, 50), (50, 50)]:
    x, y = c + dx, c + dy
    draw.ellipse([x - rr, y - rr, x + rr, y + rr], outline=cream, width=9)

# central body (rounded rectangle, front-back)
draw.rounded_rectangle([c - 28, c - 19, c + 28, c + 19], radius=14, fill=cream)

icon.save(os.path.join(godot_root, "assets", "ui", "icon_aerofly.png"))
print("saved", os.path.join(godot_root, "assets", "ui", "icon_aerofly.png"))

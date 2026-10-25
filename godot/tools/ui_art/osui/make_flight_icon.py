from PIL import Image, ImageDraw
import numpy as np
import os, math

here = os.path.dirname(os.path.abspath(__file__))     # godot/tools/ui_art/osui
godot_root = os.path.abspath(os.path.join(here, "..", "..", ".."))   # godot

# Reference icon for the exact background shape + colour
ref = Image.open(os.path.join(godot_root, "assets", "ui", "icon_map.png")).convert("RGBA")
a = np.array(ref)
mask = a[:, :, 3] > 200
region = a[200:236, 16:60]
region = region[region[:, :, 3] > 200]
bg = tuple(int(x) for x in np.median(region[:, :3], axis=0))

im = np.zeros((256, 256, 4), dtype=np.uint8)
im[mask] = [bg[0], bg[1], bg[2], 255]
icon = Image.fromarray(im, "RGBA")

# Draw on a 4x supersample, then downscale for smooth anti-aliased edges (Illustrator-grade curves)
S = 4
big = Image.new("RGBA", (256 * S, 256 * S), (0, 0, 0, 0))
d = ImageDraw.Draw(big)
cream = (250, 245, 226, 255)
brass = (224, 171, 89, 255)

cx, cy = 128 * S, 108 * S          # drone centre
arm = 52 * S                        # rotor offset from centre
rr = 19 * S                         # rotor ring radius
sw = 7 * S                          # stroke weight

def s(v): return v  # keep S-scaled coordinates explicit

# ---- the drone: four rotor rings, a diamond body, four arms ----
rotors = [(cx - arm, cy - arm), (cx + arm, cy - arm), (cx - arm, cy + arm), (cx + arm, cy + arm)]
# arms first (under the body)
for rx, ry in rotors:
    d.line([(cx, cy), (rx, ry)], fill=cream, width=sw)
# rotor rings
for rx, ry in rotors:
    d.ellipse([rx - rr, ry - rr, rx + rr, ry + rr], outline=cream, width=sw)
# diamond body (rotated square)
h = 26 * S
d.polygon([(cx, cy - h), (cx + h, cy), (cx, cy + h), (cx - h, cy)], fill=cream)

# ---- the link: a tether down to the remote, then a signal that spreads ----
dot_y = cy + 70 * S
d.line([(cx, cy + h), (cx, dot_y)], fill=cream, width=sw)
d.ellipse([cx - 6 * S, dot_y - 6 * S, cx + 6 * S, dot_y + 6 * S], fill=brass)   # the remote point, in brass
for r in (16 * S, 27 * S, 38 * S):
    d.arc([cx - r, dot_y - r, cx + r, dot_y + r], 180, 360, fill=cream, width=sw)

# downscale with a good filter, then composite the mark onto the pine background
mark = big.resize((256, 256), Image.LANCZOS)
icon = Image.alpha_composite(Image.fromarray(im, "RGBA"), mark)
# re-apply the adaptive-icon mask so the corners stay transparent
icon_arr = np.array(icon)
icon_arr[mask == 0] = 0
icon = Image.fromarray(icon_arr, "RGBA")

out = os.path.join(godot_root, "assets", "ui", "icon_aerolink.png")
icon.save(out)
print("saved", out)

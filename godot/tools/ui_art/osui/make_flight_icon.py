from PIL import Image, ImageDraw
import numpy as np
import os

here = os.path.dirname(os.path.abspath(__file__))
godot_root = os.path.abspath(os.path.join(here, "..", "..", ".."))

ref = Image.open(os.path.join(godot_root, "assets", "ui", "icon_map.png")).convert("RGBA")
a = np.array(ref)
mask = a[:, :, 3] > 200
region = a[200:236, 16:60]
region = region[region[:, :, 3] > 200]
bg = tuple(int(x) for x in np.median(region[:, :3], axis=0))

S = 4
W = 256 * S
cream = (250, 245, 226, 255)
brass = (224, 171, 89, 255)

# ---- draw the mark on a transparent layer at 4x ----
mark = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(mark)

cx, cy = W // 2, 120 * S          # drone centre (will be auto-centred after)
arm = 48 * S                       # rotor offset from centre
rr = 18 * S                        # rotor ring outer radius
sw = 7 * S                         # stroke weight
rotors = [(cx - arm, cy - arm), (cx + arm, cy - arm), (cx - arm, cy + arm), (cx + arm, cy + arm)]

# arms (under everything)
for rx, ry in rotors:
    d.line([(cx, cy), (rx, ry)], fill=cream, width=sw)
# rotor rings
for rx, ry in rotors:
    d.ellipse([rx - rr, ry - rr, rx + rr, ry + rr], outline=cream, width=sw)
# motor hubs (rounds the arm ends where they meet each rotor)
for rx, ry in rotors:
    d.ellipse([rx - 5 * S, ry - 5 * S, rx + 5 * S, ry + 5 * S], fill=cream)

# body: a rounded square rotated 45 deg -> a soft rounded diamond
body = Image.new("RGBA", (W, W), (0, 0, 0, 0))
bd = ImageDraw.Draw(body)
bw = 36 * S
bd.rounded_rectangle([cx - bw // 2, cy - bw // 2, cx + bw // 2, cy + bw // 2], radius=int(bw * 0.40), fill=cream)
body = body.rotate(45, resample=Image.BICUBIC, center=(cx, cy))
mark = Image.alpha_composite(mark, body)

# the link: tether down to a brass remote, then a signal that spreads
half = 25 * S                      # half-extent of the diamond after rotation
dot_y = cy + half + 26 * S
d = ImageDraw.Draw(mark)
d.line([(cx, cy + half), (cx, dot_y)], fill=cream, width=sw)
d.ellipse([cx - 6 * S, dot_y - 6 * S, cx + 6 * S, dot_y + 6 * S], fill=brass)
for r in (14 * S, 24 * S, 34 * S):
    d.arc([cx - r, dot_y - r, cx + r, dot_y + r], 180, 360, fill=cream, width=sw)

# ---- centre the mark exactly on the canvas centre ----
arr = np.array(mark)
opaque = arr[:, :, 3] > 40
ys, xs = np.where(opaque)
cx0 = (xs.min() + xs.max()) / 2.0
cy0 = (ys.min() + ys.max()) / 2.0
shift = (int(W / 2 - cx0), int(W / 2 - cy0))
centred = Image.new("RGBA", (W, W), (0, 0, 0, 0))
centred.paste(mark, shift)
mark = centred

# ---- downscale, composite onto pine, re-apply the adaptive mask ----
small = mark.resize((256, 256), Image.LANCZOS)
pine = np.zeros((256, 256, 4), dtype=np.uint8)
pine[mask] = [bg[0], bg[1], bg[2], 255]
icon = Image.alpha_composite(Image.fromarray(pine, "RGBA"), small)
icon_arr = np.array(icon)
icon_arr[mask == 0] = 0
icon = Image.fromarray(icon_arr, "RGBA")

out = os.path.join(godot_root, "assets", "ui", "icon_aerolink.png")
icon.save(out)
print("saved", out, "shift was", shift)

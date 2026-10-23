"""Measure screenshots so a change in look becomes a number. Usage:
  python tools/look_metrics.py a.png [b.png]      one image: stats. Two images: stats and how much they differ.
Stats: mean luma, luma spread, shadows/highlights clipped %, mean saturation, edge sharpness, noise estimate, colour cast (R-B).
A stage that should not change the picture must show a difference under 2 grey levels (mean abs diff) vs its golden image.
"""
import sys
import numpy as np
from PIL import Image

def stats(path):
    im = Image.open(path).convert("RGB").resize((640, 360))
    a = np.asarray(im).astype(float)
    l = 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
    mx = a.max(axis=2); mn = a.min(axis=2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1), 0).mean()
    gx = np.abs(np.diff(l, axis=1)).mean(); gy = np.abs(np.diff(l, axis=0)).mean()
    blur = l.copy(); blur[1:-1, 1:-1] = (l[:-2, 1:-1] + l[2:, 1:-1] + l[1:-1, :-2] + l[1:-1, 2:]) / 4
    noise = np.abs(l - blur)[2:-2, 2:-2].mean()
    return {
        "mean_luma": round(l.mean(), 1), "spread": round(l.std(), 1),
        "clip_black_%": round((l < 5).mean() * 100, 2), "clip_white_%": round((l > 250).mean() * 100, 2),
        "saturation": round(sat, 3), "edge_sharpness": round((gx + gy) / 2, 2), "noise": round(noise, 2),
        "cast_R-B": round(a[..., 0].mean() - a[..., 2].mean(), 1),
    }

if __name__ == "__main__":
    p = sys.argv[1:]
    for f in p: print(f, stats(f))
    if len(p) == 2:
        a = np.asarray(Image.open(p[0]).convert("RGB").resize((640, 360))).astype(float)
        b = np.asarray(Image.open(p[1]).convert("RGB").resize((640, 360))).astype(float)
        print("mean abs difference (0..255):", round(np.abs(a - b).mean(), 2))

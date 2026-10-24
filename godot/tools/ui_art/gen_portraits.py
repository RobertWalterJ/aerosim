"""Grade the Cycles portrait renders (tools/blender/appui_portraits.py) into the avatar set.

Each person gets one flat palette backdrop with a soft light behind the head, a warm rural grade (lifted warm shadows,
gentle S-curve, a touch less saturation in the skin), a quiet vignette and grain. Output:
  assets/ui/avatar_<key>.png            512 x 512, opaque square (the code masks or clips it)
  assets/ui/avatars/cutout/<key>.png    512 graded subject on transparent
  assets/ui/sizes/96|48/avatar_<key>.png native downscales (sharpened) for small slots
Usage: python gen_portraits.py <render dir>
"""
import sys
from appui_lib import *

BACKDROP = {
    "maya": "#6E9A72", "jo": "#A9603F", "riley": "#4F8791", "tom": "#56697F", "alex": "#B98E4A", "sam": "#7C8B6A",
    "rennick": "#3D4A57", "unknown": "#1E2224", "you": "#2F4A3E", "wren": "#3F7774", "kit": "#A8956B",
}
NOTE = {
    "maya": "Maya, editor: long dark hair, rust jumper, headphones round the neck",
    "jo": "Jo, events: auburn bob, slate shirt, festival lanyard",
    "riley": "Riley, park ranger: moss fleece, shoulder radio, no insignia",
    "tom": "Tom, storm chaser: bucket hat, mustard jacket, camera strap",
    "alex": "Alex, Facade seller: flip-up magnifier band, work shirt",
    "sam": "Sam, crew and fixer: braids, canvas utility jacket, pocket tools",
    "rennick": "Constable Rennick: the in-game model, plain clothes",
    "unknown": "Unknown account: backlit, beanie and gaiter, no readable face",
    "you": "You, the pilot: FPV goggles down, neutral",
    "wren": "Wren, lost hiker: the in-game model, red rain jacket, pack straps",
    "kit": "Kit, DroneBudz support: headset, olive jacket",
}


def grade(rgb, warm=1.0):
    x = rgb.astype(np.float32) / 255.0
    # gentle S-curve around 0.45 and warm lift in the shadows
    x = np.clip(x, 0, 1)
    x = x + 0.10 * (x - x ** 2) * (x - 0.45) * 4
    lift = np.array([0.030, 0.022, 0.010]) * warm
    x = x * (1 - lift) + lift
    lum = (x * np.array([0.299, 0.587, 0.114])).sum(-1, keepdims=True)
    x = lum + (x - lum) * 0.92
    x = x * np.array([1.02, 1.0, 0.96])
    return np.clip(x * 255, 0, 255)


def backdrop(n, col, glow_xy=(0.42, 0.34), glow=0.22, backlit=False, seed=1):
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32) / n
    base = np.array(hx(col)[:3], np.float32)
    d = np.sqrt((xx - glow_xy[0]) ** 2 + (yy - glow_xy[1]) ** 2)
    if backlit:
        g = np.exp(-(d / 0.30) ** 2)
        img = base * (0.8 + 0.2 * (1 - yy))[..., None] + np.array([224, 160, 92], np.float32) * (g * 0.85)[..., None]
    else:
        img = base * (1 + glow * np.exp(-(d / 0.45) ** 2) - 0.22 * yy)[..., None]
    nz = tile_noise(n, seed, ((5, 1.0), (13, 0.5)))
    img *= (0.96 + 0.08 * nz)[..., None]
    return img


def build(src):
    rng = np.random.default_rng(3)
    for key, col in BACKDROP.items():
        p = os.path.join(src, key + ".png")
        if not os.path.exists(p):
            print("missing render", key)
            continue
        im = Image.open(p).convert("RGBA")
        n = im.size[0]
        arr = np.asarray(im).astype(np.float32)
        a = arr[..., 3:4] / 255.0
        rgb = np.where(a > 0.003, arr[..., :3] / np.maximum(a, 0.003), 0)        # un-premultiply edges
        subj = grade(rgb, warm=0.6 if key == "unknown" else 1.0)
        bg = backdrop(n, col, backlit=(key == "unknown"), seed=sum(map(ord, key)))
        out = subj * a + bg * (1 - a)
        # vignette and grain
        yy, xx = np.mgrid[0:n, 0:n].astype(np.float32) / n
        v = 1 - 0.28 * np.clip(np.sqrt((xx - 0.5) ** 2 + (yy - 0.45) ** 2) / 0.72, 0, 1) ** 2.2
        out *= v[..., None]
        out += rng.normal(0, 2.2, out.shape[:2])[..., None]
        sq = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
        save_ui(sq.resize((512, 512), Image.LANCZOS), f"avatar_{key}.png", note=NOTE[key])
        for S in (96, 48):
            small = sq.resize((S, S), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=0.6, percent=60, threshold=1))
            save_ui(small, f"sizes/{S}/avatar_{key}.png")
        cut = np.concatenate([subj, a * 255], -1)
        save_ui(Image.fromarray(np.clip(cut, 0, 255).astype(np.uint8), "RGBA").resize((512, 512), Image.LANCZOS), f"avatars/cutout/{key}.png")


if __name__ == "__main__":
    build(sys.argv[1])

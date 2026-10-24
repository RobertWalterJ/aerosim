"""Prepare the photographic avatar sources (lane avatars) from CC0 photographs already on this PC.

The photos are Poly Haven HDRIs by Greg Zaal, CC0: Blender 4.2.3 ships eight of them in
datafiles/studiolights/world (its license.txt: "All HDRIs are licenses as CC0. These were created by Greg Zaal (Poly Haven)"),
and RWJ-Shared-Assets carries kloofendal_48d_partly_cloudy_puresky (sun disc removed). A pinhole camera is pointed into
each equirectangular panorama, tonemapped to an ordinary photograph and saved as a 1024 px JPEG in avatar_sources/.
build_avatars.py reads those JPEGs, so this script only has to run again to change a framing.
Reading .exr needs Blender (it converts them to .hdr in a temp folder); cv2 reads .hdr directly.
Usage: python avatar_photo_prep.py
"""
import os, subprocess, sys, tempfile
import numpy as np
import cv2
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "..", ".."))           # RWJ Coding Projects
BLENDER = os.path.join(ROOT, "_tools", "blender-4.2.3-windows-x64", "blender.exe")
WORLD = os.path.join(ROOT, "_tools", "blender-4.2.3-windows-x64", "4.2", "datafiles", "studiolights", "world")
SKY = os.path.join(ROOT, "RWJ-Shared-Assets", "godot", "addons", "rwj_procgen", "sky", "sky.hdr")
OUT = os.path.join(HERE, "avatar_sources")

# name: (panorama, yaw deg, pitch deg, vertical fov deg, exposure, white point)
VIEWS = {
    "sunrise_field": ("sunrise", 33.0, 4.0, 50.0, 0.8, 8.0),      # You: sunrise over a misty field
    "woodland_trail": ("forest", 4.0, -4.0, 60.0, 1.3, 3.0),      # Wren: a gravel trail through the woods
    "cumulus": ("sky", -122.0, 26.0, 40.0, 1.0, 2.2),            # Sam: fair-weather cumulus
    "storm_cloud": ("sky", 22.0, 38.0, 48.0, 1.0, 2.2),          # Tom: cloud mass, regraded as a storm
    "storm_ground": ("sunrise", 100.0, -6.0, 60.0, 1.0, 4.0),     # Tom: open field under it
}
SOURCES = {
    "sunrise": "Poly Haven HDRI shipped with Blender 4.2.3 as studiolights/world/sunrise.exr, Greg Zaal, CC0",
    "forest": "Poly Haven HDRI shipped with Blender 4.2.3 as studiolights/world/forest.exr, Greg Zaal, CC0",
    "sky": "Poly Haven kloofendal_48d_partly_cloudy_puresky (https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky),"
           " Greg Zaal, CC0, via RWJ-Shared-Assets sky/sky.hdr",
}


def load_panoramas():
    tmp = tempfile.mkdtemp(prefix="avatar_hdr_")
    script = os.path.join(tmp, "exr2hdr.py")
    with open(script, "w") as f:
        f.write("import bpy, os, sys\nsrc, dst = sys.argv[sys.argv.index('--') + 1:][:2]\n"
                "for n in ('sunrise', 'forest'):\n"
                "    im = bpy.data.images.load(os.path.join(src, n + '.exr')); im.reload(); _ = im.pixels[0]\n"
                "    im.file_format = 'HDR'; im.filepath_raw = os.path.join(dst, n + '.hdr'); im.save()\n")
    subprocess.run([BLENDER, "-b", "--factory-startup", "--python", script, "--", WORLD, tmp], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    pano = {n: cv2.imread(os.path.join(tmp, n + ".hdr"), cv2.IMREAD_UNCHANGED)[..., ::-1].astype(np.float32)
            for n in ("sunrise", "forest")}
    pano["sky"] = cv2.imread(SKY, cv2.IMREAD_UNCHANGED)[..., ::-1].astype(np.float32)
    return pano


def view(pano, yaw, pitch, fov, size=1024):
    """Pinhole camera into an equirectangular panorama (u = 0.5 looks along +Z, yaw to the right)."""
    H, W = pano.shape[:2]
    f = 0.5 * size / np.tan(np.radians(fov) / 2)
    j, i = np.mgrid[0:size, 0:size].astype(np.float32)
    x, y, z = (i - size / 2 + 0.5) / f, -(j - size / 2 + 0.5) / f, np.ones_like(i)
    cp, sp = np.cos(np.radians(pitch)), np.sin(np.radians(pitch))
    y, z = y * cp + z * sp, -y * sp + z * cp
    cy, sy = np.cos(np.radians(yaw)), np.sin(np.radians(yaw))
    x, z = x * cy + z * sy, -x * sy + z * cy
    u = 0.5 + np.arctan2(x, z) / (2 * np.pi)
    v = 0.5 - np.arcsin(y / np.sqrt(x * x + y * y + z * z)) / np.pi
    return cv2.remap(pano, (u * W).astype(np.float32) % W, np.clip(v * H, 0, H - 1).astype(np.float32),
                     cv2.INTER_CUBIC, borderMode=cv2.BORDER_WRAP)


def tonemap(img, exposure, white):
    x = np.maximum(img * exposure, 0)
    x = x * (1 + x / (white * white)) / (1 + x)                 # extended Reinhard
    x = np.where(x <= 0.0031308, 12.92 * x, 1.055 * np.power(np.maximum(x, 1e-8), 1 / 2.4) - 0.055)
    return np.clip(x * 255, 0, 255).astype(np.uint8)


def clean_sun(img):
    """The panorama carries a dark calibration ring on the sun disc: inpaint dark specks near the sun from their surround."""
    g = cv2.cvtColor(img, cv2.COLOR_RGB2GRAY)
    ys, xs = np.nonzero(g >= np.percentile(g, 99.5))
    cy, cx = ys.mean(), xs.mean()
    med = cv2.medianBlur(g, 41).astype(np.int16)
    jj, ii = np.mgrid[0:g.shape[0], 0:g.shape[1]]
    near = (jj - cy) ** 2 + (ii - cx) ** 2 < 200 ** 2
    mask = ((med - g.astype(np.int16) > 18) & near).astype(np.uint8) * 255
    mask = cv2.dilate(mask, np.ones((7, 7), np.uint8))
    return cv2.inpaint(img, mask, 9, cv2.INPAINT_TELEA)


def build():
    os.makedirs(OUT, exist_ok=True)
    pano = load_panoramas()
    for name, (src, yaw, pitch, fov, ex, wh) in VIEWS.items():
        img = tonemap(view(pano[src], yaw, pitch, fov), ex, wh)
        if name == "sunrise_field":
            img = clean_sun(img)
        Image.fromarray(img).save(os.path.join(OUT, name + ".jpg"), quality=92)
        print("source", name)
    with open(os.path.join(OUT, "SOURCES.md"), "w", encoding="utf-8") as f:
        f.write("# Avatar photo sources (lane avatars)\n\nMade by `avatar_photo_prep.py`: a pinhole view into a CC0 panorama.\n\n"
                "| File | Panorama | Source, author, licence | yaw, pitch, fov |\n|---|---|---|---|\n")
        for name, (src, yaw, pitch, fov, ex, wh) in VIEWS.items():
            f.write(f"| `{name}.jpg` | {src} | {SOURCES[src]} | {yaw:g}, {pitch:g}, {fov:g} |\n")


if __name__ == "__main__":
    build()

"""Copies the Poly Haven sets the buildings use from tools/blender/tex_src/ into assets/textures/ as bld_*.jpg (1024 px,
albedo and ARM quality 85, normals 90), turns the painted planks a quarter turn so the boards run level (and turns the
normal map's vectors with them), draws the grime streak decal (own work), and writes .import files that make Godot
compress them for VRAM with mipmaps (normal maps flagged). Run: python -I make_building_textures.py <godot dir>"""
import os, sys, random, math
from PIL import Image, ImageFilter

GODOT = sys.argv[1]
SRC = os.path.join(GODOT, "tools", "blender", "tex_src")
DST = os.path.join(GODOT, "assets", "textures")

# key -> (Poly Haven set, maps, size)
SETS = {
    "bld_brick": ("red_brick", ("diff", "nor", "arm", "disp"), 1024),
    "bld_brick2": ("medieval_red_brick", ("diff", "nor", "arm", "disp"), 1024),
    "bld_render": ("painted_plaster_wall", ("diff", "nor", "arm"), 1024),
    "bld_slate": ("roof_slates_03", ("diff", "nor", "arm"), 1024),
    "bld_slate2": ("roof_slates_02", ("diff", "nor", "arm"), 1024),
    "bld_corrugated": ("corrugated_iron_02", ("diff", "nor", "arm"), 1024),
    "bld_corrugated_rust": ("worn_corrugated_iron", ("diff", "nor", "arm"), 1024),
    "bld_weatherboard": ("distressed_painted_planks", ("diff", "nor", "arm"), 1024),
    "bld_timber": ("weathered_plank_siding", ("diff", "nor", "arm"), 1024),
    "bld_paint": ("plastered_wall_02", ("diff", "nor", "arm"), 512),
    "bld_wood": ("old_planks_02", ("diff", "nor", "arm"), 1024),
    "bld_floor": ("wood_floor_worn", ("diff", "nor", "arm"), 512),
    "bld_concrete": ("concrete_floor_painted", ("diff", "nor", "arm"), 1024),
}
ROTATE = {"bld_weatherboard"}

IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://assets/textures/{name}"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map={nm}
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""


def write_import(name, normal):
    with open(os.path.join(DST, name + ".import"), "w", newline="\n") as f:
        f.write(IMPORT.format(name=name, nm=1 if normal else 0))


for key, (src, maps, size) in SETS.items():
    for m in maps:
        im = Image.open(os.path.join(SRC, "%s_%s.jpg" % (src, m)))
        im = im.convert("L") if m == "disp" else im.convert("RGB")
        if im.size[0] != size:
            im = im.resize((size, size), Image.LANCZOS)
        if key == "bld_weatherboard" and m == "diff":
            # the boards are painted green-grey in the photograph: take the colour out (keeping the peeling and grain)
            # so the vertex-colour paint decides it, and lift it so a cream or white paint reads as cream or white
            from PIL import ImageOps, ImageEnhance
            g = ImageOps.grayscale(im)
            g = ImageEnhance.Brightness(g).enhance(1.35)
            im = Image.merge("RGB", (g, g, g))
        if key in ROTATE:
            im = im.transpose(Image.ROTATE_90)     # counter-clockwise: vertical boards become level
            if m == "nor":
                r, g, b = im.split()
                # a vector (x, y) turned 90 degrees counter-clockwise is (-y, x)
                r2 = g.point(lambda v: 255 - v)
                im = Image.merge("RGB", (r2, r, b))
        name = "%s_%s.jpg" % (key, m)
        im.save(os.path.join(DST, name), quality=90 if m == "nor" else 85)
        write_import(name, m == "nor")
        print(name, im.size)

# the grime streak: a soft vertical run-off, darkest at the top, fading down and at the sides, with drip fingers
random.seed(7)
W, H = 128, 256
img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
px = img.load()
fingers = [(random.uniform(0.15, 0.85), random.uniform(0.5, 1.0), random.uniform(0.04, 0.1)) for _ in range(9)]
for y in range(H):
    t = y / (H - 1)
    for x in range(W):
        s = x / (W - 1)
        side = math.exp(-((s - 0.5) / 0.32) ** 4)
        a = 0.75 * (1 - t) ** 1.6 * side
        for (fx, fl, fw) in fingers:
            if t < fl:
                a += 0.35 * math.exp(-((s - fx) / fw) ** 2) * (1 - t / fl)
        a = max(0.0, min(1.0, a))
        px[x, y] = (40, 34, 26, int(a * 255))
img = img.filter(ImageFilter.GaussianBlur(1.2))
img.save(os.path.join(DST, "bld_grime.png"))
write_import("bld_grime.png", False)
print("bld_grime.png")

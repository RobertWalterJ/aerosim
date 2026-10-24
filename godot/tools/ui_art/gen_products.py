"""Facade product tiles from the Cycles renders (tools/blender/appui_products.py).

Tile treatment from CLAUDE-APP-ASSETS.md: one object, three-quarter view, soft top-left light, contact shadow, and the
category colour as a soft round plate behind the object (camera amber, drone moss, motor rust, battery lake).
Transparent outside the plate. No text, prices or logos.
  assets/ui/item_<id>.png  512 ; assets/ui/sizes/96/item_<id>.png ; assets/ui/items/cutout/<id>.png (object + shadow only)
Usage: python gen_products.py <render dir>
"""
import sys
from appui_lib import *

CAT = {
    "raptor": ("drone", MOSS), "nightowl": ("drone", MOSS), "controller": ("drone", MOSS),
    "thermal_camera": ("camera", BRASS), "night_vision": ("camera", BRASS),
    "motors": ("motor", RUST), "props": ("motor", RUST), "repair_kit": ("motor", RUST),
    "battery": ("battery", LAKE),
}
NOTE = {
    "raptor": "Raptor drone: the game's raptor_race_a model", "nightowl": "Night Owl drone: the game's nightowl_a model",
    "thermal_camera": "Thermal camera module: the game's thermal_pod_a", "night_vision": "Night vision module: the game's night_vision_pod_a",
    "battery": "Long-range battery: rugged pack, amber charge LEDs (modelled)", "motors": "Motor upgrade set: four brushless motors, one cut away (modelled)",
    "props": "Low-noise prop set: matte prop pair (modelled)", "controller": "Controller: two sticks and a phone cradle (modelled)",
    "repair_kit": "Field repair kit: case, tape, spare arm, hex keys (modelled)",
}


def plate(n, col):
    c = Canvas(n).unit(n / 2, n / 2, n / 100.0)
    disc = c.circle(0, 2, 44)
    c.fill(disc, Gradient([(0, lighten(col, 0.22)), (0.7, col), (1, darken(col, 0.30))], center=(-14, -16), radius=70), 0.92)
    c.fill(c.ring(0, 2, 44, 0.5), (255, 246, 220, 255), 0.35)
    return c.render()


def build(src):
    for key, (cat, col) in CAT.items():
        p = os.path.join(src, key + ".png")
        if not os.path.exists(p):
            print("missing render", key)
            continue
        obj = Image.open(p).convert("RGBA").resize((512, 512), Image.LANCZOS)
        tile = plate(512, col)
        # the shadow catcher leaves soft black alpha everywhere; keep the shadow only on the plate, keep the object whole
        a = np.asarray(obj.getchannel("A"), np.float32) / 255.0
        lum = np.asarray(obj.convert("L"), np.float32) / 255.0
        on_plate = np.asarray(tile.getchannel("A"), np.float32) / 255.0
        solid = np.clip((a - 0.88) / 0.1, 0, 1)
        shadow_only = (lum < 0.02) & (a < 0.97)
        na = np.where(shadow_only, a * on_plate, np.maximum(a * on_plate, a * solid + a * (1 - solid) * on_plate))
        na = np.maximum(na, np.where(~shadow_only, a * np.clip(lum * 20, 0, 1), 0))
        obj.putalpha(Image.fromarray(np.clip(na * 255, 0, 255).astype(np.uint8)))
        tile.alpha_composite(obj)
        save_ui(tile, f"item_{key}.png", note=f"{NOTE[key]}; {cat} accent")
        save_ui(tile.resize((96, 96), Image.LANCZOS).filter(ImageFilter.UnsharpMask(0.6, 50, 1)), f"sizes/96/item_{key}.png")
        save_ui(obj, f"items/cutout/{key}.png")


if __name__ == "__main__":
    build(sys.argv[1])

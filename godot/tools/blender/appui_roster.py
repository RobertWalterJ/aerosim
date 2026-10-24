# The cast of the phone apps (lane appui2). Portraits only: these specs are built with the people lane's MakeHuman/MPFB
# pipeline (people_lib.build_character) and rendered by appui_portraits.py. Nothing here is exported to assets/models.
# Rennick and Wren reuse their people_roster specs, so the portrait is the same person as the in-game model.
# Every MakeHuman asset named here is listed with author and licence in assets/ui/APPUI-README.md (from the packs json).
# props: small things modelled by appui_portraits.py after posing (headphones, lanyard, radio, strap, magnifier, tools,
# goggles). backdrop / grade: used by the 2D grade in tools/ui_art/gen_portraits.py.
import os, sys, copy
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from people_roster import ROSTER, _g, CAUC, AFR, ASN, MIX

CAST = {}

def cast(name, base=None, **kw):
    spec = copy.deepcopy(ROSTER[base]) if base else {}
    spec.update(kw)
    spec["name"] = name
    spec["hero"] = True
    spec.setdefault("body", "female" if spec["macro"].get("gender", 0.5) < 0.5 else "male")
    spec.setdefault("props", [])
    spec["extras"] = [e for e in spec.get("extras", []) if e in ("scarf", "backpack")]
    if spec.get("hair"):
        spec["hair"].setdefault("budget", 60000)
        spec["hair"].setdefault("tex", 1024)
    spec.setdefault("clothes_budget", 90000)
    spec.setdefault("tri_budget", 200000)
    CAST[name] = spec
    return spec

# Maya, editor and channel owner (about 34): long black hair, rust cardigan, headphones round the neck
cast("maya",
     macro={"gender": 0.0, "age": 0.57, "muscle": 0.42, "weight": 0.44, "height": 0.5, "proportions": 0.55},
     race={"caucasian": 0.25, "african": 0.0, "asian": 0.75}, skin="young_asian_female", eye_color="brown",
     brows="eyebrow004", lashes="eyelashes01",
     hair={"asset": "long01", "tint": (0.07, 0.05, 0.045)},
     clothes=[
         _g("mindfront_knitted_sweater_02", tint=(0.55, 0.22, 0.12), fabric="knitted_fleece", tile=7, detail=0.55, mat="sweater"),
     ],
     props=["headphones"], smile=0.35, turn=10)

# Jo, events and bookings (about 46): auburn bob, slate-blue shirt, festival lanyard
cast("jo",
     macro={"gender": 0.0, "age": 0.66, "muscle": 0.5, "weight": 0.56, "height": 0.5, "proportions": 0.5},
     race=CAUC, skin="middleage_caucasian_female", eye_color="bluegreen", brows="eyebrow009", lashes="eyelashes02",
     hair={"asset": "toigo_curled_under_bob", "tint": (0.30, 0.14, 0.07)},
     clothes=[
         _g("elvs_male_shirt_untucked_bd1", tint=(0.30, 0.42, 0.52), fabric="stretch_poplin", tile=6, detail=0.3, mat="shirt"),
     ],
     props=["lanyard"], smile=0.55, turn=-8)

# Riley, park ranger (about 38): moss fleece, shoulder radio, no insignia
cast("riley",
     macro={"gender": 1.0, "age": 0.6, "muscle": 0.6, "weight": 0.5, "height": 0.55, "proportions": 0.55},
     race=AFR, skin="middleage_african_male", eye_color="brown", brows="eyebrow003", lashes="eyelashes02",
     hair={"asset": "short04", "tint": (0.04, 0.035, 0.035)},
     clothes=[
         _g("mindfront_knitted_sweater_02", tint=(0.22, 0.32, 0.19), fabric="knitted_fleece", tile=6, detail=0.5, mat="fleece"),
     ],
     props=["radio"], smile=0.2, turn=12)

# Tom, storm chaser (about 52): weather-beaten, bucket hat, mustard jacket, camera strap
cast("tom",
     macro={"gender": 1.0, "age": 0.74, "muscle": 0.5, "weight": 0.52, "height": 0.52, "proportions": 0.55},
     race=CAUC, skin="old_caucasian_male", eye_color="blue", brows="eyebrow006", lashes="eyelashes02",
     hair={"asset": "short02", "tint": (0.52, 0.48, 0.42)},
     clothes=[
         _g("elvs_hooded_sweat_jacket1", tint=(0.62, 0.45, 0.13), fabric="stretch_poplin", tile=6, detail=0.4, mat="jacket"),
         _g("mindfront_fishing_hat_01", tint=(0.33, 0.33, 0.25), fabric="rough_linen", tile=4, detail=0.5, mat="hat", covers=False, hat=True),
     ],
     props=["camera_strap"], smile=0.75, turn=-12)

# Alex, Facade seller and tinkerer (about 41): coveralls, a flip-up magnifier band on the forehead
cast("alex",
     macro={"gender": 0.85, "age": 0.62, "muscle": 0.45, "weight": 0.42, "height": 0.5, "proportions": 0.55},
     race=ASN, skin="middleage_asian_male", eye_color="brown", brows="eyebrow002", lashes="eyelashes01",
     hair={"asset": "short04", "tint": (0.05, 0.045, 0.04)},
     clothes=[
         _g("elvs_male_shirt_untucked_bd1", tint=(0.27, 0.34, 0.40), fabric="rough_linen", tile=7, detail=0.5, mat="shirt"),
     ],
     props=["magnifier"], smile=0.3, turn=8)

# Sam, crew and fixer (about 33): tan canvas utility jacket, tools in the chest pocket, dry look
cast("sam",
     macro={"gender": 0.2, "age": 0.55, "muscle": 0.55, "weight": 0.45, "height": 0.5, "proportions": 0.55},
     race={"caucasian": 0.45, "african": 0.55, "asian": 0.0}, skin="young_african_female", skin_tint=(1.06, 1.0, 0.95),
     eye_color="brown", brows="eyebrow005", lashes="eyelashes03",
     hair={"asset": "elvs_braided_rows", "tint": (0.07, 0.05, 0.04)},
     clothes=[
         _g("elvs_hooded_sweat_jacket1", tint=(0.36, 0.27, 0.17), fabric="caban", tile=6, detail=0.5, mat="jacket"),
     ],
     props=["pocket_tools"], smile=0.12, turn=-10)

# Kit, DroneBudz support (about 29): calm, headset, warm olive jacket
cast("kit",
     macro={"gender": 0.7, "age": 0.53, "muscle": 0.4, "weight": 0.42, "height": 0.5, "proportions": 0.55},
     race={"caucasian": 0.6, "african": 0.0, "asian": 0.4}, skin="young_caucasian_male", eye_color="green",
     brows="eyebrow002", lashes="eyelashes01",
     hair={"asset": "cortu_short_messy_hair", "tint": (0.16, 0.11, 0.07)},
     clothes=[
         _g("toigo_basic_tucked_t-shirt", tint=(0.80, 0.76, 0.64), fabric="cotton_jersey", tile=6, detail=0.3, mat="tee"),
         _g("elvs_hooded_sweat_jacket1", tint=(0.30, 0.33, 0.15), fabric="caban", tile=6, detail=0.5, mat="jacket"),
         _g("punkduck_wireless_headset", mat="headset", keep_color=True, rim=False, covers=False),
     ],
     smile=0.45, turn=10)

# Unknown account: a dark beanie and a high scarf, lit only from behind; no readable face
cast("unknown",
     macro={"gender": 0.6, "age": 0.55, "muscle": 0.5, "weight": 0.45, "height": 0.52, "proportions": 0.55},
     race=CAUC, skin="young_caucasian_male2", skin_tint=(0.35, 0.33, 0.32), eye_color="grey", brows="eyebrow002", lashes="eyelashes01",
     clothes=[
         _g("elvs_hooded_sweat_jacket1", tint=(0.08, 0.09, 0.10), fabric="polar_fleece", tile=6, detail=0.4, mat="jacket"),
         _g("elvs_slouchy_beanie1", tint=(0.07, 0.08, 0.08), fabric="knitted_fleece", tile=5, detail=0.5, mat="beanie", covers=False, hat=True),
     ],
     props=["gaiter"], backlit=True, turn=-24)

# You, the pilot (no fixed gender): FPV goggles down over the eyes, the visor reflecting the sky
cast("you",
     macro={"gender": 0.5, "age": 0.52, "muscle": 0.45, "weight": 0.42, "height": 0.5, "proportions": 0.55},
     race=MIX, skin="young_caucasian_male2", skin_tint=(0.93, 0.86, 0.80), eye_color="brownlight",
     brows="eyebrow002", lashes="eyelashes01",
     hair={"asset": "short01", "tint": (0.17, 0.12, 0.09)},
     clothes=[
         _g("elvs_hooded_sweat_jacket1", tint=(0.20, 0.23, 0.26), fabric="polar_fleece", tile=6, detail=0.4, mat="jacket"),
     ],
     props=["goggles"], smile=0.1, turn=0)

# Constable Rennick and Wren: the in-game people specs (assets/models/people), same face, hair and clothes
cast("rennick", base="rennick", smile=0.1, turn=-8)
cast("wren", base="wren", smile=0.3, turn=12)

PORTRAIT_CAST = ["maya", "jo", "riley", "tom", "alex", "sam", "rennick", "unknown", "you", "wren", "kit"]

# The people of AeroSim (Blender 2). Each entry is one exported character file assets/models/people/<name>.glb.
# macro: MakeHuman macro sliders (0..1). age: 0.1875 = 11 years, 0.5 = 25, 1.0 = 90 (linear between).
# clothes: MakeHuman assets fitted to the body; tint = sRGB colour that replaces the asset's own colour (its shading,
#   folds and seams are kept); fabric = Poly Haven photo texture blended in for weave, normal and roughness.
# extras: gear modelled in people_gear.py (backpack, peaked_cap, belt_kit, scarf).
# body: which animation library the person uses (male, female, child).
# Licences of every MakeHuman asset named here: assets/models/people/README.md.

def _g(asset, **kw):
    d = {"asset": asset}
    d.update(kw)
    return d

CAUC = {"caucasian": 1.0, "african": 0.0, "asian": 0.0}
AFR = {"caucasian": 0.0, "african": 1.0, "asian": 0.0}
ASN = {"caucasian": 0.0, "african": 0.0, "asian": 1.0}
MIX = {"caucasian": 0.45, "african": 0.35, "asian": 0.2}

ROSTER = {}

def person(name, **kw):
    kw["name"] = name
    kw.setdefault("hero", False)
    if not kw["hero"]:
        kw.setdefault("skin_tex", 512)
        kw.setdefault("cloth_tex", 512)
    ROSTER[name] = kw
    return kw

# ------------------------------------------------------------------ Ellis Voss: retired mechanic, about 70
person("ellis", body="male", hero=True,
       macro={"gender": 1.0, "age": 0.85, "muscle": 0.42, "weight": 0.56, "height": 0.47, "proportions": 0.55},
       race=CAUC, skin="old_caucasian_male", eye_color="bluegreen", brows="eyebrow006", lashes="eyelashes02",
       hair={"asset": "short04", "tint": (0.62, 0.6, 0.57)},
       clothes=[
           _g("toigo_fisherman_sweater", tint=(0.20, 0.21, 0.16), fabric="knitted_fleece", tile=7, detail=0.55, mat="jumper"),
           _g("toigo_wool_pants", tint=(0.20, 0.16, 0.11), fabric="ribbed_corduroy", tile=9, detail=0.45, mat="trousers"),
           _g("toigo_ankle_boots_male", tint=(0.22, 0.14, 0.08), tint_mix=0.85, fabric="brown_leather", tile=3, detail=0.35, mat="boots", rough_scale=0.8, rim=False),
           _g("elvs_male_flat_cap1", tint=(0.25, 0.22, 0.18), fabric="poly_wool_herringbone", tile=4, detail=0.6, mat="cap", covers=False, hat=True),
       ])

# ------------------------------------------------------------------ Constable Ada Rennick, present day (plain clothes)
person("rennick", body="female", hero=True,
       macro={"gender": 0.0, "age": 0.62, "muscle": 0.55, "weight": 0.45, "height": 0.6, "proportions": 0.6},
       race=CAUC, skin="middleage_caucasian_female", eye_color="brownlight", brows="eyebrow010", lashes="eyelashes03",
       hair={"asset": "ponytail01", "tint": (0.25, 0.16, 0.10)},
       clothes=[
           _g("elvs_hooded_sweat_jacket1", tint=(0.08, 0.10, 0.16), fabric="polar_fleece", tile=6, detail=0.35, mat="jacket"),
           _g("mindfront_female_trousers_1", tint=(0.11, 0.12, 0.15), fabric="poly_wool_herringbone", tile=7, detail=0.35, mat="trousers"),
           _g("toigo_ankle_boots_male", tint=(0.06, 0.06, 0.07), fabric="brown_leather", tile=3, detail=0.3, mat="boots", rim=False),
       ],
       extras=["belt_kit"], belt_dz=0.035, tri_budget=8100)

# ------------------------------------------------------------------ Rennick in uniform (police house), no weapon belt
person("rennick_uniform", body="female", hero=True,
       macro={"gender": 0.0, "age": 0.62, "muscle": 0.55, "weight": 0.45, "height": 0.6, "proportions": 0.6},
       race=CAUC, skin="middleage_caucasian_female", eye_color="brownlight", brows="eyebrow010", lashes="eyelashes03",
       hair={"asset": "ponytail01", "tint": (0.25, 0.16, 0.10)},
       clothes=[
           _g("toigo_female_double-breasted_suit", tint=(0.07, 0.09, 0.16), fabric="poly_wool_herringbone", tile=7, detail=0.35, mat="tunic"),
           _g("toigo_ankle_boots_male", tint=(0.04, 0.04, 0.05), fabric="brown_leather", tile=3, detail=0.3, mat="boots", rim=False),
       ],
       extras=["peaked_cap"], cap_color=(0.06, 0.07, 0.12))

# ------------------------------------------------------------------ Rennick 1984 (and the ghost, by material)
person("rennick_1984", body="female", hero=True,
       macro={"gender": 0.0, "age": 0.55, "muscle": 0.55, "weight": 0.45, "height": 0.6, "proportions": 0.6},
       race=CAUC, skin="young_caucasian_female", eye_color="brownlight", brows="eyebrow010", lashes="eyelashes03",
       hair={"asset": "ponytail01", "tint": (0.30, 0.19, 0.11)},
       clothes=[
           _g("toigo_female_suit_2", tint=(0.08, 0.09, 0.14), fabric="caban", tile=6, detail=0.45, mat="tunic"),
           _g("toigo_ankle_boots_male", tint=(0.03, 0.03, 0.035), fabric="brown_leather", tile=3, detail=0.3, mat="boots", rim=False),
       ],
       extras=["peaked_cap", "belt_kit"], cap_color=(0.07, 0.07, 0.11), belt_dz=0.05, tri_budget=7900)

# ------------------------------------------------------------------ Wren, the lost hiker
person("wren", body="female", hero=True,
       macro={"gender": 0.3, "age": 0.55, "muscle": 0.5, "weight": 0.42, "height": 0.5, "proportions": 0.55},
       race=MIX, skin="young_caucasian_female", skin_tint=(0.93, 0.88, 0.84), eye_color="green", brows="eyebrow002", lashes="eyelashes01",
       hair={"asset": "short01", "tint": (0.2, 0.13, 0.08)},
       clothes=[
           _g("elvs_hooded_sweat_jacket1", tint=(0.52, 0.11, 0.07), fabric="stretch_poplin", tile=6, detail=0.35, mat="raincoat", node="coat", rough_scale=0.7),
           _g("cortu_cargo_pants", tint=(0.20, 0.21, 0.16), fabric="rough_linen", tile=7, detail=0.5, mat="trousers"),
           _g("punkduck_winter_boots", tint=(0.25, 0.17, 0.10), tint_mix=0.8, fabric="scuba_suede", tile=3, detail=0.4, mat="boots", rim=False),
       ],
       extras=["backpack"], pack_color=(0.17, 0.19, 0.15))

# ------------------------------------------------------------------ the festival crowd (16 placements use these)
person("crowd_m1", body="male",
       macro={"gender": 1.0, "age": 0.68, "muscle": 0.5, "weight": 0.62, "height": 0.5},
       race=AFR, skin="middleage_african_male", eye_color="brown", brows="eyebrow003",
       hair={"asset": "short03", "tint": (0.06, 0.05, 0.05)},
       clothes=[_g("male_casualsuit03", tint=None, mat="suit"), _g("shoes02", mat="shoes", rim=False)],
       extras=["scarf"], scarf_color=(0.62, 0.48, 0.12))
person("crowd_m2", body="male",
       macro={"gender": 1.0, "age": 0.52, "muscle": 0.55, "weight": 0.45, "height": 0.55},
       race=ASN, skin="young_asian_male", eye_color="brown", brows="eyebrow001",
       hair={"asset": "short01", "tint": (0.05, 0.045, 0.04)},
       clothes=[_g("mindfront_knitted_sweater_01", tint=(0.42, 0.12, 0.10), fabric="knitted_fleece", tile=7, detail=0.5, mat="sweater"),
                _g("punkduck_male_classic_jeans", mat="jeans", fabric="denim_fabric_03", tile=6, detail=0.3, keep_color=True),
                _g("shoes05", mat="shoes", rim=False)])
person("crowd_m3", body="male",
       macro={"gender": 1.0, "age": 0.8, "muscle": 0.4, "weight": 0.6, "height": 0.45},
       race=CAUC, skin="old_caucasian_male", eye_color="grey", brows="eyebrow011",
       hair={"asset": "short02", "tint": (0.7, 0.68, 0.65)},
       clothes=[_g("toigo_male_suit_3", tint=(0.30, 0.26, 0.19), fabric="poly_wool_herringbone", tile=6, detail=0.5, mat="suit"),
                _g("shoes03", mat="shoes", rim=False),
                _g("elvs_male_flat_cap1", tint=(0.32, 0.30, 0.26), fabric="poly_wool_herringbone", tile=4, detail=0.6, mat="cap", covers=False, hat=True)])
person("crowd_f1", body="female",
       macro={"gender": 0.0, "age": 0.62, "muscle": 0.45, "weight": 0.5, "height": 0.5},
       race=CAUC, skin="middleage_caucasian_female", eye_color="blue", brows="eyebrow009",
       hair={"asset": "toigo_curled_under_bob", "tint": (0.45, 0.3, 0.17)},
       clothes=[_g("toigo_basic_tucked_t-shirt", tint=(0.85, 0.82, 0.75), fabric="cotton_jersey", tile=6, mat="tee"),
                _g("mindfront_cardigan_long_open_front", tint=(0.30, 0.36, 0.24), fabric="knitted_fleece", tile=7, detail=0.5, mat="cardigan"),
                _g("elvs_jeans_straight_leg", mat="jeans", fabric="denim_fabric_03", tile=6, detail=0.3, keep_color=True),
                _g("toigo_ankle_boots_male", tint=(0.2, 0.12, 0.07), mat="boots", rim=False)])
person("crowd_f2", body="female",
       macro={"gender": 0.0, "age": 0.82, "muscle": 0.4, "weight": 0.62, "height": 0.4},
       race=AFR, skin="old_african_female", eye_color="brown", brows="eyebrow005",
       hair={"asset": "afro01", "tint": (0.2, 0.19, 0.18)},
       clothes=[_g("janexx_old_female_sweater", tint=(0.48, 0.28, 0.36), fabric="wool_boucle", tile=4, detail=0.25, mat="sweater"),
                _g("mindfront_female_trousers_1", tint=(0.12, 0.12, 0.14), fabric="poly_wool_herringbone", tile=7, mat="trousers"),
                _g("toigo_ballet_flats", tint=(0.08, 0.06, 0.05), mat="shoes", rim=False)],
       extras=["scarf"], scarf_color=(0.2, 0.32, 0.45))
person("crowd_f3", body="female",
       macro={"gender": 0.0, "age": 0.5, "muscle": 0.5, "weight": 0.42, "height": 0.48},
       race=ASN, skin="young_asian_female", eye_color="brown", brows="eyebrow004",
       hair={"asset": "ponytail01", "tint": (0.05, 0.04, 0.035)},
       clothes=[_g("mindfront_lusekofta", mat="sweater", keep_color=True, fabric="knitted_fleece", tile=7, detail=0.3),
                _g("punkduck_female_tight_jeans", mat="jeans", fabric="denim_fabric_03", tile=6, detail=0.3, keep_color=True),
                _g("punkduck_female_half-boots", tint=(0.15, 0.1, 0.07), mat="boots", rim=False)])
person("child_boy", body="child",
       macro={"gender": 1.0, "age": 0.17, "muscle": 0.5, "weight": 0.5, "height": 0.5},
       race=CAUC, skin="young_caucasian_male", eye_color="blue", brows="eyebrow001", proxy="male1591",
       hair={"asset": "cortu_short_messy_hair", "tint": (0.5, 0.35, 0.18)},
       clothes=[_g("male_casualsuit06", mat="suit"), _g("shoes06", mat="shoes", rim=False)])
person("child_girl", body="child",
       macro={"gender": 0.0, "age": 0.15, "muscle": 0.5, "weight": 0.5, "height": 0.5},
       race=AFR, skin="young_african_female", eye_color="brown", brows="eyebrow002", proxy="female1605",
       hair={"asset": "ponytail01", "tint": (0.06, 0.045, 0.04)},
       clothes=[_g("mindfront_knitted_sweater_02", tint=(0.78, 0.30, 0.34), fabric="knitted_fleece", tile=6, detail=0.45, mat="sweater"),
                _g("punkduck_female_tight_jeans", mat="jeans", fabric="denim_fabric_03", tile=6, detail=0.3, keep_color=True),
                _g("toigo_mj_cloth_shoes", tint=(0.9, 0.88, 0.85), mat="shoes", rim=False)])

# ------------------------------------------------------------------ the band (singer, guitar, fiddle, drummer)
person("band_singer", body="female",
       macro={"gender": 0.0, "age": 0.55, "muscle": 0.5, "weight": 0.48, "height": 0.55},
       race=CAUC, skin="young_caucasian_female2", eye_color="green", brows="eyebrow008",
       hair={"asset": "long01", "tint": (0.55, 0.22, 0.08)},
       clothes=[_g("female_elegantsuit01", tint=(0.40, 0.08, 0.10), fabric="velour_velvet" if False else "caban", tile=6, detail=0.3, mat="suit"),
                _g("toigo_ankle_boots_male", tint=(0.08, 0.06, 0.05), mat="boots", rim=False)])
person("band_guitar", body="male",
       macro={"gender": 1.0, "age": 0.58, "muscle": 0.5, "weight": 0.5, "height": 0.58},
       race=MIX, skin="middleage_african_male", skin_tint=(1.12, 1.1, 1.08), eye_color="brown", brows="eyebrow004",
       hair={"asset": "short01", "tint": (0.07, 0.05, 0.04)},
       clothes=[_g("male_casualsuit05", mat="suit"), _g("shoes04", mat="shoes", rim=False)])
person("band_fiddle", body="male",
       macro={"gender": 1.0, "age": 0.78, "muscle": 0.45, "weight": 0.55, "height": 0.48},
       race=CAUC, skin="old_caucasian_male", eye_color="blue", brows="eyebrow006",
       hair={"asset": "short02", "tint": (0.55, 0.45, 0.35)},
       clothes=[_g("elvs_male_shirt_tie_tucked1", tint=(0.86, 0.84, 0.78), fabric="stretch_poplin", tile=6, mat="shirt", keep_color=False),
                _g("mindfront_male_trousers_1", tint=(0.12, 0.13, 0.12), fabric="poly_wool_herringbone", tile=7, mat="trousers"),
                _g("shoes03", mat="shoes", rim=False)],
       extras=["scarf"], scarf_color=(0.1, 0.25, 0.15))
person("band_drummer", body="male",
       macro={"gender": 1.0, "age": 0.5, "muscle": 0.6, "weight": 0.58, "height": 0.52},
       race=ASN, skin="young_asian_male", eye_color="brown", brows="eyebrow001",
       hair={"asset": "short04", "tint": (0.05, 0.045, 0.04)},
       clothes=[_g("namuhekam_male_polo_shirt", tint=(0.12, 0.2, 0.32), fabric="cotton_jersey", tile=6, mat="polo"),
                _g("cortu_cargo_pants", tint=(0.32, 0.28, 0.2), fabric="rough_linen", tile=7, mat="trousers"),
                _g("shoes02", mat="shoes", rim=False)])

# ------------------------------------------------------------------ generic pilot and bystander
person("pilot", body="male",
       macro={"gender": 1.0, "age": 0.56, "muscle": 0.55, "weight": 0.5, "height": 0.55},
       race=CAUC, skin="young_caucasian_male2", eye_color="brownlight", brows="eyebrow002",
       hair={"asset": "short01", "tint": (0.3, 0.2, 0.12)},
       clothes=[_g("elvs_hooded_sweat_jacket1", tint=(0.18, 0.2, 0.24), fabric="polar_fleece", tile=6, detail=0.4, mat="jacket"),
                _g("cortu_cargo_pants", tint=(0.26, 0.25, 0.2), fabric="rough_linen", tile=7, mat="trousers"),
                _g("shoes05", mat="shoes", rim=False)])
person("bystander", body="female",
       macro={"gender": 0.0, "age": 0.7, "muscle": 0.45, "weight": 0.55, "height": 0.45},
       race=CAUC, skin="middleage_caucasian_female", eye_color="grey", brows="eyebrow009",
       hair={"asset": "bob02", "tint": (0.62, 0.6, 0.57)},
       clothes=[_g("toigo_female_suit_2", tint=(0.36, 0.3, 0.22), fabric="caban", tile=6, detail=0.4, mat="coat"),
                _g("toigo_ankle_boots_male", tint=(0.1, 0.07, 0.05), mat="boots", rim=False)],
       extras=["scarf"], scarf_color=(0.7, 0.62, 0.45))

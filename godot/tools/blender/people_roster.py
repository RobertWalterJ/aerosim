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

# Wren: rebuilt to the character brief by lane/antidrone (see the end of this file).

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

# ================================================================== lane/antidrone: the rest of the story's people
# The village cast, Wren and the minor voices from docs/CLAUDE-CHARACTER-BRIEF-2026-11-15.md (lane/notify; its costumes and
# ages win over the code placeholders), the DroneBudz crew from the phone app portraits (appui_roster.py, so a model matches
# its avatar), and the other people the story names (Harlan Pike, the farmer, Nora Pike, Councillor Bain). All use the same
# MakeHuman body, rig and the shared clip libraries. Age slider: 0.5 = 25 years, 1.0 = 90 (linear). Skin index n in the
# comments is the brief's palette (character_actor.gd).
#   0 deep brown, 1 rich brown, 2 warm brown, 3 golden tan, 4 light tan, 5 olive, 6 fair, 7 east asian light, 8 south asian

def _age(years):
    return round(0.5 + (years - 25) / 65.0 * 0.5, 3)

SASN = {"caucasian": 0.45, "african": 0.15, "asian": 0.4}

# 1 Ifeoma Okafor, sub-postmistress, 50s, skin 0, braids greying, 1.66 m broad: teal wool coat, ochre scarf
person("ifeoma_okafor", body="female",
       macro={"gender": 0.0, "age": _age(55), "muscle": 0.5, "weight": 0.64, "height": 0.56, "proportions": 0.5},
       race=AFR, skin="middleage_african_female", skin_tint=(0.82, 0.8, 0.8), eye_color="brown", brows="eyebrow005",
       hair={"asset": "elvs_braided_rows", "tint": (0.22, 0.2, 0.19)},
       clothes=[_g("toigo_female_double-breasted_suit", tint=(0.17, 0.34, 0.33), fabric="caban", tile=6, detail=0.45, mat="coat"),
                _g("mindfront_female_trousers_1", tint=(0.13, 0.16, 0.16), fabric="poly_wool_herringbone", tile=7, mat="trousers"),
                _g("toigo_ankle_boots_female", tint=(0.09, 0.07, 0.05), mat="boots", rim=False)],
       extras=["scarf"], scarf_color=(0.74, 0.47, 0.16))

# 2 Mei Lin, shopkeeper, 40s, skin 7, straight bob, 1.63 m slight: deep red padded coat, yellow scarf
person("mei_lin", body="female",
       macro={"gender": 0.0, "age": _age(45), "muscle": 0.45, "weight": 0.38, "height": 0.48, "proportions": 0.55},
       race=ASN, skin="middleage_asian_female", eye_color="brown", brows="eyebrow004",
       hair={"asset": "toigo_blunt_bob", "tint": (0.04, 0.035, 0.03)},
       clothes=[_g("elvs_hooded_sweat_jacket1", tint=(0.47, 0.13, 0.11), fabric="polar_fleece", tile=6, detail=0.4, mat="coat"),
                _g("mindfront_female_trousers_1", tint=(0.15, 0.16, 0.19), fabric="poly_wool_herringbone", tile=7, mat="trousers"),
                _g("toigo_ankle_boots_female", tint=(0.08, 0.06, 0.05), mat="boots", rim=False)],
       extras=["scarf"], scarf_color=(0.82, 0.64, 0.2))

# 3 Ravi Patel, mechanic and garage owner, 30s, skin 8, short crop, 1.72 m wiry: blue overalls, red scarf
person("ravi_patel", body="male",
       macro={"gender": 1.0, "age": _age(35), "muscle": 0.58, "weight": 0.4, "height": 0.44, "proportions": 0.55},
       race=SASN, skin="middleage_caucasian_male", skin_tint=(0.7, 0.55, 0.43), eye_color="brown", brows="eyebrow003",
       hair={"asset": "short04", "tint": (0.04, 0.035, 0.03)},
       clothes=[_g("elvs_male_coveralls_1", tint=(0.17, 0.23, 0.37), fabric="rough_linen", tile=7, detail=0.5, mat="overalls"),
                _g("toigo_ankle_boots_male", tint=(0.1, 0.07, 0.05), mat="boots", rim=False)],
       extras=["scarf"], scarf_color=(0.54, 0.16, 0.12))

# 4 Grace Adeyemi, landlady and cook of The Hollow Crown, 50s, skin 2, low bun, 1.65 m sturdy: ochre top, green scarf
#   (the brief's dark apron is an indoor garment and has no MakeHuman asset; her trousers carry the dark tone)
person("grace_adeyemi", body="female",
       macro={"gender": 0.0, "age": _age(55), "muscle": 0.5, "weight": 0.66, "height": 0.53, "proportions": 0.5},
       race=AFR, skin="middleage_african_female", skin_tint=(1.08, 1.04, 1.0), eye_color="brown", brows="eyebrow003",
       hair={"asset": "elvs_braid_bun", "tint": (0.06, 0.05, 0.045)},
       clothes=[_g("mindfront_knitted_sweater_01", tint=(0.52, 0.35, 0.14), fabric="knitted_fleece", tile=7, detail=0.5, mat="sweater"),
                _g("mindfront_female_trousers_1", tint=(0.1, 0.1, 0.09), fabric="poly_wool_herringbone", tile=7, mat="trousers"),
                _g("toigo_ankle_boots_female", tint=(0.07, 0.05, 0.04), mat="boots", rim=False)],
       extras=["scarf"], scarf_color=(0.18, 0.28, 0.25))

# 5 Hana Sato, village bus driver, 40s, skin 5 (olive), ponytail, 1.62 m slight: navy bus-company fleece, red scarf
person("hana_sato", body="female",
       macro={"gender": 0.0, "age": _age(40), "muscle": 0.48, "weight": 0.4, "height": 0.46, "proportions": 0.55},
       race={"caucasian": 0.45, "african": 0.0, "asian": 0.55}, skin="middleage_asian_female", skin_tint=(0.95, 0.9, 0.82),
       eye_color="brown", brows="eyebrow004",
       hair={"asset": "ponytail01", "tint": (0.05, 0.04, 0.035)},
       clothes=[_g("elvs_hooded_sweat_jacket1", tint=(0.2, 0.27, 0.42), fabric="polar_fleece", tile=6, detail=0.4, mat="fleece"),
                _g("mindfront_female_trousers_1", tint=(0.17, 0.17, 0.19), fabric="poly_wool_herringbone", tile=7, mat="trousers"),
                _g("toigo_ankle_boots_female", tint=(0.06, 0.05, 0.05), mat="boots", rim=False)],
       extras=["scarf"], scarf_color=(0.64, 0.21, 0.16))

# 6 Priya Nair, district nurse, 30s, skin 3 (golden tan), long hair tied back, 1.68 m: green coat, tan scarf
person("priya_nair", body="female",
       macro={"gender": 0.0, "age": _age(32), "muscle": 0.5, "weight": 0.46, "height": 0.6, "proportions": 0.55},
       race=SASN, skin="young_caucasian_female", skin_tint=(0.8, 0.64, 0.5), eye_color="brown", brows="eyebrow004",
       hair={"asset": "ponytail01", "tint": (0.035, 0.03, 0.028)},
       clothes=[_g("toigo_female_suit", tint=(0.2, 0.35, 0.24), fabric="caban", tile=6, detail=0.45, mat="coat"),
                _g("mindfront_female_trousers_1", tint=(0.16, 0.15, 0.14), fabric="poly_wool_herringbone", tile=7, mat="trousers"),
                _g("toigo_ankle_boots_female", tint=(0.08, 0.06, 0.05), mat="boots", rim=False)],
       extras=["scarf"], scarf_color=(0.58, 0.38, 0.18))

# 7 Daniel Whitlock, retired farm machinery salesman, 70s, skin 6, short grey, 1.71 m stooped: olive coat, brown scarf
person("daniel_whitlock", body="male",
       macro={"gender": 1.0, "age": _age(72), "muscle": 0.4, "weight": 0.58, "height": 0.4, "proportions": 0.45},
       race=CAUC, skin="old_caucasian_male", eye_color="grey", brows="eyebrow011",
       hair={"asset": "short02", "tint": (0.66, 0.65, 0.63)},
       clothes=[_g("toigo_male_suit_3", tint=(0.29, 0.32, 0.24), fabric="caban", tile=6, detail=0.5, mat="coat"),
                _g("shoes03", mat="shoes", rim=False)],
       extras=["scarf"], scarf_color=(0.4, 0.26, 0.18))

# 8 Arthur Bell, farm hand, 20s, skin 4 (light tan), short brown, 1.75 m lanky: dark work coat, maroon scarf, boots
person("arthur_bell", body="male",
       macro={"gender": 1.0, "age": _age(22), "muscle": 0.52, "weight": 0.36, "height": 0.52, "proportions": 0.55},
       race=CAUC, skin="young_caucasian_male", skin_tint=(0.94, 0.84, 0.74), eye_color="brownlight", brows="eyebrow001",
       hair={"asset": "short01", "tint": (0.33, 0.21, 0.11)},
       clothes=[_g("elvs_hooded_sweat_jacket1", tint=(0.23, 0.22, 0.2), fabric="caban", tile=6, detail=0.5, mat="coat"),
                _g("cortu_cargo_pants", tint=(0.12, 0.14, 0.13), fabric="rough_linen", tile=7, mat="trousers"),
                _g("punkduck_winter_boots", tint=(0.12, 0.1, 0.08), tint_mix=0.8, mat="boots", rim=False)],
       extras=["scarf"], scarf_color=(0.36, 0.11, 0.09))

# 9 Wren, the lost hiker (rebuilt to the brief): late 20s, skin 1 (rich brown), crop, 1.67 m slight, they/them: mustard rain
#   jacket, dark trousers, brown scarf, backpack. Replaces the earlier red-jacket, mixed-skin Wren under the same name.
person("wren", body="female", hero=True,
       macro={"gender": 0.3, "age": _age(27), "muscle": 0.5, "weight": 0.4, "height": 0.5, "proportions": 0.55},
       race=AFR, skin="young_african_female", skin_tint=(0.95, 0.92, 0.9), eye_color="brown", brows="eyebrow002", lashes="eyelashes01",
       hair={"asset": "short01", "tint": (0.04, 0.035, 0.03)},
       clothes=[
           _g("elvs_hooded_sweat_jacket1", tint=(0.62, 0.4, 0.14), fabric="stretch_poplin", tile=6, detail=0.35, mat="raincoat", node="coat", rough_scale=0.7),
           _g("cortu_cargo_pants", tint=(0.14, 0.17, 0.17), fabric="rough_linen", tile=7, detail=0.5, mat="trousers"),
           _g("punkduck_winter_boots", tint=(0.22, 0.15, 0.09), tint_mix=0.8, fabric="scuba_suede", tile=3, detail=0.4, mat="boots", rim=False),
       ],
       extras=["backpack", "scarf"], pack_color=(0.17, 0.19, 0.15), scarf_color=(0.42, 0.21, 0.09))

# ------------------------------------------------------------------ the DroneBudz crew (bodies to match their app portraits)
# Maya, editor and channel owner (about 34): long black hair, rust jumper, dark jeans
person("maya", body="female",
       macro={"gender": 0.0, "age": 0.57, "muscle": 0.42, "weight": 0.44, "height": 0.5, "proportions": 0.55},
       race={"caucasian": 0.25, "african": 0.0, "asian": 0.75}, skin="young_asian_female", eye_color="brown", brows="eyebrow004",
       hair={"asset": "long01", "tint": (0.07, 0.05, 0.045)},
       clothes=[_g("mindfront_knitted_sweater_02", tint=(0.55, 0.22, 0.12), fabric="knitted_fleece", tile=7, detail=0.55, mat="sweater"),
                _g("punkduck_female_tight_jeans", mat="jeans", fabric="denim_fabric_03", tile=6, detail=0.3, tint=(0.12, 0.13, 0.17)),
                _g("toigo_ankle_boots_female", tint=(0.08, 0.06, 0.05), mat="boots", rim=False)])
# Jo, events and bookings (about 46): auburn bob, slate-blue shirt, dark trousers
person("jo", body="female",
       macro={"gender": 0.0, "age": 0.66, "muscle": 0.5, "weight": 0.56, "height": 0.5, "proportions": 0.5},
       race=CAUC, skin="middleage_caucasian_female", eye_color="bluegreen", brows="eyebrow009",
       hair={"asset": "toigo_curled_under_bob", "tint": (0.30, 0.14, 0.07)},
       clothes=[_g("elvs_male_shirt_untucked_bd1", tint=(0.30, 0.42, 0.52), fabric="stretch_poplin", tile=6, detail=0.3, mat="shirt"),
                _g("mindfront_female_trousers_1", tint=(0.14, 0.14, 0.16), fabric="poly_wool_herringbone", tile=7, mat="trousers"),
                _g("toigo_ballet_flats", tint=(0.1, 0.07, 0.05), mat="shoes", rim=False)])
# Riley, park ranger (about 38): moss fleece, work trousers, boots, no insignia
person("riley", body="male",
       macro={"gender": 1.0, "age": 0.6, "muscle": 0.6, "weight": 0.5, "height": 0.55, "proportions": 0.55},
       race=AFR, skin="middleage_african_male", eye_color="brown", brows="eyebrow003",
       hair={"asset": "short04", "tint": (0.04, 0.035, 0.035)},
       clothes=[_g("mindfront_knitted_sweater_02", tint=(0.22, 0.32, 0.19), fabric="polar_fleece", tile=6, detail=0.5, mat="fleece"),
                _g("cortu_cargo_pants", tint=(0.24, 0.24, 0.19), fabric="rough_linen", tile=7, mat="trousers"),
                _g("culturalibre_male_boots", tint=(0.14, 0.1, 0.07), mat="boots", rim=False)])
# Tom, storm chaser (about 52): weather-beaten, bucket hat, mustard jacket, cargo trousers
person("tom", body="male",
       macro={"gender": 1.0, "age": 0.74, "muscle": 0.5, "weight": 0.52, "height": 0.52, "proportions": 0.55},
       race=CAUC, skin="old_caucasian_male", eye_color="blue", brows="eyebrow006",
       hair={"asset": "short02", "tint": (0.52, 0.48, 0.42)},
       clothes=[_g("elvs_hooded_sweat_jacket1", tint=(0.62, 0.45, 0.13), fabric="stretch_poplin", tile=6, detail=0.4, mat="jacket"),
                _g("cortu_cargo_pants", tint=(0.3, 0.29, 0.22), fabric="rough_linen", tile=7, mat="trousers"),
                _g("shoes05", mat="shoes", rim=False),
                _g("mindfront_fishing_hat_01", tint=(0.33, 0.33, 0.25), fabric="rough_linen", tile=4, detail=0.5, mat="hat", covers=False, hat=True)])
# Alex, Facade seller and tinkerer (about 41): grey-blue coveralls
person("alex", body="male",
       macro={"gender": 0.85, "age": 0.62, "muscle": 0.45, "weight": 0.42, "height": 0.5, "proportions": 0.55},
       race=ASN, skin="middleage_asian_male", eye_color="brown", brows="eyebrow002",
       hair={"asset": "short04", "tint": (0.05, 0.045, 0.04)},
       clothes=[_g("elvs_male_coveralls_1", tint=(0.27, 0.34, 0.40), fabric="rough_linen", tile=7, detail=0.5, mat="overalls"),
                _g("shoes02", mat="shoes", rim=False)])
# Sam, crew and fixer (about 33): tan canvas utility jacket, braided rows, cargo trousers
person("sam", body="female",
       macro={"gender": 0.2, "age": 0.55, "muscle": 0.55, "weight": 0.45, "height": 0.5, "proportions": 0.55},
       race={"caucasian": 0.45, "african": 0.55, "asian": 0.0}, skin="young_african_female", skin_tint=(1.06, 1.0, 0.95),
       eye_color="brown", brows="eyebrow005",
       hair={"asset": "elvs_braided_rows", "tint": (0.07, 0.05, 0.04)},
       clothes=[_g("elvs_hooded_sweat_jacket1", tint=(0.36, 0.27, 0.17), fabric="caban", tile=6, detail=0.5, mat="jacket"),
                _g("cortu_cargo_pants", tint=(0.18, 0.18, 0.16), fabric="rough_linen", tile=7, mat="trousers"),
                _g("punkduck_female_half-boots", tint=(0.12, 0.09, 0.06), mat="boots", rim=False)])
# Kit, DroneBudz support (about 29): calm, olive jacket over a pale tee, jeans
person("kit", body="male",
       macro={"gender": 0.7, "age": 0.53, "muscle": 0.4, "weight": 0.42, "height": 0.5, "proportions": 0.55},
       race={"caucasian": 0.6, "african": 0.0, "asian": 0.4}, skin="young_caucasian_male", eye_color="green", brows="eyebrow002",
       hair={"asset": "cortu_short_messy_hair", "tint": (0.16, 0.11, 0.07)},
       clothes=[_g("toigo_basic_tucked_t-shirt", tint=(0.80, 0.76, 0.64), fabric="cotton_jersey", tile=6, detail=0.3, mat="tee"),
                _g("elvs_hooded_sweat_jacket1", tint=(0.30, 0.33, 0.15), fabric="caban", tile=6, detail=0.5, mat="jacket"),
                _g("punkduck_male_classic_jeans", mat="jeans", fabric="denim_fabric_03", tile=6, detail=0.3, keep_color=True),
                _g("shoes05", mat="shoes", rim=False)])

# ------------------------------------------------------------------ the other people the story names
# Harlan Pike, freeman-on-the-land on the north ridge (about 52): a neighbour with a bad fence, not a soldier. Drab waxed
#   jacket, work trousers, boots, knitted hat. Never in the chat; here so the code can show him at a distance if it chooses.
person("harlan_pike", body="male",
       macro={"gender": 1.0, "age": _age(52), "muscle": 0.55, "weight": 0.62, "height": 0.55, "proportions": 0.5},
       race=CAUC, skin="middleage_caucasian_male", skin_tint=(1.0, 0.94, 0.9), eye_color="grey", brows="eyebrow006",
       hair={"asset": "short02", "tint": (0.38, 0.33, 0.27), "budget": 500},
       clothes=[_g("elvs_hooded_sweat_jacket1", tint=(0.25, 0.25, 0.18), fabric="caban", tile=6, detail=0.55, mat="jacket", rough_scale=0.8),
                _g("cortu_cargo_pants", tint=(0.2, 0.18, 0.14), fabric="rough_linen", tile=7, detail=0.5, mat="trousers"),
                _g("culturalibre_male_boots", tint=(0.12, 0.09, 0.06), mat="boots", rim=False),
                _g("elvs_slouchy_beanie1", tint=(0.2, 0.2, 0.17), fabric="knitted_fleece", tile=4, detail=0.6, mat="hat", covers=False, hat=True)])
# The farmer (the storm shelter beat; Rennick and Riley open the shelter with him), about 60: flat cap, jumper, boots
person("farmer", body="male",
       macro={"gender": 1.0, "age": _age(60), "muscle": 0.6, "weight": 0.6, "height": 0.5, "proportions": 0.5},
       race={"caucasian": 0.3, "african": 0.7, "asian": 0.0}, skin="old_african_male", skin_tint=(1.05, 1.02, 1.0), eye_color="brown", brows="eyebrow003",
       hair={"asset": "short03", "tint": (0.42, 0.4, 0.38)},
       clothes=[_g("toigo_fisherman_sweater", tint=(0.24, 0.3, 0.2), fabric="knitted_fleece", tile=7, detail=0.55, mat="jumper"),
                _g("toigo_wool_pants", tint=(0.22, 0.2, 0.16), fabric="ribbed_corduroy", tile=9, detail=0.45, mat="trousers"),
                _g("punkduck_winter_boots", tint=(0.1, 0.12, 0.09), tint_mix=0.85, mat="boots", rim=False),
                _g("elvs_male_flat_cap1", tint=(0.3, 0.27, 0.2), fabric="poly_wool_herringbone", tile=4, detail=0.6, mat="cap", covers=False, hat=True)])
# Nora Pike, at the pub (40s): cardigan over a tee, jeans
person("nora_pike", body="female",
       macro={"gender": 0.0, "age": _age(44), "muscle": 0.45, "weight": 0.5, "height": 0.5, "proportions": 0.5},
       race=CAUC, skin="middleage_caucasian_female", eye_color="blue", brows="eyebrow009",
       hair={"asset": "bob02", "tint": (0.42, 0.3, 0.2)},
       clothes=[_g("toigo_basic_tucked_t-shirt", tint=(0.78, 0.76, 0.7), fabric="cotton_jersey", tile=6, mat="tee"),
                _g("mindfront_cardigan_long_open_front", tint=(0.4, 0.22, 0.24), fabric="knitted_fleece", tile=7, detail=0.5, mat="cardigan"),
                _g("elvs_jeans_straight_leg", mat="jeans", fabric="denim_fabric_03", tile=6, detail=0.3, keep_color=True),
                _g("toigo_ankle_boots_female", tint=(0.12, 0.08, 0.05), mat="boots", rim=False)])
# Councillor Bain, festival committee (60s): suit and tie, the one official in a town of coats
person("councillor_bain", body="male",
       macro={"gender": 1.0, "age": _age(64), "muscle": 0.45, "weight": 0.62, "height": 0.5, "proportions": 0.5},
       race=ASN, skin="old_asian_male", eye_color="brown", brows="eyebrow011",
       hair={"asset": "short02", "tint": (0.6, 0.59, 0.57)},
       clothes=[_g("toigo_male_suit_tie_and_jacket", tint=(0.17, 0.19, 0.24), fabric="poly_wool_herringbone", tile=6, detail=0.35, mat="suit"),
                _g("shoes03", mat="shoes", rim=False)])

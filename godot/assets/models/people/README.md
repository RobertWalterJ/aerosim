# People (Blender 2): sources and licences

Every person here is built by the Blender scripts in `godot/tools/blender/` (see `game/README-models.md`, "Blender 2").
The bodies, faces, rigs, skins, eyes, brows, lashes, hair and most clothes are MakeHuman assets, loaded and fitted with the
MPFB 2 extension for Blender (extension v2.0.18 from extensions.blender.org; MPFB's own code is GPL-3, which does not
apply to the meshes and textures it produces from CC0 data). Fabrics are Poly Haven photographs (CC0), listed in
`godot/assets/textures/README.md`. Gear and props (backpack, peaked cap and badge, duty belt, scarf, mugs, clipboard,
phone, torch, flag, instruments, creeper, toolbox, camp chair, drum kit) are modelled by the scripts and are original.

## MakeHuman data (CC0, public domain)

From the MakeHuman community asset repository (`makehuman_system_assets_cc0.zip` and the CC0 packs `hats01`, `shoes01`,
`shirts01`, `pants01`, `suits01`, `hair01`, all from https://static.makehumancommunity.org/assets/assetpacks.html),
downloaded 2026-10-24. The MakeHuman base mesh (hm08), its targets (age, gender, weight, race, the expression units used
for blink and mouth shapes), the proxies `male1591` and `female1605`, the game_engine rig and its weights, the skins
(`old_caucasian_male`, `middleage_*`, `young_*`, `old_african_female`), the low-poly eyes and eye textures, eyebrows
`eyebrow001` to `eyebrow011`, eyelashes `eyelashes01` to `03` and the system hair (`short01` to `04`, `afro01`,
`long01`, `ponytail01`, `bob02`) were released CC0 by Data Collection AB, Joel Palmius and Jonas Hauquier (September 2020).

| Asset | Author | Licence | Worn by |
|---|---|---|---|
| `toigo_fisherman_sweater`, `toigo_wool_pants`, `toigo_ankle_boots_male`, `toigo_ankle_boots_female`, `toigo_ballet_flats`, `toigo_mj_cloth_shoes`, `toigo_basic_tucked_t-shirt`, `toigo_female_suit`, `toigo_female_suit_2`, `toigo_female_double-breasted_suit`, `toigo_male_suit_3`, `toigo_curled_under_bob` | MRT (Margaret Toigo) | CC0 | Ellis, Rennick, crowd, bystander |
| `cortu_cargo_pants`, `cortu_short_messy_hair` | cortu | CC0 (asset repository listing) | drummer, pilot, boy |
| `namuhekam_male_polo_shirt` | namuhekam | CC0 | drummer |
| `janexx_old_female_sweater` | unknown (listed CC0) | CC0 | crowd_f2 |
| `male_casualsuit03`, `male_casualsuit05`, `male_casualsuit06`, `female_elegantsuit01`, `female_sportsuit01`, `shoes02` to `shoes06` | MakeHuman team | CC0 | crowd, band, Rennick uniform |

## MakeHuman community assets under CC BY (attribution required)

| Asset | Author | Licence | Worn by |
|---|---|---|---|
| `elvs_male_flat_cap1` | Elvaerwyn | CC BY 4.0 | Ellis (the flat cap) |
| `elvs_hooded_sweat_jacket1` | Elvaerwyn | CC BY | Wren (as a rain jacket), pilot |
| `elvs_jeans_straight_leg` | Elvaerwyn | CC BY | crowd_f1 |
| `elvs_male_shirt_tie_tucked1` | Elvaerwyn | CC BY | fiddler |
| `mindfront_knitted_sweater_01`, `mindfront_cardigan_long_open_front`, `mindfront_female_trousers_1`, `mindfront_male_trousers_1`, `mindfront_lusekofta` | Mindfront (Sweden) | CC BY 4.0 | crowd, fiddler |
| `punkduck_male_classic_jeans`, `punkduck_female_half-boots` | punkduck | CC BY 4.0 | crowd |
| `punkduck_female_tight_jeans`, `punkduck_winter_boots` | punkduck | CC BY 3.0 | crowd_f3, Wren |

The CC BY packs are `shirts02`, `pants02`, `shoes03`, `hats03` (downloaded 2026-10-24 from files.makehumancommunity.org).
Credit line for the game's credits: "People made with MakeHuman and MPFB; clothing by Elvaerwyn, Mindfront and punkduck
(CC BY), MRT, cortu and the MakeHuman team (CC0); fabrics from Poly Haven (CC0)."

Avoided on purpose: assets with real logos, emblems or slogans (the MakeHuman logo T-shirts, the EMT jacket's red cross,
a political cap), weapons and tactical vests, and two hair assets whose files still carry an AGPL header.

## Files

`<person>.glb` (19 people), `anim_male.glb`, `anim_female.glb`, `anim_child.glb` (the shared clips on a reference body),
`people_props.glb` (props, one root node each, named `prop_<name>`). Build report with triangle counts:
`_tools/people/build_report.json` (outside the repository). Sizes are listed in the Blender 2 contract.

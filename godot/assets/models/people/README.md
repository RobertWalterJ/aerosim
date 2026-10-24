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

`<person>.glb` (38 people: the 19 of lane/people and 19 added by lane/antidrone, see below; Wren rebuilt), `anim_male.glb`, `anim_female.glb`, `anim_child.glb` (the shared clips on a reference body),
`people_props.glb` (props, one root node each, named `prop_<name>`). Build report with triangle counts:
`_tools/people/build_report.json` (outside the repository). Sizes are listed in the Blender 2 contract.

## Added by lane/antidrone (2026-10-24)

The village cast of `docs/CLAUDE-CHARACTER-BRIEF-2026-11-15.md` (Ifeoma Okafor, Mei Lin, Ravi Patel, Grace Adeyemi, Hana Sato,
Priya Nair, Daniel Whitlock, Arthur Bell), Wren rebuilt to that brief (rich brown skin, crop, mustard rain jacket, dark trousers,
brown scarf, backpack), the DroneBudz crew to match their app portraits (Maya, Jo, Riley, Tom, Alex, Sam, Kit), and the other
people the story names (Harlan Pike, the farmer, Nora Pike, Councillor Bain). Same pipeline, rig and clips. New MakeHuman assets:

| Asset | Author | Licence | Worn by |
|---|---|---|---|
| `elvs_male_coveralls_1`, `elvs_male_shirt_untucked_bd1`, `elvs_slouchy_beanie1`, `elvs_braided_rows`, `elvs_braid_bun` | Elvaerwyn | CC BY | Ravi, Alex (coveralls); Jo (shirt); Harlan Pike (beanie); Ifeoma, Sam (braided rows); Grace (bun) |
| `mindfront_knitted_sweater_02`, `mindfront_fishing_hat_01` | Mindfront | CC BY 4.0 | Maya, Riley; Tom |
| `toigo_blunt_bob`, `toigo_female_suit`, `toigo_male_suit_tie_and_jacket` | MRT | CC0 | Mei; Priya; Councillor Bain |
| `culturalibre_male_boots` | culturalibre | CC0 | Riley, Harlan Pike |

Avoided: `rehmanpolanski_hair_bun_brown` (AGPL header). Gaps against the brief: no aprons, reading glasses or medical bag (no
asset; Grace's and Mei's aprons are indoor garments), Grace's bun sits high rather than low, Priya wears a ponytail (her braid
asset broke the LOD2 budget).

## Constable Ada Rennick remade by lane/rennick (2026-10-24)

`rennick.glb` (plain clothes), `rennick_uniform.glb` (today's uniform), `rennick_1984.glb` (1984 uniform) and the new
`rennick_1984_ghost.glb` are rebuilt to the character brief (`docs/CLAUDE-CHARACTER-BRIEF-2026-11-15.md`, cast row 10): a Black
woman, 32 when she died in 1984 (she does not age, so all four are the same woman), warm brown skin (tone 2), short natural
hair, 1.68 m, calm and quiet authority. One body and face in every file (`RENNICK_BODY` in `people_roster.py`); the gear
(peaked caps, duty belts with radio and torch, speaker-mic, sleeve flashes) is modelled in `tools/blender/people_rennick.py`
and is original. The constabulary is fictional: its mark is a lit lantern in a ring, drawn in code, with no lettering, no crown
and nothing taken from a real force. No weapon, no cuffs, no baton.

| Asset | Author | Licence | Used for |
|---|---|---|---|
| skin `young_african_female` (tinted to tone 2), hair `afro01` (pulled close to the scalp for a short crop), `eyebrow005`, `eyelashes02`, brown eyes (iris recoloured darker) | MakeHuman team | CC0 | all four |
| `toigo_female_double-breasted_suit` (jacket camel, trousers charcoal, shirt and tie areas a charcoal knit), `toigo_ankle_boots_female` | MRT | CC0 | plain clothes |
| `elvs_hooded_sweat_jacket1` (navy soft-shell patrol jacket) | Elvaerwyn | CC BY | today's uniform |
| `cortu_cargo_pants` (navy uniform trousers) | cortu | CC0 | today's uniform |
| `mindfront_shoes_biker_boots_female` (black duty boots) | Mindfront (Sweden) | CC BY 4.0 | today's uniform |
| `toigo_female_suit_2` (navy tunic and trousers, pale blue shirt; its floral tie and pocket square painted out to a plain dark tie), `toigo_ankle_boots_male` (flat polished boots) | MRT | CC0 | 1984 and the ghost |

Fabrics (Poly Haven, CC0, see `godot/assets/textures/README.md`): `caban` (camel jacket, 1984 tunic, cap crowns),
`poly_wool_herringbone` (trousers), `stretch_poplin` (soft-shell, cap bands), `brown_leather` (boots, 1984 belt), `terlenka`
(modern nylon belt). Tried and dropped: `elvs_emt_uniform_jacket_female` / `_pants_female` (CC BY 4.0): its logo panel can
be painted out, but the jacket breaks up badly at the game's triangle budget.

The ghost: `rennick_1984_ghost.glb` is the 1984 build with every texture drained to a pale, faintly cool grey-white that keeps
its own tones (her face, lips, brows, the uniform's seams), plus a low emission. In the game `PeopleAssets` puts it on
`game/shaders/people_ghost.gdshader` (opaque with a dithered fade, a soft cool rim, no glowing eyes);
`PeopleAssets.set_ghost_fade(node, fade, translucency)` fades her in and out. Note for the brief: section 4.3 asked for
her ghost to keep her skin tone; Robert chose the drained, pale ghost instead (2026-10-24). Her living files and any
portrait stay full-tone.

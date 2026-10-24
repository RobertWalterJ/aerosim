# Phone app art (lane appui2)

Art for `docs/CLAUDE-PHONE-APP-UI-PASS.md` and `docs/CLAUDE-APP-ASSETS.md` (the tablet kit in `assets/ui/tablet/` covers `docs/CLAUDE-TABLET-UI.md`).
Every file sits at the exact path the code loads (`UniverseUI.app_icon()` -> `icon_<key>.png`, `UniverseUI.avatar()` ->
`avatar_<key>.png`, `UniverseUI.case_art()` -> `<key>.png`) or the brief names. `test/appui_paths_test.gd` checks them all.
The full file list with sizes, 9-patch margins and notes is `APPUI-MANIFEST.md`. Contact sheets: `docs/realism/appui2/`
(one per group, with file names) and `docs/realism/models/appui2_final_views.jpg` / `appui2_final_textures.jpg`.

## How it is made

- 2D art: `godot/tools/ui_art/build_appui.py` (Python + Pillow + numpy), built on the tablet kit's drawing library. Edit the
  generators, not the PNGs. No text is baked into any asset; stamps use bars and pictograms where words would be.
- Portraits: `godot/tools/blender/appui_portraits.py` builds each person with the people lane's MakeHuman/MPFB pipeline
  (`people_lib.build_character`, specs in `appui_roster.py`), poses them, adds small modelled props and renders a
  head-and-shoulders still in Cycles (85 mm, frame height 0.44 m, eye line 42 percent from the top, same three lights for
  everyone; the Unknown account is lit only from behind). `gen_portraits.py` grades them (warm lift, gentle S-curve, palette
  backdrop per person, vignette, grain). Rennick and Wren use their in-game people specs, so the portrait is the same person.
- Product tiles: `godot/tools/blender/appui_products.py`. Raptor, Night Owl, the night vision pod and the thermal pod are the
  game's own glTF models (lens emission added for the heat and phosphor glow); battery, motor set, props, controller and
  repair kit are modelled in the script. `gen_products.py` adds the category plate (drone moss, camera amber, motor rust,
  battery lake).

## Sizes

Root files are 2x the nominal display size in the briefs (status and nav glyphs 36 px for 18 px slots, tab glyphs 64 for 32,
app icons 256, portraits and tiles 512 as the brief asks). `sizes/<px>/` holds native renders for small slots (18, 24, 32,
48, 64, 96, 128) and `sizes/brass/` brass variants of the system glyphs. Godot draws a large texture into a small
TextureRect without mipmaps, so for 36 to 48 px avatar slots either use `sizes/48|96/avatar_<key>.png` or set the TextureRect
`texture_filter` to `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` with mipmaps enabled on import (a code-side choice, left to the app lane).

## The cast (no real likenesses; all faces are MakeHuman composites)

| Key | Person | Look |
|---|---|---|
| maya | Maya, editor | long dark hair, rust jumper, headphones round the neck, moss backdrop |
| jo | Jo, events | auburn bob, slate shirt, festival lanyard with a blank pass, rust backdrop |
| riley | Riley, ranger | close-cropped hair, moss fleece, shoulder radio, no insignia, lake backdrop |
| tom | Tom, storm chaser | bucket hat, mustard jacket, camera strap, slate backdrop |
| alex | Alex, Facade seller | flip-up magnifier band, work shirt, brass backdrop |
| sam | Sam, crew and fixer | braids, brown canvas jacket, tools in the chest pocket, sage backdrop |
| rennick | Constable Rennick | the in-game model (plain clothes, ponytail), deep slate backdrop |
| unknown | Unknown account | beanie, gaiter over the face, backlit silhouette, charcoal backdrop with a warm glow |
| you | The pilot | FPV goggles down over the eyes, grey fleece, neutral build, pine backdrop |
| wren | Wren, lost hiker | the in-game model (red rain jacket, pack straps), teal backdrop |
| kit | Kit, DroneBudz support | headset with boom mic, olive jacket, sand backdrop |

## Licences

- 2D art, product models and portrait props: original to this project.
- Fonts: SIL OFL 1.1, see `assets/fonts/LICENSES.md`.
- Portrait people are built from MakeHuman assets (the same sources as `assets/models/people/README.md`). CC0: the MakeHuman
  system assets (base mesh, targets, skins, eyes, brows, lashes, hair long01, short01, short02, short04, ponytail01), MargaretToigo
  (toigo_basic_tucked_t-shirt, toigo_curled_under_bob, toigo_ankle_boots_male), Cortu (cortu_short_messy_hair, cortu_cargo_pants).
  **CC BY (credit required):** Elvaerwyn (elvs_hooded_sweat_jacket1, elvs_male_shirt_untucked_bd1, elvs_braided_rows,
  elvs_slouchy_beanie1), Mindfront (mindfront_knitted_sweater_02, mindfront_fishing_hat_01, mindfront_female_trousers_1),
  punkduck (punkduck_wireless_headset, punkduck_winter_boots). Fabrics: Poly Haven, CC0. The game's credits line already
  covers these authors: "People made with MakeHuman and MPFB; clothing by Elvaerwyn, Mindfront and punkduck (CC BY), MRT, cortu
  and the MakeHuman team (CC0); fabrics from Poly Haven (CC0)."

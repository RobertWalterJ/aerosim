# Phone app art (lane appui2)

Art for `docs/CLAUDE-PHONE-APP-UI-PASS.md` and `docs/CLAUDE-APP-ASSETS.md` (the tablet kit in `assets/ui/tablet/` covers `docs/CLAUDE-TABLET-UI.md`).
Every file sits at the exact path the code loads (`UniverseUI.app_icon()` -> `icon_<key>.png`, `UniverseUI.avatar()` ->
`avatar_<key>.png`, `UniverseUI.case_art()` -> `<key>.png`) or the brief names. `test/appui_paths_test.gd` checks them all.
The full file list with sizes, 9-patch margins and notes is `APPUI-MANIFEST.md`. Contact sheets: `docs/realism/appui2/`
(one per group, with file names) and `docs/realism/models/appui2_final_views.jpg` / `appui2_final_textures.jpg`.

## How it is made

- 2D art: `godot/tools/ui_art/build_appui.py` (Python + Pillow + numpy), built on the tablet kit's drawing library. Edit the
  generators, not the PNGs. No text is baked into any asset; stamps use bars and pictograms where words would be.
- Avatars (lane avatars, replaces the appui2 portrait renders). Two sets, both made by `godot/tools/ui_art/build_avatars.py`
  at 2048 px and downsampled with Lanczos:
  - **eclectic (active):** each account looks like a picture the person uploaded themselves, chosen from their job and story
    role: real CC0 photographs, cartoons, a logo, a badge, a stock-style vector, a product shot and a glitched default. No
    shared tile or palette. Code in `avatars_eclectic.py`; photo crops come from `avatar_photo_prep.py` into
    `tools/ui_art/avatar_sources/` (with `SOURCES.md`). Cutouts are the circle crop of the image.
  - **emblem (alternate, round 1):** the illustrated emblems on one rounded tile, kept at Robert's request. Code is the
    emblem functions in `build_avatars.py`; cutouts are the emblem alone on transparent.
  - Files: the active set is what the game loads (`avatar_<key>.png` 512, `sizes/96|48/avatar_<key>.png`,
    `avatars/cutout/<key>.png`). Both sets are always also kept in `avatars_alt/` as `<key>_<set>.png`, `cutout/<key>_<set>.png`
    and `sizes/96|48/<key>_<set>.png`.
  - Switching: set `ACTIVE_SET` in `build_avatars.py`, or run `python build_avatars.py --set emblem --sheet` (render), or
    `python build_avatars.py --switch emblem` (no rendering: copies `avatars_alt/*_emblem` over the active files and
    rewrites the manifest rows); `--switch eclectic` switches back. `--sheet` rebuilds the contact sheet.
  - The old `appui_portraits.py` / `gen_portraits.py` path is retired and not called.
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

## The cast, active set "eclectic" (no photos of people, no real crests, mottos, brands or likenesses, no text)

| Key | Person | Picture | Kind | Source, author | Licence |
|---|---|---|---|---|---|
| maya | Maya, editor | a cartoon of her ginger cat on yellow | cartoon | drawn in code | original |
| jo | Jo, events and bookings | festival bunting and string lights at dusk | stock-style vector | drawn in code | original |
| riley | Riley, park ranger | a cartoon of her black-and-white sheepdog | cartoon | drawn in code | original |
| tom | Tom, storm chaser | lightning strike under a dark storm cloud over a field | photo composite | cloud: Poly Haven `kloofendal_48d_partly_cloudy_puresky` (https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky), Greg Zaal; field: Poly Haven HDRI bundled with Blender 4.2.3 as `datafiles/studiolights/world/sunrise.exr`, Greg Zaal; storm grade and lightning painted in code | CC0 |
| sam | Sam, meteorologist | fair-weather cumulus in a blue sky | photo | Poly Haven `kloofendal_48d_partly_cloudy_puresky`, Greg Zaal | CC0 |
| alex | Alex, tech reviewer | his Raptor race quad on the workbench | product shot | Raptor render from lane appui2 (`items/cutout/raptor.png`, own work) on Poly Haven `wood_planks_grey` (https://polyhaven.com/a/wood_planks_grey), Rob Tuytel | own work + CC0 |
| rennick | Constable Rennick | Halloway Provincial Constabulary emblem: crown, blue shield with a lit lamp, gold laurel, blank ribbon | logo / badge | drawn in code; fictional service, not modelled on any real crest | original |
| unknown | Unknown account | glitched grey default silhouette | pixel / glitch | drawn in code | original |
| you | The pilot | sunrise through mist over a field | photo | Poly Haven HDRI bundled with Blender 4.2.3 as `sunrise.exr` (Blender's `studiolights/world/license.txt`: CC0, Greg Zaal, Poly Haven) | CC0 |
| wren | Wren, lost hiker | a gravel trail through green woods | photo | Poly Haven HDRI bundled with Blender 4.2.3 as `forest.exr`, Greg Zaal | CC0 |
| kit | Kit, DroneBudz support | the app's prop-bot mascot in a headset, on teal | logo / mascot | drawn in code | original |

Tom's picture is a composite of real CC0 photographs, not a single photograph of a tornado: the lane did not download
new images (a download needs Robert's own go-ahead). To use a real storm photo, put a square JPEG at
`tools/ui_art/avatar_sources/tom_photo.jpg`, record its URL, author and licence here and in `assets/textures/README.md`,
and `avatars_eclectic.tom()` uses it instead.

## The alternate set "emblem" (round 1, in `avatars_alt/`)

| Key | Person | Emblem | Style | Tile |
|---|---|---|---|---|
| maya | Maya, editor and channel owner | clapperboard, slate open | cut paper | raspberry `#8E3E5C` |
| jo | Jo, events and bookings | festival ticket with a punched star | die-cut sticker | violet `#6A5592` |
| riley | Riley, park ranger | a sheep from her flock | flat vector | moss `#5E8A5F` |
| tom | Tom, storm chaser | thundercloud with a mustard bolt | flat vector | storm blue `#587795` |
| sam | Sam, meteorologist | striped windsock and gusts | line drawing | lake teal `#3B8584` |
| alex | Alex, tech reviewer | gear and spanner on a stitched patch | embroidered badge | rust `#B36447` |
| rennick | Constable Rennick | peaked cap with a lit lamp, plain chequer band, no crest | badge | navy `#25314A` |
| unknown | Unknown account | coarse question mark, warm backlight | pixel | charcoal `#1A1E20` |
| you | The pilot | smiling top-down quadcopter | sticker | brass `#E0AB59` |
| wren | Wren, lost hiker | a wren in a red scarf on a dotted trail | hand-drawn doodle | map paper `#E9DDBE` |
| kit | Kit, DroneBudz support | lifebuoy | flat vector | pale lake `#9CC4C8` |

## Licences

- 2D art, product models and portrait props: original to this project.
- Fonts: SIL OFL 1.1, see `assets/fonts/LICENSES.md`.
- Avatars: the emblem set and the drawn eclectic avatars are original code-drawn art. The photographic eclectic avatars use
  CC0 Poly Haven images by Greg Zaal and Rob Tuytel (table above; also in `assets/textures/README.md`).
- The retired portrait renders (no longer shipped as avatars) were built from MakeHuman assets (the same sources as `assets/models/people/README.md`). CC0: the MakeHuman
  system assets (base mesh, targets, skins, eyes, brows, lashes, hair long01, short01, short02, short04, ponytail01), MargaretToigo
  (toigo_basic_tucked_t-shirt, toigo_curled_under_bob, toigo_ankle_boots_male), Cortu (cortu_short_messy_hair, cortu_cargo_pants).
  **CC BY (credit required):** Elvaerwyn (elvs_hooded_sweat_jacket1, elvs_male_shirt_untucked_bd1, elvs_braided_rows,
  elvs_slouchy_beanie1), Mindfront (mindfront_knitted_sweater_02, mindfront_fishing_hat_01, mindfront_female_trousers_1),
  punkduck (punkduck_wireless_headset, punkduck_winter_boots). Fabrics: Poly Haven, CC0. The game's credits line already
  covers these authors: "People made with MakeHuman and MPFB; clothing by Elvaerwyn, Mindfront and punkduck (CC BY), MRT, cortu
  and the MakeHuman team (CC0); fabrics from Poly Haven (CC0)."

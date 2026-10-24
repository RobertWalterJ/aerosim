# Phone app art (lane appui2)

Art for `docs/CLAUDE-PHONE-APP-UI-PASS.md` and `docs/CLAUDE-APP-ASSETS.md` (the tablet kit in `assets/ui/tablet/` covers `docs/CLAUDE-TABLET-UI.md`).
Every file sits at the exact path the code loads (`UniverseUI.app_icon()` -> `icon_<key>.png`, `UniverseUI.avatar()` ->
`avatar_<key>.png`, `UniverseUI.case_art()` -> `<key>.png`) or the brief names. `test/appui_paths_test.gd` checks them all.
The full file list with sizes, 9-patch margins and notes is `APPUI-MANIFEST.md`. Contact sheets: `docs/realism/appui2/`
(one per group, with file names) and `docs/realism/models/appui2_final_views.jpg` / `appui2_final_textures.jpg`.

## How it is made

- 2D art: `godot/tools/ui_art/build_appui.py` (Python + Pillow + numpy), built on the tablet kit's drawing library. Edit the
  generators, not the PNGs. No text is baked into any asset; stamps use bars and pictograms where words would be.
- Avatars (lane avatars, replaces the appui2 portrait renders): `godot/tools/ui_art/build_avatars.py` draws each account
  as an illustrated emblem, not a person: a prop, an animal, a mascot or a mark that says something about them. Hand-built
  vector shapes in Pillow at 2048 px (4x supersampling), Lanczos down to 512. One rounded-square tile (corner radius 22
  percent, transparent outside the corners so it also sits inside the code's round holder), one cream hairline ring, one
  thin dark edge and the UI-STYLE palette hold the set together; the style family varies per person. `avatars/cutout/`
  holds the emblem alone on transparent. `sizes/96|48` are native downscales from the 2048 master; they stay readable at
  36 px (see `docs/realism/models/avatars_final_views.jpg`). `python build_avatars.py --sheet` rebuilds files, manifest
  rows and the sheet in about 40 s. The old `appui_portraits.py` / `gen_portraits.py` path is retired and not called.
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

## The cast (emblems, not portraits; no faces, text, crests, brands or likenesses)

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
- Avatars: original code-drawn art, no third-party assets.
- The retired portrait renders (no longer shipped as avatars) were built from MakeHuman assets (the same sources as `assets/models/people/README.md`). CC0: the MakeHuman
  system assets (base mesh, targets, skins, eyes, brows, lashes, hair long01, short01, short02, short04, ponytail01), MargaretToigo
  (toigo_basic_tucked_t-shirt, toigo_curled_under_bob, toigo_ankle_boots_male), Cortu (cortu_short_messy_hair, cortu_cargo_pants).
  **CC BY (credit required):** Elvaerwyn (elvs_hooded_sweat_jacket1, elvs_male_shirt_untucked_bd1, elvs_braided_rows,
  elvs_slouchy_beanie1), Mindfront (mindfront_knitted_sweater_02, mindfront_fishing_hat_01, mindfront_female_trousers_1),
  punkduck (punkduck_wireless_headset, punkduck_winter_boots). Fabrics: Poly Haven, CC0. The game's credits line already
  covers these authors: "People made with MakeHuman and MPFB; clothing by Elvaerwyn, Mindfront and punkduck (CC BY), MRT, cortu
  and the MakeHuman team (CC0); fabrics from Poly Haven (CC0)."

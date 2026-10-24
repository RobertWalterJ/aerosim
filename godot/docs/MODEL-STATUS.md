# Model status: what is actually in the project

Status: 2026-11-15, after the Claude review. **None of the 13 `CLAUDE-*` asset briefs has been delivered.** This is a verified inventory, not a to-do guess.

The full matrix is in `docs/REVIEW-CLAUDE-2026-11-15.md`. This page is the short version.

## The count

- **13 briefs** ask for roughly **450 to 480 named files**.
- **0 of those files were present before this modelling pass.** Now present: the Lake Car (`assets/story/lake_car.glb`, built by `tools/blender/build_lake_car.py`) and all five Priority 0 traffic fleet GLBs in `assets/traffic/`.
- The only Claude-model loader hook in the game is `game/traffic.gd:52-53` for the traffic fleet.
- App icons, avatars and Casebook stamps have code fallbacks and hooks in `game/ui_theme.gd:71-126`; the village has a texture hook only at `game/village.gd:353`.
- `assets/` contains 23 `.glb` files: 20 tree LODs, `env/all.glb` (cemetery and ground cover), `world/park.glb` (one merged park) and `world/props.glb` (cemetery props plus seven web-derived vehicle variants with none of the brief's wheel or lamp nodes).
- There is no `assets/traffic/`, `assets/vehicles/`, `assets/story/`, `assets/village/`, `assets/signs/` or `assets/fonts/`.

## What that means on screen

| Place | What is there now | What the brief asks for |
|---|---|---|
| The Lake Car | **Blender GLB now present** (`assets/story/lake_car.glb`) with a code fallback in `game/case_objects.gd` | still needs the final textured hero version, LODs and a proper contact sheet |
| Traffic | boxes with wheels and emissive lamp blocks | 9 priority vehicles / 16 total, with wheels, lamps and interiors |
| Village | nine flat-roofed box buildings, code street furniture | 12 priority / 50 total, including pub, stores, garage, phone box, bus stop and hedges |
| Wildlife | 8 primitive animal shapes | 18 priority / 29 total, including the wolf and the flock |
| Anti-drone ridge | 10 primitives | 14 priority / 31 total, including the jammer mast, shack, hunters and shotgun |
| Boat launch | 23 primitives | 16 priority / 30 total |
| Cabin track | 11 primitives | 13 priority / 25 total |
| Intersections | 8 primitives | 12 priority / 24 total |
| Location and road signs | Label3D on code posts and plates | 24 priority / 56 total, with real sign faces and posts |
| Road surface | 6 photographic base textures | seamless asphalt/gravel set plus 12 marking pieces |
| App and tablet kit | code-drawn icons, avatars, stamps and product tiles; Godot system font | ~45 priority / ~108 total files, plus the OFL font family |

## The three worst gaps

1. **Vehicles, starting with the Lake Car.** The title object is a primitive. This is the first thing a player sees in the case and the easiest place to lose belief.
2. **The village.** The new hub east of the cemetery reads as sheds from the air. It is the largest single gap by file count and the place the story now spends time.
3. **The app and tablet 2D kit plus type.** Most of the game is read through the tablet. Every icon, portrait, stamp and product tile is drawn in code and the UI uses the system font.

## What has to happen before art can land

The hooks are not enough for most briefs. Each one needs a small engineering pass:

- **Vehicles:** the fleet loader exists; the story vehicles need the same optional-file pattern in `case_objects.gd`, `traffic.gd` and the festival bus.
- **Village:** `village.gd` builds every building in code; the brief needs per-building scenes or GLBs and a loader.
- **Wildlife and anti-drone:** replace primitive builders with optional GLB instances while keeping the thermal heat shells at the same offsets.
- **Signs:** replace Label3D faces with textured quads and keep the existing collision and map names.
- **Road surface:** the shader already accepts textures; the seamless set and marking kit need import settings and material wiring.
- **UI kit:** the icon, avatar and stamp hooks exist; fonts need an OFL family imported and applied through the theme.

## Honest limits

- No art was delivered outside this repository and I cannot see any external delivery.
- The seven web-derived vehicle variants in `world/props.glb` have not been judged in-engine; node names alone do not prove they can pass as traffic.
- Model quality, scale, pivot, LOD and material correctness still need an in-engine review once files arrive.

The production order suggested by the review is: vehicles, village, app/tablet kit and font, wildlife, anti-drone, boat, cabin, signs, road surface.

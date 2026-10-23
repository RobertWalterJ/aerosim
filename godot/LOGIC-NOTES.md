# AeroSim (Godot) logic notes

The memory for any agent starting cold. One section per system: inputs, decisions, outputs, where the code lives, which test covers it.
Update this in the same commit as any logic change. Realism pass stages are listed in `SPEC-REALISM-PASS.md` section 4.

## Realism pass status
| Stage | State |
|---|---|
| 1.5 Motion blur | not started |
| 1.1 Bloom and glare, 1.2 Colour looks | not started |
| 1.3 Compression, 1.4 Lens character | not started |
| 2.1 Contact shadows, 2.2 Cheap GI | not started |
| 2.3 Volumetric light, 2.4 Sky clouds | not started |
| 2.5 Water | not started |
| 3.1 Trees | done on lane/trees (2026-10-23), see "Trees" below |
| 3.2 Far hills forest, 3.3 Grass and ground | not started |
| 3.4 Gravestones, 3.5 Drone detail | not started |

## Questions for Claude and the owner
(none yet)

## Systems (short)
- **Sensor camera** (`game/sensor_pipeline.gd`, shaders in `game/shaders/`): HDR scene viewport, metering (CPU exposure `_log_e`), bloom, sensor, ISP, codec, blit. `simple` mode (phone default) skips all passes. Test: `-- apstest`, screenshots with `simple` and without.
- **Sun and moon** (`game/solar.gd`, `main.gd` `_update_celestial`): real clock or set time. Sky in `shaders/sky.gdshader`.
- **Drone shadow and cloud shadow** (`game/drone_shadow.gd`, `shaders/cloud_shadow.gdshaderinc`, globals `g_cloud`, `g_ds*`): applied in ground, grass, foliage shaders per vertex or pixel.
- **Depth of field and autofocus** (`sensor_pipeline.gd`, `focus_box.gd`): `CameraAttributesPractical`, thin-lens maths, tap to focus.
- **World** (`terrain.gd`, `world.gd`, `hedgerow.gd`, `lake.gd`, `far_hills.gd`, `ambient_particles.gd`, `assets.gd`).
- **Menu** (`hud.gd`, `menu_style.gd`, `drone_schematic.gd`, `keyboard_guide.gd`).
- **Icons** (`hud_icons.gd`, `round_button.gd`, `shutter_button.gd`).
- **Phone**: `export_presets.cfg`, release steps in `SPEC-REALISM-PASS.md` section 7.

## Trees (realism 3.1, lane/trees, 2026-10-23)
- **Models** (`tools/tree_gen.ts`, run through `tools/export_assets.ts --trees-only`; it writes `assets/trees/*.glb`, the leaf atlases `assets/trees/leaves_*.webp`, `assets/textures/bark_birch_diff.jpg` and the tree entries of `assets/manifest.json`, leaving `env/all.glb` alone). Nine species, own procedural work: `spruce_a`, `spruce_b` (Norway spruce: whorls of sprig strips plus hanging curtains), `maple_red`, `maple_gold`, `oak`, and new `beech` (wide dome), `birch` (narrow, white bark, drooping sprays), `poplar` (tall column), `pine` (Scots pine: bare stem, orange upper bark, flat crown of needle tufts). Broadleaf crowns are an ellipsoid of 10 to 15 clumps; each clump gets a main limb from the trunk, sub-branches, and clusters of three folded (V-shaped) leaf cards at random turns. Baked into COLOR: occlusion from depth in the crown and in each clump (lit tops, dark cores) and, in alpha, how near the outside a card is. UV2 keeps (phase, flex) for the wind. Normals on leaves are crown-shaped, so a crown lights as one volume.
- **Detail levels**: LOD0 4,400 to 5,950 triangles (budget 6,000), LOD1 450 to 720 (same clumps, fewer and bigger cards from the atlas's dense cell, so volume and colour hold), far silhouettes 42 (conifer) and 96 (broadleaf: three lumps at different heights). Distance bands unchanged (`World.TREE_NEAR_END` 110 m, `TREE_MID_END` 430 m, cell-wide switches, no crossfade).
- **Materials** (`game/assets.gd`, search `## ---- trees`): models carry no textures; materials are named `bark:<set>` and `leaf:<atlas>` and `Assets._tree_mat` builds one shared ShaderMaterial per name. Tables `BARK` (file, metres per repeat, tint, desaturate, moss) and `LEAF` (translucency, roughness, tint, snow hold) hold the look. Older models without named materials still fall back to `foliage.gdshader`.
- **Shaders**: `tree_common.gdshaderinc` (the same hierarchical sway and rotor wash as `foliage.gdshader`, plus the per-tree variety), `tree_leaf.gdshaderinc` body with `tree_leaf.gdshader` (desktop: alpha to coverage, needs the scene's MSAA) and `tree_leaf_mobile.gdshader` (touch devices and non-Forward+ renderers: alpha scissor; chosen in `_tree_mat`). Leaves: alpha scaled up with the mip level so distant crowns do not thin out, back faces use the crown normal (`if (!FRONT_FACING) NORMAL = -NORMAL`, no black leaves), BACKLIGHT deeper in colour than the albedo and stronger at the crown rim, snow on upper outer leaves, darker and glossier when wet. `tree_bark.gdshader`: photographed bark at real size with its normal map, moss low on the north side, wet furrows, snow on limb tops. `tree_far.gdshader` (far silhouettes): per-copy lumps, height and width, colour lean, specular off; its tint is sRGB (converted in the shader, as the old material colour was).
- **Placement** (`game/world.gd`, `_species`, `_trees`): positions from `layout.json` are never moved; some trees change species by crowding (neighbours within 14 m): lone broadleaf on the lawn may become oak or beech, woodland gets birches and some beech, edges get birch, beech and the odd poplar, lone conifers are often pines; spruce clumps stay spruce. Count unchanged (4,556: spruce 1,906, maple 1,451, oak 561, beech 168, birch 298, poplar 38, pine 134). Each tree gets its own oval crown (x and z scale 0.9 to 1.1), height 0.92 to 1.08 and a lean up to 3.5 degrees (1.5 for conifers); scale is capped per species (poplar 1.15). Trunk colliders use the species height and trunk radius (`TREE_INFO`). Near trees seen beyond 430 m use the far models with their species colour.
- **Textures**: bark sets and sources in `assets/textures/README.md`. The tree textures' `.import` files are committed (force-added) so they import VRAM-compressed with mipmaps.
- **Size**: Android files for the tree set: 8.7 MB raw, about 6.9 MB zipped (ETC2/ASTC textures 6.6 MB, meshes 2.0 MB); budget 12 MB. The old set was 12 GLBs of 12 MB with embedded textures.
- **Request (Claude, release)**: the old GLBs had embedded textures that Godot extracted to `assets/trees/<tree>_l<n>_<k>.png` (gitignored). The new GLBs have none, so those PNGs are stale in any checkout that imported the old models; delete them before an Android export, or the APK carries about 9 MB of unused textures.
- **Tests**: `-- apstest` via `tools/gate.ps1 -Tag trees`; before/after pictures and the commands in `docs/realism/trees/` (shots: canopy from 8 m `at-19.4_8_70_0_-4`, trunk `chase,cd2,at-19.4_1.2_59.8_0_5`, avenue `at-18_30_36_190_-30`, far line `at-18_150_36_0_-12`, golden hour `clock17.8,date3,at-18_12_36_90_-8`, rain `sky4`, snow `sky6`, `simple`, `--rendering-method mobile`). `test/tree_probe.gd` (`--headless -s test/tree_probe.gd`) prints each tree part's swapped shader and textures.
- **Not verified**: a real phone (only the Mobile renderer and Simple mode on this PC); rotor wash on the new trees (same code as before, not filmed).
- **Request (ground and stone lane)**: `assets/textures/*.jpg` from earlier stages import uncompressed and without mipmaps, because `*.import` is gitignored and Godot's "detect 3D" never runs headless. Committing their `.import` files with `compress/mode=2` and `mipmaps/generate=true` (as done for the bark) would cut phone memory and distant shimmer.
- **Taste questions** (choices made, can be changed in `TREE_INFO`, `_species`, `BARK`, `LEAF`): see the trees lane report; recorded here in short: species mix near the start pad (now more oak and beech on open lawn), spruce darkness (tint 0.15), how glowing golden-hour crowns should be (translucency 1.2 to 1.6), birch and poplar colours (gold rather than lemon), leaf size (about 15 cm on the cards).

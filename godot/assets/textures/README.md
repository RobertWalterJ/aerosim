# Textures

`asphalt_*.jpg` come from the shared library (RWJ-Shared-Assets, `texture/asphalt`): Poly Haven `asphalt_02`, CC0.
Albedo, OpenGL normal map, and ARM (occlusion, roughness, metal). One repeat is 5 m.

## Stone and brick (October 2026)

Five PBR sets for the cemetery's masonry, used by `game/shaders/stone.gdshader` through the stone swaps in
`game/assets.gd`. Each set is three 1024 px JPEGs: `_diff` albedo (sRGB), `_nor` OpenGL normal map, and `_arm`
(r occlusion, g roughness, b metal). They import VRAM-compressed with mipmaps (S3TC/BPTC on desktop, ETC2/ASTC on
Android). All are CC0 (public domain, no attribution required). The scale is the real-world size of one repeat, as
published by Poly Haven, and is what the shader uses.

| Files | Source | Author | Licence | One repeat | Used for |
|---|---|---|---|---|---|
| `rubble_*` | Poly Haven `stone_wall`, https://polyhaven.com/a/stone_wall (1k files from https://api.polyhaven.com/files/stone_wall) | Charlotte Baglioni (photography), Dario Barresi (processing) | CC0 | 2.4 m (published 2.0 m; shown slightly larger so stones read 25 to 40 cm) | the boundary stone wall |
| `mossrock_*` | Poly Haven `mossy_rock`, https://polyhaven.com/a/mossy_rock | Rob Tuytel | CC0 | 3.0 m | rock outcrops |
| `limestone_*` | Poly Haven `rock_boulder_dry`, https://polyhaven.com/a/rock_boulder_dry | Dimitrios Savva (photography), Rico Cilliers (processing) | CC0 | 1.2 m (published 1.8 m; finer grain for carved stone) | weathering on memorials and headstones |
| `ashlar_*` | Poly Haven `large_sandstone_blocks`, https://polyhaven.com/a/large_sandstone_blocks | Rob Tuytel | CC0 | 3.0 m | war-memorial steps, gate piers |
| `brick_*` | Poly Haven `red_brick_03`, https://polyhaven.com/a/red_brick_03, by way of the shared library (`texture/brick`, 2k) downscaled to 1k | Rob Tuytel | CC0 | 1.0 m | chapel plinth |

Downloaded 2026-10-22 as the 1k JPEGs (`diff`, `nor_gl`, `arm`) and re-saved at 1024 px with Python PIL (quality 85,
normals 90). The 1k sets were also added to the shared library (`texture/rubble`, `texture/mossrock`,
`texture/limestone`, `texture/ashlar`).

## Path edges and leaf litter (October 2026, ground pass)

Three more sets for the park ground, read by `game/shaders/ground.gdshader` through `game/ground_detail.gd`. Same format
as above: 1024 px JPEGs, `_diff` albedo, `_nor` OpenGL normal, `_arm` occlusion, roughness, metal. All CC0.

| Files | Source | Author | Licence | One repeat | Used for |
|---|---|---|---|---|---|
| `cobble_*` | Poly Haven `cobblestone_floor_08`, https://polyhaven.com/a/cobblestone_floor_08 (1k files from https://api.polyhaven.com/files/cobblestone_floor_08) | Rob Tuytel | CC0 | 2.0 m (as published) | the 30 cm cobble kerb along every path |
| `gravel_*` | Poly Haven `gravel_floor`, https://polyhaven.com/a/gravel_floor, by way of the shared library (`texture/gravel`, 2k) downscaled to 1k | Matterfield (photography), Jenelle van Heerden (processing) | CC0 | 2.0 m | the ragged gravel verge between kerb and lawn |
| `soil_leaves_*` | Poly Haven `brown_mud_leaves_01`, https://polyhaven.com/a/brown_mud_leaves_01, by way of the shared library (`texture/soil_leaves`, 2k) downscaled to 1k | Rob Tuytel | CC0 | 2.5 m (published 1.3 m; the library and this game show it larger so the leaves read at drone height) | leaf litter on the ground under the tree crowns |

Downloaded or copied 2026-10-23 and re-saved at 1024 px with Python PIL (quality 85, normals 90). The cobble set was also
added to the shared library as `texture/cobble` (1k).
## Bark (October 2026, trees)

Used by `game/shaders/tree_bark.gdshader` through `Assets._tree_mat` in `game/assets.gd`; the tree models (made by
`tools/tree_gen.ts`) carry UVs in metres, and the shader divides by the size of one repeat given here. Each set is a
`_diff` albedo (sRGB) and a `_nor` OpenGL normal map; roughness comes from the albedo's brightness, so there is no ARM
map. These files, and the leaf atlases in `assets/trees/`, import VRAM-compressed with mipmaps: their `.import` files
are committed (the folder's `.gitignore` skips `*.import`, so they were added with `git add -f`). Without that,
Godot imports them uncompressed and without mipmaps, which is large on a phone and shimmers in the distance.

| Files | Source | Author | Licence | One repeat (around x along) | Size | Used for |
|---|---|---|---|---|---|---|
| `bark_furrow_*` | Poly Haven `bark_brown_02`, https://polyhaven.com/a/bark_brown_02 (1k files from https://api.polyhaven.com/files/bark_brown_02) | Rob Tuytel | CC0 | 1.0 x 1.0 m | 512 px | maples, poplar |
| `bark_oak_*` | Poly Haven `jolcham_oak_bark_01`, https://polyhaven.com/a/jolcham_oak_bark_01 | Charlotte Baglioni | CC0 | 1.0 x 2.0 m | 512 x 1024 px | oak |
| `bark_smooth_*` | Poly Haven `japanese_hackberry_bark`, https://polyhaven.com/a/japanese_hackberry_bark | Charlotte Baglioni | CC0 | 1.89 x 1.89 m | diff 1024 px, normal 512 px | beech (shown grey: the shader takes most colour out); its normal map also serves the birch |
| `bark_pine_*` | Poly Haven `pine_bark`, https://polyhaven.com/a/pine_bark | Dimitrios Savva | CC0 | 2.0 x 2.0 m | diff 1024 px, normal 512 px | Scots pine (orange upper stem from vertex tint), spruce (tinted grey-brown) |
| `bark_birch_diff.jpg` | painted by `tools/tree_gen.ts` (`paintBirchBark`): white bark, lenticels, black diamonds | AeroSim (own work) | CC0 | 1.0 x 1.0 m | 512 px | birch |

Downloaded 2026-10-23 as the 1k JPEGs (`diff`, `nor_gl`) from the Poly Haven API and re-saved with Python PIL
(albedo quality 85, normals quality 90) at the sizes above, about 512 pixels per metre (256 for the larger normals).
The four photographed sets were also added to the shared library (`texture/bark_furrow`, `texture/bark_oak`,
`texture/bark_smooth`, `texture/bark_pine`) with the birch bark and the leaf atlases.

The leaf atlases (`assets/trees/leaves_*.webp`, 512 px, four cells each) are painted by `tools/tree_gen.ts`
(`paintLeafAtlas`, `paintConiferAtlas`): own work, CC0. A cell is about 1.25 m of leaf spray on the tree.

## Park path surface (replaces the dark asphalt_02 on the paths, 2026-10-23)
`path_diff.jpg`, `path_nor.jpg`, `path_arm.jpg` (R = ambient occlusion, G = roughness, B = 0) come from Poly Haven `asphalt_floor`
(https://polyhaven.com/a/asphalt_floor), 1k, CC0. A pale, even, chip-seal style surface with fine aggregate. One tile is about 2.35 m
(the shader divides by 2.35). The old `asphalt_*.jpg` files stay in the folder, unused.

## Barn and silo (models3, 2026-10-23)
Three sets for the farm buildings in `game/new_models2.gd`, read by `game/shaders/farm.gdshader` through
`NewModels2.farm_material`. Same format as the stone sets: 1024 px JPEGs, `_diff` albedo (sRGB), `_nor` OpenGL normal,
`_arm` (r occlusion, g roughness, b metal). Downloaded 2026-10-23 as the 1k JPEGs from the Poly Haven API
(https://api.polyhaven.com/files/<id>) and re-saved with Python PIL (albedo and ARM quality 85, normals 90). Their
`.import` files are committed (`git add -f`): VRAM-compressed with mipmaps (S3TC/BPTC on desktop, ETC2/ASTC on Android),
normal maps flagged as normal maps. 1.59 MB for all nine. The fieldstone foundation reuses `rubble_*` (above). All CC0.

| Files | Source | Author | Licence | One repeat | Used for |
|---|---|---|---|---|---|
| `barnwood_*` | Poly Haven `wood_planks_grey`, https://polyhaven.com/a/wood_planks_grey | Rob Tuytel | CC0 | 1.5 m (as published; five 30 cm boards, grain upright) | barn boards under the red paint, white trim, bare soffits |
| `roofsteel_*` | Poly Haven `corrugated_iron`, https://polyhaven.com/a/corrugated_iron | Dimitrios Savva (photography), Jenelle van Heerden (processing) | CC0 | 1.12 m (as published) | barn roof, hay hood, cupola roof, ironwork; silo dome, chute and pipe |
| `silocrete_*` | Poly Haven `concrete_wall_004`, https://polyhaven.com/a/concrete_wall_004 | Charlotte Baglioni (photography), Dario Barresi (processing) | CC0 | 1.5 m across x 1.0 m up (published 2.0 m; squeezed so the blocks read as 75 x 25 cm silo staves) | silo staves |


## Farm props (models5, 2026-10-23)

Same recipe as above (Poly Haven 1k JPEGs from https://api.polyhaven.com/files/<id>, re-saved with PIL; `_arm` is r occlusion, g roughness, b metal). All CC0. Used by `game/shaders/farm_props.gdshader` through `game/new_models3.gd`.

| Files | Source | Author | Licence | One repeat | Used for |
|---|---|---|---|---|---|
| `postwood_*` | Poly Haven `rough_wood`, https://polyhaven.com/a/rough_wood | Rob Tuytel | CC0 | 1.0 m | fence posts, rails and boards (grain along the part) |
| `straw_*` | Poly Haven `riet_01`, https://polyhaven.com/a/riet_01 | Rob Tuytel | CC0 | 0.5 m | hay chaff under the stalk streaks and the straw colour |
| `plough_*` | Poly Haven `farm_soil`, https://polyhaven.com/a/farm_soil | Amal Kumar | CC0 | 2.0 m | tilled and ploughed soil (crumb normals) |
| `mudtrack_*` | Poly Haven `aerial_mud_1`, https://polyhaven.com/a/aerial_mud_1 | Rob Tuytel | CC0 | 2.5 m (wheel lines along z) | the muddy two-rut track |

The `.import` files are committed with them.
| `wool_*` (diff, nor) | Poly Haven `curly_teddy_natural`, https://polyhaven.com/a/curly_teddy_natural | colormass (photography), Rico Cilliers (processing) | CC0 | 0.45 m | the fibre clumps and curl relief of sheep wool (game/shaders/fur.gdshader) |


## Leaf cards (`cards/*.png`, models5b)
Original drawings made by `test/gen_card_textures.gd` (curves painted with a width profile, midrib and veins; no source photographs, no licence issue). They are data textures, not colour: r is the shade, g marks stem, husk or head, b marks the accents (tassel, umbel, silk, flower) and a is the cut-out. `corn_card`, `corn_top` (seen from above), `barley_card_a/b`, `alfalfa_card_a/b`, `weeds_card`. Re-run the script after changing a drawing, then import.

## Fabrics for the people (October 2026, Blender 2, lane people)

Photographed fabrics blended into the clothing of the Blender people (`tools/blender/people_lib.py`,
`make_garment_textures`). They are not separate files in the game: each garment's MakeHuman texture keeps its folds and
seams, is recoloured, and gets the fabric's weave (albedo detail), normal map (whiteout blend) and roughness tiled over it;
the result is packed into one clothes atlas per person and embedded in `assets/models/people/<person>.glb`. Downloaded
2026-10-24 as Poly Haven 1k JPEGs (`diff`, `nor_gl`, `rough`, from https://api.polyhaven.com/files/<id>) and kept in
`_tools/people/fabric` (outside the repository). All CC0. Skin, eye, brow, lash and hair textures are MakeHuman's (CC0, see
`assets/models/people/README.md`).

| Fabric | Source | Author | Licence | One repeat | Used for |
|---|---|---|---|---|---|
| `knitted_fleece` | https://polyhaven.com/a/knitted_fleece | colormass (Photography), Rico Cilliers (Processing) | CC0 | 0.27 m | Ellis's jumper, crowd sweaters and scarves |
| `ribbed_corduroy` | https://polyhaven.com/a/ribbed_corduroy | colormass (Photography), Rico Cilliers (Processing) | CC0 | 0.27 m | Ellis's trousers |
| `poly_wool_herringbone` | https://polyhaven.com/a/poly_wool_herringbone | colormass (Photography), Rico Cilliers (Processing) | CC0 | 0.27 m | flat cap, uniform tunic, tweed jacket, peaked cap, trousers |
| `brown_leather` | https://polyhaven.com/a/brown_leather | Rob Tuytel | CC0 | 0.40 m | boots, duty belt |
| `caban` | https://polyhaven.com/a/caban | colormass (Photography), Rico Cilliers (Processing) | CC0 | 0.27 m | Rennick's jacket and 1984 tunic, coats |
| `stretch_poplin` | https://polyhaven.com/a/stretch_poplin | colormass (Photography), Rico Cilliers (Processing) | CC0 | 0.29 m | Wren's rain jacket (nylon look), shirts |
| `rough_linen` | https://polyhaven.com/a/rough_linen | colormass (Photography), Rico Cilliers (Processing) | CC0 | 0.27 m | cargo trousers |
| `scuba_suede` | https://polyhaven.com/a/scuba_suede | colormass (Photography), Rico Cilliers (Processing) | CC0 | 0.29 m | Wren's boots |
| `terlenka` | https://polyhaven.com/a/terlenka | colormass (Photography), Rico Cilliers (Processing) | CC0 | 0.27 m | Wren's backpack (nylon) |
| `denim_fabric_03` | https://polyhaven.com/a/denim_fabric_03 | colormass (Photography), Rico Cilliers (Processing) | CC0 | 0.27 m | jeans |
| `cotton_jersey` | https://polyhaven.com/a/cotton_jersey | colormass (Photography), Rico Cilliers (Processing) | CC0 | 0.26 m | T-shirt, polo shirt |
| `jersey_melange` | https://polyhaven.com/a/jersey_melange | colormass (Photography), Rico Cilliers (Processing) | CC0 | 0.29 m | the girl's sports top |
| `wool_boucle` | https://polyhaven.com/a/wool_boucle | colormass (Photography), Rico Cilliers (Processing) | CC0 | 0.31 m | crowd_f2's sweater |
| `polar_fleece` | https://polyhaven.com/a/polar_fleece | colormass (Photography), Rico Cilliers (Processing) | CC0 | 0.27 m | the pilot's fleece |

## Drones (lane/drones, Blender 4)

`drones/drone_*.jpg`, 1024 px, made by `tools/blender/drones_prep_textures.py` from the ambientCG 1K-JPG sets (re-saved with PIL;
roughness remapped into each material's range and packed as ORM: r occlusion 1, g roughness, b metal; normals OpenGL). Blender
embeds them in the drone .glb files; the game imports these copies (VRAM compressed, mipmapped) and `game/drone_assets.gd`
puts them back on the drones by material name. Sheet: `docs/realism/models/drones_final_textures.jpg`.

| Files | Source | Author | Licence | One repeat | Used for |
|---|---|---|---|---|---|
| `drone_carbon_*` | ambientCG `Fabric004`, https://ambientcg.com/a/Fabric004 (2x2 twill carbon weave), recoloured near black | ambientCG (Lennart Demes), procedural | CC0 | 14 mm | carbon plates, arms, legs |
| `drone_brushed_*` | ambientCG `Metal009`, https://ambientcg.com/a/Metal009 | ambientCG, procedural | CC0 | 20 mm | anodised parts, bell sides, rails, pod case |
| `drone_spun_*` | ambientCG `Metal051A`, https://ambientcg.com/a/Metal051A (circular brushing) | ambientCG, procedural | CC0 | one per part, centred | motor bell tops, gimbal rotors |
| `drone_plastic_*` | ambientCG `Plastic012B`, https://ambientcg.com/a/Plastic012B | ambientCG, procedural | CC0 | 50 mm | camera bodies, canopy, connectors |
| `drone_rubber_*` | ambientCG `Rubber004`, https://ambientcg.com/a/Rubber004 | ambientCG, procedural | CC0 | 10 to 12 mm | TPU mounts, dampers, feet |
| `drone_strap_*` | ambientCG `Fabric036`, https://ambientcg.com/a/Fabric036, darkened | ambientCG, procedural | CC0 | 20 mm | battery straps |
| `drone_wrap_raptor.jpg`, `drone_wrap_nightowl.jpg` | drawn by the prep script (no words, no brands) | own work | CC0 | wraps the pack | battery shrink wraps |
| `drone_pcb_diff.jpg` | drawn by the prep script | own work | CC0 | one board | flight controller, ESC, VTX boards |

Downloaded 2026-10-24. No photographed CC0 carbon weave was found (Poly Haven has none; the ambientCG sets above are all made procedurally).

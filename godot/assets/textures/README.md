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


## Blender animals and wildlife props (lane/animals, Blender 1)

The animals in `assets/models/animals/*.glb` carry their own baked maps (albedo, OpenGL normal, ORM: r occlusion, g roughness,
b metal 0), 2048 px for cattle and horses and 1024 px for the rest, made by `tools/blender/build_animal.py`. Each map is baked in
Blender Cycles from a high-resolution sculpt onto the game mesh. The coat colour and markings (Holstein patches, Hereford white
face, Jersey shading, bay points, dapple grey, Suffolk black face, sable and white collie, golden retriever, grey agouti wolf,
brown hen feathers) are painted per vertex on the sculpt by `tools/blender/species.py`, `sp_*.py` (own work, CC0). The fine
surface of fur, wool and bare skin comes from photographed CC0 sets, projected on the sculpt and baked in at the size below.
They are downloaded once to `_tools/blender-cache/polyhaven/` (outside the repo) and are not shipped as separate files.

| Detail set | Source | Author | Licence | One repeat | Used for |
|---|---|---|---|---|---|
| coat | Poly Haven `velour_velvet`, https://polyhaven.com/a/velour_velvet (1k diff, nor_gl) | colormass (photography), Rico Cilliers (processing) | CC0 | 0.10 m | short hair: the fine pile in the albedo and normal of cattle, horses, dogs, the wolf, sheep faces and legs |
| wool | Poly Haven `curly_teddy_natural`, https://polyhaven.com/a/curly_teddy_natural (1k) | colormass, Rico Cilliers | CC0 | 0.12 m | the fleece of the sheep, lamb and ram |
| skin | Poly Haven `brown_leather`, https://polyhaven.com/a/brown_leather (1k) | Rob Tuytel | CC0 | 0.10 m | bare skin: noses, udders, teats, hooves, horns, the hen's comb, beak and legs |

Generated (own work, CC0): the eye maps (iris streaks and the pupil shape per species: horizontal bar for sheep, oval for
cattle and horses, round for dogs, the wolf and the hen), the coat patterns, and the track decals of the wildlife set
(`wolf_track_*`, `sheep_print_*`: a depth map drawn in `tools/blender/build_props.py`, turned into damp-mud albedo with
alpha and a normal map). Downloaded 2026-10-24.

The wildlife props in `assets/models/wildlife/` (`tools/blender/build_props.py`) reuse sets already in this folder, embedded
in each .glb at their 1k size: `barnwood_*` (Poly Haven `wood_planks_grey`, Rob Tuytel, CC0) for boards, rails, gates and the
painted sign board; `postwood_*` (Poly Haven `rough_wood`, Rob Tuytel, CC0) for posts and the stump; `straw_*` (Poly Haven
`riet_01`, Rob Tuytel, CC0) for hay and straw; `wool_*` (Poly Haven `curly_teddy_natural`, CC0) for wool on the wire;
`roofsteel_*` (Poly Haven `corrugated_iron`, Dimitrios Savva and Jenelle van Heerden, CC0) for wire and steel straps. Brass,
zinc, steel, leather, salt, water, paint, glass and the lantern flame are plain PBR values, no texture.

## Blender vehicles (lane/vehicles, 2026-10-24)
Three small detail maps for `game/shaders/vehicle_pbr.gdshader` (the Blender vehicles, `game/vehicle_assets.gd`). Downloaded
2026-10-24 as the 1k JPEGs from the Poly Haven API (https://api.polyhaven.com/files/<id>) and re-saved at 512 px with Python
PIL (albedo quality 85, normals 90). All CC0. The cars also reuse `mudtrack_diff.jpg` (above) as the colour of road dirt on
their lower panels. Every other vehicle finish (paint flake, clear coat, glass, chrome, rubber, lamp lenses) is procedural.

| Files | Source | Author | Licence | Repeats | Used for |
|---|---|---|---|---|---|
| `rust_diff.jpg` | Poly Haven `rust_coarse_01`, https://polyhaven.com/a/rust_coarse_01 | Dimitrios Savva (photography), Rico Cilliers (processing) | CC0 | 1.6 per metre | rust where the paint has rusted through (the Lake Car, the 1984 cruiser, the older pickup, the unrestored bus) |
| `fabric_nor.jpg` | Poly Haven `fabric_pattern_07` (normal map), https://polyhaven.com/a/fabric_pattern_07 | Rob Tuytel | CC0 | 9 per metre | seat cloth weave |
| `rubber_nor.jpg` | Poly Haven `rubberized_track` (normal map), https://polyhaven.com/a/rubberized_track | Charlotte Baglioni | CC0 | 6 per metre | fine grain on tyre sidewalls and treads |
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

## Buildings (October 2026, lane/buildings)

`bld_*` sets for the Blender-made Halloway buildings, garage and cabin, read by `game/building_mats.gd` (an ORM material;
uv1_scale is 1 / one repeat, and the .glb UVs are in metres). Downloaded 2026-10-24 as Poly Haven 1k JPEGs (`diff`,
`nor_gl`, `arm`, and `disp` for the two bricks) by `tools/blender/fetch_textures.py`, and re-saved by
`tools/blender/make_building_textures.py` (1024 px, albedo and ARM quality 85, normals 90; `bld_paint` and `bld_floor` at
512 px). All CC0. Their `.import` files are committed (VRAM compressed, mipmaps, normal maps flagged).

| Files | Source | Author | One repeat | Used for |
|---|---|---|---|---|
| `bld_brick_*` | Poly Haven `red_brick`, https://polyhaven.com/a/red_brick | Rob Tuytel | 1.4 m (19 courses of 74 mm) | police house, shop A, school, chimneys |
| `bld_brick2_*` | Poly Haven `medieval_red_brick`, https://polyhaven.com/a/medieval_red_brick | Rob Tuytel | 2.0 m | shop B, bakery, garage |
| `bld_render_*` | Poly Haven `painted_plaster_wall`, https://polyhaven.com/a/painted_plaster_wall | Amal Kumar | 2.0 m (1.2 m as stone dressings, 0.8 m on clay) | pub, chip shop, sills, lintels, quoins, pots |
| `bld_slate_*` | Poly Haven `roof_slates_03`, https://polyhaven.com/a/roof_slates_03 | Rob Tuytel | 3.0 m | slate roofs |
| `bld_slate2_*` | Poly Haven `roof_slates_02`, https://polyhaven.com/a/roof_slates_02 | Rob Tuytel | 3.0 m | church roof and spire |
| `bld_corrugated_*` | Poly Haven `corrugated_iron_02`, https://polyhaven.com/a/corrugated_iron_02 | Jenelle van Heerden, Sergej Majboroda | 2.7 m | garage roof, roller door |
| `bld_corrugated_rust_*` | Poly Haven `worn_corrugated_iron`, https://polyhaven.com/a/worn_corrugated_iron | Jenelle van Heerden, Dimitrios Savva | 1.8 m | cabin roofs |
| `bld_weatherboard_*` | Poly Haven `distressed_painted_planks`, https://polyhaven.com/a/distressed_painted_planks; turned 90 degrees (its normal vectors turned with it) and desaturated so the paint colour comes from the vertex colour | Rob Tuytel | 1.6 m | village hall |
| `bld_timber_*` | Poly Haven `weathered_plank_siding`, https://polyhaven.com/a/weathered_plank_siding | Dimitrios Savva | 1.57 m | cabin walls |
| `bld_paint_*` | Poly Haven `plastered_wall_02`, https://polyhaven.com/a/plastered_wall_02 | Charlotte Baglioni | 2.23 m | painted joinery, fascias, signs |
| `bld_wood_*` | Poly Haven `old_planks_02`, https://polyhaven.com/a/old_planks_02 | Rob Tuytel | 2.0 m | cabin deck, door, shutters |
| `bld_floor_*` | Poly Haven `wood_floor_worn`, https://polyhaven.com/a/wood_floor_worn | Dimitrios Savva | 2.0 m | floors seen through windows |
| `bld_concrete_*` | Poly Haven `concrete_floor_painted`, https://polyhaven.com/a/concrete_floor_painted | Rob Tuytel | 2.0 m | garage floor, steps |
| `bld_grime.png` | own work, drawn by `make_building_textures.py` | AeroSim | one per decal | run-off streaks |

The church walls reuse `ashlar_*` (at a 2.6 m repeat). The lettering fonts (used as glyph geometry only) are Playfair
Display SC Bold, Alfa Slab One and PT Sans Narrow Bold, all under the SIL Open Font License 1.1 (`tools/blender/fonts/OFL-*.txt`).

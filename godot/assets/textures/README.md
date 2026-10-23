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

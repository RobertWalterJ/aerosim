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

# Farm fields and the cemetery

The farm fields are fixed rectangles in `game/farmland.gd`:

| Field | Centre | Size | Yaw |
|---|---|---|---|
| corn | (300, 590) | 90 x 60 | 0.15 |
| barley | (120, 640) | 80 x 52 | -0.20 |
| alfalfa | (330, 468) | 70 x 46 | 0.30 |
| hay | (55, 585) | 70 x 50 | 0.10 |

The cemetery wall is at 238 m. `Farmland.min_cemetery_gap()` returns the nearest field edge to that wall: the alfalfa field is the closest, at about **195 m**, and the other fields are farther. No field, fence, bale or crop instance enters the cemetery, its paths, its chapel or its gates. The road corridor, grass mask and tree planting all treat the fields as their own exclusion.

The farmyard bales sit around `FARM` (165.4, 522.6) and skip roads. The fields are also checked by `World` before trees and props are planted, so there are no trees standing in a crop.

The aerial check is `docs/realism/farm/00_farm_layout.jpg`: the crop rows stay south and east of the cemetery, the fields are separated by their own access and field fences, and the cemetery wall and trees are untouched.

Honest limits: the field shapes are simple rotated rectangles, not surveyed land. The crop rows are code-built crossed quads until Claude's farm models land. There is no soil compaction, drainage or crop rotation. The farmyard bales are a small scattering, not a working yard.

# Halloway village layout

The town is now real and separate from the cemetery. It is a single-street village on the east side of the park, reached by the village lane from the south gate junction.

## Position

- Bounds: x 330 to 512, z 226 to 318.
- The cemetery wall ends at x 238, z 238. The nearest village edge is **92 m** east of that corner; the nearest building is further in. The cemetery keeps its own wall, trees, chapel and memorials, and no village lot touches it.
- The festival field is at (300, 300), west of the village; the nearest building is about 47 m east of the bus and the field gate.
- The farm fields are south of the village; the closest crop edge is far away and the farm audit in `FARM-CEMETERY-LAYOUT.md` is unchanged.
- The village lane runs from the existing south lane junction (286, 260) east to (455, 276), width 5 m, speed 15 mph. It is a real road route, so the grass mask, road shoulders and minimap draw it.

## Buildings

| Building | Position | Front |
|---|---|---|
| Bramble Cottage | (358, 242) | south to the lane |
| Stone cottage | (392, 243) | south |
| Stone cottage | (426, 244) | south |
| Brick cottage | (461, 245) | south |
| South cottage | (347, 296) | north to the lane |
| The Hollow Crown pub | (382, 299) | north |
| Halloway Stores | (414, 301) | north |
| South cottage | (443, 303) | north |
| Halloway Garage | (477, 306) | north and west to the forecourt |

## Green and street furniture

- The green is at (342, 274), with an oak, two benches, lamps, and a low stone ring.
- Phone box (365, 268), bus shelter (397, 249), post box (410, 282), lamps (372, 252), (432, 260), (466, 266).
- Hedges front the north row and the south cottages. Gravel driveways lead to the stores and the garage; a gravel forecourt sits south of the garage.
- The village name sign is on the lane approach at (312, 252).

## Placement audit

- `Village.min_cemetery_gap()` returns **92 m** from the nearest village bound to the cemetery corner. The nearest building is farther.
- `Farmland.min_cemetery_gap()` is unchanged at about **195 m**.
- No village building or prop enters a farm field, the festival bus, the cemetery wall, the chapel or a grave.
- World clears trees from the village bounds before planting; the village has its own oak on the green.
- The lane is added to the road network, so grass is masked from the asphalt and traffic can use it.

## Evidence

- `docs/realism/village/00_village_aerial.jpg`
- `docs/realism/village/01_village_street.jpg`
- `docs/realism/village/02_village_cemetery.jpg`

## Honest limits

The current buildings are code-built coloured boxes with photographed wall textures, gable prisms for roofs, flat window boxes and simple signs. They are not final architecture. The pavements were removed because the temporary slabs read as floating; the road shoulders carry the street edge for now. There is no interior, no collision, no chimney smoke, no night lighting beyond the lamp material, and no bespoke road markings. The final models and textures are requested in `CLAUDE-VILLAGE-ASSETS.md`. The village is a separate place from the cemetery, but it is still a small valley village, not a town with a high street.

# Village buildings: Blender pub, shop and garage now in this lane

Status: 2026-11-15. Three of the nine village buildings now use shared Blender models.

## Files

- `assets/models/story/halloway/town_pub_a.glb`
- `assets/models/story/halloway/town_shop_a.glb`
- `assets/models/story/halloway/garage_shell_a.glb`

## Wiring

`Village._pub()`, `_shop()` and `_garage()` now try `_try_building_model()` first:

- The model is instantiated at the same position and yaw as the code building.
- The existing footprint collider is kept.
- The stats still count the pub, shop and garage.
- If a file is missing, the code building is built as before.

The six cottages, the green furniture, hedges, parked cars, phone box, bus shelter, lamps and the small village signs are still code placeholders.

## Honest limits

- Direct static load, so the buildings do not have the shared story-material remap and their named interior lights are not driven.
- Early return means the code-built pub/shop/garage labels, footpaths and some trim are skipped when the models are present; a later pass should keep those exterior pieces.
- The models are the shared `halloway` story models, not a complete nine-building village kit; the cottages and furniture still need the village brief.
- No new Blender modelling was done for this slice; it integrates existing shared assets that match the code footprints.

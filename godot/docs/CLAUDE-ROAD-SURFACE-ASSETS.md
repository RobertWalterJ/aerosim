# Claude road surface and pavement marking asset brief

Status: production request, 2026-11-15. The road mesh and marking system are now articulated, but the asphalt and marking art should be authored properly instead of relying on the current photographic sheets and placeholder white strips. This brief defines the textures, the marking kit and the assembly contract.

Owner of placement and code: session B. Claude handles the art and source textures only. The game already builds the road ribbon, shoulder, junction apron and marking meshes from these assets.

## What exists now

- `assets/textures/asphalt_diff.jpg`, `asphalt_nor.jpg`, `asphalt_arm.jpg`: 2048 x 2048 photographic asphalt sheets.
- `assets/textures/gravel_diff.jpg`, `gravel_nor.jpg`, `gravel_arm.jpg`: 1024 x 1024.
- The asphalt shader samples U across the carriageway and V along the route, roughly eight metres of road per V repeat.
- Painted lines are now separate meshes at real-world sizes: a 120 mm edge line and a 120 mm dashed centre line, 3 m paint and 9 m gap. The shader no longer bakes lines into the surface.
- Road offsets: asphalt surface about 55 mm above the sampled ground, edge skirt down 160 mm, shoulder outer lip sunk 120 mm.

## Shared contract

- Seamless tileable textures. The left edge must tile to the right edge, the top to the bottom, with no seam and no baked perspective.
- PBR channel convention for Godot: albedo/diffuse as sRGB, normal as tangent-space OpenGL (+Y up), ARM as R = ambient occlusion, G = roughness, B = metallic.
- Use 2048 x 2048 for asphalt and 1024 x 1024 for gravel, or 4096 if the aggregate needs it. Keep file sizes sensible.
- No road markings baked into the asphalt sheets. Markings must be separate.
- No perspective, no vignette, no directional lighting baked into albedo.
- Natural scale: the asphalt aggregate should read at roughly 1:1 when one tile covers 8 x 8 m. State the authored tile size in the delivery notes.
- Every texture must pass a seam check at 200 percent and a tiling test at 3 x 3 tiles.

## Priority 0: asphalt PBR set

| Asset | Description | Tiling |
|---|---|---|
| `asphalt_worn_a` | fine grey aggregate, lightly worn, small chips, no large cracks | 8 m tile |
| `asphalt_worn_b` | slightly coarser and darker, tar lines and small patches | 8 m tile |
| `asphalt_worn_c` | faded, gritty rural surface, more aggregate exposed | 8 m tile |
| `asphalt_worn_n` | one tangent-space normal map shared by the set, subtle 2 to 5 mm relief | 8 m tile |
| `asphalt_worn_arm` | one ARM map shared by the set, roughness variation and small AO in the chips | 8 m tile |

Optional variants:

- `asphalt_patched_a` with a repaired rectangle and tar seam, as a separate 4 x 4 m decal tile.
- `asphalt_cracked_a` with fine alligator cracking, as a separate alpha decal.
- `asphalt_wet_a` darker, tighter roughness, no standing water.
- `asphalt_shoulder_a` a transitional strip from asphalt to gravel, 8 x 2 m.

## Priority 0: pavement marking kit

All markings are separate meshes or alpha decals with real-world dimensions. The game assembles them along the road, so each piece must have a clean pivot and a consistent orientation.

Convention: the strip runs along local +Y or +Z, the paint is centred on the local X axis, and the origin is at the start of the paint. Front face +Z.

| Asset | Dimensions | Notes |
|---|---|---|
| `mark_edge_line_straight` | 120 mm wide, 4 m long | solid white, straight |
| `mark_edge_line_curve` | 120 mm wide, 2 m arc | left and right variants |
| `mark_centre_dash_3m` | 120 mm wide, 3 m long | white, 3 m paint / 9 m gap |
| `mark_centre_dash_2m` | 100 mm wide, 2 m long | white, 2 m paint / 4 m gap |
| `mark_centre_solid` | 120 mm wide, 8 m | continuous white |
| `mark_stop_bar` | 300, 400 and 450 mm deep, 3 to 4 m wide | white, worn |
| `mark_yield_bar` | 300 mm triangle pair | optional |
| `mark_arrow_left` | 3 m long, 1 m wide | white, flat paint |
| `mark_arrow_right` | 3 m long, 1 m wide | white, flat paint |
| `mark_arrow_straight` | 3 m long, 0.8 m wide | white, flat paint |
| `mark_parking_bay` | 2.4 m by 4.8 m outline | white or faded cream |
| `mark_hatch` | 1 m by 3 m diagonal hatch | optional |

Provide each marking as:

- a clean geometry version with a 2 mm lift above the asphalt;
- an alpha decal version for older or worn paint;
- a worn/faded variant with chipped edges and dirt;
- a white and a faded cream colour variant.

Do not bake a full lane pattern into one sheet. The point is to string pieces together on curves and at junctions.

## Priority 1: shoulder and verge

- `gravel_shoulder_a` 8 x 2 m, asphalt edge on one side and grass lip on the other.
- `gravel_shoulder_b` 8 x 2 m, loose stone and ruts.
- `shoulder_transition_a` 8 x 2 m, broken asphalt to gravel.
- `shoulder_grass_a` 4 x 1 m, grass creeping over the gravel.
- `road_edge_skirt_a` 8 x 0.3 m dark side face, if a texture is preferred to the current flat material.
- `drain_grate_a` and `manhole_a` small road hardware for the junction aprons.

## Priority 1: junction aprons

- `junction_asphalt_a` 16 x 16 m, no markings, worn centre and darker wheel paths.
- `junction_asphalt_t` 16 x 16 m, shaped for a T junction, with a clean fade at the approach edges.
- `junction_asphalt_cross` 16 x 16 m.
- `junction_edge_blend` 8 x 2 m, asphalt to grass at the apron boundary.

## Delivery notes Claude must include

1. Authored tile size in metres.
2. Channel convention for the normal and ARM maps.
3. Whether each map is seamless and how it was checked.
4. For markings: exact width, length, pivot and forward direction.
5. A contact sheet with a 3 x 3 tiling view and a 1:1 close-up for every material.
6. Any source licence or generation notes.

## Integration notes

- Road shader inputs: `uAlbedo`, `uNormal`, `uArm`, `uJunctionMask`, `wetness`.
- Surface UV: U across the carriageway, V along the route in metres / 8.
- Marking meshes: separate white material today; they will swap to `mark_*` meshes or decals.
- Junction aprons use the same asphalt shader with markings disabled; a dedicated junction tile is optional.
- The edge skirt is currently a flat dark material; the art can stay flat or supply `road_edge_skirt_a`.
- The shoulder uses the gravel shader; its UV is U across the shoulder, V along / 4.

## What this unlocks

Priority 0 gives the roads a real seamless asphalt surface and a modular, correctly sized marking kit. Priority 1 gives the shoulders and junction aprons a finished edge. The road can then be assembled from real pieces rather than procedural paint and stretched photo sheets.

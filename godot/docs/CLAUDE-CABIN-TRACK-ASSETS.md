# Claude cabin track and cave asset brief: the old way to the cabin

Status: production request, 2026-11-15. The cabin is no longer reached by a country highway. It has a narrow old dirt and gravel track through the trees, with fallen trees and rockfall across it, and a cave entrance in the outcrop beside the cabin. The current code placeholders in `game/cabin_track.gd` need final art.

Owner of placement and code: session B. Claude handles the art only. The tone is an abandoned working track in autumn woodland: quiet, overgrown, a little dangerous, no gore and no horror props.

## The scene

The asphalt ridge road passes the pull-off at (45, -760). From there the old track runs west through the trees to the cabin at (-250, -820). It is barely wide enough for one vehicle, with two worn ruts and grass and leaves creeping in from both sides. A fallen tree lies across it, then a second one, and two rockfalls cover the way nearer the cabin. West of the cabin, a low rock outcrop opens into a dark cave mouth.

## Shared contract

- glTF 2.0 `.glb`, metre scale, Y up, origin at the base, front face +Z.
- Low poly: fallen trees 800 to 2,000 triangles each, rocks 200 to 1,000, cave outcrop 2,000 to 4,000.
- PBR kit materials and vertex colours, muted late-autumn woodland palette.
- Separate named nodes for the trunk, roots, branches, boulders and cave mouth.
- No collisions required for the first pass.
- No gore, no bodies, no weapons, no readable text except the optional warning board.
- Readable from a drone at 20 to 80 m and from the cabin approach.

## Priority 0: the track and obstructions

| Asset | Description | Notes |
|---|---|---|
| `track_dirt_strip` | a worn dirt and gravel ribbon, 3.4 m wide, with two ruts and soft overgrown edges | can be a texture-ready strip |
| `track_rut_pair` | two darker wheel ruts, separate mesh or decal | 0.28 m wide |
| `tree_fall_a` | a mature broadleaf fallen across the track, roots lifted at one end, crown snapped | about 8 m long |
| `tree_fall_b` | a smaller birch or beech fallen at an angle, branches across the ruts | about 7 m |
| `rockfall_a` | five to seven boulders covering the track, one large centre stone | 3 to 4 m across the group |
| `rockfall_b` | a second smaller fall with moss and leaf litter | 2 to 3 m |
| `dead_branch_scatter` | snapped branches and twigs at the falls | optional set |

## Priority 0: the cave entrance

| Asset | Description | Notes |
|---|---|---|
| `cave_outcrop` | a low broken rock face, 7 m wide and 4 m tall, with a dark arched mouth | the mouth must be a separate dark surface |
| `cave_mouth` | a black recessed arch, 2.2 m wide and 2.8 m tall | rounded or broken-edge, not a perfect oval |
| `cave_boulder_arch` | three or four large boulders framing the mouth | moss and damp at the bases |
| `cave_apron` | bare dirt and stone ground in front of the mouth, 8 m across | no grass |
| `cave_warning_board` | a small weathered board, blank or with CAVE / KEEP OUT | two short posts |
| `cave_fallen_slab` | a flat slab of rock half-buried at the entrance | optional |

## Priority 1: woodland detail

- `track_puddle` a shallow muddy puddle in one rut.
- `track_leaf_drift` a leaf drift along the track edge.
- `track_grass_tuft` a clump of grass in the centre strip.
- `tree_stump_a` a broken stump beside the track.
- `fallen_log_old` a mossy log already collapsed at the side.
- `cave_damp_stain` a dark damp stain around the mouth.
- `cave_scree` loose stones below the outcrop.

## Priority 2: small signs of use

- `track_old_gate` a leaning timber gate at the ridge pull-off.
- `track_oil_stain` and `track_tyre_print` faded marks in the dirt.
- `cave_old_lantern` a rusted lantern on the rocks, unlit.
- `cave_chalk_mark` a faint mark just inside the mouth, not readable.
- `tree_fall_cut` a sawn branch end variant.

## Integration notes

- `game/cabin_track.gd` places the track, the two falls, the two rockfalls and the cave.
- The track starts at the ridge road pull-off at (45, -760) and ends at the cabin at (-250, -820).
- The cave outcrop is at `CaseObjects.CAVE_SPOT` (-292, -806), facing the cabin.
- The cave is a named photo subject (`cave_entrance`), so it should read in a photograph.
- The track has no markings or shoulders and must not become a second asphalt road.
- The cave mouth should be a separate dark material so the code can keep it black in all light.
- Keep the obstacles loose and irregular; the player flies over them and reads the blocked way.

## What this unlocks

Priority 0 turns the placeholder into a believable overgrown track and cave. Priority 1 gives it a damp autumn woodland floor. Priority 2 makes it feel like someone used this way once and stopped.

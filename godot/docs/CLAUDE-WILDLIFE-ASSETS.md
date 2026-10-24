# Claude wildlife asset brief: the night pasture, the wolf and the sheep

Status: production request, 2026-11-11. The new night pasture story favour is playable with code placeholders: a small flock of sheep in the hay field, a wolf at the treeline and their heat signatures through the thermal camera. This brief asks Claude for the models that replace those placeholders and for the farm evidence around them.

Owner of the story and placement: session B. The tone is humane: the wolf is young and hungry, not a monster; the flock is moved and penned; nothing is shot, and no gore is shown.

## The scene

Night in the west pasture. The hay field with a small flock of sheep behind a field fence, wool caught on the wire, tracks in the soft ground, and a thin young wolf working the edge of the trees. The pilot finds it with the thermal camera, keeps high, and reports it to Riley. The resolution is a better night pen, not a rifle.

## Shared contract

- glTF 2.0 binary `.glb`, metre scale, Y up, origin at the base, +Z forward.
- Low poly: sheep and wolf 1,200 to 2,500 triangles, props 200 to 1,500.
- Kit materials and vertex colours, muted late-autumn valley palette.
- Static posed variants. No rig required, but separate named `body`, `head`, `legs` and `wool` nodes where possible so the thermal heat mask can be applied.
- Separate named nodes for pen panels and gate.
- Colliders only on the pen, gate, trough and wolf if it can be approached closely. No colliders on wool, paper or grass.
- No gore, no blood, no dead livestock, no weapons. The sheep are alive; the wolf is alive.

## Priority 0: the animals

### Wolf
A thin young timber wolf, about 1.2 to 1.4 m nose to tail, 0.75 m at the shoulder. Grey-brown, winter coat, no tracking collar in the base model.

| Asset | Description | Variants |
|---|---|---|
| `wolf_standing_a` | standing at the treeline, head up, alert | one |
| `wolf_walking_a` | walking across the field edge, low head | one |
| `wolf_looking_a` | standing, head turned toward the camera | one |
| `wolf_trotting_a` | moving away, tail low | one |
| `wolf_collar_a` | optional variant with a thin tracking collar, for a later case | one |

### Sheep
A small flock of white and cream sheep, about 0.9 m long and 0.7 m tall. Alive, calm, some grazing.

| Asset | Description | Variants |
|---|---|---|
| `sheep_grazing_a` | head down in the grass | three wool tints |
| `sheep_standing_a` | head up, looking | three wool tints |
| `sheep_lamb_a` | smaller lamb beside an adult | two tints |
| `sheep_ram_a` | one larger ram with horns | one |
| `sheep_trough_a` | low wooden trough with water | one |
| `sheep_hay_rack_a` | small hay rack | one |
| `sheep_salt_lick_a` | salt block on a stump | one |

The flock is shown at 6 to 8 animals in the field. The code can instance the same model with colour and scale variation; a handful of poses is enough.

## Priority 0: the evidence around the flock

| Asset | Description | Variants |
|---|---|---|
| `wool_on_wire_a` | small tuft of wool caught on a field fence wire | two |
| `wolf_track_a` | a set of paw prints in soft ground, as a decal or thin mesh | two |
| `sheep_print_a` | small hoof prints in the same ground | two |
| `night_pen_a` | a simple timber pen, 6 m by 4 m, with a gate, beside the hay field | closed, open |
| `pen_gate_a` | separate gate node | one |
| `farm_warning_sign_a` | a small hand-painted PREDATOR? advisory sign, no threat language | one |

## Priority 1: atmosphere and detail

- `sheep_bell_a` a small brass bell on a collar.
- `hay_bale_small_a` and `straw_patch_a` for the pen ground.
- `sheep_feed_bucket_a` with a scoop.
- `wolf_ear_tuft_a` or a small fur tuft cluster for the field edge.
- `field_gate_a` a second field gate for the lane.
- `farm_lantern_a` a storm lantern on a fence post, for the night scene.

## Priority 2: later cases

- `sheepdog_a` a border collie for the farm, for a lost-dog case.
- `farm_truck_a` a small old pickup, for the farmer.
- `wolf_collar_tracker_a` a receiver and antenna, for a tracking case.
- `sheep_shearing_kit_a` for a farm job.

## Integration notes

- The code places the sheep at the hay field around `CaseObjects.SHEEP_SPOT` and the wolf at `CaseObjects.WOLF_SPOT`.
- The wolf stays hidden until the player buys the thermal camera and the night pasture favour starts. It is shown as a heat signature through the thermal camera.
- The sheep can be visible from the start as ordinary farm life.
- Heat signatures are added by the code as translucent orange shells; keep the animal meshes clear and simple so the shells read.
- A thermal camera pod was already requested in the endgame brief; reuse that asset if possible.
- The point of the set is a real working farm on the edge of wild country, not a horror scene.

## What this unlocks

Priority 0 puts real animals and a proper night pen into the pasture favour. Priority 1 gives the field its small physical evidence and makes the thermal pass legible. Priority 2 lets the farm and future wildlife cases reuse the same set.

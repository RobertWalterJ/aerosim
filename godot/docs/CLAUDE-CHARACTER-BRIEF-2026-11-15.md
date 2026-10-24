# The character layer: rig, colliders, skin and casting

Status: audit and production spec, 2026-11-15 (session B). Read-only review; the only file written by this pass is this one.

Snapshot: git `HEAD` 9d4e7d2 plus the uncommitted character pass, read at 11:18 local on 2026-11-24. The pass added `game/character_actor.gd` and changed `game/case_objects.gd`, `game/village.gd` and `game/main.gd` while this audit was running. Line numbers will drift; every reference here also names the function, so it survives the next edit.

Scope: every human figure in the build, the ground and collider layer they stand on, a rig and shader contract for the code placeholder and the future Claude GLBs, casting for a varied village cast, and an in-engine checklist.

## The findings, in order of pain

**1. Sitting has no seat anchor. This is the worst rig/collider problem in the build.**
`_set_pose("sit")` (`character_actor.gd:302`) writes a fixed 0.50 m hip height, folds the legs and disables the capsule. Nothing reads the bench's 0.53 m seat height, and nothing moves the root onto the seat. Daniel Whitlock is placed at the bench centre on the bare ground (`village.gd:361-363`). His hips sit 3 cm inside the seat slab, his shoes go 1.3 cm under the grass, and his torso passes 5.5 cm into the backrest. His collider is switched off. A sit pose without a seat transform is always a float or an intersection; the exact bench numbers are in section 2.3.

**2. The valley has almost no character collision.**
Eleven `StaticBody3D` boxes exist in the whole map: nine village buildings and two benches (`village.gd:100,117,142,158,237`). The terrain has no collider at all, and it never has: the drone samples heights instead (`roads.gd:129`). The actor only stands because `_settle_ground()` overwrites its Y every physics tick (`character_actor.gd:266`); no gravity is ever applied, so `move_and_slide()` has nothing to land on and `floor_snap_length = 0.35` is inert. Hedges, parked cars, lamp posts, the phone box, the bus shelter, the post box, the cabin, the cruiser, the festival bus and every cemetery prop are walk-through. Characters also do not collide with each other (both are layer 2, mask 1), so two villagers can overlap and swap bodies.

**3. The thermal signature no longer fits the body.**
The person shell (`thermal_heat.gd:51-61`) was authored for the old capsule hiker and survives unchanged beside the new slimmer actor. Against the current body the torso shell has a 30 cm radius where the coat is 20.5 cm, and the head shell 17 cm where the head is 10.8 cm. The hands sit at x ±31 cm; the model's hands are at ±24.5 cm and have no visible geometry at all. Wren's shell is also scaled twice, 0.98 on the body and 0.98 again on the shell, so it lands 4% small overall. The villagers have no heat shell at all: `_heat` is declared at `character_actor.gd:78`, tested at `:314`, and never built. `Village.set_thermal_heat()` is never called from `main._sync_thermal_heat()` (`main.gd:1041-1050`), so the village's parked cars never light up either. That contradicts `THERMAL-CAMERA.md:45` and `:64`.

**4. Skin is one flat colour.**
The material (`character_actor.gd:329-341`) has no texture, one roughness for face, hands and scalp, and real subsurface scattering that Godot only renders on Forward+. The project also runs the mobile renderer on phones and `gl_compatibility` on the web (`project.godot:24-26`), where the SSS feature is silently dropped and every character goes back to painted-plastic flat shading. Section 3.7 gives the two-path fix.

**5. The cast exists but has no roles, collides in places, and repeats its palette.**
Eight villagers are named in `village.gd:342-366` and they read as ordinary people, which is the right instinct. They have no roles yet, one of them walks through a hedge, one shares a first name with the story's constable, and six of them reuse three skin tones. Section 4 turns them into the canon cast.

What I could not verify: I did not render the new characters. The Lead was editing the same files during the audit, and running the game would have raced the import cache and the save files. Every number below comes from the source, the shipped Godot 4.7.2 class data, headless engine probes, and direct sampling of `assets/world/valley_height.bin`; the render-time checks are the checklist in section 5, not claims of done.

## 1. The figures that exist

### 1.1 The one system

There is exactly one character system: `CharacterActor`, a `CharacterBody3D` that builds a person from primitives, poses it procedurally and snaps it to `Terrain.height()`. Wren uses it (`case_objects.gd:661`), and the village cast uses it through `_person()` (`village.gd:368`). Everything else human in the game is absent, imported, or a stitched primitive.

### 1.2 Audit table

| Figure | Where | Construction | Height | Origin / pivot | Collider | Thermal | Stand / sit / walk |
|---|---|---|---|---|---|---|---|
| **Wren**, lost hiker | `case_objects.gd:661` `_build_hiker`, `CharacterActor` with `skin: 1`, hair `crop`, backpack, `height: 0.98` | About 30 primitive meshes: capsule torso, jacket panel, collar, hiker panel, neck, sphere head, ears, eye whites and pupils, nose, mouth, hair cap, backpack and straps, two-segment arms with hands, two-segment legs with shoes | 1.672 m (1.706 m base × 0.98) | Body root between the feet at ground level; the scene node sits at `SEARCH_SPOT` = (−70, −790) | Capsule r 0.25 h 1.58, scaled to r 0.245 h 1.548; bottom floats 2.9 cm; layer 2 / mask 1 | `ThermalHeat.person(_hiker, ZERO, 0.98)`, hidden until the thermal camera is on | Stands and breathes. Cannot walk (empty route), cannot sit, has no phone or torch geometry |
| **Village cast**, 8 | `village.gd:342-366` `_build_people`, built by `_person()` | Same actor, per-person skin, hair, colours, height scale | 1.59 to 1.71 m (height scale 0.93 to 1.0) | Feet at ground; routes are XZ only | Capsule per actor; only the 9 building boxes and 2 bench boxes exist to collide with | None. `_heat` is never built, and `Village.set_thermal_heat()` is not called | Seven walk a closed route, one sits (broken, section 2.3) |
| **Harlan Pike** | `anti_drone.gd` site only | No figure at all. The file builds a trailer, mast, dish, beacon, notice board and three drones | n/a | n/a | n/a | n/a | Never appears. `ANTI-DRONE-RIDGE.md:53` says so on purpose |
| **Hunter drones**, 3 | `anti_drone.gd:275-322` `_make_hunter` | Box 0.62 × 0.16 × 0.78, four cylinder arms r 0.035 h 0.95, four rotors r 0.24, emissive red eye r 0.09; they fly at least 9 m above the ground | 0.16 m body | Node at the drone centre, up in the air | None (distance chase only, `HUNTER_RANGE` 280 m) | None. They read cool in the thermal pass, which is wrong for a flying machine with a battery and motors | Fly and chase; not people, recorded so the character count stays honest |
| **The angel monument** | `graveyard.gd:98-111` | Code-built statue: lathe body, sphere head, extruded wings on a plinth; 1.9 m tall | 1.9 m | Base on the ground | None from the character layer; the cemetery colliders live in `layout.json` for the drone | None | Static. The only other human-shaped geometry in the game |
| **Constable Rennick** | `finale.gd` `_ghost()` | Text only. The "ghost" is a notification line, not a figure | n/a | n/a | n/a | n/a | Never shown. Requested as three static GLBs in `CLAUDE-ENDGAME-ASSETS.md:64-73` |
| **Ellis Voss** | story only | The camp on the ridge is empty; Ellis is discussed, never placed | n/a | n/a | n/a | n/a | Never shown |
| **Festival crowd** | `CLAUDE-NARRATIVE-ASSETS.md:139-149` | Requested models `crowd_point_a`, `crowd_cheer_a`, `crowd_seated_a`; none delivered (`MODEL-STATUS.md`) | n/a | n/a | n/a | n/a | Would be static posed |
| **The player** | first person | No body by design (`ENDGAME.md:63`) | n/a | n/a | n/a | n/a | Camera only |

The crew from chat (Maya, Alex, Riley, Tom, Sam, Jo, Kit) have no bodies and are not candidates for one in this pass. They are voices and app avatars (`CLAUDE-APP-ASSETS.md:21-32`).

### 1.3 What the old Wren looked like, and why it matters

The removed placeholder (`git diff` of `case_objects.gd`) was a 1.84 m capsule with a 0.32 m torso, 0.19 m head, 0.55 × 0.6 × 0.35 pack and two leg boxes, with no arms at all. Three numbers matter because the rest of the project still assumes them:

- The asset brief asks for 1.72 m (`CLAUDE-ENDGAME-ASSETS.md:55`). The old placeholder was 1.84 m, the new actor is 1.672 m, so the brief's height now sits between the two.
- The thermal shell's dimensions are still the old body's, and that is why it is too fat (finding 3).
- The old figure's origin was exactly at the feet. The new one is 1 cm under the feet (section 1.4).

### 1.4 The placeholder actor, measured

From `character_actor.gd` at `height_scale = 1.0`. I recomputed every value from the construction code rather than reading it off a screenshot.

| Part | Value | Comment |
|---|---|---|
| Hip joint (`_hips`) | y 0.920 | Correct for a 1.75 m adult, but this actor is only 1.706 m tall |
| Torso capsule | r 0.205, h 1.06, centre y 1.160 | Spans 0.63 to 1.69 |
| Head sphere | r 0.108, centre y 1.580 | 0.216 m tall head on a 1.706 m body, so 7.9 heads; slightly small |
| Hair top | y 1.706 | Total standing height at scale 1.0 |
| Shoulder pivots | x ±0.245 | Outer edge 0.594 m wide. That is 25 to 30% broader than an adult shoulder |
| Arm capsule inner edge | x 0.193 | The 0.205 torso radius overlaps it by 1.2 cm at rest: the arms are already inside the coat |
| Hand centre | y 0.830 | Fingertips at mid-thigh, plausible |
| Shoe sole | y −0.010 | **1 cm below the root origin**, so every actor sinks 1 cm |
| Collider capsule | r 0.25, h 1.58, centre y 0.820 | Bottom at y 0.030, top at 1.610. Godot's `height` is the full height including caps; verified in a 4.7.2 headless probe, `mid_height` = 1.08 |
| Effective capsule at Wren's 0.98 | r 0.245, h 1.548 | The whole body is scaled, collider included |

The shoulder width and the sunken soles are the two numbers a delivered GLB should not inherit.

## 2. Ground and collider gaps

### 2.1 How ground height is found

`Terrain.height(x, z)` (`terrain.gd:129-140`) is bilinear on a 2049 × 2049 grid of u16 samples decompressed from `assets/world/valley_height.bin`, 1.953 m between samples. The drawn ground is a triangulated version of the same grid: a 1.95 m near mesh within ±500 m and a 15.6 m far mesh outside it (`terrain.gd:48-50`). `Terrain.normal_at()` (`terrain.gd:142`) already returns the surface normal and no character code uses it.

I compared the bilinear sample the actor uses against the triangle interpolation the player actually sees, over the whole cell under each site. The worst disagreement is **0.55 cm**, at bench A. Sampling is not the reason anyone floats. It is accurate to under a centimetre, which is good enough to stop worrying about.

### 2.2 Where the feet actually land

Root at `Terrain.height()` of the body centre, body never pitched. I sampled the ground under the eight shoe corners (local x ±0.165 m, z −0.175 to +0.065 m) at each site, using the real heightmap.

| Site | Slope | Highest corner (float) | Lowest corner (sink) |
|---|---|---|---|
| Village lane, 421, 272 | 7.8° | +2.45 cm | −3.10 cm |
| Village bench B, 356, 282 | 4.2° | +1.65 cm | −1.33 cm |
| Cabin, −250, −820 | 6.3° | +2.07 cm | −1.94 cm |
| Wren's search spot, −70, −790 | 5.0° | +2.10 cm | −1.26 cm |
| Cottage 1 door, 358, 242 | 2.9° | +0.41 cm | −0.97 cm |

The worst case in the inhabited valley is about 3 cm of float and 3 cm of sink on the lane. At the drone's normal 20 to 60 m that is a couple of pixels and invisible. At 5 m, in the Wren shot, it is a foot hovering. Fix: pitch the actor to `normal_at()` clamped to 15°, then the residual falls under 1 cm. Add the ±1 cm sole offset separately (section 1.4).

### 2.3 Benches, and what sitting actually needs

The bench (`village.gd:228-240`) is honest geometry:

- seat slab 1.8 × 0.10 × 0.48 at y 0.48, so **the seat surface is at 0.53 m**;
- backrest 1.8 × 0.48 × 0.10 at z +0.20, spanning y 0.50 to 0.98;
- two iron legs 0.10 × 0.48 × 0.10 at x ±0.75;
- one collider: a solid 1.8 × 0.82 × 0.50 block from y 0.0 to 0.82.

The bench is placed at `Terrain.height()` of its centre and never pitched, so it does not sit on its own ground either. Measured from the real heightmap:

| Bench | Left leg | Right leg |
|---|---|---|
| A, 350, 280, yaw 0.2 | 3.37 cm into the ground | 3.72 cm in the air |
| B, 356, 282, yaw −0.3 | 5.04 cm into the ground | 5.22 cm in the air |

So five centimetres of seating error exist before a character is involved.

Now the sitter. `_animate()` in the seated branch (`character_actor.gd:272-283`) sets `_hips.position.y = 0.50`, thighs at 1.45 rad, knees at −1.42 rad, and `_settle_ground()` has already put the root on the terrain at the bench centre. Working the chain through (thigh 0.44 m, shin 0.42 m, shoe 0.08 m):

| Seated value | Measured | Bench needs |
|---|---|---|
| Hip surface | 0.500 m | 0.530 m: hips are **3.0 cm inside the seat slab** |
| Shoe sole | −0.013 m | 0.000 m: shoes are **1.3 cm under the grass** |
| Thigh horizontal reach | 0.437 m forward | Seat depth is 0.48 m, so the knees stop just inside the seat front |
| Torso extent | y 0.21 to 1.27, radius 0.205 at z 0 | Backrest starts at z +0.15, so the coat overlaps it by **5.5 cm** |
| Collider | disabled | Nothing holds the actor on the seat |

The sit clip also has no `sit_down` or `stand_up`; the pose appears and disappears instantly.

**The seat contract a character needs.** Give every bench and chair a `SeatAnchor` (a `Node3D`): origin at the seat surface centre, local −Z facing out from the back, plus `seat_height`, `seat_depth` and `back_offset`. The sit pose is authored against a nominal 0.45 m seat with the hips at 0.45, and placement applies `root.y = seat_y − 0.45`. For this bench that is +0.08 m. With the hips at 0.53, the feet reach the ground if the thigh drops about 12° and the shin angles about 29° forward; those two angles belong in the clip (section 3.4). The bench collider should also become three thin boxes (seat slab, back slab, two legs) instead of one 0.82 m block, or a character cannot stand at the bench front without hitting an invisible wall.

### 2.4 Buildings and thresholds, the largest ground error in the village

Each building is placed at the `Terrain.height()` of its centre (`village.gd:97` and the other builders), and its door is placed on the local ground plane, bottom at y 0. Because the valley slopes up to 8° across a 9 to 15 m footprint, the door bottoms and the ground do not agree. Measured across the actual door widths:

| Building | Ground at door left | Ground at door right | Effect |
|---|---|---|---|
| Cottage 1, 358, 242 | −19.2 cm | −20.2 cm | Door floats about 20 cm |
| Cottage 2, 392, 243 | −61.8 cm | −68.7 cm | **Door floats about 65 cm** |
| Pub, 382, 299 | −21.2 cm | −13.5 cm | Door floats about 17 cm |
| Stores, 414, 301 | +29.2 cm | +44.3 cm | Door is buried about 37 cm |
| Garage, 477, 306 | +64.9 cm | +64.4 cm | **Door is buried about 65 cm** |

This is a building problem, not a character problem, but it blocks two checklist items. You cannot judge character scale against a door whose base is 65 cm out. A character standing in that doorway stands on terrain half a metre below the threshold. The cheap fix is a plinth or a skirt wall that extends 0.9 m below the building base, and a threshold step at each door. Then the door height becomes a usable scale reference again.

### 2.5 Where collision exists, and where it does not

| Layer | What exists | Reachable by a character? |
|---|---|---|
| Terrain | Triangle mesh only, no body | No |
| Village | 9 building boxes + 2 bench boxes, `StaticBody3D` layer 1 | Yes, these are the only obstacles |
| Hedges, cars, lamp posts, phone box, bus shelter, post box, green ring | Meshes only | No |
| Cemetery and park | 2 building boxes and 2,521 cylinder colliders in `assets/world/layout.json`, used only by `World.obstacle_hit()` (`world.gd:281-314`) | No, the village bounds contain zero of them |
| Case objects (cabin, cruiser, bus, camp, cave, garage, boat launch) | None. `case_objects.gd:10` says so | No |
| Trees | Cylinders in `layout.json`, drone only | No |
| Characters vs characters | Layer 2 / mask 1 for both | No |

One route already walks through furniture. Grace Adeyemi's route (`village.gd:352-354`) passes through hedge 5 at (365, 288): the point (368, 288) is inside the 8 × 0.7 m hedge footprint, and both segments touching it cross it. With no hedge collider she walks straight through the leaves. Nothing in the code prevents it.

**Two collision worlds, one source of truth.** The world already has a spatial hash of trunks, monuments, hedge pieces and buildings (`World.obstacle_hit`, `world.gd:281-314`, 2,521 cylinders and 2 boxes loaded from `layout.json`). The village then added eleven physics boxes of its own. A third system for characters would be a mistake. Recommendation: let characters push out with `World.obstacle_hit()` for trees, monuments and the cemetery, keep `StaticBody3D` for the eleven village boxes, and move the village building boxes into `layout.json` so both layers use one dataset. A `CharacterActor` with no `move_and_slide` floor is already kinematic, so a push-out query costs less than a physics world.

### 2.6 What a character needs from the ground layer

1. A ground query that returns height and normal at any XZ. Both exist (`terrain.gd:129`, `:142`).
2. A snap that runs after movement and puts the soles, not the root, on the ground: `root.y = ground − sole_offset`, with `sole_offset` authored as 0 in the GLB.
3. Pitch and roll from `normal_at()`, clamped to about 15°, low-passed so a walking actor does not jitter over 2 m mesh cells.
4. A foot-plant option for close-ups: sample the ground under each foot and offset the lower one.
5. A seat anchor and seat height for any furniture that can be sat on (section 2.3).
6. An obstacle query with a radius of 0.26 m at the body centre plus a head check, or a real collider layer (section 2.5).

## 3. Production rig spec

This is the contract for the code placeholder and for every character GLB Claude delivers. The placeholder already uses the right joints; the delivered skeleton should keep their names and hierarchy so a GLB can replace the primitives without changes in `case_objects.gd` or `village.gd`.

### 3.1 Export contract

- glTF 2.0 binary, `.glb`, one file per character with all LODs and clips inside it.
- Metres, Y up, uniform scale 1.0. No transforms baked into the root beyond identity.
- **Forward axis: +Z in the file**, matching every other asset brief (`CLAUDE-ENDGAME-ASSETS.md:13`, `CLAUDE-VEHICLE-ASSETS.md:24`). The code actor faces −Z (eyes at z −0.092, `character_actor.gd:151`; walk yaw `atan2(-dir.x, -dir.z)`, `:259`). Resolve the mismatch once: import the GLB under a `Model` node rotated 180° on Y, so the file keeps the project convention and the actor keeps its own. Do not mix the two conventions inside one GLB.
- **Feet at origin.** The root bone sits on the ground between the feet, and both soles are at y = 0.000 ± 0.002 m. Nothing below zero. The current placeholder fails this by 1 cm.
- Rest pose: A-pose, arms 40° below horizontal. T-pose is acceptable but makes the shoulder weights and the armpit worse.
- Nominal height 1.75 m at scale 1.0. Per-character scale 0.92 to 1.07 (1.61 to 1.87 m), uniform only.
- One root node `CharacterRoot`, one `Skeleton3D`, meshes named `Body_LOD0` to `Body_LOD3`, optional `Hair_LOD0`, `Props`.

### 3.2 Skeleton

Side convention: the actor faces −Z, so `_r` is +X and `_l` is −X. Rest positions are for the 1.75 m figure, in metres, in the file's +Z-forward convention (so the nose points +Z). If the file is imported under the 180° wrapper, X and Z flip together and the side names stay correct.

Required bones, 22:

| Bone | Parent | Head (x, y, z) | Notes |
|---|---|---|---|
| `root` | none | 0, 0, 0 | Feet on the ground; never animated in place |
| `hips` | root | 0, 0.94, 0 | The pelvis. All root motion is authored here, and it is zero by policy |
| `spine_01` | hips | 0, 1.06, 0 | |
| `spine_02` | spine_01 | 0, 1.22, 0 | Chest |
| `neck_01` | spine_02 | 0, 1.50, 0 | |
| `head` | neck_01 | 0, 1.57, 0 | Pivot at the base of the skull, not the centre |
| `clavicle_l` | spine_02 | −0.04, 1.44, 0 | |
| `upperarm_l` | clavicle_l | −0.19, 1.42, 0 | Shoulder joint at ±0.19, not ±0.245 |
| `lowerarm_l` | upperarm_l | −0.20, 1.14, 0 | |
| `hand_l` | lowerarm_l | −0.20, 0.86, 0 | |
| `thigh_l` | hips | −0.095, 0.90, 0 | |
| `shin_l` | thigh_l | −0.095, 0.48, 0 | |
| `foot_l` | shin_l | −0.095, 0.09, 0 | Ankle |
| `ball_l` | foot_l | −0.095, 0.02, 0.11 | Toe joint, +Z forward in the file |
| `clavicle_r`, `upperarm_r`, `lowerarm_r`, `hand_r`, `thigh_r`, `shin_r`, `foot_r`, `ball_r` | mirrored | x positive | |

Optional bones, add only if they carry geometry: `jaw`, `eye_l`, `eye_r`, `hair_01` to `hair_03` (braids, ponytail, locs), `scarf_01`, `coat_tail_l`, `coat_tail_r`, `backpack` (so Wren's pack can hang and be hidden), `hat`.

Naming rules: lower snake_case, `_l` / `_r` suffixes, ASCII only, no `mixamorig:` prefix in the file. If a Mixamo rig is retargeted in Blender, map `mixamorig:Hips` → `hips`, `mixamorig:LeftArm` → `upperarm_l`, and so on, then rename before export. Godot treats bone names as node paths, so a typo is a silent animation failure.

Mapping to the placeholder (`character_actor.gd`):

| Placeholder node | Bone |
|---|---|
| `Hips` | `hips` |
| `Torso` | `spine_02` (the chest), with `spine_01` inserted |
| `Head` | `head` |
| `Hair` | `hair_01` or attached to `head` |
| `UpperArmL` / `UpperArmR` | `upperarm_l` / `upperarm_r` |
| elbow nodes | `lowerarm_l` / `lowerarm_r` |
| `UpperLegL` / `UpperLegR` | `thigh_l` / `thigh_r` |
| knee nodes | `shin_l` / `shin_r` |
| shoe mesh | `foot_l` / `foot_r`, with a `ball` for toe roll |

### 3.3 Collider

- Standing: `CapsuleShape3D`, radius 0.26 m, height 1.74 m, centre y 0.87 m, so the bottom is exactly at 0.000 and the top is at 1.74 m on a 1.75 m body. Verified property semantics on 4.7.2: `height` is the total height including both caps, and `mid_height` = height − 2 × radius = 1.22 m.
- Layer 2, mask 1. Add layer 3 for characters if they should collide with each other, then mask 1|3.
- The capsule inherits the body's uniform scale. Keep `height_scale` inside 0.92 to 1.07 or the radius shifts by 2 cm.
- Seated: keep the current switch-off, and add a small seated body (capsule r 0.22, h 0.90, centre at seat + 0.45) so a seated character cannot be walked through.
- Step height 0.25 m, safe margin 0.02 m.
- No foot or hand colliders. Footsteps, if they ever come, should raycast from `foot_l` and `foot_r`, not from a collider.
- Head clearance: 1.74 m. Village doors are 2.1, 2.2 and 2.3 m high (`village.gd:98`, pub and stores), so even the 1.87 m top of the scale clears by 23 cm.

### 3.4 Clips

30 fps, named exactly, in-place. Clip names are looked up by string, so the list is a hard contract.

| Clip | Frames | Loop | Content | Notes |
|---|---|---|---|---|
| `idle_stand` | 120 | yes | Weight shift, breathing, small head turns | 4 s. The current placeholder's breathe is a good reference |
| `idle_cold` | 120 | yes | Arms folded or hands in pockets, shoulders raised | Wren in the treeline |
| `walk` | 30 | yes | One full cycle, 1.10 m of travel at 1.1 m/s | Stride ≈ 0.55 m per step; playback rate = speed / 1.1 |
| `walk_slow` | 30 | yes | Same cycle at 0.65 m/s | Optional; playback rate can do this instead |
| `turn_l` / `turn_r` | 15 | no | 90° pivot with a foot plant | Keeps turns from skating |
| `sit_down` | 27 | no | Standing to the nominal 0.45 m seat | Hips 0.45, thigh −12°, knee +29°; the code adds the seat-height delta |
| `sit_idle` | 180 | yes | Seated breathing, hands on knees or lap | 6 s |
| `stand_up` | 27 | no | Seat to standing | |
| `wave` | 60 | no | Arm up, hand open, weight on one leg | Wren's find |
| `phone_stand` | 90 | yes | Phone held, head down, other arm wrapped | Wren's `wren_standing_phone_a` pose in clip form |
| `torch_walk` | 33 | yes | Walk with one arm forward holding a torch | Wren's `wren_walking_torch_a` |
| `crouch_idle` | 90 | yes | Crouched behind a branch, cold | Wren's `wren_crouched_a` |
| `point` | 60 | no | Arm out, for crowd models | |
| `cheer` | 60 | yes | Clap and wave, for crowd models | |
| `ghost_idle` | 120 | yes | Still, head slightly turned, no foot movement | Rennick, if she is ever shown |

**Root motion policy: none.** The root bone stays at the origin for every clip, X, Y and Z. The hips carry vertical and lateral weight shift, and the code drives world position: `CharacterActor` handles XZ, `_settle_ground()` handles Y, and the seat anchor handles sitting. This keeps a GLB and the placeholder interchangeable, keeps the thermal shells attached to bones in the same frame, and means a clip cannot fight the terrain snap. If a future on-foot player mode wants root motion, add it as a separate clip set with the `RM_` prefix so the mixer can tell them apart (Godot's `RootMotionView` is the debugging aid for that case).

**Foot contacts.** The placeholder walk is a pendulum: `_phase` advances at `walk_speed × 5.6` and the thighs swing ±0.55 rad with no stance phase, so no foot is ever planted. At 1.1 m/s the stance foot travels 0.90 m backwards relative to the body in the half cycle while the body moves 0.56 m forward, so it scuffs about 34 cm back and forth each step. It is not drift, but it reads as ice at close range. The delivered `walk` clip must hold each planted foot still in world space for the stance half, and the placeholder should be given a simple stance phase or a foot lock when time allows. Contact frames: 0 and 15 of 30, for footsteps later.

**Blends.** An `AnimationTree` with a 1D blend space from 0 to 1.4 m/s (`idle_stand` at 0, `walk` at 1.1, optional `walk_slow` at 0.65), 0.2 s crossfade. Sit and stand are one-shots queued from code.

### 3.5 LOD

The drone is the main camera. At the 24 mm setting shown on the HUD the vertical field of view works out at about 45° for a 16:9 frame (the HUD's 84° is taken as the diagonal), so at 1280 × 720:

| Distance | Pixels per metre | A 1.75 m person |
|---|---|---|
| 10 m | 87 | 152 px |
| 20 m | 43.5 | 76 px |
| 50 m | 17.4 | 31 px |
| 100 m | 8.7 | 15 px |
| 150 m | 5.8 | 10 px |

The normal flight case is 20 to 60 m, so LOD1 is the one the game actually shows. LOD0 is for the close Wren shot, and for any future on-foot mode.

| LOD | Range | Triangles | Shadows | Materials |
|---|---|---|---|---|
| LOD0 | under 12 m | 8,000 to 12,000 | Cast | Full skin shader, carded hair |
| LOD1 | 12 to 40 m | 2,000 to 3,500 | Cast | Same slots, simplified skin material |
| LOD2 | 40 to 90 m | 500 to 900 | Off | Flat colour skin, no SSS |
| LOD3 | 90 to 300 m | 60 to 120 billboard | Off | Unshaded card |
| Culled | over 300 m | | | |

Note that the story briefs ask for 1,000 to 2,500 triangles per character (`CLAUDE-NARRATIVE-ASSETS.md:10`) and 1,200 to 3,000 (`CLAUDE-ENDGAME-ASSETS.md:14`). That is fine for LOD2 and too coarse for the 152 px close shot. Ask for the LOD ladder instead of one number. Eight villagers at 3,500 triangles is 28,000 triangles on screen, which is noise next to the trees.

### 3.6 Material slots

Named with type prefixes, because `Assets.parts()` already reads prefixes from `resource_name` to swap shaders (`assets.gd:143-145`, the `bark:` / `leaf:` convention). A character loader can do the same for `skin:` and `hair:` without a bespoke mapping table.

| Slot name | Surface | Albedo | Roughness | Specular | Metallic | Textures |
|---|---|---|---|---|---|---|
| `skin:head` | Face, neck, ears | sRGB tone map | 0.42 to 0.48 | 0.38 | 0 | 2048² albedo, 2048² thickness, arm map |
| `skin:body` | Forearms, hands, chest if bare | Same tone | 0.52 to 0.58 | 0.40 | 0 | 1024² albedo, thickness |
| `hair:` | Scalp, strands | Per-character | Coily 0.65 to 0.80, straight 0.35 to 0.50 | 0.45 | 0 | 1024² albedo + alpha |
| `brow:` | Eyebrows, lashes | Dark | 0.7 | 0.3 | 0 | Optional card |
| `eye:` | Sclera and iris | Off-white, iris colour | 0.25 | 0.5 | 0 | 256² iris; clearcoat 0 |
| `cloth:outer` | Coat, jacket, fleece | sRGB | 0.85 to 0.95 wool, 0.55 to 0.65 waxed | 0.4 | 0 | 1024² albedo + normal |
| `cloth:inner` | Shirt, knit | sRGB | 0.80 | 0.35 | 0 | 512² |
| `trouser:` | Trousers, workwear | sRGB | 0.80 to 0.90 | 0.35 | 0 | 1024² |
| `boot:` | Boots | Dark leather | 0.38 to 0.48 | 0.5 | 0 | 512², normal map |
| `metal:` | Zip, buckles, badge | Grey | 0.35 | 0.5 | 0.8 | Shared |
| `prop:pack` | Wren's backpack | sRGB | 0.75 | 0.4 | 0 | 1024², wet cover variant |
| `prop:phone` | Phone body and screen | Dark, emissive screen | 0.3 | 0.5 | 0 | 256², emission |
| `prop:torch` | Torch body and lens | Grey, emissive lens | 0.35 | 0.5 | 0.4 | 256² |

Rules. No untextured skin slot in the final build. Texture sizes are power of two. The roughness map goes in the G channel of an arm map, the same packing the stone sets use (`assets.gd:243`). sRGB on albedo only, no baked lighting in albedo, and a texel density of about 10 px per cm on the face for the close shot and 5 px per cm on the body.

### 3.7 Skin shader: what the engine actually does

I checked this against the shipped Godot 4.7.2 rather than assuming, because the answer decides the whole recommendation.

- `BaseMaterial3D` in 4.7.2 has real subsurface scattering: `subsurf_scatter_enabled` (`FEATURE_SUBSURFACE_SCATTERING` = 7), `subsurf_scatter_skin_mode` (`FLAG_SUBSURFACE_MODE_SKIN` = 18), `subsurf_scatter_strength`, a thickness map via `subsurf_scatter_texture`, and a separate transmittance feature (`subsurf_scatter_transmittance_enabled`, colour, depth, boost; `TEXTURE_SUBSURFACE_TRANSMITTANCE` = 11). Confirmed from the 4.7.2 class data and a headless probe that set the properties without error.
- **It is Forward+ only.** The engine binary contains the string "Subsurface scattering is only available when using the Forward+ renderer." This project uses `forward_plus` on desktop, `mobile` on phones and `gl_compatibility` on the web (`project.godot:24-26`). On two of three targets the current material silently renders as plain diffuse, which is exactly the painted-plastic look this pass is meant to remove.
- Project-wide SSS settings, from `ProjectSettings`: `rendering/environment/subsurface_scattering/scale` 0.05 m, `depth_scale` 0.01, `quality` 1. The 0.05 m scale means roughly 5 cm of scatter, which is about a quarter of a 22 cm head. That default is a sound starting point; do not raise it for realism, raise it only if the close shot looks waxy.
- The current material assigns albedo, roughness 0.58, specular 0.34, SSS strength 0.22, skin mode on, transmittance off, rim off, and no textures. The architecture is right; the absence of any texture and the single roughness are what make it plastic.

**Recommendation, desktop path (Forward+):**

| Setting | Face | Hands and forearms |
|---|---|---|
| Albedo | Tone map, 2048², with pore and lip detail | Tone map, 1024² |
| Roughness | 0.42 (forehead, nose) to 0.50 (cheek), map | 0.52 to 0.58 |
| Specular | 0.38 | 0.40 |
| Metallic | 0 | 0 |
| SSS enabled | yes | yes |
| Skin mode | yes | yes |
| SSS strength | 0.25, scaled per tone (0.16 deep brown to 0.30 fair) | 0.15 |
| Thickness map | White at ears, nose, fingers, lips; black under hair | Same |
| Transmittance | Off for the face; on with depth 0.03 and a desaturated red colour for a separate ear/lip slot | Off |
| Clearcoat, rim | 0, 0 | 0, 0 |

The tone-scaled SSS strength matters. A single 0.22 on a palette that runs from albedo 0.235 to 0.875 gives deep brown skin too much glow and fair skin too little, so either the dark tones wash out or the light tones look chalk. Scale the strength inversely with the albedo luminance and leave the albedo alone. Do not lift deep tones toward mid-brown to compensate; that greys the skin.

**Recommendation, mobile and web path:** same colour maps, `subsurf_scatter_enabled = false`, and `backlight_enabled = true` with `backlight = Color(0.55, 0.18, 0.12)`, roughness 0.50, specular 0.40. Backlight is the cheap translucency approximation and it survives every renderer. Branch once in `skin_material()` on `RenderingServer.get_current_rendering_method() == "forward_plus"`, the same pattern the tree code uses to pick a leaf shader per renderer (`assets.gd:127-128`).

**Optional stage two:** a `skin.gdshader` with wrapped diffuse and a reddened wrap term, if the backlight fallback still reads flat on mobile. Wrap = 0.45, `diffuse_light = clamp((dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap), 0.0, 1.0)`, GGX specular at 0.4, roughness mapped 0.35 to 0.6. Tie the wet response to the existing `g_wet` global the way bark does (`tree_bark.gdshader:45-55`): skin darkens about 20% and the specular rises when it rains. Do not start here; a custom shader is a maintenance cost and the base material plus a good albedo map is most of the way.

**How to tell plastic from skin** (all three must pass at 2 m):

1. The highlight is broad and slightly coloured, not a small white pinprick. A pinprick means roughness is under 0.3 or specular is too high.
2. The shadow terminator is soft and shifts toward red. A hard grey terminator means SSS is off, or the renderer is mobile and the fallback is missing.
3. The ear rim and the side of the nose glow when the light is behind. No glow means the thickness map is white everywhere or transmittance is off when it should be on.

### 3.8 Hair and cloth

- Hair is its own mesh and slot, never part of the skin mesh. Weight it to `head`, plus a `hair_01..03` chain for anything that hangs (braids, ponytail, locs), so it can swing and can be given a cloth-like sway later.
- LOD0 hero hair can use alpha cards 8 to 12 cm wide with `alpha_scissor`, not alpha blend, to avoid sorting. The villager LOD1 can keep a solid cap. Wren's close shot cannot.
- Roughness by hair type: coily and Afro-textured 0.65 to 0.80 with a wide lobe; straight 0.35 to 0.50; wet hair darkens 30 to 45% and clumps. The single roughness of 0.92 in the placeholder reads as felt.
- Cloth: wool and fleece 0.85 to 0.95, waxed cotton 0.55 to 0.65 with specular 0.5, denim 0.80, leather boots 0.38 to 0.48. Non-metallic except hardware.
- Wren's backpack should be a `prop:pack` slot, not part of the coat mesh (the placeholder builds it into the body at `character_actor.gd:220-224`), so it can be hidden, swapped for the wet-cover variant, or dropped at the cabin.

### 3.9 File layout and manifest

```
assets/characters/
  wren/wren.glb + wren_manifest.json
  cast/ada_okafor.glb, mei_lin.glb, ravi_patel.glb, grace_adeyemi.glb,
       hana_sato.glb, priya_nair.glb, daniel_whitlock.glb, arthur_bell.glb
  rennick/rennick_1984.glb + rennick_1984_ghost.glb      (if she is ever shown)
  crowd/crowd_point_a.glb, crowd_cheer_a.glb, crowd_seated_a.glb
```

Each `manifest.json` follows the `assets/manifest.json` precedent (`assets.gd:301-307`): id, height, bbox, root, forward axis, bone list, clip list with loop flags, material slots, texture sizes, triangle counts per LOD, and seat offset. The loader should read the manifest rather than trust the file name.

### 3.10 Acceptance for a delivered GLB

A delivered file passes when: it imports with no scale warning; the soles are at 0.000 ± 0.002 m; the height is within 2 cm of the manifest; the 22 bones are present with the exact names and parents; skin weights are normalised with no unweighted vertices and no more than 4 influences; the clips match the named set with the right loop flags; material names carry the prefixes above; textures are power of two and sRGB only on albedo; the LOD meshes are named `Body_LOD0` to `Body_LOD3`; the rest pose is A-pose; and the file is under 4 MB for LODs 0 to 2.

## 4. Diversity and casting

### 4.1 The rule

The valley is a British-leaning rural place, and the cast should read as people who already live there. Jobs, routes, coats and one telling detail carry character. Race is a fact about a person, not a theme: no line of dialogue refers to it, and no outfit is a costume. The test for each character is whether you could describe them to a neighbour without using their ethnicity as the description.

### 4.2 Skin, hair and body variation

**Skin.** The palette in `character_actor.gd:23-33` is nine tones, and it is a good base: it is read as material data, not an ethnicity label. Three fixes:

- Use all nine. The current cast uses five, with tone 7 twice, 8 twice and 6 twice (section 4.3 gives the reassignment).
- Give each tone its own SSS strength and roughness, as in section 3.7. There is no single value that works across the range.
- Do not reskin a character lighter to "read better at distance". Under this valley's overcast and rain light, a deep brown can go to silhouette. The answer is specular and backlight/SSS, not albedo lift.

**Hair.** Six styles exist as primitives (`crop`, `short`, `braids`, `bun`, `ponytail`, `long`, `character_actor.gd:44`). Add `afro` (a coily volume with a visible edge, not a sphere), `locs` (6 to 12 hanging tubes with a scalp parting), `wavy` and `straight_long`. The current braids are two rods at ±0.105 m (`:214-216`); at LOD0 they need 6 to 10 strand cards per side and a parting, or they read as antennae. Braids, locs and ponytails want a hair bone chain so they move.

**Body.** Right now every person shares one shoulder width (0.594 m) and one torso radius, so eight villagers are eight copies of the same silhouette. Add a `build` parameter: shoulder pivot 0.17 to 0.22 m, chest depth 0.17 to 0.24 m, hip width 0.30 to 0.38 m, belly 0 to 1. Do not map build to gender: vary it independently. Heights should span 1.60 to 1.86 m, not the current 1.59 to 1.71 m, which is every adult below average.

**Age.** Spread from 20s to 70s. Ages are visible in a rural street more than almost anything else, and they cost nothing on a primitive rig.

**Outfits.** Rural layers: fleece, waxed cotton, knit scarf, work trousers, boots, an apron or tabard for shop and pub work, hi-vis for the garage yard. Muted colours with one accent per person. The current code already uses the scarf as the accent, which is the right instinct. Nothing culturally specific unless the character chose it, and never as the whole character.

**Role spread.** Make sure authority and service are not split along lines of race. The cast below has Black and Asian characters owning the stores and the pub, and a white character as the young farmhand, with the retired white man on the bench.

### 4.3 The cast

Ten named people: eight villagers in code now, plus Wren and Rennick, who are shown only if the story ever puts them on screen.

Skin index is the palette index from `character_actor.gd:23-33`. Where it is proposed, the code's current value is noted.

| # | Name | Role | Age | Skin | Hair | Height / build | Outfit | One detail |
|---|---|---|---|---|---|---|---|---|
| 1 | **Ifeoma Okafor** (currently "Ada Okafor") | Sub-postmistress, runs the counter inside Halloway Stores | 50s | 0 deep brown | Braids, greying at the temples | 1.66 m, broad | Teal wool coat, ochre scarf, reading glasses on a chain | Knows everyone's business and repeats none of it |
| 2 | **Mei Lin** | Shopkeeper, Halloway Stores | 40s | 7 east asian light | Straight bob | 1.63 m, slight | Deep red padded coat, yellow scarf, shop apron indoors | Orders the papers and the flour, complains about both |
| 3 | **Ravi Patel** | Mechanic and owner, Halloway Garage | 30s | 8 south asian medium | Short crop | 1.72 m, wiry | Blue overalls, red scarf, oil-stained cuffs | Keeps the festival bus running; the only person Ellis Voss talks to |
| 4 | **Grace Adeyemi** | Landlady and cook, The Hollow Crown | 50s | 2 warm brown (currently 1) | Low bun | 1.65 m, sturdy | Ochre top, green scarf, dark apron | The only person who calls Riley by her first name |
| 5 | **Hana Sato** | Village bus driver | 40s | 5 olive (currently 7) | Ponytail | 1.62 m, slight | Navy bus-company fleece, red scarf | Waves at the drone every time it goes over |
| 6 | **Priya Nair** | District nurse | 30s | 3 golden tan (currently 8) | Long, tied back on shift | 1.68 m, average | Green coat, tan scarf, a medical bag she never puts down | Parks behind the pub because the lane is too narrow |
| 7 | **Daniel Whitlock** | Retired farm machinery salesman | 70s | 6 fair | Short, grey (hair colour 4) | 1.71 m, stooped | Olive coat, brown scarf | Sits on the same bench every afternoon, watching the lane |
| 8 | **Arthur Bell** | Farm hand | 20s | 4 light tan (currently 6) | Short, brown | 1.75 m, lanky | Dark work coat, maroon scarf, boots | Always carrying something; never in a hurry |
| 9 | **Wren** | Lost hiker, the story's centre | Late 20s | 1 rich brown | Crop | 1.67 m (0.98 scale), slight | Mustard rain jacket, dark trousers, brown scarf, backpack | Keeps a paper map even though they have a phone |
| 10 | **Constable Ada Rennick** | Halloway detachment, died on the north shore in 1984 | 32 at death | 2 warm brown | Short natural hair under the cap | 1.68 m | 1984 provincial uniform, cap, duty belt with radio and torch, no weapon | Says "this is a favour, not a case" and means it |

Why these choices:

- **The cast uses every skin tone once.** Current indices are 0, 7, 8, 1, 7, 8, 6, 6: two pairs repeat and four tones are unused. The reassignment above uses 0 to 8 across the villagers plus Wren at 1, so no two people in the street share a tone, which is what makes a varied cast read as varied at 20 m.
- **Two Black women hold authority** (the post office and the pub). The Asian characters own the stores and drive the bus. The white characters are a retired man and a young farmhand. That spread is deliberate.
- **Wren stays Black**, as the placeholder already codes them (skin 1, `case_objects.gd:661`), and the app portrait must match (`CLAUDE-APP-ASSETS.md:32`). Their presentation stays `they/them`, matching the story text (`ENDGAME.md:10`, and "You found them" at `finale.gd:147`).
- **Rennick is cast as a Black woman in her early thirties**, which is the age she was when she died. If she appears as the ghost, keep her skin tone and features and lift her with a pale rim and emission. Do not desaturate her to white. That is the default ghost treatment, and it would recast the story's one Black authority figure as a white apparition. Her living 1984 portrait and her Casebook avatar should be full-tone.

### 4.4 Continuity problems in the current casting

1. **Two Adas.** The village cast has "Ada Okafor" (`village.gd:343`) and the constable's proposed first name is Ada Rennick (`docs/story/TOWN-ARC.md:37`, `:191`). A player meeting Ada Okafor in the lane will carry that name into the ghost reveal. Rename the villager, or drop the constable's first name. Recommended: Ifeoma Okafor, with Ada kept for Rennick.
2. **Rennick's age is stated two ways.** `CLAUDE-APP-ASSETS.md:29` asks the avatar for an "older" Rennick; `TOWN-ARC.md:37` says thirties, and she died in 1984. Since she is a 1984 ghost and a 1984 portrait, she is early thirties. "Careful, quiet authority" is posture and framing, not age lines. Update the avatar brief.
3. **Rennick's pronouns are still an open question** (`MESSAGE-VOICE.md:70`), while the story documents, the voice brief and every chapter use she and her. Lock she/her and delete the question, or the asset lane will get it wrong.
4. **The thermal pass documents villagers that are not in the thermal pass.** `THERMAL-CAMERA.md:45` and `:64` claim the village cars and the people read hot and that the shells are sized to the silhouettes; neither is true now (finding 3).

### 4.5 Cost

Eight villagers at LOD1 are about 28,000 triangles, which is nothing. SSS is the only real cost: it is per-pixel, desktop only, and should be limited to the nearest two or three characters, with the flat fallback material on the rest and everywhere on mobile.

## 5. In-engine verification checklist

Run these with the existing screenshot hooks. The command shape follows `docs/realism/trees/commands.txt`: the console binary, `--path .`, then `--` and one user argument. The screenshot mode parses `shot=<file>,<frames>,<fpv|chase>,<tokens>` (`main.gd:1083-1088`), and the `at<x>_<y above ground>_<z>_<yaw deg>_<gimbal deg>` token places the camera (`main.gd:1112-1115`). The hooks for this pass are `villageshot` (`main.gd:1530`), `wrenshot` (`:1537`, now shows Wren without moving the camera), `wrenshow` (`:1540`, the same thing with a debug print) and `thermalwren` (`:1559`).

```
G = ..\..\_tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe

People, street level (villageshot now puts the camera at 420, 292, 2 m up, looking north):
  G --path . -- "shot=docs/realism/characters/00_village_people.png,300,fpv,villageshot,clock15.0"

Wren standing, camera 6 m east of the search spot looking west, then close on the feet:
  G --path . -- "shot=docs/realism/characters/01_wren_stand.png,300,fpv,wrenshow,at-64_2_-790_90_-10,clock20.5"
  G --path . -- "shot=docs/realism/characters/01b_wren_feet.png,300,fpv,wrenshow,at-70_1.2_-784_0_-5,clock20.5"

Bench sit, camera 4 m south-east of bench A looking at it:
  G --path . -- "shot=docs/realism/characters/04_bench_sit.png,300,fpv,at354_1.5_284_45_-8,clock15.0"

Wren through the thermal camera at 20 m:
  G --path . -- "shot=docs/realism/characters/02_wren_thermal.png,300,fpv,thermalwren,clock20.5"

Mobile renderer, same street:
  G --rendering-method mobile --path . -- "shot=docs/realism/characters/03_village_mobile.png,300,fpv,villageshot,clock15.0"
```

The camera hooks move between edits, so check the current `_screenshot_mode` branches before a run. The yaw convention: 0 faces −Z (north), 90 faces −X (west), 180 faces +Z (south).

Then check, in this order:

1. **Feet on the ground.** 5 m shot, both shoes. Pass: each sole is within 1 cm of the visible grass, with a contact shadow under it. Current placeholder fails at −1.0 cm by construction (shoe sole below the root) and floats up to 2.1 cm at slope.
2. **No float or sink on slopes.** Repeat on the lane (7.8°) and at the cabin (6.3°). Pass: under 1.5 cm after the normal pitch fix; up to 3 cm is expected before it. Fail: a visible gap at 5 m.
3. **Collider contact.** Walk an actor into a cottage wall. Pass: stops at the capsule radius, 0.26 m from the wall, and does not enter. Fail: passes through any hedge, parked car, phone box, bus shelter, post box, lamp post, cabin, cruiser or bus.
4. **Bench sit.** Daniel on bench A, from the side and from the front. Pass: hips at 0.53 ± 0.01 m, both feet flat within 1 cm, back clear of the backrest by at least 1 cm, and no part of him inside the seat slab. Current state fails all four (section 2.3).
5. **Seat transition.** If `sit_down` and `stand_up` exist: no foot slide, no floating, and the return pose lands on the lane with the capsule re-enabled.
6. **Walk.** Side-on at 5 m. Pass: the planted foot does not move against the ground; the stride matches the speed. Current placeholder scuffs about 34 cm per step.
7. **Thermal shell alignment.** Thermal camera, Wren at 20 m. Pass: head, hands and torso shells sit within 2 cm of the visible silhouette and the hands are where the hands are. Current state: torso 9.5 cm too fat, head 6.2 cm too fat, hands 6.5 cm outboard with no arm geometry under them, and 4% small from the double scale.
8. **Thermal coverage.** Every villager and the two parked cars must show a signature, and turning the camera off must hide every shell. Current state: villagers and the village cars never show.
9. **Skin not plastic.** 2 m close-up of the head. Pass: broad, slightly coloured highlight; soft, reddening terminator; glowing ear rims when backlit. Fail: pinprick highlight (roughness under 0.3), flat grey shadow (SSS off on mobile), or a uniform mask (no texture).
10. **No self-intersection.** Rest pose: the arms already overlap the torso by 1.2 cm at ±0.245 pivots. Check the walk extremes and the mid-frame of the sit: forearms clear of the coat, knees clear of each other, hair clear of the shoulders.
11. **Scale against doors and benches.** Door height 2.1 m, bench seat 0.53 m. Pass: an adult's head is under the lintel with 20 to 35 cm of clearance, and the hips meet the bench. Judge height against the door top, not the door bottom, until the thresholds in section 2.4 are fixed.
12. **Shadow contact.** Pass: both shoes have a soft contact shadow with no gap. Turn shadows off on LOD2 so distant people do not cast hard dots.
13. **LOD switches.** Use the `at` camera token at 12, 40 and 90 m. Pass: no visible pop in silhouette or height; the person is a clean shape at 40 m (31 px).
14. **Renderer fallback.** Run the mobile command and confirm the skin material branch took the no-SSS path (print `RenderingServer.get_current_rendering_method()` in a probe if unsure). Pass: no pink, no flat white, no shader error in the log.
15. **Two characters, one spot.** Walk two actors into each other. Current state: they overlap. Either accept it or add character-to-character layer 3.

## 6. Priority list

**P0, fixing what is visibly broken**

1. Seat anchor and seated placement. Add `SeatAnchor` to benches and chairs, place seated actors from it, fix the hip height to the real 0.53 m, author `sit_down`/`sit_idle`/`stand_up` with thigh −12° and knee +29°, and keep a seated collider.
2. Thermal shells. Rebuild the person shell against the actor's measured geometry, parent it to bones with `BoneAttachment3D`, build `_heat` inside `CharacterActor`, call `Village.set_thermal_heat()` from `main._sync_thermal_heat()`, and remove the double scale on Wren. Update `THERMAL-CAMERA.md:45` and `:64`.
3. Collider capsule and soles. Capsule centre 0.79 m for r 0.25 h 1.58 so the bottom is at 0.000; move the shoe boxes from −0.45 to −0.44 so the soles are at 0.000.
4. Character collision. Push-out via `World.obstacle_hit()` plus the village boxes, and add the missing hedge, car, lamp, phone box, shelter and post box obstacles.
5. Building thresholds and plinths, so doors stop floating and burying (section 2.4).

**P1, making it good**

6. Proportions: shoulders to ±0.19 m, arm rest gap +4 cm, torso radius 0.185 m.
7. Skin: albedo and roughness maps, tone-scaled SSS, thickness map, and the mobile backlight fallback.
8. Walk with a real stance phase on the placeholder, and a proper `walk` clip from the asset lane.
9. Height and build spread across the cast, and the skin-tone reassignment.
10. Ground normal pitch on actors.
11. Rename Ada Okafor, settle Rennick's age and pronouns.

**P2, later**

12. Hair cards and hair bones at LOD0, the backpack slot, footsteps from contact frames, the crowd models on this rig, and the LLOD ladder in the story briefs.

## 7. Open questions for Robert

1. Face direction: keep +Z in every GLB with a 180° wrapper in code (recommended), or make characters the one −Z exception?
2. Is Wren permanently a Black character? The placeholder says yes (skin 1); the app avatar brief should say so too.
3. Rennick: a Black woman in her early thirties, she/her. Confirm, or overrule.
4. Rename Ada Okafor, or give the constable a different first name?
5. Do villagers need to be interactable at all (look-at, a line of dialogue), or are they scenery that walks?
6. Is desktop-only SSS acceptable if mobile gets the backlight fallback and looks slightly flatter, or must both match exactly?

## Appendix A: character definition skeleton

A drop-in array for `game/character_data.gd` or a JSON file, using the palette indices and the cast above. Fields are optional except `id`, `name`, `role`, `skin`, `hair`, `height`.

```json
[
  {
    "id": "ifeoma_okafor",
    "name": "Ifeoma Okafor",
    "role": "sub-postmistress",
    "age": 50,
    "skin": 0,
    "hair": "braids",
    "hair_color": 1,
    "height": 0.95,
    "build": {"shoulder": 0.21, "chest": 1.05, "belly": 0.2},
    "outfit": {"coat": "#2f5a56", "trousers": "#232b2b", "scarf": "#c27a2c"},
    "clip": "walk",
    "route": [[356.0, 278.0], [380.0, 280.0], [404.0, 279.0], [380.0, 280.0]],
    "speed": 0.85,
    "thermal": {"torso": [0.24, 0.78, 1.20], "head": [0.12, 1.58], "hands": 2}
  },
  {
    "id": "mei_lin",
    "name": "Mei Lin",
    "role": "shopkeeper",
    "age": 45,
    "skin": 7,
    "hair": "bob",
    "hair_color": 0,
    "height": 0.94,
    "build": {"shoulder": 0.18, "chest": 0.95, "belly": 0.1},
    "outfit": {"coat": "#7a2420", "trousers": "#2b2f36", "scarf": "#d4a83a"},
    "clip": "walk",
    "route": [[404.0, 286.0], [416.0, 290.0], [410.0, 281.0], [400.0, 278.0]],
    "speed": 0.95
  },
  {
    "id": "ravi_patel",
    "name": "Ravi Patel",
    "role": "garage owner",
    "age": 35,
    "skin": 8,
    "hair": "crop",
    "hair_color": 0,
    "height": 0.99,
    "build": {"shoulder": 0.20, "chest": 1.0, "belly": 0.0},
    "outfit": {"coat": "#2f3a52", "trousers": "#232a30", "scarf": "#8a2a20"},
    "clip": "walk",
    "route": [[458.0, 292.0], [478.0, 290.0], [470.0, 285.0], [460.0, 294.0]],
    "speed": 0.90
  },
  {
    "id": "grace_adeyemi",
    "name": "Grace Adeyemi",
    "role": "publican",
    "age": 55,
    "skin": 2,
    "hair": "bun",
    "hair_color": 1,
    "height": 0.97,
    "build": {"shoulder": 0.19, "chest": 1.08, "belly": 0.25},
    "outfit": {"coat": "#7a5426", "trousers": "#292a25", "scarf": "#2f4740"},
    "clip": "walk",
    "route": [[368.0, 288.0], [380.0, 286.0], [392.0, 288.0], [380.0, 286.0]],
    "speed": 0.80
  },
  {
    "id": "hana_sato",
    "name": "Hana Sato",
    "role": "bus driver",
    "age": 40,
    "skin": 5,
    "hair": "ponytail",
    "hair_color": 0,
    "height": 0.93,
    "build": {"shoulder": 0.18, "chest": 0.92, "belly": 0.1},
    "outfit": {"coat": "#384c70", "trousers": "#2e2e33", "scarf": "#a8382b"},
    "clip": "walk",
    "route": [[394.0, 258.0], [408.0, 260.0], [420.0, 258.0], [408.0, 260.0]],
    "speed": 0.90
  },
  {
    "id": "priya_nair",
    "name": "Priya Nair",
    "role": "district nurse",
    "age": 32,
    "skin": 3,
    "hair": "long",
    "hair_color": 0,
    "height": 0.95,
    "build": {"shoulder": 0.18, "chest": 0.96, "belly": 0.15},
    "outfit": {"coat": "#33593c", "trousers": "#2a2825", "scarf": "#94602e"},
    "clip": "walk",
    "route": [[338.0, 266.0], [346.0, 274.0], [338.0, 280.0], [346.0, 274.0]],
    "speed": 0.82
  },
  {
    "id": "daniel_whitlock",
    "name": "Daniel Whitlock",
    "role": "retired",
    "age": 72,
    "skin": 6,
    "hair": "short",
    "hair_color": 4,
    "height": 1.0,
    "build": {"shoulder": 0.19, "chest": 1.0, "belly": 0.3},
    "outfit": {"coat": "#4c543f", "trousers": "#272824", "scarf": "#66422e"},
    "clip": "sit_idle",
    "seated": true,
    "seat": {"id": "bench_a", "yaw": 0.2}
  },
  {
    "id": "arthur_bell",
    "name": "Arthur Bell",
    "role": "farm hand",
    "age": 22,
    "skin": 4,
    "hair": "short",
    "hair_color": 2,
    "height": 0.98,
    "build": {"shoulder": 0.21, "chest": 0.98, "belly": 0.0},
    "outfit": {"coat": "#3a3833", "trousers": "#1f2321", "scarf": "#5c1d17"},
    "clip": "walk",
    "route": [[428.0, 268.0], [446.0, 270.0], [432.0, 276.0], [446.0, 270.0]],
    "speed": 0.62
  },
  {
    "id": "wren",
    "name": "Wren",
    "role": "lost hiker",
    "age": 27,
    "skin": 1,
    "hair": "crop",
    "hair_color": 0,
    "height": 0.98,
    "build": {"shoulder": 0.18, "chest": 0.94, "belly": 0.05},
    "outfit": {"coat": "#a86b2a", "trousers": "#262f2e", "scarf": "#703818"},
    "clip": "idle_cold",
    "props": ["pack", "torch", "phone"],
    "thermal": {"torso": [0.23, 0.80, 1.22], "head": [0.12, 1.58], "hands": 2}
  },
  {
    "id": "rennick_1984",
    "name": "Constable Ada Rennick",
    "role": "police constable, 1984",
    "age": 32,
    "skin": 2,
    "hair": "crop",
    "hair_color": 0,
    "height": 0.96,
    "build": {"shoulder": 0.19, "chest": 0.98, "belly": 0.0},
    "outfit": {"coat": "#2b3242", "trousers": "#23262e", "scarf": "#111318"},
    "clip": "ghost_idle",
    "variants": ["living", "ghost"],
    "props": ["notebook", "cap", "radio"]
  }
]
```

## Appendix B: the numbers this brief relies on

| Quantity | Value | Where it comes from |
|---|---|---|
| Terrain sample spacing | 1.953 m (near mesh 1.95 m, far mesh 15.6 m) | `terrain.gd:9-13, 48-50` |
| Bilinear vs drawn triangle | 0.0 to 0.55 cm | Heightmap probe over the cells under each site |
| Village lane slope | 7.8° | Heightmap probe at 421, 272 |
| Standing foot float / sink | +2.45 / −3.10 cm worst | Heightmap probe at the eight shoe corners |
| Bench leg float / sink | +5.22 / −5.04 cm worst | Heightmap probe at the two benches |
| Bench seat height | 0.53 m | `village.gd:235` |
| Door floats / buries | +0.65 m (cottage 2) to −0.65 m (garage) | Heightmap probe at the door edges |
| Placeholder height | 1.706 m at scale 1.0; Wren 1.672 m | `character_actor.gd` construction |
| Placeholder shoe sole | −1.0 cm | `character_actor.gd:192, 202` |
| Collider capsule bottom | +3.0 cm | `character_actor.gd:226-233` |
| Shoulder outer width | 0.594 m | `character_actor.gd:161-180` |
| Arm-to-torso overlap at rest | 1.2 cm | 0.245 pivot − 0.052 arm radius vs 0.205 torso radius |
| Seated hips vs seat | −3.0 cm | `character_actor.gd:272-283` vs `village.gd:235` |
| Thermal torso / head / hands error | 9.5 cm / 6.2 cm / 6.5 cm, plus 4% double scale | `thermal_heat.gd:51-61` vs the actor |
| Static collision boxes in the valley | 11 | `village.gd:100,117,142,158,237` |
| World colliders, drone only | 2,521 cylinders + 2 boxes | `assets/world/layout.json` |
| SSS availability | Forward+ only | Godot 4.7.2 binary and class data |
| Capsule height semantics | total, including caps; `mid_height` = height − 2r | 4.7.2 headless probe |

## Appendix C: what was checked and what was not

Read in full or in the relevant part: `game/character_actor.gd`, `game/case_objects.gd` (`_build_hiker`, cabin, cruiser), `game/village.gd`, `game/anti_drone.gd`, `game/thermal_heat.gd`, `game/terrain.gd`, `game/finale.gd`, `game/main.gd` (thermal sync, screenshot hooks), `game/assets.gd`, `game/graveyard.gd` (angel), `game/world.gd` (obstacle query), `game/roads.gd`, `project.godot`, and the docs named in the text (`CLAUDE-ENDGAME-ASSETS.md`, `CLAUDE-NARRATIVE-ASSETS.md`, `CLAUDE-ANTI-DRONE-ASSETS.md`, `CLAUDE-APP-ASSETS.md`, `ANTI-DRONE-RIDGE.md`, `THERMAL-CAMERA.md`, `MODEL-STATUS.md`, `MESSAGE-VOICE.md`, `TOWN-ARC.md`, `ENDGAME.md`, `APP-SCREENS-AUDIT.md`, `VILLAGE-LAYOUT.md`).

Verified against the engine rather than from memory: Godot 4.7.2 class data for `BaseMaterial3D`, `CapsuleShape3D`, `BoneAttachment3D`, `Skeleton3D`, `AnimationMixer`, `RootMotionView`; a headless probe that set the SSS properties and measured the capsule; the binary string that limits SSS to Forward+.

Measured from the shipped data: every terrain and slope figure above, by decompressing `assets/world/valley_height.bin` and reproducing `Terrain.height()` and the triangle split from `terrain.gd:59-117`.

Not verified: any actual render of the new actors. I did not launch the game, because the Lead was editing `case_objects.gd`, `village.gd` and `main.gd` during the audit and a run would have raced the import cache. I also could not verify the delivered-character path, since there are no character GLBs in `assets/` yet. Screenshots referenced by `THERMAL-CAMERA.md` (`docs/realism/thermal/00_wren.jpg`) predate the actor swap, so they cannot be used to judge the current shell alignment.

Line numbers refer to the 11:18 snapshot; functions and constants are named so the references survive the churn.
## Lead implementation note (2026-11-15, after this brief)
The code placeholder has been aligned to the brief's first P0s:
- `CharacterActor` now has a `seat_height` contract; the village bench passes its real 0.53 m seat surface and the seated hips are 2 cm above it, not 3 cm inside it.
- The collider capsule bottom is at the sole line (centre 0.79, height 1.58) and the shoes are at the root line.
- The cast has been renamed **Ifeoma Okafor** (no collision with Constable Ada Rennick) and now uses all nine skin tones once. Heights run 1.58 to 1.78 m.
- Grace's route no longer crosses hedge 5; hedges, phone box, post box, parked cars and the bus shelter now have static boxes.
- Wren's old capsule hiker is replaced by `CharacterActor`. Wren is a rich-brown-skinned hiker in a mustard coat with a crop, backpack and the same actor as the villagers.
- Thermal shells are resized to the actor and Wren's double 0.98 scale is removed. Villagers now build heat shells, and `Village.set_thermal_heat()` is called from `main._sync_thermal_heat()`, so both parked cars and people light up.
- `skin_material()` now branches on the renderer: Forward+ uses tone-scaled subsurface scattering; Mobile/Compatibility uses backlight. It has a procedural noise albedo/roughness map rather than one flat colour.
- The production GLBs and clips are still not delivered. The placeholder walk still scuffs because it has no stance lock; the brief's clips remain the fix.

Evidence: `docs/realism/characters/00_wren_stand.jpg`, `01_cast_line.jpg`, `02_wren_thermal.jpg`, `03_village_walk.jpg`, `04_sit.jpg`, `05_walk.jpg`. Full status: `docs/CHARACTER-SYSTEM.md`.
### Rig pass 2 addendum
The placeholder now has explicit hip, knee and ankle pivots on both legs, shoulder, elbow and wrist pivots on both arms, and a level-foot ankle correction in the walk. The seated pose uses the real seat height, thigh and knee folds, and flat feet. Wren gets a `wave` state on the finale find, facing the camera. The production clips still replace all of this; the placeholder is now a joint check rather than a static mannequin.
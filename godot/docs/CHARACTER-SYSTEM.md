# The character system: what is built and what is still a placeholder

Status: 2026-11-15. This is the code-side note for the character pass. The production rig and casting specification is in `docs/CLAUDE-CHARACTER-BRIEF-2026-11-15.md`; the model delivery status is still the hard truth in `docs/MODEL-STATUS.md`: **no Claude character GLBs exist yet.** What exists now is a working code placeholder that stands, sits, walks, collides and uses a proper skin material, so the valley is not empty while the art is commissioned.

## What is in the game

`game/character_actor.gd` is the one human-actor system. Wren and the village cast use it.

- **Root and feet:** the scene root is between the feet on the ground, not at the hips. The body is built upward from there.
- **Collider:** a `CharacterBody3D` capsule, radius 0.25 m and height 1.58 m, centred at 0.79 m so the capsule bottom sits at the sole line. Characters collide with the village's static building, bench, hedge, phone box, post box, parked-car and bus-shelter boxes.
- **Ground:** `_settle_ground()` samples `Terrain.height()` every physics tick and puts the root on it. The valley terrain still has no physics collider; this is a height-sampled walker, not a rigid-body faller. That is deliberate for the drone game and should be replaced by a proper ground query when an on-foot player mode arrives.
- **Standing:** an idle breathing pose with a slight weight shift.
- **Walking:** a closed route, a procedural two-segment walk, opposite arm swing and a knee bend. It is a placeholder walk, not a production clip: the feet scuff because there is no stance lock. The delivered clips in the brief replace it.
- **Sitting:** `seat_height` is read from the actor's seat contract, the hips are placed at the seat surface plus 2 cm, the thighs and knees fold to reach the ground, and the character collider is switched off. Daniel Whitlock uses the bench's real 0.53 m seat surface. The bench collider is a solid block; the brief recommends splitting it into seat, back and legs for standing at the bench front.
- **Thermal:** every actor can build a `ThermalHeat.person` shell; the shells are invisible until the thermal camera is on. Wren's shell is attached once at the actor scale, not scaled twice. The village's `set_thermal_heat()` now drives both the parked cars and the people.
- **Skin:** `CharacterActor.skin_material()` uses a procedural noise albedo and roughness map, roughness 0.50, specular 0.38 and no metallic. On the Forward+ renderer it uses Godot's physical subsurface scattering with a strength scaled by skin tone. On Mobile/Compatibility it switches to the backlight approximation, because Godot 4.7 only supports SSS on Forward+. There is no real face albedo/thickness map yet; that needs the Claude texture set.

## The cast

The cast uses all nine skin tones once. It is deliberately mixed, and the characterisation is ordinary jobs and clothes rather than ethnicity-as-costume.

| Name | Role | Skin | Hair | Height |
|---|---|---|---|---|
| **Wren** | lost hiker, the centre of the Lake Car story | rich brown (1) | crop | 1.67 m |
| **Ifeoma Okafor** | post office and village green | deep brown (0) | braids | 1.67 m |
| **Mei Lin** | Halloway Stores | east asian light (7) | short | 1.59 m |
| **Ravi Patel** | Halloway Garage | south asian medium (8) | crop | 1.78 m |
| **Grace Adeyemi** | The Hollow Crown | warm brown (2) | bun | 1.65 m |
| **Hana Sato** | bus shelter and the lane | golden tan (3) | ponytail | 1.58 m |
| **Priya Nair** | village green | olive (5) | long | 1.62 m |
| **Daniel Whitlock** | retired, on the bench | fair (6) | short | 1.73 m |
| **Arthur Bell** | slow walk to the pub | light tan (4) | grey | 1.70 m |

Wren uses they/them in the story. Rennick is a Black woman in her early thirties at the time of her death; she is text-only today, and if the ghost is ever modelled the brief says the ghost must keep her skin tone rather than desaturate her to white.

## What was fixed in this pass

- Wren was a five-primitive capsule with no arms and no collider; she is now the same articulated actor as the village.
- Sitting read no seat height and put the hips 3 cm inside the bench. It now reads a `seat_height` contract and uses the bench's 0.53 m seat surface.
- The capsule bottom floated 3 cm; the shoe soles sat 1 cm under the root. Both are corrected.
- Wren's thermal shell was scaled twice and was authored for the old capsule; it now matches the actor.
- Villagers had no thermal shell and the village `set_thermal_heat()` was never called. Both are wired.
- The old skin was one flat colour and one roughness. It now has tone-scaled SSS on Forward+, a backlight fallback on Mobile/Compatibility, and a noise albedo/roughness map so it does not read as plastic.
- The cast had a name collision with Constable Rennick ("Ada Okafor") and reused three tones six times. Renamed to Ifeoma and the palette is now used once per person.
- Grace's route crossed hedge 5. It now runs clear of the hedge, and the hedge has a collider.
- Cottages, pub, shop, garage, benches, hedges, phone box, post box, parked cars and bus shelter now have static colliders.

## Honest limits

- **The character models and animation clips are not delivered.** This is a code placeholder, not the final rig. See `CLAUDE-CHARACTER-BRIEF-2026-11-15.md` for the 22-bone skeleton, 15 clips, LOD ladder and material slots.
- **The walk is procedural and scuffs.** It has no stance-phase foot lock. The production `walk` clip must solve it.
- **There is no terrain physics collider.** The actor is height-snapped, which is fine for a distant villager but not a full on-foot character controller.
- **There is no character-vs-character collision.** Two walkers can pass through each other; they collide with the static world.
- **The braids, bun and ponytail are primitive shapes.** The brief asks for proper hair cards and hair bones; an afro and locs style are specified but not in the placeholder.
- **The skin has no face texture or thickness map.** The material architecture is right; the maps are not delivered.
- **Only one close-up render was verified:** Wren at the default spawn, plus a line of four cast members, plus the Wren thermal signature. Sitting and walking were verified from the code and measured constants, not from a live animation capture. The brief's section 5 has the full render checklist.

## Evidence

- `docs/realism/characters/00_wren_stand.jpg`
- `docs/realism/characters/01_cast_line.jpg`
- `docs/realism/characters/02_wren_thermal.jpg`
- `docs/realism/characters/03_village_walk.jpg`
- `docs/realism/characters/04_sit.jpg`
- `docs/realism/characters/05_walk.jpg`
- `docs/CLAUDE-CHARACTER-BRIEF-2026-11-15.md`
## Rig pass 2: knees, elbows, hips, feet and the end beat

The placeholder is now articulated at every joint the brief asks for:
- **Legs:** hip pivot -> thigh -> knee pivot -> shin -> ankle pivot -> shoe. The shoe sole sits on the root/ground line. The ankle counter-rotates against the thigh and knee in the walk so the soles stay level; the old version rotated the whole foot with the shin.
- **Arms:** shoulder -> upper arm -> elbow -> forearm -> wrist -> hand. The elbows bend in the walk and in the seated rest pose.
- **Sitting:** hips are 2 cm above the real bench seat surface, thighs go forward and slightly down, knees fold back under the seat front, and the ankles keep the feet flat. The old sit was a straight-legged fold with the soles angled.
- **Walk:** the stride drives the hip swing, the knee lifts only on the back swing, the arms counter-swing, the torso has a small counter-rotation, and the ankles cancel the leg angles. This is still a procedural placeholder, not a baked clip; the final `walk` still needs a stance-phase foot lock from the Claude animation set.
- **End beat:** when the finale finds Wren, Wren now faces the camera and **waves** instead of remaining a static standing body. The wave is a new `wave` animation state, used only at the find. The ghost Rennick is still a message voice, not a physical character, which keeps the end scene from adding an unexplained extra figure.
- **Visible cast:** eight small ambient villagers remain for the village, plus Wren. They are deliberately ordinary and sparse enough to read as a working village, not a crowd. No other human characters are visible; Rennick, the festival crowd and the wider cast stay text/model-delivery items.

Honest limits: there is still no IK or foot-plant lock; the walk is an approximation at close range. The seat contract is a simple seat-height anchor, not a full bench clip. The production clips, actual skeleton and skin maps are still the Claude character brief's work, not part of this placeholder.

Evidence after the joint pass: `docs/realism/characters/00_wren_stand.jpg`, `01_cast_line.jpg`, `02_wren_thermal.jpg`, `04_sit.jpg`, `05_walk.jpg`.
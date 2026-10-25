# The ending: the wash, the card and the walk

Status: implemented, 2026-11-15. The old hard fade and credit scroll is gone. The story now ends through the lens: eight seconds of heavy depth-of-field and post processing, a warm washed-out world, a quiet A24-style card, and then the player is on foot in the valley with the drone waiting to be clicked.

## The sequence

### 1. The lens loses the valley (0 to 8 seconds)
- `game/shaders/end_wash.gdshader` blurs the screen with an eight-direction multi-tap sample.
- The colour is desaturated, lifted and washed toward a warm paper cream. A slow vignette and fine grain come with it.
- `SensorPipeline.set_cinematic_blur()` also pushes the actual camera depth of field far past the normal lens, as a second layer under the overlay.
- The HUD and the notification bundle disappear so the picture is only the valley.

### 2. The card (7 to 22 seconds)
A black card with letterbox bars. The text arrives in slow beats:

> A HALLOWAY VALLEY STORY
>
> **T H E   L A K E   C A R**
>
> AFTER THE STORM
>
> Some lights are not the storm.
>
> Some stories arrive forty years late.
>
> The valley keeps its weather. The cabin keeps its light.
>
> **T H E   E N D**
>
> Thank you for flying the valley.

The card holds for a few seconds after THE END appears.

### 3. The walk (22 seconds onward)
The card clears. The player is standing in the world near the drone:

- **Move the mouse** to look around.
- **WASD** to walk.
- **Click the drone** to fly again.

The drone is put down on the ground where the story ended, with a small amber marker so the click target is visible. A persistent bottom hint names the three actions. The world is left still and quiet while the player walks; no timer, no failure, no forced transition.

Clicking the drone returns the HUD, the OSD and the flight controls at that spot and the sandbox continues.

## Saved completion

`StoryArc.mark_completed()` writes `completed=true` into `user://story_lake_car.cfg` as the wash starts. The case is already closed in the same save. On a later launch the story remains complete and the valley is simply the sandbox again.

## Cabin in the forest

The abandoned cabin is now in a dense wood rather than on an open edge. `World._plant_cabin_forest()` fills the old evidence clearing edge with up to 620 extra conifer and broadleaf trees in a 14 to 70 m ring, giving the cabin a 12 m clearing and keeping the dirt track and cave clear. The player flies the last leg under the treeline and the cabin appears between the trunks.

## Evidence

- `docs/realism/ending/00_end_wash.jpg`, the blurred and washed last view.
- `docs/realism/ending/01_end_card.jpg`, the full end card.
- `docs/realism/cabin_forest/00_cabin_forest.jpg`, the cabin inside the new forest ring.

## Honest limits

- The wash is partly a screen-space post shader and partly a pushed depth-of-field; it is not a physical lens.
- The card is code typography, not a designed film plate. Claude has not supplied a serif or a title card.
- The free walk is a camera, not a character: no footstep collision, no body, no animation, no interactions beyond the drone click.
- The world is frozen while walking. The walk is contemplative, not a second simulation.
- The screen-space drone marker and the click test are simple; if the drone is off-screen the marker is hidden.
- The walk camera starts from a simple behind-the-drone placement and does not push itself out of a building or a tree.
- The end text is fixed. It does not use the player's stats, photos or exact choice.
- Escape no longer quits from the end card. The player stays in the valley.

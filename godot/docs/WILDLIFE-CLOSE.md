# Wolf close-range behaviour

Status: 2026-11-15. The wolf no longer vanishes when the drone gets close. It gives a warning and then runs.

## Behaviour

| Distance | State |
|---|---|
| More than 42 m | Wary; walks/rests and stays visible |
| 42 m to about 10 m | **Hostile warning**: turns to face the drone, stiffens and takes a slow step toward it |
| About 10 m or after 2.2 s of warning | **Flees**: runs away from the drone at 8.8 m/s, still visible |
| More than 140 m away | Calms back to wary |

- The wolf is never made invisible in front of the player.
- The heat shell follows the animal in every state.
- A toast announces the warning and the break for the trees.
- The sheep also flee without disappearing; they no longer blink out inside the old 25 m hide radius.

## Mission copy

Riley now tells the player that the wolf will stand its ground and warn them before breaking for the trees, and not to chase it into the wood. The thermal sighting remains the objective.

## Test hook

`wolfclose` places the drone about 8 m from the wolf and prints the state after 150 frames:

```text
wolfclose start={ "state": "wary", "visible": true, "showing": true, ... }
wolfclose end={ "state": "flee", "visible": true, "showing": true, ... }
```

`GATE PASS (wildlifeclose)`.

## Limits

- No animal damage, gore or collision; the warning charge is a visual behaviour.
- The wolf animation uses the clip the GLB provides; if a run clip is missing it falls back to walk/idle.
- The mission still completes from the thermal sighting range; approaching closely is optional, not required.

# Rennick realization sequence

Status: 2026-11-15. The last flight no longer opens with Rennick announcing that she died. The player is guided north normally, and the realization happens when the drone reaches the cabin.

## Sequence

1. The last flight starts with Rennick directing Lou to the cabin and warning about Pike’s hunters. Nothing about her death is said.
2. At the approach waypoints she talks normally: the old plot, the cruiser, the cabin lights.
3. At the cabin approach the ghost figure is placed by the cruiser (the high-quality `rennick_1984_ghost_a` model) and starts to fade in on the far side of the 48 m human keep-out.
4. Rennick speaks:
   - “Lou? I am standing by the cruiser, by the driver door. You are looking straight through me.”
   - “Oh. You really cannot see me, can you. I have been standing here since the storm. I did not know.”
   - “Forty years. I have been dead since that storm. I thought I was still on duty. I am sorry.”
5. She comes to, takes charge again, and directs the search:
   - “All right. I have got myself together. Wren is east of the cabin, near the treeline. Use the thermal camera and find them.”
6. The cabin lights and Wren’s heat trail are revealed only now; the thermal search proceeds as before.

The ghost model is hidden if the drone comes within the same 48 m keep-out used for other humans, so it remains a distant, ambiguous figure rather than a close-up inspection.

## Files

- `game/finale.gd` — stair-step realization, timed messages, Wren reveal delayed until after the realization.
- `game/case_objects.gd` — `rennick_1984_ghost_a` placement, distance veil and ghost fade.
- `game/people_assets.gd` — latest ghost asset/material handling.
- `game/main.gd` — per-frame ghost distance update.

## Verification

- `finalerealize` dev hook: starts the sequence, shows the timed messages and then the Wren search state.
- `GATE PASS (rennickreveal)` is the final gate for this pass.
## Search recollections

After Rennick composes herself and gives Lou the thermal search direction, she keeps talking while the player searches. The beats are deliberately interleaved with the search, not another cutscene:

- the cabin lights on the winter night;
- being snowed in for days, the road and track disappearing;
- being trapped, lighting the fire and waiting;
- falling asleep after the fire died, into the storm's stillness and silence;
- hearing nothing until the hiker came through on a similar night;
- the hiker's phone, and the unexplained certainty that she could reach Lou;
- the realisation of how much time has passed;
- refusing to think about her own plight until Wren is rescued;
- one last "keep looking" direction east of the cabin.

The found beat still interrupts the sequence cleanly; nothing is queued after it.

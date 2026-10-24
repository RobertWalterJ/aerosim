# Story and gameplay test report — 2026-11-15

Tested by DSH Session B with a backup of the previous completed save.

## Automated gate

- `GATE PASS (storyprofile)` on the final tree.
- `GATE PASS (profilepass)` earlier on the player-name build.
- Full, simple, mobile and chase modes rendered; no script errors.
- Logs: `%LOCALAPPDATA%\Temp\shots\storyprofile_gate.txt` and `gate_*.txt`.

## Chapter sequence

Ran the real save state through one process per token, so the save persisted between steps:

`storystart → storydeliver → storynext` × five chapters, then `storypublish`.

Observed:

- chapter advanced 0 → 1 → 2 → 3 → 4 → 5;
- each `storydeliver` set `waiting=true`, recorded the expected evidence requirement and did not skip forward;
- each `storynext` advanced exactly one chapter;
- `storypublish` set `choice=published`;
- no script errors and no duplicate chapter state in the log.

## Unknown thread

`unknownstart` then five `unknownnext` runs advanced beats 0 → 5, with the expected delays. The last message is present and the thread did not crash.

## Finale and ending

`finalecabin` started the last flight and triggered the new jammer-down call. The current dev save reached the right state; the full ending card test remains a time-based visual test rather than a state assertion.

## Audit fixes applied

1. **Anti-drone system is now live.** `main.gd` ticks `AntiDrone.update()` and `Finale.start()` calls `AntiDrone.jammer_down_now()`. Before this, the system was dead code and the finale claimed the jammer was already down. The cabin sits inside the jammer radius, so the jammer-down call is required for the finale to be winnable.
2. **Chapter waits are skippable from the Casebook.** A **Wait for Rennick to call back** button appears while the case is waiting and calls `StoryArc.wait_for_next()`. The old design silently required up to 15 real-time hours in Story mode.
3. **Reload after the credits no longer reopens the finale.** `Finale` auto-start now refuses when `story.is_completed()`, and `StoryDirector` has an explicit completed state and next-step text.
4. **The launch-site gate is visible.** `StoryDirector.next_step()` now tells the player to drive to the ridge trailhead or north gate pull-off before the last flight.
5. **Text contradictions fixed:** the unknown message now says 1984, not 1974; the workshop/tow sticker is introduced only when the close-up chapter asks for it; the last chapter says the file is "ready to close", not already closed.
6. **Casebook spoilers removed:** Wren is not listed as a missing hiker from a fresh file, and the Wren contact no longer opens the Unknown DM.
7. **Story/jobs switch persists** in `mode.cfg`, and `StoryArc.on_photo()` refuses to complete a chapter while story/jobs is off.
8. **Callsign and optional real name** are wired through the welcome screen, chat, Casebook, story greeting and ending; the real name appears only with explicit opt-in.

## Known remaining story risks

- The final ending card is still a time-based sequence; a full hands-on run should verify the fade/card/free-walk on a real save.
- The wildlife mid-hunt reload edge case and the "fit it" wording remain to be verified against a real thermal-camera run.
- The anti-drone hunter pressure is now live but has not been hand-flown through the whole approach; the gate exercises the load path, not the forced-return path.
- The festival volunteer is text-only.

## Save handling

The previous completed save is backed up under:

```text
%APPDATA%\Godot\app_userdata\AeroSim-backup-20261024-154232
%APPDATA%\Godot\app_userdata\AeroSim-story-test-originals-20261024-154232
```

The test story state is preserved under `AeroSim-story-test-result-*` so nothing was silently destroyed.

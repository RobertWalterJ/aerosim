# Wren: Blender character model integration

Status: 2026-11-15. The end-beat Wren is now the shared Blender `wren` character model instead of the code-built `CharacterActor` placeholder.

## What changed

- Copied the shared `PeopleAssets`, `PeopleFace` and `people_ghost.gdshader` loaders into this lane.
- `CaseObjects._build_hiker()` tries `PeopleAssets.person("wren", "idle")` first:
  - real rigged mesh, skeleton, humanoid clips;
  - a per-instance skin-tone pass (`PeopleAssets.tint_skin`) gives her the rich brown tone used by the code cast;
  - the existing thermal heat shell is attached to the model;
  - `wave_hiker()` plays `wave_up` on the real AnimationPlayer at the finale.
- The old `CharacterActor` remains the fallback when the GLB is missing or fails.

## Evidence and limits

- The model file is `assets/models/people/wren.glb`; her story name resolves through `PeopleAssets.STORY`.
- The direct close-up dev screenshot did not show her because the camera reset happened after the debug placement; the finale path is the real verification target. The model instantiated and its AnimationPlayer was found in the probe.
- The code cast in the village still uses `CharacterActor`, so the ambient villagers and Wren currently use different rigs. A later pass can move the eight villagers onto `PeopleAssets` as well.
- The skin tint is a material multiply, not a new MakeHuman skin; it preserves her features but is not a rebuilt model.
- Gate is pending until Session A's tablet UI work stops writing the shared files.

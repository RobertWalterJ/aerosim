# AeroSim Desktop Edition

Browser-based quadcopter flight simulator (Three.js, TypeScript, Vite).

## Run
1. Install Node.js 20 or newer.
2. In this folder: `npm install`, then `npm run dev`.
3. Open the address Vite prints. Useful URL options: `?quality=low|medium|high|ultra`, `?airframe=...`, `?teleport=x,y,z,headingDeg,gimbalDeg` (or `?teleport=pilot`), `?wind=calm|light|breezy|strong`, `?env=0`, `?drone=legacy`, `?pilot=0|simple`, `?chase=1`.
4. Tests: `npm test` (physics, aerobatics, assets).

Controls: flight modes 1 to 4 (4 is aerobatic, tricks on J K N M), gimbal Q/E tilt, `,` `.` pan, T level, Y look down, Z wind level. Full list: `docs/flight-and-camera.md`.

## Folders
- `src/` code: core, physics, world, rendering, audio, ui, game, util
- `docs/` specification (SPEC_v2)
- `tests/` headless physics tests and screenshot script
- `assets/opus-incoming/environment` drop Opus-made environment modules here (grass, hedges, fences, clutter)
- `assets/opus-incoming/drones` drop Opus-made drone models here
- `assets/reference` reference images
- `assets/blender/pilot.blend` editable pilot model; `tools/blender/pilot/` rebuilds `public/models/pilot.glb`
- `_obsolete/` superseded files

All assets are generated in code at load time (see `src/world/`), except the pilot, which is a Blender-built GLB. Asset docs: `docs/assets/`.

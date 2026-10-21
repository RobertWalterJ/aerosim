# AeroSim Desktop Edition

Browser-based quadcopter flight simulator (Three.js, TypeScript, Vite).

## Run
1. Install Node.js 20 or newer.
2. In this folder: `npm install`, then `npm run dev`.
3. Open the address Vite prints. Useful URL options: `?quality=low|medium|high|ultra`, `?airframe=...`, `?teleport=x,y,z,headingDeg,gimbalDeg`.

## Folders
- `src/` code: core, physics, world, rendering, audio, ui, game, util
- `docs/` specification (SPEC_v2)
- `tests/` headless physics tests and screenshot script
- `assets/opus-incoming/environment` drop Opus-made environment modules here (grass, hedges, fences, clutter)
- `assets/opus-incoming/drones` drop Opus-made drone models here
- `assets/reference` reference images
- `_obsolete/` superseded files

All current assets are generated in code at load time (see `src/world/`).

# Claude asset integration — quality pass

Status: 2026-11-15. This pass brings the latest Claude-authored art into `lane/notify` instead of leaving the older shared library in place.

## Sources

The latest work was taken from the current Claude worktrees and `AeroSim` main:

- `AeroSim` main — current `assets/models` library and the latest `people_assets.gd`, `people_face.gd`, `people_ghost.gdshader`.
- `AeroSim-antidrone` / `AeroSim-avatars` / `AeroSim-rennick` — rebuilt Wren, Rennick and the story cast, plus the latest avatar portraits.
- `AeroSim-wreckvan` — `anne_car_wreck_a.glb` and `police_dive_van_a.glb`, and the wreck textures.
- `AeroSim-villagefix` — the plinth fix for buildings on sloped ground.

## What is now in the lane

- **People:** latest Wren and Rennick models, the rebuilt story cast and the current people loader/shader. Wren still uses the distance veil and thermal signature; the village cast remains deliberately invisible.
- **Avatars:** the app now uses Claude’s real portrait PNGs in DroneBudz and the Casebook instead of initials. Lou has a portrait derived from the `avatar_you` art.
- **Story vehicles:** the latest vehicle library is copied in, including Anne Voss’s lake wreck and the police dive van. The dive van and wreck are placed at the boat launch; their full armature/material shaders are not driven yet.
- **Village:** cottages now get a ground plinth so walls reach the terrain on slopes. The higher-detail pub/shop/garage shells and village labels remain from the earlier pass.
- **Animal models:** the latest rigged animal GLBs replace the older library copies; the wildlife objects try to play their idle/graze animation where a clip exists.

## Verification

- `GATE PASS (claudequality)` after the asset import.
- Latest chat screenshot shows the new avatars: `latest_chat.png`.
- Model files are committed; not pushed.

## Honest limits

- Copying the latest assets does **not** mean every model is wired to its intended runtime loader. The high-end `VehicleAssets` system (armature wheels, doors, LODs, wreck shaders) lives in another lane and is not merged into this one; the wreck and dive van are currently direct GLB placements.
- The latest people loader is used, but the world still hides humans close-up by design.
- Animal clips play only where the GLB exposes a matching clip; the herd/flee movement remains the lane’s own simple system.
- There is a large asset drop and conflicting art generations across lanes; a later full merge of `main` will still need conflict review.
- Some texture sidecars could not be overwritten from the source tree due to file permissions, so they remain at the lane’s current versions.

# Spec for DSH: volumetric-looking grass and advanced ground surfaces (efficient, phone-safe)

Written by Claude 2026-11-16. Photoreal direction. Look first at game/grass.gd (MultiMesh blades, carpet layer), game/shaders/ground.gdshader (uAsphalt block), assets/textures/README.md.

## Grass: layered, cheap, looks volumetric
1. **Three bands by distance, blended by a dither fade (no popping):**
   - 0 to 8 m: real blade geometry (MultiMesh, 3 to 5 tapered segments, curved, per-blade tint, root-to-tip gradient, translucent backlight, wind sway from g_wind). Keep the existing carpet layer.
   - 8 to 40 m: **crossed cards** (2 to 3 quads per clump) using an alpha-tested clump atlas (CC0 photographed grass from Poly Haven, 4 variants incl. seed heads, clover, dry stalks), same wind and tint hooks. Fewer instances, bigger clumps.
   - 40 m and beyond: no geometry. The ground shader paints grass: tiling macro albedo, per-pixel noise breakup, fake blade streaks by a stretched noise along the wind, darker AO in the roots. This is where the volume illusion comes from: **self-shadow gradient** (dark at the soil, bright at the tip, bright rim light when the sun is behind).
2. **Fake volume tricks (very cheap):**
   - Parallax shell layers on the ground (4 to 6 horizontal alpha-cutout shells, the fur.gdshader approach, only within 6 m; reuse game/shaders/fur.gdshader ideas).
   - Per-instance height from a noise map, taller near fences, trees and stones (the same field mask used for unmown patches), shorter on paths and wheel ruts.
   - Flatten under the drone (g_wash) and under footfall/vehicle tracks.
3. **Efficiency:** one MultiMesh per chunk with frustum culling and a 25 m chunk size, instance counts per quality tier (phone: carpet 1/3, no mid band shells), all colour variation in shader (no extra materials), alpha-to-coverage or dithered alpha not blend, a single shared texture atlas. Measure frame time with the gate screenshot tokens and report a table.
4. **Acceptance:** screenshots at 2 m, 10 m, 40 m, 100 m in golden hour, overcast, backlit; no visible band edges; phone mode at 60 fps target on the S23 is untested, so provide a menu switch "Grass detail" Low/Normal/High.

## Cracked pavement and other advanced surfaces
1. **Material stack (Forward+ and Mobile safe):**
   - Triplanar PBR albedo/normal/ARM from photographed CC0 asphalt/concrete/cobble (Poly Haven), 8 m authored tile, de-tiled with a second larger-scale noise-rotated sample.
   - **Height-blend** between layers using a height map (dirt in the cracks, moss at edges, gravel spill) rather than a plain alpha mix: `mix by smoothstep(height + noise, threshold)`.
   - **Parallax occlusion** only on Forward+ and only on near road (StandardMaterial3D heightmap_enabled with deep parallax, 4 to 8 layers); on mobile use the baked normal only.
2. **Cracks, patches, stains as DECALS** (Godot `Decal` nodes, max about 24 visible, distance fade 30 m): crack networks (4 variants), tar-snake repairs, patched rectangles, oil stains, puddle rims, manhole rust, tyre marks. Authored as albedo+normal+ORM atlas, alpha masked. Place by a seeded scatter along roads (more at edges and junctions); this also fits Worldsmith's surface-wear layer later.
3. **Wetness:** the existing g_wet drives roughness down and darkens albedo; add puddle masks from the height map low points with a flat-water normal and a sky reflection.
4. **Verification:** the 3 x 3 tiling sheet and 1:1 close-up the road brief (docs/CLAUDE-ROAD-SURFACE-ASSETS.md) already asks for.

## Order
Road surface textures first (brief exists) then the decals, then the grass bands. Claude can build the clump atlas and the decal atlases (Blender plus numpy) if Robert asks, as one `[REQUEST CLAUDE]` with names; everything else is shader and placement code for DSH.

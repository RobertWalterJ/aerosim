# AeroSim (Godot) logic notes

The memory for any agent starting cold. One section per system: inputs, decisions, outputs, where the code lives, which test covers it.
Update this in the same commit as any logic change. Realism pass stages are listed in `SPEC-REALISM-PASS.md` section 4.

## Realism pass status
| Stage | State |
|---|---|
| 1.5 Motion blur | not started |
| 1.1 Bloom and glare, 1.2 Colour looks | not started |
| 1.3 Compression, 1.4 Lens character | not started |
| 2.1 Contact shadows, 2.2 Cheap GI | not started |
| 2.3 Volumetric light, 2.4 Sky clouds | not started |
| 2.5 Water | not started |
| 3.1 Trees | not started |
| 3.2 Far hills forest, 3.3 Grass and ground | not started |
| 3.4 Gravestones, 3.5 Drone detail | not started |

## Questions for Claude and the owner
(none yet)

## Systems (short)
- **Sensor camera** (`game/sensor_pipeline.gd`, shaders in `game/shaders/`): HDR scene viewport, metering (CPU exposure `_log_e`), bloom, sensor, ISP, codec, blit. `simple` mode (phone default) skips all passes. Test: `-- apstest`, screenshots with `simple` and without.
- **Sun and moon** (`game/solar.gd`, `main.gd` `_update_celestial`): real clock or set time. Sky in `shaders/sky.gdshader`.
- **Drone shadow and cloud shadow** (`game/drone_shadow.gd`, `shaders/cloud_shadow.gdshaderinc`, globals `g_cloud`, `g_ds*`): applied in ground, grass, foliage shaders per vertex or pixel.
- **Depth of field and autofocus** (`sensor_pipeline.gd`, `focus_box.gd`): `CameraAttributesPractical`, thin-lens maths, tap to focus.
- **World** (`terrain.gd`, `world.gd`, `hedgerow.gd`, `lake.gd`, `far_hills.gd`, `ambient_particles.gd`, `assets.gd`).
- **Menu** (`hud.gd`, `menu_style.gd`, `drone_schematic.gd`, `keyboard_guide.gd`).
- **Icons** (`hud_icons.gd`, `round_button.gd`, `shutter_button.gd`).
- **Phone**: `export_presets.cfg`, release steps in `SPEC-REALISM-PASS.md` section 7.

# Android OS UI pass: real tablet kit, Material launcher and system chrome

Status: 2026-11-15. This is the Lead's implementation pass on top of DSH Session A's audit (`docs/ANDROID-OS-UI-SPEC-2026-11-15.md`). It moves the in-game tablet from a field-notebook drawing to a recognisable Android tablet OS without losing the game app names. DSH Session A's follow-up on shared task `task-4` is appended at the end of this file; the "Honest limits" list below is annotated where that follow-up changed it.

## What changed

### Real tablet art kit

The 215-file, 4.4 MB tablet UI kit from the shared AeroSim lane is now in `assets/ui/tablet/`:

- 512/128/64/44 app icons;
- the transparent 1280x720 / 1920x1080 device frame with bezel and camera cutout;
- status bar signal, Wi-Fi, battery and notification glyphs;
- dock tray, page dots, wallpaper vignette, controls, switches, sliders, dials and Inter.

`TabletIcon` now loads the real 128 px app icons instead of drawing them. The ten app surfaces that use it get the real painted icons, and the home, dock and app switcher all share them.

### Status bar and frame

- A device-frame overlay gives the screen a black bezel, speaker slot and camera cutout.
- Status bar now shows a real clock, **real signal/Wi-Fi/battery glyphs** and the battery percentage; the old `LINK · 100%` text is gone, including the `_refresh()`/`set_battery()` regression.
- Carrier branding is removed from the system bar.
- The frame is selected from the real window size and only used on a 16:9 window; it will not distort a 16:10 tablet.

### Launcher

- The app grid is now **5 columns** with 64 px real icons and one-line labels; category captions are gone.
- The dock has five app icons, no labels, and no Home/Recents text buttons.
- Launcher page dots use the kit art.
- The wallpaper scrim is reduced from 50% to 18%, so the valley photograph reads as a wallpaper rather than a black overlay.
- The giant field-note card remains as a game-specific Android-style widget; the game has no stock widgets to replace it with.

### Navigation and system UI

- Bottom navigation now uses 48 px back, home, recents and put-away icon buttons instead of text.
- Notification layer is raised **above `PhoneOS` (34)**, so heads-up cards and the shade are visible while the tablet is open. Before this pass they rendered behind the phone.
- The notification shade now has a **Quick Settings row**: Wi-Fi, Bluetooth, Do Not Disturb and Battery Saver tiles, with real status glyphs and Material pressed states.

### Typography and Material palette

- Inter is now the phone/tablet font, including `PhoneNotes` weights.
- `UniverseUI` is shifted from the field-kit pine/brass palette to Material dark surfaces (near-black surfaces, pale blue primary, white/grey text, Material green/error roles). App names, story strings and content are unchanged.

## Evidence

- `docs/realism/android_os/00_launcher.jpg`
- `docs/realism/android_os/01_casebook.jpg`
- `docs/realism/android_os/02_shade_quick_settings.jpg`
- `docs/realism/android_os/03_recents.jpg`

## Honest limits

- ~~The **Map** app has no kit icon in the 12-icon set, so it still uses the code-drawn map glyph; adding one needs the sibling `tools/ui_art/gen_icons.py` generator.~~ **Done in the Session A follow-up:** a Map tile was generated in the same family and is wired into `TabletIcon`.
- The launcher is a 5-column Android-like home, but not a full Android launcher: there is **no page-2 widget page and no swipe page transitions**. **Session A added a real app drawer with search**; paging and swipe transitions are still open.
- Quick Settings tiles are visual toggles only; Wi-Fi/Bluetooth/DND do not change the game systems. Battery Saver is not wired to the drone battery.
- The device frame is 16:9, while modern Android tablets are 16:10. The frame is disabled on non-16:9 windows rather than distorted.
- ~~The launcher still uses fixed pixel sizes rather than a full `u = height / 720` scale system; the layout is correct at 1280x720 and safe at the frame edges, but 1080p/16:10 still needs the scale pass.~~ **Done:** `PhoneOS` now has a `u` unit (`_compute_u()`, `_status_h()`, `_nav_h()`, `_resize_insets()`), so the status bar, app insets, nav bar and dock scale; the engine's canvas stretch handles 1080p.
- The wallpaper is only 1024x683, so it cannot be photoreal at 1080p+.
- ~~No real Android nav/QS glyphs are in the kit; back is a text arrow and the quick-setting glyphs are repurposed status icons. A Material Symbols set would be needed for stock accuracy.~~ **Done:** a Material-style glyph set (`assets/ui/tablet/glyphs/`) was generated for navigation, the drawer, the HUD entry points and the quick settings; it is wired in.
- ~~The dials are still code-drawn; the kit faces and needles are not wired.~~ **Done:** `TabletDial` now draws the kit faces, needles and the battery fill.
- Apps are Material-coloured but still use the game's card layout rather than Google Material components.

## Session A follow-up (2026-10-24, shared task `task-4`)

This is the completion pass on the six remaining items in the list above. Scope: `game/phone_os.gd`,
`game/tablet_icon.gd`, `game/tablet_dial.gd`, `game/phone_notes.gd`, `game/hud.gd`, `game/main.gd` (HUD signal wiring),
`assets/ui/tablet/` and this document. No model/world/traffic files, no user saves, no push.

### Done in this pass

1. **Map icon.** Generated `icons/icon_map.png` (512) + native 128/64/44 exports + adaptive `bg/fg` layers + mono
   exports, in the same folded-map/pin/olive-tile family as the other twelve. `TabletIcon.ANDROID_ICONS` maps
   `"map": "map"`, so home, dock, Recents and app bars use the real tile.
2. **Icon export selection.** `TabletIcon` now loads the native export nearest the display size (44 <= 52 px, 64 <= 96,
   128 above) with a static cache and a bucket re-check on resize. The 128-to-40/48 downscale aliasing in the dock,
   Recents and small headers is gone.
3. **Dial kit wiring.** `TabletDial` draws `dial_wind_face` / `dial_battery_face`, the separate needles and the three
   battery fills. The battery arc is a textured annulus sector following the kit geometry (150 degrees, 240 clockwise,
   r 176/512, width 32/512), so it reveals smoothly at any size; the battery needle follows the arc angle and the wind
   needle follows the compass bearing (bearing minus 90 screen degrees, so 250 degrees points WSW as the face expects);
   the live number and caption are Inter on top. Code-drawn fallback kept if the kit is absent.
4. **App drawer.** New full-screen drawer over the faintly visible wallpaper with an "All apps" title, a 48 dp Material
   search pill with live filtering, an alphabetical four-column grid, and back/close. The kit's search-pill art is a
   single fixed 640x96 lozenge that cannot be nine-patched at 48 dp without bulging ends, so the pill surface is a
   StyleBoxFlat and only the magnifier glyph comes from the kit. Opens from the "All apps" button under the home grid.
   The fake page dots were removed (the home is one page plus the drawer); the existing app switcher is unchanged.
   Home badges became Android red count pills on the icon's top-right instead of amber captions under the name.
5. **HUD touch entry.** `Hud` gained `phone_requested` / `notes_requested` signals and two 40 dp glass glyph buttons
   (tablet + bell) in the right-hand utility column under the camera add-ons, hidden while paused and on the welcome
   screen, placed with the existing HUD `u` scale. They sit below the OSD top bar so they never cover the camera
   ISO/EV/WB readout. `main.gd` connects them to `phone_os.toggle()` and `phone_notes.toggle_shade()`, so the tablet and
   shade are reachable without a keyboard.
6. **`u` scale/insets pass.** `PhoneOS` gained `_compute_u()` (height/720), `_status_h()` (28 dp), `_nav_h()` (56 dp) and
   `_resize_insets()` connected to `Viewport.size_changed`; status bar, app insets, nav bar and dock now scale. The frame
   stays 16:9-only and uses the physical window size.
7. **Material nav/QS glyphs.** Generated `glyphs/` (nav_back, nav_home, nav_recents, nav_phone, nav_bell, nav_allapps,
   qs_bluetooth, qs_dnd, qs_airplane, qs_rotation, qs_flashlight, qs_battery_saver, qs_screen_record, qs_gear, qs_power,
   qs_mic, qs_search) at 64 and 128 px. Wired into the bottom nav bar, the drawer, the HUD buttons and the shade quick
   settings; the shade QS tiles and its header actions now use the shared Material roles (primary container tint when on,
   `UniverseUI.AMBER` for text actions) instead of stray one-off colours. Reproducible via
   `assets/ui/tablet/gen_lane_assets.py`.
8. **Wallpaper treatment.** The kit `polish/wallpaper_vignette.png` overlays the photo and the full-height 0.72 gradient
   became a 96 dp top scrim, so the home wallpaper reads bright instead of dusk-dark.
9. **Device-frame safe area.** Every OS surface is now parented under a `Screen` control inset by the measured 18 px
   bezel (`_apply_frame_inset()`), and an opaque matte sits under the bezel ring (`_add_bezel_matte()`). Before this the
   frame's opaque bezel covered the status clock and the screen edges, and HUD edge text could peek through the bezel
   ring. The design unit starts at 1.0 in `_build()` because the viewport can still report the physical window size
   during `_ready` before the canvas stretch is applied; `_resize_insets()` refreshes it once the game is up.

### Corrections on top of the first Session A draft

The first draft of this section was written before the work was run in the engine. The completion pass fixed these
defects it found on screenshot review:

- **Wind needle bearing.** The kit needle points up, but the first draft fed the compass bearing straight into the
  screen-angle helper, so every bearing was drawn 90 degrees clockwise of truth. The call now passes `heading - 90`.
- **HUD entry discs.** They were placed beside the pause glyph in the OSD top bar, where two extra discs covered the
  camera ISO/EV/WB readout. They moved to the right-hand utility column under the camera add-ons. They were also missing
  from `Hud.set_landing()` / `set_paused()`, so they stayed visible on the welcome screen; that is fixed.
- **Drawer search pill.** The kit pill is one fixed 640x96 bitmap with a 48 px cap radius; nine-patched at a 48 dp row
  height its rounded ends bulged. The surface is now a Material `StyleBoxFlat` pill with the kit magnifier glyph.
- **Drawer grid.** Four centred columns of 120 dp cells (was five left-aligned), so the labels no longer ellipsize.
- **Shade palette.** The quick settings and the shade's "Open DroneBudz" / "Clear all" actions had stray brass and blue
  one-off colours; both now use the shared `UniverseUI` Material roles.
- **Recents.** The app switcher was a two-column grid that clipped the seventh app (Map) at 720p; it is now three
  columns with shorter descriptions, and its "Open" buttons shrink to their 54x30 dp size instead of stretching the
  full card height.
- **Frame export selection.** Now also selects the 2560x1440 bezel above 2400 px wide, so 4K windows stay sharp.
- Removed unused badge label declarations left by the badge rewrite.

### Evidence

- Parse check: `godot --headless --check-only --script res://game/<file>.gd` on all six edited scripts, exit 0, no errors.
- Headless boot `--quit-after 5`: no script errors.
- Gate: **GATE PASS (task4b)**, 2026-10-24, `tools/gate.ps1 -Tag task4b`, run on the final tree that was committed.
  All four render modes (full, simple, mobile, chase) produced their screenshots with no script errors; the autopilot
  test printed `after takeoff agl 2.20 m` and `rth finished after 48.0 s, state 4, 398.0 m from home, agl 22.60 m,
  crashed=false`. Logs and shots in `%LOCALAPPDATA%\Temp\shots\task4b_*.png` and `gate_*.txt`.
- Screenshots (`docs/realism/android_ui/`): `00_launcher_home.jpg` (frame, status bar, Map tile, red badges, kit dials),
  `01_app_drawer.jpg` (All apps, search pill, four-column grid), `02_recents.jpg` (all seven apps),
  `03_quick_settings_shade.jpg` (QUICK SETTINGS tiles and notification group), `04_dial_kit.jpg` (kit faces, needle at a
  250 degree bearing, 100 percent battery fill), `05_hud_touch_entries.jpg` (tablet and bell discs under the camera
  add-ons on the flight screen, clear of the OSD readout).
- Resolution spot checks: screenshots at a 1920x1080 window and at a 1600x1000 (16:10) window. The canvas stretch keeps
  the 16:9 layout at 1080p, and the 16:10 window keeps the same layout with the frame correctly disabled; the status bar,
  app insets and nav bar follow the taller viewport through `_resize_insets()`. The home label width was raised to 100 dp
  after these checks so "VidTube Studio" fits on the launcher.

### Still open after this pass

- No gesture navigation (pill, edge back, swipe-up home/Recents, pull-down shade); nav is still 3-button.
- No two-pane Android 12L shade: no shade clock/date header, brightness slider, expandable QS grid, media notification,
  per-app grouping or swipe-to-dismiss. The four QS toggles remain visual only except where a safe game hook exists.
- No Material motion or ripple: app/drawer/shade transitions are still instant; no confirm dialogs, snackbars or undo.
- App interiors are unchanged (game card layouts inside the Material surfaces); per-app app bars/back arrows from the
  spec are still a separate pass. `_apps` insets are now correct, so the space is reserved.
- No page-2 widget page or swipe page transitions, folders, wallpaper picker, At a Glance search bar or Material You
  dynamic colour (dynamic colour would replace the game palette and was deliberately not done).
- No new app content art: avatars, Facade product photos, video thumbnails, Casebook paper/stamps, Job badges are still
  missing (`docs/MODEL-STATUS.md`: 0 of 13 briefs). Wallpaper is still 1024x683, soft at 1080p+.
- The kit art is painted rather than flat stock-Android, and the frame is a 16:9 overlay, not photoreal tablet hardware.

Committed locally on `lane/notify` (not pushed); the commit hash is reported to the Lead.

# Android OS UI pass: real tablet kit, Material launcher and system chrome

Status: 2026-11-15. This is the Lead's implementation pass on top of DSH Session A's audit (`docs/ANDROID-OS-UI-SPEC-2026-11-15.md`). It moves the in-game tablet from a field-notebook drawing to a recognisable Android tablet OS without losing the game app names.

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

- The **Map** app has no kit icon in the 12-icon set, so it still uses the code-drawn map glyph; adding one needs the sibling `tools/ui_art/gen_icons.py` generator.
- The launcher is a 5-column Android-like home, but not a full Android launcher: there is **no page-2 widget page, no swipe page transitions and no app drawer with search** yet. The app switcher covers app launching.
- Quick Settings tiles are visual toggles only; Wi-Fi/Bluetooth/DND do not change the game systems. Battery Saver is not wired to the drone battery.
- The device frame is 16:9, while modern Android tablets are 16:10. The frame is disabled on non-16:9 windows rather than distorted.
- The launcher still uses fixed pixel sizes rather than a full `u = height / 720` scale system; the layout is correct at 1280x720 and safe at the frame edges, but 1080p/16:10 still needs the scale pass.
- The wallpaper is only 1024x683, so it cannot be photoreal at 1080p+.
- No real Android nav/QS glyphs are in the kit; back is a text arrow and the quick-setting glyphs are repurposed status icons. A Material Symbols set would be needed for stock accuracy.
- The dials are still code-drawn; the kit faces and needles are not wired.
- Apps are Material-coloured but still use the game's card layout rather than Google Material components.

## Next UI work

1. Add the missing Map icon through the kit generator.
2. Wire `TabletDial` to the kit faces/needles/fills.
3. Add a true app drawer and a second launcher page.
4. Add HUD touch entry for the phone and notification shade, not just Tab/N.
5. Add the `u` scale pass for 1080p and 16:10.
6. Add quick-setting state hooks where they make game sense (DND hides heads-up, battery saver reports drone battery, Wi-Fi shows link state).

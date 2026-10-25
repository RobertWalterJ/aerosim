# Android OS UI spec for the in-game tablet

Status: 2026-11-15, audit and implementation spec for the Halloway Valley tablet OS.
Scope: the system chrome (status bar, navigation, launcher, Recents, notification shade, quick settings, dialogs) and the app chrome of all seven game apps. Read-only audit: no game code, assets or saves were changed. The only write from this session is this file.

Audience: the Lead and session B, who own `game/phone_os.gd`, `game/ui_theme.gd` and the app files.

## 0. Audit basis and live workspace state

### What was audited

- Code: `game/phone_os.gd` (708 lines), `game/ui_theme.gd` (203), `game/tablet_icon.gd`, `game/tablet_dial.gd` (77), `game/phone_notes.gd` (877), `game/chat_app.gd` (436), `game/studio_app.gd` (430), `game/casebook_app.gd` (578), `game/marketplace_app.gd` (328), `game/map_app.gd` (274), `game/photo_library.gd`, `game/jobs.gd`, `game/hud.gd`, `game/main.gd`, `game/menu_style.gd`, `project.godot`.
- Screenshots: `docs/realism/phone_ui/00_home.jpg`, `01_casebook_overview.jpg`, `04_chat.jpg`; `docs/realism/tablet/00_tablet_desktop.jpg`, `01_recents.jpg`; `docs/realism/phone/10_ui_pass_home.jpg`, `12_ui_pass_chat.jpg`, `13_ui_pass_studio.jpg`, `18_facade_home.jpg`; `docs/realism/ui_review/04_notifications.jpg`; the kit contact sheet in the sibling checkout `AeroSim/godot/docs/realism/models/tablet_ui_final_views.jpg`.
- The real kit: measured with Pillow, not just read.

### The kit is already in this lane

The brief said the kit lives in the sibling checkout. It has already been copied into this lane:

- `godot/assets/ui/tablet/` — 215 files, 4.4 MB, with Godot `.import` files present for every PNG and for `Inter.woff2`.
- The sibling `AeroSim/godot/assets/ui/tablet/` has the same art (214 files, 4.07 MB).
- The generator that made it is in the sibling checkout only: `AeroSim/godot/tools/ui_art/` (`build_all.py`, `gen_icons.py`, `gen_dials.py`, `gen_controls.py`, `gen_sheets.py`, `glyphs.py`, `lib.py`, `fonts/Inter.woff2`). It is not in the notify lane.

Consequence: there is no copy step and no waiting on art. The work is **wiring, sizing, layout and system behaviour**. This also means three documents are now stale: `docs/APP-SCREENS-AUDIT.md` ("none of the Claude icon pack is present"), the kit README ("Nothing in the game loads these yet") and `docs/UI-STYLE.md` ("the icons are drawn in tablet_icon.gd"). Update them when the wiring lands.

### In-flight workspace changes (this is the state the spec targets)

At about 13:30 today, while this audit was running, `game/phone_os.gd`, `game/tablet_icon.gd` and `game/ui_theme.gd` gained uncommitted edits (the Lead's kit wiring, `git status`: `M godot/game/phone_os.gd`, `M godot/game/tablet_icon.gd`, `M godot/game/ui_theme.gd`, `?? godot/assets/ui/tablet/`):

- `phone_os.gd`: status bar now appends three `status/64` kit glyphs at 16 px; `_add_device_frame()` added; `TabletIcon`/font wiring follows.
- `tablet_icon.gd`: `ANDROID_ICONS` maps game keys to kit names and `_draw()` blits `icons/128/icon_<app>.png`.
- `ui_theme.gd`: `make_theme()` loads Inter from `assets/ui/tablet/Inter.woff2` as the default font.

The screenshots above pre-date these edits. Line numbers in this document are from the current working tree and will drift as the Lead keeps editing; function names are the stable reference.

**Two bugs introduced by the in-flight edits that must be fixed before anything else:**

1. `phone_os.gd` line 681 (in `_refresh()`) and line 689 (in `set_battery()`) still set `_status_sig.text = "LINK   ·   %d%%"`. The new status bar sets it to `"LINK"` in `_build()` and adds three kit glyphs after it, so every frame the old text comes back: the bar shows `LINK · 74%` **and** a battery glyph. Delete the text and put the percentage beside the battery glyph (see section 2).
2. `_add_device_frame()` decides `wide := get_viewport().get_visible_rect().size.x > 1600.0`. Under `window/stretch/mode="canvas_items"`, the logical viewport is 1280 wide at 16:9, so this is never true: it always picks the 1280x720 frame. It also uses `STRETCH_SCALE`, so on a 16:10 window (1280x800 logical under `aspect="expand"`) the bezel and corners are stretched elliptical. See sections 1.4 and 10.

## 1. Canvas, units and safe areas

### 1.1 Engine facts that fix the numbers

`project.godot` has `window/size/viewport_width=1280`, `height=720`, `window/stretch/mode="canvas_items"`, `aspect="expand"`, `handheld/orientation=4` (sensor landscape).

So:

- At 16:9 (1280x720 window or 1920x1080 monitor), the Control coordinate space is **always 1280x720 logical pixels**, and a 1080p display simply scales it by 1.5. The same constants work on both.
- At a non-16:9 window (16:10 tablet, 1280x800 logical), height stays 720 and width grows to 1280 * (aspect). The HUD already handles this with a scale unit:

```gdscript
# hud.gd::layout_for(), line 343 - the pattern to copy
var u := maxf(0.6, minf(frame.size.x / 1280.0, frame.size.y / 720.0))
```

`phone_os.gd` does **not** use a `u` factor. It hard-codes 40 px status bar, 54 px bottom bar, 44 px home margins, 96 px icons and a 320 px widget. That is the root cause of most geometry drift. Every number in section 1.3 is a 720-baseline `dp`; in code it must be multiplied by `u`, where `u = viewport_height / 720.0` (1.0 at 720p, 1.5 at 1080p, 1.111 at 1280x800).

Reference device model: treat 1280x720 as an 8-inch **mdpi** Android tablet, so **1 dp = 1 px** at 1280x720. This is the mapping that makes Android's published dp sizes land on readable numbers here. At 1080p native, multiply by 1.5. Do not mix dp and px in the same helper.

### 1.2 Design grid and scale table

All values are logical px at 1280x720 and at a native 1920x1080 viewport (x1.5). If the project keeps its 1280x720 viewport - recommended - only the first column exists in code and the engine scales it.

| Token | 1280x720 | 1920x1080 native | Notes |
|---|---|---|---|
| Screen (no frame) | 1280x720 | 1920x1080 | full viewport |
| Screen (frame on, from kit) | inset 18 all sides = 1244x684 | inset 26 = 1868x1028 | measured, section 1.4 |
| Status bar height | 24 | 36 | Android tablet 24 dp |
| Status bar side padding | 16 | 24 | |
| Status text (clock) | 13 | 20 | Inter medium 500 |
| Status glyph | 18 | 27 | use 64 export, not 32 |
| Status glyph gap | 8 | 12 | |
| Nav gesture inset | 24 | 36 | bottom |
| Gesture pill | 108 x 4, 8 from bottom | 162 x 6 | radius 2 |
| 3-button nav height | 48 | 72 | only if 3-button mode |
| 3-button glyph | 24 | 36 | |
| App bar (top) | 56 | 84 | Material 3 medium top app bar |
| Large/collapsing app bar | 64 | 96 | optional, Casebook |
| Tab row (in app) | 48 | 72 | |
| Content side margin | 16 | 24 | apps; launcher uses 24 |
| List item 1-line / 2-line | 56 / 72 | 84 / 108 | |
| Section header block | 48 | 72 | |
| Touch target minimum | 48 | 72 | Android hard minimum |
| FAB | 56 | 84 | 16 radius |
| Extended FAB height | 56 | 84 | 16 radius, 20 side padding |
| Card radius | 16 | 24 | |
| Widget radius | 24 | 36 | Android 12L+ widgets |
| Dialog radius | 28 | 42 | |
| Bottom sheet top radius | 28 | 42 | |
| Snackbar height | 48 | 72 | radius 4 |
| Ripple / state layer | 12% white, 200 ms | same | |
| Divider | 1 | 1.5 | only where a divider is needed |

### 1.3 Safe area and bezel

Measured from the real kit (`frame/tablet_frame_*.png`, Pillow): the art is a 16:9 chassis with an opaque bezel and a fully transparent screen area, no intrusion into the screen.

| Frame art | Bezel all sides | Screen rect | Screen corner radius |
|---|---|---|---|
| 1280x720 | 18 px | 1244x684 | ~16 px |
| 1920x1080 | 26 px | 1868x1028 | ~23 px |
| 2560x1440 | 35 px | 2490x1370 | ~31 px |

Bezel = 2.5% of height; corner radius = 2.2% of height. There is a camera/speaker slot in the **top bezel only**; it never enters the screen, so it adds no cutout safe area. There is no punch-hole.

Safe-area rules:

- Content origin is the **screen rect**, not the window: with the frame on, add the bezel to every inset. The status bar starts at screen top (`18` at 720), not at window 0.
- Rounded screen corners mean the four 16 px corner areas are not usable for text or buttons. Keep the 48 px touch targets and any text at least 16 px inside a corner: the status clock at `x = screen_left + 16` and `y = screen_top + 3` is fine; a back arrow at `y = screen_top` is not.
- The frame is only correct at 16:9. For a 16:10 window, either (a) turn the frame off, or (b) letterbox the 16:9 UI inside the window and draw the frame around the letterboxed rect. Never stretch it.
- Choose the frame export from the **physical window size**, not the logical viewport: `DisplayServer.window_get_size()`. Use 2560 art above 2400 px wide, 1920 art above 1600, else 1280. That also gives sharper bezels on a 4K monitor.
- **Honest limitation:** a 16:9 tablet is not a modern Android tablet. Pixel Tablet and Galaxy Tab are 16:10, iPad is 4:3. A 16:9 device frame reads as a TV or a cheap tablet. Recommended default: frame **off**, UI edge-to-edge like an Android screenshot. Keep the frame as an optional "device view" toggle for the Lead's realism screenshots. It cannot make the hardware photoreal (section 11).

### 1.4 App content area

When the OS is open, define one content rect and give it to every app:

```
screen    = Rect2(bezel, bezel, w - 2*bezel, h - 2*bezel)      # bezel = 0 if frame off
status    = Rect2(screen.x, screen.y, screen.w, 24*u)          # 24*u tall
nav       = 24*u gesture, or 48*u 3-button
app_bar   = 56*u tall, immediately below status
content   = screen, y from app_bar.bottom to nav.top
```

No app may draw above the status bar or below the nav bar. The current `_apps.offset_top = 38.0` / `offset_bottom = -54.0` is the right idea with wrong numbers and no `u`.

## 2. Status bar

Current state: `phone_os.gd::_build()` lines 110-130 (40 px tall, 30 px side margins, time left, `HALLOWAY VALLEY` centred, `LINK · %` right, three 16 px kit glyphs appended). Wallpaper shows through it in every app (visible in `docs/realism/phone_ui/01_casebook_overview.jpg`). It is the single most "not Android" element after the launcher.

### 2.1 Layout

| Element | Position at 720 | Spec |
|---|---|---|
| Bar background | screen top, full width, 24 tall | Home: transparent. Apps: `surface` (`#121512`) matching the app bar, or draw the status region as part of the app bar background. Never wallpaper over an app. |
| Clock | left, x = screen_left + 16, vertically centred | 13 px Inter medium 500, on-surface `#F0E9D1`, `tnum` figures, 24-hour `HH:MM`. Update on minute change, not per frame. |
| Notification icons | after clock, gap 12 | Up to 4 mono app icons, 16 px, from `icons/mono/64/icon_<app>_mono.png`, white. A 5th+ becomes a 4 px dot (use `status/32/badge_dot.png` scaled to 5 px) + no text. |
| System icons, right | right edge minus 16, gap 8 | Order: `status_signal` (drone LINK), `status_wifi` (valley relay), `status_battery` + percentage text. 18 px glyphs, `status/64/*.png`, cream on dark surfaces. On a lighter app bar use `status/64/*_brass.png` or the cream variant at 85% opacity; do not invent blue icons. |
| Battery | rightmost | Kit glyph is static full. Draw `NN%` in 12 px Inter medium next to it, 4 px gap. Do **not** also render `LINK · 74%` (the in-flight regression, section 0). |
| Carrier text | removed | `HALLOWAY VALLEY` centred is not Android and eats the whole bar. The valley name belongs in Settings > About ("Halloway Personal") and on the welcome screen. |
| Status drag target | whole bar, plus 16 px below it | Pull down opens the shade; on touch this is the main entry. |

### 2.2 Colour and scrim

- Home: transparent bar plus a top scrim `black 40% -> 0%` over the first 96 px (not the current full-height 0.72 -> 0 gradient, which darkens the whole wallpaper). The kit ships `polish/wallpaper_vignette.png` (1920x1080, alpha 117 at the edges, 0 in the centre); use it instead of stacking a full-screen 50% ColorRect and a full-height gradient. Android wallpapers are bright; the current home is a dark green wash.
- Apps: the app bar background extends **under** the status bar (edge-to-edge), status icons use the on-surface colour for that bar. This fixes the current band of wallpaper above every app.
- The shade, dialogs and heads-up draw above the status bar and may tint it.
- Flight HUD: keep the status bar hidden (immersive). The OS was closed by the player; Android immersive mode is the correct model. Notifications still appear as heads-up (section 6).

### 2.3 Behaviour

- Tap the bar: open the shade (notifications). Two-finger pull or a second pull: quick settings expanded.
- Swipe down from the bar: shade. Swipe down again: QS.
- Clock is 24-hour to match the game's existing clock; if a 12-hour setting is added later, it belongs in Settings.
- Battery: the status battery is the **tablet**, not the drone. The drone pack stays in the field-note widget dial and in the Studio/app data. A static 86%, or a slow cosmetic drain/recharge of the tablet that never affects gameplay, is correct. Keeping `set_battery()` feeding the status number is a story leak (drone battery shown as device battery) - keep it feeding only the widget dial.
- LINK and the two radio glyphs are in-universe labels for the drone link, valley relay and drone pack if the Lead prefers function over Android purity. If Android purity wins, drop LINK text and keep three plain system glyphs. Either way, no blue, no carrier.

## 3. Navigation bar and back

Current state: a 54 px full-width dark bar with text buttons `Home`, app title · HALLOWAY PERSONAL, `Recents`, `Put away` (`phone_os.gd::_build_system_nav()` lines 399-442, `_update_system_nav()`). This is a desktop toolbar, not Android. It is on-screen in every app and duplicates the app-level Back that only the Casebook has.

### 3.1 Gesture navigation (recommended, Pixel Tablet model)

- Nav inset 24 px bottom, dark scrim none; system wallpaper/app surface continues behind it.
- Gesture pill: 108 x 4 px, radius 2, on-surface at 50%, centred, bottom margin 8 px. On home it sits over the wallpaper with a soft shadow; in apps it sits on the app surface.
- Swipe up from the pill / bottom edge: Home (launcher).
- Swipe up and hold, or swipe up from the bottom 24 px and pause: Recents.
- Swipe from the left or right edge (24 px active zone, 32 px drag threshold): Back. Back leaves an app to the launcher; Back on the launcher does nothing; Back with the shade open closes the shade.
- Keyboard mapping stays: `Esc` = Back, `Tab` = put the tablet away, `N` = shade. Do not remove these; they are the desktop and accessibility path.
- Add an on-screen entry point for touch: a 40-48 px phone button in the HUD, next to the gear button (`hud.gd::layout_for()` places `_back_btn` and `_gear_btn`; add a `_phone_btn` in the same row/column and a bell button for the shade). Without this the phone and shade are unreachable on a real tablet - currently they are keyboard-only (`main.gd::_unhandled_key_input()` lines 1019-1038).
- No visible `Home` / `Recents` / `Put away` text buttons anywhere.

### 3.2 3-button navigation (only if the Lead prefers Samsung-style tablets)

Home, Recents, Back: 48 px tall bar, three 48x48 targets centred at 1/6, 3/6, 5/6 width. Recents = rounded-square outline, Home = rounded square/circle, Back = arrow. The kit has **no Material nav glyphs** (see section 11); they must be drawn in code or added to the kit generator.

### 3.3 Per-app back

Every app gets a leading 48 px back arrow in its 56 px top app bar. The Casebook's text `Back` button (`casebook_app.gd::_app_bar()` line 92) becomes the same arrow. `Put away` moves out of the system bar: long-press Home does nothing, the way Android works; the player uses Tab or the HUD button. If a visible "put away" affordance is needed, put it in the shade footer/Settings, not in the nav bar.

## 4. Home screen and launcher

Current state: `phone_os.gd::_build()` lines 131-316 builds a desktop: 3-column grid of seven 96 px icons with name + category caption, a 320 px field-note card on the right, a 48 px big clock top-left, a tip strip, and a 58 px dock row that also contains Home/Recents/Put away. Screenshot: `docs/realism/phone_ui/00_home.jpg` (real kit icons are already showing via the in-flight `TabletIcon` change). Problems: not Android grid, no page dots, no app drawer, category captions, one orphan app on row 3, dock mixed with nav, wallpaper too dark, huge empty middle, 96 px icons too large for an mdpi tablet, labels wrap ("HALLOWAY VALLEY" style mini-captions).

### 4.1 Wallpaper

- The only wallpaper is `assets/ui/tablet_red_barn.jpg` at **1024x683** (measured). It is already upscaled 1.25x at 720p and 1.875x at 1080p, so it is soft. Keep it as the wall for now, but it is the #1 photoreal blocker on the home screen (section 11). If a higher-res public-domain crop can be found, use 2560x1440.
- Draw with `STRETCH_KEEP_ASPECT_COVERED`, full screen rect, behind every system surface.
- Treatment: nothing over the whole wall; `polish/wallpaper_vignette.png` stretched over the screen rect; a 96 px top scrim for status legibility; subtle 0-6% darken overall is acceptable. Delete the full-screen 50% `scrim` ColorRect (line 98) and the full-height `top_shade` gradient (lines 103-109). Current result looks like dusk inside a phone.
- Page parallax: wallpaper offset 10% of page scroll. Standard launcher behaviour and cheap in code.

### 4.2 Layout at 1280x720 (safe screen 1244x684 at offset 18,18)

| Region | Rect (window coords, frame on) | Spec |
|---|---|---|
| Status bar | (18,18, 1244, 24) | section 2 |
| Clock / At a Glance widget | (34, 58, 560, 120) | 24 radius, `surface-container #1E231E` at 82%, no border. Time 48 px Inter regular 400, `tnum`; date 12 px on-surface-variant above (e.g. `SAT 24 OCT`); weather line 13 px (`10°C · wind 8.5 m/s`) under it with a `weather/64/weather_cloud.png` glyph at 20 px. |
| Field-note widget | (678, 58, 560, 152) | 24 radius, same surface. "FIELD NOTE" 11 px medium tracking 1.2, brass; "Halloway Valley" 18 px medium; condition 12 px body 2 lines max; two 64 px kit dials (`dial_wind_face` + needle, `dial_battery_face` + fill + needle); crew/case lines 11 px with brass `·`. Keep every current string; this is the story widget and can stay game-specific. |
| App grid | centred, x = 346, y = 238, 5 columns, cell 108x100, gutter 12 | 7 apps: row 1 DroneBudz, VidTube Studio, Photos, Jobs, Casebook; row 2 Facade, Map (or put Facade+Map on page 2 if the widgets take the space). Icon visual 56, label 12 medium, 6 px gap, 100 max label width, ellipsis, single line, no category caption, no `9+ NEW` text under the icon (badge instead). |
| Page dots | centred, y = 566 | 2 pages: 8 px dots, gap 8, active `polish/page_dot_on`, inactive `page_dot_off`; scale the 32 px source to 8. |
| Dock | centred, (439, 584, 402, 84) | `polish/dock_tray.png` nine-patch, height 84, content 44/128 margins scaled; 5 apps: DroneBudz, VidTube Studio, Photos, Facade, Map. Icon 56, gap 16, labels hidden (Android dock has no labels). The dock is home-only. |
| Gesture pill | centred, y = 690, 108x4 | section 3 |
| Page 2 | same frame | Weather widget (560x200) using kit `weather/64/*` glyphs and a 5-day style strip; channel widget (560x200) with follower/view/money numbers and a small VidTube mark. Then two apps (Facade, Map) on the same grid geometry. This is what makes page dots real rather than decoration. |

### 4.3 App grid rules

- Android tablets use 5-6 columns in landscape; mdpi 1280 uses 5. Cell 108x100 is the minimum for a 56 px icon plus a 12 px label and 48 px touch target (the whole cell is the target).
- Grid is centred horizontally, not left-aligned with a giant empty band. Android launchers centre the workspace.
- Label: one line, 12 px medium, on-surface, text shadow (black 50%, offset (0,1), blur 2) for wallpaper legibility. No second caption. App names stay exactly: DroneBudz, VidTube Studio, Photos, Jobs, Casebook, Facade, Map.
- Tap: container-transform open (section 8). Long-press: Android shows a popup menu (App info / Uninstall). Do not fake uninstall; a long-press menu with "App info" opening the in-OS Settings page is enough, and optional.
- Widgets are read-only; tapping the field-note widget opens Casebook, tapping the clock opens the weather/at-a-glance detail page, tapping a channel widget opens Studio. Android widgets are tappable.

### 4.4 App drawer

Missing today; add it.

- Opened by swipe-up on the home screen (from anywhere on the wallpaper, not from the dock) or a small "all apps" chevron above the dock. Also a kit `search_pill` search bar at the top.
- Surface: wallpaper dimmed 60% + blur if a blur is ever available; Godot has no cheap backdrop blur, so use `surface #121512` at 92% and the wallpaper faintly visible. Do not build a full-screen photo.
- Search pill: `controls/search_pill.png` nine-patch, 640x48 at 720, y = 58, x = 320; placeholder "Search apps" 14 px; mic glyph `status/64/search_mic.png` 20 px right.
- Grid: 4 columns, cell 140x140, icon 56, label 14 px, alphabetical: Casebook, DroneBudz, Facade, Jobs, Map, Photos, VidTube Studio. Labels always visible. Sort alphabetically even though the home grid uses story order.
- Drag handle pill at the bottom; swipe down or Back returns home.

### 4.5 Folders

Not needed with seven apps; Android only shows folders when the user makes one. Do not add fake folders. If apps are added later: folder icon = 24 radius `surface-container-high` tile with a 2x2 mini preview of the first four icons, 12 px name; tap opens a centred popover (280x320, 28 radius) with a 4x2 grid; no drag. Keep it out of this pass.

### 4.6 Lock screen

Out of scope for this pass. The game pauses via the HUD, not a lock screen. If added later it is a separate spec (clock, notifications stack, swipe-up, camera/weather shortcuts). The OS must not pretend to have one now.

## 5. Recents

Current state: `phone_os.gd::_show_switcher()` builds a centred 80%-wide dialog with a `RECENTS / Apps` heading, a 2-column grid of 7 app cards with descriptions and an `Open` button (`docs/realism/tablet/01_recents.jpg`). That is an app-picker dialog, not Android Recents.

### 5.1 Spec

- Full-screen surface over the launcher: wallpaper at 40% brightness or `surface` at 98%; status bar visible (clock + system icons), no `RECENTS/Apps` title.
- Task cards: 520x380 at 720 (40% width, 53% height), 24 radius, centred vertically around y = 180..560, gap 24, horizontal scroll with snap.
- One card per **opened app this session**, in order opened, current task nearest centre. Track `_recent_apps: Array[String]` in `PhoneOS._open_app()`; do not list all 7 apps. If empty, show an empty state ("No recent items", 14 px, on-surface-variant).
- Card content (no expensive viewport capture): app icon 32 + app name 14 medium top-left in a header strip 56 tall; below, a tonal body tinted with the app's accent (10-16% alpha over surface-container) with the app mark watermarked at 96 px and 10% alpha, plus two lines of live summary provided by the app: DroneBudz "#general · 8 unread · 10 on the server"; VidTube "104 followers · 9 videos · $317 pot"; Photos "12 photographs"; Jobs "3 open jobs"; Casebook "CASE CLOSED · HV-84-017"; Facade "8 listings · 1 owned"; Map "Valley road map · 4 launch sites". This is honest (no fake screenshots) and reads like Android task cards.
- Tap a card: open that app with the container transform. Swipe up on a card: dismiss it (drag threshold 120 px, 200 ms collapse + fade). Back/Home: leave Recents.
- "Clear all" pill: 120x40, 20 radius, surface-container-high, 14 px, bottom-left at (34, 630), visible when at least one card. Android 14 places it at the left of the task row; either position reads correctly.
- The gesture pill stays at the bottom.
- Transition: cards scale from 0.92 + fade 150 ms when Recents opens; closing animates back to the app.

### 5.2 Where it lives

Replace `_show_switcher()` and the `_switcher` subtree inside `phone_os.gd`. Do not reuse the current PanelContainer dialog styling. The code already frees and rebuilds the panel each open; keep that pattern but rebuild a full-screen task strip.

## 6. Notifications, shade, quick settings, dialogs

Current state: `phone_notes.gd` is a separate CanvasLayer at `layer = 20`, below `PhoneOS` at `layer = 28`. So when the phone is open, heads-up cards and the shade render **behind** the wallpaper - the OS has no notifications at all. The shade exists only over the flight HUD (`docs/realism/ui_review/04_notifications.jpg`): a top sheet about 420 px tall with `Notifications`, blue link-coloured `Open DroneBudz` / `Clear all`, hand-drawn app glyphs, no clock, no quick settings, no status-bar icons, no grouping by app. `N` opens it; there is no touch entry.

### 6.1 Layer and ownership

- `phone_notes.gd` must become the system UI layer: `layer = 34` (above `PhoneOS` 28 and above the device frame if the frame is in `PhoneOS`; if the frame lives at layer 40, put the system UI at 44). Fix in `phone_notes.gd::setup()` line 119.
- Set `_root.theme = UniverseUI.make_theme()` in `setup()`. Today every notification Label and every drawn glyph uses `ThemeDB.fallback_font` (`phone_notes.gd` lines 100, 123-133), so the shade renders in Segoe UI/Roboto while the phone renders in Inter. That font switch is visible in every screenshot.
- Heads-up, status-bar notification icons, the shade and QS all share this layer. The `AppIcon` and `Avatar` inner classes (`phone_notes.gd` lines 61-107) must load the real kit: `status/64/*.png` for the short glyphs, `icons/mono/64/icon_<app>_mono.png` for notification app marks, and `icons/44/icon_<app>.png` for avatars if real avatars never land. Delete the hand-drawn x/play/tag glyphs.
- `main.gd` already wires `phone_notes.app_requested -> phone_os.open() + _open_app()` (lines 439-442); keep it and use the same path when the shade opens an app.

### 6.2 Status-bar notification icons

When `_history` is non-empty and the OS is open, show up to four 16 px mono app icons in the status bar after the clock (section 2.1). Dismissing the shade clears them; this is the Android contract and it finally connects the notification system to the OS.

### 6.3 Heads-up banners

- Width 420 at 720 (max 92% width), x centred, y = status_bar.bottom + 8 = 50, height 72-88 depending on body lines.
- Surface `#1E231E` 97%, 24 radius, shadow 12/24 black 35%. One card per app group; stack up to 3 with 8 px vertical offset and 0.98 scale per level (keep the existing stack/group logic, it is good).
- Header: app icon 22 (mono, white), app name 12 medium, `· N` group count, time 11 on-surface-variant right. Then title 14 semi-bold and up to two body lines 14, on-surface. A chevron/expand control only if there is more than one message.
- Tap: open the app inside the OS (even if the OS is closed: opening the OS to that app is the correct Android behaviour and `main.gd` already does it). Swipe up: dismiss. Auto-hide 9.5 s (current `HEADS_UP_LIFE`, keep).
- Enter: slide from -90 to y over 220 ms, ease-out; successive cards push down 180 ms. Exit: fade 250 ms, no slide.
- When the OS is closed (flight), the same heads-up is the only phone surface - that is canonical Android immersive behaviour and already works.
- The `_pill` (`_build_pill()`, lines 763-814) is not Android. Replace it with the status-bar notification icons: when the OS is closed the HUD has no status bar, so either (a) keep a small 18 px unread dot at the top-right of the HUD's video frame (in-universe notification indicator) or (b) drop it and rely on the heads-up. If kept, position it inside the safe area, not at `vp.x - width - 18, y = 30` with a 30 px top offset that ignores bezels. Recommended: (b) drop the pill; the heads-up plus the shade key `N`/bell button is enough.

### 6.4 Shade layout (tablet two-pane, Android 12L+ model)

Full-width sheet from the top, height `min(560, 78% of screen height)` = 560 at 720, bottom corners 28, top square, `surface-container-high #262C26` 98% with a 8 px shadow. It covers the status bar and shows its own clock/date.

| Region | 720 rect | Content |
|---|---|---|
| Header left | (34, 34) | Date 14 px on-surface-variant (`SAT 24 OCT`); clock 28 px regular under it; no "Notifications" heading duplicate. |
| Header right | right-aligned, y 34 | Settings gear 48x48 (`icons/44/icon_settings.png` 24 in a 48 target) and power 48x48. Settings opens the in-OS Settings page (section 9.8); power does nothing destructive - open a dialog with "Put the tablet away" / Cancel. |
| QS column | x 34..414, y 106..470 | Brightness slider 48 tall with `controls/slider_track/fill/knob`; 3x3 grid of 118x84 tiles, 12 gap, 16 radius. Header "Quick settings" 12 px. |
| Notification column | x 438..1238, y 106..470 | Header "Notifications" 12 px left, "Clear all" 12 px brass right; grouped cards. |
| Footer | y 500..540 | Device name `Halloway Personal` 11 px on-surface-variant left; `N` hint only on desktop. Optional drag handle 32x4 centred at y 552. |
| Scrim | full screen below sheet | black 32%, tap closes; drag up closes. |

Quick-setting tiles (functional first, cosmetic second - never leave a dead-looking toggle):

| Tile | Icon source | State | Effect |
|---|---|---|---|
| Drone link (Wi-Fi analogue) | `status/64/status_wifi.png` | on by default | Cosmetic: off greys the LINK status glyph and shows "No link" in the field-note widget. |
| Drone messages (DND analogue) | `icons/mono/64/icon_dronebudz_mono.png` | follows `hud.phone_notes` | Real: off sets `hud.phone_notes = false`, no heads-up, shade stays available. |
| Night camera | `icons/mono/64/icon_phone_mono.png` or kit `weather/64/weather_moon.png` | follows night vision | Real: toggles the existing night vision only when fitted and paused. |
| Thermal camera | `weather/64/weather_cloud.png` alternate or `icons/mono/64/icon_camera_mono.png` | follows thermal | Real: same rule as above. |
| Battery saver | `status/64/status_battery.png` | off | Real: maps to the existing `hud.simple_on` camera-effects setting if a safe mapping exists; otherwise cosmetic with a snackbar explanation. |
| Rotation lock | `weather/64/weather_wind.png` (reuse) | locked | Cosmetic: home pages do not rotate anyway, so it is honest. |
| Airplane / radio off | `status/64/status_signal.png` | off | Cosmetic: dims LINK and radio glyphs in the status bar. |
| Screen record | `status/64/status_notification.png` | off | Cosmetic: shows a small `REC` pill under the status bar while on. |
| Torch | `weather/64/weather_sun.png` | off | Cosmetic; do not tie to the drone light. |

There are **no QS tile glyphs in the kit** except the five status icons and the weather set. Until a proper 24 px glyph set is added (section 11), use the status/weather/mono icons above, or draw Material-style glyphs in `game/system_glyphs.gd`. Do not use 512 app tiles at 24 px in the tiles: they carry baked tile backgrounds and will look like tiny app icons, not system glyphs.

Tile spec: 16 radius; off = `surface-container-highest #2E352E` + on-surface-variant icon/text; on = `primary-container #4A3B22` + brass icon/text; press ripple 12%; toggle 150 ms colour crossfade, no knob needed for tiles (Android tiles are stateful buttons; the kit `switch_on/off` is for the Settings page rows, not the tiles).

Interactions: drag the brightness slider (kit track/fill/knob, 12 px groove); tap a tile toggles; long-press a tile opens the matching Settings row when one exists; pull the shade further (past 40 px) to expand QS to full height; Back/Esc or swipe up closes.

### 6.5 Notification cards in the shade

- Grouped by app, newest first. App group header: mono icon 18, app name 13 medium, count 12 on-surface-variant, chevron. Cards inside: full width, min height 72, 20 radius, `surface-container #1E231E`; icon 24 (app mark), title 14 semi-bold, body 14 max 2 lines, time 11 right, dismiss `X` 24 (use a 32 px target).
- Swipe left/right on a row dismisses it (drag 96 px or more). "Clear all" clears the history.
- Cards are tappable: open the app, keep the history (Android keeps it until dismissed; current code already keeps history).
- Empty state: "No notifications" 14 on-surface-variant, centred.
- Media style for VidTube uploads (optional but high realism): 1 row with 96x96 rounded thumbnail, title, upload progress using the kit slider fill, and a "Studio" open action. Android media/progress notifications are the most recognisable notification shape after messaging.

### 6.6 System dialogs

Use Material alert dialogs for destructive or irreversible actions. Today there are none: `photo_library.gd::_delete_current()` (line 375) deletes immediately and `marketplace_app.gd::_buy()` (line 241) buys immediately. That is both non-Android and bad UX.

Spec: 320 px wide at 720 (max 560), centred, 28 radius, `surface-container-high`, 24 padding; title 22 medium; body 14 2 lines; text buttons right-aligned, 48 tall, 8 apart, label 14 medium (`Cancel` on-surface-variant, action brass or error red for destructive); scrim 32% black, fade 150 ms; dialog scale 0.94 -> 1 + fade 150 ms. No filled button in dialogs (Android uses text buttons).

Dialogs to add:

| Trigger | Title / body | Actions |
|---|---|---|
| Delete photo | "Delete this photo? The original is removed from the camera roll." | Cancel / Delete (error) |
| Buy from Facade | "Buy <item> for $<price>? Channel pot: $<money>." | Cancel / Buy |
| Publish or delete a clip (if a destructive action exists) | same pattern | Cancel / action |
| Close case | Keep the existing Casebook choice card (it is story, not system). Optionally present it as a full-height bottom sheet with the same 28 radius. | Publish / Keep |
| Put away / quit | "Put the tablet away?" is unnecessary; Tab already does it. Do not add a dialog. | - |

### 6.7 Snackbars and toasts

- Inside the OS, use a Material snackbar for undo and non-blocking confirmations: 344x48, 4 radius, `surface #2E352E` (inverse surface), message 14 on-surface, action 14 brass, 4 s, positioned 16 above the nav inset, centred. First use: photo delete with `UNDO` (soft-delete the record, restore on undo) and Facade purchase ("Thermal camera added to your kit") with no action.
- Keep `hud.toast()` for the flight HUD only. A phone notification is not a toast.
- Do not restyle the HUD toast in this pass; it belongs to the flight app, not the tablet OS.

## 7. Adaptive icons using the real kit

### 7.1 What the kit actually contains (measured)

- `icons/icon_<name>.png` 512 composite tiles; native exports at `icons/128/`, `icons/64/`, `icons/44/` (rendered, not downscaled).
- `icons/layers/icon_<name>_bg.png` (full bleed) and `icon_<name>_fg.png` (art bbox 125..387 px = 51% of 512, inside the 66% adaptive safe zone).
- `icons/mono/icon_<name>_mono.png` at 512 and `mono/128|64|44/` white-on-alpha for notifications.
- 12 apps: dronebudz, vidtube, photos, jobs, casebook, facade, settings, recents, weather, camera, home, phone. **No `icon_map`.** Map still falls back to the drawn `TabletIcon` path because `tablet_icon.gd::ANDROID_ICONS` has no `"map"` entry either.
- Style: warm painted rounded-square tiles with gradients, grain, baked shadow (<=8 px) and a small top-left highlight. This reads as a premium in-universe app icon set, not as stock Android flat vector. The silhouettes are clean and survive 44 px.

### 7.2 Mapping and sizes

| Game app | Kit base | Home icon | Dock / drawer | Recents / app bar | Notification |
|---|---|---|---|---|---|
| DroneBudz (chat) | dronebudz | 64 (128 export) | 56 (64) | 32 (44) | mono 22 (64) |
| VidTube Studio (studio) | vidtube | 64 | 56 | 32 | mono 22 |
| Photos | photos | 64 | 56 | 32 | - |
| Jobs | jobs | 64 | 56 | 32 | mono 22 |
| Casebook | casebook | 64 | 56 | 32 | mono 22 |
| Facade (market) | facade | 64 | 56 | 32 | mono 22 |
| Map | **missing** | 64 | 56 | 32 | - |

Rules:

- Choose the export by display size, not 128 for everything: display <= 48 use the 44 or 64 export; 49-72 use 64; > 72 use 128. The in-flight `TabletIcon` always loads 128 and blits it to 40 px in the dock, which aliases. Fix `tablet_icon.gd::set_kind()` to pick the nearest export, and cache by name.
- Never shrink 512 to <= 64; that is what the native exports exist for.
- Do not add another shadow stylebox on top of the kit tile: the shadow is baked. The current code-drawn fallback adds `shadow_size = 6` (`tablet_icon.gd::_draw()`); when the kit texture is present, return before that, which the in-flight change already does. Keep the fallback path for Map until Map art exists, but draw the fallback in the same 64-72 px box so it does not sit visually heavier than the kit icons.
- Home icon visual is 64 px inside a 108 px cell: Android's icon is about 60% of the cell. Do not fill the cell.
- Keep the label outside the icon: the kit tile already bakes its rounded-square body, so the label must not overlap it (current home labels sit right under the tile and are fine; the category caption is the problem).
- The dock and app drawer use the same 56/48 px icon with no label in the dock and a 14 px label in the drawer.
- On the home page only, if the Lead wants true adaptive-icon behaviour: draw `bg` at the full tile and `fg` at 72/108 inset (66% safe zone equivalent), apply a 28% rounded-rect clip, and offset the fg by up to 2 px against page scroll (Android adaptive icon parallax). This is optional polish; the composite exports already look right and are cheaper.

### 7.3 Badges and unread treatment

Current: `_drone_budz_badge` and `_studio_badge` are 9-10 px amber text labels *under* the app name (`phone_os.gd` lines 241-248), reading `9+ NEW` and `N RUSHES`. Not Android.

Spec:

- Badge on the icon, top-right: use `status/badge_dot.png` (red dot, 8 px) when count is 1-9 and `status/badge_unread.png` (96x64 red pill) as the background for numbers, or draw a `#B3261E` pill 16-18 px high with 9 px radius. Number 11 px Inter medium white, `9+` cap. Android positions the badge centred on the icon's top-right corner, overlapping both the icon and the cell: at 64 px icon, badge centre at (icon.x + 56, icon.y + 8).
- Badge only for notification-driven apps: DroneBudz unread (`chat.unread_total()`), VidTube when a job publishes/uploads, Facade when an order is ready, Jobs when new work appears, Casebook when the next step changes. Do not badge Photos/Map. `N RUSHES` is not an Android badge; move that count into the Studio widget on page 2.
- The badge sits above the label, not below the icon in the text column. Remove the two badge Labels from the grid cell.
- Notification dots for non-count apps: 8 px dot, same position, no number.
- Status-bar notification icons and app badges must use the same count source so they agree.

## 8. Typography, spacing, surfaces, touch and motion

### 8.1 Typography

- Inter is loaded as the default font in `ui_theme.gd::make_theme()` (in-flight) and it is the right choice. It is not Roboto: letterforms differ slightly (Inter is wider, more geometric). For "almost identical to Android", Inter at the correct sizes and weights reads correctly at 720p; a literal Roboto match would need Roboto/Noto Sans (Apache-2.0) added, which is a product decision, not a blocker.
- Add a weight/letter-spacing helper, because right now every label is one weight:

```gdscript
# ui_theme.gd, new helper
static func font(size: int, weight := 400, tracking := 0.0) -> FontVariation:
    var f := FontVariation.new()
    f.base_font = load("res://assets/ui/tablet/Inter.woff2")
    f.variation_opentype = {"wght": weight}
    if tracking != 0.0:
        f.spacing_glyph = int(round(tracking * float(size)))
    return f
```

- Type scale (sp = px at mdpi; `weight` Inter axis):

| Role | Size / line | Weight | Use |
|---|---|---|---|
| Display (widget clock) | 48 / 52 | 400 | At a Glance clock |
| Headline medium | 28 / 36 | 500 | empty-state titles, Recents empty |
| Title large | 22 / 28 | 500 | top app bar title, dialog title |
| Title medium | 16 / 24 | 600 | list primary, dialog list items |
| Body large | 16 / 24 | 400 | long copy, chat body maybe 15 |
| Body medium | 14 / 20 | 400 | default body, notifications |
| Label large | 14 / 20 | 500 | buttons, tabs |
| Label medium | 12 / 16 | 500 | app labels, chips, metadata |
| Label small | 11 / 16 | 500 | overline, badge, status secondary |

- Tracking: -0.5 at 48, -0.25 at 28-22, 0 at 16-14, +0.3 at 12, +0.8 at 11 all-caps metadata. Use `tnum` for clock, money, followers, views, distances and battery so live values do not jitter.
- `phone_notes.gd` must stop using `ThemeDB.fallback_font` and use Inter via the theme; `tablet_dial.gd` too (`_draw()` uses `ThemeDB.fallback_font` for labels).
- Small caps metadata is a game-identity choice and can stay on the field-note widget and Casebook stamps, but not on Android chrome (status bar, app labels, QS, dialogs).

### 8.2 Spacing: 4 dp grid

Use 4/8/12/16/24/32/48/64. Current code mixes 7, 9, 10, 11, 13, 14, 18, 20, 22, 26, 30 - that is why the UI reads hand-tuned rather than Android.

- Screen margin: 16 (24 for launcher edges).
- Gaps: 8 between icon and text, 12 between list columns, 16 between cards, 24 between groups.
- List: 16 start/end, 12 between avatar and text, 72 two-line row.
- App bar: 16 start/end, 56 height.
- Dialog: 24 padding, 12 between title and body, 24 before buttons.
- Widgets: 16 internal and 12 between elements.

### 8.3 Surface hierarchy and Material colour roles

Android dark theme reads through tonal surfaces, not hairline borders. The current `UniverseUI.box()` puts a 1 px warm border on almost every surface; that is the "field kit" look, not Android.

Map the existing palette to Material roles (keep the identity, change the structure):

| Role | Hex | Replaces |
|---|---|---|
| surface | `#121512` | `NIGHT` / app scrim |
| surface-container-low | `#181C18` | `DEEP` |
| surface-container | `#1E231E` | `PANEL` |
| surface-container-high | `#262C26` | `CARD` |
| surface-container-highest | `#2E352E` | `FIELD` |
| on-surface | `#F0E9D1` | `CREAM` |
| on-surface-variant | `#C2C0AE` | `CREAM_DIM` / `MUTED` |
| outline | `#4A5148` | dividers only |
| primary | `#E0AB59` | `AMBER` |
| on-primary / primary-container | `#241C0C` / `#4A3B22` | `ON_AMBER` / `AMBER_SOFT` |
| tertiary | `#74A87A` | `MOSS` |
| error | `#B3261E` (badge) / `#DB5C52` text | badge red / `DANGER` |

Rules:

- Cards and widgets: tonal fill, 0 or 1 px outline only if needed for separation, 16/24 radius, no border by default.
- Inputs: outline 1 px `outline`, radius 12, fill surface-container-low; focused outline 2 px primary.
- Dividers: 1 px `outline` at 30%, only in lists and settings.
- Elevation: level 1 (cards, 2-4 px shadow, black 20%), level 2 (app bar on scroll, 6 px), level 3 (FAB/dialog/heads-up, 12-24 px, black 35%). Never more; the kit bakes <= 8 px into icons.
- App bases: keep `scrim.color` in each app but set it to `surface` (currently 100% opaque dark greens - fine) and let the **app bar** carry the accent, not a border.
- Selected states: tonal `primary-container` + primary text, not just a coloured 1 px border. Current selected channel row uses `AMBER_SOFT` fill plus amber border - drop the border, keep the fill.

### 8.4 Touch targets

| Control | Current | Required |
|---|---|---|
| Home app cell | 96x96 icon + labels | 108x100 cell, whole cell tappable |
| Dock icon | 44x44 | 56 icon in 72 target |
| Back arrow | text 76x38 (Casebook only) | 48x48 icon, 56 app bar |
| Chat chips (`Chip`) | 24 px tall | 32 visual, 48 touch |
| Send button | 78x38 | 48 min height |
| QS tile | none | 118x84 |
| Notification dismiss | 24-ish | 48 target |
| Shade handle | none | 48 tall drag region |
| Photo grid cell | variable | 96x96 minimum, 4 px gap |

- Minimum 48x48; dense menus 40x40 only if separated by 8 px.
- Hover-only states must never be the only affordance; the game supports touch, so press states and ripples matter more than hover.
- Contrast: body text on surface must reach 4.5:1; MUTED (`#999F8D`) on CARD is about 4.2:1 - raise to `#C2C0AE` for body-size text. Labels over wallpaper get a shadow, not a pill.

### 8.5 Motion

Android motion is short, decelerating and physical. The game currently has no transitions at all (phone appears instantly, apps swap instantly, shade snaps open via a lerp only when open). Recommended set (all in ms; use `Tween` with `TRANS_QUINT/EASE_OUT` for enter, `TRANS_QUAD/EASE_IN` for exit unless noted):

| Interaction | Spec |
|---|---|
| Press state / ripple | 200 ms, 12% white circle expanding from touch point, clipped to the control; implement one `Ripple` helper and use it on every button/tile/card. |
| App open (container transform) | 220 ms: copy the tapped icon texture into a Control at the icon rect, animate its rect to the app content rect with ease-out while the app fades in (120 ms, 40 ms delay). Reverse in 180 ms on Back/Home. |
| Home page swipe | follow finger, snap 260 ms; wallpaper parallax 10%. Overscroll stretch 8% and spring back 200 ms if cheap, else a hard stop. |
| Recents open/close | 200/180 ms, cards scale 0.92 -> 1 and fade; card dismiss 200 ms up + fade. |
| Shade open/close | 280/220 ms, texture height + fade; scrim 150 ms. QS expansion 200 ms. |
| QS tile toggle | 150 ms colour crossfade and icon tint; state word not needed (icon + fill). |
| Heads-up in/out | 220 ms in from -90 px; 250 ms fade out; stack push 180 ms. |
| Dialog | 150 ms: scrim fade, dialog scale 0.94 -> 1. |
| Snackbar | 200 ms slide up from bottom, 150 ms out. |
| Badge change | 150 ms scale pop 0.8 -> 1 when the count changes. |
| Screen transitions | No slides/parallax between apps beyond the container transform; Android uses shared-axis transitions, not wipes. |
| Wallpaper clock | update per minute with a 150 ms fade on the minute change (subtle). |

- Do not animate the OS opening with a slide: the current instant appearance is correct for a game where the sandbox keeps flying. A 120 ms fade of the whole `PhoneOS` root is enough.
- Keep the reduced-motion escape: no motion affects gameplay; 220 ms is short enough that it never blocks flying.

## 9. Keeping the game's app identities inside the Android shell

The shell should be indistinguishable from Android; the app interiors should be believable genre apps that happen to be fictional. Rules for every app:

1. App name and all story copy stay exactly as written: DroneBudz, VidTube Studio, Photos, Jobs, Casebook, Facade, Map. No renaming to Android/Google products, no Android/Google/Apple/VidTube real marks. The kit art is already fictional.
2. Every app draws under the status bar with its own app-bar background; content starts below the 56 px app bar; every app has a 48 px leading back arrow to the launcher.
3. No app uses the valley wallpaper as its background. Apps use `surface`; the wallpaper belongs to the launcher and the shade (slightly).
4. No app's top row is a desktop toolbar of outlined buttons. Primary actions are a filled button or FAB, secondary actions are icon buttons, tertiary are text buttons.
5. Every app must remain usable with touch: 48 px targets, no hover-only controls, no tooltips required.
6. Keep game-specific mechanics visible (the ASK chips in chat, the field-note dials, case stamps, job requirement chips). They are the story; give them Material chips/badges/checkmarks.

### 9.1 DroneBudz (chat) - Discord-like messaging app on Material rails

- Genre: Discord/WhatsApp hybrid. Keep the server + channel list and the cast roles.
- App bar (56): back arrow, server mark 24 (kit `icons/44/icon_dronebudz.png`), title `# general` 22 medium, subtitle/topic 11 on-surface-variant, member count trailing 12. Drop the current separate 70 px header panel; merge into the app bar.
- Tablet layout: permanent navigation drawer/rail for channels, 260 wide (not the current 272 border-separated panel): `surface-container-low`, "CHANNELS" and "DIRECT MESSAGES" section headers 11 px, channel rows 48 tall with `#` glyph (draw a 20 px hash or use a mono icon), name 14, unread count badge 11, selected state `primary-container` fill 12 radius. Bottom of rail: the "You · pilot" identity row 56 tall with a 32 px avatar.
- Message list: 16 px side padding, grouped by author (keep current logic), avatar 36, name 13 medium in the cast colour (game identity), role 10 small caps faint, time 10, body 14. System rows stay centred muted. Photo messages keep the real photo frame.
- Composer: 56 px bottom bar above the nav inset, 16 radius field (`LineEdit`), attach/mic icon buttons 48, Send filled 48. The ASK chips become a horizontally scrollable Material chip row 32 tall (touch 48) directly above the composer; keep the six questions and their crew tooltips.
- Motion: channel switch is an instant content swap (no slide); new messages fade in 120 ms.

### 9.2 VidTube Studio - creator studio app

- Genre: YouTube Studio. App bar: back, channel avatar 32 (rust gradient), "Studio" 22, trailing search/settings icons 48. Banner: rust-toned banner 1600x? - there is no banner art, so use a 24 radius tonal rust gradient (`#7A3C29 -> #CE7F5A`) 104 px tall with the channel name inside, not a translucent panel over the wallpaper (current screenshot `13_ui_pass_studio.jpg` shows the title colliding with the widget behind because the header has no opaque background).
- Metrics: 2x2 grid of cards (16 radius, `surface-container`, 16 padding) or a single row of 4 at 1280; value 28 semi-bold, label 11 small caps, sub 11 on-surface-variant. Keep followers, pot, videos, views. Remove coloured left borders (not Android); the metric's colour lives in the icon/label.
- Content: "UPLOADS" section header 11, thumbnail rows 72 tall: 96x54 16:9 thumbnail with 12 radius, title 14 medium, meta 11, views 18 right. Keep the real clip thumbnails.
- Primary action: extended FAB "Upload" 56 tall, icon `icons/mono/64/icon_vidtube_mono.png` or play glyph, bottom-right 16 above nav inset. Replace the two top-right buttons (current `Open DroneBudz`, `Upload from camera roll`). Keep `Open DroneBudz` as a trailing icon or a rail item; keep `Jobs board` as a chip.
- Video detail: full-screen surface with a 16:9 still, title, edit/publish actions; it is a still, not playback, and should say so honestly once, not in a footnote on every card.

### 9.3 Photos - gallery app

- Genre: Google Photos. Full-screen `surface`; app bar 56: back, "Photos" 22, search icon 48, overflow 48. Below: a 2 px segmented control (`All | Albums`) if albums exist, else nothing.
- Grid: 4 columns at 720 (5 at 1080), square tiles, 4 px gaps, radius 8 (Google Photos is slightly rounded). Section headers by date ("TODAY", "OCT 24") 11 small caps. Empty state: outline photo icon, "No photographs yet", body line about the shutter.
- Detail: full-bleed photo on `#000` with a top scrim, back arrow over it, bottom action sheet with metadata (weather, ISO, shutter, AGL) and Export/Upload/Delete as a bottom bar or sheet; Delete opens the confirm dialog + undo snackbar (6.6).
- The gallery is currently a modal panel with a bordered header (`photo_library.gd::_build_ui()`); it must become an app surface inside `_apps`, like the other apps, with the system chrome around it.

### 9.4 Jobs - paid-work board

- Genre: gig-work app (TaskRabbit/Fieldwire). App bar: back, "Jobs" 22, filter icon 48; chip row 32 tall (`All`, `Near`, `Photo`, `Farm`, `Lake`, `Civic`) with 8 gap, horizontally scrollable.
- Cards: full-width, 16 radius, `surface-container`, 16 padding; job photo 16:9 (real captured photos where they exist, otherwise a tonal placeholder), title 16 medium, payout `$` 18 brass, distance/time 11, requirement badges as small 11 px chips (keep the existing keep-clear/range/framing/retake states; no kit badge art, draw them as tinted pills), primary `Accept` filled button 40 tall, secondary text button.
- The board is a list, not a two-column desktop grid. Current `jobs.gd` is 955 lines; keep the data/state, restyle the surfaces and move it under the app content rect.

### 9.5 Casebook - constabulary case-file app

- Genre: official records app, not a generic notes app. Keep the paper/ink identity; it can be more bespoke than the other apps because it is a police tool, but the system chrome stays Android.
- App bar 64 (large title): back arrow, constabulary crest/icon 24 (kit casebook), overline `HALLOWAY VALLEY CONSTABULARY` 10 brass, title `Casebook` 22, case id + act 11 on-surface-variant, status chip right (`CASE CLOSED` moss tonal pill) and a trailing message icon button. Remove the text `Back` button and the `Message Rennick` wide button from the bar; the message action becomes the trailing icon and the existing contact action inside the pane.
- Navigation rail: 4 destinations (Overview, Evidence, Chapters, Contacts) as a Material 3 navigation rail 80 wide, icons 24, labels 11, selected `primary-container` pill; expand to 240 with labels when width >= 1400. The current 272 px card rail with a file-identity card is too desktop and duplicates the app bar. The file identity moves into the overview content.
- Content: max width 720 centered on wide screens; cards are paper-toned (`#EFE6D0` at 96%) with 12 radius and dark ink text, or keep dark surfaces with ink stamps? For realism inside a dark Android OS, a light paper pane is legitimate and makes the Casebook read as a real app. Recommend: content cards on `surface` with warm paper-tinted section headers; reserve full paper for the evidence photo frame and stamps. There is no paper texture in the kit; a flat warm tone is honest (section 11).
- Keep all current content: request card, story director next step, evidence register with progress bars, chapter trail, contacts, choice card, closed card.
- Progress bars: 4 px track `outline`, 4 px fill moss/brass, 2 radius, no border.

### 9.6 Facade - classifieds/marketplace

- Genre: marketplace (eBay/Facebook Marketplace). App bar: back, "Facade", search pill below the bar (`controls/search_pill.png` nine-patch 48 tall), category chips horizontally scrollable (`All`, `Drones`, `Cameras`, `Motors`, `Parts`), 2-column grid of cards on tablet: image area 4:3 (no product art - use a tonal tile with the kind glyph and the kit `icon_facade` watermark; this is a visible placeholder, see section 11), title 14, seller/place/condition 11, price 18 brass, `Buy` filled 40 / `OWNED` tonal pill.
- Detail: bottom sheet 28 top radius, drag handle, 16:9 image, title 20, price 22, seller row 56, description 14, sticky bottom bar with `Buy` filled and `Add to kit`/`Fly` secondary.
- The "Your kit" tab stays, as a second destination in a 2-item segmented control under the app bar (not a text tab row with 2 buttons and a spacer).
- `_buy()` gets the confirm dialog and a snackbar; keep the existing spend/pot logic and copy.

### 9.7 Map - road atlas/map app

- Genre: Google Maps / OsmAnd. This is the easiest app to make convincing because the map already draws in code.
- Full-bleed map canvas fills the content area under a **transparent** app bar: back arrow and search pill float over the map with 12 radius surface backgrounds and shadows. Current `map_app.gd::_build()` already draws a map with a side list; make the list a bottom sheet (28 top radius, drag handle, site cards 72 tall, distance/time 11, `Set route` filled / `Fly here` text, active site highlighted with a 16 radius `primary-container` fill).
- Floating controls: 40 px rounded-square buttons right side for layers/compass/recentre (24 px glyphs drawn in code; no kit glyphs exist), plus a 56 FAB "current site" bottom-right.
- Keep the map palette (lake, roads, sites) but bring the paper/surface to the Material dark map style: dark ground `#1A1F1A`, roads `#C2C0AE` at 20-40%, water lake teal 30%, labels 10 px. The current map uses cream lines on dark; it works, just align sizes.
- Top status bar: transparent over the map with a scrim (map apps tint the status bar dark).

### 9.8 In-OS Settings (new, small)

Android needs a settings destination reachable from the shade gear. Add a small system page (not a home app): title "Settings" 22; rows 72 tall: `Phone messages` switch (kit `controls/switch_on/off/knob`), `Phone style` (Android / iPhone, existing `hud.phone_style`), `Battery saver` switch (existing camera effects toggle if safe), `About`: device name "Halloway Personal", OS build line (in-universe, e.g. `Halloway OS 4.2 · valley build`), wallpaper credit (USDA NRCS, keep the credit here instead of on the home widget), and `Signals`: LINK, relay, tablet battery. Use kit switches; rows separated by 1 px outline dividers; 16 px margins. The pause-menu copies of these two phone toggles can stay as a fallback but the OS should mirror them (`hud.phone_notes`, `hud.phone_style`), not duplicate state.

### 9.9 Copy and universe guardrails

- No `Android`, `Google`, `Pixel`, `Material`, `Wi-Fi` brand text? Wi-Fi is a generic term and fine; avoid Android/Google product names. "Halloway Personal" as the device name is in-universe and reads like an OEM skin name.
- Remove `HALLOWAY PERSONAL` from the current system bar (section 3); it becomes the Settings device name.
- Status bar `HALLOWAY VALLEY` carrier text: removed (section 2).
- `Put phone away (Tab)` stays as a desktop hint only in the keyboard guide, not as an Android UI label.
- The valley/autumn identity stays in the wallpaper, the field-note widget, the app accents and the copy - not in fake Android chrome.

## 10. The five highest-impact defects and exact fix sites

Ranked by how much each blocks "looks like a modern Android tablet". Line numbers from the current tree; function names are stable.

### 10.1 The launcher is a desktop, not a launcher

Evidence: `docs/realism/phone_ui/00_home.jpg` and `docs/realism/tablet/00_tablet_desktop.jpg` - 3-column grid, giant clock top-left, 320-360 px field-note card on the right, category captions under every icon, a 7th icon alone on row 3, a tip strip, and Home/Recents text buttons in the dock row. No page dots, no app drawer, no wallpaper brightness.

Fix sites: `phone_os.gd::_build()` lines ~131-316 (home subtree), `_show_home()`, `_show_switcher()` (Recents), and `_refresh()` for the widget text. Rebuild as section 4: wallpaper + vignette + short top scrim; At a Glance widget; field-note 2x2 widget; 5-column centred grid with 56-64 px icons and 12 px labels; no category captions; page dots; a separate 84 px dock with 5 icons using `polish/dock_tray.png`; app drawer; second page.

### 10.2 System chrome is a toolbar, and the status bar shows wallpaper through apps

Evidence: `01_casebook_overview.jpg` - wallpaper visible across the top 38 px inside the Casebook; a 54 px bottom bar with `Home`, `CASebook · HALLOWAY PERSONAL`, `Recents`, `Put away`; apps draw their own desktop headers and only the Casebook has a `Back` text button. The status bar has a centred fake carrier and a text battery/link.

Fix sites: `phone_os.gd::_build()` lines ~110-130 (status bar), `_build_system_nav()` (replace entirely with a 24 px gesture nav + pill), `_update_system_nav()` (delete), `_apps` insets (line ~330), `_add_device_frame()` (size/aspect fix), `_input()` (back/home/shade gestures). Every app's `_build()`/`_app_bar()` gets a 56 px top app bar and a 48 px back arrow: `chat_app.gd::_build()`, `studio_app.gd::_build()`, `casebook_app.gd::_app_bar()`/`_rail()`, `marketplace_app.gd::_build()`, `map_app.gd::_build()`, `photo_library.gd::_build_ui()`.

### 10.3 Notifications and quick settings are not part of the OS

Evidence: `docs/realism/ui_review/04_notifications.jpg` - a separate top sheet with blue links, hand-drawn icons, no clock, no QS, no status-bar icons; and `phone_notes.gd::setup()` puts the whole layer at 20, under `PhoneOS` at 28, so the OS shows no notifications at all. In-flight: `phone_os.gd` line 681/689 still writes `LINK · %` over the new icons.

Fix sites: `phone_notes.gd::setup()` (layer >= 34, set the UniverseUI theme, Inter weights), `_build_shade()` (two-pane shade + QS + clock + status icons), `_build_pill()` (delete or replace with status-bar icons), `_update_pill()`, `_build_android_card()` (kit mono icons, 24 radius, 72 row), `_base_card()`, `AppIcon` inner class. `phone_os.gd::_refresh()`/`set_battery()` (remove `LINK · %`, add percentage next to the battery glyph). `main.gd` lines 439-442 already route `app_requested` correctly; keep. Add swipe/tap entry: `hud.gd::layout_for()` phone + bell buttons.

### 10.4 The kit is only half wired, and the most visible pieces are still placeholders

Evidence: kit art is now used for 12 app icons and three status glyphs, but: Map has no kit icon (falls back to the code-drawn glyph); `TabletIcon` always loads the 128 export and blits to 40 px (aliasing); `TabletDial` still draws both dials in code while the kit ships `dial_wind_face`, `dial_battery_face`, needles and fills; `dock_tray`, `page_dot_on/off`, `wallpaper_vignette`, `switch_*`, `slider_*`, `button_*`, `radio/check`, `search_pill`, weather glyphs are unused; `phone_notes` still draws its own app icons; the `ui_theme.gd::app_icon()` hook still checks the dead path `res://assets/ui/icon_<key>.png`, not the kit path.

Fix sites: `ui_theme.gd::app_icon()`/`app_colour()`/`make_theme()` (add `font()`, Material tokens, kit loader that picks the right export); `tablet_icon.gd::set_kind()`/`_draw()` (size-appropriate export, add `"map"` fallback, badge support); `tablet_dial.gd::_draw()` (switch to kit face + needle + fill; the kit contract: needle rotates about (256,256), battery arc starts 150 degrees, 240 degrees clockwise, radius 176, width 32; use a `TextureProgressBar` with `dial_battery_fill*`); `phone_notes.gd` AppIcon; `phone_os.gd` home/dock/drawer/QS to consume the kit. Add the missing Map icon in the sibling generator: `AeroSim/godot/tools/ui_art/gen_icons.py` `ICONS` list (12 entries) plus an `fg_map` (folded map, route, pin), then `python build_all.py` and copy the new `icon_map*` files into this lane. The generator is not in this lane; copying `tools/ui_art` over is optional.

### 10.5 Geometry is not scale-safe, and touch cannot reach the OS

Evidence: 40/54/44/96/320/430 px constants with no `u`; `_add_device_frame()` picks the wrong export (logical width never exceeds 1600) and stretches on 16:10; `phone_notes` card width/heads-up offsets are absolute; the phone opens only via `Tab` and the shade only via `N` (`main.gd::_unhandled_key_input()`), so a tablet player cannot open either. Touch targets: chips 24 px, buttons 32-38 px, dock 44 px - all below Android's 48 px minimum.

Fix sites: `phone_os.gd` all layout constants -> `* u`; `_add_device_frame()` -> physical window size + aspect guard (or default off); `phone_notes.gd::update()` `_card_w = clampf(vp.x * 0.35, 360, 470)` and `target_y = 30.0 + 11.0 * i` -> safe-area/u based; `hud.gd::layout_for()` add phone/bell buttons (`_place` pattern) and connect `phone_os.toggle()` / `phone_notes.toggle_shade()`; `main.gd` keep keyboard, no change beyond wiring; `ui_theme.gd` touch minimums/button heights.

### 10.6 Quick wins (30-60 minutes each)

1. Delete the `LINK · %` writes (`phone_os.gd` lines 681, 689); status = glyph + `%` text.
2. Delete the full-screen 50% scrim and the full-height gradient; add `wallpaper_vignette.png` + a 96 px top scrim. The home immediately looks like Android and the wallpaper becomes visible.
3. Remove the app category captions (`SERVER`, `CHANNEL`, ...) and the two `9+ NEW`/`N RUSHES` labels from the home grid.
4. Remove `HALLOWAY VALLEY` carrier text and the three duplicated status glyphs after the battery; use kit exports at 18 px.
5. Give every app's `scrim` the app-bar background so the status strip is opaque in apps.
6. `TabletIcon` export selection by size (44/64/128).
7. Set `phone_notes._root.theme = UniverseUI.make_theme()` and Inter FontVariations.
8. Swap notification `X`/link blue (`Color(0.55,0.80,0.95)`) for brass/on-surface-variant.
9. Make every `custom_minimum_size` at least 48 px tall on touch controls.
10. Add the phone + notification buttons to the HUD.

## 11. What cannot be photoreal without new art or assets

State this plainly to the user. These are hard gaps, not polish:

1. **Wallpaper resolution.** `tablet_red_barn.jpg` is 1024x683. At 720p it is upscaled 1.25x, at 1080p 1.875x. A near-photoreal launcher needs a 2560x1440 or larger crop of the same public-domain USDA NRCS source (or a new photograph). The current wall will always look soft on a 1080p+ display. One photo, one page - Android users also expect a wallpaper picker; not needed for the game, but two pages share the same 1024 px wall.
2. **App content art is the biggest gap.** `docs/MODEL-STATUS.md` records **0 of 13** `CLAUDE-*` briefs delivered. Missing, specifically: 10 illustrated avatars (Maya, Jo, Riley, Tom, Alex, Sam, Rennick, Unknown, You, Wren); Facade product photos for every drone/camera/motor/battery; Casebook paper, folder, stamps, timeline nodes and evidence frames; Job requirement badges and stamps; Photos empty-state/album art; VidTube banner; map paper. The Android chrome can be near-identical, but app interiors will read as "game UI with placeholders" until these exist. This is not something a wiring pass can fix.
3. **The icons are painted, not stock-Android.** The kit is warm illustration with gradients, grain and baked shadows. Real Android app icons are crisp flat vectors. At 56-64 px the kit reads as premium fictional apps and is the right trade for the story, but a literal "stock Android" look would need a flat icon set generated from the same silhouettes (the generator's `fg_*` functions can render flat variants; about a day of generator work) or a new icon set.
4. **No Material system glyphs.** The kit has 5 status glyphs, weather glyphs and app tiles; it has no back/home/recents nav glyphs, and no quick-setting glyphs for Bluetooth, Do Not Disturb, airplane, rotation, flashlight, battery saver, screen record, power or gear at 24 px. These must be drawn in code (Material Symbols paths) or added to the generator; hand-drawn curves may not match Robot/Android exactly.
5. **The device frame cannot be photoreal hardware.** The three frames are a simple vector-like bezel (2.5% of height, 16 px corner radius) around a transparent screen, 16:9 only. There are no bezel reflections, antenna lines, buttons, camera rings, speaker perforations or rounded-glass edge. A 16:9 tablet is also not a modern form factor (modern Android tablets are 16:10/3:2/4:3). If the user expects to see a photoreal tablet object in-game, that needs a 3D/photo mockup of a specific tablet, letterboxing to its aspect, and new frame art per aspect - a much larger job, and probably wrong for a full-screen game HUD. The OS screen itself can look photoreal; the hardware cannot.
6. **Material You dynamic colour** (Android 12+ derives the whole palette from the wallpaper) is not implemented and arguably should not be: it would replace the game's pine/brass identity with the red barn's colours. A fixed dark scheme that mirrors Material 3 roles (section 8.3) is the realistic compromise. If true dynamic colour is wanted, it is a code feature (palette extraction from the wallpaper at startup) plus a design decision, not art.
7. **The exact Android system font.** Inter is close but not Roboto. A literal match needs Roboto/Noto Sans (Apache-2.0) bundled; the difference is small at 12-14 px but visible in large titles and the clock.
8. **Video.** VidTube has no video file - the detail screen is a still card by design (`studio_app.gd::_open_video()`). Photoreal media notifications, playback controls, progress and "now playing" art cannot exist without a real video pipeline.
9. **Recents thumbnails.** Android Recents shows real task snapshots. Rendering hidden app viewports per app is expensive in Godot; the spec uses curated summary cards instead (section 5). That reads correctly but is not pixel-identical to Android.
10. **Light/ambient realism.** Screen reflections, glare, rounded-glass refraction, camera cutout shading, haptics and system sounds are outside a 2D CanvasLayer. They would need a 3D device render or platform haptics/audio work.

What *can* be near-identical with the existing art: the geometry, status bar, gesture/3-button nav, icon grid/dock/page dots/drawer, Recents layout, notification shade with QS, dialogs/snackbars, typography scale, surfaces, touch sizes and motion. That is the bulk of what the user recognises as "Android".

## 12. Implementation order and acceptance checklist

### Order

1. **Fix the two in-flight regressions** (`LINK · %`, frame selection/aspect) so the current build does not show contradictory chrome.
2. **System scaffold in `phone_os.gd`:** `u` scale helper, safe/content rects, status bar rewrite, gesture nav + pill, remove `_build_system_nav` text bar, status bar opaque over apps. No visual redesign yet; this alone fixes half the "not Android" read.
3. **Launcher rebuild:** wallpaper treatment, At a Glance + field-note widgets, 5-column grid, labels, page dots, dock, second page, app drawer, badges. Remove category captions and text badges.
4. **Recents rebuild** in `_show_switcher` + `_recent_apps` tracking.
5. **Notifications and shade:** raise layer, theme/Inter, two-pane shade with QS, status icons, mono kit app icons, remove pill, add HUD phone/bell entry points.
6. **Kit completion:** `TabletDial` faces/needles/fills, export selection, Map icon (generator), dock tray/vignette/page dots/controls/search pill, settings page with kit switches.
7. **App chrome pass:** app bars + back arrows, remove wallpaper bleed, Material surfaces, per-app layouts (chat rail, studio FAB, photos grid, jobs list, casebook rail, facade grid/sheet, map sheet).
8. **Dialogs/snackbars/motion:** confirm dialogs for delete/buy, undo snackbar, ripples, container transform, shade/page/heads-up timings.
9. **Final polish:** typography weights/tracking, tabular numbers, contrast, 1080p and 16:10 checks, stale docs update.

### Acceptance checklist

- [ ] At 1280x720 and 1920x1080 (and 1280x800 16:10), the status bar, app bar, content and nav are inside the safe rect; nothing is clipped by the bezel or corners; no app shows wallpaper in the status bar.
- [ ] Status bar: clock left, notification icons, signal/relay/battery right, battery percentage, no carrier, no `LINK · %` regression, 24-hour.
- [ ] Home: wallpaper bright with vignette; 5-column grid; 56-64 px kit icons; one-line labels; no category captions; badges on icons only; page dots; 84 px dock with 5 apps; swipe between two pages; app drawer opens.
- [ ] Icons: every visible app icon is the correct kit export at the correct size (no 128->40 aliasing); Map no longer uses the code glyph; no extra shadow on kit tiles.
- [ ] Recents: Android task cards for opened apps only, not an app-picker dialog; tap opens, swipe dismisses, Clear all works.
- [ ] Notifications: heads-up appears above the OS when open and above the HUD when flying; tap opens the app; status-bar icons appear; shade has clock/date, grouped cards, Clear all, two-pane QS with working DND/battery/night/thermal where applicable; layer above phone OS.
- [ ] Nav: gesture pill, edge-back, swipe-up home, swipe-up-hold Recents; on touch the HUD has a phone button and a bell; Esc/Tab/N still work.
- [ ] Typography: Inter everywhere including notifications and dials; weights regular/medium/semi-bold; type scale per section 8.1; tabular clock and numbers.
- [ ] Touch: every interactive control >= 48x48; chips and buttons >= 40 visual with 48 hit; dialog buttons 48.
- [ ] Dialogs: delete photo and buy item confirm; undo snackbar for delete; no dead destructive button.
- [ ] App names and story copy unchanged; no Android/Google/real-brand text or marks; status/QS text is generic or in-universe.
- [ ] Performance: the OS still opens instantly (no longer than 1 frame + 120 ms fade), no per-frame rebuilding of menus, `_refresh()` not rebuilding strings every frame beyond text set.
- [ ] Saves untouched: no changes to `user://` handling; notification history remains user data.

### Screenshots to capture for the Lead's review

1. Home page 1 (1280x720 and 1920x1080).
2. Home page 2 with widgets, page dots active.
3. App drawer with search.
4. Recents with 3 opened apps.
5. Shade collapsed (notifications) and expanded (QS), over the home and over an app.
6. Each app's top app bar + content, 7 shots.
7. Dialog + snackbar.
8. A 16:10 window (1280x800) home + Casebook to prove the safe-area handling.
9. Flight HUD with a heads-up notification and the phone/bell buttons.

## Appendix A: kit asset map (exact paths)

Base: `res://assets/ui/tablet/`.

| Asset | Use |
|---|---|
| `icons/128/icon_<app>.png` (also 64, 44) | home 64, dock/drawer 56/48, app bar 24-32; choose export by size |
| `icons/layers/icon_<app>_bg.png`, `_fg.png` | optional adaptive compositing/parallax on home |
| `icons/mono/64/icon_<app>_mono.png` | notification cards, heads-up, status-bar notification icons, QS DND tile |
| `status/64/status_signal.png`, `status_wifi.png`, `status_battery.png`, `status_notification.png`, `status_search.png`, `search_mic.png` (+ `_brass`) | status bar 18, QS tiles 24, search pill mic 20; battery % text beside glyph |
| `status/badge_dot.png` (64), `status/badge_unread.png` (96x64) | app icon badges; number drawn on top |
| `dials/dial_wind_face.png`, `dial_needle_wind.png` | field-note wind widget 64 |
| `dials/dial_battery_face.png`, `dial_battery_fill.png` (+ `_amber`, `_rust`), `dial_needle_battery.png` | field-note battery widget 64; arc 150 degrees, 240 clockwise, radius 176, width 32, TextureProgressBar |
| `weather/64/weather_<sun|cloud|rain|storm|fog|snow|wind|moon>.png` | home weather widget, status weather line, QS cosmetic tiles |
| `polish/wallpaper_vignette.png` | wallpaper edge treatment (1920x1080, stretch) |
| `polish/dock_tray.png` | dock nine-patch 512x128, content margins 44 |
| `polish/page_dot_on.png`, `page_dot_off.png` | page dots 8 px |
| `controls/switch_on/off.png`, `switch_knob(_on)` | Settings rows / QS switches |
| `controls/slider_track/fill/knob.png` | brightness slider, progress |
| `controls/button_primary/ghost/card(_pressed).png` | app CTAs/dialog actions (9-patch, 32 px margins) |
| `controls/radio_on/off.png`, `check_on/off/mixed.png` | Settings rows, job filters |
| `controls/search_pill.png` | app drawer search, Facade/Map search |
| `frame/tablet_frame_1280x720.png` / `_1920x1080` / `_2560x1440` | optional device bezel (16:9 only; section 1.4) |
| `Inter.woff2` | theme default font (in flight) |

Not in the kit, must be drawn or generated: Map icon, nav bar glyphs (back/home/recents), QS tile glyphs (Bluetooth, DND, airplane, rotation, flashlight, battery saver, screen record, power, gear 24 px), Material dialogs (draw with styleboxes), ripples, snackbars, bottom sheets, recents cards, widget layouts.

Generator, if new icons are wanted: `AeroSim/godot/tools/ui_art/gen_icons.py` `ICONS` list (12 entries) plus `fg_map`; `build_all.py` regenerates everything in about 5 minutes; copy the PNGs (and `.import` files or let Godot import) into this lane. The generator requires Python + Pillow + numpy and the bundled Inter font.

## Appendix B: measured facts used in this spec

- `project.godot`: viewport 1280x720, `stretch/mode=canvas_items`, `aspect=expand`, `handheld/orientation=4`, renderer `forward_plus` (mobile `mobile`, web `gl_compatibility`).
- Wallpaper: `assets/ui/tablet_red_barn.jpg`, 1024x683 RGB (upscaled to 1244x684 in the frame, so already ~1.2x soft).
- Frame exports: 1280x720 (bezel 18, screen 1244x684, corner radius ~16), 1920x1080 (bezel 26, 1868x1028, radius ~23), 2560x1440 (bezel 35, 2490x1370, radius ~31). Screen area transparent; camera/speaker in the top bezel only.
- App icon exports: 512, 128, 64, 44; bg full bleed; fg bbox x 125..387 of 512 (51%, inside the 66% safe zone); mono exports 512/128/64/44; composite tiles bake a <=8 px shadow and a rounded-square body (corner radius roughly 20/128 at the 128 export).
- Status glyphs 64 px with content bbox 40-63 px depending on glyph; cream variants approximately `#EFE8D0`/`#FFFAE0`; brass variants exist.
- Controls: switch 104x64; slider track/fill 256x64 (12 px groove, 32 px stretch margins); buttons 192x96 (9-patch 32); search pill 640x96 (margins 48); radio/check 64; badge dot 64; badge pill 96x64.
- Dials: 512 faces, needle pivot (256,256); battery arc start 150 degrees, 240 degrees clockwise, radius 176, width 32 (kit README contract).
- Vignette: 1920x1080, warm umber `#22160C` at alpha 117 (~46%) at the edges, 0 at the centre; designed to overlay the wallpaper.
- Existing code that must keep working: `main.gd` keyboard (`Tab` phone, `N` shade, `Esc` back), `main.gd` `phone_notes.app_requested` -> `phone_os.open()/_open_app()`, `phone_os.set_battery()` from `main.gd` (feed the widget dial, not the status battery), `phone_notes.update(delta, paused)` each frame, `hud.phone_notes`/`hud.phone_style` toggles, the debug screenshot keys in `main.gd` lines ~1180-1290.
- Screenshot evidence used: `docs/realism/phone_ui/00_home.jpg`, `01_casebook_overview.jpg`, `04_chat.jpg`; `docs/realism/tablet/00_tablet_desktop.jpg`, `01_recents.jpg`; `docs/realism/phone/10_ui_pass_home.jpg`, `12_ui_pass_chat.jpg`, `13_ui_pass_studio.jpg`, `18_facade_home.jpg`; `docs/realism/ui_review/04_notifications.jpg`; kit contact sheet in the sibling checkout `AeroSim/godot/docs/realism/models/tablet_ui_final_views.jpg`.

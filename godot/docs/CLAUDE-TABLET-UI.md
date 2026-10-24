# Claude tablet UI asset brief

Status: production request, 2026-11-10. The tablet desktop now uses a real public-domain aerial red-barn photograph as its wallpaper, with a credit line on the home screen. The layout, app icons and instrument dials are currently drawn in code. Claude is asked for the polished 2D icon and control kit that replaces those placeholders and makes the desktop feel like a real Android tablet in the AeroSim universe.

## Current build

- Home screen wallpaper: `assets/ui/tablet_red_barn.jpg`, USDA NRCS aerial view of Mt. Toby Farm by Lance Cheung, public domain. Credit shown on screen and in `assets/ui/TABLET-WALLPAPER-CREDIT.txt`.
- Code-drawn icons: `game/tablet_icon.gd` (DroneBudz, VidTube Studio, Photos, Jobs, Casebook, Facade, Settings).
- Code-drawn dials: `game/tablet_dial.gd` (wind compass, drone battery gauge).
- Palette: deep pine, warm paper, brass, moss, lake teal, rust. See `docs/UI-STYLE.md`.
- What is missing is the finish: real-looking adaptive icons, layered widget faces, status-bar glyphs and physical controls.

## Priority 0: the icon set

One icon per app, made as an Android-style adaptive icon: a background layer and a foreground layer, or one 512 x 512 PNG with alpha. Same visual weight at 44 px in the dock and 108 px on the home screen.

| Asset | Description |
|---|---|
| `icon_dronebudz` | A speech bubble with a small drone silhouette inside. Moss and cream. |
| `icon_vidtube` | A play mark in a soft frame, rust and cream. Fictional VidTube, not the real logo. |
| `icon_photos` | An aperture or camera with a valley line, lake teal. |
| `icon_jobs` | A clipboard with a checklist and one brass pin. |
| `icon_casebook` | A case folder with a brass tab and a small evidence seal. Slate blue and brass. |
| `icon_facade` | A price tag or awning, MugShot Motors brass and rust. |
| `icon_settings` | A simple gear with a brass centre. |
| `icon_recents` | A stack of rounded app cards. |
| `icon_weather` | A cloud, wind line and small sun. |
| `icon_camera` | A lens ring and a small hill horizon. |
| `icon_home` | A simple house or home pad. |
| `icon_phone` | A handset or tablet outline. |

Style: rounded-square base, warm pine surface, subtle top-left highlight and lower shadow, 1 to 2 px warm hairline, no real Android, Google or social-media marks. The app identity colours above are the intended accents.

## Priority 0: widget faces and dials

Transparent PNG or SVG, 512 x 512, designed to sit on the home card.

- `dial_wind_face` compass rose, ticks, N/E/S/W, quiet brass ring.
- `dial_battery_face` arc gauge with an empty track and a filled track for 0 to 100 percent.
- `dial_needle_wind` and `dial_needle_battery` as separate layers, or one face with a clean needle area.
- `widget_weather_face` a small weather glyph set: sun, cloud, rain, storm, fog, snow, wind.
- `status_wifi`, `status_signal`, `status_battery`, `status_notification`, `status_search` 64 and 128 px, cream or brass, for the tablet status bar.
- `badge_dot` and `badge_unread` small notification marks.

The code can animate the needle and fill the battery arc, so flat faces and separate needles are better than baked screenshots.

## Priority 1: controls

- `switch_on`, `switch_off` and `switch_knob` for Android-style toggles.
- `slider_track`, `slider_fill` and `slider_knob` 2x assets, 64 px high.
- `button_primary`, `button_ghost`, `button_card` nine-patch or SVG frames in the palette.
- A small set of radio and checkbox marks for the settings pages.
- A rounded search pill and a microphone glyph for the desktop search bar.

## Priority 1: tablet frame (optional)

A 16:9 tablet chassis overlay: rounded screen corners, a thin dark bezel, a front camera and a speaker slot. This can sit on top of the whole phone UI and make it read as a physical tablet without changing any layout. It must be transparent in the screen area and safe for 1280 x 720, 1920 x 1080 and 2560 x 1440.

## Priority 2: extra polish

- A small set of home-screen page dots and a dock tray texture.
- A subtle vignette or warm edge overlay for the wallpaper that keeps the photo visible.
- Monochrome versions of the app icons for the notification shade.

## Technical contract

- PNG with alpha, 512 px source and 128, 64 and 44 px exports. SVG source if easy.
- No baked drop shadows larger than 8 px; the UI can add its own.
- Keep icons inside a 66 percent safe zone for adaptive masks.
- Transparent backgrounds except where the icon itself is the rounded tile.
- Fictional branding only. No real Android, Google, VidTube or Facebook marks. The game's VidTube is fictional.
- Name files exactly as above so the code can load them without a mapping table.

## What this unlocks

- Replace the code-drawn app glyphs with a real tablet icon set.
- Replace the two line-art dial faces with widget faces and separate needles.
- Give the tablet status bar real glyphs and the settings pages real switches and sliders.
- Optionally frame the whole phone UI as a tablet.

The layout, wallpaper, photo credit, live battery dial, wind dial and app launch logic are already in code. The requested assets are the finish, not the structure.

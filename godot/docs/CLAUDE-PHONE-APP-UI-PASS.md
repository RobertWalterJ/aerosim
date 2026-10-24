# Claude phone app UI asset brief: the pass after the layout rebuild

Status: second production request, 2026-11-15. The phone system UI and the Casebook have been rebuilt as a proper tablet app shell: a persistent system bar, a bottom Home/Recents/Put away bar, a case-file rail with Overview, Evidence, Chapters and Contacts, photo evidence tiles, case-stamp slots and optional Claude art hooks. This brief asks for the remaining 2D assets that turn the code-built shell into a finished, believable app suite.

Owner of layout and code: session B. Claude handles the art only. The code already loads the files below by exact path and falls back to the drawn placeholder when they are missing.

## What exists now

- `game/phone_os.gd`: tablet home, app switcher, persistent status bar, bottom system bar, insets for every app.
- `game/ui_theme.gd`: `UniverseUI.app_icon(key)`, `UniverseUI.avatar(key)`, `UniverseUI.case_art(key)`. These are the three asset hooks.
- `game/casebook_app.gd`: constabulary app bar, case-file rail, Overview, Evidence, Chapters and Contacts, closure card.
- `game/chat_app.gd`: the same avatar hook for every message.
- `docs/CLAUDE-TABLET-UI.md` already asks for the adaptive app icon set, dials and general controls.
- `docs/CLAUDE-APP-ASSETS.md` already asks for portraits, product tiles, act stamps, evidence stamps and channel badges.

This brief is the delta: the app-specific pieces that make each screen read as a real app, plus the system pieces still missing.

## Shared contract

- PNG with alpha, 2x resolution. Icons at 24, 32, 48, 64, 96 and 128 px where useful.
- One visual family across all apps. Warm rural field-kit palette from `docs/UI-STYLE.md`: deep pine, warm paper, brass, moss, lake teal, rust.
- No baked text, no real Android, Google, Apple, VidTube or social-media marks. Fictional Halloway branding only.
- Transparent background unless the asset is intentionally a surface or a frame.
- Keep the readable centre inside a 66 percent safe zone.
- Deliver a contact sheet and a manifest with file names, dimensions, pivot and whether the art is 9-patch.
- No generic stock-photo people; use the fictional cast.

## Priority 0: the system and launcher

### App icons

The existing tablet brief lists the glyph set. These must be delivered as files so `UniverseUI.app_icon()` can pick them up:

- `assets/ui/icon_chat.png`
- `assets/ui/icon_studio.png`
- `assets/ui/icon_photos.png`
- `assets/ui/icon_jobs.png`
- `assets/ui/icon_casebook.png`
- `assets/ui/icon_market.png`
- `assets/ui/icon_map.png`
- `assets/ui/icon_settings.png`
- `assets/ui/icon_recents.png`
- `assets/ui/icon_home.png`
- `assets/ui/icon_search.png`

Style: rounded-square tile, warm pine surface, one strong silhouette, 1 to 2 px warm hairline, top-left light, no baked drop shadow larger than 8 px. The app colour is the accent, not a full saturated fill.

### Status bar and navigation glyphs

Cream or brass, transparent, with a quiet line weight:

- `assets/ui/status_signal.png`, `status_wifi.png`, `status_battery.png`, `status_battery_low.png`, `status_notification.png`, `status_search.png`
- `assets/ui/nav_home.png`, `nav_back.png`, `nav_recents.png`, `nav_close.png`, `nav_more.png`
- `assets/ui/badge_dot.png`, `badge_unread.png`, `badge_work.png`
- `assets/ui/page_dot_on.png`, `page_dot_off.png`

These need to read at 18 px. The current code can keep text fallbacks, but the finished system bar should use these glyphs.

## Priority 0: Casebook app kit

The Casebook is now a rail-and-pane case file, not a single sheet. It still needs the material that makes it feel like an official app kept in a drawer.

| Asset | Description | Notes |
|---|---|---|
| `casebook_paper.jpg` | warm off-white recycled paper, faint fibres, no text | 2048 square, tileable or full-bleed |
| `casebook_folder.png` | manila case-folder tab and corner, transparent | 9-patch, warm manila and brass |
| `casebook_tab_overview.png` | tab glyph: file leaf | 24 and 32 px |
| `casebook_tab_evidence.png` | tab glyph: photo and seal | 24 and 32 px |
| `casebook_tab_chapters.png` | tab glyph: numbered timeline | 24 and 32 px |
| `casebook_tab_contacts.png` | tab glyph: two person silhouettes | 24 and 32 px |
| `casebook_stamp_open.png` | ink stamp, CASE OPEN, no readable text | distressed blue-grey ink |
| `casebook_stamp_closed.png` | ink stamp, CASE CLOSED, no readable text | worn red-brown ink |
| `casebook_stamp_evidence.png` | evidence seal, no real crest | 256 px |
| `casebook_photo_frame.png` | cream photo frame with a paper corner | 9-patch for evidence thumbnails |
| `casebook_timeline_node_open.png` | timeline ring, brass | 32 and 64 px |
| `casebook_timeline_node_done.png` | timeline check, moss | 32 and 64 px |
| `casebook_timeline_node_waiting.png` | quiet grey ring | 32 and 64 px |
| `casebook_empty_folder.png` | an empty folder with a paperclip | 512 px, for no-case states |
| `casebook_pin_red.png` | small red evidence pin | 32 px |

Do not create a readable document or fake handwriting. The game supplies every line of case text.

## Priority 1: the other apps

Each app should read as a distinct product with the same underlying OS.

### DroneBudz

- `chat_compose.png`, `chat_attach.png`, `chat_mic.png`, `chat_send.png` 24 and 32 px.
- `chat_channel_hash.png`, `chat_channel_voice.png`, `chat_channel_jobs.png` 24 px.
- `chat_reply_arrow.png`, `chat_pinned.png`, `chat_edited.png` 20 px.
- Optional: a small server banner 1200 x 200, moss and cream, no text.

### VidTube Studio

- `studio_banner.jpg` 1600 x 500, warm rust channel banner, no text.
- `studio_metric_followers.png`, `metric_money.png`, `metric_videos.png`, `metric_views.png` 32 px.
- `studio_play.png`, `studio_upload.png`, `studio_cut.png` 32 px.
- A clean 16:9 thumbnail frame overlay; the game uses real player photos.

### Photos

- `photos_empty.png` 512 px, a quiet empty contact sheet with a paperclip.
- `photos_album.png`, `photos_grid.png`, `photos_detail.png` 24 px.
- `photos_frame_clean.png` 9-patch warm photo border.
- `photos_delete.png`, `photos_share.png` 24 px.

### Jobs

The current job system now has keep-clear, range, framing, retake and pulled states. The app needs matching badges:

- `job_badge_distance.png`, `job_badge_range.png`, `job_badge_frame.png`, `job_badge_retake.png`, `job_badge_pulled.png`, `job_badge_excellent.png` 32 px.
- `job_category_photo.png`, `job_category_farm.png`, `job_category_lake.png`, `job_category_civic.png` 24 px.
- `job_stamp_pulled.png` and `job_stamp_excellent.png` 96 px, ink or brass.
- A small clipboard-with-brass-pin app mark can be reused from the icon set.

### Facade

- Category chips: `facade_drones.png`, `facade_cameras.png`, `facade_power.png`, `facade_parts.png` 24 px.
- Seller strip: `facade_seller_strip.png`, a narrow warm 9-patch with no text.
- A sold/collection mark `facade_sold.png`.

### Map

- `map_paper.jpg` 2048 square, warm survey paper with faint grid and fold lines, no labels.
- `map_pin_current.png`, `map_pin_suggested.png`, `map_pin_locked.png`, `map_pin_open.png` 32 px.
- `map_route_line.png` a 3-px dashed brass line, transparent.
- `map_compass.png` 128 px, quiet brass rose.
- `map_beacon.png` optional small signal mark.

## Priority 1: portraits and people

The portrait set in `docs/CLAUDE-APP-ASSETS.md` is still missing. The new UI hooks check `assets/ui/avatar_<key>.png`. Priority keys:

- `rennick`, `maya`, `jo`, `riley`, `sam`, `alex`, `wren`, `unknown`, `you`.

The Casebook calls Rennick, Wren, Riley, Maya, Jo and Sam by those exact keys. A portrait at 42 px must still read.

## Priority 1: typography

The single biggest remaining lift for believability is type. Please supply open-licence fonts, OFL or CC0:

- `assets/fonts/ui_sans.ttf`: a warm humanist sans with four weights (regular, medium, semibold, bold).
- `assets/fonts/ui_serif.ttf`: a readable book or typewriter serif for the Casebook, two weights.
- `assets/fonts/ui_mono.ttf`: a small numeric mono for times, distances and follower counts.

State the licence in `assets/fonts/LICENSES.md`. If a font is not supplied, the engine stays on its system default.

## Priority 2: tablet frame and polish

- A subtle 16:9 tablet chassis overlay with rounded screen corners, thin dark bezel and a speaker slot. Transparent screen area; safe at 1280 x 720, 1920 x 1080 and 2560 x 1440.
- A soft warm edge vignette for the wallpaper.
- A dock tray texture, 9-patch.
- Monochrome notification versions of the app icons.
- A very quiet paper-grain overlay at 10 to 18 percent for the Casebook and Jobs cards.

## Integration contract

- App icons: `res://assets/ui/icon_<key>.png`, loaded by `UniverseUI.app_icon()`.
- Avatars: `res://assets/ui/avatar_<key>.png`, loaded by `UniverseUI.avatar()` and used by Chat and Casebook.
- Casebook stamps: `res://assets/ui/casebook_stamp_*.png`, `casebook_photo_frame.png`, and the timeline nodes; loaded through `UniverseUI.case_art()`.
- System glyphs: the code has text fallbacks today; when the set lands the status bar and bottom bar should switch to these files.
- Fonts: swap through `UniverseUI.make_theme()` only when the licence is confirmed.
- 9-patch assets must include the patch margins in the manifest.
- Do not bake labels, numbers, names or case text into any asset.

## What is still needed, in one line

Adaptive app icons, the portrait set, the Casebook paper and evidence kit, system status and navigation glyphs, job requirement badges, map pins and paper, a couple of app banners and empty states, and an OFL UI/typewriter font family. The layout, the case-file structure, the real photo evidence and all labels are already in code.

# Claude app asset brief: portraits, product tiles and the Casebook marks

Status: production request, 2026-11-14. The in-game screens are built. This brief covers the final art that replaces the code-drawn placeholders inside the phone apps: portraits, Facade product tiles, Casebook act stamps, notification and channel badges, and optional video thumbnail overlays.

Owner of app layout and code: session B. Claude handles the art only; the code integration stays on this lane.

## Shared contract

- PNG with transparency for UI pieces; 2x resolution for high DPI.
- Warm rural documentary palette: cream, moss, rust, amber, lake blue, charcoal. Match `docs/UI-STYLE.md`.
- Friendly and human, not corporate stock art and not horror.
- No text baked into the image unless specifically listed as a stamp; the game supplies all labels.
- Keep the centre of each icon readable at 24, 48 and 96 px.
- No gore, no weapons, no real people's likenesses.
- Deliver a simple contact sheet with file names and a one-line description for each.

## Priority 0: portraits

Illustrated head-and-shoulders portraits, square, 512 x 512, consistent lighting and crop so they read as one set.

| Asset | Person | Notes |
|---|---|---|
| `avatar_maya.png` | Maya, editor and channel owner | creative, brisk, warm layers, headphones or a notebook |
| `avatar_jo.png` | Jo, events and bookings | practical, clipboard energy, festival lanyard |
| `avatar_riley.png` | Riley, park ranger | fleece, radio, outdoor calm, no uniform insignia |
| `avatar_tom.png` | Tom, storm chaser | weather-beaten, camera strap, excited about clouds |
| `avatar_alex.png` | Alex, Facade seller and tinkerer | workshop background, magnifier or small motor part |
| `avatar_sam.png` | Sam, crew and fixer | utility jacket, pocket tools, dry humour |
| `avatar_rennick.png` | Constable Rennick | older, careful, plain clothes, notebook, quiet authority |
| `avatar_unknown.png` | Unknown account | deliberately obscure, hooded or backlit, no clear face |
| `avatar_you.png` | The pilot | neutral, headset, visor reflection, no fixed gender |
| `avatar_wren.png` | Wren, the lost hiker | young, outdoor layers, tired but hopeful |

At 48 px the portrait should still read as a distinct person. A simple coloured backdrop per person is enough; no detailed scenery.

## Priority 0: Facade product tiles

Square product art, 512 x 512, transparent background, readable as a small card image.

| Asset | Listing | Notes |
|---|---|---|
| `item_raptor.png` | Raptor drone | folded quad, carbon arms, red accent |
| `item_nightowl.png` | Night Owl drone | quiet dark airframe, low-light sensor pod |
| `item_thermal_camera.png` | Thermal camera module | small gimbal pod, lens and heat glow, no flames |
| `item_night_vision.png` | Night vision module | green-phosphor lens, small sensor box |
| `item_battery.png` | Long-range battery | rugged pack, amber charge light |
| `item_motors.png` | Motor upgrade set | four brushless motors, one cutaway |
| `item_props.png` | Low-noise prop set | folded prop pair, matte finish |
| `item_controller.png` | Controller | compact remote with two sticks and a phone cradle |
| `item_repair_kit.png` | Field repair kit | small case, tape, spare arm, hex keys |

### Product tile treatment

- One object, three-quarter view, soft top-left light, subtle contact shadow.
- Category colour accent in the background: camera amber, drone moss, motor rust, battery lake.
- No prices, no logos, no text.

## Priority 1: Casebook marks

| Asset | Use | Notes |
|---|---|---|
| `act_1_waiting.png` | Act 1 stamp | quiet empty-road mark |
| `act_2_lake_car.png` | Act 2 stamp | car shape and lake line |
| `act_3_last_flight.png` | Act 3 stamp | cabin light and tree line |
| `act_4_cabin.png` | Act 4 stamp | cabin, cruiser, torch beam |
| `act_5_end.png` | Act 5 stamp | open valley and rising light |
| `stamp_evidence.png` | Evidence stamp | simple official-looking mark, no real crest |
| `stamp_case_closed.png` | Closed case | simple archival stamp |

Stamps should work at 64 to 180 px, slightly worn, ink on paper, no readable official text.

## Priority 1: badges and notifications

- `badge_rush.png` small film-frame badge for rushes.
- `badge_dm.png` small direct-message badge.
- `badge_job.png` small clipboard badge.
- `badge_story.png` small case-file badge.
- `notify_clip.png`, `notify_video.png`, `notify_photo.png`, `notify_job.png` 64 px glyphs.
- `channel_clips.png`, `channel_town.png`, `channel_weather.png`, `channel_jobs.png` 48 px channel marks.
- `badge_edited.png` small "Maya cut" mark without text.

## Priority 2: video thumbnail overlays

Optional transparent overlays at 1280 x 720 and 480 x 270:

- `thumb_frame_clean.png` thin cream frame and a soft corner vignette.
- `thumb_frame_rust.png` stronger rust corner and a small channel mark.
- `thumb_duration_mask.png` translucent lower-right plate for duration text.
- `thumb_play_plate.png` subtle play glyph plate, no text.

These sit over the player's own captured clip thumbnail. Do not create fake photographic thumbnails; the game uses the player's photos.

## Integration notes

- Portraits can be dropped into the chat/DM data once delivered; for now the game shows coloured initials.
- Product tiles map to `facade_catalog.gd` ids. Keep the file names listed above.
- Act stamps map to the Story Director act numbers. Keep the file names listed above.
- Notification badges are small UI art only; no gameplay logic.
- Everything should feel like one valley app suite, not a set of unrelated icons.

## Verification

- At 48 px the portraits are distinguishable.
- At 96 px the product tiles read as their objects.
- At 64 px the stamps are legible as marks without text.
- All assets have transparent backgrounds except the video overlays.

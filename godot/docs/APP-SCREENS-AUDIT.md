# In-game apps: screens, assets and story director audit

Status: 2026-11-14. This is the checklist behind "are all the screens and assets there?" The answer is: every app screen exists, the story director is now a real system with a player-facing act card, and the remaining missing pieces are mostly final art, not missing functionality.

## The story director

Built in `game/story_director.gd`. It is not a separate app and not a separate mission container. It reads the state of the existing story systems and turns them into one route:

- `StoryArc` owns the Lake Car chapters and evidence.
- `UnknownThread` owns the unknown account.
- `WildlifeCase` owns Riley's night pasture and the thermal tutorial.
- `Finale` owns the last flight.
- `Ending` owns the epilogue and credits.
- `StoryDirector` reads all of them and exposes the current act, the next step, whether the thermal camera is fitted, whether the night pasture is done, and the chapter line.

The player sees it at the top of the Casebook as the **STORY DIRECTOR** card: ACT, a one-line next step, and the THERMAL / NIGHT PASTURE / chapter status strip. The card refreshes when the act changes and whenever the Casebook opens.

## Screens

| Screen | Where | State |
|---|---|---|
| Landing and Story/Sandbox mode | `landing.gd` | built |
| Flight HUD, map, camera, video | `hud.gd`, `minimap.gd` | built |
| Pause menu, settings and effects toggles | `hud.gd` | built |
| Photo gallery and photo detail | `photo_library.gd` | built |
| Phone home and Recents | `phone_os.gd` | built |
| Notification shade and banners | `phone_notes.gd` | built |
| DroneBudz chat, channels, DMs, commands | `chat_app.gd` | built |
| VidTube Studio: metrics, rushes, uploads | `studio_app.gd` | built |
| VidTube video detail | `studio_app.gd` | built |
| Photos app | phone -> photo gallery | built |
| Jobs board | `jobs.gd` | built |
| Casebook: story director, request, evidence, chapters, choice | `casebook_app.gd` | built |
| Facade market and kit | `marketplace_app.gd`, `facade_catalog.gd` | built |
| Night pasture objective card | `wildlife_case.gd` | built |
| Last flight objective card | `finale.gd` | built |
| Ending, epilogue and credits | `ending.gd` | built |
| Thermal and night vision screens | `thermal.gd`, `night_vision.gd` | built |
| Tablet home, app icons, dials, Recents | `phone_os.gd`, `tablet_icon.gd`, `tablet_dial.gd` | built |

## Assets present

- Public-domain tablet wallpaper: aerial red barn, Mt. Toby Farm, Lance Cheung / USDA NRCS, credited on screen.
- Code-drawn app icons, dials, HUD icons, notification icons, drone pictures and market category tiles.
- Real photo thumbnails from the gallery and real clip thumbnails from the rushes.
- Chat avatars as coloured initials, with role names and timestamps.
- All the story evidence is the player's own photographs, so the Casebook uses real captures.
- World, story, wildlife and endgame placeholder props are all in place and playable.

## Known asset gaps and what they need

| Gap | Current placeholder | Needed asset |
|---|---|---|
| Final app icon set | code-drawn layered icons | Claude icon pack for the six apps, in the existing tablet brief |
| Crew and story portraits | coloured initials | 10 illustrated avatars: Maya, Jo, Riley, Tom, Alex, Sam, Rennick, Unknown, You, Wren |
| Facade product art | coloured category tiles | product tiles for every camera, drone, motor and battery listing |
| Casebook stamps and act marks | text and borders | five act stamps, one evidence stamp |
| Notification and channel art | code icons | small notification and channel badges |
| Video thumbnail templates | the player's own thumbnail plus text | optional YouTube-style frame and duration overlays |
| Final world and story models | code placeholders | already requested in the narrative, endgame and wildlife briefs |

The detailed production request is `docs/CLAUDE-APP-ASSETS.md`.

## What is not missing

The story director is not absent; it is now central. Every app has its home, its list and its detail or empty state. There are no dead buttons in the app grid. The Casebook does not depend on a separate mission select; the director card tells the player where they are.

## Honest limits

- The app icons, avatars and Facade product tiles are placeholders until Claude's art lands.
- The story director reads the existing systems; it does not replace them, so a bug in one arc can still show up in the act card.
- The act card has no history log or act-by-act completion list beyond the chapter trail.
- The video detail screen is a still card, not playback, because there is no video file.
- The Casebook request box can still show the last closed request after a case closes, which reads as stale next to the director card.
- Chat has no profile screen or member list beyond the crew roles in the channel header.
- There is no separate Settings app; settings stay in the pause menu.
- The director card is in Casebook only, not on the home screen.

## Questions for Robert

- APP1. Should the story director get its own app icon, or stay as the Casebook act card?
- APP2. Do you want a short act history in the director card, or only the current act and next step?
- APP3. Should the avatars be illustrated portraits, or stylised role badges with no faces?
- APP4. Should Facade product art be photography, illustration, or diagram-style?
- APP5. Do you want a video detail screen with a "play" animation even though there is no video file?

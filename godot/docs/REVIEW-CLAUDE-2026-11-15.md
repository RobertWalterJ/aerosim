# Claude review: model completeness and in-universe UX/message audit

Status: review complete, 2026-11-15. Read-only pass over the Godot project at
`C:\Users\Robert Walter-Joseph\Documents\RWJ Coding Projects\AeroSim-notify\godot`. No game code, assets, saves or board were changed. No commit, no server.

**The answer in one line:** none of the 13 `CLAUDE-*` asset briefs has been delivered — roughly 450–480 named files, zero present — and the most visible in-universe break is the tablet home screen, which shows the real photographer credit, the game mode and a fake static status bar.

The model situation is one sentence: **the only Claude-model loader hook in the whole game is `game/traffic.gd:52-53`.** App icons/avatars/case stamps have their hooks in `game/ui_theme.gd:71-126`. Every other brief needs a code change as well as art.

---

## 1. Model status matrix

Evidence baseline (verified by directory walk, GLB node-name extraction and code grep):

- `assets/` contains only: `audio/` (13 fireworks wav), `env/`, `textures/` (18 PBR material sets), `trees/`, `ui/`, `world/`.
- 23 `.glb` files total: 20 tree LODs, `env/all.glb`, `world/park.glb`, `world/props.glb`.
- `assets/ui/` holds exactly two files: `tablet_red_barn.jpg` and its credit note.
- There is no `assets/traffic/`, `assets/vehicles/`, `assets/story/`, `assets/village/`, `assets/signs/`, `assets/fonts/`.
- `env/all.glb` node names (133) are cemetery and ground-cover families only (headstones, monuments, fences, hedges, meadow clumps).
- `world/park.glb` is one merged `park` node. `world/props.glb` has cemetery props plus seven web-derived `vehicles__N` variants — none with the brief's wheel/lamp node names.
- Only `traffic.gd`, `ui_theme.gd` and a texture hook in `village.gd:353` use `ResourceLoader.exists()`. Nothing else loads optional art.

| Brief | Requested (P0 / total named) | Present | Actual state | Asset hook wired? | Evidence |
|---|---|---|---|---|---|
| `CLAUDE-VEHICLE-ASSETS.md` | 9 / 16 | 0 | Code boxes + wheels + emissive lamp blocks | Fleet only: `traffic.gd:12-16,52-53` | Brief line 3; `traffic.gd` paths; `case_objects.gd:4` "Until Claude's models arrive these are simple code built" |
| `CLAUDE-VILLAGE-ASSETS.md` | 12 / 50 | 0 | Code box buildings, flat roofs, no facade detail | No | `village.gd` (8 Box/Cylinder meshes); `docs/realism/village/01_village_street.jpg` reads as plain sheds at 142 m |
| `CLAUDE-WILDLIFE-ASSETS.md` | 18 / 29 | 0 | Code animal shapes + code thermal shells | No | `wildlife_objects.gd` (8 primitives); `docs/realism/wildlife/*` |
| `CLAUDE-ANTI-DRONE-ASSETS.md` | 14 / 31 | 0 | Code crates/cylinders for mast, shack, hunters | No | `anti_drone.gd` (10 primitives); `docs/realism/anti_drone/00_pike_ridge.jpg` — site barely legible from 71 m |
| `CLAUDE-BOAT-LAUNCH-ASSETS.md` | 16 / 30 | 0 | Code ramp, dock, boat, trailer | No | `boat_launch.gd` (23 primitives); `docs/realism/boat_launch/*` |
| `CLAUDE-CABIN-TRACK-ASSETS.md` | 13 / 25 | 0 | Code track, falls, rocks, cave | No | `cabin_track.gd` (11 primitives); `docs/realism/cabin_track/*` |
| `CLAUDE-INTERSECTION-ASSETS.md` | 12 / 24 | 0 | Code poles, box cable, emissive spheres | No | `intersection_signals.gd` (8 primitives); `docs/realism/intersections/*` |
| `CLAUDE-LOCATION-SIGNS-ASSETS.md` | 8 / 25 | 0 | Label3D text on code posts | No | `landmark_signs.gd` (7 primitives); `docs/realism/location_signs/*` |
| `CLAUDE-ROAD-SIGNS-ASSETS.md` | 16 / 31 | 0 | Label3D text on code plates | No | `road_signs.gd` (8 primitives); `docs/realism/road_signs/*` |
| `CLAUDE-ROAD-SURFACE-ASSETS.md` | 5 asphalt + 12 markings / 31 | **6 base textures** | Baseline photographic asphalt/gravel present; requested seamless set and marking kit missing; markings are code meshes | Shader inputs only | `assets/textures/asphalt_{diff,nor,arm}.jpg`, `gravel_{diff,nor,arm}.jpg`; brief lines 9-13 |
| `CLAUDE-APP-ASSETS.md` | 26 / 47 | 0 | Initials avatars, drawn tiles and stamps | **Yes**: `ui_theme.gd:77,80,113` | `assets/ui` has 2 files; `ui_theme.gd:91-110,112-126` fallbacks |
| `CLAUDE-PHONE-APP-UI-PASS.md` | ~45 / ~108 | 0 | Drawn icons, text glyphs, system font | Icons/avatars/stamps yes; glyphs and fonts no | `ui_theme.gd:72-126`; no `assets/fonts`; `ThemeDB.fallback_font` at `phone_notes.gd:114,120` |
| `CLAUDE-TABLET-UI.md` | 20 / ~33 | 0 | Drawn adaptive icons and dials | Yes for icons only | `tablet_icon.gd`, `tablet_dial.gd`; `docs/realism/tablet/*`, `docs/realism/phone_ui/00_home.jpg` |

**Nothing in any brief is present, so nothing can be called done.** The only model file that exists and is wired is the tree/cemetery set, and that predates the briefs.

### The three worst model gaps

1. **The vehicles, including the car the game is named after.** Roads are the most-flown surface in the valley, and every car on them is a box with emissive lamp blocks (the brief's own words). Worse, the Lake Car, the festival bus and the police cruiser are code-built primitives in `case_objects.gd` — the title object of the whole story is a placeholder.
2. **The village.** Nine flat-roofed box buildings and code street furniture are the new hub east of the cemetery, and they read as sheds from the air (screenshot above). This is the largest single art gap by file count (50) and the most story-visible new location.
3. **The app and tablet 2D kit, plus type.** Every icon, portrait, stamp and product tile is drawn in code and the whole UI runs on Godot's system font. The tablet is where most of the game is read, so this gap is felt on every screen, and the briefs themselves call the font "the single biggest remaining lift for believability".

Runners-up worth scheduling early: the anti-drone ridge (a story hazard that is currently not readable as hostile hardware), the wildlife set (the thermal-camera showcase), and the road-surface marking kit (affects every frame from the air).

---

## 2. UX/UI findings, worst first

**U1 (high) — Every notification is branded DroneBudz, whatever actually sent it.**
The heads-up card, shade header and group row hardcode the app name and icon (`phone_notes.gd:309`, `:548`, `:611`). But senders include `VidTube` (`jobs.gd:214,271,321`), `Rennick` and `Riley` (`story_arc.gd:180,237`, `anti_drone.gd:114`, `wildlife_case.gd:77`), `Unknown` and `Kit`. The title line is built as `"sender: title"` (`phone_notes.gd:357,694`), so a VidTube payout reads as **"DroneBudz · VidTube: Your video is live…"** and a case note as **"DroneBudz · Rennick: Casebook: A favour"** — three brand layers on one banner, two of them wrong.

**U2 (high) — The tablet home screen shows the real world and the game mode.**
On one screen (`docs/realism/phone_ui/00_home.jpg`):
- "Photo: Lance Cheung / USDA NRCS · public domain" (`phone_os.gd:214`) — a real photographer credit inside a fictional pilot's tablet.
- "SANDBOX · weather controls unlocked" (`phone_os.gd:662`) — game-mode copy in the fiction.
- "LTE ▮▮▮ 100%" (`phone_os.gd:128`) — a hardcoded, never-updating status bar, next to a live drone battery dial.
- "AUTUMN · NORTH VALLEY · 47°N" (`phone_os.gd:147`) — 47°N is southern Europe, not the British-leaning valley the vehicle brief describes.

**U3 (high) — The unread counter balloons to absurd numbers.**
The home icon reads "1158 NEW" and the chat sidebar reads #town 35, #clips 29 (`phone_ui/00_home.jpg`, `phone/12_ui_pass_chat.jpg`). Every unattended post increments a lifetime counter (`chat_data.gd:64-70`); it only resets for the channel being opened (`chat_data.gd:54-62`), and crew chatter posts on a timer. The home badge sums all of them (`phone_os.gd:646-648`). It reads as a broken app, not a lived-in one.

**U4 (medium-high) — Story chat messages are posted twice.**
Each chapter's crew "beats" are posted when the chapter begins (`story_arc.gd:176-178`) and posted again when it completes (`story_arc.gd:228-229`). The duplication is visible in `docs/realism/phone/12_ui_pass_chat.jpg`: Jo's "If he gets that bus running…" and "The bus led the parade…" each appear twice.

**U5 (medium) — Game instructions live inside in-universe apps.**
- Casebook: "Story and jobs are switched off in Display > Overlay and sound. The case will wait." (`casebook_app.gd:284`)
- Jobs: the same pause-menu path (`jobs.gd:747`)
- Photos: "Photos stay in the game." (`photo_library.gd:172`)
- Facade: a product tile captioned "Press K in flight" (`marketplace_app.gd:223`)

These put the settings hierarchy and keyboard keys into apps that characters supposedly built. The pause menu is the right home for all of it.

**U6 (medium) — The settings page has duplicate controls and two labels per action.**
Header "Done" (`hud.gd:469`) and footer "Resume flight" (`hud.gd:509`) do the same thing; "Exit game" (`hud.gd:502`) and "Quit" (`hud.gd:779`) also duplicate. "Reset drone to the start" (`hud.gd:564`) is a debug phrase in an otherwise in-world app. This contradicts `UI-STYLE.md:45` ("Exactly one [primary] per screen").

**U7 (medium) — Esc inside the tablet closes it instead of leaving the app.**
`phone_os.gd:679-684` calls `close()` from any app, but `UI-STYLE.md:61` says "Esc still leaves an app". There is no keyboard route back to the home screen; the player must click Home.

**U8 (medium) — The status-bar clock and battery freeze inside apps.**
`phone_os.gd:686-688` refreshes only when the home screen is current, so the clock stops at the moment an app opens. The status battery is not connected to the drone battery at all (`phone_os.gd:128`), while a live drone dial sits on the home card.

**U9 (medium) — The keyboard guide omits four documented controls.**
`keyboard_guide.gd:34-36` leaves Tab, T, K and N unlit and unlabelled, although Tab is the tablet (`phone_os.gd:382`), T and K are the thermal and night cameras (`main.gd:1056-1066`), and N is the notification centre (`phone_notes.gd:11-12`). Kit's own tips cite Tab, T and K (`guide_coach.gd:130-134`), so the guide contradicts the coach.

**U10 (medium) — Chat metadata is below the style guide's floor.**
Roles render at 8 px in `FAINT` and times at 9 px in `FAINT` (`chat_app.gd:299,302`; colour `ui_theme.gd:21`). `UI-STYLE.md:36` says small caps are 9–11 px. Long roles such as "EDITOR AND CHANNEL OWNER" are hard to read in the screenshot.

**U11 (low-medium) — Participant counts are hardcoded and wrong.**
"6 CREW" in the chat header (`chat_app.gd:139,242`) shows in #town where Rennick posts, and the server has nine named participants including Kit and Unknown (`chat_data.gd:25-36`).

**U12 (low) — Notification titles duplicate their own sender or body.**
`world_life.gd:224` sends sender `DroneBudz` with title "You found …" in an app-badged banner (app name twice), and the railway note near-repeats the title in the body (`world_life.gd:29`). Job titles carry metrics ("Your shot is live: +N followers, +N money", `jobs.gd:634-639`) and are then clipped by `clip_text` (`phone_notes.gd:361-362`).

**U13 (low) — Home screen repeats itself.**
Weather and money appear twice (`phone_os.gd:643` vs `:652`), Home/Recents buttons appear in both dock and system bar (`phone_os.gd:288-295,409-425`), and "Home" on the home screen is a dead button.

**U14 (low) — Style drift in the flight HUD.**
The HUD theme still uses cool blue pressed states and a blue slider fill (`hud.gd:176,185,190`) while `UI-STYLE.md:75` says "The old cool cyan is gone" and `MenuStyle` is brass (`menu_style.gd:11`). Visible on the gimbal slider.

**U15 (low) — Currency and economy vocabulary are inconsistent.**
"$" (`chat_app.gd:229`, `phone_os.gd:645`, `marketplace_app.gd:74,205`, `studio_app.gd:367`), "MONEY" (`studio_app.gd:117`), "channel pot" (`marketplace_app.gd:73`, `crew.gd:177`) and literal "money" as a unit (`jobs.gd:634,637,644`; `casebook_app.gd:545`) all describe the same quantity. "$" also sits oddly beside a constabulary and right-hand-drive traffic.

**U16 (trivial) — Minimap waypoint label can clip.**
`minimap.gd:97-99` draws the label at the clamped edge while `clip_contents` is on (`minimap.gd:25`).

---

## 3. Message findings

**M1 (high) — Duplicate story beats.** Same root cause as U4: every chapter's beats post twice (`story_arc.gd:176-178` and `:228-229`). Confirmed on screen in `docs/realism/phone/12_ui_pass_chat.jpg`.

**M2 (high) — A character sends the app's metrics, in game units.**
A job's contact is the notification sender, but the title and body are VidTube copy: "Your shot is live: +12 followers, +40 money" and "I have sent a 25 money bonus" (`jobs.gd:632-641`). Same pattern at `:644`. The fix in `MESSAGE-VOICE.md` made the chat lines first person, but the notes still mix character sender + app phrasing + economy units.

**M3 (high) — "A message" is the title of every ghost notification.**
`finale.gd:189-191` titles all ghost notes "A message", and `finale.gd:178-184` fires six of them in one burst. The player gets several identical "Rennick · A message" rows with no way to tell them apart. This replaced the old "Rennick: Rennick" duplicate but overcorrected into non-unique titles.

**M4 (high) — App instructions still come out of characters' mouths.**
- Jo: "Take one in Flight > DroneBudz jobs." (`crew.gd:189`) — exactly the phrase `MESSAGE-VOICE.md:36` says was removed from job notes, still live in Jo's chat reply.
- Riley's note: "Fly the west pasture with T on and find the wolf." (`wildlife_case.gd:77`) — a keyboard key in a character's voice. Her chat line at `:75` is clean, so the note is the offender.

**M5 (medium) — Second-person app notices sit in a character sender.**
`world_life.gd:224` sends `DroneBudz` as sender with a "You found …" title and the place note as body. The app voice is per `MESSAGE-VOICE.md:23`, but because the banner is also DroneBudz the result is doubled branding (U12).

**M6 (medium) — The pilot is gendered male in the opening chat.**
Sam: "Lay off him… His uncle just passed"; Maya: "Leave him be. He flies better when he is quiet." (`chat_data.gd:111-112`). The portrait brief specifies `avatar_you` with "no fixed gender" (`CLAUDE-APP-ASSETS.md:32`). This is other characters' dialogue rather than self-reference, but it fixes the player's gender and conflicts with the art brief.

**M7 (medium) — Job failure lines are first person but render anonymously.**
`jobs.gd:486-497` now writes "I called. You went right over the graves…" as the contact, but posts it with `system=true`, and system rows ignore the sender name (`chat_app.gd:278-284`). The fix changed the words but the chat shows "◈ I called…" with no visible speaker.

**M8 (medium) — One event, three phrasings.**
The jammer going down is "Pike's jammer mast came down in the storm last night" (`anti_drone.gd:111`), "Pike's jammer is down" (`anti_drone.gd:114`), and "Pike's jammer is off us now" (`finale.gd:178`). Also a HUD toast puts the sender inside the text — "Rennick: Pike jammer is down…" — while the source line already says DRONEBUDZ (`anti_drone.gd:115`).

**M9 (low) — Naming drift for the same person.**
"The constable will get in touch" (`story_director.gd:63`) vs "Rennick will get in touch" (`casebook_app.gd:287`). App text may be third person (`MESSAGE-VOICE.md:49`), but it should pick one name.

**M10 (low) — Duplicate title across publish paths.**
"Your video is live" is used for both photo and clip uploads (`jobs.gd:214` and `:271`), and "Your cut is live" for rushes (`:321`). Not a runtime duplicate, but one event with three names.

Verified clean: Rennick's chapter requests are consistently first person (`story_arc.gd:21,33,45,57,69,84`); the Unknown account stays lower-case and fragmented (`unknown_thread.gd:17-50`); Kit is first-person support and its app paths are in character as per `MESSAGE-VOICE.md:21`; "The constable has one more favour", "Rennick has the photographs" and "Open Flight > DroneBudz jobs" no longer appear in notes.

---

## 4. Prioritized fix list for the Lead

Code fixes, cheapest first. All are session-B-owned.

1. **Give each notification an owning app.** Add an app key to `PhoneNotes.post_text`/`_add`, render the app name and icon from it, and group by app. Update the call sites in `jobs.gd`, `story_arc.gd`, `anti_drone.gd`, `wildlife_case.gd`, `world_life.gd`, `guide_coach.gd`. (`phone_notes.gd:295-338,548,611`)
2. **Clean the tablet home.** Drop the "SANDBOX…" mode line; move the USDA credit to the ending/credits surface and keep only the licence file; drive the status bar battery and clock from live data; correct `47°N`. (`phone_os.gd:128,147,214,662`; `phone_os.gd:686-688`)
3. **Stop duplicate story beats.** Post beats at one moment only — completion is the better place. (`story_arc.gd:176-178,228-229`)
4. **Cap and clear unread correctly.** Reset per-channel unread when read, cap the visible badge ("9+"), and stop summing unreviewed chatter on the home icon. (`chat_data.gd:54-70`; `phone_os.gd:646-648`)
5. **Move all game-instruction copy to the pause menu.** Remove the `Display > Overlay and sound` strings and "in the game" from the apps; keep one settings route. (`casebook_app.gd:284`; `jobs.gd:747`; `photo_library.gd:172`; `marketplace_app.gd:223`)
6. **Unify the voice rule in notes.** Character sender → character-voiced title/body, no metrics; app sender → app voice, unique title. Fix M2, M3, M5, M7, M8. (`jobs.gd:632-644`; `finale.gd:189-191`; `world_life.gd:224`; `anti_drone.gd:111-115`)
7. **Remove app instructions from characters.** Rewrite `crew.gd:189` (Jo) and `wildlife_case.gd:77` (Riley). Add a neutral "how to accept a job" line to Kit instead.
8. **Fix navigation and the keyboard guide.** Make Esc return to Home from any app, then close the tablet on Home; add Tab, T, K, N to `keyboard_guide.gd`. (`phone_os.gd:679-684`; `keyboard_guide.gd:34-36`)
9. **Delete duplicate exits and debug phrased actions.** One "Done", one quit path, rename "Reset drone to the start". (`hud.gd:469,502,509,564,779`)
10. **Pick one currency and one unit.** £ or $, "pot" for the channel balance, never "money" inside a sentence. (`jobs.gd:634-644`; `casebook_app.gd:545`; `chat_app.gd:229`; `phone_os.gd:645`; `studio_app.gd:117`)
11. **Raise chat metadata to the type floor.** Roles/times 10–11 px and a lighter colour than `FAINT`. (`chat_app.gd:299,302`; `ui_theme.gd:21`)
12. **Colour pass on the flight HUD.** Replace the blue press/slider states with brass. (`hud.gd:176,185,190`)

Art production order (the briefs are ready; the queue is the decision):

1. Vehicle fleet + the three story vehicles (the Lake Car is the title object).
2. Village buildings and street furniture.
3. App/tablet icon, portrait, stamp and product-tile set, then the OFL font family.
4. Anti-drone ridge and the wildlife set.
5. Boat launch, cabin track, intersection hardware, signs, road-surface marking kit.

Integration note for whoever schedules art: only traffic, app icons/avatars/case stamps and base road textures are wired. Village, anti-drone, wildlife, boat, cabin, signs and story vehicles will each need a loader change before art can drop in.

---

## 5. What I could not verify

- **I did not run the game.** Running it would write `user://` saves and configs, which the task forbids. Duplicate-notification bursts, layout overlap at other resolutions, touch/gamepad behaviour and the exact text of truncations are code-read findings, not live observations.
- **The screenshots predate the latest commits.** They are from `docs/realism/` and their strings match current code, but they do not prove the current build's exact pixels.
- **I cannot judge the visual quality of the 23 existing GLBs** beyond node names. In particular, whether the seven web-derived vehicle variants in `world/props.glb` could pass as traffic was not tested in engine.
- **I did not audit audio, weather/fireworks runtime, physics, mobile performance, controller support or save migration.**
- **Two flagged items may be deliberate choices:** "$" currency and "47°N" latitude. I marked them as consistency risks, not bugs.
- **Unknown = Wren is unconfirmed.** The Casebook routes the "Message Wren" button to the Unknown DM (`casebook_app.gd:487-491` → `phone_os.gd:344-351`). If that is intentional it is fine; if not, it spoils the reveal.
- **No access to any art delivered outside this repo.** The project tree contains none, and the briefs' own status lines still describe the code placeholders.

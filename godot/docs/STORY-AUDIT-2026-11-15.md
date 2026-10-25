# Story and state-machine audit — 2026-11-15

Read-only audit of the Lake Car story, its state files and the route to the credits. I did not run Godot, did not read or write any `user://` save, and changed no game code or assets. Every claim below is from the source in this tree.

**Snapshot.** Commit `ef0fe13`, plus an in-progress uncommitted PlayerProfile pass (`casebook_app.gd`, `chat_app.gd`, `ending.gd`, `landing.gd`, `story_arc.gd` modified; `player_profile.gd` untracked). Those files were still being edited while I read them, so line numbers are as of roughly 15:26–15:31 local. Re-run the greps before applying a patch. All other files were clean.

**Bottom line.** The chapter-to-chapter loop is coherent code and the gates do technically exist. The run from the current save to the credits is not safe yet. The Pike anti-drone hazard is never ticked and the jammer is never brought down, while the finale's dialogue states that the jammer is off. Chapter waits are 3 in-game hours and a Story-mode player has no way to move the clock, so the loop stalls for hours with no instruction. Reloading after the ending re-opens the finale and writes a second copy of the whole ghost reveal into the saved chat.

## The five findings that matter most

1. **The anti-drone ridge is dead code, and the finale narrates a state the game never enters.** `AntiDrone.update()` has no caller in `main.gd`, and `AntiDrone.jammer_down_now()` has no caller anywhere in the repo. So the jammer field, the shotgun timer, the hunter chase, the red LINK warnings and the "jammer came down" messages never happen. The finale still says *"Pike's jammer is off us now. His hunter drones are not."* (`finale.gd:185`). Two design docs assert the missing call (`docs/ANTI-DRONE-RIDGE.md:25`, `LOGIC-NOTES.md:1060`). If only `update()` is wired without the `jammer_down_now()` call, the cabin becomes unreachable: the cabin spot is 16 m from the mast, inside the 235 m field, and the field returns the drone after 2.6 s.
2. **The six chapter waits are real-time hours in Story mode, with no visible instruction.** Each chapter waits `next_hours = 3.0` in-game hours (`story_arc.gd:29,41,53,65,80`), which in the default real-clock mode is three wall-clock hours per chapter — 15 hours across the five waits. The Weather tab hides the whole sandbox block that contains Clock / Hour / "Time passes" when `story_mode` is on (`hud.gd:710,716–721,926–930`). The Casebook only says *"Evidence delivered. Rennick is looking into it and will be in touch."* (`story_arc.gd:353`). There is no countdown, no "come back later", and no in-game way to pass time.
3. **The finale's launch-site gate is not surfaced in the Casebook, and it is the gate most likely to stop the current save.** `finale._missing_requirement()` refuses to start unless `sites.active_id` is `cabin_track` or `north_ridge` (`finale.gd:112–119`). `StoryDirector.next_step()` says *"Everything is ready. Rennick is waiting at the cabin. Open #town and take the last flight."* — with no mention of driving the kit north (`story_director.gd:64–69`). The only other notice is a one-shot chat/phone prompt (`finale.gd:121–130`) and a Kit tip that fires once (`guide_coach.gd:112–117`). If the player misses the note, nothing repeats and the last flight never starts.
4. **A reload after the ending re-opens the story and duplicates the ghost reveal.** Neither `Finale` nor `Ending` persists any state (no `SAVE`, no `_load`), and `StoryDirector._act_from_state()` has no completed branch (`story_director.gd:38–47`). `StoryArc.completed` is saved (`story_arc.gd:380–382,394–406`) but read only by the Casebook contact card (`casebook_app.gd:485,490`). On the next launch the director reports act 3 "The Last Flight", the Casebook says *"Everything is ready… take the last flight"*, and `finale.update()` auto-starts again after 3 s (`finale.gd:71–85`). Each replay appends six more ghost messages to `#town`, and those are persisted in `user://chat.json` (`chat_data.gd:64–71,154–157`).
5. **Narrative contradictions the player can see.** The Unknown says *"ask her about 1974"* (`unknown_thread.gd:34`) but the implemented truth is 1984: *"I died out here forty years ago"* (`finale.gd:188`), case number `HV-84-017` (`casebook_app.gd:14`), a 1984 cruiser (`case_objects.gd:673`), and the design briefs all say spring 1984. Chapter 1's reveal reads the tow sticker before Chapter 2 asks for it (`story_arc.gd:23` vs `:33`). The last chapter's reveal says *"The file is closed"* (`story_arc.gd:86`) while the file is only ready to close (`story_arc.gd:349`). Wren appears in the Casebook Contacts as `MISSING HIKER` from a fresh save, and "Message Wren" opens the Unknown DM (`casebook_app.gd:490`, `phone_os.gd:408–415`), which spoils the finale's reveal.

## 1. The intended run, fresh save to credits

The route below is what the code actually does, not what the design notes intend.

### 1.1 The opening

1. Boot, welcome screen, Story mode default (`landing.gd:43`, `hud.gd:899–910`). The player can type a callsign; the computer name is pre-filled suggestively (`landing.gd:89–104`, `player_profile.gd:36–39`).
2. The story starts when **the player has published a clip or finished a job**: `StoryArc.update()` tests `jobs.videos().size() > 0 or jobs._done.size() > 0` (`story_arc.gd:146–149`). Publishing a photo from the camera roll and submitting a job both append a video (`jobs.gd:200,629`).
3. `StoryArc._start()` posts Rennick's greeting in `#town`, then chapter 1's request, then a phone note (`story_arc.gd:154–166`). In the same frame `UnknownThread.update()` posts its first wrong-number DM (`unknown_thread.gd:86–88`). Kit's welcome tip fires on the first frame after that, because its four-second warm-up timer has long elapsed (`guide_coach.gd:69–76`).

### 1.2 The six chapters

Each chapter runs the same loop: request in `#town` + phone note, photographs filed by subject id and distance, completion fires the reveal + three crew beats + "I will come back…", then a wait, then the next request.

| # | Chapter | Evidence gate | Wait |
|---|---|---|---|
| 1 | A favour — the blue estate | `case_lake_car`, ≤ 80 m, 2 photos | 3 h |
| 2 | No plates — VIN / tow sticker | `case_lake_car`, ≤ 18 m, 1 photo | 3 h |
| 3 | The garage | `case_garage`, ≤ 90 m, 2 photos | 3 h |
| 4 | Lights on the ridge — the camp | `case_camp`, 25–160 m, 2 photos | 3 h |
| 5 | The man who fixed things — the bus | `case_bus` ≤ 80 m ×2 **and** `case_bus` ≤ 22 m ×1 | 3 h |
| 6 | The festival | `case_bus` ≤ 220 m, 2 photos | none |

Chapter 5's two requirements share the subject `case_bus`, so one photo inside 22 m counts toward both (`story_arc.gd:184–217`). The last chapter moves the bus to the festival field when it begins (`story_arc.gd:176–177`, `case_objects.gd:74–84`).

**Completion and wait.** `StoryArc._complete()` sets `waiting = true` and `_next_at = _abs_hours + next_hours` (`story_arc.gd:222–252`). `update()` begins the next chapter when `_abs_hours >= _next_at` (`story_arc.gd:150–152`). `_abs_hours` grows from the difference in `hud.weather["hour"]` between frames, and only while `hud.story_on` is true, `story_mode` is irrelevant to the wait (`story_arc.gd:132–152`).

### 1.3 Wildlife, in parallel

`WildlifeCase` starts by itself once the case reaches chapter 3 (`story_arc.gd` chapter index ≥ 2, `wildlife_case.gd:56–59`). It does not require an in-game night. The player must:

1. buy the **thermal camera** on Facade for 120 (`facade_catalog.gd:29–33`),
2. have it in inventory, which makes the mod auto-install and start the hunt (`wildlife_case.gd:62–69`),
3. fly within 110 m of the wolf with the thermal camera switched on (`wildlife_case.gd:80–83`).

That mission is both the thermal tutorial and a hard gate for the finale.

### 1.4 The Unknown thread

Beats 0–5 are gated by chapter **and** a delay in game hours (`unknown_thread.gd:51–52,89–98`):

- beat 0: any time after the story starts;
- beats 1–3: chapter ≥ 1, 2, 3 and 2 h / 3 h / 3 h after the previous beat;
- beat 4: chapter ≥ 5 and 4 h after beat 3;
- beat 5: chapter 5, the case closed, and 5 h after beat 4.

Beat 5 swaps its first line for the published variant when the player chose to publish (`unknown_thread.gd:105–106`).

### 1.5 Closing the case

When chapter 6 is complete the Casebook shows the closing choice (`story_arc.gd:255–257`, `casebook_app.gd:370–375`). Publish pays $120 and posts a Maya cut; private pays $240 (`story_arc.gd:258–287`).

### 1.6 The last flight

The finale auto-starts only when **all** of these hold (`finale.gd:71–85,112–119`):

- `hud.story_on` is true,
- the case is closed,
- `unknown.beat >= 5`,
- three seconds have passed,
- the thermal camera is owned,
- the night pasture is complete,
- the active launch site is `cabin_track` or `north_ridge`.

On start it forces the clock to 20:30, starts a storm, installs the thermal camera, posts the six-line ghost reveal in `#town` (Rennick is dead, Wren is in the cabin), and a "please hurry" DM from Unknown (`finale.gd:163–193`).

Then the player flies north. Three distance bands fire the ghost lines: 700 m, 420 m and 190 m from the cabin (`finale.gd:39,93–105`). At 190 m the cabin lights come on, Wren is shown at the search spot, and the NAV target switches to the heat signature. With the thermal camera on and the drone within 105 m of Wren, `_found()` plays the ending (`finale.gd:107–110,141–161`).

### 1.7 The ending

`Ending.play()` blurs for 8 s, brings the card up from 7 s, and at 22 s swaps to a free walk around the parked drone (`ending.gd:13–15,165–191`). `main._on_ending_began()` hides the HUD and marks the story complete (`main.gd:2074–2091`). Clicking the drone within 105 px of screen centre returns to flight (`main.gd:2144–2179`).

## 2. Ways the run stalls, skips, repeats or contradicts itself

### 2.1 The anti-drone ridge is not wired to anything (high — explains a false finale line)

Two separate omissions, both provable by grep:

- **`AntiDrone.update()` is never called.** `main.gd` creates the node and connects `forced_return` (`main.gd:437–441`) but the per-frame update block (`main.gd:930–953`) does not call it. `anti_drone.gd` defines `func update(delta)` and no `_process`/`_physics_process`, so nothing ticks it. Consequence: no jammer field, no shotgun check, no hunter movement, no LINK warning, and `_on_anti_return` can never fire.
- **`AntiDrone.jammer_down_now()` is never called.** Its only definition is `anti_drone.gd:104–115`; no file calls it. `Finale` holds an `anti_drone` field (`finale.gd:22`) that `main.gd:441` fills, but `Finale.start()` never uses it. So the "mast came down in the storm last night" messages, the beacon-off state and the saved `jammer_down` flag never occur.
- The docs describe the intended wiring as fact: *"`Finale.start()` calls `AntiDrone.jammer_down_now()`"* (`docs/ANTI-DRONE-RIDGE.md:25`) and *"The break: `Finale.start()` calls `AntiDrone.jammer_down_now()`"* (`LOGIC-NOTES.md:1060`). The code disagrees.
- The geometry makes this matter: cabin `CABIN_SPOT = (-250, -820)` (`case_objects.gd:15`) and jammer `JAMMER_SPOT = (-260, -807)` (`anti_drone.gd:14`) are **16.4 m apart**. The 235 m jammer field covers the cabin, the cruiser and most of the search area; the 105 m find radius around Wren is still ~86 m from the mast. If `update()` is wired and `jammer_down_now()` is not, a 2.6 s grace inside the field (`anti_drone.gd:79–88`) returns the drone before it can finish the search. Fix both or neither.
- The current behaviour is the "neither" case, so the available test route is unobstructed. That is why the finale can still be flown today; the hazard the story refers to does not exist.

### 2.2 Waiting is invisible and costs real hours (high — playtest blocker)

Covered in detail in section 4. In state-machine terms: after each of the first five chapters the game enters a state with no player action and no explanation. The Casebook status is `"Evidence delivered. Rennick is looking into it and will be in touch."` (`story_arc.gd:353`), the last chat line is `"I will come back to you when I have had a look. Thank you."` (`story_arc.gd:236`), and nothing prints a duration. A tester who completes chapter 1 and keeps flying sees nothing happen for three hours.

### 2.3 The last flight can be postponed indefinitely and the Casebook says the opposite (high)

Two gates make the finale start later than the Casebook implies:

- **The Unknown's fifth beat.** It requires the case closed *and* 5 game hours after beat 4 (`unknown_thread.gd:52,96–97`). With the six chapter waits, an efficient player closes the case around game-hour 15–16 and beat 5 lands around game-hour 20. For those five hours `StoryDirector.next_step()` already says *"Everything is ready. Rennick is waiting at the cabin. Open #town and take the last flight."* (`story_director.gd:64–69`). The finale does nothing, and no message explains why.
- **The launch-site gate** (`finale.gd:112–119`). `next_step()` never mentions it. The one-shot prompt is the only instruction (`finale.gd:121–130`), and Kit's `map_help` tip is sent once (`guide_coach.gd:112–117`). On the current save, unless `user://launch_site.cfg` already says `cabin_track` or `north_ridge`, the finale will sit behind this gate after every launch.
- The prompt itself reads *"Not yet."* (`finale.gd:123`) as though the player pressed a button. They did not; there is no button. That is a prompt/trigger mismatch.

### 2.4 Reload re-opens a finished story (high — data damage, not just UI)

`Finale` and `Ending` have no persistence. On a completed save (`story.completed = true`, `choice = "published"`, `chapter = 5`, all `_done`) the next launch does this:

1. `StoryDirector` reports act 3, "The Last Flight", because `ending.started` and `finale.is_started()` are both false (`story_director.gd:38–47`).
2. The Casebook header shows `CASE CLOSED` and, in the same header, `CASE FILE · HV-84-017 · ACT 3 · THE LAST FLIGHT` (`casebook_app.gd:229–234`).
3. The next-step card says *"Everything is ready. Rennick is waiting at the cabin."*
4. After three seconds `finale.update()` starts the last flight again (assuming thermal, wildlife and launch site still pass) and posts the six ghost lines to `#town` a second time. `chat_data` persists every line in `user://chat.json`, so the duplicates are permanent.
5. The Casebook Contacts card still says `Wren · FOUND` (`wren_found` reads `story.is_completed()`, `casebook_app.gd:485`), so the file claims Wren is safe while Rennick is asking the player to go and find Wren.

This is not only a reload issue: the same false state is visible in the same session after finishing, because nothing marks the run as done in the director.

### 2.5 Evidence and reveal contradictions (medium)

- **Tow sticker twice.** Chapter 1's evidence is two photographs of the car and the ground, ≤ 80 m (`story_arc.gd:22`). Its reveal already reports *"There is a tow sticker on the back window, Voss and Son Motor Works."* (`story_arc.gd:23`). Chapter 2 then asks for *"the VIN plate … and the tow sticker if it is still there"* (`story_arc.gd:33`). Either the reveal is unearned or chapter 2's request is redundant.
- **VIN accepted "or" but VIN result always reported.** Chapter 2's requirement text is *"Close-up of the VIN or the tow sticker"* (`story_arc.gd:34`), but the reveal leads with VIN results: *"The VIN comes back to a 1987 blue estate…"* (`story_arc.gd:35`). A player who only shot the sticker still hears a VIN report.
- **The file closes twice.** The last chapter's reveal says *"The file is closed"* (`story_arc.gd:86`) before the closing choice exists; the Casebook immediately says *"Case ready to close. Decide what happens to the story."* (`story_arc.gd:349`). The completion note correctly says "The case is ready to close" (`story_arc.gd:243`), so the chat line is the odd one.
- **A volunteer finds the programme that Ellis already gave.** The in-progress PlayerProfile edit appends *"A festival volunteer called %s found the original programme in a box…"* to the same reveal that says *"he gave me the original festival programme for the archive"* (`story_arc.gd:86,227–238`). With "Use my computer name in the story" enabled, the last chapter contains two different accounts of the same object, and Jo repeats the volunteer version in `#general`.
- **"1974" is not in this story.** The Unknown says *"ask her about 1974"* (`unknown_thread.gd:34`). 1974 comes from a future-case storm-narrative document (`docs/story/STORM-NARRATIVE.md`), not this build. The implemented truth is 1984. A curious player who asks Rennick about 1974 gets nothing.
- **Wren appears before Wren exists.** Contacts lists Wren as `MISSING HIKER`, *"Last seen north of the cabin. The reason the file is still open."*, from the first time the app opens (`casebook_app.gd:490`). No character has mentioned Wren at that point, no chapter uses Wren, and the finale's reveal is that Unknown is Wren. The same card's "Message" button opens the Unknown DM (`phone_os.gd:408–415`), which answers the mystery in the UI. The earlier review flagged this as a possibility (`REVIEW-CLAUDE-2026-11-15.md:185`); the code does route it there.
- **The bus teleports.** The bus moves from the garage to the festival field at `_begin(5)` (`story_arc.gd:176–177`), i.e. while the player is waiting 3 h or flying anywhere near the garage. The bus vanishes from the yard and reappears on the field at chapter 6's start.
- **The festival has no festival.** Chapter 6 asks for photographs of the bus at the festival field and its reveal describes *"the whole parade route with the band on board"* (`story_arc.gd:86`). The world has a field and a bus, no parade, no band and no committee present. The photographs cannot show what the reveal describes.

### 2.6 Wrong order: cabin lights claimed before they are switched on (low–medium)

The 420 m ghost line says *"I can see the cabin lights from here."* (`finale.gd:101`). The cabin lights are only switched on at 190 m, inside `_arrive_cabin()` (`finale.gd:132–135`). The start-of-finale Unknown message also says *"I can see the lights in the storm"* (`unknown_thread.gd:44`; published variant `:49`), before the lights exist. The toast at the cabin, *"The cabin lights are on. Wren has set out again on foot."* (`finale.gd:135`), implies they just came on. Either move `objects.set_cabin_lights(true)` to `start()` or change the two earlier lines.

### 2.7 A session's first frames can jump the story clock (medium — skips waits)

`StoryArc` and `UnknownThread` seed `_last_hour` in `setup()` from `hud.weather["hour"]` (`story_arc.gd:123`, `unknown_thread.gd:69`). That happens at `main.gd:397,402`, but the weather is only applied at `main.gd:462` and the live clock is written into `hud.weather["hour"]` one second later (`main.gd:958–961`). On the first frames, `_last_hour` therefore holds the **saved weather-file hour** (default 16.0), then snaps to the real hour. The difference is added to `_abs_hours` if positive (`story_arc.gd:136–143`). Launching an evening session with a saved weather hour of, say, 16:00 can add up to 12 h in one frame, which can complete a pending chapter wait instantly. `UnknownThread` has the identical bug. It also means two players starting at different times of day begin the story clock at different points.

### 2.8 The "Story and jobs" switch does not switch everything off (medium)

- `StoryArc.on_photo()` has no `hud.story_on` check (`story_arc.gd:184–217`). With the switch off, photographing a chapter subject still files evidence and can complete the chapter, posting reveals and beats into the chat. The switch only stops the start trigger and the wait (`story_arc.gd:144–152`).
- `WildlifeCase.update()` and `Finale.update()` likewise gate only their start conditions on the story layer, not their running state (`wildlife_case.gd:53–59`, `finale.gd:71–75`).
- `StoryArc.make_choice()` does not check `story_on` either (`story_arc.gd:255–257`), so the closing choice works from the Casebook while the story is supposedly off.
- `hud.story_on` is never saved (`hud.gd:84,807`; only `story_mode` is persisted at `hud.gd:899–910`). The switch silently returns to On at the next launch, which can resume a story the player turned off — including an auto-starting finale.

### 2.9 Wildlife state bugs

- **The contradiction when the camera is already owned.** If the player buys the thermal camera before Riley's favour starts, `_start()` posts *"Fit it, come out to the hay field"* (`wildlife_case.gd:88–93`), then the same update recognises the already-owned camera, advances to stage 1 and posts *"That is the thermal camera fitted."* (`wildlife_case.gd:69–77`). The player reads "fit it" and "fitted" in one frame, having done nothing.
- **The wolf disappears on reload.** `WildlifeObjects.setup()` hides the wolf (`wildlife_objects.gd:22–23`). The wolf is only re-shown in the stage 0 → 1 transition (`wildlife_case.gd:72–73`), and `stage` is saved. Reload mid-hunt: `stage = 1`, so the wolf stays invisible and its heat shell stays off (`WildlifeObjects.set_thermal_markers()` requires `_wolf.visible`, `wildlife_objects.gd:38–42`). The mission still "completes" because completion only checks camera-on plus distance (`wildlife_case.gd:81–83`), so the player can solve an empty field.
- **No night gate.** The brief says *"West pasture, after dark"* (`wildlife_case.gd:75`), and the Casebook/director repeat "night pasture", but nothing checks the clock or `meta.night`. Daylight completion is possible.

### 2.10 Debug hooks (`main.gd:1088+`) are not a safe stand-in for the real route

The `shot=` screenshot hooks mostly bypass the very gates the story depends on:

- `wildlife`, `wildlifecomplete`, `wildlifeworld` call `story.debug_jump(2)`, which marks chapters 0–1 done without posting their requests or reveals, and `debug_complete()` resolves the night pasture without flying (`main.gd:1389–1414`).
- `finalestart`, `cabinworld`, `thermalwren`, `thermalview` call `finale.debug_start()` which adds the thermal camera, completes wildlife and sets the launch site itself (`finale.gd:234–241`). They cannot tell you whether the real launch-site gate is reachable.
- `endingdemo`/`endingcabin`/`endingwash`/`endingcard`/`endingfree` call `finale.debug_found()` directly, which plays the credits and, through `ending.began`, calls `story.mark_completed()` (`main.gd:2091`). A screenshot session on a real profile therefore writes `completed = true` without playing the story.
- `unknowndoubt`/`unknownfinal` call `story.debug_run_all()` and then `unknown_thread.debug_jump(4/5)`, which posts beats without the chapter/hour gates.
- `storypublish`/`storyprivate` silently do nothing on a save that already has a `choice`, because `has_choice()` is false (`story_arc.gd:255`).

## 3. Prompt vs trigger, subject, distance, time-of-day, chapter and UI location

| Where | Prompt says | Code actually checks | Verdict |
|---|---|---|---|
| Ch 1 request | "two clear photographs … from the air, within eighty metres. Do not land." (`story_arc.gd:21`) | `case_lake_car`, ≤ 80 m, 2 photos (`:22`) | "from the air" and "do not land" are not checked. `_photo_meta()` records `agl` (`main.gd:2300`), so a check is one line away. |
| Ch 1 evidence text | "Photograph the abandoned car (2 angles)" (`:22`) | Any 2 distinct photos of the subject | No angle/bearing check; two frames from one hover count as "2 angles". |
| Ch 2 request | "a close pass within fifteen metres" (`:33`) | `max_dist: 18.0` (`:34`) | Number mismatch. The marker is more lenient than the prompt. |
| Ch 2 evidence text | "Close-up of the VIN or the tow sticker" (`:34`) | distance only; either photo counts | "VIN or sticker" is fine, but the reveal always reports VIN (`:35`). |
| Ch 3 request | "Photograph the roller door, the workshop window and the yard." (`:45`) | one subject `case_garage`, ≤ 90 m, 2 photos (`:46`) | No door/window/yard distinction; any two garage frames satisfy it. |
| Ch 4 request | "at least twenty five metres away, no close pass and no people" (`:57`) | `min_dist: 25`, `max_dist: 160`, 2 photos (`:58`) | Range is enforced; "no people" is not checked, and too-close photos are silently ignored (no retake feedback, unlike jobs). |
| Ch 5 request | "Two photographs, and one close enough to read the lettering on its side." (`:69`) | `case_bus` ≤ 80 m ×2 plus ≤ 22 m ×1 (`:71–72`) | "Read the lettering" is not verified; one 22 m photo counts for both requirements. |
| Ch 6 request | "two photographs of it there, from the air" (`:84`) | `case_bus` ≤ 220 m, 2 photos (`:85`) | No height check; the lowest hover counts. |
| Night pasture | "West pasture, after dark" / "night tracking favour" (`wildlife_case.gd:75,89`) | distance + thermal on (`:80–83`) | No time-of-day check. |
| Finale prompt | "Come north. The last flight should start from the ridge trailhead, not from the home pad." (`finale.gd:129`) | active launch site id only (`:117`) | Correct in spirit, but the target of the action ("Drive here" in the Map app) is not named in the Casebook, and the prompt is one-shot. |
| Finale ghost | "Pike's jammer is off us now." (`finale.gd:185`) | AntiDrone is never ticked; jammer never goes down | Inverted: nothing is on, and nothing goes off. |
| Finale ghost | "I can see the cabin lights from here." (`:101`) | lights switch on at the next band, 190 m (`:133`) | Order mismatch. |
| Casebook header | `CASE FILE · HV-84-017 · ACT n · NAME` | `ACT` is always appended, even when the case has not started or is closed (`casebook_app.gd:229–230`) | Contradicts `NO CASE YET` / `CASE CLOSED` shown beside it. |
| Casebook next step | "Everything is ready… take the last flight" (`story_director.gd:69`) | unknown beat 5, launch site, 3 s (`finale.gd:75,112–119`) | Two hidden gates remain, so the prompt is false. |
| Casebook Contacts | Wren: "Last seen north of the cabin. The reason the file is still open." (`casebook_app.gd:490`) | story has not mentioned Wren until the finale | Spoiler and a false statement about why the file is open. |
| Casebook "Approach" | "drive the kit to a closer site before a long chapter" | no launch-site requirement before chapter 6 | Harmless advice, but it never mentions the only site-gated step. |

## 4. The six chapter waits: can a Story-mode player advance time?

**No, not through the UI. They are expected to wait in real time, and nothing says so.**

The evidence:

- Five chapters have `"next_hours": 3.0` (`story_arc.gd:29,41,53,65,80`); the last is 0. The five waits add up to 15 game hours.
- `_abs_hours` is advanced from the in-game clock (`story_arc.gd:135–143`), which in the default `clock_mode = 0` is the real system clock (`main.gd:685–691`, `hud.gd:48`).
- The only controls that change the clock mode or speed live in `_weather_sandbox` (`hud.gd:710–721`: Clock, Hour of day, "Time passes — Real time / Fast (a minute a second) / Frozen").
- `_apply_mode_ui()` hides the whole of `_weather_sandbox` when `story_mode` is on (`hud.gd:926–930`), and the story-mode note tells the player to use Free flight for time controls (`hud.gd:701–702`).
- The only visible feedback is the Casebook line "Evidence delivered. Rennick is looking into it and will be in touch." (`story_arc.gd:353`) and Rennick's "I will come back to you when I have had a look." (`story_arc.gd:236`). Neither mentions hours, a countdown or "come back later".

So a Story-mode playthrough needs **15 game hours for the five chapter waits, plus up to 5 more game hours for the Unknown's final beat (about 20 hours)**, spent mostly not playing, with no indication of why. In one session that is a playtest blocker. It is also easy to mistake for a broken story.

The only ways past it today are accidental or developer-only: relaunch later in the day (section 2.7 can jump the clock by hours), or the `shot=` debug hooks (`storynext`). A normal player has neither. If the clock was previously set to "Fast" in Free flight, that setting is saved in `user://weather.cfg` and survives into Story mode — an undocumented workaround, not a design.

**Fix direction (minimal):** show the wait in the Casebook and make it short. For example, keep `_next_at` but set `next_hours` to something like `0.25` (15 real minutes at 1× speed) and change `current_status()` while waiting to `"Rennick will call in about %d minutes."` That keeps the narrative "she is looking into it" without an empty session. The alternative — expose a story-mode "wait until Rennick calls" action — is more work but preserves the intended pacing. Do not leave both the duration and the silence.

## 5. The Unknown thread: gates and variants

### Gates

`MIN_CHAPTER = [0, 1, 2, 3, 5, 5]` and `DELAY_HOURS = [2, 3, 3, 4, 5, 0]` (`unknown_thread.gd:51–52`). A beat fires only when `_abs_hours >= _next_at` **and** `story.chapter >= MIN_CHAPTER[beat]`, with beat 5 additionally requiring `story.case_closed()` (`:89–98`).

Two problems:

- **The comment is wrong about the camp.** The header says the unknown must not know about the camp before the pilot has found it (`:10–11`), but `MIN_CHAPTER[3] = 3` fires the beat when the camp chapter *opens*, before any camp photograph. The beat's text is *"they found the tow sticker, didn't they. and someone has been camping up by the railway."* (`:33`). Either raise the gate to 4 (camp finished) or accept that the sender read Rennick's own request in `#town`.
- **Everything the Unknown "knows" is already public.** Rennick posts every request and reveal in `#town` (`story_arc.gd:179,232`), so the tow sticker, the camp and the file are all visible to the whole crew. The thread's intended effect ("it knows more than a stranger should") only survives because of `"ask her about 1974"` and `"she knew the garage before she knew the town"` (`unknown_thread.gd:34–35`), and 1974 is not in this story. Consider moving some case detail to a DM or giving the Unknown one concrete private fact that Rennick never posted.

### Published vs private variants

`MESSAGES[5]` is replaced by `PUBLISHED_LAST` when `choice == "published"` (`unknown_thread.gd:47–50,105–106`):

- published: *"you put it on the channel. i hope ellis was ready for that."*
- private: *"i'm not the one you should be worried about."* (the default first line)

The published hook is coherent with the choice and is the only line that acknowledges it. Two caveats:

- Under the finale's reveal ("I have been borrowing their phone"), the published acknowledgement implies Rennick saw the channel and Ellis's situation in the hour after the choice — acceptable, but it is the only reaction. Maya's "The cut is up…" is the only other acknowledgement.
- The private path gets no acknowledgement and loses the "i'm not the one you should be worried about" line only if published. The last beat is otherwise identical, so the choice changes exactly one sentence in the Unknown thread. If the choice is supposed to matter, the private line should at least say "thank you for keeping it quiet."

## 6. Finale requirements, thermal/wildlife gating, and reaching the cabin

### What `_missing_requirement()` enforces (`finale.gd:112–119`)

1. `inventory.has_addon("thermal_camera")` — otherwise the "Not yet" prompt,
2. `wildlife.completed()` — otherwise Riley's prompt,
3. `sites.active_id in ["cabin_track", "north_ridge"]` — otherwise Rennick's trailhead prompt,
4. plus, outside that function, the auto-start conditions: story on, case closed, `unknown.beat >= 5`, 3 s (`:71–85`).

`start()` re-checks the same three requirements (`:163–169`), and `_debug_start()` satisfies them itself. So the finale cannot be started in the real game without the kit, and cannot be skipped.

### Can the player reach the cabin without the kit or before the unknown beat?

Physically, yes. There is no barrier, the jammer is inert (section 2.1), and the cabin, cruiser and cave are ordinary geometry. Story-wise, nothing happens: the cabin lights are off, Wren is hidden (`case_objects.gd:749,771`), no messages fire, and the finale's state machine is not running. So flying there early is harmless mechanically. It does spoil the ending's best image (the cruiser at the cabin), because `case_cabin` and `case_cruiser` are photographable subjects from the start (`case_objects.gd:61–62`) and the cabin is a visible landmark. If the intention is that the cabin is a discovery, hide or move it until the finale.

The thermal/wildlife gate is sound in code. The two failure modes are the reloaded invisible wolf (2.9) and the fact that the thermal camera is a 120 purchase early in a save where the pot starts at 0. The director covers the second with "buy the thermal camera on Facade, then try Riley's night pasture", and the shop listing says the pasture will teach it (`facade_catalog.gd:32`), so that one is signposted.

## 7. The end card, the free walk, and what reload leaves behind

Live, the sequence is sound: `_found()` → `ending.play()` → `_on_ending_began()` hides HUD/phone, cuts the motors, marks completed → card at 7 s → free walk at 22 s → click the drone to fly again (`main.gd:2074–2179`, `ending.gd:147–191`). The free walk camera and drone hint are in `main._update_end_walk`/`Ending.set_drone_hint`.

What reload leaves behind:

- **Nothing about the finale or the ending is persisted.** `Finale.started/ended/stage`, `Ending.started/free`, `main.end_sequence/end_walk` all reset. Section 2.4 lists the consequences; the important ones are the re-armed finale, the repeated ghosts and the Casebook claiming `ACT 3 · THE LAST FLIGHT` on a closed file.
- **`story.completed` is saved early** (`main.gd:2091`, at the start of the card, not after it). Quit during the 22 s card and the save says the story is complete while the director will re-run it.
- **`StoryArc.last_result` is not saved** (`story_arc.gd:394–406` writes no `last_result`). After a reload, the published Casebook card loses its *"The cut is at N views so far…"* line (`casebook_app.gd:571–574`), so the only record of the ending's numbers disappears.
- **Cabin lights, Wren, the storm and the 20:30 clock are not restored.** They are set live by the finale and are simply absent after a reload. The forced weather also persists only until the weather system rolls on.
- **The drone spawns at the saved launch site**, not at the ending spot (`main.spawn()` uses `launch_pos`). The free walk cannot be resumed.
- **`hud.story_on` resets to true** (section 2.8), so a player who switched the story off before quitting gets it back, and the finale can auto-start on a save they considered finished.

## 8. Voice, names and the callsign pass

The in-progress PlayerProfile pass is a good direction, and it is unfinished. What still reads wrong:

1. **Characters talk about the player as an absent man.** In the opening `#general` seed: *"Why is the pilot always circling the cemetery?"* (Alex), *"Lay off him, okay guys. His uncle just passed… It gives him some peace."* (Sam), *"Leave him be. He flies better when he is quiet."* (Maya) (`chat_data.gd:113–115`). That fixes the player's gender as male and addresses them in third person inside their own server. It conflicts with the Callsign field and with the art brief's "no fixed gender". This is the single worst voice inconsistency in the story and it is in the first screen the player reads.
2. **"You · pilot" still appears in the chat sidebar.** The avatar now shows `PlayerProfile.initials()`, but the label below it is still `"You  ·  pilot"` (`chat_app.gd:111`). It should be the callsign, e.g. `"<callsign> · pilot"`.
3. **Rennick greets the player by a name they did not choose.** `_start()` addresses `PlayerProfile.display_name()` (`story_arc.gd:157–162`), and `display_name()` defaults to the detected computer/account first name (`player_profile.gd:36–39,72–74`). The profile's own doc says the computer name is "only a suggestion, never shown to other characters unless the player opts in" (`player_profile.gd:8`). Pre-filling the field and pressing Fly is a soft opt-in, but it is worth a deliberate decision, because the name then appears in chat and in the credits (`ending.gd:98`).
4. **`PlayerProfile.address()` is never used.** It exists for "a line where a character addresses the pilot directly" (`player_profile.gd:100–104`), but no call site uses it. Rennick's greeting and the ending note call `display_name()` instead, so the fallback wording ("pilot") is hand-rolled rather than sharing one rule.
5. **The festival-volunteer name contradicts the reveal** (section 2.5). Also, the volunteer line is generated in the story reveal itself (`story_arc.gd:227–238`), so the optional real name is injected into Rennick's voice, not into an app or a neutral narrator.
6. **Wren's contact card uses a name and role the player should not have yet** (`casebook_app.gd:490`). It is not a self-reference problem, but it is the clearest place where a character/UI uses a name the story has not earned.
7. **"Hey, buddy"** in Rennick's last note (`finale.gd:193`) is still the one place her voice breaks into informality. The message-voice doc lists it as an open question (`MESSAGE-VOICE.md:27,57`). Decide MSG1; either is defensible, but the rest of her lines are formal and this one reads as a different character.
8. **Alex says "Press T" in chat** (`finale.gd:182`): *"…Press T or tap it."* A character naming a keyboard key was the exact pattern the voice pass removed elsewhere (Riley's "with T on" note). Move the key name to the CAMERA toast, which already says the button is on the flight screen.
9. **Casebook label "PILOT · YOU"** next to the callsign is redundant/third-person (`casebook_app.gd:488`). Use the callsign as the name and leave the role as `PILOT`.

## 9. Prioritised fixes

Ordered by cost to the playtest and by how small the change is.

1. **Wire the anti-drone ridge, or cut its dialogue.** In `main._process()`, next to `finale.update()` (`main.gd:950–951`), add `if anti_drone != null: anti_drone.update(delta)`. In `Finale.start()`, before `_ghost("Pike's jammer is off us now…")` (`finale.gd:185`), add `if anti_drone != null: anti_drone.jammer_down_now()`. Both are needed: the first alone makes the cabin unreachable (jammer 16 m from cabin, 235 m field, 2.6 s grace). If the hazard is deliberately cut for this build, remove the ghost line and the hunting dialogue instead.
2. **Make the chapter waits visible and short.** In `StoryArc` keep the wait mechanism but set `next_hours` to a playable value (for example 0.25) and change `current_status()` while waiting to a countdown, e.g. *"Rennick will call in about 10 minutes."* Add one line to the chapter-complete chat message: *"I will come back to you in a few hours."* `director.next_step()` and the Casebook should show the same countdown so there is only one source of truth.
3. **Add the launch-site gate to the Casebook and to the missing-requirement prompt's repeat behaviour.** Extend `StoryDirector.next_step()`'s case-closed branch: when the site is wrong, return *"Drive the kit to the Ridge trailhead or North gate pull-off in the Map app (land first), then the last flight can start."* Consider re-posting the site prompt once per session, or letting Kit repeat `map_help` while the site is wrong.
4. **Persist the end state and make the director honour it.** Simplest: in `StoryDirector._act_from_state()`, return 4 (The End) when `story.is_completed()`, and in `Finale.update()`'s auto-start condition add `and not story.is_completed()`. Also skip the auto-start when `ending.started` or `story.completed`. That stops the reload replay and the duplicate ghost messages. If you want the free walk to survive a reload, persist `end_walk`'s camera/drone position; otherwise at least make the post-completion Casebook say *"The story is complete."* A `completed` check in the finale is one line and does the most work.
5. **Fix the two hard evidence mismatches in the chapter text.** Change Chapter 2's `max_dist` from `18.0` to `15.0` (`story_arc.gd:34`) so it matches the request, and add an altitude check to the "from the air" chapters: pass `min_agl` in the evidence dict and test `float(meta.get("agl", 0.0)) >= min_agl` in `StoryArc.on_photo()`. The metadata already carries `agl` (`main.gd:2300`).
6. **Remove the unearned tow sticker from Chapter 1's reveal.** Replace *"There is a tow sticker on the back window, Voss and Son Motor Works."* (`story_arc.gd:23`) with a line that only uses what two 80 m photographs can show, and let Chapter 2's reveal deliver the sticker. Alternatively move the tow-sticker sentence into Chapter 2's reveal and have Chapter 1 say the car is unlocked/abandoned.
7. **Fix the closing contradiction.** Change *"The file is closed"* in Chapter 6's reveal (`story_arc.gd:86`) to *"The file is ready to close."*, matching `current_status()` and the completion note.
8. **Fix the unknown thread's 1974 and its camp gate.** Replace *"ask her about 1974"* with a 1984 reference (`unknown_thread.gd:34`), and change `MIN_CHAPTER[3]` from `3` to `4` if the intent in the header comment ("does not know about the camp before the pilot has found it") is to be honoured.
9. **Stop the Wren spoiler in the Casebook.** Only add the Wren contact once the Unknown thread has revealed enough (`unknown_thread.beat >= 4` or the finale has started), and label it `UNKNOWN`/`MISSING HIKER` without "the reason the file is still open". Do not route its "Message" button to the Unknown DM until the reveal, or the finale's last line has nothing left to reveal.
10. **Fix the reload clock jump.** Store `_last_hour` in the save file (one new key in `StoryArc._save/_load` and `UnknownThread._save/_load`), or call a new `sync_clock()` on both after `apply_weather(hud.weather, true)` in `_ready`. This closes the accidental wait skip described in section 2.7.
11. **Gate `on_photo`, `make_choice`, wildlife and the finale on `hud.story_on`.** Add an early return in `StoryArc.on_photo()` and a `story_on` condition to `has_choice()`; persist `story_on` in `hud`'s mode file or in the story config so the switch means what it says across sessions.
12. **Wildlife polish.** In `WildlifeCase._load()`/`setup()`, if `stage >= 1 and not done`, call `objects.show_wolf()`; skip the "fit it" chat lines when the player already owns the camera; add a `meta.night` check (or an honest "any time after dark is best, but daylight works") to the completion condition.
13. **Order the cabin lights before the claim.** Move `objects.set_cabin_lights(true)` into `Finale.start()` (and the "the lights are on" toast into `_arrive_cabin()`), or change the 420 m line and the Unknown's cabin line to stop claiming a visible light before `stage 3`.
14. **Voice pass.** Replace the male third-person opening lines (`chat_data.gd:113–115`) with neutral second-person or callsign lines; change `"You · pilot"` (`chat_app.gd:111`) to the callsign; use `PlayerProfile.address()` in Rennick's greeting and the ending note, or delete the helper; move "Press T" out of Alex's mouth (`finale.gd:182`).
15. **Clean up the debug hooks that mark the story complete.** `endingdemo` and the other ending hooks call `finale.debug_found()` and therefore `story.mark_completed()`; either guard that write behind the expected state or make the hooks refuse to run on a save whose story is not closed. Otherwise a screenshot run can corrupt the one save a playtester is judging.

## What I could not verify

- I did not run Godot. Everything here is from source. Two things need a live check I cannot make without the game window: whether the current save's `user://launch_site.cfg` already names `cabin_track`/`north_ridge` (if not, the finale will not auto-start), and whether `user://guide_tips.cfg` already contains `map_help` (if it does, Kit will not repeat the launch-site instruction).
- I did not read any `user://` file, including `story_lake_car.cfg`, `unknown_thread.cfg`, `chat.json`, `launch_site.cfg` or `guide_tips.cfg`. The "current save" state in this report is the state described in the task, not an observation.
- The working tree was moving while I read it (PlayerProfile pass). If the pass is finished before the patch, re-grep for the exact line numbers; the quoted code is current as of the snapshot above.
- I could not confirm whether `AntiDrone.update()` was removed deliberately or by accident in a refactor. The field `Finale.anti_drone` (`finale.gd:22`, assigned at `main.gd:441`) and the two docs that describe the call suggest it was meant to run, but git blame would settle it.
- I did not verify that the enemy hunter drones, shotgun warning and jammer visuals look right when ticked; that needs the game.
- On the "current save": the next launch should re-run the finale if (and only if) the thermal camera is owned, the night pasture is complete and the launch site is `cabin_track` or `north_ridge`. If it is not, the player will see *"Come north. The last flight should start from the ridge trailhead…"* once and no finale. Driving the kit there (Map → Drive here, while landed) unblocks it.

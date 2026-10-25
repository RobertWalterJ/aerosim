# Kit: the DroneBudz support contact

Kit is the in-game guide in DroneBudz (session B UI pass 2). Kit sends a direct message with story-mode tips and gentle follow-ups, and never pauses, scores, fails or gates anything.

## Why a contact

The screen is a tablet with seven apps, a constabulary case file and a flight kit. A new pilot should not have to discover the shell by accident. Kit is a believable crew/support person who knows the valley and the kit, so the help can arrive as a message from a person rather than a tutorial overlay.

## Where Kit lives

- DroneBudz direct messages, under a contact named **Kit**, role **DroneBudz support**.
- `game/guide_coach.gd` owns the tips and the follow-ups.
- `game/chat_data.gd` adds the `guide` channel and the `Kit` cast entry.
- `game/chat_app.gd` treats `guide` as a direct message and colours Kit's words.

## What Kit sends

### Opening

About four seconds after the case starts:

> Hi, I'm Kit from DroneBudz support. Press **Tab** to open the tablet. Open **DroneBudz** and pick a channel on the left. **Casebook** keeps the file, **Jobs** pays, **Facade** sells gear. The bottom bar always has **Home**.

**Tab** is amber, apps are moss, and places inside an app are lake teal.

### If the player does not open the tablet

After roughly 18 seconds without the tablet opening:

> Still not seeing the server? Press **Tab** to open the tablet. If an app is in front, tap **Home** on the bottom bar. Then tap **DroneBudz** and pick a channel on the left.

### If the player opens the tablet but not DroneBudz

After roughly 20 seconds:

> **DroneBudz** is the green app on the home screen. Open it, then tap **#town** or **#clips** in the left column.

### If the player only reads #general

After roughly 24 seconds:

> Try the other channels in DroneBudz: **#town**, **#clips** and **#jobs**. The case starts in #town.

### Story beats

- **Casebook:** when the director reaches act 1, Kit points out Casebook's Overview and Evidence tabs.
- **Evidence:** at act 2, Kit explains that a photo only files itself if it matches the case request and keeps the subject inside the frame.
- **Jobs:** when jobs are on the board, Kit explains accepting a job, the requirement line, publishing and the risk of the client pulling it for getting too close.
- **Thermal camera:** when Riley's night pasture starts and the thermal module is not fitted, Kit explains Facade, Cameras, the channel pot and Your kit.
- **Last flight:** when the case closes, Kit explains the Map app, Ridge trailhead or North gate pull-off and Drive here, and that the drone must be on the ground.
- **Ending choice:** when the file is ready to close, Kit points at Casebook again.
- **Photo:** after the first saved photograph, Kit points at the shutter, Photos and the channel pot.
- **Flight controls:** once the tablet has been opened, Kit explains Takeoff, Land, Return, Esc, Tab, the shutter and the movement keys.

## Colour language

- **Amber `#E0AB59`**: keys and physical controls, such as Tab, Drive here, Takeoff.
- **Moss `#74A87A`**: apps and channels, such as DroneBudz, Jobs, Facade, Casebook, #town.
- **Lake teal `#5C959F`**: a place inside an app, such as Home, Overview, Cameras, Ridge trailhead.

The chat renders these as individual coloured words, so punctuation sits correctly and the text wraps at the message width.

## Behaviour rules

- Story mode only.
- One tip at a time, with at least 8 seconds between tips.
- A tip that asks for an action gets one follow-up, then Kit stops.
- A tip is sent once and saved in `user://guide_tips.cfg`; reloading does not repeat it.
- Notifications are posted through `PhoneNotes`, never a modal.
- No tip has a deadline, a failure state or a forced app.

## Evidence

- `docs/realism/guide/00_kit_welcome.jpg`, the opening message with amber, moss and teal words.

## Honest limits

- Kit reads the phone's current app and chat channel to know whether the player acted; it does not track every input.
- The follow-up timers are real seconds, not in-game time.
- Some story beats only fire if the player reaches that state; a player who ignores the story will not see those tips.
- The tips are canned text, not generated from the player's actual frame or exact location.
- Kit's kit portrait is still a coloured initial until Claude delivers `avatar_kit.png`.
- If the guide channel is deleted from the local chat save, Kit's sent history is still remembered, so the early tips will not repeat.

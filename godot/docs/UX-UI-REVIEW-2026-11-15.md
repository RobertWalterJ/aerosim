# UX and UI review: what was checked and what changed

Status: 2026-11-15. This is the Lead's second pass over the tablet, HUD, menus, notifications and message surfaces, using the Claude review in `docs/REVIEW-CLAUDE-2026-11-15.md` and fresh screenshots. It is not a blanket "everything is polished" claim.

## What was checked

- The tablet home, app grid, dock, Recents and status bar.
- The Casebook at four points: open request, ready to close, closed, and archived evidence.
- The notification heads-up and the notification shade.
- The welcome screen and both mode descriptions.
- The Jobs board, Job offer and active Job.
- The keyboard guide and the pause menu.
- Every note and chat sender in the story, jobs, wildlife and finale paths.
- The model inventory against every `CLAUDE-*` brief; see `docs/MODEL-STATUS.md`.

## Fixed in this pass

### Tablet and welcome

- The tablet home no longer leaks the real world or the game mode. The USDA photographer credit is off the home card and sits on the welcome screen; the mode line is now `FIELD KIT · weather station online`; the latitude is `52°N`.
- The status bar is no longer a fake `LTE 100%`. It reads `LINK · <drone battery>`, and the clock and battery update inside apps instead of freezing when the home screen closes.
- `SANDBOX` is now `Free flight` on the welcome screen, with in-universe copy. The welcome screen no longer shows thermal and night camera buttons before the player has flown.
- The unread badge is capped at `9+ NEW` instead of showing four-digit lifetime counts.

### Casebook

- A closed file no longer shows a stale `CURRENT REQUEST` card. The overview shows the next step, the archived total evidence count, and the closed-file card.
- The Evidence tab archives the filed photographs by chapter instead of showing the last open request's `0 / 2`. When the camera roll no longer holds a filed photograph, it says so instead of contradicting the count.
- Contact `Message` buttons now open the right place: Rennick opens `#town`, Wren opens the Unknown DM, and the crew opens `#general`. They all opened `#town` before.
- Wren's contact card switches from `MISSING HIKER` to `FOUND` once the story is complete.
- Esc now leaves the current app for the tablet home, then closes the tablet on a second press. Before, it closed the whole tablet from any app.

### Notifications and messages

- Notifications are owned by an app. DroneBudz, VidTube and Facade now get their own name and icon, and a title no longer repeats its sender when the sender is the app. The shade uses the latest app; per-app grouped sections are still not built.
- Story chapters no longer post their crew beats twice. The beats now post once, on chapter completion.
- Ghost notes no longer all share the title `A message`; they use `The truth`, `The lake road`, `Wren`, `Please find Wren`, `The cabin`, `The old plot`, `The cabin lights`, `The ridge` and `Found`.
- Job publish notes come from `VidTube`, not from the contact in app copy, and use `$` instead of `money`. The contact's chat failure line is a normal message, not a system row that hides who said it.
- Riley's note says `with the thermal camera on`, not `with T on`. Jo's reply no longer tells the player to open `Flight > DroneBudz jobs`.
- `money` as a unit is replaced with `$` in the Casebook and job notes; the Studio metric is `POT`. The player-facing word `sandbox` is gone from the Jobs board and settings copy.
- The member count is real: `10 MEMBERS` in chat and `10 on the server` on the phone, instead of a hardcoded `6`.

### Keyboard guide

- Tab, T, K, N, G and J are now labelled. The guide was missing the phone, thermal, night vision, notification, gallery and jobs keys while Kit's tips mentioned them.

## Still open

- **Models: none of the 13 briefs is delivered.** This is the largest remaining believability gap; see `docs/MODEL-STATUS.md`. The app icons, avatars, stamps and font are still code and system fallbacks.
- **Notifications are per-message app-owned but not grouped by app.** A mixed set still collapses into one shade group.
- **The landing title is still `AeroSim`.** The subtitle and mode copy are in-universe, but the product name is not a Halloway name.
- **The currency is `$` in a British-leaning valley.** The review flagged this; changing it is a product decision, not a bug I should make silently.
- **The money/pot vocabulary is not fully unified** across older copy outside the touched screens.
- **The dialogs have not been tested at 720p, 1080p, phone aspect ratios, touch or gamepad.** The screenshots are 1280×720.
- **The notification shade in the current save contains old test messages.** They are user data from the dev saves and are not rewritten.
- **Some older saved chat messages still show duplicate beats.** The fix stops new duplicates; it does not rewrite `user://chat.json`.
- **The Casebook evidence archive in the test save says the photographs are no longer in the camera roll.** That is truthful for this test save, but a normal playthrough should show the real thumbnails.

## Evidence

- `docs/realism/ui_review/00_home_clean.jpg`
- `docs/realism/ui_review/01_landing.jpg`
- `docs/realism/ui_review/02_casebook_closed.jpg`
- `docs/realism/ui_review/03_casebook_evidence.jpg`
- `docs/realism/ui_review/04_notifications.jpg`
- `docs/REVIEW-CLAUDE-2026-11-15.md`
- `docs/MODEL-STATUS.md`

## Questions for Robert

- UX1. Is `AeroSim` still the right welcome title, or should the front end read `Halloway Valley`?
- UX2. Do you want the notification shade grouped by app in separate sections, or is one mixed group with an app name enough?
- UX3. Is `$` the valley's currency, or should it be `£`?
- UX4. Should the Casebook archive keep every filed photograph even if the camera roll copy is deleted?
- UX5. Do you want the models commissioned next, starting with the Lake Car and the village?

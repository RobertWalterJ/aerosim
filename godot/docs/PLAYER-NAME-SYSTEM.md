# Player name and callsign

Status: 2026-11-15. The pilot has a saved callsign, and can opt in to having their computer name used as one minor festival character.

## What the player sees

On the welcome screen, under **PILOT**:

- **Callsign** — editable, saved to `user://profile.cfg`, used in DroneBudz, the Casebook, the story greeting and the end card.
- **Use my computer name in the story** — optional checkbox. The game detects the OS account name (`USERNAME` on Windows, `USER`/`LOGNAME` elsewhere), offers it as a first-name suggestion, and lets the player edit or clear it.

If the checkbox is off, no computer name is saved and the festival volunteer stays unnamed. If it is on, only the first name is used, in one festival line and one line of Rennick's final reveal.

## Where the name appears

- Welcome screen callsign field.
- DroneBudz identity panel and the pilot's own message headers.
- Casebook → Contacts → **Pilot** card.
- Rennick's first #town message: "Afternoon, <callsign>…"
- End card note: "Thank you for flying the valley, <callsign>."
- Festival volunteer (optional, real first name): one Jo message and one line in Rennick's final festival reveal.

## Privacy

- Nothing leaves the save.
- The detected full account name is not shown to other characters.
- The real name is not saved until the checkbox is on; turning it off clears the saved real name.
- The callsign can be anything up to 24 characters.
- Generic account names (`user`, `admin`, `owner`, `guest`, `root`) are ignored.

## Files

- `game/player_profile.gd` — detection, sanitising, persistence, festival-name helper.
- `game/landing.gd` — callsign field, opt-in checkbox, real-name edit, scrollable welcome screen.
- `game/chat_app.gd`, `casebook_app.gd`, `story_arc.gd`, `ending.gd` — display and story use.
- `user://profile.cfg`.

## Limits

- The detected name is a **suggestion**; the player can override it.
- The festival volunteer is text-only; there is no extra visible actor for them at the festival field.
- Callsign is not yet in every generic line where characters say "pilot"; those lines remain deliberately generic.

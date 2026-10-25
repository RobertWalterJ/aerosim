# Player character Lou and optional real name

Status: 2026-11-15. The player character is **Lou**. The player can opt in to having their computer account name used as one minor festival character.

## What the player sees

On the welcome screen, under **PILOT**:

- **Name** — fixed as **Lou**, used consistently in DroneBudz, the Casebook, the story greeting and the end card.
- **Use my computer name in the story** — optional checkbox. The game detects the OS account name (`USERNAME` on Windows, `USER`/`LOGNAME` elsewhere), offers it as a first-name suggestion, and lets the player edit or clear it.

If the checkbox is off, no computer name is saved and the festival volunteer stays unnamed. If it is on, only the first name is used, in one festival line and one line of Rennick's final reveal.

## Where the name appears

- Welcome screen name field (fixed to Lou).
- DroneBudz identity panel and Lou's own message headers.
- Casebook → Contacts → **Pilot** card.
- Rennick's first #town message: "Afternoon, Lou…"
- End card note: "Thank you for flying the valley, Lou."
- Festival volunteer (optional, real first name): one Jo message and one line in Rennick's final festival reveal.

## Privacy

- Nothing leaves the save.
- The detected full account name is not shown to other characters.
- The real name is not saved until the checkbox is on; turning it off clears the saved real name.
- The player name is fixed; only the optional festival character name is editable.
- Generic account names (`user`, `admin`, `owner`, `guest`, `root`) are ignored.

## Files

- `game/player_profile.gd` — detection, sanitising, persistence, festival-name helper.
- `game/landing.gd` — fixed Lou name field, opt-in checkbox, real-name edit, scrollable welcome screen.
- `game/chat_app.gd`, `casebook_app.gd`, `story_arc.gd`, `ending.gd` — display and story use.
- `user://profile.cfg`.

## Limits

- The detected name is a **suggestion**; the player can override it.
- The festival volunteer is text-only; there is no extra visible actor for them at the festival field.
- Some generic role lines still say "pilot"; the player character is Lou wherever a name is used.

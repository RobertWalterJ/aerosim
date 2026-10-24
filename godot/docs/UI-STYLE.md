# AeroSim interface style: the valley field kit

Status: applied to the phone, its apps and the HUD menus, 2026-11-06. This is the visual rulebook for every dialogue, notification, app and menu in the valley. It exists so the next screen added still feels like it belongs to AeroSim.

## The idea

The interface is a field notebook and a small provincial broadcast kit, not a generic dark dashboard. Warm paper text on deep pine and charcoal, brass for the one action that matters, moss for the crew and the channel, lake teal for weather and water, rust for VidTube and old metal. It should feel like something a pilot would carry in the valley: practical, quiet, slightly analogue.

## Palette

| Use | Colour |
|---|---|
| Night / app base | `#0E110F` deep pine black |
| Deep chrome / headers | `#131714` |
| Panel | `#181D1A` |
| Card | `#1F241F` |
| Field / pressed | `#2A2F29` |
| Text | `#F0E9D1` warm paper |
| Dim text | `#C2C0AE` |
| Muted text | `#999F8D` |
| Faint text | `#666B5F` |
| Accent / action | `#E0AB59` brass |
| Moss / crew | `#74A87A` |
| Lake / weather | `#5C959F` |
| Rust / VidTube | `#B36447` |
| Danger | `#DB5C52` |
| Hairline | warm cream at 10 percent |
| Strong hairline | brass at 30 percent |

No pure white surfaces. No neon cyan. No blue-purple gradients. No drop shadows larger than a soft short lift.

## Type

- Body 14 to 16, with 3 to 4 px line spacing.
- Screen titles 26 to 32, never all caps for long titles.
- Small caps labels 9 to 11 for sections, roles, states and field notes.
- Actions 15 to 17.
- Numbers (followers, views, money, clock) are the only large display type: 28 to 56.
- Sentence case for dialogue. Small caps for metadata. Numbers in the interface use the middle dot `·` as a separator.

## Components

- **Card:** 12 to 16 px radius, `#1F241F` fill, warm hairline, 16 to 18 px inner margins.
- **Button, ordinary:** dark field, warm hairline, cream text, 10 px radius.
- **Primary button:** brass fill, dark brown text. Exactly one per screen.
- **Ghost button:** transparent with a warm outline, for close, back and secondary actions.
- **Channel row:** no card, 8 px radius, muted until selected, then amber-soft with cream text.
- **Chip:** small field button at 12 px, for the crew questions and compact filters.
- **Field:** dark field, warm hairline, brass caret and selection.
- **Scrollbar:** 3 px brass thumb, no trough.
- **Dialogues:** no bubbles. A left avatar, a name in the speaker's colour, a small-caps role, a quiet time, then the line. System events are a centred muted line with a small diamond. Photos are framed with a warm hairline, not rounded masks.
- **App icon:** a rounded square tinted by the app, the app's two letters in cream, the name below, the category in tiny caps. The home screen is the only place the valley wallpaper is visible.

## App identities

- **Phone home:** valley wallpaper with contour lines and a low brass sun, clock, weather and a field note card. The only screen that shows the wallpaper; apps get a dark scrim so text is always legible.
- **DroneBudz (chat):** moss server mark, channel list with CHANNELS and DIRECT MESSAGES groups, brass selection, avatar colours per crew, a composer with ASK chips and a brass Send.
- **VidTube Studio:** rust channel mark, a channel banner, four metric cards (followers, money, videos, views) with coloured left edges, and a list of uploads with a play tile. Warm, not corporate.
- **Photos:** a quiet gallery grid, warm panel, cream header, no bright chrome.
- **Jobs:** a board of cards with the potential line, a photograph, and raw or edited publish actions. Amber accents, not a marketplace.
- **Facade:** the valley classifieds, with a warm brass mark and MugShot Motors as the slightly dodgy drone seller. Market cards show seller, place, condition, price and a clear Buy or Fly action. The Your kit tab is the inventory: owned drones with Fly, fitted motors, camera add-ons and the battery.
- **Casebook:** brass case accent, a request card, evidence thumbnails, the chapter trail and the ending choice. It should read like a police file kept in a drawer.
- **HUD menus:** the same palette and component language, brass selected tabs, warm cards, dark pine panel. The old cool cyan is gone.
- **Notifications:** Android heads-up cards in warm charcoal, the DroneBudz mark in moss, urgency in amber or rust, no glass.

## Dialogue rules

- Keep the speaker's colour for names only; body text stays warm paper.
- Roles are small caps and quiet. Never let a role outshout the line.
- Times are small and faint.
- System/job events are centred and muted, never full message cards.
- The unknown account keeps the same avatar and role treatment; its separateness comes from the content, not a special effect.
- The ending screen is the exception: black, cream, no chrome, one short epilogue and the credits.

## Motion and feel

- Hover and press are a small colour lift, not a bounce.
- No sliding panels, parallax or animated gradients.
- The phone appears and disappears instantly because the sandbox must keep flying.
- Everything is drawn in code; no texture assets are required beyond the existing photos and HUD icons.

## Accessibility and consistency

- Aim for a contrast of 4.5:1 or better for body text; muted text is for metadata only.
- Minimum touch target 32 px, 40 px for primary actions.
- Do not rely on colour alone for state: add a word, a check mark or an outline.
- Keep the app switcher cards to two columns at 1280 wide, three columns of app icons on the home screen.
- New menus should use `UniverseUI` for the phone and `MenuStyle` for the HUD, or they will drift.

## Files

- `game/ui_theme.gd`: palette, theme, stylebox and label helpers.
- `game/phone_background.gd`: the valley wallpaper.
- `game/phone_os.gd`: home and app switcher.
- `game/chat_app.gd`: DroneBudz.
- `game/studio_app.gd`: VidTube Studio.
- `game/casebook_app.gd`: the Casebook.
- `game/menu_style.gd`: the HUD menu theme.
- `game/phone_notes.gd`: notifications.

## Tablet desktop

The phone home is now a tablet-style desktop: an aerial red-barn photograph as the wallpaper, an Android-like status bar, adaptive app icons, a field-note widget with live wind and battery dials, a dock with app shortcuts and a proper Recents screen. The wallpaper is `assets/ui/tablet_red_barn.jpg`, an aerial view of Mt. Toby Farm by Lance Cheung / USDA NRCS, public domain. The credit is shown on the home card and in `assets/ui/TABLET-WALLPAPER-CREDIT.txt`. The icons are drawn in `game/tablet_icon.gd`; the dials are drawn in `game/tablet_dial.gd`; the battery dial reads the live drone pack from main. Claude has been asked for the polished icon, widget and control kit in `docs/CLAUDE-TABLET-UI.md`.

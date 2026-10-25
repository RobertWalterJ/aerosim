# Phone app availability, downloads and loads

Status: 2026-11-15. The tablet no longer shows every app from the first minute. Apps are available when the game has given the player a reason to use them, and a newly available app is downloaded once before it joins the launcher.

## Availability rules

| App | Available when |
|---|---|
| DroneBudz | Always — the story starts in chat |
| Photos | Always — the camera roll |
| Jobs | Always — the job board |
| Map | Always — road atlas and launch-site travel |
| VidTube Studio | After the first photo or published clip |
| Casebook | After the Rennick story actually starts |
| Facade | After the Rennick story actually starts |

Unavailable apps are not shown on the home grid, dock or app drawer, so the player cannot open an empty app just to find nothing in it.

## Download

When an app becomes available:

1. It is queued for download the next time the tablet is visible.
2. A short full-tablet panel appears: **DOWNLOADING** / app name / progress bar.
3. The app joins the launcher and dock when the download completes.
4. The download is remembered for the session; it does not repeat.

This is deliberately only for newly unlocked apps. Core apps are already installed at the start.

## First-open load

The heavy apps (`Casebook`, `Map`, `Studio`, `Facade`) show a brief **OPENING** panel on their first launch in a session. Chat, Photos and Jobs open immediately. The load screen never appears on subsequent opens.

## Test hooks

- `appdownload` — force Casebook and Facade back into the download path.
- `appload` — force the first-open opening panel for the Map.

## Verification

- `GATE PASS (appavailability)`.
- Download and load panels captured in the screenshot set.
- Story start, existing save, and direct internal app opens are unaffected; debug/direct `_open_app()` still bypasses the launcher gate.

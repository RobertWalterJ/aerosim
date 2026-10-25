# In-world HUD, waypoints and camera attachments

Status: implemented, 2026-11-15. The last-pass objective card and the night pasture objective card were out-of-world game boxes. They are gone. The player now learns the route from the people in the story, and the route is carried by the flight app: a NAV strip, a minimap waypoint and the camera add-on buttons.

## What the player sees now

### The NAV strip and minimap waypoint
- A small amber strip at the bottom centre of the flight screen shows: `NAV  ·  CABIN  ·  520 m`.
- The minimap draws the same target as an amber dot. If the target is outside the map thumbnail, the dot sits on the rim with a short line back to the drone.
- The strip is part of the drone's flight app. It is not an objective card and it never pauses the game.
- The waypoint updates its distance as the drone flies. It is cleared when the story beat is done.

### Friend messages and phone notes
- The last flight is led by Rennick's messages in `#town` and the phone notes. The ghosts now say where the cabin is, where Wren went and when to use the camera.
- Riley's night pasture favour is led by her `#general` messages and the phone note. The NAV target points to the wolf after the thermal camera is fitted.
- The phone notification banner is DroneBudz itself. Nothing in the flight path uses an unrelated system dialog.

### Camera attachment buttons
- When the thermal camera is owned, the flight screen gains a **THERMAL · T** button. It is lit and changes to **THERMAL ON · T** while the camera is on.
- When the night vision module is owned, the screen gains a **NIGHT · K** button in the same stack.
- Tapping either button toggles that camera. The keys still work.
- The thermal camera also draws its full-screen false-colour pass and the **THERMAL CAMERA · T** badge.
- The buttons are part of the flight app, not a tutorial popup.

### Notices with a source
Every HUD notice now carries a small source line above the message:

- `DRONE OS` for flight notices
- `CAMERA` for the camera
- `SKYSYNC` for the weather
- `DRONEBUDZ` for the friends and jobs
- `FACADE` for the marketplace
- `LINK` for the Pike jammer, shotgun and hunter hits
- `VIDTUBE` for publish results

The source line makes a plain message read like a notification from the app that actually owns it. Exported-file notices no longer print a Windows filesystem path.

## Files

- `game/hud.gd`: NAV strip, minimap waypoint hookup, attachment buttons, source-tagged notices.
- `game/minimap.gd`: navigator marker and edge-of-map dot.
- `game/finale.gd`: objective card removed; NAV target to the cabin, then the heat signature; messages and notes carry the story.
- `game/wildlife_case.gd`: objective card removed; NAV target to the wolf; Riley's messages carry the favour.
- `game/thermal.gd`: camera badge with the T key.
- `game/main.gd`: attachment buttons wired to the real thermal and night-vision toggles; source labels on the camera notices.

## Evidence

- `docs/realism/hud/00_nav_waypoint.jpg`
- `docs/realism/hud/01_thermal_attachment.jpg`
- `docs/realism/hud/02_camera_notice.jpg`

## Honest limits

- The NAV strip is a simple straight-line distance, not a turn-by-turn route. It does not route around terrain, the jammer or no-fly land.
- The minimap waypoint is drawn on the heading-up thumbnail; it is not a 3D world marker. The player still has to look out of the window.
- The attachment buttons are plain buttons, not a camera menu with lens choices. The thermal and night vision are the only add-ons with a flight-screen control.
- The source tags are a small text line, not a full app icon or notification centre card.
- The phone notification banner can still cover the top strip for a few seconds. The NAV strip sits at the bottom to avoid that.
- The old objective code paths still exist as hidden state for debugging; they draw nothing.
- The thermal button appears when the module is owned, not when it is physically fitted at the end of the story. The story message and the button are consistent, but there is no separate "fit" animation.
- Keyboard T and K still work without the buttons on desktop. On touch, the buttons are the way.

## Questions for Robert

- HUD1. Should the NAV strip also show a bearing arrow or turn hint, not just distance?
- HUD2. Should the NAV target be clearable by the player, or always owned by the current story beat?
- HUD3. Should the thermal button sit in a small camera tray with the other attachments, or stay as its own top-right stack?
- HUD4. Should the source line use app icons as well as names?
- HUD5. Should the phone notice banner move lower so it never covers the top of the flight screen?

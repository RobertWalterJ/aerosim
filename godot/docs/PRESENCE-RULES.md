# Presence rules: animals, people and traffic

Status: 2026-11-15. The valley is deliberately emptier than the systems that describe it.

## Animals spook

- Sheep: start moving away when the drone is within **58 m**; flee at **4.6 m/s**; the model is hidden inside **25 m**.
- Wolf: starts moving away within **85 m**; flees at **7.2 m/s**; hidden inside **30 m**.
- The flee directions are away from the drone, and the heat signature goes with the animal. Inside the hide radius there is no close-up animal model to inspect.
- The flock and wolf still exist for the thermal-camera story; they are found from a respectful distance, not by flying into them.

## People

- The eight village cast members are **not rendered**. They still exist in the village stats and their messages still arrive in DroneBudz. The valley is carried by radio, phone messages and the places people leave behind.
- Wren is the only story human in the world. Her Blender model is revealed for the search from a distance; it is hidden again whenever the drone gets within **48 m**. The thermal marker is the way to find her; the end-beat wave happens at the designed search distance (105 m), not at close range.
- If a future human model is added, it should follow the same rule: distant reveal, hide inside the keep-out radius, and carry presence through voice/messages/heat rather than a close-up mesh.

## Traffic

- Moving traffic is deliberately sparse: **three vehicles on desktop, two on a phone**.
- The roads still read as roads because the parked/gate vehicles and road furniture remain. A moving car should be an event, not wallpaper.

## Why

The models are readable at distance but not close-up. Hiding the mesh before the player can inspect it keeps the game coherent, makes the valley feel haunted rather than populated, and turns the drone into a respectful observer.

## Test evidence

- Village shot with no human figures: `docs/realism/android_os` is unrelated; the check was `%LOCALAPPDATA%\Temp\shots\spook2_villageshot.png`.
- Wren at 41 m is hidden: `spook2_wrenshow.png`.
- Sheep at close range scatter and disappear: `spook_wildmodels.png`.
- Traffic log after the change: `traffic: { "vehicles": 3, "mobile": false }`.

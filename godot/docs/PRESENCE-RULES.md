# Presence rules: animals, people and traffic

Status: 2026-11-15. The valley is deliberately emptier than the systems that describe it.

## Animals spook

- Sheep: start moving away when the drone is within **58 m**; flee at **4.6 m/s**; they stay visible even at close range.
- Wolf: starts watching at **42 m**, faces the drone and gives a short warning charge, then breaks away at **8.8 m/s** if the drone closes to about 10 m. It never blinks out of existence in front of the player.
- The flee directions are away from the drone, and the heat signature goes with the animal. The animal is still the thing you track, not a model that is removed to protect the camera.
- The flock and wolf still exist for the thermal-camera story; they are found from a respectful distance, not by flying into them.

## People

- The eight village cast members are **not rendered**. They still exist in the village stats and their messages still arrive in DroneBudz. The valley is carried by radio, phone messages and the places people leave behind.
- Wren is the only story human in the world. Her Blender model is revealed for the search from a distance; it is hidden again whenever the drone gets within **48 m**. The thermal marker is the way to find her; the end-beat wave happens at the designed search distance (105 m), not at close range.
- If a future human model is added, it should follow the same rule: distant reveal, hide inside the keep-out radius, and carry presence through voice/messages/heat rather than a close-up mesh.

## Thermal car rules

- **Moving traffic is hot:** each active vehicle has the `ThermalHeat.vehicle()` shell for its engine, warm cabin and exhaust.
- **Parked and abandoned cars are cold:** the village parked cars no longer get a heat shell, and the abandoned Lake Car, festival bus and cabin cruiser have none. In the thermal camera they sit at the temperature of their surroundings, with no red engine or pale cabin patch.
- There is no residual-heat timer; a car that has stopped is treated as cold. If we later want a recently parked car to stay warm for a few minutes, that should be an explicit short-lived heat state on the vehicle, not a permanent shell.
- **People are not represented by visible bodies**, so there are no human heat silhouettes to read as close-up characters; the thermal story uses the animals and the distance-limited Wren marker.

## Traffic

- Moving traffic is deliberately sparse: **three vehicles on desktop, two on a phone**.
- The roads still read as roads because the parked/gate vehicles and road furniture remain. A moving car should be an event, not wallpaper.

## Why

The models are readable at distance but not close-up. Hiding the mesh before the player can inspect it keeps the game coherent, makes the valley feel haunted rather than populated, and turns the drone into a respectful observer.

## Test evidence

- Village shot with no human figures: `docs/realism/android_os` is unrelated; the check was `%LOCALAPPDATA%\Temp\shots\spook2_villageshot.png`.
- Wren at 41 m is hidden: `spook2_wrenshow.png`.
- Sheep at close range scatter and stay visible; the wolf warns and then flees.
- Traffic log after the change: `traffic: { "vehicles": 3, "mobile": false }`.

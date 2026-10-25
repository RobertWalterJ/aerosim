# Harlan Pike and the anti-drone ridge

Harlan Pike is the north-ridge freeman-on-the-land who keeps the player away from the abandoned cabin until the last flight. He never posts in DroneBudz himself. Rennick, Riley and Alex know of him; the player learns about him through them, through the ridge, and through what happens to the drone when it goes north too early.

## The character

Pike believes the county has no jurisdiction over his ridge. He has printed a short, badly set manifesto called **The Unbound Valley** and nailed a copy to a board by his jammer trailer. The story treats him as a neighbour with a bad fence and a worse pamphlet, not a cartoon villain.

He has:

- a rusty box trailer with a tall jammer mast and a red beacon;
- a jammer field that drops the drone link over the ridge;
- three hunter drones that chase and ram slower drones;
- a shotgun for low-flying drones and a warning board for everyone else.

## The rules

### Before the last flight
- Entering the jammer field gives a red HUD warning. After about 2.6 seconds the link fails and the drone returns to the current launch site.
- Pike's hunter drones idle around the ridge. They do not chase until the last flight.
- Rennick, Riley and Alex post a warning when the story reaches act two: the ridge is Pike's, he has a jammer and hunters, and he has been warned off three investigations.
- The player cannot reach the abandoned cabin: the jammer keeps the link, and the approach, closed.

### The jammer goes down
`Finale.start()` calls `AntiDrone.jammer_down_now()`. The mast beacon goes dark and the messages arrive:

- Rennick: the jammer mast came down in the storm; the north frequency is clear; the hunter drones are still up.
- Riley: go fast; the hunters are slow to turn but patient.
- Alex: you will have a signal; do not stop to look at the cabin.

### The last flight
- The jammer no longer forces a return.
- The three hunter drones now chase the player. They fly at about 13 m/s and turn slowly. The racing quad can outrun them; a slow drone cannot.
- A hunter that reaches the drone forces it back to the launch site with a warning, not a crash and not a lost save.
- Below 15 m AGL inside Pike's 92 m shotgun ring, the player gets a warning and is forced back after about 2.2 seconds. The last approach has to be fast or high.

## Site

- `AntiDrone.JAMMER_SPOT` is (-260, -807), in a 14 m clearing at the edge of the new cabin forest.
- The mast is 24 m, above the canopy, with a red beacon and a manifesto board.
- The code placeholders are a rusty trailer, mast, dish, beacon, board, three quadcopter hunters and a clear warning. Final models are requested in `docs/CLAUDE-ANTI-DRONE-ASSETS.md`.

## Evidence

- `docs/realism/anti_drone/00_pike_ridge.jpg`, the cabin and Pike clearing from the air.

## Honest limits

- The hunters are distance-chasing props, not a flight AI. They do not avoid trees or each other.
- The jammer is a radius check with a timer, not a radio simulation or a link-quality model.
- The shotgun is a low-altitude timer and a warning; there is no shooter model, muzzle flash or projectile.
- The forced return is a spawn at the current launch site, not a damaged drone.
- Pike has no direct messages, no portrait and no dialogue. He exists through the other contacts and the site.
- The jammer site is code geometry until Claude's assets land.
- The last flight remains winnable; the hunters are pressure, not a hard failure state.

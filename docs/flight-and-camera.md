# Flight modes, wind and camera controls

## Flight modes
| key | mode | behaviour |
|---|---|---|
| 1 | N (normal) | GPS position and altitude hold, gentle limits |
| 2 | S (sport) | the same with higher speed and bank limits |
| 3 | M (manual) | full acro rates with airmode, no self-levelling |
| 4 | A (aerobatic) | self-levels near centre stick (lean follows the stick up to 55 degrees), full deflection blends into acro rates, throttle is altitude-assisted (centre holds height, up and down set the climb rate) |

Touch: the MODE button cycles N, S, M, A.

### Tricks (aerobatic mode only)
| key | gamepad | touch | trick |
|---|---|---|---|
| J | A | FLIP | flip on the pitch axis (forward, or backward if the pitch stick is pulled back) |
| K | B | ROLL | roll on the roll axis (right, or left if the roll stick is left) |
| N | X | LOOP | power loop |
| M | | SPIN | pirouette (360 degree yaw spin) |
| Shift + arrows | | | flip or roll in the arrow's direction |

Each trick punches up, rotates, then levels out with a throttle boost. They need 4 m of height (1.5 m for the pirouette). Implementation and tunables: `src/game/Aerobatics.ts` (`AERO`); tests: `npm run test:aero`.

## Wind
| level | reference speed at 30 m | gustiness |
|---|---|---|
| calm | 1.0 m/s | 0.45 |
| light (default) | 3.0 m/s | 0.65 |
| breezy | 5.0 m/s | 0.85 |
| strong | 7.5 m/s | 1.0 |

`Z` key, the WIND touch button or `?wind=<level>`. Near the ground the speed is lower (log profile), and behind trees there is a wake with eddies. Values: `WIND_LEVELS` in `src/main.ts`.

## Camera gimbal
| input | action |
|---|---|
| Q / E, mouse wheel, gamepad triggers, touch slider | tilt |
| , / . (hold), Shift + wheel, gamepad LB / RB, drag the touch slider sideways | pan (up to 60 degrees each way) |
| T, gamepad Y, touch LVL | level and centre |
| Y, gamepad D-pad down, touch DOWN | look straight down |

On the FPV freestyle (no gimbal) the tilt input sets the camera uptilt between 0 and 55 degrees.

class_name WeatherSystem
extends RefCounted
## What the weather does to the world. Seven conditions each set a target for cloud cover, cloud darkness, haze, fog,
## how much direct sun gets through, how fast the wind blows and whether rain or snow falls. The current values ease
## towards the target over several seconds, so a change of weather rolls in instead of snapping. Ground wetness
## builds slowly while it rains and dries slowly afterwards. In a storm lightning flashes.

const NAMES := ["Clear", "Partly cloudy", "Overcast", "Fog", "Rain", "Storm", "Snow"]
enum Kind { CLEAR, PARTLY, OVERCAST, FOG, RAIN, STORM, SNOW }

# per condition: cover, dark, cirrus, haze, fog (sky), sun (direct light left), amb (sky light left), fogd (height fog density x),
#                wind (x the menu wind), rain, snow (0..1 base intensity), wet (target wetness)
const TABLE := [
	{"cover": 0.12, "dark": 0.0, "cirrus": 0.35, "haze": 0.02, "fog": 0.0, "sun": 1.0, "amb": 1.0, "fogd": 1.0, "wind": 1.0, "rain": 0.0, "snow": 0.0, "wet": 0.0},
	{"cover": 0.48, "dark": 0.05, "cirrus": 0.25, "haze": 0.22, "fog": 0.0, "sun": 0.78, "amb": 1.0, "fogd": 1.1, "wind": 1.15, "rain": 0.0, "snow": 0.0, "wet": 0.0},
	{"cover": 0.92, "dark": 0.28, "cirrus": 0.0, "haze": 0.38, "fog": 0.1, "sun": 0.2, "amb": 0.9, "fogd": 1.7, "wind": 1.3, "rain": 0.0, "snow": 0.0, "wet": 0.0},
	{"cover": 0.35, "dark": 0.0, "cirrus": 0.0, "haze": 0.75, "fog": 0.95, "sun": 0.35, "amb": 0.95, "fogd": 8.0, "wind": 0.5, "rain": 0.0, "snow": 0.0, "wet": 0.25},
	{"cover": 0.97, "dark": 0.58, "cirrus": 0.0, "haze": 0.5, "fog": 0.4, "sun": 0.1, "amb": 0.75, "fogd": 2.6, "wind": 1.7, "rain": 0.6, "snow": 0.0, "wet": 1.0},
	{"cover": 1.0, "dark": 0.92, "cirrus": 0.0, "haze": 0.6, "fog": 0.55, "sun": 0.05, "amb": 0.55, "fogd": 3.6, "wind": 2.8, "rain": 1.0, "snow": 0.0, "wet": 1.0},
	{"cover": 0.93, "dark": 0.22, "cirrus": 0.0, "haze": 0.62, "fog": 0.45, "sun": 0.22, "amb": 0.95, "fogd": 3.2, "wind": 1.1, "rain": 0.0, "snow": 0.7, "wet": 0.0},
]

var kind := 0
var intensity := 0.6          # 0..1 menu slider: how heavy the rain or snow, how thick the fog
var cur := {}                 # eased values, same keys as TABLE entries plus the extras below
var wet := 0.0                # ground wetness 0..1
var snow_cover := 0.0         # 0..1 how much snow lies on the ground
var flash := 0.0              # lightning, decays quickly
var _next_flash := 6.0
var _t := 0.0

func _init() -> void:
	cur = (TABLE[0] as Dictionary).duplicate()

func set_condition(k: int, inten: float) -> void:
	kind = clampi(k, 0, TABLE.size() - 1)
	intensity = clampf(inten, 0.0, 1.0)

func target() -> Dictionary:
	var t: Dictionary = (TABLE[kind] as Dictionary).duplicate()
	# the intensity slider thickens or thins the precipitation and fog around each condition's own value
	var k := 0.5 + intensity
	t["rain"] = float(t["rain"]) * k
	t["snow"] = float(t["snow"]) * k
	t["fogd"] = 1.0 + (float(t["fogd"]) - 1.0) * k
	t["fog"] = clampf(float(t["fog"]) * k, 0.0, 1.0)
	return t

## Ease the current state towards the target. `snap` jumps straight there (used at start-up).
func update(dt: float, snap := false) -> void:
	_t += dt
	var tg := target()
	var k := 1.0 if snap else 1.0 - exp(-dt / 5.0)    # about five seconds to settle
	for key in tg:
		cur[key] = lerpf(float(cur.get(key, tg[key])), float(tg[key]), k)
	# wetness builds in rain and dries slowly; snow accumulates and melts slowly
	var wet_t := maxf(float(tg["wet"]) * (0.4 + 0.6 * intensity) if float(tg["rain"]) > 0.0 else float(tg["wet"]), 0.0)
	var rate := 1.0 / 40.0 if wet_t > wet else 1.0 / 240.0
	if snap: wet = wet_t
	else: wet = move_toward(wet, wet_t, dt * rate)
	var snow_t := clampf(float(tg["snow"]) * 1.4, 0.0, 1.0) if float(tg["snow"]) > 0.0 else 0.0
	var srate := 1.0 / 60.0 if snow_t > snow_cover else 1.0 / 300.0
	if snap: snow_cover = snow_t
	else: snow_cover = move_toward(snow_cover, snow_t, dt * srate)
	# lightning in a storm: bright quick double flash at random intervals
	flash = maxf(flash - dt * 5.0, 0.0)
	if kind == Kind.STORM:
		_next_flash -= dt
		if _next_flash <= 0.0:
			flash = 1.0
			_next_flash = randf_range(3.0, 11.0) / (0.5 + intensity)
	elif flash > 0.0 and kind != Kind.STORM:
		flash = maxf(flash - dt * 4.0, 0.0)

class_name Solar
extends RefCounted
## Where the sun and moon are for a given day and clock time (equation of time and solar declination for the sun; the
## moon's phase from the date, placed on the ecliptic). Good to about a degree for the sun and a few for the moon.
## The sun part is adapted from the sun rig in the Procedural Main Street project.

const LAT := 43.65     # Toronto
const LON := -79.38
const SYNODIC := 29.530588853
const NEW_MOON_UNIX := 947182440.0     # 2000-01-06 18:14 UTC
const CUM_DAYS := [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]

static func day_of_year(month: int, day: int) -> int:
	return CUM_DAYS[clampi(month, 1, 12) - 1] + day

## Daylight time runs from about 8 March to 1 November.
static func utc_offset_for(doy: int) -> float:
	return -4.0 if (doy >= 68 and doy < 305) else -5.0

static func _alt_az(decl: float, ha: float, lat: float) -> Vector2:
	var phi := deg_to_rad(lat)
	var el := asin(clampf(sin(phi) * sin(decl) + cos(phi) * cos(decl) * cos(ha), -1.0, 1.0))
	var az := atan2(sin(ha), cos(ha) * sin(phi) - tan(decl) * cos(phi)) + PI
	return Vector2(rad_to_deg(el), fposmod(rad_to_deg(az), 360.0))

static func _solar_time(doy: int, clock: float, lon: float, utc_off: float) -> float:
	var b := TAU * (doy - 81) / 365.0
	var eot := 9.87 * sin(2.0 * b) - 7.53 * cos(b) - 1.5 * sin(b)
	return clock + (4.0 * (lon - 15.0 * utc_off) + eot) / 60.0

## Vector2(elevation in degrees, azimuth in degrees clockwise from north).
static func sun_position(doy: int, clock: float, utc_off: float, lat := LAT, lon := LON) -> Vector2:
	var decl := deg_to_rad(23.44) * sin(TAU * (doy - 81) / 365.0)
	var ha := deg_to_rad(15.0 * (_solar_time(doy, clock, lon, utc_off) - 12.0))
	return _alt_az(decl, ha, lat)

## Moon phase 0..1: 0 new, 0.5 full.
static func moon_phase(unix_time: float) -> float:
	return fposmod((unix_time - NEW_MOON_UNIX) / 86400.0 / SYNODIC, 1.0)

static func moon_illumination(phase: float) -> float:
	return 0.5 * (1.0 - cos(phase * TAU))

static func moon_position(doy: int, clock: float, phase: float, utc_off: float, lat := LAT, lon := LON) -> Vector2:
	var eps := deg_to_rad(23.44)
	var lam_s := TAU * (doy - 80) / 365.25
	var lam_m := lam_s + phase * TAU
	var ra_s := atan2(cos(eps) * sin(lam_s), cos(lam_s))
	var ra_m := atan2(cos(eps) * sin(lam_m), cos(lam_m))
	var decl_m := asin(sin(eps) * sin(lam_m))
	var ha_sun := deg_to_rad(15.0 * (_solar_time(doy, clock, lon, utc_off) - 12.0))
	return _alt_az(decl_m, ha_sun + ra_s - ra_m, lat)

## Unit vector from the ground toward a body at (elevation, azimuth); north is -Z, east is +X.
static func direction(el_deg: float, az_deg: float) -> Vector3:
	var el := deg_to_rad(el_deg)
	var az := deg_to_rad(az_deg)
	return Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el)).normalized()

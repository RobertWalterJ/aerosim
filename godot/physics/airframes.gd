class_name Airframes
extends RefCounted
## The five airframes, ported number for number from src/config.ts of the web version.
## Axes: Ixx is pitch, Iyy is yaw, Izz is roll. Angles are in radians.

const DEG := PI / 180.0
const IDS: Array[String] = ["mini", "freestyle", "race", "cinewhoop", "cinema", "wing"]

static func make(id: String) -> Dictionary:
	match id:
		"wing":
			return {
				"id": "wing", "name": "FPV plane", "blurb": "900 g. Fixed wing. Cruises fast, banks to turn, and glides home.",
				"mass": 0.9, "armD": 0.55, "I": Vector3(0.1, 0.1, 0.07),
				"R": 0.127, "sigma": 0.1, "a": 5.0, "Cd0": 0.03, "nBlades": 2, "Jr": 1.2e-5, "kH": 0.01,
				"twr": 1.4, "omegaMax": 1800.0, "tauUp": 0.05, "tauDown": 0.03, "motorEff": 0.8,
				"cells": 3, "capacityAh": 2.2, "rInt": 0.04,
				"dragCd": Vector3(0.3, 0.4, 0.3), "dragA": Vector3(0.06, 0.15, 0.06),
				"hasGimbal": false, "camTilt": 0.0, "camOffset": Vector3(0, 0.06, 0.52),
				"ratesRc": 0.5, "ratesSuper": 0.6, "ratesExpo": 0.25,
				"gain": {"rateP": 20.0, "rateI": 8.0, "rateD": 0.02, "yawP": 16.0, "attP": 8.0},
				"limits": {
					"N": {"vH": 20.0, "bank": 45 * DEG, "vUp": 6.0, "vDown": 6.0, "yawRate": 1.4, "kv": 1.0},
					"S": {"vH": 30.0, "bank": 60 * DEG, "vUp": 10.0, "vDown": 10.0, "yawRate": 2.0, "kv": 0.8},
				},
				"S": 0.25, "cbar": 0.23, "span": 1.104, "CL0": 0.15, "CLa": 5.0, "CD0": 0.03, "kD": 0.08,
				"stallA": 12 * DEG, "CLmax": 1.3, "Cm_a": -0.03, "Cm_e": 0.4, "Cl_a": 0.25, "Cn_r": 0.3, "Cn_adv": 0.02, "Cn_beta": 0.25,
				"Vpitch": 30.0, "Tmax": 20.0,
			}
		"freestyle":
			return {
				"id": "freestyle", "name": "5-inch Freestyle", "blurb": "750 g. Fast and powerful. Made for flips, rolls and tricks.",
				"mass": 0.75, "armD": 0.0795, "I": Vector3(2.6e-3, 4.6e-3, 2.6e-3),
				"R": 0.0635, "sigma": 0.21, "a": 5.0, "Cd0": 0.02, "nBlades": 3, "Jr": 8e-6, "kH": 0.01,
				"twr": 8.0, "omegaMax": 2900.0, "tauUp": 0.022, "tauDown": 0.012, "motorEff": 0.8,
				"cells": 4, "capacityAh": 1.5, "rInt": 0.03,
				"dragCd": Vector3(1.1, 1.2, 1.0), "dragA": Vector3(0.006, 0.02, 0.009),
				"hasGimbal": false, "camTilt": 25 * DEG, "camOffset": Vector3(0, 0.01, -0.06),
				"ratesRc": 0.9, "ratesSuper": 0.72, "ratesExpo": 0.2,
				"gain": {"rateP": 45.0, "rateI": 30.0, "rateD": 0.008, "yawP": 35.0, "attP": 10.0},
				"limits": {
					"N": {"vH": 14.0, "bank": 25 * DEG, "vUp": 6.0, "vDown": 4.0, "yawRate": 1.6, "kv": 2.6},
					"S": {"vH": 25.0, "bank": 38 * DEG, "vUp": 12.0, "vDown": 8.0, "yawRate": 2.4, "kv": 1.4},
				},
			}
		"race":
			return {
				"id": "race", "name": "Race quad", "blurb": "600 g. The fastest. Quick to turn and hard to fly.",
				"mass": 0.6, "armD": 0.0795, "I": Vector3(2.2e-3, 4.0e-3, 2.2e-3),
				"R": 0.0635, "sigma": 0.21, "a": 5.0, "Cd0": 0.02, "nBlades": 3, "Jr": 8e-6, "kH": 0.01,
				"twr": 12.0, "omegaMax": 3200.0, "tauUp": 0.015, "tauDown": 0.009, "motorEff": 0.82,
				"cells": 6, "capacityAh": 1.1, "rInt": 0.025,
				"dragCd": Vector3(0.9, 1.0, 0.8), "dragA": Vector3(0.005, 0.016, 0.007),
				"hasGimbal": false, "camTilt": 35 * DEG, "camOffset": Vector3(0, 0.01, -0.06),
				"ratesRc": 0.95, "ratesSuper": 0.75, "ratesExpo": 0.15,
				"gain": {"rateP": 50.0, "rateI": 32.0, "rateD": 0.009, "yawP": 38.0, "attP": 11.0},
				"limits": {
					"N": {"vH": 18.0, "bank": 30 * DEG, "vUp": 8.0, "vDown": 6.0, "yawRate": 2.0, "kv": 2.8},
					"S": {"vH": 35.0, "bank": 45 * DEG, "vUp": 16.0, "vDown": 10.0, "yawRate": 3.0, "kv": 1.6},
				},
			}
		"cinewhoop":
			return {
				"id": "cinewhoop", "name": "Cinewhoop", "blurb": "350 g. Slow and steady. Guarded props for smooth shots close to things.",
				"mass": 0.35, "armD": 0.055, "I": Vector3(1.0e-3, 1.8e-3, 1.0e-3),
				"R": 0.038, "sigma": 0.35, "a": 5.0, "Cd0": 0.025, "nBlades": 3, "Jr": 3e-6, "kH": 0.01,
				"twr": 3.4, "omegaMax": 2600.0, "tauUp": 0.035, "tauDown": 0.022, "motorEff": 0.72,
				"cells": 4, "capacityAh": 1.2, "rInt": 0.05,
				"dragCd": Vector3(1.4, 1.5, 1.3), "dragA": Vector3(0.012, 0.03, 0.016),
				"hasGimbal": false, "camTilt": 10 * DEG, "camOffset": Vector3(0, 0, -0.06),
				"ratesRc": 0.6, "ratesSuper": 0.5, "ratesExpo": 0.3,
				"gain": {"rateP": 30.0, "rateI": 18.0, "rateD": 0.010, "yawP": 22.0, "attP": 9.0},
				"limits": {
					"N": {"vH": 8.0, "bank": 20 * DEG, "vUp": 3.0, "vDown": 2.5, "yawRate": 1.0, "kv": 2.4},
					"S": {"vH": 14.0, "bank": 32 * DEG, "vUp": 6.0, "vDown": 4.0, "yawRate": 1.8, "kv": 1.4},
				},
			}
		"cinema":
			return {
				"id": "cinema", "name": "Cinema drone", "blurb": "1.4 kg. Big and heavy. Very smooth and slow to turn.",
				"mass": 1.4, "armD": 0.13, "I": Vector3(9e-3, 1.6e-2, 9e-3),
				"R": 0.12, "sigma": 0.11, "a": 5.0, "Cd0": 0.02, "nBlades": 2, "Jr": 4e-5, "kH": 0.01,
				"twr": 2.4, "omegaMax": 1500.0, "tauUp": 0.07, "tauDown": 0.05, "motorEff": 0.8,
				"cells": 6, "capacityAh": 5.0, "rInt": 0.03,
				"dragCd": Vector3(1.0, 1.1, 0.9), "dragA": Vector3(0.02, 0.05, 0.03),
				"hasGimbal": true, "camTilt": 0.0, "camOffset": Vector3(0, -0.03, -0.12),
				"ratesRc": 0.45, "ratesSuper": 0.4, "ratesExpo": 0.3,
				"gain": {"rateP": 18.0, "rateI": 10.0, "rateD": 0.02, "yawP": 14.0, "attP": 7.0},
				"limits": {
					"N": {"vH": 14.0, "bank": 25 * DEG, "vUp": 5.0, "vDown": 3.5, "yawRate": 1.0, "kv": 2.0},
					"S": {"vH": 22.0, "bank": 35 * DEG, "vUp": 8.0, "vDown": 6.0, "yawRate": 1.6, "kv": 1.2},
				},
			}
		_:
			return {
				"id": "mini", "name": "Gimbal Mini", "blurb": "249 g. Light and easy, with a steady gimbal camera. A good place to start.",
				"mass": 0.249, "armD": 0.0675, "I": Vector3(6.5e-4, 1.2e-3, 6.5e-4),
				"R": 0.0585, "sigma": 0.13, "a": 5.0, "Cd0": 0.02, "nBlades": 2, "Jr": 2.5e-6, "kH": 0.01,
				"twr": 2.6, "omegaMax": 2000.0, "tauUp": 0.045, "tauDown": 0.028, "motorEff": 0.78,
				"cells": 3, "capacityAh": 1.3, "rInt": 0.06,
				"dragCd": Vector3(1.0, 1.1, 0.9), "dragA": Vector3(0.0075, 0.02, 0.011),
				"hasGimbal": true, "camTilt": 0.0, "camOffset": Vector3(0, -0.012, -0.07),
				"ratesRc": 0.55, "ratesSuper": 0.55, "ratesExpo": 0.25,
				"gain": {"rateP": 24.0, "rateI": 14.0, "rateD": 0.012, "yawP": 18.0, "attP": 9.0},
				"limits": {
					"N": {"vH": 12.0, "bank": 25 * DEG, "vUp": 4.0, "vDown": 3.0, "yawRate": 1.2, "kv": 2.2},
					"S": {"vH": 20.0, "bank": 38 * DEG, "vUp": 8.0, "vDown": 6.0, "yawRate": 2.0, "kv": 1.2},
				},
			}

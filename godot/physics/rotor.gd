class_name Rotor
extends RefCounted
## Blade-element / momentum rotor model, ported from AerodynamicsBEM.ts.
##   Blade element (linear twist):  Ct = (sigma a / 2) (theta/3 - lambda/2),  lambda = lambda_c + lambda_i
##   Glauert momentum (edgewise):   Ct = 2 lambda_i sqrt(mu^2 + lambda^2)
## solved by bisection for lambda_i. Translational lift emerges from the falling lambda_i as mu rises.
## Ground effect: Cheeseman-Bennett. VRS: thrust loss in the descent window.

var R: float
var sigma: float
var a: float
var Cd0: float
var kH: float
var A: float
var theta: float
var kT: float
var Tmax: float
var kq: float

# results of the last compute()
var T := 0.0
var Q := 0.0
var H := 0.0
var lambda_i := 0.0
var ge := 1.0
var vrs := 0.0

func _init(af: Dictionary, rho0: float = 1.225) -> void:
	R = af["R"]; sigma = af["sigma"]; a = af["a"]; Cd0 = af["Cd0"]; kH = af["kH"]
	var twr: float = af["twr"]; var mass: float = af["mass"]; var omega_max: float = af["omegaMax"]
	A = PI * R * R
	Tmax = (mass * 9.80665 * twr) / 4.0
	var ct_max := Tmax / (rho0 * A * pow(omega_max * R, 2.0))
	# static blade pitch that yields CtMax at omegaMax: Ct = sa/2 (th/3 - li/2), li = sqrt(Ct/2)
	theta = 3.0 * (2.0 * ct_max / (sigma * a) + sqrt(ct_max / 2.0) / 2.0)
	kT = Tmax / (omega_max * omega_max)
	var ct_h := ct_max / twr
	kq = R * (sqrt(ct_h / 2.0) + sigma * Cd0 / (8.0 * ct_h))

func _f(li: float, lc: float, mu: float) -> float:
	var lam := lc + li
	return (sigma * a / 2.0) * (theta / 3.0 - lam / 2.0) - 2.0 * li * sqrt(mu * mu + lam * lam + 1e-12)

func compute(omega: float, vc: float, vperp: float, z_agl: float, rho: float, noise: float) -> void:
	var om := maxf(omega, 1e-3)
	var tip := om * R
	var lc := vc / tip
	var mu := vperp / tip
	# solve f(li) = 0. f falls as li rises, so Newton from the previous answer converges in a few steps;
	# bisection is the fallback if it does not.
	if _f(0.0, lc, mu) <= 0.0:
		lambda_i = 0.0
	else:
		var li := clampf(lambda_i, 0.01, 0.34)
		var k := sigma * a / 4.0
		var ok := false
		for i in 6:
			var lam_n := lc + li
			var root := sqrt(mu * mu + lam_n * lam_n + 1e-12)
			var fv := (sigma * a / 2.0) * (theta / 3.0 - lam_n / 2.0) - 2.0 * li * root
			var dfv := -k - 2.0 * root - 2.0 * li * lam_n / root
			var step := fv / dfv
			li = clampf(li - step, 0.0, 0.35)
			if absf(step) < 1e-9:
				ok = true
				break
		if ok:
			lambda_i = li
		else:
			var lo := 0.0
			var hi := 0.35
			for i in 16:
				var mid := 0.5 * (lo + hi)
				if _f(mid, lc, mu) > 0.0:
					lo = mid
				else:
					hi = mid
			lambda_i = 0.5 * (lo + hi)
	var lam := lc + lambda_i
	var ct := (sigma * a / 2.0) * (theta / 3.0 - lam / 2.0)
	ct *= clampf(1.0 - 1.1 * mu, 0.55, 1.0)   # advancing/retreating blade asymmetry
	if ct < 0.0:
		ct = 0.0
	# ground effect, washed out by forward flight
	var z := maxf(z_agl, 0.25 * R)
	var vi := lambda_i * tip
	var wash := 1.0 + pow(vperp / maxf(vi, 0.5), 2.0)
	var gr := R / (4.0 * z)
	ge = 1.0 / (1.0 - clampf((gr * gr) / wash, 0.0, 0.55)) if z < 2.0 * R else 1.0
	# VRS: hover induced velocity at current thrust
	var vh := sqrt(maxf(ct, 1e-6) * 0.5) * tip
	var r := vc / maxf(vh, 0.3)
	var window := smoothstep(0.05, 0.25, -r) * (1.0 - smoothstep(0.75, 1.15, -r))
	vrs = window * (1.0 - smoothstep(0.35, 1.0, vperp / maxf(vh, 0.3))) * clampf(0.55 + noise, 0.0, 1.0)
	var loss := 0.15 + 0.25 * clampf(noise * 0.5 + 0.5, 0.0, 1.0)
	var vrs_mul := 1.0 - vrs * loss
	var q := rho * A * tip * tip
	T = ct * q * ge * vrs_mul
	Q = maxf(0.0, (maxf(lam, 0.0) * ct + sigma * Cd0 / 8.0)) * q * R
	H = kH * rho * A * tip

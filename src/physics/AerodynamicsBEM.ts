import { clamp, smoothstep } from '../util/math';
import type { Airframe } from '../config';

/**
 * Blade-element / momentum hybrid rotor model.
 *  Blade element (linear twist):   Ct = (sigma a / 2) (theta/3 - lambda/2),  lambda = lambda_c + lambda_i
 *  Glauert momentum (edgewise):    Ct = 2 lambda_i sqrt(mu^2 + lambda^2)
 * solved by bisection for lambda_i. Translational lift then emerges from the falling lambda_i as mu rises
 * (no hard-coded speed band). Ground effect: Cheeseman-Bennett. VRS: stochastic thrust loss in the
 * -0.8..-0.2 v_h window that fades out with edgewise speed.
 */
export interface RotorOut { T: number; Q: number; H: number; lambdaI: number; ge: number; vrs: number; }

export class RotorModel {
  readonly A: number; readonly theta: number; readonly kT: number; readonly Tmax: number; readonly kq: number;
  constructor(readonly af: Airframe, readonly rho0 = 1.225) {
    const { R, sigma, a, twr, mass, omegaMax, Cd0 } = af;
    this.A = Math.PI * R * R;
    this.Tmax = (mass * 9.80665 * twr) / 4;
    const CtMax = this.Tmax / (rho0 * this.A * Math.pow(omegaMax * R, 2));
    // static blade pitch that yields CtMax at omegaMax: Ct = sa/2 (th/3 - li/2), li = sqrt(Ct/2)
    this.theta = 3 * (2 * CtMax / (sigma * a) + Math.sqrt(CtMax / 2) / 2);
    this.kT = this.Tmax / (omegaMax * omegaMax);
    const CtH = CtMax / twr;
    this.kq = R * (Math.sqrt(CtH / 2) + sigma * Cd0 / (8 * CtH));
  }

  compute(omega: number, vc: number, vperp: number, zAgl: number, rho: number, noise: number, out: RotorOut): RotorOut {
    const { R, sigma, a, Cd0 } = this.af;
    const om = Math.max(omega, 1e-3), tip = om * R;
    const lc = vc / tip, mu = vperp / tip;
    const f = (li: number) => (sigma * a / 2) * (this.theta / 3 - (lc + li) / 2) - 2 * li * Math.sqrt(mu * mu + (lc + li) * (lc + li) + 1e-12);
    let lo = 0, hi = 0.35;
    if (f(0) <= 0) { out.lambdaI = 0; } else {
      for (let i = 0; i < 16; i++) { const mid = 0.5 * (lo + hi); if (f(mid) > 0) lo = mid; else hi = mid; }
      out.lambdaI = 0.5 * (lo + hi);
    }
    const lam = lc + out.lambdaI;
    let Ct = (sigma * a / 2) * (this.theta / 3 - lam / 2);
    Ct *= clamp(1 - 1.1 * mu, 0.55, 1);   // advancing/retreating blade asymmetry & retreating-blade loss
    if (Ct < 0) Ct = 0;
    // Ground effect (Cheeseman-Bennett) applied for z in rotor radii; forward flight washes it out.
    const z = Math.max(zAgl, 0.25 * R);
    const vi = out.lambdaI * tip;
    const wash = 1 + Math.pow(vperp / Math.max(vi, 0.5), 2);
    const gr = (R / (4 * z)); 
    out.ge = z < 2 * R ? 1 / (1 - clamp((gr * gr) / wash, 0, 0.55)) : 1;
    // VRS: v_h from hover induced velocity at current thrust.
    const vh = Math.sqrt(Math.max(Ct, 1e-6) * 0.5) * tip; // hover induced velocity = lambda_h * tip
    const r = vc / Math.max(vh, 0.3);
    const window = smoothstep(0.05, 0.25, -r / 1) * (1 - smoothstep(0.75, 1.15, -r)) ;
    out.vrs = window * (1 - smoothstep(0.35, 1.0, vperp / Math.max(vh, 0.3))) * clamp(0.55 + noise, 0, 1);
    const loss = 0.15 + 0.25 * clamp(noise * 0.5 + 0.5, 0, 1);
    const vrsMul = 1 - out.vrs * loss;
    const q = rho * this.A * tip * tip;
    out.T = Ct * q * out.ge * vrsMul;
    out.Q = Math.max(0, (Math.max(lam, 0.0) * Ct + sigma * Cd0 / 8)) * q * R;
    out.H = this.af.kH * rho * this.A * tip; // multiply by perpendicular velocity vector
    return out;
  }
}

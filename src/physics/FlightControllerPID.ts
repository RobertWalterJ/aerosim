import type { Airframe, ModeLimits } from '../config';
import type { Quadcopter6DOF } from './Quadcopter6DOF';
import { G } from './Quadcopter6DOF';
import { qrot, qmul, qeuler, clamp, DEG, V3 } from '../util/math';
import { mulberry32, gauss } from '../util/noise';

export type FlightMode = 'N' | 'S' | 'M';
export interface Sticks { throttle: number; yaw: number; pitch: number; roll: number; } // each -1..1, pitch +1 = forward, roll +1 = right

/**
 * Cascaded controller: velocity (100 Hz) -> attitude (250 Hz) -> rate PID (1 kHz) -> mixer.
 * N/S: GPS velocity + altitude hold with bank limiter. M: Betaflight-style Expo/Super-Rate acro with airmode.
 */
export class FlightController {
  mode: FlightMode = 'N';
  private tick = 0;
  private gyro: V3 = [0, 0, 0];
  private rateSp: V3 = [0, 0, 0];
  private iTerm: V3 = [0, 0, 0];
  private prevGyro: V3 = [0, 0, 0];
  private dFilt: V3 = [0, 0, 0];
  private velI: V3 = [0, 0, 0];
  private thrustCmd = 0;                     // N total
  private tiltSp = { pitch: 0, roll: 0 };    // desired lean (rad) in heading frame
  private yawRateSp = 0;
  private rng = mulberry32(99);
  private vSpH: V3 = [0, 0, 0];
  private altI = 0; private aZ = 0;
  hoverThrottle = 0;
  onGround = false;
  heading = 0;
  tilt = 0;
  constructor(private af: Airframe, private quad: Quadcopter6DOF) { this.hoverThrottle = Math.sqrt(1 / af.twr); }

  setAirframe(af: Airframe) { this.af = af; this.hoverThrottle = Math.sqrt(1 / af.twr); }
  resetState() { this.iTerm = [0, 0, 0]; this.velI = [0, 0, 0]; this.altI = 0; this.tiltSp = { pitch: 0, roll: 0 }; }

  private lim(): ModeLimits { return this.mode === 'S' ? this.af.limits.S : this.af.limits.N; }

  /** Betaflight-like rate curve (rad/s) */
  private acroRate(x: number): number {
    const { ratesRc: rc, ratesSuper: sr, ratesExpo: ex } = this.af;
    const xe = x * (Math.pow(Math.abs(x), 3) * ex + Math.abs(x) * (1 - ex)) / Math.max(Math.abs(x), 1e-6) * Math.sign(x) * Math.abs(x) / Math.max(Math.abs(x), 1e-6);
    const xr = Math.abs(x) < 1e-6 ? 0 : Math.sign(x) * (Math.pow(Math.abs(x), 3) * ex + Math.abs(x) * (1 - ex));
    void xe;
    const base = 200 * rc * xr;
    const f = 1 / clamp(1 - Math.abs(xr) * sr, 0.01, 1);
    return base * f * DEG;
  }

  update(dt: number, st: Sticks): void {
    const q = this.quad, af = this.af, s = q.s;
    if (!q.armed) { q.cmd.fill(0); return; }
    this.tick++;
    // gyro measurement: true rate + noise through PT1 (~180 Hz)
    const gn = 0.002;
    const a = dt / (dt + 1 / (2 * Math.PI * 180));
    for (let i = 0; i < 3; i++) this.gyro[i] += a * (s[10 + i] + gn * gauss(this.rng) - this.gyro[i]);
    // heading + tilt
    const f: V3 = [0, 0, 0]; qrot(s, 6, [0, 0, -1], f);
    const up: V3 = [0, 0, 0]; qrot(s, 6, [0, 1, 0], up);
    this.tilt = Math.acos(clamp(up[1], -1, 1));
    if (this.mode !== 'M' || true) this.heading = Math.atan2(-f[0], -f[2]);
    if (this.mode !== 'M') {
      if (this.tick % 10 === 0) this.velocityLoop(0.01, st);
      if (this.tick % 4 === 0) this.attitudeLoop(st);
    } else {
      this.acroSetpoint(st);
    }
    this.rateLoop(dt);
  }

  private velocityLoop(dt: number, st: Sticks): void {
    const q = this.quad, s = q.s, L = this.lim(), af = this.af;
    const cosH = Math.cos(this.heading), sinH = Math.sin(this.heading);
    // heading-frame velocities (fwd, right). forward = (-sinH, -cosH) in (x,z); right = (cosH, -sinH)
    const fwd: V3 = [-sinH, 0, -cosH], right: V3 = [cosH, 0, -sinH];
    const vF = s[3] * fwd[0] + s[5] * fwd[2], vR = s[3] * right[0] + s[5] * right[2];
    const dz = 0.04; const sh = (x: number) => (Math.abs(x) < dz ? 0 : (x - Math.sign(x) * dz) / (1 - dz));
    const spF = sh(st.pitch) * L.vH, spR = sh(st.roll) * L.vH;
    // brake-limited setpoint slew (S mode brakes less)
    const kv = L.kv;
    let aF = kv * (spF - vF), aR = kv * (spR - vR);
    // integral for wind rejection when sticks centred
    if (Math.abs(st.pitch) < 0.05 && Math.abs(st.roll) < 0.05 && Math.hypot(vF, vR) < 2) { this.velI[0] = clamp(this.velI[0] + 0.5 * (spF - vF) * dt, -2, 2); this.velI[2] = clamp(this.velI[2] + 0.5 * (spR - vR) * dt, -2, 2); } else { this.velI[0] *= 0.97; this.velI[2] *= 0.97; }
    aF += clamp(this.velI[0], -2, 2); aR += clamp(this.velI[2], -2, 2);
    const aMax = G * Math.tan(L.bank);
    const mag = Math.hypot(aF, aR); if (mag > aMax) { aF *= aMax / mag; aR *= aMax / mag; }
    this.tiltSp.pitch = -Math.atan2(aF, G);     // nose-down for forward accel
    this.tiltSp.roll = -Math.atan2(aR, G);      // rotation about +z: negative = right side down
    // vertical
    const vzSp = sh(st.throttle) * (st.throttle > 0 ? L.vUp : L.vDown);
    const aZ = 3.2 * (vzSp - s[4]);
    this.altI = clamp(this.altI + 2.6 * (vzSp - s[4]) * dt, -3, 3);
    this.aZ = aZ + this.altI;
    const cosT = clamp(Math.cos(this.tilt), 0.55, 1);
    this.thrustCmd = (af.mass * (G + this.aZ)) / cosT;
    if (this.onGround && st.throttle < 0.08 && vzSp <= 0.01) { this.thrustCmd = af.mass * G * 0.78; this.tiltSp.pitch = 0; this.tiltSp.roll = 0; this.altI = 0; this.velI = [0, 0, 0]; }
    this.yawRateSp = -sh(st.yaw) * L.yawRate; // stick right -> clockwise from above -> negative about +Y
  }

  private attitudeLoop(st: Sticks): void {
    const s = this.quad.s, af = this.af;
    const qd = qeuler(this.heading, this.tiltSp.pitch, this.tiltSp.roll, [0, 0, 0, 1]);
    // q_err = q_cur^-1 (x) q_des (body frame)
    const qc = [-s[6], -s[7], -s[8], s[9]];
    const qe = qmul(qc, qd, [0, 0, 0, 1]);
    const sg = qe[3] < 0 ? -1 : 1;
    const P = af.gain.attP;
    this.rateSp[0] = 2 * sg * qe[0] * P;
    this.rateSp[2] = 2 * sg * qe[2] * P;
    this.rateSp[1] = this.yawRateSp;
    void st;
  }

  private acroSetpoint(st: Sticks): void {
    // body axes: x pitch (nose-up +), y yaw, z roll (right-side-down = -z)
    this.rateSp[0] = -this.acroRate(st.pitch);   // stick forward -> nose down
    this.rateSp[2] = -this.acroRate(st.roll);    // stick right -> right side down
    this.rateSp[1] = -this.acroRate(st.yaw) * 0.8;
    const u = this.throttleCurve(st.throttle);
    this.thrustCmd = 4 * this.quad.rotor.Tmax * u * u;
    this.stickThrottle = u;
  }
  stickThrottle = 0;
  private throttleCurve(s: number): number {
    const uh = this.hoverThrottle;
    const n = s < 0 ? uh * (0.08 + 0.92 * (1 + s)) : uh + s * (1 - uh);
    return clamp(n, 0.06, 1);
  }

  private rateLoop(dt: number): void {
    const q = this.quad, af = this.af, g = af.gain;
    const P = [g.rateP, g.yawP, g.rateP], I = [g.rateI, g.rateI * 0.6, g.rateI];
    const tau: V3 = [0, 0, 0];
    const damp = this.mode === 'M' ? 1 : 1;
    for (let i = 0; i < 3; i++) {
      const e = this.rateSp[i] - this.gyro[i];
      this.iTerm[i] = clamp(this.iTerm[i] + e * I[i] * dt * damp, -40, 40);
      const dMeas = (this.gyro[i] - this.prevGyro[i]) / dt;
      this.dFilt[i] += 0.12 * (dMeas - this.dFilt[i]);
      this.prevGyro[i] = this.gyro[i];
      const acc = P[i] * e + this.iTerm[i] - g.rateD * 1000 * 0 - g.rateD * this.dFilt[i];
      tau[i] = acc * af.I[i];
    }
    this.mix(this.thrustCmd, tau);
  }

  private mix(Tc: number, tau: V3): void {
    const q = this.quad, d = this.af.armD, kq = q.rotor.kq, Tmax = q.rotor.Tmax;
    const cap = q.omegaCap / this.af.omegaMax; // battery-limited fraction of omegaMax
    const TmaxEff = Tmax * cap * cap;
    const Ti = [0, 0, 0, 0];
    const rp = q.rpos, sp = q.spin;
    for (let i = 0; i < 4; i++) {
      Ti[i] = Tc / 4 + (rp[i][0] * tau[2]) / (4 * d * d) + (-rp[i][2] * tau[0]) / (4 * d * d) + (-sp[i] * tau[1]) / (4 * kq);
    }
    // airmode-style desaturation: shift to keep differential authority
    let mn = Math.min(...Ti), mx = Math.max(...Ti);
    const idle = 0.0036 * Tmax;
    if (mn < idle) { const sh = idle - mn; for (let i = 0; i < 4; i++) Ti[i] += sh; mx += sh; }
    if (mx > TmaxEff) { const sh = mx - TmaxEff; for (let i = 0; i < 4; i++) Ti[i] -= sh; }
    for (let i = 0; i < 4; i++) {
      const t = clamp(Ti[i], idle, TmaxEff);
      q.cmd[i] = Math.sqrt(t / q.rotor.kT);
    }
  }

  get thrustFraction() { return this.thrustCmd / (4 * this.quad.rotor.Tmax); }
}

/**
 * 2-axis mechanical gimbal (pitch + roll) with spring-damper dynamics, yaw follow, and soft mechanical stops
 * (-90 deg nadir .. +20 deg up, relative to the airframe). Body accelerations and motor vibration shake it.
 */
export class Gimbal {
  pitch = -0.35; pv = 0;           // world pitch (rad, + up) and rate
  roll = 0; rv = 0;                // residual world roll
  yawErr = 0; yv = 0;              // lag behind body yaw
  ks = 520; kd = 21;               // ~23 rad/s, zeta ~0.46 (visible shudder)
  stopHit = 0;
  private rng = mulberry32(5);
  /** relative-to-airframe limits (rad) */
  static readonly MIN = -90 * DEG; static readonly MAX = 20 * DEG;
  update(dt: number, cmdPitch: number, bodyPitch: number, bodyPitchAcc: number, bodyRollAcc: number, bodyYawRate: number, vib: number, gust: number, stabilised: boolean): void {
    const n = () => gauss(this.rng);
    const target = stabilised ? cmdPitch : cmdPitch + bodyPitch;
    const dist = -0.55 * bodyPitchAcc + vib * 18 * n() + gust * 6 * n();
    let acc = -this.ks * (this.pitch - target) - this.kd * this.pv + dist;
    const rel = this.pitch - bodyPitch; this.stopHit = 0;
    if (rel > Gimbal.MAX) { acc += -6000 * (rel - Gimbal.MAX) - 60 * Math.max(0, this.pv); this.stopHit = rel - Gimbal.MAX; }
    else if (rel < Gimbal.MIN) { acc += -6000 * (rel - Gimbal.MIN) - 60 * Math.min(0, this.pv); this.stopHit = rel - Gimbal.MIN; }
    this.pv += acc * dt; this.pitch += this.pv * dt;
    const racc = -this.ks * this.roll - this.kd * this.rv - 0.5 * bodyRollAcc + vib * 14 * n() + gust * 5 * n();
    this.rv += racc * dt; this.roll += this.rv * dt;
    const yacc = -this.ks * 0.35 * this.yawErr - this.kd * 0.8 * this.yv - bodyYawRate * 3.2 * 0.0 + vib * 6 * n();
    this.yv += (yacc - 2.0 * bodyYawRate * 0.0) * dt; this.yawErr += (this.yv + (-bodyYawRate) * 0.12) * dt;
    this.yawErr = clamp(this.yawErr, -0.5, 0.5);
  }
}

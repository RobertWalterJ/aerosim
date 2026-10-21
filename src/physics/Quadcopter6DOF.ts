import { RotorModel, RotorOut } from './AerodynamicsBEM';
import type { Airframe } from '../config';
import { qrot, qrotInv, qnormalize, clamp, V3 } from '../util/math';
import { mulberry32, gauss } from '../util/noise';

export interface Environment {
  wind: V3;                                        // m/s at drone position
  groundH(x: number, z: number): number;           // terrain height (m MSL)
  groundN(x: number, z: number, out: number[]): void;
  obstacleHit?(x: number, y: number, z: number, r: number, push: number[]): boolean;
}
export const G = 9.80665;

/** 3S/4S LiPo with open-circuit curve and internal-resistance sag. */
export class Battery {
  soc = 1; vTerm: number; current = 0; vOc: number;
  constructor(public cells: number, public capacityAh: number, public rInt: number) { this.vOc = this.ocv(1) * cells; this.vTerm = this.vOc; }
  ocv(soc: number): number { // per-cell OCV (typical LiPo)
    const s = clamp(soc, 0, 1);
    if (s > 0.9) return 4.05 + (s - 0.9) * 1.5;      // 4.05..4.2
    if (s > 0.2) return 3.70 + (s - 0.2) * (0.35 / 0.7); // plateau 3.70..4.05
    if (s > 0.05) return 3.45 + (s - 0.05) * (0.25 / 0.15);
    return 3.0 + s * 9;
  }
  update(pElec: number, dt: number): void {
    this.vOc = this.ocv(this.soc) * this.cells;
    const disc = Math.max(this.vOc * this.vOc - 4 * this.rInt * pElec, 0.25 * this.vOc * this.vOc);
    this.vTerm = (this.vOc + Math.sqrt(disc)) / 2;
    this.current = pElec / this.vTerm;
    this.soc = Math.max(0, this.soc - (this.current * dt) / (this.capacityAh * 3600));
  }
  get cellV() { return this.vTerm / this.cells; }
  /** Scale on achievable motor speed (KV * voltage). */
  get voltageScale() { return this.vTerm / (this.cells * 4.1); }
}

const N_STATE = 17;
export class Quadcopter6DOF {
  readonly rotor: RotorModel;
  readonly battery: Battery;
  /** state: pos(3) vel(3) quat xyzw(4) omegaBody(3) motorOmega(4) */
  s = new Float64Array(N_STATE);
  prevPos = new Float64Array(3); prevQuat = new Float64Array(4);
  cmd = new Float64Array(4);
  armed = true; crashed = false; crashReason = '';
  readonly rpos: V3[]; readonly spin = [-1, 1, -1, 1]; // FR, RR, RL, FL
  groundContact = false; maxImpact = 0;
  rho = 1.225;
  // diagnostics
  thrust = new Float64Array(4); torqueQ = new Float64Array(4); vrs = 0; ge = 1; pElec = 0; angAccel = [0, 0, 0];
  private rng = mulberry32(1234);
  private turb = [0, 0, 0]; private vrsNoise = 0; private nTime = 0;
  private ro: RotorOut = { T: 0, Q: 0, H: 0, lambdaI: 0, ge: 1, vrs: 0 };
  private k: Float64Array[] = [0, 1, 2, 3].map(() => new Float64Array(N_STATE));
  private tmp = new Float64Array(N_STATE);
  private env!: Environment;
  private gN = [0, 1, 0]; private gH0 = 0;
  private contactPts: V3[];

  constructor(public af: Airframe) {
    this.rotor = new RotorModel(af);
    this.battery = new Battery(af.cells, af.capacityAh, af.rInt);
    const d = af.armD;
    // body frame: +x right, +y up, forward = -z
    this.rpos = [[d, 0, -d], [d, 0, d], [-d, 0, d], [-d, 0, -d]];
    const f = 0.03;
    this.contactPts = [];
    for (const p of this.rpos) { this.contactPts.push([p[0], -f, p[2]]); }
    for (const p of this.rpos) { this.contactPts.push([p[0] * 0.8, f + 0.012, p[2] * 0.8]); }
    this.reset(0, 0, 0, 0);
  }

  reset(x: number, y: number, z: number, yaw: number): void {
    this.s.fill(0);
    this.s[0] = x; this.s[1] = y; this.s[2] = z;
    this.s[6] = 0; this.s[7] = Math.sin(yaw / 2); this.s[8] = 0; this.s[9] = Math.cos(yaw / 2);
    this.prevPos.set([x, y, z]); this.prevQuat.set([0, this.s[7], 0, this.s[9]]);
    this.armed = true; this.crashed = false; this.crashReason = ''; this.cmd.fill(0);
    this.battery.soc = 1; this.battery.update(0, 0);
  }
  get pos() { return this.s.subarray(0, 3); }
  get vel() { return this.s.subarray(3, 6); }
  get quat() { return this.s.subarray(6, 10); }
  get omega() { return this.s.subarray(10, 13); }
  get motorOmega() { return this.s.subarray(13, 17); }
  /** Cap on motor speed from battery voltage (KV x V). */
  get omegaCap() { return this.af.omegaMax * Math.min(1.02, this.battery.voltageScale / 0.985 * 0.985 + 0.0); }

  private deriv(s: Float64Array, out: Float64Array): void {
    const af = this.af, m = af.mass, env = this.env;
    const q = s, qo = 6;
    const rho = this.rho;
    const vRelW: V3 = [s[3] - env.wind[0], s[4] - env.wind[1], s[5] - env.wind[2]];
    const vRelB: V3 = [0, 0, 0]; qrotInv(q, qo, vRelW, vRelB);
    const w: V3 = [s[10], s[11], s[12]];
    const F: V3 = [0, 0, 0], tau: V3 = [0, 0, 0];
    let sumSpin = 0;
    const pos0 = [s[0], s[1], s[2]];
    const rw: V3 = [0, 0, 0];
    for (let i = 0; i < 4; i++) {
      const r = this.rpos[i];
      // rotor velocity relative to air in body frame, includes w x r
      const vx = vRelB[0] + (w[1] * r[2] - w[2] * r[1]);
      const vy = vRelB[1] + (w[2] * r[0] - w[0] * r[2]);
      const vz = vRelB[2] + (w[0] * r[1] - w[1] * r[0]);
      qrot(q, qo, r, rw);
      const zAgl = s[1] + rw[1] - this.gH0;
      const o = this.rotor.compute(s[13 + i], vy, Math.hypot(vx, vz), zAgl, rho, this.vrsNoise + 0.35 * Math.sin(i * 1.7 + this.nTime * 31), this.ro);
      const T = o.T;
      this.thrust[i] = T; this.torqueQ[i] = o.Q;
      // in-plane H-force opposing edgewise airspeed
      const Hx = -o.H * vx, Hz = -o.H * vz;
      F[0] += Hx; F[1] += T; F[2] += Hz;
      // moment of rotor force about CG: r x F
      tau[0] += r[1] * (Hz) - r[2] * T;
      tau[1] += r[2] * Hx - r[0] * Hz;
      tau[2] += r[0] * T - r[1] * Hx;
      tau[1] += -this.spin[i] * o.Q;                    // reaction torque
      sumSpin += this.spin[i] * s[13 + i];
      if (i === 0) { this.ge = o.ge; }
      this.vrs = Math.max(i === 0 ? 0 : this.vrs, o.vrs);
    }
    // body drag
    for (let a = 0; a < 3; a++) {
      const v = vRelB[a];
      F[a] -= 0.5 * rho * af.dragCd[a] * af.dragA[a] * Math.abs(v) * v;
    }
    // gyroscopic precession from rotor angular momentum (about body Y)
    const Hr = af.Jr * sumSpin;
    tau[0] -= -w[2] * Hr;    // -(w x H)_x with H=(0,Hr,0): (w x H) = (w_y*0 - w_z*Hr, w_z*0 - w_x*0, w_x*Hr - w_y*0)
    tau[2] -= w[0] * Hr;
    // propwash / VRS turbulence torque
    tau[0] += this.turb[0]; tau[1] += this.turb[1]; tau[2] += this.turb[2];
    // rigid-body: I dw = tau - w x I w
    const I = af.I;
    const Iw: V3 = [I[0] * w[0], I[1] * w[1], I[2] * w[2]];
    const wxIw: V3 = [w[1] * Iw[2] - w[2] * Iw[1], w[2] * Iw[0] - w[0] * Iw[2], w[0] * Iw[1] - w[1] * Iw[0]];
    // force to world
    const Fw: V3 = [0, 0, 0]; qrot(q, qo, F, Fw);
    Fw[1] -= m * G;
    // ground contact points (penalty spring-damper with friction)
    this.groundContact = false;
    const kC = (m * G / 4) / 0.003, cC = 2 * 0.55 * Math.sqrt(kC * m / 4);
    const pw: V3 = [0, 0, 0], vb: V3 = [0, 0, 0], vw: V3 = [0, 0, 0];
    const n = this.gN;
    const tauC: V3 = [0, 0, 0];
    for (const cp of this.contactPts) {
      qrot(q, qo, cp, pw);
      const px = pos0[0] + pw[0], py = pos0[1] + pw[1], pz = pos0[2] + pw[2];
      const h = env.groundH(px, pz);
      const pen = h - py;
      if (pen <= 0) continue;
      this.groundContact = true;
      vb[0] = w[1] * cp[2] - w[2] * cp[1]; vb[1] = w[2] * cp[0] - w[0] * cp[2]; vb[2] = w[0] * cp[1] - w[1] * cp[0];
      qrot(q, qo, vb, vw);
      vw[0] += s[3]; vw[1] += s[4]; vw[2] += s[5];
      const vn = vw[0] * n[0] + vw[1] * n[1] + vw[2] * n[2];
      const Fn = Math.max(0, kC * Math.min(pen, 0.05) - cC * vn);
      let tx = vw[0] - vn * n[0], ty = vw[1] - vn * n[1], tz = vw[2] - vn * n[2];
      const tm = Math.hypot(tx, ty, tz); const fr = 0.7 * Fn / (tm + 0.04);
      const fx = Fn * n[0] - fr * tx, fy = Fn * n[1] - fr * ty, fz = Fn * n[2] - fr * tz;
      Fw[0] += fx; Fw[1] += fy; Fw[2] += fz;
      // torque in body frame = r_body x F_body
      const fb: V3 = [0, 0, 0]; qrotInv(q, qo, [fx, fy, fz], fb);
      tauC[0] += cp[1] * fb[2] - cp[2] * fb[1]; tauC[1] += cp[2] * fb[0] - cp[0] * fb[2]; tauC[2] += cp[0] * fb[1] - cp[1] * fb[0];
      // angular damping while resting (rolling resistance)
    }
    tau[0] += tauC[0] - (this.groundContact ? 0.002 * w[0] : 0);
    tau[1] += tauC[1] - (this.groundContact ? 0.002 * w[1] : 0);
    tau[2] += tauC[2] - (this.groundContact ? 0.002 * w[2] : 0);

    out[0] = s[3]; out[1] = s[4]; out[2] = s[5];
    out[3] = Fw[0] / m; out[4] = Fw[1] / m; out[5] = Fw[2] / m;
    // q_dot = 0.5 q (x) (w, 0)
    const qx = s[6], qy = s[7], qz = s[8], qw = s[9];
    out[6] = 0.5 * (qw * w[0] + qy * w[2] - qz * w[1]);
    out[7] = 0.5 * (qw * w[1] + qz * w[0] - qx * w[2]);
    out[8] = 0.5 * (qw * w[2] + qx * w[1] - qy * w[0]);
    out[9] = 0.5 * (-qx * w[0] - qy * w[1] - qz * w[2]);
    out[10] = (tau[0] - wxIw[0]) / I[0]; out[11] = (tau[1] - wxIw[1]) / I[1]; out[12] = (tau[2] - wxIw[2]) / I[2];
    this.angAccel[0] = out[10]; this.angAccel[1] = out[11]; this.angAccel[2] = out[12];
    for (let i = 0; i < 4; i++) {
      const c = this.cmd[i], o = s[13 + i];
      out[13 + i] = (c - o) / (c > o ? af.tauUp : af.tauDown);
    }
  }

  step(dt: number, env: Environment): void {
    this.env = env;
    this.prevPos.set(this.s.subarray(0, 3)); this.prevQuat.set(this.s.subarray(6, 10));
    const s = this.s;
    this.rho = 1.225 * Math.exp(-Math.max(s[1], 0) / 8500);
    // environment sampling once per step
    this.gH0 = env.groundH(s[0], s[2]); env.groundN(s[0], s[2], this.gN);
    // clamp commands to battery capability
    const cap = this.omegaCap;
    if (!this.armed) this.cmd.fill(0);
    for (let i = 0; i < 4; i++) this.cmd[i] = clamp(this.cmd[i], 0, cap);
    // propwash / VRS stochastic terms (held across RK stages)
    this.nTime += dt;
    this.vrsNoise = 0.8 * this.vrsNoise + 0.2 * gauss(this.rng) * 0.6;
    const spd = Math.hypot(s[3], s[4], s[5]);
    const tAmp = (0.00015 + 0.0006 * this.vrs) * this.af.mass * (1 + 0.03 * spd) * (this.af.id === 'freestyle' ? 4 : 1);
    this.turb[0] = tAmp * gauss(this.rng); this.turb[1] = 0.2 * tAmp * gauss(this.rng); this.turb[2] = tAmp * gauss(this.rng);
    // RK4
    const [k1, k2, k3, k4] = this.k, t = this.tmp;
    this.vrs = 0;
    this.deriv(s, k1);
    for (let i = 0; i < N_STATE; i++) t[i] = s[i] + 0.5 * dt * k1[i];
    this.deriv(t, k2);
    for (let i = 0; i < N_STATE; i++) t[i] = s[i] + 0.5 * dt * k2[i];
    this.deriv(t, k3);
    for (let i = 0; i < N_STATE; i++) t[i] = s[i] + dt * k3[i];
    this.deriv(t, k4);
    for (let i = 0; i < N_STATE; i++) s[i] += (dt / 6) * (k1[i] + 2 * k2[i] + 2 * k3[i] + k4[i]);
    qnormalize(s, 6);
    for (let i = 0; i < 4; i++) s[13 + i] = clamp(s[13 + i], 0, cap * 1.05);
    // electrical power (shaft / efficiency + avionics)
    let pShaft = 0; for (let i = 0; i < 4; i++) pShaft += this.torqueQ[i] * s[13 + i];
    this.pElec = pShaft / this.af.motorEff + (this.armed ? 2.5 : 0.5);
    this.battery.update(this.pElec, dt);
    if (this.battery.soc <= 0 && this.armed) { this.armed = false; this.crashReason = 'BATTERY DEPLETED'; }
    this.checkImpacts(env);
  }

  private checkImpacts(env: Environment): void {
    const s = this.s;
    if (this.crashed) return;
    // upper contact points touching ground = inverted -> crash; fast contact -> crash
    const pw: V3 = [0, 0, 0];
    let vImpact = 0;
    for (let i = 0; i < this.contactPts.length; i++) {
      const cp = this.contactPts[i];
      qrot(s, 6, cp, pw);
      const h = env.groundH(s[0] + pw[0], s[2] + pw[2]);
      const pen = h - (s[1] + pw[1]);
      if (pen > 0.004) {
        if (i >= 4) { this.markCrash('INVERTED / BODY STRIKE'); return; }
        vImpact = Math.max(vImpact, -s[4]);
      }
    }
    this.maxImpact = vImpact;
    if (vImpact > 5.5 && this.groundContact) { this.markCrash('HARD IMPACT ' + vImpact.toFixed(1) + ' m/s'); return; }
    if (env.obstacleHit) {
      const push = [0, 0, 0];
      if (env.obstacleHit(s[0], s[1], s[2], 0.12, push)) {
        s[0] += push[0]; s[2] += push[2];
        const sp = Math.hypot(s[3], s[4], s[5]);
        s[3] *= -0.2; s[5] *= -0.2;
        if (sp > 1.2) this.markCrash('COLLISION'); 
      }
    }
  }
  private markCrash(why: string): void { this.crashed = true; this.armed = false; this.crashReason = why; this.cmd.fill(0); }
}

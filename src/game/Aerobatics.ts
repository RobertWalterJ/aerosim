// Aerobatics mode ("A"). A stick-shaping layer on top of the existing acro
// (M) controller, so no physics code changes:
//  - near-centre sticks self-level like Betaflight Horizon mode (lean angle
//    follows the stick, up to 55 degrees); full deflection blends into pure
//    acro rates, so you can still flip by hand;
//  - throttle is altitude-assisted while upright (centre stick = hold height,
//    up/down = climb/sink rate);
//  - one-button tricks: flip (pitch), roll (roll axis), power loop, pirouette.
// While A mode is active the flight controller runs in M with a cloned airframe
// that has faster rates (the mini's camera-drone rates are too slow to flip).
import type { Airframe } from '../config';
import type { FlightController, Sticks } from '../physics/FlightControllerPID';
import type { Quadcopter6DOF } from '../physics/Quadcopter6DOF';
import { G } from '../physics/Quadcopter6DOF';
import { qrot, clamp, smoothstep, DEG, type V3 } from '../util/math';

export type TrickKind = 'flip' | 'roll' | 'loop' | 'pirouette';
type Phase = 'punch' | 'spin' | 'recover';
interface Trick { kind: TrickKind; dir: number; phase: Phase; t: number; acc: number; }

/** Tunables (see docs/assets/aerobatics.md). */
export const AERO = {
  maxLean: 55 * DEG,        // self-level lean at full horizon deflection
  levelRate: 7,             // rad/s commanded per rad of attitude error
  acroBlend: [0.62, 0.97],  // stick range where self-levelling hands over to pure acro
  vzUp: 5, vzDown: 4,       // altitude assist climb/sink rate at full throttle stick (m/s)
  punch: { flip: 0.22, roll: 0.18, loop: 0.35, pirouette: 0 },
  recover: 0.55,
  minRatesRc: 0.85, minRatesSuper: 0.68,  // airframe rates while in A mode
};

export class Aerobatics {
  active = false;
  trick: Trick | null = null;
  /** completed tricks this flight (shown in the OSD) */
  count = 0;
  lastTrick = '';
  private out: Sticks = { throttle: 0, yaw: 0, pitch: 0, roll: 0 };
  private up: V3 = [0, 0, 0]; private fw: V3 = [0, 0, 0]; private rt: V3 = [0, 0, 0];
  private aeroAf: Airframe | null = null;
  constructor(private fc: FlightController, private quad: Quadcopter6DOF, private af: Airframe) {}

  /** Enter or leave A mode. Uses the M controller with faster rates. */
  setActive(on: boolean, af: Airframe): void {
    this.af = af; this.trick = null;
    if (on) {
      this.aeroAf = { ...af, ratesRc: Math.max(af.ratesRc, AERO.minRatesRc), ratesSuper: Math.max(af.ratesSuper, AERO.minRatesSuper) };
      this.fc.setAirframe(this.aeroAf); this.fc.mode = 'M';
    } else if (this.active) this.fc.setAirframe(af);
    this.active = on; this.fc.resetState();
  }

  /** Start a trick. dir: +1 forward/right/clockwise, -1 the other way; 0 picks from the sticks. */
  start(kind: TrickKind, sticks?: Sticks, dir = 0): void {
    if (!this.active || this.trick || !this.quad.armed || this.fc.onGround) return;
    if (!dir) {
      const s = sticks ?? this.out;
      dir = kind === 'flip' ? (s.pitch < -0.25 ? -1 : 1) : kind === 'roll' ? (s.roll < -0.25 ? -1 : 1) : kind === 'pirouette' ? (s.yaw < -0.25 ? -1 : 1) : 1;
    }
    this.trick = { kind, dir, phase: AERO.punch[kind] > 0 ? 'punch' : 'spin', t: 0, acc: 0 };
  }

  /** small stick value that produces `rate` rad/s near centre on this airframe */
  private stickFor(rate: number): number {
    const a = this.aeroAf ?? this.af;
    const slope = 200 * a.ratesRc * (1 - a.ratesExpo) * DEG;
    return rate / slope;
  }

  /** stick value that produces thrust for vertical acceleration aZ given the current tilt */
  private throttleFor(aZ: number): number {
    const fc = this.fc, q = this.quad;
    const cosT = Math.max(this.up[1], 0.45);
    const T = (this.af.mass * (G + aZ)) / cosT;
    const u = Math.sqrt(clamp(T / (4 * q.rotor.Tmax), 0, 1));
    const uh = fc.hoverThrottle;
    const s = u >= uh ? (u - uh) / (1 - uh) : (u / uh - 0.08) / 0.92 - 1;
    return clamp(s, -1, 1);
  }

  /** Shape the pilot sticks; call once per physics step before fc.update. */
  shape(dt: number, st: Sticks): Sticks {
    const q = this.quad, s = q.s, o = this.out;
    qrot(s, 6, [0, 1, 0], this.up); qrot(s, 6, [0, 0, -1], this.fw); qrot(s, 6, [1, 0, 0], this.rt);
    const up = this.up, fw = this.fw, rt = this.rt;
    const pitchAng = Math.asin(clamp(fw[1], -1, 1));   // nose up +
    const rollAng = Math.atan2(-rt[1], up[1]);          // right side down +, full circle
    // ---- self-levelling sticks (Horizon-like). Stick + = nose down / right side down.
    const blend = (cmd: number, stick: number): number => {
      const w = smoothstep(AERO.acroBlend[0], AERO.acroBlend[1], Math.abs(stick));
      return clamp(cmd, -0.95, 0.95) * (1 - w) + stick * w;
    };
    const upright = up[1] > 0.05;
    const levelPitch = (stick: number): number => upright ? blend(this.stickFor(AERO.levelRate * (pitchAng + stick * AERO.maxLean)), stick) : stick;
    const levelRoll = (stick: number): number => blend(this.stickFor(AERO.levelRate * (stick * AERO.maxLean - rollAng)), stick);
    // ---- altitude assist
    const vzHold = (stick: number): number => {
      if (this.fc.onGround && stick < 0.12) return st.throttle;
      if (up[1] < 0.25) return st.throttle;
      const dz = 0.06, sh = Math.abs(stick) < dz ? 0 : (stick - Math.sign(stick) * dz) / (1 - dz);
      const vz = sh * (sh > 0 ? AERO.vzUp : AERO.vzDown);
      return this.throttleFor(clamp(3.2 * (vz - s[4]), -6, 12));
    };

    const tr = this.trick;
    if (!tr) {
      o.pitch = levelPitch(st.pitch); o.roll = levelRoll(st.roll); o.yaw = st.yaw; o.throttle = vzHold(st.throttle);
      return o;
    }
    // ---- trick sequencer
    tr.t += dt;
    const k = tr.kind;
    if (tr.phase === 'punch') {
      o.pitch = levelPitch(0); o.roll = levelRoll(0); o.yaw = 0; o.throttle = 1;
      if (tr.t >= AERO.punch[k]) { tr.phase = 'spin'; tr.t = 0; }
      return o;
    }
    if (tr.phase === 'spin') {
      o.pitch = 0; o.roll = 0; o.yaw = 0;
      if (k === 'flip') { o.pitch = tr.dir; o.throttle = -0.55; tr.acc += Math.abs(s[10]) * dt; }
      else if (k === 'roll') { o.roll = tr.dir; o.throttle = -0.45; tr.acc += Math.abs(s[12]) * dt; }
      else if (k === 'loop') { o.pitch = -0.68; o.throttle = up[1] > -0.2 ? 1 : 0.25; tr.acc += Math.abs(s[10]) * dt; }
      else { o.pitch = levelPitch(0); o.roll = levelRoll(0); o.yaw = tr.dir; o.throttle = vzHold(0); tr.acc += Math.abs(s[11]) * dt; }
      const done = tr.acc >= Math.PI * 2 - (k === 'loop' ? 0.35 : k === 'pirouette' ? 0.25 : 0.55);
      if (done || tr.t > 4) { tr.phase = 'recover'; tr.t = 0; }
      return o;
    }
    // recover: level out with a throttle boost, then hand back
    o.pitch = levelPitch(st.pitch * 0.3); o.roll = levelRoll(st.roll * 0.3); o.yaw = st.yaw;
    o.throttle = up[1] > 0.5 ? Math.max(this.throttleFor(clamp(3.2 * (0 - s[4]), -2, 12)), 0.2) : 0.5;
    if (tr.t >= AERO.recover) { this.trick = null; this.count++; this.lastTrick = k; }
    return o;
  }

  /** text for the OSD */
  label(): string {
    if (!this.active) return '';
    return this.trick ? `TRICK: ${this.trick.kind.toUpperCase()}` : `tricks ${this.count}${this.lastTrick ? ' (last: ' + this.lastTrick + ')' : ''}`;
  }
}

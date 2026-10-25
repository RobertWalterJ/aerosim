// Chase-camera drone model driven by the simulation state: rotor spin from
// the real motor speeds (with sharp-blade to blur-disc cross-fade), gimbal
// pivots from the gimbal angles, LEDs from the armed and battery state.
// Replaces DroneModel by default; ?drone=legacy keeps the old model.
import * as THREE from 'three';
import type { Airframe } from '../../config';
import { buildMiniDrone } from './MiniDrone';
import { buildFreestyleDrone } from './FreestyleDrone';
import type { DroneBuild, DroneVariant, Lod } from './parts';

export interface DroneViewState {
  /** motor speeds in rad/s, rotor order 0 FR, 1 RR, 2 RL, 3 FL */
  omega: ArrayLike<number>;
  dt: number;
  time: number;
  armed: boolean;
  /** battery state of charge 0..1 */
  soc: number;
  /** camera orientation relative to the body (gimballed airframes) */
  gimbalRel?: THREE.Quaternion;
  /** the model is only built once it is first shown */
  visible: boolean;
}

const smooth = (a: number, b: number, x: number): number => { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t); };

export class DroneView {
  group = new THREE.Group();
  build: DroneBuild | null = null;
  private angle = [0, 0, 0, 0];
  private euler = new THREE.Euler(0, 0, 0, 'YZX');
  constructor(private af: Airframe, private lod: Lod, private spin: readonly number[], private variant: DroneVariant = {}) {
    this.group.name = 'drone-view';
  }
  setAirframe(af: Airframe): void {
    this.af = af;
    this.dispose();
  }
  private dispose(): void {
    if (!this.build) return;
    this.build.root.traverse((o) => { const m = o as THREE.Mesh; if (m.isMesh) m.geometry.dispose(); });
    this.group.clear();
    this.build = null;
  }
  /** Build ahead of time (call when the main thread is idle) so the first chase view does not hitch. */
  prewarm(): void { this.ensure(); }
  private ensure(): DroneBuild {
    if (this.build) return this.build;
    const v = { ...this.variant, spin: this.spin };
    this.build = this.af.id === 'mini' ? buildMiniDrone(v, this.lod) : buildFreestyleDrone(v, this.lod);
    this.build.root.traverse((o) => { if ((o as THREE.Mesh).isMesh) { o.castShadow = true; o.receiveShadow = true; } });
    this.group.add(this.build.root);
    return this.build;
  }
  update(s: DroneViewState): void {
    if (!s.visible && !this.build) return;
    const b = this.ensure();
    // rotors: integrate the real speed; above ~20 rev/s fade to the blur disc
    for (let i = 0; i < 4; i++) {
      const w = s.omega[i] ?? 0, r = b.rotors[i]!;
      const sgn = (r.userData['spin'] as number) ?? 1;
      this.angle[i] = (this.angle[i]! + sgn * w * s.dt) % (Math.PI * 2);
      r.rotation.y = this.angle[i]!;
      const rps = Math.abs(w) / (Math.PI * 2);
      const blur = r.getObjectByName('bladesBlur') as THREE.Mesh, sharp = r.getObjectByName('bladesSharp')!;
      const k = smooth(12, 28, rps);
      sharp.visible = rps < 25;
      blur.visible = k > 0.01;
      (blur.material as THREE.MeshStandardMaterial).opacity = k * ((blur.material as THREE.Material).userData['baseOpacity'] as number ?? 1);
    }
    // gimbal: relative camera orientation -> yaw, roll, pitch pivots (mechanical limits)
    if (b.gimbal && s.gimbalRel) {
      this.euler.setFromQuaternion(s.gimbalRel, 'YZX');
      b.gimbal.yaw.rotation.y = THREE.MathUtils.clamp(this.euler.y, -1.05, 1.05);
      b.gimbal.roll.rotation.z = THREE.MathUtils.clamp(this.euler.z, -0.6, 0.6);
      b.gimbal.pitch.rotation.x = THREE.MathUtils.clamp(this.euler.x, -Math.PI / 2, 0.35);
    }
    // LEDs
    const t = s.time;
    const blink = (hz: number, duty: number): number => ((t * hz) % 1 < duty ? 1 : 0);
    const breathe = 0.5 + 0.5 * Math.sin(t * 2.2);
    const status = s.soc > 0.3 ? 0x20ff40 : s.soc > 0.15 ? 0xffb000 : 0xff2010;
    for (const l of b.leds) {
      switch (l.name) {
        case 'frontLeft': case 'frontRight': l.set(0xff2a1a, s.armed ? 2.5 : 0.4); break;
        case 'rearLeft': case 'rearRight': l.set(status, s.armed ? (s.soc > 0.15 ? 0.3 + 2.7 * blink(1, 0.25) : 3 * blink(4, 0.5)) : 0.4 + 1.2 * breathe); break;
        case 'tailLeft': case 'tailRight': l.set(s.soc > 0.2 ? l.color : 0xff2010, s.armed ? (s.soc > 0.2 ? 3 : 3 * blink(3, 0.5)) : 0.3 + 1.5 * breathe); break;
        case 'fcStatus': l.set(0x2a6bff, s.armed ? 2 : 2 * blink(1, 0.5)); break;
        case 'vtxStatus': l.set(0xff2010, 1.5); break;
      }
    }
  }
}

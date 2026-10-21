import * as THREE from 'three';
import type { Airframe } from '../config';

/** Visual quadcopter (observer / chase view). Props rendered as motion-blur discs + static ghost blades. */
export class DroneModel {
  group = new THREE.Group();
  gimbal = new THREE.Group();
  private discs: THREE.Mesh[] = []; private blades: THREE.Object3D[] = [];
  constructor(private af: Airframe) { this.build(); }
  build(): void {
    const af = this.af; const g = this.group; g.clear();
    const carbon = new THREE.MeshStandardMaterial({ color: 0x1b1d20, roughness: 0.45, metalness: 0.15 });
    const shell = new THREE.MeshStandardMaterial({ color: af.id === 'mini' ? 0xb9bcc0 : 0x222428, roughness: 0.38, metalness: 0.1 });
    const metal = new THREE.MeshStandardMaterial({ color: 0x777b80, roughness: 0.3, metalness: 0.95 });
    const d = af.armD;
    const body = new THREE.Mesh(new THREE.BoxGeometry(0.075, 0.032, 0.115), shell); body.position.y = 0.0; g.add(body);
    const top = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.016, 0.09), carbon); top.position.y = 0.022; g.add(top);
    const spin = [-1, 1, -1, 1], rp = [[d, -d], [d, d], [-d, d], [-d, -d]];
    rp.forEach(([x, z], i) => {
      const L = Math.hypot(x, z); const arm = new THREE.Mesh(new THREE.BoxGeometry(L, 0.008, 0.016), carbon); arm.position.set(x / 2, 0.0, z / 2); arm.rotation.y = -Math.atan2(z, x); g.add(arm);
      const motor = new THREE.Mesh(new THREE.CylinderGeometry(0.014, 0.015, 0.022, 14), metal); motor.position.set(x, 0.012, z); g.add(motor);
      const bladeG = new THREE.Group(); bladeG.position.set(x, 0.03, z);
      const bl = new THREE.BoxGeometry(af.R * 2, 0.0012, 0.011); const b1 = new THREE.Mesh(bl, carbon); bladeG.add(b1);
      if (af.nBlades === 3) { const b2 = b1.clone(); b2.rotation.y = Math.PI / 3; const b3 = b1.clone(); b3.rotation.y = -Math.PI / 3; bladeG.add(b2, b3); }
      g.add(bladeG); this.blades.push(bladeG);
      const disc = new THREE.Mesh(new THREE.CircleGeometry(af.R, 36).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ color: 0x15171a, transparent: true, opacity: 0.22, depthWrite: false, side: THREE.DoubleSide }));
      disc.position.set(x, 0.031, z); g.add(disc); this.discs.push(disc); void spin[i];
    });
    // camera
    this.gimbal.clear();
    const ball = new THREE.Mesh(new THREE.SphereGeometry(0.02, 18, 14), carbon); const lens = new THREE.Mesh(new THREE.CylinderGeometry(0.009, 0.009, 0.01, 14).rotateX(Math.PI / 2), new THREE.MeshStandardMaterial({ color: 0x0b1020, roughness: 0.04, metalness: 0.6 }));
    lens.position.z = -0.02; this.gimbal.add(ball, lens); this.gimbal.position.set(af.camOffset[0], af.camOffset[1] + 0.005, af.camOffset[2]); g.add(this.gimbal);
    if (af.id === 'freestyle') { const battery = new THREE.Mesh(new THREE.BoxGeometry(0.036, 0.03, 0.105), new THREE.MeshStandardMaterial({ color: 0x2b3f6b, roughness: 0.6 })); battery.position.y = 0.032; g.add(battery); const cam = new THREE.Mesh(new THREE.BoxGeometry(0.03, 0.03, 0.03), carbon); cam.position.set(0, 0.012, -0.06); g.add(cam); }
    g.traverse(o => { if ((o as THREE.Mesh).isMesh) { o.castShadow = true; } });
  }
  setAirframe(af: Airframe) { this.af = af; this.discs = []; this.blades = []; this.build(); }
  update(omega: ArrayLike<number>, t: number, gimbalWorldPitchRel: number): void {
    const spin = [-1, 1, -1, 1];
    for (let i = 0; i < 4; i++) { const w = omega[i]; this.blades[i].rotation.y = ((t * w * 0.05 * spin[i]) % (Math.PI * 2)); const k = THREE.MathUtils.clamp(w / (this.af.omegaMax * 0.35), 0, 1); (this.discs[i].material as THREE.MeshBasicMaterial).opacity = 0.05 + 0.24 * k; this.blades[i].visible = k < 0.4 || true; this.blades[i].children.forEach(c => ((c as THREE.Mesh).material as THREE.Material).opacity = 1); }
    this.gimbal.rotation.x = gimbalWorldPitchRel;
  }
}

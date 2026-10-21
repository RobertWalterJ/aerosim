import * as THREE from 'three';
import type { ValleyTerrain } from '../world/ValleyTerrain';

/** Lightweight game layer: waypoint rings, a photo objective, time + eco score (bird flushes cost points). */
export class Missions {
  group = new THREE.Group();
  private rings: THREE.Mesh[] = []; idx = 0; time = 0; score = 0; photoDone = false; flushes = 0; crashes = 0; finished = false; started = false;
  private pts: [number, number, number][];
  constructor(private T: ValleyTerrain, private memorial: THREE.Vector3) {
    const wp: [number, number, number][] = [[62, -62, 38], [150, -30, 46], [118, 84, 34], [-18, 118, 30], [-120, 24, 40], [-60, -92, 26], [0, 8, 24]];
    this.pts = wp.map(([x, z, h]) => [x, T.height(x, z) + h, z]);
    const mat = new THREE.MeshBasicMaterial({ color: new THREE.Color(5.0, 2.7, 0.3), transparent: true, opacity: 0.9, depthWrite: false });
    this.pts.forEach((p, i) => { const m = new THREE.Mesh(new THREE.TorusGeometry(4.5, 0.14, 8, 40), mat.clone()); m.position.set(p[0], p[1], p[2]); m.rotation.y = Math.atan2(this.pts[(i + 1) % this.pts.length][0] - p[0], this.pts[(i + 1) % this.pts.length][2] - p[2]); this.rings.push(m); this.group.add(m); });
    this.refresh();
  }
  private refresh() { this.rings.forEach((r, i) => { r.visible = i === this.idx && !this.finished; (r.material as THREE.MeshBasicMaterial).color.set(i === this.idx ? new THREE.Color(5, 2.7, 0.3) : new THREE.Color(0.2, 0.2, 0.2)); }); }
  reset() { this.idx = 0; this.time = 0; this.score = 0; this.finished = false; this.started = false; this.photoDone = false; this.flushes = 0; this.crashes = 0; this.refresh(); }
  update(dt: number, pos: THREE.Vector3, airborne: boolean) {
    if (airborne && !this.started) this.started = true;
    if (this.started && !this.finished) this.time += dt;
    if (this.finished) return;
    const r = this.rings[this.idx]; r.rotation.z += dt * 0.6;
    if (pos.distanceTo(r.position) < 5.2) { this.score += 100; this.idx++; if (this.idx >= this.rings.length) { this.finished = true; this.score += Math.max(0, Math.round(600 - this.time * 2)); } this.refresh(); }
  }
  photo(camPos: THREE.Vector3, camFwd: THREE.Vector3): boolean {
    const to = this.memorial.clone().add(new THREE.Vector3(0, 6, 0)).sub(camPos), d = to.length();
    if (d > 25 && d < 110 && to.normalize().dot(camFwd) > Math.cos(14 * Math.PI / 180) && !this.photoDone) { this.photoDone = true; this.score += 150; return true; }
    return false;
  }
  lines(): string[] {
    const l = [this.finished ? `COURSE COMPLETE  ${this.time.toFixed(1)} s` : `RING ${this.idx + 1}/${this.rings.length}   ${this.time.toFixed(1)} s`, `SCORE ${Math.max(0, this.score - this.flushes * 50 - this.crashes * 100)}`];
    l.push(this.photoDone ? 'PHOTO: memorial captured' : 'PHOTO: frame the memorial obelisk (P)'); return l;
  }
}

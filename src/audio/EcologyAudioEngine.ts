import { mulberry32 } from '../util/noise';
import { clamp } from '../util/math';

type Species = 'chickadee' | 'robin' | 'bluejay' | 'nuthatch';
type State = 'calm' | 'alert' | 'flush' | 'silent';
interface Emitter { x: number; y: number; z: number; species: Species; state: State; next: number; silentUntil: number; treeId: number; }
interface Soarer { kind: 'crow' | 'hawk'; cx: number; cz: number; r: number; ang: number; w: number; alt: number; next: number; x: number; y: number; z: number; }
export interface FlushEvent { x: number; y: number; z: number; }

/** Reactive 3D avian ecology: canopy songbirds (calm / alert / flush FSM) + valley soarers with Doppler. */
export class EcologyAudioEngine {
  emitters: Emitter[] = []; soarers: Soarer[] = []; onFlush?: (e: FlushEvent) => void;
  private rng = mulberry32(88); private pool: PannerNode[] = []; private poolIdx = 0; private bus: GainNode; private cricket: GainNode;
  flushes = 0;
  constructor(private ctx: AudioContext, out: AudioNode, trees: { x: number; y: number; z: number; H: number; conifer: boolean }[]) {
    this.bus = ctx.createGain(); this.bus.gain.value = 0.55; this.bus.connect(out);
    for (let i = 0; i < 16; i++) { const p = ctx.createPanner(); p.panningModel = 'HRTF'; p.distanceModel = 'inverse'; p.refDistance = 5; p.rolloffFactor = 1.3; p.maxDistance = 600; p.connect(this.bus); this.pool.push(p); }
    const sp: Species[] = ['chickadee', 'robin', 'bluejay', 'nuthatch'];
    const near = trees.filter(t => Math.hypot(t.x, t.z) < 260);
    for (let i = 0; i < Math.min(60, near.length); i++) { const t = near[Math.floor(this.rng() * near.length)]; this.emitters.push({ x: t.x, y: t.y + clamp(8 + this.rng() * 10, 8, t.H * 0.85), z: t.z, species: sp[Math.floor(this.rng() * 4)], state: 'calm', next: this.rng() * 8, silentUntil: 0, treeId: i }); }
    this.soarers.push({ kind: 'crow', cx: -150, cz: -100, r: 380, ang: 0.4, w: 0.025, alt: 160, next: 6, x: 0, y: 0, z: 0 }, { kind: 'hawk', cx: -400, cz: 200, r: 520, ang: 2.0, w: -0.014, alt: 230, next: 20, x: 0, y: 0, z: 0 }, { kind: 'crow', cx: 200, cz: 300, r: 300, ang: 3.2, w: 0.03, alt: 150, next: 13, x: 0, y: 0, z: 0 });
    // cricket / insect ground bed (October: sparse)
    const o = ctx.createOscillator(); o.type = 'sine'; o.frequency.value = 4300; const am = ctx.createOscillator(); am.frequency.value = 52; const amg = ctx.createGain(); amg.gain.value = 0.5; const g = ctx.createGain(); g.gain.value = 0.5;
    am.connect(amg); amg.connect(g.gain); o.connect(g); this.cricket = ctx.createGain(); this.cricket.gain.value = 0.0045; g.connect(this.cricket); this.cricket.connect(this.bus); o.start(); am.start();
  }
  private voice(x: number, y: number, z: number, t0: number): PannerNode { const p = this.pool[this.poolIdx++ % this.pool.length]; p.positionX.value = x; p.positionY.value = y; p.positionZ.value = z; void t0; return p; }
  private note(p: AudioNode, t: number, f0: number, f1: number, dur: number, vol: number, type: OscillatorType = 'sine', vib = 0) {
    const c = this.ctx, o = c.createOscillator(), g = c.createGain(); o.type = type; o.frequency.setValueAtTime(f0, t); o.frequency.exponentialRampToValueAtTime(Math.max(50, f1), t + dur);
    g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + Math.min(0.012, dur * 0.3)); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    if (vib) { const l = c.createOscillator(), lg = c.createGain(); l.frequency.value = 38; lg.gain.value = f0 * vib; l.connect(lg); lg.connect(o.frequency); l.start(t); l.stop(t + dur); }
    o.connect(g); g.connect(p); o.start(t); o.stop(t + dur + 0.02);
  }
  private phrase(e: Emitter, t: number) {
    const p = this.voice(e.x, e.y, e.z, t), j = 1 + (this.rng() - 0.5) * 0.16, r = this.rng;
    switch (e.species) {
      case 'chickadee': // "fee-bee"
        this.note(p, t, 3900 * j, 3850 * j, 0.32, 0.18); this.note(p, t + 0.42, 3300 * j, 3250 * j, 0.42, 0.18); if (r() < 0.5) { for (let i = 0; i < 4; i++) this.note(p, t + 1.1 + i * 0.09, 3100 * j, 2700 * j, 0.06, 0.12, 'square'); } break;
      case 'robin': // cheerful warble
        for (let i = 0; i < 7; i++) { const f = (2200 + r() * 1400) * j; this.note(p, t + i * 0.19, f, f * (0.8 + r() * 0.5), 0.15, 0.16, 'sine', 0.01); } break;
      case 'bluejay': // harsh "jay"
        for (let i = 0; i < 3; i++) this.note(p, t + i * 0.28, 2300 * j, 1500 * j, 0.2, 0.1, 'sawtooth'); break;
      case 'nuthatch': // nasal "yank yank"
        for (let i = 0; i < 4; i++) this.note(p, t + i * 0.2, 1350 * j, 1250 * j, 0.14, 0.12, 'square'); break;
    }
  }
  private alarm(e: Emitter, t: number) { const p = this.voice(e.x, e.y, e.z, t); for (let i = 0; i < 2; i++) this.note(p, t + i * 0.07, 5200 + this.rng() * 500, 4300, 0.04, 0.2, 'square'); }
  private flutter(e: Emitter, t: number) {
    const c = this.ctx, p = this.voice(e.x, e.y, e.z, t);
    const nb = c.createBuffer(1, c.sampleRate * 0.8, c.sampleRate), d = nb.getChannelData(0); for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * (0.5 + 0.5 * Math.sin(i / c.sampleRate * 2 * Math.PI * 22)) * Math.exp(-i / c.sampleRate * 1.8);
    const s = c.createBufferSource(); s.buffer = nb; const f = c.createBiquadFilter(); f.type = 'bandpass'; f.frequency.value = 1800; f.Q.value = 0.6; const g = c.createGain(); g.gain.value = 0.55; s.connect(f); f.connect(g); g.connect(p); s.start(t);
  }
  private call(s: Soarer, t: number, dopp: number, dist: number) {
    const p = this.voice(s.x, s.y, s.z, t); const air = this.ctx.createBiquadFilter(); air.type = 'lowpass'; air.frequency.value = clamp(7000 / (1 + dist / 220), 700, 7000); air.connect(p);
    if (s.kind === 'crow') for (let i = 0; i < 3; i++) this.note(air, t + i * 0.42, 520 * dopp, 380 * dopp, 0.3, 0.55, 'sawtooth'); else this.note(air, t, 3600 * dopp, 1900 * dopp, 1.6, 0.35, 'sawtooth', 0.01);
  }
  update(now: number, dronePos: [number, number, number], dt: number, droneVel: [number, number, number]) {
    if (this.ctx.state !== 'running') return; const t = this.ctx.currentTime;
    for (const e of this.emitters) {
      const d = Math.hypot(e.x - dronePos[0], e.y - dronePos[1], e.z - dronePos[2]);
      if (e.state === 'silent') { if (now > e.silentUntil) { e.state = 'calm'; e.next = now + 4; } continue; }
      if (d > 140) continue;
      if (d <= 15) { e.state = 'flush'; this.flutter(e, t); this.flushes++; this.onFlush?.({ x: e.x, y: e.y, z: e.z }); e.state = 'silent'; e.silentUntil = now + 60; continue; }
      if (d <= 35) { if (e.state !== 'alert') { e.state = 'alert'; e.next = now; } if (now >= e.next) { this.alarm(e, t); e.next = now + 0.5 + this.rng() * 0.7; } }
      else { e.state = 'calm'; if (now >= e.next) { this.phrase(e, t); e.next = now + 3 + this.rng() * 9; } }
    }
    for (const s of this.soarers) {
      s.ang += s.w * dt; const px = s.x, py = s.y, pz = s.z; s.x = s.cx + Math.cos(s.ang) * s.r; s.z = s.cz + Math.sin(s.ang) * s.r; s.y = s.alt + Math.sin(s.ang * 3) * 14;
      if (now >= s.next) { const d = Math.hypot(s.x - dronePos[0], s.y - dronePos[1], s.z - dronePos[2]); const v = dt > 0 ? [(s.x - px) / dt, (s.y - py) / dt, (s.z - pz) / dt] : [0, 0, 0]; const rad = ((v[0] - droneVel[0]) * (dronePos[0] - s.x) + (v[2] - droneVel[2]) * (dronePos[2] - s.z)) / (d || 1); const dop = 343 / (343 - clamp(-rad, -40, 40)); this.call(s, t, dop, d); s.next = now + (s.kind === 'hawk' ? 25 : 10) + this.rng() * 14; }
    }
  }
  setListener(): void { /* listener shared with DroneSynth (ground perspective). */ }
}

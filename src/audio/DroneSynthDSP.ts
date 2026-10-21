import { clamp } from '../util/math';

export type AudioPerspective = 'Ground Binaural' | 'Onboard Mic' | 'Cinematic Hybrid';
export interface AudioInputs {
  motorRpm: ArrayLike<number>; nBlades: number; throttle: number;
  vz: number; angJerk: number; vrs: number;
  airSpeed: number;                      // |v_air| (m/s) over the mic
  dronePos: [number, number, number]; homePos: [number, number, number]; droneVel: [number, number, number];
  reflectorDist: number; camForward: [number, number, number]; aglM: number; grassWash: number; windCanopy: number; coniferFrac: number; gust: number;
}

/** Procedural propulsion synth: 4 harmonic voices (phase beating), blade-vortex slap, mic wind buffet, slapback comb, rotor-wash noise. */
export class DroneSynthDSP {
  ctx: AudioContext; master: GainNode; perspective: AudioPerspective = 'Cinematic Hybrid';
  private osc: OscillatorNode[][] = []; private og: GainNode[][] = [];
  private motorBus: GainNode; private gGround: GainNode; private gOnboard: GainNode;
  private panner: PannerNode; private groundLP: BiquadFilterNode; private onboardLP: BiquadFilterNode;
  private noiseSrc: AudioBufferSourceNode; private buffetG: GainNode; private slapG: GainNode; private slapLfo: OscillatorNode; private washG: GainNode;
  private delay: DelayNode; private delayG: GainNode; private fbG: GainNode;
  private ambBus: GainNode; foliageSpruce: GainNode; foliageLeaf: GainNode; private leafAM: GainNode; envBus: GainNode;
  private lastDist = 1;
  started = false;
  constructor() {
    const AC = (window as any).AudioContext || (window as any).webkitAudioContext;
    this.ctx = new AC({ latencyHint: 'interactive', sampleRate: 48000 });
    const c = this.ctx;
    this.master = c.createGain(); this.master.gain.value = 0.6; this.master.connect(c.destination);
    this.motorBus = c.createGain(); this.gGround = c.createGain(); this.gOnboard = c.createGain();
    this.panner = c.createPanner(); this.panner.panningModel = 'HRTF'; this.panner.distanceModel = 'inverse'; this.panner.refDistance = 4; this.panner.rolloffFactor = 1.1; this.panner.maxDistance = 4000;
    this.groundLP = c.createBiquadFilter(); this.groundLP.type = 'lowpass'; this.groundLP.frequency.value = 8000;
    this.onboardLP = c.createBiquadFilter(); this.onboardLP.type = 'lowpass'; this.onboardLP.frequency.value = 5200;
    this.motorBus.connect(this.panner); this.panner.connect(this.groundLP); this.groundLP.connect(this.gGround); this.gGround.connect(this.master);
    this.motorBus.connect(this.onboardLP); this.onboardLP.connect(this.gOnboard); this.gOnboard.connect(this.master);
    // noise
    const nb = c.createBuffer(1, c.sampleRate * 3, c.sampleRate), d = nb.getChannelData(0); let b0 = 0, b1 = 0, b2 = 0;
    for (let i = 0; i < d.length; i++) { const w = Math.random() * 2 - 1; b0 = 0.99765 * b0 + w * 0.099046; b1 = 0.963 * b1 + w * 0.2965164; b2 = 0.57 * b2 + w * 1.0526913; d[i] = (b0 + b1 + b2 + w * 0.1848) * 0.18; }
    this.noiseSrc = c.createBufferSource(); this.noiseSrc.buffer = nb; this.noiseSrc.loop = true; this.noiseSrc.start();
    // mic wind buffet: 40-250 Hz rumble through soft clipper
    const bufLP = c.createBiquadFilter(); bufLP.type = 'bandpass'; bufLP.frequency.value = 110; bufLP.Q.value = 0.5;
    const shaper = c.createWaveShaper(); const curve = new Float32Array(1024); for (let i = 0; i < 1024; i++) { const x = i / 512 - 1; curve[i] = Math.tanh(x * 2.2); } shaper.curve = curve;
    this.buffetG = c.createGain(); this.buffetG.gain.value = 0; this.noiseSrc.connect(bufLP); bufLP.connect(shaper); shaper.connect(this.buffetG); this.buffetG.connect(this.gOnboard);
    // blade-vortex slap
    const slapBP = c.createBiquadFilter(); slapBP.type = 'bandpass'; slapBP.frequency.value = 210; slapBP.Q.value = 1.4; this.slapG = c.createGain(); this.slapG.gain.value = 0;
    const slapMod = c.createGain(); slapMod.gain.value = 0; this.slapLfo = c.createOscillator(); this.slapLfo.type = 'sawtooth'; this.slapLfo.frequency.value = 17; const lfoDepth = c.createGain(); lfoDepth.gain.value = 0.5;
    this.slapLfo.connect(lfoDepth); lfoDepth.connect(this.slapG.gain); this.slapLfo.start(); this.noiseSrc.connect(slapBP); slapBP.connect(this.slapG); this.slapG.connect(this.motorBus);
    // rotor wash on grass / leaves
    const washHP = c.createBiquadFilter(); washHP.type = 'bandpass'; washHP.frequency.value = 3200; washHP.Q.value = 0.7; this.washG = c.createGain(); this.washG.gain.value = 0;
    this.noiseSrc.connect(washHP); washHP.connect(this.washG); this.washG.connect(this.gOnboard); const wsp = c.createGain(); wsp.gain.value = 0.7; this.washG.connect(wsp); wsp.connect(this.panner);
    // slapback early reflections (15-35 ms comb)
    this.delay = c.createDelay(0.1); this.delay.delayTime.value = 0.025; this.delayG = c.createGain(); this.delayG.gain.value = 0; this.fbG = c.createGain(); this.fbG.gain.value = 0.35;
    this.motorBus.connect(this.delay); this.delay.connect(this.delayG); this.delayG.connect(this.master); this.delay.connect(this.fbG); this.fbG.connect(this.delay);
    // 4 motors x 5 harmonics
    for (let m = 0; m < 4; m++) {
      this.osc.push([]); this.og.push([]);
      for (let h = 1; h <= 5; h++) {
        const o = c.createOscillator(); o.type = h === 1 ? 'sawtooth' : 'triangle'; o.frequency.value = 200 * h * (1 + m * 0.0013); const g = c.createGain(); g.gain.value = 0;
        o.connect(g); g.connect(this.motorBus); o.start(); this.osc[m].push(o); this.og[m].push(g);
      }
    }
    // ambience beds (shared with ecology engine)
    this.envBus = c.createGain(); this.envBus.gain.value = 1; this.envBus.connect(this.master);
    this.ambBus = c.createGain(); this.ambBus.connect(this.envBus);
    const spBP = c.createBiquadFilter(); spBP.type = 'bandpass'; spBP.frequency.value = 4200; spBP.Q.value = 0.8; this.foliageSpruce = c.createGain(); this.foliageSpruce.gain.value = 0; this.noiseSrc.connect(spBP); spBP.connect(this.foliageSpruce); this.foliageSpruce.connect(this.ambBus);
    const lfBP = c.createBiquadFilter(); lfBP.type = 'bandpass'; lfBP.frequency.value = 1500; lfBP.Q.value = 0.6; this.leafAM = c.createGain(); this.leafAM.gain.value = 0; this.foliageLeaf = c.createGain(); this.foliageLeaf.gain.value = 0;
    this.noiseSrc.connect(lfBP); lfBP.connect(this.leafAM); this.leafAM.connect(this.foliageLeaf); this.foliageLeaf.connect(this.ambBus);
    const amLfo = c.createOscillator(); amLfo.frequency.value = 7; const amD = c.createGain(); amD.gain.value = 0.35; amLfo.connect(amD); amD.connect(this.leafAM.gain); this.leafAM.gain.value = 0.65; amLfo.start();
    this.setPerspective(this.perspective);
  }
  async start() { if (this.ctx.state !== 'running') await this.ctx.resume(); this.started = true; }
  setPerspective(p: AudioPerspective) {
    this.perspective = p; const t = this.ctx.currentTime;
    const [g, o] = p === 'Ground Binaural' ? [1, 0] : p === 'Onboard Mic' ? [0, 1] : [0.7, 0.65];
    this.gGround.gain.setTargetAtTime(g, t, 0.06); this.gOnboard.gain.setTargetAtTime(o, t, 0.06);
  }
  cyclePerspective(): AudioPerspective { const l: AudioPerspective[] = ['Ground Binaural', 'Onboard Mic', 'Cinematic Hybrid']; this.setPerspective(l[(l.indexOf(this.perspective) + 1) % 3]); return this.perspective; }

  update(a: AudioInputs, dt: number) {
    if (!this.started) return; const c = this.ctx, t = c.currentTime, T = 0.03;
    // listener at home point (ground perspective)
    const L = c.listener; const dx = a.dronePos[0] - a.homePos[0], dy = a.dronePos[1] - a.homePos[1], dz = a.dronePos[2] - a.homePos[2];
    const dist = Math.hypot(dx, dy, dz);
    if (L.positionX) {
      if (this.perspective === 'Onboard Mic') { L.positionX.value = a.dronePos[0]; L.positionY.value = a.dronePos[1]; L.positionZ.value = a.dronePos[2]; L.forwardX.value = a.camForward[0]; L.forwardY.value = a.camForward[1]; L.forwardZ.value = a.camForward[2]; }
      else { L.positionX.value = a.homePos[0]; L.positionY.value = a.homePos[1]; L.positionZ.value = a.homePos[2]; const fx = dx / (dist || 1), fz = dz / (dist || 1); L.forwardX.value = fx; L.forwardY.value = 0; L.forwardZ.value = fz; }
      L.upX.value = 0; L.upY.value = 1; L.upZ.value = 0;
    }
    this.panner.positionX.value = a.dronePos[0]; this.panner.positionY.value = a.dronePos[1]; this.panner.positionZ.value = a.dronePos[2];
    // Doppler from radial velocity toward home
    const vr = ((a.droneVel[0] * -dx) + (a.droneVel[1] * -dy) + (a.droneVel[2] * -dz)) / (dist || 1);
    const dop = 343 / (343 - clamp(vr, -60, 60));
    const air = 1 / (1 + dist / 120); this.groundLP.frequency.setTargetAtTime(clamp(9000 * air + 900, 900, 9000), t, 0.1);
    const amp = 0.05 + 0.55 * a.throttle * a.throttle;
    for (let m = 0; m < 4; m++) {
      const f0 = (a.motorRpm[m] * a.nBlades) / 60;
      for (let h = 0; h < 5; h++) {
        this.osc[m][h].frequency.setTargetAtTime(Math.max(20, f0 * (h + 1) * dop * (this.perspective === 'Onboard Mic' ? 1 : 1)), t, T);
        this.og[m][h].gain.setTargetAtTime((amp * 0.065) / Math.pow(h + 1, 1.15) * (h === 0 ? 1.3 : 1), t, T);
      }
    }
    // vortex slap
    const slap = clamp(Math.max(0, -a.vz - 1.5) * 0.12 + a.vrs * 0.8 + a.angJerk * 0.0004, 0, 1);
    this.slapG.gain.setTargetAtTime(slap * 0.6, t, 0.04); this.slapLfo.frequency.setTargetAtTime(14 + 40 * slap, t, 0.1);
    // wind buffet on the capsule
    const buf = clamp((a.airSpeed * a.airSpeed - 25) / 400, 0, 1); this.buffetG.gain.setTargetAtTime(buf * 1.1, t, 0.06);
    // reflections
    const rd = a.reflectorDist; if (isFinite(rd)) { this.delay.delayTime.setTargetAtTime(clamp((2 * rd) / 343, 0.015, 0.035), t, 0.05); this.delayG.gain.setTargetAtTime(clamp(0.28 * (1 - rd / 12), 0, 0.3), t, 0.08); } else this.delayG.gain.setTargetAtTime(0, t, 0.1);
    // rotor wash over grass
    this.washG.gain.setTargetAtTime(a.grassWash * 0.5, t, 0.08);
    // foliage beds: spruce hiss (2.5-6 kHz) and deciduous rustle (0.8-2.5 kHz) follow the local gust vector
    const w = clamp(a.windCanopy / 9, 0, 1);
    this.foliageSpruce.gain.setTargetAtTime(0.1 * w * (0.4 + a.coniferFrac) * (0.6 + 0.4 * a.gust), t, 0.3);
    this.foliageLeaf.gain.setTargetAtTime(0.12 * w * (1.2 - a.coniferFrac) * (0.5 + a.gust), t, 0.3);
    this.lastDist = dist; void dt;
  }
}

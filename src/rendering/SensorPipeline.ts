import * as THREE from 'three';
import * as S from './SensorPipeline.glsl';
import { DEG, clamp } from '../util/math';

export type Lens = 'standard' | 'wide';
export interface SensorInput {
  dt: number; time: number;
  camera: THREE.PerspectiveCamera;            // render camera (overscan FOV set by the pipeline)
  sunDir: THREE.Vector3;
  angVelCam: THREE.Vector3;                   // rad/s in camera frame (x pitch up, y yaw left, z roll)
  vibration: number;                          // 0..1 motor/jello energy
  motorHz: number;                            // blade-pass frequency
  rfBad: number;                              // 0..1 codec degradation
}

class Pass {
  mesh: THREE.Mesh;
  constructor(frag: string, uniforms: Record<string, THREE.IUniform>) {
    const m = new THREE.ShaderMaterial({ vertexShader: S.VERT, fragmentShader: frag, uniforms, depthTest: false, depthWrite: false });
    this.mesh = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), m); this.mesh.frustumCulled = false;
  }
  get u() { return (this.mesh.material as THREE.ShaderMaterial).uniforms; }
}

/**
 * Seven-stage small-sensor camera model.
 *  1 rolling shutter + jello | 2 centre-weighted AE w/ lag | 3 sun streak + cyan ghost + veiling glare
 *  4 Brown-Conrady + lateral CA | 5 10-stop S-curve | 6 ISP unsharp + ISO noise | 7 RF-link H.264 macroblocking
 * (Flares are evaluated in the rectilinear lens plane and then distorted with the image, matching optics.)
 */
export class SensorPipeline {
  lens: Lens = 'standard';
  fps = 60; evComp = 0;
  readonly lenses = {
    standard: { diagDeg: 84, k1: 0.035, k2: 0.0, name: '84° Standard (24 mm)', ca: 0.0018 },
    wide: { diagDeg: 150, k1: 0.30, k2: 0.16, name: '150° Wide (SuperView)', ca: 0.004 },
  };
  outW = 1280; outH = 720; S_ = 1.15;
  private rtScene!: THREE.WebGLRenderTarget; private rtA!: THREE.WebGLRenderTarget; private rtB!: THREE.WebGLRenderTarget;
  private rtOut: THREE.WebGLRenderTarget[] = []; private outIdx = 0;
  private rtMeter!: THREE.WebGLRenderTarget; private rtMeter1!: THREE.WebGLRenderTarget; private rtExp: THREE.WebGLRenderTarget[] = []; private expIdx = 0;
  private bloomDown: THREE.WebGLRenderTarget[] = []; private bloomUp: THREE.WebGLRenderTarget[] = [];
  private rtHist!: THREE.WebGLRenderTarget;
  private cam = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
  private pMeter!: Pass; private pReduce!: Pass; private pAdapt!: Pass; private pPre!: Pass; private pDown!: Pass; private pUp!: Pass; private pSensor!: Pass; private pIsp!: Pass; private pCodec!: Pass; private pBlit!: Pass; private pHist!: Pass; private pSun!: Pass; private rtSun: THREE.WebGLRenderTarget[] = []; private sunIdx = 0;
  private frame = 0; private msaa: number;
  exposureEV = 0; histogram = new Float32Array(64); private readbackTick = 0; private expBuf = new Float32Array(4); private histBuf = new Uint8Array(64 * 36 * 4);
  sunVisibility = 0; exposure = 1; isoShown = 100; shutterShown = 1 / 200;
  bloomOn = true; private sceneBg = new THREE.Color(0, 0, 0);

  constructor(private renderer: THREE.WebGLRenderer, msaa: number) {
    this.msaa = msaa;
    const tex = (v?: THREE.Texture | null): THREE.IUniform => ({ value: v ?? null });
    this.pMeter = new Pass(S.METER, { uScene: tex(), uS: { value: 1.15 }, uTexel: { value: new THREE.Vector2() } });
    this.pReduce = new Pass(S.REDUCE, { uSrc: tex() });
    this.pAdapt = new Pass(S.ADAPT, { uMeter: tex(), uPrev: tex(), uDt: { value: 0.016 }, uTau: { value: 0.35 }, uEvComp: { value: 0 }, uMinE: { value: 0.03 }, uMaxE: { value: 40 } });
    this.pPre = new Pass(S.BLOOM_PRE, { uScene: tex(), uExp: tex(), uTexel: { value: new THREE.Vector2() }, uKnee: { value: 1.0 } });
    this.pDown = new Pass(S.BLOOM_DOWN, { uSrc: tex(), uTexel: { value: new THREE.Vector2() } });
    this.pUp = new Pass(S.BLOOM_UP, { uLow: tex(), uHigh: tex(), uTexel: { value: new THREE.Vector2() }, uWeight: { value: 1 } });
    this.pSensor = new Pass(S.SENSOR, {
      uScene: tex(), uDepth: tex(), uBloom: tex(), uExp: tex(), uSunTex: tex(), uInView: { value: 0 }, uS: { value: 1.15 }, uAspect: { value: 16 / 9 }, uTime: { value: 0 }, uReadout: { value: 0.012 }, uVibAmp: { value: 0 }, uVibFreq: { value: 60 }, uBloomK: { value: 0.08 },
      uTan: { value: new THREE.Vector2(1, 0.5) }, uK: { value: new THREE.Vector2() }, uSunS: { value: new THREE.Vector2(2, 2) }, uWRS: { value: new THREE.Vector2() }, uWRoll: { value: 0 }, uSunVis: { value: 0 }, uGlare: { value: 0 },
      uIso: { value: 1 }, uCA: { value: 0.004 }, uGhostK: { value: 0.55 }, uFrame: { value: 0 }, uFlareI: { value: 1 }, uVig: { value: 0.28 },
    });
    this.pIsp = new Pass(S.ISP, { uSrc: tex(), uTexel: { value: new THREE.Vector2() }, uGlare: { value: 0 }, uSharp: { value: 1.4 }, uRadius: { value: 1.2 }, uSat: { value: 1.1 }, uFrame: { value: 0 } });
    this.pCodec = new Pass(S.CODEC, { uSrc: tex(), uPrev: tex(), uRes: { value: new THREE.Vector2() }, uBad: { value: 0 }, uFrame: { value: 0 }, uTime: { value: 0 } });
    this.pBlit = new Pass(S.BLIT, { uSrc: tex(), uAspectScreen: { value: 1 }, uAspectSrc: { value: 1 } });
    this.pSun = new Pass(S.SUNVIS, { uDepth: tex(), uPrev: tex(), uSunS: { value: new THREE.Vector2() } });
    this.pHist = new Pass(S.HIST, { uSrc: tex(), uTexel: { value: new THREE.Vector2() } });
  }

  private rt(w: number, h: number, type: THREE.TextureDataType = THREE.HalfFloatType, filter: THREE.MinificationTextureFilter | THREE.MagnificationTextureFilter = THREE.LinearFilter, extra: any = {}): THREE.WebGLRenderTarget {
    const t = new THREE.WebGLRenderTarget(Math.max(1, w | 0), Math.max(1, h | 0), { type, format: THREE.RGBAFormat, minFilter: filter as THREE.MinificationTextureFilter, magFilter: filter as THREE.MagnificationTextureFilter, depthBuffer: false, generateMipmaps: false, ...extra });
    t.texture.colorSpace = THREE.NoColorSpace; return t;
  }

  /** (Re)allocate for output resolution. Overscan scale also covers distortion + rolling-shutter margins. */
  resize(outW: number, outH: number): void {
    this.outW = Math.max(16, outW | 0); this.outH = Math.max(16, outH | 0);
    this.dispose();
    const l = this.lenses[this.lens]; this.S_ = Math.max(1.2, (1 + l.k1 + l.k2) * 1.06);
    const sw = Math.round(this.outW * Math.min(this.S_, 1.45)), sh = Math.round(this.outH * Math.min(this.S_, 1.45));
    const depth = new THREE.DepthTexture(sw, sh); depth.type = THREE.UnsignedIntType;
    this.rtScene = this.rt(sw, sh, THREE.HalfFloatType, THREE.LinearFilter, { depthBuffer: true, depthTexture: depth, samples: this.msaa });
    this.rtA = this.rt(this.outW, this.outH); this.rtB = this.rt(this.outW, this.outH, THREE.HalfFloatType);
    this.rtOut = [this.rt(this.outW, this.outH, THREE.UnsignedByteType), this.rt(this.outW, this.outH, THREE.UnsignedByteType)];
    this.rtMeter = this.rt(32, 32, THREE.FloatType, THREE.NearestFilter); this.rtMeter1 = this.rt(1, 1, THREE.FloatType, THREE.NearestFilter);
    this.rtExp = [this.rt(1, 1, THREE.FloatType, THREE.NearestFilter), this.rt(1, 1, THREE.FloatType, THREE.NearestFilter)];
    this.rtHist = this.rt(64, 36, THREE.UnsignedByteType, THREE.NearestFilter);
    this.rtSun = [this.rt(1, 1, THREE.FloatType, THREE.NearestFilter), this.rt(1, 1, THREE.FloatType, THREE.NearestFilter)];
    let w = Math.round(this.outW / 2), h = Math.round(this.outH / 2);
    for (let i = 0; i < 5; i++) { this.bloomDown.push(this.rt(w, h)); this.bloomUp.push(this.rt(w, h)); w = Math.max(2, w >> 1); h = Math.max(2, h >> 1); }
    // seed exposure
    this.renderer.setRenderTarget(this.rtExp[0]); this.renderer.setClearColor(0x000000, 1); this.renderer.clear(); this.renderer.setRenderTarget(null);
    this.pAdapt.u.uPrev.value = this.rtExp[0].texture;
  }
  dispose(): void {
    for (const t of [this.rtScene, this.rtA, this.rtB, this.rtMeter, this.rtMeter1, this.rtHist, ...this.rtOut, ...this.rtExp, ...this.rtSun, ...this.bloomDown, ...this.bloomUp]) t?.dispose();
    this.bloomDown = []; this.bloomUp = [];
  }

  setLens(l: Lens, aspect: number): void { this.lens = l; this.resize(this.outW, this.outH); void aspect; }

  /** configure the render camera so the sensor frame's rectilinear footprint (before distortion) is oversized by S */
  configureCamera(cam: THREE.PerspectiveCamera): void {
    const L = this.lenses[this.lens]; const aspect = this.outW / this.outH;
    const halfDiag = Math.tan(L.diagDeg * DEG / 2); const ty = halfDiag / Math.sqrt(1 + aspect * aspect), tx = ty * aspect;
    const f = 1 + L.k1 + L.k2;      // corner of the distorted frame samples the rectilinear plane at r_u = f * r
    const S = this.S_;
    const tyS = ty * S * 1.0; const needed = tyS;
    cam.fov = 2 * Math.atan(needed) / DEG; cam.aspect = aspect * 1.0; cam.updateProjectionMatrix();
    void f; void tx;
  }
  get tanHalf(): THREE.Vector2 {
    const L = this.lenses[this.lens]; const aspect = this.outW / this.outH; const halfDiag = Math.tan(L.diagDeg * DEG / 2);
    const ty = halfDiag / Math.sqrt(1 + aspect * aspect); return new THREE.Vector2(ty * aspect, ty);
  }
  get hfovDeg(): number { const t = this.tanHalf; return 2 * Math.atan(t.x) / DEG; }

  private run(p: Pass, target: THREE.WebGLRenderTarget | null): void {
    const r = this.renderer; r.setRenderTarget(target); r.render(p.mesh, this.cam);
  }

  /** Renders the 3D scene into the HDR target (call at sensor cadence). */
  renderScene(scene: THREE.Scene, camera: THREE.PerspectiveCamera): void {
    const r = this.renderer; r.setRenderTarget(this.rtScene); r.setClearColor(this.sceneBg, 1); r.clear(); r.render(scene, camera);
  }

  /** Runs stages 1-7 and returns the output texture. */
  process(inp: SensorInput): THREE.Texture {
    const r = this.renderer, L = this.lenses[this.lens]; this.frame++;
    const aspect = this.outW / this.outH, tan = this.tanHalf;
    // --- Stage 2: metering + adaptation
    this.pMeter.u.uScene.value = this.rtScene.texture; this.pMeter.u.uS.value = this.S_; this.run(this.pMeter, this.rtMeter);
    this.pReduce.u.uSrc.value = this.rtMeter.texture; this.run(this.pReduce, this.rtMeter1);
    const prev = this.rtExp[this.expIdx], next = this.rtExp[1 - this.expIdx];
    this.pAdapt.u.uMeter.value = this.rtMeter1.texture; this.pAdapt.u.uPrev.value = prev.texture; this.pAdapt.u.uDt.value = Math.min(inp.dt, 0.1); this.pAdapt.u.uEvComp.value = this.evComp;
    this.run(this.pAdapt, next); this.expIdx = 1 - this.expIdx;
    const expTex = next.texture;
    // --- bloom chain
    if (this.bloomOn) {
      this.pPre.u.uScene.value = this.rtScene.texture; this.pPre.u.uExp.value = expTex; this.pPre.u.uTexel.value.set(1 / this.rtScene.width, 1 / this.rtScene.height); this.run(this.pPre, this.bloomDown[0]);
      for (let i = 1; i < 5; i++) { this.pDown.u.uSrc.value = this.bloomDown[i - 1].texture; this.pDown.u.uTexel.value.set(1 / this.bloomDown[i - 1].width, 1 / this.bloomDown[i - 1].height); this.run(this.pDown, this.bloomDown[i]); }
      // up chain: up[4] = down[4]
      this.pUp.u.uLow.value = this.bloomDown[4].texture; this.pUp.u.uHigh.value = this.bloomDown[4].texture; this.pUp.u.uWeight.value = 0; this.pUp.u.uTexel.value.set(1 / this.bloomDown[4].width, 1 / this.bloomDown[4].height); this.run(this.pUp, this.bloomUp[4]);
      for (let i = 3; i >= 0; i--) { this.pUp.u.uLow.value = this.bloomUp[i + 1].texture; this.pUp.u.uHigh.value = this.bloomDown[i].texture; this.pUp.u.uWeight.value = 1; this.pUp.u.uTexel.value.set(1 / this.bloomUp[i + 1].width, 1 / this.bloomUp[i + 1].height); this.run(this.pUp, this.bloomUp[i]); }
    } else { r.setRenderTarget(this.bloomUp[0]); r.setClearColor(0, 1); r.clear(); }
    // --- sun in scene-uv + visibility (depth-tested against sky)
    const cam = inp.camera; const sunW = cam.position.clone().addScaledVector(inp.sunDir, 4000);
    const ndc = sunW.clone().project(cam); const behind = sunW.clone().sub(cam.position).dot(cam.getWorldDirection(new THREE.Vector3())) <= 0;
    const sunUv = new THREE.Vector2(ndc.x * 0.5 + 0.5, ndc.y * 0.5 + 0.5);
    const fwdDot = cam.getWorldDirection(new THREE.Vector3()).dot(inp.sunDir);
    const inView = !behind && sunUv.x > -0.3 && sunUv.x < 1.3 && sunUv.y > -0.3 && sunUv.y < 1.3;
    this.pSun.u.uDepth.value = this.rtScene.depthTexture; this.pSun.u.uSunS.value.copy(sunUv); this.pSun.u.uPrev.value = this.rtSun[this.sunIdx].texture;
    this.run(this.pSun, this.rtSun[1 - this.sunIdx]); this.sunIdx = 1 - this.sunIdx;
    // --- Stages 1,3,4: sensor/lens compose
    const u = this.pSensor.u;
    u.uScene.value = this.rtScene.texture; u.uDepth.value = this.rtScene.depthTexture; u.uBloom.value = this.bloomUp[0].texture; u.uExp.value = expTex;
    u.uS.value = this.S_; u.uAspect.value = aspect; u.uTime.value = inp.time; u.uTan.value.copy(tan); u.uK.value.set(L.k1, L.k2); u.uCA.value = L.ca;
    u.uSunS.value.copy(sunUv); u.uWRS.value.set(inp.angVelCam.y, inp.angVelCam.x); u.uWRoll.value = inp.angVelCam.z; u.uReadout.value = 0.012;
    u.uVibAmp.value = 0.00035 + 0.0016 * inp.vibration; u.uVibFreq.value = 2 * Math.PI * (inp.motorHz * 0.071 + 17); u.uFrame.value = this.frame;
    u.uGlare.value = THREE.MathUtils.smoothstep(fwdDot, 0.8, 0.98) * (inView ? 1 : 0.5);
    u.uIso.value = this.noiseGain(); u.uBloomK.value = this.bloomOn ? 0.1 : 0;
    // sun visibility: filled by CPU estimator (sampled depth); default optimistic until first readback
    u.uSunTex.value = this.rtSun[this.sunIdx].texture; u.uInView.value = inView ? 1 : 0;
    this.run(this.pSensor, this.rtA);
    // --- Stages 5+6: tone curve & ISP sharpening
    const ip = this.pIsp.u; ip.uSrc.value = this.rtA.texture; ip.uTexel.value.set(1 / this.outW, 1 / this.outH); ip.uGlare.value = u.uGlare.value; ip.uFrame.value = this.frame;
    this.run(this.pIsp, this.rtB);
    // --- Stage 7: codec
    const cp = this.pCodec.u; const out = this.rtOut[this.outIdx], prevOut = this.rtOut[1 - this.outIdx];
    cp.uSrc.value = this.rtB.texture; cp.uPrev.value = prevOut.texture; cp.uRes.value.set(this.outW, this.outH); cp.uBad.value = inp.rfBad; cp.uFrame.value = this.frame; cp.uTime.value = inp.time;
    this.run(this.pCodec, out); this.outIdx = 1 - this.outIdx;
    // --- periodic CPU readback for OSD (exposure, histogram, sun visibility)
    if ((++this.readbackTick % 6) === 0) this.readback(out);
    return out.texture;
  }

  private noiseGain(): number { return clamp(this.exposure / 3.5, 1, 16) ** 0.8; }

  private readback(out: THREE.WebGLRenderTarget): void {
    const r = this.renderer;
    const exp = this.rtExp[this.expIdx];
    try {
      r.readRenderTargetPixels(exp, 0, 0, 1, 1, this.expBuf);
      const log2e = this.expBuf[0]; this.exposure = Math.pow(2, log2e);
      // map exposure -> shutter/ISO: E=1 ~ 1/200 s @ ISO100; shutter limited to [1/4000, 1/50]
      const E = this.exposure; let shutter = E / 200, iso = 100;
      if (shutter > 1 / 50) { iso = clamp(100 * shutter * 50, 100, 1600); shutter = 1 / 50; }
      if (shutter < 1 / 4000) shutter = 1 / 4000;
      this.shutterShown = shutter; this.isoShown = Math.round(iso / 50) * 50; this.exposureEV = this.evComp;
      this.pHist.u.uSrc.value = out.texture; this.pHist.u.uTexel.value.set(1 / this.outW, 1 / this.outH); this.run(this.pHist, this.rtHist);
      r.readRenderTargetPixels(this.rtHist, 0, 0, 64, 36, this.histBuf);
      this.histogram.fill(0);
      for (let i = 0; i < 64 * 36; i++) { const l = (0.2126 * this.histBuf[i * 4] + 0.7152 * this.histBuf[i * 4 + 1] + 0.0722 * this.histBuf[i * 4 + 2]) / 255; this.histogram[Math.min(63, Math.floor(l * 64))]++; }
      for (let i = 0; i < 64; i++) this.histogram[i] /= 64 * 36;
    } catch { /* readback unsupported: OSD keeps last values */ }
    r.setRenderTarget(null);
  }

  /** Sun visibility is estimated analytically from the scene's depth probe (set by caller using raycasts). */
  setSunVisibility(v: number): void { this.sunVisibility += (v - this.sunVisibility) * 0.35; }

  blit(tex: THREE.Texture, screenW: number, screenH: number): void {
    this.pBlit.u.uSrc.value = tex; this.pBlit.u.uAspectScreen.value = screenW / screenH; this.pBlit.u.uAspectSrc.value = this.outW / this.outH;
    this.renderer.setRenderTarget(null); this.renderer.render(this.pBlit.mesh, this.cam);
  }
}

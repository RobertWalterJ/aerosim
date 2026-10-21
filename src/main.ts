import * as THREE from 'three';
import { AIRFRAMES, Airframe, QUALITY, Quality, WORLD } from './config';
import { ValleyTerrain } from './world/ValleyTerrain';
import { Colliders } from './world/Colliders';
import { FoliageInstancer } from './world/FoliageInstancer';
import { MemorialParkAssets } from './world/MemorialParkAssets';
import { DroneModel } from './world/DroneModel';
import { FoliageUniforms } from './world/FoliageMaterials';
import { Atmosphere } from './rendering/Atmosphere';
import { SensorPipeline } from './rendering/SensorPipeline';
import { Quadcopter6DOF } from './physics/Quadcopter6DOF';
import { FlightController, Gimbal, FlightMode } from './physics/FlightControllerPID';
import { WindField } from './physics/WindFieldVolume';
import { SimulationLoop } from './core/SimulationLoop';
import { InputManagerHID } from './core/InputManagerHID';
import { TelemetryOSD, Telemetry } from './ui/TelemetryOSD';
import { DroneSynthDSP } from './audio/DroneSynthDSP';
import { EcologyAudioEngine } from './audio/EcologyAudioEngine';
import { Missions } from './game/Missions';
import { TouchControls, isTouchDevice } from './ui/TouchControls';
import { initPWA } from './pwa';
import { qrot, qeuler, qmul, qaxis, qslerp, clamp, smoothstep, DEG, V3 } from './util/math';

const $ = (id: string) => document.getElementById(id)!;
const params = new URLSearchParams(location.search);
const setMsg = (m: string, f: number) => { $('msg').textContent = m; ($('bar').firstElementChild as HTMLElement).style.width = (f * 100).toFixed(0) + '%'; };
const tick = () => new Promise<void>(r => setTimeout(r, 0));

async function boot() {
  const touchMode = isTouchDevice(params);
  let qName = (params.get('quality') as Quality) || (touchMode ? 'low' : 'medium'); let Q = QUALITY[qName];
  const canvas = $('gl') as HTMLCanvasElement;
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: false, powerPreference: 'high-performance', preserveDrawingBuffer: params.has('capture') });
  renderer.setPixelRatio(1); renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap; renderer.toneMapping = THREE.NoToneMapping;
  renderer.autoClear = true;
  const gl2 = renderer.getContext() as WebGL2RenderingContext; gl2.getExtension('EXT_color_buffer_float'); gl2.getExtension('OES_texture_float_linear');
  const overrideW = Number(params.get('w')), overrideH = Number(params.get('h'));
  if (overrideW) renderer.setSize(overrideW, overrideH, false); else renderer.setSize(innerWidth, innerHeight, false);
  const size = () => new THREE.Vector2(renderer.domElement.width, renderer.domElement.height);

  // ---------- world
  setMsg('baking valley terrain, land cover and path distance field…', 0.02); await tick();
  const terrain = new ValleyTerrain();
  terrain.bake(f => setMsg('baking valley terrain…', 0.02 + f * 0.25));
  await tick();
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(60, 16 / 9, 0.2, 14000);
  scene.add(camera);
  const pipeline = new SensorPipeline(renderer, Q.msaa);
  const atmo = new Atmosphere(scene, camera, renderer, Q);
  scene.add(terrain.mesh);
  const colliders = new Colliders();
  setMsg('growing the woodland (procedural spruce, maple, oak)…', 0.3); await tick();
  const foliage = new FoliageInstancer(terrain, colliders, Q, f => setMsg('growing the woodland…', 0.3 + f * 0.3));
  scene.add(foliage.group);
  setMsg('carving granite monuments, chapel, lamps…', 0.65); await tick();
  const park = new MemorialParkAssets(terrain, colliders);
  scene.add(park.group); foliage.grass.forEach(g => g.setExclusions(park.exclusions));
  const missions = new Missions(terrain, park.monumentPos.clone().setY(terrain.height(park.monumentPos.x, park.monumentPos.z)));
  scene.add(missions.group);
  // shadows + CSM wiring for every lit material (preserve our own onBeforeCompile patches)
  setMsg('compiling shaders…', 0.8); await tick();
  const seen = new Set<THREE.Material>();
  const wire = (m: THREE.Material) => {
    if (seen.has(m)) return; seen.add(m);
    const sm = m as THREE.MeshStandardMaterial; if (!(sm as any).isMeshStandardMaterial) return;
    const prev = sm.onBeforeCompile; atmo.csm.setupMaterial(sm); const csmFn = sm.onBeforeCompile;
    sm.onBeforeCompile = function (this: any, sh: any, r: any) { csmFn.call(this, sh, r); prev.call(this, sh, r); };
  };
  scene.traverse((o: any) => { if (o.material && o !== atmo.sky) (Array.isArray(o.material) ? o.material : [o.material]).forEach(wire); });
  // ---------- physics
  let af: Airframe = AIRFRAMES[(params.get('airframe') as 'mini' | 'freestyle') || 'mini'];
  const quad = new Quadcopter6DOF(af); const fc = new FlightController(af, quad); const gimbal = new Gimbal();
  const wind = new WindField((x, z) => terrain.height(x, z)); wind.addObstacles(foliage.windObstacles());
  const home = new THREE.Vector3(-18, 0, 36); home.y = terrain.height(home.x, home.z);
  const windVec: V3 = [0, 0, 0]; const push = [0, 0, 0];
  const env = {
    wind: windVec, groundH: (x: number, z: number) => terrain.height(x, z), groundN: (x: number, z: number, o: number[]) => terrain.normal(x, z, o),
    obstacleHit: (x: number, y: number, z: number, r: number, p: number[]) => colliders.hit(x, y, z, r, p),
  };
  void push;
  const drone = new DroneModel(af); drone.group.visible = false; scene.add(drone.group);
  const spawn = (x: number, z: number, yawDeg: number, agl = 0.04, hover = false) => {
    quad.af = af; const y = terrain.height(x, z) + agl; quad.reset(x, y, z, yawDeg * DEG); fc.resetState();
    const wh = af.omegaMax * Math.sqrt(1 / af.twr); if (hover) for (let i = 0; i < 4; i++) { quad.s[13 + i] = wh; quad.cmd[i] = wh; }
    gimbal.pitch = -0.35; gimbal.pv = 0; gimbal.roll = 0; gimbal.rv = 0; fc.mode = 'N'; fc.heading = yawDeg * DEG; missions.reset();
  };
  const tp = params.get('teleport');
  if (tp) { const [x, y, z, h, g] = tp.split(',').map(Number); spawn(x, z, h || 0, y - terrain.height(x, z), true); input_gimbalInit = (g ?? -15) * DEG; } else spawn(home.x, home.z, 150);
  var input_gimbalInit = -20 * DEG; // hoisted for the teleport branch
  // ---------- UI / input / audio
  const osdCanvas = $('osd') as HTMLCanvasElement; const osd = new TelemetryOSD(osdCanvas);
  let chase = false, fps = 60, audioName = 'Cinematic Hybrid', lensName = pipeline.lenses.standard.name;
  let audio: DroneSynthDSP | null = null, eco: EcologyAudioEngine | null = null;
  const initAudio = async () => { if (audio) { await audio.start(); return; } try { audio = new DroneSynthDSP(); await audio.start(); eco = new EcologyAudioEngine(audio.ctx, audio.envBus, foliage.trees); eco.onFlush = (e) => { missions.flushes++; scatterBirds(e); }; audioName = audio.perspective; } catch (e) { console.warn('audio unavailable', e); } };
  const birds: { s: THREE.Sprite; v: THREE.Vector3; t: number; ph: number }[] = []; const birdTex = [0, 1].map(k => { const c = document.createElement('canvas'); c.width = 64; c.height = 32; const g = c.getContext('2d')!; g.fillStyle = '#121212'; g.beginPath(); g.moveTo(32, 18); g.quadraticCurveTo(16, k ? 2 : 24, 2, k ? 8 : 20); g.quadraticCurveTo(18, k ? 12 : 16, 32, 20); g.quadraticCurveTo(46, k ? 12 : 16, 62, k ? 8 : 20); g.quadraticCurveTo(48, k ? 2 : 24, 32, 18); g.fill(); const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t; });
  const scatterBirds = (e: { x: number; y: number; z: number }) => { for (let i = 0; i < 9; i++) { const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: birdTex[0], transparent: true, depthWrite: true, fog: true })); s.scale.set(0.42, 0.21, 1); s.position.set(e.x, e.y, e.z); const a = Math.random() * 6.28; const v = new THREE.Vector3(Math.cos(a) * 7, 2 + Math.random() * 3, Math.sin(a) * 7); scene.add(s); birds.push({ s, v, t: 0, ph: Math.random() * 6 }); } };
  const input = new InputManagerHID(canvas, {
    onMode: m => { fc.mode = m; fc.resetState(); }, onAudio: () => { initAudio().then(() => { if (audio) audioName = audio.cyclePerspective(); }); }, onLens: () => { const l = pipeline.lens === 'standard' ? 'wide' : 'standard'; pipeline.setLens(l, 0); lensName = pipeline.lenses[l].name; },
    onOSD: () => { osd.visible = !osd.visible; }, onReset: () => spawn(home.x, home.z, 150), onChase: () => { chase = !chase; }, onFps: () => { fps = fps === 60 ? 30 : 60; },
    onAirframe: () => { af = af.id === 'mini' ? AIRFRAMES.freestyle : AIRFRAMES.mini; quad.af = af; Object.assign(quad, { rotor: new (quad.rotor.constructor as any)(af) }); (quad as any).battery = new (quad.battery.constructor as any)(af.cells, af.capacityAh, af.rInt); (quad as any).rpos = [[af.armD, 0, -af.armD], [af.armD, 0, af.armD], [-af.armD, 0, af.armD], [-af.armD, 0, -af.armD]]; fc.setAirframe(af); drone.setAirframe(af); spawn(home.x, home.z, 150); },
    onSun: d => { atmo.setSun(atmo.azimuth, atmo.elevation + d); atmo.refreshMaterials(); }, onEv: d => { pipeline.evComp = clamp(pipeline.evComp + d, -3, 3); }, onPhoto: () => { photoReq = true; }, onQuality: () => { }, onBloom: () => { pipeline.bloomOn = !pipeline.bloomOn; },
  });
  input.gimbalCmd = input_gimbalInit;
  const pwa = initPWA();
  let touch: TouchControls | null = null;
  if (touchMode) {
    const next: Record<string, 'N' | 'S' | 'M'> = { N: 'S', S: 'M', M: 'N' };
    touch = new TouchControls({
      mode: () => fc.mode, cycleMode: () => { fc.mode = next[fc.mode] ?? 'N'; fc.resetState(); },
      chase: () => { chase = !chase; }, photo: () => { photoReq = true; }, reset: () => spawn(home.x, home.z, 150),
      lens: () => { const l = pipeline.lens === 'standard' ? 'wide' : 'standard'; pipeline.setLens(l, 0); lensName = pipeline.lenses[l].name; },
      osd: () => { osd.visible = !osd.visible; }, audio: () => { initAudio().then(() => { if (audio) audioName = audio.cyclePerspective(); }); },
      fps: () => { fps = fps === 60 ? 30 : 60; },
      fullscreen: () => { const d = document.documentElement as any; if (document.fullscreenElement) document.exitFullscreen(); else (d.requestFullscreen?.() ?? Promise.resolve()).then(() => (screen.orientation as any)?.lock?.('landscape')).catch(() => { }); },
      install: () => { pwa.promptInstall(); },
    });
    input.touch = touch; touch.syncGimbal(input.gimbalCmd);
    pwa.onInstallable(ok => touch!.setInstallAvailable(ok));
  }
  addEventListener('pointerdown', () => { initAudio(); $('help').style.opacity = '0'; }, { once: false });
  if (!params.has('capture') && !touchMode) setTimeout(() => { $('help').style.display = 'block'; }, 100); setTimeout(() => { $('help').style.opacity = '0'; }, 14000);
  let photoReq = false;

  // ---------- resize
  const layout = () => {
    const cw = overrideW || innerWidth, ch = overrideH || innerHeight; renderer.setSize(cw, ch, false); osd.resize(cw, ch, 1);
    const outH = Math.min(Q.renderHeight, ch); const outW = Math.round(outH * 16 / 9);
    pipeline.resize(outW, outH); pipeline.configureCamera(camera); atmo.setSize();
  };
  layout(); addEventListener('resize', layout);
  // warm-up compile
  renderer.compile(scene, camera); setMsg('ready', 1); await tick();
  if (touchMode && !params.has('capture')) {
    await new Promise<void>(res => {
      const b = document.createElement('button'); b.textContent = 'TAP TO FLY (full screen, landscape)';
      b.style.cssText = 'font:600 15px ui-monospace,Menlo,monospace;letter-spacing:.12em;color:#06090c;background:#7ef;border:0;border-radius:10px;padding:16px 26px;margin-top:10px';
      b.onclick = () => { const d = document.documentElement as any; Promise.resolve(d.requestFullscreen?.()).then(() => (screen.orientation as any)?.lock?.('landscape')).catch(() => { }); initAudio(); res(); };
      $('loading').appendChild(b);
    });
  }
  $('loading').style.opacity = '0'; setTimeout(() => $('loading').remove(), 900);
  setTimeout(() => pwa.maybePrompt(), 6000);

  // ---------- state for per-frame use
  const sim = new SimulationLoop(); let stepN = 0; let simT = 0;
  const rfState = { dbm: -45, bad: 0, sats: 16, accum: 0, stutter: 0 };
  const tmpQ = [0, 0, 0, 1]; const camQ = new THREE.Quaternion(); const prevCamQ = new THREE.Quaternion(); const prevCamQInit = { v: false };
  let lastTex: THREE.Texture | null = null; let sensorAcc = 1, lastSensorT = 0; let fpsSmooth = 60;
  const bodyPose = { pos: new THREE.Vector3(), quat: [0, 0, 0, 1] as number[] };
  const physStep = (dt: number, t: number) => {
    simT = t;
    if ((stepN++ % 10) === 0) wind.sample(quad.s[0], quad.s[1], quad.s[2], t, windVec);
    fc.onGround = quad.groundContact;
    fc.update(dt, input.sticks);
    quad.step(dt, env);
    // gimbal (fixed 1 kHz)
    const f: V3 = [0, 0, 0]; qrot(quad.s, 6, [0, 0, -1], f); const bodyPitch = Math.asin(clamp(f[1], -1, 1));
    const vib = clamp(0.2 + 0.5 * fc.thrustFraction ** 2 + 1.4 * quad.vrs, 0, 1);
    gimbal.update(dt, input.gimbalCmd, bodyPitch, quad.angAccel[0], quad.angAccel[2], quad.s[11], vib * (af.hasGimbal ? 0.35 : 0), Math.hypot(windVec[0], windVec[2]) * 0.01, fc.mode !== 'M' || true);
  };
  const missionsAirborne = () => (quad.s[1] - terrain.height(quad.s[0], quad.s[2])) > 1.0;

  // ---------- RF link model (OcuSync-like line of sight)
  const rfUpdate = () => {
    const ax = home.x, ay = home.y + 1.6, az = home.z, bx = quad.s[0], by = quad.s[1], bz = quad.s[2];
    const d = Math.hypot(bx - ax, by - ay, bz - az);
    let loss = colliders.rfLoss(ax, ay, az, bx, by, bz);
    let blocked = 0; const n = 48; for (let i = 1; i < n; i++) { const t = i / n; if (ay + (by - ay) * t < terrain.height(ax + (bx - ax) * t, az + (bz - az) * t) + 0.4) blocked++; }
    loss += Math.min(48, blocked * 6);
    rfState.dbm = -35 - 20 * Math.log10(d / 10 + 1) - loss;
    rfState.bad = smoothstep(-76, -92, rfState.dbm);
    const canopy: number[] = [0, 0, 0]; void canopy;
    rfState.sats = Math.round(clamp(17 - (blocked > 0 ? 3 : 0) - (colliders.rfLoss(bx, by, bz, bx, by + 60, bz) > 3 ? 6 : 0) + (Math.sin(performance.now() / 4000) > 0.8 ? -1 : 0), 4, 18));
  };

  // ---------- main loop
  let last = performance.now(), rfT = 0, fpsAcc = 0, fpsN = 0, frameIdx = 0;
  const tmpV = new THREE.Vector3(), camFwd = new THREE.Vector3(), up = new THREE.Vector3(0, 1, 0);
  const loop = (now: number) => {
    const dtF = Math.min((now - last) / 1000, 0.1); last = now; frameIdx++;
    fpsAcc += dtF; fpsN++; if (fpsAcc > 0.5) { fpsSmooth = fpsN / fpsAcc; fpsAcc = 0; fpsN = 0; }
    const sticks = input.poll(dtF); void sticks;
    const alpha = sim.advance(dtF, physStep);
    if (quad.crashed && !(quad as any)._counted) { (quad as any)._counted = true; missions.crashes++; } if (!quad.crashed) (quad as any)._counted = false;
    touch?.setCrashed(quad.crashed || !quad.armed);
    // interpolated body pose
    bodyPose.pos.set(quad.prevPos[0] + (quad.s[0] - quad.prevPos[0]) * alpha, quad.prevPos[1] + (quad.s[1] - quad.prevPos[1]) * alpha, quad.prevPos[2] + (quad.s[2] - quad.prevPos[2]) * alpha);
    qslerp(Array.from(quad.prevQuat), [quad.s[6], quad.s[7], quad.s[8], quad.s[9]], alpha, bodyPose.quat);
    rfT += dtF; if (rfT > 0.1) { rfT = 0; rfUpdate(); }
    // camera orientation
    const bq = bodyPose.quat; const fwd: V3 = [0, 0, 0]; qrot(bq, 0, [0, 0, -1], fwd);
    const heading = Math.atan2(-fwd[0], -fwd[2]);
    let cq: number[];
    if (af.hasGimbal) cq = qeuler(heading + gimbal.yawErr, gimbal.pitch, gimbal.roll, tmpQ);
    else cq = qmul(bq, qaxis(1, 0, 0, af.camTilt, [0, 0, 0, 1]), [0, 0, 0, 1]);
    const off: V3 = [0, 0, 0]; qrot(bq, 0, af.camOffset, off);
    camera.position.set(bodyPose.pos.x + off[0], bodyPose.pos.y + off[1], bodyPose.pos.z + off[2]); camQ.set(cq[0], cq[1], cq[2], cq[3]); camera.quaternion.copy(camQ);
    drone.group.position.copy(bodyPose.pos); drone.group.quaternion.set(bq[0], bq[1], bq[2], bq[3]);
    drone.update(quad.motorOmega, simT, af.hasGimbal ? gimbal.pitch - Math.asin(clamp(fwd[1], -1, 1)) : af.camTilt);
    drone.group.visible = chase;
    if (chase) { const back = tmpV.set(-fwd[0], 0, -fwd[2]).normalize().multiplyScalar(5.5); camera.position.set(bodyPose.pos.x + back.x, bodyPose.pos.y + 1.6, bodyPose.pos.z + back.z); camera.lookAt(bodyPose.pos); camQ.copy(camera.quaternion); }
    // foliage / grass uniforms
    const agl = quad.s[1] - terrain.height(quad.s[0], quad.s[2]);
    FoliageUniforms.uDrone.value.set(bodyPose.pos.x, bodyPose.pos.y, bodyPose.pos.z, 3.5);
    FoliageUniforms.uWash.value = clamp(fc.thrustFraction * 1.8, 0, 1) * (1 - smoothstep(4, 14, agl)) * (quad.armed ? 1 : 0);
    const cw: V3 = [0, 0, 0]; wind.canopyWind(quad.s[0], quad.s[2], simT, cw); FoliageUniforms.uWind.value.set(cw[0], cw[1], cw[2]);
    foliage.update(camera.position, now / 1000);
    missions.update(dtF, camera.position, missionsAirborne());
    for (let i = birds.length - 1; i >= 0; i--) { const b = birds[i]; b.t += dtF; b.s.position.addScaledVector(b.v, dtF); b.v.y += (b.t < 1.5 ? 1.2 : -0.1) * dtF; b.s.material.map = birdTex[Math.floor((b.t * 11 + b.ph) % 2)]; if (b.t > 9) { scene.remove(b.s); b.s.material.dispose(); birds.splice(i, 1); } }
    // audio
    if (audio && audio.started) {
      const mr = Array.from(quad.motorOmega).map(w => w * 60 / (2 * Math.PI)); const vAir = Math.hypot(quad.s[3] - windVec[0], quad.s[4] - windVec[1], quad.s[5] - windVec[2]);
      const cf: V3 = [0, 0, 0]; camera.getWorldDirection(tmpV); cf[0] = tmpV.x; cf[1] = tmpV.y; cf[2] = tmpV.z;
      let refl = Infinity; const hd = [Math.cos(heading), -Math.sin(heading)]; for (const ang of [0, Math.PI / 2, Math.PI, -Math.PI / 2]) { const dx = hd[0] * Math.cos(ang) - hd[1] * Math.sin(ang), dz = hd[0] * Math.sin(ang) + hd[1] * Math.cos(ang); refl = Math.min(refl, colliders.reflectorDistance(quad.s[0], quad.s[1], quad.s[2], dx, dz, 12)); }
      audio.update({ motorRpm: mr, nBlades: af.nBlades, throttle: clamp(fc.thrustFraction, 0, 1) ** 0.5, vz: quad.s[4], angJerk: Math.hypot(...quad.angAccel), vrs: quad.vrs, airSpeed: vAir, dronePos: [quad.s[0], quad.s[1], quad.s[2]], homePos: [home.x, home.y + 1.6, home.z], droneVel: [quad.s[3], quad.s[4], quad.s[5]], reflectorDist: refl, camForward: cf, aglM: agl, grassWash: agl < 3.5 ? FoliageUniforms.uWash.value : 0, windCanopy: Math.hypot(cw[0], cw[2]), coniferFrac: 0.5, gust: clamp(vAir / 12, 0, 1) }, dtF);
      eco?.update(now / 1000, [quad.s[0], quad.s[1], quad.s[2]], dtF, [quad.s[3], quad.s[4], quad.s[5]]);
    }
    // sensor cadence
    sensorAcc += dtF; const period = 1 / fps; let rendered = false;
    const freeze = rfState.dbm < -92 && Math.random() < 0.5;       // video freezes when the link nearly drops
    if ((sensorAcc >= period || !lastTex) && !freeze) {
      const sdt = Math.max(sensorAcc, 1e-3); sensorAcc = Math.min(sensorAcc - period, period);
      camera.updateMatrixWorld(true); pipeline.configureCamera(camera);
      const angVel = new THREE.Vector3(); if (prevCamQInit.v) { const dq = prevCamQ.clone().invert().multiply(camQ); const ang = 2 * Math.acos(clamp(Math.abs(dq.w), 0, 1)); const s = Math.sqrt(Math.max(1 - dq.w * dq.w, 1e-9)); const sgn = dq.w < 0 ? -1 : 1; angVel.set(dq.x / s, dq.y / s, dq.z / s).multiplyScalar(ang * sgn / sdt); if (!isFinite(angVel.x)) angVel.set(0, 0, 0); }
      prevCamQ.copy(camQ); prevCamQInit.v = true; angVel.clampLength(0, 12);
      atmo.update(); pipeline.renderScene(scene, camera);
      const hz = (quad.motorOmega[0] + quad.motorOmega[1] + quad.motorOmega[2] + quad.motorOmega[3]) / 4 / (2 * Math.PI) * af.nBlades;
      lastTex = pipeline.process({ dt: sdt, time: now / 1000, camera, sunDir: atmo.sunDir, angVelCam: chase ? new THREE.Vector3() : angVel, vibration: clamp(0.2 + 0.7 * fc.thrustFraction ** 2 + 1.5 * quad.vrs, 0, 1) * (chase ? 0 : 1), motorHz: hz, rfBad: rfState.bad });
      rendered = true;
    }
    void rendered;
    if (lastTex) { const s = size(); pipeline.blit(lastTex, s.x, s.y); }
    if (photoReq) { photoReq = false; const ok = missions.photo(camera.position, camera.getWorldDirection(camFwd)); canvas.toBlob(b => { if (!b) return; const a = document.createElement('a'); a.href = URL.createObjectURL(b); a.download = `aerosim_${ok ? 'memorial_' : ''}${Date.now()}.png`; a.click(); }); }
    // ---- OSD
    const s = size(); const aspect = pipeline.outW / pipeline.outH; let fw = s.x, fh = s.x / aspect; if (fh > s.y) { fh = s.y; fw = s.y * aspect; }
    const body = new THREE.Quaternion(bq[0], bq[1], bq[2], bq[3]); const vb = new THREE.Vector3(quad.s[3], quad.s[4], quad.s[5]).applyQuaternion(body.clone().invert());
    const camE = new THREE.Euler().setFromQuaternion(camQ, 'YXZ'); const hb = Math.atan2(home.x - quad.s[0], -(home.z - quad.s[2]));
    const tel: Telemetry = {
      mode: fc.mode, sats: rfState.sats, rfDbm: rfState.dbm, rfBars: clamp(Math.round((rfState.dbm + 100) / 12), 0, 5), battPct: quad.battery.soc * 100, cellV: quad.battery.cellV, battA: quad.battery.current,
      iso: pipeline.isoShown, shutter: pipeline.shutterShown, ev: pipeline.evComp, pitch: camE.x, roll: camE.z, heading: heading, velWorld: [quad.s[3], quad.s[4], quad.s[5]], velBody: [vb.x, vb.y, vb.z],
      aglM: agl, mslM: quad.s[1], gs: Math.hypot(quad.s[3], quad.s[5]), vs: quad.s[4], homeDist: Math.hypot(quad.s[0] - home.x, quad.s[2] - home.z), gimbalDeg: (af.hasGimbal ? gimbal.pitch : af.camTilt) / DEG,
      histogram: pipeline.histogram, lensName, airframe: af.name + (chase ? '  [CHASE]' : ''), audio: audio ? audio.perspective : 'click to enable', fps: Math.min(fps, fpsSmooth), crashed: quad.crashed || !quad.armed ? quad.crashReason : '', armed: quad.armed, touch: touchMode, mission: missions.lines(), windMs: Math.hypot(windVec[0], windVec[2]), homeBearing: hb, droneBearing: 0, sunVis: 0, stopHit: gimbal.stopHit, eco: eco ? `birds flushed: ${eco.flushes}` : '',
    };
    osd.draw(tel, { x: (s.x - fw) / 2, y: (s.y - fh) / 2, w: fw, h: fh });
    requestAnimationFrame(loop);
  };
  requestAnimationFrame(loop);

  // test/automation hooks
  (window as any).__aerosim = {
    ready: true, quality: qName, quad, fc, gimbal, terrain, atmo, pipeline, scene, camera, renderer, foliage, park, colliders, wind, input, rf: rfState,
    sticks: (t: number, y: number, p: number, r: number) => { input.sticks.throttle = t; input.sticks.yaw = y; input.sticks.pitch = p; input.sticks.roll = r; input.poll = () => input.sticks; },
    stats: () => ({ fps: fpsSmooth, calls: renderer.info.render.calls, tris: renderer.info.render.triangles, programs: renderer.info.programs?.length, textures: renderer.info.memory.textures, geometries: renderer.info.memory.geometries }),
  };
}
boot().catch(e => { console.error(e); setMsg('ERROR: ' + (e?.message ?? e), 0); });
void WORLD;

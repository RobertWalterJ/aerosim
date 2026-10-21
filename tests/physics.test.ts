import { Quadcopter6DOF } from '../src/physics/Quadcopter6DOF';
import { FlightController } from '../src/physics/FlightControllerPID';
import { MINI, FREESTYLE } from '../src/config';
import { RotorModel } from '../src/physics/AerodynamicsBEM';

const env = (wind: [number, number, number] = [0, 0, 0]) => ({
  wind, groundH: () => 0, groundN: (_x: number, _z: number, o: number[]) => { o[0] = 0; o[1] = 1; o[2] = 0; },
});
let fails = 0; const DEG = Math.PI / 180;
const check = (name: string, ok: boolean, info: string) => { console.log((ok ? 'PASS ' : 'FAIL ') + name + '  ' + info); if (!ok) fails++; };

for (const af of [MINI, FREESTYLE]) {
  console.log('--- ' + af.name);
  const rm = new RotorModel(af);
  const o = { T: 0, Q: 0, H: 0, lambdaI: 0, ge: 1, vrs: 0 };
  // static thrust at omegaMax
  rm.compute(af.omegaMax, 0, 0, 10, 1.225, 0, o);
  check('static Tmax', Math.abs(o.T - rm.Tmax) / rm.Tmax < 0.03, `T=${o.T.toFixed(3)} N vs ${rm.Tmax.toFixed(3)} N`);
  const wh = af.omegaMax * Math.sqrt(1 / af.twr);
  rm.compute(wh, 0, 0, 10, 1.225, 0, o); const Thov = o.T; const lamH = o.lambdaI;
  rm.compute(wh, 0, 0, af.R * 0.5, 1.225, 0, o);
  check('ground effect boosts thrust', o.T > Thov * 1.05, `GE x${(o.T / Thov).toFixed(3)} at z=0.5R`);
  rm.compute(wh, 0, 0, 10, 1.225, 0, o); const T0 = o.T;
  const vtl = 0.1 * wh * af.R; rm.compute(wh, 0, vtl, 10, 1.225, 0, o);
  check('translational lift at mu=0.1 (inflow drops)', o.lambdaI < lamH * 0.95, `${vtl.toFixed(1)} m/s: lambda_i ${(o.lambdaI/lamH).toFixed(2)}x hover, T x${(o.T / T0).toFixed(3)}`);
  const vh = lamH * wh * af.R;
  rm.compute(wh, -0.5 * vh, 0, 10, 1.225, 0, o);
  check('VRS thrust loss in window', o.vrs > 0.3, `vrs=${o.vrs.toFixed(2)} T x${(o.T / T0).toFixed(3)}`);

  // hover in N-mode
  const q = new Quadcopter6DOF(af); const fc = new FlightController(af, q);
  q.reset(0, 20, 0, 0); q.s[13] = q.s[14] = q.s[15] = q.s[16] = wh;
  for (let i = 0; i < 4; i++) q.cmd[i] = wh;
  let t = 0; const dt = 0.001; const E = env();
  for (; t < 6; t += dt) { fc.update(dt, { throttle: 0, yaw: 0, pitch: 0, roll: 0 }); q.step(dt, E); }
  check('N-mode hover holds alt', Math.abs(q.s[1] - 20) < 0.3 && Math.hypot(q.s[3], q.s[5]) < 0.1, `y=${q.s[1].toFixed(3)} v=${Math.hypot(q.s[3], q.s[4], q.s[5]).toFixed(3)} P=${q.pElec.toFixed(1)} W`);
  // forward stick
  for (let k = 0; k < 4; k++) { for (let i = 0; i < 4000; i++) { fc.update(dt, { throttle: 0, yaw: 0, pitch: 1, roll: 0 }); q.step(dt, E); } }
  const vF = Math.hypot(q.s[3], q.s[5]);
  check('forward flight reaches vmax', vF > af.limits.N.vH * 0.8, `v=${vF.toFixed(2)} m/s, alt=${q.s[1].toFixed(2)}, tilt=${(fc.tilt / DEG).toFixed(1)}deg`);
  // release, brake
  for (let i = 0; i < 6000; i++) { fc.update(dt, { throttle: 0, yaw: 0, pitch: 0, roll: 0 }); q.step(dt, E); }
  check('brakes to hover', Math.hypot(q.s[3], q.s[5]) < 0.4, `v=${Math.hypot(q.s[3], q.s[5]).toFixed(2)}`);
  // wind hold
  const Ew = env([6, 0, 0]);
  for (let i = 0; i < 8000; i++) { fc.update(dt, { throttle: 0, yaw: 0, pitch: 0, roll: 0 }); q.step(dt, Ew); }
  check('GPS hold in 6 m/s wind', Math.hypot(q.s[3], q.s[5]) < 0.5, `v=${Math.hypot(q.s[3], q.s[5]).toFixed(2)} alt=${q.s[1].toFixed(2)}`);
  // M mode acro roll rate step
  fc.mode = 'M'; fc.resetState();
  let maxW = 0;
  for (let i = 0; i < 700; i++) { fc.update(dt, { throttle: 0.1, yaw: 0, pitch: 0, roll: 1 }); q.step(dt, E); maxW = Math.max(maxW, Math.abs(q.s[12])); }
  check('M-mode roll rate achieved', maxW > 2.5, `peak roll rate ${(maxW / DEG).toFixed(0)} deg/s`);
  check('M-mode stays armed', !q.crashed, q.crashReason);
  // battery
  console.log(`battery: soc=${q.battery.soc.toFixed(3)} V=${q.battery.vTerm.toFixed(2)} (${q.battery.cellV.toFixed(2)}/cell) I=${q.battery.current.toFixed(1)}A`);
}
console.log(fails === 0 ? 'ALL PASS' : fails + ' FAILURES');
process.exit(fails ? 1 : 0);

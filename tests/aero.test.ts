// Aerobatics mode checks: self-levelling, altitude assist and every trick on
// both airframes, using the real physics and flight controller.
import { Quadcopter6DOF } from '../src/physics/Quadcopter6DOF';
import { FlightController } from '../src/physics/FlightControllerPID';
import { MINI, FREESTYLE } from '../src/config';
import { Aerobatics, type TrickKind } from '../src/game/Aerobatics';

const env = { wind: [0, 0, 0] as [number, number, number], groundH: () => 0, groundN: (_x: number, _z: number, o: number[]) => { o[0] = 0; o[1] = 1; o[2] = 0; } };
let fails = 0; const DEG = Math.PI / 180;
const check = (name: string, ok: boolean, info: string): void => { console.log((ok ? 'PASS ' : 'FAIL ') + name + '  ' + info); if (!ok) fails++; };
const zero = { throttle: 0, yaw: 0, pitch: 0, roll: 0 };

for (const af of [MINI, FREESTYLE]) {
  console.log('--- ' + af.name + ' (aerobatics)');
  const q = new Quadcopter6DOF(af), fc = new FlightController(af, q), A = new Aerobatics(fc, q, af);
  const wh = af.omegaMax * Math.sqrt(1 / af.twr);
  q.reset(0, 40, 0, 0); for (let i = 0; i < 4; i++) { q.s[13 + i] = wh; q.cmd[i] = wh; }
  A.setActive(true, af);
  const dt = 0.001;
  const run = (sec: number, st = zero): void => { for (let t = 0; t < sec; t += dt) { fc.onGround = q.groundContact; fc.update(dt, A.shape(dt, st)); q.step(dt, env); } };
  const tiltDeg = (): number => fc.tilt / DEG;
  run(3);
  check('hover holds altitude', Math.abs(q.s[1] - 40) < 0.6 && tiltDeg() < 3, `y=${q.s[1].toFixed(2)} tilt=${tiltDeg().toFixed(1)}`);
  run(1.5, { ...zero, roll: 0.4 });
  const lean = tiltDeg();
  check('half stick leans (horizon)', lean > 12 && lean < 35, `lean ${lean.toFixed(1)} deg`);
  run(2.5);
  check('releases to level', tiltDeg() < 4, `tilt ${tiltDeg().toFixed(1)} deg`);
  run(2, { ...zero, throttle: 0.6 }); const y1 = q.s[1]; run(1, { ...zero, throttle: 0.6 });
  check('throttle up climbs', q.s[1] - y1 > 2, `climb ${(q.s[1] - y1).toFixed(2)} m/s`);
  run(3);
  for (const k of ['flip', 'roll', 'loop', 'pirouette'] as TrickKind[]) {
    const y0 = q.s[1], n0 = A.count;
    A.start(k, zero);
    let t = 0; while (A.trick && t < 6) { run(0.01); t += 0.01; }
    run(1.5);
    const ok = A.count === n0 + 1 && !q.crashed && tiltDeg() < 8;
    check(`trick ${k}`, ok, `${t.toFixed(2)} s, height change ${(q.s[1] - y0).toFixed(1)} m, tilt after ${tiltDeg().toFixed(1)} deg${q.crashed ? ' CRASHED ' + q.crashReason : ''}`);
    run(2);
  }
  A.setActive(false, af);
  check('leaving A mode restores rates', (fc as any).af === af, '');
}
console.log(fails === 0 ? 'ALL PASS' : fails + ' FAILURES');
process.exit(fails ? 1 : 0);

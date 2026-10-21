export type V3 = [number, number, number];
export type Q4 = [number, number, number, number]; // x,y,z,w
export const clamp = (x: number, a: number, b: number) => (x < a ? a : x > b ? b : x);
export const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
export const smoothstep = (a: number, b: number, x: number) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };
export const DEG = Math.PI / 180;

/** v rotated by q (body -> world). */
export function qrot(q: ArrayLike<number>, qo: number, v: ArrayLike<number>, out: number[] | Float64Array): void {
  const x = q[qo], y = q[qo + 1], z = q[qo + 2], w = q[qo + 3];
  const vx = v[0], vy = v[1], vz = v[2];
  const tx = 2 * (y * vz - z * vy), ty = 2 * (z * vx - x * vz), tz = 2 * (x * vy - y * vx);
  out[0] = vx + w * tx + (y * tz - z * ty);
  out[1] = vy + w * ty + (z * tx - x * tz);
  out[2] = vz + w * tz + (x * ty - y * tx);
}
/** v rotated by inverse(q) (world -> body). */
export function qrotInv(q: ArrayLike<number>, qo: number, v: ArrayLike<number>, out: number[] | Float64Array): void {
  const x = -q[qo], y = -q[qo + 1], z = -q[qo + 2], w = q[qo + 3];
  const vx = v[0], vy = v[1], vz = v[2];
  const tx = 2 * (y * vz - z * vy), ty = 2 * (z * vx - x * vz), tz = 2 * (x * vy - y * vx);
  out[0] = vx + w * tx + (y * tz - z * ty);
  out[1] = vy + w * ty + (z * tx - x * tz);
  out[2] = vz + w * tz + (x * ty - y * tx);
}
export function qmul(a: ArrayLike<number>, b: ArrayLike<number>, out: number[]): number[] {
  const ax = a[0], ay = a[1], az = a[2], aw = a[3], bx = b[0], by = b[1], bz = b[2], bw = b[3];
  out[0] = aw * bx + ax * bw + ay * bz - az * by;
  out[1] = aw * by - ax * bz + ay * bw + az * bx;
  out[2] = aw * bz + ax * by - ay * bx + az * bw;
  out[3] = aw * bw - ax * bx - ay * by - az * bz;
  return out;
}
export function qaxis(ax: number, ay: number, az: number, ang: number, out: number[]): number[] {
  const s = Math.sin(ang / 2); out[0] = ax * s; out[1] = ay * s; out[2] = az * s; out[3] = Math.cos(ang / 2); return out;
}
export function qnormalize(q: Float64Array | number[], o = 0): void {
  const n = 1 / Math.hypot(q[o], q[o + 1], q[o + 2], q[o + 3]);
  q[o] *= n; q[o + 1] *= n; q[o + 2] *= n; q[o + 3] *= n;
}
/** Yaw (about +Y), then pitch (about +X, + = nose up), then roll (about +Z). */
export function qeuler(yaw: number, pitch: number, roll: number, out: number[]): number[] {
  const a = qaxis(0, 1, 0, yaw, [0, 0, 0, 1]), b = qaxis(1, 0, 0, pitch, [0, 0, 0, 1]), c = qaxis(0, 0, 1, roll, [0, 0, 0, 1]);
  const ab = qmul(a, b, [0, 0, 0, 1]); return qmul(ab, c, out);
}
export function qslerp(a: ArrayLike<number>, b: ArrayLike<number>, t: number, out: number[]): number[] {
  let bx = b[0], by = b[1], bz = b[2], bw = b[3];
  let d = a[0] * bx + a[1] * by + a[2] * bz + a[3] * bw;
  if (d < 0) { d = -d; bx = -bx; by = -by; bz = -bz; bw = -bw; }
  let s0: number, s1: number;
  if (d > 0.9995) { s0 = 1 - t; s1 = t; } else { const th = Math.acos(d), sn = Math.sin(th); s0 = Math.sin((1 - t) * th) / sn; s1 = Math.sin(t * th) / sn; }
  out[0] = a[0] * s0 + bx * s1; out[1] = a[1] * s0 + by * s1; out[2] = a[2] * s0 + bz * s1; out[3] = a[3] * s0 + bw * s1;
  const n = 1 / Math.hypot(out[0], out[1], out[2], out[3]); out[0] *= n; out[1] *= n; out[2] *= n; out[3] *= n;
  return out;
}

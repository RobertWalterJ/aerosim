import { DEG } from '../util/math';

export interface Telemetry {
  mode: 'N' | 'S' | 'M'; sats: number; rfDbm: number; rfBars: number; battPct: number; cellV: number; battA: number; iso: number; shutter: number; ev: number;
  pitch: number; roll: number; heading: number; velWorld: [number, number, number]; velBody: [number, number, number]; aglM: number; mslM: number; gs: number; vs: number; homeDist: number; gimbalDeg: number;
  histogram: Float32Array; lensName: string; airframe: string; audio: string; fps: number; crashed: string; armed: boolean; mission: string[]; windMs: number; homeBearing: number; droneBearing: number; sunVis: number; stopHit: number; eco: string;
}

/** Crisp vector OSD drawn on a 2D canvas over the video feed. */
export class TelemetryOSD {
  visible = true;
  private ctx: CanvasRenderingContext2D; private w = 0; private h = 0; private dpr = 1;
  constructor(private canvas: HTMLCanvasElement) { this.ctx = canvas.getContext('2d')!; }
  resize(cssW: number, cssH: number, dpr: number) { this.dpr = dpr; this.canvas.width = Math.round(cssW * dpr); this.canvas.height = Math.round(cssH * dpr); this.canvas.style.width = cssW + 'px'; this.canvas.style.height = cssH + 'px'; this.w = cssW; this.h = cssH; }
  draw(t: Telemetry, frameRect: { x: number; y: number; w: number; h: number }): void {
    const c = this.ctx; c.setTransform(this.dpr, 0, 0, this.dpr, 0, 0); c.clearRect(0, 0, this.w, this.h);
    if (!this.visible) return;
    const { x, y, w, h } = frameRect; const u = Math.max(0.6, Math.min(w / 1280, h / 720));
    c.save(); c.translate(x, y);
    const F = (s: number, b = false) => { c.font = `${b ? '600 ' : ''}${Math.round(s * u)}px "SF Mono", Menlo, Consolas, "DejaVu Sans Mono", monospace`; };
    const text = (s: string, px: number, py: number, al: CanvasTextAlign = 'left', col = '#fff') => { c.textAlign = al; c.fillStyle = 'rgba(0,0,0,0.55)'; c.fillText(s, px + 1.2 * u, py + 1.2 * u); c.fillStyle = col; c.fillText(s, px, py); };
    c.lineWidth = 1.6 * u; c.strokeStyle = '#fff'; c.shadowColor = 'rgba(0,0,0,0.6)'; c.shadowBlur = 3 * u;
    const m = 18 * u;
    // ---- top bar
    c.fillStyle = 'rgba(0,0,0,0.28)'; c.fillRect(0, 0, w, 36 * u);
    const mcol = t.mode === 'N' ? '#8ff' : t.mode === 'S' ? '#fc6' : '#f88';
    F(15, true); c.strokeStyle = mcol; c.strokeRect(m, 8 * u, 26 * u, 20 * u); text(t.mode, m + 13 * u, 24 * u, 'center', mcol);
    F(13); text(t.armed ? (t.mode === 'M' ? 'MANUAL' : t.mode === 'S' ? 'SPORT' : 'NORMAL') : t.crashed || 'DISARMED', m + 36 * u, 24 * u, 'left', t.armed ? '#fff' : '#f66');
    const gx = w * 0.30; text('GPS', gx, 24 * u); for (let i = 0; i < 5; i++) { c.fillStyle = i < Math.round(t.sats / 4) ? '#7f7' : 'rgba(255,255,255,0.3)'; c.fillRect(gx + 34 * u + i * 5 * u, 24 * u - (4 + i * 3) * u, 3 * u, (4 + i * 3) * u); } text(String(t.sats), gx + 66 * u, 24 * u);
    const rx = w * 0.43; text('RF', rx, 24 * u); for (let i = 0; i < 5; i++) { c.fillStyle = i < t.rfBars ? (t.rfBars <= 1 ? '#f66' : '#7f7') : 'rgba(255,255,255,0.3)'; c.fillRect(rx + 22 * u + i * 5 * u, 24 * u - (4 + i * 3) * u, 3 * u, (4 + i * 3) * u); } text(`${t.rfDbm.toFixed(0)} dBm`, rx + 52 * u, 24 * u);
    const bx = w * 0.60; const bc = t.battPct < 20 ? '#f66' : t.battPct < 40 ? '#fc6' : '#fff'; c.strokeStyle = bc; c.strokeRect(bx, 12 * u, 28 * u, 14 * u); c.fillStyle = bc; c.fillRect(bx + 2 * u, 14 * u, 24 * u * t.battPct / 100, 10 * u); c.fillRect(bx + 28 * u, 15 * u, 2 * u, 8 * u);
    text(`${t.battPct.toFixed(0)}%  ${t.cellV.toFixed(2)}V/c  ${t.battA.toFixed(1)}A`, bx + 38 * u, 24 * u);
    F(13); text(`ISO ${t.iso}  1/${Math.round(1 / t.shutter)}  EV ${t.ev >= 0 ? '+' : ''}${t.ev.toFixed(1)}`, w - m, 24 * u, 'right');
    // ---- reticle / horizon / pitch ladder
    const cx = w / 2, cy = h / 2; c.strokeStyle = 'rgba(255,255,255,0.9)'; c.lineWidth = 1.5 * u;
    c.beginPath(); c.moveTo(cx - 14 * u, cy); c.lineTo(cx - 4 * u, cy); c.moveTo(cx + 4 * u, cy); c.lineTo(cx + 14 * u, cy); c.moveTo(cx, cy - 14 * u); c.lineTo(cx, cy - 4 * u); c.moveTo(cx, cy + 4 * u); c.lineTo(cx, cy + 14 * u); c.stroke();
    c.save(); c.beginPath(); c.rect(cx - 150 * u, cy - 110 * u, 300 * u, 220 * u); c.clip();
    c.translate(cx, cy); c.rotate(-t.roll); const ppd = 5.2 * u;           // px per degree
    const camPitch = t.pitch / DEG;
    for (let a = -40; a <= 40; a += 10) { const yy = (camPitch - a) * ppd * 0 + (-(a - camPitch)) * ppd * -1; const Y = (camPitch - a) * ppd * -1; void yy; const len = a === 0 ? 120 : 34; c.globalAlpha = a === 0 ? 0.95 : 0.55; c.beginPath(); c.moveTo(-len * u, Y); c.lineTo(-10 * u, Y); c.moveTo(10 * u, Y); c.lineTo(len * u, Y); c.stroke(); if (a !== 0) { F(10); text(String(a), -len * u - 6 * u, Y + 3 * u, 'right'); } }
    c.restore(); c.globalAlpha = 1;
    // velocity vector (flight-path marker)
    const sp = Math.hypot(t.velBody[0], t.velBody[2]);
    if (sp > 0.8) { const fx = Math.max(-140, Math.min(140, (t.velBody[0] / Math.max(sp, 1)) * Math.min(1, sp / 12) * 120)) * u, fy = Math.max(-100, Math.min(100, (-t.velBody[1] / Math.max(sp, 4)) * 90)) * u; c.strokeStyle = '#8f8'; c.beginPath(); c.arc(cx + fx, cy + fy, 6 * u, 0, 6.283); c.moveTo(cx + fx - 12 * u, cy + fy); c.lineTo(cx + fx - 6 * u, cy + fy); c.moveTo(cx + fx + 6 * u, cy + fy); c.lineTo(cx + fx + 12 * u, cy + fy); c.moveTo(cx + fx, cy + fy - 6 * u); c.lineTo(cx + fx, cy + fy - 12 * u); c.stroke(); }
    // ---- gimbal scale (right edge)
    const sx = w - 26 * u, sy0 = h * 0.28, sy1 = h * 0.72; c.strokeStyle = '#fff'; c.lineWidth = 1.2 * u; c.beginPath(); c.moveTo(sx, sy0); c.lineTo(sx, sy1); c.stroke();
    F(10); for (let a = 20; a >= -90; a -= 10) { const yy = sy0 + (20 - a) / 110 * (sy1 - sy0); c.beginPath(); c.moveTo(sx - (a % 30 === 0 ? 8 : 4) * u, yy); c.lineTo(sx, yy); c.stroke(); if (a % 30 === 0 || a === 20) text(String(a), sx - 12 * u, yy + 3 * u, 'right'); }
    const gy = sy0 + (20 - t.gimbalDeg) / 110 * (sy1 - sy0); c.fillStyle = t.stopHit ? '#f66' : '#ffe14d'; c.beginPath(); c.moveTo(sx + 2 * u, gy); c.lineTo(sx + 11 * u, gy - 5 * u); c.lineTo(sx + 11 * u, gy + 5 * u); c.fill();
    F(12, true); text(`${t.gimbalDeg.toFixed(0)}°`, sx + 6 * u, sy1 + 18 * u, 'center', '#ffe14d');
    // ---- bottom bar
    c.fillStyle = 'rgba(0,0,0,0.30)'; c.fillRect(0, h - 56 * u, w, 56 * u);
    const items: [string, string][] = [['H', `${t.homeDist.toFixed(0)} m`], ['AGL', `${t.aglM.toFixed(1)} m`], ['MSL', `${t.mslM.toFixed(0)} m`], ['H.S', `${t.gs.toFixed(1)} m/s  ${(t.gs * 3.6).toFixed(0)} km/h`], ['V.S', `${t.vs >= 0 ? '+' : ''}${t.vs.toFixed(1)} m/s`], ['WIND', `${t.windMs.toFixed(1)} m/s`]];
    let bxp = m; items.forEach(([k, v]) => { F(11); text(k, bxp, h - 34 * u, 'left', '#bcd'); F(17, true); text(v, bxp, h - 14 * u); bxp += (c.measureText(v).width) + 34 * u; });
    // ---- bottom-right: histogram + radar compass
    const hx = w - 214 * u, hy = h - 150 * u, hw = 180 * u, hh = 70 * u; c.fillStyle = 'rgba(0,0,0,0.38)'; c.fillRect(hx, hy, hw, hh); const hmax = Math.max(0.0001, ...Array.from(t.histogram));
    c.fillStyle = 'rgba(255,255,255,0.85)'; for (let i = 0; i < 64; i++) { const v = Math.pow(t.histogram[i] / hmax, 0.6) * (hh - 6 * u); c.fillRect(hx + 2 * u + i * (hw - 4 * u) / 64, hy + hh - 3 * u - v, (hw - 4 * u) / 64 - 0.4 * u, v); }
    F(9); text('LUMA', hx + 4 * u, hy + 11 * u, 'left', '#9fb');
    const rcx = w - 78 * u, rcy = h - 232 * u, rr = 38 * u; c.strokeStyle = 'rgba(255,255,255,0.8)'; c.lineWidth = 1.3 * u; c.beginPath(); c.arc(rcx, rcy, rr, 0, 6.283); c.stroke(); c.beginPath(); c.arc(rcx, rcy, rr * 0.5, 0, 6.283); c.globalAlpha = 0.4; c.stroke(); c.globalAlpha = 1;
    c.save(); c.translate(rcx, rcy); c.rotate(-t.heading);
    F(10); text('N', 0, -rr + 11 * u, 'center', '#f88'); c.restore();
    c.save(); c.translate(rcx, rcy); c.fillStyle = '#7ef'; c.beginPath(); c.moveTo(0, -9 * u); c.lineTo(6 * u, 7 * u); c.lineTo(0, 3 * u); c.lineTo(-6 * u, 7 * u); c.fill();
    c.rotate(t.homeBearing - t.heading); c.fillStyle = '#fc4'; c.beginPath(); c.arc(0, -rr * 0.72, 4 * u, 0, 6.283); c.fill(); c.restore();
    // ---- left info
    F(12); const info = [t.lensName, t.airframe, `AUDIO: ${t.audio}`, `${t.fps.toFixed(0)} fps sensor`]; info.forEach((s, i) => text(s, m, 62 * u + i * 16 * u, 'left', 'rgba(255,255,255,0.85)'));
    if (t.mission.length) { F(13, true); t.mission.forEach((s, i) => text(s, m, 62 * u + 84 * u + i * 17 * u, 'left', i === 0 ? '#ffe14d' : '#fff')); }
    if (t.eco) { F(12); text(t.eco, m, h - 70 * u, 'left', '#9f9'); }
    if (t.crashed) { F(30, true); text(t.crashed.toUpperCase(), cx, cy - 60 * u, 'center', '#ff5555'); F(15); text('PRESS R TO RESET', cx, cy - 34 * u, 'center'); }
    if (t.rfDbm < -85) { F(16, true); text('VIDEO LINK WEAK', cx, 70 * u, 'center', '#ff7766'); }
    if (t.battPct < 15) { F(16, true); text('LOW BATTERY — LAND NOW', cx, 92 * u, 'center', '#ff7766'); }
    c.restore();
  }
}

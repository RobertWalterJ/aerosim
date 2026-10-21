import type { Sticks, FlightMode } from '../physics/FlightControllerPID';
import { clamp } from '../util/math';
import type { TouchControls } from '../ui/TouchControls';

export interface InputEvents { onMode?(m: FlightMode): void; onAudio?(): void; onLens?(): void; onOSD?(): void; onReset?(): void; onChase?(): void; onAirframe?(): void; onSun?(d: number): void; onPhoto?(): void; onFps?(): void; onEv?(d: number): void; onQuality?(): void; onBloom?(): void }

/** Keyboard + mouse virtual stick + Gamepad API (RC transmitters appear as HID gamepads). */
export class InputManagerHID {
  sticks: Sticks = { throttle: 0, yaw: 0, pitch: 0, roll: 0 };
  gimbalCmd = -20 * Math.PI / 180;     // absolute (horizon) pitch, radians
  usingPad = false; mouseStick = false; touch: TouchControls | null = null;
  private keys = new Set<string>(); private mx = 0; private my = 0;
  private kb = { throttle: 0, yaw: 0, pitch: 0, roll: 0 };
  private wheel = 0;
  constructor(private el: HTMLElement, private ev: InputEvents) {
    addEventListener('keydown', e => this.key(e, true)); addEventListener('keyup', e => this.key(e, false));
    el.addEventListener('mousemove', e => { const r = el.getBoundingClientRect(); this.mx = ((e.clientX - r.left) / r.width) * 2 - 1; this.my = ((e.clientY - r.top) / r.height) * 2 - 1; });
    el.addEventListener('wheel', e => { this.wheel += -Math.sign(e.deltaY); e.preventDefault(); }, { passive: false });
    el.addEventListener('mousedown', e => { if (e.button === 0) this.mouseStick = true; }); addEventListener('mouseup', () => { this.mouseStick = false; });
  }
  private key(e: KeyboardEvent, down: boolean) {
    const k = e.key.length === 1 ? e.key.toLowerCase() : e.key;
    if (down) {
      if (!e.repeat) {
        if (k === '1') this.ev.onMode?.('N'); else if (k === '2') this.ev.onMode?.('S'); else if (k === '3') this.ev.onMode?.('M');
        else if (k === 'v') this.ev.onAudio?.(); else if (k === 'l') this.ev.onLens?.(); else if (k === 'h') this.ev.onOSD?.(); else if (k === 'r') this.ev.onReset?.();
        else if (k === 'c') this.ev.onChase?.(); else if (k === 'f') this.ev.onAirframe?.(); else if (k === 'p') this.ev.onPhoto?.(); else if (k === 'g') this.ev.onFps?.(); else if (k === 'b') this.ev.onBloom?.();
        else if (k === '[') this.ev.onSun?.(-2); else if (k === ']') this.ev.onSun?.(2); else if (k === '-') this.ev.onEv?.(-0.33); else if (k === '=') this.ev.onEv?.(0.33); else if (k === 'u') this.ev.onQuality?.();
      }
      this.keys.add(k);
      if (k.startsWith('Arrow') || k === ' ') e.preventDefault();
    } else this.keys.delete(k);
  }
  poll(dt: number): Sticks {
    const K = this.keys, kb = this.kb;
    const axis = (cur: number, pos: boolean, neg: boolean, rate: number, ret: number) => {
      const tgt = (pos ? 1 : 0) - (neg ? 1 : 0);
      if (tgt !== 0) return clamp(cur + Math.sign(tgt - cur) * rate * dt, -1, 1) ;
      return Math.abs(cur) < ret * dt ? 0 : cur - Math.sign(cur) * ret * dt;
    };
    kb.throttle = axis(kb.throttle, K.has('w'), K.has('s'), 3.2, 5);
    kb.yaw = axis(kb.yaw, K.has('d'), K.has('a'), 3.5, 6);
    kb.pitch = axis(kb.pitch, K.has('ArrowUp'), K.has('ArrowDown'), 4, 6);
    kb.roll = axis(kb.roll, K.has('ArrowRight'), K.has('ArrowLeft'), 4, 6);
    let t = kb.throttle, y = kb.yaw, p = kb.pitch, r = kb.roll;
    if (this.mouseStick) { r = clamp(this.mx * 1.4, -1, 1); p = clamp(-this.my * 1.4, -1, 1); }
    // gamepad / RC transmitter (raw, un-deadzoned axes; mode 2)
    const pads = navigator.getGamepads ? Array.from(navigator.getGamepads()).filter(Boolean) as Gamepad[] : [];
    this.usingPad = pads.length > 0;
    if (pads.length) {
      const g = pads[0];
      if (g.mapping === 'standard') { y = g.axes[0] ?? 0; t = -(g.axes[1] ?? 0); r = g.axes[2] ?? 0; p = -(g.axes[3] ?? 0); const lt = g.buttons[6]?.value ?? 0, rt = g.buttons[7]?.value ?? 0; this.gimbalCmd = clamp(this.gimbalCmd + (rt - lt) * 0.9 * dt, -Math.PI / 2, 20 * Math.PI / 180); }
      else { r = g.axes[0] ?? 0; p = -(g.axes[1] ?? 0); t = -(g.axes[2] ?? 0); y = g.axes[3] ?? 0; if (g.axes[4] !== undefined) this.gimbalCmd = clamp(-Math.PI / 4 + g.axes[4] * (Math.PI / 2.4), -Math.PI / 2, 20 * Math.PI / 180); }
    }
    if (K.has('q')) this.gimbalCmd = clamp(this.gimbalCmd + 0.7 * dt, -Math.PI / 2, 20 * Math.PI / 180);
    if (K.has('e')) this.gimbalCmd = clamp(this.gimbalCmd - 0.7 * dt, -Math.PI / 2, 20 * Math.PI / 180);
    if (this.wheel) { this.gimbalCmd = clamp(this.gimbalCmd + this.wheel * 0.05, -Math.PI / 2, 20 * Math.PI / 180); this.wheel = 0; }
    if (this.touch) {
      const ts = this.touch.state;
      if (ts.active) { t = clamp(t + ts.throttle, -1, 1); y = clamp(y + ts.yaw, -1, 1); p = clamp(p + ts.pitch, -1, 1); r = clamp(r + ts.roll, -1, 1); }
      const g = this.touch.takeGimbal(); if (g !== null) this.gimbalCmd = g;
    }
    this.sticks.throttle = t; this.sticks.yaw = y; this.sticks.pitch = p; this.sticks.roll = r;
    return this.sticks;
  }
}

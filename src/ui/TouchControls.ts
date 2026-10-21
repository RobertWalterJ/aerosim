import { clamp } from '../util/math';

export interface TouchActions {
  mode(): string; cycleMode(): void; chase(): void; photo(): void; reset(): void; lens(): void;
  osd(): void; audio(): void; fps(): void; fullscreen(): void; install?(): void;
}

export interface TouchState { active: boolean; throttle: number; yaw: number; pitch: number; roll: number; gimbalCmd: number | null }

const GIMBAL_MIN = -Math.PI / 2, GIMBAL_MAX = 20 * Math.PI / 180;

/** True on phones and tablets (coarse primary pointer) or when forced with ?touch=1. */
export function isTouchDevice(params: URLSearchParams): boolean {
  if (params.get('touch') === '0') return false;
  if (params.get('touch') === '1') return true;
  return matchMedia('(pointer: coarse)').matches || navigator.maxTouchPoints > 1 && /Android|iPhone|iPad|Mobile/i.test(navigator.userAgent);
}

/**
 * Floating dual-stick overlay (Mode 2 layout, like an RC transmitter).
 * Left thumb: throttle (up/down) and yaw (left/right). The stick springs to centre, so
 * throttle is a climb-rate command, the same as the keyboard.
 * Right thumb: pitch (up = forward) and roll (left/right).
 * Far right slider: camera gimbal tilt. Top row: action buttons.
 */
export class TouchControls {
  state: TouchState = { active: false, throttle: 0, yaw: 0, pitch: 0, roll: 0, gimbalCmd: null };
  private root: HTMLDivElement;
  private sticks = new Map<number, { side: 'L' | 'R'; ox: number; oy: number; base: HTMLDivElement; knob: HTMLDivElement }>();
  private gimbalEl!: HTMLDivElement; private gimbalKnob!: HTMLDivElement; private gimbalPointer = -1;
  private modeBtn!: HTMLButtonElement; private installBtn?: HTMLButtonElement; private crashBtn!: HTMLButtonElement;
  private radius = 62;

  constructor(private actions: TouchActions) {
    const css = document.createElement('style');
    css.textContent = `
      #touch{position:fixed;inset:0;z-index:3;touch-action:none;user-select:none;-webkit-user-select:none;-webkit-touch-callout:none;pointer-events:none}
      #touch .zone{position:absolute;top:18%;bottom:0;pointer-events:auto;touch-action:none}
      #touch .zone.L{left:0;width:42%}#touch .zone.R{right:64px;width:42%}
      #touch .hint{position:absolute;bottom:56px;opacity:.32;font:11px ui-monospace,Menlo,Consolas,monospace;color:#dfe;letter-spacing:.12em;pointer-events:none}
      #touch .zone.L .hint{left:36px}#touch .zone.R .hint{right:36px}
      #touch .base{position:fixed;border-radius:50%;border:2px solid rgba(220,255,240,.45);background:rgba(10,20,24,.22);pointer-events:none;transform:translate(-50%,-50%)}
      #touch .knob{position:absolute;left:50%;top:50%;width:46%;height:46%;border-radius:50%;background:rgba(220,255,240,.5);border:2px solid rgba(255,255,255,.7);transform:translate(-50%,-50%)}
      #touch .gimbal{position:absolute;right:10px;top:26%;height:48%;width:44px;border-radius:22px;border:2px solid rgba(220,255,240,.4);background:rgba(10,20,24,.25);pointer-events:auto;touch-action:none}
      #touch .gimbal .gk{position:absolute;left:50%;width:34px;height:34px;margin-left:-17px;margin-top:-17px;border-radius:50%;background:rgba(220,255,240,.55);border:2px solid #fff}
      #touch .gimbal .gl{position:absolute;left:0;right:0;text-align:center;font:9px ui-monospace,monospace;color:#dfe;opacity:.6;pointer-events:none}
      #touch .row{position:absolute;top:32px;left:50%;transform:translateX(-50%);display:flex;gap:6px;pointer-events:auto;flex-wrap:wrap;justify-content:center;max-width:92vw;gap:4px}
      #touch button{font:600 10px ui-monospace,Menlo,Consolas,monospace;letter-spacing:.04em;color:#dfe;background:rgba(10,20,24,.55);border:1px solid rgba(220,255,240,.4);border-radius:7px;padding:7px 8px;min-width:0;touch-action:manipulation}
      #touch .crashreset{position:absolute;left:50%;top:58%;transform:translateX(-50%);display:none;pointer-events:auto;font-size:18px;padding:16px 34px;border-radius:14px;color:#fff;background:rgba(200,40,40,.85);border:2px solid #fff;letter-spacing:.1em}
      #touch .crashreset.show{display:block}
      #touch button:active{background:rgba(120,230,255,.35)}
    `;
    document.head.appendChild(css);
    const root = this.root = document.createElement('div'); root.id = 'touch';
    root.innerHTML = `
      <div class="zone L"><div class="hint">THROTTLE / YAW</div></div>
      <div class="zone R"><div class="hint">PITCH / ROLL</div></div>
      <div class="gimbal"><div class="gl" style="top:6px">UP</div><div class="gl" style="bottom:6px">DOWN</div><div class="gk"></div></div>
      <div class="row"></div>`;
    document.body.appendChild(root);
    this.gimbalEl = root.querySelector('.gimbal') as HTMLDivElement; this.gimbalKnob = root.querySelector('.gk') as HTMLDivElement;
    const row = root.querySelector('.row') as HTMLDivElement;
    const btn = (label: string, fn: () => void) => { const b = document.createElement('button'); b.textContent = label; b.addEventListener('click', e => { e.stopPropagation(); fn(); }); b.addEventListener('pointerdown', e => e.stopPropagation()); row.appendChild(b); return b; };
    const cr = this.crashBtn = document.createElement('button'); cr.className = 'crashreset'; cr.textContent = 'RESET';
    cr.addEventListener('click', e => { e.stopPropagation(); actions.reset(); }); cr.addEventListener('pointerdown', e => e.stopPropagation()); root.appendChild(cr);
    this.modeBtn = btn('MODE ' + actions.mode(), () => { actions.cycleMode(); this.modeBtn.textContent = 'MODE ' + actions.mode(); });
    btn('CAM', actions.chase); btn('PHOTO', actions.photo); // lens, reset, display, sound, frame rate and full screen live in the pause window
    if (actions.install) { this.installBtn = btn('INSTALL', actions.install); this.installBtn.style.display = 'none'; }

    for (const side of ['L', 'R'] as const) {
      const z = root.querySelector('.zone.' + side) as HTMLDivElement;
      z.addEventListener('pointerdown', e => this.down(e, side, z));
    }
    addEventListener('pointermove', e => this.move(e)); addEventListener('pointerup', e => this.up(e)); addEventListener('pointercancel', e => this.up(e));
    this.gimbalEl.addEventListener('pointerdown', e => { this.gimbalPointer = e.pointerId; this.gimbalEl.setPointerCapture(e.pointerId); this.gimbalSet(e.clientY); });
    this.gimbalEl.addEventListener('pointermove', e => { if (e.pointerId === this.gimbalPointer) this.gimbalSet(e.clientY); });
    const gEnd = (e: PointerEvent) => { if (e.pointerId === this.gimbalPointer) this.gimbalPointer = -1; };
    this.gimbalEl.addEventListener('pointerup', gEnd); this.gimbalEl.addEventListener('pointercancel', gEnd);
    for (const ev of ['contextmenu', 'gesturestart', 'dblclick']) addEventListener(ev, e => e.preventDefault());
    root.addEventListener('touchmove', e => e.preventDefault(), { passive: false });
    this.syncGimbal(-20 * Math.PI / 180);
    const sizeIt = () => { this.radius = clamp(Math.min(innerWidth, innerHeight) * 0.17, 46, 90); }; sizeIt(); addEventListener('resize', sizeIt);
  }

  /** Show the install button once the browser says the app can be installed. */
  setInstallAvailable(on: boolean) { if (this.installBtn) this.installBtn.style.display = on ? '' : 'none'; }
  /** Show the large RESET button while the drone is crashed or disarmed. */
  setCrashed(on: boolean) { this.crashBtn.classList.toggle('show', on); }
  refreshMode() { this.modeBtn.textContent = 'MODE ' + this.actions.mode(); }
  syncGimbal(cmd: number) { const f = (GIMBAL_MAX - cmd) / (GIMBAL_MAX - GIMBAL_MIN); this.gimbalKnob.style.top = (f * 100).toFixed(1) + '%'; }
  /** Called each frame: returns a new gimbal command once when the slider moved, else null. */
  takeGimbal(): number | null { const g = this.state.gimbalCmd; this.state.gimbalCmd = null; return g; }

  private gimbalSet(clientY: number) {
    const r = this.gimbalEl.getBoundingClientRect(); const f = clamp((clientY - r.top) / r.height, 0, 1);
    this.state.gimbalCmd = GIMBAL_MAX - f * (GIMBAL_MAX - GIMBAL_MIN); this.gimbalKnob.style.top = (f * 100).toFixed(1) + '%';
  }
  private down(e: PointerEvent, side: 'L' | 'R', zone: HTMLElement) {
    for (const s of this.sticks.values()) if (s.side === side) return;
    e.preventDefault(); (zone as HTMLElement).setPointerCapture?.(e.pointerId);
    const base = document.createElement('div'); base.className = 'base'; const d = this.radius * 2;
    base.style.cssText = `left:${e.clientX}px;top:${e.clientY}px;width:${d}px;height:${d}px`;
    const knob = document.createElement('div'); knob.className = 'knob'; base.appendChild(knob); this.root.appendChild(base);
    this.sticks.set(e.pointerId, { side, ox: e.clientX, oy: e.clientY, base, knob });
    this.state.active = true;
  }
  private move(e: PointerEvent) {
    const s = this.sticks.get(e.pointerId); if (!s) return;
    let dx = (e.clientX - s.ox) / this.radius, dy = (e.clientY - s.oy) / this.radius; const m = Math.hypot(dx, dy);
    if (m > 1) { dx /= m; dy /= m; }
    s.knob.style.transform = `translate(calc(-50% + ${dx * this.radius}px), calc(-50% + ${dy * this.radius}px))`;
    const shape = (v: number) => { const a = Math.abs(v); const dz = 0.06; if (a < dz) return 0; const n = (a - dz) / (1 - dz); return Math.sign(v) * (0.35 * n + 0.65 * n * n * n); };
    if (s.side === 'L') { this.state.yaw = shape(dx); this.state.throttle = shape(-dy); } else { this.state.roll = shape(dx); this.state.pitch = shape(-dy); }
  }
  private up(e: PointerEvent) {
    const s = this.sticks.get(e.pointerId); if (!s) return;
    s.base.remove(); this.sticks.delete(e.pointerId);
    if (s.side === 'L') { this.state.yaw = 0; this.state.throttle = 0; } else { this.state.roll = 0; this.state.pitch = 0; }
    this.state.active = this.sticks.size > 0 || this.state.active;
  }
}

export interface Weather { windMs: number; gust: number; windFromDeg: number; sunEl: number }

export const DEFAULT_WEATHER: Weather = { windMs: 3, gust: 0.65, windFromDeg: 250, sunEl: 14 };

const KEY = 'aerosim-weather';
const PRESETS: { name: string; windMs: number; gust: number }[] = [
  { name: 'Calm', windMs: 0.5, gust: 0.3 }, { name: 'Light', windMs: 3, gust: 0.65 },
  { name: 'Breezy', windMs: 5, gust: 0.85 }, { name: 'Strong', windMs: 7.5, gust: 1 },
];
const COMPASS = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

/** Weather as saved on this device; falls back to the defaults if storage is missing or damaged. */
export function loadWeather(): Weather {
  try {
    const raw = JSON.parse(localStorage.getItem(KEY) || 'null');
    if (raw && typeof raw === 'object') {
      const n = (v: unknown, d: number, lo: number, hi: number) => (typeof v === 'number' && isFinite(v) ? Math.min(hi, Math.max(lo, v)) : d);
      return { windMs: n(raw.windMs, DEFAULT_WEATHER.windMs, 0, 10), gust: n(raw.gust, DEFAULT_WEATHER.gust, 0, 1), windFromDeg: n(raw.windFromDeg, DEFAULT_WEATHER.windFromDeg, 0, 359), sunEl: n(raw.sunEl, DEFAULT_WEATHER.sunEl, 4, 40) };
    }
  } catch { /* storage unavailable */ }
  return { ...DEFAULT_WEATHER };
}

const windWord = (ms: number) => ms < 1.5 ? 'Calm' : ms < 4 ? 'Light' : ms < 6.5 ? 'Breezy' : 'Strong';
const sunWord = (el: number) => el < 8 ? 'Sunset glow' : el < 18 ? 'Late afternoon' : el < 30 ? 'Afternoon' : 'Midday';

/**
 * A menu window with a floating MENU button (and the Escape key). Holds the weather settings:
 * wind speed, gustiness, wind direction and sun height. Changes apply live and are saved on the device.
 */
export class SettingsMenu {
  private panel: HTMLDivElement;
  private weather: Weather;
  private inputs: Record<string, HTMLInputElement> = {};
  private labels: Record<string, HTMLElement> = {};

  constructor(private apply: (w: Weather) => void) {
    this.weather = loadWeather();
    const css = document.createElement('style');
    css.textContent = `
      #menuBtn{position:fixed;top:6px;right:6px;z-index:5;font:600 12px ui-monospace,Menlo,Consolas,monospace;letter-spacing:.06em;color:#dfe;background:rgba(10,20,24,.6);border:1px solid rgba(220,255,240,.45);border-radius:8px;padding:9px 12px;touch-action:manipulation}
      #menuPanel{position:fixed;inset:0;z-index:9;display:none;align-items:center;justify-content:center;background:rgba(4,8,10,.55);touch-action:none}
      #menuPanel.open{display:flex}
      #menuPanel .win{width:min(520px,94vw);max-height:92vh;overflow:auto;background:rgba(12,22,26,.96);border:1px solid rgba(220,255,240,.4);border-radius:14px;padding:16px 18px;color:#e8fff4;font:16px/1.4 system-ui,Segoe UI,Roboto,sans-serif;touch-action:pan-y}
      #menuPanel h2{margin:0 0 4px;font-size:20px} #menuPanel h3{margin:14px 0 6px;font-size:13px;letter-spacing:.14em;text-transform:uppercase;color:#9fd}
      #menuPanel .row{display:flex;justify-content:space-between;gap:10px;margin-top:10px} #menuPanel .val{color:#fff;font-weight:600}
      #menuPanel input[type=range]{width:100%;height:36px;accent-color:#7fe}
      #menuPanel .presets{display:flex;gap:8px;flex-wrap:wrap;margin-top:6px}
      #menuPanel button{font:600 15px system-ui,Segoe UI,Roboto,sans-serif;color:#e8fff4;background:rgba(40,70,76,.8);border:1px solid rgba(220,255,240,.4);border-radius:10px;padding:11px 14px;min-height:44px;touch-action:manipulation}
      #menuPanel button:active{background:rgba(120,230,255,.35)}
      #menuPanel .foot{display:flex;gap:10px;justify-content:space-between;margin-top:16px} #menuPanel .close{background:rgba(30,120,90,.9)}
    `;
    document.head.appendChild(css);
    const btn = document.createElement('button'); btn.id = 'menuBtn'; btn.textContent = 'MENU';
    btn.addEventListener('click', e => { e.stopPropagation(); this.toggle(); }); btn.addEventListener('pointerdown', e => e.stopPropagation());
    document.body.appendChild(btn);
    const p = this.panel = document.createElement('div'); p.id = 'menuPanel';
    p.innerHTML = `<div class="win" role="dialog" aria-label="Menu">
      <h2>Menu</h2><div>Weather changes apply straight away and are saved on this device.</div>
      <h3>Weather</h3>
      <div class="presets">${PRESETS.map((q, i) => `<button data-preset="${i}">${q.name}</button>`).join('')}</div>
      ${this.slider('windMs', 'Wind speed', 0, 10, 0.1)}${this.slider('gust', 'Gusts', 0, 1, 0.01)}
      ${this.slider('windFromDeg', 'Wind comes from', 0, 359, 1)}${this.slider('sunEl', 'Time of day', 4, 40, 1)}
      <div class="foot"><button data-act="reset">Reset weather</button><button class="close" data-act="close">Close</button></div></div>`;
    document.body.appendChild(p);
    for (const k of ['windMs', 'gust', 'windFromDeg', 'sunEl'] as const) {
      const el = p.querySelector(`[data-k="${k}"]`) as HTMLInputElement; this.inputs[k] = el; this.labels[k] = p.querySelector(`[data-v="${k}"]`) as HTMLElement;
      el.addEventListener('input', () => { this.weather[k] = parseFloat(el.value); this.changed(); });
    }
    p.addEventListener('click', e => {
      const t = e.target as HTMLElement;
      if (t === p || t.dataset.act === 'close') this.toggle(false);
      else if (t.dataset.act === 'reset') { this.weather = { ...DEFAULT_WEATHER }; this.changed(); }
      else if (t.dataset.preset) { const q = PRESETS[+t.dataset.preset]!; this.weather.windMs = q.windMs; this.weather.gust = q.gust; this.changed(); }
    });
    // keep taps and drags inside the window from reaching the flight sticks underneath
    for (const ev of ['pointerdown', 'pointermove', 'pointerup', 'touchstart', 'touchmove']) p.addEventListener(ev, e => e.stopPropagation());
    addEventListener('keydown', e => { if (e.key === 'Escape') { e.preventDefault(); this.toggle(); } });
    this.sync(); this.apply({ ...this.weather });
  }

  private slider(k: string, label: string, min: number, max: number, step: number) {
    return `<div class="row"><span>${label}</span><span class="val" data-v="${k}"></span></div><input type="range" data-k="${k}" min="${min}" max="${max}" step="${step}" aria-label="${label}">`;
  }
  private describe(k: keyof Weather): string {
    const w = this.weather;
    if (k === 'windMs') return `${windWord(w.windMs)}, ${w.windMs.toFixed(1)} m/s`;
    if (k === 'gust') return w.gust < 0.34 ? 'Steady' : w.gust < 0.7 ? 'Some gusts' : 'Gusty';
    if (k === 'windFromDeg') return `${COMPASS[Math.round(w.windFromDeg / 45) % 8]} (${Math.round(w.windFromDeg)}°)`;
    return `${sunWord(w.sunEl)}`;
  }
  private sync() { for (const k of ['windMs', 'gust', 'windFromDeg', 'sunEl'] as const) { this.inputs[k]!.value = String(this.weather[k]); this.labels[k]!.textContent = this.describe(k); } }
  private changed() {
    this.sync(); this.apply({ ...this.weather });
    try { localStorage.setItem(KEY, JSON.stringify(this.weather)); } catch { /* storage unavailable */ }
  }
  get isOpen() { return this.panel.classList.contains('open'); }
  toggle(on = !this.isOpen) { this.panel.classList.toggle('open', on); if (on) this.sync(); }
}

export interface Weather { windMs: number; gust: number; windFromDeg: number; sunEl: number; snow: number }

/** snow: 0 = clear, 1 = light snow, 2 = heavy snow */
export const DEFAULT_WEATHER: Weather = { windMs: 1, gust: 0.45, windFromDeg: 250, sunEl: 14, snow: 0 };

/** One button in the pause window. `value` is the live state shown on the right of the label. */
export interface MenuItem { label: string; value?: () => string; run: () => void; show?: () => boolean }

const KEY = 'aerosim-weather';
const PRESETS: { name: string; windMs: number; gust: number }[] = [
  { name: 'Still', windMs: 0, gust: 0 }, { name: 'Calm', windMs: 1, gust: 0.45 }, { name: 'Light', windMs: 3, gust: 0.65 },
  { name: 'Breezy', windMs: 5, gust: 0.85 }, { name: 'Strong', windMs: 7.5, gust: 1 },
];
const SNOW = ['Clear', 'Light snow', 'Heavy snow'];
const COMPASS = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
const SLIDERS: { k: 'windMs' | 'gust' | 'windFromDeg' | 'sunEl'; label: string; min: number; max: number; step: number }[] = [
  { k: 'windMs', label: 'Wind speed', min: 0, max: 10, step: 0.1 }, { k: 'gust', label: 'Gusts', min: 0, max: 1, step: 0.01 },
  { k: 'windFromDeg', label: 'Wind comes from', min: 0, max: 359, step: 1 }, { k: 'sunEl', label: 'Time of day', min: 4, max: 40, step: 1 },
];

/** Weather as saved on this device; falls back to the defaults if storage is missing or damaged. */
export function loadWeather(): Weather {
  try {
    const raw = JSON.parse(localStorage.getItem(KEY) || 'null');
    if (raw && typeof raw === 'object') {
      const n = (v: unknown, d: number, lo: number, hi: number) => (typeof v === 'number' && isFinite(v) ? Math.min(hi, Math.max(lo, v)) : d);
      const D = DEFAULT_WEATHER;
      return { windMs: n(raw.windMs, D.windMs, 0, 10), gust: n(raw.gust, D.gust, 0, 1), windFromDeg: n(raw.windFromDeg, D.windFromDeg, 0, 359), sunEl: n(raw.sunEl, D.sunEl, 4, 40), snow: Math.round(n(raw.snow, D.snow, 0, 2)) };
    }
  } catch { /* storage unavailable */ }
  return { ...DEFAULT_WEATHER };
}

const windWord = (ms: number) => ms < 0.3 ? 'Still' : ms < 2 ? 'Calm' : ms < 4 ? 'Light' : ms < 6.5 ? 'Breezy' : 'Strong';
const sunWord = (el: number) => el < 8 ? 'Sunset glow' : el < 18 ? 'Late afternoon' : el < 30 ? 'Afternoon' : 'Midday';

/**
 * The pause window. A PAUSE button (and the Escape key) opens it and freezes the flight.
 * It holds the controls that do not need to be in reach mid-flight (lens, sound, display, frame rate,
 * reset) and the weather: wind speed, gusts, wind direction, time of day and snow.
 * Weather changes apply live and are saved on the device.
 */
export class SettingsMenu {
  private panel: HTMLDivElement;
  private weather: Weather;
  private inputs: Record<string, HTMLInputElement> = {};
  private labels: Record<string, HTMLElement> = {};
  private itemEls: { el: HTMLButtonElement; item: MenuItem }[] = [];

  constructor(private apply: (w: Weather) => void, items: MenuItem[], private onPause: (paused: boolean) => void) {
    this.weather = loadWeather();
    const css = document.createElement('style');
    css.textContent = `
      #menuBtn{position:fixed;top:max(8px,env(safe-area-inset-top));right:max(8px,env(safe-area-inset-right));z-index:20;font:700 14px ui-monospace,Menlo,Consolas,monospace;letter-spacing:.08em;color:#fff;background:rgba(10,20,24,.72);border:2px solid rgba(220,255,240,.7);border-radius:10px;padding:10px 14px;min-height:44px;touch-action:manipulation}
      #menuPanel{position:fixed;inset:0;z-index:30;display:none;align-items:center;justify-content:center;background:rgba(4,8,10,.6);touch-action:none}
      #menuPanel.open{display:flex}
      #menuPanel .win{width:min(560px,94vw);max-height:94vh;overflow:auto;background:rgba(12,22,26,.97);border:1px solid rgba(220,255,240,.4);border-radius:14px;padding:16px 18px;color:#e8fff4;font:16px/1.4 system-ui,Segoe UI,Roboto,sans-serif;touch-action:pan-y}
      #menuPanel h2{margin:0 0 4px;font-size:22px} #menuPanel h3{margin:16px 0 6px;font-size:13px;letter-spacing:.14em;text-transform:uppercase;color:#9fd}
      #menuPanel .row{display:flex;justify-content:space-between;gap:10px;margin-top:10px} #menuPanel .val{color:#fff;font-weight:600}
      #menuPanel input[type=range]{width:100%;height:36px;accent-color:#7fe}
      #menuPanel .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:8px;margin-top:6px}
      #menuPanel .seg{display:flex;gap:8px;flex-wrap:wrap;margin-top:6px}
      #menuPanel button{font:600 15px system-ui,Segoe UI,Roboto,sans-serif;color:#e8fff4;background:rgba(40,70,76,.8);border:1px solid rgba(220,255,240,.4);border-radius:10px;padding:10px 12px;min-height:46px;touch-action:manipulation;text-align:left}
      #menuPanel button small{display:block;font-weight:400;color:#9fd;font-size:13px}
      #menuPanel button.on{background:rgba(30,120,90,.95);border-color:#fff}
      #menuPanel button:active{background:rgba(120,230,255,.35)}
      #menuPanel .foot{display:flex;gap:10px;justify-content:flex-end;margin-top:16px} #menuPanel .close{background:rgba(30,120,90,.95);text-align:center;min-width:140px}
    `;
    document.head.appendChild(css);
    const btn = document.createElement('button'); btn.id = 'menuBtn'; btn.textContent = 'II  PAUSE'; btn.setAttribute('aria-label', 'Pause and open menu');
    btn.addEventListener('click', e => { e.stopPropagation(); this.toggle(); }); btn.addEventListener('pointerdown', e => e.stopPropagation());
    document.body.appendChild(btn);
    const p = this.panel = document.createElement('div'); p.id = 'menuPanel';
    p.innerHTML = `<div class="win" role="dialog" aria-label="Paused">
      <h2>Paused</h2><div>The flight is stopped. Weather changes are saved on this device.</div>
      <h3>Flight and display</h3><div class="grid" data-items></div>
      <h3>Wind</h3><div class="seg">${PRESETS.map((q, i) => `<button data-preset="${i}">${q.name}</button>`).join('')}</div>
      ${SLIDERS.map(s => `<div class="row"><span>${s.label}</span><span class="val" data-v="${s.k}"></span></div><input type="range" data-k="${s.k}" min="${s.min}" max="${s.max}" step="${s.step}" aria-label="${s.label}">`).join('')}
      <h3>Precipitation</h3><div class="seg">${SNOW.map((n, i) => `<button data-snow="${i}">${n}</button>`).join('')}</div>
      <div class="foot"><button data-act="reset">Reset weather</button><button class="close" data-act="close">Resume</button></div></div>`;
    document.body.appendChild(p);
    const grid = p.querySelector('[data-items]') as HTMLElement;
    for (const item of items) {
      const el = document.createElement('button'); grid.appendChild(el); this.itemEls.push({ el, item });
      el.addEventListener('click', () => { item.run(); this.sync(); });
    }
    for (const s of SLIDERS) {
      const el = p.querySelector(`[data-k="${s.k}"]`) as HTMLInputElement; this.inputs[s.k] = el; this.labels[s.k] = p.querySelector(`[data-v="${s.k}"]`) as HTMLElement;
      el.addEventListener('input', () => { this.weather[s.k] = parseFloat(el.value); this.changed(); });
    }
    p.addEventListener('click', e => {
      const t = (e.target as HTMLElement).closest('button') as HTMLElement | null;
      if (e.target === p || t?.dataset.act === 'close') this.toggle(false);
      else if (t?.dataset.act === 'reset') { this.weather = { ...DEFAULT_WEATHER }; this.changed(); }
      else if (t?.dataset.preset) { const q = PRESETS[+t.dataset.preset]!; this.weather.windMs = q.windMs; this.weather.gust = q.gust; this.changed(); }
      else if (t?.dataset.snow) { this.weather.snow = +t.dataset.snow; this.changed(); }
    });
    // keep taps and drags inside the window from reaching the flight sticks underneath
    for (const ev of ['pointerdown', 'pointermove', 'pointerup', 'touchstart', 'touchmove']) p.addEventListener(ev, e => e.stopPropagation());
    addEventListener('keydown', e => { if (e.key === 'Escape') { e.preventDefault(); this.toggle(); } });
    this.sync(); this.apply({ ...this.weather });
  }

  private describe(k: keyof Weather): string {
    const w = this.weather;
    if (k === 'windMs') return `${windWord(w.windMs)}, ${w.windMs.toFixed(1)} m/s`;
    if (k === 'gust') return w.gust < 0.34 ? 'Steady' : w.gust < 0.7 ? 'Some gusts' : 'Gusty';
    if (k === 'windFromDeg') return `${COMPASS[Math.round(w.windFromDeg / 45) % 8]} (${Math.round(w.windFromDeg)}°)`;
    return sunWord(w.sunEl);
  }
  private sync() {
    for (const s of SLIDERS) { this.inputs[s.k]!.value = String(this.weather[s.k]); this.labels[s.k]!.textContent = this.describe(s.k); }
    this.panel.querySelectorAll<HTMLElement>('[data-snow]').forEach(b => b.classList.toggle('on', +b.dataset.snow! === this.weather.snow));
    for (const { el, item } of this.itemEls) {
      el.style.display = item.show && !item.show() ? 'none' : '';
      el.innerHTML = item.value ? `${item.label}<small>${item.value()}</small>` : item.label;
    }
  }
  private changed() {
    this.sync(); this.apply({ ...this.weather });
    try { localStorage.setItem(KEY, JSON.stringify(this.weather)); } catch { /* storage unavailable */ }
  }
  /** Redraw the button labels after something changed outside the window. */
  refresh() { this.sync(); }
  get isOpen() { return this.panel.classList.contains('open'); }
  toggle(on = !this.isOpen) { this.panel.classList.toggle('open', on); if (on) this.sync(); this.onPause(on); }
}

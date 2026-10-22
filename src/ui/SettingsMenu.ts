export interface Weather { windMs: number; gust: number; windFromDeg: number; sunEl: number; snow: number }

/** snow: 0 = clear, 1 = light snow, 2 = heavy snow */
export const DEFAULT_WEATHER: Weather = { windMs: 1, gust: 0.45, windFromDeg: 250, sunEl: 14, snow: 0 };

/** A row of choices (one is always selected) or a single action button. `value` is the live state shown under an action's label. */
export type Widget =
  | { type: 'choice'; label: string; options: string[]; get: () => number; set: (i: number) => void }
  | { type: 'action'; label: string; value?: () => string; run: () => void; show?: () => boolean };

/** One drone in the Drone tab. */
export interface DroneCard { name: string; blurb: string; selected: () => boolean; pick: () => void }

export interface MenuSpec { fly: Widget[]; drones: DroneCard[]; display: Widget[] }

const KEY = 'aerosim-weather';
const PRESETS: { name: string; windMs: number; gust: number }[] = [
  { name: 'Still', windMs: 0, gust: 0 }, { name: 'Calm', windMs: 1, gust: 0.45 }, { name: 'Light', windMs: 3, gust: 0.65 },
  { name: 'Breezy', windMs: 5, gust: 0.85 }, { name: 'Strong', windMs: 7.5, gust: 1 },
];
const SNOW = ['Clear', 'Light snow', 'Heavy snow'];
const COMPASS = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
const TABS = ['Fly', 'Drone', 'Weather', 'Display'];
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
 * Four tabs keep each page short enough to fit a phone held sideways:
 *   Fly (mode, camera, lens, reset), Drone (pick an airframe), Weather (wind, time of day, snow), Display (screen and sound).
 * Resume and Peek stay at the bottom on every tab. Hold Peek to fade the window and see the effect of a weather change.
 * Weather changes apply live and are saved on the device.
 */
export class SettingsMenu {
  private panel: HTMLDivElement;
  private weather: Weather;
  private inputs: Record<string, HTMLInputElement> = {};
  private labels: Record<string, HTMLElement> = {};
  private refreshers: (() => void)[] = [];
  private tab = 0;
  private arrow!: SVGElement; private arrowLabel!: HTMLElement;

  constructor(private apply: (w: Weather) => void, spec: MenuSpec, private onPause: (paused: boolean) => void) {
    this.weather = loadWeather();
    const css = document.createElement('style');
    css.textContent = `
      #menuBtn{position:fixed;top:max(8px,env(safe-area-inset-top));right:max(8px,env(safe-area-inset-right));z-index:20;font:700 14px ui-monospace,Menlo,Consolas,monospace;letter-spacing:.08em;color:#fff;background:rgba(10,20,24,.72);border:2px solid rgba(220,255,240,.7);border-radius:10px;padding:10px 14px;min-height:44px;touch-action:manipulation}
      #menuPanel{position:fixed;inset:0;z-index:30;display:none;align-items:center;justify-content:center;background:rgba(4,8,10,.6);touch-action:none;padding:max(8px,env(safe-area-inset-top)) max(8px,env(safe-area-inset-right)) max(8px,env(safe-area-inset-bottom)) max(8px,env(safe-area-inset-left))}
      #menuPanel.open{display:flex} #menuPanel.peek{background:transparent}
      #menuPanel .win{width:min(640px,100%);max-height:100%;display:flex;flex-direction:column;background:rgba(12,22,26,.97);border:1px solid rgba(220,255,240,.4);border-radius:14px;color:#e8fff4;font:16px/1.4 system-ui,Segoe UI,Roboto,sans-serif;overflow:hidden}
      #menuPanel.peek .win{background:transparent;border-color:transparent}
      #menuPanel.peek .tabs,#menuPanel.peek .body{opacity:.06;pointer-events:none}
      #menuPanel .tabs{display:flex;gap:6px;padding:10px 12px 0} #menuPanel .tabs button{flex:1;text-align:center;border-radius:10px 10px 0 0;min-height:44px}
      #menuPanel .body{flex:1;min-height:0;overflow:auto;padding:12px 16px;touch-action:pan-y;border-top:1px solid rgba(220,255,240,.25)}
      #menuPanel .pane{display:none} #menuPanel .pane.on{display:block}
      #menuPanel h3{margin:14px 0 6px;font-size:13px;letter-spacing:.14em;text-transform:uppercase;color:#9fd} #menuPanel h3:first-child{margin-top:0}
      #menuPanel .row{display:flex;justify-content:space-between;gap:10px;margin-top:10px} #menuPanel .val{color:#fff;font-weight:600}
      #menuPanel input[type=range]{width:100%;height:36px;accent-color:#7fe}
      #menuPanel .skybar{height:8px;border-radius:4px;margin-top:2px;background:linear-gradient(90deg,#ff8a4d,#ffd7a0 40%,#bfe3ff)}
      #menuPanel .seg{display:flex;gap:8px;flex-wrap:wrap;margin-top:6px} #menuPanel .seg button{flex:1;min-width:84px;text-align:center}
      #menuPanel .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:8px;margin-top:6px}
      #menuPanel .wx{display:flex;gap:14px;align-items:center;margin-top:10px} #menuPanel .wx svg{flex:none}
      #menuPanel button{font:600 15px system-ui,Segoe UI,Roboto,sans-serif;color:#e8fff4;background:rgba(40,70,76,.8);border:1px solid rgba(220,255,240,.4);border-radius:10px;padding:10px 12px;min-height:46px;touch-action:manipulation;text-align:left}
      #menuPanel button small{display:block;font-weight:400;color:#bfe;font-size:13px;line-height:1.3}
      #menuPanel button.on{background:rgba(30,120,90,.95);border-color:#fff}
      #menuPanel button:active{background:rgba(120,230,255,.35)}
      #menuPanel .foot{display:flex;gap:10px;justify-content:space-between;padding:10px 16px;border-top:1px solid rgba(220,255,240,.25);background:rgba(12,22,26,.97)}
      #menuPanel.peek .foot{background:transparent;border-top-color:transparent}
      #menuPanel .foot .go{background:rgba(30,120,90,.95);text-align:center;min-width:150px}
      @media (max-height:430px){#menuPanel .tabs button,#menuPanel button{min-height:40px;padding:6px 10px}#menuPanel .body{padding:8px 14px}}
    `;
    document.head.appendChild(css);
    const btn = document.createElement('button'); btn.id = 'menuBtn'; btn.textContent = 'II  PAUSE'; btn.setAttribute('aria-label', 'Pause and open menu');
    btn.addEventListener('click', e => { e.stopPropagation(); this.toggle(); }); btn.addEventListener('pointerdown', e => e.stopPropagation());
    document.body.appendChild(btn);

    const p = this.panel = document.createElement('div'); p.id = 'menuPanel';
    p.innerHTML = `<div class="win" role="dialog" aria-label="Paused">
      <div class="tabs">${TABS.map((t, i) => `<button data-tab="${i}">${t}</button>`).join('')}</div>
      <div class="body">
        <div class="pane" data-pane="0"></div>
        <div class="pane" data-pane="1"></div>
        <div class="pane" data-pane="2">
          <h3>Wind</h3><div class="seg">${PRESETS.map((q, i) => `<button data-preset="${i}">${q.name}</button>`).join('')}</div>
          <div class="wx"><svg width="76" height="76" viewBox="-38 -38 76 76" aria-hidden="true"><circle r="35" fill="rgba(40,70,76,.6)" stroke="rgba(220,255,240,.5)" stroke-width="2"/><text y="-23" text-anchor="middle" font-size="10" fill="#9fd">N</text><g data-arrow><path d="M0 -24 L9 6 L0 0 L-9 6 Z" fill="#fff"/></g></svg><div><div class="val" data-arrowlabel></div><div>The arrow shows where the wind blows to.</div></div></div>
          ${SLIDERS.slice(0, 3).map(s => this.sliderHtml(s)).join('')}
          <h3>Time of day</h3><div class="skybar"></div>${this.sliderHtml(SLIDERS[3]!)}
          <h3>Precipitation</h3><div class="seg">${SNOW.map((n, i) => `<button data-snow="${i}">${n}</button>`).join('')}</div>
          <div class="seg"><button data-act="reset">Reset weather</button></div>
        </div>
        <div class="pane" data-pane="3"></div>
      </div>
      <div class="foot"><button data-act="peek" aria-label="Hold to see the scene">Hold to peek</button><button class="go" data-act="close">Resume</button></div></div>`;
    document.body.appendChild(p);
    this.arrow = p.querySelector('[data-arrow]') as SVGElement; this.arrowLabel = p.querySelector('[data-arrowlabel]') as HTMLElement;

    this.fillWidgets(p.querySelector('[data-pane="0"]') as HTMLElement, spec.fly);
    this.fillDrones(p.querySelector('[data-pane="1"]') as HTMLElement, spec.drones);
    this.fillWidgets(p.querySelector('[data-pane="3"]') as HTMLElement, spec.display);
    for (const s of SLIDERS) {
      const el = p.querySelector(`[data-k="${s.k}"]`) as HTMLInputElement; this.inputs[s.k] = el; this.labels[s.k] = p.querySelector(`[data-v="${s.k}"]`) as HTMLElement;
      el.addEventListener('input', () => { this.weather[s.k] = parseFloat(el.value); this.changed(); });
    }
    p.addEventListener('click', e => {
      const t = (e.target as HTMLElement).closest('button') as HTMLElement | null;
      if (e.target === p || t?.dataset.act === 'close') this.toggle(false);
      else if (t?.dataset.tab) { this.tab = +t.dataset.tab; this.sync(); }
      else if (t?.dataset.act === 'reset') { this.weather = { ...DEFAULT_WEATHER }; this.changed(); }
      else if (t?.dataset.preset) { const q = PRESETS[+t.dataset.preset]!; this.weather.windMs = q.windMs; this.weather.gust = q.gust; this.changed(); }
      else if (t?.dataset.snow) { this.weather.snow = +t.dataset.snow; this.changed(); }
    });
    const peek = p.querySelector('[data-act="peek"]') as HTMLElement;
    const peekOn = (on: boolean) => p.classList.toggle('peek', on);
    peek.addEventListener('pointerdown', () => peekOn(true)); for (const ev of ['pointerup', 'pointercancel', 'pointerleave']) peek.addEventListener(ev, () => peekOn(false));
    // keep taps and drags inside the window from reaching the flight sticks underneath
    for (const ev of ['pointerdown', 'pointermove', 'pointerup', 'touchstart', 'touchmove']) p.addEventListener(ev, e => e.stopPropagation());
    addEventListener('keydown', e => { if (e.key === 'Escape') { e.preventDefault(); this.toggle(); } });
    this.sync(); this.apply({ ...this.weather });
  }

  private sliderHtml(s: { k: string; label: string; min: number; max: number; step: number }) {
    return `<div class="row"><span>${s.label}</span><span class="val" data-v="${s.k}"></span></div><input type="range" data-k="${s.k}" min="${s.min}" max="${s.max}" step="${s.step}" aria-label="${s.label}">`;
  }

  private fillWidgets(pane: HTMLElement, widgets: Widget[]) {
    const actions = document.createElement('div'); actions.className = 'grid';
    for (const w of widgets) {
      if (w.type === 'choice') {
        const h = document.createElement('h3'); h.textContent = w.label; const seg = document.createElement('div'); seg.className = 'seg';
        const bs = w.options.map((o, i) => { const b = document.createElement('button'); b.textContent = o; b.addEventListener('click', () => { w.set(i); this.sync(); }); seg.appendChild(b); return b; });
        pane.append(h, seg); this.refreshers.push(() => bs.forEach((b, i) => b.classList.toggle('on', i === w.get())));
      } else {
        const b = document.createElement('button'); actions.appendChild(b);
        b.addEventListener('click', () => { w.run(); this.sync(); });
        this.refreshers.push(() => { b.style.display = w.show && !w.show() ? 'none' : ''; b.innerHTML = w.value ? `${w.label}<small>${w.value()}</small>` : w.label; });
      }
    }
    if (actions.childElementCount) { const h = document.createElement('h3'); h.textContent = 'Actions'; pane.append(h, actions); }
  }

  private fillDrones(pane: HTMLElement, drones: DroneCard[]) {
    const h = document.createElement('h3'); h.textContent = 'Choose a drone. Your drone returns to the start.'; const grid = document.createElement('div'); grid.className = 'grid'; pane.append(h, grid);
    for (const d of drones) {
      const b = document.createElement('button'); b.innerHTML = `${d.name}<small>${d.blurb}</small>`; grid.appendChild(b);
      b.addEventListener('click', () => { if (!d.selected()) d.pick(); this.sync(); });
      this.refreshers.push(() => b.classList.toggle('on', d.selected()));
    }
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
    this.panel.querySelectorAll<HTMLElement>('[data-tab]').forEach(b => b.classList.toggle('on', +b.dataset.tab! === this.tab));
    this.panel.querySelectorAll<HTMLElement>('[data-pane]').forEach(b => b.classList.toggle('on', +b.dataset.pane! === this.tab));
    this.arrow.setAttribute('transform', `rotate(${(this.weather.windFromDeg + 180) % 360})`);
    this.arrowLabel.textContent = `Wind from the ${COMPASS[Math.round(this.weather.windFromDeg / 45) % 8]}, ${windWord(this.weather.windMs).toLowerCase()}`;
    for (const f of this.refreshers) f();
  }
  private changed() {
    this.sync(); this.apply({ ...this.weather });
    try { localStorage.setItem(KEY, JSON.stringify(this.weather)); } catch { /* storage unavailable */ }
  }
  /** Redraw the labels after something changed outside the window. */
  refresh() { this.sync(); }
  get isOpen() { return this.panel.classList.contains('open'); }
  toggle(on = !this.isOpen) { this.panel.classList.toggle('open', on); if (!on) this.panel.classList.remove('peek'); if (on) this.sync(); this.onPause(on); }
}

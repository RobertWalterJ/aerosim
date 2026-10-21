/** Installable web app support: service worker registration and the "add to home screen" prompt. */
interface BIPEvent extends Event { prompt(): Promise<void>; userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }> }

const KEY = 'aerosim-install-dismissed';
const get = (): string | null => { try { return localStorage.getItem(KEY); } catch { return null; } };
const set = (v: string) => { try { localStorage.setItem(KEY, v); } catch { /* ignore */ } };

export function initPWA() {
  let deferred: BIPEvent | null = null; const listeners: ((ok: boolean) => void)[] = []; const listener = (ok: boolean) => listeners.forEach(f => f(ok));
  const standalone = matchMedia('(display-mode: standalone)').matches || matchMedia('(display-mode: fullscreen)').matches || (navigator as any).standalone === true;

  if ('serviceWorker' in navigator && import.meta.env.PROD) {
    const reg = () => navigator.serviceWorker.register('./sw.js').catch(e => console.warn('sw failed', e));
    if (document.readyState === 'complete') reg(); else addEventListener('load', reg);
  }
  addEventListener('beforeinstallprompt', e => { e.preventDefault(); deferred = e as BIPEvent; listener(true); });
  addEventListener('appinstalled', () => { deferred = null; listener(false); set('installed'); banner?.remove(); });

  let banner: HTMLDivElement | null = null;
  const show = (html: string, withButton: boolean) => {
    banner?.remove(); const b = banner = document.createElement('div');
    b.style.cssText = 'position:fixed;left:50%;bottom:18px;transform:translateX(-50%);z-index:9;background:rgba(6,12,16,.92);color:#dfe;border:1px solid #7ef;border-radius:12px;padding:12px 16px;font:13px ui-monospace,Menlo,monospace;display:flex;gap:12px;align-items:center;max-width:92vw';
    b.innerHTML = `<span>${html}</span>`;
    if (withButton) { const i = document.createElement('button'); i.textContent = 'Install'; i.style.cssText = 'background:#7ef;color:#06090c;border:0;border-radius:8px;padding:8px 14px;font:600 13px ui-monospace,monospace'; i.onclick = () => api.promptInstall(); b.appendChild(i); }
    const x = document.createElement('button'); x.textContent = 'Not now'; x.style.cssText = 'background:none;color:#9bb;border:1px solid #567;border-radius:8px;padding:8px 12px;font:13px ui-monospace,monospace'; x.onclick = () => { set(String(Date.now())); b.remove(); }; b.appendChild(x);
    document.body.appendChild(b); setTimeout(() => b.remove(), 20000);
  };
  const api = {
    onInstallable(fn: (ok: boolean) => void) { listeners.push(fn); if (deferred) fn(true); },
    async promptInstall() { if (!deferred) return; const d = deferred; await d.prompt(); const r = await d.userChoice; if (r.outcome === 'accepted') { deferred = null; listener(false); banner?.remove(); } },
    /** Offer the install once per week, never inside the installed app. */
    maybePrompt() {
      if (standalone || get() === 'installed') return; const t = Number(get()); if (t && Date.now() - t < 7 * 864e5) return;
      if (deferred) show('Install AeroSim on your home screen to fly full screen, offline.', true);
      else if (/iPhone|iPad|iPod/i.test(navigator.userAgent)) show('To install: tap Share, then Add to Home Screen.', false);
    },
  };
  return api;
}

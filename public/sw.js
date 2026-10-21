// AeroSim service worker: cache the app shell so it launches offline and installs cleanly.
const CACHE = 'aerosim-v2';
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(['./', './icons/icon-192.png', './icons/icon-512.png'])).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k.startsWith('aerosim-') && k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  const req = e.request; if (req.method !== 'GET' || new URL(req.url).origin !== location.origin) return;
  if (req.mode === 'navigate') { // network first so updates arrive, cache as fallback
    e.respondWith(fetch(req, { cache: 'no-cache' }).then(r => { const c = r.clone(); caches.open(CACHE).then(ch => ch.put('./', c)); return r; }).catch(() => caches.match('./')));
    return;
  }
  e.respondWith(caches.match(req).then(hit => hit || fetch(req).then(r => { if (r.ok) { const c = r.clone(); caches.open(CACHE).then(ch => ch.put(req, c)); } return r; })));
});

// CodePhantom service worker.
//
// Scope is deliberately small: it only answers top-level page navigations,
// network-first, falling back to a cached offline page when the device has
// no connection. It never intercepts API, auth, asset or third-party
// requests, so it cannot serve stale account data, cache tokens or pin an
// old build: every request other than a navigation goes straight to the
// network as if no service worker existed.
const OFFLINE_CACHE = 'codephantom-offline-v1';
const OFFLINE_URL = 'offline.html';
const OFFLINE_ASSETS = [OFFLINE_URL, 'icons/Icon-192.png'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(OFFLINE_CACHE).then((cache) => cache.addAll(OFFLINE_ASSETS)).then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k.startsWith('codephantom-') && k !== OFFLINE_CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  if (event.request.mode !== 'navigate') return;
  event.respondWith(
    fetch(event.request).catch(() => caches.match(OFFLINE_URL, { ignoreSearch: true })),
  );
});

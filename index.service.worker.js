// Self-destroying service worker.
//
// The previous Godot-generated worker had a syntax error (an unescaped
// apostrophe in the "Pilgrim's Road" cache prefix) so it could never install,
// while any earlier worker kept serving a STALE cached build -- which is why
// players kept seeing an old version after re-exporting / redeploying.
//
// This replacement takes over from any old worker, deletes every cache, then
// unregisters itself and reloads open tabs. Afterwards the site is served
// straight from the network (Vercel / R2) with no stale caching.

self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil((async function () {
    try {
      var keys = await caches.keys();
      await Promise.all(keys.map(function (k) { return caches.delete(k); }));
    } catch (e) {}
    try { await self.clients.claim(); } catch (e) {}
    try { await self.registration.unregister(); } catch (e) {}
    try {
      var clients = await self.clients.matchAll({ type: 'window' });
      clients.forEach(function (c) { try { c.navigate(c.url); } catch (e) {} });
    } catch (e) {}
  })());
});

self.addEventListener('fetch', function (event) {
  event.respondWith(
    fetch(event.request).catch(function () {
      return new Response('', { status: 504, statusText: 'offline' });
    })
  );
});

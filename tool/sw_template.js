// Service worker do ReSo. Gerado por tool/make_sw.dart a partir deste modelo,
// que preenche BUILD (o hash do build), RESOURCES (o hash de cada arquivo) e
// CORE (o que vem na instalacao).
//
// - Na instalacao, baixa o essencial para abrir offline.
// - O resto (o motor que o navegador escolher: wasm ou js) entra no cache na
//   primeira vez que e pedido.
// - Numa versao nova, so baixa de novo o que mudou: o que tem o mesmo hash
//   passa do cache antigo para o novo.
// - A pagina (index.html) vem da rede quando ha rede, para ver versao nova
//   logo; sem rede, vem do cache.
'use strict';

const BUILD = '__BUILD__';
const RESOURCES = __RESOURCES__;
const CORE = __CORE__;
const CACHE = 'reso-' + BUILD;
const META = 'reso-meta';

const scope = new URL(self.registration.scope);
const keyOf = (url) => {
  const u = new URL(url);
  if (u.origin !== scope.origin || !u.pathname.startsWith(scope.pathname)) return null;
  const key = u.pathname.slice(scope.pathname.length);
  return key === '' ? 'index.html' : key;
};

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE)
      .then((cache) => cache.addAll(CORE.map((k) => new Request(k, { cache: 'reload' }))))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const meta = await caches.open(META);
    const old = await meta.match('manifest');
    const cache = await caches.open(CACHE);
    if (old) {
      const { build, resources } = await old.json();
      if (build !== BUILD) {
        const previous = await caches.open('reso-' + build);
        for (const [key, hash] of Object.entries(RESOURCES)) {
          if (resources[key] !== hash) continue;
          if (await cache.match(key)) continue;
          const hit = await previous.match(key);
          if (hit) await cache.put(key, hit);
        }
      }
    }
    await meta.put('manifest', new Response(JSON.stringify({ build: BUILD, resources: RESOURCES })));
    for (const name of await caches.keys()) {
      if (name !== CACHE && name !== META) await caches.delete(name);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  let key = keyOf(request.url);
  if (request.mode === 'navigate' && key !== null) key = 'index.html';
  if (key === null || !(key in RESOURCES)) return;

  if (key === 'index.html') {
    event.respondWith(fromNetwork(key, request));
  } else {
    event.respondWith(fromCache(key, request));
  }
});

async function fromCache(key, request) {
  const cache = await caches.open(CACHE);
  const hit = await cache.match(key);
  if (hit) return hit;
  const response = await fetch(request);
  if (response.ok) await cache.put(key, response.clone());
  return response;
}

async function fromNetwork(key, request) {
  const cache = await caches.open(CACHE);
  try {
    const response = await fetch(request);
    if (response.ok) await cache.put(key, response.clone());
    return response;
  } catch (error) {
    const hit = await cache.match(key);
    if (hit) return hit;
    throw error;
  }
}

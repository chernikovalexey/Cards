// Two Cubes service worker: installable PWA + offline play.
//
// Strategy: network-first with cache fallback for every same-origin GET.
// Fresh deploys are picked up immediately (nothing is served stale while
// online), flaky fetches fall back to the last good copy (the same class
// of Cloudflare+Firefox HTTP/3 drops the in-page retrying loader guards
// against), and after one successful visit the game boots and plays
// offline. Assets fetched during play (sprites, level JSON) accumulate in
// the runtime cache; the boot-critical shell is precached on install.
'use strict';

var VERSION = 'twocubes-v1';

var SHELL = [
    '/',
    '/index.html',
    '/manifest.webmanifest',
    '/web/cards.html',
    '/web/cards.css',
    '/web/cards.dart.js',
    '/web/external/scrollbar.js',
    '/web/external/html2canvas.js',
    '/web/external/jquery-2.1.1.min.js',
    '/web/external/jqEase.js',
    '/web/external/TemplateEngine.js',
    '/web/external/webapi.js',
    '/web/external/features.js',
    '/web/external/touch.js',
    '/web/external/locales/en.js',
    '/web/levels/hints.js',
    '/web/levels/chapters.json',
    '/web/levels/chapter_1.json',
    '/web/levels/chapter_2.json',
    '/web/levels/chapter_3.json',
    '/web/levels/chapter_4.json',
    '/packages/browser/dart.js',
];

self.addEventListener('install', function (event) {
    event.waitUntil(
        caches.open(VERSION).then(function (cache) {
            // no-cache: precache from the server, not from whatever the
            // browser HTTP cache still holds under the CDN's max-age.
            return cache.addAll(SHELL.map(function (url) {
                return new Request(url, { cache: 'no-cache' });
            }));
        }).then(function () {
            return self.skipWaiting();
        })
    );
});

self.addEventListener('activate', function (event) {
    event.waitUntil(
        caches.keys().then(function (keys) {
            return Promise.all(keys.map(function (key) {
                if (key !== VERSION) return caches.delete(key);
                return null;
            }));
        }).then(function () {
            return self.clients.claim();
        })
    );
});

// Navigations must not be answered with a redirected response (a security
// error that fails the load), and Cloudflare Pages' pretty URLs redirect
// /web/cards.html -> /web/cards, so both the cached copy can carry the
// redirected flag and the live URL can miss the cache key. Rebuild the
// response body to strip the flag.
function cleanResponse(hit) {
    if (!hit.redirected) return Promise.resolve(hit);
    return hit.blob().then(function (body) {
        return new Response(body, {
            status: hit.status,
            statusText: hit.statusText,
            headers: hit.headers,
        });
    });
}

self.addEventListener('fetch', function (event) {
    var req = event.request;
    if (req.method !== 'GET') return;
    var url = new URL(req.url);
    if (url.origin !== self.location.origin) return;

    // Bypass the browser HTTP cache: Cloudflare Pages serves assets with
    // max-age=14400, and a default-mode fetch() is answered by that cache
    // for 4 hours — "network-first" would never see a fresh deploy.
    // 'no-cache' still sends conditional requests (unchanged files cost a
    // 304). Navigation Requests can't be rebuilt (the Request constructor
    // throws on mode 'navigate'); HTML stays fresh via the _headers file
    // deployed alongside the site.
    var net = req.mode === 'navigate' ? req : new Request(req, { cache: 'no-cache' });

    event.respondWith(
        fetch(net).then(function (res) {
            if (res && res.ok) {
                var copy = res.clone();
                caches.open(VERSION).then(function (cache) {
                    cache.put(req, copy);
                });
            }
            return res;
        }).catch(function () {
            return caches.match(req, { ignoreSearch: true }).then(function (hit) {
                // The game is a single page: any same-origin navigation
                // can fall back to the cached shell page.
                if (!hit && req.mode === 'navigate') {
                    return caches.match('/web/cards.html');
                }
                return hit;
            }).then(function (hit) {
                if (!hit) throw new Error('offline and not cached: ' + url.pathname);
                return req.mode === 'navigate' ? cleanResponse(hit) : hit;
            });
        })
    );
});

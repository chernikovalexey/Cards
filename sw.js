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
    '/packages/browser/dart.js',
];

self.addEventListener('install', function (event) {
    event.waitUntil(
        caches.open(VERSION).then(function (cache) {
            return cache.addAll(SHELL);
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

self.addEventListener('fetch', function (event) {
    var req = event.request;
    if (req.method !== 'GET') return;
    var url = new URL(req.url);
    if (url.origin !== self.location.origin) return;

    event.respondWith(
        fetch(req).then(function (res) {
            if (res && res.ok) {
                var copy = res.clone();
                caches.open(VERSION).then(function (cache) {
                    cache.put(req, copy);
                });
            }
            return res;
        }).catch(function () {
            return caches.match(req, { ignoreSearch: true }).then(function (hit) {
                if (hit) return hit;
                throw new Error('offline and not cached: ' + url.pathname);
            });
        })
    );
});

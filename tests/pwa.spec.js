// PWA packaging: manifest served and linked, service worker installs, and
// the game boots fully offline after one online visit. The offline flow is
// pinned on chromium (Playwright's firefox SW + setOffline support is
// unreliable); the manifest checks run everywhere.
'use strict';
const { test, expect } = require('@playwright/test');
const http = require('http');
const fs = require('fs');
const path = require('path');

test('manifest is linked and served with icons', async ({ page, request }) => {
    await page.goto('/web/cards.html');
    const href = await page.getAttribute('link[rel="manifest"]', 'href');
    expect(href).toBe('/manifest.webmanifest');
    const res = await request.get('/manifest.webmanifest');
    expect(res.ok()).toBe(true);
    const manifest = JSON.parse(await res.text());
    expect(manifest.name).toBe('Two Cubes');
    expect(manifest.start_url).toBe('/web/cards.html');
    expect(manifest.display).toBe('fullscreen');
    expect(manifest.icons.length).toBeGreaterThanOrEqual(3);
    for (const icon of manifest.icons) {
        const ir = await request.get(icon.src);
        expect(ir.ok()).toBe(true);
    }
});

test('service worker installs and the game boots offline', async ({ page, context, browserName }) => {
    test.skip(browserName !== 'chromium', 'offline SW flow pinned on chromium');
    test.setTimeout(120000);
    await page.goto('/web/cards.html');
    await expect(page.locator('#new-game')).toBeVisible({ timeout: 30000 });
    // wait for the SW to activate and finish precaching the shell
    await page.evaluate(() => navigator.serviceWorker.ready);
    await page.waitForFunction(async () => {
        const keys = await caches.keys();
        if (!keys.length) return false;
        const cache = await caches.open(keys[0]);
        return !!(await cache.match('/web/cards.dart.js'));
    }, null, { timeout: 30000 });

    await context.setOffline(true);
    await page.reload();
    await expect(page.locator('#new-game')).toBeVisible({ timeout: 30000 });
    await context.setOffline(false);
});

// Cloudflare Pages serves every asset with Cache-Control: max-age=14400.
// A default-mode fetch() inside the service worker is answered by the
// browser HTTP cache for those 4 hours, silently breaking the worker's
// "network-first, fresh deploys are never stale" contract (a phone that
// played v2 kept getting v2 after the v3 deploy). The worker must fetch
// with cache: 'no-cache' so it revalidates with the server every time.
test.describe('CDN-style max-age headers', () => {
    let server;
    let origin;
    let probeHits = 0;

    const MIME = {
        '.html': 'text/html', '.js': 'application/javascript',
        '.css': 'text/css', '.json': 'application/json',
        '.png': 'image/png', '.webmanifest': 'application/manifest+json',
    };

    test.beforeAll(async () => {
        const root = path.join(__dirname, '..');
        server = http.createServer((req, res) => {
            let urlPath;
            try {
                urlPath = decodeURIComponent(new URL(req.url, 'http://x').pathname);
            } catch (e) {
                res.writeHead(400);
                res.end();
                return;
            }
            if (urlPath === '/__probe.js') {
                probeHits += 1;
                res.writeHead(200, {
                    'Content-Type': 'application/javascript',
                    'Cache-Control': 'public, max-age=14400, must-revalidate',
                });
                res.end(String(probeHits));
                return;
            }
            const file = path.join(root, urlPath === '/' ? 'index.html' : urlPath.slice(1));
            if (!file.startsWith(root) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
                res.writeHead(404);
                res.end();
                return;
            }
            res.writeHead(200, {
                'Content-Type': MIME[path.extname(file)] || 'application/octet-stream',
                'Cache-Control': 'public, max-age=14400, must-revalidate',
            });
            fs.createReadStream(file).pipe(res);
        });
        await new Promise((r) => server.listen(0, '127.0.0.1', r));
        origin = 'http://127.0.0.1:' + server.address().port;
    });

    test.afterAll(async () => {
        await new Promise((r) => server.close(r));
    });

    test('service worker revalidates past the CDN max-age (deploys are never stale)', async ({ page, browserName }) => {
        test.skip(browserName !== 'chromium', 'SW flow pinned on chromium');
        test.setTimeout(120000);
        await page.goto(origin + '/web/cards.html');
        await page.evaluate(() => navigator.serviceWorker.ready);
        await page.waitForFunction(() => !!navigator.serviceWorker.controller);
        // Two fetches through the worker: the probe increments per server
        // hit, so a stale HTTP-cache answer would repeat the first body.
        const a = await page.evaluate(() => fetch('/__probe.js').then((r) => r.text()));
        const b = await page.evaluate(() => fetch('/__probe.js').then((r) => r.text()));
        expect(a).toBe('1');
        expect(b).toBe('2');   // '1' again = served from HTTP cache, stale
    });
});

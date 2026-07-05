// PWA packaging: manifest served and linked, service worker installs, and
// the game boots fully offline after one online visit. The offline flow is
// pinned on chromium (Playwright's firefox SW + setOffline support is
// unreliable); the manifest checks run everywhere.
'use strict';
const { test, expect } = require('@playwright/test');

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

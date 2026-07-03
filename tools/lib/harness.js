'use strict';
const { chromium } = require('playwright-core');
const { startServer } = require('./server');

// Runs before any page script. Replaces requestAnimationFrame with a manual
// pump: the Dart engine performs exactly one fixed physics step per rAF
// callback (StateManager.dart), so tick(n) advances the simulation n frames
// deterministically. Also wraps #graphics 2D context so turbo mode can skip
// rasterization without skipping render logic (energy fill lives in render).
const INIT_SCRIPT = `(() => {
    const pump = {
        queue: [],
        now: 0,
        mode: 'manual',
        turbo: false,
        events: [],
        realRAF: window.requestAnimationFrame.bind(window),
        tick(n) {
            for (let i = 0; i < n; i++) {
                this.now += 1000 / 60;
                const cbs = this.queue.splice(0);
                for (const cb of cbs) cb(this.now);
            }
        },
        setMode(mode) {
            this.mode = mode;
            if (mode === 'real') {
                const drain = () => {
                    if (this.mode !== 'real') return;
                    const cbs = this.queue.splice(0);
                    for (const cb of cbs) cb(performance.now());
                    this.realRAF(drain);
                };
                this.realRAF(drain);
            }
        },
    };
    window.__harness = pump;
    window.requestAnimationFrame = (cb) => { pump.queue.push(cb); return pump.queue.length; };

    const origGetContext = HTMLCanvasElement.prototype.getContext;
    HTMLCanvasElement.prototype.getContext = function (type, ...rest) {
        const ctx = origGetContext.call(this, type, ...rest);
        if (type === '2d' && this.id === 'graphics' && ctx && !ctx.__wrapped) {
            ctx.__wrapped = true;
            for (const k of ['fill', 'stroke', 'fillRect', 'clearRect', 'arc',
                             'beginPath', 'moveTo', 'lineTo', 'closePath',
                             'strokeText', 'fillText']) {
                const orig = ctx[k].bind(ctx);
                ctx[k] = function (...a) { if (!pump.turbo) return orig(...a); };
            }
        }
        return ctx;
    };
})();`;

async function createHarness(opts = {}) {
    const {
        turbo = true, realTime = false, videoDir = null,
        profile = {}, headless = true,
    } = opts;

    const server = await startServer();
    const baseURL = `http://127.0.0.1:${server.port}`;
    const browser = await chromium.launch({ headless });
    const context = await browser.newContext({
        viewport: { width: 1280, height: 720 },
        ...(videoDir ? { recordVideo: { dir: videoDir, size: { width: 1280, height: 720 } } } : {}),
    });
    await context.addInitScript(INIT_SCRIPT);
    if (Object.keys(profile).length) {
        await context.addInitScript((entries) => {
            for (const [k, v] of entries) localStorage.setItem(k, v);
        }, Object.entries(profile));
    }

    const page = await context.newPage();
    await page.goto(`${baseURL}/web/cards.html`, { waitUntil: 'domcontentloaded' });
    // Boot completes on timers/XHR (not rAF): loading overlay removed, menu shown.
    await page.locator('.loading-overlay').waitFor({ state: 'detached', timeout: 60000 });
    await page.locator('#menu-box').waitFor({ state: 'visible', timeout: 10000 });

    // Post-boot instrumentation (game globals exist now)
    await page.evaluate(([turboOn, realTimeOn]) => {
        window.__harness.turbo = turboOn;
        if (realTimeOn) window.__harness.setMode('real');
        const orig = window.Features.onLevelFinish.bind(window.Features);
        window.Features.onLevelFinish = function (chapter, level, stars, numDynamic, numStatic, attempts, timeSpent) {
            window.__harness.events.push({ type: 'levelFinish', chapter, level, stars, numDynamic, numStatic, attempts, timeSpent });
            return orig(chapter, level, stars, numDynamic, numStatic, attempts, timeSpent);
        };
        // Search sessions get an effectively unlimited attempt budget so long
        // runs never hit the 125-attempt UI lock (UserManager reads this JS
        // object). Real-time (proof) sessions keep stock behavior.
        if (turboOn) window.Features.user.allAttempts = 1e9;
    }, [turbo, realTime]);

    return {
        page, context, browser, baseURL,
        tick: (n) => page.evaluate((k) => window.__harness.tick(k), n),
        events: () => page.evaluate(() => window.__harness.events),
        clearEvents: () => page.evaluate(() => { window.__harness.events.length = 0; }),
        exportProfile: () => page.evaluate(() => Object.fromEntries(Object.entries(localStorage))),
        close: async () => {
            await context.close();
            await browser.close();
            await server.close();
        },
    };
}

module.exports = { createHarness };

# CLI Play API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A CLI that lets a machine play Two Cubes headlessly (place blocks, apply physics, read win/fail) fast enough for thousands of scenarios, plus a video-proof mode; then use it to complete all three chapters.

**Architecture:** Playwright (playwright-core, already in node_modules) drives the real compiled game in headless Chromium. An init script replaces `requestAnimationFrame` with a manual tick pump (the engine does exactly one fixed `world.step(1/60)` per rAF frame, so ticking fast-forwards the deterministic simulation). Input is synthetic DOM events against the pinned `Input.dart` interface; success is observed by wrapping the JS global `Features.onLevelFinish` that the Dart engine calls on every level completion; failure is observed via the "Rewind to try again" tooltip (re-armed each attempt by deleting localStorage `apply_fail_occured`). No game file is modified.

**Tech Stack:** Node ≥ 20 (repo has v25), `playwright-core` (transitive dep of `@playwright/test`), `node:test` for the CLI's own tests, no new npm dependencies.

## Global Constraints

- Do NOT modify any game file: nothing under `web/`, `packages/`, `index.html`. All instrumentation is injected at runtime.
- Do NOT touch `tests/parity.spec.js` or `playwright.config.js`; CLI tests live in `tools/tests/` and run via `node --test tools/tests/` so `npm test` (the parity suite) is unaffected.
- No new npm dependencies. Use `require('playwright-core')` and Node built-ins only.
- World units are box2d meters: `world = px / 85` (`GameEngine.NSCALE = 85`). Card is 45×2.5 px (0.5294×0.0294 wu); energy cubes are 35×35 px (0.4118 wu).
- The harness never pans or zooms the camera (no arrow keys, no space-drag, no z-zoom) — the world→screen mapping below is only valid under that invariant.
- Key codes used (from `Input.dart:15-17`): enter=13, esc=27, 1=49, 2=50, q=81, e=69, c=67, v=86.
- Angle API is radians, snapped to π/72 (2.5°) increments — the game's own rotation granularity.

---

### Task 1: Level data module (`tools/lib/levels.js`)

**Files:**
- Create: `tools/lib/levels.js`
- Test: `tools/tests/levels.test.js`
- Modify: `package.json` (add scripts)

**Interfaces:**
- Produces (used by every later task):
  - `NSCALE` (85), `CARD = {w, h}` (world units), `CUBE = 35/85`
  - `loadChapter(chapter) -> {name?, levels: [raw]}` — parses `web/levels/chapter_N.json`
  - `levelInfo(chapter, level) -> info` where `info = {chapter, level, name, gravity, blocks: {static, dynamic}, stars: [forThree, forTwo], bounds: {x, y, width, height} (px), from: {x, y, w, h}, to: {x, y, w, h} (world units, x/y = lower-left corner as the game creates them), obstacles: [{type, ...world units}]}`
  - `cameraOffsets(rawLevel, canvasW, canvasH) -> {pxOffsetX, pxOffsetY}` — replica of `Camera.checkTarget` clamping (`Camera.dart:216-226`) for the settled, never-panned camera
  - `worldToClient(wx, wy, rawLevel, canvasRect) -> {clientX, clientY}` — inverse of `Input.onMouseMove` (`Input.dart:47-48`)
  - `searchProfile(chapter, level) -> {[key]: value}` — localStorage seed that makes the game open chapter C at level L directly (`last` key, `stars` blob big enough to unlock the chapter, `seen_howto`/`runout_occured` to suppress tutorial overlays)

- [ ] **Step 1: Write the failing test**

```js
// tools/tests/levels.test.js
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const L = require('../lib/levels');

test('levelInfo converts chapter 1 level 1 to world units', () => {
    const info = L.levelInfo(1, 1);
    assert.equal(info.name, 'Transgalactic Hustler');
    assert.deepEqual(info.blocks, { static: 0, dynamic: 3 });
    assert.deepEqual(info.stars, [1, 2]);
    // from cube: x=100px, y=50px, 35x35px
    assert.ok(Math.abs(info.from.x - 100 / 85) < 1e-9);
    assert.ok(Math.abs(info.from.y - 50 / 85) < 1e-9);
    assert.ok(Math.abs(info.from.w - 35 / 85) < 1e-9);
    assert.equal(info.gravity, -10); // default GameEngine.GRAVITY
    assert.equal(info.obstacles.length, 3);
});

test('cameraOffsets reproduces the settled camera for chapter 1 level 1', () => {
    const raw = L.loadChapter(1).levels[0]; // x:0 y:-10 w:1600 h:2000
    const { pxOffsetX, pxOffsetY } = L.cameraOffsets(raw, 800, 600);
    assert.equal(pxOffsetX, 0);
    // mTargetY clamps to by1/85 + H = -10/85 + 600/85; pxOffsetY = -mTargetY*85 = -(590)
    assert.ok(Math.abs(pxOffsetY - (-590)) < 1e-9);
});

test('worldToClient maps the from cube onto the canvas', () => {
    const raw = L.loadChapter(1).levels[0];
    const rect = { left: 100, top: 20, width: 800, height: 600 };
    const p = L.worldToClient(100 / 85, 50 / 85, raw, rect);
    assert.ok(Math.abs(p.clientX - (100 + 100)) < 1e-6);      // 100*85/85 px into canvas
    assert.ok(Math.abs(p.clientY - (20 + (-50 + 590))) < 1e-6); // -wy*85 - pxOffsetY
});

test('searchProfile seeds direct entry and chapter unlock', () => {
    const p = L.searchProfile(3, 5);
    assert.equal(p.last, JSON.stringify({ chapter: 3, level: 5 }));
    assert.ok(JSON.parse(p.stars).total >= 60); // chapter 3 needs 60 stars
    assert.equal(p.seen_howto, 'true');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test tools/tests/levels.test.js`
Expected: FAIL — `Cannot find module '../lib/levels'`

- [ ] **Step 3: Write the implementation**

```js
// tools/lib/levels.js
'use strict';
const fs = require('fs');
const path = require('path');

const NSCALE = 85;
const CARD = { w: 45 / NSCALE, h: 2.5 / NSCALE };
const CUBE = 35 / NSCALE;
const REPO_ROOT = path.join(__dirname, '..', '..');

const chapterCache = new Map();

function loadChapter(chapter) {
    if (!chapterCache.has(chapter)) {
        const file = path.join(REPO_ROOT, 'web', 'levels', `chapter_${chapter}.json`);
        chapterCache.set(chapter, JSON.parse(fs.readFileSync(file, 'utf8')));
    }
    return chapterCache.get(chapter);
}

// SubLevel.dart creates cubes with createPolygonShape(x/85, y/85, CUBE, CUBE)
// where (x, y) is the lower-left corner and the body center is corner + w/2.
function cubeRect(raw) {
    return { x: raw.x / NSCALE, y: raw.y / NSCALE, w: CUBE, h: CUBE };
}

function levelInfo(chapter, level) {
    const raw = loadChapter(chapter).levels[level - 1];
    if (!raw) throw new Error(`no level ${chapter}-${level}`);
    return {
        chapter,
        level,
        name: raw.name,
        gravity: raw.gravity != null && raw.gravity !== 0 ? raw.gravity : -10,
        blocks: { static: raw.blocks[0], dynamic: raw.blocks[1] },
        stars: raw.stars,
        bounds: { x: raw.x, y: raw.y, width: raw.width, height: raw.height },
        from: cubeRect(raw.from),
        to: cubeRect(raw.to),
        obstacles: raw.obstacles.map((o) => {
            const out = { type: o.type, dynamic: o.type === 5 || o.type === 6 };
            if (o.points) {
                out.points = o.points.map((p) => ({ x: p.x / NSCALE, y: p.y / NSCALE }));
            } else {
                out.x = o.x / NSCALE; out.y = o.y / NSCALE;
                out.w = o.width / NSCALE; out.h = o.height / NSCALE;
            }
            if (o.gravity != null) out.gravity = o.gravity;
            return out;
        }),
    };
}

// Replica of SubLevel.apply() + Camera.checkTarget() (Camera.dart:216-226) for
// a camera that is never panned or zoomed after entering the level.
function cameraOffsets(rawLevel, canvasW, canvasH) {
    const S = NSCALE;
    const W = canvasW / S;
    const H = canvasH / S;
    const bx1 = rawLevel.x, bx2 = rawLevel.x + rawLevel.width;
    const by1 = rawLevel.y, by2 = rawLevel.y + rawLevel.height;

    let mx = rawLevel.x / S;                       // apply(): mTargetX = x / scale
    if (mx <= bx1 / S) mx = bx1 / S;
    if (mx + W >= bx2 / S) mx = bx2 / S - W;

    let my = rawLevel.y / S;                       // apply(): mTargetY = y / scale
    if (my - H <= by1 / S) my = by1 / S + H;
    if (my >= by2 / S) my = by2 / S;

    return { pxOffsetX: mx * S, pxOffsetY: -my * S };
}

// Inverse of Input.onMouseMove (Input.dart:47-48):
//   mouseX = (clientX - canvasX)/85 + pxOffsetX/85
//   mouseY = -(clientY - canvasY)/85 - pxOffsetY/85
function worldToClient(wx, wy, rawLevel, canvasRect) {
    const { pxOffsetX, pxOffsetY } = cameraOffsets(rawLevel, canvasRect.width, canvasRect.height);
    return {
        clientX: canvasRect.left + wx * NSCALE - pxOffsetX,
        clientY: canvasRect.top + (-wy * NSCALE - pxOffsetY),
    };
}

// localStorage seed for search sessions: Level.preload() jumps straight to
// storage['last'].level when its chapter matches, and the chapters API
// computes unlocks from the 'stars' blob. Search-only — never use for proofs.
function searchProfile(chapter, level) {
    const starsNeeded = chapter === 3 ? 60 : chapter === 2 ? 30 : 0;
    const profile = {
        seen_howto: 'true',
        runout_occured: 'true',
        last: JSON.stringify({ chapter, level }),
    };
    if (starsNeeded > 0) {
        profile.stars = JSON.stringify({
            total: starsNeeded,
            chapters: [{ id: 1, s: Math.min(36, starsNeeded) },
                       { id: 2, s: Math.max(0, starsNeeded - 36) }],
        });
    }
    return profile;
}

module.exports = { NSCALE, CARD, CUBE, loadChapter, levelInfo, cameraOffsets, worldToClient, searchProfile };
```

- [ ] **Step 4: Run test to verify it passes**

Run: `node --test tools/tests/levels.test.js`
Expected: PASS (4 tests)

- [ ] **Step 5: Add npm scripts**

In `package.json` `"scripts"`, add (keep existing entries):

```json
"cli": "node tools/cli.js",
"test:cli": "node --test tools/tests/"
```

- [ ] **Step 6: Commit**

```bash
git add tools/lib/levels.js tools/tests/levels.test.js package.json
git commit -m "cli-play: level data module with world-unit conversion and camera math"
```

---

### Task 2: Browser harness with tick pump (`tools/lib/harness.js`)

**Files:**
- Create: `tools/lib/server.js` (static file server, no deps)
- Create: `tools/lib/harness.js`
- Test: `tools/tests/harness.test.js`

**Interfaces:**
- Consumes: nothing from Task 1 (independent).
- Produces:
  - `server.js`: `startServer() -> Promise<{port, close()}>` serving the repo root.
  - `harness.js`: `createHarness(opts) -> Promise<harness>` with
    `opts = {turbo = true, realTime = false, videoDir = null, profile = {}, headless = true}` and
    `harness = {page, context, browser, baseURL, tick(n): Promise<void>, events(): Promise<[]>, clearEvents(): Promise<void>, exportProfile(): Promise<{[k]:string}>, close(): Promise<void>}`.
  - In-page globals installed by the harness (used by Task 3's page code):
    - `window.__harness = {tick(n), setMode(m), turbo, events: []}` (init script, runs before all page scripts)
    - `Features.onLevelFinish` wrapped to push `{type:'levelFinish', chapter, level, stars, numDynamic, numStatic, attempts, timeSpent}` into `__harness.events` (installed post-boot, read-only pass-through)

**Key facts encoded here:** `StateManager.run()` schedules exactly one `step` per rAF and each step does one `world.step(1/60, 10, 10)` (`StateManager.dart:43-63`, `GameEngine.dart:437`) — so a manual pump fast-forwards simulation deterministically. Rendering cannot be skipped (energy fill advances inside `EnergySprite.render`, `EnergySprite.dart:64-74`), so turbo mode no-ops the expensive `#graphics` 2D-context calls instead. Boot (menu appearing) is driven by timers/XHR, not rAF, so the game boots fully even with rAF frozen.

- [ ] **Step 1: Write the failing test**

```js
// tools/tests/harness.test.js
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { createHarness } = require('../lib/harness');

test('game boots to menu under the tick pump and ticks advance', { timeout: 120000 }, async () => {
    const h = await createHarness();
    try {
        // Menu is visible, loading overlay gone (harness waits for this in boot)
        assert.equal(await h.page.locator('.loading-overlay').count(), 0);
        assert.ok(await h.page.locator('#menu-box').isVisible());

        // rAF is hijacked: pending callbacks queue up and tick() drains them
        const queued = await h.page.evaluate(() => window.__harness.queue.length);
        assert.ok(queued > 0, 'game loop parked in the pump queue');
        await h.tick(10);
        const stillQueued = await h.page.evaluate(() => window.__harness.queue.length);
        assert.ok(stillQueued > 0, 'game loop keeps rescheduling after ticks');

        // Success hook installed
        const wrapped = await h.page.evaluate(() =>
            window.Features.onLevelFinish.toString().includes('__harness'));
        assert.ok(wrapped);
    } finally {
        await h.close();
    }
});

test('profile seeding puts keys into localStorage before boot', { timeout: 120000 }, async () => {
    const h = await createHarness({ profile: { seen_howto: 'true', probe_key: 'probe_value' } });
    try {
        const v = await h.page.evaluate(() => localStorage.getItem('probe_key'));
        assert.equal(v, 'probe_value');
    } finally {
        await h.close();
    }
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test tools/tests/harness.test.js`
Expected: FAIL — `Cannot find module '../lib/harness'`

- [ ] **Step 3: Implement the static server**

```js
// tools/lib/server.js
'use strict';
const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..', '..');
const MIME = {
    '.html': 'text/html', '.js': 'application/javascript', '.css': 'text/css',
    '.json': 'application/json', '.png': 'image/png', '.gif': 'image/gif',
    '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.svg': 'image/svg+xml',
    '.woff': 'font/woff', '.woff2': 'font/woff2', '.ttf': 'font/ttf', '.ico': 'image/x-icon',
};

function startServer() {
    const server = http.createServer((req, res) => {
        const urlPath = decodeURIComponent(new URL(req.url, 'http://x').pathname);
        let file = path.normalize(path.join(ROOT, urlPath));
        if (!file.startsWith(ROOT)) { res.writeHead(403).end(); return; }
        fs.stat(file, (err, st) => {
            if (!err && st.isDirectory()) file = path.join(file, 'index.html');
            fs.readFile(file, (err2, data) => {
                if (err2) { res.writeHead(404); res.end('not found'); return; }
                res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream' });
                res.end(data);
            });
        });
    });
    return new Promise((resolve) => {
        server.listen(0, '127.0.0.1', () => {
            resolve({ port: server.address().port, close: () => new Promise((r) => server.close(r)) });
        });
    });
}

module.exports = { startServer };
```

- [ ] **Step 4: Implement the harness**

```js
// tools/lib/harness.js
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
```

- [ ] **Step 5: Run tests**

Run: `node --test tools/tests/harness.test.js`
Expected: PASS (2 tests). If the first test fails at `queued > 0`: the game parks its loop before `#menu-box` shows only after `StateManager` constructon ran — debug by checking `window.__harness` exists and `cards.dart.js` loaded (`typeof window.Features`).

- [ ] **Step 6: Commit**

```bash
git add tools/lib/server.js tools/lib/harness.js tools/tests/harness.test.js
git commit -m "cli-play: headless harness with rAF tick pump and success hook"
```

---

### Task 3: Game verbs — goto / place / apply (`tools/lib/game.js`) + first win

**Files:**
- Create: `tools/lib/game.js`
- Test: `tools/tests/game.test.js`

**Interfaces:**
- Consumes: `createHarness` (Task 2), `levels.js` (Task 1).
- Produces: `class Game`:
  - `constructor(harness)`
  - `async gotoLevel(chapter)` — menu → `#new-game` → `.chapter[data-id]` click; resolves `{chapter, level}` once the engine reports the level via localStorage `last`; ticks 160 frames for the camera-settle animation; clears the chapter-1-level-1 hint ghost card via a body click.
  - `async place({x, y, angle = 0, static: isStatic = false})` — returns `{ok, snappedAngle, remaining: {static, dynamic}}` or `{ok: false, reason}`; world coordinates are the card CENTER.
  - `async apply(maxTicks = 3600)` — returns `{outcome: 'won'|'failed'|'timeout', ticks, stars?, event?}`.
  - `async state()` — `{chapter, level, remaining, physicsOn, ratingBoxVisible, events}`.
  - `info()` — `levelInfo` for the current level.
- In-page helper `window.__game` (installed once per page by `Game`): `press(code)`, `keyDown(code)`, `keyUp(code)`, `remaining()`, `place(clientX, clientY, steps, isStatic)`, `applyPhysics(maxTicks, failText)`.

**Key facts encoded here:**
- Placement pipeline per `GameEngine.update` (`GameEngine.dart:467-479`): `1`/`2` select block type; `c`→angle 0, `v`→π/2, `q`/`e` → ±π/72 per press (`BoundedCard.dart:45-55`); a `mousemove` on the canvas teleports the ghost card (`Input.dart:47-48`, synthetic events skip hit-testing so off-viewport world coords work); Enter places if nothing overlaps. Contacts refresh one tick after the ghost moves (the world steps before `bcard.update` in the same frame), hence `tick(2)` between move and Enter.
- Success = `levelFinish` event (hook from Task 2). Failure = the engine settles with no path and shows the "Rewind to try again" tooltip (`GameWizard.showRewind`, gated by localStorage `apply_fail_occured` which we delete before every apply; text from `web/external/locales/en.js`). Stale `.tt` tooltip nodes are removed before each apply so the detector can't see a previous attempt's tooltip.
- Chapter 1 level 1 spawns a hint ghost card (a solid static body) via `GameWizard.showOverview` → `hints.addHintCard(1.671, 2.5, ...)`; any body click clears it (`GameWizard.dart:170-209`).

- [ ] **Step 1: Write the failing test**

```js
// tools/tests/game.test.js
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { createHarness } = require('../lib/harness');
const { Game } = require('../lib/game');

// Chapter 1 level 1: from cube spans x 1.176..1.588, to cube 1.765..2.176,
// both sitting on ground at y 0.588..1.0. One flat card laid across both cube
// tops bridges them: center x between cube centers, y just above cube top.
const BRIDGE = { x: (1.382 + 1.971) / 2, y: 1.0 + 0.0147 + 0.02, angle: 0, static: false };

test('completes chapter 1 level 1 with a single bridge card', { timeout: 180000 }, async () => {
    const h = await createHarness({ profile: { seen_howto: 'true', runout_occured: 'true' } });
    const g = new Game(h);
    try {
        const at = await g.gotoLevel(1);
        assert.deepEqual(at, { chapter: 1, level: 1 });

        const placed = await g.place(BRIDGE);
        assert.equal(placed.ok, true, JSON.stringify(placed));
        assert.equal(placed.remaining.dynamic, 2);

        const result = await g.apply();
        assert.equal(result.outcome, 'won', JSON.stringify(result));
        assert.equal(result.stars, 3); // 1 card <= stars[0]=1
    } finally {
        await h.close();
    }
});

test('a hopeless placement is detected as failed', { timeout: 180000 }, async () => {
    const h = await createHarness({ profile: { seen_howto: 'true', runout_occured: 'true' } });
    const g = new Game(h);
    try {
        await g.gotoLevel(1);
        // Card dropped far left of both cubes: settles on the ground, no path.
        const placed = await g.place({ x: 0.6, y: 2.0, angle: 0, static: false });
        assert.equal(placed.ok, true);
        const result = await g.apply();
        assert.equal(result.outcome, 'failed', JSON.stringify(result));
    } finally {
        await h.close();
    }
});

test('overlapping placement is rejected with ok:false', { timeout: 180000 }, async () => {
    const h = await createHarness({ profile: { seen_howto: 'true', runout_occured: 'true' } });
    const g = new Game(h);
    try {
        await g.gotoLevel(1);
        // Ghost centered inside the from cube overlaps it -> canPut() blocks.
        const placed = await g.place({ x: 1.382, y: 0.794, angle: 0, static: false });
        assert.equal(placed.ok, false);
        assert.equal(placed.remaining.dynamic, 3);
    } finally {
        await h.close();
    }
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node --test tools/tests/game.test.js`
Expected: FAIL — `Cannot find module '../lib/game'`

- [ ] **Step 3: Implement `Game`**

```js
// tools/lib/game.js
'use strict';
const levels = require('./levels');

const KEY = { enter: 13, esc: 27, one: 49, two: 50, q: 81, e: 69, c: 67, v: 86 };
const FAIL_TEXT = 'Rewind to try again';
const STEP = Math.PI / 72;

// In-page toolkit. Runs synchronously inside one evaluate per verb so a full
// placement costs a single protocol round trip.
const PAGE_HELPERS = `window.__game = {
    key(type, code) {
        window.dispatchEvent(new KeyboardEvent(type, { keyCode: code, which: code, bubbles: true }));
    },
    press(code) {
        this.key('keydown', code); window.__harness.tick(1);
        this.key('keyup', code); window.__harness.tick(1);
    },
    remaining() {
        const grab = (sel) => {
            const el = document.querySelector(sel);
            const m = el && el.textContent.match(/\\d+/);
            return m ? parseInt(m[0], 10) : null;
        };
        return { dynamic: grab('.dynamic .remaining'), static: grab('.static .remaining') };
    },
    place(clientX, clientY, steps, isStatic) {
        const before = this.remaining();
        this.press(isStatic ? 50 : 49);
        // Angle: start from 0 (c) or PI/2 (v), then q(+)/e(-) by PI/72 each.
        if (Math.abs(steps) > 18) {
            this.press(86); steps -= 36;      // v = 36 steps
        } else {
            this.press(67);
        }
        for (let i = 0; i < Math.abs(steps); i++) this.press(steps > 0 ? 81 : 69);
        const canvas = document.querySelector('#graphics');
        canvas.dispatchEvent(new MouseEvent('mousemove', { clientX, clientY, bubbles: true }));
        window.__harness.tick(2);             // move ghost, then refresh contacts
        this.key('keydown', 13); window.__harness.tick(1);
        this.key('keyup', 13); window.__harness.tick(1);
        return { before, after: this.remaining() };
    },
    applyPhysics(maxTicks, failText) {
        localStorage.removeItem('apply_fail_occured');
        document.querySelectorAll('.tt').forEach((el) => el.remove());
        const H = window.__harness;
        const evStart = H.events.length;
        document.querySelector('#toggle-physics').click();
        let ticks = 0, failSeenAt = -1;
        while (ticks < maxTicks) {
            H.tick(30); ticks += 30;
            if (H.events.length > evStart) {
                const e = H.events[H.events.length - 1];
                return { outcome: 'won', stars: e.stars, ticks, event: e };
            }
            if (failSeenAt < 0) {
                const tips = document.querySelectorAll('.tooltip .tooltip-text');
                for (const t of tips) {
                    if (t.textContent.includes(failText)) { failSeenAt = ticks; break; }
                }
            }
            if (failSeenAt >= 0 && ticks - failSeenAt >= 120) {
                return { outcome: 'failed', ticks };
            }
        }
        return { outcome: 'timeout', ticks };
    },
};`;

class Game {
    constructor(harness) {
        this.h = harness;
        this.page = harness.page;
        this.chapter = null;
        this.level = null;
        this.rawLevel = null;
        this.canvasRect = null;
        this.helpersInstalled = false;
    }

    async _ensureHelpers() {
        if (!this.helpersInstalled) {
            await this.page.evaluate(PAGE_HELPERS);
            this.helpersInstalled = true;
        }
    }

    async _syncLevel() {
        const last = await this.page.evaluate(() => localStorage.getItem('last'));
        if (!last) throw new Error('not in a level (no localStorage.last)');
        const { chapter, level } = JSON.parse(last);
        this.chapter = chapter;
        this.level = level;
        this.rawLevel = levels.loadChapter(chapter).levels[level - 1];
        this.canvasRect = await this.page.evaluate(() => {
            const r = document.querySelector('#graphics').getBoundingClientRect();
            return { left: r.left, top: r.top, width: r.width, height: r.height };
        });
        return { chapter, level };
    }

    info() {
        return levels.levelInfo(this.chapter, this.level);
    }

    async gotoLevel(chapter) {
        await this._ensureHelpers();
        await this.page.evaluate(() => document.querySelector('#new-game').click());
        await this.page.locator('#chapter-selection').waitFor({ state: 'visible' });
        const locked = await this.page.evaluate((c) => {
            const el = document.querySelector(`.chapter[data-id="${c}"]`);
            if (!el) return 'missing';
            if (el.classList.contains('chapter-locked')) return 'locked';
            el.click();
            return null;
        }, chapter);
        if (locked) throw new Error(`chapter ${chapter} is ${locked}`);
        // Level JSON loads over XHR (real time), then 'last' is written.
        await this.page.waitForFunction(
            (c) => { const l = localStorage.getItem('last'); return l && JSON.parse(l).chapter === c; },
            chapter, { timeout: 30000 });
        await this.h.tick(160); // camera settle animation (75-frame DoubleAnimation + margin)
        // Chapter 1 level 1 tutorial spawns a solid hint ghost card; a body
        // click clears it (GameWizard.showOverview). Harmless elsewhere.
        await this.page.evaluate(() => document.body.click());
        await this.h.tick(2);
        return this._syncLevel();
    }

    async place({ x, y, angle = 0, static: isStatic = false }) {
        await this._ensureHelpers();
        if (!this.rawLevel) await this._syncLevel();
        // Rectangle cards are symmetric under PI; normalize to (-PI/2, PI/2].
        let a = angle % Math.PI;
        if (a > Math.PI / 2) a -= Math.PI;
        if (a <= -Math.PI / 2) a += Math.PI;
        const steps = Math.round(a / STEP);
        const { clientX, clientY } = levels.worldToClient(x, y, this.rawLevel, this.canvasRect);
        const r = await this.page.evaluate(
            ([cx, cy, s, st]) => window.__game.place(cx, cy, s, st),
            [clientX, clientY, steps, isStatic]);
        const key = isStatic ? 'static' : 'dynamic';
        const ok = r.before[key] != null && r.after[key] === r.before[key] - 1;
        return {
            ok,
            ...(ok ? {} : { reason: r.before[key] === 0 ? 'no blocks left' : 'overlap or physics on' }),
            snappedAngle: steps * STEP,
            remaining: r.after,
        };
    }

    async apply(maxTicks = 3600) {
        await this._ensureHelpers();
        return this.page.evaluate(
            ([mt, ft]) => window.__game.applyPhysics(mt, ft),
            [maxTicks, FAIL_TEXT]);
    }

    async state() {
        await this._ensureHelpers();
        const s = await this.page.evaluate(() => ({
            last: localStorage.getItem('last'),
            remaining: window.__game.remaining(),
            physicsOn: document.querySelector('#toggle-physics').classList.contains('rewind'),
            ratingBoxVisible: !document.querySelector('#rating-box').classList.contains('hidden'),
            events: window.__harness.events,
        }));
        const last = s.last ? JSON.parse(s.last) : {};
        return { chapter: last.chapter ?? null, level: last.level ?? null, ...s, last: undefined };
    }
}

module.exports = { Game, FAIL_TEXT };
```

- [ ] **Step 4: Run the test**

Run: `node --test tools/tests/game.test.js`
Expected: PASS (3 tests). This is the pipeline-proving milestone. Debugging aids if it fails:
- Win test placement rejected → mouse-mapping bug: temporarily disable turbo (`createHarness({turbo: false})`), `await h.tick(1)`, `await h.page.screenshot({path: '/tmp/board.png'})` and look at where the ghost card actually is versus the cubes.
- `apply` timeout on the good bridge → check `await h.events()`; if empty, verify `#toggle-physics` had no `rewind` class before clicking and that `Features.user.allAttempts` is large.
- Fail test returning timeout → the tooltip text or gating changed; inspect `document.querySelectorAll('.tt')` contents after ~900 ticks.

- [ ] **Step 5: Commit**

```bash
git add tools/lib/game.js tools/tests/game.test.js
git commit -m "cli-play: game verbs (goto/place/apply) win chapter 1 level 1 headlessly"
```

---

### Task 4: Game verbs — restart / next level / card probe / screenshot

**Files:**
- Modify: `tools/lib/game.js` (add methods + page helpers)
- Test: append to `tools/tests/game.test.js`

**Interfaces:**
- Produces (on `Game`):
  - `async restartLevel()` — resets the level (removes all placed cards, restores block counters, rewinds physics if running); returns `{ok, remaining}`.
  - `async nextLevel()` — clicks `#next-level` in the rating box after a win; resolves `{chapter, level}` of the new level (camera settled).
  - `async cards()` — exact placed-card positions `[{x, y, a, s, e}]` via the Esc-pause save probe (`RatingShower.pause` → `saveCurrentProgress` → localStorage `level_<c>_<l>`), resumed afterwards. Returns `[]` when nothing saved.
  - `async screenshot(path)` — real rendered frame even in turbo (temporarily un-stubs, ticks 1, screenshots, restores).

**Key facts:** `#restart` opens a PromptWindow (synchronous `appendHtml`); confirm = last `.prompt-window .prompt-positive` (`PromptWindow.dart:51`, template `web/cards.html:373`). `engine.clear()` rewinds through the recorded bobbin frames (accelerating ~1.05×/frame), then removes every card — completion is observable as block counters returning to their maxima. Esc is consumed inside `engine.update` (needs one tick), pauses the game into `#rating-box` pause mode; `#resume-game` resumes.

- [ ] **Step 1: Write the failing tests (append to `tools/tests/game.test.js`)**

```js
test('restartLevel restores counters after placements and a failed apply', { timeout: 180000 }, async () => {
    const h = await createHarness({ profile: { seen_howto: 'true', runout_occured: 'true' } });
    const g = new Game(h);
    try {
        await g.gotoLevel(1);
        await g.place({ x: 0.6, y: 2.0 });
        await g.place({ x: 0.6, y: 3.0 });
        await g.apply();                       // fails, physics stays on
        const r = await g.restartLevel();
        assert.equal(r.ok, true);
        assert.equal(r.remaining.dynamic, 3);
        // And the level is playable again:
        const placed = await g.place(BRIDGE);
        assert.equal(placed.ok, true);
        assert.equal((await g.apply()).outcome, 'won');
    } finally {
        await h.close();
    }
});

test('cards() reports exact placed positions; nextLevel advances', { timeout: 180000 }, async () => {
    const h = await createHarness({ profile: { seen_howto: 'true', runout_occured: 'true' } });
    const g = new Game(h);
    try {
        await g.gotoLevel(1);
        await g.place(BRIDGE);
        const cs = await g.cards();
        assert.equal(cs.length, 1);
        assert.ok(Math.abs(cs[0].x - BRIDGE.x) < 0.02, `x off: ${cs[0].x} vs ${BRIDGE.x}`);
        assert.ok(Math.abs(cs[0].y - BRIDGE.y) < 0.02, `y off: ${cs[0].y} vs ${BRIDGE.y}`);

        assert.equal((await g.apply()).outcome, 'won');
        const at = await g.nextLevel();
        assert.deepEqual(at, { chapter: 1, level: 2 });
    } finally {
        await h.close();
    }
});
```

Note: `cards()` doubles as the calibration check for the analytic camera math — if the 0.02 wu tolerance fails, the mapping is wrong, not the tolerance.

- [ ] **Step 2: Run to verify the new tests fail**

Run: `node --test tools/tests/game.test.js`
Expected: first three tests PASS, new two FAIL (`g.restartLevel is not a function`).

- [ ] **Step 3: Implement — add to `PAGE_HELPERS` object in `game.js`**

Add these methods inside the `window.__game = {...}` literal:

```js
    restart(expectedDynamic, expectedStatic) {
        document.querySelectorAll('.tt').forEach((el) => el.remove());
        document.querySelector('#restart').click();
        const btns = document.querySelectorAll('.prompt-window .prompt-positive');
        btns[btns.length - 1].click();
        const H = window.__harness;
        let t = 0;
        while (t < 4000) {
            H.tick(25); t += 25;
            const r = this.remaining();
            const staticOk = expectedStatic === 0 || r.static === expectedStatic;
            if (r.dynamic === expectedDynamic && staticOk) return { ok: true, remaining: r, ticks: t };
        }
        return { ok: false, remaining: this.remaining(), ticks: t };
    },
    probeCards(storageKey) {
        // Esc pauses and persists exact card state (RatingShower.pause ->
        // saveCurrentProgress -> LevelSerializer.toJSON).
        this.key('keydown', 27); window.__harness.tick(1); this.key('keyup', 27);
        const raw = localStorage.getItem(storageKey);
        const resume = document.querySelector('#resume-game');
        if (resume) resume.click();
        window.__harness.tick(2);
        return raw ? JSON.parse(raw).c : [];
    },
```

- [ ] **Step 4: Implement — add methods to the `Game` class**

```js
    async restartLevel() {
        await this._ensureHelpers();
        if (!this.rawLevel) await this._syncLevel();
        const inf = this.info();
        return this.page.evaluate(
            ([d, s]) => window.__game.restart(d, s),
            [inf.blocks.dynamic, inf.blocks.static]);
    }

    async nextLevel() {
        await this._ensureHelpers();
        await this.page.evaluate(() => document.querySelector('#next-level').click());
        const prev = this.level;
        await this.page.waitForFunction(
            (lv) => { const l = localStorage.getItem('last'); return l && JSON.parse(l).level !== lv; },
            prev, { timeout: 30000 });
        await this.h.tick(160); // camera settle for the new level
        await this.page.evaluate(() => document.body.click()); // clear any tutorial hint card
        await this.h.tick(2);
        return this._syncLevel();
    }

    async cards() {
        await this._ensureHelpers();
        if (!this.rawLevel) await this._syncLevel();
        return this.page.evaluate(
            (key) => window.__game.probeCards(key),
            `level_${this.chapter}_${this.level}`);
    }

    async screenshot(path) {
        const wasTurbo = await this.page.evaluate(() => {
            const t = window.__harness.turbo;
            window.__harness.turbo = false;
            window.__harness.tick(1);
            return t;
        });
        const buf = await this.page.screenshot(path ? { path } : {});
        await this.page.evaluate((t) => { window.__harness.turbo = t; }, wasTurbo);
        return buf;
    }
```

- [ ] **Step 5: Run all game tests**

Run: `node --test tools/tests/game.test.js`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add tools/lib/game.js tools/tests/game.test.js
git commit -m "cli-play: restart, next-level, card probe and screenshot verbs"
```

---

### Task 5: CLI entry — `info` and interactive `play` (JSONL)

**Files:**
- Create: `tools/cli.js`
- Test: `tools/tests/cli.test.js`

**Interfaces:**
- Consumes: `Game`, `createHarness`, `levels`.
- Produces: `node tools/cli.js <command>`:
  - `info --chapter C [--level L]` — prints `levelInfo` JSON (whole chapter array without `--level`).
  - `play [--chapter C] [--level L] [--no-turbo] [--headed]` — starts a session, optionally seeds `searchProfile(C, L)` and enters the chapter, then reads one JSON command per stdin line and writes one JSON response per stdout line. Commands:
    `{"cmd":"goto","chapter":C}` · `{"cmd":"place","x":..,"y":..,"angle":..,"static":..}` · `{"cmd":"apply","maxTicks":..}` · `{"cmd":"restart"}` · `{"cmd":"next"}` · `{"cmd":"state"}` · `{"cmd":"cards"}` · `{"cmd":"info"}` · `{"cmd":"screenshot","path":".."}` · `{"cmd":"tick","n":..}` · `{"cmd":"quit"}`.
    Every response is `{ok: true, ...result}` or `{ok: false, error}`. A `{"ready":true, chapter, level}` line is printed once the session is up.

- [ ] **Step 1: Write the failing test**

```js
// tools/tests/cli.test.js
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { spawn } = require('child_process');
const path = require('path');
const readline = require('readline');

const CLI = path.join(__dirname, '..', 'cli.js');

test('info prints level facts', () => {
    const { execFileSync } = require('child_process');
    const out = JSON.parse(execFileSync('node', [CLI, 'info', '--chapter', '1', '--level', '1']));
    assert.equal(out.name, 'Transgalactic Hustler');
    assert.equal(out.blocks.dynamic, 3);
});

test('play session wins level 1-1 over JSONL', { timeout: 240000 }, async () => {
    const child = spawn('node', [CLI, 'play', '--chapter', '1', '--level', '1'], { stdio: ['pipe', 'pipe', 'inherit'] });
    const rl = readline.createInterface({ input: child.stdout });
    const lines = [];
    const waiters = [];
    rl.on('line', (l) => {
        const msg = JSON.parse(l);
        if (waiters.length) waiters.shift()(msg); else lines.push(msg);
    });
    const next = () => lines.length
        ? Promise.resolve(lines.shift())
        : new Promise((r) => waiters.push(r));
    const send = (obj) => child.stdin.write(JSON.stringify(obj) + '\n');

    try {
        const ready = await next();
        assert.equal(ready.ready, true);
        assert.equal(ready.chapter, 1);

        send({ cmd: 'place', x: 1.6765, y: 1.0347, angle: 0 });
        const placed = await next();
        assert.equal(placed.ok, true, JSON.stringify(placed));

        send({ cmd: 'apply' });
        const applied = await next();
        assert.equal(applied.outcome, 'won', JSON.stringify(applied));
        assert.equal(applied.stars, 3);

        send({ cmd: 'quit' });
        const bye = await next();
        assert.equal(bye.ok, true);
    } finally {
        child.kill();
    }
});
```

- [ ] **Step 2: Run to verify failure**

Run: `node --test tools/tests/cli.test.js`
Expected: FAIL — cli.js does not exist.

- [ ] **Step 3: Implement `tools/cli.js`**

```js
#!/usr/bin/env node
// CLI play API for Two Cubes. See docs/superpowers/specs/2026-07-03-cli-play-api-design.md
'use strict';
const readline = require('readline');
const levels = require('./lib/levels');
const { createHarness } = require('./lib/harness');
const { Game } = require('./lib/game');

function parseArgs(argv) {
    const args = { _: [] };
    for (let i = 0; i < argv.length; i++) {
        const a = argv[i];
        if (a.startsWith('--')) {
            const key = a.slice(2);
            const next = argv[i + 1];
            if (next !== undefined && !next.startsWith('--')) { args[key] = next; i++; }
            else args[key] = true;
        } else args._.push(a);
    }
    return args;
}

function cmdInfo(args) {
    const chapter = parseInt(args.chapter, 10);
    if (!chapter) throw new Error('info requires --chapter');
    if (args.level) {
        process.stdout.write(JSON.stringify(levels.levelInfo(chapter, parseInt(args.level, 10)), null, 2) + '\n');
    } else {
        const n = levels.loadChapter(chapter).levels.length;
        const all = Array.from({ length: n }, (_, i) => levels.levelInfo(chapter, i + 1));
        process.stdout.write(JSON.stringify(all, null, 2) + '\n');
    }
}

async function cmdPlay(args) {
    const chapter = args.chapter ? parseInt(args.chapter, 10) : null;
    const level = args.level ? parseInt(args.level, 10) : 1;
    const profile = chapter
        ? levels.searchProfile(chapter, level)
        : { seen_howto: 'true', runout_occured: 'true' };
    const h = await createHarness({
        turbo: !args['no-turbo'],
        headless: !args.headed,
        profile,
    });
    const g = new Game(h);
    let at = { chapter: null, level: null };
    if (chapter) at = await g.gotoLevel(chapter);
    process.stdout.write(JSON.stringify({ ready: true, ...at }) + '\n');

    const rl = readline.createInterface({ input: process.stdin });
    for await (const line of rl) {
        if (!line.trim()) continue;
        let out;
        try {
            const c = JSON.parse(line);
            switch (c.cmd) {
                case 'goto': out = await g.gotoLevel(c.chapter); break;
                case 'place': out = await g.place(c); break;
                case 'apply': out = await g.apply(c.maxTicks || 3600); break;
                case 'restart': out = await g.restartLevel(); break;
                case 'next': out = await g.nextLevel(); break;
                case 'state': out = await g.state(); break;
                case 'cards': out = { cards: await g.cards() }; break;
                case 'info': out = g.info(); break;
                case 'screenshot': await g.screenshot(c.path); out = { path: c.path }; break;
                case 'tick': await h.tick(c.n || 1); out = {}; break;
                case 'quit':
                    process.stdout.write(JSON.stringify({ ok: true, bye: true }) + '\n');
                    await h.close();
                    return;
                default: throw new Error(`unknown cmd: ${c.cmd}`);
            }
            process.stdout.write(JSON.stringify({ ok: true, ...out }) + '\n');
        } catch (err) {
            process.stdout.write(JSON.stringify({ ok: false, error: String(err.message || err) }) + '\n');
        }
    }
    await h.close();
}

async function main() {
    const [cmd, ...rest] = process.argv.slice(2);
    const args = parseArgs(rest);
    switch (cmd) {
        case 'info': cmdInfo(args); break;
        case 'play': await cmdPlay(args); break;
        case 'run': await require('./lib/batch').cmdRun(args); break;      // Task 6
        case 'prove': await require('./lib/prove').cmdProve(args); break;  // Task 7
        default:
            process.stderr.write('usage: cli.js <info|play|run|prove> [--flags]\n');
            process.exit(2);
    }
}

main().catch((err) => { console.error(err); process.exit(1); });
```

Note: `place` responses spread `{ok: true, ...out}` where `out.ok` may be `false` (overlap) — the spread means the placement verdict wins, which is intended: callers read the single `ok` field.

- [ ] **Step 4: Run the test**

Run: `node --test tools/tests/cli.test.js`
Expected: PASS (2 tests). (`run`/`prove` requires are lazy, so their absence doesn't break `info`/`play`.)

- [ ] **Step 5: Commit**

```bash
git add tools/cli.js tools/tests/cli.test.js
git commit -m "cli-play: CLI with info and interactive JSONL play mode"
```

---

### Task 6: Batch scenario runner (`run`)

**Files:**
- Create: `tools/lib/batch.js`
- Test: `tools/tests/batch.test.js`

**Interfaces:**
- Consumes: `Game`, `createHarness`, `levels.searchProfile`.
- Produces: `cmdRun(args)` for `node tools/cli.js run <scenarios.json> [--parallel N] [--out results.jsonl]`:
  - Input file: `[{“chapter”: C, “level”: L, “cards”: [{x, y, angle, static}]}, ...]` (plain JSON array).
  - Output: one JSON line per scenario `{index, chapter, level, outcome, stars?, ticks, placed, rejected?}` to `--out` file (default stdout).
  - Also exports `runScenarios(scenarios, {parallel}) -> Promise<results[]>` for programmatic use (the solver in Task 8 uses this).
  - Workers: `min(parallel, scenarios.length)` harnesses; scenarios grouped by `chapter:level` so a worker seeds one profile and iterates its group with `restartLevel()` between scenarios (no reloads).

- [ ] **Step 1: Write the failing test**

```js
// tools/tests/batch.test.js
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { runScenarios } = require('../lib/batch');

test('batch reports won/failed per scenario', { timeout: 300000 }, async () => {
    const scenarios = [
        { chapter: 1, level: 1, cards: [{ x: 1.6765, y: 1.0347, angle: 0 }] }, // bridge: wins
        { chapter: 1, level: 1, cards: [{ x: 0.6, y: 2.0, angle: 0 }] },       // off target: fails
        { chapter: 1, level: 1, cards: [{ x: 3.5, y: 2.0, angle: 0 }] },       // off target: fails
    ];
    const results = await runScenarios(scenarios, { parallel: 1 });
    assert.equal(results.length, 3);
    assert.equal(results[0].outcome, 'won');
    assert.equal(results[1].outcome, 'failed');
    assert.equal(results[2].outcome, 'failed');
    assert.equal(results[0].index, 0);
});
```

- [ ] **Step 2: Run to verify failure**

Run: `node --test tools/tests/batch.test.js`
Expected: FAIL — module missing.

- [ ] **Step 3: Implement `tools/lib/batch.js`**

```js
// Batch scenario runner: the "test thousands of scenarios fast" clause.
'use strict';
const fs = require('fs');
const levels = require('./levels');
const { createHarness } = require('./harness');
const { Game } = require('./game');

async function runScenarios(scenarios, { parallel = 4, onResult = null } = {}) {
    // Group by level so each worker keeps one warm page per level.
    const groups = new Map();
    scenarios.forEach((s, index) => {
        const key = `${s.chapter}:${s.level}`;
        if (!groups.has(key)) groups.set(key, []);
        groups.get(key).push({ ...s, index });
    });
    const queue = [...groups.values()];
    const results = new Array(scenarios.length);

    async function worker() {
        while (queue.length) {
            const group = queue.shift();
            const { chapter, level } = group[0];
            const h = await createHarness({ profile: levels.searchProfile(chapter, level) });
            const g = new Game(h);
            try {
                await g.gotoLevel(chapter);
                for (const sc of group) {
                    const r = await playScenario(g, sc);
                    results[sc.index] = r;
                    if (onResult) onResult(r);
                }
            } finally {
                await h.close();
            }
        }
    }

    async function playScenario(g, sc) {
        const base = { index: sc.index, chapter: sc.chapter, level: sc.level };
        const restart = await g.restartLevel();
        if (!restart.ok) return { ...base, outcome: 'error', error: 'restart failed' };
        let placed = 0;
        const rejected = [];
        for (const card of sc.cards) {
            const p = await g.place(card);
            if (p.ok) placed++; else rejected.push({ card, reason: p.reason });
        }
        if (placed === 0) return { ...base, outcome: 'error', error: 'no card placed', rejected };
        const r = await g.apply(sc.maxTicks || 3600);
        return { ...base, outcome: r.outcome, stars: r.stars, ticks: r.ticks, placed, ...(rejected.length ? { rejected } : {}) };
    }

    const n = Math.max(1, Math.min(parallel, queue.length));
    await Promise.all(Array.from({ length: n }, worker));
    return results;
}

async function cmdRun(args) {
    const file = args._[0];
    if (!file) throw new Error('run requires a scenarios JSON file');
    const scenarios = JSON.parse(fs.readFileSync(file, 'utf8'));
    const out = args.out ? fs.createWriteStream(args.out) : process.stdout;
    const started = Date.now();
    const results = await runScenarios(scenarios, {
        parallel: parseInt(args.parallel, 10) || 4,
        onResult: (r) => out.write(JSON.stringify(r) + '\n'),
    });
    const won = results.filter((r) => r && r.outcome === 'won').length;
    process.stderr.write(`ran ${results.length} scenarios in ${((Date.now() - started) / 1000).toFixed(1)}s, ${won} won\n`);
    if (args.out) out.end();
}

module.exports = { runScenarios, cmdRun };
```

- [ ] **Step 4: Run the test**

Run: `node --test tools/tests/batch.test.js`
Expected: PASS. Note the wall-clock printed — a 3-scenario single-level group should run in well under a minute after the initial boot.

- [ ] **Step 5: Commit**

```bash
git add tools/lib/batch.js tools/tests/batch.test.js
git commit -m "cli-play: batch scenario runner with warm-page groups and parallel workers"
```

---

### Task 7: Video proof mode (`prove`)

**Files:**
- Create: `tools/lib/prove.js`
- Create: `.gitignore` entry for `proofs/`
- Test: `tools/tests/prove.test.js`

**Interfaces:**
- Consumes: `Game`, `createHarness` (with `realTime: true, turbo: false, videoDir`), `levels`.
- Produces: `cmdProve(args)` for `node tools/cli.js prove [--solutions solutions] [--out proofs] [--chapter C] [--levels N]`:
  - Reads `solutions/chapter_C.json` files: `{"chapter": C, "levels": [{"level": 1, "cards": [{x, y, angle, static}]}, ...]}`.
  - Plays each chapter start-to-finish in real time (stock rAF, real rendering, stock attempts) in a video-recorded context; localStorage is carried from one chapter to the next so chapter unlocks are earned, not seeded.
  - Writes `proofs/chapter_C.webm` and `proofs/summary.json`: `{startedAt, chapters: [{chapter, video, levels: [{level, outcome, stars, cards}], completed}]}`.
  - Failure runs are recorded identically; the summary says `outcome: 'failed'|'timeout'` — video + summary is the proof either way.
  - Also exports `proveChapter(chapter, solution, {outDir, profile, levelsLimit}) -> {video, levels, profile}` for tests.

**Real-time apply:** in real mode ticks flow by themselves, so waiting for a result means polling `__harness.events` / the fail tooltip on wall-clock. Add this method to the `Game` class in `game.js` as part of this task:

```js
    // Real-time counterpart of apply(): physics runs on live rAF; we poll.
    async applyRealtime(timeoutMs = 90000) {
        await this._ensureHelpers();
        await this.page.evaluate((ft) => {
            localStorage.removeItem('apply_fail_occured');
            document.querySelectorAll('.tt').forEach((el) => el.remove());
            window.__game.applyStart = window.__harness.events.length;
            document.querySelector('#toggle-physics').click();
        }, null);
        const deadline = Date.now() + timeoutMs;
        let failSeenAt = 0;
        while (Date.now() < deadline) {
            const s = await this.page.evaluate((ft) => ({
                won: window.__harness.events.length > window.__game.applyStart
                    ? window.__harness.events[window.__harness.events.length - 1] : null,
                fail: [...document.querySelectorAll('.tooltip .tooltip-text')]
                    .some((t) => t.textContent.includes(ft)),
            }), FAIL_TEXT);
            if (s.won) return { outcome: 'won', stars: s.won.stars, event: s.won };
            if (s.fail && !failSeenAt) failSeenAt = Date.now();
            if (failSeenAt && Date.now() - failSeenAt > 2500) return { outcome: 'failed' };
            await new Promise((r) => setTimeout(r, 250));
        }
        return { outcome: 'timeout' };
    }
```

- [ ] **Step 1: Write the failing test**

```js
// tools/tests/prove.test.js
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { proveChapter } = require('../lib/prove');

test('prove records a video of a real-time chapter 1 level 1 win', { timeout: 300000 }, async () => {
    const outDir = fs.mkdtempSync(path.join(os.tmpdir(), 'proof-'));
    const solution = {
        chapter: 1,
        levels: [{ level: 1, cards: [{ x: 1.6765, y: 1.0347, angle: 0 }] }],
    };
    const r = await proveChapter(1, solution, { outDir, levelsLimit: 1 });
    assert.equal(r.levels[0].outcome, 'won');
    assert.equal(r.levels[0].stars, 3);
    const st = fs.statSync(r.video);
    assert.ok(st.size > 20000, `video too small: ${st.size}`);
});
```

- [ ] **Step 2: Run to verify failure**

Run: `node --test tools/tests/prove.test.js`
Expected: FAIL — module missing.

- [ ] **Step 3: Implement `tools/lib/prove.js`**

```js
// Video proof mode: replay stored solutions in real time with recording.
'use strict';
const fs = require('fs');
const path = require('path');
const { createHarness } = require('./harness');
const { Game } = require('./game');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function proveChapter(chapter, solution, { outDir, profile = {}, levelsLimit = Infinity } = {}) {
    fs.mkdirSync(outDir, { recursive: true });
    const h = await createHarness({
        turbo: false,
        realTime: true,
        videoDir: outDir,
        profile: { seen_howto: 'true', runout_occured: 'true', ...profile },
    });
    const g = new Game(h);
    const levelResults = [];
    let exportedProfile = null;
    const video = h.page.video();
    try {
        let at = await g.gotoLevel(chapter);
        for (const sol of solution.levels) {
            if (sol.level > levelsLimit) break;
            if (at.level !== sol.level) {
                levelResults.push({ level: sol.level, outcome: 'skipped', error: `game is at level ${at.level}` });
                break;
            }
            await sleep(800); // let the level-name banner show on camera
            let placedAll = true;
            for (const card of sol.cards) {
                const p = await g.place(card);
                if (!p.ok) { placedAll = false; levelResults.push({ level: sol.level, outcome: 'error', error: `placement rejected: ${p.reason}` }); break; }
                await sleep(350); // watchable pacing
            }
            if (!placedAll) break;
            const r = await g.applyRealtime();
            levelResults.push({ level: sol.level, outcome: r.outcome, stars: r.stars, cards: sol.cards.length });
            if (r.outcome !== 'won') break;
            await sleep(1500); // show the star rating on camera
            const hasNext = sol.level < 12 && solution.levels.some((s) => s.level === sol.level + 1) && sol.level + 1 <= levelsLimit;
            if (hasNext) at = await g.nextLevel();
        }
        exportedProfile = await h.exportProfile();
        await sleep(1000);
    } finally {
        await h.close(); // finalizes the video file
    }
    const rawVideo = await video.path();
    const finalVideo = path.join(outDir, `chapter_${chapter}.webm`);
    fs.renameSync(rawVideo, finalVideo);
    return { video: finalVideo, levels: levelResults, profile: exportedProfile };
}

async function cmdProve(args) {
    const solutionsDir = args.solutions || 'solutions';
    const outDir = args.out || 'proofs';
    const only = args.chapter ? [parseInt(args.chapter, 10)] : [1, 2, 3];
    const levelsLimit = args.levels ? parseInt(args.levels, 10) : Infinity;
    const summary = { startedAt: new Date().toISOString(), chapters: [] };
    let profile = {};
    for (const chapter of only) {
        const file = path.join(solutionsDir, `chapter_${chapter}.json`);
        if (!fs.existsSync(file)) {
            summary.chapters.push({ chapter, error: `missing ${file}` });
            continue;
        }
        const solution = JSON.parse(fs.readFileSync(file, 'utf8'));
        process.stderr.write(`proving chapter ${chapter}...\n`);
        const r = await proveChapter(chapter, solution, { outDir, profile, levelsLimit });
        // Carry earned progress (stars/levels) into the next chapter: unlocks
        // are earned, not seeded.
        profile = r.profile || profile;
        summary.chapters.push({
            chapter,
            video: r.video,
            levels: r.levels,
            completed: r.levels.length === 12 && r.levels.every((l) => l.outcome === 'won'),
        });
    }
    fs.mkdirSync(outDir, { recursive: true });
    fs.writeFileSync(path.join(outDir, 'summary.json'), JSON.stringify(summary, null, 2));
    process.stdout.write(JSON.stringify(summary, null, 2) + '\n');
}

module.exports = { proveChapter, cmdProve };
```

- [ ] **Step 4: Add `proofs/` to `.gitignore`**

Create or append to `.gitignore`:

```
proofs/
```

- [ ] **Step 5: Run the test**

Run: `node --test tools/tests/prove.test.js`
Expected: PASS; a real `.webm` lands in the temp dir. Optionally eyeball it.

- [ ] **Step 6: Commit**

```bash
git add tools/lib/prove.js tools/lib/game.js tools/tests/prove.test.js .gitignore
git commit -m "cli-play: real-time video proof mode"
```

---

### Task 8: Solver harness (`tools/solve.js`)

**Files:**
- Create: `tools/solve.js`
- Create: `solutions/` (output dir, committed)
- Test: `tools/tests/solve.test.js`

**Interfaces:**
- Consumes: `levels.levelInfo`, `runScenarios` (Task 6).
- Produces:
  - `generateCandidates(info, {rounds}) -> [{cards: [...]}, ...]` — heuristic candidate generator.
  - `solveLevel(chapter, level, {parallel, rounds}) -> {cards, stars} | null` — searches candidates, prefers fewest cards / most stars.
  - CLI: `node tools/solve.js --chapter C [--level L] [--parallel N]` — solves and merges results into `solutions/chapter_C.json` (existing solved levels kept unless `--force`).

**Generator heuristics** (all in world units, using `info.from`/`info.to` cube rects, `info.gravity` sign, card w=0.5294):
1. *flat-bridge*: cubes roughly level and close → 1..n cards in a row spanning cube tops (or bottoms when gravity > 0, since blocks fall upward), y = cube top + card half-height + 0.02, overlapping ends.
2. *incline*: straight chain of cards along the from-top → to-top segment, angle = segment angle snapped to π/72, spaced 0.9 × card-width, each lifted 0.03 above the line.
3. *tower*: for vertical separations — vertical cards (angle π/2) stacked from the lower cube up to the higher one, capped with one flat card.
4. *jitter*: for every base candidate, `rounds` random variants with gaussian noise (σ = 0.06 wu position, ±2 steps angle) — this is where "thousands of scenarios" get spent.
Static blocks: if `info.blocks.dynamic` is 0, generate the same shapes with `static: true`; if mixed, try dynamic-first.

- [ ] **Step 1: Write the failing test**

```js
// tools/tests/solve.test.js
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { generateCandidates, solveLevel } = require('../solve');
const levels = require('../lib/levels');

test('generator produces in-budget candidates for 1-1', () => {
    const info = levels.levelInfo(1, 1);
    const cands = generateCandidates(info, { rounds: 5 });
    assert.ok(cands.length >= 10);
    for (const c of cands) {
        assert.ok(c.cards.length >= 1);
        assert.ok(c.cards.filter((k) => !k.static).length <= info.blocks.dynamic);
        assert.ok(c.cards.filter((k) => k.static).length <= info.blocks.static);
    }
});

test('solveLevel cracks chapter 1 level 1', { timeout: 600000 }, async () => {
    const sol = await solveLevel(1, 1, { parallel: 2, rounds: 8 });
    assert.ok(sol, 'no solution found');
    assert.ok(sol.stars >= 1);
    assert.ok(sol.cards.length <= 3);
});
```

- [ ] **Step 2: Run to verify failure**

Run: `node --test tools/tests/solve.test.js`
Expected: FAIL — module missing.

- [ ] **Step 3: Implement `tools/solve.js`**

```js
#!/usr/bin/env node
// Heuristic solver: generates placement candidates per level and searches
// them through the batch runner. Claude drives `cli.js play` for levels the
// generator can't crack, then records the manual solution here.
'use strict';
const fs = require('fs');
const path = require('path');
const levels = require('./lib/levels');
const { runScenarios } = require('./lib/batch');

const STEP = Math.PI / 72;
const CARD_W = levels.CARD.w;
const CARD_H = levels.CARD.h;

function snap(angle) { return Math.round(angle / STEP) * STEP; }

function center(rect) { return { x: rect.x + rect.w / 2, y: rect.y + rect.h / 2 }; }

function generateCandidates(info, { rounds = 20 } = {}) {
    const up = info.gravity > 0; // blocks fall upward
    const A = center(info.from), B = center(info.to);
    const restY = (rect) => (up ? rect.y - CARD_H / 2 - 0.02 : rect.y + rect.h + CARD_H / 2 + 0.02);
    const yA = restY(info.from), yB = restY(info.to);
    const budgetD = info.blocks.dynamic, budgetS = info.blocks.static;
    const asStatic = budgetD === 0;
    const bases = [];

    const mk = (cards) => {
        const d = cards.filter((c) => !c.static).length;
        const s = cards.filter((c) => c.static).length;
        if (d <= budgetD && s <= budgetS && cards.length > 0) bases.push({ cards });
    };

    // 1. flat bridge(s) across the gap at resting height
    const span = Math.abs(B.x - A.x);
    for (let n = 1; n <= Math.min(4, budgetD + budgetS); n++) {
        if (n * CARD_W * 0.95 < span - CARD_W) continue; // cannot reach
        const cards = [];
        for (let i = 0; i < n; i++) {
            const t = n === 1 ? 0.5 : i / (n - 1);
            cards.push({
                x: A.x + (B.x - A.x) * t,
                y: (yA + yB) / 2,
                angle: 0,
                static: asStatic,
            });
        }
        mk(cards);
    }

    // 2. inclined chain along the from->to segment
    const segAngle = snap(Math.atan2(yB - yA, B.x - A.x));
    for (let n = 1; n <= Math.min(4, budgetD + budgetS); n++) {
        const cards = [];
        for (let i = 0; i < n; i++) {
            const t = (i + 0.5) / n;
            cards.push({
                x: A.x + (B.x - A.x) * t,
                y: yA + (yB - yA) * t + (up ? -0.03 : 0.03),
                angle: segAngle,
                static: asStatic,
            });
        }
        mk(cards);
    }

    // 3. tower: vertical cards stacked from the lower cube toward the higher
    const dy = Math.abs(yB - yA);
    if (dy > CARD_W / 2) {
        const lower = yA < yB ? A : B;
        const lowY = Math.min(yA, yB);
        const nV = Math.min(Math.ceil(dy / (CARD_W * 0.9)), Math.max(0, budgetD + budgetS - 1));
        const cards = [];
        for (let i = 0; i < nV; i++) {
            cards.push({ x: lower.x, y: lowY + CARD_W / 2 + i * CARD_W * 0.9, angle: Math.PI / 2, static: asStatic });
        }
        cards.push({ x: (A.x + B.x) / 2, y: Math.max(yA, yB), angle: 0, static: asStatic });
        mk(cards);
    }

    // 4. jittered variants of every base
    const out = [...bases];
    for (const base of bases) {
        for (let r = 0; r < rounds; r++) {
            out.push({
                cards: base.cards.map((c) => ({
                    ...c,
                    x: c.x + (Math.random() * 2 - 1) * 0.06,
                    y: c.y + (Math.random() * 2 - 1) * 0.06,
                    angle: snap(c.angle + (Math.random() * 2 - 1) * 2 * STEP),
                })),
            });
        }
    }
    return out;
}

async function solveLevel(chapter, level, { parallel = 4, rounds = 20 } = {}) {
    const info = levels.levelInfo(chapter, level);
    const candidates = generateCandidates(info, { rounds });
    const scenarios = candidates.map((c) => ({ chapter, level, cards: c.cards }));
    process.stderr.write(`level ${chapter}-${level}: trying ${scenarios.length} candidates\n`);
    const results = await runScenarios(scenarios, { parallel });
    const winners = results
        .filter((r) => r && r.outcome === 'won')
        .map((r) => ({ cards: scenarios[r.index].cards, stars: r.stars }));
    if (!winners.length) return null;
    winners.sort((a, b) => (b.stars - a.stars) || (a.cards.length - b.cards.length));
    return winners[0];
}

function mergeSolution(chapter, level, sol) {
    const dir = path.join(__dirname, '..', 'solutions');
    fs.mkdirSync(dir, { recursive: true });
    const file = path.join(dir, `chapter_${chapter}.json`);
    const doc = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : { chapter, levels: [] };
    doc.levels = doc.levels.filter((l) => l.level !== level);
    doc.levels.push({ level, stars: sol.stars, cards: sol.cards });
    doc.levels.sort((a, b) => a.level - b.level);
    fs.writeFileSync(file, JSON.stringify(doc, null, 2));
    return file;
}

async function main() {
    const args = process.argv.slice(2);
    const get = (k) => { const i = args.indexOf(`--${k}`); return i >= 0 ? args[i + 1] : null; };
    const chapter = parseInt(get('chapter'), 10);
    if (!chapter) { console.error('usage: solve.js --chapter C [--level L] [--parallel N] [--rounds R] [--force]'); process.exit(2); }
    const onlyLevel = get('level') ? parseInt(get('level'), 10) : null;
    const parallel = parseInt(get('parallel'), 10) || 4;
    const rounds = parseInt(get('rounds'), 10) || 20;
    const force = args.includes('--force');

    const file = path.join(__dirname, '..', 'solutions', `chapter_${chapter}.json`);
    const have = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')).levels.map((l) => l.level) : [];
    const targets = onlyLevel ? [onlyLevel]
        : Array.from({ length: levels.loadChapter(chapter).levels.length }, (_, i) => i + 1)
            .filter((l) => force || !have.includes(l));

    for (const level of targets) {
        const sol = await solveLevel(chapter, level, { parallel, rounds });
        if (sol) {
            mergeSolution(chapter, level, sol);
            process.stderr.write(`level ${chapter}-${level}: SOLVED with ${sol.cards.length} cards, ${sol.stars} stars\n`);
        } else {
            process.stderr.write(`level ${chapter}-${level}: unsolved — needs interactive play\n`);
        }
    }
}

if (require.main === module) main().catch((e) => { console.error(e); process.exit(1); });
module.exports = { generateCandidates, solveLevel };
```

- [ ] **Step 4: Run the test**

Run: `node --test tools/tests/solve.test.js`
Expected: PASS (the solve test takes a few minutes — it's a real search).

- [ ] **Step 5: Commit**

```bash
git add tools/solve.js tools/tests/solve.test.js
git commit -m "cli-play: heuristic solver writing solutions/chapter_N.json"
```

---

### Task 9: Solve all 36 levels, produce proofs, document

This task is iterative play, not plumbing. Budget most of the wall-clock here.

**Files:**
- Create: `solutions/chapter_1.json`, `solutions/chapter_2.json`, `solutions/chapter_3.json` (committed)
- Modify: `CLAUDE.md` (short section pointing at the CLI), `docs/superpowers/specs/2026-07-03-cli-play-api-design.md` is already committed
- Output (not committed): `proofs/chapter_{1,2,3}.webm`, `proofs/summary.json`

- [ ] **Step 1: Auto-solve chapter 1**

Run: `node tools/solve.js --chapter 1 --parallel 6 --rounds 30`
Expected: most levels solved; stderr lists any `unsolved` levels.

- [ ] **Step 2: Interactive mop-up for unsolved levels**

For each unsolved level L: `node tools/cli.js info --chapter 1 --level L` to read the geometry, then drive `node tools/cli.js play --chapter 1 --level L` with JSONL commands; use `{"cmd":"screenshot","path":"/tmp/claude-.../board.png"}` to see the board, iterate placements (`restart` between attempts), and on a win append the working `cards` array to `solutions/chapter_1.json` in the Task 8 format (`{level, stars, cards}`). Raise `--rounds`, tweak the generator, or add a strategy if a *class* of levels fails rather than one.

- [ ] **Step 3: Repeat for chapters 2 and 3**

Run: `node tools/solve.js --chapter 2 --parallel 6 --rounds 30`, mop up; same for chapter 3. Watch for `gravity > 0` levels (blocks fall up — generator already mirrors) and dynamic obstacles (type 5/6 — timing-free since everything settles deterministically).

- [ ] **Step 4: Star audit**

Sum stars in `solutions/chapter_1.json` + `chapter_2.json`: must be ≥ 60 so chapter 3 is reachable legitimately (and chapter 1 alone ≥ 30 for chapter 2). If short, re-solve the cheapest-to-improve levels with more rounds targeting fewer cards (`stars` field in each level JSON shows the thresholds via `info`).
Run: `node -e "const s=[1,2].map(c=>require('./solutions/chapter_'+c+'.json')); console.log(s.map(d=>d.levels.reduce((a,l)=>a+l.stars,0)))"`

- [ ] **Step 5: Full proof run**

Run: `node tools/cli.js prove --solutions solutions --out proofs`
Expected: `proofs/summary.json` with `completed: true` for chapters 1, 2, 3 and three non-trivial `.webm` files. If a level that won in turbo fails in real time, that's a determinism bug worth investigating (most likely a placement rejected because a tooltip/timer differed — check `rejected` in the summary), not a physics divergence.

- [ ] **Step 6: Verify nothing else broke**

Run: `npm test`
Expected: parity suite still green (no game files were touched).
Run: `npm run test:cli`
Expected: all CLI tests green.

- [ ] **Step 7: Document and commit**

Append to `CLAUDE.md` under Commands:

```markdown
npm run cli -- info --chapter 1 --level 1   # level geometry in world units
npm run cli -- play --chapter 1 --level 1   # machine-play session (JSONL on stdin/stdout)
npm run cli -- run scenarios.json           # batch scenario search (turbo)
npm run cli -- prove                        # replay solutions/ with video -> proofs/
node tools/solve.js --chapter 1             # heuristic auto-solver
npm run test:cli                            # harness self-tests (node --test)
```

And one Architecture bullet:

```markdown
- Machine play: `tools/` drives the real game in headless Chromium (rAF tick
  pump; success hook = `Features.onLevelFinish`). Solutions for all chapters
  live in `solutions/`; `prove` replays them in real time with video. See
  docs/superpowers/specs/2026-07-03-cli-play-api-design.md.
```

```bash
git add solutions CLAUDE.md
git commit -m "cli-play: solutions for all three chapters + docs"
```

---

## Execution notes

- Task order is strict 1→9; each task's tests depend on the previous ones passing.
- Tasks 3 and 9 carry the real risk (mouse-mapping math; level difficulty). Everything else is plumbing around them.
- If turbo throughput disappoints during Task 9 (`run` slower than ~1 scenario/sec/worker), profile before optimizing: the likely lever is chunk size in `applyPhysics` (30 → 120) and placement tick counts, not architecture.

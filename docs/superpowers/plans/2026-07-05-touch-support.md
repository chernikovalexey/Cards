# Touch Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Two Cubes fully playable on touch smartphones with desktop-precision placement (1 px nudge, 2.5° rotate), both orientations, full menu→level→win→next flow.

**Architecture:** A single new script `web/external/touch.js` (loaded by the retrying loader right before `cards.dart.js`) translates touch gestures into the synthetic MouseEvent/KeyboardEvent stream the compiled Dart engine already consumes, overrides the canvas `getBoundingClientRect` with a fixed 800×600 `DOMRect` so CSS scaling never corrupts world math, scales the whole `.game-box` uniformly (letterbox), and renders a two-thumb control chrome. See `docs/superpowers/specs/2026-07-05-touch-support-design.md` for all verified engine facts.

**Tech Stack:** Vanilla ES5-ish JS (matches `webapi.js`/`features.js` style), CSS gated on `.touch-mode`, Playwright (chromium, `hasTouch` + `isMobile`) for tests.

## Global Constraints

- `cards.dart.js` and `web/*.dart` must not change; all changes in `web/external/`, `web/cards.html`, `web/cards.css`, `playwright.config.js`, `tests/`.
- Desktop unchanged: `npm test` (chromium + firefox parity projects) stays green; touch code activates only when `matchMedia('(pointer: coarse)').matches || 'ontouchstart' in window` (query-param escape hatch `?touch=0/1`).
- Synthetic "press" pattern: down-event, then the matching up-event after two `requestAnimationFrame`s (the engine clears one-shot input state at the end of every frame; an early up cancels the action).
- The rect override must return a real `DOMRect` (plain objects crash dart2js interceptors).
- No commits (repo policy: commit only on request); leave changes in the working tree.
- `.buttons`/`.selectors` and other legacy DOM nodes must stay in the DOM (compiled Dart writes into them) — hide with CSS only.

---

### Task 1: Activation core — loader entry, viewport meta, rect override, letterbox refit, mobile test project

**Files:**
- Create: `web/external/touch.js` (activation, rect override, refit; interaction added in Task 2)
- Modify: `web/cards.html` (viewport meta in `<head>`; add `'external/touch.js'` to the loader `scripts` array right before `'cards.dart.js'`)
- Modify: `web/cards.css` (append `.touch-mode` base rules)
- Modify: `playwright.config.js` (add `mobile` project; scope specs per project)
- Create: `tests/mobile.spec.js` (boot test only, more added later)

**Interfaces:**
- Produces: `window.__touch` test/introspection API:
  `__touch.W === 800`, `__touch.H === 600`,
  `__touch.realRect()` → real (scaled) canvas `DOMRect`,
  `__touch.toVirtual(sx, sy)` → `{x, y}` virtual client coords,
  `__touch.liftFor(sy)` → lift px in screen space,
  `__touch.state` → `{scale, portrait, virtual}`.
- Produces: `<html class="touch-mode">` gate for all touch CSS.

- [ ] **Step 1: Write the failing mobile boot test**

`tests/mobile.spec.js`:

```js
// Mobile touch suite. Runs only in the 'mobile' Playwright project
// (chromium, phone viewport, hasTouch) against the local static server.
'use strict';
const { test, expect } = require('@playwright/test');

test.beforeEach(async ({ page }) => {
    await page.goto('/web/cards.html');
});

test('boots on a touch phone: touch mode active, menu visible, canvas letterboxed', async ({ page }) => {
    await expect(page.locator('#new-game')).toBeVisible({ timeout: 30000 });
    await expect(page.locator('html')).toHaveClass(/touch-mode/);
    const fit = await page.evaluate(() => {
        const r = window.__touch.realRect();
        const fake = document.querySelector('#graphics').getBoundingClientRect();
        return {
            cssW: r.width, innerW: innerWidth,
            fakeW: fake.width, fakeH: fake.height,
            scale: window.__touch.state.scale,
        };
    });
    expect(fit.fakeW).toBe(800);           // engine sees unscaled canvas
    expect(fit.fakeH).toBe(600);
    expect(fit.cssW).toBeLessThanOrEqual(fit.innerW + 1);  // letterboxed to viewport
    expect(fit.scale).toBeCloseTo(fit.cssW / 800, 3);
});
```

`playwright.config.js` — replace the `projects` array:

```js
    projects: [
        { name: 'chromium', use: { browserName: 'chromium' }, testIgnore: '**/mobile.spec.js' },
        { name: 'firefox', use: { browserName: 'firefox' }, testIgnore: '**/mobile.spec.js' },
        {
            name: 'mobile',
            testMatch: '**/mobile.spec.js',
            use: {
                browserName: 'chromium',
                viewport: { width: 412, height: 915 },
                hasTouch: true,
                isMobile: true,
                deviceScaleFactor: 2.625,
            },
        },
    ],
```

(Production runs `npm run test:prod` with the same config — mobile project runs there too; the boot test is production-safe, deeper tests use localStorage seeding which is also production-safe. If a prod-only failure shows up, gate with `isLocal` the way parity.spec.js does.)

- [ ] **Step 2: Run it to verify it fails**

Run: `npx playwright test --project=mobile -g "boots on a touch phone"`
Expected: FAIL — `html` lacks `touch-mode`, `window.__touch` undefined.

- [ ] **Step 3: Implement activation core**

`web/cards.html` `<head>` (after the charset meta):

```html
    <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no, viewport-fit=cover"/>
```

`web/cards.html` loader list — insert before `'cards.dart.js'`:

```js
        'external/webapi.js',
        'external/features.js',
        'external/touch.js',
        'cards.dart.js'
```

`web/external/touch.js` (activation + geometry; gesture/chrome sections appended in later tasks):

```js
// Touch support for phones/tablets. Translates touch gestures into the
// synthetic MouseEvent/KeyboardEvent stream the compiled Dart engine
// (cards.dart.js) already listens for, and letterbox-scales the fixed
// 800x600 game to the viewport. Loaded right before cards.dart.js so the
// canvas rect override below is installed before compiled main() runs.
// Design: docs/superpowers/specs/2026-07-05-touch-support-design.md
(function () {
    'use strict';

    var W = 800, H = 600;
    var m = /[?&]touch=([01])/.exec(location.search);
    var forced = m ? m[1] : null;
    var enabled = forced === '1' || (forced !== '0' &&
        ((window.matchMedia && matchMedia('(pointer: coarse)').matches) ||
         'ontouchstart' in window));
    if (!enabled) return;

    document.documentElement.classList.add('touch-mode');

    var state = { scale: 1, portrait: false, virtual: null };

    function canvasEl() { return document.getElementById('graphics'); }

    // The engine derives BOTH pointer mapping and world dimensions
    // (camera bounds, viewport) from this rect; it must always look like
    // an unscaled 800x600 canvas at its real page position. Must be a
    // real DOMRect: dart2js interceptors reject plain objects.
    function realRect() {
        return Element.prototype.getBoundingClientRect.call(canvasEl());
    }
    canvasEl().getBoundingClientRect = function () {
        var r = realRect();
        return new DOMRect(r.left, r.top, W, H);
    };

    // Map a screen point to the engine's virtual (unscaled) client space.
    function toVirtual(sx, sy) {
        var r = realRect();
        return {
            x: r.left + (sx - r.left) * (W / r.width),
            y: r.top + (sy - r.top) * (H / r.height),
        };
    }

    // Ghost floats above the finger; less near the canvas top so high
    // targets stay reachable. Screen-space px.
    function liftFor(sy) {
        var r = realRect();
        return Math.min(70, Math.max(12, 0.35 * (sy - r.top)));
    }

    // ------------------------------------------------------------------
    // Letterbox: scale the whole .game-box (canvas + every dialog)
    // uniformly. Portrait pins it to the top, landscape centers it.
    function refit() {
        var box = document.querySelector('.game-box');
        if (!box) return;
        var vw = window.innerWidth, vh = window.innerHeight;
        state.portrait = vh > vw;
        var s = state.portrait ? vw / W : Math.min(vw / W, vh / H);
        var tx = Math.max(0, (vw - W * s) / 2);
        var ty = state.portrait ? 0 : Math.max(0, (vh - H * s) / 2);
        box.style.transformOrigin = '0 0';
        box.style.transform = 'translate(' + tx + 'px,' + ty + 'px) scale(' + s + ')';
        state.scale = s;
        // The engine re-reads the canvas rect on window resize
        // (updateCanvasPositionAndDimension); flag ours to avoid loops.
        var ev = new Event('resize');
        ev.__touchRefit = true;
        window.dispatchEvent(ev);
    }
    window.addEventListener('resize', function (e) {
        if (!e.__touchRefit) refit();
    });
    window.addEventListener('orientationchange', function () {
        setTimeout(refit, 100);
    });
    refit();

    window.__touch = {
        W: W, H: H, state: state,
        realRect: realRect, toVirtual: toVirtual, liftFor: liftFor,
    };
})();
```

`web/cards.css` — append:

```css
/* ------------------------------------------------------------------ */
/* Touch mode (phones/tablets). Gated on .touch-mode set by touch.js,  */
/* never on bare media queries, so desktop browsers can't match it.    */
/* The .game-box is scaled as one unit by touch.js (inline transform). */

.touch-mode .game-box {
    left: 0;
    margin-left: 0;
}

.touch-mode .loading-overlay {
    width: 100vw;
    left: 0;
    margin-left: 0;
}

.touch-mode .share-offer {
    display: none;
}

/* Desktop control bars are replaced by the touch chrome; nodes must
   stay in the DOM (the compiled Dart writes into them at boot). */
.touch-mode .buttons,
.touch-mode .selectors {
    visibility: hidden !important;
    pointer-events: none;
}

.touch-mode #graphics {
    touch-action: none;
}
```

- [ ] **Step 4: Run the mobile boot test — passes**

Run: `npx playwright test --project=mobile -g "boots on a touch phone"`
Expected: PASS

- [ ] **Step 5: Desktop parity still green**

Run: `npm test`
Expected: all chromium + firefox parity tests pass; mobile project runs only mobile.spec.js.

---

### Task 2: Gesture synthesis + two-thumb chrome (drag, nudge, rotate, snap, commit, park)

**Files:**
- Modify: `web/external/touch.js` (event synthesis, gestures, chrome UI)
- Modify: `web/cards.css` (chrome styling)
- Modify: `tests/mobile.spec.js` (placement-precision tests)

**Interfaces:**
- Consumes: `toVirtual`, `liftFor`, `realRect`, `state` from Task 1.
- Produces: chrome buttons with ids `#touch-rl` (⟲), `#touch-rr` (⟳), `#touch-sh` (—), `#touch-sv` (|), `#touch-ok` (✓), `#touch-no` (✕), `#touch-up/down/left/right` (nudge), `#touch-apply`, `#touch-restart`, `#touch-blocks`, `#touch-hint`, `#touch-trash` (🗑, Task 3), containers `#touch-top`, `#touch-cluster-l`, `#touch-cluster-r`, feedback nodes `#touch-toast`, `#touch-flash`.
- Produces: `__touch.moveGhost(vx, vy)`, `__touch.commit()`, `__touch.park()`, `__touch.nudge(dx, dy)`, `__touch.pressKey(code)` (all also used by tests).

**Key facts for the implementer** (verified, see spec §1): Q=81 E=69 C=67 V=86 Enter=13 Space=32 Esc=27 Delete=46; rotate step is 2.5° per Q/E *keydown* (one-shot `.clicked`); nudge must NOT use WASD (frame-timed, non-deterministic) — move a virtual cursor ±1 px in virtual client space and send `mousemove`; place = left `mousedown` (+delayed `mouseup`); ghost parks wherever the last `mousemove` left it.

- [ ] **Step 1: Write failing precision tests**

Append to `tests/mobile.spec.js`:

```js
const levels = require('../tools/lib/levels');

// Screen point whose lifted ghost lands exactly on virtual client (vx, vy).
// Inverse of touch.js dragGhostTo: ghost = toVirtual(sx, sy - liftFor(sy)).
async function fingerFor(page, vx, vy) {
    return page.evaluate(([vx, vy]) => {
        const r = window.__touch.realRect();
        const sx = r.left + (vx - r.left) * (r.width / 800);
        const gy = r.top + (vy - r.top) * (r.height / 600); // ghost screen y
        // lift = clamp(0.35 * (sy - top), 12, 70), ghost = sy - lift; solve for sy.
        let sy = (gy - 0.35 * r.top) / 0.65;                // assume mid-range lift
        const lift = Math.min(70, Math.max(12, 0.35 * (sy - r.top)));
        if (lift === 12 || lift === 70) sy = gy + lift;     // clamped: constant offset
        return [sx, sy];
    }, [vx, vy]);
}

// Virtual client coords for a world point (fake rect: real left/top, 800x600).
async function clientForWorld(page, chapter, level, wx, wy) {
    const raw = levels.loadChapter(chapter).levels[level - 1];
    const r = await page.evaluate(() => {
        const q = window.__touch.realRect();
        return { left: q.left, top: q.top, width: 800, height: 600 };
    });
    return levels.worldToClient(wx, wy, raw, r);
}

// Esc-pause persists exact card state to localStorage (same probe the
// machine-play harness uses); resume afterwards.
async function probeCards(page) {
    return page.evaluate(async () => {
        const key = 'level_' + JSON.parse(localStorage.getItem('last')).chapter +
            '_' + JSON.parse(localStorage.getItem('last')).level;
        window.dispatchEvent(new KeyboardEvent('keydown', { keyCode: 27, which: 27, bubbles: true }));
        await new Promise((r) => setTimeout(r, 300));
        window.dispatchEvent(new KeyboardEvent('keyup', { keyCode: 27, which: 27, bubbles: true }));
        const raw = localStorage.getItem(key);
        const resume = document.querySelector('#resume-game');
        if (resume) resume.click();
        await new Promise((r) => setTimeout(r, 300));
        return raw ? JSON.parse(raw).c : [];
    });
}

async function enterLevel11(page) {
    await page.addInitScript(() => {
        localStorage.setItem('seen_howto', 'true');
        localStorage.setItem('runout_occured', 'true');
        localStorage.setItem('apply_fail_occured', 'true');
    });
    await page.goto('/web/cards.html');
    await expect(page.locator('#new-game')).toBeVisible({ timeout: 30000 });
    await page.locator('#new-game').tap();
    await expect(page.locator('#chapter-selection')).toBeVisible();
    await page.locator('.chapter[data-id="1"]').tap();
    await page.waitForFunction(() => {
        const l = localStorage.getItem('last');
        return l && JSON.parse(l).chapter === 1;
    }, null, { timeout: 30000 });
    await page.waitForTimeout(2000);          // camera settle animation
    await page.locator('#graphics').tap();    // clear tutorial hint card/tooltips
    await page.waitForTimeout(300);
    await expect(page.locator('#touch-ok')).toBeVisible();
}

test('drag parks the lifted ghost; checkmark places with world precision', async ({ page }) => {
    await enterLevel11(page);
    const target = await clientForWorld(page, 1, 1, 2.5, 1.5);
    const [sx, sy] = await fingerFor(page, target.clientX, target.clientY);
    // touchstart/move/end: ghost follows with lift, then parks
    await page.locator('#graphics').dispatchEvent('touchstart', {}); // replaced by CDP below
    // (real gesture via touchscreen)
    await page.touchscreen.tap(sx, sy);
    await page.locator('#touch-ok').tap();
    await page.waitForTimeout(400);
    const cards = await probeCards(page);
    expect(cards.length).toBe(1);
    expect(cards[0].x).toBeCloseTo(2.5, 1);
    expect(cards[0].y).toBeCloseTo(1.5, 1);
});

test('nudge pad moves exactly 1px per tap; rotate exactly 2.5deg per tap', async ({ page }) => {
    await enterLevel11(page);
    const target = await clientForWorld(page, 1, 1, 2.5, 1.5);
    const [sx, sy] = await fingerFor(page, target.clientX, target.clientY);
    await page.touchscreen.tap(sx, sy);
    for (let i = 0; i < 5; i++) await page.locator('#touch-right').tap();
    for (let i = 0; i < 3; i++) await page.locator('#touch-rl').tap();
    await page.locator('#touch-ok').tap();
    await page.waitForTimeout(400);
    const cards = await probeCards(page);
    expect(cards.length).toBe(1);
    expect(cards[0].x).toBeCloseTo(2.5 + 5 / 85, 2);   // 5 px right = 5/NSCALE world
    expect(cards[0].a).toBeCloseTo(3 * Math.PI / 72, 3); // 3 rotate taps = 7.5deg
});
```

Remove the stray `dispatchEvent('touchstart', ...)` line from the first test before running (tap covers it).

- [ ] **Step 2: Run to verify failure**

Run: `npx playwright test --project=mobile -g "nudge pad"`
Expected: FAIL — `#touch-ok` not found (chrome doesn't exist yet).

- [ ] **Step 3: Implement synthesis + gestures + chrome**

Replace the closing of `touch.js` (`window.__touch = {...}; })();`) with the following sections, keeping everything from Task 1 above them:

```js
    // ------------------------------------------------------------------
    // Synthetic events. The engine clears one-shot input state at the end
    // of every frame; the paired "up" event must arrive at least one
    // engine frame after "down" or the action is cancelled — hence raf2.
    function raf2(fn) {
        requestAnimationFrame(function () { requestAnimationFrame(fn); });
    }
    function mouse(type, vx, vy, button) {
        canvasEl().dispatchEvent(new MouseEvent(type, {
            bubbles: true, cancelable: true, view: window,
            clientX: vx, clientY: vy, button: button || 0,
        }));
    }
    function key(type, code) {
        window.dispatchEvent(new KeyboardEvent(type, {
            keyCode: code, which: code, bubbles: true,
        }));
    }
    function pressKey(code) {
        key('keydown', code);
        raf2(function () { key('keyup', code); });
    }
    var KEY = { space: 32, q: 81, e: 69, c: 67, v: 86 };

    function moveGhost(vx, vy) {
        state.virtual = { x: vx, y: vy };
        mouse('mousemove', vx, vy);
    }
    function nudge(dx, dy) {
        if (state.virtual) moveGhost(state.virtual.x + dx, state.virtual.y + dy);
    }
    function park() {
        var r = realRect();
        moveGhost(r.left - 150, r.top - 150);
    }

    function remaining() {
        var grab = function (sel) {
            var el = document.querySelector(sel);
            var mm = el && el.textContent.match(/\d+/);
            return mm ? parseInt(mm[0], 10) : null;
        };
        return { d: grab('.dynamic .remaining'), s: grab('.static .remaining') };
    }

    function commit() {
        if (!state.virtual) return;
        var before = remaining();
        var v = state.virtual;
        mouse('mousedown', v.x, v.y, 0);
        raf2(function () {
            mouse('mouseup', v.x, v.y, 0);
            raf2(function () {
                var after = remaining();
                var placed = (before.d !== null && after.d === before.d - 1) ||
                             (before.s !== null && after.s === before.s - 1);
                if (!placed) rejectFeedback();
            });
        });
    }

    // ------------------------------------------------------------------
    // Canvas gestures: 1-finger drag moves the lifted ghost; lifting the
    // finger parks it. Quick tap offers delete (Task 3). Two fingers pan
    // (Space+left-drag) and pinch (zoom button clicks) — Task 4.
    var tap = null;   // {x, y, t, moved}

    function dragGhostTo(sx, sy) {
        var v = toVirtual(sx, sy - liftFor(sy));
        moveGhost(v.x, v.y);
    }

    canvasEl().addEventListener('touchstart', function (e) {
        e.preventDefault();
        hideTrash();
        if (e.touches.length === 1) {
            var t = e.touches[0];
            tap = { x: t.clientX, y: t.clientY, t: Date.now(), moved: false };
            dragGhostTo(t.clientX, t.clientY);
        } else if (e.touches.length === 2) {
            tap = null;
            startPan(e);
        }
    }, { passive: false });

    canvasEl().addEventListener('touchmove', function (e) {
        e.preventDefault();
        if (pan && e.touches.length >= 2) { movePan(e); return; }
        if (e.touches.length === 1) {
            var t = e.touches[0];
            if (tap && Math.hypot(t.clientX - tap.x, t.clientY - tap.y) > 10) tap.moved = true;
            dragGhostTo(t.clientX, t.clientY);
        }
    }, { passive: false });

    canvasEl().addEventListener('touchend', function (e) {
        e.preventDefault();
        if (pan && e.touches.length < 2) { endPan(); return; }
        if (tap && !tap.moved && Date.now() - tap.t < 300) {
            // Bubbling click clears tutorial tooltips/hint cards exactly
            // like a desktop body click, and arms the delete affordance.
            canvasEl().dispatchEvent(new MouseEvent('click', {
                bubbles: true, clientX: tap.x, clientY: tap.y,
            }));
            showTrash(tap.x, tap.y);
        }
        tap = null;
    }, { passive: false });
    canvasEl().addEventListener('touchcancel', function () {
        tap = null;
        if (pan) endPan();
    });

    // ------------------------------------------------------------------
    // Chrome: two thumb clusters + top bar. Built only in touch mode so
    // the desktop DOM is untouched.
    function btn(id, label, cls) {
        var b = document.createElement('button');
        b.id = id;
        b.className = 'touch-btn ' + (cls || '');
        b.innerHTML = label;
        return b;
    }

    // Tap = one action; holding repeats it (rotate 120ms, nudge 50ms).
    function holdable(el, act, interval) {
        var timer = null;
        el.addEventListener('touchstart', function (e) {
            e.preventDefault();
            e.stopPropagation();
            act();
            timer = setInterval(act, interval || 120);
        }, { passive: false });
        var stop = function () { clearInterval(timer); timer = null; };
        el.addEventListener('touchend', stop);
        el.addEventListener('touchcancel', stop);
    }

    var top = document.createElement('div');
    top.id = 'touch-top';
    var applyBtn = btn('touch-apply', '⚡ Apply');
    var restartBtn = btn('touch-restart', '↺ Restart');
    var blocksBtn = btn('touch-blocks', '▤');
    var hintBtn = btn('touch-hint', '💡');
    top.appendChild(applyBtn); top.appendChild(restartBtn);
    top.appendChild(blocksBtn); top.appendChild(hintBtn);

    var left = document.createElement('div');
    left.id = 'touch-cluster-l';
    var rl = btn('touch-rl', '⟲'), rr = btn('touch-rr', '⟳');
    var sh = btn('touch-sh', '—'), sv = btn('touch-sv', '|');
    var ok = btn('touch-ok', '✓', 'touch-ok'), no = btn('touch-no', '✕', 'touch-no');
    [rl, rr, sh, sv, ok, no].forEach(function (b) { left.appendChild(b); });

    var right = document.createElement('div');
    right.id = 'touch-cluster-r';
    var up = btn('touch-up', '▲'), dn = btn('touch-down', '▼');
    var lf = btn('touch-left', '◀'), rt = btn('touch-right', '▶');
    [up, lf, rt, dn].forEach(function (b) { right.appendChild(b); });

    var toast = document.createElement('div');
    toast.id = 'touch-toast';
    var flash = document.createElement('div');
    flash.id = 'touch-flash';

    function mountChrome() {
        document.body.appendChild(top);
        document.body.appendChild(left);
        document.body.appendChild(right);
        document.body.appendChild(toast);
        document.body.appendChild(flash);
    }
    if (document.body) mountChrome();
    else document.addEventListener('DOMContentLoaded', mountChrome);

    holdable(rl, function () { pressKey(KEY.q); });
    holdable(rr, function () { pressKey(KEY.e); });
    sh.addEventListener('touchstart', function (e) { e.preventDefault(); pressKey(KEY.c); }, { passive: false });
    sv.addEventListener('touchstart', function (e) { e.preventDefault(); pressKey(KEY.v); }, { passive: false });
    ok.addEventListener('touchstart', function (e) { e.preventDefault(); commit(); }, { passive: false });
    no.addEventListener('touchstart', function (e) { e.preventDefault(); park(); }, { passive: false });
    holdable(up, function () { nudge(0, -1); }, 50);
    holdable(dn, function () { nudge(0, 1); }, 50);
    holdable(lf, function () { nudge(-1, 0); }, 50);
    holdable(rt, function () { nudge(1, 0); }, 50);

    applyBtn.addEventListener('touchstart', function (e) {
        e.preventDefault();
        var el = document.getElementById('toggle-physics');
        if (el) el.click();
    }, { passive: false });
    restartBtn.addEventListener('touchstart', function (e) {
        e.preventDefault();
        var el = document.getElementById('restart');
        if (el) el.click();
    }, { passive: false });
    blocksBtn.addEventListener('touchstart', function (e) {
        e.preventDefault();
        var current = document.querySelector('.selector.current');
        var other = (current && current.classList.contains('dynamic'))
            ? document.querySelector('.selector.static')
            : document.querySelector('.selector.dynamic');
        if (other && !other.hidden) other.click();
    }, { passive: false });
    hintBtn.addEventListener('touchstart', function (e) {
        e.preventDefault();
        var el = document.getElementById('hint');
        if (el) el.click();
    }, { passive: false });

    // ------------------------------------------------------------------
    // Feedback (rejection UX; engine rejection is silent).
    var toastTimer = null;
    function rejectFeedback() {
        flash.classList.add('on');
        setTimeout(function () { flash.classList.remove('on'); }, 450);
        toast.textContent = 'Too close — leave a small gap';
        toast.classList.add('on');
        clearTimeout(toastTimer);
        toastTimer = setTimeout(function () { toast.classList.remove('on'); }, 2500);
        if (navigator.vibrate) navigator.vibrate(50);
    }

    // ------------------------------------------------------------------
    // Chrome visibility + labels: poll cheap DOM state (no rAF hook into
    // the engine exists). In a level = .buttons unhidden; physics applied
    // = #toggle-physics has .rewind; dialog up = any visible .light-box
    // or an open .bs-screen.
    function dialogUp() {
        var boxes = document.querySelectorAll('.light-box');
        for (var i = 0; i < boxes.length; i++) {
            if (!boxes[i].classList.contains('hidden')) return true;
        }
        var screens = document.querySelectorAll('.bs-screen');
        for (var j = 0; j < screens.length; j++) {
            var r = screens[j].getBoundingClientRect();
            if (r.height > 0 && r.top < window.innerHeight / 2) return true;
        }
        return false;
    }
    setInterval(function () {
        var buttons = document.querySelector('.buttons');
        var toggle = document.getElementById('toggle-physics');
        var inLevel = !!buttons && !buttons.classList.contains('hidden');
        var physics = !!toggle && toggle.classList.contains('rewind');
        var dlg = dialogUp();
        top.style.display = inLevel && !dlg ? 'flex' : 'none';
        var clusters = inLevel && !physics && !dlg ? 'grid' : 'none';
        left.style.display = clusters;
        right.style.display = clusters;
        applyBtn.innerHTML = physics ? '⏪ Rewind' : '⚡ Apply';
        var rem = remaining();
        var cur = document.querySelector('.selector.current');
        var isStatic = !!cur && cur.classList.contains('static');
        blocksBtn.innerHTML = (isStatic ? '▤ static ' : '▦ dynamic ') +
            (isStatic ? (rem.s === null ? '' : rem.s) : (rem.d === null ? '' : rem.d));
    }, 200);

    // Delete affordance (wired fully in Task 3).
    var trash = btn('touch-trash', '🗑');
    trash.style.display = 'none';
    function showTrash(sx, sy) { /* Task 3 */ }
    function hideTrash() { trash.style.display = 'none'; }

    // Pan/pinch stubs (Task 4).
    var pan = null;
    function startPan(e) { /* Task 4 */ }
    function movePan(e) { /* Task 4 */ }
    function endPan() { /* Task 4 */ }

    window.__touch = {
        W: W, H: H, state: state,
        realRect: realRect, toVirtual: toVirtual, liftFor: liftFor,
        moveGhost: moveGhost, nudge: nudge, commit: commit, park: park,
        pressKey: pressKey,
    };
})();
```

Note: `var pan`/function hoisting keeps the earlier references valid; keep all sections inside the same IIFE.

`web/cards.css` — append:

```css
.touch-btn {
    min-width: 48px;
    min-height: 48px;
    border: none;
    border-radius: 10px;
    background: rgba(36, 48, 64, 0.9);
    color: #cfd8e3;
    font-size: 20px;
    -webkit-user-select: none;
    user-select: none;
    touch-action: none;
}

.touch-btn:active {
    background: rgba(57, 70, 90, 0.95);
}

#touch-top {
    display: none;
    position: fixed;
    top: 4px;
    left: 50%;
    transform: translateX(-50%);
    gap: 8px;
    z-index: 40;
}

#touch-top .touch-btn {
    font-size: 15px;
    padding: 0 10px;
    white-space: nowrap;
}

#touch-cluster-l,
#touch-cluster-r {
    display: none;
    position: fixed;
    bottom: 18px;
    grid-gap: 10px;
    z-index: 40;
}

#touch-cluster-l {
    left: 12px;
    grid-template-columns: repeat(2, 52px);
}

#touch-cluster-r {
    right: 12px;
    grid-template-columns: repeat(3, 52px);
    grid-template-areas: ". up ." "lf . rt" ". dn .";
}

#touch-up { grid-area: up; }
#touch-down { grid-area: dn; }
#touch-left { grid-area: lf; }
#touch-right { grid-area: rt; }

.touch-ok { background: rgba(47, 125, 79, 0.95); color: #fff; }
.touch-no { background: rgba(143, 61, 61, 0.95); color: #fff; }

/* Landscape: clusters sit in the letterbox side bars, vertically centered */
@media (orientation: landscape) {
    #touch-cluster-l,
    #touch-cluster-r {
        bottom: auto;
        top: 50%;
        transform: translateY(-50%);
    }
}

#touch-toast {
    position: fixed;
    left: 50%;
    bottom: 130px;
    transform: translateX(-50%);
    background: rgba(143, 61, 61, 0.95);
    color: #fff;
    padding: 10px 16px;
    border-radius: 8px;
    font-size: 15px;
    opacity: 0;
    transition: opacity 0.2s;
    pointer-events: none;
    z-index: 60;
    white-space: nowrap;
}

#touch-toast.on { opacity: 1; }

#touch-flash {
    position: fixed;
    inset: 0;
    background: rgba(200, 30, 30, 0.25);
    opacity: 0;
    transition: opacity 0.15s;
    pointer-events: none;
    z-index: 50;
}

#touch-flash.on { opacity: 1; }

#touch-trash {
    position: fixed;
    z-index: 45;
    display: none;
    font-size: 24px;
}
```

- [ ] **Step 4: Run precision tests — pass**

Run: `npx playwright test --project=mobile -g "nudge pad|world precision"`
Expected: PASS (card lands at expected world coords / angle within tolerance).

---

### Task 3: Rejection feedback + tap-to-delete

**Files:**
- Modify: `web/external/touch.js` (wire `showTrash`/delete)
- Modify: `tests/mobile.spec.js`

**Interfaces:**
- Consumes: `commit()` rejection path, `remaining()`, `toVirtual`, `moveGhost`, `raf2`, `mouse` from Task 2; `#touch-trash` node.
- Produces: tap → 🗑 → right-click-delete flow.

- [ ] **Step 1: Write failing tests**

```js
test('rejected placement shows toast + red flash, counters unchanged', async ({ page }) => {
    await enterLevel11(page);
    const target = await clientForWorld(page, 1, 1, 2.5, 1.5);
    const [sx, sy] = await fingerFor(page, target.clientX, target.clientY);
    await page.touchscreen.tap(sx, sy);
    await page.locator('#touch-ok').tap();
    await page.waitForTimeout(400);
    // Same spot again → ghost overlaps the placed card → silent engine
    // rejection → touch layer must surface it.
    await page.touchscreen.tap(sx, sy);
    await page.locator('#touch-ok').tap();
    await expect(page.locator('#touch-toast')).toHaveClass(/on/);
    await expect(page.locator('#touch-flash')).toHaveClass(/on/);
    const rem = await page.evaluate(() => document.querySelector('.dynamic .remaining').textContent);
    expect(rem).toMatch(/4/);   // level 1-1 has 5 dynamic; only one placed
});

test('quick tap on a placed card offers trash; trash deletes it', async ({ page }) => {
    await enterLevel11(page);
    const target = await clientForWorld(page, 1, 1, 2.5, 1.5);
    const [sx, sy] = await fingerFor(page, target.clientX, target.clientY);
    await page.touchscreen.tap(sx, sy);
    await page.locator('#touch-ok').tap();
    await page.waitForTimeout(400);
    // Tap directly on the card (no lift compensation: tap the card's
    // *screen* point).
    const cardScreen = await page.evaluate(([vx, vy]) => {
        const r = window.__touch.realRect();
        return [r.left + (vx - r.left) * (r.width / 800),
                r.top + (vy - r.top) * (r.height / 600)];
    }, [target.clientX, target.clientY]);
    await page.touchscreen.tap(cardScreen[0], cardScreen[1]);
    await expect(page.locator('#touch-trash')).toBeVisible();
    await page.locator('#touch-trash').tap();
    await page.waitForTimeout(500);
    await expect(page.locator('#touch-trash')).toBeHidden();
    const rem = await page.evaluate(() => document.querySelector('.dynamic .remaining').textContent);
    expect(rem).toMatch(/5/);   // card returned to the pool
});
```

- [ ] **Step 2: Run to verify failure**

Run: `npx playwright test --project=mobile -g "trash|rejected placement"`
Expected: rejection test may already pass (commit() from Task 2 wires feedback); trash test FAILS (`showTrash` is a stub).

- [ ] **Step 3: Implement delete flow**

In `touch.js`, replace the trash stubs:

```js
    document.body ? document.body.appendChild(trash)
                  : document.addEventListener('DOMContentLoaded', function () {
                        document.body.appendChild(trash);
                    });

    var trashPoint = null;
    function showTrash(sx, sy) {
        trashPoint = { x: sx, y: sy };
        trash.style.left = Math.min(window.innerWidth - 60, sx + 24) + 'px';
        trash.style.top = Math.max(8, sy - 60) + 'px';
        trash.style.display = 'block';
    }
    function hideTrash() {
        trash.style.display = 'none';
        trashPoint = null;
    }
    trash.addEventListener('touchstart', function (e) {
        e.preventDefault();
        e.stopPropagation();
        if (!trashPoint) return;
        // Park the ghost exactly on the tapped point, give box2d a frame
        // to refresh sensor contacts, then right-click: the engine removes
        // every placed card overlapping the ghost (desktop parity).
        var v = toVirtual(trashPoint.x, trashPoint.y);
        moveGhost(v.x, v.y);
        raf2(function () {
            raf2(function () {
                mouse('mousedown', v.x, v.y, 2);
                raf2(function () { mouse('mouseup', v.x, v.y, 2); });
            });
        });
        hideTrash();
    }, { passive: false });
```

(Adjust Task 2's chrome-mounting block: `trash` is appended with the other chrome nodes inside `mountChrome()` instead of the standalone append above, whichever reads cleaner — one append only.)

Note `mountChrome` from Task 2 should include `trash`; make sure the earlier `hideTrash` definition is this one (single definition).

- [ ] **Step 4: Run — pass**

Run: `npx playwright test --project=mobile -g "trash|rejected placement"`
Expected: PASS.

---

### Task 4: Two-finger pan + pinch zoom

**Files:**
- Modify: `web/external/touch.js` (real `startPan/movePan/endPan`, pinch)
- Modify: `tests/mobile.spec.js`

**Interfaces:**
- Consumes: `key`, `mouse`, `toVirtual`, `raf2`, `state` from Task 2.
- Produces: two-finger drag = engine Space+left-drag; pinch = `#zoom-in`/`#zoom-out` clicks.

**Key trap:** `Input.mouseDelta*` is the difference between consecutive mousemoves and is consumed by the camera when Space+left are down. Send the anchor `mousemove` first, then the left `mousedown` only after a `raf2` — otherwise the jump from the previous ghost position pans the camera wildly.

- [ ] **Step 1: Write failing tests** (two-finger drag needs raw touch dispatch; Playwright's touchscreen has no multi-touch, so dispatch `TouchEvent`s in-page)

```js
async function twoFingerGesture(page, steps) {
    // steps: array of [[x1,y1],[x2,y2]] frames; dispatches touchstart on
    // the first, touchmove for the rest, touchend at the end.
    await page.evaluate(async (frames) => {
        const c = document.querySelector('#graphics');
        const mk = (pts) => pts.map(([x, y], i) =>
            new Touch({ identifier: i, target: c, clientX: x, clientY: y }));
        const fire = (type, pts) => c.dispatchEvent(new TouchEvent(type, {
            bubbles: true, cancelable: true,
            touches: type === 'touchend' ? [] : mk(pts),
            targetTouches: type === 'touchend' ? [] : mk(pts),
            changedTouches: mk(pts),
        }));
        fire('touchstart', frames[0]);
        for (let i = 1; i < frames.length; i++) {
            await new Promise((r) => setTimeout(r, 40));
            fire('touchmove', frames[i]);
        }
        await new Promise((r) => setTimeout(r, 40));
        fire('touchend', frames[frames.length - 1]);
    }, steps);
}

test('two-finger drag pans the camera', async ({ page }) => {
    await enterLevel11(page);
    // Place a probe card before panning, then pan and place a second card
    // at the same finger point: world-x must differ by the pan distance.
    const target = await clientForWorld(page, 1, 1, 2.5, 2.2);
    const [sx, sy] = await fingerFor(page, target.clientX, target.clientY);
    await page.touchscreen.tap(sx, sy);
    await page.locator('#touch-ok').tap();
    await page.waitForTimeout(400);
    const before = await probeCards(page);

    const r = await page.evaluate(() => {
        const q = window.__touch.realRect();
        return { left: q.left, top: q.top, w: q.width, h: q.height };
    });
    const cx = r.left + r.w / 2, cy = r.top + r.h / 2;
    // drag both fingers 60 screen px left => camera moves right
    const frames = [];
    for (let i = 0; i <= 6; i++) {
        frames.push([[cx - i * 10, cy - 40], [cx - i * 10, cy + 40]]);
    }
    await twoFingerGesture(page, frames);
    await page.waitForTimeout(600);

    await page.touchscreen.tap(sx, sy);
    await page.locator('#touch-ok').tap();
    await page.waitForTimeout(400);
    const after = await probeCards(page);
    expect(after.length).toBe(2);
    const xs = after.map((c) => c.x).sort((a, b) => a - b);
    // camera panned by 60 screen px * (800/cssW) / 85 world units
    const expectedShift = await page.evaluate(() =>
        60 * (800 / window.__touch.realRect().width) / 85);
    expect(Math.abs(xs[1] - xs[0])).toBeGreaterThan(expectedShift * 0.5);
});

test('pinch zooms via the zoom buttons', async ({ page }) => {
    await enterLevel11(page);
    await page.evaluate(() => {
        window.__zoom = { in: 0, out: 0 };
        document.querySelector('#zoom-in').addEventListener('click', () => window.__zoom.in++);
        document.querySelector('#zoom-out').addEventListener('click', () => window.__zoom.out++);
    });
    const r = await page.evaluate(() => {
        const q = window.__touch.realRect();
        return { left: q.left, top: q.top, w: q.width, h: q.height };
    });
    const cx = r.left + r.w / 2, cy = r.top + r.h / 2;
    const spread = [];
    for (let i = 0; i <= 5; i++) {
        spread.push([[cx - 20 - i * 15, cy], [cx + 20 + i * 15, cy]]);
    }
    await twoFingerGesture(page, spread);
    const z = await page.evaluate(() => window.__zoom);
    expect(z.in).toBeGreaterThan(0);
});
```

- [ ] **Step 2: Run to verify failure**

Run: `npx playwright test --project=mobile -g "pans the camera|pinch"`
Expected: FAIL (pan/pinch are stubs).

- [ ] **Step 3: Implement pan + pinch**

Replace the Task 2 stubs in `touch.js`:

```js
    var pan = null;        // {vx, vy} last virtual centroid sent
    var pinchDist = 0;

    function centroid(e) {
        var a = e.touches[0], b = e.touches[1];
        return {
            x: (a.clientX + b.clientX) / 2,
            y: (a.clientY + b.clientY) / 2,
            d: Math.hypot(a.clientX - b.clientX, a.clientY - b.clientY),
        };
    }

    function startPan(e) {
        var c = centroid(e);
        pinchDist = c.d;
        var v = toVirtual(c.x, c.y);
        pan = { vx: v.x, vy: v.y, ready: false };
        key('keydown', KEY.space);
        // Anchor the engine's mouse position BEFORE pressing left, and let
        // one engine frame consume the jump delta, or the camera lurches.
        mouse('mousemove', v.x, v.y);
        state.virtual = { x: v.x, y: v.y };
        raf2(function () {
            if (!pan) return;
            mouse('mousedown', v.x, v.y, 0);
            pan.ready = true;
        });
    }

    function movePan(e) {
        if (!pan) return;
        var c = centroid(e);
        // Pinch: every 15% spread change is one zoom-button step.
        if (pinchDist > 0 && c.d > 0) {
            if (c.d / pinchDist > 1.15) {
                var zi = document.getElementById('zoom-in');
                if (zi) zi.click();
                pinchDist = c.d;
            } else if (pinchDist / c.d > 1.15) {
                var zo = document.getElementById('zoom-out');
                if (zo) zo.click();
                pinchDist = c.d;
            }
        }
        if (!pan.ready) return;
        var v = toVirtual(c.x, c.y);
        pan.vx = v.x;
        pan.vy = v.y;
        mouse('mousemove', v.x, v.y);
        state.virtual = { x: v.x, y: v.y };
    }

    function endPan() {
        if (!pan) return;
        var p = pan;
        pan = null;
        mouse('mouseup', p.vx, p.vy, 0);
        key('keyup', KEY.space);
    }
```

Remove the `var pan = null;` stub line from Task 2 (single declaration).

- [ ] **Step 4: Run — pass**

Run: `npx playwright test --project=mobile -g "pans the camera|pinch"`
Expected: PASS.

---

### Task 5: Full flow — orientations, chapter scroll, 3-star touch-only win, suite green

**Files:**
- Modify: `tests/mobile.spec.js`
- Modify: `web/cards.css` (only if the orientation screenshots reveal broken dialogs)
- Modify: `CLAUDE.md` (one line documenting touch support + mobile test project)

**Interfaces:**
- Consumes: everything above; `tools/lib/levels.js` (`worldToClient`, chapter JSON).

- [ ] **Step 1: Write the remaining tests**

```js
test('chapter list scrolls by touch drag (scrollbar.js native path)', async ({ page }) => {
    await page.addInitScript(() => localStorage.setItem('seen_howto', 'true'));
    await page.goto('/web/cards.html');
    await expect(page.locator('#new-game')).toBeVisible({ timeout: 30000 });
    await page.locator('#new-game').tap();
    await expect(page.locator('#chapter-selection')).toBeVisible();
    const before = await page.evaluate(() =>
        document.querySelector('#chapter-es').style.top || '0px');
    const box = await page.locator('#chapter-vs').boundingBox();
    await page.evaluate(async ([x, y]) => {
        const lyr = document.querySelector('#chapter-es');
        const mk = (yy) => [new Touch({ identifier: 0, target: lyr, clientX: x, clientY: yy })];
        const fire = (type, yy) => lyr.dispatchEvent(new TouchEvent(type, {
            bubbles: true, cancelable: true,
            touches: type === 'touchend' ? [] : mk(yy),
            targetTouches: type === 'touchend' ? [] : mk(yy),
            changedTouches: mk(yy),
        }));
        fire('touchstart', y);
        for (let i = 1; i <= 6; i++) {
            await new Promise((r) => setTimeout(r, 30));
            fire('touchmove', y - i * 20);
        }
        fire('touchend', y - 120);
    }, [box.x + box.width / 2, box.y + box.height / 2]);
    const after = await page.evaluate(() =>
        document.querySelector('#chapter-es').style.top || '0px');
    expect(after).not.toBe(before);
});

test.describe('landscape', () => {
    test.use({ viewport: { width: 915, height: 412 } });

    test('boots and places in landscape', async ({ page }) => {
        await enterLevel11(page);
        const target = await clientForWorld(page, 1, 1, 2.5, 1.5);
        const [sx, sy] = await fingerFor(page, target.clientX, target.clientY);
        await page.touchscreen.tap(sx, sy);
        await page.locator('#touch-ok').tap();
        await page.waitForTimeout(400);
        const rem = await page.evaluate(() =>
            document.querySelector('.dynamic .remaining').textContent);
        expect(rem).toMatch(/4/);
        // dialogs fit: rating/pause box is inside the viewport when opened
        await page.evaluate(() => {
            window.dispatchEvent(new KeyboardEvent('keydown', { keyCode: 27, which: 27, bubbles: true }));
        });
        await expect(page.locator('#rating-box')).toBeVisible();
        const bb = await page.locator('.rating-inner-layout').boundingBox();
        expect(bb.x).toBeGreaterThanOrEqual(-1);
        expect(bb.x + bb.width).toBeLessThanOrEqual(916);
        await page.locator('#resume-game').tap();
    });
});

test('wins level 1-1 with 3 stars touch-only', async ({ page }) => {
    test.setTimeout(180000);
    await enterLevel11(page);
    await page.evaluate(() => {
        const orig = Features.onLevelFinish;
        window.__finish = null;
        Features.onLevelFinish = function (chapter, level, result) {
            window.__finish = { chapter, level, stars: result };
            return orig.apply(Features, arguments);
        };
    });
    // Known 3-star solution (AGENT_PLAYBOOK.md §8): one dynamic card at
    // x=1.6765 y=1.0647 angle=0.
    const target = await clientForWorld(page, 1, 1, 1.6765, 1.0647);
    const [sx, sy] = await fingerFor(page, target.clientX, target.clientY);
    // Coarse drop by touch, then deterministic 1px nudges close the
    // sub-pixel gap: compute the landed virtual position and the delta.
    await page.touchscreen.tap(sx, sy);
    const landed = await page.evaluate(() => window.__touch.state.virtual);
    const dx = Math.round(target.clientX - landed.x);
    const dy = Math.round(target.clientY - landed.y);
    for (let i = 0; i < Math.abs(dx); i++) await page.locator(dx > 0 ? '#touch-right' : '#touch-left').tap();
    for (let i = 0; i < Math.abs(dy); i++) await page.locator(dy > 0 ? '#touch-down' : '#touch-up').tap();
    await page.locator('#touch-ok').tap();
    await page.waitForTimeout(400);
    const rem = await page.evaluate(() => document.querySelector('.dynamic .remaining').textContent);
    expect(rem).toMatch(/4/);
    await page.locator('#touch-apply').dispatchEvent('touchstart');
    await page.waitForFunction(() => window.__finish, null, { timeout: 120000 });
    const fin = await page.evaluate(() => window.__finish);
    expect(fin.chapter).toBe(1);
    expect(fin.level).toBe(1);
    expect(fin.stars).toBe(3);
    // full flow continues: win dialog -> next level
    await expect(page.locator('#rating-box')).toBeVisible();
    await page.locator('#next-level').tap();
    await page.waitForFunction(() => JSON.parse(localStorage.getItem('last')).level === 2,
        null, { timeout: 30000 });
});
```

- [ ] **Step 2: Run the full mobile suite**

Run: `npx playwright test --project=mobile`
Expected: all mobile tests pass. Iterate on touch.js/CSS if the orientation test reveals clipped dialogs (fix with `.touch-mode` rules only).

- [ ] **Step 3: Full suite + docs**

Run: `npm test`
Expected: chromium, firefox, mobile — all green.

Add to `CLAUDE.md` Architecture section:

```markdown
- Touch support (phones): `web/external/touch.js` translates touch gestures into the synthetic mouse/keyboard events the compiled engine consumes, letterbox-scales `.game-box`, and renders a two-thumb control chrome; design in `docs/superpowers/specs/2026-07-05-touch-support-design.md`. Mobile Playwright project: `npx playwright test --project=mobile`.
```

- [ ] **Step 4: Visual sanity screenshots (portrait + landscape)**

Run a scratchpad script (or `page.screenshot` inside a temporary test) capturing menu, chapter list, level with chrome, win dialog at 412×915 and 915×412; eyeball for clipped dialogs. Fix any with `.touch-mode` CSS and re-run the suite.

## Self-Review

- Spec coverage: §2 activation → Task 1; §3 scaling/rect → Task 1; §4 synthesis table → Tasks 2 (drag/nudge/rotate/snap/commit/park), 3 (tap-delete), 4 (pan/pinch), chrome proxies → Task 2; §5 placement flow + rejection → Tasks 2–3; §6 delete → Task 3; §7 chrome/visibility → Task 2; §9 done-when → Tasks 1–5. Covered.
- Placeholders: Task 2 contains explicit stubs for Task 3/4 functions, each labeled with the task that replaces them — intentional seams, with the real code present in those tasks.
- Type consistency: `__touch` API names match across tasks; `KEY` map defined once (Task 2) and used in Task 4; `raf2/mouse/key` defined in Task 2 and consumed by Tasks 3–4.

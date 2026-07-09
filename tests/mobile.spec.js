// Mobile touch suite, v3 gesture UX. Runs only in the 'mobile' Playwright
// project (chromium, phone viewport, hasTouch) — see playwright.config.js.
// tap = place (immediate, no double-tap window), 1-finger drag = pan,
// 2 fingers = rotate (dotted line) and the block is placed when the
// fingers lift, long-press near a block = pick it up (fat hit bounds) to
// drag-move or trash it.
// Touch design: docs/superpowers/specs/2026-07-05-touch-support-design.md
'use strict';
const { test, expect } = require('@playwright/test');
const levels = require('../tools/lib/levels');

const NSCALE = 85;
const TOPBAR = 56;

// With the responsive canvas, screen px == canvas px == engine px.
// Returns the screen point for a world point, using the live camera
// prediction for a never-panned camera at the real canvas size.
function screenForWorld(page, chapter, level, wx, wy) {
    const raw = levels.loadChapter(chapter).levels[level - 1];
    return page.evaluate(([wx, wy, raw, TOPBAR]) => {
        const L = window.__touch.state.layout;
        // replicate tools/lib/levels.cameraOffsets inline (browser side)
        const S = 85, W = L.w / S, H = L.h / S;
        const bx1 = raw.x, bx2 = raw.x + raw.width;
        const by1 = raw.y, by2 = raw.y + raw.height;
        let mx = raw.x / S;
        if (mx <= bx1 / S) mx = bx1 / S;
        if (mx + W >= bx2 / S) mx = bx2 / S - W;
        let my = raw.y / S;
        if (my - H <= by1 / S) my = by1 / S + H;
        if (my >= by2 / S) my = by2 / S;
        const pxOffsetX = mx * S, pxOffsetY = -my * S;
        return {
            x: L.left + wx * S - pxOffsetX,
            y: L.top + (-wy * S - pxOffsetY),
        };
    }, [wx, wy, raw, TOPBAR]);
}

// Esc-pause persists exact card state to localStorage (same probe the
// machine-play harness uses), then resumes.
async function probeCards(page) {
    return page.evaluate(async () => {
        const last = JSON.parse(localStorage.getItem('last'));
        const key = 'level_' + last.chapter + '_' + last.level;
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
    // clear the tutorial hint card/tooltips without touching the canvas
    // (a canvas tap would schedule a placement in the v2 UX)
    await page.evaluate(() => document.body.click());
    await page.waitForTimeout(300);
    await expect(page.locator('#touch-apply')).toBeVisible();
}

async function remainingDynamic(page) {
    const txt = await page.evaluate(() =>
        document.querySelector('.dynamic .remaining').textContent);
    const m = txt.match(/\d+/);
    return m ? parseInt(m[0], 10) : null;
}

// tap and wait for the immediate placement's frame chain to finish
async function tapPlace(page, x, y) {
    await page.touchscreen.tap(x, y);
    await page.waitForTimeout(500);
}

// In-page touch dispatch for gestures Playwright's touchscreen can't do
// (drags, multi-touch, long holds).
async function fingerDrag(page, frames, holdMs = 0) {
    await page.evaluate(async ([frames, holdMs]) => {
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
        if (holdMs) await new Promise((r) => setTimeout(r, holdMs));
        for (let i = 1; i < frames.length; i++) {
            await new Promise((r) => setTimeout(r, 40));
            fire('touchmove', frames[i]);
        }
        await new Promise((r) => setTimeout(r, 40));
        fire('touchend', frames[frames.length - 1]);
    }, [frames, holdMs]);
}

test('boots responsive: full-viewport canvas, no nudge/rotate buttons', async ({ page }) => {
    await page.goto('/web/cards.html');
    await expect(page.locator('#new-game')).toBeVisible({ timeout: 30000 });
    await expect(page.locator('html')).toHaveClass(/touch-mode/);
    const fit = await page.evaluate(() => {
        const c = document.querySelector('#graphics');
        const fake = c.getBoundingClientRect();
        return {
            attrW: c.width, attrH: c.height,
            cssW: parseFloat(c.style.width), innerW: innerWidth, innerH: innerHeight,
            fakeW: fake.width, fakeH: fake.height, fakeTop: fake.top,
            clusters: !!document.querySelector('#touch-up, #touch-rl, #touch-ok'),
        };
    });
    expect(fit.attrW).toBe(fit.innerW);            // canvas is device-sized
    expect(fit.attrH).toBe(fit.innerH - TOPBAR);
    expect(fit.cssW).toBe(fit.attrW);              // 1:1 css px, no scaling blur
    expect(fit.fakeW).toBe(fit.attrW);             // engine sees the same rect
    expect(fit.fakeTop).toBe(TOPBAR);
    expect(fit.clusters).toBe(false);              // v1 button clusters are gone
});

test('tap places a block at the tapped world point', async ({ page }) => {
    await enterLevel11(page);
    const base = await remainingDynamic(page);
    const p = await screenForWorld(page, 1, 1, 2.5, 1.5);
    await tapPlace(page, p.x, p.y);
    expect(await remainingDynamic(page)).toBe(base - 1);
    const cards = await probeCards(page);
    expect(cards.length).toBe(1);
    expect(cards[0].x).toBeCloseTo(2.5, 1);
    expect(cards[0].y).toBeCloseTo(1.5, 1);
});

test('double tap does not zoom: two immediate placements, no canvas transform', async ({ page }) => {
    await enterLevel11(page);
    const base = await remainingDynamic(page);
    const p = await screenForWorld(page, 1, 1, 2.5, 1.8);
    await page.touchscreen.tap(p.x, p.y);
    await page.waitForTimeout(150);
    await page.touchscreen.tap(p.x, p.y);       // overlaps the first: rejected
    await page.waitForTimeout(500);
    const out = await page.evaluate(() => ({
        grid: !!document.querySelector('#touch-grid'),
        transform: document.querySelector('#graphics').style.transform,
    }));
    expect(out.grid).toBe(false);                // precision grid is gone
    expect(out.transform).toBe('');              // no CSS zoom ever applied
    expect(await remainingDynamic(page)).toBe(base - 1);
    const cards = await probeCards(page);
    expect(cards.length).toBe(1);
});

test('two-finger rotate places the block when the fingers lift', async ({ page }) => {
    await enterLevel11(page);
    const base = await remainingDynamic(page);
    const p = await screenForWorld(page, 1, 1, 2.5, 2.0);
    // fingers around p at 30 degrees (screen y is inverted vs world)
    const r = 90, ang = Math.PI / 6;
    const f = (a) => [
        [p.x - r * Math.cos(a), p.y + r * Math.sin(a)],
        [p.x + r * Math.cos(a), p.y - r * Math.sin(a)],
    ];
    // start horizontal, rotate to 30 degrees, hold for the key-driven
    // rotation to finish
    const seq = [];
    for (let i = 0; i <= 8; i++) seq.push(f(ang * i / 8));
    for (let i = 0; i < 14; i++) seq.push(f(ang));   // hold ~0.6s
    const lineVisible = page.waitForFunction(() =>
        document.querySelector('#touch-rotline').classList.contains('on'));
    const gesture = fingerDrag(page, seq);
    await lineVisible;
    await gesture;
    await page.waitForFunction(() =>
        !document.querySelector('#touch-rotline').classList.contains('on'));
    // no extra tap: the lift itself placed the block at the line midpoint
    await page.waitForTimeout(1200);
    expect(await remainingDynamic(page)).toBe(base - 1);
    const cards = await probeCards(page);
    expect(cards.length).toBe(1);
    expect(cards[0].x).toBeCloseTo(2.5, 1);
    expect(cards[0].y).toBeCloseTo(2.0, 1);
    expect(cards[0].a).toBeCloseTo(Math.round(ang / (Math.PI / 72)) * Math.PI / 72, 2);
});

test('two-finger rotation is softly magnetic at 15-degree angles', async ({ page }) => {
    await page.goto('/web/cards.html');
    await expect(page.locator('#new-game')).toBeVisible({ timeout: 30000 });
    const steps = await page.evaluate(() => {
        const at = (degrees) =>
            window.__touch.magneticAngleSteps(degrees * Math.PI / 180);
        return {
            below: at(12.5),
            exact: at(15),
            above: at(17.5),
            freeBelow: at(10),
            freeAbove: at(20),
            negative: at(-12.5),
        };
    });
    expect(steps).toEqual({
        below: 6,
        exact: 6,
        above: 6,
        freeBelow: 4,
        freeAbove: 8,
        negative: -6,
    });
});

test('touch placement softly joins nearby block ends', async ({ page }) => {
    await enterLevel11(page);
    const p = await screenForWorld(page, 1, 1, 2.5, 2.0);
    await tapPlace(page, p.x, p.y);

    // A horizontal card is 45 screen pixels long. Aim 55px from the first
    // center: its ends are 10px apart, inside the 18px attraction radius.
    // The magnet should leave the configured 4px collision-safe gap.
    await tapPlace(page, p.x + 55, p.y);

    const cards = (await probeCards(page)).sort((a, b) => a.x - b.x);
    expect(cards.length).toBe(2);
    expect((cards[1].x - cards[0].x) * NSCALE).toBeCloseTo(49, 0);
});

test('one-finger drag pans the camera', async ({ page }) => {
    await enterLevel11(page);
    const p = await screenForWorld(page, 1, 1, 2.5, 2.2);
    await tapPlace(page, p.x, p.y);
    const before = await probeCards(page);
    expect(before.length).toBe(1);

    // drag 160px left => the world under a fixed screen point shifts right
    const frames = [];
    for (let i = 0; i <= 8; i++) frames.push([[p.x - i * 20, p.y - 120]]);
    await fingerDrag(page, frames);
    await page.waitForTimeout(1500);          // camera glide settles

    // place at a vertically offset screen point so even a partial pan
    // can't overlap the first card
    await tapPlace(page, p.x, p.y - 30);
    const after = await probeCards(page);
    expect(after.length).toBe(2);
    const xs = after.map((c) => c.x).sort((a, b) => a - b);
    expect(Math.abs(xs[1] - xs[0])).toBeGreaterThan(60 / NSCALE);  // > 3/8 of the pan
});

test('rejected placement shows toast + red flash, counters unchanged', async ({ page }) => {
    await enterLevel11(page);
    const base = await remainingDynamic(page);
    const p = await screenForWorld(page, 1, 1, 2.5, 1.5);
    await tapPlace(page, p.x, p.y);
    expect(await remainingDynamic(page)).toBe(base - 1);
    await page.waitForTimeout(400);           // slide out of double-tap window
    await tapPlace(page, p.x, p.y);           // same spot: overlap, rejected
    await expect(page.locator('#touch-toast')).toHaveClass(/on/);
    expect(await remainingDynamic(page)).toBe(base - 1);
});

// The card is 45x2.5 px; pressing 14px above its center is well outside the
// brick itself but inside the fat selection bounds for big fingers.
test('long-press near a card picks it up; dragging moves it; release re-places it', async ({ page }) => {
    await enterLevel11(page);
    const base = await remainingDynamic(page);
    const p = await screenForWorld(page, 1, 1, 2.5, 1.5);
    await tapPlace(page, p.x, p.y);
    expect(await remainingDynamic(page)).toBe(base - 1);
    // long hold above the card, then drag 64px right and release
    const s = { x: p.x + 10, y: p.y - 14 };
    const frames = [[[s.x, s.y]]];
    for (let i = 1; i <= 8; i++) frames.push([[s.x + i * 8, s.y]]);
    await fingerDrag(page, frames, 800);
    await page.waitForTimeout(800);
    expect(await remainingDynamic(page)).toBe(base - 1);   // still one on board
    const cards = await probeCards(page);
    expect(cards.length).toBe(1);
    expect(cards[0].x).toBeCloseTo(2.5 + 64 / NSCALE, 1);  // moved with the drag
    expect(cards[0].y).toBeCloseTo(1.5, 1);
    expect(cards[0].a).toBeCloseTo(0, 2);                  // angle preserved
});

test('long-press near a card then trash deletes it (fat bounds, single card)', async ({ page }) => {
    await enterLevel11(page);
    const base = await remainingDynamic(page);
    const p = await screenForWorld(page, 1, 1, 2.5, 1.5);
    await tapPlace(page, p.x, p.y);
    expect(await remainingDynamic(page)).toBe(base - 1);
    // long hold 14px above the brick (outside it, inside the fat bounds)
    await fingerDrag(page, [[[p.x, p.y - 14]]], 800);
    await expect(page.locator('#touch-trash')).toBeVisible();
    await page.waitForTimeout(500);                 // release re-places the card
    await page.locator('#touch-trash').tap();
    await page.waitForTimeout(500);
    await expect(page.locator('#touch-trash')).toBeHidden();
    expect(await remainingDynamic(page)).toBe(base);   // card back in the pool
    const cards = await probeCards(page);
    expect(cards.length).toBe(0);
});

test('long-press on empty space offers nothing', async ({ page }) => {
    await enterLevel11(page);
    const base = await remainingDynamic(page);
    const p = await screenForWorld(page, 1, 1, 2.5, 2.5);
    await fingerDrag(page, [[[p.x, p.y]]], 800);    // long hold, nothing there
    await page.waitForTimeout(500);
    await expect(page.locator('#touch-trash')).toBeHidden();
    expect(await remainingDynamic(page)).toBe(base);   // and nothing was placed
    const cards = await probeCards(page);
    expect(cards.length).toBe(0);
});

test('scroll lists respond to touch drag (scrollbar.js native path)', async ({ page }) => {
    await enterLevel11(page);
    await page.evaluate(() => {
        window.dispatchEvent(new KeyboardEvent('keydown', { keyCode: 27, which: 27, bubbles: true }));
    });
    await page.waitForTimeout(300);
    await page.evaluate(() => {
        window.dispatchEvent(new KeyboardEvent('keyup', { keyCode: 27, which: 27, bubbles: true }));
    });
    await expect(page.locator('#rating-box')).toBeVisible();
    await page.waitForTimeout(400);
    const overflow = await page.evaluate(() => ({
        es: document.querySelector('#tape-es').offsetWidth,
        vs: document.querySelector('#tape-vs').offsetWidth,
        left: document.querySelector('#tape-es').style.left || '0px',
    }));
    expect(overflow.es).toBeGreaterThan(overflow.vs);
    const box = await page.locator('#tape-vs').boundingBox();
    await page.evaluate(async ([x, y]) => {
        const lyr = document.querySelector('#tape-es');
        const mk = (xx) => [new Touch({ identifier: 0, target: lyr, clientX: xx, clientY: y })];
        const fire = (type, xx) => lyr.dispatchEvent(new TouchEvent(type, {
            bubbles: true, cancelable: true,
            touches: type === 'touchend' ? [] : mk(xx),
            targetTouches: type === 'touchend' ? [] : mk(xx),
            changedTouches: mk(xx),
        }));
        fire('touchstart', x);
        for (let i = 1; i <= 6; i++) {
            await new Promise((r) => setTimeout(r, 30));
            fire('touchmove', x - i * 20);
        }
        fire('touchend', x - 120);
    }, [box.x + box.width / 2, box.y + box.height / 2]);
    const after = await page.evaluate(() =>
        document.querySelector('#tape-es').style.left || '0px');
    expect(after).not.toBe(overflow.left);
    await page.locator('#resume-game').tap();
});

// --- native touch chrome (v3): the menu, chapter list, in-game top bar
// and pause/rating screens reflow to the real viewport instead of the old
// scale-to-fit. Every interactive control must be a finger-sized target
// (>= 44px) and sit inside the viewport.
const MIN_TAP = 44;

async function bootMenu(page) {
    await page.addInitScript(() => localStorage.setItem('seen_howto', 'true'));
    await page.goto('/web/cards.html');
    await expect(page.locator('#new-game')).toBeVisible({ timeout: 30000 });
}

test('main menu: full-width thumb-sized buttons inside the viewport', async ({ page }) => {
    await bootMenu(page);
    const box = await page.locator('#menu-box').boundingBox();
    // the box fills the viewport, it is not a small centered 800x600 card
    expect(box.width).toBeGreaterThan(page.viewportSize().width - 2);
    for (const id of ['#new-game', '#continue']) {
        const b = await page.locator(id).boundingBox();
        expect(b.height).toBeGreaterThanOrEqual(MIN_TAP);
        expect(b.width).toBeGreaterThan(page.viewportSize().width * 0.5);
        expect(b.x).toBeGreaterThanOrEqual(-1);
        expect(b.x + b.width).toBeLessThanOrEqual(page.viewportSize().width + 1);
        expect(b.y + b.height).toBeLessThanOrEqual(page.viewportSize().height + 1);
    }
});

test('chapter list: big Menu pill, zoomed cards, no desktop blur bar', async ({ page }) => {
    await bootMenu(page);
    await page.locator('#new-game').tap();
    await expect(page.locator('#chapter-selection')).toBeVisible();
    await page.waitForTimeout(400);
    const menuBtn = await page.locator('.go-to-menu-button').boundingBox();
    expect(menuBtn.height).toBeGreaterThanOrEqual(MIN_TAP);
    // the html2canvas desktop blur bar is hidden in touch mode
    const blurShown = await page.evaluate(() =>
        getComputedStyle(document.querySelector('.chapter-blurry-bar')).display !== 'none');
    expect(blurShown).toBe(false);
    // cards are zoomed for fingers (zoom var applied)
    const zoom = await page.evaluate(() =>
        getComputedStyle(document.querySelector('.chapter')).zoom);
    expect(parseFloat(zoom)).toBeGreaterThan(1);
    // the whole list fits the width — first card is not clipped off-screen
    const card = await page.locator('.chapter[data-id="1"]').boundingBox();
    expect(card.x).toBeGreaterThanOrEqual(-1);
    expect(card.x + card.width).toBeLessThanOrEqual(page.viewportSize().width + 1);
});

test('in-game top bar: pause button present, all targets finger-sized', async ({ page }) => {
    await enterLevel11(page);
    for (const id of ['#touch-pause', '#touch-restart',
                      '#touch-hint', '#touch-apply']) {
        await expect(page.locator(id)).toBeVisible();
        const b = await page.locator(id).boundingBox();
        expect(b.height).toBeGreaterThanOrEqual(MIN_TAP);
        expect(b.width).toBeGreaterThanOrEqual(MIN_TAP);
    }
    // the whole bar fits the viewport width
    const bar = await page.locator('#touch-top').boundingBox();
    expect(bar.x).toBeGreaterThanOrEqual(-1);
    expect(bar.x + bar.width).toBeLessThanOrEqual(page.viewportSize().width + 1);
});

test('block and wall selectors are both visible on touch', async ({ page }) => {
    await enterLevel11(page);
    const dynamic = page.locator('#touch-block-dynamic');
    const statik = page.locator('#touch-block-static');
    await expect(dynamic).toBeVisible();
    await expect(statik).toBeVisible();
    await expect(dynamic).toContainText('Block');
    await expect(statik).toContainText('Wall');
    await expect(dynamic).toHaveClass(/selected/);
    for (const button of [dynamic, statik]) {
        const b = await button.boundingBox();
        expect(b.height).toBeGreaterThanOrEqual(MIN_TAP);
        expect(b.width).toBeGreaterThanOrEqual(MIN_TAP);
    }
});

test('zoom control: finger-sized +/- on the right edge, drives engine zoom', async ({ page }) => {
    await enterLevel11(page);
    // two-finger is taken by rotate, so a dedicated zoom control must exist
    for (const id of ['#touch-zoom-in', '#touch-zoom-out']) {
        await expect(page.locator(id)).toBeVisible();
        const b = await page.locator(id).boundingBox();
        expect(b.height).toBeGreaterThanOrEqual(MIN_TAP);
        expect(b.width).toBeGreaterThanOrEqual(MIN_TAP);
        // docked on the right edge, inside the viewport
        expect(b.x + b.width).toBeLessThanOrEqual(page.viewportSize().width + 1);
        expect(b.x).toBeGreaterThan(page.viewportSize().width / 2);
    }
    // taps reach the engine's zoom handlers (#zoom-in / #zoom-out)
    const counts = await page.evaluate(() => {
        const c = { in: 0, out: 0 };
        document.querySelector('#zoom-in').addEventListener('click', () => c.in++);
        document.querySelector('#zoom-out').addEventListener('click', () => c.out++);
        window.__zoomCounts = c;
        return true;
    });
    expect(counts).toBe(true);
    await page.locator('#touch-zoom-in').tap();
    await page.locator('#touch-zoom-in').tap();
    await page.locator('#touch-zoom-out').tap();
    await page.waitForTimeout(200);
    const c = await page.evaluate(() => window.__zoomCounts);
    expect(c.in).toBe(2);
    expect(c.out).toBe(1);
});

test('pause button opens the pause dialog (resume returns to the level)', async ({ page }) => {
    await enterLevel11(page);
    await page.locator('#touch-pause').tap();
    await expect(page.locator('#rating-box')).toBeVisible();
    await expect(page.locator('.pause-controls')).toBeVisible();
    // the pause dialog buttons are finger-sized and on-screen
    for (const id of ['#resume-game', '#clear-level', '#pm-menu']) {
        const b = await page.locator(id).boundingBox();
        expect(b.height).toBeGreaterThanOrEqual(MIN_TAP);
        expect(b.x).toBeGreaterThanOrEqual(-1);
        expect(b.x + b.width).toBeLessThanOrEqual(page.viewportSize().width + 1);
    }
    await page.locator('#resume-game').tap();
    await expect(page.locator('#rating-box')).toBeHidden();
    await expect(page.locator('#touch-apply')).toBeVisible();
});

test('in-game hints are reworded for touch (no mouse/click wording)', async ({ page }) => {
    await enterLevel11(page);
    const loc = await page.evaluate(() => ({
        place: window.locale.wizard_place,
        remove: window.locale.wizard_remove,
    }));
    expect(loc.place.toLowerCase()).toContain('tap');
    expect(loc.place.toLowerCase()).not.toContain('click');
    expect(loc.remove.toLowerCase()).not.toContain('mouse');
});

test.describe('landscape', () => {
    test.use({ viewport: { width: 915, height: 412 } });

    test('menu and chapter list fit the landscape viewport', async ({ page }) => {
        await bootMenu(page);
        for (const id of ['#new-game', '#continue']) {
            const b = await page.locator(id).boundingBox();
            expect(b.y + b.height).toBeLessThanOrEqual(page.viewportSize().height + 1);
            expect(b.height).toBeGreaterThanOrEqual(MIN_TAP);
        }
        await page.locator('#new-game').tap();
        await expect(page.locator('#chapter-selection')).toBeVisible();
        const menuBtn = await page.locator('.go-to-menu-button').boundingBox();
        expect(menuBtn.height).toBeGreaterThanOrEqual(MIN_TAP);
        expect(menuBtn.y).toBeGreaterThanOrEqual(-1);
    });

    test('responsive canvas, tap-place, and dialogs fit in landscape', async ({ page }) => {
        await enterLevel11(page);
        const fit = await page.evaluate(() => {
            const c = document.querySelector('#graphics');
            return { attrW: c.width, attrH: c.height, innerW: innerWidth, innerH: innerHeight };
        });
        expect(fit.attrW).toBe(fit.innerW);
        expect(fit.attrH).toBe(fit.innerH - TOPBAR);
        const base = await remainingDynamic(page);
        const p = await screenForWorld(page, 1, 1, 2.5, 1.5);
        await tapPlace(page, p.x, p.y);
        expect(await remainingDynamic(page)).toBe(base - 1);
        // pause dialog fits the viewport
        await page.evaluate(() => {
            window.dispatchEvent(new KeyboardEvent('keydown', { keyCode: 27, which: 27, bubbles: true }));
        });
        await page.waitForTimeout(300);
        await page.evaluate(() => {
            window.dispatchEvent(new KeyboardEvent('keyup', { keyCode: 27, which: 27, bubbles: true }));
        });
        await expect(page.locator('#rating-box')).toBeVisible();
        const bb = await page.locator('.rating-inner-layout').boundingBox();
        expect(bb.x).toBeGreaterThanOrEqual(-1);
        expect(bb.x + bb.width).toBeLessThanOrEqual(916);
        await page.locator('#resume-game').tap();
    });
});

test('wins level 1-1 with 3 stars via an exact tap placement', async ({ page }) => {
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
    // x=1.6765 y=1.0647 angle=0. Synthetic touches carry float coordinates,
    // so a plain tap at the exact point is pixel-perfect (screen == engine px).
    const p = await screenForWorld(page, 1, 1, 1.6765, 1.0647);
    await fingerDrag(page, [[[p.x, p.y]]], 60);   // exact-coordinate tap
    await page.waitForTimeout(800);
    const rem = await remainingDynamic(page);
    expect(rem).toBe(2);                   // 1-1 has 3 dynamic blocks
    await page.locator('#touch-apply').tap();
    await page.waitForFunction(() => window.__finish, null, { timeout: 120000 });
    const fin = await page.evaluate(() => window.__finish);
    expect(fin.chapter).toBe(1);
    expect(fin.level).toBe(1);
    expect(fin.stars).toBe(3);
    // full flow continues: win dialog -> next level
    await expect(page.locator('#rating-box')).toBeVisible();
    await page.locator('#next-level').tap();
    await page.waitForFunction(
        () => JSON.parse(localStorage.getItem('last')).level === 2,
        null, { timeout: 30000 });
});

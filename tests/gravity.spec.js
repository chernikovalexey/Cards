// Chapter 4 ("Head Over Heels") gravity-vector mechanic.
//
// A level can pin the whole gravity vector via "gravity_vector": [gx, gy]
// (SubLevel.dart), and the engine drifts huge translucent arrows across the
// canvas whenever effective gravity differs from the default (0, -10)
// (GameEngine.renderGravityIndicator). Everything here is client-side
// (localStorage profile + canvas), so the suite also runs against the
// production deploy (chapter 4 shipped 2026-07-07).
const { test, expect } = require('@playwright/test');
const levels = require('../tools/lib/levels');

const GAME = '/web/cards.html';

// Chapter 4 unlocks at 0 stars; Level.preload jumps straight to `last`
// when its chapter matches, so seeding it is all the setup needed.
function seedProfile(page, level) {
    return page.addInitScript((lv) => {
        localStorage.setItem('seen_howto', 'true');
        localStorage.setItem('runout_occured', 'true');
        localStorage.setItem('last', JSON.stringify({ chapter: 4, level: lv }));
    }, level);
}

async function bootIntoLevel(page, level) {
    await seedProfile(page, level);
    await page.goto(GAME);
    await expect(page.locator('.loading-overlay')).toHaveCount(0);
    await page.evaluate(() => document.querySelector('#continue').click());
    await expect(page.locator('.buttons')).not.toHaveClass(/hidden/);
    // Camera settle + level-name banner.
    await page.waitForTimeout(1500);
}

// The engine samples Input.keys once per rAF and keyup clears both `down`
// and `clicked` — a keydown+keyup pair inside one task is never seen. Let a
// couple of real frames pass between the two events.
async function pressKey(page, code) {
    await page.evaluate((c) => {
        window.dispatchEvent(new KeyboardEvent('keydown', { keyCode: c, which: c, bubbles: true }));
    }, code);
    await page.waitForTimeout(80);
    await page.evaluate((c) => {
        window.dispatchEvent(new KeyboardEvent('keyup', { keyCode: c, which: c, bubbles: true }));
    }, code);
    await page.waitForTimeout(80);
}

// Same synthetic-event flow the machine-play harness uses (tools/lib/game.js).
async function placeCard(page, wx, wy) {
    const rawLevel = await page.evaluate(() => JSON.parse(localStorage.getItem('last')))
        .then((l) => levels.loadChapter(l.chapter).levels[l.level - 1]);
    const rect = await page.evaluate(() => {
        const r = document.querySelector('#graphics').getBoundingClientRect();
        return { left: r.left, top: r.top, width: r.width, height: r.height };
    });
    const { clientX, clientY } = levels.worldToClient(wx, wy, rawLevel, rect);
    await pressKey(page, 49); // '1' — dynamic block
    await pressKey(page, 67); // 'c' — reset angle to 0
    await page.evaluate(([x, y]) => {
        document.querySelector('#graphics').dispatchEvent(
            new MouseEvent('mousemove', { clientX: x, clientY: y, bubbles: true }));
    }, [clientX, clientY]);
    await page.waitForTimeout(150);
    await pressKey(page, 13); // Enter — place
}

// Max count (over a few pairs of snapshots ~1.5s apart) of canvas pixels
// that changed brightness between snapshots. The arrows are huge faint
// shapes drifting across a mostly static scene; the idle level animates
// only a few thousand pixels (~4k measured), while the arrows repaint
// tens of thousands (~37k). Robust to how transparent the arrows are.
async function peakMovingPixels(page) {
    let peak = 0;
    for (let i = 0; i < 3; i++) {
        const n = await page.evaluate(async () => {
            const c = document.querySelector('#graphics');
            const ctx = c.getContext('2d');
            const a = ctx.getImageData(0, 0, c.width, c.height).data;
            await new Promise((r) => setTimeout(r, 1500));
            const b = ctx.getImageData(0, 0, c.width, c.height).data;
            let n = 0;
            for (let p = 0; p < a.length; p += 4) {
                if (Math.abs(a[p] - b[p]) > 15) n++;
            }
            return n;
        });
        peak = Math.max(peak, n);
    }
    return peak;
}

test.describe('gravity vectors', () => {
    test('level 2: a block placed under the cubes falls UP and wins', async ({ page }) => {
        await bootIntoLevel(page, 2);
        await expect(page.locator('.dynamic .remaining')).toHaveText('3 left');

        // Under the gap between the cube bottoms (cubes sit at y 0.588..1.0).
        await placeCard(page, 2.441, 0.535);
        await expect(page.locator('.dynamic .remaining')).toHaveText('2 left');

        await page.locator('#toggle-physics').click();
        // Reversed gravity pins the plank against both cube bottoms; the
        // energy chain closes and the rating dialog appears.
        await expect(page.locator('#rating-box')).toBeVisible({ timeout: 20000 });
        const stars = await page.evaluate(() => JSON.parse(localStorage.getItem('stars')));
        expect(stars.chapters.find((c) => c.id === 4).s).toBe(3);
    });

    test('level 3: leftward gravity layers two vertical pins across the stacked cubes', async ({ page }) => {
        await bootIntoLevel(page, 3);

        const rawLevel = levels.loadChapter(4).levels[2];
        const rect = await page.evaluate(() => {
            const r = document.querySelector('#graphics').getBoundingClientRect();
            return { left: r.left, top: r.top, width: r.width, height: r.height };
        });
        for (const [wx, wy] of [[3.15, 1.05], [3.24, 1.51]]) {
            const { clientX, clientY } = levels.worldToClient(wx, wy, rawLevel, rect);
            await pressKey(page, 49);
            await pressKey(page, 86); // 'v' — vertical orientation
            await page.evaluate(([x, y]) => {
                document.querySelector('#graphics').dispatchEvent(
                    new MouseEvent('mousemove', { clientX: x, clientY: y, bubbles: true }));
            }, [clientX, clientY]);
            await page.waitForTimeout(150);
            await pressKey(page, 13);
        }
        await expect(page.locator('.dynamic .remaining')).toHaveText('2 left');

        await page.locator('#toggle-physics').click();
        await expect(page.locator('#rating-box')).toBeVisible({ timeout: 20000 });
    });

    test('arrow indicator shows on custom-gravity levels, not on default ones', async ({ page }) => {
        await bootIntoLevel(page, 2);
        const onCustom = await peakMovingPixels(page);
        expect(onCustom).toBeGreaterThan(15000);
    });

    test('no arrow indicator on the default-gravity level 1', async ({ page }) => {
        await bootIntoLevel(page, 1);
        const onDefault = await peakMovingPixels(page);
        expect(onDefault).toBeLessThan(10000);
    });
});

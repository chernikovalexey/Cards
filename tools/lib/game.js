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
        const out = { chapter: last.chapter ?? null, level: last.level ?? null, ...s };
        delete out.last;
        return out;
    }
}

module.exports = { Game, FAIL_TEXT };

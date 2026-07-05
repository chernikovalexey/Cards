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

test('restartLevel restores counters after placements and a failed apply', { timeout: 180000 }, async () => {
    const h = await createHarness({ profile: { seen_howto: 'true', runout_occured: 'true' } });
    const g = new Game(h);
    try {
        await g.gotoLevel(1);
        await g.place({ x: 0.6, y: 2.0 });
        await g.place({ x: 0.6, y: 3.0 });
        await g.apply();                       // fails, physics stays on
        const r = await g.restartLevel();
        assert.equal(r.ok, true, JSON.stringify(r));
        assert.equal(r.remaining.dynamic, 3);
        // And the level is playable again:
        const placed = await g.place(BRIDGE);
        assert.equal(placed.ok, true, JSON.stringify(placed));
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

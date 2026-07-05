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

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

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

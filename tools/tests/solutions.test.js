'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const solutions = require('../lib/solutions');

const FILE = solutions.fileFor(99); // fake chapter to avoid touching real data

test.afterEach(() => { if (fs.existsSync(FILE)) fs.unlinkSync(FILE); });

test('saveIfBetter keeps the higher-star / fewer-card solution', async () => {
    let r = await solutions.saveIfBetter(99, 1, { stars: 1, cards: [{ x: 1 }, { x: 2 }] });
    assert.equal(r.saved, true);

    // worse (same stars, more cards) -> rejected
    r = await solutions.saveIfBetter(99, 1, { stars: 1, cards: [{ x: 1 }, { x: 2 }, { x: 3 }] });
    assert.equal(r.saved, false);
    assert.equal(r.current.cards.length, 2);

    // better stars -> accepted
    r = await solutions.saveIfBetter(99, 1, { stars: 3, cards: [{ x: 1 }, { x: 2 }, { x: 3 }] });
    assert.equal(r.saved, true);

    // same stars, fewer cards -> accepted
    r = await solutions.saveIfBetter(99, 1, { stars: 3, cards: [{ x: 5 }] });
    assert.equal(r.saved, true);
    assert.equal(solutions.getLevel(99, 1).cards.length, 1);

    // concurrent writers to different levels don't lose data
    await Promise.all([
        solutions.saveIfBetter(99, 2, { stars: 2, cards: [{ x: 1 }] }),
        solutions.saveIfBetter(99, 3, { stars: 1, cards: [{ x: 1 }] }),
    ]);
    assert.equal(solutions.load(99).levels.length, 3);
});

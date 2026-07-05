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
    assert.equal(r.levels[0].outcome, 'won', JSON.stringify(r.levels));
    assert.equal(r.levels[0].stars, 3);
    const st = fs.statSync(r.video);
    assert.ok(st.size > 20000, `video too small: ${st.size}`);
});

#!/usr/bin/env node
// Sequentially replays a chapter's stored solutions in the true progression
// context, regenerating the per-level profile snapshots as it goes. Run this
// after changing any earlier level's solution — downstream context shifts.
//   node tools/validate.js --chapter 1 [--video]
'use strict';
const solutions = require('./lib/solutions');
const { verifyAndRecord } = require('./lib/recorder');

async function main() {
    const args = process.argv.slice(2);
    const get = (k) => { const i = args.indexOf(`--${k}`); return i >= 0 ? args[i + 1] : null; };
    const chapter = parseInt(get('chapter'), 10);
    if (!chapter) { console.error('usage: validate.js --chapter C [--video]'); process.exit(2); }
    const doc = solutions.load(chapter);
    const levelsSorted = [...doc.levels].sort((a, b) => a.level - b.level);
    let bad = 0;
    for (const l of levelsSorted) {
        const r = await verifyAndRecord(chapter, l.level, l.cards, { video: args.includes('--video') });
        const clean = r.ok;
        if (!clean) bad++;
        console.log(`${chapter}-${l.level}: ${clean ? `won ${r.verified.stars}*` : `${r.verified}  <-- broken, re-solve from here`}`);
        if (!clean) break; // later levels' context is now unknown
    }
    process.exit(bad ? 1 : 0);
}

main().catch((e) => { console.error(e); process.exit(1); });

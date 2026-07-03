#!/usr/bin/env node
// THE way to save a solution. Verifies the cards win IN CONTEXT (the world
// state after the previous level — earlier levels' cards are solid bodies),
// merges into solutions/chapter_C.json only if better (stars, then fewer
// cards), captures the after-win profile snapshot that the NEXT level needs
// (solutions/profiles/), and keeps proofs/chapter_C/level_LL.webm fresh.
// Safe to run from several agents at once.
//
//   node tools/record.js --chapter 1 --level 6 --cards '[{"x":4.1,"y":4.36,"angle":0}]'
//   node tools/record.js --chapter 1 --level 6 --cards-file sol.json
//   node tools/record.js --chapter 1 --level 6 --from-solutions   # re-verify stored + ensure video/profile
//   node tools/record.js --chapter 1 --all                        # sequentially re-verify the whole chapter
'use strict';
const fs = require('fs');
const solutions = require('./lib/solutions');
const { verifyAndRecord } = require('./lib/recorder');

async function main() {
    const args = process.argv.slice(2);
    const get = (k) => { const i = args.indexOf(`--${k}`); return i >= 0 ? args[i + 1] : null; };
    const chapter = parseInt(get('chapter'), 10);
    if (!chapter) { console.error('usage: record.js --chapter C (--level L (--cards JSON | --cards-file F | --from-solutions) | --all) [--out proofs] [--no-video]'); process.exit(2); }
    const outDir = get('out') || 'proofs';
    const video = !args.includes('--no-video');

    const targets = [];
    if (args.includes('--all')) {
        // Sequential by construction: each level's win regenerates the
        // context profile the next level is verified against.
        for (const l of solutions.load(chapter).levels) targets.push({ level: l.level, cards: l.cards });
        targets.sort((a, b) => a.level - b.level);
    } else {
        const level = parseInt(get('level'), 10);
        if (!level) { console.error('record.js: need --level (or --all)'); process.exit(2); }
        let cards;
        if (args.includes('--from-solutions')) {
            const cur = solutions.getLevel(chapter, level);
            if (!cur) { console.error(`no stored solution for ${chapter}-${level}`); process.exit(2); }
            cards = cur.cards;
        } else {
            cards = JSON.parse(get('cards') || fs.readFileSync(get('cards-file'), 'utf8'));
        }
        targets.push({ level, cards });
    }

    const out = [];
    for (const t of targets) {
        const r = await verifyAndRecord(chapter, t.level, t.cards, { outDir, video });
        out.push(r);
        process.stderr.write(`${chapter}-${t.level}: ${r.ok
            ? `won ${r.verified.stars}* (saved=${r.saved}, profile=${r.profileSaved}, video=${r.videoRefreshed ? 'recorded' : 'kept'})`
            : `NOT WON (${r.verified}${r.detail ? ': ' + r.detail : ''})`}\n`);
        if (!r.ok && args.includes('--all')) break; // downstream context would be stale
    }
    process.stdout.write(JSON.stringify(out.length === 1 ? out[0] : out, null, 2) + '\n');
    process.exit(out.every((r) => r.ok) ? 0 : 1);
}

main().catch((e) => { console.error(e); process.exit(1); });

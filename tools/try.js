#!/usr/bin/env node
// One-shot scenario probe with screenshots — the interactive-solving loop:
//   node tools/try.js --chapter 2 --level 3 --cards '[{"x":6,"y":1,"angle":0}]' --shots /tmp/x
// Prints JSON: placement verdicts, apply outcome, screenshot paths.
'use strict';
const fs = require('fs');
const path = require('path');
const levels = require('./lib/levels');
const { createHarness } = require('./lib/harness');
const { Game } = require('./lib/game');

async function main() {
    const args = process.argv.slice(2);
    const get = (k) => { const i = args.indexOf(`--${k}`); return i >= 0 ? args[i + 1] : null; };
    const chapter = parseInt(get('chapter'), 10);
    const level = parseInt(get('level'), 10);
    const cards = JSON.parse(get('cards') || (get('cards-file') ? fs.readFileSync(get('cards-file'), 'utf8') : '[]'));
    const shots = get('shots');
    if (!chapter || !level) { console.error('usage: try.js --chapter C --level L --cards JSON | --cards-file F [--shots DIR] [--no-apply]'); process.exit(2); }
    if (shots) fs.mkdirSync(shots, { recursive: true });

    const h = await createHarness({ profile: levels.searchProfile(chapter, level) });
    const g = new Game(h);
    const out = { chapter, level, placements: [] };
    try {
        const at = await g.gotoLevel(chapter);
        out.at = at;
        if (at.level !== level) throw new Error(`landed on level ${at.level}, wanted ${level}`);
        for (const card of cards) out.placements.push(await g.place(card));
        if (shots) { out.beforeShot = path.join(shots, `c${chapter}l${level}-before.png`); await g.screenshot(out.beforeShot); }
        if (!args.includes('--no-apply') && cards.length) {
            out.result = await g.apply(parseInt(get('max-ticks'), 10) || 3600);
            if (shots) { out.afterShot = path.join(shots, `c${chapter}l${level}-after.png`); await g.screenshot(out.afterShot); }
        }
        out.cardsProbe = await g.cards().catch(() => null);
    } finally {
        await h.close();
    }
    process.stdout.write(JSON.stringify(out, null, 2) + '\n');
}

main().catch((e) => { console.error(e); process.exit(1); });

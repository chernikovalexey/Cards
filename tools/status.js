#!/usr/bin/env node
// Campaign status: per-level stars, chapter totals, unlock thresholds, and
// which proof videos exist. Pure filesystem — instant, no browser.
'use strict';
const fs = require('fs');
const path = require('path');
const solutions = require('./lib/solutions');
const levels = require('./lib/levels');

const UNLOCK = { 1: 0, 2: 30, 3: 60 };

function main() {
    const summary = { chapters: [], totalStars: 0 };
    for (let c = 1; c <= 3; c++) {
        const doc = solutions.load(c);
        const byLevel = new Map(doc.levels.map((l) => [l.level, l]));
        const n = levels.loadChapter(c).levels.length;
        const rows = [];
        let stars = 0;
        for (let l = 1; l <= n; l++) {
            const cur = byLevel.get(l) || null;
            const video = path.join('proofs', `chapter_${c}`, `level_${String(l).padStart(2, '0')}.webm`);
            rows.push({
                level: l,
                stars: cur ? cur.stars : 0,
                cards: cur ? cur.cards.length : null,
                solved: !!cur,
                threeStarTarget: levels.levelInfo(c, l).stars[0],
                video: fs.existsSync(video),
            });
            stars += cur ? cur.stars : 0;
        }
        summary.chapters.push({ chapter: c, stars, maxStars: n * 3, unlockNeeds: UNLOCK[c], levels: rows });
        summary.totalStars += stars;
    }
    summary.chapter2Unlocked = summary.chapters[0].stars >= UNLOCK[2] ? true : `need ${UNLOCK[2]} stars in ch1 (have ${summary.chapters[0].stars})`;
    summary.chapter3Unlocked = (summary.chapters[0].stars + summary.chapters[1].stars) >= UNLOCK[3] ? true : `need ${UNLOCK[3]} total (have ${summary.chapters[0].stars + summary.chapters[1].stars})`;

    if (process.argv.includes('--json')) {
        process.stdout.write(JSON.stringify(summary, null, 2) + '\n');
        return;
    }
    for (const ch of summary.chapters) {
        const cells = ch.levels.map((r) => `${String(r.level).padStart(2)}:${r.solved ? r.stars + '*' : '--'}${r.video ? 'v' : ' '}`);
        process.stdout.write(`chapter ${ch.chapter}  [${cells.join(' ')}]  ${ch.stars}/${ch.maxStars} stars\n`);
    }
    process.stdout.write(`total ${summary.totalStars} | ch2 unlock: ${summary.chapter2Unlocked === true ? 'OK' : summary.chapter2Unlocked} | ch3 unlock: ${summary.chapter3Unlocked === true ? 'OK' : summary.chapter3Unlocked}\n`);
}

main();

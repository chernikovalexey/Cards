#!/usr/bin/env node
// Campaign status: per-level stars, chapter totals, unlock thresholds, and
// which proof videos exist. Pure filesystem — instant, no browser.
'use strict';
const fs = require('fs');
const path = require('path');
const solutions = require('./lib/solutions');
const levels = require('./lib/levels');

const CHAPTERS = JSON.parse(fs.readFileSync(
    path.join(__dirname, '..', 'web', 'levels', 'chapters.json'), 'utf8')).chapters;

function main() {
    const summary = { chapters: [], totalStars: 0 };
    for (let c = 1; c <= CHAPTERS.length; c++) {
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
        summary.chapters.push({
            chapter: c, stars, maxStars: n * 3,
            unlockNeeds: CHAPTERS[c - 1].unlock_stars, levels: rows,
        });
        summary.totalStars += stars;
    }
    // Unlocks are computed from the total star count, like webapi.js does.
    summary.unlocks = {};
    let running = 0;
    for (let c = 1; c <= CHAPTERS.length; c++) {
        const need = CHAPTERS[c - 1].unlock_stars;
        summary.unlocks[`chapter${c}`] = running >= need
            ? true : `need ${need} total (have ${running})`;
        running += summary.chapters[c - 1].stars;
    }

    if (process.argv.includes('--json')) {
        process.stdout.write(JSON.stringify(summary, null, 2) + '\n');
        return;
    }
    for (const ch of summary.chapters) {
        const cells = ch.levels.map((r) => `${String(r.level).padStart(2)}:${r.solved ? r.stars + '*' : '--'}${r.video ? 'v' : ' '}`);
        process.stdout.write(`chapter ${ch.chapter}  [${cells.join(' ')}]  ${ch.stars}/${ch.maxStars} stars\n`);
    }
    const locks = Object.entries(summary.unlocks)
        .filter(([, v]) => v !== true)
        .map(([k, v]) => `${k} locked: ${v}`);
    process.stdout.write(`total ${summary.totalStars}${locks.length ? ' | ' + locks.join(' | ') : ''}\n`);
}

main();

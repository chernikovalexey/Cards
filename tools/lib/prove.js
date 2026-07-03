// Video proof mode: replay stored solutions in real time with recording.
'use strict';
const fs = require('fs');
const path = require('path');
const { createHarness } = require('./harness');
const { Game } = require('./game');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function proveChapter(chapter, solution, { outDir, profile = {}, levelsLimit = Infinity } = {}) {
    fs.mkdirSync(outDir, { recursive: true });
    const h = await createHarness({
        turbo: false,
        realTime: true,
        videoDir: outDir,
        profile: { seen_howto: 'true', runout_occured: 'true', ...profile },
    });
    const g = new Game(h);
    const levelResults = [];
    let exportedProfile = null;
    const video = h.page.video();
    try {
        let at = await g.gotoLevel(chapter);
        for (const sol of solution.levels) {
            if (sol.level > levelsLimit) break;
            if (at.level !== sol.level) {
                levelResults.push({ level: sol.level, outcome: 'skipped', error: `game is at level ${at.level}` });
                break;
            }
            await sleep(800); // let the level-name banner show on camera
            let placedAll = true;
            for (const card of sol.cards) {
                const p = await g.place(card);
                if (!p.ok) { placedAll = false; levelResults.push({ level: sol.level, outcome: 'error', error: `placement rejected: ${p.reason}` }); break; }
                await sleep(350); // watchable pacing
            }
            if (!placedAll) break;
            const r = await g.applyRealtime();
            levelResults.push({ level: sol.level, outcome: r.outcome, stars: r.stars, cards: sol.cards.length });
            if (r.outcome !== 'won') break;
            await sleep(1500); // show the star rating on camera
            const hasNext = sol.level < 12 && solution.levels.some((s) => s.level === sol.level + 1) && sol.level + 1 <= levelsLimit;
            if (hasNext) at = await g.nextLevel();
        }
        exportedProfile = await h.exportProfile();
        await sleep(1000);
    } finally {
        await h.close(); // finalizes the video file
    }
    const rawVideo = await video.path();
    const finalVideo = path.join(outDir, `chapter_${chapter}.webm`);
    fs.renameSync(rawVideo, finalVideo);
    return { video: finalVideo, levels: levelResults, profile: exportedProfile };
}

async function cmdProve(args) {
    const solutionsDir = args.solutions || 'solutions';
    const outDir = args.out || 'proofs';
    const only = args.chapter ? [parseInt(args.chapter, 10)] : [1, 2, 3];
    const levelsLimit = args.levels ? parseInt(args.levels, 10) : Infinity;
    const summary = { startedAt: new Date().toISOString(), chapters: [] };
    let profile = {};
    for (const chapter of only) {
        const file = path.join(solutionsDir, `chapter_${chapter}.json`);
        if (!fs.existsSync(file)) {
            summary.chapters.push({ chapter, error: `missing ${file}` });
            continue;
        }
        const solution = JSON.parse(fs.readFileSync(file, 'utf8'));
        process.stderr.write(`proving chapter ${chapter}...\n`);
        const r = await proveChapter(chapter, solution, { outDir, profile, levelsLimit });
        // Carry earned progress (stars/levels) into the next chapter: unlocks
        // are earned, not seeded.
        profile = r.profile || profile;
        summary.chapters.push({
            chapter,
            video: r.video,
            levels: r.levels,
            completed: r.levels.length === 12 && r.levels.every((l) => l.outcome === 'won'),
        });
    }
    fs.mkdirSync(outDir, { recursive: true });
    fs.writeFileSync(path.join(outDir, 'summary.json'), JSON.stringify(summary, null, 2));
    process.stdout.write(JSON.stringify(summary, null, 2) + '\n');
}

module.exports = { proveChapter, cmdProve };

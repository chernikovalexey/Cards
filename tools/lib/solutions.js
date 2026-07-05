// Shared store for solutions/chapter_C.json with only-improve merge
// semantics and a directory lock so several agents can record concurrently.
'use strict';
const fs = require('fs');
const path = require('path');

const DIR = path.join(__dirname, '..', '..', 'solutions');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function fileFor(chapter) { return path.join(DIR, `chapter_${chapter}.json`); }

function load(chapter) {
    const f = fileFor(chapter);
    if (!fs.existsSync(f)) return { chapter, levels: [] };
    return JSON.parse(fs.readFileSync(f, 'utf8'));
}

function getLevel(chapter, level) {
    return load(chapter).levels.find((l) => l.level === level) || null;
}

// a beats b when it has more stars, or equal stars with fewer cards.
function isBetter(a, b) {
    if (!b) return true;
    if ((a.stars || 0) !== (b.stars || 0)) return (a.stars || 0) > (b.stars || 0);
    return a.cards.length < b.cards.length;
}

async function withLock(fn) {
    fs.mkdirSync(DIR, { recursive: true });
    const lock = path.join(DIR, '.lock');
    let held = false;
    for (let i = 0; i < 200; i++) {
        try { fs.mkdirSync(lock); held = true; break; } catch (e) { await sleep(50); }
    }
    if (!held) throw new Error('solutions store lock timeout (stale solutions/.lock?)');
    try { return fn(); } finally { fs.rmdirSync(lock); }
}

// Merge a candidate {stars, cards} for one level; keeps whichever is better.
// Returns {saved, current} where current is what the store now holds.
function saveIfBetter(chapter, level, sol) {
    return withLock(() => {
        const doc = load(chapter);
        const cur = doc.levels.find((l) => l.level === level) || null;
        if (cur && !isBetter(sol, cur)) return { saved: false, current: cur };
        const entry = { level, stars: sol.stars, cards: sol.cards };
        doc.levels = doc.levels.filter((l) => l.level !== level);
        doc.levels.push(entry);
        doc.levels.sort((a, b) => a.level - b.level);
        fs.writeFileSync(fileFor(chapter), JSON.stringify(doc, null, 2));
        return { saved: true, current: entry };
    });
}

module.exports = { DIR, load, getLevel, isBetter, saveIfBetter, fileFor };

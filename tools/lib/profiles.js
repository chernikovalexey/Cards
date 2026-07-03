// World-context profiles. Levels are NOT independent: the game keeps every
// previous level's settled cards in the world as solid static bodies, so
// level N must be played in the world state left by winning N-1. That state
// is exactly the localStorage snapshot after the N-1 win (level_C_i entries
// hold the settled card positions; Level.preload restores them).
//
// solutions/profiles/chapter_C/level_LL.json = snapshot captured right after
// winning level L in context. contextProfile(C, L) is what a session playing
// level L must be seeded with.
'use strict';
const fs = require('fs');
const path = require('path');
const levels = require('./levels');

const DIR = path.join(__dirname, '..', '..', 'solutions', 'profiles');

function pathFor(chapter, level) {
    return path.join(DIR, `chapter_${chapter}`, `level_${String(level).padStart(2, '0')}.json`);
}

function load(chapter, level) {
    const f = pathFor(chapter, level);
    return fs.existsSync(f) ? JSON.parse(fs.readFileSync(f, 'utf8')) : null;
}

// Store the after-win snapshot of level L. `last` is rewritten so a fresh
// session seeded with this profile enters the NEXT level with all prior
// levels restored (Level.preload uses last.level when the chapter matches).
function save(chapter, level, snapshot) {
    const out = { ...snapshot };
    const total = levels.loadChapter(chapter).levels.length;
    if (level < total) {
        out.last = JSON.stringify({ chapter, level: level + 1 });
    } else {
        delete out.last; // chapter complete removes 'last' in the real game
    }
    fs.mkdirSync(path.dirname(pathFor(chapter, level)), { recursive: true });
    fs.writeFileSync(pathFor(chapter, level), JSON.stringify(out, null, 2));
    return pathFor(chapter, level);
}

// Profile a session must be seeded with to play (chapter, level) in the true
// progression context. Level 1 starts from a clean profile; later levels
// need the previous level's snapshot.
function contextProfile(chapter, level) {
    if (level === 1) return levels.searchProfile(chapter, 1);
    const p = load(chapter, level - 1);
    if (!p) {
        throw new Error(
            `no context profile for ${chapter}-${level}: solve and record level ` +
            `${chapter}-${level - 1} first (tools/record.js writes solutions/profiles/)`);
    }
    return p;
}

module.exports = { DIR, pathFor, load, save, contextProfile };

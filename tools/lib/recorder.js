// Verify a candidate solution IN CONTEXT (world state after the previous
// level), and on a win: capture the after-win profile snapshot, merge the
// solution if better, and keep the per-level proof video fresh.
// Shared by record.js, solve.js and validate.js.
'use strict';
const fs = require('fs');
const path = require('path');
const { createHarness } = require('./harness');
const { Game } = require('./game');
const solutions = require('./solutions');
const profiles = require('./profiles');
const { proveLevel } = require('./prove');

function videoPath(chapter, level, outDir) {
    return path.join(outDir, `chapter_${chapter}`, `level_${String(level).padStart(2, '0')}.webm`);
}

// Turbo-verify `cards` for (chapter, level) in context. Returns
// {outcome, stars, accepted, snapshot} — snapshot only on a win.
async function verifyInContext(chapter, level, cards) {
    const profile = profiles.contextProfile(chapter, level); // throws if predecessor missing
    const h = await createHarness({ profile });
    const g = new Game(h);
    try {
        const at = await g.gotoLevel(chapter);
        if (at.level !== level) {
            return { outcome: 'error', error: `context put the game at level ${at.level}, wanted ${level}` };
        }
        const accepted = [];
        const rejected = [];
        for (const card of cards) {
            const p = await g.place(card);
            if (p.ok) accepted.push(card); else rejected.push({ card, reason: p.reason });
        }
        if (!accepted.length) return { outcome: 'error', error: 'no card placed', rejected };
        const r = await g.apply(4800);
        if (r.outcome !== 'won') return { outcome: r.outcome, rejected };
        // saveCurrentProgress ran at the win, so localStorage now holds the
        // settled cards of this level — the context for the next level.
        const snapshot = await h.exportProfile();
        return { outcome: 'won', stars: r.stars, accepted, rejected, snapshot };
    } finally {
        await h.close();
    }
}

// Full pipeline for one candidate. Options:
//   outDir  — proofs directory (default 'proofs')
//   video   — keep the per-level proof video fresh (default true)
async function verifyAndRecord(chapter, level, cards, { outDir = 'proofs', video = true } = {}) {
    const v = await verifyInContext(chapter, level, cards);
    if (v.outcome !== 'won') {
        return { ok: false, chapter, level, verified: v.outcome, detail: v.error || null, rejected: v.rejected };
    }
    const merge = await solutions.saveIfBetter(chapter, level, { stars: v.stars, cards: v.accepted });
    // The stored snapshot must correspond to the stored BEST solution: only
    // overwrite it when this candidate became the best (or none existed).
    let profileSaved = false;
    if (merge.saved || !profiles.load(chapter, level)) {
        profiles.save(chapter, level, v.snapshot);
        profileSaved = true;
    }
    const vp = videoPath(chapter, level, outDir);
    let videoInfo = { video: vp, refreshed: false };
    if (video && (merge.saved || !fs.existsSync(vp))) {
        const pv = await proveLevel(chapter, level, merge.current.cards, { outDir });
        videoInfo = { ...pv, refreshed: true };
    }
    return {
        ok: true,
        chapter,
        level,
        verified: { outcome: 'won', stars: v.stars, cardsUsed: v.accepted.length },
        saved: merge.saved,
        profileSaved,
        best: { stars: merge.current.stars, cards: merge.current.cards.length },
        video: videoInfo.video,
        videoRefreshed: videoInfo.refreshed || false,
    };
}

module.exports = { verifyInContext, verifyAndRecord, videoPath };

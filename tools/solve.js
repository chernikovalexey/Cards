#!/usr/bin/env node
// Heuristic solver: generates placement candidates per level and searches
// them through the batch runner. Claude drives `cli.js play` for levels the
// generator can't crack, then records the manual solution here.
'use strict';
const fs = require('fs');
const path = require('path');
const levels = require('./lib/levels');
const { runScenarios } = require('./lib/batch');
const solutions = require('./lib/solutions');
const profiles = require('./lib/profiles');
const { verifyAndRecord } = require('./lib/recorder');

const STEP = Math.PI / 72;
const CARD_W = levels.CARD.w;
const CARD_H = levels.CARD.h;

function snap(angle) { return Math.round(angle / STEP) * STEP; }

function center(rect) { return { x: rect.x + rect.w / 2, y: rect.y + rect.h / 2 }; }

function generateCandidates(info, { rounds = 20 } = {}) {
    const up = info.gravity > 0; // blocks fall upward
    const A = center(info.from), B = center(info.to);
    // Clearances must beat box2d's polygon skin (~0.02 wu) or the ghost
    // registers a contact and the placement is rejected.
    const CLEAR = 0.05;
    const restY = (rect) => (up ? rect.y - CARD_H / 2 - CLEAR : rect.y + rect.h + CARD_H / 2 + CLEAR);
    const yA = restY(info.from), yB = restY(info.to);
    const budgetD = info.blocks.dynamic, budgetS = info.blocks.static;
    const asStatic = budgetD === 0;
    const bases = [];

    const mk = (cards) => {
        const d = cards.filter((c) => !c.static).length;
        const s = cards.filter((c) => c.static).length;
        if (d <= budgetD && s <= budgetS && cards.length > 0) bases.push({ cards });
    };

    const budget = budgetD + budgetS;
    const span = Math.abs(B.x - A.x);
    const STAGGER = CARD_H + 0.055; // surface gap stays above the contact skin

    // 1. single card spanning both cubes — feasible when the gap between the
    // cubes' inner edges is well under the card length (anchors on each side)
    const innerGap = span - levels.CUBE;
    if (innerGap < CARD_W * 0.85) {
        mk([{ x: (A.x + B.x) / 2, y: Math.max(yA, yB), angle: 0, static: asStatic }]);
        mk([{ x: (A.x + B.x) / 2, y: (yA + yB) / 2, angle: 0, static: asStatic }]);
    }

    // 2. plank bridges between the cube tops. Two patterns per card count:
    //    - weave (brick bond): even planks at rest height, odd planks lying
    //      across their joints one STAGGER up — stable despite low friction;
    //    - cascade: each plank one STAGGER above the previous (a ramp).
    for (let n = 2; n <= Math.min(10, budget); n++) {
        const sgn = B.x >= A.x ? 1 : -1;
        const x0 = A.x + sgn * CARD_W * 0.3;               // anchored over cube A
        const x1 = B.x - sgn * CARD_W * 0.3;               // anchored over cube B
        const step = (x1 - x0) / Math.max(1, n - 1);
        const lineY = (t) => yA + (yB - yA) * t;
        const row = (pattern) => {
            const cards = [];
            for (let i = 0; i < n; i++) {
                const t = n === 1 ? 0.5 : i / (n - 1);
                cards.push({
                    x: x0 + step * i,
                    y: lineY(t) + (up ? -1 : 1) * pattern(i) * STAGGER,
                    angle: 0,
                    static: asStatic,
                });
            }
            return cards;
        };
        // weave (brick bond): same-row planks must not overlap, odd planks
        // must rest on both neighbors
        if (Math.abs(step) >= (CARD_W + 0.06) / 2 && Math.abs(step) <= CARD_W * 0.8) {
            mk(row((i) => i % 2));
        }
        // cascade ramp: dense overlap, each plank a step above the previous
        if (Math.abs(step) <= CARD_W * 0.48) {
            mk(row((i) => i));
        }
    }

    // 3. tower: vertical cards stacked end-on-end from the lower cube's top
    // up to the higher cube (angular damping keeps aligned stacks standing).
    const lowRect = A.y < B.y ? info.from : info.to;
    const highRect = A.y < B.y ? info.to : info.from;
    const highC = A.y < B.y ? B : A;
    const dy = Math.abs(B.y - A.y);
    const seg = CARD_W + 0.05;
    if (dy > CARD_W * 0.5) {
        const base = lowRect.y + lowRect.h + 0.05;         // stack base on the low cube's top
        const target = highRect.y + 0.1;                   // overlap slightly past the high cube's underside
        const nV = Math.ceil(Math.max(0, target - base - CARD_W) / seg) + 1;
        if (nV >= 1 && nV <= budget) {
            const lowX = lowRect.x + lowRect.w / 2;
            // Standing beside the high cube (touching its side) avoids the
            // placement-overlap rejection a through-the-cube stack hits.
            const leftOfHigh = highRect.x - 0.055;
            const rightOfHigh = highRect.x + highRect.w + 0.055;
            for (const baseX of new Set([lowX, leftOfHigh, rightOfHigh])) {
                const cards = [];
                for (let i = 0; i < nV; i++) {
                    cards.push({ x: baseX, y: base + CARD_W / 2 + i * seg, angle: Math.PI / 2, static: asStatic });
                }
                mk(cards);
                // tower + top plank toward the target cube
                if (cards.length + 1 <= budget && Math.abs(highC.x - baseX) > 0.1) {
                    mk([...cards, {
                        x: (baseX + highC.x) / 2,
                        y: base + nV * seg + STAGGER,
                        angle: 0,
                        static: asStatic,
                    }]);
                }
            }
        }
    }

    // 4. jittered variants of every base
    const out = [...bases];
    for (const base of bases) {
        for (let r = 0; r < rounds; r++) {
            out.push({
                cards: base.cards.map((c) => ({
                    ...c,
                    x: c.x + (Math.random() * 2 - 1) * 0.06,
                    y: c.y + (Math.random() * 2 - 1) * 0.06,
                    angle: snap(c.angle + (Math.random() * 2 - 1) * 2 * STEP),
                })),
            });
        }
    }
    return out;
}

async function solveLevel(chapter, level, { parallel = 4, rounds = 20 } = {}) {
    const info = levels.levelInfo(chapter, level);
    const candidates = generateCandidates(info, { rounds });
    // Cheapest structures first: fewer cards means a better star rating.
    candidates.sort((a, b) => a.cards.length - b.cards.length);
    const scenarios = candidates.map((c, i) => ({ chapter, level, cards: c.cards, shard: i % parallel }));
    process.stderr.write(`level ${chapter}-${level}: trying ${scenarios.length} candidates\n`);
    const results = await runScenarios(scenarios, {
        parallel,
        // A 3-star win can't be beaten — stop the search early.
        stopWhen: (r) => r.outcome === 'won' && r.stars === 3,
    });
    const winners = results
        .filter((r) => r && r.outcome === 'won')
        .map((r) => ({
            // Keep only the placements the game accepted — a solution must
            // replay cleanly in prove mode (rejected cards abort the replay).
            cards: scenarios[r.index].cards.filter(
                (c) => !(r.rejected || []).some((j) => j.card === c)),
            stars: r.stars,
        }));
    if (!winners.length) return null;
    winners.sort((a, b) => (b.stars - a.stars) || (a.cards.length - b.cards.length));
    return winners[0];
}

async function main() {
    const args = process.argv.slice(2);
    const get = (k) => { const i = args.indexOf(`--${k}`); return i >= 0 ? args[i + 1] : null; };
    const chapter = parseInt(get('chapter'), 10);
    if (!chapter) { console.error('usage: solve.js --chapter C [--level L] [--parallel N] [--rounds R] [--force] [--no-video]'); process.exit(2); }
    const onlyLevel = get('level') ? parseInt(get('level'), 10) : null;
    const parallel = parseInt(get('parallel'), 10) || 4;
    const rounds = parseInt(get('rounds'), 10) || 20;
    const force = args.includes('--force');

    // Levels are sequential: level L is searched in the world state left by
    // winning L-1 (context profile). Without --force, levels that already
    // hold a 3-star solution are skipped; lower-star levels stay in scope.
    const have = new Map(solutions.load(chapter).levels.map((l) => [l.level, l.stars]));
    const targets = onlyLevel ? [onlyLevel]
        : Array.from({ length: levels.loadChapter(chapter).levels.length }, (_, i) => i + 1)
            .filter((l) => force || (have.get(l) || 0) < 3);

    for (const level of targets) {
        try {
            profiles.contextProfile(chapter, level); // throws if predecessor unrecorded
        } catch (e) {
            process.stderr.write(`level ${chapter}-${level}: SKIPPED — ${e.message}\n`);
            continue;
        }
        const sol = await solveLevel(chapter, level, { parallel, rounds });
        if (!sol) {
            process.stderr.write(`level ${chapter}-${level}: no win found — needs interactive play\n`);
            continue;
        }
        // Re-verify + persist through the shared pipeline (solution merge,
        // context snapshot for the next level, proof video).
        const r = await verifyAndRecord(chapter, level, sol.cards, { video: !args.includes('--no-video') });
        process.stderr.write(`level ${chapter}-${level}: ${r.ok
            ? `won ${r.verified.stars}* with ${r.verified.cardsUsed} cards (saved=${r.saved}, video=${r.videoRefreshed ? 'recorded' : 'kept'})`
            : `verification failed (${r.verified})`}\n`);
    }
}

if (require.main === module) main().catch((e) => { console.error(e); process.exit(1); });
module.exports = { generateCandidates, solveLevel };

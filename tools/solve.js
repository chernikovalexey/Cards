#!/usr/bin/env node
// Heuristic solver: generates placement candidates per level and searches
// them through the batch runner. Claude drives `cli.js play` for levels the
// generator can't crack, then records the manual solution here.
'use strict';
const fs = require('fs');
const path = require('path');
const levels = require('./lib/levels');
const { runScenarios } = require('./lib/batch');

const STEP = Math.PI / 72;
const CARD_W = levels.CARD.w;
const CARD_H = levels.CARD.h;

function snap(angle) { return Math.round(angle / STEP) * STEP; }

function center(rect) { return { x: rect.x + rect.w / 2, y: rect.y + rect.h / 2 }; }

function generateCandidates(info, { rounds = 20 } = {}) {
    const up = info.gravity > 0; // blocks fall upward
    const A = center(info.from), B = center(info.to);
    const restY = (rect) => (up ? rect.y - CARD_H / 2 - 0.02 : rect.y + rect.h + CARD_H / 2 + 0.02);
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
    const STAGGER = 0.05; // > card thickness: staggered planks never overlap at placement

    // 1. single card spanning both cubes
    if (span < CARD_W * 0.95) {
        mk([{ x: (A.x + B.x) / 2, y: Math.max(yA, yB), angle: 0, static: asStatic }]);
        mk([{ x: (A.x + B.x) / 2, y: (yA + yB) / 2, angle: 0, static: asStatic }]);
    }

    // 2. plank chain: horizontally overlapping cards, each one STAGGER higher
    // than the previous so nothing overlaps at placement; they settle into a
    // connected ramp when physics run. Both directions (low->high, high->low).
    for (let n = 2; n <= Math.min(8, budget); n++) {
        const reach = CARD_W + (n - 1) * CARD_W * 0.55; // ~45% overlap between planks
        if (reach < span * 0.95) continue;
        const step = n > 1 ? (B.x - A.x) / (n - 1) * ((span - CARD_W * 0.5) / span) : 0;
        for (const dir of [1, -1]) {
            const cards = [];
            for (let i = 0; i < n; i++) {
                const k = dir === 1 ? i : n - 1 - i;
                cards.push({
                    x: A.x + step * k + (B.x > A.x ? 1 : -1) * CARD_W * 0.2,
                    y: (yA + (yB - yA) * (k / Math.max(1, n - 1))) + (up ? -1 : 1) * i * STAGGER,
                    angle: 0,
                    static: asStatic,
                });
            }
            mk(cards);
        }
    }

    // 3. tower: vertical cards stacked end-on-end from the lower cube's top
    // up to the higher cube (angular damping keeps aligned stacks standing).
    const lowRect = A.y < B.y ? info.from : info.to;
    const highRect = A.y < B.y ? info.to : info.from;
    const highC = A.y < B.y ? B : A;
    const dy = Math.abs(B.y - A.y);
    const seg = CARD_W + 0.008;
    if (dy > CARD_W * 0.5) {
        const base = lowRect.y + lowRect.h + 0.01;         // stack base on the low cube's top
        const target = highRect.y + 0.1;                   // overlap slightly past the high cube's underside
        const nV = Math.ceil(Math.max(0, target - base - CARD_W) / seg) + 1;
        if (nV >= 1 && nV <= budget) {
            const lowX = lowRect.x + lowRect.w / 2;
            for (const baseX of new Set([lowX, highC.x])) {
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
        .map((r) => ({ cards: scenarios[r.index].cards, stars: r.stars }));
    if (!winners.length) return null;
    winners.sort((a, b) => (b.stars - a.stars) || (a.cards.length - b.cards.length));
    return winners[0];
}

function mergeSolution(chapter, level, sol) {
    const dir = path.join(__dirname, '..', 'solutions');
    fs.mkdirSync(dir, { recursive: true });
    const file = path.join(dir, `chapter_${chapter}.json`);
    const doc = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : { chapter, levels: [] };
    doc.levels = doc.levels.filter((l) => l.level !== level);
    doc.levels.push({ level, stars: sol.stars, cards: sol.cards });
    doc.levels.sort((a, b) => a.level - b.level);
    fs.writeFileSync(file, JSON.stringify(doc, null, 2));
    return file;
}

async function main() {
    const args = process.argv.slice(2);
    const get = (k) => { const i = args.indexOf(`--${k}`); return i >= 0 ? args[i + 1] : null; };
    const chapter = parseInt(get('chapter'), 10);
    if (!chapter) { console.error('usage: solve.js --chapter C [--level L] [--parallel N] [--rounds R] [--force]'); process.exit(2); }
    const onlyLevel = get('level') ? parseInt(get('level'), 10) : null;
    const parallel = parseInt(get('parallel'), 10) || 4;
    const rounds = parseInt(get('rounds'), 10) || 20;
    const force = args.includes('--force');

    const file = path.join(__dirname, '..', 'solutions', `chapter_${chapter}.json`);
    const have = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')).levels.map((l) => l.level) : [];
    const targets = onlyLevel ? [onlyLevel]
        : Array.from({ length: levels.loadChapter(chapter).levels.length }, (_, i) => i + 1)
            .filter((l) => force || !have.includes(l));

    for (const level of targets) {
        const sol = await solveLevel(chapter, level, { parallel, rounds });
        if (sol) {
            mergeSolution(chapter, level, sol);
            process.stderr.write(`level ${chapter}-${level}: SOLVED with ${sol.cards.length} cards, ${sol.stars} stars\n`);
        } else {
            process.stderr.write(`level ${chapter}-${level}: unsolved — needs interactive play\n`);
        }
    }
}

if (require.main === module) main().catch((e) => { console.error(e); process.exit(1); });
module.exports = { generateCandidates, solveLevel };

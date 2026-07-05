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

// The game ships its own solution sketches (web/levels/hints.js, served to
// HintManager through the getHint shim). They are SETTLED card states, not
// legal placements — cards must be lifted off their supports before the
// ghost check accepts them.
function loadHint(chapter, level) {
    try {
        const src = fs.readFileSync(path.join(__dirname, '..', 'web', 'levels', 'hints.js'), 'utf8');
        const sandbox = { window: {} };
        require('vm').runInNewContext(src, sandbox);
        return ((sandbox.window.LocalHintData || {}).chapters || {})[String(chapter)]?.[level - 1] || null;
    } catch (e) { return null; }
}

function center(rect) { return { x: rect.x + rect.w / 2, y: rect.y + rect.h / 2 }; }

// Hint solutions are SETTLED card states, not legal placements: lift each
// card so the ghost check passes. Cards resting on other hint cards need a
// larger lift than cards resting on the world, so produce uniform lifts and
// bottom-up rank-staggered lifts. Statics keep their pose (they float).
function hintSeeds(info) {
    const hint = loadHint(info.chapter, info.level);
    if (!hint || !hint.length) return [];
    const up = info.gravity > 0;
    const byY = [...hint].sort((a, b) => a.y - b.y);
    const rank = new Map(hint.map((h) => [h, byY.indexOf(h)]));
    const out = [];
    for (const [base, perRank] of [[0.035, 0], [0.05, 0], [0.08, 0], [0.035, 0.03], [0.05, 0.045]]) {
        out.push({ cards: hint.map((h) => ({
            x: h.x,
            y: h.y + (up ? -1 : 1) * (h.static ? 0.02 : base + perRank * rank.get(h)),
            angle: snap(h.angle),
            static: !!h.static,
        })) });
    }
    return out;
}

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

    // 0. hint-seeded: start from the designer's settled solution.
    for (const cand of hintSeeds(info)) bases.push(cand);

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

    // 2b. Settled-raft search. Old embedded hint/save traces show that many
    // flat gaps are won by a dense, nearly-horizontal two-band raft. Those
    // traces are settled shapes, not legal placement lists, so generate a
    // placement-clear version with alternating rows and small slopes.
    if (Math.abs(yA - yB) < CARD_W * 0.5 && span > CARD_W * 1.2) {
        const sgn = B.x >= A.x ? 1 : -1;
        const baseY = Math.max(yA, yB);
        for (let n = 3; n <= Math.min(7, budget); n++) {
            const x0s = [
                A.x,
                A.x + sgn * CARD_W * 0.12,
                A.x - sgn * CARD_W * 0.08,
            ];
            const x1s = [
                B.x,
                B.x - sgn * CARD_W * 0.12,
                B.x + sgn * CARD_W * 0.08,
            ];
            for (let k = 0; k < x0s.length; k++) {
                const x0 = x0s[k], x1 = x1s[k];
                const step = (x1 - x0) / Math.max(1, n - 1);
                // Same-row cards are every other card; keep those legal at
                // placement time while allowing the final raft to settle denser.
                if (Math.abs(step) * 2 < CARD_W + 0.06) continue;
                for (const band of [0.085, 0.105, 0.125]) {
                    for (const slope of [0, STEP / 2, -STEP / 2]) {
                        const cards = [];
                        for (let i = 0; i < n; i++) {
                            const row = i % 2;
                            cards.push({
                                x: x0 + step * i,
                                y: baseY + (up ? -1 : 1) * row * band,
                                angle: slope * (i % 2 ? -1 : 1),
                                static: asStatic,
                            });
                        }
                        mk(cards);
                    }
                }
            }
        }
    }

    // 2c. counterweighted double cantilever for flat gaps too wide to weave:
    // an anchor plank on each cube top with its tip cantilevered into the
    // gap, a counterweight card on the anchored end (moment balance: the
    // counterweight's ~0.28 wu lever beats the bridge load on the ~0.24 wu
    // tip lever), and a bridge plank laid across the two tips one layer up.
    if (Math.abs(yA - yB) < 0.3 && innerGap > CARD_W * 0.85 && innerGap < CARD_W * 2 && !up) {
        const sgn = B.x >= A.x ? 1 : -1;
        const innerA = A.x + sgn * levels.CUBE / 2;   // inner top corners
        const innerB = B.x - sgn * levels.CUBE / 2;
        const bridgeY = Math.max(yA, yB) + STAGGER;
        for (const off of [0.02, 0.05, 0.09]) {
            const cantA = innerA - sgn * off;          // anchor centers just
            const cantB = innerB + sgn * off;          // inside the cube edge
            const tipA = cantA + sgn * CARD_W / 2;
            const tipB = cantB - sgn * CARD_W / 2;
            const middle = Math.abs(tipB - tipA);
            const anchors = (cw) => [
                { x: cantA, y: yA, angle: 0, static: asStatic },
                { x: cantB, y: yB, angle: 0, static: asStatic },
                // counterweights sit over the cube, pinning the anchored ends
                ...(cw ? [
                    { x: cantA - sgn * CARD_W * 0.45, y: yA + STAGGER, angle: 0, static: asStatic },
                    { x: cantB + sgn * CARD_W * 0.45, y: yB + STAGGER, angle: 0, static: asStatic },
                ] : []),
            ];
            if (middle <= CARD_W - 0.08) {
                // one bridge plank reaches both tips
                mk([...anchors(true), { x: (tipA + tipB) / 2, y: bridgeY, angle: 0, static: asStatic }]);
                mk([...anchors(false), { x: (tipA + tipB) / 2, y: bridgeY, angle: 0, static: asStatic }]);
            } else if (middle <= CARD_W * 1.7) {
                // two woven bridge planks across the tips
                mk([...anchors(true),
                    { x: tipA + sgn * CARD_W * 0.3, y: bridgeY, angle: 0, static: asStatic },
                    { x: tipB - sgn * CARD_W * 0.3, y: bridgeY + STAGGER, angle: 0, static: asStatic }]);
            }
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
                for (const lean of [0, STEP / 2, -STEP / 2, STEP, -STEP]) {
                    const cards = [];
                    for (let i = 0; i < nV; i++) {
                        cards.push({
                            x: baseX + i * Math.sin(lean) * 0.03,
                            y: base + CARD_W / 2 + i * seg,
                            angle: Math.PI / 2 + lean,
                            static: asStatic,
                        });
                    }
                    mk(cards);
                    // tower + top plank toward the target cube
                    if (cards.length + 1 <= budget && Math.abs(highC.x - baseX) > 0.1) {
                        mk([...cards, {
                            x: (baseX + highC.x) / 2,
                            y: base + nV * seg + STAGGER,
                            angle: lean / 2,
                            static: asStatic,
                        }]);
                    }
                }
            }
        }
    }

    // 2d. drop-leg bridge for descending gaps: a vertical leg stands on the
    // LOW cube's inner edge rising to the HIGH cube's top level, then a
    // counterweighted cantilever plank runs from the high cube's top across
    // to the leg top. Handles "down and across" gaps that neither flat
    // bridges (mid-air collapse) nor towers (no support beside the high
    // cube) can cross.
    if (!up && dy > 0.3 && innerGap > 0.15 && innerGap < CARD_W * 2.2) {
        const sgn = highC.x >= (A.y < B.y ? A : B).x ? -1 : 1; // direction high -> low
        const lowTop = lowRect.y + lowRect.h;
        const highTop = highRect.y + highRect.h;
        const nLeg = Math.max(1, Math.round((highTop - lowTop) / seg));
        if (nLeg + 2 <= budget) {
            const legEdge = sgn > 0 ? lowRect.x : lowRect.x + lowRect.w; // low cube's edge facing the high cube
            for (const legOff of [0.05, 0.1, 0.16]) {
                const legX = legEdge + sgn * legOff; // leg stands on the low cube, just inside that edge
                const legTop = lowTop + 0.05 + nLeg * CARD_W;
                const leg = Array.from({ length: nLeg }, (_, i) => ({
                    x: legX,
                    y: lowTop + 0.05 + CARD_W / 2 + i * seg,
                    angle: Math.PI / 2,
                    static: asStatic,
                }));
                for (const off of [0.02, 0.06]) {
                    const innerHigh = sgn > 0 ? highRect.x + highRect.w : highRect.x;
                    const cant = innerHigh - sgn * off;
                    const tip = cant + sgn * CARD_W / 2;
                    const gapTipLeg = Math.abs(legX - tip);
                    const plankY = Math.max(highTop + CARD_H / 2 + 0.05, legTop + CARD_H / 2 + 0.05) + STAGGER;
                    const anchor = [
                        { x: cant, y: highTop + CARD_H / 2 + 0.05, angle: 0, static: asStatic },
                        { x: cant - sgn * CARD_W * 0.45, y: highTop + CARD_H / 2 + 0.05 + STAGGER, angle: 0, static: asStatic },
                    ];
                    if (gapTipLeg <= CARD_W - 0.08) {
                        mk([...leg, ...anchor, { x: (tip + legX) / 2, y: plankY, angle: 0, static: asStatic }]);
                        // without counterweight (one card cheaper)
                        mk([...leg, anchor[0], { x: (tip + legX) / 2, y: plankY, angle: 0, static: asStatic }]);
                    } else if (gapTipLeg <= CARD_W * 1.7 && nLeg + 4 <= budget) {
                        mk([...leg, ...anchor,
                            { x: tip + sgn * CARD_W * 0.3, y: plankY, angle: 0, static: asStatic },
                            { x: legX - sgn * CARD_W * 0.3, y: plankY + STAGGER, angle: 0, static: asStatic }]);
                    }
                }
            }
        }
    }

    // 3b. braced lean-to tower. The target cube is a fixed anchor, so a
    // stack that leans INTO its near corner is stable even at friction
    // 0.115 — but the contact must form during the fall: the engine walks
    // the chain exactly once, at the first all-asleep frame, and
    // force-sleeps slow creepers (GameEngine.update), so a plumb tower
    // beside the cube dies with a permanent 0.05+ gap. Pre-tilting the top
    // card toward the cube makes gravity torque rotate it onto the corner
    // while the stack is still settling.
    if (dy > CARD_W * 0.5 && !up) {
        const base = lowRect.y + lowRect.h + 0.05;
        const nV = Math.ceil(Math.max(0, highRect.y + 0.1 - base - CARD_W) / seg) + 1;
        const sides = [
            { xs: (g) => highRect.x + highRect.w + CARD_H / 2 + g, lean: +1 }, // right of cube, tip left
            { xs: (g) => highRect.x - CARD_H / 2 - g, lean: -1 },              // left of cube, tip right
        ];
        for (const { xs, lean } of sides) {
            for (const gap of [0.07, 0.1, 0.14]) {
                for (const n of new Set([nV, nV + 1])) {
                    if (n < 2 || n > budget) continue;
                    for (const tiltSteps of [1, 2, 3, 4]) {
                        const tilt = tiltSteps * STEP;
                        // plumb stack, only the top card pre-tilted at the cube
                        mk(Array.from({ length: n }, (_, i) => ({
                            x: xs(gap),
                            y: base + CARD_W / 2 + i * seg,
                            angle: Math.PI / 2 + (i === n - 1 ? lean * tilt : 0),
                            static: asStatic,
                        })));
                        // whole stack pre-tilted, cards staggered end-to-end
                        // along the lean line
                        mk(Array.from({ length: n }, (_, i) => ({
                            x: xs(gap) - lean * Math.sin(tilt) * i * seg,
                            y: base + CARD_W / 2 + i * seg,
                            angle: Math.PI / 2 + lean * tilt,
                            static: asStatic,
                        })));
                    }
                }
            }
        }
    }

    // 3c. zigzag staircase for steep climbs: cards alternate +/-zig from
    // vertical, each based near the previous card's upper end, bracing each
    // other like roof trusses. Rises ~CARD_W*sin(zig) per card, needs no
    // wall. Placement staggers +0.06 per card so ghosts never touch.
    if (dy > CARD_W * 1.5 && !up) {
        const base = lowRect.y + lowRect.h + 0.05;
        const lowC = A.y < B.y ? A : B;
        for (const zigDeg of [24, 27] /* x PI/72: 60 deg, 67.5 deg */) {
            const zig = zigDeg * STEP;
            const dyz = CARD_W * Math.sin(zig), dxz = CARD_W * Math.cos(zig);
            const n = Math.min(budget, Math.ceil((highRect.y + 0.1 - base) / dyz));
            if (n < 2) continue;
            for (const firstDir of [1, -1]) {
                const cards = [];
                let px = lowC.x - firstDir * dxz / 2, py = base;
                for (let i = 0; i < n; i++) {
                    const dir = firstDir * (i % 2 ? -1 : 1);
                    cards.push({
                        x: px + dir * dxz / 2,
                        y: py + dyz / 2 + 0.06 * (i + 1),
                        angle: snap(dir > 0 ? zig : Math.PI - zig),
                        static: asStatic,
                    });
                    px += dir * dxz; py += dyz;
                }
                mk(cards);
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
module.exports = { generateCandidates, solveLevel, hintSeeds };

#!/usr/bin/env node
// Self-driving level solver: evolutionary repair loop over placements,
// evaluated in ONE warm browser session (restart between attempts, no
// reboot). Feedback = settled card positions (probeCards); repair rules fix
// the card that failed instead of blind re-jittering. Wins are re-verified
// and persisted through the shared recorder pipeline.
//
//   node tools/autosolve.js --chapter 1 --level 9 [--attempts 120] [--seed-only]
'use strict';
const levels = require('./lib/levels');
const profiles = require('./lib/profiles');
const { createHarness } = require('./lib/harness');
const { Game } = require('./lib/game');
const { verifyAndRecord } = require('./lib/recorder');
const { generateCandidates, hintSeeds } = require('./solve');

const W = 0.529, H = 0.029;

function axisPoints(c, n = 7) {
    // n sample points along a card's long axis (settled or placed pose)
    const out = [];
    for (let i = 0; i < n; i++) {
        const t = (i / (n - 1) - 0.5) * (W - 0.02);
        out.push({ x: c.x + Math.cos(c.angle || 0) * t, y: c.y + Math.sin(c.angle || 0) * t });
    }
    return out;
}

function rectDist(p, r) {
    const dx = Math.max(r.x - p.x, 0, p.x - (r.x + r.w));
    const dy = Math.max(r.y - p.y, 0, p.y - (r.y + r.h));
    return Math.hypot(dx, dy);
}

// Chain gap: min distance between the connected component reachable from
// `from` and the one reachable from `to`, over settled cards. 0 = probably
// connected (within touch tolerance).
function chainGap(settled, info) {
    const TOUCH = 0.09;
    const pts = settled.map((c) => axisPoints(c));
    const n = settled.length;
    const near = (i, j) => pts[i].some((p) => pts[j].some((q) => Math.hypot(p.x - q.x, p.y - q.y) < TOUCH));
    const nearRect = (i, r) => pts[i].some((p) => rectDist(p, r) < TOUCH);
    const comp = new Array(n).fill(-1);
    const grow = (seedRect, id) => {
        let changed = true;
        while (changed) {
            changed = false;
            for (let i = 0; i < n; i++) {
                if (comp[i] !== -1) continue;
                if (nearRect(i, seedRect) || comp.some((c, j) => c === id && near(i, j))) {
                    comp[i] = id; changed = true;
                }
            }
        }
    };
    grow(info.from, 0);
    grow(info.to, 1);
    let gap = Infinity;
    let at = { x: info.from.x + (info.to.x - info.from.x) / 2, y: Math.max(info.from.y, info.to.y) + 0.412 };
    const seen = (i, j) => {
        for (const p of pts[i]) for (const q of pts[j]) {
            const d = Math.hypot(p.x - q.x, p.y - q.y);
            if (d < gap) { gap = d; at = { x: (p.x + q.x) / 2, y: (p.y + q.y) / 2 }; }
        }
    };
    const toC = { x: info.to.x + info.to.w / 2, y: info.to.y + info.to.h / 2 };
    const fromC = { x: info.from.x + info.from.w / 2, y: info.from.y + info.from.h / 2 };
    for (let i = 0; i < n; i++) {
        if (comp[i] === 0) {
            if (nearRect(i, info.to)) return { gap: 0, at };
            for (let j = 0; j < n; j++) if (comp[j] === 1) seen(i, j);
            for (const p of pts[i]) {
                const d = rectDist(p, info.to);
                if (d < gap) { gap = d; at = { x: (p.x + toC.x) / 2, y: (p.y + toC.y) / 2 }; }
            }
        } else if (comp[i] === 1) {
            // symmetric: a structure growing from the to-side also counts
            for (const p of pts[i]) {
                const d = rectDist(p, info.from);
                if (d < gap) { gap = d; at = { x: (p.x + fromC.x) / 2, y: (p.y + fromC.y) / 2 }; }
            }
        }
    }
    if (gap === Infinity) gap = Math.hypot(toC.x - fromC.x, toC.y - fromC.y);
    return { gap: Math.max(0, gap), at };
}

function mutate(parent, settled, info, rng, gapAt, budget) {
    // Repair rules keyed on what each card actually did during settle.
    const kids = [];
    const placed = parent.cards;
    const fell = [], slid = [];
    for (let i = 0; i < placed.length && i < settled.length; i++) {
        const dY = settled[i].y - placed[i].y;
        const dX = settled[i].x - placed[i].x;
        if (dY < -0.5) fell.push(i);
        else if (Math.abs(dX) > 0.12) slid.push({ i, dX });
    }
    const clone = () => placed.map((c) => ({ ...c }));
    if (fell.length) {
        const i = fell[0];
        const staticsUsed = placed.filter((c) => c.static).length;
        for (const fix of [
            (c) => { c[i].y -= 0.06; },                       // arrive earlier
            (c) => { c[i].x += rng() > 0.5 ? 0.05 : -0.05; }, // seek support
            (c) => c.splice(i, 1),                            // drop the card entirely
            // no support anywhere? a static doesn't need any (free anchor)
            ...(info.blocks.static > staticsUsed ? [(c) => { c[i].static = true; }] : []),
        ]) { const c = clone(); fix(c); if (c.length) kids.push({ cards: c }); }
    }
    for (const { i, dX } of slid.slice(0, 2)) {
        const c = clone();
        c[i].x -= dX / 2;                                     // pre-compensate the slide
        kids.push({ cards: c });
        const t = clone();
        t[i].angle = (t[i].angle || 0) + (dX > 0 ? 1 : -1) * Math.PI / 72; // tilt against it
        kids.push({ cards: t });
    }
    // grow toward the measured frontier: drop a plank right at the gap
    if (gapAt && placed.length < budget) {
        for (const ang of [0, Math.PI / 2]) {
            const c = clone();
            c.push({ x: gapAt.x, y: gapAt.y + 0.12, angle: ang, static: false });
            kids.push({ cards: c });
        }
    }
    // universal small perturbation as a fallback explorer
    const scale = parent.heat ? 0.09 : 0.03;
    const j = clone();
    for (const c of j) { c.x += (rng() * 2 - 1) * scale; c.y += (rng() * 2 - 1) * scale; }
    kids.push({ cards: j });
    return kids;
}

async function main() {
    const args = process.argv.slice(2);
    const get = (k) => { const i = args.indexOf(`--${k}`); return i >= 0 ? args[i + 1] : null; };
    const chapter = parseInt(get('chapter'), 10);
    const level = parseInt(get('level'), 10);
    const maxAttempts = parseInt(get('attempts'), 10) || 120;
    if (!chapter || !level) { console.error('usage: autosolve.js --chapter C --level L [--attempts N]'); process.exit(2); }

    const info = levels.levelInfo(chapter, level);
    let seed = 1234567;
    const rng = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;

    // Seed population: stratified across structure sizes, ALWAYS including
    // the largest designs (hint schedules sort to the tail).
    const all = generateCandidates(info, { rounds: 2 }).sort((a, b) => a.cards.length - b.cards.length);
    const strat = Math.max(1, Math.floor(all.length / 34));
    // hint schedules FIRST (guaranteed), then stratified sizes + largest
    const seeds = [...hintSeeds(info), ...all.filter((_, i) => i % strat === 0).slice(0, 34), ...all.slice(-8)];
    const seedFile = get('seed-file');
    if (seedFile) seeds.unshift({ cards: JSON.parse(require('fs').readFileSync(seedFile, 'utf8')) });

    const h = await createHarness({ profile: profiles.contextProfile(chapter, level) });
    const g = new Game(h);
    const seedQ = [...seeds];
    const kidQ = [];
    const tried = new Set();
    let best = null, attempts = 0, flip = false, lastImprove = 0;
    try {
        await g.gotoLevel(chapter);
        while ((seedQ.length || kidQ.length) && attempts < maxAttempts) {
            // alternate seeds and mutants so mutant dynasties can't starve
            // the untried seed designs
            flip = !flip;
            const cand = (flip && seedQ.length ? seedQ : kidQ.length ? kidQ : seedQ).shift();
            if (!cand) continue;
            const key = JSON.stringify(cand.cards.map((c) => [c.x.toFixed(3), c.y.toFixed(3), (c.angle || 0).toFixed(3), !!c.static]));
            if (tried.has(key)) continue;
            tried.add(key);
            attempts++;
            const r0 = await g.restartLevel();
            if (!r0.ok) break;
            let placedN = 0;
            const kept = [];
            for (const card of cand.cards) {
                const p = await g.place(card);
                if (p.ok) { placedN++; kept.push(card); }
            }
            if (!placedN) continue;
            const res = await g.apply(3600);
            if (res.outcome === 'won') {
                process.stderr.write(`attempt ${attempts}: WON ${res.stars}*\n`);
                const rec = await verifyAndRecord(chapter, level, kept, { video: true });
                console.log(JSON.stringify({ ok: rec.ok, attempts, stars: rec.ok ? rec.verified.stars : null, cards: kept }));
                return;
            }
            const settled = await g.cards();
            const norm = settled.map((c) => ({ x: c.x, y: c.y, angle: c.a ?? c.angle ?? 0 }));
            const { gap, at } = chainGap(norm, info);
            const budget = info.blocks.dynamic + info.blocks.static;
            const fit = -gap - kept.length * 0.001;
            if (!best || fit > best.fit) {
                best = { fit, gap, cards: kept, settled, at };
                lastImprove = attempts;
                process.stderr.write(`attempt ${attempts}: gap=${gap.toFixed(3)} (new best, ${kept.length} cards)\n`);
                // best parents breed more
                kidQ.unshift(...mutate({ cards: kept }, settled, info, rng, at, budget));
            } else if (gap < best.gap + 0.15 && kept.length >= 3) {
                kidQ.push(...mutate({ cards: kept }, settled, info, rng, at, budget).slice(0, 3));
            }
            if (((attempts - lastImprove > 40) || (!seedQ.length && !kidQ.length)) && best) {
                lastImprove = attempts; // stagnation/extinction kick: re-breed from best, hot
                kidQ.unshift(...mutate({ cards: best.cards, heat: true }, best.settled, info, rng, best.at, budget));
            }
        }
        console.log(JSON.stringify({ ok: false, attempts, bestGap: best ? best.gap : null, bestCards: best ? best.cards : null }));
        process.exit(1);
    } finally {
        await h.close();
    }
}

main().catch((e) => { console.error(e); process.exit(1); });

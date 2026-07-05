// Batch scenario runner: the "test thousands of scenarios fast" clause.
'use strict';
const fs = require('fs');
const profiles = require('./profiles');
const { createHarness } = require('./harness');
const { Game } = require('./game');

async function runScenarios(scenarios, { parallel = 4, onResult = null, stopWhen = null } = {}) {
    let stopped = false;
    // Group by level so each worker keeps one warm page per level. A shard
    // field lets callers split one level's scenarios across several workers.
    const groups = new Map();
    scenarios.forEach((s, index) => {
        const key = `${s.chapter}:${s.level}:${s.shard || 0}`;
        if (!groups.has(key)) groups.set(key, []);
        groups.get(key).push({ ...s, index });
    });
    const queue = [...groups.values()];
    const results = new Array(scenarios.length);

    async function worker() {
        while (queue.length && !stopped) {
            const group = queue.shift();
            const { chapter, level } = group[0];
            // Context matters: previous levels' settled cards are solid
            // bodies in the world, so search runs in the true progression
            // state (throws until the previous level is recorded).
            const h = await createHarness({ profile: profiles.contextProfile(chapter, level) });
            const g = new Game(h);
            try {
                await g.gotoLevel(chapter);
                for (const sc of group) {
                    if (stopped) break;
                    const r = await playScenario(g, sc);
                    results[sc.index] = r;
                    if (onResult) onResult(r);
                    if (stopWhen && stopWhen(r)) stopped = true;
                }
            } finally {
                await h.close();
            }
        }
    }

    async function playScenario(g, sc) {
        const base = { index: sc.index, chapter: sc.chapter, level: sc.level };
        const restart = await g.restartLevel();
        if (!restart.ok) return { ...base, outcome: 'error', error: 'restart failed' };
        let placed = 0;
        const rejected = [];
        for (const card of sc.cards) {
            const p = await g.place(card);
            if (p.ok) placed++; else rejected.push({ card, reason: p.reason });
        }
        if (placed === 0) return { ...base, outcome: 'error', error: 'no card placed', rejected };
        const r = await g.apply(sc.maxTicks || 3600);
        return { ...base, outcome: r.outcome, stars: r.stars, ticks: r.ticks, placed, ...(rejected.length ? { rejected } : {}) };
    }

    const n = Math.max(1, Math.min(parallel, queue.length));
    await Promise.all(Array.from({ length: n }, worker));
    return results;
}

async function cmdRun(args) {
    const file = args._[0];
    if (!file) throw new Error('run requires a scenarios JSON file');
    const scenarios = JSON.parse(fs.readFileSync(file, 'utf8'));
    const out = args.out ? fs.createWriteStream(args.out) : process.stdout;
    const started = Date.now();
    const results = await runScenarios(scenarios, {
        parallel: parseInt(args.parallel, 10) || 4,
        onResult: (r) => out.write(JSON.stringify(r) + '\n'),
    });
    const won = results.filter((r) => r && r.outcome === 'won').length;
    process.stderr.write(`ran ${results.length} scenarios in ${((Date.now() - started) / 1000).toFixed(1)}s, ${won} won\n`);
    if (args.out) out.end();
}

module.exports = { runScenarios, cmdRun };

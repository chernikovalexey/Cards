#!/usr/bin/env node
// CLI play API for Two Cubes. See docs/superpowers/specs/2026-07-03-cli-play-api-design.md
'use strict';
const readline = require('readline');
const levels = require('./lib/levels');
const profiles = require('./lib/profiles');
const { createHarness } = require('./lib/harness');
const { Game } = require('./lib/game');

function parseArgs(argv) {
    const args = { _: [] };
    for (let i = 0; i < argv.length; i++) {
        const a = argv[i];
        if (a.startsWith('--')) {
            const key = a.slice(2);
            const next = argv[i + 1];
            if (next !== undefined && !next.startsWith('--')) { args[key] = next; i++; }
            else args[key] = true;
        } else args._.push(a);
    }
    return args;
}

function cmdInfo(args) {
    const chapter = parseInt(args.chapter, 10);
    if (!chapter) throw new Error('info requires --chapter');
    if (args.level) {
        process.stdout.write(JSON.stringify(levels.levelInfo(chapter, parseInt(args.level, 10)), null, 2) + '\n');
    } else {
        const n = levels.loadChapter(chapter).levels.length;
        const all = Array.from({ length: n }, (_, i) => levels.levelInfo(chapter, i + 1));
        process.stdout.write(JSON.stringify(all, null, 2) + '\n');
    }
}

async function cmdPlay(args) {
    const chapter = args.chapter ? parseInt(args.chapter, 10) : null;
    const level = args.level ? parseInt(args.level, 10) : 1;
    // Sessions play in the true progression context unless --isolated.
    const profile = chapter
        ? (args.isolated ? levels.searchProfile(chapter, level) : profiles.contextProfile(chapter, level))
        : { seen_howto: 'true', runout_occured: 'true' };
    const h = await createHarness({
        turbo: !args['no-turbo'],
        headless: !args.headed,
        profile,
    });
    const g = new Game(h);
    let at = { chapter: null, level: null };
    if (chapter) at = await g.gotoLevel(chapter);
    process.stdout.write(JSON.stringify({ ready: true, ...at }) + '\n');

    const rl = readline.createInterface({ input: process.stdin });
    for await (const line of rl) {
        if (!line.trim()) continue;
        let out;
        try {
            const c = JSON.parse(line);
            switch (c.cmd) {
                case 'goto': out = await g.gotoLevel(c.chapter); break;
                case 'place': out = await g.place(c); break;
                case 'apply': out = await g.apply(c.maxTicks || 3600); break;
                case 'restart': out = await g.restartLevel(); break;
                case 'next': out = await g.nextLevel(); break;
                case 'state': out = await g.state(); break;
                case 'cards': out = { cards: await g.cards() }; break;
                case 'info': out = g.info(); break;
                case 'screenshot': await g.screenshot(c.path); out = { path: c.path }; break;
                case 'tick': await h.tick(c.n || 1); out = {}; break;
                case 'quit':
                    process.stdout.write(JSON.stringify({ ok: true, bye: true }) + '\n');
                    rl.close();
                    await h.close();
                    process.exit(0);
                default: throw new Error(`unknown cmd: ${c.cmd}`);
            }
            process.stdout.write(JSON.stringify({ ok: true, ...out }) + '\n');
        } catch (err) {
            process.stdout.write(JSON.stringify({ ok: false, error: String(err.message || err) }) + '\n');
        }
    }
    await h.close();
}

async function main() {
    const [cmd, ...rest] = process.argv.slice(2);
    const args = parseArgs(rest);
    switch (cmd) {
        case 'info': cmdInfo(args); break;
        case 'play': await cmdPlay(args); break;
        case 'run': await require('./lib/batch').cmdRun(args); break;
        case 'prove': await require('./lib/prove').cmdProve(args); break;
        default:
            process.stderr.write('usage: cli.js <info|play|run|prove> [--flags]\n');
            process.exit(2);
    }
}

main().catch((err) => { console.error(err); process.exit(1); });

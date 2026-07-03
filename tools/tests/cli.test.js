'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { spawn } = require('child_process');
const path = require('path');
const readline = require('readline');

const CLI = path.join(__dirname, '..', 'cli.js');

test('info prints level facts', () => {
    const { execFileSync } = require('child_process');
    const out = JSON.parse(execFileSync('node', [CLI, 'info', '--chapter', '1', '--level', '1']));
    assert.equal(out.name, 'Transgalactic Hustler');
    assert.equal(out.blocks.dynamic, 3);
});

test('play session wins level 1-1 over JSONL', { timeout: 240000 }, async () => {
    const child = spawn('node', [CLI, 'play', '--chapter', '1', '--level', '1'], { stdio: ['pipe', 'pipe', 'inherit'] });
    const rl = readline.createInterface({ input: child.stdout });
    const lines = [];
    const waiters = [];
    rl.on('line', (l) => {
        const msg = JSON.parse(l);
        if (waiters.length) waiters.shift()(msg); else lines.push(msg);
    });
    const next = () => lines.length
        ? Promise.resolve(lines.shift())
        : new Promise((r) => waiters.push(r));
    const send = (obj) => child.stdin.write(JSON.stringify(obj) + '\n');

    try {
        const ready = await next();
        assert.equal(ready.ready, true);
        assert.equal(ready.chapter, 1);

        send({ cmd: 'place', x: 1.6765, y: 1.0347, angle: 0 });
        const placed = await next();
        assert.equal(placed.ok, true, JSON.stringify(placed));

        send({ cmd: 'apply' });
        const applied = await next();
        assert.equal(applied.outcome, 'won', JSON.stringify(applied));
        assert.equal(applied.stars, 3);

        send({ cmd: 'quit' });
        const bye = await next();
        assert.equal(bye.ok, true);
        child.stdin.end();
        rl.close();
        await new Promise((r) => child.on('exit', r));
    } finally {
        child.kill();
    }
});

'use strict';
const test = require('node:test');
const assert = require('node:assert');
const L = require('../lib/levels');

test('levelInfo converts chapter 1 level 1 to world units', () => {
    const info = L.levelInfo(1, 1);
    assert.equal(info.name, 'Transgalactic Hustler');
    assert.deepEqual(info.blocks, { static: 0, dynamic: 3 });
    assert.deepEqual(info.stars, [1, 2]);
    // from cube: x=100px, y=50px, 35x35px
    assert.ok(Math.abs(info.from.x - 100 / 85) < 1e-9);
    assert.ok(Math.abs(info.from.y - 50 / 85) < 1e-9);
    assert.ok(Math.abs(info.from.w - 35 / 85) < 1e-9);
    assert.equal(info.gravity, -10); // default GameEngine.GRAVITY
    assert.equal(info.obstacles.length, 3);
});

test('cameraOffsets reproduces the settled camera for chapter 1 level 1', () => {
    const raw = L.loadChapter(1).levels[0]; // x:0 y:-10 w:1600 h:2000
    const { pxOffsetX, pxOffsetY } = L.cameraOffsets(raw, 800, 600);
    assert.equal(pxOffsetX, 0);
    // mTargetY clamps to by1/85 + H = -10/85 + 600/85; pxOffsetY = -mTargetY*85 = -(590)
    assert.ok(Math.abs(pxOffsetY - (-590)) < 1e-9);
});

test('worldToClient maps the from cube onto the canvas', () => {
    const raw = L.loadChapter(1).levels[0];
    const rect = { left: 100, top: 20, width: 800, height: 600 };
    const p = L.worldToClient(100 / 85, 50 / 85, raw, rect);
    assert.ok(Math.abs(p.clientX - (100 + 100)) < 1e-6);      // 100*85/85 px into canvas
    assert.ok(Math.abs(p.clientY - (20 + (-50 + 590))) < 1e-6); // -wy*85 - pxOffsetY
});

test('searchProfile seeds direct entry and chapter unlock', () => {
    const p = L.searchProfile(3, 5);
    assert.equal(p.last, JSON.stringify({ chapter: 3, level: 5 }));
    assert.ok(JSON.parse(p.stars).total >= 60); // chapter 3 needs 60 stars
    assert.equal(p.seen_howto, 'true');
});

'use strict';
const fs = require('fs');
const path = require('path');

const NSCALE = 85;
const CARD = { w: 45 / NSCALE, h: 2.5 / NSCALE };
const CUBE = 35 / NSCALE;
const REPO_ROOT = path.join(__dirname, '..', '..');

const chapterCache = new Map();

function loadChapter(chapter) {
    if (!chapterCache.has(chapter)) {
        const file = path.join(REPO_ROOT, 'web', 'levels', `chapter_${chapter}.json`);
        chapterCache.set(chapter, JSON.parse(fs.readFileSync(file, 'utf8')));
    }
    return chapterCache.get(chapter);
}

// SubLevel.dart creates cubes with createPolygonShape(x/85, y/85, CUBE, CUBE)
// where (x, y) is the lower-left corner and the body center is corner + w/2.
function cubeRect(raw) {
    return { x: raw.x / NSCALE, y: raw.y / NSCALE, w: CUBE, h: CUBE };
}

function levelInfo(chapter, level) {
    const raw = loadChapter(chapter).levels[level - 1];
    if (!raw) throw new Error(`no level ${chapter}-${level}`);
    // SubLevel.dart:79-82 — for level > 1 the from cube IS the previous
    // level's to cube; the JSON "from" of those levels (often {offset}) is
    // ignored by the engine.
    const fromRaw = level > 1 ? loadChapter(chapter).levels[level - 2].to : raw.from;
    return {
        chapter,
        level,
        name: raw.name,
        gravity: raw.gravity != null && raw.gravity !== 0 ? raw.gravity : -10,
        blocks: { static: raw.blocks[0], dynamic: raw.blocks[1] },
        stars: raw.stars,
        bounds: { x: raw.x, y: raw.y, width: raw.width, height: raw.height },
        from: cubeRect(fromRaw),
        to: cubeRect(raw.to),
        obstacles: raw.obstacles.map((o) => {
            const out = { type: o.type, dynamic: o.type === 5 || o.type === 6 };
            if (o.points) {
                out.points = o.points.map((p) => ({ x: p.x / NSCALE, y: p.y / NSCALE }));
            } else {
                out.x = o.x / NSCALE; out.y = o.y / NSCALE;
                out.w = o.width / NSCALE; out.h = o.height / NSCALE;
            }
            if (o.gravity != null) out.gravity = o.gravity;
            return out;
        }),
    };
}

// Replica of SubLevel.apply() + Camera.checkTarget() (Camera.dart:216-226) for
// a camera that is never panned or zoomed after entering the level.
function cameraOffsets(rawLevel, canvasW, canvasH) {
    const S = NSCALE;
    const W = canvasW / S;
    const H = canvasH / S;
    const bx1 = rawLevel.x, bx2 = rawLevel.x + rawLevel.width;
    const by1 = rawLevel.y, by2 = rawLevel.y + rawLevel.height;

    let mx = rawLevel.x / S;                       // apply(): mTargetX = x / scale
    if (mx <= bx1 / S) mx = bx1 / S;
    if (mx + W >= bx2 / S) mx = bx2 / S - W;

    let my = rawLevel.y / S;                       // apply(): mTargetY = y / scale
    if (my - H <= by1 / S) my = by1 / S + H;
    if (my >= by2 / S) my = by2 / S;

    return { pxOffsetX: mx * S, pxOffsetY: -my * S };
}

// Inverse of Input.onMouseMove (Input.dart:47-48):
//   mouseX = (clientX - canvasX)/85 + pxOffsetX/85
//   mouseY = -(clientY - canvasY)/85 - pxOffsetY/85
function worldToClient(wx, wy, rawLevel, canvasRect) {
    const { pxOffsetX, pxOffsetY } = cameraOffsets(rawLevel, canvasRect.width, canvasRect.height);
    return {
        clientX: canvasRect.left + wx * NSCALE - pxOffsetX,
        clientY: canvasRect.top + (-wy * NSCALE - pxOffsetY),
    };
}

// localStorage seed for search sessions: Level.preload() jumps straight to
// storage['last'].level when its chapter matches, and the chapters API
// computes unlocks from the 'stars' blob. Search-only — never use for proofs.
function searchProfile(chapter, level) {
    const starsNeeded = chapter === 3 ? 60 : chapter === 2 ? 30 : 0;
    const profile = {
        seen_howto: 'true',
        runout_occured: 'true',
        last: JSON.stringify({ chapter, level }),
    };
    if (starsNeeded > 0) {
        profile.stars = JSON.stringify({
            total: starsNeeded,
            chapters: [{ id: 1, s: Math.min(36, starsNeeded) },
                       { id: 2, s: Math.max(0, starsNeeded - 36) }],
        });
    }
    return profile;
}

module.exports = { NSCALE, CARD, CUBE, loadChapter, levelInfo, cameraOffsets, worldToClient, searchProfile };

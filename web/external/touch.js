// Touch support for phones/tablets, v4 — single-finger precision placement.
//
// The game becomes truly responsive: the #graphics canvas is resized to the
// real device viewport (1:1 CSS pixels; the engine derives all world math
// from Input.canvasWidth/Height, so it adapts), dialogs are scaled
// independently, and placement is pure gestures:
//   tap           opens a magnified placement preview at the tapped point
//                 with top/center/bottom handles; center is selected by default
//   drag handle   moves the ghost with that handle under the finger
//   drag elsewhere rotates the ghost around its center (2.5-degree steps)
//   tap selected handle commits the placement
//   1-finger drag pan the camera when no placement preview is open
//   2-finger pinch zooms the engine camera; no two-finger rotate mode
//   long press    pick up the placed block near the finger (fat hit bounds,
//                 via the compiled engine's TouchBridge) — keep dragging to
//                 move it, release to drop, or tap the trash button
//
// Synthetic events target the same listeners the compiled Dart engine
// (cards.dart.js) wires at boot. Loaded right before cards.dart.js so the
// canvas rect override below is installed before compiled main() runs.
// Design: docs/superpowers/specs/2026-07-05-touch-support-design.md
(function () {
    'use strict';

    var m = /[?&]touch=([01])/.exec(location.search);
    var forced = m ? m[1] : null;
    var enabled = forced === '1' || (forced !== '0' &&
        ((window.matchMedia && matchMedia('(pointer: coarse)').matches) ||
         'ontouchstart' in window));
    if (!enabled) return;

    document.documentElement.classList.add('touch-mode');

    var TOPBAR = 56;          // px reserved for the chrome bar (56 + notch)
    var STEP = Math.PI / 72;  // 2.5 degrees, the engine's Q/E step
    var MAGNET_STEPS = 6;     // preferred angles are 15 degrees apart
    var MAGNET_RADIUS = 1;    // attract only the adjacent 2.5-degree step
    var POSITION_MAGNET_PX = 18;
    var POSITION_GAP_PX = 4;
    var GRAB_PX = 30;         // selection pad around a block's own bounds

    // Notched phones: measure env(safe-area-inset-top) through a probe so
    // the chrome bar and the canvas both start below the cutout.
    var safeProbe = document.createElement('div');
    safeProbe.style.cssText = 'position:fixed;left:0;width:0;height:0;' +
        'visibility:hidden;pointer-events:none;' +
        'top:env(safe-area-inset-top,0px)';
    document.documentElement.appendChild(safeProbe);
    function safeTop() {
        var t = safeProbe.getBoundingClientRect().top;
        return t > 0 ? Math.round(t) : 0;
    }

    var state = {
        layout: { left: 0, top: TOPBAR, w: 800, h: 600 },  // canvas layout rect
        ghost: null,          // last ghost position in layout px {x, y}
        angleSteps: 0,        // tracked ghost angle in 2.5-degree steps
        mode: null,           // null | 'pan' | 'place' | 'pinch'
        placement: null,      // active precision placement state
    };

    function canvasEl() { return document.getElementById('graphics'); }

    // The engine reads BOTH pointer mapping and world dimensions from this
    // rect. It must always describe the *layout* box of the canvas and
    // must be a real DOMRect (dart2js interceptors reject plain objects).
    canvasEl().getBoundingClientRect = function () {
        var L = state.layout;
        return new DOMRect(L.left, L.top, L.w, L.h);
    };

    // ------------------------------------------------------------------
    // Responsive layout: device-sized canvas below the top bar, dialogs
    // scaled to fit independently (they keep their internal 800x600).
    function refit() {
        var vw = window.innerWidth, vh = window.innerHeight;
        var st = safeTop();
        TOPBAR = 56 + st;
        var c = canvasEl();
        var w = vw, h = Math.max(200, vh - TOPBAR);
        state.layout = { left: 0, top: TOPBAR, w: w, h: h };
        c.width = w;                       // attribute = world px, 1:1 CSS
        c.height = h;
        c.style.width = w + 'px';
        c.style.height = h + 'px';
        c.style.position = 'fixed';
        c.style.left = '0';
        c.style.top = TOPBAR + 'px';
        var root = document.documentElement.style;
        root.setProperty('--dlg-scale', Math.min(vw / 800, vh / 600));
        root.setProperty('--topbar', TOPBAR + 'px');
        root.setProperty('--safe-top', st + 'px');
        // Chapter cards keep their internal 240px design and are zoomed to
        // a comfortable finger size (cards.css: .touch-mode .chapter).
        root.setProperty('--chapter-zoom',
            Math.min(1.6, (Math.min(vw, 460) - 32) / 240));
        // Open scroll lists (chapters, level tape) re-measure after the
        // viewport changes, e.g. an orientation flip.
        if (window.dw_scrollObj && dw_scrollObj.refreshAll) {
            try { dw_scrollObj.refreshAll(); } catch (err) { /* not built yet */ }
        }
        // The engine re-reads the canvas rect on window resize
        // (updateCanvasPositionAndDimension); flag ours to avoid loops.
        var ev = new Event('resize');
        ev.__touchRefit = true;
        window.dispatchEvent(ev);
    }
    window.addEventListener('resize', function (e) {
        if (!e.__touchRefit) refit();
    });
    window.addEventListener('orientationchange', function () {
        setTimeout(refit, 100);
    });
    refit();

    // ------------------------------------------------------------------
    // Coordinate mapping. Screen px == canvas layout px == engine px
    // (that is the point of the responsive canvas).
    function toLayout(sx, sy) {
        var L = state.layout;
        return { x: sx - L.left, y: sy - L.top };
    }

    // ------------------------------------------------------------------
    // Synthetic events. clientX/Y are layout-based: the engine subtracts
    // the (overridden) rect origin.
    function mouse(type, q, button) {
        var L = state.layout;
        canvasEl().dispatchEvent(new MouseEvent(type, {
            bubbles: true, cancelable: true, view: window,
            clientX: L.left + q.x, clientY: L.top + q.y, button: button || 0,
        }));
    }
    function key(type, code) {
        window.dispatchEvent(new KeyboardEvent(type, {
            keyCode: code, which: code, bubbles: true,
        }));
    }
    var KEY = { space: 32, q: 81, e: 69, c: 67, v: 86 };

    function raf2(fn) {
        requestAnimationFrame(function () { requestAnimationFrame(fn); });
    }

    // The compiled build applies Q/E (and W/A/S/D) every engine frame while
    // the key is down; C/V/Enter/clicks are one-shot. The engine's rAF
    // chain was registered at boot, before ours, so within a frame our rAF
    // callbacks run after its update: dispatching keydown in one callback
    // and keyup N callbacks later yields exactly N frames with the key
    // down. All key work is serialized through this queue.
    var keyQueue = [], keyBusy = false;
    function enqueueKey(code, frames, after) {
        keyQueue.push({ code: code, frames: frames, after: after });
        if (!keyBusy) {
            keyBusy = true;
            drainKeys();
        }
    }
    function drainKeys() {
        var job = keyQueue.shift();
        if (!job) {
            keyBusy = false;
            return;
        }
        requestAnimationFrame(function () {
            key('keydown', job.code);
            var left = Math.max(1, job.frames);
            var tick = function () {
                requestAnimationFrame(function () {
                    if (--left > 0) {
                        tick();
                        return;
                    }
                    key('keyup', job.code);
                    if (job.after) job.after();
                    drainKeys();
                });
            };
            tick();
        });
    }
    function whenKeysIdle(fn) {
        if (!keyBusy) fn();
        else setTimeout(function () { whenKeysIdle(fn); }, 20);
    }

    function moveGhost(q) {
        state.ghost = { x: q.x, y: q.y };
        mouse('mousemove', q);
    }
    function parkGhost() {
        moveGhost({ x: -200, y: -200 });
    }

    // ------------------------------------------------------------------
    // Ghost rotation: absolute angle in 2.5-degree steps. Every gesture
    // starts from a C-snap (0), so the tracked step count is exact.
    function driveAngle(targetSteps) {
        // Rectangular cards are symmetric under 180 degrees.
        var t = ((targetSteps % 72) + 72) % 72;
        if (t >= 36) t -= 72;
        var delta = t - state.angleSteps;
        if (delta === 0) return;
        state.angleSteps = t;
        enqueueKey(delta > 0 ? KEY.q : KEY.e, Math.abs(delta));
    }
    function snapAngle() {
        state.angleSteps = 0;
        enqueueKey(KEY.c, 1);
    }

    // ------------------------------------------------------------------
    // Placement + feedback. The engine accepts or rejects silently; the
    // block counters are the only observable.
    function remaining() {
        var grab = function (sel) {
            var el = document.querySelector(sel);
            var mm = el && el.textContent.match(/\d+/);
            return mm ? parseInt(mm[0], 10) : null;
        };
        return { d: grab('.dynamic .remaining'), s: grab('.static .remaining') };
    }
    function physicsOn() {
        var el = document.getElementById('toggle-physics');
        return !!el && el.classList.contains('rewind');
    }
    function selectedStatic() {
        var cur = document.querySelector('.selector.current');
        return !!cur && cur.classList.contains('static');
    }
    function magneticPosition(q) {
        if (!window.TouchBridge || !TouchBridge.snapCardAt) return q;
        var snapped = TouchBridge.snapCardAt(
            q.x, q.y, state.angleSteps * STEP,
            POSITION_MAGNET_PX, POSITION_GAP_PX);
        return snapped ? { x: snapped.x, y: snapped.y } : q;
    }

    // q: layout point to place at. onDone(placed:boolean). Queued behind any
    // pending rotation key frames, so a precision rotation settles first.
    function placeAt(q, onDone) {
        if (physicsOn()) {
            rejectFeedback('Rewind first');
            if (onDone) onDone(false);
            return;
        }
        var rem = remaining();
        var left = selectedStatic() ? rem.s : rem.d;
        if (left === 0) {
            rejectFeedback('No blocks of this type left');
            if (onDone) onDone(false);
            return;
        }
        whenKeysIdle(function () {
            q = magneticPosition(q);
            moveGhost(q);
            raf2(function () {              // box2d refreshes ghost contacts
                var before = remaining();
                mouse('mousedown', q, 0);
                raf2(function () {
                    mouse('mouseup', q, 0);
                    raf2(function () {
                        var after = remaining();
                        var placed =
                            (before.d !== null && after.d === before.d - 1) ||
                            (before.s !== null && after.s === before.s - 1);
                        if (!placed) rejectFeedback('Too close — leave a small gap');
                        else parkGhost();
                        if (onDone) onDone(placed);
                    });
                });
            });
        });
    }

    // ------------------------------------------------------------------
    // Chrome: a single top bar (no placement buttons — placement is pure
    // gestures) + feedback overlays. Built only in touch mode.
    function el(tag, id, cls, html) {
        var e = document.createElement(tag);
        if (id) e.id = id;
        if (cls) e.className = cls;
        if (html) e.innerHTML = html;
        return e;
    }

    var top = el('div', 'touch-top');
    var pauseBtn = el('button', 'touch-pause', 'touch-btn', '⏸');
    var restartBtn = el('button', 'touch-restart', 'touch-btn', '↺');
    var hintBtn = el('button', 'touch-hint', 'touch-btn', '💡');
    var applyBtn = el('button', 'touch-apply', 'touch-btn touch-btn-primary', '⚡ Apply');
    var blocksWrap = el('div', 'touch-blocks');
    var dynamicBtn = el('button', 'touch-block-dynamic', 'touch-btn', '▦ Block');
    var staticBtn = el('button', 'touch-block-static', 'touch-btn', '▤ Wall');
    blocksWrap.appendChild(dynamicBtn);
    blocksWrap.appendChild(staticBtn);
    top.appendChild(pauseBtn);
    top.appendChild(restartBtn);
    top.appendChild(hintBtn);
    top.appendChild(applyBtn);

    var toast = el('div', 'touch-toast');
    var flash = el('div', 'touch-flash');
    var trash = el('button', 'touch-trash', 'touch-btn', '🗑');
    trash.style.display = 'none';

    var placeOverlay = el('div', 'touch-place');
    var placeHandles = {};
    ['top', 'center', 'bottom'].forEach(function (name) {
        var h = el('button', 'touch-point-' + name, 'touch-point');
        h.setAttribute('aria-label', name);
        h.dataset.point = name;
        placeHandles[name] = h;
        placeOverlay.appendChild(h);
    });

    function mountChrome() {
        document.body.appendChild(top);
        document.body.appendChild(blocksWrap);
        document.body.appendChild(toast);
        document.body.appendChild(flash);
        document.body.appendChild(trash);
        document.body.appendChild(placeOverlay);
    }
    if (document.body) mountChrome();
    else document.addEventListener('DOMContentLoaded', mountChrome);

    function proxy(btn, targetSel) {
        btn.addEventListener('touchstart', function (e) {
            e.preventDefault();
            e.stopPropagation();
            var t = document.querySelector(targetSel);
            if (t) t.click();
        }, { passive: false });
    }
    proxy(applyBtn, '#toggle-physics');
    proxy(restartBtn, '#restart');
    proxy(hintBtn, '#hint');
    // Pause = the engine's Esc. Opens the pause dialog (Resume / Restart /
    // Menu) — the only way off a level on a phone.
    pauseBtn.addEventListener('touchstart', function (e) {
        e.preventDefault();
        e.stopPropagation();
        enqueueKey(27, 3);
    }, { passive: false });
    function selectBlock(btn, selector) {
        btn.addEventListener('touchstart', function (e) {
            e.preventDefault();
            e.stopPropagation();
            var target = document.querySelector(selector);
            if (target && !target.hidden) target.click();
        }, { passive: false });
    }
    selectBlock(dynamicBtn, '.selector.dynamic');
    selectBlock(staticBtn, '.selector.static');

    var toastTimer = null;
    function rejectFeedback(msg) {
        flash.classList.add('on');
        setTimeout(function () { flash.classList.remove('on'); }, 450);
        toast.textContent = msg;
        toast.classList.add('on');
        clearTimeout(toastTimer);
        toastTimer = setTimeout(function () { toast.classList.remove('on'); }, 2200);
        if (navigator.vibrate) navigator.vibrate(50);
    }

    // ------------------------------------------------------------------
    // Camera pan = engine Space + left-drag. The camera consumes mousemove
    // deltas, so the anchor mousemove must land one frame before the left
    // mousedown or the jump from the previous ghost position pans wildly.
    var pan = null;   // {q, ready}
    function startPan(q) {
        pan = { q: q, ready: false };
        state.mode = 'pan';
        key('keydown', KEY.space);
        moveGhost(q);
        raf2(function () {
            if (!pan) return;
            mouse('mousedown', pan.q, 0);
            pan.ready = true;
        });
    }
    function movePan(q) {
        if (!pan) return;
        pan.q = q;
        if (pan.ready) moveGhost(q);
    }
    function endPan() {
        if (!pan) return;
        var p = pan;
        pan = null;
        state.mode = null;
        mouse('mouseup', p.q, 0);
        key('keyup', KEY.space);
        parkGhost();
    }

    // ------------------------------------------------------------------
    // Single-finger precision placement. A tap opens a magnified canvas
    // around the ghost and shows three selectable handles on the block.
    // Dragging the selected handle moves the block; dragging away from the
    // handles rotates it. Tapping the selected handle commits placement.
    var PZOOM = 3;
    var HANDLE_HIT_PX = 32;
    var CARD_HANDLE_PX = 34;
    var placeDrag = null; // {kind, point, startAngle}

    function magneticAngleSteps(angle) {
        var raw = Math.round(angle / STEP);
        var preferred = Math.round(raw / MAGNET_STEPS) * MAGNET_STEPS;
        // Keep every 2.5-degree angle available. Only the immediately
        // adjacent steps are pulled onto a preferred 15-degree angle.
        return Math.abs(raw - preferred) <= MAGNET_RADIUS ? preferred : raw;
    }
    function handleOffset(point) {
        if (point === 'center') return { x: 0, y: 0 };
        // Top/bottom sit on the ghost's local normal. This gives the player a
        // stable "finger attaches here" choice without changing card geometry.
        var sign = point === 'top' ? -1 : 1;
        var a = state.angleSteps * STEP;
        return {
            x: sign * -Math.sin(a) * CARD_HANDLE_PX,
            y: sign * -Math.cos(a) * CARD_HANDLE_PX,
        };
    }
    function transformedScreen(q) {
        var L = state.layout;
        var p = state.placement;
        if (!p) return { x: L.left + q.x, y: L.top + q.y };
        return {
            x: L.left + p.tx + PZOOM * q.x,
            y: L.top + p.ty + PZOOM * q.y,
        };
    }
    function handleScreen(point) {
        var p = state.placement;
        var o = handleOffset(point);
        return transformedScreen({ x: p.center.x + o.x, y: p.center.y + o.y });
    }
    function pointNearHandle(sx, sy) {
        if (!state.placement) return null;
        var best = null;
        var bestD = HANDLE_HIT_PX + 1;
        ['top', 'center', 'bottom'].forEach(function (name) {
            var h = handleScreen(name);
            var d = Math.hypot(sx - h.x, sy - h.y);
            if (d <= HANDLE_HIT_PX && d < bestD) {
                best = name;
                bestD = d;
            }
        });
        return best;
    }
    function layoutFromTransformed(sx, sy) {
        var L = state.layout;
        var p = state.placement;
        if (!p) return toLayout(sx, sy);
        return {
            x: (sx - L.left - p.tx) / PZOOM,
            y: (sy - L.top - p.ty) / PZOOM,
        };
    }
    function updateCanvasZoom() {
        var p = state.placement;
        if (!p) return;
        var L = state.layout;
        var targetX = window.innerWidth / 2;
        var targetY = TOPBAR + (window.innerHeight - TOPBAR) / 2;
        p.tx = targetX - L.left - PZOOM * p.center.x;
        p.ty = targetY - L.top - PZOOM * p.center.y;
        var c = canvasEl();
        c.style.transformOrigin = '0 0';
        c.style.transform = 'translate(' + p.tx + 'px,' + p.ty + 'px) scale(' + PZOOM + ')';
    }
    function updatePlaceOverlay() {
        var p = state.placement;
        if (!p) return;
        updateCanvasZoom();
        placeOverlay.classList.add('on');
        placeOverlay.style.setProperty('--touch-angle', (-state.angleSteps * STEP) + 'rad');
        ['top', 'center', 'bottom'].forEach(function (name) {
            var s = handleScreen(name);
            var h = placeHandles[name];
            h.style.left = s.x + 'px';
            h.style.top = s.y + 'px';
            h.classList.toggle('selected', p.selected === name);
        });
        moveGhost(p.center);
    }
    function beginPlacement(q) {
        if (physicsOn()) {
            rejectFeedback('Rewind first');
            return;
        }
        if (pan) endPan();
        hideTrash();
        state.mode = 'place';
        state.placement = {
            center: { x: q.x, y: q.y },
            selected: 'center',
            tx: 0,
            ty: 0,
        };
        moveGhost(q);
        updatePlaceOverlay();
    }
    function closePlacement() {
        state.placement = null;
        state.mode = null;
        placeOverlay.classList.remove('on');
        canvasEl().style.transform = '';
        parkGhost();
    }
    function commitPlacement() {
        var p = state.placement;
        if (!p) return;
        var q = { x: p.center.x, y: p.center.y };
        closePlacement();
        placeAt(q, null);
    }
    function movePlacementHandle(sx, sy) {
        var p = state.placement;
        if (!p) return;
        var q = layoutFromTransformed(sx, sy);
        var o = handleOffset(p.selected);
        p.center = { x: q.x - o.x, y: q.y - o.y };
        updatePlaceOverlay();
    }
    function rotatePlacement(sx, sy) {
        var p = state.placement;
        if (!p) return;
        var q = layoutFromTransformed(sx, sy);
        var angle = Math.atan2(-(q.y - p.center.y), q.x - p.center.x);
        driveAngle(magneticAngleSteps(angle));
        updatePlaceOverlay();
    }

    // ------------------------------------------------------------------
    // Long-press pickup: grab the placed block near the finger through the
    // engine bridge (fat, finger-friendly bounds). The block leaves the
    // board and becomes the ghost at its exact spot and angle; dragging
    // moves it, releasing drops it, the trash button deletes it.
    var grab = null;   // {home:{x,y}, fx, fy, moved}
    function grabAt(sx, sy) {
        if (physicsOn() || !window.TouchBridge) return false;
        var q = toLayout(sx, sy);
        var res = TouchBridge.grabCardAt(q.x, q.y, GRAB_PX);
        if (!res) return false;
        // match the selector to the grabbed block so the re-placement
        // draws from (and returns to) the right pool
        var sel = document.querySelector(
            res.isStatic ? '.selector.static' : '.selector.dynamic');
        if (sel && !sel.classList.contains('current')) sel.click();
        // keep the tracked rotation steps roughly in sync (rotation
        // gestures snap to 0 first, so this only aids consistency)
        var steps = ((Math.round(res.angle / STEP) % 72) + 72) % 72;
        state.angleSteps = steps >= 36 ? steps - 72 : steps;
        moveGhost({ x: res.x, y: res.y });
        grab = { home: { x: res.x, y: res.y }, fx: sx, fy: sy, moved: false };
        var L = state.layout;
        showTrash(L.left + res.x, L.top + res.y);
        if (navigator.vibrate) navigator.vibrate(30);
        return true;
    }
    function endGrab(drop) {
        if (!grab) return;
        var g = grab;
        grab = null;
        if (drop && g.moved) {
            hideTrash();
            placeAt({ x: state.ghost.x, y: state.ghost.y }, null);
        } else {
            // not moved (or cancelled): put the block back where it was;
            // the trash button stays armed on that spot for deleting
            placeAt(g.home, null);
        }
    }

    // ------------------------------------------------------------------
    // Gesture recognition on the canvas.
    var touch0 = null;        // {x, y, t, moved} current single touch
    var longPress = null;     // timer for the pickup gesture
    var TAP_MS = 300, DRAG_PX = 10, LONG_MS = 550;
    var pinch = null;         // {distance, bucket}

    function cancelTapTracking() {
        clearTimeout(longPress);
        longPress = null;
        touch0 = null;
    }

    canvasEl().addEventListener('touchstart', function (e) {
        e.preventDefault();
        if (grab) return;         // one block in hand: ignore extra fingers
        hideTrash();
        if (e.touches.length === 1) {
            var t = e.touches[0];
            touch0 = { x: t.clientX, y: t.clientY, t: Date.now(), moved: false };
            clearTimeout(longPress);
            if (state.placement) {
                var hit = pointNearHandle(t.clientX, t.clientY);
                placeDrag = {
                    kind: hit ? 'handle' : 'rotate',
                    point: hit || state.placement.selected,
                };
                updatePlaceOverlay();
            } else {
                longPress = setTimeout(function () {
                    if (touch0 && !touch0.moved) {
                        var sx = touch0.x, sy = touch0.y;
                        touch0 = null;      // consume: no tap on release
                        grabAt(sx, sy);
                    }
                }, LONG_MS);
            }
        } else if (e.touches.length === 2) {
            cancelTapTracking();
            if (pan) endPan();
            closePlacement();
            startPinch(e.touches[0], e.touches[1]);
        }
    }, { passive: false });

    canvasEl().addEventListener('touchmove', function (e) {
        e.preventDefault();
        if (grab && e.touches.length === 1) {
            var f = e.touches[0];
            if (!grab.moved &&
                Math.hypot(f.clientX - grab.fx, f.clientY - grab.fy) > DRAG_PX) {
                grab.moved = true;
                hideTrash();
            }
            if (grab.moved) {
                moveGhost({
                    x: grab.home.x + (f.clientX - grab.fx),
                    y: grab.home.y + (f.clientY - grab.fy),
                });
            }
            return;
        }
        if (pinch && e.touches.length >= 2) {
            updatePinch(e.touches[0], e.touches[1]);
            return;
        }
        if (e.touches.length !== 1) return;
        var t = e.touches[0];
        if (state.placement) {
            if (touch0 && !touch0.moved &&
                Math.hypot(t.clientX - touch0.x, t.clientY - touch0.y) > DRAG_PX) {
                touch0.moved = true;
                clearTimeout(longPress);
            }
            if (!touch0 || !touch0.moved) return;
            if (placeDrag && placeDrag.kind === 'handle') {
                state.placement.selected = placeDrag.point;
                movePlacementHandle(t.clientX, t.clientY);
            } else {
                rotatePlacement(t.clientX, t.clientY);
            }
            return;
        }
        if (touch0 && !touch0.moved &&
            Math.hypot(t.clientX - touch0.x, t.clientY - touch0.y) > DRAG_PX) {
            touch0.moved = true;
            clearTimeout(longPress);
            startPan(toLayout(t.clientX, t.clientY));
        }
        if (!touch0 || !touch0.moved) return;
        if (pan) {
            movePan(toLayout(t.clientX, t.clientY));
        }
    }, { passive: false });

    canvasEl().addEventListener('touchend', function (e) {
        e.preventDefault();
        if (grab && e.touches.length === 0) {
            endGrab(true);
            return;
        }
        if (pinch && e.touches.length < 2) {
            endPinch();
            return;
        }
        if (pan && e.touches.length === 0) {
            endPan();
            touch0 = null;
            return;
        }
        if (!touch0 || Date.now() - touch0.t >= TAP_MS) {
            touch0 = null;
            placeDrag = null;
            return;
        }
        var sx = touch0.x, sy = touch0.y;
        var moved = touch0.moved;
        touch0 = null;
        clearTimeout(longPress);
        if (state.placement) {
            var hit = pointNearHandle(sx, sy);
            if (hit) {
                if (hit === state.placement.selected && !moved) commitPlacement();
                else {
                    state.placement.selected = hit;
                    updatePlaceOverlay();
                }
            } else if (!moved) {
                rotatePlacement(sx, sy);
            }
            placeDrag = null;
            return;
        }
        if (moved) return;
        // Tutorial tooltips/hint cards dismiss on a body click.
        canvasEl().dispatchEvent(new MouseEvent('click', {
            bubbles: true, clientX: sx, clientY: sy,
        }));
        beginPlacement(toLayout(sx, sy));
    }, { passive: false });

    canvasEl().addEventListener('touchcancel', function () {
        touch0 = null;
        placeDrag = null;
        clearTimeout(longPress);
        if (grab) endGrab(false);   // put the block back where it was
        if (pan) endPan();
        if (pinch) endPinch();
    });

    function pinchDistance(t0, t1) {
        return Math.hypot(t1.clientX - t0.clientX, t1.clientY - t0.clientY);
    }
    function startPinch(t0, t1) {
        state.mode = 'pinch';
        pinch = { distance: pinchDistance(t0, t1), bucket: 0 };
    }
    function updatePinch(t0, t1) {
        if (!pinch) return;
        var d = pinchDistance(t0, t1);
        if (!d || !pinch.distance) return;
        var bucket = Math.round(Math.log(d / pinch.distance) / Math.log(1.15));
        while (pinch.bucket < bucket) {
            var zi = document.getElementById('zoom-in');
            if (zi) zi.click();
            pinch.bucket++;
        }
        while (pinch.bucket > bucket) {
            var zo = document.getElementById('zoom-out');
            if (zo) zo.click();
            pinch.bucket--;
        }
    }
    function endPinch() {
        pinch = null;
        state.mode = null;
        parkGhost();
    }

    // ------------------------------------------------------------------
    // Delete: the trash button appears next to a picked-up block; tapping
    // it grabs the block back off the board (fat bounds, single block)
    // and parks the ghost — the block returns to its pool.
    var trashPoint = null;
    function showTrash(sx, sy) {
        trashPoint = { x: sx, y: sy };
        trash.style.left = Math.min(window.innerWidth - 64, sx + 28) + 'px';
        trash.style.top = Math.max(TOPBAR + 4, sy - 72) + 'px';
        trash.style.display = 'block';
        if (navigator.vibrate) navigator.vibrate(20);
    }
    function hideTrash() {
        trash.style.display = 'none';
        trashPoint = null;
    }
    trash.addEventListener('touchstart', function (e) {
        e.preventDefault();
        e.stopPropagation();
        if (!trashPoint || !window.TouchBridge) return;
        var q = toLayout(trashPoint.x, trashPoint.y);
        if (TouchBridge.grabCardAt(q.x, q.y, GRAB_PX)) parkGhost();
        hideTrash();
    }, { passive: false });

    // ------------------------------------------------------------------
    // Chrome state: poll cheap DOM signals (no engine hook exists).
    function dialogUp() {
        var boxes = document.querySelectorAll('.light-box');
        for (var i = 0; i < boxes.length; i++) {
            if (!boxes[i].classList.contains('hidden')) return true;
        }
        var prompts = document.querySelectorAll('.prompt-window');
        for (var k = 0; k < prompts.length; k++) {
            if (!prompts[k].closest('.templates')) return true;
        }
        var screens = document.querySelectorAll('.bs-screen');
        for (var j = 0; j < screens.length; j++) {
            var r = screens[j].getBoundingClientRect();
            if (r.height > 0 && r.top < window.innerHeight / 2) return true;
        }
        return false;
    }
    // Engine tooltips (GameWizard) anchor to the hidden desktop buttons.
    // Park those buttons under their touch counterparts so the tooltips
    // point at real chrome. visibility:hidden inherits from .buttons, so
    // the desktop nodes stay invisible; only their geometry moves.
    function mirrorButtons() {
        var map = [
            ['#toggle-physics', applyBtn],
            ['#restart', restartBtn],
            ['#hint', hintBtn],
            ['.selector.dynamic', dynamicBtn],
            ['.selector.static', staticBtn],
        ];
        for (var i = 0; i < map.length; i++) {
            var d = document.querySelector(map[i][0]);
            if (!d) continue;
            var r = map[i][1].getBoundingClientRect();
            if (!r.width) continue;
            d.style.position = 'fixed';
            d.style.left = r.left + 'px';
            d.style.top = r.top + 'px';
            d.style.width = r.width + 'px';
            d.style.height = r.height + 'px';
            d.style.margin = '0';
            d.style.boxSizing = 'border-box';
        }
    }

    var wasInLevel = false;
    setInterval(function () {
        // Closed bs-screens park at top:800px — inside a phone viewport,
        // where their (transparent) topbar would swallow taps. Tag open
        // ones; CSS keeps the rest visibility:hidden.
        var screens = document.querySelectorAll('.bs-screen');
        for (var i = 0; i < screens.length; i++) {
            screens[i].classList.toggle('bs-open',
                screens[i].getBoundingClientRect().top < 400);
        }
        var buttons = document.querySelector('.buttons');
        var inLevel = !!buttons && !buttons.classList.contains('hidden');
        var dlg = dialogUp();
        var showChrome = inLevel && !dlg;
        top.style.display = showChrome ? 'flex' : 'none';
        blocksWrap.style.display = showChrome ? 'flex' : 'none';
        if (showChrome) mirrorButtons();
        applyBtn.innerHTML = physicsOn() ? '⏪ Rewind' : '⚡ Apply';
        var rem = remaining();
        dynamicBtn.innerHTML = '▦ Block ' + (rem.d === null ? '' : rem.d);
        staticBtn.innerHTML = '▤ Wall ' + (rem.s === null ? '' : rem.s);
        dynamicBtn.classList.toggle('selected', !selectedStatic());
        staticBtn.classList.toggle('selected', selectedStatic());
        if (!inLevel || dlg) {
            hideTrash();
        }
        if (inLevel && !wasInLevel) {
            state.angleSteps = 0;   // fresh level: ghost angle is 0
            parkGhost();
        }
        wasInLevel = inLevel;
    }, 200);

    // ------------------------------------------------------------------
    // The in-game hints read window.locale at show time; reword the
    // mouse/keyboard ones for fingers. The locale file loads async
    // (features.js $.getScript), so poll until it lands.
    var localeTimer = setInterval(function () {
        var loc = window.locale;
        if (!loc || !loc.wizard_place) return;
        clearInterval(localeTimer);
        loc.wizard_place = 'Tap to aim, then tap the highlighted point to place';
        loc.wizard_rotate = '<b>To rotate the block,</b> drag away from its placement points';
        loc.wizard_remove = '<b>Press and hold a block</b> to pick it up — drag to move it, or tap the trash to remove it';
        loc.wizard_zoom = '<b>Pinch with two fingers</b> to zoom the camera';
        loc.click_to_unlock = 'Tap to unlock';
    }, 100);

    window.__touch = {
        TOPBAR: TOPBAR, GRAB_PX: GRAB_PX, state: state,
        toLayout: toLayout, moveGhost: moveGhost, placeAt: placeAt,
        magneticAngleSteps: magneticAngleSteps, magneticPosition: magneticPosition,
    };
})();

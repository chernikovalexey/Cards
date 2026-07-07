// Touch support for phones/tablets, v3 — gesture-first UX.
//
// The game becomes truly responsive: the #graphics canvas is resized to the
// real device viewport (1:1 CSS pixels; the engine derives all world math
// from Input.canvasWidth/Height, so it adapts), dialogs are scaled
// independently, and placement is pure gestures:
//   tap           place a block at the tapped point (immediately — there is
//                 no double-tap gesture anymore)
//   1-finger drag pan the camera (engine Space+left-drag)
//   2 fingers     rotate the ghost: an animated dotted line is drawn between
//                 the fingers and the block aligns to it (2.5-degree steps);
//                 lifting the fingers places the block at the line midpoint
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

    var TOPBAR = 56;          // px reserved for the chrome bar
    var STEP = Math.PI / 72;  // 2.5 degrees, the engine's Q/E step
    var GRAB_PX = 30;         // selection pad around a block's own bounds

    var state = {
        layout: { left: 0, top: TOPBAR, w: 800, h: 600 },  // canvas layout rect
        ghost: null,          // last ghost position in layout px {x, y}
        angleSteps: 0,        // tracked ghost angle in 2.5-degree steps
        mode: null,           // null | 'pan' | 'rotate'
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
        document.documentElement.style.setProperty(
            '--dlg-scale', Math.min(vw / 800, vh / 600));
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

    // q: layout point to place at. onDone(placed:boolean). Queued behind any
    // pending rotation key frames, so a rotate gesture settles first.
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
    var applyBtn = el('button', 'touch-apply', 'touch-btn', '⚡ Apply');
    var restartBtn = el('button', 'touch-restart', 'touch-btn', '↺');
    var blocksBtn = el('button', 'touch-blocks', 'touch-btn', '▦');
    var hintBtn = el('button', 'touch-hint', 'touch-btn', '💡');
    top.appendChild(applyBtn);
    top.appendChild(restartBtn);
    top.appendChild(blocksBtn);
    top.appendChild(hintBtn);

    var toast = el('div', 'touch-toast');
    var flash = el('div', 'touch-flash');
    var trash = el('button', 'touch-trash', 'touch-btn', '🗑');
    trash.style.display = 'none';

    var rotSvg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    rotSvg.id = 'touch-rotline';
    var rotLine = document.createElementNS('http://www.w3.org/2000/svg', 'line');
    rotLine.setAttribute('stroke-dasharray', '10 8');
    rotSvg.appendChild(rotLine);

    function mountChrome() {
        document.body.appendChild(top);
        document.body.appendChild(toast);
        document.body.appendChild(flash);
        document.body.appendChild(trash);
        document.body.appendChild(rotSvg);
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
    blocksBtn.addEventListener('touchstart', function (e) {
        e.preventDefault();
        e.stopPropagation();
        var other = selectedStatic()
            ? document.querySelector('.selector.dynamic')
            : document.querySelector('.selector.static');
        if (other && !other.hidden) other.click();
    }, { passive: false });

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
    // Two-finger rotation with the animated dotted line. Lifting the
    // fingers places the block right there — no extra tap needed.
    var rot = null;   // {midQ}
    function rotAngleSteps(t0, t1) {
        // screen y grows downward; world angle grows counter-clockwise
        var a = Math.atan2(-(t1.clientY - t0.clientY), t1.clientX - t0.clientX);
        return Math.round(a / STEP);
    }
    function startRotate(t0, t1) {
        cancelTapTracking();
        if (pan) endPan();
        state.mode = 'rotate';
        rot = {};
        snapAngle();
        updateRotate(t0, t1);
        rotSvg.classList.add('on');
    }
    function updateRotate(t0, t1) {
        if (!rot) return;
        rotLine.setAttribute('x1', t0.clientX);
        rotLine.setAttribute('y1', t0.clientY);
        rotLine.setAttribute('x2', t1.clientX);
        rotLine.setAttribute('y2', t1.clientY);
        driveAngle(rotAngleSteps(t0, t1));
        // the block rides the line: keep it at the midpoint
        var mid = toLayout(
            (t0.clientX + t1.clientX) / 2, (t0.clientY + t1.clientY) / 2);
        moveGhost(mid);
        rot.midQ = mid;
    }
    // place=true (fingers lifted): put the block at the line midpoint, after
    // the queued rotation key frames settle (placeAt is whenKeysIdle-gated).
    function endRotate(place) {
        var q = rot && rot.midQ;
        rot = null;
        state.mode = null;
        rotSvg.classList.remove('on');
        if (place && q) placeAt(q, null);
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
            longPress = setTimeout(function () {
                if (touch0 && !touch0.moved) {
                    var sx = touch0.x, sy = touch0.y;
                    touch0 = null;      // consume: no tap on release
                    grabAt(sx, sy);
                }
            }, LONG_MS);
        } else if (e.touches.length === 2) {
            startRotate(e.touches[0], e.touches[1]);
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
        if (rot && e.touches.length >= 2) {
            updateRotate(e.touches[0], e.touches[1]);
            return;
        }
        if (e.touches.length !== 1) return;
        var t = e.touches[0];
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
        if (rot && e.touches.length < 2) {
            endRotate(true);
            return;
        }
        if (pan && e.touches.length === 0) {
            endPan();
            touch0 = null;
            return;
        }
        if (!touch0 || touch0.moved || Date.now() - touch0.t >= TAP_MS) {
            touch0 = null;
            return;
        }
        var sx = touch0.x, sy = touch0.y;
        touch0 = null;
        clearTimeout(longPress);
        // Tutorial tooltips/hint cards dismiss on a body click.
        canvasEl().dispatchEvent(new MouseEvent('click', {
            bubbles: true, clientX: sx, clientY: sy,
        }));
        placeAt(toLayout(sx, sy), null);   // tap places immediately
    }, { passive: false });

    canvasEl().addEventListener('touchcancel', function () {
        touch0 = null;
        clearTimeout(longPress);
        if (grab) endGrab(false);   // put the block back where it was
        if (pan) endPan();
        if (rot) endRotate(false);
    });

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
        top.style.display = inLevel && !dlg ? 'flex' : 'none';
        applyBtn.innerHTML = physicsOn() ? '⏪ Rewind' : '⚡ Apply';
        var rem = remaining();
        blocksBtn.innerHTML = selectedStatic()
            ? ('▤ ' + (rem.s === null ? '' : rem.s))
            : ('▦ ' + (rem.d === null ? '' : rem.d));
        if (!inLevel || dlg) {
            hideTrash();
        }
        if (inLevel && !wasInLevel) {
            state.angleSteps = 0;   // fresh level: ghost angle is 0
            parkGhost();
        }
        wasInLevel = inLevel;
    }, 200);

    window.__touch = {
        TOPBAR: TOPBAR, GRAB_PX: GRAB_PX, state: state,
        toLayout: toLayout, moveGhost: moveGhost, placeAt: placeAt,
    };
})();

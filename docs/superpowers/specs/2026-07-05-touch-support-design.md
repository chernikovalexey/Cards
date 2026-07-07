# Touch support — full playability on smartphones

**Date:** 2026-07-05
**Status:** approved (decisions final per project owner); investigation findings folded in
**Goal:** precision parity — a phone player can 3-star every level (1 px nudge / 2.5° rotate,
same as desktop keyboard). Both orientations; full flow menu → level → win → next.

## Constraints

- `cards.dart.js` cannot be rebuilt. All changes live in `web/external/`, `web/cards.html`,
  `web/cards.css`. New JS is loaded via the retrying loader in `cards.html`.
- Desktop behavior unchanged: `npm test` (chromium + firefox parity suite) stays green.
  Touch UI activates only under touch detection (see §2).
- No game file is modified by the machine-play harness; `tools/` continues to work.

## 1. How the compiled engine consumes input (verified)

- `main()` (cards.dart:48) wires: `mousemove/mousedown/wheel/contextmenu` on `#graphics`,
  `mouseup/keydown/keyup` on `window`, `resize` → `updateCanvasPositionAndDimension()`.
- `updateCanvasPositionAndDimension` (cards.dart:308) reads
  `canvas.getBoundingClientRect()` into `Input.canvasX/Y/Width/Height`. Those feed **both**
  the mouse→world mapping (`Input.onMouseMove`: `mouseX = (clientX − canvasX)/scale + camX`)
  **and the world dimensions** (`GameEngine.WIDTH = canvasWidth/scale`, used by camera
  bounds, zoom centering, viewport transform). CSS-shrinking the canvas therefore corrupts
  camera math, not just pointer coords.
- `Input.onMouseDown/Up` read `event.which` (1 = left, 3 = right). `Input.toggle` reads
  `event.keyCode`. dart2js reads both as **native properties on the event instance**.
- One-shot semantics: `Input.update()` runs at the end of every engine frame and clears
  `*.clicked`, `isMouseLeftClicked`, `isMouseRightClicked`, `mouseMoved`, `wheelDirection`.
  `*.down` persists until keyup. Consequences:
  - **Caveat found at runtime:** the compiled build is older than the Dart sources.
    `cards.dart.js` rotates **every frame while Q/E is `.down`** (`q.get$down()`,
    cards.dart.js:1312-1315), not once per keydown as BoundedCard.dart:45-48 suggests.
    C/V snap and Enter/left-click place *are* one-shot (`clicked`). A precise 2.5°
    rotate therefore requires the keydown→keyup pair to straddle **exactly one** engine
    frame. touch.js exploits rAF ordering: the engine's rAF chain was registered at
    boot before any touch.js callback, so within a frame touch.js callbacks run after
    the engine's update — dispatching keydown in one rAF callback and keyup in the next
    yields exactly one engine frame with the key down. Presses are serialized through
    a queue so consecutive taps can't overlap.
  - W/A/S/D nudge moves **1 px per engine frame while `.down`** (same per-frame
    semantics) — a synthesized tap would move 0–2 px depending on frame phase. Not
    precise enough; the nudge pad uses virtual-cursor mousemove instead (§4).
- Ghost card: follows `mousemove` only when `Input.mouseMoved` (else keeps its position —
  "parking" is free). Placement (`canPut`, GameEngine.dart:253) requires
  `!z.down && !alt && !space.down && (leftClick || enter.clicked) && contacts.isEmpty
  && !physicsEnabled`; rejection is silent. Placement uses the **ghost body position**,
  not the click point. Right-click / Delete removes every placed card currently
  overlapping the ghost sensor (GameEngine.dart:508) — the ghost must be moved onto the
  card first, and box2d needs ≥1 `world.step` (≥1 frame) to refresh sensor contacts.
- Pan: `space.down && isMouseLeftDown` consumes mousemove deltas (Camera.dart:152-177).
  While space is down the ghost is hidden and `canPut` is false.
- Zoom: `#zoom-in`/`#zoom-out` button clicks, ±0.2 in [1, 3], animated 75 frames,
  re-centers between the two cubes.
- Physics state: `#toggle-physics` carries class `rewind` **iff physics is currently
  applied**. While applied, the ghost is transparent and placement is blocked; class
  removal (rewind started) restores.
- Placement/deletion result is observable via `.dynamic/.static .remaining` counters
  (updated synchronously by `updateBlockButtons`, works while CSS-hidden).

### Runtime facts verified in touch Chromium (probe, 2026-07-05)

- `new MouseEvent('mousedown', {button: 2})`.which === 3, `{button: 0}` → 1. No
  `defineProperty` needed for mouse.
- `new KeyboardEvent('keydown', {keyCode: 81})`.keyCode === 81 — Chromium honors the
  legacy init field (the machine-play harness already relies on this).
- A per-instance `canvas.getBoundingClientRect` override **is** read by the compiled
  handlers, but it must return a real `DOMRect` — a plain object throws
  `t1.get$left is not a function` inside dart2js interceptors.
- Without a viewport meta, mobile Chrome lays the page out at 980 px; `(pointer: coarse)`
  matches and `ontouchstart` exists in a Playwright `hasTouch` context.
- scrollbar.js (dw_scrollObj, 2012) has a built-in touch path: when
  `'ontouchend' in document` it binds `touchstart`/`touchmove` drag on the content layer —
  chapter list / level tape scrolling works without new code (pinned by test).

## 2. Activation

`web/external/touch.js`, loaded by the retrying loader **immediately before
`cards.dart.js`** (it must install the rect override before compiled `main()` runs).

```
enabled = qs.touch === '1' || (qs.touch !== '0' &&
          (matchMedia('(pointer: coarse)').matches || 'ontouchstart' in window))
```

When disabled it returns without side effects (desktop stays byte-identical in behavior).
When enabled it adds class `touch-mode` to `<html>`; all touch CSS is gated on
`.touch-mode` (not bare media queries) so desktop test browsers can never match it.

`cards.html` `<head>` gains
`<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no, viewport-fit=cover">`.
This is safe for desktop (no-op) and required for real phones.

## 3. Scaling & letterbox

- The **whole `.game-box`** (canvas + top buttons + every light-box dialog + templates’
  render targets) is scaled uniformly: `transform: translate(tx, ty) scale(s)`,
  `transform-origin: 0 0`, with `.touch-mode .game-box { left: 0; margin-left: 0; }`.
  `s = min(vw/800, vh/600)` in landscape (centered); in portrait `s = vw/800` and the
  box is pinned to the top, leaving the lower band for thumb clusters.
  One mechanism scales **all** dialogs (menu, chapter list, rating/win, pause, wizard,
  how-to, prompts) — no per-dialog audit debt.
- Refit on `resize` + `orientationchange`; after refitting, touch.js dispatches a
  synthetic `window` resize so the compiled engine re-reads the canvas rect.
- **Canvas rect override:** `#graphics.getBoundingClientRect` is replaced (instance-level,
  touch mode only) to return `new DOMRect(realLeft, realTop, 800, 600)` where
  `realLeft/Top` come from the untampered prototype call. The engine keeps 800×600 world
  math; only touch.js knows the CSS scale.
- **Coordinate mapping:** every synthesized mouse event uses *virtual client* coords:
  `vx = realLeft + (touchX − realLeft) · (800 / cssW)`, `vy` likewise with `600 / cssH`.
- `.selectors` top is set inline by the engine from the fake rect; `.touch-mode` CSS
  overrides it with `!important` (they are CSS-hidden on touch anyway, nodes kept).
- Elements outside `.game-box` (`.loading-overlay`, `.share-offer`) get `.touch-mode`
  rules to fit the viewport.

## 4. Interaction model (touch → synthetic events)

All synthesized events target `#graphics` (mouse) or `window` (keyboard), matching the
engine’s listeners. The "delayed release" pattern `press(type)` = dispatch down-event,
then the matching up-event after **two rAFs** (guarantees ≥1 engine frame sees the state).

| Gesture / control | Synthesis |
|---|---|
| 1-finger drag on canvas | `mousemove` at virtual coords, ghost floats above finger (§5) |
| Lift finger | nothing — ghost parks where it was (uncommitted) |
| ✓ commit | `mousedown {button:0}` + delayed `mouseup` (left click place) |
| ✕ park | `mousemove` to off-world point (100 px left of canvas) — ghost leaves the scene |
| Nudge pad ▲▼◀▶ | **virtual-cursor `mousemove`**, ±1 px per tap in virtual client space; hold repeats every 50 ms (see deviation note) |
| ⟲ / ⟳ | `keydown Q` / `keydown E` (+delayed keyup) — exactly 2.5° per pulse; hold repeats pulses |
| — / \| snap | `keydown C` / `keydown V` (+delayed keyup) |
| 2-finger drag | `keydown Space` (held) + `mousedown left` + `mousemove` stream at centroid; on release `mouseup` + `keyup Space` |
| Pinch | every ±15 % distance ratio → `#zoom-in` / `#zoom-out` `.click()` |
| Quick tap (<10 px, <300 ms) | dispatch a bubbling `click` (clears tutorial tooltips/hint cards exactly like a desktop body click) and offer delete (§6) |
| Apply / Restart / Blocks / Hint (top bar) | proxy `.click()` to `#toggle-physics` / `#restart` / `.selector` / `#hint` |

**Deviation from the brief (WASD → mousemove nudge):** the brief mapped the nudge pad to
WASD. WASD moves 1 px *per engine frame while held*, so a synthesized tap yields 0–2 px
depending on frame phase — it cannot deliver the "exactly 1 px per tap" precision the
goal requires. The nudge pad instead moves a **virtual cursor** by exactly ±1 px in
virtual client space and dispatches `mousemove` — deterministic 1 px steps, identical
user-visible semantics, and holding repeats like key auto-repeat. The virtual cursor is
the last position sent to the engine (finger drags update it), so nudges always refine
the current ghost position.

## 5. Placement flow (park → refine → commit)

- While dragging, the ghost floats **above** the finger:
  `ghostScreenY = fingerY − lift`, `lift = clamp(0.35 · (fingerY − canvasTopScreen), 12, 70)`
  (shrinks near the canvas top so high targets stay reachable). X is unshifted.
- Lift = park. Refine with nudge/rotate/snap. ✓ commits, ✕ parks off-world.
- **Rejection feedback:** ✓ snapshots `.remaining` counters, waits 4 rAFs, and if neither
  counter decreased: red flash overlay on the canvas + toast
  “Too close — leave a small gap” + `navigator.vibrate(50)`. (Also fires for “physics on”
  / “no blocks left”, matching the engine’s silent-rejection surface; the engine’s own
  blink handles those on desktop.)

## 6. Delete

Quick tap (<10 px, <300 ms) on the canvas → floating 🗑 button appears near the tap
point. Pressing 🗑: `mousemove` to the tapped point (virtual coords), wait 3 rAFs
(sensor contacts refresh during `world.step`), `mousedown {button:2}` + delayed
`mouseup` (right-click delete). Counters increasing confirms deletion (toast on
success is unnecessary; the card visibly disappears). Tapping anywhere else dismisses 🗑.
If no card is under the point the right-click is a no-op — same as desktop.

## 7. Touch chrome (two-thumb split, mockup option A)

Fixed-position overlay outside `.game-box`, natural (unscaled) size, all targets ≥44 px:

- **Landscape:** rotate ⟲⟳ + snap —/| + ✓/✕ on the left edge; nudge pad on the right
  edge; Apply ⚡ / Restart ↺ / Blocks ▤ / Hint 💡 along the top.
- **Portrait:** canvas letterboxed at top; left cluster bottom-left, nudge pad
  bottom-right, top bar between canvas and clusters.
- **Blocks ▤** shows live remaining counts (mirrors `.dynamic/.static .remaining`) and
  toggles dynamic/static by proxy-clicking the hidden `.selector` nodes.
- **Apply ⚡** mirrors `#toggle-physics` (label flips to Rewind ⏪ when the `rewind`
  class appears).
- Visibility state machine (MutationObserver on `.buttons`/`#toggle-physics` class
  lists): clusters show only when in a level (`.buttons` not `hidden`) **and** physics
  is off (`#toggle-physics` lacks `rewind`) **and** no light-box/bs-screen dialog is up.
  Original `.buttons`/`.selectors` are CSS-hidden on touch (DOM stays — the compiled
  Dart writes into them and crashes on missing nodes).
- Menus/dialogs need no touch chrome: they are plain HTML scaled by §3;
  `(pointer-coarse)`-equivalent `.touch-mode` CSS bumps the smallest hit targets
  (menu items, prompt buttons, close links). Chapter list and win-screen tape scroll by
  native scrollbar.js touch drag (§1).

## 8. Files

- `web/external/touch.js` — new; everything above; exposes `window.__touch`
  (mapping helpers + state) for tests.
- `web/cards.html` — viewport meta; add `external/touch.js` to the loader list right
  before `cards.dart.js`.
- `web/cards.css` — `.touch-mode` rules (layout overrides, chrome styling, toast,
  red-flash, hidden desktop bars).
- `playwright.config.js` — new `mobile` project (chromium, Pixel-class viewport,
  `hasTouch`, `isMobile`), `testMatch: 'mobile.spec.js'`; desktop projects ignore it.
- `tests/mobile.spec.js` — new suite (§9).

## 9. Done when

- `npm test` green (desktop chromium + firefox parity, plus the mobile project);
  no Dart / `cards.dart.js` changes.
- `tests/mobile.spec.js` (hasTouch, phone viewport) covers: boot, offset-ghost drag,
  exact nudge steps (±1 px) and rotate steps (±2.5°) verified through the Esc-pause
  localStorage probe, placement, rejection feedback (red flash + toast), tap + 🗑
  delete, two-finger pan, pinch zoom, chapter-list touch scroll, both orientations.
- Win level 1-1 with 3 stars touch-only (one card at x=1.6765 y=1.0647 a=0,
  AGENT_PLAYBOOK.md §8): drag + nudge + ✓ + Apply ⚡ through the touch chrome,
  asserting the `Features.onLevelFinish` result.

---

# v2 (2026-07-06) — gesture-first redesign

Owner feedback on v1: "not touch friendly — make the game responsive/adaptive,
remove the nudge/rotate button clusters, tap places a block, double-tap zooms
into a grid for pixel-perfect placement then zooms back, two-finger rotation
visualized as an animated dotted line the block sits on."

v2 supersedes §3–§7 above. §1 (engine facts) and §2 (activation) still hold.

## Responsive canvas (replaces §3)

The `#graphics` canvas is resized to the real device viewport: attribute and
CSS size both `innerWidth × (innerHeight − 56)` below a 56px chrome bar,
1:1 CSS pixels (no scaling blur). The engine adapts because **all** world
math derives from `Input.canvasWidth/Height` (camera bounds clamp per
`Camera.checkTarget`, the viewport transform is rebuilt every in-level frame
via the bounds check → `updateEngine` → `updateZoom` chain). Screen px ==
canvas px == engine px, so pointer mapping is the identity outside precision
mode. The `getBoundingClientRect` override now returns the tracked *layout*
rect — needed so precision mode's CSS transform stays invisible to the
engine. Dialogs (`.light-box`, `.bs-screen`) keep their internal 800×600 and
are scaled independently as fixed centered overlays via `--dlg-scale =
min(vw/800, vh/600)`.

## Gestures (replace §4–§7)

| Gesture | Behavior |
|---|---|
| tap | place a block at the tapped point (ghost `mousemove` → contact-refresh frame → left click; silent rejection surfaced as red flash + toast + vibration; toast text distinguishes physics-on / no-blocks-left / too-close) |
| double tap | **precision mode**: the canvas gets CSS `translate+scale(3)` centered on the point (engine unaware via the rect override), a world-pixel grid overlay appears (minor 5px / major 25px lines), one-finger drags move the ghost at 1/3 finger speed (sub-pixel), tap places at the fine-tuned position and the canvas animates back; double-tap again exits without placing |
| 1-finger drag | camera pan (engine Space+left-drag; anchor mousemove one frame before mousedown) |
| 2 fingers | rotate: an animated dashed SVG line tracks the fingers, the ghost rides its midpoint and aligns to its angle in 2.5° steps. Angle is driven absolutely: C-snap (0°) at gesture start, then frame-counted Q/E holds (the compiled build rotates 2.5°/frame while held — §1 caveat); the target step count is `round(atan2(−dy, dx)/2.5°)`, tracked in `state.angleSteps` |
| long press (550ms) | delete affordance: floating 🗑 at the point; pressing it moves the ghost there and right-clicks (removes overlapping cards, desktop parity) |

Chrome is a single top bar: Apply/Rewind ⚡⏪, Restart ↺, block-type toggle
with live count, Hint 💡. No placement buttons. Visibility/labels via the
200ms DOM poll (`.buttons` hidden state, `#toggle-physics.rewind`, dialog
detection including template-excluded prompt windows and `bs-open` tagging).

Single-tap actions wait out a 350ms double-tap window (tap latency trade-off
for the double-tap gesture). Drags anchor at the touchstart point so the
10px drag threshold loses no distance in precision mode.

## Tests (replace §9)

`tests/mobile.spec.js` v2: responsive boot (device-sized canvas attribute,
no cluster buttons), tap-place at a predicted world point (validates the
`cameraOffsets` model at arbitrary canvas sizes), double-tap precision
(grid + `scale(3)` on, exact `delta/3` ghost drag, place, transform
restored), two-finger rotate (dotted line visible during gesture, placed
angle snapped to 2.5° steps), one-finger pan (world shift between two
placements at the same screen point), rejection toast, long-press delete,
tape touch-scroll, landscape variant, and a 3-star touch-only win of level
1-1 placed through precision mode.

# v3 (2026-07-07) — one-gesture placement, engine-assisted selection

Three UX changes over v2, driven by phone playtesting: the rotate gesture
needed a follow-up tap, precision zoom confused more than it helped, and
deleting required pressing exactly on a 2.5px-thin brick.

## Gestures (replace the v2 table)

| Gesture | Behavior |
|---|---|
| tap | place a block at the tapped point, **immediately** — the double-tap gesture is gone, so there is no 350ms tap-latency window anymore |
| 1-finger drag | camera pan (unchanged from v2) |
| 2 fingers | rotate along the animated dashed line (unchanged mechanics) — and **lifting the fingers places the block at the line midpoint**. `endRotate(place)` funnels through `placeAt`, which is `whenKeysIdle`-gated, so the queued Q/E rotation frames settle before the click lands |
| long press (550ms) | **pick up the placed block near the finger.** The block leaves the board and becomes the ghost at its exact spot and angle; keep dragging to move it (10px threshold), release to drop it (`placeAt`), or lift without moving and it is re-placed in place with the 🗑 trash button armed on it — tapping the trash removes it (back to its pool). Long-press on empty space does nothing |

## Engine bridge (new)

Selection with finger-friendly bounds can't be done in JS — placed-card
geometry lives inside the compiled engine. `cards.dart` exposes
`window.TouchBridge.grabCardAt(qx, qy, tolPx)` → `GameEngine.grabCardAt`:

- input is canvas-layout px (same frame as synthetic mouse events); world
  point derived with the `Input.onMouseMove` formulas (camera offsets).
- hit test = point-in-rotated-box with a `tolPx` pad (touch.js passes
  `GRAB_PX = 30`) around each placed card's own half-extents; nearest
  (deepest) match wins; hint cards skipped.
- on hit it mirrors the desktop right-click delete path — scrubs the body
  from `contactingBodies` (endContact is unreliable on destroy), calls
  `removeCard` (pool counter back up) + `addHistoryState(_, true)` (Ctrl+Z
  parity) — then parks the **ghost at the card's exact position and angle**
  (`bcard.b.setTransform`) and returns `{x, y, angle, isStatic}` in layout
  px. Returns null when nothing is close enough, or when physics is on /
  rewinding / not ready.
- touch.js matches the block-type selector to `isStatic` (DOM click) so the
  re-placement draws from the right pool, and re-syncs its tracked
  `state.angleSteps` (rotation gestures still C-snap first, so exact angles
  survive a move untouched).

The trash button also deletes through `grabCardAt` (+ park) — single
precise card with fat bounds, instead of the old right-click that removed
every card overlapping the ghost.

Precision mode (CSS zoom + grid + 1/3-speed drag) is fully removed:
`#touch-grid` element/CSS, `state.precision`, `PZOOM`, and the double-tap
recognizer. Sub-pixel placement remains possible programmatically (touch
events carry float coordinates), which is how the 3-star win test places
exactly.

## Tests (replace the v2 list)

`tests/mobile.spec.js` v3: responsive boot, immediate tap-place, double-tap
does-not-zoom (two placements, no transform, no grid element), two-finger
rotate placing on lift (position + 2.5°-snapped angle asserted, no extra
tap), one-finger pan, rejection toast, long-press pickup 14px above the
brick (outside the brick, inside the pad) → drag-move (position moved,
angle preserved, count unchanged), long-press → trash delete (single card,
pool restored), long-press on empty space (no trash, nothing placed), tape
touch-scroll, landscape variant, 3-star win of 1-1 via one exact-coordinate
tap.

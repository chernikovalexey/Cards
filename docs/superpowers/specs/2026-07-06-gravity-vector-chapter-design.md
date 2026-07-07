# Gravity vectors + chapter 4 "Head Over Heels" (2026-07-06)

## What was built

1. **Per-level gravity vector.** A level JSON entry can now declare
   `"gravity_vector": [gx, gy]` (world units, y up). It wins over the old
   vertical-only `"gravity"` scalar and is applied as the Box2D world gravity
   whenever the level is entered (`SubLevel.dart`: constructor and
   `apply()`). The scalar is kept in sync (`length * sign(gy)`) so
   `GameEngine.update`'s custom-gravity sleep gate (`gravity.abs() > 0.1`)
   still engages. The constructor now sets world gravity **unconditionally**
   (previously only custom-gravity levels did), fixing a latent leak where a
   custom level's gravity survived into a following gravity-less level.

2. **Gravity indicator.** `GameEngine.renderGravityIndicator()` drifts three
   huge translucent arrows across the canvas along the gravity direction
   whenever effective gravity differs from the default `(0, -10)`. It reads
   `level.current.effectiveGravity()` each frame — game-wide behavior, no
   per-level opt-in.

3. **Chapter 4 "Head Over Heels"** (`web/levels/chapter_4.json`, 4 levels,
   unlocked from the start (unlock_stars 0)): L1 default gravity, L2 reversed (`"gravity": 10` —
   engine-native scalar), L3 right-to-left (`[-10, 0]`), L4 45° up-right
   (`[7.071, 7.071]`). One-plank 3★ solutions recorded in `solutions/` with
   proofs in `proofs/chapter_4/`; designer hints in `web/levels/hints.js{,on}`.
   Levels chain their cubes (to of N = from of N+1) and containment walls sit
   on the gravity-ward side of each level's action zone.

## The Dart toolchain is back

`web/cards.dart.js` is **compiled from source again** via
`tools/build-dart.sh` (Dart SDK 1.24.3 + pinned pub packages, cached in
`~/.cache/twocubes-build`). Key archaeology, learned the hard way:

- The old `pubspec.lock` was stale: the sources match **box2d 0.1.7** (with a
  hand-added one-line `World.setGravity`, re-applied by the build script) and
  **vector_math 1.4.7** (chainable `sub()`), not box2d 0.4.0/vector_math 2.0.7.
- The committed Dart sources had drifted from the shipped artifact and from
  SDK 1.24 semantics; runtime-fatal drift fixed in source:
  - `cards.dart` show/collapseFriendsBar called the removed `VK` global → no-ops.
  - `GameEngine.dart` used bare `querySelector`/`window` while importing
    `dart:html as Html` → prefixed.
  - `Input.dart` read `MouseEvent.which` (only on `Event` in the 2015 SDK) →
    `MouseEvent.button`.
  - `ChapterShower.dart` injected chapter tiles via `appendHtml`, whose 1.24
    sanitizer strips `data-*` → explicit `NodeValidator` (same pattern as
    RatingShower's tape).
  - `BoundedCard.dart` rotated Q/E on `.clicked` (one step per key event);
    the shipped build repeated every frame while held — which touch.js's
    two-finger rotation counts on (N held frames = N steps) → back to `.down`.
  - `HintManager.addHintCard` called the non-existent `Body.setType` → now
    `b.type = BodyType.STATIC`. In the shipped build the throw leaked the
    half-added hint card into `engine.cards`, which skewed the star rating
    of any level where a hint (or the chapter-1 tutorial ghost) appeared,
    and skipped the hint auto-clear timer.

## Tests

- `tests/parity.spec.js`: chapter pins updated to 4 chapters (production
  still has 3 until the next deploy — `npm run test:prod` will disagree on
  those two tests until then).
- `tests/gravity.spec.js`: reversed-gravity win, leftward-gravity win, arrow
  indicator visible on custom gravity and absent on default (canvas pixel
  sampling). Local-only (skipped against production).

# CLI Play API for Two Cubes — Design

Date: 2026-07-03
Status: approved for implementation

## Goal

Let a machine (Claude, or any script) play Two Cubes: place blocks, apply
physics, observe win/fail — fast enough to test thousands of scenarios — and
ultimately complete all three chapters legitimately. A separate CLI mode
produces video proof of success or failure runs.

## How the game actually works (investigation summary)

All facts below were read from the Dart sources (`web/*.dart`), which are the
reference for the compiled `web/cards.dart.js`.

- **Core loop**: `StateManager.step` runs on `window.requestAnimationFrame`
  and performs exactly **one fixed physics step** (`world.step(1/60, 10, 10)`)
  per frame, regardless of wall-clock delta (`GameEngine.update`,
  `StateManager.dart:48-63`). Frame-hijacking rAF therefore accelerates the
  simulation without changing its outcome.
- **Determinism**: the only randomness is in `ParallaxManager` (background
  stars); physics, energy propagation and win detection are fully
  deterministic given the same placements.
- **Player verbs** (all via `Input.dart` static state fed by canvas/window
  events):
  - Move the ghost card: mouse move (`Input.mouseX = (clientX - canvasX)/scale
    + camera.pxOffsetX/scale`, `Input.dart:47-48`) or WASD (1 px per frame).
  - Rotate: `q`/`e` (±π/72 per press), `c` (0), `v` (π/2), wheel (±π/24).
  - Place: left click or **Enter** (`GameEngine.canPut`), rejected while the
    ghost overlaps anything (`CardContactListener.contactingBodies`).
  - Block type: keys `1` (dynamic) / `2` (static); limits per level
    (`blocks: [static, dynamic]` in the level JSON).
  - Apply physics / rewind: `#toggle-physics` button (or Ctrl+Shift).
  - Undo: Ctrl+Z; delete: hover + right-click/Delete; restart level:
    `#restart` → PromptWindow confirm (`.pp-<n>` button).
- **Win condition**: when every dynamic card is asleep, `Traverser` walks the
  box2d contact graph from the `from` cube; if a touching chain of
  energy-supporting bodies reaches the `to` cube, energy flows and the `to`
  sprite fills at 0.1/frame. When full, `GameEngine.update` marks the level
  complete and Dart calls **`Features.onLevelFinish(chapter, level, stars,
  numDynamic, numStatic, attempts, timeSpent)`** — a JS global we own
  (`web/external/features.js`), i.e. a perfect machine-readable success hook.
- **Fail signal**: cards settle with no path → `GameWizard.showRewind()`
  shows a tooltip, but only if localStorage `apply_fail_occured` is absent.
  Deleting that key before each attempt turns the tooltip into a reliable
  "attempt failed" DOM signal; a tick budget is the fallback.
- **Rating**: stars per level = 3 if `cards.length <= stars[0]`, 2 if
  `<= stars[1]`, else 1 (`SubLevel.getRating`). Chapter 2 unlocks at 30 total
  stars, chapter 3 at 60 (`web/levels/chapters.json`) — so the solver must
  care about block counts, not just completion.
- **Attempts**: decremented from the JS-side `Features.user` object
  (`UserManager.dart`); `boughtAttempts == -1` means unlimited. Search mode
  can set that without touching game code; proof mode leaves it stock (125
  attempts is plenty for a replay).
- **State readout**: pressing Esc pauses and calls
  `engine.saveCurrentProgress()`, which serializes exact card positions to
  localStorage `level_<c>_<l>` (`LevelSerializer.toJSON`: `{cd, c: [{x, y, a,
  s, e}], f, do, df}`); `#resume-game` resumes. This gives placement
  verification and calibration without touching minified internals.
- **UI flow**: menu `#new-game` → `#chapter-es .chapter[data-id]` → play;
  level complete → `#rating-box` → `#next-level`; chapter complete →
  `.chapter-rating-wrap` + `#cc-list`. Chapter 1 level 1 spawns a *hint ghost
  card* (a solid static body) until a body click clears it — the harness must
  click once after entering.

## Approaches considered

1. **Instrumented real game in headless Chromium (chosen).** Playwright
   drives `web/cards.html`; an init script hijacks rAF into a tick pump and
   wraps the JS globals the Dart bridge already calls. Physics are the real
   compiled box2d — a found solution is by construction a real solution.
   Video proof falls out of Playwright's recorder. Cost: ~1s per scenario,
   mitigated by turbo ticking and parallel browser contexts.
2. **Reimplement the rules headlessly in Node** (port box2d + traverser).
   10-100× faster search, but the win condition hangs on exact contact
   graphs, sleep thresholds and fixture parameters; parity risk is huge and
   every solution would still need replaying in the browser. Rejected.
3. **Patch `cards.dart.js` to expose engine internals.** Minified dart2js
   output, no build toolchain; brittle and against the repo rule of keeping
   behavior changes in the JS layer. Rejected.

## Architecture (approach 1)

```
tools/
  cli.js            CLI entry: play | run | prove | info
  lib/harness.js    Playwright session: init scripts, tick pump, hooks
  lib/game.js       Game verbs on top of the harness (goto/place/apply/…)
  lib/levels.js     chapter_N.json reader; px → world-unit conversion
solutions/          per-level solution scripts found by the solver (JSON)
proofs/             video proof output (.webm + summary.json, gitignored)
```

No game file changes are required. All instrumentation is injected at
runtime by the harness:

- **Tick pump** (init script, before any page script): replace
  `requestAnimationFrame` with a queue; expose `__harness.tick(n)` which
  synchronously runs n frames with a synthetic timestamp (+16.67 ms each).
  Real-time mode passes rAF through untouched (used for video).
- **Turbo render stub**: render is load-bearing (energy fill advances
  0.2/render in `EnergySprite.render`), so rendering cannot be skipped —
  instead the `#graphics` 2D context methods are wrapped with no-ops in turbo
  mode. Logic sees the same call sequence; the GPU does nothing.
- **Hooks**: wrap `Features.onLevelFinish` to record `{chapter, level, stars,
  numDynamic, numStatic, attempts}` events; watch for the rewind tooltip
  (after clearing `apply_fail_occured`) as the fail signal.
- **Input**: placement teleports the ghost card with one synthetic
  `mousemove` on the canvas using the inverse of the `Input.dart` mouse
  formula (camera offset is constant because the harness never pans or
  zooms; synthetic events are not hit-tested, so off-screen world coordinates
  work too). A probe placement read back through the Esc-save trick
  calibrates/verifies the mapping once per level; WASD single-frame ticking
  is the exact fallback. Rotation via `c`/`v`/`q`/`e` gives any multiple of
  π/72 exactly. Placement = Enter; type = `1`/`2`.

## CLI surface

`node tools/cli.js <command>`:

- **`info --chapter C [--level L]`** — static level facts from the JSON, in
  world units: from/to cube positions, obstacles, block limits, star
  thresholds, gravity.
- **`play [--chapter C --level L] [--turbo] [--screenshot-dir D]`** —
  interactive JSONL protocol on stdin/stdout for machine play. Commands:
  `goto {chapter}`, `place {x, y, angle, static}`, `restart` (rewind + remove
  all cards, the between-attempts reset), `apply {maxTicks}`, `next`, `state`,
  `cards` (exact placed positions), `info`, `screenshot {path}`, `tick {n}`,
  `quit`. Every response carries `ok`; `apply` returns `{outcome:
  "won"|"failed"|"timeout", stars, ticks}`.
- **`run <scenarios.json> [--parallel N] [--turbo]`** — batch mode for
  thousands of scenarios: input is a list of `{chapter, level, cards:
  [{x, y, angle, static}]}`; each is played (clear → place → apply → record)
  reusing warm pages across scenarios; output is JSONL results with outcome,
  stars and tick counts. This is the "test thousands of scenarios fast"
  clause.
- **`prove [--solutions solutions/] [--out proofs/] [--chapter C]`** — replay
  the stored solutions start-to-finish in real time with Playwright video
  recording, stock game behavior (no turbo, no attempt patch; only the
  read-only success hook). Produces `proofs/chapter_C.webm` and
  `proofs/summary.json` with per-level verdicts (won/failed, stars, cards).
  Failure runs are recorded the same way — the video plus the summary is the
  proof either way.

## Solving all three chapters

The CLI is the hands; solving is a separate activity that uses it. Solutions
live in `solutions/chapter_C.json` as ordered per-level placement lists. The
search loop per level: generate candidate placements (bridge/tower heuristics
between the `from`/`to` cubes read from `info`, plus randomized perturbations),
batch them through `run`, keep the cheapest winner (fewest cards → best star
rating), with Claude inspecting screenshots for levels the generator can't
crack. Chapter progression is legit: chapter 2/3 unlock only through earned
stars (≥30/≥60), which the star-aware solver must satisfy.

## Error handling

- Every `place` verifies the block counter DOM changed; a rejected placement
  (overlap) returns `ok: false` with the reason instead of silently drifting.
- `apply` always resolves: won (hook fired), failed (tooltip signal), or
  timeout (tick budget, default 3600 ticks ≈ 60 sim-seconds).
- The harness fails fast if the page shows the loading overlay after boot
  (subresource drop) by reloading once, mirroring the loader's own retries.
- Session state is disposable: every `run` scenario starts from
  `engine.clear()`; `reset` rebuilds the browser context with a fresh
  localStorage profile (seeded `seen_howto` etc. to suppress tutorials).

## Testing

- A Playwright-independent smoke script (`npm run play:smoke` or plain node)
  boots the harness, solves chapter 1 level 1 with a known one-card solution,
  and asserts the `onLevelFinish` hook fires with 3 stars — pinning the whole
  pipeline (tick pump, placement mapping, hooks).
- The existing parity suite (`npm test`) keeps guarding the game itself; the
  harness never modifies game files, so no parity impact.

## Out of scope

- No changes to game sources or `cards.dart.js`.
- No camera work (pan/zoom) — synthetic events reach any world coordinate.
- No re-implementation of physics outside the browser.
- Level designer/editor features.

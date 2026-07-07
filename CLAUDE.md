# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"Two Cubes" — a legacy web physics-puzzle game (circa 2014–2015), now **fully static with no backend**. The client is Dart 1.24 (pre-Dart-2) compiled to JS with dart2js. The compiled `web/cards.dart.js` is committed AND rebuildable: **edit the Dart sources in `web/` and recompile with `./tools/build-dart.sh`** (fetches SDK 1.24.3 + era-correct pub packages into `~/.cache/twocubes-build` on first run, offline afterwards; see `docs/superpowers/specs/2026-07-06-gravity-vector-chapter-design.md` for the toolchain archaeology — the package versions in `pubspec.lock` are the real ones, older than what the pre-2026-07 lockfile claimed). Do not modernize dependencies without being asked.

The old PHP/MySQL backend was removed in 2026-07 (see `docs/superpowers/specs/2026-07-03-remove-backend-design.md`). Its API is emulated in-browser by `web/external/webapi.js`, whose response shapes are pinned to the production deploy at https://twocubes.io by the Playwright suite.

## Commands

```bash
python3 -m http.server 8080     # serve the game (any static server works)
docker-compose up               # same, via nginx

./tools/build-dart.sh           # recompile web/cards.dart.js from the Dart sources

npm test                        # Playwright suite against a local server (auto-spawned)
npm run test:prod               # same suite against production twocubes.io
npx playwright test -g "boots"  # single test by title

npm run cli -- info --chapter 1 --level 1   # level geometry in world units
npm run cli -- play --chapter 1 --level 1   # machine-play session (JSONL on stdin/stdout)
npm run cli -- run scenarios.json           # batch scenario search (turbo)
npm run cli -- prove                        # replay solutions/ with video -> proofs/
node tools/solve.js --chapter 1             # heuristic auto-solver (saves + records videos)
node tools/try.js --chapter 1 --level 2 --cards '[{"x":2.3,"y":1.03}]' --shots /tmp/s  # one-shot probe
node tools/record.js --chapter 1 --level 2 --cards '[...]'  # verify + save + proof video
node tools/status.js                        # per-level stars / videos / unlock progress
npm run test:cli                            # harness self-tests (node --test)
```

First-time test setup: `npm install && npx playwright install chromium`.

The repo root must be the web root: `web/cards.html` references `/packages/browser/dart.js` by absolute path.

## Architecture

- Entry: `index.html` redirects to `web/cards.html`, which boots the game. All CSS/JS is loaded by an **inline retrying loader** at the end of `<body>` in `cards.html` — for two reasons: (1) Cloudflare+Firefox HTTP/3 connections sporadically drop subresources (`NS_ERROR_NET_HTTP3_PROTOCOL_ERROR`), and a plain `<script>` tag never retries — a lost `scrollbar.js` made the chapter screen unclickable; (2) compiled Dart `main()` immediately grabs the `#graphics` canvas, so it must run after `<body>` is parsed (loading from `<head>` raced warm-cache page parsing; production still has this bug). The two other boot-critical fetches retry too: the locale (`features.js`) and `chapters.json` (`webapi.js`).
- Game engine (`web/*.dart`, compiled into `web/cards.dart.js`): custom canvas engine (`GameEngine`, `StateManager`, `Sprite`), physics via the `box2d` package, levels deserialized from `web/levels/chapter_N.json` + `chapters.json`.
- Gravity is a level feature: the vertical scalar `"gravity"` (legacy) or the full vector `"gravity_vector": [gx, gy]` (2026-07, chapter 4 "Head Over Heels") — applied in `SubLevel.dart`, which keeps the scalar synced for the engine's custom-gravity sleep gate. Whenever effective gravity ≠ default `(0, -10)`, `GameEngine.renderGravityIndicator()` drifts huge translucent arrows along the vector (game-wide cue, no level opt-in). Pinned by `tests/gravity.spec.js`. Dynamic obstacles (types 5/6) still get a hardcoded vertical per-frame force in `GameEngine.update` — avoid them in custom-gravity levels.
- Dart ↔ JS bridge: `web/WebApi.dart` calls global JS objects `Features` (`web/external/features.js`) and `Api` (`web/external/webapi.js`). Any new client behavior that the compiled Dart must trigger goes through these globals.
- `web/external/webapi.js` is the **local API shim**: `WebApi(method, data, callback, async)` dispatches to `LocalServer.handlers` instead of AJAX. It reproduces the old backend's responses for the `no` platform (getUser/initialRequest return a fresh user with 125 attempts — production was stateless too); `chapters` computes unlock state from the localStorage `stars` blob that `StarManager` maintains.
- All persistence is localStorage: `userId`, `stars`, `last` (last played level), `level_<c>_<l>` results, `seen_howto`.
- The VK/Facebook platform integrations were removed (2026-07): `features.js` now only has the base `Features` + `NoFeatures` objects. Social UI elements (share buttons, invite-friends) are hidden via CSS in `cards.css` but their **DOM nodes must stay** — the compiled Dart wires listeners and writes into them at boot and crashes on missing elements. Same for JS methods the Dart bridge calls (`shareWithFriends`, `prepareLevelWallPost` are kept as no-op stubs).
- Localization: `web/external/locales/{en,ru}.js`; elements with class `localized` + `data-lid` get translated at boot. Only `en` is reachable (language selection was VK-specific).
- Touch support (phones): `web/external/touch.js` (loaded right before `cards.dart.js` — it overrides the canvas `getBoundingClientRect` before compiled `main()` runs) resizes the canvas to the device viewport (the engine adapts — all world math derives from `Input.canvasWidth/Height`) and drives play with gestures: tap = place (immediate, no double-tap gesture), 1-finger drag = pan, 2 fingers = rotate (animated dotted line) with the block placed when the fingers lift, long-press = pick up the placed block near the finger (fat hit bounds via the compiled engine's `TouchBridge.grabCardAt` global — see `cards.dart`/`GameEngine.grabCardAt`) to drag-move or trash-delete it. Synthetic mouse/keyboard events feed the compiled engine. Activates only under `(pointer: coarse)`/`ontouchstart` (`?touch=0/1` overrides); desktop is untouched. Design: `docs/superpowers/specs/2026-07-05-touch-support-design.md` (v3 section). Tests: `npx playwright test --project=mobile`.
- PWA: `manifest.webmanifest` + `sw.js` + `_headers` live at the repo root (root scope) and are staged by `npm run deploy`; icons are `web/img/pwa-*.png`. The service worker is **network-first with cache fallback** for all same-origin GETs (fresh deploys are never served stale; the game boots and plays offline after one visit; boot shell precached on install). Network-first only holds because both layers bypass the browser HTTP cache: Cloudflare Pages defaults to `max-age=14400`, so `sw.js` fetches with `cache: 'no-cache'` and `_headers` overrides Pages to `max-age=0, must-revalidate` (unchanged files cost a 304). Bump `VERSION` in `sw.js` only to purge old cache entries. Registration happens from `cards.html` after `load`. Pinned by `tests/pwa.spec.js` (offline boot + CDN-max-age revalidation on chromium).
- Machine play: `tools/` drives the real game in headless Chromium (rAF tick pump — the engine does one fixed `world.step(1/60)` per frame; success hook = wrapping `Features.onLevelFinish`). Solutions live in `solutions/` (write only via `tools/record.js` — it verifies, keeps the better solution, and records `proofs/chapter_C/level_LL.webm`). No game file is modified by the harness. Design: `docs/superpowers/specs/2026-07-03-cli-play-api-design.md`; agent instructions & solving heuristics: `docs/AGENT_PLAYBOOK.md`.

## Testing

`tests/parity.spec.js` pins observable behavior (boot, menu, API contract, chapter list, level start/reload) so that the local build matches production. When changing `webapi.js`, run `npm test`; run `npm run test:prod` only to re-pin against production — two tests are skipped there (mutating API calls, and the reload flow that production's bootstrap race breaks).

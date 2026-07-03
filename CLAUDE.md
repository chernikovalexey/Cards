# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"Two Cubes" — a legacy web physics-puzzle game (circa 2014–2015), now **fully static with no backend**. The client is Dart 1.24 (pre-Dart-2) compiled to JS with dart2js; the compiled `web/cards.dart.js` is committed and there is no working build toolchain for it — treat the Dart sources as reference and make behavioral changes in the JS layer (`web/external/`) when possible. Do not modernize dependencies without being asked.

The old PHP/MySQL backend was removed in 2026-07 (see `docs/superpowers/specs/2026-07-03-remove-backend-design.md`). Its API is emulated in-browser by `web/external/webapi.js`, whose response shapes are pinned to the production deploy at https://twocubes.io by the Playwright suite.

## Commands

```bash
python3 -m http.server 8080     # serve the game (any static server works)
docker-compose up               # same, via nginx

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
- Dart ↔ JS bridge: `web/WebApi.dart` calls global JS objects `Features` (`web/external/features.js`) and `Api` (`web/external/webapi.js`). Any new client behavior that the compiled Dart must trigger goes through these globals.
- `web/external/webapi.js` is the **local API shim**: `WebApi(method, data, callback, async)` dispatches to `LocalServer.handlers` instead of AJAX. It reproduces the old backend's responses for the `no` platform (getUser/initialRequest return a fresh user with 125 attempts — production was stateless too); `chapters` computes unlock state from the localStorage `stars` blob that `StarManager` maintains.
- All persistence is localStorage: `userId`, `stars`, `last` (last played level), `level_<c>_<l>` results, `seen_howto`.
- The VK/Facebook platform integrations were removed (2026-07): `features.js` now only has the base `Features` + `NoFeatures` objects. Social UI elements (share buttons, invite-friends) are hidden via CSS in `cards.css` but their **DOM nodes must stay** — the compiled Dart wires listeners and writes into them at boot and crashes on missing elements. Same for JS methods the Dart bridge calls (`shareWithFriends`, `prepareLevelWallPost` are kept as no-op stubs).
- Localization: `web/external/locales/{en,ru}.js`; elements with class `localized` + `data-lid` get translated at boot. Only `en` is reachable (language selection was VK-specific).
- Machine play: `tools/` drives the real game in headless Chromium (rAF tick pump — the engine does one fixed `world.step(1/60)` per frame; success hook = wrapping `Features.onLevelFinish`). Solutions live in `solutions/` (write only via `tools/record.js` — it verifies, keeps the better solution, and records `proofs/chapter_C/level_LL.webm`). No game file is modified by the harness. Design: `docs/superpowers/specs/2026-07-03-cli-play-api-design.md`; agent instructions & solving heuristics: `docs/AGENT_PLAYBOOK.md`.

## Testing

`tests/parity.spec.js` pins observable behavior (boot, menu, API contract, chapter list, level start/reload) so that the local build matches production. When changing `webapi.js`, run `npm test`; run `npm run test:prod` only to re-pin against production — two tests are skipped there (mutating API calls, and the reload flow that production's bootstrap race breaks).

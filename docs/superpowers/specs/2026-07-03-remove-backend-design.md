# Remove PHP backend — local-only Two Cubes

Date: 2026-07-03
Status: implemented alongside this change

## Goal

Make the game deployable as plain static files: no PHP, no MySQL, no Docker
multi-stage build. Observable behavior must match the production deploy at
https://twocubes.io. Behavior is pinned by Playwright tests that run against
production first, then against the local static build.

## What the backend actually does today

Production (twocubes.io) serves `/web/cards.html` with no `?platform=` query
param, so the client always takes the `NoFeatures` path in
`web/external/features.js`: userId is generated into localStorage, platform is
`no`. All gameplay progress (level state, stars, "last played") is already
stored client-side in localStorage (`Level.dart`, `StarManager.dart`).

Every server call funnels through one function: `WebApi(method, data,
callback, async)` in `web/external/webapi.js`, which POSTs to
`/serverside/index.php`.

Production responses were probed on 2026-07-03. Notably, production is
**effectively stateless** for the `no` platform: every request returns
`{"userId":0, "isNew":true, ...}` — the `tcardusers` INSERT fails silently
server-side, so nothing ever persists. Observed responses:

| method | response |
|---|---|
| `no.getUser` | `{"userId":0,"platformId":"no","platformUserId":"<id>","isNew":true,"dayAttempts":125,"allAttempts":125}` |
| `no.initialRequest` | `{"user":<same as getUser>,"results":[]}` |
| `no.finishLevel` | `{"result":true}` |
| `no.keepAlive` | `{"result":true}` |
| `no.addAttempts` | user object with attempts decremented by the delta, plus `dayAttemptsUsed` |
| `no.chapters` | `{"chapters":[...]}` from `web/levels/chapters.json` with an `unlocked` flag per chapter |

## Approaches considered

1. **JS shim at the `WebApi()` choke point (chosen).** Rewrite the body of
   `WebApi()` to dispatch to an in-browser implementation. Zero changes to the
   compiled Dart (`cards.dart.js` cannot realistically be rebuilt — Dart 1.24),
   zero changes to `features.js`. Smallest possible diff.
2. Keep PHP but stub the DB. Rejected: still needs a PHP runtime, doesn't
   achieve "local only / easy deploy".
3. Rewrite the Dart client to skip the API. Rejected: requires dart2js 1.24
   toolchain; risky and unnecessary.

## Design

### `web/external/webapi.js` — local dispatcher

`WebApi(method, data, callback, async)` keeps its exact signature and async
callback contract (callbacks fire asynchronously via `setTimeout(0)` when
`async !== false`, synchronously otherwise, mirroring jQuery's `$.ajax`).
Methods implemented, reproducing the production responses above:

- `no.getUser`, `no.initialRequest`, `no.finishLevel`, `no.keepAlive`,
  `no.addAttempts` — stateless, byte-shape-identical to production.
- `no.chapters` — reads `levels/chapters.json` (already shipped to the
  client) and computes `unlocked = unlock_stars <= total stars` from the
  localStorage `stars` blob that `StarManager` maintains.
- Unknown methods return an ApiException-shaped object, like the router does.

**Deliberate deviation:** production computes chapter unlocks from
`SUM(result) WHERE userId=0` — a shared garbage row that currently leaves
chapter 2 unlocked for brand-new users and chapter 3 permanently locked for
everyone. The local version implements the *intended* rule (unlock by the
player's own stars). Parity tests therefore pin only stable facts about the
chapter list (3 chapters, names, chapter 1 playable), not the lock state of
chapters 2–3.

### Deletions

- `serverside/` (PHP API), `db/` (MySQL image + schema), `fb_payments/`
  (Facebook Open Graph product pages — payments are impossible without the
  backend and were never reachable on the `no` platform),
  root SQL dumps, root `index.php`.
- `Dockerfile` + `docker-compose.yaml` replaced by a single nginx static
  service so `docker-compose up` keeps working.

### Serving

Repo root must be the web root (`cards.html` references
`/packages/browser/dart.js` absolutely). `index.html` replaces `index.php`
(meta-refresh redirect to `/web/cards.html`). Any static server works:
`python3 -m http.server 8080` or `docker-compose up`.

### Testing

Playwright (`tests/parity.spec.js`), parametrized by `BASE_URL`:

- boot: page title, loading overlay removed, menu visible, `Api.platform ===
  'no'`, `Features.initialized`, localStorage `userId` created
- user: `Features.user.allAttempts === 125`, `isNew === true`
- localization applied (en strings on menu / share button)
- chapter list: 3 chapters, names, chapter 1 starts a level (game UI appears)
- persistence: after starting a level, reload shows the Continue menu item

Workflow: suite must pass with `BASE_URL=https://twocubes.io` (pinning), then
with the local static server (parity).

## Findings from the pinning run

Two production behaviors could not be pinned and are handled as documented
deviations:

1. **Bootstrap race (production bug, fixed locally).** `cards.html` loaded the
   Dart bootstrap from `<head>`; `packages/browser/dart.js` swaps in
   `cards.dart.js` as a non-blocking dynamic script, and compiled `main()`
   immediately does `querySelector("#graphics").getContext(...)`. With a warm
   cache the script often executes before `<body>` is parsed, `main()` throws
   `TypeError: ... getContext$1` on the missing canvas, and the loading
   overlay never goes away. Reproduced repeatedly against production on
   revisit/reload. Fix in the local build: the three bootstrap script tags
   moved to the end of `<body>` (safe — `cards.dart` handles both orders of
   the `Features.initialized` handshake). The reload parity test is therefore
   local-only.
2. **`Features.user` at menu time** is just `{allAttempts: 125}`; the full
   user object arrives only when the game later calls `getUser`. The boot test
   asserts the attempt budget; the API-contract test pins the full shape.

Additional local-only change: jQuery 2.1.1 is vendored
(`web/external/jquery-2.1.1.min.js`) instead of loaded from the CDN, so the
game works fully offline.

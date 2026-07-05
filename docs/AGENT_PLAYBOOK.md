# Two Cubes — Agent Playbook

Instructions for an AI agent playing the game through the CLI harness in
`tools/`. Written to be followed literally. All commands run from the repo
root. Everything is deterministic: the same placements always produce the
same outcome, so a solution that won once will win again.

## 1. Mission

Complete all 36 levels (3 chapters × 12). For every level, find a set of
block placements that connects the two energy cubes, then save it with
`record.js` (which also produces the proof video). Keep improving each level
until it has **3 stars**. Star totals gate progress: chapter 2 unlocks at 30
total stars, chapter 3 at 60, so 3-star solutions are not optional polish —
they are how later chapters open.

Success criteria for the campaign:
1. every level has a saved, verified solution (any stars),
2. `proofs/chapter_C/level_LL.webm` exists for every solved level,
3. each solved prefix has a JSON proof of the best stored solutions for
   levels 1..N, including block counts checked against the level budget,
4. chapter 1 + 2 stars ≥ 60 so chapter 3 is legitimately reachable,
5. final full-chapter videos via `npm run cli -- prove`.

## 2. The game in one paragraph

Two cubes float in a 2D box2d world: the **from** cube is energized, the
**to** cube must be reached. You place rectangular blocks ("jumpers") while
physics is frozen, then press Apply. Blocks fall under gravity (0, −10),
collide, and settle. When everything stops moving, the game walks the chain
of touching blocks starting at the *from* cube; if the chain reaches the *to*
cube, energy flows and you **win**. Fewer blocks used = more stars. If the
settled blocks don't form a connected chain, the attempt **fails** (nothing
is lost — restart and try again).

## 2b. Levels are NOT independent (critical)

A chapter is ONE continuous world. When a level is won, its settled blocks
turn into **solid static bodies that stay in the world forever**, and its
*to* cube becomes the next level's *from* cube. So level N is always played
on top of everything built in levels 1…N-1 — earlier structures can support
your new blocks, or be in the way of a placement.

The harness models this with **context profiles**: winning level N via
`record.js` stores a world snapshot in `solutions/profiles/chapter_C/`, and
every tool (`try.js`, `play`, `solve.js`, `record.js`, per-level videos)
seeds sessions for level N+1 from that snapshot. Consequences you must
respect:

1. **Solve levels strictly in order.** Tools refuse level N until level N-1
   has a recorded win (`no context profile` error).
2. **Lock a level before moving on.** Improve it to 3 stars (or accept your
   best) BEFORE starting the next level — the next level is built on it.
3. **Changing an earlier level invalidates everything after it.** If you do
   improve an already-passed level, immediately run
   `node tools/validate.js --chapter C` — it sequentially re-verifies the
   stored solutions and regenerates the downstream snapshots; if a later
   level breaks, it must be re-solved from there.
4. Your NEW blocks can rest on OLD structures — check the `-before.png`
   screenshot to see what is already in the world near your cubes.
5. `--isolated` (try.js / play) runs an empty world instead — quick geometry
   peeks only; a win there does NOT count and may not reproduce in context.

## 3. Coordinates, sizes, physics facts

Everything uses **world units** (wu). 1 wu = 85 px. Y points **up**.

| Fact | Value |
|---|---|
| block (card/jumper) size | 0.529 long × 0.029 thick |
| energy cube size | 0.412 × 0.412 |
| cube coords in `info` | `x, y` = **lower-left corner**; center = x+0.206, y+0.206 |
| card coords in `place` | `x, y` = **center** of the card |
| gravity | (0, −10) — blocks fall down. No level overrides it |
| card friction | 0.115 — **very slippery**; unsupported chains slide apart |
| card angular damping | 10.5 — rotation is heavily damped; aligned stacks stand |
| contact skin | ~0.02 wu — see the placement-clearance rule below |
| static blocks | beige; **do not fall** when physics applies — free anchors |
| dynamic blocks | orange; fall under gravity |

**Placement clearance rule (critical):** a placement is REJECTED if the ghost
card touches anything. Contact registers up to ~0.02 wu before surfaces meet
(box2d skin). Always leave **≥ 0.05 wu** between your card's surface and any
other surface (cube tops, other cards, obstacles). Cards just fall the extra
0.05 when physics starts — it costs nothing.

**Angles** are radians, snapped to π/72 (2.5°). `0` = horizontal,
`Math.PI/2` (1.5708) = vertical. Cards are symmetric: 0 and π are the same.

## 4. The commands

### 4.1 Read a level: `info`

```bash
npm run cli -- info --chapter 1 --level 6
```

Returns JSON. Fields you need:
- `from`, `to` — the cubes: `{x, y, w, h}` lower-left corner + size (wu).
  The card must ultimately connect these two.
- `blocks` — `{static: N, dynamic: M}` — your budget. Never plan more.
- `stars` — `[a, b]`: use ≤ a cards → 3 stars; ≤ b → 2 stars; more → 1 star.
- `gravity` — always −10 in this game.
- `obstacles` — rectangles `{x, y, w, h}` (lower-left + size) or polygons
  `{points: [...]}`. `dynamic: true` obstacles fall when physics applies.
  Do not place cards overlapping any obstacle.

### 4.2 Probe an idea: `try.js` (one shot, ~10 s)

```bash
node tools/try.js --chapter 1 --level 6 \
  --cards '[{"x":4.13,"y":4.36,"angle":0},{"x":4.45,"y":4.44,"angle":0}]' \
  --shots /tmp/shots
```

Output JSON, read these fields in order:
1. `placements[i].ok` — `false` means REJECTED (overlap / no blocks left).
   The card was NOT placed. Fix coordinates before anything else.
2. `result.outcome` — `won` / `failed` / `timeout`.
3. `result.stars` — if won.
4. `cardsProbe` — where each placed card actually was **before physics**
   (verify your coordinates landed where you intended).
5. `/tmp/shots/cXlY-before.png` and `-after.png` — LOOK AT BOTH. `before`
   shows your placement; `after` shows where everything settled. The gap
   between intention and settlement tells you what to fix (see §6.4).

### 4.3 Save a win: `record.js` (the ONLY way to save)

```bash
node tools/record.js --chapter 1 --level 6 --cards '[...same JSON...]'
```

What it does, in order: replays your cards in turbo **in context** to
**verify** the win → merges into `solutions/chapter_1.json` **only if
better** than what's stored (more stars, or same stars with fewer cards) →
captures the after-win world snapshot to `solutions/profiles/chapter_1/`
(this is what unlocks level 7 for every tool) → records/updates the proof
video `proofs/chapter_1/level_06.webm`.

- It is safe when several agents run it at once (file locking).
- It exits 0 with `"ok": true` on a verified win; exit 1 otherwise.
- NEVER edit `solutions/*.json` by hand. NEVER claim a level solved without
  a successful `record.js` run — it is the source of truth.

### 4.4 Bulk search: `solve.js`

```bash
node tools/solve.js --chapter 1 --parallel 6 --rounds 30
node tools/solve.js --chapter 1 --level 6 --rounds 60 --force
```

Generates bridge/tower candidates automatically and searches them, walking
levels strictly in order (a level is skipped with `SKIPPED — no context
profile` until its predecessor is recorded). Skips levels that already have
3 stars (unless `--force`). Saves + snapshots + records video on improvement
automatically. Run this FIRST on any unsolved chapter; only levels it
reports `no win found` need your manual attention.

### 4.5 Where am I: `status.js`

```bash
node tools/status.js          # human table:  3:2*v  = level 3, 2 stars, video exists
node tools/status.js --json   # machine form
```

### 4.6 Interactive session: `play` (for hard levels)

```bash
npm run cli -- play --chapter 2 --level 9
```

Then write one JSON command per line on stdin; read one JSON response per
line from stdout. First line printed is `{"ready":true,...}`.

| Command | Effect |
|---|---|
| `{"cmd":"info"}` | level facts |
| `{"cmd":"place","x":4.1,"y":4.36,"angle":0,"static":false}` | place a card; response `ok:false` = rejected |
| `{"cmd":"apply"}` | run physics; response `{outcome, stars?, ticks}` |
| `{"cmd":"restart"}` | remove all cards, reset counters (use between attempts) |
| `{"cmd":"cards"}` | exact positions of placed cards |
| `{"cmd":"state"}` | blocks remaining, physics on/off, win events |
| `{"cmd":"screenshot","path":"/tmp/s.png"}` | rendered frame |
| `{"cmd":"next"}` | advance after a win |
| `{"cmd":"quit"}` | end session |

Prefer `try.js` (stateless, simpler). Use `play` when you want to keep a
board and iterate placements without re-booting per attempt.

### 4.7 Full-chapter cinematic proof: `prove`

```bash
npm run cli -- prove --chapter 1        # plays the whole chapter start to finish
npm run cli -- prove                     # all three chapters, carrying progress
```

Run this only when a chapter is fully solved. Per-level videos are already
handled by `record.js` / `solve.js`.

### 4.8 Prefix proof JSON (levels 1..N)

Every handoff or "frontier advanced" report must include a machine-readable
proof JSON for the solved prefix of the chapter. This is separate from the
video proof: it lets the next agent verify that the best stored solution for
each level uses no more blocks than the level actually provides.

Shape:

```json
{
  "chapter": 1,
  "solvedThrough": 5,
  "levels": [
    {
      "level": 1,
      "stars": 3,
      "cards": 1,
      "used": { "static": 0, "dynamic": 1 },
      "available": { "static": 0, "dynamic": 3 },
      "budgetOk": true,
      "video": "proofs/chapter_1/level_01.webm"
    }
  ]
}
```

Rules:
- Read the best solution from `solutions/chapter_C.json`; never invent card
  counts from memory.
- Treat this as a proof of the stored best solution, not of the historical
  reference snapshot. If the repo contains extracted reference JSON, use it
  only as inspection input unless `record.js` has verified and stored the
  same cards in `solutions/chapter_C.json`.
- Read the available block budget with
  `npm run cli -- info --chapter C --level L`.
- `used.static` is the count of cards with `"static": true`; `used.dynamic`
  is every other card. Both must be ≤ `available`.
- Also compare the best stored solution's total card count against the level
  budget before advancing. If the stored JSON uses more blocks than the level
  provides, the chapter is not valid progress even if it wins.
- If any `budgetOk` is false, do not advance the frontier. Re-run
  `record.js` with a legal solution or mark the level broken.
- The proof JSON is a report artifact/checklist. It does not replace
  `record.js`, `solutions/chapter_C.json`, context profiles, or videos.

## 5. Building structures that win — heuristics

Compute these numbers from `info` first:

```
fromTop  = from.y + from.h            # y of the from cube's top surface
toTop    = to.y + to.h
fromCx   = from.x + from.w/2          # cube center x
toCx     = to.x + to.w/2
span     = |toCx - fromCx|
rise     = toTop - fromTop            # + means to-cube is higher
restY(surfaceY) = surfaceY + 0.0147 + 0.05   # card center resting placement
```

### 5.1 Single bridge (span < 0.5) — always try first
One horizontal card across both cube tops:
```
{ x: (fromCx+toCx)/2, y: restY(max(fromTop,toTop)), angle: 0 }
```
1 card → almost always 3 stars.

### 5.2 Weave bridge (flat-ish gaps, span 0.5–2.5)
Brick-bond: even cards rest at cube-top height, odd cards lie across their
joints one layer up. Adjacent same-row cards must NOT overlap (keep centers
≥ 0.59 apart in the same row); odd cards overlap both neighbours.
```
n cards, centers evenly from fromCx+0.16·sign to toCx−0.16·sign
step must satisfy 0.30 ≤ |step| ≤ 0.42
y_i = restY(cubeTop line) + (i % 2) · 0.084
```
Fails by sliding apart when overlaps are thin — increase n / overlap.

### 5.3 Settled raft exemplar (flat gaps that beat sparse bridges)
The original embedded hint/save JSON in old `serverside/chapter1.full.json`
contains completed card traces. Treat those cards as **settled shapes**, not
as legal placement commands. They are valuable because they show which
structures survive physics:

- level 1-6 uses a dense, almost-horizontal two-band raft across the two cube
  tops: all 7 cards are within about 0.09 vertical units and most angles are
  within 0.02 rad of flat;
- levels 1-8 and 1-9 repeat the same idea on wider gaps: two static shelf
  anchors when available, then many nearly-horizontal dynamic planks in close
  x spacing;
- level 1-5 uses a near-vertical tower with slight lean and x drift, plus a
  base brace; the minimal 4-card win is a cleaned-up version of that shape;
- levels 1-10 and 1-11 use paired vertical stacks plus short flat caps, not a
  long suspended chain.

When a sparse weave/cascade fails on a flat gap, switch to a raft search:
build 2 close height bands above the cube tops, with mostly flat cards,
small alternating slopes (`±0.02` rad), and x centers from the left support
center to the right support center. Search the legal placement version of the
shape: same-band centers need placement clearance, so use fewer cards than
the settled trace, stagger row heights by `0.045..0.09`, and validate each
candidate with `try.js`. Do not copy the embedded arrays into solutions; use
them only to choose structure class, density, slope, and support locations.

### 5.4 Cascade ramp (gentle slopes)
Each card one layer (0.084) above the previous, dense horizontal overlap
(|step| ≤ 0.25). Good when `rise` is between 0.3 and 1.5 over the span.

### 5.5 Tower (vertical rise > 0.5, e.g. shafts)
Vertical cards (angle π/2) stacked end-on-end. Spacing between centers:
**0.579** (= 0.529 card length + 0.05 clearance). Base card center:
`lowCubeTop + 0.05 + 0.265`. The stack must stand BESIDE the target cube
(x = to.x − 0.055 or to.x + to.w + 0.055), never through it — a card
overlapping the cube is rejected. Stacks stand because rotation is damped,
but they are fragile. The embedded traces show that a slight lean and drift
are often better than a perfectly straight column: try `π/2 ± 0.02..0.10`
and x drift toward the target, then add a low brace if the base walks.
Cap with one horizontal card on top reaching toward the target if the tower
is off to the side.

### 5.6 Static anchors
If `blocks.static > 0`, the level almost certainly NEEDS them: place static
blocks (`"static": true`) as fixed supports where dynamic structures would
slip — mid-gap pillars to rest planks on, shelf under an overhang. Statics
don't fall; build the dynamic path on top of them.

### 5.7 What tends NOT to work
- Long chains of barely-overlapping planks — friction 0.115, they slip.
- Free-standing towers taller than ~6 cards without a wall/cube beside them.
- Anything touching at placement time (< 0.05 clearance) — rejected.
- Cards resting half on a cube edge — they see-saw and tip; keep the card's
  center above the supporting surface.

### 5.8 Iteration discipline
Change ONE thing between tries. Rejected placement → fix coordinates (bump
y by +0.05). Structure collapsed left → shift anchor left / add overlap.
`timeout` → something is still moving; usually a card rolling — flatten it.
After 5–6 failed variations of one idea, screenshot the level empty
(`try.js --cards '[]' --no-apply --shots ...`), look at the actual geometry
(obstacles!), and pick a different structure class.

## 6. Reading failures

| Signal | Meaning | Do |
|---|---|---|
| `placements[i].ok == false`, reason `overlap or physics on` | ghost touched something at placement | raise y by 0.05; check against obstacles and earlier cards |
| reason `no blocks left` | budget exhausted | plan uses ≤ `blocks` counts |
| `outcome: failed` | settled, no connected path | look at `-after.png`: where did the chain break? |
| `outcome: timeout` | never settled in budget | a card is rolling/sliding forever; remove or flatten it |
| won but < 3 stars | too many cards | remove the least load-bearing card and retry |
| `landed on level X, wanted Y` | earlier levels not marked done in this profile | you gave a wrong `--level`; use the exact target level |

`cardsProbe` x/y within 0.02 of what you asked = placement was exact; the
problem is physics, not coordinates.

## 7. Multi-agent pipeline (coordinator + subagents)

Because levels are sequential (§2b), a chapter advances one level at a time.
Do not spend the whole search budget on blind concurrent variants. Use a
staged search: try the obvious heuristics briefly, then switch to a thinking
subagent that studies the actual geometry and physics failure modes before
more candidates are generated. The store keeps whichever recorded solution
is best, and `record.js` remains safe to call concurrently, but concurrency
is for validating selected ideas, not replacing analysis.

**Smart-search escalation rule:**
- Give the basic heuristics (§5.1–§5.6) only 2–3 serious attempts per
  structure class, or 6 total failed attempts, whichever comes first.
- Escalate immediately if attempts fail for different reasons than expected
  (e.g. a bridge idea turns into a sliding/tipping problem, an obstacle
  blocks the only clean span, or block budget makes the obvious plan too
  expensive).
- After escalation, stop random nudging. Ask the analysis subagent for a
  small ranked list of new ideas, seeded by the embedded trace heuristics
  in §5.3 when the geometry matches, and include the best stored JSON
  solution as a baseline to beat. The subagent should reason about geometry
  and physics, then return concrete candidates that you validate with
  `try.js`. Only ideas that actually win are passed to `record.js`.

**Coordinator loop (per chapter C):**
1. `node tools/status.js --json` → find the frontier: the lowest level L
   that is unsolved, and whether already-passed levels are below 3 stars.
2. Cheap pass first: `node tools/solve.js --chapter C --parallel 6
   --rounds 30`. It walks levels in order, searches generated candidates in
   context, and records wins + snapshots + videos automatically. Levels it
   reports `no win found` are the frontier for subagents.
3. For the frontier level L, run one focused heuristic pass: read `info`,
   inspect the empty/context board screenshot, and try at most 6 total
   candidates from the obvious classes (§5.1–§5.6). Record any win
   immediately.
4. If no 3-star win appears quickly, spawn one analysis subagent with:
   this playbook path, chapter C, level L, the `info` JSON, before/after
   screenshots for failed attempts, the failed cards/results, and the
   current best entry to beat (from `solutions/chapter_C.json`, may be
   absent). Its job is to reason about geometry and physics, then return
   3–5 ranked candidate strategies with concrete cards or generation ranges.
5. Validate the ranked ideas with `try.js`, in small parallel batches only
   when the candidates are independent. Record every winning candidate with
   `record.js`; discard ideas that do not place cleanly or do not win.
6. If the level now has 3 stars — advance to L+1.
   If it is won but < 3 stars, run ONE more improvement round (fresh
   analysis, told the current card count to beat); then accept the best
   and advance — do not stall the chapter forever (you can return later,
   but that requires re-validating everything after it, §2b.3).
7. Before advancing, produce the prefix proof JSON (§4.8) for levels 1..L.
   Check every best stored solution against `info.blocks`; a level whose
   best JSON uses too many static or dynamic cards is not valid progress.
8. If an already-passed level was improved later:
   `node tools/validate.js --chapter C` immediately, and re-solve any level
   it reports broken before doing anything else.
9. When all 12 levels are recorded, run `npm run cli -- prove --chapter C`
   for the full-chapter cinematic video, check `proofs/summary.json` says
   `completed: true`, then move to the next chapter.
10. Star budget check before leaving a chapter: `status.js` shows unlock
   thresholds (ch2 needs 30 stars from ch1; ch3 needs 60 from ch1+ch2). If
   short, pick the passed levels with the largest `threeStarTarget` minus
   used-cards slack and run improvement rounds on them (then step 7).

**Analysis subagent loop (assigned chapter C, level L):**
1. Read `info` and the supplied screenshots/results. Compute span, rise,
   cube tops, obstacle clearance, block budget, and star thresholds.
2. Classify why the first attempts failed: placement rejection, sliding,
   tipping, insufficient contact chain, timeout, obstacle interference, or
   too many blocks for the star target.
3. Think from physics, not templates: identify stable anchors, old
   structures that can support the new path, likely slide directions,
   where a static block would remove a failure mode, and where clearance
   must be increased.
4. Return 3–5 ranked ideas. Each idea must include:
   intended support path, expected failure mode, exact initial card JSON or
   a tight coordinate range, estimated static/dynamic counts, and why it can
   beat the current best.
5. Validate ideas with `try.js`. If an idea fails, revise it once based on
   `-after.png`; if the same physical failure remains, discard that idea.
6. On EVERY win — even 1 star — IMMEDIATELY
   `node tools/record.js --chapter C --level L --cards '[...]'`.
   It re-verifies in context, keeps it only if better, writes the context
   snapshot for level L+1, and records the proof video. A win that isn't
   recorded doesn't exist.
7. After `record.js`, read the best stored level entry and make/update the
   prefix proof JSON (§4.8). Explicitly compare that best solution's
   `used.static` and `used.dynamic` counts to `info.blocks`; report the
   counts with the `record.js` JSON.
8. Check `record.js` output `best.stars`. If < 3: keep iterating with
   fewer cards (target `info.stars[0]`). If 3 and `budgetOk` is true:
   report done and stop.
9. Hard stop after 2 analysis rounds or ~12 validated candidate attempts:
   report the level stuck, with the ranked ideas, best `-before/-after`
   screenshots, and the concrete physics failure that remains.

**Rules for every agent:**
- Only `record.js` writes solutions/profiles. No manual JSON edits, no git
  commits.
- Work only on your assigned level; never start a level whose predecessor
  has no recorded win (the tools enforce this with `no context profile`).
- Every claim of "solved" must quote the `record.js` JSON output.
- Every claim of "frontier advanced" must include the prefix proof JSON for
  levels 1..N and show `budgetOk: true` for each level.
- After the first quick heuristic budget is spent, every new candidate must
  come from a stated geometry/physics hypothesis, not random coordinate
  drift.

## 8. Worked example (level 1-1, start to finish)

```bash
$ npm run cli -- info --chapter 1 --level 1
# from: {x:1.176, y:0.588, w:0.412, h:0.412}  -> top 1.0, center x 1.382
# to:   {x:1.765, y:0.588, w:0.412, h:0.412}  -> top 1.0, center x 1.971
# blocks: {static:0, dynamic:3}; stars [1,2]
# span = 0.59 -> too wide? card is 0.529... but cube tops are level:
# single card CAN rest on both inner edges. Try it.

$ node tools/try.js --chapter 1 --level 1 \
    --cards '[{"x":1.6765,"y":1.0647,"angle":0}]' --shots /tmp/s
# placements: [true], result: {outcome:"won", stars:3}

$ node tools/record.js --chapter 1 --level 1 --cards '[{"x":1.6765,"y":1.0647,"angle":0}]'
# {"ok":true, "verified":{"outcome":"won","stars":3,...}, "saved":true,
#  "video":"proofs/chapter_1/level_01.webm"}
```

y was computed as `restY(1.0)` = 1.0 + 0.0147 + 0.05 = 1.0647.

## 9. Guarantees the harness gives you

- Determinism: identical placements → identical outcome, every time.
- No game files are modified; everything runs in a throwaway browser profile.
- Attempts are unlimited in search mode; `restart` is free.
- Turbo verification in `record.js` uses the same physics as the real-time
  video — if turbo won, the video wins too.

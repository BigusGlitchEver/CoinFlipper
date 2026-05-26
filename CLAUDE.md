# CLAUDE.md — Coin Flipper

This file is read automatically at the start of every session. It defines how this
project is built. Follow it on every change unless I explicitly say otherwise.

## What this is

A hand-drawn 2D kids-conquest game in LÖVE2D (Lua / LuaJIT). You flip items
(coins, toast, pancakes) onto a board of pocket-style scoring zones, chain
multipliers, earn Marbles, and conquer houses boss-by-boss. Roguelite run
structure with a Cookie-Clicker-style idle meta-layer. Tone: schoolyard swagger,
Slay the Spire's casual cool. Single player for the prototype.

The design bible is the GDD. When a gameplay decision is ambiguous, check the GDD
before inventing something; if the GDD is silent, ask me rather than guessing.

## Architecture — non-negotiable

**State machine.** LÖVE is a framework, not an engine; it has no scene manager,
so we built one. `main.lua` is deliberately tiny and contains NO game logic — it
only sets up the window, registers states, and forwards LÖVE callbacks to
`statemachine.lua`. Every screen is its own file in `states/`.

- A state is a table implementing any of: `enter(prev, ...)`, `exit()`,
  `update(dt)`, `draw()`, `mousepressed(x,y,button)`, `keypressed(key)`.
  Missing methods are skipped — states only define what they use.
- To add a screen: create `states/<name>.lua`, register it with one line in
  `main.lua`, and switch to it via `StateMachine.switch("<name>", ...)`.
- Extra args to `switch` are forwarded to the new state's `enter`. This is how
  the map passes the house name into the game state. Use this pattern for
  state-to-state data; do NOT reach for globals.

**Entities use classic.lua.** Lua has no native classes. Player, Coin, Pocket,
Enemy, etc. are classic classes in `entities/`, with `:new()`, `:update(dt)`,
`:draw()`. Use inheritance for shared behavior (e.g. an Item base for flip items).
`require("lib.classic")` at the top of each entity file.

## LuaJIT performance rules — apply automatically

- **Localize hot functions** at the top of any file with loops:
  `local sin = math.sin`, `local lg = love.graphics`, etc. No global lookups
  inside update/draw.
- **Never create tables inside `update` or `draw`.** Pre-allocate in the state's
  `enter` (our equivalent of `love.load`) and reuse. This is the most common way
  to tank framerate — watch for it in every change.
- **Object pooling** for anything spawned repeatedly: score popups, the Marble
  shower, particles, multiple flip items. Recycle from a fixed-size pool; never
  create/destroy on the fly. The score-popup pool in `states/game.lua` is the
  reference pattern — copy it.
- Prefer numerical `for i = 1, #t` and `ipairs` over `pairs` so LuaJIT can
  compile the loop. Reserve `pairs` for genuine hash maps.

## Collision / landing

Landing detection is a squared-distance point-in-circle check against pockets
(`Pocket:contains`). Do NOT pull in `love.physics`/Box2D for the flip — it's
overkill and makes things floaty. Keep detection (is it inside?) separate from
any response logic. The coin's "flip" is faked 3D: an x,y board position plus a
fake z height driving a vertical draw offset, a shadow, and a scale/squash
tumble — no animation frames, which suits the hand-drawn-asset pipeline.

## Design principles (from the GDD + reference math)

- **Tight zone values; the multiplier is the source of big numbers.** Per the
  Balatro lesson in the notes: the best pocket should NOT be ~10x the worst at
  base (center is 5, others 2–3). Big scores come from the multiplier chain and,
  later, Bicycle cards — not from fat zone values. Hold this line.
- **Multiplier chain:** consecutive pocket hits stack the multiplier; a miss
  (landing in empty board) resets it to 1. This risk/reward tension is core.
- **Difficulty lever is shrinking pockets, not obstacles.** Floors 2 and 3 reuse
  the Floor 1 pocket layout with smaller radii and higher pass thresholds.
  Obstacles are out of scope for the prototype.
- **"More pockets / bigger pockets" is the card-and-stage lever.** Adding a
  pocket or fattening radii is exactly what cards and stage effects should do.
  Keep pocket setup data-driven so this stays a one-liner.
- **Hand-drawn art is the aesthetic.** All sprites are drawn by the developer
  and imported as-is — rough lines on purpose. UI chrome stays minimal so the
  art carries personality. Animations are simple: scale bounce, shake, slide.
  The colored placeholder shapes in code are stand-ins for sprites; keep draw
  code easy to swap a sprite into.
- **One currency: Marbles.** Run Marbles and global Marbles are the same.
  Losing a boss flip costs the run's Marbles; the global bank is untouched.

## Conventions

- One class/state per file. `states/` for screens, `entities/` for game objects,
  `lib/` for third-party (`classic.lua` lives here).
- 2-space indent, matching existing files.
- Comment the why, especially around `dt` usage and any perf-sensitive loop.
- Keep placeholder visuals clearly marked so it's obvious what's awaiting real
  art.

## Verifying changes

You can't open a LÖVE window in this environment, so you can't judge feel —
that's the developer's job by running `love .`. But you CAN and SHOULD verify
logic headlessly: stub the `love` global (`love.graphics` as a no-op metatable,
etc.), require the modules, drive the state machine, and assert on outcomes
(scoring, lock/unlock, multiplier reset, pool recycling). There are reference
smoke tests in the project's test approach — write one for any non-trivial logic
change before calling it done. Also byte-check syntax with `luajit -bl <file>`.

## Current state of the build

**Working:** state machine + `main.lua` routing; neighborhood map
(`states/map.lua`) with a cul-de-sac and three houses (Grandma playable/red,
Cat + Gym Bro locked/grey, conquered = green), sequential lock/unlock,
click-to-enter passing the house name; flip board (`states/game.lua`) with one
Coin entity, five Floor-1 pockets, arc-flip physics, pocket scoring, multiplier
chain, score-popup object pool, and a HUD. **M** returns to map, **R** resets,
**Esc** quits.

**Not built yet:** real win/lose flow, floors 2–3 (shrinking pockets), shop,
Bicycle cards, boss flip + tug-of-war bar, idle/passive Marble layer, the
Angel/Demon event, the special Marble jackpot, and persistence of the global
bank across runs.

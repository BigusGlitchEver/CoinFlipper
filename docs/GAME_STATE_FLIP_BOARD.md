# Coin Flipper — Flip Board: Capabilities & File Map

Use this document to orient a new Claude session to the flip-board game state.
It describes every mechanic that is currently working, where the code lives,
and what each file is responsible for. Nothing here is speculative — it
describes the code as it stands right now.

---

## Overview

The game is a LÖVE 2D (Lua) project. `main.lua` is a thin router; all logic
lives in named states managed by `statemachine.lua`. There are two states:

| State | File | What it does |
|-------|------|--------------|
| Map   | `states/map.lua` | Neighbourhood screen — 3 houses, click to enter |
| Game  | `states/game.lua` | The flip board (this document) |

The game state is split into focused submodules under `states/game/`:

| Submodule | File | Responsibility |
|-----------|------|----------------|
| Config | `states/game/config.lua` | All constants, palette, geometry |
| Layout | `states/game/layout.lua` | Screen rectangles, rebuilt on enter |
| Fonts | `states/game/fonts.lua` | Lazily created HUD fonts |
| Flip | `states/game/flip.lua` | Shot math, press detection, launch + chain logic |
| Spawn | `states/game/spawn.lua` | Coin placement, replenish, egg-split spawn |
| Render HUD | `states/game/render_hud.lua` | Left sidebar panel |
| Render Board | `states/game/render_board.lua` | Playing surface, tool, preview, overlays |

Entity and data files used by the game state:

| File | Responsibility |
|------|----------------|
| `entities/coin.lua` | Coin object: draw, physics animation, launch/bounce |
| `data/flip_items.lua` | Per-item flight tuning (power, arc, regions) |
| `data/coin_tiers.lua` | 4-tier degradation: colors + score multipliers |
| `ui/card.lua` | Single card widget (used in the sidebar) |
| `ui/card_panel.lua` | Scrollable card list in the sidebar |
| `helpers/probability.lua` | Weighted pick, coin flip, lerp utilities |

---

## Screen Layout

- **Window**: 800 × 600, not resizable (`conf.lua`).
- **Left sidebar** (220 px wide): parchment-tan HUD panel.
- **Right area**: the playing board + border frame, filling the rest.
- **Board**: white rectangle inside a dark border frame. Upper portion holds
  the scoring zones; lower strip is the START ZONE where coins rest.
- All pixel measurements are computed dynamically in `states/game/layout.lua`
  (`L.rebuild()` is called on `Game:enter`).

---

## Coins on the Board

### Types (`data/flip_items.lua`)

There are three food-coin types that appear on the board. Each has sprite art
in `assets/coins/`:

| Type | File | Radius | Behaviour |
|------|------|--------|-----------|
| Toast | `assets/coins/toast.png` | 1.15 × base | Standard launch |
| Egg   | `assets/coins/egg.png`  | 1.0 × base  | Splits on chain hit |
| Skull | `assets/coins/skull.png` | 0.65 × base | Standard launch |

The base coin radius scales with window width (`COIN_RADIUS_AT_390W = 24` in
`config.lua`). Tool radius = 1.5 × coin radius.

### Coin Tiers (`data/coin_tiers.lua`)

Each coin has a `tier` (0–3) that degrades on non-scoring flips:

| Tier | Color | Score multiplier |
|------|-------|-----------------|
| 0 | Amber-yellow `#F0C040` | 1.00× |
| 1 | Blue `#4488FF` | 0.75× |
| 2 | Purple `#AA44FF` | 0.50× |
| 3 | Red `#FF4444` | 0.25× |

Tier bumps on white-zone miss or off-board miss. Tier resets are not
implemented; tier only goes up.

### Golden Coins (`spawn.lua` + `coin.lua` + `flip.lua`)

When an egg is hit by a chain reaction it spawns a bonus coin. Each bonus coin
has a **1-in-5 chance** of being **golden**:

- Regular spawned coin: tier 1 (blue, 0.75× mult).
- Golden spawned coin: tier 0, bright yellow fill `#FFD41F`, **5× score
  multiplier** (`scoreMult = 5` factored in `resolveFlip`).
- Visual: `coin.golden = true` overrides the tier fill color in `Coin:draw`.

---

## Board Scatter & Replenishment (`states/game/spawn.lua`)

| Function | What it does |
|----------|--------------|
| `scatterBoard()` | Places 8 opening coins (toast × 3, egg × 3, skull × 2) in the START ZONE on `Game:enter`. |
| `replenishCoins(self)` | Called every frame. Adds random coins when the resting count drops below `MIN_BOARD_COINS` (6), topping up to `TARGET_BOARD_COINS` (8). |
| `scatterCoins(n, item)` | General-purpose scatter (not currently used at runtime). |
| `spawnCoinsAt(self, x, y, count, tier)` | Creates `count` bonus coins at a landing point with ≤ 6 px scatter. Used by the egg-split mechanic. Returns a reused module-level buffer (no allocation). |

---

## The Flip Tools (`states/game/config.lua`, `states/game/flip.lua`, `states/game/render_board.lua`)

Two tools exist, toggled with **T**:

### Circle Tool
- Drawn as a semi-transparent disc (radius = `L.toolR`).
- Engages any coin whose disc **overlaps** the tool disc:
  `dist(toolCenter, coinCenter) < toolR + coin.radius`.
- No dead zone — can touch any point of any coin from any direction,
  including coins pinned to a wall.
- Contact point sits on the coin's near side (toward the tool), so the
  launched coin always flies **away** from the tool.
- In the normal orbit zone (`dist ≥ toolR`) the contact is identical to the
  old rim-projection, preserving aim/power feel.

### Triangle Tool
- Drawn as a symmetric isosceles triangle with the **sharp apex straight up**,
  vertically centred on the cursor.
- Vertices (unit vectors × `toolR`):
  - Apex: `(0, -1.08)` — straight up
  - Base-right: `(0.72, 0.54)`
  - Base-left: `(-0.72, 0.54)`
- Each tip independently finds the nearest non-flipping coin within
  `coin.radius + L.coinR` (one base-coin radius of forgiveness outside the
  coin's edge).
- Can engage up to 3 coins simultaneously (one per tip).
- Contact point = the tip, so coins launch away from the jabbed tip.

### Tool Engagement Logic (`flip.lua` → `findPressedCoin`)
- Up to 6 conflict slots (preallocated in `Game:enter`).
- When multiple coins are under the tool, **A / Left** and **D / Right** cycle
  the selection. The selected coin is highlighted with a cyan ring.
- `_refreshHover()` in `game.lua` recomputes the engaged set every frame.

---

## Shot Physics (`states/game/flip.lua` + `entities/coin.lua`)

### Power & Arc Model (`resolveShot`)

Two zones split at `zone_threshold` (default 0.65, per item):

| Zone | Contact offset | Power | Arc |
|------|---------------|-------|-----|
| Inner | 0 → threshold | 80–130 px (pop) | 160–220 px (high) |
| Outer | threshold → 1 | 180–340 px (flat) | 25–70 px (low) |

Values interpolated linearly within each zone. Hard discontinuity at the
threshold: just past it snaps from a short pop to a long flat launch.

### Direction

`angle = math.atan2(coin.y − contactY, coin.x − contactX)` — from the
contact point to the coin's centre. This is what the **red trajectory
preview** line also computes, so aim and shot always match.

### Wall Bounce (`entities/coin.lua` → `Coin:launch`)

- Bounds passed at launch: `boardX + coin.radius, boardY + coin.radius,
  boardW − 2·radius, boardH − 2·radius` (edge-based, so the disc touches
  the wall rather than the centre reaching it).
- **Start-position clamp**: at launch, `ox/oy` are clamped into bounds
  first, so a coin resting exactly against a wall (from a prior bounce clamp)
  never produces `t ≤ 0` and silently escapes.
- **Wall-crossing time**: `t ≥ 0` accepted (was `> 0`) on all four walls,
  so a coin sitting on a wall reflects immediately.
- Single-bounce model: one reflection computed analytically; remaining
  trajectory after reflection is clamped inside bounds. Applies to all coin
  types uniformly.
- `bounceX / bounceY` stored for the two-phase arc animation.

---

## Scoring (`states/game/flip.lua` → `resolveFlip`)

### Zone Values

The target area in the upper board has three concentric rectangular zones:

| Zone | Points | Color |
|------|--------|-------|
| Blue (outer) | 1 | `#3380D9` |
| Yellow (middle) | 2 | `#F5CC1A` |
| Red (centre) | 3 | `#D92E24` |

### Zone Detection

Edge-based: zone triggers when any part of the coin's disc touches the zone
boundary (`inset = zone_constant − coin.radius`, clamped to ≥ 0).

### Score Formula

```
gain = max(1, floor(POINTS[zone] × tierMult × multiplier × chainMult × scoreMult))
```

- `tierMult` — from `data/coin_tiers.lua` (1.0 / 0.75 / 0.5 / 0.25)
- `multiplier` — the current chain multiplier (increments on each scoring flip)
- `chainMult` — `CHAIN_BONUS[depth]` = `{[0]=1, [1]=2, [2]=10, [3]=100}`
- `scoreMult` — `coin.scoreMult or 1` (5 for golden coins)

### Misses

- **White zone** (on board, outside all scored zones): coin stays live,
  tier bumps, chain multiplier resets to 1.
- **Off board**: same as white miss.

---

## Chain Multiplier & Hot Streak (`states/game.lua` + `states/game/render_hud.lua`)

- Every scoring flip increments `self.multiplier` by 1.
- Every miss resets `self.multiplier` to 1.
- **Hot streak**: 3 consecutive scoring flips (any coin, any zone) fills 3
  pip indicators in the sidebar. On the 4th+ hit `bonusReady = true`.
- **Bonus Ready**: the next scoring flip scores an additional `gain × 29`
  marbles and clears the streak.
- The chain multiplier gold badge in the sidebar bounces on increment
  (`multBounce` animation, 0.28 s).

---

## Chain Reactions (`states/game/flip.lua` → `fireFlip` / `tryChainFlip`)

When a coin lands, `tryChainFlip` checks every other non-flipping coin for
overlap with the landing radius. Any touching coin is immediately launched
via `fireFlip` at `depth + 1`.

- **Depth 0**: player's click.
- **Depth ≥ 1**: chain reactions. `chainMult` gives bonus points.
- **No depth cap on chain propagation**: every landed coin (player-flipped,
  chain-activated, egg-spawned) calls `tryChainFlip`. The `coin.flipping`
  flag prevents infinite cycles.
- **Contact point for chain hits**: computed from the target coin's near side
  (`target.x − dx·invD·tr·0.8`), always strictly inside the disc even when
  two coins land on top of each other (`d ≈ 0`).

---

## Egg Split / Coin Multiplication (`states/game/flip.lua` + `states/game/spawn.lua`)

Spawn gate (all conditions must be true):
1. `depth > 0` — a chain hit, not the player's initial flip.
2. `depth <= CHAIN_SPAWN_MAX_DEPTH` (= 1) — hard cap at the first chain hop.
3. `coin.itemType == "egg"` — only eggs split.
4. `not coin.isSpawned` — spawned coins never themselves multiply.

On split, `spawnCoinsAt` creates one bonus coin (with ≤ 6 px scatter) at the
egg's landing point. That coin immediately launches with the **same angle,
power, arc, and item** the egg had, so it visibly flies out in the same
direction. On landing it can itself knock other coins via `tryChainFlip`.

Spawned coins have `isSpawned = true`; they can trigger further chain
reactions but cannot trigger further egg splits.

---

## Trajectory Preview (`states/game/render_board.lua`)

- Toggle with the **PREVIEW ON/OFF** button at the bottom of the sidebar,
  or via `[Space]`-click in the sidebar region.
- When enabled and a coin is highlighted: draws a flat red line from the
  coin's centre to the computed landing point, plus a bullseye target circle.
- Uses the same `resolveShot` + `atan2(coin − armedDot)` calculation as the
  actual `fireFlip`, so the line always matches the real shot.

---

## Input Bindings (`states/game.lua`)

| Key / Action | Effect |
|-------------|--------|
| Left-click (board) | Fire the highlighted coin |
| Left-click (sidebar preview button) | Toggle trajectory preview |
| A / ← | Cycle conflict selection left |
| D / → | Cycle conflict selection right |
| T | Toggle tool (circle ↔ triangle) |
| G | Toggle region debug overlay |
| R | Restart the current floor |
| M | Return to the map |
| Escape | Quit |

---

## HUD Sidebar (`states/game/render_hud.lua`)

Four stacked cards in the left parchment panel:

| Card | Content |
|------|---------|
| Floor Info | House name, floor number (1–3), next threshold |
| Marble Progress | Current marble count, progress bar, chain multiplier badge |
| Hot Streak | 3 pip indicators; "BONUS READY!" text when armed |
| Active Cards | Scrollable list of modifier cards (`ui/card_panel.lua`) |

Preview toggle button pinned to the bottom of the panel.

---

## Active Cards UI (`ui/card.lua`, `ui/card_panel.lua`)

- `CardPanel` holds a list of `Card` objects.
- Each card renders as a banner row with: a left colour block (rank/suit for
  bicycle cards; icon for monster cards), card name, and description text.
- Cards are placeholder data in `Game:enter`; the card system is not yet
  connected to gameplay effects.
- `cardPanel:setRegion(x, y, w)` is called each frame by `render_hud` to slot
  the panel inside the ACTIVE CARDS card region.

---

## Floor Progression (`states/game.lua`, `states/game/config.lua`)

| Floor | Marble threshold |
|-------|-----------------|
| 1 | 20 |
| 2 | 60 |
| 3 | 120 |

Floor advancement is tracked but automatic floor transition is not yet
implemented — the progress bar fills and stops. Three floors total
(`NUM_FLOORS = 3`).

---

## Services, Map & Future Systems

| File | Status | Notes |
|------|--------|-------|
| `states/map.lua` | Working | 3 clickable houses; sequential unlock; click launches `Game:enter(nil, houseName)` |
| `services.lua` | Stub | Global service locator; `Services.update(dt)` called each frame |
| `components/marbles/bank.lua` | Implemented, not wired | Global marble bank with deposit/spend/accrue/save |
| `components/buildings/manager.lua` | Stub | Building upgrade manager shell |
| `data/buildings.lua` | Data only | Building definitions |
| `data/cards.lua` | Data only | Card definitions |
| `helpers/probability.lua` | Utility | `weightedPick`, `flipCoin`, `lerp` |
| `tests/smoke.lua` | Runnable | `lovec . --test` smoke test; run with `--test` flag |

---

## Key Constants to Know (`states/game/config.lua`)

| Constant | Value | Meaning |
|----------|-------|---------|
| `TOOL_R_FACTOR` | 1.5 | Tool radius = this × coin radius |
| `COIN_RADIUS_AT_390W` | 24 | Base coin radius in pixels at 390 px width |
| `POINTS` | red=3, yellow=2, blue=1 | Zone base point values |
| `CHAIN_BONUS` | [0]=1,[1]=2,[2]=10,[3]=100 | Per-depth chain multipliers |
| `CHAIN_SPAWN_MAX_DEPTH` | 1 | Max depth at which eggs split |
| `MIN_BOARD_COINS` | 6 | Replenish trigger threshold |
| `TARGET_BOARD_COINS` | 8 | Replenish target count |
| `FLOOR_THRESHOLDS` | 20/60/120 | Marbles needed per floor |
| `NUM_FLOORS` | 3 | Total floors per house |
| `PANEL_W` | 220 | Left sidebar width (px) |

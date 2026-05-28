-- tests/smoke.lua
-- Headless smoke test. Invoked via `lovec . --test`.
-- Verifies:
--   (1) every source file parses (loadfile == luajit -bl coverage)
--   (2) state machine + map basics
--   (3) Game state: coin scatter + 4-tier ring scoring + tap-on-coin input
--   (4) Coin:launch closed-form arc math (per FLIP_PHYSICS_SPEC)
--
-- Runs inside LOVE (lovec), so `love` is real. No stubs needed.

local M = {}

local function newCounter() return { pass = 0, fail = 0 } end

local function check(c, name, ok, info)
  if ok then
    c.pass = c.pass + 1
    print("  PASS  " .. name)
  else
    c.fail = c.fail + 1
    print("  FAIL  " .. name .. (info ~= nil and ("   " .. tostring(info)) or ""))
  end
end

local SOURCES = {
  "main.lua",
  "conf.lua",
  "statemachine.lua",
  "services.lua",
  "lib/classic.lua",
  "lib/tween.lua",
  "entities/coin.lua",
  "states/map.lua",
  "states/game.lua",
  "components/buildings/manager.lua",
  "components/marbles/bank.lua",
  "data/buildings.lua",
  "data/cards.lua",
  "data/flip_items.lua",
  "data/coin_tiers.lua",
  "helpers/probability.lua",
}

function M.run()
  print("")
  print("===== COIN FLIPPER SMOKE TEST =====")
  local c = newCounter()

  -- ---------- (1) Syntax check every source file ----------
  print("\n[1/4] Syntax check (love.filesystem.load == luajit -bl coverage):")
  for _, src in ipairs(SOURCES) do
    local fn, err = love.filesystem.load(src)
    check(c, "parse " .. src, fn ~= nil, err)
  end
  if c.fail > 0 then
    print(string.format("\n%d parse failures -- aborting before logic tests.", c.fail))
    print(string.format("RESULT: %d passed, %d failed", c.pass, c.fail))
    return c.fail
  end

  -- ---------- (2) State machine + map basics ----------
  print("\n[2/4] State machine + map basics:")
  local StateMachine = require("statemachine")
  local Map          = require("states.map")
  local Game         = require("states.game")
  Map._reset()
  StateMachine._reset()
  StateMachine.register("map",  Map)
  StateMachine.register("game", Game)

  StateMachine.switch("map")
  check(c, "1a state == 'map'",       StateMachine.current() == "map")
  check(c, "1b three houses",         #Map._houses == 3)
  check(c, "1c house 1 unlocked",     Map._isUnlocked(1))
  check(c, "1d house 2 locked",       not Map._isUnlocked(2))
  check(c, "1e house 3 locked",       not Map._isUnlocked(3))

  local h2 = Map._houses[2]
  Map:mousepressed(h2.x, h2.y, 1)
  check(c, "2 locked-house click ignored", StateMachine.current() == "map")

  local h1 = Map._houses[1]
  Map:mousepressed(h1.x, h1.y, 1)
  check(c, "3a state == 'game'",            StateMachine.current() == "game")
  check(c, "3b houseName forwarded",        Game.houseName == "Grandma")
  check(c, "3c initial marbles == 0",       Game.marbles == 0)
  check(c, "3d initial multiplier == 1",    Game.multiplier == 1)
  check(c, "3e no active coin at start",    Game.activeCoin == nil)

  -- ---------- (3) Game: scatter + ring scoring + tap-on-coin ----------
  print("\n[3/4] Game: coin scatter + 4-tier scoring + tap-on-coin input:")
  local L = Game._L

  -- Scatter: should produce a non-zero number of coins, up to the requested 5.
  -- (rejection sampling may give fewer in tight layouts, but at least 1).
  check(c, "4a at least 1 coin scattered",  #Game.coins >= 1)
  check(c, "4b at most 5 coins scattered",  #Game.coins <= 5)
  -- All scattered coins start un-used and not flipping.
  local allFresh = true
  for i = 1, #Game.coins do
    if Game.coins[i].used or Game.coins[i].flipping then allFresh = false; break end
  end
  check(c, "4c all coins start unused and not flipping", allFresh)

  -- 5: 4-tier ring resolution against synthetic landings.
  --    We poke marbles/multiplier directly via the exposed _resolveFlip.
  --    The 2nd arg is the coin (used for tier multiplier + degradation).
  --    Use a fresh tier-0 coin so each scoring assertion matches the old
  --    pre-degradation behavior (tier 0 mult = 1.0).
  local CoinClass = require("entities.coin")
  local sCoin     = CoinClass(0, 0, 14)  -- tier 0
  Game.marbles, Game.multiplier = 0, 1

  -- 5a) Bullseye: dead center of target.
  local ring, gain = Game._resolveFlip(Game, sCoin, L.targetCX, L.targetCY)
  check(c, "5a bullseye ring detected",     ring == "bull",   "ring=" .. ring)
  check(c, "5b bullseye gain = 5*1 = 5",    gain == 5,        "gain=" .. gain)
  check(c, "5c marbles == 5",               Game.marbles == 5)
  check(c, "5d multiplier == 2",            Game.multiplier == 2)

  -- 5b) Middle ring: between bullR and middleR.
  local midR = (L.bullR + L.middleR) / 2
  ring, gain = Game._resolveFlip(Game, sCoin, L.targetCX + midR, L.targetCY)
  check(c, "5e middle ring detected",       ring == "middle", "ring=" .. ring)
  check(c, "5f middle gain = 3*2 = 6",      gain == 6,        "gain=" .. gain)
  check(c, "5g marbles == 11",              Game.marbles == 11)
  check(c, "5h multiplier == 3",            Game.multiplier == 3)

  -- 5c) Outer ring: between middleR and outerR.
  local outR = (L.middleR + L.outerR) / 2
  ring, gain = Game._resolveFlip(Game, sCoin, L.targetCX + outR, L.targetCY)
  check(c, "5i outer ring detected",        ring == "outer",  "ring=" .. ring)
  check(c, "5j outer gain = 1*3 = 3",       gain == 3,        "gain=" .. gain)
  check(c, "5k marbles == 14",              Game.marbles == 14)
  check(c, "5l multiplier == 4",            Game.multiplier == 4)

  -- 5d) On-board but outside target: no score, no chain change. Tier bumps.
  --     Use a fresh tier-0 coin so we can observe tier transitions cleanly.
  local missCoin = CoinClass(0, 0, 14)
  check(c, "5d.0 fresh coin starts at tier 0", missCoin.tier == 0)
  local marblesBefore, multBefore = Game.marbles, Game.multiplier
  ring, gain = Game._resolveFlip(Game, missCoin, L.boardX + 4, L.boardY + 4)
  check(c, "5m on-board off-target detected", ring == "on_board_miss")
  check(c, "5n on-board off-target: marbles unchanged", Game.marbles == marblesBefore)
  check(c, "5o on-board off-target: mult unchanged",    Game.multiplier == multBefore)
  check(c, "5o.1 on-board miss bumps tier to 1",        missCoin.tier == 1)

  -- 5e) Off-board: chain resets, marbles unchanged, tier bumps further.
  marblesBefore = Game.marbles
  ring, gain = Game._resolveFlip(Game, missCoin, -100, -100)
  check(c, "5p off-board detected",         ring == "off_board_miss")
  check(c, "5q off-board: marbles unchanged", Game.marbles == marblesBefore)
  check(c, "5r off-board: mult reset to 1",   Game.multiplier == 1)
  check(c, "5r.1 off-board miss bumps tier to 2", missCoin.tier == 2)
  -- One more miss -> tier 3 (cap).
  Game._resolveFlip(Game, missCoin, L.boardX + 4, L.boardY + 4)
  check(c, "5r.2 third miss bumps tier to 3", missCoin.tier == 3)
  -- Further misses must NOT exceed 3.
  Game._resolveFlip(Game, missCoin, L.boardX + 4, L.boardY + 4)
  Game._resolveFlip(Game, missCoin, -100, -100)
  check(c, "5r.3 tier caps at 3 (no overflow)", missCoin.tier == 3)

  -- 5f) Tier-aware scoring: tier-2 coin (mult 0.50) hitting bull at chain=1
  --     should produce floor(5 * 0.5 * 1) = 2.
  local t2Coin = CoinClass(0, 0, 14)
  t2Coin.tier = 2
  Game.marbles, Game.multiplier = 0, 1
  ring, gain = Game._resolveFlip(Game, t2Coin, L.targetCX, L.targetCY)
  check(c, "5s tier-2 bull at chain=1: gain == floor(5*0.5*1) == 2",
    ring == "bull" and gain == 2,
    "gain=" .. gain)

  -- 5g) Tier-2 bull at chain=3 -> floor(5 * 0.5 * 3) = 7.
  t2Coin.tier = 2
  Game.marbles, Game.multiplier = 0, 3
  ring, gain = Game._resolveFlip(Game, t2Coin, L.targetCX, L.targetCY)
  check(c, "5t tier-2 bull at chain=3: gain == floor(5*0.5*3) == 7",
    ring == "bull" and gain == 7,
    "gain=" .. gain)

  -- 5h) Min-1 floor: tier-3 coin (mult 0.25) hitting OUTER (1 point) at
  --     chain=1 -> floor(1 * 0.25 * 1) = 0, but min-1 kicks in.
  local t3Coin = CoinClass(0, 0, 14)
  t3Coin.tier = 3
  Game.marbles, Game.multiplier = 0, 1
  ring, gain = Game._resolveFlip(Game, t3Coin, L.targetCX + outR, L.targetCY)
  check(c, "5u tier-3 outer at chain=1: min-1 floor applies (gain == 1)",
    ring == "outer" and gain == 1,
    "gain=" .. gain)

  -- 5i) Scoring hits do NOT degrade the coin (tier stays).
  local stayCoin = CoinClass(0, 0, 14)
  stayCoin.tier = 1
  Game.marbles, Game.multiplier = 0, 1
  Game._resolveFlip(Game, stayCoin, L.targetCX, L.targetCY)
  check(c, "5v scoring hit does NOT increment tier (stays at 1)",
    stayCoin.tier == 1)

  -- 6: tap-on-coin input model.
  -- Re-enter to get a fresh scatter and clean state.
  Game:enter(nil, "Grandma")
  check(c, "6a fresh enter: no active coin",  Game.activeCoin == nil)

  -- Tap somewhere with no coin -> nothing happens.
  Game:mousepressed(1, 1, 1)
  check(c, "6b tap off any coin: no active",  Game.activeCoin == nil)

  -- Place the tool so its TOP rim dot lands on the coin's exact center.
  -- Top dot is at (clickX, clickY - toolR), so click at (coin.x, coin.y + toolR).
  local firstCoin = Game.coins[1]
  local toolR     = L.toolR
  Game:mousepressed(firstCoin.x, firstCoin.y + toolR, 1)
  check(c, "6c top dot on coin center: it flips",  firstCoin.flipping)
  check(c, "6d activeCoin == that coin",           Game.activeCoin == firstCoin)
  -- Dot at coin center -> center region -> fly straight UP.
  check(c, "6e center contact launches straight up",
    math.abs(firstCoin.targetX - firstCoin.x) < 1e-6
    and firstCoin.targetY < firstCoin.y)

  -- While a coin is in flight, contacting another coin should do nothing.
  if #Game.coins >= 2 then
    local secondCoin = Game.coins[2]
    Game:mousepressed(secondCoin.x, secondCoin.y + toolR, 1)
    check(c, "6f contact during flight: ignored", not secondCoin.flipping)
    check(c, "6g activeCoin unchanged",           Game.activeCoin == firstCoin)
  end

  -- Tick time forward past the flight duration to let it land.
  for i = 1, 30 do Game:update(0.05) end   -- 1.5s
  check(c, "6h after landing: coin no longer flipping", not firstCoin.flipping)
  check(c, "6j after landing: activeCoin cleared",      Game.activeCoin == nil)
  -- Fix 2: coin.used is only set on scoring rings (bull/middle/outer).
  -- Derive whether this shot scored from the landing distance to the target.
  local ldx = firstCoin.targetX - L.targetCX
  local ldy = firstCoin.targetY - L.targetCY
  local shotScored = (ldx * ldx + ldy * ldy) <= (L.outerR * L.outerR)
  check(c, "6i scored -> coin.used; miss -> coin still live",
    firstCoin.used == shotScored)
  check(c, "6k contains() is inverse of used",
    firstCoin:contains(firstCoin.x, firstCoin.y) == (not firstCoin.used))

  -- 7: 6-dot collider + auto-arm vs A/D conflict cycling.
  --    Geometries below use the post-halving toolR (L.coinR * 0.5 = 12px).
  --    Single dot in coin -> auto-arm (click fires). 2+ dots in SAME coin
  --    -> conflict; first dot selected by default; A/D (and arrow keys)
  --    cycle the selection. Click fires the CURRENTLY SELECTED dot.
  Game:enter(nil, "Grandma")
  local toolR2 = Game._L.toolR
  local Coin   = require("entities.coin")
  -- New schema: each entry is a preallocated {idx=, coin=} pair table.
  local scratchConflict = {}
  for i = 1, 6 do scratchConflict[i] = { idx = 0, coin = nil } end

  -- 7a) Single (dot, coin) pair inside coin. Coin (400, 400, r=14); tool at
  --     (400, 420): top dot at (400, 408) dist 8 in; everything else out.
  local lone = { Coin(400, 400, 14) }
  local hitCount =
    Game._findPressedCoin(lone, 400, 420, toolR2, scratchConflict)
  check(c, "7a single dot inside coin -> count = 1 (auto-arm)",
    hitCount == 1)
  check(c, "7a.1 pair[1] = (dot 1 = top, lone[1])",
    scratchConflict[1].idx == 1 and scratchConflict[1].coin == lone[1])

  -- 7b) Tool far from any coin -> 0.
  local farCount = Game._findPressedCoin(lone, 800, 800, toolR2, scratchConflict)
  check(c, "7b tool far from any coin -> count = 0", farCount == 0)

  -- 7c) 2-dot conflict on the SAME coin. Coin at (405, 400, r=12); tool at
  --     (400, 412): top (400, 400) dist 5 in; top-right (410.4, 406) dist
  --     ~8.06 in; rest out.
  local conflicted = { Coin(405, 400, 12) }
  local cCount =
    Game._findPressedCoin(conflicted, 400, 412, toolR2, scratchConflict)
  check(c, "7c same-coin conflict: count == 2", cCount == 2)
  check(c, "7d pair[1] = (dot 1, coin) and pair[2] = (dot 2, coin)",
    scratchConflict[1].idx == 1 and scratchConflict[1].coin == conflicted[1]
    and scratchConflict[2].idx == 2 and scratchConflict[2].coin == conflicted[1])

  -- 7e) End-to-end auto-arm: single-dot click fires.
  Game:enter(nil, "Grandma")
  local edgeCoin = Game.coins[1]
  edgeCoin.x, edgeCoin.y, edgeCoin.radius = 400, 400, 14
  Game.coins = { edgeCoin }
  Game:mousepressed(400, 420, 1)
  check(c, "7e single-dot click flips the coin", edgeCoin.flipping)
  check(c, "7f single-dot click sets activeCoin",
    Game.activeCoin == edgeCoin)

  -- 7g) Click with NO dot inside any coin does nothing.
  Game:enter(nil, "Grandma")
  local lonely = Game.coins[1]
  lonely.x, lonely.y, lonely.radius = 400, 400, 14
  Game.coins = { lonely }
  Game:mousepressed(800, 800, 1)
  check(c, "7g click far from any coin does NOT flip",
    not lonely.flipping and Game.activeCoin == nil)

  -- 7h) Conflict state via _refreshHover (no click yet). Same geometry as 7c.
  Game:enter(nil, "Grandma")
  local conCoin = Game.coins[1]
  conCoin.x, conCoin.y, conCoin.radius = 405, 400, 12
  Game.coins = { conCoin }
  Game.toolX, Game.toolY = 400, 412
  Game:_refreshHover()
  check(c, "7h conflict established: count=2, idx=1 (default)",
    Game.conflictCount == 2 and Game.conflictIdx == 1)
  check(c, "7i conflict list: [(1, coin), (2, coin)]",
    Game.conflictDots[1].idx == 1 and Game.conflictDots[1].coin == conCoin
    and Game.conflictDots[2].idx == 2 and Game.conflictDots[2].coin == conCoin)
  check(c, "7j armedDotIdx = pair[idx].idx = 1 (top); hoveredCoin = conCoin",
    Game.armedDotIdx == 1 and Game.hoveredCoin == conCoin)

  -- 7k) D cycles forward (idx 1 -> 2).
  Game:keypressed("d")
  check(c, "7k D: idx 1 -> 2, armed = 2 (top-right)",
    Game.conflictIdx == 2 and Game.armedDotIdx == 2)
  -- 7l) D wraps (idx 2 -> 1).
  Game:keypressed("d")
  check(c, "7l D wraps: idx 2 -> 1", Game.conflictIdx == 1)
  -- 7m) A wraps backward (idx 1 -> 2).
  Game:keypressed("a")
  check(c, "7m A wraps backward: idx 1 -> 2", Game.conflictIdx == 2)
  -- 7n) Left arrow steps backward (idx 2 -> 1).
  Game:keypressed("left")
  check(c, "7n left arrow: idx 2 -> 1", Game.conflictIdx == 1)
  -- 7o) Right arrow steps forward (idx 1 -> 2).
  Game:keypressed("right")
  check(c, "7o right arrow: idx 1 -> 2", Game.conflictIdx == 2)

  -- 7p) Click confirms current selection (idx 2 = top-right dot).
  --     Top-right dot at (410.4, 406). Coin at (405, 400, r=12).
  --     offX = (410.4 - 405)/12 = 0.45, offY = (406 - 400)/12 = 0.5
  --     -> bottom-right region cell -> angle = -3pi/4 (up-LEFT).
  --     Expected: targetX < coin.x and targetY < coin.y.
  Game:mousepressed(400, 412, 1)
  check(c, "7p click fires currently selected dot (coin flipping)",
    conCoin.flipping and Game.activeCoin == conCoin)
  check(c, "7q click used top-right dot (coin flies UP-LEFT)",
    conCoin.targetX < conCoin.x and conCoin.targetY < conCoin.y)

  -- 7r) A/D outside conflict are ignored entirely.
  Game:enter(nil, "Grandma")
  local stillCoin = Game.coins[1]
  stillCoin.x, stillCoin.y, stillCoin.radius = 400, 400, 14
  Game.coins = { stillCoin }
  Game.toolX, Game.toolY = 50, 50
  Game:_refreshHover()
  check(c, "7r far-away tool: no hover, no conflict",
    Game.hoveredCoin == nil and Game.conflictCount == 0)
  Game:keypressed("a"); Game:keypressed("d")
  Game:keypressed("left"); Game:keypressed("right")
  check(c, "7s A/D outside conflict: no flip, no state change",
    not stillCoin.flipping and Game.activeCoin == nil)

  -- 7t) Conflict that EVAPORATES (tool moves away) clears without firing.
  Game:enter(nil, "Grandma")
  local moveCoin = Game.coins[1]
  moveCoin.x, moveCoin.y, moveCoin.radius = 405, 400, 12
  Game.coins = { moveCoin }
  Game.toolX, Game.toolY = 400, 412
  Game:_refreshHover()
  check(c, "7t mid-step: in conflict before move",
    Game.hoveredCoin == moveCoin and Game.conflictCount == 2)
  Game.toolX, Game.toolY = 50, 50
  Game:_refreshHover()
  check(c, "7u after move: conflict cleared, no auto-fire",
    Game.hoveredCoin == nil and Game.conflictCount == 0
    and Game.armedDotIdx == nil and not moveCoin.flipping)

  -- 7v) Selection PRESERVATION: tool jitter that keeps the same conflict
  --     dots in the same coin should preserve the player's A/D choice.
  Game:enter(nil, "Grandma")
  local jitterCoin = Game.coins[1]
  jitterCoin.x, jitterCoin.y, jitterCoin.radius = 405, 400, 12
  Game.coins = { jitterCoin }
  Game.toolX, Game.toolY = 400, 412
  Game:_refreshHover()
  Game:keypressed("d")  -- now idx=2 (top-right selected)
  check(c, "7v pre-jitter: idx == 2 (player chose top-right)",
    Game.conflictIdx == 2)
  -- Jitter the tool by 1px; same conflict dots should still be in.
  Game.toolX, Game.toolY = 401, 412
  Game:_refreshHover()
  check(c, "7w post-jitter: idx STILL == 2 (selection preserved)",
    Game.conflictCount == 2 and Game.conflictIdx == 2
    and Game.armedDotIdx == 2)

  -- 7x) MULTI-COIN conflict: one dot in each of two different coins.
  --     coin1 at (400, 388, r=8) -- top dot lands at its center.
  --     coin2 at (400, 412, r=8) -- bottom dot lands at its center.
  --     With toolR=12 and r=8, the other 4 dots are >= 12px from any coin
  --     center -> out. Result: 2 pairs across 2 different coins.
  local multi = { Coin(400, 388, 8), Coin(400, 412, 8) }
  local mCount = Game._findPressedCoin(multi, 400, 400, toolR2, scratchConflict)
  check(c, "7x multi-coin: count == 2", mCount == 2)
  check(c, "7y multi-coin pair[1] = (dot 1, coin1)",
    scratchConflict[1].idx == 1 and scratchConflict[1].coin == multi[1])
  check(c, "7z multi-coin pair[2] = (dot 4, coin2)",
    scratchConflict[2].idx == 4 and scratchConflict[2].coin == multi[2])

  -- 7aa) End-to-end multi-coin conflict via Game state. Default selection
  --      is pair[1] -> coin1 armed; A/D cycles to pair[2] -> coin2 armed;
  --      click fires whichever pair's coin is currently selected.
  Game:enter(nil, "Grandma")
  Game.coins = { Coin(400, 388, 8), Coin(400, 412, 8) }
  Game.toolX, Game.toolY = 400, 400
  Game:_refreshHover()
  check(c, "7aa multi-coin in-game: count=2, idx=1, hoveredCoin = coin1",
    Game.conflictCount == 2 and Game.conflictIdx == 1
    and Game.hoveredCoin == Game.coins[1] and Game.armedDotIdx == 1)

  -- D cycles to pair[2] = (dot 4, coin2)
  Game:keypressed("d")
  check(c, "7bb D cycles to pair[2]: hoveredCoin = coin2, armed = dot 4",
    Game.conflictIdx == 2 and Game.hoveredCoin == Game.coins[2]
    and Game.armedDotIdx == 4)

  -- Click fires the SELECTED pair's coin (coin2), not coin1.
  local coin1Ref, coin2Ref = Game.coins[1], Game.coins[2]
  Game:mousepressed(400, 400, 1)
  check(c, "7cc click fires SELECTED pair's coin (coin2)",
    coin2Ref.flipping and Game.activeCoin == coin2Ref)
  check(c, "7dd coin1 untouched (other pair was not selected)",
    not coin1Ref.flipping)

  -- ---------- (4) Region map + circle press + power/arc curves ----------
  print("\n[4/4] Coin:regionAt + Coin:pressedBy + Coin:launch:")
  local Coin   = require("entities.coin")
  local Items  = require("data.flip_items")
  local cos    = math.cos
  local sin    = math.sin
  local abs    = math.abs
  local pi     = math.pi
  local coinItem = Items.byId("coin")
  local panItem  = Items.byId("pancakes")
  check(c, "items: Coin tuning loaded",     coinItem ~= nil)
  check(c, "items: Pancakes tuning loaded", panItem  ~= nil)
  check(c, "items: Coin has regions table", coinItem and coinItem.regions ~= nil)
  check(c, "items: Coin has 9 regions (3x3 grid)",
    coinItem and #coinItem.regions == 9)
  -- Two-zone invariants: outer launches outpace inner pops; pops out-arc launches.
  check(c, "items: Coin zone_threshold == 0.65",
    coinItem.zone_threshold == 0.65)
  check(c, "items: Coin outer_power_edge > inner_power_edge (launch > pop)",
    coinItem.outer_power_edge > coinItem.inner_power_edge)
  check(c, "items: Coin inner_arc_center > outer_arc_edge (pop > launch arc)",
    coinItem.inner_arc_center > coinItem.outer_arc_edge)
  check(c, "items: Coin SNAP -- outer_power_center > inner_power_edge",
    coinItem.outer_power_center > coinItem.inner_power_edge)
  check(c, "items: Pancakes outer_power_edge > inner_power_edge",
    panItem.outer_power_edge > panItem.inner_power_edge)
  check(c, "items: Pancakes inner_arc_center > outer_arc_edge",
    panItem.inner_arc_center > panItem.outer_arc_edge)

  local function makeCoin() return Coin(200, 600, 14) end
  local function approxEq(a, b) return abs(a - b) < 1e-6 end

  -- 8a) Center region -> straight UP.
  local k = makeCoin()
  local r = k:regionAt(0, 0, coinItem)
  check(c, "8a center region: angle = -pi/2 (up)",
    r and approxEq(r.angle, -pi/2))

  -- 8b) Left column -> fly RIGHT.
  r = k:regionAt(-0.7, 0, coinItem)
  check(c, "8b left-column region: angle = 0 (right)",
    r and approxEq(r.angle, 0))

  -- 8c) Right column -> fly LEFT.
  r = k:regionAt(0.7, 0, coinItem)
  check(c, "8c right-column region: angle = pi (left)",
    r and approxEq(r.angle, pi))

  -- 8d) Bottom row -> fly UP.
  r = k:regionAt(0, 0.7, coinItem)
  check(c, "8d bottom-center region: angle = -pi/2 (up)",
    r and approxEq(r.angle, -pi/2))

  -- 8e) Top row -> fly DOWN.
  r = k:regionAt(0, -0.7, coinItem)
  check(c, "8e top-center region: angle = pi/2 (down)",
    r and approxEq(r.angle, pi/2))

  -- 8f) Corners combine: bottom-left tap -> up-right.
  r = k:regionAt(-0.7, 0.7, coinItem)
  check(c, "8f bottom-left region: angle = -pi/4 (up-right)",
    r and approxEq(r.angle, -pi/4))

  -- 8g) Out-of-disc clamp.
  r = k:regionAt(5, 0, coinItem)
  check(c, "8g out-of-disc tap clamps to a valid region (left direction)",
    r and approxEq(r.angle, pi))

  -- 8h) pressedBy: point at coin center -> offDist == 0.
  k = makeCoin()
  local ox, oy, od = k:pressedBy(200, 600)
  check(c, "8h pressedBy at center: offDist == 0",
    ox and approxEq(od, 0))

  -- 8i) pressedBy: point inside coin off-center -> valid (offX, offY, offDist).
  --     7px right of center, R=14 -> offX=0.5, offY=0, offDist=0.5.
  k = makeCoin()
  ox, oy, od = k:pressedBy(207, 600)
  check(c, "8i pressedBy off-center inside: returns (0.5, 0, 0.5)",
    ox and approxEq(ox, 0.5) and approxEq(oy, 0) and approxEq(od, 0.5))

  -- 8j) pressedBy clearly outside the coin -> nil.
  k = makeCoin()
  check(c, "8j pressedBy outside coin -> nil",
    k:pressedBy(220, 600) == nil)

  -- 8k) pressedBy at the EXACT edge (d^2 == r^2) -> nil (strict less-than).
  k = makeCoin()
  check(c, "8k pressedBy at exact edge -> nil",
    k:pressedBy(214, 600) == nil)

  -- 8k.1) Just inside the edge -> hit, offDist near 1.
  k = makeCoin()
  ox, oy, od = k:pressedBy(213.5, 600)
  check(c, "8k.1 pressedBy just inside edge -> hit, offDist near 1",
    ox and od and od < 1 and od > 0.95)

  -- 8l) pressedBy on a flipping coin -> nil.
  k = makeCoin(); k.flipping = true
  check(c, "8l pressedBy flipping coin -> nil", k:pressedBy(200, 600) == nil)
  -- 8m) pressedBy on a used coin -> nil.
  k = makeCoin(); k.used = true
  check(c, "8m pressedBy used coin -> nil",     k:pressedBy(200, 600) == nil)

  -- 8n) launch(angle, power, arc, item, cb) lands at coin + (cos*power, sin*power).
  k = makeCoin()
  local lx, ly = k:launch(0, 200, 60, coinItem)
  check(c, "8n launch(angle=0, power=200) lands 200px right",
    abs(lx - 400) < 0.01 and abs(ly - 600) < 0.01)

  -- 8o) Explicit arc is stored on the coin (not pulled from item.base_arc).
  k = makeCoin(); k:launch(0, 200, 60,  coinItem)
  check(c, "8o launch stores passed arc (60)",  approxEq(k.arcHeight, 60))
  k = makeCoin(); k:launch(0, 200, 222, coinItem)
  check(c, "8p launch stores passed arc (222)", approxEq(k.arcHeight, 222))

  -- 8q) Determinism: same args -> same landing.
  k = makeCoin(); local a1, b1 = k:launch(1.234, 175, 90, coinItem)
  k = makeCoin(); local a2, b2 = k:launch(1.234, 175, 90, coinItem)
  check(c, "8q determinism: same (angle, power, arc) -> same landing",
    a1 == a2 and b1 == b2)

  -- 8r) Per-item flight_time still drives flight duration.
  k = makeCoin(); k:launch(0, 100, 60, coinItem); local coinFt = k.flightDuration
  k = makeCoin(); k:launch(0, 100, 60, panItem);  local panFt  = k.flightDuration
  check(c, "8r Pancakes flight_time > Coin flight_time", panFt > coinFt)

  -- 8s) NO AUTO-AIM: launch offset depends only on (angle, power).
  local kA = Coin(100, 100, 14); local ax, ay = kA:launch(pi/4, 100, 60, coinItem)
  local kB = Coin(500, 300, 14); local bx, by = kB:launch(pi/4, 100, 60, coinItem)
  check(c, "8s no auto-aim: launch offset is identical regardless of coin pos",
    abs((ax - 100) - (bx - 500)) < 1e-6 and abs((ay - 100) - (by - 300)) < 1e-6)

  -- 8t) Coin:contains() hit detection (unchanged behavior).
  k = makeCoin()
  check(c, "8t contains: center tap hits",       k:contains(200, 600))
  check(c, "8u contains: near-edge tap hits",    k:contains(212, 600))
  check(c, "8v contains: distant tap misses",    not k:contains(300, 600))
  k.flipping = true
  check(c, "8w contains: false while flipping",  not k:contains(200, 600))
  k.flipping = false; k.used = true
  check(c, "8x contains: false when used",       not k:contains(200, 600))

  -- 9: Two-zone power/arc model with hard discontinuity at zone_threshold.
  --    Dead center pops short and high; just inside threshold still pops;
  --    just outside threshold snaps to a long, flat launch.
  print("\n[bonus] resolveShot two-zone model (snap at 0.65):")
  local rp, ra = Game._resolveShot(coinItem, 0.0)
  check(c, "9a dead center: power == 80, arc == 220",
    rp == 80 and ra == 220,
    string.format("got power=%.2f arc=%.2f", rp, ra))

  rp, ra = Game._resolveShot(coinItem, 0.64)
  check(c, "9b just inside threshold (0.64): power ~ 129, arc ~ 161",
    abs(rp - 129.23) < 0.5 and abs(ra - 160.92) < 0.5,
    string.format("got power=%.2f arc=%.2f", rp, ra))

  rp, ra = Game._resolveShot(coinItem, 0.65)
  check(c, "9c snap at threshold (0.65): power == 180, arc == 70",
    rp == 180 and ra == 70,
    string.format("got power=%.2f arc=%.2f", rp, ra))

  -- 9d) Edge: maximum launch.
  rp, ra = Game._resolveShot(coinItem, 1.0)
  check(c, "9d at edge (1.0): power == 340, arc == 25",
    rp == 340 and ra == 25)

  -- 9e) The snap is a real discontinuity: across the threshold, power JUMPS
  --     up by >= 40 (from ~130 to 180) and arc DROPS by >= 80 (from ~160 to 70).
  local p_below, a_below = Game._resolveShot(coinItem, 0.6499)
  local p_above, a_above = Game._resolveShot(coinItem, 0.6500)
  check(c, "9e snap: power jumps up across threshold (>= 40px)",
    (p_above - p_below) >= 40,
    string.format("below=%.2f above=%.2f", p_below, p_above))
  check(c, "9f snap: arc drops across threshold (>= 80px)",
    (a_below - a_above) >= 80,
    string.format("below=%.2f above=%.2f", a_below, a_above))

  print("")
  print(string.format("RESULT: %d passed, %d failed", c.pass, c.fail))
  print("===================================")
  return c.fail
end

return M

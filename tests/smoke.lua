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
  Game.marbles, Game.multiplier = 0, 1

  -- 5a) Bullseye: dead center of target.
  local ring, gain = Game._resolveFlip(Game, L.targetCX, L.targetCY)
  check(c, "5a bullseye ring detected",     ring == "bull",   "ring=" .. ring)
  check(c, "5b bullseye gain = 5*1 = 5",    gain == 5,        "gain=" .. gain)
  check(c, "5c marbles == 5",               Game.marbles == 5)
  check(c, "5d multiplier == 2",            Game.multiplier == 2)

  -- 5b) Middle ring: between bullR and middleR.
  local midR = (L.bullR + L.middleR) / 2
  ring, gain = Game._resolveFlip(Game, L.targetCX + midR, L.targetCY)
  check(c, "5e middle ring detected",       ring == "middle", "ring=" .. ring)
  check(c, "5f middle gain = 3*2 = 6",      gain == 6,        "gain=" .. gain)
  check(c, "5g marbles == 11",              Game.marbles == 11)
  check(c, "5h multiplier == 3",            Game.multiplier == 3)

  -- 5c) Outer ring: between middleR and outerR.
  local outR = (L.middleR + L.outerR) / 2
  ring, gain = Game._resolveFlip(Game, L.targetCX + outR, L.targetCY)
  check(c, "5i outer ring detected",        ring == "outer",  "ring=" .. ring)
  check(c, "5j outer gain = 1*3 = 3",       gain == 3,        "gain=" .. gain)
  check(c, "5k marbles == 14",              Game.marbles == 14)
  check(c, "5l multiplier == 4",            Game.multiplier == 4)

  -- 5d) On-board but outside target: no score, no chain change.
  --     Pick a board corner well outside the outer ring.
  local marblesBefore, multBefore = Game.marbles, Game.multiplier
  ring, gain = Game._resolveFlip(Game, L.boardX + 4, L.boardY + 4)
  check(c, "5m on-board off-target detected", ring == "on_board_miss")
  check(c, "5n on-board off-target: marbles unchanged", Game.marbles == marblesBefore)
  check(c, "5o on-board off-target: mult unchanged",    Game.multiplier == multBefore)

  -- 5e) Off-board: chain resets, marbles unchanged.
  marblesBefore = Game.marbles
  ring, gain = Game._resolveFlip(Game, -100, -100)
  check(c, "5p off-board detected",         ring == "off_board_miss")
  check(c, "5q off-board: marbles unchanged", Game.marbles == marblesBefore)
  check(c, "5r off-board: mult reset to 1",   Game.multiplier == 1)

  -- 6: tap-on-coin input model.
  -- Re-enter to get a fresh scatter and clean state.
  Game:enter(nil, "Grandma")
  check(c, "6a fresh enter: no active coin",  Game.activeCoin == nil)

  -- Tap somewhere with no coin -> nothing happens.
  Game:mousepressed(1, 1, 1)
  check(c, "6b tap off any coin: no active",  Game.activeCoin == nil)

  -- Tap on a coin -> it becomes the active flipping coin.
  local firstCoin = Game.coins[1]
  Game:mousepressed(firstCoin.x, firstCoin.y, 1)
  check(c, "6c tap on coin: it flips",        firstCoin.flipping)
  check(c, "6d activeCoin == that coin",      Game.activeCoin == firstCoin)
  -- Center tap -> center region -> fly straight UP at base_power pixels.
  -- Verify the launch direction came from the region, not from any auto-aim.
  check(c, "6e center tap launches straight up",
    math.abs(firstCoin.targetX - firstCoin.x) < 1e-6
    and firstCoin.targetY < firstCoin.y)

  -- While a coin is in flight, tapping another coin should do nothing.
  if #Game.coins >= 2 then
    local secondCoin = Game.coins[2]
    Game:mousepressed(secondCoin.x, secondCoin.y, 1)
    check(c, "6f tap during flight: ignored", not secondCoin.flipping)
    check(c, "6g activeCoin unchanged",       Game.activeCoin == firstCoin)
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

  -- 7: Tool circle IS the collider. A left-click while ANY part of the grey
  --    circle touches a coin must flip that coin -- even if the click point
  --    itself is outside the coin's own outline.
  Game:enter(nil, "Grandma")
  local toolR  = Game._L.toolR
  local Coin   = require("entities.coin")
  -- 7a) Direct test of the helper: grazing edge (centers exactly sumR apart)
  --     counts as a hit, just beyond counts as a miss.
  local lone   = { Coin(400, 400, 14) }
  local grazeX = 400 + 14 + toolR        -- centers exactly coin.r + toolR apart
  check(c, "7a findPressedCoin: grazing edge (exactly sumR apart) hits",
    Game._findPressedCoin(lone, grazeX, 400, toolR) == lone[1])
  check(c, "7b findPressedCoin: 1px beyond sumR -> nil",
    Game._findPressedCoin(lone, grazeX + 1, 400, toolR) == nil)
  -- 7c) End-to-end: click position OUTSIDE the coin's own outline but inside
  --     the tool overlap zone still flips the coin via Game:mousepressed.
  local edgeCoin = Game.coins[1]
  -- Park the test coin at a known spot away from neighbors so the nearest-
  -- center pick is unambiguous; rebuild the coins list around it.
  edgeCoin.x, edgeCoin.y = 400, 400
  Game.coins = { edgeCoin }
  local nudge  = (toolR + edgeCoin.radius) * 0.5  -- well inside overlap, well outside coin radius
  local clickX = edgeCoin.x + edgeCoin.radius + (toolR * 0.5)
  check(c, "7c click point is OUTSIDE coin's own outline (sanity)",
    (clickX - edgeCoin.x) > edgeCoin.radius)
  Game:mousepressed(clickX, edgeCoin.y, 1)
  check(c, "7d outside-outline circle press flips the coin",
    edgeCoin.flipping)
  check(c, "7e outside-outline circle press sets activeCoin",
    Game.activeCoin == edgeCoin)

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
  -- Curve invariants: edge press = farther, center press = higher.
  check(c, "items: Coin edge_power > center_power",
    coinItem.edge_power > coinItem.center_power)
  check(c, "items: Coin center_arc > edge_arc",
    coinItem.center_arc > coinItem.edge_arc)
  check(c, "items: Pancakes edge_power > center_power",
    panItem.edge_power > panItem.center_power)
  check(c, "items: Pancakes center_arc > edge_arc",
    panItem.center_arc > panItem.edge_arc)

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

  -- 8h) pressedBy: direct hit registers, returns center offset.
  k = makeCoin()
  local ox, oy, od = k:pressedBy(200, 600, 18)
  check(c, "8h pressedBy dead-center: offDist == 0",
    ox and od and approxEq(od, 0))

  -- 8i) pressedBy: tool OUTSIDE the coin's own radius but overlapping still
  -- registers a press (the whole point of the new circle test).
  -- Coin at (200, 600) r=14; tool at (220, 600) r=18 -> centers 20 apart,
  -- sumR = 32, so they overlap. The tool sits 6px outside the coin's outline.
  k = makeCoin()
  ox, oy, od = k:pressedBy(220, 600, 18)
  check(c, "8i pressedBy: tool outside coin radius still registers (overlap)",
    ox ~= nil)

  -- 8j) Clamp: when the tool is outside the coin outline, offDist saturates at 1.
  check(c, "8j pressedBy: outside-outline contact clamps offDist to 1",
    od and approxEq(od, 1))

  -- 8k) pressedBy: no overlap -> nil.
  k = makeCoin()
  ox, oy, od = k:pressedBy(300, 600, 18)  -- 100 apart, sumR=32
  check(c, "8k pressedBy: clearly outside -> nil", ox == nil)

  -- 8k.1) Grazing edge: centers EXACTLY (coin.r + toolR) apart counts as hit.
  k = makeCoin()
  local grazeOk = k:pressedBy(200 + 14 + 18, 600, 18)
  check(c, "8k.1 pressedBy: grazing edge (exactly sumR apart) hits",
    grazeOk ~= nil)
  -- 8k.2) Just beyond -> nil.
  check(c, "8k.2 pressedBy: 1px beyond sumR -> nil",
    k:pressedBy(200 + 14 + 18 + 1, 600, 18) == nil)

  -- 8l) pressedBy: flipping/used coins are not pressable.
  k = makeCoin(); k.flipping = true
  check(c, "8l pressedBy: flipping coin -> nil", k:pressedBy(200, 600, 18) == nil)
  k = makeCoin(); k.used = true
  check(c, "8m pressedBy: used coin -> nil",     k:pressedBy(200, 600, 18) == nil)

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

  print("")
  print(string.format("RESULT: %d passed, %d failed", c.pass, c.fail))
  print("===================================")
  return c.fail
end

return M

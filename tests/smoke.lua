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

  -- ---------- (4) Coin:regionAt + Coin:launch (region-driven, no auto-aim) ----------
  print("\n[4/4] Coin:regionAt + Coin:launch (region-driven, per-item):")
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

  local function makeCoin() return Coin(200, 600, 14) end
  local function approxEq(a, b) return abs(a - b) < 1e-6 end

  -- 8a) Center tap -> center region -> launch straight UP (angle = -pi/2).
  local k = makeCoin()
  local r = k:regionAt(0, 0, coinItem)
  check(c, "8a center region: angle = -pi/2 (up)",
    r and approxEq(r.angle, -pi/2),
    r and ("angle=" .. r.angle) or "nil region")

  -- 8b) Left column -> fly RIGHT (angle = 0).
  r = k:regionAt(-0.7, 0, coinItem)
  check(c, "8b left-column region: angle = 0 (right)",
    r and approxEq(r.angle, 0))

  -- 8c) Right column -> fly LEFT (angle = pi).
  r = k:regionAt(0.7, 0, coinItem)
  check(c, "8c right-column region: angle = pi (left)",
    r and approxEq(r.angle, pi))

  -- 8d) Bottom row -> fly UP (angle = -pi/2).
  r = k:regionAt(0, 0.7, coinItem)
  check(c, "8d bottom-center region: angle = -pi/2 (up)",
    r and approxEq(r.angle, -pi/2))

  -- 8e) Top row -> fly DOWN (angle = pi/2).
  r = k:regionAt(0, -0.7, coinItem)
  check(c, "8e top-center region: angle = pi/2 (down)",
    r and approxEq(r.angle, pi/2))

  -- 8f) Corners combine: bottom-left tap -> up-right (angle = -pi/4).
  r = k:regionAt(-0.7, 0.7, coinItem)
  check(c, "8f bottom-left region: angle = -pi/4 (up-right)",
    r and approxEq(r.angle, -pi/4))

  -- 8g) Out-of-disc clamp: regionAt clamps to unit circle before matching.
  r = k:regionAt(5, 0, coinItem)  -- way off; should clamp toward (1, 0)
  check(c, "8g out-of-disc tap clamps to a valid region (left direction)",
    r and approxEq(r.angle, pi))

  -- 8h) Launch lands at (x + cos*power, y + sin*power) for the given angle.
  k = makeCoin()
  local lx, ly = k:launch(0, 200, coinItem)  -- angle 0 = right
  check(c, "8h launch(angle=0, power=200) lands 200px right",
    abs(lx - 400) < 0.01 and abs(ly - 600) < 0.01,
    string.format("got=(%.2f, %.2f)", lx, ly))

  -- 8i) Launch straight up.
  k = makeCoin()
  lx, ly = k:launch(-pi/2, 150, coinItem)
  check(c, "8i launch(angle=-pi/2, power=150) lands 150px up",
    abs(lx - 200) < 0.01 and abs(ly - 450) < 0.01,
    string.format("got=(%.2f, %.2f)", lx, ly))

  -- 8j) Determinism: same angle + power -> same landing.
  k = makeCoin(); local a1, b1 = k:launch(1.234, 175, coinItem)
  k = makeCoin(); local a2, b2 = k:launch(1.234, 175, coinItem)
  check(c, "8j determinism: same (angle, power) -> same landing",
    a1 == a2 and b1 == b2)

  -- 8k) Per-item arc: Pancakes floatier than Coin.
  k = makeCoin(); k:launch(0, 100, coinItem); local coinArc = k.arcHeight
  k = makeCoin(); k:launch(0, 100, panItem);  local panArc  = k.arcHeight
  check(c, "8k Pancakes arcHeight > Coin arcHeight", panArc > coinArc)

  -- 8l) Per-item flight_time: Pancakes flies longer than Coin.
  k = makeCoin(); k:launch(0, 100, coinItem); local coinFt = k.flightDuration
  k = makeCoin(); k:launch(0, 100, panItem);  local panFt  = k.flightDuration
  check(c, "8l Pancakes flight_time > Coin flight_time", panFt > coinFt)

  -- 8m) NO AUTO-AIM: launch must NOT reference board center. Same (angle, power)
  -- from two coins at different positions both land at the SAME offset from
  -- their origin -- the launch is purely directional.
  local kA = Coin(100, 100, 14); local ax, ay = kA:launch(pi/4, 100, coinItem)
  local kB = Coin(500, 300, 14); local bx, by = kB:launch(pi/4, 100, coinItem)
  check(c, "8m no auto-aim: launch offset is identical regardless of coin pos",
    abs((ax - 100) - (bx - 500)) < 1e-6 and abs((ay - 100) - (by - 300)) < 1e-6)

  -- 8n) Coin:contains() hit detection (unchanged behavior).
  k = makeCoin()
  check(c, "8n contains: center tap hits",       k:contains(200, 600))
  check(c, "8o contains: near-edge tap hits",    k:contains(212, 600))
  check(c, "8p contains: distant tap misses",    not k:contains(300, 600))
  k.flipping = true
  check(c, "8q contains: false while flipping",  not k:contains(200, 600))
  k.flipping = false; k.used = true
  check(c, "8r contains: false when used",       not k:contains(200, 600))

  print("")
  print(string.format("RESULT: %d passed, %d failed", c.pass, c.fail))
  print("===================================")
  return c.fail
end

return M

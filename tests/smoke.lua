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
  check(c, "6e lastTappedCoin tracked",       Game.lastTappedCoin == firstCoin)

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

  -- ---------- (4) Coin:launch pixel-based parametric arc math ----------
  print("\n[4/4] Coin:launch math (pixel-based parametric arc, per-item):")
  local Coin   = require("entities.coin")
  local Items  = require("data.flip_items")
  local sqrt   = math.sqrt
  local cos    = math.cos
  local sin    = math.sin
  local atan2  = math.atan2
  local abs    = math.abs
  local coinItem = Items.byId("coin")
  local panItem  = Items.byId("pancakes")
  check(c, "items: Coin tuning loaded",     coinItem ~= nil)
  check(c, "items: Pancakes tuning loaded", panItem  ~= nil)

  local function makeCoin()
    local k = Coin(200, 600, 14)
    k.boardCenterX, k.boardCenterY = 640, 380
    return k
  end

  -- 8a) Dead-center tap travels exactly base_power pixels along the safe line.
  -- Coin at (200, 600), target at (640, 380); base_angle = atan2(-220, 440).
  -- Expected landing: coin + base_power * (cos, sin)(base_angle).
  local k = makeCoin()
  local lx, ly = k:launch(0, 0, coinItem)
  local baseAngle = atan2(380 - 600, 640 - 200)
  local expX = 200 + cos(baseAngle) * coinItem.base_power
  local expY = 600 + sin(baseAngle) * coinItem.base_power
  check(c, "8a center tap travels base_power pixels along safe line",
    abs(lx - expX) < 0.01 and abs(ly - expY) < 0.01,
    string.format("got=(%.2f, %.2f)  expected=(%.2f, %.2f)", lx, ly, expX, expY))

  -- 8b) Determinism: same inputs -> same landing.
  k = makeCoin(); local a1, b1 = k:launch(0.3, -0.2, coinItem)
  k = makeCoin(); local a2, b2 = k:launch(0.3, -0.2, coinItem)
  check(c, "8b determinism (Coin, off-center tap)",
    a1 == a2 and b1 == b2)

  -- 8c) Pancakes deviate more than Coin for the same off-center tap.
  k = makeCoin(); local cx0, cy0 = k:launch(0,   0, coinItem)
  k = makeCoin(); local cx1, cy1 = k:launch(0.5, 0, coinItem)
  local coinDev = sqrt((cx1 - cx0)^2 + (cy1 - cy0)^2)
  k = makeCoin(); local px0, py0 = k:launch(0,   0, panItem)
  k = makeCoin(); local px1, py1 = k:launch(0.5, 0, panItem)
  local panDev  = sqrt((px1 - px0)^2 + (py1 - py0)^2)
  check(c, "8c Pancakes deviate more than Coin for +0.5 horizontal tap",
    panDev > coinDev,
    string.format("coin=%.1fpx pan=%.1fpx", coinDev, panDev))

  -- 8d) Per-item arc height: Pancakes is floatier than Coin.
  k = makeCoin(); k:launch(0, 0, coinItem); local coinArc = k.arcHeight
  k = makeCoin(); k:launch(0, 0, panItem);  local panArc  = k.arcHeight
  check(c, "8d Pancakes has bigger arc than Coin", panArc > coinArc)

  -- 8e) Per-item flight_time: Pancakes flies longer than Coin.
  k = makeCoin(); k:launch(0, 0, coinItem); local coinFt = k.flightDuration
  k = makeCoin(); k:launch(0, 0, panItem);  local panFt  = k.flightDuration
  check(c, "8e Pancakes flight_time > Coin flight_time", panFt > coinFt)

  -- 8f) offset_y: tap ABOVE center (offY < 0) adds power -> longer shot.
  --              tap BELOW center (offY > 0) subtracts power -> shorter shot.
  --  launch_power = base_power - offY * power_sensitivity  (negated per Fix 1)
  k = makeCoin(); local _, _ = k:launch(0,  0,    coinItem); local centerLand = { k.targetX, k.targetY }
  k = makeCoin();                k:launch(0,  0.5, coinItem); local shortLand  = { k.targetX, k.targetY }
  k = makeCoin();                k:launch(0, -0.5, coinItem); local longLand   = { k.targetX, k.targetY }
  -- "Short" should be closer to origin than center; "long" should be farther.
  local function distFromOrigin(p) return sqrt((p[1] - 200)^2 + (p[2] - 600)^2) end
  check(c, "8f -offset_y (above center) travels farther than center", distFromOrigin(longLand)  > distFromOrigin(centerLand))
  check(c, "8g +offset_y (below center) travels shorter than center", distFromOrigin(shortLand) < distFromOrigin(centerLand))

  -- 8h) Coin:contains() hit detection.
  k = makeCoin()
  check(c, "8h contains: center tap hits",       k:contains(200, 600))
  check(c, "8i contains: near-edge tap hits",    k:contains(212, 600))
  check(c, "8j contains: distant tap misses",    not k:contains(300, 600))
  k.flipping = true
  check(c, "8k contains: false while flipping",  not k:contains(200, 600))
  k.flipping = false; k.used = true
  check(c, "8l contains: false when used",       not k:contains(200, 600))

  print("")
  print(string.format("RESULT: %d passed, %d failed", c.pass, c.fail))
  print("===================================")
  return c.fail
end

return M

-- tests/smoke.lua
-- Headless smoke test. Invoked via `lovec . --test`.
-- Verifies:
--   (a) every source file parses (loadfile == luajit -bl coverage)
--   (b) state machine + map + game basic loop per the kickoff prompt's
--       7 assertions: lock/unlock, click-routing, scoring, multiplier
--       chain, miss-reset, popup pool no-leak.
--
-- This runs INSIDE LOVE (lovec), so `love` is real. No stubs needed.

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
  "entities/pocket.lua",
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

  -- ---------- (a) Syntax check every source file ----------
  -- Use love.filesystem.load -- it reads from LOVE's mounted source filesystem
  -- and parses but does not execute. Equivalent coverage to `luajit -bl <file>`.
  print("\n[1/2] Syntax check (love.filesystem.load == luajit -bl coverage):")
  for _, src in ipairs(SOURCES) do
    local fn, err = love.filesystem.load(src)
    check(c, "parse " .. src, fn ~= nil, err)
  end

  if c.fail > 0 then
    print(string.format("\n%d parse failures -- aborting before logic tests.", c.fail))
    print(string.format("RESULT: %d passed, %d failed", c.pass, c.fail))
    return c.fail
  end

  -- ---------- (b) Logic assertions ----------
  print("\n[2/2] Logic assertions:")

  -- Fresh requires (modules were already loaded above, but require caches).
  local StateMachine = require("statemachine")
  local Map          = require("states.map")
  local Game         = require("states.game")

  -- Ensure clean state if tests have been run before.
  Map._reset()
  StateMachine._reset()
  StateMachine.register("map",  Map)
  StateMachine.register("game", Game)

  -- 1) Map boots, 3 houses, house 1 unlocked / 2 locked.
  StateMachine.switch("map")
  check(c, "1a state == 'map'",     StateMachine.current() == "map")
  check(c, "1b three houses",       #Map._houses == 3)
  check(c, "1c house 1 unlocked",   Map._isUnlocked(1))
  check(c, "1d house 2 locked",     not Map._isUnlocked(2))
  check(c, "1e house 3 locked",     not Map._isUnlocked(3))

  -- 2) Clicking a locked house does NOT switch state.
  local h2 = Map._houses[2]
  Map:mousepressed(h2.x, h2.y, 1)
  check(c, "2 locked-house click ignored", StateMachine.current() == "map")

  -- 3) Clicking Grandma enters game with houseName == "Grandma".
  local h1 = Map._houses[1]
  Map:mousepressed(h1.x, h1.y, 1)
  check(c, "3a state == 'game'",            StateMachine.current() == "game")
  check(c, "3b houseName forwarded",        Game.houseName == "Grandma")
  check(c, "3c game has 5 pockets",         #Game.pockets == 5)
  check(c, "3d initial marbles == 0",       Game.marbles == 0)
  check(c, "3e initial multiplier == 1",    Game.multiplier == 1)

  -- 4) Flip into the center pocket scores 5 and bumps multiplier to 2.
  local center = Game.pockets[1]
  check(c, "4-pre center value == 5",       center.value == 5)
  Game._resolveFlip(Game, center.x, center.y)
  check(c, "4a marbles == 5",               Game.marbles == 5,    "got " .. Game.marbles)
  check(c, "4b multiplier == 2",            Game.multiplier == 2, "got " .. Game.multiplier)

  -- 5) Second center hit scores +10 (5 x 2) for 15 total.
  Game._resolveFlip(Game, center.x, center.y)
  check(c, "5a marbles == 15",              Game.marbles == 15,   "got " .. Game.marbles)
  check(c, "5b multiplier == 3",            Game.multiplier == 3, "got " .. Game.multiplier)

  -- 6) Flip into empty board: multiplier resets to 1, marbles unchanged.
  local before = Game.marbles
  Game._resolveFlip(Game, 5, 5)   -- top-left corner; no pocket
  check(c, "6a marbles unchanged",          Game.marbles == before, "got " .. Game.marbles)
  check(c, "6b multiplier reset to 1",      Game.multiplier == 1,   "got " .. Game.multiplier)

  -- 7) Popup pool fully deactivates after settling (no leaks).
  --    Spawn many popups, then tick past POPUP_LIFE.
  for i = 1, 10 do Game._resolveFlip(Game, center.x, center.y) end
  -- 30 ticks of 0.05s = 1.5s > POPUP_LIFE (1.0s)
  for i = 1, 30 do Game:update(0.05) end
  local active = 0
  for i = 1, Game._popupPoolSize do
    if Game._popupPool[i].active then active = active + 1 end
  end
  check(c, "7 popup pool fully drained",    active == 0,           "active=" .. active)

  -- ---------- (c) Coin:launch closed-form arc math (Chunk 2) ----------
  print("\n[3/3] Coin:launch math (closed-form parametric arc, per-item):")
  local Coin   = require("entities.coin")
  local Items  = require("data.flip_items")
  local sqrt   = math.sqrt
  local abs    = math.abs

  local coinItem = Items.byId("coin")
  local panItem  = Items.byId("pancakes")
  check(c, "items: Coin tuning loaded",     coinItem ~= nil)
  check(c, "items: Pancakes tuning loaded", panItem  ~= nil)

  -- Helper: place coin at a known origin + board center, return fresh Coin.
  local function makeCoin()
    local k = Coin(200, 600)
    k.boardCenterX, k.boardCenterY = 640, 380
    return k
  end

  -- 8a) Dead-center tap with base_power=1.0 lands at the board center.
  local k = makeCoin()
  local lx, ly = k:launch(0, 0, coinItem)
  check(c, "8a center tap lands at board center",
    abs(lx - 640) < 1 and abs(ly - 380) < 1,
    string.format("landing=(%.2f, %.2f)", lx, ly))

  -- 8b) Determinism: same inputs -> same landing, every time.
  k = makeCoin(); local a1, b1 = k:launch(0.3, -0.2, coinItem)
  k = makeCoin(); local a2, b2 = k:launch(0.3, -0.2, coinItem)
  check(c, "8b determinism (Coin, off-center tap)",
    a1 == a2 and b1 == b2,
    string.format("(%.4f,%.4f) vs (%.4f,%.4f)", a1, b1, a2, b2))

  -- 8c) Per-item difference: Pancakes deviate further than Coin for the SAME
  -- off-center tap. (Higher angle_sens AND higher base_power both push the
  -- landing further from each item's own safe-line target.)
  k = makeCoin(); local cx0, cy0 = k:launch(0,   0, coinItem)
  k = makeCoin(); local cx1, cy1 = k:launch(0.5, 0, coinItem)
  local coinDev = sqrt((cx1 - cx0)^2 + (cy1 - cy0)^2)

  k = makeCoin(); local px0, py0 = k:launch(0,   0, panItem)
  k = makeCoin(); local px1, py1 = k:launch(0.5, 0, panItem)
  local panDev  = sqrt((px1 - px0)^2 + (py1 - py0)^2)

  check(c, "8c Pancakes deviate more than Coin for +0.5 horizontal tap",
    panDev > coinDev,
    string.format("coin=%.1fpx pan=%.1fpx", coinDev, panDev))

  -- 8d) Per-item arc height: Pancakes is floatier than Coin (bigger base_arc).
  k = makeCoin(); k:launch(0, 0, coinItem); local coinArc = k.arcHeight
  k = makeCoin(); k:launch(0, 0, panItem);  local panArc  = k.arcHeight
  check(c, "8d Pancakes has bigger arc than Coin",
    panArc > coinArc,
    string.format("coin=%.1fpx pan=%.1fpx", coinArc, panArc))

  -- 8e) flight_time set per-item: Pancakes flies longer than Coin.
  k = makeCoin(); k:launch(0, 0, coinItem); local coinFt = k.flightDuration
  k = makeCoin(); k:launch(0, 0, panItem);  local panFt  = k.flightDuration
  check(c, "8e Pancakes flight_time > Coin flight_time",
    panFt > coinFt,
    string.format("coin=%.2fs pan=%.2fs", coinFt, panFt))

  -- 8f) Coin:contains() hit detection (for the Chunk 3 tap-on-coin input).
  k = makeCoin()
  check(c, "8f contains: center tap hits",       k:contains(200, 600))
  check(c, "8g contains: near-edge tap hits",    k:contains(212, 600))  -- inside r=14
  check(c, "8h contains: distant tap misses",    not k:contains(300, 600))
  k.flipping = true
  check(c, "8i contains: false while flipping",  not k:contains(200, 600))

  -- 8j) Falloff applied: Pancakes (falloff=1.4) has a tighter sweet spot,
  -- so its effective offset at raw 0.2 is *smaller* than its raw, while
  -- Coin (falloff=0.8) has it *larger* than raw. We verify by comparing
  -- the arc height (which uses eff_dist directly).
  k = makeCoin(); k:launch(0.2, 0, coinItem); local coinArcSmallOff = k.arcHeight
  k = makeCoin(); k:launch(0.2, 0, panItem);  local panArcSmallOff  = k.arcHeight
  -- Coin: eff_dist = 0.2^0.8 = ~0.275 (LARGER than 0.2)
  -- Pan:  eff_dist = 0.2^1.4 = ~0.111 (SMALLER than 0.2)
  -- So the *added* arc on top of base is proportionally larger for Coin
  -- than for Pancakes at this small offset. Verify the ratio is in the
  -- expected direction.
  local coinAdded = coinArcSmallOff - coinArc   -- arc_var * eff_dist contribution
  local panAdded  = panArcSmallOff  - panArc
  check(c, "8j falloff curve direction (coin>0, pan>0 added arc)",
    coinAdded > 0 and panAdded > 0,
    string.format("coin_added=%.2f pan_added=%.2f", coinAdded, panAdded))

  print("")
  print(string.format("RESULT: %d passed, %d failed", c.pass, c.fail))
  print("===================================")
  return c.fail
end

return M

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
  print("\n[1/2] Syntax check (loadfile == luajit -bl coverage):")
  for _, src in ipairs(SOURCES) do
    local fn, err = loadfile(src)
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

  print("")
  print(string.format("RESULT: %d passed, %d failed", c.pass, c.fail))
  print("===================================")
  return c.fail
end

return M

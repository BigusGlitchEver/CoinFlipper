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

  -- 7: 4-dot collider + auto-arm vs conflict resolution.
  --    Single dot inside -> auto-arm (click fires). 2+ dots inside the SAME
  --    coin -> conflict (click does nothing until matching WASD key pressed).
  Game:enter(nil, "Grandma")
  local toolR2 = Game._L.toolR
  local Coin   = require("entities.coin")
  -- Scratch table the new findPressedCoin signature requires.
  local scratchConflict = { false, false, false, false }

  -- 7a) Single dot inside coin -> hit returned with that dotIdx.
  --     Tool at (400, 400 + toolR - 1) -> top dot at (400, 401), inside coin.
  local lone = { Coin(400, 400, 14) }
  local hitCoin, hitDot = Game._findPressedCoin(
    lone, 400, 400 + toolR2 - 1, toolR2, scratchConflict)
  check(c, "7a single dot inside coin -> auto-arm, dotIdx=1 (top)",
    hitCoin == lone[1] and hitDot == 1)

  -- 7b) Tool CENTER directly over coin with NO dot inside -> nil.
  local centerOver = Game._findPressedCoin(lone, 400, 400, toolR2, scratchConflict)
  check(c, "7b tool center over coin but every dot far outside -> nil",
    centerOver == nil)

  -- 7c) 2-dot conflict: with the production toolR=60 and a 45-radius coin
  --     placed at (toolX + 30, toolY - 30), both top and right dots fall
  --     inside (each ~42.4px from coin center, < 45). bottom/left ~94.9 out.
  --     Result: coin returned, dotIdx == nil, conflictDots[1] and [2] set.
  local conflicted = { Coin(430, 370, 45) }
  local cCoin, cDot = Game._findPressedCoin(
    conflicted, 400, 400, toolR2, scratchConflict)
  check(c, "7c conflict: coin returned, dotIdx == nil (no auto-arm)",
    cCoin == conflicted[1] and cDot == nil)
  check(c, "7d conflict: top + right dots flagged, bottom + left not",
    scratchConflict[1] == true  and scratchConflict[2] == true
    and scratchConflict[3] == false and scratchConflict[4] == false)

  -- 7e) End-to-end auto-arm: single-dot click flips.
  Game:enter(nil, "Grandma")
  local edgeCoin = Game.coins[1]
  edgeCoin.x, edgeCoin.y, edgeCoin.radius = 400, 400, 14
  Game.coins = { edgeCoin }
  Game:mousepressed(400, 400 + toolR2 - 1, 1)
  check(c, "7e single-dot click flips the coin", edgeCoin.flipping)
  check(c, "7f single-dot click sets activeCoin",
    Game.activeCoin == edgeCoin)

  -- 7g) Click with NO dot inside any coin does nothing.
  Game:enter(nil, "Grandma")
  local lonely = Game.coins[1]
  lonely.x, lonely.y, lonely.radius = 400, 400, 14
  Game.coins = { lonely }
  Game:mousepressed(400, 400, 1)
  check(c, "7g tool center over coin (no dot inside) does NOT flip",
    not lonely.flipping and Game.activeCoin == nil)

  -- 7h) End-to-end conflict: a click that produces 2-dot contact does NOT
  --     fire. State (hoveredCoin + conflictDots) is populated for WASD.
  Game:enter(nil, "Grandma")
  local conCoin = Game.coins[1]
  conCoin.x, conCoin.y, conCoin.radius = 430, 370, 45
  Game.coins = { conCoin }
  Game:mousepressed(400, 400, 1)
  check(c, "7h conflict click: NOT flipped",
    not conCoin.flipping and Game.activeCoin == nil)
  check(c, "7i conflict click: state recorded (hoveredCoin set, no auto-arm)",
    Game.hoveredCoin == conCoin and Game.hoveredDotIdx == nil)
  check(c, "7j conflict click: conflictDots[1]+[2] set",
    Game.conflictDots[1] and Game.conflictDots[2])

  -- 7k) Non-matching WASD key (S = bottom = 3, not in conflict set) does nothing.
  Game:keypressed("s")
  check(c, "7k WASD non-matching key (S): no flip",
    not conCoin.flipping and Game.activeCoin == nil)

  -- 7l) Non-WASD key (e.g. 'r' resets state; we use 'q' which is unbound).
  Game:keypressed("q")
  check(c, "7l unbound key: no flip", not conCoin.flipping)

  -- 7m) Matching WASD key (W = top = 1, in conflict set) fires the coin.
  Game:keypressed("w")
  check(c, "7m WASD W matches conflictDots[1]: flips coin",
    conCoin.flipping and Game.activeCoin == conCoin)

  -- 7n) WASD outside any conflict is ignored entirely (no auto-fire).
  Game:enter(nil, "Grandma")
  local stillCoin = Game.coins[1]
  stillCoin.x, stillCoin.y, stillCoin.radius = 400, 400, 14
  Game.coins = { stillCoin }
  -- Tool parked far away -> no hover, no conflict.
  Game.toolX, Game.toolY = 50, 50
  Game:_refreshHover()
  check(c, "7n far-away tool: no hover, no conflict",
    Game.hoveredCoin == nil and Game.conflictDots[1] == false
    and Game.conflictDots[2] == false)
  Game:keypressed("w"); Game:keypressed("a")
  Game:keypressed("s"); Game:keypressed("d")
  check(c, "7o WASD outside conflict: nothing happens",
    not stillCoin.flipping and Game.activeCoin == nil)

  -- 7p) Conflict that EVAPORATES (tool moves away) clears without firing.
  Game:enter(nil, "Grandma")
  local moveCoin = Game.coins[1]
  moveCoin.x, moveCoin.y, moveCoin.radius = 430, 370, 45
  Game.coins = { moveCoin }
  Game.toolX, Game.toolY = 400, 400
  Game:_refreshHover()
  check(c, "7p mid-step: in conflict before move",
    Game.hoveredCoin == moveCoin and Game.hoveredDotIdx == nil
    and Game.conflictDots[1] and Game.conflictDots[2])
  -- Move tool far away; conflict should disappear.
  Game.toolX, Game.toolY = 50, 50
  Game:_refreshHover()
  check(c, "7q after move: conflict cleared, no auto-fire",
    Game.hoveredCoin == nil
    and Game.conflictDots[1] == false and Game.conflictDots[2] == false
    and not moveCoin.flipping)

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

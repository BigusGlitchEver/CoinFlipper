-- states/game/marble_event.lua
-- The Special Marble Event — a self-contained, removable feature module.
--
-- A glowing marble rolls diagonally across the board from one wall to the
-- opposite wall. While it travels, egg-coins rain down from the top: coins
-- that land in a scoring zone convert to points instantly (same formula as
-- flip.resolveFlip); coins that land on white space become normal live board
-- coins. The marble is purely cosmetic — it never collides with coins or
-- triggers chain reactions.
--
-- Public API:
--   M.trigger(self)       -- fire an event now (no-op if one is active)
--   M.update(self, dt)    -- per-frame sim + auto-trigger timer (cheap if idle)
--   M.draw(self)          -- draw marble + falling rain (cheap if idle)
--   M.onFloorStart()      -- reset per-floor state (call on enter / next floor)
--   M.isActive()          -- whether an event is currently running
--
-- All state lives in pre-allocated module-level tables; nothing is allocated
-- inside update() or draw(). (Landing a white-space coin necessarily creates a
-- Coin object — that is the same pattern spawn.lua uses to add a board coin.)

local L    = require("states.game.layout")
local Coin = require("entities.coin")

local lg     = love.graphics
local random = math.random
local floor  = math.floor
local max    = math.max
local sqrt   = math.sqrt

local M = {}

-- ---------- Tunables ----------
local MARBLE_SPEED   = 320     -- px/sec along the diagonal
local MARBLE_R       = 18      -- marble radius
local MIN_Y_FRAC     = 0.15    -- entry/exit Y stays within 15%..85% of height
local MAX_Y_FRAC     = 0.85
local MIN_Y_DIFF     = 0.20    -- entry/exit Y differ by >= 20% of height
local RAIN_MIN       = 20      -- coin count range, inclusive
local RAIN_MAX       = 30
local FALL_MIN       = 280     -- px/sec fall speed range
local FALL_MAX       = 380
local DRIFT          = 15      -- horizontal drift range: -DRIFT..+DRIFT px/sec
local AUTO_INTERVAL  = 30      -- seconds between auto-trigger rolls
local AUTO_CHANCE    = 0.10    -- chance per roll

-- Marble colors.
local MARBLE_FILL = { 0xFF/255, 0xE8/255, 0x7C/255 }  -- #FFE87C iridescent gold
-- Rain egg color: tier-0 amber-yellow #F0C040.
local RAIN_FILL   = { 0xF0/255, 0xC0/255, 0x40/255 }
local RAIN_LINE   = { 0x33/255, 0x33/255, 0x33/255 }

-- ---------- Pre-allocated state ----------
local POOL_SIZE = RAIN_MAX
local pool = {}            -- recycled rain-coin slots
for i = 1, POOL_SIZE do
  pool[i] = { active = false, x = 0, y = 0, targetY = 0, vx = 0, vy = 0, r = 0 }
end

local schedule = {}        -- pre-computed spawn times (seconds since start)
for i = 1, POOL_SIZE do schedule[i] = 0 end

local state = {
  active        = false,   -- event running (marble and/or rain still settling)
  marbleActive  = false,   -- marble still crossing the board
  firedThisFloor = false,  -- auto-trigger fires at most once per floor
  autoTimer     = 0,       -- accumulates toward AUTO_INTERVAL
  -- marble travel
  sx = 0, sy = 0, vx = 0, vy = 0, mx = 0, my = 0,
  travelTime = 0, elapsed = 0,
  -- rain scheduling
  coinCount = 0, nextIdx = 1, eggR = 0,
}

function M.isActive() return state.active end

-- ---------- Trigger ----------
function M.trigger(self)
  if state.active then return end   -- never overlap events

  local bx, by = L.boardX, L.boardY
  local bw, bh = L.boardW, L.boardH

  -- Direction: enter from one wall, exit the opposite.
  local fromLeft = random() < 0.5
  local sx = fromLeft and bx or (bx + bw)
  local ex = fromLeft and (bx + bw) or bx

  -- Entry/exit Y within the middle band, with a meaningful vertical gap.
  local span = MAX_Y_FRAC - MIN_Y_FRAC
  local sy = by + (MIN_Y_FRAC + random() * span) * bh
  local ey
  repeat
    ey = by + (MIN_Y_FRAC + random() * span) * bh
  until max(sy - ey, ey - sy) >= MIN_Y_DIFF * bh

  local dx, dy = ex - sx, ey - sy
  local dist   = sqrt(dx * dx + dy * dy)
  local travel = dist / MARBLE_SPEED

  state.sx, state.sy = sx, sy
  state.mx, state.my = sx, sy
  state.vx, state.vy = dx / travel, dy / travel
  state.travelTime   = travel
  state.elapsed      = 0

  -- Rain: pick the count, pre-compute the even spawn schedule.
  local count = random(RAIN_MIN, RAIN_MAX)
  state.coinCount = count
  state.nextIdx   = 1
  state.eggR      = L.coinR
  local interval  = travel / count
  for i = 1, count do schedule[i] = (i - 1) * interval end

  -- Clear the pool.
  for i = 1, POOL_SIZE do pool[i].active = false end

  state.firedThisFloor = true
  state.active         = true
  state.marbleActive   = true
end

-- ---------- Internal helpers ----------

-- Spawns one rain coin into a free pool slot.
local function spawnRainCoin()
  local r  = state.eggR
  local bx = L.boardX
  local bw = L.boardW
  for i = 1, POOL_SIZE do
    local s = pool[i]
    if not s.active then
      s.active  = true
      s.x       = bx + r + random() * (bw - 2 * r)
      s.y       = L.boardY                      -- top of the interior
      s.targetY = L.boardY + r + random() * (L.boardH - 2 * r)
      s.vx      = (random() * 2 - 1) * DRIFT
      s.vy      = FALL_MIN + random() * (FALL_MAX - FALL_MIN)
      s.r       = r
      return
    end
  end
end

-- Resolves a rain coin that has reached its landing point.
local function landRainCoin(self, s)
  s.active = false
  local r  = s.r
  -- Clamp final X inside the interior so a drifted coin never lands clipped.
  local x = s.x
  if x < L.boardX + r then x = L.boardX + r end
  if x > L.boardX + L.boardW - r then x = L.boardX + L.boardW - r end
  local y = s.targetY

  -- Zone scan in reverse (highest-value wins), centre-in-rect like resolveFlip.
  local zones = L.zones
  for i = #zones, 1, -1 do
    local z = zones[i]
    if x >= z.x and x <= z.x + z.w and y >= z.y and y <= z.y + z.h then
      -- Same formula as resolveFlip: tier 0 (mult 1), depth 0 (chain 1),
      -- scoreMult 1 -> points * self.multiplier.
      local gain = max(1, floor(z.points * (self.multiplier or 1)))
      self.floorMarbles = (self.floorMarbles or 0) + gain
      self.runMarbles   = (self.runMarbles   or 0) + gain
      self.scoreFlash   = 0.20   -- reuse existing score-burst feedback
      return
    end
  end

  -- White space: becomes a normal live egg board coin (split applies later).
  local c = Coin(x, y, r)
  c.itemType = "egg"
  c.tier     = 0
  self.coins[#self.coins + 1] = c
end

-- ---------- Per-frame update ----------
function M.update(self, dt)
  -- Auto-trigger roll (cheap; only while idle and not yet fired this floor).
  if not state.active then
    if not state.firedThisFloor then
      state.autoTimer = state.autoTimer + dt
      if state.autoTimer >= AUTO_INTERVAL then
        state.autoTimer = state.autoTimer - AUTO_INTERVAL
        if random() < AUTO_CHANCE then M.trigger(self) end
      end
    end
    if not state.active then return end   -- still idle: nothing to simulate
  end

  -- Advance the marble + spawn scheduled rain.
  if state.marbleActive then
    state.elapsed = state.elapsed + dt
    local e = state.elapsed
    state.mx = state.sx + state.vx * e
    state.my = state.sy + state.vy * e
    while state.nextIdx <= state.coinCount and e >= schedule[state.nextIdx] do
      spawnRainCoin()
      state.nextIdx = state.nextIdx + 1
    end
    if e >= state.travelTime then state.marbleActive = false end
  end

  -- Advance falling rain; land any that reached their target.
  local anyRain = false
  for i = 1, POOL_SIZE do
    local s = pool[i]
    if s.active then
      s.x = s.x + s.vx * dt
      s.y = s.y + s.vy * dt
      if s.y >= s.targetY then
        landRainCoin(self, s)
      else
        anyRain = true
      end
    end
  end

  -- Event ends once the marble is gone and all rain has settled.
  if not state.marbleActive and not anyRain then
    state.active = false
  end
end

-- ---------- Draw ----------
function M.draw(self)
  if not state.active then return end

  -- Falling rain coins (amber egg discs).
  for i = 1, POOL_SIZE do
    local s = pool[i]
    if s.active then
      lg.setColor(RAIN_FILL[1], RAIN_FILL[2], RAIN_FILL[3], 1)
      lg.circle("fill", s.x, s.y, s.r)
      lg.setColor(RAIN_LINE[1], RAIN_LINE[2], RAIN_LINE[3], 1)
      lg.setLineWidth(2)
      lg.circle("line", s.x, s.y, s.r)
    end
  end

  -- The glowing marble (halo behind, bright core in front).
  if state.marbleActive then
    local mx, my = state.mx, state.my
    lg.setColor(1, 1, 1, 0.30)
    lg.circle("fill", mx, my, MARBLE_R * 1.7)
    lg.setColor(MARBLE_FILL[1], MARBLE_FILL[2], MARBLE_FILL[3], 1)
    lg.circle("fill", mx, my, MARBLE_R)
    lg.setColor(1, 1, 1, 0.85)
    lg.setLineWidth(2)
    lg.circle("line", mx, my, MARBLE_R)
  end

  lg.setColor(1, 1, 1, 1)
end

-- ---------- Per-floor reset ----------
function M.onFloorStart()
  state.active         = false
  state.marbleActive   = false
  state.firedThisFloor = false
  state.autoTimer      = 0
  state.nextIdx        = 1
  for i = 1, POOL_SIZE do pool[i].active = false end
end

return M

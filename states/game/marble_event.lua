-- states/game/marble_event.lua
-- The Special Marble Event — a self-contained, removable feature module.
--
-- A glowing marble rolls slowly and diagonally across the board, leaving a
-- fading motion trail (like a flipping coin). It is clickable while it rolls:
-- ONLY when the player clicks it does it burst, exploding a shower of egg-coins
-- outward from the marble that fly to random spots on the board. Coins that
-- land in a scoring zone convert to points instantly (same formula as
-- flip.resolveFlip); coins that land on white space become normal live board
-- coins. If the marble is never clicked it simply exits and nothing happens.
-- The marble is purely cosmetic — it never collides with coins or chains.
--
-- Public API:
--   M.trigger(self)       -- start a marble roll (no-op if one is active)
--   M.click(self, x, y)   -- attempt to pop the marble; true if it was hit
--   M.update(self, dt)    -- per-frame sim + auto-trigger timer (cheap if idle)
--   M.draw(self)          -- draw marble + trail + flying coins (cheap if idle)
--   M.onFloorStart()      -- reset per-floor state (call on enter / next floor)
--   M.isActive()          -- whether an event is currently running
--
-- All state lives in pre-allocated module-level tables; nothing is allocated
-- inside update() or draw(). (Landing a white-space coin necessarily creates a
-- Coin object — the same pattern spawn.lua uses to add a board coin.)

local L     = require("states.game.layout")
local Coin  = require("entities.coin")
local Tiers = require("data.coin_tiers")

local lg     = love.graphics
local random = math.random
local floor  = math.floor
local max    = math.max
local sqrt   = math.sqrt
local sin    = math.sin
local pi     = math.pi

local M = {}

-- ---------- Tunables ----------
local MARBLE_SPEED   = 160     -- px/sec along the diagonal (half the old speed)
local MARBLE_R       = 18      -- marble radius
local CLICK_PAD      = 10      -- extra forgiveness on the click hit-test
local MIN_Y_FRAC     = 0.15    -- entry/exit Y stays within 15%..85% of height
local MAX_Y_FRAC     = 0.85
local MIN_Y_DIFF     = 0.20    -- entry/exit Y differ by >= 20% of height
local RAIN_MIN       = 20      -- burst coin count range, inclusive
local RAIN_MAX       = 30
local FLY_MIN        = 0.45    -- per-coin burst flight time range (seconds)
local FLY_MAX        = 0.80
local ARC_MIN        = 26      -- burst arc-pop height range (px)
local ARC_MAX        = 70
local AUTO_INTERVAL  = 30      -- seconds between auto-trigger rolls
local AUTO_CHANCE    = 0.10    -- chance per roll
local TRAIL_N        = 10      -- motion-trail after-image count

-- Marble colors.
local MARBLE_FILL = { 0xFF/255, 0xE8/255, 0x7C/255 }  -- #FFE87C iridescent gold
-- Burst egg color: tier-0 amber-yellow #F0C040.
local RAIN_FILL   = { 0xF0/255, 0xC0/255, 0x40/255 }
local RAIN_LINE   = { 0x33/255, 0x33/255, 0x33/255 }

-- ---------- Pre-allocated state ----------
local POOL_SIZE = RAIN_MAX
local pool = {}            -- recycled flying-coin slots
for i = 1, POOL_SIZE do
  pool[i] = { active = false, sx = 0, sy = 0, tx = 0, ty = 0,
              t = 0, dur = 1, r = 0, arc = 0 }
end

-- Motion trail ring (shifted in place; never reallocated).
local trail = {}
for i = 1, TRAIL_N do trail[i] = { x = 0, y = 0 } end

local state = {
  phase          = "idle",  -- "idle" | "rolling" | "burst"
  active         = false,   -- event running (rolling and/or coins settling)
  firedThisFloor = false,   -- auto-trigger fires at most once per floor
  autoTimer      = 0,       -- accumulates toward AUTO_INTERVAL
  -- marble travel
  sx = 0, sy = 0, vx = 0, vy = 0, mx = 0, my = 0,
  travelTime = 0, elapsed = 0,
  trailCount = 0,
  -- burst
  eggR = 0,
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
  state.eggR         = L.coinR
  state.trailCount   = 0

  -- Seed the trail at the entry point so it doesn't streak from (0,0).
  for i = 1, TRAIL_N do trail[i].x = sx; trail[i].y = sy end

  for i = 1, POOL_SIZE do pool[i].active = false end

  state.firedThisFloor = true
  state.active         = true
  state.phase          = "rolling"
end

-- ---------- Click to burst ----------
function M.click(self, x, y)
  if state.phase ~= "rolling" then return false end
  local dx = x - state.mx
  local dy = y - state.my
  local hit = MARBLE_R + CLICK_PAD
  if dx * dx + dy * dy > hit * hit then return false end

  -- Explode a shower of egg-coins outward from the marble toward random spots.
  local bx, by = L.boardX, L.boardY
  local bw, bh = L.boardW, L.boardH
  local r      = state.eggR
  local count  = random(RAIN_MIN, RAIN_MAX)
  for i = 1, count do
    local s = pool[i]
    s.active = true
    s.sx  = state.mx
    s.sy  = state.my
    s.tx  = bx + r + random() * (bw - 2 * r)
    s.ty  = by + r + random() * (bh - 2 * r)
    s.t   = 0
    s.dur = FLY_MIN + random() * (FLY_MAX - FLY_MIN)
    s.r   = r
    s.arc = ARC_MIN + random() * (ARC_MAX - ARC_MIN)
  end

  state.phase = "burst"   -- marble is consumed; coins now fly
  return true
end

-- ---------- Internal helpers ----------

-- Resolves a burst coin that has reached its random landing point. The coin is
-- a GOLD coin (the same kind eggs spawn) — never an egg, so it never splits.
-- It stays on the board wherever it lands and then follows the exact same
-- rules as any other landed coin:
--   • landed in a scoring zone -> it scores and enters the 'done' (used) state,
--     so the only way to flip it again is to knock it with another coin.
--   • landed on white space     -> it stays a live, clickable coin.
local function landBurstCoin(self, s)
  s.active = false
  local x, y, r = s.tx, s.ty, s.r

  local c = Coin(x, y, r)
  c.itemType  = "coin"   -- gold coin, NOT an egg (no egg-split)
  c.tier      = 0        -- full value, amber-gold fill
  c.golden    = true
  c.scoreMult = 5        -- same bonus as a golden egg-spawned coin
  c.isSpawned = true     -- spawned coins never multiply / split
  self.coins[#self.coins + 1] = c

  -- Same landing resolution as flip.resolveFlip: reverse zone scan, edge-based
  -- by the coin radius. A scoring zone scores and marks the coin used (done).
  local zones = L.zones
  for i = #zones, 1, -1 do
    local z = zones[i]
    if x >= z.x - r and x <= z.x + z.w + r and
       y >= z.y - r and y <= z.y + z.h + r then
      local tierMult = Tiers[(c.tier or 0) + 1].mult
      local gain = max(1, floor(z.points * tierMult * (self.multiplier or 1) * (c.scoreMult or 1)))
      self.marbles      = (self.marbles      or 0) + gain
      self.floorMarbles = (self.floorMarbles or 0) + gain
      self.runMarbles   = (self.runMarbles   or 0) + gain
      self.scoreFlash   = 0.20   -- reuse existing score-burst feedback
      c.used = true              -- enter the 'done' state
      return
    end
  end
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

  -- Marble rolling: advance, record trail, exit if never clicked.
  if state.phase == "rolling" then
    state.elapsed = state.elapsed + dt
    local e = state.elapsed
    state.mx = state.sx + state.vx * e
    state.my = state.sy + state.vy * e

    -- Shift the trail ring in place and write the newest sample at index 1.
    for i = TRAIL_N, 2, -1 do
      trail[i].x = trail[i - 1].x
      trail[i].y = trail[i - 1].y
    end
    trail[1].x = state.mx
    trail[1].y = state.my
    if state.trailCount < TRAIL_N then state.trailCount = state.trailCount + 1 end

    if e >= state.travelTime then
      -- Exited without being clicked: end the event cleanly.
      state.phase  = "idle"
      state.active = false
      return
    end
  end

  -- Burst: advance flying coins; land any that arrived.
  if state.phase == "burst" then
    local anyFlying = false
    for i = 1, POOL_SIZE do
      local s = pool[i]
      if s.active then
        s.t = s.t + dt / s.dur
        if s.t >= 1 then
          landBurstCoin(self, s)
        else
          anyFlying = true
        end
      end
    end
    if not anyFlying then
      state.phase  = "idle"
      state.active = false
    end
  end
end

-- ---------- Draw ----------
function M.draw(self)
  if not state.active then return end

  if state.phase == "rolling" then
    -- Motion trail: faded after-images, oldest dimmest (like a coin's trail).
    for i = state.trailCount, 1, -1 do
      local a = 0.28 * (1 - (i - 1) / TRAIL_N)
      lg.setColor(MARBLE_FILL[1], MARBLE_FILL[2], MARBLE_FILL[3], a)
      lg.circle("fill", trail[i].x, trail[i].y, MARBLE_R * (1 - (i - 1) * 0.05))
    end

    -- The glowing marble (halo behind, bright core in front).
    local mx, my = state.mx, state.my
    lg.setColor(1, 1, 1, 0.30)
    lg.circle("fill", mx, my, MARBLE_R * 1.7)
    lg.setColor(MARBLE_FILL[1], MARBLE_FILL[2], MARBLE_FILL[3], 1)
    lg.circle("fill", mx, my, MARBLE_R)
    lg.setColor(1, 1, 1, 0.85)
    lg.setLineWidth(2)
    lg.circle("line", mx, my, MARBLE_R)
  end

  -- Flying burst coins (amber egg discs arcing to their landing spots).
  if state.phase == "burst" then
    for i = 1, POOL_SIZE do
      local s = pool[i]
      if s.active then
        local t = s.t
        local e = 1 - (1 - t) * (1 - t)        -- ease-out for an explosive pop
        local x = s.sx + (s.tx - s.sx) * e
        local y = s.sy + (s.ty - s.sy) * e - sin(t * pi) * s.arc
        lg.setColor(RAIN_FILL[1], RAIN_FILL[2], RAIN_FILL[3], 1)
        lg.circle("fill", x, y, s.r)
        lg.setColor(RAIN_LINE[1], RAIN_LINE[2], RAIN_LINE[3], 1)
        lg.setLineWidth(2)
        lg.circle("line", x, y, s.r)
      end
    end
  end

  lg.setColor(1, 1, 1, 1)
end

-- ---------- Per-floor reset ----------
function M.onFloorStart()
  state.phase          = "idle"
  state.active         = false
  state.firedThisFloor = false
  state.autoTimer      = 0
  state.trailCount     = 0
  for i = 1, POOL_SIZE do pool[i].active = false end
end

return M

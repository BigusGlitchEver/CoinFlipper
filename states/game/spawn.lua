-- states/game/spawn.lua
-- Coin scatter + replenish. Places food-coin tokens in the start strip and
-- tops the board up each frame when the live count drops too low.

local C     = require("states.game.config")
local L     = require("states.game.layout")
local Coin  = require("entities.coin")
local Items = require("data.flip_items")

local floor   = math.floor
local max     = math.max
local min     = math.min
local cos     = math.cos
local sin     = math.sin
local sqrt    = math.sqrt
local pi      = math.pi
local lrandom = love.math.random

local MIN_BOARD_COINS    = C.MIN_BOARD_COINS
local TARGET_BOARD_COINS = C.TARGET_BOARD_COINS

local M = {}

-- True when a coin of radius cr centred at (x, y) would overlap ANY scoring
-- zone (edge-based, inflated by cr). Used to keep starting coins out of every
-- point zone on every board.
local function inAnyZone(x, y, cr)
  local zones = L.zones
  for i = 1, #zones do
    local z = zones[i]
    if x >= z.x - cr and x <= z.x + z.w + cr and
       y >= z.y - cr and y <= z.y + z.h + cr then
      return true
    end
  end
  return false
end

-- Picks a random candidate start point for a coin of radius cr. If the active
-- board defines a spawn circle, the point is drawn uniformly inside it (inset
-- by cr so the coin never clips the circle edge); otherwise it's anywhere on
-- the board interior, inset by cr from the walls.
local function randStartPoint(cr)
  local sc = L.spawnCircle
  if sc then
    local ang = lrandom() * 2 * pi
    local rr  = sqrt(lrandom()) * max(0, sc.r - cr)
    return sc.x + cos(ang) * rr, sc.y + sin(ang) * rr
  end
  return lrandom(floor(L.boardX + cr), floor(L.boardX + L.boardW - cr)),
         lrandom(floor(L.boardY + cr), floor(L.boardY + L.boardH - cr))
end

function M.scatterCoins(n, item)
  local coins = {}
  local minSpacing = L.coinR * 2 + 12
  local maxAttempts = 60
  for i = 1, n do
    local placed = false
    for attempt = 1, maxAttempts do
      local x = love.math.random(L.boardX + L.coinR, L.boardX + L.boardW - L.coinR)
      local y = love.math.random(L.boardY + L.coinR, L.boardY + L.boardH - L.coinR)
      local ok = true
      for j = 1, #coins do
        local c = coins[j]
        local dx = x - c.x
        local dy = y - c.y
        if (dx * dx + dy * dy) < (minSpacing * minSpacing) then ok = false; break end
      end
      if ok then
        local coin = Coin(x, y, L.coinR)
        coins[#coins + 1] = coin
        placed = true
        break
      end
    end
    if not placed then break end
  end
  return coins
end

-- Places 8 opening food-coin tokens inside the white start strip.
function M.scatterBoard()
  local toastR = floor(L.coinR * 1.15)
  local eggR   = L.coinR
  local skullR = floor(L.coinR * 0.65)
  local toastItem = Items.byId("toast")
  local eggItem   = Items.byId("egg")
  local skullItem = Items.byId("skull")
  local specs = {
    { radius = toastR, itemType = "toast", item = toastItem },
    { radius = eggR,   itemType = "egg",   item = eggItem   },
    { radius = skullR, itemType = "skull", item = skullItem },
    { radius = eggR,   itemType = "egg",   item = eggItem   },
    { radius = toastR, itemType = "toast", item = toastItem },
    { radius = skullR, itemType = "skull", item = skullItem },
    { radius = eggR,   itemType = "egg",   item = eggItem   },
    { radius = toastR, itemType = "toast", item = toastItem },
  }
  local coins       = {}
  local maxAttempts = 80
  for _, spec in ipairs(specs) do
    local cr  = spec.radius
    for attempt = 1, maxAttempts do
      -- Scatter inside the spawn circle (if any) or across the whole interior,
      -- never inside a point zone.
      local x, y = randStartPoint(cr)
      local ok = not inAnyZone(x, y, cr)
      if ok then
        for j = 1, #coins do
          local c = coins[j]
          local dx, dy = x - c.x, y - c.y
          local sep = cr + c.radius + 12
          if (dx * dx + dy * dy) < (sep * sep) then ok = false; break end
        end
      end
      if ok then
        local c = Coin(x, y, cr)
        c.itemType = spec.itemType
        coins[#coins + 1] = c
        break
      end
    end
  end
  return coins
end

-- Called every update frame. Adds random food-coin tokens when the resting
-- count is below MIN_BOARD_COINS, placed anywhere in the start strip.
function M.replenishCoins(self)
  -- Count only LIVE, clickable coins (not flipping, not retired). Used coins
  -- stay on the board where they landed (they remain visible in the goal
  -- area), but they don't block fresh coins from spawning in the start strip.
  local resting = 0
  for i = 1, #self.coins do
    local c = self.coins[i]
    if not c.flipping and not c.used then resting = resting + 1 end
  end
  if resting >= MIN_BOARD_COINS then return end
  local toastR = floor(L.coinR * 1.15)
  local eggR   = L.coinR
  local skullR = floor(L.coinR * 0.65)
  local pool = {
    { radius = toastR, itemType = "toast", item = Items.byId("toast") },
    { radius = eggR,   itemType = "egg",   item = Items.byId("egg")   },
    { radius = skullR, itemType = "skull", item = Items.byId("skull") },
  }
  local toAdd       = TARGET_BOARD_COINS - resting
  local maxAttempts = 60
  for n = 1, toAdd do
    local spec = pool[love.math.random(#pool)]
    local cr   = spec.radius
    for attempt = 1, maxAttempts do
      -- Same rules as scatterBoard: spawn circle (if any) or whole interior,
      -- never inside a point zone.
      local x, y = randStartPoint(cr)
      local ok = not inAnyZone(x, y, cr)
      if ok then
        for j = 1, #self.coins do
          local c = self.coins[j]
          local dx, dy = x - c.x, y - c.y
          local sep = cr + c.radius + 14
          if (dx * dx + dy * dy) < (sep * sep) then ok = false; break end
        end
      end
      if ok then
        local c = Coin(x, y, cr)
        c.itemType = spec.itemType
        self.coins[#self.coins + 1] = c
        break
      end
    end
  end
end

-- Module-level buffer so spawnCoinsAt never allocates inside its loop.
-- Safe for reuse because spawning is always sequential (never nested).
local _spawnBuf = {}

-- spawnCoinsAt: creates `count` coins starting at (x, y) and returns them so
-- the caller (flip.lua) can immediately launch each one. Coins are placed with
-- a tiny (≤6px) scatter so they don't perfectly overlap at the pop point.
-- Returns the module-level _spawnBuf — caller must use the values immediately.
function M.spawnCoinsAt(self, x, y, count, tier)
  -- Clear the reuse buffer without allocating a new table.
  for i = 1, #_spawnBuf do _spawnBuf[i] = nil end

  if count <= 0 then return _spawnBuf end
  local cr  = L.coinR
  local bx  = L.boardX;  local bw = L.boardW
  local by  = L.boardY;  local bh = L.boardH
  for i = 1, count do
    -- Tiny scatter so coins don't perfectly stack at the pop point.
    local ang = lrandom() * 2 * pi
    local r   = sqrt(lrandom()) * 6
    local nx  = x + cos(ang) * r
    local ny  = y + sin(ang) * r
    nx = max(bx + cr, min(bx + bw - cr, nx))
    ny = max(by + cr, min(by + bh - cr, ny))
    local c = Coin(nx, ny, cr)
    c.isSpawned = true   -- spawned coins never produce further multiplication
    -- Default: tier 1 (blue fill, 0.75× mult). 1-in-5 chance the coin is the
    -- GOLD coin type (data/coins/gold_coin.lua): tier 0, gold fill, half reach,
    -- and its score multiplier sourced from that one file.
    if lrandom(5) == 1 then
      local gold  = Items.byId("gold_coin")
      c.tier      = 0
      c.itemType  = "gold_coin"
      c.golden    = true
      c.scoreMult = gold.score_mult
    else
      c.tier = 1
    end
    self.coins[#self.coins + 1] = c
    _spawnBuf[i] = c
  end
  return _spawnBuf
end

return M

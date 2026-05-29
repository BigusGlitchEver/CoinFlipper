-- states/game/spawn.lua
-- Coin scatter + replenish. Places food-coin tokens in the start strip and
-- tops the board up each frame when the live count drops too low.

local C     = require("states.game.config")
local L     = require("states.game.layout")
local Coin  = require("entities.coin")
local Items = require("data.flip_items")

local floor = math.floor
local max   = math.max

local MIN_BOARD_COINS    = C.MIN_BOARD_COINS
local TARGET_BOARD_COINS = C.TARGET_BOARD_COINS

local M = {}

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
  local stripTop    = floor(L.startY + 4)
  local coins       = {}
  local maxAttempts = 80
  for _, spec in ipairs(specs) do
    local cr  = spec.radius
    local loY = max(stripTop + cr, floor(L.boardY + cr))
    local hiY = floor(L.boardY + L.boardH - cr)
    if hiY < loY then hiY = loY end
    for attempt = 1, maxAttempts do
      local x = love.math.random(floor(L.boardX + cr), floor(L.boardX + L.boardW - cr))
      local y = love.math.random(loY, hiY)
      local ok = true
      for j = 1, #coins do
        local c = coins[j]
        local dx, dy = x - c.x, y - c.y
        local sep = cr + c.radius + 12
        if (dx * dx + dy * dy) < (sep * sep) then ok = false; break end
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
  local resting = 0
  for i = 1, #self.coins do
    if not self.coins[i].flipping then resting = resting + 1 end
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
    local loX  = floor(L.boardX + cr)
    local hiX  = floor(L.boardX + L.boardW - cr)
    local loY  = floor(L.startY + cr + 4)
    local hiY  = floor(L.boardY + L.boardH - cr)
    if hiY < loY then hiY = loY end
    for attempt = 1, maxAttempts do
      local x = love.math.random(loX, hiX)
      local y = love.math.random(loY, hiY)
      local ok = true
      for j = 1, #self.coins do
        local c = self.coins[j]
        local dx, dy = x - c.x, y - c.y
        local sep = cr + c.radius + 14
        if (dx * dx + dy * dy) < (sep * sep) then ok = false; break end
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

return M

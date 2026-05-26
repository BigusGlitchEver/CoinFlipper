-- states/game.lua
-- The flip board. One Coin, five Floor-1 pockets, arc-flip, multiplier chain,
-- score-popup object pool, HUD. Click on the board = aim the flip.
-- Keys: [M] back to map, [R] reset the run, [Esc] quit (routed in main.lua).
--
-- Pocket setup is data-driven (see buildPockets) so "add a pocket" or
-- "fatten a pocket" is a one-liner -- that's the card/stage lever.
-- Pocket VALUES are tight (5 / 3 / 2). Big numbers come from the multiplier
-- chain, not zone values. (Balatro lesson, see CLAUDE.md.)

local StateMachine = require("statemachine")
local Coin         = require("entities.coin")
local Pocket       = require("entities.pocket")

local lg = love.graphics

local Game = {}

-- ---------- Score popup pool (pre-allocated; NEVER allocate in update/draw) ----------

local POPUP_POOL_SIZE = 24
local POPUP_LIFE      = 1.0
local POPUP_RISE      = 32     -- pixels/sec upward
local popupPool       = {}
for i = 1, POPUP_POOL_SIZE do
  popupPool[i] = { active = false, x = 0, y = 0, text = "", life = 0 }
end

local function spawnPopup(x, y, text)
  for i = 1, POPUP_POOL_SIZE do
    local p = popupPool[i]
    if not p.active then
      p.active = true
      p.x      = x
      p.y      = y
      p.text   = text
      p.life   = POPUP_LIFE
      return p
    end
  end
  -- Pool exhausted: drop silently. NEVER allocate a new one here.
end

local function updatePopups(dt)
  for i = 1, POPUP_POOL_SIZE do
    local p = popupPool[i]
    if p.active then
      p.life = p.life - dt
      p.y    = p.y - POPUP_RISE * dt
      if p.life <= 0 then p.active = false end
    end
  end
end

local function drawPopups()
  for i = 1, POPUP_POOL_SIZE do
    local p = popupPool[i]
    if p.active then
      local alpha = p.life / POPUP_LIFE
      lg.setColor(1, 0.95, 0.35, alpha)
      lg.printf(p.text, p.x - 60, p.y, 120, "center")
    end
  end
  lg.setColor(1, 1, 1)
end

local function resetPopupPool()
  for i = 1, POPUP_POOL_SIZE do
    popupPool[i].active = false
  end
end

-- ---------- Pocket layout (data-driven, parameterizable by floor) ----------

-- floor: 1..3. Floors 2-3 reuse the layout at smaller radii (per GDD).
local function buildPockets(floor)
  local scale = 1 - (floor - 1) * 0.18      -- floor 1=1.00, 2=0.82, 3=0.64
  local cx, cy = 640, 380
  local pockets = {}
  -- center: highest single-pocket value, but only 5 (not 10x the others)
  pockets[#pockets + 1] = Pocket(cx,       cy,       48 * scale, 5)
  -- four outer pockets, values 3/3/2/2 -- chain mult does the heavy lifting
  pockets[#pockets + 1] = Pocket(cx - 180, cy - 70,  40 * scale, 3)
  pockets[#pockets + 1] = Pocket(cx + 180, cy - 70,  40 * scale, 3)
  pockets[#pockets + 1] = Pocket(cx - 180, cy + 70,  40 * scale, 2)
  pockets[#pockets + 1] = Pocket(cx + 180, cy + 70,  40 * scale, 2)
  return pockets
end

-- ---------- State lifecycle ----------

function Game:enter(prev, houseName)
  self.houseName  = houseName or "?"
  self.floor      = 1
  self.pockets    = buildPockets(self.floor)
  -- Coin starts at lower edge ("hand reaching in from the screen edge").
  self.coin       = Coin(160, 640)
  self.marbles    = 0
  self.multiplier = 1
  resetPopupPool()
end

function Game:exit() end

function Game:update(dt)
  self.coin:update(dt)
  for i = 1, #self.pockets do
    self.pockets[i]:update(dt)
  end
  updatePopups(dt)
end

function Game:draw()
  lg.setColor(0.18, 0.20, 0.24)
  lg.rectangle("fill", 0, 0, lg.getWidth(), lg.getHeight())
  for i = 1, #self.pockets do
    self.pockets[i]:draw()
  end
  self.coin:draw()
  -- HUD
  lg.setColor(1, 1, 1)
  lg.print("HOUSE:  " .. self.houseName,        16, 16)
  lg.print("FLOOR:  " .. self.floor,            16, 36)
  lg.print("MARBLES: " .. self.marbles,         16, 56)
  lg.print("MULT:    x" .. self.multiplier,     16, 76)
  lg.print("[click] flip   [R] reset   [M] map   [Esc] quit", 16, lg.getHeight() - 24)
  drawPopups()
end

-- ---------- Flip resolution ----------

-- Pure logic. Exposed for tests via Game._resolveFlip.
local function resolveFlip(self, x, y)
  for i = 1, #self.pockets do
    local pkt = self.pockets[i]
    if pkt:contains(x, y) then
      pkt:flash()
      local gain = pkt.value * self.multiplier
      self.marbles    = self.marbles + gain
      self.multiplier = self.multiplier + 1
      spawnPopup(x, y - 30, "+" .. gain)
      return "hit", gain
    end
  end
  -- Miss: landed in empty board. Multiplier resets to 1. Marbles unchanged.
  self.multiplier = 1
  spawnPopup(x, y - 30, "MISS")
  return "miss", 0
end

function Game:mousepressed(x, y, button)
  if button ~= 1 then return end
  if self.coin.flipping then return end
  local game = self
  self.coin:flipTo(x, y, function(lx, ly)
    resolveFlip(game, lx, ly)
  end)
end

function Game:keypressed(k)
  if k == "m" then
    StateMachine.switch("map")
  elseif k == "r" then
    Game:enter(nil, self.houseName)
  end
end

-- ---------- Test hooks ----------

Game._popupPool       = popupPool
Game._popupPoolSize   = POPUP_POOL_SIZE
Game._resolveFlip     = resolveFlip
Game._buildPockets    = buildPockets

return Game

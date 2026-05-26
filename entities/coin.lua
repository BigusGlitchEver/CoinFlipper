-- entities/coin.lua
-- The flipped Coin. The "flip" is faked 3D per CLAUDE.md:
--   x, y     : board position (interpolated start -> target)
--   z        : fake height (parabolic arc, peaks at t=0.5)
--   tumble   : sin oscillation driving x-scale squash
-- We do NOT use love.physics; landing detection is done by the state by
-- asking each Pocket :contains(x, y) after the coin lands.

local Object = require("lib.classic")

local lg  = love.graphics
local sin = math.sin
local abs = math.abs
local pi  = math.pi

local Coin = Object:extend()

local FLIP_DURATION = 0.85
local ARC_PEAK      = 140   -- max z (pixels)
local TUMBLE_RATE   = 18

function Coin:new(x, y)
  self.x        = x
  self.y        = y
  self.startX   = x
  self.startY   = y
  self.targetX  = x
  self.targetY  = y
  self.z        = 0
  self.radius   = 14
  self.flipTime = 0
  self.flipping = false
  -- landedCallback(x, y) is invoked exactly once when the coin lands.
  self.landedCallback = nil
end

-- Begin a flip toward (tx, ty). callback fires when the coin lands.
function Coin:flipTo(tx, ty, callback)
  self.startX         = self.x
  self.startY         = self.y
  self.targetX        = tx
  self.targetY        = ty
  self.flipTime       = 0
  self.flipping       = true
  self.landedCallback = callback
end

function Coin:update(dt)
  if not self.flipping then return end
  self.flipTime = self.flipTime + dt
  local t = self.flipTime / FLIP_DURATION
  if t >= 1 then
    -- Landed.
    self.x        = self.targetX
    self.y        = self.targetY
    self.z        = 0
    self.flipping = false
    local cb      = self.landedCallback
    self.landedCallback = nil
    if cb then cb(self.x, self.y) end
    return
  end
  -- Linear horizontal interp; parabolic vertical arc.
  self.x = self.startX + (self.targetX - self.startX) * t
  self.y = self.startY + (self.targetY - self.startY) * t
  self.z = sin(t * pi) * ARC_PEAK
end

function Coin:draw()
  -- Drop shadow on board. Smaller / fainter the higher we are.
  local shadowScale = 1 - (self.z / (ARC_PEAK * 1.4))
  if shadowScale < 0.3 then shadowScale = 0.3 end
  lg.setColor(0, 0, 0, 0.35)
  lg.ellipse("fill",
    self.x, self.y + 6,
    self.radius * shadowScale,
    self.radius * 0.42 * shadowScale)

  -- Tumble squash on x.
  local tumble = self.flipping and abs(sin(self.flipTime * TUMBLE_RATE)) or 1
  local sx     = tumble * 0.5 + 0.5

  lg.setColor(1, 0.85, 0.25)
  lg.ellipse("fill", self.x, self.y - self.z, self.radius * sx, self.radius)
  lg.setColor(0.35, 0.25, 0.10)
  lg.setLineWidth(2)
  lg.ellipse("line", self.x, self.y - self.z, self.radius * sx, self.radius)
  lg.setColor(1, 1, 1)
end

return Coin

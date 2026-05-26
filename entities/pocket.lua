-- entities/pocket.lua
-- A scoring pocket on the flip board. Discrete circular zone with a Marble
-- value. `contains` is a squared-distance point-in-circle check (no sqrt).
-- Flash is a brief visual hit-flash; drawing is a placeholder shape so it's
-- trivial to swap a hand-drawn sprite in later.

local Object = require("lib.classic")

-- Localize hot lookups per CLAUDE.md performance rules.
local lg = love.graphics

local Pocket = Object:extend()

local FLASH_TIME = 0.25

function Pocket:new(x, y, radius, value)
  self.x          = x
  self.y          = y
  self.radius     = radius
  self.radiusSq   = radius * radius   -- pre-compute for hit test
  self.value      = value
  self.flashTimer = 0
end

-- True if board-position (px, py) lands inside this pocket.
function Pocket:contains(px, py)
  local dx = px - self.x
  local dy = py - self.y
  return (dx * dx + dy * dy) <= self.radiusSq
end

function Pocket:flash()
  self.flashTimer = FLASH_TIME
end

function Pocket:update(dt)
  if self.flashTimer > 0 then
    self.flashTimer = self.flashTimer - dt
    if self.flashTimer < 0 then self.flashTimer = 0 end
  end
end

-- Placeholder visual. Color brightens during flash.
function Pocket:draw()
  local flash = (self.flashTimer > 0) and (self.flashTimer / FLASH_TIME) or 0
  lg.setColor(0.18 + 0.55 * flash, 0.55 + 0.30 * flash, 0.22 + 0.30 * flash)
  lg.circle("fill", self.x, self.y, self.radius)
  lg.setColor(1, 1, 1)
  lg.setLineWidth(2)
  lg.circle("line", self.x, self.y, self.radius)
  lg.printf(tostring(self.value), self.x - 30, self.y - 8, 60, "center")
end

return Pocket

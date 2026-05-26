-- entities/coin.lua
-- The flipped Coin. The "flip" is faked 3D per CLAUDE.md:
--   x, y     : board position (interpolated start -> target)
--   z        : fake height (parabolic arc, peaks at t = 0.5)
--   tumble   : sin oscillation driving x-scale squash (cosmetic only)
--
-- Public API:
--   Coin(x, y, radius)            constructor
--   :contains(px, py)             tap-hit detection
--   :launch(offX, offY, item, cb) closed-form parametric arc per spec
--   :update(dt), :draw()
--
-- Per FLIP_BOARD_VISUAL_SPEC: prototype draw is a filled circle in #F0C040
-- with a 2px #333333 outline. Replaced with hand-drawn sprite later.

local Object = require("lib.classic")

-- Localize hot lookups per CLAUDE.md performance rules.
local lg    = love.graphics
local sin   = math.sin
local cos   = math.cos
local abs   = math.abs
local sqrt  = math.sqrt
local atan2 = math.atan2
local pi    = math.pi

local Coin = Object:extend()

local TUMBLE_RATE = 18

-- Spec colors.
local COLOR_COIN_FILL    = { 0xF0/255, 0xC0/255, 0x40/255 }
local COLOR_COIN_OUTLINE = { 0x33/255, 0x33/255, 0x33/255 }

function Coin:new(x, y, radius)
  self.x        = x
  self.y        = y
  self.startX   = x
  self.startY   = y
  self.targetX  = x
  self.targetY  = y
  self.z        = 0
  self.radius   = radius or 14
  self.flipTime = 0
  self.flipping = false
  -- Per-launch tuning set by launch() from the item table.
  self.flightDuration = 0.45
  self.arcHeight      = 60
  -- "Safe line" target. Configured by the game state (target circle center).
  self.boardCenterX = 360
  self.boardCenterY = 440
  -- landedCallback(x, y) is invoked once when the coin lands.
  self.landedCallback = nil
  -- "used" = already flipped, can't be tapped again (game state owns this flag).
  self.used = false
end

-- Tap-hit detection. True if (px, py) is inside the coin's radius AND the coin
-- is not mid-flip AND has not already been used.
function Coin:contains(px, py)
  if self.flipping or self.used then return false end
  local dx = px - self.x
  local dy = py - self.y
  return (dx * dx + dy * dy) <= (self.radius * self.radius)
end

-- Launch with a normalized tap offset and per-item tuning. Closed-form
-- parametric arc per docs/FLIP_PHYSICS_SPEC.md.
--
--   offX, offY : tap relative to coin center, normalized to coin.radius
--                (each roughly in [-1, 1]; clamped to unit disc here)
--   item       : per-item tuning table (data/flip_items.lua)
--   callback   : invoked once when the coin lands; receives (landingX, landingY)
--
-- Returns (landingX, landingY) immediately. The animation only interpolates --
-- tumble/spin is cosmetic and CANNOT alter the landing. Same tap = same landing.
function Coin:launch(offX, offY, item, callback)
  local raw_dist = sqrt(offX * offX + offY * offY)
  if raw_dist > 1 then
    local s = 1 / raw_dist
    offX, offY, raw_dist = offX * s, offY * s, 1
  end

  local falloff  = item.falloff or 1
  local eff_dist = raw_dist ^ falloff
  local k = (raw_dist > 0) and (eff_dist / raw_dist) or 0
  local eff_x = offX * k
  local eff_y = offY * k

  local dxc = self.boardCenterX - self.x
  local dyc = self.boardCenterY - self.y
  local center_dist = sqrt(dxc * dxc + dyc * dyc)
  if center_dist < 1 then center_dist = 1 end
  local base_angle = atan2(dyc, dxc)

  local launch_angle = base_angle + eff_x * (item.angle_sens or 0.20)
  local power_units  = (item.base_power or 1.0) + eff_y * (item.power_sens or 0.15)
  local launch_dist  = power_units * center_dist

  local arc_units  = (item.base_arc or 0.30) + eff_dist * (item.arc_var or 0.10)
  local arc_pixels = arc_units * center_dist

  local lx = self.x + cos(launch_angle) * launch_dist
  local ly = self.y + sin(launch_angle) * launch_dist

  self.startX         = self.x
  self.startY         = self.y
  self.targetX        = lx
  self.targetY        = ly
  self.flipTime       = 0
  self.flipping       = true
  self.flightDuration = item.flight_time or 0.45
  self.arcHeight      = arc_pixels
  self.landedCallback = callback

  return lx, ly
end

function Coin:update(dt)
  if not self.flipping then return end
  self.flipTime = self.flipTime + dt
  local t = self.flipTime / self.flightDuration
  if t >= 1 then
    self.x        = self.targetX
    self.y        = self.targetY
    self.z        = 0
    self.flipping = false
    local cb      = self.landedCallback
    self.landedCallback = nil
    if cb then cb(self.x, self.y) end
    return
  end
  self.x = self.startX + (self.targetX - self.startX) * t
  self.y = self.startY + (self.targetY - self.startY) * t
  self.z = sin(t * pi) * self.arcHeight
end

function Coin:draw()
  -- Drop shadow during flight.
  if self.z > 0 then
    local shadowScale = 1 - (self.z / 200)
    if shadowScale < 0.3 then shadowScale = 0.3 end
    lg.setColor(0, 0, 0, 0.35)
    lg.ellipse("fill",
      self.x, self.y + 6,
      self.radius * shadowScale,
      self.radius * 0.42 * shadowScale)
  end

  -- Tumble squash on x during flight; static circle when at rest.
  local sx
  if self.flipping then
    local tumble = abs(sin(self.flipTime * TUMBLE_RATE))
    sx = tumble * 0.5 + 0.5
  else
    sx = 1
  end

  local alpha = self.used and 0.30 or 1.0
  lg.setColor(COLOR_COIN_FILL[1], COLOR_COIN_FILL[2], COLOR_COIN_FILL[3], alpha)
  lg.ellipse("fill", self.x, self.y - self.z, self.radius * sx, self.radius)
  lg.setColor(COLOR_COIN_OUTLINE[1], COLOR_COIN_OUTLINE[2], COLOR_COIN_OUTLINE[3], alpha)
  lg.setLineWidth(2)
  lg.ellipse("line", self.x, self.y - self.z, self.radius * sx, self.radius)
  lg.setColor(1, 1, 1, 1)
end

return Coin

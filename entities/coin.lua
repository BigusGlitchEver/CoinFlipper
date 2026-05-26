-- entities/coin.lua
-- The flipped Coin. The "flip" is faked 3D per CLAUDE.md:
--   x, y     : board position (interpolated start -> target)
--   z        : fake height (parabolic arc, peaks at t = 0.5)
--   tumble   : sin oscillation driving x-scale squash (cosmetic only)
--
-- Public API:
--   Coin(x, y, radius)                 constructor
--   :contains(px, py)                  tap-hit detection
--   :regionAt(localX, localY, item)    pick the collision region for a tap
--   :launch(angle, power, item, cb)    instant launch in a screen-space angle
--   :update(dt), :draw()
--
-- Region-based launch model (per the region refactor):
--   Direction is data-driven per coin type via item.regions. NO auto-aim --
--   Coin:launch must NOT reference any target/board center. The coin flies in
--   whatever screen-space `angle` the caller provides (resolved from the
--   region the tap landed in), at the given `power` in pixels. Arc height
--   comes from item.base_arc; per-region arc overrides are supported via the
--   schema but currently consumed by the caller, not by launch itself.
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
  -- landedCallback(x, y) is invoked once when the coin lands.
  self.landedCallback = nil
  -- "used" = already flipped (game state owns this flag).
  self.used = false
end

-- Tap-hit detection. True if (px, py) is inside the coin's radius AND the
-- coin is not mid-flip AND has not already been used.
function Coin:contains(px, py)
  if self.flipping or self.used then return false end
  local dx = px - self.x
  local dy = py - self.y
  return (dx * dx + dy * dy) <= (self.radius * self.radius)
end

-- Pick the region containing (localX, localY) for this item.
--   localX, localY : tap relative to coin center, normalized to coin.radius
--                    (each roughly in [-1, 1]; clamped to the unit disc here)
--   item           : the item table whose `regions` list to walk
--
-- Returns the matching region table (the schema entry the box belongs to).
-- Fallback order: region containing (0,0) (the "center"), then regions[1].
-- Returns nil if the item has no regions table at all.
function Coin:regionAt(localX, localY, item)
  if not item or not item.regions then return nil end
  -- Clamp tap to the unit disc.
  local d = sqrt(localX * localX + localY * localY)
  if d > 1 then
    local s = 1 / d
    localX, localY = localX * s, localY * s
  end
  local regions = item.regions
  -- Inclusive upper bound so points on the +x / +y edge (after disc clamp)
  -- still land in a cell. First match wins for interior tie-breaking.
  for i = 1, #regions do
    local r = regions[i]
    if localX >= r.x and localX <= r.x + r.w
       and localY >= r.y and localY <= r.y + r.h then
      return r
    end
  end
  -- Fallback: region containing (0, 0).
  for i = 1, #regions do
    local r = regions[i]
    if 0 >= r.x and 0 < r.x + r.w and 0 >= r.y and 0 < r.y + r.h then
      return r
    end
  end
  return regions[1]
end

-- Launch in a screen-space angle at the given power (in pixels).
--   angle    : radians, screen-space (cos = +x = right, sin = +y = down)
--   power    : pixel distance to travel
--   item     : per-item tuning (used for base_arc + flight_time defaults)
--   callback : invoked once when the coin lands; receives (landingX, landingY)
--
-- Returns (landingX, landingY) immediately at launch time. The animation only
-- interpolates -- tumble/spin is cosmetic and CANNOT alter the landing.
-- Same angle + same power = same landing, deterministic.
function Coin:launch(angle, power, item, callback)
  local arc_pixels    = (item and item.base_arc)    or 80
  local flight_time   = (item and item.flight_time) or 0.45

  -- Compute landing immediately (deterministic).
  local lx = self.x + cos(angle) * power
  local ly = self.y + sin(angle) * power

  -- Stash for the animation; the visual cannot change the result.
  self.startX         = self.x
  self.startY         = self.y
  self.targetX        = lx
  self.targetY        = ly
  self.flipTime       = 0
  self.flipping       = true
  self.flightDuration = flight_time
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

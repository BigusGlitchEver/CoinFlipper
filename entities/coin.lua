-- entities/coin.lua
-- The flipped Coin. The "flip" is faked 3D per CLAUDE.md:
--   x, y     : board position (interpolated start -> target)
--   z        : fake height (parabolic arc, peaks at t = 0.5)
--   tumble   : sin oscillation driving x-scale squash
-- We do NOT use love.physics; landing detection is the state's job.
--
-- Chunk 2 added Coin:launch(offX, offY, item, callback) -- the closed-form
-- parametric arc per docs/FLIP_PHYSICS_SPEC.md. This is the API the new
-- tap-the-coin input model will use (Chunk 3 wires it up in states/game.lua).
-- The OLD Coin:flipTo(targetX, targetY, callback) is retained for backwards
-- compat with the current click-to-launch states/game.lua until Chunk 3.

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

-- Defaults used by the legacy flipTo() path. The new launch() path overrides
-- both from the per-item tuning table.
local DEFAULT_FLIP_DURATION = 0.85
local DEFAULT_ARC_PEAK      = 140
local TUMBLE_RATE           = 18

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
  -- Per-launch tuning. Set by either flipTo() (defaults) or launch() (item).
  self.flightDuration = DEFAULT_FLIP_DURATION
  self.arcHeight      = DEFAULT_ARC_PEAK
  -- Board center ("safe line" target). Configured by the game state.
  -- Defaults match the current 1280x720 layout for convenience.
  self.boardCenterX = 640
  self.boardCenterY = 380
  -- landedCallback(x, y) is invoked exactly once when the coin lands.
  self.landedCallback = nil
end

-- Tap-hit detection for the new input model. Returns true if (px, py) is
-- inside the coin's tap radius AND the coin is not mid-flip.
-- (Chunk 3 will use this in states/game.lua.)
function Coin:contains(px, py)
  if self.flipping then return false end
  local dx = px - self.x
  local dy = py - self.y
  return (dx * dx + dy * dy) <= (self.radius * self.radius)
end

-- LEGACY: flip to an explicit target. Used by the current states/game.lua
-- click-to-launch model. Removed in Chunk 3 once launch() is wired in.
function Coin:flipTo(tx, ty, callback)
  self.startX         = self.x
  self.startY         = self.y
  self.targetX        = tx
  self.targetY        = ty
  self.flipTime       = 0
  self.flipping       = true
  self.landedCallback = callback
  self.flightDuration = DEFAULT_FLIP_DURATION
  self.arcHeight      = DEFAULT_ARC_PEAK
end

-- NEW (Chunk 2): launch with a normalized tap offset and per-item tuning.
-- Implements the closed-form parametric arc from FLIP_PHYSICS_SPEC.md.
--
--   offX, offY : tap position relative to coin center, normalized to the
--                coin's radius. Each component roughly in [-1, 1]; values
--                outside the unit disc are clamped.
--   item       : per-item tuning record from data/flip_items.lua
--                  (base_power, power_sens, angle_sens, base_arc, arc_var,
--                   flight_time, falloff)
--   callback   : invoked once when the coin lands; receives (landingX, landingY)
--
-- Returns (landingX, landingY) immediately at launch time. The animation
-- only interpolates -- the tumble/spin is cosmetic and CANNOT alter the
-- landing. This guarantees the "same tap = same landing" rule from the spec.
function Coin:launch(offX, offY, item, callback)
  -- Clamp tap to the unit disc.
  local raw_dist = sqrt(offX * offX + offY * offY)
  if raw_dist > 1 then
    local s = 1 / raw_dist
    offX, offY, raw_dist = offX * s, offY * s, 1
  end

  -- Apply sensitivity falloff (shapes the off-center response curve).
  --   falloff < 1 -> forgiving near center, scary only at the very edge
  --   falloff = 1 -> linear
  --   falloff > 1 -> tight sweet spot, punishing quickly  (high-value items)
  local falloff  = item.falloff or 1
  local eff_dist = raw_dist ^ falloff
  -- Scale offset components so direction is preserved and magnitude is reshaped.
  local k = (raw_dist > 0) and (eff_dist / raw_dist) or 0
  local eff_x = offX * k
  local eff_y = offY * k

  -- The "safe line" runs from the coin's current position to the board center.
  local dx_to_center = self.boardCenterX - self.x
  local dy_to_center = self.boardCenterY - self.y
  local center_dist  = sqrt(dx_to_center * dx_to_center + dy_to_center * dy_to_center)
  if center_dist < 1 then center_dist = 1 end  -- defensive
  local base_angle   = atan2(dy_to_center, dx_to_center)

  -- Per the spec: offset_x rotates the shot; offset_y pushes it long/short.
  local launch_angle = base_angle + eff_x * (item.angle_sens or 0.20)
  local power_units  = (item.base_power or 1.0) + eff_y * (item.power_sens or 0.15)
  local launch_dist  = power_units * center_dist

  -- Arc height: per-item base, modulated by how far off-center the tap was.
  local arc_units  = (item.base_arc or 0.30) + eff_dist * (item.arc_var or 0.10)
  local arc_pixels = arc_units * center_dist

  -- Compute landing (deterministic) -- this is the contract: same in, same out.
  local lx = self.x + cos(launch_angle) * launch_dist
  local ly = self.y + sin(launch_angle) * launch_dist

  -- Stash for the animation; the visual cannot change the result.
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
  -- Linear horizontal interp; parabolic vertical arc (peaks at t = 0.5).
  self.x = self.startX + (self.targetX - self.startX) * t
  self.y = self.startY + (self.targetY - self.startY) * t
  self.z = sin(t * pi) * self.arcHeight
end

function Coin:draw()
  -- Drop shadow on board. Smaller / fainter the higher we are.
  local shadowScale = 1 - (self.z / (DEFAULT_ARC_PEAK * 1.4))
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

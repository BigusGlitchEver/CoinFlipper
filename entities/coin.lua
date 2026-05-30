-- entities/coin.lua
-- The flipped Coin. The "flip" is faked 3D per CLAUDE.md:
--   x, y     : board position (interpolated start -> target)
--   z        : fake height (parabolic arc, peaks at t = 0.5)
--   tumble   : sin oscillation driving x-scale squash (cosmetic only)
--
-- Public API:
--   Coin(x, y, radius)                       constructor
--   :contains(px, py)                        point-in-coin hit test (tests/UI)
--   :pressedBy(px, py)                       point-in-coin contact test
--   :regionAt(localX, localY, item)          pick the collision region
--   :launch(angle, power, arc, item, cb)     instant launch (deterministic)
--   :update(dt), :draw()
--
-- Region-based launch model:
--   Direction is data-driven per coin type via item.regions. NO auto-aim --
--   Coin:launch must NOT reference any target/board center. The coin flies in
--   whatever screen-space `angle` the caller provides (resolved from the
--   region the press landed in), at the given `power` in pixels, with the
--   given `arc` in pixels. The caller is responsible for resolving power/arc
--   from the contact offset (typically: edge press = far/flat, center = short/high).
--
-- Per FLIP_BOARD_VISUAL_SPEC: prototype draw is a filled circle in #F0C040
-- with a 2px #333333 outline. Replaced with hand-drawn sprite later.

local Object = require("lib.classic")
local Tiers  = require("data.coin_tiers")

-- Localize hot lookups per CLAUDE.md performance rules.
local lg    = love.graphics
local sin   = math.sin
local cos   = math.cos
local abs   = math.abs
local sqrt  = math.sqrt
local pi    = math.pi

local Coin = Object:extend()

local TUMBLE_RATE = 18

-- Outline stays #333333 across all tiers; fill comes from Tiers[tier+1].
local COLOR_COIN_OUTLINE = { 0x33/255, 0x33/255, 0x33/255 }

-- Golden coin: rare egg-spawned bonus coin (yellow, worth 5x). Overrides the
-- tier fill so it reads as a distinct gold disc.
local COLOR_COIN_GOLDEN = { 0xFF/255, 0xD4/255, 0x1F/255 }

-- Pre-allocated star vertex buffer for easy_coin icon (10 points = 20 floats).
-- Filled each draw call; avoids per-frame table creation.
local STAR_VERTS = {}
for _i = 1, 20 do STAR_VERTS[_i] = 0 end

-- Lazy sprite loader. Food-coin art (egg / skull / toast) lives in
-- assets/coins. Loaded on first draw -- love.graphics is guaranteed ready by
-- then; module-load time is NOT safe for newImage. Missing files fall back to
-- the primitive (filled disc) rendering.
local SPRITES = nil
local function ensureSprites()
  if SPRITES then return end
  SPRITES = {}
  local files = {
    egg   = "assets/coins/egg.png",
    skull = "assets/coins/skull.png",
    toast = "assets/coins/toast.png",
  }
  for key, path in pairs(files) do
    if love.filesystem.getInfo(path) then
      SPRITES[key] = lg.newImage(path)
    end
  end
end

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
  -- Degradation tier 0..3. Starts at 0 (yellow, full value). Each non-scoring
  -- flip bumps it; capped at 3 (red, 0.25x). game.lua's resolveFlip mutates.
  self.tier = 0
  -- Last launch direction in radians (screen-space). Stored so the chain
  -- reaction can compute the leading-edge contact point at landing.
  self.launchAngle = 0
  -- Bounce point set by launch() when the coin clips a board wall; nil otherwise.
  self.bounceX = nil
  self.bounceY = nil
  self._tSplit = nil
  -- Item type key for icon selection. Caller sets to 'easy_coin' for easy coins.
  self.itemType = 'coin'
end

-- Tap-hit detection. True if (px, py) is inside the coin's radius AND the
-- coin is not mid-flip AND has not already been used.
function Coin:contains(px, py)
  if self.flipping or self.used then return false end
  local dx = px - self.x
  local dy = py - self.y
  return (dx * dx + dy * dy) <= (self.radius * self.radius)
end

-- Pure offset calculator. (px, py) is a single screen point -- typically a
-- tool rim-dot position resolved upstream. Returns the contact in coin-local
-- normalized space (coin spans -1..1). Points outside the coin's disc clamp
-- to the unit circle (offDist == 1), which lets a dot engaged via the grab
-- zone -- sitting just outside the coin's outline -- resolve to an edge
-- contact and trigger the outer-zone (long, flat) shot.
--
-- Always returns three numbers: never nil. The "is this dot engaged with
-- this coin?" decision lives in findPressedCoin, not here.
--
-- Returns: offX, offY, offDist (offDist in [0, 1]; 0 = center, 1 = edge).
function Coin:pressedBy(px, py)
  local r    = self.radius
  local offX = (px - self.x) / r
  local offY = (py - self.y) / r
  local mag  = sqrt(offX * offX + offY * offY)
  if mag > 1 then
    local s = 1 / mag
    offX, offY = offX * s, offY * s
    mag = 1
  end
  return offX, offY, mag
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

-- Launch in a screen-space angle at the given power and arc (all in pixels).
--   angle    : radians, screen-space (cos = +x = right, sin = +y = down)
--   power    : pixel distance to travel
--   arc      : visible arc lift at flight midpoint (pixels)
--   item     : per-item tuning (used for flight_time)
--   callback : invoked once when the coin lands; receives (landingX, landingY)
--
-- Returns (landingX, landingY) immediately at launch time. The animation only
-- interpolates -- tumble/spin is cosmetic and CANNOT alter the landing.
-- Same (angle, power) = same landing, deterministic.
-- bx,by,bw,bh: inner board bounds for one-bounce wall reflection (optional).
-- When the tentative landing is outside the board the coin reflects off the
-- first wall it crosses and continues with remaining power. bounceX/Y is
-- nil when no bounce occurred; _tSplit records the phase-split fraction.
function Coin:launch(angle, power, arc, item, callback, bx, by, bw, bh)
  local flight_time = (item and item.flight_time) or 0.45
  local ca = cos(angle)
  local sa = sin(angle)
  local ox, oy = self.x, self.y

  -- Keep the start strictly within the bounce bounds. A previous bounce
  -- clamps a coin's landing exactly onto a wall (ox == bx), and placement can
  -- leave it a hair past one; without this the crossing-time math below yields
  -- t <= 0, the wall is missed, and the coin escapes the board. Pulling the
  -- start back inside makes t well-defined for every launch.
  if bx then
    if ox < bx then ox = bx elseif ox > bx + bw then ox = bx + bw end
    if oy < by then oy = by elseif oy > by + bh then oy = by + bh end
  end

  -- Tentative landing (deterministic).
  local lx = ox + ca * power
  local ly = oy + sa * power

  -- Reset bounce state.
  self.bounceX = nil
  self.bounceY = nil
  self._tSplit = nil

  if bx and (lx < bx or lx > bx + bw or ly < by or ly > by + bh) then
    -- Find smallest t in [0,1] where the ray first crosses a wall. t == 0 is
    -- valid: a coin resting against a wall reflects immediately.
    local tMin      = 2          -- sentinel > 1
    local wallHoriz = false      -- true = top/bottom, false = left/right

    if ca < 0 then          -- left wall x = bx
      local t = (bx - ox) / (ca * power)
      if t >= 0 and t <= 1 then
        local hy = oy + sa * power * t
        if hy >= by and hy <= by + bh and t < tMin then
          tMin = t; wallHoriz = false
        end
      end
    elseif ca > 0 then      -- right wall x = bx + bw
      local t = (bx + bw - ox) / (ca * power)
      if t >= 0 and t <= 1 then
        local hy = oy + sa * power * t
        if hy >= by and hy <= by + bh and t < tMin then
          tMin = t; wallHoriz = false
        end
      end
    end
    if sa < 0 then          -- top wall y = by
      local t = (by - oy) / (sa * power)
      if t >= 0 and t <= 1 then
        local hx = ox + ca * power * t
        if hx >= bx and hx <= bx + bw and t < tMin then
          tMin = t; wallHoriz = true
        end
      end
    elseif sa > 0 then      -- bottom wall y = by + bh
      local t = (by + bh - oy) / (sa * power)
      if t >= 0 and t <= 1 then
        local hx = ox + ca * power * t
        if hx >= bx and hx <= bx + bw and t < tMin then
          tMin = t; wallHoriz = true
        end
      end
    end

    if tMin <= 1 then
      local wx = ox + ca * power * tMin
      local wy = oy + sa * power * tMin
      local rca = ca
      local rsa = sa
      if wallHoriz then rsa = -rsa else rca = -rca end
      local rem = (1 - tMin) * power
      lx = wx + rca * rem
      ly = wy + rsa * rem
      if lx < bx      then lx = bx      end
      if lx > bx + bw then lx = bx + bw end
      if ly < by      then ly = by       end
      if ly > by + bh then ly = by + bh  end
      self.bounceX = wx
      self.bounceY = wy
      local d1x = wx - ox;  local d1y = wy - oy
      local d2x = lx - wx;  local d2y = ly - wy
      local d1  = sqrt(d1x * d1x + d1y * d1y)
      local d2  = sqrt(d2x * d2x + d2y * d2y)
      self._tSplit = (d1 + d2 > 0) and (d1 / (d1 + d2)) or 0.5
    end
  end

  -- Stash for the animation; the visual cannot alter the landing.
  self.startX         = ox
  self.startY         = oy
  self.targetX        = lx
  self.targetY        = ly
  self.flipTime       = 0
  self.flipping       = true
  self.flightDuration = flight_time
  self.arcHeight      = arc
  self.landedCallback = callback
  self.launchAngle    = angle  -- needed at landing for the chain leading edge

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
  if self.bounceX then
    -- Two-phase arc: start->bounce (phase 1) then bounce->target (phase 2).
    local ts = self._tSplit
    if t < ts then
      local p = (ts > 0) and (t / ts) or 0
      self.x = self.startX  + (self.bounceX - self.startX)  * p
      self.y = self.startY  + (self.bounceY - self.startY)  * p
      self.z = sin(p * pi)  * self.arcHeight * ts
    else
      -- Phase 2: z resets to 0 at the bounce point.
      local rem = 1 - ts
      local p   = (rem > 0) and ((t - ts) / rem) or 1
      self.x = self.bounceX + (self.targetX - self.bounceX) * p
      self.y = self.bounceY + (self.targetY - self.bounceY) * p
      self.z = sin(p * pi)  * self.arcHeight * rem
    end
  else
    self.x = self.startX + (self.targetX - self.startX) * t
    self.y = self.startY + (self.targetY - self.startY) * t
    self.z = sin(t * pi) * self.arcHeight
  end
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

  -- Full opacity while airborne; faded only when resting and scored.
  local alpha = (self.used and not self.flipping) and 0.30 or 1.0
  local fill  = self.golden and COLOR_COIN_GOLDEN or Tiers[(self.tier or 0) + 1].color

  ensureSprites()
  local sprite = SPRITES and SPRITES[self.itemType]

  -- Motion trail: 4 after-images of the WHOLE coin behind it during flight.
  -- Alpha ramps from 0.25 (g=1, closest) down to ~0.05 (g=4, farthest).
  if self.flipping then
    local t_now = self.flipTime / self.flightDuration
    for g = 4, 1, -1 do
      local tg = t_now - g * 0.05
      if tg > 0 then
        local gx, gy, gz
        if self.bounceX then
          local ts = self._tSplit
          if tg < ts then
            local p = (ts > 0) and (tg / ts) or 0
            gx = self.startX  + (self.bounceX - self.startX)  * p
            gy = self.startY  + (self.bounceY - self.startY)  * p
            gz = sin(p * pi)  * self.arcHeight * ts
          else
            local rem = 1 - ts
            local p   = (rem > 0) and ((tg - ts) / rem) or 1
            gx = self.bounceX + (self.targetX - self.bounceX) * p
            gy = self.bounceY + (self.targetY - self.bounceY) * p
            gz = sin(p * pi)  * self.arcHeight * rem
          end
        else
          gx = self.startX + (self.targetX - self.startX) * tg
          gy = self.startY + (self.targetY - self.startY) * tg
          gz = sin(tg * pi) * self.arcHeight
        end
        -- After-image of the WHOLE coin: same squashed body + outline as the
        -- live coin, just faded. Each ghost uses its own tumble phase so the
        -- trail reads as the coin itself echoing behind, not plain dots.
        local gtumble = abs(sin(tg * self.flightDuration * TUMBLE_RATE))
        local gsx     = gtumble * 0.5 + 0.5
        local ga      = 0.25 - (g - 1) * (0.20 / 3)
        if sprite then
          local iw, ih = sprite:getDimensions()
          local fit = (self.radius * 2) / ((iw > ih) and iw or ih)
          lg.setColor(1, 1, 1, ga)
          lg.draw(sprite, gx, gy - gz, 0, fit * gsx, fit, iw * 0.5, ih * 0.5)
        else
          lg.setColor(fill[1], fill[2], fill[3], ga)
          lg.ellipse("fill", gx, gy - gz, self.radius * gsx, self.radius)
          lg.setColor(COLOR_COIN_OUTLINE[1], COLOR_COIN_OUTLINE[2], COLOR_COIN_OUTLINE[3], ga)
          lg.setLineWidth(2)
          lg.ellipse("line", gx, gy - gz, self.radius * gsx, self.radius)
        end
      end
    end
  end

  if sprite then
    -- Sprite IS the coin face. Scale so its larger side fills the coin's
    -- diameter; tumble squash applies to x like the primitive body does.
    local iw, ih = sprite:getDimensions()
    local fit = (self.radius * 2) / ((iw > ih) and iw or ih)
    lg.setColor(1, 1, 1, alpha)
    lg.draw(sprite, self.x, self.y - self.z, 0, fit * sx, fit, iw * 0.5, ih * 0.5)
    -- Tier ring carries the degradation cue (yellow -> blue -> purple -> red).
    lg.setColor(fill[1], fill[2], fill[3], alpha)
    lg.setLineWidth(3)
    lg.ellipse("line", self.x, self.y - self.z, self.radius * sx, self.radius)
  else
    lg.setColor(fill[1], fill[2], fill[3], alpha)
    lg.ellipse("fill", self.x, self.y - self.z, self.radius * sx, self.radius)
    lg.setColor(COLOR_COIN_OUTLINE[1], COLOR_COIN_OUTLINE[2], COLOR_COIN_OUTLINE[3], alpha)
    lg.setLineWidth(2)
    lg.ellipse("line", self.x, self.y - self.z, self.radius * sx, self.radius)
  end

  -- Coin icon: shown only when not retired (used=false) AND no sprite art.
  if not self.used and not sprite then
    local cx = self.x
    local cy = self.y - self.z
    if self.itemType == 'easy_coin' then
      -- 5-point star for easy_coin.
      local outerR = self.radius * 0.45
      local innerR = self.radius * 0.20
      for i = 0, 4 do
        local ao = (i * 2 * pi / 5) - pi * 0.5
        local ai = ao + pi * 0.2
        STAR_VERTS[i * 4 + 1] = cx + cos(ao) * outerR
        STAR_VERTS[i * 4 + 2] = cy + sin(ao) * outerR
        STAR_VERTS[i * 4 + 3] = cx + cos(ai) * innerR
        STAR_VERTS[i * 4 + 4] = cy + sin(ai) * innerR
      end
      lg.setColor(1, 1, 1, 0.55)
      lg.polygon("fill", STAR_VERTS)
    elseif self.itemType == 'mini_coin' then
      -- White diamond for mini_coin (4-point rotated square).
      local dr = self.radius * 0.42
      lg.setColor(1, 1, 1, 0.60)
      lg.polygon("fill", cx, cy - dr, cx + dr, cy, cx, cy + dr, cx - dr, cy)
      lg.setColor(0.30, 0.88, 0.60, 0.70)
      lg.setLineWidth(1.5)
      lg.polygon("line", cx, cy - dr, cx + dr, cy, cx, cy + dr, cx - dr, cy)
    elseif self.itemType == 'hard_coin' then
      -- Solid black dot for hard_coin.
      lg.setColor(0, 0, 0, 0.82)
      lg.circle("fill", cx, cy, self.radius * 0.32)
      -- Thin white ring so it reads on dark tier fills.
      lg.setColor(1, 1, 1, 0.40)
      lg.setLineWidth(1.5)
      lg.circle("line", cx, cy, self.radius * 0.32)
    else
      -- Simplified skull for mid coin.
      local cr   = self.radius * 0.40
      local oy   = cy - self.radius * 0.10
      lg.setColor(1, 1, 1, 0.55)
      lg.circle("fill", cx, oy, cr)
      local eyeR   = self.radius * 0.09
      local eyeOff = cr * 0.38
      lg.setColor(0.10, 0.10, 0.10, 0.80)
      lg.circle("fill", cx - eyeOff, oy - eyeR, eyeR)
      lg.circle("fill", cx + eyeOff, oy - eyeR, eyeR)
      local jawY = oy + cr + self.radius * 0.04
      lg.setColor(1, 1, 1, 0.45)
      lg.setLineWidth(1.5)
      lg.line(cx - cr * 0.40, jawY, cx + cr * 0.40, jawY)
    end
  end

  -- Leading-edge indicator: a small bright dot on the coin's perimeter in
  -- the direction of travel. Visible only while the coin is flipping so the
  -- player can anticipate where a chain contact will land.
  if self.flipping then
    local a  = self.launchAngle or 0
    local ex = self.x + cos(a) * self.radius
    local ey = self.y - self.z + sin(a) * self.radius
    lg.setColor(1, 1, 1, 1)
    lg.circle("fill", ex, ey, 4)
  end

  lg.setColor(1, 1, 1, 1)
end

return Coin

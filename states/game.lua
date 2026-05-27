-- states/game.lua
-- The flip board, rebuilt per docs/FLIP_BOARD_VISUAL_SPEC.md.
--
-- Portrait layout, light grey background, white board rectangle filling
-- everything below a top HUD strip. One target (3 concentric rings) in the
-- upper half of the board. Multiple coins scattered on the board at floor
-- start; tap an un-used coin to flip it (closed-form arc per the physics
-- spec). Only one coin flies at a time. A hand sprite renders behind the
-- most-recently-tapped coin, from the nearest screen edge.
--
-- Scoring is 4-tier: bullseye / middle ring / outer ring (graze) / off-board
-- (full miss + chain reset). On-board-but-outside-target is a no-op (no
-- score, no chain change) -- effectively a "wasted shot."
--
-- NO JUICE in this chunk: no score popups, no ring flash, no screen shake,
-- no multiplier bounce, no between-floor shrink. Those land in Chunk 4.

local StateMachine = require("statemachine")
local Coin         = require("entities.coin")
local Items        = require("data.flip_items")
local Tiers        = require("data.coin_tiers")

local lg    = love.graphics
local lm    = love.mouse
local lt    = love.timer
local sqrt  = math.sqrt
local min   = math.min
local max   = math.max
local cos   = math.cos
local sin   = math.sin
local pi    = math.pi
local huge  = math.huge
local floor = math.floor

-- Tiny helper: linear interpolation in [0, 1].
local function lerp(a, b, t) return a + (b - a) * t end

-- Two-zone power/arc model. A hard discontinuity at zone_threshold (typically
-- 0.65): inner zone is a short, high pop; outer zone is a long, flat launch.
-- The snap is intentional. Returns power, arc as multiple values (no alloc).
local function resolveShot(item, offDist)
  local th = item.zone_threshold or 0.65
  if offDist < th then
    local t = offDist / th
    return lerp(item.inner_power_center or 80,  item.inner_power_edge or 130, t),
           lerp(item.inner_arc_center   or 220, item.inner_arc_edge   or 160, t)
  end
  local t = (offDist - th) / (1 - th)
  return lerp(item.outer_power_center or 180, item.outer_power_edge or 340, t),
         lerp(item.outer_arc_center   or 70,  item.outer_arc_edge   or 25,  t)
end

-- Tool radius is hoisted into L (rebuildLayout) so drawing and hit-testing
-- agree on the same number. 0.5x coin radius (== 12px at coinR=24) makes the
-- tool compact -- the player aims precisely with the rim dots, which scale
-- with toolR so the whole assembly shrinks together.
local TOOL_R_FACTOR = 1.5

-- ---------- Rim dots (the actual coin colliders) ----------
-- SIX dots evenly spaced at 60 deg, starting at 270 deg (top) and going
-- clockwise. Indices:
--   1 = 270 (top)         red     #FF4444
--   2 = 330 (top-right)   orange  #FF9933
--   3 =  30 (bottom-right) yellow #FFDD00
--   4 =  90 (bottom)      green   #44CC44
--   5 = 150 (bottom-left) cyan    #33CCFF
--   6 = 210 (top-left)    purple  #AA44FF
-- Unit-vector offsets precomputed at file load -- no per-frame trig.
local DOT_UX, DOT_UY = {}, {}
do
  local angles = { 270, 330, 30, 90, 150, 210 }
  for i = 1, 6 do
    local rad = angles[i] * pi / 180
    DOT_UX[i] = cos(rad)
    DOT_UY[i] = sin(rad)
  end
end
local DOT_R         = 6     -- normal dot fill radius
local DOT_R_ARMED   = 8     -- armed (auto OR selected) dot radius
local DOT_OUTLINE   = 1.5   -- dot outline width
local DOT_COLORS = {
  { 0xFF/255, 0x44/255, 0x44/255 },  -- 1 top         red
  { 0xFF/255, 0x99/255, 0x33/255 },  -- 2 top-right   orange
  { 0xFF/255, 0xDD/255, 0x00/255 },  -- 3 bot-right   yellow
  { 0x44/255, 0xCC/255, 0x44/255 },  -- 4 bottom      green
  { 0x33/255, 0xCC/255, 0xFF/255 },  -- 5 bot-left    cyan
  { 0xAA/255, 0x44/255, 0xFF/255 },  -- 6 top-left    purple
}

local Game = {}

-- ---------- Visual spec colors ----------

local COLOR_BG             = { 0xEE/255, 0xEE/255, 0xEE/255 }
local COLOR_BOARD          = { 1, 1, 1 }
local COLOR_BOARD_BORDER   = { 0xAA/255, 0xAA/255, 0xAA/255 }
local COLOR_BULL           = { 0xE8/255, 0x47/255, 0x3F/255 }
local COLOR_MIDDLE         = { 0xF5/255, 0xA6/255, 0x23/255 }
local COLOR_OUTER          = { 0x5D/255, 0xB3/255, 0x5D/255 }
local COLOR_TARGET_OUTLINE = { 0x33/255, 0x33/255, 0x33/255 }
local COLOR_TOOL           = { 0x9A/255, 0xA0/255, 0xA6/255 }
local COLOR_TOOL_OUTLINE   = { 0x33/255, 0x33/255, 0x33/255 }
local COLOR_HIGHLIGHT      = { 0.20, 0.95, 1.00 }   -- cyan "armed" ring
local COLOR_TEXT           = { 0.10, 0.10, 0.10 }
local COLOR_TEXT_DIM       = { 0.40, 0.40, 0.40 }

-- ---------- Tunables ----------

local COINS_PER_FLOOR = 5
local COIN_RADIUS_AT_390W = 24                  -- spec: 48px DIAMETER at 390w
local FLOOR_THRESHOLDS = { [1] = 20, [2] = 60, [3] = 120 }

-- Tight per Balatro lesson; the big numbers come from the multiplier chain.
local POINTS = { bull = 5, middle = 3, outer = 1 }

local HUD_HEIGHT       = 64
local BOARD_MARGIN     = 16
-- Per FIX prompt: outer radius <= 18% of board's shortest dim. On 800x600
-- with this layout that's ~85px max; we pick 65px (in spec's 60-70 range)
-- so the target genuinely feels missable.
local TARGET_OUTER_R   = 65
local TARGET_CENTER_Y_FRAC = 0.40   -- target somewhat above middle, room for coin scatter below

-- ---------- Layout (rebuilt on enter / resize) ----------

local L = {}

local function rebuildLayout()
  L.W, L.H = lg.getWidth(), lg.getHeight()
  L.hudH = HUD_HEIGHT
  L.boardX = BOARD_MARGIN
  L.boardY = L.hudH + BOARD_MARGIN
  L.boardW = L.W - 2 * BOARD_MARGIN
  L.boardH = L.H - L.boardY - BOARD_MARGIN

  -- Target circle in the upper portion of the board.
  L.targetCX = L.boardX + L.boardW / 2
  L.targetCY = L.boardY + L.boardH * TARGET_CENTER_Y_FRAC
  L.outerR  = TARGET_OUTER_R
  L.middleR = L.outerR * 0.66
  L.bullR   = L.outerR * 0.33

  -- Coin size: use the spec value (48px diameter) directly. Coins are
  -- intentionally larger than the target -- tappable, not aim-able.
  L.coinR = COIN_RADIUS_AT_390W
  -- Tool size derived from coin radius. Read by drawing AND hit-testing.
  L.toolR = L.coinR * TOOL_R_FACTOR
end

-- ---------- Coin scatter ----------

local function scatterCoins(n, item)
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
    if not placed then break end  -- give up if we can't fit more
  end
  return coins
end

-- ---------- Flip tool (round, follows the cursor) ----------

-- Draws the tool: large translucent grey disc + opaque rim + 6 colored dots
-- around the rim. Three per-dot visual states:
--   ARMED (auto-arm OR conflict selection): thick white outline, r=8.
--   AVAILABLE (in conflict list but not selected): pulsing outline, r=6.
--   INACTIVE: normal colored fill + dark outline, r=6.
local function drawToolAt(x, y, armedDot, conflictDots, conflictCount)
  local toolR = L.toolR
  lg.setColor(COLOR_TOOL[1], COLOR_TOOL[2], COLOR_TOOL[3], 0.50)
  lg.circle("fill", x, y, toolR)
  lg.setColor(COLOR_TOOL_OUTLINE[1], COLOR_TOOL_OUTLINE[2], COLOR_TOOL_OUTLINE[3], 1.0)
  lg.setLineWidth(2)
  lg.circle("line", x, y, toolR)

  local t = lt.getTime()
  local pulse = 0.5 + 0.5 * sin(t * 8)   -- 0..1, ~1.3 Hz

  for d = 1, 6 do
    local dx = x + DOT_UX[d] * toolR
    local dy = y + DOT_UY[d] * toolR
    local col = DOT_COLORS[d]

    local isArmed = (d == armedDot)
    -- "Available" = in conflict list but not currently armed. Linear scan of
    -- up to 6 indices; trivial cost, zero allocation.
    local isAvailable = false
    if conflictDots and conflictCount and conflictCount > 0 and not isArmed then
      for i = 1, conflictCount do
        if conflictDots[i] == d then isAvailable = true; break end
      end
    end

    local r = isArmed and DOT_R_ARMED or DOT_R
    lg.setColor(col[1], col[2], col[3], 1)
    lg.circle("fill", dx, dy, r)

    if isArmed then
      lg.setColor(1, 1, 1, 1)
      lg.setLineWidth(3)
      lg.circle("line", dx, dy, r)
    elseif isAvailable then
      -- Pulsing outline + base dark outline underneath.
      lg.setColor(COLOR_TOOL_OUTLINE[1], COLOR_TOOL_OUTLINE[2], COLOR_TOOL_OUTLINE[3], 1)
      lg.setLineWidth(DOT_OUTLINE)
      lg.circle("line", dx, dy, r)
      lg.setColor(1, 1, 1, 0.30 + pulse * 0.60)
      lg.setLineWidth(2)
      lg.circle("line", dx, dy, r + 2 + pulse * 2)
    else
      lg.setColor(COLOR_TOOL_OUTLINE[1], COLOR_TOOL_OUTLINE[2], COLOR_TOOL_OUTLINE[3], 1)
      lg.setLineWidth(DOT_OUTLINE)
      lg.circle("line", dx, dy, r)
    end
  end
  lg.setColor(1, 1, 1, 1)
end

-- Hint row floating above the contested coin: one small colored dot per
-- conflicting rim point, with the currently selected one highlighted.
local function drawConflictHint(coin, conflictDots, conflictCount, selectedIdx)
  if not coin or not conflictDots or not conflictCount or conflictCount < 2 then return end
  local r = 5
  local spacing = 14
  local totalW = (conflictCount - 1) * spacing
  local hx = coin.x - totalW * 0.5
  local hy = coin.y - coin.radius - r - 16
  lg.setColor(0, 0, 0, 0.75)
  lg.rectangle("fill", hx - r - 6, hy - r - 4, totalW + 2*r + 12, 2*r + 8, 5, 5)
  for i = 1, conflictCount do
    local d = conflictDots[i]
    local col = DOT_COLORS[d]
    local cx = hx + (i - 1) * spacing
    lg.setColor(col[1], col[2], col[3], 1)
    lg.circle("fill", cx, hy, r)
    if i == selectedIdx then
      lg.setColor(1, 1, 1, 1)
      lg.setLineWidth(2)
      lg.circle("line", cx, hy, r + 2)
    else
      lg.setColor(COLOR_TOOL_OUTLINE[1], COLOR_TOOL_OUTLINE[2], COLOR_TOOL_OUTLINE[3], 1)
      lg.setLineWidth(1)
      lg.circle("line", cx, hy, r)
    end
  end
  lg.setColor(1, 1, 1, 1)
end

-- "Armed" ring around the coin the tool circle is currently touching. Drawn
-- after the coins so it remains visible. The ring sits just outside the
-- coin's outline so it doesn't fight with the coin art.
local function drawHighlightFor(coin)
  if not coin then return end
  lg.setColor(COLOR_HIGHLIGHT[1], COLOR_HIGHLIGHT[2], COLOR_HIGHLIGHT[3], 0.90)
  lg.setLineWidth(3)
  lg.circle("line", coin.x, coin.y, coin.radius + 4)
  lg.setColor(1, 1, 1, 1)
end

-- ---------- Region debug overlay (press 'd' to toggle) ----------

-- Authoring/tuning aid: draws each region as an outlined box on top of every
-- live coin, with an arrow showing the launch direction. No allocations -- it
-- iterates the item.regions table that was defined once at load time.
local function drawRegionDebug(coin, item)
  if not coin or coin.used or not item or not item.regions then return end
  local r       = coin.radius
  local cx, cy  = coin.x, coin.y
  local regions = item.regions
  for i = 1, #regions do
    local reg = regions[i]
    local x  = cx + reg.x * r
    local y  = cy + reg.y * r
    local w  = reg.w * r
    local h  = reg.h * r
    lg.setColor(1, 0.2, 0.2, 0.6)
    lg.setLineWidth(1)
    lg.rectangle("line", x, y, w, h)
    -- Launch arrow from box center.
    local mx = x + w * 0.5
    local my = y + h * 0.5
    local arrowLen = r * 0.75
    local ex = mx + cos(reg.angle) * arrowLen
    local ey = my + sin(reg.angle) * arrowLen
    lg.setColor(1, 1, 1, 0.9)
    lg.setLineWidth(2)
    lg.line(mx, my, ex, ey)
    -- Tiny arrowhead dot.
    lg.circle("fill", ex, ey, 2)
  end
  lg.setColor(1, 1, 1, 1)
end

-- Live trajectory preview for the currently-hovered coin: contact dot, the
-- resolved launch arrow at the resolved power, and a sampled arc showing the
-- z (height) lift. Takes the active dot position (the actual contact point).
local function drawHoverDebug(coin, item, dotX, dotY)
  if not coin or not item or not dotX then return end
  local offX, offY, offDist = coin:pressedBy(dotX, dotY)
  if not offX then return end
  local region = coin:regionAt(offX, offY, item)
  if not region then return end
  local angle = region.angle
  local power, arc = resolveShot(item, offDist)
  if region.power then power = region.power end
  if region.arc   then arc   = region.arc   end
  -- Contact point on the coin's surface (post-clamp).
  local contactX = coin.x + offX * coin.radius
  local contactY = coin.y + offY * coin.radius
  lg.setColor(1, 1, 0, 1)
  lg.circle("fill", contactX, contactY, 4)
  -- Direction line at full power.
  local endX = coin.x + cos(angle) * power
  local endY = coin.y + sin(angle) * power
  lg.setColor(0.2, 1, 0.4, 0.85)
  lg.setLineWidth(2)
  lg.line(coin.x, coin.y, endX, endY)
  -- Arc preview (sampled height curve, no allocations).
  lg.setColor(0.2, 0.6, 1, 0.8)
  local px, py = coin.x, coin.y
  for i = 1, 14 do
    local t  = i / 14
    local sx = coin.x + (endX - coin.x) * t
    local sy = coin.y + (endY - coin.y) * t - sin(t * pi) * arc
    lg.line(px, py, sx, sy)
    px, py = sx, sy
  end
  lg.setColor(1, 1, 1, 1)
end

-- ---------- Press resolution ----------

-- Per-frame contact resolution with conflict detection over the 6 rim dots.
--   For each live coin:
--     0 hits  -> no contact
--     1 hit   -> single auto-arm candidate (deepest across all coins wins)
--     2+ hits -> CONFLICT for this coin (first conflict coin wins; the
--                conflicting dot indices are written to outConflict[1..count]
--                in clockwise (dot-index) order, count returned).
-- Returns (coin, dotIdx, count):
--   (nil, nil, 0)         no contact
--   (coin, idx, 0)        auto-arm at dot idx (no conflict)
--   (coin, nil, count>=2) conflict; outConflict[1..count] holds the dot indices
-- outConflict is a list table the caller owns -- we wipe entries 1..6 first.
local function findPressedCoin(coins, toolX, toolY, toolR, outConflict)
  for i = 1, 6 do outConflict[i] = nil end

  local soloCoin, soloDot, soloD2 = nil, nil, huge

  for i = 1, #coins do
    local coin = coins[i]
    if not coin.flipping and not coin.used then
      local cx, cy = coin.x, coin.y
      local r2 = coin.radius * coin.radius
      local hits = 0
      local deepDot, deepD2 = nil, huge
      local in1, in2, in3, in4, in5, in6
      local dx, dy, dsq

      dx = toolX + DOT_UX[1] * toolR - cx
      dy = toolY + DOT_UY[1] * toolR - cy
      dsq = dx*dx + dy*dy
      in1 = dsq < r2
      if in1 then hits = hits + 1; if dsq < deepD2 then deepDot, deepD2 = 1, dsq end end

      dx = toolX + DOT_UX[2] * toolR - cx
      dy = toolY + DOT_UY[2] * toolR - cy
      dsq = dx*dx + dy*dy
      in2 = dsq < r2
      if in2 then hits = hits + 1; if dsq < deepD2 then deepDot, deepD2 = 2, dsq end end

      dx = toolX + DOT_UX[3] * toolR - cx
      dy = toolY + DOT_UY[3] * toolR - cy
      dsq = dx*dx + dy*dy
      in3 = dsq < r2
      if in3 then hits = hits + 1; if dsq < deepD2 then deepDot, deepD2 = 3, dsq end end

      dx = toolX + DOT_UX[4] * toolR - cx
      dy = toolY + DOT_UY[4] * toolR - cy
      dsq = dx*dx + dy*dy
      in4 = dsq < r2
      if in4 then hits = hits + 1; if dsq < deepD2 then deepDot, deepD2 = 4, dsq end end

      dx = toolX + DOT_UX[5] * toolR - cx
      dy = toolY + DOT_UY[5] * toolR - cy
      dsq = dx*dx + dy*dy
      in5 = dsq < r2
      if in5 then hits = hits + 1; if dsq < deepD2 then deepDot, deepD2 = 5, dsq end end

      dx = toolX + DOT_UX[6] * toolR - cx
      dy = toolY + DOT_UY[6] * toolR - cy
      dsq = dx*dx + dy*dy
      in6 = dsq < r2
      if in6 then hits = hits + 1; if dsq < deepD2 then deepDot, deepD2 = 6, dsq end end

      if hits >= 2 then
        -- Pack the conflicting dot indices into outConflict[1..count].
        local count = 0
        if in1 then count = count + 1; outConflict[count] = 1 end
        if in2 then count = count + 1; outConflict[count] = 2 end
        if in3 then count = count + 1; outConflict[count] = 3 end
        if in4 then count = count + 1; outConflict[count] = 4 end
        if in5 then count = count + 1; outConflict[count] = 5 end
        if in6 then count = count + 1; outConflict[count] = 6 end
        return coin, nil, count
      elseif hits == 1 and deepD2 < soloD2 then
        soloCoin, soloDot, soloD2 = coin, deepDot, deepD2
      end
    end
  end

  if soloCoin then return soloCoin, soloDot, 0 end
  return nil, nil, 0
end

-- ---------- Flip resolution ----------

-- 4-tier landing resolution. Pure logic; exposed as Game._resolveFlip for tests.
-- The coin parameter is used for tier-based degradation:
--   * Scoring hits apply Tiers[tier+1].mult to the zone points (min 1).
--   * Missed flips bump coin.tier by 1, capped at 3. Tier never resets.
local function resolveFlip(self, coin, landingX, landingY)
  local dx = landingX - L.targetCX
  local dy = landingY - L.targetCY
  local d2 = dx * dx + dy * dy
  local tierMult = Tiers[(coin.tier or 0) + 1].mult

  if d2 <= L.bullR * L.bullR then
    local gain = max(1, floor(POINTS.bull * tierMult * self.multiplier))
    self.marbles    = self.marbles + gain
    self.multiplier = self.multiplier + 1
    return "bull", gain
  elseif d2 <= L.middleR * L.middleR then
    local gain = max(1, floor(POINTS.middle * tierMult * self.multiplier))
    self.marbles    = self.marbles + gain
    self.multiplier = self.multiplier + 1
    return "middle", gain
  elseif d2 <= L.outerR * L.outerR then
    local gain = max(1, floor(POINTS.outer * tierMult * self.multiplier))
    self.marbles    = self.marbles + gain
    self.multiplier = self.multiplier + 1
    return "outer", gain
  end

  -- Outside the target. Is it still on the board?
  local onBoard =
    landingX >= L.boardX and landingX <= L.boardX + L.boardW and
    landingY >= L.boardY and landingY <= L.boardY + L.boardH

  if onBoard then
    -- Wasted shot: no points, no chain change. Survivable but degrades.
    if coin.tier < 3 then coin.tier = coin.tier + 1 end
    return "on_board_miss", 0
  else
    -- Full miss: chain resets, no points, also degrades.
    if coin.tier < 3 then coin.tier = coin.tier + 1 end
    self.multiplier = 1
    return "off_board_miss", 0
  end
end

-- Shared launch path: used by both the auto-arm click and the WASD
-- conflict-resolution keypress. Computes offset/region/zone curves from a
-- given dot position and fires the coin.
local function fireFlip(self, coin, dotX, dotY)
  local item = self.activeCoinItem
  local offX, offY, offDist = coin:pressedBy(dotX, dotY)
  if not offX then return end
  local region = coin:regionAt(offX, offY, item)
  local angle  = region and region.angle or -pi / 2
  local power, arc = resolveShot(item, offDist)
  if region then
    if region.power then power = region.power end
    if region.arc   then arc   = region.arc   end
  end
  coin:launch(angle, power, arc, item, function(lx, ly)
    local zone, _ = resolveFlip(self, coin, lx, ly)
    if zone == "bull" or zone == "middle" or zone == "outer" then
      coin.used = true  -- scoring hits retire the coin at its current tier
    end
    -- Tier mutation on misses is handled inside resolveFlip.
  end)
  self.activeCoin = coin
end

-- ---------- State lifecycle ----------

function Game:enter(prev, houseName)
  self.houseName  = houseName or "?"
  self.floor      = 1
  self.marbles    = 0
  self.multiplier = 1

  rebuildLayout()

  -- Prototype: every coin in the scatter is the same item (Coin). Future:
  -- per-floor item assignment, varied per scatter spot.
  self.activeCoinItem = Items.byId("coin")
  self.coins          = scatterCoins(COINS_PER_FLOOR, self.activeCoinItem)
  self.activeCoin     = nil  -- the one currently in flight, or nil
  self.hoveredCoin    = nil  -- coin a rim dot is currently inside, if any
  self.hoveredDotIdx  = nil  -- 1..6 auto-arm dot (single in-coin dot), or nil
  -- conflictDots: preallocated list table. After _refreshHover, entries
  -- 1..conflictCount hold the dot indices currently inside hoveredCoin (in
  -- clockwise order). conflictCount >= 2 means we're in conflict.
  -- conflictIdx is the index into conflictDots of the currently SELECTED dot.
  self.conflictDots   = self.conflictDots or {}
  for i = 1, 6 do self.conflictDots[i] = nil end
  self.conflictCount  = 0
  self.conflictIdx    = 1
  -- armedDotIdx is the dot that will actually fire on click. It equals
  -- hoveredDotIdx in the auto-arm case, or conflictDots[conflictIdx] in the
  -- conflict case. Computed by _updateArmed.
  self.armedDotIdx    = nil
  self.armedDotX      = nil
  self.armedDotY      = nil
  -- Tool follows the mouse; initialize to current cursor so it doesn't pop in.
  self.toolX, self.toolY = lm.getPosition()
  self.debugRegions = self.debugRegions or false
  -- Hide the OS cursor on the flip board -- the grey tool circle IS the
  -- pointer. lm.getPosition() still works while the cursor is hidden.
  lm.setVisible(false)
end

function Game:exit()
  -- Restore normal cursor for map/menus.
  lm.setVisible(true)
end

-- Computes armedDotIdx + armedDotX/Y from the current hover/conflict state.
function Game:_updateArmed()
  local idx
  if self.hoveredDotIdx then
    idx = self.hoveredDotIdx
  elseif self.conflictCount > 0 then
    idx = self.conflictDots[self.conflictIdx]
  end
  self.armedDotIdx = idx
  if idx then
    self.armedDotX = self.toolX + DOT_UX[idx] * L.toolR
    self.armedDotY = self.toolY + DOT_UY[idx] * L.toolR
  else
    self.armedDotX = nil
    self.armedDotY = nil
  end
end

-- Recompute hover/conflict state from the current self.toolX / self.toolY.
-- Called by update (every frame) AND mousepressed (so a fresh sample drives
-- the click decision even if the cursor moved since the last frame). Preserves
-- the player's previously-selected conflict dot when possible, so tool jitter
-- doesn't reset their A/D choice.
function Game:_refreshHover()
  local prevHoveredCoin = self.hoveredCoin
  local prevSelectedDot
  if self.conflictCount > 0 then
    prevSelectedDot = self.conflictDots[self.conflictIdx]
  end

  local coin, dotIdx, count = findPressedCoin(
    self.coins, self.toolX, self.toolY, L.toolR, self.conflictDots)
  self.hoveredCoin   = coin
  self.hoveredDotIdx = dotIdx
  self.conflictCount = count

  if count >= 2 then
    -- New conflict OR conflict on a different coin: default to first.
    -- Same-coin refresh: try to keep the previously-selected dot.
    if coin ~= prevHoveredCoin or prevSelectedDot == nil then
      self.conflictIdx = 1
    else
      local newIdx = 1
      for i = 1, count do
        if self.conflictDots[i] == prevSelectedDot then newIdx = i; break end
      end
      self.conflictIdx = newIdx
    end
  else
    self.conflictIdx = 1
  end

  self:_updateArmed()
end

function Game:update(dt)
  -- Sample cursor once per frame; stored on self -- no per-frame allocation.
  self.toolX, self.toolY = lm.getPosition()
  self:_refreshHover()
  for i = 1, #self.coins do self.coins[i]:update(dt) end
  if self.activeCoin and not self.activeCoin.flipping then
    self.activeCoin = nil
  end
end

function Game:draw()
  -- Background.
  lg.setColor(COLOR_BG)
  lg.rectangle("fill", 0, 0, L.W, L.H)

  -- HUD strip.
  lg.setColor(COLOR_TEXT)
  lg.print("MARBLES  " .. self.marbles, 20, 22)
  local multStr = "MULT  x" .. self.multiplier
  local font = lg.getFont()
  lg.print(multStr, L.W - font:getWidth(multStr) - 20, 22)
  -- Floor threshold (secondary).
  lg.setColor(COLOR_TEXT_DIM)
  local threshStr = "FLOOR " .. self.floor .. "   NEED " .. (FLOOR_THRESHOLDS[self.floor] or "?")
  lg.printf(threshStr, 0, 52, L.W, "center")

  -- Board rectangle.
  lg.setColor(COLOR_BOARD)
  lg.rectangle("fill", L.boardX, L.boardY, L.boardW, L.boardH)
  lg.setColor(COLOR_BOARD_BORDER)
  lg.setLineWidth(2)
  lg.rectangle("line", L.boardX, L.boardY, L.boardW, L.boardH)

  -- Target rings (outer first so inner sit on top -- flat fills, no
  -- per-ring outline -- a single outer outline goes on last).
  lg.setColor(COLOR_OUTER)
  lg.circle("fill", L.targetCX, L.targetCY, L.outerR)
  lg.setColor(COLOR_MIDDLE)
  lg.circle("fill", L.targetCX, L.targetCY, L.middleR)
  lg.setColor(COLOR_BULL)
  lg.circle("fill", L.targetCX, L.targetCY, L.bullR)
  lg.setColor(COLOR_TARGET_OUTLINE)
  lg.setLineWidth(2)
  lg.circle("line", L.targetCX, L.targetCY, L.outerR)

  -- Coins.
  for i = 1, #self.coins do self.coins[i]:draw() end

  -- Highlight the coin the tool is currently touching (armed OR in conflict).
  drawHighlightFor(self.hoveredCoin)

  -- Conflict row hint above the contested coin: small colored dots, the
  -- currently selected one highlighted. Only shown when 2+ dots are inside.
  if self.conflictCount >= 2 then
    drawConflictHint(self.hoveredCoin, self.conflictDots,
                     self.conflictCount, self.conflictIdx)
  end

  -- Flip tool follows the cursor. Drawn ON TOP of the coins so you can see
  -- it make contact (translucent fill lets the coin show through). The
  -- armed dot gets a white outline; conflict-available dots get a pulse.
  drawToolAt(self.toolX, self.toolY, self.armedDotIdx,
             self.conflictDots, self.conflictCount)

  -- Region debug overlay (press 'd' to toggle). On top of everything.
  if self.debugRegions then
    for i = 1, #self.coins do
      drawRegionDebug(self.coins[i], self.activeCoinItem)
    end
    drawHoverDebug(self.hoveredCoin, self.activeCoinItem,
                   self.armedDotX, self.armedDotY)
  end

  -- Bottom hint (temporary; replaced when the run/shop flow lands).
  lg.setColor(COLOR_TEXT_DIM)
  lg.printf("HOUSE: " .. self.houseName .. "   [M] map   [R] reset   [G] debug   [Esc] quit",
    0, L.H - 24, L.W, "center")
  lg.setColor(1, 1, 1, 1)
end

-- ---------- Input ----------

function Game:mousepressed(x, y, button)
  if button ~= 1 then return end
  if self.activeCoin then return end                 -- one flip at a time
  -- Re-sample so the click decision uses the freshest cursor position.
  self.toolX, self.toolY = x, y
  self:_refreshHover()
  if not self.armedDotIdx then return end            -- no dot inside any coin
  fireFlip(self, self.hoveredCoin, self.armedDotX, self.armedDotY)
end

function Game:keypressed(k)
  -- A/D and left/right cycle through the conflicting dots when 2+ are inside
  -- the same coin. They do NOTHING when there is no conflict. The cycle
  -- wraps. Click is still the trigger -- selection just changes which dot.
  if not self.activeCoin and self.conflictCount > 1 then
    if k == "a" or k == "left" then
      self.conflictIdx = self.conflictIdx - 1
      if self.conflictIdx < 1 then self.conflictIdx = self.conflictCount end
      self:_updateArmed()
      return
    elseif k == "d" or k == "right" then
      self.conflictIdx = self.conflictIdx + 1
      if self.conflictIdx > self.conflictCount then self.conflictIdx = 1 end
      self:_updateArmed()
      return
    end
  end
  if k == "m" then
    StateMachine.switch("map")
  elseif k == "r" then
    Game:enter(nil, self.houseName)
  elseif k == "g" then
    self.debugRegions = not self.debugRegions
  end
end

-- ---------- Test hooks ----------

Game._resolveFlip     = resolveFlip
Game._findPressedCoin = findPressedCoin
Game._resolveShot     = resolveShot
Game._L               = L  -- layout table (read after enter())

return Game

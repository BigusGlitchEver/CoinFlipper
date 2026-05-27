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
-- agree on the same number. 2.5x coin radius (== 60px at coinR=24) makes the
-- tool large enough that the player is consciously aiming a specific rim dot
-- at a coin, not hovering the tool center over it.
local TOOL_R_FACTOR = 2.5

-- ---------- Rim dots (the actual coin colliders) ----------
-- Four dots at the tool's compass points. Indices: 1=top, 2=right,
-- 3=bottom, 4=left. Precomputed unit-vector offsets so per-frame draw and
-- hit-test do zero allocation.
local DOT_UX     = { 0, 1, 0, -1 }   -- cos(theta) for top/right/bottom/left
local DOT_UY     = { -1, 0, 1, 0 }   -- sin(theta) (screen-space, +y = down)
local DOT_R      = 6                  -- dot fill radius in pixels
local DOT_OUTLINE = 1.5               -- dot outline width
local DOT_COLORS = {
  { 0xFF/255, 0x44/255, 0x44/255 },  -- top    red
  { 0xFF/255, 0xDD/255, 0x00/255 },  -- right  yellow
  { 0x44/255, 0xCC/255, 0x44/255 },  -- bottom green
  { 0x33/255, 0xCC/255, 0xFF/255 },  -- left   cyan
}

-- WASD <-> dot mapping (used ONLY to resolve an active conflict). Outside
-- of an active conflict these keys are ignored entirely.
local KEY_TO_DOT = { w = 1, d = 2, s = 3, a = 4 }
local DOT_TO_KEY = { "W", "D", "S", "A" }

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

-- Draws the tool: large translucent grey disc + opaque rim + 4 colored dots
-- at the compass points (the only colliders). `activeDot` (1-4 or nil) gets
-- a solid white halo (auto-armed). `conflictDots` is a 4-bool table; any dot
-- with conflictDots[d] == true gets a YELLOW PULSING halo + WASD letter so
-- the player can see a tiebreaker is required.
local function drawToolAt(x, y, activeDot, conflictDots)
  local toolR = L.toolR
  lg.setColor(COLOR_TOOL[1], COLOR_TOOL[2], COLOR_TOOL[3], 0.50)
  lg.circle("fill", x, y, toolR)
  lg.setColor(COLOR_TOOL_OUTLINE[1], COLOR_TOOL_OUTLINE[2], COLOR_TOOL_OUTLINE[3], 1.0)
  lg.setLineWidth(2)
  lg.circle("line", x, y, toolR)

  local t = lt.getTime()
  local pulse = 0.5 + 0.5 * sin(t * 8)   -- 0..1, ~1.3 Hz

  for d = 1, 4 do
    local dx = x + DOT_UX[d] * toolR
    local dy = y + DOT_UY[d] * toolR
    local col = DOT_COLORS[d]
    lg.setColor(col[1], col[2], col[3], 1)
    lg.circle("fill", dx, dy, DOT_R)
    lg.setColor(COLOR_TOOL_OUTLINE[1], COLOR_TOOL_OUTLINE[2], COLOR_TOOL_OUTLINE[3], 1)
    lg.setLineWidth(DOT_OUTLINE)
    lg.circle("line", dx, dy, DOT_R)

    if d == activeDot then
      -- Auto-armed: solid white halo.
      lg.setColor(1, 1, 1, 0.95)
      lg.setLineWidth(2)
      lg.circle("line", dx, dy, DOT_R + 3)
    elseif conflictDots and conflictDots[d] then
      -- Conflict: yellow pulsing halo + the WASD letter floating outward.
      lg.setColor(1, 1, 0.3, 0.30 + pulse * 0.65)
      lg.setLineWidth(2)
      lg.circle("line", dx, dy, DOT_R + 3 + pulse * 3)
      local label = DOT_TO_KEY[d]
      local font  = lg.getFont()
      local lw    = font:getWidth(label)
      local lh    = font:getHeight()
      -- Push the letter further away from tool center.
      local lx = dx + DOT_UX[d] * 14 - lw * 0.5
      local ly = dy + DOT_UY[d] * 14 - lh * 0.5
      lg.setColor(0, 0, 0, 0.75)
      lg.rectangle("fill", lx - 4, ly - 2, lw + 8, lh + 4, 4, 4)
      lg.setColor(1, 1, 0.4, 1)
      lg.print(label, lx, ly)
    end
  end
  lg.setColor(1, 1, 1, 1)
end

-- Small "W / D" style prompt floating above the contested coin so the
-- decision is obvious even if the player's eyes are on the coin, not the tool.
local function drawConflictHint(coin, conflictDots)
  if not coin or not conflictDots then return end
  -- Build the hint text without allocating intermediate junk: count keys first.
  local count = 0
  for d = 1, 4 do if conflictDots[d] then count = count + 1 end end
  if count < 2 then return end
  -- Compose "W / S" once -- a single string concat per frame is acceptable.
  local text = nil
  for d = 1, 4 do
    if conflictDots[d] then
      text = text and (text .. " / " .. DOT_TO_KEY[d]) or DOT_TO_KEY[d]
    end
  end
  local font = lg.getFont()
  local tw   = font:getWidth(text)
  local th   = font:getHeight()
  local hx   = coin.x - tw * 0.5
  local hy   = coin.y - coin.radius - th - 14
  lg.setColor(0, 0, 0, 0.78)
  lg.rectangle("fill", hx - 8, hy - 4, tw + 16, th + 8, 6, 6)
  lg.setColor(1, 1, 0.4, 1)
  lg.print(text, hx, hy)
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

-- Per-frame contact resolution with conflict detection.
--   For each live coin, count how many rim dots sit inside it.
--     0 dots         -> no contact for that coin.
--     1 dot          -> single-arm candidate (deepest single across all
--                       coins wins, as before).
--     2+ dots        -> CONFLICT for that coin. The first coin found in
--                       conflict short-circuits everything (no auto-arm) and
--                       outConflict[d] is set true for each dot inside it.
--                       The player must press a matching WASD key.
-- Returns (coin, dotIdx). dotIdx == nil + coin set -> conflict; nil + nil -> no contact.
-- outConflict is a 4-element table the caller owns; we reset and (maybe) populate it.
local function findPressedCoin(coins, toolX, toolY, toolR, outConflict)
  -- Always reset the conflict mask first.
  outConflict[1] = false
  outConflict[2] = false
  outConflict[3] = false
  outConflict[4] = false

  -- Precompute the four dot positions once (stack-local scalars, no alloc).
  local d1x = toolX + DOT_UX[1] * toolR; local d1y = toolY + DOT_UY[1] * toolR
  local d2x = toolX + DOT_UX[2] * toolR; local d2y = toolY + DOT_UY[2] * toolR
  local d3x = toolX + DOT_UX[3] * toolR; local d3y = toolY + DOT_UY[3] * toolR
  local d4x = toolX + DOT_UX[4] * toolR; local d4y = toolY + DOT_UY[4] * toolR

  local soloCoin, soloDot, soloD2 = nil, nil, huge

  for i = 1, #coins do
    local coin = coins[i]
    if not coin.flipping and not coin.used then
      local cx, cy = coin.x, coin.y
      local r2 = coin.radius * coin.radius
      local hits = 0
      local deepDot, deepD2 = nil, huge

      local dx, dy, dsq
      dx = d1x - cx; dy = d1y - cy; dsq = dx*dx + dy*dy
      local in1 = dsq < r2
      if in1 then hits = hits + 1; if dsq < deepD2 then deepDot, deepD2 = 1, dsq end end

      dx = d2x - cx; dy = d2y - cy; dsq = dx*dx + dy*dy
      local in2 = dsq < r2
      if in2 then hits = hits + 1; if dsq < deepD2 then deepDot, deepD2 = 2, dsq end end

      dx = d3x - cx; dy = d3y - cy; dsq = dx*dx + dy*dy
      local in3 = dsq < r2
      if in3 then hits = hits + 1; if dsq < deepD2 then deepDot, deepD2 = 3, dsq end end

      dx = d4x - cx; dy = d4y - cy; dsq = dx*dx + dy*dy
      local in4 = dsq < r2
      if in4 then hits = hits + 1; if dsq < deepD2 then deepDot, deepD2 = 4, dsq end end

      if hits >= 2 then
        -- Conflict on this coin takes precedence over any other contact.
        outConflict[1] = in1
        outConflict[2] = in2
        outConflict[3] = in3
        outConflict[4] = in4
        return coin, nil
      elseif hits == 1 and deepD2 < soloD2 then
        soloCoin, soloDot, soloD2 = coin, deepDot, deepD2
      end
    end
  end

  if soloCoin then return soloCoin, soloDot end
  return nil
end

-- ---------- Flip resolution ----------

-- 4-tier landing resolution. Pure logic; exposed as Game._resolveFlip for tests.
local function resolveFlip(self, landingX, landingY)
  local dx = landingX - L.targetCX
  local dy = landingY - L.targetCY
  local d2 = dx * dx + dy * dy

  if d2 <= L.bullR * L.bullR then
    local gain = POINTS.bull * self.multiplier
    self.marbles    = self.marbles + gain
    self.multiplier = self.multiplier + 1
    return "bull", gain
  elseif d2 <= L.middleR * L.middleR then
    local gain = POINTS.middle * self.multiplier
    self.marbles    = self.marbles + gain
    self.multiplier = self.multiplier + 1
    return "middle", gain
  elseif d2 <= L.outerR * L.outerR then
    local gain = POINTS.outer * self.multiplier
    self.marbles    = self.marbles + gain
    self.multiplier = self.multiplier + 1
    return "outer", gain
  end

  -- Outside the target. Is it still on the board?
  local onBoard =
    landingX >= L.boardX and landingX <= L.boardX + L.boardW and
    landingY >= L.boardY and landingY <= L.boardY + L.boardH

  if onBoard then
    -- Wasted shot: no points, no chain change. Survivable.
    return "on_board_miss", 0
  else
    -- Full miss: chain resets, no points.
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
    local zone, _ = resolveFlip(self, lx, ly)
    if zone == "bull" or zone == "middle" or zone == "outer" then
      coin.used = true
    end
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
  self.hoveredDotIdx  = nil  -- 1..4 (top/right/bottom/left) or nil
  self.hoveredDotX    = nil  -- screen position of the active dot
  self.hoveredDotY    = nil
  -- conflictDots: preallocated 4-bool table reset every frame by _refreshHover.
  -- When self.hoveredCoin is set but self.hoveredDotIdx is nil, ANY true entry
  -- in this table means the corresponding dot is in conflict (WASD required).
  self.conflictDots   = self.conflictDots or { false, false, false, false }
  for d = 1, 4 do self.conflictDots[d] = false end
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

-- Recompute hover/conflict state from the current self.toolX / self.toolY.
-- Called by update (every frame) AND mousepressed (so a fresh sample drives
-- the click decision even if the cursor moved since the last frame).
function Game:_refreshHover()
  local coin, dotIdx = findPressedCoin(
    self.coins, self.toolX, self.toolY, L.toolR, self.conflictDots)
  self.hoveredCoin   = coin
  self.hoveredDotIdx = dotIdx
  if dotIdx then
    self.hoveredDotX = self.toolX + DOT_UX[dotIdx] * L.toolR
    self.hoveredDotY = self.toolY + DOT_UY[dotIdx] * L.toolR
  else
    self.hoveredDotX = nil
    self.hoveredDotY = nil
  end
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

  -- Conflict prompt: "W / S" style hint floating above the contested coin.
  -- Only fires when hoveredCoin is set AND no single dot was auto-armed.
  if self.hoveredCoin and not self.hoveredDotIdx then
    drawConflictHint(self.hoveredCoin, self.conflictDots)
  end

  -- Flip tool follows the cursor. Drawn ON TOP of the coins so you can see
  -- it make contact (translucent fill lets the coin show through). The
  -- active dot (if any) gets a white halo; conflicting dots get yellow pulses.
  drawToolAt(self.toolX, self.toolY, self.hoveredDotIdx,
             (self.hoveredCoin and not self.hoveredDotIdx) and self.conflictDots or nil)

  -- Region debug overlay (press 'd' to toggle). On top of everything.
  if self.debugRegions then
    for i = 1, #self.coins do
      drawRegionDebug(self.coins[i], self.activeCoinItem)
    end
    drawHoverDebug(self.hoveredCoin, self.activeCoinItem,
                   self.hoveredDotX, self.hoveredDotY)
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
  if not self.hoveredCoin then return end            -- no dot inside any coin
  if not self.hoveredDotIdx then return end          -- conflict: WASD required
  fireFlip(self, self.hoveredCoin, self.hoveredDotX, self.hoveredDotY)
end

function Game:keypressed(k)
  -- WASD ONLY does something when an active conflict is on screen and the
  -- pressed key matches one of the conflicting dots. Outside conflict, WASD
  -- keys are ignored entirely (per spec). Debug toggle moved to 'g' so it
  -- doesn't collide with 'd' = right dot.
  local dot = KEY_TO_DOT[k]
  if dot
     and not self.activeCoin
     and self.hoveredCoin and not self.hoveredDotIdx
     and self.conflictDots[dot] then
    local toolR = L.toolR
    local dotX = self.toolX + DOT_UX[dot] * toolR
    local dotY = self.toolY + DOT_UY[dot] * toolR
    fireFlip(self, self.hoveredCoin, dotX, dotY)
    return
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

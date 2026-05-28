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
-- agree on the same number. 1.5x coin radius (== 36px at coinR=24) gives
-- enough rim room that adjacent coins can each be "claimed" by a different
-- dot, which is what enables cross-coin conflict. The rim dots scale with
-- toolR so the whole assembly grows together.
local TOOL_R_FACTOR = 1.5

-- ---------- Rim dots & Simon Says arc bars ----------
-- The 6 contact "dots" are still single points for collision (one per 60deg
-- around the rim, starting at 270deg = top, going clockwise). VISUALLY they
-- render as a Simon-Says wheel of 6 colored arc panels with darker center
-- marks at the exact dot angles. Indices/colors match what was here before:
--   1 = 270 (top)          red     #FF4444   dark #992222
--   2 = 330 (top-right)    orange  #FF9933   dark #995511
--   3 =  30 (bottom-right) yellow  #FFDD00   dark #998800
--   4 =  90 (bottom)       green   #44CC44   dark #227722
--   5 = 150 (bottom-left)  cyan    #33CCFF   dark #116688
--   6 = 210 (top-left)     purple  #AA44FF   dark #551188
-- Unit vectors + per-bar angle constants precomputed at file load.
local DOT_UX, DOT_UY      = {}, {}
local DOT_ANGLES_RAD      = {}    -- center angle of each bar in radians
do
  local angles = { 270, 330, 30, 90, 150, 210 }
  for i = 1, 6 do
    local rad = angles[i] * pi / 180
    DOT_UX[i]         = cos(rad)
    DOT_UY[i]         = sin(rad)
    DOT_ANGLES_RAD[i] = rad
  end
end
local BAR_HALF_WIDTH      = 28 * pi / 180   -- half of 56deg panel arc
local CENTER_HALF         = 10 * pi / 180   -- half of 20deg dark center mark
local BAR_LINE_WIDTH      =  9              -- normal panel thickness
local BAR_LINE_WIDTH_AVAIL = 12             -- "available in conflict" thickness
local BAR_OUTLINE_OFFSET  =  7              -- white halo arc radius offset
local DOT_COLORS = {
  { 0xFF/255, 0x44/255, 0x44/255 },  -- 1 red
  { 0xFF/255, 0x99/255, 0x33/255 },  -- 2 orange
  { 0xFF/255, 0xDD/255, 0x00/255 },  -- 3 yellow
  { 0x44/255, 0xCC/255, 0x44/255 },  -- 4 green
  { 0x33/255, 0xCC/255, 0xFF/255 },  -- 5 cyan
  { 0xAA/255, 0x44/255, 0xFF/255 },  -- 6 purple
}
local DOT_COLORS_DARK = {
  { 0x99/255, 0x22/255, 0x22/255 },  -- 1 dark red
  { 0x99/255, 0x55/255, 0x11/255 },  -- 2 dark orange
  { 0x99/255, 0x88/255, 0x00/255 },  -- 3 dark yellow
  { 0x22/255, 0x77/255, 0x22/255 },  -- 4 dark green
  { 0x11/255, 0x66/255, 0x88/255 },  -- 5 dark cyan
  { 0x55/255, 0x11/255, 0x88/255 },  -- 6 dark purple
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
  -- A rim dot engages a coin when its distance from the coin's center is
  -- under (coin.radius + grabMargin). This lets a dot "grab" a coin from
  -- just outside its outline -- crucial for cross-coin conflict, since the
  -- tool sitting between two adjacent coins gets a different dot to reach
  -- toward each. Computed once per layout rebuild -- no per-frame math.
  L.grabMargin = floor(L.coinR * 0.6)  -- ~14px at coinR=24
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

-- Draws the tool as a Simon-Says wheel: translucent grey hub + 6 colored
-- arc panels around the rim with darker center marks at the exact dot
-- contact angles. Three per-bar visual states:
--   ARMED      : base color + bright dark-center mark + white halo arc
--                just outside the bar.
--   AVAILABLE  : (in conflict list but not selected) thicker pulsing fill.
--   INACTIVE   : base color, normal thickness, no halo.
-- conflictDots entries are {idx, coin} pairs; we just need the idx for "is
-- this bar in the conflict list?" so we don't allocate when reading.
local function drawToolAt(x, y, armedDot, conflictDots, conflictCount)
  local toolR = L.toolR
  -- Hub disc (translucent so coins underneath show through).
  lg.setColor(COLOR_TOOL[1], COLOR_TOOL[2], COLOR_TOOL[3], 0.45)
  lg.circle("fill", x, y, toolR - 4)

  local t = lt.getTime()
  local pulse = 0.5 + 0.5 * sin(t * 8)

  for d = 1, 6 do
    local cAng = DOT_ANGLES_RAD[d]
    local a1   = cAng - BAR_HALF_WIDTH
    local a2   = cAng + BAR_HALF_WIDTH
    local cm1  = cAng - CENTER_HALF
    local cm2  = cAng + CENTER_HALF
    local col  = DOT_COLORS[d]
    local dark = DOT_COLORS_DARK[d]

    local isArmed = (d == armedDot)
    local isAvailable = false
    if not isArmed and conflictCount and conflictCount > 1 then
      for i = 1, conflictCount do
        if conflictDots[i].idx == d then isAvailable = true; break end
      end
    end

    -- Main bar arc.
    if isAvailable then
      lg.setLineWidth(BAR_LINE_WIDTH_AVAIL)
      lg.setColor(col[1], col[2], col[3], 0.55 + pulse * 0.45)
    else
      lg.setLineWidth(BAR_LINE_WIDTH)
      lg.setColor(col[1], col[2], col[3], 1)
    end
    lg.arc("line", "open", x, y, toolR, a1, a2)

    -- Dark center mark at the exact dot angle. When armed it's pushed brighter
    -- (interpolated 50% toward white) to mark the chosen contact.
    if isArmed then
      lg.setColor((dark[1] + 1) * 0.5, (dark[2] + 1) * 0.5, (dark[3] + 1) * 0.5, 1)
    else
      lg.setColor(dark[1], dark[2], dark[3], 1)
    end
    lg.setLineWidth(BAR_LINE_WIDTH)
    lg.arc("line", "open", x, y, toolR, cm1, cm2)

    -- Armed halo: thin white arc just outside the bar.
    if isArmed then
      lg.setColor(1, 1, 1, 1)
      lg.setLineWidth(1.5)
      lg.arc("line", "open", x, y, toolR + BAR_OUTLINE_OFFSET, a1, a2)
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

-- Per-dot nearest-coin resolution within the grab zone. EACH of the 6 rim
-- dots contributes AT MOST ONE pair: for that dot, find the NEAREST live
-- flippable coin whose center is within (coin.radius + L.grabMargin) of the
-- dot. A dot near two coins picks the closer one; a dot near none contributes
-- nothing. Each entry in outConflict is a preallocated {idx, coin} slot
-- mutated in place (zero per-frame allocation).
--
-- Returns count only:
--   0  -> no contact
--   1  -> auto-arm (single pair; caller uses outConflict[1])
--   2+ -> conflict (player cycles through outConflict[1..count] with A/D)
local function findPressedCoin(coins, toolX, toolY, toolR, outConflict)
  local grab  = L.grabMargin
  local count = 0
  for d = 1, 6 do
    local dxd = toolX + DOT_UX[d] * toolR
    local dyd = toolY + DOT_UY[d] * toolR
    -- Find the closest live coin this dot can engage.
    local bestCoin, bestD2 = nil, huge
    for i = 1, #coins do
      local coin = coins[i]
      if not coin.flipping and not coin.used then
        local dx    = dxd - coin.x
        local dy    = dyd - coin.y
        local d2    = dx * dx + dy * dy
        local reach = coin.radius + grab
        if d2 < (reach * reach) and d2 < bestD2 then
          bestCoin = coin
          bestD2   = d2
        end
      end
    end
    if bestCoin then
      count = count + 1
      local slot = outConflict[count]
      slot.idx  = d
      slot.coin = bestCoin
    end
  end
  return count
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
  self.hoveredCoin    = nil  -- coin of the currently selected pair (any state)
  -- conflictDots: preallocated list of {idx, coin} PAIR slots. After
  -- _refreshHover, entries 1..conflictCount hold every (dot, coin) pair where
  -- a rim dot is inside a live coin -- across ALL coins, not just one.
  --   conflictCount = 0  -> nothing armed; click does nothing.
  --   conflictCount = 1  -> auto-armed pair; click fires immediately.
  --   conflictCount >= 2 -> conflict; player cycles with A/D + arrow keys.
  -- conflictIdx is the index into conflictDots of the currently SELECTED pair.
  self.conflictDots   = self.conflictDots or {}
  for i = 1, 6 do
    self.conflictDots[i] = self.conflictDots[i] or { idx = 0, coin = nil }
    self.conflictDots[i].idx  = 0
    self.conflictDots[i].coin = nil
  end
  self.conflictCount  = 0
  self.conflictIdx    = 1
  -- armedDotIdx is the dot that will actually fire on click; computed from
  -- the currently selected pair by _updateArmed.
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

-- Computes hoveredCoin + armedDotIdx + armedDotX/Y from the currently
-- selected pair in self.conflictDots. count==0 -> nothing armed; count==1
-- auto-arms that pair; count>=2 uses the conflictIdx pair.
function Game:_updateArmed()
  if self.conflictCount == 0 then
    self.hoveredCoin = nil
    self.armedDotIdx = nil
    self.armedDotX   = nil
    self.armedDotY   = nil
    return
  end
  local i = (self.conflictCount == 1) and 1 or self.conflictIdx
  local pair = self.conflictDots[i]
  self.hoveredCoin = pair.coin
  self.armedDotIdx = pair.idx
  self.armedDotX   = self.toolX + DOT_UX[pair.idx] * L.toolR
  self.armedDotY   = self.toolY + DOT_UY[pair.idx] * L.toolR
end

-- Recompute hover/conflict state from the current self.toolX / self.toolY.
-- Called by update (every frame) AND mousepressed (so a fresh sample drives
-- the click decision). Preserves the player's previously-selected PAIR (by
-- idx + coin identity) across tool jitter so A/D choices don't reset.
function Game:_refreshHover()
  local prevIdx, prevCoin
  if self.conflictCount > 0 then
    local prev = self.conflictDots[self.conflictIdx]
    if prev then prevIdx, prevCoin = prev.idx, prev.coin end
  end

  local count = findPressedCoin(
    self.coins, self.toolX, self.toolY, L.toolR, self.conflictDots)
  self.conflictCount = count

  if count <= 1 then
    self.conflictIdx = 1
  else
    -- Try to preserve previous (idx, coin) selection.
    local newIdx = 1
    if prevIdx then
      for i = 1, count do
        local p = self.conflictDots[i]
        if p.idx == prevIdx and p.coin == prevCoin then newIdx = i; break end
      end
    end
    self.conflictIdx = newIdx
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

  -- Highlight the coin the tool will fire against (auto-arm OR selected pair).
  drawHighlightFor(self.hoveredCoin)

  -- Flip tool follows the cursor. Simon-Says wheel: 6 arc panels around the
  -- rim with dark center marks at the exact contact angles. The armed bar
  -- gets a white halo; conflict-available bars pulse thicker.
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
  -- A/D and left/right cycle through ALL active (dot, coin) pairs whenever
  -- 2+ rim dots are engaged with any coins (same coin OR different coins).
  -- They do NOTHING when fewer than 2 pairs are engaged. The cycle wraps.
  -- Click is still the trigger -- selection just chooses which pair fires.
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

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
local SLIVER_HALF_WIDTH = 9 * pi / 180   -- half-width of interior sliver tab
local SLIVER_LINE_WIDTH = 5              -- sliver arc line width
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

local TOOL_CIRCLE   = "circle"
local TOOL_TRIANGLE = "triangle"

-- Triangle tip unit vectors (equilateral, tip pointing up).
-- Angles: 270 deg (top), 30 deg (bottom-right), 150 deg (bottom-left).
local TRI_UX = {}
local TRI_UY = {}
do
  local triAngles = { 270, 30, 150 }
  for _ti = 1, 3 do
    local rad = triAngles[_ti] * pi / 180
    TRI_UX[_ti] = cos(rad)
    TRI_UY[_ti] = sin(rad)
  end
end
local TRI_COLORS = {
  { 1.00, 0.60, 0.15 },  -- tip 1: amber (top)
  { 0.15, 0.85, 0.60 },  -- tip 2: teal  (bottom-right)
  { 0.75, 0.15, 1.00 },  -- tip 3: violet (bottom-left)
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
local COLOR_PANEL          = { 0x22/255, 0x22/255, 0x22/255 }  -- left panel bg
local COLOR_BORDER         = { 0x33/255, 0x33/255, 0x33/255 }  -- board border frame
-- Left panel scoreboard UI (pre-declared; no draw-time allocation).
local COLOR_PANEL_LABEL    = { 0.55, 0.55, 0.55 }
local COLOR_PANEL_VALUE    = { 1.00, 1.00, 1.00 }
local COLOR_MULT_ACTIVE    = { 1.00, 0.85, 0.25 }  -- gold when chain active
local COLOR_MULT_IDLE      = { 0.45, 0.45, 0.45 }  -- dim when x1
local COLOR_BTN            = { 0.28, 0.28, 0.28 }
local COLOR_BTN_BORDER     = { 0.48, 0.48, 0.48 }
local COLOR_BTN_TEXT       = { 0.78, 0.78, 0.78 }
local COLOR_DEBUG_ON       = { 0.25, 0.80, 0.35 }
local COLOR_TOOL_ACTIVE    = { 0.25, 0.60, 1.00 }  -- blue tint for selected tool btn

-- ---------- Tunables ----------

local COINS_PER_FLOOR = 5
local COIN_RADIUS_AT_390W = 24                  -- spec: 48px DIAMETER at 390w
local FLOOR_THRESHOLDS = { [1] = 20, [2] = 60, [3] = 120 }
local NUM_FLOORS        = 3

-- Tight per Balatro lesson; the big numbers come from the multiplier chain.
local POINTS = { bull = 5, middle = 3, outer = 1 }

local PANEL_W   = 220   -- left score panel width
local BORDER_T  = 10    -- board border thickness (pixels each side)
local MARGIN    = 12    -- gap between screen edge/panel and border outer edge
-- outerR <= 18% of board shortest dim; 65px sits in spec 60-70 range.
local TARGET_OUTER_R = 65

-- ---------- Layout (rebuilt on enter / resize) ----------

local L = {}

local function rebuildLayout()
  L.W, L.H = lg.getWidth(), lg.getHeight()

  -- Left score panel.
  L.panelX = 0
  L.panelW = PANEL_W
  L.panelH = L.H

  -- Outer border frame.
  L.borderX = PANEL_W + MARGIN
  L.borderY = MARGIN
  L.borderW = L.W - L.borderX - MARGIN
  L.borderH = L.H - MARGIN * 2

  -- Inner playing surface (inset BORDER_T on all sides).
  L.boardX = L.borderX + BORDER_T
  L.boardY = L.borderY + BORDER_T
  L.boardW = L.borderW - BORDER_T * 2
  L.boardH = L.borderH - BORDER_T * 2

  L.outerR  = TARGET_OUTER_R
  L.middleR = L.outerR * 0.66
  L.bullR   = L.outerR * 0.33

  -- Coin size: use the spec value (48px diameter) directly. Coins are
  -- intentionally larger than the target -- tappable, not aim-able.
  L.coinR = COIN_RADIUS_AT_390W
  -- Tool size derived from coin radius. Read by drawing AND hit-testing.
  L.toolR = L.coinR * TOOL_R_FACTOR
  -- NOTE: targetCX/CY are NOT set here; they are randomised in Game:enter
  -- each floor so they differ between runs.
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
      -- Also reject positions that overlap the target ring.
      if ok then
        local tdx = x - L.targetCX
        local tdy = y - L.targetCY
        local tThresh = L.outerR + L.coinR + 8
        if (tdx * tdx + tdy * tdy) < (tThresh * tThresh) then ok = false end
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

-- scatterBoard: places 1 Mid coin + 2 Easy coins with spacing and target
-- exclusion checks. Returns a table of Coin instances with itemType set.
local function scatterBoard()
  local easyR    = floor(L.coinR * Tiers.EASY_COIN_RADIUS_SCALE)
  local miniR    = floor(L.coinR * Tiers.MINI_COIN_RADIUS_SCALE)
  local midItem  = Items.byId("coin")
  local easyItem = Items.byId("easy_coin")
  local miniItem = Items.byId("mini_coin")
  local hardItem = Items.byId("hard_coin")
  local specs = {
    { radius = L.coinR, itemType = "coin",      item = midItem  },
    { radius = easyR,   itemType = "easy_coin", item = easyItem },
    { radius = easyR,   itemType = "easy_coin", item = easyItem },
    { radius = miniR,   itemType = "mini_coin", item = miniItem },
    { radius = L.coinR, itemType = "hard_coin", item = hardItem },
  }
  local coins       = {}
  local maxAttempts = 60
  for _, spec in ipairs(specs) do
    local cr = spec.radius
    for attempt = 1, maxAttempts do
      local x = love.math.random(floor(L.boardX + cr), floor(L.boardX + L.boardW - cr))
      local y = love.math.random(floor(L.boardY + cr), floor(L.boardY + L.boardH - cr))
      local ok = true
      for j = 1, #coins do
        local c = coins[j]
        local dx, dy = x - c.x, y - c.y
        local sep = cr + c.radius + 12
        if (dx * dx + dy * dy) < (sep * sep) then ok = false; break end
      end
      if ok then
        local tdx, tdy = x - L.targetCX, y - L.targetCY
        local tThresh = L.outerR + cr + 8
        if (tdx * tdx + tdy * tdy) < (tThresh * tThresh) then ok = false end
      end
      if ok then
        local c = Coin(x, y, cr)
        c.itemType = spec.itemType
        coins[#coins + 1] = c
        break
      end
    end
  end
  return coins
end

-- ---------- Flip tool (round, follows the cursor) ----------

-- Triangle tool: equilateral triangle (tip pointing up). The three vertices
-- ARE the contact points; no external dots. Tips highlight when armed.
-- Triangle tool: translucent body + clean edge outline. The edges ARE the contact surface.
local function drawTriangleToolAt(x, y)
  local r   = L.toolR
  local v1x = x + TRI_UX[1] * r;  local v1y = y + TRI_UY[1] * r
  local v2x = x + TRI_UX[2] * r;  local v2y = y + TRI_UY[2] * r
  local v3x = x + TRI_UX[3] * r;  local v3y = y + TRI_UY[3] * r
  lg.setColor(COLOR_TOOL[1], COLOR_TOOL[2], COLOR_TOOL[3], 0.22)
  lg.polygon("fill", v1x, v1y, v2x, v2y, v3x, v3y)
  lg.setColor(COLOR_TOOL_OUTLINE[1], COLOR_TOOL_OUTLINE[2], COLOR_TOOL_OUTLINE[3], 0.75)
  lg.setLineWidth(2)
  lg.polygon("line", v1x, v1y, v2x, v2y, v3x, v3y)
  lg.setColor(1, 1, 1, 1)
end

-- Draws the tool as a Simon-Says wheel: translucent grey hub + 6 colored
-- arc panels around the rim with darker center marks at the exact dot
-- contact angles. Three per-bar visual states:
--   ARMED      : base color + bright dark-center mark + white halo arc
--                just outside the bar.
--   AVAILABLE  : (in conflict list but not selected) thicker pulsing fill.
--   INACTIVE   : base color, normal thickness, no halo.
-- conflictDots entries are {idx, coin} pairs; we just need the idx for "is
-- this bar in the conflict list?" so we don't allocate when reading.
-- Circle tool: translucent disc + clean rim ring. The rim IS the contact surface.
local function drawToolAt(x, y)
  local toolR = L.toolR
  lg.setColor(COLOR_TOOL[1], COLOR_TOOL[2], COLOR_TOOL[3], 0.30)
  lg.circle("fill", x, y, toolR)
  lg.setColor(COLOR_TOOL_OUTLINE[1], COLOR_TOOL_OUTLINE[2], COLOR_TOOL_OUTLINE[3], 0.75)
  lg.setLineWidth(2)
  lg.circle("line", x, y, toolR)
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

-- Per-dot STRICT-CONTAINMENT resolution. EACH of the 6 rim dots contributes
-- AT MOST ONE pair: for that dot, find the NEAREST live flippable coin whose
-- disc strictly contains the dot's point (d2 < coin.radius^2). A dot inside
-- no coin contributes nothing. Coins don't overlap so "nearest" rarely
-- matters, but the one-pair-per-dot guarantee is preserved either way.
-- outConflict's slots are preallocated {idx, coin} tables mutated in place.
--
-- Returns count only:
--   0  -> no contact
--   1  -> auto-arm (single pair; caller uses outConflict[1])
--   2+ -> conflict (player cycles through outConflict[1..count] with A/D)
-- Contact detection: the tool EDGE (circle rim / triangle sides) is the
-- contact surface. A coin registers a hit when its body overlaps the edge.
local function findPressedCoin(coins, toolX, toolY, toolR, outConflict, isTriangle)
  local count = 0
  if isTriangle then
    -- Triangle: for each coin, find the closest point on any of the 3 edges.
    -- Contact when that distance < coin.radius. Deduplication is natural
    -- because we loop coins in the outer loop.
    local v1x = toolX + TRI_UX[1] * toolR;  local v1y = toolY + TRI_UY[1] * toolR
    local v2x = toolX + TRI_UX[2] * toolR;  local v2y = toolY + TRI_UY[2] * toolR
    local v3x = toolX + TRI_UX[3] * toolR;  local v3y = toolY + TRI_UY[3] * toolR
    for i = 1, #coins do
      local coin = coins[i]
      if not coin.flipping and not coin.used then
        local cr = coin.radius
        local cx = coin.x;  local cy = coin.y
        local bestDist = huge
        local bestPX, bestPY = 0, 0
        -- Edge v1->v2
        do
          local ex = v2x-v1x;  local ey = v2y-v1y
          local len2 = ex*ex + ey*ey
          local t = ((cx-v1x)*ex + (cy-v1y)*ey) / len2
          if t < 0 then t = 0 elseif t > 1 then t = 1 end
          local px = v1x+t*ex;  local py = v1y+t*ey
          local ddx = cx-px;    local ddy = cy-py
          local d = sqrt(ddx*ddx + ddy*ddy)
          if d < cr and d < bestDist then bestDist=d; bestPX=px; bestPY=py end
        end
        -- Edge v2->v3
        do
          local ex = v3x-v2x;  local ey = v3y-v2y
          local len2 = ex*ex + ey*ey
          local t = ((cx-v2x)*ex + (cy-v2y)*ey) / len2
          if t < 0 then t = 0 elseif t > 1 then t = 1 end
          local px = v2x+t*ex;  local py = v2y+t*ey
          local ddx = cx-px;    local ddy = cy-py
          local d = sqrt(ddx*ddx + ddy*ddy)
          if d < cr and d < bestDist then bestDist=d; bestPX=px; bestPY=py end
        end
        -- Edge v3->v1
        do
          local ex = v1x-v3x;  local ey = v1y-v3y
          local len2 = ex*ex + ey*ey
          local t = ((cx-v3x)*ex + (cy-v3y)*ey) / len2
          if t < 0 then t = 0 elseif t > 1 then t = 1 end
          local px = v3x+t*ex;  local py = v3y+t*ey
          local ddx = cx-px;    local ddy = cy-py
          local d = sqrt(ddx*ddx + ddy*ddy)
          if d < cr and d < bestDist then bestDist=d; bestPX=px; bestPY=py end
        end
        if bestDist < cr then
          count = count + 1
          local slot = outConflict[count]
          slot.contactX = bestPX
          slot.contactY = bestPY
          slot.coin     = coin
          if count == 6 then break end
        end
      end
    end
  else
    -- Circle: coin overlaps the rim when |dist(toolCenter, coinCenter) - toolR|
    -- < coin.radius. Contact point is the rim point nearest to the coin center.
    for i = 1, #coins do
      local coin = coins[i]
      if not coin.flipping and not coin.used then
        local dx   = coin.x - toolX
        local dy   = coin.y - toolY
        local dist = sqrt(dx*dx + dy*dy)
        if dist > 1 then
          local rimDist = dist - toolR
          if rimDist < 0 then rimDist = -rimDist end
          if rimDist < coin.radius then
            count = count + 1
            local slot = outConflict[count]
            local inv  = toolR / dist
            slot.contactX = toolX + dx * inv
            slot.contactY = toolY + dy * inv
            slot.coin     = coin
            if count == 6 then break end
          end
        end
      end
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

  local cr      = coin.radius
  local bull_t  = L.bullR   + cr
  local mid_t   = L.middleR + cr
  local outer_t = L.outerR  + cr

  if d2 < bull_t * bull_t then
    local gain = max(1, floor(POINTS.bull * tierMult * self.multiplier))
    self.marbles    = self.marbles + gain
    self.multiplier = self.multiplier + 1
    return "bull", gain
  elseif d2 < mid_t * mid_t then
    local gain = max(1, floor(POINTS.middle * tierMult * self.multiplier))
    self.marbles    = self.marbles + gain
    self.multiplier = self.multiplier + 1
    return "middle", gain
  elseif d2 < outer_t * outer_t then
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

-- Shared launch path: used by the player click AND by chain reactions.
-- contactX/Y is a screen point on the coin (player: rim dot; chain: leading
-- edge of the landing coin). depth: 0 = player flip (gates input via
-- self.activeCoin); >= 1 = chain step (bypasses player gate). Chains stop
-- propagating when depth reaches 3 (so at most 3 hops past the player flip).
--
-- Forward-declared because tryChainFlip calls fireFlip and fireFlip's launch
-- callback calls tryChainFlip.
local fireFlip, tryChainFlip

fireFlip = function(self, coin, contactX, contactY, depth)
  local item = (coin.itemType and Items.byId(coin.itemType)) or self.activeCoinItem
  local offX, offY, offDist = coin:pressedBy(contactX, contactY)
  if not offX then return end
  local region = coin:regionAt(offX, offY, item)
  local angle  = region and region.angle or -pi / 2
  local power, arc = resolveShot(item, offDist)
  if region then
    if region.power then power = region.power end
    if region.arc   then arc   = region.arc   end
  end
  -- Player gate: only depth-0 flips block subsequent player input.
  if depth == 0 then self.activeCoin = coin end
  coin:launch(angle, power, arc, item, function(lx, ly)
    local zone, _ = resolveFlip(self, coin, lx, ly)
    if zone == "bull" or zone == "middle" or zone == "outer" then
      coin.used = true  -- scoring hits retire the coin at its current tier
    end
    -- Tier mutation on misses is handled inside resolveFlip.
    -- Chain reaction: bumps the depth. At depth 3 we still LAND and resolve
    -- normally, but we do NOT trigger a 4th-hop chain.
    if depth < 3 then
      tryChainFlip(self, coin, lx, ly, depth + 1)
    end
    -- Release the player gate exactly when the player's own coin lands.
    -- Chains fired by that coin are already in the air; they don't gate
    -- further player input.
    if depth == 0 then self.activeCoin = nil end
  end, L.boardX, L.boardY, L.boardW, L.boardH)
end

-- After a coin lands at (lx, ly), check every OTHER live, flippable coin for
-- disc overlap. Each overlapping target is chain-flipped, using the LEADING
-- EDGE of the landing coin (perimeter point in the landing coin's travel
-- direction) as the contact. If the leading-edge point misses the target's
-- own disc (e.g. side-swiping overlap), fall back to the landing coin's
-- perimeter point in the direction of the target's center. From there, the
-- usual pressedBy -> regionAt -> resolveShot path resolves the chain shot.
tryChainFlip = function(self, landingCoin, lx, ly, depth)
  local lr = landingCoin.radius
  local a  = landingCoin.launchAngle or 0
  local ca = cos(a)
  local sa = sin(a)
  for i = 1, #self.coins do
    local target = self.coins[i]
    if target ~= landingCoin
       and not target.flipping and not target.used then
      local dx   = target.x - lx
      local dy   = target.y - ly
      local d2   = dx * dx + dy * dy
      local sumR = lr + target.radius
      if d2 < (sumR * sumR) then
        -- Primary: leading edge in travel direction.
        local edgeX = lx + ca * lr
        local edgeY = ly + sa * lr
        -- If the leading edge isn't strictly inside the target, fall back to
        -- the landing coin's rim toward the target center.
        local edx = edgeX - target.x
        local edy = edgeY - target.y
        local tr  = target.radius
        if (edx * edx + edy * edy) >= (tr * tr) then
          local d = sqrt(d2)
          if d > 0 then
            local invD = 1 / d
            edgeX = lx + dx * invD * lr
            edgeY = ly + dy * invD * lr
          end
        end
        fireFlip(self, target, edgeX, edgeY, depth)
      end
    end
  end
end

-- ---------- State lifecycle ----------

function Game:enter(prev, houseName)
  self.houseName  = houseName or "?"
  self.floor      = 1
  self.marbles    = 0
  self.multiplier = 1

  rebuildLayout()

  -- Randomise target position within the board each floor.
  local tMargin = L.outerR + L.coinR + 24
  L.targetCX = love.math.random(
    L.boardX + tMargin, L.boardX + L.boardW - tMargin)
  L.targetCY = love.math.random(
    L.boardY + tMargin, L.boardY + L.boardH - tMargin)

  -- Prototype: every coin in the scatter is the same item (Coin). Future:
  -- per-floor item assignment, varied per scatter spot.
  self.activeCoinItem = Items.byId("coin")  -- fallback for legacy paths
  self.coins          = scatterBoard()
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
    self.conflictDots[i] = self.conflictDots[i] or { contactX = 0, contactY = 0, coin = nil }
    self.conflictDots[i].contactX = 0
    self.conflictDots[i].contactY = 0
    self.conflictDots[i].coin     = nil
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
  self.toolType     = self.toolType or TOOL_CIRCLE  -- preserved across [R] restart
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
    self.armedDotX   = nil
    self.armedDotY   = nil
    return
  end
  local i        = (self.conflictCount == 1) and 1 or self.conflictIdx
  local pair     = self.conflictDots[i]
  self.hoveredCoin = pair.coin
  self.armedDotX   = pair.contactX
  self.armedDotY   = pair.contactY
end

-- Recompute hover/conflict state from the current self.toolX / self.toolY.
-- Called by update (every frame) AND mousepressed (so a fresh sample drives
-- the click decision). Preserves the player's previously-selected PAIR (by
-- idx + coin identity) across tool jitter so A/D choices don't reset.
function Game:_refreshHover()
  local prevCoin
  if self.conflictCount > 0 then
    local prev = self.conflictDots[self.conflictIdx]
    if prev then prevCoin = prev.coin end
  end

  local count = findPressedCoin(
    self.coins, self.toolX, self.toolY, L.toolR, self.conflictDots,
    self.toolType == TOOL_TRIANGLE)
  self.conflictCount = count

  if count <= 1 then
    self.conflictIdx = 1
  else
    -- Preserve previous coin selection if it is still in contact.
    local newIdx = 1
    if prevCoin then
      for i = 1, count do
        local p = self.conflictDots[i]
        if p.coin == prevCoin then newIdx = i; break end
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

  -- Left score panel.
  lg.setColor(COLOR_PANEL[1], COLOR_PANEL[2], COLOR_PANEL[3])
  lg.rectangle("fill", L.panelX, 0, L.panelW, L.panelH)

  local px = L.panelX + 18       -- left margin
  local pw = L.panelW - 36       -- usable width
  local py = 18

  -- House name
  lg.setColor(COLOR_PANEL_VALUE[1], COLOR_PANEL_VALUE[2], COLOR_PANEL_VALUE[3])
  lg.print(string.upper(self.houseName or "?"), px, py)
  py = py + 22
  lg.setColor(1, 1, 1, 0.12)
  lg.setLineWidth(1)
  lg.line(px, py, px + pw, py)
  py = py + 12

  -- Score
  lg.setColor(COLOR_PANEL_LABEL[1], COLOR_PANEL_LABEL[2], COLOR_PANEL_LABEL[3])
  lg.print("SCORE", px, py)
  py = py + 18
  local tier0col = Tiers[1].color
  local circR = 10
  lg.setColor(tier0col[1], tier0col[2], tier0col[3])
  lg.circle("fill", px + circR, py + circR, circR)
  lg.setColor(0.12, 0.12, 0.12, 0.70)
  lg.setLineWidth(1.5)
  lg.circle("line", px + circR, py + circR, circR)
  lg.setColor(COLOR_PANEL_VALUE[1], COLOR_PANEL_VALUE[2], COLOR_PANEL_VALUE[3])
  lg.print(tostring(self.marbles), px + circR * 2 + 10, py + 3)
  py = py + circR * 2 + 10
  local mc = self.multiplier > 1 and COLOR_MULT_ACTIVE or COLOR_MULT_IDLE
  lg.setColor(mc[1], mc[2], mc[3])
  lg.print("x" .. self.multiplier .. "  MULT", px, py)
  py = py + 22
  lg.setColor(1, 1, 1, 0.12)
  lg.setLineWidth(1)
  lg.line(px, py, px + pw, py)
  py = py + 12

  -- Floor
  lg.setColor(COLOR_PANEL_LABEL[1], COLOR_PANEL_LABEL[2], COLOR_PANEL_LABEL[3])
  lg.print("FLOOR", px, py)
  py = py + 18
  lg.setColor(COLOR_PANEL_VALUE[1], COLOR_PANEL_VALUE[2], COLOR_PANEL_VALUE[3])
  lg.print(tostring(self.floor) .. " / " .. NUM_FLOORS, px, py)
  py = py + 22
  lg.setColor(COLOR_PANEL_LABEL[1], COLOR_PANEL_LABEL[2], COLOR_PANEL_LABEL[3])
  lg.print("NEED  " .. (FLOOR_THRESHOLDS[self.floor] or "?"), px, py)
  py = py + 22
  lg.setColor(1, 1, 1, 0.12)
  lg.setLineWidth(1)
  lg.line(px, py, px + pw, py)
  py = py + 12

  -- Tool selector
  lg.setColor(COLOR_PANEL_LABEL[1], COLOR_PANEL_LABEL[2], COLOR_PANEL_LABEL[3])
  lg.print("TOOL", px, py)
  py = py + 18
  local halfBtnW = (pw - 8) / 2
  self._toolBtnY = py
  for bi = 1, 2 do
    local bx     = px + (bi - 1) * (halfBtnW + 8)
    local isCirc = (bi == 1)
    local active = (isCirc and self.toolType == TOOL_CIRCLE) or
                   (not isCirc and self.toolType == TOOL_TRIANGLE)
    local bgCol  = active and COLOR_TOOL_ACTIVE or COLOR_BTN
    local brCol  = active and COLOR_TOOL_ACTIVE or COLOR_BTN_BORDER
    lg.setColor(bgCol[1], bgCol[2], bgCol[3], active and 0.28 or 1)
    lg.rectangle("fill", bx, py, halfBtnW, 38, 4, 4)
    lg.setColor(brCol[1], brCol[2], brCol[3])
    lg.setLineWidth(active and 2 or 1)
    lg.rectangle("line", bx, py, halfBtnW, 38, 4, 4)
    local iconX = bx + halfBtnW * 0.5
    local iconY = py + 19
    local iconR = 11
    local iconA = active and 1.0 or 0.55
    if isCirc then
      lg.setColor(1, 1, 1, iconA * 0.30)
      lg.circle("fill", iconX, iconY, iconR)
      lg.setColor(1, 1, 1, iconA)
      lg.setLineWidth(2)
      lg.circle("line", iconX, iconY, iconR)
    else
      local ti1x = iconX + TRI_UX[1] * iconR
      local ti1y = iconY + TRI_UY[1] * iconR
      local ti2x = iconX + TRI_UX[2] * iconR
      local ti2y = iconY + TRI_UY[2] * iconR
      local ti3x = iconX + TRI_UX[3] * iconR
      local ti3y = iconY + TRI_UY[3] * iconR
      lg.setColor(1, 1, 1, iconA * 0.30)
      lg.polygon("fill", ti1x, ti1y, ti2x, ti2y, ti3x, ti3y)
      lg.setColor(1, 1, 1, iconA)
      lg.setLineWidth(2)
      lg.polygon("line", ti1x, ti1y, ti2x, ti2y, ti3x, ti3y)
    end
  end
  py = py + 50

  -- Restart button
  lg.setColor(COLOR_BTN[1], COLOR_BTN[2], COLOR_BTN[3])
  lg.rectangle("fill", px, py, pw, 26, 4, 4)
  lg.setColor(COLOR_BTN_BORDER[1], COLOR_BTN_BORDER[2], COLOR_BTN_BORDER[3])
  lg.setLineWidth(1)
  lg.rectangle("line", px, py, pw, 26, 4, 4)
  lg.setColor(COLOR_BTN_TEXT[1], COLOR_BTN_TEXT[2], COLOR_BTN_TEXT[3])
  lg.print("[R]  Restart", px + 8, py + 5)
  py = py + 34

  -- Debug toggle button
  local dbgCol = self.debugRegions and COLOR_DEBUG_ON or COLOR_BTN_TEXT
  lg.setColor(COLOR_BTN[1], COLOR_BTN[2], COLOR_BTN[3])
  lg.rectangle("fill", px, py, pw, 26, 4, 4)
  lg.setColor(COLOR_BTN_BORDER[1], COLOR_BTN_BORDER[2], COLOR_BTN_BORDER[3])
  lg.setLineWidth(1)
  lg.rectangle("line", px, py, pw, 26, 4, 4)
  lg.setColor(dbgCol[1], dbgCol[2], dbgCol[3])
  lg.print("[G]  Debug", px + 8, py + 5)

  -- Thick dark border frame (drawn first; board surface sits inset inside it).
  lg.setColor(COLOR_BORDER[1], COLOR_BORDER[2], COLOR_BORDER[3])
  lg.rectangle("fill", L.borderX, L.borderY, L.borderW, L.borderH)

  -- Inner playing surface.
  lg.setColor(COLOR_BOARD)
  lg.rectangle("fill", L.boardX, L.boardY, L.boardW, L.boardH)

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
  if self.toolType == TOOL_TRIANGLE then
    drawTriangleToolAt(self.toolX, self.toolY)
  else
    drawToolAt(self.toolX, self.toolY)
  end
  -- Armed contact flash: bright dot exactly where the edge meets the coin.
  if self.armedDotX then
    lg.setColor(1, 1, 1, 0.92)
    lg.circle("fill", self.armedDotX, self.armedDotY, 5)
    lg.setColor(1, 1, 1, 0.38)
    lg.setLineWidth(1.5)
    lg.circle("line", self.armedDotX, self.armedDotY, 5)
    lg.setColor(1, 1, 1, 1)
  end

  -- Region debug overlay (press 'd' to toggle). On top of everything.
  if self.debugRegions then
    for i = 1, #self.coins do
      local dItem = Items.byId(self.coins[i].itemType or "coin") or self.activeCoinItem
      drawRegionDebug(self.coins[i], dItem)
    end
    local hItem = self.hoveredCoin and
      (Items.byId(self.hoveredCoin.itemType or "coin") or self.activeCoinItem)
    drawHoverDebug(self.hoveredCoin, hItem,
                   self.armedDotX, self.armedDotY)
  end

  lg.setColor(1, 1, 1, 1)
end

-- ---------- Input ----------

function Game:mousepressed(x, y, button)
  if button ~= 1 then return end
  -- Panel tool switcher clicks (checked before the board flip gate).
  if x < L.panelW and self._toolBtnY then
    if y >= self._toolBtnY and y <= self._toolBtnY + 38 then
      local bpx = L.panelX + 18
      local bpw = L.panelW - 36
      local mid = bpx + (bpw - 8) / 2
      self.toolType = (x < mid) and TOOL_CIRCLE or TOOL_TRIANGLE
      self:_refreshHover()
      return
    end
  end
  if self.activeCoin then return end                 -- one flip at a time
  -- Re-sample so the click decision uses the freshest cursor position.
  self.toolX, self.toolY = x, y
  self:_refreshHover()
  if not self.armedDotIdx then return end            -- no dot inside any coin
  fireFlip(self, self.hoveredCoin, self.armedDotX, self.armedDotY, 0)
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
  elseif k == "t" then
    self.toolType = (self.toolType == TOOL_TRIANGLE) and TOOL_CIRCLE or TOOL_TRIANGLE
    self:_refreshHover()
  end
end

-- ---------- Test hooks ----------

Game._resolveFlip     = resolveFlip
Game._findPressedCoin = findPressedCoin
Game._resolveShot     = resolveShot
Game._fireFlip        = function(self, coin, x, y, depth) return fireFlip(self, coin, x, y, depth) end
Game._tryChainFlip    = function(self, landing, lx, ly, depth) return tryChainFlip(self, landing, lx, ly, depth) end
Game._L               = L  -- layout table (read after enter())

return Game

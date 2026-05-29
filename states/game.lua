-- states/game.lua
-- The flip board, rebuilt per docs/FLIP_BOARD_VISUAL_SPEC.md.
--
-- Portrait layout, light grey background, board rectangle filling
-- everything below a top HUD strip. The ENTIRE board is the scoring space:
-- four concentric-rectangle scoring zones:
--   white (outer strip) = 0 pts, coin stays live and can be flipped again
--   blue  (next band)   = 1 pt
--   yellow (inner band) = 2 pts
--   red   (centre rect) = 3 pts
-- Landing off-board resets the chain. White is a survivable no-score.
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
  -- Measured contact-mark positions (fractions of toolR) matching the
  -- hand-drawn reference. atan2 derives each arc panel's center angle so
  -- the Simon-Says slivers line up with the dots.
  DOT_UX[1] =  0.006;  DOT_UY[1] = -0.799  -- top
  DOT_UX[2] =  0.637;  DOT_UY[2] = -0.586  -- top-right
  DOT_UX[3] =  0.796;  DOT_UY[3] =  0.045  -- right
  DOT_UX[4] =  0.596;  DOT_UY[4] =  0.520  -- bottom-right
  DOT_UX[5] = -0.608;  DOT_UY[5] =  0.513  -- bottom-left
  DOT_UX[6] = -0.771;  DOT_UY[6] = -0.035  -- left
  for i = 1, 6 do
    DOT_ANGLES_RAD[i] = math.atan2(DOT_UY[i], DOT_UX[i])
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
  -- Measured tip positions (fractions of toolR) matching the hand-drawn
  -- reference. These 3 tips ARE the contact vertices used by findPressedCoin,
  -- so the drawn shape and the hit geometry stay in sync automatically.
  TRI_UX[1] =  0.159;  TRI_UY[1] = -0.630  -- top tip
  TRI_UX[2] =  0.830;  TRI_UY[2] =  0.576  -- bottom-right tip
  TRI_UX[3] = -0.833;  TRI_UY[3] =  0.707  -- bottom-left tip
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
local COLOR_ZONE_BLUE      = { 0.25, 0.50, 0.85 }  -- blue band:   1 pt
local COLOR_ZONE_YELLOW    = { 0.96, 0.80, 0.10 }  -- yellow band: 2 pts
local COLOR_ZONE_RED       = { 0.85, 0.18, 0.14 }  -- red centre:  3 pts
local COLOR_ZONE_BORDER    = { 0.15, 0.15, 0.15 }  -- dark outlines between zones
local COLOR_TOOL           = { 0x9A/255, 0xA0/255, 0xA6/255 }
local COLOR_TOOL_OUTLINE   = { 0x33/255, 0x33/255, 0x33/255 }
local COLOR_HIGHLIGHT      = { 0.20, 0.95, 1.00 }   -- cyan "armed" ring
local COLOR_TOOL_HL        = { 1.00, 0.88, 0.30 }   -- lit leading-edge segment
local TOOL_BORDER_WIDTH    = 4                       -- chip border thickness
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

-- Notebook / parchment HUD palette
local COLOR_HUD_BG      = { 0.88, 0.84, 0.76 }  -- warm tan panel background
local COLOR_CARD_BG     = { 0.98, 0.95, 0.88 }  -- cream card fill
local COLOR_CARD_BORDER = { 0.48, 0.34, 0.18 }  -- warm brown card border
local COLOR_CARD_LABEL  = { 0.38, 0.28, 0.14 }  -- dark brown label text
local COLOR_CARD_VALUE  = { 0.11, 0.08, 0.04 }  -- near-black value text
local COLOR_MULT_GOLD   = { 0.88, 0.60, 0.04 }  -- gold chain multiplier
local COLOR_BAR_BG      = { 0.74, 0.68, 0.56 }  -- muted tan bar background
local COLOR_BAR_FILL    = { 0.20, 0.56, 0.20 }  -- green progress fill

-- HUD fonts — nil until first Game:enter (safe for module-load time).
local HUD_FONT_DEFAULT, HUD_FONT_SMALL, HUD_FONT_MEDIUM, HUD_FONT_LARGE, HUD_FONT_HUGE

-- ---------- Tunables ----------

local COINS_PER_FLOOR = 5
local COIN_RADIUS_AT_390W = 24                  -- spec: 48px DIAMETER at 390w
local FLOOR_THRESHOLDS = { [1] = 20, [2] = 60, [3] = 120 }
local NUM_FLOORS        = 3

-- Tight per Balatro lesson; the big numbers come from the multiplier chain.
local POINTS = { red = 3, yellow = 2, blue = 1 }  -- zone point values

local PANEL_W   = 220   -- left score panel width
local BORDER_T  = 10    -- board border thickness (pixels each side)
local MARGIN    = 12    -- gap between screen edge/panel and border outer edge

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

  -- Concentric-rect zone insets (px from each board edge).
  -- White outer strip → Blue band → Yellow band → Red centre.
  local s  = math.min(L.boardW, L.boardH)
  L.zone1  = floor(s * 0.08)   -- white → blue  boundary
  L.zone2  = floor(s * 0.20)   -- blue  → yellow boundary
  L.zone3  = floor(s * 0.34)   -- yellow → red  boundary

  -- Coin size: use the spec value (48px diameter) directly. Coins are
  -- intentionally larger than the zone marks -- tappable, not aim-able.
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

-- scatterBoard: places 5 coins (mid/easy/easy/mini/hard) with spacing
-- checks. Returns a table of Coin instances with itemType set.
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

-- Triangle tool: translucent grey body + thick dark edge border. The 3 edges
-- ARE the contact surface. No dots, no outer ring; the leading-edge highlight
-- (drawn separately) lights up whichever edge faces the coin.
local function drawTriangleToolAt(x, y)
  local r   = L.toolR
  local v1x = x + TRI_UX[1] * r;  local v1y = y + TRI_UY[1] * r
  local v2x = x + TRI_UX[2] * r;  local v2y = y + TRI_UY[2] * r
  local v3x = x + TRI_UX[3] * r;  local v3y = y + TRI_UY[3] * r
  -- Translucent grey body.
  lg.setColor(COLOR_TOOL[1], COLOR_TOOL[2], COLOR_TOOL[3], 0.30)
  lg.polygon("fill", v1x, v1y, v2x, v2y, v3x, v3y)
  -- Thick dark edge border.
  lg.setColor(COLOR_TOOL_OUTLINE[1], COLOR_TOOL_OUTLINE[2], COLOR_TOOL_OUTLINE[3], 0.85)
  lg.setLineWidth(TOOL_BORDER_WIDTH)
  lg.polygon("line", v1x, v1y, v2x, v2y, v3x, v3y)
  lg.setColor(1, 1, 1, 1)
end

-- Circle tool: translucent disc + thick dark rim border. The rim IS the
-- contact surface. No panels, no dots, no outer ring; the leading-edge
-- highlight (drawn separately) lights up the rim arc facing the coin.
local function drawToolAt(x, y)
  local toolR = L.toolR
  -- Translucent grey disc.
  lg.setColor(COLOR_TOOL[1], COLOR_TOOL[2], COLOR_TOOL[3], 0.30)
  lg.circle("fill", x, y, toolR)
  -- Thick dark rim border.
  lg.setColor(COLOR_TOOL_OUTLINE[1], COLOR_TOOL_OUTLINE[2], COLOR_TOOL_OUTLINE[3], 0.85)
  lg.setLineWidth(TOOL_BORDER_WIDTH)
  lg.circle("line", x, y, toolR)
  lg.setColor(1, 1, 1, 1)
end

-- Leading-edge highlight: when the chip overlaps a coin, light up the part of
-- the chip facing the coin. Circle lights a rim arc; triangle lights ONLY the
-- single tip nearest the coin (its sides never light up). The lit part tracks
-- the coin continuously. No effect when nothing is in contact.
local TOOL_HL_HALF = 32 * pi / 180   -- circle highlight arc half-width
local function drawLeadingEdge(toolX, toolY, toolType, coin)
  if not coin then return end
  lg.setColor(COLOR_TOOL_HL[1], COLOR_TOOL_HL[2], COLOR_TOOL_HL[3], 1)
  if toolType == TOOL_TRIANGLE then
    -- Light up only the TIP nearest the coin (1 of the 3 vertices), as a dot.
    local r = L.toolR
    local bestI, bestD2 = 1, huge
    for i = 1, 3 do
      local tx = toolX + TRI_UX[i] * r
      local ty = toolY + TRI_UY[i] * r
      local dx = coin.x - tx
      local dy = coin.y - ty
      local d2 = dx * dx + dy * dy
      if d2 < bestD2 then bestD2 = d2; bestI = i end
    end
    lg.circle("fill", toolX + TRI_UX[bestI] * r, toolY + TRI_UY[bestI] * r, TOOL_BORDER_WIDTH + 3)
  else
    -- Light up the rim arc facing the coin.
    local ang = math.atan2(coin.y - toolY, coin.x - toolX)
    lg.setLineWidth(TOOL_BORDER_WIDTH + 2)
    lg.arc("line", "open", toolX, toolY, L.toolR, ang - TOOL_HL_HALF, ang + TOOL_HL_HALF)
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
    -- Triangle: only the 3 TIPS are contact points -- the sides never touch.
    -- A tip activates a coin when the tip point lies inside the coin's disc.
    -- Each tip claims the nearest live coin it is inside (one pair per tip).
    for d = 1, 3 do
      local tx = toolX + TRI_UX[d] * toolR
      local ty = toolY + TRI_UY[d] * toolR
      local bestCoin, bestD2 = nil, huge
      for i = 1, #coins do
        local coin = coins[i]
        if not coin.flipping and not coin.used then
          local dx = tx - coin.x
          local dy = ty - coin.y
          local d2 = dx*dx + dy*dy
          local cr = coin.radius
          if d2 < cr*cr and d2 < bestD2 then
            bestCoin = coin
            bestD2   = d2
          end
        end
      end
      if bestCoin then
        count = count + 1
        local slot = outConflict[count]
        slot.contactX = tx
        slot.contactY = ty
        slot.coin     = bestCoin
        if count == 6 then break end
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

-- Grandma's House 4-zone landing resolution. Concentric rectangles tested
-- innermost-first so the highest zone always wins:
--   off-board    → miss + chain reset  (coin not retired)
--   white strip  → 0 pts, no chain change (coin NOT retired, can flip again)
--   blue band    → 1 pt, feeds multiplier
--   yellow band  → 2 pts, feeds multiplier
--   red centre   → 3 pts, feeds multiplier
local function resolveFlip(self, coin, landingX, landingY)
  local bx, by   = L.boardX, L.boardY
  local bw, bh   = L.boardW, L.boardH
  local z1, z2, z3 = L.zone1, L.zone2, L.zone3
  local tierMult = Tiers[(coin.tier or 0) + 1].mult

  -- Off-board: full miss, chain resets.
  if landingX < bx or landingX > bx + bw or
     landingY < by or landingY > by + bh then
    if coin.tier < 3 then coin.tier = coin.tier + 1 end
    self.multiplier = 1
    return "off_board_miss", 0
  end

  -- Red centre (innermost).
  if landingX >= bx + z3 and landingX <= bx + bw - z3 and
     landingY >= by + z3 and landingY <= by + bh - z3 then
    local gain = max(1, floor(POINTS.red * tierMult * self.multiplier))
    self.marbles    = self.marbles + gain
    self.multiplier = self.multiplier + 1
    return "red", gain
  end

  -- Yellow band.
  if landingX >= bx + z2 and landingX <= bx + bw - z2 and
     landingY >= by + z2 and landingY <= by + bh - z2 then
    local gain = max(1, floor(POINTS.yellow * tierMult * self.multiplier))
    self.marbles    = self.marbles + gain
    self.multiplier = self.multiplier + 1
    return "yellow", gain
  end

  -- Blue band.
  if landingX >= bx + z1 and landingX <= bx + bw - z1 and
     landingY >= by + z1 and landingY <= by + bh - z1 then
    local gain = max(1, floor(POINTS.blue * tierMult * self.multiplier))
    self.marbles    = self.marbles + gain
    self.multiplier = self.multiplier + 1
    return "blue", gain
  end

  -- White outer strip: on-board but no score. Coin stays live, can be
  -- flipped again. Degrades tier to make the coin harder over time.
  if coin.tier < 3 then coin.tier = coin.tier + 1 end
  return "white_miss", 0
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
    if zone == "red" or zone == "yellow" or zone == "blue" then
      coin.used = true  -- scoring zones retire the coin
    end
    -- white_miss / off_board_miss: coin stays live and can be flipped again.
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
  -- Lazy-create HUD fonts once (safe: Game:enter always precedes Game:draw).
  if not HUD_FONT_HUGE then
    HUD_FONT_DEFAULT = lg.newFont(12)
    HUD_FONT_SMALL   = lg.newFont(11)
    HUD_FONT_MEDIUM  = lg.newFont(16)
    HUD_FONT_LARGE   = lg.newFont(28)
    HUD_FONT_HUGE    = lg.newFont(40)
  end
  -- HUD animation timers (reset each enter so restarts start clean).
  self.multBounce   = 0
  self.scoreFlash   = 0
  self._prevMult    = 1
  self._prevMarbles = 0
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
  -- HUD animation: detect score / multiplier changes and trigger timers.
  if self.multiplier ~= self._prevMult then
    if self.multiplier > (self._prevMult or 1) then
      self.multBounce = 0.28   -- trigger scale-bounce
    end
    self._prevMult = self.multiplier
  end
  if self.marbles ~= self._prevMarbles then
    if self.marbles > (self._prevMarbles or 0) then
      self.scoreFlash = 0.20   -- trigger highlight flash
    end
    self._prevMarbles = self.marbles
  end
  if self.multBounce  > 0 then self.multBounce  = self.multBounce  - dt end
  if self.scoreFlash  > 0 then self.scoreFlash  = self.scoreFlash  - dt end
end

function Game:draw()
  -- Background.
  lg.setColor(COLOR_BG)
  lg.rectangle("fill", 0, 0, L.W, L.H)

  -- ── Notebook HUD — three stacked card sections ──────────────────────
  -- Warm parchment panel background.
  lg.setColor(COLOR_HUD_BG[1], COLOR_HUD_BG[2], COLOR_HUD_BG[3])
  lg.rectangle("fill", 0, 0, L.panelW, L.H)

  local pm = 10                  -- outer margin + gap between cards
  local cx = pm                  -- card left edge
  local cw = L.panelW - pm * 2  -- card usable width
  local cy = pm                  -- running y cursor

  -- ── Card 1: Floor Info ───────────────────────────────────────────────
  local c1h = 88
  lg.setColor(COLOR_CARD_BG[1], COLOR_CARD_BG[2], COLOR_CARD_BG[3])
  lg.rectangle("fill", cx, cy, cw, c1h, 6, 6)
  lg.setColor(COLOR_CARD_BORDER[1], COLOR_CARD_BORDER[2], COLOR_CARD_BORDER[3])
  lg.setLineWidth(2)
  lg.rectangle("line", cx, cy, cw, c1h, 6, 6)
  -- House name
  lg.setFont(HUD_FONT_MEDIUM)
  lg.setColor(COLOR_CARD_VALUE[1], COLOR_CARD_VALUE[2], COLOR_CARD_VALUE[3])
  lg.print(string.upper(self.houseName or "?"), cx + 10, cy + 8)
  -- Thin divider
  lg.setColor(COLOR_CARD_BORDER[1], COLOR_CARD_BORDER[2], COLOR_CARD_BORDER[3], 0.30)
  lg.setLineWidth(1)
  lg.line(cx + 10, cy + 30, cx + cw - 10, cy + 30)
  -- Floor and threshold
  lg.setFont(HUD_FONT_SMALL)
  lg.setColor(COLOR_CARD_LABEL[1], COLOR_CARD_LABEL[2], COLOR_CARD_LABEL[3])
  lg.print("FLOOR  " .. self.floor .. " / " .. NUM_FLOORS, cx + 10, cy + 38)
  lg.print("NEXT:  " .. (FLOOR_THRESHOLDS[self.floor] or "?"), cx + 10, cy + 60)
  cy = cy + c1h + pm

  -- ── Card 2: Marble Progress ──────────────────────────────────────────
  local c2h = 182
  lg.setColor(COLOR_CARD_BG[1], COLOR_CARD_BG[2], COLOR_CARD_BG[3])
  lg.rectangle("fill", cx, cy, cw, c2h, 6, 6)
  lg.setColor(COLOR_CARD_BORDER[1], COLOR_CARD_BORDER[2], COLOR_CARD_BORDER[3])
  lg.setLineWidth(2)
  lg.rectangle("line", cx, cy, cw, c2h, 6, 6)
  -- Section label
  lg.setFont(HUD_FONT_SMALL)
  lg.setColor(COLOR_CARD_LABEL[1], COLOR_CARD_LABEL[2], COLOR_CARD_LABEL[3])
  lg.print("MARBLES EARNED", cx + 10, cy + 8)
  -- Score flash highlight (brief amber glow on change)
  if self.scoreFlash > 0 then
    local fi = self.scoreFlash / 0.20
    lg.setColor(0.92, 0.70, 0.15, 0.26 * fi)
    lg.rectangle("fill", cx + 6, cy + 22, cw - 12, 50, 4, 4)
  end
  -- Hero score number
  lg.setFont(HUD_FONT_HUGE)
  lg.setColor(COLOR_CARD_VALUE[1], COLOR_CARD_VALUE[2], COLOR_CARD_VALUE[3])
  lg.print(tostring(self.marbles), cx + 10, cy + 24)
  -- Progress bar toward threshold
  local barX   = cx + 10
  local barY   = cy + 82
  local barW   = cw - 32        -- gap on right for star
  local barH   = 14
  local thresh = FLOOR_THRESHOLDS[self.floor] or 1
  local frac   = math.min(self.marbles / thresh, 1)
  lg.setColor(COLOR_BAR_BG[1], COLOR_BAR_BG[2], COLOR_BAR_BG[3])
  lg.rectangle("fill", barX, barY, barW, barH, 5, 5)
  if frac > 0 then
    lg.setColor(COLOR_BAR_FILL[1], COLOR_BAR_FILL[2], COLOR_BAR_FILL[3])
    lg.rectangle("fill", barX, barY, max(barH, floor(barW * frac)), barH, 5, 5)
  end
  lg.setColor(COLOR_CARD_BORDER[1], COLOR_CARD_BORDER[2], COLOR_CARD_BORDER[3], 0.55)
  lg.setLineWidth(1)
  lg.rectangle("line", barX, barY, barW, barH, 5, 5)
  -- Star badge at bar right end
  local sCX = barX + barW + 14
  local sCY = barY + barH * 0.5
  lg.setColor(COLOR_MULT_GOLD[1], COLOR_MULT_GOLD[2], COLOR_MULT_GOLD[3])
  lg.circle("fill", sCX, sCY, 9)
  lg.setColor(0.18, 0.10, 0.02)
  lg.setLineWidth(1.5)
  lg.circle("line", sCX, sCY, 9)
  -- Chain multiplier (large; bounces on increase)
  local mScale = 1.0
  if self.multBounce > 0 then
    local t = self.multBounce / 0.28
    mScale = 1 + 0.32 * t * t   -- quadratic ease-out, max 1.32x
  end
  local multStr = "x" .. self.multiplier
  local mcol    = self.multiplier > 1 and COLOR_MULT_GOLD or COLOR_CARD_LABEL
  local mCX     = cx + cw * 0.5
  local mCY     = cy + 135
  lg.push()
  lg.translate(mCX, mCY)
  lg.scale(mScale, mScale)
  lg.setFont(HUD_FONT_LARGE)
  local mW  = HUD_FONT_LARGE:getWidth(multStr)
  local mHt = HUD_FONT_LARGE:getHeight()
  if self.multiplier > 1 then  -- warm drop shadow when chain is active
    lg.setColor(0.52, 0.32, 0.04, 0.28)
    lg.print(multStr, -mW * 0.5 + 2, -mHt * 0.5 + 2)
  end
  lg.setColor(mcol[1], mcol[2], mcol[3])
  lg.print(multStr, -mW * 0.5, -mHt * 0.5)
  lg.pop()
  -- "CHAIN" sub-label below multiplier
  lg.setFont(HUD_FONT_SMALL)
  lg.setColor(COLOR_CARD_LABEL[1], COLOR_CARD_LABEL[2], COLOR_CARD_LABEL[3])
  lg.printf("CHAIN", cx, cy + 160, cw, "center")
  cy = cy + c2h + pm

  -- ── Card 3: Active Cards (fills remaining panel height) ──────────────
  local c3h = max(60, L.H - cy - pm)
  lg.setColor(COLOR_CARD_BG[1], COLOR_CARD_BG[2], COLOR_CARD_BG[3])
  lg.rectangle("fill", cx, cy, cw, c3h, 6, 6)
  lg.setColor(COLOR_CARD_BORDER[1], COLOR_CARD_BORDER[2], COLOR_CARD_BORDER[3])
  lg.setLineWidth(2)
  lg.rectangle("line", cx, cy, cw, c3h, 6, 6)
  lg.setFont(HUD_FONT_SMALL)
  lg.setColor(COLOR_CARD_LABEL[1], COLOR_CARD_LABEL[2], COLOR_CARD_LABEL[3])
  lg.print("ACTIVE CARDS", cx + 10, cy + 10)
  -- Empty state placeholder
  lg.setColor(COLOR_CARD_LABEL[1], COLOR_CARD_LABEL[2], COLOR_CARD_LABEL[3], 0.38)
  lg.printf("NO CARDS YET", cx, cy + floor(c3h * 0.42), cw, "center")

  -- Restore default font before board rendering.
  lg.setFont(HUD_FONT_DEFAULT)

  -- Thick dark border frame (drawn first; board surface sits inset inside it).
  lg.setColor(COLOR_BORDER[1], COLOR_BORDER[2], COLOR_BORDER[3])
  lg.rectangle("fill", L.borderX, L.borderY, L.borderW, L.borderH)

  -- Inner playing surface.
  lg.setColor(COLOR_BOARD)
  lg.rectangle("fill", L.boardX, L.boardY, L.boardW, L.boardH)

  -- Board scoring zones: concentric rectangles layered outermost → innermost.
  -- White board surface (drawn above) is the outer no-score strip.
  -- Blue (1 pt) → Yellow (2 pts) → Red centre (3 pts) sit on top.
  local bx, by = L.boardX, L.boardY
  local bw, bh = L.boardW, L.boardH
  local z1, z2, z3 = L.zone1, L.zone2, L.zone3
  lg.setColor(COLOR_ZONE_BLUE)
  lg.rectangle("fill", bx + z1, by + z1, bw - z1*2, bh - z1*2)
  lg.setColor(COLOR_ZONE_YELLOW)
  lg.rectangle("fill", bx + z2, by + z2, bw - z2*2, bh - z2*2)
  lg.setColor(COLOR_ZONE_RED)
  lg.rectangle("fill", bx + z3, by + z3, bw - z3*2, bh - z3*2)
  lg.setColor(COLOR_ZONE_BORDER)
  lg.setLineWidth(2)
  lg.rectangle("line", bx + z1, by + z1, bw - z1*2, bh - z1*2)
  lg.rectangle("line", bx + z2, by + z2, bw - z2*2, bh - z2*2)
  lg.rectangle("line", bx + z3, by + z3, bw - z3*2, bh - z3*2)

  -- Coins.
  for i = 1, #self.coins do self.coins[i]:draw() end

  -- Highlight the coin the tool will fire against (auto-arm OR selected pair).
  drawHighlightFor(self.hoveredCoin)

  -- Flip tool follows the cursor: a plain grey chip with a thick dark border.
  if self.toolType == TOOL_TRIANGLE then
    drawTriangleToolAt(self.toolX, self.toolY)
  else
    drawToolAt(self.toolX, self.toolY)
  end
  -- Leading-edge highlight: the chip's own border segment facing the armed
  -- coin lights up (Simon-Says style). Only when a coin is in contact.
  drawLeadingEdge(self.toolX, self.toolY, self.toolType, self.hoveredCoin)

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
  -- Panel clicks don't fire flips (tool toggle is keyboard [T]).
  if x < L.panelW then return end
  if self.activeCoin then return end                 -- one flip at a time
  -- Re-sample so the click decision uses the freshest cursor position.
  self.toolX, self.toolY = x, y
  self:_refreshHover()
  if not self.armedDotX then return end              -- no coin in contact
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

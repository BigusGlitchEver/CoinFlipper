-- states/game/render_board.lua
-- The playing surface: border frame, scoring zones, start strip, coins, the
-- trajectory preview, the follow-cursor tool + leading-edge highlight, the
-- region/hover debug overlays, and the x30 bonus burst.

local C    = require("states.game.config")
local L    = require("states.game.layout")
local F    = require("states.game.fonts")
local Flip = require("states.game.flip")
local Items = require("data.flip_items")

local lg    = love.graphics
local max   = math.max
local floor = math.floor
local cos   = math.cos
local sin   = math.sin
local pi    = math.pi
local huge  = math.huge

local resolveShot = Flip.resolveShot

local TOOL_TRIANGLE     = C.TOOL_TRIANGLE
local TRI_UX            = C.TRI_UX
local TRI_UY            = C.TRI_UY
local TOOL_BORDER_WIDTH = C.TOOL_BORDER_WIDTH
local TOOL_HL_HALF      = C.TOOL_HL_HALF
local COLOR_TOOL          = C.COLOR_TOOL
local COLOR_TOOL_OUTLINE  = C.COLOR_TOOL_OUTLINE
local COLOR_TOOL_HL       = C.COLOR_TOOL_HL
local COLOR_HIGHLIGHT     = C.COLOR_HIGHLIGHT
local COLOR_BORDER        = C.COLOR_BORDER
local COLOR_BOARD         = C.COLOR_BOARD
local COLOR_ZONE_BLUE     = C.COLOR_ZONE_BLUE
local COLOR_ZONE_YELLOW   = C.COLOR_ZONE_YELLOW
local COLOR_ZONE_RED      = C.COLOR_ZONE_RED
local COLOR_ZONE_BORDER   = C.COLOR_ZONE_BORDER

local M = {}

-- ---------- Flip tool (round / triangle, follows the cursor) ----------

local function drawTriangleToolAt(x, y)
  local r   = L.toolR
  local v1x = x + TRI_UX[1] * r;  local v1y = y + TRI_UY[1] * r
  local v2x = x + TRI_UX[2] * r;  local v2y = y + TRI_UY[2] * r
  local v3x = x + TRI_UX[3] * r;  local v3y = y + TRI_UY[3] * r
  lg.setColor(COLOR_TOOL[1], COLOR_TOOL[2], COLOR_TOOL[3], 0.30)
  lg.polygon("fill", v1x, v1y, v2x, v2y, v3x, v3y)
  lg.setColor(COLOR_TOOL_OUTLINE[1], COLOR_TOOL_OUTLINE[2], COLOR_TOOL_OUTLINE[3], 0.85)
  lg.setLineWidth(TOOL_BORDER_WIDTH)
  lg.polygon("line", v1x, v1y, v2x, v2y, v3x, v3y)
  lg.setColor(1, 1, 1, 1)
end

local function drawToolAt(x, y)
  local toolR = L.toolR
  lg.setColor(COLOR_TOOL[1], COLOR_TOOL[2], COLOR_TOOL[3], 0.30)
  lg.circle("fill", x, y, toolR)
  lg.setColor(COLOR_TOOL_OUTLINE[1], COLOR_TOOL_OUTLINE[2], COLOR_TOOL_OUTLINE[3], 0.85)
  lg.setLineWidth(TOOL_BORDER_WIDTH)
  lg.circle("line", x, y, toolR)
  lg.setColor(1, 1, 1, 1)
end

local function drawLeadingEdge(toolX, toolY, toolType, coin)
  if not coin then return end
  lg.setColor(COLOR_TOOL_HL[1], COLOR_TOOL_HL[2], COLOR_TOOL_HL[3], 1)
  if toolType == TOOL_TRIANGLE then
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
    local ang = math.atan2(coin.y - toolY, coin.x - toolX)
    lg.setLineWidth(TOOL_BORDER_WIDTH + 2)
    lg.arc("line", "open", toolX, toolY, L.toolR, ang - TOOL_HL_HALF, ang + TOOL_HL_HALF)
    -- Short red tick at the exact contact angle (the calculation origin point).
    lg.setColor(1, 0.15, 0.15, 1)
    lg.arc("line", "open", toolX, toolY, L.toolR, ang - 4 * pi / 180, ang + 4 * pi / 180)
  end
  lg.setColor(1, 1, 1, 1)
end

local function drawHighlightFor(coin)
  if not coin then return end
  lg.setColor(COLOR_HIGHLIGHT[1], COLOR_HIGHLIGHT[2], COLOR_HIGHLIGHT[3], 0.90)
  lg.setLineWidth(3)
  lg.circle("line", coin.x, coin.y, coin.radius + 4)
  lg.setColor(1, 1, 1, 1)
end

-- ---------- Region debug overlay (press 'g' to toggle) ----------

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
    local mx = x + w * 0.5
    local my = y + h * 0.5
    local arrowLen = r * 0.75
    local ex = mx + cos(reg.angle) * arrowLen
    local ey = my + sin(reg.angle) * arrowLen
    lg.setColor(1, 1, 1, 0.9)
    lg.setLineWidth(2)
    lg.line(mx, my, ex, ey)
    lg.circle("fill", ex, ey, 2)
  end
  lg.setColor(1, 1, 1, 1)
end

-- Live trajectory preview for the hovered coin: straight aiming line from the
-- coin center through the resolved landing point, with a bullseye target.
local function drawHoverDebug(coin, item, dotX, dotY)
  if not coin or not item or not dotX then return end
  local offX, offY, offDist = coin:pressedBy(dotX, dotY)
  if not offX then return end
  local angle = math.atan2(coin.y - dotY, coin.x - dotX)
  local power = resolveShot(item, offDist)
  local endX  = coin.x + cos(angle) * power
  local endY  = coin.y + sin(angle) * power
  lg.setColor(1, 0.08, 0.08, 1)
  lg.setLineWidth(2)
  lg.line(coin.x, coin.y, endX, endY)
  lg.circle("line", endX, endY, 18)
  lg.circle("line", endX, endY, 10)
  lg.circle("fill", endX, endY, 3)
  lg.line(endX - 24, endY, endX - 20, endY)
  lg.line(endX + 20, endY, endX + 24, endY)
  lg.line(endX, endY - 24, endX, endY - 20)
  lg.line(endX, endY + 20, endX, endY + 24)
  lg.setColor(1, 1, 1, 1)
end

M.drawTriangleToolAt = drawTriangleToolAt
M.drawToolAt         = drawToolAt
M.drawLeadingEdge    = drawLeadingEdge
M.drawHighlightFor   = drawHighlightFor
M.drawRegionDebug    = drawRegionDebug
M.drawHoverDebug     = drawHoverDebug

function M.draw(self)
  -- Thick dark border frame (board surface sits inset inside it).
  lg.setColor(COLOR_BORDER[1], COLOR_BORDER[2], COLOR_BORDER[3])
  lg.rectangle("fill", L.borderX, L.borderY, L.borderW, L.borderH)

  -- Inner playing surface.
  lg.setColor(COLOR_BOARD)
  lg.rectangle("fill", L.boardX, L.boardY, L.boardW, L.boardH)

  -- Board scoring zones: data-driven rects from the active board. Drawn in
  -- index order (1 first, last on top); the white surface itself communicates
  -- the dead/miss areas, so there are no grey tints.
  local zones = L.zones
  for i = 1, #zones do
    local z = zones[i]
    lg.setColor(z.color)
    lg.rectangle("fill", z.x, z.y, z.w, z.h)
  end
  lg.setColor(COLOR_ZONE_BORDER)
  lg.setLineWidth(2)
  for i = 1, #zones do
    local z = zones[i]
    lg.rectangle("line", z.x, z.y, z.w, z.h)
  end

  -- Coin-spawn corral: a soft dashed-look ring showing where coins start.
  local sc = L.spawnCircle
  if sc then
    lg.setColor(0.55, 0.55, 0.55, 0.30)
    lg.setLineWidth(2)
    lg.circle("line", sc.x, sc.y, sc.r, 48)
  end

  -- Coins.
  for i = 1, #self.coins do self.coins[i]:draw() end

  -- Trajectory preview: flat red aiming line + bullseye at the landing point.
  if self.trajectoryPreview and self.hoveredCoin
     and self.armedDotX and not self.activeCoin then
    local tCoin = self.hoveredCoin
    local tItem = Items.byId(tCoin.itemType or "coin") or self.activeCoinItem
    local oX, oY, oDist = tCoin:pressedBy(self.armedDotX, self.armedDotY)
    if oX then
      local tAng = math.atan2(tCoin.y - self.armedDotY, tCoin.x - self.armedDotX)
      local tPow = resolveShot(tItem, oDist)
      local tlx  = tCoin.x + cos(tAng) * tPow
      local tly  = tCoin.y + sin(tAng) * tPow
      lg.setColor(1, 0.08, 0.08, 1)
      lg.setLineWidth(2)
      lg.line(tCoin.x, tCoin.y, tlx, tly)
      lg.circle("line", tlx, tly, 18)
      lg.circle("line", tlx, tly, 10)
      lg.circle("fill", tlx, tly, 3)
      lg.line(tlx - 24, tly, tlx - 20, tly)
      lg.line(tlx + 20, tly, tlx + 24, tly)
      lg.line(tlx, tly - 24, tlx, tly - 20)
      lg.line(tlx, tly + 20, tlx, tly + 24)
      lg.setColor(1, 1, 1, 1)
    end
  end

  -- Highlight the coin the tool will fire against.
  drawHighlightFor(self.hoveredCoin)

  -- Flip tool follows the cursor.
  if self.toolType == TOOL_TRIANGLE then
    drawTriangleToolAt(self.toolX, self.toolY)
  else
    drawToolAt(self.toolX, self.toolY)
  end
  drawLeadingEdge(self.toolX, self.toolY, self.toolType, self.hoveredCoin)

  -- Region debug overlay (press 'g' to toggle).
  if self.debugRegions then
    for i = 1, #self.coins do
      local dItem = Items.byId(self.coins[i].itemType or "coin") or self.activeCoinItem
      drawRegionDebug(self.coins[i], dItem)
    end
    local hItem = self.hoveredCoin and
      (Items.byId(self.hoveredCoin.itemType or "coin") or self.activeCoinItem)
    drawHoverDebug(self.hoveredCoin, hItem, self.armedDotX, self.armedDotY)
  end

  -- x30 bonus burst.
  if self.bonusFlash > 0 then
    local bft     = self.bonusFlash
    local bfAlpha = bft * bft
    local bfScale = 1.5 + (1 - bft) * 2.5
    local bcx     = L.boardX + L.boardW * 0.5
    local bcy     = L.boardY + L.boardH * 0.42
    lg.push()
    lg.translate(bcx, bcy)
    lg.scale(bfScale, bfScale)
    lg.setFont(F.HUGE)
    local bStr = "x30!"
    local bsW  = F.HUGE:getWidth(bStr)
    local bsH  = F.HUGE:getHeight()
    lg.setColor(0.55, 0.28, 0, bfAlpha * 0.50)
    lg.print(bStr, -bsW * 0.5 + 3, -bsH * 0.5 + 3)
    lg.setColor(1, 0.86, 0.10, bfAlpha)
    lg.print(bStr, -bsW * 0.5, -bsH * 0.5)
    lg.pop()
  end

  lg.setColor(1, 1, 1, 1)
end

return M

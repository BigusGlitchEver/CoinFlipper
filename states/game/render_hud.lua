-- states/game/render_hud.lua
-- The left notebook/parchment sidebar: floor card, marble progress + chain
-- multiplier, hot-streak pips, active-cards placeholder, preview toggle button.

local C = require("states.game.config")
local L = require("states.game.layout")
local F = require("states.game.fonts")

local lg    = love.graphics
local lt    = love.timer
local max   = math.max
local floor = math.floor
local sin   = math.sin

-- Format an integer with comma separators, e.g. 12345 → "12,345".
local function commaNum(n)
  local s = tostring(floor(n))
  local result, i = "", #s
  while i > 0 do
    local from = math.max(1, i - 2)
    result = s:sub(from, i) .. result
    if from > 1 then result = "," .. result end
    i = from - 1
  end
  return result
end

local COLOR_HUD_BG      = C.COLOR_HUD_BG
local COLOR_CARD_BG     = C.COLOR_CARD_BG
local COLOR_CARD_BORDER = C.COLOR_CARD_BORDER
local COLOR_CARD_LABEL  = C.COLOR_CARD_LABEL
local COLOR_CARD_VALUE  = C.COLOR_CARD_VALUE
local COLOR_MULT_GOLD   = C.COLOR_MULT_GOLD
local COLOR_BAR_BG      = C.COLOR_BAR_BG
local COLOR_BAR_FILL    = C.COLOR_BAR_FILL
local FLOOR_THRESHOLDS  = C.FLOOR_THRESHOLDS
local NUM_FLOORS        = C.NUM_FLOORS
local PREVIEW_BTN_H     = C.PREVIEW_BTN_H
local NEXT_ARROW_X      = C.NEXT_ARROW_X
local NEXT_ARROW_Y      = C.NEXT_ARROW_Y
local NEXT_ARROW_W      = C.NEXT_ARROW_W
local NEXT_ARROW_H      = C.NEXT_ARROW_H
local abs               = math.abs

local M = {}

function M.draw(self)
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
  lg.setFont(F.MEDIUM)
  lg.setColor(COLOR_CARD_VALUE[1], COLOR_CARD_VALUE[2], COLOR_CARD_VALUE[3])
  lg.print(string.upper(self.houseName or "?"), cx + 10, cy + 8)
  lg.setColor(COLOR_CARD_BORDER[1], COLOR_CARD_BORDER[2], COLOR_CARD_BORDER[3], 0.30)
  lg.setLineWidth(1)
  lg.line(cx + 10, cy + 30, cx + cw - 10, cy + 30)
  lg.setFont(F.SMALL)
  lg.setColor(COLOR_CARD_LABEL[1], COLOR_CARD_LABEL[2], COLOR_CARD_LABEL[3])
  lg.print("FLOOR  " .. self.floor .. " / " .. NUM_FLOORS, cx + 10, cy + 38)
  lg.printf("FLIPS: " .. (self.flipsLeft or 0), cx, cy + 38, cw - 10, "right")
  lg.print("FLOOR TARGET: " .. commaNum(FLOOR_THRESHOLDS[self.floor] or 0), cx + 10, cy + 60)
  cy = cy + c1h + pm

  -- ── Card 2: Marble Progress ──────────────────────────────────────────
  local c2h = 182
  lg.setColor(COLOR_CARD_BG[1], COLOR_CARD_BG[2], COLOR_CARD_BG[3])
  lg.rectangle("fill", cx, cy, cw, c2h, 6, 6)
  lg.setColor(COLOR_CARD_BORDER[1], COLOR_CARD_BORDER[2], COLOR_CARD_BORDER[3])
  lg.setLineWidth(2)
  lg.rectangle("line", cx, cy, cw, c2h, 6, 6)
  lg.setFont(F.SMALL)
  lg.setColor(COLOR_CARD_LABEL[1], COLOR_CARD_LABEL[2], COLOR_CARD_LABEL[3])
  lg.print("MARBLES EARNED", cx + 10, cy + 8)
  if self.scoreFlash > 0 then
    local fi = self.scoreFlash / 0.20
    lg.setColor(0.92, 0.70, 0.15, 0.26 * fi)
    lg.rectangle("fill", cx + 6, cy + 22, cw - 12, 50, 4, 4)
  end
  lg.setFont(F.HUGE)
  lg.setColor(COLOR_CARD_VALUE[1], COLOR_CARD_VALUE[2], COLOR_CARD_VALUE[3])
  lg.print(commaNum(self.runMarbles or 0), cx + 10, cy + 24)
  local barX   = cx + 10
  local barY   = cy + 82
  local barW   = cw - 32
  local barH   = 14
  local thresh = FLOOR_THRESHOLDS[self.floor] or 1
  local frac   = math.min((self.floorMarbles or 0) / thresh, 1)
  lg.setColor(COLOR_BAR_BG[1], COLOR_BAR_BG[2], COLOR_BAR_BG[3])
  lg.rectangle("fill", barX, barY, barW, barH, 5, 5)
  if frac > 0 then
    lg.setColor(COLOR_BAR_FILL[1], COLOR_BAR_FILL[2], COLOR_BAR_FILL[3])
    lg.rectangle("fill", barX, barY, max(barH, floor(barW * frac)), barH, 5, 5)
  end
  lg.setColor(COLOR_CARD_BORDER[1], COLOR_CARD_BORDER[2], COLOR_CARD_BORDER[3], 0.55)
  lg.setLineWidth(1)
  lg.rectangle("line", barX, barY, barW, barH, 5, 5)
  if self.floorTargetMet then
    -- Pulsing green "progress to next floor" arrow at the bar's right end.
    local ax, ay, aw, ah = NEXT_ARROW_X, NEXT_ARROW_Y, NEXT_ARROW_W, NEXT_ARROW_H
    local pulse = 0.70 + 0.30 * abs(sin(lt.getTime() * 4))
    lg.setColor(0.20, 0.72, 0.26, pulse)
    lg.rectangle("fill", ax, ay, aw, ah, 6, 6)
    lg.setColor(0.08, 0.34, 0.12)
    lg.setLineWidth(2)
    lg.rectangle("line", ax, ay, aw, ah, 6, 6)
    lg.setColor(1, 1, 1, 1)
    local acx, acy = ax + aw * 0.5, ay + ah * 0.5
    lg.polygon("fill", acx - 5, acy - 7, acx - 5, acy + 7, acx + 8, acy)
  else
    local sCX = barX + barW + 14
    local sCY = barY + barH * 0.5
    lg.setColor(COLOR_MULT_GOLD[1], COLOR_MULT_GOLD[2], COLOR_MULT_GOLD[3])
    lg.circle("fill", sCX, sCY, 9)
    lg.setColor(0.18, 0.10, 0.02)
    lg.setLineWidth(1.5)
    lg.circle("line", sCX, sCY, 9)
  end
  local mScale = 1.0
  if self.multBounce > 0 then
    local t = self.multBounce / 0.28
    mScale = 1 + 0.32 * t * t
  end
  local multStr = "x" .. self.multiplier
  local mcol    = self.multiplier > 1 and COLOR_MULT_GOLD or COLOR_CARD_LABEL
  local mCX     = cx + cw * 0.5
  local mCY     = cy + 135
  lg.push()
  lg.translate(mCX, mCY)
  lg.scale(mScale, mScale)
  lg.setFont(F.LARGE)
  local mW  = F.LARGE:getWidth(multStr)
  local mHt = F.LARGE:getHeight()
  if self.multiplier > 1 then
    lg.setColor(0.52, 0.32, 0.04, 0.28)
    lg.print(multStr, -mW * 0.5 + 2, -mHt * 0.5 + 2)
  end
  lg.setColor(mcol[1], mcol[2], mcol[3])
  lg.print(multStr, -mW * 0.5, -mHt * 0.5)
  lg.pop()
  lg.setFont(F.SMALL)
  lg.setColor(COLOR_CARD_LABEL[1], COLOR_CARD_LABEL[2], COLOR_CARD_LABEL[3])
  lg.printf("CHAIN", cx, cy + 160, cw, "center")
  cy = cy + c2h + pm

  -- Hot-streak progress card.
  local cSH  = 48
  local pipR = 7
  local pipG = floor(cw / 4)
  local p1x  = cx + floor(cw * 0.5) - pipG
  lg.setColor(COLOR_CARD_BG[1], COLOR_CARD_BG[2], COLOR_CARD_BG[3])
  lg.rectangle("fill", cx, cy, cw, cSH, 6, 6)
  lg.setColor(COLOR_CARD_BORDER[1], COLOR_CARD_BORDER[2], COLOR_CARD_BORDER[3])
  lg.setLineWidth(2)
  lg.rectangle("line", cx, cy, cw, cSH, 6, 6)
  lg.setFont(F.SMALL)
  lg.setColor(COLOR_CARD_LABEL[1], COLOR_CARD_LABEL[2], COLOR_CARD_LABEL[3])
  lg.print("HOT STREAK", cx + 8, cy + 7)
  local pipY = cy + cSH - 14
  for _pi = 1, 3 do
    local pipX = p1x + (_pi - 1) * pipG
    local pa   = 1.0
    if self.bonusReady then
      pa = 0.55 + 0.45 * math.abs(sin(lt.getTime() * 5))
    end
    if _pi <= self.hotStreak then
      lg.setColor(COLOR_MULT_GOLD[1], COLOR_MULT_GOLD[2], COLOR_MULT_GOLD[3], pa)
    else
      lg.setColor(COLOR_BAR_BG[1], COLOR_BAR_BG[2], COLOR_BAR_BG[3])
    end
    lg.circle("fill", pipX, pipY, pipR)
    lg.setColor(COLOR_CARD_BORDER[1], COLOR_CARD_BORDER[2], COLOR_CARD_BORDER[3])
    lg.setLineWidth(1.5)
    lg.circle("line", pipX, pipY, pipR)
  end
  if self.bonusReady then
    local bra = 0.65 + 0.35 * math.abs(sin(lt.getTime() * 5))
    lg.setColor(COLOR_MULT_GOLD[1], COLOR_MULT_GOLD[2], COLOR_MULT_GOLD[3], bra)
    lg.printf("BONUS READY!", cx, cy + 7, cw - 8, "right")
  end
  cy = cy + cSH + pm

  -- ── Card 3: Active Cards (fills remaining panel height) ──────────────
  local c3h = max(60, L.H - cy - pm - PREVIEW_BTN_H - pm)
  lg.setColor(COLOR_CARD_BG[1], COLOR_CARD_BG[2], COLOR_CARD_BG[3])
  lg.rectangle("fill", cx, cy, cw, c3h, 6, 6)
  lg.setColor(COLOR_CARD_BORDER[1], COLOR_CARD_BORDER[2], COLOR_CARD_BORDER[3])
  lg.setLineWidth(2)
  lg.rectangle("line", cx, cy, cw, c3h, 6, 6)
  lg.setFont(F.SMALL)
  lg.setColor(COLOR_CARD_LABEL[1], COLOR_CARD_LABEL[2], COLOR_CARD_LABEL[3])
  lg.print("ACTIVE CARDS", cx + 10, cy + 10)
  -- Active-cards list (banner rows) drawn by the owning state's CardPanel.
  -- It slots into this region; the empty-state text lives in CardPanel:draw().
  if self.cardPanel then
    self.cardPanel:setRegion(cx + 8, cy + 30, cw - 16)
    self.cardPanel:draw()
  end

  -- Preview toggle button — pinned to the bottom of the sidebar panel.
  local btnY = L.H - PREVIEW_BTN_H - pm
  if self.trajectoryPreview then
    lg.setColor(COLOR_BAR_FILL[1], COLOR_BAR_FILL[2], COLOR_BAR_FILL[3], 0.50)
  else
    lg.setColor(COLOR_BAR_BG[1], COLOR_BAR_BG[2], COLOR_BAR_BG[3], 0.60)
  end
  lg.rectangle("fill", cx, btnY, cw, PREVIEW_BTN_H, 5, 5)
  lg.setColor(COLOR_CARD_BORDER[1], COLOR_CARD_BORDER[2], COLOR_CARD_BORDER[3],
              self.trajectoryPreview and 1.0 or 0.40)
  lg.setLineWidth(self.trajectoryPreview and 2.5 or 1.5)
  lg.rectangle("line", cx, btnY, cw, PREVIEW_BTN_H, 5, 5)
  lg.setFont(F.SMALL)
  lg.setColor(COLOR_CARD_VALUE[1], COLOR_CARD_VALUE[2], COLOR_CARD_VALUE[3],
              self.trajectoryPreview and 1.0 or 0.50)
  lg.printf(self.trajectoryPreview and "PREVIEW  ON" or "PREVIEW  OFF",
            cx, btnY + floor(PREVIEW_BTN_H * 0.5) - 6, cw, "center")

  -- Restore default font before board rendering.
  lg.setFont(F.DEFAULT)
end

return M

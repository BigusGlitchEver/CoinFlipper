-- ui/card.lua
-- A single active-card banner row (wide + short, NOT a playing-card shape).
-- Two visual types: "bicycle" (parchment + rank/suit) and "monster" (green +
-- a hand-drawn creature). All art is love.graphics primitives — no images.

local Object = require("lib.classic")

local lg = love.graphics

local Card = Object:extend()

-- ---------- Module-level color constants (no inline alloc in draw) ----------
local function rgb(r, g, b) return { r / 255, g / 255, b / 255 } end

-- Bicycle palette
local BIKE_BG     = rgb(0xfd, 0xf6, 0xec)  -- #fdf6ec parchment body
local BIKE_BORDER = rgb(0xc8, 0xa9, 0x6e)  -- #c8a96e golden-brown
local BIKE_ICONBG = rgb(0xf5, 0xe8, 0xd0)  -- #f5e8d0 darker left box
-- Monster palette
local MON_BG      = rgb(0xf0, 0xfa, 0xee)  -- #f0faee light green body
local MON_BORDER  = rgb(0x3a, 0x8a, 0x3a)  -- #3a8a3a dark green
local MON_ICONBG  = rgb(0x1a, 0x4a, 0x1a)  -- #1a4a1a very dark green box
-- Suit colors
local SUIT_HEART   = rgb(0xb2, 0x22, 0x22)  -- #b22222 red
local SUIT_DIAMOND = rgb(0xcc, 0x66, 0x00)  -- #cc6600 orange
local SUIT_DARK    = rgb(0x1a, 0x1a, 0x8c)  -- #1a1a8c spade/club blue
-- Text
local TXT_NAME = rgb(0x2a, 0x20, 0x12)
local TXT_DESC = rgb(0x55, 0x48, 0x38)
local SLIME_BODY = rgb(0x6a, 0xc8, 0x5a)
local SLIME_DARK = rgb(0x12, 0x30, 0x12)

-- ---------- Layout constants ----------
local ROW_H  = 58
local ICON_W = 52
local PAD    = 8

-- ---------- Lazy fonts (created once, after the window exists) ----------
local F_RANK, F_NAME, F_DESC
local function ensureFonts()
  if F_RANK then return end
  F_RANK = lg.newFont(26)
  F_NAME = lg.newFont(13)
  F_DESC = lg.newFont(10)
end

function Card:new(data)
  self.rank        = data.rank
  self.suit        = data.suit
  self.name        = data.name
  self.description = data.description
  self.cardType    = data.cardType or "bicycle"
  self.width       = data.width or 200   -- set by the owning CardPanel
end

function Card:getHeight() return ROW_H end

-- ---------- Suit symbols (filled primitives) ----------
local function drawHeart(cx, cy, s)
  local r = s * 0.30
  lg.circle("fill", cx - r, cy - r * 0.5, r)
  lg.circle("fill", cx + r, cy - r * 0.5, r)
  lg.polygon("fill", cx - s * 0.6, cy - r * 0.1,
                     cx + s * 0.6, cy - r * 0.1,
                     cx, cy + s * 0.7)
end

local function drawDiamond(cx, cy, s)
  lg.polygon("fill", cx, cy - s * 0.8,
                     cx + s * 0.6, cy,
                     cx, cy + s * 0.8,
                     cx - s * 0.6, cy)
end

local function drawSpade(cx, cy, s)
  local r = s * 0.30
  -- inverted heart lobes + top point
  lg.polygon("fill", cx, cy - s * 0.7,
                     cx + s * 0.6, cy + r * 0.3,
                     cx - s * 0.6, cy + r * 0.3)
  lg.circle("fill", cx - r, cy + r * 0.2, r)
  lg.circle("fill", cx + r, cy + r * 0.2, r)
  lg.rectangle("fill", cx - s * 0.08, cy, s * 0.16, s * 0.6)
end

local function drawClub(cx, cy, s)
  local r = s * 0.28
  lg.circle("fill", cx, cy - s * 0.35, r)
  lg.circle("fill", cx - r, cy + r * 0.2, r)
  lg.circle("fill", cx + r, cy + r * 0.2, r)
  lg.rectangle("fill", cx - s * 0.08, cy, s * 0.16, s * 0.6)
end

-- ---------- Magnet Slime creature ----------
local function drawSlime(cx, cy, s)
  -- magnet horns on stalks above the head
  lg.setColor(SLIME_DARK)
  lg.setLineWidth(2)
  lg.line(cx - s * 0.35, cy - s * 0.35, cx - s * 0.35, cy - s * 0.7)
  lg.line(cx + s * 0.35, cy - s * 0.35, cx + s * 0.35, cy - s * 0.7)
  lg.setColor(SLIME_BODY)
  lg.circle("fill", cx - s * 0.35, cy - s * 0.75, s * 0.14)
  lg.circle("fill", cx + s * 0.35, cy - s * 0.75, s * 0.14)
  -- body
  lg.setColor(SLIME_BODY)
  lg.ellipse("fill", cx, cy + s * 0.1, s * 0.7, s * 0.55)
  -- eyes
  lg.setColor(SLIME_DARK)
  lg.circle("fill", cx - s * 0.25, cy, s * 0.13)
  lg.circle("fill", cx + s * 0.25, cy, s * 0.13)
  lg.setColor(1, 1, 1, 1)
  lg.circle("fill", cx - s * 0.21, cy - s * 0.04, s * 0.05)
  lg.circle("fill", cx + s * 0.29, cy - s * 0.04, s * 0.05)
  -- mouth
  lg.setColor(SLIME_DARK)
  lg.rectangle("fill", cx - s * 0.12, cy + s * 0.28, s * 0.24, s * 0.07)
end

-- ---------- Full banner row ----------
function Card:draw(x, y)
  ensureFonts()
  local w = self.width
  local isMon = self.cardType == "monster"
  local body   = isMon and MON_BG     or BIKE_BG
  local border = isMon and MON_BORDER or BIKE_BORDER
  local iconbg = isMon and MON_ICONBG or BIKE_ICONBG

  -- card body + border
  lg.setColor(body)
  lg.rectangle("fill", x, y, w, ROW_H, 6, 6)
  lg.setColor(border)
  lg.setLineWidth(2)
  lg.rectangle("line", x, y, w, ROW_H, 6, 6)

  -- left icon box
  lg.setColor(iconbg)
  lg.rectangle("fill", x + 2, y + 2, ICON_W, ROW_H - 4, 5, 5)

  local iconCX = x + 2 + ICON_W * 0.5
  local iconCY = y + ROW_H * 0.5

  if isMon then
    drawSlime(iconCX, iconCY, 16)
  else
    -- rank number (top) + suit symbol (below)
    local suitCol = SUIT_DARK
    if self.suit == "heart" then suitCol = SUIT_HEART
    elseif self.suit == "diamond" then suitCol = SUIT_DIAMOND end
    lg.setColor(suitCol)
    lg.setFont(F_RANK)
    local rs = tostring(self.rank or "")
    lg.print(rs, iconCX - F_RANK:getWidth(rs) * 0.5, y + 4)
    -- suit glyph below the number
    local sy = y + ROW_H - 16
    if self.suit == "heart" then drawHeart(iconCX, sy, 9)
    elseif self.suit == "diamond" then drawDiamond(iconCX, sy, 9)
    elseif self.suit == "club" then drawClub(iconCX, sy, 9)
    else drawSpade(iconCX, sy, 9) end
  end

  -- right side: name + wrapped description
  local tx = x + ICON_W + PAD + 4
  local tw = w - ICON_W - PAD * 2 - 4
  lg.setColor(TXT_NAME)
  lg.setFont(F_NAME)
  lg.print(string.upper(self.name or ""), tx, y + 7)
  lg.setColor(TXT_DESC)
  lg.setFont(F_DESC)
  lg.printf(self.description or "", tx, y + 25, tw, "left")

  lg.setColor(1, 1, 1, 1)
end

return Card

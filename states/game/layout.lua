-- states/game/layout.lua
-- The shared layout table L, rebuilt on enter / resize. A single mutable table
-- instance is returned so every module that requires it sees the same numbers.

local C = require("states.game.config")

local lg    = love.graphics
local floor = math.floor

local PANEL_W             = C.PANEL_W
local BORDER_T            = C.BORDER_T
local MARGIN              = C.MARGIN
local COIN_RADIUS_AT_390W = C.COIN_RADIUS_AT_390W
local TOOL_R_FACTOR       = C.TOOL_R_FACTOR

local L = {}

function L.rebuild()
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

  -- Blank white START strip along the bottom of the board.
  L.startH = floor(L.boardH * 0.34)
  L.startY = L.boardY + L.boardH - L.startH

  -- Scoring target area = the board ABOVE the start strip.
  L.targetX = L.boardX
  L.targetY = L.boardY
  L.targetW = L.boardW
  L.targetH = L.boardH - L.startH

  -- Concentric-rect zone insets (px from each target-area edge).
  local s  = math.min(L.targetW, L.targetH)
  L.zone1  = floor(s * 0.08)   -- white → blue  boundary
  L.zone2  = floor(s * 0.20)   -- blue  → yellow boundary
  L.zone3  = floor(s * 0.34)   -- yellow → red  boundary

  -- Coin + tool size.
  L.coinR = COIN_RADIUS_AT_390W
  L.toolR = L.coinR * TOOL_R_FACTOR
end

return L

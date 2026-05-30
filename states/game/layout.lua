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

-- Pre-allocated, reused every rebuild so we never churn tables in draw/update.
L.zones     = {}   -- pixel scoring rects: { x, y, w, h, points, color }
L.deadZones = {}   -- pixel grey-tint rects: { x, y, w, h }
L.floor     = 1

-- Converts the proportional zone defs from C.getZoneLayout(floor) into pixel
-- rects inside the current TARGET area. Repopulates L.zones / L.deadZones in
-- place (no new tables). Call after L.rebuild() and whenever the floor changes.
function L.buildZones(floor)
  L.floor = floor or 1
  local def = C.getZoneLayout(L.floor)
  local tx, ty = L.targetX, L.targetY
  local tw, th = L.targetW, L.targetH

  local zsrc = def.zones
  local n = #zsrc
  for i = 1, n do
    local z = zsrc[i]
    local dst = L.zones[i]
    if not dst then dst = {}; L.zones[i] = dst end
    dst.x      = tx + z.xPct * tw
    dst.y      = ty + z.yPct * th
    dst.w      = z.wPct * tw
    dst.h      = z.hPct * th
    dst.points = z.points
    dst.color  = z.color
  end
  for i = n + 1, #L.zones do L.zones[i] = nil end

  local dsrc = def.dead
  local dn = #dsrc
  for i = 1, dn do
    local d = dsrc[i]
    local dst = L.deadZones[i]
    if not dst then dst = {}; L.deadZones[i] = dst end
    dst.x = tx + d.xPct * tw
    dst.y = ty + d.yPct * th
    dst.w = d.wPct * tw
    dst.h = d.hPct * th
  end
  for i = dn + 1, #L.deadZones do L.deadZones[i] = nil end
end

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

  -- Coin + tool size.
  L.coinR = COIN_RADIUS_AT_390W
  L.toolR = L.coinR * TOOL_R_FACTOR

  -- Rebuild the pixel scoring zones for the current floor.
  L.buildZones(L.floor)
end

return L

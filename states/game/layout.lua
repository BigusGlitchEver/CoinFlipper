-- states/game/layout.lua
-- The shared layout table L, rebuilt on enter / resize. A single mutable table
-- instance is returned so every module that requires it sees the same numbers.

local C = require("states.game.config")

local lg    = love.graphics
local floor = math.floor
local min   = math.min

local PANEL_W             = C.PANEL_W
local BORDER_T            = C.BORDER_T
local MARGIN              = C.MARGIN
local COIN_RADIUS_AT_390W = C.COIN_RADIUS_AT_390W
local TOOL_R_FACTOR       = C.TOOL_R_FACTOR

local L = {}

-- Pre-allocated, reused on every board load so we never churn tables in
-- draw/update. Each entry: { x, y, w, h, points, color = {r,g,b} }.
L.zones        = {}
L.currentBoard = nil   -- the board def table currently loaded (for resize)

-- Optional coin-spawn circle for the active board: { x, y, r } in pixels, or
-- nil when the board scatters coins across the whole interior. Reused in place.
L.spawnCircle  = nil
local _spawnCircle = { x = 0, y = 0, r = 0 }

-- Parses a "#RRGGBB" hex string into the reused out table {r,g,b} in 0..1.
local function hexColor(hex, out)
  out[1] = tonumber(hex:sub(2, 3), 16) / 255
  out[2] = tonumber(hex:sub(4, 5), 16) / 255
  out[3] = tonumber(hex:sub(6, 7), 16) / 255
  return out
end

-- Loads a board definition (already require()d) and converts each proportional
-- zone into an absolute pixel rect inside the FULL board interior rectangle
-- (the entire white surface: boardX/Y/W/H, wall to wall). Repopulates L.zones
-- in place — never allocates a new array, and reuses each zone + color table.
function L.loadBoard(boardDef)
  L.currentBoard = boardDef
  local bx, by = L.boardX, L.boardY
  local bw, bh = L.boardW, L.boardH

  local zsrc = boardDef.zones
  local n = #zsrc
  for i = 1, n do
    local z   = zsrc[i]
    local dst = L.zones[i]
    if not dst then dst = { color = {} }; L.zones[i] = dst end
    if not dst.color then dst.color = {} end
    dst.x      = bx + z.xPct * bw
    dst.y      = by + z.yPct * bh
    dst.w      = z.wPct * bw
    dst.h      = z.hPct * bh
    dst.points = z.points
    hexColor(z.color, dst.color)
  end
  -- Trim any leftover zones from a previously larger board.
  for i = n + 1, #L.zones do L.zones[i] = nil end

  -- Optional spawn circle. A board opts in with:
  --   spawn = { cxPct = .., cyPct = .., rPct = .. }
  -- cxPct/cyPct are centre fractions of the board interior; rPct is a fraction
  -- of the interior's smaller dimension. When present, coins start inside this
  -- circle instead of scattering across the whole surface.
  local sp = boardDef.spawn
  if sp then
    _spawnCircle.x = bx + sp.cxPct * bw
    _spawnCircle.y = by + sp.cyPct * bh
    _spawnCircle.r = sp.rPct * min(bw, bh)
    L.spawnCircle  = _spawnCircle
  else
    L.spawnCircle = nil
  end
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

  -- Inner playing surface (inset BORDER_T on all sides). This full rectangle
  -- is the entire white board interior — zones can be placed anywhere on it.
  L.boardX = L.borderX + BORDER_T
  L.boardY = L.borderY + BORDER_T
  L.boardW = L.borderW - BORDER_T * 2
  L.boardH = L.borderH - BORDER_T * 2

  -- Coin + tool size.
  L.coinR = COIN_RADIUS_AT_390W
  L.toolR = L.coinR * TOOL_R_FACTOR

  -- Re-project the current board's zones onto the new geometry.
  if L.currentBoard then L.loadBoard(L.currentBoard) end
end

return L

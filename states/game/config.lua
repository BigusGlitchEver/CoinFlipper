-- states/game/config.lua
-- All tunables, palette colors, and precomputed geometry constants for the
-- flip board. Pure data + load-time math; no love.graphics state, no fonts.

local pi = math.pi

local M = {}

-- Tool radius factor (1.5x coin radius). Read by drawing AND hit-testing.
M.TOOL_R_FACTOR = 1.5

-- ---------- Rim dots & Simon Says arc bars ----------
local DOT_UX, DOT_UY = {}, {}
local DOT_ANGLES_RAD = {}
do
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
M.DOT_UX = DOT_UX
M.DOT_UY = DOT_UY
M.DOT_ANGLES_RAD = DOT_ANGLES_RAD
M.SLIVER_HALF_WIDTH = 9 * pi / 180
M.SLIVER_LINE_WIDTH = 5
M.DOT_COLORS = {
  { 0xFF/255, 0x44/255, 0x44/255 },  -- 1 red
  { 0xFF/255, 0x99/255, 0x33/255 },  -- 2 orange
  { 0xFF/255, 0xDD/255, 0x00/255 },  -- 3 yellow
  { 0x44/255, 0xCC/255, 0x44/255 },  -- 4 green
  { 0x33/255, 0xCC/255, 0xFF/255 },  -- 5 cyan
  { 0xAA/255, 0x44/255, 0xFF/255 },  -- 6 purple
}
M.DOT_COLORS_DARK = {
  { 0x99/255, 0x22/255, 0x22/255 },  -- 1 dark red
  { 0x99/255, 0x55/255, 0x11/255 },  -- 2 dark orange
  { 0x99/255, 0x88/255, 0x00/255 },  -- 3 dark yellow
  { 0x22/255, 0x77/255, 0x22/255 },  -- 4 dark green
  { 0x11/255, 0x66/255, 0x88/255 },  -- 5 dark cyan
  { 0x55/255, 0x11/255, 0x88/255 },  -- 6 dark purple
}

M.TOOL_CIRCLE   = "circle"
M.TOOL_TRIANGLE = "triangle"

-- Triangle tip unit vectors (equilateral, tip pointing up).
local TRI_UX = {}
local TRI_UY = {}
do
  TRI_UX[1] =  0.159;  TRI_UY[1] = -0.630  -- top tip
  TRI_UX[2] =  0.830;  TRI_UY[2] =  0.576  -- bottom-right tip
  TRI_UX[3] = -0.833;  TRI_UY[3] =  0.707  -- bottom-left tip
end
M.TRI_UX = TRI_UX
M.TRI_UY = TRI_UY
M.TRI_COLORS = {
  { 1.00, 0.60, 0.15 },  -- tip 1: amber (top)
  { 0.15, 0.85, 0.60 },  -- tip 2: teal  (bottom-right)
  { 0.75, 0.15, 1.00 },  -- tip 3: violet (bottom-left)
}

-- ---------- Visual spec colors ----------
M.COLOR_BG             = { 0xEE/255, 0xEE/255, 0xEE/255 }
M.COLOR_BOARD          = { 1, 1, 1 }
M.COLOR_BOARD_BORDER   = { 0xAA/255, 0xAA/255, 0xAA/255 }
M.COLOR_ZONE_BLUE      = { 0.25, 0.50, 0.85 }  -- blue band:   1 pt
M.COLOR_ZONE_YELLOW    = { 0.96, 0.80, 0.10 }  -- yellow band: 2 pts
M.COLOR_ZONE_RED       = { 0.85, 0.18, 0.14 }  -- red centre:  3 pts
M.COLOR_ZONE_BORDER    = { 0.15, 0.15, 0.15 }  -- dark outlines between zones
M.COLOR_TOOL           = { 0x9A/255, 0xA0/255, 0xA6/255 }
M.COLOR_TOOL_OUTLINE   = { 0x33/255, 0x33/255, 0x33/255 }
M.COLOR_HIGHLIGHT      = { 0.20, 0.95, 1.00 }   -- cyan "armed" ring
M.COLOR_TOOL_HL        = { 1.00, 0.88, 0.30 }   -- lit leading-edge segment
M.TOOL_BORDER_WIDTH    = 4                       -- chip border thickness
M.COLOR_TEXT           = { 0.10, 0.10, 0.10 }
M.COLOR_TEXT_DIM       = { 0.40, 0.40, 0.40 }
M.COLOR_PANEL          = { 0x22/255, 0x22/255, 0x22/255 }  -- left panel bg
M.COLOR_BORDER         = { 0x33/255, 0x33/255, 0x33/255 }  -- board border frame
M.COLOR_PANEL_LABEL    = { 0.55, 0.55, 0.55 }
M.COLOR_PANEL_VALUE    = { 1.00, 1.00, 1.00 }
M.COLOR_MULT_ACTIVE    = { 1.00, 0.85, 0.25 }  -- gold when chain active
M.COLOR_MULT_IDLE      = { 0.45, 0.45, 0.45 }  -- dim when x1
M.COLOR_BTN            = { 0.28, 0.28, 0.28 }
M.COLOR_BTN_BORDER     = { 0.48, 0.48, 0.48 }
M.COLOR_BTN_TEXT       = { 0.78, 0.78, 0.78 }
M.COLOR_DEBUG_ON       = { 0.25, 0.80, 0.35 }
M.COLOR_TOOL_ACTIVE    = { 0.25, 0.60, 1.00 }  -- blue tint for selected tool btn

-- Notebook / parchment HUD palette
M.COLOR_HUD_BG      = { 0.88, 0.84, 0.76 }  -- warm tan panel background
M.COLOR_CARD_BG     = { 0.98, 0.95, 0.88 }  -- cream card fill
M.COLOR_CARD_BORDER = { 0.48, 0.34, 0.18 }  -- warm brown card border
M.COLOR_CARD_LABEL  = { 0.38, 0.28, 0.14 }  -- dark brown label text
M.COLOR_CARD_VALUE  = { 0.11, 0.08, 0.04 }  -- near-black value text
M.COLOR_MULT_GOLD   = { 0.88, 0.60, 0.04 }  -- gold chain multiplier
M.COLOR_BAR_BG      = { 0.74, 0.68, 0.56 }  -- muted tan bar background
M.COLOR_BAR_FILL    = { 0.20, 0.56, 0.20 }  -- green progress fill

-- ---------- Tunables ----------
M.COINS_PER_FLOOR     = 5
M.COIN_RADIUS_AT_390W = 24                  -- spec: 48px DIAMETER at 390w
M.FLOOR_THRESHOLDS    = { [1] = 20, [2] = 60, [3] = 120 }
M.NUM_FLOORS          = 3
M.POINTS              = { red = 3, yellow = 2, blue = 1 }  -- zone point values
M.CHAIN_BONUS         = { [0] = 1, [1] = 2, [2] = 10, [3] = 100 }
M.MIN_BOARD_COINS     = 6    -- replenish below this
M.TARGET_BOARD_COINS  = 8    -- replenish up to this
M.PANEL_W             = 220  -- left score panel width
M.BORDER_T            = 10   -- board border thickness (pixels each side)
M.MARGIN              = 12   -- gap between screen edge/panel and border outer edge
M.PREVIEW_BTN_H       = 34   -- height of the preview-toggle button in the sidebar
M.CHAIN_SPAWN_MAX_DEPTH = 1  -- chain reactions cap at this depth (spawn + chain stop)
M.TOOL_HL_HALF        = 32 * pi / 180   -- circle highlight arc half-width

return M

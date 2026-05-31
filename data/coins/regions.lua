-- data/coins/regions.lua
-- Shared collision-region grids referenced by the individual coin files in
-- data/coins/. Authored once here; each coin file picks the grid that matches
-- its intended feel (DEFAULT = standard 3x3, EASY = big dead zone, MINI = huge
-- dead zone). Direction is data-driven per region; there is NO auto-aim.
--
-- Each region: { x, y, w, h, angle [, power] [, arc] } in coin-local normalized
-- space (coin spans -1..1 per axis, center = 0,0). `angle` is the launch
-- direction in radians, screen-space (cos = +x = right, sin = +y = down).

local pi    = math.pi
local THIRD = 1 / 3
local W3    = 2 / 3
local H3    = 2 / 3

-- The default 3x3 tiddlywinks grid: pressing AWAY from where you want the coin
-- to go (left -> right, bottom -> up, corners combine). Center is "up."
local DEFAULT = {
  { x = -1,     y = -1,     w = W3, h = H3, angle =  pi/4    },  -- TL -> down-right
  { x = -THIRD, y = -1,     w = W3, h = H3, angle =  pi/2    },  -- TC -> down
  { x =  THIRD, y = -1,     w = W3, h = H3, angle =  3*pi/4  },  -- TR -> down-left
  { x = -1,     y = -THIRD, w = W3, h = H3, angle =  0       },  -- ML -> right
  { x = -THIRD, y = -THIRD, w = W3, h = H3, angle = -pi/2    },  -- C  -> up
  { x =  THIRD, y = -THIRD, w = W3, h = H3, angle =  pi      },  -- MR -> left
  { x = -1,     y =  THIRD, w = W3, h = H3, angle = -pi/4    },  -- BL -> up-right
  { x = -THIRD, y =  THIRD, w = W3, h = H3, angle = -pi/2    },  -- BC -> up
  { x =  THIRD, y =  THIRD, w = W3, h = H3, angle = -3*pi/4  },  -- BR
}

-- Easy coin regions: centre cell is large (EC half-width), a big flat dead
-- zone. Corner/edge cells shrink to fill the rest.
local EC = 0.40        -- centre cell half-width in normalised +/-1 space
local EW = 1 - EC      -- outer cell width = 0.60
local EASY = {
  { x = -1,  y = -1,  w = EW,     h = EW,     angle =  pi/4    },  -- TL
  { x = -EC, y = -1,  w = 2 * EC, h = EW,     angle =  pi/2    },  -- TC
  { x =  EC, y = -1,  w = EW,     h = EW,     angle =  3*pi/4  },  -- TR
  { x = -1,  y = -EC, w = EW,     h = 2 * EC, angle =  0       },  -- ML
  { x = -EC, y = -EC, w = 2 * EC, h = 2 * EC, angle = -pi/2    },  -- C (large)
  { x =  EC, y = -EC, w = EW,     h = 2 * EC, angle =  pi      },  -- MR
  { x = -1,  y =  EC, w = EW,     h = EW,     angle = -pi/4    },  -- BL
  { x = -EC, y =  EC, w = 2 * EC, h = EW,     angle = -pi/2    },  -- BC
  { x =  EC, y =  EC, w = EW,     h = EW,     angle = -3*pi/4  },  -- BR
}

-- Mini coin regions: even larger centre cell (MC half-width) for a very
-- forgiving dead zone.
local MC = 0.55        -- mini centre cell half-width
local MW = 1 - MC      -- outer cell width = 0.45
local MINI = {
  { x = -1,  y = -1,  w = MW,     h = MW,     angle =  pi/4    },  -- TL
  { x = -MC, y = -1,  w = 2 * MC, h = MW,     angle =  pi/2    },  -- TC
  { x =  MC, y = -1,  w = MW,     h = MW,     angle =  3*pi/4  },  -- TR
  { x = -1,  y = -MC, w = MW,     h = 2 * MC, angle =  0       },  -- ML
  { x = -MC, y = -MC, w = 2 * MC, h = 2 * MC, angle = -pi/2    },  -- C (huge)
  { x =  MC, y = -MC, w = MW,     h = 2 * MC, angle =  pi      },  -- MR
  { x = -1,  y =  MC, w = MW,     h = MW,     angle = -pi/4    },  -- BL
  { x = -MC, y =  MC, w = 2 * MC, h = MW,     angle = -pi/2    },  -- BC
  { x =  MC, y =  MC, w = MW,     h = MW,     angle = -3*pi/4  },  -- BR
}

return { DEFAULT = DEFAULT, EASY = EASY, MINI = MINI }

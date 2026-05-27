-- data/flip_items.lua
-- Per-item flight tuning. PIXEL-BASED model -- launch power and arc height
-- are measured in pixels. As of the region refactor, direction is data-driven
-- per coin type via the `regions` table -- no auto-aim, no sensitivities.
--
-- Fields:
--   zone_threshold      : split between INNER (pop) and OUTER (launch) zones
--                         in normalized contact distance (0 = center, 1 = edge).
--                         At offDist < threshold -> inner zone; >= threshold ->
--                         outer zone. There is a HARD discontinuity at the
--                         threshold -- pressing just past it snaps to a long,
--                         flat launch.
--   inner_power_center  : pop power at dead center (offDist = 0)
--   inner_power_edge    : pop power at the inner boundary (offDist = threshold)
--   inner_arc_center    : pop arc (height) at dead center
--   inner_arc_edge      : pop arc at the inner boundary
--   outer_power_center  : launch power just past the threshold
--   outer_power_edge    : launch power at the coin's outer edge (offDist = 1)
--   outer_arc_center    : launch arc just past the threshold
--   outer_arc_edge      : launch arc at the coin's outer edge
--   flight_time         : seconds of flight animation
--   regions             : list of collision boxes in coin-local normalized
--                         space (coin spans -1..1 per axis, center = 0,0).
--                         Each region:
--                           { x, y, w, h, angle [, power] [, arc] }
--                         x,y,w,h define the box in local space. `angle` is
--                         the launch direction in radians, screen-space
--                         (cos = +x = right, sin = +y = down). So -pi/2 = up
--                         the board, +pi/2 = down. Optional per-region
--                         `power` / `arc` override the zone curves for that
--                         region -- the hook for wild future trajectories.
--
-- Legacy power_sensitivity / angle_sensitivity / arc_variance / falloff are
-- intentionally gone: direction is now purely region-driven, not formulaic.

local Data = {}

local pi    = math.pi
local THIRD = 1/3
local W3    = 2/3
local H3    = 2/3

-- The default 3x3 tiddlywinks grid: pressing AWAY from where you want the
-- coin to go (left -> right, bottom -> up, corners combine). Center is "up."
-- Authored once and referenced by every item that wants the default behavior;
-- future coin types (triangle, square, blob) will define their own tables.
local DEFAULT_REGIONS = {
  -- Top row (y in [-1, -1/3]) -> fly DOWN-ish
  { x = -1,     y = -1,     w = W3, h = H3, angle =  pi/4    },  -- TL -> down-right
  { x = -THIRD, y = -1,     w = W3, h = H3, angle =  pi/2    },  -- TC -> down
  { x =  THIRD, y = -1,     w = W3, h = H3, angle =  3*pi/4  },  -- TR -> down-left
  -- Middle row (y in [-1/3, 1/3])
  { x = -1,     y = -THIRD, w = W3, h = H3, angle =  0       },  -- ML -> right
  { x = -THIRD, y = -THIRD, w = W3, h = H3, angle = -pi/2    },  -- C  -> up
  { x =  THIRD, y = -THIRD, w = W3, h = H3, angle =  pi      },  -- MR -> left
  -- Bottom row (y in [1/3, 1]) -> fly UP-ish
  { x = -1,     y =  THIRD, w = W3, h = H3, angle = -pi/4    },  -- BL -> up-right
  { x = -THIRD, y =  THIRD, w = W3, h = H3, angle = -pi/2    },  -- BC -> up
  { x =  THIRD, y =  THIRD, w = W3, h = H3, angle = -3*pi/4  },  -- BR -> up-left
}

Data.items = {
  {
    id                 = 'coin',
    name               = 'Coin',
    tier               = 'low',
    color              = { 0.45, 0.78, 0.32 },
    zone_threshold     = 0.65,
    inner_power_center = 80,    inner_power_edge = 130,
    inner_arc_center   = 220,   inner_arc_edge   = 160,
    outer_power_center = 180,   outer_power_edge = 340,
    outer_arc_center   = 70,    outer_arc_edge   = 25,
    flight_time        = 0.45,
    regions            = DEFAULT_REGIONS,
    notes              = 'Fast pop, short hang, very learnable. The honest starter.',
  },
  {
    id                 = 'lucky_coin',
    name               = 'Lucky Coin',
    tier               = 'low+',
    color              = { 0.30, 0.55, 0.85 },
    zone_threshold     = 0.65,
    inner_power_center = 80,    inner_power_edge = 130,
    inner_arc_center   = 220,   inner_arc_edge   = 160,
    outer_power_center = 180,   outer_power_edge = 340,
    outer_arc_center   = 70,    outer_arc_edge   = 25,
    flight_time        = 0.45,
    regions            = DEFAULT_REGIONS,
    notes              = 'Same flight as Coin; its edge is a bonus effect, not harder physics.',
  },
  {
    id                 = 'toast',
    name               = 'Toast',
    tier               = 'mid',
    color              = { 0.92, 0.78, 0.25 },
    zone_threshold     = 0.65,
    inner_power_center = 90,    inner_power_edge = 150,
    inner_arc_center   = 270,   inner_arc_edge   = 200,
    outer_power_center = 220,   outer_power_edge = 380,
    outer_arc_center   = 90,    outer_arc_edge   = 35,
    flight_time        = 0.65,
    regions            = DEFAULT_REGIONS,
    notes              = 'Medium hang, more drift than Coin. The in-between teacher.',
  },
  {
    id                 = 'pancakes',
    name               = 'Pancakes',
    tier               = 'high',
    color              = { 0.85, 0.30, 0.28 },
    zone_threshold     = 0.65,
    inner_power_center = 110,   inner_power_edge = 180,
    inner_arc_center   = 340,   inner_arc_edge   = 260,
    outer_power_center = 260,   outer_power_edge = 420,
    outer_arc_center   = 120,   outer_arc_edge   = 50,
    flight_time        = 0.95,
    regions            = DEFAULT_REGIONS,
    notes              = 'Slow lift, long floaty hang, tight sweet spot. High reward, hard to place.',
  },
}

function Data.byId(id)
  for i = 1, #Data.items do
    if Data.items[i].id == id then return Data.items[i] end
  end
  return nil
end

return Data

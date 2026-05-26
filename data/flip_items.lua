-- data/flip_items.lua
-- Per-item flight tuning. PIXEL-BASED model -- launch power and arc height
-- are measured in pixels. As of the region refactor, direction is data-driven
-- per coin type via the `regions` table -- no auto-aim, no sensitivities.
--
-- Fields:
--   center_power : pixels of launch travel when pressed at dead center (offDist = 0)
--   edge_power   : pixels of launch travel when pressed at the edge   (offDist = 1)
--   center_arc   : visible arc lift at flight midpoint, center press (pixels)
--   edge_arc     : visible arc lift at flight midpoint, edge press   (pixels)
--                  -> power is lerped UP toward the edge; arc is lerped UP
--                     toward the center. Edge press = long & flat;
--                     center press = short & high.
--   flight_time  : seconds of flight animation
--   base_power   : legacy default (used as a safety fallback only)
--   base_arc     : legacy default (used as a safety fallback only)
--   regions      : list of collision boxes in coin-local normalized space
--                  (coin spans -1..1 per axis, center = 0,0). Each region:
--                    { x, y, w, h, angle [, power] [, arc] }
--                  x,y,w,h define the box in local space. `angle` is the
--                  launch direction in radians, screen-space (cos = +x = right,
--                  sin = +y = down). So -pi/2 = up the board, +pi/2 = down.
--                  Optional `power` / `arc` override the item-level curves
--                  for that region -- the hook for wild future trajectories.
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
    id           = 'coin',
    name         = 'Coin',
    tier         = 'low',
    color        = { 0.45, 0.78, 0.32 },
    center_power = 120,
    edge_power   = 300,
    center_arc   = 150,
    edge_arc     = 55,
    flight_time  = 0.45,
    base_power   = 220,
    base_arc     = 80,
    regions      = DEFAULT_REGIONS,
    notes        = 'Fast pop, short hang, very learnable. The honest starter.',
  },
  {
    id           = 'lucky_coin',
    name         = 'Lucky Coin',
    tier         = 'low+',
    color        = { 0.30, 0.55, 0.85 },
    center_power = 120,
    edge_power   = 300,
    center_arc   = 150,
    edge_arc     = 55,
    flight_time  = 0.45,
    base_power   = 220,
    base_arc     = 80,
    regions      = DEFAULT_REGIONS,
    notes        = 'Same flight as Coin; its edge is a bonus effect, not harder physics.',
  },
  {
    id           = 'toast',
    name         = 'Toast',
    tier         = 'mid',
    color        = { 0.92, 0.78, 0.25 },
    center_power = 140,
    edge_power   = 340,
    center_arc   = 200,
    edge_arc     = 80,
    flight_time  = 0.65,
    base_power   = 240,
    base_arc     = 130,
    regions      = DEFAULT_REGIONS,
    notes        = 'Medium hang, more drift than Coin. The in-between teacher.',
  },
  {
    id           = 'pancakes',
    name         = 'Pancakes',
    tier         = 'high',
    color        = { 0.85, 0.30, 0.28 },
    center_power = 160,
    edge_power   = 380,
    center_arc   = 260,
    edge_arc     = 120,
    flight_time  = 0.95,
    base_power   = 260,
    base_arc     = 200,
    regions      = DEFAULT_REGIONS,
    notes        = 'Slow lift, long floaty hang, tight sweet spot. High reward, hard to place.',
  },
}

function Data.byId(id)
  for i = 1, #Data.items do
    if Data.items[i].id == id then return Data.items[i] end
  end
  return nil
end

return Data

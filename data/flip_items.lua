-- data/flip_items.lua
-- Per-item flight tuning. Implements the table in docs/FLIP_PHYSICS_SPEC.md.
-- Color tier follows the GDD's "color = value = difficulty" rule.
--
-- Each item is a closed-form-arc tuning record. Fields:
--   base_power   : launch power in board units (1.0 ~= reaches board center)
--   power_sens   : how much offset_y pushes the shot long/short
--   angle_sens   : how much offset_x rotates the shot, in radians
--   base_arc     : visible hang height (in board units)
--   arc_var      : extra arc per unit of off-center tap
--   flight_time  : seconds of flight animation
--   falloff      : sensitivity falloff exponent (shape of off-center curve)
--   tier / color : tier identity (see GDD)
--   notes        : human-readable feel summary

local Data = {}

Data.items = {
  {
    id          = 'coin',
    name        = 'Coin',
    tier        = 'low',
    color       = { 0.45, 0.78, 0.32 },     -- green
    base_power  = 1.00,
    power_sens  = 0.15,
    angle_sens  = 0.20,
    base_arc    = 0.30,
    arc_var     = 0.10,
    flight_time = 0.45,
    falloff     = 0.8,
    notes       = 'Fast pop, short hang, very learnable. The honest starter.',
  },
  {
    id          = 'lucky_coin',
    name        = 'Lucky Coin',
    tier        = 'low+',
    color       = { 0.30, 0.55, 0.85 },     -- blue
    base_power  = 1.00,
    power_sens  = 0.15,
    angle_sens  = 0.20,
    base_arc    = 0.30,
    arc_var     = 0.10,
    flight_time = 0.45,
    falloff     = 0.8,
    notes       = 'Same flight as Coin; its edge is a bonus effect, not harder physics.',
  },
  {
    id          = 'toast',
    name        = 'Toast',
    tier        = 'mid',
    color       = { 0.92, 0.78, 0.25 },     -- yellow
    base_power  = 1.05,
    power_sens  = 0.25,
    angle_sens  = 0.30,
    base_arc    = 0.45,
    arc_var     = 0.20,
    flight_time = 0.65,
    falloff     = 1.0,
    notes       = 'Medium hang, more drift than Coin. The in-between teacher.',
  },
  {
    id          = 'pancakes',
    name        = 'Pancakes',
    tier        = 'high',
    color       = { 0.85, 0.30, 0.28 },     -- red
    base_power  = 1.10,
    power_sens  = 0.40,
    angle_sens  = 0.45,
    base_arc    = 0.70,
    arc_var     = 0.35,
    flight_time = 0.95,
    falloff     = 1.4,
    notes       = 'Slow lift, long floaty hang, tight sweet spot. High reward, hard to place.',
  },
}

-- Convenience lookup by id. Returns nil if unknown.
function Data.byId(id)
  for i = 1, #Data.items do
    if Data.items[i].id == id then return Data.items[i] end
  end
  return nil
end

return Data

-- data/flip_items.lua
-- Per-item flight tuning. PIXEL-BASED model -- launch power, sensitivities,
-- and arc height are all measured in pixels (closed-form parametric arc per
-- docs/FLIP_PHYSICS_SPEC.md, simplified per the FIX prompt's calibration).
--
-- Fields:
--   base_power        : launch distance in pixels (center tap travels this far)
--   power_sensitivity : how much offset_y shifts launch power (pixels)
--   angle_sensitivity : how much offset_x rotates the shot (radians)
--   base_arc          : visible arc lift at flight midpoint (pixels)
--   arc_variance      : extra arc added at full edge-tap (pixels)
--   flight_time       : seconds of flight animation
--   falloff           : reserved for future use; spec lists it but the current
--                       launch math does not apply it (do not change yet).

local Data = {}

Data.items = {
  {
    id                = 'coin',
    name              = 'Coin',
    tier              = 'low',
    color             = { 0.45, 0.78, 0.32 },     -- green
    base_power        = 220,
    power_sensitivity = 40,
    angle_sensitivity = 0.35,
    base_arc          = 80,
    arc_variance      = 30,
    flight_time       = 0.45,
    falloff           = 0.8,
    notes             = 'Fast pop, short hang, very learnable. The honest starter.',
  },
  {
    id                = 'lucky_coin',
    name              = 'Lucky Coin',
    tier              = 'low+',
    color             = { 0.30, 0.55, 0.85 },     -- blue
    base_power        = 220,
    power_sensitivity = 40,
    angle_sensitivity = 0.35,
    base_arc          = 80,
    arc_variance      = 30,
    flight_time       = 0.45,
    falloff           = 0.8,
    notes             = 'Same flight as Coin; its edge is a bonus effect, not harder physics.',
  },
  {
    id                = 'toast',
    name              = 'Toast',
    tier              = 'mid',
    color             = { 0.92, 0.78, 0.25 },     -- yellow
    base_power        = 240,
    power_sensitivity = 80,
    angle_sensitivity = 0.50,
    base_arc          = 130,
    arc_variance      = 60,
    flight_time       = 0.65,
    falloff           = 1.0,
    notes             = 'Medium hang, more drift than Coin. The in-between teacher.',
  },
  {
    id                = 'pancakes',
    name              = 'Pancakes',
    tier              = 'high',
    color             = { 0.85, 0.30, 0.28 },     -- red
    base_power        = 260,
    power_sensitivity = 130,
    angle_sensitivity = 0.65,
    base_arc          = 200,
    arc_variance      = 100,
    flight_time       = 0.95,
    falloff           = 1.4,
    notes             = 'Slow lift, long floaty hang, tight sweet spot. High reward, hard to place.',
  },
}

function Data.byId(id)
  for i = 1, #Data.items do
    if Data.items[i].id == id then return Data.items[i] end
  end
  return nil
end

return Data

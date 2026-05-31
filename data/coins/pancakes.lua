-- data/coins/pancakes.lua
-- Slow lift, long floaty hang, tight sweet spot. High reward, hard to place.

local R = require("data.coins.regions")

return {
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
  regions            = R.DEFAULT,
  notes              = 'Slow lift, long floaty hang, tight sweet spot. High reward, hard to place.',
}

-- data/coins/skull.lua
-- Small, hair-trigger, fast. The hard skull.

local R = require("data.coins.regions")

return {
  id                 = 'skull',
  name               = 'Skull',
  tier               = 'high',
  color              = { 0.85, 0.20, 0.20 },
  zone_threshold     = 0.15,
  inner_power_center = 110,   inner_power_edge = 110,
  inner_arc_center   = 170,   inner_arc_edge   = 170,
  outer_power_center = 110,   outer_power_edge = 430,
  outer_arc_center   = 170,   outer_arc_edge   = 8,
  flight_time        = 0.34,
  regions            = R.DEFAULT,
  notes              = 'Small, hair-trigger, fast. The hard skull.',
}

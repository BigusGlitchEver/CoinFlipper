-- data/coins/egg.lua
-- Medium coin. Balanced control, the standard egg. Eggs are the only coin type
-- that splits into extra coins when hit by a chain reaction (see flip.lua).

local R = require("data.coins.regions")

return {
  id                 = 'egg',
  name               = 'Egg',
  tier               = 'mid',
  color              = { 0.95, 0.90, 0.78 },
  zone_threshold     = 0.65,
  inner_power_center = 85,    inner_power_edge = 140,
  inner_arc_center   = 230,   inner_arc_edge   = 170,
  outer_power_center = 190,   outer_power_edge = 350,
  outer_arc_center   = 80,    outer_arc_edge   = 30,
  flight_time        = 0.48,
  regions            = R.DEFAULT,
  notes              = 'Medium coin. Balanced control, the standard egg.',
}

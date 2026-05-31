-- data/coins/hard_coin.lua
-- Same size as Coin; hair-trigger outer zone, fast flight.

local R = require("data.coins.regions")

return {
  id                 = 'hard_coin',
  name               = 'Hard Coin',
  tier               = 'high',
  color              = { 0.80, 0.20, 0.20 },
  zone_threshold     = 0.15,
  inner_power_center = 100,   inner_power_edge = 100,
  inner_arc_center   = 180,   inner_arc_edge   = 180,
  outer_power_center = 100,   outer_power_edge = 420,
  outer_arc_center   = 180,   outer_arc_edge   = 8,
  flight_time        = 0.35,
  regions            = R.DEFAULT,
  notes              = 'Same size as Coin; hair-trigger outer zone, fast flight.',
}

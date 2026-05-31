-- data/coins/easy_coin.lua
-- Large dead zone; forgiving. Edge identical to Coin edge.

local R = require("data.coins.regions")

return {
  id                 = 'easy_coin',
  name               = 'Easy Coin',
  tier               = 'easy',
  color              = { 0.45, 0.78, 0.32 },
  zone_threshold     = 0.40,
  inner_power_center = 80,    inner_power_edge = 80,
  inner_arc_center   = 220,   inner_arc_edge   = 220,
  outer_power_center = 80,    outer_power_edge = 340,
  outer_arc_center   = 220,   outer_arc_edge   = 25,
  flight_time        = 0.45,
  regions            = R.EASY,
  notes              = 'Large dead zone; forgiving. Edge identical to Coin edge.',
}

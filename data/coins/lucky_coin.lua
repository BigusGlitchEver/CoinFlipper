-- data/coins/lucky_coin.lua
-- Same flight as Coin; its edge is a bonus effect, not harder physics.

local R = require("data.coins.regions")

return {
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
  regions            = R.DEFAULT,
  notes              = 'Same flight as Coin; its edge is a bonus effect, not harder physics.',
}

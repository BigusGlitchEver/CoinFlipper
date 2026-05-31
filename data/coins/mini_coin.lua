-- data/coins/mini_coin.lua
-- Tiny coin, huge dead zone, gentle ramp. Most forgiving.

local R = require("data.coins.regions")

return {
  id                 = 'mini_coin',
  name               = 'Mini Coin',
  tier               = 'easy',
  color              = { 0.30, 0.88, 0.60 },
  zone_threshold     = 0.55,
  inner_power_center = 80,    inner_power_edge = 80,
  inner_arc_center   = 220,   inner_arc_edge   = 220,
  outer_power_center = 80,    outer_power_edge = 280,
  outer_arc_center   = 220,   outer_arc_edge   = 60,
  flight_time        = 0.55,
  regions            = R.MINI,
  notes              = 'Tiny coin, huge dead zone, gentle ramp. Most forgiving.',
}

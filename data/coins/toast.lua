-- data/coins/toast.lua
-- Large easy slice. Big dead zone, slow floaty flight.

local R = require("data.coins.regions")

return {
  id                 = 'toast',
  name               = 'Toast',
  tier               = 'easy',
  color              = { 0.92, 0.78, 0.25 },
  zone_threshold     = 0.40,
  inner_power_center = 90,    inner_power_edge = 90,
  inner_arc_center   = 260,   inner_arc_edge   = 260,
  outer_power_center = 90,    outer_power_edge = 320,
  outer_arc_center   = 260,   outer_arc_edge   = 70,
  flight_time        = 0.62,
  regions            = R.EASY,
  notes              = 'Large easy slice. Big dead zone, slow floaty flight.',
}

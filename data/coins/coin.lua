-- data/coins/coin.lua
-- The standard Coin. This file is the reference for the coin-definition schema:
--
--   id / name / tier   : identity + difficulty tag
--   color              : tint used by some UI
--   zone_threshold     : split between INNER (pop) and OUTER (launch) press
--                        zones, in normalized contact distance (0=center,1=edge)
--   inner_* / outer_*  : power (pixel distance) and arc (pixel height) curves
--   flight_time        : seconds of flight animation
--   regions            : collision/direction grid (see data/coins/regions.lua)
--   power_scale        : OPTIONAL multiplier on launch distance (default 1).
--                        Applied by Flip.shotFor so the aimer AND the real
--                        flight always agree. Edit this to make a coin reach
--                        farther/shorter from one place.
--   score_mult         : OPTIONAL scoring multiplier applied at creation
--                        (default 1).

local R = require("data.coins.regions")

return {
  id                 = 'coin',
  name               = 'Coin',
  tier               = 'low',
  color              = { 0.45, 0.78, 0.32 },
  zone_threshold     = 0.65,
  inner_power_center = 80,    inner_power_edge = 130,
  inner_arc_center   = 220,   inner_arc_edge   = 160,
  outer_power_center = 180,   outer_power_edge = 340,
  outer_arc_center   = 70,    outer_arc_edge   = 25,
  flight_time        = 0.45,
  regions            = R.DEFAULT,
}

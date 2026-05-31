-- data/coins/gold_coin.lua
-- The rare GOLD coin. Spawned by egg splits and by the Special Marble Event.
-- It flies like a normal Coin but is deliberately reined in:
--
--   power_scale = 0.5  -> travels HALF as far as a normal coin. Because
--                         Flip.shotFor applies this single value, BOTH the red
--                         aimer preview and the actual launch use it, so they
--                         always match. Edit this one number to retune reach.
--   score_mult  = 5    -> worth 5x on a scoring hit (set on the coin at spawn).
--   golden      = true -> drawn as a distinct gold disc (entities/coin.lua).
--
-- Everything else mirrors data/coins/coin.lua.

local R = require("data.coins.regions")

return {
  id                 = 'gold_coin',
  name               = 'Gold Coin',
  tier               = 'low',
  color              = { 1.00, 0.83, 0.12 },
  golden             = true,
  power_scale        = 0.5,
  score_mult         = 5,
  zone_threshold     = 0.65,
  inner_power_center = 80,    inner_power_edge = 130,
  inner_arc_center   = 220,   inner_arc_edge   = 160,
  outer_power_center = 180,   outer_power_edge = 340,
  outer_arc_center   = 70,    outer_arc_edge   = 25,
  flight_time        = 0.45,
  regions            = R.DEFAULT,
}

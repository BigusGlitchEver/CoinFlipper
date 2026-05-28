-- data/coin_tiers.lua
-- 4-tier coin degradation. A freshly scattered coin is tier 0 (yellow, full
-- value). Every non-scoring flip bumps the tier (capped at 3). Each tier
-- applies a point multiplier to scoring hits; coin outline stays #333333.
--
-- Single source of truth: entities/coin.lua reads .color in draw,
-- states/game.lua reads .mult in resolveFlip.

local EASY_COIN_RADIUS_SCALE = 0.82  -- easy coins are 82% of standard radius
local MINI_COIN_RADIUS_SCALE = 0.65  -- mini coins are 65% of standard radius

local Tiers = {
  { color = { 0xF0/255, 0xC0/255, 0x40/255 }, mult = 1.00 },  -- 0 yellow (fresh)
  { color = { 0x44/255, 0x88/255, 0xFF/255 }, mult = 0.75 },  -- 1 blue
  { color = { 0xAA/255, 0x44/255, 0xFF/255 }, mult = 0.50 },  -- 2 purple
  { color = { 0xFF/255, 0x44/255, 0x44/255 }, mult = 0.25 },  -- 3 red
}

Tiers.EASY_COIN_RADIUS_SCALE = EASY_COIN_RADIUS_SCALE
Tiers.MINI_COIN_RADIUS_SCALE = MINI_COIN_RADIUS_SCALE

return Tiers

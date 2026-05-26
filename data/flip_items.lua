-- data/flip_items.lua
-- Prototype flip items per GDD: Coin, Lucky Coin, Toast, Pancakes.
-- zoneWeights: relative chance of landing in each ring (outer -> inner).
--   Higher weight = more likely to land there.
-- Higher-value items have flatter weighting (harder to control).

local Data = {}

Data.items = {
    {
        id          = 'coin',
        name        = 'Coin',
        zoneWeights = { 4, 3, 2, 1 }, -- outer ring most likely
        notes       = 'Standard flip item',
    },
    {
        id          = 'lucky_coin',
        name        = 'Lucky Coin',
        zoneWeights = { 2, 3, 3, 2 }, -- nudged toward middle rings
        notes       = 'Better zone weighting',
    },
    {
        id          = 'toast',
        name        = 'Toast',
        zoneWeights = { 3, 3, 2, 2 },
        notes       = 'Mid-tier item',
    },
    {
        id          = 'pancakes',
        name        = 'Pancakes',
        zoneWeights = { 5, 3, 2, 1 }, -- harder to land, but big payout
        valueMultiplier = 2,
        notes       = 'Bigger, harder to land, higher value',
    },
}

return Data

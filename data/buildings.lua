-- data/buildings.lua
-- Prototype buildings per GDD: 3 houses in the cul-de-sac.
-- These are the 3 conquerable houses, each tied to a boss.
-- baseIncome  = Marbles per second when conquered (tier 0)
-- upgradeCost = global Marbles for the first upgrade; doubles per tier
-- upgradeMultiplier = applied to baseIncome per tier (so tier 1 = 2x base)
-- passiveBonus = flavor bonus from the GDD (TBD numbers)

local Data = {}

Data.buildings = {
    {
        id           = 'grandma',
        name         = "Grandma's House",
        boss         = 'Grandma',
        baseIncome   = 1,
        upgradeCost  = 100,
        upgradeMultiplier = 2,
        maxTier      = 1,
        passiveBonus = { kind = 'shop_discount', amount = 0.10 }, -- placeholder %
    },
    {
        id           = 'cat',
        name         = "The Cat's House",
        boss         = 'The Cat',
        baseIncome   = 3,
        upgradeCost  = 300,
        upgradeMultiplier = 2,
        maxTier      = 1,
        passiveBonus = { kind = 'cat_bonus', amount = 0 }, -- TBD per GDD
    },
    {
        id           = 'gymbro',
        name         = "Gym Bro's House",
        boss         = 'Gym Bro',
        baseIncome   = 8,
        upgradeCost  = 800,
        upgradeMultiplier = 2,
        maxTier      = 1,
        passiveBonus = { kind = 'flip_power', amount = 0 }, -- TBD per GDD
    },
}

return Data

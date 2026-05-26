-- data/cards.lua
-- Bicycle cards (modifier system) per GDD.
-- Prototype target: 3-4 cards with distinct effects.
-- Exact effects are an open GDD item; this is a placeholder stub
-- showing the intended shape so the card system can be built around it.
--
-- Effect categories from GDD:
--   * scoring_multiplier   (e.g. 2x a flip, double every third flip)
--   * zone_manipulation    (zones bigger, worth more, bonus zone appears)
--   * flip_behavior        (bounces off walls, stays airborne longer)
--   * chain_bonus          (extend multiplier chain)
--   * economy              (drop bonus Marbles regardless of zone)
--   * safety               (one free reflip per floor, minimum guarantee)
--   * curse                (zones shrink BUT multiplier triples)
--   * passive              (does nothing floors 1-2, cashes out on floor 3)

local Data = {}

Data.cards = {
    -- TODO: replace these with real designed cards before card system build
    {
        id       = 'double_down',
        name     = 'Double Down',
        category = 'scoring_multiplier',
        cost     = 50,
        rarity   = 'common',
        text     = 'The next flip is worth 2x Marbles.',
    },
    {
        id       = 'wide_load',
        name     = 'Wide Load',
        category = 'zone_manipulation',
        cost     = 75,
        rarity   = 'common',
        text     = 'All zones are 20% larger this floor.',
    },
    {
        id       = 'safety_net',
        name     = 'Safety Net',
        category = 'safety',
        cost     = 100,
        rarity   = 'uncommon',
        text     = 'Get one free reflip on this floor.',
    },
    {
        id       = 'cursed_marble',
        name     = 'Cursed Marble',
        category = 'curse',
        cost     = 50,
        rarity   = 'rare',
        text     = 'Zones shrink, but your multiplier triples.',
    },
}

return Data

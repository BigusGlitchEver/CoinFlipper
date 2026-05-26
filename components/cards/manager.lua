-- components/cards/manager.lua
-- Bicycle card system: holds the player's active cards for a run
-- and exposes simple effect hooks for the flip board and shop.
-- Effects are dispatched by category (see data/cards.lua).

local Data = require('data.cards')

local CardManager = {}
CardManager.__index = CardManager

function CardManager.new()
    return setmetatable({
        owned  = {},     -- list of card ids owned across the run
        active = {},     -- cards currently in play this floor
    }, CardManager)
end

local function findCard(id)
    for _, c in ipairs(Data.cards) do
        if c.id == id then return c end
    end
    return nil
end

function CardManager:add(cardId)
    local c = findCard(cardId)
    if c then table.insert(self.owned, c) end
end

function CardManager:remove(cardId)
    for i, c in ipairs(self.owned) do
        if c.id == cardId then table.remove(self.owned, i); return end
    end
end

function CardManager:owns(cardId)
    for _, c in ipairs(self.owned) do
        if c.id == cardId then return true end
    end
    return false
end

-- Snapshot of cards by category — used by the board to apply effects.
function CardManager:byCategory(category)
    local out = {}
    for _, c in ipairs(self.owned) do
        if c.category == category then table.insert(out, c) end
    end
    return out
end

function CardManager:reset()
    self.owned  = {}
    self.active = {}
end

return CardManager

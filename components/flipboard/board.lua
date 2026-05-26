-- components/flipboard/board.lua
-- The flip board: a flat 2D surface divided into concentric ring zones.
-- Per GDD: hand reaches in from screen edge, taps item, item pops + flips,
-- lands in a zone, score = zone value * active modifiers * multiplier chain.
--
-- This is the prototype skeleton. Drawing/animation will be filled in
-- once hand-drawn assets exist.

local Probability = require('helpers.probability')

local Board = {}
Board.__index = Board

-- floor: 1, 2, or 3 (per GDD difficulty curve, zones shrink each floor)
-- zoneValues: Marble value of each ring, outer -> inner
function Board.new(floor, zoneValues)
    return setmetatable({
        floor          = floor or 1,
        zoneValues     = zoneValues or { 1, 3, 10, 50 },
        multiplier     = 1,
        chain          = 0,
        marblesEarned  = 0,
    }, Board)
end

-- Performs one flip. item must expose zoneWeights and (optional) valueMultiplier.
-- Returns: zoneIndex, baseValue, totalValue
function Board:flip(item)
    local weights = self:_adjustedWeights(item.zoneWeights)
    local zone = Probability.weightedPick(weights)
    local baseValue = self.zoneValues[zone] or 0
    local mult = item.valueMultiplier or 1
    -- Good flip = landed in an inner zone (2..top). Outer ring resets chain.
    if zone > 1 then
        self.chain = self.chain + 1
        self.multiplier = 1 + self.chain * 0.5
    else
        self.chain = 0
        self.multiplier = 1
    end
    local total = math.floor(baseValue * mult * self.multiplier)
    self.marblesEarned = self.marblesEarned + total
    return zone, baseValue, total
end

-- Zones shrink per floor by tilting weight toward outer ring.
function Board:_adjustedWeights(weights)
    local shrink = (self.floor - 1) * 0.5
    local adjusted = {}
    for i, w in ipairs(weights) do
        if i == 1 then
            adjusted[i] = w + shrink * (#weights - 1)
        else
            adjusted[i] = math.max(0.1, w - shrink)
        end
    end
    return adjusted
end

function Board:reset()
    self.multiplier    = 1
    self.chain         = 0
    self.marblesEarned = 0
end

return Board

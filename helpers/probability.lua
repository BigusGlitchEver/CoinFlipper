-- helpers/probability.lua
-- Probability utilities for flip outcomes and zone landing.

local Probability = {}

-- Picks an index from a weighted list. weights = { 5, 3, 1 } -> returns 1, 2, or 3.
-- Higher weight = more likely.
function Probability.weightedPick(weights)
    local total = 0
    for _, w in ipairs(weights) do total = total + w end
    if total <= 0 then return 1 end
    local roll = love.math.random() * total
    local acc = 0
    for i, w in ipairs(weights) do
        acc = acc + w
        if roll <= acc then return i end
    end
    return #weights
end

-- Simple 50/50 flip. Returns 'heads' or 'tails'.
function Probability.flipCoin()
    return love.math.random() < 0.5 and 'heads' or 'tails'
end

-- Lerp two numbers. Handy for interpolating zone weights as floors progress.
function Probability.lerp(a, b, t)
    return a + (b - a) * t
end

return Probability

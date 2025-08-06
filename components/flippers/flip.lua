local Probability = require('helpers.probability')
local Player = require('components.player.player')
local StatsTracker = require('components.player.stats_tracker')

local Flip = {}

function Flip.flipCoin(bet, guess, winRate)
    -- winRate: probability of winning (e.g., 0.5 for 50%)
    if bet < 1 then
        return {error = 'Invalid bet amount.'}
    end
    local win = love.math.random() < (winRate or 0.5)
    local result = win and guess or (guess == 'heads' and 'tails' or 'heads')
    
    -- Track the coin flip result
    StatsTracker.addCoinFlip(win)
    
    return {result = result, win = win}
end

return Flip

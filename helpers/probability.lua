local Probability = {}
local StatsTracker = require('components.player.stats_tracker')

function Probability.flipCoin()
    local result
    if love.math.random() < 0.5 then
        result = 'heads'
    else
        result = 'tails'
    end
    
    -- Track the coin flip result (assuming heads is a win for tracking purposes)
    -- You can modify this logic based on how your game determines wins
    local isWin = (result == 'heads')  -- or whatever your win condition is
    StatsTracker.addCoinFlip(isWin)
    
    return result
end

function Probability.getPayout(result, bet)
    -- 1:1 payout for correct guess
    return bet
end

return Probability

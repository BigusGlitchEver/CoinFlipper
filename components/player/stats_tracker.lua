-- Player Stats Tracker
-- Tracks various player statistics including coin flip wins

local StatsTracker = {}

-- Initialize stats if not already done
StatsTracker.stats = StatsTracker.stats or {
    coinFlipWins = 0,
    coinFlipTotal = 0,
    totalCoinsEarned = 1000000,  -- Start with 1M since player starts with 1M points
    itemsOwned = 0,
    itemsEquipped = 0,
    maxPointsEver = 1000000  -- Start with 1M since player starts with 1M points
}

-- Track a coin flip win
function StatsTracker.addCoinFlipWin()
    StatsTracker.stats.coinFlipWins = StatsTracker.stats.coinFlipWins + 1
    StatsTracker.stats.coinFlipTotal = StatsTracker.stats.coinFlipTotal + 1
end

-- Track a coin flip loss
function StatsTracker.addCoinFlipLoss()
    StatsTracker.stats.coinFlipTotal = StatsTracker.stats.coinFlipTotal + 1
end

-- Track a coin flip (win or loss)
function StatsTracker.addCoinFlip(isWin)
    if isWin then
        StatsTracker.addCoinFlipWin()
    else
        StatsTracker.addCoinFlipLoss()
    end
end

-- Get coin flip wins
function StatsTracker.getCoinFlipWins()
    return StatsTracker.stats.coinFlipWins
end

-- Get total coin flips
function StatsTracker.getCoinFlipTotal()
    return StatsTracker.stats.coinFlipTotal
end

-- Get win rate
function StatsTracker.getWinRate()
    if StatsTracker.stats.coinFlipTotal == 0 then
        return 0
    end
    return StatsTracker.stats.coinFlipWins / StatsTracker.stats.coinFlipTotal
end

-- Track coins earned
function StatsTracker.addCoinsEarned(amount)
    StatsTracker.stats.totalCoinsEarned = StatsTracker.stats.totalCoinsEarned + amount
end

-- Get total coins earned
function StatsTracker.getTotalCoinsEarned()
    return StatsTracker.stats.totalCoinsEarned
end

-- Track item ownership changes
function StatsTracker.onItemPurchased()
    StatsTracker.stats.itemsOwned = StatsTracker.stats.itemsOwned + 1
end

function StatsTracker.onItemEquipped()
    StatsTracker.stats.itemsEquipped = StatsTracker.stats.itemsEquipped + 1
end

function StatsTracker.onItemUnequipped()
    StatsTracker.stats.itemsEquipped = StatsTracker.stats.itemsEquipped - 1
end

-- Get all stats
function StatsTracker.getAllStats()
    return StatsTracker.stats
end

-- Track maximum points ever reached
function StatsTracker.updateMaxPoints(currentPoints)
    if currentPoints > StatsTracker.stats.maxPointsEver then
        StatsTracker.stats.maxPointsEver = currentPoints
    end
end

-- Check if player has ever had a certain amount of points
function StatsTracker.hasEverHadPoints(points)
    return StatsTracker.stats.maxPointsEver >= points
end

-- Reset all stats (for testing)
function StatsTracker.resetStats()
    StatsTracker.stats = {
        coinFlipWins = 0,
        coinFlipTotal = 0,
        totalCoinsEarned = 0,
        itemsOwned = 0,
        itemsEquipped = 0,
        maxPointsEver = 0
    }
end

return StatsTracker 
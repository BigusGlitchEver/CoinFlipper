local Player = {}

Player.points = 1000000 -- Starting points (increased for testing)

-- Equipment system
Player.equipped = {
    hat = nil,
    pants = nil,
    socks = nil,
    gloves = nil,
    ring = nil,
    glasses = nil,
    accessory = nil
}

-- Stats (calculated from equipped items)
Player.stats = {
    luck = 0,
    speed = 0,
    coin_attraction = 0,
    flip_bonus = 0
}

-- Existing points functions
function Player.getPoints()
    return Player.points
end

function Player.addPoints(amount)
    Player.points = Player.points + amount
    -- Update max points tracker
    local StatsTracker = require('components.player.stats_tracker')
    StatsTracker.updateMaxPoints(Player.points)
    -- Track total coins earned (only positive amounts)
    if amount > 0 then
        StatsTracker.addCoinsEarned(amount)
    end
end

function Player.subtractPoints(amount)
    Player.points = Player.points - amount
end

function Player.formatPoints(n)
    if n >= 1e12 then return string.format("%.2fT", n / 1e12) end
    if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
    if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
    if n >= 1e3 then return string.format("%.0fK", n / 1e3) end
    return tostring(math.floor(n))
end

-- New equipment functions
function Player.equipItem(slot, item)
    Player.equipped[slot] = item
    Player.recalculateStats()
end

function Player.getEquipped(slot)
    return Player.equipped[slot]
end

function Player.recalculateStats()
    -- Reset stats
    Player.stats.luck = 0
    Player.stats.speed = 0
    Player.stats.coin_attraction = 0
    Player.stats.flip_bonus = 0
    -- Add bonuses from all equipped items
    for slot, item in pairs(Player.equipped) do
        if item and item.stats then
            for stat, bonus in pairs(item.stats) do
                Player.stats[stat] = (Player.stats[stat] or 0) + bonus
            end
        end
    end
end

return Player

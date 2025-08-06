local PlayerManager = {}

local points = 100
local bet = 1

function PlayerManager.getPoints()
    return points
end

function PlayerManager.addPoints(amount)
    points = points + amount
end

function PlayerManager.subtractPoints(amount)
    points = math.max(0, points - amount)
end

function PlayerManager.setPoints(amount)
    points = math.max(0, amount)
end

function PlayerManager.getBet()
    return bet
end

function PlayerManager.setBet(amount)
    bet = math.max(1, math.floor(amount))
end

return PlayerManager

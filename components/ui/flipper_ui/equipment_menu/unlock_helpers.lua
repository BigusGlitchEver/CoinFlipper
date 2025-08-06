-- Simple unlock helper functions for KISS approach
local UnlockHelpers = {}

-- Coin flip wins unlock
function UnlockHelpers.requireCoinWins(wins)
    local StatsTracker = require('components.player.stats_tracker')
    local result = StatsTracker.getCoinFlipWins() >= wins
    -- Debug output
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.print(string.format("DEBUG: requireCoinWins(%d) = %s (wins=%d)", wins, tostring(result), StatsTracker.getCoinFlipWins()), 400, 200)
    return result
end

-- Points threshold unlock (current points)
function UnlockHelpers.requirePoints(points)
    local Player = require('components.player.player')
    local result = Player.getPoints() >= points
    -- Debug output
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.print(string.format("DEBUG: requirePoints(%d) = %s (points=%d)", points, tostring(result), Player.getPoints()), 400, 220)
    return result
end

-- Current points unlock (what you have right now)
function UnlockHelpers.requireCurrentPoints(points)
    local Player = require('components.player.player')
    local result = Player.getPoints() >= points
    -- Debug output
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.print(string.format("DEBUG: requireCurrentPoints(%d) = %s (points=%d)", points, tostring(result), Player.getPoints()), 400, 260)
    return result
end

-- Total points earned unlock (lifetime earnings)
function UnlockHelpers.requireTotalEarned(points)
    local StatsTracker = require('components.player.stats_tracker')
    local result = StatsTracker.getTotalCoinsEarned() >= points
    -- Debug output
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.print(string.format("DEBUG: requireTotalEarned(%d) = %s (earned=%d)", points, tostring(result), StatsTracker.getTotalCoinsEarned()), 400, 280)
    return result
end

-- Crew member unlock
function UnlockHelpers.requireCrewMember(crewType)
    local crew = require('components.crew.crew')
    local owned = crew.types[crewType].owned
    local result = owned > 0
    -- Debug output
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.print(string.format("DEBUG: requireCrewMember('%s') = %s (owned=%d)", crewType, tostring(result), owned), 400, 300)
    return result
end

-- Building unlock
function UnlockHelpers.requireAnyBuilding()
    local BuildingManager = require('components.buildings.manager')
    local buildings = BuildingManager.getBuildings()
    local totalBuildings = 0
    for _, building in ipairs(buildings) do
        totalBuildings = totalBuildings + building.owned
    end
    local result = totalBuildings > 0
    -- Debug output
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.print(string.format("DEBUG: requireAnyBuilding() = %s (total=%d)", tostring(result), totalBuildings), 400, 320)
    return result
end

-- Specific building unlock
function UnlockHelpers.requireBuilding(buildingName)
    local BuildingManager = require('components.buildings.manager')
    local buildings = BuildingManager.getBuildings()
    for _, building in ipairs(buildings) do
        if building.name == buildingName and building.owned > 0 then
            return true
        end
    end
    return false
end

-- Item ownership unlock
function UnlockHelpers.requireItem(itemId)
    local Inventory = require('components.player.inventory')
    return Inventory.hasItem(itemId)
end

return UnlockHelpers 
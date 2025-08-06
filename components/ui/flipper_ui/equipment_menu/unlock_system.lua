-- Unlock System for Equipment Items
-- Supports multiple condition types for unlocking equipment

local Player = require('components.player.player')
local Items = require('data.items')
local StatsTracker = require('components.player.stats_tracker')
local Inventory = require('components.player.inventory')

local UnlockSystem = {}

-- Condition type definitions
local CONDITION_TYPES = {
    MONEY = 'money',
    FRIEND_COUNT = 'friend_count',
    BUILDING_COUNT = 'building_count',
    ITEM_OWNERSHIP = 'item_ownership',
    ACHIEVEMENT = 'achievement',
    COMBINATION = 'combination',
    COIN_FLIP_WINS = 'coin_flip_wins'
}

-- Condition checking functions
local function checkMoneyCondition(condition)
    return Player.getPoints() >= condition.amount
end

local function checkFriendCountCondition(condition)
    -- TODO: Implement when friend system is available
    return false
end

local function checkBuildingCountCondition(condition)
    -- TODO: Implement when building system is available
    return false
end

local function checkItemOwnershipCondition(condition)
    -- Check if the player owns the specified item
    for _, item in ipairs(Items) do
        if item.name == condition.itemName and Inventory.hasItem(item.id) then
            return true
        end
    end
    return false
end

local function checkAchievementCondition(condition)
    -- TODO: Implement when achievement system is available
    return false
end

local function checkCoinFlipWinsCondition(condition)
    return StatsTracker.getCoinFlipWins() >= condition.wins
end

local function checkCombinationCondition(condition)
    for _, subCondition in ipairs(condition.conditions) do
        if not UnlockSystem.checkCondition(subCondition) then
            return false
        end
    end
    return true
end

-- Condition checker mapping
local conditionCheckers = {
    [CONDITION_TYPES.MONEY] = checkMoneyCondition,
    [CONDITION_TYPES.FRIEND_COUNT] = checkFriendCountCondition,
    [CONDITION_TYPES.BUILDING_COUNT] = checkBuildingCountCondition,
    [CONDITION_TYPES.ITEM_OWNERSHIP] = checkItemOwnershipCondition,
    [CONDITION_TYPES.ACHIEVEMENT] = checkAchievementCondition,
    [CONDITION_TYPES.COMBINATION] = checkCombinationCondition,
    [CONDITION_TYPES.COIN_FLIP_WINS] = checkCoinFlipWinsCondition
}

-- Main condition checking function
function UnlockSystem.checkCondition(condition)
    local checker = conditionCheckers[condition.type]
    if checker then
        return checker(condition)
    end
    return false
end

-- Check if an item is unlocked based on its unlock conditions
function UnlockSystem.isItemUnlocked(item)
    if not item.unlockConditions then
        return true -- No conditions means always unlocked
    end
    
    for _, condition in ipairs(item.unlockConditions) do
        if not UnlockSystem.checkCondition(condition) then
            return false
        end
    end
    
    return true
end

-- Helper functions for creating conditions
function UnlockSystem.createMoneyCondition(amount)
    return {
        type = CONDITION_TYPES.MONEY,
        amount = amount
    }
end

function UnlockSystem.createFriendCountCondition(count)
    return {
        type = CONDITION_TYPES.FRIEND_COUNT,
        count = count
    }
end

function UnlockSystem.createBuildingCountCondition(count)
    return {
        type = CONDITION_TYPES.BUILDING_COUNT,
        count = count
    }
end

function UnlockSystem.createItemOwnershipCondition(itemName)
    return {
        type = CONDITION_TYPES.ITEM_OWNERSHIP,
        itemName = itemName
    }
end

function UnlockSystem.createAchievementCondition(achievementId)
    return {
        type = CONDITION_TYPES.ACHIEVEMENT,
        achievementId = achievementId
    }
end

function UnlockSystem.createCoinFlipWinsCondition(wins)
    return {
        type = CONDITION_TYPES.COIN_FLIP_WINS,
        wins = wins
    }
end

function UnlockSystem.createCombinationCondition(conditions)
    return {
        type = CONDITION_TYPES.COMBINATION,
        conditions = conditions
    }
end

-- Get unlock description for display
function UnlockSystem.getUnlockDescription(item)
    if not item.unlockConditions then
        return "Always available"
    end
    
    local descriptions = {}
    for _, condition in ipairs(item.unlockConditions) do
        local desc = UnlockSystem.getConditionDescription(condition)
        if desc then
            table.insert(descriptions, desc)
        end
    end
    
    if #descriptions == 0 then
        return "Always available"
    elseif #descriptions == 1 then
        return descriptions[1]
    else
        return "Requires: " .. table.concat(descriptions, " AND ")
    end
end

function UnlockSystem.getConditionDescription(condition)
    if condition.type == CONDITION_TYPES.MONEY then
        return string.format("Have %d coins", condition.amount)
    elseif condition.type == CONDITION_TYPES.FRIEND_COUNT then
        return string.format("Have %d friends", condition.count)
    elseif condition.type == CONDITION_TYPES.BUILDING_COUNT then
        return string.format("Own %d buildings", condition.count)
    elseif condition.type == CONDITION_TYPES.ITEM_OWNERSHIP then
        return string.format("Own %s", condition.itemName)
    elseif condition.type == CONDITION_TYPES.ACHIEVEMENT then
        return string.format("Achieve %s", condition.achievementId)
    elseif condition.type == CONDITION_TYPES.COIN_FLIP_WINS then
        return string.format("Win %d coin flip(s)", condition.wins)
    elseif condition.type == CONDITION_TYPES.COMBINATION then
        local subDescriptions = {}
        for _, subCondition in ipairs(condition.conditions) do
            local desc = UnlockSystem.getConditionDescription(subCondition)
            if desc then
                table.insert(subDescriptions, desc)
            end
        end
        return "(" .. table.concat(subDescriptions, " AND ") .. ")"
    end
    
    return nil
end

-- Export condition types for external use
UnlockSystem.CONDITION_TYPES = CONDITION_TYPES

return UnlockSystem 
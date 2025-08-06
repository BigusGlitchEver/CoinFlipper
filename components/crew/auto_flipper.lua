local Player = require('components.player.player')
local flipperData = require('components.flippers.data')
local flippers = flipperData.flippers
local nameToKey = flipperData.nameToKey
local BuildingManager = require('components.buildings.manager')
local fallingFlips = require('components.ui.flipper_ui.falling_flips')
local BurstEffects = require('components.ui.flipper_ui.burst_effects')

local crewTimers = {}
local rewardText, rewardTimer
local REWARD_DURATION = 1.0
local crewFlipFlash = 0 -- seconds remaining for visual flash

local M = {}

function M.update(dt, crew)
    -- Crew auto-flip logic (restored)
    for crewKey, c in pairs(crew.types) do
        for i = 1, c.owned do
            crewTimers[crewKey] = crewTimers[crewKey] or {}
            crewTimers[crewKey][i] = crewTimers[crewKey][i] or 0
            crewTimers[crewKey][i] = crewTimers[crewKey][i] - dt
            if crewTimers[crewKey][i] <= 0 then
                local assignedName = c.assignments[i] or 'Coin'
                local flipperKey = nameToKey[assignedName] or 'coin'
                local f = flippers[flipperKey] or flippers.coin
                local totalPoints = 0
                for flipN = 1, c.coinsPerCycle do
                    local isWin = love.math.random() < (f.winRate or 0.5)
                    local mult = math.floor((f.bet or 1) / (f.betIncrement or 1))
                    local delta = isWin and (mult * f.win) or (mult * f.lose)
                    totalPoints = totalPoints + delta
                    if isWin then
                        fallingFlips.spawnFallingFlip(flipperKey, 'win')
                    end
                end
                if totalPoints ~= 0 then
                    Player.addPoints(totalPoints)
                    rewardText = (totalPoints > 0 and '+' or '') .. tostring(totalPoints) .. ' (Crew)'
                    rewardTimer = REWARD_DURATION * 0.7
                    crewFlipFlash = 0.5
                end
                crewTimers[crewKey][i] = c.interval or 2.0
            end
        end
    end
    -- Building auto-flip logic
    local buildings = BuildingManager.getBuildings()
    local capacities = BuildingManager.crewCapacities
    for _, b in ipairs(buildings) do
        if b.assignments and b.owned and b.owned > 0 then
            b.timers = b.timers or {}
            -- Normalize building name to type key (e.g., 'Lucky Penny' -> 'luckyPenny')
            local typeKey = b.name:lower():gsub("%s", "")
            if typeKey == 'luckypenny' then typeKey = 'luckyPenny' end
            if typeKey == 'gamblinghouse' then typeKey = 'gamblingHouse' end
            if typeKey == 'casino' then typeKey = 'casino' end
            if typeKey == 'vegasempire' then typeKey = 'vegasEmpire' end
            local cap = capacities[typeKey] and capacities[typeKey].total or 1
            for i = 1, b.owned do
                b.timers[i] = (b.timers[i] or 0) - dt
                if b.timers[i] <= 0 then
                    local assignedName = b.assignments[i] or 'Coin'
                    local flipperKey = nameToKey[assignedName] or 'coin'
                    local f = flippers[flipperKey] or flippers.coin
                    local bonus = b.bonus or 0
                    local winRate = (f.winRate or 0.5) + bonus
                    local totalPoints = 0
                    local winCount = 0
                    for flipN = 1, cap do
                        local isWin = love.math.random() < winRate
                        local mult = math.floor((f.bet or 1) / (f.betIncrement or 1))
                        local delta = isWin and (mult * f.win) or (mult * f.lose)
                        totalPoints = totalPoints + delta
                        if isWin then winCount = winCount + 1 end
                    end
                    if winCount > 0 then
                        for i = 1, winCount do
                            fallingFlips.spawnFallingFlip(flipperKey, 'win')
                        end
                    end
                    if totalPoints ~= 0 then
                        Player.addPoints(totalPoints)
                        rewardText = (totalPoints > 0 and '+' or '') .. tostring(totalPoints) .. ' (Building)'
                        rewardTimer = REWARD_DURATION * 0.7
                        crewFlipFlash = 0.5
                    end
                    b.timers[i] = 2.0 -- Fixed interval for now
                end
            end
        end
    end
    -- Update reward text timer
    if rewardTimer and rewardTimer > 0 then
        rewardTimer = rewardTimer - dt
        if rewardTimer <= 0 then rewardText = nil end
    end
    -- Update crew flip flash
    if crewFlipFlash > 0 then
        crewFlipFlash = crewFlipFlash - dt
        if crewFlipFlash < 0 then crewFlipFlash = 0 end
    end
end

function M.getRewardText()
    return rewardText, rewardTimer, REWARD_DURATION
end

function M.getCrewFlipFlash()
    return crewFlipFlash
end

return M 
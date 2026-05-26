-- components/buildings/manager.lua
-- Manages conquered buildings and their passive Marble generation.
-- Adapted from old CoinFlipper buildings manager.
-- Per GDD: 3 prototype buildings, each conquered via boss flip,
-- each generates passive Marbles, each has 1 upgrade tier.

local BuildingManager = {}

local Data = require('data.buildings')

-- Runtime building state. Mirrors the static data file but tracks
-- per-building conquest + upgrade progress.
local state = {}

local function initState()
    state = {}
    for i, b in ipairs(Data.buildings) do
        state[i] = {
            id          = b.id,
            name        = b.name,
            conquered   = false,
            upgradeTier = 0,
            -- baseIncome is Marbles per second when conquered
            baseIncome  = b.baseIncome,
            -- upgradeCost = global Marbles required for the next tier
            upgradeCost = b.upgradeCost,
            -- upgradeMultiplier applied to baseIncome per tier
            upgradeMultiplier = b.upgradeMultiplier or 2,
            maxTier = b.maxTier or 1,
        }
    end
end

initState()

-- ---------- Queries ----------

function BuildingManager.all()
    return state
end

function BuildingManager.get(id)
    for _, b in ipairs(state) do
        if b.id == id then return b end
    end
    return nil
end

function BuildingManager.isConquered(id)
    local b = BuildingManager.get(id)
    return b and b.conquered or false
end

-- Marbles per second for a single building (0 if not conquered)
function BuildingManager.incomeOf(id)
    local b = BuildingManager.get(id)
    if not b or not b.conquered then return 0 end
    return b.baseIncome * (b.upgradeMultiplier ^ b.upgradeTier)
end

-- Total Marbles/sec across the empire
function BuildingManager.totalIncome()
    local total = 0
    for _, b in ipairs(state) do
        if b.conquered then
            total = total + b.baseIncome * (b.upgradeMultiplier ^ b.upgradeTier)
        end
    end
    return total
end

-- Are all 3 prototype buildings conquered? (gates district upgrade)
function BuildingManager.allConquered()
    for _, b in ipairs(state) do
        if not b.conquered then return false end
    end
    return true
end

-- ---------- Mutations ----------

function BuildingManager.conquer(id)
    local b = BuildingManager.get(id)
    if b and not b.conquered then
        b.conquered = true
        return true
    end
    return false
end

-- Attempts to spend Marbles to upgrade a single building.
-- bank: a table/object exposing :balance() and :spend(amount) -> bool
function BuildingManager.upgrade(id, bank)
    local b = BuildingManager.get(id)
    if not b or not b.conquered then return false end
    if b.upgradeTier >= b.maxTier then return false end
    local cost = b.upgradeCost * (2 ^ b.upgradeTier)
    if bank:spend(cost) then
        b.upgradeTier = b.upgradeTier + 1
        return true
    end
    return false
end

-- District upgrade: bumps every conquered building by one tier (capped).
-- Unlocked only once all prototype buildings are conquered.
function BuildingManager.districtUpgrade(bank)
    if not BuildingManager.allConquered() then return false end
    local totalCost = 0
    for _, b in ipairs(state) do
        totalCost = totalCost + (b.upgradeCost * (2 ^ b.upgradeTier))
    end
    if bank:spend(totalCost) then
        for _, b in ipairs(state) do
            if b.upgradeTier < b.maxTier then
                b.upgradeTier = b.upgradeTier + 1
            end
        end
        return true
    end
    return false
end

-- ---------- Save / Load ----------

function BuildingManager.getSaveData()
    local out = {}
    for i, b in ipairs(state) do
        out[i] = { id = b.id, conquered = b.conquered, upgradeTier = b.upgradeTier }
    end
    return out
end

function BuildingManager.loadSaveData(data)
    if not data then return end
    for i, saved in ipairs(data) do
        if state[i] then
            state[i].conquered   = saved.conquered or false
            state[i].upgradeTier = saved.upgradeTier or 0
        end
    end
end

function BuildingManager.reset()
    initState()
end

return BuildingManager

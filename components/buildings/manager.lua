local BuildingManager = {}

local buildings = {
    {name = 'Friend', cost = 100, owned = 0, income = 1, assignments = {}},
    {name = 'Gambler', cost = 500, owned = 0, income = 5, assignments = {}},
    {name = 'High Roller', cost = 2000, owned = 0, income = 20, assignments = {}},
    {name = 'Lucky Penny', cost = 5000, owned = 0, income = 0, assignments = {}, bonus = 0.0},
    {name = 'Gambling House', cost = 10000, owned = 0, income = 100, assignments = {}, bonus = 0.10},
    {name = 'Casino', cost = 50000, owned = 0, income = 500, assignments = {}, bonus = 0.15},
    {name = 'Vegas Empire', cost = 250000, owned = 0, income = 2500, assignments = {}, bonus = 0.20},
}

-- Name mapping tables
local keyToDisplayName = {
    coin = 'Coin',
    luckycoin = 'Lucky Coin',
    unluckycoin = 'Unlucky Coin',
    cat = 'Cat',
    grandma = 'Grandma',
    toast = 'Toast'
}

local displayNameToKey = {
    ['Coin'] = 'coin',
    ['Lucky Coin'] = 'luckycoin',
    ['Unlucky Coin'] = 'unluckycoin',
    ['Cat'] = 'cat',
    ['Grandma'] = 'grandma',
    ['Toast'] = 'toast'
}

function BuildingManager.getBuildings()
    return buildings
end

function BuildingManager.getOwned(index)
    return buildings[index] and buildings[index].owned or 0
end

function BuildingManager.getCost(index)
    return buildings[index] and buildings[index].cost or 0
end

function BuildingManager.attemptPurchase(index, player)
    local b = buildings[index]
    if b and player.getPoints() >= b.cost then
        player.subtractPoints(b.cost)
        b.owned = b.owned + 1
        b.assignments = b.assignments or {}
        b.assignments[b.owned] = 'Coin' -- Store display name as default
        return true
    end
    return false
end

function BuildingManager.purchase(index)
    if buildings[index] then
        buildings[index].owned = buildings[index].owned + 1
    end
end

function BuildingManager.getTotalIncome()
    local total = 0
    for _, b in ipairs(buildings) do
        total = total + (b.owned * b.income)
    end
    return total
end

function BuildingManager.getWinBonus(name)
    for _, b in ipairs(buildings) do
        if b.name == name then
            return b.bonus or 0
        end
    end
    return 0
end

function BuildingManager.getAssignableBuildings()
    return buildings
end

function BuildingManager.setAssignment(name, idx, assignment)
    for _, b in ipairs(buildings) do
        if b.name == name then
            b.assignments = b.assignments or {}
            -- Convert flipper key to display name for auto-flipper compatibility
            b.assignments[idx] = keyToDisplayName[assignment] or 'Coin'
            return
        end
    end
end

-- Crew capacity logic for each building type
BuildingManager.crewCapacities = {
    luckyPenny = {
        friends = 3,
        gamblers = 0,
        highRollers = 0,
        total = 3
    },
    gamblingHouse = {
        friends = 1,
        gamblers = 4,
        highRollers = 0,
        total = 5
    },
    casino = {
        friends = 0,
        gamblers = 4,
        highRollers = 4,
        total = 8
    },
    vegasEmpire = {
        friends = 0,
        gamblers = 0,
        highRollers = 12,
        total = 12
    }
}

-- Dropdown state for building modal
local buildingDropdowns = {}
local orderedBuildingList = {}

function BuildingManager.clearBuildingDropdowns()
    for k in pairs(buildingDropdowns) do buildingDropdowns[k] = nil end
    for i = #orderedBuildingList, 1, -1 do table.remove(orderedBuildingList, i) end
end

function BuildingManager.createBuildingModalContent(buildingName, modalX, modalY, modalW, modalH)
    return function(x, y, width, height)
        local padding = 16
        local rowHeight = 50
        -- Flipper options as keys (what dropdown passes to setAssignment)
        local flipperOptions = {'coin', 'luckycoin', 'unluckycoin', 'cat', 'grandma', 'toast'}
        
        -- Rebuild ordered list every frame
        for i = #orderedBuildingList, 1, -1 do table.remove(orderedBuildingList, i) end
        
        local assignable = BuildingManager.getAssignableBuildings()
        local b = nil
        for _, ab in ipairs(assignable) do
            if ab.name == buildingName then b = ab break end
        end
        
        if not b or b.owned < 1 then return end
        
        b.assignments = b.assignments or {}
        -- Ensure all workers have assignments (as display names)
        for j = #b.assignments + 1, b.owned do
            b.assignments[j] = 'Coin'
        end
        
        for j = 1, b.owned do
            table.insert(orderedBuildingList, {name = b.name, index = 1, memberIndex = j})
        end
        
        for idx, entry in ipairs(orderedBuildingList) do
            local i = entry.memberIndex
            
            -- Bar position
            local barY = y + padding + (idx-1)*(rowHeight+8)
            local barW = width - 2*padding
            
            -- Dropdown position
            local dropdownW, dropdownH = 140, 32
            local dropdownX = x + width - padding - dropdownW - 12
            local dropdownY = barY + (rowHeight - dropdownH) / 2
            
            -- Use composite key for dropdown state
            local ddKey = tostring(b.name) .. '_' .. tostring(i)
            buildingDropdowns[ddKey] = buildingDropdowns[ddKey] or {
                options = flipperOptions,
                selectedIndex = 1,
                isOpen = false,
                onSelect = function(idx, value)
                    BuildingManager.setAssignment(b.name, i, value)
                end
            }
            
            local dd = buildingDropdowns[ddKey]
            dd.x, dd.y, dd.w, dd.h = dropdownX, dropdownY, dropdownW, dropdownH
            
            -- Sync selectedIndex with assignment (convert display name back to key for dropdown)
            local assignedDisplayName = b.assignments and b.assignments[i] or 'Coin'
            local assignedKey = displayNameToKey[assignedDisplayName] or 'coin'
            
            for fidx, optionKey in ipairs(flipperOptions) do
                if optionKey == assignedKey then 
                    dd.selectedIndex = fidx 
                    break
                end
            end
            
            -- Draw bar
            love.graphics.setColor(0.85, 0.1, 0)
            love.graphics.rectangle('fill', x + padding, barY, barW, rowHeight, 12)
            love.graphics.setColor(1, 215/255, 0)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle('line', x + padding, barY, barW, rowHeight, 12)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(b.name .. ' #' .. i, x + padding * 2, barY + (rowHeight - 20) / 2)
            
            -- Draw dropdown button
            local bx, by, bw, bh = dd.x, dd.y, dd.w, dd.h
            love.graphics.setColor(0.85, 0.1, 0)
            love.graphics.rectangle('fill', bx, by, bw, bh, 8)
            love.graphics.setColor(1, 215/255, 0)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle('line', bx, by, bw, bh, 8)
            love.graphics.setColor(1, 1, 1)
            
            -- Show display name in dropdown
            local selectedKey = dd.options[dd.selectedIndex] or 'coin'
            local label = keyToDisplayName[selectedKey] or 'Coin'
            love.graphics.print(label, bx + 10, by + 6)
            love.graphics.print(dd.isOpen and '▲' or '▼', bx + bw - 24, by + 6)
        end
    end
end

BuildingManager.buildingDropdowns = buildingDropdowns
BuildingManager.orderedBuildingList = orderedBuildingList

function BuildingManager.getSaveData()
    local saveData = {}
    for i, b in ipairs(buildings) do
        saveData[i] = {
            owned = b.owned,
            assignments = b.assignments or {}
        }
    end
    return saveData
end

function BuildingManager.loadSaveData(saveData)
    if not saveData then return end
    for i, data in pairs(saveData) do
        if buildings[i] then
            buildings[i].owned = data.owned or 0
            buildings[i].assignments = data.assignments or {}
        end
    end
end

function BuildingManager.resetData()
    for _, b in ipairs(buildings) do
        b.owned = 0
        b.assignments = {}
    end
end

return BuildingManager

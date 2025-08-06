local ModalMenu = require('components.modal_menu')

-- Persistent dropdown state for crew members
local crewDropdowns = {}
local orderedCrewList = {}

-- Helper to get flipper options
local function getFlipperOptions()
    local coins = require('components.flippers.coins')
    local misc = require('components.flippers.miscellaneous')
    local options = {}
    local seen = {}
    for k, v in pairs(coins) do
        if not seen[v.name] then
            table.insert(options, v.name)
            seen[v.name] = true
        end
    end
    for k, v in pairs(misc) do
        if not seen[v.name] then
            table.insert(options, v.name)
            seen[v.name] = true
        end
    end
    return options
end

-- Clear all dropdown state (call on modal close)
local function clearCrewDropdowns()
    for k in pairs(crewDropdowns) do crewDropdowns[k] = nil end
    for i = #orderedCrewList, 1, -1 do table.remove(orderedCrewList, i) end
end

-- Crew modal content function
function createCrewModalContent(building, modalX, modalY, modalW, modalH)
    return function(x, y, width, height)
        local padding = 16
        local crewRowHeight = 50
        local flipperOptions = getFlipperOptions()
        local crewType = building.crewType or building.type or building.name:lower():gsub("%s", "")
        -- Auto-pad assignments array for legacy/short saves
        building.assignments = building.assignments or {}
        for i = #building.assignments + 1, building.owned do
            building.assignments[i] = 'coin'
        end
        -- Rebuild ordered list every frame
        for i = #orderedCrewList, 1, -1 do table.remove(orderedCrewList, i) end
        for i = 1, building.owned do
            table.insert(orderedCrewList, {crewType = crewType, memberIndex = i})
        end
        for idx, member in ipairs(orderedCrewList) do
            local i = member.memberIndex
            -- Bar position
            local barY = y + padding + (idx-1)*(crewRowHeight+8)
            local barW = width - 2*padding
            -- Dropdown position (right side, 12px from right edge)
            local dropdownW, dropdownH = 140, 32
            local dropdownX = x + width - padding - dropdownW - 12
            local dropdownY = barY + (crewRowHeight - dropdownH) / 2
            -- Use composite key for dropdown state
            local ddKey = tostring(crewType) .. '_' .. tostring(i)
            crewDropdowns[ddKey] = crewDropdowns[ddKey] or {
                options = flipperOptions,
                selectedIndex = 1,
                isOpen = false,
                onSelect = function(idx, value)
                    building.assignments[i] = value
                end
            }
            local dd = crewDropdowns[ddKey]
            -- Update bounding box every frame
            dd.x, dd.y, dd.w, dd.h = dropdownX, dropdownY, dropdownW, dropdownH
            -- Sync selectedIndex with assignment
            local assigned = building.assignments and building.assignments[i]
            for fidx, v in ipairs(flipperOptions) do
                if v == assigned then dd.selectedIndex = fidx end
            end
            -- Draw bar
            love.graphics.setColor(0.85, 0.1, 0)
            love.graphics.rectangle('fill', x + padding, barY, barW, crewRowHeight, 12)
            love.graphics.setColor(1, 215/255, 0)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle('line', x + padding, barY, barW, crewRowHeight, 12)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(building.name .. ' #' .. i, x + padding * 2, barY + (crewRowHeight - 20) / 2)
            -- Draw dropdown button
            local bx, by, bw, bh = dd.x, dd.y, dd.w, dd.h
            love.graphics.setColor(0.85, 0.1, 0)
            love.graphics.rectangle('fill', bx, by, bw, bh, 8)
            love.graphics.setColor(1, 215/255, 0)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle('line', bx, by, bw, bh, 8)
            love.graphics.setColor(1, 1, 1)
            local label = dd.options[dd.selectedIndex] or 'Select...'
            love.graphics.print(label, bx + 10, by + 6)
            love.graphics.print(dd.isOpen and '▲' or '▼', bx + bw - 24, by + 6)
        end
    end
end

-- Expose crewDropdowns, orderedCrewList, and clear function
return {
    crewDropdowns = crewDropdowns,
    orderedCrewList = orderedCrewList,
    createCrewModalContent = createCrewModalContent,
    clearCrewDropdowns = clearCrewDropdowns
} 
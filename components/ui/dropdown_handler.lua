local DropdownHandler = {}

-- Get required managers
local function getManagers()
    local CrewManager = require('components.crew.manager')
    local BuildingManager = require('components.buildings.manager')
    return CrewManager, BuildingManager
end

-- Helper function to close all dropdowns except the specified one
local function closeOtherDropdowns(dropdowns, keepOpenKey)
    for key, dd in pairs(dropdowns) do
        if key ~= keepOpenKey then
            dd.isOpen = false
        end
    end
end

-- Handle clicks on dropdown options (the expanded list)
local function handleDropdownOptionClick(dropdown, x, y)
    if not dropdown.isOpen then return false end
    
    local bx, by, bw, bh = dropdown.x, dropdown.y, dropdown.w, dropdown.h
    local optH = bh
    local n = #dropdown.options
    
    -- Check if click is within the dropdown options area
    local listStartY = by + bh
    local listEndY = listStartY + (n * optH)
    
    if x >= bx and x <= bx + bw and y >= listStartY and y <= listEndY then
        -- Calculate which option was clicked
        local optionIndex = math.floor((y - listStartY) / optH) + 1
        
        if optionIndex >= 1 and optionIndex <= n then
            dropdown.selectedIndex = optionIndex
            
            -- Force close dropdown BEFORE callback
            dropdown.isOpen = false
            
            -- Trigger callback if exists (with 3 parameters for compatibility)
            if dropdown.onSelect then
                dropdown.onSelect(optionIndex, dropdown.options[optionIndex], dropdown)
            end
            
            return true -- Option was selected
        end
    end
    
    return false
end

-- Handle clicks on dropdown buttons (toggle open/close)
local function handleDropdownButtonClick(dropdown, x, y, dropdowns, dropdownKey)
    local bx, by, bw, bh = dropdown.x, dropdown.y, dropdown.w, dropdown.h
    
    -- Check if click is on dropdown button
    if x >= bx and x <= bx + bw and y >= by and y <= by + bh then
        -- Store original state before closing others
        local wasOpen = dropdown.isOpen
        
        -- Close other dropdowns first
        closeOtherDropdowns(dropdowns, dropdownKey)
        
        -- Toggle this dropdown (opposite of what it was)
        dropdown.isOpen = not wasOpen
        
        return true -- Button was clicked
    end
    
    return false
end

-- Handle crew dropdown clicks (both modal and non-modal)
local function handleCrewDropdownClicks(x, y, button)
    local CrewManager = getManagers()
    
    if not CrewManager.crewDropdowns or not CrewManager.orderedCrewList then
        return false
    end
    
    local crewDropdowns = CrewManager.crewDropdowns
    local orderedCrewList = CrewManager.orderedCrewList
    
    -- Check for clicks on dropdown options first
    for _, member in ipairs(orderedCrewList) do
        local ddKey = tostring(member.crewType) .. '_' .. tostring(member.memberIndex)
        local dd = crewDropdowns[ddKey]
        
        if dd and handleDropdownOptionClick(dd, x, y) then
            -- Close other dropdowns after selection
            closeOtherDropdowns(crewDropdowns, nil) -- Close all
            return true
        end
    end
    
    -- Check for clicks on dropdown buttons
    for _, member in ipairs(orderedCrewList) do
        local ddKey = tostring(member.crewType) .. '_' .. tostring(member.memberIndex)
        local dd = crewDropdowns[ddKey]
        
        if dd and handleDropdownButtonClick(dd, x, y, crewDropdowns, ddKey) then
            return true
        end
    end
    
    return false
end

-- Handle building dropdown clicks (both modal and non-modal)
local function handleBuildingDropdownClicks(x, y, button)
    local _, BuildingManager = getManagers()
    
    if not BuildingManager.buildingDropdowns or not BuildingManager.orderedBuildingList then
        return false
    end
    
    local buildingDropdowns = BuildingManager.buildingDropdowns
    local orderedBuildingList = BuildingManager.orderedBuildingList
    
    -- Check for clicks on dropdown options first
    for _, entry in ipairs(orderedBuildingList) do
        local ddKey = tostring(entry.name) .. '_' .. tostring(entry.memberIndex)
        local dd = buildingDropdowns[ddKey]
        
        if dd and handleDropdownOptionClick(dd, x, y) then
            -- Close other dropdowns after selection
            closeOtherDropdowns(buildingDropdowns, nil) -- Close all
            return true
        end
    end
    
    -- Check for clicks on dropdown buttons
    for _, entry in ipairs(orderedBuildingList) do
        local ddKey = tostring(entry.name) .. '_' .. tostring(entry.memberIndex)
        local dd = buildingDropdowns[ddKey]
        
        if dd and handleDropdownButtonClick(dd, x, y, buildingDropdowns, ddKey) then
            return true
        end
    end
    
    return false
end

-- Handle clicks outside dropdowns (close them) - FIXED VERSION
local function handleOutsideClicks(x, y)
    local CrewManager, BuildingManager = getManagers()
    
    -- Check if click was actually ON any dropdown button or option area
    local clickedOnDropdown = false
    
    -- Check crew dropdowns
    if CrewManager.crewDropdowns and CrewManager.orderedCrewList then
        for _, member in ipairs(CrewManager.orderedCrewList) do
            local ddKey = tostring(member.crewType) .. '_' .. tostring(member.memberIndex)
            local dd = CrewManager.crewDropdowns[ddKey]
            
            if dd then
                local bx, by, bw, bh = dd.x, dd.y, dd.w, dd.h
                local optH = bh
                local n = #dd.options
                local listH = dd.isOpen and (n * optH) or 0
                
                -- Check if click is on button OR dropdown area
                if x >= bx and x <= bx + bw and y >= by and y <= by + bh + listH then
                    clickedOnDropdown = true
                    break
                end
            end
        end
    end
    
    -- Check building dropdowns if not already found
    if not clickedOnDropdown and BuildingManager.buildingDropdowns and BuildingManager.orderedBuildingList then
        for _, entry in ipairs(BuildingManager.orderedBuildingList) do
            local ddKey = tostring(entry.name) .. '_' .. tostring(entry.memberIndex)
            local dd = BuildingManager.buildingDropdowns[ddKey]
            
            if dd then
                local bx, by, bw, bh = dd.x, dd.y, dd.w, dd.h
                local optH = bh
                local n = #dd.options
                local listH = dd.isOpen and (n * optH) or 0
                
                -- Check if click is on button OR dropdown area
                if x >= bx and x <= bx + bw and y >= by and y <= by + bh + listH then
                    clickedOnDropdown = true
                    break
                end
            end
        end
    end
    
    -- Only close dropdowns if click was truly OUTSIDE all dropdowns
    if not clickedOnDropdown then
        DropdownHandler.closeAllDropdowns()
    end
end

-- Check if any dropdown is currently open
function DropdownHandler.hasOpenDropdown()
    local CrewManager, BuildingManager = getManagers()
    
    -- Check crew dropdowns
    if CrewManager.crewDropdowns then
        for _, dd in pairs(CrewManager.crewDropdowns) do
            if dd.isOpen then return true end
        end
    end
    
    -- Check building dropdowns
    if BuildingManager.buildingDropdowns then
        for _, dd in pairs(BuildingManager.buildingDropdowns) do
            if dd.isOpen then return true end
        end
    end
    
    return false
end

-- Main dropdown click handler - handles ALL dropdown interactions - FIXED VERSION
function DropdownHandler.handleDropdownClicks(x, y, button)
    if button ~= 1 then return false end -- Only handle left clicks
    
    -- Handle crew dropdown clicks
    if handleCrewDropdownClicks(x, y, button) then
        return true -- Crew dropdown interaction - block other UI
    end
    
    -- Handle building dropdown clicks
    if handleBuildingDropdownClicks(x, y, button) then
        return true -- Building dropdown interaction - block other UI
    end
    
    -- Handle outside clicks (but be smart about it)
    handleOutsideClicks(x, y)
    
    -- Return false to allow other UI handling if no dropdown was interacted with
    return false
end

-- Close all open dropdowns (preserves dropdown data)
function DropdownHandler.closeAllDropdowns()
    local CrewManager, BuildingManager = getManagers()
    
    -- Close crew dropdowns
    if CrewManager.crewDropdowns then
        for _, dd in pairs(CrewManager.crewDropdowns) do
            dd.isOpen = false
        end
    end
    
    -- Close building dropdowns
    if BuildingManager.buildingDropdowns then
        for _, dd in pairs(BuildingManager.buildingDropdowns) do
            dd.isOpen = false
        end
    end
end

-- Clear all dropdowns using manager functions
function DropdownHandler.clearAllDropdowns()
    local CrewManager, BuildingManager = getManagers()
    
    if CrewManager.clearCrewDropdowns then 
        CrewManager.clearCrewDropdowns() 
    end
    if BuildingManager.clearBuildingDropdowns then 
        BuildingManager.clearBuildingDropdowns() 
    end
end

return DropdownHandler

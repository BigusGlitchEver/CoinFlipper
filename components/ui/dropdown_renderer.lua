local DropdownRenderer = {}

-- Common dropdown styling constants
local DROPDOWN_BG_COLOR = {0.7, 0, 0, 1}
local DROPDOWN_BORDER_COLOR = {1, 215/255, 0, 1}
local DROPDOWN_HOVER_COLOR = {1, 0.85, 0, 0.3}
local DROPDOWN_SELECTED_COLOR = {1, 0.85, 0, 0.2}
local DROPDOWN_TEXT_COLOR = {1, 1, 1, 1}
local DROPDOWN_BORDER_WIDTH = 2
local DROPDOWN_CORNER_RADIUS = 8
local DROPDOWN_TEXT_PADDING = 10
local DROPDOWN_TEXT_OFFSET_Y = 6

-- Helper function to draw a single dropdown list
local function drawDropdownList(dd)
    if not dd.isOpen then return end
    
    local bx, by, bw, bh = dd.x, dd.y, dd.w, dd.h
    local optH = bh
    local n = #dd.options
    local listH = n * optH
    local mx, my = love.mouse.getPosition()
    
    -- Draw dropdown background
    love.graphics.setColor(DROPDOWN_BG_COLOR)
    love.graphics.rectangle('fill', bx, by + bh, bw, listH, DROPDOWN_CORNER_RADIUS)
    
    -- Draw dropdown border
    love.graphics.setColor(DROPDOWN_BORDER_COLOR)
    love.graphics.setLineWidth(DROPDOWN_BORDER_WIDTH)
    love.graphics.rectangle('line', bx, by + bh, bw, listH, DROPDOWN_CORNER_RADIUS)
    
    -- Draw dropdown options
    for j = 1, n do
        local oy = by + bh + (j-1) * optH
        
        -- Draw hover effect
        if mx >= bx and mx <= bx + bw and my >= oy and my <= oy + optH then
            love.graphics.setColor(DROPDOWN_HOVER_COLOR)
            love.graphics.rectangle('fill', bx + 2, oy + 2, bw - 4, optH - 4, DROPDOWN_CORNER_RADIUS - 2)
        end
        
        -- Draw selected effect
        if dd.selectedIndex == j then
            love.graphics.setColor(DROPDOWN_SELECTED_COLOR)
            love.graphics.rectangle('fill', bx + 2, oy + 2, bw - 4, optH - 4, DROPDOWN_CORNER_RADIUS - 2)
        end
        
        -- Draw option text
        love.graphics.setColor(DROPDOWN_TEXT_COLOR)
        love.graphics.print(dd.options[j], bx + DROPDOWN_TEXT_PADDING, oy + DROPDOWN_TEXT_OFFSET_Y)
    end
end

-- Draw all crew dropdowns
function DropdownRenderer.drawCrewDropdowns(crewDropdowns)
    if not crewDropdowns then return end
    
    for i, dd in pairs(crewDropdowns) do
        drawDropdownList(dd)
    end
end

-- Draw all building dropdowns
function DropdownRenderer.drawBuildingDropdowns(buildingDropdowns)
    if not buildingDropdowns then return end
    
    for k, dd in pairs(buildingDropdowns) do
        drawDropdownList(dd)
    end
end

-- Draw any generic dropdown (for future extensibility)
function DropdownRenderer.drawDropdown(dropdown)
    drawDropdownList(dropdown)
end

-- Utility function to check if any dropdown in a collection is open
function DropdownRenderer.hasOpenDropdown(dropdowns)
    if not dropdowns then return false end
    
    for _, dd in pairs(dropdowns) do
        if dd.isOpen then return true end
    end
    return false
end

-- Get the currently open dropdown from a collection (returns first found)
function DropdownRenderer.getOpenDropdown(dropdowns)
    if not dropdowns then return nil end
    
    for key, dd in pairs(dropdowns) do
        if dd.isOpen then return dd, key end
    end
    return nil
end

return DropdownRenderer 
local theme = require('theme')

local Dropdown = {}

-- Track dropdown state
local dropdowns = {}
local activeDropdown = nil

function Dropdown.create(id, x, y, width, height, options, selectedIndex, onSelect)
    dropdowns[id] = {
        x = x,
        y = y,
        width = width,
        height = height,
        options = options or {},
        selectedIndex = selectedIndex or 1,
        isOpen = false,
        onSelect = onSelect,
        anim = 0, -- 0=closed, 1=open
    }
end

function Dropdown.update(dt)
    for id, dropdown in pairs(dropdowns) do
        if dropdown.isOpen then
            dropdown.anim = math.min(1, dropdown.anim + dt * 8)
        else
            dropdown.anim = math.max(0, dropdown.anim - dt * 8)
        end
    end
end

function Dropdown.draw()
    for id, dropdown in pairs(dropdowns) do
        local cx, cy, cw, ch = dropdown.x, dropdown.y, dropdown.width, dropdown.height
        
        -- Main dropdown button
        love.graphics.setColor(0.85, 0.1, 0) -- Red background
        love.graphics.rectangle('fill', cx, cy, cw, ch, 8)
        
        -- Main dropdown border
        love.graphics.setColor(1, 215/255, 0) -- Gold border
        love.graphics.setLineWidth(2)
        love.graphics.rectangle('line', cx, cy, cw, ch, 8)
        
        -- Selected option text
        love.graphics.setColor(1, 1, 1) -- White text
        local selectedText = dropdown.options[dropdown.selectedIndex] or "Select..."
        love.graphics.print(selectedText, cx + 8, cy + 6)
        
        -- Arrow indicator
        local arrowText = dropdown.isOpen and "▲" or "▼"
        love.graphics.print(arrowText, cx + cw - 20, cy + 6)
        
        -- Dropdown options (when open)
        if dropdown.anim > 0 then
            local optionHeight = 25
            local maxOptions = math.min(5, #dropdown.options) -- Show max 5 options
            local dropdownHeight = maxOptions * optionHeight
            
            -- Options background
            love.graphics.setColor(0.7, 0, 0, dropdown.anim) -- Red background with alpha
            love.graphics.rectangle('fill', cx, cy + ch, cw, dropdownHeight, 8)
            
            -- Options border
            love.graphics.setColor(1, 215/255, 0, dropdown.anim) -- Gold border with alpha
            love.graphics.setLineWidth(2)
            love.graphics.rectangle('line', cx, cy + ch, cw, dropdownHeight, 8)
            
            -- Option items
            for i = 1, maxOptions do
                local optionY = cy + ch + (i - 1) * optionHeight
                local optionText = dropdown.options[i]
                
                -- Highlight hovered option
                local mouseX, mouseY = love.mouse.getX(), love.mouse.getY()
                if mouseX >= cx and mouseX <= cx + cw and mouseY >= optionY and mouseY <= optionY + optionHeight then
                    love.graphics.setColor(0.85, 0.1, 0, dropdown.anim) -- Brighter red for hover
                    love.graphics.rectangle('fill', cx + 2, optionY + 2, cw - 4, optionHeight - 4, 6)
                end
                
                -- Option text
                love.graphics.setColor(1, 1, 1, dropdown.anim) -- White text with alpha
                love.graphics.print(optionText, cx + 8, optionY + 4)
            end
        end
    end
end

function Dropdown.mousepressed(x, y, button)
    if button == 1 then -- Left click
        for id, dropdown in pairs(dropdowns) do
            local cx, cy, cw, ch = dropdown.x, dropdown.y, dropdown.width, dropdown.height
            
            -- Check if click is on main dropdown button
            if x >= cx and x <= cx + cw and y >= cy and y <= cy + ch then
                -- Close other dropdowns
                for otherId, otherDropdown in pairs(dropdowns) do
                    if otherId ~= id then
                        otherDropdown.isOpen = false
                    end
                end
                
                -- Toggle this dropdown
                dropdown.isOpen = not dropdown.isOpen
                activeDropdown = dropdown.isOpen and id or nil
                return true
            end
            
            -- Check if click is on dropdown options
            if dropdown.isOpen and dropdown.anim > 0.5 then
                local optionHeight = 25
                local maxOptions = math.min(5, #dropdown.options)
                
                for i = 1, maxOptions do
                    local optionY = cy + ch + (i - 1) * optionHeight
                    if x >= cx and x <= cx + cw and y >= optionY and y <= optionY + optionHeight then
                        dropdown.selectedIndex = i
                        dropdown.isOpen = false
                        activeDropdown = nil
                        if dropdown.onSelect then
                            dropdown.onSelect(i, dropdown.options[i])
                        end
                        return true
                    end
                end
            end
        end
        
        -- Close dropdown if clicking outside
        if activeDropdown then
            dropdowns[activeDropdown].isOpen = false
            activeDropdown = nil
            return true
        end
    end
    return false
end

function Dropdown.getSelected(id)
    local dropdown = dropdowns[id]
    if dropdown then
        return dropdown.selectedIndex, dropdown.options[dropdown.selectedIndex]
    end
    return nil, nil
end

function Dropdown.setSelected(id, index)
    local dropdown = dropdowns[id]
    if dropdown and index >= 1 and index <= #dropdown.options then
        dropdown.selectedIndex = index
    end
end

function Dropdown.clear()
    dropdowns = {}
    activeDropdown = nil
end

return Dropdown 
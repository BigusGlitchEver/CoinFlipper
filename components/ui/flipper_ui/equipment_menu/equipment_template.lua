local EquipmentManager = require('components.ui.flipper_ui.equipment_menu.equipment_manager')
local Items = require('data.items')
local Player = require('components.player.player')
local StatsTracker = require('components.player.stats_tracker')
local Inventory = require('components.player.inventory')
local right_details_panel = require('components.ui.flipper_ui.equipment_menu.right_details_panel')

local equipment_template = {}

-- Shared state for all template instances
local sharedState = {
    imageCache = {},
    hoveredItem = nil,
    selectedItem = nil,
    lastUpdateTime = 0
}

-- Utility functions
local function loadImage(path)
    if sharedState.imageCache[path] then
        return sharedState.imageCache[path]
    end
    
    local success, image = pcall(love.graphics.newImage, path)
    if success then
        image:setFilter('nearest', 'nearest')
        sharedState.imageCache[path] = image
        return image
    else
        return nil
    end
end

    local function getItemState(item)
        -- Use the item's own getItemState function if it exists (KISS approach)
        if item.getItemState then
            return item.getItemState()
        end
        
        -- Fallback to normal equipment logic for items without custom state
        local equipped = Player.equipped and Player.equipped[item.slot]
        if equipped and equipped.id == item.id then
            return 'equipped'
        elseif Inventory.hasItem(item.id) then
            return 'owned'
        elseif Player.getPoints() >= item.price then
            return 'available'
        else
            return 'locked'
        end
    end

local function formatPrice(price)
    if price >= 1000000 then
        return string.format("%.1fM", price / 1000000)
    elseif price >= 1000 then
        return string.format("%.1fK", price / 1000)
    else
        return tostring(price)
    end
end

-- Simple grid calculation
local function getGridPosition(index, x, y, w, h)
    local columns = 4
    local cellSize = 88
    local padding = 18
    local startX = x + 32
    local startY = y + 32
    
    local col = (index - 1) % columns
    local row = math.floor((index - 1) / columns)
    
    local cellX = startX + col * (cellSize + padding)
    local cellY = startY + row * (cellSize + padding)
    
    return cellX, cellY, cellSize, cellSize
end

local function isPointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

-- Template creation function
function equipment_template.create(config)
    config = config or {}
    
    -- Default configuration
    local defaultConfig = {
        slotName = 'hat',
        showAllItems = true  -- Show all items including locked ones
    }
    
    -- Merge with provided config
    for k, v in pairs(config) do
        defaultConfig[k] = v
    end
    
    config = defaultConfig
    
    -- Template instance state
    local instanceState = {
        items = {},
        lastItemUpdate = 0,
        hoveredItem = nil,
        selectedItem = nil,
        gridPositions = {}  -- Store grid positions like tabs do
    }
    
    -- Update items list (cached per update cycle)
    local function updateItems()
        local currentTime = love.timer.getTime()
        if currentTime - instanceState.lastItemUpdate < 0.1 then
            return instanceState.items
        end
        
        instanceState.lastItemUpdate = currentTime
        instanceState.items = EquipmentManager.getItemsForSlot(config.slotName, config.showAllItems)
        
        return instanceState.items
    end
    
    -- Draw grid only
    local function drawGrid(x, y, w, h)
        local items = updateItems()
        

        
        -- Clear and recalculate grid positions (like tabs do)
        instanceState.gridPositions = {}
        
        for i, item in ipairs(items) do
            local cellX, cellY, cellW, cellH = getGridPosition(i, x, y, w, h)
            
            -- Store grid position (like absoluteTabPositions)
            instanceState.gridPositions[i] = {
                x = cellX,
                y = cellY,
                w = cellW,
                h = cellH,
                item = item
            }
            
            local state = getItemState(item)
            local isHovered = (instanceState.hoveredItem == item)
            local isSelected = (instanceState.selectedItem == item)
            
            -- Draw cell background (translucent)
            love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
            love.graphics.rectangle('fill', cellX, cellY, cellW, cellH, 8)
            
            -- Draw border with proper state priorities
            if isSelected and isHovered then
                -- Yellow border for selected + hover
                love.graphics.setColor(1, 1, 0, 1)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle('line', cellX, cellY, cellW, cellH, 8)
            elseif isSelected then
                -- Yellow border for selected only
                love.graphics.setColor(1, 1, 0, 1)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle('line', cellX, cellY, cellW, cellH, 8)
            elseif isHovered then
                -- Hover effect: red for locked items, orange for unavailable items, yellow for available/owned/equipped items
                if state == 'locked' then
                    love.graphics.setColor(1, 0, 0, 1) -- Red for locked items
                elseif state == 'unavailable' then
                    love.graphics.setColor(1, 0.5, 0, 1) -- Orange for unavailable items
                else
                    love.graphics.setColor(1, 1, 0, 1) -- Yellow for available/owned/equipped items
                end
                love.graphics.setLineWidth(3)
                love.graphics.rectangle('line', cellX, cellY, cellW, cellH, 8)
            else
                -- Default colors: black for locked/unowned, orange for owned, yellow for equipped
                if state == 'equipped' then
                    love.graphics.setColor(1, 1, 0, 1) -- Yellow for equipped
                elseif state == 'owned' then
                    love.graphics.setColor(1, 0.5, 0, 1) -- Orange for owned
                elseif state == 'available' then
                    love.graphics.setColor(0, 0, 0, 1) -- Black for available (not hovered)
                else
                    love.graphics.setColor(0, 0, 0, 1) -- Black for locked/unavailable
                end
                love.graphics.setLineWidth(2)
                love.graphics.rectangle('line', cellX, cellY, cellW, cellH, 8)
            end
            
            -- Draw item image
            local image = loadImage(item.image)
            if image then
                love.graphics.setColor(1, 1, 1, state == 'locked' and 0.2 or 1)
                local imgW, imgH = image:getDimensions()
                local scale = math.min(cellW * 0.7 / imgW, cellH * 0.7 / imgH)
                local imgX = cellX + (cellW - imgW * scale) / 2
                local imgY = cellY + (cellH - imgH * scale) / 2
                love.graphics.draw(image, imgX, imgY, 0, scale, scale)
            end
            
            -- Draw coin symbol for owned items (top-right corner)
            if state == 'owned' or state == 'equipped' then
                local coinImage = loadImage('assets/Flippers/Coins/Regular/CoinHeads.png')
                if coinImage then
                    love.graphics.setColor(1, 1, 1, 1)
                    local coinSize = 16
                    local coinX = cellX + cellW - coinSize - 4
                    local coinY = cellY + 4
                    love.graphics.draw(coinImage, coinX, coinY, 0, coinSize/32, coinSize/32)
                end
            end
            
            -- Draw lock symbol for locked items (center)
            if state == 'locked' then
                local lockImage = loadImage('assets/upgrades/notification/locked.png')
                if lockImage then
                    love.graphics.setColor(1, 1, 1, 0.8)
                    local lockSize = 24
                    local lockX = cellX + (cellW - lockSize) / 2
                    local lockY = cellY + (cellH - lockSize) / 2
                    love.graphics.draw(lockImage, lockX, lockY, 0, lockSize/32, lockSize/32)
                end
            end
            
            -- Draw price or status
            love.graphics.setColor(1, 1, 1)
            local text = state == 'equipped' and 'EQUIPPED' or 
                        state == 'owned' and 'OWNED' or
                        (state == 'available' or state == 'unavailable') and formatPrice(item.price) or
                        'LOCKED'
            
            local font = love.graphics.getFont()
            local textW = font:getWidth(text)
            local textX = cellX + (cellW - textW) / 2
            local textY = cellY + cellH - 20
            love.graphics.print(text, textX, textY)
            

        end
    end
    
    -- Mouse handling functions
    local function handleGridClick(mx, my, x, y, w, h)
        -- Use stored grid positions (like tabs do)
        for i, pos in ipairs(instanceState.gridPositions) do
            if isPointInRect(mx, my, pos.x, pos.y, pos.w, pos.h) then
                instanceState.selectedItem = pos.item
                
                return true
            end
        end
        return false
    end
    
    local function handleGridHover(mx, my, x, y, w, h)
        -- Use stored grid positions (like tabs do)
        for i, pos in ipairs(instanceState.gridPositions) do
            if isPointInRect(mx, my, pos.x, pos.y, pos.w, pos.h) then
                instanceState.hoveredItem = pos.item
                
                return true
            end
        end
        instanceState.hoveredItem = nil
        return false
    end
    
    -- Main template functions
    local template = {}
    
    function template.draw(x, y, w, h)
        -- Split layout: left panel for grid, right panel for details
        local leftPanelW = w * 0.6  -- 60% for grid
        local rightPanelW = w * 0.4  -- 40% for details
        local rightPanelX = x + leftPanelW
        
        -- Draw left panel (grid)
        drawGrid(x, y, leftPanelW, h)
        
        -- Draw right panel (details) - use clicked item with fallback to hovered item
        local itemToShow = instanceState.selectedItem or instanceState.hoveredItem
        right_details_panel.draw(rightPanelX, y, rightPanelW, h, itemToShow)
    end
    
    function template.mousepressed(mx, my, x, y, w, h)
        -- Split layout for click handling
        local leftPanelW = w * 0.6
        local rightPanelW = w * 0.4
        local rightPanelX = x + leftPanelW
        
        -- Handle clicks in left panel (grid)
        if mx < rightPanelX then
            return handleGridClick(mx, my, x, y, leftPanelW, h)
        end
        
        return false
    end
    
    function template.mousemoved(mx, my, x, y, w, h)
        -- Split layout for hover handling
        local leftPanelW = w * 0.6
        local rightPanelW = w * 0.4
        local rightPanelX = x + leftPanelW
        
        -- Handle hover in left panel (grid)
        if mx < rightPanelX then
            handleGridHover(mx, my, x, y, leftPanelW, h)
        else
            -- Clear hover when mouse is in right panel
            instanceState.hoveredItem = nil
        end
    end
    
    return template
end

return equipment_template 
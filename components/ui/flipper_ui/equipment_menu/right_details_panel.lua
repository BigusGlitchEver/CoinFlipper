local Button = require('components.ui.button')
local EquipmentManager = require('components.ui.flipper_ui.equipment_menu.equipment_manager')

local right_details_panel = {}

-- Utility function to load images
local function loadImage(path)
    local success, image = pcall(love.graphics.newImage, path)
    if success then
        image:setFilter('nearest', 'nearest')
        return image
    else
        return nil
    end
end

-- Format price display
local function formatPrice(price)
    if price >= 1000000 then
        return string.format("%.1fM", price / 1000000)
    elseif price >= 1000 then
        return string.format("%.1fK", price / 1000)
    else
        return tostring(price)
    end
end

function right_details_panel.draw(x, y, w, h, item)
    if not item then
        -- Show "Whatcha want?" when no item is hovered
        love.graphics.setColor(1, 1, 1, 1)
        local font = love.graphics.getFont()
        
        -- Big question mark
        local questionMark = "?"
        local questionW = font:getWidth(questionMark)
        local questionX = x + (w - questionW) / 2
        local questionY = y + h / 2 - 40
        love.graphics.print(questionMark, questionX, questionY)
        
        -- "Whatcha want?" text
        local text = "Whatcha want?"
        local textW = font:getWidth(text)
        local textX = x + (w - textW) / 2
        local textY = y + h / 2 + 10
        love.graphics.print(text, textX, textY)
        
        return
    end
    
    -- Item box dimensions (centered, bordered rectangle)
    local itemBoxW = w * 0.8  -- 80% of panel width
    local itemBoxH = h * 0.6  -- 60% of panel height
    local itemBoxX = x + (w - itemBoxW) / 2
    local itemBoxY = y + 60  -- Leave space for name box
    
    -- Draw item box background (only if item has image)
    local image = loadImage(item.image)
    if image then
        love.graphics.setColor(0.3, 0.3, 0.3, 0.9)
        love.graphics.rectangle('fill', itemBoxX, itemBoxY, itemBoxW, itemBoxH, 8)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle('line', itemBoxX, itemBoxY, itemBoxW, itemBoxH, 8)
        
        -- Draw item image inside the box
        local state = EquipmentManager.getItemState(item)
        local imageAlpha = (state == 'locked') and 0.1 or 1  -- Much more opaque for locked items
        love.graphics.setColor(1, 1, 1, imageAlpha)
        local imgW, imgH = image:getDimensions()
        local maxImgW = itemBoxW - 20
        local maxImgH = itemBoxH - 20
        local scale = math.min(maxImgW / imgW, maxImgH / imgH)
        local imgX = itemBoxX + (itemBoxW - imgW * scale) / 2
        local imgY = itemBoxY + (itemBoxH - imgH * scale) / 2
        love.graphics.draw(image, imgX, imgY, 0, scale, scale)
    end
    
    -- Name box (sits on top edge of item box, centered)
    local nameBoxW = 120
    local nameBoxH = 30
    local nameBoxX = itemBoxX + (itemBoxW - nameBoxW) / 2
    local nameBoxY = itemBoxY - nameBoxH / 2  -- Overlaps top edge
    
    love.graphics.setColor(0.4, 0.4, 0.4, 0.9)
    love.graphics.rectangle('fill', nameBoxX, nameBoxY, nameBoxW, nameBoxH, 6)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', nameBoxX, nameBoxY, nameBoxW, nameBoxH, 6)
    
    -- Name text
    love.graphics.setColor(1, 1, 1, 1)
    local font = love.graphics.getFont()
    local nameW = font:getWidth(item.name)
    local nameX = nameBoxX + (nameBoxW - nameW) / 2
    local nameY = nameBoxY + (nameBoxH - font:getHeight()) / 2
    love.graphics.print(item.name, nameX, nameY)
    
    -- Price box (top-left corner, outside item box) - only show for unlocked items
    local state = EquipmentManager.getItemState(item)
    if state ~= 'locked' then
        local priceText = formatPrice(item.price)
        local priceBoxW = font:getWidth(priceText) + 20
        local priceBoxH = 25
        local priceBoxX = x + 20  -- Top-left corner of panel
        local priceBoxY = y + 50  -- Slightly lower than title
        
        love.graphics.setColor(0.4, 0.4, 0.4, 0.9)
        love.graphics.rectangle('fill', priceBoxX, priceBoxY, priceBoxW, priceBoxH, 4)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle('line', priceBoxX, priceBoxY, priceBoxW, priceBoxH, 4)
        
        -- Price text
        love.graphics.setColor(1, 1, 0, 1) -- Yellow
        local priceX = priceBoxX + (priceBoxW - font:getWidth(priceText)) / 2
        local priceY = priceBoxY + (priceBoxH - font:getHeight()) / 2
        love.graphics.print(priceText, priceX, priceY)
    end
    
    -- Description box (sits on bottom edge of item box, centered)
    if item.description then
        local descText = '"' .. item.description .. '"'
        local descBoxW = font:getWidth(descText) + 20
        local descBoxH = 30
        local descBoxX = itemBoxX + (itemBoxW - descBoxW) / 2
        local descBoxY = itemBoxY + itemBoxH - descBoxH / 2  -- Overlaps bottom edge
        
        love.graphics.setColor(0.4, 0.4, 0.4, 0.9)
        love.graphics.rectangle('fill', descBoxX, descBoxY, descBoxW, descBoxH, 6)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle('line', descBoxX, descBoxY, descBoxW, descBoxH, 6)
        
        -- Description text
        love.graphics.setColor(1, 1, 1, 1)
        local descX = descBoxX + (descBoxW - font:getWidth(descText)) / 2
        local descY = descBoxY + (descBoxH - font:getHeight()) / 2
        love.graphics.print(descText, descX, descY)
    end
    
    -- Effect text (directly under description box) - only show for unlocked items
    local state = EquipmentManager.getItemState(item)
    if state ~= 'locked' and item.stats and item.stats.coin_value then
        love.graphics.setColor(1, 0.8, 0, 1) -- Gold color
        local effectText = "Effect: +" .. item.stats.coin_value .. " coin value"
        local effectW = font:getWidth(effectText)
        local effectX = x + (w - effectW) / 2
        local effectY = itemBoxY + itemBoxH + 20
        love.graphics.print(effectText, effectX, effectY)
    end
    
    -- Buy button at bottom (like sketch) - TODO: Will implement in Step 3
    local state = EquipmentManager.getItemState(item)
    if state == 'available' or state == 'unavailable' then
        local buttonW, buttonH = 120, 40
        local buttonX = x + (w - buttonW) / 2
        local buttonY = y + h - 50
        
        -- TODO: Create button in Step 3
        -- Button.create('buy_item', buttonX, buttonY, buttonW, buttonH, 'BUY', function()
        --     print("Buy clicked for: " .. item.name)
        -- end)
    end
end

return right_details_panel 
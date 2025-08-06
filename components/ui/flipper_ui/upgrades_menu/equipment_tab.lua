-- equipment_tab.lua (orchestrator for equipment sub-tabs)
local player_tab = require('components.ui/flipper_ui/equipment_menu/player_tab')
local pants_tab = require('components.ui/flipper_ui/equipment_menu/pants_tab')
local hats_tab = require('components.ui/flipper_ui/equipment_menu/hats_tab')
local socks_tab = require('components.ui/flipper_ui/equipment_menu/socks_tab')
local gloves_tab = require('components.ui/flipper_ui/equipment_menu/gloves_tab')
local rings_tab = require('components.ui/flipper_ui/equipment_menu/rings_tab')
local glasses_tab = require('components.ui/flipper_ui/equipment_menu/glasses_tab')
local accessory_tab = require('components.ui/flipper_ui/equipment_menu/accessory_tab')
local theme = require('components.ui.flipper_ui.ui_theme')

local tabs = {
    {name = "Player", label = "Player", module = player_tab},
    {name = "Pants", label = "Pants", module = pants_tab},
    {name = "Hats", label = "Hats", module = hats_tab},
    {name = "Socks", label = "Socks", module = socks_tab},
    {name = "Gloves", label = "Gloves", module = gloves_tab},
    {name = "Rings", label = "Rings", module = rings_tab},
    {name = "Glasses", label = "Glasses", module = glasses_tab},
    {name = "Accessories", label = "Accessories", module = accessory_tab},
}

local selectedTab = 1
local hoveredTab = nil
local equipment_menu = {}
equipment_menu.selectedTab = selectedTab
equipment_menu.hoveredTab = hoveredTab
equipment_menu.absoluteTabPositions = {}

function equipment_menu.draw(x, y, w, h)
    -- Draw Player tab visually above the others, but treat as tab 1
    local playerTab = tabs[1]
    local playerTabW, playerTabH = 160, 36
    local playerTabX = x + (w - playerTabW) / 2
    local playerTabY = y + 8
    equipment_menu.absoluteTabPositions = {}
    -- Draw Player tab
    local tabRadius = 14
    equipment_menu.absoluteTabPositions[1] = {x = playerTabX, y = playerTabY, w = playerTabW, h = playerTabH}
    local isSelected = equipment_menu.selectedTab == 1
    local isHovered = equipment_menu.hoveredTab == 1
    if isSelected then
        love.graphics.setColor(0.85, 0.1, 0.1)
    elseif isHovered then
        love.graphics.setColor(0.7, 0.1, 0.1)
    else
        love.graphics.setColor(0.5, 0.05, 0.05)
    end
    love.graphics.rectangle('fill', playerTabX, playerTabY, playerTabW, playerTabH, tabRadius)
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle('line', playerTabX, playerTabY, playerTabW, playerTabH, tabRadius)
    if isSelected or isHovered then
        love.graphics.setColor(1, 0.85, 0)
    else
        love.graphics.setColor(1, 1, 1)
    end
    local font = love.graphics.getFont()
    local textW = font:getWidth(playerTab.label)
    local textH = font:getHeight()
    love.graphics.print(playerTab.label, playerTabX + (playerTabW - textW)/2, playerTabY + (playerTabH - textH)/2)

    -- Draw the rest of the tabs in a row below
    local tabBarY = playerTabY + playerTabH + 12
    local tabBarH = 32
    local tabSpacing = 10
    local numTabs = #tabs - 1
    local totalTabWidth = (numTabs * 100) + ((numTabs - 1) * tabSpacing)
    local startX = x + (w - totalTabWidth) / 2
    for i = 2, #tabs do
        local tab = tabs[i]
        local tabX = startX + (i-2)*(100 + tabSpacing)
        equipment_menu.absoluteTabPositions[i] = {x = tabX, y = tabBarY, w = 100, h = tabBarH}
        local isSelected = equipment_menu.selectedTab == i
        local isHovered = equipment_menu.hoveredTab == i
        if isSelected then
            love.graphics.setColor(0.85, 0.1, 0.1)
        elseif isHovered then
            love.graphics.setColor(0.7, 0.1, 0.1)
        else
            love.graphics.setColor(0.5, 0.05, 0.05)
        end
        love.graphics.rectangle('fill', tabX, tabBarY, 100, tabBarH, tabRadius)
        love.graphics.setColor(1, 0.85, 0)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle('line', tabX, tabBarY, 100, tabBarH, tabRadius)
        if isSelected or isHovered then
            love.graphics.setColor(1, 0.85, 0)
        else
            love.graphics.setColor(1, 1, 1)
        end
        local textW = font:getWidth(tab.label)
        local textH = font:getHeight()
        love.graphics.print(tab.label, tabX + (100 - textW)/2, tabBarY + (tabBarH - textH)/2)
    end
    -- Draw content area (no fill, just border)
    local contentY = tabBarY + tabBarH + 10
    local contentH = h - (contentY - y)
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', x, contentY, w, contentH, 0, 0, 10, 10)
    love.graphics.setColor(1, 1, 1)
    tabs[equipment_menu.selectedTab].module.draw(x, contentY, w, contentH)
end

function equipment_menu.mousepressed_absolute(x, y, button)
    for i, pos in ipairs(equipment_menu.absoluteTabPositions) do
        if x >= pos.x and x <= pos.x + pos.w and y >= pos.y and y <= pos.y + pos.h then
            equipment_menu.selectedTab = i
            return true
        end
    end
    
    -- If no tab was clicked, pass to the current tab's module
    local tab = tabs[equipment_menu.selectedTab]
    if tab and tab.module and tab.module.mousepressed then
        -- The coordinates passed to this function are already relative to the modal content area
        -- (transformed by ModalMenu.mousepressed: x - mx - 16, y - my - 48)
        
        -- Calculate the content area position (same as in draw function)
        local titleBarH = 40
        local tabBarY = 0 + titleBarH + 12  -- Relative to modal content area
        local tabBarH = 36
        local contentY = tabBarY + tabBarH + 10  -- Match the draw function
        
        -- Mouse coordinates are already relative to modal content area
        -- Pass coordinates directly to the template (same as draw function)
        return tab.module.mousepressed(
            x,                   -- mx: mouse coordinates relative to modal content area
            y,                   -- my: mouse coordinates relative to modal content area
            0,                   -- x: content area x position (relative to itself)
            contentY,            -- y: content area y position (relative to modal content area)
            1000 - 32,           -- w: content area width (modal width - 32)
            650 - 56 - contentY  -- h: content area height (modal height - 56 - contentY)
        )
    end
    
    return false
end

function equipment_menu.mousemoved_absolute(x, y)
    local tab = tabs[equipment_menu.selectedTab]
    if tab and tab.module and tab.module.mousemoved then
        -- The coordinates passed to this function are already relative to the modal content area
        -- (transformed by ModalMenu.mousepressed: x - mx - 16, y - my - 48)
        -- The draw function is called with (x, contentY, w, contentH) where:
        -- x = modal content area x (relative to modal)
        -- contentY = calculated from modal content area
        -- w = modal width - 32
        -- contentH = modal height - 56 - contentY offset
        
        -- Calculate the content area position (same as in draw function)
        local titleBarH = 40
        local tabBarY = 0 + titleBarH + 12  -- Relative to modal content area
        local tabBarH = 36
        local contentY = tabBarY + tabBarH + 10  -- Match the draw function
        
        -- Mouse coordinates are already relative to modal content area
        -- Pass coordinates directly to the template (same as draw function)
        tab.module.mousemoved(
            x,                   -- mx: mouse coordinates relative to modal content area
            y,                   -- my: mouse coordinates relative to modal content area
            0,                   -- x: content area x position (relative to itself)
            contentY,            -- y: content area y position (relative to modal content area)
            1000 - 32,           -- w: content area width (modal width - 32)
            650 - 56 - contentY  -- h: content area height (modal height - 56 - contentY)
        )
    end
end

return equipment_menu 
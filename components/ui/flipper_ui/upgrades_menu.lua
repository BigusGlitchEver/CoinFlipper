-- upgrades_menu.lua (orchestrator)
local upgrades_menu = {}

local equipment_tab = require('components.ui/flipper_ui/upgrades_menu/equipment_tab')
local crew_perks_tab = require('components.ui/flipper_ui/upgrades_menu/crew_perks_tab')
local building_mods_tab = require('components.ui/flipper_ui/upgrades_menu/building_mods_tab')
local global_tab = require('components.ui/flipper_ui/upgrades_menu/global_tab')
local theme = require('components.ui.flipper_ui.ui_theme')

local tabs = {
    {name = "Equipment", label = "Equipment", module = equipment_tab},
    {name = "Crew Perks", label = "Crew Perks", module = crew_perks_tab},
    {name = "Building Mods", label = "Building Mods", module = building_mods_tab},
    {name = "Global", label = "Global", module = global_tab},
}

local selectedTab = 1
upgrades_menu.selectedTab = selectedTab
upgrades_menu.absoluteTabPositions = {}
upgrades_menu.tabs = tabs

function upgrades_menu.draw(x, y, w, h)
    local titleBarH = 40
    local tabBarY = y + titleBarH + 12  -- Increased from 8 to 12 to give more space
    local tabBarH = 36
    local tabSpacing = 12
    local totalTabWidth = (#tabs * 120) + ((#tabs - 1) * tabSpacing)  -- Fixed width per tab
    local startX = x + (w - totalTabWidth) / 2  -- Center the tabs
    local contentY = tabBarY + tabBarH + 12  -- Increased from 8 to 12 to match tab spacing
    local contentH = h - (contentY - y)
    local tabRadius = 14
    upgrades_menu.absoluteTabPositions = {}
    for i, tab in ipairs(tabs) do
        local tabX = startX + (i-1)*(120 + tabSpacing)
        upgrades_menu.absoluteTabPositions[i] = {x = tabX, y = tabBarY, w = 120, h = tabBarH}
        -- Style
        if i == selectedTab then
            love.graphics.setColor(0.85, 0.1, 0.1)
        else
            love.graphics.setColor(0.5, 0.05, 0.05)
        end
        love.graphics.rectangle('fill', tabX, tabBarY, 120, tabBarH, tabRadius)
        love.graphics.setColor(1, 0.85, 0)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle('line', tabX, tabBarY, 120, tabBarH, tabRadius)
        -- Text
        if i == selectedTab then
            love.graphics.setColor(1, 0.85, 0)
        else
            love.graphics.setColor(1, 1, 1)
        end
        local font = love.graphics.getFont()
        local textW = font:getWidth(tab.label)
        local textH = font:getHeight()
        love.graphics.print(tab.label, tabX + (120 - textW)/2, tabBarY + (tabBarH - textH)/2)
    end
    -- Draw content area (bottom corners rounded, top corners square)
    -- love.graphics.setColor(0.15, 0.05, 0.05, 0.97)
    -- love.graphics.rectangle('fill', x, contentY, w, contentH, 0, 0, 12, 12)
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle('line', x, contentY, w, contentH, 0, 0, 12, 12)
    love.graphics.setColor(1, 1, 1)
    tabs[selectedTab].module.draw(x, contentY, w, contentH)
end

function upgrades_menu.mousepressed_absolute(x, y, button)
    for i, pos in ipairs(upgrades_menu.absoluteTabPositions) do
        if x >= pos.x and x <= pos.x + pos.w and y >= pos.y and y <= pos.y + pos.h then
            selectedTab = i
            upgrades_menu.selectedTab = i
            return true
        end
    end
    return false
end

return upgrades_menu 
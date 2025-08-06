-- right_panel.lua
local Button = require('components.ui.button')
local theme = require('components.ui.flipper_ui.ui_theme')
local Panel = require('components.ui.panel')
local crew = require('components.crew.crew')
local BuildingManager = require('components.buildings.manager')
local ModalMenu = require('components.modal_menu')

local upgradesBtnState = {hovered = false, pressed = false, offset = 0, velocity = 0}
local PRESS_OFFSET = 12
local SPRING = 60
local DAMPING = 8

local M = {}

function M.update(dt)
    -- Simple springy animation for the upgrades button
    local target = (upgradesBtnState.pressed and PRESS_OFFSET) or 0
    local displacement = upgradesBtnState.offset - target
    local force = -SPRING * displacement
    upgradesBtnState.velocity = upgradesBtnState.velocity + force * dt
    upgradesBtnState.velocity = upgradesBtnState.velocity * math.exp(-DAMPING * dt)
    upgradesBtnState.offset = upgradesBtnState.offset + upgradesBtnState.velocity * dt
end

function M.mousepressed(x, y, w, h, panelPad)
    -- Only handle upgrades button click
    local upgradesBtnW, upgradesBtnH = w - 2*panelPad, 48
    local upgradesBtnX = panelPad
    local upgradesBtnY = h - 65
    if x >= upgradesBtnX and x <= upgradesBtnX + upgradesBtnW and y >= upgradesBtnY and y <= upgradesBtnY + upgradesBtnH then
        M.upgradesModalOpen = true
        return true
    end
    return false
end

function M.draw(_, buttonLayout, x, y, w, h)
    local panelPad = theme.panelPad
    local rowHeight = theme.rowHeight
    local buttonW, buttonH = theme.buttonW, theme.buttonH
    local sectionSpacing = 24
    -- CREW SECTION BOX
    local crewBoxH = (#({'friend','gambler','highRoller'}) * rowHeight) + 56
    Panel.draw(x + panelPad, y + panelPad, w - 2*panelPad, crewBoxH, 'Crew', function(px, py, pw, ph)
        local yB = py + 32
        local crewTypes = {'friend', 'gambler', 'highRoller'}
        for i, crewType in ipairs(crewTypes) do
            local c = crew.types[crewType]
            local rowY = yB
            -- Row border
            love.graphics.setColor(theme.border)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle('line', px + 8, rowY, pw - 16, rowHeight - 8, 12)
            -- Crew name with count
            love.graphics.setColor(theme.text)
            local nameWithCount = c.name .. ' (x' .. (c.owned or 0) .. ')'
            love.graphics.printf(nameWithCount, px + 16, rowY + 6, pw - buttonW - 32, 'left')
            -- Cost (below name)
            love.graphics.setColor(1, 0.95, 0.2)
            love.graphics.printf('Cost: ' .. c.cost, px + 16, rowY + 28, pw - buttonW - 32, 'left')
            -- Owned (right side)
            love.graphics.setColor(theme.text)
            love.graphics.printf('Owned: ' .. (c.owned or 0), px + pw - 100, rowY + (rowHeight - buttonH) / 2, 100, 'right')
            -- Buy button (right edge)
            local btnX = px + pw - buttonW - 8
            local btnY = rowY + ((rowHeight - 8) - buttonH) / 2
            if Button.buttons['buy_'..i] then
                Button.buttons['buy_'..i].x = btnX
                Button.buttons['buy_'..i].y = btnY
            end
            yB = yB + rowHeight
        end
    end)
    -- BUILDINGS SECTION BOX
    local buildings = BuildingManager.getBuildings()
    local numBuildings = 0
    for i, b in ipairs(buildings) do
        if b.name ~= 'Friend' and b.name ~= 'Gambler' and b.name ~= 'High Roller' then
            numBuildings = numBuildings + 1
        end
    end
    local buildingsBoxY = y + panelPad + crewBoxH + sectionSpacing
    local buildingsBoxH = (numBuildings * rowHeight) + 56
    Panel.draw(x + panelPad, buildingsBoxY, w - 2*panelPad, buildingsBoxH, 'Buildings', function(px, py, pw, ph)
        local yB = py + 32
        local buildingIdx = 0
        for i, b in ipairs(buildings) do
            if b.name ~= 'Friend' and b.name ~= 'Gambler' and b.name ~= 'High Roller' then
                buildingIdx = buildingIdx + 1
                local rowY = yB
                -- Row border
                love.graphics.setColor(theme.border)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle('line', px + 8, rowY, pw - 16, rowHeight - 8, 12)
                -- Building name with count
                love.graphics.setColor(theme.text)
                local nameWithCount = b.name .. ' (x' .. (b.owned or 0) .. ')'
                love.graphics.printf(nameWithCount, px + 16, rowY + 6, pw - buttonW - 32, 'left')
                -- Cost (below name)
                love.graphics.setColor(1, 0.95, 0.2)
                love.graphics.printf('Cost: ' .. b.cost, px + 16, rowY + 28, pw - buttonW - 32, 'left')
                -- Buy button (right edge)
                local btnX = px + pw - buttonW - 8
                local btnY = rowY + ((rowHeight - 8) - buttonH) / 2
                if Button.buttons['buy_building_'..buildingIdx] then
                    Button.buttons['buy_building_'..buildingIdx].x = btnX
                    Button.buttons['buy_building_'..buildingIdx].y = btnY
                end
                yB = yB + rowHeight
            end
        end
    end)
    -- Upgrades button (mechanical style, springy motion)
    local upgradesBtnW, upgradesBtnH = w - 2*panelPad, 48
    local upgradesBtnX = x + panelPad
    local upgradesBtnY = y + h - 65
    local mx, my = love.mouse.getX(), love.mouse.getY()
    local hovered = mx >= upgradesBtnX and mx <= upgradesBtnX + upgradesBtnW and my >= upgradesBtnY and my <= upgradesBtnY + upgradesBtnH
    local pressed = hovered and love.mouse.isDown(1)
    upgradesBtnState.hovered = hovered
    upgradesBtnState.pressed = pressed
    -- Shadow (black, mechanical)
    local shadow_dx, shadow_dy = 12, 12
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', upgradesBtnX + shadow_dx, upgradesBtnY + shadow_dy, upgradesBtnW, upgradesBtnH, 18)
    -- Button fill (shades of red)
    local offset = upgradesBtnState.offset
    if pressed then
        love.graphics.setColor(0.5, 0.05, 0.05)
    elseif hovered then
        love.graphics.setColor(0.7, 0.1, 0.1)
    else
        love.graphics.setColor(0.85, 0.1, 0.1)
    end
    love.graphics.rectangle('fill', upgradesBtnX + offset, upgradesBtnY + offset, upgradesBtnW, upgradesBtnH, 18)
    -- Outline
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle('line', upgradesBtnX + offset, upgradesBtnY + offset, upgradesBtnW, upgradesBtnH, 18)
    -- Text
    love.graphics.setColor(1, 0.85, 0)
    local font = love.graphics.getFont()
    local text = 'UPGRADES'
    local textW = font:getWidth(text)
    local textH = font:getHeight()
    love.graphics.print(text, upgradesBtnX + offset + (upgradesBtnW - textW) / 2, upgradesBtnY + offset + (upgradesBtnH - textH) / 2)
end

M.upgradesBtnState = upgradesBtnState

return M 
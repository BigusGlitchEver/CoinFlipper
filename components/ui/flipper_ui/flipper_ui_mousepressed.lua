-- FlipperUI.mousepressed function

local state = require('components.ui.flipper_ui.flipper_state')
local Button = require('components.ui.button')
local ModalMenu = require('components.modal_menu')
local CrewManager = require('components.crew.manager')
local BuildingManager = require('components.buildings.manager')
local crew = require('components.crew.crew')
local right_panel = require('components.ui.flipper_ui.right_panel')
local upgrades_menu = require('components.ui.flipper_ui.upgrades_menu')

local upgradesModalOpen = false

local function mousepressed(x, y, button)
    state.mouseX, state.mouseY = x, y
    
    -- Settings button (bottom left)
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local leftW = screenW * 0.25
    local centerW = screenW * 0.5
    local rightW = screenW * 0.25
    local panelPad = 16
    -- Convert to left panel coordinates
    local leftPanelX = 0
    local leftPanelY = 0
    local relX = x - leftPanelX
    local relY = y - leftPanelY
    local flipper_panel = require('components.ui.flipper_ui.flipper_panel')
    if flipper_panel.mousepressed(relX, relY, leftW, screenH, panelPad) then
        -- TODO: Open settings modal
        return
    end
    
    -- Upgrades button (bottom right)
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local leftW = screenW * 0.25
    local centerW = screenW * 0.5
    local rightW = screenW * 0.25
    local panelPad = 16
    -- Convert to right panel coordinates
    local rightPanelX = leftW + centerW
    local rightPanelY = 0
    local relX = x - rightPanelX
    local relY = y - rightPanelY
    if right_panel.mousepressed(relX, relY, rightW, screenH, panelPad) then
        upgradesModalOpen = true
        ModalMenu.open("UPGRADES", function()
            upgrades_menu.draw((screenW-1000)/2, (screenH-650)/2, 1000, 650)
        end, 1000, 650)
        return
    end
    -- Detect right panel row clicks for owned crew/buildings
    local panelX = leftW + centerW
    local panelY = 0
    local panelW = rightW
    local panelH = screenH
    local crewTypes = {'friend', 'gambler', 'highRoller'}
    local rowY = panelPad + 40
    for i, crewType in ipairs(crewTypes) do
        local c = crew.types[crewType]
        -- Check if click is on the buy button first
        local btn = state.buttonLayout['buy_'..i]
        if btn and x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            Button.mousepressed(x, y, button)
            return
        end
        -- If not on buy button, check if click is on the row (excluding button area)
        if x >= panelX + panelPad and x <= panelX + panelW - panelPad and y >= rowY and y <= rowY + 60 - 8 then
            if c.owned and c.owned > 0 then
                -- Open modal for this crew/building using the new content function
                local modalW, modalH = 600, 400
                local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
                local modalX = (sw - modalW) / 2
                local modalY = (sh - modalH) / 2
                local contentFn = CrewManager.createCrewModalContent(c, modalX, modalY, modalW, modalH)
                ModalMenu.open("FRIENDS", contentFn, modalW, modalH)
                return
            end
        end
        rowY = rowY + 60
    end
    -- After crew row click logic, add building row click logic
    local buildings = BuildingManager.getBuildings()
    local numBuildings = 0
    for i, b in ipairs(buildings) do
        if b.name ~= 'Friend' and b.name ~= 'Gambler' and b.name ~= 'High Roller' then
            numBuildings = numBuildings + 1
        end
    end
    local buildingsBoxY = panelPad + 40 + (#crewTypes * 60) + 56 + 24
    local yB = buildingsBoxY
    local buildingIdx = 0
    for i, b in ipairs(buildings) do
        if b.name ~= 'Friend' and b.name ~= 'Gambler' and b.name ~= 'High Roller' then
            buildingIdx = buildingIdx + 1
            local rowY = yB
            -- Check if click is on the buy button first
            local btn = state.buttonLayout['buy_building_'..buildingIdx]
            if btn and x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + 60 - 8 then
                Button.mousepressed(x, y, button)
                return
            end
            -- If not on buy button, check if click is on the row (excluding button area)
            if x >= panelX + panelPad and x <= panelX + panelW - panelPad and y >= rowY and y <= rowY + 60 - 8 then
                if b.owned and b.owned > 0 then
                    local modalW, modalH = 600, 400
                    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
                    local modalX = (sw - modalW) / 2
                    local modalY = (sh - modalH) / 2
                    local contentFn = BuildingManager.createBuildingModalContent(b.name, modalX, modalY, modalW, modalH)
                    ModalMenu.open(b.name .. " BUILDINGS", contentFn, modalW, modalH)
                    return
                end
            end
            yB = yB + 60
        end
    end
    Button.mousepressed(x, y, button)
end

return mousepressed 
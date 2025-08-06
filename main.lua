local FlipperUI = require('components.ui.flipper_ui')
local PlayerManager = require('components.player.manager')
local FlipperManager = require('components.flippers.manager')
local BuildingManager = require('components.buildings.manager')
local ModalMenu = require('components.modal_menu')
local CrewManager = require('components.crew.manager')
local Dropdown = require('components.ui.dropdown')
local AutoFlipper = require('components.crew.auto_flipper')
local crew = require('components.crew.crew')
local fallingFlips = require('components.ui.flipper_ui.falling_flips')
local DropdownRenderer = require('components.ui.dropdown_renderer')
local DropdownHandler = require('components.ui.dropdown_handler')
local InputHandler = require('components.ui.input_handler')
local BurstEffects = require('components.ui.flipper_ui.burst_effects')

function love.load()
    FlipperUI.init()
end

function love.update(dt)
    FlipperManager.update(dt)
    FlipperUI.update(dt)
    ModalMenu.update(dt)
    Dropdown.update(dt)
    AutoFlipper.update(dt, crew)
    fallingFlips.updateFallingFlips(dt)
    BurstEffects.update(dt)
end

function love.draw()
    -- Draw burst effects behind main UI
    BurstEffects.draw()
    FlipperUI.draw()
    ModalMenu.draw()
    DropdownRenderer.drawCrewDropdowns(CrewManager.crewDropdowns)
    DropdownRenderer.drawBuildingDropdowns(BuildingManager.buildingDropdowns)
    
    -- Draw crew reward text if active
    local rewardText, rewardTimer, REWARD_DURATION = AutoFlipper.getRewardText()
    if rewardText and rewardTimer and rewardTimer > 0 then
        local panelPad = 16
        local font = love.graphics.getFont()
        local rewardFont = love.graphics.newFont(20)
        rewardFont:setFilter('nearest', 'nearest')
        local alpha = math.max(0, rewardTimer / REWARD_DURATION)
        local floatY = (1 - alpha) * -24
        love.graphics.setFont(rewardFont)
        if rewardText:sub(1,1) == '+' then
            love.graphics.setColor(1, 0.85, 0, alpha)
        else
            love.graphics.setColor(1, 0.2, 0.2, alpha)
        end
        love.graphics.print(rewardText, panelPad + 90, panelPad + floatY)
        love.graphics.setFont(font)
        love.graphics.setColor(1, 1, 1)
    end
end

-- ============= FIXED INPUT HANDLING =============

function love.mousepressed(x, y, button)
    -- Handle dropdowns FIRST (highest priority)
    if DropdownHandler.handleDropdownClicks(x, y, button) then
        return -- Stop processing if dropdown handled it
    end
    
    -- Then handle other input
    InputHandler.handleMousePress(x, y, button)
end

function love.mousemoved(x, y)
    InputHandler.handleMouseMoved(x, y)
end

function love.keypressed(key)
    InputHandler.handleKeyPressed(key)
end

-- ============= MODAL DROPDOWN CLEANUP =============

-- Patch ModalMenu to clear dropdowns on close and ensure modal exclusivity
local oldModalClose = ModalMenu.close
function ModalMenu.close(...)
    DropdownHandler.clearAllDropdowns()
    return oldModalClose(...)
end

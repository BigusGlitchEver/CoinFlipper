-- FlipperUI.init function

local state = require('components.ui.flipper_ui.flipper_state')
local flippers = require('components.ui.flipper_ui.flipper_data')
local buttonLayoutModule = require('components.ui.flipper_ui.flipper_button_layout')
local button_logic = require('components.ui.flipper_ui.button_logic')
local Player = require('components.player.player')
local crew = require('components.crew.crew')

local function init()
    -- Set default flipper if not set
    if not state.currentFlipper then
        state.currentFlipper = flippers.coin
    end
    -- Assign flippers table to state.flippers for button logic
    state.flippers = flippers
    -- Setup button layout and assign to state.buttonLayout
    state.buttonLayout = buttonLayoutModule.setupButtonLayout(state.currentFlipper)
    -- Create left panel buttons (flip, bet, flipper selection)
    local panelPad = 16
    local flipperStartY = panelPad + 220
    button_logic.createLeftPanelButtons(state, Player, state.buttonLayout, panelPad, flipperStartY)
    -- Crew and building buy buttons
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local leftW = screenW * 0.25
    local centerW = screenW * 0.5
    local rightW = screenW * 0.25
    button_logic.createCrewBuyButtons(Player, crew, state.buttonLayout, panelPad, leftW, centerW, rightW)
    button_logic.createBuildingBuyButtons(Player, state.buttonLayout, panelPad, leftW, centerW, rightW)
end

return init 
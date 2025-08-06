-- FlipperUI.draw function

local state = require('components.ui.flipper_ui.flipper_state')
local flippers = require('components.ui.flipper_ui.flipper_data')
local Panel = require('components.ui.panel')
local flipper_panel = require('components.ui.flipper_ui.flipper_panel')
local center_panel = require('components.ui.flipper_ui.center_panel')
local right_panel = require('components.ui.flipper_ui.right_panel')
local Button = require('components.ui.button')
local fallingFlips = require('components.ui.flipper_ui.falling_flips')
local Player = require('components.player.player')

local function draw()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local leftW = screenW * 0.25
    local centerW = screenW * 0.5
    local rightW = screenW * 0.25
    local panelPad = 16
    local font = love.graphics.getFont()

    -- Juicy win/lose font setup
    local juicyFontSize = 48
    if not state.juicyFont then
        state.juicyFont = love.graphics.newFont(juicyFontSize)
        state.juicyFont:setFilter('nearest', 'nearest')
    end

    -- Left Panel
    Panel.draw(0, 0, leftW, screenH, nil, function(x, y, w, h)
        flipper_panel.draw(
            Player, flippers, state.currentFlipper, state.bet, state.guess,
            state.rewardText, state.rewardTimer, state.REWARD_DURATION, state.buttonLayout, w, h
        )
    end)

    -- Center Panel
    Panel.draw(leftW, 0, centerW, screenH, nil, function(x, y, w, h)
        fallingFlips.drawFallingFlips()
        center_panel.draw(
            state.currentFlipper, state.flipState, state.win, state.flipAnimFrame, state.squash, state.targetFrame,
            state.rewardText, state.rewardTimer, state.REWARD_DURATION, x, y, w, h
        )
    end)

    -- Right Panel
    Panel.draw(leftW + centerW, 0, rightW, screenH, nil, function(x, y, w, h)
        right_panel.draw(nil, state.buttonLayout, x, y, w, h)
    end)

    Button.draw()
    love.graphics.setFont(font)
end

return draw 
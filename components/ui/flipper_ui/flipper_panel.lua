-- flipper_panel.lua
local Button = require('components.ui.button')
local Panel = require('components.ui.panel')
local theme = require('components.ui.flipper_ui.ui_theme')

local M = {}

-- Settings button state (same as UPGRADES button)
local settingsBtnState = {hovered = false, pressed = false, offset = 0, velocity = 0}
local PRESS_OFFSET = 12
local SPRING = 60
local DAMPING = 8

function M.update(dt)
    -- Simple springy animation for the settings button (same as UPGRADES button)
    local target = (settingsBtnState.pressed and PRESS_OFFSET) or 0
    local displacement = settingsBtnState.offset - target
    local force = -SPRING * displacement
    settingsBtnState.velocity = settingsBtnState.velocity + force * dt
    settingsBtnState.velocity = settingsBtnState.velocity * math.exp(-DAMPING * dt)
    settingsBtnState.offset = settingsBtnState.offset + settingsBtnState.velocity * dt
end

function M.draw(Player, flippers, currentFlipper, bet, guess, rewardText, rewardTimer, REWARD_DURATION, buttonLayout, w, h)
    local panelPad = theme.panelPad
    local font = love.graphics.getFont()
    -- Player stats
    love.graphics.setColor(theme.text)
    love.graphics.printf('Points: ' .. Player.getPoints(), panelPad, panelPad, w - 2*panelPad, 'left')
    -- Floating reward text
    if rewardText then
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
        love.graphics.setColor(theme.text)
    end
    -- Bet display and up/down buttons
    love.graphics.printf('Bet: ' .. bet .. ' (inc: ' .. (currentFlipper.betIncrement or 1) .. ')', panelPad, panelPad + 40, 120, 'left')
    if Button.buttons['bet_up'] then
        Button.buttons['bet_up'].x = panelPad + 80 + 50
        Button.buttons['bet_up'].y = panelPad + 40
    end
    if Button.buttons['bet_down'] then
        Button.buttons['bet_down'].x = panelPad + 80 + 50
        Button.buttons['bet_down'].y = panelPad + 40 + 22 + 2
    end
    love.graphics.printf('Guess: ' .. guess, panelPad, panelPad + 80, w - 2*panelPad, 'left')
    love.graphics.setColor(theme.text)
    love.graphics.printf('Flipper:', panelPad, panelPad + 190, w - 2*panelPad, 'left')
    
    -- Settings button (mechanical style, springy motion - EXACT same as UPGRADES button)
    local settingsBtnW, settingsBtnH = w - 2*panelPad, 48
    local settingsBtnX = panelPad
    local settingsBtnY = h - 65
    local mx, my = love.mouse.getX(), love.mouse.getY()
    local hovered = mx >= settingsBtnX and mx <= settingsBtnX + settingsBtnW and my >= settingsBtnY and my <= settingsBtnY + settingsBtnH
    local pressed = hovered and love.mouse.isDown(1)
    settingsBtnState.hovered = hovered
    settingsBtnState.pressed = pressed
    -- Shadow (black, mechanical)
    local shadow_dx, shadow_dy = 12, 12
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', settingsBtnX + shadow_dx, settingsBtnY + shadow_dy, settingsBtnW, settingsBtnH, 18)
    -- Button fill (shades of red)
    local offset = settingsBtnState.offset
    if pressed then
        love.graphics.setColor(0.5, 0.05, 0.05)
    elseif hovered then
        love.graphics.setColor(0.7, 0.1, 0.1)
    else
        love.graphics.setColor(0.85, 0.1, 0.1)
    end
    love.graphics.rectangle('fill', settingsBtnX + offset, settingsBtnY + offset, settingsBtnW, settingsBtnH, 18)
    -- Outline
    love.graphics.setColor(1, 0.85, 0)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle('line', settingsBtnX + offset, settingsBtnY + offset, settingsBtnW, settingsBtnH, 18)
    -- Text
    love.graphics.setColor(1, 0.85, 0)
    local font = love.graphics.getFont()
    local text = 'SETTINGS'
    local textW = font:getWidth(text)
    local textH = font:getHeight()
    love.graphics.print(text, settingsBtnX + offset + (settingsBtnW - textW) / 2, settingsBtnY + offset + (settingsBtnH - textH) / 2)
end

function M.mousepressed(x, y, w, h, panelPad)
    -- Handle settings button click
    local settingsBtnW, settingsBtnH = w - 2*panelPad, 48
    local settingsBtnX = panelPad
    local settingsBtnY = h - 65
    if x >= settingsBtnX and x <= settingsBtnX + settingsBtnW and y >= settingsBtnY and y <= settingsBtnY + settingsBtnH then
        -- TODO: Open settings modal
        return true
    end
    return false
end

return M 
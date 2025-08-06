-- center_panel.lua
local theme = require('components.ui.flipper_ui.ui_theme')
local Panel = require('components.ui.panel')

local M = {}

function M.draw(currentFlipper, flipState, win, flipAnimFrame, squash, targetFrame, rewardText, rewardTimer, REWARD_DURATION, x, y, w, h)
    local panelPad = theme.panelPad
    local font = love.graphics.getFont()
    local juicyFontSize = theme.juicyFontSize
    local juicyFont = love.graphics.newFont(juicyFontSize)
    juicyFont:setFilter('nearest', 'nearest')
    -- Flipper animation
    local flipperScale = math.min(w, h * 0.6) * 0.9 / math.max(currentFlipper.frameWidth, currentFlipper.frameHeight)
    local cx, cy = x + w/2, y + h * 0.38
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(flipperScale * squash, flipperScale * (2 - squash))
    love.graphics.translate(-currentFlipper.frameWidth/2, -currentFlipper.frameHeight/2)
    local isCoin = (currentFlipper.name == 'Coin' or currentFlipper.name == 'Lucky Coin' or currentFlipper.name == 'Unlucky Coin')
    if flipState == 'flipping' then
        love.graphics.draw(currentFlipper.imgFlipping, currentFlipper.quads[flipAnimFrame], 0, 0)
    elseif flipState == 'result' then
        if isCoin then
            if win then
                love.graphics.draw(currentFlipper.imgHeads, 0, 0)
            else
                love.graphics.draw(currentFlipper.imgTails, 0, 0)
            end
        else
            love.graphics.draw(currentFlipper.imgFlipping, currentFlipper.quads[flipAnimFrame], 0, 0)
        end
    else
        love.graphics.draw(currentFlipper.imgHeads, 0, 0)
    end
    love.graphics.pop()
    -- Win/lose/result display
    if flipState == 'result' then
        local resultText = win and 'YOU WIN!' or 'YOU LOSE!'
        local pulse = 1 + math.sin(love.timer.getTime() * 8) * 0.12
        love.graphics.setFont(juicyFont)
        local textW = juicyFont:getWidth(resultText)
        local textH = juicyFont:getHeight()
        local textX = x + (w - textW * pulse) / 2
        local textY = cy + currentFlipper.frameHeight * flipperScale / 2 + 32
        -- Drop shadow
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.push()
        love.graphics.translate(textX + 4 + textW * (1-pulse)/2, textY + 4 + textH * (1-pulse)/2)
        love.graphics.scale(pulse, pulse)
        love.graphics.print(resultText, 0, 0)
        love.graphics.pop()
        -- Pixel outline (8 directions)
        local offsets = {{-2,0},{2,0},{0,-2},{0,2},{-2,-2},{2,2},{-2,2},{2,-2}}
        love.graphics.setColor(0,0,0,1)
        for _, o in ipairs(offsets) do
            love.graphics.push()
            love.graphics.translate(textX + o[1] + textW * (1-pulse)/2, textY + o[2] + textH * (1-pulse)/2)
            love.graphics.scale(pulse, pulse)
            love.graphics.print(resultText, 0, 0)
            love.graphics.pop()
        end
        -- Main text (gold/yellow)
        if win then
            love.graphics.setColor(1, 0.95, 0.2)
        else
            love.graphics.setColor(1, 0.2, 0.2)
        end
        love.graphics.push()
        love.graphics.translate(textX + textW * (1-pulse)/2, textY + textH * (1-pulse)/2)
        love.graphics.scale(pulse, pulse)
        love.graphics.print(resultText, 0, 0)
        love.graphics.pop()
        love.graphics.setFont(font)
    end
    -- Flipper name display
    love.graphics.setColor(theme.text)
    love.graphics.printf('Flipper: ' .. currentFlipper.name, x + panelPad, y + h - 65, w - 2*panelPad, 'center')
end

return M 
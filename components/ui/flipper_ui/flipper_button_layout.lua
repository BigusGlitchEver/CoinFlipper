-- Button layout table for Flipper UI

local buttonLayout = {}

local function setupButtonLayout(currentFlipper)
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local leftW = screenW * 0.25
    local panelPad = 16
    -- Flip button
    buttonLayout.flip = {x = panelPad, y = panelPad + 130, w = leftW - 2*panelPad, h = 40}
    -- Bet up/down buttons
    local betBtnW, betBtnH = 28, 22
    local betX = panelPad + 80
    local betY = panelPad + 40
    buttonLayout.bet_up = {x = betX + 50, y = betY, w = betBtnW, h = betBtnH}
    buttonLayout.bet_down = {x = betX + 50, y = betY + betBtnH + 2, w = betBtnW, h = betBtnH}
    -- Flipper selection buttons
    local ySel = panelPad + 220
    for k, _ in pairs(require('components.ui.flipper_ui.flipper_data')) do
        buttonLayout['flipper_'..k] = {x = panelPad, y = ySel, w = leftW - 2*panelPad, h = 32}
        ySel = ySel + 40
    end
    return buttonLayout
end

return {
    buttonLayout = buttonLayout,
    setupButtonLayout = setupButtonLayout
} 
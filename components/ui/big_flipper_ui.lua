local Player = require('components.player.player')
local Flip = require('components.flippers.flip')
love.graphics.setDefaultFilter('nearest', 'nearest')

local Shared = require('components.ui.flipper_ui.shared')
local Button = require('components.ui.button')
local Panel = require('components.ui.panel')
local crew = require('components.crew.crew')
local assignmentPanel = { open = false, crewType = nil }

local FlipperUI = {}
-- Remove old flippers table
local coins = require('components.flippers.coins')
local misc = require('components.flippers.miscellaneous')
-- Merge all flippers into one table
local flippers = {}
for k, v in pairs(coins) do flippers[k] = v end
for k, v in pairs(misc) do flippers[k] = v end
for _, f in pairs(flippers) do
    f.frameWidth = f.imgFlipping:getWidth() / f.frames
    f.frameHeight = f.imgFlipping:getHeight()
    f.quads = {}
    for i = 1, f.frames do
        f.quads[i] = love.graphics.newQuad((i-1)*f.frameWidth, 0, f.frameWidth, f.frameHeight, f.imgFlipping:getDimensions())
    end
end
local currentFlipper = flippers.coin

local bet = 1
local guess = 'heads'
local flipState = 'idle'
local flipTimer = 0
local flipResult = nil
local win = false
local FLIP_ANIM_SPEED = 0.1
local flipAnimFrame = 1
local flipAnimTimer = 0
local squash = 1
local squashTarget = 1
local squashSpeed = 8
local popTimer = 0
local popDuration = 0.15

-- Add a table to store pending payout info
local pendingPayout = nil
-- Add floating reward text state
local rewardText = nil
local rewardTimer = 0
local REWARD_DURATION = 1.0

-- Add targetFrame to flip state
local targetFrame = 1

-- Placeholder buildings/workers
local buildings = {
    {name = 'Friend', cost = 100, owned = 0, income = 1},
    {name = 'Gambler', cost = 500, owned = 0, income = 5},
    {name = 'High Roller', cost = 2000, owned = 0, income = 20},
    {name = 'Gambling House', cost = 10000, owned = 0, income = 100},
    {name = 'Casino', cost = 50000, owned = 0, income = 500},
    {name = 'Vegas Empire', cost = 250000, owned = 0, income = 2500},
}

local mouseX, mouseY = 0, 0
local buttonLayout = {}

-- Crew auto-flip timers
local crewTimers = {}

local crewKeys = {'friend','gambler','highroller','gamblinghouse','casino','vegasempire'}

-- Modal state for crew management
local crewModal = {
    open = false, crewType = nil, scroll = 0, targetScroll = 0, dropdowns = {},
    alpha = 0, targetAlpha = 0, transitioning = false,
    selectedRow = 1, dropdownSelected = 1, dropdownAnimating = {},
    openDropdownIndex = nil, -- track which dropdown is open
}
local MODAL_ROW_HEIGHT = 56
local MODAL_VISIBLE_ROWS = 6
local MODAL_SCROLL_SPEED = 12
local MODAL_TRANSITION_SPEED = 10
local DROPDOWN_ANIM_SPEED = 16

-- Helper for dropdown state
local function isDropdownOpen(idx)
    return crewModal.dropdowns[idx] and crewModal.dropdowns[idx].open
end

-- Helper for dropdown rect
local function getDropdownRect(mx, my, mw, rowY)
    local ddW, ddH = 180, 32
    return mx + mw - ddW - 48, rowY + 8, ddW, ddH
end

-- Add a helper to check if the crew modal is open
function FlipperUI.isCrewModalOpen()
    return crewModal.open or (crewModal.alpha and crewModal.alpha > 0.01)
end

-- Add a helper for closing the modal
local function closeCrewModal()
    crewModal.open = false; crewModal.crewType = nil; crewModal.scroll = 0; crewModal.targetScroll = 0; crewModal.dropdowns = {}; crewModal.selectedRow = 1; crewModal.dropdownSelected = 1; crewModal.openDropdownIndex = nil
end

function FlipperUI.init()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local leftW = screenW * 0.25
    local centerW = screenW * 0.5
    local rightW = screenW * 0.25
    local panelPad = 16
    -- Left panel buttons
    buttonLayout.flip = {x = panelPad, y = panelPad + 130, w = leftW - 2*panelPad, h = 40}
    -- Bet up/down buttons
    local betBtnW, betBtnH = 28, 22
    local betX = panelPad + 80
    local betY = panelPad + 40
    Button.create('bet_up', betX + 50, betY, betBtnW, betBtnH, '+', function()
        local inc = currentFlipper.betIncrement or 1
        local maxBet = math.floor(Player.getPoints() / inc) * inc
        bet = math.min(maxBet, bet + inc)
    end, {
        fillColor = {0.85, 0.1, 0},
        borderColor = {1, 0.85, 0},
        textColor = {1, 0.85, 0},
        hoverColor = {1, 0.5, 0},
        borderRadius = 8,
        borderWidth = 2,
    })
    Button.create('bet_down', betX + 50, betY + betBtnH + 2, betBtnW, betBtnH, '-', function()
        local inc = currentFlipper.betIncrement or 1
        bet = math.max(inc, bet - inc)
    end, {
        fillColor = {0.85, 0.1, 0},
        borderColor = {1, 0.85, 0},
        textColor = {1, 0.85, 0},
        hoverColor = {1, 0.5, 0},
        borderRadius = 8,
        borderWidth = 2,
    })
    Button.create('flip', buttonLayout.flip.x, buttonLayout.flip.y, buttonLayout.flip.w, buttonLayout.flip.h, 'Flip!', function()
        if flipState ~= 'flipping' and not pendingPayout then
            flipState = 'flipping'
            flipTimer = 1.0
            flipAnimFrame = 1
            flipAnimTimer = 0
            -- Set winRate based on flipper ratio
            local winRate = 0.5
            if currentFlipper.name == 'Coin' then winRate = 0.5
            elseif currentFlipper.name == 'Cat' then winRate = 0.75
            elseif currentFlipper.name == 'Toast' then winRate = 0.25
            elseif currentFlipper.name == 'Grandma' then winRate = 0.125
            elseif currentFlipper.name == 'Lucky Coin' then winRate = 2/3
            elseif currentFlipper.name == 'Unlucky Coin' then winRate = 1/3
            end
            -- Decide win/lose and target frame
            local isWin = love.math.random() < winRate
            if isWin then
                targetFrame = 1
            else
                local frames = currentFlipper.frames
                repeat
                    targetFrame = love.math.random(2, frames)
                until targetFrame ~= 1
            end
            flipResult = {win = isWin, result = (isWin and 'heads' or 'tails')} -- result is not used for frame-based win
            win = isWin
            -- Prepare pending payout info for later
            pendingPayout = {
                bet = bet,
                win = win,
                flipper = currentFlipper,
                result = flipResult.result,
            }
            -- Do not update points here
        end
    end, {
        borderColor = {1, 0.85, 0}, -- yellow
        fillColor = {0.85, 0.1, 0}, -- red
        textColor = {1, 0.85, 0}, -- yellow
        shadowColor = {1, 0.5, 0, 0.5}, -- orange
        borderRadius = 18,
        borderWidth = 4,
        shadowUnpressed = 24,
        shadowPressed = 4,
        offsetUnpressed = 18,
        offsetPressed = 2,
        springUnpressed = -12,
        springPressed = 8,
    })
    -- Flipper selection buttons
    local ySel = panelPad + 220
    for k, f in pairs(flippers) do
        buttonLayout['flipper_'..k] = {x = panelPad, y = ySel, w = leftW - 2*panelPad, h = 32}
        local canAfford = Player.getPoints() >= f.bet
        -- Set up simple ratio labels
        local ratioLabel = f.name
        if k == 'toast' then ratioLabel = 'Toast 1:3'
        elseif k == 'cat' then ratioLabel = 'Cat 3:1'
        elseif k == 'grandma' then ratioLabel = 'Grandma 1:8'
        elseif k == 'coin' then ratioLabel = 'Coin 1:1'
        elseif k == 'luckycoin' then ratioLabel = 'Lucky Coin 2:1'
        elseif k == 'unluckycoin' then ratioLabel = 'Unlucky Coin 1:2'
        end
        Button.create('flipper_'..k, buttonLayout['flipper_'..k].x, buttonLayout['flipper_'..k].y, buttonLayout['flipper_'..k].w, buttonLayout['flipper_'..k].h, ratioLabel, function()
            if canAfford then
                currentFlipper = f
                flipAnimFrame = 1
                flipState = 'idle'
            end
        end, nil)
        ySel = ySel + 40
    end
    -- Right panel buy buttons
    local yB = panelPad + 40
    for i, key in ipairs(crewKeys) do
        local c = crew[key]
        buttonLayout['buy_'..i] = {x = leftW + centerW + rightW - panelPad - 80, y = yB + 8, w = 64, h = 32}
        Button.create('buy_'..i, buttonLayout['buy_'..i].x, buttonLayout['buy_'..i].y, buttonLayout['buy_'..i].w, buttonLayout['buy_'..i].h, 'Buy', function()
            if Player.getPoints() >= c.cost then
                Player.addPoints(-c.cost)
                c.owned = c.owned + 1
            end
        end)
        yB = yB + 60
    end
end

function FlipperUI.update(dt)
    mouseX, mouseY = love.mouse.getX(), love.mouse.getY()
    -- Crew auto-flip logic
    for crewKey, c in pairs(crew) do
        for i = 1, c.owned do
            crewTimers[crewKey] = crewTimers[crewKey] or {}
            crewTimers[crewKey][i] = crewTimers[crewKey][i] or 0
            crewTimers[crewKey][i] = crewTimers[crewKey][i] - dt
            if crewTimers[crewKey][i] <= 0 then
                -- Get assigned flipper (default to 'coin')
                local flipperKey = c.assignments[i] or 'coin'
                local f = flippers[flipperKey] or flippers.coin
                local totalPoints = 0
                for flipN = 1, c.coinsPerCycle do
                    local isWin = love.math.random() < c.winRate
                    local mult = math.floor((f.bet or 1) / (f.betIncrement or 1))
                    local delta = isWin and (mult * f.win) or (mult * f.lose)
                    totalPoints = totalPoints + delta
                end
                if totalPoints ~= 0 then
                    Player.addPoints(totalPoints)
                    -- Show a simple floating text (flash) for crew points
                    rewardText = (totalPoints > 0 and '+' or '') .. tostring(totalPoints) .. ' (Crew)'
                    rewardTimer = REWARD_DURATION * 0.7
                end
                crewTimers[crewKey][i] = c.interval
            end
        end
    end
    if flipState == 'flipping' then
        flipTimer = flipTimer - dt
        flipAnimTimer = flipAnimTimer + dt
        if flipAnimTimer >= FLIP_ANIM_SPEED then
            flipAnimFrame = flipAnimFrame % currentFlipper.frames + 1
            flipAnimTimer = flipAnimTimer - FLIP_ANIM_SPEED
        end
        squashTarget = 0.7 + 0.3 * math.abs(math.sin(flipTimer * 10))
        squash = squash + (squashTarget - squash) * math.min(1, squashSpeed * dt)
        if flipTimer <= 0 then
            flipState = 'result'
            flipAnimFrame = targetFrame -- Snap to target frame
            -- Determine win/lose based on final frame
            win = (flipAnimFrame == 1)
            if win then popTimer = popDuration end
            -- Award points only now
            if pendingPayout then
                local f = pendingPayout.flipper
                local mult = math.floor((pendingPayout.bet or f.bet) / (f.betIncrement or 1))
                local delta = win and (mult * f.win) or (mult * f.lose)
                Player.addPoints(delta)
                -- Set up reward text
                rewardText = (delta > 0 and '+' or '') .. tostring(delta) .. '!'
                rewardTimer = REWARD_DURATION
                pendingPayout = nil
            end
        end
    elseif flipState == 'result' then
        if popTimer > 0 then
            popTimer = popTimer - dt
            squash = 1.3
        else
            squash = squash + (1 - squash) * math.min(1, squashSpeed * dt)
        end
    else
        squash = squash + (1 - squash) * math.min(1, squashSpeed * dt)
    end
    -- Update reward text timer
    if rewardTimer > 0 then
        rewardTimer = rewardTimer - dt
        if rewardTimer <= 0 then rewardText = nil end
    end
    -- Clamp bet to allowed increments and player points in update
    dt = math.max(currentFlipper.betIncrement or 1, dt)
    bet = math.max(currentFlipper.betIncrement or 1, bet)
    bet = math.floor(bet / (currentFlipper.betIncrement or 1)) * (currentFlipper.betIncrement or 1)
    bet = math.min(bet, math.floor(Player.getPoints() / (currentFlipper.betIncrement or 1)) * (currentFlipper.betIncrement or 1))
    -- Smooth scroll for modal
    if crewModal.open and crewModal.crewType then
        crewModal.scroll = crewModal.scroll + (crewModal.targetScroll - crewModal.scroll) * math.min(1, MODAL_SCROLL_SPEED * dt)
    end
    -- Clamp scroll
    if crewModal.open and crewModal.crewType then
        local c = crew[crewModal.crewType]
        local maxScroll = math.max(0, (#c.assignments or 0) * MODAL_ROW_HEIGHT - MODAL_VISIBLE_ROWS * MODAL_ROW_HEIGHT)
        crewModal.targetScroll = math.max(0, math.min(crewModal.targetScroll, maxScroll))
        crewModal.scroll = math.max(0, math.min(crewModal.scroll, maxScroll))
    end
    -- Modal alpha transition
    if crewModal.open then
        crewModal.targetAlpha = 1
    else
        crewModal.targetAlpha = 0
    end
    if math.abs(crewModal.alpha - crewModal.targetAlpha) > 0.01 then
        crewModal.alpha = crewModal.alpha + (crewModal.targetAlpha - crewModal.alpha) * math.min(1, MODAL_TRANSITION_SPEED * dt)
        crewModal.transitioning = true
    else
        crewModal.alpha = crewModal.targetAlpha
        crewModal.transitioning = false
    end
    -- Dropdown animation
    for i, dd in pairs(crewModal.dropdowns) do
        crewModal.dropdownAnimating[i] = crewModal.dropdownAnimating[i] or 0
        if dd.open then
            crewModal.dropdownAnimating[i] = math.min(1, crewModal.dropdownAnimating[i] + DROPDOWN_ANIM_SPEED * dt)
        else
            crewModal.dropdownAnimating[i] = math.max(0, crewModal.dropdownAnimating[i] - DROPDOWN_ANIM_SPEED * dt)
        end
    end
    Button.update(dt, mouseX, mouseY)
end

-- Refactor draw order: draw modal at the end, always on top
function FlipperUI.draw()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local leftW = screenW * 0.25
    local centerW = screenW * 0.5
    local rightW = screenW * 0.25
    local panelPad = 16
    local font = love.graphics.getFont()
    local juicyFontSize = 48
    if not FlipperUI.juicyFont then
        FlipperUI.juicyFont = love.graphics.newFont(juicyFontSize)
        FlipperUI.juicyFont:setFilter('nearest', 'nearest')
    end
    -- Draw main game UI (background, panels, center, etc.)
    -- Left Panel
    Panel.draw(0, 0, leftW, screenH, nil, function(x, y, w, h)
        love.graphics.setColor(Shared.theme.text)
        love.graphics.printf('Points: ' .. Player.getPoints(), x + panelPad, y + panelPad, w - 2*panelPad, 'left')
        -- Draw floating reward text if active
        if rewardText then
            local rewardFont = love.graphics.newFont(20)
            rewardFont:setFilter('nearest', 'nearest')
            local alpha = math.max(0, rewardTimer / REWARD_DURATION)
            local floatY = (1 - alpha) * -24
            love.graphics.setFont(rewardFont)
            if rewardText:sub(1,1) == '+' then
                love.graphics.setColor(1, 0.85, 0, alpha) -- yellow for positive
            else
                love.graphics.setColor(1, 0.2, 0.2, alpha)
            end
            love.graphics.print(rewardText, x + panelPad + 90, y + panelPad + floatY)
            love.graphics.setFont(font)
            love.graphics.setColor(Shared.theme.text)
        end
        -- Bet display and up/down buttons
        love.graphics.printf('Bet: ' .. bet .. ' (inc: ' .. (currentFlipper.betIncrement or 1) .. ')', x + panelPad, y + panelPad + 40, 120, 'left')
        -- Up button
        if Button.buttons['bet_up'] then
            Button.buttons['bet_up'].x = x + panelPad + 80 + 50
            Button.buttons['bet_up'].y = y + panelPad + 40
        end
        -- Down button
        if Button.buttons['bet_down'] then
            Button.buttons['bet_down'].x = x + panelPad + 80 + 50
            Button.buttons['bet_down'].y = y + panelPad + 40 + 22 + 2
        end
        love.graphics.printf('Guess: ' .. guess, x + panelPad, y + panelPad + 80, w - 2*panelPad, 'left')
        love.graphics.setColor(Shared.theme.text)
        love.graphics.printf('Flipper:', x + panelPad, y + panelPad + 190, w - 2*panelPad, 'left')
        love.graphics.setColor(Shared.theme.text)
        love.graphics.printf('Settings', x + panelPad, y + h - 65, w - 2*panelPad, 'center')
    end)
    -- Center Panel
    Panel.draw(leftW, 0, centerW, screenH, nil, function(x, y, w, h)
        local flipperScale = math.min(w, h * 0.6) * 0.9 / math.max(currentFlipper.frameWidth, currentFlipper.frameHeight)
        local cx, cy = x + w/2, y + h * 0.38
        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.scale(flipperScale * squash, flipperScale * (2 - squash))
        love.graphics.translate(-currentFlipper.frameWidth/2, -currentFlipper.frameHeight/2)
        local isCoin = (currentFlipper == flippers.coin or currentFlipper == flippers.luckycoin or currentFlipper == flippers.unluckycoin)
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
        if flipState == 'result' and flipResult then
            local resultText = win and 'YOU WIN!' or 'YOU LOSE!'
            local pulse = 1 + math.sin(love.timer.getTime() * 8) * 0.12
            local juicyFont = FlipperUI.juicyFont
            local prevFont = love.graphics.getFont()
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
            love.graphics.setFont(prevFont)
        end
        love.graphics.setColor(Shared.theme.text)
        love.graphics.printf('Flipper: ' .. currentFlipper.name, x + panelPad, y + h - 65, w - 2*panelPad, 'center')
    end)
    -- Right Panel
    Panel.draw(leftW + centerW, 0, rightW, screenH, nil, function(x, y, w, h)
        love.graphics.setColor(Shared.theme.text)
        love.graphics.printf('Crew', x + panelPad, y + panelPad, w - 2*panelPad, 'center')
        local rowHeight = 60
        local buttonW, buttonH = 64, 32
        local yB = y + panelPad + 40
        if crewModal.open or crewModal.alpha > 0.01 then
            -- Modal overlay with alpha
            local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
            local mw, mh = sw * 0.6, sh * 0.6
            local mx, my = (sw - mw) / 2, (sh - mh) / 2
            love.graphics.setColor(0,0,0,0.4 * crewModal.alpha)
            love.graphics.rectangle('fill', 0, 0, sw, sh)
            love.graphics.setColor(0.7, 0, 0, crewModal.alpha)
            love.graphics.rectangle('fill', mx, my, mw, mh, 24)
            love.graphics.setColor(1, 0.85, 0, crewModal.alpha)
            love.graphics.setLineWidth(6)
            love.graphics.rectangle('line', mx, my, mw, mh, 24)
            love.graphics.setColor(1, 0.85, 0, crewModal.alpha)
            love.graphics.setFont(love.graphics.newFont(32))
            love.graphics.printf(crew[crewModal.crewType].name .. 's', mx, my + 18, mw, 'center')
            love.graphics.setFont(font)
            -- Scrollable list of crew members
            local c = crew[crewModal.crewType]
            local n = c.owned or 0
            c.assignments = c.assignments or {}
            local listX, listY = mx + 32, my + 70
            local listW, listH = mw - 64, mh - 140
            love.graphics.setScissor(listX, listY, listW, listH)
            for i = 1, n do
                local rowY = listY + (i-1) * MODAL_ROW_HEIGHT - crewModal.scroll
                if rowY + MODAL_ROW_HEIGHT > listY and rowY < listY + listH then
                    -- Row bg
                    if crewModal.selectedRow == i and crewModal.alpha > 0.8 then
                        love.graphics.setColor(1,1,0,0.18 * crewModal.alpha + 0.18)
                        love.graphics.rectangle('fill', listX-2, rowY-2, listW+4, MODAL_ROW_HEIGHT, 12)
                        love.graphics.setColor(1,1,0,0.5 * crewModal.alpha)
                        love.graphics.setLineWidth(3)
                        love.graphics.rectangle('line', listX-2, rowY-2, listW+4, MODAL_ROW_HEIGHT, 12)
                    else
                        love.graphics.setColor(0.8,0.1,0.1,0.18 + 0.08*(i%2))
                        love.graphics.rectangle('fill', listX, rowY, listW, MODAL_ROW_HEIGHT-4, 10)
                    end
                    -- Crew member label
                    love.graphics.setColor(1,0.85,0, crewModal.alpha)
                    love.graphics.setFont(font)
                    love.graphics.print(c.name..' #'..i, listX+12, rowY+10)
                    -- Dropdown for flipper assignment
                    local ddX, ddY, ddW, ddH = getDropdownRect(listX, listY, listW, rowY)
                    crewModal.dropdowns[i] = crewModal.dropdowns[i] or {open=false,selected=c.assignments[i] or 'coin'}
                    -- Dropdown box
                    love.graphics.setColor(1,0.85,0, crewModal.alpha)
                    love.graphics.rectangle('line', ddX, rowY+8, ddW, ddH, 8)
                    love.graphics.setColor(0.7,0,0,crewModal.alpha)
                    love.graphics.rectangle('fill', ddX, rowY+8, ddW, ddH, 8)
                    -- Dropdown label
                    local flipperKey = crewModal.dropdowns[i].selected or 'coin'
                    local f = flippers[flipperKey] or flippers.coin
                    love.graphics.setColor(1,0.85,0, crewModal.alpha)
                    love.graphics.print(f.name, ddX+12, rowY+8+6)
                    -- Dropdown arrow
                    love.graphics.setColor(1,0.85,0, crewModal.alpha)
                    love.graphics.polygon('fill', ddX+ddW-24, rowY+8+ddH/2-4, ddX+ddW-12, rowY+8+ddH/2-4, ddX+ddW-18, rowY+8+ddH/2+6)
                    -- Dropdown open (animated)
                    local anim = crewModal.dropdownAnimating[i] or 0
                    if anim > 0.01 then
                        local ddListH = math.min(#flippers*ddH, 6*ddH) * anim
                        love.graphics.setColor(0.7,0,0,crewModal.alpha)
                        love.graphics.rectangle('fill', ddX, rowY+8+ddH, ddW, ddListH, 8)
                        love.graphics.setColor(1,0.85,0, crewModal.alpha)
                        love.graphics.rectangle('line', ddX, rowY+8+ddH, ddW, ddListH, 8)
                        local idx = 0
                        for k, ff in pairs(flippers) do
                            local itemY = rowY+8+ddH+idx*ddH
                            if itemY >= rowY+8+ddH and itemY < rowY+8+ddH+ddListH then
                                if crewModal.dropdowns[i].open and crewModal.dropdownSelected == idx+1 and crewModal.selectedRow == i then
                                    love.graphics.setColor(1,1,0,0.25*crewModal.alpha+0.25)
                                    love.graphics.rectangle('fill', ddX, itemY, ddW, ddH, 8)
                                    love.graphics.setColor(1,1,0,0.7*crewModal.alpha)
                                    love.graphics.setLineWidth(2)
                                    love.graphics.rectangle('line', ddX, itemY, ddW, ddH, 8)
                                end
                                love.graphics.setColor(1,0.85,0, crewModal.alpha)
                                love.graphics.print(ff.name, ddX+12, itemY+6)
                            end
                            idx = idx + 1
                        end
                    end
                end
            end
            love.graphics.setScissor()
            -- Scrollbar
            local maxScroll = math.max(0, n*MODAL_ROW_HEIGHT - MODAL_VISIBLE_ROWS*MODAL_ROW_HEIGHT)
            if maxScroll > 0 then
                local barH = listH * MODAL_VISIBLE_ROWS / n
                local barY = listY + (crewModal.scroll / maxScroll) * (listH - barH)
                love.graphics.setColor(1,0.85,0, crewModal.alpha)
                love.graphics.rectangle('fill', mx+mw-24, barY, 12, barH, 6)
                love.graphics.setColor(0.7,0,0,crewModal.alpha)
                love.graphics.rectangle('line', mx+mw-24, listY, 12, listH, 6)
            end
        else
            for i, key in ipairs(crewKeys) do
                local c = crew[key]
                local rowY = yB
                -- Crew name and owned count (clickable for modal)
                love.graphics.setColor(Shared.theme.text)
                Button.create('crew_assign_'..key, x + panelPad, rowY + 4, w - 2*panelPad - buttonW - 16, 28, c.name .. ' (' .. c.owned .. ')', function()
                    crewModal.open = true; crewModal.crewType = key
                end, {fillColor={1,0.85,0},borderColor={1,0.85,0},textColor={0.85,0.1,0.1},borderRadius=12,borderWidth=2})
                -- Cost (below name)
                love.graphics.setColor(Shared.theme.accent)
                love.graphics.printf('Cost: ' .. c.cost, x + panelPad, rowY + 28, w - 2*panelPad - buttonW - 16, 'left')
                -- Buy button (right edge, vertically centered in row)
                local btnX = x + w - panelPad - buttonW
                local btnY = rowY + (rowHeight - buttonH) / 2
                if Button.buttons['buy_'..i] then
                    Button.buttons['buy_'..i].x = btnX
                    Button.buttons['buy_'..i].y = btnY
                end
                yB = yB + rowHeight
            end
        end
        love.graphics.setColor(Shared.theme.text)
        love.graphics.printf('Upgrades', x + panelPad, y + h - 65, w - 2*panelPad, 'center')
    end)
    Button.draw()
    love.graphics.setFont(font)
    -- Draw modal overlay and menu LAST, always on top
    if FlipperUI.isCrewModalOpen() then
        local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
        local mw, mh = sw * 0.6, sh * 0.6
        local mx, my = (sw - mw) / 2, (sh - mh) / 2
        -- Draw semi-transparent overlay
        love.graphics.setColor(0,0,0,0.5 * (crewModal.alpha or 1))
        love.graphics.rectangle('fill', 0, 0, sw, sh)
        -- Draw modal background
        love.graphics.setColor(0.7, 0, 0, crewModal.alpha)
        love.graphics.rectangle('fill', mx, my, mw, mh, 24)
        love.graphics.setColor(1, 0.85, 0, crewModal.alpha)
        love.graphics.setLineWidth(6)
        love.graphics.rectangle('line', mx, my, mw, mh, 24)
        -- Larger modal title
        love.graphics.setColor(1, 0.85, 0, crewModal.alpha)
        love.graphics.setFont(love.graphics.newFont(56))
        love.graphics.printf(crew[crewModal.crewType].name .. 's', mx, my + 18, mw, 'center')
        love.graphics.setFont(font)
        -- Crew list and closed dropdowns (no Back button)
        local c = crew[crewModal.crewType]
        local n = c.owned or 0
        c.assignments = c.assignments or {}
        local listX, listY = mx + 32, my + 70 + 32 -- Move list down by 32px for more space below the title
        local listW, listH = mw - 64, mh - 140
        love.graphics.setScissor(listX, listY, listW, listH)
        local openDropdown = nil
        for i = 1, n do
            local rowY = listY + (i-1) * MODAL_ROW_HEIGHT - crewModal.scroll
            if rowY + MODAL_ROW_HEIGHT > listY and rowY < listY + listH then
                -- Row bg and highlight (as before)
                if crewModal.selectedRow == i and crewModal.alpha > 0.8 then
                    love.graphics.setColor(1,1,0,0.18 * crewModal.alpha + 0.18)
                    love.graphics.rectangle('fill', listX, rowY, listW, MODAL_ROW_HEIGHT-4, 10)
                    love.graphics.setColor(1,1,0,0.5 * crewModal.alpha)
                    love.graphics.setLineWidth(3)
                    love.graphics.rectangle('line', listX, rowY, listW, MODAL_ROW_HEIGHT-4, 10)
                else
                    love.graphics.setColor(0.8,0.1,0.1,0.18 + 0.08*(i%2))
                    love.graphics.rectangle('fill', listX, rowY, listW, MODAL_ROW_HEIGHT-4, 10)
                end
                -- Crew member label (larger and bolder)
                love.graphics.setColor(1,0.85,0, crewModal.alpha)
                love.graphics.setFont(love.graphics.newFont(24))
                love.graphics.print(c.name..' #'..i, listX+12, rowY+8)
                love.graphics.setFont(font)
                -- Dropdown for flipper assignment
                local ddX, ddY, ddW, ddH = getDropdownRect(listX, listY, listW, rowY)
                crewModal.dropdowns[i] = crewModal.dropdowns[i] or {open=false,selected=c.assignments[i] or 'coin'}
                -- Dropdown box
                love.graphics.setColor(1,0.85,0, crewModal.alpha)
                love.graphics.rectangle('line', ddX, rowY+8, ddW, ddH, 8)
                love.graphics.setColor(0.7,0,0,crewModal.alpha)
                love.graphics.rectangle('fill', ddX, rowY+8, ddW, ddH, 8)
                -- Dropdown label
                local flipperKey = crewModal.dropdowns[i].selected or 'coin'
                local f = flippers[flipperKey] or flippers.coin
                love.graphics.setColor(1,0.85,0, crewModal.alpha)
                love.graphics.print(f.name, ddX+12, rowY+8+6)
                -- Dropdown arrow
                love.graphics.setColor(1,0.85,0, crewModal.alpha)
                love.graphics.polygon('fill', ddX+ddW-24, rowY+8+ddH/2-4, ddX+ddW-12, rowY+8+ddH/2-4, ddX+ddW-18, rowY+8+ddH/2+6)
                -- Only one dropdown open at a time, tracked globally
                if crewModal.openDropdownIndex == i then
                    openDropdown = {i=i, x=ddX, y=rowY+8, w=ddW, h=ddH}
                end
            end
        end
        love.graphics.setScissor()
        -- Scrollbar (as before)
        local maxScroll = math.max(0, n*MODAL_ROW_HEIGHT - MODAL_VISIBLE_ROWS*MODAL_ROW_HEIGHT)
        if maxScroll > 0 then
            local barH = listH * MODAL_VISIBLE_ROWS / n
            local barY = listY + (crewModal.scroll / maxScroll) * (listH - barH)
            love.graphics.setColor(1,0.85,0, crewModal.alpha)
            love.graphics.rectangle('fill', mx+mw-24, barY, 12, barH, 6)
            love.graphics.setColor(0.7,0,0,crewModal.alpha)
            love.graphics.rectangle('line', mx+mw-24, listY, 12, listH, 6)
        end
        -- Draw open dropdown last (on top of all modal content, not clipped)
        if openDropdown then
            love.graphics.setScissor()
            local i = openDropdown.i
            local ddX, ddY, ddW, ddH = openDropdown.x, openDropdown.y, openDropdown.w, openDropdown.h
            local rowY = nil -- not used in draw, but for consistency
            if not (ddX and ddY and ddW and ddH) then
                print('Dropdown draw: invalid rect', ddX, ddY, ddW, ddH)
                return
            end
            ddX = ddX or 0
            ddY = ddY or 0
            ddW = ddW or 180
            ddH = ddH or 32
            local anim = crewModal.dropdownAnimating[i] or 1
            local flipperKeys = {}
            for k in pairs(flippers) do table.insert(flipperKeys, k) end
            table.sort(flipperKeys)
            local minListH = ddH
            local ddListH = math.max(minListH, math.min(#flipperKeys*ddH, 6*ddH) * anim)
            love.graphics.setColor(0.7,0,0,crewModal.alpha)
            love.graphics.rectangle('fill', ddX, ddY+ddH, ddW, ddListH, 8)
            love.graphics.setColor(1,0.85,0, crewModal.alpha)
            love.graphics.rectangle('line', ddX, ddY+ddH, ddW, ddListH, 8)
            for idx, k in ipairs(flipperKeys) do
                local ff = flippers[k]
                local itemY = ddY+ddH+(idx-1)*ddH
                if itemY >= ddY+ddH and itemY < ddY+ddH+ddListH then
                    local isSelected = crewModal.openDropdownIndex == i and crewModal.dropdownSelected == idx and crewModal.selectedRow == i
                    local isHovered = mouseX > ddX and mouseX < ddX+ddW and mouseY > itemY and mouseY < itemY+ddH
                    if isHovered then
                        love.graphics.setColor(1, 0.85, 0.2, 0.25*crewModal.alpha+0.25) -- gold hover
                        love.graphics.rectangle('fill', ddX, itemY, ddW, ddH, 8)
                        love.graphics.setColor(1, 0.85, 0.2, 0.7*crewModal.alpha)
                        love.graphics.setLineWidth(2)
                        love.graphics.rectangle('line', ddX, itemY, ddW, ddH, 8)
                    elseif isSelected then
                        love.graphics.setColor(1,1,0,0.25*crewModal.alpha+0.25)
                        love.graphics.rectangle('fill', ddX, itemY, ddW, ddH, 8)
                        love.graphics.setColor(1,1,0,0.7*crewModal.alpha)
                        love.graphics.setLineWidth(2)
                        love.graphics.rectangle('line', ddX, itemY, ddW, ddH, 8)
                    end
                    love.graphics.setColor(1,0.85,0, crewModal.alpha)
                    love.graphics.print(ff.name, ddX+12, itemY+6)
                end
            end
        end
    end
end

function FlipperUI.mousepressed(x, y, button)
    mouseX, mouseY = x, y
    if FlipperUI.isCrewModalOpen() then
        local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
        local mw, mh = sw * 0.6, sh * 0.6
        local mx, my = (sw - mw) / 2, (sh - mh) / 2
        local c = crew[crewModal.crewType]
        if not c then
            -- Draw debug text if crew type is nil
            love.graphics.setColor(1,0,0,0.7)
            love.graphics.rectangle('fill', mx+mw/2-100, my+mh/2-30, 200, 60)
            love.graphics.setColor(1,1,1,1)
            love.graphics.print('DEBUG: crew type nil', mx+mw/2-90, my+mh/2-10)
            return
        end
        local n = c.owned or 0
        c.assignments = c.assignments or {}
        local listX, listY = mx + 32, my + 70 + 32
        local listW, listH = mw - 64, mh - 140
        -- If a dropdown is open, handle its input first
        if crewModal.openDropdownIndex then
            local i = crewModal.openDropdownIndex
            local rowY = listY + (i-1) * MODAL_ROW_HEIGHT - crewModal.scroll
            local ddX, ddY, ddW, ddH = getDropdownRect(listX, listY, listW, rowY)
            if not (ddX and ddY and ddW and ddH and rowY) then
                -- Draw debug rectangle and text
                love.graphics.setColor(1,0,0,0.7)
                love.graphics.rectangle('fill', mx+mw/2-120, my+mh/2-40, 240, 80)
                love.graphics.setColor(1,1,1,1)
                love.graphics.print('DEBUG: Dropdown rect or rowY nil', mx+mw/2-110, my+mh/2-10)
                love.graphics.print('ddX:'..tostring(ddX)..' ddY:'..tostring(ddY)..' ddW:'..tostring(ddW)..' ddH:'..tostring(ddH)..' rowY:'..tostring(rowY), mx+mw/2-110, my+mh/2+10)
                return
            end
            ddX = ddX or 0
            ddY = ddY or 0
            ddW = ddW or 180
            ddH = ddH or 32
            local flipperKeys = {}
            for k in pairs(flippers) do table.insert(flipperKeys, k) end
            table.sort(flipperKeys)
            for idx, k in ipairs(flipperKeys) do
                local itemY = ddY+ddH+(idx-1)*ddH
                if x > ddX and x < ddX+ddW and y > itemY and y < itemY+ddH then
                    crewModal.dropdowns[i].selected = k
                    c.assignments[i] = k
                    crewModal.dropdowns[i].open = false
                    crewModal.openDropdownIndex = nil
                    -- Visually indicate selection by changing the row color (handled in draw)
                    crewModal._debugClickedRow = i
                    return
                end
            end
            -- Click outside dropdown closes it
            crewModal.dropdowns[i].open = false
            crewModal.openDropdownIndex = nil
            return
        end
        -- If click outside modal, close it
        if not (x > mx and x < mx+mw and y > my and y < my+mh) then
            closeCrewModal()
            return
        end
        -- Dropdowns: only one open at a time
        local clickedDropdown = false
        for i = 1, n do
            local rowY = listY + (i-1) * MODAL_ROW_HEIGHT - crewModal.scroll
            local ddX, ddY, ddW, ddH = getDropdownRect(listX, listY, listW, rowY)
            if not (ddX and ddY and ddW and ddH and rowY) then
                love.graphics.setColor(1,0,0,0.7)
                love.graphics.rectangle('fill', mx+mw/2-120, my+mh/2-40, 240, 80)
                love.graphics.setColor(1,1,1,1)
                love.graphics.print('DEBUG: Dropdown rect or rowY nil', mx+mw/2-110, my+mh/2-10)
                love.graphics.print('ddX:'..tostring(ddX)..' ddY:'..tostring(ddY)..' ddW:'..tostring(ddW)..' ddH:'..tostring(ddH)..' rowY:'..tostring(rowY), mx+mw/2-110, my+mh/2+10)
                return
            end
            -- Dropdown box
            if x > ddX and x < ddX+ddW and y > rowY+8 and y < rowY+8+ddH then
                for j = 1, n do crewModal.dropdowns[j].open = false end
                crewModal.dropdowns[i].open = true
                crewModal.openDropdownIndex = i
                crewModal.selectedRow = i
                local flipperKeys = {}
                for k in pairs(flippers) do table.insert(flipperKeys, k) end
                table.sort(flipperKeys)
                for idx, k in ipairs(flipperKeys) do
                    if k == (crewModal.dropdowns[i].selected or 'coin') then
                        crewModal.dropdownSelected = idx
                    end
                end
                clickedDropdown = true
                crewModal._debugClickedRow = i -- Visually indicate row click
            end
        end
        if not clickedDropdown then
            for i = 1, n do crewModal.dropdowns[i].open = false end
            crewModal.openDropdownIndex = nil
        end
        return
    end
    Button.mousepressed(x, y, button)
end

function FlipperUI.mousereleased(x, y, button)
    if FlipperUI.isCrewModalOpen() then
        if crewModal.draggingBar then
            crewModal.draggingBar = nil
        end
        return
    end
end

function FlipperUI.mousemoved(x, y)
    mouseX, mouseY = x, y
    if FlipperUI.isCrewModalOpen() then
        -- Scrollbar drag
        if crewModal.draggingBar then
            local c = crew[crewModal.crewType]
            local n = c.owned or 0
            local maxScroll = math.max(0, n*MODAL_ROW_HEIGHT - MODAL_VISIBLE_ROWS*MODAL_ROW_HEIGHT)
            local listY = crewModal.draggingBar.listY
            local listH = crewModal.draggingBar.listH
            local barH = crewModal.draggingBar.barH
            local relY = y - listY - crewModal.draggingBar.offset
            relY = math.max(0, math.min(relY, listH - barH))
            local scroll = (relY / (listH - barH)) * maxScroll
            crewModal.targetScroll = scroll
        end
        return
    end
end

function FlipperUI.wheelmoved(dx, dy)
    if FlipperUI.isCrewModalOpen() then
        local c = crew[crewModal.crewType]
        local n = c.owned or 0
        local maxScroll = math.max(0, n*MODAL_ROW_HEIGHT - MODAL_VISIBLE_ROWS*MODAL_ROW_HEIGHT)
        crewModal.targetScroll = math.max(0, math.min(crewModal.targetScroll - dy*MODAL_ROW_HEIGHT, maxScroll))
    end
end

function FlipperUI.keypressed(key)
    if FlipperUI.isCrewModalOpen() then
        if key == 'escape' then
            closeCrewModal()
            return
        end
        local c = crew[crewModal.crewType]
        local n = c.owned or 0
        if n == 0 then return end
        local dd = crewModal.dropdowns[crewModal.selectedRow]
        local flipperKeys = {}
        for k in pairs(flippers) do table.insert(flipperKeys, k) end
        table.sort(flipperKeys)
        if dd and dd.open then
            if key == 'up' then
                crewModal.dropdownSelected = ((crewModal.dropdownSelected - 2) % #flipperKeys) + 1
            elseif key == 'down' then
                crewModal.dropdownSelected = (crewModal.dropdownSelected % #flipperKeys) + 1
            elseif key == 'return' or key == 'kpenter' or key == 'space' then
                local selectedKey = flipperKeys[crewModal.dropdownSelected]
                dd.selected = selectedKey
                c.assignments[crewModal.selectedRow] = selectedKey
                dd.open = false
                crewModal.openDropdownIndex = nil
            elseif key == 'escape' then
                dd.open = false
                crewModal.openDropdownIndex = nil
            end
            return
        end
        -- Row navigation (as before)
        if key == 'up' then
            crewModal.selectedRow = math.max(1, crewModal.selectedRow - 1)
            if crewModal.selectedRow < math.floor(crewModal.scroll / MODAL_ROW_HEIGHT) + 1 then
                crewModal.targetScroll = (crewModal.selectedRow - 1) * MODAL_ROW_HEIGHT
            end
        elseif key == 'down' then
            crewModal.selectedRow = math.min(n, crewModal.selectedRow + 1)
            if crewModal.selectedRow > math.floor((crewModal.scroll + MODAL_VISIBLE_ROWS * MODAL_ROW_HEIGHT - 1) / MODAL_ROW_HEIGHT) then
                crewModal.targetScroll = math.max(0, (crewModal.selectedRow - MODAL_VISIBLE_ROWS) * MODAL_ROW_HEIGHT)
            end
        elseif key == 'return' or key == 'kpenter' or key == 'space' then
            if dd then
                for j = 1, n do crewModal.dropdowns[j].open = false end
                dd.open = not dd.open
                if dd.open then
                    crewModal.openDropdownIndex = crewModal.selectedRow
                else
                    crewModal.openDropdownIndex = nil
                end
                for idx, k in ipairs(flipperKeys) do
                    if k == dd.selected then crewModal.dropdownSelected = idx end
                end
            end
        end
        return
    end
    if key == '+' or key == '=' then
        if Button.buttons['bet_up'] and Button.buttons['bet_up'].callback then Button.buttons['bet_up'].callback() end
    elseif key == '-' then
        if Button.buttons['bet_down'] and Button.buttons['bet_down'].callback then Button.buttons['bet_down'].callback() end
    end
end

return FlipperUI

-- button_logic.lua
local Button = require('components.ui.button')
local BuildingManager = require('components.buildings.manager')

local M = {}

function M.createLeftPanelButtons(gameState, Player, buttonLayout, panelPad, flipperStartY)
    -- Bet up button
    Button.create('bet_up', buttonLayout.bet_up.x, buttonLayout.bet_up.y, buttonLayout.bet_up.w, buttonLayout.bet_up.h, '+', function()
        local inc = gameState.currentFlipper.betIncrement or 1
        local maxBet = math.floor(Player.getPoints() / inc) * inc
        gameState.bet = math.min(maxBet, gameState.bet + inc)
    end, {
        fillColor = {0.85, 0.1, 0},
        borderColor = {1, 0.85, 0},
        textColor = {1, 0.85, 0},
        hoverColor = {1, 0.5, 0},
        borderRadius = 8,
        borderWidth = 2,
    })
    -- Bet down button
    Button.create('bet_down', buttonLayout.bet_down.x, buttonLayout.bet_down.y, buttonLayout.bet_down.w, buttonLayout.bet_down.h, '-', function()
        local inc = gameState.currentFlipper.betIncrement or 1
        gameState.bet = math.max(inc, gameState.bet - inc)
    end, {
        fillColor = {0.85, 0.1, 0},
        borderColor = {1, 0.85, 0},
        textColor = {1, 0.85, 0},
        hoverColor = {1, 0.5, 0},
        borderRadius = 8,
        borderWidth = 2,
    })
    -- Flip button (full original logic)
    Button.create('flip', buttonLayout.flip.x, buttonLayout.flip.y, buttonLayout.flip.w, buttonLayout.flip.h, 'Flip!', function()
        if gameState.flipState ~= 'flipping' and not gameState.pendingPayout then
            gameState.flipState = 'flipping'
            gameState.flipTimer = 1.0
            gameState.flipAnimFrame = 1
            gameState.flipAnimTimer = 0
            -- Set winRate based on flipper ratio
            local winRate = 0.5
            if gameState.currentFlipper.name == 'Coin' then winRate = 0.5
            elseif gameState.currentFlipper.name == 'Cat' then winRate = 0.75
            elseif gameState.currentFlipper.name == 'Toast' then winRate = 0.25
            elseif gameState.currentFlipper.name == 'Grandma' then winRate = 0.125
            elseif gameState.currentFlipper.name == 'Lucky Coin' then winRate = 2/3
            elseif gameState.currentFlipper.name == 'Unlucky Coin' then winRate = 1/3
            end
            -- Decide win/lose and target frame
            local isWin = love.math.random() < winRate
            if isWin then
                gameState.targetFrame = 1
            else
                local frames = gameState.currentFlipper.frames
                repeat
                    gameState.targetFrame = love.math.random(2, frames)
                until gameState.targetFrame ~= 1
            end
            gameState.flipResult = {win = isWin, result = (isWin and 'heads' or 'tails')}
            gameState.win = isWin
            
            -- Track the coin flip result
            local StatsTracker = require('components.player.stats_tracker')
            StatsTracker.addCoinFlip(isWin)
            
            -- Prepare pending payout info for later
            gameState.pendingPayout = {
                bet = gameState.bet,
                win = gameState.win,
                flipper = gameState.currentFlipper,
                result = gameState.flipResult.result,
            }
            -- Do not update points here
        end
    end, {
        borderColor = {1, 0.85, 0},
        fillColor = {0.85, 0.1, 0},
        textColor = {1, 0.85, 0},
        shadowColor = {1, 0.5, 0, 0.5},
        borderRadius = 18,
        borderWidth = 4,
        shadowUnpressed = 24,
        shadowPressed = 4,
        offsetUnpressed = 18,
        offsetPressed = 2,
        springUnpressed = -12,
        springPressed = 8,
    })
    -- Flipper selection buttons (with canAfford and ratioLabel logic)
    local ySel = flipperStartY
    for k, f in pairs(gameState.flippers) do
        local canAfford = Player.getPoints() >= (f.bet or 1)
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
                gameState.currentFlipper = f
                gameState.flipAnimFrame = 1
                gameState.flipState = 'idle'
            end
        end, {
            fillColor = canAfford and {1, 0.85, 0} or {0.5, 0.5, 0.5},
            borderColor = {1, 0.85, 0},
            textColor = canAfford and {0.85, 0.1, 0.1} or {0.5, 0.5, 0.5},
            borderRadius = 12,
            borderWidth = 2,
        })
        ySel = ySel + 40
    end
end

-- Modular function to create crew buy buttons for the right panel
function M.createCrewBuyButtons(Player, crew, buttonLayout, panelPad, leftW, centerW, rightW)
    local crewTypes = {'friend', 'gambler', 'highRoller'}
    local yB = panelPad + 40
    for i, crewType in ipairs(crewTypes) do
        local c = crew.types and crew.types[crewType]
        if c then
            -- Defensive: skip if malformed
            if type(c) ~= 'table' or not c.name or not c.cost then goto continue end
            -- Calculate cost dynamically
            local cost = crew.getCost and crew.getCost(crewType) or c.cost
            buttonLayout['buy_'..i] = {
                x = leftW + centerW + rightW - panelPad - 80,
                y = yB + 8,
                w = 64,
                h = 32
            }
            Button.create('buy_'..i, buttonLayout['buy_'..i].x, buttonLayout['buy_'..i].y, buttonLayout['buy_'..i].w, buttonLayout['buy_'..i].h, 'Buy', function()
                local cost = crew.buy(crewType, Player.getPoints())
                if cost > 0 then
                    Player.subtractPoints(cost)
                end
            end)
            yB = yB + 60
        end
        ::continue::
    end
end

function M.createBuildingBuyButtons(Player, buttonLayout, panelPad, leftW, centerW, rightW)
    local buildings = BuildingManager.getBuildings()
    local yB = panelPad + 40 + ((3) * 60) + 56 + 24 -- Crew rows + crew box + spacing
    local buildingIdx = 0
    for i, b in ipairs(buildings) do
        if b.name ~= 'Friend' and b.name ~= 'Gambler' and b.name ~= 'High Roller' then
            buildingIdx = buildingIdx + 1
            buttonLayout['buy_building_'..buildingIdx] = {
                x = leftW + centerW + rightW - panelPad - 80,
                y = yB + 8,
                w = 64,
                h = 32
            }
            Button.create('buy_building_'..buildingIdx, buttonLayout['buy_building_'..buildingIdx].x, buttonLayout['buy_building_'..buildingIdx].y, buttonLayout['buy_building_'..buildingIdx].w, buttonLayout['buy_building_'..buildingIdx].h, 'Buy', function()
                BuildingManager.attemptPurchase(i, Player)
            end)
            yB = yB + 60
        end
    end
end

return M 
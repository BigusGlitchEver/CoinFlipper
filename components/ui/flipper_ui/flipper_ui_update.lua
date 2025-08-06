-- FlipperUI.update function

local state = require('components.ui.flipper_ui.flipper_state')
local flippers = require('components.ui.flipper_ui.flipper_data')
local Button = require('components.ui.button')
local Player = require('components.player.player')
local fallingFlips = require('components.ui.flipper_ui.falling_flips')
local right_panel = require('components.ui.flipper_ui.right_panel')

local function update(dt)
    state.mouseX, state.mouseY = love.mouse.getX(), love.mouse.getY()
    if state.flipState == 'flipping' then
        state.flipTimer = state.flipTimer - dt
        state.flipAnimTimer = state.flipAnimTimer + dt
        if state.flipAnimTimer >= state.FLIP_ANIM_SPEED then
            state.flipAnimFrame = state.flipAnimFrame % state.currentFlipper.frames + 1
            state.flipAnimTimer = state.flipAnimTimer - state.FLIP_ANIM_SPEED
        end
        state.squashTarget = 0.7 + 0.3 * math.abs(math.sin(state.flipTimer * 10))
        state.squash = state.squash + (state.squashTarget - state.squash) * math.min(1, state.squashSpeed * dt)
        if state.flipTimer <= 0 then
            state.flipState = 'result'
            state.flipAnimFrame = state.targetFrame
            state.win = (state.flipAnimFrame == 1)
            if state.win then state.popTimer = state.popDuration end
            if state.pendingPayout then
                local f = state.pendingPayout.flipper
                local mult = math.floor((state.pendingPayout.bet or f.bet) / (f.betIncrement or 1))
                local delta = state.win and (mult * f.win) or (mult * f.lose)
                Player.addPoints(delta)
                if delta > 0 then
                    fallingFlips.spawnFallingFlip(state.currentFlipper.id, 'win')
                end
                state.rewardText = (delta > 0 and "+" or "") .. Player.formatPoints(delta)
                state.rewardTimer = 0
                state.pendingPayout = nil
            end
        end
    elseif state.flipState == 'result' then
        if state.popTimer > 0 then
            state.popTimer = state.popTimer - dt
            state.squash = 1.3
        else
            state.squash = state.squash + (1 - state.squash) * math.min(1, state.squashSpeed * dt)
        end
    else
        state.squash = state.squash + (1 - state.squash) * math.min(1, state.squashSpeed * dt)
    end
    if state.rewardTimer > 0 then
        state.rewardTimer = state.rewardTimer - dt
        if state.rewardTimer <= 0 then state.rewardText = nil end
    end
    state.bet = math.max(state.currentFlipper.betIncrement or 1, state.bet)
    state.bet = math.floor(state.bet / (state.currentFlipper.betIncrement or 1)) * (state.currentFlipper.betIncrement or 1)
    Button.update(dt, state.mouseX, state.mouseY)
    right_panel.update(dt)
    
    -- Update settings button animation
    local flipper_panel = require('components.ui.flipper_ui.flipper_panel')
    flipper_panel.update(dt)
end

return update 
local Player = require('components.player.player')
local Flip = require('components.flippers.flip')
love.graphics.setDefaultFilter('nearest', 'nearest')

local theme = require('theme')
local Button = require('components.ui.button')
local Panel = require('components.ui.panel')
local flipper_panel = require('components.ui.flipper_ui.flipper_panel')
local center_panel = require('components.ui.flipper_ui.center_panel')
local right_panel = require('components.ui.flipper_ui.right_panel')
local CrewManager = require('components.crew.manager')
local ModalMenu = require('components.modal_menu')
local crew = require('components.crew.crew')
local fallingFlips = require('components.ui.flipper_ui.falling_flips')

-- Remove old flippers table
local coins = require('components.flippers.coins')
local misc = require('components.flippers.miscellaneous')
-- Merge all flippers into one table
local flippers = {}
for k, v in pairs(coins) do
    v.id = k
    flippers[k] = v
end
for k, v in pairs(misc) do
    v.id = k
    flippers[k] = v
end
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

local mouseX, mouseY = 0, 0
local buttonLayout = {}

local FlipperUI = {}

FlipperUI.init = require('components.ui.flipper_ui.flipper_ui_init')
FlipperUI.update = require('components.ui.flipper_ui.flipper_ui_update')
FlipperUI.draw = require('components.ui.flipper_ui.flipper_ui_draw')
FlipperUI.keypressed = require('components.ui.flipper_ui.flipper_ui_keypressed')
FlipperUI.mousepressed = require('components.ui.flipper_ui.flipper_ui_mousepressed')
FlipperUI.mousemoved = require('components.ui.flipper_ui.flipper_ui_mousemoved')

return FlipperUI

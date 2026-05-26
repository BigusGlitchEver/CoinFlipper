-- main.lua
-- Entry point for Coin Flipper (LÖVE 2D).
-- See COIN FLIPPER — MACRO GDD v3.

local Gamestate = require('gamestate')
local Tween     = require('lib.tween')

local Buildings = require('components.buildings.manager')
local Bank      = require('components.marbles.bank')

local Map = require('gamestates.map')

-- Globals available to states.
_G.bank      = Bank.new(0)
_G.buildings = Buildings

function love.load()
    love.window.setTitle('Coin Flipper')
    love.graphics.setBackgroundColor(0.10, 0.12, 0.16)
    Gamestate.switch(Map)
end

function love.update(dt)
    Tween.update(dt)
    -- Passive Marble accrual from conquered buildings.
    _G.bank:accrue(Buildings.totalIncome(), dt)
    Gamestate.update(dt)
end

function love.draw()
    Gamestate.draw()
    love.graphics.print(("Marble Bank: %d"):format(_G.bank:balance()), 10, love.graphics.getHeight() - 24)
end

function love.keypressed(k)
    if k == 'escape' then love.event.quit() end
    Gamestate.keypressed(k)
end

function love.mousepressed(x, y, button)
    Gamestate.mousepressed(x, y, button)
end

-- gamestates/run.lua
-- A single run inside a house: 3 floors with a shop between each.
-- Owns a FlipBoard and tracks per-run Marbles earned.

local Board = require('components.flipboard.board')

local Run = {}

function Run:enter(prev, houseData)
    self.house = houseData
    self.floor = 1
    self.board = Board.new(self.floor)
    -- TODO: per-floor Marble threshold check, shop transition between floors
end

function Run:update(dt)
end

function Run:draw()
    love.graphics.print("RUN — Floor " .. (self.floor or 1), 20, 20)
    love.graphics.print("Marbles this run: " .. (self.board.marblesEarned or 0), 20, 40)
    love.graphics.print("Press SPACE to test-flip a coin", 20, 60)
end

function Run:keypressed(k)
    if k == 'space' then
        local item = { zoneWeights = { 4, 3, 2, 1 } }
        local zone, base, total = self.board:flip(item)
        print(("flip: zone=%d base=%d total=%d chain=%d"):format(zone, base, total, self.board.chain))
    end
end

function Run:mousepressed(x, y, button)
end

return Run

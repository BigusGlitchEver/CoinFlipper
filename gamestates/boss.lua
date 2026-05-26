-- gamestates/boss.lua
-- The boss flip. Simultaneous flips, fixed rounds, tug-of-war bar at top.
-- Per GDD: 5 rounds (to be tested), winner = whoever pushes bar to opponent's side.

local Boss = {}

function Boss:enter(prev, bossData)
    self.boss        = bossData
    self.round       = 1
    self.maxRounds   = 5
    self.tugOfWar    = 0   -- range [-1, 1]; +1 = player wins, -1 = boss wins
    self.playerScore = 0
    self.bossScore   = 0
end

function Boss:update(dt)
end

function Boss:draw()
    love.graphics.print("BOSS FLIP — round " .. self.round .. "/" .. self.maxRounds, 20, 20)
    love.graphics.print("Tug-of-war: " .. string.format("%.2f", self.tugOfWar), 20, 40)
    love.graphics.print("(walk away option TODO)", 20, 60)
end

function Boss:keypressed(k)
end

function Boss:mousepressed(x, y, button)
end

return Boss

-- gamestates/map.lua
-- Neighborhood map screen (prototype: cul-de-sac with 3 houses).
-- Skeleton only - drawing fills in once art exists.

local Map = {}

function Map:enter(prev)
    -- TODO: layout 3 houses, show locked/conquered state, global Marble bank
end

function Map:update(dt)
end

function Map:draw()
    love.graphics.print("MAP: cul-de-sac (3 houses)", 20, 20)
    love.graphics.print("Click a house to start a run (TODO)", 20, 40)
end

function Map:keypressed(k)
end

function Map:mousepressed(x, y, button)
    -- TODO: detect house click -> transition to run state with that house's data
end

return Map

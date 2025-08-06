-- Flipper aggregation, frame setup, and quad generation

local coins = require('components.flippers.coins')
local misc = require('components.flippers.miscellaneous')
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

return flippers 
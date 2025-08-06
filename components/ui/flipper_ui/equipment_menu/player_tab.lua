local playerImage = love.graphics.newImage('assets/player/playeroutline.png')
playerImage:setFilter('nearest', 'nearest')

local player_tab = {}

-- You can adjust this scale factor to make the image larger or smaller
local PLAYER_IMAGE_SCALE = 10 -- Increase for bigger, decrease for smaller

function player_tab.draw(x, y, w, h)
    local imgW, imgH = playerImage:getDimensions()
    local scale = PLAYER_IMAGE_SCALE
    local scaledW, scaledH = imgW * scale, imgH * scale
    local imgX = x + (w - scaledW) / 2
    local imgY = y + (h - scaledH) / 2

    -- Draw stage oval under the player's feet
    local ovalCX = x + w/2
    local ovalCY = imgY + scaledH * 0.98 -- just below the player's feet
    local ovalRadiusX = scaledW * 0.45
    local ovalRadiusY = scaledH * 0.13
    love.graphics.setColor(1, 0.85, 0.2, 0.32) -- brighter yellow, more opaque
    love.graphics.ellipse('fill', ovalCX, ovalCY, ovalRadiusX, ovalRadiusY)

    -- Draw the player image on top
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(playerImage, imgX, imgY, 0, scale, scale)
end

function player_tab.mousepressed(mx, my, x, y, w, h)
    -- No-op for now
end

function player_tab.mousemoved(mx, my, x, y, w, h)
    -- No-op for now, but function exists to prevent errors
end

return player_tab 
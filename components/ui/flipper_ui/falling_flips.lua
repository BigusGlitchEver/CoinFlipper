local M = {}
local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()
local flipperData = require('components.flippers.data')
local flippers = flipperData.flippers
local nameToKey = flipperData.nameToKey

M.fallingFlips = {}
M.maxFlips = 150

local function getRandomAnimationType(flipperType)
    if flipperType == 'toast' or flipperType == 'cat' then
        return love.math.random() < 0.6 and 'tumbling' or (love.math.random() < 0.5 and 'spinning' or 'static')
    elseif flipperType == 'coin' or flipperType == 'luckycoin' or flipperType == 'unluckycoin' then
        return love.math.random() < 0.7 and 'spinning' or (love.math.random() < 0.5 and 'tumbling' or 'static')
    else
        local r = love.math.random()
        if r < 0.4 then return 'spinning' elseif r < 0.75 then return 'tumbling' else return 'static' end
    end
end

function M.spawnFallingFlip(flipperType, result, sourceX)
    if #M.fallingFlips >= M.maxFlips then table.remove(M.fallingFlips, 1) end
    local itemWidth = flippers[flipperType] and flippers[flipperType].frameWidth or 64
    local maxItemWidth = math.min(itemWidth, screenWidth - 2)
    local minX = math.floor(maxItemWidth / 2)
    local maxX = math.floor(screenWidth - maxItemWidth / 2)
    local x
    if sourceX then
        x = sourceX
    else
        if minX > maxX then
            x = math.floor(screenWidth / 2)
        else
            x = love.math.random(minX, maxX)
        end
    end
    local flip = {
        x = x,
        y = -50,
        vx = love.math.random(-30, 30),
        vy = love.math.random(100, 180),
        sprite = flipperType,
        animationType = getRandomAnimationType(flipperType),
        animationTimer = 0,
        lifeTimer = 4.0,
        result = result,
        scale = love.math.random(80, 120) / 100
    }
    table.insert(M.fallingFlips, flip)
end

function M.updateFallingFlips(dt)
    for i = #M.fallingFlips, 1, -1 do
        local flip = M.fallingFlips[i]
        flip.x = flip.x + flip.vx * dt
        flip.y = flip.y + flip.vy * dt
        flip.vy = flip.vy + 300 * dt
        flip.animationTimer = flip.animationTimer + dt
        flip.lifeTimer = flip.lifeTimer - dt
        if flip.y > screenHeight + 100 or flip.lifeTimer <= 0 then
            table.remove(M.fallingFlips, i)
        end
    end
end

local ANIMATION_SPEED = 0.1 -- Match main flip animation speed

local function drawAnimated(flipperData, flip)
    -- Ensure we have the necessary data for animation
    if not flipperData.imgFlipping or not flipperData.frames or flipperData.frames == 0 or not flipperData.frameWidth or not flipperData.frameHeight then
        -- Fallback to static image if animation data is missing
        local sprite = flipperData.imgFlipping or flipperData.imgHeads
        if sprite then
            love.graphics.draw(sprite, flip.x, flip.y, 0, flip.scale, flip.scale, sprite:getWidth() / 2, sprite:getHeight() / 2)
        end
        return
    end

    local frame = (math.floor(flip.animationTimer / ANIMATION_SPEED) % flipperData.frames) + 1
    local quad = love.graphics.newQuad((frame - 1) * flipperData.frameWidth, 0, flipperData.frameWidth, flipperData.frameHeight, flipperData.imgFlipping:getDimensions())

    love.graphics.draw(flipperData.imgFlipping, quad, flip.x, flip.y, 0, flip.scale, flip.scale, flipperData.frameWidth / 2, flipperData.frameHeight / 2)
end


function M.drawFallingFlips()
    for _, flip in ipairs(M.fallingFlips) do
        local flipperData = flippers[flip.sprite]
        if flipperData then
            love.graphics.setColor(1, 1, 1, 1)
            drawAnimated(flipperData, flip)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return M 
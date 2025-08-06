local BurstEffects = {}

local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()
local flipperData = require('components.flippers.data')
local flippers = flipperData.flippers
local nameToKey = flipperData.nameToKey

BurstEffects.bursts = {}
BurstEffects.maxBursts = 100
local ANIMATION_SPEED = 0.1
local GRAVITY = 300

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

function BurstEffects.spawnBuildingBurst(flipperType, winCount, building)
    if winCount <= 0 then return end
    
    -- Clean up old bursts if we're at max capacity
    if #BurstEffects.bursts + winCount > BurstEffects.maxBursts then
        for i = 1, winCount do 
            table.remove(BurstEffects.bursts, 1) 
        end
    end
    
    -- Spawn from top of screen with random X position
    local burstX = love.math.random(80, screenWidth - 80)
    local burstY = -50
    
    -- Create burst spread pattern
    local spread = math.pi * 1.2
    local startAngle = -math.pi/2 - spread/2
    local speed = love.math.random(180, 260)
    
    for i = 1, winCount do
        local angle = startAngle + (spread * (i-1) / math.max(1, winCount-1))
        local vx = speed * math.cos(angle) + love.math.random(-20, 20)
        local vy = speed * math.sin(angle) + love.math.random(0, 40)
        
        local flip = {
            x = burstX,
            y = burstY,
            vx = vx,
            vy = vy,
            sprite = flipperType,
            animationType = getRandomAnimationType(flipperType),
            animationTimer = 0,
            lifeTimer = 4.0,
            result = 'win',
            scale = love.math.random(80, 120) / 100
        }
        table.insert(BurstEffects.bursts, flip)
    end
end

function BurstEffects.update(dt)
    for i = #BurstEffects.bursts, 1, -1 do
        local flip = BurstEffects.bursts[i]
        
        -- Update physics
        flip.x = flip.x + flip.vx * dt
        flip.y = flip.y + flip.vy * dt
        flip.vy = flip.vy + GRAVITY * dt
        
        -- Update animation
        flip.animationTimer = flip.animationTimer + dt
        flip.lifeTimer = flip.lifeTimer - dt
        
        -- Remove if off screen or expired
        if flip.y > screenHeight + 100 or flip.lifeTimer <= 0 then
            table.remove(BurstEffects.bursts, i)
        end
    end
end

local function drawAnimated(flipperData, flip)
    -- Handle sprites without animation frames
    if not flipperData.imgFlipping or not flipperData.frames or flipperData.frames == 0 or not flipperData.frameWidth or not flipperData.frameHeight then
        local sprite = flipperData.imgFlipping or flipperData.imgHeads
        if sprite then
            love.graphics.draw(sprite, flip.x, flip.y, 0, flip.scale, flip.scale, sprite:getWidth() / 2, sprite:getHeight() / 2)
        end
        return
    end
    
    -- Animated sprite with frames
    local frame = (math.floor(flip.animationTimer / ANIMATION_SPEED) % flipperData.frames) + 1
    local quad = love.graphics.newQuad(
        (frame - 1) * flipperData.frameWidth, 0, 
        flipperData.frameWidth, flipperData.frameHeight, 
        flipperData.imgFlipping:getDimensions()
    )
    love.graphics.draw(
        flipperData.imgFlipping, quad, 
        flip.x, flip.y, 0, flip.scale, flip.scale, 
        flipperData.frameWidth / 2, flipperData.frameHeight / 2
    )
end

function BurstEffects.draw()
    -- Draw all burst items
    for _, flip in ipairs(BurstEffects.bursts) do
        local flipperData = flippers[flip.sprite]
        if flipperData then
            love.graphics.setColor(1, 1, 1, 1)
            drawAnimated(flipperData, flip)
        end
    end
    
    love.graphics.setColor(1, 1, 1, 1) -- Reset color
end

return BurstEffects

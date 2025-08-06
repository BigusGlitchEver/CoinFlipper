local FlipperManager = {}

local flippers = {
    coin = {
        name = 'Coin',
        imgHeads = love.graphics.newImage('assets/Flippers/Coins/Regular/CoinHeads.png'),
        imgTails = love.graphics.newImage('assets/Flippers/Coins/Regular/CoinTails.png'),
        imgFlipping = love.graphics.newImage('assets/Flippers/Coins/Regular/CoinFlipping.png'),
        frames = 3,
    },
    cat = {
        name = 'Cat',
        imgHeads = love.graphics.newImage('assets/Flippers/Misc/Cat/Cat.png'),
        imgTails = love.graphics.newImage('assets/Flippers/Misc/Cat/Cat.png'),
        imgFlipping = love.graphics.newImage('assets/Flippers/Misc/Cat/CatSpinClockwise.png'),
        frames = 4,
    },
    grandma = {
        name = 'Grandma',
        imgHeads = love.graphics.newImage('assets/Flippers/Misc/Grandma/Grandma.png'),
        imgTails = love.graphics.newImage('assets/Flippers/Misc/Grandma/Grandma.png'),
        imgFlipping = love.graphics.newImage('assets/Flippers/Misc/Grandma/GrandmaClockwise.png'),
        frames = 4,
    },
    toast = {
        name = 'Toast',
        imgHeads = love.graphics.newImage('assets/Flippers/Misc/Toast/ToastHeads.png'),
        imgTails = love.graphics.newImage('assets/Flippers/Misc/Toast/ToastTails.png'),
        imgFlipping = love.graphics.newImage('assets/Flippers/Misc/Toast/ToastClockwise.png'),
        frames = 8,
    },
}

for _, f in pairs(flippers) do
    f.frameWidth = f.imgFlipping:getWidth() / f.frames
    f.frameHeight = f.imgFlipping:getHeight()
    f.quads = {}
    for i = 1, f.frames do
        f.quads[i] = love.graphics.newQuad((i-1)*f.frameWidth, 0, f.frameWidth, f.frameHeight, f.imgFlipping:getDimensions())
    end
end

local currentFlipper = flippers.coin
local flipState = 'idle' -- 'idle', 'flipping', 'result'
local flipTimer = 0
local flipAnimFrame = 1
local flipAnimTimer = 0
local flipResult = nil
local win = false
local FLIP_ANIM_SPEED = 0.1
local popTimer = 0
local popDuration = 0.15
local squash = 1
local squashTarget = 1
local squashSpeed = 8

function FlipperManager.getFlippers()
    return flippers
end

function FlipperManager.getCurrent()
    return currentFlipper
end

function FlipperManager.setCurrent(key)
    if flippers[key] then
        currentFlipper = flippers[key]
    end
end

function FlipperManager.getState()
    return flipState
end

function FlipperManager.getResult()
    return flipResult, win
end

function FlipperManager.getAnim()
    return flipAnimFrame, squash
end

function FlipperManager.startFlip(result, isWin)
    flipState = 'flipping'
    flipTimer = 1.0
    flipAnimFrame = 1
    flipAnimTimer = 0
    flipResult = result
    win = isWin
    popTimer = 0
end

function FlipperManager.update(dt)
    if flipState == 'flipping' then
        flipTimer = flipTimer - dt
        flipAnimTimer = flipAnimTimer + dt
        if flipAnimTimer >= FLIP_ANIM_SPEED then
            flipAnimFrame = flipAnimFrame % currentFlipper.frames + 1
            flipAnimTimer = flipAnimTimer - FLIP_ANIM_SPEED
        end
        squashTarget = 0.7 + 0.3 * math.abs(math.sin(flipTimer * 10))
        squash = squash + (squashTarget - squash) * math.min(1, squashSpeed * dt)
        if flipTimer <= 0 then
            flipState = 'result'
            if win then popTimer = popDuration end
        end
    elseif flipState == 'result' then
        if popTimer > 0 then
            popTimer = popTimer - dt
            squash = 1.3
        else
            squash = squash + (1 - squash) * math.min(1, squashSpeed * dt)
        end
    else
        squash = squash + (1 - squash) * math.min(1, squashSpeed * dt)
    end
end

function FlipperManager.reset()
    flipState = 'idle'
    flipResult = nil
end

return FlipperManager

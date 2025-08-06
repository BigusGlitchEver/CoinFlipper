-- button_shine.lua
local ButtonShine = {}

-- Shine effect variables
local shineActive = false
local shinePosition = 0  -- 0 to 1, represents progress across button
local shineSpeed = 1.2   -- seconds to complete the shine
local shineTimer = 0
local repeatDelay = 0.5  -- seconds to wait before repeating
local repeatTimer = 0
local shouldRepeat = false
local waitingForRepeat = false  -- New flag to track waiting state

function ButtonShine.start()
    shineActive = true
    shinePosition = 0
    shineTimer = 0
    shouldRepeat = true
    repeatTimer = 0
    waitingForRepeat = false
end

function ButtonShine.stop()
    shouldRepeat = false
    waitingForRepeat = false
end

function ButtonShine.update(dt)
    if shineActive then
        shineTimer = shineTimer + dt
        shinePosition = shineTimer / shineSpeed
        
        if shinePosition >= 1 then
            shineActive = false
            shinePosition = 0
            
            -- Start waiting for repeat if we should repeat
            if shouldRepeat then
                waitingForRepeat = true
                repeatTimer = 0
            end
        end
    elseif waitingForRepeat and shouldRepeat then
        -- Update the repeat timer when waiting
        repeatTimer = repeatTimer + dt
        if repeatTimer >= repeatDelay then
            -- Start the shine again
            shineActive = true
            shinePosition = 0
            shineTimer = 0
            waitingForRepeat = false
            repeatTimer = 0
        end
    end
end

function ButtonShine.draw(buttonX, buttonY, buttonWidth, buttonHeight, borderRadius)
    if not shineActive then return end
    
    love.graphics.push()
    
    -- Create a stencil to clip the shine to button bounds
    love.graphics.stencil(function()
        love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, borderRadius or 18)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    
    -- Calculate shine position
    local shineWidth = buttonWidth * 0.3  -- Width of the shine band
    local totalDistance = buttonWidth + shineWidth
    local currentX = buttonX - shineWidth + (shinePosition * totalDistance)
    
    -- Draw the diagonal shine gradient
    local mesh = love.graphics.newMesh({
        {currentX, buttonY, 0, 0, 1, 1, 1, 0}, -- Left edge, transparent
        {currentX + shineWidth * 0.3, buttonY, 0, 0, 1, 1, 1, 0.8}, -- Left-center, bright
        {currentX + shineWidth * 0.7, buttonY + buttonHeight, 0, 0, 1, 1, 1, 0.8}, -- Right-center, bright  
        {currentX + shineWidth, buttonY + buttonHeight, 0, 0, 1, 1, 1, 0}, -- Right edge, transparent
    }, "strip")
    
    love.graphics.setBlendMode("add") -- Makes it look like light
    love.graphics.draw(mesh)
    love.graphics.setBlendMode("alpha")
    
    love.graphics.setStencilTest()
    love.graphics.pop()
end

function ButtonShine.isActive()
    return shineActive or waitingForRepeat
end

return ButtonShine

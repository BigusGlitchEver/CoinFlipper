-- lib/tween.lua
-- A simple, custom tweening engine.

local Tween = {}
local activeTweens = {}

-- Easing functions determine the rate of change of a parameter over time.
local easing = {
    linear = function(t) return t end,
    quadIn = function(t) return t * t end,
    quadOut = function(t) return t * (2 - t) end,
    quadInOut = function(t) 
        if t < 0.5 then 
            return 2 * t * t 
        else 
            return -1 + (4 - 2 * t) * t 
        end 
    end,
}

-- Starts a new tween.
-- target: The table/object to animate.
-- properties: A table of properties to animate to (e.g., {x = 100, y = 50}).
-- duration: The time the animation should take in seconds.
-- options: A table with optional parameters like 'ease' and 'onComplete'.
function Tween.new(target, properties, duration, options)
    options = options or {}
    local tween = {
        target = target,
        properties = properties,
        duration = duration,
        ease = options.ease or easing.quadOut,
        onComplete = options.onComplete,
        progress = 0,
        startValues = {}
    }

    -- Store the starting values of the properties being animated
    for key, _ in pairs(properties) do
        tween.startValues[key] = target[key]
    end

    table.insert(activeTweens, tween)
    return tween
end

-- Update all active tweens. This should be called in love.update(dt).
function Tween.update(dt)
    for i = #activeTweens, 1, -1 do
        local tween = activeTweens[i]
        tween.progress = tween.progress + dt

        local t = math.min(tween.progress / tween.duration, 1)
        local eased_t = tween.ease(t)

        -- Update the target's properties
        for key, endValue in pairs(tween.properties) do
            local startValue = tween.startValues[key]
            if startValue then
                -- Check if the values are tables (for colors, vectors, etc.)
                if type(endValue) == "table" and type(startValue) == "table" then
                    for j = 1, #endValue do
                        if startValue[j] and endValue[j] then
                            tween.target[key][j] = startValue[j] + (endValue[j] - startValue[j]) * eased_t
                        end
                    end
                else -- It's a single number
                    tween.target[key] = startValue + (endValue - startValue) * eased_t
                end
            end
        end

        -- If the tween is complete
        if t >= 1 then
            if tween.onComplete then
                tween.onComplete()
            end
            table.remove(activeTweens, i)
        end
    end
end

return Tween

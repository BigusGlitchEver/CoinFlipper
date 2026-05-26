-- lib/tween.lua
-- Simple tweening engine. Carried over from old CoinFlipper.

local Tween = {}
local activeTweens = {}

local easing = {
    linear   = function(t) return t end,
    quadIn   = function(t) return t * t end,
    quadOut  = function(t) return t * (2 - t) end,
    quadInOut = function(t)
        if t < 0.5 then return 2 * t * t
        else return -1 + (4 - 2 * t) * t end
    end,
}
Tween.easing = easing

function Tween.new(target, properties, duration, options)
    options = options or {}
    local tween = {
        target      = target,
        properties  = properties,
        duration    = duration,
        ease        = options.ease or easing.quadOut,
        onComplete  = options.onComplete,
        progress    = 0,
        startValues = {},
    }
    for key, _ in pairs(properties) do
        tween.startValues[key] = target[key]
    end
    table.insert(activeTweens, tween)
    return tween
end

function Tween.update(dt)
    for i = #activeTweens, 1, -1 do
        local tween = activeTweens[i]
        tween.progress = tween.progress + dt
        local t = math.min(tween.progress / tween.duration, 1)
        local eased = tween.ease(t)
        for key, endValue in pairs(tween.properties) do
            local startValue = tween.startValues[key]
            if startValue then
                if type(endValue) == "table" and type(startValue) == "table" then
                    for j = 1, #endValue do
                        if startValue[j] and endValue[j] then
                            tween.target[key][j] = startValue[j] + (endValue[j] - startValue[j]) * eased
                        end
                    end
                else
                    tween.target[key] = startValue + (endValue - startValue) * eased
                end
            end
        end
        if t >= 1 then
            if tween.onComplete then tween.onComplete() end
            table.remove(activeTweens, i)
        end
    end
end

function Tween.clear()
    for i = #activeTweens, 1, -1 do
        table.remove(activeTweens, i)
    end
end

return Tween

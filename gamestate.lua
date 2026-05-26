-- gamestate.lua
-- Minimal state machine driving the core loop:
--   map -> run (3 floors w/ shops between) -> boss decision -> back to map
-- Each state is a module in gamestates/ exposing optional:
--   enter(prev, ...), leave(next), update(dt), draw(), keypressed(k), mousepressed(x,y,b)

local Gamestate = {}
local current = nil

local function noop() end

local function safe(state, fn)
    return state and state[fn] or noop
end

function Gamestate.switch(stateModule, ...)
    local prev = current
    safe(prev, 'leave')(prev, stateModule)
    current = stateModule
    safe(current, 'enter')(current, prev, ...)
end

function Gamestate.current()
    return current
end

function Gamestate.update(dt)
    safe(current, 'update')(current, dt)
end

function Gamestate.draw()
    safe(current, 'draw')(current)
end

function Gamestate.keypressed(k)
    safe(current, 'keypressed')(current, k)
end

function Gamestate.mousepressed(x, y, b)
    safe(current, 'mousepressed')(current, x, y, b)
end

return Gamestate

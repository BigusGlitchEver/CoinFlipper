-- statemachine.lua
-- Minimal scene/state manager. LOVE has no built-in one, so we built our own.
-- Each state is a table with any of: enter(prev, ...), exit(),
-- update(dt), draw(), mousepressed(x,y,button), keypressed(key).
-- Missing methods are skipped.
-- switch(name, ...) forwards the extra args to the new state's enter().

local StateMachine = {}

local states      = {}
local current     = nil
local currentName = nil

local function noop() end

local function callIf(state, fn, ...)
  if state and state[fn] then
    state[fn](state, ...)
  end
end

function StateMachine.register(name, module)
  states[name] = module
end

function StateMachine.switch(name, ...)
  local nxt = states[name]
  if not nxt then
    error("StateMachine: unknown state '" .. tostring(name) .. "'")
  end
  callIf(current, "exit")
  local prev   = current
  current      = nxt
  currentName  = name
  -- Forward extra args to the new state's enter.
  callIf(current, "enter", prev, ...)
end

function StateMachine.current()      return currentName end
function StateMachine.currentState() return current     end

function StateMachine.update(dt)            callIf(current, "update",       dt)        end
function StateMachine.draw()                callIf(current, "draw")                    end
function StateMachine.keypressed(k)         callIf(current, "keypressed",   k)         end
function StateMachine.mousepressed(x, y, b) callIf(current, "mousepressed", x, y, b)   end

-- Test-only helper.
function StateMachine._reset()
  callIf(current, "exit")
  current     = nil
  currentName = nil
end

return StateMachine

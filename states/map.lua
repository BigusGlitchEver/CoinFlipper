-- states/map.lua
-- Neighborhood cul-de-sac. 3 houses, sequential unlock.
-- Click an unlocked, un-conquered house -> StateMachine.switch("game", name).
-- Conquered = green, playable = red, locked = grey.
-- House conquest is tracked in-memory; persistence is a later concern.

local StateMachine = require("statemachine")

local lg = love.graphics

local Map = {}

-- Module-scope so conquest state survives state transitions.
-- (Reset via Map._reset() in tests.)
local houses = {
  { name = "Grandma", x = 360, y = 380, conquered = false },
  { name = "Cat",     x = 640, y = 220, conquered = false },
  { name = "GymBro",  x = 920, y = 380, conquered = false },
}

local HOUSE_RADIUS = 70

local function isUnlocked(i)
  if i == 1 then return true end
  return houses[i - 1].conquered
end

local function houseAt(x, y)
  for i, h in ipairs(houses) do
    local dx = x - h.x
    local dy = y - h.y
    if (dx * dx + dy * dy) <= (HOUSE_RADIUS * HOUSE_RADIUS) then
      return i, h
    end
  end
  return nil, nil
end

function Map:enter(prev)
end

function Map:exit() end
function Map:update(dt) end

function Map:draw()
  -- Cul-de-sac patch.
  lg.setColor(0.42, 0.70, 0.32)
  lg.circle("fill", 640, 360, 220)
  lg.setColor(0.30, 0.55, 0.22)
  lg.setLineWidth(3)
  lg.circle("line", 640, 360, 220)

  lg.setColor(1, 1, 1)
  lg.printf("NEIGHBORHOOD", 0, 36, lg.getWidth(), "center")

  for i, h in ipairs(houses) do
    if h.conquered then
      lg.setColor(0.25, 0.75, 0.30)
    elseif isUnlocked(i) then
      lg.setColor(0.80, 0.22, 0.22)
    else
      lg.setColor(0.45, 0.45, 0.45)
    end
    lg.circle("fill", h.x, h.y, HOUSE_RADIUS)
    lg.setColor(1, 1, 1)
    lg.setLineWidth(3)
    lg.circle("line", h.x, h.y, HOUSE_RADIUS)
    lg.printf(h.name, h.x - 60, h.y - 8, 120, "center")
    if not isUnlocked(i) then
      lg.printf("LOCKED", h.x - 60, h.y + 14, 120, "center")
    elseif h.conquered then
      lg.printf("CONQUERED", h.x - 60, h.y + 14, 120, "center")
    end
  end
end

function Map:mousepressed(x, y, button)
  if button ~= 1 then return end
  local i, h = houseAt(x, y)
  if not i then return end
  if not isUnlocked(i) then return end
  if h.conquered then return end
  StateMachine.switch("game", h.name)
end

function Map:keypressed(k) end

-- Public hook: called from game.lua when the player wins a boss flip.
function Map.markConquered(name)
  for _, h in ipairs(houses) do
    if h.name == name then h.conquered = true; return end
  end
end

-- Test hooks. Underscore prefix = internal.
Map._houses     = houses
Map._isUnlocked = isUnlocked
function Map._reset()
  for _, h in ipairs(houses) do h.conquered = false end
end

return Map

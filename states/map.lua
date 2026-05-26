-- states/map.lua
-- Neighborhood cul-de-sac. 3 houses, sequential unlock.
-- Landscape layout (800x600): houses in a triangle around a central green patch.
-- Click an unlocked, un-conquered house -> StateMachine.switch("game", name).

local StateMachine = require("statemachine")

local lg = love.graphics

local Map = {}

-- Module-scope so conquest state survives state transitions.
local houses = {
  { name = "Grandma", x = 200, y = 210, conquered = false },
  { name = "Cat",     x = 600, y = 210, conquered = false },
  { name = "GymBro",  x = 400, y = 430, conquered = false },
}

local HOUSE_RADIUS = 70
local CUL_DE_SAC_CX, CUL_DE_SAC_CY, CUL_DE_SAC_R = 400, 310, 180

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

function Map:enter(prev) end
function Map:exit() end
function Map:update(dt) end

function Map:draw()
  lg.setColor(0.92, 0.92, 0.92)
  lg.rectangle("fill", 0, 0, lg.getWidth(), lg.getHeight())

  -- Cul-de-sac patch.
  lg.setColor(0.42, 0.70, 0.32)
  lg.circle("fill", CUL_DE_SAC_CX, CUL_DE_SAC_CY, CUL_DE_SAC_R)
  lg.setColor(0.30, 0.55, 0.22)
  lg.setLineWidth(3)
  lg.circle("line", CUL_DE_SAC_CX, CUL_DE_SAC_CY, CUL_DE_SAC_R)

  lg.setColor(0.1, 0.1, 0.1)
  lg.printf("NEIGHBORHOOD", 0, 60, lg.getWidth(), "center")

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
    lg.printf(h.name, h.x - 80, h.y - 10, 160, "center")
    if not isUnlocked(i) then
      lg.printf("LOCKED", h.x - 80, h.y + 14, 160, "center")
    elseif h.conquered then
      lg.printf("CONQUERED", h.x - 80, h.y + 14, 160, "center")
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

function Map.markConquered(name)
  for _, h in ipairs(houses) do
    if h.name == name then h.conquered = true; return end
  end
end

-- Test hooks.
Map._houses     = houses
Map._isUnlocked = isUnlocked
function Map._reset()
  for _, h in ipairs(houses) do h.conquered = false end
end

return Map

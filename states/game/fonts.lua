-- states/game/fonts.lua
-- HUD fonts, lazily created. love.graphics.newFont must NOT run at module-load
-- time (no window yet), so ensure() is called from Game:enter instead.

local lg = love.graphics

local F = {}

function F.ensure()
  if F.HUGE then return end
  F.DEFAULT = lg.newFont(12)
  F.SMALL   = lg.newFont(11)
  F.MEDIUM  = lg.newFont(16)
  F.LARGE   = lg.newFont(28)
  F.HUGE    = lg.newFont(40)
end

return F

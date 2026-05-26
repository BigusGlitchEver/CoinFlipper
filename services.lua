-- services.lua
-- Persistent, session-spanning services (marble bank + buildings manager).
-- Relocated out of main.lua so main.lua stays tiny and contains no game logic.
-- States `require("services")` instead of reaching for globals.

local Bank      = require("components.marbles.bank")
local Buildings = require("components.buildings.manager")

local Services = {
  bank      = Bank.new(0),
  buildings = Buildings,
}

-- Per-frame tick: accrue passive Marbles from conquered buildings.
function Services.update(dt)
  Services.bank:accrue(Services.buildings.totalIncome(), dt)
end

return Services

-- main.lua
-- Window setup, state registration, callback routing. NO game logic.
-- See CLAUDE.md.

local StateMachine = require("statemachine")
local Services     = require("services")

local Map  = require("states.map")
local Game = require("states.game")

function love.load(arg)
  -- Headless smoke test entry: `lovec . --test` runs assertions and exits.
  if arg then
    for i = 1, #arg do
      if arg[i] == "--test" then
        local failed = require("tests.smoke").run()
        love.event.quit(failed > 0 and 1 or 0)
        return
      end
    end
  end

  -- Fix 1: lock window to 800x600 so it fits on a standard laptop screen.
  love.window.setMode(800, 600, { resizable = false })
  love.window.setTitle("Coin Flipper")
  love.graphics.setBackgroundColor(0.10, 0.12, 0.16)

  StateMachine.register("map",  Map)
  StateMachine.register("game", Game)
  StateMachine.switch("map")
end

function love.update(dt)
  StateMachine.update(dt)
  Services.update(dt)
end

function love.draw()
  StateMachine.draw()
end

function love.keypressed(k)
  if k == "escape" then love.event.quit(); return end
  StateMachine.keypressed(k)
end

function love.mousepressed(x, y, button)
  StateMachine.mousepressed(x, y, button)
end

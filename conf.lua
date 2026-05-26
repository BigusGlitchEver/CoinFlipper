-- conf.lua
-- LÖVE 2D configuration.

function love.conf(t)
    t.identity              = 'CoinFlipper'
    t.version               = '11.5'
    t.window.title          = 'Coin Flipper'
    t.window.width          = 1280
    t.window.height         = 720
    t.window.resizable      = true
    t.window.vsync          = 1
    t.console               = false
end

-- conf.lua
-- LOVE 2D configuration. Portrait orientation per FLIP_BOARD_VISUAL_SPEC.md.

function love.conf(t)
    t.identity              = 'CoinFlipper'
    t.version               = '11.5'
    t.window.title          = 'Coin Flipper'
    t.window.width          = 720
    t.window.height         = 1280
    t.window.resizable      = true
    t.window.minwidth       = 360
    t.window.minheight      = 640
    t.window.vsync          = 1
    t.console               = false
end

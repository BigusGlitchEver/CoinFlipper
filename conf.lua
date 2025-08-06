function love.conf(t)
    t.window.width = 1280
    t.window.height = 720
    t.window.title = "Anafuda"
    t.window.resizable = true
    t.window.minwidth = 800
    t.window.minheight = 600
    g_layout = {
        score = { x = 20, y = 20 },
        coins = { x = 20, y = 50 }
    }
end

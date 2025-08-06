local global_tab = {}

function global_tab.draw(x, y, w, h)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("World-affecting upgrades (events, multipliers, etc.). (Placeholder)", x + 32, y + 32)
end

function global_tab.mousepressed(mx, my, x, y, w, h)
    -- No-op for now
end

return global_tab 
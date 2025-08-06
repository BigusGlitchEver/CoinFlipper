local crew_perks_tab = {}

function crew_perks_tab.draw(x, y, w, h)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Upgrades that affect friends/gamblers/high rollers. (Placeholder)", x + 32, y + 32)
end

function crew_perks_tab.mousepressed(mx, my, x, y, w, h)
    -- No-op for now
end

return crew_perks_tab 
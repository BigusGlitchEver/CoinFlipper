local building_mods_tab = {}

function building_mods_tab.draw(x, y, w, h)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Upgrades for Lucky Penny, Gambling House, etc. (Placeholder)", x + 32, y + 32)
end

function building_mods_tab.mousepressed(mx, my, x, y, w, h)
    -- No-op for now
end

return building_mods_tab 
-- gamestates/shop.lua
-- The Nerdy Kid's shop. Shows up between every floor.
-- Prototype: 3-4 items for sale, fixed inventory.

local Shop = {}

function Shop:enter(prev, runContext)
    self.runContext = runContext
    self.dialogue = "Welcome. Got Marbles? I got stuff." -- placeholder
end

function Shop:update(dt)
end

function Shop:draw()
    love.graphics.print("SHOP (Nerdy Kid)", 20, 20)
    love.graphics.print(self.dialogue or '', 20, 40)
    love.graphics.print("(items list TODO)", 20, 60)
end

function Shop:keypressed(k)
end

function Shop:mousepressed(x, y, button)
end

return Shop

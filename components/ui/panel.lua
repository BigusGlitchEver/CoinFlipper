local Panel = {}
local theme = require('theme')

function Panel.draw(x, y, w, h, title, contentFn)
    -- Panel background
    love.graphics.setColor(theme.panel)
    love.graphics.rectangle('fill', x, y, w, h)
    -- Border
    love.graphics.setColor(theme.border)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle('line', x, y, w, h)
    -- Title (optional)
    if title then
        love.graphics.setColor(theme.text)
        love.graphics.printf(title, x, y + 8, w, 'center')
    end
    -- Content (optional)
    if contentFn then
        love.graphics.setScissor(x, y, w, h)
        contentFn(x, y, w, h)
        love.graphics.setScissor()
    end
end

return Panel

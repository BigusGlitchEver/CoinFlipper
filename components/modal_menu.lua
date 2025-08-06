local theme = require('theme')

local ModalMenu = {
    isOpen = false,
    title = nil,
    contentDrawFunction = nil,
    width = 400,
    height = 300,
    anim = 0, -- 0=closed, 1=open
    onClose = nil,
    onClick = nil, -- New callback for content clicks
}

function ModalMenu.open(title, contentDrawFunction, width, height, onClose, onClick)
    ModalMenu.isOpen = true
    ModalMenu.title = title
    ModalMenu.contentDrawFunction = contentDrawFunction
    ModalMenu.width = width or 400
    ModalMenu.height = height or 300
    ModalMenu.onClose = onClose
    ModalMenu.onClick = onClick
    ModalMenu.anim = 0
end

function ModalMenu.close()
    ModalMenu.isOpen = false
    if ModalMenu.onClose then ModalMenu.onClose() end
end

function ModalMenu.update(dt)
    if ModalMenu.isOpen then
        ModalMenu.anim = math.min(1, ModalMenu.anim + dt * 8)
    else
        ModalMenu.anim = math.max(0, ModalMenu.anim - dt * 8)
    end
end

function ModalMenu.draw()
    if ModalMenu.anim <= 0 then return end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    -- Overlay to darken background
    love.graphics.setColor(0, 0, 0, 0.6 * ModalMenu.anim)
    love.graphics.rectangle('fill', 0, 0, sw, sh)
    -- Modal position/size
    local mw, mh = ModalMenu.width, ModalMenu.height
    local mx = (sw - mw) / 2
    local my = (sh - mh) / 2
    -- Animation: scale in
    local scale = 0.95 + 0.05 * ModalMenu.anim
    local cx, cy = sw/2, sh/2
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-cx, -cy)
    -- Modal background
    love.graphics.setColor(theme.panel or theme.background or {0.7, 0, 0})
    love.graphics.rectangle('fill', mx, my, mw, mh, 18)
    -- Border
    love.graphics.setColor(theme.border or {1, 215/255, 0})
    love.graphics.setLineWidth(4)
    love.graphics.rectangle('line', mx, my, mw, mh, 18)
    -- Title bar
    if ModalMenu.title then
        love.graphics.setColor(theme.text or {1, 1, 1})
        love.graphics.setFont(love.graphics.getFont())
        love.graphics.printf(ModalMenu.title, mx, my + 12, mw, 'center')
    end
    -- Close button (top right)
    local closeW, closeH = 32, 32
    local closeX, closeY = mx + mw - closeW - 8, my + 8
    love.graphics.setColor(theme.border or {1, 215/255, 0})
    love.graphics.rectangle('fill', closeX, closeY, closeW, closeH, 12)
    love.graphics.setColor(theme.panel or theme.background or {0.7, 0, 0})
    love.graphics.setLineWidth(2)
    love.graphics.rectangle('line', closeX, closeY, closeW, closeH, 12)
    love.graphics.setColor(theme.text or {1, 1, 1})
    love.graphics.printf('X', closeX, closeY + 4, closeW, 'center')
    -- Content area
    if ModalMenu.contentDrawFunction then
        love.graphics.setScissor(mx, my + 48, mw, mh - 56)
        ModalMenu.contentDrawFunction(mx + 16, my + 48, mw - 32, mh - 56)
        love.graphics.setScissor()
    end
    love.graphics.pop()
end

function ModalMenu.mousepressed(x, y, button)
    if not ModalMenu.isOpen or ModalMenu.anim < 1 then return false end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    local mw, mh = ModalMenu.width, ModalMenu.height
    local mx = (sw - mw) / 2
    local my = (sh - mh) / 2
    -- Close button
    local closeW, closeH = 32, 32
    local closeX = mx + mw - closeW - 8
    local closeY = my + 8
    if x >= closeX and x <= closeX + closeW and y >= closeY and y <= closeY + closeH then
        ModalMenu.close()
        return true
    end
    -- Content area clicks (including dropdowns)
    if x >= mx and x <= mx + mw and y >= my + 48 and y <= my + mh - 8 then
        if ModalMenu.onClick then
            -- Pass coordinates relative to modal content area
            if ModalMenu.onClick(x - mx - 16, y - my - 48, 0, 0, mw - 32, mh - 56) then
                return true
            end
        end
        -- If no specific click was handled, still block the click
        return true
    end
    -- Click outside closes modal
    ModalMenu.close()
    return true
end

return ModalMenu 
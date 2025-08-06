local Button = {}

Button.buttons = {}
Button.transitionSpeed = 16 -- Faster transitions (was 6.67)
Button.theme = require('theme')
Button.shine = require('components.ui.button_shine')

-- Dramatic pop: larger translateY and shadow, chunkier border radius
Button.POP_HOVER = -6
Button.POP_ACTIVE = 3
Button.SHADOW_HOVER = 16
Button.SHADOW_ACTIVE = 2
Button.SHADOW_DEFAULT = 8
Button.SHADOW_OFFSET_DEFAULT = 6
Button.SHADOW_OFFSET_HOVER = 12
Button.SHADOW_OFFSET_ACTIVE = 2
Button.BORDER_RADIUS = 14

-- Pixelated look for all images and text
love.graphics.setDefaultFilter('nearest', 'nearest')
if love.graphics.getFont() and love.graphics.getFont().setFilter then
    love.graphics.getFont():setFilter('nearest', 'nearest')
end

function Button.create(id, x, y, w, h, text, callback, style)
    Button.buttons[id] = {
        x = x, y = y, w = w, h = h, text = text, callback = callback,
        hover = 0, -- 0 to 1
        active = 0, -- 0 to 1
        translateY = 0,
        shadowBlur = Button.SHADOW_DEFAULT,
        shadowOffset = Button.SHADOW_OFFSET_DEFAULT,
        style = style or nil,
    }
end

function Button.update(dt, mouseX, mouseY)
    for id, btn in pairs(Button.buttons) do
        local isHovered = mouseX and mouseY and mouseX >= btn.x and mouseX <= btn.x + btn.w and mouseY >= btn.y and mouseY <= btn.y + btn.h
        local targetHover = isHovered and 1 or 0
        local wasHovered = btn.hover > 0.5
        btn.hover = btn.hover + (targetHover - btn.hover) * math.min(1, Button.transitionSpeed * dt)
        local isNowHovered = btn.hover > 0.5
        
        -- Trigger shine effect for flip button when hover starts/stops
        if id == 'flip' and btn.style then
            if isNowHovered and not wasHovered then
                Button.shine.start()
            elseif not isNowHovered and wasHovered then
                Button.shine.stop()
            end
        end
        if id == 'flip' and btn.style then
            -- Use exact same spring logic as UPGRADES button
            local PRESS_OFFSET = 25  -- Increased for more dramatic press
            local SPRING = 60
            local DAMPING = 8
            
            -- Initialize spring state if not exists
            btn.offset = btn.offset or 3  -- Start 3 pixels down from normal position
            btn.velocity = btn.velocity or 0
            
            -- Simple springy animation (same as UPGRADES button)
            local target = (btn.active > 0 and PRESS_OFFSET) or 0
            local displacement = btn.offset - target
            local force = -SPRING * displacement
            btn.velocity = btn.velocity + force * dt
            btn.velocity = btn.velocity * math.exp(-DAMPING * dt)
            btn.offset = btn.offset + btn.velocity * dt
            
            -- Decay active state
            btn.active = math.max(0, btn.active - Button.transitionSpeed * dt)
            
            -- Update shine effect
            Button.shine.update(dt)
        
        else
            local targetTranslateY = Button.POP_HOVER * btn.hover + Button.POP_ACTIVE * btn.active
            btn.translateY = btn.translateY + (targetTranslateY - btn.translateY) * math.min(1, Button.transitionSpeed * dt)
            local targetShadowBlur = Button.SHADOW_DEFAULT + (Button.SHADOW_HOVER - Button.SHADOW_DEFAULT) * btn.hover + (Button.SHADOW_ACTIVE - Button.SHADOW_DEFAULT) * btn.active
            btn.shadowBlur = btn.shadowBlur + (targetShadowBlur - btn.shadowBlur) * math.min(1, Button.transitionSpeed * dt)
            local targetShadowOffset = Button.SHADOW_OFFSET_DEFAULT + (Button.SHADOW_OFFSET_HOVER - Button.SHADOW_OFFSET_DEFAULT) * btn.hover + (Button.SHADOW_OFFSET_ACTIVE - Button.SHADOW_OFFSET_DEFAULT) * btn.active
            btn.shadowOffset = btn.shadowOffset + (targetShadowOffset - btn.shadowOffset) * math.min(1, Button.transitionSpeed * dt)
            btn.active = math.max(0, btn.active - Button.transitionSpeed * dt)
        end
    end
end

function Button.draw()
    for id, btn in pairs(Button.buttons) do
        local theme = Button.theme
        local style = btn.style
        local isFlip = (id == 'flip' and style)
        if isFlip then
            -- Flip button: same logic as UPGRADES button but with orange shadow
            local shadow_dx, shadow_dy = 12, 12
            local offset = btn.offset or 0
            
            -- Shadow (orange instead of black)
            love.graphics.setColor(1, 0.5, 0, 0.7)
            love.graphics.rectangle('fill', btn.x + shadow_dx, btn.y + shadow_dy, btn.w, btn.h, 18)
            
            -- Button fill (same shades of red as UPGRADES)
            if btn.active > 0 then
                love.graphics.setColor(0.5, 0.05, 0.05)
            elseif btn.hover > 0 then
                love.graphics.setColor(0.7, 0.1, 0.1)
            else
                love.graphics.setColor(0.85, 0.1, 0.1)
            end
            love.graphics.rectangle('fill', btn.x + offset, btn.y + offset, btn.w, btn.h, 18)
            
            -- Outline
            love.graphics.setColor(1, 0.85, 0)
            love.graphics.setLineWidth(4)
            love.graphics.rectangle('line', btn.x + offset, btn.y + offset, btn.w, btn.h, 18)
            
            -- Text
            love.graphics.setColor(1, 0.85, 0)
            local font = love.graphics.getFont()
            if font and font.setFilter then font:setFilter('nearest', 'nearest') end
            local textW = font:getWidth(btn.text)
            local textH = font:getHeight()
            local textX = btn.x + offset + (btn.w - textW) / 2
            local textY = btn.y + offset + (btn.h - textH) / 2
            love.graphics.print(btn.text, textX, textY)
            
            -- Draw shine effect
            Button.shine.draw(btn.x + offset, btn.y + offset, btn.w, btn.h, 18)
        elseif style then
            -- All other buttons: no drop shadow
            local fill = style.fillColor or {1, 0.85, 0}
            local border = style.borderColor or {1, 0.85, 0}
            local text = style.textColor or {0.85, 0.1, 0.1}
            local hover = style.hoverColor or {1, 0.5, 0}
            local radius = style.borderRadius or 18
            local baseBorder = style.borderWidth or 2
            local borderWidth = baseBorder + 3 * btn.hover - 1.5 * btn.active
            local borderOffset = (borderWidth - baseBorder) / 2
            love.graphics.setColor(fill)
            love.graphics.rectangle('fill', btn.x - borderOffset, btn.y - borderOffset, btn.w + borderOffset * 2, btn.h + borderOffset * 2, radius + borderOffset)
            love.graphics.setColor(border)
            love.graphics.setLineWidth(borderWidth)
            love.graphics.rectangle('line', btn.x - borderOffset, btn.y - borderOffset, btn.w + borderOffset * 2, btn.h + borderOffset * 2, radius + borderOffset)
            love.graphics.setColor(text)
            local font = love.graphics.getFont()
            if font and font.setFilter then font:setFilter('nearest', 'nearest') end
            local textW = font:getWidth(btn.text)
            local textH = font:getHeight()
            local textX = btn.x + (btn.w - textW) / 2
            local textY = btn.y + (btn.h - textH) / 2
            love.graphics.print(btn.text, textX, textY)
        else
            -- Default style for all other buttons
            local r, g, b = unpack(theme.button)
            local hoverR, hoverG, hoverB = unpack(theme.button_hover)
            local activeR, activeG, activeB = unpack(theme.button_active)
            local finalR = r + (hoverR - r) * btn.hover + (activeR - r) * btn.active
            local finalG = g + (hoverG - g) * btn.hover + (activeG - g) * btn.active
            local finalB = b + (hoverB - b) * btn.hover + (activeB - b) * btn.active
            -- Shadow
            love.graphics.setColor(0, 0, 0, 0.4)
            love.graphics.rectangle('fill', btn.x + btn.shadowOffset, btn.y + btn.shadowOffset + btn.translateY, btn.w, btn.h, Button.BORDER_RADIUS)
            -- Button
            love.graphics.setColor(finalR, finalG, finalB)
            love.graphics.rectangle('fill', btn.x, btn.y + btn.translateY, btn.w, btn.h, Button.BORDER_RADIUS)
            -- Border
            love.graphics.setColor(theme.border)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle('line', btn.x, btn.y + btn.translateY, btn.w, btn.h, Button.BORDER_RADIUS)
            -- Text: always centered in the button, pixelated
            love.graphics.setColor(theme.bg)
            local font = love.graphics.getFont()
            if font and font.setFilter then font:setFilter('nearest', 'nearest') end
            local textW = font:getWidth(btn.text)
            local textH = font:getHeight()
            local textX = btn.x + (btn.w - textW) / 2
            local textY = btn.y + btn.translateY + (btn.h - textH) / 2
            love.graphics.print(btn.text, textX, textY)
        end
    end
end

function Button.mousepressed(x, y, button)
    if button == 1 then
        for _, btn in pairs(Button.buttons) do
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                btn.active = 1
                if btn.callback then btn.callback() end
                break
            end
        end
    end
end

function Button.mousemoved(x, y)
    -- No-op, hover handled in update
end

function Button.clear()
    Button.buttons = {}
end

-- Provide a function to get the max button height including border for layout
function Button.getMaxHeight(id, h, style)
    local baseBorder = (style and style.borderWidth) or 2
    local maxBorder = baseBorder + 3 -- max hover expansion
    local borderOffset = (maxBorder - baseBorder) / 2
    return h + borderOffset * 2
end

return Button
